/// Lot A / écart 2 — **l'inset système du bas est réservé** par les surfaces
/// d'actions basses de la session.
///
/// Mesuré à l'appareil (portrait, barre de navigation système) : la rangée des
/// paliers SRS et le bouton « je ne sais pas » tombaient SOUS la barre — donc
/// hors d'atteinte du doigt. Aucun `SafeArea` n'existait dans ce paquet
/// (`grep -rn SafeArea lib` = 0).
///
/// Ce que ces gardes mesurent, et qui n'est pas la même chose que « il y a un
/// SafeArea quelque part » :
/// 1. la réserve VAUT l'inset (égalité stricte, jamais `> 0`) ;
/// 2. elle DISPARAÎT quand un ancêtre l'a déjà consommée (`SafeArea` hôte) —
///    c'est la double-gouttière, le défaut symétrique ;
/// 3. elle n'est JAMAIS appliquée deux fois quand une surface en contient une
///    autre ;
/// 4. un hôte qui gouverne lui-même l'inset (`bottomInset: 0`) n'en a aucune ;
/// 5. sans inset système, l'arbre est IDENTIQUE au dump figé d'avant le lot.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZReviewMode, ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

const double _navBar = 48;

List<String> _treeSignature(WidgetTester tester) => tester.allWidgets
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

/// Hôte à inset système déclaré — `padding.bottom` est ce que consomme un
/// `SafeArea` : le mesurer ici, c'est mesurer ce que voit l'appareil.
Widget _hostWithInset(
  Widget child, {
  double bottom = _navBar,
  bool hostSafeArea = false,
}) => MediaQuery(
  data: const MediaQueryData().copyWith(
    padding: EdgeInsets.only(bottom: bottom),
    viewPadding: EdgeInsets.only(bottom: bottom),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MaterialApp(
      home: Scaffold(body: hostSafeArea ? SafeArea(child: child) : child),
    ),
  ),
);

/// Distance entre le bas du widget et le bas de la surface qui le porte.
double _gapBelow(WidgetTester tester, Finder inner, Finder outer) =>
    tester.getRect(outer).bottom - tester.getRect(inner).bottom;

void main() {
  group('🔵 écart 2 — la rangée de paliers SRS réserve l\'inset du bas', () {
    testWidgets('la réserve VAUT l\'inset système (égalité stricte)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostWithInset(
          Align(
            alignment: Alignment.bottomCenter,
            child: ZSrsQualityButtons(
              scale: ZQualityScale.fromConfig(const ZSrsConfig()),
              passThreshold: 3,
              onQualitySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _gapBelow(
          tester,
          find.byKey(K.quality(0)),
          find.byType(ZSrsQualityButtons),
        ),
        _navBar,
        reason:
            '🔴 sans réserve, le cran le plus bas touche le bord de la '
            'rangée — donc la barre système, donc un doigt qui ne l\'atteint '
            'pas',
      );
    });

    testWidgets('🔴 PAS de double gouttière : un `SafeArea` hôte a déjà consommé '
        'l\'inset ⇒ réserve nulle', (tester) async {
      await tester.pumpWidget(
        _hostWithInset(
          Align(
            alignment: Alignment.bottomCenter,
            child: ZSrsQualityButtons(
              scale: ZQualityScale.fromConfig(const ZSrsConfig()),
              passThreshold: 3,
              onQualitySelected: (_) {},
            ),
          ),
          hostSafeArea: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _gapBelow(
          tester,
          find.byKey(K.quality(0)),
          find.byType(ZSrsQualityButtons),
        ),
        0,
        reason:
            'la réserve se lit sur `MediaQuery.padding`, que le `SafeArea` '
            'ancêtre a mise à zéro : la poser sur `viewPadding` ajouterait une '
            'seconde gouttière de 48 dp',
      );
    });

    testWidgets('`bottomInset: 0` — l\'hôte gouverne, aucune réserve', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostWithInset(
          Align(
            alignment: Alignment.bottomCenter,
            child: ZSrsQualityButtons(
              scale: ZQualityScale.fromConfig(const ZSrsConfig()),
              passThreshold: 3,
              bottomInset: 0,
              onQualitySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _gapBelow(
          tester,
          find.byKey(K.quality(0)),
          find.byType(ZSrsQualityButtons),
        ),
        0,
      );
    });
  });

  group(
    '🔵 écart 2 — la surface de saisie réserve l\'inset, UNE seule fois',
    () {
      /// Hauteur de la surface, montée avec puis sans inset système. La
      /// DIFFÉRENCE est la réserve — mesure insensible aux gouttières internes
      /// de la colonne (un `gapM` de 8 dp suit le dernier contrôle).
      Future<double> reserve(
        WidgetTester tester, {
        required Widget Function() build,
        bool answerFirst = false,
      }) async {
        final heights = <double>[];
        for (final double inset in <double>[0, _navBar]) {
          await tester.pumpWidget(
            _hostWithInset(
              Align(alignment: Alignment.bottomCenter, child: build()),
              bottom: inset,
            ),
          );
          await tester.pumpAndSettle();
          if (answerFirst) {
            await tester.tap(find.byKey(K.answerTrue));
            await tester.pumpAndSettle();
            expect(
              find.byType(ZSrsQualityButtons),
              findsOneWidget,
              reason:
                  'sans la rangée montée, la garde de double-application ne '
                  'mesurerait rien',
            );
          }
          heights.add(
            tester.getRect(find.byType(ZFlashcardAnswerInput)).height,
          );
          await tester.pumpWidget(const SizedBox());
        }
        return heights[1] - heights[0];
      }

      testWidgets('la réserve VAUT l\'inset système (égalité stricte)', (
        tester,
      ) async {
        expect(
          await reserve(
            tester,
            build: () => ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
            ),
          ),
          _navBar,
          reason:
              '🔴 « je ne sais pas » est le dernier contrôle avant '
              'correction : sans réserve il tombe sous la barre système',
        );
      });

      testWidgets('🔴 la rangée SRS IMBRIQUÉE ne réserve pas une seconde fois '
          '(48 dp au total, jamais 96)', (tester) async {
        expect(
          await reserve(
            tester,
            answerFirst: true,
            build: () => ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
              onQualitySelected: (_) {},
            ),
          ),
          _navBar,
          reason:
              '🔴 ATTRAPE la double gouttière : la surface RÉSERVE et la '
              'rangée qu\'elle contient réserverait à nouveau ⇒ 96 dp. '
              'La surface est propriétaire de l\'inset de tout son sous-arbre',
        );
      });

      testWidgets('`bottomInset: 0` — l\'hôte gouverne, aucune réserve', (
        tester,
      ) async {
        expect(
          await reserve(
            tester,
            build: () => ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
              bottomInset: 0,
            ),
          ),
          0,
        );
      });

      /// La réserve n'est pas seulement « de la bonne taille » : elle est
      /// ABSENTE de l'arbre quand elle vaut zéro. Une réserve de 0 dp rendue
      /// quand même serait invisible à l'œil et passerait toutes les mesures de
      /// hauteur — mais elle intercalerait un widget, donc casserait l'inertie.
      testWidgets('🔴 sous un `SafeArea` hôte, AUCUNE réserve n\'est rendue '
          '(clé absente, pas seulement nulle)', (tester) async {
        await tester.pumpWidget(
          _hostWithInset(
            Align(
              alignment: Alignment.bottomCenter,
              child: ZFlashcardAnswerInput(
                card: trueFalseCard(),
                mode: ZReviewMode.learn,
              ),
            ),
            hostSafeArea: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
          findsNothing,
          reason:
              'le `SafeArea` ancêtre a déjà consommé l\'inset : la surface ne '
              'réserve donc rien, et n\'intercale AUCUN widget',
        );

        await tester.pumpWidget(const SizedBox());
      });

      /// Le clavier ouvert est le seul cas où `padding` et `viewPadding`
      /// divergent sans qu'un `SafeArea` soit en jeu : le système met
      /// `padding.bottom` à zéro (la barre de navigation est recouverte par le
      /// clavier) en gardant `viewPadding.bottom`. Une surface de SAISIE est
      /// précisément l'endroit où ce cas arrive.
      ///
      /// ⚠️ Ce que la garde `SafeArea` ci-dessus ne peut PAS attraper :
      /// `MediaQueryData.removePadding` décrémente AUSSI `viewPadding` du
      /// montant consommé, si bien que sous un `SafeArea` les deux valent zéro
      /// et qu'une lecture erronée y reste invisible (mesuré : injection
      /// `viewPaddingOf` ⇒ garde `SafeArea` restée VERTE).
      testWidgets(
        '🔴 clavier ouvert (`padding` à zéro, `viewPadding` non) ⇒ aucune '
        'réserve',
        (tester) async {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData().copyWith(
                padding: EdgeInsets.zero,
                viewPadding: const EdgeInsets.only(bottom: _navBar),
                viewInsets: const EdgeInsets.only(bottom: 300),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: MaterialApp(
                  home: Scaffold(
                    resizeToAvoidBottomInset: false,
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: ZFlashcardAnswerInput(
                        card: trueFalseCard(),
                        mode: ZReviewMode.learn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
            findsNothing,
            reason:
                '🔴 la réserve se lit sur `padding` — la poser sur '
                '`viewPadding` intercalerait 48 dp entre les derniers '
                'contrôles et le clavier',
          );

          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        'sans `SafeArea` hôte, la réserve EST rendue (la garde précédente '
        'n\'est pas vraie par vacuité)',
        (tester) async {
          await tester.pumpWidget(
            _hostWithInset(
              Align(
                alignment: Alignment.bottomCenter,
                child: ZFlashcardAnswerInput(
                  card: trueFalseCard(),
                  mode: ZReviewMode.learn,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
        },
      );
    },
  );

  group('🧊 Inertie — sans inset système, RIEN ne bouge', () {
    testWidgets(
      'l\'arbre de la surface de saisie est IDENTIQUE au dump figé d\'avant '
      'le lot',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expected = File(
          'test/support/z_answer_input_tree_before_lota.txt',
        ).readAsLinesSync().where((l) => l.isNotEmpty).toList();
        expect(expected, isNotEmpty, reason: 'dump figé absent');
        expect(
          _treeSignature(tester),
          expected,
          reason:
              'égalité STRICTE de la suite (widget, clé) — jamais un '
              '`contains`, jamais un `length >=`',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
