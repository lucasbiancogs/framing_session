import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas_vm.dart';
import 'whiteboard_canvas.dart';

/// The main canvas page for a whiteboard session.
///
/// Architecture:
/// - All shapes are drawn in a single CustomPainter (WhiteboardPainter)
/// - No shape is a Flutter widget
/// - Gestures are handled centrally in WhiteboardCanvas
/// - ViewModel is the single source of truth
class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasVM(sessionId));

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        title: Text('Session: $sessionId'),
        actions: [
          // Delete button (only when shape is selected)
          if (state is CanvasLoaded && state.selectedShapeId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(canvasVM(sessionId).notifier).deleteSelectedShape(),
              tooltip: 'Delete selected shape',
            ),
        ],
      ),
      body: switch (state) {
        CanvasLoading() => const Center(child: CircularProgressIndicator()),
        CanvasLoaded() => WhiteboardCanvas(sessionId: sessionId),
        CanvasError(:final exception) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                exception.message,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(canvasVM(sessionId).notifier).retryLoading(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: state is CanvasLoaded
          ? _ToolBar(sessionId: sessionId, currentTool: state.currentTool)
          : null,
    );
  }
}

/// Toolbar for selecting drawing tools.
class _ToolBar extends ConsumerWidget {
  const _ToolBar({required this.sessionId, required this.currentTool});

  final String sessionId;
  final CanvasTool currentTool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolButton(
              icon: Icons.near_me,
              label: 'Select',
              isSelected: currentTool == CanvasTool.select,
              onTap: () => ref
                  .read(canvasVM(sessionId).notifier)
                  .setTool(CanvasTool.select),
            ),
            _ToolButton(
              icon: Icons.crop_square,
              label: 'Rectangle',
              isSelected: currentTool == CanvasTool.rectangle,
              onTap: () => ref
                  .read(canvasVM(sessionId).notifier)
                  .setTool(CanvasTool.rectangle),
            ),
            _ToolButton(
              icon: Icons.circle_outlined,
              label: 'Circle',
              isSelected: currentTool == CanvasTool.circle,
              onTap: () => ref
                  .read(canvasVM(sessionId).notifier)
                  .setTool(CanvasTool.circle),
            ),
            _ToolButton(
              icon: Icons.change_history,
              label: 'Triangle',
              isSelected: currentTool == CanvasTool.triangle,
              onTap: () => ref
                  .read(canvasVM(sessionId).notifier)
                  .setTool(CanvasTool.triangle),
            ),
            _ToolButton(
              icon: Icons.text_fields,
              label: 'Text',
              isSelected: currentTool == CanvasTool.text,
              onTap: () => ref
                  .read(canvasVM(sessionId).notifier)
                  .setTool(CanvasTool.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
