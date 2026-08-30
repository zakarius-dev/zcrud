/// Gardes STATIQUES de la bascule responsive des sous-dossiers.
///
/// Ce que ces gardes défendent :
/// 1. la règle de bascule a **UNE seule source** dans `lib/` — un second site
///    de comparaison au seuil rougit ici, avant de diverger en silence ;
/// 2. le seuil reste **nommé** : aucun littéral de largeur de bascule dans la
///    famille de fichiers concernée (FR-26).
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show libDartFiles, stripped;

/// Chemin normalisé (séparateurs `/`) d'un fichier de `lib/`.
String _path(File f) => f.path.replaceAll(r'\', '/');

/// Le SEUL fichier autorisé à porter la règle de bascule.
const String _kRuleFile = 'lib/src/presentation/z_subfolder_nav.dart';

/// La FAMILLE de fichiers qui rend la navigation de sous-dossiers : les
/// surfaces, la bascule, et l'ossature qui la consomme. Une comparaison de
/// largeur ou un littéral de seuil n'y a de sens qu'au site de la règle.
bool _inNavFamily(String path) =>
    path.contains('/z_subfolder_') || path.endsWith('z_study_folder_detail.dart');

void main() {
  group('CR-87 — la règle de bascule a une SOURCE UNIQUE', () {
    test(
      'le seuil de bascule des sous-dossiers n\'est nommé que dans '
      'z_subfolder_nav.dart',
      () {
        // Le seuil lui-même (`ZWindowSizeThresholds.mediumMinWidth`) et sa
        // constante dérivée ne doivent apparaître dans le CODE que là où la
        // règle vit. Ailleurs, c'est une seconde copie de la décision.
        //
        // La garde vise le SEUIL, pas le porte-jetons : `ZWindowSizeThresholds`
        // porte aussi `expandedMinWidth`, qui est la règle d'UNE AUTRE famille
        // (la grille de dossiers). Bannir la classe entière obligerait cette
        // famille-là à réécrire son propre seuil en littéral — exactement le
        // défaut que cette garde combat, déplacé d'un cran.
        final RegExp re = RegExp(
          r'\b(ZWindowSizeThresholds\.mediumMinWidth|'
          r'kZSubfolderSidebarBreakpoint)\b',
        );
        final Map<String, int> hits = <String, int>{};
        for (final File f in libDartFiles()) {
          final int n = stripped(f).where(re.hasMatch).length;
          if (n > 0) hits[_path(f)] = n;
        }
        expect(
          hits.keys.where((String p) => !p.endsWith(_kRuleFile)),
          isEmpty,
          reason:
              'seuil de bascule nommé hors de $_kRuleFile : $hits — '
              'la règle serait dupliquée',
        );
        expect(
          hits.keys.where((String p) => p.endsWith(_kRuleFile)),
          hasLength(1),
          reason: 'garde VACUELLE : la règle n\'a été trouvée nulle part',
        );
      },
    );

    test('la comparaison de largeur au seuil n\'existe qu\'à UN endroit', () {
      // `>=` (ou `>`) appliqué à une largeur disponible : la forme exacte
      // qu'un hôte réécrit quand la règle ne lui est pas atteignable.
      final RegExp re = RegExp(
        r'(availableWidth|maxWidth|constraints\.maxWidth)\s*>=?',
      );
      final List<String> sites = <String>[];
      for (final File f in libDartFiles()) {
        if (!_inNavFamily(_path(f))) continue;
        if (stripped(f).any(re.hasMatch)) sites.add(_path(f));
      }
      expect(
        sites.where((String p) => !p.endsWith(_kRuleFile)),
        isEmpty,
        reason: 'comparaison de largeur hors de $_kRuleFile : $sites',
      );
      expect(sites, isNotEmpty, reason: 'garde VACUELLE');
    });

    test('aucune largeur de bascule CODÉE EN DUR dans la famille nav', () {
      // FR-26 — la valeur du seuil ne doit apparaître nulle part comme
      // littéral : ni dans la bascule, ni dans les surfaces, ni dans
      // l'ossature qui la consomme.
      final RegExp literal = RegExp(r'(?<![\w.])600(\.0)?(?![\w.])');
      final List<String> offenders = <String>[];
      for (final File f in libDartFiles()) {
        final String p = _path(f);
        if (!_inNavFamily(p)) continue;
        final List<String> lines = stripped(f);
        for (int i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) offenders.add('$p:${i + 1}');
        }
      }
      expect(offenders, isEmpty, reason: 'seuil codé en dur : $offenders');
    });

    test('la garde de littéral MORD (contre-preuve sur une ligne fabriquée)', () {
      final RegExp literal = RegExp(r'(?<![\w.])600(\.0)?(?![\w.])');
      expect(literal.hasMatch('final wide = constraints.maxWidth >= 600;'), isTrue);
      expect(literal.hasMatch('final wide = w >= 600.0;'), isTrue);
      // Ne mord PAS sur un identifiant ou une décimale qui contient 600.
      expect(literal.hasMatch('const double k1600 = 1;'), isFalse);
      expect(literal.hasMatch('const double x = 1600;'), isFalse);
    });
  });
}
