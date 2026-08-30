// CR-LEX-93 — les DEUX hôtes (IFFD et lex) réécrivaient les mêmes quatre
// nombres de grille de dossiers, et IFFD réécrivait en plus le seuil 840 que
// le socle porte déjà (`ZWindowSizeThresholds.expandedMinWidth`).
//
// Les littéraux ci-dessous sont RECOPIÉS de la mesure hôte, jamais choisis
// ici — dépôt IFFD, branche `main` :
//   • lib/src/presentation/features/folders/pages/folders_page.dart:450
//       final itemMinWidth = Get.width >= 840 ? 350 : 300.0;
//   • lib/src/presentation/features/folders/pages/folders_page.dart:648-649
//       mainAxisSpacing: 8, crossAxisSpacing: 8
//   • lib/src/presentation/features/folders/pages/folders_page.dart:652
//       childAspectRatio: itemWidth / 250
//
// Cette garde fige ces valeurs : les changer côté socle changerait la grille
// de tout hôte qui adopte la référence, et doit donc être un geste explicite.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZWindowSizeThresholds;
import 'package:zcrud_study/zcrud_study.dart';

/// Remonte jusqu'au dossier du paquet (celui qui porte `pubspec.yaml`), pour
/// que la garde de source soit ancrée sur le paquet et non sur le répertoire
/// courant du harnais.
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('pubspec.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('CR-LEX-93 — jetons de grille de dossiers', () {
    test('les quatre valeurs de référence sont celles relevées chez l\'hôte',
        () {
      expect(ZFolderGridReference.minItemWidth, 300);
      expect(ZFolderGridReference.minItemWidthExpanded, 350);
      expect(ZFolderGridReference.cellHeight, 250);
      expect(ZFolderGridReference.spacing, 8);
    });

    test('le palier consomme le seuil du socle — jamais un 840 réécrit', () {
      // Le seuil vient de `zcrud_responsive` : c'est précisément ce que l'hôte
      // IFFD réécrivait en dur faute de le connaître.
      expect(ZWindowSizeThresholds.expandedMinWidth, 840);

      // Juste EN DESSOUS du palier ⇒ régime étroit.
      expect(
        ZFolderGridReference.minItemWidthFor(
          ZWindowSizeThresholds.expandedMinWidth - 0.01,
        ),
        ZFolderGridReference.minItemWidth,
      );
      // AU palier (comparaison `>=`, comme chez l'hôte) ⇒ régime étendu.
      expect(
        ZFolderGridReference.minItemWidthFor(
          ZWindowSizeThresholds.expandedMinWidth,
        ),
        ZFolderGridReference.minItemWidthExpanded,
      );
      expect(
        ZFolderGridReference.minItemWidthFor(1400),
        ZFolderGridReference.minItemWidthExpanded,
      );
    });

    test('reproduit la décision de l\'hôte sur ses propres largeurs', () {
      // Transcription littérale du site hôte `folders_page.dart:450`, jouée
      // sur des largeurs de part et d'autre du palier.
      double hostRule(double width) => width >= 840 ? 350 : 300.0;

      for (final double width in <double>[320, 599, 600, 839, 840, 1024, 1920]) {
        expect(
          ZFolderGridReference.minItemWidthFor(width),
          hostRule(width),
          reason: 'divergence avec la règle hôte à $width dp',
        );
      }
    });

    test('replis AD-10 — largeur non finie ⇒ régime le plus étroit, sans throw',
        () {
      expect(
        ZFolderGridReference.minItemWidthFor(double.nan),
        ZFolderGridReference.minItemWidth,
      );
      expect(
        ZFolderGridReference.minItemWidthFor(double.infinity),
        ZFolderGridReference.minItemWidth,
      );
      expect(
        ZFolderGridReference.minItemWidthFor(-1),
        ZFolderGridReference.minItemWidth,
      );
    });

    test('la référence ne porte AUCUNE couleur (FR-26, aucune exemption due)',
        () {
      final File source = File(
        '${_packageRoot().path}/lib/src/presentation/z_folder_grid_reference.dart',
      );
      expect(source.existsSync(), isTrue, reason: '${source.path} introuvable');
      final String text = source.readAsStringSync();

      for (final String pattern in <String>[
        'Color(',
        'Colors.',
        '0xFF',
        '0xff',
        'LinearGradient',
        'withOpacity',
      ]) {
        expect(
          text.contains(pattern),
          isFalse,
          reason: 'motif couleur « $pattern » dans un fichier de référence '
              'qui doit rester purement dimensionnel',
        );
      }
    });

    test(
        'la référence n\'est PAS inscrite dans l\'exemption nominative '
        'anti-couleurs — elle est traitée comme ZFolderCardReference', () {
      // Mécanisme vérifié : `z_widgets_hardcode_scan_test.dart` porte un
      // `_colorGuardExemptFiles` NOMINATIF. Seules les deux références qui
      // portent des couleurs non dérivables y figurent ; les références
      // purement dimensionnelles (carte de dossier, grille de dossiers) sont
      // gardées comme n'importe quel fichier de `lib/`.
      final File scan = File(
        '${_packageRoot().path}/test/presentation/z_widgets_hardcode_scan_test.dart',
      );
      expect(scan.existsSync(), isTrue, reason: '${scan.path} introuvable');
      final String text = scan.readAsStringSync();

      expect(
        text.contains('z_folder_grid_reference.dart'),
        isFalse,
        reason: 'exemption INUTILE : la grille de référence ne porte aucune '
            'couleur, l\'exempter affaiblirait la garde sans besoin',
      );
      // Contre-preuve du mécanisme : sa sœur dimensionnelle ne l'est pas non
      // plus, tandis que les deux références COLORÉES le sont bien.
      expect(text.contains('z_folder_card_reference.dart'), isFalse);
      expect(text.contains('z_flashcard_card_reference.dart'), isTrue);
      expect(text.contains('z_content_hub_reference.dart'), isTrue);
    });
  });
}
