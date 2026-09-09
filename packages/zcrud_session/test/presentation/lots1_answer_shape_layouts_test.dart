/// Les trois réglages de FORME de la surface de saisie, posés.
///
/// Ce que chaque groupe établit :
/// * la forme demandée est réellement rendue (géométrie MESURÉE, jamais un
///   `findsOneWidget` sur un type) ;
/// * la matière reste RÉSOLUE (rôles du `ColorScheme`, clés du seam du cœur) —
///   aucune valeur posée dans le code de rendu ;
/// * les canaux d'accessibilité restent à PARITÉ avec la forme de référence
///   (même rôle, même état sélectionné, cible ≥ 48 dp) ;
/// * un repli est défini là où la contrainte manque (largeur non bornée).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_answer_input_harness.dart';

/// Le cadre de tuile d'un choix : la `Material` à `shape` du sous-arbre du
/// choix. Lue par DESCENDANCE de la clé du choix — jamais par position.
RoundedRectangleBorder _tileShape(WidgetTester tester, int index) {
  final Iterable<Material> withShape = tester
      .widgetList<Material>(
        find.descendant(
          of: find.byKey(K.choice(index)),
          matching: find.byType(Material),
        ),
      )
      .where((Material m) => m.shape != null);
  expect(
    withShape,
    hasLength(1),
    reason: 'exactement un cadre de tuile attendu pour le choix $index',
  );
  return withShape.single.shape! as RoundedRectangleBorder;
}

/// Le pourtour tracé d'un contrôle repéré par sa clé.
BorderSide _outline(WidgetTester tester, Key key) {
  final Iterable<Material> withShape = tester
      .widgetList<Material>(
        find.ancestor(of: find.byKey(key), matching: find.byType(Material)),
      )
      .where((Material m) => m.shape != null);
  expect(withShape, hasLength(1));
  return (withShape.single.shape! as RoundedRectangleBorder).side;
}

/// Hôte à résolveur de clés de couleur INJECTÉ — la teinte du pourtour vient
/// de là, jamais du code de rendu.
Widget _hostWithKeys(ZFlashcardAnswerInput input) => ZcrudScope(
  colorKeyResolver: (ColorScheme scheme, String colorKey) => switch (colorKey) {
    ZFlashcardAnswerInput.hintOutlineColorKey => const ZColorPair(
      color: Color(0xFF102030),
      onColor: Color(0xFFFFFFFF),
    ),
    ZFlashcardAnswerInput.dontKnowOutlineColorKey => const ZColorPair(
      color: Color(0xFF405060),
      onColor: Color(0xFFFFFFFF),
    ),
    _ => null,
  },
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: input)),
  ),
);

void main() {
  group('`tile` — la ligne de choix devient une tuile', () {
    testWidgets('géométrie : pleine largeur, coins et liseré de référence', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            choiceLayout: ZAnswerChoiceLayout.tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final double surface = tester
          .getSize(find.byType(ZFlashcardAnswerInput))
          .width;
      final Rect tile = tester.getRect(find.byKey(K.choice(0)));
      expect(
        tile.width,
        surface,
        reason: '🔴 la tuile n\'occupe pas la largeur ENTIÈRE de la surface',
      );

      final RoundedRectangleBorder shape = _tileShape(tester, 0);
      expect(
        shape.borderRadius,
        const BorderRadius.all(ZAnswerInputReference.choiceTileRadius),
      );
      expect(shape.side.width, ZAnswerInputReference.choiceTileBorderWidth);
    });

    testWidgets(
      '🔴 la SÉLECTION épaissit le trait — une forme, jamais la seule couleur',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              choiceLayout: ZAnswerChoiceLayout.tile,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _tileShape(tester, 0).side.width,
          ZAnswerInputReference.choiceTileBorderWidth,
        );
        await tester.tap(find.byKey(K.choice(0)));
        await tester.pumpAndSettle();
        expect(
          _tileShape(tester, 0).side.width,
          ZAnswerInputReference.choiceTileSelectedBorderWidth,
          reason:
              '🔴 sélection portée par la seule couleur : un utilisateur '
              'daltonien ne la verrait pas (invariant AD-13)',
        );
        expect(
          _tileShape(tester, 1).side.width,
          ZAnswerInputReference.choiceTileBorderWidth,
          reason: 'la tuile voisine ne bouge pas',
        );
      },
    );

    testWidgets('la matière est DÉRIVÉE : rôles du `ColorScheme`', (
      tester,
    ) async {
      final ThemeData theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                choiceLayout: ZAnswerChoiceLayout.tile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ColorScheme scheme = theme.colorScheme;
      expect(_tileShape(tester, 0).side.color, scheme.outlineVariant);
      await tester.tap(find.byKey(K.choice(0)));
      await tester.pumpAndSettle();
      expect(
        _tileShape(tester, 0).side.color,
        scheme.primary,
        reason:
            '🔴 une teinte qui ne suit pas le `ColorScheme` est une couleur '
            'en dur (FR-26)',
      );
    });

    testWidgets(
      '🔴 cible ≥ 48 dp et sémantiques STRICTEMENT à parité avec la puce',
      (tester) async {
        // Parité MESURÉE, jamais énumérée : on lit la sémantique rendue par la
        // puce, puis celle rendue par la tuile, et on les compare. Une liste
        // de drapeaux recopiée à la main ne dirait que ce que le test croit,
        // et resterait verte si la tuile PERDAIT un canal que la puce porte.
        final SemanticsHandle handle = tester.ensureSemantics();

        Future<List<SemanticsData>> lire(ZAnswerChoiceLayout layout) async {
          await tester.pumpWidget(
            host(
              ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                choiceLayout: layout,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final SemanticsData avant = tester
              .getSemantics(find.byKey(K.choice(0)))
              .getSemanticsData();
          await tester.tap(find.byKey(K.choice(0)));
          await tester.pumpAndSettle();
          final SemanticsData apres = tester
              .getSemantics(find.byKey(K.choice(0)))
              .getSemanticsData();
          await tester.pumpWidget(const SizedBox());
          return <SemanticsData>[avant, apres];
        }

        final List<SemanticsData> puce = await lire(
          ZAnswerChoiceLayout.compact,
        );
        final List<SemanticsData> tuile = await lire(ZAnswerChoiceLayout.tile);

        for (int i = 0; i < 2; i++) {
          expect(
            tuile[i].label,
            puce[i].label,
            reason: '🔴 libellé annoncé divergent (état $i)',
          );
          expect(
            tuile[i].value,
            puce[i].value,
            reason: '🔴 valeur annoncée divergente (état $i)',
          );
          expect(
            tuile[i].actions,
            puce[i].actions,
            reason: '🔴 actions annoncées divergentes (état $i)',
          );
          expect(
            tuile[i].flagsCollection,
            puce[i].flagsCollection,
            reason:
                '🔴 drapeaux divergents (état $i) : la tuile n\'annonce plus '
                'le même rôle ou le même état sélectionné que la puce',
          );
        }
        // La garde doit distinguer les deux états, sinon elle comparerait
        // deux fois la même chose.
        expect(
          puce[0].flagsCollection,
          isNot(puce[1].flagsCollection),
          reason: '🔴 la sélection ne change RIEN à la sémantique de la puce',
        );

        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              choiceLayout: ZAnswerChoiceLayout.tile,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(K.choice(0))).height,
          greaterThanOrEqualTo(48),
        );
        handle.dispose();
      },
    );

    testWidgets('Vrai/Faux : deux tuiles EMPILÉES, pleine largeur', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            choiceLayout: ZAnswerChoiceLayout.tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final double surface = tester
          .getSize(find.byType(ZFlashcardAnswerInput))
          .width;
      final Rect vrai = tester.getRect(find.byKey(K.answerTrue));
      final Rect faux = tester.getRect(find.byKey(K.answerFalse));
      expect(vrai.width, surface);
      expect(faux.width, surface);
      expect(
        faux.top,
        greaterThanOrEqualTo(vrai.bottom),
        reason: '🔴 les deux tuiles V/F partagent une ligne',
      );
      expect(vrai.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      'Vrai/Faux : le tap vaut TOUJOURS la soumission (le geste ne change '
      'pas avec la forme)',
      (tester) async {
        int submitted = 0;
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
              choiceLayout: ZAnswerChoiceLayout.tile,
              onSubmitted: (_) => submitted++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(K.answerTrue));
        await tester.pumpAndSettle();
        expect(submitted, 1);
      },
    );
  });

  group('`sideBySide` — les deux contrôles d\'aide partagent une ligne', () {
    testWidgets('même ligne, largeurs ÉGALES', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            hintPort: SlowHintPort(),
            actionsLayout: ZAnswerActionsLayout.sideBySide,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsOneWidget);
      final Rect hint = tester.getRect(find.byKey(K.hintButton));
      final Rect dontKnow = tester.getRect(find.byKey(K.dontKnow));
      expect(hint.top, dontKnow.top, reason: '🔴 pas la même ligne');
      expect(hint.width, dontKnow.width, reason: '🔴 parts inégales');
      expect(dontKnow.left, greaterThan(hint.right));
      expect(hint.height, greaterThanOrEqualTo(48));
      expect(dontKnow.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      '🔴 le pourtour est teinté par CLÉ — la teinte vient du résolveur de '
      'l\'hôte, jamais du code de rendu',
      (tester) async {
        await tester.pumpWidget(
          _hostWithKeys(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              hintPort: SlowHintPort(),
              actionsLayout: ZAnswerActionsLayout.sideBySide,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _outline(tester, K.hintButton).color,
          const Color(0xFF102030),
          reason: '🔴 le pourtour « indice » ignore le résolveur de clés',
        );
        expect(
          _outline(tester, K.dontKnow).color,
          const Color(0xFF405060),
          reason: '🔴 le pourtour « je ne sais pas » ignore le résolveur',
        );
        expect(
          _outline(tester, K.hintButton).width,
          ZAnswerInputReference.actionOutlineWidth,
        );
      },
    );

    testWidgets(
      'sans résolveur, la clé retombe sur un RÔLE du `ColorScheme` — jamais '
      'sur une valeur en dur',
      (tester) async {
        final ThemeData theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF117744)),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ZFlashcardAnswerInput(
                  card: qcmSingle(),
                  mode: ZReviewMode.learn,
                  hintPort: SlowHintPort(),
                  actionsLayout: ZAnswerActionsLayout.sideBySide,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _outline(tester, K.hintButton).color,
          theme.colorScheme.tertiaryContainer,
        );
        expect(
          _outline(tester, K.dontKnow).color,
          theme.colorScheme.errorContainer,
        );
      },
    );

    testWidgets(
      'plus rien à servir en indice : le second contrôle occupe seul la place',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              // Ni indice stocké, ni port ⇒ aucun bouton « Indice ».
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              actionsLayout: ZAnswerActionsLayout.sideBySide,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(K.hintButton), findsNothing);
        expect(find.byKey(K.dontKnow), findsOneWidget);
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
      },
    );

    testWidgets(
      '🔴 largeur NON BORNÉE : repli sur la colonne, jamais une exception',
      (tester) async {
        // Carte Vrai/Faux : sa disposition de RÉFÉRENCE ne pose aucun enfant à
        // flex, elle survit donc à une largeur infinie. Un QCM ou un champ
        // rédigé n'y survivent pas — et n'y survivaient pas davantage avant ce
        // lot : ce test mesure le repli AJOUTÉ, pas un support qui n'a jamais
        // existé.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ZFlashcardAnswerInput(
                  card: trueFalseCard(),
                  mode: ZReviewMode.learn,
                  hintPort: SlowHintPort(),
                  actionsLayout: ZAnswerActionsLayout.sideBySide,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
        expect(find.byKey(K.hintButton), findsOneWidget);
        expect(find.byKey(K.dontKnow), findsOneWidget);
        final Rect hint = tester.getRect(find.byKey(K.hintButton));
        final Rect dontKnow = tester.getRect(find.byKey(K.dontKnow));
        expect(
          dontKnow.top,
          greaterThanOrEqualTo(hint.bottom),
          reason: '🔴 le repli n\'a pas empilé les deux contrôles',
        );
      },
    );
  });

  group('`full` — la soumission occupe la largeur entière', () {
    testWidgets('QCM : le contrôle est étiré à la largeur de la surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            submitWidth: ZAnswerSubmitWidth.full,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(K.submit)).width,
        tester.getSize(find.byType(ZFlashcardAnswerInput)).width,
      );
    });

    testWidgets('rédigée : la ligne d\'action occupe la largeur entière', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            submitWidth: ZAnswerSubmitWidth.full,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(K.submit)).width,
        tester.getSize(find.byType(ZFlashcardAnswerInput)).width,
      );
    });

    testWidgets(
      'rédigée avec « évaluer sans IA » : les deux boutons se PARTAGENT la '
      'largeur (aucun n\'est poussé hors du cadre)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              submitWidth: ZAnswerSubmitWidth.full,
              allowSkipEvaluation: true,
              evaluationPort: SpyEvaluationPort(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final double submit = tester.getSize(find.byKey(K.submit)).width;
        final double skip = tester
            .getSize(find.byKey(ZFlashcardAnswerInput.skipEvaluationKey))
            .width;
        expect(submit, skip);
        final double surface = tester
            .getSize(find.byType(ZFlashcardAnswerInput))
            .width;
        expect(submit + skip, lessThanOrEqualTo(surface));
      },
    );

    testWidgets(
      '🔴 largeur NON BORNÉE : repli sur la largeur du contenu, jamais une '
      'exception',
      (tester) async {
        // Champ INJECTÉ de largeur finie : le `TextFormField` de référence ne
        // survit pas à une largeur infinie, et n'y survivait pas davantage
        // avant ce lot. Ce test mesure le repli AJOUTÉ à la ligne d'action.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ZFlashcardAnswerInput(
                  card: writtenCard(),
                  mode: ZReviewMode.learn,
                  submitWidth: ZAnswerSubmitWidth.full,
                  writtenAnswerFieldBuilder:
                      (
                        BuildContext context, {
                        required TextEditingController controller,
                        required FocusNode focusNode,
                        required FormFieldValidator<String> validator,
                        required bool isSubmitted,
                      }) => const SizedBox(width: 120, height: 40),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsNothing,
        );
        expect(find.byKey(K.submit), findsOneWidget);
      },
    );
  });

  group('les jetons de thème sont le MAILLON DU MILIEU', () {
    testWidgets('un jeton seul suffit à poser les quatre formes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(
                answerInputChoiceLayout: ZAnswerChoiceLayout.tile,
                answerInputActionsLayout: ZAnswerActionsLayout.sideBySide,
                answerInputSubmitWidth: ZAnswerSubmitWidth.full,
              ),
            ],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                hintPort: SlowHintPort(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_tileShape(tester, 0).side.width, isNotNull);
      expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsOneWidget);
      expect(
        find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
        findsOneWidget,
      );
    });

    testWidgets('🔴 le PARAMÈTRE prime sur le jeton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(answerInputChoiceLayout: ZAnswerChoiceLayout.tile),
            ],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                choiceLayout: ZAnswerChoiceLayout.compact,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<Material>(
              find.descendant(
                of: find.byKey(K.choice(0)),
                matching: find.byType(Material),
              ),
            )
            .where((Material m) => m.shape != null),
        isEmpty,
        reason: '🔴 le jeton a gagné contre le paramètre',
      );
    });
  });
}
