@TestOn('vm')
/// 🔴 Garde de SOURCE de `ZGetFormPresenter` — « zéro valeur recopiée »,
/// exemption **ZÉRO** (patron `z_material_source_guard_test.dart`, K3).
///
/// Le contrat de l'alignement CR-IFFD-SHEET côté binding GetX : **toute**
/// dimension, forme et couleur de la feuille vient de la chaîne partagée de
/// `zcrud_navigation` — `zSheetFrameMetricsOf`, qui résout **paramètre
/// (`ZSheetFrameSpec`) > jetons `ZcrudTheme.editionSheet*` (`zcrud_core`) >
/// `ZSheetFrameReference`** — ou de `ZAdaptivePresenterDefaults`. Le binding ne
/// **décide** de rien.
///
/// (Mesuré le 2026-08-09 : le maillon intermédiaire n'est plus une
/// `ThemeExtension` locale au paquet de navigation — elle a été supprimée au
/// profit du canal de thème unique `ZcrudTheme` ;
/// `grep -rn "ZSheetFrameTheme" packages/zcrud_navigation/lib packages/zcrud_core/lib`
/// ne rend plus que des lignes de **commentaire** du fichier
/// `z_sheet_frame.dart` qui en documentent le retrait.)
///
/// ## Surface (« surface avec le cadre », 2026-08-09)
///
/// Le présentateur rétablit désormais le fond que `Get.bottomSheet` efface. La
/// résolution est **reprise du SDK**, donc elle non plus n'introduit aucune
/// valeur : `GSG-2` (aucune couleur construite) reste la garde qui le tient, et
/// `GSG-0` exige la présence du maillon `_themeSheetSurface`.
///
/// Sans cette garde, le mode de panne est connu et silencieux : recopier `0.9`
/// et `640` ici rendrait des tests VERTS aujourd'hui et laisserait les deux
/// copies **diverger** au premier ajustement de la référence — c'est exactement
/// le défaut que l'audit `ZAdaptivePresenterDefaults` avait déjà corrigé une
/// fois dans ce fichier (un `_ZGetPresenterDefaults` local y répliquait les
/// bornes M3).
///
/// Volets :
/// * **GSG-0** — contrôle POSITIF : la garde balaie bien la source réelle et
///   y trouve les marqueurs de consommation de la chaîne (sans quoi tout le
///   reste serait vrai par vacuité) ;
/// * **GSG-1** — aucun littéral numérique (le fichier n'en a AUCUN besoin :
///   toutes ses bornes sont des constantes nommées d'un autre paquet) ;
/// * **GSG-2** — aucune couleur construite ici (FR-26) ;
/// * **GSG-3** — aucune forme ni bordure construite ici : `resolveShape` est le
///   seul canal ;
/// * **GSG-4** — aucune inspection du contenu (`runtimeType`, `is`
///   d'écran, `EditionScreen`) : l'heuristique d'IFFD reste écartée ;
/// * **GSG-5** — AD-13 : aucun motif non directionnel ;
/// * **GSG-6** — `double.infinity` interdit sur la LARGEUR de feuille : c'est
///   le défaut exact qui neutralisait le plafond M3.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La seule source sous contrat ici.
const String kPresenterPath = 'lib/src/presentation/z_get_form_presenter.dart';

/// Code utile d'une ligne : sans commentaire (`//…`) ni contenu de chaîne.
///
/// Indispensable — l'en-tête de ce présentateur **documente** les valeurs de la
/// référence (0,9 ; 640) et cite le SDK. Une garde qui lirait les commentaires
/// rougirait sur sa propre documentation.
String _stripped(String line) {
  final StringBuffer out = StringBuffer();
  bool inString = false;
  String quote = '';
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (inString) {
      if (c == quote) {
        inString = false;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      quote = c;
      continue;
    }
    if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
      break;
    }
    out.write(c);
  }
  return out.toString();
}

void main() {
  final File source = File(kPresenterPath);
  final List<String> lines = source.readAsLinesSync();

  test('GSG-0 — contrôle POSITIF : la garde lit la source réelle, qui '
      'CONSOMME la chaîne partagée', () {
    // Un scan muet rendrait toutes les assertions suivantes vraies par vacuité.
    expect(source.existsSync(), isTrue);
    expect(lines.length, greaterThan(80));
    final String all = lines.join('\n');
    for (final String marker in <String>[
      'ZImplicitDismissControl',
      'zSheetFrameMetricsOf',
      'effectiveMaxWidth',
      'resolveShape',
      'ZSheetFrameSpec',
      'ZAdaptivePresenterDefaults',
    ]) {
      expect(all, contains(marker),
          reason: '🔴 le présentateur ne consomme plus « $marker » : la chaîne '
              'partagée a été court-circuitée.');
    }

    // 🔴 « Surface avec le cadre » — ces marqueurs-ci sont cherchés dans le
    // CODE UTILE, pas dans le fichier brut. La nuance n'est pas cosmétique :
    // l'en-tête de ce présentateur *documente* la résolution du SDK et cite
    // `modalBackgroundColor` en toutes lettres. Un contrôle qui lirait le
    // fichier brut resterait donc VERT alors que le maillon aurait disparu du
    // code — une garde qui défend le défaut, exactement la famille recensée
    // dans la rétrospective de l'epic CHAT. Mesuré en R3 : l'injection
    // « le `BottomSheetThemeData` de l'hôte est ignoré » ne rougissait pas ce
    // volet tant qu'il lisait le brut.
    final String code = lines.map(_stripped).join('\n');
    for (final String marker in <String>[
      '_themeSheetSurface',
      'modalBackgroundColor',
      'surfaceContainerLow',
    ]) {
      expect(code, contains(marker),
          reason: '🔴 le CODE ne porte plus « $marker » : la reproduction de '
              'la résolution du SDK Material est incomplète — la feuille GetX '
              'reperd sa surface ou cesse d\'honorer le thème de l\'hôte.');
    }
  });

  test('GSG-1 — aucun littéral numérique : toute borne est une constante '
      'nommée de `zcrud_navigation`', () {
    final RegExp number =
        RegExp(r'(?<![A-Za-z0-9_.])\d+(\.\d+)?(?![A-Za-z0-9_])');
    final List<String> hits = <String>[];
    for (int n = 0; n < lines.length; n++) {
      for (final RegExpMatch m in number.allMatches(_stripped(lines[n]))) {
        hits.add('$kPresenterPath:${n + 1} → « ${m.group(0)} »');
      }
    }
    expect(hits, isEmpty,
        reason: '🔴 valeur recopiée dans le binding — elle doit venir de '
            '`ZSheetFrameReference`/`ZAdaptivePresenterDefaults` :\n'
            '${hits.join('\n')}');
  });

  test('GSG-2 — FR-26 : aucune couleur construite dans le binding', () {
    final RegExp banned =
        RegExp(r'(?<![A-Za-z0-9_])(Color\(|Colors\.|Color\.fromARGB)');
    for (int n = 0; n < lines.length; n++) {
      expect(banned.hasMatch(_stripped(lines[n])), isFalse,
          reason: '🔴 $kPresenterPath:${n + 1} — couleur en dur : la teinte du '
              'cadre est un RÔLE résolu par `zSheetFrameMetricsOf`.');
    }
  });

  test('GSG-3 — aucune forme ni bordure construite ici : `resolveShape` est '
      'le seul canal', () {
    final RegExp banned = RegExp(
      r'(?<![A-Za-z0-9_])(BorderSide\(|RoundedRectangleBorder\(|'
      r'BorderRadius\.|Radius\.|StadiumBorder\(|OutlinedBorder\()',
    );
    for (int n = 0; n < lines.length; n++) {
      expect(banned.hasMatch(_stripped(lines[n])), isFalse,
          reason: '🔴 $kPresenterPath:${n + 1} — le binding fabrique sa propre '
              'forme : elle divergera de celle de `ZAdaptivePresenter`.');
    }
  });

  test('GSG-4 — le contenu n\'est JAMAIS inspecté (heuristique IFFD écartée)',
      () {
    final RegExp banned = RegExp(
      r'(?<![A-Za-z0-9_])(runtimeType|EditionScreen|endsWith\()',
    );
    for (int n = 0; n < lines.length; n++) {
      expect(banned.hasMatch(_stripped(lines[n])), isFalse,
          reason: '🔴 $kPresenterPath:${n + 1} — inspection du contenu : '
              'l\'heuristique `runtimeType.toString().endsWith("EditionScreen")` '
              'est explicitement refusée. `unlessChrome` se résout dans '
              '`presentEdition`, pas ici.');
    }
  });

  test('GSG-5 — AD-13 : aucun motif non directionnel', () {
    final RegExp banned = RegExp(
      r'EdgeInsets\.only\(|EdgeInsets\.fromLTRB\(|Alignment\.centerLeft|'
      r'Alignment\.centerRight|TextAlign\.left|TextAlign\.right|'
      r'(?<![A-Za-z0-9_])Positioned\(',
    );
    for (int n = 0; n < lines.length; n++) {
      expect(banned.hasMatch(_stripped(lines[n])), isFalse,
          reason: '🔴 $kPresenterPath:${n + 1} — motif non directionnel.');
    }
  });

  test('GSG-6 — la LARGEUR de feuille ne retombe JAMAIS sur `double.infinity` '
      '(le défaut qui neutralisait le plafond M3)', () {
    for (int n = 0; n < lines.length; n++) {
      final String code = _stripped(lines[n]);
      expect(
        RegExp(r'maxWidth\s*[:?]{1,2}[^,;]*double\.infinity').hasMatch(code),
        isFalse,
        reason: '🔴 $kPresenterPath:${n + 1} — « maxWidth ?? double.infinity » '
            'est de retour : il ÉCRASE le plafond de la chaîne partagée et '
            'supprime la marge des hôtes GetX.',
      );
    }
  });
}
