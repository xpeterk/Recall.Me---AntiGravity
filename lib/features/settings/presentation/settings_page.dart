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
          Consumer<TranscriptionViewModel>(
            builder: (context, vm, child) {
              return ListTile(
                leading: const Icon(Icons.mic),
                title: const Text("Note Transcription"),
                subtitle: Text(
                  vm.isGeminiEngine 
                      ? "Gemini 3.5 Transcribe Live (Cloud AI)" 
                      : "On-Device Speech Recognition (Offline)",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showTranscriptionEngineDialog(context, vm);
                },
              );
            },
          ),
          Consumer<TranscriptionViewModel>(
            builder: (context, vm, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.keyboard),
                title: const Text("Show Text Input Box"),
                subtitle: const Text("Display a manual text input box at the bottom of the conversation"),
                value: vm.showBottomTextInput,
                onChanged: (value) {
                  vm.toggleBottomTextInput(value);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("App Version"),
            subtitle: const Text("v1.3.0 (Build: 2026-07-06 17:00 PDT)"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               _showVersionHistoryDialog(context);
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

  void _showTranscriptionEngineDialog(BuildContext context, TranscriptionViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.indigoAccent),
                      const SizedBox(width: 8),
                      const Text(
                        "Speech Transcription Engine",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Choose how your voice is recognized in real time. You can also toggle this anytime directly from the Home Screen.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: vm.engineMode == TranscriptionEngineMode.native 
                          ? Colors.indigo.withOpacity(0.2) 
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vm.engineMode == TranscriptionEngineMode.native 
                            ? Colors.indigoAccent 
                            : Colors.white12,
                      ),
                    ),
                    child: RadioListTile<TranscriptionEngineMode>(
                      value: TranscriptionEngineMode.native,
                      groupValue: vm.engineMode,
                      activeColor: Colors.indigoAccent,
                      title: const Row(
                        children: [
                          Text("📱 On-Device Speech Recognition"),
                          SizedBox(width: 8),
                          Text("(Offline)", style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                        ],
                      ),
                      subtitle: const Text(
                        "Fastest local recognition using Android SpeechRecognizer. Works completely offline with zero data usage.",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      onChanged: (mode) {
                        if (mode != null) {
                          vm.setTranscriptionEngine(mode);
                          setModalState(() {});
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: vm.engineMode == TranscriptionEngineMode.gemini 
                          ? const Color(0xFF4F46E5).withOpacity(0.25) 
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vm.engineMode == TranscriptionEngineMode.gemini 
                            ? const Color(0xFF818CF8) 
                            : Colors.white12,
                      ),
                    ),
                    child: RadioListTile<TranscriptionEngineMode>(
                      value: TranscriptionEngineMode.gemini,
                      groupValue: vm.engineMode,
                      activeColor: const Color(0xFF818CF8),
                      title: const Row(
                        children: [
                          Text("✨ Gemini 3.5 Transcribe Live"),
                          SizedBox(width: 8),
                          Text("(Cloud AI)", style: TextStyle(fontSize: 11, color: Color(0xFF818CF8))),
                        ],
                      ),
                      subtitle: const Text(
                        "Real-time PCM audio streaming to Gemini Live API. High accuracy with smart formatting, filler-word removal, and Notion context biasing.",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      onChanged: (mode) {
                        if (mode != null) {
                          vm.setTranscriptionEngine(mode);
                          setModalState(() {});
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVersionHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text("Version History"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: const [
              _VersionHistoryItem(
                version: "v1.3.0 (Current)",
                date: "2026-07-06",
                changes: [
                  "Added Hybrid Transcription Engine: On-Device STT vs Gemini 3.5 Transcribe Live.",
                  "Added one-tap Engine Toggle pill in Home Screen header.",
                  "Real-time PCM 16kHz audio streaming to Gemini Live API over WebSockets.",
                  "Notion context biasing and custom vocabulary injection for smart transcription.",
                ],
              ),
              Divider(color: Colors.white24),
              _VersionHistoryItem(
                version: "v1.2.0",
                date: "2026-07-06",
                changes: [
                  "Added Home Screen Convo Starters icon in header.",
                  "Moved Paste Web Link context button into Convo Starters panel.",
                  "Added build timestamp & version history changelog popup to Settings.",
                ],
              ),
              Divider(color: Colors.white24),
              _VersionHistoryItem(
                version: "v1.1.0",
                date: "2026-07-05",
                changes: [
                  "Premium Pitch-Black & Slate UI redesign with Indigo highlights.",
                  "Mockup-accurate User Speeches and AI Insights bubble styling.",
                  "Top-level Notion database syncing only, pages synced as vector context.",
                  "Notion Short Answer retrieval and Notion capsule source pill.",
                  "Persistent Notion checkbox selections and sync status indicator.",
                  "Auto summaries for 10+ transcript segments with topic boundaries.",
                  "Show Diagnostics badge displaying confidence score on user bubbles.",
                ],
              ),
              Divider(color: Colors.white24),
              _VersionHistoryItem(
                version: "v1.0.0",
                date: "2026-07-01",
                changes: [
                  "Initial release of Recall.Me native speech transcription app.",
                  "Real-time continuous speech-to-text recognition.",
                  "Notion integration & semantic workspace synchronizer.",
                  "Settings and basic configurations.",
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class _VersionHistoryItem extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;

  const _VersionHistoryItem({
    Key? key,
    required this.version,
    required this.date,
    required this.changes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                version,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
              ),
              Text(
                date,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...changes.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.indigoAccent)),
                    Expanded(
                      child: Text(
                        c,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
