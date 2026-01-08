import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Represents a user on the whiteboard canvas.
///
/// This is a domain entity — immutable and contains only business data.
/// Matches the PostgreSQL table: users
@immutable
class User extends Equatable {
  const User({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final String color;

  @override
  List<Object?> get props => [id, name, color];
}
