import 'dart:ui';

import 'package:flutter/material.dart' show Colors, CustomPainter;

import '../models/canvas_shape.dart';

/// A single CustomPainter that renders all shapes on the whiteboard.
///
/// This is the ONLY place shapes are painted. No shape is a Flutter widget.
///
/// The painter receives:
/// - All shapes to render (domain entities)
/// - The currently selected shape ID
/// - Pan offset and zoom (for viewport transforms)
///
/// Architecture principle: Canvas handles rendering, shapes own geometry.
class WhiteboardPainter extends CustomPainter {
  WhiteboardPainter({
    required this.shapes,
    this.selectedShapeId,
    required this.gridSize,
    required this.isEditingText,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
    this.showGrid = true,
  });

  final List<CanvasShape> shapes;
  final String? selectedShapeId;
  final bool isEditingText;
  final Offset panOffset;
  final double zoom;
  final bool showGrid;
  final double gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Apply viewport transform
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoom);

    // Draw grid
    if (showGrid) {
      _paintGrid(canvas, size);
    }

    for (final shape in shapes) {
      final isSelected = shape.id == selectedShapeId;
      // Only the selected shape can be in text editing mode
      final isShapeEditingText = isSelected && isEditingText;

      shape.paint(
        canvas,
        isSelected: isSelected,
        isEditingText: isShapeEditingText,
      );

      if (isSelected) {
        shape.paintHandles(canvas);
      }
    }

    canvas.restore();
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    // Adjust for viewport transform
    final adjustedSize = Size(
      size.width / zoom + panOffset.dx.abs() / zoom,
      size.height / zoom + panOffset.dy.abs() / zoom,
    );

    // Vertical lines
    for (var x = 0.0; x < adjustedSize.width + gridSize; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, adjustedSize.height), paint);
    }

    // Horizontal lines
    for (var y = 0.0; y < adjustedSize.height + gridSize; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(adjustedSize.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) {
    return shapes != oldDelegate.shapes ||
        selectedShapeId != oldDelegate.selectedShapeId ||
        isEditingText != oldDelegate.isEditingText ||
        panOffset != oldDelegate.panOffset ||
        zoom != oldDelegate.zoom ||
        showGrid != oldDelegate.showGrid ||
        gridSize != oldDelegate.gridSize;
  }
}
