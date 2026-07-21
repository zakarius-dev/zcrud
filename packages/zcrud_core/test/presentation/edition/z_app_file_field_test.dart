// AC6–AC10 (E3-3c) — `ZAppFileField` : acquisition via seam picker injecté →
// AppFile en tranche (value-in-slice) ; multiplicité single/multiple (+maxFiles) ;
// prévisualisation image/document + suppression ; états d'upload via port fake
// (pending/uploading→uploaded/failed + retry) ; dégradation propre sans seam.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_cloud_storage_repository.dart';
import '../../support/fake_file_picker.dart';

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZFilePicker? picker,
  CloudStorageRepository? storage,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          filePicker: picker,
          cloudStorage: storage,
          child: Scaffold(
            body: DynamicEdition(
                controller: controller, fields: <ZFieldSpec>[field]),
          ),
        ),
      ),
    );

/// Champ image mono-source (galerie) → 1 seul bouton d'action.
ZFieldSpec _imageField(String name, {bool multiple = false, int? maxFiles}) =>
    ZFieldSpec(
      name: name,
      type: EditionFieldType.image,
      label: 'Photo',
      multiple: multiple,
      config: FileFieldConfig(
        allowedSources: const <ZFileSource>[ZFileSource.gallery],
        maxFiles: maxFiles,
      ),
    );

void main() {
  testWidgets('AC6/AC7 : tap action → picker (seam) → AppFile pending en tranche '
      '(sans storage)', (tester) async {
    final picker = FakeFilePicker(<AppFile>[fakePendingFile()]);
    final controller = _controller('img');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img'), picker: picker));
    await tester.pump();
    expect(find.byType(ZAppFileField), findsOneWidget);

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pumpAndSettle();

    expect(picker.pickCount, 1);
    expect(picker.lastSource, ZFileSource.gallery);
    final v = controller.valueOf('img');
    expect(v, isA<AppFile>());
    expect((v! as AppFile).uploadState, ZAppFileUploadState.pending,
        reason: 'aucun storage injecté → reste pending (draft→cloud déféré)');
  });

  testWidgets('AC7 : filePicker == null → actions désactivées, aucun crash',
      (tester) async {
    final controller = _controller('img');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img')));
    await tester.pump();

    final btn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.photo_library_outlined));
    expect(btn.onPressed, isNull, reason: 'sans picker injecté → désactivé');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC8 : single → le pick REMPLACE (AppFile?)', (tester) async {
    final picker = FakeFilePicker(
        <AppFile>[fakePendingFile(name: 'a.png', path: '/a.png')]);
    final controller = _controller('img');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img'), picker: picker));
    await tester.pump();

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pumpAndSettle();
    expect((controller.valueOf('img')! as AppFile).name, 'a.png');

    picker.result = <AppFile>[fakePendingFile(name: 'b.png', path: '/b.png')];
    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pumpAndSettle();
    final v = controller.valueOf('img');
    expect(v, isA<AppFile>());
    expect((v! as AppFile).name, 'b.png', reason: 'single remplace');
  });

  testWidgets('AC8 : multiple → le pick AJOUTE, borné par maxFiles',
      (tester) async {
    final picker = FakeFilePicker(<AppFile>[
      fakePendingFile(name: 'a.png', path: '/a.png'),
      fakePendingFile(name: 'b.png', path: '/b.png'),
      fakePendingFile(name: 'c.png', path: '/c.png'),
    ]);
    final controller = _controller('imgs');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(
        controller, _imageField('imgs', multiple: true, maxFiles: 2),
        picker: picker));
    await tester.pump();

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pumpAndSettle();

    final v = controller.valueOf('imgs');
    expect(v, isA<List<AppFile>>());
    expect((v! as List).length, 2, reason: 'borné par maxFiles=2');
  });

  testWidgets(
      'AC8/M1 : dépassement maxFiles → borné + REFUS ACCESSIBLE (liveRegion), '
      'aucun fichier valide perdu, pas de crash', (tester) async {
    const msgText =
        'Maximum number of files reached; extra files were not added';
    final picker = FakeFilePicker(<AppFile>[
      fakePendingFile(name: 'a.png', path: '/a.png'),
      fakePendingFile(name: 'b.png', path: '/b.png'),
      fakePendingFile(name: 'c.png', path: '/c.png'),
    ]);
    final controller = _controller('imgs');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(
        controller, _imageField('imgs', multiple: true, maxFiles: 2),
        picker: picker));
    await tester.pump();

    // Avant acquisition : aucun message de refus (état propre).
    expect(find.text(msgText), findsNothing);

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pumpAndSettle();

    // Borne respectée : 3 sélectionnés → 2 retenus, excédent écarté.
    final v = controller.valueOf('imgs');
    expect(v, isA<List<AppFile>>());
    final files = (v! as List).cast<AppFile>();
    expect(files.length, 2, reason: 'borné par maxFiles=2');
    expect(files.map((f) => f.name).toList(), <String>['a.png', 'b.png'],
        reason: 'les fichiers valides du début sont conservés, seul l\'excès tombe');

    // Refus ACCESSIBLE : message présent + annoncé (Semantics liveRegion).
    final msg = find.text(msgText);
    expect(msg, findsOneWidget, reason: 'feedback visible de l\'excès');
    // Le message est enveloppé d'un Semantics(liveRegion: true) (annonce lecteur
    // d'écran) : aucun upload ici → c'est la seule liveRegion active.
    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.liveRegion ?? false);
    expect(liveRegions, isNotEmpty,
        reason: 'refus annoncé au lecteur d\'écran (AD-13)');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'L3 : 2 uploads concurrents + add pendant upload (complétion entrelacée) '
      '→ AUCUN fichier perdu, tous atteignent uploaded', (tester) async {
    final picker = FakeFilePicker(<AppFile>[
      fakePendingFile(name: 'a.png', path: '/a.png'),
      fakePendingFile(name: 'b.png', path: '/b.png'),
    ]);
    final storage = GatedCloudStorageRepository();
    final controller = _controller('imgs');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(
        controller, _imageField('imgs', multiple: true),
        picker: picker, storage: storage));
    await tester.pump();

    // Pick [A,B] → 2 uploads EN VOL (non résolus).
    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pump();
    await tester.pump();
    expect(storage.uploadCount, 2);
    var files = (controller.valueOf('imgs')! as List).cast<AppFile>();
    expect(files.length, 2);
    expect(
        files.every((f) => f.uploadState == ZAppFileUploadState.uploading), isTrue,
        reason: 'A et B en cours d\'upload');

    // Add C PENDANT que A et B sont encore en vol.
    picker.result = <AppFile>[fakePendingFile(name: 'c.png', path: '/c.png')];
    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pump();
    await tester.pump();
    expect(storage.uploadCount, 3);
    files = (controller.valueOf('imgs')! as List).cast<AppFile>();
    expect(files.length, 3,
        reason: 'add pendant upload n\'écrase pas les fichiers en vol');

    // Complétion ENTRELACÉE : B, puis A, puis C (ordre != acquisition).
    storage.resolve('b.png');
    await tester.pump();
    storage.resolve('a.png');
    await tester.pump();
    storage.resolve('c.png');
    await tester.pump();
    await tester.pump();

    // Chaîne read-modify-write robuste : aucun fichier perdu, états cohérents.
    files = (controller.valueOf('imgs')! as List).cast<AppFile>();
    expect(files.length, 3, reason: 'aucun fichier perdu malgré l\'entrelacement');
    expect(files.map((f) => f.name).toSet(),
        <String>{'a.png', 'b.png', 'c.png'});
    expect(
        files.every((f) => f.uploadState == ZAppFileUploadState.uploaded), isTrue,
        reason: 'chaque AppFile atteint son état final uploaded');
    expect(files.every((f) => f.remoteUrl != null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC9 : preview image uploadée → Image ; document → icône + nom',
      (tester) async {
    // Image uploadée.
    final imgController = _controller('img',
        value: const AppFile(
          name: 'p.png',
          mimeType: 'image/png',
          remoteUrl: 'https://cdn/p.png',
          uploadState: ZAppFileUploadState.uploaded,
        ));
    addTearDown(imgController.dispose);
    await tester.pumpWidget(_app(imgController, _imageField('img')));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget,
        reason: 'image uploadée → Image.network');

    // Document local pré-upload.
    final docController = _controller('doc',
        value: const AppFile(
          name: 'contract.pdf',
          mimeType: 'application/pdf',
          localPath: '/contract.pdf',
        ));
    addTearDown(docController.dispose);
    await tester.pumpWidget(_app(
        docController,
        const ZFieldSpec(
            name: 'doc', type: EditionFieldType.document, label: 'Doc')));
    await tester.pump();
    expect(find.byType(Image), findsNothing, reason: 'document → icône, pas Image');
    expect(find.text('contract.pdf'), findsWidgets);
  });

  testWidgets('AC9 : suppression retire l\'AppFile de la tranche', (tester) async {
    final controller = _controller('img',
        value: const AppFile(
          name: 'p.png',
          mimeType: 'image/png',
          localPath: '/p.png',
        ));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img')));
    await tester.pump();
    expect(controller.valueOf('img'), isA<AppFile>());

    await tester.tap(find.byTooltip('Remove file'));
    await tester.pump();
    expect(controller.valueOf('img'), isNull, reason: 'single → null après suppr');
  });

  testWidgets('AC10 : upload succès via port → uploaded + remoteUrl en tranche',
      (tester) async {
    final picker = FakeFilePicker(
        <AppFile>[fakePendingFile(name: 'ph.png', path: '/ph.png')]);
    final storage = FakeCloudStorageRepository();
    final controller = _controller('img');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img'),
        picker: picker, storage: storage));
    await tester.pump();

    await tester.tap(find.byTooltip('Pick from gallery'));
    // Séquence de pumps (évite pumpAndSettle : le spinner d'upload anime).
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final v = controller.valueOf('img');
    expect(v, isA<AppFile>());
    final f = v! as AppFile;
    expect(f.uploadState, ZAppFileUploadState.uploaded);
    expect(f.remoteUrl, isNotNull);
    expect(storage.uploadCount, 1);
  });

  testWidgets('AC10 : upload échec via port → failed + retry (réessaie)',
      (tester) async {
    final picker = FakeFilePicker(
        <AppFile>[fakePendingFile(name: 'ph.png', path: '/ph.png')]);
    final storage = FakeCloudStorageRepository(fail: true);
    final controller = _controller('img');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _imageField('img'),
        picker: picker, storage: storage));
    await tester.pump();

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect((controller.valueOf('img')! as AppFile).uploadState,
        ZAppFileUploadState.failed);
    expect(find.text('Upload failed'), findsWidgets);

    // Retry accessible → re-déclenche l'upload (échoue encore, mais uploadCount++).
    await tester.tap(find.byTooltip('Retry upload'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(storage.uploadCount, 2, reason: 'retry ré-appelle le port');
    expect(tester.takeException(), isNull);
  });
}

/// Fake `CloudStorageRepository` **contrôlable** (L3) : chaque `upload` reste EN
/// VOL jusqu'à `resolve(name)` — permet d'entrelacer des complétions concurrentes
/// dans un ordre arbitraire pour prouver la robustesse read-modify-write.
class GatedCloudStorageRepository implements CloudStorageRepository {
  final Map<String, Completer<ZResult<AppFile>>> _pending =
      <String, Completer<ZResult<AppFile>>>{};
  final Map<String, AppFile> _inFlight = <String, AppFile>{};

  /// Nombre d'appels à [upload] (oracle de concurrence).
  int uploadCount = 0;

  @override
  Future<ZResult<AppFile>> upload(AppFile file) {
    uploadCount++;
    _inFlight[file.name] = file;
    final completer = Completer<ZResult<AppFile>>();
    _pending[file.name] = completer;
    return completer.future;
  }

  /// Résout l'upload en vol de [name] par un succès (uploaded + remoteUrl).
  void resolve(String name) {
    final file = _inFlight.remove(name)!;
    _pending.remove(name)!.complete(
          Right<ZFailure, AppFile>(
            file.copyWith(
              uploadState: ZAppFileUploadState.uploaded,
              remoteUrl: 'https://cdn.example/$name',
              id: file.id ?? 'remote-$name',
            ),
          ),
        );
  }

  @override
  Future<ZResult<Unit>> delete(AppFile file) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<String>> downloadUrl(AppFile file) async =>
      file.remoteUrl != null
          ? Right<ZFailure, String>(file.remoteUrl!)
          : Left<ZFailure, String>(const ZNotFoundFailure('no remote url'));

  @override
  Stream<double> watchProgress(AppFile file) => const Stream<double>.empty();
}
