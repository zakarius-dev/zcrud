// CR-MENU — le menu de GABARITS de création de la sous-liste résolvait le
// gabarit sélectionné par sa POSITION.
//
// Défaut mesuré (`z_sub_list_field_widget.dart`, avant correction) :
//
//     PopupMenuButton<int>(
//       onSelected: (i) => _openAddDialog(templateDefaults: templates[i].defaults),
//       itemBuilder: ... PopupMenuItem<int>(value: i, ...)
//     )
//
// `itemBuilder` s'exécute à l'OUVERTURE (menu FIGÉ) ; `onSelected` s'exécute
// APRÈS la fermeture et relisait `_creationTemplates` COURANT. La sous-liste
// rebâtit à chaque `setState` (ajout/suppression/restauration d'item) et à
// chaque rebuild du formulaire hôte — les deux lectures pouvaient donc
// diverger :
//   * réordonnancement ⇒ le dialog s'ouvre pré-rempli avec les valeurs d'un
//     AUTRE gabarit, sans aucune trace ;
//   * raccourcissement ⇒ `RangeError` levé DANS un gestionnaire de tap.
//
// Correction : la valeur portée par l'entrée est le GABARIT lui-même — même
// lecture que `ZDefaultMenuRenderer` (`zcrud_menu`), non importable ici (AD-1,
// out-degree zcrud de `zcrud_core` = 0).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZSubListItemTemplate _tpl(String s) => ZSubListItemTemplate(
      labelKey: 'tpl$s',
      defaults: <String, Object?>{'f1': s},
    );

/// Hôte dont la LISTE DE GABARITS est mutable à chaud.
class _TplHost extends StatefulWidget {
  const _TplHost({super.key, required this.initial, required this.onChanged});

  final List<String> initial;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<_TplHost> createState() => _TplHostState();
}

class _TplHostState extends State<_TplHost> {
  late List<String> _keys = widget.initial;

  /// Rejoue le scénario du défaut : les gabarits changent PENDANT que le menu
  /// est ouvert.
  void mutate(List<String> keys) => setState(() => _keys = keys);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZSubListFieldWidget(
              field: ZFieldSpec(
                name: 'items',
                type: EditionFieldType.subItems,
                label: 'Items',
                config: ZSubListConfig(
                  itemFields: _itemFields,
                  displayMode: ZSubListDisplayMode.compact,
                  summaryFields: const <String>['f1'],
                  creationTemplates: <ZSubListItemTemplate>[
                    for (final k in _keys) _tpl(k),
                  ],
                ),
              ),
              initialValue: null,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      );
}

void main() {
  group('CR-MENU — le menu de gabarits résout par IDENTITÉ, pas par index', () {
    testWidgets(
        'G1 : un rebuild qui RÉORDONNE les gabarits pendant que le menu est '
        'ouvert ne pré-remplit PAS avec un autre gabarit', (tester) async {
      List<Map<String, dynamic>>? captured;
      final key = GlobalKey<_TplHostState>();

      await tester.pumpWidget(_TplHost(
        key: key,
        initial: const <String>['A', 'B', 'C'],
        onChanged: (list) => captured = list,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('tplC'), findsOneWidget);

      // Menu ouvert ; la sous-liste rebâtit avec l'ordre INVERSÉ.
      key.currentState!.mutate(const <String>['C', 'B', 'A']);
      await tester.pump();

      await tester.tap(find.text('tplC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(captured!.single['f1'], 'C',
          reason: "le gabarit appliqué doit être CELUI QUE L'UTILISATEUR A VU "
              '— une résolution par index appliquerait « A »');
    });

    testWidgets(
        'G2 : un rebuild qui RACCOURCIT les gabarits pendant que le menu est '
        'ouvert ne LÈVE pas', (tester) async {
      List<Map<String, dynamic>>? captured;
      final key = GlobalKey<_TplHostState>();

      await tester.pumpWidget(_TplHost(
        key: key,
        initial: const <String>['A', 'B', 'C'],
        onChanged: (list) => captured = list,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('tplC'), findsOneWidget);

      // Un SEUL gabarit restant : l'ancien index 2 sort des bornes. Le
      // déclencheur reste un `PopupMenuButton` (liste non vide) — donc monté,
      // sinon `onSelected` ne serait jamais appelé et la garde ne mesurerait
      // plus rien.
      key.currentState!.mutate(const <String>['A']);
      await tester.pump();

      await tester.tap(find.text('tplC'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un `RangeError` dans un gestionnaire de tap est le symptôme '
              'EXACT de la résolution positionnelle');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(captured!.single['f1'], 'C');
    });
  });
}
