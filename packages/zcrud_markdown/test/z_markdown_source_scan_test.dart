/// ZÉRO couleur en dur, ZÉRO libellé en dur sur le chemin du chrome, ZÉRO API
/// non-directionnelle dans les sources de `zcrud_markdown`.
///
/// ## Pourquoi CRÉÉE ici (extension de couverture, pas duplication)
///
/// La garde jumelle n'existait que dans d'autres paquets et scanne
/// `Directory('lib/src/presentation')` **du sien** (chemin relatif) : elle ne
/// peut structurellement pas couvrir celui-ci. Mesuré avant écriture :
/// `zcrud_markdown/lib` était déjà conforme sur les couleurs et le RTL —
/// cette garde VERROUILLE un état sain, elle ne légalise aucune dette.
///
/// Elle devient nécessaire maintenant que ce paquet rend un chrome PAR DÉFAUT :
/// une couleur ou un libellé figé n'y était vu par personne, et se retrouverait
/// désormais chez tout consommateur sans qu'il l'ait demandé.
///
/// ## 🔒 Exception FR-26 encadrée — pour l'instant VIDE, et c'est un fait
///
/// [_colorGuardExemptFiles] est l'unique porte d'entrée d'une couleur de
/// référence dans ce paquet. Elle est **vide** : la chaîne de couleurs du
/// chrome est paramètre > seam > rôle du `ColorScheme`, et
/// `ZMarkdownChromeReference` ne fige que des DIMENSIONS et des opacités.
/// Toute valeur de référence future entre par cette liste, chemin EXACT,
/// jamais un glob — et seulement si elle est remplaçable par thème ET par
/// paramètre.
///
/// ## Portée déclarée honnêtement
///
/// Le volet LIBELLÉS est volontairement ÉTROIT : il vise les quatre libellés
/// du chrome et de l'agrandissement, ceux que le défaut expose désormais à
/// tout consommateur. Le reste du paquet (menus de tableau, dialogue de
/// formule) porte encore des libellés figés : ils sont HORS de ce lot, ne sont
/// pas prétendus couverts, et ne le seront que par un lot dédié.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')` (sinon la suite ne compile pas en JS).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du paquet, que le test tourne depuis son dossier ou depuis la racine
/// du dépôt. Jamais un `../` relatif.
Directory _packageRoot() {
  for (final String p in <String>['.', 'packages/zcrud_markdown']) {
    final Directory d = Directory(p);
    if (File('${d.path}/pubspec.yaml').existsSync() &&
        Directory('${d.path}/lib/src').existsSync()) {
      return d;
    }
  }
  fail('racine de zcrud_markdown introuvable depuis ${Directory.current.path}');
}

/// Tous les `.dart` de `lib/`, chemins NORMALISÉS relativement au paquet.
List<({String path, List<String> lines})> _libSources() {
  final Directory lib = Directory('${_packageRoot().path}/lib');
  expect(lib.existsSync(), isTrue, reason: 'lib/ introuvable');
  final List<({String path, List<String> lines})> out = [];
  for (final File f in lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))) {
    final String rel = f.path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^.*?/?lib/'), 'lib/');
    out.add((path: rel, lines: f.readAsLinesSync()));
  }
  expect(out, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

/// Motifs de COULEUR en dur interdits (FR-26).
const List<String> _bannedColorPatterns = <String>['Colors.', 'Color(0x'];

/// `Colors.transparent` n'est pas un CHOIX de couleur : c'est l'absence de
/// peinture. Il est indispensable là où une surface doit laisser voir ce qui
/// est dessous — notamment pour neutraliser le fond opaque que la barre
/// d'outils peint par-dessus la décoration du socle.
const String _transparentIsNotAColor = 'Colors.transparent';

/// 🔒 Exemption FR-26 NOMINATIVE — chemins EXACTS, jamais un glob. Vide
/// aujourd'hui (cf. dartdoc de tête).
const Set<String> _colorGuardExemptFiles = <String>{};

/// Motifs non-directionnels interdits (AD-13 — RTL).
const List<String> _bannedDirectionalPatterns = <String>[
  'EdgeInsets.only(left:',
  'EdgeInsets.only(right:',
  'Alignment.centerLeft',
  'Alignment.centerRight',
  'Alignment.topLeft',
  'Alignment.topRight',
  'Alignment.bottomLeft',
  'Alignment.bottomRight',
  'TextAlign.left',
  'TextAlign.right',
  'Positioned(left:',
  'Positioned(right:',
  'ListView(children:',
];

/// Fichiers portant le chrome et l'agrandissement — le chemin du DÉFAUT.
const Set<String> _chromePathFiles = <String>{
  'lib/src/presentation/z_markdown_field.dart',
  'lib/src/presentation/z_markdown_chrome.dart',
};

/// Les quatre libellés que le défaut EXPOSE. Les variantes anglaises sont
/// bannies aussi : traduire un littéral ne le sort pas du paquet.
const List<String> _bannedChromeLabels = <String>[
  "'Valider'",
  "'Rédiger'",
  "'Modifier'",
  "'Agrandir'",
  "'Confirm'",
  "'Write'",
  "'Expand'",
];

/// Scanner RÉEL, partagé avec les contre-preuves. Ignore les lignes de
/// commentaire (`//`, `///`) : la documentation a le droit de NOMMER ce
/// qu'elle interdit.
List<String> scanForPatterns(
  List<String> lines,
  String path,
  List<String> patterns, {
  List<String> allowedSubstrings = const <String>[],
}) {
  final List<String> violations = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final String raw = lines[i];
    final String trimmed = raw.trimLeft();
    if (trimmed.startsWith('//')) continue;
    for (final String pattern in patterns) {
      if (!raw.contains(pattern)) continue;
      String probe = raw;
      for (final String allowed in allowedSubstrings) {
        probe = probe.replaceAll(allowed, '');
      }
      if (!probe.contains(pattern)) continue;
      violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
    }
  }
  return violations;
}

void main() {
  group('FR-26 — ZÉRO couleur en dur dans les sources du paquet', () {
    test('aucun `Colors.`/`Color(0x` hors exemption nominative', () {
      final List<String> violations = <String>[];
      for (final src in _libSources()) {
        if (_colorGuardExemptFiles.contains(src.path)) continue;
        violations.addAll(scanForPatterns(
          src.lines,
          src.path,
          _bannedColorPatterns,
          allowedSubstrings: const <String>[_transparentIsNotAColor],
        ));
      }
      expect(violations, isEmpty,
          reason: '🔴 couleur codée en dur :\n${violations.join('\n')}\n'
              'FR-26 : le thème est INJECTÉ (`ZcrudTheme.of`, repli '
              '`Theme.of`). Depuis que ce paquet rend un chrome PAR DÉFAUT, '
              'une couleur figée casserait le thème sombre de TOUT '
              'consommateur, sans qu\'il ait rien demandé.');
    });

    test('CONTRE-PREUVE : le scanner mord vraiment (anti-vacuité)', () {
      expect(
        scanForPatterns(
          <String>['  color: Colors.blue,'],
          'sonde.dart',
          _bannedColorPatterns,
          allowedSubstrings: const <String>[_transparentIsNotAColor],
        ),
        hasLength(1),
      );
      expect(
        scanForPatterns(
          <String>['  color: const Color(0xFF667EEA),'],
          'sonde.dart',
          _bannedColorPatterns,
          allowedSubstrings: const <String>[_transparentIsNotAColor],
        ),
        hasLength(1),
      );
      // …et laisse passer la seule forme légitime.
      expect(
        scanForPatterns(
          <String>['  color: Colors.transparent,'],
          'sonde.dart',
          _bannedColorPatterns,
          allowedSubstrings: const <String>[_transparentIsNotAColor],
        ),
        isEmpty,
      );
      // …sans devenir aveugle sur la même ligne.
      expect(
        scanForPatterns(
          <String>['  a: Colors.transparent, b: Colors.red,'],
          'sonde.dart',
          _bannedColorPatterns,
          allowedSubstrings: const <String>[_transparentIsNotAColor],
        ),
        hasLength(1),
      );
    });
  });

  group('l10n — aucun libellé de chrome codé dans le paquet', () {
    test('les quatre libellés du défaut sont ABSENTS des sources', () {
      final List<String> violations = <String>[];
      for (final src in _libSources()) {
        if (!_chromePathFiles.contains(src.path)) continue;
        violations
            .addAll(scanForPatterns(src.lines, src.path, _bannedChromeLabels));
      }
      expect(violations, isEmpty,
          reason: '🔴 libellé codé en dur :\n${violations.join('\n')}\n'
              'Le chrome est le rendu PAR DÉFAUT : un littéral ici fuit dans '
              'toutes les langues. Passer par `label(context, '
              '\'z.markdown.…\')` — clés déclarées dans les DEUX tables du '
              'délégué de `zcrud_core`.');
    });

    test('CONTRE-PREUVE : les deux fichiers du chemin du chrome existent bien',
        () {
      final Set<String> seen =
          _libSources().map((s) => s.path).toSet();
      for (final String f in _chromePathFiles) {
        expect(seen, contains(f),
            reason: 'chemin obsolète : la garde ne scanne plus rien');
      }
    });

    test('CONTRE-PREUVE : le scanner de libellés mord', () {
      expect(
        scanForPatterns(
            <String>["    label: 'Valider',"], 'sonde.dart', _bannedChromeLabels),
        hasLength(1),
      );
      expect(
        scanForPatterns(<String>["    // 'Valider' en commentaire"],
            'sonde.dart', _bannedChromeLabels),
        isEmpty,
        reason: 'la documentation a le droit de nommer ce qu\'elle interdit',
      );
    });
  });

  group('AD-13 — ZÉRO API non-directionnelle (RTL)', () {
    test('aucun left:/right:/centerLeft… ni ListView(children:)', () {
      final List<String> violations = <String>[];
      for (final src in _libSources()) {
        violations.addAll(
            scanForPatterns(src.lines, src.path, _bannedDirectionalPatterns));
      }
      expect(violations, isEmpty,
          reason: '🔴 API non directionnelle :\n${violations.join('\n')}');
    });

    test('CONTRE-PREUVE : le scanner directionnel mord', () {
      expect(
        scanForPatterns(<String>['  padding: EdgeInsets.only(left: 8),'],
            'sonde.dart', _bannedDirectionalPatterns),
        hasLength(1),
      );
    });
  });
}
