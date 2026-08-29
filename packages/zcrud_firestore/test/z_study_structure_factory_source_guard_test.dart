@TestOn('vm')
library;

// Garde de SOURCE : la fabrique des dépôts de structure ne doit porter AUCUNE
// ligne de (dé)sérialisation spécifique.
//
// Ce qu'elle mesure, sur le fichier réel :
// 1. aucun NOM DE CHAMP persisté d'une entité de structure n'y apparaît — les
//    noms de champs sont LUS dans les `ZFieldSpec` du noyau, jamais listés ici
//    (une garde qui listerait elle-même `parent_id`, `subject_id`… hériterait
//    de l'angle mort de son auteur : le champ oublié ne serait pas surveillé) ;
// 2. aucune VALEUR DE KIND (`study_*`) n'y est écrite en dur — le `kind` est
//    résolu par le registre ;
// 3. aucun appel de (dé)sérialisation d'entité (`fromMap`/`toMap`).
//
// Sans cette garde, la fabrique pourrait dériver vers un adaptateur par
// entité : le défaut serait PASSIF (tout resterait vert) et ne se paierait
// qu'à la première évolution du schéma du noyau.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Remonte jusqu'au dossier du paquet (celui qui porte `pubspec.yaml`).
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('pubspec.yaml introuvable depuis ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

/// Registre des vingt-trois entités de structure — source de vérité des noms
/// de champs et des kinds surveillés.
final ZcrudRegistry _registry = buildStudyStructureRegistry();

/// Schéma déclaratif de [kind], tel que le registrar du noyau l'a posé.
List<ZFieldSpec> _fieldSpecsOf(String kind) =>
    _registry.fieldSpecsFor(kind);

/// Tous les kinds de structure, lus dans le registre.
List<String> get _kinds => <String>[
      _registry.kindOf<ZStudyWorkspace>()!,
      _registry.kindOf<ZStudyPrincipal>()!,
      _registry.kindOf<ZStudyOrganization>()!,
      _registry.kindOf<ZStudyOrgUnit>()!,
      _registry.kindOf<ZStudyProgram>()!,
      _registry.kindOf<ZStudyGroup>()!,
      _registry.kindOf<ZStudyClassification>()!,
      _registry.kindOf<ZStudySubject>()!,
      _registry.kindOf<ZStudyCourse>()!,
      _registry.kindOf<ZStudyProgramCourse>()!,
      _registry.kindOf<ZStudyCalendar>()!,
      _registry.kindOf<ZStudyPeriod>()!,
      _registry.kindOf<ZStudySession>()!,
      _registry.kindOf<ZStudyOffering>()!,
      _registry.kindOf<ZStudyOfferingAudience>()!,
      _registry.kindOf<ZStudyParticipation>()!,
      _registry.kindOf<ZStudyCurriculum>()!,
      _registry.kindOf<ZStudyTopic>()!,
      _registry.kindOf<ZStudyCompetency>()!,
      _registry.kindOf<ZStudyCompetencyFramework>()!,
      _registry.kindOf<ZStudyExplanation>()!,
      _registry.kindOf<ZStudyRoleBinding>()!,
      _registry.kindOf<ZStudyShareGrant>()!,
    ];

void main() {
  final File source = File(
    '${_packageRoot().path}/lib/src/data/'
    'z_study_structure_firestore_repositories.dart',
  );

  setUpAll(() {
    expect(
      source.existsSync(),
      isTrue,
      reason: 'garde MAL ANCRÉE si le fichier surveillé n\'existe pas : '
          '${source.path}',
    );
  });

  /// Le corps du fichier, commentaires et dartdoc RETIRÉS : la garde porte sur
  /// le code, pas sur la prose qui l'explique.
  List<String> codeLines() => source
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('//'))
      .toList();

  test('la garde surveille bien 23 kinds et un schéma non vide', () {
    // Sujet monté : sans cela, les deux gardes suivantes seraient vertes par
    // vacuité (aucun motif à chercher).
    expect(_kinds, hasLength(23));
    expect(_kinds.toSet(), hasLength(23));
    final List<String> fields = <String>[
      for (final String kind in _kinds)
        ..._fieldSpecsOf(kind).map((ZFieldSpec s) => s.name),
    ];
    expect(fields.length, greaterThan(100), reason: 'schéma réel non vide');
  });

  test('AUCUN nom de champ persisté du noyau n\'apparaît dans la fabrique', () {
    final Set<String> fields = <String>{
      for (final String kind in _kinds)
        ..._fieldSpecsOf(kind).map((ZFieldSpec s) => s.name),
    }
      // `id` est le nom de l'identité, pas un champ métier : il est structurel
      // et le mot apparaît légitimement dans du code générique (`kind`, `id`).
      ..remove('id');

    final List<String> hits = <String>[];
    for (final String line in codeLines()) {
      for (final String field in fields) {
        if (line.contains("'$field'") || line.contains('"$field"')) {
          hits.add('$field → $line');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'la fabrique doit être GÉNÉRIQUE : un nom de champ écrit ici '
          'est une ligne de (dé)sérialisation spécifique.',
    );
  });

  test('AUCUNE valeur de kind n\'est écrite en dur dans la fabrique', () {
    final List<String> hits = <String>[
      for (final String line in codeLines())
        for (final String kind in _kinds)
          if (line.contains("'$kind'") || line.contains('"$kind"'))
            '$kind → $line',
    ];
    expect(
      hits,
      isEmpty,
      reason: 'le kind se résout par le registre (kindOf), jamais en dur.',
    );
  });

  test('AUCUN appel de (dé)sérialisation d\'entité dans la fabrique', () {
    final List<String> hits = <String>[
      for (final String line in codeLines())
        if (line.contains('.fromMap(') ||
            line.contains('.toMap(') ||
            line.contains('fromMapSafe:'))
          line,
    ];
    expect(hits, isEmpty);
  });
}
