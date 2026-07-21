// me-2 — tests porteurs du widget `ZMultiFlashcardEditor` (AC1/AC3/AC5/AC6/AC7/
// AC8/AC9/AC10). L'espion de commit est PROUVÉ captant (écriture témoin) avant
// toute assertion « 0 écriture » (leçon su-9/me-1).
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart'
    show EditionFieldType, ZServerFailure, Unit, ZFieldSpec, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

class _CommitSpy {
  int writes = 0;
  final List<List<ZFlashcard>> payloads = <List<ZFlashcard>>[];
  bool fail = false;
  Future<ZResult<Unit>> call(List<ZFlashcard> cards) async {
    writes++;
    payloads.add(List<ZFlashcard>.of(cards));
    if (fail) return left(const ZServerFailure('refusé'));
    return right(unit);
  }
}

final _labels = ZMultiFlashcardEditorLabels(
  addCardLabel: 'Ajouter',
  deleteSelectedLabel: 'Supprimer',
  commitLabel: 'Enregistrer',
  applyCommonLabel: 'Appliquer',
  selectAllLabel: 'Tout sélectionner',
  emptyState: 'Aucune carte',
  detailPlaceholder: 'Sélectionner une carte',
  backToListLabel: 'Retour',
  questionLabel: 'Question',
  answerLabel: 'Réponse',
  explanationLabel: 'Explication',
  hintLabel: 'Indice',
  typeLabel: 'Type',
  commonFieldPickerLabel: 'Champ',
  commonValueLabel: 'Valeur',
  previewTitle: 'Aperçu',
  commitSucceeded: 'Enregistré',
  commitFailed: 'Échec',
  selectCardSemanticLabel: (i) => 'Sélectionner la carte $i',
  countLabelBuilder: (n) => '$n sélectionnée(s)',
  applyReportBuilder: (r) =>
      'Appliqué à ${r.succeededCount}, échecs ${r.failedCount}',
);

const _folderField = ZFieldSpec(
  name: 'folder_id',
  type: EditionFieldType.text,
);

final _commonFields = <ZMultiFlashcardCommonField>[
  ZMultiFlashcardCommonField(
    spec: _folderField,
    label: 'Dossier',
    apply: (card, value) => card.copyWith(folderId: value),
  ),
];

ZFlashcard _card(String id, {String q = 'Q'}) =>
    ZFlashcard(id: id, question: q);

Widget _harness(
  Widget child, {
  Size size = const Size(1000, 800),
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    );

ZMultiFlashcardEditor _editor({
  required _CommitSpy spy,
  List<ZFlashcard> cards = const <ZFlashcard>[],
  List<ZMultiFlashcardCommonField> commonFields = const <ZMultiFlashcardCommonField>[],
  Widget Function(BuildContext, ZFlashcard)? rowContentBuilder,
}) =>
    ZMultiFlashcardEditor(
      initialCards: cards,
      onCommit: spy.call,
      labels: _labels,
      commonFields: commonFields,
      rowContentBuilder: rowContentBuilder,
    );

void main() {
  group('🔴 AC1 — split-view responsive (infra existante, pas de breakpoint)', () {
    testWidgets('grand écran (≥ 840) ⇒ liste ET formulaire simultanés',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(
        _harness(_editor(spy: spy, cards: <ZFlashcard>[_card('a')]),
            size: const Size(1000, 800)),
      );
      await tester.pump();
      expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsOneWidget);
      expect(find.byKey(ZMultiFlashcardEditor.detailPaneKey), findsOneWidget,
          reason: '🔴 en large les DEUX volets coexistent (split-view)');
    });

    testWidgets('mobile (< 600) ⇒ un SEUL volet + navigation liste↔formulaire',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(
        _harness(_editor(spy: spy, cards: <ZFlashcard>[_card('a')]),
            size: const Size(400, 800)),
      );
      await tester.pump();
      // Un seul volet : la liste (aucune carte focalisée).
      expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsOneWidget);
      expect(find.byKey(ZMultiFlashcardEditor.detailPaneKey), findsNothing);

      // Navigation : taper une ligne ⇒ le formulaire remplace la liste.
      await tester.tap(find.text('Q'));
      await tester.pump();
      expect(find.byKey(ZMultiFlashcardEditor.detailPaneKey), findsOneWidget);
      expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsNothing,
          reason: '🔴 en étroit : un seul volet à la fois (navigation)');
    });
  });

  group('🔴 AC3 — sortie gardée par ZDiscardChangesGuard EXISTANT', () {
    testWidgets('brouillon PROPRE ⇒ pop direct, aucun dialog', (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(),
                  body: _editor(spy: spy, cards: <ZFlashcard>[_card('a')]),
                ),
              ),
            ),
            child: const Text('PUSH'),
          ),
        ),
      ));
      await tester.tap(find.text('PUSH'));
      await tester.pumpAndSettle();
      expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Sorti sans dialog.
      expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsNothing);
    });

    testWidgets(
      '🔴 brouillon DIRTY (une carte ajoutée) ⇒ sortie bloquée + dialog',
      (tester) async {
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(),
                    body: _editor(spy: spy),
                  ),
                ),
              ),
              child: const Text('PUSH'),
            ),
          ),
        ));
        await tester.tap(find.text('PUSH'));
        await tester.pumpAndSettle();

        // Rend le brouillon DIRTY.
        await tester.tap(find.byKey(ZMultiFlashcardEditor.addButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Bloqué : toujours là + un dialog de confirmation (destructif) affiché.
        expect(find.byKey(ZMultiFlashcardEditor.listPaneKey), findsOneWidget,
            reason: '🔴 sortie bloquée tant que le brouillon diverge');
        expect(find.byType(Dialog), findsOneWidget);
      },
    );
  });

  group('🔴 AC4/AC8 — commit unique = SEULE frontière (espion prouvé captant)', () {
    testWidgets(
      '🔴 add + delete + apply NE persistent RIEN ; le commit = UNE salve',
      (tester) async {
        final spy = _CommitSpy();

        // 1) ÉCRITURE TÉMOIN : l'espion capte réellement.
        await spy.call(<ZFlashcard>[_card('témoin')]);
        expect(spy.writes, 1);

        await tester.pumpWidget(_harness(
            _editor(spy: spy, cards: <ZFlashcard>[_card('a'), _card('b')])));
        await tester.pump();

        // add.
        await tester.tap(find.byKey(ZMultiFlashcardEditor.addButtonKey));
        await tester.pump();
        // select toutes + delete.
        await tester.tap(find.byTooltip('Tout sélectionner'));
        await tester.pump();
        await tester.tap(find.byTooltip('Supprimer'));
        await tester.pump();

        expect(spy.writes, 1,
            reason: '🔴 AD-43 : aucune écriture pendant les mutations de '
                'brouillon (l\'espion, qui CAPTE, n\'a rien reçu de plus)');

        // commit ⇒ exactement UNE salve de plus.
        await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
        await tester.pump();
        expect(spy.writes, 2,
            reason: '🔴 AC4 : le commit est le SEUL franchissement');
      },
    );
  });

  group('🔴 AC6 — aperçu via ZFlashcardReviewCard (su-2), pas un rendu parallèle',
      () {
    testWidgets('le volet détail construit un ZFlashcardReviewCard',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(
          _harness(_editor(spy: spy, cards: <ZFlashcard>[_card('a')])));
      await tester.pump();
      await tester.tap(find.text('Q'));
      await tester.pump();
      expect(find.byType(ZFlashcardReviewCard), findsOneWidget,
          reason: '🔴 l\'aperçu RÉUTILISE su-2 (jamais un rendu parallèle)');
    });
  });

  group('🔴 AC7 — champ commun via me-1 (applyCommonField), défaut false CONSOMMÉ',
      () {
    testWidgets(
      'appliquer un champ commun mute la liste EN MÉMOIRE et CONSERVE la sélection',
      (tester) async {
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(
          _editor(
            spy: spy,
            cards: <ZFlashcard>[_card('a'), _card('b')],
            commonFields: _commonFields,
          ),
        ));
        await tester.pump();

        // Sélectionne tout.
        await tester.tap(find.byTooltip('Tout sélectionner'));
        await tester.pump();

        // Saisit une valeur commune et applique.
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-multi-editor-common-value')),
            'dossier-x');
        await tester.tap(
            find.byKey(const ValueKey<String>('z-multi-editor-apply-common')));
        await tester.pump();

        // clearSucceededFromSelection défaut false ⇒ sélection CONSERVÉE.
        expect(find.text('2 sélectionnée(s)'), findsOneWidget,
            reason: '🔴 défaut false CONSOMMÉ : la sélection reste pour un 2ᵉ champ');
        // Rien persisté par l'application (in-memory).
        expect(spy.writes, 0);
      },
    );
  });

  group('🔴 AC10/SM-1 — taper n\'incrémente QUE le champ, jamais la liste', () {
    testWidgets(
      '🔴 taper dans la question ⇒ 0 rebuild de ligne ; ajouter ⇒ rebuild (sonde)',
      (tester) async {
        final spy = _CommitSpy();
        var rowBuilds = 0;
        await tester.pumpWidget(_harness(
          _editor(
            spy: spy,
            cards: <ZFlashcard>[_card('a'), _card('b')],
            rowContentBuilder: (context, card) {
              rowBuilds++;
              return Text(card.question, textAlign: TextAlign.start);
            },
          ),
        ));
        await tester.pump();
        expect(rowBuilds, greaterThan(0),
            reason: 'sonde : les lignes sont RÉELLEMENT rendues via le slot');

        // Focalise la 1re carte (volet détail).
        await tester.tap(find.text('Q').first);
        await tester.pump();

        final controllerBefore = tester
            .widget<TextField>(find.byKey(const ValueKey<String>('z-card-question')))
            .controller;

        rowBuilds = 0;
        // Frappe soutenue dans le champ question.
        for (final s in <String>['H', 'He', 'Hel', 'Hell', 'Hello']) {
          await tester.enterText(
              find.byKey(const ValueKey<String>('z-card-question')), s);
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(rowBuilds, 0,
            reason: '🔴 SM-1 : éditer un champ ne reconstruit JAMAIS la liste '
                '(orderKeys inchangé)');

        final controllerAfter = tester
            .widget<TextField>(find.byKey(const ValueKey<String>('z-card-question')))
            .controller;
        expect(identical(controllerBefore, controllerAfter), isTrue,
            reason: '🔴 AD-2 : TextEditingController STABLE (jamais recréé)');

        // La sonde est VIVANTE : une mutation structurelle reconstruit bien.
        rowBuilds = 0;
        await tester.tap(find.byKey(ZMultiFlashcardEditor.addButtonKey));
        await tester.pump();
        expect(rowBuilds, greaterThan(0),
            reason: '🔴 ajouter une carte reconstruit la liste — preuve que le '
                '« 0 » ci-dessus est significatif (sonde branchée)');
      },
    );
  });

  group('AC9 — robustesse (états dégénérés + échecs, jamais de throw)', () {
    testWidgets('liste vide ⇒ état vide rendu, aucun throw', (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(_editor(spy: spy)));
      await tester.pump();
      expect(find.text('Aucune carte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('commit qui ÉCHOUE ⇒ message d\'échec, rien perdu', (tester) async {
      final spy = _CommitSpy()..fail = true;
      await tester.pumpWidget(
          _harness(_editor(spy: spy, cards: <ZFlashcard>[_card('a')])));
      await tester.pump();
      await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
      await tester.pump();
      expect(find.textContaining('Échec'), findsOneWidget);
      // Carte toujours là (liste inchangée).
      expect(find.text('Q'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1 carte · N cartes : rendu défini', (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(_editor(
          spy: spy,
          cards: <ZFlashcard>[_card('a'), _card('b', q: 'Q2'), _card('c', q: 'Q3')])));
      await tester.pump();
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 BUG-1 — un champ commun appliqué à la carte FOCALISÉE survit à la frappe',
      () {
    testWidgets(
      '🔴 focaliser A → appliquer folderId → RETAPER la question ⇒ folderId '
      'conservé (pas écrasé à null depuis un snapshot figé)',
      (tester) async {
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(
          _editor(
            spy: spy,
            // folderId == null au départ (jamais renseigné par _card).
            cards: <ZFlashcard>[_card('a')],
            commonFields: _commonFields,
          ),
          size: const Size(1000, 800),
        ));
        await tester.pump();

        // Focalise A (ouvre le volet détail).
        await tester.tap(find.text('Q'));
        await tester.pump();
        // Sélectionne A pour l'application du champ commun.
        await tester.tap(find.byTooltip('Tout sélectionner'));
        await tester.pump();

        // Applique folderId = 'dossier-x' HORS formulaire (panneau champ commun).
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-multi-editor-common-value')),
            'dossier-x');
        await tester.tap(
            find.byKey(const ValueKey<String>('z-multi-editor-apply-common')));
        await tester.pump();

        // PUIS une frappe DANS le formulaire de A (la question).
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-card-question')), 'Q!');
        await tester.pump();

        // Commit ⇒ la salve doit porter folderId ET la question éditée.
        await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
        await tester.pump();

        expect(spy.payloads.last.single.folderId, 'dossier-x',
            reason: '🔴 BUG-1 : la valeur commune appliquée hors formulaire ne '
                'doit PAS être revertée à null par la frappe suivante');
        expect(spy.payloads.last.single.question, 'Q!',
            reason: 'la frappe est bien prise en compte');
      },
    );
  });

  group('🔴 FIX-5 — éditer un champ de carte atteint la liste committée', () {
    testWidgets('🔴 taper dans z-card-question ⇒ le commit porte la question éditée',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(
          _editor(spy: spy, cards: <ZFlashcard>[_card('a')])));
      await tester.pump();
      await tester.tap(find.text('Q'));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey<String>('z-card-question')), 'Éditée');
      await tester.pump();
      await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
      await tester.pump();
      expect(spy.payloads.last.single.question, 'Éditée',
          reason: '🔴 FIX-5 : l\'édition de champ DOIT atteindre le lot committé '
              '(neutraliser onChanged du champ fait rougir)');
    });
  });

  group('🔴 FIX-6 — la mutation in-memory du champ commun est ASSERTÉE', () {
    testWidgets(
      '🔴 appliquer folderId ⇒ le commit porte folderId sur les cartes sélectionnées',
      (tester) async {
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(_editor(
          spy: spy,
          cards: <ZFlashcard>[_card('a'), _card('b')],
          commonFields: _commonFields,
        )));
        await tester.pump();
        await tester.tap(find.byTooltip('Tout sélectionner'));
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-multi-editor-common-value')),
            'dossier-x');
        await tester.tap(
            find.byKey(const ValueKey<String>('z-multi-editor-apply-common')));
        await tester.pump();
        // Prouve que la mutation a bien atteint les cartes (pas seulement le rapport).
        await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
        await tester.pump();
        expect(spy.payloads.last.map((c) => c.folderId),
            everyElement('dossier-x'),
            reason: '🔴 FIX-6 : `applyCommonField`+`writeRootInMemory` MUTENT '
                'réellement les cartes (neutraliser writeRootInMemory fait rougir)');
      },
    );
  });

  group('🔴 BUG-2 — un onCommit qui THROW ⇒ message d\'échec, aucune exception', () {
    testWidgets(
      '🔴 onCommit lève ⇒ message commitFailed rendu, tester.takeException null',
      (tester) async {
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          onCommit: (cards) async => throw StateError('boom'),
          labels: _labels,
          initialCards: <ZFlashcard>[_card('a')],
        )));
        await tester.pump();
        await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
        await tester.pump();
        expect(find.text('Échec'), findsOneWidget,
            reason: '🔴 BUG-2 : l\'échec (throw capté) est RAPPORTÉ à l\'écran');
        expect(tester.takeException(), isNull,
            reason: '🔴 BUG-2/AD-10 : aucune exception ne traverse la surface');
      },
    );
  });

  group('🔴 BUG-3 — commit ré-entrant : double-tap = UNE seule salve', () {
    testWidgets('🔴 taper commit DEUX fois avant résolution ⇒ writes == 1',
        (tester) async {
      var writes = 0;
      final completer = Completer<ZResult<Unit>>();
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        onCommit: (cards) {
          writes++;
          return completer.future; // reste EN VOL jusqu'à résolution manuelle.
        },
        labels: _labels,
        initialCards: <ZFlashcard>[_card('a')],
      )));
      await tester.pump();

      // Deux taps AVANT que le premier commit ne se résolve.
      await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
      await tester.pump();

      expect(writes, 1,
          reason: '🔴 BUG-3 : la garde de ré-entrance empêche la 2ᵉ salve');

      // Résout le commit en vol (évite un timer pendant).
      completer.complete(right(unit));
      await tester.pump();
    });
  });
}
