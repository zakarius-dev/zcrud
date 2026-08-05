/// CR-IFFD-71 — gardes de **SOURCE** de la distinction notebook/conversation.
///
/// Les gardes de comportement (`z_chat_cr71_notebook_test.dart`) prouvent ce
/// qui se produit sur l'arbre qu'elles montent. Elles sont AVEUGLES à une
/// réécriture du notebook qui construirait sa propre liste — tant qu'elle rend
/// les mêmes textes. Ce fichier est le grep négatif outillé.
///
/// * **G-N1** — le notebook est une COMPOSITION : il monte la racine commune
///   (`ZChatConversationView`) et ne construit NI liste, NI tuile, NI identité.
///   C'est ce qui rend l'anti-divergence structurelle (motif CR-LEX-78) : la
///   fabrique de tuile unique (G-S5) rend les deux surfaces.
/// * **G-N2** — les créneaux TRAVERSENT la fabrique unique : chaque builder est
///   relayé de la vue à `_ZChatList`, puis de `_ZChatList` à la tuile. Un
///   créneau « déclaré mais non relayé » serait une promesse morte.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

/// Le fichier de la surface notebook.
const String _notebook = 'lib/src/presentation/view/z_chat_notebook_view.dart';

/// Le fichier de la racine commune (et de la fabrique unique `_ZChatList._item`).
const String _conversation =
    'lib/src/presentation/view/z_chat_conversation_view.dart';

void main() {
  group('🔴 G-N1 — le notebook DÉLÈGUE à la racine commune', () {
    test('il monte `ZChatConversationView` UNE fois, et ne construit ni '
        'liste, ni tuile, ni défilement', () {
      final List<String> lines = stripped(libFile(_notebook));
      final String src = lines.join('\n');

      // Non-vacuité : la surface existe bien.
      expect(
        RegExp(r'class\s+ZChatNotebookView\b').hasMatch(src),
        isTrue,
        reason: '🔴 GARDE VACUELLE : `ZChatNotebookView` introuvable',
      );

      final int delegations = RegExp(
        r'\bZChatConversationView\s*\(',
      ).allMatches(src).length;
      expect(
        delegations,
        1,
        reason:
            '🔴 le notebook doit monter la racine commune EXACTEMENT une '
            'fois. 0 = il a réécrit son rendu (la « surface B » d\'IFFD, '
            'motif CR-LEX-78) ; 2+ = deux fils dans une même surface.',
      );

      for (final RegExp interdit in <RegExp>[
        // Un SECOND constructeur de tuile (déjà gardé par G-S5, redit ici avec
        // le nom du fichier fautif).
        RegExp(r'\bZChatMessageTile\s*\('),
        // Une liste à lui — c'est la racine commune qui virtualise.
        RegExp(r'\bListView\b'),
        RegExp(r'\bSliver\w*\b'),
        RegExp(r'\bScrollView\b'),
        // L'identité : PAS un défaut réglable du notebook — le paramètre ne
        // doit même pas exister sur cette surface.
        RegExp(r'\bidentityBuilder\b'),
      ]) {
        expect(
          interdit.hasMatch(src),
          isFalse,
          reason:
              '🔴 `${interdit.pattern}` dans `$_notebook` : le notebook '
              'n\'est plus une composition mince — c\'est le début du '
              'monolithe à booléen que CR-71 remplace.',
        );
      }

      // …et le créneau d'actions, lui, est bien RELAYÉ (champ + passage).
      expect(
        RegExp(r'\bactionsBuilder\b').allMatches(src).length,
        greaterThanOrEqualTo(2),
        reason:
            '🔴 le créneau d\'actions n\'est plus relayé : un notebook '
            'sans actions par message n\'a plus de raison d\'être distinct',
      );
    });

    test('🔬 contre-preuve — les motifs interdits SAVENT rougir', () {
      expect(
        RegExp(
          r'\bZChatMessageTile\s*\(',
        ).hasMatch('      return ZChatMessageTile(message: m);'),
        isTrue,
      );
      expect(
        RegExp(r'\bidentityBuilder\b').hasMatch('    this.identityBuilder,'),
        isTrue,
      );
      expect(
        RegExp(r'\bListView\b').hasMatch('    return ListView.builder('),
        isTrue,
      );
      // …sans crier au loup sur la délégation légitime.
      expect(
        RegExp(
          r'\bZChatMessageTile\s*\(',
        ).hasMatch('    return ZChatConversationView('),
        isFalse,
      );
    });
  });

  group('🔴 G-N2 — les créneaux TRAVERSENT la fabrique unique', () {
    test('chaque builder est relayé vue → _ZChatList → tuile (2 passages)', () {
      final String src = stripped(libFile(_conversation)).join('\n');
      for (final String slot in <String>['identityBuilder', 'actionsBuilder']) {
        final int relays = RegExp('$slot:\\s*$slot\\b').allMatches(src).length;
        expect(
          relays,
          2,
          reason:
              '🔴 `$slot` doit être relayé EXACTEMENT deux fois '
              '(`ZChatConversationView` → `_ZChatList`, puis `_ZChatList` → '
              '`ZChatMessageTile`). $relays passage(s) trouvé(s) : le '
              'créneau est déclaré mais n\'atteint pas la tuile — une '
              'promesse morte, ou un chemin PARALLÈLE est apparu.',
        );
      }
    });

    test('🔬 contre-preuve — le motif de relais voit un passage réel', () {
      final RegExp relay = RegExp(r'actionsBuilder:\s*actionsBuilder\b');
      expect(relay.hasMatch('        actionsBuilder: actionsBuilder,'), isTrue);
      expect(
        relay.hasMatch('        actionsBuilder: null,'),
        isFalse,
        reason:
            '🔴 un relais COUPÉ (`null`) ne doit pas compter comme un '
            'passage',
      );
    });
  });
}
