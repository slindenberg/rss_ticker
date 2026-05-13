import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/ticker_entry.dart';
import 'app_theme.dart';

/// Horizontally scrolling ticker bar that displays [TickerEntry] headlines.
///
/// Delegates scroll control entirely to the provided [scrollController].
/// Hover state is propagated outward via [onHoverChanged] and
/// [onItemHoverChanged] so the parent can pause/resume scrolling.
class TickerBar extends StatelessWidget {
  /// The entries to display; shows a loading placeholder when empty.
  final List<TickerEntry> entries;

  /// Current app configuration (separator, colors).
  final AppConfig config;

  /// External scroll controller managed by [TickerScrollMixin].
  final ScrollController scrollController;

  /// Index of the currently hovered item, or `null`.
  final int? hoveredItemIndex;

  /// Called when the pointer enters or leaves the entire ticker bar.
  final void Function(bool) onHoverChanged;

  /// Called when the pointer enters or leaves an individual item.
  final void Function(int?) onItemHoverChanged;

  /// Called when the user taps a clickable entry.
  final void Function(TickerEntry) onEntryTapped;

  const TickerBar({
    super.key,
    required this.entries,
    required this.config,
    required this.scrollController,
    required this.hoveredItemIndex,
    required this.onHoverChanged,
    required this.onItemHoverChanged,
    required this.onEntryTapped,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onHover: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: entries.isEmpty ? 1 : entries.length,
        itemBuilder: (context, index) {
          final entry = entries.isNotEmpty
              ? entries[index]
              : const TickerEntry(title: 'Loading feeds...');
          final hasLink = (entry.link?.trim().isNotEmpty ?? false);
          final isHoveredLink = hasLink && hoveredItemIndex == index;
          return Center(
            child: MouseRegion(
              cursor: hasLink
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onEnter: (_) {
                if (hasLink) onItemHoverChanged(index);
              },
              onExit: (_) {
                if (hoveredItemIndex == index) onItemHoverChanged(null);
              },
              child: InkWell(
                onTap: hasLink ? () => onEntryTapped(entry) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ' ${config.separator} ${entry.title} ${config.separator} ',
                    style: TickerTheme.tickerText(
                      color: Theme.of(context).colorScheme.primary,
                      underline: isHoveredLink,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
