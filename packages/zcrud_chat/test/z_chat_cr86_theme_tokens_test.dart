/// Les deux JETONS de thème qui manquaient au chrome de chat : le **premier
/// plan d'erreur** (libellé de pastille) et l'**accent d'état actif** des
/// bascules du composer.
///
/// Ce que ce fichier prouve, garde par garde :
/// * **T1** — le jeton de premier plan d'erreur déclaré est **effectivement
///   peint** sur le libellé de pastille (couleur résolue du `RenderParagraph`,
///   jamais le paramètre passé).
/// * **T2** — non déclaré, la chaîne appariée d'origine reste : le libellé
///   vaut EXACTEMENT la couleur ambiante lisible, comme avant l'ajout.
/// * **T3** — un jeton que l'hôte rendrait illisible (premier plan = fond)
///   est **corrigé** par le plancher de contraste, jamais peint tel quel.
/// * **T4** — la symétrie du repli : fond et premier plan sont alimentés
///   depuis le MÊME `ColorScheme`, assertés **ensemble**.
/// * **T5** — la mesure du rendu par DÉFAUT (aucun jeton déclaré) : ce que
///   voit un hôte passif, en clair et en sombre.
/// * **T6** — mode compact, un outil ACTIF se distingue d'un outil au repos
///   par une couleur PEINTE (glyphe et libellé) — et l'état reste **annoncé**
///   (`Semantics(toggled:)`) et **écrit** (libellé emphasé).
/// * **T7** — contre-témoin à comptes ABSOLUS : sans déclaration, aucune
///   enveloppe de premier plan n'est posée et le glyphe garde la couleur
///   ambiante, actif comme au repos.
/// * **T8** — avec un libellé, le canal TEXTUEL survit : l'emphase
///   (graisse + décoration) est intacte, la couleur s'y ajoute.
/// * **T9** — un accent illisible déclaré par l'hôte est porté au plancher de
///   contraste des composants graphiques.
@TestOn('vm')
library;

import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Instruments ──────────────────────────────────────────────────────────

const IconData _icon = IconData(0xE901, fontFamily: 'MaterialIcons');

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// Luminance relative WCAG 2.x — implémentation **indépendante** de celle du
/// socle : rappeler `zReadableTintOn` rendrait la garde tautologique.
double _luminance(Color c) {
  double lin(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(body: child),
  ),
);

/// Un thème dont l'extension `ZcrudTheme` est celle du repli, éventuellement
/// surchargée — l'hôte réel n'en déclare jamais une partielle.
ThemeData _themed(
  Brightness brightness, {
  Color? error,
  Color? onError,
  Color? activeAccent,
}) {
  ThemeData base = ThemeData(brightness: brightness);
  if (error != null) {
    base = base.copyWith(
      colorScheme: base.colorScheme.copyWith(error: error),
    );
  }
  ZcrudTheme tokens = ZcrudTheme.fallback(base);
  if (onError != null) tokens = tokens.copyWith(onErrorColor: onError);
  if (activeAccent != null) {
    tokens = tokens.copyWith(chatComposerActiveAccent: activeAccent);
  }
  return base.copyWith(extensions: <ThemeExtension<dynamic>>[tokens]);
}

/// Le même thème, mais dont l'extension NE porte PAS le premier plan
/// d'erreur — l'état exact d'un hôte qui n'a rien déclaré et dont le socle
/// n'aurait pas le jeton.
ThemeData _withoutOnError(Brightness brightness, Color error) {
  final ThemeData base = ThemeData(brightness: brightness).copyWith(
    colorScheme: ThemeData(brightness: brightness).colorScheme.copyWith(
      error: error,
    ),
  );
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      ZcrudTheme(
        errorColor: base.colorScheme.error,
        surfaceColor: base.colorScheme.surface,
      ),
    ],
  );
}

ZChatMessage get _message => const ZChatMessage(
  id: 'm1',
  conversationId: 'c1',
  role: ZChatRole.assistant,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: 'corps')],
);

ZChatArtifactSpec get _counted => ZChatArtifactSpec(
  key: kZChatCapabilityMindmap,
  icon: _icon,
  label: 'Carte mentale',
  presence: (ZChatMessage _) => true,
  count: (ZChatMessage _) => 3,
);

Future<void> _pumpBadge(WidgetTester tester, ThemeData theme) =>
    tester.pumpWidget(
      _app(
        ZChatArtifactBar(
          message: _message,
          artifacts: <ZChatArtifactSpec>[_counted],
        ),
        theme: theme,
      ),
    );

/// La couleur RÉELLEMENT peinte du libellé de pastille.
Color _labelColor(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.text('3')).text.style!.color!;

/// La couleur RÉELLEMENT peinte du fond de pastille.
Color _badgeBackground(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ZChatArtifactBar),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

/// Le premier plan AMBIANT lu par le socle (l'ENTRÉE de la chaîne, pas son
/// algorithme).
Color _ambient(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(ZChatArtifactBar));
  return IconTheme.of(context).color ??
      DefaultTextStyle.of(context).style.color!;
}

/// La couleur RÉELLEMENT héritée par le glyphe d'hôte du composer.
Color? _glyphColor(WidgetTester tester) =>
    IconTheme.of(tester.element(find.byIcon(_icon))).color;

/// L'état d'une bascule tel qu'un lecteur d'écran le reçoit.
Tristate _toggled(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label)).flagsCollection.isToggled;

void main() {
  group('🔴 T — le jeton de PREMIER PLAN d\'erreur', () {
    testWidgets('T1 — déclaré, il est EFFECTIVEMENT peint sur le libellé', (
      WidgetTester tester,
    ) async {
      // Un bleu profond : lisible sur le rouge d'erreur, donc rendu tel quel
      // — le plancher ne le réécrit pas, la garde mesure bien le jeton.
      const Color declared = Color(0xFF002171);
      await _pumpBadge(
        tester,
        _themed(Brightness.dark, error: const Color(0xFFFFB4AB),
            onError: declared),
      );
      expect(
        _labelColor(tester),
        declared,
        reason:
            '🔴 le jeton de premier plan d\'erreur est déclaré et n\'est PAS '
            'peint : le libellé de pastille ne consomme pas le rôle prévu '
            'pour ce qui se pose sur la couleur d\'erreur',
      );
    });

    testWidgets(
      'T2 — NON déclaré, la chaîne appariée d\'origine reste (ambiant)',
      (WidgetTester tester) async {
        // Un rouge très sombre : l'ambiant clair du thème sombre y tient déjà
        // le plancher, donc la chaîne d'origine le rend INCHANGÉ — ce qui
        // rend la garde discriminante (une valeur, pas un intervalle).
        const Color error = Color(0xFF4A0000);
        await _pumpBadge(tester, _withoutOnError(Brightness.dark, error));
        final Color ambient = _ambient(tester);
        expect(
          _ratio(ambient, error),
          greaterThanOrEqualTo(4.5),
          reason: '🔬 scénario non atteint : l\'ambiant ne tient pas le '
              'plancher, la garde mesurerait une correction et non le repli',
        );
        expect(
          _labelColor(tester),
          ambient,
          reason:
              '🔴 sans jeton déclaré, le libellé ne vaut plus la couleur '
              'ambiante : le repli de la chaîne d\'origine a été perdu en '
              'ajoutant le rôle dédié',
        );
      },
    );

    testWidgets('T3 — un jeton ILLISIBLE est corrigé par le plancher', (
      WidgetTester tester,
    ) async {
      const Color error = Color(0xFFB3261E);
      await _pumpBadge(
        tester,
        // Premier plan = fond : contraste 1:1, le pire cas déclarable.
        _themed(Brightness.dark, error: error, onError: error),
      );
      final Color painted = _labelColor(tester);
      expect(
        painted,
        isNot(error),
        reason:
            '🔴 le jeton illisible est peint TEL QUEL : le plancher de '
            'contraste n\'est plus le garde-fou final',
      );
      expect(
        _ratio(painted, _badgeBackground(tester)),
        greaterThanOrEqualTo(4.5),
        reason: '🔴 le libellé corrigé reste sous le plancher du TEXTE',
      );
    });

    test('T4 — repli SYMÉTRIQUE : fond et premier plan, même schéma', () {
      for (final Brightness brightness in Brightness.values) {
        final ThemeData base = ThemeData(brightness: brightness);
        final ZcrudTheme tokens = ZcrudTheme.fallback(base);
        expect(
          (tokens.errorColor, tokens.onErrorColor),
          (base.colorScheme.error, base.colorScheme.onError),
          reason:
              '🔴 les deux rôles ne sont plus alimentés symétriquement depuis '
              'le schéma ($brightness) : un fond sans son premier plan est '
              'exactement le défaut corrigé',
        );
      }
    });

    testWidgets('T5 — rendu par DÉFAUT : au moins aussi lisible qu\'avant', (
      WidgetTester tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        final ThemeData base = ThemeData(brightness: brightness);
        final Color error = base.colorScheme.error;

        // L'AVANT : la chaîne appariée seule, sans le rôle dédié.
        await _pumpBadge(tester, _withoutOnError(brightness, error));
        final Color avant = _labelColor(tester);

        // L'APRÈS : le repli du socle porte désormais le rôle dédié.
        // `pumpAndSettle` : l'hôte Material INTERPOLE son thème, et une
        // couleur mesurée en cours de transition n'est celle d'aucun des deux.
        await _pumpBadge(tester, base);
        await tester.pumpAndSettle();
        final Color apres = _labelColor(tester);
        final Color background = _badgeBackground(tester);
        expect(background, error);

        expect(
          _ratio(apres, background),
          greaterThanOrEqualTo(4.5),
          reason: '🔴 le rendu par défaut passe sous le plancher du TEXTE',
        );
        expect(
          _ratio(apres, background),
          greaterThanOrEqualTo(_ratio(avant, background)),
          reason:
              '🔴 le rendu par défaut ($brightness) est MOINS lisible '
              'qu\'avant l\'ajout du rôle dédié : $avant → $apres',
        );
        // Le rôle dédié est bien la SOURCE du rendu par défaut : soit il tient
        // déjà le plancher et il est peint tel quel, soit il est la teinte
        // corrigée — jamais la couleur ambiante.
        if (_ratio(base.colorScheme.onError, background) >= 4.5) {
          expect(apres, base.colorScheme.onError);
        } else {
          expect(apres, isNot(_ambient(tester)));
        }
      }
    });
  });

  group('🔴 T — l\'accent d\'état ACTIF du composer', () {
    const Color accent = Color(0xFF1B5E20);

    testWidgets(
      'T6 — compact : ACTIF ≠ REPOS, par la couleur PEINTE — et l\'état reste '
      'annoncé ET écrit',
      (WidgetTester tester) async {
        final ZChatSettingsController settings = ZChatSettingsController();
        addTearDown(settings.dispose);
        final SemanticsHandle handle = tester.ensureSemantics();
        final String label = _fb(kZChatLabelCapabilityWebSearch);

        await tester.pumpWidget(
          _app(
            ZChatComposerWebSearchToggle(
              controller: settings,
              glyph: const Icon(_icon),
              // 🔴 LE cas de l'hôte : glyphe compact, sans libellé demandé.
              showLabel: false,
            ),
            theme: _themed(Brightness.light, activeAccent: accent),
          ),
        );
        final Color? rest = _glyphColor(tester);
        expect(_toggled(tester, label), Tristate.isFalse);

        settings.toggleCapability(kZChatCapabilityWebSearch);
        await tester.pump();

        final Color? active = _glyphColor(tester);
        expect(
          active,
          isNot(rest),
          reason:
              '🔴 en mode compact, un outil ACTIF est peint comme un outil au '
              'repos : le canal chromatique est absent',
        );
        expect(active, accent);
        // AD-13 : la couleur ne porte JAMAIS l'état seule.
        expect(
          _toggled(tester, label),
          Tristate.isTrue,
          reason:
              '🔴 l\'état actif n\'est plus ANNONCÉ : la couleur en serait le '
              'seul porteur',
        );
        expect(
          find.text(label),
          findsOneWidget,
          reason:
              '🔴 le libellé emphasé — canal visible non chromatique — a '
              'disparu du mode compact actif',
        );
        expect(
          tester.renderObject<RenderParagraph>(find.text(label)).text.style!
              .color,
          accent,
          reason: '🔴 le libellé actif n\'est pas teinté par l\'accent',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'T7 — contre-témoin ABSOLU : sans déclaration, rien ne change',
      (WidgetTester tester) async {
        final ZChatSettingsController settings = ZChatSettingsController();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          _app(
            ZChatComposerWebSearchToggle(
              controller: settings,
              glyph: const Icon(_icon),
              showLabel: false,
            ),
            theme: ThemeData(brightness: Brightness.light),
          ),
        );
        final Color? rest = _glyphColor(tester);
        expect(find.byType(ZForegroundOverride), findsNWidgets(0));

        settings.toggleCapability(kZChatCapabilityWebSearch);
        await tester.pump();

        expect(
          find.byType(ZForegroundOverride),
          findsNWidgets(0),
          reason:
              '🔴 une enveloppe de premier plan est posée alors qu\'aucun '
              'accent n\'est déclaré : le canal n\'est plus additif',
        );
        expect(
          _glyphColor(tester),
          rest,
          reason:
              '🔴 le glyphe d\'un hôte qui n\'a rien déclaré change de '
              'couleur : le rendu par défaut a bougé',
        );
      },
    );

    testWidgets('T8 — avec libellé, le canal TEXTUEL survit', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final String label = _fb(kZChatLabelRevealThinking);
      await tester.pumpWidget(
        _app(
          ZChatComposerThinkingToggle(
            controller: settings,
            glyph: const Icon(_icon),
          ),
          theme: _themed(Brightness.light, activeAccent: accent),
        ),
      );
      final TextStyle repos = tester.widget<Text>(find.text(label)).style!;
      settings.setRevealThinkingSteps(true);
      await tester.pump();
      final TextStyle actif = tester.widget<Text>(find.text(label)).style!;
      expect(
        (actif.fontWeight, actif.decoration),
        isNot((repos.fontWeight, repos.decoration)),
        reason:
            '🔴 l\'emphase textuelle a été REMPLACÉE par la couleur : le '
            'canal non chromatique devait subsister',
      );
      expect(
        actif.color,
        accent,
        reason: '🔴 la couleur ne s\'AJOUTE pas au canal textuel',
      );
    });

    testWidgets('T9 — un accent ILLISIBLE est porté au plancher', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final ThemeData base = ThemeData(brightness: Brightness.light);
      final Color surface = base.colorScheme.surface;
      await tester.pumpWidget(
        _app(
          ZChatComposerWebSearchToggle(
            controller: settings,
            glyph: const Icon(_icon),
            // L'hôte déclare l'accent le plus illisible qui soit : la surface.
            activeAccent: surface,
          ),
          theme: _themed(Brightness.light),
        ),
      );
      settings.toggleCapability(kZChatCapabilityWebSearch);
      await tester.pump();
      final Color painted = _glyphColor(tester)!;
      expect(
        painted,
        isNot(surface),
        reason:
            '🔴 l\'accent illisible déclaré par l\'hôte est peint tel quel : '
            'le plancher n\'est plus appliqué',
      );
      expect(
        _ratio(painted, surface),
        greaterThanOrEqualTo(3),
        reason: '🔴 l\'accent corrigé reste sous le plancher des composants',
      );
    });
  });
}
