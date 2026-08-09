/// 🔴 Gardes de la **surface de la feuille sous GetX** — « surface avec le
/// cadre » (décision propriétaire, 2026-08-09).
///
/// ## Le défaut mesuré, et pourquoi aucune garde ne le voyait
///
/// `get 4.7.2`, `extension_navigation.dart` l. 46 :
/// `backgroundColor: backgroundColor ?? Colors.transparent`. La valeur remise à
/// `GetModalBottomSheetRoute` n'est donc **jamais `null`**, et la chaîne propre
/// de la route (`?? sheetTheme.modalBackgroundColor ?? sheetTheme.backgroundColor`,
/// `bottomsheet.dart` l. 89-91) est **court-circuitée** : le
/// `BottomSheetThemeData` de l'hôte n'a aucun effet et la feuille est
/// transparente. Le cadre livré par CR-IFFD-SHEET se peignait donc, sous GetX,
/// comme un **contour flottant sur la barrière**.
///
/// `z_get_sheet_frame_test.dart` mesure la largeur, la `shape` et `enableDrag` —
/// **jamais** la couleur du `Material` peint. Mesuré (grep NÉGATIF, `rc=1`) :
/// `grep -n "backgroundColor\|widget<Material>" test/z_get_sheet_frame_test.dart`
/// ⇒ **aucune ligne** ; ses seules occurrences de `.color` (l. 215-221) portent
/// sur le `BorderSide` du cadre, pas sur la surface. C'est le trou que ce
/// fichier ferme.
///
/// ## 🔴 Le piège de la garde VACANTE, hérité du lot précédent
///
/// `GS-2` avait été écrite vacante : elle mesurait le **plancher du SDK** au
/// lieu du nôtre, et l'injection R3 ne la faisait pas rougir. Même famille de
/// risque ici : asserter « la surface vaut `surfaceContainerLow` » ne prouve
/// rien si `surfaceContainerLow` se trouve valoir la couleur ambiante, et
/// asserter « le thème est honoré » ne prouve rien si la valeur posée par le
/// thème est celle que le repli aurait produite de toute façon.
///
/// **Chaque volet établit donc d'abord que la valeur attendue DIFFÈRE de celle
/// qu'il aurait obtenue sans le comportement testé** — pré-assertions
/// explicites, marquées « ANTI-VACUITÉ ».
///
/// ## Ce qui est mesuré : la couleur RÉELLEMENT peinte
///
/// Pas « un paramètre a été passé à `Get.bottomSheet` » : le `BottomSheet` du
/// SDK construit `Material(color: color, …)` (`bottom_sheet.dart` l. 387-389)
/// après avoir résolu `widget.backgroundColor ?? theme ?? defaults` (l. 353).
/// C'est **ce `Material`** — celui qui peint — que ces gardes lisent.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Largeur d'écran du montage.
const double kWidth = 400;

/// Sentinelle « fond MODAL posé par l'hôte ».
const Color kModalSentinel = Color(0xFF102030);

/// Sentinelle « fond COMMUN posé par l'hôte » — distincte de [kModalSentinel]
/// pour pouvoir départager les deux maillons du thème.
const Color kCommonSentinel = Color(0xFF405060);

/// Sentinelle « fond EXPLICITE fourni à l'appel ».
const Color kExplicitSentinel = Color(0xFF708090);

/// Sentinelle « `canvasColor` de l'hôte » (branche M2).
const Color kCanvasSentinel = Color(0xFFA0B0C0);

/// Corps **expansif** : sans lui le `Material` de la feuille se réduirait au
/// contenu et la mesure de largeur de [GSU-12] serait vacante.
class _ExpandingBody extends StatelessWidget {
  const _ExpandingBody();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: double.infinity,
        height: 200,
        child: Text('CORPS'),
      );
}

/// Ouvre une feuille via `presentEdition` **avec le présentateur GetX**, et
/// laisse l'arbre monté.
///
/// Le passage par `presentEdition` est délibéré (même raison que dans
/// `z_get_sheet_frame_test.dart`) : c'est lui qui teste
/// `is ZImplicitDismissControl` et qui collapse `unlessChrome`.
Future<void> openSheet(
  WidgetTester tester, {
  ThemeData? theme,
  ZSheetFrameSpec? sheetFrame,
  ZGetFormPresenter presenter = const ZGetFormPresenter(),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.physicalSize = const Size(kWidth, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => unawaited(
                presentEdition<void>(
                  context,
                  builder: (_) => const _ExpandingBody(),
                  presenter: presenter,
                  forcedMode: ZEditionPresentation.sheet,
                  sheetFrame: sheetFrame,
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Le `Material` **qui peint** la feuille (cf. l'en-tête).
Finder sheetMaterialFinder() => find
    .descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Material),
    )
    .first;

/// La couleur **réellement peinte** par la feuille.
Color? sheetSurface(WidgetTester tester) =>
    tester.widget<Material>(sheetMaterialFinder()).color;

/// Le côté visible de la `shape`, ou `null` si aucun cadre (même lecture que
/// `z_get_sheet_frame_test.dart`).
BorderSide? sheetSide(WidgetTester tester) {
  final ShapeBorder? s =
      tester.widget<BottomSheet>(find.byType(BottomSheet)).shape;
  if (s is! OutlinedBorder) {
    return null;
  }
  final BorderSide side = s.side;
  return side.style == BorderStyle.none || side.width == 0 ? null : side;
}

/// Largeur RENDUE de la surface peinte (le `BottomSheet` lui-même rendrait
/// toujours la largeur d'écran — piège documenté dans
/// `z_get_sheet_frame_test.dart`).
double sheetWidth(WidgetTester tester) =>
    tester.getSize(sheetMaterialFinder()).width;

/// Un thème dont on connaît le rôle de repli.
ThemeData themeSeeded(Color seed) =>
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed));

void main() {
  setUp(() => Get.testMode = true);

  // ══════════════════════════════════════════════════════════════════════
  // 1. LE DÉFAUT — la surface effacée par GetX est RÉTABLIE
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GSU-0 — DÉFAUT : cadre peint ⇒ la feuille peint RÉELLEMENT le fond que '
      'le SDK Material aurait résolu (et non `Colors.transparent`)',
      (WidgetTester tester) async {
    final ThemeData theme = themeSeeded(const Color(0xFF0000FF));
    // 🔴 ANTI-VACUITÉ : sans le correctif la surface vaut `Colors.transparent`
    // (GetX force `?? Colors.transparent`). L'assertion n'a de valeur que si le
    // rôle attendu en diffère.
    expect(theme.colorScheme.surfaceContainerLow, isNot(Colors.transparent),
        reason: '🔴 le rôle de repli VAUT le défaut GetX : la garde ne '
            'distinguerait pas le correctif de son absence.');
    await openSheet(tester, theme: theme);
    expect(sheetSide(tester), isNotNull,
        reason: '🔴 aucun cadre monté : le volet parlerait d\'un cas qui '
            'n\'existe pas.');
    expect(sheetSurface(tester), theme.colorScheme.surfaceContainerLow,
        reason: '🔴 la feuille GetX ne peint pas la surface du SDK : le cadre '
            'flotte sur la barrière. `Get.bottomSheet` force '
            '`?? Colors.transparent` — il faut lui remettre la couleur.');
  });

  testWidgets(
      'GSU-1 — la surface rétablie est OPAQUE (une surface, pas une teinte '
      'translucide)', (WidgetTester tester) async {
    await openSheet(tester, theme: themeSeeded(const Color(0xFF0000FF)));
    final Color? c = sheetSurface(tester);
    expect(c, isNotNull,
        reason: '🔴 le `Material` de la feuille n\'a AUCUNE couleur : rien '
            'n\'est peint.');
    expect(c!.a, 1.0,
        reason: '🔴 la surface est translucide (alpha ${c.a}) : le contenu de '
            'la page reste visible au travers.');
    expect(c, isNot(Colors.transparent));
  });

  testWidgets(
      'GSU-2 — « surface AVEC le cadre » : les deux sont peints dans le MÊME '
      'montage', (WidgetTester tester) async {
    final ThemeData theme = themeSeeded(const Color(0xFF0000FF));
    await openSheet(tester, theme: theme);
    final BorderSide? side = sheetSide(tester);
    expect(side, isNotNull, reason: '🔴 le cadre a disparu.');
    expect(side!.color, theme.colorScheme.outlineVariant);
    expect(sheetSurface(tester)!.a, 1.0,
        reason: '🔴 cadre sans surface : exactement le rendu que la décision '
            'propriétaire refuse.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 2. L'ÉCHAPPATOIRE — cadre coupé ⇒ le rendu GetX d'aujourd'hui, INTACT
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GSU-3 — ÉCHAPPATOIRE (paramètre) : cadre désactivé ⇒ fond TRANSPARENT, '
      'comme aujourd\'hui', (WidgetTester tester) async {
    final ThemeData theme = themeSeeded(const Color(0xFF0000FF));
    // 🔴 ANTI-VACUITÉ : on mesure D'ABORD l'état encadré du MÊME thème. Sans
    // cette moitié, un volet qui trouverait « transparent » partout (correctif
    // entièrement inerte) passerait quand même.
    await openSheet(tester, theme: theme);
    final Color? framed = sheetSurface(tester);
    expect(framed, isNot(Colors.transparent),
        reason: '🔴 le correctif est inerte : la garde d\'échappatoire serait '
            'vraie par vacuité.');
    await tester.pumpWidget(const SizedBox.shrink());

    await openSheet(
      tester,
      theme: theme,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(sheetSide(tester), isNull, reason: '🔴 le cadre n\'a pas été coupé.');
    expect(sheetSurface(tester), Colors.transparent,
        reason: '🔴 l\'échappatoire est perdue : couper le cadre ne rend plus '
            'le comportement GetX historique (fond transparent). Un hôte qui '
            'peignait lui-même son fond voit désormais DEUX surfaces.');
  });

  testWidgets(
      'GSU-4 — ÉCHAPPATOIRE (jeton) : `editionSheetFrameMode: never` rend la '
      'transparence pour TOUTE l\'app', (WidgetTester tester) async {
    // 🔴 Le mode transite en `String?` côté `ZcrudTheme` (AD-1 : `zcrud_core`
    // ne connaît pas `ZSheetFrameMode`) ; l'enum reste la source du nom.
    await openSheet(
      tester,
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[
          ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name),
        ],
      ),
    );
    expect(sheetSide(tester), isNull);
    expect(sheetSurface(tester), Colors.transparent,
        reason: '🔴 le maillon JETON ne pilote plus la surface : la surface et '
            'le cadre se sont découplés.');
  });

  testWidgets(
      'GSU-5 — AD-10 : un jeton de mode INCONNU ne lève pas et retombe sur la '
      'référence (donc encadré ⇒ surface)', (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
      extensions: <ThemeExtension<dynamic>>[
        // Chaîne libre : thème sérialisé par une version plus récente du socle.
        const ZcrudTheme(editionSheetFrameMode: 'PALIER-INCONNU'),
      ],
    );
    await openSheet(tester, theme: theme);
    expect(sheetSurface(tester), theme.colorScheme.surfaceContainerLow,
        reason: '🔴 un jeton inconnu a changé la surface (ou levé) : '
            '`zSheetFrameModeFromToken` doit rendre `null` et laisser la '
            'référence décider.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3. LE THÈME DE L'HÔTE PRIME SUR LE REPLI (fidélité au SDK)
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GSU-6 — `BottomSheetThemeData.modalBackgroundColor` de l\'hôte est '
      'HONORÉ et prime sur le rôle de repli', (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
      bottomSheetTheme:
          const BottomSheetThemeData(modalBackgroundColor: kModalSentinel),
    );
    // 🔴 ANTI-VACUITÉ (double) : la sentinelle doit différer ET du repli de
    // rôle, ET du défaut GetX — sinon le volet ne distingue rien.
    expect(kModalSentinel, isNot(theme.colorScheme.surfaceContainerLow),
        reason: '🔴 la sentinelle VAUT le repli : le volet passerait même si '
            'le thème était ignoré.');
    expect(kModalSentinel, isNot(Colors.transparent));
    await openSheet(tester, theme: theme);
    expect(sheetSurface(tester), kModalSentinel,
        reason: '🔴 le `BottomSheetThemeData` de l\'hôte est ignoré : le '
            'binding impose sa propre teinte (FR-26 — « on n\'impose pas les '
            'couleurs »).');
  });

  testWidgets(
      'GSU-7 — fidélité SDK : `modalBackgroundColor` prime sur '
      '`backgroundColor` du MÊME thème', (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      bottomSheetTheme: const BottomSheetThemeData(
        modalBackgroundColor: kModalSentinel,
        backgroundColor: kCommonSentinel,
      ),
    );
    // 🔴 ANTI-VACUITÉ : les deux maillons doivent être distinguables.
    expect(kModalSentinel, isNot(kCommonSentinel));
    await openSheet(tester, theme: theme);
    expect(sheetSurface(tester), kModalSentinel,
        reason: '🔴 l\'ordre du SDK n\'est pas reproduit : `showModalBottomSheet` '
            'lit `modalBackgroundColor` AVANT `backgroundColor` '
            '(`bottom_sheet.dart` l. 1147-1148). Une feuille modale et une '
            'feuille persistante n\'auraient plus la même règle.');
  });

  testWidgets(
      'GSU-8 — fidélité SDK : `backgroundColor` SEUL du thème est honoré '
      '(maillon 3)', (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: kCommonSentinel),
    );
    // 🔴 ANTI-VACUITÉ.
    expect(kCommonSentinel, isNot(theme.colorScheme.surfaceContainerLow));
    await openSheet(tester, theme: theme);
    expect(sheetSurface(tester), kCommonSentinel,
        reason: '🔴 le maillon `backgroundColor` du thème est sauté : un hôte '
            'qui n\'a réglé QUE lui perd sa teinte au profit du rôle.');
  });

  testWidgets(
      'GSU-9 — fidélité SDK (branche M2) : sans Material 3, le repli est '
      '`ThemeData.canvasColor`, pas un rôle M3',
      (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      useMaterial3: false,
      canvasColor: kCanvasSentinel,
    );
    // 🔴 ANTI-VACUITÉ : le repli M3 du MÊME thème doit différer, sinon les deux
    // branches sont indiscernables et le volet ne prouve rien.
    expect(kCanvasSentinel, isNot(theme.colorScheme.surfaceContainerLow),
        reason: '🔴 `canvasColor` VAUT le rôle M3 : la branche M2 serait '
            'indistinguable.');
    expect(kCanvasSentinel, isNot(Colors.transparent));
    await openSheet(tester, theme: theme);
    expect(sheetSurface(tester), kCanvasSentinel,
        reason: '🔴 un hôte resté en Material 2 reçoit une couleur M3 : la '
            'reproduction de la résolution du SDK n\'est pas fidèle '
            '(`bottom_sheet.dart` l. 1139-1141 : `defaults` y est VIDE).');
  });

  testWidgets(
      'GSU-10 — FR-26 : la teinte SUIT le thème de l\'hôte, elle n\'est figée '
      'nulle part dans le binding', (WidgetTester tester) async {
    final ThemeData a = themeSeeded(const Color(0xFF0000FF));
    final ThemeData b = themeSeeded(const Color(0xFFFF0000));
    // 🔴 ANTI-VACUITÉ : deux graines qui rendraient le MÊME rôle ne prouveraient
    // rien.
    expect(a.colorScheme.surfaceContainerLow,
        isNot(b.colorScheme.surfaceContainerLow));
    await openSheet(tester, theme: a);
    final Color? ca = sheetSurface(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await openSheet(tester, theme: b);
    final Color? cb = sheetSurface(tester);
    expect(ca, a.colorScheme.surfaceContainerLow);
    expect(cb, b.colorScheme.surfaceContainerLow);
    expect(ca == cb, isFalse,
        reason: '🔴 la surface est la MÊME sous deux thèmes différents : une '
            'couleur est codée en dur dans le binding (FR-26).');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 4. LE FOND EXPLICITE PRIME SUR TOUT
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GSU-11 — un fond EXPLICITE à l\'appel prime sur le thème de l\'hôte',
      (WidgetTester tester) async {
    final ThemeData theme = ThemeData(
      bottomSheetTheme:
          const BottomSheetThemeData(modalBackgroundColor: kModalSentinel),
    );
    // 🔴 ANTI-VACUITÉ : le fond explicite doit différer de ce que le thème
    // aurait donné, sinon la priorité n'est pas observable.
    expect(kExplicitSentinel, isNot(kModalSentinel));
    await openSheet(
      tester,
      theme: theme,
      presenter: const ZGetFormPresenter(
        sheetBackgroundColor: kExplicitSentinel,
      ),
    );
    expect(sheetSurface(tester), kExplicitSentinel,
        reason: '🔴 le thème a battu le paramètre : la chaîne '
            '« paramètre > thème > rôle » est inversée.');
  });

  testWidgets(
      'GSU-12 — le fond explicite prime AUSSI cadre coupé (c\'est le '
      '`backgroundColor` que `Get.bottomSheet` accepte : le '
      '`?? Colors.transparent` ne joue qu\'en son ABSENCE)',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
      presenter: const ZGetFormPresenter(
        sheetBackgroundColor: kExplicitSentinel,
      ),
    );
    expect(sheetSide(tester), isNull);
    expect(sheetSurface(tester), kExplicitSentinel,
        reason: '🔴 couper le cadre a ÉCRASÉ un fond que l\'appelant avait '
            'demandé explicitement. « Prime sur tout le reste » inclut '
            'l\'échappatoire de cadre.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 5. NON-RÉGRESSION DU LOT PRÉCÉDENT
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GSU-13 — rétablir la surface ne touche NI la marge NI le cadre',
      (WidgetTester tester) async {
    await openSheet(tester, theme: themeSeeded(const Color(0xFF0000FF)));
    expect(sheetWidth(tester),
        closeTo(kWidth * ZSheetFrameReference.widthRatio, 0.01),
        reason: '🔴 la marge de CR-IFFD-SHEET a été perdue.');
    expect(sheetSide(tester)!.width, ZSheetFrameReference.borderWidth,
        reason: '🔴 l\'épaisseur du cadre a changé.');
  });
}
