/// Pureté runtime des widgets de PRÉSENTATION de `zcrud_study` (SU-8/AC20 —
/// AD-2/AD-15/AD-23/AD-33).
///
/// ## Pourquoi cette garde est CRÉÉE ici (et n'est PAS une duplication)
///
/// Les gardes jumelles `z_widgets_purity_test.dart` /
/// `z_widgets_hardcode_scan_test.dart` **n'existaient QUE dans `zcrud_session`**
/// (vérifié : `find packages -name 'z_widgets_purity_test.dart'` ⇒ **un seul**
/// fichier, `zcrud_session`). Elles scannent `Directory('lib/src/presentation')`
/// — **de leur propre package**, en chemin RELATIF. Elles ne peuvent donc
/// **structurellement pas** couvrir `zcrud_study`, et `zcrud_session` ne dépend
/// **pas** de `zcrud_study` (su-8 ne peut pas s'y ajouter).
///
/// ⇒ Les créer ici est une **EXTENSION DE COUVERTURE à un package non gardé**,
/// pas une seconde source. Mesuré avant écriture : `zcrud_study/lib/src/
/// presentation` était **déjà conforme** (0 couleur en dur, 0 gestionnaire
/// d'état) — la garde ne « légalise » aucune dette, elle **verrouille** un état
/// sain que rien ne protégeait.
///
/// ## Ce qu'elle interdit — et pourquoi le danger est LOCAL
///
/// `zcrud_study` dépend de `zcrud_flashcard`, qui **contient lui-même** les
/// moyens d'écrire le SRS (`ZSm2Scheduler`, `ZSrsScheduler`, `ZRepetitionStore`).
/// Un widget de liste **peut** appeler `ZSrsScheduler.apply` directement : ce
/// serait la porte dérobée exacte qu'AD-33 interdit (l'écriture SRS passe
/// UNIQUEMENT par le seam `ZSessionReviewer`). su-8 n'écrit **aucun** SRS — il
/// consulte.
///
/// **N'énumère JAMAIS une liste figée** : scan **récursif** ⇒ tout futur widget
/// est capté **sans édition du test** (durabilité, R16).
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**`.
List<String> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: $root (cwd=${Directory.current.path}) — '
          '⚠️ `flutter test` doit être lancé DEPUIS le package');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// Gestionnaires d'état interdits dans le cœur et les satellites (AD-2/AD-15).
const List<String> _bannedImports = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:get/',
  'package:provider/',
];

/// Symboles d'**ÉCRITURE SRS** interdits (AD-23/AD-33 : l'écriture passe
/// UNIQUEMENT par le seam `ZSessionReviewer`, jamais par une surface de
/// présentation).
const List<String> _bannedWriteSymbols = <String>[
  'ZRepetitionStore',
  'ZSrsScheduler',
  'ZSm2Scheduler',
  '.reviewCard(',
];

/// Symboles de **STORE / REPOSITORY** interdits (SU-9/AC5 — AD-37/AD-43).
///
/// Le flux de génération IA (`z_flashcard_generation_*`/`z_flashcard_tag_confirm_*`)
/// **ne persiste RIEN** avant un commit explicite : le seul canal de sortie est le
/// **handoff** `onGenerated` à l'appelant (la frontière de commit AD-43), jamais
/// une écriture base. Cette garde couvre AUTOMATIQUEMENT les 3 nouveaux fichiers
/// (scan récursif de `lib/src/presentation/**`) — extension de couverture, pas
/// une seconde garde.
///
/// 🔒 Forme **MÉTHODE/TYPE** (`.save(`/`.persist(`/`…Repository`), jamais un mot
/// de prose : la dartdoc « ne persiste rien » vit en commentaire (skippé par le
/// scanner), sinon la garde crierait au loup sur sa propre documentation.
const List<String> _bannedStoreSymbols = <String>[
  'ZRepository',
  'Repository',
  'LocalStore',
  'RemoteStore',
  '.save(',
  '.persist(',
];

/// **Scanner RÉEL de la garde** — partagé avec sa contre-preuve (sans ce
/// partage, la contre-preuve prouverait le pouvoir des MOTIFS, jamais celui du
/// SCANNER).
List<String> scanForBanned(
  List<String> lines,
  String path,
  List<String> patterns,
) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // la prose DOIT pouvoir nommer ce qu'elle interdit
    }
    for (final pattern in patterns) {
      if (raw.contains(pattern)) {
        violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

void main() {
  group('AC20/AD-2/AD-15 — aucun gestionnaire d\'état dans la présentation', () {
    test('aucun import de Riverpod/GetX/provider', () {
      final files = _presentationFiles();
      expect(files, isNotEmpty,
          reason: 'sonde cassée : aucun fichier scanné ⇒ garde infalsifiable');

      final violations = <String>[];
      for (final path in files) {
        violations.addAll(
            scanForBanned(File(path).readAsLinesSync(), path, _bannedImports));
      }

      expect(violations, isEmpty,
          reason: '🔴 un gestionnaire d\'état a fuité dans la présentation :\n'
              '${violations.join('\n')}\n'
              'AD-15 : la réactivité est Flutter-native (`ChangeNotifier`/'
              '`ValueListenable`) ; le code manager-spécifique vit UNIQUEMENT '
              'dans son package de binding (`zcrud_get`/`zcrud_riverpod`).');
    });
  });

  group('🔴 AC20/AD-23/AD-33 — aucune ÉCRITURE SRS depuis un widget', () {
    test('aucun scheduler / store / reviewCard dans la présentation', () {
      final violations = <String>[];
      for (final path in _presentationFiles()) {
        violations.addAll(scanForBanned(
            File(path).readAsLinesSync(), path, _bannedWriteSymbols));
      }

      expect(violations, isEmpty,
          reason: '🔴 une porte dérobée d\'écriture SRS est apparue :\n'
              '${violations.join('\n')}\n'
              'Le danger est LOCAL : `zcrud_study` dépend de `zcrud_flashcard`, '
              'qui CONTIENT `ZSrsScheduler`/`ZRepetitionStore`. su-8 CONSULTE '
              'les cartes — il n\'écrit aucun état de révision (AD-33).');
    });
  });

  group('🔴 SU-9/AC5/AD-43 — aucun STORE/REPOSITORY dans la présentation', () {
    test('aucun repository/save/persist dans les fichiers de génération', () {
      final files = _presentationFiles();
      // Sonde : les 3 fichiers de su-9 sont RÉELLEMENT dans le corpus scanné
      // (sinon l'assertion à vide serait infalsifiable — leçon su-7).
      expect(
        files.where((p) =>
            p.contains('z_flashcard_generation_') ||
            p.contains('z_flashcard_tag_confirm_')),
        hasLength(greaterThanOrEqualTo(3)),
        reason: 'les 3 fichiers su-9 doivent être dans le corpus scanné',
      );

      final violations = <String>[];
      for (final path in files) {
        violations.addAll(
            scanForBanned(File(path).readAsLinesSync(), path, _bannedStoreSymbols));
      }

      expect(violations, isEmpty,
          reason: '🔴 un store/repository a fuité dans la présentation :\n'
              '${violations.join('\n')}\n'
              'AD-37/AD-43 : le flux de génération ne persiste RIEN — le seul '
              'canal de sortie est le handoff `onGenerated`, pas une écriture base.');
    });
  });

  group('🔴 CONTRE-PREUVES — le scanner RÉEL n\'est pas aveugle', () {
    test('un import de gestionnaire d\'état est ATTRAPÉ', () {
      final fake = <String>["import 'package:get/get.dart';"];
      expect(scanForBanned(fake, 'fake.dart', _bannedImports), isNotEmpty,
          reason: 'le SCANNER est aveugle ⇒ la garde ne garde RIEN');
    });

    test('une écriture SRS est ATTRAPÉE', () {
      final fake = <String>['  ZSrsScheduler().apply(card, quality);'];
      expect(scanForBanned(fake, 'fake.dart', _bannedWriteSymbols), isNotEmpty);
    });

    test('🔴 un appel de STORE est ATTRAPÉ (la garde su-9 n\'est pas aveugle)', () {
      // Sans cette contre-preuve, l'assertion « aucun store » pourrait rester
      // verte sur un scanner cassé (leçon : un espion jamais branché).
      expect(
          scanForBanned(<String>['    _repo.save(card);'], 'f.dart',
              _bannedStoreSymbols),
          isNotEmpty);
      expect(
          scanForBanned(<String>['  final ZRepository<ZFlashcard> r = x;'],
              'f.dart', _bannedStoreSymbols),
          isNotEmpty);
    });

    test('la prose peut NOMMER ce qu\'elle interdit sans faire rougir', () {
      final proseOnly = <String>[
        "/// N'importe JAMAIS `package:get/get.dart` (AD-15).",
        '// ZSrsScheduler est interdit ici : AD-33.',
      ];
      expect(scanForBanned(proseOnly, 'prose.dart', _bannedImports), isEmpty);
      expect(
          scanForBanned(proseOnly, 'prose.dart', _bannedWriteSymbols), isEmpty,
          reason: 'deux gardes ne doivent pas se contredire : la dartdoc de '
              'z_widgets_purity_test.dart NOMME ces symboles');
    });
  });
}
