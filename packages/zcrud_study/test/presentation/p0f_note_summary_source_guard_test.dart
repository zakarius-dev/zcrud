// Lot P0-F — gardes STATIQUES de source de l'assemblage de résumé de note.
//
// Quatre propriétés, mesurées sur le disque plutôt que sur une intention :
// 1. FR-26 — aucun libellé ni couleur en dur dans les fichiers CRÉÉS par le lot
//    (le contrôleur et la feuille) : tout ce qui s'affiche est injecté.
// 2. FR-26 (carte) — l'action ajoutée à la carte n'a PAS de libellé par défaut.
//    Un défaut « Résumer » fuirait en français dans une application anglaise,
//    sans voie de remplacement. Les libellés PRÉEXISTANTS de la carte ne sont
//    pas dans le périmètre : la garde défendrait alors autre chose que ce que
//    le lot a écrit.
// 3. Voie d'appel UNIQUE — `summarize(` n'est appelé QUE depuis le contrôleur.
//    C'est le grep négatif de l'affirmation « une seule voie », exécuté au lieu
//    d'être promis.
// 4. AD-1 — aucun moteur de rich-text n'entre dans ce paquet par la porte du
//    rendu de résumé : la lecture riche passe par le slot injecté.
//
// Accès `dart:io` ⇒ `@TestOn('vm')` (le gate web compile vers Node).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' show libDartFiles, packageRoot, stripped;

/// Fichiers CRÉÉS par le lot (chemins relatifs au package).
const List<String> _lotFiles = <String>[
  'lib/src/presentation/z_note_summary_controller.dart',
  'lib/src/presentation/z_note_summary_sheet.dart',
];

/// Fichier de la carte, MODIFIÉ par le lot (périmètre restreint : couleurs et
/// directionnalité, plus la règle nominative du libellé d'action ajouté).
const String _cardFile = 'lib/src/presentation/z_default_note_card.dart';

File _file(String relative) {
  final f = File('${packageRoot().path}/$relative');
  expect(f.existsSync(), isTrue,
      reason: 'introuvable: $relative (cwd=${Directory.current.path}) — '
          'lancer `flutter test` DEPUIS le package');
  return f;
}

/// Motifs de COULEUR en dur interdits (FR-26).
const List<String> _bannedColorPatterns = <String>[
  'Colors.',
  'Color(0x',
];

/// Motifs NON directionnels interdits (AD-13 — RTL).
const List<String> _bannedDirectionalPatterns = <String>[
  'EdgeInsets.only(left:',
  'EdgeInsets.only(right:',
  'Alignment.centerLeft',
  'Alignment.centerRight',
  'TextAlign.left',
  'TextAlign.right',
  'Positioned(left:',
  'Positioned(right:',
  'ListView(children:',
];

/// Puits RÉELLEMENT rendus à l'écran : un littéral y est toujours un défaut.
final List<({String name, RegExp pattern})> _bannedLabelRules =
    <({String name, RegExp pattern})>[
  (name: "Text('…') en dur", pattern: RegExp(r"""Text\(\s*'([^']*)'""")),
  (name: 'Text("…") en dur', pattern: RegExp(r'''Text\(\s*"([^"]*)"''')),
  (name: "hintText: '…' en dur", pattern: RegExp(r"hintText:\s*'([^']*)'")),
  (name: "labelText: '…' en dur", pattern: RegExp(r"labelText:\s*'([^']*)'")),
  (name: "tooltip: '…' en dur", pattern: RegExp(r"tooltip:\s*'([^']*)'")),
  (
    name: "semanticLabel: '…' en dur",
    pattern: RegExp(r"semanticLabel:\s*'([^']*)'")
  ),
  (name: "Semantics(label: '…') en dur", pattern: RegExp(r"label:\s*'([^']*)'")),
];

/// Un littéral qui porte une LETTRE (interpolations retirées) est un texte à
/// traduire ; `Text('$n')` rend un nombre et n'en est pas un.
bool isTranslatable(String s) {
  final withoutInterpolation = s
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$\w+'), '');
  return RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(withoutInterpolation);
}

/// SCANNER RÉEL de motifs simples — partagé avec ses contre-preuves (sans ce
/// partage, une contre-preuve ne prouverait que le pouvoir du MOTIF).
List<String> scanForPatterns(
  List<String> lines,
  String path,
  List<String> patterns,
) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
    for (final p in patterns) {
      if (raw.contains(p)) {
        violations.add('$path:${i + 1} → « $p » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// SCANNER RÉEL des libellés en dur — partagé avec ses contre-preuves.
List<String> scanForLabels(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
    for (final rule in _bannedLabelRules) {
      final m = rule.pattern.firstMatch(raw);
      if (m != null && isTranslatable(m.group(1) ?? '')) {
        violations.add('$path:${i + 1} → ${rule.name} : « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

void main() {
  group('G10 — FR-26 : aucun libellé ni couleur en dur dans les fichiers du lot',
      () {
    test('0 libellé en dur dans le contrôleur et la feuille', () {
      final violations = <String>[];
      for (final path in _lotFiles) {
        violations.addAll(scanForLabels(stripped(_file(path)), path));
      }
      expect(violations, isEmpty,
          reason: '🔴 un libellé est figé dans une langue, sans voie de '
              'remplacement :\n${violations.join('\n')}');
    });

    test('0 couleur en dur dans les fichiers du lot (carte incluse)', () {
      final violations = <String>[];
      for (final path in <String>[..._lotFiles, _cardFile]) {
        violations.addAll(
            scanForPatterns(stripped(_file(path)), path, _bannedColorPatterns));
      }
      expect(violations, isEmpty,
          reason: '🔴 une couleur échappe au thème injecté :\n'
              '${violations.join('\n')}');
    });

    test('0 API non directionnelle dans les fichiers du lot (AD-13)', () {
      final violations = <String>[];
      for (final path in <String>[..._lotFiles, _cardFile]) {
        violations.addAll(scanForPatterns(
            stripped(_file(path)), path, _bannedDirectionalPatterns));
      }
      expect(violations, isEmpty,
          reason: '🔴 une API non directionnelle casse le RTL :\n'
              '${violations.join('\n')}');
    });

    test(
        '🔴 le libellé de l\'action « résumer » n\'a AUCUN défaut de '
        'constructeur', () {
      final lines = stripped(_file(_cardFile));
      final defaulted = <String>[
        for (final l in lines)
          if (RegExp(r"""\bsummarizeSemanticLabel\s*=\s*['"]""").hasMatch(l))
            l.trim(),
      ];
      expect(defaulted, isEmpty,
          reason: '🔴 un défaut de libellé fige l\'action dans une langue : '
              '${defaulted.join(' | ')}');
      // Sonde : le paramètre existe bien dans le fichier scanné, sinon
      // l'assertion à vide serait infalsifiable.
      expect(lines.any((l) => l.contains('summarizeSemanticLabel')), isTrue,
          reason: 'sonde cassée : le paramètre n\'est pas dans le corpus');
    });

    test('CONTRE-PREUVES : les scanners RÉELS ne sont pas aveugles', () {
      expect(
          scanForLabels(<String>["    tooltip: 'Résumer la note',"], 'f.dart'),
          isNotEmpty);
      expect(scanForLabels(<String>["      Text('Résumer'),"], 'f.dart'),
          isNotEmpty);
      expect(
          scanForPatterns(<String>['  color: Colors.red,'], 'f.dart',
              _bannedColorPatterns),
          isNotEmpty);
      expect(
          scanForPatterns(<String>['  padding: EdgeInsets.only(left: 8),'],
              'f.dart', _bannedDirectionalPatterns),
          isNotEmpty);
      // …mais la PROSE peut nommer ce qu'elle interdit, et une interpolation
      // pure n'est pas un texte à traduire.
      expect(
          scanForLabels(
              <String>["  /// Jamais Text('Résumer') en dur."], 'prose.dart'),
          isEmpty);
      expect(scanForLabels(<String>[r"      Text('$count'),"], 'f.dart'),
          isEmpty);
    });
  });

  group('G11 — `summarize(` n\'est appelé QUE depuis le contrôleur', () {
    test('voie d\'appel unique dans tout lib/', () {
      const declaration = 'lib/src/domain/z_note_summary_port.dart';
      const caller = 'lib/src/presentation/z_note_summary_controller.dart';
      final root = packageRoot().path;
      final files = libDartFiles();
      expect(files, isNotEmpty,
          reason: 'sonde cassée : aucun fichier scanné ⇒ garde infalsifiable');

      final sites = <String>[];
      for (final f in files) {
        final relative = f.path.replaceFirst('$root/', '');
        for (final line in stripped(f)) {
          if (line.contains('summarize(')) sites.add(relative);
        }
      }
      // Sonde : les deux sites LÉGITIMES sont bien vus par le scanner.
      expect(sites, contains(declaration));
      expect(sites, contains(caller));
      expect(sites.toSet(), <String>{declaration, caller},
          reason: '🔴 le port est appelé hors du contrôleur : la surface de '
              'résumé n\'a plus une voie unique (jeton de fraîcheur, '
              'anti-double-soumission et frontière de commit contournés) — '
              'sites : ${sites.toSet().join(', ')}');
    });
  });

  group('G12 — AD-1 : aucun moteur de rich-text tiré par le rendu du résumé',
      () {
    test('0 import d\'un moteur de rendu riche dans les fichiers du lot', () {
      // La lecture riche du résumé passe par le slot injecté
      // `summaryBuilder` : elle est FOURNIE par l'application. Le jour où un
      // import de moteur apparaîtrait ici, l'arête serait réintroduite en
      // silence — c'est ce que cette garde interdit.
      const banned = <String>[
        'package:zcrud_markdown/',
        'package:flutter_quill/',
        'package:flutter_markdown/',
        'package:zcrud_note/',
      ];
      final violations = <String>[];
      for (final path in <String>[..._lotFiles, _cardFile]) {
        violations
            .addAll(scanForPatterns(stripped(_file(path)), path, banned));
      }
      expect(violations, isEmpty,
          reason: '🔴 une arête de rendu riche est réintroduite (AD-1) :\n'
              '${violations.join('\n')}');
      // Sonde : le slot de rendu existe bien, sinon la garde protégerait une
      // absence sans alternative.
      expect(
        stripped(_file('lib/src/presentation/z_note_summary_sheet.dart'))
            .any((l) => l.contains('summaryBuilder')),
        isTrue,
        reason: 'sonde cassée : le slot de rendu injecté a disparu',
      );
    });
  });
}
