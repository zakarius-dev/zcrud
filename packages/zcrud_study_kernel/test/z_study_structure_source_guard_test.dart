@TestOn('vm')
library;

// Gardes de SOURCE sur la famille « structure d'étude ».
//
// 1. AUCUNE CHAÎNE DE CONTEXTE hors des préréglages. C'est la garde qui rend
//    la doctrine vérifiable : si un mot de contexte scolaire réapparaît dans
//    une entité, une primitive ou une constante, c'est qu'une décision du
//    noyau s'est mise à dépendre d'un contexte particulier — et le socle
//    cesse d'être universel. Le seul fichier autorisé à en porter est celui
//    des préréglages, qui est de la DONNÉE.
// 2. PURETÉ : rien de Flutter, rien de `dart:ui`, rien de `dart:io` sous
//    `structure/`. Le noyau est pur-Dart et ses tests tournent aussi bien sur
//    la VM que compilés vers Node.
//
// Ces gardes lisent le disque : d'où `@TestOn('vm')` — compilées vers Node,
// elles rougiraient pour une raison qui n'a rien à voir avec ce qu'elles
// mesurent.

import 'dart:io';

import 'package:test/test.dart';

/// Racine du paquet, ancrée sur `pubspec.yaml` plutôt que sur un `../`
/// relatif : la garde doit dire la même chose quel que soit le répertoire
/// courant du harnais.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/src/domain/structure').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'Racine du paquet zcrud_study_kernel introuvable depuis '
    '${Directory.current.path}',
  );
}

/// Le seul fichier autorisé à porter du vocabulaire de contexte.
const String _fichierPrereglages =
    'lib/src/domain/structure/z_study_ontology_presets.dart';

/// Jetons de contexte scolaire distinctifs, en minuscules.
///
/// Volontairement restreint aux mots qui ne peuvent pas apparaître pour une
/// autre raison : « classe » (mot du langage), « niveau » (profondeur) et
/// « parcours » (traversée) en sont donc EXCLUS — les inclure rendrait la
/// garde bruyante, et une garde bruyante finit désactivée.
const List<String> _jetonsDeContexte = <String>[
  'lycée',
  'lycee',
  'terminale',
  'filière',
  'filiere',
  'université',
  'universite',
  'licence',
  'doctorat',
  'promotion',
  'apprenant',
  'formateur',
  'élève',
  'eleve',
  'étudiant',
  'etudiant',
  'enseignant',
  'trimestre',
  'semestre',
  'anneescolaire',
  'annéescolaire',
  'école',
  'ecole',
  'etablissement',
  'établissement',
  'organisme',
  'presentiel',
  'présentiel',
  'distanciel',
  'alternance',
];

/// Sous-ensemble des jetons qui ne peuvent être QU'une valeur de `kind` — ils
/// n'apparaissent jamais dans de la prose française ordinaire. C'est le jeu
/// scanné sur tout `lib/`.
const List<String> _jetonsDeKindInstitutionnel = <String>[
  'lycée',
  'lycee',
  'terminale',
  'filière',
  'filiere',
  'université',
  'universite',
  'doctorat',
  'trimestre',
  'semestre',
  'anneescolaire',
  'annéescolaire',
  'etablissement',
  'établissement',
  'organisme',
  'presentiel',
  'présentiel',
  'distanciel',
];

List<File> _sourcesStructure(Directory root) =>
    Directory('${root.path}/lib/src/domain/structure')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

void main() {
  final root = _packageRoot();
  final sources = _sourcesStructure(root);

  group('Aucune chaîne de contexte hors des préréglages', () {
    test('la famille structure/ est bien scannée (garde non vacuante)', () {
      // Sans cette assertion, un chemin devenu faux rendrait la garde
      // silencieusement verte sur zéro fichier.
      expect(sources.length, greaterThanOrEqualTo(20));
      expect(
        sources.map((File f) => f.path.split('/').last),
        contains('z_study_ontology.dart'),
      );
    });

    test('le fichier de préréglages PORTE bien du vocabulaire de contexte',
        () {
      // Contre-épreuve : si le vocabulaire disparaissait des préréglages, la
      // garde ci-dessous deviendrait verte sans rien mesurer.
      final contenu =
          File('${root.path}/$_fichierPrereglages').readAsStringSync()
              .toLowerCase();
      final trouves = <String>[
        for (final jeton in _jetonsDeContexte)
          if (contenu.contains(jeton)) jeton,
      ];
      expect(
        trouves.length,
        greaterThanOrEqualTo(8),
        reason: 'les préréglages devraient porter le vocabulaire de contexte',
      );
    });

    test('aucun fichier de structure/ hors préréglages ne porte de jeton', () {
      final coupables = <String>[];
      for (final entry in sources) {
        final relatif = entry.path.substring(root.path.length + 1);
        if (relatif == _fichierPrereglages) continue;
        final contenu = entry.readAsStringSync().toLowerCase();
        for (final jeton in _jetonsDeContexte) {
          if (contenu.contains(jeton)) {
            coupables.add('$relatif → « $jeton »');
          }
        }
      }
      expect(
        coupables,
        isEmpty,
        reason:
            'vocabulaire de contexte hors des préréglages :\n'
            '${coupables.join('\n')}',
      );
    });

    test('aucun fichier de lib/ ne porte de LITTÉRAL de type institutionnel',
        () {
      // Portée élargie à tout `lib/`, restreinte aux jetons qui ne peuvent
      // être QUE des valeurs de `kind` — jamais de la prose. Les jetons de
      // prose (« apprenant », « enseignant »…) restent surveillés sur
      // `structure/` seulement : ailleurs dans le paquet, ils décrivent le
      // domaine sans rien décider.
      final coupables = <String>[];
      for (final entry in Directory('${root.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))) {
        final relatif = entry.path.substring(root.path.length + 1);
        if (relatif == _fichierPrereglages) continue;
        final contenu = entry.readAsStringSync().toLowerCase();
        for (final jeton in _jetonsDeKindInstitutionnel) {
          if (contenu.contains(jeton)) {
            coupables.add('$relatif → « $jeton »');
          }
        }
      }
      expect(
        coupables,
        isEmpty,
        reason:
            'littéral de type institutionnel hors des préréglages :\n'
            '${coupables.join('\n')}',
      );
    });
  });

  group('Pureté de la famille structure/', () {
    test('aucun import Flutter, `dart:ui` ou `dart:io`', () {
      final coupables = <String>[];
      for (final file in sources) {
        final contenu = file.readAsStringSync();
        for (final interdit in <String>[
          'package:flutter/',
          'dart:ui',
          'dart:io',
          'package:get/',
          'package:flutter_riverpod/',
          'package:provider/',
        ]) {
          if (contenu.contains(interdit)) {
            coupables.add('${file.path.split('/').last} → $interdit');
          }
        }
      }
      expect(coupables, isEmpty, reason: coupables.join('\n'));
    });

    test('aucun octet de contrôle brut dans les sources', () {
      // Un octet de contrôle dans un littéral est invisible à l'analyseur et
      // rend `grep` sans `-a` aveugle : il doit être refusé à la source.
      final coupables = <String>[];
      for (final file in sources) {
        final octets = file.readAsBytesSync();
        for (final octet in octets) {
          final estControle =
              octet < 0x20 && octet != 0x09 && octet != 0x0a && octet != 0x0d;
          if (estControle) {
            coupables.add('${file.path.split('/').last} → octet 0x'
                '${octet.toRadixString(16).padLeft(2, '0')}');
            break;
          }
        }
      }
      expect(coupables, isEmpty, reason: coupables.join('\n'));
    });
  });
}
