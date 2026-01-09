import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'edit_intent.dart';

/// An immutable operation that describes a change to a shape.
///
/// Operations are:
/// - Applied locally (optimistic update)
/// - Broadcast to other clients
/// - Consumed by all clients (including the sender)
///
/// Operations, not state, are the unit of collaboration.
@immutable
sealed class EditOperation extends Equatable {
  const EditOperation({
    required this.opId,
    required this.shapeId,
    this.revision,
  });

  /// Unique identifier for this operation (for deduplication).
  final String opId;

  /// The shape this operation targets.
  final String shapeId;

  /// Monotonically increasing revision number (for ordering/resync).
  final int? revision;

  @override
  List<Object?> get props => [opId, shapeId, revision];
}

/// Move a shape by a delta.
class MoveOperation extends EditOperation {
  const MoveOperation({
    required super.opId,
    required super.shapeId,
    required this.delta,
    super.revision,
  });

  final Offset delta;

  @override
  List<Object?> get props => [...super.props, delta];
}

/// Resize a shape via a handle.
class ResizeOperation extends EditOperation {
  const ResizeOperation({
    required super.opId,
    required super.shapeId,
    required this.handle,
    required this.delta,
    super.revision,
  });

  final ResizeHandle handle;
  final Offset delta;

  @override
  List<Object?> get props => [...super.props, handle, delta];
}

/// Create a new shape.
class CreateOperation extends EditOperation {
  const CreateOperation({
    required super.opId,
    required super.shapeId,
    super.revision,
  });
}

/// Delete a shape.
class DeleteOperation extends EditOperation {
  const DeleteOperation({
    required super.opId,
    required super.shapeId,
    super.revision,
  });
}

/// Update a shape's text content.
class TextEditOperation extends EditOperation {
  const TextEditOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
    super.revision,
  });

  /// The new text content for the shape.
  final String text;

  @override
  List<Object?> get props => [...super.props, text];
}
