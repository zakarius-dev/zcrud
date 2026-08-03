/// Gardes du **raccordement `ZDisplayState`** des deux états d'affichage non
/// commandables de `zcrud_chat` : le **dépli d'un message**
/// (`ZChatMessageTile.expandController`) et le **mode sélection multiple**
/// (`ZChatConversationSelection.activeController`).
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 **L'ARBRE RENDU, jamais un champ.** Une garde qui se contenterait de lire
/// `controller.value` après une commande serait verte sur un composant qui
/// garde un **miroir** de l'état et ne l'écoute pas : le contrôleur bougerait,
/// l'écran non. C'est le défaut d'IFFD reconstitué (le `showAll` masquant
/// pilote la contrainte, le `showAll` masqué pilote le bouton). Chaque garde de
/// commande externe mesure donc soit une **hauteur** de tuile, soit la
/// **présence d'une surface** dans l'arbre.
///
/// 🔴 **Les DEUX sens.** Commande de l'hôte → arbre, ET geste interne →
/// contrôleur. Une seule direction laisserait passer un miroir à sens unique.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

String showMore = kZChatLabelFallbacks[kZChatLabelShowMore]!;
String showLess = kZChatLabelFallbacks[kZChatLabelShowLess]!;
String exitSelection = kZChatLabelFallbacks[kZChatLabelExitSelection]!;

/// Construction d'un contrôleur d'affichage — la forme INTERDITE dans `lib/`.
///
/// 🔴 `(<…>)?\s*\(` et non `[<(]` : `[<(]` prenait la **signature**
/// `zRegisterDisplayState(ZDisplayStateController<Object?> c)` pour une
/// construction (faux positif), et il fallait alors des exemptions — dont deux
/// se sont révélées **inatteignables**, donc du bruit qui masquait le motif
/// réel. Ici, une construction est un nom, un éventuel argument de type, puis
/// une parenthèse ouvrante.
final RegExp _construction =
    RegExp(r'\bZ(Toggle|Index|DisplayState)Controller(<[^;>]*>)?\s*\(');

ZChatConversation conv(String id, String title) => ZChatConversation(
  id: id,
  title: title,
  createdAt: DateTime.utc(2026, 8, 3),
  lastMessageAt: DateTime.utc(2026, 8, 3),
);

/// Hôte MINIMAL **conforme au patron** : le contrôleur est créé dans
/// `initState`, jamais dans `build`.
///
/// 🔒 C'est la clause 4 du contrat, et elle est **imposée** par
/// [ZDisplayStateOwnerMixin] : cet hôte ne compilerait pas autrement (le
/// constructeur du contrôleur exige un `owner`), et une création tardive dans
/// `build` lèverait au premier rebuild.
class ControllerHost extends StatefulWidget {
  /// Monte [child], construit avec le contrôleur possédé par cet hôte.
  const ControllerHost({
    required this.child,
    required this.onController,
    this.initial = false,
    super.key,
  });

  /// Construit le sous-arbre à partir du contrôleur possédé.
  final Widget Function(ZToggleController controller) child;

  /// Remet le contrôleur au test (une seule fois, à `initState`).
  final void Function(ZToggleController controller) onController;

  /// Valeur initiale du contrôleur — un hôte a le droit d'arriver « déjà
  /// ouvert » (restauration de session).
  final bool initial;

  @override
  State<ControllerHost> createState() => ControllerHostState();
}

/// L'état de [ControllerHost] — porte la possession (AD-2 : hors `build`).
class ControllerHostState extends State<ControllerHost>
    with ZDisplayStateOwnerMixin<ControllerHost> {
  /// Le contrôleur possédé.
  late final ZToggleController controller;

  /// Nombre de rebuilds — sert aux gardes de stabilité.
  int builds = 0;

  @override
  void initState() {
    super.initState();
    controller = ZToggleController(
      owner: this,
      initialValue: widget.initial,
      debugLabel: 'test',
    );
    widget.onController(controller);
  }

  /// Force un rebuild de l'hôte (sans rien changer d'autre).
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    builds++;
    return widget.child(controller);
  }
}

/// Hôte possédant **DEUX** contrôleurs et n'en passant qu'un à la fois.
///
/// 🔴 Deux hôtes successifs ne conviendraient pas : le premier serait `dispose`,
/// et son contrôleur avec lui — la garde ne pourrait plus prouver que l'ANCIEN
/// est devenu muet, elle mesurerait un objet mort.
class TwoControllerHost extends StatefulWidget {
  /// Monte la tuile pilotée par le premier ou le second contrôleur.
  const TwoControllerHost({
    required this.useSecond,
    required this.onReady,
    super.key,
  });

  /// `true` ⇒ la tuile reçoit le SECOND contrôleur.
  final bool useSecond;

  /// Remet les deux contrôleurs au test.
  final void Function(ZToggleController a, ZToggleController b) onReady;

  @override
  State<TwoControllerHost> createState() => _TwoControllerHostState();
}

class _TwoControllerHostState extends State<TwoControllerHost>
    with ZDisplayStateOwnerMixin<TwoControllerHost> {
  late final ZToggleController a;
  late final ZToggleController b;

  @override
  void initState() {
    super.initState();
    a = ZToggleController(owner: this, debugLabel: 'a');
    b = ZToggleController(owner: this, debugLabel: 'b');
    widget.onReady(a, b);
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topStart,
    child: ZChatMessageTile(
      message: assistant(<ZContentBlock>[longText(20)]),
      collapsedMaxHeight: 60,
      expandController: widget.useSecond ? b : a,
    ),
  );
}

/// Hôte qui possède le contrôleur **et** la sélection — les deux hors `build`.
class SelectionHost extends StatefulWidget {
  /// Monte une liste de conversations pilotée par un contrôleur de mode.
  const SelectionHost({required this.items, required this.onReady, super.key});

  /// Les conversations rendues.
  final List<ZChatConversation> items;

  /// Remet le contrôleur et la sélection au test.
  final void Function(
    ZToggleController controller,
    ZChatConversationSelection selection,
  ) onReady;

  @override
  State<SelectionHost> createState() => _SelectionHostState();
}

class _SelectionHostState extends State<SelectionHost>
    with ZDisplayStateOwnerMixin<SelectionHost> {
  late final ZToggleController controller;
  late final ZChatConversationSelection selection;

  @override
  void initState() {
    super.initState();
    controller = ZToggleController(owner: this, debugLabel: 'selection');
    // 🔴 Hors `build` : une sélection reconstruite à chaque frame perdrait ses
    // identités — la dette exacte que `ZChatConversationSelection` documente.
    selection = ZChatConversationSelection(activeController: controller);
    widget.onReady(controller, selection);
  }

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZChatConversationList(
    items: widget.items,
    selection: selection,
  );
}

/// Monte une tuile de message dépliable, éventuellement pilotée.
Widget tileTree({
  ZToggleController? controller,
  double collapsedMaxHeight = 60,
  int lines = 20,
}) => harness(
  Align(
    alignment: AlignmentDirectional.topStart,
    child: ZChatMessageTile(
      // 20 lignes, pas 40 : au-delà, la surface de test de 600 dp ÉCRASERAIT
      // les deux états à la même hauteur (patron de la garde G-R4).
      message: assistant(<ZContentBlock>[longText(lines)]),
      collapsedMaxHeight: collapsedMaxHeight,
      expandController: controller,
    ),
  ),
);

void main() {
  group('🔴 G-DS1 — SANS contrôleur, la tuile est STRICTEMENT inchangée', () {
    testWidgets('mêmes textes et même hauteur qu\'avec un contrôleur au repos',
        (WidgetTester t) async {
      await t.pumpWidget(tileTree());
      await t.pumpAndSettle();
      final Finder tile = find.byType(ZChatMessageTile);
      final double heightAlone = t.getSize(tile).height;
      final List<String> textsAlone = renderedTexts(t);
      expect(textsAlone, contains(showMore));

      late ZToggleController c;
      await t.pumpWidget(
        harness(
          ControllerHost(
            onController: (ZToggleController x) => c = x,
            child: (ZToggleController x) => Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
                expandController: x,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, heightAlone,
          reason: '🔴 le seul fait de FOURNIR un contrôleur (au repos) a changé '
              'le rendu : le point d\'entrée optionnel d\'AD-4 n\'est plus '
              'neutre.');
      expect(renderedTexts(t), textsAlone);
      expect(c.value, isFalse);
    });

    testWidgets('le geste interne fonctionne toujours seul (dépli réel)',
        (WidgetTester t) async {
      await t.pumpWidget(tileTree());
      await t.pumpAndSettle();
      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = t.getSize(tile).height;
      await t.tap(find.text(showMore));
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, greaterThan(collapsed),
          reason: '🔴 le raccordement a CASSÉ le dépli sans contrôleur — le '
              'défaut d\'origine, réintroduit par son propre correctif.');
    });
  });

  group('🔴 G-DS2 — AVEC contrôleur, la commande de l\'hôte agit sur l\'ARBRE',
      () {
    testWidgets('`set()`/`clear()` déplient et replient RÉELLEMENT la tuile',
        (WidgetTester t) async {
      late ZToggleController c;
      await t.pumpWidget(
        harness(
          ControllerHost(
            onController: (ZToggleController x) => c = x,
            child: (ZToggleController x) => Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
                expandController: x,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = t.getSize(tile).height;
      expect(find.text(showMore), findsOneWidget);

      // 🔴 AUCUN geste sur l'arbre : la seule commande est celle de l'hôte.
      c.set();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, greaterThan(collapsed),
          reason: '🔴 le bouton « tout déplier » de l\'hôte est un BOUTON MORT : '
              'le contrôleur bouge, la CONTRAINTE DE HAUTEUR ne bouge pas. '
              'C\'est exactement le divorce `showAll` d\'IFFD, une couche plus '
              'haut.');
      expect(find.text(showLess), findsOneWidget,
          reason: '🔴 le libellé du bouton annonce encore « déplier » sur un '
              'message déjà déplié.');

      c.clear();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, collapsed,
          reason: '🔴 la commande de repli de l\'hôte n\'est pas suivie.');
      expect(find.text(showMore), findsOneWidget);
    });

    testWidgets('un contrôleur arrivé DÉJÀ déplié rend la tuile dépliée dès la '
        'première frame', (WidgetTester t) async {
      await t.pumpWidget(tileTree());
      await t.pumpAndSettle();
      final double collapsed = t.getSize(find.byType(ZChatMessageTile)).height;

      await t.pumpWidget(
        harness(
          ControllerHost(
            initial: true,
            onController: (ZToggleController _) {},
            child: (ZToggleController x) => Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
                expandController: x,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(ZChatMessageTile)).height,
          greaterThan(collapsed),
          reason: '🔴 la tuile part REPLIÉE alors que sa source de vérité dit '
              'dépliée : un miroir initialisé à `false` a écrasé l\'état de '
              'l\'hôte.');
    });
  });

  group('🔴 G-DS3 — le geste INTERNE s\'écrit à la SOURCE (lisible par l\'hôte)',
      () {
    testWidgets('taper « Afficher plus » écrit dans le contrôleur ET le notifie',
        (WidgetTester t) async {
      late ZToggleController c;
      final List<bool> seen = <bool>[];
      await t.pumpWidget(
        harness(
          ControllerHost(
            onController: (ZToggleController x) {
              c = x;
              x.addListener(() => seen.add(x.value));
            },
            child: (ZToggleController x) => Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
                expandController: x,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.text(showMore));
      await t.pumpAndSettle();
      expect(c.value, isTrue,
          reason: '🔴 le tap a écrit dans un MIROIR local : la barre d\'outils '
              'de l\'hôte annoncera « déplier » sur un message déjà déplié — '
              'deux états qui divergent, ce que le contrat interdit.');
      expect(seen, <bool>[true],
          reason: '🔴 le geste interne est MUET pour l\'hôte.');

      await t.tap(find.text(showLess));
      await t.pumpAndSettle();
      expect(c.value, isFalse);
      expect(seen, <bool>[true, false]);
    });

    testWidgets('l\'hôte peut CHANGER de contrôleur : le nouveau commande, '
        'l\'ancien est muet', (WidgetTester t) async {
      late ZToggleController first;
      late ZToggleController second;
      Widget tree({required bool useSecond}) => harness(
        TwoControllerHost(
          useSecond: useSecond,
          onReady: (ZToggleController a, ZToggleController b) {
            first = a;
            second = b;
          },
        ),
      );

      await t.pumpWidget(tree(useSecond: false));
      await t.pumpAndSettle();
      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = t.getSize(tile).height;
      first.set();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, greaterThan(collapsed));

      // L'hôte remplace son pilote. Le nouveau est au repos ⇒ la tuile se
      // replie, et c'est LUI qui commande désormais.
      await t.pumpWidget(tree(useSecond: true));
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, collapsed,
          reason: '🔴 la tuile suit encore l\'ANCIEN contrôleur.');
      first.set();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, collapsed,
          reason: '🔴 l\'ancien contrôleur commande TOUJOURS : la tuile a deux '
              'pilotes, donc aucun.');
      second.set();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, greaterThan(collapsed),
          reason: '🔴 le NOUVEAU contrôleur ne commande pas.');
    });

    testWidgets('les rebuilds de l\'hôte ne perdent NI l\'état NI la liaison',
        (WidgetTester t) async {
      late ZToggleController c;
      final GlobalKey<ControllerHostState> key =
          GlobalKey<ControllerHostState>();
      await t.pumpWidget(
        harness(
          ControllerHost(
            key: key,
            onController: (ZToggleController x) => c = x,
            child: (ZToggleController x) => Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
                expandController: x,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = t.getSize(tile).height;
      c.set();
      await t.pumpAndSettle();
      final double expanded = t.getSize(tile).height;

      for (int i = 0; i < 5; i++) {
        key.currentState!.rebuild();
        await t.pumpAndSettle();
      }
      expect(key.currentState!.builds, greaterThan(5),
          reason: '🔴 GARDE VACUELLE : l\'hôte n\'a pas réellement reconstruit');
      expect(t.getSize(tile).height, expanded,
          reason: '🔴 l\'état de dépli a SAUTÉ à un rebuild de l\'hôte — la '
              'signature exacte d\'un contrôleur (ou d\'une liaison) recréé '
              'dans `build`.');
      expect(expanded, greaterThan(collapsed));

      // 🔴 La LIAISON survit-elle, ou seulement la VALEUR ? Un composant qui
      // aurait recréé sa liaison au rebuild peut très bien afficher encore le
      // bon état (il l'a recopié) tout en ayant perdu son pilote. On mesure
      // donc la commande, dans les DEUX sens, APRÈS les rebuilds.
      c.clear();
      await t.pumpAndSettle();
      expect(t.getSize(tile).height, collapsed,
          reason: '🔴 après quelques rebuilds de l\'hôte, sa commande n\'atteint '
              'plus l\'arbre : la liaison a été refaite, l\'état recopié.');
      await t.tap(find.text(showMore));
      await t.pumpAndSettle();
      expect(c.value, isTrue,
          reason: '🔴 après quelques rebuilds, le geste interne n\'est plus '
              'écrit à la source : l\'hôte a cessé de voir les taps.');
    });
  });

  group('🔴 G-DS4 — SANS contrôleur, la SÉLECTION est strictement inchangée',
      () {
    testWidgets('appui long ⇒ mode ; « Quitter » ⇒ sortie et sélection vidée',
        (WidgetTester t) async {
      final ZChatConversationSelection sel = ZChatConversationSelection();
      addTearDown(sel.dispose);
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[conv('a', 'Alpha'), conv('b', 'Bravo')],
            selection: sel,
          ),
        ),
      );
      expect(find.text(exitSelection), findsNothing);
      await t.longPress(find.text('Alpha'));
      await t.pump();
      expect(sel.active, isTrue);
      expect(find.text(exitSelection), findsOneWidget);
      await t.tap(find.text(exitSelection));
      await t.pump();
      expect(sel.active, isFalse);
      expect(sel.count, 0);
      expect(find.text(exitSelection), findsNothing);
    });
  });

  group('🔴 G-DS5 — AVEC contrôleur, l\'hôte COMMANDE le mode sélection', () {
    testWidgets('`set()` fait APPARAÎTRE la barre, `clear()` la fait '
        'DISPARAÎTRE de l\'arbre', (WidgetTester t) async {
      late ZToggleController c;
      late ZChatConversationSelection sel;
      await t.pumpWidget(
        harness(
          SelectionHost(
            items: <ZChatConversation>[conv('a', 'Alpha'), conv('b', 'Bravo')],
            onReady: (ZToggleController x, ZChatConversationSelection s) {
              c = x;
              sel = s;
            },
          ),
        ),
      );
      await t.pump();
      expect(find.text(exitSelection), findsNothing);

      // 🔴 La commande de l'hôte, seule — aucun appui long.
      c.set();
      await t.pump();
      expect(find.text(exitSelection), findsOneWidget,
          reason: '🔴 l\'hôte ne peut pas ENTRER en mode sélection : sa barre '
              'reste absente alors que sa source de vérité dit « actif ».');
      expect(sel.active, isTrue,
          reason: '🔴 la sélection garde un MIROIR de son mode.');

      c.clear();
      await t.pump();
      expect(find.text(exitSelection), findsNothing,
          reason: '🔴 le « Annuler » de la barre d\'app de l\'hôte est un '
              'BOUTON MORT : la barre de sélection reste montée.');
      expect(sel.active, isFalse);
    });

    testWidgets('le geste INTERNE (appui long) s\'écrit dans le contrôleur',
        (WidgetTester t) async {
      late ZToggleController c;
      await t.pumpWidget(
        harness(
          SelectionHost(
            items: <ZChatConversation>[conv('a', 'Alpha')],
            onReady: (ZToggleController x, ZChatConversationSelection _) =>
                c = x,
          ),
        ),
      );
      await t.pump();
      expect(c.value, isFalse);

      await t.longPress(find.text('Alpha'));
      await t.pump();
      expect(c.value, isTrue,
          reason: '🔴 l\'appui long a écrit dans un MIROIR : la barre d\'app de '
              'l\'hôte ne sait pas que l\'écran est entré en sélection, et son '
              '« Annuler » n\'apparaîtra jamais.');

      await t.tap(find.text(exitSelection));
      await t.pump();
      expect(c.value, isFalse,
          reason: '🔴 la sortie par le bouton du socle laisse le contrôleur de '
              'l\'hôte à « actif » — deux états divergents.');
    });
  });

  group('🔴 G-DS6 — la NOTIFICATION SORTANTE est conservée sur TOUS les chemins',
      () {
    test('une commande externe notifie les auditeurs de la sélection', () {
      final _Owner owner = _Owner();
      final ZToggleController c = ZToggleController(owner: owner);
      final ZChatConversationSelection sel =
          ZChatConversationSelection(activeController: c);
      int notified = 0;
      sel.addListener(() => notified++);

      c.set();
      expect(notified, 1,
          reason: '🔴 la liste ne sera PAS reconstruite sur une commande de '
              'l\'hôte : l\'écoute passe par `notifyListeners`, et ce chemin '
              'est resté MUET.');
      c.clear();
      expect(notified, 2);

      // Une écriture sans changement ne notifie pas (contrat du contrôleur).
      c.clear();
      expect(notified, 2);

      sel.dispose();
      c.dispose();
    });

    test('les chemins INTERNES notifient exactement comme avant', () {
      final ZChatConversationSelection sel = ZChatConversationSelection();
      int notified = 0;
      sel.addListener(() => notified++);
      sel.begin('a');
      expect(notified, 1);
      sel.begin('a'); // idempotent, rien de neuf
      expect(notified, 1);
      sel.begin('b');
      expect(notified, 2);
      sel.toggle('b');
      expect(notified, 3);
      sel.clear();
      expect(notified, 4);
      sel.clear();
      expect(notified, 4);
      sel.dispose();
    });
  });

  group('🔴 G-DS7 — SORTIR du mode VIDE la sélection, d\'où que vienne la '
      'sortie', () {
    test('sortie INTERNE (`clear`) : mode et contenu retombent ensemble', () {
      final ZChatConversationSelection sel = ZChatConversationSelection()
        ..begin('a')
        ..begin('b');
      expect(sel.count, 2);
      sel.clear();
      expect(sel.active, isFalse);
      expect(sel.count, 0);
      sel.dispose();
    });

    test('sortie EXTERNE : le contrôleur commande le MODE, et la sélection est '
        'vidée avec lui', () {
      final _Owner owner = _Owner();
      final ZToggleController c = ZToggleController(owner: owner);
      final ZChatConversationSelection sel =
          ZChatConversationSelection(activeController: c);
      sel
        ..begin('a')
        ..begin('b');
      expect(sel.count, 2);
      expect(c.value, isTrue);

      c.clear();
      expect(sel.active, isFalse);
      expect(sel.count, 0,
          reason: '🔴 la barre a disparu en laissant DEUX identités cochées '
              'derrière elle : le prochain appui long ressusciterait une '
              'sélection fantôme, et un « retirer la sélection » supprimerait '
              'des conversations que l\'utilisateur croit désélectionnées.');
      expect(sel.selectedIds, isEmpty);

      // Le contenu, lui, reste la propriété de la sélection : le contrôleur ne
      // le commande pas.
      c.set();
      expect(sel.active, isTrue);
      expect(sel.count, 0);
      sel.dispose();
      c.dispose();
    });

    testWidgets('…et l\'ARBRE le reflète : plus de barre, plus de compte',
        (WidgetTester t) async {
      late ZToggleController c;
      late ZChatConversationSelection sel;
      await t.pumpWidget(
        harness(
          SelectionHost(
            items: <ZChatConversation>[conv('a', 'Alpha'), conv('b', 'Bravo')],
            onReady: (ZToggleController x, ZChatConversationSelection s) {
              c = x;
              sel = s;
            },
          ),
        ),
      );
      await t.longPress(find.text('Alpha'));
      await t.pump();
      await t.tap(find.text('Bravo'));
      await t.pump();
      expect(find.text('2 sélectionnée(s)'), findsOneWidget);

      c.clear();
      await t.pump();
      expect(find.text('2 sélectionnée(s)'), findsNothing);
      expect(find.text(exitSelection), findsNothing);
      expect(sel.count, 0);
    });
  });

  group('🔴 G-DS8 — le socle ne CRÉE aucun contrôleur d\'affichage', () {
    test('grep NÉGATIF : aucune construction dans `lib/`', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          scanned++;
          final String line = e.value[i];
          // Seule une CONSTRUCTION est interdite : la DÉCLARATION d'un
          // paramètre ou d'un champ EST le point d'entrée, elle est légitime.
          if (!_construction.hasMatch(line)) continue;
          offenders.add('${e.key}:${i + 1} → ${line.trim()}');
        }
      }
      expect(scanned, greaterThan(500),
          reason: '🔴 GARDE VACUELLE : $scanned ligne(s) scannée(s)');
      expect(offenders, isEmpty,
          reason: '🔴 le socle POSSÈDE un état d\'affichage piloté : le cycle '
              'de vie appartient à l\'hôte (clause 4), et un contrôleur créé '
              'ici serait détruit à chaque reconstruction du composant.\n'
              '${offenders.join('\n')}');
    });

    test('🔬 contre-preuve R3 — le motif VOIT une construction, y compris '
        'GÉNÉRIQUE, et ne prend pas un TYPE pour elle', () {
      for (final String hit in <String>[
        '    _c = ZToggleController(owner: this);',
        '  final ZIndexController _i = ZIndexController(owner: this);',
        // 🔴 La forme générique : sans elle, la garde serait verte sur une
        // construction du contrôleur de base.
        '    final c = ZDisplayStateController<bool>(owner: o, initialValue: false);',
      ]) {
        expect(_construction.hasMatch(hit), isTrue,
            reason: '🔴 le motif ne voit pas la construction qu\'il interdit — '
                'la garde serait verte sur le défaut exact : $hit');
      }
      for (final String ok in <String>[
        '  final ZToggleController? expandController;',
        '  ZChatConversationSelection({ZToggleController? activeController}) {',
        // Un TYPE en signature n'est pas une construction, fût-il générique.
        '  void zRegisterDisplayState(ZDisplayStateController<Object?> c);',
      ]) {
        expect(_construction.hasMatch(ok), isFalse,
            reason: '🔴 le motif prend une DÉCLARATION pour une construction : '
                'la garde interdirait le point d\'entrée lui-même : $ok');
      }
    });
  });
}

/// Propriétaire minimal pour les gardes **hors widget** (pas de `State` en jeu).
///
/// ⚠️ Il n'applique pas la borne temporelle du mixin : c'est délibéré, ces
/// gardes-là ne mesurent pas la possession — celles de G-DS3 (« rebuilds »)
/// s'en chargent, sur l'arbre.
class _Owner implements ZDisplayStateOwner {
  @override
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller) {}
}
