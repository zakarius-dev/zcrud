// GARDE D'INERTIE des jetons de thème.
//
// Le défaut visé : un jeton public de `ZcrudTheme`, documenté, INERTE —
// déclaré (constructeur, copyWith, lerp) mais lu par AUCUN site de rendu.
// L'hôte le pose, le croit actif, et rien ne rougit — c'est l'histoire de
// `accentBarHeight`, resté « hauteur future » sans consommateur de champ,
// exactement la classe de défaut que la garde d'inertie des configs
// (`z_field_config_inertia_guard_test.dart`) ferme pour `z_field_config.dart`
// — mais son périmètre ne couvrait pas le thème : ce trou-ci le ferme.
//
// Règle : chaque propriété `final` publique de `ZcrudTheme` est
// - lue par au moins un site de `packages/*/lib` HORS `z_theme.dart` (motif
//   `.<nom>`, code strippé — les consommateurs légitimes vivent aussi dans
//   les satellites : `zcrud_study`, `zcrud_flashcard`, `zcrud_chat`…), OU
// - consommée DANS `z_theme.dart` même par un corps de MÉTHODE de rendu
//   (ex. `inputDecoration`), inscrite nominativement ci-dessous et vérifiée
//   MÉCANIQUEMENT (le nom doit apparaître dans le corps de la méthode citée —
//   jamais une exemption sur parole).
//
// 🔴 Les listes sont LUES DANS LA SOURCE, jamais recopiées ; le code est
// STRIPPÉ de ses commentaires avant analyse (discipline des gardes du dépôt).
//
// Limite assumée (la même que la garde jumelle) : le motif `.<nom>` est
// textuel — un nom générique peut être « vivant » par homonymie. La garde vise
// le jeton mort AJOUTÉ (nom neuf, donc discriminant), pas un audit exhaustif.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Jetons consommés dans `z_theme.dart` MÊME, par le corps de la méthode
/// indiquée. L'exclusion du fichier rend leurs lectures invisibles au corpus ;
/// l'exemption est donc vérifiée mécaniquement contre ce corps de méthode.
const Map<String, String> _intraTheme = <String, String>{
  'fieldFocusedBorderColor': 'inputDecoration',
  'inputFilled': 'inputDecoration',
  'helperMaxLines': 'inputDecoration',
};

void main() {
  test(
      '🔴 INERTIE : tout jeton public de `ZcrudTheme` a un consommateur hors '
      '`z_theme.dart` (repo-wide), ou une exemption intra-fichier vérifiée',
      () {
    final File themeFile =
        sources.libFile('presentation/theme/z_theme.dart');
    final String theme = sources.strippedSource(themeFile);

    // ── 1. Les propriétés `final` publiques de la classe ZcrudTheme ─────────
    final int classStart = theme.indexOf('class ZcrudTheme');
    expect(classStart, greaterThanOrEqualTo(0),
        reason: 'classe ZcrudTheme introuvable — parsing cassé');
    final String body = theme.substring(classStart);
    final List<String> props = <String>[];
    for (final m in RegExp(r'^  final\s+[\w<>,? ]+?\s(\w+);', multiLine: true)
        .allMatches(body)) {
      final String p = m.group(1)!;
      if (!p.startsWith('_')) props.add(p);
    }
    expect(props.length, greaterThanOrEqualTo(60),
        reason: 'trop peu de jetons trouvés — parsing probablement cassé');

    // ── 2. Corpus repo-wide : `packages/*/lib` strippé, hors z_theme.dart ───
    final Directory pkgs =
        Directory('${sources.repoRoot().path}/packages');
    final List<File> files = pkgs
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((File f) {
      final String p = f.path.replaceAll(r'\', '/');
      return p.endsWith('.dart') &&
          !p.endsWith('.g.dart') &&
          !p.endsWith('.freezed.dart') &&
          !p.endsWith('/z_theme.dart') &&
          RegExp(r'/packages/[^/]+/lib/').hasMatch(p);
    }).toList();
    expect(files.length, greaterThanOrEqualTo(100),
        reason: 'corpus trop maigre — chemin cassé, garde VACUELLE');
    final String corpus = files.map(sources.strippedSource).join('\n');
    expect(corpus.length, greaterThan(100000),
        reason: 'corpus vide — garde VACUELLE');

    // ── 3. Corps des méthodes citées par les exemptions intra-fichier ───────
    // Anchors stables de `z_theme.dart` : le corps d'`inputDecoration` court
    // de sa signature à la méthode statique `of` qui la suit.
    final int decoStart = theme.indexOf('InputDecoration inputDecoration(');
    final int decoEnd = theme.indexOf('static ZcrudTheme of(');
    expect(decoStart, greaterThanOrEqualTo(0),
        reason: 'inputDecoration introuvable — exemptions invérifiables');
    expect(decoEnd, greaterThan(decoStart));
    final String inputDecorationBody = theme.substring(decoStart, decoEnd);

    // ── 4. Verdict ──────────────────────────────────────────────────────────
    final List<String> dead = <String>[];
    for (final String prop in props) {
      if (RegExp('\\.$prop\\b').hasMatch(corpus)) continue;
      final String? method = _intraTheme[prop];
      if (method != null) {
        expect(method, 'inputDecoration',
            reason: 'seule méthode intra-fichier connue de cette garde');
        expect(RegExp('\\b$prop\\b').hasMatch(inputDecorationBody), isTrue,
            reason: 'exemption MENSONGÈRE : $prop est exempté comme lu par '
                '$method, mais son corps ne le lit pas — retirez l\'exemption '
                'ou câblez la lecture');
        continue;
      }
      dead.add(prop);
    }
    expect(
      dead,
      isEmpty,
      reason: '🔴 JETON(S) MORT(S) : $dead — déclaré(s) publics dans '
          '`ZcrudTheme` mais lu(s) par AUCUN site de rendu de '
          '`packages/*/lib`. Câblez la lecture (le jeton doit faire ce que sa '
          'dartdoc promet), ou retirez le jeton — jamais une option déclarée '
          'sans consommateur.',
    );

    // ── 5. Chaque exemption existe encore, et la liste reste COURTE ─────────
    for (final String prop in _intraTheme.keys) {
      expect(props.contains(prop), isTrue,
          reason: 'exemption périmée : $prop n\'est plus un jeton — '
              'retirez-la de la liste');
    }
    expect(_intraTheme.length, lessThanOrEqualTo(6),
        reason: 'la liste intra-fichier s\'allonge — câblez des consommateurs '
            'réels au lieu d\'exempter');
  });
}
