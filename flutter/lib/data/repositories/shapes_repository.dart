import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whiteboard/data/dtos/connector_dto.dart';
import 'package:whiteboard/data/dtos/shape_dto.dart';
import 'package:whiteboard/domain/entities/connector.dart';
import 'package:whiteboard/domain/entities/shape.dart';

/// Shape repository for managing whiteboard shapes and connectors with Supabase.
///
/// - Defines [ShapesRepository] interface and [ShapesRepositoryImpl] implementation.
/// - Uses [ShapeDto] and [ConnectorDto] for data mapping.
/// - Supports fetching, creating, updating, and deleting shapes and connectors.
///
/// Usage:
/// ```dart
/// final repo = ShapesRepositoryImpl(Supabase.instance.client);
/// final shapes = await repo.getSessionShapes('session_id');
/// final connectors = await repo.getSessionConnectors('session_id');
/// ```
abstract class ShapesRepository {
  // -------------------------------------------------------------------------
  // Shape methods
  // -------------------------------------------------------------------------

  /// Fetches all shapes for a session.
  Future<List<Shape>> getSessionShapes(String sessionId);

  /// Creates a new shape.
  Future<Shape> createShape(Shape shape);

  /// Updates an existing shape.
  Future<Shape> updateShape(Shape shape);

  /// Deletes a shape.
  Future<void> deleteShape(String id);

  // -------------------------------------------------------------------------
  // Connector methods
  // -------------------------------------------------------------------------

  /// Fetches all connectors for a session.
  Future<List<Connector>> getSessionConnectors(String sessionId);

  /// Creates a new connector.
  Future<Connector> createConnector(Connector connector);

  /// Updates an existing connector.
  Future<Connector> updateConnector(Connector connector);

  /// Deletes a connector.
  Future<void> deleteConnector(String id);
}

class _ShapeKeys {
  static const String repo = 'shapes';
  static const String id = 'id';
  static const String sessionId = 'session_id';
  static const String createdAt = 'created_at';
}

class _ConnectorKeys {
  static const String repo = 'connectors';
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
          (data) => ShapeDto.fromJson(data as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Shape> createShape(Shape shape) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .insert(ShapeDto.fromEntity(shape).toJson())
        .select()
        .single();

    return ShapeDto.fromJson(response).toEntity();
  }

  @override
  Future<Shape> updateShape(Shape shape) async {
    final response = await _client
        .from(_ShapeKeys.repo)
        .update(ShapeDto.fromEntity(shape).toJson())
        .eq(_ShapeKeys.id, shape.id)
        .select()
        .single();

    return ShapeDto.fromJson(response).toEntity();
  }

  @override
  Future<void> deleteShape(String id) async {
    await _client.from(_ShapeKeys.repo).delete().eq(_ShapeKeys.id, id);
  }

  // -------------------------------------------------------------------------
  // Connector methods
  // -------------------------------------------------------------------------

  @override
  Future<List<Connector>> getSessionConnectors(String sessionId) async {
    final response = await _client
        .from(_ConnectorKeys.repo)
        .select()
        .eq(_ConnectorKeys.sessionId, sessionId)
        .order(_ConnectorKeys.createdAt, ascending: true);

    return (response as List)
        .map(
          (data) =>
              ConnectorDto.fromJson(data as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Connector> createConnector(Connector connector) async {
    final response = await _client
        .from(_ConnectorKeys.repo)
        .insert(ConnectorDto.fromEntity(connector).toJson())
        .select()
        .single();

    return ConnectorDto.fromJson(response).toEntity();
  }

  @override
  Future<Connector> updateConnector(Connector connector) async {
    final response = await _client
        .from(_ConnectorKeys.repo)
        .update(ConnectorDto.fromEntity(connector).toJson())
        .eq(_ConnectorKeys.id, connector.id)
        .select()
        .single();

    return ConnectorDto.fromJson(response).toEntity();
  }

  @override
  Future<void> deleteConnector(String id) async {
    await _client.from(_ConnectorKeys.repo).delete().eq(_ConnectorKeys.id, id);
  }
}
