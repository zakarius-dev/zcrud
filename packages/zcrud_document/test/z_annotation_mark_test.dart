/// `ZAnnotationMark` — chaque nature d'annotation se REND différemment.
///
/// Les assertions lisent le `TextStyle` RÉELLEMENT appliqué au passage
/// (décoration, style de trait, fond, teinte du trait) — jamais la seule
/// présence d'un widget : un rendu qui aurait la même apparence pour deux
/// natures passerait une garde de présence et échoue ici.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';

const Color _hostFill = Color(0xFF123456);
const Color _hostOn = Color(0xFFFEDCBA);

ZColorPair? _hostResolver(ColorScheme scheme, String colorKey) =>
    colorKey == 'marker'
        ? const ZColorPair(color: _hostFill, onColor: _hostOn)
        : null;

Widget _wrap(
  Widget child, {
  ZcrudLabels? labels,
  ZColorKeyResolver? colorKeyResolver,
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: ZcrudScope(
          labels: labels,
          colorKeyResolver: colorKeyResolver,
          child: Scaffold(body: child),
        ),
      ),
    );

Finder _markOf(ZDocumentAnnotationKind kind) => find.byKey(
    ValueKey<String>('$kAnnotationMarkKeyPrefix${kind.name}'));

TextStyle _styleOf(WidgetTester tester, ZDocumentAnnotationKind kind) =>
    tester.widget<Text>(_markOf(kind)).style!;

/// Signature OBSERVABLE d'un rendu : le triplet qui distingue les natures.
({TextDecoration? d, TextDecorationStyle? s, bool filled}) _signature(
        TextStyle st) =>
    (d: st.decoration, s: st.decorationStyle, filled: st.backgroundColor != null);

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // 1 — Les cinq natures rendent des signatures DEUX À DEUX DISTINCTES.
  // ═══════════════════════════════════════════════════════════════════════
  group('discrimination — une apparence observable par nature', () {
    testWidgets('les signatures de rendu sont deux à deux distinctes',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: <Widget>[
            for (final kind in ZDocumentAnnotationKind.values)
              ZAnnotationMark(text: 'passage', kind: kind, colorKey: 'marker'),
          ],
        ),
        colorKeyResolver: _hostResolver,
      ));

      final signatures = <ZDocumentAnnotationKind,
          ({TextDecoration? d, TextDecorationStyle? s, bool filled})>{
        for (final kind in ZDocumentAnnotationKind.values)
          kind: _signature(_styleOf(tester, kind)),
      };

      // 🔴 Le cœur de la garde : aucune paire de natures ne partage la même
      // apparence. Si `squiggly` était rendu comme `underline`, ceci rougit.
      for (final a in ZDocumentAnnotationKind.values) {
        for (final b in ZDocumentAnnotationKind.values) {
          if (a == b) continue;
          expect(signatures[a], isNot(signatures[b]),
              reason: '`${a.name}` et `${b.name}` rendent à l\'identique : '
                  'la nature ne se lit plus sur le rendu.');
        }
      }
      expect(signatures.values.toSet().length,
          ZDocumentAnnotationKind.values.length);
    });

    testWidgets('chaque nature rend l\'apparence CANONIQUE attendue',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: <Widget>[
            for (final kind in ZDocumentAnnotationKind.values)
              ZAnnotationMark(text: 'passage', kind: kind, colorKey: 'marker'),
          ],
        ),
        colorKeyResolver: _hostResolver,
      ));

      // Surlignage : fond rempli de la teinte injectée, texte sur son `on-`,
      // aucun trait.
      final hl = _styleOf(tester, ZDocumentAnnotationKind.highlight);
      expect(hl.backgroundColor, _hostFill);
      expect(hl.color, _hostOn);
      expect(hl.decoration, TextDecoration.none);

      // Soulignage : trait continu SOUS la ligne, aucun fond.
      final ul = _styleOf(tester, ZDocumentAnnotationKind.underline);
      expect(ul.decoration, TextDecoration.underline);
      expect(ul.decorationStyle, TextDecorationStyle.solid);
      expect(ul.backgroundColor, isNull);
      expect(ul.decorationColor, _hostFill);

      // Barrage : trait AU MILIEU du texte — jamais un soulignage.
      final st = _styleOf(tester, ZDocumentAnnotationKind.strikethrough);
      expect(st.decoration, TextDecoration.lineThrough);
      expect(st.decorationStyle, TextDecorationStyle.solid);
      expect(st.backgroundColor, isNull);
      expect(st.decorationColor, _hostFill);

      // Ondulé : soulignage ONDULÉ — c'est le style de trait, et lui seul,
      // qui le sépare du soulignage simple.
      final sq = _styleOf(tester, ZDocumentAnnotationKind.squiggly);
      expect(sq.decoration, TextDecoration.underline);
      expect(sq.decorationStyle, TextDecorationStyle.wavy);
      expect(sq.backgroundColor, isNull);
      expect(sq.decorationColor, _hostFill);

      // Note ancrée : ne marque pas le texte (son marqueur est un point sur
      // la page, dessiné par la visionneuse).
      final sn = _styleOf(tester, ZDocumentAnnotationKind.stickyNote);
      expect(sn.decoration, TextDecoration.none);
      expect(sn.backgroundColor, isNull);

      // 🔴 La teinte d'annotation ne FUIT PAS dans un trait qui n'est pas
      // dessiné. Assertion volontairement formulée en « n'est pas la teinte »
      // et non en « est null » : le `bodyMedium` du thème porte DÉJÀ un
      // `decorationColor` (= `onSurface`), qu'un `copyWith` ne peut pas
      // effacer. Exiger `null` aurait mesuré une propriété du thème, pas une
      // propriété du rendu — et serait resté vert si le socle appliquait la
      // teinte à toutes les natures. Formulée ainsi, la garde rougit dans ce
      // cas précis.
      final Color? baseDecorationColor =
          Theme.of(tester.element(_markOf(ZDocumentAnnotationKind.stickyNote)))
              .textTheme
              .bodyMedium
              ?.decorationColor;
      for (final sansTrait in <TextStyle>[hl, sn]) {
        expect(sansTrait.decorationColor, isNot(_hostFill),
            reason: 'aucune décoration n\'est peinte : la teinte de '
                'l\'annotation n\'a rien à y faire.');
        expect(sansTrait.decorationColor, baseDecorationColor,
            reason: 'le style de base est laissé intact.');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2 — Couleur et épaisseur INJECTÉES (FR-26), repli total (AD-10).
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-26 — teinte et épaisseur injectées, repli garanti', () {
    testWidgets('sans résolveur hôte, le rendu tient sur le ColorScheme',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: <Widget>[
            for (final kind in ZDocumentAnnotationKind.values)
              ZAnnotationMark(text: 'p', kind: kind, colorKey: 'inconnue'),
          ],
        ),
      ));
      expect(tester.takeException(), isNull);
      final scheme =
          Theme.of(tester.element(_markOf(ZDocumentAnnotationKind.underline)))
              .colorScheme;
      final ul = _styleOf(tester, ZDocumentAnnotationKind.underline);
      // La teinte du trait vient du repli de slot, pas d'un hex du socle.
      expect(ul.decorationColor, isNotNull);
      expect(ul.decorationColor, isNot(_hostFill));
      expect(zColorSlotPair(scheme, 0).color, ul.decorationColor);
    });

    testWidgets('épaisseur : `null` ⇒ celle de la police ; sinon la valeur',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: const <Widget>[
            ZAnnotationMark(
              key: ValueKey<String>('sans'),
              text: 'p',
              kind: ZDocumentAnnotationKind.underline,
            ),
            ZAnnotationMark(
              key: ValueKey<String>('avec'),
              text: 'p',
              kind: ZDocumentAnnotationKind.strikethrough,
              thickness: 2.5,
            ),
          ],
        ),
      ));
      // Aucun nombre n'est figé par le socle quand l'hôte ne dit rien.
      expect(_styleOf(tester, ZDocumentAnnotationKind.underline)
          .decorationThickness, isNull);
      expect(_styleOf(tester, ZDocumentAnnotationKind.strikethrough)
          .decorationThickness, 2.5);
    });

    testWidgets('le style de base injecté est PRÉSERVÉ (jamais écrasé)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ZAnnotationMark(
          text: 'p',
          kind: ZDocumentAnnotationKind.squiggly,
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
      ));
      final sq = _styleOf(tester, ZDocumentAnnotationKind.squiggly);
      expect(sq.fontSize, 27);
      expect(sq.fontWeight, FontWeight.w900);
      expect(sq.decorationStyle, TextDecorationStyle.wavy);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3 — AD-13 : la nature est annoncée, et l'annonce est SUPPRIMABLE.
  // ═══════════════════════════════════════════════════════════════════════
  group('AD-13 — la nature circule par un canal non visuel', () {
    testWidgets('la nature est annoncée, et deux natures s\'annoncent '
        'DIFFÉREMMENT', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        Column(
          children: const <Widget>[
            ZAnnotationMark(
                text: 'alpha', kind: ZDocumentAnnotationKind.underline),
            ZAnnotationMark(
                text: 'alpha', kind: ZDocumentAnnotationKind.strikethrough),
          ],
        ),
      ));
      // Même texte, deux natures : sans l'annonce, un lecteur d'écran
      // restituerait les deux passages à l'identique.
      expect(
        tester.getSemantics(_markOf(ZDocumentAnnotationKind.underline)).label,
        'underline',
      );
      expect(
        tester
            .getSemantics(_markOf(ZDocumentAnnotationKind.strikethrough))
            .label,
        'strikethrough',
      );
      expect(
        tester.getSemantics(_markOf(ZDocumentAnnotationKind.underline)).value,
        'alpha',
      );
      handle.dispose();
    });

    testWidgets('le libellé de nature est INJECTABLE (jamais en dur)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const ZAnnotationMark(
            text: 'p', kind: ZDocumentAnnotationKind.squiggly),
        labels: ZcrudLabels(<String, String>{
          'zcrud.annotation.kind.squiggly': 'souligné ondulé',
        }),
      ));
      expect(
        tester.getSemantics(_markOf(ZDocumentAnnotationKind.squiggly)).label,
        'souligné ondulé',
      );
      handle.dispose();
    });

    testWidgets('`announceKind: false` retire l\'annonce sans changer le rendu',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const ZAnnotationMark(
          text: 'p',
          kind: ZDocumentAnnotationKind.underline,
          announceKind: false,
        ),
      ));
      final node = tester.getSemantics(_markOf(ZDocumentAnnotationKind.underline));
      expect(node.label, 'p',
          reason: 'sans annonce, seul le texte du passage est énoncé.');
      // Le rendu visuel, lui, est inchangé.
      final st = _styleOf(tester, ZDocumentAnnotationKind.underline);
      expect(st.decoration, TextDecoration.underline);
      expect(st.decorationStyle, TextDecorationStyle.solid);
      handle.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4 — INERTIE : ce qui n'emploie que les natures antérieures ne bouge pas.
  // ═══════════════════════════════════════════════════════════════════════
  group('inertie — les natures antérieures rendent comme avant', () {
    testWidgets('le panneau garde ses icônes historiques', (tester) async {
      await tester.pumpWidget(_wrap(
        const SizedBox(
          height: 400,
          child: ZAnnotationPanel(
            annotations: <ZDocumentAnnotation>[
              ZDocumentAnnotation(
                  id: 'a', text: 'x', kind: ZDocumentAnnotationKind.highlight),
              ZDocumentAnnotation(
                  id: 'b', text: 'y', kind: ZDocumentAnnotationKind.stickyNote),
            ],
          ),
        ),
      ));
      final icons =
          tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon).toList();
      expect(icons, <IconData>[
        Icons.brush_outlined,
        Icons.sticky_note_2_outlined,
      ]);
    });

    testWidgets('le panneau donne aux natures neuves des icônes DISTINCTES',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SizedBox(
          height: 600,
          child: ZAnnotationPanel(
            annotations: <ZDocumentAnnotation>[
              ZDocumentAnnotation(
                  id: 'a', text: 'x', kind: ZDocumentAnnotationKind.highlight),
              ZDocumentAnnotation(
                  id: 'b', text: 'y', kind: ZDocumentAnnotationKind.stickyNote),
              ZDocumentAnnotation(
                  id: 'c', text: 'z', kind: ZDocumentAnnotationKind.underline),
              ZDocumentAnnotation(
                  id: 'd',
                  text: 'w',
                  kind: ZDocumentAnnotationKind.strikethrough),
              ZDocumentAnnotation(
                  id: 'e', text: 'v', kind: ZDocumentAnnotationKind.squiggly),
            ],
          ),
        ),
      ));
      final icons =
          tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon).toSet();
      expect(icons.length, 5,
          reason: 'deux natures partageant une icône rendraient le canal '
              'non-coloré du panneau ambigu.');
    });

    testWidgets('la barre d\'outils peut être FIGÉE sur le jeu antérieur',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ZAnnotationToolbar(
          kinds: <ZDocumentAnnotationKind>[
            ZDocumentAnnotationKind.highlight,
            ZDocumentAnnotationKind.stickyNote,
          ],
        ),
      ));
      expect(
          find.byKey(const ValueKey<String>(
              '${kAnnotationKindKeyPrefix}highlight')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              '${kAnnotationKindKeyPrefix}underline')),
          findsNothing);
      expect(
          find.byKey(const ValueKey<String>(
              '${kAnnotationKindKeyPrefix}squiggly')),
          findsNothing);
    });

    testWidgets('par défaut la barre propose TOUTES les natures',
        (tester) async {
      await tester.pumpWidget(_wrap(const ZAnnotationToolbar()));
      for (final kind in ZDocumentAnnotationKind.values) {
        expect(
            find.byKey(
                ValueKey<String>('$kAnnotationKindKeyPrefix${kind.name}')),
            findsOneWidget,
            reason: '`${kind.name}` doit être proposable.');
      }
    });
  });
}
