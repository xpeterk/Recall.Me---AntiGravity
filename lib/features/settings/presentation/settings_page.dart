import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import 'ai_services_page.dart';
import 'bubble_library_page.dart';
import 'placeholder_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 28),
            const SizedBox(width: 8),
            const Text("Recall.Me"),
          ],
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, "AI Services"),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text("API Keys"),
            subtitle: const Text("Manage Gemini, Pinecone, Notion keys"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AiServicesPage()),
              );
            },
          ),
          
          _buildSectionHeader(context, "Bubble Management"),
          ListTile(
            leading: const Icon(Icons.bubble_chart),
            title: const Text("Bubble Types"),
            subtitle: const Text("Configure triggers and prompts"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BubbleLibraryPage()),
              );
            },
          ),
          
          _buildSectionHeader(context, "System"),
           ListTile(
            leading: const Icon(Icons.mic),
            title: const Text("Note Transcription"),
            subtitle: const Text("Engine settings & sensitivity"),
             trailing: const Icon(Icons.chevron_right),
            onTap: () {
               Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PlaceholderPage(
                  title: "Transcription Engine",
                  message: "Switch between On-Device, Cloud, and Hybrid engines. Adjust microphone sensitivity and silence detection.",
                )),
              );
            },
          ),
          
          _buildSectionHeader(context, "Data Management"),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.orange),
            title: const Text("Clear Raw Transcripts"),
            subtitle: const Text("Delete only your speech text, keep AI memories"),
            onTap: () {
               showDialog(
                 context: context,
                 builder: (context) => AlertDialog(
                   title: const Text("Clear Raw Transcripts?"),
                   content: const Text("This will remove all your speech text bubbles. AI Analysis and Notion checks will be kept."),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                     TextButton(
                       onPressed: () async {
                         Navigator.pop(context); // Close dialog
                         // We need the VM. Since SettingsPage is usually pushed, we should access Provider.
                         // But SettingsPage is stateless and built with context.
                         // Ensure Provider is available in context (it is, above MaterialApp).
                         await Provider.of<TranscriptionViewModel>(context, listen: false).clearRawTranscripts();
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transcripts Cleared")));
                       }, 
                       child: const Text("Clear", style: TextStyle(color: Colors.orange)),
                     ),
                   ],
                 ),
               );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Clear All History"),
            subtitle: const Text("Delete EVERYTHING: Transcripts, AI Memories, and Logs"),
            onTap: () {
               showDialog(
                 context: context,
                 builder: (context) => AlertDialog(
                   title: const Text("Delete Everything?"),
                   content: const Text("This cannot be undone. All history will be wiped."),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                     TextButton(
                       onPressed: () async {
                         Navigator.pop(context);
                         await Provider.of<TranscriptionViewModel>(context, listen: false).clearAllHistory();
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History Wiped")));
                       }, 
                       child: const Text("DELETE ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                     ),
                   ],
                 ),
               );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
