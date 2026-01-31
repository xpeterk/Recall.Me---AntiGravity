import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotionHelpBottomSheet extends StatelessWidget {
  const NotionHelpBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/images/notion_logo.png', width: 32, errorBuilder: (_,__,___) => const Icon(Icons.info, size: 32)),
                const SizedBox(width: 12),
                Text(
                  "Notion RAG Setup",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "1. Create an Integration Token:",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://www.notion.so/my-integrations')),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  "   👉 Click here to create at notion.so/my-integrations",
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ),
            Text(
              "2. Go to your Notion Page (e.g. 'RecallMe RAG').\n"
              "3. Click '...' (top right) > Connections > Connect to.\n"
              "4. Select the integration you just created.\n\n"
              "Optional: To limit access to one folder:\n"
              "5. On your 'RecallMe RAG' page, click 'Share' > 'Copy link'.\n"
              "6. Paste that link in the 'Root Page Link' field in Settings.\n\n"
              "For best results, organize your Database with these columns:", // existing text
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildTable(context),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text("Got it"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
      },
      children: [
        _buildRow(context, "Column Name", "Type", isHeader: true),
        _buildRow(context, "Question", "Title (Primary)"),
        _buildRow(context, "Short Answer", "Rich Text (Default Output)"),
        _buildRow(context, "Long Answer", "Rich Text (Optional Details)"),
        _buildRow(context, "Keywords", "Multi-Select (Synonyms)"),
        _buildRow(context, "Alternative Questions", "Rich Text (Variations)"),
      ],
    );
  }

  TableRow _buildRow(BuildContext context, String col1, String col2, {bool isHeader = false}) {
    final style = isHeader 
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
        : const TextStyle(fontSize: 13);
    final bg = isHeader ? Theme.of(context).colorScheme.surfaceContainerHighest : null;

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(col1, style: style)),
        Padding(padding: const EdgeInsets.all(8.0), child: Text(col2, style: style)),
      ],
    );
  }
}
