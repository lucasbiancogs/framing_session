import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a whiteboard session.
///
/// This is a domain entity — immutable and contains only business data.
/// Matches the PostgreSQL table: sessions
@immutable
class Session extends Equatable {
  const Session({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, name, createdAt, updatedAt];

  Session copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
