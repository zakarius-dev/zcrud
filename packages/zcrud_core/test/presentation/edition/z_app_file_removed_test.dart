// Ce qu'un champ fichier a RETENU du retrait.
//
// La tranche d'un champ fichier ne porte que ce qui **reste** attaché. Ce que
// l'utilisateur détache disparaissait au moment même où il le produisait : plus
// rien ne désignait le fichier à effacer pour de bon, et rien ne le signalait.
//
// Ces gardes fixent le contrat de bout en bout :
//  - le champ remonte ce qu'il TENAIT au retrait — l'objet fichier, y compris
//    quand l'entrée persistée n'était qu'une référence opaque déjà résolue ;
//  - le retrait survit jusqu'à la soumission, sous la clé compagne
//    `zRemovedFilesKey` de la voie de normalisation UNIQUE du socle ;
//  - un champ fichier sans retrait expose une liste VIDE, jamais `null` ;
//  - un formulaire sans champ fichier rend exactement les mêmes clés
//    qu'auparavant (contre-témoin) ;
//  - une transition d'état d'upload n'est PAS un retrait.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_app_file_resolver.dart';
import '../../support/fake_file_picker.dart';

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
  List<ZFieldSpec> fields, {
  ZAppFileResolver? resolver,
  ZFilePicker? picker,
  CloudStorageRepository? storage,
}) =>
    MaterialApp(
      home: ZcrudScope(
        appFileResolver: resolver,
        filePicker: picker,
        cloudStorage: storage,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

/// Le bouton « Retirer le fichier » de la n-ième tuile.
Finder _removeButton({int at = 0}) =>
    find.byTooltip('Remove file').at(at);

/// Transport qui rend un fichier portant **son** identité, pas la nôtre : le
/// chemin local disparaît au profit d'un identifiant distant. C'est la forme
/// qu'un stockage réel renvoie, et c'est elle qui ferait passer une simple mise
/// à jour d'état pour un retrait si le champ ne la distinguait pas.
class _RelabellingStorage implements CloudStorageRepository {
  @override
  Future<ZResult<AppFile>> upload(AppFile file) async =>
      Right<ZFailure, AppFile>(
        AppFile(
          id: 'distant-${file.name}',
          name: file.name,
          mimeType: file.mimeType,
          remoteUrl: 'https://cdn.exemple.test/${file.name}',
          uploadState: ZAppFileUploadState.uploaded,
        ),
      );

  @override
  Future<ZResult<Unit>> delete(AppFile file) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<String>> downloadUrl(AppFile file) async =>
      Left<ZFailure, String>(const ZNotFoundFailure('sans objet'));

  @override
  Stream<double> watchProgress(AppFile file) => const Stream<double>.empty();
}

void main() {
  group('Un fichier retiré est exposé, sous la forme utile', () {
    testWidgets('objet fichier retiré ⇒ l\'objet lui-même est remonté',
        (tester) async {
      final photo = fakePendingFile(name: 'permis.pdf', path: '/tmp/permis.pdf');
      final autre = fakePendingFile(name: 'carte.pdf', path: '/tmp/carte.pdf');
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'docs': <AppFile>[photo, autre],
        },
        visibleFields: const <String>['docs'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(controller, <ZFieldSpec>[_fileField('docs', multiple: true)]),
      );
      await tester.pump();

      expect(controller.removedFilesOf('docs'), isEmpty);

      await tester.tap(_removeButton());
      await tester.pump();

      expect(
        controller.removedFilesOf('docs'),
        <Object>[photo],
        reason: 'le fichier détaché est remonté tel que le champ le tenait',
      );
      expect(
        controller.valueOf('docs'),
        <AppFile>[autre],
        reason: 'la tranche ne porte plus que ce qui reste',
      );
    });

    testWidgets(
        'référence opaque RÉSOLUE retirée ⇒ l\'objet RÉSOLU est remonté, '
        'pas son identifiant', (tester) async {
      const referenceId = 'doc-42';
      final resolu = AppFile(
        id: referenceId,
        name: 'connaissement.pdf',
        mimeType: 'application/pdf',
        remoteUrl: 'https://exemple.test/connaissement.pdf',
        uploadState: ZAppFileUploadState.uploaded,
      );
      final resolver = FakeAppFileResolver(files: <AppFile>[resolu]);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'docs': <Object>[referenceId],
        },
        visibleFields: const <String>['docs'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          controller,
          <ZFieldSpec>[_fileField('docs', multiple: true)],
          resolver: resolver,
        ),
      );
      await tester.pump();
      await tester.pump();

      // La référence est bien résolue avant le retrait (sinon la garde
      // mesurerait le repli, pas la forme utile).
      expect(find.text('connaissement.pdf'), findsOneWidget);

      await tester.tap(_removeButton());
      await tester.pump();

      expect(
        controller.removedFilesOf('docs'),
        <Object>[resolu],
        reason: 'le contrat des appelants attend un objet RÉSOLU, pas un '
            'identifiant que la persistance seule sait relire',
      );
      expect(controller.valueOf('docs'), isEmpty);
    });

    testWidgets(
        'référence NON résolue retirée ⇒ la référence opaque est remontée '
        '(jamais un silence)', (tester) async {
      final resolver = FakeAppFileResolver(
        failure: FakeResolveFailure.exception,
      );
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'docs': <Object>['doc-inconnu'],
        },
        visibleFields: const <String>['docs'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          controller,
          <ZFieldSpec>[_fileField('docs', multiple: true)],
          resolver: resolver,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(_removeButton());
      await tester.pump();

      expect(controller.removedFilesOf('docs'), <Object>['doc-inconnu']);
    });

    testWidgets(
        'champ à valeur unique : le fichier REMPLACÉ compte comme retiré',
        (tester) async {
      final ancien = fakePendingFile(name: 'v1.pdf', path: '/tmp/v1.pdf');
      final nouveau = fakePendingFile(name: 'v2.pdf', path: '/tmp/v2.pdf');
      final picker = FakeFilePicker(<AppFile>[nouveau]);
      final controller = ZFormController(
        initialValues: <String, Object?>{'piece': ancien},
        visibleFields: const <String>['piece'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          controller,
          <ZFieldSpec>[_fileField('piece')],
          picker: picker,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Pick a file'));
      await tester.pump();

      expect(
        controller.removedFilesOf('piece'),
        <Object>[ancien],
        reason: 'un remplacement détache l\'ancien fichier tout autant qu\'une '
            'suppression',
      );
      expect(controller.valueOf('piece'), nouveau);
    });
  });

  group('Le retrait survit jusqu\'à la soumission', () {
    testWidgets(
        'la voie de normalisation unique du socle porte la clé compagne',
        (tester) async {
      final photo = fakePendingFile(name: 'permis.pdf', path: '/tmp/permis.pdf');
      final fields = <ZFieldSpec>[
        const ZFieldSpec(name: 'titre', type: EditionFieldType.text),
        _fileField('docs', multiple: true),
      ];
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'titre': 'Escale du 12',
          'docs': <AppFile>[photo],
        },
        visibleFields: const <String>['titre', 'docs'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, fields));
      await tester.pump();

      await tester.tap(_removeButton());
      await tester.pump();

      final valeurs = zNormalizeFormValues(fields: fields, controller: controller);
      expect(
        valeurs[zRemovedFilesKey('docs')],
        <Object>[photo],
        reason: 'la clé compagne est ce que lisent `ZFormOnly.values` et la '
            'soumission de l\'écran assemblé',
      );
      expect(valeurs['docs'], isEmpty);
      expect(valeurs['titre'], 'Escale du 12');
    });

    test('la clé compagne suit une convention unique, jamais écrite à la main',
        () {
      expect(zRemovedFilesKey('docs'), 'docs_removed');
    });

    test('un champ réellement déclaré sous ce nom n\'est jamais recouvert', () {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'docs', type: EditionFieldType.document, multiple: true),
        ZFieldSpec(name: 'docs_removed', type: EditionFieldType.text),
      ];
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'docs': <Object>[],
          'docs_removed': 'valeur de l\'hôte',
        },
      );
      addTearDown(controller.dispose);

      final valeurs = zNormalizeFormValues(fields: fields, controller: controller);
      expect(valeurs['docs_removed'], 'valeur de l\'hôte');
    });
  });

  group('Contrat figé : liste vide, jamais `null`', () {
    test('un champ fichier sans retrait expose une liste vide', () {
      final fields = <ZFieldSpec>[_fileField('docs', multiple: true)];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'docs': <Object>[]},
      );
      addTearDown(controller.dispose);

      expect(controller.removedFilesOf('docs'), isEmpty);
      final valeurs = zNormalizeFormValues(fields: fields, controller: controller);
      expect(valeurs.containsKey(zRemovedFilesKey('docs')), isTrue);
      expect(valeurs[zRemovedFilesKey('docs')], isEmpty);
      expect(valeurs[zRemovedFilesKey('docs')], isNotNull);
    });

    test('un champ fichier en lecture seule n\'expose aucune clé compagne', () {
      final fields = <ZFieldSpec>[_fileField('docs', multiple: true, readOnly: true)];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'docs': <Object>[]},
      );
      addTearDown(controller.dispose);

      final valeurs = zNormalizeFormValues(fields: fields, controller: controller);
      expect(valeurs.containsKey('docs'), isFalse);
      expect(valeurs.containsKey(zRemovedFilesKey('docs')), isFalse);
    });

    test('CONTRE-TÉMOIN : un formulaire sans champ fichier est inchangé', () {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'titre', type: EditionFieldType.text),
        ZFieldSpec(name: 'quantite', type: EditionFieldType.integer),
      ];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'titre': 'Escale', 'quantite': '3'},
      );
      addTearDown(controller.dispose);

      final valeurs = zNormalizeFormValues(fields: fields, controller: controller);
      expect(
        valeurs.keys.toSet(),
        <String>{'titre', 'quantite'},
        reason: 'aucune clé nouvelle là où le seam n\'est pas employé',
      );
    });
  });

  group('Ce qui n\'est PAS un retrait', () {
    testWidgets(
        'une transition d\'état d\'upload ne détache rien, même quand le '
        'transport renomme le fichier', (tester) async {
      final fichier = fakePendingFile(name: 'scan.pdf', path: '/tmp/scan.pdf');
      final picker = FakeFilePicker(<AppFile>[fichier]);
      final controller = ZFormController(
        initialValues: const <String, Object?>{'docs': <Object>[]},
        visibleFields: const <String>['docs'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          controller,
          <ZFieldSpec>[_fileField('docs', multiple: true)],
          picker: picker,
          storage: _RelabellingStorage(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Pick a file'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Le fichier a bien traversé l'upload (sinon la garde ne mesurerait rien).
      expect(
        (controller.valueOf('docs')! as List).single,
        isA<AppFile>().having(
          (f) => f.uploadState,
          'uploadState',
          ZAppFileUploadState.uploaded,
        ),
      );
      expect(
        controller.removedFilesOf('docs'),
        isEmpty,
        reason: 'acquérir puis refléter l\'état d\'un fichier n\'en détache aucun',
      );
    });

    test('un retrait consigné deux fois ne compte qu\'une fois', () {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final fichier = fakePendingFile();

      controller
        ..recordRemovedFile('docs', fichier)
        ..recordRemovedFile('docs', fichier);

      expect(controller.removedFilesOf('docs'), <Object>[fichier]);
    });

    test('`reset` / `reseed` / `markPristine` oublient les retraits en attente',
        () {
      final fichier = fakePendingFile();
      for (final oubli in <void Function(ZFormController)>[
        (c) => c.reset(),
        (c) => c.reseed(const <String, Object?>{'docs': <Object>[]}),
        (c) => c.markPristine(),
      ]) {
        final controller = ZFormController();
        controller.recordRemovedFile('docs', fichier);
        expect(controller.removedFilesOf('docs'), isNotEmpty);
        oubli(controller);
        expect(controller.removedFilesOf('docs'), isEmpty);
        expect(controller.removedFiles, isEmpty);
        controller.dispose();
      }
    });
  });
}
