// CR-DODLP-DATE-DISPLAY — le champ date en **SAISIE** affichait l'ISO brut alors
// que le port `ZDateDisplayFormatter` (v0.69.0) était déjà consommé par la fiche
// de lecture, le résumé de sous-liste et la liste (v0.70.0). Le MÊME champ
// rendait donc une date lisible en liste et `2026-08-09T00:00:00.000` dans le
// formulaire.
//
// Ces gardes asservissent les TROIS modes servis par la famille date
// (`dateTime`, `date`, `time`) **et** la famille sœur `dateRange` :
//
//  - D1  : `dateTime` AVEC port → sortie du port, l'ISO n'apparaît plus ;
//  - D2  : `dateTime` SANS port → **exactement** l'ISO d'avant (hôte passif) ;
//  - D3  : mode `date` explicite (`ZDateConfig.mode`) → routé, et le port reçoit
//          bien `ZDateMode.date` (pas `dateTime`) ;
//  - D4  : `time` → **jamais** routé vers le port (aucun appel), `HH:mm` conservé
//          (⚠️ NON discriminante seule — cf. son commentaire in situ) ;
//  - D4bis: `time` exclu du port MÊME avec une valeur parsable (discriminante) ;
//  - D5  : port rendant `null` → repli ISO (AD-10) ;
//  - D6  : port qui LÈVE → repli ISO, aucune exception dans le `build` (AD-10) ;
//  - D7  : valeur NON parsable en date → repli brut ;
//  - D8  : la locale ambiante atteint le port (BCP-47 non nul) ;
//  - D9  : le nœud `Semantics` du déclencheur annonce la valeur PROJETÉE ;
//  - D10 : l'échappatoire `decorated: false` (`OutlinedButton`) projette aussi ;
//  - D11 : la voie de DISPATCH réelle (`DynamicEdition` → `ZFieldWidget`) porte
//          la projection — la garde ne vaut pas que sur un montage direct ;
//  - D12 : `dateRange` AVEC port → LES DEUX bornes projetées (mode `date`) ;
//  - D13 : `dateRange` SANS port → **exactement** `YYYY-MM-DD → YYYY-MM-DD` ;
//  - D14 : `dateRange` port en échec → repli ISO sur les deux bornes.
//
// 🔴 Discrimination : la chaîne rendue par le faux port ne partage AUCUN
// fragment avec l'ISO (« Neuvieme jour, quinzaine chaude » n'a ni chiffre ni
// séparateur commun avec `2026-08-09T14:35:00.000`). Une garde écrite avec un
// formateur qui renverrait « 2026-08-09 » serait VACANTE : elle passerait aussi
// sans projection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Constantes de discrimination ─────────────────────────────────────────────
const _iso = '2026-08-09T14:35:00.000';
const _formatted = 'Neuvieme jour, quinzaine chaude';
const _rangeStartIso = '2026-01-01';
const _rangeEndIso = '2026-01-31';
const _formattedStart = 'Premier matin';
const _formattedEnd = 'Dernier soir';

/// Faux port : rend une chaîne RECONNAISSABLE et **enregistre** chaque appel
/// (mode + locale) — c'est ce journal qui empêche les gardes d'être vacantes.
class _RecordingFormatter extends ZDateDisplayFormatter {
  _RecordingFormatter();

  static const output = _formatted;
  final calls = <({ZDateMode mode, String? localeTag, DateTime value})>[];

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) {
    calls.add((mode: mode, localeTag: localeTag, value: value));
    return output;
  }
}

/// Port qui rend `null` — « je ne sais pas rendre ce mode » (AD-10).
class _NullFormatter extends ZDateDisplayFormatter {
  const _NullFormatter();

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      null;
}

/// Port qui LÈVE — le socle doit replier, jamais propager (AD-10).
class _ThrowingFormatter extends ZDateDisplayFormatter {
  const _ThrowingFormatter();

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) =>
      throw StateError('boom');
}

/// Port qui distingue les DEUX bornes d'une plage (garde D12 : une seule borne
/// projetée serait un demi-correctif).
class _BoundFormatter extends ZDateDisplayFormatter {
  _BoundFormatter();

  final modes = <ZDateMode>[];

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) {
    modes.add(mode);
    return value.month == 1 && value.day == 1 ? _formattedStart : _formattedEnd;
  }
}

Widget _host(Widget child, {ZDateDisplayFormatter? formatter}) => ZcrudScope(
      dateDisplayFormatter: formatter,
      child: MaterialApp(home: Scaffold(body: child)),
    );

ZFieldSpec _dateField({
  EditionFieldType type = EditionFieldType.dateTime,
  ZDateMode? mode,
}) =>
    ZFieldSpec(
      name: 'd',
      type: type,
      label: 'Date',
      config: mode == null ? null : ZDateConfig(mode: mode),
    );

Widget _dateWidget(
  Object? value, {
  EditionFieldType type = EditionFieldType.dateTime,
  ZDateMode? mode,
  bool? decorated,
}) =>
    ZDateFieldWidget(
      field: _dateField(type: type, mode: mode),
      value: value,
      onChanged: (_) {},
      decorated: decorated,
    );

final _range = ZDateRange(
  start: DateTime.parse('${_rangeStartIso}T00:00:00.000'),
  end: DateTime.parse('${_rangeEndIso}T00:00:00.000'),
);

Widget _rangeWidget() => ZDateRangeFieldWidget(
      field: const ZFieldSpec(
        name: 'p',
        type: EditionFieldType.dateRange,
        label: 'Période',
      ),
      value: _range,
      onChanged: (_) {},
    );

void main() {
  group('CR-DODLP-DATE-DISPLAY — famille date en SAISIE', () {
    testWidgets('D1 — `dateTime` avec port : sortie du port, ISO absent',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(_host(_dateWidget(_iso), formatter: port));

      expect(find.text(_formatted), findsOneWidget);
      expect(find.textContaining(_iso), findsNothing);
      expect(port.calls.single.mode, ZDateMode.dateTime);
    });

    testWidgets('D2 — `dateTime` SANS port : exactement l\'ISO (hôte passif)',
        (tester) async {
      await tester.pumpWidget(_host(_dateWidget(_iso)));

      expect(find.text(_iso), findsOneWidget);
      expect(find.text(_formatted), findsNothing);
    });

    testWidgets('D3 — mode `date` explicite : routé, et le port reçoit `date`',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(
        _host(_dateWidget(_iso, mode: ZDateMode.date), formatter: port),
      );

      expect(find.text(_formatted), findsOneWidget);
      expect(port.calls.single.mode, ZDateMode.date);
    });

    testWidgets('D4 — `time` : JAMAIS routé vers le port, `HH:mm` conservé',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(
        _host(
          _dateWidget('08:30', type: EditionFieldType.time),
          formatter: port,
        ),
      );

      expect(find.text('08:30'), findsOneWidget);
      expect(find.text(_formatted), findsNothing);
      expect(port.calls, isEmpty);
    });

    // 🔴 D4 seule était NON discriminante, et c'est MESURÉ : sous une injection
    // forçant le mode à `dateTime`, D4 restait VERTE — non pas parce que `time`
    // est exclu du port, mais parce que `08:30` n'est pas parsable en `DateTime`
    // (le repli de `zDateDisplayTextOf` mordait à sa place). D4bis porte donc le
    // cas où la valeur EST parsable : seule l'exclusion du mode `time` peut
    // alors empêcher l'appel du port.
    testWidgets('D4bis — `time` : exclu du port MÊME si la valeur est parsable',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(
        _host(
          _dateWidget(_iso, type: EditionFieldType.time),
          formatter: port,
        ),
      );

      expect(port.calls, isEmpty);
      expect(find.text(_iso), findsOneWidget);
      expect(find.text(_formatted), findsNothing);
    });

    testWidgets('D5 — port rendant `null` : repli ISO (AD-10)', (tester) async {
      await tester.pumpWidget(
        _host(_dateWidget(_iso), formatter: const _NullFormatter()),
      );

      expect(find.text(_iso), findsOneWidget);
    });

    testWidgets('D6 — port qui LÈVE : repli ISO, aucune exception (AD-10)',
        (tester) async {
      await tester.pumpWidget(
        _host(_dateWidget(_iso), formatter: const _ThrowingFormatter()),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_iso), findsOneWidget);
    });

    testWidgets('D7 — valeur non parsable : repli brut', (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(
        _host(_dateWidget('pas-une-date'), formatter: port),
      );

      expect(find.text('pas-une-date'), findsOneWidget);
      expect(port.calls, isEmpty);
    });

    testWidgets('D8 — la locale ambiante atteint le port (BCP-47)',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(
        ZcrudScope(
          dateDisplayFormatter: port,
          child: MaterialApp(
            // `en-GB` (et non `fr-FR`) : `DefaultMaterialLocalizations` ne
            // supporte que `en` sans `flutter_localizations` — mais le SOUS-tag
            // régional suffit à discriminer (le défaut du harnais est `en`).
            locale: const Locale('en', 'GB'),
            supportedLocales: const <Locale>[Locale('en', 'GB'), Locale('en')],
            home: Scaffold(body: _dateWidget(_iso)),
          ),
        ),
      );

      expect(port.calls.single.localeTag, 'en-GB');
    });

    testWidgets('D9 — la SÉMANTIQUE annonce la valeur projetée', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(_dateWidget(_iso), formatter: _RecordingFormatter()),
      );

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape('Date'))),
        findsWidgets,
      );
      final node = tester.getSemantics(find.byType(ZDateFieldWidget).first);
      expect(node.value, contains(_formatted));
      expect(node.value, isNot(contains(_iso)));
      handle.dispose();
    });

    testWidgets('D10 — échappatoire `decorated: false` : projetée aussi',
        (tester) async {
      await tester.pumpWidget(
        _host(
          _dateWidget(_iso, decorated: false),
          formatter: _RecordingFormatter(),
        ),
      );

      expect(find.text('Date : $_formatted'), findsOneWidget);
      expect(find.textContaining(_iso), findsNothing);
    });

    testWidgets('D11 — la voie de DISPATCH réelle porte la projection',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'d': _iso},
        visibleFields: <String>['d'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ZcrudScope(
          dateDisplayFormatter: _RecordingFormatter(),
          child: MaterialApp(
            home: Scaffold(
              body: DynamicEdition(
                controller: controller,
                fields: <ZFieldSpec>[_dateField()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ZDateFieldWidget), findsOneWidget);
      expect(find.text(_formatted), findsOneWidget);
      expect(find.textContaining(_iso), findsNothing);
    });
  });

  group('CR-DODLP-DATE-DISPLAY — famille dateRange', () {
    testWidgets('D12 — les DEUX bornes projetées, en mode `date`',
        (tester) async {
      final port = _BoundFormatter();
      await tester.pumpWidget(_host(_rangeWidget(), formatter: port));

      expect(find.text('$_formattedStart → $_formattedEnd'), findsOneWidget);
      expect(find.textContaining(_rangeStartIso), findsNothing);
      expect(find.textContaining(_rangeEndIso), findsNothing);
      expect(port.modes, <ZDateMode>[ZDateMode.date, ZDateMode.date]);
    });

    testWidgets('D13 — SANS port : exactement l\'ISO d\'avant (hôte passif)',
        (tester) async {
      await tester.pumpWidget(_host(_rangeWidget()));

      expect(find.text('$_rangeStartIso → $_rangeEndIso'), findsOneWidget);
    });

    testWidgets('D14 — port qui LÈVE : repli ISO sur les DEUX bornes',
        (tester) async {
      await tester.pumpWidget(
        _host(_rangeWidget(), formatter: const _ThrowingFormatter()),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('$_rangeStartIso → $_rangeEndIso'), findsOneWidget);
    });
  });
}
