// Tests E5-4 : `ZSyncRunReport` — value object neutre du rapport de cycle.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('empty : attempted=succeeded=failed=0, sans failures', () {
    const r = ZSyncRunReport.empty();
    expect(r.attempted, 0);
    expect(r.succeeded, 0);
    expect(r.failed, 0);
    expect(r.failures, isEmpty);
  });

  test('invariant attempted == succeeded + failed (assertion debug)', () {
    expect(
      () => ZSyncRunReport(attempted: 3, succeeded: 1, failed: 1),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => const ZSyncRunReport(attempted: 2, succeeded: 1, failed: 1),
      returnsNormally,
    );
  });

  test('égalité de valeur (== / hashCode) incluant failures', () {
    const f = ZServerFailure('x');
    final a = ZSyncRunReport(
        attempted: 1, succeeded: 0, failed: 1, failures: const [f]);
    final b = ZSyncRunReport(
        attempted: 1, succeeded: 0, failed: 1, failures: const [f]);
    final c = ZSyncRunReport(
        attempted: 1,
        succeeded: 0,
        failed: 1,
        failures: const [ZServerFailure('y')]);

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('toString lisible', () {
    const r = ZSyncRunReport(attempted: 2, succeeded: 1, failed: 1);
    expect(r.toString(), contains('attempted: 2'));
    expect(r.toString(), contains('succeeded: 1'));
    expect(r.toString(), contains('failed: 1'));
  });
}
