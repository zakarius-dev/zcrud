// CR-IFFD-79 — « un champ n'affiche sa valeur que si elle a le type que son
// propre sélecteur ÉCRIT ».
//
// Le défaut mesuré chez l'hôte : une valeur SEMÉE depuis la persistance
// (`DateTime`) rendait un champ VIDE, alors que la valeur était bien là et
// serait resoumise intacte — un **mensonge d'affichage** silencieux, la classe
// de défaut déjà tranchée par CR-IFFD-77 puis `v0.65.0` (« dissocier présence
// et identité »).
//
// 🔴 Ces gardes exercent le chemin d'HYDRATATION (valeur semée), jamais le
// chemin de saisie — c'est précisément celui que huit tags n'ont pas exercé.
//
// Périmètre (chaque cas ci-dessous a été MESURÉ vide sur `v0.77.0`) :
//
//  - S1  : `dateTime` semé `DateTime`, hôte passif → l'ISO s'affiche ;
//  - S2  : `dateTime` semé `DateTime`, port injecté → la valeur ATTEINT le port
//          (mode `dateTime`, instant identique) et le rendu est sa sortie (§⑤) ;
//  - S3  : `time` semé `DateTime` → `HH:mm`, la convention que SON sélecteur
//          écrit (non mesuré par la CR, mesuré cassé ici) ;
//  - S4  : `time` semé `TimeOfDay` → `HH:mm` (idem) ;
//  - S5  : `time` semé `DateTime` n'appelle JAMAIS le port (le mode `time` reste
//          hors du port — discriminante vis-à-vis de S3) ;
//  - S6  : `dateTime` hors contrat (type non reconnu) → la présence est rendue
//          (`'$value'`), plus jamais le vide silencieux ;
//  - S7  : `dateRange` semé la **Map réellement persistée** (`toJson()`, ce que
//          le `toMap()` généré émet pour un champ `ZDateRange`) → les deux
//          bornes s'affichent ;
//  - S8  : `dateRange` Map CORROMPUE (`end < start`) → décodeur défensif
//          (AD-10, aucun throw) et présence rendue, pas le vide ;
//  - S9  : `dateRange` hors contrat → présence rendue ;
//  - S10 : hôte passif STRICTEMENT immobile — `String` ISO et `null` inchangés ;
//  - S11 : la voie de DISPATCH réelle (`ZFormController.initialValues` →
//          `DynamicEdition` → `ZFieldWidget`) porte la lecture : c'est le vrai
//          chemin d'hydratation, pas un montage direct.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Constantes de discrimination ─────────────────────────────────────────────
final _seedDateTime = DateTime(2025, 9, 1, 14, 30);
const _seedIso = '2025-09-01T14:30:00.000';
const _seedHhmm = '14:30';
const _portOutput = 'Neuvieme jour, quinzaine chaude';

/// Faux port : rend une chaîne RECONNAISSABLE (aucun fragment commun avec
/// l'ISO) et **enregistre** ses appels — ce journal est ce qui empêche S2/S5
/// d'être vacantes.
class _RecordingFormatter extends ZDateDisplayFormatter {
  _RecordingFormatter();

  final calls = <({ZDateMode mode, String? localeTag, DateTime value})>[];

  @override
  String? format(DateTime value, {required ZDateMode mode, String? localeTag}) {
    calls.add((mode: mode, localeTag: localeTag, value: value));
    return _portOutput;
  }
}

Widget _host(Widget child, {ZDateDisplayFormatter? formatter}) => ZcrudScope(
      dateDisplayFormatter: formatter,
      child: MaterialApp(home: Scaffold(body: child)),
    );

ZFieldSpec _spec(EditionFieldType type, {ZDateMode? mode}) => ZFieldSpec(
      name: 'd',
      type: type,
      label: 'Date',
      config: mode == null ? null : ZDateConfig(mode: mode),
    );

Widget _dateWidget(Object? value, {EditionFieldType? type}) => ZDateFieldWidget(
      field: _spec(type ?? EditionFieldType.dateTime),
      value: value,
      onChanged: (_) {},
    );

Widget _rangeWidget(Object? value) => ZDateRangeFieldWidget(
      field: _spec(EditionFieldType.dateRange),
      value: value,
      onChanged: (_) {},
    );

/// Valeur annoncée par le nœud sémantique UNIQUE du déclencheur — c'est ce
/// qu'un lecteur d'écran restitue, donc la propriété qui compte pour « le champ
/// ne ment pas ».
String? _announced(WidgetTester tester) =>
    tester.getSemantics(find.bySemanticsLabel('Date')).value;

void main() {
  group('CR-IFFD-79 — famille date : la graine est LUE', () {
    testWidgets('S1 — `dateTime` semé `DateTime`, hôte passif → ISO affiché',
        (tester) async {
      await tester.pumpWidget(_host(_dateWidget(_seedDateTime)));

      expect(find.text(_seedIso), findsOneWidget);
      expect(_announced(tester), _seedIso);
    });

    testWidgets('S2 — `dateTime` semé `DateTime` ATTEINT le port (§⑤)',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(_host(_dateWidget(_seedDateTime), formatter: port));

      // La valeur atteint le formateur : c'est tout l'objet de la CR.
      expect(port.calls, hasLength(1));
      expect(port.calls.single.mode, ZDateMode.dateTime);
      expect(port.calls.single.value, _seedDateTime);
      expect(find.text(_portOutput), findsOneWidget);
      expect(find.textContaining(_seedIso), findsNothing);
    });

    testWidgets('S3 — `time` semé `DateTime` → `HH:mm`', (tester) async {
      await tester.pumpWidget(
          _host(_dateWidget(_seedDateTime, type: EditionFieldType.time)));

      expect(find.text(_seedHhmm), findsOneWidget);
      expect(_announced(tester), _seedHhmm);
      // Jamais l'ISO complet dans un champ HEURE.
      expect(find.textContaining(_seedIso), findsNothing);
    });

    testWidgets('S4 — `time` semé `TimeOfDay` → `HH:mm`', (tester) async {
      await tester.pumpWidget(_host(_dateWidget(
        const TimeOfDay(hour: 14, minute: 30),
        type: EditionFieldType.time,
      )));

      expect(find.text(_seedHhmm), findsOneWidget);
      expect(_announced(tester), _seedHhmm);
    });

    testWidgets('S5 — `time` semé `DateTime` n\'appelle JAMAIS le port',
        (tester) async {
      final port = _RecordingFormatter();
      await tester.pumpWidget(_host(
        _dateWidget(_seedDateTime, type: EditionFieldType.time),
        formatter: port,
      ));

      expect(port.calls, isEmpty);
      expect(find.text(_seedHhmm), findsOneWidget);
      expect(find.text(_portOutput), findsNothing);
    });

    testWidgets('S6 — hors contrat : la PRÉSENCE est rendue, jamais le vide',
        (tester) async {
      await tester.pumpWidget(_host(_dateWidget(42)));

      expect(find.text('42'), findsOneWidget);
      expect(_announced(tester), '42');
    });
  });

  group('CR-IFFD-79 — famille dateRange : la graine persistée est LUE', () {
    testWidgets('S7 — la Map réellement persistée (`toJson()`) est lue',
        (tester) async {
      final seed = ZDateRange(
        start: DateTime(2026),
        end: DateTime(2026, 1, 31),
      ).toJson();

      await tester.pumpWidget(_host(_rangeWidget(seed)));

      expect(find.text('2026-01-01 → 2026-01-31'), findsOneWidget);
      expect(_announced(tester), '2026-01-01 → 2026-01-31');
    });

    testWidgets('S8 — Map CORROMPUE (`end < start`) : défensif + présence',
        (tester) async {
      const corrupt = <String, dynamic>{
        'start': '2026-01-31T00:00:00.000',
        'end': '2026-01-01T00:00:00.000',
      };

      await tester.pumpWidget(_host(_rangeWidget(corrupt)));

      // AD-10 : aucune exception n'a traversé le `build`.
      expect(tester.takeException(), isNull);
      // Et la valeur n'est pas effacée de l'affichage : elle sera resoumise.
      expect(_announced(tester), '$corrupt');
    });

    testWidgets('S9 — hors contrat : la PRÉSENCE est rendue', (tester) async {
      await tester.pumpWidget(_host(_rangeWidget(42)));

      expect(find.text('42'), findsOneWidget);
      expect(_announced(tester), '42');
    });
  });

  group('CR-IFFD-79 — hôte passif strictement immobile', () {
    testWidgets('S10a — `String` ISO : rendu inchangé', (tester) async {
      await tester.pumpWidget(_host(_dateWidget(_seedIso)));

      expect(find.text(_seedIso), findsOneWidget);
      expect(_announced(tester), _seedIso);
    });

    testWidgets('S10b — `null` : placeholder, aucune valeur inventée',
        (tester) async {
      await tester.pumpWidget(_host(_dateWidget(null)));

      expect(find.textContaining('2025'), findsNothing);
      expect(_announced(tester), isNot(contains('2025')));
      // Le placeholder l10n est annoncé (pas une chaîne vide).
      expect(_announced(tester), isNotEmpty);
    });

    testWidgets('S10c — `dateRange` semé `ZDateRange` : rendu inchangé',
        (tester) async {
      await tester.pumpWidget(_host(_rangeWidget(
        ZDateRange(start: DateTime(2026), end: DateTime(2026, 1, 31)),
      )));

      expect(find.text('2026-01-01 → 2026-01-31'), findsOneWidget);
    });
  });

  group('CR-IFFD-79 — voie de DISPATCH réelle (hydratation)', () {
    testWidgets('S11 — `initialValues: DateTime` → la valeur est visible',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'d': _seedDateTime},
        visibleFields: <String>['d'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ZcrudScope(
          child: MaterialApp(
            home: Scaffold(
              body: DynamicEdition(
                controller: controller,
                fields: <ZFieldSpec>[_spec(EditionFieldType.dateTime)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ZDateFieldWidget), findsOneWidget);
      expect(find.text(_seedIso), findsOneWidget);
      // La valeur soumise n'a PAS changé : le champ lit, il n'écrit pas.
      expect(controller.values['d'], _seedDateTime);
    });
  });
}
