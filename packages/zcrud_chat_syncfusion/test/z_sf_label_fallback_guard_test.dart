// 🔴 HIGH-1 — AUCUNE clé de la coquille sans repli lisible.
//
// Défaut mesuré par la revue de fin d'epic : les deux clés `zchat.sf.*` — des
// **noms d'auteur affichés** que `AssistMessageAuthor` exige non nuls —
// n'avaient aucun repli. Un hôte au registre non alimenté lisait littéralement
// `zchat.sf.userAuthor` au-dessus de ses propres messages. Le paquet reprenait
// l'arbitrage de `z_chat_labels.dart`, lequel divergeait de la convention du
// dépôt (`zcrud_session`, `zcrud_study` : `label(context, 'cancel',
// fallback: 'Annuler')`).
//
// ⚠️ `@TestOn('vm')` : le volet SOURCE lit le disque.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_chat/assist_view.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';

import 'z_sf_assist_view_test.dart' show controllerWith, SfRig;

Directory _repoRoot() {
  Directory d = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${d.path}/melos.yaml').existsSync()) return d;
    final Directory parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  fail('Racine du dépôt introuvable depuis ${Directory.current.path}');
}

List<File> _libFiles() {
  final Directory lib = Directory(
    '${_repoRoot().path}/packages/zcrud_chat_syncfusion/lib',
  );
  final List<File> files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: '🔴 GARDE VACUELLE : aucun fichier lu');
  return files;
}

void main() {
  test('volet CARTE — replis et clés ÉGAUX en ensemble, aucun repli = la clé',
      () {
    expect(kZSfAssistLabelFallbacks.keys.toSet(), kZSfAssistLabelKeys.toSet(),
        reason: '🔴 une clé sans repli affiche son discriminant machine.');
    for (final MapEntry<String, String> e
        in kZSfAssistLabelFallbacks.entries) {
      expect(e.value.trim(), isNotEmpty, reason: '🔴 repli VIDE : ${e.key}');
      expect(e.value, isNot(e.key));
      expect(e.value, isNot(startsWith(kZSfAssistLabelPrefix)));
    }
    expect(kZSfAssistLabelFallbacks, hasLength(2));
  });

  test('volet SOURCE — `label(` n\'est appelé QUE depuis `z_sf_assist_labels`',
      () {
    final List<String> offenders = <String>[];
    for (final File f in _libFiles()) {
      final String path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('z_sf_assist_labels.dart')) continue;
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('///')) {
          continue;
        }
        if (RegExp(r'(?<![\w.])label\s*\(\s*context').hasMatch(line)) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '🔴 appel DIRECT à `label(context, …)` hors du fichier de '
            'clés : passez par `zSfAssistLabel`, qui porte le repli.\n'
            '${offenders.join('\n')}');

    // Volet NON-VACUITÉ : le résolveur unique passe bien un repli.
    final File labels = _libFiles().firstWhere(
      (File f) =>
          f.path.replaceAll(r'\', '/').endsWith('z_sf_assist_labels.dart'),
    );
    expect(labels.readAsStringSync(),
        contains('fallback: kZSfAssistLabelFallbacks[key]'),
        reason: '🔴 GARDE VACUELLE : plus aucun repli n\'est transmis.');

    // 🔬 CONTRE-PREUVE : le motif VOIT un appel direct, et n'accuse PAS le
    // résolveur unique.
    final RegExp motif = RegExp(r'(?<![\w.])label\s*\(\s*context');
    expect(motif.hasMatch('    final n = label(context, kZSfAssistLabelUserAuthor);'),
        isTrue);
    expect(motif.hasMatch('    zSfAssistLabel(context, kZSfAssistLabelUserAuthor)'),
        isFalse);
  });

  testWidgets('volet RENDU — sans registre, les noms d\'auteur sont LISIBLES',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      const ZChatMessage(
        id: 'u1',
        conversationId: 'c1',
        role: ZChatRole.user,
        contentBlocks: <ZContentBlock>[ZTextBlock(text: 'question')],
      ),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    // 🔴 AUCUN `ZcrudScope(labels:)` — l'hôte non configuré, exactement.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZChatShellRendererScope(
            renderer: const ZSfAssistShellRenderer(),
            child: ZChatConversationView(controller: rig.controller),
          ),
        ),
      ),
    );
    await tester.pump();

    final SfAIAssistView view = tester.widget<SfAIAssistView>(
      find.byType(SfAIAssistView),
    );
    for (final AssistMessage m in view.messages) {
      final String name = m.author?.name ?? '';
      expect(name, isNotEmpty);
      expect(name, isNot(startsWith(kZSfAssistLabelPrefix)),
          reason: '🔴 CLÉ BRUTE en nom d\'auteur : "$name" — le défaut HIGH-1.');
    }
    expect(view.messages.first.author?.name,
        kZSfAssistLabelFallbacks[kZSfAssistLabelUserAuthor]);
  });
}
