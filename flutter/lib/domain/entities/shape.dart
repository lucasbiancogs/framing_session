import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'shape_type.dart';

/// Represents a shape on the whiteboard canvas.
///
/// This is a domain entity — immutable and contains only business data.
/// Matches the PostgreSQL table: shapes
@immutable
class Shape extends Equatable {
  const Shape({
    required this.id,
    required this.sessionId,
    required this.shapeType,
    required this.height,
    required this.width,
    required this.x,
    required this.y,
    required this.color,
    required this.rotation,
    this.text,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final ShapeType shapeType;
  final double height;
  final double width;
  final double x;
  final double y;
  final String color;
  final double rotation;
  final String? text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    sessionId,
    shapeType,
    height,
    width,
    x,
    y,
    color,
    rotation,
    text,
    createdAt,
    updatedAt,
  ];
}
