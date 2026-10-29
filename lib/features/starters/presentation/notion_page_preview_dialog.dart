import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/models/notion_library_note.dart';
import 'starter_refine_page.dart';
import '../domain/models/starter_item.dart';

class NotionPagePreviewDialog extends StatelessWidget {
  final NotionLibraryNote note;

  const NotionPagePreviewDialog({Key? key, required this.note}) : super(key: key);

  static Future<void> show(BuildContext context, NotionLibraryNote note) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotionPagePreviewDialog(note: note),
    );
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.trim().isEmpty) return;
    final uri = Uri.parse(urlString.trim());
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${note.editedAt.month}/${note.editedAt.day}/${note.editedAt.year}";

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF161619),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with category tag and close
          Row(
            children: [
              if (note.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    note.category!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                "Edited $formattedDate · ${note.pageCount} page${note.pageCount > 1 ? 's' : ''}",
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            note.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Content Scroll
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    note.excerpt,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (note.fullContent != null && note.fullContent != note.excerpt) ...[
                    const SizedBox(height: 12),
                    Text(
                      note.fullContent!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (note.suggestedAngles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Suggested angles for this note:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: note.suggestedAngles.map((angle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            angle,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (note.url != null && note.url!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchUrl(note.url),
                    icon: Image.asset(
                      'assets/images/notion_logo.png',
                      width: 14,
                      height: 14,
                      errorBuilder: (_, __, ___) => const Icon(Icons.description, size: 14),
                    ),
                    label: const Text("Open in Notion"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (note.url != null && note.url!.isNotEmpty)
                const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final starter = StarterItem(
                      id: "from_note_${note.id}",
                      title: note.title,
                      summary: note.excerpt,
                      category: note.category,
                      angles: note.suggestedAngles,
                      notionPageIds: [note.id],
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StarterRefinePage(starter: starter),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text("Refine & Start"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
