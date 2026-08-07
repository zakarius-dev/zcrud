/// Lot K2 (chantier composer-lex) — gardes du CHROME du composer (S1).
///
/// Ce que ce fichier MESURE, sur un sujet réellement monté :
/// * **CHR-T** — la priorité **paramètre > jeton > référence**, les TROIS
///   niveaux atteints SÉPARÉMENT (un test qui ne prouverait que « paramètre
///   gagne » serait vert sur une implémentation qui ignore le jeton) ;
/// * **CHR-P** — le plancher AD-13 : les 40 dp du legacy sont INEXPRIMABLES,
///   même demandés explicitement ;
/// * **CHR-A** — l'exception FR-26 encadrée : les trois teintes lex EXACTES,
///   remplaçables clé par clé, jamais en bloc ;
/// * **CHR-S** — le créneau d'envoi par défaut : géométrie RENDUE ≥ 48 dp,
///   échelle 0.7 → 1.0, transition NEUTRALISÉE sous Reduce Motion (mesuré,
///   dans les deux sens) ;
/// * **CHR-H** — le placeholder animé : il TOURNE sans Reduce Motion, il est
///   INERTE avec (le défaut lex — aucune garde — n'est pas reproduit) ;
/// * **CHR-N** — le créneau `hint` du composer : règle des trois cas, et la
///   visibilité reste pilotée par la vacuité de la saisie.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

/// Force `disableAnimations` SOUS le `MediaQuery` du harnais — le chemin exact
/// qu'emprunte un vrai réglage d'accessibilité.
Widget reduceMotion(Widget child) => Builder(
  builder: (BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

void main() {
  group('🔴 CHR-T — paramètre > jeton > référence, TROIS niveaux SÉPARÉS', () {
    testWidgets('CHR-T3 — sans paramètre NI scope, la RÉFÉRENCE lex', (
      WidgetTester tester,
    ) async {
      late ZChatComposerChromeStyle style;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              style = zChatComposerChromeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.containerRadius, const Radius.circular(12),
          reason: '🔴 la référence lex (`chat_input.dart:482`) n\'est plus le '
              'dernier ressort');
      expect(style.sendScaleIdle, 0.7);
      expect(style.sendScaleDuration, const Duration(milliseconds: 150));
      expect(style.mobileBreakpoint, 400);
      expect(
        style.fieldContentPadding,
        const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 4),
      );
    });

    testWidgets('CHR-T2 — sans paramètre, le JETON du scope l\'emporte sur la '
        'référence', (WidgetTester tester) async {
      late ZChatComposerChromeStyle style;
      await tester.pumpWidget(
        harness(
          ZcrudScope(
            theme: const ZcrudTheme(radiusM: Radius.circular(3)),
            child: Builder(
              builder: (BuildContext context) {
                style = zChatComposerChromeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(style.containerRadius, const Radius.circular(3),
          reason: '🔴 le jeton `radiusM` est IGNORÉ : le niveau 2 n\'existe '
              'pas — la « chaîne » n\'a que deux maillons');
    });

    testWidgets('CHR-T1 — le PARAMÈTRE l\'emporte sur le jeton', (
      WidgetTester tester,
    ) async {
      late ZChatComposerChromeStyle style;
      await tester.pumpWidget(
        harness(
          ZcrudScope(
            theme: const ZcrudTheme(radiusM: Radius.circular(3)),
            child: Builder(
              builder: (BuildContext context) {
                style = zChatComposerChromeOf(
                  context,
                  chrome: const ZChatComposerChrome(
                    containerRadius: Radius.circular(7),
                  ),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(style.containerRadius, const Radius.circular(7),
          reason: '🔴 le paramètre est IGNORÉ face au jeton');
    });
  });

  group('🔴 CHR-P — le plancher AD-13 est INEXPRIMABLE à contourner', () {
    testWidgets('demander 20 dp rend 48 dp', (WidgetTester tester) async {
      late ZChatComposerChromeStyle style;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              style = zChatComposerChromeOf(
                context,
                chrome: const ZChatComposerChrome(sendTargetSize: 20),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.sendTargetSize, 48,
          reason: '🔴 le legacy envoie depuis 40 dp ; si 20 passe, 40 passe '
              'aussi — le plancher est décoratif');
    });
  });

  group('🔴 CHR-A — les 3 teintes lex, exception FR-26 encadrée', () {
    test('les valeurs EXACTES de `chat_enums.dart:42-46`, indexées kernel', () {
      expect(
        ZChatComposerReference.responseLengthAccents,
        <ZChatResponseLength, Color>{
          ZChatResponseLength.concise: const Color(0xFF4CAF50),
          ZChatResponseLength.standard: const Color(0xFF2196F3),
          ZChatResponseLength.detailed: const Color(0xFF9C27B0),
        },
        reason: '🔴 la référence a dérivé du relevé lex — ou une teinte a été '
            'ajoutée hors mesure',
      );
    });

    testWidgets('un accent de PARAMÈTRE remplace SA clé sans toucher les '
        'autres', (WidgetTester tester) async {
      late ZChatComposerChromeStyle style;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              style = zChatComposerChromeOf(
                context,
                chrome: const ZChatComposerChrome(
                  responseLengthAccents: <ZChatResponseLength, Color>{
                    ZChatResponseLength.concise: Color(0xFF000001),
                  },
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(style.responseLengthAccent(ZChatResponseLength.concise),
          const Color(0xFF000001));
      expect(style.responseLengthAccent(ZChatResponseLength.standard),
          const Color(0xFF2196F3),
          reason: '🔴 remplacer UNE clé a effacé les autres : la table est '
              'consultée en bloc, pas clé par clé');
    });
  });

  group('🔴 CHR-S — le créneau d\'envoi par défaut', () {
    Widget mount(
      ZChatController controller, {
      bool reduce = false,
      VoidCallback? submit,
    }) {
      final Widget target = Builder(
        builder: (BuildContext context) => ZChatComposerSendTarget(
          slot: ZChatComposerSlot(
            controller: controller,
            submit: submit ?? () {},
          ),
          child: const SizedBox(width: 10, height: 10),
        ),
      );
      return harness(reduce ? reduceMotion(target) : target);
    }

    testWidgets('CHR-S1 — géométrie RENDUE ≥ 48 dp, échelle 0.7 puis 1.0', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(mount(rig.controller));

      final Size size = tester.getSize(find.byType(ZChatComposerSendTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '🔴 la cible d\'envoi rend moins de 48 dp — le défaut '
              'legacy (40 dp) est de retour');

      AnimatedScale scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale().scale, 0.7,
          reason: '🔴 saisie vide ⇒ échelle 0.7 (lex `:674-676`)');
      rig.controller.composer.text = 'x';
      await tester.pump();
      expect(scale().scale, 1.0,
          reason: '🔴 saisie non vide ⇒ échelle 1.0');
      expect(scale().duration, const Duration(milliseconds: 150));
    });

    testWidgets('CHR-S2 — Reduce Motion ⇒ transition en Duration.zero, état '
        'final identique', (WidgetTester tester) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(mount(rig.controller, reduce: true));

      final AnimatedScale scale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero,
          reason: '🔴 sous « réduire les animations », la transition doit être '
              'INSTANTANÉE — pas simplement plus courte');
      rig.controller.composer.text = 'x';
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
        reason: '🔴 l\'état FINAL doit rester identique : Reduce Motion retire '
            'l\'animation, jamais l\'information',
      );
    });

    testWidgets('CHR-S3 — le tap emprunte `slot.submit` — le site UNIQUE', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      int submits = 0;
      await tester.pumpWidget(
        mount(rig.controller, submit: () => submits++),
      );
      await tester.tap(find.byType(ZChatComposerSendTarget));
      expect(submits, 1,
          reason: '🔴 le créneau n\'appelle pas la fermeture fournie : il '
              's\'est inventé un chemin d\'envoi');
    });
  });

  group('🔴 CHR-H — le placeholder animé, et sa garde Reduce Motion', () {
    testWidgets('CHR-H1 — SANS Reduce Motion, la rotation TOURNE (4 s)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ZChatComposerAnimatedHint(
            hints: <String>['premier', 'second'],
          ),
        ),
      );
      expect(find.text('premier'), findsOneWidget);
      expect(find.text('second'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400)); // fondu 350 ms
      expect(find.text('second'), findsOneWidget,
          reason: '🔴 la rotation ne tourne pas : la « référence 4 s » est '
              'décorative');
      expect(find.text('premier'), findsNothing,
          reason: '🔴 l\'ancien libellé n\'est jamais retiré : le fondu '
              'n\'aboutit pas');
    });

    testWidgets('CHR-H2 — AVEC Reduce Motion, INERTE : premier libellé figé, '
        'aucun minuteur', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          reduceMotion(
            const ZChatComposerAnimatedHint(
              hints: <String>['premier', 'second'],
            ),
          ),
        ),
      );
      expect(find.text('premier'), findsOneWidget);
      // 🔴 MESURÉ, pas affirmé : trois périodes complètes plus tard, rien n'a
      // bougé. (Et un `Timer.periodic` restant ferait échouer le test au
      // démontage — c'est la preuve « aucun minuteur ».)
      await tester.pump(const Duration(seconds: 13));
      expect(find.text('premier'), findsOneWidget,
          reason: '🔴 le placeholder anime SOUS Reduce Motion — le défaut lex '
              '(`chat_input.dart:1162`, aucune garde) est reproduit');
      expect(find.text('second'), findsNothing);
    });
  });

  group('🔴 CHR-N — le créneau `hint` du composer (règle des trois cas)', () {
    Widget composer(
      ZChatController controller, {
      ZChatComposerSlotBuilder? hint,
    }) => harness(
      ZChatComposer(
        controller: controller,
        cursorColor: _cursor,
        hint: hint,
      ),
    );

    testWidgets('fourni ⇒ REMPLACE l\'invite, et la frappe le cache toujours', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        composer(
          rig.controller,
          hint: (BuildContext context, ZChatComposerSlot slot) =>
              const Text('invite hôte'),
        ),
      );
      expect(find.text('invite hôte'), findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelComposerHint]!),
          findsNothing,
          reason: '🔴 l\'invite d\'hôte s\'AJOUTE au lieu de remplacer');
      rig.controller.composer.text = 'x';
      await tester.pump();
      expect(find.text('invite hôte'), findsNothing,
          reason: '🔴 l\'invite d\'hôte survit à la frappe : la visibilité '
              'n\'est plus pilotée par la vacuité de la saisie');
    });

    testWidgets('rendant `null` ⇒ AUCUNE invite (AD-4) ; absent ⇒ défaut', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final String fallback =
          kZChatLabelFallbacks[kZChatLabelComposerHint]!;

      await tester.pumpWidget(
        composer(
          rig.controller,
          hint: (BuildContext context, ZChatComposerSlot slot) => null,
        ),
      );
      expect(find.text(fallback), findsNothing,
          reason: '🔴 un builder rendant `null` doit RETIRER l\'invite, pas '
              'retomber sur le défaut');

      await tester.pumpWidget(composer(rig.controller));
      expect(find.text(fallback), findsOneWidget,
          reason: '🔴 sans builder, l\'invite par défaut a disparu : le '
              'comportement d\'avant le lot n\'est plus le défaut');
    });
  });
}
