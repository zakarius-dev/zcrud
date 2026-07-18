import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Frontière SU-10 — l\'app dépend de zcrud_core + 3 bindings + zcrud_list + '
      'les 5 satellites EX-3 + zcrud_session/zcrud_flashcard (parcours d\'étude) ; '
      'zcrud_mindmap (E10) reste INTERDIT', () {
    // `flutter test` s\'exécute depuis la racine du package `example/`.
    // On strippe les COMMENTAIRES (qui mentionnent les paquets interdits à titre
    // explicatif) pour ne tester que les vraies déclarations de dépendances.
    final withoutComments = File('pubspec.yaml')
        .readAsLinesSync()
        .map((l) {
          final hash = l.indexOf('#');
          return hash >= 0 ? l.substring(0, hash) : l;
        })
        .join('\n');

    // BASCULEMENT DE FRONTIÈRE (su-10, AC10) — ce n'est PAS « taire un défaut » :
    // la frontière EX-3 disait « `zcrud_flashcard` interdit TANT QUE non consommé ».
    // su-10 le consomme LÉGITIMEMENT (carte de révision + ports indice/évaluation
    // + SRS, assemblés dans la démo « Parcours d'étude ») ⇒ `zcrud_flashcard`
    // QUITTE l'ensemble interdit. Seul `zcrud_mindmap` (E10, su-12, hors
    // périmètre) reste INTERDIT — y compris en TRANSITIF : c'est précisément
    // pourquoi `zcrud_study` (qui dépend en dur de `zcrud_mindmap`) n'est PAS
    // ajouté (écart consigné su-10). L'assertion couvre `dependencies` ET
    // `dependency_overrides` : un override path de `zcrud_mindmap` (requis dès
    // qu'il entre dans le lock) ferait rougir ce test.
    const forbidden = <String>[
      'zcrud_mindmap',
    ];
    for (final pkg in forbidden) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isFalse,
          reason: 'Frontière violée : $pkg (E10, v1.x — su-12) ne doit être '
              'déclaré NI en dépendance NI en override');
    }

    // Les paquets zcrud attendus sont bien déclarés — assertion POSITIVE : sans
    // elle, un futur nettoyage de pubspec casserait le parcours sans rougir.
    for (final pkg in <String>[
      'zcrud_core',
      'zcrud_get',
      'zcrud_riverpod',
      'zcrud_provider',
      'zcrud_list',
      'zcrud_markdown',
      'zcrud_geo',
      'zcrud_intl',
      'zcrud_export',
      'zcrud_firestore',
      // su-10 — parcours d'étude assemblé.
      'zcrud_session',
      'zcrud_flashcard',
      // fp-3-2 — parité totale : les 4 satellites FORM-PARITY (fp-4/fp-5) sont
      // consommés par la showcase EXHAUSTIVE + le harnais 6 formulaires DODLP.
      // Sans cette assertion POSITIVE, un futur nettoyage de pubspec casserait la
      // parité sans rougir. Aucun de ces 4 ne tire `zcrud_mindmap` (interdit ci-dessus).
      'zcrud_select',
      'zcrud_html',
      'zcrud_media',
      'zcrud_field_extras',
    ]) {
      final declared = RegExp('^\\s+$pkg\\s*:', multiLine: true);
      expect(declared.hasMatch(withoutComments), isTrue, reason: '$pkg attendu');
    }
  });
}
