// CR-DODLP « Gap 3bis » — la projection de résumé du mode COMPACT affichait la
// VALEUR BRUTE mise en chaîne (`'$value'`) : un `select` montrait son
// identifiant, un `dateTime` son ISO.
//
// Ces gardes asservissent :
//  - G1 : `select` à choix STATIQUES → le LIBELLÉ, jamais la clé ;
//  - G2 : valeur ORPHELINE → le libellé l10n `choiceUnresolved` (le même que
//    les dix voies de v0.65.0), ni disparition, ni clé brute ;
//  - G3 : `select` à choix DYNAMIQUES (`ZChoicesSource`, synchrone) → le
//    libellé calculé par la source, résolue sur le contrôleur DE L'ITEM ;
//  - G4 : date SANS port injecté → chaîne BRUTE (hôte passif immobile) ;
//  - G5 : date AVEC port injecté → sortie du port ;
//  - G6 : port qui LÈVE → repli brut (AD-10, jamais d'exception dans un build) ;
//  - G7 : mode `time` → jamais routé vers le port (valeur `HH:mm` conservée) ;
//  - G8 : famille NON nommée par la CR (`boolean`) → rendu brut inchangé ;
//  - G9 : en-têtes de colonnes ABSENTS par défaut (opt-in) ;
//  - G10 : `showSummaryHeaders: true` → libellé l10n de chaque colonne, annoncé
//    `header: true`.
//
// 🔴 Les identifiants techniques sont volontairement NON CONFONDABLES avec
// leurs libellés (`zz9` ↔ « Arrivée du personnel ») : une garde de libellé
// écrite avec `arrivee` ↔ `Arrivée` serait VACANTE (elle passerait aussi avec
// la projection brute).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Constantes de discrimination ──────────────────────────────────────────────
const _keyStatic = 'zz9';
const _labelStatic = 'Arrivée du personnel';
const _keyOrphan = 'qk7';
const _keyDynamic = 'w3x';
const _labelDynamic = 'Mobilité interne';
const _orphanLabelEn = 'Option unavailable';
const _isoValue = '2026-08-09T00:00:00.000';
const _formattedDate = 'Dim. 9 août 2026';

/// Source de choix SYNCHRONE (port `ZChoicesSource`) — impl de test.
class _FakeChoicesSource extends ZChoicesSource {
  const _FakeChoicesSource();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) =>
      const <ZFieldChoice>[
        ZFieldChoice(value: _keyDynamic, label: _labelDynamic),
      ];
}

/// Formateur de dates de test : rend une chaîne RECONNAISSABLE, et **compte**
/// ses appels (pour prouver que `time` ne le traverse pas).
class _FakeDateFormatter extends ZDateDisplayFormatter {
  _FakeDateFormatter();

  final calls = <ZDateMode>[];

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) {
    calls.add(mode);
    return _formattedDate;
  }
}

/// Formateur qui LÈVE (AD-10 : le socle doit replier, jamais propager).
class _ThrowingDateFormatter extends ZDateDisplayFormatter {
  const _ThrowingDateFormatter();

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      throw StateError('boom');
}

ZFieldSpec _field(
  List<ZFieldSpec> itemFields,
  List<String> summary, {
  bool headers = false,
}) =>
    ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: itemFields,
        displayMode: ZSubListDisplayMode.compact,
        summaryFields: summary,
        showSummaryHeaders: headers,
      ),
    );

Widget _host(
  Widget child, {
  ZChoicesSourceRegistry? choices,
  ZDateDisplayFormatter? dateFormatter,
}) =>
    ZcrudScope(
      choicesSourceRegistry: choices,
      dateDisplayFormatter: dateFormatter,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Widget _subList(
  ZFieldSpec field,
  List<Map<String, dynamic>> items,
) =>
    ZSubListFieldWidget(
      field: field,
      initialValue: items,
      onChanged: (_) {},
    );

void main() {
  // ── G1 : choix statiques → libellé ────────────────────────────────────────
  testWidgets('G1 — select statique : le résumé rend le LIBELLÉ, pas la clé',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'motif',
        type: EditionFieldType.select,
        label: 'Motif',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: _keyStatic, label: _labelStatic),
        ],
      ),
    ];
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['motif']),
      <Map<String, dynamic>>[
        <String, dynamic>{'motif': _keyStatic},
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text(_labelStatic), findsOneWidget);
    expect(find.text(_keyStatic), findsNothing);
  });

  // ── G2 : valeur orpheline → libellé l10n partagé, jamais la clé ───────────
  testWidgets(
      'G2 — valeur orpheline : libellé `choiceUnresolved` (ni clé, ni vide)',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'motif',
        type: EditionFieldType.select,
        label: 'Motif',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: _keyStatic, label: _labelStatic),
        ],
      ),
    ];
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['motif']),
      <Map<String, dynamic>>[
        <String, dynamic>{'motif': _keyOrphan},
      ],
    )));
    await tester.pumpAndSettle();

    // Le MÊME libellé et le MÊME canal que les dix voies de v0.65.0.
    expect(find.text(_orphanLabelEn), findsOneWidget);
    // Ni la clé technique…
    expect(find.text(_keyOrphan), findsNothing);
    // …ni une disparition silencieuse (la cellule n'est pas vide).
    expect(find.text(''), findsNothing);
  });

  // ── G3 : choix dynamiques (source synchrone) ──────────────────────────────
  testWidgets('G3 — select dynamique (`ZChoicesSource`) : libellé de la source',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'motif',
        type: EditionFieldType.select,
        label: 'Motif',
        // Aucun choix STATIQUE : sans résolution dynamique, la valeur serait
        // orpheline — la garde distingue donc les trois issues possibles
        // (clé brute / orphelin / libellé de la source).
        config: ZSelectConfig(choicesSourceKey: 'motifs'),
      ),
    ];
    final registry = ZChoicesSourceRegistry()
      ..register('motifs', const _FakeChoicesSource());

    await tester.pumpWidget(_host(
      _subList(
        _field(fields, const <String>['motif']),
        <Map<String, dynamic>>[
          <String, dynamic>{'motif': _keyDynamic},
        ],
      ),
      choices: registry,
    ));
    await tester.pumpAndSettle();

    expect(find.text(_labelDynamic), findsOneWidget);
    expect(find.text(_keyDynamic), findsNothing);
    expect(find.text(_orphanLabelEn), findsNothing);
  });

  // ── G4 : hôte PASSIF immobile ─────────────────────────────────────────────
  testWidgets('G4 — date SANS port : la chaîne BRUTE, à l\'identique',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'd', type: EditionFieldType.dateTime, label: 'Date'),
    ];
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['d']),
      <Map<String, dynamic>>[
        <String, dynamic>{'d': _isoValue},
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text(_isoValue), findsOneWidget);
    expect(find.text(_formattedDate), findsNothing);
  });

  // ── G5 : port injecté → formatage ─────────────────────────────────────────
  testWidgets('G5 — date AVEC port : la sortie du port, mode `dateTime`',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'd', type: EditionFieldType.dateTime, label: 'Date'),
    ];
    final formatter = _FakeDateFormatter();
    await tester.pumpWidget(_host(
      _subList(
        _field(fields, const <String>['d']),
        <Map<String, dynamic>>[
          <String, dynamic>{'d': _isoValue},
        ],
      ),
      dateFormatter: formatter,
    ));
    await tester.pumpAndSettle();

    expect(find.text(_formattedDate), findsOneWidget);
    expect(find.text(_isoValue), findsNothing);
    expect(formatter.calls, contains(ZDateMode.dateTime));
  });

  // ── G6 : port en erreur → repli DÉFINI ────────────────────────────────────
  testWidgets('G6 — port qui LÈVE : repli sur la chaîne brute (AD-10)',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'd', type: EditionFieldType.dateTime, label: 'Date'),
    ];
    await tester.pumpWidget(_host(
      _subList(
        _field(fields, const <String>['d']),
        <Map<String, dynamic>>[
          <String, dynamic>{'d': _isoValue},
        ],
      ),
      dateFormatter: const _ThrowingDateFormatter(),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_isoValue), findsOneWidget);
  });

  // ── G7 : `time` hors périmètre du port ────────────────────────────────────
  testWidgets('G7 — `time` (`HH:mm`) : le port n\'est jamais appelé',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 't', type: EditionFieldType.time, label: 'Heure'),
    ];
    final formatter = _FakeDateFormatter();
    await tester.pumpWidget(_host(
      _subList(
        _field(fields, const <String>['t']),
        <Map<String, dynamic>>[
          <String, dynamic>{'t': '08:30'},
        ],
      ),
      dateFormatter: formatter,
    ));
    await tester.pumpAndSettle();

    expect(find.text('08:30'), findsOneWidget);
    expect(formatter.calls, isEmpty);
  });

  testWidgets(
      'G7b — `time` portant une valeur ISO : le mode `time` l\'exclut du port',
      (tester) async {
    // 🔴 Sans cette variante, G7 serait VACANTE : `DateTime.tryParse("08:30")`
    // rend déjà `null`, donc le port ne serait pas appelé MÊME si le
    // court-circuit sur `ZDateMode.time` disparaissait. Ici la valeur EST
    // parsable — seul le court-circuit de mode empêche le formatage.
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 't', type: EditionFieldType.time, label: 'Heure'),
    ];
    final formatter = _FakeDateFormatter();
    await tester.pumpWidget(_host(
      _subList(
        _field(fields, const <String>['t']),
        <Map<String, dynamic>>[
          <String, dynamic>{'t': _isoValue},
        ],
      ),
      dateFormatter: formatter,
    ));
    await tester.pumpAndSettle();

    expect(find.text(_isoValue), findsOneWidget);
    expect(formatter.calls, isEmpty);
  });

  // ── G8 : familles NON projetées, rendu inchangé ───────────────────────────
  testWidgets('G8 — `boolean` : rendu BRUT inchangé (hors périmètre CR)',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'b', type: EditionFieldType.boolean, label: 'B'),
    ];
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['b']),
      <Map<String, dynamic>>[
        <String, dynamic>{'b': true},
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('true'), findsOneWidget);
    // Le rendu « Oui »/« Non » de la fiche de LECTURE n'a PAS été importé ici :
    // il aurait déplacé un hôte passif que la CR ne vise pas.
    expect(find.text('Yes'), findsNothing);
  });

  // ── G9/G10 : en-têtes de colonnes, opt-in ─────────────────────────────────
  testWidgets('G9 — en-têtes ABSENTS par défaut (hôte passif immobile)',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'motif', type: EditionFieldType.text, label: 'Motif'),
    ];
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['motif']),
      <Map<String, dynamic>>[
        <String, dynamic>{'motif': 'x'},
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Motif'), findsNothing);
  });

  testWidgets('G10 — `showSummaryHeaders: true` → libellé l10n + `header`',
      (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'motif', type: EditionFieldType.text, label: 'Motif'),
    ];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_subList(
      _field(fields, const <String>['motif'], headers: true),
      <Map<String, dynamic>>[
        <String, dynamic>{'motif': 'x'},
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Motif'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Motif')),
      matchesSemantics(label: 'Motif', isHeader: true),
    );
    handle.dispose();
  });
}
