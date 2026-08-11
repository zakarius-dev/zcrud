/// 🔴 Gardes de la **feuille contrainte et encadrée** (CR-IFFD-SHEET,
/// 2026-08-09).
///
/// La CR change un **DÉFAUT visible** : la bottom-sheet du socle n'occupe plus
/// toute la largeur et porte un cadre. Ces gardes affirment donc, dans l'ordre :
///
/// 1. **le nouveau défaut** (feuille effectivement plus étroite, cadre
///    effectivement peint) — pas seulement l'existence des paramètres ;
/// 2. **l'échappatoire** (un hôte peut retrouver l'ancien rendu), et par les
///    **deux** niveaux : paramètre et jeton, avec la priorité prouvée **dans les
///    deux sens** ;
/// 3. **l'indépendance** des deux réglages (retirer le cadre ne rend pas la
///    feuille pleine largeur, et inversement) ;
/// 4. l'interaction avec l'existant (`maxWidth`, `forcedMode`, `chrome`, forme
///    ambiante du thème) et l'accessibilité (AD-13).
///
/// ⚠️ **Piège écarté** : mesurer une largeur qui vaut celle de l'écran *parce
/// que la surface de test fait déjà cette taille*. Chaque mesure de largeur est
/// donc **double** : la valeur ATTENDUE (calculée à la main) **et** la
/// comparaison stricte à la largeur d'écran du montage.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_navigation/zcrud_navigation.dart';

import 'support/z_sources.dart' show stripped;

/// Largeur d'écran « compacte » du montage — la policy y choisit `sheet`.
const double kCompactWidth = 400;

/// Largeur d'écran « large » du montage — `forcedMode` y impose `sheet`.
const double kWideWidth = 1600;

/// Ouvre une feuille via `presentEdition` et laisse l'arbre monté.
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
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => presentEdition<void>(
                context,
                builder: (_) => body,
                chrome: chrome,
                // Mode IMPOSÉ : la CR ne porte que sur la branche `sheet`, et
                // sur un écran large la policy choisirait `dialog`/`page`.
                forcedMode: ZEditionPresentation.sheet,
                sheetFrame: sheetFrame,
                maxWidth: maxWidth,
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

/// Largeur RENDUE de la **surface peinte** de la feuille (mesure de rendu, pas
/// de paramètre).
///
/// 🔴 On mesure le `Material` de la feuille, **pas** le widget `BottomSheet` :
/// mesuré le 2026-08-09, `tester.getSize(find.byType(BottomSheet))` rend
/// **toujours la largeur de l'écran**, parce que `BottomSheet.build` enveloppe
/// son `Material` dans `Align(alignment: bottomCenter, child: ConstrainedBox(…))`
/// (`flutter/lib/src/material/bottom_sheet.dart`, l. 412-417) — l'`Align`
/// occupe toute la largeur disponible et c'est lui que la boîte du `BottomSheet`
/// mesure. Une garde branchée là serait **verte quoi qu'il arrive** : elle
/// mesurerait l'ambiant, pas la contrainte.
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

/// La `shape` réellement remise au `BottomSheet` (donc à son `Material`, qui
/// la **peint** — `flutter/lib/src/material/material.dart`, `_ShapeBorderPaint`).
ShapeBorder? sheetShape(WidgetTester tester) =>
    tester.widget<BottomSheet>(find.byType(BottomSheet)).shape;

/// Le côté visible de la `shape` de la feuille, ou `null` si aucun cadre.
BorderSide? sheetSide(WidgetTester tester) {
  final ShapeBorder? s = sheetShape(tester);
  if (s is! OutlinedBorder) {
    return null;
  }
  final BorderSide side = s.side;
  return side.style == BorderStyle.none || side.width == 0 ? null : side;
}

/// `true` ssi un cadre est effectivement peint autour de la feuille.
bool isFramed(WidgetTester tester) => sheetSide(tester) != null;

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // 1. LE NOUVEAU DÉFAUT — il doit être AFFIRMÉ, pas seulement possible
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'SF-1 — DÉFAUT : sur petit écran la feuille est PLUS ÉTROITE que '
      'l\'écran (ratio 0,9)', (WidgetTester tester) async {
    await openSheet(tester);
    final double w = sheetWidth(tester);
    // Double mesure : valeur attendue ET stricte infériorité à l'écran — sans
    // la seconde, la garde passerait si la surface de test faisait déjà 360.
    expect(w, closeTo(kCompactWidth * ZSheetFrameReference.widthRatio, 0.01),
        reason: '🔴 la feuille ne suit pas le ratio de référence (0,9).');
    expect(w, lessThan(kCompactWidth),
        reason: '🔴 la feuille occupe TOUTE la largeur : la marge du '
            'propriétaire a disparu.');
  });

  testWidgets(
      'SF-2 — DÉFAUT : sur grand écran le PLAFOND absolu (640) prime sur le '
      'ratio', (WidgetTester tester) async {
    await openSheet(tester, width: kWideWidth);
    final double w = sheetWidth(tester);
    expect(w, closeTo(ZSheetFrameReference.maxWidth, 0.01),
        reason: '🔴 1600 × 0,9 = 1440 dp de feuille : le plafond M3 (640, '
            '`_BottomSheetDefaultsM3.constraints`) n\'est pas appliqué.');
    expect(w, lessThan(kWideWidth * ZSheetFrameReference.widthRatio),
        reason: '🔴 le ratio seul décide encore : le plafond est inerte.');
  });

  testWidgets('SF-3 — DÉFAUT : le CADRE est effectivement peint',
      (WidgetTester tester) async {
    await openSheet(tester);
    final BorderSide? side = sheetSide(tester);
    expect(side, isNotNull,
        reason: '🔴 aucune bordure visible : le défaut du propriétaire n\'est '
            'pas rendu.');
    expect(side!.width, ZSheetFrameReference.borderWidth);
    expect(side.style, BorderStyle.solid);
  });

  testWidgets(
      'SF-4 — DÉFAUT : la teinte du cadre est le RÔLE outlineVariant, héritée '
      'du thème de l\'hôte (FR-26)', (WidgetTester tester) async {
    // Deux thèmes de graines DIFFÉRENTES : si la couleur était un littéral,
    // elle serait la même dans les deux montages.
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
        reason: '🔴 la teinte ne suit PAS le thème : elle est figée (donc '
            'codée en dur quelque part) — FR-26.');
  });

  testWidgets(
      'SF-5 — DÉFAUT : le cadre s\'applique AUSSI à un formulaire d\'édition '
      '(chrome fourni) — écart délibéré avec IFFD',
      (WidgetTester tester) async {
    await openSheet(tester, chrome: const ZEditionChrome(title: 'Titre'));
    expect(isFramed(tester), isTrue,
        reason: '🔴 le cadre a disparu parce qu\'un chrome d\'édition est '
            'monté : l\'exception « EditionScreen » d\'IFFD a été reproduite, '
            'alors qu\'elle est explicitement écartée.');
    expect(sheetWidth(tester), lessThan(kCompactWidth),
        reason: '🔴 la marge a disparu sur un formulaire d\'édition.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 2. L'ÉCHAPPATOIRE — un hôte doit pouvoir retrouver l'ancien rendu
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('SF-6 — ÉCHAPPATOIRE (paramètre) : `never` retire le cadre',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 l\'échappatoire par paramètre est inerte : le cadre reste '
            'peint.');
    // AD-4 : `null` ⇒ ABSENT de l'arbre — aucune `shape` n'est imposée, le SDK
    // retrouve sa résolution native (thème puis défauts M3).
    expect(sheetShape(tester), isNull,
        reason: '🔴 une `shape` est imposée alors qu\'aucun cadre n\'est '
            'demandé : la résolution native du SDK est écrasée.');
  });

  testWidgets(
      'SF-7 — ÉCHAPPATOIRE (paramètre) : pleine largeur restituée',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(
        widthRatio: 1,
        maxWidth: double.infinity,
      ),
    );
    expect(sheetWidth(tester), closeTo(kCompactWidth, 0.01),
        reason: '🔴 l\'hôte ne peut PAS retrouver la pleine largeur.');
  });

  testWidgets(
      'SF-8 — INDÉPENDANCE : retirer le cadre ne rend PAS la feuille pleine '
      'largeur', (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse);
    expect(sheetWidth(tester),
        closeTo(kCompactWidth * ZSheetFrameReference.widthRatio, 0.01),
        reason: '🔴 désactiver la bordure a AUSSI supprimé la marge : les deux '
            'réglages sont couplés alors qu\'ils doivent être distincts.');
  });

  testWidgets(
      'SF-9 — INDÉPENDANCE (sens inverse) : pleine largeur garde le cadre',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      sheetFrame: const ZSheetFrameSpec(
        widthRatio: 1,
        maxWidth: double.infinity,
      ),
    );
    expect(sheetWidth(tester), closeTo(kCompactWidth, 0.01));
    expect(isFramed(tester), isTrue,
        reason: '🔴 demander la pleine largeur a AUSSI retiré la bordure.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3. LE MAILLON JETON, ET LA PRIORITÉ PROUVÉE DANS LES DEUX SENS
  // ══════════════════════════════════════════════════════════════════════

  // 🔴 CR-TOKENS (2026-08-09) : le maillon jeton est désormais
  // `ZcrudTheme.editionSheet*` (`zcrud_core`), et **plus** une `ThemeExtension`
  // locale. Le mode y est un `String` — AD-1 interdit à `zcrud_core` d'importer
  // `ZSheetFrameMode` — mais l'énumération reste la SOURCE du nom : aucun
  // libellé n'est écrit à la main ici, on passe `.name`.
  ThemeData themeWith(ZcrudTheme token) => ThemeData(
        extensions: <ThemeExtension<dynamic>>[token],
      );

  testWidgets('SF-10 — JETON : `never` désactive le cadre pour TOUTE l\'app',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name),
      ),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 le maillon JETON de la chaîne est inerte.');
  });

  testWidgets('SF-11 — JETON : le ratio et le plafond sont surchargeables',
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
    // Anti-vacuité : la valeur du JETON diffère de celle de la RÉFÉRENCE, donc
    // cette mesure ne peut pas passer avec un jeton ignoré.
    expect(0.5, isNot(ZSheetFrameReference.widthRatio));
    expect(sheetWidth(tester), closeTo(kCompactWidth * 0.5, 0.01),
        reason: '🔴 le jeton de ratio est ignoré.');
    expect(
      sheetWidth(tester),
      isNot(closeTo(kCompactWidth * ZSheetFrameReference.widthRatio, 0.01)),
    );
  });

  testWidgets(
      'SF-11b — JETON : la teinte ET l\'épaisseur du cadre sont '
      'surchargeables', (WidgetTester tester) async {
    const Color jeton = Color(0xFF123456);
    await openSheet(
      tester,
      theme: themeWith(
        const ZcrudTheme(
          editionSheetBorderColor: jeton,
          editionSheetBorderWidth: 4,
        ),
      ),
    );
    final BorderSide? side = sheetSide(tester);
    expect(side, isNotNull);
    // Anti-vacuité : le jeton DIFFÈRE du rôle de repli `outlineVariant` et de
    // l'épaisseur de référence — sinon la garde passerait aussi jeton ignoré.
    final Color role = ThemeData(
      extensions: const <ThemeExtension<dynamic>>[],
    ).colorScheme.outlineVariant;
    expect(jeton, isNot(role));
    expect(4.0, isNot(ZSheetFrameReference.borderWidth));
    expect(side!.color, jeton,
        reason: '🔴 le jeton de teinte est ignoré : le cadre reste peint sur '
            'le rôle de repli.');
    expect(side.width, 4.0, reason: '🔴 le jeton d\'épaisseur est ignoré.');
  });

  testWidgets(
      'SF-12 — PRIORITÉ (sens 1) : paramètre ENCADRANT sous un jeton NON '
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
            '« paramètre > jeton » est inversée.');
  });

  testWidgets(
      'SF-13 — PRIORITÉ (sens 2) : paramètre NON encadrant sous un jeton '
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
  // 4. `unlessChrome` — l'intention d'IFFD, DÉCLARÉE et non devinée
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'SF-14 — `unlessChrome` SANS chrome ⇒ encadré ; AVEC chrome ⇒ non '
      'encadré', (WidgetTester tester) async {
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
        reason: '🔴 `unlessChrome` n\'a pas vu le chrome déclaré : la seule '
            'entrée de la décision est ignorée.');
    // …et la marge, elle, reste : `unlessChrome` ne parle QUE du cadre.
    expect(sheetWidth(tester), lessThan(kCompactWidth));
  });

  testWidgets(
      'SF-15 — `unlessChrome` fonctionne aussi comme JETON (app entière)',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.unlessChrome.name),
      ),
      chrome: const ZEditionChrome(title: 'Titre'),
    );
    expect(isFramed(tester), isFalse,
        reason: '🔴 le jeton `unlessChrome` n\'est pas collapsé par '
            '`presentEdition`.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 5. INTERACTION AVEC L'EXISTANT
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('SF-16 — `maxWidth` explicite REPRIME sur toute la chaîne',
      (WidgetTester tester) async {
    await openSheet(tester, maxWidth: 200);
    expect(sheetWidth(tester), closeTo(200, 0.01),
        reason: '🔴 la CR a volé la priorité au paramètre `maxWidth` de '
            '`presentEdition`, qui la détenait AVANT elle.');
  });

  testWidgets(
      'SF-17 — la forme AMBIANTE du thème est CONSERVÉE : on lui ajoute un '
      'côté, on ne la remplace pas', (WidgetTester tester) async {
    // Cas réel d'IFFD : `kBottomSheetTheme` porte un rayon de 50 en haut.
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
      reason: '🔴 l\'arrondi de l\'hôte a été ÉCRASÉ par la forme de '
          'référence : l\'hôte gagne un contour mais perd son rayon.',
    );
    expect(isFramed(tester), isTrue);
  });

  testWidgets(
      'SF-18 — AD-10 : une forme ambiante NON-OutlinedBorder retombe sur la '
      'référence, sans exception', (WidgetTester tester) async {
    await openSheet(
      tester,
      theme: ThemeData(
        bottomSheetTheme: const BottomSheetThemeData(
          // `StadiumBorder` EST un OutlinedBorder ; `CircleBorder` aussi.
          // Une forme non-outlined : `BeveledRectangleBorder` l'est aussi…
          // On prend donc un vrai non-OutlinedBorder : `UnderlineInputBorder`
          // en est un (InputBorder extends ShapeBorder, pas OutlinedBorder).
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

  testWidgets(
      'SF-19 — CADRE vs POIGNÉE : un SEUL bord est peint (pas deux bords '
      'concentriques)', (WidgetTester tester) async {
    await openSheet(
      tester,
      chrome: const ZEditionChrome(title: 'Titre'),
    );
    int bordered = 0;
    for (final Element e in find.byType(Material).evaluate()) {
      final ShapeBorder? s = (e.widget as Material).shape;
      if (s is OutlinedBorder &&
          s.side.style != BorderStyle.none &&
          s.side.width > 0) {
        bordered++;
      }
    }
    expect(bordered, 1,
        reason: '🔴 $bordered `Material` bordés dans la feuille : le chrome '
            'peint son propre contour PAR-DESSUS celui de la feuille, donc '
            'deux bords concentriques.');
    // La poignée, elle, reste rendue — le cadre ne l'a pas évincée.
    expect(find.byType(ZEditionScaffold), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════
  // 6. AD-13 — accessibilité
  // ══════════════════════════════════════════════════════════════════════

  testWidgets(
      'SF-20 — AD-13 : la feuille contrainte ne réduit AUCUNE cible sous 48 dp',
      (WidgetTester tester) async {
    // 360 dp d'écran ⇒ 324 dp de feuille : le cas le plus serré.
    await openSheet(
      tester,
      width: 360,
      chrome: const ZEditionChrome(title: 'Titre', onSubmit: _noop),
    );
    expect(sheetWidth(tester), closeTo(324, 0.01));
    // 🔴 SCOPÉ au chrome de la feuille : sans ce `descendant`, la garde
    // mesurerait aussi le bouton « ouvrir » de la page HÔTE derrière la
    // modale (un `ElevatedButton` M3 fait 40 dp de haut) — elle rougirait
    // pour une cible qui n'appartient pas au socle.
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

  testWidgets(
      'SF-21 — AD-13 : le cadre n\'est le SEUL canal d\'aucune information',
      (WidgetTester tester) async {
    String semanticsOf(WidgetTester t) {
      final StringBuffer out = StringBuffer();
      for (final Element e in find.byType(Semantics).evaluate()) {
        final Semantics w = e.widget as Semantics;
        final SemanticsProperties p = w.properties;
        out.writeln(
          '${p.label}|${p.button}|${p.enabled}|${p.header}|${w.container}',
        );
      }
      return out.toString();
    }

    // Volet 1 — SOURCE : le cadre ne peut porter AUCUNE information, parce
    // que le fichier qui le produit ne construit aucun nœud sémantique et
    // n'émet aucun libellé. C'est le volet MORDANT (ajouter un `Semantics`
    // dans `z_sheet_frame.dart` le fait rougir) ; le volet 2 ci-dessous est
    // son corollaire observable.
    // Stripped : le dartdoc du fichier peut légitimement CITER `Semantics(`
    // ou `label(` en documentant qu'ils en sont absents — le grep vise le
    // CODE, jamais la prose (même précaution que SG-1/SG-2, P0D1).
    final String src = stripped(File('lib/src/presentation/z_sheet_frame.dart'));
    expect(src.contains('Semantics('), isFalse,
        reason: '🔴 le fichier du cadre construit un nœud sémantique : le '
            'contour porterait alors une information (AD-13).');
    expect(RegExp(r'\blabel\(').hasMatch(src), isFalse,
        reason: '🔴 le fichier du cadre émet un libellé.');

    // Volet 2 — RENDU : la sémantique est la MÊME avec et sans cadre.
    await openSheet(tester, chrome: const ZEditionChrome(title: 'Titre'));
    expect(isFramed(tester), isTrue);
    final String framed = semanticsOf(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await openSheet(
      tester,
      chrome: const ZEditionChrome(title: 'Titre'),
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(isFramed(tester), isFalse);
    expect(semanticsOf(tester), framed,
        reason: '🔴 la sémantique CHANGE selon que le cadre est peint ou non : '
            'une information passerait donc par la couleur/le contour seuls.');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 7. Le jeton `String` du MODE — traduction et AD-10 (CR-TOKENS)
  //
  // 🔴 Le `lerp` et le `copyWith` des cinq jetons `editionSheet*` sont gardés
  // là où ils vivent, dans `zcrud_core`
  // (`test/presentation/z_theme_edition_sheet_tokens_test.dart`, ET-1..ET-9).
  // Ici on garde ce qui est propre à `zcrud_navigation` : la TRADUCTION du
  // jeton `String` en `ZSheetFrameMode`, et son repli AD-10.
  // ══════════════════════════════════════════════════════════════════════

  test(
      'SF-22 — TRADUCTION : chaque palier de `ZSheetFrameMode` est reconnu par '
      'son nom', () {
    // Bijection prouvée sur `values` : ajouter un palier sans l'exposer au
    // thème fait rougir cette garde (elle n'est donc pas figée sur 3 noms).
    expect(ZSheetFrameMode.values, isNotEmpty);
    for (final ZSheetFrameMode m in ZSheetFrameMode.values) {
      expect(zSheetFrameModeFromToken(m.name), m,
          reason: '🔴 le palier `${m.name}` n\'est pas atteignable par le '
              'jeton `ZcrudTheme.editionSheetFrameMode`.');
    }
  });

  test(
      'SF-23 — AD-10 : un jeton INCONNU rend `null` (donc « la référence '
      'décide »), JAMAIS une exception', () {
    for (final String? t in <String?>[
      null,
      '',
      ' ',
      'Never', // casse différente
      'NEVER',
      'always ', // espace parasite
      'unless_chrome', // snake_case
      'aPaliersDUneVersionFuture',
    ]) {
      expect(zSheetFrameModeFromToken(t), isNull,
          reason: '🔴 « $t » a été accepté comme un palier valide.');
    }
    // Anti-vacuité : la fonction n'est pas un `return null` constant.
    expect(
      zSheetFrameModeFromToken(ZSheetFrameMode.never.name),
      ZSheetFrameMode.never,
    );
  });

  testWidgets(
      'SF-24 — AD-10 AU RENDU : un jeton inconnu retombe sur la RÉFÉRENCE, '
      'sans lever — et le canal reste vivant', (WidgetTester tester) async {
    // Volet 1 — jeton inventé : le rendu est celui de la référence (`always`),
    // et aucune exception n'a été levée pendant l'ouverture.
    await openSheet(
      tester,
      theme: themeWith(
        const ZcrudTheme(editionSheetFrameMode: 'unPalierQuiNExistePas'),
      ),
    );
    expect(tester.takeException(), isNull,
        reason: '🔴 un jeton de thème inconnu a fait LEVER le rendu (AD-10).');
    expect(isFramed(tester), isTrue,
        reason: '🔴 le repli sur `ZSheetFrameReference.mode` n\'a pas eu lieu.');

    // Volet 2 — CONTRASTE, sans lequel le volet 1 serait vacant : un jeton
    // VALIDE, lui, change bien le rendu. Le canal n'est donc pas mort.
    await tester.pumpWidget(const SizedBox.shrink());
    await openSheet(
      tester,
      theme: themeWith(
        ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name),
      ),
    );
    expect(isFramed(tester), isFalse);
  });

  test(
      'SF-24b — PAS DE VUE PARALLÈLE : `z_sheet_frame.dart` ne déclare aucune '
      '`ThemeExtension` locale', () {
    // 🔴 CR-LEX-78. `ZSheetFrameTheme` a été supprimée au profit de
    // `ZcrudTheme.editionSheet*` : deux canaux pour la même propriété
    // produisent un gagnant silencieux et deux `lerp` à maintenir. Cette garde
    // empêche la ré-introduction.
    final String src =
        File('lib/src/presentation/z_sheet_frame.dart').readAsStringSync();
    // 🔴 On scanne le CODE, pas la prose : le dartdoc de ce fichier CITE
    // `extends ThemeExtension<` pour expliquer la suppression. Une garde
    // branchée sur le texte brut rougirait sur son propre motif.
    final List<String> code = src
        .split('\n')
        .where((String l) => !l.trimLeft().startsWith('//'))
        .toList();
    expect(code.where((String l) => l.contains('ThemeExtension<')), isEmpty,
        reason: '🔴 une `ThemeExtension` locale est réapparue : le maillon '
            'jeton doit vivre dans `ZcrudTheme`, canal UNIQUE du dépôt.');
    // Anti-vacuité : le fichier a bien été lu, le filtre n'a pas tout mangé,
    // et le code parle bien du canal de thème retenu.
    expect(code.length, greaterThan(100));
    expect(code.any((String l) => l.contains('ZcrudTheme')), isTrue);
  });

  test('SF-25 — `ZSheetFrameSpec()` vide est équivalent à `null`', () {
    // AD-4 : « je ne me prononce pas » sur chaque champ.
    const ZSheetFrameSpec empty = ZSheetFrameSpec();
    expect(empty.mode, isNull);
    expect(empty.widthRatio, isNull);
    expect(empty.maxWidth, isNull);
    expect(empty.borderColor, isNull);
    expect(empty.borderWidth, isNull);
    expect(
      empty.copyWith(mode: ZSheetFrameMode.never).mode,
      ZSheetFrameMode.never,
    );
  });

  test(
      'SF-26 — `effectiveMaxWidth` : le ratio ET le plafond mordent, chacun '
      'sur son domaine', () {
    const ZSheetFrameMetrics m = ZSheetFrameMetrics(
      framed: true,
      widthRatio: ZSheetFrameReference.widthRatio,
      maxWidth: ZSheetFrameReference.maxWidth,
      borderColor: Color(0xFF000000),
      borderWidth: 1,
      fallbackTopRadius: 28,
    );
    expect(m.effectiveMaxWidth(360), closeTo(324, 1e-9));
    expect(m.effectiveMaxWidth(400), closeTo(360, 1e-9));
    expect(m.effectiveMaxWidth(700), closeTo(630, 1e-9));
    expect(m.effectiveMaxWidth(1600), 640);
  });
}

void _noop() {}

/// Corps de test qui **veut toute la largeur disponible**.
///
/// 🔴 Indispensable : le `Material` d'une bottom-sheet **s'ajuste à son
/// contenu**. Avec un simple `Text('CORPS')`, la feuille mesurée fait 71 dp de
/// large quelles que soient les contraintes — une garde de largeur branchée
/// là serait **inerte** (elle mesurerait le texte, jamais la contrainte).
class _ExpandingBody extends StatelessWidget {
  const _ExpandingBody();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: double.infinity,
        height: 200,
        child: Text('CORPS'),
      );
}
