/// Garde « **UNE SEULE VOIE** d'écriture de l'ordre » (SU-8, AC11 — AD-38).
///
/// ## Pourquoi une garde STRUCTURELLE, et pas seulement un test de comportement
///
/// Le test « drag et boutons ⇒ ordre persisté identique »
/// (`z_flashcard_reorder_test.dart`) prouve que les deux voies **actuelles**
/// convergent. Il ne peut rien contre une **TROISIÈME** voie ajoutée demain : un
/// widget qui écrirait `copyWith(sectionOrders: …)` directement passerait ce test
/// **sans le faire rougir** (il ne serait simplement pas exercé), et divergerait
/// en silence — `applyOrder` étant **TOTAL**, l'ordre deviendrait orphelin sans
/// erreur.
///
/// ⇒ Cette garde interdit toute écriture de `sectionOrders` **hors** du foyer
/// unique `z_flashcard_reorder.dart`.
///
/// **Portée déclarée honnêtement** : scanne `lib/src/presentation/**` de
/// `zcrud_study` (le code de prod de ce package), et rien d'autre. Elle
/// **complète** — sans la contredire — la garde du kernel
/// (`z_section_key_single_composition_test.dart`), qui interdit la *composition*
/// manuelle des **clés** ; celle-ci interdit les *écritures* concurrentes de
/// l'**ordre**. Deux invariants distincts, jamais deux règles qui se contredisent.
///
/// ⚠️ Scan **hors dartdoc/commentaires** : la prose DOIT pouvoir expliquer le
/// patron `copyWith(sectionOrders:)` (c'est même sa raison d'être — patron
/// `z_section_key_single_composition_test.dart`, dont ce fichier reprend la
/// structure).
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **UNIQUE** foyer autorisé à écrire l'ordre des flashcards (AD-38).
const String _canonicalHome = 'z_flashcard_reorder.dart';

/// Fichiers PRÉEXISTANTS autorisés, avec leur justification.
///
/// `z_sectioned_study_layout.dart` (ES-5.3) porte le drag **générique** des
/// sections d'outils d'étude : il appelle `zReorderIds` puis **délègue la
/// persistance à son appelant** via `spec.onReorder` — il n'écrit **jamais**
/// `sectionOrders` lui-même. C'est une voie de *notification*, pas d'*écriture* :
/// il reste donc hors du périmètre de cette garde, mais l'allowlist le déclare
/// **explicitement** plutôt que de le laisser passer par accident.
const Set<String> _allowedZReorderIdsCallers = <String>{
  _canonicalHome,
  'z_sectioned_study_layout.dart',
};

/// Motifs d'**écriture** de l'ordre — réservés au foyer canonique.
const List<String> _bannedOrderWritePatterns = <String>[
  'copyWith(sectionOrders:',
  'sectionOrders:',
];

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Exercé À LA FOIS par la garde (sur le code de prod) et par sa contre-preuve
/// (sur une source artificielle) : sans ce partage, une contre-preuve qui
/// recopierait la boucle resterait verte alors même que le scan réel deviendrait
/// aveugle — elle prouverait le pouvoir des MOTIFS, jamais celui du SCANNER.
List<String> scanForOrderWrite(
  List<String> lines,
  String path,
  List<String> patterns,
) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // dartdoc/commentaire — la prose peut montrer le patron
    }
    for (final pattern in patterns) {
      if (raw.contains(pattern)) {
        violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// Énumère RÉCURSIVEMENT `lib/src/presentation/**` — jamais une liste figée : un
/// futur widget qui ouvrirait une 2e voie est capté **sans édition du test**.
List<File> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: $root (cwd=${Directory.current.path}) — '
          '⚠️ `flutter test` doit être lancé DEPUIS le package');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  group('🔴 AC11/AD-38 — une SEULE voie d\'écriture de sectionOrders', () {
    test('aucun fichier hors du foyer canonique n\'écrit sectionOrders', () {
      final files = _presentationFiles();
      expect(files, isNotEmpty,
          reason: 'sonde cassée : aucun fichier scanné ⇒ garde infalsifiable');

      final violations = <String>[];
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        if (name == _canonicalHome) continue; // le foyer a le droit
        violations.addAll(scanForOrderWrite(
          file.readAsLinesSync(),
          file.path,
          _bannedOrderWritePatterns,
        ));
      }

      expect(
        violations,
        isEmpty,
        reason: '🔴 une SECONDE voie d\'écriture de l\'ordre est '
            'apparue :\n${violations.join('\n')}\n'
            'AD-38 : drag ET boutons doivent aboutir à `zReorderFlashcards` '
            '($_canonicalHome), seule fonction autorisée à persister. Une 2e '
            'voie divergerait EN SILENCE (`applyOrder` est TOTAL : une clé '
            'orpheline n\'échoue jamais, elle est ignorée).',
      );
    });

    test('🔴 le foyer canonique écrit RÉELLEMENT (sinon la garde garde le vide)', () {
      // Sans ce test, supprimer l'écriture ferait passer la garde ci-dessus au
      // VERT (« aucune voie » ⊂ « une seule voie ») — elle prouverait l'absence
      // de tout, y compris de la fonctionnalité.
      final home = File('lib/src/presentation/$_canonicalHome');
      expect(home.existsSync(), isTrue);

      final writes = scanForOrderWrite(
        home.readAsLinesSync(),
        home.path,
        _bannedOrderWritePatterns,
      );
      expect(writes, isNotEmpty,
          reason: '🔴 le foyer canonique n\'écrit PLUS `sectionOrders` ⇒ l\'ordre '
              'manuel n\'est plus persisté DU TOUT, et la garde de voie unique '
              'resterait verte sur un package qui ne fait rien');
    });

    test('🔴 CONTRE-PREUVE : le scanner RÉEL attrape une 2e voie', () {
      final fake = <String>[
        'void save(ZFolderContentsOrder o) {',
        "  o.copyWith(sectionOrders: <String, List<String>>{'flashcards': ids});",
        '}',
      ];
      final violations =
          scanForOrderWrite(fake, 'fake.dart', _bannedOrderWritePatterns);
      expect(violations, isNotEmpty,
          reason: 'le SCANNER lui-même est aveugle ⇒ la garde ne garde RIEN');
    });

    test('CONTRE-PREUVE : la dartdoc peut citer le patron sans faire rougir', () {
      // Deux gardes ne doivent pas se contredire : la dartdoc du foyer DOIT
      // pouvoir documenter `copyWith(sectionOrders:)`.
      final proseOnly = <String>[
        '/// Persiste via `copyWith(sectionOrders: …)` — patron AD-38.',
        '// sectionOrders: est réservé au foyer canonique.',
      ];
      expect(
        scanForOrderWrite(proseOnly, 'prose.dart', _bannedOrderWritePatterns),
        isEmpty,
        reason: 'la garde doit tolérer la prose',
      );
    });
  });

  group('AC11 — zReorderIds n\'est appelé que par des voies déclarées', () {
    test('aucun appelant inattendu de zReorderIds', () {
      final unexpected = <String>[];
      for (final file in _presentationFiles()) {
        final name = file.uri.pathSegments.last;
        if (_allowedZReorderIdsCallers.contains(name)) continue;
        if (name == 'z_reorder_ids.dart') continue; // la définition elle-même

        final hits = scanForOrderWrite(
          file.readAsLinesSync(),
          file.path,
          const <String>['zReorderIds('],
        );
        unexpected.addAll(hits);
      }

      expect(
        unexpected,
        isEmpty,
        reason: '🔴 un appelant non déclaré de `zReorderIds` est '
            'apparu :\n${unexpected.join('\n')}\n'
            'Le déplacement doit passer par `zReorderFlashcards` — un appel '
            'direct produirait une liste d\'ids que rien ne persiste (ou que '
            'quelqu\'un persistera par une 2e voie).',
      );
    });

    test('l\'allowlist est JUSTE (les fichiers déclarés existent vraiment)', () {
      // Une allowlist qui pourrit (fichier renommé/supprimé) autoriserait un
      // nom mort tout en donnant l'illusion d'une exception maîtrisée.
      for (final allowed in _allowedZReorderIdsCallers) {
        expect(File('lib/src/presentation/$allowed').existsSync(), isTrue,
            reason: '🔴 l\'allowlist déclare « $allowed », qui n\'existe pas — '
                'exception morte à retirer');
      }
    });
  });
}
