/// Gardes de SOURCE de la surface de liste — grep NÉGATIF outillé (CR-IFFD-39).
///
/// Les gardes de comportement prouvent ce qui se produit sur le chemin qu'elles
/// montent. Elles sont **aveugles** à une seconde tuile qu'aucun test ne monte —
/// et c'est exactement ainsi que lex s'est retrouvé avec `_ConversationTile`
/// (`conversations_screen.dart:634-771`) **et** `SearchResultTile`
/// (`widgets/chat/search_result_tile.dart:7-124`), qui ont divergé : la seconde
/// perd l'épinglage, le compte de messages, le glisser-supprimer et l'appui
/// long, et fige `locale: 'fr'`.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_sources.dart';

/// Compte les occurrences de [pattern] dans `lib/`, par fichier.
Map<String, int> _sites(RegExp pattern) {
  final Map<String, int> out = <String, int>{};
  for (final MapEntry<String, List<String>> e in strippedLib().entries) {
    for (final String l in e.value) {
      if (pattern.hasMatch(l)) out[e.key] = (out[e.key] ?? 0) + 1;
    }
  }
  return out;
}

int _total(Map<String, int> sites) =>
    sites.values.fold<int>(0, (int a, int b) => a + b);

void main() {
  group('🔴 G39-S1 — AUCUNE seconde tuile de conversation', () {
    test('`ZChatConversationTile(` n\'est instancié qu\'à UN seul endroit', () {
      // 🔴 Le fichier qui DÉCLARE la classe porte forcément une occurrence (son
      // constructeur). Le compter comme une instanciation rendrait la garde
      // fausse dès le premier jour — donc désactivée. Il est retiré, et le fait
      // qu'il existe est asserté à part (non-vacuité).
      final Map<String, int> declaring =
          _sites(RegExp(r'^class\s+ZChatConversationTile\b'));
      expect(declaring, hasLength(1),
          reason: '🔴 GARDE VACUELLE : la classe est introuvable');
      final Map<String, int> sites = <String, int>{
        for (final MapEntry<String, int> e
            in _sites(RegExp(r'\bZChatConversationTile\s*\(')).entries)
          if (e.key != declaring.keys.single) e.key: e.value,
      };
      expect(_total(sites), 1,
          reason: '🔴 une SECONDE fabrique de tuile. C\'est le défaut mesuré '
              'chez lex : deux tuiles parallèles, dont l\'une perd l\'épinglage, '
              'le compte de messages et l\'appui long, et fige la locale. '
              'Sites : $sites');
      expect(sites.keys.single.replaceAll(r'\', '/'),
          endsWith('lib/src/presentation/view/z_chat_conversation_list.dart'));
    });

    test('🔬 contre-preuve — le motif VOIT une seconde instanciation', () {
      final RegExp p = RegExp(r'\bZChatConversationTile\s*\(');
      expect(p.hasMatch('      return ZChatConversationTile(x: 1);'), isTrue);
      expect(p.hasMatch('  final ZChatConversationTile t = w;'), isFalse,
          reason: '🔴 sans la parenthèse, une simple déclaration de type '
              'accuserait — et une garde qui crie au loup finit désactivée');
    });
  });

  group('🔴 G39-S2 — UN SEUL surlignage', () {
    test('`zChatHighlightRanges` est défini une fois, et rien d\'autre ne '
        'découpe de texte', () {
      final Map<String, int> defs = _sites(
        RegExp(r'^List<ZChatHighlightRange>\s+zChatHighlightRanges\s*\('),
      );
      expect(_total(defs), 1, reason: '🔴 deux implémentations : sites $defs');
      // Chez lex, la tuile de recherche réimplémente sa propre boucle
      // `indexOf` (`search_result_tile.dart:95-116`) alors qu'un utilitaire
      // partagé existe (`utils/search_highlight.dart:38-103`) — et une
      // troisième variante vit dans `widgets/search_content.dart:325`.
      final Map<String, int> loops = _sites(RegExp(r'\.indexOf\s*\('));
      for (final String path in loops.keys) {
        expect(path.replaceAll(r'\', '/'),
            endsWith('lib/src/presentation/view/z_chat_highlight.dart'),
            reason: '🔴 un second découpage de texte hors du fichier de '
                'surlignage : la divergence de lex, réintroduite. Sites : '
                '$loops');
      }
      expect(_total(loops), greaterThan(0),
          reason: '🔴 GARDE VACUELLE : plus aucun `indexOf` — le surlignage a '
              'disparu et la garde passerait sur n\'importe quoi');
    });
  });

  group('🔴 G39-S3 — les champs NÔTRES ne sont pas rendus d\'office', () {
    test('`messageCount` n\'est lu NULLE PART dans `lib/`', () {
      final Map<String, int> sites = _sites(RegExp(r'\.messageCount\b'));
      expect(sites, isEmpty,
          reason: '🔴 `messageCount` est un champ de NOTRE schéma, absent chez '
              'IFFD. Le rendre d\'office y peindrait une décoration morte, et '
              'l\'imposerait à tout hôte. Il passe par un slot (`trailing`, '
              '`subtitleBuilder`) ou un badge. Sites : $sites');
    });

    test('`pinned` n\'est lu QUE par la fabrique de descripteurs', () {
      final Map<String, int> sites = _sites(RegExp(r'\.pinned\b'));
      expect(sites, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : plus aucune lecture de `pinned` — la '
              'fabrique d\'actions ne sait plus quel libellé montrer');
      for (final String path in sites.keys) {
        expect(
          path.replaceAll(r'\', '/'),
          endsWith(
            'lib/src/presentation/view/z_chat_conversation_actions.dart',
          ),
          reason: '🔴 `pinned` est lu par le RENDU : la tuile décore un champ '
              'que le grep négatif prouve absent chez IFFD '
              '(`grep -rn "pinned" iffd/lib/ai_assistant/` ⇒ EXIT=1). Sites : '
              '$sites',
        );
      }
    });

    test('`isArchived` — le champ de l\'AUTRE hôte — n\'entre pas non plus', () {
      // Il existe chez IFFD (`chatbot_conversation.dart:25`) et n'y est jamais
      // lu comme filtre. Il passe par `extra` + un prédicat de badge, jamais par
      // un champ du socle.
      expect(_sites(RegExp(r'\bisArchived\b')), isEmpty);
    });
  });

  group('🔴 G39-S4 — aucune NAVIGATION, aucun drapeau de déploiement', () {
    test('rien ne pousse de route depuis la surface de liste', () {
      final Map<String, int> sites = _sites(
        RegExp(r'Navigator\s*\.|\bNavigator\.of\s*\('),
      );
      expect(sites, isEmpty,
          reason: '🔴 la navigation appartient à l\'hôte : le socle n\'expose '
              'que des callbacks (AD-11). Sites : $sites');
    });

    test('aucun drapeau booléen de disponibilité d\'action', () {
      // Le drapeau de déploiement de lex : ne PAS passer le callback EST le
      // drapeau. Un `enablePin`/`supportsShare` rendrait deux sources de vérité.
      final Map<String, int> sites = _sites(
        RegExp(r'\b(enable|supports|allow)(Pin|Share|Delete|Retire|Restore)\b'),
      );
      expect(sites, isEmpty, reason: '🔴 drapeau de déploiement : $sites');
    });

    test('aucune canonicalisation d\'URL de partage', () {
      final Map<String, int> sites = _sites(
        RegExp(r'\bUri\.(parse|https?|base)\b|\bcanonicali[sz]e'),
      );
      expect(sites, isEmpty,
          reason: '🔴 l\'URL de partage est OPAQUE (`ZChatShareLink.url`) : lex '
              'rend un chemin relatif, un autre hôte une URL absolue ou un lien '
              'profond. La parser ici casserait l\'un des deux. Sites : $sites');
    });
  });

  group('🔴 G39-S5 — toute clé nouvelle porte son repli', () {
    test('les clés de la liste sont déclarées ET repliées', () {
      for (final String key in <String>[
        kZChatLabelConversations,
        kZChatLabelLoadingConversations,
        kZChatLabelConversationsError,
        kZChatLabelRetry,
        kZChatLabelNoConversations,
        kZChatLabelNoResults,
        kZChatLabelNewConversation,
        kZChatLabelLoadMore,
        kZChatLabelSelectedCount,
        kZChatLabelExitSelection,
        kZChatLabelRowSelected,
        kZChatLabelPin,
        kZChatLabelUnpin,
        kZChatLabelRetire,
        kZChatLabelRestore,
        kZChatLabelTrim,
        kZChatLabelRetireSelected,
        kZChatLabelTimeNow,
        kZChatLabelTimeMinutes,
        kZChatLabelTimeHours,
        kZChatLabelTimeDays,
        kZChatLabelTimeWeeks,
        kZChatLabelTimeMonths,
        kZChatLabelTimeYears,
      ]) {
        expect(kZChatLabelKeys, contains(key), reason: 'clé non déclarée : $key');
        expect(kZChatLabelFallbacks[key], isNotNull,
            reason: '🔴 clé SANS repli : $key s\'afficherait tel quel');
        expect(kZChatLabelFallbacks[key], isNotEmpty);
      }
    });

    test('les clés PORTEUSES DE COMPTE contiennent bien le marqueur', () {
      for (final String key in <String>[
        kZChatLabelSelectedCount,
        kZChatLabelTimeMinutes,
        kZChatLabelTimeHours,
        kZChatLabelTimeDays,
        kZChatLabelTimeWeeks,
        kZChatLabelTimeMonths,
        kZChatLabelTimeYears,
      ]) {
        expect(kZChatLabelFallbacks[key], contains(kZChatCountPlaceholder),
            reason: '🔴 le repli de $key ne porte pas $kZChatCountPlaceholder : '
                'le compte n\'apparaîtra jamais');
      }
      // …et un repli SANS marqueur ne fabrique pas de texte cassé (AD-10).
      expect(kZChatLabelFallbacks[kZChatLabelTimeNow],
          isNot(contains(kZChatCountPlaceholder)));
    });
  });
}
