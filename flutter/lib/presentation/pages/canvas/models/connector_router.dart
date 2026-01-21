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
/// - Collinear waypoints can be simplified (optional)
class LinearConnectorRouter implements ConnectorRouter {
  const LinearConnectorRouter();

  @override
  List<ConnectorNode> createInitialNodes({
    required Offset sourcePosition,
    required Offset targetPosition,
    required AnchorPoint sourceAnchor,
    required AnchorPoint targetAnchor,
    required List<Waypoint> waypoints,
  }) {
    return [
      AnchorNode(anchor: sourceAnchor, position: sourcePosition),
      ...waypoints.map((wp) => WaypointNode(position: Offset(wp.x, wp.y))),
      AnchorNode(anchor: targetAnchor, position: targetPosition),
    ];
  }

  @override
  List<Offset> route(List<ConnectorNode> nodes) {
    // Linear routing: just return the node positions in order
    return nodes.map((node) => node.position).toList();
  }

  @override
  List<ConnectorNode> onMovedWaypoint(
    List<ConnectorNode> nodes,
    int index,
    Offset newPosition,
  ) {
    // Validate index (must be a waypoint, not an anchor)
    if (index <= 0 || index >= nodes.length - 1) {
      return nodes;
    }

    final node = nodes[index];
    if (node is! WaypointNode) {
      return nodes;
    }

    // Create new list with updated waypoint
    final newNodes = List<ConnectorNode>.from(nodes);
    newNodes[index] = WaypointNode(position: newPosition);

    // Optionally simplify collinear points
    return _simplifyCollinearNodes(newNodes);
  }

  /// Remove waypoints that are collinear with their neighbors.
  ///
  /// A point is collinear if it lies on the line between its neighbors
  /// (within a small tolerance).
  List<ConnectorNode> _simplifyCollinearNodes(List<ConnectorNode> nodes) {
    if (nodes.length <= 2) return nodes;

    const tolerance = 5.0; // pixels
    final result = <ConnectorNode>[nodes.first];

    for (int i = 1; i < nodes.length - 1; i++) {
      final prev = result.last.position;
      final curr = nodes[i].position;
      final next = nodes[i + 1].position;

      // Skip anchor nodes - they should never be removed
      if (nodes[i] is AnchorNode) {
        result.add(nodes[i]);
        continue;
      }

      // Check if current point is collinear with prev and next
      if (!_isCollinear(prev, curr, next, tolerance)) {
        result.add(nodes[i]);
      }
    }

    result.add(nodes.last);
    return result;
  }

  /// Check if point [b] lies on the line segment from [a] to [c].
  bool _isCollinear(Offset a, Offset b, Offset c, double tolerance) {
    // Calculate the perpendicular distance from b to line ac
    final lineLength = (c - a).distance;
    if (lineLength < tolerance) return true; // a and c are very close

    // Cross product gives area of parallelogram, divide by base for height
    final crossProduct =
        (c.dx - a.dx) * (b.dy - a.dy) - (c.dy - a.dy) * (b.dx - a.dx);
    final distance = crossProduct.abs() / lineLength;

    return distance < tolerance;
  }
}
