import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whiteboard/core/either_extension.dart';
import 'package:whiteboard/core/errors/base_faults.dart';
import 'package:whiteboard/domain/entities/user.dart';
import 'package:whiteboard/domain/services/session_services.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';
import 'package:whiteboard/presentation/view_models/global_providers.dart';

final presenceVM = StateNotifierProvider.autoDispose<PresenceVM, PresenceState>(
  (ref) => PresenceVM(ref.watch(sessionServices), ref.watch(sessionIdProvider)),
  name: 'presenceVM',
  dependencies: [sessionServices, sessionIdProvider],
);

class PresenceVM extends StateNotifier<PresenceState> {
  PresenceVM(this._sessionServices, this._sessionId)
    : super(const PresenceLoading()) {
    _init();
  }

  final SessionServices _sessionServices;
  final String _sessionId;
  StreamSubscription<List<User>>? _subscription;

  Future<void> _init() async {
    final result = await _sessionServices.joinSession(_sessionId);

    if (result.isLeft()) {
      state = PresenceError(result.forceLeft());
      return;
    }

    final stream = result.forceRight();

    _subscription = stream.listen((users) {
      if (!mounted) return;

      state = PresenceLoaded(onlineUsers: users);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

@immutable
abstract class PresenceState extends Equatable {
  const PresenceState();

  @override
  List<Object?> get props => [];
}

class PresenceLoading extends PresenceState {
  const PresenceLoading();
}

class PresenceLoaded extends PresenceState {
  const PresenceLoaded({required this.onlineUsers});
  final List<User> onlineUsers;

  @override
  List<Object?> get props => [onlineUsers];
}

class PresenceError extends PresenceState {
  const PresenceError(this.exception);

  final BaseException exception;

  @override
  List<Object?> get props => [exception];
}
