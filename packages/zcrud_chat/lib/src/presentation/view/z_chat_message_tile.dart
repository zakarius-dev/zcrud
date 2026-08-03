/// Tuile neutre d'un message, et le **dépli INLINE réel** — CHAT-3.
///
/// ## 🔴 Le défaut d'IFFD que ce fichier rend inexprimable
///
/// `chatbot_conversation_screen.dart` déclare `showAll` **deux fois** :
/// * `:3733` — `final showAll = explanationToggler.value;` (l'état réel du
///   dépli, porté par un `ValueNotifier`) ;
/// * `:4124` — `final showAll = isChatSession;` **dans le `builder` d'un
///   `ResponsiveBuilder` imbriqué**, qui masque le précédent.
///
/// C'est la variable **masquante** qui pilote la contrainte de hauteur
/// (`:4135 constraints: showAll ? null : BoxConstraints(maxHeight: …)`). Le
/// bouton, lui, est **hors** de cette closure (`:4179`) et lit la variable
/// **masquée**. Conséquence mesurable : basculer le toggler ne relâche **jamais**
/// la contrainte — le dépli n'a pas lieu — et la branche « replié » du bouton
/// part dans `exportExplanationToPdf(...)`, c'est-à-dire une **sortie hors de la
/// conversation** là où l'utilisateur a lu « Afficher plus ».
///
/// Le correctif structurel n'est pas « renommer une variable » : c'est que
/// **l'état du dépli et la contrainte de hauteur soient lus au même endroit, sur
/// la même source**. Ici, [_ZCollapsibleContent] reçoit `expanded` et applique
/// la contrainte lui-même ; il n'existe aucun second chemin qui puisse diverger.
/// Garde : le dépli **augmente la hauteur de la tuile** et **ne pousse aucune
/// route**.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../render/z_chat_accessible_text_scope.dart';
import '../render/z_chat_render_request.dart';
import 'z_chat_block_view.dart';
import 'z_chat_labels.dart';

/// Hauteur de cible tactile minimale (AD-13). Ce n'est pas un style : c'est un
/// **seuil d'accessibilité**, non négociable et donc non injectable.
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
    super.key,
  });

  /// Le message rendu.
  final ZChatMessage message;

  /// Hauteur maximale à l'état **replié**. `null` ⇒ aucun repli, aucun bouton
  /// (le comportement par défaut est le message ENTIER : on ne tronque pas un
  /// contenu sans que l'hôte l'ait demandé).
  final double? collapsedMaxHeight;

  /// `true` si ce message est une réponse encore en cours.
  final bool isStreaming;

  /// Pilotage EXTERNE du dépli — `null` ⇒ la tuile se gouverne seule
  /// (comportement historique, **strictement inchangé**).
  ///
  /// ## Pourquoi ce paramètre existe (patron `ZDisplayState`, CR-IFFD-38)
  ///
  /// Le dépli est le cas d'ORIGINE de ce chantier : chez IFFD, « Afficher
  /// plus » était cassé par un bug de shadowing (cf. la note de bibliothèque)
  /// et nous avons livré le vrai dépli inline. Mais il restait **commandable
  /// depuis le seul bouton** : un hôte qui veut un « tout déplier » dans sa
  /// barre d'outils, ou déplier le message qu'une recherche vient de cibler,
  /// n'avait aucun second chemin de déclenchement. *Une commande absente est
  /// moins coûteuse qu'une commande morte, mais elle reste une capacité
  /// manquante.*
  ///
  /// ## Le contrat
  ///
  /// Fourni, le contrôleur devient **LA SOURCE DE VÉRITÉ** : la tuile ne garde
  /// aucun miroir du dépli (cf. [ZDisplayStateBinding]) ⇒ les deux états ne
  /// peuvent pas diverger, parce qu'il n'y en a qu'un. Le tap sur « Afficher
  /// plus » écrit **dans le contrôleur** — l'hôte lit donc le geste interne
  /// sans qu'aucun callback ne soit nécessaire.
  ///
  /// ⚠️ Sans [collapsedMaxHeight], il n'y a **ni repli ni bouton** : le
  /// contrôleur est alors accepté mais sans effet visible, exactement comme le
  /// dépli interne l'était.
  ///
  /// 🔒 Le contrôleur doit être **possédé hors `build`** : c'est imposé par
  /// [ZDisplayStateOwnerMixin], qui refuse un enregistrement postérieur à la
  /// première frame de son `State`. Un contrôleur créé dans `build` serait
  /// remplacé à chaque rebuild — donc silencieusement inerte.
  final ZToggleController? expandController;

  @override
  State<ZChatMessageTile> createState() => _ZChatMessageTileState();
}

class _ZChatMessageTileState extends State<ZChatMessageTile> {
  /// 🔴 `ValueNotifier` et non `setState` (AD-2) : basculer le dépli d'UNE tuile
  /// ne doit pas reconstruire la conversation. `setState` ici remonterait au
  /// `build` de la tuile entière, blocs compris.
  ///
  /// 🔴 Ce n'est plus un `ValueNotifier` privé mais une **liaison** : état
  /// interne par défaut, contrôleur de l'hôte quand il y en a un. La liaison ne
  /// **copie** rien — quand l'hôte pilote, la valeur est lue et écrite chez
  /// lui. `_expanded.listenable` reste **stable** au travers d'un changement de
  /// contrôleur, ce qui évite un `setState` d'échelle tuile (AD-2).
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
    // ⚠️ La liaison ne dispose JAMAIS le contrôleur de l'hôte : il ne nous
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
    if (maxHeight == null) return content;

    return ValueListenableBuilder<bool>(
      // 🔴 L'écoute STABLE de la liaison — pas la source courante : brancher le
      // `ValueListenableBuilder` sur le contrôleur lui-même obligerait à
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
                  // 🔴 Le geste INTERNE écrit **à la source** : quand l'hôte
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
      // 🔴 Les blocs sont passés en `child` : basculer le dépli ne les
      // reconstruit PAS (SM-1). Seule la contrainte de hauteur change.
      child: content,
    );
  }

  /// 🔴 **HIGH-2 — le nœud d'annonce que NOUS contrôlons.**
  ///
  /// Le résumé du kernel (`zChatAccessibleTextOf`, `switch` exhaustif sur
  /// l'union scellée) était jusqu'ici confié à `AssistMessage.data` de
  /// Syncfusion, champ **inerte** dès que `messageContentBuilder` est fourni —
  /// c'est-à-dire toujours, chez nous. Un message fait d'un **tableau** ou d'un
  /// bloc de **sources** n'était donc annoncé nulle part. Il l'est ici, sur le
  /// chemin **commun** aux deux branches de rendu : la coquille tierce rappelle
  /// cette même fabrique de tuile, elle ne peut pas contourner ce nœud.
  ///
  /// 🔴 `excludeSemantics: true` — sans quoi le résumé **et** le texte de chaque
  /// bloc sont énoncés (le doublon `<rapport.pdf\nrapport.pdf>` mesuré sur la
  /// bande de pièces jointes ; correctif jumeau documenté dans
  /// `zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:73-76`). Retirer le
  /// `label:` à la place rendrait le nœud **muet**. Le bouton de dépli, lui,
  /// est **hors** de ce nœud (il est un frère dans la `Column`) : sa sémantique
  /// de bouton est intacte. Un hôte dont les blocs sont **interactifs** coupe
  /// l'annonce par `ZChatAccessibleTextScope(announce: false)`.
  ///
  /// Un résumé vide ⇒ **aucun** nœud : on n'insère pas un conteneur muet.
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

  /// Chaîne de résolution de l'annonce d'**un** bloc : hôte → socle → kernel.
  ///
  /// 🔴 **Le maillon « socle » n'est pas décoratif** : `excludeSemantics`
  /// remplace l'arbre sémantique des blocs par ce seul résumé, et le kernel —
  /// pur-Dart, sans `BuildContext` — n'émet **aucune prose**. Sans ce maillon,
  /// les quatre en-têtes que le rendu neutre annonce (« Sources »,
  /// « Suggestions », « Diagramme », « Contenu non pris en charge ») seraient
  /// **perdues** : un bloc de sources se serait mis à énoncer ses renvois sans
  /// dire que ce sont des sources, et un `kind` inconnu aurait été annoncé par
  /// son seul discriminant machine. C'est exactement la régression que la garde
  /// G-R7 a fait rougir quand le maillon manquait.
  ///
  /// L'hôte reste **prioritaire** : c'est lui qui sait nommer *ses* blocs
  /// ouverts, et lui qui les localise (le socle ne connaît que sa propre table).
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
    // 🔴 `accessibleText()` SANS résolveur : le rappeler avec celui-ci
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
            // AD-13 : alignement DIRECTIONNEL — le bouton suit le sens du texte.
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
/// posé au jugé sur un message d'une ligne est un geste sans effet — la
/// première marche vers le bouton d'IFFD, qui promettait un dépli et faisait
/// autre chose.
class _ZRenderCollapsible extends RenderProxyBox {
  // 🔴 `prefer_initializing_formals` est INAPPLICABLE ici (même arbitrage que
  // `ZChatController`) : un paramètre NOMMÉ ne peut pas s'appeler `_expanded`
  // — les formels privés sont interdits en Dart — et rendre ces champs publics
  // court-circuiterait leurs setters, qui portent le `markNeedsLayout`. Sans ce
  // `markNeedsLayout`, basculer le dépli ne relaierait rien à la mise en page :
  // le défaut d'IFFD, reconstitué une couche plus bas.
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
      // 🔴 Notifier PENDANT la mise en page relancerait un build dans la même
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
