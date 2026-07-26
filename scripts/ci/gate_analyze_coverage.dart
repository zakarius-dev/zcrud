// Gate : aucun répertoire portant un `pubspec.yaml` ne doit échapper à
// l'analyse statique.
//
// Trois faux-verts ont déjà eu la même cause : `melos exec` n'analyse que les
// membres du workspace. Les scripts puis `example/`, chacun hors workspace,
// ont donc survécu à un `melos run analyze` vert. Ce contrôle ferme la CLASSE :
// tout futur pubspec hors vue Melos doit être couvert explicitement, sinon le
// merge est rouge.
//
// Source de vérité des membres Melos : `workspace:` du pubspec racine. C'est
// plus fiable ici que `dart run melos list` : Melos le dérive lui-même, tandis
// que l'invocation d'un sous-processus dépend d'un état pub/toolchain valide et
// de son format de sortie. Le bloc `melos.scripts` du même manifeste est aussi
// l'autorité sous pub workspaces.
import 'dart:io';

import 'package:yaml/yaml.dart';

String _normaliser(String path) => path.replaceAll('\\', '/');

String _relatif(Directory root, FileSystemEntity entity) {
  final prefix = '${_normaliser(root.absolute.path)}/';
  final absolu = _normaliser(entity.absolute.path);
  return absolu.startsWith(prefix) ? absolu.substring(prefix.length) : absolu;
}

bool _estIgnore(String name) =>
    name == '.dart_tool' ||
    name == 'build' ||
    name == '.git' ||
    name == '.pub-cache' ||
    name == 'pub-cache';

Set<String> _pubspecsDecouverts(Directory root) {
  final trouves = <String>{};

  void visiter(Directory dossier) {
    for (final entree in dossier.listSync(followLinks: false)) {
      if (entree is! Directory) continue;
      final nom = entree.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (_estIgnore(nom)) continue;

      if (File('${entree.path}/pubspec.yaml').existsSync()) {
        trouves.add(_relatif(root, entree));
      }
      visiter(entree);
    }
  }

  // Le pubspec racine est le manifeste d'orchestration du workspace, pas un
  // package enfant à analyser. Tous les répertoires-paquets sont descendants.
  visiter(root);
  return trouves;
}

/// Répertoires réellement analysés par `analyze:packages` (`melos exec`).
///
/// 🔴 CE N'EST PAS `workspace:` TOUT SEUL — et la nuance est le défaut que ce
/// gate a lui-même laissé passer à sa première version. `melos exec` applique le
/// bloc `melos.ignore:` : un répertoire peut être membre du `workspace:` (donc
/// résolu par pub) tout en étant INVISIBLE de `melos list`, donc JAMAIS analysé.
///
/// MESURÉ sur `tool/reserved_keys_gate` : erreur de type réelle injectée
/// (`dart analyze` la voit), `melos run analyze` restait **RC=0** — et la
/// première version de ce gate le déclarait **couvert**. Un gate qui certifie
/// une couverture inexistante est pire qu'une absence de gate : il éteint la
/// vigilance. L'oracle doit être ce qui est RÉELLEMENT exécuté, pas ce qui est
/// déclaré à côté.
Set<String> _membresMelosAnalyses(YamlMap racine) {
  final workspace = racine['workspace'];
  if (workspace is! YamlList) return <String>{};
  final membres = workspace.whereType<String>().map(_normaliser).toSet();

  // `melos.ignore:` retire de la vue melos — donc de `melos exec`, donc de
  // `analyze:packages`. Les entrées sont des noms de paquet (ou des globs), pas
  // des chemins : on retire tout membre dont le dernier segment correspond.
  final melos = racine['melos'];
  final ignore = melos is YamlMap ? melos['ignore'] : null;
  if (ignore is YamlList) {
    final motifs = ignore.whereType<String>().toSet();
    membres.removeWhere((chemin) {
      final nom = chemin.split('/').last;
      return motifs.contains(nom) || motifs.contains(chemin);
    });
  }
  return membres;
}

Set<String> _cheminsExplicitementAnalyses(YamlMap racine) {
  final melos = racine['melos'];
  final scripts = melos is YamlMap ? melos['scripts'] : null;
  if (scripts is! YamlMap) return <String>{};

  final chemins = <String>{};
  for (final definition in scripts.values) {
    final run = definition is YamlMap ? definition['run'] : null;
    if (run is! String) continue;

    // Un script peut analyser plusieurs cibles (`dart analyze a b`). On ne
    // déduit aucune cible d'un texte de description : seul le `run` exécutable
    // vaut couverture.
    for (final match in RegExp(
      r'dart\s+analyze\s+([^&|;\n]+)',
    ).allMatches(run)) {
      final arguments = match.group(1)!.trim().split(RegExp(r'\s+'));
      for (final argument in arguments) {
        if (!argument.startsWith('-')) chemins.add(_normaliser(argument));
      }
    }
  }
  return chemins;
}

bool _estCouvertExplicitement(String pubspecDir, Set<String> cibles) {
  for (final cible in cibles) {
    if (cible == '.' || cible == pubspecDir) return true;
    if (pubspecDir.startsWith('$cible/')) return true;
  }
  return false;
}

void main() {
  final root = Directory.current;
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'gate:analyze-coverage ÉCHEC — pubspec.yaml racine introuvable.',
    );
    exit(1);
  }

  final yaml = loadYaml(pubspec.readAsStringSync());
  if (yaml is! YamlMap) {
    stderr.writeln(
      'gate:analyze-coverage ÉCHEC — pubspec.yaml racine illisible.',
    );
    exit(1);
  }

  final decouverts = _pubspecsDecouverts(root);
  if (decouverts.isEmpty) {
    stderr.writeln(
      'gate:analyze-coverage ÉCHEC — contrôle positif : aucun '
      'répertoire portant un pubspec.yaml n\'a été découvert.',
    );
    exit(1);
  }

  final membresMelos = _membresMelosAnalyses(yaml);
  final explicites = _cheminsExplicitementAnalyses(yaml);
  final nonCouverts =
      decouverts
          .where(
            (dir) =>
                !membresMelos.contains(dir) &&
                !_estCouvertExplicitement(dir, explicites),
          )
          .toList()
        ..sort();

  if (nonCouverts.isNotEmpty) {
    stderr.writeln(
      'gate:analyze-coverage VIOLATION — répertoire(s) avec '
      'pubspec.yaml hors vue Melos et hors analyse explicite :',
    );
    for (final dir in nonCouverts) {
      stderr.writeln('  - $dir');
    }
    stderr.writeln(
      '\nAjoutez le répertoire au bloc `workspace:` du pubspec '
      'racine, ou couvrez-le par un script Melos `run: dart analyze <chemin>`.',
    );
    exit(1);
  }

  stdout.writeln(
    'gate:analyze-coverage OK — ${decouverts.length} répertoire(s) '
    'portant un pubspec.yaml sont couverts (${membresMelos.length} workspace, '
    '${explicites.length} cible(s) explicite(s)).',
  );
}
