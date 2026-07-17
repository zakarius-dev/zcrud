/// AC9 (ES-4.5) + SU-3/AC2 — pureté runtime des widgets de PRÉSENTATION
/// (AD-2/AD-15/AD-23/AD-33).
///
/// Les widgets de `lib/src/presentation/**` sont des widgets PURS : ils
/// n'importent NI un moteur de session (`z_study_session_engine`/
/// `z_white_exam_session_engine`/`z_linear_session_state`), NI un
/// `ZRepetitionStore`, NI un gestionnaire d'état (Riverpod/GetX/provider).
/// `simulate` n'est appelé que côté APPELANT (seam `previewLabelFor`) — aucun
/// `apply`/`put`/`reviewCard` dans les widgets.
///
/// 🔴 **SU-3 — pourquoi cette garde est CENTRALE ici** (AD-33) : le danger n'est
/// pas lointain, il est **LOCAL**. `zcrud_flashcard` — dont `zcrud_session`
/// dépend — **contient lui-même** les moyens d'écrire le SRS (`ZSm2Scheduler`,
/// `ZSrsScheduler`, `ZRepetitionStore`). Un dev pressé **peut** appeler
/// `ZSrsScheduler.apply` directement depuis la surface de saisie : ce serait la
/// **porte dérobée exacte** qu'AD-33 interdit. su-3 n'écrit RIEN — il **émet**
/// une soumission advisory ; **su-4** branchera `onQualitySelected` sur
/// `ZSessionReviewer.reviewCard`.
///
/// **Cette garde n'énumère JAMAIS une liste figée de widgets** : elle scanne
/// `lib/src/presentation/**` **récursivement** ⇒ tout futur widget (dont
/// `ZFlashcardAnswerInput`, SU-3) est capté **sans édition du test** (R16).
/// C'est pourquoi su-3 l'**ÉTEND** au lieu d'en créer une parallèle.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**` — jamais
/// une liste figée : un futur widget de présentation est capté sans édition du
/// test (durabilité de la garde, R16).
List<String> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: $root (cwd=${Directory.current.path})');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// Imports/symboles interdits dans les widgets (couplage runtime / état / SRS).
const List<String> _bannedImports = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:get/',
  'package:provider/',
  'z_study_session_engine.dart',
  'z_white_exam_session_engine.dart',
  'z_linear_session_state.dart',
];

/// Symboles d'ÉCRITURE SRS interdits (AD-23 : projection pure seule ; AD-33 :
/// l'écriture passe UNIQUEMENT par le seam `ZSessionReviewer`).
const List<String> _bannedWriteSymbols = <String>[
  'ZRepetitionStore',
  '.apply(',
  '.reviewCard(',
  // 🔴 SU-3 (T4bis) — TROU RÉEL COMBLÉ : les schedulers n'étaient attrapés
  // qu'INDIRECTEMENT, via `.apply(`. Un widget qui détiendrait un scheduler en
  // champ, ou le passerait à un helper, passait SOUS le radar. Les nommer ferme
  // la porte à la SOURCE : une surface de présentation n'a AUCUNE raison
  // légitime de mentionner un scheduler.
  'ZSrsScheduler',
  'ZSm2Scheduler',
  // 🔴 SU-3 — le seam lui-même : su-3 n'écrit RIEN (AD-33). C'est su-4 qui
  // branchera `ZSessionReviewer`, et depuis l'HÔTE — jamais depuis un widget.
  'ZSessionReviewer',
];

/// Recolle les **déclarations** d'un source Dart : chaque entrée = une
/// déclaration logique, ses lignes de continuation **réunies**, avec le numéro
/// de sa PREMIÈRE ligne.
///
/// 🔴 **SU-3 (T4bis) — pourquoi ce recollage** (défaut **D4**, démasqué en su-1) :
/// la garde était **LIGNE-À-LIGNE**. Or `dart format` **wrappe à 80 colonnes** —
/// une violation coupée en deux devenait **INVISIBLE** :
///
/// ```dart
/// final y = someVeryLongRepositoryName
///     .reviewCard(card, quality);   // ← AUCUNE ligne ne contient '.reviewCard('
/// ```
///
/// C'est **exactement** ce que `dart format` produit sur une ligne longue — la
/// garde ne pouvait donc pas rougir dessus. su-3 ajoutant un **gros** widget
/// (donc des lignes longues, donc du wrapping), le trou allait s'ouvrir pour de
/// bon. On raisonne désormais **par déclaration**.
///
/// Les lignes de **commentaire/doc** sont écartées : elles CITENT légitimement
/// les motifs interdits (ce dartdoc-ci en est la preuve vivante).
List<({int line, String text})> _declarations(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <({int line, String text})>[];
  final buffer = StringBuffer();
  var startLine = 0;
  var inBlockComment = false;

  void flush() {
    if (buffer.isNotEmpty) {
      out.add((line: startLine, text: buffer.toString()));
      buffer.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    var trimmed = raw.trim();

    // Commentaires de bloc `/* … */` (multi-lignes).
    if (inBlockComment) {
      if (trimmed.contains('*/')) {
        inBlockComment = false;
        trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
      } else {
        continue;
      }
    }
    if (trimmed.startsWith('/*')) {
      if (!trimmed.contains('*/')) {
        inBlockComment = true;
        continue;
      }
      trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
    }
    // Commentaires de ligne / dartdoc / continuation de doc-block.
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    // Commentaire de FIN de ligne : on garde le code qui le précède.
    final slash = trimmed.indexOf('//');
    if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
    if (trimmed.isEmpty) continue;

    if (buffer.isEmpty) startLine = i + 1;
    // Recollage SANS espace : `foo\n    .apply(x)` doit redevenir `foo.apply(x)`
    // pour que le motif `.apply(` redevienne visible. Un espace inséré ici
    // rouvrirait le défaut D4.
    buffer.write(trimmed);

    // Fin de déclaration logique : `;` `{` `}` en fin de ligne.
    if (trimmed.endsWith(';') ||
        trimmed.endsWith('{') ||
        trimmed.endsWith('}')) {
      flush();
    }
  }
  flush();
  return out;
}

void main() {
  test('AC9 — aucun import de moteur / état ; aucune écriture SRS', () {
    final files = _presentationFiles();
    // Contre-preuve R12 : le scan DOIT réellement voir des fichiers (une garde
    // qui ne scanne rien est verte pour de mauvaises raisons).
    expect(files, isNotEmpty, reason: 'aucun fichier de présentation scanné');

    final violations = <String>[];
    for (final path in files) {
      for (final decl in _declarations(path)) {
        final text = decl.text;
        if (text.startsWith('import ') || text.startsWith('export ')) {
          for (final banned in _bannedImports) {
            if (text.contains(banned)) {
              violations.add('$path:${decl.line} → import banni: $banned');
            }
          }
        }
        for (final banned in _bannedWriteSymbols) {
          if (text.contains(banned)) {
            violations.add('$path:${decl.line} → écriture SRS interdite: '
                '$banned :: $text');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'couplage runtime / écriture SRS détecté :\n'
            '${violations.join('\n')}');
  });

  group('🔬 contre-preuve R12 — le scanner SAIT rougir (défaut D6)', () {
    // ⚠️ D6 : une contre-preuve qui RÉ-IMPLÉMENTE le scanner ne prouve RIEN
    // (elle testerait sa propre copie). Ici on écrit un VRAI fichier sur disque
    // et on exerce le VRAI `_declarations` — le même code que la garde ci-dessus.
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('z_purity_probe'));
    tearDown(() => tmp.deleteSync(recursive: true));

    ({int line, String text})? findViolation(String source, String banned) {
      final f = File('${tmp.path}/probe.dart')..writeAsStringSync(source);
      for (final decl in _declarations(f.path)) {
        if (decl.text.contains(banned)) return decl;
      }
      return null;
    }

    test('une violation SUR UNE LIGNE est captée', () {
      expect(
        findViolation('final x = store.apply(quality);', '.apply('),
        isNotNull,
      );
    });

    test(
        'une violation coupée AVANT le point est captée (forme réelle de '
        '`dart format` sur une ligne longue)', () {
      const wrapped = '''
final result = someVeryLongRepositoryName
    .reviewCard(card, quality);
''';
      expect(findViolation(wrapped, '.reviewCard('), isNotNull);
    });

    test('un scheduler dont la construction est coupée est capté (SU-3)', () {
      const wrapped = '''
final scheduler =
    ZSm2Scheduler(config);
''';
      expect(findViolation(wrapped, 'ZSm2Scheduler'), isNotNull);
    });

    test(
        '🔬 le recollage capte la forme `Nom(arg:` COUPÉE — la seule que '
        '`dart format` sait rendre invisible', () {
      // ⚠️ HONNÊTETÉ DE PORTÉE (mesurée, pas supposée — cf. Completion Notes).
      //
      // Les motifs BANNIS ICI ne sont PAS vulnérables au wrapping :
      //  - `ZSm2Scheduler`/`ZRepetitionStore`/`ZSessionReviewer` sont des
      //    identifiants d'un seul tenant — `dart format` ne coupe JAMAIS un
      //    identifiant ;
      //  - `.apply(`/`.reviewCard(` : `dart format` coupe AVANT le `.`, jamais
      //    entre le nom et sa parenthèse ⇒ le motif survit sur sa ligne.
      // Prétendre ici « le scan ligne-à-ligne était aveugle » serait donc FAUX
      // (le premier jet de ce test l'a prétendu — et ce test l'a démasqué).
      //
      // Le durcissement de CETTE garde est donc **prophylactique** : il ferme
      // les coupures écrites à la main et, surtout, il rend la garde sûre le
      // jour où l'on y ajoutera un motif de forme `Nom(arg:` — la SEULE forme
      // que `dart format` sait réellement rendre invisible (vérifié : c'est
      // l'angle mort RÉEL de `z_widgets_hardcode_scan_test.dart`, où
      // `EdgeInsets.only(left:` disparaît de toutes les lignes).
      //
      // On exerce donc le VRAI scanner sur cette forme-là : la machinerie est
      // prouvée, sans mentir sur ce qui était troué.
      const wrapped = '''
final w = SomeWidget(
  store: ZRepetitionStore(
    db: database,
  ),
);
''';
      expect(findViolation(wrapped, 'ZRepetitionStore'), isNotNull);

      // Et la preuve que la forme `Nom(arg:` est bien celle qui échappe au
      // ligne-à-ligne (motif fictif, exercé sur le VRAI recollage) :
      expect(
        wrapped.split('\n').any((l) => l.contains('ZRepetitionStore(db:')),
        isFalse,
        reason: 'aucune LIGNE ne porte `ZRepetitionStore(db:` ⇒ un motif de '
            'cette forme serait invisible à un scan ligne-à-ligne',
      );
      expect(findViolation(wrapped, 'ZRepetitionStore(db:'), isNotNull,
          reason: 'le recollage par déclaration, lui, le voit');
    });

    test('un COMMENTAIRE citant un motif interdit n\'est PAS une violation', () {
      // Sans quoi ce fichier — et les dartdoc de prod qui expliquent la règle —
      // se dénonceraient eux-mêmes.
      expect(
        findViolation('// jamais de .apply( ici\nfinal x = 1;', '.apply('),
        isNull,
      );
      expect(
        findViolation(
            '/// AD-33 : ZSm2Scheduler interdit\nfinal x = 1;', 'ZSm2Scheduler'),
        isNull,
      );
    });

    test('un commentaire de FIN de ligne ne masque pas le code qui le précède',
        () {
      expect(
        findViolation('final x = s.apply(q); // note', '.apply('),
        isNotNull,
      );
    });
  });
}
