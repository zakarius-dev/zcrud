/// 🔴 Garde ANTI-NO-OP SILENCIEUX — l'entrée devenue « périmée » par un rebuild.
///
/// Défaut MESURÉ pendant CHAT-4b (migration de `ZItemActionsMenu`) : trois
/// gardes de `zcrud_study` sont passées au ROUGE parce que taper une entrée de
/// menu n'invoquait PLUS RIEN. Cause : `ZActionMenu.select` filtrait par
/// `visible.contains(entry)`, et `ZMenuEntry.==` compare `onSelected` — donc
/// une **identité de closure**. Or :
///
/// * la surface flottante capture la valeur de l'entrée à l'OUVERTURE
///   (`itemBuilder`), tandis que `PopupMenuButton` lit `widget.onSelected` à la
///   SÉLECTION ;
/// * tout hôte qui déclare ses entrées avec des closures en ligne
///   (`onSelected: () => faire(x)`, le patron NORMAL — celui de
///   `ZFlashcardListView`) en fabrique de NEUVES à chaque rebuild ;
/// * un rebuild pendant que le menu est ouvert (poussée de route, focus,
///   `setState` de l'hôte…) suffit donc à rendre l'entrée capturée « non
///   contenue » dans la liste courante.
///
/// Résultat : `contains` faux ⇒ `return` ⇒ **rien ne se passe, sans aucune
/// trace**. Exactement le « no-op silencieux » que AD-4 proscrit, arrivé par la
/// porte de derrière du garde-fou censé le prévenir.
///
/// Ces gardes verrouillent la résolution actuelle : l'entrée sélectionnée est
/// RÉSOLUE dans la liste visible COURANTE (identité, puis `id`+`label`), et
/// c'est l'effet de CETTE entrée-là qui est invoqué — jamais celui porté par la
/// valeur reçue. Un renderer ne peut donc toujours pas injecter un effet à lui
/// (garde d'origine préservée), et un rebuild ne peut plus tuer la sélection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

/// Hôte qui REBUILD pendant que le menu est ouvert, en refabriquant ses
/// closures — le patron de `ZFlashcardListView`, jamais un cas de laboratoire.
class _HoteQuiRebuild extends StatefulWidget {
  const _HoteQuiRebuild({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  State<_HoteQuiRebuild> createState() => _HoteQuiRebuildState();
}

class _HoteQuiRebuildState extends State<_HoteQuiRebuild> {
  int _tick = 0;

  /// Déclenche un rebuild depuis l'EXTÉRIEUR de l'arbre du menu.
  void rebuild() => setState(() => _tick++);

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text('tick $_tick'),
          ZActionMenu(
            trigger: const ZMenuTrigger(
              icon: Icons.more_vert,
              semanticLabel: 'ACTIONS',
            ),
            entries: <ZMenuEntry>[
              ZMenuEntry(
                id: ZMenuEntryIds.open,
                label: 'OUVRIR-XYZ',
                // 🔴 Closure NEUVE à chaque build — le patron normal.
                onSelected: () => widget.onOpen(),
              ),
            ],
          ),
        ],
      );
}

void main() {
  testWidgets(
      '🔴 un rebuild de l\'hôte pendant que le menu est OUVERT ne tue pas la '
      'sélection (no-op silencieux)', (tester) async {
    var ouvertures = 0;
    final key = GlobalKey<_HoteQuiRebuildState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _HoteQuiRebuild(key: key, onOpen: () => ouvertures++),
      ),
    ));

    await tester.tap(find.byType(ZActionMenu));
    await tester.pumpAndSettle();
    expect(find.text('OUVRIR-XYZ'), findsOneWidget,
        reason: 'sonde : la surface doit être RÉELLEMENT ouverte');

    // 🔴 Le rebuild : l'entrée capturée par la surface flottante porte
    // désormais une closure DIFFÉRENTE de celle de la liste courante.
    key.currentState!.rebuild();
    await tester.pump();
    expect(find.text('tick 1'), findsOneWidget, reason: 'sonde : rebuild réel');

    await tester.tap(find.text('OUVRIR-XYZ'));
    await tester.pumpAndSettle();

    expect(ouvertures, 1,
        reason: '🔴 0 ⇒ la sélection a été SILENCIEUSEMENT avalée par le '
            'filtre de `select` ; 2 ⇒ double invocation.');
  });

  testWidgets(
      'l\'effet invoqué est celui de la liste COURANTE, pas de la valeur '
      'périmée', (tester) async {
    // Deux compteurs : si l'effet PÉRIMÉ était invoqué, c'est `avant` qui
    // monterait. Sans cette distinction, « ça marche » serait indiscernable de
    // « ça marche mais avec l'ancien callback ».
    var avant = 0;
    var apres = 0;
    var courant = () => avant++;
    late StateSetter setter;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            setter = setState;
            return ZActionMenu(
              trigger: const ZMenuTrigger(
                icon: Icons.more_vert,
                semanticLabel: 'ACTIONS',
              ),
              entries: <ZMenuEntry>[
                ZMenuEntry(
                  id: ZMenuEntryIds.open,
                  label: 'OUVRIR-XYZ',
                  onSelected: () => courant(),
                ),
              ],
            );
          },
        ),
      ),
    ));

    await tester.tap(find.byType(ZActionMenu));
    await tester.pumpAndSettle();

    setter(() => courant = () => apres++);
    await tester.pump();

    await tester.tap(find.text('OUVRIR-XYZ'));
    await tester.pumpAndSettle();

    expect(apres, 1, reason: '🔴 l\'effet COURANT doit être invoqué');
    expect(avant, 0, reason: '🔴 l\'effet périmé ne doit pas l\'être');
  });

  testWidgets(
      '🔴 la garde d\'origine TIENT : un renderer ne peut pas injecter un '
      'effet à lui', (tester) async {
    var vrai = 0;
    var fabrique = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZActionMenu(
          renderer: _RendererFabricateur(() => fabrique++),
          trigger: const ZMenuTrigger(
            icon: Icons.more_vert,
            semanticLabel: 'ACTIONS',
          ),
          entries: <ZMenuEntry>[
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'OUVRIR-XYZ',
              onSelected: () => vrai++,
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('DECLENCHEUR-ESPION'));
    await tester.pump();

    expect(fabrique, 0,
        reason: '🔴 l\'effet FABRIQUÉ par le renderer ne doit JAMAIS être '
            'exécuté — c\'est la raison d\'être du filtre de `select`');
    expect(vrai, 1,
        reason: 'l\'entrée est résolue par son identité déclarée (id+label) : '
            'c\'est l\'effet DÉCLARÉ par l\'appelant qui s\'exécute');
  });

  testWidgets('🔴 une entrée INCONNUE reste sans effet', (tester) async {
    var fabrique = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZActionMenu(
          renderer: _RendererFabricateur(() => fabrique++, id: 'INCONNU'),
          trigger: const ZMenuTrigger(
            icon: Icons.more_vert,
            semanticLabel: 'ACTIONS',
          ),
          entries: <ZMenuEntry>[
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'OUVRIR-XYZ',
              onSelected: () {},
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('DECLENCHEUR-ESPION'));
    await tester.pump();

    expect(fabrique, 0, reason: '🔴 une entrée hors liste n\'a aucun effet');
  });
}

/// Renderer HOSTILE : il fabrique sa propre entrée, avec son propre effet, et la
/// passe à `select`. Le socle doit refuser d'exécuter CET effet-là.
class _RendererFabricateur extends ZMenuRenderer {
  const _RendererFabricateur(this.effetFabrique, {this.id = ZMenuEntryIds.open});

  final VoidCallback effetFabrique;
  final String id;

  @override
  Widget build(BuildContext context, ZMenuRequest request) => GestureDetector(
        onTap: () => request.select(
          ZMenuEntry(
            id: id,
            label: 'OUVRIR-XYZ',
            onSelected: effetFabrique,
          ),
        ),
        child: const Text('DECLENCHEUR-ESPION'),
      );
}
