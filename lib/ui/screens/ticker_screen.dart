import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../bus/logic/ticker_scroll_mixin.dart';
import '../../models/ticker_entry.dart';
import '../../bus/services/ticker_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/dialog_handlers.dart';
import '../widgets/ticker_bar.dart';
import '../widgets/ticker_overlay.dart';

class TickerScreen extends StatefulWidget {
  const TickerScreen({super.key});

  @override
  State<TickerScreen> createState() => _TickerScreenState();
}

class _TickerScreenState extends State<TickerScreen>
    with TickerScrollMixin<TickerScreen> {
  @override
  AppConfig get tickerConfig => _config;

  bool _isMenuOpen = false;
  Timer? _refreshTimer;
  List<String> _feeds = [];
  List<TickerEntry> _entries = [];
  AppConfig _config = const AppConfig();

  /// Feed title shown in the static label; updated by the scroll listener.
  String? _currentFeedTitle;

  /// Pre-computed cumulative item widths used by the scroll listener.
  List<double> _cumulativeItemWidths = [];

  final _service = TickerService();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_updateCurrentFeedTitle);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeTicker());
  }

  @override
  void dispose() {
    scrollController.removeListener(_updateCurrentFeedTitle);
    scrollTimer?.cancel();
    _refreshTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> _initializeTicker() async {
    await _service.initialize();
    await _loadConfig();
    await _loadFeeds();
    if (!mounted) return;
    await _fetchHeadlines();
    restartScrolling();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadConfig() async {
    final config = await _service.loadConfig();
    if (!mounted) return;
    setState(() => _config = config);
    _restartRefreshTimer();
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    final interval = _config.refreshIntervalMinutes;
    if (interval <= 0) return;
    _refreshTimer = Timer.periodic(
      Duration(minutes: interval),
      (_) => _fetchHeadlines(),
    );
  }

  Future<void> _loadFeeds() async {
    final feeds = await _service.loadFeeds();
    if (!mounted) return;
    setState(() => _feeds = feeds);
  }

  Future<void> _fetchHeadlines() async {
    final entries = await _service.fetchHeadlines(_feeds);
    if (!mounted) return;
    setState(() => _entries = entries);
    _computeCumulativeWidths();
    _updateCurrentFeedTitle();
  }

  /// Pre-computes the cumulative pixel widths of all ticker items so the
  /// scroll listener can efficiently determine the currently visible entry.
  void _computeCumulativeWidths() {
    const style = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    double cumulative = 0;
    _cumulativeItemWidths = List<double>.generate(_entries.length, (i) {
      final text =
          ' ${_config.separator} ${_entries[i].title} ${_config.separator} ';
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      cumulative += tp.width + 8; // 8 = horizontal padding
      return cumulative;
    });
  }

  /// Scroll listener: finds the entry whose right edge first exceeds the
  /// current scroll offset, then updates [_currentFeedTitle].
  void _updateCurrentFeedTitle() {
    if (!_config.showFeedTitle || !_config.feedTitleStatic) return;
    if (_entries.isEmpty || _cumulativeItemWidths.isEmpty) return;
    if (!scrollController.hasClients) return;

    final offset = scrollController.offset;
    String? title;
    for (int i = 0; i < _cumulativeItemWidths.length; i++) {
      if (_cumulativeItemWidths[i] > offset) {
        title = _entries[i].feedTitle;
        break;
      }
    }
    title ??= _entries.last.feedTitle;
    if (title != _currentFeedTitle) {
      setState(() => _currentFeedTitle = title);
    }
  }

  Future<void> _openEntry(TickerEntry entry) async {
    final launched = await _service.openEntry(entry);
    if (!launched) _showSnackBar('Could not open link.');
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  void _toggleMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  void _closeMenu() {
    if (_isMenuOpen) setState(() => _isMenuOpen = false);
  }

  Future<void> _onMenuSelected(String value) async {
    _closeMenu();
    switch (value) {
      case 'refresh':
        scrollController.jumpTo(0);
        _fetchHeadlines();
        _showSnackBar('Refreshing feeds...');
      case 'settings':
        await showSettingsDialog(
          context: context,
          config: _config,
          onChanged:
              (
                updated, {
                required bool speedChanged,
                required bool refreshChanged,
              }) {
                setState(() => _config = updated);
                if (speedChanged) restartScrolling();
                if (refreshChanged) _restartRefreshTimer();
                _computeCumulativeWidths();
              },
        );
        await _service.saveConfig(_config);
      case 'manage_feeds':
        await showManageFeedsDialog(
          context: context,
          feeds: _feeds,
          onChanged: (newFeeds) {
            setState(() => _feeds = newFeeds);
            _service.saveFeeds(newFeeds);
            _fetchHeadlines();
          },
        );
      case 'help':
        _showSnackBar('Showing help...');
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TickerTheme.themeData(_config),
      child: Scaffold(
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
                    if (_config.showFeedTitle && _config.feedTitleStatic)
                      _buildStaticFeedTitle(),
                    Expanded(
                      child: TickerBar(
                        entries: _entries,
                        config: _config,
                        scrollController: scrollController,
                        hoveredItemIndex: hoveredTickerItemIndex,
                        onHoverChanged: setTickerHovered,
                        onItemHoverChanged: setHoveredTickerItemIndex,
                        onEntryTapped: _openEntry,
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
                child: TickerOverlay(onMenuSelected: _onMenuSelected),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaticFeedTitle() {
    final title = _currentFeedTitle ?? '';
    if (title.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: double.infinity,
          color: _config.foregroundColor,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: _config.backgroundColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: _config.foregroundColor.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}
