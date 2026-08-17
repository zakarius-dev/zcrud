// Gardes du SEAM DE PERSISTANCE DES ONGLETS (CR DODLP « l'onglet actif et sa
// position de défilement ne survivent pas à la fermeture », 2026-08-17).
//
// Le CR demande un seam, pas une implémentation : zcrud n'a pas à connaître le
// stockage. Le port `ZListTabsStore` suit le patron `ZSectionCollapseStore` /
// `ZStepIndexStore` (abstract + const, load/save, portée opaque, variante
// mémoire).
//
// 🔴 DEUX choses sont persistées, pas une : l'index de l'onglet ET le
// défilement DE CHAQUE ONGLET. C'est la moitié qu'on oublie en lisant
// « persistance d'onglet », et c'est celle que les gardes (b) et (c) tiennent.
//
// Le store est un ESPION : la garde (e) affirme une **absence d'appel**, pas
// une absence d'effet visible — un socle qui lirait le store sans en tenir
// compte passerait la seconde et échouerait la première.
//
// Ce que ces gardes tiennent, dans l'ordre :
//   (a) l'onglet actif est RESTAURÉ après reconstruction complète de l'arbre ;
//   (b) 🔴 le défilement est mémorisé et restauré PAR ONGLET — deux onglets,
//       deux offsets distincts, aucun mélange ;
//   (c) 🔴 l'écriture est PAR EMPLACEMENT : mémoriser l'offset d'un onglet
//       n'efface ni l'index, ni l'offset du voisin ;
//   (d) AD-10 — lecture tolérante : index absent ⇒ premier onglet, index HORS
//       BORNES ⇒ premier onglet, offsets absents ⇒ zéros, store qui LÈVE ⇒
//       traité comme absent ;
//   (e) 🔴 CONTRE-TÉMOIN — sans store déclaré : aucune lecture, aucune
//       écriture, et pas un widget de plus dans l'arbre ;
//   (f) la clé de portée est dérivée de l'identité de l'écran ET du jeu
//       d'onglets : deux écrans ne se marchent pas dessus, et un changement de
//       jeu d'onglets invalide naturellement l'ancienne préférence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Assez d'éléments pour que chaque onglet DÉBORDE de sa fenêtre : sans
/// défilement possible, une garde d'offset ne mesurerait rien.
List<Item> _seed() => <Item>[
      for (var i = 0; i < 60; i++)
        Item(id: 'i$i', name: 'Item $i', qty: i.isEven ? 1 : 2),
    ];

const List<ZListTab> _tabs = <ZListTab>[
  ZListTab(
    labelKey: 'Un',
    baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)],
  ),
  ZListTab(
    labelKey: 'Deux',
    baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 2)],
  ),
];

/// Store ESPION : persiste réellement (pour les gardes de survie) **et**
/// journalise chaque appel avec sa portée (pour la garde d'absence et celle
/// d'isolation des portées).
class _StoreEspion extends ZListTabsStore {
  _StoreEspion();

  final Map<String, int> _index = <String, int>{};
  final Map<String, Map<int, double>> _offsets = <String, Map<int, double>>{};

  /// Portées passées en LECTURE, dans l'ordre.
  final List<String> lectures = <String>[];

  /// Portées passées en ÉCRITURE, dans l'ordre.
  final List<String> ecritures = <String>[];

  int get appels => lectures.length + ecritures.length;

  /// Portées vues, tous sens confondus.
  Set<String> get portees => <String>{...lectures, ...ecritures};

  int? indexDe(String scopeKey) => _index[scopeKey];

  Map<int, double> offsetsDe(String scopeKey) =>
      <int, double>{...?_offsets[scopeKey]};

  @override
  int? loadTabIndex(String scopeKey) {
    lectures.add(scopeKey);
    return _index[scopeKey];
  }

  @override
  void saveTabIndex(String scopeKey, int index) {
    ecritures.add(scopeKey);
    _index[scopeKey] = index;
  }

  @override
  double? loadScrollOffset(String scopeKey, int tabIndex) {
    lectures.add(scopeKey);
    return _offsets[scopeKey]?[tabIndex];
  }

  @override
  void saveScrollOffset(String scopeKey, int tabIndex, double offset) {
    ecritures.add(scopeKey);
    (_offsets[scopeKey] ??= <int, double>{})[tabIndex] = offset;
  }
}

/// Store qui LÈVE à chaque appel — l'implémentation fautive d'un hôte.
class _StoreFautif extends ZListTabsStore {
  const _StoreFautif();

  @override
  int? loadTabIndex(String scopeKey) => throw StateError('boom');

  @override
  void saveTabIndex(String scopeKey, int index) => throw StateError('boom');

  @override
  double? loadScrollOffset(String scopeKey, int tabIndex) =>
      throw StateError('boom');

  @override
  void saveScrollOffset(String scopeKey, int tabIndex, double offset) =>
      throw StateError('boom');
}

Widget _screen(
  FakeItemRepo repo, {
  ZListTabsStore? tabsStore,
  String? tabsScopeKey,
  String title = 'Items',
  String? collectionId,
  List<ZListTab> tabs = _tabs,
}) =>
    ZCrudScreen<Item>(
      title: title,
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      collectionId: collectionId,
      tabs: tabs,
      tabsStore: tabsStore,
      tabsScopeKey: tabsScopeKey,
      itemBuilder: (context, entity, columns) => SizedBox(
        height: 60,
        key: ValueKey<String>('zCrudTile_${entity.id}'),
        child: Text(entity.name),
      ),
    );

/// Clé de portée DÉRIVÉE attendue pour [_screen] par défaut : type d'entité,
/// identité de l'écran, jeu d'onglets.
const String _porteeAttendue = 'Item/Items/Un,Deux';

/// **Relance simulée** : jette TOUT l'arbre.
///
/// Un simple `pumpWidget(MaterialApp(…))` ne suffirait pas — le même type de
/// widget au même emplacement fait RÉUTILISER les éléments, donc l'écran n'est
/// jamais remonté et la garde passerait sans rien prouver (piège mesuré sur le
/// seam jumeau `ZSectionCollapseStore`).
Future<void> _relance(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(find.byType(MaterialApp), findsNothing);
  expect(find.byType(TabBar), findsNothing);
}

/// La liste défilante de l'onglet [pageKey], et elle seule (les pages
/// keep-alive voisines portent la leur).
Finder _listeDe(String pageKey) => find.descendant(
      of: find.byKey(ValueKey<String>('zTab_$pageKey')),
      matching: find.byType(Scrollable),
    );

/// Position RÉELLEMENT peinte de l'onglet [pageKey] — mesurée sur le rendu,
/// jamais sur ce que le store contient.
double _offsetPeint(WidgetTester tester, String pageKey) =>
    tester.state<ScrollableState>(_listeDe(pageKey).first).position.pixels;

/// Fait défiler l'onglet [pageKey] de [dy] pixels vers le haut.
Future<void> _defiler(
  WidgetTester tester,
  String pageKey,
  double dy,
) async {
  await tester.drag(_listeDe(pageKey).first, Offset(0, -dy));
  await tester.pumpAndSettle();
}

/// Index de l'onglet ACTIF, lu sur le `TabController` que `ZTabbedList`
/// possède — l'état réel de la barre, jamais le notifieur interne de l'écran.
int _indexActif(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

/// Bascule sur l'onglet de libellé [libelle].
Future<void> _ongletVers(WidgetTester tester, String libelle) async {
  await tester.tap(find.widgetWithText(Tab, libelle));
  await tester.pumpAndSettle();
}

void main() {
  group('(a) l\'onglet actif est RESTAURÉ après reconstruction de l\'arbre',
      () {
    testWidgets('l\'onglet quitté est celui retrouvé', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      await _ongletVers(tester, 'Deux');
      expect(espion.indexDe(_porteeAttendue), 1);

      await _relance(tester);
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      // L'onglet 1 est celui qui est monté ET actif : sa page porte les
      // éléments de sa catégorie (qty == 2 ⇒ indices impairs).
      expect(
        find.byKey(const ValueKey<String>('zCrudTile_i1')),
        findsOneWidget,
        reason: 'l\'écran est retombé sur le premier onglet',
      );
      expect(_indexActif(tester), 1);
    });

    testWidgets('CONTRE-TÉMOIN — sans changement d\'onglet, rien à restaurer '
        'et l\'écran ouvre sur le premier', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      await _relance(tester);
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      expect(find.byKey(const ValueKey<String>('zCrudTile_i0')), findsOneWidget);
    });
  });

  group('(b) 🔴 le défilement est mémorisé et restauré PAR ONGLET', () {
    testWidgets('deux onglets, deux offsets DISTINCTS, aucun mélange',
        (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      await _defiler(tester, 'Un', 300);
      final offsetUn = _offsetPeint(tester, 'Un');
      expect(offsetUn, greaterThan(0));

      await _ongletVers(tester, 'Deux');
      await _defiler(tester, 'Deux', 600);
      final offsetDeux = _offsetPeint(tester, 'Deux');
      expect(offsetDeux, greaterThan(offsetUn));

      // Deux emplacements, pas un : un offset GLOBAL rendrait ici deux fois la
      // même valeur.
      final memorises = espion.offsetsDe(_porteeAttendue);
      expect(memorises.keys.toSet(), <int>{0, 1});
      expect(memorises[0], offsetUn);
      expect(memorises[1], offsetDeux);
      expect(memorises[0], isNot(memorises[1]));

      await _relance(tester);
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      // L'onglet actif restauré est le second : il rouvre à SA position.
      expect(
        _offsetPeint(tester, 'Deux'),
        moreOrLessEquals(offsetDeux, epsilon: 1),
        reason: 'l\'onglet actif a rouvert ailleurs qu\'à sa position',
      );

      await _ongletVers(tester, 'Un');
      expect(
        _offsetPeint(tester, 'Un'),
        moreOrLessEquals(offsetUn, epsilon: 1),
        reason: 'l\'onglet rejoint a reçu la position de son voisin',
      );
    });
  });

  group('(c) 🔴 l\'écriture est PAR EMPLACEMENT, jamais par portée entière',
      () {
    testWidgets('mémoriser un offset n\'efface ni l\'index ni l\'offset voisin',
        (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();
      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      await _defiler(tester, 'Un', 300);
      await _ongletVers(tester, 'Deux');
      expect(espion.indexDe(_porteeAttendue), 1);
      expect(espion.offsetsDe(_porteeAttendue).containsKey(0), isTrue);

      // Le geste qui, avec une signature « portée entière », effacerait tout le
      // reste.
      await _defiler(tester, 'Deux', 400);

      expect(
        espion.indexDe(_porteeAttendue),
        1,
        reason: 'l\'index a été effacé par une écriture d\'offset',
      );
      expect(
        espion.offsetsDe(_porteeAttendue).containsKey(0),
        isTrue,
        reason: 'l\'offset du voisin a été effacé par une écriture d\'offset',
      );
    });
  });

  group('(d) AD-10 — lecture tolérante', () {
    testWidgets('index HORS BORNES ⇒ repli sur le premier onglet '
        '(le jeu d\'onglets a rétréci)', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion()
        // Trois onglets la session dernière, deux aujourd'hui.
        ..saveTabIndex(_porteeAttendue, 2);
      espion.ecritures.clear();

      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      expect(tester.takeException(), isNull);
      expect(
        _indexActif(tester),
        0,
        reason: 'un index hors bornes a été appliqué tel quel',
      );
      expect(find.byKey(const ValueKey<String>('zCrudTile_i0')), findsOneWidget);
    });

    testWidgets('index NÉGATIF ⇒ même repli', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion()..saveTabIndex(_porteeAttendue, -3);

      await pumpScreen(tester, _screen(repo, tabsStore: espion));

      expect(tester.takeException(), isNull);
      expect(_indexActif(tester), 0);
    });

    testWidgets('offsets absents ⇒ zéros, pas de saut', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo, tabsStore: _StoreEspion()));

      expect(_offsetPeint(tester, 'Un'), 0);
    });

    testWidgets('un store qui LÈVE est traité comme absent — l\'écran reste '
        'debout, sur le premier onglet, en haut', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo, tabsStore: const _StoreFautif()));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('zCrudTile_i0')), findsOneWidget);
      expect(_offsetPeint(tester, 'Un'), 0);

      // Et les gestes continuent de passer : l'écriture fautive est absorbée.
      await _ongletVers(tester, 'Deux');
      await _defiler(tester, 'Deux', 200);
      expect(tester.takeException(), isNull);
    });
  });

  group('(e) 🔴 CONTRE-TÉMOIN — sans store déclaré, rien n\'est payé', () {
    testWidgets('aucune lecture, aucune écriture (absence d\'APPEL, pas '
        'absence d\'effet)', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final muet = _StoreEspion();
      // Le store existe, il n'est simplement PAS déclaré à l'écran.
      await pumpScreen(tester, _screen(repo));

      await _ongletVers(tester, 'Deux');
      await _defiler(tester, 'Deux', 300);
      await _ongletVers(tester, 'Un');

      expect(
        muet.appels,
        0,
        reason: 'lectures=${muet.lectures}, écritures=${muet.ecritures}',
      );
    });

    testWidgets('l\'écran rouvre sur le premier onglet, en haut — comportement '
        'strictement antérieur', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo));

      await _ongletVers(tester, 'Deux');
      await _defiler(tester, 'Deux', 300);

      await _relance(tester);
      await pumpScreen(tester, _screen(repo));

      expect(find.byKey(const ValueKey<String>('zCrudTile_i0')), findsOneWidget);
      expect(_offsetPeint(tester, 'Un'), 0);
    });

    testWidgets('pas un widget de plus dans l\'arbre (compte absolu)',
        (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);

      await pumpScreen(tester, _screen(repo));
      final sansStore = tester
          .widgetList(find.byType(NotificationListener<ScrollNotification>))
          .length;

      await _relance(tester);
      await pumpScreen(tester, _screen(repo, tabsStore: _StoreEspion()));
      final avecStore = tester
          .widgetList(find.byType(NotificationListener<ScrollNotification>))
          .length;

      expect(
        avecStore,
        greaterThan(sansStore),
        reason: 'la mémoire de défilement n\'est pas montée avec le store',
      );
    });
  });

  group('(f) la clé de portée dérivée isole les écrans et les jeux d\'onglets',
      () {
    testWidgets('deux écrans DIFFÉRENTS ne se marchent pas dessus',
        (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();

      await pumpScreen(tester, _screen(repo, tabsStore: espion));
      await _ongletVers(tester, 'Deux');

      await _relance(tester);
      // Même entité, même jeu d'onglets, AUTRE écran (autre collection).
      await pumpScreen(
        tester,
        _screen(repo, tabsStore: espion, collectionId: 'archives'),
      );

      expect(
        find.byKey(const ValueKey<String>('zCrudTile_i0')),
        findsOneWidget,
        reason: 'un écran a hérité de la préférence d\'un autre',
      );
      expect(espion.portees.length, 2);
      expect(espion.portees, contains('Item/archives/Un,Deux'));
    });

    testWidgets('changer le JEU D\'ONGLETS invalide naturellement l\'ancienne '
        'préférence', (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();

      await pumpScreen(tester, _screen(repo, tabsStore: espion));
      await _ongletVers(tester, 'Deux');
      expect(espion.indexDe(_porteeAttendue), 1);

      await _relance(tester);
      // Le jeu d'onglets a changé — l'index mémorisé ne lui appartient pas.
      await pumpScreen(
        tester,
        _screen(
          repo,
          tabsStore: espion,
          tabs: const <ZListTab>[
            ZListTab(
              labelKey: 'Un',
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)],
            ),
            ZListTab(
              labelKey: 'Trois',
              baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 2)],
            ),
          ],
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('zCrudTile_i0')),
        findsOneWidget,
        reason: 'une préférence d\'un autre jeu d\'onglets a été réappliquée',
      );
      expect(espion.portees, contains('Item/Items/Un,Trois'));
    });

    testWidgets('la clé DÉCLARÉE (tabsScopeKey) l\'emporte sur la dérivation',
        (tester) async {
      final repo = FakeItemRepo(_seed());
      addTearDown(repo.dispose);
      final espion = _StoreEspion();

      await pumpScreen(
        tester,
        _screen(repo, tabsStore: espion, tabsScopeKey: 'dossier-42'),
      );
      await _ongletVers(tester, 'Deux');

      expect(espion.portees, <String>{'dossier-42'});
      expect(espion.indexDe('dossier-42'), 1);
    });
  });
}
