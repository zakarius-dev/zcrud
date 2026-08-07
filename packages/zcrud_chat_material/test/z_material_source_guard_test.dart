@TestOn('vm')
/// 🔴 Garde de SOURCE du lot K3 — « zéro valeur recopiée », exemption ZÉRO.
///
/// Le contrat du satellite : toute dimension/durée/couleur passe par la chaîne
/// du chrome K2 (`zChatComposerChromeOf`) ou par `ZChatComposerReference`. Ce
/// fichier balaie `lib/` (code SANS commentaires ni chaînes) et interdit :
///
/// * **MAT-L1** — tout littéral numérique hors {0, 1, 2} (0/1 : bornes
///   neutres ; 2 : moitié/diamètre). Le `48`, le `24`, le `12`, le `0.7`, le
///   `150`… recopiés de lex sont EXACTEMENT le défaut que la garde ferme ;
/// * **MAT-L2** — toute couleur construite ici (`Color(`, `Colors.`) : les
///   rôles viennent du `ColorScheme` de l'hôte, les teintes d'identité de la
///   référence K2 (exception FR-26 encadrée, LÀ-BAS et pas ici) ;
/// * **MAT-L3** — toute durée construite ici (`Duration(`) : les durées vivent
///   dans le chrome/la référence ;
/// * **MAT-L4** — AD-13 : `EdgeInsets.only(`/`fromLTRB(`, `Alignment.center
///   Left/Right`, `TextAlign.left/right`, `Positioned(` (le `Positioned(top:0,
///   right:0)` de lex est le défaut relevé §A.2) ;
/// * **MAT-L5** — toute animation en propre (`Timer`, `AnimationController`,
///   `setState(`) : les transitions sont celles des primitives K2, qui portent
///   la garde Reduce-Motion — les contourner recréerait le défaut lex.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Code utile d'une ligne : sans commentaire (`//…`) ni contenu de chaîne.
String _stripped(String line) {
  final StringBuffer out = StringBuffer();
  bool inString = false;
  String quote = '';
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (inString) {
      if (c == quote) inString = false;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      quote = c;
      continue;
    }
    if (c == '/' && i + 1 < line.length && line[i + 1] == '/') break;
    out.write(c);
  }
  return out.toString();
}

void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('contrôle positif — la garde balaie bien les sources réelles', () {
    // Un scan muet rendrait toutes les assertions vraies par vacuité.
    expect(sources.length, greaterThanOrEqualTo(6));
    final String all = sources
        .map((File f) => f.readAsStringSync())
        .join('\n');
    expect(all, contains('zChatComposerChromeOf'),
        reason: 'les builders doivent consommer la chaîne du chrome');
    expect(all, contains('ZChatComposerReference'));
  });

  test('🔴 MAT-L1 — aucun littéral numérique hors {0, 1, 2}', () {
    final RegExp number = RegExp(r'(?<![A-Za-z0-9_.])\d+(\.\d+)?(?![A-Za-z0-9_])');
    const Set<String> allowed = <String>{'0', '1', '2'};
    final List<String> hits = <String>[];
    for (final File f in sources) {
      final List<String> lines = f.readAsLinesSync();
      for (int n = 0; n < lines.length; n++) {
        for (final RegExpMatch m in number.allMatches(_stripped(lines[n]))) {
          if (allowed.contains(m.group(0))) continue;
          hits.add('${f.path}:${n + 1} → « ${m.group(0)} »');
        }
      }
    }
    expect(hits, isEmpty,
        reason: '🔴 valeur recopiée — elle doit passer par le chrome K2 ou '
            'la référence :\n${hits.join('\n')}');
  });

  test('🔴 MAT-L2/L3 — aucune couleur ni durée construite ici', () {
    final RegExp banned = RegExp(r'(?<![A-Za-z0-9_])(Color\(|Colors\.|Duration\()');
    for (final File f in sources) {
      final List<String> lines = f.readAsLinesSync();
      for (int n = 0; n < lines.length; n++) {
        expect(banned.hasMatch(_stripped(lines[n])), isFalse,
            reason: '🔴 ${f.path}:${n + 1} — couleur/durée en dur : les '
                'teintes vivent dans la référence K2 (FR-26), les rôles chez '
                'l\'hôte, les durées dans le chrome');
      }
    }
  });

  test('🔴 MAT-L4 — AD-13 : aucun motif non directionnel', () {
    final RegExp banned = RegExp(
      r'EdgeInsets\.only\(|EdgeInsets\.fromLTRB\(|Alignment\.centerLeft|'
      r'Alignment\.centerRight|TextAlign\.left|TextAlign\.right|'
      r'(?<![A-Za-z0-9_])Positioned\(',
    );
    for (final File f in sources) {
      final List<String> lines = f.readAsLinesSync();
      for (int n = 0; n < lines.length; n++) {
        expect(banned.hasMatch(_stripped(lines[n])), isFalse,
            reason: '🔴 ${f.path}:${n + 1} — motif non directionnel (le '
                'défaut `Positioned(top:0, right:0)` de lex, §A.2)');
      }
    }
  });

  test('🔴 MAT-L5 — aucune animation en propre (Reduce-Motion : primitives '
      'K2 seulement)', () {
    final RegExp banned = RegExp(
      r'(?<![A-Za-z0-9_])(Timer\.|Timer\(|AnimationController|setState\()',
    );
    for (final File f in sources) {
      final List<String> lines = f.readAsLinesSync();
      for (int n = 0; n < lines.length; n++) {
        expect(banned.hasMatch(_stripped(lines[n])), isFalse,
            reason: '🔴 ${f.path}:${n + 1} — animation en propre : elle '
                'contournerait la neutralisation Reduce-Motion des primitives '
                'K2');
      }
    }
  });
}
