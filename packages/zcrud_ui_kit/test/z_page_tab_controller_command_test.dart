// Sonde de commande externe des onglets — CR-IFFD-38, famille « onglet actif ».
//
// 🔴 POURQUOI CETTE GARDE EXISTE
//
// `ZPageScaffold`/`ZPageShell` acceptent un `TabController` de l'hôte. Cette
// propriété a été mesurée vraie à l'exécution en v0.33.0 — mais **aucun test
// de ce paquet ne la gardait** (`grep tabController test/` → 0 résultat). Une
// propriété vraie et non gardée est une régression qui attend.
//
// L'enjeu est concret : chez l'hôte, l'onglet actif est commandé depuis TROIS
// seconds chemins (un sommaire en tiroir, une barre d'outils, une barre
// d'onglets parallèle). Si le paramètre devenait un passe-plat inerte, ces
// trois commandes deviendraient **muettes sans que rien ne le signale** — le
// symptôme exact décrit par CR-IFFD-38 : « une commande morte est plus
// coûteuse qu'une commande absente, parce qu'elle promet ».
//
// 🔴 CE QUE LA GARDE MESURE, ET POURQUOI PAS AUTRE CHOSE
//
// Elle ne vérifie NI que le paramètre existe, NI que `controller.index` a
// bougé : les deux resteraient vrais avec un paramètre inerte. Elle vérifie
// que **l'arbre rendu change** — seule preuve qu'une commande a agi.
//
// Elle est mordante par construction : quand un contrôleur est injecté, le
// shell **n'installe pas** de `DefaultTabController`. Un `TabBar`/`TabBarView`
// qui ne recevrait pas celui de l'hôte lèverait « No TabController for … ».
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Hôte qui **possède** le contrôleur dans un champ de `State`.
///
/// Jamais dans `build` : un contrôleur créé là est remplacé à chaque rebuild,
/// et la commande devient silencieusement inerte. C'est le défaut mesuré à
/// trois endroits chez l'hôte, que le socle refuse d'industrialiser.
class _Host extends StatefulWidget {
  const _Host({required this.mode});

  final ZPageAppBarMode mode;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: ZPageScaffold(
      title: 'Sonde',
      mode: widget.mode,
      tabController: controller,
      tabs: <ZPageTab>[
        ZPageTab(
          label: 'A',
          contentBuilder: (BuildContext _) => const Text('CONTENU-A'),
        ),
        ZPageTab(
          label: 'B',
          contentBuilder: (BuildContext _) => const Text('CONTENU-B'),
        ),
      ],
    ),
  );
}

void main() {
  group('🔴 CR-IFFD-38 — l\'onglet actif est commandable par l\'HÔTE', () {
    // Les quatre modes partagent les onglets mais PAS le chemin de
    // construction (fixe vs sliver) : un seul mode testé ne prouverait rien
    // des trois autres.
    for (final ZPageAppBarMode mode in ZPageAppBarMode.values) {
      testWidgets('mode ${mode.name} — animateTo change l\'ARBRE rendu', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_Host(mode: mode));

        // Contrôle NÉGATIF : sans quoi une garde qui trouverait B d'emblée
        // (les deux onglets montés) passerait sans qu'aucune commande n'agisse.
        expect(find.text('CONTENU-A'), findsOneWidget);
        expect(find.text('CONTENU-B'), findsNothing);

        final _HostState host = tester.state<_HostState>(find.byType(_Host));
        host.controller.animateTo(1);
        await tester.pumpAndSettle();

        expect(
          find.text('CONTENU-B'),
          findsOneWidget,
          reason:
              'la commande de l\'hôte doit agir sur le rendu — un paramètre '
              'accepté mais non consommé laisserait CONTENU-A à l\'écran',
        );
        expect(find.text('CONTENU-A'), findsNothing);
      });
    }

    testWidgets(
      'le shell N\'INSTALLE PAS de DefaultTabController quand l\'hôte en fournit un',
      (WidgetTester tester) async {
        await tester.pumpWidget(const _Host(mode: ZPageAppBarMode.fixed));

        // C'est ce qui rend les tests ci-dessus mordants : si le shell posait
        // son propre contrôleur par-dessus, les onglets basculeraient tout
        // seuls et la commande de l'hôte serait ignorée SANS ERREUR.
        expect(
          find.byType(DefaultTabController),
          findsNothing,
          reason:
              'un DefaultTabController installé masquerait le contrôleur de '
              'l\'hôte : la commande deviendrait inerte en silence',
        );
      },
    );

    testWidgets('sans contrôleur injecté, le shell reste autonome', (
      WidgetTester tester,
    ) async {
      // CONTRE-PREUVE : le chemin par défaut ne doit pas régresser.
      await tester.pumpWidget(
        MaterialApp(
          home: ZPageScaffold(
            title: 'Sonde',
            tabs: <ZPageTab>[
              ZPageTab(
                label: 'A',
                contentBuilder: (BuildContext _) => const Text('CONTENU-A'),
              ),
              ZPageTab(
                label: 'B',
                contentBuilder: (BuildContext _) => const Text('CONTENU-B'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('CONTENU-A'), findsOneWidget);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(find.text('CONTENU-B'), findsOneWidget);
    });
  });
}
