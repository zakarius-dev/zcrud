// Capacités de colonne dépendant de LA LIGNE : numéro d'ordre (1-based sur la
// séquence rendue, stable au tri), format monétaire à devise portée par la
// ligne (repli déclaré, jamais la devise d'une autre ligne), `formatWithRow`
// recevant la ligne entière, bornes de largeur min/max, et contre-témoin
// d'immobilité (sans déclaration, la dérivation est inchangée).
//
// Tests UNIT purs : aucun widget, aucun BuildContext.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'label', type: EditionFieldType.text),
  ZFieldSpec(name: 'amount', type: EditionFieldType.float),
  ZFieldSpec(name: 'currency', type: EditionFieldType.text),
];

ZListRow _row(String id, Map<String, Object?> cells) =>
    ZListRow(id: id, cells: cells);

void main() {
  group('Numéro d\'ordre — 1-based sur la séquence RENDUE', () {
    test('numérote 1..n la page rendue', () {
      final request = ZListRenderRequest.fromSchema(
        _schema,
        <ZListRow>[
          _row('a', const {'label': 'A'}),
          _row('b', const {'label': 'B'}),
          _row('c', const {'label': 'C'}),
        ],
        policy: const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true)),
      );

      expect(request.ordinalTextAt(0), '1');
      expect(request.ordinalTextAt(1), '2');
      expect(request.ordinalTextAt(2), '3');
    });

    test(
      'la numérotation suit L\'AFFICHAGE, pas l\'ordre d\'origine des lignes',
      () {
        final rows = <ZListRow>[
          _row('a', const {'label': 'A'}),
          _row('b', const {'label': 'B'}),
          _row('c', const {'label': 'C'}),
        ];
        final request = ZListRenderRequest.fromSchema(
          _schema,
          rows,
          policy: const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true)),
        );

        // Le backend a trié : l'ordre affiché est l'inverse de l'ordre reçu.
        final displayed = rows.reversed.toList();
        expect(
          displayed.map((r) => r.id).toList(),
          <String>['c', 'b', 'a'],
          reason: 'préalable du scénario : l\'affichage est bien réordonné',
        );

        // La ligne 'c', TROISIÈME dans les données, est affichée en premier :
        // elle porte donc le numéro 1. Une numérotation figée à la
        // construction des lignes rendrait ['3', '2', '1'].
        expect(
          request.ordinalTextsForDisplay(displayed),
          <String>['1', '2', '3'],
        );
      },
    );

    test('le numéro n\'est JAMAIS rangé dans les cellules de la ligne', () {
      final rows = <ZListRow>[
        _row('a', const {'label': 'A'}),
        _row('b', const {'label': 'B'}),
      ];
      final request = ZListRenderRequest.fromSchema(
        _schema,
        rows,
        policy: const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true)),
      );

      for (final row in request.rows) {
        expect(
          row.cells.containsKey(ZListOrdinal.columnName),
          isFalse,
          reason: 'un numéro rangé dans la donnée voyagerait avec sa ligne '
              'au tri',
        );
      }
      // La colonne d'ordre n'est pas non plus une colonne dérivée du schéma.
      expect(
        request.columns.map((c) => c.name),
        isNot(contains(ZListOrdinal.columnName)),
      );
    });

    test('pageOffset décale la numérotation (pagination continue)', () {
      const ordinal = ZListOrdinal(enabled: true, pageOffset: 20);
      expect(ordinal.textAt(0), '21');
      expect(ordinal.textsFor(3), <String>['21', '22', '23']);
    });

    test('désactivé par défaut : aucun numéro rendu', () {
      final request = ZListRenderRequest.fromSchema(
        _schema,
        <ZListRow>[_row('a', const {'label': 'A'})],
      );
      expect(request.ordinal.enabled, isFalse);
      expect(request.ordinalTextAt(0), isNull);
      expect(request.ordinalTextsForDisplay(request.rows), isEmpty);
    });
  });

  group('Devise par ligne — le repli déclaré, jamais celui d\'une autre', () {
    ZListColumn amountColumn({int? decimalDigits}) => deriveColumns(
          _schema,
          policy: ZColumnPolicy(
            overrides: {
              'amount': ZColumnOverride(
                currency: ZCurrencyFormat(
                  codeField: 'currency',
                  fallbackCode: 'XOF',
                  decimalDigits: decimalDigits,
                ),
              ),
            },
          ),
        ).firstWhere((c) => c.name == 'amount');

    test('chaque ligne affiche SA devise', () {
      final column = amountColumn();
      expect(
        column.formatRow(1500, const {'amount': 1500, 'currency': 'EUR'}),
        '1500 EUR',
      );
      expect(
        column.formatRow(1500, const {'amount': 1500, 'currency': 'USD'}),
        '1500 USD',
      );
    });

    test(
      'une ligne SANS code devise retombe sur le repli déclaré, même '
      'immédiatement après une ligne qui en portait un',
      () {
        final column = amountColumn();
        final rows = <Map<String, Object?>>[
          const {'amount': 10, 'currency': 'EUR'},
          const {'amount': 20}, // champ absent
          const {'amount': 30, 'currency': null}, // champ nul
          const {'amount': 40, 'currency': '   '}, // champ vide
          const {'amount': 50, 'currency': 'USD'},
          const {'amount': 60}, // absent, après une ligne en USD
        ];

        final rendered =
            rows.map((r) => column.formatRow(r['amount'], r)).toList();

        expect(rendered, <String>[
          '10 EUR',
          '20 XOF',
          '30 XOF',
          '40 XOF',
          '50 USD',
          '60 XOF',
        ]);

        // Assertion frontale du défaut silencieux : aucune ligne sans code ne
        // doit avoir hérité de la devise d'une voisine.
        expect(rendered[1], isNot(contains('EUR')));
        expect(rendered[5], isNot(contains('USD')));
      },
    );

    test('l\'ordre de rendu des lignes ne change rien au résultat', () {
      final column = amountColumn();
      const withCode = {'amount': 10, 'currency': 'EUR'};
      const withoutCode = {'amount': 20};

      final forward = <String>[
        column.formatRow(withCode['amount'], withCode),
        column.formatRow(withoutCode['amount'], withoutCode),
      ];
      final backward = <String>[
        column.formatRow(withoutCode['amount'], withoutCode),
        column.formatRow(withCode['amount'], withCode),
      ];

      expect(forward, <String>['10 EUR', '20 XOF']);
      expect(backward.reversed.toList(), forward);
    });

    test('codeField absent de la déclaration ⇒ devise fixe pour tout le monde',
        () {
      const format = ZCurrencyFormat(fallbackCode: 'XOF');
      expect(format.codeFor(const {'currency': 'EUR'}), 'XOF');
      expect(format.textFor(5, const {'currency': 'EUR'}), '5 XOF');
    });

    test('montant nul ⇒ cellule vide (pas un code devise esseulé)', () {
      final column = amountColumn();
      expect(column.formatRow(null, const {'currency': 'EUR'}), '');
    });

    test('decimalDigits impose les décimales ; placement en préfixe', () {
      expect(
        amountColumn(decimalDigits: 2)
            .formatRow(1500.5, const {'currency': 'EUR'}),
        '1500.50 EUR',
      );
      const prefixed = ZCurrencyFormat(
        fallbackCode: 'XOF',
        placement: ZCurrencyPlacement.prefix,
      );
      expect(prefixed.textFor(12, const {}), 'XOF 12');
    });

    test('montant non numérique rendu tel quel, avec sa devise', () {
      final column = amountColumn(decimalDigits: 2);
      expect(column.formatRow('n/a', const {'currency': 'EUR'}), 'n/a EUR');
    });
  });

  group('formatWithRow — la ligne entière', () {
    test('reçoit la valeur de la cellule ET toutes les autres', () {
      final columns = deriveColumns(
        _schema,
        policy: ZColumnPolicy(
          overrides: {
            'amount': ZColumnOverride(
              formatWithRow: (raw, row) => '$raw/${row['label']}/${row.length}',
            ),
          },
        ),
      );
      final column = columns.firstWhere((c) => c.name == 'amount');

      expect(
        column.formatRow(7, const {'label': 'A', 'amount': 7, 'currency': 'X'}),
        '7/A/3',
      );
    });

    test('prime sur le format monétaire et sur le format dérivé', () {
      final column = deriveColumns(
        _schema,
        policy: ZColumnPolicy(
          overrides: {
            'amount': ZColumnOverride(
              currency: const ZCurrencyFormat(fallbackCode: 'XOF'),
              formatWithRow: (raw, row) => 'brut:$raw',
            ),
          },
        ),
      ).firstWhere((c) => c.name == 'amount');

      expect(column.formatRow(3, const {}), 'brut:3');
    });

    test('non déclaré ⇒ formatRow rend exactement ce que rend format', () {
      final column =
          deriveColumns(_schema).firstWhere((c) => c.name == 'amount');
      for (final raw in <Object?>[null, 12, 'texte']) {
        expect(column.formatRow(raw, const {'currency': 'EUR'}),
            column.format(raw));
      }
    });
  });

  group('Égalité de valeur — les fonctions n\'y entrent pas', () {
    test(
      'deux colonnes identiques restent ÉGALES avec deux formatWithRow '
      'différents',
      () {
        final a = deriveColumns(
          _schema,
          policy: ZColumnPolicy(
            overrides: {
              'amount': ZColumnOverride(formatWithRow: (raw, row) => 'A$raw'),
            },
          ),
        );
        final b = deriveColumns(
          _schema,
          policy: ZColumnPolicy(
            overrides: {
              'amount': ZColumnOverride(formatWithRow: (raw, row) => 'B$raw'),
            },
          ),
        );

        final columnA = a.firstWhere((c) => c.name == 'amount');
        final columnB = b.firstWhere((c) => c.name == 'amount');

        // Les deux closures sont bien distinctes (préalable du scénario).
        expect(columnA.formatRow(1, const {}), 'A1');
        expect(columnB.formatRow(1, const {}), 'B1');
        expect(columnA.formatWithRow, isNot(same(columnB.formatWithRow)));

        expect(columnA, equals(columnB));
        expect(columnA.hashCode, columnB.hashCode);

        // Et jusqu'à la requête de rendu, dont dépend la mémoïsation.
        final rows = <ZListRow>[_row('a', const {'amount': 1})];
        expect(
          ZListRenderRequest(columns: a, rows: rows),
          equals(ZListRenderRequest(columns: b, rows: rows)),
        );
      },
    );

    test('une devise DIFFÉRENTE rend les colonnes inégales', () {
      final a = deriveColumns(
        _schema,
        policy: const ZColumnPolicy(
          overrides: {
            'amount': ZColumnOverride(
              currency: ZCurrencyFormat(fallbackCode: 'XOF'),
            ),
          },
        ),
      ).firstWhere((c) => c.name == 'amount');
      final b = deriveColumns(
        _schema,
        policy: const ZColumnPolicy(
          overrides: {
            'amount': ZColumnOverride(
              currency: ZCurrencyFormat(fallbackCode: 'EUR'),
            ),
          },
        ),
      ).firstWhere((c) => c.name == 'amount');

      expect(a, isNot(equals(b)));
    });

    test('la déclaration de numéro d\'ordre entre dans l\'égalité', () {
      final rows = <ZListRow>[_row('a', const {})];
      expect(
        const ZListRenderRequest(columns: [], rows: []),
        equals(const ZListRenderRequest(columns: [], rows: [])),
      );
      expect(
        ZListRenderRequest(columns: const [], rows: rows),
        isNot(
          equals(
            ZListRenderRequest(
              columns: const [],
              rows: rows,
              ordinal: const ZListOrdinal(enabled: true),
            ),
          ),
        ),
      );
    });
  });

  group('Bornes de largeur min/max', () {
    test('sont portées par la colonne dérivée', () {
      final column = deriveColumns(
        _schema,
        policy: const ZColumnPolicy(
          overrides: {
            'label': ZColumnOverride(width: 200, minWidth: 120, maxWidth: 320),
          },
        ),
      ).firstWhere((c) => c.name == 'label');

      expect(column.width, 200);
      expect(column.minWidth, 120);
      expect(column.maxWidth, 320);
    });

    test('entrent dans l\'égalité de valeur', () {
      const base = ZListColumn(
        name: 'a',
        header: 'a',
        type: EditionFieldType.text,
        order: 0,
        format: _identityFormat,
      );
      const narrow = ZListColumn(
        name: 'a',
        header: 'a',
        type: EditionFieldType.text,
        order: 0,
        format: _identityFormat,
        minWidth: 80,
      );
      expect(base, isNot(equals(narrow)));
    });
  });

  group('Contre-témoin — hôte passif strictement immobile', () {
    test(
      'sans overrides ni ordinal, la dérivation est identique à l\'existant',
      () {
        final plain = deriveColumns(_schema);
        final withEmptyPolicy = deriveColumns(
          _schema,
          policy: const ZColumnPolicy(),
        );

        expect(withEmptyPolicy, equals(plain));
        for (final column in plain) {
          expect(column.minWidth, isNull);
          expect(column.maxWidth, isNull);
          expect(column.currency, isNull);
          expect(column.formatWithRow, isNull);
        }

        final rows = <ZListRow>[
          _row('a', const {'label': 'A', 'amount': 1, 'currency': 'EUR'}),
        ];
        final request = ZListRenderRequest.fromSchema(_schema, rows);
        expect(request.columns, equals(plain));
        expect(request.ordinal, const ZListOrdinal());
        for (final column in request.columns) {
          expect(
            column.formatRow(rows.first.cells[column.name], rows.first.cells),
            column.format(rows.first.cells[column.name]),
          );
        }
      },
    );

    test('un override visant une colonne absente est sans effet', () {
      final plain = deriveColumns(_schema);
      final withGhost = deriveColumns(
        _schema,
        policy: const ZColumnPolicy(
          overrides: {'inexistant': ZColumnOverride(minWidth: 999)},
        ),
      );
      expect(withGhost, equals(plain));
    });
  });
}

String _identityFormat(Object? raw) => raw?.toString() ?? '';
