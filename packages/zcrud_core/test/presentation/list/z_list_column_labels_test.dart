// CR-LIST-LABELS — la règle d'orphelin de v0.65.0 et le port de dates de
// v0.69.0 atteignent enfin `DynamicList`.
//
// Le défaut fermé ici : `ZListColumn.format` portait sa PROPRE résolution de
// libellé de choix (4ᵉ copie du motif dans ce paquet) et rendait
// `raw.toString()` sur une valeur ORPHELINE — l'identifiant technique s'affichait
// à l'utilisateur, dans une liste, l'endroit le plus vu de l'application.
//
// 🔴 Identifiants NON CONFONDABLES avec leurs libellés (`zz9` ↔ « Arrivée du
// personnel »), pour qu'une projection restée brute ne puisse pas passer pour un
// libellé résolu — piège mesuré (`arrivee` ↔ « Arrivée »).
//
// La closure `format` n'a **aucun `BuildContext`** (le backend l'appelle depuis
// une `DataGridSource`, `zcrud_export` sans arbre) : les gardes vérifient donc
// que les seams sont **capturés** par `DynamicList` au moment de la dérivation,
// et que sans seams le rendu est **exactement** celui d'avant.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellé `en` de repli de la clé d'orphelin (table intégrée, aucun delegate
/// monté dans ces tests). Jamais la clé `choiceUnresolved` elle-même.
const String _orphanEn = 'Option unavailable';

const _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'zz9', label: 'Arrivée du personnel'),
  ZFieldChoice(value: 'w3x', label: 'Mobilité interne'),
];

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'motif', type: EditionFieldType.select, choices: _choices),
  ZFieldSpec(name: 'quand', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'heure', type: EditionFieldType.time),
  ZFieldSpec(name: 'actif', type: EditionFieldType.boolean),
  ZFieldSpec(name: 'poids', type: EditionFieldType.number),
  ZFieldSpec(name: 'nom', type: EditionFieldType.text),
];

ZListRow _row(Map<String, Object?> cells) =>
    ZListRow(id: 'r1', cells: <String, Object?>{...cells});

/// Monte un `DynamicList` en variante `builder` et **capture les colonnes que le
/// widget a réellement dérivées** (avec ses seams), puis rend chaque cellule.
///
/// Le sujet est donc bien MONTÉ : les seams lus le sont depuis le vrai arbre.
Future<Map<String, String>> _cells(
  WidgetTester tester,
  Map<String, Object?> values, {
  ZcrudLabels? labels,
  ZDateDisplayFormatter? dateFormatter,
  Locale? locale,
}) async {
  final out = <String, String>{};
  Widget list = DynamicList(
    fields: _fields,
    state: ZListReady(<ZListRow>[_row(values)]),
    layout: ZListBuilderLayout(
      itemBuilder: (context, row, columns) {
        for (final c in columns) {
          out[c.name] = c.format(row.cells[c.name]);
        }
        return const SizedBox.shrink();
      },
    ),
  );
  if (locale != null) {
    // Locale ambiante posée LOCALEMENT (et non sur `MaterialApp`, dont les
    // delegates par défaut ne couvrent pas `fr` sans `flutter_localizations`).
    list = Localizations(
      locale: locale,
      delegates: const <LocalizationsDelegate<Object>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: list,
    );
  }
  if (labels != null || dateFormatter != null) {
    list = ZcrudScope(
      labels: labels,
      dateDisplayFormatter: dateFormatter,
      child: list,
    );
  }
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: list)),
  );
  return out;
}

/// Clé l10n déclarée par le module d'orphelin — **lue dans la source**, pas
/// recopiée : si `DynamicList` se dotait d'une SECONDE clé pour la même idée,
/// la surcharge de celle-ci ne déplacerait plus la cellule et G5 rougirait.
///
/// 🔴 Les commentaires sont RETIRÉS avant analyse : le dartdoc du module cite la
/// clé plusieurs fois, un motif naïf y serait dévié.
String _declaredOrphanKey() {
  for (final base in <String>['', 'packages/zcrud_core/']) {
    final f = File('${base}lib/src/presentation/edition/z_orphan_choice.dart');
    if (!f.existsSync()) continue;
    final code = f
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i < 0 ? l : l.substring(0, i);
        })
        .join('\n');
    final m = RegExp(r"zOrphanChoiceLabelKey\s*=\s*'([^']+)'").firstMatch(code);
    if (m != null) return m.group(1)!;
    fail('Déclaration de zOrphanChoiceLabelKey introuvable dans la source.');
  }
  fail('z_orphan_choice.dart introuvable depuis ${Directory.current.path}');
}

/// Port de dates de test : rend un marqueur reconnaissable + le mode + la locale
/// reçue (aucune dépendance `intl` — AD-1).
class _MarkerDateFormatter extends ZDateDisplayFormatter {
  const _MarkerDateFormatter();
  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      'D<${value.year}|${mode.name}|$localeTag>';
}

/// Port qui LÈVE (AD-10 : jamais d'exception dans un `build`).
class _ThrowingDateFormatter extends ZDateDisplayFormatter {
  const _ThrowingDateFormatter();
  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      throw StateError('boom');
}

/// Port qui s'abstient (`null`) ⇒ repli du socle.
class _AbstainingDateFormatter extends ZDateDisplayFormatter {
  const _AbstainingDateFormatter();
  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      null;
}

void main() {
  group('CR-LIST-LABELS — valeur orpheline en colonne de liste', () {
    testWidgets('G1 — orpheline ⇒ libellé l10n, JAMAIS la clé technique',
        (tester) async {
      final cells = await _cells(tester, {'motif': 'qk7'});
      expect(cells['motif'], equals(_orphanEn));
      // La valeur brute ne doit apparaître NULLE PART dans la cellule.
      expect(cells['motif'], isNot(contains('qk7')));
      // Ni la clé l10n elle-même (défaut symétrique : « la clé à l'écran »).
      expect(cells['motif'], isNot(contains('choiceUnresolved')));
    });

    testWidgets('G2 — valeur résolvable ⇒ son libellé (inchangé)',
        (tester) async {
      final cells = await _cells(tester, {'motif': 'zz9'});
      expect(cells['motif'], equals('Arrivée du personnel'));
    });

    testWidgets('G3 — multi : chaque élément traité, orphelin compris',
        (tester) async {
      final cells = await _cells(tester, {
        'motif': <String>['w3x', 'qk7'],
      });
      expect(cells['motif'], equals('Mobilité interne, $_orphanEn'));
      expect(cells['motif'], isNot(contains('qk7')));
    });

    testWidgets('G4 — le libellé est SURCHARGEABLE par l\'hôte (FR-26)',
        (tester) async {
      final cells = await _cells(
        tester,
        {'motif': 'qk7'},
        labels: ZcrudLabels(const <String, String>{
          'choiceUnresolved': 'Plus proposé',
        }),
      );
      expect(cells['motif'], equals('Plus proposé'));
    });

    testWidgets('G5 — MÊME clé l10n que les dix voies de v0.65.0',
        (tester) async {
      // La clé est LUE DANS LA SOURCE du module d'orphelin : si `DynamicList`
      // se dotait d'une seconde clé pour la même idée, la surcharge de celle-ci
      // ne déplacerait plus la cellule.
      expect(_declaredOrphanKey(), equals('choiceUnresolved'));
      final cells = await _cells(
        tester,
        {'motif': 'qk7'},
        labels: ZcrudLabels(<String, String>{_declaredOrphanKey(): 'Retiré'}),
      );
      expect(cells['motif'], equals('Retiré'));
    });

    test('G6 — headless (aucun seam) : repli DOCUMENTÉ = la valeur brute', () {
      // `zcrud_export` dérive sans arbre de widgets : aucune l10n n'y est
      // atteignable, et coder un texte en dur violerait FR-26.
      final col = deriveColumns(_fields).firstWhere((c) => c.name == 'motif');
      expect(col.format('qk7'), equals('qk7'));
      // …mais l'hôte headless peut fournir le libellé lui-même.
      final withSeam = deriveColumns(
        _fields,
        formatting: const ZListFormat(orphanChoiceLabel: 'Indisponible'),
      ).firstWhere((c) => c.name == 'motif');
      expect(withSeam.format('qk7'), equals('Indisponible'));
    });
  });

  group('CR-LIST-LABELS — hôte passif IMMOBILE hors du cas orphelin', () {
    testWidgets('G7 — boolean / number / text / vide : rendu inchangé',
        (tester) async {
      final cells = await _cells(tester, {
        'actif': true,
        'poids': 42,
        'nom': 'Alice',
        'motif': null,
      });
      expect(cells['actif'], equals('true')); // PAS « Oui »
      expect(cells['poids'], equals('42')); // PAS « 42 % »
      expect(cells['nom'], equals('Alice'));
      expect(cells['motif'], equals('')); // PAS le placeholder « — »
    });

    testWidgets('G8 — date SANS port : ISO strict (String et DateTime)',
        (tester) async {
      final dt = DateTime.utc(2026, 7, 10, 8, 30);
      final cells = await _cells(tester, {
        'quand': dt,
        'heure': '08:30',
      });
      expect(cells['quand'], equals(dt.toIso8601String()));
      expect(cells['heure'], equals('08:30'));
    });
  });

  group('CR-LIST-LABELS — port de dates atteint DynamicList', () {
    testWidgets('G9 — port injecté ⇒ la cellule est formatée par le port',
        (tester) async {
      final cells = await _cells(
        tester,
        {'quand': '2026-07-10T08:30:00.000Z'},
        dateFormatter: const _MarkerDateFormatter(),
        locale: const Locale('fr', 'FR'),
      );
      // Le mode ET la locale ambiante ont bien traversé la closure sans contexte.
      expect(cells['quand'], equals('D<2026|dateTime|fr-FR>'));
    });

    testWidgets('G10 — un DateTime BRUT est normalisé en ISO avant le port',
        (tester) async {
      // Repli si le port s'abstient : l'ISO, jamais `DateTime.toString()`
      // (`2026-07-10 08:30:00.000Z`), qui déplacerait l'hôte.
      final dt = DateTime.utc(2026, 7, 10, 8, 30);
      final cells = await _cells(
        tester,
        {'quand': dt},
        dateFormatter: const _AbstainingDateFormatter(),
      );
      expect(cells['quand'], equals(dt.toIso8601String()));
      expect(cells['quand'], isNot(contains('2026-07-10 ')));
    });

    testWidgets('G11 — port qui LÈVE ⇒ repli brut, aucune exception (AD-10)',
        (tester) async {
      final cells = await _cells(
        tester,
        {'quand': '2026-07-10T08:30:00.000Z'},
        dateFormatter: const _ThrowingDateFormatter(),
      );
      expect(cells['quand'], equals('2026-07-10T08:30:00.000Z'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('G12 — mode `time` n\'est JAMAIS routé vers le port',
        (tester) async {
      // Valeur ISO PARSABLE dans un champ `time` : seul le court-circuit de mode
      // peut l'exclure du port (une valeur `HH:mm` serait exclue par le parse,
      // ce qui rendrait la garde VACANTE — piège mesuré en v0.69.0).
      final cells = await _cells(
        tester,
        {'heure': '2026-07-10T08:30:00.000Z'},
        dateFormatter: const _MarkerDateFormatter(),
      );
      expect(cells['heure'], equals('2026-07-10T08:30:00.000Z'));
    });
  });

  group('CR-LIST-LABELS — les seams participent à l\'égalité', () {
    test('G13 — seams différents ⇒ colonnes INÉGALES', () {
      // Sinon `zcrud_list` (`widget.request != old.request`) ne reconstruirait
      // pas ses cellules : la grille garderait ses anciennes chaînes après un
      // changement de locale ou d'injection.
      final a = deriveColumns(_fields);
      final b = deriveColumns(
        _fields,
        formatting: const ZListFormat(orphanChoiceLabel: 'X'),
      );
      expect(a, isNot(equals(b)));

      final c = deriveColumns(
        _fields,
        formatting: const ZListFormat(orphanChoiceLabel: 'X', localeTag: 'fr'),
      );
      expect(b, isNot(equals(c)));
    });

    test('G14 — seams IDENTIQUES ⇒ colonnes égales (aucun rebuild parasite)',
        () {
      const f = ZListFormat(
        orphanChoiceLabel: 'X',
        dateFormatter: _MarkerDateFormatter(),
        localeTag: 'fr',
      );
      expect(
        deriveColumns(_fields, formatting: f),
        equals(deriveColumns(_fields, formatting: f)),
      );
    });

    testWidgets('G15 — DynamicList RENSEIGNE réellement les seams',
        (tester) async {
      ZListFormat? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            dateDisplayFormatter: const _MarkerDateFormatter(),
            child: DynamicList(
              fields: _fields,
              state: ZListReady(<ZListRow>[_row(const {})]),
              layout: ZListBuilderLayout(
                itemBuilder: (context, row, columns) {
                  seen = columns.first.formatting;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.orphanChoiceLabel, equals(_orphanEn));
      expect(seen!.dateFormatter, isA<_MarkerDateFormatter>());
    });
  });
}
