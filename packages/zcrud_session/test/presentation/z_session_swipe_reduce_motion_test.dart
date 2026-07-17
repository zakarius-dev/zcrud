/// 🔴 AC8 (SU-4) — **Reduce Motion : l'animation doit EXISTER VRAIMENT**
/// (NFR-SU3/AD-13).
///
/// **Leçon su-3 / D8 — le piège exact.** su-3 a dû **retirer** un
/// `AnimatedOpacity(opacity: 1)` qui n'animait rien : l'appel à `zReduceMotionOf`
/// y était **décoratif**, le test **tautologique**, et le tout
/// **invraisemblablement vert**. Ici, la dégradation est **RÉELLE et MESURÉE** :
///
/// - **sans** Reduce Motion : l'indicateur varie **continûment** avec l'offset
///   ⇒ deux offsets distincts donnent deux valeurs **DIFFÉRENTES** ;
/// - **avec** Reduce Motion : apparition **binaire au seuil**, opacité et échelle
///   **fixes** ⇒ les deux valeurs sont **IDENTIQUES**, et l'émoji est bien
///   **PRÉSENT** au-delà du seuil (la FONCTION n'est jamais dégradée — seulement
///   l'ANIMATION, règle su-2/AC3, arbitrage A4).
///
/// Les valeurs sont **OBSERVÉES sur le rendu**, jamais déduites : l'opacité est
/// lue sur le `Opacity` réellement construit, et l'échelle est **mesurée sur la
/// géométrie peinte** de l'icône (cf. `_scaleOf` — lire le champ `transform` du
/// widget aurait été un **faux négatif**, mesuré).
@TestOn('vm')
library;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

/// Monte l'indicateur SEUL, à un offset donné — la façon la plus directe de
/// comparer des valeurs RÉSOLUES à deux offsets exacts.
Future<void> _pumpAt(
  WidgetTester tester, {
  required int offset,
  required bool reduceMotion,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: wrapApp(
        ZSwipeEmotionIndicator(
          offsetPercentage: offset,
          reduceMotion: reduceMotion,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Lit l'opacité **RÉSOLUE** sur le widget rendu.
double _opacityOf(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(ZSwipeEmotionIndicator.opacityKey)).opacity;

/// Mesure l'échelle **RÉELLEMENT APPLIQUÉE**, via la géométrie rendue de
/// l'icône (`getRect` applique les transformations de peinture des ancêtres).
///
/// ⚠️ **Écart de sonde assumé, MESURÉ** (consigné au Dev Agent Record) : le
/// premier jet lisait `tester.widget<Transform>(…).transform.getMaxScaleOnAxis()`
/// et rendait **1.0 aux deux offsets** — alors que `resolvedScale` valait bien
/// 0.6 puis 0.8. `Transform.scale` **ne peuple pas** le champ `transform` du
/// widget (la matrice est calculée par le `RenderTransform`), et
/// `RenderTransform.transform` est un **setter seul**. La sonde mesurait donc
/// une matrice identité — un faux négatif qui aurait fait passer le CODE pour
/// fautif. On mesure désormais l'**effet observable** : la largeur peinte de
/// l'icône (mesuré : 19.2 → 25.6 sans RM ; 32.0 → 32.0 avec RM).
double _scaleOf(WidgetTester tester) => tester.getRect(find.byType(Icon)).width;

void main() {
  group('🔴 AC8 — l\'animation EXISTE : sans RM, deux offsets ⇒ deux valeurs', () {
    testWidgets('opacité ET échelle varient CONTINÛMENT avec l\'offset',
        (tester) async {
      await _pumpAt(tester, offset: 20, reduceMotion: false);
      final opacity20 = _opacityOf(tester);
      final scale20 = _scaleOf(tester);

      await _pumpAt(tester, offset: 60, reduceMotion: false);
      final opacity60 = _opacityOf(tester);
      final scale60 = _scaleOf(tester);

      expect(
        opacity60,
        isNot(closeTo(opacity20, 0.001)),
        reason: '🔴 l\'opacité ne dépend PAS de l\'offset ⇒ il n\'y a AUCUNE '
            'animation à dégrader ⇒ l\'appel à `zReduceMotionOf` serait '
            'DÉCORATIF (défaut D8 de su-3, rejoué)',
      );
      expect(
        scale60,
        isNot(closeTo(scale20, 0.01)),
        reason: '🔴 l\'échelle ne dépend PAS de l\'offset — même défaut',
      );
      // …et le sens de variation est le bon (l'indicateur SUIT le doigt).
      expect(opacity60, greaterThan(opacity20));
      expect(scale60, greaterThan(scale20));
    });
  });

  group('🔴 AC8 — avec RM, l\'animation est RÉELLEMENT supprimée (A4)', () {
    testWidgets(
        '🎯 les MÊMES deux offsets ⇒ valeurs IDENTIQUES, et l\'émoji est PRÉSENT',
        (tester) async {
      await _pumpAt(tester, offset: 20, reduceMotion: true);
      final opacity20 = _opacityOf(tester);
      final scale20 = _scaleOf(tester);
      // 🔒 La FONCTION n'est jamais dégradée : au-delà du seuil, l'indicateur
      // APPARAÎT — Reduce Motion ou non.
      expect(find.byType(Icon), findsOneWidget);
      expect(opacity20, 1.0, reason: 'l\'émoji doit être VISIBLE au-delà du '
          'seuil : dégrader la FONCTION serait une régression d\'accessibilité');

      await _pumpAt(tester, offset: 60, reduceMotion: true);
      final opacity60 = _opacityOf(tester);
      final scale60 = _scaleOf(tester);
      expect(find.byType(Icon), findsOneWidget);

      // 🎯 L'AC : aucune interpolation ne subsiste.
      expect(
        opacity60,
        closeTo(opacity20, 0.001),
        reason: '🔴 R3-I12 : l\'opacité varie ENCORE avec l\'offset sous Reduce '
            'Motion ⇒ la dégradation est fictive',
      );
      expect(
        scale60,
        closeTo(scale20, 0.01),
        reason: '🔴 R3-I12 : l\'échelle varie ENCORE sous Reduce Motion',
      );
    });

    testWidgets('sous le seuil, rien ne s\'affiche (apparition BINAIRE)',
        (tester) async {
      await _pumpAt(tester, offset: 5, reduceMotion: true);
      expect(_opacityOf(tester), 0.0,
          reason: 'apparition binaire AU SEUIL : en-deçà, rien');
      await _pumpAt(tester, offset: 40, reduceMotion: true);
      expect(_opacityOf(tester), 1.0, reason: 'au-delà du seuil : tout');
    });

    testWidgets('aucun drag (offset 0) ⇒ aucun indicateur, RM ou non',
        (tester) async {
      for (final rm in <bool>[false, true]) {
        await _pumpAt(tester, offset: 0, reduceMotion: rm);
        expect(find.byKey(ZSwipeEmotionIndicator.opacityKey), findsNothing);
        expect(find.byType(Icon), findsNothing);
      }
    });
  });

  group(
      '🔴 AC8/NFR-SU3 — 1ᵉʳ point d\'application : le CÂBLAGE `zReduceMotionOf` '
      '→ `ZSwipeEmotionIndicator` (l\'ASSEMBLAGE, pas le widget nu)', () {
    // 🔴 **TROU RÉEL, mesuré et fermé (D6).** Les tests ci-dessus montent
    // `ZSwipeEmotionIndicator` **isolément** et lui **injectent** le booléen en
    // paramètre : ils prouvent que l'indicateur **SAIT** dégrader — jamais que
    // le swiper **le lui DEMANDE**. C'est le motif « prouver la PRÉSENCE d'une
    // capacité au lieu de son ASSOCIATION au code de prod » (leçon su-2/HIGH,
    // su-3/D6b) — le même que celui du D2.
    //
    // Mesure décisive : rompre le câblage dans le `cardBuilder` du swiper
    // (`reduceMotion: false` en dur au lieu de `reduceMotion`) laissait la suite
    // **304/304 VERTE**. Un apprenant ayant activé Reduce Motion recevait
    // l'animation continue pendant le drag — la régression d'accessibilité
    // exacte que NFR-SU3 interdit — sans qu'aucun test ne rougisse.
    //
    // Ce test-ci traverse `MediaQuery` → `zReduceMotionOf` → `cardBuilder` →
    // `ZSwipeEmotionIndicator`. Il est le SEUL à garder cette arête.

    /// Drague la carte de devant à un offset donné **sans relâcher**, et rend
    /// l'opacité **RÉSOLUE** lue sur le nœud de l'indicateur.
    ///
    /// `horizontalOffset` du paquet vaut `(100 * left / threshold).ceil()`
    /// (`card_swiper_state.dart:121`, `threshold` = 50 par défaut) ⇒ un drag de
    /// 10 px donne 20 %, de 30 px donne 60 %.
    Future<double> opacityAfterDrag(
      WidgetTester tester, {
      required bool reduceMotion,
      required double dx,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: wrapApp(
            SizedBox(
              height: 600,
              child: ZSessionCardSwiper(
                queue: const <ZSessionItem>[
                  ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
                  ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
                ],
                cardBuilder: (context, item) =>
                    Center(child: Text(item.flashcardId)),
                passThreshold: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le drag part de la CARTE (zone du pan), jamais de la rangée de nav.
      final gesture = await tester.startGesture(tester.getCenter(find.text('f0')));
      // 🔒 Franchir d'abord le `kTouchSlop` (18 dp) : en-deçà, le
      // `PanGestureRecognizer` n'accepte pas le geste et `onPanUpdate` n'est
      // JAMAIS appelé ⇒ `left` resterait à 0 ⇒ l'indicateur ne serait même pas
      // monté (`_emotion == null` ⇒ `SizedBox.shrink`), et ce test échouerait
      // sur « No element » au lieu de mesurer quoi que ce soit.
      // `dragStartBehavior: DragStartBehavior.start` (défaut du
      // `GestureDetector` du paquet) **écarte** ce delta de franchissement : les
      // deltas qui suivent sont donc seuls à alimenter `_cardAnimation.left`.
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      await gesture.moveBy(Offset(dx, 0));
      await tester.pump();

      final opacity = tester
          .widget<Opacity>(find.byKey(ZSwipeEmotionIndicator.opacityKey))
          .opacity;

      // On relâche proprement (sans quoi le geste fuirait sur le test suivant).
      await gesture.up();
      await tester.pumpAndSettle();
      return opacity;
    }

    testWidgets(
        '🔴 SANS Reduce Motion, l\'opacité SUIT le doigt (deux offsets ⇒ deux '
        'valeurs) — l\'animation est bien RÉELLE', (tester) async {
      final at20 = await opacityAfterDrag(tester, reduceMotion: false, dx: 10);
      final at60 = await opacityAfterDrag(tester, reduceMotion: false, dx: 30);

      // Témoin positif : sans ce contraste, le test ci-dessous serait vert
      // parce que rien n'anime — et non parce que RM dégrade.
      expect(at20, isNot(closeTo(at60, 0.01)),
          reason: '🔴 l\'indicateur n\'interpole PAS avec l\'offset : il n\'y a '
              'aucune animation à dégrader, et le test RM serait vert pour de '
              'mauvaises raisons');
      expect(at20, greaterThan(0));
      expect(at60, greaterThan(at20));
    });

    testWidgets(
        '🔴 SOUS Reduce Motion, le SWIPER demande la dégradation : l\'opacité '
        'est BINAIRE (deux offsets ⇒ une seule valeur)', (tester) async {
      final at20 = await opacityAfterDrag(tester, reduceMotion: true, dx: 10);
      final at60 = await opacityAfterDrag(tester, reduceMotion: true, dx: 30);

      // 🔒 L'ASSOCIATION : c'est le SWIPER qui doit résoudre `zReduceMotionOf`
      // et le relayer. Rompre ce câblage (`reduceMotion: false` en dur) rend
      // l'opacité de nouveau continue ⇒ ces deux valeurs divergent ⇒ ROUGE.
      expect(at20, closeTo(at60, 0.01),
          reason: '🔴 NFR-SU3 : l\'opacité varie encore avec l\'offset SOUS '
              'Reduce Motion ⇒ le swiper ne relaie PAS `zReduceMotionOf` à '
              '`ZSwipeEmotionIndicator` (câblage rompu).');
      // 🔒 …et la FONCTION n'est pas dégradée : l'indicateur apparaît quand même
      // (règle su-2/AC3 — on retire l'animation, jamais l'information).
      expect(at20, 1.0,
          reason: 'au-delà du seuil, l\'indicateur doit apparaître même sous '
              'Reduce Motion');
    });
  });

  group('🔴 AC8 — 2ᵉ point d\'application : la `duration` du CardSwiper', () {
    testWidgets(
        'sous Reduce Motion, le swipe est INSTANTANÉ (`Duration.zero`) — '
        'l\'animation de 200 ms est bien RÉELLE', (tester) async {
      final indices = <int>[];
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrapApp(
            SizedBox(
              height: 600,
              child: ZSessionCardSwiper(
                queue: const <ZSessionItem>[
                  ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
                  ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
                ],
                cardBuilder: (context, item) => Center(child: Text(item.flashcardId)),
                passThreshold: 3,
                onIndexChanged: indices.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      // 🔒 UNE seule frame : à `Duration.zero`, l'animation est déjà terminée.
      // Avec les 200 ms par défaut, il en faudrait ~12 à 60 fps.
      await tester.pump();
      await tester.pump();

      expect(
        indices,
        <int>[1],
        reason: '🔴 le swipe n\'est pas instantané sous Reduce Motion ⇒ la '
            '`duration` n\'a pas été ramenée à `Duration.zero`',
      );
      await tester.pumpAndSettle();
    });
  });
}
