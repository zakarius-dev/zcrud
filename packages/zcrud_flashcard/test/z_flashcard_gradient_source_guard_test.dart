/// G2 VIS-3 : garde de structure contre palettes et mappings locaux.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'G2 — aucune palette/mapping de type local ne contourne le resolver',
    () {
      final root = Directory('lib');
      final source = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(
        RegExp(r'(?:Map\s*)?<\s*ZFlashcardType\s*,').hasMatch(source),
        isFalse,
      );
      expect(
        RegExp(r'(?:Map\s*)?<\s*QuestionType\s*,').hasMatch(source),
        isFalse,
      );
      expect(RegExp(r'Color\s*\(\s*0x').hasMatch(source), isFalse);
      expect(RegExp(r'Colors\.').hasMatch(source), isFalse);
      expect(
        RegExp(r'zResolveGradient\s*\(').allMatches(source),
        hasLength(1),
        reason: 'une seule voie package doit atteindre le resolver hôte',
      );
    },
  );
}
