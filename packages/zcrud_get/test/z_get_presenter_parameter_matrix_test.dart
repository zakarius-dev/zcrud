/// Gardes de la **matrice paramètre × mode** de `ZGetFormPresenter`
/// (CR-IFFD-78 ③) — jumeau mesuré de la garde de `zcrud_navigation`.
///
/// La CR demande que la règle « honoré, ou déclaré inerte » vaille pour **le
/// port**, donc pour **chaque** implémentation. Une matrice qui ne couvrirait
/// que `ZAdaptivePresenter` rouvrirait ailleurs exactement la divergence qu'elle
/// prétend fermer.
///
/// * **P1a — exhaustivité** : `ZEditionPresentation.values` pour les modes, et
///   le `switch` sans `default` de `zProbeArgs` pour les paramètres (**casse la
///   compilation**).
/// * **P1b — vs le PORT** : [_testPortSignature] parse les fichiers du port
///   **sur disque** (les mêmes que la garde de `zcrud_navigation`) et exige
///   l'égalité avec `ZPresenterParam.values`. C'est ce qui interdit aux deux
///   matrices de diverger sur la LISTE. 🔴 Limite nommée : garde, pas
///   compilation.
/// * **P2 — statut MESURÉ** : `ZMatrixCell.honoured` compare deux empreintes de
///   surface. Aucun champ où écrire un statut.
/// * **P3 — anti-vacuité** : aucun paramètre inerte sur les trois modes.
/// * **P4 — synchronisation** : document lu **tel qu'il est sur disque**.
///
/// 🔴 Ancrage par remontée jusqu'à `melos.yaml` — jamais un `../` relatif.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

import 'support/z_get_presenter_parameter_matrix.dart';

/// Les cellules mesurées, remplies par les sondes puis consommées par le rendu.
final List<ZMatrixCell> _cells = <ZMatrixCell>[];

const ZGetFormPresenter _presenter = ZGetFormPresenter();

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
  group('Matrice paramètre × mode — ZGetFormPresenter', () {
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

void _testPortSignature() {
  test('les fichiers du port existent sur disque', () {
    for (final String rel in kZPortSourcePaths) {
      expect(File('${zRepoRoot().path}/$rel').existsSync(), isTrue,
          reason: 'le port cité `$rel` est absent du dépôt.');
    }
  });

  test('ZPresenterParam == les paramètres de réglage déclarés par le port', () {
    final Set<String> surDisque = zPortParameterNames();
    expect(surDisque, isNotEmpty,
        reason: 'aucun paramètre extrait des sources du port : le parseur est '
            'cassé, ou la signature a changé de forme.');
    expect(
      surDisque,
      ZPresenterParam.values.map((ZPresenterParam p) => p.name).toSet(),
      reason: '🔴 CR-IFFD-78 ③ : le binding GetX doit couvrir EXACTEMENT les '
          'paramètres du port — c\'est ce qui interdit aux deux matrices de '
          'diverger sur la liste.',
    );
  });
}

void _testAucunParametreInertePartout() {
  test('aucun paramètre n\'est mesuré inerte sur les TROIS modes', () {
    for (final ZPresenterParam p in ZPresenterParam.values) {
      expect(
        _cells.where((ZMatrixCell c) => c.param == p).any(
              (ZMatrixCell c) => c.honoured,
            ),
        isTrue,
        reason: '`${p.name}` ne produit AUCUNE différence sur aucun mode : '
            'paramètre mort partout, ou sonde vacante '
            '(${zAlternativeLabel(p)}).',
      );
    }
  });

  test('les DEUX observations d\'une cellule honorée sont non dégénérées', () {
    for (final ZMatrixCell c in _cells.where((ZMatrixCell c) => c.honoured)) {
      expect(c.reference.rect, isNot('absent'),
          reason: '${c.param.name}/${c.mode.name} : référence non montée.');
      expect(c.alternative.rect, isNot('absent'),
          reason: '${c.param.name}/${c.mode.name} : alternative non montée.');
    }
  });
}

ZMatrixCell _cell(ZPresenterParam p, ZEditionPresentation m) =>
    _cells.firstWhere((ZMatrixCell c) => c.param == p && c.mode == m);

void _testInertiesSignaleesParLaCR() {
  test('① `useSafeArea` : honoré en sheet et dialog, INERTE en page', () {
    expect(
        _cell(ZPresenterParam.useSafeArea, ZEditionPresentation.sheet).honoured,
        isTrue);
    expect(
        _cell(ZPresenterParam.useSafeArea, ZEditionPresentation.dialog).honoured,
        isTrue);
    final ZMatrixCell page =
        _cell(ZPresenterParam.useSafeArea, ZEditionPresentation.page);
    expect(page.honoured, isFalse,
        reason: '`Get.to` ne pose aucune `SafeArea` — même inertie que '
            '`ZAdaptivePresenter`, et même conséquence : l\'honorer serait un '
            'changement de DÉFAUT visible pour tout hôte GetX passif.');
    expect(page.reference.padding, page.alternative.padding);
    expect(page.reference.padding, isNot(EdgeInsets.zero.toString()),
        reason: 'ANTI-VACUITÉ : un encart nul rendrait l\'égalité vraie pour '
            'une raison étrangère au paramètre.');
  });

  test('② `isDismissible` : honoré en sheet, inerte en page et dialog', () {
    final ZMatrixCell sheet =
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.sheet);
    expect(sheet.honoured, isTrue,
        reason: '🔴 la capacité était ABSENTE des DEUX présentateurs ; la '
            'fermer d\'un seul côté rouvrirait la divergence que la CR pointe.');
    expect(sheet.reference.barrier, 'ferme');
    expect(sheet.alternative.barrier, 'reste');
    expect(
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.dialog)
            .honoured,
        isFalse);
    expect(
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.page)
            .honoured,
        isFalse);
  });

  test('`allowImplicitDismiss` et `isDismissible` sont ORTHOGONAUX en sheet',
      () {
    final ZMatrixCell drag =
        _cell(ZPresenterParam.allowImplicitDismiss, ZEditionPresentation.sheet);
    final ZMatrixCell barrier =
        _cell(ZPresenterParam.isDismissible, ZEditionPresentation.sheet);
    expect(drag.honoured, isTrue);
    expect(barrier.honoured, isTrue);
    expect(drag.reference.barrier, drag.alternative.barrier,
        reason: 'couper le glissement ne doit PAS couper la barrière : elle '
            'passe par `maybePop`, donc par le garde d\'abandon (v0.60.0).');
    expect(drag.alternative.sheet, contains('enableDrag=false'));
    expect(barrier.reference.sheet, barrier.alternative.sheet,
        reason: '`isDismissible` ne doit rien changer au glissement.');
    expect(barrier.alternative.sheet, contains('enableDrag=true'));
  });

  testWidgets(
      '② COMBINÉS : `isDismissible: false` + garde d\'abandon ⇒ aucune sortie '
      'implicite, et le garde n\'est PAS consulté', (WidgetTester tester) async {
    // Même mesure que côté `ZAdaptivePresenter` : la règle écrite au dartdoc du
    // port doit valoir pour les DEUX implémentations, sinon elle ne vaut rien.
    int seamCalls = 0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = kZProbeScreen;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();

    late BuildContext host;
    await tester.pumpWidget(GetMaterialApp(
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
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byKey(kZProbeMarker), findsOneWidget,
        reason: 'la feuille doit rester : c\'est « interdire le renoncement ».');
    expect(seamCalls, 0,
        reason: '🔴 `isDismissible: false` ne GARDE pas le renoncement, il le '
            'RETIRE — le seam de confirmation n\'est jamais consulté sur cette '
            'voie. Sous GetX comme en Flutter vanilla.');
  });
}

void _testSynchronisation() {
  test('le document publié est identique au rendu des MESURES', () {
    final String root = zRepoRoot().path;
    final File doc = File('$root/$kZGetMatrixDocPath');

    expect(doc.existsSync(), isTrue,
        reason: '$kZGetMatrixDocPath est absent du dépôt.');

    // 🔴 Lecture du fichier TEL QU'IL EST : aucune régénération préalable.
    final String surDisque = doc.readAsStringSync();
    final String attendu = renderZPresenterMatrixMarkdown(
      implementation: 'ZGetFormPresenter',
      implementationPath:
          'packages/zcrud_get/lib/src/presentation/z_get_form_presenter.dart',
      guardPath:
          'packages/zcrud_get/test/z_get_presenter_parameter_matrix_test.dart',
      supportPath: 'packages/zcrud_get/test/support/'
          'z_get_presenter_parameter_matrix.dart',
      cells: _cells,
    );

    if (surDisque != attendu) {
      final File dump = File('${Directory.systemTemp.path}/'
          'zcrud-parameter-matrix-get.attendu.md')
        ..writeAsStringSync(attendu);
      fail('$kZGetMatrixDocPath a divergé des mesures. '
          'Contenu attendu écrit dans ${dump.path} — '
          'copiez-le sur $kZGetMatrixDocPath.');
    }
  });
}
