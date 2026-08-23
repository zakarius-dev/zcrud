/// **LOT A — ergonomie du composer.**
///
/// Ce que ce fichier MESURE, sur un sujet réellement monté :
///
/// * **LA-K** — le chemin d'envoi au CLAVIER. Le défaut d'origine : le
///   composer câblait `onSubmitted` sur un `EditableText` à `maxLines: 5`,
///   or Flutter ne déclenche jamais `onSubmitted` hors du mono-ligne. Le
///   bouton était donc le SEUL chemin d'envoi. Les gardes pressent la touche
///   sur un sujet monté, et comptent les flux ouverts — jamais un appel de
///   fermeture simulé.
/// * **LA-T** — AD-13 : la référence du composer ne déclare plus AUCUNE
///   cible sous 48 dp, et les deux affordances qu'elle refusait de déclarer
///   (sortie du bandeau d'édition, retrait d'une pièce jointe) sont mesurées
///   en géométrie RENDUE.
/// * **LA-B** — le compteur de réglages actifs, rendu PAR DÉFAUT sur le
///   déclencheur d'outils, et la règle du mode compact : sous le seuil, le
///   badge remplace le libellé — sauf à zéro, où le libellé reste (jamais
///   zéro canal visible).
@TestOn('vm')
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Couleur de curseur du TEST — le socle n'en invente aucune (FR-26).
const Color _cursor = Color(0xFF123456);

/// Les plateformes de BUREAU, où le raccourci s'applique.
const List<TargetPlatform> _desktop = <TargetPlatform>[
  TargetPlatform.linux,
  TargetPlatform.macOS,
  TargetPlatform.windows,
];

/// Les plateformes TACTILES, où il ne s'applique jamais.
const List<TargetPlatform> _touch = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
];

/// Rétablit la plateforme ambiante.
///
/// Le binding de test vérifie les variables de débogage **avant** les
/// `addTearDown` : la remise à zéro doit donc aussi se faire dans le corps du
/// test — [_resetPlatform] y sert deux fois, et une double remise à `null` est
/// sans effet.
void _resetPlatform() => debugDefaultTargetPlatformOverride = null;

void main() {
  group('🔴 LA-K — le chemin d\'envoi au CLAVIER (table de raccourcis)', () {
    test('LA-K1 — défaut : Entrée SOUMET, Maj+Entrée et Ctrl+Entrée non', () {
      final Map<ShortcutActivator, Intent> table =
          zChatComposerSubmitShortcuts(ZChatComposerSubmitKey.enterSubmits);
      expect(
        table[const SingleActivator(LogicalKeyboardKey.enter)],
        isA<ZChatComposerSubmitIntent>(),
        reason: '🔴 Entrée ne soumet pas : le composer n\'a AUCUN chemin '
            'd\'envoi au clavier (le défaut d\'origine, `onSubmitted` mort '
            'sur un champ multiligne).',
      );
      for (final SingleActivator newline in <SingleActivator>[
        const SingleActivator(LogicalKeyboardKey.enter, shift: true),
        const SingleActivator(LogicalKeyboardKey.enter, control: true),
      ]) {
        expect(
          table[newline],
          isA<DoNothingAndStopPropagationTextIntent>(),
          reason: '🔴 $newline doit ATTEINDRE la saisie pour y insérer une '
              'ligne — ce paquet n\'écrit jamais lui-même dans le champ.',
        );
      }
    });

    test('LA-K2 — la convention INVERSE est déclarable', () {
      final Map<ShortcutActivator, Intent> table =
          zChatComposerSubmitShortcuts(ZChatComposerSubmitKey.modifierSubmits);
      expect(
        table[const SingleActivator(LogicalKeyboardKey.enter)],
        isA<DoNothingAndStopPropagationTextIntent>(),
      );
      expect(
        table[const SingleActivator(LogicalKeyboardKey.enter, shift: true)],
        isA<ZChatComposerSubmitIntent>(),
      );
      expect(
        table[const SingleActivator(LogicalKeyboardKey.enter, control: true)],
        isA<ZChatComposerSubmitIntent>(),
      );
    });

    test('LA-K3 — le retrait donne une table VIDE (aucun raccourci monté)',
        () {
      expect(
        zChatComposerSubmitShortcuts(ZChatComposerSubmitKey.none),
        isEmpty,
      );
    });

    test('LA-K4 — le filtrage porte sur la PLATEFORME, pas sur la largeur',
        () {
      const ZChatComposerSubmitPolicy p = ZChatComposerSubmitPolicy.standard;
      for (final TargetPlatform d in _desktop) {
        expect(p.resolve(platform: d, isWeb: false),
            ZChatComposerSubmitKey.enterSubmits,
            reason: '🔴 $d est un bureau : le raccourci s\'y applique.');
      }
      for (final TargetPlatform t in _touch) {
        expect(p.resolve(platform: t, isWeb: false),
            ZChatComposerSubmitKey.none,
            reason: '🔴 $t est tactile : un clavier virtuel n\'a pas de '
                'modificateur, Entrée doit y insérer une ligne.');
        expect(p.resolve(platform: t, isWeb: true),
            ZChatComposerSubmitKey.enterSubmits,
            reason: '🔴 sur le Web, le clavier est physique quelle que soit '
                'la plateforme annoncée.');
      }
      expect(
        const ZChatComposerSubmitPolicy(desktopAndWebOnly: false)
            .resolve(platform: TargetPlatform.android, isWeb: false),
        ZChatComposerSubmitKey.enterSubmits,
        reason: '🔴 l\'hôte doit pouvoir imposer le raccourci partout.',
      );
      expect(
        ZChatComposerSubmitPolicy.disabled
            .resolve(platform: TargetPlatform.linux, isWeb: false),
        ZChatComposerSubmitKey.none,
      );
    });

    for (final TargetPlatform platform in _desktop) {
      testWidgets('LA-K5[$platform] — Entrée ouvre EXACTEMENT un flux',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(_resetPlatform);
        final c = buildController();
        addTearDown(c.controller.dispose);
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: c.controller,
              cursorColor: _cursor,
              focusNode: node,
            ),
          ),
        );
        c.controller.seedDraft('question tapée');
        await tester.pump();
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        _resetPlatform();
        expect(c.port.calls, hasLength(1),
            reason: '🔴 la touche Entrée n\'envoie rien : le composer est '
                'revenu au chemin MORT (`onSubmitted` sur un champ '
                'multiligne).');
        await c.port.closeAll();
      });
    }

    testWidgets('LA-K6 — Maj+Entrée et Ctrl+Entrée n\'envoient RIEN',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(_resetPlatform);
      final c = buildController();
      addTearDown(c.controller.dispose);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: c.controller,
            cursorColor: _cursor,
            focusNode: node,
          ),
        ),
      );
      c.controller.seedDraft('question tapée');
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      for (final LogicalKeyboardKey modifier in <LogicalKeyboardKey>[
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
        _resetPlatform();
        expect(c.port.calls, isEmpty,
            reason: '🔴 $modifier + Entrée a ENVOYÉ : la nouvelle ligne est '
                'devenue inatteignable au clavier.');
      }
      _resetPlatform();
    });

    for (final TargetPlatform platform in _touch) {
      testWidgets('LA-K7[$platform] — sur tactile, Entrée n\'envoie RIEN',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(_resetPlatform);
        final c = buildController();
        addTearDown(c.controller.dispose);
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: c.controller,
              cursorColor: _cursor,
              focusNode: node,
            ),
          ),
        );
        c.controller.seedDraft('question tapée');
        await tester.pump();
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        _resetPlatform();
        expect(c.port.calls, isEmpty,
            reason: '🔴 le raccourci n\'est pas filtré par plateforme : sur '
                'un clavier virtuel, la nouvelle ligne devient '
                'inatteignable.');
      });
    }

    testWidgets('LA-K8 — la politique RETIRÉE rend la touche inerte',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(_resetPlatform);
      final c = buildController();
      addTearDown(c.controller.dispose);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: c.controller,
            cursorColor: _cursor,
            focusNode: node,
            submitPolicy: ZChatComposerSubmitPolicy.disabled,
          ),
        ),
      );
      c.controller.seedDraft('question tapée');
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      _resetPlatform();
      expect(c.port.calls, isEmpty,
          reason: '🔴 `disabled` doit rendre la touche inerte.');
    });

    testWidgets('LA-K9 — le raccourci et le BOUTON partagent le site unique',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(_resetPlatform);
      final c = buildController();
      addTearDown(c.controller.dispose);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: c.controller,
            cursorColor: _cursor,
            focusNode: node,
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                ZChatComposerSendTarget(
                  slot: slot,
                  child: const SizedBox(width: 18, height: 18),
                ),
          ),
        ),
      );
      c.controller.seedDraft('question tapée');
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(c.port.calls, hasLength(1));
      c.controller.seedDraft('deuxième question');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pump();
      _resetPlatform();
      expect(c.port.calls, hasLength(2),
          reason: '🔴 les deux gestes doivent ouvrir un flux CHACUN, par le '
              'même site.');
      await c.port.closeAll();
    });
  });

  group('🔴 LA-T — AD-13 : plus AUCUNE cible sous 48 dp déclarée', () {
    const String referencePath =
        'lib/src/presentation/view/z_chat_composer_reference.dart';

    test('LA-T1 — toute cible DÉCLARÉE dans la référence vaut ≥ 48', () {
      final List<String> lines = stripped(libFile(referencePath));
      final RegExp decl = RegExp(
        r'static\s+const\s+double\s+(\w*[Tt]argetSize)\s*=\s*([^;]+);',
      );
      final Map<String, String> declared = <String, String>{};
      for (final String l in lines) {
        final RegExpMatch? m = decl.firstMatch(l);
        if (m != null) declared[m.group(1)!] = m.group(2)!.trim();
      }
      expect(declared, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : plus aucune cible déclarée.');
      expect(
        declared.keys,
        containsAll(<String>[
          'sendTargetSize',
          'editingCancelTargetSize',
          'attachmentRemoveTargetSize',
        ]),
        reason: '🔴 les deux affordances que la référence REFUSAIT de '
            'déclarer (sortie du bandeau, retrait d\'une pièce jointe) '
            'doivent y figurer : une valeur absente est une valeur '
            'reproductible par inadvertance.',
      );
      for (final MapEntry<String, String> e in declared.entries) {
        final double? literal = double.tryParse(e.value);
        expect(
          literal == null ? e.value : '$literal',
          literal == null
              ? 'kZChatMinTapTarget'
              : predicate<String>((String _) => literal >= 48),
          reason: '🔴 ${e.key} = ${e.value} : une cible sous 48 dp est de '
              'nouveau DÉCLARÉE, donc reproductible (invariant AD-13).',
        );
      }
    });

    test('LA-T2 — la référence n\'AVOUE plus de cible sous 48 dp', () {
      final String body = libFile(referencePath).readAsStringSync();
      expect(
        body.contains('sous 48 dp'),
        isFalse,
        reason: '🔴 la référence documente de nouveau une cible sous le '
            'plancher au lieu de la corriger.',
      );
      expect(
        body.contains('n\'est pas directionnel'),
        isFalse,
        reason: '🔴 la référence documente de nouveau un positionnement non '
            'directionnel au lieu de le corriger.',
      );
      expect(body, contains('editingCancelTargetSize'),
          reason: '🔴 GARDE VACUELLE : le fichier lu n\'est pas le bon.');
    });

    testWidgets('LA-T3 — la sortie du bandeau d\'édition mesure ≥ 48 dp RENDUS',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      c.controller.startEditing(messageId: 'm1', originalText: 'texte');
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZChatComposerEditingBanner(
              controller: c.controller,
              cancelGlyph: const SizedBox(width: 16, height: 16),
            ),
          ),
        ),
      );
      await tester.pump();
      final Finder cancel = find.bySemanticsLabel('Annuler la modification');
      expect(cancel, findsOneWidget,
          reason: '🔴 GARDE VACUELLE : la sortie n\'est pas montée.');
      final Size size = tester.getSize(
        find.descendant(of: cancel, matching: find.byType(ConstrainedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('🔴 LA-B — le compteur de réglages actifs, rendu PAR DÉFAUT', () {
    Widget mount(
      ZChatController controller,
      ZChatSettingsController settings, {
      bool showToolsBadge = true,
      bool glyph = true,
    }) => harness(
      Align(
        alignment: AlignmentDirectional.bottomStart,
        child: ZDefaultChatComposer(
          controller: controller,
          settings: settings,
          cursorColor: _cursor,
          onOpenTools: () {},
          showToolsBadge: showToolsBadge,
          toolsGlyph: glyph ? const SizedBox(width: 18, height: 18) : null,
        ),
      ),
    );

    testWidgets('LA-B1 — un hôte PASSIF voit le compte apparaître',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mount(c.controller, settings));
      expect(find.text('2'), findsNothing,
          reason: '🔴 GARDE VACUELLE : le compte est rendu avant tout '
              'réglage.');
      settings.setRevealThinkingSteps(true);
      settings.toggleCorpusKey('corpus-a');
      await tester.pump();
      expect(settings.activeCount.value, 2,
          reason: '🔴 GARDE VACUELLE : la tranche mesurée ne vaut pas 2.');
      expect(find.text('2'), findsOneWidget,
          reason: '🔴 `activeCount` n\'est rendu NULLE PART : la tranche '
              'existe et reste invisible (le défaut d\'origine).');
      expect(find.text('Outils'), findsOneWidget,
          reason: '🔴 au-dessus du seuil, le badge s\'AJOUTE au libellé.');
    });

    testWidgets('LA-B2 — sous le seuil, le badge REMPLACE le libellé',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      settings.setRevealThinkingSteps(true);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 600);
      addTearDown(tester.view.reset);
      // Sans glyphe : c'est le cas où le libellé était le SEUL canal visible.
      await tester.pumpWidget(mount(c.controller, settings, glyph: false));
      await tester.pump();
      expect(find.text('1'), findsOneWidget,
          reason: '🔴 le badge doit survivre au mode compact.');
      expect(find.text('Outils'), findsNothing,
          reason: '🔴 sous le seuil, le badge REMPLACE le libellé (économie '
              'de largeur), il ne s\'y ajoute pas.');
      expect(find.bySemanticsLabel('Outils'), findsOneWidget,
          reason: '🔴 masquer le libellé ne masque JAMAIS la sémantique.');
    });

    testWidgets('LA-B3 — à ZÉRO, le libellé reste : jamais zéro canal visible',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mount(c.controller, settings, glyph: false));
      await tester.pump();
      expect(find.text('0'), findsNothing,
          reason: '🔴 un compte nul ne se rend pas (invariant AD-4).');
      expect(find.text('Outils'), findsOneWidget,
          reason: '🔴 sans glyphe ni badge, masquer le libellé laisserait un '
              'bouton INVISIBLE.');
    });

    testWidgets('LA-B4 — le canal est RETIRABLE par l\'hôte',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      settings.setRevealThinkingSteps(true);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        mount(c.controller, settings, showToolsBadge: false),
      );
      await tester.pump();
      expect(find.text('1'), findsNothing,
          reason: '🔴 `showToolsBadge: false` doit retirer le badge par '
              'défaut.');
      expect(find.text('Outils'), findsOneWidget);
    });

    testWidgets('LA-B5 — AD-2 : le compte ne reconstruit PAS le champ',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mount(c.controller, settings));
      final Element before = tester.element(find.byType(EditableText));
      settings.setRevealThinkingSteps(true);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(identical(tester.element(find.byType(EditableText)), before),
          isTrue,
          reason: '🔴 le champ a été RECRÉÉ par un changement de compte : le '
              'rebuild n\'est plus granulaire (invariant AD-2).');
    });
  });
}
