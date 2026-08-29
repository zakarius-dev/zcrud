@TestOn('vm')
// Lot P1-D — FR-26 : le vocabulaire de STYLE et d'OPÉRATION appartient à
// l'HÔTE. Ce paquet n'en déclare aucune valeur, ne compare rien à une valeur
// connue, et n'affiche aucun libellé en dur.
//
// Garde de SOURCE (`dart:io`) ⇒ `@TestOn('vm')` obligatoire : le gate
// `web-determinism` compile ce fichier vers Node sans lui.
//
// Le scan porte sur la source DÉPOUILLÉE de ses commentaires : une dartdoc qui
// écrit le mot « humour » en français n'est pas une clé codée en dur ; un
// littéral Dart, si.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Les dix styles de la page d'explication historique, recensés chez l'hôte.
/// Aucun ne doit exister comme valeur dans ce paquet : ce sont des clés que
/// l'application passe, pas une énumération du socle.
const List<String> _legacyStyleKeys = <String>[
  'exampes',
  'poemes',
  'history',
  'humor',
  'didactique',
  'technique',
  'creatif',
  'analytique',
  'inspirational',
  'classroom',
];

/// Les quatre traitements de la même page. Idem : des clés de l'hôte.
const List<String> _legacyOperationKeys = <String>[
  'summarizeExplanation',
  'regenerateExplanation',
  'elaborateExplanation',
  'explainSubjectWithStyle',
];

/// Extrait les littéraux de chaîne d'une source déjà dépouillée.
List<String> _stringLiterals(String source) {
  final matches = RegExp("'([^'\\n]*)'|\"([^\"\\n]*)\"").allMatches(source);
  return <String>[
    for (final m in matches) m.group(1) ?? m.group(2) ?? '',
  ];
}

void main() {
  test('aucun nom de style ni d\'opération de l\'hôte n\'est un littéral de '
      'lib/', () {
    final files = libDartFiles();
    expect(files.length, greaterThan(10),
        reason: 'scan VACUEL : aucun fichier lu');

    final violations = <String>[];
    for (final File file in files) {
      final literals = _stringLiterals(strippedText(file));
      for (final String literal in literals) {
        final lowered = literal.toLowerCase();
        for (final String key in <String>[
          ..._legacyStyleKeys,
          ..._legacyOperationKeys,
        ]) {
          if (lowered == key.toLowerCase()) {
            violations.add('${file.path} : littéral "$literal" == clé "$key"');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'FR-26 : une clé de style ou d\'opération de l\'hôte est '
            'codée en dur dans le socle :\n${violations.join('\n')}');
  });

  test('les surfaces d\'explication ne COMPARENT aucune clé à une valeur '
      'connue', () {
    // Une comparaison littérale (`operation == '…'`) serait une interprétation
    // du vocabulaire de l'hôte — exactement ce que le contrat interdit. Le
    // socle transporte, il ne juge pas.
    for (final String path in <String>[
      'lib/src/domain/z_ai_explanation_port.dart',
      'lib/src/domain/z_ai_explanation_stream_port.dart',
      'lib/src/presentation/z_explanation_controller.dart',
      'lib/src/presentation/z_explanation_view.dart',
    ]) {
      final String source = strippedOf(path);
      expect(
        RegExp(r'''(style|operation|styleKey)\s*==\s*['"]''').hasMatch(source),
        isFalse,
        reason: '$path compare une clé opaque à un littéral',
      );
      expect(
        RegExp(r'''switch\s*\(\s*(style|operation)\b''').hasMatch(source),
        isFalse,
        reason: '$path aiguille sur une clé opaque',
      );
    }
  });

  test('le port progressif reste PUR : aucune dépendance Flutter ni de '
      'transport dans le domaine', () {
    final String source =
        File('${packageRoot().path}/lib/src/domain/z_ai_explanation_stream_port.dart')
            .readAsStringSync();
    for (final String banned in <String>[
      'package:flutter/',
      'package:http/',
      'dart:io',
      'dart:html',
    ]) {
      expect(source.contains(banned), isFalse,
          reason: 'le seam progressif importe $banned');
    }
    // Le contrat est bien un FLUX NU, pas un `Future<Stream<…>>`.
    final String strippedSource =
        strippedOf('lib/src/domain/z_ai_explanation_stream_port.dart');
    expect(strippedSource.contains('Stream<ZResult<ZGenerationProgress>>'),
        isTrue);
    expect(
      RegExp(r'Future<\s*Stream').hasMatch(strippedSource),
      isFalse,
      reason: 'un flux enveloppé dans un Future n\'est plus un flux nu',
    );
  });
}
