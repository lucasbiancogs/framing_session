import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';

sealed class ConnectorNode extends Equatable {
  const ConnectorNode({required this.position});

  final Offset position;

  @override
  List<Object?> get props => [position];
}

class AnchorNode extends ConnectorNode {
  const AnchorNode({required this.anchor, required super.position});

  final AnchorPoint anchor;

  @override
  List<Object?> get props => [anchor, ...super.props];
}

class WaypointNode extends ConnectorNode {
  const WaypointNode({required super.position});
}
