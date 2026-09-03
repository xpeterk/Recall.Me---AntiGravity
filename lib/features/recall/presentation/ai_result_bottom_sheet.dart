import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart'; // Import Link Launcher
import '../../transcription/presentation/transcription_view_model.dart';

class AiResultBottomSheet extends StatelessWidget {
  const AiResultBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: GlassContainer(
        height: double.infinity,
        width: double.infinity,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.surface.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
         borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        blur: 10,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "AI Analysis",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 32),

            // Content
            Expanded(
              child: Consumer<TranscriptionViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isAiProcessing && viewModel.aiResponse.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // PageView Logic
                  int currentPage = 0;
                  
                  return StatefulBuilder(
                    builder: (context, setState) {
                      final responses = viewModel.aiResponseList.isNotEmpty ? viewModel.aiResponseList : [viewModel.aiResponse];
                      
                      return Column(
                        children: [
                                      // Page Info & Tools Area (Moved to top)
                                      if (!viewModel.isAiProcessing && responses.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: responses[currentPage]));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text("Copied to Clipboard")),
                                                        );
                                                      },
                                                      icon: const Icon(Icons.copy, size: 18),
                                                      label: const Text("Share Page"),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: Colors.white,
                                                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: responses[currentPage]));
                                                        viewModel.saveAiMemory("Quick Action", viewModel.aiResponse);
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text("All Answers Saved & Page Copied")),
                                                        );
                                                      },
                                                      icon: const Icon(Icons.save_alt, size: 18),
                                                      label: const Text("Save All"),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: Colors.white,
                                                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 40,
                                                child: ListView(
                                                  scrollDirection: Axis.horizontal,
                                                  children: [
                                                    _buildFollowUpButton(context, viewModel, "Deep Dive 🧠", () => viewModel.deepDiveText(), isPrimary: true),
                                                    const SizedBox(width: 8),
                                                    _buildFollowUpButton(context, viewModel, "Simplify 👶", () => viewModel.runFollowUp("Simplified", "Rewrite the analysis in simple, easy-to-understand language.")),
                                                    const SizedBox(width: 8),
                                                    _buildFollowUpButton(context, viewModel, "Key Points 🔑", () => viewModel.runFollowUp("Key Takeaways", "Extract the 3 most important points as a bulleted list.")),
                                                    const SizedBox(width: 8),
                                                    _buildFollowUpButton(context, viewModel, "Critique ⚖️", () => viewModel.runFollowUp("Critique", "Identify any potential flaws or alternative perspectives.")),
                                                    const SizedBox(width: 8),
                                                    _buildFollowUpButton(context, viewModel, "Español 🇪🇸", () => viewModel.runFollowUp("Traducción", "Translate the analysis into Spanish.")),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      Expanded(
                                        child: PageView.builder(
                                          itemCount: responses.length,
                                          onPageChanged: (idx) => setState(() => currentPage = idx),
                                          itemBuilder: (context, index) {
                                            return SingleChildScrollView(
                                              padding: const EdgeInsets.all(24),
                                              child: MarkdownBody(
                                                data: responses[index],
                                                selectable: true,
                                                onTapLink: (text, href, title) async {
                                                  if (href != null) {
                                                     final Uri url = Uri.parse(href);
                                                     if (await canLaunchUrl(url)) {
                                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                                     }
                                                  }
                                                },
                                                imageBuilder: (uri, title, alt) {
                                                   return Center(
                                                     child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.network(
                                                           uri.toString(),
                                                           errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                        ),
                                                     ),
                                                   );
                                                },
                                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                                                  h1: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                                  h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                                  code: TextStyle(
                                                    backgroundColor: Colors.black26,
                                                    fontFamily: 'monospace', 
                                                    color: Theme.of(context).colorScheme.tertiary,
                                                  ),
                                                  codeblockDecoration: BoxDecoration(
                                                    color: Colors.black26, 
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      
                                      // Page Indicator
                                      if (responses.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: List.generate(responses.length, (index) {
                                              return Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: currentPage == index 
                                                      ? Theme.of(context).colorScheme.primary 
                                                      : Colors.white24,
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                    ],
                                  );
                                }
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                ),
              );
            }
            Widget _buildFollowUpButton(BuildContext context, TranscriptionViewModel vm, String label, VoidCallback onTap, {bool isPrimary = false}) {

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
        foregroundColor: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isPrimary ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(label),
    );
  }
}
