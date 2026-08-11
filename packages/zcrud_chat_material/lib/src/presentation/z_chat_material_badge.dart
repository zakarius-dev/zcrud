/// Le badge compteur, en Material pixel-perfect.
///
/// {@template zcrud.chat_material.chrome_param}
/// Réglage de chrome pour ce builder — dimensions et couleurs d'identité.
/// `null` résout la chaîne par défaut : jeton de thème du chrome composer,
/// puis valeurs de référence Material intégrées à ce paquet.
/// {@endtemplate}
///
/// Le radius et la marge viennent du chrome résolu
/// ([ZChatComposerChromeStyle.badgeRadius], `ZChatComposerReference.badgePadding`) ;
/// les rôles de couleur viennent du `ColorScheme` de l'hôte, jamais d'une
/// valeur hexadécimale codée en dur.
///
/// Un badge est un glyphe, pas une cible tactile : il se monte à l'intérieur
/// d'une affordance déjà conforme (le bouton « outils » de l'hôte), jamais
/// seul comme surface interactive. Le nombre reste lisible par un lecteur
/// d'écran (c'est un `Text`) — la couleur n'est jamais le seul canal qui
/// porte l'état actif/inactif.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Le badge statique — l'hôte fournit [count].
class ZChatMaterialBadge extends StatelessWidget {
  /// Construit le badge.
  const ZChatMaterialBadge({required this.count, this.chrome, super.key});

  /// Le compte affiché. `0` rend la variante discrète (rôles de surface) —
  /// jamais un badge masqué en silence : masquer le badge lui-même reste une
  /// décision de l'hôte (invariant AD-4), pas de ce widget.
  final int count;

  /// {@macro zcrud.chat_material.chrome_param}
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

/// Le badge vivant du bouton « outils » — lié à
/// [ZChatSettingsController.activeCount] : il suit le nombre de réglages
/// non-défaut sans que l'hôte recompte quoi que ce soit.
class ZChatMaterialToolsBadge extends StatelessWidget {
  /// Construit le badge lié.
  const ZChatMaterialToolsBadge({
    required this.controller,
    this.chrome,
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// {@macro zcrud.chat_material.chrome_param}
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    // Abonné uniquement à la tranche `activeCount` (invariant AD-2).
    return ValueListenableBuilder<int>(
      valueListenable: controller.activeCount,
      builder: (BuildContext context, int count, Widget? _) =>
          ZChatMaterialBadge(count: count, chrome: chrome),
    );
  }
}

/// Zéro réglage actif.
const int _kNone = 0;
