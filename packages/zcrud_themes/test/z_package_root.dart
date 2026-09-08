library;

import 'dart:io';

/// Racine du paquet, ancrée par REMONTÉE jusqu'au dossier portant `melos.yaml`.
///
/// Jamais un `../` relatif : `flutter test` résout le répertoire courant
/// différemment selon l'endroit d'où il est lancé, et une garde qui s'ancre
/// relativement lit alors un dossier qui n'est pas le sien.
Directory zThemesPackageRoot() =>
    Directory('${zMonorepoRoot().path}/packages/zcrud_themes');

/// Racine du MONOREPO — le dossier qui porte `melos.yaml`.
///
/// Même ancrage par remontée que [zThemesPackageRoot], exposé à part pour les
/// gardes qui doivent LIRE la source d'un autre paquet (jamais l'écrire) sans
/// ouvrir d'arête de dépendance vers lui.
Directory zMonorepoRoot() {
  Directory dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
          'melos.yaml introuvable au-dessus de ${Directory.current}');
    }
    dir = parent;
  }
}

/// Tous les fichiers `.dart` de `lib/` du paquet.
List<File> zThemesLibSources() {
  final Directory lib = Directory('${zThemesPackageRoot().path}/lib');
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
}
