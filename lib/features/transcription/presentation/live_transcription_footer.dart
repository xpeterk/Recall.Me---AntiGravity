import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../transcription/presentation/transcription_view_model.dart';
import '../../recall/presentation/transcription_bubble.dart';
import '../../../../core/theme/glass_container.dart';

class LiveTranscriptionFooter extends StatelessWidget {
  const LiveTranscriptionFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TranscriptionViewModel>(
      builder: (context, vm, child) {
        // If not frozen or available, hide
        if (!vm.isFrozen) return const SizedBox.shrink();

        final hasNewSegments = vm.liveSegments.isNotEmpty;
        final hasLiveText = vm.text.isNotEmpty && !vm.text.contains("Press the mic");
        
        if (!hasNewSegments && !hasLiveText) return const SizedBox.shrink();

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 16, 
              bottom: MediaQuery.of(context).padding.bottom + 16
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.4, 0.7],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Live Now" Indicator
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "LIVE NOW",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Recent Finalized Bubbles (Last 2 max)
                if (hasNewSegments)
                  ...vm.liveSegments.takeLast(2).map((s) => 
                     Opacity(
                       opacity: 0.8,
                       child: Transform.scale(
                         scale: 0.9,
                         alignment: Alignment.centerLeft,
                         child: TranscriptionBubble(
                           segment: s, 
                           isSelectionMode: false, 
                           isSelected: false,
                           onTap: (_) {},
                         ),
                       ),
                     )
                  ),

                // Live Interim Text
                if (hasLiveText)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12),
                      borderRadius: BorderRadius.circular(12),
                      child: Text(
                         vm.text, 
                         style: const TextStyle(fontStyle: FontStyle.italic)
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension ListExtensions<E> on List<E> {
  Iterable<E> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
