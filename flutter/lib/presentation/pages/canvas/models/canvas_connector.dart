import 'package:flutter/material.dart';
import 'package:whiteboard/domain/entities/connector.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;

import 'connector_node.dart';

/// Presentation-layer wrapper for a [Connector] entity.
///
/// This class is a **data holder** for UI rendering:
/// - **nodes**: Sequence of [AnchorNode] and [WaypointNode] defining control points
/// - **path**: Pre-calculated path (list of offsets to draw)
///
/// Key design principles:
/// - **Stateless**: Receives pre-computed nodes and path, doesn't manage them
/// - **UI-focused**: Only contains hit testing and painting logic
/// - **Immutable**: Use [copyWith] to create updated instances
///
/// Node and path creation is handled by [ConnectorRouter] and orchestrated
/// by the ViewModel. This class only consumes the results for rendering.
///
/// Usage:
/// ```dart
/// // Created by ViewModel using router
/// final nodes = router.createInitialNodes(...);
/// final path = router.route(nodes);
/// final connector = CanvasConnector(
///   entity: connectorEntity,
///   nodes: nodes,
///   path: path,
/// );
///
/// // Painting
/// connector.paint(canvas, isSelected: true);
///
/// // Hit testing
/// final hitNode = connector.hitTestNode(point);
/// ```
class CanvasConnector {
  const CanvasConnector({
    required this.entity,
    required this.nodes,
    required this.path,
  });

  /// The underlying domain entity for persistence.
  final Connector entity;

  /// Ordered list of nodes: [source anchor, ...waypoints, target anchor].
  final List<ConnectorNode> nodes;

  /// Pre-calculated path to draw (list of offsets).
  final List<Offset> path;

  /// Unique identifier (from entity).
  String get id => entity.id;

  /// Get the color as a Flutter Color.
  Color get color => color_helper.getColorFromHex(entity.color);

  /// Get the source anchor node.
  AnchorNode get sourceNode => nodes.first as AnchorNode;

  /// Get the target anchor node.
  AnchorNode get targetNode => nodes.last as AnchorNode;

  /// Get the start position (source anchor).
  Offset get startPosition => sourceNode.position;

  /// Get the end position (target anchor).
  Offset get endPosition => targetNode.position;

  // ---------------------------------------------------------------------------
  // Hit Testing
  // ---------------------------------------------------------------------------

  static const double _hitTolerance = 12.0;

  /// Hit test on connector nodes (waypoints and anchors).
  ///
  /// Returns the node if hit, null otherwise.
  ConnectorNode? hitTestNode(Offset point) {
    for (final node in nodes) {
      if ((point - node.position).distance < _hitTolerance) {
        return node;
      }
    }
    return null;
  }

  /// Hit test on path segments.
  ///
  /// Returns the segment index if hit, null otherwise.
  /// Segment index i is the line from path[i] to path[i+1].
  int? hitTestSegment(Offset point) {
    if (path.length < 2) return null;

    for (int i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];

      if (_pointToSegmentDistance(point, start, end) < _hitTolerance) {
        return i;
      }
    }

    return null;
  }

  /// Calculate perpendicular distance from point to line segment.
  double _pointToSegmentDistance(Offset point, Offset start, Offset end) {
    final segmentLength = (end - start).distance;
    if (segmentLength < 0.001) {
      return (point - start).distance;
    }

    // Project point onto line, clamped to segment
    final t =
        ((point - start).dx * (end - start).dx +
            (point - start).dy * (end - start).dy) /
        (segmentLength * segmentLength);
    final tClamped = t.clamp(0.0, 1.0);

    final projection = Offset(
      start.dx + tClamped * (end.dx - start.dx),
      start.dy + tClamped * (end.dy - start.dy),
    );

    return (point - projection).distance;
  }

  /// Get the index of a waypoint node in the nodes list.
  ///
  /// Returns -1 if not found or if node is not a WaypointNode.
  int getWaypointIndex(ConnectorNode node) {
    if (node is! WaypointNode) return -1;
    return nodes.indexOf(node);
  }

  /// Paint the connector on the canvas.
  ///
  /// [isSelected] - Whether this connector is selected (shows handles).
  /// [draggingNodeIndex] - If set, only show this node's handle (during drag).
  void paint(Canvas canvas, {bool isSelected = false, int? draggingNodeIndex}) {
    if (path.length < 2) return;

    _drawPath(canvas);

    // Draw handles when selected
    if (isSelected) {
      _paintHandles(canvas, draggingNodeIndex: draggingNodeIndex);
    }
  }

  void _drawPath(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    linePath.moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      linePath.lineTo(path[i].dx, path[i].dy);
    }
    canvas.drawPath(linePath, paint);
  }

  /// Paint handles for interactive nodes (waypoints and segment mids).
  ///
  /// [draggingNodeIndex] - If set, only paint this node (hide others during drag).
  void _paintHandles(Canvas canvas, {int? draggingNodeIndex}) {
    final waypointFillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final waypointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw handles (skip anchor nodes at first and last)
    for (int i = 1; i < nodes.length - 1; i++) {
      // If dragging a node, only show that node
      if (draggingNodeIndex != null && i != draggingNodeIndex) {
        continue;
      }

      final node = nodes[i];
      final position = node.position;

      // Waypoint: solid white with colored border
      canvas.drawCircle(position, 6, waypointFillPaint);
      canvas.drawCircle(position, 6, waypointBorderPaint);
    }
  }

  /// Create a copy with updated values.
  CanvasConnector copyWith({
    Connector? entity,
    List<ConnectorNode>? nodes,
    List<Offset>? path,
  }) {
    return CanvasConnector(
      entity: entity ?? this.entity,
      nodes: nodes ?? this.nodes,
      path: path ?? this.path,
    );
  }
}
