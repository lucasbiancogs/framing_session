import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whiteboard/data/dtos/shape_dto.dart';
import 'package:whiteboard/domain/entities/shape.dart';

/// Shape repository for managing whiteboard shapes with Supabase.
///
/// - Defines [ShapesRepository] interface and [ShapesRepositoryImpl] implementation.
/// - Uses [ShapeDto] for data mapping and [Shape] as domain entity.
/// - Supports fetching, creating, updating, and deleting shapes.
///
/// Usage:
/// ```dart
/// final repo = ShapesRepositoryImpl(Supabase.instance.client);
/// final shapes = await repo.getSessionShapes('session_id');
/// ```
abstract class ShapesRepository {
  /// Fetches all shapes for a session.
  Future<List<Shape>> getSessionShapes(String sessionId);

  /// Fetches a shape by its ID.
  Future<Shape> getShape(String id);

  /// Creates a new shape.
  Future<Shape> createShape(ShapeDto shape);

  /// Updates an existing shape.
  Future<Shape> updateShape(ShapeDto shape);

  /// Deletes a shape.
  Future<void> deleteShape(String id);
}

class _ShapeKeys {
  static const String repo = 'shapes';
  static const String id = 'id';
  static const String sessionId = 'session_id';
  static const String createdAt = 'created_at';
}

class ShapesRepositoryImpl implements ShapesRepository {
  ShapesRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Shape>> getSessionShapes(String sessionId) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .select()
        .eq(_ShapeKeys.sessionId, sessionId)
        .order(_ShapeKeys.createdAt, ascending: true);

    return (response as List)
        .map(
          (data) => ShapeDto.fromMap(data as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Shape> getShape(String id) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .select()
        .eq(_ShapeKeys.id, id)
        .single();

    return ShapeDto.fromMap(response).toEntity();
  }

  @override
  Future<Shape> createShape(ShapeDto shape) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .insert(shape.toMap())
        .select()
        .single();

    return ShapeDto.fromMap(response).toEntity();
  }

  @override
  Future<Shape> updateShape(ShapeDto shape) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .update(shape.toMap())
        .eq(_ShapeKeys.id, shape.id)
        .select()
        .single();

    return ShapeDto.fromMap(response).toEntity();
  }

  @override
  Future<void> deleteShape(String id) async {
    await _client.from(_ShapeKeys.repo).delete().eq(_ShapeKeys.id, id);
  }
}
