/// Garde de **SOURCE** du chrome d'édition — AD-13 (RTL) et FR-26/NFR-S7
/// (aucune couleur ni libellé codé en dur).
///
/// Elle lit les fichiers **réellement sur disque** : c'est la seule façon de
/// prouver une ABSENCE. Chemins RELATIFS au dossier du paquet (convention du
/// dépôt : `flutter test` se lance depuis `packages/zcrud_navigation`).
///
/// 🔴 Le grep porte sur le CODE, jamais sur la prose : chaque motif banni ici
/// (`TextAlign.left`, `Colors.`…) est un nom que le dartdoc du chantier
/// documentation peut légitimement CITER pour expliquer pourquoi il est
/// interdit. `_read` retourne donc la source STRIPPÉE de ses commentaires
/// (`test/support/z_sources.dart`) — jamais le fichier brut.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show stripSource;

const List<String> _chromeSources = <String>[
  'lib/src/presentation/z_edition_chrome.dart',
  'lib/src/presentation/z_edition_scaffold.dart',
  'lib/src/presentation/z_implicit_dismiss_control.dart',
  // CR-IFFD-SHEET (2026-08-09) — la feuille contrainte et encadrée introduit
  // une COULEUR dans le rendu (le cadre). C'est exactement le fichier qu'il
  // faut soumettre à la garde FR-26.
  'lib/src/presentation/z_sheet_frame.dart',
  'lib/src/presentation/z_adaptive_presenter.dart',
  'lib/src/presentation/present_edition.dart',
  // CR scaffold-scrollable-body (2026-08-09) — nouveau fichier du chrome
  // d'édition. Il n'a aujourd'hui aucune couleur ni libellé, et c'est
  // précisément ce que cette garde doit continuer d'établir demain : un
  // fichier neuf non listé serait un TROU dans la garde FR-26.
  'lib/src/presentation/z_edition_body_fit.dart',
  // CR-IFFD-122 (2026-08-26) — la réservation de la place du clavier est un
  // fichier neuf du chrome d'édition. Il n'a aujourd'hui ni couleur ni
  // libellé : la garde doit l'établir DEMAIN aussi, faute de quoi le fichier
  // serait un trou dans la couverture FR-26/AD-13.
  'lib/src/presentation/z_sheet_keyboard_inset.dart',
];

/// Motifs BANNIS pour le RTL (AD-13) — les variantes directionnelles existent.
const Map<String, String> _bannedDirectional = <String, String>{
  'EdgeInsets.only(left:': 'utiliser EdgeInsetsDirectional.only(start:)',
  'EdgeInsets.only(right:': 'utiliser EdgeInsetsDirectional.only(end:)',
  'Alignment.centerLeft': 'utiliser AlignmentDirectional.centerStart',
  'Alignment.centerRight': 'utiliser AlignmentDirectional.centerEnd',
  'Positioned(left:': 'utiliser PositionedDirectional(start:)',
  'Positioned(right:': 'utiliser PositionedDirectional(end:)',
  'TextAlign.left': 'utiliser TextAlign.start',
  'TextAlign.right': 'utiliser TextAlign.end',
};

/// Motifs BANNIS pour FR-26 — une couleur littérale dans un paquet.
const List<String> _bannedColors = <String>[
  'Color(0x',
  'Colors.',
  'Color.fromARGB',
  'Color.fromRGBO',
];

/// Les seules chaînes visibles par l'utilisateur admises dans le chrome sont
/// des **clés** de `ZcrudLocalizations`, passées à `label(context, …)`.
const List<String> _allowedLabelKeys = <String>['save', 'cancel', 'close'];

String _read(String path) {
  final File f = File(path);
  expect(f.existsSync(), isTrue, reason: '🔴 source absente : $path');
  // Stripped : le grep vise le CODE, jamais le dartdoc qui documente
  // légitimement les motifs interdits (cf. l'en-tête de ce fichier).
  return stripSource(f.readAsStringSync());
}

void main() {
  group('SG-1 — AD-13 : aucune variante directionnelle bannie', () {
    for (final String path in _chromeSources) {
      test(path, () {
        final String src = _read(path);
        // La table de la garde elle-même cite les motifs : on ne scanne que le
        // code du chrome, jamais ce fichier de test.
        for (final MapEntry<String, String> e in _bannedDirectional.entries) {
          expect(src.contains(e.key), isFalse,
              reason: '🔴 $path contient « ${e.key} » — ${e.value} (AD-13).');
        }
      });
    }
  });

  group('SG-2 — FR-26 : aucune couleur littérale', () {
    for (final String path in _chromeSources) {
      test(path, () {
        final String src = _read(path);
        for (final String motif in _bannedColors) {
          expect(src.contains(motif), isFalse,
              reason: '🔴 $path contient « $motif » : une couleur littérale '
                  'dans un paquet (FR-26). Passer par un rôle du '
                  '`ColorScheme` ou un jeton `ZcrudTheme`.');
        }
      });
    }
  });

  test('SG-3 — NFR-S7 : les libellés passent tous par `label(context, clé)`',
      () {
    final String src = _read('lib/src/presentation/z_edition_scaffold.dart');
    final RegExp calls = RegExp(r"label\(\s*context,\s*'([a-zA-Z.]+)'\s*\)");
    final List<String> keys =
        calls.allMatches(src).map((Match m) => m.group(1)!).toList();
    expect(keys, isNotEmpty,
        reason: '🔴 aucun appel `label(context, …)` : les libellés du chrome '
            'ne viennent plus de `ZcrudLocalizations`.');
    for (final String key in keys) {
      expect(_allowedLabelKeys.contains(key), isTrue,
          reason: '🔴 clé l10n « $key » inconnue du cœur : elle doit être '
              'posée dans `zcrud_core` avant usage.');
    }
  });

  test('SG-4 — le fichier de RÉFÉRENCE ne porte que des DIMENSIONS', () {
    final String src = _read('lib/src/presentation/z_edition_chrome.dart');
    final int start = src.indexOf('abstract final class ZEditionChromeReference');
    expect(start, greaterThan(-1));
    final int end = src.indexOf('\n}', start);
    final String body = src.substring(start, end);
    for (final String motif in _bannedColors) {
      expect(body.contains(motif), isFalse,
          reason: '🔴 `ZEditionChromeReference` porte une couleur : '
              'l\'exception FR-26 encadrée ne couvre que les dimensions.');
    }
  });

  test(
      'SG-5 — `ZSheetFrameReference` ne porte que des DIMENSIONS (CR-IFFD-SHEET)',
      () {
    final String src = _read('lib/src/presentation/z_sheet_frame.dart');
    final int start = src.indexOf('abstract final class ZSheetFrameReference');
    expect(start, greaterThan(-1),
        reason: '🔴 le fichier de référence audité de la feuille a disparu.');
    final int end = src.indexOf('\n}', start);
    final String body = src.substring(start, end);
    for (final String motif in _bannedColors) {
      expect(body.contains(motif), isFalse,
          reason: '🔴 `ZSheetFrameReference` porte une couleur : la teinte du '
              'cadre doit rester un RÔLE du `ColorScheme`, hérité du thème de '
              'l\'hôte (le propriétaire a tranché « on n\'impose pas les '
              'couleurs »).');
    }
  });
}
