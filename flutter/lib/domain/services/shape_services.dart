import 'package:dartz/dartz.dart';

import '../../core/errors/base_exception.dart';
import '../entities/shape.dart';
import '../entities/shape_type.dart';
import '../../core/errors/shape_exception.dart';

/// Service interface for shape business logic.
///
/// This abstraction allows swapping implementations:
/// - MockShapeServices (this phase) — local mock data
/// - ShapeServicesImpl (later phases) — backed by Supabase
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

// =============================================================================
// Mock Implementation (Phase 4 only)
// =============================================================================
// This implementation uses in-memory data for UI development.
// In Phase 5+, this will be replaced with SupabaseShapeServices.

class MockShapeServices implements ShapeServices {
  MockShapeServices() {
    // Seed with example shapes
    _shapes.addAll(_seedShapes);
  }

  final List<Shape> _shapes = [];

  // Example shapes for the mock session
  static final List<Shape> _seedShapes = [
    const Shape(
      id: 'shape-1',
      sessionId: 'session-1',
      shapeType: ShapeType.rectangle,
      x: 100,
      y: 100,
      width: 150,
      height: 100,
      color: '#4ED09A',
      rotation: 0,
    ),
    const Shape(
      id: 'shape-2',
      sessionId: 'session-1',
      shapeType: ShapeType.circle,
      x: 300,
      y: 150,
      width: 100,
      height: 100,
      color: '#FF6B6B',
      rotation: 0,
    ),
    const Shape(
      id: 'shape-3',
      sessionId: 'session-1',
      shapeType: ShapeType.triangle,
      x: 500,
      y: 100,
      width: 120,
      height: 100,
      color: '#FFFFFF',
      rotation: 0,
    ),
  ];

  @override
  Future<Either<BaseException, List<Shape>>> getSessionShapes(
    String sessionId,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final sessionShapes = _shapes
        .where((s) => s.sessionId == sessionId)
        .toList();
    return right(sessionShapes);
  }

  @override
  Future<Either<BaseException, Shape>> getShapeById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final shape = _shapes.firstWhere((s) => s.id == id);
      return right(shape);
    } catch (_) {
      return left(ShapeException.notFound(id));
    }
  }

  @override
  Future<Either<BaseException, Shape>> createShape(Shape shape) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final newShape = shape.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _shapes.add(newShape);
    return right(newShape);
  }

  @override
  Future<Either<BaseException, Shape>> updateShape(Shape shape) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final index = _shapes.indexWhere((s) => s.id == shape.id);
    if (index == -1) {
      return left(ShapeException.notFound(shape.id));
    }

    final updatedShape = shape.copyWith(updatedAt: DateTime.now());
    _shapes[index] = updatedShape;
    return right(updatedShape);
  }

  @override
  Future<Either<BaseException, void>> deleteShape(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final index = _shapes.indexWhere((s) => s.id == id);
    if (index == -1) {
      return left(ShapeException.notFound(id));
    }

    _shapes.removeAt(index);
    return right(null);
  }
}
