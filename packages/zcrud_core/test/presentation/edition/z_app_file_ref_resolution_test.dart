// LOT 1 (bloquant de migration DODLP) — `ZAppFileResolver` : le champ fichier
// résout des RÉFÉRENCES OPAQUES (`String`, ex. `shipDocumentsIds`) vers des
// `AppFile`.
//
// Défaut d'origine mesuré : `v.whereType<AppFile>()` écartait SILENCIEUSEMENT
// toute valeur qui n'était pas déjà un objet fichier ⇒ un champ fichier migré
// s'affichait VIDE sur une donnée existante, SANS erreur.
//
// Ce que ces gardes tiennent :
//  - port ABSENT ⇒ comportement historique STRICTEMENT conservé (hôte passif) ;
//  - port présent ⇒ résolution asynchrone SOUS la frontière de rebuild
//    (AD-2/SM-1 : `Element` du voisin identique, structurel inchangé, tranche
//    JAMAIS écrite) ;
//  - AD-10 : `Exception` (échec NORMAL d'E/S), `Error`, throw synchrone,
//    `Future` qui ne se termine jamais (délai de garde), référence introuvable
//    ⇒ rendu dégradé DÉFINI et VISIBLE, jamais une exception, jamais un champ
//    bloqué sans issue ;
//  - les références non résolues sont PRÉSERVÉES dans la tranche à l'écriture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_app_file_resolver.dart';
import '../../support/fake_file_picker.dart';

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

ZFieldSpec _fileField(
  String name, {
  bool multiple = false,
  bool readOnly = false,
}) =>
    ZFieldSpec(
      name: name,
      type: EditionFieldType.document,
      label: 'Pièces',
      multiple: multiple,
      readOnly: readOnly,
      config: const FileFieldConfig(
        allowedSources: <ZFileSource>[ZFileSource.filePicker],
      ),
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZAppFileResolver? resolver,
  ZFilePicker? picker,
}) =>
    MaterialApp(
      home: ZcrudScope(
        appFileResolver: resolver,
        filePicker: picker,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[field],
          ),
        ),
      ),
    );

void main() {
  group('Port ABSENT — hôte passif strictement immobile', () {
    testWidgets(
        'une référence `String` reste ignorée : aucune tuile, aucun état, '
        'aucune exception (comportement d\'AVANT le port)', (tester) async {
      final controller = _controller('docs', value: <Object>['ref-1', 'ref-2']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true)));
      // `pump` et NON `pumpAndSettle` : sous injection de la régression, la
      // tuile « en cours » anime un indicateur de progression — `pumpAndSettle`
      // rendrait alors un rouge d'INFRASTRUCTURE (timeout) au lieu du rouge
      // d'ASSERTION que cette garde doit produire.
      await tester.pump();
      await tester.pump();

      expect(find.byType(ZAppFileField), findsOneWidget);
      // AUCUN état de référence n'est introduit sans port : le rendu est
      // exactement celui d'avant (les refs n'existent pas pour le champ).
      expect(find.text('Loading file…'), findsNothing);
      expect(find.text('File unavailable'), findsNothing);
      expect(find.text('Could not load file'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'écriture sans port : la tranche reste `List<AppFile>` et les refs sont '
        'écartées comme avant', (tester) async {
      final picker =
          FakeFilePicker(<AppFile>[fakePendingFile(name: 'a.pdf', path: '/a')]);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          picker: picker));
      await tester.pump();

      await tester.tap(find.byTooltip('Pick a file'));
      await tester.pump();
      await tester.pump();

      final v = controller.valueOf('docs');
      expect(v, isA<List<AppFile>>(),
          reason: 'type de tranche historique préservé');
      expect((v! as List).length, 1,
          reason: 'sans port, la ref est écartée — comportement d\'avant');
    });
  });

  group('Port présent — résolution', () {
    testWidgets('les références résolues deviennent des fichiers VISIBLES',
        (tester) async {
      final resolver = FakeAppFileResolver(files: <AppFile>[
        fakeResolvedFile(id: 'ref-1', name: 'connaissement.pdf'),
        fakeResolvedFile(id: 'ref-2', name: 'facture.pdf'),
      ]);
      final controller = _controller('docs', value: <Object>['ref-1', 'ref-2']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('connaissement.pdf'), findsOneWidget);
      expect(find.text('facture.pdf'), findsOneWidget);
      expect(resolver.callCount, 1);
      expect(resolver.calls.first, <String>['ref-1', 'ref-2']);
    });

    testWidgets('la résolution N\'ÉCRIT JAMAIS la tranche (AD-2)',
        (tester) async {
      final resolver = FakeAppFileResolver(
          files: <AppFile>[fakeResolvedFile(id: 'ref-1')]);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);
      var writes = 0;
      controller.fieldListenable('docs').addListener(() => writes++);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('doc.pdf'), findsOneWidget);
      expect(writes, 0, reason: 'la résolution est un état UI local, pas une valeur');
      expect(controller.valueOf('docs'), <Object>['ref-1'],
          reason: 'la tranche porte toujours la RÉFÉRENCE, pas l\'objet');
    });

    testWidgets('mono-valeur : une `String` seule est résolue', (tester) async {
      final resolver = FakeAppFileResolver(
          files: <AppFile>[fakeResolvedFile(id: 'r9', name: 'unique.pdf')]);
      final controller = _controller('doc', value: 'r9');
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('doc'), resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('unique.pdf'), findsOneWidget);
    });

    testWidgets('une référence déjà demandée n\'est PAS redemandée à chaque build',
        (tester) async {
      final resolver = FakeAppFileResolver(
          files: <AppFile>[fakeResolvedFile(id: 'ref-1')]);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();
      // Force plusieurs rebuilds de la tranche (valeur ré-écrite à l'identique).
      for (var i = 0; i < 5; i++) {
        controller.setValue('docs', <Object>['ref-1']);
        await tester.pump();
      }
      expect(resolver.callCount, 1);
    });
  });

  group('AD-10 — tout échec produit un rendu dégradé DÉFINI et VISIBLE', () {
    testWidgets('référence INTROUVABLE (le port répond sans cet id) : état visible',
        (tester) async {
      final resolver = FakeAppFileResolver(files: const <AppFile>[]);
      final controller = _controller('docs', value: <Object>['fantome']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      // `pump` (cf. supra) : l'état `resolving` injecté animerait un indicateur.
      await tester.pump();
      await tester.pump();

      expect(find.text('File unavailable'), findsOneWidget,
          reason: 'une ref introuvable ne disparaît JAMAIS sans trace');
      expect(tester.takeException(), isNull);
    });

    testWidgets('`Exception` (échec NORMAL d\'E/S) : échec visible + réessai',
        (tester) async {
      final resolver = FakeAppFileResolver(
        failure: FakeResolveFailure.exception,
        files: <AppFile>[fakeResolvedFile(id: 'ref-1', name: 'ok.pdf')],
      );
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('Could not load file'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'un `on Error` seul aurait laissé remonter l\'Exception');

      // Le champ n'est PAS bloqué sans issue : le réessai rétablit.
      resolver.failure = FakeResolveFailure.none;
      await tester.tap(find.byTooltip('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.text('ok.pdf'), findsOneWidget);
      expect(resolver.callCount, 2);
    });

    testWidgets('`Error` : échec visible, aucune exception remontée',
        (tester) async {
      final resolver = FakeAppFileResolver(failure: FakeResolveFailure.error);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('Could not load file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('throw SYNCHRONE du port : échec visible, aucune exception',
        (tester) async {
      final resolver = FakeAppFileResolver(failure: FakeResolveFailure.syncThrow);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(find.text('Could not load file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '`Future` qui ne se termine JAMAIS : le délai de garde débloque le champ',
        (tester) async {
      final resolver = FakeAppFileResolver(
        failure: FakeResolveFailure.never,
        timeout: const Duration(seconds: 3),
      );
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pump();

      // AVANT le délai : état « en cours » visible (jamais un vide muet).
      expect(find.text('Loading file…'), findsOneWidget);
      expect(find.text('Could not load file'), findsNothing);

      // APRÈS le délai de garde : bascule sur l'échec réessayable.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Could not load file'), findsOneWidget);
      expect(find.byTooltip('Retry loading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Préservation des références dans la tranche', () {
    testWidgets(
        'ajouter un fichier ne DÉTRUIT PAS les références non résolues '
        '(port présent)', (tester) async {
      final picker =
          FakeFilePicker(<AppFile>[fakePendingFile(name: 'n.pdf', path: '/n')]);
      final resolver = FakeAppFileResolver(files: const <AppFile>[]);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver, picker: picker));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pick a file'));
      await tester.pumpAndSettle();

      final v = controller.valueOf('docs')! as List;
      expect(v.length, 2);
      expect(v.first, 'ref-1',
          reason: 'la référence persistée par l\'hôte survit à l\'édition');
      expect(v.last, isA<AppFile>());
    });

    testWidgets('retirer une référence l\'enlève de la tranche', (tester) async {
      final resolver = FakeAppFileResolver(files: const <AppFile>[]);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove file'));
      await tester.pumpAndSettle();
      expect(controller.valueOf('docs'), isEmpty);
    });
  });

  group('SM-1 / AD-2 — la résolution ne déplace RIEN hors du champ', () {
    testWidgets(
        'à l\'arrivée de la réponse : `Element` du voisin IDENTIQUE, compteurs '
        'de build voisins inchangés, builder structurel non rejoué',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final resolver = FakeAppFileResolver(
        failure: FakeResolveFailure.deferred,
        files: <AppFile>[fakeResolvedFile(id: 'ref-1', name: 'resolu.pdf')],
      );
      final fields = <ZFieldSpec>[
        const ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
        const ZFieldSpec(
            name: 'note', type: EditionFieldType.text, label: 'Note'),
        _fileField('docs', multiple: true),
      ];
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'nom': '',
          'note': '',
          'docs': <Object>['ref-1'],
        },
        visibleFields: <String>['nom', 'note', 'docs'],
      );
      addTearDown(controller.dispose);

      final builds = <String, int>{};
      var structural = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZcrudScope(
              appFileResolver: resolver,
              child: DynamicEdition(
                controller: controller,
                fields: fields,
                onStructuralBuild: () => structural++,
                fieldBuilder: (context, ctrl, field) => ZFieldWidget(
                  controller: ctrl,
                  field: field,
                  onBuild: () =>
                      builds[field.name] = (builds[field.name] ?? 0) + 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(resolver.callCount, 1, reason: 'la résolution est bien en vol');
      expect(find.text('Loading file…'), findsOneWidget);

      // Aucun `Form` global (AD-2) : chaque champ porte sa frontière.
      expect(find.byType(Form), findsNothing);

      final baseBuilds = Map<String, int>.from(builds);
      final baseStructural = structural;
      // Identité d'`Element` — la MESURE qui distingue « pas reconstruit » de
      // « reconstruit à l'identique ». On prend le voisin texte ET la racine du
      // formulaire.
      final nomElement = tester.element(find.byType(TextFormField).first);
      final editionElement = tester.element(find.byType(DynamicEdition));

      resolver.completeDeferred();
      await tester.pumpAndSettle();

      // La résolution a bien abouti DANS le champ fichier…
      expect(find.text('resolu.pdf'), findsOneWidget);
      expect(find.text('Loading file…'), findsNothing);

      // …et n'a déplacé RIEN d'autre.
      expect(identical(tester.element(find.byType(TextFormField).first),
              nomElement),
          isTrue,
          reason: 'l\'Element du champ voisin est le MÊME objet');
      expect(
          identical(tester.element(find.byType(DynamicEdition)), editionElement),
          isTrue);
      expect(structural, baseStructural,
          reason: 'le builder structurel n\'est pas rejoué');
      expect(builds['nom'], baseBuilds['nom'],
          reason: 'le voisin texte ne reconstruit pas');
      expect(builds['note'], baseBuilds['note']);
      expect(builds['docs'], baseBuilds['docs'],
          reason: 'même la FRONTIÈRE de tranche du champ fichier ne rejoue pas : '
              'la résolution vit SOUS elle (setState local du State)');
    });
  });

  group('a11y (AD-13)', () {
    testWidgets('état terminal annoncé (liveRegion) + cibles ≥ 48 dp',
        (tester) async {
      final handle = tester.ensureSemantics();
      final resolver = FakeAppFileResolver(failure: FakeResolveFailure.exception);
      final controller = _controller('docs', value: <Object>['ref-1']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, _fileField('docs', multiple: true),
          resolver: resolver));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.liveRegion ?? false) &&
              w.properties.label == 'Could not load file',
        ),
        findsOneWidget,
        reason: 'l\'échec est ANNONCÉ, pas seulement dessiné',
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
