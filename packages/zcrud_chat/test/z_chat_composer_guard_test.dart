/// Lot α (CR-IFFD-72) — gardes de **SOURCE** du composer socle partagé.
///
/// Les gardes de comportement (`z_chat_composer_test.dart`) prouvent ce qui se
/// produit sur l'arbre qu'elles montent. Elles sont **aveugles** à une seconde
/// zone de saisie qu'aucun test ne monte — et c'est exactement ainsi qu'IFFD
/// s'est retrouvé avec deux barres d'actions parallèles qui ont divergé. Ce
/// fichier est le grep NÉGATIF outillé.
///
/// * **CMP-F1** — la fabrique de composition est **UNIQUE** : un seul site
///   d'appel dans tout `lib/`, dans le fichier de la racine commune. C'est ce
///   qui rend l'anti-divergence structurelle plutôt que promise.
/// * **CMP-F2** — le notebook **RELAIE**, il ne compose pas : aucune seconde
///   disposition, aucun `ZChatComposer` construit chez lui.
/// * **CMP-F3** — SM-1 structurel : la fabrique est appelée **au-dessus** des
///   `ValueListenableBuilder` du fil, jamais dedans.
/// * **CMP-F4** — **aucun nouveau chemin d'exécution** : le composer ne touche
///   du contrôleur QUE `composer`, `canSend` et `send`, en égalité d'ensemble.
/// * **CMP-F5** — le composer ne fabrique **aucun** `TextEditingController`.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

/// Le fichier du composer.
const String _composer = 'lib/src/presentation/view/z_chat_composer.dart';

/// Le fichier de la racine commune — il DÉCLARE la fabrique de composition.
const String _conversation =
    'lib/src/presentation/view/z_chat_conversation_view.dart';

/// Le fichier de la surface notebook.
const String _notebook = 'lib/src/presentation/view/z_chat_notebook_view.dart';

/// Le nom de la fabrique UNIQUE de zone de saisie.
const String _factory = '_zChatComposeSurface';

String _norm(String path) => path.replaceAll(r'\', '/');

/// Occurrences de [pattern] dans `lib/`, indexées par chemin.
Map<String, List<String>> _sites(RegExp pattern) {
  final Map<String, List<String>> out = <String, List<String>>{};
  for (final MapEntry<String, List<String>> e in strippedLib().entries) {
    for (int i = 0; i < e.value.length; i++) {
      if (pattern.hasMatch(e.value[i])) {
        (out[_norm(e.key)] ??= <String>[]).add('${i + 1}: ${e.value[i].trim()}');
      }
    }
  }
  return out;
}

int _total(Map<String, List<String>> sites) =>
    sites.values.fold<int>(0, (int a, List<String> b) => a + b.length);

void main() {
  group('🔴 CMP-F1 — la fabrique de zone de saisie est UNIQUE', () {
    /// Un APPEL de la fabrique — jamais sa déclaration.
    final RegExp call = RegExp('(?<!Widget )\\b$_factory\\s*\\(');
    final RegExp declaration = RegExp('^Widget\\s+$_factory\\s*\\(');

    test('elle est déclarée UNE fois, dans la racine commune, et appelée UNE '
        'fois', () {
      final Map<String, List<String>> declared = _sites(declaration);
      expect(_total(declared), 1,
          reason: '🔴 GARDE VACUELLE si 0 : la fabrique a disparu. Si 2+ : il '
              'y a DEUX fabriques, donc deux dispositions possibles. '
              'Sites : $declared');
      expect(declared.keys.single, endsWith(_conversation),
          reason: '🔴 la fabrique a quitté la racine commune : les deux '
              'surfaces ne passent plus forcément par elle');

      final Map<String, List<String>> calls = _sites(call);
      expect(_total(calls), 1,
          reason: '🔴 ${_total(calls)} sites de composition. UN SEUL est '
              'admis : c\'est le patron exact de la fabrique de tuile '
              '(`_ZChatList._item`, garde G-S5/G-N1). Deux sites, c\'est la '
              '« surface B » d\'IFFD — deux barres parallèles dont l\'une '
              'confirme la suppression et l\'autre non. Sites : $calls');
      expect(calls.keys.single, endsWith(_conversation));
    });

    test('🔬 contre-preuve — le motif distingue l\'APPEL de la DÉCLARATION', () {
      expect(call.hasMatch('    return $_factory(thread: t, composer: c);'),
          isTrue);
      expect(
        call.hasMatch('Widget $_factory({required Widget thread}) {'),
        isFalse,
        reason: '🔴 la déclaration comptée comme un appel rendrait la garde '
            'fausse dès le premier jour — donc désactivée',
      );
      expect(declaration.hasMatch('Widget $_factory({required Widget t}) {'),
          isTrue);
    });
  });

  group('🔴 CMP-F2 — le NOTEBOOK relaie, il ne compose pas', () {
    test('il relaie `composer` EXACTEMENT une fois et ne dispose rien', () {
      final String src = stripped(libFile(_notebook)).join('\n');
      expect(RegExp(r'class\s+ZChatNotebookView\b').hasMatch(src), isTrue,
          reason: '🔴 GARDE VACUELLE : la surface notebook est introuvable');
      expect(
        RegExp(r'composer:\s*composer\b').allMatches(src).length,
        1,
        reason: '🔴 le relai de la saisie est coupé (0) ou dupliqué (2+). Un '
            'notebook qui ne relaie plus reçoit un paramètre MORT : l\'hôte '
            'le passe et rien n\'apparaît.',
      );
      for (final RegExp interdit in <RegExp>[
        // Une disposition à lui — c'est la fabrique unique qui compose.
        RegExp(r'\bColumn\s*\('),
        RegExp(r'\bExpanded\s*\('),
        // Une saisie à lui — le pendant exact de l'interdit `ZChatMessageTile(`
        // de G-N1.
        RegExp(r'\bZChatComposer\s*\('),
        RegExp(r'\bEditableText\b'),
        RegExp('\\b$_factory\\b'),
      ]) {
        expect(interdit.hasMatch(src), isFalse,
            reason: '🔴 `${interdit.pattern}` dans `$_notebook` : le notebook '
                'compose SA saisie au lieu de relayer. C\'est le début du '
                'monolithe à booléen que CR-71 remplace, et la fabrique '
                'unique cesse alors de rendre les deux surfaces.');
      }
    });

    test('🔬 contre-preuve — les motifs SAVENT rougir, sans crier au loup', () {
      expect(RegExp(r'\bZChatComposer\s*\(').hasMatch(
          '      return ZChatComposer(controller: controller);'), isTrue);
      expect(RegExp(r'\bColumn\s*\(').hasMatch('    return Column(children: c);'),
          isTrue);
      expect(
        RegExp(r'composer:\s*composer\b').hasMatch('      composer: null,'),
        isFalse,
        reason: '🔴 un relai COUPÉ ne doit pas compter comme un passage',
      );
      expect(
        RegExp(r'\bZChatComposer\s*\(')
            .hasMatch('  final Widget? composer;'),
        isFalse,
      );
    });
  });

  group('🔴 CMP-F3 — SM-1 structurel : la saisie est un FRÈRE du fil', () {
    test('la fabrique est appelée au premier niveau de `build`, jamais dans un '
        '`ValueListenableBuilder`', () {
      final List<String> lines = stripped(libFile(_conversation));
      final List<String> calls = <String>[
        for (final String l in lines)
          if (RegExp('(?<!Widget )\\b$_factory\\s*\\(').hasMatch(l)) l,
      ];
      expect(calls, hasLength(1),
          reason: '🔴 GARDE VACUELLE : aucun appel trouvé dans la racine');
      expect(
        RegExp('^    return $_factory\\(').hasMatch(calls.single),
        isTrue,
        reason: '🔴 l\'appel est indenté au-delà du premier niveau de `build` '
            '(« ${calls.single.trim()} ») : la saisie est passée SOUS les '
            'tranches `messages`/`activeRequests`. Chaque tour la '
            'reconstruirait alors sous les doigts de l\'utilisateur — SM-1, '
            'l\'objectif produit n°1.',
      );
    });

    test('🔬 contre-preuve — le motif voit la différence d\'indentation', () {
      final RegExp top = RegExp('^    return $_factory\\(');
      expect(top.hasMatch('    return $_factory(thread: t, composer: c);'),
          isTrue);
      expect(
        top.hasMatch('              return $_factory(thread: t, composer: c);'),
        isFalse,
      );
    });
  });

  group('🔴 CMP-F4 — AUCUN nouveau chemin d\'exécution', () {
    test('le composer ne touche du contrôleur QUE `composer`, `canSend` et '
        '`send` — en ÉGALITÉ d\'ENSEMBLE', () {
      final String src = stripped(libFile(_composer)).join('\n');
      final Set<String> touched = <String>{
        for (final RegExpMatch m
            in RegExp(r'\bcontroller\.(\w+)').allMatches(src))
          m.group(1)!,
      };
      expect(
        touched,
        <String>{'composer', 'canSend', 'send'},
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE, pas « contient » (leçon G-CH1). Le '
            'composer lit la saisie, lit la condition d\'envoi, et appelle le '
            'verbe EXISTANT. `runAction(`, `attach(`, `setAttachments(` ou un '
            'membre nouveau ici seraient un chemin d\'exécution de plus — '
            'exactement ce que ce paquet interdit. Vu : $touched',
      );
    });

    test('`send(` n\'est invoqué qu\'à UN endroit du composer', () {
      final List<String> lines = stripped(libFile(_composer));
      final List<String> sites = <String>[
        for (int i = 0; i < lines.length; i++)
          if (RegExp(r'\.send\s*\(').hasMatch(lines[i]))
            '${i + 1}: ${lines[i].trim()}',
      ];
      expect(sites, hasLength(1),
          reason: '🔴 le créneau d\'envoi et la validation clavier doivent '
              'partager LE MÊME site d\'appel. Deux sites = deux '
              'comportements possibles, c\'est-à-dire le défaut d\'IFFD. '
              'Sites : $sites');
    });

    test('🔬 contre-preuve — l\'extracteur voit un membre fautif', () {
      const String witness =
          '    unawaited(widget.controller.runAction(action));\n'
          '    widget.controller.composer.text;';
      final Set<String> touched = <String>{
        for (final RegExpMatch m
            in RegExp(r'\bcontroller\.(\w+)').allMatches(witness))
          m.group(1)!,
      };
      expect(touched, <String>{'runAction', 'composer'},
          reason: '🔴 si `runAction` échappe à l\'extracteur, la garde est '
              'décorative');
    });
  });

  group('🔴 CMP-F5 — le composer ne FABRIQUE aucun contrôleur de saisie', () {
    test('aucun `TextEditingController(` dans le fichier du composer', () {
      final List<String> lines = stripped(libFile(_composer));
      final List<String> sites = <String>[
        for (int i = 0; i < lines.length; i++)
          if (RegExp(r'\bTextEditingController\s*\(').hasMatch(lines[i]))
            '${i + 1}: ${lines[i].trim()}',
      ];
      expect(sites, isEmpty,
          reason: '🔴 un `TextEditingController` créé dans le rendu, c\'est '
              'l\'interdit AD-2 le plus coûteux : curseur et sélection perdus '
              'à chaque frappe. La tranche du contrôleur est STABLE et lui '
              'appartient. Sites : $sites');
      // Non-vacuité : le composer LIE bien une tranche existante.
      expect(lines.join('\n'), contains('controller: controller.composer'),
          reason: '🔴 GARDE VACUELLE : le champ ne lie plus la tranche du '
              'contrôleur — la garde ci-dessus passerait sur un composer qui '
              'n\'affiche rien.');
    });

    test('🔬 contre-preuve — le motif voit une fabrication réelle', () {
      final RegExp p = RegExp(r'\bTextEditingController\s*\(');
      expect(p.hasMatch('  final TextEditingController _f = '
          'TextEditingController();'), isTrue);
      expect(p.hasMatch('  final TextEditingController before = w.controller;'),
          isFalse);
    });
  });
}
