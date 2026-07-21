// SU-9/AC1/AC9/AC10/AC11/AC13 — feuille de génération, point d'entrée conditionnel,
// aperçu via ZFlashcardReviewCard, confirmation de tags, SM-1.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _messages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR',
  emptyResult: 'VIDE',
);

const _labels = ZFlashcardGenerationLabels(
  contentLabel: 'Contenu',
  contentHint: 'Coller le texte',
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
  tagConfirmTitle: 'Tags proposés',
  tagConfirmApply: 'Confirmer',
  tagConfirmCancel: 'Annuler',
  tagInputLabel: 'Nom du tag',
  tagInputHint: 'Ajouter un tag',
  tagAddSemanticLabel: 'Ajouter le tag',
);

class _FakePort implements ZFlashcardGenerationPort {
  _FakePort(this.responder);
  final Future<ZResult<List<ZFlashcard>>> Function(ZFlashcardGenerationRequest) responder;
  ZFlashcardGenerationRequest? lastRequest;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest r) {
    lastRequest = r;
    return responder(r);
  }
}

ZFlashcard _card(String id) => ZFlashcard(id: id, question: 'Q$id', answer: 'A$id');

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, height: 1400, child: child)),
    );

List<ZGenerationSourceOption> _sources() => <ZGenerationSourceOption>[
      const ZGenerationSourceOption(label: 'Texte libre'),
      ZGenerationSourceOption(
        label: 'Article',
        provenance: ZCustomSource('article', const <String, dynamic>{'id': '9'}),
      ),
    ];

void main() {
  group('AC11 — point d\'entrée conditionnel (absent sans port)', () {
    testWidgets('sans port (ni param ni scope) ⇒ option ABSENTE (jamais grisée)',
        (tester) async {
      await tester.pumpWidget(_harness(
        ZFlashcardGenerationLauncher(label: 'Générer avec IA', onPressed: (_) {}),
      ));
      expect(find.byKey(const ValueKey<String>('z-generation-launch')), findsNothing);
    });

    testWidgets('avec port en paramètre ⇒ option PRÉSENTE', (tester) async {
      final port = _FakePort((_) async => right(<ZFlashcard>[_card('a')]));
      await tester.pumpWidget(_harness(
        ZFlashcardGenerationLauncher(
            label: 'Générer avec IA', port: port, onPressed: (_) {}),
      ));
      expect(
          find.byKey(const ValueKey<String>('z-generation-launch')), findsOneWidget);
    });

    testWidgets('avec port via ZFlashcardGenerationScope ⇒ option PRÉSENTE',
        (tester) async {
      final port = _FakePort((_) async => right(<ZFlashcard>[_card('a')]));
      ZFlashcardGenerationPort? received;
      await tester.pumpWidget(_harness(
        ZFlashcardGenerationScope(
          port: port,
          child: ZFlashcardGenerationLauncher(
            label: 'Générer avec IA',
            onPressed: (p) => received = p,
          ),
        ),
      ));
      final btn = find.byKey(const ValueKey<String>('z-generation-launch'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      expect(received, same(port), reason: 'le port résolu est passé à l\'app');
    });
  });

  group('AC1/AC10 — génération : requête d\'union + aperçu via ReviewCard', () {
    testWidgets('la requête porte source (provenance), count, distribution',
        (tester) async {
      final port = _FakePort((_) async => right(<ZFlashcard>[_card('a')]));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      // Sélectionne la source « Article » (index 1) puis génère.
      await tester.tap(find.text('Article'));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey<String>('z-generation-content')), 'mon texte');
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();

      final req = port.lastRequest!;
      expect(req.content, 'mon texte');
      expect(req.provenance, isA<ZCustomSource>());
      expect(req.count, inInclusiveRange(1, 50));
      expect(req.typesDistribution, isNotNull);
      expect(req.typesDistribution!.values.fold<int>(0, (a, b) => a + b), req.count);
    });

    testWidgets('🔴 l\'aperçu passe par ZFlashcardReviewCard (jamais parallèle)',
        (tester) async {
      final port = _FakePort((_) async =>
          right(<ZFlashcard>[_card('a'), _card('b')]));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ZFlashcardPreview), findsNWidgets(2));
      expect(find.byType(ZFlashcardReviewCard), findsNWidgets(2),
          reason: 'chaque carte rendue par su-2, pas un rendu maison');
    });

    testWidgets('cartes malformées → rendu DÉFENSIF (aucun throw)', (tester) async {
      final port = _FakePort((_) async =>
          right(<ZFlashcard>[const ZFlashcard(question: '')]));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZFlashcardReviewCard), findsOneWidget);
    });

    testWidgets('échec du port → message affiché, saisie préservée', (tester) async {
      final port = _FakePort((_) async => left(const ZServerFailure('hors ligne')));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      await tester.enterText(
          find.byKey(const ValueKey<String>('z-generation-content')), 'gardé');
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text('hors ligne'), findsOneWidget);
      expect(find.text('gardé'), findsOneWidget, reason: 'saisie préservée (AC7)');
    });
  });

  group('AC9 — confirmation de tags (réutilise ZTagEditor)', () {
    testWidgets('aperçu → confirmer → ZTagEditor présent, tags pré-cochés',
        (tester) async {
      final port = _FakePort((_) async => right(<ZFlashcard>[_card('a')]));
      List<ZFlashcard>? handed;
      List<ZFlashcardTag>? handedTags;
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
        suggestedTags: const <ZSuggestedTag>[ZSuggestedTag(title: 'algèbre')],
        onGenerated: (c, t) {
          handed = c;
          handedTags = t;
        },
      )));
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();
      await tester.pump();
      final proceed = find.byKey(const ValueKey<String>('z-generation-proceed'));
      await tester.ensureVisible(proceed);
      await tester.pump();
      await tester.tap(proceed);
      await tester.pump();

      expect(find.byType(ZTagEditor), findsOneWidget,
          reason: 'réutilise l\'éditeur existant, jamais un second');
      // Le tag suggéré est PRÉ-COCHÉ (rendu comme puce d'un tag retenu).
      expect(find.text('algèbre'), findsWidgets);

      final apply = find.byKey(const ValueKey<String>('z-tag-confirm-apply'));
      await tester.ensureVisible(apply);
      await tester.pump();
      await tester.tap(apply);
      await tester.pump();
      expect(handed, isNotNull);
      expect(handed!.single.id, isNull, reason: 'id reste null (AC6/AC9)');
      expect(handedTags!.map((t) => t.title), contains('algèbre'));
    });
  });

  group('AC13 — SM-1 : réactivité granulaire (controller stable, focus)', () {
    testWidgets('taper dans un champ ne perd pas le focus', (tester) async {
      final port = _FakePort((_) async => right(<ZFlashcard>[_card('a')]));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      final field = find.byKey(const ValueKey<String>('z-generation-instructions'));
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, 'consigne');
      await tester.pump();
      final editable = find.descendant(
          of: field, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue,
          reason: 'aucune perte de focus (SM-1/AD-2)');
    });

    testWidgets(
        '🔴 saisie préservée à travers un rebuild COMPLET (controller stable)',
        (tester) async {
      // Un échec fait passer le statut → failed ⇒ le ListenableBuilder externe
      // reconstruit TOUTE la feuille. Si le controller était créé dans build(),
      // le texte serait perdu. Il est en initState ⇒ préservé.
      final port = _FakePort((_) async => left(const ZServerFailure('nope')));
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: _sources(),
      )));
      await tester.enterText(
          find.byKey(const ValueKey<String>('z-generation-instructions')),
          'ne me perds pas');
      await tester.tap(find.byKey(const ValueKey<String>('z-generation-submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text('ne me perds pas'), findsOneWidget,
          reason: 'TextEditingController stable (jamais recréé au rebuild)');
    });
  });
}
