/// Gardes de la **matrice paramètre × mode** de `ZAdaptivePresenter`
/// (CR-IFFD-78 ③).
///
/// Le livrable est `doc/parameter-matrix-z-adaptive-presenter.md`, **dérivé de
/// mesures** — pas d'une lecture du `switch`. Ce fichier est ce qui le rend
/// *incapable de mentir* :
///
/// * **P1a — exhaustivité des MODES** : tenue par `ZEditionPresentation.values`
///   (une valeur ajoutée à l'enum crée sa colonne toute seule) **et** par le
///   `switch` sans `default` de `zProbeArgs` côté paramètres, qui **casse la
///   compilation**.
/// * **P1b — exhaustivité des PARAMÈTRES vs le PORT** : [_testPortSignature]
///   parse les deux fichiers du port **sur disque** et exige l'égalité stricte
///   avec `ZPresenterParam.values`. 🔴 Limite nommée : c'est une garde, pas la
///   compilation.
/// * **P2 — statut MESURÉ** : `ZMatrixCell.honoured` est un *getter* qui compare
///   deux empreintes de surface. Il n'existe **aucun champ** où écrire un
///   statut : « honoré alors que la branche ne le lit pas » est **inexprimable**.
/// * **P3 — anti-vacuité** : [_testAucunParametreInertePartout] prouve que
///   chaque couple de valeurs sondé EST discriminant. Sans elle, une sonde
///   cassée se lirait « inerte partout ».
/// * **P4 — synchronisation** : [_testSynchronisation] lit le document **tel
///   qu'il est sur disque** et le compare au rendu des mesures. Il ne régénère
///   jamais avant de comparer.
///
/// 🔴 Ancrage par remontée jusqu'à `melos.yaml` — jamais un `../` relatif.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

import 'support/z_presenter_parameter_matrix.dart';

/// Les cellules mesurées, remplies par les sondes puis consommées par le rendu.
final List<ZMatrixCell> _cells = <ZMatrixCell>[];

const ZAdaptivePresenter _presenter = ZAdaptivePresenter();

Future<ZSurfaceObservation> _observe(
  WidgetTester tester, {
  required ZPresenterParam param,
  required ZEditionPresentation mode,
  required bool alternative,
}) {
  final ZProbeArgs a = zProbeArgs(param, alternative: alternative);
  return zObserveSurface(
    tester,
    probeId: '${param.name}-${mode.name}-$alternative',
    present: (BuildContext context, WidgetBuilder builder) => unawaited(
      _presenter.presentWithDismissControl<void>(
        context,
        builder: builder,
        mode: mode,
        maxWidth: a.maxWidth,
        maxHeight: a.maxHeight,
        useSafeArea: a.useSafeArea,
        barrierDismissible: a.barrierDismissible,
        allowImplicitDismiss: a.allowImplicitDismiss,
        isDismissible: a.isDismissible,
        sheetFrame: a.sheetFrame,
      ),
    ),
  );
}

void main() {
  group('Matrice paramètre × mode — ZAdaptivePresenter', () {
    for (final ZPresenterParam p in ZPresenterParam.values) {
      for (final ZEditionPresentation m in kZPresenterModes) {
        testWidgets('MESURE `${p.name}` × `${m.name}`', (WidgetTester t) async {
          final ZSurfaceObservation ref =
              await _observe(t, param: p, mode: m, alternative: false);
          final ZSurfaceObservation alt =
              await _observe(t, param: p, mode: m, alternative: true);
          _cells.add(ZMatrixCell(
            param: p,
            mode: m,
            reference: ref,
            alternative: alt,
          ));
        });
      }
    }

    _testCouverture();
    _testPortSignature();
    _testAucunParametreInertePartout();
    _testInertiesSignaleesParLaCR();
    _testSynchronisation();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P1a — filet redondant (la vraie garde est la compilation de `zProbeArgs`)
// ─────────────────────────────────────────────────────────────────────────────
void _testCouverture() {
  test('chaque couple (paramètre, mode) est mesuré exactement une fois', () {
    expect(_cells.length,
        ZPresenterParam.values.length * kZPresenterModes.length);
    expect(
      _cells.map((ZMatrixCell c) => '${c.param.name}/${c.mode.name}').toSet(),
      <String>{
        for (final ZPresenterParam p in ZPresenterParam.values)
          for (final ZEditionPresentation m in kZPresenterModes)
            '${p.name}/${m.name}',
      },
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P1b — la matrice suit la SIGNATURE du port, lue sur disque
// ─────────────────────────────────────────────────────────────────────────────
void _testPortSignature() {
  test('les fichiers du port existent sur disque', () {
    for (final String rel in kZPortSourcePaths) {
      expect(File('${zRepoRoot().path}/$rel').existsSync(), isTrue,
          reason: 'le port cité `$rel` est absent du dépôt : la garde de '
              'signature mesurerait le vide.');
    }
  });

  test('ZPresenterParam == les paramètres de réglage déclarés par le port', () {
    final Set<String> surDisque = zPortParameterNames();
    // ANTI-VACUITÉ : un parseur cassé rendrait l'ensemble vide, et l'égalité
    // ci-dessous échouerait — mais on le dit explicitement pour que le motif
    // d'échec soit lisible.
    expect(surDisque, isNotEmpty,
        reason: 'aucun paramètre extrait des sources du port : le parseur est '
            'cassé, ou la signature a changé de forme.');
    expect(
      surDisque,
      ZPresenterParam.values.map((ZPresenterParam p) => p.name).toSet(),
      reason: '🔴 CR-IFFD-78 ③ : un paramètre du port sans entrée dans la '
          'matrice (ou l\'inverse). Tout paramètre est soit honoré sur une '
          'surface, soit déclaré inerte sur elle — jamais absent de la table.',
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P3 — le piège que la CR décrit : une sonde qui ne peut RIEN mesurer
// ─────────────────────────────────────────────────────────────────────────────
void _testAucunParametreInertePartout() {
  test('aucun paramètre n\'est mesuré inerte sur les TROIS modes', () {
    for (final ZPresenterParam p in ZPresenterParam.values) {
      final Iterable<ZMatrixCell> row =
          _cells.where((ZMatrixCell c) => c.param == p);
      expect(
        row.any((ZMatrixCell c) => c.honoured),
        isTrue,
        reason: '`${p.name}` ne produit AUCUNE différence sur aucun mode. '
            'Deux lectures possibles, toutes deux graves : le paramètre est '
            'mort partout, ou le couple de valeurs sondé (${zAlternativeLabel(p)}) '
            'est incapable de discriminer — c\'est-à-dire une sonde vacante, '
            'exactement le défaut que CR-IFFD-78 signale.',
      );
    }
  });

  test('les DEUX observations d\'une cellule honorée sont non dégénérées', () {
    // Une cellule « honorée » où l'une des deux surfaces n'aurait pas été
    // montée du tout produirait une différence pour une raison ÉTRANGÈRE au
    // paramètre. On exige donc que le marqueur ait été rendu des deux côtés.
    for (final ZMatrixCell c in _cells.where((ZMatrixCell c) => c.honoured)) {
      expect(c.reference.rect, isNot('absent'),
          reason: '${c.param.name}/${c.mode.name} : surface de référence non '
              'montée.');
      expect(c.alternative.rect, isNot('absent'),
          reason: '${c.param.name}/${c.mode.name} : surface alternative non '
              'montée.');
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Les cellules NOMMÉES par la CR — tripwires ciblés
// ─────────────────────────────────────────────────────────────────────────────
ZMatrixCell _cell(ZPresenterParam p, ZEditionPresentation m) =>
    _cells.firstWhere((ZMatrixCell c) => c.param == p && c.mode == m);

void _testInertiesSignaleesParLaCR() {
  test('① `useSafeArea` : honoré en sheet et dialog, INERTE en page', () {
    expect(_cell(ZPresenterParam.useSafeArea, ZEditionPresentation.sheet)
        .honoured, isTrue);
    expect(_cell(ZPresenterParam.useSafeArea, ZEditionPresentation.dialog)
        .honoured, isTrue);
    // 🔴 Le fait mesuré qui fonde la décision : la route pleine n'insère
    // AUCUNE `SafeArea`, ni avec `true` ni avec `false`. L'encart reste donc
    // intact des deux côtés — ce n'est pas « l'opt-out est ignoré », c'est
    // « le paramètre entier est ignoré ».
    final ZMatrixCell page =
        _cell(ZPresenterParam.useSafeArea, ZEditionPresentation.page);
    expect(page.honoured, isFalse,
        reason: 'si cette garde rougit, quelqu\'un a rendu `useSafeArea` '
            'effectif en `page` : c\'est un CHANGEMENT DE DÉFAUT visible pour '
            'tout hôte passif, il appartient au propriétaire, pas à une '
            'refactorisation.');
    expect(page.reference.padding, page.alternative.padding);
    expect(page.reference.padding, isNot(EdgeInsets.zero.toString()),
        reason: 'ANTI-VACUITÉ : si l\'encart mesuré était nul, l\'égalité '
            'ci-dessus serait vraie pour une raison étrangère au paramètre.');
  });

  test('② `isDismissible` : honoré en sheet, inerte en page et dialog', () {
    final ZMatrixCell sheet =
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.sheet);
    expect(sheet.honoured, isTrue);
    // La différence porte bien sur la BARRIÈRE, pas sur autre chose.
    expect(sheet.reference.barrier, 'ferme');
    expect(sheet.alternative.barrier, 'reste');
    expect(
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.dialog)
            .honoured,
        isFalse,
        reason: 'en `dialog`, la barrière se règle par `barrierDismissible` : '
            'un second canal pour la même propriété serait le motif de '
            'divergence que ce dépôt s\'interdit.');
    expect(
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.page)
            .honoured,
        isFalse,
        reason: 'une route pleine n\'a pas de barrière — inertie structurelle.');
  });

  test('② `barrierDismissible` : honoré en dialog, inerte en sheet et page',
      () {
    final ZMatrixCell dialog =
        _cell(ZPresenterParam.barrierDismissible, ZEditionPresentation.dialog);
    expect(dialog.honoured, isTrue);
    expect(dialog.reference.barrier, 'ferme');
    expect(dialog.alternative.barrier, 'reste');
    // 🔴 C'est EXACTEMENT l'injection restée verte de la CR : `showModalBottomSheet`
    // ne prend pas `barrierDismissible`. La matrice le dit désormais.
    expect(
        _cell(ZPresenterParam.barrierDismissible, ZEditionPresentation.sheet)
            .honoured,
        isFalse);
  });

  test('`allowImplicitDismiss` et `isDismissible` sont ORTHOGONAUX en sheet',
      () async {
    // Les deux cellules sont honorées, et par des CANAUX DIFFÉRENTS :
    // le glissement pour l'un, la barrière pour l'autre. Si un jour l'un
    // capturait l'autre, ces égalités croisées rougiraient.
    final ZMatrixCell drag =
        _cell(ZPresenterParam.allowImplicitDismiss, ZEditionPresentation.sheet);
    final ZMatrixCell barrier =
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.sheet);

    expect(drag.honoured, isTrue);
    expect(barrier.honoured, isTrue);

    // `allowImplicitDismiss: false` NE touche PAS la barrière…
    expect(drag.reference.barrier, drag.alternative.barrier,
        reason: 'v0.60.0 a délibérément laissé la barrière fermante quand le '
            'glissement est coupé : elle passe par `maybePop`, donc par le '
            'garde d\'abandon. Cette propriété ne doit pas se perdre.');
    expect(drag.alternative.sheet, contains('enableDrag=false'));

    // …et `isDismissible: false` NE touche PAS le glissement.
    expect(barrier.reference.sheet, barrier.alternative.sheet,
        reason: '`isDismissible` ne doit rien changer au glissement : sinon '
            'les deux réglages ne seraient plus composables.');
    expect(barrier.alternative.sheet, contains('enableDrag=true'));
  });

  testWidgets(
      '② COMBINÉS : `isDismissible: false` + garde d\'abandon ⇒ aucune sortie '
      'implicite, et le garde n\'est PAS consulté', (WidgetTester tester) async {
    // Mesure demandée par CR-IFFD-78 ② : que se passe-t-il quand « interdire »
    // (`isDismissible: false`) et « garder » (`allowImplicitDismiss: false`,
    // ce que pose un `ZEditionChrome` gardant l'abandon) se combinent ?
    int seamCalls = 0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = kZProbeScreen;
    addTearDown(tester.view.reset);

    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (BuildContext c) {
        host = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));

    unawaited(_presenter.presentWithDismissControl<void>(
      host,
      mode: ZEditionPresentation.sheet,
      allowImplicitDismiss: false,
      isDismissible: false,
      builder: (BuildContext c) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? _) => seamCalls++,
        child: const SizedBox(key: kZProbeMarker, width: 80, height: 100),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(kZProbeMarker), findsOneWidget);

    // Glissement : la voie est coupée (`enableDrag: false`).
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse);

    // Barrière : le tap ne ferme pas, ET ne consulte même pas le garde —
    // `barrierDismissible: false` empêche `maybePop` d'être appelé.
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byKey(kZProbeMarker), findsOneWidget,
        reason: 'la feuille doit rester : c\'est « interdire le renoncement ».');
    expect(seamCalls, 0,
        reason: '🔴 la règle à écrire au dartdoc : `isDismissible: false` ne '
            'GARDE pas le renoncement, il le RETIRE — le seam de confirmation '
            'n\'est jamais consulté sur cette voie.');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P4 — synchronisation prouvée
// ─────────────────────────────────────────────────────────────────────────────
void _testSynchronisation() {
  test('le document publié est identique au rendu des MESURES', () {
    final String root = zRepoRoot().path;
    final File doc = File('$root/$kZAdaptiveMatrixDocPath');

    expect(doc.existsSync(), isTrue,
        reason: '$kZAdaptiveMatrixDocPath est absent du dépôt.');

    // 🔴 Lecture du fichier TEL QU'IL EST : aucune régénération préalable.
    final String surDisque = doc.readAsStringSync();
    final String attendu = renderZPresenterMatrixMarkdown(
      implementation: 'ZAdaptivePresenter',
      implementationPath: 'packages/zcrud_navigation/lib/src/presentation/'
          'z_adaptive_presenter.dart',
      guardPath: 'packages/zcrud_navigation/test/'
          'z_presenter_parameter_matrix_test.dart',
      supportPath: 'packages/zcrud_navigation/test/support/'
          'z_presenter_parameter_matrix.dart',
      cells: _cells,
    );

    if (surDisque != attendu) {
      final File dump = File('${Directory.systemTemp.path}/'
          'zcrud-parameter-matrix-adaptive.attendu.md')
        ..writeAsStringSync(attendu);
      fail('$kZAdaptiveMatrixDocPath a divergé des mesures. '
          'Contenu attendu écrit dans ${dump.path} — '
          'copiez-le sur $kZAdaptiveMatrixDocPath.');
    }
  });
}
