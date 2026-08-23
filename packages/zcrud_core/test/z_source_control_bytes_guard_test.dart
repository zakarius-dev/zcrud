@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

// Octets de contrôle TOLÉRÉS dans une source Dart : tabulation, saut de
// ligne, retour chariot. Tout le reste sous 0x20 (y compris NUL) est un
// octet de contrôle brut qui n'a rien à faire dans un littéral Dart — un
// éditeur/outil qui l'introduit (copier-coller depuis un binaire, séparateur
// NUL) rend `grep` (sans -a) et `git diff` aveugles au fichier, et peut
// corrompre la doc générée.
const Set<int> _kAllowedControlBytes = <int>{0x09, 0x0A, 0x0D};

/// Racine du dépôt, quel que soit le CWD (racine du workspace ou package).
///
/// Ancrage par remontée jusqu'à `melos.yaml` — jamais un `../` relatif : la
/// convention `melos exec` lance chaque suite depuis le dossier de SON
/// package.
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Tous les `.dart` de `packages/*/lib` et `packages/*/test`.
///
/// Aucune exclusion de `*.g.dart` / `*.freezed.dart` : un balayage mesuré sur
/// le dépôt (2026-08-23) ne montre aucun octet de contrôle brut légitime
/// dans ces fichiers générés — les exclure serait donc un trou non prouvé.
List<File> _packageSourceDartFiles() {
  final Directory packages = Directory('${_repoRoot().path}/packages');
  expect(packages.existsSync(), isTrue, reason: 'packages/ introuvable');
  final List<File> files = <File>[];
  for (final Directory pkg
      in packages.listSync().whereType<Directory>()) {
    for (final String sub in <String>['lib', 'test']) {
      final Directory dir = Directory('${pkg.path}/$sub');
      if (!dir.existsSync()) continue;
      files.addAll(
        dir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart')),
      );
    }
  }
  return files;
}

/// Un octet de contrôle brut repéré dans un flux d'octets.
class ControlByteHit {
  const ControlByteHit({required this.line, required this.byte});

  /// Ligne 1-based (comptée en octets `\n`, cohérente avec un fichier lu en
  /// octets).
  final int line;

  /// Valeur de l'octet fautif (ex. `0x00` pour NUL).
  final int byte;
}

/// Fonction de scan PURE, testable sur des octets sans toucher au disque —
/// c'est elle que la contre-preuve exerce directement.
///
/// Volontairement en octets, jamais en `String` : un décodage UTF-8 en amont
/// masquerait justement le défaut visé (NUL est un octet UTF-8 valide, un
/// `grep` sans `-a` le voit comme binaire et rend une sortie vide sans
/// erreur — faux constat d'absence).
List<ControlByteHit> scanControlBytes(List<int> bytes) {
  final List<ControlByteHit> hits = <ControlByteHit>[];
  int line = 1;
  for (final int b in bytes) {
    if (b < 0x20 && !_kAllowedControlBytes.contains(b)) {
      hits.add(ControlByteHit(line: line, byte: b));
    }
    if (b == 0x0A) line++;
  }
  return hits;
}

void main() {
  group('scanControlBytes — contre-preuve sur octets fabriqués', () {
    test('un contenu propre ne rend aucun hit', () {
      final List<int> clean = "class A {\n  final x = 'y';\r\n}\t\n".codeUnits;
      expect(scanControlBytes(clean), isEmpty);
    });

    test('un NUL injecté en mémoire est détecté avec sa ligne', () {
      // "line1\nline2<NUL>line2b\nline3" — le NUL est sur la 2e ligne.
      final List<int> withNul = <int>[
        ...'line1\nline2'.codeUnits,
        0x00,
        ...'line2b\nline3'.codeUnits,
      ];
      final List<ControlByteHit> hits = scanControlBytes(withNul);
      expect(hits, hasLength(1));
      expect(hits.single.byte, 0x00);
      expect(hits.single.line, 2);
    });

    test('tabulation / LF / CR seuls restent tolérés', () {
      final List<int> ok = <int>[0x09, 0x0A, 0x0D, ..._letterA()];
      expect(scanControlBytes(ok), isEmpty);
    });
  });

  group('aucun octet de contrôle brut dans packages/*/{lib,test}', () {
    late List<File> files;

    setUpAll(() => files = _packageSourceDartFiles());

    test('la garde n\'est pas VACUELLE : elle voit bien des fichiers', () {
      expect(
        files.length,
        greaterThanOrEqualTo(200),
        reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) balayé(s) '
            'dans packages/*/{lib,test} — un balayage quasi vide signale un '
            'chemin cassé.',
      );
    });

    test('🔴 aucun `.dart` ne porte un octet de contrôle brut (NUL en '
        'premier lieu)', () {
      final List<String> offenders = <String>[];
      for (final File f in files) {
        final List<int> bytes = f.readAsBytesSync();
        for (final ControlByteHit hit in scanControlBytes(bytes)) {
          offenders.add(
            '${f.path.split('/packages/').last}:${hit.line}:'
            '0x${hit.byte.toRadixString(16).padLeft(2, '0')}',
          );
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 Octet(s) de contrôle brut dans un littéral/dartdoc Dart. '
            'Dart accepte, l\'analyseur se tait, mais `grep` sans `-a` '
            'déclare le fichier binaire et rend une sortie vide SANS erreur '
            '(faux constat d\'absence), `git diff` affiche « Binary files '
            'differ », et la doc générée peut s\'en trouver corrompue. '
            'Remplacer par l\'échappement `\\uXXXX` correspondant.\n'
            'Fichiers fautifs :\n  ${offenders.join('\n  ')}',
      );
    });
  });
}

List<int> _letterA() => 'A'.codeUnits;
