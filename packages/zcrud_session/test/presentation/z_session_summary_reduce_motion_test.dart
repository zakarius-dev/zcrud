/// 🎯 AC6/AC7 (SU-5) — célébration **opt-in, UN SEUL tir** et **Reduce Motion :
/// aucun confetti, animations neutralisées** (NFR-SU3/AD-13).
///
/// ## 🔴 La leçon DURE de su-3 (D7) — pourquoi ce fichier existe
///
/// su-3 avait un `AnimatedOpacity(opacity: 1)` **qui n'animait rien** : l'appel
/// à `zReduceMotionOf` y était **décoratif**, le test **incapable de rougir**,
/// et **tout a dû être retiré**. Ici, **chaque** animation prouve sa
/// dégradation :
///
/// - **sans** Reduce Motion : la valeur **DIFFÈRE entre deux `pump()`
///   intermédiaires** ⇒ l'animation EXISTE vraiment ;
/// - **avec** Reduce Motion : elle est **à sa valeur FINALE dès le premier
///   frame** et n'évolue plus ⇒ la dégradation est RÉELLE.
///
/// Une animation dont ce test ne peut pas rougir **doit être RETIRÉE** — pas
/// conservée avec un `zReduceMotionOf` décoratif. **Aucune conformité AD-13
/// simulée.**
///
/// ## 🔴 Les 3 pièges du paquet `confetti`, neutralisés (lus dans ses sources)
///
/// - **T1** `assert(!duration.isNegative && duration.inMicroseconds > 0)`
///   (`confetti.dart:501`) ⇒ `Duration.zero` **CRASHE** ⇒ sous Reduce Motion on
///   **ne construit PAS** le widget (jamais « une durée nulle ») ;
/// - **T2** `_continueAnimation()` est appelé **HORS** du `if (!shouldLoop)`
///   (`:252-258`) ⇒ relance **inconditionnelle** ⇒ **`pumpAndSettle` INTERDIT**
///   ici (il peut ne **jamais** converger) — on utilise `pump()` + durées
///   explicites ;
/// - **T3** `deltaTime` sur **horloge murale** + `pauseEmission` ⇒ **ZÉRO
///   particule** en test ⇒ on n'assère **JAMAIS** sur les particules, mais sur
///   **notre latch** et sur la **présence du `ConfettiWidget`**.
@TestOn('vm')
library;

import 'dart:io';

import 'package:confetti/confetti.dart' show ConfettiWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const ZStudySessionResult _result = ZStudySessionResult(
  total: 4,
  correct: 3,
  byQuality: <String, int>{'3': 1, '4': 2, '5': 1},
);

Widget _tree({
  required bool reduceMotion,
  required ZSummaryCelebration celebration,
  Key? key,
}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Scaffold(
          body: ZSessionSummaryView(
            key: key,
            result: _result,
            duration: const Duration(minutes: 1),
            config: const ZSrsConfig(),
            onFinish: () {},
            celebration: celebration,
          ),
        ),
      ),
    );

/// Mesure l'échelle **RÉELLEMENT APPLIQUÉE** du trophée, via la géométrie
/// **peinte** de l'icône.
///
/// ⚠️ Patron **imposé par une mesure de su-4** : lire
/// `tester.widget<Transform>(…).transform` rend la matrice **IDENTITÉ**
/// (`Transform.scale` ne peuple pas ce champ — le `RenderTransform` la calcule).
/// La sonde mesurerait alors `1.0` partout : un **faux négatif** qui ferait
/// passer le CODE pour fautif. On mesure donc l'**effet observable**.
double _trophyWidth(WidgetTester tester) =>
    tester.getRect(find.byKey(ZSessionSummaryView.trophyIconKey)).width;

/// Lit l'opacité **RÉSOLUE** du halo sur le widget rendu.
double _glowOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(ZSessionSummaryView.glowKey)).opacity;

/// Compteur de tirs **RÉELS** (seam de test — jamais les particules, T3).
int _plays(WidgetTester tester) =>
    tester
        .state<ZSessionSummaryViewState>(find.byType(ZSessionSummaryView))
        .celebrationPlays;

void main() {
  group('🔴 AC7 — SANS Reduce Motion, les animations EXISTENT vraiment', () {
    testWidgets(
        '🎯 échelle du trophée ET opacité du halo VARIENT entre deux frames',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.subtle),
      );
      // Premier frame : l'animation démarre (`forward`), rien n'est encore joué.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final width80 = _trophyWidth(tester);
      final opacity80 = _glowOpacity(tester);

      await tester.pump(const Duration(milliseconds: 200));
      final width280 = _trophyWidth(tester);
      final opacity280 = _glowOpacity(tester);

      expect(
        width280,
        isNot(closeTo(width80, 0.01)),
        reason: '🔴 D7 : l\'échelle du trophée ne bouge PAS entre deux frames ⇒ '
            'il n\'y a AUCUNE animation à dégrader ⇒ l\'appel à '
            '`zReduceMotionOf` serait DÉCORATIF (défaut EXACT de su-3, où un '
            '`AnimatedOpacity(opacity: 1)` n\'animait rien). Une animation dont '
            'ce test ne peut pas rougir DOIT ÊTRE RETIRÉE',
      );
      expect(
        opacity280,
        isNot(closeTo(opacity80, 0.001)),
        reason: '🔴 D7 : le halo n\'anime rien — même défaut',
      );
    });

    testWidgets('l\'animation CONVERGE vers son état final (trophée VISIBLE)',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.subtle),
      );
      // ⚠️ `pumpAndSettle` est licite ICI (aucun confetti : `subtle`).
      await tester.pumpAndSettle();
      expect(_glowOpacity(tester), closeTo(1, 0.001));
      expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsOneWidget);
    });
  });

  group('🎯 AC7 — AVEC Reduce Motion, la dégradation est RÉELLE', () {
    testWidgets(
        '🎯 l\'état FINAL est rendu dès le PREMIER frame, et n\'évolue plus',
        (tester) async {
      // Référence : l'état final MESURÉ sans Reduce Motion (jamais une constante
      // devinée — c'est l'état vers lequel l'animation converge réellement).
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.subtle),
      );
      await tester.pumpAndSettle();
      final settledWidth = _trophyWidth(tester);
      final settledOpacity = _glowOpacity(tester);

      // …et maintenant, sous Reduce Motion, DÈS le premier frame.
      await tester.pumpWidget(
        _tree(reduceMotion: true, celebration: ZSummaryCelebration.subtle),
      );
      await tester.pump();
      final firstWidth = _trophyWidth(tester);
      final firstOpacity = _glowOpacity(tester);

      expect(
        firstWidth,
        closeTo(settledWidth, 0.01),
        reason: '🔴 R3-AC7 : sous Reduce Motion, le trophée doit être à sa '
            'taille FINALE dès le 1ᵉʳ frame — dégrader l\'ANIMATION, jamais la '
            'FONCTION',
      );
      expect(firstOpacity, closeTo(settledOpacity, 0.001));

      // …et rien ne bouge ensuite (aucune interpolation résiduelle).
      await tester.pump(const Duration(milliseconds: 80));
      expect(_trophyWidth(tester), closeTo(firstWidth, 0.01));
      expect(_glowOpacity(tester), closeTo(firstOpacity, 0.001));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _trophyWidth(tester),
        closeTo(firstWidth, 0.01),
        reason: '🔴 R3-AC7-(a) : l\'échelle varie ENCORE sous Reduce Motion ⇒ '
            'la dégradation est FICTIVE',
      );
      expect(_glowOpacity(tester), closeTo(firstOpacity, 0.001));
    });

    testWidgets('🔒 la FONCTION n\'est jamais dégradée : le trophée et le bilan '
        'restent PRÉSENTS', (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: true, celebration: ZSummaryCelebration.subtle),
      );
      await tester.pump();
      expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsOneWidget);
      expect(find.byType(ZSessionQualityBreakdown), findsOneWidget);
      expect(find.byType(ZStudyProgressRings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 AC6 — confetti OPT-IN, et UN SEUL tir', () {
    testWidgets('🔴 défaut (`none`) ⇒ AUCUN `ConfettiWidget`, AUCUN tir',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.none),
      );
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(_plays(tester), 0);
      // …et pas même le trophée : `none` ne célèbre rien.
      expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsNothing);
    });

    testWidgets('🔴 `subtle` ⇒ trophée animé mais AUCUN confetti',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.subtle),
      );
      await tester.pump();
      expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsOneWidget);
      expect(
        find.byType(ConfettiWidget),
        findsNothing,
        reason: '🔴 `subtle` n\'est PAS `confetti` — la 3ᵉ variante existe '
            'justement pour célébrer sans confetti (AC11)',
      );
      expect(_plays(tester), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('🔴 `confetti` ⇒ le `ConfettiWidget` est monté et le tir part '
        'UNE fois', (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: false, celebration: ZSummaryCelebration.confetti),
      );
      // 🚫 JAMAIS `pumpAndSettle` autour du confetti (T2 : `_continueAnimation()`
      // inconditionnel ⇒ peut ne JAMAIS converger). `pump()` + durées explicites.
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsOneWidget);
      expect(_plays(tester), 1);
      // Démontage explicite : le paquet garde un ticker actif (T2).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '🎯 R3-AC6 — le tir reste UNIQUE après N rebuilds (latch one-shot)',
        (tester) async {
      // `setState` parent, changement de thème, `didUpdateWidget`, rotation :
      // autant d'occasions de re-tirer. Le latch (patron `_stackEnded` de su-4)
      // doit tenir.
      const key = ValueKey<String>('summary');
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          _tree(
            reduceMotion: false,
            celebration: ZSummaryCelebration.confetti,
            key: key,
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        _plays(tester),
        1,
        reason: '🔴 R3-AC6 : retirer le latch donne `plays == 3` au lieu de 1 — '
            'l\'apprenant recevrait une rafale à chaque rebuild',
      );
      expect(find.byType(ConfettiWidget), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('passer `subtle` → `confetti` APRÈS coup tire UNE seule fois',
        (tester) async {
      const key = ValueKey<String>('summary');
      await tester.pumpWidget(
        _tree(
          reduceMotion: false,
          celebration: ZSummaryCelebration.subtle,
          key: key,
        ),
      );
      await tester.pump();
      expect(_plays(tester), 0);

      await tester.pumpWidget(
        _tree(
          reduceMotion: false,
          celebration: ZSummaryCelebration.confetti,
          key: key,
        ),
      );
      await tester.pump();
      expect(_plays(tester), 1);

      // …et un rebuild de plus ne re-tire pas.
      await tester.pump(const Duration(milliseconds: 16));
      expect(_plays(tester), 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🎯 AC7 — Reduce Motion : AUCUN confetti, jamais (NFR-SU3)', () {
    testWidgets(
        '🔴 opt-in ACTIVÉ + Reduce Motion ⇒ AUCUN `ConfettiWidget`, AUCUN tir',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: true, celebration: ZSummaryCelebration.confetti),
      );
      await tester.pump();
      expect(
        find.byType(ConfettiWidget),
        findsNothing,
        reason: '🔴 R3-AC7-(a) : ignorer Reduce Motion pour le confetti fait '
            'ROUGIR ce test. On ne « neutralise » PAS le confetti par une durée '
            'nulle : `ConfettiController` porte `assert(duration.inMicroseconds '
            '> 0)` ⇒ `Duration.zero` CRASHE (T1). On ne le construit pas',
      );
      expect(_plays(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le trophée reste PRÉSENT (la FONCTION n\'est pas dégradée)',
        (tester) async {
      await tester.pumpWidget(
        _tree(reduceMotion: true, celebration: ZSummaryCelebration.confetti),
      );
      await tester.pump();
      expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsOneWidget);
    });

    testWidgets(
        '🔴 le CÂBLAGE est gardé : activer Reduce Motion APRÈS coup n\'ouvre '
        'jamais un tir', (tester) async {
      const key = ValueKey<String>('summary');
      await tester.pumpWidget(
        _tree(
          reduceMotion: true,
          celebration: ZSummaryCelebration.confetti,
          key: key,
        ),
      );
      await tester.pump();
      expect(_plays(tester), 0);
      // Le réglage système change en cours de route (`MediaQuery` notifie) :
      // l'utilisateur DÉSACTIVE Reduce Motion ⇒ la célébration devient licite.
      await tester.pumpWidget(
        _tree(
          reduceMotion: false,
          celebration: ZSummaryCelebration.confetti,
          key: key,
        ),
      );
      await tester.pump();
      expect(
        _plays(tester),
        1,
        reason: 'la dégradation suit le SIGNAL, elle ne le fige pas',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔬 AC7 — `zReduceMotionOf` est la PRIMITIVE UNIQUE (garde de source)',
      () {
    test('🔴 le widget lit le signal via `zReduceMotionOf`, jamais un '
        '`MediaQuery.of(context).disableAnimations` réécrit', () {
      final src = File(
        'lib/src/presentation/z_session_summary_view.dart',
      ).readAsStringSync();
      final code = src
          .split('\n')
          .where((l) {
            final t = l.trim();
            return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/');
          })
          .join('\n');
      expect(
        code.contains('zReduceMotionOf(context)'),
        isTrue,
        reason: '🔴 R3-AC7-(c) : le CÂBLAGE lui-même est gardé (leçon su-3/D6 '
            'su-4) — la garde porte sur l\'APPEL, pas sur une apparence',
      );
      expect(
        code.contains('disableAnimations'),
        isFalse,
        reason: '🔴 une SECONDE lecture du signal divergerait silencieusement : '
            'le repo aurait deux politiques d\'accessibilité',
      );
    });
  });
}
