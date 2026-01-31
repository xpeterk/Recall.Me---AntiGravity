class NotionPage {
  final String id;
  final String title;
  final DateTime lastEdited;
  final String url;
  bool isSelected;

  NotionPage({
    required this.id,
    required this.title,
    required this.lastEdited,
    required this.url,
    this.isSelected = false,
  });
}
