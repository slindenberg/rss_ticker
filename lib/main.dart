import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/feeds_storage.dart';
import 'models/ticker_entry.dart';
import 'network/feed_fetcher.dart';
import 'widgets/manage_feeds_dialog.dart';
import 'widgets/settings_dialog.dart';

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

  bool _isMenuOpen = false;
  Timer? _scrollTimer;
  Timer? _refreshTimer;
  DateTime? _lastScrollTick;
  int _scrollSession = 0;
  List<String> _feeds = [];
  List<TickerEntry> _entries = [];
  bool _isTickerHovered = false;
  int? _hoveredTickerItemIndex;

  AppConfig _config = const AppConfig();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTicker();
    });
  }

  Future<void> _initializeTicker() async {
    final storageDir = await getStorageDirectory();
    debugPrint('Default directory: ${storageDir.path}');
    await _loadConfig();
    await _loadFeeds();
    if (!mounted) return;
    await _fetchHeadlines();
    _restartScrolling();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _restartScrolling() {
    _scrollSession++;
    final session = _scrollSession;
    _scrollTimer?.cancel();
    _lastScrollTick = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session != _scrollSession) return;

      _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (session != _scrollSession) {
          _scrollTimer?.cancel();
          return;
        }

        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        final position = _scrollController.position;
        final maxExtent = position.maxScrollExtent;
        final now = DateTime.now();
        final previous = _lastScrollTick ?? now;
        _lastScrollTick = now;

        if (_isTickerHovered) {
          return;
        }

        if (maxExtent <= 0) {
          return;
        }

        final deltaSeconds =
            now.difference(previous).inMicroseconds /
            Duration.microsecondsPerSecond;
        final nextOffset = position.pixels + (_config.textSpeed * deltaSeconds);

        if (nextOffset >= maxExtent) {
          _scrollController.jumpTo(0);
          return;
        }

        _scrollController.jumpTo(nextOffset);
      });
    });
  }

  void _pauseScrolling() {
    _scrollSession++;
    _scrollTimer?.cancel();
    _scrollTimer = null;
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

  Future<void> _loadConfig() async {
    final config = await loadConfig();
    setState(() {
      _config = config;
    });
    _restartRefreshTimer();
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    final interval = _config.refreshIntervalMinutes;
    if (interval <= 0) return;
    _refreshTimer = Timer.periodic(Duration(minutes: interval), (_) {
      _fetchHeadlines();
    });
  }

  Future<void> _saveConfig() async {
    await saveConfig(_config);
  }

  Future<void> _loadFeeds() async {
    final feeds = await loadFeeds();
    setState(() {
      _feeds = feeds;
    });
  }

  Future<void> _saveFeeds() async {
    await saveFeeds(_feeds);
  }

  Future<void> _fetchHeadlines() async {
    debugPrint(
      '[RSS Ticker] Fetching feeds at ${DateTime.now().toIso8601String()}...',
    );
    final entries = await fetchHeadlines(_feeds);
    if (!mounted) return;
    debugPrint(
      '[RSS Ticker] Feed update complete: ${entries.length} entries loaded.',
    );
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _openEntry(TickerEntry entry) async {
    final rawLink = entry.link?.trim();
    if (rawLink == null || rawLink.isEmpty) {
      _showSnackBar('No link available for this entry.');
      return;
    }

    Uri? uri = Uri.tryParse(rawLink);
    if (uri != null && !uri.hasScheme) {
      uri = Uri.tryParse('https://$rawLink');
    }

    if (uri == null || !uri.hasScheme) {
      _showSnackBar('Invalid link: $rawLink');
      return;
    }

    debugPrint('Ticker link clicked: ${uri.toString()}');

    final launched = await tryOpenInBrowser(uri);
    if (!launched) {
      _showSnackBar('Could not open link in browser.');
    }
  }

  void _setTickerHovered(bool isHovered) {
    if (_isTickerHovered == isHovered) {
      return;
    }

    _isTickerHovered = isHovered;

    if (isHovered) {
      _pauseScrolling();
      return;
    }

    _hoveredTickerItemIndex = null;
    _restartScrolling();
  }

  void _setHoveredTickerItemIndex(int? index) {
    if (_hoveredTickerItemIndex == index || !mounted) {
      return;
    }

    setState(() {
      _hoveredTickerItemIndex = index;
    });
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
            initialSpeed: _config.textSpeed,
            initialForegroundColor: _config.foregroundColor,
            initialBackgroundColor: _config.backgroundColor,
            initialSeparator: _config.separator,
            initialRefreshInterval: _config.refreshIntervalMinutes,
            onSettingsChanged:
                ({
                  required double speed,
                  required Color foregroundColor,
                  required Color backgroundColor,
                  required String separator,
                  required int refreshIntervalMinutes,
                }) {
                  final speedChanged = (_config.textSpeed - speed).abs() > 0.01;
                  final refreshChanged =
                      _config.refreshIntervalMinutes != refreshIntervalMinutes;
                  setState(() {
                    _config = _config.copyWith(
                      textSpeed: speed,
                      foregroundColor: foregroundColor,
                      backgroundColor: backgroundColor,
                      separator: separator,
                      refreshIntervalMinutes: refreshIntervalMinutes,
                    );
                  });
                  if (speedChanged) {
                    _restartScrolling();
                  }
                  if (refreshChanged) {
                    _restartRefreshTimer();
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
              color: _config.backgroundColor,
              child: Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => _setTickerHovered(true),
                      onHover: (_) => _setTickerHovered(true),
                      onExit: (_) => _setTickerHovered(false),
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _entries.isEmpty ? 1 : _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries.isNotEmpty
                              ? _entries[index]
                              : const TickerEntry(title: 'Loading feeds...');
                          final hasLink =
                              (entry.link?.trim().isNotEmpty ?? false);
                          final isHoveredLink =
                              hasLink && _hoveredTickerItemIndex == index;
                          return Center(
                            child: MouseRegion(
                              cursor: hasLink
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              onEnter: (_) {
                                if (hasLink) {
                                  _setHoveredTickerItemIndex(index);
                                }
                              },
                              onExit: (_) {
                                if (_hoveredTickerItemIndex == index) {
                                  _setHoveredTickerItemIndex(null);
                                }
                              },
                              child: InkWell(
                                onTap: hasLink ? () => _openEntry(entry) : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    ' ${_config.separator} ${entry.title} ${_config.separator} ',
                                    style: TextStyle(
                                      color: _config.foregroundColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      decoration: isHoveredLink
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                      decorationColor: _config.foregroundColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
