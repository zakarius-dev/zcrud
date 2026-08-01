/// CHAT-3b — `ZContentBlock.accessibleText` : le résumé annonçable, réglé UNE
/// fois pour TOUS les adaptateurs.
///
/// 🔴 Le défaut que ces gardes rendent inexprimable, MESURÉ par le lot C6 :
/// `AssistMessage.data` de Syncfusion exige un `String`, et l'adaptateur avait
/// écrit un résumé local qui ne connaissait que `ZTextBlock`. Un **tableau**,
/// un bloc de **sources**, un diagramme n'étaient donc annoncés **nulle part** —
/// et chaque adaptateur futur aurait rouvert le même trou.
///
/// ⚠️ **PAS de `@TestOn('vm')`** : ce fichier ne lit aucune source, il exerce du
/// pur-Dart. Il DOIT donc rester exécutable par `dart test -p node` (gate
/// `web-determinism`).
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// **Un** représentant de CHAQUE variante, portant de la donnée réelle.
///
/// 🔴 C'est la table de non-vacuité de tout ce fichier : si une variante y
/// manquait, « toutes les variantes sont couvertes » serait vrai par omission.
final Map<String, ZContentBlock> kOnePerKind = <String, ZContentBlock>{
  'text': const ZTextBlock(text: 'bonjour'),
  'table': const ZTableBlock(
    title: 'tarif',
    headers: <String>['code', 'droit'],
    rows: <List<String>>[
      <String>['0101', 'cinq'],
    ],
  ),
  'keyDefinition': const ZKeyDefinitionBlock(
    term: 'dedouanement',
    definition: 'mise a la consommation',
    source: 'annexe',
  ),
  'comparisonTable': const ZComparisonTableBlock(
    title: 'comparatif',
    columns: <ZComparisonColumn>[
      ZComparisonColumn(header: 'avant', values: <String>['lent']),
      ZComparisonColumn(header: 'apres', values: <String>['rapide']),
    ],
  ),
  'timeline': const ZTimelineBlock(
    title: 'chronologie',
    events: <ZTimelineEvent>[
      ZTimelineEvent(date: '1789', title: 'octroi', description: 'suppression'),
    ],
  ),
  'alert': const ZAlertBlock(
    level: 'warning',
    title: 'attention',
    message: 'verifier',
  ),
  'mermaidDiagram': const ZMermaidDiagramBlock(
    title: 'schema',
    code: 'graph TD;',
  ),
  'sources': ZSourcesBlock(
    sources: <ZChatSource>[
      ZChatSource.fromJson(const <String, dynamic>{
        'source_type': 'article',
        'display_text': 'article 42',
      })!,
    ],
  ),
  'suggestions': const ZSuggestionsBlock(
    suggestions: <ZChatSuggestion>[
      ZChatSuggestion(id: 's1', type: 'followUp', content: 'et ensuite ?'),
    ],
  ),
  'custom': ZCustomContentBlock('legalReference', const <String, dynamic>{
    'articles': <String>['art. 42'],
  }),
};

void main() {
  group('🔴 G-A1 — COUVERTURE EXHAUSTIVE : aucune variante n\'est muette', () {
    test('la table de témoins couvre les 9 variantes fermées + le variant '
        'OUVERT (non-vacuité de tout ce fichier)', () {
      // Si une variante était ajoutée au kernel sans témoin ici, `_accessibleParts`
      // casserait la COMPILATION (switch exhaustif) — mais ce test-ci, lui,
      // resterait vert. Il compte donc explicitement.
      expect(kOnePerKind, hasLength(10));
      expect(
        kOnePerKind.entries
            .where((MapEntry<String, ZContentBlock> e) => e.key != 'custom')
            .map((MapEntry<String, ZContentBlock> e) => e.value.kind)
            .toSet(),
        <String>{
          'text',
          'table',
          'keyDefinition',
          'comparisonTable',
          'timeline',
          'alert',
          'mermaidDiagram',
          'sources',
          'suggestions',
        },
      );
    });

    test('CHAQUE variante rend un texte NON VIDE, sans jamais lever', () {
      for (final MapEntry<String, ZContentBlock> e in kOnePerKind.entries) {
        final String text = e.value.accessibleText();
        expect(text.trim(), isNotEmpty,
            reason: '🔴 la variante `${e.key}` est MUETTE : un lecteur d\'écran '
                'ne dirait rien de ce bloc — il devient invisible sans que '
                'rien ne le signale');
      }
    });

    test('🔴 LE défaut C6 : le tableau, les sources et les suggestions sont '
        'annoncés — pas seulement le texte', () {
      // C6 concaténait UNIQUEMENT les `ZTextBlock`. Ces trois assertions
      // rougiraient sur ce résumé-là.
      expect(kOnePerKind['table']!.accessibleText(), contains('0101'),
          reason: '🔴 les LIGNES du tableau ne sont pas annoncées');
      expect(kOnePerKind['table']!.accessibleText(), contains('droit'),
          reason: '🔴 les EN-TÊTES du tableau ne sont pas annoncés');
      expect(kOnePerKind['sources']!.accessibleText(), contains('article 42'),
          reason: '🔴 la PROVENANCE n\'est pas annoncée');
      expect(
        kOnePerKind['suggestions']!.accessibleText(),
        contains('et ensuite ?'),
        reason: '🔴 les RELANCES ne sont pas annoncées',
      );
      expect(kOnePerKind['timeline']!.accessibleText(), contains('1789'));
      expect(
        kOnePerKind['comparisonTable']!.accessibleText(),
        allOf(contains('avant'), contains('rapide')),
      );
      expect(
        kOnePerKind['alert']!.accessibleText(),
        allOf(contains('warning'), contains('verifier')),
      );
      expect(kOnePerKind['mermaidDiagram']!.accessibleText(), contains('graph'));
      expect(
        kOnePerKind['keyDefinition']!.accessibleText(),
        allOf(contains('dedouanement'), contains('mise a la consommation')),
      );
    });

    test('les cellules d\'une ligne sont SÉPARÉES — « 0101 cinq », jamais '
        '« 0101cinq »', () {
      final String text = kOnePerKind['table']!.accessibleText();
      expect(text, contains('0101${kZContentBlockAccessibleCellSeparator}cinq'),
          reason: '🔴 sans séparateur, deux cellules voisines fusionnent en un '
              'mot qui n\'existe pas — l\'annonce devient FAUSSE');
    });
  });

  group('🔴 G-A2 — JAMAIS de chaîne vide, JAMAIS de payload dumpé', () {
    test('un bloc sans aucune donnée retombe sur son `kind`, jamais sur `\'\'`',
        () {
      for (final ZContentBlock empty in <ZContentBlock>[
        const ZTextBlock(),
        const ZTableBlock(),
        const ZKeyDefinitionBlock(),
        const ZComparisonTableBlock(),
        const ZTimelineBlock(),
        const ZAlertBlock(),
        const ZMermaidDiagramBlock(),
        const ZSourcesBlock(),
        const ZSuggestionsBlock(),
      ]) {
        expect(empty.accessibleText(), empty.kind,
            reason: '🔴 `${empty.kind}` vide s\'annonce « » : le bloc devient '
                'INVISIBLE au lecteur d\'écran');
      }
    });

    test('un `kind` lui-même vide retombe sur un jeton machine non vide', () {
      expect(
        ZCustomContentBlock('', const <String, dynamic>{}).accessibleText(),
        kZContentBlockUnknownKind,
      );
      expect(
        ZCustomContentBlock('   ', const <String, dynamic>{}).accessibleText(),
        kZContentBlockUnknownKind,
      );
      expect(kZContentBlockUnknownKind.trim(), isNotEmpty);
    });

    test('🔴 D5 — le payload d\'un bloc OUVERT n\'est PAS annoncé : seul son '
        '`kind` l\'est', () {
      final String text = kOnePerKind['custom']!.accessibleText();
      expect(text, 'legalReference');
      expect(text, isNot(contains('art. 42')),
          reason: '🔴 le dump du payload à l\'oreille est le défaut de lex '
              '(`TextBlock(text: json.toString())`) transposé à l\'a11y');
    });

    test('un message ENTIER agrège tous ses blocs', () {
      final String text = zChatAccessibleTextOf(<ZContentBlock>[
        const ZTextBlock(text: 'intro'),
        kOnePerKind['table']!,
        kOnePerKind['sources']!,
      ]);
      expect(text, contains('intro'));
      expect(text, contains('0101'));
      expect(text, contains('article 42'));
      // Une suite VIDE n'a rien à annoncer — inventer un texte serait mentir.
      expect(zChatAccessibleTextOf(const <ZContentBlock>[]), isEmpty);
    });
  });

  group('🔴 G-A3 — AD-4 : le seam d\'hôte, et AD-10 : il ne peut pas nuire',
      () {
    test('un resolver d\'hôte prend le pas sur TOUTE variante, custom comprise',
        () {
      String? resolver(ZContentBlock b) =>
          b is ZCustomContentBlock ? 'reference juridique' : null;
      expect(
        kOnePerKind['custom']!.accessibleText(resolver: resolver),
        'reference juridique',
        reason: '🔴 AD-4 : un bloc ouvert d\'hôte doit pouvoir fournir SON '
            'annonce — sinon la famille n\'est ouverte que sur le papier',
      );
      // …et les variantes qu'il décline gardent le résumé du kernel.
      expect(
        kOnePerKind['table']!.accessibleText(resolver: resolver),
        kOnePerKind['table']!.accessibleText(),
        reason: '🔴 un resolver partiel doit laisser le reste INCHANGÉ — la '
            'sémantique `null` du port de rendu, transposée',
      );
      // Le seam vaut aussi pour une variante FERMÉE (localisation d'hôte).
      expect(
        kOnePerKind['table']!.accessibleText(resolver: (_) => 'Tableau tarif'),
        'Tableau tarif',
      );
    });

    test('AD-10 — un resolver qui LÈVE est absorbé, le bloc reste annoncé', () {
      expect(
        () => kOnePerKind['table']!.accessibleText(
          resolver: (_) => throw StateError('hôte cassé'),
        ),
        returnsNormally,
      );
      expect(
        kOnePerKind['table']!
            .accessibleText(resolver: (_) => throw StateError('hôte cassé')),
        contains('0101'),
        reason: '🔴 un hôte cassé rendrait le message MUET au lieu de dégradé',
      );
    });

    test('un resolver qui rend une chaîne VIDE ou BLANCHE est IGNORÉ', () {
      for (final String? mute in <String?>[null, '', '   ', '\n']) {
        expect(
          kOnePerKind['table']!.accessibleText(resolver: (_) => mute),
          contains('0101'),
          reason: '🔴 le seam permettrait de rendre un bloc muet PAR ACCIDENT '
              '(un `map[...]` qui rate sa clé rend `null`, un `join` de rien '
              'rend `\'\'`)',
        );
      }
    });

    test('le resolver voit CHAQUE bloc exactement une fois, dans l\'ordre', () {
      final List<String> seen = <String>[];
      zChatAccessibleTextOf(
        <ZContentBlock>[
          const ZTextBlock(text: 'a'),
          kOnePerKind['table']!,
          kOnePerKind['custom']!,
        ],
        resolver: (ZContentBlock b) {
          seen.add(b.kind);
          return null;
        },
      );
      expect(seen, <String>['text', 'table', 'legalReference']);
    });
  });

  group('🔴 G-A4 — AUCUNE prose du socle : ni mot, ni langue', () {
    test('le résumé d\'un bloc ne contient QUE de la donnée et de la '
        'ponctuation', () {
      // Sur des témoins dont on connaît TOUTE la donnée, la sortie ne doit
      // contenir aucun caractère alphabétique qui n'en vienne pas.
      const ZContentBlock block = ZTableBlock(
        headers: <String>['aa'],
        rows: <List<String>>[
          <String>['bb'],
        ],
      );
      final String text = block.accessibleText();
      expect(
        text.replaceAll(RegExp('[ab]'), '').replaceAll(
              RegExp(r'[\s,]'),
              '',
            ),
        isEmpty,
        reason: '🔴 un mot du SOCLE s\'est glissé dans l\'annonce : « $text ». '
            'Une rubrique écrite en dur (« Tableau : », « Sources : ») est une '
            'régression de localisation SILENCIEUSE dans un socle '
            'multi-consommateurs — même arbitrage que `z_chat_labels.dart`, '
            'qui refuse jusqu\'au repli français.',
      );
    });

    test('les séparateurs sont de la PONCTUATION, pas des mots', () {
      for (final String sep in <String>[
        kZContentBlockAccessibleSeparator,
        kZContentBlockAccessibleCellSeparator,
      ]) {
        expect(RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(sep), isFalse,
            reason: '🔴 « $sep » porte une lettre : c\'est un LIBELLÉ déguisé');
      }
    });
  });
}
