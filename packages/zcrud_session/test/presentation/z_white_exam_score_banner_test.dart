/// Bandeau de résultat d'examen blanc : verdict peint, seuil paramétrable et
/// trois statistiques.
///
/// La couleur est mesurée **telle qu'elle est peinte** : une garde qui se
/// contenterait de lire un paramètre ne dirait rien de ce que voit
/// l'apprenant.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../support/z_sources.dart';

ZStudySessionResult _result({required int correct, required int total}) =>
    ZStudySessionResult(
      mode: ZReviewMode.whiteExam,
      total: total,
      correct: correct,
      byQuality: const <String, int>{},
    );

Widget _app({
  required ZStudySessionResult result,
  Duration elapsed = Duration.zero,
  double? successRatio,
  ZColorKeyResolver? colorKeyResolver,
}) {
  final banner = ZWhiteExamScoreBanner(
    result: result,
    elapsed: elapsed,
    successRatio: successRatio,
  );
  return MaterialApp(
    home: Scaffold(
      body: colorKeyResolver == null
          ? banner
          : ZcrudScope(colorKeyResolver: colorKeyResolver, child: banner),
    ),
  );
}

Color _painted(WidgetTester tester) {
  final decorated = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(ZWhiteExamScoreBanner.bannerKey),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (decorated.decoration as BoxDecoration).color!;
}

ColorScheme _scheme(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(ZWhiteExamScoreBanner.bannerKey)),
).colorScheme;

void main() {
  testWidgets('au-dessus du seuil déclaré, le bandeau peint la réussite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 4, total: 5), successRatio: 0.7),
    );

    expect(_painted(tester), _scheme(tester).primaryContainer);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('sous le seuil déclaré, il peint l\'autre rôle', (tester) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 3, total: 5), successRatio: 0.7),
    );

    expect(_painted(tester), _scheme(tester).tertiaryContainer);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('les deux rôles sont bien DEUX couleurs distinctes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 5, total: 5), successRatio: 0.7),
    );
    final passed = _painted(tester);
    final scheme = _scheme(tester);

    await tester.pumpWidget(
      _app(result: _result(correct: 0, total: 5), successRatio: 0.7),
    );
    expect(_painted(tester), isNot(passed));
    expect(passed, scheme.primaryContainer);
  });

  testWidgets('atteindre EXACTEMENT le seuil réussit', (tester) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 7, total: 10), successRatio: 0.7),
    );
    expect(_painted(tester), _scheme(tester).primaryContainer);

    await tester.pumpWidget(
      _app(result: _result(correct: 6, total: 10), successRatio: 0.7),
    );
    expect(_painted(tester), _scheme(tester).tertiaryContainer);
  });

  testWidgets('le seuil est paramétrable', (tester) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 6, total: 10), successRatio: 0.5),
    );
    expect(_painted(tester), _scheme(tester).primaryContainer);

    await tester.pumpWidget(
      _app(result: _result(correct: 6, total: 10), successRatio: 0.9),
    );
    expect(_painted(tester), _scheme(tester).tertiaryContainer);
  });

  testWidgets('sans seuil déclaré, AUCUN verdict n\'est prononcé', (
    tester,
  ) async {
    await tester.pumpWidget(_app(result: _result(correct: 5, total: 5)));

    final scheme = _scheme(tester);
    expect(_painted(tester), scheme.surfaceContainerHighest);
    expect(_painted(tester), isNot(scheme.primaryContainer));
    expect(_painted(tester), isNot(scheme.tertiaryContainer));
    expect(
      find.textContaining('%'),
      findsNothing,
      reason: 'un taux atteint n\'a de sens que face à un taux exigé',
    );
    // Les statistiques, elles, restent rendues.
    expect(find.text('5/5'), findsOneWidget);
  });

  testWidgets('un seuil inexploitable ne prononce aucun verdict non plus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 8, total: 10), successRatio: double.nan),
    );

    expect(_painted(tester), _scheme(tester).surfaceContainerHighest);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('une épreuve sans réponse notée ne divise par rien', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(result: _result(correct: 0, total: 0), successRatio: 0.7),
    );

    expect(_painted(tester), _scheme(tester).tertiaryContainer);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('la teinte passe par une CLÉ : l\'hôte peut la remplacer', (
    tester,
  ) async {
    const hostColor = Color(0xFF123456);
    ZColorPair? resolver(ColorScheme scheme, String key) =>
        key == ZWhiteExamScoreBanner.successColorKey
        ? const ZColorPair(color: hostColor, onColor: Color(0xFFFFFFFF))
        : null;

    await tester.pumpWidget(
      _app(
        result: _result(correct: 5, total: 5),
        successRatio: 0.7,
        colorKeyResolver: resolver,
      ),
    );

    expect(_painted(tester), hostColor);
  });

  testWidgets('les trois statistiques sont rendues', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        result: _result(correct: 3, total: 5),
        elapsed: const Duration(minutes: 2, seconds: 30),
      ),
    );

    expect(
      tester
          .getSemantics(find.byKey(ZWhiteExamScoreBanner.correctStatKey))
          .value,
      '3/5',
    );
    expect(
      tester
          .getSemantics(find.byKey(ZWhiteExamScoreBanner.elapsedStatKey))
          .value,
      '02:30',
    );
    expect(
      tester
          .getSemantics(find.byKey(ZWhiteExamScoreBanner.averageStatKey))
          .value,
      '00:30',
      reason: 'deux minutes trente sur cinq réponses',
    );
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('02:30'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    handle.dispose();
  });

  test('la durée visible ne porte aucun mot', () {
    expect(zWhiteExamDigits(const Duration(seconds: 65)), '01:05');
    expect(zWhiteExamDigits(const Duration(hours: 1, minutes: 5)), '1:05:00');
    expect(zWhiteExamDigits(const Duration(seconds: -5)), '00:00');
  });

  test('le bandeau ne porte ni couleur ni libellé en dur', () {
    final source = strippedSource(
      File('lib/src/presentation/z_white_exam_score_banner.dart'),
    );
    final hardcoded = RegExp(r"""Text\s*\(\s*'([^']*)'""")
        .allMatches(source)
        .map((m) => m.group(1) ?? '')
        .where(
          (literal) => literal
              .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
              .replaceAll(RegExp(r'\$\w+'), '')
              .contains(RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]')),
        )
        .toList();
    expect(hardcoded, isEmpty, reason: 'libellés en dur : $hardcoded');
    expect(source.contains('Colors.'), isFalse);
    expect(source.contains('Color(0x'), isFalse);
    // Le taux de réussite est une donnée de l'application : sa valeur ne vit
    // nulle part dans ce paquet, pas même en repli.
    expect(RegExp(r'(?<![\d.])0\.\d').hasMatch(source), isFalse);
  });
}
