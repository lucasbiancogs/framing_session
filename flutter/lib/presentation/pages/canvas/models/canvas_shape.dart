import 'package:flutter/material.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;

import '../../../../domain/entities/shape.dart' as domain;
import '../../../../domain/entities/shape_type.dart';
import 'edit_intent.dart';
import 'canvas_operation.dart';

/// Offset applied to anchor positions from shape bounds.
const double anchorOffset = 15.0;

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

  static CanvasShape createCanvasShape(domain.Shape shape) {
    return switch (shape.shapeType) {
      ShapeType.rectangle => RectangleCanvasShape(shape),
      ShapeType.circle => CircleCanvasShape(shape),
      ShapeType.triangle => TriangleCanvasShape(shape),
      ShapeType.text => TextCanvasShape(shape),
    };
  }

  CanvasShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? text,
    String? color,
  });

  /// Unique identifier (delegates to entity).
  String get id => entity.id;

  /// The bounding rectangle of this shape.
  Rect get bounds;

  /// The center point of this shape.
  Offset get center => bounds.center;

  /// Check if a point hits the shape body.
  bool hitTest(Offset point);

  double get handleSize => 6;

  /// Determine what kind of edit the user intends based on touch position.
  ///
  /// Returns null if the point doesn't hit any interactive area.
  EditIntent? getEditIntent(Offset point);

  /// Apply an operation to this shape, returning a new shape.
  ///
  /// Operations are applied immutably — the original shape is unchanged.
  CanvasShape apply(CanvasOperation operation);

  /// Paint this shape onto the canvas.
  ///
  /// [isEditingText] is true when this shape's text is being edited
  /// via the TextField overlay — in that case, skip rendering text.
  void paint(
    Canvas canvas, {
    bool isSelected = false,
    bool isEditingText = false,
  });

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
    switch (handle) {
      case ResizeHandle.topRight ||
          ResizeHandle.topLeft ||
          ResizeHandle.bottomRight ||
          ResizeHandle.bottomLeft:
        final handleRect = getHandleRect(handle);
        return handleRect.inflate(2).contains(point);
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
        return point.dx <= bounds.right + handleSize / 2 &&
            point.dx >= bounds.right - handleSize / 2 &&
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

  /// Apply move operation with absolute position.
  CanvasShape applyMove(Offset position) {
    return copyWith(x: position.dx, y: position.dy);
  }

  /// Apply resize operation with absolute bounds.
  CanvasShape applyResize(Rect bounds) {
    // Enforce minimum size
    const minSize = 20.0;
    final newWidth = bounds.width < minSize ? minSize : bounds.width;
    final newHeight = bounds.height < minSize ? minSize : bounds.height;

    return copyWith(
      x: bounds.left,
      y: bounds.top,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Apply rotate operation.
  CanvasShape applyRotate(double angleDelta) {
    return copyWith(rotation: entity.rotation + angleDelta);
  }

  /// Parse a hex color string to a Color.
  Color get color => color_helper.getColorFromHex(entity.color);

  Color get textColor =>
      color.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  // ---------------------------------------------------------------------------
  // Anchor Points (for connectors)
  // ---------------------------------------------------------------------------

  /// Get the position of an anchor point on this shape.
  Offset getAnchorPosition(AnchorPoint anchor) {
    return switch (anchor) {
      AnchorPoint.top => Offset(bounds.center.dx, bounds.top - anchorOffset),
      AnchorPoint.right => Offset(
        bounds.right + anchorOffset,
        bounds.center.dy,
      ),
      AnchorPoint.bottom => Offset(
        bounds.center.dx,
        bounds.bottom + anchorOffset,
      ),
      AnchorPoint.left => Offset(bounds.left - anchorOffset, bounds.center.dy),
    };
  }

  /// Get all anchor positions as a map.
  Map<AnchorPoint, Offset> get anchorPositions => {
    AnchorPoint.top: getAnchorPosition(AnchorPoint.top),
    AnchorPoint.right: getAnchorPosition(AnchorPoint.right),
    AnchorPoint.bottom: getAnchorPosition(AnchorPoint.bottom),
    AnchorPoint.left: getAnchorPosition(AnchorPoint.left),
  };

  /// Hit test anchor points, returns the anchor if hit, null otherwise.
  AnchorPoint? hitTestAnchor(Offset point, {double tolerance = 12.0}) {
    for (final entry in anchorPositions.entries) {
      if ((point - entry.value).distance <= tolerance) {
        return entry.key;
      }
    }
    return null;
  }
}

/// Rectangle shape implementation.
class RectangleCanvasShape extends CanvasShape {
  RectangleCanvasShape(this.entity);

  @override
  final domain.Shape entity;

  @override
  RectangleCanvasShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? text,
    String? color,
  }) => RectangleCanvasShape(
    domain.Shape(
      id: entity.id,
      sessionId: entity.sessionId,
      shapeType: entity.shapeType,
      height: height ?? entity.height,
      width: width ?? entity.width,
      x: x ?? entity.x,
      y: y ?? entity.y,
      color: color ?? entity.color,
      rotation: rotation ?? entity.rotation,
      text: text ?? entity.text,
    ),
  );

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
  RectangleCanvasShape apply(CanvasOperation operation) {
    final newShape = switch (operation) {
      MoveShapeOperation(:final position) => applyMove(position),
      ResizeShapeOperation(:final bounds) => applyResize(bounds),
      _ => this,
    };

    return newShape as RectangleCanvasShape;
  }

  @override
  void paint(
    Canvas canvas, {
    bool isSelected = false,
    bool isEditingText = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(4));

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    // Draw text content if not editing
    if (!isEditingText && entity.text != null && entity.text!.isNotEmpty) {
      _paintText(canvas);
    }

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

  void _paintText(Canvas canvas) {
    final textSpan = TextSpan(
      text: entity.text,
      style: TextStyle(color: textColor, fontSize: 14),
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
  CircleCanvasShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? text,
    String? color,
  }) => CircleCanvasShape(
    domain.Shape(
      id: entity.id,
      sessionId: entity.sessionId,
      shapeType: entity.shapeType,
      height: height ?? entity.height,
      width: width ?? entity.width,
      x: x ?? entity.x,
      y: y ?? entity.y,
      color: color ?? entity.color,
      rotation: rotation ?? entity.rotation,
      text: text ?? entity.text,
    ),
  );

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
  CanvasShape apply(CanvasOperation operation) {
    final newShape = switch (operation) {
      MoveShapeOperation(:final position) => applyMove(position),
      ResizeShapeOperation(:final bounds) => applyResize(bounds),
      _ => this,
    };
    return newShape as CircleCanvasShape;
  }

  @override
  void paint(
    Canvas canvas, {
    bool isSelected = false,
    bool isEditingText = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(bounds, paint);
    canvas.drawOval(bounds, borderPaint);

    // Draw text content if not editing
    if (!isEditingText && entity.text != null && entity.text!.isNotEmpty) {
      _paintText(canvas);
    }

    if (isSelected) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(bounds, borderPaint);
    }
  }

  void _paintText(Canvas canvas) {
    final textSpan = TextSpan(
      text: entity.text,
      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
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
  TriangleCanvasShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? text,
    String? color,
  }) => TriangleCanvasShape(
    domain.Shape(
      id: entity.id,
      sessionId: entity.sessionId,
      shapeType: entity.shapeType,
      height: height ?? entity.height,
      width: width ?? entity.width,
      x: x ?? entity.x,
      y: y ?? entity.y,
      color: color ?? entity.color,
      rotation: rotation ?? entity.rotation,
      text: text ?? entity.text,
    ),
  );

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
  CanvasShape apply(CanvasOperation operation) {
    final newShape = switch (operation) {
      MoveShapeOperation(:final position) => applyMove(position),
      ResizeShapeOperation(:final bounds) => applyResize(bounds),
      _ => this,
    };
    return newShape as TriangleCanvasShape;
  }

  @override
  void paint(
    Canvas canvas, {
    bool isSelected = false,
    bool isEditingText = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = _trianglePath;

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Draw text content if not editing
    if (!isEditingText && entity.text != null && entity.text!.isNotEmpty) {
      _paintText(canvas);
    }

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

  void _paintText(Canvas canvas) {
    final textSpan = TextSpan(
      text: entity.text,
      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
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
  TextCanvasShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? text,
    String? color,
  }) => TextCanvasShape(
    domain.Shape(
      id: entity.id,
      sessionId: entity.sessionId,
      shapeType: entity.shapeType,
      height: height ?? entity.height,
      width: width ?? entity.width,
      x: x ?? entity.x,
      y: y ?? entity.y,
      color: color ?? entity.color,
      rotation: rotation ?? entity.rotation,
      text: text ?? entity.text,
    ),
  );

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
  CanvasShape apply(CanvasOperation operation) {
    final newShape = switch (operation) {
      MoveShapeOperation(:final position) => applyMove(position),
      ResizeShapeOperation(:final bounds) => applyResize(bounds),
      _ => this,
    };
    return newShape as TextCanvasShape;
  }

  @override
  void paint(
    Canvas canvas, {
    bool isSelected = false,
    bool isEditingText = false,
  }) {
    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(4));

    if (entity.rotation != 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(entity.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    // Only paint text if not editing (TextField overlay handles it)
    if (!isEditingText) {
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
    }

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
