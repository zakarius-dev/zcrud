/// `zSectionKey` — constructeur canonique UNIQUE de clé de section (SU-1, AC3 —
/// AD-38).
///
/// **Ce test protège des DONNÉES RÉELLES, pas une convention de style.**
/// `sectionOrders` est un canal **persisté** dont les clés sont déjà en base
/// sous forme **nue** (`'flashcards'` — cf. `z_folder_contents_order_test.dart`).
/// `applyOrder` étant **TOTAL**, une clé fautive est **ignorée sans erreur ni
/// test rouge** : l'ordre persisté deviendrait orphelin **en silence**. Le
/// groupe « RÉTRO-COMPAT » ci-dessous est le verrou qui rend ce bug impossible.
///
/// Injection R3-I3 : préfixer la clé (`'section:$contentType'`) ⇒ le cas
/// rétro-compat ROUGIT.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('AC3 — RÉTRO-COMPAT du persisté (verrou anti-orphelins, AD-38)', () {
    test(
      'DISCRIMINANT R3-I3 — sans sous-dossier, la clé est le contentType VERBATIM',
      () {
        // La forme EXACTE déjà en base chez les consommateurs. Tout préfixe ou
        // suffixe orphelinerait silencieusement l'ordre persisté.
        expect(zSectionKey(contentType: 'flashcards'), 'flashcards');
        expect(zSectionKey(contentType: 'docs'), 'docs');
        expect(zSectionKey(contentType: 'podcasts'), 'podcasts');
      },
    );

    test('aucun préfixe, aucun suffixe, aucun séparateur parasite', () {
      final key = zSectionKey(contentType: 'flashcards');
      expect(key.startsWith('section'), isFalse,
          reason: 'un préfixe orphelinerait le persisté');
      expect(key.endsWith('/'), isFalse,
          reason: 'un séparateur en fin orphelinerait le persisté');
      expect(key.contains('/'), isFalse);
      expect(key.length, 'flashcards'.length,
          reason: 'la clé nue doit être STRICTEMENT le contentType');
    });

    test(
      'PREUVE DE BOUT EN BOUT — la clé canonique retrouve un ordre DÉJÀ persisté '
      'via ZFolderContentsOrder + applyOrder',
      () {
        // Simule un ordre écrit AVANT SU-1, avec la clé nue historique.
        final persisted = ZFolderContentsOrder.fromMap(<String, dynamic>{
          'folder_id': 'f',
          'section_orders': <String, dynamic>{
            'flashcards': <String>['c2', 'c1'],
          },
        });

        // Lecture via le constructeur canonique : DOIT taper dans le persisté.
        final order = persisted.orderFor(zSectionKey(contentType: 'flashcards'));
        expect(order, <String>['c2', 'c1'],
            reason: 'la clé canonique doit retrouver l\'ordre déjà en base — '
                'sinon `orderFor` rend une liste vide EN SILENCE');

        // Et l'ordre est réellement appliqué (applyOrder est TOTAL : avec une
        // clé fautive il rendrait l'ordre d'entrée, sans lever).
        final reordered = applyOrder<String>(
          <String>['c1', 'c2'],
          order,
          idOf: (item) => item,
        );
        expect(reordered, <String>['c2', 'c1'],
            reason: 'une clé orpheline ⇒ ordre d\'entrée conservé ⇒ classement '
                'utilisateur « oublié » sans aucun signal (Prevents AD-38)');
      },
    );
  });

  group('AC3 — forme canonique avec sous-dossier', () {
    test('subfolderId non vide ⇒ « contentType/subfolderId »', () {
      expect(zSectionKey(contentType: 'flashcards', subfolderId: 'sub1'),
          'flashcards/sub1');
      expect(zSectionKey(contentType: 'docs', subfolderId: 'a-b-c'), 'docs/a-b-c');
    });

    test('la clé avec sous-dossier est DISTINCTE de la clé nue', () {
      expect(
        zSectionKey(contentType: 'flashcards', subfolderId: 'sub1'),
        isNot(zSectionKey(contentType: 'flashcards')),
      );
    });
  });

  group('AC3 — dégénérescence explicite du sous-dossier vide', () {
    test('subfolderId: \'\' ⇒ clé NUE (jamais « flashcards/ »)', () {
      // Une simple interpolation produirait 'flashcards/' — clé fantôme,
      // distincte du persisté, donc orpheline.
      expect(zSectionKey(contentType: 'flashcards', subfolderId: ''),
          'flashcards');
      expect(zSectionKey(contentType: 'flashcards', subfolderId: ''),
          isNot('flashcards/'));
    });

    test('subfolderId: null et subfolderId: \'\' produisent la MÊME clé', () {
      expect(
        zSectionKey(contentType: 'flashcards', subfolderId: null),
        zSectionKey(contentType: 'flashcards', subfolderId: ''),
      );
    });
  });

  group('AC3 — fonction PURE et déterministe (kernel pur)', () {
    test('deux appels identiques produisent la même clé (stabilité)', () {
      expect(
        zSectionKey(contentType: 'flashcards', subfolderId: 'sub1'),
        zSectionKey(contentType: 'flashcards', subfolderId: 'sub1'),
      );
      expect(zSectionKey(contentType: 'docs'), zSectionKey(contentType: 'docs'));
    });

    test('contentType est OPAQUE — aucun vocabulaire n\'est imposé (AD-4)', () {
      // Les apps (IFFD/lex) apportent leurs propres types : le kernel compose,
      // il ne valide pas. Un enum fermé casserait ces consommateurs.
      expect(zSectionKey(contentType: 'type-inconnu-de-zcrud'),
          'type-inconnu-de-zcrud');
      expect(zSectionKey(contentType: 'customApp.widget'), 'customApp.widget');
    });
  });
}
