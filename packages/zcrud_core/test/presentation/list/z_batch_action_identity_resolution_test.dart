// CR-MENU — le menu de dépassement de la barre de lot résolvait l'action
// SÉLECTIONNÉE par sa POSITION.
//
// Défaut mesuré (`z_batch_action.dart`, avant correction) :
//
//     PopupMenuButton<int>(
//       itemBuilder: ... PopupMenuItem<int>(value: i, ...)
//       onSelected: (i) => entries[i].onPressed(),   // ← relit la liste APRÈS
//     )
//
// `itemBuilder` n'est appelé qu'à l'OUVERTURE : le menu affiché est FIGÉ.
// `onSelected`, lui, s'exécute APRÈS la fermeture et relisait la liste
// COURANTE. Tout rebuild survenu entre les deux (la barre rebâtit à chaque
// notification de `ZListSelectionController` et à chaque rebuild de l'hôte)
// désalignait les deux lectures :
//   * réordonnancement ⇒ une AUTRE action s'exécute, SANS aucune trace ;
//   * raccourcissement ⇒ `RangeError` levé DANS un gestionnaire de tap.
//
// La correction adopte la sémantique de `ZDefaultMenuRenderer` (`zcrud_menu`,
// `PopupMenuButton<ZMenuEntry>`) : la valeur portée par l'entrée est l'ENTRÉE
// ELLE-MÊME. `zcrud_menu` n'est PAS importable ici (AD-1 : `zcrud_core` a un
// out-degree zcrud de 0) — c'est la LECTURE qui est alignée, pas la couture.
//
// Gardes PORTEUSES : elles assèrent le symptôme (quelle action a réellement
// tiré / aucune exception), pas une propriété de forme. Remettre
// `onSelected: (i) => entries[i].onPressed()` les fait ROUGIR (G1 : échec
// d'ASSERTION sur l'action tirée ; G2 : `RangeError` propagé).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Barre de lot dont la liste d'actions est MUTABLE à chaud (via [_BarHostState]).
class _BarHost extends StatefulWidget {
  const _BarHost({super.key, required this.initial, required this.fired});

  final List<String> initial;
  final List<String> fired;

  @override
  State<_BarHost> createState() => _BarHostState();
}

class _BarHostState extends State<_BarHost> {
  late List<String> _labels = widget.initial;
  final ZListSelectionController _controller = ZListSelectionController()
    ..selectAll(<String>['a', 'b', 'c']);

  /// Rejoue EXACTEMENT le scénario du défaut : la liste change pendant que le
  /// menu est ouvert.
  void mutate(List<String> labels) => setState(() => _labels = labels);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZBatchActionBar(
        controller: _controller,
        actions: <ZBatchAction>[
          for (final label in _labels)
            ZBatchAction(
              kind: ZBatchActionKind.custom,
              label: label,
              icon: Icons.star,
              onSelected: () => widget.fired.add(label),
            ),
        ],
        countLabelBuilder: (n) => '$n',
        selectAllLabel: 'Tout sélectionner',
        onSelectAll: () => widget.fired.add('selectAll'),
      );
}

List<String> _labels(int count) =>
    <String>[for (var i = 0; i < count; i++) 'Action $i'];

void main() {
  group('CR-MENU — le menu de dépassement résout par IDENTITÉ, pas par index',
      () {
    // Surface 800 × 600 : 16 créneaux de 48 dp ⇒ 15 entrées en ligne, le reste
    // replié. Avec 24 actions (+ « tout sélectionner ») le repli porte
    // « Action 14 » … « Action 23 ».
    testWidgets(
        'G1 : un rebuild qui RÉORDONNE pendant que le menu est ouvert '
        "n'exécute PAS une autre action", (tester) async {
      final fired = <String>[];
      final key = GlobalKey<_BarHostState>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _BarHost(key: key, initial: _labels(24), fired: fired),
        ),
      ));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // L'entrée VUE par l'utilisateur, au fond du repli.
      expect(find.text('Action 23'), findsOneWidget,
          reason: 'le menu figé doit porter la dernière action repliée');

      // Le menu reste ouvert ; la barre, elle, rebâtit avec l'ordre INVERSÉ.
      key.currentState!.mutate(_labels(24).reversed.toList());
      await tester.pump();

      await tester.tap(find.text('Action 23'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fired, <String>['Action 23'],
          reason: "l'action exécutée doit être CELLE QUE L'UTILISATEUR A VUE "
              'et touchée — une résolution par index tirerait « Action 0 »');
    });

    testWidgets(
        'G2 : un rebuild qui RACCOURCIT la liste pendant que le menu est '
        'ouvert ne LÈVE pas', (tester) async {
      final fired = <String>[];
      final key = GlobalKey<_BarHostState>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _BarHost(key: key, initial: _labels(24), fired: fired),
        ),
      ));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Action 23'), findsOneWidget);

      // 18 actions ⇒ 19 entrées ⇒ repli de 4 entrées : l'ancien index 9 SORT
      // des bornes. Le bouton de dépassement reste monté (sinon `onSelected`
      // ne serait jamais appelé et la garde ne mesurerait plus rien).
      key.currentState!.mutate(_labels(18));
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.text('Action 23'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un `RangeError` levé dans un gestionnaire de tap est le '
              'symptôme EXACT de la résolution positionnelle');
      expect(fired, <String>['Action 23']);
    });
  });
}
