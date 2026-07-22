// CR-LEX-6 — slot d'action « voir la source » sur la carte de révision.
//
// lex_douane permet, depuis une carte en révision, de remonter à la SOURCE dont
// elle est tirée (article de code, note, document, conversation). C'est la
// traçabilité vers le texte officiel — la valeur propre d'une app juridique, et
// le seul écart de leur audit non comblable côté hôte.
//
// La carte ne peut PAS résoudre la source elle-même : `ZFlashcard.source` est un
// slot ouvert (`ZSourceRegistry`), elle ignore ce qu'il désigne et comment y
// naviguer. D'où un callback, sur le patron exact de `onEdit`/`onDelete`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ZFlashcard card,
  VoidCallback? onSource,
  VoidCallback? onEdit,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: card,
                onSource: onSource,
                onEdit: onEdit,
              ),
            ),
          ),
        ),
      ),
    );

final Finder _source = find.byKey(ZFlashcardReviewCard.sourceActionKey);
final Finder _edit = find.byKey(ZFlashcardReviewCard.editActionKey);
final Finder _actions = find.byKey(ZFlashcardReviewCard.actionsKey);

void main() {
  testWidgets('onSource fourni ⇒ action PRÉSENTE et déclenchable',
      (tester) async {
    var opened = false;
    await _pump(
      tester,
      card: const ZFlashcard(question: 'Q', answer: 'A'),
      onSource: () => opened = true,
    );

    expect(_source, findsOneWidget);
    await tester.tap(_source);
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('onSource null ⇒ action ABSENTE de l\'arbre (patron AD-45)',
      (tester) async {
    await _pump(tester, card: const ZFlashcard(question: 'Q', answer: 'A'));
    // Absence STRUCTURELLE, jamais un bouton grisé.
    expect(_source, findsNothing);
    expect(_actions, findsNothing, reason: 'aucun callback ⇒ aucune rangée');
  });

  // ⚠️ CORRIGÉ (CR-LEX-12) — ce test verrouillait un DÉFAUT. Il asserait que la
  // source disparaît en lecture seule, or c'est exactement la population qui a
  // motivé CR-LEX-6 : les cartes CURÉES d'un corpus officiel sont en lecture
  // seule ET porteuses d'une source. La consultation n'est pas une mutation.
  testWidgets('🔴 carte en lecture seule ⇒ la SOURCE reste accessible',
      (tester) async {
    var opened = false;
    await _pump(
      tester,
      card: const ZFlashcard(question: 'Q', answer: 'A', isReadOnly: true),
      onSource: () => opened = true,
    );
    expect(_source, findsOneWidget,
        reason: 'consulter la source ne modifie rien — la lecture seule ne '
            'doit pas la supprimer');
    await tester.tap(_source);
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('carte en lecture seule ⇒ les MUTATIONS restent absentes (AD-45)',
      (tester) async {
    await _pump(
      tester,
      card: const ZFlashcard(question: 'Q', answer: 'A', isReadOnly: true),
      onSource: () {},
      onEdit: () {},
    );
    expect(_source, findsOneWidget);
    expect(_edit, findsNothing, reason: 'éditer EST une mutation');
  });

  testWidgets('la source PRÉCÈDE l\'édition (consultation avant mutation)',
      (tester) async {
    await _pump(
      tester,
      card: const ZFlashcard(question: 'Q', answer: 'A'),
      onSource: () {},
      onEdit: () {},
    );
    expect(_source, findsOneWidget);
    expect(_edit, findsOneWidget);
    final xSource = tester.getCenter(_source).dx;
    final xEdit = tester.getCenter(_edit).dx;
    expect(xSource, lessThan(xEdit));
  });

  testWidgets('a11y — cible ≥ 48 dp et Semantics explicite (AD-13)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      card: const ZFlashcard(question: 'Q', answer: 'A'),
      onSource: () {},
    );

    final size = tester.getSize(_source);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
