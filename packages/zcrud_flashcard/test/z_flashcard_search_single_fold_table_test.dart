/// Garde de **table de repli UNIQUE** (SU-8, AC4 — D5).
///
/// La table des diacritiques vit dans `zcrud_core` (`z_search_text.dart` →
/// `zFoldDiacritics`). Une **seconde** table recopiée dans `zcrud_flashcard`
/// serait invisible : elle **passerait tous les tests fonctionnels** du jour
/// (les deux tables étant identiques au moment de la copie) et ne divergerait
/// qu'au **premier ajout** fait d'un seul côté — la recherche rendrait alors deux
/// résultats différents selon le chemin, **sans qu'aucun test ne rougisse**.
/// C'est le même `Prevents` qu'AD-38 : un défaut qu'aucun test de comportement ne
/// peut attraper ⇒ une garde **structurelle** est le seul filet.
///
/// **Portée déclarée honnêtement** : scanne le **code de production** de
/// `zcrud_flashcard` (`lib/`), et rien d'autre. Ne scanne **pas** les tests (qui
/// écrivent légitimement `'é'`/`'ç'` comme données d'entrée — c'est leur rôle).
///
/// ⚠️ Scan **hors dartdoc/commentaires** (patron
/// `z_section_key_single_composition_test.dart`) : la prose doit pouvoir citer
/// `œ → oe` en exemple sans faire rougir la garde. Deux gardes ne doivent pas se
/// contredire — celle-ci **bénit** ce que la dartdoc de `z_flashcard_search_text.dart`
/// documente.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Motifs révélant une **table de repli** recopiée (mapping diacritique → ASCII).
///
/// Volontairement étroits : on cible le **mapping** (`'é': 'e'`), jamais la
/// simple présence d'un caractère accentué (un libellé légitime en contient).
const List<String> _bannedFoldTablePatterns = <String>[
  "'é': 'e'",
  "'è': 'e'",
  "'à': 'a'",
  "'ç': 'c'",
  "'œ': 'oe'",
  "'æ': 'ae'",
  "'ß': 'ss'",
  '"é": "e"',
  '"ç": "c"',
];

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Exercé À LA FOIS par la garde (sur le code de prod) et par sa contre-preuve
/// (sur une source artificielle) : sans ce partage, une contre-preuve qui
/// recopierait la boucle resterait verte alors même que le scan réel deviendrait
/// aveugle — elle prouverait le pouvoir des MOTIFS, jamais celui du SCANNER.
List<String> scanForFoldTable(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // dartdoc/commentaire — la prose peut montrer la forme
    }
    for (final pattern in _bannedFoldTablePatterns) {
      if (raw.contains(pattern)) {
        violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/` — jamais une liste figée :
/// un futur fichier qui recopierait la table est capté sans édition du test.
List<String> _productionFiles() {
  final dir = Directory('lib');
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: lib (cwd=${Directory.current.path}) — '
          '⚠️ `flutter test` doit être lancé DEPUIS le package');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

void main() {
  group('AC4/D5 — table de repli UNIQUE (jamais une 2e dans zcrud_flashcard)', () {
    test('aucun mapping diacritique → ASCII dans lib/', () {
      final files = _productionFiles();
      expect(files, isNotEmpty,
          reason: 'sonde cassée : aucun fichier scanné ⇒ garde infalsifiable');

      final violations = <String>[];
      for (final path in files) {
        violations.addAll(scanForFoldTable(File(path).readAsLinesSync(), path));
      }

      expect(
        violations,
        isEmpty,
        reason: '🔴 une SECONDE table de repli est apparue dans '
            'zcrud_flashcard :\n${violations.join('\n')}\n'
            'La table est possédée par `zcrud_core/z_search_text.dart` '
            '(`zFoldDiacritics`). `zFlashcardSearchText` DÉLÈGUE — il ne recopie '
            'pas. Deux tables divergent au 1er ajout, en silence.',
      );
    });

    test('🔴 CONTRE-PREUVE : le scanner RÉEL attrape une table recopiée', () {
      // Sans ce test, une garde dont les motifs seraient tous faux resterait
      // verte pour toujours — elle prouverait l'absence de rien.
      final fake = <String>[
        'const Map<String, String> _myTable = <String, String>{',
        "  'é': 'e', 'ç': 'c',",
        '};',
      ];
      final violations = scanForFoldTable(fake, 'fake.dart');
      expect(violations, isNotEmpty,
          reason: 'le SCANNER lui-même est aveugle ⇒ la garde ne garde RIEN');
      expect(violations.length, 2, reason: 'les deux mappings sont vus');
    });

    test('CONTRE-PREUVE : la dartdoc peut citer la forme sans faire rougir', () {
      // Deux gardes ne doivent pas se contredire : la dartdoc de
      // `z_flashcard_search_text.dart` DOIT pouvoir documenter `œ → oe`.
      final proseOnly = <String>[
        "/// Ligatures : 'œ': 'oe', 'æ': 'ae' — repliées par le CŒUR.",
        "// 'ç': 'c' est dans zcrud_core, jamais ici.",
      ];
      expect(scanForFoldTable(proseOnly, 'prose.dart'), isEmpty,
          reason: 'la garde doit tolérer la prose (patron '
              'z_section_key_single_composition_test.dart)');
    });

    test('zFlashcardSearchText DÉLÈGUE réellement (import du cœur présent)', () {
      // La prose affirme « délègue à zFoldDiacritics » : vérifions-le sur disque
      // plutôt que de la croire (5 récidives de prose menteuse dans cet epic).
      final src =
          File('lib/src/domain/z_flashcard_search_text.dart').readAsStringSync();
      expect(src.contains('zFoldDiacritics'), isTrue,
          reason: '🔴 la délégation a disparu ⇒ soit une 2e table est née, soit '
              'la limite L-2 est revenue');
      expect(src.contains("import 'package:zcrud_core/"), isTrue,
          reason: 'la délégation passe par un import RÉEL du cœur');
    });
  });
}
