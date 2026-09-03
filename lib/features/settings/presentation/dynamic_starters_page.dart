import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../domain/dynamic_starter.dart';

class DynamicStartersPage extends StatefulWidget {
  const DynamicStartersPage({Key? key}) : super(key: key);

  @override
  State<DynamicStartersPage> createState() => _DynamicStartersPageState();
}

class _DynamicStartersPageState extends State<DynamicStartersPage> {
  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<TranscriptionViewModel>(context);
    final starters = vm.dynamicStarters;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversation Starters"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showStarterDialog(context, vm, null),
          )
        ],
      ),
      body: starters.isEmpty 
        ? const Center(child: Text("No dynamic starters configured."))
        : ListView.builder(
            itemCount: starters.length,
            itemBuilder: (context, index) {
              final starter = starters[index];
              return ListTile(
                title: Text(starter.name),
                subtitle: Text("Notion DB: ${starter.notionDatabaseId}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: starter.isActive,
                      onChanged: (val) {
                         // Update active status
                         final updated = List<DynamicStarter>.from(starters);
                         updated[index] = DynamicStarter(
                           id: starter.id, 
                           name: starter.name, 
                           notionDatabaseId: starter.notionDatabaseId,
                           prompt: starter.prompt,
                           isActive: val
                         );
                         _saveAndRefresh(vm, updated);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showStarterDialog(context, vm, starter),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                         final updated = List<DynamicStarter>.from(starters);
                         updated.removeAt(index);
                         _saveAndRefresh(vm, updated);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showStarterDialog(BuildContext context, TranscriptionViewModel vm, DynamicStarter? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    final dbIdCtrl = TextEditingController(text: existing?.notionDatabaseId ?? "");
    final promptCtrl = TextEditingController(text: existing?.prompt ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? "Add Starter" : "Edit Starter"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Display Name (e.g. Daily Brief)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dbIdCtrl,
                decoration: const InputDecoration(labelText: "Notion Database ID (Optional)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: promptCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Custom Instructions/Prompt (Optional)", alignLabelWithHint: true),
              ),
              const SizedBox(height: 8),
              const Text(
                "Note: Make sure your Notion template uses 'Summary:' and 'Content:' labels for the output.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final dbId = dbIdCtrl.text.trim();
              final prompt = promptCtrl.text.trim();
              if (name.isNotEmpty && (dbId.isNotEmpty || prompt.isNotEmpty)) {
                 final updated = List<DynamicStarter>.from(vm.dynamicStarters);
                 if (existing == null) {
                    updated.add(DynamicStarter(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      notionDatabaseId: dbId,
                      prompt: prompt.isEmpty ? null : prompt,
                    ));
                 } else {
                    final index = updated.indexWhere((s) => s.id == existing.id);
                    if (index != -1) {
                      updated[index] = DynamicStarter(
                        id: existing.id,
                        name: name,
                        notionDatabaseId: dbId,
                        prompt: prompt.isEmpty ? null : prompt,
                        isActive: existing.isActive,
                      );
                    }
                 }
                 _saveAndRefresh(vm, updated);
                 Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _saveAndRefresh(TranscriptionViewModel vm, List<DynamicStarter> newList) async {
     // Wait, we need to access settingsRepository from VM?
     // TranscriptionViewModel has no public saveDynamicStarters.
     // We should add saveDynamicStarters(List<DynamicStarter>) to TranscriptionViewModel.
     await vm.saveDynamicStarters(newList);
  }
}
