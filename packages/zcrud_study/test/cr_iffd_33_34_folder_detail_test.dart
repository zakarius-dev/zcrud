/// CR-IFFD-33 (`progressionBuilder` libre) et CR-IFFD-34 (propagation RÉELLE du
/// sous-titre et du dégradé d'identité par `ZStudyFolderDetail`).
///
/// Les gardes de propagation sont posées **au site d'appel** : elles observent
/// l'`AppBar` effectivement construite, pas la seule déclaration du paramètre —
/// un champ déclaré mais non câblé passerait une garde de déclaration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

const Color _kOn = Color(0xFFFEDCBA);
const Color _kStart = Color(0xFF102030);
const Color _kEnd = Color(0xFF405060);

final List<String> _clesRecues = <String>[];

ZGradientSpec? _resolver(ColorScheme scheme, String key) {
  _clesRecues.add(key);
  if (key != 'dossier-42') return null;
  return const ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[_kStart, _kEnd]),
    onGradient: _kOn,
  );
}

/// Pompe une `ZStudyFolderDetail` avec les slots de CR-33/34 (le harnais
/// partagé ne les expose pas ; on ne le modifie pas pour ne pas empiéter sur les
/// autres chantiers en vol).
Future<void> _pumpDetail(
  WidgetTester tester, {
  Widget? subtitle,
  String? gradientKey,
  WidgetBuilder? progressionBuilder,
  ZProgressRingsData? progressData,
  List<Widget> progressStatCards = const <Widget>[],
  Widget? progressEmptyState,
  ZGradientResolver? resolver,
}) async {
  _clesRecues.clear();
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(
        gradientResolver: resolver,
        child: ZStudyFolderDetail(
          title: 'Dossier',
          subtitle: subtitle,
          gradientKey: gradientKey,
          materialTabLabel: kMatTab,
          notebookTabLabel: kNoteTab,
          progressionTabLabel: kProgTab,
          materialSectionsBuilder: defaultSections,
          notebookBuilder: (_) => const Text('NOTE_BODY'),
          progressionBuilder: progressionBuilder,
          progressData: progressData,
          progressStatCards: progressStatCards,
          progressEmptyState: progressEmptyState,
          nav: navSpec(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppBar _appBar(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar).first);

Future<void> _openProgression(WidgetTester tester) async {
  await tester.tap(find.text(kProgTab));
  await tester.pumpAndSettle();
}

void main() {
  group('CR-IFFD-34 — propagation RÉELLE par ZStudyFolderDetail', () {
    testWidgets('subtitle null ⇒ titre nu (rendu historique intact)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(tester);
      expect(_appBar(tester).title, isNot(isA<Column>()));
      expect(find.text('SOUS-TITRE'), findsNothing);
    });

    testWidgets('subtitle fourni ⇒ rendu dans l\'app-bar du shell', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(tester, subtitle: const Text('SOUS-TITRE'));
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('SOUS-TITRE'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('gradientKey SANS resolver hôte ⇒ app-bar inchangée', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(tester, gradientKey: 'dossier-42');
      expect(_appBar(tester).flexibleSpace, isNull);
      expect(_appBar(tester).foregroundColor, isNull);
    });

    testWidgets('gradientKey AVEC resolver ⇒ dégradé sur l\'en-tête', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(
        tester,
        gradientKey: 'dossier-42',
        resolver: _resolver,
      );
      // La clé transmise est bien l'identité du dossier, pas autre chose.
      expect(_clesRecues, contains('dossier-42'));
      expect(_appBar(tester).foregroundColor, _kOn);
      expect(_appBar(tester).flexibleSpace, isA<Container>());
    });
  });

  group('CR-IFFD-33 — progressionBuilder', () {
    testWidgets('absent + progressData ⇒ ANNEAU conservé (défaut intact)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(
        tester,
        progressData: const ZProgressRingsData(
          total: 10,
          correct: 7,
          ratio: .7,
        ),
        progressStatCards: const <Widget>[Text('stat A')],
      );
      await _openProgression(tester);
      expect(find.byType(ZStudyProgressRings), findsOneWidget);
      expect(find.text('stat A'), findsOneWidget);
    });

    testWidgets('fourni ⇒ PRIORITAIRE sur l\'anneau, même avec progressData', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(
        tester,
        progressData: const ZProgressRingsData(
          total: 10,
          correct: 7,
          ratio: .7,
        ),
        progressStatCards: const <Widget>[Text('stat A')],
        progressionBuilder: (_) => const Text('BARRES'),
      );
      await _openProgression(tester);
      expect(find.text('BARRES'), findsOneWidget);
      // L'onglet appartient au builder : ni anneau, ni cartes du chemin par
      // défaut ne subsistent (sinon le contenu serait dupliqué).
      expect(find.byType(ZStudyProgressRings), findsNothing);
      expect(find.text('stat A'), findsNothing);
    });

    testWidgets('fourni + progressData null ⇒ builder, PAS l\'état vide', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(
        tester,
        progressEmptyState: const Text('EMPTY'),
        progressionBuilder: (_) => const Text('BARRES'),
      );
      await _openProgression(tester);
      expect(find.text('BARRES'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
    });

    testWidgets(
      'progressEmptyState GARDE son sens : jamais rendu si progressData != null',
      (tester) async {
        await setScreen(tester, 500, 800);
        await _pumpDetail(
          tester,
          progressData: const ZProgressRingsData(
            total: 4,
            correct: 2,
            ratio: .5,
          ),
          progressEmptyState: const Text('EMPTY'),
        );
        await _openProgression(tester);
        expect(find.byType(ZStudyProgressRings), findsOneWidget);
        expect(find.text('EMPTY'), findsNothing);
      },
    );

    testWidgets('absent + progressData null ⇒ état vide (chemin historique)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await _pumpDetail(tester, progressEmptyState: const Text('EMPTY'));
      await _openProgression(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ZStudyProgressRings), findsNothing);
      expect(find.text('EMPTY'), findsOneWidget);
    });
  });
}
