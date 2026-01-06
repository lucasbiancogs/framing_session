import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/session_services.dart';
import '../../domain/services/shape_services.dart';

// =============================================================================
// Global Providers
// =============================================================================
// These providers are overridden at app startup in ProviderScope.
// The pattern allows swapping mock → real implementations easily.

/// Shape services provider.
/// Override this with MockShapeServices (Phase 4) or real implementation (Phase 5+).
final shapeServices = Provider<ShapeServices>(
  (_) => throw UnimplementedError('shapeServices must be overridden'),
  name: 'shapeServices',
);

/// Session services provider.
/// Override this with MockSessionServices (Phase 4) or real implementation (Phase 5+).
final sessionServices = Provider<SessionServices>(
  (_) => throw UnimplementedError('sessionServices must be overridden'),
  name: 'sessionServices',
);
