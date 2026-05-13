/// A single item displayed in the ticker bar.
///
/// [title] is the headline text shown in the scrolling bar.
/// [link] is an optional URL opened when the user clicks the item.
class TickerEntry {
  /// The headline text for this entry.
  final String title;

  /// Optional URL to open when the entry is tapped. `null` means non-clickable.
  final String? link;

  const TickerEntry({required this.title, this.link});
}
