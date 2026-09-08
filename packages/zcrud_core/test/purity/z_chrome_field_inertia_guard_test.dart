/// GARDE D'INERTIE des champs de CHROME RÉSOLU (repo-wide).
///
/// ## Le défaut visé
///
/// Un « chrome » est une classe-porteur : un résolveur y range, champ par
/// champ, le résultat de la chaîne `paramètre > jeton > référence`, et des
/// widgets le lisent pour peindre. Un champ de chrome **sans lecteur** est donc
/// exactement le même défaut qu'un jeton de thème inerte — déclaré, documenté,
/// résolu à chaque build, et peint nulle part — mais il vit dans un fichier de
/// RÉFÉRENCE, où la garde d'inertie du thème (`z_theme_token_inertia_guard`)
/// ne regarde pas : son périmètre s'arrête aux propriétés de `ZcrudTheme`.
///
/// Ce trou-ci s'est refermé sur un cas réel : un champ d'accent résolu à
/// chaque build de l'écran de session, dont AUCUN widget ne lisait la valeur —
/// et dont la garde locale assertait fidèlement qu'il suivait bien le rôle du
/// schéma, c'est-à-dire qu'elle **défendait le défaut** au lieu de le voir.
///
/// ## La règle
///
/// Pour chaque classe `Z…Chrome` de `packages/*/lib` qui est une classe-porteur
/// (pas un widget), chaque propriété `final` publique doit être LUE — motif
/// `.<nom>` — quelque part dans `packages/*/lib`, en dehors du corps de la
/// classe elle-même. Écrire le champ (`nom:` dans un constructeur nommé) ne
/// compte PAS : c'est précisément le geste que le défaut exécutait déjà.
///
/// Le lecteur légitime peut vivre dans le fichier de la classe (résolveur et
/// widget co-localisés) : seul le corps de la classe est retiré du corpus, pas
/// son fichier.
///
/// ## Ce que cette garde ne couvre PAS — dit explicitement
///
/// * Les `static const` des classes `Z…Reference`. Beaucoup ne sont lus que
///   dans leur propre fichier (une constante composée dans une table voisine),
///   et une règle textuelle y produit une majorité de faux positifs : mesuré
///   sur ce dépôt avant d'écrire cette garde. Le périmètre s'arrête donc aux
///   champs d'INSTANCE des chromes résolus.
/// * Les classes `Z…Chrome` qui `extends` un widget : les champs d'un widget
///   sont lus par son `State` via `widget.<nom>`, une forme différente que
///   cette garde n'a pas à arbitrer.
/// * Les porteurs analogues qui ne s'appellent pas `…Chrome` — la garde
///   s'ancre sur la convention de nommage, pas sur une analyse sémantique.
/// * L'homonymie : `.<nom>` est textuel, donc un nom très générique peut
///   paraître vivant par coïncidence. La garde vise le champ mort AJOUTÉ (nom
///   neuf, donc discriminant), pas un audit exhaustif.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Une classe-porteur `Z…Chrome` : un widget (`extends`) n'est pas capturé.
final RegExp _chromeRe = RegExp(r'^class (Z\w*Chrome) \{', multiLine: true);

/// Propriété `final` publique déclarée au niveau de la classe.
final RegExp _fieldRe = RegExp(r'^  final [^;]+? (\w+);', multiLine: true);

/// Un chrome trouvé dans les sources : son fichier, son nom, son corps et ses
/// bornes dans la source du fichier.
class _Chrome {
  _Chrome(this.file, this.name, this.body, this.start, this.end);

  final String file;
  final String name;
  final String body;
  final int start;
  final int end;

  List<String> get fields => _fieldRe
      .allMatches(body)
      .map((RegExpMatch m) => m.group(1)!)
      .where((String f) => !f.startsWith('_'))
      .toList();
}

/// Corps de la classe démarrant à [open] (index de `class …Chrome {`), borné
/// par la première accolade fermante en colonne 0.
({String body, int end}) _classBody(String source, int open) {
  final int bodyStart = source.indexOf('{', open) + 1;
  final int close = source.indexOf('\n}\n', bodyStart);
  final int end = close >= 0 ? close + 2 : source.length;
  return (body: source.substring(bodyStart, end), end: end);
}

void main() {
  final Directory pkgs = Directory('${sources.repoRoot().path}/packages');
  final List<File> files = pkgs
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) {
    final String p = f.path.replaceAll(r'\', '/');
    return p.endsWith('.dart') &&
        !p.endsWith('.g.dart') &&
        !p.endsWith('.freezed.dart') &&
        RegExp(r'/packages/[^/]+/lib/').hasMatch(p);
  }).toList();

  final Map<String, String> source = <String, String>{
    for (final File f in files) f.path: sources.strippedSource(f),
  };

  final List<_Chrome> chromes = <_Chrome>[
    for (final MapEntry<String, String> e in source.entries)
      for (final RegExpMatch m in _chromeRe.allMatches(e.value))
        () {
          final ({String body, int end}) b = _classBody(e.value, m.start);
          return _Chrome(e.key, m.group(1)!, b.body, m.start, b.end);
        }(),
  ];

  test('le balayage n\'est pas VACUEL', () {
    expect(files.length, greaterThanOrEqualTo(100),
        reason: 'corpus trop maigre — chemin cassé, garde VACUELLE');
    expect(source.values.join().length, greaterThan(100000),
        reason: 'corpus vide — garde VACUELLE');
    expect(chromes.length, greaterThanOrEqualTo(5),
        reason: '🔴 le scanner ne trouve plus les classes de chrome — garde '
            'INERTE (${chromes.map((_Chrome c) => c.name).toList()})');
    final int total =
        chromes.fold(0, (int a, _Chrome c) => a + c.fields.length);
    expect(total, greaterThanOrEqualTo(50),
        reason: '🔴 le scanner ne trouve plus les champs — garde INERTE');
  });

  test(
      '🔴 INERTIE : tout champ public d\'un chrome résolu a un LECTEUR dans '
      '`packages/*/lib`', () {
    final List<String> dead = <String>[];
    for (final _Chrome c in chromes) {
      // Corpus = tout `packages/*/lib`, MOINS le corps de la classe : un
      // lecteur co-localisé dans le même fichier reste légitime, mais
      // l'écriture du champ par le constructeur ne peut pas se compter
      // elle-même comme sa propre preuve de vie.
      final StringBuffer corpus = StringBuffer();
      for (final MapEntry<String, String> e in source.entries) {
        if (e.key != c.file) {
          corpus.writeln(e.value);
        } else {
          corpus.writeln(e.value.substring(0, c.start));
          corpus.writeln(e.value.substring(c.end));
        }
      }
      final String text = corpus.toString();
      for (final String f in c.fields) {
        if (!RegExp('\\.$f\\b').hasMatch(text)) dead.add('${c.name}.$f');
      }
    }
    expect(
      dead,
      isEmpty,
      reason: '🔴 CHAMP(S) DE CHROME MORT(S) : $dead — résolu(s) à chaque '
          'build et lu(s) par AUCUN site de rendu de `packages/*/lib`. '
          'Câblez le lecteur (le champ doit peindre ce que sa dartdoc '
          'promet), ou retirez le champ — jamais une valeur résolue sans '
          'consommateur.',
    );
  });

  test('CONTRE-PREUVE : le scanner ATTRAPE un champ ajouté sans lecteur', () {
    // La garde ci-dessus serait verte par construction si le scanner ne savait
    // rien détecter. On lui soumet donc une source MUTÉE dont on connaît le
    // défaut : un champ au nom certainement absent du dépôt.
    final _Chrome sample = chromes.first;
    const String ghost = 'zGhostFieldNeverRead';
    final String mutedBody =
        '${sample.body}\n  final Object? $ghost;\n';
    final _Chrome muted = _Chrome(
      sample.file,
      sample.name,
      mutedBody,
      sample.start,
      sample.end,
    );
    expect(muted.fields, contains(ghost),
        reason: 'la mutation n\'a pas été vue par le scanner de champs');
    final String corpus = source.values.join('\n');
    expect(RegExp('\\.$ghost\\b').hasMatch(corpus), isFalse,
        reason: 'le nom fantôme existe déjà dans le dépôt — contre-preuve '
            'invalide, choisissez-en un autre');
  });
}
