// me-2 / AC5 — intégration du flux de génération su-9 : les cartes générées sont
// AJOUTÉES à la liste de travail (jamais persistées). L'espion de commit est
// prouvé captant (témoin) avant l'assertion « 0 écriture ».
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZServerFailure, Unit, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

class _CommitSpy {
  int writes = 0;
  Future<ZResult<Unit>> call(List<ZFlashcard> cards) async {
    writes++;
    return right(unit);
  }
}

class _FakeGenPort implements ZFlashcardGenerationPort {
  _FakeGenPort(this.responder);
  final Future<ZResult<List<ZFlashcard>>> Function(ZFlashcardGenerationRequest)
      responder;
  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
          ZFlashcardGenerationRequest r) =>
      responder(r);
}

const _genMessages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR',
  emptyResult: 'VIDE',
);

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
  selectCardSemanticLabel: (i) => 'Sélectionner $i',
  countLabelBuilder: (n) => '$n sélectionnée(s)',
  applyReportBuilder: (r) => 'Appliqué ${r.succeededCount}',
);

ZMultiFlashcardGeneration _gen(ZFlashcardGenerationPort port) =>
    ZMultiFlashcardGeneration(
      port: port,
      messages: _genMessages,
      labels: _genLabels,
      sources: const <ZGenerationSourceOption>[
        ZGenerationSourceOption(label: 'Texte libre'),
      ],
      launcherLabel: 'Générer avec IA',
    );

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1000, height: 1400, child: child),
      ),
    );

void main() {
  testWidgets('AC5 — sans configuration de génération, le launcher est ABSENT',
      (tester) async {
    final spy = _CommitSpy();
    await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
      onCommit: spy.call,
      labels: _labels,
    )));
    await tester.pump();
    expect(find.text('Générer avec IA'), findsNothing,
        reason: 'AC5/AC11 : option ABSENTE (jamais grisée) sans port');
  });

  testWidgets(
    '🔴 AC5 — le lot généré est AJOUTÉ à la liste de travail, RIEN persisté',
    (tester) async {
      final spy = _CommitSpy();
      // Témoin : l'espion capte réellement.
      await spy.call(const <ZFlashcard>[]);
      expect(spy.writes, 1);

      final port = _FakeGenPort((_) async => right(<ZFlashcard>[
            ZFlashcard(question: 'G1'),
            ZFlashcard(question: 'G2'),
          ]));
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        onCommit: spy.call,
        labels: _labels,
        generation: _gen(port),
      )));
      await tester.pump();

      // Ouvre la feuille de génération.
      await tester.tap(find.text('Générer avec IA'));
      await tester.pumpAndSettle();

      // Génère (le port répond 2 cartes).
      final submit = find.byKey(const ValueKey<String>('z-generation-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      // Aperçu → confirmation des tags → handoff onGenerated → addGenerated.
      final proceed = find.byKey(const ValueKey<String>('z-generation-proceed'));
      await tester.ensureVisible(proceed);
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      final apply = find.byKey(const ValueKey<String>('z-tag-confirm-apply'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      // La liste de travail a grandi de 2 (les 2 cartes générées).
      expect(find.text('G1'), findsWidgets);
      expect(find.text('G2'), findsWidgets);
      // AUCUNE persistance (l'espion, qui capte, n'a rien reçu de plus).
      expect(spy.writes, 1,
          reason: '🔴 AD-43 : générer AJOUTE au brouillon, ne persiste RIEN');
    },
  );

  testWidgets(
      '🔴 LOW#13 — génération qui retourne Left ⇒ brouillon intact, 0 écriture, '
      'aucune exception', (tester) async {
    final spy = _CommitSpy();
    // Témoin : l'espion capte réellement.
    await spy.call(const <ZFlashcard>[]);
    expect(spy.writes, 1);
    final port = _FakeGenPort(
        (_) async => left(const ZServerFailure('port en panne')));
    await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
      onCommit: spy.call,
      labels: _labels,
      initialCards: <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q')],
      generation: _gen(port),
    )));
    await tester.pump();
    await tester.tap(find.text('Générer avec IA'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
    await tester.pump();
    await tester.pump();
    // Left ⇒ le message de la ZFailure (rendu lisible), aucune carte ajoutée.
    expect(find.text('port en panne'), findsOneWidget,
        reason: '🔴 LOW#13 : un Left de génération affiche la cause (failure.message)');
    expect(spy.writes, 1,
        reason: '🔴 aucune persistance (l\'espion, qui capte, n\'a rien reçu)');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC9 — génération qui ÉCHOUE ⇒ liste de travail intacte',
      (tester) async {
    final spy = _CommitSpy();
    final port = _FakeGenPort((_) async => right(<ZFlashcard>[]));
    await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
      onCommit: spy.call,
      labels: _labels,
      initialCards: <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q')],
      generation: _gen(port),
    )));
    await tester.pump();
    await tester.tap(find.text('Générer avec IA'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
    await tester.pump();
    await tester.pump();
    // Right([]) ⇒ message d'échec, aucune carte ajoutée. Ferme la feuille.
    expect(find.text('VIDE'), findsOneWidget);
    expect(spy.writes, 0);
  });
}
