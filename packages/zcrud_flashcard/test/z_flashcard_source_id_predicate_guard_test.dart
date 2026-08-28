@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' as zsrc;

const String _canonicalPredicate = 'zMatchesSourceId';

final RegExp _directSourceIdComparison = RegExp(
  r'\b(?:sourceIds?|sourceTypes?|noteId|messageId|documentId)\b'
  r'\s*(?:==|!=)'
  r'|(?:==|!=)\s*[^&|,;{}\n]{0,80}'
  r'\b(?:sourceIds?|sourceTypes?|noteId|messageId|documentId)\b'
  r'|\b(?:sourceIds?|sourceTypes?|noteId|messageId|documentId)\b'
  r'\s*\.\s*contains\s*\(',
  multiLine: true,
);

/// Retire le corps du prédicat canonique tout en préservant les numéros de
/// ligne. Une absence du prédicat fait échouer la garde au lieu de produire un
/// faux vert.
List<String> _withoutCanonicalPredicate(File file) {
  final lines = zsrc.strippedLines(file);
  if (!file.path.endsWith('z_flashcard_filters.dart')) return lines;

  var inPredicate = false;
  var braceDepth = 0;
  var predicateFound = false;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (!inPredicate &&
        RegExp(r'\bbool\s+zMatchesSourceId\s*\(').hasMatch(line)) {
      inPredicate = true;
      predicateFound = true;
    }
    if (!inPredicate) continue;

    braceDepth += '{'.allMatches(line).length;
    braceDepth -= '}'.allMatches(line).length;
    lines[index] = '';
    if (braceDepth == 0) inPredicate = false;
  }

  expect(
    predicateFound,
    isTrue,
    reason: '$_canonicalPredicate introuvable : garde d\'unicité vacuelle',
  );
  return lines;
}

bool _isStructuralSourceEquality(File file, String line) {
  if (!file.path.endsWith('z_flashcard_source.dart')) return false;
  final normalized = line.replaceAll(RegExp(r'\s+'), ' ');
  return RegExp(
        r'\b(?:noteId|messageId|documentId)\s*==\s*'
        r'other\.(?:noteId|messageId|documentId)\b',
      ).hasMatch(normalized) &&
      !RegExp(r'\b(?:sourceIds?|sourceTypes?)\b').hasMatch(normalized);
}

List<String> _directComparisonsOutsidePredicate() {
  final violations = <String>[];
  for (final file in zsrc.libDartFiles()) {
    final source = _withoutCanonicalPredicate(file).join('\n');
    for (final match in _directSourceIdComparison.allMatches(source)) {
      final snippet = match.group(0)!.trim();
      final lineStart = source.lastIndexOf('\n', match.start) + 1;
      final nextNewline = source.indexOf('\n', match.end);
      final lineEnd = nextNewline == -1 ? source.length : nextNewline;
      if (_isStructuralSourceEquality(
        file,
        source.substring(lineStart, lineEnd),
      )) {
        continue;
      }
      final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
      violations.add(
        '${file.path}:$line → comparaison directe hors '
        '$_canonicalPredicate : ${snippet.replaceAll(RegExp(r'\s+'), ' ')}',
      );
    }
  }
  return violations;
}

void main() {
  test(
    'sourceId — zMatchesSourceId reste l’unique prédicat de comparaison',
    () {
      final violations = _directComparisonsOutsidePredicate();

      expect(
        violations,
        isEmpty,
        reason:
            'Toute comparaison applicative de sourceId/sourceType doit passer '
            'par $_canonicalPredicate. Les égalités structurelles des value '
            'objects source restent autorisées :\n${violations.join('\n')}',
      );
    },
  );
}
