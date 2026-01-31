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
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ...bubbles.where((b) => b.isEnabled).map((bubble) => 
                   Padding(
                     padding: const EdgeInsets.only(right: 16),
                     child: _buildActionItem(context, bubble, () => onBubbleTap(bubble)),
                   )
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
