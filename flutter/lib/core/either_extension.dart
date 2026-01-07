import 'package:dartz/dartz.dart';
import 'package:whiteboard/core/errors/inconsistency_error.dart';

extension Force<L, R> on Either<L, R> {
  L forceLeft() {
    return fold<L>((e) => e, (_) {
      throw InconsistencyError.internal(
        'Either with Right should never be forced to Left',
      );
    });
  }

  R forceRight() {
    return fold<R>((_) {
      throw InconsistencyError.internal(
        'Either with Left should never be forced to Right',
      );
    }, (r) => r);
  }
}
