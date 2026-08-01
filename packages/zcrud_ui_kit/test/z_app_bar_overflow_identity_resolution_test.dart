// CR-MENU — le menu de DÉBORDEMENT de l'app-bar résolvait l'action sélectionnée
// par sa POSITION.
//
// Défaut mesuré (`z_page_shell.dart` / `_zBuildActions`, avant correction) :
//
//     PopupMenuButton<int>(
//       itemBuilder: ... PopupMenuItem<int>(value: i, ...)
//       onSelected: (i) => overflow[i].onPressed?.call(),   // ← relit APRÈS
//     )
//
// `itemBuilder` n'est appelé qu'à l'OUVERTURE (le menu affiché est FIGÉ) tandis
// que `onSelected` s'exécute APRÈS la fermeture, sur la liste COURANTE. Or
// `ZPageShell`/`ZSearchableAppBar` rebâtissent leurs actions à chaque
// notification de props réactives et à chaque rebuild de l'hôte. Tout rebuild
// tombant dans cette fenêtre désalignait les deux lectures :
//   * réordonnancement ⇒ une AUTRE action s'exécute, SANS aucune trace ;
//   * raccourcissement ⇒ `RangeError` levé DANS un gestionnaire de tap.
//
// Correction : la valeur portée par chaque entrée est la `ZAppBarAction`
// elle-même — MÊME lecture que `ZDefaultMenuRenderer` (`zcrud_menu`,
// `PopupMenuButton<ZMenuEntry>`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// App-bar dont la liste d'actions de débordement est MUTABLE à chaud.
class _BarHost extends StatefulWidget {
  const _BarHost({super.key, required this.initial, required this.fired});

  final List<String> initial;
  final List<String> fired;

  @override
  State<_BarHost> createState() => _BarHostState();
}

class _BarHostState extends State<_BarHost> {
  late List<String> _labels = widget.initial;

  /// Rejoue le scénario du défaut : les actions changent PENDANT que le menu
  /// est ouvert.
  void mutate(List<String> labels) => setState(() => _labels = labels);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: ZSearchableAppBar(
            title: 'T',
            actions: <ZAppBarAction>[
              for (final label in _labels)
                ZAppBarAction(
                  icon: Icons.star,
                  semanticLabel: label,
                  isOverflow: true,
                  onPressed: () => widget.fired.add(label),
                ),
            ],
          ),
        ),
      );
}

void main() {
  group("CR-MENU — le débordement d'app-bar résout par IDENTITÉ, pas par index",
      () {
    testWidgets(
        'G1 : un rebuild qui RÉORDONNE pendant que le menu est ouvert '
        "n'exécute PAS une autre action", (tester) async {
      final fired = <String>[];
      final key = GlobalKey<_BarHostState>();

      await tester.pumpWidget(
        _BarHost(key: key, initial: const <String>['A', 'B', 'C'], fired: fired),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget);

      // Menu ouvert ; l'app-bar rebâtit avec l'ordre INVERSÉ.
      key.currentState!.mutate(const <String>['C', 'B', 'A']);
      await tester.pump();

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fired, <String>['C'],
          reason: "l'action exécutée doit être CELLE QUE L'UTILISATEUR A VUE — "
              'une résolution par index tirerait « A »');
    });

    testWidgets(
        'G2 : un rebuild qui RACCOURCIT la liste pendant que le menu est '
        'ouvert ne LÈVE pas', (tester) async {
      final fired = <String>[];
      final key = GlobalKey<_BarHostState>();

      await tester.pumpWidget(
        _BarHost(key: key, initial: const <String>['A', 'B', 'C'], fired: fired),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget);

      // Une SEULE action restante : l'ancien index 2 sort des bornes. Le
      // bouton de débordement reste monté (`overflow.isNotEmpty`) — sinon
      // `onSelected` ne serait jamais appelé et la garde ne mesurerait plus rien.
      key.currentState!.mutate(const <String>['A']);
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un `RangeError` dans un gestionnaire de tap est le symptôme '
              'EXACT de la résolution positionnelle');
      expect(fired, <String>['C']);
    });
  });
}
