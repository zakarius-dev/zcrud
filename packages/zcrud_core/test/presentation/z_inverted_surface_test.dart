/// **CR-IFFD-42** — l'enveloppe d'inversion doit atteindre `Theme.textTheme`.
///
/// 🔴 **L'angle mort que ces gardes visent explicitement.** Une garde qui monte
/// un `Text` **nu** sous un fond inversé est **verte même quand le défaut est
/// présent** : le `Text` nu hérite du `DefaultTextStyle`, qui, lui, était bien
/// posé. Le contenu réellement cassé est celui qui suit la **bonne pratique** —
/// `Text(x, style: Theme.of(context).textTheme.titleSmall)` — parce que chaque
/// rôle de `TextTheme` porte sa PROPRE couleur (`inherit: false` dans la
/// typographie Material), qui court-circuite entièrement le `DefaultTextStyle`.
///
/// Chaque garde de lisibilité mesure donc la couleur **réellement peinte** sur
/// le `RenderParagraph` (texte) ou sur le `RichText` interne de l'`Icon`
/// (glyphe) — jamais une intention déclarée, jamais la présence d'un widget
/// d'enveloppe. Et chaque mesure est précédée d'un **contrôle de non-vacuité** :
/// si la couleur ambiante valait déjà `onInverseSurface`, l'assertion ne
/// prouverait rien.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ValueKey<String> _kStyled = ValueKey<String>('styled');
const ValueKey<String> _kBare = ValueKey<String>('bare');
const ValueKey<String> _kIcon = ValueKey<String>('icon');
const ValueKey<String> _kButton = ValueKey<String>('button');
const ValueKey<String> _kProbe = ValueKey<String>('probe');

/// Contenu de référence : les QUATRE chemins de style qu'un hôte peut emprunter,
/// plus une sonde de contexte pour lire le thème réellement en vigueur SOUS
/// l'enveloppe.
Widget _content() => Builder(
  builder: (BuildContext context) => Column(
    key: _kProbe,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // 🔴 LE chemin de la CR : styler depuis le `TextTheme` du thème.
      Text(
        'STYLED',
        key: _kStyled,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const Text('BARE', key: _kBare),
      const Icon(Icons.folder, key: _kIcon),
      TextButton(key: _kButton, onPressed: null, child: const Text('BTN')),
    ],
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool inverted,
  bool paintBackground = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: inverted
            ? ZInvertedSurface(
                padding: const EdgeInsetsDirectional.all(8),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                paintBackground: paintBackground,
                child: _content(),
              )
            : Padding(
                padding: const EdgeInsetsDirectional.all(8),
                child: _content(),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Couleur RÉELLEMENT peinte pour le texte porté par [key].
Color? _textColor(WidgetTester tester, Key key) =>
    (tester.renderObject(find.byKey(key)) as RenderParagraph).text.style?.color;

/// Couleur RÉELLEMENT peinte pour le GLYPHE de l'`Icon` portée par [key] —
/// mesurée sur le `RichText` que l'`Icon` construit, et non sur
/// `IconTheme.of(...)` : un socle pourrait poser le bon `IconTheme` et
/// néanmoins peindre autre chose (couleur explicite sur l'`Icon`).
Color? _glyphColor(WidgetTester tester, Key key) =>
    (tester.renderObject(
              find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
            )
            as RenderParagraph)
        .text
        .style
        ?.color;

/// Couleur peinte du LIBELLÉ d'un bouton (le bouton résout son premier plan
/// depuis le `ColorScheme`, pas depuis le `TextTheme`).
Color? _buttonLabelColor(WidgetTester tester) =>
    (tester.renderObject(
              find.descendant(
                of: find.byKey(_kButton),
                matching: find.text('BTN'),
              ),
            )
            as RenderParagraph)
        .text
        .style
        ?.color;

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(_kProbe))).colorScheme;

/// Écart de luminance — proxy honnête du contraste réellement perçu.
double _contrast(Color a, Color b) =>
    (a.computeLuminance() - b.computeLuminance()).abs();

void main() {
  group('CR-IFFD-42 — ZInvertedSurface atteint TOUS les chemins de style', () {
    testWidgets('🔴 un `Text` stylé depuis `textTheme.titleSmall` est peint en '
        '`onInverseSurface`', (tester) async {
      // (a) NON-VACUITÉ : hors enveloppe, ce même chemin peint AUTRE CHOSE.
      //     Sans ce relevé, l'assertion (b) pourrait être vraie par accident.
      await _pump(tester, inverted: false);
      final ColorScheme scheme = _scheme(tester);
      final Color? ambient = _textColor(tester, _kStyled);
      expect(ambient, isNotNull);
      expect(
        ambient,
        isNot(scheme.onInverseSurface),
        reason: 'garde de non-vacuité : la couleur ambiante ne doit pas déjà '
            'valoir la couleur inversée',
      );

      // (b) SOUS l'enveloppe, la couleur PEINTE est bien celle de l'inversion.
      await _pump(tester, inverted: true);
      expect(_textColor(tester, _kStyled), scheme.onInverseSurface);

      // (c) …et elle TRANCHE réellement sur le fond peint. Le couple de rôles
      //     seul ne prouve pas la lisibilité ; le contraste, si.
      expect(
        _contrast(scheme.inverseSurface, _textColor(tester, _kStyled)!),
        greaterThan(0.5),
      );
    });

    testWidgets('non-régression : un `Text` NU reste inversé lui aussi', (
      tester,
    ) async {
      await _pump(tester, inverted: false);
      final ColorScheme scheme = _scheme(tester);
      expect(_textColor(tester, _kBare), isNot(scheme.onInverseSurface));

      await _pump(tester, inverted: true);
      expect(_textColor(tester, _kBare), scheme.onInverseSurface);
    });

    testWidgets('non-régression : le GLYPHE d\'une `Icon` nue est inversé', (
      tester,
    ) async {
      await _pump(tester, inverted: false);
      final ColorScheme scheme = _scheme(tester);
      expect(_glyphColor(tester, _kIcon), isNot(scheme.onInverseSurface));

      await _pump(tester, inverted: true);
      expect(_glyphColor(tester, _kIcon), scheme.onInverseSurface);
    });

    testWidgets('TOUS les rôles de `TextTheme` sont repeints — pas seulement '
        'ceux du corps de texte', (tester) async {
      // `TextTheme.apply` distingue `bodyColor` et `displayColor` : n'en passer
      // qu'un laisserait la moitié des rôles à la couleur ambiante. Un hôte qui
      // stylerait depuis `headlineSmall` ou `displayLarge` retomberait alors
      // exactement dans le défaut corrigé ici.
      await _pump(tester, inverted: true);
      final ColorScheme scheme = _scheme(tester);
      final TextTheme t = Theme.of(
        tester.element(find.byKey(_kProbe)),
      ).textTheme;
      for (final MapEntry<String, TextStyle?> role
          in <String, TextStyle?>{
            'displayLarge': t.displayLarge,
            'headlineMedium': t.headlineMedium,
            'titleSmall': t.titleSmall,
            'bodyMedium': t.bodyMedium,
            'bodySmall': t.bodySmall,
            'labelSmall': t.labelSmall,
          }.entries) {
        expect(
          role.value?.color,
          scheme.onInverseSurface,
          reason: 'rôle `${role.key}` non inversé',
        );
      }
    });
  });

  group('CR-IFFD-42 — les effets de bord NON produits sont assertés', () {
    testWidgets('le `ColorScheme` de l\'hôte n\'est PAS substitué', (
      tester,
    ) async {
      await _pump(tester, inverted: false);
      final ColorScheme outside = _scheme(tester);
      await _pump(tester, inverted: true);
      // Substituer un `ThemeData` entier (inverseSurface promu en `surface`)
      // recolorerait boutons, cartes, séparateurs et états d'erreur de l'hôte.
      // L'enveloppe se borne aux rôles de TEXTE et d'ICÔNE : le `ColorScheme`
      // doit traverser INTACT.
      expect(_scheme(tester), outside);
    });

    testWidgets('la couleur d\'un BOUTON de l\'hôte n\'est pas détournée', (
      tester,
    ) async {
      await _pump(tester, inverted: false);
      final Color? outside = _buttonLabelColor(tester);
      expect(outside, isNotNull);

      await _pump(tester, inverted: true);
      // Un `TextButton` résout son premier plan depuis le `ColorScheme` et
      // l'applique PAR-DESSUS `textTheme.labelLarge` : l'enveloppe ne doit donc
      // rien y changer. C'est la limite documentée de la forme retenue — elle
      // est ici MESURÉE, pas supposée.
      expect(_buttonLabelColor(tester), outside);
    });
  });

  group('CR-IFFD-42 — neutralité et repli', () {
    testWidgets('`paintBackground: false` n\'ajoute AUCUN fond, mais inverse '
        'quand même le premier plan', (tester) async {
      await _pump(tester, inverted: true, paintBackground: false);
      final ColorScheme scheme = _scheme(tester);
      expect(_textColor(tester, _kStyled), scheme.onInverseSurface);
      expect(
        find.descendant(
          of: find.byType(ZInvertedSurface),
          matching: find.byType(Container),
        ),
        findsNothing,
        reason: 'aucun fond ne doit être peint quand l\'hôte peint le sien',
      );
    });

    testWidgets('le fond peint est `inverseSurface`, avec le rayon demandé', (
      tester,
    ) async {
      await _pump(tester, inverted: true);
      final Container c = tester.widget<Container>(
        find.descendant(
          of: find.byType(ZInvertedSurface),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration d = c.decoration! as BoxDecoration;
      expect(d.color, _scheme(tester).inverseSurface);
      expect(d.borderRadius, const BorderRadius.all(Radius.circular(8)));
    });

    testWidgets('HORS de l\'enveloppe, le thème est strictement inchangé', (
      tester,
    ) async {
      // L'inversion ne doit pas fuir vers le reste de l'arbre : une garde qui ne
      // mesurerait que l'intérieur laisserait passer un socle qui inverse tout.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ZInvertedSurface(child: _content()),
                Builder(
                  builder: (BuildContext c) => Text(
                    'OUTSIDE',
                    key: const ValueKey<String>('outside'),
                    style: Theme.of(c).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ColorScheme scheme = _scheme(tester);
      expect(_textColor(tester, _kStyled), scheme.onInverseSurface);
      expect(
        _textColor(tester, const ValueKey<String>('outside')),
        isNot(scheme.onInverseSurface),
      );
    });
  });
}
