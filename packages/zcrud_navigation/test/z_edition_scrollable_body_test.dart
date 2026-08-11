/// 🔴 Gardes de la CR **scaffold-scrollable-body** (2026-08-09) —
/// `ZEditionScaffold` face à un corps qui **défile lui-même**.
///
/// ⚠️ **Hauteur NON BORNÉE obligatoire.** Un corps de hauteur finie (un `Text`,
/// un `SizedBox`) ne fait apparaître AUCUN de ces défauts : la garde serait
/// **vacante**. Tous les volets montent donc un `ListView.builder` de 60 lignes
/// de 60 dp — un viewport vertical qui **exige** une contrainte de hauteur
/// bornée pour se poser.
///
/// Volets :
/// * SB-1 — le crash de la CR est REPRODUIT sous l'ancien régime (`intrinsic`)
///   en `page` **et** en `sheet`, et il est ABSENT sous `scrollable` ;
/// * SB-2 — `dialog` allait déjà bien, dans les DEUX régimes (mesuré, pas
///   supposé symétrique) ;
/// * SB-3 — le corps DÉFILE réellement (pas seulement « monté ») ;
/// * SB-4 — l'en-tête repliable de `page` fonctionne TOUJOURS avec un corps
///   scrollable (repli **et** réapparition) ;
/// * SB-5 — AD-10 : le défaut piégeux ne tombe pas en silence — un message de
///   développement **nomme le paramètre** ;
/// * SB-6 — le corps NON scrollable est inchangé par l'ajout du paramètre.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        DynamicEdition,
        EditionFieldType,
        ZEditionStep,
        ZFieldSpec,
        ZFormController,
        ZStepperEdition,
        ZcrudLocalizationsDelegate;
import 'package:zcrud_navigation/zcrud_navigation.dart';

import 'support/z_edition_tree_serializer.dart';
import 'support/z_sources.dart' show stripSource;

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      home: Scaffold(body: child),
    );

/// Corps de hauteur **NON BORNÉE** — la seule forme qui expose le défaut.
Widget _scrollingBody() => ListView.builder(
      itemCount: 60,
      itemBuilder: (BuildContext context, int i) =>
          SizedBox(height: 60, child: Text('L$i')),
    );

Widget _scaffold(
  ZEditionPresentation mode, {
  required ZEditionBodyFit fit,
  Widget? body,
}) =>
    ZEditionScaffold(
      body: body ?? _scrollingBody(),
      chrome: const ZEditionChrome(title: 'Titre'),
      mode: mode,
      bodyFit: fit,
    );

/// Compte les erreurs Flutter émises pendant [action], en les DÉTOURNANT du
/// binding de test (sinon le premier rouge ferait échouer le volet lui-même).
Future<List<FlutterErrorDetails>> _captureErrors(
  Future<void> Function() action,
) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await action();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

bool _hasUnboundedViewportError(List<FlutterErrorDetails> errors) =>
    errors.any((FlutterErrorDetails d) =>
        d.exception.toString().contains('unbounded height') ||
        d.exception.toString().contains('was not laid out'));

const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'a', label: 'A', type: EditionFieldType.text),
  ZFieldSpec(name: 'b', label: 'B', type: EditionFieldType.text),
  ZFieldSpec(name: 'c', label: 'C', type: EditionFieldType.text),
];

void main() {
  group(
      'SB-7 — les corps RÉELS de la CR (`DynamicEdition`, `ZStepperEdition`), '
      'pas seulement un `ListView` de laboratoire', () {
    // 🔴 Les deux widgets échouent DIFFÉREMMENT — aucune symétrie supposée :
    // `DynamicEdition` est une `ListView` ⇒ « Vertical viewport was given
    // unbounded height » ; `ZStepperEdition` est une `Column` + `Expanded`
    // ⇒ « RenderFlex children have non-zero flex but incoming height
    // constraints are unbounded ». Une seule déclaration corrige les deux.
    for (final (String name, Widget Function(ZFormController) build)
        in <(String, Widget Function(ZFormController))>[
      (
        'DynamicEdition',
        (ZFormController c) => DynamicEdition(controller: c, fields: _fields),
      ),
      (
        'ZStepperEdition',
        (ZFormController c) => ZStepperEdition(
              controller: c,
              fields: _fields,
              steps: const <ZEditionStep>[
                ZEditionStep(title: 'S1', fields: <String>['a']),
                ZEditionStep(title: 'S2', fields: <String>['b', 'c']),
              ],
            ),
      ),
    ]) {
      for (final ZEditionPresentation mode in ZEditionPresentation.values) {
        testWidgets('$name — ${mode.name}/scrollable : AUCUNE erreur',
            (WidgetTester tester) async {
          final ZFormController controller =
              ZFormController(initialValues: const <String, Object?>{});
          addTearDown(controller.dispose);
          final List<FlutterErrorDetails> errors =
              await _captureErrors(() async {
            await tester.pumpWidget(_host(_scaffold(mode,
                fit: ZEditionBodyFit.scrollable, body: build(controller))));
          });
          expect(errors, isEmpty,
              reason: '🔴 $name/${mode.name} lève encore en `scrollable` : '
                  '${errors.map((FlutterErrorDetails d) => d.exception.toString().split('\n').first).toList()}');
        });
      }

      for (final ZEditionPresentation mode in <ZEditionPresentation>[
        ZEditionPresentation.page,
        ZEditionPresentation.sheet,
      ]) {
        testWidgets(
            '$name — ${mode.name}/intrinsic : le défaut de la CR se REPRODUIT, '
            'et la garde le NOMME', (WidgetTester tester) async {
          final ZFormController controller =
              ZFormController(initialValues: const <String, Object?>{});
          addTearDown(controller.dispose);
          final List<FlutterErrorDetails> errors =
              await _captureErrors(() async {
            await tester.pumpWidget(_host(_scaffold(mode,
                fit: ZEditionBodyFit.intrinsic, body: build(controller))));
          });
          expect(errors, isNotEmpty,
              reason: '🔴 $name/${mode.name} ne reproduit plus le défaut : ce '
                  'volet ne prouve plus rien.');
          expect(
            errors.any((FlutterErrorDetails d) =>
                d.toString().contains('ZEditionBodyFit.scrollable')),
            isTrue,
            reason: '🔴 $name/${mode.name} : l\'hôte ne reçoit aucun message '
                'actionnable.',
          );
          tester.takeException();
        });
      }
    }
  });

  group(
      'SB-8 — le CÂBLAGE `presentEdition(bodyFit:)` → `ZEditionScaffold` '
      'existe vraiment (un passage de paramètre peut se perdre en silence)',
      () {
    Future<List<FlutterErrorDetails>> open(
      WidgetTester tester, {
      required ZEditionBodyFit fit,
      required String hostKey,
    }) async {
      return _captureErrors(() async {
        await tester.pumpWidget(MaterialApp(
          key: ValueKey<String>(hostKey),
          localizationsDelegates: const <LocalizationsDelegate<Object?>>[
            ZcrudLocalizationsDelegate(),
          ],
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => presentEdition<void>(
                    context,
                    builder: (_) => _scrollingBody(),
                    chrome: const ZEditionChrome(title: 'Titre'),
                    forcedMode: ZEditionPresentation.page,
                    bodyFit: fit,
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('`scrollable` traverse jusqu\'au scaffold : AUCUNE erreur',
        (WidgetTester tester) async {
      final List<FlutterErrorDetails> errors = await open(tester,
          fit: ZEditionBodyFit.scrollable, hostKey: 'ok');
      expect(errors, isEmpty,
          reason: '🔴 `presentEdition(bodyFit:)` ne transmet pas la '
              'déclaration au scaffold : '
              '${errors.map((FlutterErrorDetails d) => d.exception.toString().split('\n').first).toList()}');
      expect(find.text('L0'), findsOneWidget);
    });

    testWidgets(
        'NON-VACUITÉ : le même montage en `intrinsic` LÈVE (sinon le volet '
        'ci-dessus passerait quoi qu\'on transmette)',
        (WidgetTester tester) async {
      final List<FlutterErrorDetails> errors = await open(tester,
          fit: ZEditionBodyFit.intrinsic, hostKey: 'ko');
      expect(_hasUnboundedViewportError(errors), isTrue);
      tester.takeException();
    });
  });

  group('SB-1 — le crash de la CR : REPRODUIT en `intrinsic`, ABSENT en '
      '`scrollable`', () {
    for (final ZEditionPresentation mode in <ZEditionPresentation>[
      ZEditionPresentation.page,
      ZEditionPresentation.sheet,
    ]) {
      testWidgets('${mode.name} — `intrinsic` LÈVE le rouge de layout',
          (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = await _captureErrors(() async {
          await tester.pumpWidget(
            _host(_scaffold(mode, fit: ZEditionBodyFit.intrinsic)),
          );
        });
        expect(
          _hasUnboundedViewportError(errors),
          isTrue,
          reason: '🔴 le défaut de la CR ne se reproduit plus en '
              '${mode.name}/intrinsic : ce volet ne prouve donc plus rien sur '
              'ce que `scrollable` corrige.',
        );
        tester.takeException();
      });

      testWidgets('${mode.name} — `scrollable` : AUCUNE erreur de layout',
          (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = await _captureErrors(() async {
          await tester.pumpWidget(
            _host(_scaffold(mode, fit: ZEditionBodyFit.scrollable)),
          );
        });
        expect(errors, isEmpty,
            reason: '🔴 ${mode.name}/scrollable lève encore : '
                '${errors.map((FlutterErrorDetails d) => d.exception).toList()}');
        expect(find.text('L0'), findsOneWidget);
      });
    }
  });

  group('SB-2 — `dialog` : correct dans les DEUX régimes (mesuré, jamais '
      'déduit des deux autres modes)', () {
    for (final ZEditionBodyFit fit in ZEditionBodyFit.values) {
      testWidgets('dialog / ${fit.name}', (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = await _captureErrors(() async {
          await tester.pumpWidget(
            _host(_scaffold(ZEditionPresentation.dialog, fit: fit)),
          );
        });
        expect(errors, isEmpty,
            reason: '🔴 dialog/${fit.name} lève : '
                '${errors.map((FlutterErrorDetails d) => d.exception).toList()}');
        expect(find.text('L0'), findsOneWidget);
      });
    }

    testWidgets(
        'dialog : les deux régimes rendent le MÊME arbre (bodyFit y est sans '
        'effet, et c\'est délibéré)', (WidgetTester tester) async {
      await tester.pumpWidget(_host(_scaffold(ZEditionPresentation.dialog,
          fit: ZEditionBodyFit.intrinsic, body: const Text('CORPS'))));
      final String a =
          zSerializeTree(tester, find.byType(ZEditionScaffold));
      await tester.pumpWidget(_host(_scaffold(ZEditionPresentation.dialog,
          fit: ZEditionBodyFit.scrollable, body: const Text('CORPS'))));
      final String b =
          zSerializeTree(tester, find.byType(ZEditionScaffold));
      expect(a, b,
          reason: '🔴 `bodyFit` a un effet en dialog alors que la mesure dit '
              'que le mode est déjà correct.');
    });
  });

  group('SB-3 — le corps DÉFILE réellement (pas seulement « monté »)', () {
    for (final ZEditionPresentation mode in <ZEditionPresentation>[
      ZEditionPresentation.page,
      ZEditionPresentation.sheet,
      ZEditionPresentation.dialog,
    ]) {
      testWidgets('${mode.name} — glisser fait DISPARAÎTRE le haut de liste',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(_scaffold(mode, fit: ZEditionBodyFit.scrollable)),
        );
        expect(find.text('L0'), findsOneWidget);
        await tester.drag(find.text('L2'), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text('L0'), findsNothing,
            reason: '🔴 ${mode.name} : le corps n\'a pas défilé — il est monté, '
                'et c\'est tout.');
        expect(find.text('L10'), findsOneWidget,
            reason: '🔴 ${mode.name} : aucune ligne plus bas n\'est apparue.');
      });
    }
  });

  testWidgets(
      'SB-4 — `page` : l\'en-tête REPLIABLE fonctionne toujours avec un corps '
      'scrollable (repli ET réapparition)', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(_scaffold(ZEditionPresentation.page,
          fit: ZEditionBodyFit.scrollable)),
    );
    expect(find.text('Titre'), findsOneWidget);
    await tester.drag(find.text('L2'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Titre'), findsNothing,
        reason: '🔴 l\'en-tête ne se replie PLUS quand le corps défile : '
            'c\'est exactement ce que produit '
            '`SliverFillRemaining(hasScrollBody: true)`, forme mesurée puis '
            'REJETÉE. Le corps consomme le geste et le viewport externe n\'a '
            'plus rien à défiler.');
    await tester.drag(find.text('L10'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.text('Titre'), findsOneWidget,
        reason: '🔴 l\'en-tête `floating` ne REPARAÎT pas au défilement '
            'inverse.');
  });

  group('SB-5 — AD-10 : le piège ne tombe pas en SILENCE', () {
    for (final ZEditionPresentation mode in <ZEditionPresentation>[
      ZEditionPresentation.page,
      ZEditionPresentation.sheet,
    ]) {
      testWidgets(
          '${mode.name} — un message de développement NOMME le paramètre à '
          'passer', (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = await _captureErrors(() async {
          await tester.pumpWidget(
            _host(_scaffold(mode, fit: ZEditionBodyFit.intrinsic)),
          );
        });
        final Iterable<String> texts =
            errors.map((FlutterErrorDetails d) => d.toString());
        expect(
          texts.any((String t) =>
              t.contains('ZEditionBodyFit.scrollable') &&
              t.contains('bodyFit')),
          isTrue,
          reason: '🔴 ${mode.name} : l\'hôte n\'obtient que « RenderBox was not '
              'laid out » et un écran blanc — aucun message ne lui dit QUEL '
              'paramètre passer. Erreurs vues : '
              '${texts.map((String t) => t.split('\n').first).toList()}',
        );
        expect(
          texts.any((String t) =>
              t.contains('shrinkWrap') &&
              t.contains('Ne modifiez PAS votre corps')),
          isTrue,
          reason: '🔴 le message ne dit pas à l\'hôte de NE PAS transformer son '
              'corps — c\'est pourtant le contournement qu\'il va inventer.',
        );
        tester.takeException();
      });
    }

    testWidgets(
        'aucun FAUX POSITIF : un corps de hauteur FINIE ne déclenche aucun '
        'message', (WidgetTester tester) async {
      for (final ZEditionPresentation mode in ZEditionPresentation.values) {
        final List<FlutterErrorDetails> errors = await _captureErrors(() async {
          await tester.pumpWidget(_host(_scaffold(mode,
              fit: ZEditionBodyFit.intrinsic, body: const Text('CORPS'))));
        });
        expect(errors, isEmpty,
            reason: '🔴 ${mode.name} : la garde crie sur un corps qui va bien.');
      }
    });

    test('FR-26 — le message ne peut pas devenir de l\'UI : il vit dans un '
        '`assert` et ne construit aucun widget', () {
      final List<String> source = <String>[
        'lib/src/presentation/z_edition_scaffold.dart',
      ];
      for (final String path in source) {
        // Le fichier BRUT (non stripé) sert à BORNER la tranche : la borne de
        // fin est elle-même un marqueur dartdoc (`/// Emphase visuelle …`),
        // donc chercher cette borne dans une source déjà strippée la ferait
        // disparaître. Seul le CONTENU de la tranche (les `.contains`/regex
        // ci-dessous) doit être insensible aux commentaires.
        final String code = File(path).readAsStringSync();
        final int start = code.indexOf('_ZRenderUnboundedBodyGuard');
        expect(start, greaterThan(0),
            reason: '🔴 la garde de layout a disparu du fichier.');
        // Tranche STRICTEMENT la classe de garde : sans borne de fin, la
        // tranche courait jusqu'au bout du fichier et attrapait le `Text` de
        // `_ZChromeAction` — la garde aurait rougi pour la MAUVAISE raison.
        const String end = '/// Emphase visuelle d\'une action de chrome';
        final int stop = code.indexOf(end, start);
        expect(stop, greaterThan(start),
            reason: '🔴 borne de fin de la garde introuvable : le volet FR-26 '
                'lirait tout le reste du fichier.');
        // Stripped à l'intérieur de la tranche : un dartdoc peut légitimement
        // CITER `ErrorWidget`/`Text(` pour documenter qu'ils sont interdits
        // ici (P0D1) — le grep vise le CODE, jamais la prose.
        final String body = stripSource(code.substring(start, stop));
        expect(body.contains('assert(() {'), isTrue,
            reason: '🔴 le diagnostic n\'est plus sous `assert` : il serait '
                'compilé en release.');
        expect(body.contains('ErrorWidget'), isFalse,
            reason: '🔴 le diagnostic construit un `ErrorWidget` — donc de '
                'l\'UI, avec du texte en dur (FR-26).');
        // Le message n'est jamais rendu : la garde ne construit aucun `Text`.
        expect(RegExp(r'\bText\(').hasMatch(body), isFalse,
            reason: '🔴 la garde de layout construit un `Text` : le message de '
                'développement pourrait s\'afficher.');
      }
    });
  });

  group('SB-6 — le corps NON scrollable reste INCHANGÉ', () {
    testWidgets(
        'l\'arbre des 3 modes avec un corps court est identique au défaut '
        'd\'aujourd\'hui, hors le nœud de garde', (WidgetTester tester) async {
      for (final ZEditionPresentation mode in ZEditionPresentation.values) {
        await tester.pumpWidget(_host(_scaffold(mode,
            fit: ZEditionBodyFit.intrinsic, body: const Text('CORPS'))));
        expect(find.text('CORPS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // La garde est TRANSPARENTE : le corps occupe exactement la place
        // qu'il occuperait sans elle (pas de contrainte ajoutée).
        expect(tester.getSize(find.text('CORPS')).height, greaterThan(0));
      }
    });

    testWidgets(
        '🔴 la MESURE qui fonde le défaut : `scrollable` N\'EST PAS gratuit '
        'pour un corps non scrollable — en `page` et en `sheet` l\'arbre '
        'DIFFÈRE', (WidgetTester tester) async {
      for (final ZEditionPresentation mode in <ZEditionPresentation>[
        ZEditionPresentation.page,
        ZEditionPresentation.sheet,
      ]) {
        await tester.pumpWidget(_host(_scaffold(mode,
            fit: ZEditionBodyFit.intrinsic, body: const Text('CORPS'))));
        final String a = zSerializeTree(tester, find.byType(ZEditionScaffold));
        await tester.pumpWidget(_host(_scaffold(mode,
            fit: ZEditionBodyFit.scrollable, body: const Text('CORPS'))));
        final String b = zSerializeTree(tester, find.byType(ZEditionScaffold));
        expect(a == b, isFalse,
            reason: '🔴 ${mode.name} : les deux régimes rendent le MÊME arbre '
                'sur un corps non scrollable. Si c\'était vrai, le régime '
                'robuste serait GRATUIT et devrait devenir le DÉFAUT — la '
                'décision « défaut = intrinsic » ne tiendrait plus.');
      }
    });
  });
}
