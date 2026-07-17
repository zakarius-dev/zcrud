/// AC1 — `ZFlashcardReviewCard` rend les **6 types canoniques**, par le slot
/// AD-40 **réellement branché** (SU-2).
///
/// ⚠️ **Ce fichier SOLDE la dette D5 du code-review de su-1** : le slot
/// `ZFlashcardContentBuilder` n'avait alors **aucun consommateur de production**,
/// si bien qu'un test du slot ne pouvait qu'appeler **sa propre closure locale**
/// — zéro symbole de prod exercé, tautologie pure (supprimée par honnêteté plutôt
/// que verdie). `ZFlashcardReviewCard` **est** ce consommateur : le discriminant
/// « le slot est-il décoratif ? » devient enfin **falsifiable**, parce que la
/// sentinelle traverse ici du **code de production**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Monte la carte dans un hôte minimal (largeur bornée : rendu déterministe).
Future<void> pumpCard(
  WidgetTester tester, {
  required ZFlashcard card,
  ZFlashcardContentBuilder? contentBuilder,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: card,
                contentBuilder: contentBuilder,
              ),
            ),
          ),
        ),
      ),
    );

/// Révèle la réponse (tap sur la carte) et laisse la transition s'achever.
Future<void> reveal(WidgetTester tester) async {
  await tester.tap(find.byType(ZFlashcardReviewCard));
  await tester.pumpAndSettle();
}

void main() {
  group('AC1 — rendu adapté aux 6 types canoniques', () {
    testWidgets('multipleChoice — question + choix ; réponse marque le correct',
        (tester) async {
      const card = ZFlashcard(
        question: 'Capitale du Togo ?',
        type: ZFlashcardType.multipleChoice,
        choices: <ZChoice>[
          ZChoice(content: 'Lomé', isCorrect: true),
          ZChoice(content: 'Accra'),
        ],
      );
      await pumpCard(tester, card: card);

      // Face question : l'énoncé ET les choix, sans révéler le correct.
      expect(find.text('Capitale du Togo ?'), findsOneWidget);
      expect(find.text('Lomé'), findsOneWidget);
      expect(find.text('Accra'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing,
          reason: 'la face QUESTION ne doit jamais révéler le bon choix');

      await reveal(tester);

      // Face réponse : le/les `isCorrect` marqués — canal NON-COLORÉ (icône).
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Lomé'), findsOneWidget);
    });

    testWidgets('trueOrFalse — réponse dérivée de isTrue (l10n)', (tester) async {
      const card = ZFlashcard(
        question: 'Le Togo est en Afrique.',
        type: ZFlashcardType.trueOrFalse,
        isTrue: true,
      );
      await pumpCard(tester, card: card);
      expect(find.text('Le Togo est en Afrique.'), findsOneWidget);

      await reveal(tester);
      expect(find.text('Vrai'), findsOneWidget);
    });

    testWidgets('trueOrFalse — isTrue == false rend « Faux »', (tester) async {
      const card = ZFlashcard(
        question: 'Le Togo est en Asie.',
        type: ZFlashcardType.trueOrFalse,
        isTrue: false,
      );
      await pumpCard(tester, card: card);
      await reveal(tester);
      expect(find.text('Faux'), findsOneWidget);
    });

    // Les 4 types à réponse libre partagent la MÊME branche de la table de
    // rendu : chacun est couvert, aucun n'est supposé.
    for (final type in <ZFlashcardType>[
      ZFlashcardType.openQuestion,
      ZFlashcardType.exercise,
      ZFlashcardType.fillBlank,
      ZFlashcardType.shortAnswer,
    ]) {
      testWidgets('${type.name} — question puis réponse libre', (tester) async {
        final card = ZFlashcard(
          question: 'Énoncé ${type.name}',
          type: type,
          answer: 'Réponse ${type.name}',
        );
        await pumpCard(tester, card: card);
        expect(find.text('Énoncé ${type.name}'), findsOneWidget);
        expect(find.text('Réponse ${type.name}'), findsNothing,
            reason: 'la réponse ne doit pas être visible avant révélation');

        await reveal(tester);
        expect(find.text('Réponse ${type.name}'), findsOneWidget);
      });
    }

    test('les 6 valeurs de ZFlashcardType sont bien couvertes ci-dessus', () {
      // Garde d'EXHAUSTIVITÉ du fichier de test lui-même : si une 7ᵉ valeur
      // apparaît, ce test rougit et force l'ajout d'un cas de rendu — sans lui,
      // le nouveau type serait rendu par une branche jamais exercée.
      expect(ZFlashcardType.values, hasLength(6));
    });
  });

  group('🔴 D3 — la face DÉBORDE-t-elle ? (parité lex_ui : SingleChildScrollView)',
      () {
    // ⚠️ Le débordement avait été diagnostiqué « artefact de harnais » et le
    // test AJUSTÉ plutôt que le code. L'exécution réfute ce diagnostic : un QCM
    // ORDINAIRE (8 choix + explication) à 800×600 débordait de 200 px, et un
    // contenu long SANS aucun markdown de 3436 px. Ni le markdown ni le harnais
    // n'étaient en cause — c'est ce que verrait l'utilisateur.
    //
    // La source de parité citée par la story pose exactement le mécanisme qui
    // manquait : `lex_ui/…/study/session_flashcard_view.dart:247` →
    // `SingleChildScrollView`.

    testWidgets(
      'un QCM ORDINAIRE (8 choix + explication) à 800×600 ne déborde PAS',
      (tester) async {
        final card = ZFlashcard(
          question: 'Une question de QCM parfaitement ordinaire ?',
          type: ZFlashcardType.multipleChoice,
          choices: <ZChoice>[
            for (var i = 0; i < 8; i++)
              ZChoice(content: 'Choix numéro $i', isCorrect: i == 3),
          ],
          explanation: 'Une explication de quelques lignes, comme en produit '
              'n\'importe quel auteur de fiches : elle détaille le pourquoi de '
              'la bonne réponse et occupe naturellement plusieurs lignes.',
        );
        await pumpCard(tester, card: card);
        await reveal(tester);

        expect(tester.takeException(), isNull,
            reason: 'RenderFlex overflow sur un QCM ordinaire : la face n\'est '
                'pas défilable (patron lex_ui absent)');
      },
    );

    testWidgets(
      'un contenu LONG (sans aucun markdown) ne déborde pas — il DÉFILE',
      (tester) async {
        final card = ZFlashcard(
          question: 'Q',
          answer: List<String>.filled(200, 'Une réponse très détaillée.').join(' '),
        );
        await pumpCard(tester, card: card);
        await reveal(tester);

        expect(tester.takeException(), isNull,
            reason: 'RenderFlex overflow de plusieurs milliers de pixels : le '
                'contenu long n\'est ni tronqué ni défilable — l\'utilisateur '
                'ne peut PAS lire la fin de la réponse');
        expect(find.byType(Scrollable), findsWidgets,
            reason: 'aucun mécanisme de défilement : le contenu qui dépasse est '
                'définitivement inaccessible');
      },
    );

    testWidgets(
      'CONTRE-PREUVE — la sonde de débordement a du POUVOIR : un Column NON '
      'défilable, lui, déborde bel et bien dans ce harnais',
      (tester) async {
        // Sans ce cas, les `takeException(), isNull` ci-dessus resteraient verts
        // si le harnais était incapable de PRODUIRE un débordement — la garde
        // ne prouverait alors rien du tout.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < 40; i++) const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNotNull,
            reason: 'le harnais NE PEUT PAS produire de débordement : les '
                'assertions ci-dessus sont aveugles');
      },
    );

    testWidgets(
      'une carte en hauteur NON BORNÉE (dans un ListView) reste rendable',
      (tester) async {
        // Garde-fou du fix D3 : un viewport exige une hauteur bornée. Rendre la
        // face inconditionnellement défilable lèverait « Vertical viewport was
        // given unbounded height » pour tout hôte qui pose la carte dans une
        // liste — un usage parfaitement légitime.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const <Widget>[
                  ZFlashcardReviewCard(card: ZFlashcard(question: 'Q', answer: 'A')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'la carte lève une exception en hauteur non bornée : elle '
                'est inutilisable dans un ListView');
        expect(find.text('Q'), findsOneWidget);
      },
    );
  });

  group('AC1 — explanation : présente si non vide, ABSENTE sinon', () {
    testWidgets('explanation non vide ⇒ affichée sur la face réponse',
        (tester) async {
      const card = ZFlashcard(
        question: 'Q',
        answer: 'A',
        explanation: 'Parce que.',
      );
      await pumpCard(tester, card: card);
      expect(find.text('Parce que.'), findsNothing);

      await reveal(tester);
      expect(find.text('Parce que.'), findsOneWidget);
    });

    testWidgets('explanation vide ⇒ AUCUN bloc vide rendu', (tester) async {
      const card = ZFlashcard(question: 'Q', answer: 'A', explanation: '');
      await pumpCard(tester, card: card, contentBuilder: _sentinel);
      await reveal(tester);

      // La sentinelle rend UN widget par contenu passé au slot : une explanation
      // vide ne doit produire AUCUN passage (sinon un bloc vide serait rendu).
      expect(find.text('INJ:'), findsNothing);
      expect(find.text('INJ:A'), findsOneWidget);
    });
  });

  group('AC1 — AD-10 : aucun champ nullable ne fait planter le rendu', () {
    testWidgets('answer == null ⇒ repli l10n, jamais d\'exception',
        (tester) async {
      const card = ZFlashcard(question: 'Q sans réponse');
      await pumpCard(tester, card: card);
      await reveal(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Aucune réponse'), findsOneWidget);
    });

    testWidgets('answer vide ⇒ repli l10n (jamais un écran vide)',
        (tester) async {
      const card = ZFlashcard(question: 'Q', answer: '');
      await pumpCard(tester, card: card);
      await reveal(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Aucune réponse'), findsOneWidget);
    });

    testWidgets('choices == null (type multipleChoice) ⇒ repli l10n',
        (tester) async {
      const card = ZFlashcard(
        question: 'QCM sans choix',
        type: ZFlashcardType.multipleChoice,
      );
      await pumpCard(tester, card: card);
      expect(tester.takeException(), isNull);
      expect(find.text('QCM sans choix'), findsOneWidget);

      await reveal(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Aucune réponse'), findsOneWidget);
    });

    testWidgets('choices vide ⇒ repli l10n', (tester) async {
      const card = ZFlashcard(
        question: 'QCM vide',
        type: ZFlashcardType.multipleChoice,
        choices: <ZChoice>[],
      );
      await pumpCard(tester, card: card);
      await reveal(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Aucune réponse'), findsOneWidget);
    });

    testWidgets('isTrue == null (type trueOrFalse) ⇒ repli l10n',
        (tester) async {
      const card = ZFlashcard(
        question: 'VF sans valeur',
        type: ZFlashcardType.trueOrFalse,
      );
      await pumpCard(tester, card: card);
      await reveal(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Aucune réponse'), findsOneWidget);
      expect(find.text('Vrai'), findsNothing);
      expect(find.text('Faux'), findsNothing);
    });
  });

  group('AC1-d — le slot AD-40 est RÉELLEMENT BRANCHÉ (solde de la dette D5)', () {
    testWidgets(
      'TOUS les chemins de contenu (question / réponse / choix / explanation) '
      'traversent le contentBuilder injecté',
      (tester) async {
        const card = ZFlashcard(
          question: 'Q',
          type: ZFlashcardType.multipleChoice,
          choices: <ZChoice>[ZChoice(content: 'C1', isCorrect: true)],
          explanation: 'E',
        );
        await pumpCard(tester, card: card, contentBuilder: _sentinel);

        // Chemin QUESTION + chemin CHOIX (face question).
        expect(find.text('INJ:Q'), findsOneWidget,
            reason: 'le chemin QUESTION ne passe pas par le slot — '
                '`Text(card.question)` en dur ?');
        expect(find.text('INJ:C1'), findsOneWidget,
            reason: 'le chemin CHOIX (ZChoice.content) ne passe pas par le slot');

        await reveal(tester);

        // Chemin CHOIX (face réponse) + chemin EXPLANATION.
        expect(find.text('INJ:C1'), findsOneWidget);
        expect(find.text('INJ:E'), findsOneWidget,
            reason: 'le chemin EXPLANATION ne passe pas par le slot');
      },
    );

    testWidgets('chemin RÉPONSE LIBRE : la réponse traverse le slot',
        (tester) async {
      const card = ZFlashcard(question: 'Q', answer: 'A');
      await pumpCard(tester, card: card, contentBuilder: _sentinel);
      await reveal(tester);

      expect(find.text('INJ:A'), findsOneWidget,
          reason: 'le chemin RÉPONSE ne passe pas par le slot');
    });

    // 🔴 D4 — La sentinelle ne traversait que 2 des 3 chemins `question` : le
    // chemin `trueOrFalse` n'était gardé par AUCUN test. Preuve du trou :
    // injecter `Text(card.question)` sur ce chemin laissait la suite 328/328
    // VERTE. La promesse centrale de su-2 (« la sentinelle traverse TOUS les
    // chemins ») n'était donc vraie que sur les chemins déjà couverts.
    //
    // Cette boucle ferme le trou par CONSTRUCTION : les 6 types y passent, et
    // toute 7ᵉ valeur d'enum ajoutera mécaniquement son cas.
    for (final type in ZFlashcardType.values) {
      testWidgets(
        'chemin QUESTION du type ${type.name} : l\'énoncé traverse le slot',
        (tester) async {
          final card = ZFlashcard(
            question: 'Énoncé ${type.name}',
            type: type,
            isTrue: true,
            choices: const <ZChoice>[ZChoice(content: 'C1', isCorrect: true)],
            answer: 'A',
          );
          await pumpCard(tester, card: card, contentBuilder: _sentinel);

          expect(find.text('INJ:Énoncé ${type.name}'), findsOneWidget,
              reason: 'le chemin QUESTION du type ${type.name} ne passe PAS '
                  'par le slot AD-40 — `Text(card.question)` en dur ?');
          expect(find.text('Énoncé ${type.name}'), findsNothing,
              reason: 'l\'énoncé du type ${type.name} est rendu EN DUR à côté '
                  'du slot (slot décoratif)');
        },
      );
    }

    testWidgets(
      'quand la sentinelle est injectée, le rendu PAR DÉFAUT disparaît '
      '(le slot REMPLACE, il ne double pas)',
      (tester) async {
        const card = ZFlashcard(question: 'Q', answer: 'A');
        await pumpCard(tester, card: card, contentBuilder: _sentinel);

        expect(find.text('INJ:Q'), findsOneWidget);
        expect(find.text('Q'), findsNothing,
            reason: 'le texte brut par défaut subsiste malgré l\'injection : '
                'le slot serait DÉCORATIF (rendu en dur à côté)');
        expect(find.byType(ZFlashcardDefaultContent), findsNothing,
            reason: 'le défaut de su-1 ne doit pas être rendu quand l\'app '
                'injecte son propre builder');
      },
    );

    testWidgets(
      'SANS injection, le défaut de su-1 (texte brut thématisé) est utilisé',
      (tester) async {
        const card = ZFlashcard(question: 'Q', answer: 'A');
        await pumpCard(tester, card: card);

        expect(find.byType(ZFlashcardDefaultContent), findsWidgets,
            reason: 'le chemin par défaut doit rester le texte brut de su-1');
        expect(find.text('INJ:Q'), findsNothing);
      },
    );
  });
}

/// Sentinelle d'injection — **tear-off statique** (jamais une closure allouée
/// dans le `build` d'un test : cela masquerait la garde SM-1).
///
/// Elle préfixe le contenu reçu : `INJ:` n'apparaît dans l'arbre QUE si le
/// contenu a **réellement** traversé le slot de production.
Widget _sentinel(BuildContext context, String content) => Text('INJ:$content');
