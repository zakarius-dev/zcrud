/// **CR-IFFD-56** (absorbe CR-IFFD-55) — les trois cartes par défaut
/// (document, note, carte mentale) répliquent le rendu de RÉFÉRENCE **sans
/// aucun réglage**, chaque valeur restant surchargeable (paramètre > jeton
/// `studyCard*` > défaut-référence), et le rendu v0.43.0 reste atteignable
/// par réglage (`tintedTile`) — restitution EXACTE gardée dans
/// `cr_iffd56_v43_restitution_test.dart`.
///
/// ## Leçon « une garde hérite de l'angle mort de son auteur », appliquée
///
/// « Le glyphe est teinté » se mesure en couleur peinte du glyphe **ET** de la
/// tuile — une garde qui ne regarde que le glyphe resterait verte si la tuile
/// était AUSSI colorée. Le badge d'extension se mesure en **géométrie de
/// surimpression** (il chevauche la tuile) et en **texte rendu**.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZStudyCardHierarchy, ZcrudTheme;
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

const Color _seed = Color(0xFF3F51B5);

ThemeData _material({ZcrudTheme? tokens}) {
  final ThemeData base = ThemeData(colorSchemeSeed: _seed);
  if (tokens == null) return base;
  return base.copyWith(extensions: <ThemeExtension<dynamic>>[tokens]);
}

Widget _host(Widget child, {ZcrudTheme? tokens, ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? _material(tokens: tokens),
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 420, child: child),
        ),
      ),
    );

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

BoxDecoration _decoOf(WidgetTester tester, Key key) {
  final Widget keyed = tester.widget(find.byKey(key));
  if (keyed is DecoratedBox) return keyed.decoration as BoxDecoration;
  return tester
      .widget<DecoratedBox>(find
          .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
          .first)
      .decoration as BoxDecoration;
}

ZMindmap _mindmap() => ZMindmap(
      id: 'm1',
      folderId: 'f1',
      title: 'Plan',
      nodes: <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'r')],
    );

void main() {
  // -------------------------------------------------------------------------
  group('CR-IFFD-56 §document — rendu de référence SANS réglage', () {
    testWidgets(
        'tuile NEUTRE (surface) ET glyphe TEINTÉ par le format — les DEUX '
        'couleurs mesurées', (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material();
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(
          title: 'Doc',
          subtitle: 'Hier',
          formatKey: 'pdf',
          formatLabel: 'PDF',
        ),
        theme: material,
      ));
      await tester.pumpAndSettle();

      // Tuile : NEUTRE — le rôle `surface`, jamais la paire d'accent.
      final BoxDecoration tile =
          _decoOf(tester, ZDefaultDocumentCard.iconTileKey);
      expect(tile.color?.toARGB32(),
          material.colorScheme.surface.toARGB32(),
          reason: '🔴 CR-56 : la tuile de référence est NEUTRE (surface) — '
              'une tuile encore colorée est le rendu v0.43.0.');

      // Glyphe : TEINTÉ (≠ neutre) — et c'est la MÊME couleur que le fond du
      // badge d'extension (la couleur résolue du format).
      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultDocumentCard.iconTileKey),
          matching: find.byType(Icon)));
      final BoxDecoration badge =
          _decoOf(tester, ZDefaultDocumentCard.extensionBadgeKey);
      expect(glyph.color, isNotNull);
      expect(glyph.color!.toARGB32(), badge.color!.toARGB32(),
          reason: 'glyphe et badge portent la couleur du FORMAT.');
      expect(glyph.color!.toARGB32(),
          isNot(material.colorScheme.surface.toARGB32()));
      expect(glyph.color!.toARGB32(),
          isNot(material.colorScheme.onSurfaceVariant.toARGB32()),
          reason: '🔴 un glyphe NEUTRE signifierait que la teinte par format '
              'a disparu.');

      // Géométrie de la tuile : jetons `studyCardIconTile*`, référence 48/12.
      expect(tester.getSize(find.byKey(ZDefaultDocumentCard.iconTileKey)),
          const Size(48, 48));
      expect(tile.borderRadius,
          const BorderRadius.all(Radius.circular(12)));
    });

    testWidgets('glyphe par défaut = UNIQUE (description_outlined), pas la '
        'table v0.43.0', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        formatKey: 'pdf',
        formatLabel: 'PDF',
      )));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: find.byKey(ZDefaultDocumentCard.iconTileKey),
            matching: find.byIcon(Icons.description_outlined)),
        findsOneWidget,
        reason: 'référence : différenciation par COULEUR + badge, glyphe '
            'unique.',
      );
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing,
          reason: '🔴 la table v0.43.0 ne s\'applique PAS en référence.');
    });

    testWidgets('badge d\'extension : géométrie LEGACY mesurée (coin du '
        'glyphe, DANS la tuile), texte rendu, premier plan apparié, rayon '
        '`radiusS`', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        subtitle: 'Hier',
        formatKey: 'pdf',
        formatLabel: 'PDF',
      )));
      await tester.pumpAndSettle();

      // Géométrie LEGACY (`_iconeDocumentLegacy`) : le badge est épinglé au
      // coin bas-fin du GLYPHE (28) centré dans la tuile (48) — donc DANS la
      // tuile, son bord à (48 − 28) / 2 = 10 dp du bord de tuile, en
      // surimpression sur le glyphe, JAMAIS en débord de tuile.
      final Rect tile =
          tester.getRect(find.byKey(ZDefaultDocumentCard.iconTileKey));
      final Rect badge =
          tester.getRect(find.byKey(ZDefaultDocumentCard.extensionBadgeKey));
      expect(badge.overlaps(tile), isTrue,
          reason: '🔴 un badge qui ne chevauche pas la tuile est une puce '
              'voisine, pas une surimpression.');
      const double inset = (48 - 28) / 2;
      expect(tile.bottom - badge.bottom, inset,
          reason: '🔴 le badge est épinglé au coin du GLYPHE centré '
              '(bord à 10 dp du bord de tuile) — un débord (-3) ou un '
              'collage au bord de tuile (0) trahit la géométrie legacy.');
      expect(tile.right - badge.right, inset,
          reason: 'même ancrage côté fin (LTR).');
      // Et il chevauche le GLYPHE : c'est une surimpression, pas un voisin.
      expect(badge.top, lessThan(tile.bottom - inset),
          reason: 'le badge recouvre le coin du glyphe.');

      // Texte RENDU (AD-13 : l\'info couleur est AUSSI en texte).
      final Text label = tester
          .widget<Text>(find.byKey(ZDefaultDocumentCard.extensionLabelKey));
      expect(label.data, 'PDF');

      // Matière : fond = couleur du format, texte = premier plan APPARIÉ.
      final BoxDecoration deco =
          _decoOf(tester, ZDefaultDocumentCard.extensionBadgeKey);
      expect(label.style?.color, isNotNull);
      expect(label.style!.color!.toARGB32(),
          isNot(deco.color!.toARGB32()));
      // Métriques LEGACY du badge : 8 / bold (`kStudyToolsLeadingIconSize`
      // voisin) — PAS le `labelSmall` ambiant (11). C'est la fonte qui rend
      // le badge « bas-fin » lisible sans envahir la tuile.
      expect(label.style!.fontSize, 8,
          reason: '🔴 fonte du badge = 8 (legacy), pas le labelSmall ambiant.');
      expect(label.style!.fontWeight, FontWeight.bold,
          reason: 'graisse du badge = bold (legacy).');
      // Rayon : `studyCardBadgeRadius` repli `radiusS` (référence 4).
      expect(deco.borderRadius, const BorderRadius.all(Radius.circular(4)));
    });

    testWidgets('AD-4 : sans `formatLabel`, AUCUN badge (jamais un libellé '
        'inventé)', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(
          const ZDefaultDocumentCard(title: 'Doc', formatKey: 'pdf')));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultDocumentCard.extensionBadgeKey), findsNothing);
      expect(find.text('PDF'), findsNothing);
      expect(find.text('pdf'), findsNothing);
    });

    testWidgets('AD-13 : le format reste ANNONCÉ dans le libellé sémantique',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        subtitle: 'Hier',
        formatKey: 'pdf',
        formatLabel: 'PDF',
      )));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Doc, Hier, PDF'), findsOneWidget);
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-55 — `formatColors`, symétrique de `formatIcons`', () {
    const ZColorPair injected = ZColorPair(
      color: Color(0xFFB71C1C),
      onColor: Color(0xFFFFFFFF),
    );

    test('normalisation IDENTIQUE au glyphe (extension, point, casse, MIME)',
        () {
      const Map<String, ZColorPair> colors = <String, ZColorPair>{
        'pdf': injected,
      };
      expect(zLookupDocumentFormatColor('pdf', colors), injected);
      expect(zLookupDocumentFormatColor('.PDF', colors), injected);
      expect(zLookupDocumentFormatColor('application/pdf', colors), injected);
      expect(zLookupDocumentFormatColor('docx', colors), isNull,
          reason: 'aucune entrée ⇒ null : l\'appelant retombe sur le tirage '
              'stable — le socle ne fige AUCUNE convention format→couleur.');
      expect(zLookupDocumentFormatColor(null, colors), isNull);
      expect(zLookupDocumentFormatColor('pdf', null), isNull);
      // Famille MIME en dernier recours, comme le glyphe.
      const Map<String, ZColorPair> family = <String, ZColorPair>{
        'image': injected,
      };
      expect(zLookupDocumentFormatColor('image/x-exotic', family), injected);
    });

    testWidgets('la paire INJECTÉE teinte le glyphe ET le badge — la tuile '
        'reste neutre', (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material();
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(
          title: 'Doc',
          formatKey: 'application/pdf',
          formatLabel: 'PDF',
          formatColors: <String, ZColorPair>{'pdf': injected},
        ),
        theme: material,
      ));
      await tester.pumpAndSettle();

      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultDocumentCard.iconTileKey),
          matching: find.byType(Icon)));
      expect(glyph.color!.toARGB32(), injected.color.toARGB32(),
          reason: '🔴 CR-55 : la convention de couleur de l\'hôte doit être '
              'exprimable — « PDF rouge » par une entrée de map, jamais une '
              'CR.');
      final BoxDecoration badge =
          _decoOf(tester, ZDefaultDocumentCard.extensionBadgeKey);
      expect(badge.color!.toARGB32(), injected.color.toARGB32());
      final Text label = tester
          .widget<Text>(find.byKey(ZDefaultDocumentCard.extensionLabelKey));
      expect(label.style!.color!.toARGB32(), injected.onColor.toARGB32(),
          reason: 'texte inversé = le `onColor` de la paire injectée.');
      final BoxDecoration tile =
          _decoOf(tester, ZDefaultDocumentCard.iconTileKey);
      expect(tile.color?.toARGB32(),
          material.colorScheme.surface.toARGB32(),
          reason: 'la tuile reste NEUTRE même sous couleur injectée.');
    });

    testWidgets('`colorKey` (par item) PRIME sur `formatColors` (par format)',
        (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        formatKey: 'pdf',
        formatLabel: 'PDF',
        formatColors: <String, ZColorPair>{'pdf': injected},
        colorKey: 'gamma',
      )));
      await tester.pumpAndSettle();
      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultDocumentCard.iconTileKey),
          matching: find.byType(Icon)));
      expect(glyph.color!.toARGB32(), isNot(injected.color.toARGB32()),
          reason: 'le réglage PAR ITEM est plus spécifique que la convention '
              'par format.');
    });

    testWidgets('`formatIcons` injecté PRIME sur le glyphe unique de '
        'référence ; `icon` prime sur tout', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        formatKey: 'application/pdf',
        formatIcons: <String, IconData>{'pdf': Icons.star_outline},
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_outline), findsOneWidget);

      await tester.pumpWidget(_host(const ZDefaultDocumentCard(
        title: 'Doc',
        formatKey: 'pdf',
        formatIcons: <String, IconData>{'pdf': Icons.star_outline},
        icon: Icons.animation,
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.animation), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 — chrome commun de référence (les six dimensions)', () {
    testWidgets('rayon 16, liseré outlineVariant 50 %, marge 4, padding 12, '
        'titre titleMedium/w600/15 UNE ligne, sous-titre onSurfaceVariant',
        (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material();
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(title: 'Doc', subtitle: 'Hier'),
        theme: material,
      ));
      await tester.pumpAndSettle();

      final Card card = tester.widget<Card>(find.byType(Card));
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius,
          const BorderRadius.all(Radius.circular(16)));
      expect(shape.side.width, 1);
      expect(
          shape.side.color.toARGB32(),
          material.colorScheme.outlineVariant
              .withValues(alpha: 0.5)
              .toARGB32());
      expect(card.margin, const EdgeInsetsDirectional.all(4));
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is Padding && w.padding == const EdgeInsetsDirectional.all(12)),
        findsWidgets,
        reason: 'padding de carte 12 (référence).',
      );
      final Text title = tester.widget<Text>(find.text('Doc'));
      expect(title.style?.fontSize, 15);
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.maxLines, 1, reason: 'référence : titre sur UNE ligne.');
      final Text sub = tester.widget<Text>(find.text('Hier'));
      expect(sub.style?.color?.toARGB32(),
          material.colorScheme.onSurfaceVariant.toARGB32());
    });

    testWidgets('les trois cartes portent le MÊME chrome (structure '
        'ZStudyToolsItemCard partagée)', (WidgetTester tester) async {
      _wide(tester);
      Future<String> chromeOf(Widget child) async {
        await tester.pumpWidget(_host(child));
        await tester.pumpAndSettle();
        final Card card = tester.widget<Card>(find.byType(Card));
        final RoundedRectangleBorder s = card.shape! as RoundedRectangleBorder;
        return '${s.borderRadius}|${s.side.width}|${s.side.color.toARGB32()}'
            '|${card.margin}';
      }

      final String doc = await chromeOf(
          const ZDefaultDocumentCard(title: 'D', subtitle: 'S'));
      final String note =
          await chromeOf(const ZDefaultNoteCard(title: 'N', subtitle: 'S'));
      final String mm = await chromeOf(ZDefaultMindmapCard(map: _mindmap()));
      expect(note, doc);
      expect(mm, doc);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 §note — rendu de référence', () {
    testWidgets('tuile NEUTRE + glyphe note_outlined NEUTRE ; AUCUNE barre '
        'd\'accent', (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material();
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: 'Note', subtitle: 'Hier'),
        theme: material,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZDefaultNoteCard.accentKey), findsNothing,
          reason: 'la barre d\'accent est le rendu v0.43.0 (`tintedTile`).');
      final BoxDecoration tile = _decoOf(tester, ZDefaultNoteCard.iconTileKey);
      expect(tile.color?.toARGB32(),
          material.colorScheme.surface.toARGB32());
      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultNoteCard.iconTileKey),
          matching: find.byType(Icon)));
      expect(glyph.icon, Icons.note_outlined);
      expect(glyph.color!.toARGB32(),
          material.colorScheme.onSurfaceVariant.toARGB32(),
          reason: 'glyphe NEUTRE (rôle onSurfaceVariant) — la note n\'est pas '
              'teintée par un format.');
      expect(tester.getSize(find.byKey(ZDefaultNoteCard.iconTileKey)),
          const Size(48, 48));
    });

    testWidgets('extrait et balises : OPTIONS toujours rendues quand fournies '
        '(pas retirées, plus imposées)', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultNoteCard(
        title: 'Note',
        excerpt: 'Extrait fourni par l\'hôte',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.excerptKey), findsOneWidget);

      await tester.pumpWidget(_host(const ZDefaultNoteCard(title: 'Note')));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.excerptKey), findsNothing);
      expect(find.byKey(ZDefaultNoteCard.tagsKey), findsNothing);
    });

    testWidgets('`icon` surcharge le glyphe de la tuile',
        (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(const ZDefaultNoteCard(
          title: 'Note', icon: Icons.sticky_note_2_outlined)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.note_outlined), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 §mindmap — rendu de référence', () {
    testWidgets('tuile NEUTRE + glyphe hub_outlined NEUTRE ; AUCUNE vignette '
        'peinte', (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material();
      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(map: _mindmap()),
        theme: material,
      ));
      await tester.pumpAndSettle();

      final BoxDecoration tile =
          _decoOf(tester, ZDefaultMindmapCard.vignetteKey);
      expect(tile.color?.toARGB32(),
          material.colorScheme.surface.toARGB32());
      final Icon glyph = tester.widget<Icon>(find.descendant(
          of: find.byKey(ZDefaultMindmapCard.vignetteKey),
          matching: find.byType(Icon)));
      expect(glyph.icon, Icons.hub_outlined);
      expect(glyph.color!.toARGB32(),
          material.colorScheme.onSurfaceVariant.toARGB32());
      expect(
        find.descendant(
            of: find.byKey(ZDefaultMindmapCard.vignetteKey),
            matching: find.byType(CustomPaint)),
        findsNothing,
        reason: 'la vignette structurelle est le rendu v0.43.0 '
            '(`tintedTile`).',
      );
    });

    testWidgets('compteur de nœuds : OPTION rendue quand le libellé est '
        'injecté, absente sinon (AD-4/FR-26)', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(_host(ZDefaultMindmapCard(
        map: _mindmap(),
        nodeCountLabel: (int n) => '$n nœuds',
      )));
      await tester.pumpAndSettle();
      expect(find.text('1 nœuds'), findsOneWidget);

      await tester.pumpWidget(_host(ZDefaultMindmapCard(map: _mindmap())));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultMindmapCard.countChipKey), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 — surcharge : paramètre > jeton > référence', () {
    testWidgets('jeton `studyCardHierarchy: tintedTile` bascule les TROIS '
        'cartes vers v0.43.0', (WidgetTester tester) async {
      _wide(tester);
      const ZcrudTheme tokens =
          ZcrudTheme(studyCardHierarchy: ZStudyCardHierarchy.tintedTile);

      await tester.pumpWidget(_host(
          const ZDefaultNoteCard(title: 'Note'), tokens: tokens));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.accentKey), findsOneWidget);

      await tester.pumpWidget(_host(
          const ZDefaultDocumentCard(title: 'Doc', formatKey: 'pdf'),
          tokens: tokens));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

      await tester.pumpWidget(
          _host(ZDefaultMindmapCard(map: _mindmap()), tokens: tokens));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: find.byKey(ZDefaultMindmapCard.vignetteKey),
            matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    });

    testWidgets('le PARAMÈTRE de carte prime sur le jeton (hiérarchie)',
        (WidgetTester tester) async {
      _wide(tester);
      const ZcrudTheme tokens =
          ZcrudTheme(studyCardHierarchy: ZStudyCardHierarchy.tintedTile);
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(
            title: 'Note', hierarchy: ZStudyCardHierarchy.tintedGlyph),
        tokens: tokens,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.accentKey), findsNothing);
      expect(find.byKey(ZDefaultNoteCard.iconTileKey), findsOneWidget);
    });

    testWidgets('chaque jeton de géométrie est HONORÉ (rayon, padding, marge, '
        'tuile, badge)', (WidgetTester tester) async {
      _wide(tester);
      const ZcrudTheme tokens = ZcrudTheme(
        studyCardRadius: Radius.circular(24),
        studyCardContentPadding: EdgeInsetsDirectional.all(20),
        studyCardMargin: EdgeInsetsDirectional.all(6),
        studyCardIconTileSize: 56,
        studyCardIconTileRadius: Radius.circular(18),
        studyCardBadgeRadius: Radius.circular(2),
      );
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(
            title: 'Doc', formatKey: 'pdf', formatLabel: 'PDF'),
        tokens: tokens,
      ));
      await tester.pumpAndSettle();

      final Card card = tester.widget<Card>(find.byType(Card));
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius,
          const BorderRadius.all(Radius.circular(24)));
      expect(card.margin, const EdgeInsetsDirectional.all(6));
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is Padding && w.padding == const EdgeInsetsDirectional.all(20)),
        findsWidgets,
      );
      expect(tester.getSize(find.byKey(ZDefaultDocumentCard.iconTileKey)),
          const Size(56, 56));
      expect(_decoOf(tester, ZDefaultDocumentCard.iconTileKey).borderRadius,
          const BorderRadius.all(Radius.circular(18)));
      expect(
          _decoOf(tester, ZDefaultDocumentCard.extensionBadgeKey).borderRadius,
          const BorderRadius.all(Radius.circular(2)));
    });

    testWidgets('jetons de MATIÈRE et de STYLE honorés (liseré, titre, '
        'sous-titre) — et le paramètre prime sur le jeton',
        (WidgetTester tester) async {
      _wide(tester);
      const BorderSide side = BorderSide(color: Color(0xFF123456), width: 3);
      const TextStyle title = TextStyle(fontSize: 21);
      const TextStyle subtitle = TextStyle(fontSize: 9);
      const ZcrudTheme tokens = ZcrudTheme(
        studyCardBorderSide: side,
        studyCardTitleStyle: title,
        studyCardSubtitleStyle: subtitle,
      );
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: 'Note', subtitle: 'Hier'),
        tokens: tokens,
      ));
      await tester.pumpAndSettle();
      final Card card = tester.widget<Card>(find.byType(Card));
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 3);
      expect(shape.side.color.toARGB32(), 0xFF123456);
      expect(tester.widget<Text>(find.text('Note')).style?.fontSize, 21);
      expect(tester.widget<Text>(find.text('Hier')).style?.fontSize, 9);

      // Paramètre > jeton.
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(
          title: 'Note',
          subtitle: 'Hier',
          borderSide: BorderSide(color: Color(0xFF654321), width: 5),
          titleStyle: TextStyle(fontSize: 27),
        ),
        tokens: tokens,
      ));
      await tester.pumpAndSettle();
      final RoundedRectangleBorder shape2 =
          tester.widget<Card>(find.byType(Card)).shape!
              as RoundedRectangleBorder;
      expect(shape2.side.width, 5);
      expect(shape2.side.color.toARGB32(), 0xFF654321);
      expect(tester.widget<Text>(find.text('Note')).style?.fontSize, 27);
    });

    testWidgets('leçon CR-LEX-73 : `CardTheme.margin` de l\'hôte reste '
        'ATTEIGNABLE (jeton nul)', (WidgetTester tester) async {
      _wide(tester);
      final ThemeData material = _material().copyWith(
        cardTheme: const CardThemeData(margin: EdgeInsets.all(9)),
      );
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(title: 'Doc'),
        theme: material,
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<Card>(find.byType(Card)).margin,
          const EdgeInsets.all(9),
          reason: 'priorité : paramètre > jeton > CardTheme.margin > '
              'référence (4).');
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 — slot `progress` RELAYÉ (« non mesuré » n°2)', () {
    testWidgets('les trois cartes par défaut rendent `progress`',
        (WidgetTester tester) async {
      _wide(tester);
      const Key spinner = ValueKey<String>('spin');
      final List<Widget> cards = <Widget>[
        const ZDefaultDocumentCard(
            title: 'Doc',
            progress: CircularProgressIndicator(key: spinner)),
        const ZDefaultNoteCard(
            title: 'Note',
            progress: CircularProgressIndicator(key: spinner)),
        ZDefaultMindmapCard(
            map: _mindmap(),
            progress: const CircularProgressIndicator(key: spinner)),
      ];
      for (final Widget card in cards) {
        await tester.pumpWidget(_host(card));
        await tester.pump();
        expect(find.byKey(spinner), findsOneWidget,
            reason: '🔴 ${card.runtimeType} ne relaie pas `progress` — le '
                'repli par item des hôtes reste alors nécessaire (CR-56).');
      }
    });

    testWidgets('éviction du trailing pilotable depuis les cartes par défaut',
        (WidgetTester tester) async {
      _wide(tester);
      const Key action = ValueKey<String>('action');
      await tester.pumpWidget(_host(const ZDefaultNoteCard(
        title: 'Note',
        progress: CircularProgressIndicator(),
        trailing: Icon(Icons.close, key: action),
      )));
      await tester.pump();
      expect(find.byKey(action), findsNothing,
          reason: 'défaut CR-IFFD-21 : éviction pendant le traitement.');

      await tester.pumpWidget(_host(const ZDefaultNoteCard(
        title: 'Note',
        progress: CircularProgressIndicator(),
        trailing: Icon(Icons.close, key: action),
        hidesTrailingWhileBusy: false,
      )));
      await tester.pump();
      expect(find.byKey(action), findsOneWidget);
    });

    testWidgets('voie typée `.mindmaps` : `progressOf` PAR CARTE atteint la '
        'carte rendue', (WidgetTester tester) async {
      _wide(tester);
      final ZStudyToolsSectionSpec spec = ZStudyToolsSectionSpec.mindmaps(
        id: 'mindmaps',
        title: 'Cartes mentales',
        maps: <ZMindmap>[_mindmap()],
        emptyState: const SizedBox.shrink(),
        progressOf: (BuildContext context, ZMindmap map) =>
            CircularProgressIndicator(key: ValueKey<String>('p-${map.id}')),
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 0)),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('p-m1')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 — voie typée `.mindmaps` : relais de réglage', () {
    testWidgets('hiérarchie + glyphe + géométrie relayés à la carte',
        (WidgetTester tester) async {
      _wide(tester);
      final ZStudyToolsSectionSpec spec = ZStudyToolsSectionSpec.mindmaps(
        id: 'mindmaps',
        title: 'Cartes mentales',
        maps: <ZMindmap>[_mindmap()],
        emptyState: const SizedBox.shrink(),
        hierarchy: ZStudyCardHierarchy.tintedGlyph,
        cardIcon: Icons.workspaces_outline,
        cardBorderRadius: const Radius.circular(30),
        cardMargin: const EdgeInsetsDirectional.all(7),
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 0)),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.workspaces_outline), findsOneWidget);
      final Card card = tester.widget<Card>(find.byType(Card));
      expect((card.shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(30)));
      expect(card.margin, const EdgeInsetsDirectional.all(7));
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-56 — `ZStudyToolsItemCard.borderRadius` (capacité de base)',
      () {
    testWidgets('null ⇒ rendu historique (radiusM) ; fourni ⇒ il prime',
        (WidgetTester tester) async {
      _wide(tester);
      await tester
          .pumpWidget(_host(const ZStudyToolsItemCard(title: 'T')));
      await tester.pumpAndSettle();
      RoundedRectangleBorder shape = tester
          .widget<Card>(find.byType(Card))
          .shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(8)),
          reason: 'défaut historique STRICTEMENT préservé (radiusM).');

      await tester.pumpWidget(_host(const ZStudyToolsItemCard(
          title: 'T', borderRadius: Radius.circular(22))));
      await tester.pumpAndSettle();
      shape = tester.widget<Card>(find.byType(Card)).shape!
          as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(22)));
    });
  });
}
