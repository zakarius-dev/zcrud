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
import 'z_chat_tile_shell.dart';

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
    this.shell,
    this.topic,
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
  /// Sous une coquille déclarée ([shell]), cette barre est rendue **hors du
  /// filet**, sous la carte : le cadre délimite la réponse, jamais la réponse
  /// **et** ses commandes. Les commandes qui portent sur la carte elle-même
  /// (modifier, régénérer, supprimer) ont leur propre place, dans la coiffe —
  /// cf. `ZChatTileShell.topicTrailing`.
  ///
  /// `null` (défaut) donne un comportement strictement inchangé.
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// La **coquille** de cette tuile : carte, filet, horodatage, style du
  /// bouton de dépli.
  ///
  /// Le filet borne le **contenu** : l'identité, la coiffe, les blocs et le
  /// bouton de dépli sont dedans ; la barre d'[actionsBuilder] reste dehors,
  /// sous la carte.
  ///
  /// `null` (défaut) donne un arbre strictement inchangé — pas même un
  /// conteneur transparent. Déclarée, elle apporte le rendu de référence,
  /// corrigeable champ par champ (cf. [ZChatTileShell]).
  final ZChatTileShell? shell;

  /// Le **sujet du tour** qui coiffe ce message — typiquement la question qui
  /// a produit cette réponse.
  ///
  /// 🔴 Ce n'est pas l'identité de l'interlocuteur : celle-ci a son propre
  /// créneau ([identityBuilder]), et une surface qui la masque
  /// (`ZChatNotebookView`) peut parfaitement coiffer ses réponses. Régler
  /// l'un ne règle jamais l'autre.
  ///
  /// `null` ou vide (défaut) signifie aucune coiffe, absente de l'arbre
  /// (invariant AD-4). Une vue résout ce sujet par message
  /// (`ZChatTileShell.topicOf`, qui voit le message précédent) ; une tuile
  /// montée seule le reçoit ici, déjà résolu.
  final String? topic;

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

    // Deux déclarations INDÉPENDANTES, deux effets séparés : la coquille
    // amène la carte, son filet et le style du bouton de dépli ; le sujet du
    // tour amène la coiffe. Déclarer l'un ne fait jamais apparaître l'autre.
    final ZChatTileShell? shell = widget.shell;
    final String? raw = widget.topic?.trim();
    final String? subject = (raw == null || raw.isEmpty) ? null : raw;
    // Rien de déclaré ⇒ RIEN n'est résolu : pas une lecture de thème, pas un
    // rôle de couleur demandé. La coquille implicite ne sert qu'à donner sa
    // typographie de référence à une coiffe posée sans carte.
    final ZChatTileShellStyle? style = (shell == null && subject == null)
        ? null
        : zChatTileShellStyleOf(
            context,
            shell: shell ?? const ZChatTileShell(),
          );
    // Le bouton de dépli ne suit QUE la coquille : une coiffe seule ne le
    // déplace pas.
    final ZChatTileShellStyle? shellStyle = shell == null ? null : style;

    final double? maxHeight = widget.collapsedMaxHeight;
    final Widget core = maxHeight == null
        ? content
        : _collapsible(content, maxHeight, shellStyle);

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
    final Widget? topic = _topic(context, shell, style, subject);
    if (identity == null &&
        actions == null &&
        topic == null &&
        shellStyle == null) {
      return core;
    }
    if (shellStyle == null) {
      // Sans coquille, l'empilement est celui qu'il a toujours été : une
      // seule colonne, les quatre créneaux à la suite.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[?identity, ?topic, core, ?actions],
      );
    }
    // Le filet borne le CONTENU. L'identité, la coiffe et les blocs sont ce
    // dont la carte parle ; la barre d'actions, elle, porte les commandes du
    // message — elle reste une sœur de la carte, sous elle et hors du filet.
    // Cf. la dartdoc d'[actionsBuilder] : c'est un contrat, pas un effet de
    // mise en page.
    final Widget framed = _ZTileShell(
      style: shellStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // L'identité précède le contenu (ordre de lecture, invariant
          // AD-13). Aucun interligne imposé : l'espacement appartient au
          // widget de l'hôte.
          ?identity,
          // La coiffe est construite ICI, dans `build`, donc hors du
          // `ValueListenableBuilder` du dépli : basculer « Afficher plus » ne
          // la reconstruit pas, et elle ne reconstruit pas les blocs
          // (invariant AD-2).
          ?topic,
          core,
        ],
      ),
    );
    if (actions == null) return framed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      // Les actions restent des sœurs du nœud annoncé (`_announced` exclut la
      // sémantique de ses seuls enfants) : leurs boutons gardent leur
      // sémantique propre.
      children: <Widget>[framed, actions],
    );
  }

  /// La coiffe : le sujet du tour, puis l'horodatage.
  ///
  /// Rend `null` quand il n'y a ni l'un ni l'autre — pas un conteneur vide
  /// (invariant AD-4). L'horodatage suit la chaîne du skin
  /// (`showTimestamp`) et n'existe que sous une coquille déclarée : une
  /// tuile nue n'a jamais affiché de date, et ce lot ne lui en donne pas.
  Widget? _topic(
    BuildContext context,
    ZChatTileShell? shell,
    ZChatTileShellStyle? style,
    String? subject,
  ) {
    if (style == null) return null;
    final DateTime? stamp = (shell != null && style.showTimestamp)
        ? widget.message.createdAt
        : null;
    final Widget? trailing = _trailing(context, shell, style);
    if (subject == null && stamp == null && trailing == null) return null;
    final int maxLines = style.topicMaxLines;
    final List<Widget> parts = <Widget>[
      if (subject != null)
        Semantics(
          // La contrainte DÉCLARÉE : la coiffe est un en-tête, et son libellé
          // porte le sujet ENTIER — la troncature est visuelle, elle ne
          // retire rien à l'annonce.
          header: true,
          container: true,
          label: subject,
          excludeSemantics: true,
          child: Text(
            subject,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            // Une GRAISSE seule, posée sur le style ambiant : la police, le
            // corps et la couleur restent ceux de l'hôte (invariant FR-26).
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(fontWeight: style.topicWeight),
          ),
        ),
      if (stamp != null)
        Text(
          _stamp(context, stamp, shell?.timestampFormatter),
          textAlign: TextAlign.start,
        ),
    ];
    if (trailing == null) {
      if (parts.length == 1) return parts.single;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      );
    }
    // Un créneau sans sujet ni horodatage : il se pose seul, en FIN de coiffe
    // (`centerEnd`, donc à droite en LTR et à gauche en RTL — invariant
    // AD-13). Pas de `Row` avec un `Expanded` vide : on n'insère pas un
    // conteneur qui ne borne rien (invariant AD-4).
    if (parts.isEmpty) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: trailing);
    }
    final Widget lead = parts.length == 1
        ? parts.single
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: parts,
          );
    // `Expanded` sur le sujet, largeur INTRINSÈQUE sur le créneau : c'est ce
    // qui fait que le sujet TRONQUE (il n'a que la place restante) et que les
    // commandes restent entières, quelle que soit la longueur de la question.
    // L'inverse — laisser le sujet prendre sa largeur naturelle — écraserait
    // le créneau, ou déborderait.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: lead),
        trailing,
      ],
    );
  }

  /// Le créneau de **fin de coiffe** : les commandes de la carte.
  ///
  /// Rend `null` quand la coquille n'en déclare aucun, ou quand le builder de
  /// l'hôte rend `null` pour ce message (invariant AD-4). Un builder qui lève
  /// perd le créneau, jamais la coiffe (invariant AD-10).
  ///
  /// Deux contraintes, et deux seulement : le plancher tactile de
  /// `kZChatMinTapTarget`, qui ne se négocie pas (invariant AD-13), et une
  /// taille de glyphe réduite, posée par `IconTheme` — un `merge` de TAILLE,
  /// jamais de couleur (invariant FR-26).
  Widget? _trailing(
    BuildContext context,
    ZChatTileShell? shell,
    ZChatTileShellStyle style,
  ) {
    final Widget? built = _slot(
      context,
      shell?.topicTrailing,
      kZChatSeamTopicTrailing,
    );
    if (built == null) return null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
      child: IconTheme.merge(
        data: IconThemeData(size: style.topicTrailingIconSize),
        child: built,
      ),
    );
  }

  /// L'horodatage rendu — format de l'hôte, sinon celui de la référence.
  ///
  /// Chaîne totale (invariant AD-10) : un formateur d'hôte qui lève perd son
  /// format, jamais l'horodatage ni le message. L'exception est relayée à
  /// `FlutterError` avec le nom du seam, comme pour les créneaux.
  String _stamp(
    BuildContext context,
    DateTime value,
    ZChatTimestampFormatter? formatter,
  ) {
    if (formatter == null) return zChatReferenceTimestamp(value);
    try {
      return formatter(context, value);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamTimestamp,
      );
      return zChatReferenceTimestamp(value);
    }
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
  Widget _collapsible(
    Widget content,
    double maxHeight,
    ZChatTileShellStyle? style,
  ) {
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
                  style: style,
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
///
/// Deux rendus, et un seul point de bascule : sans coquille déclarée, le
/// bouton est le texte aligné au début qu'il a toujours été ; avec, il prend
/// la forme, l'alignement et le remplissage de la coquille. Le plancher
/// tactile de 48 dp et la sémantique de bouton sont les mêmes dans les deux —
/// ils ne sont pas un style, ils ne se règlent pas.
class _ZToggleButton extends StatelessWidget {
  const _ZToggleButton({
    required this.expanded,
    required this.onToggle,
    this.style,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// La coquille résolue, ou `null` — l'interrupteur entre les deux rendus.
  final ZChatTileShellStyle? style;

  @override
  Widget build(BuildContext context) {
    final String text = zChatLabel(
      context,
      expanded ? kZChatLabelShowLess : kZChatLabelShowMore,
    );
    final ZChatTileShellStyle? s = style;
    final Widget target = s == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kZChatMinTapTarget,
              minWidth: kZChatMinTapTarget,
            ),
            child: Align(
              // Invariant AD-13 : alignement directionnel — le bouton suit le
              // sens du texte.
              alignment: AlignmentDirectional.centerStart,
              child: Text(text, textAlign: TextAlign.start),
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kZChatMinTapTarget,
              minWidth: kZChatMinTapTarget,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s.toggleFill?.color,
                borderRadius: BorderRadius.all(s.toggleRadius),
              ),
              child: Padding(
                padding: s.togglePadding,
                child: Center(
                  // `widthFactor: 1` — la pilule se serre sur son libellé,
                  // sans jamais descendre sous le plancher tactile que la
                  // contrainte ci-dessus impose.
                  widthFactor: 1,
                  child: Text(
                    text,
                    textAlign: TextAlign.start,
                    // Le premier plan vient de la MÊME paire que le fond :
                    // le contraste du libellé est garanti par le rôle, pas
                    // espéré (invariant AD-13). Sans remplissage, le style
                    // ambiant est gardé tel quel.
                    style: s.toggleFill == null
                        ? null
                        : DefaultTextStyle.of(
                            context,
                          ).style.copyWith(color: s.toggleFill!.onColor),
                  ),
                ),
              ),
            ),
          );
    final Widget interactive = Semantics(
      button: true,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: target,
      ),
    );
    // L'alignement est posé AU-DESSUS du geste, jamais au-dessous : la zone
    // tactile épouse la pilule au lieu de couvrir toute la largeur de la
    // tuile. Directionnel (invariant AD-13) : en RTL, `centerStart` bascule
    // de lui-même, sans second réglage.
    if (s == null) return interactive;
    return Align(alignment: s.toggleAlignment, child: interactive);
  }
}

/// La carte d'une tuile : sa marge externe, son fond, son filet, sa marge
/// interne.
///
/// Ce widget n'existe que sous une coquille déclarée — il n'a pas de branche
/// « rien » : c'est l'appelant qui décide de ne pas le monter, ce qui laisse
/// l'arbre d'un hôte passif exempt même d'un conteneur transparent
/// (invariant AD-4).
class _ZTileShell extends StatelessWidget {
  const _ZTileShell({required this.style, required this.child});

  final ZChatTileShellStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: style.margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          // Une épaisseur nulle ne peint aucun côté : une coquille sans
          // cadre est exprimable, et elle ne pose alors rien.
          border: style.hasBorder
              ? Border.fromBorderSide(
                  BorderSide(
                    color: style.borderColor,
                    width: style.borderWidth,
                  ),
                )
              : null,
          borderRadius: BorderRadius.all(style.radius),
          // L'ombre vit dans la MÊME décoration : sans élévation, `boxShadow`
          // reste `null` et l'arbre est, nœud pour nœud, celui d'avant — pas
          // de `Material` ni de `PhysicalModel` ajouté pour une ombre absente.
          boxShadow: style.hasElevation
              ? zChatTileElevationShadows(style.elevation, style.shadowColor)
              : null,
        ),
        child: Padding(padding: style.padding, child: child),
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
  RenderObject createRenderObject(BuildContext context) => _ZRenderCollapsible(
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
