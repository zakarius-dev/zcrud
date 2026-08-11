/// G2 VIS-3 : garde de structure contre palettes et mappings locaux.
///
/// 🔴 Scan sur source STRIPPÉE (`support/z_sources.dart`) : une dartdoc citant
/// `Colors.red`, un mapping `<ZFlashcardType, …>` ou `zResolveGradient(` ne
/// doit ni faire rougir la garde, ni fausser le comptage « une seule voie vers
/// le resolver ».
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' as zsrc;

void main() {
  test(
    'G2 — aucune palette/mapping de type local ne contourne le resolver',
    () {
      final source = zsrc
          .libDartFiles()
          .map(zsrc.strippedSource)
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
