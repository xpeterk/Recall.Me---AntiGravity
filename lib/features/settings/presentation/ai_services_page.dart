import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/glass_container.dart';
import '../../settings/domain/settings_repository.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../../knowledge/presentation/notion_help_bottom_sheet.dart';
import '../../starters/data/supabase_service.dart';

class AiServicesPage extends StatefulWidget {
  const AiServicesPage({Key? key}) : super(key: key);

  @override
  State<AiServicesPage> createState() => _AiServicesPageState();
}

class _AiServicesPageState extends State<AiServicesPage> {
  final _geminiController = TextEditingController();
  final _claudeController = TextEditingController();
  final _pineconeController = TextEditingController();
  final _notionController = TextEditingController();
  final TextEditingController _notionRootPageController = TextEditingController();
  bool _isLoading = true;
  bool _isGeminiVisible = false;
  bool _isClaudeVisible = false;
  bool _isNotionVisible = false;
  final Set<String> _customModelIds = {};

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final repo = Provider.of<SettingsRepository>(context, listen: false);
    
    // Load Gemini
    final geminiResult = await repo.getApiKey('gemini');
    geminiResult.fold(
      (failure) {
        // Fallback to .env if not in storage
        _geminiController.text = dotenv.env['GEMINI_API_KEY'] ?? '';
      },
      (key) => _geminiController.text = key,
    );

    // Load Claude
    final claudeResult = await repo.getApiKey('claude');
    claudeResult.fold(
      (_) => null,
      (key) => _claudeController.text = key,
    );
    
    // Load Pinecone
    final pineconeResult = await repo.getApiKey('pinecone');
    pineconeResult.fold(
      (_) => null,
      (key) => _pineconeController.text = key,
    );

    // Load Notion
    final notionResult = await repo.getApiKey('notion');
    notionResult.fold(
      (_) => null,
      (key) => _notionController.text = key,
    );

    // Load Notion Root Page Link
    final rootPageResult = await repo.getPreference('notion_root_page');
    rootPageResult.fold(
      (_) => null,
      (val) => _notionRootPageController.text = val,
    );

    setState(() => _isLoading = false);
  }

  Future<void> _saveKeys() async {
    setState(() => _isLoading = true);
    final repo = Provider.of<SettingsRepository>(context, listen: false);

    await repo.setApiKey('gemini', _geminiController.text);
    await repo.setApiKey('claude', _claudeController.text);
    await repo.setApiKey('pinecone', _pineconeController.text);
    await repo.setApiKey('notion', _notionController.text);
    await repo.setPreference('notion_root_page', _notionRootPageController.text);
    
    // Refresh ViewModel Keys immediately
    if (mounted) {
       final vm = Provider.of<TranscriptionViewModel>(context, listen: false);
       await vm.refreshApiKeys();
    }

    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("API Keys Saved Successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _saveKeys();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("AI Services Configuration")),
        body: Stack(
        children: [
           // Background
           Container(
             decoration: BoxDecoration(
               gradient: RadialGradient(
                 colors: [
                   Theme.of(context).colorScheme.primary.withOpacity(0.05),
                   Theme.of(context).colorScheme.surface,
                 ],
                 center: Alignment.center,
                 radius: 1.0,
               ),
             ),
           ),
           
           if (_isLoading)
             const Center(child: CircularProgressIndicator())
           else
             ListView(
               padding: const EdgeInsets.all(24),
               children: [
                 _buildSectionHeader(context, "Generative AI"),
                  GlassContainer(
                   padding: const EdgeInsets.all(16),
                   borderRadius: BorderRadius.circular(16),
                   gradient: LinearGradient(
                     colors: [
                       Theme.of(context).colorScheme.surface.withOpacity(0.4),
                       Theme.of(context).colorScheme.surface.withOpacity(0.1),
                     ],
                   ),
                   borderGradient: LinearGradient(
                     colors: [Colors.white24, Colors.white10],
                   ),
                     child: Consumer<TranscriptionViewModel>(
                     builder: (context, vm, _) {
                       // Safe Dropdown Logic
                       final defaultModels = _getModelsForProvider(vm.selectedProvider);
                       final List<Map<String, String>> currentModels = List.from(defaultModels);
                        
                       // Add custom models if not present
                       for (final customId in _customModelIds) {
                          if (!currentModels.any((m) => m['id'] == customId)) {
                             // Heuristic to filter by provider
                             if (vm.selectedProvider == 'gemini' && customId.startsWith('gemini')) {
                                currentModels.add({'id': customId, 'name': '$customId (Custom)'});
                             } else if (vm.selectedProvider == 'claude' && customId.startsWith('claude')) {
                                currentModels.add({'id': customId, 'name': '$customId (Custom)'});
                             }
                          }
                       }
                        
                       // Ensure selected model is in list
                       if (!currentModels.any((m) => m['id'] == vm.selectedModel)) {
                          currentModels.add({'id': vm.selectedModel, 'name': '${vm.selectedModel} (Saved)'});
                       }

                       final isValidModel = currentModels.any((m) => m['id'] == vm.selectedModel);
                       final safeValue = isValidModel ? vm.selectedModel : currentModels.first['id'];

                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // Provider Selection
                           Row(
                             children: [
                               Expanded(
                                 child: _buildProviderButton(context, vm, 'Google Gemini', 'gemini', Icons.auto_awesome),
                               ),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: _buildProviderButton(context, vm, 'Anthropic Claude', 'claude', Icons.psychology),
                               ),
                             ],
                           ),
                           const SizedBox(height: 16),
                           
                           // Model Selection
                           
                           DropdownButtonFormField<String>(
                             value: safeValue,
                             decoration: InputDecoration(
                               labelText: "Selected Model",
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                               filled: true,
                               fillColor: Colors.black12,
                             ),
                             items: currentModels.map((m) {
                               return DropdownMenuItem(value: m['id'], child: Text(m['name']!));
                             }).toList(),
                             onChanged: (val) {
                               if (val != null) vm.setModel(val);
                             },
                           ),
                           const SizedBox(height: 16),

                           // API Key Field (Conditional)
                           if (vm.selectedProvider == 'gemini')
                              TextField(
                                controller: _geminiController,
                                obscureText: !_isGeminiVisible,
                                decoration: InputDecoration(
                                  labelText: "Gemini API Key",
                                  prefixIcon: const Icon(Icons.smart_toy),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isGeminiVisible ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _isGeminiVisible = !_isGeminiVisible),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                              )
                           else
                              TextField(
                                controller: _claudeController,
                                obscureText: !_isClaudeVisible,
                                decoration: InputDecoration(
                                  labelText: "Claude API Key",
                                  prefixIcon: const Icon(Icons.vpn_key),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isClaudeVisible ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _isClaudeVisible = !_isClaudeVisible),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                              ),

                           const SizedBox(height: 8),
                           Align(
                             alignment: Alignment.centerRight,
                             child: TextButton.icon(
                               onPressed: () async {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Testing Connection...")));
                                 String? error;
                                 if (vm.selectedProvider == 'gemini') {
                                    error = await vm.testGeminiConnection(_geminiController.text);
                                 } else {
                                    error = await vm.testClaudeConnection(_claudeController.text);
                                 }
                                 
                                 if (!context.mounted) return;
                                 if (error == null) {
                                   await _saveKeys();
                                   if (!context.mounted) return;
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text("✅ Connection Successful & Saved!")),
                                   );
                                 } else {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text("❌ Failed: $error")),
                                   );
                                 }
                               },
                               icon: const Icon(Icons.check_circle_outline, size: 16),
                               label: const Text("Test Connection"),
                               style: TextButton.styleFrom(
                                 foregroundColor: Colors.white70,
                                 visualDensity: VisualDensity.compact,
                               ),
                             ),
                           ),
                           Align(
                             alignment: Alignment.centerRight,
                             child: TextButton.icon(
                               onPressed: () async {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching Models...")));
                                 final models = await vm.fetchAvailableModels(vm.selectedProvider);
                                 
                                 if (!context.mounted) return;
                                 
                                 showDialog(
                                   context: context,
                                   builder: (ctx) => AlertDialog(
                                     title: Text("Available ${vm.selectedProvider == 'gemini' ? 'Gemini' : 'Claude'} Models"),
                                     content: SizedBox(
                                       width: double.maxFinite,
                                       child: ListView.builder(
                                         shrinkWrap: true,
                                         itemCount: models.length,
                                         itemBuilder: (context, index) {
                                           final modelId = models[index];
                                           return ListTile(
                                             title: Text(modelId, style: const TextStyle(fontSize: 13)),
                                             trailing: IconButton(
                                               icon: const Icon(Icons.copy, size: 16),
                                               onPressed: () {
                                                 // Copy to clipboard or select
                                                 vm.setModel(modelId);
                                                 Navigator.pop(ctx);
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(content: Text("Selected model: $modelId")),
                                                 );
                                               },
                                             ),
                                             onTap: () {
                                                setState(() {
                                                  _customModelIds.add(modelId);
                                                });
                                                vm.setModel(modelId);
                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(content: Text("Selected model: $modelId")),
                                                );
                                             },
                                           );
                                         },
                                       ),
                                     ),
                                     actions: [
                                       TextButton(
                                         onPressed: () => Navigator.pop(ctx),
                                         child: const Text("Close"),
                                       ),
                                     ],
                                   ),
                                 );
                               },
                               icon: const Icon(Icons.list, size: 16),
                               label: const Text("Check Available Models"),
                               style: TextButton.styleFrom(
                                 foregroundColor: Colors.blueAccent,
                                 visualDensity: VisualDensity.compact,
                               ),
                             ),
                           ),
                         ],
                       );
                     }
                   ),
                 ),

                 const SizedBox(height: 24),
                 _buildSectionHeader(context, "Knowledge Base (Notion)"),
                  GlassContainer(
                   padding: const EdgeInsets.all(16),
                   borderRadius: BorderRadius.circular(16),
                   gradient: LinearGradient(
                     colors: [
                       Theme.of(context).colorScheme.surface.withOpacity(0.4),
                       Theme.of(context).colorScheme.surface.withOpacity(0.1),
                     ],
                   ),
                   borderGradient: LinearGradient(
                     colors: [Colors.white24, Colors.white10],
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Helper Guide
                       ExpansionTile(
                         title: const Text("Setup Guide: Connections & RAG", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                         children: [
                           Padding(
                             padding: const EdgeInsets.all(12.0),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 const Text("1. Get your Integration Secret:"),
                                 InkWell(
                                   onTap: () {}, // Ideally launch URL
                                   child: const Text("https://www.notion.so/my-integrations", style: TextStyle(color: Colors.blue)),
                                 ),
                                 const SizedBox(height: 8),
                                 const Text("2. Connect your Page:"),
                                 const Text("Go to your Notion Page > ... Menu > Connections > Add your Integration."),
                                 const SizedBox(height: 8),
                                 const Text("3. Optional: Optimize for RAG Search"),
                                 const Text("For best results, use a Table Database with columns: 'Question' and 'Keywords'. The page content serves as the answer."),
                               ],
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),

                       TextField(
                         controller: _notionController,
                         obscureText: !_isNotionVisible,
                         decoration: InputDecoration(
                           labelText: "Integration Secret ID",
                           prefixIcon: const Icon(Icons.vpn_key),
                           suffixIcon: IconButton(
                             icon: Icon(_isNotionVisible ? Icons.visibility : Icons.visibility_off),
                             onPressed: () => setState(() => _isNotionVisible = !_isNotionVisible),
                           ),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           filled: true,
                           fillColor: Colors.black12,
                         ),
                       ),
                       const SizedBox(height: 16),
                       TextField(
                         controller: _notionRootPageController,
                         decoration: InputDecoration(
                           labelText: "Root Page Link (Optional)",
                           hintText: "https://www.notion.so/my-page-id",
                           prefixIcon: const Icon(Icons.link),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           filled: true,
                           fillColor: Colors.black12,
                           helperText: "Paste link to 'RecallMe RAG' to only show its sub-pages.",
                         ),
                       ),
                        const SizedBox(height: 16),
                       
                        // Sync Controls
                        Consumer<TranscriptionViewModel>(
                          builder: (context, vm, _) {
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Last Synced: ${vm.lastSyncTimeFormatted}",
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    if (vm.isAiProcessing && vm.aiResponse.contains("Syncing"))
                                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          Provider.of<SettingsRepository>(context, listen: false).setApiKey('notion', _notionController.text);
                                          final viewModel = Provider.of<TranscriptionViewModel>(context, listen: false);
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching Notion Pages...")));
                                          await viewModel.fetchNotionPages();
            
                                          if (!context.mounted) return;
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (ctx) => _buildSelectionSheet(ctx, viewModel),
                                          );
                                        },
                                        icon: const Icon(Icons.list),
                                        label: const Text("Select Pages"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: vm.isAiProcessing ? null : () async {
                                           await vm.backgroundSync(silent: false);
                                        },
                                        icon: const Icon(Icons.sync),
                                        label: const Text("Sync Now"),
                                        style: ElevatedButton.styleFrom(
                                           backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                           foregroundColor: Colors.white, 
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                        ),
                     ],
                   ),
                 ),
                 
                   const SizedBox(height: 32),
                  _buildSectionHeader(context, "Personal Assistant (Google)"),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface.withOpacity(0.4),
                        Theme.of(context).colorScheme.surface.withOpacity(0.1),
                      ],
                    ),
                    borderGradient: LinearGradient(
                       colors: [Colors.white24, Colors.white10],
                    ),
                    child: Consumer<TranscriptionViewModel>(
                      builder: (context, vm, child) {
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.account_circle, color: Colors.blueAccent),
                              title: Text(vm.isGoogleAuthenticated ? "Connected" : "Not Connected"),
                              subtitle: Text(vm.isGoogleAuthenticated ? (vm.googleUserEmail ?? "User") : "Sign in to use Gmail & Calendar context"),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  if (vm.isGoogleAuthenticated) {
                                    await vm.disconnectGoogle();
                                  } else {
                                    final error = await vm.connectGoogle();
                                    if (!context.mounted) return;
                                    
                                    if (error == null) {
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connected to Google!")));
                                    } else {
                                       // Show Detailed Error Dialog
                                       showDialog(
                                         context: context,
                                         builder: (ctx) => AlertDialog(
                                           title: const Text("Connection Error"),
                                           content: SingleChildScrollView(
                                             child: SelectableText(error), 
                                           ),
                                           actions: [
                                             TextButton(
                                               onPressed: () => Navigator.pop(ctx),
                                               child: const Text("OK"),
                                             )
                                           ],
                                         ),
                                       );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: vm.isGoogleAuthenticated ? Colors.redAccent.withOpacity(0.2) : Colors.white,
                                  foregroundColor: vm.isGoogleAuthenticated ? Colors.redAccent : Colors.black,
                                ),
                                child: Text(vm.isGoogleAuthenticated ? "Disconnect" : "Connect"),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                   const SizedBox(height: 32),
                  _buildSectionHeader(context, "Preferences"),
                   GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface.withOpacity(0.4),
                        Theme.of(context).colorScheme.surface.withOpacity(0.1),
                      ],
                    ),
                    borderGradient: LinearGradient(
                      colors: [Colors.white24, Colors.white10],
                    ),
                    child: Consumer<TranscriptionViewModel>(
                      builder: (context, vm, child) {
                        return Column(
                           children: [
                             SwitchListTile(
                               title: const Text("Show System Messages"),
                               subtitle: const Text("Display context imports and status updates in chat"),
                               value: vm.showSystemMessages,
                               onChanged: (val) => vm.toggleSystemMessages(val),
                               secondary: const Icon(Icons.info_outline),
                             ),
                             const Divider(color: Colors.white24),
                             ListTile(
                               title: const Text("Suggested Bubbles"),
                               subtitle: Text("Generate ${vm.suggestedBubbleCount} AI suggestions on selection"),
                               trailing: Text(
                                 "${vm.suggestedBubbleCount}", 
                                 style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                               ),
                               leading: const Icon(Icons.auto_awesome),
                             ),
                             Slider(
                               value: vm.suggestedBubbleCount.toDouble(),
                               min: 0,
                               max: 5,
                               divisions: 5,
                               label: "${vm.suggestedBubbleCount}",
                               onChanged: (val) => vm.setSuggestedBubbleCount(val.toInt()),
                             ),
                           ],
                        );
                      },
                    ),
                   ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveKeys,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Configurations"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
               ],
             ),
        ],
      ),
    ));
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSelectionSheet(BuildContext context, TranscriptionViewModel viewModel) {
    return Consumer<TranscriptionViewModel>(
      builder: (context, vm, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Pages to Import",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (vm.isAiProcessing)
                const LinearProgressIndicator()
              else 
                Expanded(
                  child: vm.availablePages.isEmpty
                      ? const Center(child: Text("No pages found matching criteria."))
                      : ListView.builder(
                          itemCount: vm.availablePages.length,
                          itemBuilder: (context, index) {
                            final page = vm.availablePages[index];
                            final isPreviouslySynced = vm.syncedRootIds.contains(page.id);
                            return CheckboxListTile(
                              title: Text(page.title),
                              subtitle: Text("${page.lastEdited.toString().split('.')[0]}${isPreviouslySynced ? ' • Synced' : ''}"),
                              value: page.isSelected,
                              onChanged: (val) => vm.togglePageSelection(page.id),
                              secondary: Icon(
                                page.isDatabase ? Icons.dns : Icons.article_outlined,
                                color: isPreviouslySynced ? Colors.green : null,
                              ),
                            );
                          },
                        ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    vm.importSelectedPages();
                    Navigator.pop(context); // Close sheet
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Import Selected (${vm.availablePages.where((p) => p.isSelected).length})"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderButton(BuildContext context, TranscriptionViewModel vm, String label, String value, IconData icon) {
    final isSelected = vm.selectedProvider == value;
    return GestureDetector(
      onTap: () => vm.setProvider(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.black12,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white54),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getModelsForProvider(String provider) {
    if (provider == 'claude') {
      return [
        // Claude 4.5 Comp (Future/Beta)
        {'id': 'claude-opus-4-5-20251101', 'name': 'Claude 4.5 Opus'},
        {'id': 'claude-sonnet-4-5-20250929', 'name': 'Claude 4.5 Sonnet'},
        {'id': 'claude-haiku-4-5-20251001', 'name': 'Claude 4.5 Haiku'},
        
        // Claude 4.0
        {'id': 'claude-opus-4-1-20250805', 'name': 'Claude 4.1 Opus'},
        {'id': 'claude-opus-4-20250514', 'name': 'Claude 4 Opus'},
        {'id': 'claude-sonnet-4-20250514', 'name': 'Claude 4 Sonnet'},
        
        // Claude 3.7
        {'id': 'claude-3-7-sonnet-20250219', 'name': 'Claude 3.7 Sonnet'},

        // Claude 3.5
        {'id': 'claude-3-5-sonnet-20241022', 'name': 'Claude 3.5 Sonnet (New)'},
        {'id': 'claude-3-5-haiku-20241022', 'name': 'Claude 3.5 Haiku'},
        {'id': 'claude-3-opus-20240229', 'name': 'Claude 3 Opus'},
      ];
    } else {
      return [
        // Gemini 3 Series
        {'id': 'gemini-3.7-flash', 'name': 'Gemini 3.7 Flash (Latest)'},
        {'id': 'gemini-3.6-flash', 'name': 'Gemini 3.6 Flash'},
        {'id': 'gemini-3.5-flash', 'name': 'Gemini 3.5 Flash'},
        {'id': 'gemini-3.5-flash-lite', 'name': 'Gemini 3.5 Flash-Lite'},
        {'id': 'gemini-3.1-pro', 'name': 'Gemini 3.1 Pro (Flagship)'},
        {'id': 'gemini-3.0-pro-exp', 'name': 'Gemini 3.0 Pro (Exp)'},
        {'id': 'gemini-3.0-flash-exp', 'name': 'Gemini 3.0 Flash (Exp)'},
        
        // Gemini 2.5
        {'id': 'gemini-2.5-pro', 'name': 'Gemini 2.5 Pro'},
        {'id': 'gemini-2.5-flash', 'name': 'Gemini 2.5 Flash'},
        
        // Gemini 2.0
        {'id': 'gemini-2.0-pro-exp', 'name': 'Gemini 2.0 Pro (Exp)'},
        {'id': 'gemini-2.0-flash', 'name': 'Gemini 2.0 Flash'},
        
        // Gemini Latest (Auto)
        {'id': 'gemini-experimental', 'name': 'Gemini Experimental (Latest)'},
        
        // Legacy
        {'id': 'gemini-1.5-pro', 'name': 'Gemini 1.5 Pro'},
        {'id': 'gemini-1.5-flash', 'name': 'Gemini 1.5 Flash'},
      ];
    }
  }
}
