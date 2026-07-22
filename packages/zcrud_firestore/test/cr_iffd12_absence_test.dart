// CR-IFFD-12 — préserver une distinction que le domaine cible NE PORTE PAS.
//
// La CR a été révisée par son émetteur : elle ne demande plus que les entités
// deviennent nullables (ce serait faire régresser un domaine strict à dessein),
// mais que la COUCHE DE MIGRATION sache préserver l'absence — au même titre que
// `preserveLegacyUnder` préserve la granularité de `status`.
//
// Le motif est générique : toute migration d'un schéma legacy permissif vers un
// domaine strict le rencontre. Cinq cutovers ont posé cinq fois le même
// contournement app-side ; c'est le signe que ça appartient au socle.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

void main() {
  const codec = ZStudyLegacyCodec(
    preserveAbsenceUnder: <String>{'folderId', 'title'},
  );

  group('CR-IFFD-12 — l\'absence survit à la conversion', () {
    test('🔴 une clé MANQUANTE est marquée', () {
      final out = codec.toCanonical(<String, dynamic>{'ownerId': 'u1'});
      expect(out[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['folder_id', 'title']);
    });

    test('🔴 une clé présente à `null` est marquée AUSSI', () {
      // Le domaine rendra `''` dans les deux cas : les deux doivent être retenus.
      final out = codec.toCanonical(<String, dynamic>{
        'folderId': null,
        'title': 'Chimie',
      });
      expect(out[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['folder_id']);
    });

    test('un document COMPLET ne porte aucun marqueur (empreinte nulle)', () {
      final out = codec.toCanonical(<String, dynamic>{
        'folderId': 'f1',
        'title': 'Chimie',
      });
      expect(out.containsKey(ZStudyLegacyCodec.kAbsentFieldsKey), isFalse);
    });

    test('sans l\'option déclarée, RIEN ne change (rétro-compatibilité)', () {
      const plain = ZStudyLegacyCodec();
      final out = plain.toCanonical(<String, dynamic>{'ownerId': 'u1'});
      expect(out.containsKey(ZStudyLegacyCodec.kAbsentFieldsKey), isFalse);
    });
  });

  group('CR-IFFD-12 — restitution au retour', () {
    test('🔴 `''` redevient `null` pour un champ marqué absent', () {
      final legacy = codec.toLegacy(<String, dynamic>{
        'folder_id': '', // ce que le domaine strict a produit
        'title': 'Chimie',
        ZStudyLegacyCodec.kAbsentFieldsKey: <String>['folder_id'],
      });
      expect(legacy['folderId'], isNull);
      expect(legacy['title'], 'Chimie');
    });

    test('une valeur RENSEIGNÉE depuis l\'emporte sur un marqueur périmé', () {
      // Discriminant : sans la garde `== ''`, la migration écraserait par `null`
      // une donnée que l'utilisateur a saisie après le premier passage.
      final legacy = codec.toLegacy(<String, dynamic>{
        'folder_id': 'f-saisi-depuis',
        ZStudyLegacyCodec.kAbsentFieldsKey: <String>['folder_id'],
      });
      expect(legacy['folderId'], 'f-saisi-depuis');
    });

    test('un champ NON marqué garde `''` — l\'hôte qui vide volontairement', () {
      final legacy = codec.toLegacy(<String, dynamic>{'title': ''});
      expect(legacy['title'], '');
    });

    test('le marqueur traverse intact (clé de survie)', () {
      final legacy = codec.toLegacy(<String, dynamic>{
        ZStudyLegacyCodec.kAbsentFieldsKey: <String>['title'],
      });
      expect(legacy[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['title']);
    });
  });

  group('CR-IFFD-12 — idempotence (la classe de défaut CR-IFFD-7)', () {
    test('🔴 un 2ᵉ passage n\'EFFACE PAS le marqueur du 1ᵉʳ', () {
      // Au 2ᵉ passage le champ vaut `''` et non plus `null` : un recalcul seul
      // conclurait « présent » et supprimerait le marqueur — perdant l'absence
      // au moment précis où on la relit. C'est le défaut qu'on interdit ici.
      final pass1 = codec.toCanonical(<String, dynamic>{'title': 'Chimie'});
      expect(pass1[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['folder_id']);

      // Ce que le domaine strict a écrit, puis relu :
      final materialized = <String, dynamic>{
        ...pass1,
        'folder_id': '',
      };
      final pass2 = codec.toCanonical(materialized);
      expect(
        pass2[ZStudyLegacyCodec.kAbsentFieldsKey],
        <String>['folder_id'],
        reason: 'le marqueur est CUMULATIF entre passages',
      );
    });

    test('🔴 un champ MATÉRIALISÉ ne fait pas tomber les autres absences', () {
      // LE cas qui discrimine réellement la fusion. Le passthrough de clé de
      // survie suffit tant que le recalcul rend un ensemble VIDE ; dès qu'il
      // rend un ensemble NON vide, il ÉCRASE la clé passée — et les absences
      // du passage précédent, désormais matérialisées en `''`, disparaissent.
      // Sans `prior`, ce test rougit : on obtient ['title'] au lieu des deux.
      final pass1 = codec.toCanonical(<String, dynamic>{'ownerId': 'u'});
      expect(pass1[ZStudyLegacyCodec.kAbsentFieldsKey],
          <String>['folder_id', 'title']);

      // `folder_id` a été matérialisé par le domaine ; `title` reste absent.
      final pass2 = codec.toCanonical(<String, dynamic>{
        ...pass1,
        'folder_id': '',
      });
      expect(
        pass2[ZStudyLegacyCodec.kAbsentFieldsKey],
        <String>['folder_id', 'title'],
        reason: 'l\'absence de `folder_id` ne doit pas être écrasée par le '
            'recalcul déclenché par `title`',
      );
    });

    test('un 3ᵉ passage reste stable (pas de croissance)', () {
      var doc = codec.toCanonical(<String, dynamic>{'title': 't'});
      doc = codec.toCanonical(<String, dynamic>{...doc, 'folder_id': ''});
      doc = codec.toCanonical(<String, dynamic>{...doc});
      expect(doc[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['folder_id']);
    });

    test('un champ absent DÉCOUVERT au 2ᵉ passage s\'ajoute', () {
      final pass1 = codec.toCanonical(<String, dynamic>{'title': 't'});
      final pass2 = codec.toCanonical(<String, dynamic>{
        ...pass1,
        'title': null, // vidé entre-temps côté legacy
      });
      expect(
        pass2[ZStudyLegacyCodec.kAbsentFieldsKey],
        <String>['folder_id', 'title'],
      );
    });
  });

  group('CR-IFFD-12 — composition avec les autres options', () {
    test('un champ RENOMMÉ est marqué sous son nom CANONIQUE', () {
      // Sans consulter `keyAliases`, le marqueur nommerait une clé qui n'existe
      // pas dans le document canonique — donc une restitution qui ne mordrait
      // jamais.
      const c = ZStudyLegacyCodec(
        keyAliases: <String, String>{'quality': 'last_quality'},
        preserveAbsenceUnder: <String>{'quality'},
      );
      final out = c.toCanonical(<String, dynamic>{'question': 'q'});
      expect(out[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['last_quality']);
    });

    test('coexiste avec `preserveLegacyUnder` sans interférence', () {
      const c = ZStudyLegacyCodec(
        preserveLegacyUnder: <String>{'status'},
        preserveAbsenceUnder: <String>{'title'},
      );
      final out = c.toCanonical(<String, dynamic>{'status': 'embedded'});
      expect(out['_legacy_status'], 'embedded');
      expect(out[ZStudyLegacyCodec.kAbsentFieldsKey], <String>['title']);
    });

    test('la clé réservée `is_deleted` reste ajoutée', () {
      final out = codec.toCanonical(<String, dynamic>{'ownerId': 'u'});
      expect(out['is_deleted'], false);
    });
  });
}
