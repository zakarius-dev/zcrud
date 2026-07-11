// DP-5 (AC3/AC4) — tests DOMAINE PURS (`package:test`, aucun Flutter) du port
// neutre `ZRelationSource`/`ZRelationSourceRegistry` (registre instanciable AD-4,
// lookup strict/défensif AD-10) et de la config `ZRelationConfig` (const,
// égalité profonde `filterKeys`).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Source de test PURE (aucun backend) : émet une liste fixe.
class _StubSource extends ZRelationSource {
  const _StubSource(this.data);

  final List<ZFieldChoice> data;

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) =>
      Stream<List<ZFieldChoice>>.value(data);
}

void main() {
  group('ZRelationSourceRegistry (AC3, AD-4/AD-10)', () {
    test('register / isRegistered / keys', () {
      final registry = ZRelationSourceRegistry();
      expect(registry.isRegistered('provinces'), isFalse);
      const source = _StubSource(<ZFieldChoice>[]);
      registry.register('provinces', source);
      expect(registry.isRegistered('provinces'), isTrue);
      expect(registry.keys, contains('provinces'));
    });

    test('collision → ZDuplicateRegistrationError (jamais last-wins)', () {
      final registry = ZRelationSourceRegistry()
        ..register('k', const _StubSource(<ZFieldChoice>[]));
      expect(
        () => registry.register('k', const _StubSource(<ZFieldChoice>[])),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('sourceFor strict : absent → ZUnregisteredTypeError', () {
      final registry = ZRelationSourceRegistry();
      expect(() => registry.sourceFor('nope'),
          throwsA(isA<ZUnregisteredTypeError>()));
    });

    test('sourceFor strict : présent → la source enregistrée', () {
      const source = _StubSource(<ZFieldChoice>[]);
      final registry = ZRelationSourceRegistry()..register('k', source);
      expect(registry.sourceFor('k'), same(source));
    });

    test('trySourceFor défensif : absent → null ; présent → la source', () {
      const source = _StubSource(<ZFieldChoice>[]);
      final registry = ZRelationSourceRegistry()..register('k', source);
      expect(registry.trySourceFor('absent'), isNull);
      expect(registry.trySourceFor('k'), same(source));
    });

    test('instanciable / non-singleton : deux instances indépendantes (AD-4)',
        () {
      final a = ZRelationSourceRegistry()
        ..register('k', const _StubSource(<ZFieldChoice>[]));
      final b = ZRelationSourceRegistry();
      expect(a.isRegistered('k'), isTrue);
      expect(b.isRegistered('k'), isFalse,
          reason: 'aucun état statique partagé entre instances');
    });

    test('le port émet un Stream<List<ZFieldChoice>> NU (AD-5)', () async {
      const source = _StubSource(<ZFieldChoice>[
        ZFieldChoice(value: '1', label: 'Un'),
      ]);
      final emitted = await source.options(const <String, Object?>{}).first;
      expect(emitted, hasLength(1));
      expect(emitted.first.value, '1');
    });
  });

  group('ZRelationConfig (AC4)', () {
    test('const + valeurs par défaut', () {
      const cfg = ZRelationConfig();
      expect(cfg.sourceKey, isNull);
      expect(cfg.filterKeys, isEmpty);
      expect(cfg.searchable, isFalse);
      expect(cfg, isA<ZFieldConfig>());
    });

    test('égalité de valeur (dont filterKeys profond) + hashCode', () {
      const a = ZRelationConfig(
          sourceKey: 's', filterKeys: <String>['p', 'q'], searchable: true);
      const b = ZRelationConfig(
          sourceKey: 's', filterKeys: <String>['p', 'q'], searchable: true);
      const different = ZRelationConfig(
          sourceKey: 's', filterKeys: <String>['p'], searchable: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(different)));
    });

    test('sourceKey/searchable discriminants', () {
      const base = ZRelationConfig(sourceKey: 's');
      expect(base, isNot(equals(const ZRelationConfig(sourceKey: 't'))));
      expect(
        const ZRelationConfig(sourceKey: 's', searchable: true),
        isNot(equals(base)),
      );
    });
  });
}
