import 'package:flutter/material.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;
import 'package:whiteboard/presentation/pages/canvas/models/canvas_cursor.dart';

class CursorsPainter extends CustomPainter {
  CursorsPainter({
    required this.cursors,
    required this.panOffset,
    required this.zoom,
  });

  final List<CanvasCursor> cursors;
  final Offset panOffset;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    for (final cursor in cursors) {
      final screenX = cursor.x * zoom + panOffset.dx;
      final screenY = cursor.y * zoom + panOffset.dy;
      canvas.drawCircle(
        Offset(screenX, screenY),
        10,
        Paint()..color = color_helper.getColorFromHex(cursor.userColor),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CursorsPainter oldDelegate) {
    return cursors != oldDelegate.cursors ||
        panOffset != oldDelegate.panOffset ||
        zoom != oldDelegate.zoom;
  }
}
