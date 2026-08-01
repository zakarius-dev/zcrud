@TestOn('vm')
/// 🔴 Garde ANTI-DOUBLON (piège CR-LEX-78) — CHAT-8.
///
/// Le lot avait une consigne explicite : `ZFlashcardGenerationPort` **existe** et
/// n'avait aucun consommateur ; `ZConversationSource` **existe** ; le sélecteur
/// de session **existe**. Ce test mesure deux choses **différentes**, et c'est
/// la seconde qui compte :
///
/// 1. **(négatif)** ce paquet ne REDÉCLARE aucun de ces symboles ;
/// 2. **(positif, DISCRIMINANT)** ce paquet les UTILISE réellement, et chacun
///    n'est déclaré **qu'une fois** dans tout le dépôt.
///
/// Sans (2), un paquet vide passerait le test au vert — une garde verte sous sa
/// propre régression est un défaut. Sans le comptage repo-wide, un doublon
/// déposé **ailleurs** (le scénario réel de CR-LEX-78) resterait invisible.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du dépôt (dossier portant `melos.yaml`).
///
/// Ancrage par REMONTÉE, jamais par `../..` relatif : `flutter test` s'exécute
/// depuis le dossier du paquet, un `dart test` depuis ailleurs ne résoudrait pas.
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current.path}');
    }
    dir = parent;
  }
}

List<File> _dartFilesUnder(Directory dir) => dir.existsSync()
    ? dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where((File f) => !f.path.endsWith('.g.dart'))
        .toList()
    : <File>[];

void main() {
  final Directory root = _repoRoot();
  final Directory ownLib = Directory('${root.path}/packages/zcrud_chat_study/lib');
  final List<File> ownFiles = _dartFilesUnder(ownLib);
  final String ownSource =
      ownFiles.map((File f) => f.readAsStringSync()).join('\n');

  test('contrôle positif — la garde lit bien des sources non vides', () {
    expect(ownFiles, isNotEmpty);
    expect(ownSource.length, greaterThan(2000));
  });

  group('négatif — aucun symbole existant n\'est REDÉCLARÉ ici', () {
    final Map<String, RegExp> forbidden = <String, RegExp>{
      'un second port de génération':
          RegExp(r'^\s*(abstract\s+)?(interface\s+)?class\s+\w*GenerationPort\b',
              multiLine: true),
      'un second DTO de requête de génération':
          RegExp(r'^\s*class\s+\w*GenerationRequest\b', multiLine: true),
      'une seconde provenance de conversation':
          RegExp(r'^\s*class\s+ZConversationSource\b', multiLine: true),
      'un second enum de mode de révision':
          RegExp(r'^\s*enum\s+\w*ReviewMode\b', multiLine: true),
      'un second sélecteur de session':
          RegExp(r'^\s*class\s+\w*SessionSelector\b', multiLine: true),
      'un second ordonnanceur SRS':
          RegExp(r'^\s*(abstract\s+)?class\s+\w*(SrsScheduler|Sm2\w*)\b',
              multiLine: true),
    };

    for (final MapEntry<String, RegExp> e in forbidden.entries) {
      test('ce paquet ne déclare pas ${e.key}', () {
        expect(e.value.hasMatch(ownSource), isFalse, reason: e.key);
      });
    }
  });

  group('positif DISCRIMINANT — les symboles EXISTANTS sont bien câblés', () {
    for (final String symbol in <String>[
      'ZFlashcardGenerationPort',
      'ZFlashcardGenerationRequest',
      'ZConversationSource',
      'ZStudySessionSelector',
      'ZReviewMode',
    ]) {
      test('$symbol est réellement consommé', () {
        expect(ownSource.contains(symbol), isTrue,
            reason: '$symbol n\'est pas câblé — le négatif serait trivial');
      });
    }
  });

  group('repo-wide — chaque seam n\'a qu\'UNE déclaration', () {
    final List<File> repoFiles = <File>[
      for (final FileSystemEntity e
          in Directory('${root.path}/packages').listSync())
        if (e is Directory) ..._dartFilesUnder(Directory('${e.path}/lib')),
    ];

    setUpAll(() {
      expect(repoFiles.length, greaterThan(200),
          reason: 'contrôle positif : le balayage repo-wide a bien trouvé du code');
    });

    final Map<String, RegExp> declarations = <String, RegExp>{
      'ZFlashcardGenerationPort': RegExp(
          r'^\s*abstract\s+interface\s+class\s+ZFlashcardGenerationPort\b',
          multiLine: true),
      'ZFlashcardGenerationRequest':
          RegExp(r'^\s*class\s+ZFlashcardGenerationRequest\b', multiLine: true),
      'ZConversationSource':
          RegExp(r'^\s*class\s+ZConversationSource\b', multiLine: true),
      'ZReviewMode': RegExp(r'^\s*enum\s+ZReviewMode\b', multiLine: true),
    };

    for (final MapEntry<String, RegExp> e in declarations.entries) {
      test('${e.key} est déclaré exactement 1 fois dans packages/*/lib', () {
        final List<String> sites = <String>[
          for (final File f in repoFiles)
            if (e.value.hasMatch(f.readAsStringSync()))
              f.path.replaceFirst('${root.path}/', ''),
        ];
        expect(sites, hasLength(1), reason: 'sites : $sites');
      });
    }
  });

  group('AD-19.1 — la ceinture `zSanitizeExtra` ne peut pas disparaître', () {
    // 🔴 Garde de SOURCE, et c'est délibéré. La garde COMPORTEMENTALE
    // équivalente (`z_chat_flashcard_mapper_test.dart`) reste VERTE si on
    // retire l'appel — mesuré par R3 — parce que le DTO filtre déjà à la
    // lecture. Seule une garde de source est porteuse de NOTRE ligne.
    test('le mapper appelle zSanitizeExtra avec ZSyncMeta.reservedKeys', () {
      expect(ownSource, contains('zSanitizeExtra(extra, ZSyncMeta.reservedKeys)'));
    });
  });

  group('AD-9 — aucun hard-delete dans ce paquet', () {
    // ⚠️ Ce que ce test mesure : ce paquet ne DÉTIENT aucune voie de
    // suppression. Il n'affirme rien sur les repositories (hors périmètre) —
    // c'est une propriété de CE code, énoncée comme telle.
    final Map<String, RegExp> hardDelete = <String, RegExp>{
      'un appel de suppression': RegExp(r'\.delete\s*\('),
      'une suppression de boîte/document': RegExp(r'\b(box|doc|ref)\.delete\b'),
      'un hard-delete nommé': RegExp(r'hardDelete|purge\s*\(|\.remove\s*\('),
    };

    for (final MapEntry<String, RegExp> e in hardDelete.entries) {
      test('ce paquet ne contient pas ${e.key}', () {
        expect(e.value.hasMatch(ownSource), isFalse);
      });
    }

    test('la seule voie d\'exclusion est le soft-delete, par LECTURE filtrée',
        () {
      // Contrôle positif : la propriété « pas de hard-delete » serait vide de
      // sens si le paquet n'avait aucune notion de suppression du tout.
      expect(ownSource, contains('softDeletedIds'));
      expect(ownSource, contains('ZSyncMeta.isDeleted'));
    });
  });
}
