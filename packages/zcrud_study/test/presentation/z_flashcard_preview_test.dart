// Tests de `ZFlashcardPreview` (SU-8/AC14 — AD-45).
//
// 🔴 Le test structurant est « le rendu est DÉLÉGUÉ à ZFlashcardReviewCard » :
// une réécriture parallèle passerait tous les tests de contenu (la question
// s'afficherait !) et ne divergerait qu'au premier changement de su-2 — sans
// qu'aucun test ne rougisse.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
    );

void main() {
  group('🔴 AC14/AD-45 — le rendu est DÉLÉGUÉ (jamais un rendu parallèle)', () {
    testWidgets('l\'aperçu MONTE un ZFlashcardReviewCard', (tester) async {
      await tester.pumpWidget(_harness(const ZFlashcardPreview(
        card: ZFlashcard(id: 'c1', question: 'Question ?'),
      )));
      await tester.pump();

      expect(find.byType(ZFlashcardReviewCard), findsOneWidget,
          reason: '🔴 AD-45 : « rendu par ZFlashcardReviewCard — JAMAIS un '
              'rendu parallèle ». Une 2e surface de rendu divergerait de su-2 '
              'en silence (transitions, types de cartes, contraste)');
      expect(find.text('Question ?'), findsOneWidget);
    });

    test('🔴 GARDE DE SOURCE : l\'aperçu ne construit AUCUN rendu propre', () {
      // Le test widget ci-dessus resterait VERT si l'aperçu montait la carte de
      // su-2 **et** doublait son propre affichage à côté. On vérifie donc sur
      // disque que le fichier est bien MINCE PAR CONCEPTION.
      final src = File('lib/src/presentation/z_flashcard_preview.dart')
          .readAsLinesSync()
          .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('///') && !t.startsWith('//');
      }).join('\n');

      expect(src.contains('ZFlashcardReviewCard('), isTrue,
          reason: 'sonde : la délégation doit être RÉELLE');

      // ⚠️ Motifs ANCRÉS sur une frontière de mot (`\b`) : un `contains('Card(')`
      // naïf matcherait… `ZFlashcardReviewCard(` — la délégation elle-même.
      // Une garde qui rougit sur ce qu'elle exige est une garde qui se
      // contredit (et qu'on finit par supprimer).
      for (final banned in <String>[
        'Text',
        'RichText',
        'Column',
        'Row',
        'Card',
        'Stack',
      ]) {
        final pattern = RegExp('\\b$banned\\(');
        expect(pattern.hasMatch(src), isFalse,
            reason: '🔴 « $banned( » dans l\'aperçu ⇒ un rendu PARALLÈLE est '
                'né. Ce widget ne décide QUE des callbacks ; su-2 rend.');
      }
    });
  });

  group('🔴 AC14/AD-45 — carte en LECTURE SEULE : actions ABSENTES', () {
    testWidgets('🔴 isReadOnly ⇒ Modifier et Supprimer ABSENTS du rendu',
        (tester) async {
      var edited = 0;
      var deleted = 0;
      await tester.pumpWidget(_harness(ZFlashcardPreview(
        card: const ZFlashcard(id: 'c1', question: 'Q', isReadOnly: true),
        // 🔴 Les callbacks SONT fournis : c'est le test le plus dur. Une
        // implémentation qui se contenterait de « pas de callback ⇒ pas
        // d'action » resterait verte sans jamais honorer `isReadOnly`.
        onEdit: () => edited++,
        onDelete: () => deleted++,
      )));
      await tester.pump();

      expect(find.byKey(ZFlashcardReviewCard.editActionKey), findsNothing,
          reason: '🔴 ABSENTE, jamais grisée (AD-45)');
      expect(find.byKey(ZFlashcardReviewCard.deleteActionKey), findsNothing);
      expect(edited, 0);
      expect(deleted, 0);
    });

    testWidgets('les callbacks sont FORCÉS à null sur une carte en lecture seule',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardPreview(
        card: const ZFlashcard(id: 'c1', question: 'Q', isReadOnly: true),
        onEdit: () {},
        onDelete: () {},
      )));
      await tester.pump();

      // Assère le CÂBLAGE réel passé à su-2 (pas seulement le rendu) : les deux
      // canaux, jamais un seul.
      final card = tester.widget<ZFlashcardReviewCard>(
          find.byType(ZFlashcardReviewCard));
      expect(card.onEdit, isNull,
          reason: '🔴 l\'aperçu doit FORCER le null — s\'il passait le callback '
              'et comptait sur la garde interne de su-2, la règle vivrait à '
              'DEUX endroits');
      expect(card.onDelete, isNull);
    });

    testWidgets('carte ÉDITABLE + callbacks ⇒ actions PRÉSENTES et ACTIONNÉES',
        (tester) async {
      var edited = 0;
      await tester.pumpWidget(_harness(ZFlashcardPreview(
        card: const ZFlashcard(id: 'c1', question: 'Q'),
        onEdit: () => edited++,
        onDelete: () {},
      )));
      await tester.pump();

      expect(find.byKey(ZFlashcardReviewCard.editActionKey), findsOneWidget,
          reason: '🔴 sonde : sans elle, « actions absentes » serait vrai d\'un '
              'aperçu qui n\'en rend JAMAIS aucune');

      await tester.tap(find.byKey(ZFlashcardReviewCard.editActionKey));
      await tester.pump();
      expect(edited, 1, reason: 'présence ≠ association : le contrôle est ACTIONNÉ');
    });

    testWidgets('carte éditable SANS callback ⇒ action ABSENTE (AD-45)',
        (tester) async {
      await tester.pumpWidget(_harness(_ZPreviewNoCallbacks()));
      await tester.pump();

      expect(find.byKey(ZFlashcardReviewCard.editActionKey), findsNothing,
          reason: 'la règle « null ⇒ absente » vaut aussi hors lecture seule');
    });

    test('actionsAllowed reflète isReadOnly (la voie RÉELLE de build)', () {
      const readOnly =
          ZFlashcardPreview(card: ZFlashcard(question: 'Q', isReadOnly: true));
      const editable = ZFlashcardPreview(card: ZFlashcard(question: 'Q'));
      expect(readOnly.actionsAllowed, isFalse);
      expect(editable.actionsAllowed, isTrue);
    });
  });

  group('AC14/AD-40 — le slot de contenu est transmis à su-2', () {
    testWidgets('contentBuilder injecté ⇒ CONSOMMÉ par la carte', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_harness(ZFlashcardPreview(
        card: const ZFlashcard(id: 'c1', question: 'Brut'),
        contentBuilder: (context, text) {
          calls++;
          return Text('RICHE:$text');
        },
      )));
      await tester.pump();

      expect(calls, greaterThan(0),
          reason: '🔴 un slot transmis mais jamais consommé serait une '
              'fonctionnalité MORTE sur son chemin documenté');
      expect(find.text('RICHE:Brut'), findsOneWidget);
    });
  });

  group('AC19/AD-10 — robustesse', () {
    testWidgets('carte MINIMALE ⇒ aucun throw', (tester) async {
      await tester.pumpWidget(
          _harness(const ZFlashcardPreview(card: ZFlashcard(question: 'Q'))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Q'), findsOneWidget);
    });

    testWidgets('RTL ⇒ aucun throw', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: const ZFlashcardPreview(
                card: ZFlashcard(question: 'سؤال', answer: 'جواب'),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Aperçu SANS callback (carte éditable) — cas « null ⇒ absente ».
class _ZPreviewNoCallbacks extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const ZFlashcardPreview(
        card: ZFlashcard(id: 'c1', question: 'Q'),
      );
}
