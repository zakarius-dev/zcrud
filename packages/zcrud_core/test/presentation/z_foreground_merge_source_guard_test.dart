/// **CR-IFFD-43 — verrou STRUCTUREL** : le duo d'enveloppes d'héritage
/// (`IconTheme.merge` / `DefaultTextStyle.merge`) ne peut plus porter de
/// **COULEUR** hors de la primitive [ZForegroundOverride].
///
/// 🔴 **Pourquoi une garde de SOURCE et pas une garde de rendu.** CR-IFFD-42 a
/// établi que ce duo est **structurellement insuffisant** pour colorer un slot
/// d'hôte : les rôles de `TextTheme` sont `inherit: false`, donc un
/// `Text(x, style: Theme.of(c).textTheme.titleSmall)` court-circuite entièrement
/// le `DefaultTextStyle` ambiant. Une garde de rendu ne peut être écrite que
/// **site par site**, après coup. Elle ne dit rien du site que quelqu'un écrira
/// demain en recopiant le duo. C'est exactement ce que le lot v0.37.0 avait
/// consigné comme non verrouillé — et qu'il ne pouvait pas verrouiller, parce
/// que deux sites légitimes portaient encore une couleur. Ces deux sites sont
/// désormais migrés : l'obstacle est tombé.
///
/// 🔴 **Ce que la garde mesure vraiment.** Pas « y a-t-il un `merge` » — un
/// `merge` de **taille** ou de **poids** est parfaitement légitime et ne
/// souffre d'aucun défaut (il n'entre en concurrence avec aucune couleur de
/// `TextTheme`). La garde n'accuse que le `merge` portant une **couleur**, et le
/// prouve : elle vérifie sur des extraits synthétiques qu'elle **rougit** sur un
/// `merge` coloré et **reste verte** sur un `merge` de taille / de poids / de
/// décoration.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Fichiers où le duo d'enveloppes a le droit de porter une couleur : la
/// primitive elle-même, et elle seule.
const Set<String> _kAllowed = <String>{
  'z_foreground_override.dart',
};

/// Racine du dépôt, quel que soit le CWD (racine du workspace ou package).
///
/// 🔴 Ancrage par remontée jusqu'à `melos.yaml` — jamais un `../` relatif : la
/// convention `melos exec` lance chaque suite depuis le dossier de SON package.
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Tous les `.dart` **sources** de `packages/*/lib` (hors code généré).
List<File> _packageLibDartFiles() {
  final Directory packages = Directory('${_repoRoot().path}/packages');
  expect(packages.existsSync(), isTrue, reason: 'packages/ introuvable');
  return packages
      .listSync()
      .whereType<Directory>()
      .map((Directory d) => Directory('${d.path}/lib'))
      .where((Directory d) => d.existsSync())
      .expand((Directory d) => d.listSync(recursive: true, followLinks: false))
      .whereType<File>()
      .where(
        (File f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'),
      )
      .toList();
}

/// Retire les commentaires (LIGNE **et** BLOC) en préservant le nombre de
/// lignes, pour que les numéros signalés restent exacts.
///
/// 🔴 Indispensable ici : les dartdoc de ce dépôt **citent littéralement** le
/// motif interdit pour documenter qu'il l'est (`z_foreground_override.dart`,
/// `z_inverted_surface.dart`, et ce fichier même). Sans dépouillement, la garde
/// s'accuserait elle-même — un faux positif qui aurait forcé à l'élargir
/// jusqu'à la rendre inerte.
///
/// L'ordre compte : le commentaire de LIGNE est reconnu AVANT `/*` (une dartdoc
/// écrivant `packages/*/lib` ouvrirait sinon un bloc jamais refermé et
/// avalerait la fin du fichier, rendant la garde silencieusement VACUELLE). Les
/// littéraux de chaîne sont sautés pour la même raison (une URL contient `//`).
String _stripComments(String source) {
  final StringBuffer out = StringBuffer();
  bool inBlock = false;
  for (final String raw in source.split('\n')) {
    int i = 0;
    while (i < raw.length) {
      final String c = raw[i];
      final String next = i + 1 < raw.length ? raw[i + 1] : '';
      if (inBlock) {
        if (c == '*' && next == '/') {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '/') break;
      if (c == '/' && next == '*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') {
        final String quote = c;
        out.write(c);
        i++;
        while (i < raw.length) {
          if (raw[i] == r'\') {
            out.write(raw[i]);
            i++;
            if (i < raw.length) {
              out.write(raw[i]);
              i++;
            }
            continue;
          }
          out.write(raw[i]);
          final bool end = raw[i] == quote;
          i++;
          if (end) break;
        }
        continue;
      }
      out.write(c);
      i++;
    }
    out.write('\n');
  }
  return out.toString();
}

/// Un site de `merge` détecté.
class _MergeSite {
  const _MergeSite({
    required this.call,
    required this.line,
    required this.head,
  });

  /// `IconTheme.merge` ou `DefaultTextStyle.merge`.
  final String call;

  /// Ligne 1-based dans la source dépouillée (= ligne réelle du fichier).
  final int line;

  /// Les arguments **hors `child:`** — la seule région qui décide du style
  /// imposé. Le sous-arbre `child:` est EXCLU : il porte le contenu, où une
  /// couleur est évidemment légitime, et l'y scanner aurait produit un déluge de
  /// faux positifs qui aurait tué la garde.
  final String head;
}

/// Les deux enveloppes d'héritage surveillées.
const List<String> _kCalls = <String>[
  'IconTheme.merge(',
  'DefaultTextStyle.merge(',
];

/// Extrait les sites de `merge` d'une source **déjà dépouillée**.
List<_MergeSite> _mergeSites(String stripped) {
  final List<_MergeSite> sites = <_MergeSite>[];
  for (final String call in _kCalls) {
    int from = 0;
    while (true) {
      final int at = stripped.indexOf(call, from);
      if (at < 0) break;
      from = at + call.length;
      final int open = at + call.length - 1; // la '(' du call
      final String? args = _balanced(stripped, open);
      if (args == null) continue;
      sites.add(
        _MergeSite(
          call: call.substring(0, call.length - 1),
          line: '\n'.allMatches(stripped.substring(0, at)).length + 1,
          head: _beforeChild(args),
        ),
      );
    }
  }
  return sites;
}

/// Contenu entre la parenthèse ouvrante en [open] et sa fermante appariée.
/// `null` si non appariée (source tronquée) — un tel cas est signalé par la
/// borne de non-vacuité, pas silencieusement ignoré.
String? _balanced(String s, int open) {
  int depth = 0;
  for (int i = open; i < s.length; i++) {
    final String c = s[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return s.substring(open + 1, i);
    }
  }
  return null;
}

/// Les arguments jusqu'au `child:` de **premier niveau** (exclu).
String _beforeChild(String args) {
  int depth = 0;
  for (int i = 0; i < args.length; i++) {
    final String c = args[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 && args.startsWith('child:', i)) return args.substring(0, i);
  }
  return args;
}

/// Marqueurs de COULEUR — et rien d'autre.
///
/// `[Cc]olor\s*:` attrape aussi bien `color:` que `backgroundColor:` ou
/// `decorationColor:` (toutes des couleurs), tandis que `size:`, `fontSize:`,
/// `fontWeight:`, `letterSpacing:`, `height:`, `decoration:` ne matchent pas.
/// `Color(`, `Colors.` et `ColorScheme` couvrent l'expression passée sans nom
/// d'argument nommé « color ».
final RegExp _kColorMarker = RegExp(
  r'[Cc]olor\s*:|\bColor\s*\(|\bColors\s*\.|\bColorScheme\b',
);

bool _carriesColor(_MergeSite site) => _kColorMarker.hasMatch(site.head);

void main() {
  group('CR-IFFD-43 — la garde DISCRIMINE la couleur du reste', () {
    // 🔴 Cette première paire prouve que la garde n'est pas « toujours verte »
    // ni « toujours rouge » : elle est vérifiée sur des extraits SYNTHÉTIQUES
    // dont on connaît le verdict attendu. Sans elle, un détecteur cassé (regex
    // qui ne matche jamais) passerait la suite entière avec un vert vide.
    void expectVerdict(String snippet, {required bool colored}) {
      final List<_MergeSite> sites = _mergeSites(_stripComments(snippet));
      expect(sites, hasLength(1), reason: 'extrait mal formé : $snippet');
      expect(
        _carriesColor(sites.single),
        colored,
        reason: 'verdict inattendu sur : $snippet',
      );
    }

    test('un `merge` de COULEUR est détecté', () {
      expectVerdict(
        'IconTheme.merge(data: IconThemeData(color: c), child: x)',
        colored: true,
      );
      expectVerdict(
        'DefaultTextStyle.merge(style: TextStyle(color: c), child: x)',
        colored: true,
      );
      expectVerdict(
        'IconTheme.merge(data: IconThemeData(size: s, color: c), child: x)',
        colored: true,
      );
    });

    test('un `merge` de TAILLE / POIDS / DÉCORATION reste vert', () {
      expectVerdict(
        'IconTheme.merge(data: IconThemeData(size: 24), child: x)',
        colored: false,
      );
      expectVerdict(
        'DefaultTextStyle.merge(style: TextStyle(fontWeight: FontWeight.w500), '
        'child: x)',
        colored: false,
      );
      expectVerdict(
        'DefaultTextStyle.merge(style: TextStyle(fontSize: 14, height: 1.2, '
        'letterSpacing: 0.5), child: x)',
        colored: false,
      );
      expectVerdict(
        'DefaultTextStyle.merge(style: const TextStyle(decoration: '
        'TextDecoration.lineThrough), child: x)',
        colored: false,
      );
    });

    test('une couleur portée par le CHILD n\'accuse pas le `merge`', () {
      // Le sous-arbre `child:` est du CONTENU : une `Icon(color: …)` posée là
      // est légitime. Scanner le child aurait rendu la garde inutilisable.
      expectVerdict(
        'IconTheme.merge(data: IconThemeData(size: 24), '
        'child: Icon(Icons.a, color: c))',
        colored: false,
      );
    });
  });

  group('CR-IFFD-43 — aucun `merge` COLORÉ hors de la primitive', () {
    late List<File> files;

    setUpAll(() => files = _packageLibDartFiles());

    test('la garde n\'est pas VACUELLE : elle voit bien des sites', () {
      expect(
        files.length,
        greaterThanOrEqualTo(200),
        reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) balayé(s) dans '
            'packages/*/lib — un balayage quasi vide signale un chemin cassé.',
      );
      final int total = files
          .map((File f) => _mergeSites(_stripComments(f.readAsStringSync())))
          .expand((List<_MergeSite> s) => s)
          .length;
      expect(
        total,
        greaterThanOrEqualTo(5),
        reason: '🔴 GARDE VACUELLE : $total site(s) de `merge` détecté(s). Le '
            'dépôt en porte plusieurs (tous LÉGITIMES, de taille ou de poids) ; '
            'zéro signifierait que le détecteur est cassé, pas que le dépôt est '
            'propre.',
      );
    });

    test('🔴 aucun `IconTheme.merge` / `DefaultTextStyle.merge` ne porte de '
        'couleur hors de `ZForegroundOverride`', () {
      final List<String> offenders = <String>[];
      for (final File f in files) {
        final String name = f.uri.pathSegments.last;
        if (_kAllowed.contains(name)) continue;
        for (final _MergeSite site
            in _mergeSites(_stripComments(f.readAsStringSync()))) {
          if (_carriesColor(site)) {
            offenders.add(
              '${f.path.split('/packages/').last}:${site.line} — '
              '${site.call} porte une couleur',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 CR-IFFD-42 REJOUÉE : le duo `IconTheme.merge` / '
            '`DefaultTextStyle.merge` n\'atteint QUE le contenu qui hérite. Un '
            'slot d\'hôte stylé depuis `Theme.of(context).textTheme.*` '
            '(rôles `inherit: false`) garde la couleur AMBIANTE et reste '
            'illisible. Utiliser `ZForegroundOverride` (zcrud_core), qui '
            'réécrit AUSSI `ThemeData.textTheme` / `ThemeData.iconTheme`.\n'
            'Sites fautifs :\n  ${offenders.join('\n  ')}',
      );
    });

    test('la primitive elle-même EST bien la seule dérogation', () {
      // Volet anti-régression de l'allowlist : si `ZForegroundOverride` cessait
      // un jour de poser le duo (refonte, renommage de fichier), l'exemption
      // deviendrait une porte ouverte silencieuse.
      final File primitive = File(
        '${_repoRoot().path}/packages/zcrud_core/lib/src/presentation/theme/'
        'z_foreground_override.dart',
      );
      expect(primitive.existsSync(), isTrue);
      final List<_MergeSite> sites = _mergeSites(
        _stripComments(primitive.readAsStringSync()),
      );
      expect(sites.where(_carriesColor), hasLength(2),
          reason: '🔴 la primitive doit poser EXACTEMENT les deux enveloppes '
              'colorées (icône + texte). Si ce n\'est plus le cas, '
              'l\'allowlist protège du vide.');
    });
  });
}
