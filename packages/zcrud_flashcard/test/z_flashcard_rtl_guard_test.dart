/// AC5 — garde de source **RTL** : aucune variante non directionnelle dans le
/// code de production de `zcrud_flashcard` (SU-2, AD-13).
///
/// **Portée déclarée HONNÊTEMENT** : cette garde couvre le **code zcrud** de
/// `lib/` — jamais les tests (qui construisent légitimement des cas LTR/RTL
/// explicites), jamais le code généré. Elle ne prétend rien de plus.
///
/// ⚠️ **Scan par DÉCLARATION, jamais ligne-à-ligne** (leçon **D4** du
/// code-review de su-1) : `dart format` wrappe à 80 colonnes, si bien qu'une
/// violation s'écrit le plus souvent
///
/// ```dart
/// padding: const EdgeInsets.only(
///   left: 8,
/// ),
/// ```
///
/// — forme où **aucune ligne** ne contient `EdgeInsets.only(left:`. Le
/// multi-lignes est le cas **NOMINAL**, pas l'exception.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Variantes **non directionnelles** interdites (AD-13), et leur remplaçante.
///
/// Bornées par `[^;{]*?` : le motif ne traverse pas la fin d'instruction, mais
/// franchit les parenthèses imbriquées (`EdgeInsets.only(top: gap(1), left: 2)`),
/// que `[^)]*` manquerait.
const Map<String, String> _bannedDirectional = <String, String>{
  r'EdgeInsets\.only\([^;{]*?\bleft\s*:': 'EdgeInsetsDirectional.only(start:)',
  r'EdgeInsets\.only\([^;{]*?\bright\s*:': 'EdgeInsetsDirectional.only(end:)',
  r'Alignment\.centerLeft\b': 'AlignmentDirectional.centerStart',
  r'Alignment\.centerRight\b': 'AlignmentDirectional.centerEnd',
  r'TextAlign\.left\b': 'TextAlign.start',
  r'TextAlign\.right\b': 'TextAlign.end',
  r'Positioned\([^;{]*?\bleft\s*:': 'PositionedDirectional(start:)',
  r'Positioned\([^;{]*?\bright\s*:': 'PositionedDirectional(end:)',
};

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Raisonne par **DÉCLARATION** : les lignes de continuation sont **recollées**
/// jusqu'au `;`/`{`/`}` qui clôt l'unité syntaxique, puis les espaces sont
/// normalisés. C'est ce qui lui donne son pouvoir sur la forme réelle du code.
///
/// Exercé À LA FOIS par la garde (sur `lib/`) et par ses contre-preuves : sans ce
/// partage, une contre-preuve ne prouverait que le pouvoir des MOTIFS, jamais
/// celui du SCANNER — racine causale exacte du finding **D6**.
List<String> scanForNonDirectional(List<String> lines, String path) {
  final violations = <String>[];
  final buffer = StringBuffer();
  var startLine = 0;

  void flush() {
    final declaration = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    buffer.clear();
    if (declaration.isEmpty) return;
    for (final entry in _bannedDirectional.entries) {
      if (RegExp(entry.key).hasMatch(declaration)) {
        violations.add(
          '$path:$startLine → variante NON directionnelle (RTL cassé, AD-13) ; '
          'utiliser « ${entry.value} » : « $declaration »',
        );
      }
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // la prose doit pouvoir NOMMER les variantes interdites
    }
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    if (buffer.isEmpty) startLine = i + 1;
    buffer
      ..write(' ')
      ..write(trimmed);
    if (trimmed.endsWith(';') || trimmed.endsWith('{') || trimmed.endsWith('}')) {
      flush();
    }
  }
  flush(); // unité résiduelle en fin de fichier
  return violations;
}

void main() {
  test(
    'AC5 — aucune variante non directionnelle dans zcrud_flashcard/lib (AD-13)',
    () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'lib/ introuvable (cwd = ${Directory.current.path})');

      final sources = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .toList();

      // Contre-preuve R12 : le scan DOIT voir des fichiers ET voir la carte de
      // révision — sinon la garde serait morte (faux vert éternel).
      expect(sources, isNotEmpty, reason: 'aucune source scannée — garde morte');
      expect(
        sources.any((f) => f.path.endsWith('z_flashcard_review_card.dart')),
        isTrue,
        reason: 'la carte de révision n\'a pas été vue par le scan',
      );

      final violations = <String>[];
      for (final source in sources) {
        violations.addAll(
          scanForNonDirectional(source.readAsLinesSync(), source.path),
        );
      }

      expect(
        violations,
        isEmpty,
        reason: 'RTL CASSÉ : une variante non directionnelle rendrait la carte '
            'illisible en arabe/hébreu (AD-13) :\n${violations.join('\n')}',
      );
    },
  );

  test(
    'POUVOIR SUR LE CAS NOMINAL — le SCANNER RÉEL détecte une violation '
    'MULTI-LIGNES (la forme que `dart format` impose)',
    () {
      // Un scan ligne-à-ligne ne verrait JAMAIS « left: 8, » : c'est le cas
      // NOMINAL, pas l'exception — et c'était le trou réel de la garde de su-1.
      const injected = <String>[
        'Widget build(BuildContext context) {',
        '  return Padding(',
        '    padding: const EdgeInsets.only(',
        '      left: 8,',
        '    ),',
        '  );',
        '}',
      ];

      final violations = scanForNonDirectional(injected, 'artificiel.dart');

      expect(violations, isNotEmpty,
          reason: 'VIOLATION MULTI-LIGNES NON DÉTECTÉE — le scanner raisonne '
              'encore par ligne : il est aveugle à la forme réelle du code');
      expect(violations.single, contains('EdgeInsetsDirectional.only(start:)'),
          reason: 'la garde doit nommer la variante de remplacement');
    },
  );

  test('POUVOIR — le scanner détecte chacune des variantes interdites', () {
    // Une garde qui ne couvre qu'un motif laisse passer les sept autres.
    const cases = <String, String>{
      'Alignment.centerLeft': 'const a = Alignment.centerLeft;',
      'Alignment.centerRight': 'const a = Alignment.centerRight;',
      'TextAlign.left': 'const t = TextAlign.left;',
      'TextAlign.right': 'const t = TextAlign.right;',
      'EdgeInsets.only(right:': 'const p = EdgeInsets.only(right: 4);',
      'Positioned(left:': 'final w = Positioned(left: 0, child: c);',
      'Positioned(right:': 'final w = Positioned(right: 0, child: c);',
    };

    for (final entry in cases.entries) {
      expect(
        scanForNonDirectional(<String>[entry.value], 'artificiel.dart'),
        isNotEmpty,
        reason: 'motif « ${entry.key} » NON détecté — la garde a un trou',
      );
    }
  });

  test('POUVOIR — le scanner franchit les PARENTHÈSES IMBRIQUÉES', () {
    // `[^)]*` (le motif naïf) s'arrêterait à la parenthèse de `gap(1)` et
    // manquerait le `left:` qui suit.
    const injected = <String>[
      'final p = EdgeInsets.only(top: gap(1), left: gap(2));',
    ];

    expect(scanForNonDirectional(injected, 'artificiel.dart'), isNotEmpty,
        reason: 'violation manquée derrière un appel imbriqué');
  });

  test(
    'PAS DE FAUX POSITIF — prose, variantes directionnelles et Alignment.center '
    'légitimes ne déclenchent RIEN',
    () {
      // Anti-sur-blocage : une garde qui crie au loup finit désarmée.
      // ⚠️ `Alignment.center` est un PRÉFIXE de `Alignment.centerLeft` : sans le
      // `\b` des motifs, il ferait un faux positif — or le flip 3D l'utilise
      // légitimement (`Transform(alignment: Alignment.center)`).
      const injected = <String>[
        '/// Jamais EdgeInsets.only(left:) ni Alignment.centerLeft (AD-13).',
        '// TextAlign.left est interdit : préférer TextAlign.start.',
        'const p = EdgeInsetsDirectional.only(start: 8, end: 4);',
        'const a = AlignmentDirectional.centerStart;',
        'const t = TextAlign.start;',
        'final w = Transform(alignment: Alignment.center, child: c);',
        'const p2 = EdgeInsets.only(top: 8, bottom: 4);',
        'final w2 = Positioned(top: 0, child: c);',
        'final w3 = PositionedDirectional(start: 0, child: c);',
      ];

      final violations = scanForNonDirectional(injected, 'artificiel.dart');

      expect(violations, isEmpty,
          reason: 'faux positif — la prose doit rester libre, et les variantes '
              'directionnelles (ainsi que Alignment.center, EdgeInsets.only('
              'top:/bottom:)) sont LÉGITIMES :\n${violations.join('\n')}');
    },
  );
}
