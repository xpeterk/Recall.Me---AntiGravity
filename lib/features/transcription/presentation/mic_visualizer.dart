import 'package:flutter/material.dart';

class MicVisualizer extends StatelessWidget {
  final Stream<double> soundLevelStream;
  final VoidCallback onTap;
  final bool isListening;

  const MicVisualizer({
    Key? key,
    required this.soundLevelStream,
    required this.onTap,
    required this.isListening,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ripple / Glow
          if (isListening)
            StreamBuilder<double>(
              stream: soundLevelStream,
              initialData: 0.0,
              builder: (context, snapshot) {
                // Determine scale based on sound level
                // Sound levels from speech_to_text are usually -10 to 10 or similar relative dB
                // We normalize simple for visual effect. Adjust bounds as needed.
                double level = snapshot.data ?? 0.0;
                
                // Simple normalization heuristic
                // If level is in dB, it might be negative. Let's assume it pushes > 0 when speaking.
                // We clamp and scale for the visual.
                double scale = 1.0 + (level.clamp(0.0, 10.0) / 10.0) * 0.5; // Scale up to 1.5x

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 56 * scale,
                  height: 56 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.3),
                  ),
                );
              },
            ),
          
          // Main Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isListening 
                  ? Colors.redAccent 
                  : Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isListening 
                      ? Colors.redAccent 
                      : Theme.of(context).colorScheme.primary).withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(
              isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
