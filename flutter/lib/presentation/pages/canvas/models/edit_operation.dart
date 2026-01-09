import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'edit_intent.dart';

/// An immutable operation that describes a change to a shape.
///
/// Operations use **absolute values** (not deltas) so that the last operation
/// always represents the correct final state. This is a "Last Write Wins" (LWW)
/// approach that ensures consistency even if intermediate updates are lost.
///
/// Operations are:
/// - Applied locally (optimistic update)
/// - Broadcast to other clients
/// - Consumed by all clients (including the sender)
///
/// Operations, not state, are the unit of collaboration.
@immutable
sealed class EditOperation extends Equatable {
  const EditOperation({required this.opId, required this.shapeId});

  /// Unique identifier for this operation (for deduplication).
  final String opId;

  /// The shape this operation targets.
  final String shapeId;

  @override
  List<Object?> get props => [opId, shapeId];
}

/// Move a shape to an absolute position.
class MoveOperation extends EditOperation {
  const MoveOperation({
    required super.opId,
    required super.shapeId,
    required this.position,
  });

  /// The final absolute position (top-left corner) of the shape.
  final Offset position;

  @override
  List<Object?> get props => [...super.props, position];
}

/// Resize a shape to absolute bounds.
class ResizeOperation extends EditOperation {
  const ResizeOperation({
    required super.opId,
    required super.shapeId,
    required this.handle,
    required this.bounds,
  });

  /// The handle used for the resize (for cursor feedback).
  final ResizeHandle handle;

  /// The final absolute bounds (x, y, width, height) of the shape.
  final Rect bounds;

  @override
  List<Object?> get props => [...super.props, handle, bounds];
}

/// Create a new shape.
class CreateOperation extends EditOperation {
  const CreateOperation({required super.opId, required super.shapeId});
}

/// Delete a shape.
class DeleteOperation extends EditOperation {
  const DeleteOperation({required super.opId, required super.shapeId});
}

/// Update a shape's text content.
class TextEditOperation extends EditOperation {
  const TextEditOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  /// The new text content for the shape.
  final String text;

  @override
  List<Object?> get props => [...super.props, text];
}
