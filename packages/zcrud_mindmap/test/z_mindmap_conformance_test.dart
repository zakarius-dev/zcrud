/// Tests de conformité statique du code de présentation E10-2.
///
/// Gardes grep (déterministes) sur les fichiers `lib/src/presentation/**` :
/// - AD-13 : AUCUNE API non-directionnelle (`EdgeInsets.only(left/right)`,
///   `Alignment.centerLeft/Right`, `Positioned(left/right)`, `TextAlign.left/right`).
/// - AD-2/AD-15 : AUCUN gestionnaire d'état tiers (`flutter_riverpod`, `get`,
///   `provider`) ni `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show stripSource;

/// Résout le dossier `lib/src/presentation` que le test soit lancé depuis la
/// racine du workspace (`flutter test packages/zcrud_mindmap`) ou depuis le
/// package lui-même (`flutter test`).
Directory _presentationDir() {
  const candidates = <String>[
    'lib/src/presentation',
    'packages/zcrud_mindmap/lib/src/presentation',
  ];
  for (final c in candidates) {
    final dir = Directory(c);
    if (dir.existsSync()) return dir;
  }
  return Directory(candidates.first);
}

List<File> _presentationSources() {
  final dir = _presentationDir();
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Retire les commentaires (doc `///`, ligne `//`, bloc `/* */`) pour que la
/// garde n'analyse que le **code réel** — les docstrings citent volontairement
/// les API interdites pour documenter leur bannissement.
///
/// Déléguée à `test/support/z_sources.dart` (P0D1) : cette fonction dupliquait
/// une passe bloc-avant-ligne par `RegExp` global, ordre documenté comme
/// dangereux (une dartdoc citant `/*` littéralement pouvait avaler du CODE
/// réel jusqu'au `*/` suivant). `stripSource` fait le même travail dans le
/// bon ordre, caractère par caractère.
String _stripComments(String source) => stripSource(source);

void main() {
  final sources = _presentationSources();

  test('des fichiers de présentation existent', () {
    expect(sources, isNotEmpty);
  });

  group('AD-13 — aucune API de layout non-directionnelle', () {
    // Motifs interdits (variantes directionnelles obligatoires).
    const forbidden = <String>[
      'Alignment.centerLeft',
      'Alignment.centerRight',
      'Alignment.topLeft',
      'Alignment.topRight',
      'Alignment.bottomLeft',
      'Alignment.bottomRight',
      'TextAlign.left',
      'TextAlign.right',
      'EdgeInsets.only(left:',
      'EdgeInsets.only(right:',
      'EdgeInsets.only( left:',
      'EdgeInsets.only( right:',
    ];

    for (final file in sources) {
      test('${file.path} — pas d\'API non-directionnelle', () {
        final content = _stripComments(file.readAsStringSync());
        for (final pattern in forbidden) {
          expect(
            content.contains(pattern),
            isFalse,
            reason: 'Motif non-directionnel interdit "$pattern" dans ${file.path}',
          );
        }
        // Positioned(...) avec left:/right: littéral (RegExp tolérante).
        expect(
          RegExp(r'Positioned\([^)]*\bleft:').hasMatch(content),
          isFalse,
          reason: 'Positioned(left:) interdit dans ${file.path}',
        );
        expect(
          RegExp(r'Positioned\([^)]*\bright:').hasMatch(content),
          isFalse,
          reason: 'Positioned(right:) interdit dans ${file.path}',
        );
      });
    }
  });

  group('AD-2/AD-15 — aucun gestionnaire d\'état tiers', () {
    const forbidden = <String>[
      'package:flutter_riverpod',
      'package:riverpod',
      'package:get/',
      'package:provider',
      'WidgetRef',
      'ConsumerWidget',
      'Get.find',
      'Get.put',
      'Provider.of',
    ];

    for (final file in sources) {
      test('${file.path} — pas de dépendance à un manager d\'état', () {
        final content = _stripComments(file.readAsStringSync());
        for (final pattern in forbidden) {
          expect(
            content.contains(pattern),
            isFalse,
            reason: 'Référence interdite "$pattern" dans ${file.path}',
          );
        }
      });
    }
  });
}
