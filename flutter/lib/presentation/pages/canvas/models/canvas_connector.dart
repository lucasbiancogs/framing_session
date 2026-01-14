import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/arrow_type.dart';
import 'package:whiteboard/domain/entities/connector.dart';
import 'package:whiteboard/domain/entities/waypoint.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;

import 'canvas_shape.dart';

const double _anchorOffset = 15.0;

// ---------------------------------------------------------------------------
// Manhattan Router Constants
// ---------------------------------------------------------------------------
const double _gridSize = 12.0;
const int _maxIterations = 2000;
const double _maxSearchRadius = 1200.0;
const double _bendPenaltyCost = 24.0;
const double _obstaclePadding = 16.0;

/// Presentation-layer wrapper for a [Connector] entity.
///
/// Provides:
/// - Path calculation (orthogonal routing with Manhattan A*)
/// - Hit testing for segments
/// - Painting methods
class CanvasConnector {
  CanvasConnector({
    required this.entity,
    required this.sourceShape,
    required this.targetShape,
  });

  final Connector entity;
  final CanvasShape sourceShape;
  final CanvasShape targetShape;

  String get id => entity.id;

  // ---------------------------------------------------------------------------
  // Path Cache - Avoids recalculating on every paint
  // ---------------------------------------------------------------------------
  Offset? _cachedStart;
  Offset? _cachedEnd;
  List<Offset>? _cachedPath;

  /// Tolerance for segment hit testing.
  static const double _hitTolerance = 8.0;

  /// Arrow head size.
  static const double _arrowSize = 20.0;

  /// Get the color as a Flutter Color.
  Color get color => color_helper.getColorFromHex(entity.color);

  /// Get the start position (source anchor on source shape).
  Offset get startPosition =>
      _getAnchorPosition(sourceShape, entity.sourceAnchor);

  /// Get the end position (target anchor on target shape).
  Offset get endPosition =>
      _getAnchorPosition(targetShape, entity.targetAnchor);

  /// Calculate the path as a list of points.
  ///
  /// If custom waypoints exist (user has dragged segments), uses them
  /// with orthogonal stubs at both ends to maintain clean connections.
  /// Otherwise, auto-routes using Manhattan A* with caching.
  List<Offset> get path {
    final waypoints = entity.waypoints;

    // Manual waypoints take precedence - do NOT auto-route
    if (waypoints.isNotEmpty) {
      final sortedWaypoints = [...waypoints]
        ..sort((a, b) => a.index.compareTo(b.index));

      final waypointOffsets = sortedWaypoints
          .map((w) => Offset(w.x, w.y))
          .toList();

      return _buildPathWithOrthogonalEnds(waypointOffsets);
    }

    // Auto-route with caching
    return _getAutoRoutedPath();
  }

  /// Build a path with orthogonal stub segments at both ends.
  /// Ensures the first and last segments are always perpendicular to the anchors.
  List<Offset> _buildPathWithOrthogonalEnds(List<Offset> waypoints) {
    final start = startPosition;
    final end = endPosition;

    if (waypoints.isEmpty) {
      return [start, end];
    }

    final result = <Offset>[start];

    // Add orthogonal stub from start anchor to first waypoint
    final firstWaypoint = waypoints.first;
    final startStub = _calculateOrthogonalStub(
      anchor: start,
      target: firstWaypoint,
      anchorPoint: entity.sourceAnchor,
    );
    if (startStub != null) {
      result.add(startStub);
    }

    // Add all waypoints
    result.addAll(waypoints);

    // Add orthogonal stub from last waypoint to end anchor
    final lastWaypoint = waypoints.last;
    final endStub = _calculateOrthogonalStub(
      anchor: end,
      target: lastWaypoint,
      anchorPoint: entity.targetAnchor,
    );
    if (endStub != null) {
      result.add(endStub);
    }

    result.add(end);

    return _simplifyPath(result);
  }

  /// Calculate an orthogonal stub point between an anchor and a waypoint.
  /// Returns null if the waypoint is already aligned with the anchor direction.
  Offset? _calculateOrthogonalStub({
    required Offset anchor,
    required Offset target,
    required AnchorPoint anchorPoint,
  }) {
    final direction = _getAnchorDirection(anchorPoint);
    final isHorizontal = _isHorizontalAnchor(direction);

    if (isHorizontal) {
      // Anchor exits horizontally (left/right)
      // Check if target is already on the same horizontal line
      if ((anchor.dy - target.dy).abs() < 1.0) {
        return null; // Already aligned, no stub needed
      }
      // Create a turn point: same Y as anchor, same X as target
      return Offset(target.dx, anchor.dy);
    } else {
      // Anchor exits vertically (top/bottom)
      // Check if target is already on the same vertical line
      if ((anchor.dx - target.dx).abs() < 1.0) {
        return null; // Already aligned, no stub needed
      }
      // Create a turn point: same X as anchor, same Y as target
      return Offset(anchor.dx, target.dy);
    }
  }

  /// Get auto-routed path with caching.
  /// Only recalculates if start or end position changed.
  List<Offset> _getAutoRoutedPath() {
    final start = startPosition;
    final end = endPosition;

    // Check cache validity
    if (_cachedPath != null &&
        _cachedStart != null &&
        _cachedEnd != null &&
        (start - _cachedStart!).distance < 1.0 &&
        (end - _cachedEnd!).distance < 1.0) {
      return _cachedPath!;
    }

    // Calculate new path
    final newPath = _routeManhattan(start: start, end: end);

    // Update cache
    _cachedStart = start;
    _cachedEnd = end;
    _cachedPath = newPath;

    return newPath;
  }

  // ---------------------------------------------------------------------------
  // Manhattan A* Router
  // ---------------------------------------------------------------------------

  Offset _snapToGrid(Offset p) {
    return Offset(
      (p.dx / _gridSize).round() * _gridSize,
      (p.dy / _gridSize).round() * _gridSize,
    );
  }

  List<Offset> _routeManhattan({required Offset start, required Offset end}) {
    // Early exit #1: Try simple L-path (covers ~90% of cases)
    final simplePath = _trySimpleLPath(start, end);
    if (simplePath != null) {
      return simplePath;
    }

    // Full A* search with bounds
    return _aStarSearch(start, end);
  }

  /// Try a simple L-shaped path (2 segments).
  /// Returns null if the path is blocked.
  List<Offset>? _trySimpleLPath(Offset start, Offset end) {
    final startDir = _getAnchorDirection(entity.sourceAnchor);

    // Determine L-path based on anchor direction
    Offset corner;
    if (_isHorizontalAnchor(startDir)) {
      // Horizontal first: go horizontal, then vertical
      corner = Offset(end.dx, start.dy);
    } else {
      // Vertical first: go vertical, then horizontal
      corner = Offset(start.dx, end.dy);
    }

    // Check if L-path is unobstructed
    if (!_isSegmentBlocked(start, corner) && !_isSegmentBlocked(corner, end)) {
      return _simplifyPath([start, corner, end]);
    }

    // Try the alternative L-path
    final altCorner = _isHorizontalAnchor(startDir)
        ? Offset(start.dx, end.dy)
        : Offset(end.dx, start.dy);

    if (!_isSegmentBlocked(start, altCorner) &&
        !_isSegmentBlocked(altCorner, end)) {
      return _simplifyPath([start, altCorner, end]);
    }

    return null; // L-path blocked, need full A*
  }

  /// Check if anchor direction is horizontal (left/right).
  bool _isHorizontalAnchor(Offset direction) {
    return direction.dx.abs() > 0.5;
  }

  /// Get direction vector for an anchor point.
  Offset _getAnchorDirection(AnchorPoint anchor) {
    return switch (anchor) {
      AnchorPoint.top => const Offset(0, -1),
      AnchorPoint.right => const Offset(1, 0),
      AnchorPoint.bottom => const Offset(0, 1),
      AnchorPoint.left => const Offset(-1, 0),
    };
  }

  /// Check if a line segment intersects any obstacle.
  bool _isSegmentBlocked(Offset a, Offset b) {
    final sourceBlock = _inflatedBounds(sourceShape);
    final targetBlock = _inflatedBounds(targetShape);

    // Sample points along the segment
    final distance = (b - a).distance;
    final steps = (distance / _gridSize).ceil().clamp(1, 100);

    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final point = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

      // Allow points near anchors
      if ((point - startPosition).distance < _gridSize ||
          (point - endPosition).distance < _gridSize) {
        continue;
      }

      if (sourceBlock.contains(point) || targetBlock.contains(point)) {
        return true;
      }
    }

    return false;
  }

  /// Full A* search with iteration and radius limits.
  List<Offset> _aStarSearch(Offset start, Offset end) {
    final startG = _snapToGrid(start);
    final endG = _snapToGrid(end);
    final searchCenter = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    // Priority queue using SplayTreeMap for efficient min extraction
    final gScore = <_GridNode, double>{};
    final fScore = <_GridNode, double>{};
    final cameFrom = <_GridNode, _GridNode>{};
    final closed = <_GridNode>{};

    final startNode = _GridNode(startG.dx, startG.dy);

    gScore[startNode] = 0;
    fScore[startNode] = _manhattanDistance(startG, endG);

    // Open set with priority queue behavior
    final open = SplayTreeMap<double, List<_GridNode>>();
    _addToOpen(open, fScore[startNode]!, startNode);

    int iterations = 0;

    while (open.isNotEmpty && iterations < _maxIterations) {
      iterations++;

      // Get node with lowest fScore
      final currentNode = _popFromOpen(open);
      if (currentNode == null) break;

      final current = Offset(currentNode.x, currentNode.y);

      // Goal reached
      if ((current - endG).distance < _gridSize) {
        return _reconstructAStarPath(cameFrom, currentNode, start, end);
      }

      closed.add(currentNode);

      // Expand neighbors
      for (final neighborOffset in _getNeighbors(current)) {
        final neighborNode = _GridNode(neighborOffset.dx, neighborOffset.dy);

        // Skip if already evaluated
        if (closed.contains(neighborNode)) continue;

        // Skip if outside search radius
        if ((neighborOffset - searchCenter).distance > _maxSearchRadius) {
          continue;
        }

        // Skip if blocked
        if (_isPointBlocked(neighborOffset)) continue;

        final tentativeG = (gScore[currentNode] ?? double.infinity) + _gridSize;

        if (tentativeG < (gScore[neighborNode] ?? double.infinity)) {
          cameFrom[neighborNode] = currentNode;
          gScore[neighborNode] = tentativeG;

          final bendCost = _calculateBendPenalty(
            currentNode,
            neighborNode,
            cameFrom,
          );

          final newFScore =
              tentativeG + _manhattanDistance(neighborOffset, endG) + bendCost;

          final oldFScore = fScore[neighborNode];
          fScore[neighborNode] = newFScore;

          // Add/update in open set
          if (oldFScore != null) {
            _removeFromOpen(open, oldFScore, neighborNode);
          }
          _addToOpen(open, newFScore, neighborNode);
        }
      }
    }

    // Fallback: straight line if A* fails
    return [start, end];
  }

  void _addToOpen(
    SplayTreeMap<double, List<_GridNode>> open,
    double score,
    _GridNode node,
  ) {
    open.putIfAbsent(score, () => []).add(node);
  }

  _GridNode? _popFromOpen(SplayTreeMap<double, List<_GridNode>> open) {
    if (open.isEmpty) return null;

    final minKey = open.firstKey()!;
    final list = open[minKey]!;
    final node = list.removeLast();

    if (list.isEmpty) {
      open.remove(minKey);
    }

    return node;
  }

  void _removeFromOpen(
    SplayTreeMap<double, List<_GridNode>> open,
    double score,
    _GridNode node,
  ) {
    final list = open[score];
    if (list != null) {
      list.remove(node);
      if (list.isEmpty) {
        open.remove(score);
      }
    }
  }

  double _manhattanDistance(Offset a, Offset b) =>
      (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  Iterable<Offset> _getNeighbors(Offset p) sync* {
    yield Offset(p.dx + _gridSize, p.dy);
    yield Offset(p.dx - _gridSize, p.dy);
    yield Offset(p.dx, p.dy + _gridSize);
    yield Offset(p.dx, p.dy - _gridSize);
  }

  bool _isPointBlocked(Offset p) {
    final sourceBlock = _inflatedBounds(sourceShape);
    final targetBlock = _inflatedBounds(targetShape);

    // Allow points near anchors
    if ((p - startPosition).distance < _gridSize ||
        (p - endPosition).distance < _gridSize) {
      return false;
    }

    return sourceBlock.contains(p) || targetBlock.contains(p);
  }

  Rect _inflatedBounds(CanvasShape shape) {
    return shape.bounds.inflate(_obstaclePadding);
  }

  double _calculateBendPenalty(
    _GridNode current,
    _GridNode next,
    Map<_GridNode, _GridNode> cameFrom,
  ) {
    final prev = cameFrom[current];
    if (prev == null) return 0;

    final d1x = current.x - prev.x;
    final d1y = current.y - prev.y;
    final d2x = next.x - current.x;
    final d2y = next.y - current.y;

    // Direction changed if moving axis changed
    final changedDirection = (d1x == 0 && d2x != 0) || (d1y == 0 && d2y != 0);

    return changedDirection ? _bendPenaltyCost : 0;
  }

  List<Offset> _reconstructAStarPath(
    Map<_GridNode, _GridNode> cameFrom,
    _GridNode current,
    Offset start,
    Offset end,
  ) {
    final path = <Offset>[Offset(current.x, current.y)];

    var node = current;
    while (cameFrom.containsKey(node)) {
      node = cameFrom[node]!;
      path.add(Offset(node.x, node.y));
    }

    // Reverse to get start-to-end order
    final reversedPath = path.reversed.toList();

    // Add exact start and end positions
    final result = <Offset>[start, ...reversedPath, end];

    return _simplifyPath(result);
  }

  /// Remove collinear points to simplify the path.
  List<Offset> _simplifyPath(List<Offset> path) {
    if (path.length < 3) return path;

    final result = <Offset>[path.first];

    for (int i = 1; i < path.length - 1; i++) {
      final a = result.last;
      final b = path[i];
      final c = path[i + 1];

      // Skip if collinear (same x or same y for all three)
      final collinearX = (a.dx - b.dx).abs() < 1 && (b.dx - c.dx).abs() < 1;
      final collinearY = (a.dy - b.dy).abs() < 1 && (b.dy - c.dy).abs() < 1;

      if (collinearX || collinearY) {
        continue;
      }
      result.add(b);
    }

    result.add(path.last);
    return result;
  }

  List<List<Offset>> get segments {
    final segments = <List<Offset>>[];
    for (int i = 0; i < path.length - 1; i++) {
      segments.add([path[i], path[i + 1]]);
    }

    return segments;
  }

  /// Get the anchor position on a shape.
  Offset _getAnchorPosition(CanvasShape shape, AnchorPoint anchor) {
    final bounds = shape.bounds;
    return switch (anchor) {
      AnchorPoint.top => Offset(bounds.center.dx, bounds.top - _anchorOffset),
      AnchorPoint.right => Offset(
        bounds.right + _anchorOffset,
        bounds.center.dy,
      ),
      AnchorPoint.bottom => Offset(
        bounds.center.dx,
        bounds.bottom + _anchorOffset,
      ),
      AnchorPoint.left => Offset(bounds.left - _anchorOffset, bounds.center.dy),
    };
  }

  /// Hit test a point against path segments.
  ///
  /// Returns the segment index (0-based) if hit, or -1 if not hit.
  int hitTestSegment(Offset point) {
    for (int i = 0; i < segments.length - 1; i++) {
      if (_isPointNearSegment(point, segments[i])) {
        return i;
      }
    }

    return -1;
  }

  /// Check if a point is near a line segment.
  bool _isPointNearSegment(Offset point, List<Offset> segment) {
    final segStart = segment.first;
    final segEnd = segment.last;
    final dx = segEnd.dx - segStart.dx;
    final dy = segEnd.dy - segStart.dy;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared < 0.0001) {
      // Segment is essentially a point
      return (point - segStart).distance < _hitTolerance;
    }

    // Project point onto segment
    final t =
        ((point.dx - segStart.dx) * dx + (point.dy - segStart.dy) * dy) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);

    final projection = Offset(
      segStart.dx + clampedT * dx,
      segStart.dy + clampedT * dy,
    );

    return (point - projection).distance < _hitTolerance;
  }

  /// Create a new connector with updated waypoints from dragging a segment.
  ///
  /// When dragging segment [segmentIndex], moves both of its endpoints:
  /// - Segment i connects point[i] to point[i+1]
  /// - Both points are moved in the perpendicular direction
  /// - Horizontal segments move vertically (delta.dy)
  /// - Vertical segments move horizontally (delta.dx)
  CanvasConnector withDraggedSegment(int segmentIndex, Offset delta) {
    final currentPath = path;

    // Validate segment index
    if (segmentIndex < 0 || segmentIndex >= currentPath.length - 1) {
      return this;
    }

    // Determine if segment is horizontal
    final segStart = currentPath[segmentIndex];
    final segEnd = currentPath[segmentIndex + 1];
    final isHorizontal = (segStart.dy - segEnd.dy).abs() < 1.0;

    // Build new internal waypoints (exclude start and end anchors)
    final newWaypoints = <Waypoint>[];
    for (int i = 1; i < currentPath.length - 1; i++) {
      var point = currentPath[i];

      // Move points that are endpoints of the dragged segment
      if (i == segmentIndex || i == segmentIndex + 1) {
        if (isHorizontal) {
          // Horizontal segment: move vertically
          point = Offset(point.dx, point.dy + delta.dy);
        } else {
          // Vertical segment: move horizontally
          point = Offset(point.dx + delta.dx, point.dy);
        }
      }

      newWaypoints.add(Waypoint(index: i, x: point.dx, y: point.dy));
    }

    final updatedEntity = Connector(
      id: entity.id,
      sessionId: entity.sessionId,
      sourceShapeId: entity.sourceShapeId,
      targetShapeId: entity.targetShapeId,
      sourceAnchor: entity.sourceAnchor,
      targetAnchor: entity.targetAnchor,
      arrowType: entity.arrowType,
      color: entity.color,
      waypoints: newWaypoints,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );

    return CanvasConnector.fromEntity(updatedEntity, sourceShape, targetShape);
  }

  /// Paint the connector on the canvas.
  void paint(Canvas canvas, {bool isSelected = false}) {
    if (path.length < 2) return;

    final paint = Paint()
      ..color = isSelected ? color.withAlpha(255) : color.withAlpha(200)
      ..strokeWidth = isSelected ? 5.0 : 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw path
    final linePath = Path();
    linePath.moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      linePath.lineTo(path[i].dx, path[i].dy);
    }
    canvas.drawPath(linePath, paint);

    // Draw arrows based on arrow type
    if (entity.arrowType == ArrowType.start ||
        entity.arrowType == ArrowType.both) {
      _drawArrowHead(canvas, path[1], path[0], paint);
    }
    if (entity.arrowType == ArrowType.end ||
        entity.arrowType == ArrowType.both) {
      _drawArrowHead(
        canvas,
        path[path.length - 2],
        path[path.length - 1],
        paint,
      );
    }

    // Draw segment handles when selected
    if (isSelected) {
      _paintSegmentHandles(canvas, path);
    }
  }

  /// Draw an arrow head at the end of a line.
  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    if (direction.distance < 0.1) return;

    final normalized = direction / direction.distance;
    final perpendicular = Offset(-normalized.dy, normalized.dx);

    final arrowPoint = to;
    final arrowBack = to - normalized * _arrowSize;
    final arrowLeft = arrowBack + perpendicular * (_arrowSize / 2);
    final arrowRight = arrowBack - perpendicular * (_arrowSize / 2);

    final arrowPath = Path();
    arrowPath.moveTo(arrowPoint.dx + _arrowSize / 2, arrowPoint.dy);
    arrowPath.lineTo(arrowLeft.dx + _arrowSize / 2, arrowLeft.dy);
    arrowPath.lineTo(arrowRight.dx + _arrowSize / 2, arrowRight.dy);
    arrowPath.close();

    final fillPaint = Paint()
      ..color = paint.color.withAlpha(255)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);
  }

  /// Paint handles on middle segments for dragging.
  ///
  /// For n points, there are n-1 segments:
  /// - Segment 0: anchor segment (no handle) - exits source shape
  /// - Segments 1 to n-3: middle segments (have handles) - draggable
  /// - Segment n-2: anchor segment (no handle) - enters target shape
  void _paintSegmentHandles(Canvas canvas, List<Offset> points) {
    final handlePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw handle at midpoint of each middle segment
    // Skip segment 0 (first anchor) and segment n-2 (last anchor)
    for (
      int segmentIndex = 1;
      segmentIndex < points.length - 2;
      segmentIndex++
    ) {
      final segmentStart = points[segmentIndex];
      final segmentEnd = points[segmentIndex + 1];
      final midpoint = Offset(
        (segmentStart.dx + segmentEnd.dx) / 2,
        (segmentStart.dy + segmentEnd.dy) / 2,
      );
      canvas.drawCircle(midpoint, 5, handlePaint);
      canvas.drawCircle(midpoint, 5, handleBorderPaint);
    }
  }

  /// Create a CanvasConnector from an entity and shape lookup.
  static CanvasConnector fromEntity(
    Connector connector,
    CanvasShape sourceShape,
    CanvasShape targetShape,
  ) => CanvasConnector(
    entity: connector,
    sourceShape: sourceShape,
    targetShape: targetShape,
  );
}

// ---------------------------------------------------------------------------
// Grid Node for A* Search
// ---------------------------------------------------------------------------

/// Immutable grid node for efficient hashing in A* search.
class _GridNode {
  const _GridNode(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GridNode &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Extension on CanvasShape to provide anchor positions.
extension CanvasShapeAnchors on CanvasShape {
  /// Get the position of an anchor point on this shape.
  Offset getAnchorPosition(AnchorPoint anchor) {
    return switch (anchor) {
      AnchorPoint.top => Offset(bounds.center.dx, bounds.top - _anchorOffset),
      AnchorPoint.right => Offset(
        bounds.right + _anchorOffset,
        bounds.center.dy,
      ),
      AnchorPoint.bottom => Offset(
        bounds.center.dx,
        bounds.bottom + _anchorOffset,
      ),
      AnchorPoint.left => Offset(bounds.left - _anchorOffset, bounds.center.dy),
    };
  }

  /// Get all anchor positions as a map.
  Map<AnchorPoint, Offset> get anchorPositions => {
    AnchorPoint.top: getAnchorPosition(AnchorPoint.top),
    AnchorPoint.right: getAnchorPosition(AnchorPoint.right),
    AnchorPoint.bottom: getAnchorPosition(AnchorPoint.bottom),
    AnchorPoint.left: getAnchorPosition(AnchorPoint.left),
  };

  /// Hit test anchor points, returns the anchor if hit, null otherwise.
  AnchorPoint? hitTestAnchor(Offset point, {double tolerance = 12.0}) {
    for (final entry in anchorPositions.entries) {
      if ((point - entry.value).distance <= tolerance) {
        return entry.key;
      }
    }
    return null;
  }
}
