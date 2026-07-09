// AC4 : registre `ZcrudLabels` immuable, surchargeable, SANS état global.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('map interne NON modifiable (immuabilité, AC4)', () {
    final labels = ZcrudLabels({'save': 'Valider'});
    expect(() => labels.labels['save'] = 'x', throwsUnsupportedError);
    expect(() => labels.labels['add'] = 'y', throwsUnsupportedError);
    expect(ZcrudLabels.empty.labels, isEmpty);
    expect(() => ZcrudLabels.empty.labels['k'] = 'v', throwsUnsupportedError);
  });

  test('maybeResolve/resolve : surcharge, fallback, clé (AC4)', () {
    final labels = ZcrudLabels({'save': 'Valider', 'myBusinessKey': 'Métier'});
    expect(labels.maybeResolve('save'), 'Valider');
    expect(labels.maybeResolve('absent'), isNull);
    expect(labels.resolve('save'), 'Valider');
    expect(labels.resolve('absent'), 'absent');
    expect(labels.resolve('absent', fallback: 'F'), 'F');
    expect(labels.maybeResolve('myBusinessKey'), 'Métier');
  });

  test('== / hashCode par contenu (mapEquals, AC4)', () {
    final a = ZcrudLabels({'save': 'Valider', 'x': 'y'});
    final b = ZcrudLabels({'x': 'y', 'save': 'Valider'});
    final c = ZcrudLabels({'save': 'Autre'});
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  testWidgets('surcharge via ZcrudScope : label() renvoie la surcharge (AC4)',
      (tester) async {
    late String saved;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            labels: ZcrudLabels({'save': 'Valider'}),
            child: Builder(builder: (context) {
              saved = label(context, 'save');
              return const SizedBox();
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    // La surcharge du scope l'emporte sur le générique du delegate.
    expect(saved, 'Valider');
  });

  testWidgets('clé non surchargée → fallback delegate générique (AC4)',
      (tester) async {
    late String edited;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            labels: ZcrudLabels({'save': 'Valider'}),
            child: Builder(builder: (context) {
              edited = label(context, 'edit');
              return const SizedBox();
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(edited, 'Modifier');
  });

  testWidgets('ISOLATION : deux scopes/labels distincts résolvent indépendamment',
      (tester) async {
    late String left;
    late String right;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              ZcrudScope(
                labels: ZcrudLabels({'save': 'AAA'}),
                child: Builder(builder: (context) {
                  left = label(context, 'save');
                  return const SizedBox();
                }),
              ),
              ZcrudScope(
                labels: ZcrudLabels({'save': 'BBB'}),
                child: Builder(builder: (context) {
                  right = label(context, 'save');
                  return const SizedBox();
                }),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(left, 'AAA');
    expect(right, 'BBB');
  });
}
