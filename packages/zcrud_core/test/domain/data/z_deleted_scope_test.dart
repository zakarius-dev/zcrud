// CR-DODLP 2026-08-11 (Lot 2a « listing corbeille ») : extension ADDITIVE de
// `ZDataRequest` — membre `deletedScope` (`ZDeletedScope`).
//
// Contrat gardé : le DÉFAUT est `aliveOnly` (comportement historique inchangé,
// AD-10 additif) ; `copyWith` préserve/écrase ; l'égalité/hash DISCRIMINE le
// scope (deux requêtes ne différant que par le scope ne sont PAS égales — sinon
// un cache/memo keyé par requête servirait la liste vivante à la corbeille).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZDeletedScope — défaut additif (AD-10)', () {
    test('ZDataRequest() par défaut porte aliveOnly (comportement historique)',
        () {
      expect(const ZDataRequest().deletedScope, ZDeletedScope.aliveOnly);
    });

    test('l\'enum expose exactement aliveOnly/includeDeleted/deletedOnly', () {
      expect(ZDeletedScope.values, <ZDeletedScope>[
        ZDeletedScope.aliveOnly,
        ZDeletedScope.includeDeleted,
        ZDeletedScope.deletedOnly,
      ]);
    });
  });

  group('ZDeletedScope — copyWith', () {
    test('omis ⇒ préservé (y compris une valeur non-défaut)', () {
      const req = ZDataRequest(deletedScope: ZDeletedScope.deletedOnly);
      final copy = req.copyWith(limit: 10);
      expect(copy.deletedScope, ZDeletedScope.deletedOnly);
      expect(copy.limit, 10);
    });

    test('fourni ⇒ écrasé', () {
      const req = ZDataRequest();
      final copy = req.copyWith(deletedScope: ZDeletedScope.includeDeleted);
      expect(copy.deletedScope, ZDeletedScope.includeDeleted);
      // L'original est immuable — non muté.
      expect(req.deletedScope, ZDeletedScope.aliveOnly);
    });
  });

  group('ZDeletedScope — égalité de valeur', () {
    test('deux requêtes ne différant que par le scope ne sont PAS égales', () {
      const alive = ZDataRequest(
        filters: <ZFilter>[ZFilter('name', ZFilterOp.eq, 'a')],
      );
      const trash = ZDataRequest(
        filters: <ZFilter>[ZFilter('name', ZFilterOp.eq, 'a')],
        deletedScope: ZDeletedScope.deletedOnly,
      );
      expect(alive, isNot(equals(trash)));
      expect(alive.hashCode, isNot(equals(trash.hashCode)));
    });

    test('même scope explicite == défaut implicite (aliveOnly)', () {
      const explicit = ZDataRequest(deletedScope: ZDeletedScope.aliveOnly);
      const implicit = ZDataRequest();
      expect(explicit, equals(implicit));
      expect(explicit.hashCode, implicit.hashCode);
    });

    test('toString expose le scope (diagnostic)', () {
      expect(
        const ZDataRequest(deletedScope: ZDeletedScope.includeDeleted)
            .toString(),
        contains('includeDeleted'),
      );
    });
  });
}
