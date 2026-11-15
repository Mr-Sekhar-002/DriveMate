import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DriveMateCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showGlow;
  final Color? glowColor;
  final double borderRadius;
  final Color? backgroundColor;

  const DriveMateCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.showGlow = false,
    this.glowColor,
    this.borderRadius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? AppColors.primaryBlue;
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.darkCardBg : AppColors.cardBg),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: showGlow ? effectiveGlowColor.withOpacity(0.5) : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
          width: showGlow ? 1.5 : 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: effectiveGlowColor.withOpacity(0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x120B1C38),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
