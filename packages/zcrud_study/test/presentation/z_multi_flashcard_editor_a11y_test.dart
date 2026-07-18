// me-2 — a11y : cibles ≥ 48 dp + canal Semantics (pas seulement le rendu) + pas
// de double annonce. Leçon su-6 : balayer TOUS les contrôles, pas un échantillon.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart'
    show EditionFieldType, Unit, ZFieldSpec, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const double _kMinTapTarget = 48.0;

Future<ZResult<Unit>> _noopCommit(List<ZFlashcard> cards) async => right(unit);

class _FakeGenPort implements ZFlashcardGenerationPort {
  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
          ZFlashcardGenerationRequest r) async =>
      right(<ZFlashcard>[]);
}

const _genLabels = ZFlashcardGenerationLabels(
  contentLabel: 'Contenu',
  contentHint: 'Coller',
  countLabel: 'Nombre',
  instructionsLabel: 'Instructions',
  instructionsHint: 'Facultatif',
  modelIdLabel: 'Modèle',
  modelIdHint: 'Optionnel',
  sourceLabel: 'Source',
  generateLabel: 'Générer',
  generatingLabel: 'Génération…',
  proceedToTagsLabel: 'Confirmer les tags',
  previewTitle: 'Aperçu',
  typeLabels: <ZFlashcardType, String>{},
  tagConfirmTitle: 'Tags',
  tagConfirmApply: 'Confirmer',
  tagConfirmCancel: 'Annuler',
  tagInputLabel: 'Nom du tag',
  tagInputHint: 'Ajouter',
  tagAddSemanticLabel: 'Ajouter le tag',
);

const _genMessages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR',
  emptyResult: 'VIDE',
);

ZMultiFlashcardGeneration _gen() => ZMultiFlashcardGeneration(
      port: _FakeGenPort(),
      messages: _genMessages,
      labels: _genLabels,
      sources: const <ZGenerationSourceOption>[
        ZGenerationSourceOption(label: 'Texte libre'),
      ],
      launcherLabel: 'Générer avec IA',
    );

final _commonFields = <ZMultiFlashcardCommonField>[
  ZMultiFlashcardCommonField(
    spec: const ZFieldSpec(name: 'folder_id', type: EditionFieldType.text),
    label: 'Dossier',
    apply: (card, value) => card.copyWith(folderId: value),
  ),
];

final _labels = ZMultiFlashcardEditorLabels(
  addCardLabel: 'Ajouter',
  deleteSelectedLabel: 'Supprimer',
  commitLabel: 'Enregistrer',
  applyCommonLabel: 'Appliquer',
  selectAllLabel: 'Tout sélectionner',
  emptyState: 'Aucune carte',
  detailPlaceholder: 'Sélectionner',
  backToListLabel: 'Retour',
  questionLabel: 'Question',
  answerLabel: 'Réponse',
  explanationLabel: 'Explication',
  hintLabel: 'Indice',
  typeLabel: 'Type',
  commonFieldPickerLabel: 'Champ',
  commonValueLabel: 'Valeur',
  previewTitle: 'Aperçu',
  commitSucceeded: 'OK',
  commitFailed: 'Échec',
  selectCardSemanticLabel: (i) => 'Sélectionner la carte $i',
  countLabelBuilder: (n) => '$n sélectionnée(s)',
  applyReportBuilder: (r) => 'Appliqué ${r.succeededCount}',
);

ZFlashcard _card(String id) => ZFlashcard(id: id, question: 'Q$id');

Widget _harness({
  Size size = const Size(1000, 800),
  bool full = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: ZMultiFlashcardEditor(
            onCommit: _noopCommit,
            labels: _labels,
            initialCards: <ZFlashcard>[_card('a'), _card('b'), _card('c')],
            // FIX-7 : câble génération + champs communs pour MESURER le launcher,
            // le champ commun et le dropdown de type (leçon su-6 : TOUS les
            // contrôles, pas un échantillon).
            generation: full ? _gen() : null,
            commonFields: full ? _commonFields : const <ZMultiFlashcardCommonField>[],
          ),
        ),
      ),
    );

void main() {
  group('🔴 AC10/AD-13 — cibles ≥ 48 dp sur TOUS les contrôles', () {
    testWidgets('boutons d\'action (ajouter, enregistrer) ≥ 48 dp',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();
      for (final key in <ValueKey<String>>[
        ZMultiFlashcardEditor.addButtonKey,
        ZMultiFlashcardEditor.commitButtonKey,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 $key : ${size.height} dp < 48 dp');
      }
    });

    testWidgets('barre de lot : « tout sélectionner » et « supprimer » ≥ 48 dp',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();
      for (final tip in <String>['Tout sélectionner', 'Supprimer']) {
        final size = tester.getSize(find.byTooltip(tip));
        expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 « $tip » : ${size.height} dp < 48 dp');
        expect(size.width, greaterThanOrEqualTo(_kMinTapTarget));
      }
    });

    testWidgets(
      '🔴 FIX-7 : launcher de génération + champ commun ≥ 48 dp (harness complet)',
      (tester) async {
        await tester.pumpWidget(_harness(full: true));
        await tester.pump();
        // Launcher de génération (cible tappable, pas seulement son texte).
        final launcher = tester
            .getSize(find.byKey(const ValueKey<String>('z-generation-launch')));
        expect(launcher.height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 FIX-7 : le launcher de génération < 48 dp (intappable)');
        // Champ commun (valeur) : cible de saisie ≥ 48 dp.
        final commonValue = tester.getSize(
            find.byKey(const ValueKey<String>('z-multi-editor-common-value')));
        expect(commonValue.height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 FIX-7 : le champ de valeur commune < 48 dp');
      },
    );

    testWidgets('🔴 FIX-7 : dropdown de TYPE (volet détail) ≥ 48 dp',
        (tester) async {
      await tester.pumpWidget(_harness(full: true));
      await tester.pump();
      // Ouvre le volet détail (focalise une carte) pour exposer le dropdown type.
      await tester.tap(find.text('Qa'));
      await tester.pump();
      final typeSize =
          tester.getSize(find.byKey(const ValueKey<String>('z-card-type')));
      expect(typeSize.height, greaterThanOrEqualTo(_kMinTapTarget),
          reason: '🔴 FIX-7 : le sélecteur de type < 48 dp (intappable)');
    });

    testWidgets('CHAQUE ligne de sélection ≥ 48 dp de haut', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3),
          reason: 'sonde : les 3 cartes ont leur case (pas un échantillon)');
      for (var i = 0; i < 3; i++) {
        final rowHeight = tester
            .getSize(find
                .ancestor(of: checkboxes.at(i), matching: find.byType(ConstrainedBox))
                .first)
            .height;
        expect(rowHeight, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 ligne $i : ${rowHeight} dp < 48 dp (intappable au doigt)');
      }
    });
  });

  group('🔴 AC10 — canal Semantics (a11y honnête, pas seulement le rendu)', () {
    testWidgets('la case de sélection porte son libellé INJECTÉ, annoncé UNE fois',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pump();

      // Le libellé injecté atteint bien le canal Semantics.
      expect(find.bySemanticsLabel(RegExp('Sélectionner la carte 1')),
          findsOneWidget,
          reason: '🔴 le libellé a11y INJECTÉ de la case doit être atteignable');

      // Pas de double annonce : le libellé n'apparaît qu'UNE fois dans le nœud.
      final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Sélectionner la carte 1')));
      final announced = node.getSemanticsData().label;
      final occurrences =
          RegExp('Sélectionner la carte 1').allMatches(announced).length;
      expect(occurrences, 1,
          reason: '🔴 « Sélectionner la carte 1 » annoncé $occurrences fois '
              '(fusion réelle : « ${announced.replaceAll('\n', ' / ')} »)');
      handle.dispose();
    });

    testWidgets(
      '🔴 FIX-8 : la ligne expose DEUX actionnables distincts (bascule + ouverture)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness());
        await tester.pump();

        // Bascule de sélection : le checkbox porte son état cochable + le tap.
        final cb = tester.getSemantics(find.byType(Checkbox).first);
        expect(cb, containsSemantics(hasCheckedState: true, hasTapAction: true),
            reason: '🔴 la bascule de sélection survit');

        // Ouverture (navigate) : un nœud DISTINCT (le résumé de ligne) porte une
        // action de tap.
        final open = tester.getSemantics(find.text('Qa'));
        expect(open, containsSemantics(hasTapAction: true),
            reason: '🔴 l\'ouverture est une action de tap');

        // 🔴 FIX-8 — les DEUX actionnables sont des nœuds SÉPARÉS : avec
        // `MergeSemantics`, la case et l'ouverture fusionnaient en UN SEUL nœud
        // (une seule action de tap survivait). L'identité des nœuds le prouve.
        expect(cb.id, isNot(open.id),
            reason: '🔴 FIX-8 : bascule et ouverture DOIVENT être deux nœuds '
                'sémantiques distincts (MergeSemantics les collapse en un seul)');
        handle.dispose();
      },
    );

    testWidgets('les boutons d\'action sont annoncés comme BOUTON', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(ZMultiFlashcardEditor.commitButtonKey)),
        containsSemantics(isButton: true, isEnabled: true),
      );
      handle.dispose();
    });
  });

  group('AC10 — Reduce Motion (AD-13, délégué à su-2)', () {
    testWidgets('disableAnimations ⇒ l\'éditeur rend sans throw', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: ZMultiFlashcardEditor(
                onCommit: _noopCommit,
                labels: _labels,
                initialCards: <ZFlashcard>[_card('a')],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Qa'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZFlashcardReviewCard), findsOneWidget);
    });
  });
}
