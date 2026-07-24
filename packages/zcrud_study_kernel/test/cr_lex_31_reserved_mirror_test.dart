// CR-LEX-31 — `toMap()` émettait le miroir déprécié `updated_at`
// INCONDITIONNELLEMENT, `null` compris. L'avertissement de collision de clé
// réservée de zcrud se déclenchait donc à CHAQUE écriture, sur 100 % des
// entités concernées : zcrud avertissant contre lui-même, sans qu'aucun de ces
// cas ne porte de signal utile.
//
// Le correctif n'est pas de supprimer la clé — un miroir RENSEIGNÉ doit
// survivre au round-trip, et l'avertissement est alors LÉGITIME (une valeur
// métier réelle qui sera écrasée par la méta hors-entité).
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('🔴 CR-LEX-31 — un miroir NUL n\'émet plus la clé réservée', () {
    test('toMap() n\'émet pas `updated_at` quand le miroir est nul', () {
      const dossier = ZStudyFolder(id: 'f1', title: 'Dossier');
      expect(dossier.toMap().containsKey('updated_at'), isFalse,
          reason: 'c\'était le cas des 100 % — un null sans aucun signal');
    });

    test('🔴 aucune collision signalée sur un dossier ordinaire', () {
      // C'est l'effet observable qui comptait pour l'hôte : le log cessait
      // d'être noyé à chaque écriture.
      const dossier = ZStudyFolder(id: 'f1', title: 'Dossier');
      expect(ZSyncMeta.collidingReservedKeys(dossier.toMap()), isEmpty);
    });
  });

  group('Le SIGNAL légitime est conservé', () {
    test('🔴 un miroir RENSEIGNÉ émet la clé — et la collision est signalée',
        () {
      // Ici l'avertissement est utile : une valeur métier réelle VA être
      // écrasée par la méta hors-entité. La supprimer masquerait le problème.
      final dossier = ZStudyFolder(
        id: 'f1',
        title: 'Dossier',
        // ignore: deprecated_member_use_from_same_package
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(dossier.toMap().containsKey('updated_at'), isTrue);
      expect(ZSyncMeta.collidingReservedKeys(dossier.toMap()), contains('updated_at'));
    });

    test('un miroir RENSEIGNÉ survit au round-trip (pas de perte)', () {
      final avant = ZStudyFolder(
        id: 'f1',
        title: 'Dossier',
        // ignore: deprecated_member_use_from_same_package
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final apres = ZStudyFolder.fromMap(avant.toMap());
      // ignore: deprecated_member_use_from_same_package
      expect(apres.updatedAt, DateTime.utc(2026, 1, 1),
          reason: 'omettre la clé non-nulle aurait détruit la valeur');
    });

    test('le round-trip d\'un dossier ordinaire reste fidèle', () {
      const avant = ZStudyFolder(id: 'f1', title: 'Dossier');
      expect(ZStudyFolder.fromMap(avant.toMap()), avant);
    });
  });

  group('AD-19 — `is_deleted` n\'est jamais émis par le corps métier', () {
    test('aucune entité ne réémet le drapeau de soft-delete', () {
      const dossier = ZStudyFolder(id: 'f1', title: 'D');
      expect(dossier.toMap().containsKey('is_deleted'), isFalse);
    });
  });
}
