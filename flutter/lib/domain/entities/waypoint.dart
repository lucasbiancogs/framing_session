import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents an intermediate point on a connector path.
///
/// Waypoints allow users to customize the path of a connector
/// by adding intermediate points that the path must pass through.
@immutable
class Waypoint extends Equatable {
  const Waypoint({required this.index, required this.x, required this.y});

  final int index;
  final double x;
  final double y;

  @override
  List<Object?> get props => [index, x, y];
}
