// Pureté du paquet — grep NÉGATIF outillé (AD-2/AD-11/AD-13/FR-26).
//
// Ce paquet a le droit à Syncfusion (c'est sa raison d'être). Il n'a PAS le
// droit à : un gestionnaire d'état, un client réseau, une couleur/dimension
// codée en dur autre que la cible tactile normative, une variante NON
// directionnelle, ou une chaîne d'interface écrite en dur.
//
// 🔴 CONTRÔLE POSITIF : chaque règle est rejouée sur un témoin synthétique dans
// le même run. Une garde de « grep négatif » est verte par défaut — y compris
// quand elle ne lit aucun fichier, ou quand son motif ne peut plus matcher.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory repoRoot() {
  Directory d = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${d.path}/melos.yaml').existsSync()) return d;
    final Directory parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  fail('Racine du dépôt introuvable depuis ${Directory.current.path}');
}

/// Retire commentaires de ligne (`//`, `///`) et de bloc (`/* … */`) d'une
/// source Dart, littéraux de chaîne préservés (`//` reconnu AVANT `/*`).
///
/// 🔴 P0D2 : sans ce filtre, toutes les règles de ce fichier (imports bannis,
/// motifs RTL, couleurs, `Text('…')` littéral) rougiraient sur leur propre
/// prose dartdoc — et pire, une clé RÉELLEMENT morte pourrait rester GREEN si
/// son nom n'apparaissait plus qu'en commentaire (garde rendue AVEUGLE à la
/// régression qu'elle est censée détecter). Jumeau de `stripDartComments` dans
/// `z_sf_ad57_isolation_guard_test.dart` (même paquet, même patron).
String stripDartComments(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < src.length) {
    final String c = src[i];
    final String next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= src.length ? i + 2 : src.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final String quote = c;
      out.write(c);
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          out.write(src.substring(i, i + 2 <= src.length ? i + 2 : i + 1));
          i += 2;
          continue;
        }
        out.write(src[i]);
        if (src[i] == quote || src[i] == '\n') {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Sources de `lib/` de CE paquet, indexées par chemin relatif, commentaires
/// RETIRÉS (P0D2 — cf. [stripDartComments]).
Map<String, String> libSources() {
  final Directory lib = Directory(
    '${repoRoot().path}/packages/zcrud_chat_syncfusion/lib',
  );
  final Map<String, String> out = <String, String>{};
  for (final FileSystemEntity f in lib.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    out[f.path.substring(lib.path.length + 1)] =
        stripDartComments(f.readAsStringSync());
  }
  return out;
}

/// Imports interdits (AD-2/AD-15 : aucun gestionnaire d'état ; AD-11/AD-12 :
/// aucun transport ni SDK IA — ils restent côté app).
const List<String> kBannedImports = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:hooks_riverpod/',
  'package:get/',
  'package:get_it/',
  'package:provider/',
  'package:dio/',
  'package:http/',
  'package:firebase_',
  'package:cloud_firestore/',
];

/// `package:` AUTORISÉS dans `lib/` — liste **nominative**, la seule qui
/// décide.
///
/// Toute autre origine fait rougir, qu'elle ait été prévue ou non : c'est la
/// différence entre une allowlist et [kBannedImports], qui ne peut interdire
/// que ce que quelqu'un a pensé à y écrire.
const Set<String> kImportsAutorises = <String>{
  'package:flutter/',
  'package:syncfusion_flutter_chat/',
  'package:zcrud_core/',
  'package:zcrud_chat/',
  'package:zcrud_chat_kernel/',
  'package:zcrud_chat_syncfusion/',
};

/// Motifs NON directionnels bannis (AD-13).
final List<RegExp> kNonDirectional = <RegExp>[
  RegExp(r'EdgeInsets\.only\(\s*(left|right)\s*:'),
  RegExp(r'Alignment\.center(Left|Right)\b'),
  RegExp(r'Positioned\(\s*(left|right)\s*:'),
  RegExp(r'TextAlign\.(left|right)\b'),
];

/// Littéraux de chaîne d'une ligne, interpolations `${…}` / `$ident` RETIRÉES
/// (leur contenu est du CODE, pas du texte affiché).
///
/// 🔴 Balayage MANUEL plutôt qu'une regex — jumeau exact de celui de
/// `zcrud_chat/test/z_chat_render_guard_test.dart` : une regex de littéral Dart
/// doit gérer les deux guillemets, les échappements et l'imbrication, et la
/// première rédaction là-bas en portait une syntaxiquement invalide.
List<String> stringLiterals(String line) {
  final List<String> out = <String>[];
  int i = 0;
  while (i < line.length) {
    final String c = line[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final String quote = c;
    final StringBuffer buf = StringBuffer();
    i++;
    while (i < line.length && line[i] != quote) {
      if (line[i] == r'\') {
        i += 2;
        continue;
      }
      buf.write(line[i]);
      i++;
    }
    i++; // le guillemet fermant
    out.add(
      buf
          .toString()
          .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\$\w+'), ''),
    );
  }
  return out;
}

/// Applique une règle et rend les fichiers fautifs.
List<String> offenders(Map<String, String> sources, bool Function(String) bad) =>
    <String>[
      for (final MapEntry<String, String> e in sources.entries)
        if (bad(e.value)) e.key,
    ]..sort();

void main() {
  final Map<String, String> sources = libSources();

  test('la garde a réellement lu les sources (anti faux-vert)', () {
    expect(sources.length, greaterThanOrEqualTo(6));
    expect(sources.keys, contains('zcrud_chat_syncfusion.dart'));
    expect(
      sources.keys,
      contains('src/presentation/z_sf_assist_shell_renderer.dart'),
      reason: '🔴 GARDE VACUELLE : le backend du port a disparu — toutes les '
          'règles ci-dessous porteraient sur un paquet sans coquille',
    );
  });

  test('AD-2/AD-11 · aucun gestionnaire d\'état, aucun transport (denylist '
      'HISTORIQUE, conservée)', () {
    for (final String banned in kBannedImports) {
      expect(
        offenders(sources, (String s) => s.contains(banned)),
        isEmpty,
        reason: 'import interdit : $banned',
      );
    }
    // CONTRÔLE POSITIF : la règle sait rougir.
    expect(
      offenders(<String, String>{
        'temoin.dart': "import 'package:dio/dio.dart';",
      }, (String s) => s.contains('package:dio/')),
      isNotEmpty,
    );
  });

  test('🔴 AD-57 · les `package:` importés sont NOMMÉMENT autorisés '
      '(allowlist)', () {
    // 🔴 **Garde RESSERRÉE en fin d'epic (MEDIUM).** [kBannedImports] est une
    // **denylist figée** : elle ne connaît que ce que quelqu'un a pensé à y
    // écrire. Un `package:flutter_quill/`, un `package:graphite/`, un
    // `package:hive/` — tous présents dans ce dépôt — passaient VERTS. Une
    // denylist ne peut pas énumérer l'avenir ; une allowlist, si. Elle est
    // conservée en plus (elle nomme le motif et sert de contrôle positif),
    // mais ce n'est plus elle qui décide.
    final List<String> offenders = <String>[];
    final RegExp directive = RegExp(
      r"""^\s*(?:import|export)\s+['"](package:[^/'"]+)/""",
      multiLine: true,
    );
    for (final MapEntry<String, String> e in sources.entries) {
      for (final RegExpMatch m in directive.allMatches(e.value)) {
        final String pkg = '${m.group(1)!}/';
        if (!kImportsAutorises.contains(pkg)) {
          offenders.add('${e.key}: $pkg');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '🔴 `package:` NON AUTORISÉ dans `lib/`. Ce paquet a droit à '
            'Syncfusion — c\'est sa raison d\'être — et à rien d\'autre. '
            'Ajouter une entrée à `kImportsAutorises` est un geste '
            'DÉLIBÉRÉ.\n${offenders.join('\n')}');

    // Non-vacuité : la garde a vu de vrais imports, dont celui qui justifie le
    // paquet.
    final Set<String> vus = <String>{
      for (final MapEntry<String, String> e in sources.entries)
        for (final RegExpMatch m in directive.allMatches(e.value))
          '${m.group(1)!}/',
    };
    expect(vus, contains('package:syncfusion_flutter_chat/'),
        reason: '🔴 GARDE VACUELLE : l\'extracteur ne voit plus rien.');

    // 🔬 CONTRÔLE POSITIF : un import que la denylist IGNORE est bien refusé
    // par l\'allowlist. C\'est la démonstration littérale du trou corrigé.
    const String quill = 'package:flutter_quill/';
    expect(kBannedImports.any(quill.startsWith), isFalse,
        reason: 'la denylist ne connaît PAS Quill — c\'est le point.');
    expect(kImportsAutorises.contains(quill), isFalse,
        reason: '🔴 l\'allowlist laisserait entrer Quill.');
  });

  test('AD-13 · aucune variante NON directionnelle', () {
    for (final RegExp p in kNonDirectional) {
      expect(
        offenders(sources, (String s) => p.hasMatch(s)),
        isEmpty,
        reason: 'variante non directionnelle : ${p.pattern}',
      );
    }
    expect(
      offenders(<String, String>{
        'temoin.dart': 'const a = Alignment.centerLeft;',
      }, (String s) => kNonDirectional[1].hasMatch(s)),
      isNotEmpty,
    );
  });

  test('FR-26 · aucune couleur codée en dur', () {
    final RegExp color = RegExp(r'Color\(0x|Colors\.[a-z]');
    expect(offenders(sources, color.hasMatch), isEmpty);
    expect(
      offenders(<String, String>{
        'temoin.dart': 'const c = Color(0xFF0000FF);',
      }, color.hasMatch),
      isNotEmpty,
    );
  });

  test('FR-26 · toutes les chaînes affichées passent par `label()`', () {
    // Le seul texte que la coquille produit vient de `label(context, k…)` : la
    // garde exige que chaque clé déclarée soit RÉELLEMENT utilisée, et qu'aucun
    // `Text('…')` littéral n'existe.
    final RegExp literalText = RegExp(r'''Text\(\s*['"]''');
    expect(
      offenders(sources, literalText.hasMatch),
      isEmpty,
      reason: 'un `Text(\'…\')` littéral est une chaîne d\'interface en dur',
    );
    expect(
      offenders(<String, String>{
        'temoin.dart': "Widget b() => Text('Bienvenue');",
      }, literalText.hasMatch),
      isNotEmpty,
    );

    final String labels = sources['src/presentation/z_sf_assist_labels.dart']!;
    final Iterable<String> keys = RegExp(r'const String (kZSfAssistLabel\w+)')
        .allMatches(labels)
        .map((RegExpMatch m) => m.group(1)!)
        .where((String k) => k != 'kZSfAssistLabelPrefix');
    expect(keys, isNotEmpty);
    final String shell =
        sources['src/presentation/z_sf_assist_shell_renderer.dart']!;
    for (final String k in keys) {
      expect(
        shell.contains(k),
        isTrue,
        reason: '$k est déclarée mais jamais résolue : clé morte. Une clé que '
            'le paquet ne consomme plus est une promesse faite à l\'hôte qu\'il '
            'alimente pour rien — c\'est ce qu\'étaient devenues '
            '`…conversation` et `…streaming` une fois la région live et la '
            'tuile de streaming rendues au socle (CHAT-3b).',
      );
    }
  });

  // 🔴 GARDE JUMELLE NON MORDANTE, TROUVÉE ET RETENDUE PAR CHAT-3b.
  //
  // La règle ci-dessus est un motif de LIGNE ancré sur `Text(` suivi d'un
  // guillemet. `zcrud_chat` a mesuré par R3 (injection n°5) que cette forme
  // laisse passer un littéral parfaitement banal :
  //
  //     child: Text(
  //       expanded ? 'Afficher moins' : 'Afficher plus',
  //     ),
  //
  // — le littéral est sur la ligne SUIVANTE, et derrière un ternaire. `zcrud_chat`
  // a RESSERRÉ sa garde en conséquence (« aucun littéral porteur de mot dans un
  // fichier de rendu ») ; ce paquet-ci, jumeau, était resté sur la forme faible.
  // C'est exactement la classe de défaut que CLAUDE.md décrit : « une CR qui
  // change un contrat doit chercher ses gardes JUMELLES dans les autres
  // packages ». La cible n'est pas baissée, elle est ALIGNÉE.
  test('FR-26 (RESSERRÉ) · aucun littéral PORTEUR DE MOT dans `presentation/` '
      '— quelle que soit la mise en forme', () {
    final RegExp wordBearing = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]{4,}');
    final List<String> faults = <String>[];
    for (final MapEntry<String, String> e in sources.entries) {
      if (!e.key.startsWith('src/presentation/')) continue;
      // Le fichier qui DÉCLARE les clés en porte forcément la valeur.
      if (e.key.endsWith('z_sf_assist_labels.dart')) continue;
      int no = 0;
      for (final String raw in e.value.split('\n')) {
        no++;
        final String line = raw.trimLeft();
        // Une dartdoc/commentaire n'atteint jamais l'utilisateur ; une URI
        // d'import est un littéral, jamais un texte affiché.
        if (line.startsWith('///') ||
            line.startsWith('//') ||
            line.startsWith('import ') ||
            line.startsWith('export ')) {
          continue;
        }
        if (line.contains('ValueKey')) continue;
        for (final String literal in stringLiterals(raw)) {
          if (wordBearing.hasMatch(literal)) {
            faults.add('${e.key}:$no: "$literal"');
          }
        }
      }
    }
    expect(faults, isEmpty,
        reason: '🔴 un mot écrit en dur dans la coquille. Tout texte affiché '
            'passe par `label(context, clé)`.\n${faults.join('\n')}');

    // CONTRÔLE POSITIF — la forme EXACTE que la règle faible laissait passer.
    const String temoin = "        expanded ? 'Afficher moins' : 'Afficher plus',";
    expect(RegExp(r'''Text\(\s*['"]''').hasMatch(temoin), isFalse,
        reason: '🔴 si la règle FAIBLE voyait déjà ce témoin, le resserrement '
            'serait décoratif — et ce test mentirait sur son utilité');
    expect(stringLiterals(temoin).where(wordBearing.hasMatch).toList(),
        <String>['Afficher moins', 'Afficher plus']);
    // …et les formes CONFORMES du paquet ne sont PAS accusées.
    for (final String ok in <String>[
      '    final String userName = label(context, kZSfAssistLabelUserAuthor);',
      r"      key: ValueKey<String>('stream#$requestId'),",
      "          data: '',",
    ]) {
      final bool flagged = !ok.contains('ValueKey') &&
          stringLiterals(ok).any(wordBearing.hasMatch);
      expect(flagged, isFalse,
          reason: '🔴 FAUX POSITIF sur `$ok` — une garde qui crie au loup finit '
              'désactivée');
    }
  });

  test('AD-57 · `syncfusion` n\'apparaît que dans la coquille et le barrel', () {
    // Contre-garde interne : la normalisation du flux (`lib/src/data/`) doit
    // rester PUR-DART. Si Syncfusion y entrait, on aurait re-mélangé les deux
    // frontières que ce paquet sépare.
    final List<String> dataFiles = sources.keys
        .where((String k) => k.startsWith('src/data/'))
        .toList();
    expect(dataFiles, isNotEmpty);
    for (final String f in dataFiles) {
      expect(
        sources[f]!.contains('syncfusion'),
        isFalse,
        reason: '$f : la normalisation du fil ne dépend pas de Syncfusion.',
      );
      expect(
        sources[f]!.contains('package:flutter/'),
        isFalse,
        reason: '$f : la normalisation du fil est PUR-DART.',
      );
    }
  });
}
