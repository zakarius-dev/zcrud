// CHAT-0 — AC5. Gardes **G1** (round-trip par type), **G2** (10 kinds
// paramétrés), **G5** (alias PascalCase de lex), **G6** (type inconnu ⇒ payload
// PRÉSERVÉ, jamais du texte) et **G7** (extension par ZTypeRegistry).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Les 10 kinds sondés — 9 fermés + le variant ouvert.
final Map<String, ZContentBlock> _samples = <String, ZContentBlock>{
  'text': const ZTextBlock(text: 'bonjour'),
  'table': const ZTableBlock(
    title: 'T',
    headers: <String>['a', 'b'],
    rows: <List<String>>[
      <String>['1', '2'],
      <String>['3', '4'],
    ],
  ),
  'keyDefinition': const ZKeyDefinitionBlock(
    term: 'douane',
    definition: 'administration',
    source: 'manuel',
  ),
  'comparisonTable': const ZComparisonTableBlock(
    title: 'C',
    columns: <ZComparisonColumn>[
      ZComparisonColumn(header: 'h1', values: <String>['v1', 'v2']),
      ZComparisonColumn(header: 'h2', values: <String>['v3']),
    ],
  ),
  'timeline': const ZTimelineBlock(
    title: 'F',
    events: <ZTimelineEvent>[
      ZTimelineEvent(date: '1789', title: 'e1', description: 'd1'),
      ZTimelineEvent(date: 'vers 1500', title: 'e2'),
    ],
  ),
  'alert': const ZAlertBlock(level: 'warning', title: 'A', message: 'msg'),
  'mermaidDiagram':
      const ZMermaidDiagramBlock(title: 'M', code: 'graph TD; A-->B;'),
  'sources': const ZSourcesBlock(
    sources: <ZChatSource>[
      ZChatSource(
        sourceType: 'web',
        displayText: 'exemple',
        relevanceScore: 0.5,
        snippet: 'extrait',
        breadcrumb: 'a > b',
        ranker: 'bm25',
        corpus: 'c',
        usageStatusRaw: 'cited',
      ),
    ],
  ),
  'suggestions': const ZSuggestionsBlock(
    suggestions: <ZChatSuggestion>[
      ZChatSuggestion(
        id: 's1',
        type: 'followUp',
        content: 'et ensuite ?',
        actions: <ZChatSuggestionAction>[
          ZChatSuggestionAction(
            shortcut: 'k',
            title: 't',
            description: 'd',
            actionType: 'sendMessage',
            payload: <String, dynamic>{
              'a': 1,
              'l': <dynamic>[1, <String, dynamic>{'b': 2}],
            },
          ),
        ],
      ),
    ],
  ),
};

void main() {
  group('G2 — round-trip PARAMÉTRÉ des 10 kinds', () {
    for (final MapEntry<String, ZContentBlock> e in _samples.entries) {
      test('${e.key} : fromJson(toJson()) == original, `kind` conservé', () {
        final Map<String, dynamic> json = e.value.toJson();
        expect(json['type'], e.key, reason: 'discriminant canonique camelCase');
        final ZContentBlock? relu = ZContentBlock.fromJson(json);
        expect(relu.runtimeType, e.value.runtimeType);
        expect(relu!.kind, e.key);
        expect(relu, equals(e.value));
        expect(<Object>{relu, e.value}, hasLength(1),
            reason: 'égalité + hash cohérents (déduplication)');
      });
    }

    test('le variant OUVERT fait aussi son round-trip (10ᵉ kind)', () {
      final ZCustomContentBlock bloc = ZCustomContentBlock(
        'legalReference',
        <String, dynamic>{
          'title': 'Art. 5',
          'articles': <String>['5', '6'],
          'nested': <String, dynamic>{'x': 1},
        },
      );
      final Map<String, dynamic> json = bloc.toJson();
      final ZContentBlock? relu = ZContentBlock.fromJson(json);
      expect(relu, isA<ZCustomContentBlock>());
      expect(relu!.kind, 'legalReference');
      expect(relu, equals(bloc));
    });
  });

  group('G1 — chaque champ compte dans le round-trip', () {
    test('un champ perdu à l\'encodage casse l\'égalité (sonde de mordant)', () {
      // Sonde : deux blocs qui ne diffèrent QUE par le champ le plus discret de
      // chaque type. S'ils étaient dits égaux, un `toJson` amputé passerait.
      expect(
        const ZKeyDefinitionBlock(term: 't', definition: 'd', source: 's'),
        isNot(const ZKeyDefinitionBlock(term: 't', definition: 'd')),
      );
      expect(
        const ZTimelineEvent(date: '1', title: 't', description: 'd'),
        isNot(const ZTimelineEvent(date: '1', title: 't')),
      );
      expect(
        const ZMermaidDiagramBlock(title: 'a', code: 'c'),
        isNot(const ZMermaidDiagramBlock(code: 'c')),
      );
      expect(
        const ZAlertBlock(level: 'info', title: 'a', message: 'm'),
        isNot(const ZAlertBlock(level: 'info', message: 'm')),
      );
    });
  });

  group('G5 — alias PascalCase des documents lex', () {
    test('un bloc lex `KeyDefinition` se relit TYPÉ', () {
      final ZContentBlock? bloc = ZContentBlock.fromJson(<String, dynamic>{
        'type': 'KeyDefinition',
        'data': <String, dynamic>{'term': 'x', 'definition': 'y'},
      });
      expect(bloc, isA<ZKeyDefinitionBlock>());
      expect((bloc! as ZKeyDefinitionBlock).term, 'x');
      // Réécriture CANONIQUE : on lit le PascalCase, on n'en réémet jamais.
      expect(bloc.toJson()['type'], 'keyDefinition');
    });

    test('les 9 alias PascalCase produisent un variant TYPÉ', () {
      final Map<String, Type> attendus = <String, Type>{
        'Text': ZTextBlock,
        'Table': ZTableBlock,
        'KeyDefinition': ZKeyDefinitionBlock,
        'ComparisonTable': ZComparisonTableBlock,
        'Timeline': ZTimelineBlock,
        'Alert': ZAlertBlock,
        'MermaidDiagram': ZMermaidDiagramBlock,
        'Sources': ZSourcesBlock,
        'Suggestions': ZSuggestionsBlock,
      };
      for (final MapEntry<String, Type> e in attendus.entries) {
        final ZContentBlock? bloc = ZContentBlock.fromJson(<String, dynamic>{
          'type': e.key,
          'data': const <String, dynamic>{},
        });
        expect(bloc.runtimeType, e.value,
            reason: 'alias ${e.key} non reconnu ⇒ retombe en ZCustomContentBlock');
      }
    });
  });

  group('G6 — type INCONNU : payload PRÉSERVÉ, jamais transformé en texte', () {
    test('`Quantum` ⇒ ZCustomContentBlock, round-trip IDENTIQUE', () {
      final Map<String, dynamic> source = <String, dynamic>{
        'type': 'Quantum',
        'data': <String, dynamic>{
          'a': 1,
          'b': <String, dynamic>{'c': 2},
        },
      };
      final ZContentBlock? bloc = ZContentBlock.fromJson(source);
      expect(bloc, isA<ZCustomContentBlock>(),
          reason: 'lex ferait `TextBlock(json.toString())` — destructeur');
      expect(bloc, isNot(isA<ZTextBlock>()));
      expect(bloc!.kind, 'Quantum');
      expect((bloc as ZCustomContentBlock).payload,
          <String, dynamic>{'a': 1, 'b': <String, dynamic>{'c': 2}});
      expect(bloc.toJson(), source,
          reason: 'la map d\'origine doit être rendue À L\'IDENTIQUE');
    });

    test('`payload` est NON MODIFIABLE', () {
      final ZCustomContentBlock bloc =
          ZCustomContentBlock('X', <String, dynamic>{'a': 1});
      expect(() => bloc.payload['b'] = 2, throwsUnsupportedError);
    });
  });

  group('AC5 — fromJson est TOTALE et ne lève jamais', () {
    test('raw non-map ⇒ null ; type absent/vide ⇒ null', () {
      expect(ZContentBlock.fromJson(null), isNull);
      expect(ZContentBlock.fromJson(42), isNull);
      expect(ZContentBlock.fromJson('texte'), isNull);
      expect(ZContentBlock.fromJson(<dynamic>[]), isNull);
      expect(ZContentBlock.fromJson(<String, dynamic>{}), isNull);
      expect(ZContentBlock.fromJson(<String, dynamic>{'type': ''}), isNull);
      expect(ZContentBlock.fromJson(<String, dynamic>{'type': 42}), isNull);
    });

    test('`data` absent ou corrompu ⇒ variant aux défauts sûrs', () {
      final ZContentBlock? bloc =
          ZContentBlock.fromJson(<String, dynamic>{'type': 'text'});
      expect(bloc, isA<ZTextBlock>());
      expect((bloc! as ZTextBlock).text, '');

      final ZContentBlock? table = ZContentBlock.fromJson(
        <String, dynamic>{'type': 'table', 'data': 42},
      );
      expect(table, isA<ZTableBlock>());
      expect((table! as ZTableBlock).headers, isEmpty);
    });

    test('éléments illisibles d\'une liste de bloc ⇒ ignorés (liste préservée)',
        () {
      final ZContentBlock? bloc = ZContentBlock.fromJson(<String, dynamic>{
        'type': 'timeline',
        'data': <String, dynamic>{
          'events': <dynamic>[
            <String, dynamic>{'date': '1', 'title': 'a'},
            42,
            null,
            <String, dynamic>{'date': '2', 'title': 'b'},
          ],
        },
      });
      expect((bloc! as ZTimelineBlock).events, hasLength(2));
    });

    test('`headers`/`rows` hostiles ⇒ défauts sûrs, aucun throw', () {
      final ZContentBlock? bloc = ZContentBlock.fromJson(<String, dynamic>{
        'type': 'table',
        'data': <String, dynamic>{
          'headers': <dynamic>['a', 42, null],
          'rows': <dynamic>[
            <dynamic>['1', 2],
            'pas-une-ligne',
          ],
        },
      });
      final ZTableBlock table = bloc! as ZTableBlock;
      expect(table.headers, <String>['a']);
      expect(table.rows, <List<String>>[
        <String>['1'],
      ]);
    });
  });

  group('G7 — extension par ZTypeRegistry (AD-4 pt.3)', () {
    ZTypeRegistry buildRegistry() => ZTypeRegistry()
      ..register(
        'legalReference',
        fromJson: (Map<String, dynamic> json) => <String, dynamic>{
          ...json,
          'decode_par_app': true,
        },
        toJson: (Object value) => <String, dynamic>{
          ...(value as Map<String, dynamic>),
          'encode_par_app': true,
        },
      );

    test('un `type` enregistré est décodé/réencodé par le codec de l\'app', () {
      final ZTypeRegistry registry = buildRegistry();
      final ZContentBlock? bloc = ZContentBlock.fromJson(
        <String, dynamic>{
          'type': 'legalReference',
          'data': <String, dynamic>{'title': 'Art. 5'},
        },
        typeRegistry: registry,
      );
      final ZCustomContentBlock custom = bloc! as ZCustomContentBlock;
      expect(custom.payload['decode_par_app'], isTrue,
          reason: 'le codec de l\'app n\'a pas été observé au DÉCODAGE');
      final Map<String, dynamic> encode =
          custom.toJson(typeRegistry: registry);
      expect(
        (encode['data'] as Map<String, dynamic>)['encode_par_app'],
        isTrue,
        reason: 'le codec de l\'app n\'a pas été observé à l\'ENCODAGE',
      );
    });

    test('SANS registre, le MÊME document retombe sur un payload INTACT', () {
      final ZContentBlock? bloc = ZContentBlock.fromJson(<String, dynamic>{
        'type': 'legalReference',
        'data': <String, dynamic>{'title': 'Art. 5'},
      });
      final ZCustomContentBlock custom = bloc! as ZCustomContentBlock;
      expect(custom.payload, <String, dynamic>{'title': 'Art. 5'});
      expect(custom.payload.containsKey('decode_par_app'), isFalse);
    });

    test('un codec d\'app qui LÈVE est ABSORBÉ (repli payload, AD-10)', () {
      final ZTypeRegistry registry = ZTypeRegistry()
        ..register(
          'boom',
          fromJson: (Map<String, dynamic> json) =>
              throw StateError('codec cassé'),
          toJson: (Object value) => throw StateError('codec cassé'),
        );
      late final ZContentBlock? bloc;
      expect(
        () => bloc = ZContentBlock.fromJson(
          <String, dynamic>{
            'type': 'boom',
            'data': <String, dynamic>{'k': 'v'},
          },
          typeRegistry: registry,
        ),
        returnsNormally,
      );
      final ZCustomContentBlock custom = bloc! as ZCustomContentBlock;
      expect(custom.payload, <String, dynamic>{'k': 'v'});
      expect(() => custom.toJson(typeRegistry: registry), returnsNormally);
      expect(custom.toJson(typeRegistry: registry)['data'],
          <String, dynamic>{'k': 'v'});
    });

    test('les blocs `sources` consultent le ZSourceRegistry injecté', () {
      final ZSourceRegistry sources = ZSourceRegistry()
        ..register(
          'monType',
          fromJson: (Map<String, dynamic> json) =>
              <String, dynamic>{'reconstruit': true},
          toJson: (Object value) => <String, dynamic>{'reencode': true},
        );
      final ZContentBlock? bloc = ZContentBlock.fromJson(
        <String, dynamic>{
          'type': 'sources',
          'data': <String, dynamic>{
            'sources': <dynamic>[
              <String, dynamic>{'source_type': 'monType', 'brut': 1},
            ],
          },
        },
        sourceRegistry: sources,
      );
      final ZSourcesBlock block = bloc! as ZSourcesBlock;
      expect(block.sources.single.payload['reconstruit'], isTrue);
    });
  });
}
