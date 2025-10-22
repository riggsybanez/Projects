// lib/widgets/bounding_box_painter.dart

import 'package:flutter/material.dart';
import '../models/hazard_object.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<HazardObject> hazards;
  final Size imageSize; // This is the display size (not used for coordinates)

  BoundingBoxPainter({
    required this.hazards,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hazards.isEmpty) return;
    
    print('🎨 BoundingBoxPainter: Painting ${hazards.length} hazards');
    print('🎨 Canvas size: ${size.width} x ${size.height}');
    
    for (var hazard in hazards) {
      // Get color based on risk level
      Color boxColor;
      switch (hazard.riskLevel) {
        case 'Highly Dangerous':
          boxColor = Colors.red;
          break;
        case 'High Risk':
          boxColor = Colors.orange;
          break;
        case 'Moderate Risk':
          boxColor = Colors.yellow;
          break;
        default:
          boxColor = Colors.green;
      }

      // Get normalized bounding box (0.0 to 1.0)
      final bbox = hazard.boundingBox;
      
      // Convert normalized coordinates (0-1) directly to canvas coordinates
      // The coordinates are already normalized, just multiply by canvas size
      final left = bbox.x * size.width;
      final top = bbox.y * size.height;
      final width = bbox.width * size.width;
      final height = bbox.height * size.height;
      
      print('📦 ${hazard.objectName}: rect=($left, $top, $width, $height)');

      // Draw bounding box
      final paint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(
        Rect.fromLTWH(left, top, width, height),
        paint,
      );

      // Draw label
      final labelText = '${hazard.objectName} ${(hazard.confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position label above box
      final labelTop = top > 26 ? top - 26 : top + height + 2;
      
      // Draw label background
      final labelBgPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          left,
          labelTop,
          textPainter.width + 8,
          22,
        ),
        labelBgPaint,
      );

      // Draw text
      textPainter.paint(canvas, Offset(left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
