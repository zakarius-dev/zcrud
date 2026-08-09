/// 🔴 Gardes de la **feuille contrainte et encadrée sous GetX** — alignement de
/// `ZGetFormPresenter` sur `ZAdaptivePresenter` (CR-IFFD-SHEET, 2026-08-09).
///
/// ## Ce que ces gardes couvrent, et pourquoi elles n'existaient pas
///
/// Mesuré avant l'alignement : `z_get_form_presenter_test.dart` et
/// `ex_ui_11_seam_test.dart` ne touchent **ni** la largeur, **ni** la `shape`,
/// **ni** `enableDrag`. Le présentateur GetX pouvait donc rendre une feuille
/// pleine largeur et sans cadre **sans qu'aucun test ne rougisse** — c'est
/// exactement le trou que ce fichier ferme.
///
/// ## 🔴 Deux pièges de MESURE, déjà payés par le lot `zcrud_navigation`
///
/// 1. `tester.getSize(find.byType(BottomSheet))` rend **toujours la largeur
///    d'écran** : `BottomSheet.build` enveloppe son `Material` dans
///    `Align(alignment: bottomCenter, child: ConstrainedBox(…))`
///    (`flutter/lib/src/material/bottom_sheet.dart`, l. 412-417) et c'est
///    l'`Align` que la boîte du `BottomSheet` mesure. On mesure donc le
///    **`Material` peint**, pas le `BottomSheet`.
/// 2. Le `Material` d'une feuille **s'ajuste à son contenu** : mesurer un
///    contenu étroit ne prouve rien sur la contrainte. Le corps de test est donc
///    **expansif** (`width: double.infinity`), pour que la largeur rendue soit
///    la contrainte elle-même.
///
/// Chaque mesure de largeur est en outre **double** : la valeur attendue
/// (calculée à la main) **et** la comparaison stricte à la largeur d'écran du
/// montage — sans quoi une garde passerait si la surface de test faisait déjà
/// la bonne taille.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Largeur d'écran « compacte » du montage.
const double kCompactWidth = 400;

/// Largeur d'écran « large » du montage — au-delà du plafond M3.
const double kWideWidth = 1600;

/// Corps **expansif** : sans lui, le `Material` de la feuille se réduirait au
/// contenu et toute mesure de largeur serait vacante.
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
/// Le passage par `presentEdition` (et non par un appel direct au présentateur)
/// est délibéré : c'est lui qui teste `is ZImplicitDismissControl` et qui
/// collapse `unlessChrome`. Un test qui appellerait `presentWithDismissControl`
/// en direct **ne verrait pas** la retombée silencieuse sur `present`.
Future<void> openSheet(
  WidgetTester tester, {
  double width = kCompactWidth,
  ZSheetFrameSpec? sheetFrame,
  ZEditionChrome? chrome,
  ThemeData? theme,
  double? maxWidth,
  Widget body = const _ExpandingBody(),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.physicalSize = Size(width, 800);
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
                  builder: (_) => body,
                  presenter: const ZGetFormPresenter(),
                  chrome: chrome,
                  // Mode IMPOSÉ : l'alignement ne porte que sur `sheet`.
                  forcedMode: ZEditionPresentation.sheet,
                  sheetFrame: sheetFrame,
                  maxWidth: maxWidth,
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

/// Largeur RENDUE de la surface peinte (cf. les deux pièges en tête).
double sheetWidth(WidgetTester tester) => tester
    .getSize(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          )
          .first,
    )
    .width;

/// La `shape` réellement remise au `BottomSheet`.
ShapeBorder? sheetShape(WidgetTester tester) =>
    tester.widget<BottomSheet>(find.byType(BottomSheet)).shape;

/// Le côté visible de la `shape`, ou `null` si aucun cadre.
BorderSide? sheetSide(WidgetTester tester) {
  final ShapeBorder? s = sheetShape(tester);
  if (s is! OutlinedBorder) {
    return null;
  }
  final BorderSide side = s.side;
  return side.style == BorderStyle.none || side.width == 0 ? null : side;
}

/// `true` ssi un cadre est effectivement peint.
bool isFramed(WidgetTester tester) => sheetSide(tester) != null;

/// `enableDrag` réellement remis au `BottomSheet` du SDK par la route GetX.
bool sheetEnableDrag(WidgetTester tester) =>
    tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag;

void main() {
  setUp(() => Get.testMode = true);

  // ══════════════════════════════════════════════════════════════════════
  // 1. LE NOUVEAU DÉFAUT — affirmé, pas seulement possible
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GS-1 — DÉFAUT : sous GetX la feuille est PLUS ÉTROITE que l\'écran '
      '(ratio de référence)', (WidgetTester tester) async {
    await openSheet(tester);
    final double w = sheetWidth(tester);
    expect(w, closeTo(kCompactWidth * ZSheetFrameReference.widthRatio, 0.01),
        reason: '🔴 le présentateur GetX ne suit pas le ratio de la chaîne '
            'partagée : la marge des hôtes GetX (DODLP/IFFD) est absente.');
    expect(w, lessThan(kCompactWidth),
        reason: '🔴 la feuille occupe TOUTE la largeur (le vieux '
            '`maxWidth ?? double.infinity` est de retour).');
  });

  testWidgets('GS-2 — DÉFAUT : le PLAFOND absolu prime sur le ratio',
      (WidgetTester tester) async {
    // 🔴 PIÈGE ÉCARTÉ, mesuré en R3 (injection « ratio recopié sans plafond ») :
    // avec le thème par défaut, ce volet est **VACANT**. Le `BottomSheet` du
    // SDK applique DÉJÀ son propre plafond M3 de 640 dp
    // (`_BottomSheetDefaultsM3.constraints`) puisque `Get.bottomSheet` ne lui
    // transmet aucune `constraints` — la largeur mesurée valait donc 640 même
    // quand NOTRE plafond était supprimé. La garde mesurait le plancher du SDK,
    // pas le nôtre.
    //
    // On DÉSARME donc le plafond du SDK par le thème de l'hôte (seul canal que
    // GetX laisse passer) : ce qui reste mesuré est exclusivement la chaîne
    // partagée.
    await openSheet(
      tester,
      width: kWideWidth,
      theme: ThemeData(
        bottomSheetTheme: const BottomSheetThemeData(
          constraints: BoxConstraints(),
        ),
      ),
    );
    final double w = sheetWidth(tester);
    expect(w, closeTo(ZSheetFrameReference.maxWidth, 0.01),
        reason: '🔴 le plafond de la référence n\'est pas appliqué par le '
            'binding (le SDK ne le fait plus : son propre plafond est désarmé '
            'par le thème du montage).');
    expect(w, lessThan(kWideWidth * ZSheetFrameReference.widthRatio),
        reason: '🔴 le ratio seul décide encore : le plafond est inerte.');
  });

  testWidgets('GS-3 — DÉFAUT : le CADRE est effectivement peint sous GetX',
      (WidgetTester tester) async {
    await openSheet(tester);
    final BorderSide? side = sheetSide(tester);
    expect(side, isNotNull,
        reason: '🔴 aucune bordure : `Get.bottomSheet(shape:)` ne reçoit pas '
            'la forme résolue par la chaîne partagée.');
    expect(side!.width, ZSheetFrameReference.borderWidth);
    expect(side.style, BorderStyle.solid);
  });

  testWidgets(
      'GS-4 — DÉFAUT : la teinte du cadre est le RÔLE du thème de l\'hôte '
      '(FR-26)', (WidgetTester tester) async {
    final ThemeData a = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
    );
    final ThemeData b = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0000)),
    );
    await openSheet(tester, theme: a);
    final Color ca = sheetSide(tester)!.color;
    expect(ca, a.colorScheme.outlineVariant,
        reason: '🔴 la bordure n\'est pas le rôle `outlineVariant`.');
    await tester.pumpWidget(const SizedBox.shrink());
    await openSheet(tester, theme: b);
    final Color cb = sheetSide(tester)!.color;
    expect(cb, b.colorScheme.outlineVariant);
    expect(ca == cb, isFalse,
        reason: '🔴 la teinte ne suit PAS le thème : elle est figée quelque '
            'part dans le binding (FR-26).');
  });

  testWidgets(
      'GS-5 — DÉFAUT : le cadre s\'applique AUSSI à un formulaire d\'édition '
      '(chrome déclaré) — l\'heuristique « EditionScreen » reste écartée',
      (WidgetTester tester) async {
    await openSheet(tester, chrome: const ZEditionChrome(title: 'Titre'));
    expect(isFramed(tester), isTrue,
        reason: '🔴 le cadre a disparu parce qu\'un chrome est monté : le '
            'binding a réintroduit une inspection du contenu.');
    expect(sheetWidth(tester), lessThan(kCompactWidth));
  });

  // ══════════════════════════════════════════════════════════════════════
  // 2. L'ÉCHAPPATOIRE, LE JETON, ET LA PRIORITÉ DANS LES DEUX SENS
  // ══════════════════════════════════════════════════════════════════════

  // 🔴 Le maillon JETON est porté par `ZcrudTheme` (`zcrud_core`) depuis
  // CR-TOKENS (2026-08-09) : la `ThemeExtension` locale `ZSheetFrameTheme` de
  // `zcrud_navigation` a été SUPPRIMÉE au profit du canal de thème unique du
  // dépôt. Le mode y transite en `String` (contrainte AD-1 : `zcrud_core` ne
  // connaît pas `ZSheetFrameMode`) — d'où `ZSheetFrameMode.x.name`, qui garde
  // l'enum comme source du nom.
  ThemeData themeWith(ZcrudTheme token) => ThemeData(
        extensions: <ThemeExtension<dynamic>>[token],
      );

  testWidgets('GS-6 — ÉCHAPPATOIRE (paramètre) : `never` retire le cadre',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 l\'échappatoire par paramètre est inerte sous GetX.');
    expect(sheetShape(tester), isNull,
        reason: '🔴 une `shape` est imposée alors qu\'aucun cadre n\'est '
            'demandé : la résolution native du SDK est écrasée (AD-4).');
  });

  testWidgets(
      'GS-7 — INDÉPENDANCE : retirer le cadre ne rend PAS la feuille pleine '
      'largeur', (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse);
    expect(sheetWidth(tester),
        closeTo(kCompactWidth * ZSheetFrameReference.widthRatio, 0.01),
        reason: '🔴 désactiver la bordure a AUSSI supprimé la marge : les deux '
            'réglages sont couplés dans le binding.');
  });

  testWidgets(
      'GS-8 — INDÉPENDANCE (sens inverse) : pleine largeur garde le cadre',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(
        widthRatio: 1,
        maxWidth: double.infinity,
      ),
    );
    expect(sheetWidth(tester), closeTo(kCompactWidth, 0.01),
        reason: '🔴 l\'hôte GetX ne peut PAS retrouver la pleine largeur sous '
            'le plafond du SDK.');
    expect(isFramed(tester), isTrue,
        reason: '🔴 demander la pleine largeur a AUSSI retiré la bordure.');
  });

  testWidgets(
      'GS-9 — DIVERGENCE ASSUMÉE : au-delà du plafond du SDK, `Get.bottomSheet` '
      'n\'expose pas `constraints` ⇒ la pleine largeur reste plafonnée',
      (WidgetTester tester) async {
    // 🟢 TRIPWIRE : le jour où GetX exposera `constraints` (ou où l'on
    // trouvera un canal équivalent), ce volet ROUGIT et désigne la divergence
    // comme réparable. Il affirme la LIMITE, pas une qualité.
    await openSheet(
      tester,
      width: kWideWidth,
      sheetFrame: const ZSheetFrameSpec(
        widthRatio: 1,
        maxWidth: double.infinity,
      ),
    );
    expect(sheetWidth(tester), lessThan(kWideWidth),
        reason: '🟢 GetX transmet désormais des `constraints` au `BottomSheet` '
            ': la divergence documentée en tête de '
            '`z_get_form_presenter.dart` est réparable — retirez-la.');
  });

  testWidgets('GS-10 — JETON : `never` désactive le cadre pour TOUTE l\'app',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name),
      ),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 le maillon JETON est inerte sous GetX.');
  });

  testWidgets('GS-11 — JETON : le ratio est surchargeable',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        const ZcrudTheme(
          editionSheetWidthRatio: 0.5,
          editionSheetMaxWidth: double.infinity,
        ),
      ),
    );
    expect(sheetWidth(tester), closeTo(kCompactWidth * 0.5, 0.01),
        reason: '🔴 le jeton de ratio est ignoré par le binding.');
  });

  testWidgets(
      'GS-12 — PRIORITÉ (sens 1) : paramètre ENCADRANT sous un jeton NON '
      'encadrant', (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name),
      ),
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.always),
    );
    expect(isFramed(tester), isTrue,
        reason: '🔴 le jeton a battu le paramètre : la chaîne '
            '« paramètre > jeton » est inversée dans le binding.');
  });

  testWidgets(
      'GS-13 — PRIORITÉ (sens 2) : paramètre NON encadrant sous un jeton '
      'ENCADRANT', (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.always.name),
      ),
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 le jeton a battu le paramètre dans l\'autre sens.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3. `unlessChrome` — résolu EN AMONT, jamais deviné ici
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GS-14 — `unlessChrome` SANS chrome ⇒ encadré ; AVEC chrome ⇒ non '
      'encadré (collapse faite par `presentEdition`)',
      (WidgetTester tester) async {
    const ZSheetFrameSpec spec =
        ZSheetFrameSpec(mode: ZSheetFrameMode.unlessChrome);
    await openSheet(tester, sheetFrame: spec);
    expect(isFramed(tester), isTrue,
        reason: '🔴 `unlessChrome` retire le cadre alors qu\'AUCUN chrome '
            'n\'est déclaré.');
    await tester.pumpWidget(const SizedBox.shrink());
    await openSheet(
      tester,
      sheetFrame: spec,
      chrome: const ZEditionChrome(title: 'Titre'),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 le binding n\'honore pas le mode déjà collapsé par '
            '`presentEdition`.');
    expect(sheetWidth(tester), lessThan(kCompactWidth),
        reason: '🔴 `unlessChrome` ne parle QUE du cadre : la marge reste.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 4. INTERACTION AVEC L'EXISTANT
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('GS-15 — `maxWidth` explicite REPRIME sur toute la chaîne',
      (WidgetTester tester) async {
    await openSheet(tester, maxWidth: 200);
    expect(sheetWidth(tester), closeTo(200, 0.01),
        reason: '🔴 l\'alignement a volé la priorité au paramètre `maxWidth`, '
            'qui la détenait AVANT lui.');
  });

  testWidgets(
      'GS-16 — la forme AMBIANTE du thème est CONSERVÉE : on lui ajoute un '
      'côté, on ne la remplace pas', (WidgetTester tester) async {
    // Cas réel d'IFFD : `kBottomSheetTheme` porte un grand rayon en haut.
    await openSheet(
      tester,
      theme: ThemeData(
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
          ),
        ),
      ),
    );
    final ShapeBorder? s = sheetShape(tester);
    expect(s, isA<RoundedRectangleBorder>());
    expect(
      (s! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(50)),
      reason: '🔴 l\'arrondi de l\'hôte a été ÉCRASÉ : il gagne un contour '
          'mais perd son rayon.',
    );
    expect(isFramed(tester), isTrue);
  });

  testWidgets(
      'GS-17 — AD-10 : une forme ambiante NON-OutlinedBorder retombe sur la '
      'référence, sans exception', (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: ThemeData(
        bottomSheetTheme: const BottomSheetThemeData(
          shape: UnderlineInputBorder(),
        ),
      ),
    );
    final ShapeBorder? s = sheetShape(tester);
    expect(s, isA<RoundedRectangleBorder>(),
        reason: '🔴 le repli de référence n\'a pas eu lieu.');
    expect(
      (s! as RoundedRectangleBorder).borderRadius,
      BorderRadius.vertical(
        top: Radius.circular(ZSheetFrameReference.fallbackTopRadius),
      ),
    );
    expect(isFramed(tester), isTrue);
  });

  // ══════════════════════════════════════════════════════════════════════
  // 5. AD-13 — la feuille contrainte ne casse pas l'accessibilité
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GS-18 — AD-13 : la feuille contrainte ne réduit AUCUNE cible sous 48 dp',
      (WidgetTester tester) async {
    // 360 dp d'écran ⇒ le cas le plus serré.
    await openSheet(
      tester,
      width: 360,
      chrome: const ZEditionChrome(title: 'Titre', onSubmit: _noop),
    );
    expect(sheetWidth(tester),
        closeTo(360 * ZSheetFrameReference.widthRatio, 0.01));
    // 🔴 SCOPÉ au chrome : sans ce `descendant`, la garde mesurerait aussi le
    // bouton « ouvrir » de la page hôte derrière la modale.
    final Iterable<Element> taps = find
        .descendant(
          of: find.byType(ZEditionScaffold),
          matching: find.byType(GestureDetector),
        )
        .evaluate();
    expect(taps, isNotEmpty,
        reason: '🔴 aucune cible tactile trouvée : la garde serait VACANTE.');
    for (final Element e in taps) {
      final Size s = e.size ?? Size.zero;
      if (s.isEmpty) {
        continue;
      }
      expect(s.height, greaterThanOrEqualTo(48.0),
          reason: '🔴 une cible tactile fait ${s.height} dp de haut dans la '
              'feuille contrainte (AD-13 exige 48).');
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // 6. `enableDrag` — le paramètre RÉELLEMENT remis au SDK
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'GS-19 — SANS garde d\'abandon, `enableDrag` reste au défaut GetX '
      '(voie historique intacte)', (WidgetTester tester) async {
    await openSheet(tester, chrome: const ZEditionChrome(title: 'Titre'));
    expect(sheetEnableDrag(tester), isTrue,
        reason: '🔴 le glissement a été désactivé alors qu\'AUCUN garde '
            'd\'abandon n\'est armé : régression d\'ergonomie.');
  });
}

void _noop() {}
