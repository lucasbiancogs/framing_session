import 'dart:ui';

import 'package:flutter/painting.dart'
    show TextDirection, TextPainter, TextSpan, TextStyle;

import '../../../../domain/entities/shape.dart' as domain;
import '../../../../domain/entities/shape_type.dart';
import '../models/edit_intent.dart';
import '../models/edit_operation.dart';

/// Abstract base class for canvas shapes.
///
/// This is a **presentation-layer** abstraction that wraps a domain [Shape]
/// and provides canvas-specific behavior:
/// - Hit testing
/// - Edit intent detection
/// - Operation application
/// - Painting
///
/// The domain entity stays pure (just data), while this class handles
/// all the rendering and interaction logic.
///
/// Architecture principle: Shapes own geometry & editing rules.
abstract class CanvasShape {
  /// The underlying domain entity.
  domain.Shape get entity;

  /// Unique identifier (delegates to entity).
  String get id => entity.id;

  /// The bounding rectangle of this shape.
  Rect get bounds;

  /// The center point of this shape.
  Offset get center => bounds.center;

  /// Check if a point hits the shape body.
  bool hitTest(Offset point);

  double get handleSize => 40;

  /// Determine what kind of edit the user intends based on touch position.
  ///
  /// Returns null if the point doesn't hit any interactive area.
  EditIntent? getEditIntent(Offset point);

  /// Apply an operation to this shape, returning a new shape.
  ///
  /// Operations are applied immutably — the original shape is unchanged.
  CanvasShape apply(EditOperation operation);

  /// Paint this shape onto the canvas.
  void paint(Canvas canvas, {bool isSelected = false});

  /// Paint selection handles around this shape.
  void paintHandles(Canvas canvas);

  // ---------------------------------------------------------------------------
  // Shared Implementation Helpers
  // ---------------------------------------------------------------------------

  /// Get the rect for a specific resize handle.
  Rect getHandleRect(ResizeHandle handle) {
    final handleCenter = getHandleCenter(handle);
    return switch (handle) {
      ResizeHandle.topLeft ||
      ResizeHandle.topRight ||
      ResizeHandle.bottomLeft ||
      ResizeHandle.bottomRight => Rect.fromCenter(
        center: handleCenter,
        width: handleSize,
        height: handleSize,
      ),

      ResizeHandle.topCenter || ResizeHandle.bottomCenter => Rect.fromCenter(
        center: handleCenter,
        width: handleSize * 4,
        height: handleSize,
      ),
      ResizeHandle.centerLeft || ResizeHandle.centerRight => Rect.fromCenter(
        center: handleCenter,
        width: handleSize,
        height: handleSize * 4,
      ),
    };
  }

  /// Get the center position of a resize handle.
  Offset getHandleCenter(ResizeHandle handle) {
    final b = bounds;
    return switch (handle) {
      ResizeHandle.topLeft => b.topLeft,
      ResizeHandle.topCenter => Offset(b.center.dx, b.top),
      ResizeHandle.topRight => b.topRight,
      ResizeHandle.centerLeft => Offset(b.left, b.center.dy),
      ResizeHandle.centerRight => Offset(b.right, b.center.dy),
      ResizeHandle.bottomLeft => b.bottomLeft,
      ResizeHandle.bottomCenter => Offset(b.center.dx, b.bottom),
      ResizeHandle.bottomRight => b.bottomRight,
    };
  }

  /// Check if a point hits a resize handle.
  bool hitTestHandle(Offset point, ResizeHandle handle) {
    print('@debug hitTestHandle: $point, $handle');
    print(
      '@debug bounds: left:${bounds.left}, top:${bounds.top}, right:${bounds.right}, bottom:${bounds.bottom}',
    );
    switch (handle) {
      case ResizeHandle.topRight ||
          ResizeHandle.topLeft ||
          ResizeHandle.bottomRight ||
          ResizeHandle.bottomLeft:
        final handleRect = getHandleRect(handle);
        return handleRect.contains(point);
      case ResizeHandle.topCenter:
        return point.dy <= bounds.top + handleSize / 2 &&
            point.dy >= bounds.top - handleSize / 2 &&
            point.dx < bounds.right - handleSize / 2 &&
            point.dx > bounds.left + handleSize / 2;
      case ResizeHandle.bottomCenter:
        return point.dy >= bounds.bottom - handleSize / 2 &&
            point.dy <= bounds.bottom + handleSize / 2 &&
            point.dx < bounds.right - handleSize / 2 &&
            point.dx > bounds.left + handleSize / 2;
      case ResizeHandle.centerLeft:
        return point.dx >= bounds.left - handleSize / 2 &&
            point.dx <= bounds.left + handleSize / 2 &&
            point.dy > bounds.top + handleSize / 2 &&
            point.dy < bounds.bottom - handleSize / 2;
      case ResizeHandle.centerRight:
        return point.dx >= bounds.right + handleSize / 2 &&
            point.dx <= bounds.right - handleSize / 2 &&
            point.dy > bounds.top + handleSize / 2 &&
            point.dy < bounds.bottom - handleSize / 2;
    }
  }

  /// Default handle painting implementation.
  void paintDefaultHandles(Canvas canvas) {
    final handlePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (final handle in ResizeHandle.values) {
      final rect = getHandleRect(handle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(handleSize / 2)),
        handlePaint,
      );
    }
  }

  /// Default edit intent implementation (handles + body).
  EditIntent? getDefaultEditIntent(Offset point) {
    // Check resize handles corners first (they have priority)
    for (final handle in ResizeHandle.values) {
      if (hitTestHandle(point, handle)) {
        return ResizeIntent(handle);
      }
    }

    // Check if hitting the body = move intent
    if (hitTest(point)) {
      return const MoveIntent();
    }

    return null;
  }

  /// Apply move operation.
  domain.Shape applyMove(Offset delta) {
    return entity.copyWith(x: entity.x + delta.dx, y: entity.y + delta.dy);
  }

  /// Apply resize operation.
  domain.Shape applyResize(ResizeHandle handle, Offset delta) {
    var newX = entity.x;
    var newY = entity.y;
    var newWidth = entity.width;
    var newHeight = entity.height;

    switch (handle) {
      case ResizeHandle.topLeft:
        newX += delta.dx;
        newY += delta.dy;
        newWidth -= delta.dx;
        newHeight -= delta.dy;
      case ResizeHandle.topCenter:
        newY += delta.dy;
        newHeight -= delta.dy;
      case ResizeHandle.topRight:
        newY += delta.dy;
        newWidth += delta.dx;
        newHeight -= delta.dy;
      case ResizeHandle.centerLeft:
        newX += delta.dx;
        newWidth -= delta.dx;
      case ResizeHandle.centerRight:
        newWidth += delta.dx;
      case ResizeHandle.bottomLeft:
        newX += delta.dx;
        newWidth -= delta.dx;
        newHeight += delta.dy;
      case ResizeHandle.bottomCenter:
        newHeight += delta.dy;
      case ResizeHandle.bottomRight:
        newWidth += delta.dx;
        newHeight += delta.dy;
    }

    // Enforce minimum size
    const minSize = 20.0;
    if (newWidth < minSize) {
      newWidth = minSize;
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.centerLeft ||
          handle == ResizeHandle.bottomLeft) {
        newX = entity.x + entity.width - minSize;
      }
    }
    if (newHeight < minSize) {
      newHeight = minSize;
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topCenter ||
          handle == ResizeHandle.topRight) {
        newY = entity.y + entity.height - minSize;
      }
    }

    return entity.copyWith(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Apply rotate operation.
  domain.Shape applyRotate(double angleDelta) {
    return entity.copyWith(rotation: entity.rotation + angleDelta);
  }

  /// Parse a hex color string to a Color.
  Color parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF808080);
    }
  }
}

// =============================================================================
// Factory
// =============================================================================

/// Create the appropriate CanvasShape from a domain Shape.
CanvasShape createCanvasShape(domain.Shape shape) {
  return switch (shape.shapeType) {
    ShapeType.rectangle => RectangleCanvasShape(shape),
    ShapeType.circle => CircleCanvasShape(shape),
    ShapeType.triangle => TriangleCanvasShape(shape),
    ShapeType.text => TextCanvasShape(shape),
  };
}

// =============================================================================
// Concrete Implementations
// =============================================================================

/// Rectangle shape implementation.
class RectangleCanvasShape extends CanvasShape {
  RectangleCanvasShape(this.entity);

  @override
  final domain.Shape entity;

  @override
  Rect get bounds =>
      Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height);

  @override
  bool hitTest(Offset point) => bounds.contains(point);

  @override
  EditIntent? getEditIntent(Offset point) {
    return getDefaultEditIntent(point);
  }

  @override
  CanvasShape apply(EditOperation operation) {
    final newEntity = switch (operation) {
      MoveOperation(:final delta) => applyMove(delta),
      ResizeOperation(:final handle, :final delta) => applyResize(
        handle,
        delta,
      ),
      RotateOperation(:final angleDelta) => applyRotate(angleDelta),
      _ => entity,
    };
    return RectangleCanvasShape(newEntity);
  }

  @override
  void paint(Canvas canvas, {bool isSelected = false}) {
    final paint = Paint()
      ..color = parseColor(entity.color)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(4));

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawRRect(rrect, paint);

    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rrect, borderPaint);
    }

    if (entity.rotation != 0) {
      canvas.restore();
    }
  }

  @override
  void paintHandles(Canvas canvas) {
    paintDefaultHandles(canvas);
  }
}

/// Circle/ellipse shape implementation.
class CircleCanvasShape extends CanvasShape {
  CircleCanvasShape(this.entity);

  @override
  final domain.Shape entity;

  @override
  Rect get bounds =>
      Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height);

  @override
  bool hitTest(Offset point) {
    // Ellipse hit test
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final rx = bounds.width / 2;
    final ry = bounds.height / 2;

    final dx = point.dx - cx;
    final dy = point.dy - cy;

    return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1;
  }

  @override
  EditIntent? getEditIntent(Offset point) {
    return getDefaultEditIntent(point);
  }

  @override
  CanvasShape apply(EditOperation operation) {
    final newEntity = switch (operation) {
      MoveOperation(:final delta) => applyMove(delta),
      ResizeOperation(:final handle, :final delta) => applyResize(
        handle,
        delta,
      ),
      RotateOperation(:final angleDelta) => applyRotate(angleDelta),
      _ => entity,
    };
    return CircleCanvasShape(newEntity);
  }

  @override
  void paint(Canvas canvas, {bool isSelected = false}) {
    final paint = Paint()
      ..color = parseColor(entity.color)
      ..style = PaintingStyle.fill;

    canvas.drawOval(bounds, paint);

    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(bounds, borderPaint);
    }
  }

  @override
  void paintHandles(Canvas canvas) {
    paintDefaultHandles(canvas);
  }
}

/// Triangle shape implementation.
class TriangleCanvasShape extends CanvasShape {
  TriangleCanvasShape(this.entity);

  @override
  final domain.Shape entity;

  @override
  Rect get bounds =>
      Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height);

  Path get _trianglePath {
    final path = Path();
    path.moveTo(entity.x + entity.width / 2, entity.y); // Top center
    path.lineTo(
      entity.x + entity.width,
      entity.y + entity.height,
    ); // Bottom right
    path.lineTo(entity.x, entity.y + entity.height); // Bottom left
    path.close();
    return path;
  }

  @override
  bool hitTest(Offset point) {
    return _trianglePath.contains(point);
  }

  @override
  EditIntent? getEditIntent(Offset point) {
    return getDefaultEditIntent(point);
  }

  @override
  CanvasShape apply(EditOperation operation) {
    final newEntity = switch (operation) {
      MoveOperation(:final delta) => applyMove(delta),
      ResizeOperation(:final handle, :final delta) => applyResize(
        handle,
        delta,
      ),
      RotateOperation(:final angleDelta) => applyRotate(angleDelta),
      _ => entity,
    };
    return TriangleCanvasShape(newEntity);
  }

  @override
  void paint(Canvas canvas, {bool isSelected = false}) {
    final paint = Paint()
      ..color = parseColor(entity.color)
      ..style = PaintingStyle.fill;

    final path = _trianglePath;

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawPath(path, paint);

    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);
    }

    if (entity.rotation != 0) {
      canvas.restore();
    }
  }

  @override
  void paintHandles(Canvas canvas) {
    paintDefaultHandles(canvas);
  }
}

/// Text shape implementation.
class TextCanvasShape extends CanvasShape {
  TextCanvasShape(this.entity);

  @override
  final domain.Shape entity;

  @override
  Rect get bounds =>
      Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height);

  @override
  bool hitTest(Offset point) => bounds.contains(point);

  @override
  EditIntent? getEditIntent(Offset point) {
    return getDefaultEditIntent(point);
  }

  @override
  CanvasShape apply(EditOperation operation) {
    final newEntity = switch (operation) {
      MoveOperation(:final delta) => applyMove(delta),
      ResizeOperation(:final handle, :final delta) => applyResize(
        handle,
        delta,
      ),
      RotateOperation(:final angleDelta) => applyRotate(angleDelta),
      _ => entity,
    };
    return TextCanvasShape(newEntity);
  }

  @override
  void paint(Canvas canvas, {bool isSelected = false}) {
    final color = parseColor(entity.color);

    // Background
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(4));

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawRRect(rrect, bgPaint);

    // Text
    final textSpan = TextSpan(
      text: entity.text ?? 'Text',
      style: TextStyle(color: color, fontSize: 14),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: entity.width - 16);
    textPainter.paint(
      canvas,
      Offset(
        entity.x + (entity.width - textPainter.width) / 2,
        entity.y + (entity.height - textPainter.height) / 2,
      ),
    );

    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rrect, borderPaint);
    }

    if (entity.rotation != 0) {
      canvas.restore();
    }
  }

  @override
  void paintHandles(Canvas canvas) {
    paintDefaultHandles(canvas);
  }
}
