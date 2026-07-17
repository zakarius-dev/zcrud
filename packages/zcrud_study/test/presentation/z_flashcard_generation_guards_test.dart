// SU-9 gardes STRUCTURELLES : modelId OPAQUE (AC2), répartition SOURCE UNIQUE
// (AC3), aperçu NON parallèle (AC10). Scan CODE-ONLY (les lignes de commentaire
// sont sautées : la prose PEUT nommer ce qu'elle interdit sans faire rougir).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _genFiles = <String>[
  'lib/src/presentation/z_flashcard_generation_sheet.dart',
  'lib/src/presentation/z_flashcard_generation_controller.dart',
  'lib/src/domain/z_flashcard_generation_port.dart',
  'lib/src/presentation/z_flashcard_tag_confirm_sheet.dart',
];

/// Lignes de CODE (commentaires `//`/`///` sautés).
List<String> _codeLines(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue,
      reason: 'introuvable: $path (cwd=${Directory.current.path}) — lancer '
          '`flutter test` DEPUIS le package');
  return f
      .readAsLinesSync()
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//');
      })
      .toList();
}

/// Applique [pattern] aux lignes de CODE de chaque fichier ; retourne les hits.
List<String> _scan(RegExp pattern, Iterable<String> files) {
  final hits = <String>[];
  for (final path in files) {
    final lines = _codeLines(path);
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) hits.add('$path → ${lines[i].trim()}');
    }
  }
  return hits;
}

void main() {
  group('🔴 AC2 — modelId OPAQUE : jamais une enum/un type fermé de modèle', () {
    final modelEnum = RegExp(r'enum\s+\w*[Mm]odel');

    test('aucun `enum …Model…` dans les fichiers de génération', () {
      // Doublé du round-trip verbatim (z_flashcard_generation_request_test) :
      // « casser la compilation ne prouve rien » ⇒ garde STRUCTURELLE en plus.
      expect(_scan(modelEnum, _genFiles), isEmpty,
          reason: '🔴 modelId doit rester `String?` OPAQUE — aucun catalogue/enum '
              'de modèle dans zcrud (interprétation = app-side, AD-15).');
    });

    test('CONTRE-PREUVE : un enum de modèle serait ATTRAPÉ', () {
      expect(modelEnum.hasMatch('enum AiModel { fast, smart }'), isTrue);
      expect(modelEnum.hasMatch('enum ChatModelKind { a }'), isTrue);
      // La prose « aucun enum de modèle » ne matche PAS (pas de `enum <Word>Model`).
      expect(modelEnum.hasMatch('// aucun enum, aucun catalogue de modèle'), isFalse);
    });
  });

  group('🔴 AC3 — répartition/bornage = SOURCE UNIQUE (aucune 2e implémentation)',
      () {
    const widgetFiles = <String>[
      'lib/src/presentation/z_flashcard_generation_sheet.dart',
      'lib/src/presentation/z_flashcard_generation_controller.dart',
    ];

    test('aucun bornage/split maison dans un widget (pas de `50` ni de `~/`)', () {
      // Les bornes `[1,50]` et le split vivent UNIQUEMENT dans
      // z_flashcard_generation_defaults.dart. Une 2e implémentation dans un
      // widget divergerait en silence.
      final literal50 = RegExp(r'(?<![\w.])50(?![\w])');
      final integerDiv = RegExp(r'~/');
      expect(_scan(literal50, widgetFiles), isEmpty,
          reason: '🔴 borne `50` en dur dans un widget — utiliser '
              '`zGenerationCountBounds`.');
      expect(_scan(integerDiv, widgetFiles), isEmpty,
          reason: '🔴 division entière (split maison) dans un widget — utiliser '
              '`zEvenTypesDistribution`.');
    });

    test('les widgets DÉLÈGUENT bien à la source unique (sonde non vacante)', () {
      // Sans cette sonde, « aucun 50/~/ » serait vrai même si le widget ne
      // faisait AUCUNE répartition (test infalsifiable).
      final sheet = File(widgetFiles[0]).readAsStringSync();
      expect(sheet.contains('zEvenTypesDistribution'), isTrue);
      expect(sheet.contains('zClampGenerationCount'), isTrue);
    });

    test('la source unique EXISTE et porte la logique (`~/` + bornes)', () {
      final defaults =
          File('lib/src/domain/z_flashcard_generation_defaults.dart')
              .readAsStringSync();
      expect(defaults.contains('~/'), isTrue,
          reason: 'le split déterministe vit ICI, pas dans un widget');
      expect(defaults.contains('zGenerationCountBounds'), isTrue);
    });
  });

  group('🔴 AC10 — aperçu via ZFlashcardReviewCard, jamais un rendu parallèle', () {
    test('les fichiers de génération ne lisent AUCUN contenu de carte à rendre',
        () {
      // Un rendu maison lirait `card.question`/`.answer`/`.choices`/`.explanation`.
      // Seuls ZFlashcardPreview/ZFlashcardReviewCard (su-2) rendent la carte.
      final cardContent =
          RegExp(r'\.(question|answer|choices|explanation|isTrue|hint)\b');
      expect(_scan(cardContent, _genFiles), isEmpty,
          reason: '🔴 accès au contenu d\'une carte dans un fichier de génération '
              '⇒ rendu parallèle probable. Déléguer à ZFlashcardPreview (AC10).');
    });

    test('CONTRE-PREUVE : un rendu maison serait ATTRAPÉ', () {
      final cardContent =
          RegExp(r'\.(question|answer|choices|explanation|isTrue|hint)\b');
      expect(cardContent.hasMatch('Text(card.question)'), isTrue);
      expect(cardContent.hasMatch('final a = card.answer ?? "";'), isTrue);
    });
  });
}
