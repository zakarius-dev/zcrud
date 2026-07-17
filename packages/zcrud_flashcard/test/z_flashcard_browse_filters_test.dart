// Tests des filtres de CONSULTATION (SU-8/AC5, AC6, AC7 — D4) et du tri (AC8).
//
// 🔴 Le test structurant est « AUCUN tirage, AUCUN aléa » : `zApplyBrowseFilters`
// et `zApplyTestFilters` se ressemblent, mais confondre les deux afficherait
// **10 cartes** d'un dossier qui en compte 2 000 — un défaut fonctionnel majeur
// et MUET (la liste s'afficherait, simplement incomplète).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

ZFlashcard _card(
  String id, {
  String question = 'Question',
  String? answer,
  List<String> tagIds = const <String>[],
  String? folderId = 'f1',
  String? subFolderId,
  ZFlashcardType type = ZFlashcardType.openQuestion,
  ZFlashcardSource? source,
  List<ZChoice>? choices,
  DateTime? createdAt,
}) =>
    ZFlashcard(
      id: id,
      question: question,
      answer: answer,
      tagIds: tagIds,
      folderId: folderId,
      subFolderId: subFolderId,
      type: type,
      source: source,
      choices: choices,
      createdAt: createdAt,
    );

/// Sélecteur « tout passe » — le cas où su-8 n'ajoute QUE ses propres filtres.
const _allSelector = ZStudySessionSelector(ZStudySessionConfig());

List<String> _ids(List<ZFlashcard> cards) =>
    cards.map((c) => c.id ?? '<null>').toList();

void main() {
  group('🔴 AC7 — AUCUN tirage, AUCUN aléa (la faute que D4 prévient)', () {
    test('🔴 GARDE DE SIGNATURE : ni Random, ni questionCount dans la source', () {
      // Une garde de SOURCE, car le défaut serait invisible au comportement s'il
      // était introduit avec un défaut permissif (`count = 1000` passerait tous
      // les tests jusqu'au jour où un dossier dépasse 1000).
      final src = File('lib/src/domain/z_flashcard_filters.dart')
          .readAsLinesSync();

      // Isole le CODE de `zApplyBrowseFilters`, **commentaires exclus** : la
      // prose DOIT pouvoir expliquer pourquoi la fonction n'appelle PAS
      // `selectFrom` ni `zDrawQuestions` (c'est même l'essentiel de sa
      // justification). Une garde qui interdirait ce que la dartdoc voisine
      // exige d'expliquer serait une garde qui se contredit — patron
      // `z_section_key_single_composition_test.dart`.
      final start = src.indexWhere(
          (l) => l.startsWith('List<ZFlashcard> zApplyBrowseFilters('));
      expect(start, greaterThanOrEqualTo(0),
          reason: 'sonde cassée : `zApplyBrowseFilters` introuvable ⇒ la garde '
              'ne mesurerait RIEN');
      final end = src.indexWhere((l) => l == '}', start);
      expect(end, greaterThan(start));
      final body = src
          .sublist(start, end + 1)
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') && !t.startsWith('///');
          })
          .join('\n');

      // Sonde : le corps réellement scanné n'est pas vide (sinon la garde
      // serait verte en ne regardant rien).
      expect(body.contains('selector.matches'), isTrue,
          reason: 'sonde cassée : le corps extrait ne contient même pas '
              '`selector.matches` ⇒ l\'extraction est fausse et la garde '
              'infalsifiable');

      expect(body.contains('Random'), isFalse,
          reason: '🔴 un `Random` rendrait la liste de gestion NON DÉTERMINISTE '
              '— elle changerait d\'ordre à chaque rebuild');
      expect(body.contains('questionCount'), isFalse,
          reason: '🔴 `questionCount` (défaut 10) tronquerait un dossier de '
              '2 000 cartes à 10, EN SILENCE');
      expect(body.contains('zDrawQuestions'), isFalse,
          reason: '🔴 le tirage appartient à la session, jamais à la liste');
      expect(body.contains('selectFrom'), isFalse,
          reason: '🔴 `selectFrom` applique le plafond `config.count` — il '
              'tronquerait la liste. Seul `matches` (prédicat) est légitime');
    });

    test('DÉTERMINISME : deux appels identiques ⇒ résultat identique', () {
      final cards = List<ZFlashcard>.generate(50, (i) => _card('c$i'));
      final filters = const ZFlashcardBrowseFilters();

      final a = zApplyBrowseFilters(cards, selector: _allSelector, filters: filters);
      final b = zApplyBrowseFilters(cards, selector: _allSelector, filters: filters);

      expect(_ids(a), _ids(b));
      expect(a.length, 50, reason: '🔴 les 50 cartes sortent — AUCUNE troncature');
    });

    test('🔴 2 000 cartes ⇒ 2 000 rendues (jamais 10)', () {
      final cards = List<ZFlashcard>.generate(2000, (i) => _card('c$i'));
      final result = zApplyBrowseFilters(
        cards,
        selector: _allSelector,
        filters: const ZFlashcardBrowseFilters(),
      );
      expect(result.length, 2000,
          reason: '🔴 c\'est LE test de D4 : `zApplyTestFilters` en rendrait 10 '
              '(son `questionCount` par défaut)');
    });

    test(
      '🔴 le plafond `config.count` du sélecteur est IGNORÉ (matches, pas selectFrom)',
      () {
        // 🔴 LE test comportemental de D4. Une app réutilise naturellement SA
        // `ZStudySessionConfig` (celle des sessions, `count: 10`) pour filtrer la
        // liste. Si `zApplyBrowseFilters` appelait `selectFrom`, la liste
        // n'afficherait que **10** cartes sur 50 — en silence.
        //
        // ⚠️ Ce test est indispensable ET NON REDONDANT avec « 2 000 cartes » :
        // ce dernier utilise un sélecteur à `count: null`, pour lequel
        // `selectFrom` rend TOUT — il resterait donc VERT sous l'injection.
        // Seul un `count` NON NUL rend les deux voies distinguables.
        final cards = List<ZFlashcard>.generate(50, (i) => _card('c$i'));
        const selector = ZStudySessionSelector(ZStudySessionConfig(count: 10));

        final result = zApplyBrowseFilters(
          cards,
          selector: selector,
          filters: const ZFlashcardBrowseFilters(),
        );

        expect(result.length, 50,
            reason: '🔴 `selectFrom` aurait tronqué à `config.count` = 10. Une '
                'liste de GESTION ne connaît aucun plafond : `matches` est le '
                'prédicat, `count` est un plafond de SESSION');
      },
    );

    test('ordre d\'ENTRÉE préservé (le tri est la responsabilité de l\'appelant)', () {
      final cards = <ZFlashcard>[_card('c3'), _card('c1'), _card('c2')];
      final result = zApplyBrowseFilters(
        cards,
        selector: _allSelector,
        filters: const ZFlashcardBrowseFilters(),
      );
      expect(_ids(result), <String>['c3', 'c1', 'c2']);
    });

    test('l\'entrée n\'est jamais mutée', () {
      final cards = <ZFlashcard>[_card('c1'), _card('c2')];
      zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(query: 'zzz'));
      expect(cards.length, 2);
    });
  });

  group('🔴 AC6 — dossier ∧ tags ∧ types DÉLÉGUÉS au kernel (jamais réécrits)', () {
    test('sous-dossier : le dossier cible couvre ses sous-dossiers', () {
      final cards = <ZFlashcard>[
        _card('direct', folderId: 'target'),
        _card('sub', folderId: 'autre', subFolderId: 'target'),
        _card('dehors', folderId: 'autre'),
      ];
      final selector =
          const ZStudySessionSelector(ZStudySessionConfig(folderId: 'target'));

      final result = zApplyBrowseFilters(cards,
          selector: selector, filters: const ZFlashcardBrowseFilters());

      expect(_ids(result), <String>['direct', 'sub'],
          reason: 'rattachement inverse 2 niveaux — comportement du kernel');
    });

    test('🔴 tags : composables en OU (intersection non vide)', () {
      final cards = <ZFlashcard>[
        _card('a', tagIds: const <String>['t1']),
        _card('b', tagIds: const <String>['t2']),
        _card('c', tagIds: const <String>['t3']),
        _card('ab', tagIds: const <String>['t1', 't2']),
      ];
      final selector = const ZStudySessionSelector(
        ZStudySessionConfig(tagIds: <String>['t1', 't2']),
      );

      final result = zApplyBrowseFilters(cards,
          selector: selector, filters: const ZFlashcardBrowseFilters());

      expect(_ids(result), <String>['a', 'b', 'ab'],
          reason: '🔴 OU : une carte portant t1 OU t2 est retenue. Un ET aurait '
              'rendu la seule carte « ab »');
    });

    test('types : appartenance à l\'ensemble de clés opaques', () {
      final cards = <ZFlashcard>[
        _card('open', type: ZFlashcardType.openQuestion),
        _card('qcm', type: ZFlashcardType.multipleChoice),
        _card('vf', type: ZFlashcardType.trueOrFalse),
      ];
      final selector = const ZStudySessionSelector(
        ZStudySessionConfig(types: <String>['multipleChoice', 'trueOrFalse']),
      );

      final result = zApplyBrowseFilters(cards,
          selector: selector, filters: const ZFlashcardBrowseFilters());

      expect(_ids(result), <String>['qcm', 'vf']);
    });

    test('COMBINAISON : dossier ∧ tags ∧ types ∧ source ∧ recherche', () {
      final cards = <ZFlashcard>[
        _card('cible',
            folderId: 'f',
            tagIds: const <String>['t1'],
            type: ZFlashcardType.multipleChoice,
            question: 'Élève modèle',
            source: ZCustomSource('pdf', const <String, dynamic>{})),
        _card('mauvais-dossier',
            folderId: 'autre',
            tagIds: const <String>['t1'],
            type: ZFlashcardType.multipleChoice,
            question: 'Élève modèle',
            source: ZCustomSource('pdf', const <String, dynamic>{})),
        _card('mauvaise-source',
            folderId: 'f',
            tagIds: const <String>['t1'],
            type: ZFlashcardType.multipleChoice,
            question: 'Élève modèle',
            source: ZCustomSource('web', const <String, dynamic>{})),
      ];
      final selector = const ZStudySessionSelector(ZStudySessionConfig(
        folderId: 'f',
        tagIds: <String>['t1'],
        types: <String>['multipleChoice'],
      ));

      final result = zApplyBrowseFilters(
        cards,
        selector: selector,
        filters: const ZFlashcardBrowseFilters(
          query: 'eleve',
          sources: <String>{'pdf'},
        ),
      );

      expect(_ids(result), <String>['cible'],
          reason: 'les filtres se composent en ET, de façon cohérente');
    });
  });

  group('AC6 — `kind` de source : implémentation UNIQUE partagée', () {
    test('vide = toutes les provenances', () {
      final cards = <ZFlashcard>[
        _card('sans-source'),
        _card('pdf', source: ZCustomSource('pdf', const <String, dynamic>{})),
      ];
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector, filters: const ZFlashcardBrowseFilters());
      expect(result.length, 2);
    });

    test('filtre posé ⇒ une carte SANS source est exclue', () {
      final cards = <ZFlashcard>[
        _card('sans-source'),
        _card('pdf', source: ZCustomSource('pdf', const <String, dynamic>{})),
      ];
      final result = zApplyBrowseFilters(
        cards,
        selector: _allSelector,
        filters: const ZFlashcardBrowseFilters(sources: <String>{'pdf'}),
      );
      expect(_ids(result), <String>['pdf'],
          reason: 'une carte sans provenance n\'a pas la provenance demandée');
    });

    test('🔴 le prédicat est LE MÊME que celui du tirage (une seule source)', () {
      // Exerce `zMatchesSourceKind` DIRECTEMENT : c'est la fonction que les deux
      // surfaces appellent. Si elle divergeait, les deux filtres divergeraient.
      final pdf = _card('p', source: ZCustomSource('pdf', const <String, dynamic>{}));
      final web = _card('w', source: ZCustomSource('web', const <String, dynamic>{}));
      final nul = _card('n');

      expect(zMatchesSourceKind(pdf, const <String>{}), isTrue);
      expect(zMatchesSourceKind(pdf, const <String>{'pdf'}), isTrue);
      expect(zMatchesSourceKind(web, const <String>{'pdf'}), isFalse);
      expect(zMatchesSourceKind(nul, const <String>{'pdf'}), isFalse);
      expect(zMatchesSourceKind(nul, const <String>{}), isTrue);
    });

    test('GARDE : zApplyTestFilters CONSOMME réellement zMatchesSourceKind', () {
      // « Factorisé et partagé » doit être VRAI sur disque, pas seulement dans
      // la dartdoc (5 récidives de prose menteuse dans cet epic).
      final src = File('lib/src/domain/z_flashcard_filters.dart').readAsLinesSync();
      final start = src
          .indexWhere((l) => l.startsWith('List<ZFlashcard> zApplyTestFilters('));
      expect(start, greaterThanOrEqualTo(0), reason: 'sonde cassée');
      final end = src.indexWhere((l) => l == '}', start);
      // Commentaires exclus — même raison que la garde de signature ci-dessus.
      final body = src
          .sublist(start, end + 1)
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') && !t.startsWith('///');
          })
          .join('\n');

      expect(body.contains('zMatchesSourceKind'), isTrue,
          reason: '🔴 le tirage a re-inline son propre filtre de source ⇒ DEUX '
              'implémentations du même prédicat, qui divergeront');
      expect(body.contains('filters.sources.contains'), isFalse,
          reason: '🔴 réimplémentation inline détectée');
    });
  });

  group('AC5 — recherche : champs configurables par ENUM', () {
    final cards = <ZFlashcard>[
      _card('q', question: 'Le noyau atomique'),
      _card('a', question: 'Autre', answer: 'Le noyau contient des protons'),
      _card('t', question: 'Autre', tagIds: const <String>['noyau']),
      _card('c', question: 'Autre', choices: const <ZChoice>[
        ZChoice(content: 'Le noyau', isCorrect: true),
        ZChoice(content: 'Autre chose'),
      ]),
      _card('rien', question: 'Sans rapport'),
    ];

    test('défaut = les TROIS champs (question + réponse/choix + tags)', () {
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(query: 'noyau'));
      expect(_ids(result), <String>['q', 'a', 't', 'c'],
          reason: '🔴 IFFD ne cherchait QUE la question — su-8 corrige : la '
              'réponse, les CHOIX (QCM) et les tags comptent aussi');
    });

    test('question seule', () {
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(
            query: 'noyau',
            searchFields: <ZFlashcardSearchField>{ZFlashcardSearchField.question},
          ));
      expect(_ids(result), <String>['q']);
    });

    test('réponse seule : couvre `answer` ET le contenu des `choices`', () {
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(
            query: 'noyau',
            searchFields: <ZFlashcardSearchField>{ZFlashcardSearchField.answer},
          ));
      expect(_ids(result), <String>['a', 'c'],
          reason: 'une carte QCM n\'a pas d\'`answer` : n\'en lire qu\'un '
              'rendrait la recherche muette sur la moitié des types');
    });

    test('tags seuls', () {
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(
            query: 'noyau',
            searchFields: <ZFlashcardSearchField>{ZFlashcardSearchField.tags},
          ));
      expect(_ids(result), <String>['t']);
    });

    test('tagLabels résout les ids en libellés quand fourni', () {
      final tagged = <ZFlashcard>[_card('x', tagIds: const <String>['tag-42'])];

      // Sans résolution : la recherche porte sur l'ID.
      expect(
        zApplyBrowseFilters(tagged,
            selector: _allSelector,
            filters: const ZFlashcardBrowseFilters(query: 'physique')),
        isEmpty,
      );
      // Avec résolution : elle porte sur le LIBELLÉ.
      expect(
        _ids(zApplyBrowseFilters(tagged,
            selector: _allSelector,
            filters: const ZFlashcardBrowseFilters(query: 'physique'),
            tagLabels: const <String, String>{'tag-42': 'Physique'})),
        <String>['x'],
      );
    });

    test('searchFields VIDE + query ⇒ rien (choix explicite documenté)', () {
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(
            query: 'noyau',
            searchFields: <ZFlashcardSearchField>{},
          ));
      expect(result, isEmpty,
          reason: 'on a explicitement demandé à ne chercher NULLE PART');
    });
  });

  group('🔴 AC4/AC7/AD-10 — recherche normalisée + robustesse', () {
    test('« eleve » trouve « Élève » — NFC et NFD, dans la LISTE', () {
      // 🔴 NFD EXPLICITE (\u) : É = E+U+0301, è = e+U+0300. Un littéral collé
      // « Élève » est souvent re-précomposé (NFC) en silence par l'éditeur — la
      // sonde ci-dessous garantit que ce corpus est RÉELLEMENT décomposé, sans
      // quoi ce test resterait vert même le strip NFD supprimé (motif ②).
      const nfdEleve = 'E\u0301le\u0300ve studieux';
      expect(nfdEleve.runes.any((r) => r >= 0x300 && r <= 0x36F), isTrue,
          reason: 'sonde : le corpus « nfd » DOIT porter une marque combinante');
      final cards = <ZFlashcard>[
        _card('nfc', question: 'Élève studieux'),
        _card('nfd', question: nfdEleve), // NFD réel (cf. sonde ci-dessus)
        _card('non', question: 'Professeur'),
      ];
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(query: 'eleve'));
      expect(_ids(result), <String>['nfc', 'nfd'],
          reason: '🔴 la normalisation doit s\'appliquer des DEUX côtés de la '
              'comparaison, sur le chemin RÉEL de la liste');
    });

    test('la REQUÊTE est normalisée aussi (« ÉLÈVE  » trouve « eleve »)', () {
      final cards = <ZFlashcard>[_card('x', question: 'eleve')];
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(query: '  ÉLÈVE  '));
      expect(_ids(result), <String>['x']);
    });

    test('query vide / espaces seuls ⇒ AUCUN filtre texte', () {
      final cards = <ZFlashcard>[_card('a'), _card('b')];
      for (final q in <String>['', '   ', '\t']) {
        expect(
          zApplyBrowseFilters(cards,
                  selector: _allSelector,
                  filters: ZFlashcardBrowseFilters(query: q))
              .length,
          2,
          reason: 'query « $q » ne doit RIEN filtrer',
        );
      }
    });

    test('recherche ne retenant RIEN ⇒ liste vide, jamais de throw', () {
      final cards = <ZFlashcard>[_card('a'), _card('b')];
      final result = zApplyBrowseFilters(cards,
          selector: _allSelector,
          filters: const ZFlashcardBrowseFilters(query: 'zzz-introuvable'));
      expect(result, isEmpty);
    });

    test('dossier VIDE ⇒ liste vide, jamais de throw', () {
      expect(
        zApplyBrowseFilters(const <ZFlashcard>[],
            selector: _allSelector, filters: const ZFlashcardBrowseFilters()),
        isEmpty,
      );
    });

    test('UNE SEULE carte', () {
      final result = zApplyBrowseFilters(<ZFlashcard>[_card('seule')],
          selector: _allSelector, filters: const ZFlashcardBrowseFilters());
      expect(_ids(result), <String>['seule']);
    });

    test('tags VIDES / DUPLIQUÉS ⇒ jamais de throw', () {
      final cards = <ZFlashcard>[
        _card('vide', tagIds: const <String>[]),
        _card('dup', tagIds: const <String>['t1', 't1', 't1']),
      ];
      final selector =
          const ZStudySessionSelector(ZStudySessionConfig(tagIds: <String>['t1']));
      final result = zApplyBrowseFilters(cards,
          selector: selector, filters: const ZFlashcardBrowseFilters());
      expect(_ids(result), <String>['dup'],
          reason: 'un tag dupliqué ne doit pas dupliquer la carte');
      expect(result.length, 1);
    });

    test('emoji dans la recherche ⇒ jamais de throw', () {
      final cards = <ZFlashcard>[_card('e', question: 'Fête 🎉 nationale')];
      expect(
        _ids(zApplyBrowseFilters(cards,
            selector: _allSelector,
            filters: const ZFlashcardBrowseFilters(query: '🎉'))),
        <String>['e'],
      );
      expect(
        _ids(zApplyBrowseFilters(cards,
            selector: _allSelector,
            filters: const ZFlashcardBrowseFilters(query: 'fete'))),
        <String>['e'],
      );
    });
  });

  group('AC5/AC6 — value object immuable (== / hashCode)', () {
    test('égalité par CONTENU', () {
      const a = ZFlashcardBrowseFilters(query: 'q', sources: <String>{'pdf'});
      const b = ZFlashcardBrowseFilters(query: 'q', sources: <String>{'pdf'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('différence sur chaque champ', () {
      const base = ZFlashcardBrowseFilters();
      expect(base == const ZFlashcardBrowseFilters(query: 'x'), isFalse);
      expect(base == const ZFlashcardBrowseFilters(sources: <String>{'p'}), isFalse);
      expect(
        base ==
            const ZFlashcardBrowseFilters(
                searchFields: <ZFlashcardSearchField>{ZFlashcardSearchField.tags}),
        isFalse,
      );
    });
  });

  group('🔴 AC8 — tri : stable, total, jamais de throw', () {
    final d1 = DateTime.utc(2020, 1, 1);
    final d2 = DateTime.utc(2021, 1, 1);
    final d3 = DateTime.utc(2022, 1, 1);

    test('dateDesc : plus récentes d\'abord', () {
      final cards = <ZFlashcard>[
        _card('vieux', createdAt: d1),
        _card('recent', createdAt: d3),
        _card('milieu', createdAt: d2),
      ];
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.dateDesc)),
          <String>['recent', 'milieu', 'vieux']);
    });

    test('dateAsc : plus anciennes d\'abord', () {
      final cards = <ZFlashcard>[
        _card('vieux', createdAt: d1),
        _card('recent', createdAt: d3),
        _card('milieu', createdAt: d2),
      ];
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.dateAsc)),
          <String>['vieux', 'milieu', 'recent']);
    });

    test('🔴 createdAt NULL : position déterministe (fin), dans LES DEUX sens', () {
      final cards = <ZFlashcard>[
        _card('nul1'),
        _card('date', createdAt: d2),
        _card('nul2'),
      ];
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.dateDesc)),
          <String>['date', 'nul1', 'nul2']);
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.dateAsc)),
          <String>['date', 'nul1', 'nul2'],
          reason: '🔴 une carte SANS date ne doit pas SURGIR EN TÊTE d\'un tri '
              '« plus anciennes d\'abord » — elle n\'a pas de date, point');
    });

    test('🔴 STABILITÉ : ex-aequo ⇒ ordre d\'entrée préservé', () {
      // Import en lot : 5 cartes à la MÊME seconde. Sans clé secondaire, elles
      // permuteraient d'un rebuild à l'autre — la liste « sauterait ».
      final cards = List<ZFlashcard>.generate(
          5, (i) => _card('c$i', createdAt: d2));
      final once = _ids(zSortFlashcards(cards, ZFlashcardSortMode.dateDesc));
      expect(once, <String>['c0', 'c1', 'c2', 'c3', 'c4']);
      // Rejoué : strictement identique.
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.dateDesc)), once);
    });

    test('title : alphabétique NORMALISÉ (accents rangés à leur place)', () {
      final cards = <ZFlashcard>[
        _card('z', question: 'Zèbre'),
        _card('e', question: 'Élève'),
        _card('a', question: 'avion'),
      ];
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.title)),
          <String>['a', 'e', 'z'],
          reason: '🔴 un tri brut mettrait « Élève » APRÈS « Zèbre » (ordre des '
              'points de code) — faux pour un francophone');
    });

    test('🔴 manual : ordre d\'entrée INCHANGÉ (AD-38, jamais une 2e voie)', () {
      final cards = <ZFlashcard>[
        _card('c3', createdAt: d3),
        _card('c1', createdAt: d1),
        _card('c2', createdAt: d2),
      ];
      expect(_ids(zSortFlashcards(cards, ZFlashcardSortMode.manual)),
          <String>['c3', 'c1', 'c2'],
          reason: '🔴 `manual` ne trie RIEN : l\'ordre manuel appartient à '
              '`ZFolderContentsOrder`/`applyOrder`. Trier ici serait une '
              'SECONDE voie d\'ordre manuel');
    });

    test('liste VIDE / UNE carte ⇒ jamais de throw', () {
      for (final mode in ZFlashcardSortMode.values) {
        expect(zSortFlashcards(const <ZFlashcard>[], mode), isEmpty);
        expect(zSortFlashcards(<ZFlashcard>[_card('x')], mode).length, 1);
      }
    });

    test('l\'entrée n\'est jamais mutée', () {
      final cards = <ZFlashcard>[
        _card('b', createdAt: d1),
        _card('a', createdAt: d3),
      ];
      zSortFlashcards(cards, ZFlashcardSortMode.dateDesc);
      expect(_ids(cards), <String>['b', 'a'], reason: 'copie, jamais en place');
    });
  });
}
