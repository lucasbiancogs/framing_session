import 'package:dartz/dartz.dart';

import '../../core/errors/base_faults.dart';
import '../../core/errors/shape_exception.dart';
import '../../data/repositories/shapes_repository.dart';
import '../entities/connector.dart';
import '../entities/shape.dart';

/// Service interface for shape and connector business logic.
///
/// This abstraction allows swapping implementations:
/// - MockShapeServices — local mock data (for testing)
/// - ShapeServicesImpl — backed by Supabase
abstract class ShapeServices {
  // -------------------------------------------------------------------------
  // Shape methods
  // -------------------------------------------------------------------------

  /// Get all shapes for a session.
  Future<Either<BaseException, List<Shape>>> getSessionShapes(String sessionId);

  /// Create a new shape.
  Future<Either<BaseException, Shape>> createShape(Shape shape);

  /// Update an existing shape.
  Future<Either<BaseException, Shape>> updateShape(Shape shape);

  /// Delete a shape by ID.
  Future<Either<BaseException, void>> deleteShape(String id);

  // -------------------------------------------------------------------------
  // Connector methods
  // -------------------------------------------------------------------------

  /// Get all connectors for a session.
  Future<Either<BaseException, List<Connector>>> getSessionConnectors(
    String sessionId,
  );

  /// Create a new connector.
  Future<Either<BaseException, Connector>> createConnector(Connector connector);

  /// Update an existing connector.
  Future<Either<BaseException, Connector>> updateConnector(Connector connector);

  /// Delete a connector by ID.
  Future<Either<BaseException, void>> deleteConnector(String id);
}

class ShapeServicesImpl implements ShapeServices {
  ShapeServicesImpl(this._repository);

  final ShapesRepository _repository;

  @override
  Future<Either<BaseException, List<Shape>>> getSessionShapes(
    String sessionId,
  ) async {
    try {
      final shapes = await _repository.getSessionShapes(sessionId);
      return right(shapes);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Shape>> createShape(Shape shape) async {
    try {
      final createdShape = await _repository.createShape(shape);
      return right(createdShape);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Shape>> updateShape(Shape shape) async {
    try {
      final updatedShape = await _repository.updateShape(shape);
      return right(updatedShape);
    } catch (e) {
      if (e.toString().contains('No rows found')) {
        return left(ShapeException.notFound(shape.id));
      }
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, void>> deleteShape(String id) async {
    try {
      await _repository.deleteShape(id);
      return right(null);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  // -------------------------------------------------------------------------
  // Connector methods
  // -------------------------------------------------------------------------

  @override
  Future<Either<BaseException, List<Connector>>> getSessionConnectors(
    String sessionId,
  ) async {
    try {
      final connectors = await _repository.getSessionConnectors(sessionId);
      return right(connectors);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Connector>> createConnector(
    Connector connector,
  ) async {
    try {
      final createdConnector = await _repository.createConnector(connector);
      return right(createdConnector);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Connector>> updateConnector(
    Connector connector,
  ) async {
    try {
      final updatedConnector = await _repository.updateConnector(connector);
      return right(updatedConnector);
    } catch (e) {
      if (e.toString().contains('No rows found')) {
        return left(ShapeException.notFound(connector.id));
      }
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, void>> deleteConnector(String id) async {
    try {
      await _repository.deleteConnector(id);
      return right(null);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }
}
