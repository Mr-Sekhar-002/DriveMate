import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Professional, original DriveMate Brand Logo representing:
/// 1. Location Pin & Road Navigation (Mobility)
/// 2. Modern Aerodynamic Vehicle (Car Rental)
/// 3. Steering & Chauffeur Emblem (Driver Hiring)
///
/// Designed with Deep Navy (#0B1930), Cyan (#08B6D1), and Pure White (#FFFFFF).
class DriveMateLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final bool hasBackground;

  const DriveMateLogo({
    super.key,
    this.size = 64,
    this.showGlow = true,
    this.hasBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: hasBackground
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.3),
                radius: 0.95,
                colors: [
                  Color(0xFF132A4A), // Elevated navy
                  Color(0xFF0B1930), // Deep Navy
                  Color(0xFF060E1B), // Dark rim
                ],
              ),
              boxShadow: showGlow
                  ? [
                      BoxShadow(
                        color: AppColors.cyanAccent.withOpacity(0.25),
                        blurRadius: size * 0.28,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: size * 0.15,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
              border: Border.all(
                color: AppColors.cyanAccent.withOpacity(0.85),
                width: math.max(1.2, size * 0.035),
              ),
            )
          : null,
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _DriveMateLogoPainter(),
        ),
      ),
    );
  }
}

class _DriveMateLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ─── 1. Background Road Perspective Trajectory (Highway to Pin) ───
    final roadPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0xFF08B6D1),
          Color(0xFF2563EB),
          Color(0xFF0B1930),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final roadPath = Path()
      ..moveTo(w * 0.32, h * 0.86)
      ..quadraticBezierTo(w * 0.42, h * 0.62, w * 0.46, h * 0.40)
      ..lineTo(w * 0.54, h * 0.40)
      ..quadraticBezierTo(w * 0.58, h * 0.62, w * 0.68, h * 0.86)
      ..close();
    canvas.drawPath(roadPath, roadPaint);

    // Highway Dashed Center Line
    final roadLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.024)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.5, h * 0.84), Offset(w * 0.5, h * 0.73), roadLinePaint);
    canvas.drawLine(Offset(w * 0.5, h * 0.68), Offset(w * 0.5, h * 0.58), roadLinePaint);

    // ─── 2. Outer GPS Location Pin Contour (Driver Mobility) ───
    final pinPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF08B6D1),
          Color(0xFF38BDF8),
          Color(0xFF1D4ED8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, w * 0.045)
      ..strokeCap = StrokeCap.round;

    final pinPath = Path()
      ..moveTo(w * 0.5, h * 0.16)
      ..cubicTo(w * 0.68, h * 0.16, w * 0.82, h * 0.32, w * 0.82, h * 0.46)
      ..cubicTo(w * 0.82, h * 0.62, w * 0.62, h * 0.76, w * 0.5, h * 0.88)
      ..cubicTo(w * 0.38, h * 0.76, w * 0.18, h * 0.62, w * 0.18, h * 0.46)
      ..cubicTo(w * 0.18, h * 0.32, w * 0.32, h * 0.16, w * 0.5, h * 0.16)
      ..close();
    canvas.drawPath(pinPath, pinPaint);

    // Pin Apex Waypoint Core
    final waypointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.048, waypointPaint);

    final waypointHalo = Paint()
      ..color = const Color(0xFF08B6D1).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.02);
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.08, waypointHalo);

    // ─── 3. Modern Vector Car Silhouette (Car Rental & Chauffeur) ───
    final carBodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Aerodynamic car roof & hood
    final carPath = Path()
      // Windshield & roof top
      ..moveTo(w * 0.38, h * 0.46)
      ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.62, h * 0.46)
      // A-pillar right
      ..lineTo(w * 0.68, h * 0.54)
      // Right fender & bumper
      ..quadraticBezierTo(w * 0.74, h * 0.57, w * 0.72, h * 0.65)
      ..lineTo(w * 0.66, h * 0.66)
      // Front grille curve
      ..quadraticBezierTo(w * 0.5, h * 0.69, w * 0.34, h * 0.66)
      // Left bumper & fender
      ..lineTo(w * 0.28, h * 0.65)
      ..quadraticBezierTo(w * 0.26, h * 0.57, w * 0.32, h * 0.54)
      // A-pillar left back to roof
      ..close();

    canvas.drawPath(carPath, carBodyPaint);

    // Windshield Cutout (Deep Navy Glass)
    final glassPaint = Paint()
      ..color = const Color(0xFF0B1930)
      ..style = PaintingStyle.fill;

    final glassPath = Path()
      ..moveTo(w * 0.40, h * 0.47)
      ..quadraticBezierTo(w * 0.5, h * 0.44, w * 0.60, h * 0.47)
      ..lineTo(w * 0.64, h * 0.54)
      ..quadraticBezierTo(w * 0.5, h * 0.55, w * 0.36, h * 0.54)
      ..close();
    canvas.drawPath(glassPath, glassPaint);

    // Twin Modern LED Headlights (Vibrant Cyan #08B6D1)
    final lightPaint = Paint()
      ..color = const Color(0xFF08B6D1)
      ..style = PaintingStyle.fill;

    // Left headlight (slanted sport LED)
    final leftLight = Path()
      ..moveTo(w * 0.31, h * 0.59)
      ..lineTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.36, h * 0.62)
      ..lineTo(w * 0.30, h * 0.61)
      ..close();
    canvas.drawPath(leftLight, lightPaint);

    // Right headlight (slanted sport LED)
    final rightLight = Path()
      ..moveTo(w * 0.69, h * 0.59)
      ..lineTo(w * 0.62, h * 0.58)
      ..lineTo(w * 0.64, h * 0.62)
      ..lineTo(w * 0.70, h * 0.61)
      ..close();
    canvas.drawPath(rightLight, lightPaint);

    // Central DriveMate Signature V-Grille Wing
    final wingPaint = Paint()
      ..color = const Color(0xFF08B6D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.024)
      ..strokeCap = StrokeCap.round;

    final wingPath = Path()
      ..moveTo(w * 0.42, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 0.65, w * 0.58, h * 0.62);
    canvas.drawPath(wingPath, wingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Standalone Wordmark widget for DriveMate ("Drive" in White, "Mate" in Cyan)
class DriveMateWordmark extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final bool showTagline;

  const DriveMateWordmark({
    super.key,
    this.fontSize = 24,
    this.letterSpacing = -0.5,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Drive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: letterSpacing,
                ),
              ),
              TextSpan(
                text: 'Mate',
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: letterSpacing,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 2),
          Text(
            'Car Rental & Driver Hiring Platform',
            style: TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: fontSize * 0.38,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Header Brand Combo (DriveMate Logo + Wordmark)
class DriveMateBrandHeaderWidget extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final VoidCallback? onTap;

  const DriveMateBrandHeaderWidget({
    super.key,
    this.logoSize = 34,
    this.fontSize = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DriveMateLogo(size: logoSize, showGlow: true),
          const SizedBox(width: 8),
          Flexible(
            child: DriveMateWordmark(fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}
