import 'package:whiteboard/domain/entities/arrow_type.dart';

class ArrowTypeDto {
  const ArrowTypeDto({required this.value});

  final ArrowType value;

  factory ArrowTypeDto.fromString(String value) =>
      ArrowTypeDto(value: ArrowType.values.byName(value));

  String get raw => value.name;

  ArrowType toEntity() => value;
}
