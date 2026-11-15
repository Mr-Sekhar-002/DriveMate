import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate modern DriveMate Android launcher icons', () async {
    const resDir = 'android/app/src/main/res';

    final densities = {
      'mipmap-mdpi': {'legacy': 48, 'foreground': 108},
      'mipmap-hdpi': {'legacy': 72, 'foreground': 162},
      'mipmap-xhdpi': {'legacy': 96, 'foreground': 216},
      'mipmap-xxhdpi': {'legacy': 144, 'foreground': 324},
      'mipmap-xxxhdpi': {'legacy': 192, 'foreground': 432},
    };

    for (final entry in densities.entries) {
      final folder = '$resDir/${entry.key}';
      final legacySize = entry.value['legacy']!;
      final fgSize = entry.value['foreground']!;

      // 1. Generate full legacy square icon (with deep navy circular badge)
      final legacyBytes = await _renderLogoToPng(
        size: legacySize,
        isForegroundOnly: false,
        isRound: false,
      );
      await File('$folder/ic_launcher.png').writeAsBytes(legacyBytes);

      // 2. Generate full legacy round icon
      final roundBytes = await _renderLogoToPng(
        size: legacySize,
        isForegroundOnly: false,
        isRound: true,
      );
      await File('$folder/ic_launcher_round.png').writeAsBytes(roundBytes);

      // 3. Generate adaptive foreground icon (transparent background, centered logo)
      final fgBytes = await _renderLogoToPng(
        size: fgSize,
        isForegroundOnly: true,
        isRound: false,
      );
      await File('$folder/ic_launcher_foreground.png').writeAsBytes(fgBytes);

      // ignore: avoid_print
      print('Generated icons for ${entry.key}: legacy ${legacySize}x$legacySize, fg ${fgSize}x$fgSize');
    }
  });
}

Future<List<int>> _renderLogoToPng({
  required int size,
  required bool isForegroundOnly,
  required bool isRound,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
  final s = size.toDouble();

  if (!isForegroundOnly) {
    // Background deep navy badge
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(s * 0.4, s * 0.35),
        s * 0.65,
        const [Color(0xFF132A4A), Color(0xFF0B1930), Color(0xFF060E1B)],
        const [0.0, 0.55, 1.0],
      );

    if (isRound) {
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.48, bgPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92), Radius.circular(s * 0.24));
      canvas.drawRRect(rrect, bgPaint);
    }

    // Outer cyan trim
    final borderPaint = Paint()
      ..color = const Color(0xFF08B6D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, s * 0.035);

    if (isRound) {
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.47, borderPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92), Radius.circular(s * 0.24));
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  // Logo content canvas scale: if foreground only, standard Android adaptive safe zone is 66dp / 108dp = ~62% of total size
  canvas.save();
  if (isForegroundOnly) {
    const scale = 0.64;
    final offset = s * (1.0 - scale) * 0.5;
    canvas.translate(offset, offset);
    canvas.scale(scale);
  } else {
    const scale = 0.78;
    final offset = s * (1.0 - scale) * 0.5;
    canvas.translate(offset, offset);
    canvas.scale(scale);
  }

  _paintDriveMateEmblem(canvas, s);
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void _paintDriveMateEmblem(Canvas canvas, double s) {
  final w = s;
  final h = s;

  // Road Perspective Sweep
  final roadPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(w * 0.5, h * 0.86),
      Offset(w * 0.5, h * 0.40),
      const [Color(0xFF08B6D1), Color(0xFF2563EB), Color(0xFF0B1930)],
      const [0.0, 0.5, 1.0],
    )
    ..style = PaintingStyle.fill;

  final roadPath = Path()
    ..moveTo(w * 0.32, h * 0.86)
    ..quadraticBezierTo(w * 0.42, h * 0.62, w * 0.46, h * 0.40)
    ..lineTo(w * 0.54, h * 0.40)
    ..quadraticBezierTo(w * 0.58, h * 0.62, w * 0.68, h * 0.86)
    ..close();
  canvas.drawPath(roadPath, roadPaint);

  // Dashed lane lines
  final roadLinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, w * 0.024)
    ..strokeCap = StrokeCap.round;

  canvas.drawLine(Offset(w * 0.5, h * 0.84), Offset(w * 0.5, h * 0.73), roadLinePaint);
  canvas.drawLine(Offset(w * 0.5, h * 0.68), Offset(w * 0.5, h * 0.58), roadLinePaint);

  // Location Pin Silhouette
  final pinPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(w, h),
      const [Color(0xFF08B6D1), Color(0xFF38BDF8), Color(0xFF1D4ED8)],
      const [0.0, 0.5, 1.0],
    )
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

  // Pin Waypoint Core
  canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.048, Paint()..color = Colors.white);
  canvas.drawCircle(
    Offset(w * 0.5, h * 0.28),
    w * 0.08,
    Paint()
      ..color = const Color(0xFF08B6D1).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.02),
  );

  // Vehicle Silhouette
  final carBodyPaint = Paint()..color = Colors.white;
  final carPath = Path()
    ..moveTo(w * 0.38, h * 0.46)
    ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.62, h * 0.46)
    ..lineTo(w * 0.68, h * 0.54)
    ..quadraticBezierTo(w * 0.74, h * 0.57, w * 0.72, h * 0.65)
    ..lineTo(w * 0.66, h * 0.66)
    ..quadraticBezierTo(w * 0.5, h * 0.69, w * 0.34, h * 0.66)
    ..lineTo(w * 0.28, h * 0.65)
    ..quadraticBezierTo(w * 0.26, h * 0.57, w * 0.32, h * 0.54)
    ..close();
  canvas.drawPath(carPath, carBodyPaint);

  // Windshield Glass
  final glassPath = Path()
    ..moveTo(w * 0.40, h * 0.47)
    ..quadraticBezierTo(w * 0.5, h * 0.44, w * 0.60, h * 0.47)
    ..lineTo(w * 0.64, h * 0.54)
    ..quadraticBezierTo(w * 0.5, h * 0.55, w * 0.36, h * 0.54)
    ..close();
  canvas.drawPath(glassPath, Paint()..color = const Color(0xFF0B1930));

  // Headlights
  final lightPaint = Paint()..color = const Color(0xFF08B6D1);
  final leftLight = Path()
    ..moveTo(w * 0.31, h * 0.59)
    ..lineTo(w * 0.38, h * 0.58)
    ..lineTo(w * 0.36, h * 0.62)
    ..lineTo(w * 0.30, h * 0.61)
    ..close();
  canvas.drawPath(leftLight, lightPaint);

  final rightLight = Path()
    ..moveTo(w * 0.69, h * 0.59)
    ..lineTo(w * 0.62, h * 0.58)
    ..lineTo(w * 0.64, h * 0.62)
    ..lineTo(w * 0.70, h * 0.61)
    ..close();
  canvas.drawPath(rightLight, lightPaint);

  // V-Grille Wing
  final wingPath = Path()
    ..moveTo(w * 0.42, h * 0.62)
    ..quadraticBezierTo(w * 0.5, h * 0.65, w * 0.58, h * 0.62);
  canvas.drawPath(
    wingPath,
    Paint()
      ..color = const Color(0xFF08B6D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.024)
      ..strokeCap = StrokeCap.round,
  );
}
