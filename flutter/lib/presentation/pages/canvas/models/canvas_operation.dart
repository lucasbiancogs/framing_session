import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:whiteboard/domain/entities/operation.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';

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
sealed class CanvasOperation extends Equatable {
  const CanvasOperation({required this.opId, required this.shapeId});

  /// Unique identifier for this operation (for deduplication).
  final String opId;

  /// The shape this operation targets.
  final String shapeId;

  factory CanvasOperation.fromEntity(Operation entity) {
    return switch (entity) {
      MoveOperation() => MoveShapeOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        position: Offset(entity.x, entity.y),
      ),
      ResizeOperation() => ResizeShapeOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        handle: ResizeHandle.topLeft,
        bounds: Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height),
      ),
      CreateOperation() => CreateShapeOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        shapeType: entity.shapeType,
        color: entity.color,
        x: entity.x,
        y: entity.y,
      ),
      DeleteOperation() => DeleteShapeOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
      ),
      TextOperation() => TextShapeOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        text: entity.text,
      ),
    };
  }

  Operation toEntity();

  @override
  List<Object?> get props => [opId, shapeId];
}

/// Move a shape to an absolute position.
class MoveShapeOperation extends CanvasOperation {
  const MoveShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.position,
  });

  /// The final absolute position (top-left corner) of the shape.
  final Offset position;

  @override
  Operation toEntity() => MoveOperation(
    opId: opId,
    shapeId: shapeId,
    x: position.dx,
    y: position.dy,
  );

  @override
  List<Object?> get props => [...super.props, position];
}

/// Resize a shape to absolute bounds.
class ResizeShapeOperation extends CanvasOperation {
  const ResizeShapeOperation({
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
  Operation toEntity() => ResizeOperation(
    opId: opId,
    shapeId: shapeId,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );

  @override
  List<Object?> get props => [...super.props, handle, bounds];
}

/// Create a new shape.
class CreateShapeOperation extends CanvasOperation {
  const CreateShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.shapeType,
    required this.color,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
  final String color;
  final ShapeType shapeType;

  @override
  Operation toEntity() => CreateOperation(
    opId: opId,
    shapeId: shapeId,
    color: color,
    x: x,
    y: y,
    shapeType: shapeType,
  );

  @override
  List<Object?> get props => [...super.props, x, y, shapeType, color];
}

/// Delete a shape.
class DeleteShapeOperation extends CanvasOperation {
  const DeleteShapeOperation({required super.opId, required super.shapeId});

  @override
  Operation toEntity() => DeleteOperation(opId: opId, shapeId: shapeId);
}

/// Update a shape's text content.
class TextShapeOperation extends CanvasOperation {
  const TextShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  /// The new text content for the shape.
  final String text;

  @override
  Operation toEntity() =>
      TextOperation(opId: opId, shapeId: shapeId, text: text);

  @override
  List<Object?> get props => [...super.props, text];
}
