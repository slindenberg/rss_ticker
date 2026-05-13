import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';

mixin TickerScrollMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  Timer? scrollTimer;
  DateTime? lastScrollTick;
  int scrollSession = 0;
  bool isTickerHovered = false;
  int? hoveredTickerItemIndex;

  AppConfig get tickerConfig;

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

  void pauseScrolling() {
    scrollSession++;
    scrollTimer?.cancel();
    scrollTimer = null;
  }

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

  void setHoveredTickerItemIndex(int? index) {
    if (hoveredTickerItemIndex == index || !mounted) return;
    setState(() {
      hoveredTickerItemIndex = index;
    });
  }
}
