import 'package:dartz/dartz.dart';

import '../../core/errors/base_faults.dart';
import '../../core/errors/shape_exception.dart';
import '../../data/dtos/shape_dto.dart';
import '../../data/repositories/shapes_repository.dart';
import '../entities/shape.dart';

/// Service interface for shape business logic.
///
/// This abstraction allows swapping implementations:
/// - MockShapeServices — local mock data (for testing)
/// - ShapeServicesImpl — backed by Supabase
abstract class ShapeServices {
  /// Get all shapes for a session.
  Future<Either<BaseException, List<Shape>>> getSessionShapes(String sessionId);

  /// Get a single shape by ID.
  Future<Either<BaseException, Shape>> getShapeById(String id);

  /// Create a new shape.
  Future<Either<BaseException, Shape>> createShape(Shape shape);

  /// Update an existing shape.
  Future<Either<BaseException, Shape>> updateShape(Shape shape);

  /// Delete a shape by ID.
  Future<Either<BaseException, void>> deleteShape(String id);
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
  Future<Either<BaseException, Shape>> getShapeById(String id) async {
    try {
      final shape = await _repository.getShape(id);
      return right(shape);
    } catch (e) {
      if (e.toString().contains('No rows found')) {
        return left(ShapeException.notFound(id));
      }
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Shape>> createShape(Shape shape) async {
    try {
      final dto = ShapeDto.fromEntity(shape);
      final createdShape = await _repository.createShape(dto);
      return right(createdShape);
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Shape>> updateShape(Shape shape) async {
    try {
      final dto = ShapeDto.fromEntity(shape);
      final updatedShape = await _repository.updateShape(dto);
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
}
