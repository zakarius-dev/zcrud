/// AC3 (SU-4) — les **6 modes** sur les **3 runtimes EXISTANTS**, et la preuve
/// que la table `zSessionRuntimeForMode` **s'accorde avec la réalité des types**
/// (AD-34).
///
/// 🔴 **ANTI-TAUTOLOGIE — la raison d'être de ce fichier.** Écrire
/// `expect(zSessionRuntimeForMode(ZReviewMode.list), ZSessionRuntimeKind.linear)`
/// ne prouve **RIEN** : c'est la table récitée à elle-même (défaut **D11** de
/// su-3, « fonction locale appelée par le test »). Faire diverger la table de la
/// réalité laisserait un tel test **vert**.
///
/// Ces tests **bouclent sur `ZReviewMode.values`** (jamais une liste figée) et,
/// pour chaque mode, **CONSTRUISENT les runtimes réels** :
///  1. le runtime **désigné par la table** se construit ⇒ **ne lève PAS** ;
///  2. `ZStudySessionEngine` construit avec un mode que la table n'y envoie pas
///     ⇒ **`AssertionError`** (garde réelle de su-1) ;
///  3. `ZLinearSessionState` idem ⇒ **`AssertionError`** ;
///  4. `ZWhiteExamSessionEngine` : preuve **STRUCTURELLE** — son ctor n'a **ni**
///     `mode` **ni** `reviewer`. ⚠️ On n'attend **aucun** `AssertionError` de sa
///     part : il n'en lève pas, et le prescrire ferait échouer le test à raison.
///
/// ⇒ faire diverger la table de la réalité rend ce fichier **rouge des deux
/// côtés** (le runtime désigné lèverait, ou le mode « interdit » ne lèverait
/// plus).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Right, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionInfo;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// File minimale — 2 cartes (assez pour tout ctor).
List<ZSessionItem> _queue() => const <ZSessionItem>[
      ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
      ZSessionItem(flashcardId: 'f2', folderId: 'd1'),
    ];

/// Espion de reviewer — il **enregistre** (ce n'est PAS un no-op de prod : AD-34
/// interdit la porte dérobée « reviewer inerte » ; ici on prouve justement qu'il
/// n'est jamais appelé, ce qui exige qu'il PUISSE l'être).
class _SpyReviewer {
  final List<int> calls = <int>[];

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls.add(quality);
    return Right<Never, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

/// Construit le runtime **désigné par la table** pour [mode]. Lève si le
/// constructeur réel refuse le mode — c'est précisément ce qu'on mesure.
void _buildDesignatedRuntime(ZReviewMode mode) {
  switch (zSessionRuntimeForMode(mode)) {
    case ZSessionRuntimeKind.srsEngine:
      ZStudySessionEngine(
        queue: _queue(),
        reviewer: _SpyReviewer().call,
        mode: mode,
      ).dispose();
    case ZSessionRuntimeKind.linear:
      ZLinearSessionState(queue: _queue(), mode: mode).dispose();
    case ZSessionRuntimeKind.whiteExam:
      // ⚠️ Ni `mode` ni `reviewer` : le régime est STRUCTUREL (AD-34).
      ZWhiteExamSessionEngine(queue: _queue()).dispose();
  }
}

void main() {
  group('🎯 AC3 — la table est CONFRONTÉE aux constructeurs réels (AD-34)', () {
    test(
        '🔴 (1) pour CHAQUE mode, le runtime DÉSIGNÉ par la table se construit '
        'sans lever', () {
      // Boucle sur `values` — jamais une liste figée : une 7ᵉ valeur de
      // `ZReviewMode` est prise en compte sans édition du test (et casserait
      // déjà la compilation de la table, `switch` sans `default`).
      expect(ZReviewMode.values, hasLength(6),
          reason: 'le spine décrit 6 modes ; un changement doit être délibéré');

      for (final mode in ZReviewMode.values) {
        expect(
          () => _buildDesignatedRuntime(mode),
          returnsNormally,
          reason: 'la table envoie $mode vers ${zSessionRuntimeForMode(mode)}, '
              'mais ce runtime REFUSE ce mode ⇒ la table a divergé de la '
              'réalité des types',
        );
      }
    });

    test(
        '🔴 (2) `ZStudySessionEngine` REFUSE tout mode que la table ne lui '
        'envoie pas (assert RÉEL de su-1 — jamais réécrit ici)', () {
      final refused = ZReviewMode.values
          .where((m) => zSessionRuntimeForMode(m) != ZSessionRuntimeKind.srsEngine)
          .toList();
      // Contre-preuve : la partition ne doit être ni vide ni totale, sinon
      // l'assertion suivante serait vide de sens.
      expect(refused, hasLength(4), reason: 'list/cramming/test/whiteExam');

      for (final mode in refused) {
        expect(
          () => ZStudySessionEngine(
            queue: _queue(),
            reviewer: _SpyReviewer().call,
            mode: mode,
          ),
          throwsA(isA<AssertionError>()),
          reason: 'le moteur SRS a ACCEPTÉ $mode : il DÉTIENT un reviewer ⇒ il '
              'écrirait du SRS pour un mode qui l\'interdit (AD-34)',
        );
      }
    });

    test(
        '🔴 (3) `ZLinearSessionState` REFUSE tout mode que la table ne lui '
        'envoie pas (assert RÉEL, symétrique)', () {
      final refused = ZReviewMode.values
          .where((m) => zSessionRuntimeForMode(m) != ZSessionRuntimeKind.linear)
          .toList();
      expect(refused, hasLength(4), reason: 'spaced/learn/test/whiteExam');

      for (final mode in refused) {
        expect(
          () => ZLinearSessionState(queue: _queue(), mode: mode),
          throwsA(isA<AssertionError>()),
          reason: 'le runtime linéaire a ACCEPTÉ $mode (AD-34)',
        );
      }
    });

    test(
        '🔴 (4) `ZWhiteExamSessionEngine` — preuve STRUCTURELLE : son ctor n\'a '
        'NI `mode` NI `reviewer` ⇒ aucun assert à attendre', () {
      // ⚠️ Ne PAS attendre d'AssertionError : il n'en lève aucune. La preuve est
      // que le type n'a AUCUN paramètre par lequel un mode ou un seam d'écriture
      // pourrait entrer — c'est plus fort qu'une garde runtime.
      expect(() => ZWhiteExamSessionEngine(queue: _queue()), returnsNormally);

      // Preuve de SOURCE de l'absence des deux paramètres (une « absence » se
      // prouve, elle ne s'affirme pas). On lit le ctor RÉEL sur disque.
      const path = 'lib/src/domain/z_white_exam_session_engine.dart';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path})');
      final src = file.readAsStringSync();
      final ctor = src.substring(
        src.indexOf('ZWhiteExamSessionEngine({'),
        src.indexOf('_state = ZWhiteExamState('),
      );
      expect(ctor.contains('reviewer'), isFalse,
          reason: 'un `reviewer` est apparu au ctor de l\'examen blanc : le '
              'régime « aucune écriture SRS » n\'est plus structurel (AD-34)');
      expect(ctor.contains('ZReviewMode'), isFalse,
          reason: 'un paramètre `mode` est apparu : le régime cesserait d\'être '
              'une propriété du TYPE');
    });
  });

  group('🎯 AC3 — garde AUTO-ÉNUMÉRANTE : exactement TROIS runtimes (AD-34)', () {
    /// Scanne RÉCURSIVEMENT `lib/src/domain/**` et rend les noms de classes
    /// capturés par [re]. 🚫 Jamais une liste figée de fichiers : un 4ᵉ runtime
    /// posé dans un fichier neuf est capté **sans édition du test**.
    Set<String> declaredClasses(RegExp re) {
      const root = 'lib/src/domain';
      final dir = Directory(root);
      expect(dir.existsSync(), isTrue,
          reason: 'répertoire introuvable: $root '
              '(cwd=${Directory.current.path})');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      // Contre-preuve R12 : un scan qui ne voit rien serait vert à tort.
      expect(files, isNotEmpty, reason: 'aucun fichier de domaine scanné');
      return <String>{
        for (final f in files)
          for (final m in re.allMatches(f.readAsStringSync())) m.group(1)!,
      };
    }

    test(
        '🔴 (a) critère STRUCTUREL — les seuls `ChangeNotifier` du domaine sont '
        'les 3 runtimes existants', () {
      // Un runtime de session EST un `ChangeNotifier` (AD-2 : réactivité
      // Flutter-native). C'est le critère de FOND, indépendant du nommage : un
      // 4ᵉ runtime, quel que soit son nom, est capté ici.
      final notifiers =
          declaredClasses(RegExp(r'class\s+(Z\w+)\s+extends\s+ChangeNotifier'));
      expect(
        notifiers,
        <String>{
          'ZStudySessionEngine',
          'ZLinearSessionState',
          'ZWhiteExamSessionEngine',
        },
        reason: '🔴 AD-34 : les 6 modes sont servis par les 3 runtimes qui '
            'EXISTENT — su-4 n\'en crée AUCUN. Ensemble trouvé : $notifiers',
      );
    });

    test(
        '🔴 (b) critère de NOMMAGE — aucune classe `Z…SessionEngine/SessionState` '
        'inattendue (capte même un runtime qui n\'étend rien)', () {
      // ⚠️ Complémentaire de (a), et NON redondant : une classe posée sans
      // `extends ChangeNotifier` (p.ex. `class ZFakeSessionEngine {}`,
      // injection R3-I5) échapperait au critère structurel. Le nommage la voit.
      final named = declaredClasses(
          RegExp(r'class\s+(Z\w*(?:SessionEngine|SessionState))\b'));
      expect(
        named,
        <String>{
          'ZStudySessionEngine',
          'ZLinearSessionState',
          'ZWhiteExamSessionEngine',
          // ⚠️ `ZSessionState` n'est PAS un runtime : c'est le value-object
          // IMMUABLE d'état de file (aucun `ChangeNotifier`, aucune méthode de
          // progression) — partagé par les 3 runtimes. Il est listé ici parce
          // qu'il tombe sous le motif de NOMMAGE, pas parce qu'il serait un 4ᵉ
          // runtime : le critère (a) l'exclut correctement. L'omettre rendrait
          // ce test rouge sur du code parfaitement conforme.
          'ZSessionState',
        },
        reason: '🔴 AD-34 : classe de session inattendue. Trouvé : $named',
      );
    });
  });
}
