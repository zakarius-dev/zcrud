/// Tuile neutre d'une conversation — `ZChatConversationTile` (CR-IFFD-39).
///
/// Rendu **zéro dépendance tierce**, sur le patron strict de
/// `ZChatMessageTile` / `ZChatAttachmentStrip` : `Semantics`, cible ≥ 48 dp,
/// variantes directionnelles, libellés résolus par `zChatLabel`, tokens de
/// `ZcrudTheme`.
///
/// ## Le DÉFAUT, et rien de plus
///
/// Une tuile construite sans aucun slot ni callback rend **exactement trois
/// choses** : la pastille, le titre, l'horodatage relatif. Pas de sous-titre,
/// pas de badge, pas d'action, pas de `trailing` — et surtout **ni `pinned`, ni
/// `pinnedAt`, ni `messageCount`**, qui sont pourtant des champs de
/// `ZChatConversation`. Ces trois-là sont **nôtres** et absents chez IFFD ; les
/// rendre par défaut afficherait chez eux une décoration morte. Symétriquement,
/// `isArchived` est **leur** champ (il vit dans `extra`) et le socle ne le
/// connaît pas : il s'affiche par un [ZChatConversationBadge] dont le prédicat
/// lit `extra`, jamais par un champ qu'on aurait porté.
///
/// ## 🔴 Le champ de date est CHOISI, jamais deviné
///
/// IFFD affiche `createdAt` (`conversation_item_widget.dart:193,196`) alors que
/// son modèle porte `updatedAt` (`chatbot_conversation.dart:24`) — une
/// conversation active y reste datée de sa création. lex affiche `updatedAt`.
/// Les deux ont raison pour leur produit ; le socle ne peut pas trancher. Il
/// expose donc [ZChatConversationTile.timestampOf] et deux sélecteurs prêts à
/// l'emploi ([zChatLastMessageTimestamp], [zChatCreatedTimestamp]).
///
/// Le **formateur** est lui aussi injectable, et son défaut ne code **aucune
/// locale** (cf. `zChatDefaultRelativeTime`).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_conversation_actions.dart';
import 'z_chat_highlight.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Choisit la date affichée par la tuile — couture d'hôte.
typedef ZChatConversationTimestamp = DateTime? Function(
  ZChatConversation conversation,
);

/// Sélecteur **par défaut** : la récence métier, avec repli sur la création.
///
/// `lastMessageAt` est le champ de récence de `ZChatConversation` (jamais
/// `updated_at`, réservé hors-entité à `ZSyncMeta` — décision D3 du kernel).
DateTime? zChatLastMessageTimestamp(ZChatConversation c) =>
    c.lastMessageAt ?? c.createdAt;

/// Sélecteur « date de création » — le choix d'IFFD, disponible sans le figer.
DateTime? zChatCreatedTimestamp(ZChatConversation c) => c.createdAt;

/// Construit le leading complet d'une tuile — remplace la pastille.
///
/// 🔴 Ce slot existe parce que les deux hôtes superposent une icône et un badge
/// dans un `Stack` : ce n'est pas exprimable en champ, et sans lui ils
/// réécrivent la tuile.
typedef ZChatConversationLeadingBuilder = Widget? Function(
  BuildContext context,
  ZChatConversation conversation,
);

/// Construit le sous-titre — typiquement l'extrait du dernier message, ou le
/// `snippet` d'un `ZChatConversationHit`.
///
/// **Ni lex ni IFFD ne l'ont** : leurs tuiles n'affichent que le titre. C'est
/// pourtant la demande n°1 d'une liste de conversations, et c'est la raison pour
/// laquelle le slot existe sans que le socle n'invente le champ.
typedef ZChatConversationSubtitleBuilder = Widget? Function(
  BuildContext context,
  ZChatConversation conversation,
);

/// Un badge de statut **piloté par prédicat**.
///
/// 🔴 Ni `pinned` ni `isArchived` ne sont câblés en dur : le prédicat lit ce
/// qu'il veut (un champ du schéma, une clé d'`extra`, un préfixe de titre).
@immutable
class ZChatConversationBadge {
  /// Construit un badge.
  const ZChatConversationBadge({
    required this.labelKey,
    required this.isVisible,
    this.colorKey = '',
    this.slotIndex = 0,
  });

  /// Clé de libellé — **jamais** un libellé. Elle est **annoncée** : un badge
  /// muet est une information réservée aux voyants (AD-13).
  final String labelKey;

  /// Prédicat d'affichage.
  final bool Function(ZChatConversation conversation) isVisible;

  /// Clé de teinte, résolue par `zResolveColorKeyOrSlot` (FR-26).
  final String colorKey;

  /// Slot de repli, si [colorKey] reste inconnue du thème.
  final int slotIndex;
}

/// Rend une conversation en une ligne de liste.
class ZChatConversationTile extends StatelessWidget {
  /// Construit une tuile.
  const ZChatConversationTile({
    required this.conversation,
    this.titleMaxLines = 1,
    this.isStrongTitle,
    this.timestampOf = zChatLastMessageTimestamp,
    this.timeFormatter = zChatDefaultRelativeTime,
    this.now,
    this.iconColorKey = '',
    this.iconSlotIndex = 0,
    this.iconBuilder,
    this.leadingBuilder,
    this.subtitleBuilder,
    this.trailing,
    this.badges = const <ZChatConversationBadge>[],
    this.actions = const <ZChatConversationAction>[],
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.searchTerm = '',
    this.minHeight = kZChatMinTapTarget,
    this.padding,
    super.key,
  });

  /// La conversation rendue.
  final ZChatConversation conversation;

  /// Nombre maximal de lignes du titre — **paramétrable**.
  final int titleMaxLines;

  /// Prédicat de **graisse** du titre (« non lu », « nouveau »…), ou `null`.
  ///
  /// 🔴 Un prédicat, pas un champ : chez IFFD le « nouveau » se lit à un
  /// **préfixe dans le titre**, chez lex à un `userId != null`. Aucune de ces
  /// deux formes n'est un champ propre ; les modéliser les figerait.
  final bool Function(ZChatConversation conversation)? isStrongTitle;

  /// Sélecteur de la date affichée.
  final ZChatConversationTimestamp timestampOf;

  /// Formateur d'horodatage relatif.
  final ZChatRelativeTimeFormatter timeFormatter;

  /// Instant de référence. `null` ⇒ `DateTime.now()` lu **une seule fois** par
  /// `build` : deux lignes d'une même frame se réfèrent au même instant.
  final DateTime? now;

  /// Clé de teinte de la pastille (FR-26 — aucune couleur en dur).
  final String iconColorKey;

  /// Slot de repli de la pastille.
  final int iconSlotIndex;

  /// Contenu de la pastille (une icône d'hôte), ou `null` (pastille nue).
  final ZChatActionIconBuilder? iconBuilder;

  /// Remplace **tout** le leading, pastille comprise.
  final ZChatConversationLeadingBuilder? leadingBuilder;

  /// Sous-titre optionnel — `null` ⇒ aucune ligne supplémentaire.
  final ZChatConversationSubtitleBuilder? subtitleBuilder;

  /// Slot de fin de ligne (un compteur, un chevron…). Rien par défaut.
  final Widget? trailing;

  /// Badges de statut — aucun par défaut.
  final List<ZChatConversationBadge> badges;

  /// Actions déclarées — aucune par défaut.
  final List<ZChatConversationAction> actions;

  /// Appui simple, ou `null` (la tuile n'est pas interactive).
  final void Function(ZChatConversation conversation)? onTap;

  /// Appui long — l'entrée en sélection multiple, côté liste.
  final void Function(ZChatConversation conversation)? onLongPress;

  /// État de sélection (mono-sélection **ou** case d'un lot).
  final bool isSelected;

  /// Terme surligné dans le titre, ou `''`.
  final String searchTerm;

  /// Hauteur minimale **demandée**. Lire [effectiveMinHeight] pour dimensionner.
  final double minHeight;

  /// Marge **directionnelle** (AD-13). `null` ⇒ marge horizontale du thème.
  ///
  /// 🔴 Le défaut est **horizontal seul** : une marge verticale posée ici
  /// s'ajouterait à la cible tactile et empêcherait de la borner par le haut —
  /// c'est le défaut exact corrigé sur `ZChatAttachmentStrip` (v0.31.1), où
  /// `theme.formPadding` ramenait la hauteur utile à 40 dp.
  final EdgeInsetsDirectional? padding;

  /// Hauteur réellement appliquée : jamais sous le plancher tactile (AD-13).
  ///
  /// Le plancher est porté par le CONTENEUR, pas par l'enfant : un enfant ne
  /// peut pas être plus grand que la place que son parent lui impose
  /// (protocole de Flutter), et un `ConstrainedBox` interne serait écrasé en
  /// silence sous une contrainte serrée.
  double get effectiveMinHeight => math.max(minHeight, kZChatMinTapTarget);

  /// Les badges **visibles** pour cette conversation.
  List<ZChatConversationBadge> get visibleBadges => <ZChatConversationBadge>[
    for (final ZChatConversationBadge b in badges)
      if (b.isVisible(conversation)) b,
  ];

  /// Les actions **visibles** pour cette conversation.
  List<ZChatConversationAction> get visibleActions =>
      <ZChatConversationAction>[
        for (final ZChatConversationAction a in actions)
          if (a.visibleFor(conversation)) a,
      ];

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final DateTime reference = now ?? DateTime.now();
    final DateTime? stamp = timestampOf(conversation);
    final String time = stamp == null
        ? ''
        : timeFormatter(context, stamp, reference);
    final List<ZChatConversationBadge> shown = visibleBadges;
    final Widget? subtitle = subtitleBuilder?.call(context, conversation);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ZChatHighlightedText(
                text: conversation.title,
                term: searchTerm,
                maxLines: titleMaxLines,
                strong: isStrongTitle?.call(conversation) ?? false,
              ),
            ),
            if (time.isNotEmpty) ...<Widget>[
              SizedBox(width: theme.gapM),
              Text(time, textAlign: TextAlign.start),
            ],
          ],
        ),
        if (shown.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.gapS),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ZChatConversationBadge b in shown) ...<Widget>[
                _ZBadgePill(badge: b),
                SizedBox(width: theme.gapS),
              ],
            ],
          ),
        ],
        if (subtitle != null) ...<Widget>[
          SizedBox(height: theme.gapS),
          subtitle,
        ],
      ],
    );

    // 🔴 UN SEUL nœud sémantique pour la ligne : titre + badges + date +
    // sélection. `excludeSemantics` évite le doublon mesuré sur la bande de
    // pièces jointes (`<rapport.pdf\nrapport.pdf>`) — mais il est posé sur le
    // TEXTE seulement : la pastille (décorative) est exclue à part, et les
    // actions sont des FRÈRES, donc leur sémantique de bouton reste intacte.
    final Widget announced = Semantics(
      container: true,
      selected: isSelected,
      label: _semanticLabel(context, time, shown),
      excludeSemantics: true,
      onTap: onTap == null ? null : () => onTap!(conversation),
      onLongPress: onLongPress == null ? null : () => onLongPress!(conversation),
      child: body,
    );

    final Widget row = Row(
      children: <Widget>[
        ExcludeSemantics(child: _leading(context, theme)),
        SizedBox(width: theme.gapM),
        Expanded(child: announced),
        if (trailing != null) ...<Widget>[
          SizedBox(width: theme.gapM),
          trailing!,
        ],
        for (final ZChatConversationAction a in visibleActions)
          _ZActionButton(
            key: ValueKey<String>('zchat.action#${a.labelKey}'),
            action: a,
            conversation: conversation,
          ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(conversation),
      onLongPress: onLongPress == null ? null : () => onLongPress!(conversation),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: effectiveMinHeight),
        child: Padding(
          padding:
              padding ??
              EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
          child: row,
        ),
      ),
    );
  }

  /// L'annonce composite de la ligne — jamais une chaîne en dur.
  String _semanticLabel(
    BuildContext context,
    String time,
    List<ZChatConversationBadge> shown,
  ) {
    final List<String> parts = <String>[
      if (conversation.title.trim().isNotEmpty) conversation.title,
      for (final ZChatConversationBadge b in shown)
        zChatLabel(context, b.labelKey),
      if (time.isNotEmpty) time,
      if (isSelected) zChatLabel(context, kZChatLabelRowSelected),
    ];
    return parts.join(kZContentBlockAccessibleSeparator);
  }

  Widget _leading(BuildContext context, ZcrudTheme theme) {
    final Widget? custom = leadingBuilder?.call(context, conversation);
    if (custom != null) return custom;
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      iconColorKey,
      slotIndex: iconSlotIndex,
    );
    final double size = theme.iconContainerSize ?? theme.gapL * 2;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pair.color,
          borderRadius: BorderRadius.all(
            theme.iconContainerRadius ?? theme.radiusM,
          ),
        ),
        child: Align(
          // AD-13 : alignement DIRECTIONNEL.
          alignment: AlignmentDirectional.center,
          child: iconBuilder?.call(context) ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Une pastille de badge — libellé **résolu**, teinte du thème.
class _ZBadgePill extends StatelessWidget {
  const _ZBadgePill({required this.badge});

  final ZChatConversationBadge badge;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      badge.colorKey,
      slotIndex: badge.slotIndex,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pair.color,
        borderRadius: BorderRadius.all(theme.badgeRadius ?? theme.radiusS),
      ),
      child: Padding(
        padding:
            theme.countPillPadding ??
            EdgeInsetsDirectional.symmetric(horizontal: theme.gapS),
        child: Text(
          zChatLabel(context, badge.labelKey),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}

/// Le bouton d'une action — cible ≥ 48 dp, sémantique de bouton, libellé résolu.
class _ZActionButton extends StatelessWidget {
  const _ZActionButton({
    required this.action,
    required this.conversation,
    super.key,
  });

  final ZChatConversationAction action;
  final ZChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final Widget? icon = action.iconBuilder?.call(context);
    return Semantics(
      button: true,
      onTap: () => _invoke(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _invoke(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            child:
                icon ??
                Text(
                  zChatLabel(context, action.labelKey),
                  textAlign: TextAlign.start,
                ),
          ),
        ),
      ),
    );
  }

  void _invoke(BuildContext context) {
    final Future<bool> Function(BuildContext context)? confirm = action.confirm;
    if (confirm == null) {
      action.onInvoke(conversation);
      return;
    }
    unawaited(
      confirm(context).then((bool ok) {
        if (ok) action.onInvoke(conversation);
      }),
    );
  }
}
