import 'package:equatable/equatable.dart';

abstract class Operation extends Equatable {
  const Operation({required this.opId, required this.shapeId});

  final String opId;
  final String shapeId;

  @override
  List<Object?> get props => [opId, shapeId];
}

class MoveOperation extends Operation {
  const MoveOperation({
    required super.opId,
    required super.shapeId,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  @override
  List<Object?> get props => [...super.props, x, y];
}

class ResizeOperation extends Operation {
  const ResizeOperation({
    required super.opId,
    required super.shapeId,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  List<Object?> get props => [...super.props, width, height];
}

class CreateOperation extends Operation {
  const CreateOperation({required super.opId, required super.shapeId});

  @override
  List<Object?> get props => [...super.props];
}

class DeleteOperation extends Operation {
  const DeleteOperation({required super.opId, required super.shapeId});

  @override
  List<Object?> get props => [...super.props];
}

class TextOperation extends Operation {
  const TextOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  final String text;
}
