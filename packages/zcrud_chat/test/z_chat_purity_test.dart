/// Pureté du package — **grep NÉGATIF outillé** (AD-2/AD-13/AD-15/FR-26).
///
/// ## Ce que ce fichier prouve, et ce qu'il ne prouve PAS
///
/// Il **lit les sources de `lib/`** et rougit sur : un gestionnaire d'état,
/// une surface Flutter *stylée* (`material`/`cupertino`), une couleur ou un
/// style codé en dur, une variante directionnelle interdite. Il ne prouve rien
/// sur les autres packages — c'est `melos run analyze` repo-wide et la garde
/// **G-U1** du kernel qui les couvrent (leçon E10 : *une garde ne prouve QUE
/// ce qu'elle scanne*).
///
/// ## 🔴 L'exception `flutter/widgets.dart`, et pourquoi elle est SÛRE
///
/// `TextEditingController` est un objet d'**état**, mais il vit dans `widgets`
/// (`editable_text.dart`), pas dans `foundation`. Le contrôleur DOIT le
/// posséder : c'est la seule façon de garantir structurellement qu'il n'est
/// **jamais recréé** au rebuild (interdit AD-2, symptôme visible du bug
/// historique). L'import y est donc autorisé **uniquement** sous une clause
/// `show` exacte — ce que la garde vérifie ligne à ligne. Sans le `show`,
/// `StatefulWidget`, `setState`, `Padding` et `Alignment` entreraient dans un
/// **fichier de contrôleur** qui ne doit rendre aucun pixel.
///
/// ## 🔴 CHAT-3 — la règle est RESSERRÉE PAR FICHIER, pas relâchée
///
/// CHAT-3 introduit le rendu neutre : `lib/src/presentation/render/` et
/// `lib/src/presentation/view/` rendent, eux, de vrais pixels et ont besoin de
/// `flutter/widgets.dart` en entier. La forme d'origine — « une seule
/// occurrence de `widgets.dart` dans tout `lib/`, et sous clause `show` » —
/// n'était pas transposable telle quelle.
///
/// Deux façons de la faire évoluer, et pourquoi une seule est acceptable :
/// * **relâcher** (autoriser `widgets.dart` nu partout) aurait rendu la garde
///   muette sur le contrôleur — précisément là où l'interdit AD-2 a un coût
///   mesuré. **Refusé.**
/// * **partitionner** : le contrôleur garde sa clause `show` EXACTE ; les
///   fichiers de rendu obtiennent un import nu, mais héritent en échange de
///   contraintes que le contrôleur n'avait pas besoin de porter
///   (`material`/`cupertino` toujours bannis, `ListView(children:)` banni,
///   `Semantics` exigé, cf. `z_chat_render_guard_test.dart`). **Retenu.**
///
/// La partition est vérifiée dans les deux sens : un fichier de rendu ne peut
/// pas se faire passer pour le contrôleur, et le contrôleur ne peut pas
/// s'attribuer l'import nu en se renommant — le chemin exact est asserté.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

/// Imports **strictement interdits** dans `lib/`.
const List<String> _banned = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:hooks_riverpod/',
  'package:get/',
  'package:get_it/',
  'package:provider/',
  'package:flutter_bloc/',
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
];

/// La **seule** forme autorisée d'import `flutter/widgets` DANS LE CONTRÔLEUR.
const String _allowedWidgetsImport =
    "import 'package:flutter/widgets.dart' show TextEditingController;";

/// Chemin (suffixe) du fichier du contrôleur — le régime « aucun pixel ».
const String _controllerPath = 'lib/src/presentation/z_chat_controller.dart';

/// Répertoires du régime « rendu » (CHAT-3) : import `widgets.dart` nu admis.
const List<String> _renderDirs = <String>[
  'lib/src/presentation/render/',
  'lib/src/presentation/view/',
];

String _norm(String path) => path.replaceAll(r'\', '/');

/// `true` si [path] est le fichier du contrôleur.
bool _isController(String path) => _norm(path).endsWith(_controllerPath);

/// `true` si [path] appartient au régime « rendu ».
bool _isRenderFile(String path) =>
    _renderDirs.any((String d) => _norm(path).contains(d));

/// Les règles de [_hardcoded] qui portent sur une **COULEUR**, et elles seules.
///
/// 🔴 C'est la granularité de l'exemption : le fichier de référence audité du
/// lot γ est exempté de CES DEUX règles, **jamais** des règles AD-13
/// (directionnalité) ni de `TextStyle(`. Une exemption « de fichier » en bloc
/// aurait laissé entrer un `Positioned(left:)` dans le seul fichier que
/// personne ne relit ligne à ligne.
const Set<String> _colorRules = <String>{r'\bColors\.', r'\bColor\(0x'};

/// Fichiers de RÉFÉRENCE audités, exemptés des seules règles de [_colorRules].
///
/// ⚠️ **Exception FR-26 ENCADRÉE** (arbitrage owner, 2026-08-04, étendu au chat
/// par le lot γ / CR-IFFD-72). Les trois conditions sont tenues :
/// 1. **centralisation** — c'est le fichier unique de sa famille ;
/// 2. **remplaçabilité** — chaque couleur a un jeton (`ZcrudTheme.chat*`) et un
///    paramètre (`ZChatNotebookSkin`), priorité paramètre > jeton > référence ;
/// 3. **exemption NOMINATIVE** — par nom de fichier exact, jamais un motif,
///    jamais un répertoire. Le même mécanisme que `_kLiteralExemptFiles`
///    (`z_chat_render_guard_test.dart`), et pour la même raison : une exemption
///    qui grossit sans bruit vide la garde, donc son cardinal est asserté.
///
/// 🔴 Ce que l'exemption **ne couvre pas**, et qui est mesuré ailleurs : que les
/// couleurs y soient *justifiées* (non dérivables d'un `ColorScheme`). Quatre
/// des sept familles du relevé legacy ont été REFUSÉES à ce titre —
/// cf. `z_chat_notebook_reference.dart` et sa garde dédiée.
const List<String> _kColorExemptFiles = <String>[
  'z_chat_notebook_reference.dart',
];

/// Motifs de style / couleur codés en dur (FR-26) et de directionnalité
/// interdite (AD-13).
const Map<String, String> _hardcoded = <String, String>{
  r'\bColors\.': 'couleur du catalogue Material codée en dur',
  r'\bColor\(0x': 'couleur littérale',
  r'\bTextStyle\(': 'style typographique codé en dur',
  r'\bEdgeInsets\.only\(\s*(left|right):': 'marge NON directionnelle (AD-13)',
  r'\bAlignment\.center(Left|Right)\b': 'alignement NON directionnel (AD-13)',
  r'\bTextAlign\.(left|right)\b': 'alignement de texte NON directionnel',
  r'\bPositioned\(\s*(left|right):': 'positionnement NON directionnel',
};

/// Les lignes d'import/export d'une source dé-commentée.
List<String> _directives(List<String> lines) => <String>[
  for (final String l in lines)
    if (l.trimLeft().startsWith('import ') || l.trimLeft().startsWith('export '))
      l.trim(),
];

void main() {
  group('🔴 AUCUN gestionnaire d\'état, jamais (AD-2/AD-15)', () {
    test('grep NÉGATIF sur toutes les sources de `lib/`', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in lib.entries) {
        for (final String d in _directives(e.value)) {
          scanned++;
          for (final String bad in _banned) {
            if (d.contains(bad)) offenders.add('${e.key} → $d');
          }
        }
      }
      // Contre-preuve de NON-VACUITÉ : le scan a bien vu des directives.
      expect(scanned, greaterThan(3),
          reason: '🔴 seulement $scanned directive(s) scannée(s) — la garde ne '
              'prouve rien');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 AD-2/AD-15 : la réactivité est Flutter-native '
            '(`ChangeNotifier`/`ValueListenable`). Le code spécifique à un '
            'gestionnaire d\'état vit UNIQUEMENT dans son package de binding '
            '(`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`).\n'
            '${offenders.join('\n')}',
      );
    });

    test('le CONTRÔLEUR n\'ouvre `flutter/widgets.dart` que sous sa clause '
        '`show` EXACTE', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> controllerWidgetImports = <String>[
        for (final MapEntry<String, List<String>> e in lib.entries)
          if (_isController(e.key))
            for (final String d in _directives(e.value))
              if (d.contains('package:flutter/widgets.dart')) d,
      ];
      expect(controllerWidgetImports, hasLength(1),
          reason: '🔴 GARDE VACUELLE : le fichier du contrôleur '
              '(`$_controllerPath`) est introuvable ou n\'importe plus '
              '`widgets.dart` — vu : $controllerWidgetImports');
      expect(
        controllerWidgetImports.single,
        _allowedWidgetsImport,
        reason: '🔴 l\'import a été ÉLARGI dans le CONTRÔLEUR. Sans la clause '
            '`show`, tout `flutter/widgets` y entre : `StatefulWidget`, '
            '`setState`, `Padding`, `Alignment`… dans un fichier qui ne rend '
            'aucun pixel. `TextEditingController` est la SEULE chose dont il '
            'ait besoin. Le rendu vit sous `presentation/render|view/`.',
      );
    });

    test('seuls les fichiers de RENDU ouvrent `widgets.dart` nu — la partition '
        'est exhaustive', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> offenders = <String>[];
      int rendering = 0;
      for (final MapEntry<String, List<String>> e in lib.entries) {
        for (final String d in _directives(e.value)) {
          if (!d.contains('package:flutter/widgets.dart')) continue;
          if (_isController(e.key)) continue; // couvert par le test ci-dessus
          if (_isRenderFile(e.key)) {
            rendering++;
            continue;
          }
          offenders.add('${e.key} → $d');
        }
      }
      expect(rendering, greaterThan(2),
          reason: '🔴 GARDE VACUELLE : seuls $rendering fichiers de rendu '
              'importent `widgets.dart` — le partitionneur ne voit rien');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 un fichier HORS `presentation/render|view/` s\'ouvre tout '
            '`flutter/widgets`. La partition CHAT-3 est : le rendu rend, le '
            'reste ne rend pas. Un troisième régime la dissoudrait.\n'
            '${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve R3 — le partitionneur distingue RÉELLEMENT les trois '
        'régimes', () {
      // Sans ceci, un partitionneur qui rendrait `true` partout laisserait les
      // deux tests ci-dessus passer sur n'importe quel fichier.
      expect(_isController('/x/lib/src/presentation/z_chat_controller.dart'),
          isTrue);
      expect(_isRenderFile('/x/lib/src/presentation/z_chat_controller.dart'),
          isFalse,
          reason: '🔴 le contrôleur se ferait passer pour un fichier de rendu '
              'et obtiendrait l\'import nu');
      expect(_isRenderFile('/x/lib/src/presentation/view/z_chat_block_view.dart'),
          isTrue);
      expect(_isRenderFile('/x/lib/src/presentation/render/z_chat_renderer.dart'),
          isTrue);
      expect(_isController('/x/lib/src/presentation/view/z_chat_block_view.dart'),
          isFalse);
      // Un fichier quelconque n'est NI l'un NI l'autre ⇒ il tombe dans les
      // `offenders` s'il ouvre `widgets.dart`.
      expect(_isController('/x/lib/src/presentation/z_chat_stream_progress.dart'),
          isFalse);
      expect(
          _isRenderFile('/x/lib/src/presentation/z_chat_stream_progress.dart'),
          isFalse);
    });

    test('🔬 contre-preuve — le détecteur voit une VRAIE directive et ignore la '
        'prose', () {
      final List<String> witness = <String>[
        "import 'package:provider/provider.dart';",
        "  final String s = 'package:provider/provider.dart';",
      ];
      final List<String> found = <String>[
        for (final String d in _directives(witness))
          for (final String bad in _banned)
            if (d.contains(bad)) d,
      ];
      expect(found, hasLength(1),
          reason: '🔴 soit la garde est aveugle à un import réel, soit elle '
              'accuse une simple chaîne — les deux la rendent inutilisable');
      expect(found.single, startsWith('import '));
    });
  });

  group('🔴 AUCUNE couleur ni style codés en dur (FR-26, AD-13)', () {
    test('grep NÉGATIF sur toutes les sources de `lib/`', () {
      final List<String> offenders = <String>[];
      int colorScanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        final bool colorExempt = _kColorExemptFiles
            .any((String f) => _norm(e.key).endsWith(f));
        for (int i = 0; i < e.value.length; i++) {
          for (final MapEntry<String, String> rule in _hardcoded.entries) {
            final bool isColorRule = _colorRules.contains(rule.key);
            if (!RegExp(rule.key).hasMatch(e.value[i])) continue;
            if (isColorRule && colorExempt) {
              colorScanned++;
              continue;
            }
            offenders.add('${e.key}:${i + 1} (${rule.value}) '
                '${e.value[i].trim()}');
          }
        }
      }
      // 🔴 NON-VACUITÉ de l'exemption : si le fichier de référence cessait de
      // porter la moindre couleur, l'exemption deviendrait décorative et
      // personne ne s'en apercevrait.
      expect(colorScanned, greaterThan(0),
          reason: '🔴 aucune couleur EXEMPTÉE n\'a été vue : soit le fichier de '
              'référence a perdu ses couleurs, soit le chemin d\'exemption ne '
              'passe plus par là — dans les deux cas, retirez l\'exemption.');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 FR-26 : aucun style ni couleur codés en dur dans un package '
            '— le thème est INJECTÉ (`ZcrudScope`/`ThemeExtension`). AD-13 : '
            'jamais `left`/`right`, toujours les variantes DIRECTIONNELLES '
            '(`EdgeInsetsDirectional`, `AlignmentDirectional`, '
            '`TextAlign.start/end`), sans quoi l\'interface est cassée en RTL.\n'
            '${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — chaque règle SAIT rougir sur son témoin', () {
      const Map<String, String> witnesses = <String, String>{
        r'\bColors\.': '  final c = Colors.red;',
        r'\bColor\(0x': '  const c = Color(0xFF112233);',
        r'\bTextStyle\(': '  const s = TextStyle(fontSize: 12);',
        r'\bEdgeInsets\.only\(\s*(left|right):':
            '  const p = EdgeInsets.only(left: 8);',
        r'\bAlignment\.center(Left|Right)\b': '  const a = Alignment.centerLeft;',
        r'\bTextAlign\.(left|right)\b': '  const t = TextAlign.left;',
        r'\bPositioned\(\s*(left|right):': '  Positioned(left: 4, child: x);',
      };
      expect(witnesses.keys.toSet(), _hardcoded.keys.toSet(),
          reason: '🔴 une règle sans témoin n\'est jamais prouvée mordante');
      for (final MapEntry<String, String> w in witnesses.entries) {
        expect(RegExp(w.key).hasMatch(w.value), isTrue,
            reason: '🔴 la règle `${w.key}` ne voit pas sa propre violation');
      }
      // …et les formes CONFORMES ne sont pas accusées (une garde qui crie au
      // loup finit désactivée — leçon E10).
      for (final String ok in <String>[
        '  const p = EdgeInsetsDirectional.only(start: 8);',
        '  const a = AlignmentDirectional.centerStart;',
        '  const t = TextAlign.start;',
        '  final c = theme.colorScheme.primary;',
      ]) {
        for (final String rule in _hardcoded.keys) {
          expect(RegExp(rule).hasMatch(ok), isFalse,
              reason: '🔴 FAUX POSITIF : `$rule` accuse `$ok`');
        }
      }
    });

    test('🔬 l\'exemption de COULEUR est NOMINATIVE, ÉTROITE et non pendante',
        () {
      // 1. Cardinal asserté : une exemption ne grossit jamais par accident.
      expect(_kColorExemptFiles, hasLength(1),
          reason: '🔴 une exemption a été AJOUTÉE à la garde anti-couleurs. '
              'L\'exception FR-26 vaut PAR FAMILLE et exige un fichier de '
              'référence UNIQUE : justifiez-la au point de déclaration et '
              'mettez ce compte à jour, délibérément.');
      // 2. Elle désigne un fichier qui EXISTE (une exemption pendante est une
      //    porte ouverte sur un nom que plus personne ne relit).
      final Iterable<String> paths = strippedLib().keys.map(_norm);
      for (final String f in _kColorExemptFiles) {
        expect(paths.any((String p) => p.endsWith(f)), isTrue,
            reason: '🔴 exemption PENDANTE : `$f` n\'existe plus.');
      }
      // 3. Elle est NOMINATIVE, pas un motif : un voisin du MÊME répertoire,
      //    au nom proche, n'en bénéficie PAS.
      bool exempt(String path) =>
          _kColorExemptFiles.any((String f) => _norm(path).endsWith(f));
      expect(
          exempt('/x/lib/src/presentation/view/z_chat_notebook_reference.dart'),
          isTrue);
      for (final String voisin in <String>[
        '/x/lib/src/presentation/view/z_chat_notebook_skin.dart',
        '/x/lib/src/presentation/view/z_chat_notebook_view.dart',
        '/x/lib/src/presentation/view/z_chat_notebook_reference_extra.dart',
        '/x/lib/src/presentation/render/z_chat_notebook_reference.dart.bak',
      ]) {
        expect(exempt(voisin), isFalse,
            reason: '🔴 l\'exemption attrape `$voisin` : elle n\'est plus '
                'nominative, c\'est un motif.');
      }
      // 4. Elle ne couvre QUE la couleur : les règles AD-13 restent opposables
      //    au fichier exempté lui-même.
      expect(_colorRules, hasLength(2));
      expect(_hardcoded.keys.toSet().difference(_colorRules), hasLength(5),
          reason: '🔴 le partage couleur / non-couleur a bougé : cinq règles '
              'AD-13+`TextStyle` doivent rester HORS exemption.');
    });
  });

  group('🔴 aucune dépendance TIERCE', () {
    test('le pubspec ne déclare que les dépendances NOMMÉMENT autorisées', () {
      final List<String> deps = _deps('dependencies');
      expect(deps, isNotEmpty, reason: '🔴 GARDE VACUELLE : aucune dépendance lue');
      expect(
        deps.toSet().difference(_kDepsAutorisees),
        isEmpty,
        reason: '🔴 le transport (HTTP/SSE), les SDK IA et les prompts restent '
            'CÔTÉ APP (AD-11/AD-12), derrière `ZChatStreamPort`. Vu : $deps',
      );
      expect(deps, containsAll(<String>['zcrud_chat_kernel', 'zcrud_core']));
    });

    test('🔬 CONTRÔLE POSITIF — l\'allowlist REFUSE un satellite qui porterait '
        'une dépendance tierce', () {
      // 🔴 **Garde RESSERRÉE en fin d'epic (MEDIUM).** Le critère était
      // `d != 'flutter' && !d.startsWith('zcrud_')` : n'importe quel paquet
      // `zcrud_*` passait. Or **22 satellites du dépôt portent une dépendance
      // tierce** — ajouter `zcrud_markdown` aurait fait entrer **Quill** dans
      // le socle du chat, garde VERTE, en violation directe d'AD-57. Le
      // critère est désormais NOMINATIF (patron
      // `packages/zcrud_menu/test/z_menu_purity_test.dart:17`).
      expect(<String>{'flutter', 'zcrud_core', 'zcrud_markdown'}
          .difference(_kDepsAutorisees), <String>{'zcrud_markdown'},
          reason: '🔴 l\'allowlist laisse passer un `zcrud_*` non listé : '
              'c\'est exactement le trou par lequel Quill serait entré.');
      expect(_kDepsAutorisees, hasLength(3),
          reason: '🔴 l\'allowlist a grossi. Une entrée de plus = une '
              'dépendance de plus dans le socle du chat : justifiez-la ici.');
    });

    test('🔴 FERMETURE TRANSITIVE — aucun paquet TIERS dans la fermeture de '
        '`zcrud_chat`', () {
      // Une allowlist DIRECTE ne prouve rien du transitif : un `zcrud_*`
      // autorisé pourrait porter Quill ou Syncfusion. Patron d'isolation
      // transitive de `z_sf_ad57_isolation_guard_test.dart:337-388`.
      final Map<String, Set<String>>? graph = _resolvedGraph();
      if (graph == null) {
        markTestSkipped('`dart pub deps --json` indisponible : preuve de '
            'graphe non rejouée. Le volet pubspec reste, lui, exécuté.');
        return;
      }
      // 🔴 La fermeture est amorcée sur les dépendances **NON-dev** : les
      // `dev_dependencies` (flutter_test, test, …) ne partent pas chez le
      // consommateur et les inclure noierait le signal.
      final Set<String> ferme = <String>{};
      for (final String d in _deps('dependencies')) {
        ferme
          ..add(d)
          ..addAll(_closure(graph, d));
      }
      final List<String> lourdes = _kTiercesLourdes
          .where((String t) => ferme.any((String p) => p.startsWith(t)))
          .toList();
      expect(lourdes, isEmpty,
          reason: '🔴 dépendance TIERCE LOURDE atteinte transitivement par '
              '`zcrud_chat` — AD-57 rouge. C\'est le scénario exact que '
              'l\'allowlist DIRECTE ne pouvait pas voir : un `zcrud_*` '
              'autorisé qui porte Quill ou Syncfusion. Vu : $lourdes');

      // 🔬 CONTRÔLE POSITIF de la fermeture : elle traverse RÉELLEMENT les
      // arêtes (sans quoi « aucune lourde » serait vrai d'un graphe vide)…
      expect(ferme, contains('zcrud_chat_kernel'),
          reason: '🔴 la fermeture ne suit aucune arête : garde VACUELLE.');
      // …et elle VOIT une dépendance lourde là où il y en a une.
      final Set<String> voisin = _closure(graph, 'zcrud_chat_syncfusion');
      expect(
        _kTiercesLourdes.where((String t) =>
            voisin.any((String p) => p.startsWith(t))),
        isNotEmpty,
        reason: '🔴 la fermeture ne voit pas les dépendances lourdes POURTANT '
            'présentes chez le voisin : elle serait aveugle chez nous aussi.',
      );
    });
  });
}

/// Dépendances directes AUTORISÉES — liste **nominative** (jamais un préfixe).
const Set<String> _kDepsAutorisees = <String>{
  'flutter',
  'zcrud_core',
  'zcrud_chat_kernel',
};

/// Préfixes des dépendances **lourdes** que AD-57 interdit au socle du chat.
///
/// 🔴 Ce n'est pas « toute dépendance non-SDK » : `zcrud_core` en porte
/// légitimement (dartz, intl, form_builder_validators) et le socle du chat en
/// hérite. Ce qu'AD-57 interdit, ce sont les **poids** — un consommateur du
/// chat ne doit tirer ni grille, ni éditeur riche, ni SDK backend, ni
/// gestionnaire d'état. Chacun de ces préfixes correspond à un paquet
/// RÉELLEMENT présent dans ce dépôt : la liste n'est pas hypothétique, et le
/// contrôle positif ci-dessus prouve qu'elle sait mordre.
const List<String> _kTiercesLourdes = <String>[
  'syncfusion',
  'flutter_quill',
  'quill_',
  'firebase',
  'cloud_firestore',
  'hive',
  'dio',
  'google_maps',
  'flutter_riverpod',
  'riverpod',
  'get_it',
  'provider',
  'graphite',
];

List<String> _deps(String bloc) {
  final List<String> lines =
      File('${packageRoot().path}/pubspec.yaml').readAsLinesSync();
  final int start = lines.indexWhere((String l) => l == '$bloc:');
  expect(start, greaterThanOrEqualTo(0), reason: 'bloc `$bloc:` absent');
  final List<String> deps = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    final String l = lines[i];
    if (l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#')) break;
    final RegExpMatch? m = RegExp(r'^  ([a-z_0-9]+):').firstMatch(l);
    if (m != null) deps.add(m.group(1)!);
  }
  return deps;
}

/// Graphe de dépendances RÉSOLU, ou `null` si `dart pub deps` est indisponible.
Map<String, Set<String>>? _resolvedGraph() {
  ProcessResult res;
  try {
    res = Process.runSync(
      'dart',
      const <String>['pub', 'deps', '--json'],
      workingDirectory: packageRoot().absolute.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null;
  }
  if (res.exitCode != 0) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(res.stdout as String);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['packages'] is! List) return null;
  final Map<String, Set<String>> graph = <String, Set<String>>{};
  for (final Object? p in decoded['packages'] as List) {
    if (p is! Map) continue;
    final Object? name = p['name'];
    if (name is! String) continue;
    final Set<String> deps = <String>{};
    final Object? raw = p['dependencies'];
    if (raw is List) {
      for (final Object? d in raw) {
        if (d is String) deps.add(d);
      }
    }
    graph[name] = deps;
  }
  return graph.isEmpty ? null : graph;
}

Set<String> _closure(Map<String, Set<String>> graph, String root) {
  final Set<String> seen = <String>{};
  final List<String> stack = <String>[root];
  while (stack.isNotEmpty) {
    final String cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    stack.addAll(graph[cur] ?? const <String>{});
  }
  seen.remove(root);
  return seen;
}
