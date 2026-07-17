// Tests de `zReorderFlashcards` (SU-8/AC9-AC12 — AD-38).
//
// 🔴 LE test de ce fichier est la **rétro-compatibilité bout-en-bout** : il
// IMITE `z_section_key_test.dart:42-72` du kernel (sans le dupliquer — celui-ci
// couvre la clé NUE du kernel, celui-là couvre le chemin RÉEL de su-8 :
// `zFlashcardsSectionKey` → écriture → relecture → `applyOrder` APPLIQUÉ).
//
// Pourquoi il n'est pas décoratif : `applyOrder` est **TOTAL**. Une clé préfixée
// ou renommée n'échoue PAS — elle est ignorée en silence, et l'ordre déjà en base
// devient orphelin. Aucun test de comportement « normal » ne le verrait : la
// liste s'afficherait, simplement dans le mauvais ordre.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('🔴 AC10 — clé de section : VERBATIM « flashcards » (RISQUE DE DONNÉES)', () {
    test('clé nue = « flashcards », sans préfixe ni suffixe', () {
      final key = zFlashcardsSectionKey();
      expect(key, 'flashcards');
      expect(key.endsWith('/'), isFalse,
          reason: 'un séparateur en fin orphelinerait le persisté');
      expect(key.startsWith('section'), isFalse);
      expect(key.contains('/'), isFalse);
      expect(key.length, 'flashcards'.length,
          reason: 'la clé nue est STRICTEMENT le contentType');
    });

    test('sous-dossier VIDE ⇒ clé NUE (jamais « flashcards/ »)', () {
      expect(zFlashcardsSectionKey(subfolderId: ''), 'flashcards',
          reason: '`\'\'` produirait « flashcards/ » par simple interpolation — '
              'une clé fantôme, DISTINCTE de « flashcards »');
      expect(zFlashcardsSectionKey(subfolderId: null), 'flashcards');
    });

    test('sous-dossier non vide ⇒ « flashcards/<sub> »', () {
      expect(zFlashcardsSectionKey(subfolderId: 'sub1'), 'flashcards/sub1');
    });

    test('la constante de contentType est VERBATIM', () {
      expect(kFlashcardsContentType, 'flashcards');
    });

    test('zFlashcardsSectionKey DÉLÈGUE à zSectionKey (formes identiques)', () {
      // Si su-8 recomposait la clé à la main, les deux divergeraient un jour.
      for (final sub in <String?>[null, '', 'sub1', 'a-b-c']) {
        expect(
          zFlashcardsSectionKey(subfolderId: sub),
          zSectionKey(contentType: 'flashcards', subfolderId: sub),
          reason: 'divergence sur subfolderId=« $sub »',
        );
      }
    });
  });

  group('🔴 AC10/AD-38 — RÉTRO-COMPAT BOUT EN BOUT (ordre DÉJÀ persisté)', () {
    test(
      '🔴 un ordre écrit AVANT su-8 est retrouvé ET RÉELLEMENT APPLIQUÉ',
      () {
        // Simule le persisté RÉEL d'un consommateur (IFFD/lex_douane) : la clé
        // nue historique, écrite bien avant su-8.
        final persisted = ZFolderContentsOrder.fromMap(<String, dynamic>{
          'folder_id': 'f',
          'section_orders': <String, dynamic>{
            'flashcards': <String>['c2', 'c1'],
          },
        });

        // 1. La clé canonique de su-8 DOIT taper dans ce persisté.
        final order = persisted.orderFor(zFlashcardsSectionKey());
        expect(order, <String>['c2', 'c1'],
            reason: '🔴 une clé divergente rendrait une liste VIDE **en '
                'silence** — `orderFor` ne lève pas');

        // 2. Et l'ordre est RÉELLEMENT appliqué au rendu (assérer la clé ne
        //    suffit pas : `applyOrder` est TOTAL, avec une clé fautive il
        //    rendrait l'ordre d'ENTRÉE sans lever).
        final rendered = applyOrder<String>(
          <String>['c1', 'c2'], // ordre d'entrée = INVERSE du persisté
          order,
          idOf: (item) => item,
        );
        expect(rendered, <String>['c2', 'c1'],
            reason: '🔴 c\'est LE point : si la clé dérivait, `rendered` vaudrait '
                '[c1, c2] (l\'ordre d\'entrée) — le classement de '
                'l\'utilisateur serait « oublié » SANS AUCUN SIGNAL');
      },
    );

    test('🔴 ce que su-8 ÉCRIT est relisible par la clé historique', () {
      // Le sens INVERSE : su-8 écrit → un lecteur historique (clé nue littérale,
      // telle qu'elle est en base) doit retrouver l'ordre.
      final written = zReorderFlashcards(
        const ZFolderContentsOrder(folderId: 'f'),
        visibleIds: <String>['c1', 'c2', 'c3'],
        oldIndex: 0,
        newIndex: 2,
      );

      // Lecture par la clé BRUTE telle qu'elle existe en base (pas par notre
      // propre constructeur : ce serait une tautologie — les deux dériveraient
      // ensemble et le test resterait vert).
      final raw = written.sectionOrders['flashcards'];
      expect(raw, isNotNull,
          reason: '🔴 su-8 a écrit sous une clé que le persisté historique ne '
              'connaît PAS ⇒ l\'ordre est orphelin dès l\'écriture');
      expect(raw, <String>['c2', 'c3', 'c1']);
    });

    test('sous-dossier : écriture sous « flashcards/sub1 », section racine intacte', () {
      final base = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['r1', 'r2'],
        },
      );

      final written = zReorderFlashcards(
        base,
        visibleIds: <String>['s1', 's2'],
        oldIndex: 0,
        newIndex: 1,
        subfolderId: 'sub1',
      );

      expect(written.sectionOrders['flashcards/sub1'], <String>['s2', 's1']);
      expect(written.sectionOrders['flashcards'], <String>['r1', 'r2'],
          reason: '🔴 réordonner un sous-dossier ne doit PAS écraser l\'ordre '
              'de la racine — les sections sont indépendantes');
    });
  });

  group('🔴 AC11 — zReorderFlashcards : une seule voie, entrée jamais mutée', () {
    test('le déplacement délègue à zReorderIds (mêmes résultats)', () {
      const ids = <String>['a', 'b', 'c', 'd'];
      for (final move in <List<int>>[
        <int>[0, 2],
        <int>[3, 0],
        <int>[1, 1],
      ]) {
        final viaOrder = zReorderFlashcards(
          const ZFolderContentsOrder(folderId: 'f'),
          visibleIds: ids,
          oldIndex: move[0],
          newIndex: move[1],
        ).orderFor(zFlashcardsSectionKey());

        expect(viaOrder, zReorderIds(ids, move[0], move[1]),
            reason: 'déplacement ${move[0]}→${move[1]} : la voie unique doit '
                'DÉLÉGUER, jamais réimplémenter');
      }
    });

    test('l\'ordre d\'entrée n\'est JAMAIS muté', () {
      final original = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['c1', 'c2'],
        },
      );

      zReorderFlashcards(original,
          visibleIds: <String>['c1', 'c2'], oldIndex: 0, newIndex: 1);

      expect(original.orderFor('flashcards'), <String>['c1', 'c2'],
          reason: 'copyWith rend une NOUVELLE instance');
    });

    test('les autres sections sont préservées (jamais écrasées)', () {
      final base = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'notes': <String>['n1', 'n2'],
          'flashcards': <String>['c1', 'c2'],
        },
      );

      final written = zReorderFlashcards(base,
          visibleIds: <String>['c1', 'c2'], oldIndex: 0, newIndex: 1);

      expect(written.sectionOrders['notes'], <String>['n1', 'n2'],
          reason: '🔴 réordonner les cartes ne doit pas effacer l\'ordre des '
              'NOTES — perte muette de l\'ordre d\'une autre section');
      expect(written.sectionOrders['flashcards'], <String>['c2', 'c1']);
    });

    test('folderId et extra préservés par copyWith', () {
      final base = ZFolderContentsOrder(
        folderId: 'folder-42',
        extra: const <String, dynamic>{'custom': 'v'},
      );
      final written = zReorderFlashcards(base,
          visibleIds: <String>['a', 'b'], oldIndex: 0, newIndex: 1);

      expect(written.folderId, 'folder-42');
      expect(written.extra['custom'], 'v');
    });
  });

  group('🔴 AC11 — boutons a11y : Monter REMONTE, Descendre DESCEND', () {
    const ids = <String>['a', 'b', 'c'];

    test('🔴 Monter remonte RÉELLEMENT (su-4 : un « précédent » qui avançait)', () {
      final indices = zMoveUpIndices(ids, 'b');
      expect(indices, isNotNull);

      final order = zReorderFlashcards(
        const ZFolderContentsOrder(folderId: 'f'),
        visibleIds: ids,
        oldIndex: indices!.oldIndex,
        newIndex: indices.newIndex,
      ).orderFor(zFlashcardsSectionKey());

      expect(order, <String>['b', 'a', 'c'],
          reason: '🔴 « b » doit passer AVANT « a ». Un test qui n\'assérerait '
              'que « l\'ordre a changé » resterait vert si le bouton DESCENDAIT');
      expect(order.indexOf('b'), lessThan(order.indexOf('a')));
    });

    test('🔴 Descendre descend RÉELLEMENT', () {
      final indices = zMoveDownIndices(ids, 'b');
      expect(indices, isNotNull);

      final order = zReorderFlashcards(
        const ZFolderContentsOrder(folderId: 'f'),
        visibleIds: ids,
        oldIndex: indices!.oldIndex,
        newIndex: indices.newIndex,
      ).orderFor(zFlashcardsSectionKey());

      expect(order, <String>['a', 'c', 'b']);
      expect(order.indexOf('b'), greaterThan(order.indexOf('c')));
    });

    test('🔴 le PREMIER ne remonte pas (null ⇒ bouton ABSENT)', () {
      expect(zMoveUpIndices(ids, 'a'), isNull,
          reason: '🔴 `null` ⇒ action ABSENTE (AD-44), jamais grisée ni no-op');
    });

    test('🔴 le DERNIER ne descend pas (null ⇒ bouton ABSENT)', () {
      expect(zMoveDownIndices(ids, 'c'), isNull);
    });

    test('une carte ABSENTE ⇒ null des deux côtés (jamais de throw)', () {
      expect(zMoveUpIndices(ids, 'inconnu'), isNull);
      expect(zMoveDownIndices(ids, 'inconnu'), isNull);
    });

    test('liste d\'UN SEUL élément : ni monter ni descendre', () {
      expect(zMoveUpIndices(const <String>['seul'], 'seul'), isNull);
      expect(zMoveDownIndices(const <String>['seul'], 'seul'), isNull);
    });

    test('liste VIDE ⇒ null, jamais de throw', () {
      expect(zMoveUpIndices(const <String>[], 'x'), isNull);
      expect(zMoveDownIndices(const <String>[], 'x'), isNull);
    });

    test('🔴 DRAG et BOUTONS ⇒ ordre persisté IDENTIQUE (la MÊME voie)', () {
      // Le drag de « c » (index 2) vers l'index 1 == le bouton « Monter » sur
      // « c ». Les deux DOIVENT produire le même persisté — sinon deux voies.
      const order0 = ZFolderContentsOrder(folderId: 'f');

      final viaDrag = zReorderFlashcards(order0,
          visibleIds: ids, oldIndex: 2, newIndex: 1);

      final up = zMoveUpIndices(ids, 'c')!;
      final viaButton = zReorderFlashcards(order0,
          visibleIds: ids, oldIndex: up.oldIndex, newIndex: up.newIndex);

      expect(
        viaButton.orderFor(zFlashcardsSectionKey()),
        viaDrag.orderFor(zFlashcardsSectionKey()),
        reason: '🔴 AC11 : drag et boutons aboutissent à UNE SEULE fonction de '
            'réordonnancement — deux voies divergeraient en silence',
      );
      expect(viaDrag.orderFor(zFlashcardsSectionKey()), <String>['a', 'c', 'b']);
    });
  });

  group('🔴 AC12/AD-10 — ordre PÉRIMÉ, orphelins, robustesse', () {
    test('🔴 ordre périmé (cartes supprimées ET ajoutées) ⇒ cohérent, sans throw', () {
      // Persisté : c1, c2, c3. Réel : c2 supprimée, c4 ajoutée.
      final stale = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['c1', 'c2', 'c3'],
        },
      );

      final rendered = stale.applyTo<String>(
        zFlashcardsSectionKey(),
        <String>['c4', 'c3', 'c1'], // ordre d'entrée arbitraire
        idOf: (id) => id,
      );

      expect(rendered, <String>['c1', 'c3', 'c4'],
          reason: '🔴 c1/c3 suivent l\'ordre personnel ; « c2 » (orpheline) est '
              'IGNORÉE ; « c4 » (neuve) est APPENDÉE en fin — jamais de throw, '
              'jamais de carte perdue');
    });

    test('🔴 nouveaux éléments APPENDÉS de façon stable (ZUnorderedPlacement.end)', () {
      final order = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['c1'],
        },
      );

      final rendered = order.applyTo<String>(
        zFlashcardsSectionKey(),
        <String>['n1', 'n2', 'c1', 'n3'],
        idOf: (id) => id,
      );

      expect(rendered, <String>['c1', 'n1', 'n2', 'n3'],
          reason: 'les neuves gardent leur ordre RELATIF d\'entrée (stable)');
    });

    test('🔴 clé de section INCONNUE ⇒ ordre d\'entrée, jamais de throw', () {
      const order = ZFolderContentsOrder(folderId: 'f');
      final rendered = order.applyTo<String>(
        zFlashcardsSectionKey(subfolderId: 'jamais-vu'),
        <String>['a', 'b'],
        idOf: (id) => id,
      );
      expect(rendered, <String>['a', 'b']);
      expect(order.orderFor('clé-inconnue'), isEmpty);
    });

    test('ids d\'ordre sans carte ⇒ IGNORÉS en silence', () {
      final order = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['fantome1', 'c1', 'fantome2'],
        },
      );
      final rendered = order.applyTo<String>(
        zFlashcardsSectionKey(),
        <String>['c1'],
        idOf: (id) => id,
      );
      expect(rendered, <String>['c1']);
    });

    test('indices HORS BORNES ⇒ clampés, jamais de throw (AD-10)', () {
      const ids = <String>['a', 'b'];
      for (final move in <List<int>>[
        <int>[-5, 0],
        <int>[0, 99],
        <int>[99, -3],
      ]) {
        final result = zReorderFlashcards(
          const ZFolderContentsOrder(folderId: 'f'),
          visibleIds: ids,
          oldIndex: move[0],
          newIndex: move[1],
        );
        expect(result.orderFor(zFlashcardsSectionKey()).length, 2,
            reason: 'clamp : aucune carte perdue (${move[0]}→${move[1]})');
      }
    });

    test('visibleIds VIDE ⇒ ordre vide écrit, jamais de throw', () {
      final result = zReorderFlashcards(
        const ZFolderContentsOrder(folderId: 'f'),
        visibleIds: const <String>[],
        oldIndex: 0,
        newIndex: 0,
      );
      expect(result.orderFor(zFlashcardsSectionKey()), isEmpty);
    });

    test('UNE SEULE carte ⇒ ordre inchangé', () {
      final result = zReorderFlashcards(
        const ZFolderContentsOrder(folderId: 'f'),
        visibleIds: const <String>['seule'],
        oldIndex: 0,
        newIndex: 0,
      );
      expect(result.orderFor(zFlashcardsSectionKey()), <String>['seule']);
    });

    test('🔴 l\'ordre se répare : purge des orphelins — SI visibleIds est COMPLET', () {
      // 🔴 D1 — CE test verrouillait le bug HIGH : au niveau de la fonction pure,
      // `zReorderFlashcards` REMPLACE la section par `visibleIds` (contrat total,
      // correct). Mais « id absent de visibleIds » ne signifie « orphelin » que si
      // `visibleIds` est l'univers COMPLET de la section. Sous un filtre, une
      // carte VIVANTE masquée serait absente de visibleIds et donc PURGÉE — perte
      // de données. La complétude de `visibleIds` est garantie EN AMONT, par la
      // vue : `_contentFilterActive` DÉSACTIVE le réordonnancement sous filtre
      // (prouvé par `z_flashcard_list_view_test.dart` › « D1 (HIGH) — réordonner
      // sous filtre… »). Ici on ne teste donc QUE le cas complet : « supprimee »
      // est réellement supprimée (absente des cartes réelles), pas filtrée.
      final stale = ZFolderContentsOrder(
        folderId: 'f',
        sectionOrders: <String, List<String>>{
          'flashcards': <String>['supprimee', 'c1', 'c2'],
        },
      );

      final written = zReorderFlashcards(stale,
          visibleIds: <String>['c1', 'c2'], oldIndex: 0, newIndex: 1);

      final result = written.orderFor(zFlashcardsSectionKey());
      expect(result, <String>['c2', 'c1']);
      expect(result.contains('supprimee'), isFalse,
          reason: 'l\'ordre se répare — MAIS uniquement parce que « supprimee » '
              'est réellement absente des cartes (orpheline), jamais parce '
              'qu\'un filtre la masquerait (ce cas est écarté par la vue — D1)');
    });
  });
}
