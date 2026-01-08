import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whiteboard/domain/entities/user.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;
import 'package:whiteboard/presentation/pages/canvas/presence_vm.dart';

import 'canvas_vm.dart';
import 'whiteboard_canvas.dart';

final sessionIdProvider = Provider<String>((ref) => throw UnimplementedError());
final sessionNameProvider = Provider<String>(
  (ref) => throw UnimplementedError(),
);

/// The main canvas page for a whiteboard session.
///
/// Architecture:
/// - All shapes are drawn in a single CustomPainter (WhiteboardPainter)
/// - No shape is a Flutter widget
/// - Gestures are handled centrally in WhiteboardCanvas
/// - ViewModel is the single source of truth
/// - Persist errors are shown via snackbars (local state is kept)
class CanvasPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasVM);
    final vm = ref.watch(canvasVM.notifier);
    final sessionName = ref.watch(sessionNameProvider);
    final presenceState = ref.watch(presenceVM);

    ref.listen(canvasVM, (previous, next) {
      if (next is CanvasPersistError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.exception.message)));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        title: Text(sessionName),

        actions: [
          if (presenceState is PresenceLoaded)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: _OnlineUsersList(users: presenceState.onlineUsers),
            ),
          // Delete button (only when shape is selected)
          if (state is CanvasLoaded && state.selectedShapeId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: vm.deleteSelectedShape,
              tooltip: 'Delete selected shape',
            ),
        ],
      ),
      body: switch (state) {
        CanvasLoading() => const Center(child: CircularProgressIndicator()),
        CanvasLoaded() => WhiteboardCanvas(),
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
                onPressed: vm.retryLoading,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: state is CanvasLoaded
          ? _ToolBar(currentTool: state.currentTool)
          : null,
    );
  }
}

class _OnlineUsersList extends StatelessWidget {
  const _OnlineUsersList({required this.users});

  final List<User> users;

  static const double _avatarSize = 32;
  static const double _overlap = 16;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    // Calculate width: first avatar full + subsequent overlaps
    final width = _avatarSize + (users.length - 1) * _overlap;

    return SizedBox(
      width: width,
      height: _avatarSize,
      child: Stack(
        children: users.indexed
            .map(
              (userIndex) => Positioned(
                // Reverse order so first user is on top
                left: (users.length - 1 - userIndex.$1) * _overlap,
                child: CircleAvatar(
                  radius: _avatarSize / 2,
                  backgroundColor: color_helper.getColorFromHex(
                    userIndex.$2.color,
                  ),
                  child: Text(
                    userIndex.$2.name.substring(0, 1),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Toolbar for selecting drawing tools.
class _ToolBar extends ConsumerWidget {
  const _ToolBar({required this.currentTool});

  final CanvasTool currentTool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(canvasVM.notifier);

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
              onTap: () => vm.setTool(CanvasTool.select),
            ),
            _ToolButton(
              icon: Icons.crop_square,
              label: 'Rectangle',
              isSelected: currentTool == CanvasTool.rectangle,
              onTap: () => vm.setTool(CanvasTool.rectangle),
            ),
            _ToolButton(
              icon: Icons.circle_outlined,
              label: 'Circle',
              isSelected: currentTool == CanvasTool.circle,
              onTap: () => vm.setTool(CanvasTool.circle),
            ),
            _ToolButton(
              icon: Icons.change_history,
              label: 'Triangle',
              isSelected: currentTool == CanvasTool.triangle,
              onTap: () => vm.setTool(CanvasTool.triangle),
            ),
            _ToolButton(
              icon: Icons.text_fields,
              label: 'Text',
              isSelected: currentTool == CanvasTool.text,
              onTap: () => vm.setTool(CanvasTool.text),
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
