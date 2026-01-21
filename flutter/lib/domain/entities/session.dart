import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a whiteboard session.
///
/// This is a domain entity — immutable and contains only business data.
/// Matches the PostgreSQL table: sessions
@immutable
class Session extends Equatable {
  const Session({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];

  Session copyWith({String? id, String? name}) {
    return Session(id: id ?? this.id, name: name ?? this.name);
  }
}
