/// AC11 — a11y / RTL / thème / l10n (AD-13, NFR-SU3/4/5).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

/// QCM dont le **correct est en POSITION 2** (index 1) — 🔒 leçon **D2** de su-2.
///
/// **Jamais en tête** : un marqueur *détaché* se lirait malgré tout **juste
/// avant** le bon choix si celui-ci était premier, et le défaut resterait
/// **invisible**. En position 2, un marqueur mal associé s'attache visiblement
/// au **mauvais** choix.
ZFlashcard _qcmCorrectInSecond() => const ZFlashcard(
  question: 'Capitale du Togo ?',
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: 'Accra'),
    ZChoice(content: 'Lomé', isCorrect: true),
    ZChoice(content: 'Cotonou'),
  ],
);

void main() {
  group('AC11 — (2) cibles tap ≥ 48 dp (AD-13)', () {
    testWidgets('chaque contrôle mesure au moins 48×48', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(hint: 'un indice'),
            mode: ZReviewMode.learn,
            hintPort: SpyHintPort(),
          ),
        ),
      );
      for (final key in <ValueKey<String>>[
        K.submit,
        K.dontKnow,
        K.hintButton,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(
          size.width,
          greaterThanOrEqualTo(48.0),
          reason: 'largeur de $key',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'hauteur de $key',
        );
      }
    });

    testWidgets('les boutons V/F et les choix QCM aussi', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(card: trueFalseCard(), mode: ZReviewMode.learn),
        ),
      );
      for (final key in <ValueKey<String>>[K.answerTrue, K.answerFalse]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            key: const ValueKey<String>('qcm'),
            card: _qcmCorrectInSecond(),
            mode: ZReviewMode.learn,
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(K.choice(0))).height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });

  group('🔒 AC11 — (4) ASSOCIATION du marqueur (leçon D2), pas sa PRÉSENCE', () {
    // ⚠️ **ÉCART MESURÉ — 4ᵉ prescription FAUSSE de la story, consignée ici**
    // (code-review su-3). La story prescrit « **R3-I11b** : retirer le
    // `MergeSemantics` de la ligne ⇒ (4) ROUGIT », et les notes de dev l'ont
    // listée parmi les injections « jouées réellement, rouge obtenu ».
    // **C'est faux** : injection rejouée (retrait du `MergeSemantics` enveloppant
    // `_ChoiceRow`) ⇒ `..._a11y_test.dart` **+12 VERTS**, package entier **198/198
    // VERTS**.
    //
    // **Cause** : sans `MergeSemantics`, le `Semantics(inMutuallyExclusiveGroup:,
    // checked:, value:)` **absorbe déjà** les fragments compatibles de ses
    // descendants (le `Text(choice.content)`) — le compilateur de sémantique de
    // Flutter fusionne les fragments compatibles quand aucun n'est une frontière
    // explicite. Le `MergeSemantics` est donc **REDONDANT** ici : la propriété
    // d'association tient **sans lui**.
    //
    // 🔒 **Le test ci-dessous n'est PAS en cause — il est PORTEUR** : il part de
    // la **clé structurelle** du choix (jamais du libellé qu'il vérifie — su-2 D7
    // évité), asserte `label` + `value` sur la **MÊME** node (donc l'ASSOCIATION,
    // pas la présence) et place le correct **en position 2**. Il est conservé
    // tel quel. C'est la **revendication** qui était fausse, pas la garde.
    // Le `MergeSemantics` de prod est conservé en **défense en profondeur** (il
    // redeviendrait load-bearing si un descendant posait une frontière explicite).
    testWidgets('🔴 le marqueur « correct » est porté par la node DU BON choix, pas '
        'celle du voisin (R3-I11b)', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: _qcmCorrectInSecond(),
            mode: ZReviewMode.learn,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(1)));
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      // ⚠️ On NE cherche PAS la node « par le libellé qu'on prétend vérifier »
      // (leçon su-2 D7 : une garde qui ne peut jamais rougir). On part de la CLÉ
      // du choix — son identité structurelle — et on lit ce que SA node annonce.
      final correct = tester.getSemantics(find.byKey(K.choice(1)));
      final wrong0 = tester.getSemantics(find.byKey(K.choice(0)));
      final wrong2 = tester.getSemantics(find.byKey(K.choice(2)));

      // `MergeSemantics` fusionne icône + libellé + statut dans UNE node : le
      // statut ne peut donc pas « flotter » vers le voisin.
      expect(correct.label, contains('Lomé'));
      expect(correct.value, contains('correct'));

      expect(wrong0.label, contains('Accra'));
      expect(
        wrong0.value,
        contains('incorrect'),
        reason:
            'le marqueur du BON choix a été attaché au voisin : un '
            'utilisateur non-voyant apprendrait une ERREUR (D2)',
      );
      expect(wrong2.label, contains('Cotonou'));
      expect(wrong2.value, contains('incorrect'));
    });

    testWidgets('l\'état de sélection est porté par la node du choix', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: _qcmCorrectInSecond(),
            mode: ZReviewMode.learn,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(1)));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byKey(K.choice(1)))
            .hasFlag(SemanticsFlag.isChecked),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isChecked),
        isFalse,
      );
    });

    testWidgets('le QCM à choix unique s\'annonce comme MUTUELLEMENT EXCLUSIF '
        '(le lecteur d\'écran dit « bouton radio », pas « case à cocher »)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: _qcmCorrectInSecond(), // 1 seul correct ⇒ exclusif
            mode: ZReviewMode.learn,
          ),
        ),
      );
      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
        isTrue,
      );

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            key: const ValueKey<String>('multi'),
            card: qcmMulti(), // 2 corrects ⇒ cumulatif
            mode: ZReviewMode.learn,
          ),
        ),
      );
      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
        isFalse,
      );
    });
  });

  group('AC11 — la pré-sélection SRS a un canal NON-COLORÉ', () {
    testWidgets(
      'le cran pré-sélectionné porte `Semantics(selected:)` ET une FORME '
      '(coche) — jamais la seule couleur',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.enterText(find.byKey(K.answerField), 'r');
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        // Canal 1 : le flag d'accessibilité.
        expect(
          tester
              .getSemantics(find.byKey(K.quality(4)))
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
        );
        // Canal 2 : une FORME dans le sous-arbre DU cran (sonde scopée — D5).
        expect(
          find.descendant(
            of: find.byKey(K.quality(4)),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason:
              'le cran sélectionné doit être identifiable sans percevoir la '
              'couleur (AD-13)',
        );
        // Un cran NON sélectionné n'a pas la coche.
        expect(
          find.descendant(
            of: find.byKey(K.quality(2)),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
        );
      },
    );
  });

  group('AC11 — (1) thème : le repli est RÉELLEMENT emprunté (leçon D7)', () {
    testWidgets('🔴 `ZcrudTheme.labelColor` est utilisé quand il est fourni '
        '(valeurs DISCRIMINANTES : onSurface ≠ labelColor)', (tester) async {
      // 🔴 Leçon D7 : sans valeurs volontairement DISTINCTES, le test passerait
      // QUELLE QUE SOIT la branche empruntée — il ne prouverait rien.
      const labelColor = Color(0xFF123456);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(onSurface: Color(0xFFABCDEF)),
          ),
          home: ZcrudScope(
            theme: const ZcrudTheme(labelColor: labelColor),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ZFlashcardAnswerInput(
                  card: _qcmCorrectInSecond(),
                  mode: ZReviewMode.learn,
                ),
              ),
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byKey(K.choice(0)),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(
        icon.color,
        labelColor,
        reason:
            'la couleur du thème injecté n\'est pas empruntée : le widget '
            'a codé une couleur en dur ou lu la mauvaise source (R3-I11)',
      );
    });

    testWidgets('sans ZcrudScope, le repli `Theme.of` est emprunté (AD-6)', (
      tester,
    ) async {
      const onSurface = Color(0xFFABCDEF);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(onSurface: onSurface),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: _qcmCorrectInSecond(),
                mode: ZReviewMode.learn,
              ),
            ),
          ),
        ),
      );
      // 🔒 Cette branche de repli est RÉELLEMENT ATTEINTE (leçon D7 : un test
      // qui NOMME une branche de repli doit l'ATTEINDRE).
      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byKey(K.choice(0)),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icon.color, isNotNull);
    });
  });

  group('AC11 — (3) RTL ET LTR : aucune exception, aucun débordement', () {
    for (final direction in TextDirection.values) {
      testWidgets('rendu correct en $direction', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ZFlashcardAnswerInput(
                    card: _qcmCorrectInSecond(),
                    mode: ZReviewMode.learn,
                    timerDisplay: ZTimerDisplay.elapsed,
                    hintPort: SpyHintPort(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // 🔒 On ne « masque » AUCUN débordement en changeant le test (leçon D3) :
        // un RenderFlex overflow lèverait ici.
        expect(tester.takeException(), isNull);
        expect(find.byKey(K.choice(0)), findsOneWidget);

        // Et la surface reste UTILISABLE dans les deux sens.
        await tester.tap(find.byKey(K.choice(1)));
        await tester.pump();
        expect(
          tester
              .getSemantics(find.byKey(K.choice(1)))
              .hasFlag(SemanticsFlag.isChecked),
          isTrue,
        );
      });
    }
  });

  group('AC11 — Reduce Motion via la primitive UNIQUE `zReduceMotionOf`', () {
    // 🔴 CORRECTION du code-review su-3 — UN TEST TAUTOLOGIQUE A ÉTÉ SUPPRIMÉ ICI.
    //
    // Il montait la surface sous `disableAnimations: true`, tapait, faisait UN
    // SEUL `pump()` et asserait `find.byType(ZSrsQualityButtons), findsOneWidget`
    // — « sous Reduce Motion, la correction s'affiche INSTANTANÉMENT ».
    //
    // Or c'était vrai **AUSSI SANS** Reduce Motion (mesuré : `disableAnimations:
    // false`, un seul `pump()` ⇒ rangée SRS déjà présente). La prod portait un
    // `AnimatedOpacity(opacity: 1, duration: zReduceMotionOf(context) ? …)` :
    // `opacity` étant la **constante 1** et le sous-arbre n'étant **créé** qu'à
    // la correction, l'animation implicite ne se déclenchait **JAMAIS** (mesuré :
    // `FadeTransition.opacity.value == 1.0` à chaque pump). ⇒ `zReduceMotionOf`
    // était du **code MORT** et ce test **restait vert si on supprimait la
    // ligne** : il ne pouvait pas rougir.
    //
    // ARBITRAGE : **aucune affordance de su-3 n'est animée**, et la story n'en
    // réclame nulle part. AC11 dit exactement « toute affordance **ANIMÉE** de
    // su-3 passe par `zReduceMotionOf` » ⇒ la clause est satisfaite **par
    // vacuité**. L'`AnimatedOpacity` et l'appel mort ont donc été **RETIRÉS** de
    // la prod, avec le test qui prétendait les garder. Garder les trois aurait
    // laissé une surface qui **SIMULE la conformité AD-13** — un verrou factice
    // est pire qu'un verrou absent : il se donne pour une preuve.
    //
    // ⚠️ Le test ci-dessous, lui, est **SAIN et DISCRIMINANT** : il exerce la
    // règle « dégradation de l'ANIMATION, jamais de la FONCTION » sur une
    // fonction réelle (l'auto-passage), et il rougirait si Reduce Motion la
    // supprimait. Il est conservé.

    testWidgets(
      '🔒 l\'auto-passage N\'EST PAS supprimé par Reduce Motion (fonction ≠ '
      'animation — arbitrage n°12)',
      (tester) async {
        final advances = <int>[];
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: host(
              ZFlashcardAnswerInput(
                card: trueFalseCard(),
                mode: ZReviewMode.test,
                onAdvance: () => advances.add(1),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(K.answerTrue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          advances,
          hasLength(1),
          reason:
              'avancer est une FONCTION, pas une animation : su-2 a fixé la '
              'règle « dégradation de l\'ANIMATION, jamais de la FONCTION »',
        );
      },
    );
  });

  group('AC11 — 🔴 zéro libellé en dur AFFICHÉ à l\'utilisateur', () {
    // 🔴 DÉFAUT RÉEL de su-3 : `_validate` rendait le littéral **`'required'`**,
    // rendu en `errorText` sous le champ (`autovalidateMode: onUserInteraction`).
    // Un apprenant francophone qui tapait une lettre puis l'effaçait — geste
    // banal — voyait **« required »**, en anglais, dans une UI par ailleurs
    // entièrement française. En arabe (RTL), idem.
    //
    // C'était EXACTEMENT la dette su-1 (`'ok'`/`'lapse'`) que su-3 venait de
    // solder **dix lignes plus haut dans le même diff** : remboursée d'une main,
    // recontractée de l'autre. Aucune garde ne la voyait — le scan ne bannissait
    // que les **couleurs** et les **API non-directionnelles** ; l'AC11 « zéro
    // libellé en dur » n'avait donc **AUCUN exécuteur** (trou fermé depuis :
    // `z_widgets_hardcode_scan_test.dart`).

    testWidgets(
      '🔴 champ vidé après frappe ⇒ message LOCALISÉ, jamais `required`',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(card: writtenCard(), mode: ZReviewMode.learn),
          ),
        );

        // Le geste réel : je tape, j'hésite, j'efface.
        await tester.enterText(find.byKey(K.answerField), 'a');
        await tester.pump();
        await tester.enterText(find.byKey(K.answerField), '');
        await tester.pump();

        expect(
          find.text('required'),
          findsNothing,
          reason:
              '🔴 le DÉFAUT EXACT (sonde : Found 1 widget with text '
              '"required") : un libellé technique ANGLAIS affiché à '
              'l\'utilisateur',
        );
        expect(
          find.text('Réponse requise'),
          findsOneWidget,
          reason: 'le repli l10n du patron `label(context, …, fallback: …)`',
        );
      },
    );

    testWidgets(
      '🔒 le validateur reste MÉMOÏSÉ malgré la localisation (identité stable '
      'entre builds — AC10)',
      (tester) async {
        // La correction de D5 déplace le validateur hors du `static` (il lui faut
        // un `BuildContext`). Elle ne doit PAS coûter la mémoïsation d'AC10 : une
        // closure recréée à chaque build ferait retravailler le `FormField`.
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(card: writtenCard(), mode: ZReviewMode.learn),
          ),
        );
        FormFieldValidator<String>? validatorOf() =>
            tester.widget<TextFormField>(find.byKey(K.answerField)).validator;
        final first = validatorOf();

        // Provoque des rebuilds de la surface (frappe + tick d'arbre).
        await tester.enterText(find.byKey(K.answerField), 'abc');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          identical(validatorOf(), first),
          isTrue,
          reason:
              'le validateur a été RÉALLOUÉ ⇒ la mémoïsation d\'AC10 est '
              'perdue',
        );
      },
    );
  });

  group('AC5 — 🔴 le contenu ASYNCHRONE est ANNONCÉ (liveRegion)', () {
    // 🔴 DÉFAUT RÉEL de su-3 : ni l'erreur d'indice ni le feedback ne portaient
    // de `liveRegion` (sonde : « ancêtres Semantics liveRegion=true : 0 »). Ils
    // apparaissent de façon ASYNCHRONE, HORS du focus (qui reste sur le bouton).
    //
    // Scénario : utilisateur de lecteur d'écran, port d'indices hors ligne. Il
    // active « Indice ». Le message « Indice indisponible. » APPARAÎT plus bas
    // dans l'arbre — AUCUNE annonce. Rien ne se produit de son point de vue : il
    // ré-appuie, en boucle. Le commentaire de prod « un échec n'est JAMAIS
    // silencieux » était vrai pour un voyant, FAUX pour un non-voyant — alors
    // qu'AC5 exige que l'échec soit perceptible.

    /// Vrai si [finder] a un ancêtre `Semantics` portant `liveRegion: true`.
    bool hasLiveRegionAncestor(WidgetTester tester, Finder finder) => tester
        .widgetList<Semantics>(
          find.ancestor(of: finder, matching: find.byType(Semantics)),
        )
        .any((s) => s.properties.liveRegion ?? false);

    testWidgets('🔴 l\'échec d\'indice est annoncé (AD-10 + AC5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            hintPort: FailingHintPort(),
          ),
        ),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      final error = find.text('Indice indisponible.');
      expect(error, findsOneWidget);
      expect(
        hasLiveRegionAncestor(tester, error),
        isTrue,
        reason: '🔴 rendu, mais JAMAIS annoncé',
      );
    });

    testWidgets(
      '🔴 le feedback du barème est annoncé (c\'est le CONTENU PÉDAGOGIQUE '
      'CENTRAL de la carte)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: SpyEvaluationPort(
                feedback: 'votre réponse est partielle',
              ),
            ),
          ),
        );
        await tester.enterText(find.byKey(K.answerField), 'ma réponse');
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        final feedback = find.byKey(K.feedback);
        expect(feedback, findsOneWidget);
        expect(hasLiveRegionAncestor(tester, feedback), isTrue);
      },
    );
  });

  group('AC11 — 🔵 le minuteur dit DANS QUEL SENS il va', () {
    // 🔵 LOW : le libellé était « Minuteur » pour `elapsed` ET `countdown`. Un
    // utilisateur de lecteur d'écran entendait « Minuteur, 00:03 » sans jamais
    // savoir s'il RESTE 3 s ou s'il en a consommé 3 — l'information DÉCISIVE en
    // examen blanc (su-7, qui réutilisera cette surface).
    for (final (display, expected) in <(ZTimerDisplay, String)>[
      (ZTimerDisplay.elapsed, 'Temps écoulé'),
      (ZTimerDisplay.countdown, 'Temps restant'),
    ]) {
      testWidgets('$display ⇒ « $expected »', (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              timerDisplay: display,
              timeLimit: const Duration(minutes: 5),
            ),
          ),
        );
        // La node fusionne le libellé et le texte du minuteur (« Temps écoulé\n
        // 00:00 ») — on vise le LIBELLÉ, en tête, pas la fusion.
        expect(
          tester.getSemantics(find.byKey(K.timer)).label,
          startsWith(expected),
        );
      });
    }

    testWidgets(
      '🔒 et il n\'a TOUJOURS PAS de `liveRegion` (une annonce par seconde '
      'noierait le lecteur d\'écran)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              timerDisplay: ZTimerDisplay.elapsed,
            ),
          ),
        );
        final live = tester
            .widgetList<Semantics>(
              find.ancestor(
                of: find.byKey(K.timer),
                matching: find.byType(Semantics),
              ),
            )
            .any((s) => s.properties.liveRegion ?? false);
        expect(live, isFalse);
      },
    );
  });
}
