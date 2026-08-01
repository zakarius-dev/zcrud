/// Barre de **diffusion** — `ZChatDiffusionBar` (CHAT-9 ; AD-2, AD-13, FR-26).
///
/// Le rendu neutre des deux gestes de sortie d'une conversation : **lire à voix
/// haute** et **partager**. Zéro dépendance tierce (AD-57), aucune icône
/// imposée, aucune couleur en dur.
///
/// ## 🔴 AD-13 — les trois contraintes, tenues et gardées
///
/// * **cible tactile** : chaque action est un `ConstrainedBox` à
///   [kZChatMinTapTarget] (48 dp) — la garde **G9-A1** mesure la taille
///   **rendue**, pas la contrainte déclarée (c'est la différence qui avait
///   fait tomber `ZChatAttachmentStrip` : un `padding` de parent écrasait un
///   `minHeight: 48` parfaitement écrit) ;
/// * **directionnalité** : `EdgeInsetsDirectional` / `AlignmentDirectional` /
///   `TextAlign.start` — jamais `left`/`right` ;
/// * **sémantique** : chaque action est un `Semantics(button: true)` avec un
///   libellé **résolu**, jamais une chaîne en dur.
///
/// ## 🔴 Le bouton de lecture est un BASCULEUR, pas deux boutons
///
/// Un bouton « lire » et un bouton « arrêter » côte à côte laissent, à l'arrêt,
/// une cible active qui ne fait rien — et un lecteur d'écran annonce deux
/// actions dont une est inopérante. Ici l'action **unique** change de libellé
/// selon [ZChatDiffusionService.speaking], la tranche `ValueListenable` que le
/// service expose : seul ce bouton se reconstruit quand la lecture démarre
/// (SM-1), pas la conversation.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../diffusion/z_chat_diffusion_service.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Rend les actions de diffusion d'une conversation.
class ZChatDiffusionBar extends StatelessWidget {
  /// Construit la barre.
  const ZChatDiffusionBar({
    required this.service,
    required this.onSpeak,
    this.onShare,
    super.key,
  });

  /// Le service écouté. Il n'est **ni créé ni disposé** ici : son cycle de vie
  /// appartient à l'hôte (AD-2).
  final ZChatDiffusionService service;

  /// Déclenche la lecture. L'**arrêt** n'est pas un second rappel : la barre
  /// appelle `service.stopNarration()`, qui est déjà le site unique de l'arrêt.
  final VoidCallback onSpeak;

  /// Déclenche le partage, ou `null` ⇒ **l'action n'est pas rendue**.
  ///
  /// `null` retire le bouton plutôt que de le désactiver : une cible visible et
  /// inerte est annoncée par un lecteur d'écran comme une action disponible.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Semantics(
      container: true,
      label: zChatLabel(context, kZChatLabelDiffusion),
      child: Padding(
        // AD-13 : marge DIRECTIONNELLE, et HORIZONTALE seulement — une marge
        // verticale écraserait la cible de 48 dp dans une barre serrée.
        padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ValueListenableBuilder<bool>(
              valueListenable: service.speaking,
              builder: (BuildContext context, bool speaking, Widget? child) =>
                  _ZDiffusionAction(
                    labelKey: speaking
                        ? kZChatLabelStopSpeaking
                        : kZChatLabelSpeak,
                    onTap: speaking ? service.stopNarration : onSpeak,
                  ),
            ),
            if (onShare != null) ...<Widget>[
              SizedBox(width: theme.gapS),
              _ZDiffusionAction(
                labelKey: kZChatLabelShare,
                onTap: onShare!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une action de la barre : cible ≥ 48 dp, sémantique de bouton, libellé résolu.
class _ZDiffusionAction extends StatelessWidget {
  const _ZDiffusionAction({required this.labelKey, required this.onTap});

  final String labelKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            // 🔴 `widthFactor`/`heightFactor` — DÉFAUT TROUVÉ PAR L'INJECTION
            // R3 de la garde « ≥ 48 dp ». Sans eux, `Align` **occupe toute la
            // contrainte** : la cible mesurait 600 dp de haut (la hauteur de
            // l'écran), et la garde passait pour cette raison — pas grâce au
            // `minHeight`. Mesuré : avec `minHeight: 24` injecté, la taille
            // rendue restait 600 et la garde restait VERTE. Les facteurs font
            // que la boîte ÉPOUSE son libellé, et que le plancher de 48 dp
            // devient la contrainte réellement active.
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              zChatLabel(context, labelKey),
              // AD-13 : jamais `TextAlign.left`.
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}
