// AC8 : ce test importe UNIQUEMENT le barrel `zcrud_core` — jamais
// `package:dartz` directement. Il prouve que le re-export curaté
// (Either / Left / Right / Unit / unit) suffit à consommer `ZResult<T>`.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZResult / Either via barrel seul (AC8)', () {
    test('Right transporte un succès', () {
      const ZResult<int> r = Right(1);
      expect(r.isRight(), isTrue);
      final value = r.fold((l) => -1, (rr) => rr);
      expect(value, 1);
    });

    test('Left transporte une ZFailure', () {
      const ZResult<int> r = Left(DomainFailure('boom'));
      expect(r.isLeft(), isTrue);
      final msg = r.fold((l) => l.message, (rr) => 'ok');
      expect(msg, 'boom');
    });

    test('Either<ZFailure, Unit> avec unit (void ergonomique)', () {
      const Either<ZFailure, Unit> u = Right(unit);
      expect(u.isRight(), isTrue);
      expect(u.fold((l) => null, (r) => r), isA<Unit>());
    });

    test('fold couvre les deux branches', () {
      const ZResult<String> ok = Right('yes');
      const ZResult<String> ko = Left(ServerFailure('down'));
      expect(ok.fold((l) => 'L', (r) => 'R:$r'), 'R:yes');
      expect(ko.fold((l) => 'L:${l.message}', (r) => 'R'), 'L:down');
    });
  });
}
