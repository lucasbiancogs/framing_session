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

/// User intends to rotate the shape.
class RotateIntent extends EditIntent {
  const RotateIntent();
}
