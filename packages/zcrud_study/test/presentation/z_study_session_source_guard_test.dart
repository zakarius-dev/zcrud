/// **Lot 1 « étude »** — gardes de SOURCE du lot.
///
/// Elles verrouillent trois propriétés qu'aucun test de comportement ne peut
/// tenir durablement :
///
/// 1. **`0` `setState(`** — SM-1/AD-2. Un test de rebuild mesure l'état
///    d'aujourd'hui ; un `setState` réintroduit demain dans une branche peu
///    exercée (un cas d'erreur, un mode rare) passerait sous le radar de la
///    mesure. La garde de source, elle, ne dépend d'aucun chemin exécuté.
/// 2. **`0` `Scaffold(` / `AppBar(` dans la VUE** — la vue est un corps
///    composable ; un `Scaffold` qui s'y glisserait produirait un second
///    porteur de slots sous celui de l'hôte.
/// 3. **`0` seconde table de runtime** — aucun `switch` sur `ZReviewMode` dans
///    le lot : la désignation appartient à `zSessionRuntimeForMode` (AD-34).
///
/// Chaque scanner est **partagé** avec sa contre-preuve : sans ce partage, la
/// contre-preuve prouverait le pouvoir des MOTIFS, jamais celui du SCANNER.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fichiers RÉELLEMENT écrits par ce lot (chemins relatifs au package).
const List<String> _lotFiles = <String>[
  'lib/src/presentation/z_study_session_host.dart',
  'lib/src/presentation/z_study_session_mode.dart',
  'lib/src/presentation/z_study_session_reference.dart',
  'lib/src/presentation/z_study_session_scaffold.dart',
  'lib/src/presentation/z_study_session_slices.dart',
  'lib/src/presentation/z_study_session_view.dart',
];

/// La VUE seule (le corps composable).
const String _viewFile = 'lib/src/presentation/z_study_session_view.dart';

/// **Scanner RÉEL** — partagé avec les contre-preuves.
///
/// Recolle les **déclarations** (lignes de continuation réunies) : `dart format`
/// wrappe à 80 colonnes, et une violation coupée en deux serait invisible à un
/// scan ligne-à-ligne. Les commentaires sont écartés — la prose de ce lot NOMME
/// abondamment ce qu'elle interdit (`setState`, `Scaffold`), et une garde qui se
/// dénoncerait elle-même serait désactivée le jour même.
List<({int line, String text})> declarations(List<String> lines) {
  final out = <({int line, String text})>[];
  final buffer = StringBuffer();
  var startLine = 0;

  void flush() {
    if (buffer.isNotEmpty) {
      out.add((line: startLine, text: buffer.toString()));
      buffer.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    final int slash = trimmed.indexOf('//');
    if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
    if (trimmed.isEmpty) continue;
    if (buffer.isEmpty) startLine = i + 1;
    buffer.write(trimmed);
    if (trimmed.endsWith(';') ||
        trimmed.endsWith('{') ||
        trimmed.endsWith('}')) {
      flush();
    }
  }
  flush();
  return out;
}

/// Cherche [motif] dans les déclarations de [lines].
List<String> scan(List<String> lines, String path, String motif) => <String>[
      for (final decl in declarations(lines))
        if (decl.text.contains(motif)) '$path:${decl.line} → « $motif »',
    ];

List<String> _codeOf(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue,
      reason: 'introuvable: $path (cwd=${Directory.current.path}) — '
          '⚠️ `flutter test` doit être lancé DEPUIS le package');
  return file.readAsLinesSync();
}

void main() {
  test('sonde : les 6 fichiers du lot existent et sont scannés', () {
    for (final String path in _lotFiles) {
      expect(_codeOf(path), isNotEmpty, reason: '$path est vide ?');
    }
  });

  group('🔴 SM-1/AD-2 — ZÉRO `setState(` dans tout le lot', () {
    test('aucun `setState(` dans les 6 fichiers', () {
      final violations = <String>[];
      for (final String path in _lotFiles) {
        violations.addAll(scan(_codeOf(path), path, 'setState('));
      }
      expect(violations, isEmpty,
          reason: '🔴 un `setState` est réapparu :\n${violations.join('\n')}\n'
              'AD-2 : l\'état vit dans des `ValueNotifier` possédés, et chaque '
              'tranche a son `ValueListenableBuilder`. Un `setState` d\'écran '
              'reconstruit le sous-arbre du swiper — et comme sa `key` dérive '
              'de l\'identité de la file, c\'est le chemin exact du RangeError '
              'de su-4 D1.');
    });
  });

  group('🔴 la VUE est un corps composable — aucun porteur de slots', () {
    test('aucun `Scaffold(` ni `AppBar(` ni `Navigator.` dans la vue', () {
      final List<String> lines = _codeOf(_viewFile);
      final violations = <String>[
        ...scan(lines, _viewFile, 'Scaffold('),
        ...scan(lines, _viewFile, 'AppBar('),
        ...scan(lines, _viewFile, 'Navigator.'),
      ];
      expect(violations, isEmpty,
          reason: '🔴 la vue doit pouvoir être posée en page, en feuille OU en '
              'dialogue :\n${violations.join('\n')}');
    });
  });

  group('🔴 AD-34 — aucune SECONDE table de runtime', () {
    test('aucun `switch (` sur `ZReviewMode` dans le lot', () {
      // La démo en portait une (`_makeRuntime`, `study_session_demo_screen.dart:212`),
      // parallèle à `zSessionRuntimeForMode`. Deux tables qui s'accordent
      // aujourd'hui divergeront demain — et c'est le régime d'écriture SRS qui
      // serait en jeu.
      final violations = <String>[];
      for (final String path in _lotFiles) {
        violations.addAll(scan(_codeOf(path), path, 'switch (widget.mode)'));
        violations.addAll(scan(_codeOf(path), path, 'switch (mode)'));
        violations.addAll(scan(_codeOf(path), path, 'case ZReviewMode.'));
      }
      expect(violations, isEmpty,
          reason: '🔴 une seconde table de runtime est apparue :\n'
              '${violations.join('\n')}\n'
              'AD-34 : la désignation appartient à `zSessionRuntimeForMode`.');
    });

    test('…et `zSessionRuntimeForMode` est RÉELLEMENT appelée par le host', () {
      // Sans ce contrôle positif, l'assertion « aucune seconde table » serait
      // verte sur un host qui n'en utiliserait AUCUNE.
      final List<String> lines =
          _codeOf('lib/src/presentation/z_study_session_host.dart');
      expect(scan(lines, 'host', 'zSessionRuntimeForMode('), isNotEmpty,
          reason: '🔴 le host doit CONSOMMER la table unique — sinon il '
              'redécide en silence');
    });
  });

  group('🔴 CONTRE-PREUVES — les scanners RÉELS ne sont pas aveugles', () {
    test('un `setState(` est ATTRAPÉ', () {
      expect(scan(<String>['    setState(() => _x = 1);'], 'f.dart', 'setState('),
          isNotEmpty);
    });

    test('🔬 un `setState(` COUPÉ par `dart format` est ATTRAPÉ', () {
      // La forme que produit `dart format` sur une ligne longue : aucune LIGNE
      // ne porte le motif complet — seul le recollage par déclaration le voit.
      const List<String> wrapped = <String>[
        '    unTrèsLongNomDeMéthodeQuiPousseAuWrapping',
        '        .setState(() {});',
      ];
      expect(wrapped.any((String l) => l.contains('.setState(')), isTrue,
          reason: 'ici le motif survit sur sa ligne…');
      const List<String> reallyWrapped = <String>[
        '    setState(',
        '      () => _x = 1,',
        '    );',
      ];
      expect(
        reallyWrapped.any((String l) => l.contains('setState(() ')),
        isFalse,
        reason: '…mais `setState(() ` ne survit sur AUCUNE ligne ici',
      );
      expect(scan(reallyWrapped, 'f.dart', 'setState(() =>'), isNotEmpty,
          reason: 'le recollage par déclaration, lui, le voit');
    });

    test('un `Scaffold(` est ATTRAPÉ', () {
      expect(scan(<String>['  return Scaffold(body: x);'], 'f.dart', 'Scaffold('),
          isNotEmpty);
    });

    test('un `case ZReviewMode.` est ATTRAPÉ', () {
      expect(
        scan(<String>['      case ZReviewMode.learn:'], 'f.dart',
            'case ZReviewMode.'),
        isNotEmpty,
      );
    });

    test('la PROSE peut nommer les motifs sans faire rougir', () {
      // Sans cette clause, la dartdoc de ce lot — qui explique longuement
      // pourquoi il n'y a pas de `setState` — se dénoncerait elle-même.
      const List<String> prose = <String>[
        '/// Aucun `setState(` ici : AD-2.',
        '// La démo posait un Scaffold( — pas nous.',
        '  // case ZReviewMode.learn: interdit (AD-34)',
      ];
      expect(scan(prose, 'p.dart', 'setState('), isEmpty);
      expect(scan(prose, 'p.dart', 'Scaffold('), isEmpty);
      expect(scan(prose, 'p.dart', 'case ZReviewMode.'), isEmpty);
    });

    test('🔬 un commentaire de FIN DE LIGNE ne masque pas le code qui précède',
        () {
      expect(
        scan(<String>['  setState(() {}); // note'], 'f.dart', 'setState('),
        isNotEmpty,
      );
    });
  });
}
