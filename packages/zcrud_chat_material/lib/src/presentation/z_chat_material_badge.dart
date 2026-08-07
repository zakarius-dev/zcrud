/// Le **badge compteur** pixel-perfect lex — lot K3.
///
/// lex badge ses puces d'outils d'un compteur à radius 8, pad h4, fond
/// `primary` quand il y a des réglages actifs et `surfaceContainerHighest`
/// sinon (`chat_input.dart:856-874`). Ici :
///
/// * le **radius** vient du chrome résolu ([ZChatComposerChromeStyle.badgeRadius]
///   — paramètre > jeton `badgeRadius` > référence 8), la marge de
///   `ZChatComposerReference.badgePadding` : rien n'est recopié ;
/// * les **rôles** viennent du `ColorScheme` de l'hôte — jamais un hex.
///
/// ⚠️ Un badge est un GLYPHE, pas une cible : il se monte DANS une affordance
/// ≥ 48 dp (le bouton « outils » de l'hôte), jamais seul comme surface
/// tactile. Le nombre reste lisible par un lecteur d'écran (c'est un `Text`) —
/// la couleur n'est jamais porteuse seule (CR-74).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Le badge statique — l'hôte fournit [count].
class ZChatMaterialBadge extends StatelessWidget {
  /// Construit le badge.
  const ZChatMaterialBadge({required this.count, this.chrome, super.key});

  /// Le compte affiché. `0` ⇒ variante discrète (les rôles de surface), comme
  /// chez lex — jamais un badge masqué en silence : masquer est une décision
  /// d'hôte (AD-4 : il ne monte simplement pas le badge).
  final int count;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool active = count > _kNone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? scheme.primary : scheme.surfaceContainerHighest,
        // Symétrique — un radius uniforme n'a pas de côté (AD-13).
        borderRadius: BorderRadius.all(style.badgeRadius),
      ),
      child: Padding(
        padding: ZChatComposerReference.badgePadding,
        child: Text(
          '$count',
          style: TextStyle(
            color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          // AD-13 : jamais `TextAlign.left`.
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Le badge VIVANT du bouton « outils » — lié à
/// [ZChatSettingsController.activeCount] (la tranche F12 de K2) : il suit le
/// nombre de réglages non-défaut sans que l'hôte recompte quoi que ce soit.
class ZChatMaterialToolsBadge extends StatelessWidget {
  /// Construit le badge lié.
  const ZChatMaterialToolsBadge({
    required this.controller,
    this.chrome,
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    // 🔴 LA tranche `activeCount`, et elle seule (SM-1).
    return ValueListenableBuilder<int>(
      valueListenable: controller.activeCount,
      builder: (BuildContext context, int count, Widget? _) =>
          ZChatMaterialBadge(count: count, chrome: chrome),
    );
  }
}

/// Zéro réglage actif.
const int _kNone = 0;
