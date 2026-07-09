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

    test('ZCrudAction couvre view/create/update/delete/restore', () {
      expect(ZCrudAction.values, hasLength(5));
    });
  });
}
