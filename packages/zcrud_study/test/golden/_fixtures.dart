// Fixture DÉTERMINISTE + helpers du harnais golden ES-5.1.
//
// Déterminisme (AC4/AC5) : police Ahem par défaut de `flutter_test` (aucune
// fonte externe), surface + devicePixelRatio + textScaleFactor figés, thème
// fixe, animations off. Contenus d'items CONSTANTS (aucune donnée réelle).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Surface de rendu figée (assez haute pour rendre les 4 sections dans le
/// viewport — le comptage de sous-arbres AC5 exige que le `ListView.builder`
/// matérialise toutes les sections). Dimensions modestes mais NON triviales
/// (bien loin du 1×1 powerless rejeté par R12).
const Size kSurfaceSize = Size(500, 1000);

/// Thème FIXE injecté (aucune couleur codée en dur côté layout ; le thème est la
/// seule source de couleur — FR-26). Fixé pour un rendu reproductible.
ThemeData buildFixedTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3366AA),
      secondaryContainer: Color(0xFFD0E0F0),
      onSecondaryContainer: Color(0xFF10233A),
    ),
  );
}

/// Carte d'item CONSTANTE (équivalent minimal `_buildGridItemCard` IFFD).
Widget _fixtureItemCard(BuildContext context, int index, String tag) {
  return Container(
    key: ValueKey('item:$tag:$index'),
    height: 40,
    alignment: AlignmentDirectional.centerStart,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Text('item-$tag-$index', textAlign: TextAlign.start),
  );
}

/// État vide CONSTANT (équivalent minimal `EmtyFolderContent` IFFD).
Widget _fixtureEmptyState(String label) {
  return Container(
    key: ValueKey('empty:$label'),
    height: 60,
    alignment: AlignmentDirectional.center,
    child: Text(label, textAlign: TextAlign.start),
  );
}

/// Une section peuplée CONSTANTE.
ZStudyToolsSectionSpec populatedSection(
  String id,
  String title,
  int count, {
  bool withAdd = true,
  Axis axis = Axis.vertical,
}) {
  return ZStudyToolsSectionSpec(
    id: id,
    title: title,
    itemCount: count,
    itemBuilder: (context, index) => _fixtureItemCard(context, index, id),
    emptyState: _fixtureEmptyState('empty-$id'),
    addAction: withAdd ? () {} : null,
    axis: axis,
  );
}

/// Une section VIDE CONSTANTE (rendra son `emptyState`).
ZStudyToolsSectionSpec emptySection(
  String id,
  String title, {
  String? emptyLabel,
}) {
  return ZStudyToolsSectionSpec(
    id: id,
    title: title,
    itemCount: 0,
    itemBuilder: (context, index) => _fixtureItemCard(context, index, id),
    emptyState: _fixtureEmptyState(emptyLabel ?? 'empty-$id'),
    addAction: () {},
  );
}

/// Fixture CANONIQUE : 4 sections figées reproduisant la structure IFFD —
/// **rail flashcards HORIZONTAL** (peuplé, ES-5.2 `axis: Axis.horizontal`) +
/// grille documents (peuplé) + grille notes (VIDE → emptyState) + grille
/// mindmaps (peuplé). Ordre = ordre visuel vertical ; le golden reflète les DEUX
/// dispositions (rail horizontal vs grilles verticales — AC6).
List<ZStudyToolsSectionSpec> canonicalSections() {
  return [
    populatedSection('flashcards', 'Flashcards', 3, axis: Axis.horizontal),
    populatedSection('documents', 'Documents', 2),
    emptySection('notes', 'Notes'),
    populatedSection('mindmaps', 'Mindmaps', 2),
  ];
}

/// Enveloppe la liste de sections dans un arbre DÉTERMINISTE (thème fixe,
/// direction fixe). `ZcrudScope` n'est PAS requis : `ZcrudTheme.of` retombe sur
/// `Theme.of` (repli FR-26) — prouve le chemin zéro-config AD-15.
Widget wrapSectioned(
  List<ZStudyToolsSectionSpec> sections, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildFixedTheme(),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: ZSectionedStudyLayout(sections: sections),
      ),
    ),
  );
}

/// Pump helper : fige la surface, le devicePixelRatio et le textScaleFactor,
/// désactive implicitement les animations (aucune n'est déclenchée), puis
/// `pumpAndSettle`. Restaure la vue via `addTearDown`.
Future<void> pumpSectionedLayout(
  WidgetTester tester, {
  required List<ZStudyToolsSectionSpec> sections,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = kSurfaceSize;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(wrapSectioned(sections, textDirection: textDirection));
  await tester.pumpAndSettle();
}

/// Prédicat de comptage de sous-arbres de section : compte les widgets keyés
/// `ValueKey('section:...')` — la décomposition est COMPTABLE (AC5).
Finder sectionSubtrees() {
  return find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> && key.value.startsWith('section:');
  });
}

/// GUARD POWERLESS (R12) — surface de byte-capture. Pleine par défaut : un byte
/// capturé sur une surface TRIVIALE (1×1) rendrait le byte-diff impuissant
/// (fusion/permutation deviendraient indistinguables). L'injection R3-I4 réduit
/// cette valeur à `Size(1, 1)` pour PROUVER que le harnais attrape un golden
/// permissif (le test `m1 fusion` régresse alors).
const Size kByteCaptureSize = kSurfaceSize;

/// Capture les OCTETS de rendu (`RepaintBoundary` → `toImage` → PNG bytes) de la
/// liste de sections, sur une surface figée. Deux rendus visuellement identiques
/// produisent des octets identiques ; toute cassure de décomposition (fusion /
/// permutation / altération) change les octets.
Future<Uint8List> captureBytes(
  WidgetTester tester,
  List<ZStudyToolsSectionSpec> sections, {
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = kByteCaptureSize;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: kByteCaptureSize.width,
        height: kByteCaptureSize.height,
        child: RepaintBoundary(
          key: boundaryKey,
          child: wrapSectioned(sections, textDirection: textDirection),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary = boundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  // `toImage`/`toByteData` sont de l'async RÉEL (raster) : les exécuter sous
  // `tester.runAsync` — sinon le Future fuit hors de la zone fake-async et
  // provoque un « Guarded function conflict » qui contamine les tests suivants.
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}
