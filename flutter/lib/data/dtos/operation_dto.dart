import 'package:whiteboard/core/errors/inconsistency_error.dart';
import 'package:whiteboard/data/dtos/anchor_point_dto.dart';
import 'package:whiteboard/data/dtos/arrow_type_dto.dart';
import 'package:whiteboard/data/dtos/waypoint_dto.dart';
import 'package:whiteboard/domain/entities/operation.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';

class _OperationTypes {
  static const String move = 'move';
  static const String resize = 'resize';
  static const String create = 'create';
  static const String delete = 'delete';
  static const String text = 'text';
  static const String paste = 'paste';
  static const String createConnector = 'create_connector';
  static const String updateConnectorWaypoints = 'update_connector_waypoints';
  static const String deleteConnector = 'delete_connector';
  // Ephemeral operations
  static const String updateConnectingPreview = 'update_connecting_preview';
  static const String moveConnectorNode = 'move_connector_node';
}

sealed class OperationDto {
  const OperationDto({
    required this.opId,
    required this.shapeId,
    required this.type,
  });

  final String opId;
  final String shapeId;
  final String type;

  factory OperationDto.fromJson(Map<String, dynamic> json) {
    final type = json['operation_type'] as String;

    return switch (type) {
      _OperationTypes.move => MoveShapeOperationDto.fromJson(json),
      _OperationTypes.resize => ResizeShapeOperationDto.fromJson(json),
      _OperationTypes.create => CreateShapeOperationDto.fromJson(json),
      _OperationTypes.delete => DeleteShapeOperationDto.fromJson(json),
      _OperationTypes.text => TextShapeOperationDto.fromJson(json),
      _OperationTypes.paste => PasteShapeOperationDto.fromJson(json),
      _OperationTypes.createConnector => CreateConnectorOperationDto.fromJson(
        json,
      ),
      _OperationTypes.updateConnectorWaypoints =>
        UpdateConnectorWaypointsOperationDto.fromJson(json),
      _OperationTypes.deleteConnector => DeleteConnectorOperationDto.fromJson(
        json,
      ),
      // Ephemeral operations
      _OperationTypes.updateConnectingPreview =>
        UpdateConnectingPreviewOperationDto.fromJson(json),
      _OperationTypes.moveConnectorNode =>
        MoveConnectorNodeOperationDto.fromJson(json),
      _ => throw InconsistencyError.internal('Unknown operation type: $type'),
    };
  }

  factory OperationDto.fromEntity(Operation entity) {
    return switch (entity) {
      MoveShapeOperation() => MoveShapeOperationDto.fromEntity(entity),
      ResizeShapeOperation() => ResizeShapeOperationDto.fromEntity(entity),
      CreateShapeOperation() => CreateShapeOperationDto.fromEntity(entity),
      DeleteShapeOperation() => DeleteShapeOperationDto.fromEntity(entity),
      TextShapeOperation() => TextShapeOperationDto.fromEntity(entity),
      PasteShapeOperation() => PasteShapeOperationDto.fromEntity(entity),
      CreateConnectorOperation() => CreateConnectorOperationDto.fromEntity(
        entity,
      ),
      UpdateConnectorWaypointsOperation() =>
        UpdateConnectorWaypointsOperationDto.fromEntity(entity),
      DeleteConnectorOperation() => DeleteConnectorOperationDto.fromEntity(
        entity,
      ),
      // Ephemeral operations
      UpdateConnectingPreviewOperation() =>
        UpdateConnectingPreviewOperationDto.fromEntity(entity),
      MoveConnectorNodeOperation() => MoveConnectorNodeOperationDto.fromEntity(
        entity,
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

class MoveShapeOperationDto extends OperationDto {
  const MoveShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  factory MoveShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return MoveShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  factory MoveShapeOperationDto.fromEntity(MoveShapeOperation entity) =>
      MoveShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.move,
        x: entity.x,
        y: entity.y,
      );

  @override
  MoveShapeOperation toEntity() =>
      MoveShapeOperation(opId: opId, shapeId: shapeId, x: x, y: y);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'x': x, 'y': y};
}

class ResizeShapeOperationDto extends OperationDto {
  const ResizeShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory ResizeShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return ResizeShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  factory ResizeShapeOperationDto.fromEntity(ResizeShapeOperation entity) =>
      ResizeShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.resize,
        x: entity.x,
        y: entity.y,
        width: entity.width,
        height: entity.height,
      );

  @override
  ResizeShapeOperation toEntity() => ResizeShapeOperation(
    opId: opId,
    shapeId: shapeId,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class CreateShapeOperationDto extends OperationDto {
  const CreateShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.shapeType,
    required this.color,
    required this.x,
    required this.y,
  });

  final String shapeType;
  final String color;
  final double x;
  final double y;

  factory CreateShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return CreateShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      shapeType: json['shape_type'] as String,
      color: json['color'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  factory CreateShapeOperationDto.fromEntity(CreateShapeOperation entity) =>
      CreateShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.create,
        shapeType: entity.shapeType.name,
        color: entity.color,
        x: entity.x,
        y: entity.y,
      );

  @override
  CreateShapeOperation toEntity() => CreateShapeOperation(
    opId: opId,
    shapeId: shapeId,
    color: color,
    x: x,
    y: y,
    shapeType: ShapeType.values.byName(shapeType),
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'color': color,
    'x': x,
    'y': y,
    'shape_type': shapeType,
  };
}

class DeleteShapeOperationDto extends OperationDto {
  const DeleteShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
  });

  factory DeleteShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return DeleteShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
    );
  }

  factory DeleteShapeOperationDto.fromEntity(DeleteShapeOperation entity) =>
      DeleteShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.delete,
      );

  @override
  DeleteShapeOperation toEntity() =>
      DeleteShapeOperation(opId: opId, shapeId: shapeId);
}

class TextShapeOperationDto extends OperationDto {
  const TextShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.text,
  });

  final String text;

  factory TextShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return TextShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      text: json['text'] as String,
    );
  }

  factory TextShapeOperationDto.fromEntity(TextShapeOperation entity) =>
      TextShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.text,
        text: entity.text,
      );

  @override
  TextShapeOperation toEntity() =>
      TextShapeOperation(opId: opId, shapeId: shapeId, text: text);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'text': text};
}

class PasteShapeOperationDto extends OperationDto {
  const PasteShapeOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.shapeType,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    this.text,
  });

  final String shapeType;
  final double x;
  final double y;
  final double width;
  final double height;
  final String color;
  final String? text;

  factory PasteShapeOperationDto.fromJson(Map<String, dynamic> json) {
    return PasteShapeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      shapeType: json['shape_type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      color: json['color'] as String,
      text: json['text'] as String?,
    );
  }

  factory PasteShapeOperationDto.fromEntity(PasteShapeOperation entity) =>
      PasteShapeOperationDto(
        opId: entity.opId,
        shapeId: entity.shapeId,
        type: _OperationTypes.paste,
        shapeType: entity.shapeType.name,
        x: entity.x,
        y: entity.y,
        width: entity.width,
        height: entity.height,
        color: entity.color,
        text: entity.text,
      );

  @override
  PasteShapeOperation toEntity() => PasteShapeOperation(
    opId: opId,
    shapeId: shapeId,
    shapeType: ShapeType.values.byName(shapeType),
    x: x,
    y: y,
    width: width,
    height: height,
    color: color,
    text: text,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'shape_type': shapeType,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'color': color,
    if (text != null) 'text': text,
  };
}

// -------------------------------------------------------------------------
// Connector Operation DTOs
// -------------------------------------------------------------------------

class CreateConnectorOperationDto extends OperationDto {
  const CreateConnectorOperationDto({
    required super.opId,
    required super.shapeId, // connector ID
    required super.type,
    required this.sourceShapeId,
    required this.targetShapeId,
    required this.sourceAnchor,
    required this.targetAnchor,
    required this.arrowType,
    required this.color,
  });

  final String sourceShapeId;
  final String targetShapeId;
  final AnchorPointDto sourceAnchor;
  final AnchorPointDto targetAnchor;
  final ArrowTypeDto arrowType;
  final String color;

  factory CreateConnectorOperationDto.fromJson(Map<String, dynamic> json) {
    return CreateConnectorOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      sourceShapeId: json['source_shape_id'] as String,
      targetShapeId: json['target_shape_id'] as String,
      sourceAnchor: AnchorPointDto.fromString(json['source_anchor'] as String),
      targetAnchor: AnchorPointDto.fromString(json['target_anchor'] as String),
      arrowType: ArrowTypeDto.fromString(json['arrow_type'] as String),
      color: json['color'] as String,
    );
  }

  factory CreateConnectorOperationDto.fromEntity(
    CreateConnectorOperation entity,
  ) => CreateConnectorOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.createConnector,
    sourceShapeId: entity.sourceShapeId,
    targetShapeId: entity.targetShapeId,
    sourceAnchor: AnchorPointDto.fromString(entity.sourceAnchor.name),
    targetAnchor: AnchorPointDto.fromString(entity.targetAnchor.name),
    arrowType: ArrowTypeDto.fromString(entity.arrowType.name),
    color: entity.color,
  );

  @override
  CreateConnectorOperation toEntity() => CreateConnectorOperation(
    opId: opId,
    shapeId: shapeId,
    sourceShapeId: sourceShapeId,
    targetShapeId: targetShapeId,
    sourceAnchor: sourceAnchor.toEntity(),
    targetAnchor: targetAnchor.toEntity(),
    arrowType: arrowType.toEntity(),
    color: color,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'source_shape_id': sourceShapeId,
    'target_shape_id': targetShapeId,
    'source_anchor': sourceAnchor.raw,
    'target_anchor': targetAnchor.raw,
    'arrow_type': arrowType.raw,
    'color': color,
  };
}

class UpdateConnectorWaypointsOperationDto extends OperationDto {
  const UpdateConnectorWaypointsOperationDto({
    required super.opId,
    required super.shapeId,
    required super.type,
    required this.waypoints,
  });

  final List<WaypointDto> waypoints;

  factory UpdateConnectorWaypointsOperationDto.fromJson(
    Map<String, dynamic> json,
  ) => UpdateConnectorWaypointsOperationDto(
    opId: json['op_id'] as String,
    shapeId: json['shape_id'] as String,
    type: json['operation_type'] as String,
    waypoints: (json['waypoints'] as List<dynamic>)
        .map((wp) => WaypointDto.fromJson(wp as Map<String, dynamic>))
        .toList(),
  );

  factory UpdateConnectorWaypointsOperationDto.fromEntity(
    UpdateConnectorWaypointsOperation entity,
  ) => UpdateConnectorWaypointsOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.updateConnectorWaypoints,
    waypoints: entity.waypoints
        .map((wp) => WaypointDto.fromEntity(wp))
        .toList(),
  );

  @override
  UpdateConnectorWaypointsOperation toEntity() =>
      UpdateConnectorWaypointsOperation(
        opId: opId,
        shapeId: shapeId,
        waypoints: waypoints.map((wp) => wp.toEntity()).toList(),
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'waypoints': waypoints.map((wp) => wp.toJson()).toList(),
  };
}

class DeleteConnectorOperationDto extends OperationDto {
  const DeleteConnectorOperationDto({
    required super.opId,
    required super.shapeId, // connector ID
    required super.type,
  });

  factory DeleteConnectorOperationDto.fromJson(Map<String, dynamic> json) {
    return DeleteConnectorOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
    );
  }

  factory DeleteConnectorOperationDto.fromEntity(
    DeleteConnectorOperation entity,
  ) => DeleteConnectorOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.deleteConnector,
  );

  @override
  DeleteConnectorOperation toEntity() =>
      DeleteConnectorOperation(opId: opId, shapeId: shapeId);
}

// -------------------------------------------------------------------------
// Ephemeral Operation DTOs (broadcast but not persisted)
// -------------------------------------------------------------------------

class UpdateConnectingPreviewOperationDto extends OperationDto {
  const UpdateConnectingPreviewOperationDto({
    required super.opId,
    required super.shapeId, // source shape ID
    required super.type,
    required this.sourceAnchor,
    required this.x,
    required this.y,
  });

  final AnchorPointDto sourceAnchor;
  final double x;
  final double y;

  factory UpdateConnectingPreviewOperationDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpdateConnectingPreviewOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      sourceAnchor: AnchorPointDto.fromString(json['source_anchor'] as String),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  factory UpdateConnectingPreviewOperationDto.fromEntity(
    UpdateConnectingPreviewOperation entity,
  ) => UpdateConnectingPreviewOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.updateConnectingPreview,
    sourceAnchor: AnchorPointDto.fromString(entity.sourceAnchor.name),
    x: entity.x,
    y: entity.y,
  );

  @override
  UpdateConnectingPreviewOperation toEntity() =>
      UpdateConnectingPreviewOperation(
        opId: opId,
        shapeId: shapeId,
        sourceAnchor: sourceAnchor.toEntity(),
        x: x,
        y: y,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'source_anchor': sourceAnchor.raw,
    'x': x,
    'y': y,
  };
}

class MoveConnectorNodeOperationDto extends OperationDto {
  const MoveConnectorNodeOperationDto({
    required super.opId,
    required super.shapeId, // connector ID
    required super.type,
    required this.nodeIndex,
    required this.x,
    required this.y,
  });

  final int nodeIndex;
  final double x;
  final double y;

  factory MoveConnectorNodeOperationDto.fromJson(Map<String, dynamic> json) {
    return MoveConnectorNodeOperationDto(
      opId: json['op_id'] as String,
      shapeId: json['shape_id'] as String,
      type: json['operation_type'] as String,
      nodeIndex: json['node_index'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  factory MoveConnectorNodeOperationDto.fromEntity(
    MoveConnectorNodeOperation entity,
  ) => MoveConnectorNodeOperationDto(
    opId: entity.opId,
    shapeId: entity.shapeId,
    type: _OperationTypes.moveConnectorNode,
    nodeIndex: entity.nodeIndex,
    x: entity.x,
    y: entity.y,
  );

  @override
  MoveConnectorNodeOperation toEntity() => MoveConnectorNodeOperation(
    opId: opId,
    shapeId: shapeId,
    nodeIndex: nodeIndex,
    x: x,
    y: y,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'node_index': nodeIndex,
    'x': x,
    'y': y,
  };
}
