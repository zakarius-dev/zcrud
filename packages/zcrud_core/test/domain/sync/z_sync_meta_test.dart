// CR-IFFD-14 — collision entre un champ MÉTIER et une clé de sync RÉSERVÉE.
//
// `updated_at` est réécrit inconditionnellement par la couche de sync (AD-19).
// Or un hôte peut porter un `updatedAt` MÉTIER — « dernière modification par
// l'utilisateur » — qui n'est PAS l'estampille LWW : il était écrasé sans erreur
// ni avertissement. La CR ne remet PAS en cause le contrat de clé réservée
// (délibéré) ; elle demande que la collision cesse d'être MUETTE.
//
// Traité comme une CLASSE et non comme le cas `updated_at` : `is_deleted` est
// exposé au même risque, et chaque hôte peut en avoir d'autres.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';


// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-14 — une collision de clé réservée ne doit plus être MUETTE.
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('CR-IFFD-14 — collision de clé réservée détectable', () {
    test('🔴 un corps portant `updated_at` est SIGNALÉ', () {
      // Le nom `updatedAt` est l'un des plus répandus des modèles applicatifs :
      // un hôte peut porter un « dernière modification par l'utilisateur », qui
      // n'est PAS l'estampille LWW. Il était écrasé sans un mot.
      final collided = ZSyncMeta.collidingReservedKeys(<String, dynamic>{
        'title': 'x',
        ZSyncMeta.kUpdatedAt: '2024-01-01T00:00:00.000Z',
      });
      expect(collided, <String>{ZSyncMeta.kUpdatedAt});
    });

    test('`is_deleted` est couvert aussi (la CLASSE, pas le cas)', () {
      final collided = ZSyncMeta.collidingReservedKeys(<String, dynamic>{
        ZSyncMeta.kIsDeleted: true,
        ZSyncMeta.kUpdatedAt: 'x',
      });
      expect(collided, ZSyncMeta.reservedKeys);
    });

    test('un corps SAIN ne signale rien (aucun faux positif)', () {
      final collided = ZSyncMeta.collidingReservedKeys(<String, dynamic>{
        'title': 'x',
        'content_updated_at': 'y', // le renommage recommandé
      });
      expect(collided, isEmpty);
    });

    test('le strip reste inchangé — seule la DÉTECTION est ajoutée', () {
      final out = ZSyncMeta.stripReserved(<String, dynamic>{
        'title': 'x',
        ZSyncMeta.kUpdatedAt: 'y',
        ZSyncMeta.kIsDeleted: true,
      });
      expect(out, <String, dynamic>{'title': 'x'});
    });
  });
}
