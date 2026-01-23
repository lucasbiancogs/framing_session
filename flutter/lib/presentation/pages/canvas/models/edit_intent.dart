import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Resize handle positions around a shape's bounding box.
enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  centerLeft,
  centerRight,
  bottomCenter,
}

/// Represents the user's intended edit action based on where they touched.
///
/// EditIntent is determined by hit-testing — the shape decides what
/// kind of edit the user wants based on the touch position.
///
/// This is a presentation-layer concept, not domain.
@immutable
sealed class EditIntent extends Equatable {
  const EditIntent();

  @override
  List<Object?> get props => [];
}

/// User intends to move the shape.
class MoveIntent extends EditIntent {
  const MoveIntent();
}

/// User intends to resize the shape via a handle.
class ResizeIntent extends EditIntent {
  const ResizeIntent(this.handle);

  final ResizeHandle handle;

  @override
  List<Object?> get props => [handle];

  @override
  String toString() => 'ResizeIntent(handle: $handle)';
}

// ---------------------------------------------------------------------------
// Connector-Specific Intents
// ---------------------------------------------------------------------------

/// User intends to move a connector node (waypoint or segment mid).
class MoveConnectorNodeIntent extends EditIntent {
  const MoveConnectorNodeIntent(this.nodeIndex);

  /// The index of the node in the connector's nodes list.
  final int nodeIndex;

  @override
  List<Object?> get props => [nodeIndex];

  @override
  String toString() => 'MoveConnectorNodeIntent(nodeIndex: $nodeIndex)';
}

/// User intends to select a connector (clicked on a segment).
class SelectConnectorIntent extends EditIntent {
  const SelectConnectorIntent();
}
