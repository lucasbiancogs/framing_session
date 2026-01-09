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
      final color = color_helper.getColorFromHex(cursor.userColor);

      final cursorPaint = Paint()..color = color;
      final cursorStrokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const scale = 1.5;
      final cursorPath = Path()
        ..moveTo(screenX + 6.807 * scale, screenY + 10.656 * scale)
        ..lineTo(screenX + 4.5 * scale, screenY + 12.572 * scale)
        ..lineTo(screenX + 4.5 * scale, screenY + 2.184 * scale)
        ..lineTo(screenX + 11.874 * scale, screenY + 9.353 * scale)
        ..lineTo(screenX + 8.911 * scale, screenY + 9.738 * scale)
        ..lineTo(screenX + 10.457 * scale, screenY + 13.422 * scale)
        ..lineTo(screenX + 8.354 * scale, screenY + 14.342 * scale)
        ..close();

      final textSpan = TextSpan(
        text: cursor.userName,
        style: TextStyle(color: color, fontSize: 12),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      canvas.drawPath(cursorPath, cursorPaint);
      canvas.drawPath(cursorPath, cursorStrokePaint);
      textPainter.layout(maxWidth: 100);
      textPainter.paint(canvas, Offset(screenX + 20, screenY + 20));
    }
  }

  @override
  bool shouldRepaint(covariant CursorsPainter oldDelegate) {
    return cursors != oldDelegate.cursors ||
        panOffset != oldDelegate.panOffset ||
        zoom != oldDelegate.zoom;
  }
}
