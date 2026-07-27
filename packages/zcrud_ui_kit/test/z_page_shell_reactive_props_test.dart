/// Gardes R3 — **props déclaratives variables** du page-shell (SUF-1).
///
/// `mode` et `search` sont des props d'un widget immuable : un hôte adaptatif
/// les remplace d'un build à l'autre (shell `fixed` en compact / sliver en
/// large ; closure `onQueryChanged` recréée à chaque build en capturant
/// l'onglet ou le dossier courant). Ces gardes verrouillent le fait que l'état
/// détenu par le `State` n'est **jamais figé à l'`initState`** :
///
/// * G-A : basculer `mode` `fixed` → sliver sur un `State` **déjà monté** ne
///   crashe pas (le contrôleur de recherche n'est pas conditionné au mode) ;
/// * G-B : après remplacement de la `ZAppBarSearchConfig`, la frappe atteint le
///   **nouveau** `onQueryChanged`, jamais l'ancien (pas de perte silencieuse) ;
/// * G-C : `search` `null` → non-null active réellement la recherche.
///
/// Toutes exercent le **même élément** (aucune `key`, même type au même
/// emplacement ⇒ Flutter réutilise l'`Element`, donc le `State`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Page-shell paramétrée par les deux props variables sous test.
Widget _shell({required ZPageAppBarMode mode, ZAppBarSearchConfig? search}) =>
    MaterialApp(
      home: ZPageScaffold(
        title: 'TITRE',
        mode: mode,
        search: search,
        body: const SizedBox(height: 600, child: Text('CORPS')),
      ),
    );

/// App-bar seule (mode fixe) paramétrée par la config de recherche.
Widget _appBar(ZAppBarSearchConfig? search) => MaterialApp(
  home: Scaffold(
    appBar: ZSearchableAppBar(title: 'TITRE', search: search),
    body: const Text('CORPS'),
  ),
);

/// Ouvre la recherche (loupe) et attend la stabilisation.
Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
}

void main() {
  group('G-A — `mode` change sur un State monté', () {
    testWidgets('CR-60 — fixed → pinned préserve le champ et la query ouverts', (
      tester,
    ) async {
      final recu = <String>[];
      final search = ZAppBarSearchConfig(onQueryChanged: recu.add);

      await tester.pumpWidget(
        _shell(mode: ZPageAppBarMode.fixed, search: search),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'douane');

      await tester.pumpWidget(
        _shell(mode: ZPageAppBarMode.pinned, search: search),
      );
      await tester.pumpAndSettle();

      // GARDE MORDANTE : si le contrôleur reste détenu par les branches
      // `ZSearchableAppBar` / `ZPageShellBody`, cette assertion rouge après le
      // hot-swap (0 TextField et query perdue). Avec l'état hissé, elle est verte.
      expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
      expect(find.text('douane', skipOffstage: false), findsOneWidget);
      expect(recu, <String>['douane']);
    });

    // Un hôte adaptatif rend `fixed` en compact puis sliver en large : le
    // propriétaire de l'état ne doit PAS dépendre du mode INITIAL.
    testWidgets('fixed → pinned ne crashe pas (sans recherche)', (
      tester,
    ) async {
      await tester.pumpWidget(_shell(mode: ZPageAppBarMode.fixed));
      expect(find.byType(SliverAppBar), findsNothing);

      await tester.pumpWidget(_shell(mode: ZPageAppBarMode.pinned));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'basculer le mode sur un State monté ne doit pas lever',
      );
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('TITRE'), findsOneWidget);
    });

    // Variante AVEC recherche : la tranche sliver déréférence le contrôleur
    // pour la loupe et la bascule — le chemin le plus exposé.
    testWidgets('fixed → floating ne crashe pas et la recherche marche', (
      tester,
    ) async {
      final recu = <String>[];
      ZAppBarSearchConfig config() =>
          ZAppBarSearchConfig(onQueryChanged: recu.add);

      await tester.pumpWidget(
        _shell(mode: ZPageAppBarMode.fixed, search: config()),
      );
      await tester.pumpWidget(
        _shell(mode: ZPageAppBarMode.floating, search: config()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SliverAppBar), findsOneWidget);

      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'ab');
      expect(recu, <String>['ab']);
    });

    // Aller-retour complet : le contrôleur ne doit être ni `dispose`é au
    // passage en `fixed`, ni recréé au retour en sliver (mordant contre une
    // gestion du cycle de vie indexée sur `_isSliver`).
    testWidgets('pinned → fixed → pinned : aller-retour utilisable', (
      tester,
    ) async {
      final recu = <String>[];
      Widget page(ZPageAppBarMode mode) => _shell(
        mode: mode,
        search: ZAppBarSearchConfig(onQueryChanged: recu.add),
      );

      await tester.pumpWidget(page(ZPageAppBarMode.pinned));
      await tester.pumpWidget(page(ZPageAppBarMode.fixed));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SliverAppBar), findsNothing);

      await tester.pumpWidget(page(ZPageAppBarMode.pinned));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SliverAppBar), findsOneWidget);

      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'ab');
      expect(
        tester.takeException(),
        isNull,
        reason: 'le contrôleur ne doit pas avoir été disposé en route',
      );
      expect(recu, <String>['ab']);
    });
  });

  group('G-B — config remplacée ⇒ la frappe suit la NOUVELLE config', () {
    testWidgets('ZSearchableAppBar : ancien callback jamais rappelé', (
      tester,
    ) async {
      final vieux = <String>[];
      final neuf = <String>[];

      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: vieux.add)),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'a');
      expect(vieux, <String>['a'], reason: 'config initiale : elle reçoit');

      // L'hôte rebâtit avec une closure recréée (nouvel onglet/dossier).
      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: neuf.add)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');

      expect(neuf, <String>[
        'ab',
      ], reason: 'la NOUVELLE config doit recevoir la frappe');
      expect(vieux, <String>[
        'a',
      ], reason: 'la config périmée ne doit plus rien recevoir');
    });

    testWidgets('ZPageScaffold sliver : ancien callback jamais rappelé', (
      tester,
    ) async {
      final vieux = <String>[];
      final neuf = <String>[];

      await tester.pumpWidget(
        _shell(
          mode: ZPageAppBarMode.pinned,
          search: ZAppBarSearchConfig(onQueryChanged: vieux.add),
        ),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'a');
      expect(vieux, <String>['a']);

      await tester.pumpWidget(
        _shell(
          mode: ZPageAppBarMode.pinned,
          search: ZAppBarSearchConfig(onQueryChanged: neuf.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');

      expect(neuf, <String>[
        'ab',
      ], reason: 'la NOUVELLE config doit recevoir la frappe (sliver)');
      expect(vieux, <String>['a']);
    });

    // La fermeture émet '' : elle aussi doit viser la config FRAÎCHE.
    testWidgets('fermeture ⇒ le `\'\'` part vers la NOUVELLE config', (
      tester,
    ) async {
      final vieux = <String>[];
      final neuf = <String>[];

      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: vieux.add)),
      );
      await _openSearch(tester);
      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: neuf.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(neuf, <String>['']);
      expect(vieux, isEmpty);
    });

    // Remplacer la seule closure ne doit PAS écraser la saisie en cours
    // (aucun controller recréé au rebuild — AD-2).
    testWidgets('même initialQuery ⇒ la saisie en cours est préservée', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: (_) {})),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'saisie');

      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('saisie'), findsOneWidget);
      final state = tester.state<ZSearchableAppBarState>(
        find.byType(ZSearchableAppBar),
      );
      expect(state.queryListenable.value, 'saisie');
    });

    // En revanche, une nouvelle valeur INITIALE déclarée est adoptée.
    testWidgets('nouvel initialQuery ⇒ adopté par le champ', (tester) async {
      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: (_) {})),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'obsolete');

      await tester.pumpWidget(
        _appBar(
          ZAppBarSearchConfig(onQueryChanged: (_) {}, initialQuery: 'nouvelle'),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<ZSearchableAppBarState>(
        find.byType(ZSearchableAppBar),
      );
      expect(state.queryListenable.value, 'nouvelle');
      expect(find.text('nouvelle'), findsOneWidget);
    });
  });

  group('G-C — `search` null → non-null', () {
    testWidgets('ZSearchableAppBar : la recherche devient utilisable', (
      tester,
    ) async {
      final recu = <String>[];

      await tester.pumpWidget(_appBar(null));
      expect(
        find.byIcon(Icons.search),
        findsNothing,
        reason: 'search null ⇒ absence STRUCTURELLE de la loupe',
      );

      await tester.pumpWidget(
        _appBar(
          ZAppBarSearchConfig(onQueryChanged: recu.add, initialQuery: 'init'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.search), findsOneWidget);

      final state = tester.state<ZSearchableAppBarState>(
        find.byType(ZSearchableAppBar),
      );
      expect(
        state.queryListenable.value,
        'init',
        reason: 'initialQuery d\'une config apparue doit être adoptée',
      );

      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'x');
      expect(recu, <String>['x']);
    });

    testWidgets('ZPageScaffold sliver : la recherche devient utilisable', (
      tester,
    ) async {
      final recu = <String>[];

      await tester.pumpWidget(_shell(mode: ZPageAppBarMode.pinned));
      expect(find.byIcon(Icons.search), findsNothing);

      await tester.pumpWidget(
        _shell(
          mode: ZPageAppBarMode.pinned,
          search: ZAppBarSearchConfig(onQueryChanged: recu.add),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'x');
      expect(recu, <String>['x']);
    });

    // Retrait PUIS retour de la recherche : le retrait doit refermer l'état
    // détenu — sinon la recherche se rouvre TOUTE SEULE au retour de la config,
    // avec la saisie périmée, et sans aucune émission vers le callback disparu.
    testWidgets('non-null → null → non-null : pas de réouverture fantôme', (
      tester,
    ) async {
      final recu = <String>[];

      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: recu.add)),
      );
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), 'abc');
      recu.clear();

      await tester.pumpWidget(_appBar(null));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(recu, isEmpty, reason: 'aucune émission vers une config retirée');
      expect(find.byType(TextField), findsNothing);

      final retour = <String>[];
      await tester.pumpWidget(
        _appBar(ZAppBarSearchConfig(onQueryChanged: retour.add)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'la recherche ne doit pas se rouvrir d\'elle-même',
      );
      expect(find.text('TITRE'), findsOneWidget);
      final state = tester.state<ZSearchableAppBarState>(
        find.byType(ZSearchableAppBar),
      );
      expect(
        state.queryListenable.value,
        '',
        reason: 'aucune saisie périmée ne survit au retrait',
      );
      expect(recu, isEmpty);
    });
  });
}
