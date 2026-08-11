/// Tuile neutre d'un message, et le dépli inline réel.
///
/// ## Le défaut structurel que ce fichier rend inexprimable
///
/// Un défaut classique de dépli inline : deux variables d'état homonymes
/// coexistent, l'une portant l'état réel du dépli, l'autre — dans une
/// closure imbriquée — le masquant silencieusement. La contrainte de hauteur
/// lit l'une, le bouton de bascule l'autre. Conséquence : basculer le
/// dépli ne relâche jamais la contrainte, et le bouton finit par déclencher
/// un geste totalement différent de celui promis par son libellé.
///
/// Le correctif structurel n'est pas « renommer une variable » : c'est que
/// l'état du dépli et la contrainte de hauteur soient lus au même endroit,
/// sur la même source. Ici, [_ZCollapsibleContent] reçoit `expanded` et
/// applique la contrainte lui-même ; il n'existe aucun second chemin qui
/// puisse diverger. Le dépli augmente la hauteur de la tuile et ne pousse
/// aucune route.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../render/z_chat_accessible_text_scope.dart';
import '../render/z_chat_render_request.dart';
import '../render/z_chat_seam_failure.dart';
import 'z_chat_block_view.dart';
import 'z_chat_labels.dart';

/// Construit le contenu d'un créneau par message — couture d'hôte, sur le
/// modèle des builders de seam existants.
///
/// Un builder, jamais un jeu de booléens. L'identité d'un interlocuteur
/// (avatar, nom) est une décision d'apparence que le socle refuse par
/// construction de porter. Il offre à la place un emplacement structurel :
/// l'hôte construit ce qu'il veut y voir, le socle décide seulement où cela
/// se rend.
///
/// Rendre `null` signifie aucun widget inséré pour ce message (invariant
/// AD-4 : slot nul, absent de l'arbre) — c'est ce qui permet à un même
/// builder de ne cibler que les réponses de l'assistant, par exemple.
typedef ZChatMessageSlotBuilder =
    Widget? Function(BuildContext context, ZChatMessage message);

/// Hauteur de cible tactile minimale (invariant AD-13). Ce n'est pas un
/// style : c'est un seuil d'accessibilité, non négociable et donc non
/// injectable.
const double kZChatMinTapTarget = 48.0;

/// Tolérance de mesure du dépassement, en pixels logiques. Sans elle, un
/// contenu qui fait EXACTEMENT la hauteur repliée (au bruit d'arrondi près)
/// afficherait un « Afficher plus » sans rien à déplier.
const double _kOverflowEpsilon = 0.5;

/// Rend un message : ses blocs, et — si l'hôte a fixé une hauteur repliée — un
/// dépli **inline**.
class ZChatMessageTile extends StatefulWidget {
  /// Construit la tuile d'un message.
  const ZChatMessageTile({
    required this.message,
    this.collapsedMaxHeight,
    this.isStreaming = false,
    this.expandController,
    this.identityBuilder,
    this.actionsBuilder,
    super.key,
  });

  /// Le message rendu.
  final ZChatMessage message;

  /// Hauteur maximale à l'état replié. `null` signifie aucun repli, aucun
  /// bouton (le comportement par défaut est le message entier : on ne
  /// tronque pas un contenu sans que l'hôte l'ait demandé).
  final double? collapsedMaxHeight;

  /// `true` si ce message est une réponse encore en cours.
  final bool isStreaming;

  /// Pilotage externe du dépli — `null` signifie que la tuile se gouverne
  /// seule (comportement par défaut).
  ///
  /// ## Pourquoi ce paramètre existe
  ///
  /// Sans lui, le dépli n'est commandable que depuis son propre bouton : un
  /// hôte qui veut un « tout déplier » dans sa barre d'outils, ou déplier le
  /// message qu'une recherche vient de cibler, n'a aucun second chemin de
  /// déclenchement.
  ///
  /// ## Le contrat
  ///
  /// Fourni, le contrôleur devient la source de vérité : la tuile ne garde
  /// aucun miroir du dépli (cf. [ZDisplayStateBinding]), donc les deux états
  /// ne peuvent pas diverger, parce qu'il n'y en a qu'un. Le tap sur
  /// « Afficher plus » écrit dans le contrôleur — l'hôte lit donc le geste
  /// interne sans qu'aucun callback ne soit nécessaire.
  ///
  /// Sans [collapsedMaxHeight], il n'y a ni repli ni bouton : le contrôleur
  /// est alors accepté mais sans effet visible.
  ///
  /// Le contrôleur doit être possédé hors de `build` : c'est imposé par
  /// [ZDisplayStateOwnerMixin], qui refuse un enregistrement postérieur à la
  /// première frame de son `State`. Un contrôleur créé dans `build` serait
  /// remplacé à chaque rebuild — donc silencieusement inerte.
  final ZToggleController? expandController;

  /// Créneau d'identité — rendu au-dessus des blocs.
  ///
  /// Ce builder comble une présence structurelle sans jamais décider de
  /// l'apparence : avatar, nom, les deux, ou rien — c'est le widget de
  /// l'hôte.
  ///
  /// `null` (défaut) donne un comportement strictement inchangé. Un builder
  /// qui rend `null` pour un message signifie aucun en-tête pour ce message
  /// (invariant AD-4).
  final ZChatMessageSlotBuilder? identityBuilder;

  /// Créneau d'actions par message — rendu sous les blocs, hors de la zone
  /// repliable (une action ne doit jamais être tronquée par le repli, ni
  /// cliquable sous un clip).
  ///
  /// Le socle ne connaît aucun verbe ici : les capacités de transformation
  /// (carte mentale, flashcards, variantes, export, enregistrer en note) se
  /// montent par ce conteneur, et leurs rappels transitent par
  /// `ZChatController.runAction(ZChatCustomAction(...))` — l'unique point
  /// d'entrée des verbes. Aucun nouveau chemin d'exécution.
  ///
  /// `null` (défaut) donne un comportement strictement inchangé.
  final ZChatMessageSlotBuilder? actionsBuilder;

  @override
  State<ZChatMessageTile> createState() => _ZChatMessageTileState();
}

class _ZChatMessageTileState extends State<ZChatMessageTile> {
  /// `ValueNotifier` et non `setState` (invariant AD-2) : basculer le dépli
  /// d'une tuile ne doit pas reconstruire la conversation. `setState` ici
  /// remonterait au `build` de la tuile entière, blocs compris.
  ///
  /// C'est une liaison, pas un simple `ValueNotifier` privé : état interne
  /// par défaut, contrôleur de l'hôte quand il y en a un. La liaison ne
  /// copie rien — quand l'hôte pilote, la valeur est lue et écrite chez lui.
  /// `_expanded.listenable` reste stable au travers d'un changement de
  /// contrôleur, ce qui évite un `setState` d'échelle tuile.
  late final ZDisplayStateBinding<bool> _expanded;

  /// `true` quand le contenu **dépasse réellement** la hauteur repliée. Mesuré
  /// à la mise en page, pas deviné : sans cela, un message d'une ligne
  /// afficherait « Afficher plus » sans rien avoir à déplier.
  final ValueNotifier<bool> _overflowed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _expanded = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
      ..bind(widget.expandController);
  }

  @override
  void didUpdateWidget(covariant ZChatMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son pilote — sans quoi la
    // tuile resterait branchée sur l'ancien, muette pour le nouveau.
    _expanded.bind(widget.expandController);
  }

  @override
  void dispose() {
    // La liaison ne dispose jamais le contrôleur de l'hôte : il ne nous
    // appartient pas (son propriétaire est un `State` de l'hôte).
    _expanded.dispose();
    _overflowed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Widget content = _announced(
      context,
      _ZBlocks(
        message: widget.message,
        isStreaming: widget.isStreaming,
        theme: theme,
      ),
    );

    final double? maxHeight = widget.collapsedMaxHeight;
    final Widget core = maxHeight == null
        ? content
        : _collapsible(content, maxHeight);

    // Créneaux additifs. Construits ici, dans `build`, donc hors du
    // `ValueListenableBuilder` du dépli : basculer « Afficher plus » ne
    // ré-invoque aucun builder d'hôte (invariant AD-2). Aucun créneau
    // signifie que l'arbre rendu reste exactement celui sans ces créneaux —
    // pas même une `Column` de plus.
    final Widget? identity = _slot(
      context,
      widget.identityBuilder,
      kZChatSeamIdentitySlot,
    );
    final Widget? actions = _slot(
      context,
      widget.actionsBuilder,
      kZChatSeamActionsSlot,
    );
    if (identity == null && actions == null) return core;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // L'identité précède le contenu (ordre de lecture, invariant
        // AD-13) ; les actions le suivent et restent des sœurs du nœud
        // annoncé (`_announced` exclut la sémantique de ses seuls enfants) :
        // leurs boutons gardent leur sémantique propre. Aucun interligne
        // imposé : l'espacement appartient au widget de l'hôte.
        ?identity,
        core,
        ?actions,
      ],
    );
  }

  /// Invoque un builder de créneau — chaîne totale (invariant AD-10) : un
  /// créneau d'hôte qui lève perd le créneau, jamais le message. L'exception
  /// est relayée à `FlutterError` avec le nom du seam, comme pour les
  /// coquilles.
  Widget? _slot(
    BuildContext context,
    ZChatMessageSlotBuilder? builder,
    String seam,
  ) {
    if (builder == null) return null;
    try {
      return builder(context, widget.message);
    } catch (error, stack) {
      zChatReportSeamFailure(error: error, stack: stack, seam: seam);
      return null;
    }
  }

  /// Le cœur repliable.
  Widget _collapsible(Widget content, double maxHeight) {
    return ValueListenableBuilder<bool>(
      // L'écoute stable de la liaison — pas la source courante : brancher
      // le `ValueListenableBuilder` sur le contrôleur lui-même obligerait à
      // reconstruire la tuile entière quand l'hôte change de pilote.
      valueListenable: _expanded.listenable,
      builder: (BuildContext context, bool expanded, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ZCollapsibleContent(
              expanded: expanded,
              collapsedMaxHeight: maxHeight,
              onOverflowChanged: (bool value) => _overflowed.value = value,
              child: child!,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _overflowed,
              builder: (BuildContext context, bool overflowed, _) {
                // Ni dépassement ni état déplié ⇒ aucun bouton : on ne propose
                // pas un geste sans effet.
                if (!overflowed && !expanded) return const SizedBox.shrink();
                return _ZToggleButton(
                  expanded: expanded,
                  // Le geste interne écrit à la source : quand l'hôte
                  // pilote, le tap est écrit chez lui et lui reste donc
                  // lisible. Une écriture dans un miroir local aurait laissé
                  // sa barre d'outils annoncer « déplier » sur un message
                  // déjà déplié.
                  onToggle: () => _expanded.value = !_expanded.value,
                );
              },
            ),
          ],
        );
      },
      // Les blocs sont passés en `child` : basculer le dépli ne les
      // reconstruit pas (invariant AD-2). Seule la contrainte de hauteur
      // change.
      child: content,
    );
  }

  /// Le nœud d'annonce d'accessibilité que ce paquet contrôle.
  ///
  /// Un résumé exhaustif du kernel (`zChatAccessibleTextOf`, `switch`
  /// exhaustif sur l'union scellée) est porté par un `Semantics` posé ici,
  /// sur le chemin commun aux deux branches de rendu : une coquille tierce
  /// rappelle cette même fabrique de tuile, elle ne peut pas contourner ce
  /// nœud — un message fait d'un tableau ou d'un bloc de sources est ainsi
  /// toujours annoncé.
  ///
  /// `excludeSemantics: true` — sans quoi le résumé et le texte de chaque
  /// bloc seraient énoncés en double. Retirer le `label:` à la place
  /// rendrait le nœud muet. Le bouton de dépli, lui, est hors de ce nœud (il
  /// est un frère dans la `Column`) : sa sémantique de bouton est intacte.
  /// Un hôte dont les blocs sont interactifs coupe l'annonce par
  /// `ZChatAccessibleTextScope(announce: false)`.
  ///
  /// Un résumé vide signifie aucun nœud : on n'insère pas un conteneur muet.
  Widget _announced(BuildContext context, Widget child) {
    if (!ZChatAccessibleTextScope.announceOf(context)) return child;
    final String summary = zChatAccessibleTextOf(
      widget.message.contentBlocks,
      resolver: (ZContentBlock b) => _resolve(context, b),
    );
    if (summary.trim().isEmpty) return child;
    return Semantics(
      container: true,
      label: summary,
      excludeSemantics: true,
      child: child,
    );
  }

  /// Chaîne de résolution de l'annonce d'un bloc : hôte → socle → kernel.
  ///
  /// Le maillon « socle » n'est pas décoratif : `excludeSemantics` remplace
  /// l'arbre sémantique des blocs par ce seul résumé, et le kernel —
  /// pur-Dart, sans `BuildContext` — n'émet aucune prose. Sans ce maillon,
  /// les en-têtes que le rendu neutre annonce (« Sources », « Suggestions »,
  /// « Diagramme », « Contenu non pris en charge ») seraient perdues : un
  /// bloc de sources se serait mis à énoncer ses renvois sans dire que ce
  /// sont des sources, et un `kind` inconnu aurait été annoncé par son seul
  /// discriminant machine.
  ///
  /// L'hôte reste prioritaire : c'est lui qui sait nommer ses blocs ouverts,
  /// et lui qui les localise (le socle ne connaît que sa propre table).
  String? _resolve(BuildContext context, ZContentBlock block) {
    final String? fromHost = ZChatAccessibleTextScope.resolverOf(
      context,
    )?.call(block);
    if (fromHost != null && fromHost.trim().isNotEmpty) return fromHost;
    final String? header = switch (block) {
      ZSourcesBlock() => zChatLabel(context, kZChatLabelSources),
      ZSuggestionsBlock() => zChatLabel(context, kZChatLabelSuggestions),
      ZMermaidDiagramBlock() => zChatLabel(context, kZChatLabelDiagram),
      ZCustomContentBlock() => zChatLabel(context, kZChatLabelUnsupportedBlock),
      _ => null,
    };
    if (header == null) return null;
    // `accessibleText()` sans résolveur : le rappeler avec celui-ci
    // bouclerait à l'infini. Le corps du bloc reste donc celui du kernel,
    // seulement précédé de son en-tête localisé.
    return '$header$kZContentBlockAccessibleSeparator'
        '${block.accessibleText()}';
  }
}

/// Les blocs du message, empilés.
class _ZBlocks extends StatelessWidget {
  const _ZBlocks({
    required this.message,
    required this.isStreaming,
    required this.theme,
  });

  final ZChatMessage message;
  final bool isStreaming;
  final ZcrudTheme theme;

  @override
  Widget build(BuildContext context) {
    final List<ZContentBlock> blocks = message.contentBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: theme.gapM),
          ZChatBlockView(
            // Clé STABLE par position : le dépli ou l'arrivée d'un bloc ne
            // détruit pas l'état des blocs déjà montés.
            key: ValueKey<String>('${message.id ?? ''}#$i'),
            request: ZChatBlockRenderRequest(
              block: blocks[i],
              message: message,
              blockIndex: i,
              isStreaming: isStreaming,
            ),
          ),
        ],
      ],
    );
  }
}

/// Le bouton de dépli — cible tactile ≥ 48 dp, sémantique de bouton, libellé
/// **résolu** (jamais codé en dur).
class _ZToggleButton extends StatelessWidget {
  const _ZToggleButton({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // Invariant AD-13 : alignement directionnel — le bouton suit le
            // sens du texte.
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              zChatLabel(
                context,
                expanded ? kZChatLabelShowLess : kZChatLabelShowMore,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenu repliable : **une seule** lecture de l'état, **une seule** source de
/// la contrainte.
class _ZCollapsibleContent extends SingleChildRenderObjectWidget {
  const _ZCollapsibleContent({
    required this.expanded,
    required this.collapsedMaxHeight,
    required this.onOverflowChanged,
    required super.child,
  });

  final bool expanded;
  final double collapsedMaxHeight;
  final ValueChanged<bool> onOverflowChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ZRenderCollapsible(
        expanded: expanded,
        collapsedMaxHeight: collapsedMaxHeight,
        onOverflowChanged: onOverflowChanged,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _ZRenderCollapsible renderObject,
  ) {
    renderObject
      ..expanded = expanded
      ..collapsedMaxHeight = collapsedMaxHeight
      ..onOverflowChanged = onOverflowChanged;
  }
}

/// Mesure la hauteur **réelle** du contenu, la borne quand replié, et signale le
/// dépassement.
///
/// Pourquoi un `RenderObject` plutôt qu'un `ConstrainedBox` : la contrainte
/// seule ne dit pas s'il y avait quelque chose à déplier. Un « Afficher plus »
/// posé au jugé sur un message d'une ligne est un geste sans effet — une
/// promesse de dépli qui ne se vérifie jamais.
class _ZRenderCollapsible extends RenderProxyBox {
  // `prefer_initializing_formals` est inapplicable ici (même arbitrage que
  // `ZChatController`) : un paramètre nommé ne peut pas s'appeler `_expanded`
  // — les formels privés sont interdits en Dart — et rendre ces champs publics
  // court-circuiterait leurs setters, qui portent le `markNeedsLayout`. Sans ce
  // `markNeedsLayout`, basculer le dépli ne relaierait rien à la mise en page.
  _ZRenderCollapsible({
    required bool expanded,
    required double collapsedMaxHeight,
    required this.onOverflowChanged,
    // ignore: prefer_initializing_formals
  }) : _expanded = expanded,
       // ignore: prefer_initializing_formals
       _collapsedMaxHeight = collapsedMaxHeight;

  bool _expanded;
  bool get expanded => _expanded;
  set expanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    markNeedsLayout();
  }

  double _collapsedMaxHeight;
  double get collapsedMaxHeight => _collapsedMaxHeight;
  set collapsedMaxHeight(double value) {
    if (_collapsedMaxHeight == value) return;
    _collapsedMaxHeight = value;
    markNeedsLayout();
  }

  /// Rappel de dépassement. Non `final` : il est ré-injecté à chaque `build`.
  ValueChanged<bool> onOverflowChanged;

  bool? _lastOverflow;

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    // Le contenu est TOUJOURS mis en page en hauteur libre : c'est ce qui rend
    // le dépassement mesurable au lieu d'être supposé.
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );
    final double full = child.size.height;
    final bool overflow = full > _collapsedMaxHeight + _kOverflowEpsilon;
    final double shown = _expanded ? full : math.min(full, _collapsedMaxHeight);
    size = constraints.constrain(Size(child.size.width, shown));

    if (_lastOverflow != overflow) {
      _lastOverflow = overflow;
      // Notifier pendant la mise en page relancerait un build dans la même
      // frame (« setState during build »). Le rappel est différé.
      final ValueChanged<bool> notify = onOverflowChanged;
      SchedulerBinding.instance.addPostFrameCallback((_) => notify(overflow));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    if (child.size.height <= size.height) {
      context.paintChild(child, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (PaintingContext innerContext, Offset innerOffset) =>
          innerContext.paintChild(child, innerOffset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Rien n'est cliquable hors de la zone visible quand le contenu est replié.
    if (!size.contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }
}
