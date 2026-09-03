import 'package:flutter/material.dart';
import '../../../../core/theme/glass_container.dart';

import '../../settings/domain/ai_bubble.dart';

class RecallShelf extends StatelessWidget {
  final int selectionCount;
  final List<AiBubble> bubbles;
  final Function(AiBubble) onBubbleTap;
  final VoidCallback onBackgroundToggle;

  const RecallShelf({
    Key? key,
    required this.selectionCount,
    required this.bubbles,
    required this.onBubbleTap,
    required this.onBackgroundToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: 100 + MediaQuery.of(context).padding.bottom, // Slightly taller for the badge + safe area
      width: double.infinity,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.surface.withOpacity(0.6),
          Theme.of(context).colorScheme.surface.withOpacity(0.2),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderGradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary.withOpacity(0.5),
          Colors.white.withOpacity(0.1),
        ],
      ),
      blur: 20.0,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selection Badge / Handle
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            ),
            child: Text(
              "$selectionCount Selected",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          
          // Action Icons
          SizedBox(
            height: 40,
            child: Stack(
              children: [
                ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 48),
                  children: [
                    // Speak Prompt Action Bubble
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildActionItem(
                        context, 
                        AiBubble(
                          id: 'action_speak_prompt', 
                          name: 'Speak', 
                          icon: '🎤', 
                          color: const Color(0xFFF44336), // Colors.red
                          systemPrompt: ''
                        ), 
                        () => onBubbleTap(AiBubble(
                          id: 'action_speak_prompt', 
                          name: 'Speak', 
                          icon: '🎤', 
                          color: const Color(0xFFF44336), 
                          systemPrompt: ''
                        ))
                      ),
                    ),
                    ...bubbles.where((b) => b.isEnabled).map((bubble) => 
                       Padding(
                         padding: const EdgeInsets.only(right: 16),
                         child: _buildActionItem(context, bubble, () => onBubbleTap(bubble)),
                       )
                    ),
                  ],
                ),
                
                // Right-side visual fade clip overlay
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 48,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.surface.withOpacity(0.0),
                            Theme.of(context).colorScheme.surface.withOpacity(0.95),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Next Chevron Indicator
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right, 
                        size: 16, 
                        color: Colors.white70
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, AiBubble bubble, VoidCallback onTap) {
    // Distinct styling for Generated Bubbles
    final baseColor = bubble.isGenerated ? Colors.deepPurpleAccent : Theme.of(context).colorScheme.primary;
    final bgColor = bubble.isGenerated ? baseColor.withOpacity(0.2) : baseColor.withOpacity(0.1);
    final borderColor = bubble.isGenerated ? baseColor.withOpacity(0.6) : baseColor.withOpacity(0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          children: [
            if (bubble.icon.endsWith('.png')) 
              Image.asset(
                bubble.icon,
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 24),
              )
            else
              Text(bubble.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              bubble.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (bubble.isGenerated) ...[
               const SizedBox(width: 6),
               Icon(Icons.auto_awesome, size: 12, color: baseColor),
            ]
          ],
        ),
      ),
    );
  }
}
