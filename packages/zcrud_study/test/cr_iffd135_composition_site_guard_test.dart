// CR-IFFD-135 — garde de SOURCE : la composition du menu d'actions d'item n'a
// qu'UN SEUL site.
//
// Le risque du lot : recopier dans l'ouverture impérative la composition que
// fait le widget (traduction en entrées, cartes d'identité, contenu par
// défaut). Deux rendus du même menu naîtraient, et divergeraient au premier
// changement — exactement ce que l'hôte redoute et ce que le slot d'origine
// avait évité. Les tests de comportement ne le verraient pas : ils resteraient
// verts tant que les deux copies coïncident.
//
// Cette garde mesure donc la SOURCE, pas le rendu.
//
// Accès `dart:io` ⇒ `@TestOn('vm')` (sinon `gate:web` rougit).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart' show libDartFiles, libFile, stripped;

/// Nombre d'occurrences de [motif] dans les lignes de CODE (commentaires et
/// dartdoc dépouillés).
int _occurrences(List<String> codeLines, String motif) =>
    codeLines.fold<int>(0, (int n, String l) => n + motif.allMatches(l).length);

void main() {
  late List<String> code;
  late String chemin;

  setUp(() {
    final File f = libFile('lib/src/presentation/z_item_actions_menu.dart');
    chemin = f.path;
    code = stripped(f);
    // Garde non VACUELLE : le fichier est bien lu et non vide.
    expect(code.length, greaterThan(100), reason: 'source non lue : $chemin');
  });

  group('la composition a UN SEUL site', () {
    test('_composeItemActions : 1 déclaration + exactement 2 appels', () {
      expect(_occurrences(code, '_composeItemActions('), 3,
          reason: 'attendu : la déclaration, l\'appel du widget et celui de '
              'showZItemActionsMenu — rien d\'autre ($chemin)');
      // Les DEUX voies passent par ce site, aucune ne s'en dispense.
      final String source = code.join('\n');
      final int build = source.indexOf('Widget build(BuildContext context)');
      final int show = source.indexOf('Future<void> showZItemActionsMenu(');
      expect(build, isNonNegative);
      expect(show, isNonNegative);
      for (final int debut in <int>[build, show]) {
        expect(source.substring(debut).contains('_composeItemActions('), isTrue,
            reason: 'une voie d\'ouverture ne passe pas par le site unique');
      }
    });

    test('traduction action → entrée : un seul `toMenuEntry()` appelé', () {
      expect(_occurrences(code, '.toMenuEntry()'), 1, reason: chemin);
    });

    test('cartes d\'identité : une seule paire de `Map…identity()`', () {
      expect(_occurrences(code, 'Map<ZMenuEntry, ZItemAction>.identity()'), 1,
          reason: chemin);
      expect(_occurrences(code, 'Map<ZItemAction, ZMenuEntry>.identity()'), 1,
          reason: chemin);
    });

    test('règle d\'absence : un seul appel à `zVisibleMenuEntries(`', () {
      expect(_occurrences(code, 'zVisibleMenuEntries('), 1, reason: chemin);
    });

    test('contenu par défaut : une seule construction de la grille', () {
      // 2 = le constructeur `const _ZDefaultItemActionGrid({` de la classe
      // elle-même + l'UNIQUE construction, au site partagé.
      expect(_occurrences(code, '_ZDefaultItemActionGrid('), 2,
          reason: 'la grille par défaut est construite au site unique, jamais '
              'une seconde fois ($chemin)');
      expect(_occurrences(code, 'return _ZDefaultItemActionGrid('), 1,
          reason: chemin);
    });
  });

  group('aucune SECONDE composition ailleurs dans le paquet', () {
    test('`toMenuEntry()` et la grille par défaut ne vivent que là', () {
      final List<String> fautifs = <String>[];
      for (final File f in libDartFiles()) {
        final String p = f.path.replaceAll(r'\', '/');
        if (p.endsWith('lib/src/presentation/z_item_actions_menu.dart')) {
          continue;
        }
        final List<String> lignes = stripped(f);
        if (_occurrences(lignes, '.toMenuEntry()') > 0 ||
            _occurrences(lignes, '_ZDefaultItemActionGrid(') > 0) {
          fautifs.add(p);
        }
      }
      expect(fautifs, isEmpty,
          reason: 'une seconde composition du menu d\'actions est apparue');
    });
  });
}
