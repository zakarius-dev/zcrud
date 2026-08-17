// CR DODLP « CRUD inline de relation sans ACL » (2026-08-17) — gardes DOMAINE
// PURES (`package:test`, aucun Flutter) des trois droits du port
// `ZRelationCrudHandler` (`canCreate`/`canEdit`/`canCopy`) et de leur lecture
// **défensive** `ZRelationCrudOffer` (`offersCreate`… — un getter hôte qui lève
// FERME le geste, invariant AD-10 : le repli ne doit jamais ouvrir).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Handler qui **ne déclare rien** : il n'existait pas d'autre forme avant la
/// CR — c'est le contre-témoin de rétro-compatibilité.
class _SilentCrud extends ZRelationCrudHandler {
  const _SilentCrud();

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async => null;

  @override
  Future<ZFieldChoice?> edit(Object? value) async => null;

  @override
  Future<ZFieldChoice?> copy(Object? value) async => null;
}

/// Handler qui déclare ses trois droits explicitement.
class _DeclaringCrud extends _SilentCrud {
  const _DeclaringCrud({
    this.allowCreate = true,
    this.allowEdit = true,
    this.allowCopy = true,
  });

  final bool allowCreate;
  final bool allowEdit;
  final bool allowCopy;

  @override
  bool get canCreate => allowCreate;

  @override
  bool get canEdit => allowEdit;

  @override
  bool get canCopy => allowCopy;
}

/// Handler dont les getters **lèvent** (ACL hôte pas encore chargée, session
/// nulle, bug de calcul) — AD-10.
class _ThrowingCrud extends _SilentCrud {
  const _ThrowingCrud({
    this.onCreate = false,
    this.onEdit = false,
    this.onCopy = false,
  });

  final bool onCreate;
  final bool onEdit;
  final bool onCopy;

  @override
  bool get canCreate => onCreate ? throw StateError('acl') : true;

  @override
  bool get canEdit => onEdit ? throw StateError('acl') : true;

  @override
  bool get canCopy => onCopy ? throw StateError('acl') : true;
}

void main() {
  group('ZRelationCrudHandler — trois droits séparés (CR DODLP 2026-08-17)', () {
    test('handler qui ne déclare rien ⇒ les TROIS gestes (rétro-compat)', () {
      const handler = _SilentCrud();
      expect(handler.canCreate, isTrue);
      expect(handler.canEdit, isTrue);
      expect(handler.canCopy, isTrue);
      expect(handler.offersCreate, isTrue);
      expect(handler.offersEdit, isTrue);
      expect(handler.offersCopy, isTrue);
      expect(handler.offersAnyGesture, isTrue);
    });

    test('créer refusé SEUL ⇒ modifier et copier intacts', () {
      const handler = _DeclaringCrud(allowCreate: false);
      expect(handler.offersCreate, isFalse);
      expect(handler.offersEdit, isTrue);
      expect(handler.offersCopy, isTrue);
      expect(handler.offersAnyGesture, isTrue);
    });

    test('modifier refusé SEUL ⇒ créer et copier intacts', () {
      const handler = _DeclaringCrud(allowEdit: false);
      expect(handler.offersCreate, isTrue);
      expect(handler.offersEdit, isFalse);
      expect(handler.offersCopy, isTrue);
    });

    test('copier refusé SEUL ⇒ créer et modifier intacts', () {
      const handler = _DeclaringCrud(allowCopy: false);
      expect(handler.offersCreate, isTrue);
      expect(handler.offersEdit, isTrue);
      expect(handler.offersCopy, isFalse);
    });

    test('les trois refusés ⇒ offersAnyGesture false', () {
      const handler =
          _DeclaringCrud(allowCreate: false, allowEdit: false, allowCopy: false);
      expect(handler.offersAnyGesture, isFalse);
    });

    test('un seul geste offert ⇒ offersAnyGesture true', () {
      const handler = _DeclaringCrud(allowCreate: false, allowCopy: false);
      expect(handler.offersAnyGesture, isTrue);
    });
  });

  group('ZRelationCrudOffer — repli FERMANT sur getter qui lève (AD-10)', () {
    test('canCreate lève ⇒ offersCreate false (jamais true)', () {
      const handler = _ThrowingCrud(onCreate: true);
      // Le getter brut lève bien : la garde mesure le REPLI, pas un droit
      // déclaré `false`.
      expect(() => handler.canCreate, throwsStateError);
      expect(handler.offersCreate, isFalse);
      // Les gestes voisins ne sont PAS emportés par l'incident.
      expect(handler.offersEdit, isTrue);
      expect(handler.offersCopy, isTrue);
    });

    test('canEdit lève ⇒ offersEdit false, les autres intacts', () {
      const handler = _ThrowingCrud(onEdit: true);
      expect(() => handler.canEdit, throwsStateError);
      expect(handler.offersEdit, isFalse);
      expect(handler.offersCreate, isTrue);
      expect(handler.offersCopy, isTrue);
    });

    test('canCopy lève ⇒ offersCopy false, les autres intacts', () {
      const handler = _ThrowingCrud(onCopy: true);
      expect(() => handler.canCopy, throwsStateError);
      expect(handler.offersCopy, isFalse);
      expect(handler.offersCreate, isTrue);
      expect(handler.offersEdit, isTrue);
    });

    test('les trois lèvent ⇒ aucun geste, et aucune exception propagée', () {
      const handler =
          _ThrowingCrud(onCreate: true, onEdit: true, onCopy: true);
      expect(handler.offersAnyGesture, isFalse);
    });
  });
}
