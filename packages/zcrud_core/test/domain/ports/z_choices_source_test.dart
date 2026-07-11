// DP-15 (AC8) — tests DOMAINE PURS (`package:test`, aucun Flutter) du port neutre
// `ZChoicesSource`/`ZChoicesSourceRegistry` (registre instanciable AD-4, lookup
// strict/défensif AD-10). Port SYNCHRONE (contrairement à `ZRelationSource`).
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Source de test PURE (aucun backend) : calcule depuis le `filterContext`.
class _StubChoices extends ZChoicesSource {
  const _StubChoices();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) {
    final parent = filterContext['parent'];
    if (parent == null) return const <ZFieldChoice>[];
    return <ZFieldChoice>[
      ZFieldChoice(value: '$parent-1', label: 'Enfant 1 de $parent'),
      ZFieldChoice(value: '$parent-2', label: 'Enfant 2 de $parent'),
    ];
  }
}

void main() {
  group('ZChoicesSourceRegistry (AC8, AD-4/AD-10)', () {
    test('register / isRegistered / keys', () {
      final registry = ZChoicesSourceRegistry();
      expect(registry.isRegistered('cities'), isFalse);
      const source = _StubChoices();
      registry.register('cities', source);
      expect(registry.isRegistered('cities'), isTrue);
      expect(registry.keys, contains('cities'));
    });

    test('collision → ZDuplicateRegistrationError (jamais last-wins)', () {
      final registry = ZChoicesSourceRegistry()
        ..register('k', const _StubChoices());
      expect(
        () => registry.register('k', const _StubChoices()),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('sourceFor strict : absent → ZUnregisteredTypeError', () {
      final registry = ZChoicesSourceRegistry();
      expect(() => registry.sourceFor('nope'),
          throwsA(isA<ZUnregisteredTypeError>()));
    });

    test('sourceFor strict : présent → la source enregistrée', () {
      const source = _StubChoices();
      final registry = ZChoicesSourceRegistry()..register('k', source);
      expect(registry.sourceFor('k'), same(source));
    });

    test('trySourceFor défensif : absent → null ; présent → la source', () {
      const source = _StubChoices();
      final registry = ZChoicesSourceRegistry()..register('k', source);
      expect(registry.trySourceFor('absent'), isNull);
      expect(registry.trySourceFor('k'), same(source));
    });

    test('instanciable / non-singleton : deux instances indépendantes (AD-4)',
        () {
      final a = ZChoicesSourceRegistry()..register('k', const _StubChoices());
      final b = ZChoicesSourceRegistry();
      expect(a.isRegistered('k'), isTrue);
      expect(b.isRegistered('k'), isFalse,
          reason: 'aucun état statique partagé entre instances');
    });

    test('le port retourne une List<ZFieldChoice> NUE SYNCHRONE (AD-5)', () {
      const source = _StubChoices();
      final empty = source.options(const <String, Object?>{});
      expect(empty, isEmpty);
      final computed = source.options(const <String, Object?>{'parent': 'p'});
      expect(computed, hasLength(2));
      expect(computed.first.value, 'p-1');
    });
  });
}
