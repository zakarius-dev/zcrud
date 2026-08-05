/// **CR-IFFD-61 ①/②** — l'écart tuile→titre des cartes par défaut, et
/// l'élévation qui portait une ombre absente de la référence.
///
/// 🔴 **Les angles morts que ces gardes visent** (« une garde hérite de
/// l'angle mort de son auteur ») :
///
/// * l'écart se mesure en **DISTANCE RÉELLE** entre le bord de la tuile et le
///   bord du texte (`getRect`), jamais en constante lue ni en propriété d'un
///   `SizedBox` — une garde qui lirait `ZStudyCardReference.leadingGap`
///   resterait verte si la primitive continuait de rendre `gapM` ;
/// * l'écart est mesuré **sous un thème qui règle `gapM` à une AUTRE valeur** :
///   c'est le seul montage qui prouve que l'écart ne ride plus `gapM` (sous un
///   thème nu, `gapM` vaut 8 et la garde passerait pour de mauvaises raisons) ;
/// * la **neutralité de la primitive de BASE** est mesurée par un hôte qui
///   l'utilise DIRECTEMENT : elle doit rendre `gapM`, PAS 16 ;
/// * l'absence d'accent est mesurée par **absence de clé dans l'arbre** ET par
///   la **couleur réellement peinte** en tête de carte ;
/// * l'ombre est mesurée par les **pixels peints hors de la face de la carte**
///   (une bande de 1 dp dans la marge), pas par la propriété `elevation` seule
///   — et un contre-témoin force l'élévation à 1 pour prouver que la sonde
///   VOIT bien l'ombre quand elle est là.
@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZStudyCardHierarchy, ZcrudTheme;
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

const Color _seed = Color(0xFF3F51B5);
const Key _boundary = ValueKey<String>('cr61:boundary');

/// Le thème d'IFFD, tel qu'il est réellement posé (`gapM: 12` scopé pour le
/// padding de carte) — c'est le montage qui rend la garde MORDANTE : sous un
/// thème nu, `gapM` vaut 8 et « 16 ≠ gapM » passerait sans rien prouver.
const ZcrudTheme kIffdLike = ZcrudTheme(gapM: 12);

const String kTitle = 'Note A';

ThemeData _material({ZcrudTheme? tokens, CardThemeData? cardTheme}) {
  final ThemeData base = ThemeData(colorSchemeSeed: _seed);
  return base.copyWith(
    extensions: tokens == null
        ? const <ThemeExtension<dynamic>>[]
        : <ThemeExtension<dynamic>>[tokens],
    cardTheme: cardTheme,
  );
}

Widget _host(
  Widget child, {
  ZcrudTheme? tokens,
  CardThemeData? cardTheme,
  TextDirection dir = TextDirection.ltr,
  double width = 420,
  double? height,
}) =>
    MaterialApp(
      theme: _material(tokens: tokens, cardTheme: cardTheme),
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: RepaintBoundary(
              key: _boundary,
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      ),
    );

ZMindmap _mindmap() => ZMindmap(
      id: 'm1',
      folderId: 'f1',
      title: 'Plan',
      nodes: <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'r')],
    );

/// ÉCART RÉEL tuile→texte, dans le sens de lecture (AD-13).
double _gap(WidgetTester tester, Key tile, String title, TextDirection dir) {
  final Rect t = tester.getRect(find.byKey(tile));
  final Rect x = tester.getRect(find.text(title));
  return dir == TextDirection.ltr ? x.left - t.right : t.left - x.right;
}

/// L'élévation RÉELLEMENT portée par le `Card` rendu.
double? _elevation(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card).first).elevation;

/// Pixel `[r,g,b,a]` dans la boîte de rendu (coordonnées locales, dp = px car
/// `devicePixelRatio` est forcé à 1).
Future<List<int>> _pixel(WidgetTester tester, double dx, double dy) async {
  final RenderRepaintBoundary box =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  final List<int> out = <int>[];
  await tester.runAsync(() async {
    final ui.Image img = await box.toImage();
    final ByteData? data =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final int i = ((dy.round() * img.width) + dx.round()) * 4;
    out.addAll(<int>[
      data!.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
      data.getUint8(i + 3),
    ]);
  });
  return out;
}

void _pixelPerfect(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ────────────────────────────────────────────────── ① écart tuile → titre ─
  group('CR-IFFD-61 ① — écart tuile→titre : 16 de RÉFÉRENCE, plus `gapM`', () {
    testWidgets(
        '🔴 carte de NOTE par défaut sous `gapM: 12` ⇒ écart MESURÉ = 16 '
        '(l\'écart ne ride plus `gapM`)', (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, ZDefaultNoteCard.iconTileKey, kTitle, TextDirection.ltr),
        16,
        reason: '🔴 l\'écart suit encore `gapM` (12) au lieu de la référence',
      );
    });

    testWidgets('🔴 carte de DOCUMENT et carte MENTALE : même écart de 16',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(title: 'Doc'),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, ZDefaultDocumentCard.iconTileKey, 'Doc',
            TextDirection.ltr),
        16,
      );

      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(map: _mindmap()),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, ZDefaultMindmapCard.vignetteKey, 'Plan',
            TextDirection.ltr),
        16,
      );
    });

    testWidgets('sous un thème NU, l\'écart vaut aussi 16 — et `gapM` (8) '
        'n\'y est plus pour rien', (tester) async {
      await tester.pumpWidget(_host(const ZDefaultNoteCard(title: kTitle)));
      final BuildContext ctx = tester.element(find.text(kTitle));
      // Contrôle de MORDANT : la valeur attendue est bien DIFFÉRENTE de `gapM`.
      expect(ZcrudTheme.of(ctx).gapM, isNot(16));
      expect(
        _gap(tester, ZDefaultNoteCard.iconTileKey, kTitle, TextDirection.ltr),
        16,
      );
    });

    testWidgets('🔴 RTL — l\'écart est le MÊME, mesuré de l\'autre côté '
        '(AD-13)', (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        tokens: kIffdLike,
        dir: TextDirection.rtl,
      ));
      final Rect tile = tester.getRect(find.byKey(ZDefaultNoteCard.iconTileKey));
      final Rect text = tester.getRect(find.text(kTitle));
      // La tuile est bien du côté FIN en RTL : c'est ce qui prouve que la
      // mesure porte sur la variante directionnelle et non sur un hasard.
      expect(tile.left, greaterThan(text.right));
      expect(
        _gap(tester, ZDefaultNoteCard.iconTileKey, kTitle, TextDirection.rtl),
        16,
      );
    });

    testWidgets('le jeton `studyCardLeadingGap` PRIME sur la référence',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        tokens: const ZcrudTheme(gapM: 12, studyCardLeadingGap: 30),
      ));
      expect(
        _gap(tester, ZDefaultNoteCard.iconTileKey, kTitle, TextDirection.ltr),
        30,
      );
    });

    testWidgets(
        '🔴 NEUTRALITÉ de la primitive de BASE — un hôte qui l\'utilise '
        'DIRECTEMENT garde `gapM`, jamais 16', (tester) async {
      // Le montage EST l'hôte de la base : aucune carte par défaut ici.
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: kTitle,
          leading: SizedBox(
            key: ValueKey<String>('host:tile'),
            width: 48,
            height: 48,
          ),
        ),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, const ValueKey<String>('host:tile'), kTitle,
            TextDirection.ltr),
        12,
        reason: '🔴 la base a adopté la référence 16 : RUPTURE pour tout hôte '
            'qui la compose lui-même (lex_douane, cartes de flashcard)',
      );

      // …et la façade `ZStudyNoteCard` est le MÊME chemin (passe-plat).
      await tester.pumpWidget(_host(
        const ZStudyNoteCard(
          title: kTitle,
          leading: SizedBox(
            key: ValueKey<String>('host:tile'),
            width: 48,
            height: 48,
          ),
        ),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, const ValueKey<String>('host:tile'), kTitle,
            TextDirection.ltr),
        12,
      );
    });

    testWidgets('🔴 le jeton `studyCardLeadingGap` NE fuit PAS sur la base — '
        'seules les cartes par défaut le consomment', (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: kTitle,
          leading: SizedBox(
            key: ValueKey<String>('host:tile'),
            width: 48,
            height: 48,
          ),
        ),
        tokens: const ZcrudTheme(gapM: 12, studyCardLeadingGap: 30),
      ));
      expect(
        _gap(tester, const ValueKey<String>('host:tile'), kTitle,
            TextDirection.ltr),
        12,
        reason: 'la base lirait un jeton de CARTE PAR DÉFAUT : la frontière '
            'entre les deux chemins serait perdue',
      );
    });

    testWidgets('le slot `leadingGap` de la base PRIME sur `gapM`',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: kTitle,
          leadingGap: 24,
          leading: SizedBox(
            key: ValueKey<String>('host:tile'),
            width: 48,
            height: 48,
          ),
        ),
        tokens: kIffdLike,
      ));
      expect(
        _gap(tester, const ValueKey<String>('host:tile'), kTitle,
            TextDirection.ltr),
        24,
      );
    });
  });

  // ──────────────────────────────────── ② accent inexistant + ombre en trop ─
  group('CR-IFFD-61 ② — l\'accent n\'existe PAS au défaut (CR INFIRMÉE)', () {
    testWidgets('🔴 défaut ⇒ AUCUNE barre d\'accent dans l\'arbre ; '
        '`tintedTile` ⇒ elle est là', (tester) async {
      await tester.pumpWidget(_host(const ZDefaultNoteCard(title: kTitle)));
      expect(
        find.byKey(ZDefaultNoteCard.accentKey),
        findsNothing,
        reason: 'la CR affirmait un accent « toujours posé » au défaut : '
            'mesuré ABSENT (le chemin `_buildTintedTile` seul le pose)',
      );

      await tester.pumpWidget(_host(const ZDefaultNoteCard(
        title: kTitle,
        hierarchy: ZStudyCardHierarchy.tintedTile,
      )));
      expect(
        find.byKey(ZDefaultNoteCard.accentKey),
        findsOneWidget,
        reason: '🔴 contre-témoin : la sonde VOIT l\'accent quand il est là — '
            'son absence au défaut n\'est donc pas une cécité de la garde',
      );
    });

    testWidgets('🔴 la couleur PEINTE en tête de carte au défaut est celle du '
        'FOND de carte — aucune teinte d\'accent', (tester) async {
      _pixelPerfect(tester);
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        width: 300,
        height: 90,
      ));
      await tester.pumpAndSettle();
      final BuildContext ctx = tester.element(find.text(kTitle));
      final Color face = Theme.of(ctx).colorScheme.surfaceContainerLow;
      // Marge de référence = 4 ⇒ la face commence à y = 4 (liseré), la matière
      // à y = 5. On lit PLUSIEURS rangées : un accent de 4 dp en couvrirait
      // au moins une.
      for (final double y in <double>[5, 6, 7, 8]) {
        final List<int> px = await _pixel(tester, 150, y);
        expect(
          <int>[px[0], px[1], px[2]],
          <int>[
            (face.r * 255).round(),
            (face.g * 255).round(),
            (face.b * 255).round(),
          ],
          reason: '🔴 y=$y : la tête de carte n\'est pas le fond de carte nu',
        );
      }
    });

    testWidgets('🔴 défaut ⇒ élévation 0 (référence) et AUCUNE ombre peinte '
        'hors de la face', (tester) async {
      _pixelPerfect(tester);
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        width: 300,
        height: 90,
      ));
      await tester.pumpAndSettle();
      expect(_elevation(tester), 0, reason: 'la référence pose elevation: 0');
      // La bande de 1 dp juste au-dessus de la face (marge de 4) : une ombre
      // Material y peint du noir. La référence n'a pas d'ombre ⇒ transparent.
      final List<int> band = await _pixel(tester, 150, 3);
      expect(
        band[3],
        0,
        reason: '🔴 une ombre est peinte dans la marge : c\'est elle qui '
            'assombrit les pixels autour de la tête de carte (mesuré : '
            'noir OPAQUE avant correctif), et non un accent',
      );
    });

    testWidgets(
        '🔴 CONTRE-TÉMOIN — élévation 1 ⇒ la sonde VOIT l\'ombre (la garde '
        'ci-dessus n\'est pas aveugle)', (tester) async {
      _pixelPerfect(tester);
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        tokens: const ZcrudTheme(studyCardElevation: 1),
        width: 300,
        height: 90,
      ));
      await tester.pumpAndSettle();
      expect(_elevation(tester), 1);
      final List<int> band = await _pixel(tester, 150, 3);
      expect(
        band[3],
        greaterThan(0),
        reason: 'sans ombre visible ici, la garde d\'absence ne prouverait '
            'rien — c\'était l\'état AVANT correctif',
      );
    });

    testWidgets('les trois cartes par défaut portent l\'élévation 0',
        (tester) async {
      await tester.pumpWidget(_host(const ZDefaultDocumentCard(title: 'Doc')));
      expect(_elevation(tester), 0);
      await tester.pumpWidget(_host(ZDefaultMindmapCard(map: _mindmap())));
      expect(_elevation(tester), 0);
    });

    testWidgets('le jeton `studyCardElevation` PRIME sur la référence',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: kTitle),
        tokens: const ZcrudTheme(studyCardElevation: 3),
      ));
      expect(_elevation(tester), 3);
    });

    testWidgets(
        '🔴 NEUTRALITÉ — la primitive de BASE garde l\'élévation du '
        '`CardTheme` de l\'hôte (aucune valeur imposée)', (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: kTitle),
      ));
      expect(
        _elevation(tester),
        isNull,
        reason: '🔴 la base impose une élévation : tout hôte perd la sienne',
      );
    });

    testWidgets('🔴 NEUTRALITÉ (suite) — l\'élévation du `CardTheme` de l\'hôte '
        'reste ATTEIGNABLE depuis la base, et elle est PEINTE', (tester) async {
      _pixelPerfect(tester);
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: kTitle, margin: EdgeInsets.all(4)),
        cardTheme: const CardThemeData(elevation: 6),
        width: 300,
        height: 90,
      ));
      await tester.pumpAndSettle();
      final BuildContext ctx = tester.element(find.text(kTitle));
      expect(CardTheme.of(ctx).elevation, 6);
      expect(
        _elevation(tester),
        isNull,
        reason: 'la base ne doit RIEN imposer : c\'est ce `null` qui laisse '
            'l\'élévation du `CardTheme` s\'appliquer',
      );
      // …et elle est réellement PEINTE (une propriété atteignable qui ne se
      // rendrait pas serait une neutralité de façade).
      final List<int> band = await _pixel(tester, 150, 2);
      expect(band[3], greaterThan(0));
    });

    testWidgets(
        '🔴 `tintedTile` est une RESTITUTION v0.43.0 : ni écart 16 ni '
        'élévation 0 n\'y sont injectés', (tester) async {
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(
          title: kTitle,
          hierarchy: ZStudyCardHierarchy.tintedTile,
        ),
        tokens: kIffdLike,
      ));
      expect(
        _elevation(tester),
        isNull,
        reason: 'le chemin v0.43.0 doit rester LITTÉRAL (garde de restitution)',
      );
    });

    testWidgets(
        '🔴 une ombre de jetons `cardShadow*` PRIME toujours : élévation '
        'native forcée à 0 (pas DEUX ombres)', (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: kTitle, elevation: 8),
        tokens: const ZcrudTheme(cardShadowBlurRadius: 6, cardShadowAlpha: 0.2),
      ));
      expect(
        _elevation(tester),
        0,
        reason: '🔴 le slot a court-circuité l\'invariant CR-IFFD-27/57 : la '
            'carte porterait l\'ombre des jetons ET celle de Material',
      );
    });
  });
}
