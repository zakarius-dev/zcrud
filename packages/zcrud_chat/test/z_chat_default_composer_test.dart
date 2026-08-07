/// **CR-IFFD-76** — l'assemblage par défaut (`ZDefaultChatComposer`) et les
/// six pièces de la bande.
///
/// ## Les QUATRE défauts d'assemblage d'IFFD sont les tests d'acceptation
///
/// | # | défaut mesuré chez IFFD | garde |
/// |---|---|---|
/// | ① | feuille montée inline dans `tools` (débordement 149 px) | DC-D1 (assertion debug) + DC-D2 (arbre par défaut sans feuille) |
/// | ② | `settings:` oublié — la portée réglée puis JETÉE (B-58) | DC-A1 : la requête PART avec les réglages et la portée (le type rend l'oubli incompilable — prouvé ici en comportement) |
/// | ③ | badge volant le tap du bouton | DC-C1 : tap AU CENTRE DU BADGE ⇒ la feuille s'ouvre |
/// | ④ | trois chips d'effort au lieu du déclencheur à menu | DC-E1 : la pièce par défaut est UN déclencheur ; son menu écrit dans le contrôleur PARTAGÉ |
///
/// ## Un état, DEUX surfaces (arbitrage owner n°3)
///
/// DC-B1/B2 : basculer dans la BANDE se reflète dans la FEUILLE, et
/// inversement — mesuré sur le rendu (emphase/valeur), jamais sur le seul
/// contrôleur (une garde qui ne lirait que `settings.value` serait verte avec
/// deux surfaces désynchronisées à l'écran).
@TestOn('vm')
library;

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart'
    show FlutterErrorDetails, FlutterExceptionHandler;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Monte l'assemblé avec ses doublures. Les glyphes sont fournis (l'hôte réel
/// en fournit — Material ou autres) pour exercer le mode compact.
Widget _assembled(
  ZChatController controller,
  ZChatSettingsController settings, {
  VoidCallback? onOpenTools,
  Widget? toolsBadge,
  List<ZChatComposerPickerAction> pickers =
      const <ZChatComposerPickerAction>[],
  ZChatComposerSlotBuilder? toolsBuilder,
  ZChatComposerChrome? chrome,
  TextDirection direction = TextDirection.ltr,
  bool glyphs = true,
}) => harness(
  // Au BAS de l'écran, comme chez un hôte réel : les menus des déclencheurs
  // s'ouvrent AU-DESSUS d'eux (lex/f011) — ancrés en haut d'écran ils
  // sortiraient du viewport du testeur.
  Align(
    alignment: AlignmentDirectional.bottomStart,
    child: ZDefaultChatComposer(
    controller: controller,
    settings: settings,
    cursorColor: const Color(0xFF000000),
    chrome: chrome,
    onOpenTools: onOpenTools,
    toolsBadge: toolsBadge,
    pickers: pickers,
    toolsBuilder: toolsBuilder,
    pickerGlyph: glyphs ? const _Glyph() : null,
    thinkingGlyph: glyphs ? const _Glyph() : null,
    webSearchGlyph: glyphs ? const _Glyph() : null,
    toolsGlyph: glyphs ? const _Glyph() : null,
    effortGlyph: glyphs ? const _Glyph() : null,
    stopGlyph: glyphs ? const _Glyph() : null,
    ),
  ),
  direction: direction,
);

/// Un glyphe d'hôte neutre et mesurable.
class _Glyph extends StatelessWidget {
  const _Glyph();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18);
}

void main() {
  group('🔴 DC-A — défaut ② : les réglages PARTENT avec la requête', () {
    testWidgets(
        'DC-A1 — l\'assemblé envoie `settings` ET `corpusScope` réglés par le '
        'contrôleur câblé d\'office', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      settings.setResponseLength(ZChatResponseLength.concise);
      settings.toggleCorpusKey('corpus-test');
      await tester.pumpWidget(_assembled(c.controller, settings));
      c.controller.seedDraft('question posée');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pump();
      expect(c.port.calls, hasLength(1),
          reason: '🔴 l\'envoi n\'est pas parti par le site unique.');
      final ZChatGenerationRequest sent = c.port.calls.single.request;
      // 🔴 LA réinjection du défaut ② : sans le câblage d'office, ces deux
      // champs seraient nuls — réglés à l\'écran puis JETÉS (B-58).
      expect(sent.settings.responseLength, ZChatResponseLength.concise,
          reason: '🔴 défaut ② réinjecté : la verbosité réglée n\'atteint '
              'pas la requête.');
      expect(sent.corpusScope?.corpusKeys, contains('corpus-test'),
          reason: '🔴 défaut ② réinjecté : la portée documentaire réglée '
              'n\'atteint pas la requête.');
      await c.port.closeAll();
    });
  });

  group('🔴 DC-B — UN état, DEUX surfaces (bande ↔ feuille)', () {
    testWidgets(
        'DC-B1 — basculer « réfléchir » dans la BANDE se reflète dans la '
        'FEUILLE (rendu, pas seulement contrôleur)',
        (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              ZChatComposerThinkingToggle(controller: settings),
              Expanded(
                child: SingleChildScrollView(
                  child: ZChatSettingsSheet(controller: settings),
                ),
              ),
            ],
          ),
        ),
      );
      // Avant : la tuile « Afficher le raisonnement » n'est PAS choisie.
      SemanticsNode? option(bool selected) => findSemantics(
        tester,
        (SemanticsNode n) =>
            n.label == 'Afficher le raisonnement' &&
            n.flagsCollection.isButton &&
            n.flagsCollection.isSelected ==
                (selected ? Tristate.isTrue : Tristate.isFalse) &&
            n.flagsCollection.isToggled == Tristate.none,
      );
      expect(option(false), isNotNull,
          reason: '🔴 sujet non monté : la tuile de la feuille est absente.');
      // Geste dans la BANDE.
      await tester.tap(
        find.descendant(
          of: find.byType(ZChatComposerThinkingToggle),
          matching: find.text('Afficher le raisonnement'),
        ),
      );
      await tester.pump();
      expect(settings.settings.value.revealThinkingSteps, isTrue);
      // 🔴 La FEUILLE reflète — l'option est désormais CHOISIE au rendu.
      expect(option(true), isNotNull,
          reason: '🔴 deux états : la bande a basculé, la feuille ne le '
              'montre pas.');
      await tester.pump();
    });

    testWidgets(
        'DC-B2 — basculer dans la FEUILLE se reflète dans la BANDE '
        '(sens inverse) — et « internet » passe par la capacité TYPÉE',
        (WidgetTester tester) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              ZChatComposerWebSearchToggle(controller: settings),
              Expanded(
                child: SingleChildScrollView(
                  child: ZChatSettingsSheet(controller: settings),
                ),
              ),
            ],
          ),
        ),
      );
      SemanticsNode? band(bool on) => findSemantics(
        tester,
        (SemanticsNode n) =>
            n.label == 'Recherche web' &&
            n.flagsCollection.isToggled ==
                (on ? Tristate.isTrue : Tristate.isFalse),
      );
      expect(band(false), isNotNull,
          reason: '🔴 sujet non monté : la bascule de bande est absente.');
      // Geste dans la FEUILLE (la tuile de capacités).
      await tester.tap(
        find.descendant(
          of: find.byType(ZChatSettingsCapabilityTile),
          matching: find.text('Recherche web'),
        ),
      );
      await tester.pump();
      expect(
        settings.settings.value.capability(kZChatCapabilityWebSearch),
        isTrue,
        reason: '🔴 la tuile n\'écrit pas la capacité typée du kernel.',
      );
      // 🔴 La BANDE reflète — le drapeau `toggled` est passé à vrai.
      expect(band(true), isNotNull,
          reason: '🔴 deux états : la feuille a basculé, la bande ne le '
              'montre pas.');
    });
  });

  group('🔴 DC-C — défaut ③ : le badge ne vole pas le tap', () {
    testWidgets(
        'DC-C1 — tap AU CENTRE DU BADGE du bouton « outils » ⇒ `onOpen` part',
        (WidgetTester tester) async {
      int opened = 0;
      const Key badgeKey = Key('badge-outils');
      await tester.pumpWidget(
        harness(
          ZChatComposerToolsTrigger(
            onOpen: () => opened++,
            badge: const SizedBox(key: badgeKey, width: 12, height: 12),
          ),
        ),
      );
      // 🔴 Le geste vise le RECT DU BADGE, pas le bouton : c'est le cas
      // exact du défaut ③ (badge détaché volant le tap).
      await tester.tapAt(tester.getCenter(find.byKey(badgeKey)));
      await tester.pump();
      expect(opened, 1,
          reason: '🔴 défaut ③ réinjecté : le tap sur le badge n\'atteint '
              'pas le bouton « outils ».');
    });
  });

  group('🔴 DC-D — défaut ① : la feuille ne se monte pas dans la bande', () {
    testWidgets(
        'DC-D1 — un override qui rend une `ZChatSettingsSheet` dans la bande '
        'est DÉTECTÉ (assertion en debug)', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      // Collecte fidèle : le rendu inline de la feuille produit AUSSI des
      // erreurs de layout — la garde doit exiger l'ASSERTION du socle, pas
      // « une erreur quelconque » (sinon elle resterait verte, assert retiré,
      // sur la seule foi du débordement — garde vacante).
      final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      await tester.pumpWidget(
        _assembled(
          c.controller,
          settings,
          toolsBuilder: (BuildContext context, ZChatComposerSlot slot) =>
              ZChatSettingsSheet(controller: settings),
        ),
      );
      // 🔴 Restauré AVANT toute assertion (leçon CR75-G4 : une restauration
      // en tearDown fait planter le binding).
      FlutterError.onError = previous;
      expect(
        errors.any(
          (FlutterErrorDetails d) =>
              d.exception is AssertionError &&
              '${d.exception}'.contains(kZChatBandSheetAssertMessage),
        ),
        isTrue,
        reason: '🔴 défaut ① réinjecté SANS détection : la feuille montée '
            'inline dans la bande doit lever l\'assertion du socle en debug '
            '(chez IFFD : débordement de 149 px trouvé par la QA, pas par le '
            'code). Erreurs vues : '
            '${errors.map((FlutterErrorDetails d) => d.exception.runtimeType).toList()}',
      );
    });

    testWidgets(
        'DC-D2 — l\'arbre PAR DÉFAUT de l\'assemblé ne contient AUCUNE '
        'feuille de réglages ; le déclencheur OUVRE (callback d\'hôte)',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      int opened = 0;
      await tester.pumpWidget(
        _assembled(c.controller, settings, onOpenTools: () => opened++),
      );
      expect(find.byType(ZChatSettingsSheet), findsNothing,
          reason: '🔴 la feuille est une PAGE — jamais dans la bande.');
      await tester.tap(find.bySemanticsLabel('Outils'));
      await tester.pump();
      expect(opened, 1,
          reason: '🔴 le déclencheur « outils » n\'ouvre pas la feuille.');
    });
  });

  group('🔴 DC-E — défaut ④ : l\'effort est UN déclencheur à menu', () {
    testWidgets(
        'DC-E1 — la pièce par défaut est un déclencheur unique ; son menu '
        'écrit le palier dans le contrôleur PARTAGÉ',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_assembled(c.controller, settings));
      // UN déclencheur — pas trois chips (défaut ④).
      expect(find.byType(ZChatComposerEffortSelector), findsOneWidget,
          reason: '🔴 la forme lex est un déclencheur UNIQUE à menu.');
      expect(find.text('Concise'), findsNothing,
          reason: '🔴 des paliers rendus en permanence = la forme « trois '
              'chips », le défaut ④.');
      // Le geste, sur la pièce montée SEULE (dans l'assemblé, la bande
      // défile : le centre du déclencheur peut être hors écran pour `tap`).
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZChatComposerEffortSelector(controller: settings),
          ),
        ),
      );
      await tester.tap(find.byType(ZChatComposerEffortSelector));
      await tester.pump();
      // Le menu : Automatique + les trois paliers du kernel.
      expect(find.text('Concise'), findsOneWidget);
      expect(find.text('Automatique'), findsOneWidget);
      await tester.tap(find.text('Concise'));
      await tester.pump();
      expect(
        settings.settings.value.responseLength,
        ZChatResponseLength.concise,
        reason: '🔴 le menu n\'écrit pas dans le contrôleur partagé — un '
            'second état.',
      );
    });
  });

  group('🔴 DC-F — breakpoint mobile (< `mobileBreakpoint`, lex/f011)', () {
    testWidgets(
        'DC-F1 — sous le seuil : libellés MASQUÉS, badge GARDÉ ; au-dessus : '
        'libellés rendus', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      const Key badgeKey = Key('badge-compte');
      Widget mount() => _assembled(
        c.controller,
        settings,
        onOpenTools: () {},
        toolsBadge: const SizedBox(key: badgeKey, width: 12, height: 12),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // LARGE (≥ 400 dp de bande) : les libellés sont rendus.
      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpWidget(mount());
      expect(find.text('Outils'), findsOneWidget,
          reason: '🔴 au-dessus du seuil, le libellé doit être rendu.');
      // ÉTROIT (< 400 dp) : libellés masqués, badge gardé, sémantique intacte.
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpWidget(mount());
      await tester.pump();
      expect(find.text('Outils'), findsNothing,
          reason: '🔴 la référence `mobileBreakpoint` n\'est pas consommée : '
              'le libellé reste rendu sous le seuil.');
      expect(find.byKey(badgeKey), findsOneWidget,
          reason: '🔴 lex/f011 : les badges restent en mode compact.');
      expect(find.bySemanticsLabel('Outils'), findsOneWidget,
          reason: '🔴 masquer le libellé ne doit jamais masquer la '
              'SÉMANTIQUE.');
    });

    testWidgets(
        'DC-F2 — le seuil est RÉGLABLE par le chrome (attendu ≠ ambiant : '
        'seuil 800 ⇒ compact à 600)', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _assembled(
          c.controller,
          settings,
          onOpenTools: () {},
          chrome: const ZChatComposerChrome(mobileBreakpoint: 800),
        ),
      );
      expect(find.text('Outils'), findsNothing,
          reason: '🔴 le seuil du chrome (paramètre) n\'est pas honoré.');
    });
  });

  group('🔴 DC-G — STOP : le verbe EXISTANT, pendant le flux seulement', () {
    testWidgets(
        'DC-G1 — absent au repos, visible pendant le flux, et son tap passe '
        'par `runAction(ZChatCancelAction)` (executor mesuré)',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_assembled(c.controller, settings));
      expect(find.bySemanticsLabel('Arrêter la génération'), findsNothing,
          reason: '🔴 un STOP au repos est une affordance inerte (AD-4).');
      c.controller.seedDraft('question');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pump();
      expect(find.bySemanticsLabel('Arrêter la génération'), findsOneWidget,
          reason: '🔴 pendant le flux, le STOP doit apparaître.');
      await tester.tap(find.bySemanticsLabel('Arrêter la génération'));
      await tester.pump();
      // 🔴 Le verbe EXISTANT : l'annulation est passée par le répartiteur
      // (protocole complet), jamais par un raccourci.
      expect(c.executor.calls['cancelRequest'], 1,
          reason: '🔴 le STOP n\'emprunte pas '
              '`runAction(ZChatCancelAction)`.');
      await tester.pump();
      expect(c.controller.activeRequests.value, isEmpty,
          reason: '🔴 la requête annulée reste « en vol ».');
      // La saisie n'a PAS été détruite par l'arrêt (G-A1 : annuler ≠
      // supprimer la question). ⚠️ Pas de `closeAll()` ici : la souscription
      // du canal a été ANNULÉE par l'arrêt — `close()` n'aurait plus de
      // consommateur pour livrer `done` et son futur ne se résoudrait jamais
      // (mesuré : le test pendait 10 min).
    });
  });

  group('🔴 DC-H — bandeau d\'édition : les verbes K2 rendus', () {
    testWidgets(
        'DC-H1 — `startEditing` fait apparaître le bandeau ; « annuler » '
        'appelle `cancelEditing` et RESTITUE la saisie',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_assembled(c.controller, settings));
      c.controller.seedDraft('brouillon précieux');
      await tester.pump();
      expect(find.bySemanticsLabel('Annuler la modification'), findsNothing);
      c.controller.startEditing(
        messageId: 'm1',
        originalText: 'texte original',
      );
      await tester.pump();
      expect(find.text('Modification en cours'), findsOneWidget,
          reason: '🔴 le bandeau (pièce « non couverte » v0.56.0 §7) ne '
              'rend pas la session d\'édition.');
      await tester.tap(find.bySemanticsLabel('Annuler la modification'));
      await tester.pump();
      expect(c.controller.editing.value, isNull,
          reason: '🔴 la sortie ne passe pas par `cancelEditing`.');
      expect(c.controller.composer.text, 'brouillon précieux',
          reason: '🔴 la saisie d\'avant l\'édition n\'est pas restituée — '
              'le défaut IFFD « annuler = détruire ».');
    });
  });

  group('🔴 DC-I — `+` pickers : contrat opaque, geste d\'hôte', () {
    testWidgets(
        'DC-I1 — sans catalogue : aucun `+` (AD-4) ; avec : le menu rend les '
        'entrées d\'HÔTE et le geste remonte', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(_assembled(c.controller, settings));
      expect(find.byType(ZChatComposerPickerTrigger), findsNothing,
          reason: '🔴 un `+` sans action est une affordance inerte (AD-4).');
      int galerie = 0;
      await tester.pumpWidget(
        _assembled(
          c.controller,
          settings,
          pickers: <ZChatComposerPickerAction>[
            ZChatComposerPickerAction(
              label: 'Galerie hôte',
              onTap: () => galerie++,
            ),
          ],
        ),
      );
      await tester.tap(find.bySemanticsLabel('Ajouter'));
      await tester.pump();
      await tester.tap(find.text('Galerie hôte'));
      await tester.pump();
      expect(galerie, 1,
          reason: '🔴 le geste du picker n\'est pas celui de l\'hôte.');
    });
  });

  group('🔴 DC-J — conteneur : les constantes CONVERGENTES consommées', () {
    testWidgets(
        'DC-J1 — fond via jeton `surfaceColor` + rayon via chaîne du chrome '
        '(référence 12) ; sans couleur résolue : AUCUNE décoration',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      // Sans thème ni paramètre : aucune décoration inventée (FR-26).
      await tester.pumpWidget(_assembled(c.controller, settings));
      expect(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
        reason: '🔴 le socle a peint un fond sans couleur d\'hôte.',
      );
      // Paramètre : le fond est peint, au rayon de la RÉFÉRENCE (12 — le
      // fait §① : les deux relevés convergent).
      await tester.pumpWidget(
        harness(
          ZDefaultChatComposer(
            controller: c.controller,
            settings: settings,
            cursorColor: const Color(0xFF000000),
            backgroundColor: const Color(0xFF123456),
          ),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ZChatComposerSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration deco = box.decoration as BoxDecoration;
      expect(
        deco.borderRadius,
        const BorderRadius.all(ZChatComposerReference.containerRadius),
        reason: '🔴 le rayon ne vient pas de la chaîne du chrome (réf. 12).',
      );
      expect(deco.color, const Color(0xFF123456));
      // Le champ consomme les 1..5 lignes de la référence.
      final ZChatComposer composer = tester.widget<ZChatComposer>(
        find.byType(ZChatComposer),
      );
      expect(composer.minLines, ZChatComposerReference.fieldMinLines);
      expect(composer.maxLines, ZChatComposerReference.fieldMaxLines);
      expect(composer.settings, same(settings),
          reason: '🔴 défaut ② : le contrôleur câblé n\'est pas CELUI de '
              'l\'assemblé.');
    });
  });

  group('🔴 DC-K — RTL (AD-13)', () {
    testWidgets(
        'DC-K1 — la bande s\'inverse en RTL (le `+` passe à droite du '
        'déclencheur d\'effort) sans exception', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _assembled(
          c.controller,
          settings,
          onOpenTools: () {},
          pickers: <ZChatComposerPickerAction>[
            ZChatComposerPickerAction(label: 'Galerie hôte', onTap: () {}),
          ],
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.takeException(), isNull);
      final double plus = tester
          .getCenter(find.byType(ZChatComposerPickerTrigger))
          .dx;
      final double effort = tester
          .getCenter(find.byType(ZChatComposerEffortSelector))
          .dx;
      expect(plus, greaterThan(effort),
          reason: '🔴 en RTL le `+` (tête de bande) doit passer à DROITE du '
              'déclencheur d\'effort (fin de bande).');
    });
  });
}
