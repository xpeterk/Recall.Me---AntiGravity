class NotionPage {
  final String id;
  final String title;
  final DateTime lastEdited;
  final String url;
  final bool isDatabase;
  bool isSelected;

  NotionPage({
    required this.id,
    required this.title,
    required this.lastEdited,
    required this.url,
    this.isDatabase = false,
    this.isSelected = false,
  });
}
