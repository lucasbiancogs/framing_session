import 'dart:math' show sqrt;
import 'dart:ui';

import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/waypoint.dart';
import 'package:whiteboard/presentation/pages/canvas/models/connector_node.dart';

/// Abstract router that defines how connectors are routed between shapes.
///
/// Routers are **stateless strategies** - they receive inputs and return outputs.
/// Different implementations can define their own routing algorithms:
/// - [LinearConnectorRouter]: Direct lines between nodes
/// - Future: ManhattanRouter, BezierRouter, etc.
///
/// If a specific router needs additional data (e.g., obstacles for avoidance),
/// it should receive that via its constructor, not through this base interface.
abstract class ConnectorRouter {
  /// Create initial nodes from anchor positions and waypoints.
  ///
  /// This defines the control points for the connector path.
  /// Different routers may add intermediate nodes (e.g., Manhattan adds corners).
  List<ConnectorNode> createInitialNodes({
    required Offset sourcePosition,
    required Offset targetPosition,
    required AnchorPoint sourceAnchor,
    required AnchorPoint targetAnchor,
    required List<Waypoint> waypoints,
  });

  /// Calculate the visual path from nodes.
  ///
  /// Returns a list of offsets representing the path to draw.
  /// Linear routers return node positions directly.
  /// Other routers may simplify, curve, or add intermediate points.
  List<Offset> route(List<ConnectorNode> nodes);

  /// Handle waypoint movement.
  ///
  /// Returns a new list of nodes after the waypoint at [index] is moved.
  /// Implementations may:
  /// - Simply update the position
  /// - Remove redundant waypoints (collinear points)
  /// - Add new waypoints for better routing
  List<ConnectorNode> onMovedWaypoint(
    List<ConnectorNode> nodes,
    int index,
    Offset newPosition,
  );
}

/// A simple linear connector router that draws straight lines between nodes.
///
/// This is the most basic routing strategy:
/// - Nodes are connected with straight line segments
/// - No automatic waypoint creation or obstacle avoidance
/// - Adds [SegmentMidNode]s on segments adjacent to anchors for interaction
///
/// Node structure:
/// - No waypoints: `Anchor → [Mid] → Anchor`
/// - With waypoints: `Anchor → [Mid] → Waypoint(s) → [Mid] → Anchor`
class LinearConnectorRouter implements ConnectorRouter {
  const LinearConnectorRouter({this.collinearThreshold = 16});

  final double collinearThreshold;

  @override
  List<ConnectorNode> createInitialNodes({
    required Offset sourcePosition,
    required Offset targetPosition,
    required AnchorPoint sourceAnchor,
    required AnchorPoint targetAnchor,
    required List<Waypoint> waypoints,
  }) {
    final sourceAnchorNode = AnchorNode(
      anchor: sourceAnchor,
      position: sourcePosition,
    );
    final targetAnchorNode = AnchorNode(
      anchor: targetAnchor,
      position: targetPosition,
    );

    if (waypoints.isEmpty) {
      // No waypoints: Anchor → [Mid] → Anchor
      final midPosition = Offset(
        (sourcePosition.dx + targetPosition.dx) / 2,
        (sourcePosition.dy + targetPosition.dy) / 2,
      );
      return [
        sourceAnchorNode,
        SegmentMidNode(position: midPosition),
        targetAnchorNode,
      ];
    }

    // With waypoints: Anchor → [Mid] → Waypoints → [Mid] → Anchor
    final waypointNodes = waypoints.map(
      (wp) => WaypointNode(position: Offset(wp.x, wp.y)),
    );
    final firstWaypoint = waypointNodes.first;
    final lastWaypoint = waypointNodes.last;

    // Mid between source anchor and first waypoint
    final sourceMidPosition = Offset(
      (sourcePosition.dx + firstWaypoint.position.dx) / 2,
      (sourcePosition.dy + firstWaypoint.position.dy) / 2,
    );

    // Mid between last waypoint and target anchor
    final targetMidPosition = Offset(
      (lastWaypoint.position.dx + targetPosition.dx) / 2,
      (lastWaypoint.position.dy + targetPosition.dy) / 2,
    );

    return [
      sourceAnchorNode,
      SegmentMidNode(position: sourceMidPosition),
      ...waypointNodes,
      SegmentMidNode(position: targetMidPosition),
      targetAnchorNode,
    ];
  }

  @override
  List<Offset> route(List<ConnectorNode> nodes) {
    // Linear routing: return positions, but skip SegmentMidNodes for the path
    // (they're only for interaction, not for drawing)
    return nodes
        .where((node) => node is! SegmentMidNode)
        .map((node) => node.position)
        .toList();
  }

  @override
  List<ConnectorNode> onMovedWaypoint(
    List<ConnectorNode> nodes,
    int index,
    Offset newPosition,
  ) {
    if (index <= 0 || index >= nodes.length - 1) {
      return nodes;
    }

    final node = nodes[index];

    // Handle SegmentMidNode drag → converts to WaypointNode
    if (node is SegmentMidNode) {
      return _convertMidToWaypoint(nodes, index, newPosition);
    }

    // Handle regular WaypointNode drag
    if (node is WaypointNode) {
      return _moveWaypoint(nodes, index, newPosition);
    }

    return nodes;
  }

  /// Convert a SegmentMidNode to a WaypointNode and recalculate mid nodes.
  List<ConnectorNode> _convertMidToWaypoint(
    List<ConnectorNode> nodes,
    int index,
    Offset newPosition,
  ) {
    // Find the anchor nodes (first and last)
    final sourceAnchor = nodes.first as AnchorNode;
    final targetAnchor = nodes.last as AnchorNode;

    // Extract existing waypoints (excluding anchors and mid nodes)
    final existingWaypoints = <WaypointNode>[];
    for (int i = 1; i < nodes.length - 1; i++) {
      if (nodes[i] is WaypointNode) {
        existingWaypoints.add(nodes[i] as WaypointNode);
      }
    }

    // Determine where to insert the new waypoint based on which mid was dragged
    final isSourceMid = index == 1; // First mid is always at index 1

    final newWaypoint = WaypointNode(position: newPosition);

    List<WaypointNode> allWaypoints;
    if (existingWaypoints.isEmpty) {
      // No existing waypoints, new one becomes the only waypoint
      allWaypoints = [newWaypoint];
    } else if (isSourceMid) {
      // Insert at the beginning
      allWaypoints = [newWaypoint, ...existingWaypoints];
    } else {
      // Insert at the end
      allWaypoints = [...existingWaypoints, newWaypoint];
    }

    // Simplify collinear waypoints
    final simplifiedWaypoints = _simplifyCollinearWaypoints(
      sourceAnchor.position,
      targetAnchor.position,
      allWaypoints,
    );

    // Rebuild nodes with new mid nodes
    return _buildNodesWithMids(sourceAnchor, targetAnchor, simplifiedWaypoints);
  }

  /// Move an existing waypoint and recalculate mid nodes.
  List<ConnectorNode> _moveWaypoint(
    List<ConnectorNode> nodes,
    int index,
    Offset newPosition,
  ) {
    final sourceAnchor = nodes.first as AnchorNode;
    final targetAnchor = nodes.last as AnchorNode;

    // Extract and update waypoints
    final waypoints = <WaypointNode>[];
    for (int i = 1; i < nodes.length - 1; i++) {
      if (nodes[i] is WaypointNode) {
        if (i == index) {
          waypoints.add(WaypointNode(position: newPosition));
        } else {
          waypoints.add(nodes[i] as WaypointNode);
        }
      }
    }

    // Simplify collinear waypoints
    final simplifiedWaypoints = _simplifyCollinearWaypoints(
      sourceAnchor.position,
      targetAnchor.position,
      waypoints,
    );

    // Rebuild nodes with updated mid nodes
    return _buildNodesWithMids(sourceAnchor, targetAnchor, simplifiedWaypoints);
  }

  /// Build the complete node list with SegmentMidNodes.
  List<ConnectorNode> _buildNodesWithMids(
    AnchorNode sourceAnchor,
    AnchorNode targetAnchor,
    List<WaypointNode> waypoints,
  ) {
    if (waypoints.isEmpty) {
      final midPosition = Offset(
        (sourceAnchor.position.dx + targetAnchor.position.dx) / 2,
        (sourceAnchor.position.dy + targetAnchor.position.dy) / 2,
      );
      return [
        sourceAnchor,
        SegmentMidNode(position: midPosition),
        targetAnchor,
      ];
    }

    final firstWaypoint = waypoints.first;
    final lastWaypoint = waypoints.last;

    final sourceMidPosition = Offset(
      (sourceAnchor.position.dx + firstWaypoint.position.dx) / 2,
      (sourceAnchor.position.dy + firstWaypoint.position.dy) / 2,
    );

    final targetMidPosition = Offset(
      (lastWaypoint.position.dx + targetAnchor.position.dx) / 2,
      (lastWaypoint.position.dy + targetAnchor.position.dy) / 2,
    );

    return [
      sourceAnchor,
      SegmentMidNode(position: sourceMidPosition),
      ...waypoints,
      SegmentMidNode(position: targetMidPosition),
      targetAnchor,
    ];
  }

  /// Simplify waypoints by removing those that are collinear with neighbors.
  ///
  /// A waypoint is removed if it lies on the line between its neighbors
  /// within [_collinearThreshold] distance.
  List<WaypointNode> _simplifyCollinearWaypoints(
    Offset sourcePosition,
    Offset targetPosition,
    List<WaypointNode> waypoints,
  ) {
    if (waypoints.isEmpty) return waypoints;

    // Build list of all points: source → waypoints → target
    final allPoints = <Offset>[
      sourcePosition,
      ...waypoints.map((wp) => wp.position),
      targetPosition,
    ];

    // Track which waypoints to keep (indices in original waypoints list)
    final keepIndices = <int>{};

    // Check each waypoint (indices 1 to allPoints.length - 2 in allPoints,
    // which maps to indices 0 to waypoints.length - 1 in waypoints)
    for (int i = 0; i < waypoints.length; i++) {
      final prevPoint = allPoints[i]; // Previous point (source or waypoint)
      final currentPoint = allPoints[i + 1]; // Current waypoint
      final nextPoint = allPoints[i + 2]; // Next point (waypoint or target)

      if (!_isCollinear(prevPoint, currentPoint, nextPoint)) {
        keepIndices.add(i);
      }
    }

    // Return filtered waypoints
    return [
      for (int i = 0; i < waypoints.length; i++)
        if (keepIndices.contains(i)) waypoints[i],
    ];
  }

  /// Check if point B is collinear with line A-C within threshold.
  ///
  /// Returns true if the perpendicular distance from B to line A-C
  /// is less than [_collinearThreshold].
  bool _isCollinear(Offset a, Offset b, Offset c) {
    final distance = _distanceToLine(b, a, c);
    return distance < collinearThreshold;
  }

  /// Calculate perpendicular distance from point P to line defined by A-B.
  ///
  /// Uses the formula: |((B-A) × (A-P))| / |B-A|
  /// where × is the 2D cross product (returns a scalar).
  double _distanceToLine(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;

    // Handle degenerate case where A and B are the same point
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared < 0.0001) {
      // Return distance to point A
      return (p - a).distance;
    }

    // 2D cross product: ab × ap = ab.dx * ap.dy - ab.dy * ap.dx
    final crossProduct = ab.dx * ap.dy - ab.dy * ap.dx;

    // Perpendicular distance = |cross product| / |ab|
    return crossProduct.abs() / sqrt(abLengthSquared);
  }
}
