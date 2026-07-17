/// 🎯 AC1/AC2/AC3/AC11 (SU-5) — `ZSessionSummaryView` **assemble**, ses stats
/// disent la VÉRITÉ, et ses boutons sont **ACTIONNÉS** (FR-SU8).
///
/// ## 🔴 Le corpus est choisi pour que `correct != masteredCount`
///
/// `byQuality = {'0':1,'2':1,'3':3,'4':2,'5':1}`, `total=8`, `correct=6` ⇒
/// **maîtrisées = 3** (q4+q5 = 2+1). C'est **TOUT** le pouvoir discriminant de
/// l'AC2 : un corpus où les deux coïncident rendrait le test **incapable de
/// rougir** (défaut su-2 « présence ≠ association » : un nombre juste attribué
/// au mauvais concept).
///
/// ## 🔴 Interdits, hérités des défauts déjà démasqués
///
/// - comparer un attendu à **une constante du code** (`ZSummaryDefaults
///   .masteredThreshold`) — l'attendu est **`3`, écrit EN DUR ici**, dérivé du
///   corpus **à la main** (défaut su-4) ;
/// - prouver la **présence** d'un bouton sans le **TAPER** (défaut su-4 : un
///   bouton « précédent » qui **avançait** était vert parce que le test
///   n'assérait que `label isNotEmpty`) ;
/// - `warnIfMissed: false` — il masquerait une mauvaise cible.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' show SemanticsAction, SemanticsFlag;

// ⚠️ Importer `confetti` DANS UN TEST ne viole pas AC8/NFR-SU7 : la garde de
// confinement scanne `lib/` (`_ownerLib()`), et c'est précisément en lisant les
// propriétés RÉELLEMENT passées au widget qu'on tient les réglages imposés (D5).
import 'package:confetti/confetti.dart' show ConfettiWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// 🔴 Corpus DISCRIMINANT : `correct` (6, = q3+q4+q5) **DIFFÈRE** du compte des
/// maîtrisées (3, = q4+q5).
const ZStudySessionResult _result = ZStudySessionResult(
  total: 8,
  correct: 6,
  byQuality: <String, int>{'0': 1, '2': 1, '3': 3, '4': 2, '5': 1},
);

/// Attendu **écrit à la main** : q4 (2) + q5 (1) = **3**. Jamais lu du code.
const int _expectedMastered = 3;

/// `correct` du corpus — **6**, écrit à la main. L'AC2 oppose EXPLICITEMENT les
/// deux nombres.
const int _corpusCorrect = 6;

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _pump(
  WidgetTester tester, {
  ZStudySessionResult result = _result,
  Duration duration = const Duration(minutes: 3, seconds: 25),
  int dueRemaining = 0,
  VoidCallback? onFinish,
  VoidCallback? onContinue,
  int? masteredThreshold,
  ZSummaryCelebration celebration = ZSummaryCelebration.none,
  String? feedbackKey,
  ZFeedbackBank? feedbackBank,
}) async {
  await tester.pumpWidget(
    _wrap(
      ZSessionSummaryView(
        result: result,
        duration: duration,
        config: const ZSrsConfig(),
        onFinish: onFinish ?? () {},
        dueRemaining: dueRemaining,
        onContinue: onContinue,
        masteredThreshold: masteredThreshold,
        celebration: celebration,
        feedbackKey: feedbackKey,
        feedbackBank: feedbackBank,
      ),
    ),
  );
  await tester.pump();
}

/// Monte l'écran sous une **locale CONTRÔLÉE** (AC5/D6).
///
/// ⚠️ `MaterialApp(locale: 'fr')` est INOPÉRANT ici : `DefaultMaterialLocalizations`
/// ne connaît que `en` (aveu ③ de la story, vérifié). On monte donc
/// `Localizations` **directement** — la primitive EXACTE que lit
/// `zFeedbackText` (`Localizations.localeOf(context).languageCode`) — plutôt que
/// d'affaiblir le test.
Future<void> _pumpLocalized(
  WidgetTester tester,
  String languageCode, {
  String? feedbackKey,
  ZFeedbackBank? feedbackBank,
}) async {
  await tester.pumpWidget(
    Localizations(
      locale: Locale(languageCode),
      delegates: const <LocalizationsDelegate<dynamic>>[
        ZcrudLocalizationsDelegate(),
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: ZSessionSummaryView(
            result: _result,
            duration: const Duration(minutes: 3, seconds: 25),
            config: const ZSrsConfig(),
            onFinish: () {},
            feedbackKey: feedbackKey,
            feedbackBank: feedbackBank,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Banque TÉMOIN : **elle seule** doit parler quand elle est injectée (AC5).
class _WitnessBank implements ZFeedbackBank {
  const _WitnessBank();

  @override
  String? maybeResolve(String key, String languageCode) => 'TÉMOIN-SURCHARGE';
}

/// Lit le texte **RÉELLEMENT RENDU** d'une valeur de stat.
String _valueOf(WidgetTester tester, ValueKey<String> key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  group('🎯 AC1 — il ASSEMBLE les widgets EXISTANTS, il ne réimplémente rien',
      () {
    testWidgets('le breakdown ET les anneaux sont MONTÉS', (tester) async {
      await _pump(tester);
      expect(find.byType(ZSessionQualityBreakdown), findsOneWidget);
      expect(
        find.byType(ZStudyProgressRings),
        findsOneWidget,
        reason: '🔴 R3-AC1 : remplacer ce montage par un `CustomPaint` maison '
            'fait ROUGIR ce test',
      );
    });

    testWidgets(
        '🔴 le DTO monté ÉGALE `ZProgressRingsData.fromResult(result)` '
        '(jamais un ratio recalculé)', (tester) async {
      await _pump(tester);
      final rings = tester.widget<ZStudyProgressRings>(
        find.byType(ZStudyProgressRings),
      );
      expect(
        rings.data,
        ZProgressRingsData.fromResult(_result),
        reason: '🔴 le DTO doit venir de la fonction PURE du contrat existant. '
            'Un ratio recalculé à la main divergerait silencieusement',
      );
    });

    testWidgets('🔴 le breakdown reçoit `byQuality` VERBATIM (aucun recomptage)',
        (tester) async {
      await _pump(tester);
      final breakdown = tester.widget<ZSessionQualityBreakdown>(
        find.byType(ZSessionQualityBreakdown),
      );
      expect(breakdown.byQuality, _result.byQuality);
    });

    testWidgets(
        '🔴 `scale` et `passThreshold` DÉRIVENT de la `ZSrsConfig` injectée '
        '(AD-46 : jamais une seconde source)', (tester) async {
      // Config TRONQUÉE : si le widget redéclarait l'échelle `0..5` en dur, il
      // ignorerait cette config et ce test ROUGIRAIT.
      const truncated = ZSrsConfig(minQuality: 1, passThreshold: 2);
      await tester.pumpWidget(
        _wrap(
          ZSessionSummaryView(
            result: _result,
            duration: Duration.zero,
            config: truncated,
            onFinish: () {},
          ),
        ),
      );
      await tester.pump();
      final breakdown = tester.widget<ZSessionQualityBreakdown>(
        find.byType(ZSessionQualityBreakdown),
      );
      expect(breakdown.scale, ZQualityScale.fromConfig(truncated));
      expect(breakdown.scale.min, 1);
      expect(breakdown.passThreshold, 2);
    });
  });

  group('🎯 AC2 — stats : total / MAÎTRISÉES / durée', () {
    testWidgets(
        '🔴 « maîtrisées » affiche 3 (q4+q5), JAMAIS 6 (`result.correct`)',
        (tester) async {
      await _pump(tester);
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '$_expectedMastered',
        reason: '🔴 R3-AC2-(a) : brancher `masteredCount` sur `result.correct` '
            'affiche 6 et fait ROUGIR ce test. `correct` = q >= passThreshold '
            '(q3+) ; maîtrisée = q4-5 — DEUX concepts distincts',
      );
      // 🔴 L'AC2 OPPOSE explicitement les deux nombres : on vérifie que le
      // corpus est bien discriminant, sinon ce test ne prouverait rien.
      expect(
        _expectedMastered,
        isNot(_corpusCorrect),
        reason: 'si le corpus rendait `correct == mastered`, ce test serait '
            'INCAPABLE de rougir',
      );
      expect(_valueOf(tester, ZSessionSummaryView.masteredValueKey),
          isNot('$_corpusCorrect'));
    });

    testWidgets('« totales » affiche `result.total` (8)', (tester) async {
      await _pump(tester);
      expect(_valueOf(tester, ZSessionSummaryView.totalValueKey), '8');
    });

    testWidgets('🔴 la durée affichée est la `Duration` INJECTÉE',
        (tester) async {
      await _pump(tester, duration: const Duration(minutes: 3, seconds: 25));
      expect(
        _valueOf(tester, ZSessionSummaryView.durationValueKey),
        '03:25',
        reason: '🔴 R3-AC2-(c) : ignorer la durée injectée fait ROUGIR ce test',
      );
      // …et une AUTRE durée donne un AUTRE affichage (sans quoi une constante
      // en dur passerait le test ci-dessus).
      await _pump(tester, duration: const Duration(minutes: 12, seconds: 7));
      expect(_valueOf(tester, ZSessionSummaryView.durationValueKey), '12:07');
    });

    testWidgets('🔴 le seuil de maîtrise est DÉRIVÉ (`scale.max - 1`), jamais 4',
        (tester) async {
      // R3-AC2-(b) : avec le seuil dérivé (4), on attend 3 (q4+q5). Si le seuil
      // devenait `scale.max` (5), on obtiendrait 1 (q5 seul) ⇒ ROUGE.
      await _pump(tester);
      expect(_valueOf(tester, ZSessionSummaryView.masteredValueKey), '3');

      // Preuve de la DÉRIVATION : un seuil explicitement injecté est HONORÉ ⇒
      // le défaut vient bien d'un calcul, pas d'un `4` enfoui.
      await _pump(tester, masteredThreshold: 5);
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '1',
        reason: 'seuil 5 ⇒ q5 seul ⇒ 1 (attendu écrit à la main)',
      );
      await _pump(tester, masteredThreshold: 3);
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '6',
        reason: 'seuil 3 ⇒ q3+q4+q5 = 3+2+1 = 6 (attendu écrit à la main)',
      );
    });

    test('🔴 `zMasteredCount` — fonction PURE, attendus LITTÉRAUX', () {
      final scale = ZQualityScale.fromConfig(const ZSrsConfig());
      expect(zMasteredCount(_result.byQuality, scale, 4), 3);
      expect(zMasteredCount(_result.byQuality, scale, 5), 1);
      expect(zMasteredCount(_result.byQuality, scale, 3), 6);
      // Une clé HORS échelle n'est JAMAIS comptée (le breakdown la signale à
      // part — R6 ; une note que l'échelle ignore ne peut pas être maîtrisée).
      expect(
        zMasteredCount(const <String, int>{'9': 2, '5': 1}, scale, 4),
        1,
        reason: '🔴 AC9 : `masteredCount` ne compte pas la clé hors échelle',
      );
      // Clés non canoniques : mêmes règles que `_isInScale` (string EXACTE).
      expect(zMasteredCount(const <String, int>{'05': 3}, scale, 4), 0);
      expect(zMasteredCount(const <String, int>{}, scale, 4), 0);
    });

    test(
        '🔴 AD-10/D3 — un cran NÉGATIF n\'est JAMAIS compté (« Maîtrisées : -1 » '
        'ne peut plus s\'afficher)', () {
      final scale = ZQualityScale.fromConfig(const ZSrsConfig());
      // `ZStudySessionResult._decodeByQuality` ne filtre que le TYPE (`is int`) :
      // un `-3` d'un document persisté corrompu traverse VERBATIM. Le VO clampe
      // pourtant déjà `total`/`correct` à >= 0 — `byQuality` échappait seul.
      expect(
        zMasteredCount(const <String, int>{'5': -3, '4': 2}, scale, 4),
        2,
        reason: '🔴 sans plancher : -3 + 2 = -1 ⇒ l\'écran affiche « Maîtrisées '
            ': -1 » et le lecteur d\'écran annonce « moins un ». Aucun throw, '
            'aucun test rouge — bug SILENCIEUX',
      );
      // Le cran aberrant est IGNORÉ, il ne devient pas non plus positif.
      expect(zMasteredCount(const <String, int>{'5': -3}, scale, 4), 0);
      // Le résultat n'est JAMAIS négatif, quelle que soit la corruption.
      expect(
        zMasteredCount(const <String, int>{'4': -1, '5': -100}, scale, 4),
        0,
      );
    });

    testWidgets('🔴 AD-10/D3 — un `byQuality` corrompu n\'affiche jamais un '
        'compte négatif', (tester) async {
      await _pump(
        tester,
        result: const ZStudySessionResult(
          total: 8,
          correct: 6,
          byQuality: <String, int>{'5': -3, '4': 2},
        ),
      );
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '2',
        reason: '🔴 jamais « -1 » — cohérent avec `_decodeCount` du VO '
            '(« négatif → 0 ») et avec `_formatDuration` (jamais « -1:-30 »)',
      );
    });
  });

  // 🔴 D1 — le MOTIF `Semantics(label:/value:)` + `Text` : mesuré sur l'arbre
  // SÉMANTIQUE, jamais sur le `Text` VISUEL.
  //
  // Les 17 assertions de stats passaient TOUTES par `_valueOf` (= le `Text`
  // visuel) : le bégaiement « Cartes, 8, Cartes — valeur 8 » était donc
  // INVISIBLE. Le seul `getSemantics` de la story portait sur le bouton — celui
  // que le dev avait corrigé. C'est là toute la leçon : un défaut trouvé est un
  // MOTIF à balayer, et seul un test qui regarde le BON canal peut le tenir.
  group('🎯 AC10/AD-13 (D1) — l\'arbre SÉMANTIQUE des stats ne BÉGAIE pas', () {
    testWidgets(
        '🔴 chaque tuile annonce « libellé » + « valeur » UNE seule fois',
        (tester) async {
      await _pump(tester);

      // Attendus écrits À LA MAIN (corpus : total=8, mastered=q4+q5=3,
      // durée injectée 03:25) — jamais relus du widget.
      const expected = <(ValueKey<String>, String, String)>[
        (ZSessionSummaryView.totalValueKey, 'Cartes', '8'),
        (ZSessionSummaryView.masteredValueKey, 'Maîtrisées', '3'),
        (ZSessionSummaryView.durationValueKey, 'Durée', '03:25'),
      ];

      for (final (key, label, value) in expected) {
        // `getSemantics` sur le `Text` de la valeur remonte au nœud de la tuile
        // (le `Semantics` parent) : c'est CE nœud que le lecteur d'écran lit.
        final node = tester.getSemantics(find.byKey(key));
        expect(
          node.label,
          label,
          reason: '🔴 D1 : sans `ExcludeSemantics`, le libellé du `Semantics` '
              'parent FUSIONNE avec les 2 `Text` enfants et le nœud annonce '
              '« $label\\n$value\\n$label » — MESURÉ. L\'apprenant sous '
              'TalkBack/VoiceOver entend le libellé DEUX fois et la valeur DEUX '
              'fois, sur les 3 tuiles du bilan (fonction centrale de FR-SU8)',
        );
        expect(node.value, value,
            reason: '🔴 la valeur est portée par `Semantics(value:)`');
      }
    });

    testWidgets(
        '🔬 contre-preuve — le canal VISUEL reste intact (AD-13 : la couleur '
        'n\'est jamais seul canal)', (tester) async {
      await _pump(tester);
      // `ExcludeSemantics` ne retire QUE la sémantique : les textes restent
      // RENDUS. Une correction qui les effacerait serait pire que le défaut.
      expect(find.text('Cartes'), findsOneWidget);
      expect(find.text('Maîtrisées'), findsOneWidget);
      expect(find.text('Durée'), findsOneWidget);
      expect(_valueOf(tester, ZSessionSummaryView.totalValueKey), '8');
      expect(_valueOf(tester, ZSessionSummaryView.masteredValueKey), '3');
      expect(_valueOf(tester, ZSessionSummaryView.durationValueKey), '03:25');
    });
  });

  group('🎯 AC3 — les boutons sont TAPÉS, et l\'AUTRE callback est vérifié', () {
    testWidgets('🔴 taper « Terminer » invoque `onFinish` UNE fois — et JAMAIS '
        '`onContinue`', (tester) async {
      var finishes = 0;
      var continues = 0;
      await _pump(
        tester,
        dueRemaining: 7,
        onFinish: () => finishes++,
        onContinue: () => continues++,
      );

      await tester.tap(find.byKey(ZSessionSummaryView.finishButtonKey));
      await tester.pump();

      expect(finishes, 1);
      expect(
        continues,
        0,
        reason: '🔴 « présence ≠ association » : deux boutons câblés sur le '
            'MÊME callback passeraient un test qui ne compte qu\'un seul',
      );
    });

    testWidgets('🔴 taper « Encore N dues » invoque `onContinue` UNE fois — et '
        'JAMAIS `onFinish`', (tester) async {
      var finishes = 0;
      var continues = 0;
      await _pump(
        tester,
        dueRemaining: 7,
        onFinish: () => finishes++,
        onContinue: () => continues++,
      );

      await tester.tap(find.byKey(ZSessionSummaryView.continueButtonKey));
      await tester.pump();

      expect(continues, 1);
      expect(
        finishes,
        0,
        reason: '🔴 R3-AC3 : permuter `onFinish`/`onContinue` fait ROUGIR ce '
            'test (défaut su-4 : le bouton « précédent » qui AVANÇAIT)',
      );
    });

    testWidgets('le libellé « Encore N dues » porte N = 7 (jamais un recompte)',
        (tester) async {
      await _pump(tester, dueRemaining: 7, onContinue: () {});
      expect(find.text('Encore 7 dues'), findsOneWidget);
      // …et N SUIT le paramètre (sans quoi un `7` en dur passerait).
      await _pump(tester, dueRemaining: 2, onContinue: () {});
      expect(find.text('Encore 2 dues'), findsOneWidget);
      expect(find.text('Encore 7 dues'), findsNothing);
    });

    testWidgets('🔴 `dueRemaining == 0` ⇒ bouton ABSENT (jamais grisé, AD-45)',
        (tester) async {
      await _pump(tester, dueRemaining: 0, onContinue: () {});
      expect(find.byKey(ZSessionSummaryView.continueButtonKey), findsNothing);
      // « Terminer » reste, lui, toujours présent.
      expect(find.byKey(ZSessionSummaryView.finishButtonKey), findsOneWidget);
    });

    testWidgets('chaque bouton est une cible ≥ 48 dp avec `Semantics(button:)`',
        (tester) async {
      await _pump(tester, dueRemaining: 7, onContinue: () {});
      for (final key in <ValueKey<String>>[
        ZSessionSummaryView.finishButtonKey,
        ZSessionSummaryView.continueButtonKey,
      ]) {
        final size = tester.getSize(find.byKey(key));
        // ⚠️ L'attendu `48` est écrit À LA MAIN (jamais
        // `ZSessionSummaryView.minTarget` : comparer à la constante du code
        // serait tautologique — défaut su-4).
        expect(size.height, greaterThanOrEqualTo(48.0), reason: '$key : AD-13');
        expect(size.width, greaterThanOrEqualTo(48.0), reason: '$key : AD-13');
      }
      // ⚠️ On assère les propriétés qui PORTENT l'AC — `isButton`, le libellé
      // l10n, et une action de tap RÉELLE — sans sur-contraindre le reste :
      // `InkWell` ajoute légitimement une action `focus`, et un
      // `matchesSemantics` exhaustif rougirait sur du bruit d'implémentation
      // (une garde qui crie au loup finit désactivée).
      final finish =
          tester.getSemantics(find.byKey(ZSessionSummaryView.finishButtonKey));
      expect(finish.label, 'Terminer');
      expect(finish.hasFlag(SemanticsFlag.isButton), isTrue,
          reason: 'AD-13 : le rôle « bouton » doit être annoncé');
      expect(
        finish.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'un bouton sans action de tap est inatteignable au lecteur '
            'd\'écran',
      );
    });
  });

  // 🔴 D6 — le RACCORD du feedback pédagogique. Les deux pièces
  // (`ZSessionFeedbackText` isolé, et la vue) étaient individuellement correctes
  // et testées ; l'ASSEMBLAGE ne l'était pas. Preuve par mutation : `bank:
  // widget.feedbackBank → null` et `if (feedbackKey != null) → if (false)`
  // laissaient la suite VERTE à 397 — alors que le titre même de la story est
  // « écran de fin ET feedback pédagogique » (FR-SU9/AC5).
  group('🎯 AC5 (D6) — le SLOT de feedback est réellement CÂBLÉ', () {
    testWidgets('🔴 `feedbackKey` ⇒ le message de la banque par DÉFAUT est RENDU '
        '(texte littéral, locale FR)', (tester) async {
      await _pumpLocalized(
        tester,
        'fr',
        feedbackKey: zFeedbackKeyFor(ZFeedbackTier.exceptional),
      );
      expect(find.byType(ZSessionFeedbackText), findsOneWidget);
      expect(
        find.text('Exceptionnel — juste, sans indice et en un éclair !'),
        findsOneWidget,
        reason: '🔴 R3-D6 : `if (widget.feedbackKey != null)` → `if (false)` '
            'fait ROUGIR ce test. Sans lui, l\'apprenant ne reçoit AUCUN '
            'feedback pédagogique et la suite reste verte',
      );
    });

    testWidgets(
        '🔴 une banque INJECTÉE surcharge INTÉGRALEMENT la banque par défaut '
        '— à travers le SLOT de la vue', (tester) async {
      await _pumpLocalized(
        tester,
        'fr',
        feedbackKey: zFeedbackKeyFor(ZFeedbackTier.exceptional),
        feedbackBank: const _WitnessBank(),
      );
      expect(
        find.text('TÉMOIN-SURCHARGE'),
        findsOneWidget,
        reason: '🔴 R3-D6 : `bank: widget.feedbackBank` → `bank: null` fait '
            'ROUGIR ce test. Sans lui, la banque de l\'app est IGNORÉE au '
            'profit de la banque par défaut — le mauvais TON, en silence',
      );
      expect(
        find.text('Exceptionnel — juste, sans indice et en un éclair !'),
        findsNothing,
        reason: '🔴 AC5 : « surcharge INTÉGRALE » — jamais une fusion des deux '
            'banques',
      );
    });

    testWidgets('🔴 `feedbackKey: null` (défaut) ⇒ AUCUN message rendu',
        (tester) async {
      await _pumpLocalized(tester, 'fr');
      expect(find.byType(ZSessionFeedbackText), findsNothing);
    });

    testWidgets('🔴 une clé INCONNUE ne rend rien (jamais la clé technique) '
        '— AD-10', (tester) async {
      await _pumpLocalized(tester, 'fr', feedbackKey: 'zcrud.session.feedback.xxx');
      expect(find.text('zcrud.session.feedback.xxx'), findsNothing,
          reason: '🔴 afficher la clé brute à un apprenant est pire que rien');
    });
  });

  // 🔴 D5 — les réglages « IMPOSÉS » du `ConfettiWidget` (AC6, T1/T3/T4/T6).
  // Chacun neutralise un piège LU dans les sources du paquet, et le code les
  // applique tous correctement — mais RIEN ne les tenait : `grep
  // "widget<ConfettiWidget>" test/` → RC=1. `colors: null` (⇒ couleurs
  // ALÉATOIRES, NFR-SU5 violée) passait avec une suite VERTE, et la garde de
  // couleurs en dur ne peut pas le voir : elle cherche un `Colors.*`, or il n'y
  // a RIEN du tout. Lire des propriétés ne pompe aucune frame : aucun risque T2.
  group('🎯 AC6 (D5) — les réglages IMPOSÉS du `ConfettiWidget` sont GARDÉS', () {
    testWidgets('🔴 shouldLoop=false, pauseEmissionOnLowFrameRate=false, '
        'burst COURT, et couleurs du THÈME (jamais aléatoires)', (tester) async {
      await _pump(tester, celebration: ZSummaryCelebration.confetti);
      // 🚫 JAMAIS `pumpAndSettle` ici (T2 : `_continueAnimation()` est HORS du
      // `if (!shouldLoop)` ⇒ peut ne jamais converger).
      final confetti =
          tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));

      expect(
        confetti.shouldLoop,
        isFalse,
        reason: '🔴 T2 : `shouldLoop: true` ⇒ rafale EN BOUCLE, et tout '
            '`pumpAndSettle` du repo cesserait de converger',
      );
      expect(
        confetti.pauseEmissionOnLowFrameRate,
        isFalse,
        reason: '🔴 T3 : c\'est le DÉFAUT du paquet — sur un appareil qui rame, '
            'l\'émission se suspend et la célébration ne part pas',
      );
      expect(
        confetti.colors,
        isNotNull,
        reason: '🔴 T4 : `colors: null` ⇒ le paquet tire des couleurs '
            'ALÉATOIRES, hors thème — NFR-SU5 VIOLÉE, en silence',
      );

      // …et ce sont bien LES couleurs du thème, résolues dans CE contexte
      // (jamais une palette en dur : la garde de couleurs en dur ne voit pas
      // une ABSENCE, elle cherche un `Colors.*`).
      final context = tester.element(find.byType(ConfettiWidget));
      expect(
        confetti.colors,
        <Color>[
          zResolveColorKeyOrSlot(context, 'primary', slotIndex: 0).color,
          zResolveColorKeyOrSlot(context, 'secondary', slotIndex: 1).color,
          zResolveColorKeyOrSlot(context, 'tertiary', slotIndex: 2).color,
        ],
        reason: '🔴 T4/NFR-SU5 : les couleurs DÉRIVENT du thème injecté',
      );

      // T1 — durée EXPLICITE et courte, lue sur le controller RÉELLEMENT passé
      // (jamais une constante du code : ce serait tautologique — défaut su-4).
      final burst = confetti.confettiController.duration;
      expect(
        burst,
        lessThan(const Duration(seconds: 2)),
        reason: '🔴 T1 : le défaut du paquet est 30 s ⇒ une célébration de 30 '
            'SECONDES. La borne « < 2 s » est écrite à la main',
      );
      expect(burst.inMicroseconds, greaterThan(0),
          reason: '🔴 T1 : `Duration.zero` fait ASSERT-FAIL dans le paquet');

      // T6 — le confetti est DÉCORATIF : rien ne doit transiter par un canal
      // que le lecteur d'écran ne comprend pas (le paquet n'a AUCUN `Semantics`).
      expect(
        find.ancestor(
          of: find.byType(ConfettiWidget),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
        reason: '🔴 T6 : sans `ExcludeSemantics`, un nœud décoratif et vide de '
            'sens serait annoncé',
      );

      // Démontage explicite : le paquet garde un ticker actif (T2).
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🎯 AC11 — enums > booléens', () {
    testWidgets('🔴 le défaut est OPT-OUT : `ZSummaryCelebration.none`',
        (tester) async {
      await _pump(tester);
      final view = tester.widget<ZSessionSummaryView>(
        find.byType(ZSessionSummaryView),
      );
      expect(
        view.celebration,
        ZSummaryCelebration.none,
        reason: '🔴 le confetti est OPT-IN : jamais par défaut',
      );
    });

    test('la variante est portée par un ENUM à 3 valeurs (jamais un bool)', () {
      // Un `bool showConfetti` ne saurait pas exprimer `subtle` : l'enum est ce
      // qui rend la 3ᵉ variante possible SANS casser les appelants.
      expect(ZSummaryCelebration.values, <ZSummaryCelebration>[
        ZSummaryCelebration.none,
        ZSummaryCelebration.subtle,
        ZSummaryCelebration.confetti,
      ]);
    });

    test('🔬 garde de SOURCE — aucun `bool show…`/`bool is…` dans la signature '
        'publique du widget', () {
      final src = File(
        'lib/src/presentation/z_session_summary_view.dart',
      ).readAsStringSync();
      // On scanne les DÉCLARATIONS de champ (`final bool showX;`) — jamais le
      // dartdoc, qui cite légitimement « jamais un `bool showConfetti` ».
      final code = src
          .split('\n')
          .where((l) {
            final t = l.trim();
            return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/');
          })
          .join('\n');
      expect(
        RegExp(r'final\s+bool\s+(show|is)[A-Z]').hasMatch(code),
        isFalse,
        reason: '🔴 AC11 : une variante d\'affichage se porte par un ENUM',
      );
    });
  });
}
