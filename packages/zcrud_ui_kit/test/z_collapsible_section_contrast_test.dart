// CONTRASTE des textes de `ZCollapsibleSection`, en thème clair ET sombre.
//
// La mesure porte sur les couleurs **effectivement peintes**, lues dans
// l'arbre monté — jamais sur les rôles supposés. Le fond du disque de tête est
// semi-transparent : il est donc **composé** sur la surface qui le porte avant
// mesure, sans quoi le ratio serait calculé contre une couleur que personne ne
// voit.
//
// Seuils : 4,5 pour du texte (WCAG 2.1 AA), 3 pour un glyphe (objet
// graphique non textuel, WCAG 1.4.11).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Ratio de contraste WCAG 2.1, oracle LOCAL (luminance relative du SDK).
/// Résultat dans `[1, 21]`.
double wcagContrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(ThemeData theme) => MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZCollapsibleSection(
            title: 'Semaine du 1 au 7',
            count: 12,
            leadingIcon: Icons.calendar_month_rounded,
            child: const SizedBox(height: 20),
          ),
        ),
      ),
    );

/// Couleur peinte d'un texte monté : style explicite, sinon style hérité du
/// `DefaultTextStyle`, sinon le `onSurface` du thème (repli du SDK).
Color _paintedTextColor(WidgetTester tester, String text) {
  final Text widget = tester.widget<Text>(find.text(text));
  final Color? explicit = widget.style?.color;
  if (explicit != null) return explicit;
  final BuildContext context = tester.element(find.text(text));
  final TextStyle inherited = DefaultTextStyle.of(context).style;
  return inherited.color ?? Theme.of(context).colorScheme.onSurface;
}

Future<void> _report(
  WidgetTester tester,
  ThemeData theme,
  String label,
  List<String> lines,
) async {
  await tester.pumpWidget(_host(theme));
  await tester.pumpAndSettle();

  final BuildContext context = tester.element(find.text('Semaine du 1 au 7'));
  final ThemeData mounted = Theme.of(context);
  final ColorScheme scheme = mounted.colorScheme;

  // ── Titre sur l'en-tête ────────────────────────────────────────────────
  final Color titleColor = _paintedTextColor(tester, 'Semaine du 1 au 7');
  final Color headerSurface = mounted.cardColor;
  final double titleRatio = wcagContrastRatio(titleColor, headerSurface);

  // ── Pastille de compte ─────────────────────────────────────────────────
  final Color countColor = _paintedTextColor(tester, '12');
  final Container pill = tester.widget<Container>(
    find.ancestor(of: find.text('12'), matching: find.byType(Container)).first,
  );
  final Color pillSurface = (pill.decoration! as BoxDecoration).color!;
  final double countRatio = wcagContrastRatio(countColor, pillSurface);

  // ── Glyphe de tête sur son disque, COMPOSÉ sur l'en-tête ───────────────
  final Icon icon =
      tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded));
  final Container disc = tester.widget<Container>(
    find
        .ancestor(
          of: find.byIcon(Icons.calendar_month_rounded),
          matching: find.byType(Container),
        )
        .first,
  );
  final Color discSurface = Color.alphaBlend(
    (disc.decoration! as BoxDecoration).color!,
    headerSurface,
  );
  final double iconRatio = wcagContrastRatio(icon.color!, discSurface);

  lines.add('$label : titre ${titleRatio.toStringAsFixed(2)} · '
      'pastille ${countRatio.toStringAsFixed(2)} · '
      'glyphe ${iconRatio.toStringAsFixed(2)}');

  expect(
    titleRatio,
    greaterThanOrEqualTo(4.5),
    reason: '$label — titre ($titleColor) sur l\'en-tête ($headerSurface) : '
        '${titleRatio.toStringAsFixed(2)}, sous le seuil de texte.',
  );
  expect(
    countRatio,
    greaterThanOrEqualTo(4.5),
    reason: '$label — compte ($countColor) sur la pastille ($pillSurface) : '
        '${countRatio.toStringAsFixed(2)}, sous le seuil de texte.',
  );
  expect(
    iconRatio,
    greaterThanOrEqualTo(3),
    reason: '$label — glyphe (${icon.color}) sur le disque composé '
        '($discSurface) : ${iconRatio.toStringAsFixed(2)}, sous le seuil des '
        'objets graphiques.',
  );
  expect(scheme.secondaryContainer, isNot(scheme.onSecondaryContainer));
}

void main() {
  final List<String> measured = <String>[];
  tearDownAll(() {
    for (final String line in measured) {
      // ignore: avoid_print
      print(line);
    }
  });

  testWidgets('thème par défaut CLAIR : titre, pastille et glyphe lisibles',
      (WidgetTester tester) async {
    await _report(
      tester,
      ThemeData(brightness: Brightness.light, useMaterial3: true),
      'clair',
      measured,
    );
  });

  testWidgets('thème par défaut SOMBRE : titre, pastille et glyphe lisibles',
      (WidgetTester tester) async {
    await _report(
      tester,
      ThemeData(brightness: Brightness.dark, useMaterial3: true),
      'sombre',
      measured,
    );
  });

  testWidgets(
      'CONTRE-PREUVE : l\'oracle de contraste distingue bien lisible et '
      'illisible', (WidgetTester tester) async {
    expect(
      wcagContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      greaterThan(20),
    );
    expect(
      wcagContrastRatio(const Color(0xFF777777), const Color(0xFF808080)),
      lessThan(1.2),
    );
  });
}
