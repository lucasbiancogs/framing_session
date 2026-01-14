import 'dart:ui';

import 'package:flutter/material.dart' show Colors, CustomPainter;
import 'package:whiteboard/domain/entities/anchor_point.dart';

import '../models/canvas_connector.dart';
import '../models/canvas_shape.dart';

/// A CustomPainter that renders all connectors on the whiteboard.
///
/// Connectors are painted BEFORE shapes so they appear behind shapes.
/// This painter handles:
/// - Orthogonal path rendering
/// - Arrow heads
/// - Selection highlighting
/// - Segment handles for editing
/// - Anchor point indicators on selected shapes
class ConnectorsPainter extends CustomPainter {
  ConnectorsPainter({
    required this.connectors,
    required this.shapes,
    this.selectedConnectorId,
    this.selectedShapeId,
    this.isConnecting = false,
    this.connectingFromShape,
    this.connectingFromAnchor,
    this.connectingPreviewEnd,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
  });

  final List<CanvasConnector> connectors;
  final List<CanvasShape> shapes;
  final String? selectedConnectorId;
  final String? selectedShapeId;

  /// Whether the user is currently in "connecting" mode.
  final bool isConnecting;

  /// The shape being connected from (when isConnecting is true).
  final CanvasShape? connectingFromShape;

  /// The anchor point being connected from.
  final AnchorPoint? connectingFromAnchor;

  /// The current cursor position for preview line.
  final Offset? connectingPreviewEnd;

  final Offset panOffset;
  final double zoom;

  static const double _anchorRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Apply viewport transform
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoom);

    // Draw connectors (behind shapes)
    for (final connector in connectors) {
      final isSelected = connector.id == selectedConnectorId;
      connector.paint(canvas, isSelected: isSelected);
    }

    // Draw anchor points on selected shape
    if (selectedShapeId != null) {
      final selectedShape = shapes.firstWhere(
        (s) => s.id == selectedShapeId,
        orElse: () => shapes.first,
      );
      if (shapes.any((s) => s.id == selectedShapeId)) {
        _paintAnchorPoints(canvas, selectedShape);
      }
    }

    // Draw connecting preview line
    if (isConnecting &&
        connectingFromShape != null &&
        connectingFromAnchor != null &&
        connectingPreviewEnd != null) {
      _paintConnectingPreview(canvas);
    }

    // Draw anchor points on all shapes when in connecting mode
    if (isConnecting) {
      for (final shape in shapes) {
        if (shape.id != connectingFromShape?.id) {
          _paintAnchorPoints(canvas, shape, isTarget: true);
        }
      }
    }

    canvas.restore();
  }

  /// Paint anchor point indicators on a shape.
  void _paintAnchorPoints(
    Canvas canvas,
    CanvasShape shape, {
    bool isTarget = false,
  }) {
    final positions = shape.anchorPositions;

    final fillPaint = Paint()
      ..color = isTarget
          ? Colors.green.withAlpha(200)
          : Colors.blue.withAlpha(200)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final entry in positions.entries) {
      final position = entry.value;

      // Draw anchor circle
      canvas.drawCircle(position, _anchorRadius, fillPaint);
      canvas.drawCircle(position, _anchorRadius, borderPaint);
    }
  }

  /// Paint the preview line while connecting.
  void _paintConnectingPreview(Canvas canvas) {
    final startPosition = connectingFromShape!.getAnchorPosition(
      connectingFromAnchor!,
    );

    final previewPaint = Paint()
      ..color = Colors.blue.withAlpha(150)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw dashed preview line
    _drawDashedLine(canvas, startPosition, connectingPreviewEnd!, previewPaint);

    // Draw arrow head at preview end
    _drawArrowHead(canvas, startPosition, connectingPreviewEnd!, previewPaint);
  }

  /// Draw a dashed line between two points.
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 4.0;

    final direction = end - start;
    final distance = direction.distance;
    if (distance < 0.1) return;

    final normalized = direction / distance;
    var currentDistance = 0.0;

    while (currentDistance < distance) {
      final dashStart = start + normalized * currentDistance;
      final dashEnd =
          start +
          normalized * (currentDistance + dashLength).clamp(0, distance);

      canvas.drawLine(dashStart, dashEnd, paint);
      currentDistance += dashLength + gapLength;
    }
  }

  /// Draw an arrow head.
  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 10.0;

    final direction = to - from;
    if (direction.distance < 0.1) return;

    final normalized = direction / direction.distance;
    final perpendicular = Offset(-normalized.dy, normalized.dx);

    final arrowBack = to - normalized * arrowSize;
    final arrowLeft = arrowBack + perpendicular * (arrowSize / 2);
    final arrowRight = arrowBack - perpendicular * (arrowSize / 2);

    final arrowPath = Path();
    arrowPath.moveTo(to.dx, to.dy);
    arrowPath.lineTo(arrowLeft.dx, arrowLeft.dy);
    arrowPath.lineTo(arrowRight.dx, arrowRight.dy);
    arrowPath.close();

    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant ConnectorsPainter oldDelegate) {
    return connectors != oldDelegate.connectors ||
        shapes != oldDelegate.shapes ||
        selectedConnectorId != oldDelegate.selectedConnectorId ||
        selectedShapeId != oldDelegate.selectedShapeId ||
        isConnecting != oldDelegate.isConnecting ||
        connectingFromShape != oldDelegate.connectingFromShape ||
        connectingFromAnchor != oldDelegate.connectingFromAnchor ||
        connectingPreviewEnd != oldDelegate.connectingPreviewEnd ||
        panOffset != oldDelegate.panOffset ||
        zoom != oldDelegate.zoom;
  }
}
