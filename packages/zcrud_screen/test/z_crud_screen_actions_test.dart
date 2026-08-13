// Gardes du SEAM D'ÉDITION public (CR DODLP « retour de pilote », point 3) :
// une carte métier descendante d'un `ZCrudScreen` ouvre le cycle d'édition DE
// L'ÉCRAN — même politique de présentation, même poids de formulaire, même
// voie de sauvegarde, mêmes titres — au lieu du court-circuit qu'un rappel
// capturé par fermeture produirait. Et elle sait, AVANT de rendre, si le geste
// est possible.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart'
    show ZEditionPresentation, ZFormWeight, ZPresentationPolicy;
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Politique de présentation qui **enregistre chaque consultation**.
///
/// Elle est l'instrument de mesure du « même chemin » : une ouverture qui
/// court-circuiterait `presentEdition` ne la consulterait pas du tout, et une
/// ouverture qui reconstruirait sa propre politique la consulterait avec un
/// autre poids de formulaire.
class RecordingPolicy extends ZPresentationPolicy {
  RecordingPolicy();

  /// Un couple `(classe de fenêtre, poids de formulaire)` par consultation.
  final List<(Object?, ZFormWeight)> calls = <(Object?, ZFormWeight)>[];

  /// Le mode résolu à chaque consultation.
  final List<ZEditionPresentation> resolved = <ZEditionPresentation>[];

  @override
  ZEditionPresentation resolve(
    // `dynamic` : `ZWindowSizeClass` vit dans `zcrud_responsive`, atteint
    // seulement TRANSITIVEMENT par ce paquet — le nommer ici ajouterait une
    // dépendance non déclarée.
    dynamic sizeClass, {
    ZFormWeight formWeight = ZFormWeight.light,
  }) {
    calls.add((sizeClass as Object?, formWeight));
    // Mode CONSTANT : le discriminant de la garde est le couple ENREGISTRÉ
    // (classe de fenêtre, poids de formulaire), pas le mode rendu — une
    // ouverture qui reconstruirait sa propre politique ne serait pas
    // enregistrée du tout, et une qui retomberait sur le poids par défaut
    // enregistrerait `light`.
    const mode = ZEditionPresentation.dialog;
    resolved.add(mode);
    return mode;
  }
}

/// Compte les routes poussées — sert les assertions d'**absence d'ouverture**
/// (une surface refusée ne doit pas seulement être invisible : elle ne doit
/// pas exister).
class PushCounter extends NavigatorObserver {
  /// Nombre de routes poussées depuis le montage.
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

/// Sonde montée DANS l'écran (via `header:`), donc descendante du scope des
/// gestes — exactement la position d'une carte métier.
///
/// Elle relève à chaque rendu la capacité et le rappel obtenus, et donne au
/// test la poignée sur les gestes de l'écran.
class ProbeCard extends StatelessWidget {
  const ProbeCard({required this.entity, required this.sink, super.key});

  /// L'entité dont la sonde demande l'ouverture.
  final ZEntity entity;

  /// Réceptacle des relevés.
  final ProbeSink sink;

  @override
  Widget build(BuildContext context) {
    final actions = ZCrudScreenScope.maybeOf(context);
    final opener = zCrudEditionOpener(context, entity);
    sink
      ..actions = actions
      ..opener = opener
      ..canOpenEdition = actions?.canOpenEdition(entity)
      ..canOpenUpdate = actions?.canOpenUpdate(entity)
      ..canOpenCreation = actions?.canOpenCreation;
    return TextButton(
      key: const ValueKey('probeOpen'),
      onPressed: opener,
      child: const Text('sonde'),
    );
  }
}

/// Relevés de la [ProbeCard].
class ProbeSink {
  /// Les gestes vus par la sonde (`null` hors écran).
  ZCrudScreenActions? actions;

  /// Le rappel d'ouverture nominale (`null` = geste refusé).
  ZCrudOpener? opener;

  /// Capacité d'ouverture nominale relevée.
  bool? canOpenEdition;

  /// Capacité d'édition explicite relevée.
  bool? canOpenUpdate;

  /// Capacité de création relevée.
  bool? canOpenCreation;
}

/// Monte [child] avec un observateur de navigation (le fixture partagé n'en
/// prend pas), fenêtre large — mêmes conditions que `pumpScreen`.
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

String openedTitle(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('zCrudFormTitle')))
    .data!;

void main() {
  testWidgets(
      'garde (a) — maybeOf HORS écran rend null, et la fonction de commodité '
      'ne lève pas', (tester) async {
    final sink = ProbeSink();
    await tester.pumpWidget(
      MaterialApp(
        home: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha'),
          sink: sink,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ce qu'une exception de BUILD produit réellement : le framework la
    // consigne, elle ne remonte pas par un `try` posé autour de la
    // CONSTRUCTION du widget (qui ne construit rien). C'est donc
    // `takeException` — et lui seul — qui mesure « ne lève pas ».
    expect(tester.takeException(), isNull);
    expect(sink.actions, isNull);
    expect(sink.opener, isNull);
    // Non-vacuité : la sonde a bien été rendue (le relevé vient d'un build
    // réel, pas d'un widget jamais monté).
    expect(find.byKey(const ValueKey('probeOpen')), findsOneWidget);
  });

  testWidgets(
      'garde (b) — la surface ouverte par la carte est IDENTIQUE à celle de '
      'l\'action de ligne et du bouton « + » : même politique consultée, même '
      'poids de formulaire, même mode résolu, même titre', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final policy = RecordingPolicy();
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        policy: policy,
        // Poids NON par défaut : une ouverture qui reconstruirait sa propre
        // politique retomberait sur `light`, donc sur un autre mode.
        formWeight: ZFormWeight.heavy,
        titles: const ZCrudTitles(create: 'Créer', update: 'Modifier'),
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
    );

    final titleFinder = find.byKey(const ValueKey('zCrudFormTitle'));

    // 1. Le chemin de l'action de ligne.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(titleFinder, findsOneWidget);
    expect(policy.calls, hasLength(1));
    final rowCall = policy.calls.last;
    final rowMode = policy.resolved.last;
    final rowTitle = openedTitle(tester);
    await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
    await tester.pumpAndSettle();

    // 2. Le chemin du bouton « + ».
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();
    expect(titleFinder, findsOneWidget);
    expect(policy.calls, hasLength(2));
    final createCall = policy.calls.last;
    final createMode = policy.resolved.last;
    final createTitle = openedTitle(tester);
    await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
    await tester.pumpAndSettle();

    // 3. Le chemin de la carte.
    await tester.tap(find.byKey(const ValueKey('probeOpen')));
    await tester.pumpAndSettle();
    // La politique DÉCLARÉE a été consultée une TROISIÈME fois. Un
    // court-circuit — un rappel qui présenterait la surface lui-même — ne
    // l'aurait pas consultée, et ce compte serait resté à 2.
    expect(policy.calls, hasLength(3));
    expect(titleFinder, findsOneWidget);
    final cardCall = policy.calls.last;
    final cardMode = policy.resolved.last;
    final cardTitle = openedTitle(tester);

    // Même entrée : classe de fenêtre ET poids de formulaire de l'écran.
    // Non-vacuité : `heavy` n'est pas le défaut — une ouverture qui
    // reconstruirait sa politique enregistrerait `light`.
    expect(cardCall, rowCall);
    expect(cardCall, createCall);
    expect(cardCall.$2, ZFormWeight.heavy);
    // Même mode résolu, donc même surface.
    expect(cardMode, rowMode);
    expect(cardMode, createMode);
    // Même titre que l'action de ligne, et bien le titre d'ÉDITION (pas celui
    // de la création).
    expect(cardTitle, rowTitle);
    expect(cardTitle, 'Modifier');
    expect(createTitle, 'Créer');
    repo.dispose();
  });

  testWidgets(
      'garde (c) — c\'est l\'onSave DE L\'ÉCRAN qui persiste ce que la carte a '
      'ouvert (le court-circuit n\'existe plus)', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final saved = <Item>[];
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        onSave: (item) async => saved.add(item),
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
    );

    await tester.tap(find.byKey(const ValueKey('probeOpen')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DynamicEdition),
        matching: find.widgetWithText(TextField, 'Alpha'),
      ),
      'Alpha (carte)',
    );
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    // La voie de sauvegarde DÉCLARÉE sur l'écran a reçu l'entité éditée…
    expect(saved, hasLength(1));
    expect(saved.single.id, 'i1');
    expect(saved.single.name, 'Alpha (carte)');
    expect(saved.single.qty, 3);
    // …et elle a bien PRIMÉ sur le dépôt (preuve que la chaîne complète de
    // l'écran a été empruntée, et non une écriture directe).
    expect(repo.saved, isEmpty);
    repo.dispose();
  });

  testWidgets(
      'garde (d) — permission update refusée : capacité FALSE, rappel null, '
      'et AUCUNE route poussée si l\'ouverture est tout de même demandée',
      (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
      acl: const DenyAcl(<ZCrudAction>{ZCrudAction.update}),
    );

    // La carte peut décider AVANT de rendre : ne pas dessiner son bouton.
    expect(sink.actions, isNotNull);
    expect(sink.canOpenEdition, isFalse);
    expect(sink.canOpenUpdate, isFalse);
    expect(sink.opener, isNull);

    // Et l'ouverture demandée malgré tout est INERTE : aucune route poussée.
    // `unawaited` : si le refus cessait d'être tenu, une surface s'ouvrirait et
    // son `Future` ne se complèterait qu'à la fermeture — l'attendre ferait
    // PENDRE le test au lieu de le faire rougir sur le compte de routes.
    final before = observer.pushes;
    unawaited(sink.actions!.openEdition(const Item(id: 'i1', name: 'Alpha')));
    unawaited(sink.actions!.openUpdate(const Item(id: 'i1', name: 'Alpha')));
    await tester.pumpAndSettle();
    expect(observer.pushes, before);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (e) — ZScreenMode.locked : capacité FALSE et ouverture inerte, '
      'quelle que soit l\'ACL', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.locked,
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
    );

    expect(sink.canOpenEdition, isFalse);
    expect(sink.canOpenUpdate, isFalse);
    expect(sink.canOpenCreation, isFalse);
    expect(sink.opener, isNull);

    final before = observer.pushes;
    unawaited(sink.actions!.openEdition(const Item(id: 'i1', name: 'Alpha')));
    unawaited(sink.actions!.openCreation());
    await tester.pumpAndSettle();
    expect(observer.pushes, before);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (f) — contre-témoin : le bouton « + » et les actions de ligne '
      'gardent leur comportement, scope posé ou non', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        titles: const ZCrudTitles(
          create: 'Créer',
          copy: 'Copier',
          update: 'Modifier',
        ),
      ),
      observer: observer,
    );

    Future<String> openAndClose(Finder trigger) async {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final title = openedTitle(tester);
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();
      return title;
    }

    expect(await openAndClose(find.byKey(const ValueKey('zCrudCreate'))),
        'Créer');
    expect(await openAndClose(find.byIcon(Icons.edit_outlined).first),
        'Modifier');
    expect(await openAndClose(find.byIcon(Icons.copy_outlined).first),
        'Copier');
    // La tuile générique du paquet reste celle rendue (aucune enveloppe).
    expect(find.byKey(const ValueKey('zCrudTile_i1')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'mode details — l\'ouverture nominale produit la FICHE en lecture seule ; '
      'le retour vers l\'édition suit acl.update', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
    );

    // Capacités : consultation ET retour vers l'édition (update autorisé).
    expect(sink.canOpenEdition, isTrue);
    expect(sink.canOpenUpdate, isTrue);

    await tester.tap(find.byKey(const ValueKey('probeOpen')));
    await tester.pumpAndSettle();
    // Fiche : pied de FERMETURE, aucun enregistrement, et le drapeau de
    // lecture atteint bien la surface (brique livrée avec le mode « détails »).
    expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
    final scopeContext = tester.element(find.byType(DynamicEdition));
    expect(ZCrudEditionScope.readOnlyOf(scopeContext), isTrue);
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();

    // Le retour vers l'édition ouvre, lui, le formulaire ÉDITABLE.
    // `unawaited` : le Future d'une ouverture ne se complète qu'à la
    // FERMETURE de la surface — l'attendre ici bloquerait le test.
    unawaited(
      sink.actions!.openUpdate(const Item(id: 'i1', name: 'Alpha', qty: 3)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'mode details — acl.update refusé : la fiche reste ouvrable, le retour '
      'vers l\'édition non', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)],
    );
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha', qty: 3),
          sink: sink,
        ),
      ),
      observer: observer,
      acl: const DenyAcl(<ZCrudAction>{ZCrudAction.update}),
    );

    expect(sink.canOpenEdition, isTrue);
    expect(sink.canOpenUpdate, isFalse);

    final before = observer.pushes;
    unawaited(sink.actions!.openUpdate(const Item(id: 'i1', name: 'Alpha')));
    await tester.pumpAndSettle();
    expect(observer.pushes, before);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'création : la carte ouvre le MÊME geste que le bouton « + » ; refusée, '
      'la capacité est false et l\'ouverture inerte', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        titles: const ZCrudTitles(create: 'Créer'),
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha'),
          sink: sink,
        ),
      ),
      observer: observer,
    );
    expect(sink.canOpenCreation, isTrue);
    unawaited(sink.actions!.openCreation());
    await tester.pumpAndSettle();
    expect(openedTitle(tester), 'Créer');
    await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
    await tester.pumpAndSettle();

    // Déclaration `canCreate: false` : ni bouton « + », ni geste exposé.
    final sink2 = ProbeSink();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        canCreate: false,
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha'),
          sink: sink2,
        ),
      ),
      observer: observer,
    );
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(sink2.canOpenCreation, isFalse);
    final before = observer.pushes;
    unawaited(sink2.actions!.openCreation());
    await tester.pumpAndSettle();
    expect(observer.pushes, before);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'entité d\'un AUTRE type que celui de l\'écran : refus, jamais '
      'd\'exception (AD-10)', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final sink = ProbeSink();
    final observer = PushCounter();
    await pumpObserved(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        header: ProbeCard(
          entity: const Item(id: 'i1', name: 'Alpha'),
          sink: sink,
        ),
      ),
      observer: observer,
    );
    const other = _OtherEntity(id: 'x1');
    expect(sink.actions!.canOpenEdition(other), isFalse);
    expect(sink.actions!.editionOpener(other), isNull);
    final before = observer.pushes;
    unawaited(sink.actions!.openEdition(other));
    await tester.pumpAndSettle();
    expect(observer.pushes, before);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsNothing);
    repo.dispose();
  });
}

/// Entité étrangère à l'écran — sert la garde de repli typé.
class _OtherEntity extends ZEntity {
  const _OtherEntity({this.id});

  @override
  final String? id;
}
