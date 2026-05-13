import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// Mixin that adds time-based horizontal auto-scrolling to a [State].
///
/// Apply this mixin to the [State] of a widget that owns a [ListView] with a
/// horizontal [ScrollController]. Override [tickerConfig] to provide the
/// current [AppConfig] so the scroll speed stays in sync with settings.
mixin TickerScrollMixin<T extends StatefulWidget> on State<T> {
  /// Controls the horizontal [ListView] being scrolled.
  final ScrollController scrollController = ScrollController();

  /// The active periodic scroll timer. `null` when scrolling is paused.
  Timer? scrollTimer;

  /// Timestamp of the last scroll tick, used for delta-time calculations.
  DateTime? lastScrollTick;

  /// Incremented each time scrolling is restarted, invalidating old timer callbacks.
  int scrollSession = 0;

  /// Whether the pointer is currently hovering over the ticker bar.
  bool isTickerHovered = false;

  /// Index of the currently hovered ticker item, or `null` if none.
  int? hoveredTickerItemIndex;

  /// Provides the current [AppConfig] used to read [AppConfig.textSpeed].
  AppConfig get tickerConfig;

  /// Starts (or restarts) the scroll timer.
  ///
  /// Cancels any running timer, increments [scrollSession] to invalidate
  /// stale callbacks, then schedules a new 60 fps periodic timer that advances
  /// the scroll position by `textSpeed * deltaTime` pixels per frame.
  /// Wraps back to the start when the end of the list is reached.
  void restartScrolling() {
    scrollSession++;
    final session = scrollSession;
    scrollTimer?.cancel();
    lastScrollTick = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session != scrollSession) return;

      scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (session != scrollSession) {
          scrollTimer?.cancel();
          return;
        }

        if (!mounted || !scrollController.hasClients) return;

        final position = scrollController.position;
        final maxExtent = position.maxScrollExtent;
        final now = DateTime.now();
        final previous = lastScrollTick ?? now;
        lastScrollTick = now;

        if (isTickerHovered) return;
        if (maxExtent <= 0) return;

        final deltaSeconds =
            now.difference(previous).inMicroseconds /
            Duration.microsecondsPerSecond;
        final nextOffset =
            position.pixels + (tickerConfig.textSpeed * deltaSeconds);

        if (nextOffset >= maxExtent) {
          scrollController.jumpTo(0);
          return;
        }

        scrollController.jumpTo(nextOffset);
      });
    });
  }

  /// Stops the scroll timer without restarting it.
  void pauseScrolling() {
    scrollSession++;
    scrollTimer?.cancel();
    scrollTimer = null;
  }

  /// Called when the pointer enters or leaves the ticker bar.
  ///
  /// Pauses scrolling on hover and resumes it when the pointer leaves.
  void setTickerHovered(bool isHovered) {
    if (isTickerHovered == isHovered) return;
    isTickerHovered = isHovered;

    if (isHovered) {
      pauseScrolling();
      return;
    }

    hoveredTickerItemIndex = null;
    restartScrolling();
  }

  /// Updates [hoveredTickerItemIndex] and triggers a rebuild.
  void setHoveredTickerItemIndex(int? index) {
    if (hoveredTickerItemIndex == index || !mounted) return;
    setState(() {
      hoveredTickerItemIndex = index;
    });
  }
}
