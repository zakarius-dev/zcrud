// CR-IFFD-38 — raccordement du patron `ZDisplayState` à la section repliable :
// le déplié/replié devient commandable par l'hôte (`ZToggleController`), sans
// rien changer pour l'hôte qui n'en fournit pas.
//
// 🔴 Ce que ces gardes mesurent :
// - la commande de l'hôte est vérifiée **sur l'ARBRE RENDU** (le corps de la
//   section est monté/démonté, et le glyphe du chevron change) — pas sur un
//   champ interne, qu'un `ValueListenableBuilder` oublié laisserait juste alors
//   que l'écran serait faux ;
// - la source de vérité est vérifiée **dans les deux sens** : le chevron écrit
//   chez l'hôte, ET l'hôte commande le chevron. Un miroir local passerait le
//   premier sens et échouerait au second ;
// - l'ISOLATION entre N sections : commander la section B ne doit pas replier A
//   (une garde qui n'en testerait qu'une resterait verte avec un état partagé).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/z_sources.dart' show stripped;

ZStudyToolsSectionSpec _spec({
  required String id,
  bool initiallyExpanded = true,
  ZToggleController? expandController,
}) =>
    ZStudyToolsSectionSpec(
      id: id,
      title: 'Section $id',
      itemCount: 1,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item_${id}_$i'),
        height: 40,
        child: Text('Item $id $i'),
      ),
      emptyState: const Text('vide'),
      collapsible: true,
      initiallyExpanded: initiallyExpanded,
      expandController: expandController,
    );

/// Hôte **conforme au patron** : les N contrôleurs sont des champs du `State`
/// (possession hors `build`, imposée par le mixin), un par section.
class _Host extends StatefulWidget {
  const _Host({
    required this.ids,
    this.withControllers = true,
    this.initiallyExpanded = true,
    super.key,
  });

  final List<String> ids;
  final bool withControllers;
  final bool initiallyExpanded;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ZDisplayStateOwnerMixin<_Host> {
  late final Map<String, ZToggleController> controllers =
      <String, ZToggleController>{
    for (final String id in widget.ids)
      id: ZToggleController(
        owner: this,
        initialValue: true,
        debugLabel: 'test.expand.$id',
      ),
  };

  /// Le « tout replier » d'un sommaire externe — le second chemin réel.
  void collapseAll() {
    for (final ZToggleController c in controllers.values) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ZSectionedStudyLayout(
              sections: <ZStudyToolsSectionSpec>[
                for (final String id in widget.ids)
                  _spec(
                    id: id,
                    initiallyExpanded: widget.initiallyExpanded,
                    expandController:
                        widget.withControllers ? controllers[id] : null,
                  ),
              ],
            ),
          ),
        ),
      );
}

Finder _item(String id) => find.byKey(ValueKey<String>('item_${id}_0'));
Finder _chevron(String id) =>
    find.byKey(ValueKey<String>('section:$id:collapse'));

/// Le glyphe RÉELLEMENT rendu par le chevron — second canal de mesure : une
/// section dont le corps suivrait la commande mais dont l'icône resterait
/// figée serait un état affiché contradictoire.
IconData _chevronIcon(WidgetTester tester, String id) =>
    tester.widget<Icon>(find.descendant(of: _chevron(id), matching: find.byType(Icon))).icon!;

/// Source d'un fichier **débarrassée de ses commentaires** : une garde qui
/// compterait les occurrences de texte, dartdoc compris, serait verte (ou
/// rouge) sans rien mesurer du code réellement compilé.
///
/// 🔴 DÉPOUILLÉ via le patron PARTAGÉ (campagne dartdoc P0A) : l'ancien
/// `startsWith('//')` ligne-à-ligne laissait passer un commentaire de fin de
/// ligne et un bloc `/* … */`.
String _codeOf(String path) => stripped(File(path)).join('\n');

/// Racine du dépôt (dossier portant `melos.yaml`) — ancrage ROBUSTE.
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('CR-IFFD-38 — SANS contrôleur : strictement inchangé', () {
    testWidgets('replié au départ, le chevron déplie puis replie',
        (tester) async {
      await tester.pumpWidget(
        const _Host(
          ids: <String>['a'],
          withControllers: false,
          initiallyExpanded: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(_item('a'), findsNothing);
      expect(_chevronIcon(tester, 'a'), Icons.expand_more);

      await tester.tap(_chevron('a'));
      await tester.pumpAndSettle();
      expect(_item('a'), findsOneWidget);
      expect(_chevronIcon(tester, 'a'), Icons.expand_less);

      await tester.tap(_chevron('a'));
      await tester.pumpAndSettle();
      expect(_item('a'), findsNothing);
    });

    testWidgets('aucun `ZToggleController` n\'est CRÉÉ par le package',
        (tester) async {
      // Garde STRUCTURELLE : le layout lit les specs DANS `build` — s'il y
      // créait les contrôleurs, chaque rebuild remplacerait les instances et la
      // commande de l'hôte deviendrait silencieusement inerte. C'est le défaut
      // que le patron existe pour rendre impossible.
      final root = _repoRoot().path;
      for (final String file in <String>[
        'z_sectioned_study_layout.dart',
        'z_study_tools_section_spec.dart',
      ]) {
        final src =
            _codeOf('$root/packages/zcrud_study/lib/src/presentation/$file');
        expect(
          RegExp(r'ZToggleController\s*\(').allMatches(src),
          isEmpty,
          reason: '🔴 $file CONSOMME un contrôleur, il n\'en construit jamais',
        );
        expect(
          RegExp(r'with[^;{]*ZDisplayStateOwnerMixin').hasMatch(src),
          isFalse,
          reason: '🔴 la POSSESSION appartient à l\'hôte ($file)',
        );
      }
    });
  });

  group('CR-IFFD-38 — AVEC contrôleur : la commande AGIT sur l\'arbre', () {
    testWidgets('🔴 « tout replier » externe démonte les corps des N sections',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, ids: const <String>['a', 'b']));
      await tester.pumpAndSettle();
      expect(_item('a'), findsOneWidget);
      expect(_item('b'), findsOneWidget);

      key.currentState!.collapseAll();
      await tester.pumpAndSettle();

      expect(
        _item('a'),
        findsNothing,
        reason: '🔴 sans liaison, la commande serait inerte : le corps '
            'resterait monté et le sommaire externe serait un bouton mort',
      );
      expect(_item('b'), findsNothing);
      expect(_chevronIcon(tester, 'a'), Icons.expand_more);
      expect(_chevronIcon(tester, 'b'), Icons.expand_more);
    });

    testWidgets('🔴 N sections restent ISOLÉES : commander B ne replie pas A',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, ids: const <String>['a', 'b']));
      await tester.pumpAndSettle();

      key.currentState!.controllers['b']!.clear();
      await tester.pumpAndSettle();

      expect(_item('b'), findsNothing);
      expect(
        _item('a'),
        findsOneWidget,
        reason: '🔴 un état partagé entre sections replierait A aussi',
      );
    });

    testWidgets('le contrôleur est réellement CONSOMMÉ (anti passe-plat)',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, ids: const <String>['a']));
      await tester.pumpAndSettle();

      final ZToggleController c = key.currentState!.controllers['a']!;
      expect(c.wasEverConsumed, isTrue);
      expect(c.consumerCount, 1);
    });

    testWidgets(
        'le contrôleur PRIME sur `initiallyExpanded` (une seule source)',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: key,
          ids: const <String>['a'],
          initiallyExpanded: false, // ignoré : l'état appartient au contrôleur
        ),
      );
      await tester.pumpAndSettle();

      expect(_item('a'), findsOneWidget);
      expect(key.currentState!.controllers['a']!.value, isTrue);
    });
  });

  group('CR-IFFD-38 — le contrôleur reste LA source de vérité', () {
    testWidgets('🔴 le chevron écrit CHEZ L\'HÔTE, et l\'hôte recommande après',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, ids: const <String>['a']));
      await tester.pumpAndSettle();

      final ZToggleController c = key.currentState!.controllers['a']!;
      await tester.tap(_chevron('a'));
      await tester.pumpAndSettle();

      expect(
        c.value,
        isFalse,
        reason: '🔴 un miroir local laisserait le contrôleur de l\'hôte à '
            '`true` alors que la section est repliée — la divergence exacte '
            'que le contrat interdit',
      );
      expect(_item('a'), findsNothing);

      // SENS INVERSE : l'hôte repart de l'état RÉEL. Un miroir passerait le
      // premier sens (`toggle()` le remettrait à `false`) et échouerait ici.
      c.toggle();
      await tester.pumpAndSettle();
      expect(c.value, isTrue);
      expect(_item('a'), findsOneWidget);
    });
  });
}
