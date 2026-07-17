/// AC2 — garde de source **anti-dépendance** : `flip_card` est **INTERDITE**
/// (SU-2, FR-SU1 / AD-1).
///
/// Le flip 3D est **MAISON** (`Matrix4` + `rotateY`). Le PRD porte une
/// contre-métrique explicite : *aucune nouvelle dépendance tierce au-delà des
/// trois décidées*. Une garde de prose ne tient pas une telle règle — celle-ci la
/// tient sur le **disque**.
///
/// ⚠️ **Scan par DÉCLARATION, jamais ligne-à-ligne** (leçon **D4** du
/// code-review de su-1) : une dépendance peut parfaitement s'écrire
///
/// ```yaml
/// dependencies:
///   flip_card:
///     git:
///       url: https://example.invalid/flip_card.git
/// ```
///
/// — forme où **aucune ligne** ne contient `flip_card: ^…`. Un scan ligne-à-ligne
/// cherchant `flip_card:` la verrait ici par chance, mais ne saurait pas
/// distinguer une **déclaration de dépendance** d'une simple mention ; il
/// crierait au loup sur un commentaire et finirait désarmé. Ce scanner résout
/// donc la **section** (`dependencies`/`dev_dependencies`/`dependency_overrides`)
/// et le **nom** de la dépendance, en recollant son bloc indenté.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sections d'un `pubspec.yaml` qui déclarent de vraies dépendances.
const Set<String> _dependencySections = <String>{
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
};

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Rend une violation par **déclaration de dépendance** dont le nom vaut
/// [banned], quelle que soit sa forme (`^1.0.0`, `git:`, `path:`, bloc indenté
/// multi-lignes). Les commentaires sont ignorés : la prose DOIT pouvoir nommer
/// `flip_card` pour expliquer l'interdiction.
///
/// Exercé À LA FOIS par la garde (sur les `pubspec.yaml` réels) et par ses
/// contre-preuves : sans ce partage, une contre-preuve ne prouverait que le
/// pouvoir des MOTIFS, jamais celui du SCANNER (leçon **D6**).
List<String> scanForBannedDependency(
  List<String> lines,
  String path, {
  required String banned,
}) {
  final violations = <String>[];
  final buffer = StringBuffer();
  String? section;
  var depName = '';
  var depStart = 0;
  var depSection = '';

  void flush() {
    final declaration = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    buffer.clear();
    final name = depName;
    depName = '';
    if (name.isEmpty) return;
    if (name != banned) return;
    violations.add(
      '$path:$depStart → dépendance « $banned » déclarée dans '
      '`$depSection` : « $declaration »',
    );
  }

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trimLeft().startsWith('#')) continue; // prose libre
    // Commentaire de fin de ligne (jamais dans une URL : ` #` exige l'espace).
    final hashIndex = raw.indexOf(' #');
    final code = hashIndex >= 0 ? raw.substring(0, hashIndex) : raw;
    if (code.trim().isEmpty) continue;

    final indent = code.length - code.trimLeft().length;
    final trimmed = code.trim();

    if (indent == 0) {
      flush(); // clôt la dépendance en cours AVANT de changer de section
      final key = trimmed.split(':').first.trim();
      section = _dependencySections.contains(key) ? key : null;
      continue;
    }
    if (section == null) continue;

    if (indent <= 2) {
      // Nouvelle déclaration de dépendance (`  nom: …`).
      flush();
      depName = trimmed.split(':').first.trim();
      depStart = i + 1;
      depSection = section;
      buffer
        ..write(' ')
        ..write(trimmed);
    } else {
      // Ligne de continuation du bloc indenté (`git:`, `url:`, `path:`…).
      buffer
        ..write(' ')
        ..write(trimmed);
    }
  }
  flush();
  return violations;
}

/// Racine du dépôt (remonte jusqu'au `melos.yaml`).
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  fail('racine du dépôt introuvable (cwd = ${Directory.current.path})');
}

void main() {
  test(
    'AC2 — AUCUN pubspec.yaml du dépôt ne déclare `flip_card` (le flip 3D est '
    'MAISON — FR-SU1)',
    () {
      // Le scan part de la RACINE (et non de `packages/`) : il couvre ainsi le
      // pubspec racine et celui d'`example/`, que la version précédente
      // ignorait — or `flip_card` déclarée à la racine ou dans l'exemple serait
      // tout aussi interdite, et la garde ne l'aurait jamais vue.
      final root = _repoRoot();
      final pubspecs = root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('pubspec.yaml'))
          // Artefacts d'outillage : ce ne sont pas des déclarations du dépôt.
          .where((f) =>
              !f.path.contains('/.dart_tool/') &&
              !f.path.contains('/build/') &&
              !f.path.contains('/.git/'))
          .toList();

      // Contre-preuve R12 : le scan DOIT voir des fichiers — sinon la garde
      // serait morte (faux vert éternel).
      expect(pubspecs, isNotEmpty, reason: 'aucun pubspec scanné — garde morte');
      expect(
        pubspecs.any((f) => f.path.contains('zcrud_flashcard')),
        isTrue,
        reason: 'le pubspec de zcrud_flashcard n\'a pas été vu par le scan',
      );
      // Les deux pubspecs que le scan `packages/` manquait structurellement.
      expect(
        pubspecs.any((f) => f.path == '${root.path}/pubspec.yaml'),
        isTrue,
        reason: 'le pubspec RACINE n\'est pas scanné : une dépendance interdite '
            'y passerait inaperçue',
      );
      expect(
        pubspecs.any((f) => f.path == '${root.path}/example/pubspec.yaml'),
        isTrue,
        reason: 'le pubspec d\'`example/` n\'est pas scanné : une dépendance '
            'interdite y passerait inaperçue',
      );

      final violations = <String>[];
      for (final pubspec in pubspecs) {
        violations.addAll(
          scanForBannedDependency(
            pubspec.readAsLinesSync(),
            pubspec.path,
            banned: 'flip_card',
          ),
        );
      }

      expect(
        violations,
        isEmpty,
        reason: 'DÉPENDANCE INTERDITE : le flip 3D doit rester MAISON '
            '(Matrix4 + rotateY). Le PRD interdit toute dépendance tierce '
            'au-delà des trois décidées :\n${violations.join('\n')}',
      );
    },
  );

  test(
    'CONTRE-PREUVE R12 — le SCANNER RÉEL voit bien les dépendances réelles '
    '(exercé sur le pubspec RÉEL, avec une dépendance RÉELLEMENT présente)',
    () {
      // Prouve que le vert ci-dessus vient de l'ABSENCE de `flip_card`, et non
      // d'un scanner aveugle : la MÊME fonction, sur le MÊME fichier, DOIT
      // trouver une dépendance dont on sait qu'elle existe.
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue);

      final found = scanForBannedDependency(
        pubspec.readAsLinesSync(),
        pubspec.path,
        banned: 'zcrud_markdown',
      );

      expect(found, isNotEmpty,
          reason: 'le scanner ne voit AUCUNE dépendance dans un pubspec qui en '
              'contient : il est aveugle, donc le test principal ne prouve RIEN');
    },
  );

  test(
    'POUVOIR SUR LE CAS PIÈGE — le scanner détecte `flip_card` déclarée en '
    'bloc MULTI-LIGNES (`git:`), la forme qu\'un scan naïf manque',
    () {
      const injected = <String>[
        'name: zcrud_flashcard',
        'dependencies:',
        '  flutter:',
        '    sdk: flutter',
        '  flip_card:',
        '    git:',
        '      url: https://example.invalid/flip_card.git',
        '      ref: main',
      ];

      final violations =
          scanForBannedDependency(injected, 'artificiel.yaml', banned: 'flip_card');

      expect(violations, hasLength(1),
          reason: 'dépendance interdite en bloc multi-lignes NON détectée');
      expect(violations.single, startsWith('artificiel.yaml:5'),
          reason: 'la violation doit pointer la ligne d\'OUVERTURE du bloc');
      expect(violations.single, contains('git:'),
          reason: 'le bloc indenté doit être recollé à sa déclaration');
    },
  );

  test('POUVOIR — le scanner détecte aussi la forme courte `flip_card: ^1.0.0`',
      () {
    const injected = <String>[
      'dev_dependencies:',
      '  flip_card: ^1.0.0',
    ];

    final violations =
        scanForBannedDependency(injected, 'artificiel.yaml', banned: 'flip_card');

    expect(violations, hasLength(1));
    expect(violations.single, contains('dev_dependencies'));
  });

  test(
    'PAS DE FAUX POSITIF — une MENTION de flip_card (commentaire, nom de '
    'paquet voisin, hors section) ne déclenche RIEN',
    () {
      // Anti-sur-blocage : une garde qui crie au loup finit désarmée. La prose
      // doit rester libre de NOMMER l'interdiction pour l'expliquer.
      const injected = <String>[
        '# flip_card est INTERDITE : le flip 3D est maison (FR-SU1).',
        'name: flip_card_demo',
        'description: Ne dépend pas de flip_card. # flip_card',
        'dependencies:',
        '  flutter:',
        '    sdk: flutter',
        '  flip_card_helper: ^2.0.0',
        'flutter:',
        '  uses-material-design: true',
      ];

      final violations =
          scanForBannedDependency(injected, 'artificiel.yaml', banned: 'flip_card');

      expect(violations, isEmpty,
          reason: 'faux positif : seule une DÉCLARATION de dépendance nommée '
              'exactement `flip_card` doit être signalée — pas une mention, '
              'pas `flip_card_helper`, pas le `name:` du paquet');
    },
  );
}
