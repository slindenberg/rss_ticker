import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      home: TickerScaffold(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class TickerScaffold extends StatefulWidget {
  const TickerScaffold({super.key});

  @override
  State<TickerScaffold> createState() => _TickerScaffoldState();
}

class _TickerScaffoldState extends State<TickerScaffold> {
  final ScrollController _scrollController = ScrollController();
  static const int _repeatCount = 20;
  bool _isMenuOpen = false;
  List<String> _feeds = [];
  List<String> _headlines = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTicker();
    });
  }

  Future<void> _initializeTicker() async {
    await _loadFeeds();
    if (!mounted) return;
    await _fetchHeadlines();
    _startScrolling();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startScrolling() async {
    await Future.delayed(const Duration(milliseconds: 300));

    while (mounted && _scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;

      if (maxExtent <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      await _scrollController.animateTo(
        maxExtent,
        duration: const Duration(seconds: 40),
        curve: Curves.linear,
      );

      if (!mounted || !_scrollController.hasClients) break;

      _scrollController.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  Future<File> _getFeedsFile() async {
    final homeDir =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final dir = Directory('$homeDir/.rssticker');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/feeds.json');
  }

  Future<void> _loadFeeds() async {
    try {
      final file = await _getFeedsFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> json = jsonDecode(contents);
        setState(() {
          _feeds = List<String>.from(json);
        });
      }
    } catch (e) {
      debugPrint('Error loading feeds: $e');
    }
  }

  Future<void> _saveFeeds() async {
    try {
      final file = await _getFeedsFile();
      await file.writeAsString(jsonEncode(_feeds));
    } catch (e) {
      debugPrint('Error saving feeds: $e');
    }
  }

  Future<void> _fetchHeadlines() async {
    if (_feeds.isEmpty) {
      setState(() {
        _headlines = ['No feeds configured. Add feeds in Manage Feeds.'];
      });
      return;
    }

    List<String> allHeadlines = [];

    for (String feedUrl in _feeds) {
      final normalizedFeedUrl = _normalizeFeedUrl(feedUrl);
      try {
        final uri = Uri.tryParse(normalizedFeedUrl);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          _logFeedError(
            feedUrl: feedUrl,
            normalizedFeedUrl: normalizedFeedUrl,
            reason: 'Invalid URL',
          );
          allHeadlines.add('Error loading ($feedUrl): Invalid URL');
          continue;
        }

        final response = await http
            .get(
              uri,
              headers: const {'User-Agent': 'rss-ticker/1.0 (+Flutter)'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final responseBody = utf8.decode(
            response.bodyBytes,
            allowMalformed: true,
          );
          final parseResult = _extractTitlesFromFeed(responseBody);
          if (parseResult.titles.isNotEmpty) {
            allHeadlines.addAll(parseResult.titles);
          } else {
            final reason = parseResult.error ?? 'No entries found in feed';
            _logFeedError(
              feedUrl: feedUrl,
              normalizedFeedUrl: normalizedFeedUrl,
              reason: reason,
            );
            allHeadlines.add('Error loading ($feedUrl): $reason');
          }
        } else {
          final reason =
              'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}'
                  .trim();
          _logFeedError(
            feedUrl: feedUrl,
            normalizedFeedUrl: normalizedFeedUrl,
            reason: reason,
          );
          allHeadlines.add('Error loading ($feedUrl): $reason');
        }
      } on TimeoutException catch (e) {
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: 'Request timeout',
          error: e,
        );
        allHeadlines.add('Error loading ($feedUrl): Request timeout');
      } on SocketException catch (e) {
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: 'Network error',
          error: e,
        );
        allHeadlines.add('Error loading ($feedUrl): Network error');
      } on HttpException catch (e) {
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: 'HTTP exception',
          error: e,
        );
        allHeadlines.add('Error loading ($feedUrl): HTTP exception');
      } catch (e) {
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: 'Unexpected error',
          error: e,
        );
        allHeadlines.add('Error loading ($feedUrl): Unexpected error');
      }
    }

    setState(() {
      _headlines = allHeadlines.isNotEmpty
          ? allHeadlines
          : ['No headlines found'];
    });
  }

  String _normalizeFeedUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    String normalized = trimmed;
    Uri? uri = Uri.tryParse(normalized);

    if (uri == null || uri.scheme.isEmpty) {
      normalized = 'https://$trimmed';
      uri = Uri.tryParse(normalized);
    }

    if (uri == null) {
      return normalized;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if ((host == 'github.com' || host == 'www.github.com') &&
        path.startsWith('/blog.atom')) {
      return 'https://github.blog/feed/';
    }

    return normalized;
  }

  _FeedParseResult _extractTitlesFromFeed(String xml) {
    Object? rssError;
    try {
      final rssFeed = RssFeed.parse(xml);
      final titles = (rssFeed.items ?? [])
          .map((item) => item.title?.trim())
          .where((title) => title != null && title.isNotEmpty)
          .cast<String>()
          .toList();
      if (titles.isNotEmpty) {
        return _FeedParseResult(titles: titles);
      }
    } catch (e) {
      rssError = e;
    }

    Object? atomError;
    try {
      final atomFeed = AtomFeed.parse(xml);
      final atomTitles = (atomFeed.items ?? [])
          .map((item) => item.title?.trim())
          .where((title) => title != null && title.isNotEmpty)
          .cast<String>()
          .toList();
      if (atomTitles.isNotEmpty) {
        return _FeedParseResult(titles: atomTitles);
      }
    } catch (e) {
      atomError = e;
    }

    String reason = 'No entries found in feed';
    if (rssError != null || atomError != null) {
      reason =
          'Parse failed (rss: ${rssError ?? 'n/a'}, atom: ${atomError ?? 'n/a'})';
    }

    return _FeedParseResult(titles: const [], error: reason);
  }

  void _logFeedError({
    required String feedUrl,
    required String normalizedFeedUrl,
    required String reason,
    Object? error,
  }) {
    final suffix = error != null ? ' | error: $error' : '';
    debugPrint(
      'Feed load error | input: $feedUrl | normalized: $normalizedFeedUrl | reason: $reason$suffix',
    );
  }

  void _onMenuSelected(String value) {
    _closeMenu();
    switch (value) {
      case 'refresh':
        _scrollController.jumpTo(0);
        _fetchHeadlines();
        _showSnackBar('Refreshing feeds...');
        break;
      case 'settings':
        _showSnackBar('Opening settings...');
        break;
      case 'manage_feeds':
        showDialog(
          context: context,
          builder: (context) => ManageFeedsDialog(
            feeds: _feeds,
            onFeedsChanged: (newFeeds) {
              setState(() => _feeds = newFeeds);
              _saveFeeds();
              _fetchHeadlines();
            },
          ),
        );
        break;
      case 'help':
        _showSnackBar('Showing help...');
        break;
      case 'exit':
        exit(0);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            child: Container(
              color: Colors.blue.shade900,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _repeatCount,
                      itemBuilder: (context, index) {
                        final headlineIndex =
                            index %
                            (_headlines.isNotEmpty ? _headlines.length : 1);
                        final headline = _headlines.isNotEmpty
                            ? _headlines[headlineIndex]
                            : 'Loading feeds...';
                        return Center(
                          child: Text(
                            ' +++ $headline +++ ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleMenu,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isMenuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              top: 30,
              right: 10,
              width: 200,
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuItem('Refresh', 'refresh'),
                    _buildMenuItem('Manage Feeds', 'manage_feeds'),
                    const Divider(height: 1),
                    _buildMenuItem('Settings', 'settings'),
                    _buildMenuItem('Help', 'help'),
                    const Divider(height: 1),
                    _buildMenuItem('Exit', 'exit'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, String value) {
    return InkWell(
      onTap: () => _onMenuSelected(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(
          label,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }
}

class _FeedParseResult {
  final List<String> titles;
  final String? error;

  const _FeedParseResult({required this.titles, this.error});
}

class ManageFeedsDialog extends StatefulWidget {
  final List<String> feeds;
  final ValueChanged<List<String>> onFeedsChanged;

  const ManageFeedsDialog({
    super.key,
    required this.feeds,
    required this.onFeedsChanged,
  });

  @override
  State<ManageFeedsDialog> createState() => _ManageFeedsDialogState();
}

class _ManageFeedsDialogState extends State<ManageFeedsDialog> {
  late List<String> _feeds;
  final Set<int> _selectedIndices = {};
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _feeds = List.from(widget.feeds);
  }

  void _addFeed() {
    final normalizedInput = _urlController.text.trim();
    if (normalizedInput.isNotEmpty) {
      setState(() {
        _feeds.add(normalizedInput);
        _urlController.clear();
        _selectedIndices.clear();
      });
      widget.onFeedsChanged(_feeds);
    }
  }

  void _removeSelected() {
    setState(() {
      _feeds = _feeds
          .asMap()
          .entries
          .where((entry) => !_selectedIndices.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      _selectedIndices.clear();
    });
    widget.onFeedsChanged(_feeds);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Manage Feeds',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Select')),
                    DataColumn(label: Text('Nr.')),
                    DataColumn(label: Text('URL')),
                  ],
                  rows: _feeds.asMap().entries.map((entry) {
                    int index = entry.key;
                    String url = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedIndices.contains(index),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          SizedBox(
                            width: 400,
                            child: Text(url, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'New Feed URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addFeed, child: const Text('+')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _removeSelected,
                  child: const Text('-'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
