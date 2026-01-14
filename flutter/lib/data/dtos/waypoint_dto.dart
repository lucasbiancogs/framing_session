import 'package:whiteboard/domain/entities/waypoint.dart';

class WaypointDto {
  const WaypointDto({required this.index, required this.x, required this.y});

  final int index;
  final double x;
  final double y;

  factory WaypointDto.fromJson(Map<String, dynamic> json) => WaypointDto(
    index: json['index'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  factory WaypointDto.fromEntity(Waypoint entity) =>
      WaypointDto(index: entity.index, x: entity.x, y: entity.y);

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {'index': index, 'x': x, 'y': y};

  Waypoint toEntity() => Waypoint(index: index, x: x, y: y);
}
