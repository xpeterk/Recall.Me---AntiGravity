import 'package:flutter/material.dart';
import '../../../../core/theme/glass_container.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;

  const PlaceholderPage({
    Key? key, 
    required this.title,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
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
           Center(
             child: Padding(
               padding: const EdgeInsets.all(24.0),
               child: GlassContainer(
                 padding: const EdgeInsets.all(32),
                 borderRadius: BorderRadius.circular(24),
                 gradient: LinearGradient(
                    colors: [
                       Theme.of(context).colorScheme.surface.withOpacity(0.4),
                       Theme.of(context).colorScheme.surface.withOpacity(0.1),
                     ],
                   ),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.construction, size: 48, color: Theme.of(context).colorScheme.primary),
                     const SizedBox(height: 16),
                     Text(
                       "Coming Soon to V3",
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                       textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 8),
                     Text(
                       message,
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                       textAlign: TextAlign.center,
                     ),
                   ],
                 ),
               ),
             ),
           ),
        ],
      ),
    );
  }
}
