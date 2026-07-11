// DP-15 (AC9) — tests DOMAINE PURS (`package:test`, aucun Flutter) du port neutre
// `ZRelationCrudHandler`/`ZRelationCrudRegistry` (registre instanciable AD-4,
// lookup strict/défensif AD-10). Port ASYNC (create/edit/copy → Future).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Handler de test PUR : create renvoie une option, edit/copy dérivent de value.
class _StubCrud extends ZRelationCrudHandler {
  const _StubCrud();

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async =>
      ZFieldChoice(value: 'new', label: 'Créé (${context['seed']})');

  @override
  Future<ZFieldChoice?> edit(Object? value) async =>
      ZFieldChoice(value: value, label: 'Édité $value');

  @override
  Future<ZFieldChoice?> copy(Object? value) async =>
      ZFieldChoice(value: '$value-copy', label: 'Copie de $value');
}

void main() {
  group('ZRelationCrudRegistry (AC9, AD-4/AD-10)', () {
    test('register / isRegistered / keys', () {
      final registry = ZRelationCrudRegistry();
      expect(registry.isRegistered('prov'), isFalse);
      const handler = _StubCrud();
      registry.register('prov', handler);
      expect(registry.isRegistered('prov'), isTrue);
      expect(registry.keys, contains('prov'));
    });

    test('collision → ZDuplicateRegistrationError (jamais last-wins)', () {
      final registry = ZRelationCrudRegistry()
        ..register('k', const _StubCrud());
      expect(
        () => registry.register('k', const _StubCrud()),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('sourceFor strict : absent → ZUnregisteredTypeError', () {
      final registry = ZRelationCrudRegistry();
      expect(() => registry.sourceFor('nope'),
          throwsA(isA<ZUnregisteredTypeError>()));
    });

    test('sourceFor strict : présent → le handler enregistré', () {
      const handler = _StubCrud();
      final registry = ZRelationCrudRegistry()..register('k', handler);
      expect(registry.sourceFor('k'), same(handler));
    });

    test('trySourceFor défensif : absent → null ; présent → le handler', () {
      const handler = _StubCrud();
      final registry = ZRelationCrudRegistry()..register('k', handler);
      expect(registry.trySourceFor('absent'), isNull);
      expect(registry.trySourceFor('k'), same(handler));
    });

    test('instanciable / non-singleton (AD-4)', () {
      final a = ZRelationCrudRegistry()..register('k', const _StubCrud());
      final b = ZRelationCrudRegistry();
      expect(a.isRegistered('k'), isTrue);
      expect(b.isRegistered('k'), isFalse);
    });

    test('le port retourne des Future<ZFieldChoice?> NUS (AD-5)', () async {
      const handler = _StubCrud();
      final created =
          await handler.create(const <String, Object?>{'seed': 'x'});
      expect(created?.value, 'new');
      final edited = await handler.edit('42');
      expect(edited?.value, '42');
      final copied = await handler.copy('42');
      expect(copied?.value, '42-copy');
    });
  });
}
