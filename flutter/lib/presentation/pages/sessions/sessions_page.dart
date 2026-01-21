import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:whiteboard/presentation/router/routes.dart' as routes;

import '../../../domain/entities/session.dart';
import 'sessions_vm.dart';

/// Sessions list page — entry point for the app.
///
/// Displays all whiteboard sessions and allows:
/// - Viewing existing sessions
/// - Creating new sessions
/// - Navigating to canvas
class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionsVM);

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Whiteboards').large().semiBold(),
          trailing: [
            if (state is SessionsLoaded)
              PrimaryButton(
                onPressed: state.isCreating
                    ? null
                    : () => _showCreateSessionDialog(context, ref),
                leading: state.isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                child: Text(
                  state.isCreating ? 'Creating...' : 'New Whiteboard',
                ),
              ),
          ],
        ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200),
          child: switch (state) {
            SessionsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            SessionsLoaded(:final sessions, :final isCreating) => _SessionsList(
              sessions: sessions,
              isCreating: isCreating,
            ),
            SessionsError(:final exception) => _ErrorView(
              message: exception.message,
              onRetry: () => ref.read(sessionsVM.notifier).retryLoading(),
            ),
          },
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Whiteboard'),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
            autofocus: true,
            placeholder: const Text('Whiteboard name'),
            onSubmitted: (value) =>
                _createSession(context, ref, controller.text),
          ),
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            onPressed: () => _createSession(context, ref, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSession(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    if (name.trim().isEmpty) return;

    Navigator.pop(context);

    final sessionId = await ref.read(sessionsVM.notifier).createSession(name);

    if (sessionId != null && context.mounted) {
      routes.navigateToCanvas(context, sessionId, name);
    }
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.sessions, required this.isCreating});

  final List<Session> sessions;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(key: ValueKey(session.id), session: session);
      },
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Clickable(
          onPressed: () =>
              routes.navigateToCanvas(context, session.id, session.name),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.scaleAlpha(0.15),
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Icon(
                    Icons.dashboard_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(session.name).semiBold()],
                  ),
                ),
                // Delete button
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: () => _confirmDelete(context, ref),
                  child: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 8),
                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Whiteboard'),
        content: Text('Are you sure you want to delete "${session.name}"?'),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(sessionsVM.notifier).deleteSession(session.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 80,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 16),
            const Text('No whiteboards yet').xLarge().semiBold(),
            const SizedBox(height: 8),
            const Text(
              'Create your first whiteboard to get started',
              textAlign: TextAlign.center,
            ).muted(),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.destructive,
            ),
            const SizedBox(height: 16),
            const Text('Something went wrong').xLarge().semiBold(),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center).muted(),
            const SizedBox(height: 24),
            PrimaryButton(
              onPressed: onRetry,
              leading: const Icon(Icons.refresh),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
