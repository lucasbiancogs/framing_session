import 'dart:ui';

import 'package:flutter/material.dart' show Colors, CustomPainter;

import '../models/canvas_shape.dart';

/// A single CustomPainter that renders all shapes on the whiteboard.
///
/// This is the ONLY place shapes are painted. No shape is a Flutter widget.
///
/// The painter receives:
/// - All shapes to render (domain entities)
/// - The currently selected shape IDs (supports multiselect)
/// - Pan offset and zoom (for viewport transforms)
/// - Selection rectangle for marquee selection
///
/// Architecture principle: Canvas handles rendering, shapes own geometry.
class WhiteboardPainter extends CustomPainter {
  WhiteboardPainter({
    required this.shapes,
    this.selectedShapeIds = const {},
    required this.gridSize,
    required this.isEditingText,
    this.selectionRect,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
    this.showGrid = true,
  });

  final List<CanvasShape> shapes;
  final Set<String> selectedShapeIds;
  final bool isEditingText;
  final Rect? selectionRect;
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
      final isSelected = selectedShapeIds.contains(shape.id);
      // Only the selected shape can be in text editing mode (single selection)
      final isShapeEditingText =
          isSelected && selectedShapeIds.length == 1 && isEditingText;

      shape.paint(
        canvas,
        isSelected: isSelected,
        isEditingText: isShapeEditingText,
      );

      if (isSelected) {
        shape.paintHandles(canvas);
      }
    }

    // Draw selection rectangle (marquee)
    if (selectionRect != null) {
      _paintSelectionRect(canvas);
    }

    canvas.restore();
  }

  void _paintSelectionRect(Canvas canvas) {
    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(selectionRect!, fillPaint);
    canvas.drawRect(selectionRect!, borderPaint);
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
        selectedShapeIds != oldDelegate.selectedShapeIds ||
        isEditingText != oldDelegate.isEditingText ||
        selectionRect != oldDelegate.selectionRect ||
        panOffset != oldDelegate.panOffset ||
        zoom != oldDelegate.zoom ||
        showGrid != oldDelegate.showGrid ||
        gridSize != oldDelegate.gridSize;
  }
}
