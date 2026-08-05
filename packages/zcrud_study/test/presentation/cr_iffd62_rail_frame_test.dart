/// **CR-IFFD-62** — le rail a une HAUTEUR, la carte REMPLIT son cadre,
/// l'énoncé SIGNALE sa coupure, et les trois réglages du point ④ existent.
///
/// ## Ce que ces gardes MESURENT (jamais une intention déclarée)
///
/// - « la carte remplit le cadre » = **hauteur rendue == hauteur imposée**
///   (`getRect`), jamais la présence d'un `Expanded` dans l'arbre ;
/// - « le pied est en bas » = **distance pied↔bord bas CONSTANTE** quel que
///   soit l'énoncé, le facteur d'échelle et la hauteur du cadre ;
/// - « la neutralité » = **hauteur intrinsèque et position du pied
///   IDENTIQUES** entre le chemin historique (`contentAlignment: null`) et le
///   nouveau, hors cadre — mesuré sur deux rendus réels, jamais sur une
///   constante figée qu'une version du SDK ferait mentir ;
/// - « l'énoncé signale sa coupure » = **PIXELS réellement peints** (capture
///   `RepaintBoundary.toImage`), jamais la présence du widget de fondu ;
/// - « le culling ne régresse pas » = **nombre de cartes construites** sur un
///   rail de 50.
///
/// 🔴 **Le fondu n'est PAS une ellipse, et la garde ne prétend pas le
/// contraire** : `TextOverflow.ellipsis` n'a aucune prise sur le rendu RICHE
/// par défaut (colonne de blocs Quill, pas un `RenderParagraph`). La garde
/// mesure donc ce qui est LIVRÉ — un fondu conditionnel — et, séparément, la
/// vraie ellipse sur le chemin TEXTE NU (`questionBuilder` → `Text`).
@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZStudyCardContentAlignment, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

ZFlashcard _card({String id = 'c1', String question = 'Question ?'}) =>
    ZFlashcard(id: id, question: question, type: ZFlashcardType.openQuestion);

/// Énoncé qui DÉBORDE franchement la borne de référence (36,4 dp).
const String kOverflowing =
    'Un énoncé délibérément très long qui déborde la borne de hauteur de '
    'référence, avec assez de mots pour occuper plusieurs lignes et donc être '
    'coupé quelque part au milieu de la troisième.';

const Key _boundaryKey = ValueKey<String>('cr62-boundary');

Widget _host(
  Widget child, {
  double width = 400,
  TextScaler? scaler,
  ZcrudTheme? theme,
  CardThemeData? cardTheme,
  Brightness brightness = Brightness.light,
}) {
  final Widget body = Align(
    alignment: AlignmentDirectional.topStart,
    child: RepaintBoundary(
      key: _boundaryKey,
      child: SizedBox(width: width, child: child),
    ),
  );
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      cardTheme: cardTheme,
      extensions: theme == null
          ? const <ThemeExtension<dynamic>>[]
          : <ThemeExtension<dynamic>>[theme],
    ),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext c) => scaler == null
            ? body
            : MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: scaler),
                child: body,
              ),
      ),
    ),
  );
}

/// Face RENDUE de la carte (le `Card` Material, marge exclue).
Rect _face(WidgetTester tester) => tester.getRect(find.byType(Card).first);

Rect _pill(WidgetTester tester) =>
    tester.getRect(find.byKey(ZDefaultFlashcardCard.typeChipKey));

Rect _question(WidgetTester tester) =>
    tester.getRect(find.byKey(ZDefaultFlashcardCard.questionKey));

/// Distance du BAS de la pastille de type au BAS de la face de carte.
double _footerGap(WidgetTester tester) => _face(tester).bottom - _pill(tester).bottom;

// ---------------------------------------------------------------------------
// Capture de PIXELS — « l'énoncé signale sa coupure » se mesure à l'écran
// ---------------------------------------------------------------------------

Future<Uint8List> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  expect(data, isNotNull, reason: '🔴 capture de pixels impossible');
  return data!.buffer.asUint8List();
}

/// « Encre » moyenne d'une bande horizontale de l'image : distance moyenne au
/// BLANC (donc à peu près la quantité de glyphe peint), en 0..255.
double _inkOfBand(
  Uint8List rgba,
  int imageWidth,
  int topRow,
  int bottomRow,
) {
  double total = 0;
  int count = 0;
  for (int y = topRow; y < bottomRow; y++) {
    for (int x = 0; x < imageWidth; x++) {
      final int i = (y * imageWidth + x) * 4;
      final int r = rgba[i];
      final int g = rgba[i + 1];
      final int b = rgba[i + 2];
      final int a = rgba[i + 3];
      // Composé sur blanc, puis distance au blanc.
      final double lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) * (a / 255) +
          255 * (1 - a / 255);
      total += 255 - lum;
      count++;
    }
  }
  return count == 0 ? 0 : total / count;
}

void main() {
  // =========================================================================
  group('CR-IFFD-62 ① — `ZRailItem` a une HAUTEUR (patron `railItemWidth`)',
      () {
    testWidgets('sans paramètre NI jeton : AUCUNE contrainte de hauteur '
        '(l\'item garde celle de son contenu)', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        // `Align` : contraintes LÂCHES en largeur, sans quoi le cadre du hôte
        // (tight) masquerait le repli de largeur qu'on veut aussi vérifier.
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: ZRailItem(child: SizedBox(height: 77)),
        ),
        width: 800,
      ));
      expect(tester.getSize(find.byType(ZRailItem)).height, 77,
          reason: '🔴 un repli chiffré de hauteur imposerait une taille à TOUS '
              'les items de rail de TOUS les hôtes — asymétrie assumée avec '
              '`width`, dont l\'absence de borne est une FAUTE de layout.');
      expect(tester.getSize(find.byType(ZRailItem)).width,
          zRailItemFallbackWidth);
    });

    testWidgets('le jeton `ZcrudTheme.railItemHeight` gouverne la hauteur',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZRailItem(child: SizedBox(height: 77)),
        theme: const ZcrudTheme(railItemHeight: 160),
      ));
      expect(tester.getSize(find.byType(ZRailItem)).height, 160);
    });

    testWidgets('le paramètre `height` PRIME sur le jeton',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZRailItem(height: 220, child: SizedBox(height: 77)),
        theme: const ZcrudTheme(railItemHeight: 160),
      ));
      expect(tester.getSize(find.byType(ZRailItem)).height, 220);
    });

    testWidgets('la hauteur posée est TIGHT : la carte la REMPLIT (hauteur '
        'rendue == hauteur imposée)', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZRailItem(
          height: 260,
          // `height: null` sur la carte : SEUL le cadre du rail parle.
          child: ZDefaultFlashcardCard(card: _card(), height: null),
        ),
      ));
      expect(_face(tester).height, 260,
          reason: '🔴 c\'est LA mesure de la CR : un `SizedBox(height:)` '
              'd\'hôte laissait la carte à sa hauteur de contenu.');
    });

    testWidgets('la voie TYPÉE relaie `railItemHeight` jusqu\'à l\'item',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          height: 400,
          child: ZSectionedStudyLayout(
            sections: <ZStudyToolsSectionSpec>[
              ZStudyToolsSectionSpec.flashcards(
                id: 's',
                title: 'F',
                cards: <ZFlashcard>[_card()],
                emptyState: const SizedBox.shrink(),
                axis: Axis.horizontal,
                railItemHeight: 150,
                cardHeight: null,
              ),
            ],
          ),
        ),
        width: 800,
      ));
      expect(tester.getSize(find.byType(ZRailItem).first).height, 150);
      expect(_face(tester).height, 150,
          reason: '🔴 la carte doit CONSOMMER le cadre du rail, pas se poser '
              'dedans.');
    });
  });

  // =========================================================================
  group('CR-IFFD-62 ②/⑤ — la carte est construite en CONTRAINTES DESCENDANTES',
      () {
    testWidgets('hauteur rendue == hauteur IMPOSÉE (3 cadres mesurés)',
        (WidgetTester tester) async {
      for (final double frame in <double>[140, 200, 320]) {
        await tester.pumpWidget(_host(SizedBox(
          height: frame,
          child: ZDefaultFlashcardCard(card: _card(), height: null),
        )));
        expect(_face(tester).height, frame,
            reason: '🔴 cadre $frame dp non consommé');
      }
    });

    testWidgets('le PIED est en bas : distance pied↔bord bas CONSTANTE quel '
        'que soit l\'énoncé', (WidgetTester tester) async {
      final List<double> gaps = <double>[];
      for (final String q in <String>[
        'Court',
        'Un énoncé de longueur moyenne qui tient sur deux lignes environ.',
        kOverflowing,
      ]) {
        await tester.pumpWidget(_host(ZDefaultFlashcardCard(
          card: _card(question: q),
        )));
        gaps.add(_footerGap(tester));
      }
      expect(gaps.toSet().length, 1,
          reason: '🔴 pied DENTELÉ : la pastille remonte contre le texte quand '
              'l\'énoncé raccourcit — mesuré $gaps. C\'est exactement le grief '
              '③ de la CR (« le pied du rail est dentelé »).');
      // …et ce gap vaut le padding interne de carte (le pied touche le bas).
      expect(gaps.first, lessThanOrEqualTo(16));
    });

    testWidgets('les TROIS alignements sont RÉELLEMENT distincts sous cadre',
        (WidgetTester tester) async {
      final Map<ZStudyCardContentAlignment, double> headTop =
          <ZStudyCardContentAlignment, double>{};
      final Map<ZStudyCardContentAlignment, double> pillBottom =
          <ZStudyCardContentAlignment, double>{};
      for (final ZStudyCardContentAlignment a
          in ZStudyCardContentAlignment.values) {
        await tester.pumpWidget(_host(SizedBox(
          height: 300,
          child: ZDefaultFlashcardCard(
            card: _card(),
            height: null,
            contentAlignment: a,
          ),
        )));
        headTop[a] =
            tester.getRect(find.byKey(ZDefaultFlashcardCard.headerRowKey)).top;
        pillBottom[a] = _footerGap(tester);
      }
      // `top` : contenu collé en haut, espace libre SOUS le pied.
      expect(pillBottom[ZStudyCardContentAlignment.top]!,
          greaterThan(pillBottom[ZStudyCardContentAlignment.spread]!),
          reason: '🔴 `top` doit laisser l\'espace libre EN BAS.');
      // `bottom` : contenu collé en bas, espace libre AU-DESSUS.
      expect(headTop[ZStudyCardContentAlignment.bottom]!,
          greaterThan(headTop[ZStudyCardContentAlignment.top]!),
          reason: '🔴 `bottom` doit laisser l\'espace libre EN HAUT.');
      // `spread` (référence) : en-tête EN HAUT **et** pied EN BAS — les deux à
      // la fois, ce qu'aucun des deux autres ne fait.
      expect(headTop[ZStudyCardContentAlignment.spread],
          headTop[ZStudyCardContentAlignment.top]);
      expect(pillBottom[ZStudyCardContentAlignment.spread],
          pillBottom[ZStudyCardContentAlignment.bottom]);
    });

    testWidgets('le JETON `studyCardContentAlignment` gouverne, le paramètre '
        'PRIME', (WidgetTester tester) async {
      Future<double> gap(ZStudyCardContentAlignment? param) async {
        await tester.pumpWidget(_host(
          SizedBox(
            height: 300,
            child: ZDefaultFlashcardCard(
              card: _card(),
              height: null,
              contentAlignment: param,
            ),
          ),
          theme: const ZcrudTheme(
            studyCardContentAlignment: ZStudyCardContentAlignment.top,
          ),
        ));
        return _footerGap(tester);
      }

      final double byToken = await gap(null);
      final double byParam = await gap(ZStudyCardContentAlignment.spread);
      expect(byToken, greaterThan(byParam),
          reason: '🔴 chaîne de résolution rompue : paramètre > jeton > '
              'référence (`spread`).');
    });

    testWidgets('🔴 NEUTRALITÉ SANS CADRE : hauteur intrinsèque et position du '
        'pied IDENTIQUES au chemin historique', (WidgetTester tester) async {
      // Chemin HISTORIQUE : la primitive de base, `contentAlignment: null`.
      const String q = 'Neutralité';
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: q),
        height: null,
      )));
      final double refHeight = _face(tester).height;
      final double refGap = _footerGap(tester);
      final Rect refHead =
          tester.getRect(find.byKey(ZDefaultFlashcardCard.headerRowKey));

      // Les TROIS alignements, sans cadre : rendu STRICTEMENT identique — il
      // n'y a aucun espace libre à répartir.
      for (final ZStudyCardContentAlignment a
          in ZStudyCardContentAlignment.values) {
        await tester.pumpWidget(_host(ZDefaultFlashcardCard(
          card: _card(question: q),
          height: null,
          contentAlignment: a,
        )));
        expect(_face(tester).height, refHeight,
            reason: '🔴 NEUTRALITÉ ROMPUE ($a) : la hauteur intrinsèque a '
                'changé hors cadre.');
        expect(_footerGap(tester), refGap);
        expect(
            tester.getRect(find.byKey(ZDefaultFlashcardCard.headerRowKey)),
            refHead);
      }
    });

    testWidgets('🔴 parent NON BORNÉ : aucune exception (le piège de '
        'l\'`Expanded` inconditionnel)', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          height: 300,
          child: ListView(
            children: <Widget>[
              // Hauteur NON BORNÉE : un `Expanded` posé sans mesurer les
              // contraintes lèverait ici (« non-zero flex but incoming height
              // constraints are unbounded »).
              ZDefaultFlashcardCard(card: _card(), height: null),
              ZDefaultFlashcardCard(
                card: _card(id: 'c2'),
                height: null,
                contentAlignment: ZStudyCardContentAlignment.spread,
              ),
            ],
          ),
        ),
      ));
      expect(tester.takeException(), isNull,
          reason: '🔴 la bascule DOIT être mesurée sur les contraintes reçues, '
              'jamais déduite du paramètre.');
    });

    testWidgets('la primitive de base reste NEUTRE : `contentAlignment: null` '
        '⇒ aucun `LayoutBuilder` introduit', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        height: 200,
        child: ZStudyToolsItemCard(title: 'T', subtitle: 'S'),
      )));
      expect(
        find.descendant(
          of: find.byType(ZStudyToolsItemCard),
          matching: find.byType(LayoutBuilder),
        ),
        findsNothing,
        reason: '🔴 la primitive de base ne doit RIEN payer pour une capacité '
            'qu\'elle n\'utilise pas (neutralité d\'arbre, patron CR-IFFD-19).',
      );
      // …et le rendu reste le HISTORIQUE : contenu CENTRÉ dans le cadre (la
      // `Row` centre une colonne `MainAxisSize.min`), pas collé en haut.
      final Rect card = tester.getRect(find.byType(Card).first);
      final Rect title = tester.getRect(find.text('T'));
      final Rect subtitle = tester.getRect(find.text('S'));
      expect((title.top - card.top) - (card.bottom - subtitle.bottom),
          closeTo(0, 0.01),
          reason: '🔴 NEUTRALITÉ ROMPUE : la primitive de base cesserait de '
              'centrer son contenu sous cadre — un hôte qui la compose '
              'lui-même (lex_douane) verrait son rendu bouger SANS l\'avoir '
              'demandé (classe d\'erreur des handoffs v0.16/19.1/22).');
    });
  });

  // =========================================================================
  group('CR-IFFD-62 ③ — l\'énoncé SIGNALE sa coupure (mesuré en PIXELS)', () {
    testWidgets('énoncé qui DÉBORDE : le fondu efface réellement le bas de la '
        'boîte (comparé au même rendu SANS fondu)',
        (WidgetTester tester) async {
      // Rendu SANS fondu (`fadeExtent: 0` = rendu v0.47.0 exact).
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: kOverflowing),
        questionFadeExtent: 0,
      )));
      await tester.pumpAndSettle();
      final Rect box = _question(tester);
      final Uint8List plain = await _capture(tester);

      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: kOverflowing),
      )));
      await tester.pumpAndSettle();
      expect(_question(tester), box,
          reason: '🔴 le fondu ne doit RIEN changer au layout.');

      final Uint8List faded = await _capture(tester);
      // `toImage()` rend en pixels LOGIQUES (pixelRatio 1.0) : les rects de
      // `getRect` sont donc directement des coordonnées d'image, à l'origine
      // du RepaintBoundary près.
      final Rect boundary = tester.getRect(find.byKey(_boundaryKey));
      final int imageWidth = boundary.width.round();
      // Bande = les 4 dernières dp de la boîte d'énoncé.
      final int bottom = (box.bottom - boundary.top).round();
      final int top = bottom - 4;
      final double inkPlain = _inkOfBand(plain, imageWidth, top, bottom);
      final double inkFaded = _inkOfBand(faded, imageWidth, top, bottom);

      expect(inkPlain, greaterThan(0.5),
          reason: '🔴 sonde INERTE : sans encre dans la bande, la comparaison '
              'ne prouverait rien (encre mesurée : $inkPlain).');
      expect(inkFaded, lessThan(inkPlain * 0.75),
          reason: '🔴 le contenu tronqué doit SIGNALER qu\'il continue : encre '
              'de la dernière bande $inkFaded contre $inkPlain sans fondu. '
              '« Absorber n\'est pas signaler » (CR-IFFD-62 ③).');
    });

    testWidgets('énoncé qui TIENT : AUCUN fondu (pixels strictement identiques '
        'au rendu sans fondu)', (WidgetTester tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Court'),
        questionFadeExtent: 0,
      )));
      await tester.pumpAndSettle();
      final Uint8List plain = await _capture(tester);

      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Court'),
      )));
      await tester.pumpAndSettle();
      final Uint8List faded = await _capture(tester);

      expect(faded, plain,
          reason: '🔴 un fondu peint sur un contenu qui TIENT mentirait sur la '
              'complétude de l\'énoncé — pire que pas de signal du tout.');
    });

    testWidgets('la BORNE de hauteur tient toujours (le fondu ne l\'a pas '
        'relâchée)', (WidgetTester tester) async {
      for (final double maxHeight in <double>[
        ZFlashcardCardReference.questionMaxHeight,
        60,
      ]) {
        await tester.pumpWidget(_host(ZDefaultFlashcardCard(
          card: _card(question: kOverflowing),
          questionMaxHeight: maxHeight,
        )));
        await tester.pumpAndSettle();
        expect(_question(tester).height, lessThanOrEqualTo(maxHeight + 0.01));
      }
    });

    testWidgets('chemin TEXTE NU : la VRAIE ellipse est atteignable, et le '
        'fondu ne s\'y superpose PAS', (WidgetTester tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: kOverflowing),
        questionBuilder: (BuildContext c, String s) => Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      )));
      await tester.pumpAndSettle();
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(ZDefaultFlashcardCard.questionKey),
          matching: find.byType(RichText),
        ),
      );
      // MESURE de layout (calculée par le paragraphe), pas une propriété
      // déclarée : le texte a réellement dépassé ses 2 lignes, donc l'ellipse
      // est réellement peinte.
      expect(paragraph.didExceedMaxLines, isTrue,
          reason: '🔴 sonde INERTE : sans dépassement, l\'ellipse ne serait '
              'pas peinte et la garde ne prouverait rien.');
      // …et l'ellipse est bien DANS le texte peint (glyphe U+2026), pas une
      // simple propriété déclarée.
      expect(paragraph.text.toPlainText(), isNot(contains('\u2026')),
          reason: 'la SOURCE ne contient pas d\'ellipse — celle qui s\'affiche '
              'est donc bien celle du moteur de texte, pas une chaîne '
              'fabriquée.');
      // …et le `Text` ellipsé ne déborde PAS sa boîte : aucun fondu.
      final ZRenderFadedOverflow render =
          tester.renderObject<ZRenderFadedOverflow>(
        find.descendant(
          of: find.byKey(ZDefaultFlashcardCard.questionKey),
          matching: find.byType(ZFadedOverflow),
        ),
      );
      expect(render.isTruncated, isFalse,
          reason: '🔴 fondu ET ellipse ensemble : le signal serait redondant '
              'et le texte deux fois amputé.');
    });
  });

  // =========================================================================
  group('CR-IFFD-62 ④ — espacement et retrait latéral du rail', () {
    Widget layout({
      required ZStudyToolsSectionSpec spec,
      ZcrudTheme? theme,
    }) =>
        _host(
          SizedBox(
            height: 400,
            child: ZSectionedStudyLayout(
              sections: <ZStudyToolsSectionSpec>[spec],
            ),
          ),
          width: 900,
          theme: theme,
        );

    // ⚠️ `railItemGap` n'est PAS passé quand il n'est pas demandé : sur les
    // voies typées, OMETTRE le paramètre donne la référence (12), tandis
    // qu'un `null` EXPLICITE défère au jeton puis à `gapS` (sémantique AD-4).
    ZStudyToolsSectionSpec typed({
      double? railItemGap,
      EdgeInsetsGeometry? railPadding,
      bool passGap = false,
    }) =>
        passGap
            ? ZStudyToolsSectionSpec.flashcards(
                id: 's',
                title: 'Flashcards',
                cards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b')],
                emptyState: const SizedBox.shrink(),
                axis: Axis.horizontal,
                railItemGap: railItemGap,
                railPadding: railPadding,
              )
            : ZStudyToolsSectionSpec.flashcards(
                id: 's',
                title: 'Flashcards',
                cards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b')],
                emptyState: const SizedBox.shrink(),
                axis: Axis.horizontal,
                railPadding: railPadding,
              );

    ZStudyToolsSectionSpec host({
      double? railItemGap,
      EdgeInsetsGeometry? railPadding,
    }) =>
        ZStudyToolsSectionSpec(
          id: 's',
          title: 'Flashcards',
          itemCount: 2,
          itemBuilder: (BuildContext c, int i) => SizedBox(
            key: ValueKey<String>('host-item-$i'),
            width: 100,
            height: 80,
          ),
          emptyState: const SizedBox.shrink(),
          axis: Axis.horizontal,
          railItemGap: railItemGap,
          railPadding: railPadding,
        );

    double gapBetweenItems(WidgetTester tester, Type itemType) {
      final List<Element> items =
          find.byType(itemType, skipOffstage: false).evaluate().toList();
      final Rect a = tester.getRect(find.byWidget(items[0].widget));
      final Rect b = tester.getRect(find.byWidget(items[1].widget));
      return b.left - a.right;
    }

    testWidgets('voie TYPÉE : le défaut EST la référence (12), sans réglage',
        (WidgetTester tester) async {
      await tester.pumpWidget(layout(spec: typed()));
      expect(gapBetweenItems(tester, ZRailItem), kZRailItemReferenceGap);
      expect(kZRailItemReferenceGap, 12);
    });

    testWidgets('voie TYPÉE : un `railItemGap: null` EXPLICITE défère au thème '
        '(AD-4) — l\'omission, elle, donne la référence',
        (WidgetTester tester) async {
      await tester.pumpWidget(layout(
        spec: typed(passGap: true),
        theme: const ZcrudTheme(railItemGap: 20),
      ));
      expect(gapBetweenItems(tester, ZRailItem), 20);
    });

    testWidgets('constructeur PRINCIPAL : `gapS` — rendu HISTORIQUE inchangé '
        '(un hôte qui compose son rail ne bouge pas)',
        (WidgetTester tester) async {
      await tester.pumpWidget(layout(spec: host()));
      // Les items d'un itemBuilder d'hôte ne sont PAS enveloppés (neutralité
      // CR-49) : on mesure les `SizedBox` eux-mêmes via leurs rects.
      final Rect a = tester.getRect(find.byKey(const ValueKey<String>('host-item-0')));
      final Rect b = tester.getRect(find.byKey(const ValueKey<String>('host-item-1')));
      expect(b.left - a.right, const ZcrudTheme().gapS);
    });

    testWidgets('le jeton `railItemGap` gouverne le constructeur principal, '
        'le paramètre PRIME', (WidgetTester tester) async {
      await tester.pumpWidget(layout(
        spec: host(),
        theme: const ZcrudTheme(railItemGap: 20),
      ));
      Rect r(int i) =>
          tester.getRect(find.byKey(ValueKey<String>('host-item-$i')));
      expect(r(1).left - r(0).right, 20);

      await tester.pumpWidget(layout(
        spec: host(railItemGap: 6),
        theme: const ZcrudTheme(railItemGap: 20),
      ));
      expect(r(1).left - r(0).right, 6);
    });

    testWidgets('🔴 origine des « 45 px » : le retrait de la première CARTE '
        'CUMULE le padding de section ET la marge de carte',
        (WidgetTester tester) async {
      // Reproduction du thème IFFD : `gapM: 12` (leur padding de carte) et une
      // marge de carte de 4 (`CardThemeData.margin`, chaîne CR-LEX-73).
      await tester.pumpWidget(_host(
        SizedBox(
          height: 400,
          child: ZSectionedStudyLayout(
            sections: <ZStudyToolsSectionSpec>[typed()],
          ),
        ),
        width: 900,
        theme: const ZcrudTheme(gapM: 12),
        cardTheme: const CardThemeData(margin: EdgeInsets.all(4)),
      ));
      final double layoutLeft =
          tester.getRect(find.byType(ZSectionedStudyLayout)).left;
      final double railLeft =
          tester.getRect(find.byType(ZRailItem).first).left;
      final double faceLeft = _face(tester).left;
      expect(railLeft - layoutLeft, 12,
          reason: '🔴 le retrait du RAIL est le padding de section (`gapM`).');
      expect(faceLeft - layoutLeft, 16,
          reason: '🔴 le retrait de la première CARTE ajoute la marge de carte '
              '(12 + 4 = 16 dp) — c\'est le cumul mesuré « 45 px » de la CR '
              '(45 px ÷ 2,75 de densité ≈ 16 dp ; 20 px ≈ 8 dp côté legacy).');
    });

    testWidgets('`railPadding` rend le retrait du rail ABSOLU (le padding de '
        'section ne s\'y AJOUTE plus) — et l\'EN-TÊTE le garde',
        (WidgetTester tester) async {
      await tester.pumpWidget(layout(
        spec: typed(
          railPadding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        ),
        theme: const ZcrudTheme(gapM: 12),
      ));
      final double layoutLeft =
          tester.getRect(find.byType(ZSectionedStudyLayout)).left;
      expect(tester.getRect(find.byType(ZRailItem).first).left - layoutLeft, 8,
          reason: '🔴 8 dp DEMANDÉS ⇒ 8 dp RENDUS. Si le padding de section '
              's\'ajoutait, le retrait demandé serait INATTEIGNABLE (20 au '
              'lieu de 8) — le défaut exact que la CR décrit.');
      expect(tester.getRect(find.text('Flashcards')).left - layoutLeft, 12,
          reason: '🔴 l\'en-tête garde le retrait de SECTION : c\'est ce qui '
              'interdit d\'imposer 8 par défaut (titre et cartes seraient '
              'désalignés).');
    });

    testWidgets('le jeton `railPadding` gouverne, le paramètre PRIME',
        (WidgetTester tester) async {
      await tester.pumpWidget(layout(
        spec: typed(),
        theme: const ZcrudTheme(
          railPadding: EdgeInsetsDirectional.symmetric(horizontal: 30),
        ),
      ));
      double railLeft() =>
          tester.getRect(find.byType(ZRailItem).first).left -
          tester.getRect(find.byType(ZSectionedStudyLayout)).left;
      expect(railLeft(), 30);

      await tester.pumpWidget(layout(
        spec: typed(railPadding: EdgeInsets.zero),
        theme: const ZcrudTheme(
          railPadding: EdgeInsetsDirectional.symmetric(horizontal: 30),
        ),
      ));
      expect(railLeft(), 0);
    });

    testWidgets('`railPadding` est DIRECTIONNEL (AD-13) : en RTL le retrait '
        'de début passe à droite', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 900,
              child: ZSectionedStudyLayout(
                sections: <ZStudyToolsSectionSpec>[
                  typed(
                    railPadding:
                        const EdgeInsetsDirectional.only(start: 40, end: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      final Rect layoutRect = tester.getRect(find.byType(ZSectionedStudyLayout));
      final Rect first = tester.getRect(find.byType(ZRailItem).first);
      expect(layoutRect.right - first.right, 40,
          reason: '🔴 `start: 40` doit se rendre à DROITE en RTL.');
    });
  });

  // =========================================================================
  group('CR-IFFD-62 ⑤ (« non mesuré » de la CR) — facteur d\'échelle de texte',
      () {
    for (final double scale in <double>[1.0, 1.5, 2.0]) {
      testWidgets('textScaler $scale dans le cadre de référence (200) : ni '
          'exception, ni rognage, pied TOUJOURS en bas',
          (WidgetTester tester) async {
        await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(card: _card(question: kOverflowing)),
          scaler: TextScaler.linear(scale),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_face(tester).height, 200);
        // L'énoncé reste borné (il ABSORBE l'échelle au lieu de pousser).
        expect(_question(tester).height,
            lessThanOrEqualTo(ZFlashcardCardReference.questionMaxHeight + 0.01));
        // Le pied reste collé au bas — la même distance qu'à l'échelle 1.
        expect(_footerGap(tester), lessThanOrEqualTo(16));
        // La pastille reste DANS la carte (aucun rognage).
        expect(_pill(tester).bottom, lessThanOrEqualTo(_face(tester).bottom));
      });
    }

    testWidgets('🔴 SEUIL mesuré : à l\'échelle 2.0, le contenu de la carte '
        'demande ~130 dp — le cadre de référence (200) garde donc ~70 dp de '
        'marge avant illisibilité',
        (WidgetTester tester) async {
      // On MESURE la hauteur intrinsèque à l'échelle 2.0 : c'est le plancher
      // en dessous duquel un cadre force un débordement de la colonne.
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(question: kOverflowing), height: null),
        scaler: const TextScaler.linear(2),
      ));
      await tester.pumpAndSettle();
      final double intrinsic = _face(tester).height;
      expect(intrinsic, inInclusiveRange(100, 200),
          reason: '🔴 si le contenu à l\'échelle 2 dépassait déjà le cadre de '
              'référence, la carte de référence serait inutilisable en a11y.');
      // Au plancher exact : aucun débordement.
      await tester.pumpWidget(_host(
        SizedBox(
          height: intrinsic,
          child: ZDefaultFlashcardCard(
            card: _card(question: kOverflowing),
            height: null,
          ),
        ),
        scaler: const TextScaler.linear(2),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: '🔴 cadre == hauteur intrinsèque : doit tenir exactement.');
      // ignore: avoid_print
      print('CR-IFFD-62 — plancher mesuré à textScaler 2.0 : '
          '${intrinsic.toStringAsFixed(1)} dp '
          '(cadre de référence : 200 dp).');
    });
  });

  // =========================================================================
  group('CR-IFFD-62 — non-régression SM-1 : le CULLING du rail tient', () {
    testWidgets('rail de 50 cartes : ≪ 50 construites, malgré le cadre et le '
        'fondu', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 50,
            itemBuilder: (BuildContext context, int i) => ZRailItem(
              height: 200,
              child: ZDefaultFlashcardCard(
                card: _card(id: 'c$i', question: '$kOverflowing $i'),
                height: null,
              ),
            ),
          ),
        ),
        width: 800,
      ));
      await tester.pumpAndSettle();
      final int built = find
          .byType(ZDefaultFlashcardCard, skipOffstage: false)
          .evaluate()
          .length;
      expect(built, lessThan(15),
          reason: '🔴 CULLING RÉGRESSÉ : $built cartes construites sur 50. Ni '
              'le cadre (`ZRailItem.height`), ni le `LayoutBuilder` de la '
              'cascade, ni le fondu ne doivent forcer la construction hors '
              'viewport.');
      // ignore: avoid_print
      print('CR-IFFD-62 — culling re-mesuré : $built cartes construites / 50.');
      await tester.drag(find.byType(ListView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          find
              .byType(ZDefaultFlashcardCard, skipOffstage: false)
              .evaluate()
              .length,
          lessThan(15),
          reason: '🔴 le culling tient AUSSI en défilement (recyclage).');
    });
  });
}
