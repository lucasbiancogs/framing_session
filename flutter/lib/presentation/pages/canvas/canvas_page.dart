import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:whiteboard/domain/entities/user.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;
import 'package:whiteboard/presentation/pages/canvas/collaborative_canvas_vm.dart';

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
/// - Persist errors are shown via toasts (local state is kept)
class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasVM);
    final vm = ref.watch(canvasVM.notifier);
    final sessionName = ref.watch(sessionNameProvider);
    final collaborativeCanvasState = ref.watch(collaborativeCanvasVM);
    final theme = Theme.of(context);

    ref.listen(canvasVM, (previous, next) {
      if (next is CanvasPersistError) {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('Error'),
              subtitle: Text(next.exception.message),
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.destructive,
              ),
              trailing: IconButton.ghost(
                icon: const Icon(Icons.close),
                onPressed: () => overlay.close(),
              ),
            ),
          ),
          location: ToastLocation.bottomRight,
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          title: Text(sessionName).semiBold(),
          trailing: [
            if (collaborativeCanvasState is CollaborativeCanvasLoaded)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _OnlineUsersList(
                  users: collaborativeCanvasState.onlineUsers,
                ),
              ),
            // Delete button (only when shape is selected)
            if (state is CanvasLoaded && state.selectedShapeId != null)
              Tooltip(
                tooltip: const TooltipContainer(
                  child: Text('Delete selected shape'),
                ).call,
                child: IconButton.ghost(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: vm.deleteSelectedShape,
                ),
              ),
          ],
        ),
      ],
      child: switch (state) {
        CanvasLoading() => const Center(child: CircularProgressIndicator()),
        CanvasLoaded() => Stack(
          children: [
            WhiteboardCanvas(),
            Align(
              alignment: Alignment.bottomCenter,
              child: _ToolBar(
                currentTool: state.currentTool,
                currentColor: state.currentColor,
              ),
            ),
          ],
        ),
        CanvasError(:final exception) => _CanvasErrorView(
          message: exception.message,
          onRetry: vm.retryLoading,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _CanvasErrorView extends StatelessWidget {
  const _CanvasErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.destructive,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          PrimaryButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OnlineUsersList extends StatelessWidget {
  const _OnlineUsersList({required this.users});

  final List<User> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    return AvatarGroup.toRight(
      children: users
          .map(
            (user) => Avatar(
              size: 32,
              backgroundColor: color_helper.getColorFromHex(user.color),
              initials: user.name[0].toUpperCase(),
            ),
          )
          .toList(),
    );
  }
}

/// Toolbar for selecting drawing tools.
class _ToolBar extends ConsumerWidget {
  const _ToolBar({required this.currentTool, required this.currentColor});

  final CanvasTool currentTool;
  final String currentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(canvasVM.notifier);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(theme.radiusXl),
        child: SafeArea(
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              GhostButton(
                density: ButtonDensity.iconDense,

                size: ButtonSize.small,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: ColorInput(
                    enableEyeDropper: true,
                    value: ColorDerivative.fromColor(
                      color_helper.getColorFromHex(currentColor),
                    ),
                    onChanging: (color) => vm.setColor(
                      color_helper.getHexFromColor(color.toColor()),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  final IconData? icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      tooltip: TooltipContainer(child: Text(label)).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        size: ButtonSize.normal,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
