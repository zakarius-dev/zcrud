@TestOn('vm')
// Lot L10 — PRÉCÉDENCE du remplacement TOTAL sur le porteur de créneaux.
//
// ⚠️ Pourquoi une garde de SOURCE, et pas une garde d'arbre : la combinaison
// `composerBuilder` + `composerSlots` est refusée en debug par l'assertion du
// contrat (cf. `z_chat_composer_l10_slots_test.dart`, L10-3). Elle n'est donc
// pas CONSTRUCTIBLE dans un test — la précédence ne s'observe qu'en release,
// hors d'atteinte du harnais. Ce qui reste mesurable, et qui est exactement
// la propriété visée, est l'ORDRE dans le corps de `_composer` : le retour
// anticipé sur le remplacement total précède toute lecture du porteur.
//
// La contre-preuve ci-dessous montre que l'indexeur VOIT un ordre inversé —
// sans elle, une garde d'ordre peut être verte sur n'importe quoi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

const List<String> _screens = <String>[
  'lib/src/presentation/view/z_chat_conversation_screen.dart',
  'lib/src/presentation/view/z_chat_notebook_screen.dart',
];

/// Le corps de `_composer`, de sa signature à son accolade fermante.
String _composerBody(String source) {
  const String head = 'Widget? _composer(BuildContext context) {';
  final int i = source.indexOf(head);
  expect(i, isNot(-1), reason: '`_composer` introuvable : garde VACUELLE');
  final int j = source.indexOf('\n  }\n', i);
  expect(j, isNot(-1), reason: 'fin de `_composer` introuvable');
  return source.substring(i, j);
}

/// `true` si le retour anticipé sur le remplacement total précède la
/// première lecture du porteur de créneaux.
bool _totalReplacementFirst(String body) {
  final int custom = body.indexOf('if (custom != null) return custom(');
  final int slots = body.indexOf('widget.composerSlots');
  if (custom < 0 || slots < 0) return false;
  return custom < slots;
}

void main() {
  group('🔴 L10-4 — PRÉCÉDENCE : le remplacement TOTAL prime', () {
    test('dans les deux écrans, `_composer` retourne le composer d\'hôte '
        'AVANT de lire le porteur de créneaux', () {
      for (final String rel in _screens) {
        final String src = File('${packageRoot().path}/$rel').readAsStringSync();
        final String body = _composerBody(src);
        expect(
          body.contains('if (custom != null) return custom('),
          isTrue,
          reason: '$rel : retour anticipé du remplacement total absent',
        );
        expect(
          body.contains('widget.composerSlots'),
          isTrue,
          reason: '$rel : le porteur n\'est jamais lu — relais absent',
        );
        expect(
          _totalReplacementFirst(body),
          isTrue,
          reason: '$rel : le porteur est lu AVANT le retour anticipé',
        );
      }
    });

    test('🔬 contre-preuve — l\'indexeur VOIT un ordre inversé', () {
      const String inverted = '''
    final ZChatComposerSlots? slots = widget.composerSlots;
    if (custom != null) return custom(context, a, b);
''';
      expect(_totalReplacementFirst(inverted), isFalse);
      const String ordered = '''
    if (custom != null) return custom(context, a, b);
    final ZChatComposerSlots? slots = widget.composerSlots;
''';
      expect(_totalReplacementFirst(ordered), isTrue);
    });
  });
}
