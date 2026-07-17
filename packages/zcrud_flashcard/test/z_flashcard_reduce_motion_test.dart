/// AC3 — Reduce Motion : **jamais** de flip animé (SU-2, NFR-SU3 / AD-13).
///
/// ⚠️ **su-2 est le PREMIER traitement Reduce Motion du repo** : il fixe le
/// patron que su-4 (drag statique) et su-5 (confetti supprimé) réutiliseront.
///
/// ⚠️ **Test tautologique explicitement PROSCRIT ici** : `expect(
/// disableAnimations, isTrue)` ne prouverait rien — il testerait `MediaQuery`,
/// pas le widget. **Toutes** les assertions ci-dessous portent sur l'**arbre
/// rendu**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const ZFlashcard _card = ZFlashcard(question: 'Q', answer: 'A');

/// Monte la carte sous un `MediaQuery` dont Reduce Motion est [disableAnimations].
Future<void> _pump(
  WidgetTester tester, {
  required bool disableAnimations,
  ZRevealTransition transition = ZRevealTransition.flip3d,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: ZFlashcardReviewCard(
                  card: _card,
                  revealTransition: transition,
                ),
              ),
            ),
          ),
        ),
      ),
    );

bool _hasYRotation(Matrix4 m) =>
    m.entry(0, 2).abs() > 1e-6 || m.entry(2, 0).abs() > 1e-6;

bool _anyYRotation(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .any((t) => _hasYRotation(t.transform));

void main() {
  testWidgets(
    'AC3 — Reduce Motion + flip3d : AUCUNE rotation Y à AUCUN instant de la '
    'révélation (Reduce Motion PRIME sur l\'enum)',
    (tester) async {
      await _pump(tester, disableAnimations: true);
      expect(_anyYRotation(tester), isFalse);

      await tester.tap(find.byType(ZFlashcardReviewCard));

      // Échantillonnage SUR TOUTE la durée nominale (250 ms) : si la moindre
      // frame portait une rotation, la garde la verrait. Assertion sur l'ARBRE.
      for (var elapsed = 0; elapsed <= 300; elapsed += 25) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(_anyYRotation(tester), isFalse,
            reason: 'rotation Y trouvée à ~$elapsed ms alors que Reduce Motion '
                'est actif : `disableAnimations` est IGNORÉ (seule la valeur de '
                'l\'enum est lue ?)');
      }
    },
  );

  testWidgets(
    'AC3 — Reduce Motion : la réponse est présente IMMÉDIATEMENT (dégradation '
    'de l\'ANIMATION, jamais de la FONCTION)',
    (tester) async {
      await _pump(tester, disableAnimations: true);
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('A'), findsNothing);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump(); // UNE seule frame — aucune animation attendue

      expect(find.text('A'), findsOneWidget,
          reason: 'la révélation a été ANNULÉE par Reduce Motion : seule '
              'l\'animation doit être dégradée, jamais la fonction');
      expect(find.text('Q'), findsNothing);
    },
  );

  testWidgets(
    'AC3 — Reduce Motion + fade : aucune opacité intermédiaire (instantané)',
    (tester) async {
      await _pump(
        tester,
        disableAnimations: true,
        transition: ZRevealTransition.fade,
      );
      await tester.tap(find.byType(ZFlashcardReviewCard));

      for (var elapsed = 0; elapsed <= 300; elapsed += 25) {
        await tester.pump(const Duration(milliseconds: 25));
        final partial = tester
            .widgetList<Opacity>(find.byType(Opacity))
            .any((o) => o.opacity > 0.0 && o.opacity < 1.0);
        expect(partial, isFalse,
            reason: 'fondu en cours à ~$elapsed ms malgré Reduce Motion');
      }
      expect(find.text('A'), findsOneWidget);
    },
  );

  testWidgets(
    'AC3 — la bascule INVERSE (réponse→question) respecte aussi Reduce Motion',
    (tester) async {
      await _pump(tester, disableAnimations: true);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      expect(find.text('A'), findsOneWidget);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();

      expect(find.text('Q'), findsOneWidget);
      expect(_anyYRotation(tester), isFalse);
    },
  );

  testWidgets(
    'CONTRE-PREUVE — la garde a du POUVOIR : sans Reduce Motion, la MÊME '
    'sonde TROUVE bien la rotation',
    (tester) async {
      // Sans ce cas, tous les `isFalse` ci-dessus resteraient verts même si la
      // sonde était aveugle (garde morte). On exerce ici la MÊME fonction
      // `_anyYRotation`, sur le MÊME widget, en changeant SEULEMENT le signal.
      await _pump(tester, disableAnimations: false);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_anyYRotation(tester), isTrue,
          reason: 'la sonde ne détecte AUCUNE rotation même sans Reduce '
              'Motion : elle est aveugle, donc les assertions isFalse '
              'ci-dessus ne prouvent RIEN');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '🔴 D12 — canal 1 (`_toggle`) : Reduce Motion ⇒ AUCUNE animation n\'est '
    'même LANCÉE',
    (tester) async {
      // ⚠️ Les deux canaux Reduce Motion (`_toggle` court-circuite le
      // controller, `_animatedFace` court-circuite la rotation) se MASQUAIENT :
      // retirer l'un OU l'autre laissait 6/6 VERT — seul le retrait des DEUX
      // rougissait. Chaque canal doit avoir une garde qui rougit SEULE.
      //
      // Ce cas isole `_toggle` : sans lui, `_controller.forward()` lance une
      // vraie animation de 250 ms. Les gardes de rotation ne peuvent PAS le
      // voir directement (avec `_animatedFace` intact, aucune rotation n'est
      // construite de toute façon) — le controller tourne pourtant : ticker,
      // batterie et jank pour un utilisateur qui a refusé les animations.
      //
      // ⚠️ `tester.hasRunningAnimations` ne discrimine PAS : le ripple de
      // l'`InkWell` tourne lui aussi après un tap, quelle que soit la branche.
      // On lit donc la VALEUR du controller — en rallumant les animations sans
      // y retoucher, la face redevient une rotation qui l'EXPOSE.
      await _pump(tester, disableAnimations: true);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump(); // révélation instantanée attendue
      await tester.pump(const Duration(milliseconds: 100)); // le temps passe

      await _pump(tester, disableAnimations: false);
      await tester.pump();

      expect(_anyYRotation(tester), isFalse,
          reason: 'le controller est à mi-course : `_toggle` a lancé une VRAIE '
              'animation (`forward()`) malgré Reduce Motion au lieu de poser '
              'directement sa valeur finale');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '🔴 D12 — canal 2 (`_animatedFace`) : Reduce Motion activé PENDANT une '
    'animation en vol la neutralise immédiatement',
    (tester) async {
      // Ce cas isole `_animatedFace` : c'est le SEUL scénario qui l'exerce sans
      // passer par `_toggle` (le réglage change alors que le controller est
      // déjà à mi-course). Sans ce canal, la rotation continue de se construire
      // pour un utilisateur qui vient de demander l'arrêt des animations.
      await _pump(tester, disableAnimations: false);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50)); // flip EN VOL
      expect(_anyYRotation(tester), isTrue,
          reason: 'aucune rotation en vol : le scénario n\'exerce rien');

      // L'utilisateur active Reduce Motion pendant le flip.
      await _pump(tester, disableAnimations: true);
      await tester.pump();

      expect(_anyYRotation(tester), isFalse,
          reason: 'la rotation SURVIT à l\'activation de Reduce Motion : '
              '`_animatedFace` ne consulte pas le signal (seul `_toggle` le '
              'ferait, et il est déjà passé)');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'AC3 — le signal est bien `disableAnimations` et NON `accessibleNavigation`',
    (tester) async {
      // `accessibleNavigation` désigne le LECTEUR D'ÉCRAN, pas la réduction
      // d'animations : les confondre priverait d'animation des utilisateurs qui
      // n'ont rien demandé. Discriminant : lecteur d'écran actif SANS Reduce
      // Motion ⇒ l'animation DOIT rester.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(card: _card),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_anyYRotation(tester), isTrue,
          reason: '`accessibleNavigation` a supprimé l\'animation : le mauvais '
              'signal est lu (il désigne le lecteur d\'écran, pas Reduce Motion)');

      await tester.pumpAndSettle();
    },
  );
}
