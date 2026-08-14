// Gardes de la RESSOURCE IMMUABLE SERVIE PAR UN DÉPÔT
// (`ZCrudSource.readOnlyRepository`).
//
// Ce que ces gardes mesurent :
//   (a) l'écran n'offre ni création, ni édition, ni duplication, ni bascule
//       corbeille — sous une ACL TOUT-ACCORDÉE, montée explicitement (c'est
//       elle qui distingue cette notion d'une ACL : une ACL permissive ne fait
//       rien réapparaître) ;
//   (b) `canWrite`, `supportsTrash` et `supportsPurge` valent tous `false`,
//       dépôt présent — et même dépôt `ZPurgeable` ;
//   (c) la lecture n'est PAS dégradée : listing, pagination par curseur, tri
//       demandé et recherche serveur passent tous par le dépôt ;
//   (d) aucun chemin d'écriture n'est atteignable MÊME EN FOURNISSANT un
//       `registry` — ce qui distingue une déclaration d'une omission : le
//       registre est là, le formulaire est dérivable, et l'écriture n'existe
//       toujours pas ;
//   (e) contre-témoin : `ZCrudSource.repository` nominal est inchangé ;
//   (f) les gestes PROGRAMMATIQUES (`ZCrudScreenActions`) sont inertes —
//       assertion sur l'ABSENCE d'ouverture (aucune route poussée) et sur
//       l'ABSENCE d'écriture (le dépôt ne reçoit rien), pas seulement sur
//       l'absence de bouton ;
//   (g) la consultation reste entière : la fiche s'ouvre et ne propose aucun
//       enregistrement.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

const List<Item> _seed = <Item>[
  Item(id: 'i1', name: 'alpha', qty: 1),
  Item(id: 'i2', name: 'bravo', qty: 2),
  Item(id: 'i3', name: 'charlie', qty: 3),
];

/// Dépôt en mémoire qui **enregistre les requêtes reçues** : c'est lui qui
/// prouve que la lecture continue de passer par la voie dépôt (pagination,
/// tri, recherche) alors même que l'écriture n'existe plus.
class RecordingRepo extends FakeItemRepo {
  RecordingRepo(super.seed);

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  /// Dernière requête reçue.
  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) {
    requests.add(request ?? const ZDataRequest());
    return super.getAll(request: request);
  }
}

/// Dépôt **purgeable** ET enregistreur : sert la garde (b), où la capacité de
/// purge existe côté dépôt et doit néanmoins rester close côté source.
class RecordingPurgeableRepo extends FakePurgeableItemRepo {
  RecordingPurgeableRepo(super.seed);
}

/// Compte les routes poussées — instrument de l'assertion d'**absence
/// d'ouverture** : un geste inerte ne pousse rien.
class PushCounter extends NavigatorObserver {
  /// Nombre de routes poussées depuis le montage.
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

/// Relevés de la sonde montée DANS l'écran.
class ActionsSink {
  /// Les gestes de l'écran, vus depuis un descendant.
  ZCrudScreenActions? actions;
}

/// Sonde posée en `header:` — donc descendante du scope des gestes, exactement
/// la position d'une carte métier de l'application.
class ActionsProbe extends StatelessWidget {
  const ActionsProbe({required this.sink, super.key});

  /// Réceptacle des relevés.
  final ActionsSink sink;

  @override
  Widget build(BuildContext context) {
    sink.actions = ZCrudScreenScope.maybeOf(context);
    return const SizedBox.shrink();
  }
}

/// Monte [child] avec un observateur de navigation et une ACL **explicitement
/// tout-accordée** : la garde ne vaut que si l'ACL est la plus permissive
/// possible.
Future<void> pumpObserved(
  WidgetTester tester,
  Widget child, {
  required PushCounter observer,
  ZAcl acl = const ZAllowAllAcl(),
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: <NavigatorObserver>[observer],
      home: ZcrudScope(acl: acl, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> renderedNames(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  group('(b) Capacités déclarées closes, dépôt présent', () {
    test('canWrite, supportsTrash et supportsPurge valent tous false', () {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final source = ZCrudSource<Item>.readOnlyRepository(repo);

      // Le dépôt est bien là : c'est tout l'enjeu — l'incapacité est
      // DÉCLARÉE, elle ne vient pas d'un dépôt manquant.
      expect(source.repository, same(repo));
      expect(source.canWrite, isFalse);
      expect(source.supportsTrash, isFalse);
      expect(source.supportsPurge, isFalse);
      expect(source.writeRepository, isNull);
    });

    test(
      'un dépôt PURGEABLE branché en lecture seule n\'ouvre pas la purge : la '
      'ressource prime sur ce que le dépôt saurait faire',
      () {
        final repo = RecordingPurgeableRepo(_seed);
        addTearDown(repo.dispose);

        // Contre-témoin dans le même test : le MÊME dépôt, par la fabrique
        // nominale, déclare bien les trois capacités.
        final writable = ZCrudSource<Item>.repository(repo);
        expect(writable.canWrite, isTrue);
        expect(writable.supportsTrash, isTrue);
        expect(writable.supportsPurge, isTrue);

        final readOnly = ZCrudSource<Item>.readOnlyRepository(repo);
        expect(readOnly.canWrite, isFalse);
        expect(readOnly.supportsTrash, isFalse);
        expect(readOnly.supportsPurge, isFalse);
      },
    );

    test('la voie items reste gouvernée par ses rappels (non-régression)', () {
      const withoutCallbacks = ZCrudSource<Item>.items(_seed);
      expect(withoutCallbacks.canWrite, isFalse);
      expect(withoutCallbacks.writeRepository, isNull);

      final withSave = ZCrudSource<Item>.items(
        _seed,
        onSave: (item) async {},
      );
      expect(withSave.canWrite, isTrue);
      // Aucun dépôt sur cette voie : l'écriture passe par le rappel.
      expect(withSave.writeRepository, isNull);
    });
  });

  group('(a) Aucun geste d\'écriture offert, ACL TOUT-ACCORDÉE', () {
    testWidgets(
      'ni bouton de création, ni action d\'édition, ni duplication, ni '
      'bascule corbeille — registre fourni et ACL ZAllowAllAcl explicite',
      (tester) async {
        final repo = RecordingPurgeableRepo(_seed);
        addTearDown(repo.dispose);
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Journal',
            source: ZCrudSource<Item>.readOnlyRepository(repo),
            // Le registre est PRÉSENT : le formulaire serait dérivable, et il
            // n'ouvre pourtant aucune écriture.
            registry: buildItemRegistry(),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        // Non-vacuité : l'écran a bien rendu ses lignes (l'absence de gestes
        // n'est pas l'absence d'écran).
        expect(renderedNames(tester), <String>['alpha', 'bravo', 'charlie']);

        expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.copy_outlined), findsNothing);
        expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        expect(find.byIcon(Icons.delete_forever), findsNothing);
        expect(find.byIcon(Icons.restore_from_trash), findsNothing);
      },
    );

    testWidgets(
      'la sélection multiple n\'ouvre aucune action de masse d\'écriture',
      (tester) async {
        final repo = RecordingPurgeableRepo(_seed);
        addTearDown(repo.dispose);
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Journal',
            source: ZCrudSource<Item>.readOnlyRepository(repo),
            registry: buildItemRegistry(),
            selection: const ZSelectionPolicy(),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        final boxes = find.byType(Checkbox);
        expect(boxes, findsWidgets, reason: 'la sélection reste offerte');
        await tester.tap(boxes.first);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsNothing);
        expect(find.byIcon(Icons.delete_forever), findsNothing);
        expect(find.byIcon(Icons.restore_from_trash), findsNothing);
        expect(repo.softDeleted, isEmpty);
        expect(repo.purged, isEmpty);
      },
    );
  });

  group('(d)(f) Aucun chemin d\'écriture, registre fourni', () {
    testWidgets(
      'les gestes programmatiques sont INERTES : aucune route poussée, '
      'aucune écriture reçue par le dépôt',
      (tester) async {
        final repo = RecordingPurgeableRepo(_seed);
        addTearDown(repo.dispose);
        final sink = ActionsSink();
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Journal',
            source: ZCrudSource<Item>.readOnlyRepository(repo),
            // Registre PRÉSENT, schéma de formulaire dérivable : rien ne
            // manque « par accident ».
            registry: buildItemRegistry(),
            header: ActionsProbe(sink: sink),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        final actions = sink.actions;
        expect(actions, isNotNull, reason: 'la sonde voit bien les gestes');

        const entity = Item(id: 'i1', name: 'alpha', qty: 1);
        expect(actions!.canOpenCreation, isFalse);
        expect(actions.canOpenUpdate(entity), isFalse);
        expect(actions.canOpenEdition(entity), isFalse);
        expect(actions.creationOpener(), isNull);
        expect(actions.updateOpener(entity), isNull);
        expect(actions.editionOpener(entity), isNull);

        final pushesBefore = observer.pushes;
        // `unawaited` : le `Future` d'une ouverture ne se complète qu'à la
        // FERMETURE de la surface. L'attendre ferait DÉPENDRE la garde du
        // refus qu'elle mesure — une régression qui ouvrirait la surface
        // ferait pendre le test au lieu de le faire rougir.
        unawaited(actions.openCreation());
        await tester.pumpAndSettle();
        unawaited(actions.openUpdate(entity));
        await tester.pumpAndSettle();
        unawaited(actions.openEdition(entity));
        await tester.pumpAndSettle();

        // ABSENCE D'OUVERTURE, pas seulement absence de bouton.
        expect(
          observer.pushes,
          pushesBefore,
          reason: 'aucun formulaire n\'a été poussé',
        );
        expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
        expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);

        // ABSENCE D'ÉCRITURE : le dépôt n'a rien reçu.
        expect(repo.saved, isEmpty);
        expect(repo.softDeleted, isEmpty);
        expect(repo.restored, isEmpty);
        expect(repo.purged, isEmpty);
      },
    );

    testWidgets(
      '(g) la consultation reste entière : la fiche s\'ouvre et n\'offre '
      'aucun enregistrement',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        final sink = ActionsSink();
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Journal',
            source: ZCrudSource<Item>.readOnlyRepository(repo),
            registry: buildItemRegistry(),
            detailsEnabled: true,
            header: ActionsProbe(sink: sink),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        const entity = Item(id: 'i1', name: 'alpha', qty: 1);
        expect(sink.actions!.canOpenDetails(entity), isTrue);
        // `unawaited` : la fiche s'ouvre RÉELLEMENT ici, et son `Future` ne se
        // complète qu'à sa fermeture.
        unawaited(sink.actions!.openDetails(entity));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('zCrudFormTitle')), findsOneWidget);
        // Consultation : fermeture seulement, jamais d'enregistrement.
        expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);
        expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
        expect(repo.saved, isEmpty);

        // Refermer la surface : le test rend la main sur un arbre au repos.
        await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
        await tester.pumpAndSettle();
      },
    );
  });

  group('(c) La lecture n\'est pas dégradée', () {
    testWidgets(
      'listing, pagination par curseur, tri demandé et recherche passent tous '
      'par le dépôt',
      (tester) async {
        final repo = RecordingRepo(_seed);
        addTearDown(repo.dispose);
        final sink = ActionsSink();
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Journal',
            source: ZCrudSource<Item>.readOnlyRepository(repo),
            registry: buildItemRegistry(),
            query: const ZListQueryPolicy(pageSize: 25),
            header: ActionsProbe(sink: sink),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        // Listing servi par le dépôt, pagination déclarée honorée.
        expect(repo.requests, isNotEmpty);
        expect(repo.requests.first.limit, 25);
        expect(renderedNames(tester), <String>['alpha', 'bravo', 'charlie']);

        // Tri demandé.
        sink.actions!.sortBy(<ZSort>[const ZSort('qty', ZSortDirection.desc)]);
        await tester.pumpAndSettle();
        expect(
          repo.last.sorts,
          <ZSort>[const ZSort('qty', ZSortDirection.desc)],
        );
        expect(renderedNames(tester), <String>['charlie', 'bravo', 'alpha']);

        // Recherche serveur : le terme part dans la requête et la liste se
        // réduit.
        await searchInAppBar(tester, 'brav');
        expect(repo.last.search, 'brav');
        expect(renderedNames(tester), <String>['bravo']);
      },
    );
  });

  group('(e) Contre-témoin : la voie repository nominale est inchangée', () {
    testWidgets(
      'le MÊME dépôt, par la fabrique nominale, offre création, édition, '
      'duplication et corbeille',
      (tester) async {
        final repo = RecordingPurgeableRepo(_seed);
        addTearDown(repo.dispose);
        final sink = ActionsSink();
        final observer = PushCounter();
        await pumpObserved(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            header: ActionsProbe(sink: sink),
          ),
          observer: observer,
          acl: const ZAllowAllAcl(),
        );

        expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsWidgets);
        expect(find.byIcon(Icons.copy_outlined), findsWidgets);
        expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);

        const entity = Item(id: 'i1', name: 'alpha', qty: 1);
        expect(sink.actions!.canOpenCreation, isTrue);
        expect(sink.actions!.canOpenUpdate(entity), isTrue);

        // L'écriture aboutit RÉELLEMENT : la mise à la corbeille atteint le
        // dépôt (ce que la voie en lecture seule interdit).
        await softDeleteFirstRow(tester);
        expect(repo.softDeleted, <String>['i1']);
      },
    );
  });
}
