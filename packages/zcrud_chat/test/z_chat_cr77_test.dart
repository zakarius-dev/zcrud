/// **CR-IFFD-77** — les quatre défauts du composer assemblé, mesurés à l'écran
/// par IFFD sur un TECNO KN4 (~360 dp) et fermés ici.
///
/// | # | ce que la CR a mesuré | garde |
/// |---|---|---|
/// | ① | sous 400 dp, avec un glyphe, une bascule ACTIVE est rendue à l'identique d'une bascule au repos | CR77-A : le cas RÉEL (glyphe + largeur < seuil), rendu actif **comparé** au rendu inactif — pour les deux bascules, le déclencheur d'effort et la dictée |
/// | ② | le badge lit `computeEffort.level`, le tap écrit `revealThinkingSteps` | CR77-B : le badge suit le TAP ; et bouger le champ voisin ne change RIEN au rendu de la pièce |
/// | ③ | `ZChatComposerSurface` n'a aucun canal de bordure | CR77-C : la bordure DEMANDÉE est **peinte** (décoration rendue), au rayon du conteneur, réglable en épaisseur ; `clipBehavior` porté et inerte par défaut |
/// | ④ | le déclencheur de dictée compact n'existe pas | CR77-D : la pièce existe, elle change d'état À L'ÉCOUTE, et le socle n'écoute rien |
///
/// ## 🔴 Pourquoi la garde CR-76 ne pouvait pas voir ①
///
/// `showLabel: true` est le défaut du socle : monté ainsi, le libellé est rendu,
/// donc l'emphase aussi. Le défaut n'existe que dans la combinaison
/// **glyphe + compact** — celle que tout téléphone produit, et qu'aucune garde
/// ne montait. Chaque garde de CR77-A monte donc explicitement les deux.
@TestOn('vm')
library;

import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Un glyphe d'hôte neutre et mesurable — le socle n'en fournit jamais.
class _Glyph extends StatelessWidget {
  const _Glyph({this.side = 18});
  final double side;
  @override
  Widget build(BuildContext context) => SizedBox(width: side, height: side);
}

/// Le repli français d'une clé (le registre n'est pas monté ici).
String fb(String key) => kZChatLabelFallbacks[key]!;

/// Le style RÉELLEMENT peint sur le libellé [text], ou `null` s'il n'est pas
/// rendu du tout — la distinction que ① exige (le défaut, c'est l'absence).
TextStyle? painted(WidgetTester tester, String text) {
  final Finder f = find.text(text);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f.first).style;
}

/// Les deux canaux non chromatiques de l'emphase CR-74.
({FontWeight? weight, TextDecoration? decoration}) channels(TextStyle? s) =>
    (weight: s?.fontWeight, decoration: s?.decoration);

void main() {
  group('🔴 CR77-A — ① l\'état actif reste VISIBLE en mode compact', () {
    /// Le cas réel : un glyphe d'hôte EST fourni et `showLabel` est faux.
    testWidgets(
        'CR77-A1 — « Réfléchir » : au repos le compact masque le libellé ; '
        'ACTIVE, elle le garde EMPHASÉ (rendu actif ≠ rendu inactif)',
        (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final String label = fb(kZChatLabelRevealThinking);
      Widget mount() => harness(
        ZChatComposerThinkingToggle(
          controller: settings,
          glyph: const _Glyph(),
          // 🔴 LE cas que la garde CR-76 ne montait pas.
          showLabel: false,
        ),
      );
      await tester.pumpWidget(mount());
      // Au repos : rien à dire, le compact reprend la place (forme lex/f011).
      final TextStyle? rest = painted(tester, label);
      expect(rest, isNull,
          reason: '🔬 le scénario n\'est pas celui qu\'on croit : le compact '
              'ne masque pas le libellé au repos.');
      // 🔴 ACTIVE — c\'est ici que la CR a mesuré DEUX rendus identiques.
      settings.setRevealThinkingSteps(true);
      await tester.pump();
      final TextStyle? active = painted(tester, label);
      expect(active, isNotNull,
          reason: '🔴 défaut ① réinjecté : sous le seuil compact, avec un '
              'glyphe, la bascule ACTIVE n\'a AUCUN canal visible — le glyphe '
              'est rendu à l\'identique et le libellé, seul porteur de '
              'l\'emphase, a disparu.');
      // …et le canal est bien l\'EMPHASE, pas un simple texte : attendu ≠
      // ambiant (l\'ambiant du harness est en graisse normale, sans
      // décoration).
      final TextStyle ambient = DefaultTextStyle.of(
        tester.element(find.byType(ZChatComposerThinkingToggle)),
      ).style;
      expect(channels(active), isNot(channels(ambient)),
          reason: '🔴 le libellé est rendu SANS emphase : le canal visible ne '
              'dit pas « actif », il dit seulement « Réfléchir ».');
      // La sémantique reste, dans les DEUX états (elle s'AJOUTE au visible).
      SemanticsNode? node(bool on) => findSemantics(
        tester,
        (SemanticsNode n) =>
            n.label == label &&
            n.flagsCollection.isToggled ==
                (on ? Tristate.isTrue : Tristate.isFalse),
      );
      expect(node(true), isNotNull);
    });

    testWidgets(
        'CR77-A2 — « Internet » : même règle, même mesure (la CR a basculé '
        'les DEUX)', (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final String label = fb(kZChatLabelCapabilityWebSearch);
      await tester.pumpWidget(
        harness(
          ZChatComposerWebSearchToggle(
            controller: settings,
            glyph: const _Glyph(),
            showLabel: false,
          ),
        ),
      );
      expect(painted(tester, label), isNull,
          reason: '🔬 scénario non atteint : le compact ne masque rien.');
      settings.toggleCapability(kZChatCapabilityWebSearch);
      await tester.pump();
      final TextStyle? active = painted(tester, label);
      expect(active, isNotNull,
          reason: '🔴 défaut ① réinjecté sur « Internet » : la capacité '
              'typée est active et rien ne le montre.');
      final TextStyle ambient = DefaultTextStyle.of(
        tester.element(find.byType(ZChatComposerWebSearchToggle)),
      ).style;
      expect(channels(active), isNot(channels(ambient)));
    });

    testWidgets(
        'CR77-A3 — le déclencheur d\'EFFORT porte une VALEUR : « Automatique » '
        'cède la place, un palier CHOISI reste lisible',
        (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZChatComposerEffortSelector(
              controller: settings,
              glyph: const _Glyph(),
              showLabel: false,
            ),
          ),
        ),
      );
      // Défaut (`responseLength == null`) : rien à dire — le déclencheur est
      // muet, comme les bascules au repos.
      expect(renderedTexts(tester), isEmpty,
          reason: '🔬 scénario non atteint : le compact ne masque rien.');
      settings.setResponseLength(ZChatResponseLength.concise);
      await tester.pump();
      // 🔴 Ici le libellé N'EST PAS emphasé, et c'est correct : il ne dit pas
      // « actif », il EST la valeur (« Concise » vs rien) — le canal visible
      // est sa présence même, ce que lex badge sur sa puce.
      expect(renderedTexts(tester), <String>[fb(kZChatLabelLengthConcise)],
          reason: '🔴 le palier CHOISI est invisible en compact : le '
              'déclencheur perd exactement ce que le badge de lex portait.');
    });

    testWidgets(
        'CR77-A4 — bout en bout dans l\'ASSEMBLÉ, à 360 dp (l\'écran de la '
        'CR) : le tap sur la bascule CHANGE le rendu',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZDefaultChatComposer(
              controller: c.controller,
              settings: settings,
              cursorColor: const Color(0xFF000000),
              // L'hôte réel en fournit toujours (`Icons.psychology`…).
              thinkingGlyph: const _Glyph(),
              webSearchGlyph: const _Glyph(),
              effortGlyph: const _Glyph(),
            ),
          ),
        ),
      );
      final String label = fb(kZChatLabelRevealThinking);
      // 🔬 Le mode compact est bien atteint (sinon la garde serait vraie par
      // vacuité — le libellé serait rendu de toute façon).
      expect(find.text(label), findsNothing,
          reason: '🔬 scénario non atteint : la bande n\'est pas en compact.');
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      expect(settings.settings.value.revealThinkingSteps, isTrue);
      expect(find.text(label), findsOneWidget,
          reason: '🔴 défaut ① réinjecté À L\'ÉCRAN : sur le téléphone de la '
              'CR, basculer « Réfléchir » ne change RIEN de visible sur la '
              'pièce touchée.');
    });

    testWidgets(
        'CR77-A5 — la règle ne s\'applique QU\'aux pièces qui ont un état : '
        '« Outils » et le STOP gardent le compact nu', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              ZChatComposerToolsTrigger(
                onOpen: () {},
                glyph: const _Glyph(),
                showLabel: false,
                badge: const _Glyph(side: 12),
              ),
              ZChatComposerStopTarget(
                controller: c.controller,
                glyph: const _Glyph(),
                showLabel: false,
              ),
            ],
          ),
        ),
      );
      // « Outils » n'a pas d'état : ce qu'il a à dire est dans son BADGE, que
      // le compact garde (lex/f011).
      expect(painted(tester, fb(kZChatLabelTools)), isNull,
          reason: '🔴 le compact ne doit pas se relâcher sur les pièces SANS '
              'état — sinon la règle ① devient « toujours afficher », et le '
              'mode compact n\'existe plus.');
      expect(find.bySemanticsLabel(fb(kZChatLabelTools)), findsOneWidget);
    });
  });

  group('🔴 CR77-B — ② une pièce n\'affiche que la donnée qu\'elle PILOTE', () {
    testWidgets(
        'CR77-B1 — le badge suit le TAP : il reçoit l\'état booléen que le '
        'geste écrit, et change avec lui', (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      const Key on = Key('badge-actif');
      const Key off = Key('badge-repos');
      await tester.pumpWidget(
        harness(
          ZChatComposerThinkingToggle(
            controller: settings,
            badgeBuilder: (BuildContext context, bool active) => SizedBox(
              key: active ? on : off,
              width: 12,
              height: 12,
            ),
          ),
        ),
      );
      expect(find.byKey(off), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(fb(kZChatLabelRevealThinking)));
      await tester.pump();
      expect(settings.settings.value.revealThinkingSteps, isTrue);
      expect(find.byKey(on), findsOneWidget,
          reason: '🔴 défaut ② réinjecté : le badge ne suit pas ce que le tap '
              'change — il commente un champ voisin.');
    });

    testWidgets(
        'CR77-B2 — la DISSOCIATION est inexprimable : bouger le budget (que '
        'cette pièce ne pilote PAS) ne change RIEN à son rendu',
        (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      int builds = 0;
      final List<bool> seen = <bool>[];
      await tester.pumpWidget(
        harness(
          ZChatComposerThinkingToggle(
            controller: settings,
            badgeBuilder: (BuildContext context, bool active) {
              builds++;
              seen.add(active);
              return const SizedBox(width: 12, height: 12);
            },
          ),
        ),
      );
      final List<String> before = renderedTexts(tester);
      final int buildsBefore = builds;
      // 🔴 L'INJECTION de la dissociation : on bouge EXACTEMENT le champ que
      // la rédaction CR-76 affichait — `computeEffort`. La pièce ne le pilote
      // pas : elle ne doit rien en dire.
      settings.setComputeEffort(ZChatComputeEffort.high);
      await tester.pump();
      expect(settings.settings.value.computeEffort?.level, 5,
          reason: '🔬 scénario non atteint : le budget n\'a pas bougé.');
      expect(renderedTexts(tester), before,
          reason: '🔴 défaut ② réinjecté : le rendu de la bascule a changé '
              'alors que son propre état n\'a pas bougé — elle affiche une '
              'donnée qu\'elle ne pilote pas.');
      expect(seen.skip(buildsBefore).every((bool a) => a == false), isTrue,
          reason: '🔴 le badge a reçu autre chose que l\'état de la bascule.');
      // Et l'état annoncé, lui, n'a pas bougé non plus.
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == fb(kZChatLabelRevealThinking) &&
              n.flagsCollection.isToggled == Tristate.isFalse,
        ),
        isNotNull,
      );
    });

    test('CR77-B3 — grep NÉGATIF : la bascule ne LIT plus un champ qu\'elle '
        'n\'écrit pas', () {
      final List<String> lines = <String>[];
      bool inside = false;
      for (final String l
          in stripped(libFile('lib/src/presentation/view/z_chat_composer_band.dart'))) {
        if (l.startsWith('class ZChatComposerThinkingToggle')) {
          inside = true;
        } else if (inside && l.startsWith('class ')) {
          inside = false;
        }
        if (inside) {
          lines.add(l);
        }
      }
      expect(lines, isNotEmpty, reason: '🔬 la classe n\'a pas été trouvée.');
      expect(
        lines.where((String l) => l.contains('computeEffort')),
        isEmpty,
        reason: '🔴 défaut ② réinjecté en source : la bascule lit de nouveau '
            'le budget — le champ que son tap n\'écrit pas.',
      );
    });
  });

  group('🔴 CR77-C — ③ le canal de BORDURE de la surface', () {
    /// La décoration RÉELLEMENT peinte par la surface, ou `null`.
    BoxDecoration? decorationOf(WidgetTester tester) {
      final Finder f = find.descendant(
        of: find.byType(ZChatComposerSurface),
        matching: find.byType(DecoratedBox),
      );
      if (f.evaluate().isEmpty) return null;
      return tester.widget<DecoratedBox>(f.first).decoration as BoxDecoration;
    }

    testWidgets(
        'CR77-C1 — la bordure DEMANDÉE est peinte, à la couleur d\'hôte, à '
        'l\'épaisseur de référence, au rayon du CONTENEUR',
        (WidgetTester tester) async {
      const Color role = Color(0xFF445566);
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(
            borderColor: role,
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      final BoxDecoration? deco = decorationOf(tester);
      expect(deco, isNotNull,
          reason: '🔴 la bordure demandée n\'est pas PEINTE : le paramètre '
              'existe mais ne produit aucune décoration.');
      final Border? border = deco!.border as Border?;
      expect(border, isNotNull);
      expect(border!.top.color, role);
      expect(border.top.width, ZChatComposerReference.borderWidth);
      // 🔴 UN SEUL rayon : c'est ce qui supprime le second conteneur de
      // l'hôte (les deux rayons ne peuvent plus diverger).
      expect(
        deco.borderRadius,
        const BorderRadius.all(ZChatComposerReference.containerRadius),
      );
      // …et le filet n'a pas de côté (AD-13) : les quatre sont identiques.
      expect(border.left, border.right);
      expect(border.top, border.bottom);
      // Pas de fond inventé au passage (FR-26).
      expect(deco.color, isNull);
    });

    testWidgets('CR77-C2 — sans couleur d\'hôte : AUCUNE décoration (FR-26)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(child: SizedBox(width: 100, height: 40)),
        ),
      );
      expect(decorationOf(tester), isNull,
          reason: '🔴 le socle a inventé une bordure.');
    });

    testWidgets(
        'CR77-C3 — l\'épaisseur passe par la chaîne du chrome (attendu ≠ '
        'ambiant : 4 ≠ référence 1)', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(
            borderColor: Color(0xFF445566),
            chrome: ZChatComposerChrome(borderWidth: 4),
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      expect(ZChatComposerReference.borderWidth, isNot(4),
          reason: '🔬 attendu == ambiant : la garde ne prouverait rien.');
      expect((decorationOf(tester)!.border! as Border).top.width, 4);
    });

    testWidgets(
        'CR77-C4 — `clipBehavior` : inerte par défaut, et sinon rogné au MÊME '
        'rayon que la décoration', (WidgetTester tester) async {
      Finder clip() => find.descendant(
        of: find.byType(ZChatComposerSurface),
        matching: find.byType(ClipRRect),
      );
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(
            borderColor: Color(0xFF445566),
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      expect(clip(), findsNothing,
          reason: '🔴 une couche de composition posée sans que l\'hôte l\'ait '
              'demandée (lex la pose ; ici elle serait inutile — mesuré).');
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(
            borderColor: Color(0xFF445566),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      expect(clip(), findsOneWidget);
      final ClipRRect r = tester.widget<ClipRRect>(clip());
      expect(r.clipBehavior, Clip.antiAlias);
      expect(
        r.borderRadius,
        const BorderRadius.all(ZChatComposerReference.containerRadius),
        reason: '🔴 DEUX rayons : le rognage ne suit pas la décoration — le '
            'montage manuel que CR-76 avait supprimé, réintroduit dans le '
            'socle.',
      );
      // Le clip existe AUSSI sans décoration (un enfant peut peindre même
      // sans fond) — un seul chemin, pas deux régimes.
      await tester.pumpWidget(
        harness(
          const ZChatComposerSurface(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      expect(clip(), findsOneWidget);
    });

    testWidgets(
        'CR77-C5 — l\'assemblé CÂBLE le canal jusqu\'à la surface (bout en '
        'bout)', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      const Color role = Color(0xFF778899);
      await tester.pumpWidget(
        harness(
          ZDefaultChatComposer(
            controller: c.controller,
            settings: settings,
            cursorColor: const Color(0xFF000000),
            borderColor: role,
          ),
        ),
      );
      expect(
        ((decorationOf(tester)!.border!) as Border).top.color,
        role,
        reason: '🔴 l\'assemblé ne transmet pas la bordure à sa surface : '
            'l\'hôte devrait de nouveau envelopper d\'un second conteneur.',
      );
    });
  });

  group('🔴 CR77-D — ④ le DÉCLENCHEUR de dictée compact', () {
    testWidgets('CR77-D1 — sans geste d\'hôte : AUCUN déclencheur (AD-4)',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZDefaultChatComposer(
            controller: c.controller,
            settings: settings,
            cursorColor: const Color(0xFF000000),
          ),
        ),
      );
      expect(find.byType(ZChatComposerDictationTrigger), findsNothing,
          reason: '🔴 un micro sans moteur est une affordance inerte — le '
              'défaut du menu `+` d\'IFFD.');
    });

    testWidgets(
        'CR77-D2 — monté dans la BANDE, le geste remonte à l\'hôte, et le '
        'socle n\'écoute rien', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      int gestes = 0;
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZDefaultChatComposer(
              controller: c.controller,
              settings: settings,
              cursorColor: const Color(0xFF000000),
              onDictate: () => gestes++,
            ),
          ),
        ),
      );
      expect(find.byType(ZChatComposerDictationTrigger), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(fb(kZChatLabelDictate)));
      await tester.pump();
      expect(gestes, 1,
          reason: '🔴 le socle a intercepté le geste : la dictée est un '
              'choix d\'application (port d\'hôte).');
    });

    testWidgets(
        'CR77-D3 — À L\'ÉCOUTE le déclencheur CHANGE : étiquette, glyphe, '
        'drapeau `toggled` et région live', (WidgetTester tester) async {
      final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
      addTearDown(listening.dispose);
      const Key repos = Key('glyphe-repos');
      const Key ecoute = Key('glyphe-ecoute');
      await tester.pumpWidget(
        harness(
          ZChatComposerDictationTrigger(
            onTap: () {},
            listening: listening,
            glyph: const SizedBox(key: repos, width: 18, height: 18),
            listeningGlyph: const SizedBox(key: ecoute, width: 18, height: 18),
          ),
        ),
      );
      expect(find.byKey(repos), findsOneWidget);
      expect(find.text(fb(kZChatLabelDictate)), findsOneWidget);
      SemanticsNode? node({required bool on, required bool live}) =>
          findSemantics(
            tester,
            (SemanticsNode n) =>
                n.label ==
                    fb(on ? kZChatLabelStopDictation : kZChatLabelDictate) &&
                n.flagsCollection.isToggled ==
                    (on ? Tristate.isTrue : Tristate.isFalse) &&
                n.flagsCollection.isLiveRegion == live,
          );
      expect(node(on: false, live: false), isNotNull);
      // 🔴 L'état est INJECTÉ par l'hôte — le socle n'ouvre aucun micro.
      listening.value = true;
      await tester.pump();
      expect(find.byKey(ecoute), findsOneWidget,
          reason: '🔴 le glyphe ne change pas pendant l\'écoute.');
      expect(find.byKey(repos), findsNothing);
      expect(find.text(fb(kZChatLabelStopDictation)), findsOneWidget,
          reason: '🔴 l\'étiquette ne dit pas que le micro écoute.');
      expect(node(on: true, live: true), isNotNull,
          reason: '🔴 l\'écoute est VISIBLE mais pas ANNONCÉE — le défaut lex '
              'que CHAT-10 a déjà fermé sur la bande de capture.');
    });

    testWidgets(
        'CR77-D4 — en COMPACT avec glyphe : muet au repos, libellé rendu à '
        'l\'écoute (règle ①)', (WidgetTester tester) async {
      final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
      addTearDown(listening.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposerDictationTrigger(
            onTap: () {},
            listening: listening,
            glyph: const _Glyph(),
            showLabel: false,
          ),
        ),
      );
      expect(painted(tester, fb(kZChatLabelDictate)), isNull);
      listening.value = true;
      await tester.pump();
      expect(painted(tester, fb(kZChatLabelStopDictation)), isNotNull,
          reason: '🔴 sur téléphone, rien ne dirait que le micro écoute.');
    });

    testWidgets(
        'CR77-D5 — AD-13 : la cible fait ≥ 48 dp en GÉOMÉTRIE RENDUE, dans '
        'les deux états, et reste bornée par le haut',
        (WidgetTester tester) async {
      final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
      addTearDown(listening.dispose);
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatComposerDictationTrigger(
              onTap: () {},
              listening: listening,
              glyph: const _Glyph(),
              showLabel: false,
            ),
          ),
        ),
      );
      for (final bool on in <bool>[false, true]) {
        listening.value = on;
        await tester.pump();
        final Size size = tester.getSize(
          find.byType(ZChatComposerDictationTrigger),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        // Bornée par le HAUT : sans les facteurs d'`Align`, une cible de 600
        // dp passerait la garde pour la mauvaise raison (mesuré ailleurs).
        expect(size.height, lessThan(120));
      }
    });

    testWidgets(
        'CR77-D6 — sans tranche d\'écoute injectée : le déclencheur existe et '
        'reste au repos (un seul chemin de rendu)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          ZChatComposerDictationTrigger(
            onTap: () {},
            glyph: const _Glyph(),
          ),
        ),
      );
      expect(find.text(fb(kZChatLabelDictate)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CR77-D7 — RTL : le déclencheur ne lève pas et reste en tête '
        'de bande (AD-13)', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZDefaultChatComposer(
              controller: c.controller,
              settings: settings,
              cursorColor: const Color(0xFF000000),
              onDictate: () {},
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.takeException(), isNull);
      final double mic = tester
          .getCenter(find.byType(ZChatComposerDictationTrigger))
          .dx;
      final double effort = tester
          .getCenter(find.byType(ZChatComposerEffortSelector))
          .dx;
      expect(mic, greaterThan(effort),
          reason: '🔴 en RTL la tête de bande doit passer à DROITE.');
    });
  });
}
