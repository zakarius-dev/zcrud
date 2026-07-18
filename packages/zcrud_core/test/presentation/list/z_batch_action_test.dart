// me-1 (AC1..AC8) — capacité GÉNÉRIQUE de sélection multiple + actions de lot.
//
// Tests PORTEURS (leçons E-STUDY-UI) : on assère le RÉSULTAT (rapport AD-39 :
// QUELLES racines réussies/échouées + sur QUELS `id` le seam a AGI), jamais une
// simple garde « rien n'a levé ». La sélection est keyée par `id` STABLE : un
// test prouve qu'après mutation de la source (suppression + décalage de
// positions), le lot vise les BONS `id`, jamais un item réoccupant une position
// (RISQUE N°1). Aucun Syncfusion : pur cœur (SM-5).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
// `Left`/`Right`/`Unit`/`unit`/`Either` sont re-exportés par le barrel
// `zcrud_core` (domain.dart) — pas d'import `dartz` direct (unnecessary_import).
import 'package:zcrud_core/zcrud_core.dart';

/// Seam de suppression ESPION : enregistre l'ORDRE des `id` reçus (preuve que le
/// seam a agi par `id` stable) ; échoue pour les `id` de [failingIds] ; lève pour
/// les `id` de [throwingIds] (AD-10). Chaque appel est `await`é par le contrôleur.
class _SpyDeleter {
  _SpyDeleter({
    this.failingIds = const <String>{},
    this.throwingIds = const <String>{},
  });
  final Set<String> failingIds;
  final Set<String> throwingIds;
  final List<String> received = <String>[];

  Future<ZResult<Unit>> call(String rootId) async {
    received.add(rootId);
    if (throwingIds.contains(rootId)) {
      throw StateError('boom-$rootId');
    }
    if (failingIds.contains(rootId)) {
      return Left<ZFailure, Unit>(ServerFailure('fail-$rootId'));
    }
    return Right<ZFailure, Unit>(unit);
  }
}

/// Seam de déplacement ESPION : enregistre chaque `(rootId, field, destination)`.
class _SpyMover {
  final List<(String, String, Object?)> received = <(String, String, Object?)>[];

  Future<ZResult<Unit>> call(
    String rootId,
    String attachmentField,
    Object? destination,
  ) async {
    received.add((rootId, attachmentField, destination));
    return Right<ZFailure, Unit>(unit);
  }
}

/// Seam d'écriture de champ commun ESPION : enregistre chaque `(id, field, val)`.
class _SpyWriter {
  final List<(String, String, String?)> received =
      <(String, String, String?)>[];

  Future<ZResult<Unit>> call(String rootId, String fieldName, String? value) async {
    received.add((rootId, fieldName, value));
    return Right<ZFailure, Unit>(unit);
  }
}

void main() {
  // ── AC3 — modèle d'actions de lot DÉCLARÉ en données ──────────────────────
  group('AC3 — ZBatchAction déclaré en données', () {
    test('onSelected == null ⇒ action ABSENTE ; enum delete/move/custom', () {
      const absent = ZBatchAction(
        kind: ZBatchActionKind.delete,
        label: 'Supprimer',
        icon: Icons.delete,
      );
      var tapped = false;
      final present = ZBatchAction(
        kind: ZBatchActionKind.custom,
        label: 'Exporter',
        icon: Icons.download,
        onSelected: () => tapped = true,
      );
      expect(absent.onSelected, isNull);
      expect(present.onSelected, isNotNull);
      present.onSelected!.call();
      expect(tapped, isTrue);
      // enum extensible (3 natures intégrées, additif AD-4).
      expect(ZBatchActionKind.values,
          containsAll(<ZBatchActionKind>[
            ZBatchActionKind.delete,
            ZBatchActionKind.move,
            ZBatchActionKind.custom,
          ]));
    });

    testWidgets('barre : action sans callback ABSENTE, avec callback PRÉSENTE + '
        'agit sur la sélection courante', (tester) async {
      final controller = ZListSelectionController()..selectAll(['a', 'b']);
      addTearDown(controller.dispose);
      final tappedOn = <Set<String>>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZBatchActionBar(
            controller: controller,
            actions: [
              const ZBatchAction(
                kind: ZBatchActionKind.move,
                label: 'Déplacer-absent',
                icon: Icons.drive_file_move,
                // onSelected null ⇒ ABSENT
              ),
              ZBatchAction(
                kind: ZBatchActionKind.delete,
                label: 'Supprimer-présent',
                icon: Icons.delete,
                onSelected: () =>
                    tappedOn.add(controller.selectedIds.value),
              ),
            ],
          ),
        ),
      ));
      // Action absente : introuvable ; action présente : trouvable et actionnée.
      expect(find.byTooltip('Déplacer-absent'), findsNothing);
      expect(find.byTooltip('Supprimer-présent'), findsOneWidget);
      await tester.tap(find.byTooltip('Supprimer-présent'));
      await tester.pump();
      // présence ≠ association : l'action a AGI sur la sélection courante.
      expect(tappedOn, [<String>{'a', 'b'}]);
    });
  });

  // ── AC1 — badge compteur (tranche réactive) + tout-sélectionner ───────────
  group('AC1 — badge compteur réactif + tout-sélectionner', () {
    testWidgets('le badge suit selectedCount ; select-all absent si callback null',
        (tester) async {
      final controller = ZListSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZBatchActionBar(
            controller: controller,
            actions: const [],
            countLabelBuilder: (n) => '$n sélectionné(s)',
            // onSelectAll null ⇒ bouton tout-sélectionner ABSENT
          ),
        ),
      ));
      expect(find.text('0 sélectionné(s)'), findsOneWidget);
      controller.selectAll(['x', 'y', 'z']);
      await tester.pump();
      expect(find.text('3 sélectionné(s)'), findsOneWidget);
      expect(find.byIcon(Icons.select_all), findsNothing);
    });

    testWidgets('bouton tout-sélectionner PRÉSENT si onSelectAll fourni',
        (tester) async {
      final controller = ZListSelectionController();
      addTearDown(controller.dispose);
      const all = ['a', 'b', 'c'];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZBatchActionBar(
            controller: controller,
            actions: const [],
            selectAllLabel: 'Tout',
            onSelectAll: () => controller.selectAll(all),
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Tout'));
      await tester.pump();
      expect(controller.selectedIds.value, all.toSet());
    });

    // D1 (code-review me-1) — a11y : le compteur ne doit être annoncé QU'UNE
    // fois. Porteur sur l'ARBRE SÉMANTIQUE réel (pas `find.text`) : rougit si le
    // `Semantics` conteneur re-porte `label: countLabel` (double annonce su-8).
    testWidgets('D1 : le badge compteur est annoncé UNE seule fois dans '
        'l\'arbre sémantique (pas de double annonce su-8)', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ZListSelectionController()..selectAll(['x', 'y', 'z']);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZBatchActionBar(
            controller: controller,
            actions: const [],
            countLabelBuilder: (n) => '$n sélectionné(s)',
          ),
        ),
      ));
      await tester.pump();

      // Compte les OCCURRENCES du compteur à travers TOUS les labels de nœuds
      // sémantiques. Avec le bug (label conteneur + Text), le label conteneur
      // vaut « 3 sélectionné(s)\n3 sélectionné(s) » ⇒ 2 occurrences ⇒ RED.
      const needle = '3 sélectionné(s)';
      var occurrences = 0;
      void visit(SemanticsNode node) {
        var i = 0;
        while ((i = node.label.indexOf(needle, i)) != -1) {
          occurrences++;
          i += needle.length;
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(occurrences, 1,
          reason: 'le compteur doit apparaître exactement une fois dans '
              'l\'arbre sémantique (double annonce su-8 sinon)');
      handle.dispose();
    });

    // D2 (code-review me-1) — a11y : le bouton « tout sélectionner » a un NOM
    // ACCESSIBLE prouvé sur l'arbre sémantique (rougit s'il est muet, su-9).
    testWidgets('D2 : le bouton « tout sélectionner » a un nom accessible '
        'sur l\'arbre sémantique', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ZListSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZBatchActionBar(
            controller: controller,
            actions: const [],
            selectAllLabel: 'Tout sélectionner',
            onSelectAll: () {},
          ),
        ),
      ));
      await tester.pump();

      // Le nom accessible du bouton passe par la propriété sémantique `tooltip`
      // (dump a11y : `flags-button=true tooltip="…"`) — c'est ce que le lecteur
      // d'écran annonce. Le flag bouton et le tooltip vivent sur le même nœud.
      final data = tester.getSemantics(find.byType(IconButton));
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      final accessibleName = '${data.label} ${data.tooltip}'.trim();
      expect(accessibleName, contains('Tout sélectionner'),
          reason: 'un bouton « tout sélectionner » actionnable ne doit jamais '
              'être muet pour un lecteur d\'écran (su-9)');
      handle.dispose();
    });

    // D2 — garde-fou constructeur : onSelectAll sans selectAllLabel est INTERDIT
    // (assert) — impossible de construire un bouton actionnable mais muet.
    test('D2 : onSelectAll fourni SANS selectAllLabel ⇒ AssertionError', () {
      final controller = ZListSelectionController();
      addTearDown(controller.dispose);
      expect(
        () => ZBatchActionBar(
          controller: controller,
          actions: const [],
          onSelectAll: () {},
          // selectAllLabel OMIS ⇒ bouton muet interdit.
        ),
        throwsAssertionError,
      );
    });
  });

  // ── AC2 — la sélection survit aux changements de liste par `id` STABLE ─────
  group('AC2 — sélection keyée par id stable (RISQUE N°1)', () {
    // NB (honnêteté du test — code-review me-1, D3) : le cœur ne détient qu'un
    // `Set<String>` d'`id` — il n'a NI position NI index, donc le bug
    // « index-vs-position » ne PEUT structurellement pas exister ICI (la vraie
    // surface de divergence `id ↔ ligne` vit dans `zcrud_list`, cf. son test
    // « sélection suit l'id RÉORDONNÉ »). Ce test-ci prouve ce que le cœur
    // garantit RÉELLEMENT : la sémantique d'un `Set<String>` face à un `id`
    // dont l'item a DISPARU de la source — chaque `id` sélectionné est traité
    // par le seam à l'identique et son sort (réussi/échoué) est rapporté au
    // grain de la racine, jamais appliqué à un autre `id`.
    test('un id sélectionné dont l\'item a DISPARU est rapporté en échec — le '
        'lot vise EXACTEMENT les id sélectionnés, jamais un autre', () async {
      // Sélection {B, C} keyée par id. Dans la source sous-jacente, l'item C a
      // disparu (son enregistrement n'existe plus) ⇒ le seam échoue pour C ;
      // B existe encore ⇒ réussit.
      final controller = ZListSelectionController()..selectAll(['B', 'C']);
      addTearDown(controller.dispose);
      final spy = _SpyDeleter(failingIds: {'C'}); // C a disparu ⇒ échoue

      final report = await controller.batchDelete(deleteRoot: spy.call);

      // Le seam a été appelé EXACTEMENT sur les id sélectionnés (B et C), par
      // `id` stable. Falsifiable PAR COMPORTEMENT : si le lot visait autre chose
      // que les id du `Set` (position, index, source décalée), ce set diffèrerait
      // ⇒ RED.
      expect(spy.received.toSet(), {'B', 'C'});
      // Rapport au grain racine : B réussi (existe), C échoué (disparu) avec
      // CAUSE — jamais appliqué à un item réoccupant sa position.
      expect(report.succeededRootIds, {'B'});
      expect(report.failedRootIds, {'C'});
      expect(report.failures['C'], isA<ZFailure>());
      // B (réussi) retiré de la sélection, C (échoué) conservé.
      expect(controller.selectedIds.value, {'C'});
    });

    test('réordonner/filtrer ne perd AUCUN id sélectionné non visible '
        '(anti-régression su-8)', () async {
      // 5 items sélectionnés ; un filtre ne montrerait que 2 d'entre eux, mais
      // la sélection (source de vérité UNIQUE) conserve les 5 id.
      final controller = ZListSelectionController()
        ..selectAll(['id1', 'id2', 'id3', 'id4', 'id5']);
      addTearDown(controller.dispose);
      final spy = _SpyDeleter();
      final report = await controller.batchDelete(deleteRoot: spy.call);
      // TOUS les id sélectionnés (visibles ou non) ont été traités.
      expect(spy.received.toSet(), {'id1', 'id2', 'id3', 'id4', 'id5'});
      expect(report.succeededRootIds, {'id1', 'id2', 'id3', 'id4', 'id5'});
    });
  });

  // ── AC4 — suppression awaited + rapport au grain de la racine ─────────────
  group('AC4 — batchDelete awaited + rapport AD-39', () {
    test('1 échec sur 3 : rapport = 2 réussies + 1 ZFailure ; succès retirés '
        'de la sélection, échec conservé ; AUCUNE exception', () async {
      final controller = ZListSelectionController()
        ..selectAll(['r1', 'r2', 'r3']);
      addTearDown(controller.dispose);
      final spy = _SpyDeleter(failingIds: {'r2'});

      final report = await controller.batchDelete(deleteRoot: spy.call);

      // await par racine : les 3 racines traitées (résultats capturés).
      expect(spy.received.toSet(), {'r1', 'r2', 'r3'});
      // Rapport fidèle : 2 réussies + 1 échouée avec CAUSE.
      expect(report.succeededRootIds, {'r1', 'r3'});
      expect(report.failedRootIds, {'r2'});
      expect(report.failures['r2'], const ServerFailure('fail-r2'));
      expect(report.hasFailures, isTrue);
      // Best-effort : succès retirés de la sélection, échec conservé.
      expect(controller.selectedIds.value, {'r2'});
    });

    test('un throw du seam est CAPTÉ en racine échouée (AD-10) — aucune '
        'exception ne franchit la surface', () async {
      final controller = ZListSelectionController()..selectAll(['a', 'b']);
      addTearDown(controller.dispose);
      final spy = _SpyDeleter(throwingIds: {'a'});

      final report = await controller.batchDelete(deleteRoot: spy.call);

      // 'a' a levé mais est rapporté en échec ; 'b' a réussi. Pas de throw.
      expect(report.failedRootIds, {'a'});
      expect(report.succeededRootIds, {'b'});
      expect(report.failures['a'], isA<ZFailure>());
      // 'b' bien traité malgré le throw sur 'a' (best-effort, leçon su-3/su-7).
      expect(spy.received.toSet(), {'a', 'b'});
    });

    test('sélection vide ⇒ rapport vide, no-op, aucune exception (AC8)',
        () async {
      final controller = ZListSelectionController();
      addTearDown(controller.dispose);
      final spy = _SpyDeleter();
      final report = await controller.batchDelete(deleteRoot: spy.call);
      expect(spy.received, isEmpty);
      expect(report.succeededRootIds, isEmpty);
      expect(report.hasFailures, isFalse);
    });

    test('post-dispose ⇒ rapport vide (AC8)', () async {
      final controller = ZListSelectionController()..toggle('x');
      controller.dispose();
      final spy = _SpyDeleter();
      final report = await controller.batchDelete(deleteRoot: spy.call);
      expect(spy.received, isEmpty);
      expect(report.succeededRootIds, isEmpty);
    });
  });

  // ── AC5 — déplacer : champ paramétrique + destination injectée ────────────
  group('AC5 — batchMove champ paramétrique + destination injectée', () {
    test('réaffecte le champ de rattachement DÉCLARÉ (jamais codé en dur) à la '
        'destination injectée, par élément', () async {
      final controller = ZListSelectionController()..selectAll(['m1', 'm2']);
      addTearDown(controller.dispose);
      final spy = _SpyMover();
      final report = await controller.batchMove(
        attachmentField: 'parent_id', // paramétrique, injecté par le modèle
        destination: 'folder-42', // sélecteur injecté par l'app
        moveRoot: spy.call,
      );
      // Chaque racine réaffectée sur le BON champ à la BONNE destination.
      expect(spy.received, containsAll(<(String, String, Object?)>[
        ('m1', 'parent_id', 'folder-42'),
        ('m2', 'parent_id', 'folder-42'),
      ]));
      expect(report.succeededRootIds, {'m1', 'm2'});
    });

    test('modèle SANS champ de rattachement ⇒ chaque racine échouée, AUCUNE '
        'écriture, aucun throw (AC8)', () async {
      final controller = ZListSelectionController()..selectAll(['m1', 'm2']);
      addTearDown(controller.dispose);
      final spy = _SpyMover();
      final report = await controller.batchMove(
        attachmentField: null, // modèle sans champ de rattachement
        destination: 'folder-42',
        moveRoot: spy.call,
      );
      // Aucune écriture tentée (spy jamais appelé) ; toutes racines échouées.
      expect(spy.received, isEmpty);
      expect(report.failedRootIds, {'m1', 'm2'});
      expect(report.failures['m1'], isA<DomainFailure>());
      // La sélection reste intacte (rien n'a été appliqué).
      expect(controller.selectedIds.value, {'m1', 'm2'});
    });
  });

  // ── AC6 — édition de champ commun DÉRIVÉE du ZFieldSpec ────────────────────
  group('AC6 — applyCommonField dérive les validateurs du ZFieldSpec', () {
    // Spec avec les MÊMES validateurs que le formulaire unitaire.
    const spec = ZFieldSpec(
      name: 'title',
      type: EditionFieldType.text,
      validators: [ZValidatorSpec.minLength(3, errorText: 'trop court')],
    );

    test('valeur INVALIDE (mêmes validateurs) ⇒ REJETÉE avant écriture : aucune '
        'racine touchée, toutes rapportées échouées', () async {
      final controller = ZListSelectionController()..selectAll(['a', 'b', 'c']);
      addTearDown(controller.dispose);
      final spy = _SpyWriter();
      final report = await controller.applyCommonField(
        field: spec,
        value: 'ab', // 2 < 3 ⇒ invalide selon le MÊME validateur
        writeRoot: spy.call,
      );
      // Le validateur du cœur (ZValidatorCompiler) rend le même verdict.
      final unitVerdict = ZValidatorCompiler.compile(spec.validators)!('ab');
      expect(unitVerdict, isNotNull); // invalide en unitaire aussi
      // AUCUNE écriture (spy jamais appelé) ; toutes racines échouées.
      expect(spy.received, isEmpty);
      expect(report.failedRootIds, {'a', 'b', 'c'});
      expect(report.failures['a'], const DomainFailure('trop court'));
      expect(report.succeededRootIds, isEmpty);
      // Sélection intacte (rien appliqué).
      expect(controller.selectedIds.value, {'a', 'b', 'c'});
    });

    test('valeur VALIDE ⇒ écrite par élément sur le BON champ ; rapport succès',
        () async {
      final controller = ZListSelectionController()..selectAll(['a', 'b']);
      addTearDown(controller.dispose);
      final spy = _SpyWriter();
      final report = await controller.applyCommonField(
        field: spec,
        value: 'valide',
        writeRoot: spy.call,
      );
      expect(spy.received, containsAll(<(String, String, String?)>[
        ('a', 'title', 'valide'),
        ('b', 'title', 'valide'),
      ]));
      expect(report.succeededRootIds, {'a', 'b'});
      expect(report.hasFailures, isFalse);
    });

    // D4 (code-review me-1) — l'édition d'un champ commun est IN-PLACE : les
    // éléments restent visibles ⇒ la sélection est CONSERVÉE par défaut (le
    // consommateur me-2 peut enchaîner un 2ᵉ champ sans tout re-sélectionner).
    // Porteur : rougit si le défaut redevenait `true` (sélection vidée).
    test('D4 : après applyCommonField RÉUSSIE la sélection est CONSERVÉE par '
        'défaut (édition in-place)', () async {
      final controller = ZListSelectionController()..selectAll(['a', 'b']);
      addTearDown(controller.dispose);
      final spy = _SpyWriter();
      final report = await controller.applyCommonField(
        field: spec,
        value: 'valide',
        writeRoot: spy.call,
      );
      expect(report.succeededRootIds, {'a', 'b'});
      // Défaut `false` : les éléments existent toujours ⇒ sélection intacte.
      expect(controller.selectedIds.value, {'a', 'b'});
    });

    // D4 — opt-out explicite : l'appelant peut forcer le vidage des réussies.
    test('D4 : clearSucceededFromSelection:true vide les réussies (opt-out)',
        () async {
      final controller = ZListSelectionController()..selectAll(['a', 'b']);
      addTearDown(controller.dispose);
      final spy = _SpyWriter();
      await controller.applyCommonField(
        field: spec,
        value: 'valide',
        writeRoot: spy.call,
        clearSucceededFromSelection: true,
      );
      expect(controller.selectedIds.value, isEmpty);
    });
  });

  // ── AC8 — robustesse : rapport, égalité de valeur ─────────────────────────
  group('AC8/AD-39 — ZBatchReport value object', () {
    test('égalité de valeur par contenu + hasFailures/failedRootIds', () {
      final a = ZBatchReport(
        succeededRootIds: {'r1'},
        failures: {'r2': const ServerFailure('x')},
      );
      final b = ZBatchReport(
        succeededRootIds: {'r1'},
        failures: {'r2': const ServerFailure('x')},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.hasFailures, isTrue);
      expect(a.failedRootIds, {'r2'});
      expect(a.succeededCount, 1);
      // ZBatchDeletionReport est le MÊME type (alias).
      expect(a, isA<ZBatchDeletionReport>());
      // collections non modifiables.
      expect(() => a.succeededRootIds.add('z'), throwsUnsupportedError);
      expect(() => a.failures['q'] = const ServerFailure('y'),
          throwsUnsupportedError);
    });
  });
}
