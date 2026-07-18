// me-2 / AD-43 étage (a) STRUCTUREL + chasse aux voies de fuite (leçon su-8 : le
// HIGH passait par une voie NON anticipée). La garde de pureté récursive
// (`z_widgets_purity_test.dart`) couvre DÉJÀ `Repository`/`LocalStore`/
// `RemoteStore`/`.save(`/`.persist(`/scheduler ; CE fichier ferme les voies
// SPÉCIFIQUES à me-2 (auto-save, cascade draft, rendu d'aperçu parallèle) —
// extension de couverture, pas une garde parallèle.
//
// Accès `dart:io` ⇒ @TestOn('vm').
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _editor = 'lib/src/presentation/z_multi_flashcard_editor.dart';
const _controller =
    'lib/src/presentation/z_multi_flashcard_editor_controller.dart';

/// Lignes de CODE (dartdoc/commentaires exclus) — la prose peut NOMMER ce qu'elle
/// interdit.
List<String> _codeLines(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue,
      reason: 'sonde : $path introuvable (cwd=${Directory.current.path}) — '
          '`flutter test` doit être lancé DEPUIS le package');
  return file
      .readAsLinesSync()
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('///') && !t.startsWith('//');
      })
      .toList();
}

bool _codeContains(String path, String needle) =>
    _codeLines(path).any((l) => l.contains(needle));

void main() {
  group('🔴 AD-43 étage (a) — aucune voie de fuite dans le brouillon', () {
    test('sonde : les deux fichiers de me-2 sont RÉELLEMENT scannés', () {
      expect(_codeLines(_editor), isNotEmpty);
      expect(_codeLines(_controller), isNotEmpty);
    });

    test('🔴 aucune AUTO-SAUVEGARDE implicite (Timer / didChangeDependencies)', () {
      for (final path in <String>[_editor, _controller]) {
        for (final leak in <String>[
          'Timer(',
          'Timer.periodic',
          'didChangeDependencies',
        ]) {
          expect(_codeContains(path, leak), isFalse,
              reason: '🔴 « $leak » dans $path : une auto-sauvegarde implicite '
                  'franchirait la frontière AD-43 sans commit explicite');
        }
      }
    });

    test('🔴 aucune écriture/persistance directe (redondant avec la pureté)', () {
      // Contre-preuve locale : ces motifs SONT bien détectables par _codeContains
      // (sinon l'assertion à faux serait infalsifiable).
      expect(_codeContains(_editor, 'ZMultiFlashcardEditor'), isTrue,
          reason: 'sonde : le scanner voit RÉELLEMENT le code de l\'éditeur');
      for (final path in <String>[_editor, _controller]) {
        for (final leak in <String>[
          '.save(',
          '.persist(',
          'Repository',
          'LocalStore',
          'RemoteStore',
          'ZSrsScheduler',
          '.reviewCard(',
        ]) {
          expect(_codeContains(path, leak), isFalse,
              reason: '🔴 « $leak » dans $path : voie de persistance/SRS interdite '
                  'dans un brouillon (AD-43/AD-33)');
        }
      }
    });

    test('🔴 aucune cascade AD-39 sur une carte draft (retrait purement mémoire)',
        () {
      // La suppression du brouillon ne touche AUCUN seam de suppression persistée
      // (ni `batchDelete`, ni `deleteRoot`, ni cascade) — c'est `removeKeys`,
      // in-memory. On prouve l'absence des seams de suppression persistée.
      for (final leak in <String>['batchDelete', 'deleteRoot', 'softDelete']) {
        expect(_codeContains(_controller, leak), isFalse,
            reason: '🔴 « $leak » : la suppression draft ne cascade pas (AD-39)');
      }
    });

    test('🔴 AC6 — l\'aperçu est un ZFlashcardReviewCard, PAS un rendu parallèle',
        () {
      // Présence RÉELLE de su-2 (l'aperçu le construit)…
      expect(_codeContains(_editor, 'ZFlashcardReviewCard'), isTrue,
          reason: '🔴 l\'aperçu DOIT réutiliser su-2');
      // …et AUCUN lecteur markdown / conversion de contenu réimplémenté.
      for (final parallel in <String>[
        'ZMarkdownReader',
        'MarkdownToDelta',
        'QuillEditor',
      ]) {
        expect(_codeContains(_editor, parallel), isFalse,
            reason: '🔴 « $parallel » : rendu de contenu de carte parallèle '
                'interdit (AC6) — divergerait en silence de su-2');
      }
    });

    test('🔴 régime DÉCLARÉ en enum (jamais implicite)', () {
      expect(_codeContains(_controller, 'enum ZEditingMode'), isTrue,
          reason: '🔴 AD-43 : le régime brouillon est DÉCLARÉ (enum public)');
    });
  });
}
