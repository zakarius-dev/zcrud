/// Garde ZÉRO-SM2 PAR CONSTRUCTION (`ZLinearSessionState`) — ES-4.3, AC2a (CŒUR).
///
/// AD-23 : le runtime LINÉAIRE ne détient **AUCUN** seam/scheduler/store SRS ⇒
/// il n'existe **aucun point d'écriture SRS atteignable** — garantie de TYPE, pas
/// de garde runtime. Ce test **lit la source** de `z_linear_session_state.dart`
/// et ROUGIT si l'un des symboles SRS apparaît (`ZSessionReviewer`,
/// `ZSrsScheduler`, `ZRepetitionStore`, `.apply(`, `.initial(`, `.put(`,
/// `reviewCard`, `ZRepetitionInfo`). L'introduction d'un champ reviewer SRS (ou
/// d'un appel `apply`/`reviewCard`) rougit donc immédiatement l'AC (INJ-1).
///
/// Contraste voulu avec `ZStudySessionEngine` (ES-4.2) qui DÉTIENT un
/// `ZSessionReviewer` (voie d'écriture UNIQUE) : `ZLinearSessionState` n'en
/// détient AUCUN (zéro voie).
///
/// ⚠️ Accès au système de fichiers (`dart:io`) ⇒ `@TestOn('vm')` (miroir de
/// `z_purity_test.dart`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Symboles SRS **interdits** dans la source du runtime linéaire (AC2a). Leur
/// seule présence prouverait l'existence d'un point d'écriture SRS ⇒ violation
/// de « zéro écriture SM-2 PAR CONSTRUCTION » (AD-23).
///
/// Note : ces motifs incluent la ponctuation d'appel (`.apply(` etc.) pour ne
/// PAS faux-positiver sur de la prose de dartdoc qui doit pouvoir NOMMER ces
/// concepts (« ne mentionne jamais `apply` ») ; on interdit l'APPEL, pas le mot.
const List<String> _bannedSrsSymbols = <String>[
  'ZSessionReviewer',
  'ZSrsScheduler',
  'ZRepetitionStore',
  'ZRepetitionInfo',
  '.apply(',
  '.initial(',
  '.put(',
  'reviewCard',
];

void main() {
  test('AC2a — z_linear_session_state.dart ne contient AUCUN symbole SRS', () {
    final source = File('lib/src/domain/z_linear_session_state.dart');
    expect(source.existsSync(), isTrue,
        reason: 'source introuvable (cwd = ${Directory.current.path})');

    final lines = source.readAsLinesSync();
    // Contre-preuve R12 : le scan DOIT réellement voir du contenu.
    expect(lines, isNotEmpty, reason: 'source vide — rien scanné');

    // On scanne le CODE hors dartdoc/commentaires : la doc doit pouvoir nommer
    // les concepts SRS (contraste AD-23) sans faux-positiver ; seul un symbole
    // SRS dans le CODE prouverait un point d'écriture atteignable.
    final violations = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trimLeft();
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
        continue; // ligne de commentaire/dartdoc — ignorée
      }
      for (final symbol in _bannedSrsSymbols) {
        if (raw.contains(symbol)) {
          violations.add('${source.path}:${i + 1} → $symbol dans « ${raw.trim()} »');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'symbole(s) SRS détecté(s) dans le runtime linéaire — la garantie '
          '« zéro écriture SM-2 PAR CONSTRUCTION » (AD-23) est violée :\n'
          '${violations.join('\n')}',
    );
  });
}
