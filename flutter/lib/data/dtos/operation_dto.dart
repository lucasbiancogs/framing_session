import 'package:whiteboard/core/errors/inconsistency_error.dart';
import 'package:whiteboard/domain/entities/operation.dart';

class _OperationTypes {
  static const String move = 'move';
  static const String resize = 'resize';
  static const String create = 'create';
  static const String delete = 'delete';
  static const String text = 'text';
}

abstract class OperationDto {
  const OperationDto({
    required this.opId,
    required this.shapeId,
    required this.type,
  });

  final String opId;
  final String shapeId;
  final String type;

  factory OperationDto.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    return switch (type) {
      _OperationTypes.move => MoveOperationDto.fromJson(json),
      _OperationTypes.resize => ResizeOperationDto.fromJson(json),
      _OperationTypes.create => CreateOperationDto.fromJson(json),
      _OperationTypes.delete => DeleteOperationDto.fromJson(json),
      _OperationTypes.text => TextOperationDto.fromJson(json),
      _ => throw InconsistencyError.internal('Unknown operation type: $type'),
    };
  }

  factory OperationDto.fromEntity(Operation entity) {
    return switch (entity) {
      MoveOperation() => MoveOperationDto.fromEntity(entity),
      ResizeOperation() => ResizeOperationDto.fromEntity(entity),
      CreateOperation() => CreateOperationDto.fromEntity(entity),
      DeleteOperation() => DeleteOperationDto.fromEntity(entity),
      TextOperation() => TextOperationDto.fromEntity(entity),
      _ => throw InconsistencyError.internal(
        'Unknown operation type: ${entity.runtimeType}',
      ),
    };
  }

  Operation toEntity();

  Map<String, dynamic> toJson() => {
    'operation_type': type,
    'op_id': opId,
    'shape_id': shapeId,
  };
}

class MoveOperationDto extends OperationDto {
  const MoveOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  factory MoveOperationDto.fromJson(Map<String, dynamic> json) {
    return MoveOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      x: json['x'] as double,
      y: json['y'] as double,
    );
  }

  factory MoveOperationDto.fromEntity(MoveOperation entity) => MoveOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.move,
    x: entity.x,
    y: entity.y,
  );

  @override
  MoveOperation toEntity() =>
      MoveOperation(opId: opId, shapeId: shapeId, x: x, y: y);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'x': x, 'y': y};
}

class ResizeOperationDto extends OperationDto {
  const ResizeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  factory ResizeOperationDto.fromJson(Map<String, dynamic> json) {
    return ResizeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      width: json['width'] as double,
      height: json['height'] as double,
    );
  }

  factory ResizeOperationDto.fromEntity(ResizeOperation entity) =>
      ResizeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.resize,
        width: entity.width,
        height: entity.height,
      );

  @override
  ResizeOperation toEntity() => ResizeOperation(
    opId: opId,
    shapeId: shapeId,
    width: width,
    height: height,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'width': width,
    'height': height,
  };
}

class CreateOperationDto extends OperationDto {
  const CreateOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
  });

  factory CreateOperationDto.fromJson(Map<String, dynamic> json) {
    return CreateOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
    );
  }

  factory CreateOperationDto.fromEntity(CreateOperation entity) =>
      CreateOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.create,
      );

  @override
  CreateOperation toEntity() => CreateOperation(opId: opId, shapeId: shapeId);
}

class DeleteOperationDto extends OperationDto {
  const DeleteOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
  });

  factory DeleteOperationDto.fromJson(Map<String, dynamic> json) {
    return DeleteOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
    );
  }

  factory DeleteOperationDto.fromEntity(DeleteOperation entity) =>
      DeleteOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.delete,
      );

  @override
  DeleteOperation toEntity() => DeleteOperation(opId: opId, shapeId: shapeId);
}

class TextOperationDto extends OperationDto {
  const TextOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.text,
  });

  final String text;

  factory TextOperationDto.fromJson(Map<String, dynamic> json) {
    return TextOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      text: json['text'] as String,
    );
  }

  factory TextOperationDto.fromEntity(TextOperation entity) => TextOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.text,
    text: entity.text,
  );

  @override
  TextOperation toEntity() =>
      TextOperation(opId: opId, shapeId: shapeId, text: text);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'text': text};
}
