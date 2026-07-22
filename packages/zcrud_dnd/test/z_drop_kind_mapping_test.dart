/// Banc des règles STRUCTURANTES du contrat `ZDropRegionRenderer`.
///
/// Ces tests s'exécutent **sans engine natif** : c'est tout l'intérêt d'avoir
/// sorti les règles du widget. Ils exercent réellement le code de production
/// (`zBuildDroppedItems`), pas une reformulation de celui-ci.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_dnd/zcrud_dnd.dart';

/// Double de test de [ZDropItemSource] — compte les lectures, sait échouer.
class _FakeSource extends ZDropItemSource {
  _FakeSource({
    this.formats = const <String>[],
    this.name,
    this.textValue,
    this.bytes,
    this.throwOnFormats = false,
    this.throwOnName = false,
    this.throwOnText = false,
    this.bytesError,
  });

  final List<String> formats;
  final String? name;
  final String? textValue;
  final Uint8List? bytes;
  final bool throwOnFormats;
  final bool throwOnName;
  final bool throwOnText;
  final Object? bytesError;

  int readBytesCalls = 0;
  int readTextCalls = 0;
  int readNameCalls = 0;

  @override
  List<String> get platformFormats {
    if (throwOnFormats) throw StateError('session déjà libérée');
    return formats;
  }

  @override
  Future<String?> readSuggestedName() async {
    readNameCalls++;
    if (throwOnName) throw StateError('nom illisible');
    return name;
  }

  @override
  Future<String?> readText() async {
    readTextCalls++;
    if (throwOnText) throw StateError('texte illisible');
    return textValue;
  }

  @override
  Future<Uint8List> readBytes() async {
    readBytesCalls++;
    final Object? error = bytesError;
    if (error != null) throw error;
    return bytes ?? Uint8List(0);
  }
}

const Set<ZDropKind> _all = <ZDropKind>{
  ZDropKind.file,
  ZDropKind.image,
  ZDropKind.uri,
  ZDropKind.text,
  ZDropKind.unknown,
};

void main() {
  group('zCandidateDropKinds — traduction des formats natifs', () {
    test('type MIME image et UTI image donnent ZDropKind.image', () {
      expect(
        zCandidateDropKinds(const <String>['image/png']),
        const <ZDropKind>{ZDropKind.image},
      );
      expect(
        zCandidateDropKinds(const <String>['public.jpeg']),
        const <ZDropKind>{ZDropKind.image},
      );
      // Nom de format Windows (super_clipboard: `windowsFormats: ['PNG']`).
      expect(
        zCandidateDropKinds(const <String>['PNG']),
        const <ZDropKind>{ZDropKind.image},
      );
      // CF_TIFF interne (`NativeShell_CF_6`).
      expect(
        zCandidateDropKinds(const <String>['NativeShell_CF_6']),
        const <ZDropKind>{ZDropKind.image},
      );
    });

    test('poignées de fichier (public.file-url, CF_HDROP) donnent file', () {
      expect(
        zCandidateDropKinds(const <String>['public.file-url']),
        const <ZDropKind>{ZDropKind.file},
      );
      expect(
        zCandidateDropKinds(const <String>['NativeShell_CF_15']),
        const <ZDropKind>{ZDropKind.file},
      );
    });

    test('texte brut et HTML donnent text (y compris CF_UNICODETEXT)', () {
      expect(
        zCandidateDropKinds(const <String>['text/plain']),
        const <ZDropKind>{ZDropKind.text},
      );
      expect(
        zCandidateDropKinds(const <String>['public.utf8-plain-text']),
        const <ZDropKind>{ZDropKind.text},
      );
      expect(
        zCandidateDropKinds(const <String>['NativeShell_CF_13']),
        const <ZDropKind>{ZDropKind.text},
      );
      expect(
        zCandidateDropKinds(const <String>['text/html']),
        const <ZDropKind>{ZDropKind.text},
      );
    });

    test('adresses donnent uri', () {
      expect(
        zCandidateDropKinds(const <String>['public.url']),
        const <ZDropKind>{ZDropKind.uri},
      );
      expect(
        zCandidateDropKinds(const <String>['UniformResourceLocatorW']),
        const <ZDropKind>{ZDropKind.uri},
      );
    });

    test('text/uri-list reste AMBIGU : file ET uri sont candidats', () {
      // Sur Linux/Android/web c'est le format de repli commun à `fileUri` et
      // `uri` : trancher ici ferait rater l'un des deux usages.
      expect(
        zCandidateDropKinds(const <String>['text/uri-list']),
        const <ZDropKind>{ZDropKind.file, ZDropKind.uri},
      );
    });

    test('autre type MIME ou UTI de contenu = fichier', () {
      expect(
        zCandidateDropKinds(const <String>['application/pdf']),
        const <ZDropKind>{ZDropKind.file},
      );
      expect(
        zCandidateDropKinds(const <String>['video/mp4']),
        const <ZDropKind>{ZDropKind.file},
      );
      expect(
        zCandidateDropKinds(const <String>['com.adobe.pdf']),
        const <ZDropKind>{ZDropKind.file},
      );
    });

    test('format non reconnu ou liste vide = unknown, jamais un throw', () {
      expect(
        zCandidateDropKinds(const <String>['%%pas-un-format%%']),
        const <ZDropKind>{ZDropKind.unknown},
      );
      expect(
        zCandidateDropKinds(const <String>[]),
        const <ZDropKind>{ZDropKind.unknown},
      );
      expect(
        zCandidateDropKinds(const <String>['   ']),
        const <ZDropKind>{ZDropKind.unknown},
      );
    });

    test('unknown est écarté dès qu une nature est reconnue', () {
      expect(
        zCandidateDropKinds(const <String>['%%bruit%%', 'application/pdf']),
        const <ZDropKind>{ZDropKind.file},
      );
    });

    test('un .png de l explorateur est candidat file ET image', () {
      expect(
        zCandidateDropKinds(const <String>['public.file-url', 'public.png']),
        const <ZDropKind>{ZDropKind.file, ZDropKind.image},
      );
    });
  });

  group('zSelectDropKind — priorité et filtrage par accepts', () {
    test('file l emporte sur image quand les deux sont acceptés', () {
      expect(
        zSelectDropKind(
          const <ZDropKind>{ZDropKind.file, ZDropKind.image},
          const <ZDropKind>{ZDropKind.file, ZDropKind.image},
        ),
        ZDropKind.file,
      );
    });

    test('accepts restreint bascule sur la nature acceptée', () {
      expect(
        zSelectDropKind(
          const <ZDropKind>{ZDropKind.file, ZDropKind.image},
          const <ZDropKind>{ZDropKind.image},
        ),
        ZDropKind.image,
      );
    });

    test('aucune intersection => null (élément ignoré, jamais une erreur)', () {
      expect(
        zSelectDropKind(
          const <ZDropKind>{ZDropKind.text},
          const <ZDropKind>{ZDropKind.file},
        ),
        isNull,
      );
    });

    test('unknown n est retenu que s il est explicitement accepté', () {
      expect(
        zSelectDropKind(
          const <ZDropKind>{ZDropKind.unknown},
          const <ZDropKind>{ZDropKind.file},
        ),
        isNull,
      );
      expect(
        zSelectDropKind(
          const <ZDropKind>{ZDropKind.unknown},
          const <ZDropKind>{ZDropKind.file, ZDropKind.unknown},
        ),
        ZDropKind.unknown,
      );
    });

    test('kZDropKindPriority couvre toutes les natures du port', () {
      expect(kZDropKindPriority.toSet(), ZDropKind.values.toSet());
    });
  });

  group('zMimeTypeForFormats', () {
    test('remonte le premier vrai type MIME', () {
      expect(
        zMimeTypeForFormats(const <String>['public.png', 'image/png']),
        'image/png',
      );
    });

    test('un UTI ou un format Windows n est PAS un type MIME => null', () {
      expect(
        zMimeTypeForFormats(const <String>['public.png', 'NativeShell_CF_15']),
        isNull,
      );
    });
  });

  group('zBuildDroppedItems — contrat 2 : filtrage par accepts', () {
    test('un élément hors accepts est ignoré, sans erreur', () async {
      final _FakeSource texte = _FakeSource(
        formats: const <String>['text/plain'],
        textValue: 'bonjour',
      );

      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[texte],
        const <ZDropKind>{ZDropKind.file},
      );

      expect(items, isEmpty);
      // Garde MORDANTE : si le filtrage sautait, on lirait aussi le contenu.
      expect(texte.readTextCalls, 0);
      expect(texte.readNameCalls, 0);
    });

    test('seuls les éléments acceptés survivent dans un lot mixte', () async {
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[
          _FakeSource(formats: const <String>['text/plain'], textValue: 'a'),
          _FakeSource(formats: const <String>['application/pdf'], name: 'a.pdf'),
          _FakeSource(formats: const <String>['public.url'], textValue: 'u'),
        ],
        const <ZDropKind>{ZDropKind.file},
      );

      expect(items, hasLength(1));
      expect(items.single.kind, ZDropKind.file);
      expect(items.single.name, 'a.pdf');
    });

    test('toute nature remontée appartient à accepts', () async {
      const Set<ZDropKind> accepts = <ZDropKind>{
        ZDropKind.image,
        ZDropKind.text,
      };
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[
          _FakeSource(formats: const <String>['public.file-url', 'public.png']),
          _FakeSource(formats: const <String>['text/plain'], textValue: 'x'),
          _FakeSource(formats: const <String>['application/zip']),
          _FakeSource(formats: const <String>['%%bruit%%']),
        ],
        accepts,
      );

      expect(items.map((ZDroppedItem i) => i.kind), <ZDropKind>[
        ZDropKind.image,
        ZDropKind.text,
      ]);
      for (final ZDroppedItem item in items) {
        expect(accepts.contains(item.kind), isTrue);
      }
    });
  });

  group('zBuildDroppedItems — contrat 3 / AD-10 : rien ne lève', () {
    test('des formats illisibles dégradent en unknown sans lever', () async {
      final _FakeSource corrompu = _FakeSource(throwOnFormats: true);

      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[corrompu],
        _all,
      );

      expect(items, hasLength(1));
      expect(items.single.kind, ZDropKind.unknown);
    });

    test('formats illisibles + accepts restreint => ignoré, sans lever',
        () async {
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[_FakeSource(throwOnFormats: true)],
        const <ZDropKind>{ZDropKind.file},
      );
      expect(items, isEmpty);
    });

    test('un nom et un texte illisibles deviennent null, item conservé',
        () async {
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[
          _FakeSource(
            formats: const <String>['text/plain'],
            throwOnName: true,
            throwOnText: true,
          ),
        ],
        _all,
      );

      expect(items, hasLength(1));
      expect(items.single.kind, ZDropKind.text);
      expect(items.single.name, isNull);
      expect(items.single.text, isNull);
    });

    test('un lot entièrement corrompu ne fait pas échouer les autres',
        () async {
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[
          _FakeSource(throwOnFormats: true),
          _FakeSource(formats: const <String>['application/pdf'], name: 'ok'),
        ],
        const <ZDropKind>{ZDropKind.file},
      );

      expect(items, hasLength(1));
      expect(items.single.name, 'ok');
    });
  });

  group('zBuildDroppedItems — contrat 4 : readBytes est PARESSEUX', () {
    test('aucun octet matérialisé au moment du dépôt', () async {
      final _FakeSource source = _FakeSource(
        formats: const <String>['application/pdf'],
        name: 'gros.pdf',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[source],
        const <ZDropKind>{ZDropKind.file},
      );

      expect(items, hasLength(1));
      expect(items.single.readBytes, isNotNull);
      // LE point du contrat : la fonction est câblée, pas appelée.
      expect(source.readBytesCalls, 0);

      // Laisser tourner la boucle d'événements ne doit rien déclencher non
      // plus (pas de lecture différée « en douce »).
      await Future<void>.delayed(Duration.zero);
      expect(source.readBytesCalls, 0);
    });

    test('le contenu n arrive que sur demande explicite de l hôte', () async {
      final _FakeSource source = _FakeSource(
        formats: const <String>['application/pdf'],
        bytes: Uint8List.fromList(<int>[7, 8, 9]),
      );

      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[source],
        const <ZDropKind>{ZDropKind.file},
      );
      expect(source.readBytesCalls, 0);

      final Uint8List data = await items.single.readBytes!();

      expect(data, <int>[7, 8, 9]);
      expect(source.readBytesCalls, 1);
    });

    test('un échec de lecture est normalisé en ZDropReadFailure', () async {
      final _FakeSource source = _FakeSource(
        formats: const <String>['application/pdf'],
        bytesError: StateError('fichier virtuel annulé'),
      );

      final List<ZDroppedItem> items = await zBuildDroppedItems(
        <ZDropItemSource>[source],
        const <ZDropKind>{ZDropKind.file},
      );

      // L'échec est porté par la FUTURE, pas par le traitement du dépôt.
      await expectLater(
        items.single.readBytes!(),
        throwsA(isA<ZDropReadFailure>()),
      );
    });
  });
}
