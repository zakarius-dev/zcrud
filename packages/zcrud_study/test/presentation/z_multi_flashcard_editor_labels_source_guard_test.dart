// Garde de SOURCE des libellés du multi-éditeur (invariant FR-26).
//
// Le complément de la garde de comportement (le dialogue affiche bien le
// libellé posé, ou le repli du socle) : elle prouve qu'AUCUN libellé de repli
// n'est ÉCRIT dans ce paquet. Un `?? 'Discard changes?'` posé « juste pour
// dépanner » resterait invisible à la garde de comportement — elle verrait le
// bon texte à l'écran sans voir qu'il n'est plus surchargeable par la locale.
//
// Accès `dart:io` ⇒ @TestOn('vm').
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' show stripped;

const _editor = 'lib/src/presentation/z_multi_flashcard_editor.dart';

/// Repli littéral posé sur un libellé injecté : `labels.xxx ?? 'du texte'`.
final RegExp _literalFallback = RegExp(r"labels\.\w+\s*\?\?\s*['\x22]");

void main() {
  late List<String> code;

  setUp(() {
    final file = File(_editor);
    expect(file.existsSync(), isTrue,
        reason: 'sonde : $_editor introuvable (cwd=${Directory.current.path}) — '
            '`flutter test` doit être lancé DEPUIS le package');
    code = stripped(file);
  });

  group('🔴 FR-26 — aucun libellé de repli écrit dans ce paquet', () {
    test('sonde : le scanner voit RÉELLEMENT le code de l\'éditeur', () {
      expect(code, isNotEmpty);
      expect(code.any((l) => l.contains('ZDiscardChangesGuard(')), isTrue,
          reason: 'sonde : la garde de sortie doit être dans le corpus scanné');
    });

    test('🔴 les quatre libellés de sortie sont RELAYÉS tels quels', () {
      for (final relay in <String>[
        'title: widget.labels.discardTitle,',
        'message: widget.labels.discardMessage,',
        'confirmLabel: widget.labels.discardConfirmLabel,',
        'cancelLabel: widget.labels.discardCancelLabel,',
      ]) {
        expect(code.map((l) => l.trim()).contains(relay), isTrue,
            reason: '🔴 « $relay » absent : le libellé n\'atteint pas le '
                'dialogue d\'abandon, qui retombe sur un repli non '
                'surchargeable');
      }
    });

    test('🔴 aucun repli LITTÉRAL sur un libellé injecté', () {
      final offenders = <String>[
        for (var i = 0; i < code.length; i++)
          if (_literalFallback.hasMatch(code[i])) '$_editor:${i + 1} → ${code[i].trim()}',
      ];
      expect(offenders, isEmpty,
          reason: '🔴 un libellé de repli est écrit dans ce paquet :\n'
              '${offenders.join('\n')}\n'
              'Un libellé absent doit rester `null` : le défaut audité du '
              'widget d\'édition (ou de la garde) s\'applique alors, et reste '
              'surchargeable.');
    });

    test('contre-preuve : le motif MORD réellement', () {
      expect(
        _literalFallback
            .hasMatch("      title: widget.labels.discardTitle ?? 'Discard?',"),
        isTrue,
        reason: 'sans ce pouvoir, l\'assertion à vide serait infalsifiable',
      );
      expect(
        _literalFallback.hasMatch('      title: widget.labels.discardTitle,'),
        isFalse,
        reason: 'le motif ne doit pas crier au loup sur un relais correct',
      );
    });
  });
}
