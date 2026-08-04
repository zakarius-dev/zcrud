/// **CR-IFFD-56** — restitution EXACTE du rendu v0.43.0 sous le réglage
/// `hierarchy: ZStudyCardHierarchy.tintedTile`.
///
/// ## Les valeurs attendues sont POMPÉES, pas déduites
///
/// Chaque constante ci-dessous a été **mesurée sur le rendu v0.43.0 réel**
/// (widget pumpé AVANT le changement de défaut, même thème seedé
/// `0xFF3F51B5`, sonde du 2026-08-04) — jamais recalculée depuis le code
/// actuel : une garde qui rederiverait les attendus du code sous test serait
/// verte par construction. Un hôte qui a adopté le rendu v0.43.0 doit le
/// retrouver **à l'identique** (géométrie ET couleurs peintes), pas « à peu
/// près ».
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZStudyCardHierarchy;
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ── Valeurs MESURÉES sur v0.43.0 (sonde du 2026-08-04, seed 0xFF3F51B5) ─────

/// Tuile du document : paire dérivée du format `pdf` (fond).
const int kV43DocTileColor = 0xFFDEE0FF;

/// Tuile du document : premier plan apparié (glyphe et texte de puce).
const int kV43DocOnTileColor = 0xFF394379;

/// Barre d'accent de la note « Note de synthèse ».
const int kV43NoteAccentColor = 0xFFE0E1F9;

/// Tuile de la carte mentale `m1` (fond).
const int kV43MindmapTileColor = 0xFFFFDAD6;

/// Texte de la puce de compte de la carte mentale `m1`.
const int kV43MindmapOnTileColor = 0xFF93000A;

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 400, child: child),
        ),
      ),
    );

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('CR-IFFD-56 — restitution v0.43.0 sous `tintedTile`', () {
    testWidgets('document : tuile 40 dp COLORÉE r8, glyphe TYPÉ apparié, '
        'puce de format, chrome historique', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        subtitle: 'Hier',
        formatKey: 'pdf',
        formatLabel: 'PDF',
        hierarchy: ZStudyCardHierarchy.tintedTile,
      )));
      await tester.pumpAndSettle();

      // Tuile : taille, rayon, couleur PEINTE — les valeurs pompées.
      expect(tester.getSize(find.byKey(ZDefaultDocumentCard.iconTileKey)),
          const Size(40, 40));
      final BoxDecoration tile = tester
          .widget<DecoratedBox>(find.descendant(
              of: find.byKey(ZDefaultDocumentCard.iconTileKey),
              matching: find.byType(DecoratedBox)))
          .decoration as BoxDecoration;
      expect(tile.color?.toARGB32(), kV43DocTileColor,
          reason: '🔴 v0.43.0 : la tuile porte la paire du FORMAT.');
      expect(tile.borderRadius, const BorderRadius.all(Radius.circular(8)));

      // Glyphe : la TABLE v0.43.0 s'applique (pdf → picture_as_pdf), premier
      // plan apparié.
      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultDocumentCard.iconTileKey),
          matching: find.byType(Icon)));
      expect(glyph.icon, Icons.picture_as_pdf_outlined);
      expect(glyph.color?.toARGB32(), kV43DocOnTileColor);

      // Puce de format (metadata) : même paire, rayon 8, labelSmall 11.
      final BoxDecoration chip = tester
          .widget<DecoratedBox>(find.byKey(ZDefaultDocumentCard.formatChipKey))
          .decoration as BoxDecoration;
      expect(chip.color?.toARGB32(), kV43DocTileColor);
      expect(chip.borderRadius, const BorderRadius.all(Radius.circular(8)));
      final Text chipText =
          tester.widget<Text>(find.byKey(ZDefaultDocumentCard.formatLabelKey));
      expect(chipText.style?.color?.toARGB32(), kV43DocOnTileColor);
      expect(chipText.style?.fontSize, 11.0);
      // AUCUN badge d'extension en v0.43.0.
      expect(find.byKey(ZDefaultDocumentCard.extensionBadgeKey), findsNothing);

      // Chrome historique : marge zéro, forme radiusM SANS liseré, padding
      // gapM, titre titleSmall 14/w500 sur DEUX lignes.
      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, EdgeInsets.zero);
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(shape.side, BorderSide.none);
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is Padding && w.padding == const EdgeInsetsDirectional.all(8)),
        findsWidgets,
        reason: 'padding de carte v0.43.0 = gapM (8).',
      );
      final Text title = tester.widget<Text>(find.text('Doc'));
      expect(title.style?.fontSize, 14.0);
      expect(title.style?.fontWeight, FontWeight.w500);
      expect(title.maxLines, 2);
    });

    testWidgets('note : barre d\'accent 4 dp pleine largeur, couleur pompée, '
        'AUCUNE tuile', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultNoteCard(
        title: 'Note de synthèse',
        subtitle: 'Hier',
        excerpt: 'Extrait',
        hierarchy: ZStudyCardHierarchy.tintedTile,
      )));
      await tester.pumpAndSettle();

      final Size accent =
          tester.getSize(find.byKey(ZDefaultNoteCard.accentKey));
      expect(accent.height, 4);
      expect(accent.width, 400, reason: 'pleine largeur de la carte.');
      final ColoredBox bar = tester.widget<ColoredBox>(find.descendant(
          of: find.byKey(ZDefaultNoteCard.accentKey),
          matching: find.byType(ColoredBox)));
      expect(bar.color.toARGB32(), kV43NoteAccentColor,
          reason: '🔴 la couleur v0.43.0 (dérivée du titre) doit être '
              'RESTITUÉE, pas approchée.');
      expect(find.byKey(ZDefaultNoteCard.iconTileKey), findsNothing,
          reason: 'v0.43.0 n\'a AUCUNE tuile de note.');
      expect(find.byKey(ZDefaultNoteCard.excerptKey), findsOneWidget);
    });

    testWidgets('carte mentale : vignette 40 dp COLORÉE r8 + painter, puce de '
        'compte à la paire pompée', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(ZDefaultMindmapCard(
        map: ZMindmap(
          id: 'm1',
          folderId: 'f1',
          title: 'Plan',
          nodes: <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'r')],
        ),
        nodeCountLabel: (int n) => '$n noeuds',
        hierarchy: ZStudyCardHierarchy.tintedTile,
      )));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(ZDefaultMindmapCard.vignetteKey)),
          const Size(40, 40));
      final BoxDecoration tile = tester
          .widget<DecoratedBox>(find.descendant(
              of: find.byKey(ZDefaultMindmapCard.vignetteKey),
              matching: find.byType(DecoratedBox)))
          .decoration as BoxDecoration;
      expect(tile.color?.toARGB32(), kV43MindmapTileColor);
      expect(tile.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(
        find.descendant(
            of: find.byKey(ZDefaultMindmapCard.vignetteKey),
            matching: find.byType(CustomPaint)),
        findsOneWidget,
        reason: 'la vignette structurelle v0.43.0 est PEINTE.',
      );
      final Text count =
          tester.widget<Text>(find.byKey(ZDefaultMindmapCard.countLabelKey));
      expect(count.data, '1 noeuds');
      expect(count.style?.color?.toARGB32(), kV43MindmapOnTileColor);
    });

    testWidgets('CONTRE-PREUVE : le rendu de référence NE passe PAS cette '
        'garde (les deux hiérarchies diffèrent réellement)',
        (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        formatKey: 'pdf',
        formatLabel: 'PDF',
      )));
      await tester.pumpAndSettle();
      final BoxDecoration tile = tester
          .widget<DecoratedBox>(find
              .descendant(
                  of: find.byKey(ZDefaultDocumentCard.iconTileKey),
                  matching: find.byType(DecoratedBox))
              .first)
          .decoration as BoxDecoration;
      expect(tile.color?.toARGB32(), isNot(kV43DocTileColor),
          reason: '🔴 garde VACUELLE sinon : si le défaut rendait la même '
              'tuile, la restitution ne prouverait rien.');
    });
  });
}
