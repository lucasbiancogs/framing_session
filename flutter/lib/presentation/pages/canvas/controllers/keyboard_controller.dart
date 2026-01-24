import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';

import '../canvas_vm.dart';
import '../collaborative_canvas_vm.dart';
import '../models/canvas_operation.dart';

/// Handles keyboard events for the whiteboard canvas.
///
/// Supported shortcuts:
/// - Delete/Backspace: Delete selected shape or connector
/// - Escape: Cancel current operation (connecting mode) or deselect
/// - Enter: Start text editing on selected shape
/// - Cmd/Ctrl + C: Copy selected shape to clipboard
/// - Cmd/Ctrl + V: Paste shape from clipboard
/// - Cmd/Ctrl + D: Duplicate selected shape
///
/// Future planned features:
/// - Undo/Redo shortcuts (Cmd/Ctrl + Z/Y)
class KeyboardController {
  KeyboardController({
    required this.vm,
    required this.collaborativeVm,
    required this.onStartTextEdit,
  });

  final CanvasVM vm;
  final CollaborativeCanvasVM collaborativeVm;

  /// Callback to start text editing on the selected shape.
  /// This is needed because text editing setup requires widget-level
  /// access to TextEditingController and FocusNode.
  final void Function(CanvasLoaded state) onStartTextEdit;

  /// Offset applied when pasting/duplicating shapes.
  static const double _pasteOffset = 20.0;

  /// Handle a keyboard event.
  ///
  /// Returns [KeyEventResult.handled] if the event was processed,
  /// [KeyEventResult.ignored] otherwise.
  KeyEventResult handleKeyEvent(KeyEvent event, CanvasLoaded state) {
    // Only handle key down events
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Don't handle keyboard shortcuts while editing text
    // (let the text field handle them instead)
    if (state.isEditingText) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final isModifierPressed = _isCommandOrControlPressed();

    // Cmd/Ctrl + C - Copy selected shape
    if (isModifierPressed && key == LogicalKeyboardKey.keyC) {
      return _handleCopy(state);
    }

    // Cmd/Ctrl + V - Paste shape from clipboard
    if (isModifierPressed && key == LogicalKeyboardKey.keyV) {
      return _handlePaste(state);
    }

    // Cmd/Ctrl + D - Duplicate selected shape
    if (isModifierPressed && key == LogicalKeyboardKey.keyD) {
      return _handleDuplicate(state);
    }

    // Delete/Backspace - delete selected shape or connector
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      return _handleDelete(state);
    }

    // Escape - cancel connecting mode or deselect
    if (key == LogicalKeyboardKey.escape) {
      return _handleEscape(state);
    }

    // Enter - start text editing on selected shape
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return _handleEnter(state);
    }

    return KeyEventResult.ignored;
  }

  /// Check if Command (Mac) or Control (Windows/Linux) is pressed.
  bool _isCommandOrControlPressed() {
    return HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
  }

  // ---------------------------------------------------------------------------
  // Copy/Paste/Duplicate
  // ---------------------------------------------------------------------------

  /// Handle Cmd/Ctrl + C - Copy selected shape to clipboard as JSON.
  KeyEventResult _handleCopy(CanvasLoaded state) {
    final selectedShape = state.selectedShape;

    if (selectedShape == null) return KeyEventResult.ignored;

    // Serialize shape to clipboard JSON (without id and sessionId)
    final clipboardData = {
      'shape_type': selectedShape.entity.shapeType.name,
      'x': selectedShape.entity.x,
      'y': selectedShape.entity.y,
      'width': selectedShape.entity.width,
      'height': selectedShape.entity.height,
      'color': selectedShape.entity.color,
      if (selectedShape.entity.text != null) 'text': selectedShape.entity.text,
    };

    final jsonString = jsonEncode(clipboardData);
    Clipboard.setData(ClipboardData(text: jsonString));

    return KeyEventResult.handled;
  }

  /// Handle Cmd/Ctrl + V - Paste shape from clipboard.
  ///
  /// This is async but we return immediately and schedule the paste.
  KeyEventResult _handlePaste(CanvasLoaded state) {
    // Schedule async paste operation
    _performPaste(state);
    return KeyEventResult.handled;
  }

  /// Perform the actual paste operation (async).
  Future<void> _performPaste(CanvasLoaded state) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text == null) return;

      final json = jsonDecode(clipboardData!.text!) as Map<String, dynamic>;

      // Validate required fields
      if (!json.containsKey('shape_type') ||
          !json.containsKey('x') ||
          !json.containsKey('y') ||
          !json.containsKey('width') ||
          !json.containsKey('height') ||
          !json.containsKey('color')) {
        return;
      }

      final operation = PasteShapeCanvasOperation(
        opId: const Uuid().v4(),
        shapeId: const Uuid().v4(),
        shapeType: ShapeType.values.byName(json['shape_type'] as String),
        x: (json['x'] as num).toDouble() + _pasteOffset,
        y: (json['y'] as num).toDouble() + _pasteOffset,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        color: json['color'] as String,
        text: json['text'] as String?,
      );

      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);

      // Select the newly pasted shape
      vm.selectShape(operation.shapeId);
    } catch (_) {
      // Invalid clipboard data - ignore silently
    }
  }

  /// Handle Cmd/Ctrl + D - Duplicate selected shape.
  KeyEventResult _handleDuplicate(CanvasLoaded state) {
    final selectedShape = state.selectedShape;
    if (selectedShape == null) return KeyEventResult.ignored;

    final operation = PasteShapeCanvasOperation(
      opId: const Uuid().v4(),
      shapeId: const Uuid().v4(),
      shapeType: selectedShape.entity.shapeType,
      x: selectedShape.entity.x + _pasteOffset,
      y: selectedShape.entity.y + _pasteOffset,
      width: selectedShape.entity.width,
      height: selectedShape.entity.height,
      color: selectedShape.entity.color,
      text: selectedShape.entity.text,
    );

    vm.applyOperation(operation, persist: true);
    collaborativeVm.broadcastOperation(operation);

    // Select the duplicated shape
    vm.selectShape(operation.shapeId);

    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Delete/Escape/Enter
  // ---------------------------------------------------------------------------

  /// Handle Delete/Backspace key - delete selected connector or shape.
  KeyEventResult _handleDelete(CanvasLoaded state) {
    // Priority: delete connector if selected, otherwise delete shape
    if (state.selectedConnectorId != null) {
      final operation = DeleteConnectorCanvasOperation(
        opId: const Uuid().v4(),
        connectorId: state.selectedConnectorId!,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
      return KeyEventResult.handled;
    }

    if (state.selectedShapeId != null) {
      final operation = DeleteShapeCanvasOperation(
        opId: const Uuid().v4(),
        shapeId: state.selectedShapeId!,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handle Escape key - cancel connecting mode or deselect.
  KeyEventResult _handleEscape(CanvasLoaded state) {
    // Priority: cancel connecting mode first
    if (state.isConnecting) {
      vm.cancelConnecting();
      return KeyEventResult.handled;
    }

    // Otherwise, deselect current selection
    if (state.selectedConnectorId != null) {
      vm.selectConnector(null);
      return KeyEventResult.handled;
    }

    if (state.selectedShapeId != null) {
      vm.selectShape(null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handle Enter key - start text editing on selected shape.
  KeyEventResult _handleEnter(CanvasLoaded state) {
    // Only start text editing if a shape is selected
    if (state.selectedShapeId == null) return KeyEventResult.ignored;

    // Trigger text editing via callback (widget handles the setup)
    onStartTextEdit(state);
    return KeyEventResult.handled;
  }
}
