/// A single item displayed in the ticker bar.
///
/// [title] is the headline text shown in the scrolling bar.
/// [link] is an optional URL opened when the user clicks the item.
/// [feedTitle] is the title of the RSS/Atom channel this entry came from.
class TickerEntry {
  /// The headline text for this entry.
  final String title;

  /// Optional URL to open when the entry is tapped. `null` means non-clickable.
  final String? link;

  /// The title of the feed channel this entry belongs to, e.g. "BBC News".
  final String? feedTitle;

  const TickerEntry({required this.title, this.link, this.feedTitle});
}
