import 'package:whiteboard/domain/entities/anchor_point.dart';

class AnchorPointDto {
  const AnchorPointDto({required this.value});

  final AnchorPoint value;

  factory AnchorPointDto.fromString(String value) =>
      AnchorPointDto(value: AnchorPoint.values.byName(value));

  String get raw => value.name;

  AnchorPoint toEntity() => value;
}
