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
  Timer? _scrollTimer;
  DateTime? _lastScrollTick;
  List<String> _feeds = [];
  List<String> _headlines = [];

  double _textSpeed = 60;
  Color _foregroundColor = Colors.white;
  Color _backgroundColor = const Color(0xFF0D47A1);
  String _separator = '+++';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTicker();
    });
  }

  Future<void> _initializeTicker() async {
    await _loadConfig();
    await _loadFeeds();
    if (!mounted) return;
    await _fetchHeadlines();
    _restartScrolling();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _restartScrolling() {
    _scrollTimer?.cancel();
    _lastScrollTick = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        final position = _scrollController.position;
        final maxExtent = position.maxScrollExtent;
        final now = DateTime.now();
        final previous = _lastScrollTick ?? now;
        _lastScrollTick = now;

        if (maxExtent <= 0) {
          return;
        }

        final deltaSeconds =
            now.difference(previous).inMicroseconds /
            Duration.microsecondsPerSecond;
        final nextOffset = position.pixels + (_textSpeed * deltaSeconds);

        if (nextOffset >= maxExtent) {
          _scrollController.jumpTo(0);
          return;
        }

        _scrollController.jumpTo(nextOffset);
      });
    });
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

  Future<Directory> _getStorageDirectory() async {
    final homeDir =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final dir = Directory('$homeDir/.rssticker');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _getFeedsFile() async {
    final dir = await _getStorageDirectory();
    return File('${dir.path}/feeds.json');
  }

  Future<File> _getConfigFile() async {
    final dir = await _getStorageDirectory();
    return File('${dir.path}/config.json');
  }

  Future<void> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (!await file.exists()) {
        return;
      }

      final contents = await file.readAsString();
      final Map<String, dynamic> json =
          jsonDecode(contents) as Map<String, dynamic>;

      setState(() {
        _textSpeed = _readDouble(json['textSpeed'], fallback: 60);
        _foregroundColor = _readColor(
          json['foregroundColor'],
          fallback: Colors.white,
        );
        _backgroundColor = _readColor(
          json['backgroundColor'],
          fallback: const Color(0xFF0D47A1),
        );
        _separator = _readSeparator(json['separator'], fallback: '+++');
      });
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final file = await _getConfigFile();
      final json = {
        'textSpeed': _textSpeed,
        'foregroundColor': _colorToHex(_foregroundColor),
        'backgroundColor': _colorToHex(_backgroundColor),
        'separator': _separator,
      };
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  double _readDouble(Object? value, {required double fallback}) {
    if (value is num) {
      return value.toDouble().clamp(10, 300);
    }
    return fallback;
  }

  String _readSeparator(Object? value, {required String fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  Color _readColor(Object? value, {required Color fallback}) {
    if (value is String) {
      final hex = value.replaceAll('#', '');
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(parsed);
        }
      }
      if (hex.length == 6) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(0xFF000000 | parsed);
        }
      }
    }
    return fallback;
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32();
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
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

    final List<String> allHeadlines = [];

    for (final feedUrl in _feeds) {
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
        showDialog(
          context: context,
          builder: (context) => SettingsDialog(
            initialSpeed: _textSpeed,
            initialForegroundColor: _foregroundColor,
            initialBackgroundColor: _backgroundColor,
            initialSeparator: _separator,
            onSettingsChanged:
                ({
                  required double speed,
                  required Color foregroundColor,
                  required Color backgroundColor,
                  required String separator,
                }) {
                  final speedChanged = (_textSpeed - speed).abs() > 0.01;
                  setState(() {
                    _textSpeed = speed;
                    _foregroundColor = foregroundColor;
                    _backgroundColor = backgroundColor;
                    _separator = separator;
                  });
                  if (speedChanged) {
                    _restartScrolling();
                  }
                },
          ),
        ).then((_) {
          _saveConfig();
        });
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
              color: _backgroundColor,
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
                            ' $_separator $headline $_separator ',
                            style: TextStyle(
                              color: _foregroundColor,
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
                    final index = entry.key;
                    final url = entry.value;
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

class SettingsDialog extends StatefulWidget {
  final double initialSpeed;
  final Color initialForegroundColor;
  final Color initialBackgroundColor;
  final String initialSeparator;
  final void Function({
    required double speed,
    required Color foregroundColor,
    required Color backgroundColor,
    required String separator,
  })
  onSettingsChanged;

  const SettingsDialog({
    super.key,
    required this.initialSpeed,
    required this.initialForegroundColor,
    required this.initialBackgroundColor,
    required this.initialSeparator,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _speed;
  late Color _foregroundColor;
  late Color _backgroundColor;
  late TextEditingController _separatorController;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed;
    _foregroundColor = widget.initialForegroundColor;
    _backgroundColor = widget.initialBackgroundColor;
    _separatorController = TextEditingController(text: widget.initialSeparator);
  }

  @override
  void dispose() {
    _separatorController.dispose();
    super.dispose();
  }

  void _emitSettingsChanged() {
    final separator = _separatorController.text.trim().isEmpty
        ? '+++'
        : _separatorController.text.trim();

    widget.onSettingsChanged(
      speed: _speed,
      foregroundColor: _foregroundColor,
      backgroundColor: _backgroundColor,
      separator: separator,
    );
  }

  Future<void> _pickForegroundColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: _foregroundColor),
    );
    if (selected != null) {
      setState(() {
        _foregroundColor = selected;
      });
      _emitSettingsChanged();
    }
  }

  Future<void> _pickBackgroundColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: _backgroundColor),
    );
    if (selected != null) {
      setState(() {
        _backgroundColor = selected;
      });
      _emitSettingsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height - 48;
    final targetHeight = availableHeight.clamp(520.0, 620.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 700,
        height: targetHeight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.92,
            minHeight: targetHeight,
            maxHeight: targetHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('Textgeschwindigkeit: ${_speed.toStringAsFixed(0)} px/s'),
                Slider(
                  value: _speed,
                  min: 10,
                  max: 300,
                  divisions: 58,
                  label: _speed.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() {
                      _speed = value;
                    });
                    _emitSettingsChanged();
                  },
                ),
                const SizedBox(height: 8),
                _buildColorChooser(
                  label: 'Textfarbe Vordergrund',
                  color: _foregroundColor,
                  onPressed: _pickForegroundColor,
                ),
                const SizedBox(height: 8),
                _buildColorChooser(
                  label: 'Textfarbe Hintergrund',
                  color: _backgroundColor,
                  onPressed: _pickBackgroundColor,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _separatorController,
                  decoration: const InputDecoration(
                    labelText: 'Trennzeichen zwischen den Entries',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emitSettingsChanged(),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorChooser({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onPressed, child: const Text('Choose')),
      ],
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _red;
  late double _green;
  late double _blue;

  @override
  void initState() {
    super.initState();
    _red = widget.initialColor.r.toDouble();
    _green = widget.initialColor.g.toDouble();
    _blue = widget.initialColor.b.toDouble();
  }

  Color get _currentColor =>
      Color.fromARGB(255, _red.round(), _green.round(), _blue.round());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Color',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(height: 12),
                _buildChannelSlider(
                  label: 'R',
                  value: _red,
                  activeColor: Colors.red,
                  onChanged: (v) => setState(() => _red = v),
                ),
                _buildChannelSlider(
                  label: 'G',
                  value: _green,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => _green = v),
                ),
                _buildChannelSlider(
                  label: 'B',
                  value: _blue,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() => _blue = v),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_currentColor),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSlider({
    required String label,
    required double value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value,
            activeColor: activeColor,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text(value.round().toString())),
      ],
    );
  }
}
