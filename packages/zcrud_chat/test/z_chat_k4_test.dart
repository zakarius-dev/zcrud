/// Lot K4 (chantier composer-lex) — le MAILLON JETON branché, et gardé
/// branché.
///
/// Ce que ce fichier MESURE, sur des sujets réellement montés :
/// * **K4-CH** — les jetons du chrome posés dans `zcrud_core` sont ATTEINTS
///   par `zChatComposerChromeOf` (niveau 2), le paramètre les bat (niveau 1),
///   et le plancher AD-13 écrête AUSSI un jeton (les 40 dp du legacy restent
///   inexprimables par thème) ;
/// * **K4-EM** — les deux jetons d'emphase CR-IFFD-74
///   (`chatSelectedEmphasisWeight`/`Decoration`) s'insèrent ENTRE le paramètre
///   et la référence, mesurés sur le style RENDU de l'option choisie ;
/// * **K4-CA** — la famille « capacités » par défaut : l'entrée recherche web
///   du socle (la seule qu'il nomme), les entrées d'HÔTE, l'écriture par le
///   champ TYPÉ pour la clé réservée, la règle des trois cas ;
/// * **K4-CT** — `activeCount` compte les capacités (F12 élargi), et les
///   gestes existants ne PERDENT pas les champs K1 (`_with` transporte) ;
/// * **K4-PR** — un préréglage TRANSPORTE les champs K1 tels quels, et
///   `clearPreset` restitue l'état EXACT d'avant — mesuré entre deux états
///   DIFFÉRENTS (non vacant).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_render_harness.dart';

/// Monte [child] sous un `ZcrudScope` porteur du [theme] — le niveau 2.
Widget themed(Widget child, {required ZcrudTheme theme}) =>
    harness(ZcrudScope(theme: theme, child: child));

void main() {
  group('🔴 K4-CH — les jetons du chrome, ATTEINTS puis BATTUS', () {
    const ZcrudTheme tokens = ZcrudTheme(
      chatComposerSendTargetSize: 56,
      chatComposerSendScaleIdle: 0.5,
      chatComposerSendScaleActive: 0.9,
      chatComposerSendScaleDuration: Duration(milliseconds: 220),
      chatComposerMobileBreakpoint: 512,
      chatComposerHintRotationPeriod: Duration(seconds: 6),
      chatComposerHintSwitchDuration: Duration(milliseconds: 240),
      chatResponseLengthAccents: <String, Color>{'concise': Color(0xFF0000AA)},
    );

    Future<ZChatComposerChromeStyle> resolve(
      WidgetTester tester, {
      ZcrudTheme? theme,
      ZChatComposerChrome? chrome,
    }) async {
      late ZChatComposerChromeStyle style;
      final Widget probe = Builder(
        builder: (BuildContext context) {
          style = zChatComposerChromeOf(context, chrome: chrome);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        theme == null ? harness(probe) : themed(probe, theme: theme),
      );
      return style;
    }

    testWidgets('K4-CH1 — SANS paramètre, chaque jeton est ATTEINT', (
      WidgetTester tester,
    ) async {
      final ZChatComposerChromeStyle style =
          await resolve(tester, theme: tokens);
      expect(style.sendTargetSize, 56,
          reason: '🔴 le jeton `chatComposerSendTargetSize` est IGNORÉ : le '
              'niveau 2 n\'existe pas pour ce champ');
      expect(style.sendScaleIdle, 0.5);
      expect(style.sendScaleActive, 0.9);
      expect(style.sendScaleDuration, const Duration(milliseconds: 220));
      expect(style.mobileBreakpoint, 512);
      expect(style.hintRotationPeriod, const Duration(seconds: 6));
      expect(style.hintSwitchDuration, const Duration(milliseconds: 240));
    });

    testWidgets('K4-CH2 — le PARAMÈTRE bat chaque jeton', (
      WidgetTester tester,
    ) async {
      final ZChatComposerChromeStyle style = await resolve(
        tester,
        theme: tokens,
        chrome: const ZChatComposerChrome(
          sendTargetSize: 64,
          sendScaleIdle: 0.6,
          sendScaleActive: 1.2,
          sendScaleDuration: Duration(milliseconds: 90),
          mobileBreakpoint: 333,
          hintRotationPeriod: Duration(seconds: 2),
          hintSwitchDuration: Duration(milliseconds: 111),
        ),
      );
      expect(style.sendTargetSize, 64,
          reason: '🔴 le paramètre est IGNORÉ face au jeton');
      expect(style.sendScaleIdle, 0.6);
      expect(style.sendScaleActive, 1.2);
      expect(style.sendScaleDuration, const Duration(milliseconds: 90));
      expect(style.mobileBreakpoint, 333);
      expect(style.hintRotationPeriod, const Duration(seconds: 2));
      expect(style.hintSwitchDuration, const Duration(milliseconds: 111));
    });

    testWidgets('K4-CH3 — un JETON à 40 dp est écrêté à 48 (AD-13)', (
      WidgetTester tester,
    ) async {
      final ZChatComposerChromeStyle style = await resolve(
        tester,
        theme: const ZcrudTheme(chatComposerSendTargetSize: 40),
      );
      expect(style.sendTargetSize, 48,
          reason: '🔴 les 40 dp du legacy sont devenus EXPRIMABLES par thème — '
              'le plancher ne vaut que pour le paramètre');
    });

    testWidgets('K4-CH4 — l\'accent JETON remplace SA clé (par NOM de '
        'palier), les autres retombent sur la référence', (
      WidgetTester tester,
    ) async {
      final ZChatComposerChromeStyle style =
          await resolve(tester, theme: tokens);
      expect(style.responseLengthAccent(ZChatResponseLength.concise),
          const Color(0xFF0000AA),
          reason: '🔴 le jeton `chatResponseLengthAccents` est IGNORÉ — la '
              'condition « remplaçable par thème » de l\'exception FR-26 '
              'n\'est pas tenue');
      expect(style.responseLengthAccent(ZChatResponseLength.standard),
          const Color(0xFF2196F3),
          reason: '🔴 une clé de jeton a effacé les AUTRES accents de '
              'référence : la table est consultée en bloc');
    });

    testWidgets('K4-CH5 — le paramètre bat le jeton CLÉ PAR CLÉ sur les '
        'accents', (WidgetTester tester) async {
      final ZChatComposerChromeStyle style = await resolve(
        tester,
        theme: tokens,
        chrome: const ZChatComposerChrome(
          responseLengthAccents: <ZChatResponseLength, Color>{
            ZChatResponseLength.concise: Color(0xFF00BB00),
          },
        ),
      );
      expect(style.responseLengthAccent(ZChatResponseLength.concise),
          const Color(0xFF00BB00));
    });
  });

  group('🔴 K4-EM — les jetons d\'emphase CR-IFFD-74, entre paramètre et '
      'référence', () {
    Text chosenAuto(WidgetTester tester) => tester
        .widgetList<Text>(
          find.text(kZChatLabelFallbacks[kZChatLabelSettingAuto]!),
        )
        .first;

    testWidgets('K4-EM1 — le JETON est atteint (style RENDU de l\'option '
        'choisie)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          ZChatSettingsSheet(controller: c),
          theme: const ZcrudTheme(
            chatSelectedEmphasisWeight: FontWeight.w900,
            chatSelectedEmphasisDecoration: TextDecoration.overline,
          ),
        ),
      );
      final Text chosen = chosenAuto(tester);
      expect(chosen.style?.fontWeight, FontWeight.w900,
          reason: '🔴 `chatSelectedEmphasisWeight` est IGNORÉ : le niveau '
              'jeton demandé par CR-IFFD-74 n\'est pas branché');
      expect(chosen.style?.decoration, TextDecoration.overline,
          reason: '🔴 `chatSelectedEmphasisDecoration` est IGNORÉ');
    });

    testWidgets('K4-EM2 — le PARAMÈTRE bat le jeton', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          ZChatSettingsSheet(
            controller: c,
            selectedWeight: FontWeight.w500,
            selectedDecoration: TextDecoration.lineThrough,
          ),
          theme: const ZcrudTheme(
            chatSelectedEmphasisWeight: FontWeight.w900,
            chatSelectedEmphasisDecoration: TextDecoration.overline,
          ),
        ),
      );
      final Text chosen = chosenAuto(tester);
      expect(chosen.style?.fontWeight, FontWeight.w500);
      expect(chosen.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('K4-EM3 — sans paramètre NI jeton, la RÉFÉRENCE (CR-74 '
        'intacte)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatSettingsSheet(controller: c)));
      final Text chosen = chosenAuto(tester);
      expect(chosen.style?.fontWeight, kZChatSettingsReferenceSelectedWeight);
      expect(
          chosen.style?.decoration, kZChatSettingsReferenceSelectedDecoration);
    });
  });

  group('🔴 K4-CA — la famille « capacités » par défaut', () {
    String fb(String key) => kZChatLabelFallbacks[key]!;

    testWidgets('K4-CA1 — l\'entrée par défaut est la recherche web, et son '
        'tap écrit le champ TYPÉ', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatSettingsSheet(controller: c)));
      expect(find.text(fb(kZChatLabelCapabilities)), findsOneWidget,
          reason: '🔴 la famille « capacités » par défaut est ABSENTE');
      await tester.tap(find.text(fb(kZChatLabelCapabilityWebSearch)));
      await tester.pump();
      expect(c.settings.value.webSearch, isTrue,
          reason: '🔴 le tap n\'atteint pas le champ TYPÉ du kernel — la clé '
              'réservée serait partie dans le canal ouvert (deux écritures '
              'pour une même demande)');
      expect(c.settings.value.capabilities, isEmpty,
          reason: '🔴 la clé réservée a fui dans le canal ouvert');
      // Second tap : retour à « l'hôte décide » — jamais un `false` inventé.
      await tester.tap(find.text(fb(kZChatLabelCapabilityWebSearch)));
      await tester.pump();
      expect(c.settings.value.webSearch, isNull,
          reason: '🔴 le retrait doit rendre `null` (l\'hôte décide), pas '
              '`false` (qui est une DEMANDE de coupure)');
    });

    testWidgets('K4-CA2 — une capacité d\'HÔTE : libellé de l\'hôte, canal '
        'ouvert', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          ZChatSettingsSheet(
            controller: c,
            capabilityCatalog: const <ZChatSettingsHostOption>[
              ZChatSettingsHostOption(key: 'summary', label: 'Résumé auto'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Résumé auto'));
      await tester.pump();
      expect(c.settings.value.capabilities, <String, bool>{'summary': true});
      expect(c.settings.value.webSearch, isNull);
    });

    testWidgets('K4-CA3 — un hôte qui fournit SA PROPRE entrée pour la clé '
        'réservée remplace celle du socle (jamais deux entrées)', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          ZChatSettingsSheet(
            controller: c,
            capabilityCatalog: const <ZChatSettingsHostOption>[
              ZChatSettingsHostOption(
                key: kZChatCapabilityWebSearch,
                label: 'Recherche en ligne',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Recherche en ligne'), findsOneWidget);
      expect(find.text(fb(kZChatLabelCapabilityWebSearch)), findsNothing,
          reason: '🔴 DEUX entrées pour la même clé : deux boutons qui '
              'écrivent le même champ');
      // Le tap de l'entrée d'hôte écrit quand même le champ TYPÉ.
      await tester.tap(find.text('Recherche en ligne'));
      await tester.pump();
      expect(c.settings.value.webSearch, isTrue);
      expect(c.settings.value.capabilities, isEmpty);
    });

    testWidgets('K4-CA4 — règle des trois cas : rendre `null` RETIRE la '
        'tuile', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          ZChatSettingsSheet(
            controller: c,
            capabilitiesBuilder: (BuildContext _, ZChatSettingsSlot _) => null,
          ),
        ),
      );
      expect(find.text(fb(kZChatLabelCapabilities)), findsNothing);
      expect(find.text(fb(kZChatLabelCapabilityWebSearch)), findsNothing);
    });

    testWidgets('K4-CA5 — l\'état SÉLECTIONNÉ se lit par la lecture CANONIQUE '
        '(un settings préchargé s\'affiche coché)', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController(
        settings: const ZChatGenerationSettings(webSearch: true),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatSettingsSheet(controller: c)));
      expect(
        tester.getSemantics(find.text(fb(kZChatLabelCapabilityWebSearch))),
        matchesSemantics(
          isSelected: true,
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
          label: fb(kZChatLabelCapabilityWebSearch),
        ),
        reason: '🔴 un `webSearch: true` préchargé n\'est pas montré '
            'sélectionné : la tuile lit un AUTRE canal que le kernel',
      );
    });
  });

  group('🔴 K4-CT — le compteur et le TRANSPORT des champs K1', () {
    test('K4-CT1 — les capacités comptent dans `activeCount` (F12 élargi)', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      expect(c.activeCount.value, 0);
      c.setCapability(kZChatCapabilityWebSearch, true);
      expect(c.activeCount.value, 1,
          reason: '🔴 la recherche web demandée n\'apparaît pas au badge '
              '« outils » — un réglage actif invisible');
      c.setCapability('summary', false);
      expect(c.activeCount.value, 2,
          reason: '🔴 `false` est une DEMANDE (couper la capacité) : elle '
              'compte');
      c.setResponseLength(ZChatResponseLength.concise);
      expect(c.activeCount.value, 3);
      c.setCapability('summary', null);
      expect(c.activeCount.value, 2);
    });

    test('K4-CT2 — un geste d\'AXE ne perd PAS les capacités (le transport '
        'de `_with`)', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setCapability(kZChatCapabilityWebSearch, true);
      c.setCapability('summary', true);
      c.setResponseLength(ZChatResponseLength.detailed);
      c.setLengthBias(ZChatLengthBias.shorter);
      c.setComputeEffort(ZChatComputeEffort(3));
      c.setRevealThinkingSteps(true);
      expect(c.settings.value.webSearch, isTrue,
          reason: '🔴 régler la verbosité a EFFACÉ la recherche web : la '
              'construction explicite ne nomme pas les champs K1');
      expect(c.settings.value.capabilities, <String, bool>{'summary': true});
    });

    test('K4-CT3 — `reset()` retire aussi les capacités', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setCapability(kZChatCapabilityWebSearch, false);
      c.setCapability('summary', true);
      c.reset();
      expect(c.settings.value.isEmpty, isTrue);
      expect(c.activeCount.value, 0);
    });

    test('K4-CT4 — une clé BLANCHE est ignorée (AD-10), la clé réservée est '
        'rognée vers le champ typé', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setCapability('   ', true);
      expect(c.settings.value.isEmpty, isTrue);
      c.setCapability(' $kZChatCapabilityWebSearch ', true);
      expect(c.settings.value.webSearch, isTrue);
      expect(c.settings.value.capabilities, isEmpty,
          reason: '🔴 la clé réservée NON rognée est partie au canal ouvert');
    });
  });

  group('🔴 K4-PR — les préréglages TRANSPORTENT les champs K1', () {
    test('K4-PR1 — apply puis clear : restitution EXACTE, entre deux états '
        'DIFFÉRENTS (non vacant)', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      // L'état d'AVANT — lui-même porteur de capacités (le snapshot doit les
      // transporter dans les DEUX sens).
      c.setResponseLength(ZChatResponseLength.concise);
      c.setCapability('draft_long', true);
      final ZChatGenerationSettings before = c.settings.value;

      final ZChatSettingsPreset preset = ZChatSettingsPreset(
        id: 'expert',
        label: 'Expert',
        settings: ZChatGenerationSettings(
          computeEffort: ZChatComputeEffort(5),
          webSearch: true,
          capabilities: const <String, bool>{'summary': false},
        ),
      );
      c.applyPreset(preset.id, preset.settings, preset.corpusScope);

      // NON VACANT : les deux états diffèrent réellement.
      expect(c.settings.value, isNot(equals(before)),
          reason: '🔴 mesure vacante : préréglage et état d\'avant sont '
              'identiques, la restitution ne prouverait rien');
      expect(c.settings.value, equals(preset.settings),
          reason: '🔴 le préréglage n\'est pas transporté TEL QUEL');
      expect(c.settings.value.webSearch, isTrue);
      expect(c.settings.value.capability('summary'), isFalse);
      expect(c.activeCount.value, 3,
          reason: '🔴 effort + webSearch + summary=false : trois demandes');

      c.clearPreset();
      expect(c.settings.value, equals(before),
          reason: '🔴 la restitution n\'est pas EXACTE : les champs K1 du '
              'snapshot ont été perdus');
      expect(c.settings.value.capability('draft_long'), isTrue);
      expect(c.settings.value.webSearch, isNull);
    });
  });
}
