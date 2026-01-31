import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Gradient? borderGradient;
  final double blur;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    Key? key,
    this.width,
    this.height,
    this.child,
    this.borderRadius,
    this.gradient,
    this.borderGradient,
    this.blur = 10.0,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.transparent, // Border handled by gradient/painter if complex
              width: 0,
            ),
          ),
          child: Stack(
            children: [
              if (child != null) 
                 Padding(
                   padding: padding ?? EdgeInsets.zero,
                   child: child!,
                 ),
              if (borderGradient != null)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2), // Simple fallback
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
