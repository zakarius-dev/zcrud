/// Tests SU-12 du **bornage AD-41** (AC4) : le contenu riche d'un nœud est borné
/// à la cellule fixe du GRAPHE (`ZMindmapCellClip`) — troncature clippée, JAMAIS
/// de `RenderFlex overflow` (leçon su-2/D3) — tandis que la vue liste / l'outline
/// gardent le rendu riche COMPLET (non borné). La contre-preuve prouve que le
/// harnais SAIT déborder sans le bornage (sinon `takeException(), isNull` serait
/// aveugle — infalsifiable).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

const Size _cell = Size(180, 72);

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: ZcrudScope(
            child: SizedBox(width: 800, height: 600, child: child),
          ),
        ),
      ),
    );

/// Un contenu de nœud volontairement TROP HAUT pour la cellule (débordant).
Widget _tallContent(BuildContext context, ZMindmapNode node) => Column(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[SizedBox(height: 2000, width: 2000)],
    );

void main() {
  group('AC4 — ZMindmapCellClip borne à la cellule (aucun overflow)', () {
    testWidgets('contenu 2000px borné à 180×72 ⇒ AUCUN RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox.fromSize(
              size: _cell,
              child: ZMindmapCellClip(
                size: _cell,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[SizedBox(height: 2000, width: 2000)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Bornage effectif : pas de mesure intrinsèque qui déborde, pas d'overflow.
      expect(tester.takeException(), isNull);
      // La cellule reste à sa taille fixe (troncature, pas d'expansion).
      final size = tester.getSize(find.byType(ZMindmapCellClip));
      expect(size.height, _cell.height);
      expect(size.width, _cell.width);
    });

    testWidgets(
        'D2 PORTEUR — le ClipRect TRONQUE réellement : un pixel SOUS la cellule '
        'n\'est PAS peint par le contenu débordant (peinture, pas absence overflow)',
        (tester) async {
      // Cœur d'AD-41 : la TRONCATURE. L'`OverflowBox` seul évite l'ERREUR de
      // débordement (RenderFlex overflow) mais laisse l'enfant PEINDRE hors
      // cellule ; seul le `ClipRect` tronque cette peinture. Ce test l'observe
      // par les pixels rendus (rougit si le ClipRect disparaît — su-2/D3).
      const Color red = Color(0xFFFF0000); // enfant 2000px : sans clip, déborde
      const Color blue = Color(0xFF0000FF); // FOND distinct sous la cellule
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _host(
          Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const ColoredBox(
                color: blue,
                child: SizedBox(
                  width: 180,
                  height: 200, // zone capturée PLUS HAUTE que la cellule (72)
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ZMindmapCellClip(
                      size: _cell,
                      child: ColoredBox(
                        color: red,
                        child: SizedBox(width: 2000, height: 2000),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      // `toImage`/`toByteData` sont de VRAIS Futures : ils ne se résolvent que
      // hors de la fake-async du test ⇒ `runAsync` obligatoire (sinon deadlock).
      late final Uint8List bytes;
      late final int w;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        bytes = data.buffer.asUint8List();
        w = image.width;
        image.dispose();
      });
      int channel(int x, int y, int c) => bytes[(y * w + x) * 4 + c];

      // Pixel BIEN EN DESSOUS de la cellule (y=150 > 72), dans sa largeur (x=10).
      // Avec ClipRect : l'enfant rouge est tronqué à 72 ⇒ ce pixel est le FOND
      // (bleu). Sans ClipRect (mutation) : l'enfant 2000px déborde et le peint
      // en ROUGE ⇒ ces assertions ROUGISSENT par comportement (peinture).
      expect(channel(10, 150, 0), lessThan(40),
          reason: 'canal R : le contenu débordant NE doit PAS peindre sous la '
              'cellule (troncature AD-41)');
      expect(channel(10, 150, 2), greaterThan(200),
          reason: 'canal B : sous la cellule, seul le FOND est peint (contenu '
              'tronqué par le ClipRect)');
    });

    testWidgets(
        'CONTRE-PREUVE : le MÊME contenu SANS bornage DÉBORDE (harnais falsifiable)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox.fromSize(
              size: _cell,
              // Aucun ZMindmapCellClip : le contenu 2000px dans une cellule 72px
              // via un Flex contraint ⇒ RenderFlex overflow. Prouve que le
              // détecteur d'overflow FONCTIONNE (le test « green » n'est pas vide).
              child: Column(
                children: const <Widget>[SizedBox(height: 2000, width: 2000)],
              ),
            ),
          ),
        ),
      );
      final ex = tester.takeException();
      expect(ex, isNotNull,
          reason: 'sans bornage le harnais DOIT déborder (contre-preuve)');
      expect(ex.toString().toLowerCase(), contains('overflow'));
    });
  });

  group('AC4 — le GRAPHE borne, la LISTE / l\'outline NON', () {
    testWidgets('graphe : les nœuds sont enveloppés de ZMindmapCellClip',
        (tester) async {
      final roots = <ZMindmapNode>[
        ZMindmapNode(id: 'r', label: 'Racine'),
        ZMindmapNode(id: 'c', label: 'Enfant'),
      ];
      await tester.pumpWidget(
        _host(ZMindmapView(roots: roots, mode: ZMindmapViewMode.graph)),
      );
      await tester.pump();
      // Branchement EFFECTIF du bornage graphe (rougit si la vue ne l'applique pas).
      expect(find.byType(ZMindmapCellClip), findsWidgets);
    });

    testWidgets(
        'graphe + contenu riche TROP HAUT ⇒ borné, AUCUN overflow (AD-41)',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'Racine')];
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: roots,
            mode: ZMindmapViewMode.graph,
            nodeContentBuilder: _tallContent,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'la cellule graphe borne le contenu riche (AD-41)');
    });

    testWidgets('liste : rendu COMPLET non borné (aucun ZMindmapCellClip)',
        (tester) async {
      final roots = <ZMindmapNode>[
        ZMindmapNode(id: 'r', label: 'Racine'),
        ZMindmapNode(id: 'c', label: 'Enfant'),
      ];
      await tester.pumpWidget(
        _host(ZMindmapView(roots: roots, mode: ZMindmapViewMode.list)),
      );
      await tester.pump();
      // La liste a11y garde le rendu riche COMPLET : jamais borné à la cellule.
      expect(find.byType(ZMindmapCellClip), findsNothing);
    });
  });
}
