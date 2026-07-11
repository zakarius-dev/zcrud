// AC7 : `ZAcl` — port d'autorisation neutre synchrone ; `ZAllowAllAcl` permissive ;
// preuve du filtrage d'action via une ACL restrictive fournie par l'« app ».
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité fictive pour cibler `can(..., target:)`.
class _FakeEntity implements ZEntity {
  const _FakeEntity(this.id);
  @override
  final String? id;
  @override
  bool get isEphemeral => id == null;
}

/// ACL app-supplied restrictive : refuse `delete`, autorise le reste
/// (preuve du filtrage d'action ligne, E4-4).
class _DenyDeleteAcl implements ZAcl {
  const _DenyDeleteAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action != ZCrudAction.delete;
}

/// ACL app-supplied refusant UNIQUEMENT `publish` (preuve du filtrage sélectif
/// d'une action étendue, DP-14).
class _DenyPublishAcl implements ZAcl {
  const _DenyPublishAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action != ZCrudAction.publish;
}

void main() {
  group('ZAllowAllAcl — permissive zéro-config (AC7)', () {
    test('autorise TOUTES les ZCrudAction', () {
      const acl = ZAllowAllAcl();
      for (final action in ZCrudAction.values) {
        expect(acl.can(action), isTrue, reason: '$action doit être autorisée');
      }
    });

    test('const (instanciable en compile-time)', () {
      const a = ZAllowAllAcl();
      const b = ZAllowAllAcl();
      expect(identical(a, b), isTrue);
    });
  });

  group('ZAcl — décision synchrone app-supplied (AC7)', () {
    test('ACL restrictive refuse delete, accepte le reste', () {
      const acl = _DenyDeleteAcl();
      expect(acl.can(ZCrudAction.delete), isFalse);
      expect(acl.can(ZCrudAction.view), isTrue);
      expect(acl.can(ZCrudAction.create), isTrue);
      expect(acl.can(ZCrudAction.update), isTrue);
      expect(acl.can(ZCrudAction.restore), isTrue);
    });

    test('can accepte target/collectionId optionnels', () {
      const acl = ZAllowAllAcl();
      expect(
          acl.can(ZCrudAction.update,
              target: const _FakeEntity('42'), collectionId: 'folders'),
          isTrue);
    });

    test('ACL restrictive refuse UNIQUEMENT publish (DP-14, action étendue)', () {
      const acl = _DenyPublishAcl();
      expect(acl.can(ZCrudAction.publish), isFalse);
      // Les autres actions étendues + historiques restent autorisées.
      expect(acl.can(ZCrudAction.copy), isTrue);
      expect(acl.can(ZCrudAction.archive), isTrue);
      expect(acl.can(ZCrudAction.clear), isTrue);
      expect(acl.can(ZCrudAction.validate), isTrue);
      expect(acl.can(ZCrudAction.history), isTrue);
      expect(acl.can(ZCrudAction.view), isTrue);
    });
  });

  group('ZCrudAction — extension additive DODLP (DP-14, gap M7)', () {
    test('11 valeurs : 5 historiques + 6 étendues, ordre additif', () {
      expect(ZCrudAction.values, hasLength(11));
      // Les 5 historiques restent en tête, dans l'ordre (rétro-compat).
      expect(ZCrudAction.values.take(5), <ZCrudAction>[
        ZCrudAction.view,
        ZCrudAction.create,
        ZCrudAction.update,
        ZCrudAction.delete,
        ZCrudAction.restore,
      ]);
      // Les 6 étendues (copy/archive/publish/clear/validate/history) SUIVENT.
      expect(ZCrudAction.values.skip(5), <ZCrudAction>[
        ZCrudAction.copy,
        ZCrudAction.archive,
        ZCrudAction.publish,
        ZCrudAction.clear,
        ZCrudAction.validate,
        ZCrudAction.history,
      ]);
    });

    test('ZAllowAllAcl autorise les 11 valeurs (dont les 6 étendues)', () {
      const acl = ZAllowAllAcl();
      for (final action in <ZCrudAction>[
        ZCrudAction.copy,
        ZCrudAction.archive,
        ZCrudAction.publish,
        ZCrudAction.clear,
        ZCrudAction.validate,
        ZCrudAction.history,
      ]) {
        expect(acl.can(action), isTrue, reason: '$action doit être autorisée');
      }
    });

    test('valeurs en camelCase (canonique §5)', () {
      expect(ZCrudAction.copy.name, 'copy');
      expect(ZCrudAction.archive.name, 'archive');
      expect(ZCrudAction.publish.name, 'publish');
      expect(ZCrudAction.clear.name, 'clear');
      expect(ZCrudAction.validate.name, 'validate');
      expect(ZCrudAction.history.name, 'history');
    });
  });
}
