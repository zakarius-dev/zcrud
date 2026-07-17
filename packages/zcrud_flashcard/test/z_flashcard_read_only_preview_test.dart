/// AC4 — `isReadOnly` ⇒ aperçu lecture seule, actions **ABSENTES** (SU-2,
/// FR-SU21 aperçu / AD-45).
///
/// ⚠️ **Asserter l'ABSENCE, jamais `enabled == false`** : AD-45 dit littéralement
/// « actions d'édition et de suppression **absentes, jamais désactivées-grisées** ».
/// Un test qui vérifierait `onPressed == null` resterait **vert sur un bouton
/// grisé** — c'est-à-dire précisément sur ce que l'AD interdit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ZFlashcard card,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: card,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
      ),
    );

final Finder _edit = find.byKey(ZFlashcardReviewCard.editActionKey);
final Finder _delete = find.byKey(ZFlashcardReviewCard.deleteActionKey);
final Finder _actions = find.byKey(ZFlashcardReviewCard.actionsKey);

void main() {
  testWidgets(
    'AC4 — isReadOnly: true MÊME AVEC onEdit/onDelete fournis ⇒ actions '
    'ABSENTES de l\'arbre (findsNothing, PAS « désactivées »)',
    (tester) async {
      var edited = false;
      var deleted = false;
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: 'A', isReadOnly: true),
        onEdit: () => edited = true,
        onDelete: () => deleted = true,
      );

      expect(_edit, findsNothing,
          reason: 'action d\'édition présente sur une carte en lecture seule : '
              'si elle est seulement GRISÉE, AD-45 est violé');
      expect(_delete, findsNothing);
      expect(_actions, findsNothing,
          reason: 'la rangée d\'actions doit être absente, pas vide');
      expect(edited, isFalse);
      expect(deleted, isFalse);
    },
  );

  testWidgets(
    'AC4 — isReadOnly: true ⇒ l\'APERÇU reste pleinement fonctionnel '
    '(lecture seule ≠ carte morte)',
    (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: 'A', isReadOnly: true),
        onEdit: () {},
      );
      expect(find.text('Q'), findsOneWidget);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget,
          reason: 'la révélation doit rester possible en lecture seule : c\'est '
              'un APERÇU, pas une désactivation');
    },
  );

  testWidgets(
    'AC4 — isReadOnly: false + callbacks fournis ⇒ actions PRÉSENTES et '
    'TAPABLES (contre-preuve : la garde ci-dessus a du pouvoir)',
    (tester) async {
      var edited = false;
      var deleted = false;
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: 'A'),
        onEdit: () => edited = true,
        onDelete: () => deleted = true,
      );

      expect(_edit, findsOneWidget,
          reason: 'sans ce cas, `findsNothing` ci-dessus resterait vert même si '
              'les actions n\'étaient JAMAIS rendues (garde morte)');
      expect(_delete, findsOneWidget);
      expect(_actions, findsOneWidget);

      await tester.tap(_edit);
      await tester.pump();
      expect(edited, isTrue, reason: 'action présente mais INERTE');

      await tester.tap(_delete);
      await tester.pump();
      expect(deleted, isTrue);
    },
  );

  group('AC4 — les DEUX voies convergent (jamais deux règles)', () {
    testWidgets('callback non fourni ⇒ action absente, exactement comme isReadOnly',
        (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: 'A'),
        onEdit: () {},
        // onDelete non fourni.
      );

      expect(_edit, findsOneWidget);
      expect(_delete, findsNothing,
          reason: 'patron ZItemActionsMenu : « action ABSENTE si non fournie »');
    });

    testWidgets('aucun callback fourni ⇒ AUCUNE rangée d\'actions',
        (tester) async {
      await _pump(tester, card: const ZFlashcard(question: 'Q', answer: 'A'));

      expect(_actions, findsNothing,
          reason: 'une rangée vide serait rendue : l\'absence doit être '
              'structurelle');
      expect(_edit, findsNothing);
      expect(_delete, findsNothing);
    });
  });

  testWidgets(
    'PÉRIMÈTRE — « Dupliquer pour modifier » n\'est PAS de cette story (su-8)',
    (tester) async {
      // FR Coverage Map de l'epic : `FR-SU21 (aperçu) | 1.2` vs `FR-SU21
      // (duplication) | 1.8`. Anticiper su-8 ici la rendrait incohérente.
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: 'A', isReadOnly: true),
        onEdit: () {},
      );

      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.byIcon(Icons.content_copy), findsNothing);
      expect(find.textContaining('upliquer'), findsNothing,
          reason: 'la duplication appartient à su-8 : su-2 livre l\'APERÇU');
    },
  );
}
