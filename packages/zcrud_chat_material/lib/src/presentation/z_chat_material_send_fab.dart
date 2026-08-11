/// Le bouton d'envoi, en Material pixel-perfect : un disque plat qui
/// s'anime selon la vacuité de la saisie.
///
/// La géométrie et le geste (cible tactile, échelle d'animation, durées,
/// sémantique, respect de la réduction des animations) viennent de
/// [ZChatComposerSendTarget], la primitive du socle — jamais contournée : ce
/// fichier ne pose aucune dimension en dur, il lit le chrome résolu via
/// [zChatComposerChromeOf]. Le disque et le glyphe sont le Material que le
/// socle ne rend pas lui-même : rôles `ColorScheme.primary`/`onPrimary` et
/// `Icons.send`.
///
/// Il n'existe aucun second site d'envoi : le tap appartient à
/// [ZChatComposerSendTarget], qui invoque [ZChatComposerSlot.submit]. Le
/// disque rendu ici est un glyphe — sans `onPressed` ni `InkWell` propre —
/// pour ne jamais créer un second chemin d'envoi parallèle à celui du socle.
///
/// `Icons.send` n'est pas automatiquement miroité par le framework ; ce
/// widget le retourne horizontalement sous direction RTL (invariant AD-13).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Builder prêt-à-brancher sur le créneau `trailing` de `ZChatComposer` :
///
/// ```dart
/// ZChatComposer(
///   trailing: zChatMaterialSendFab(),
///   …
/// )
/// ```
ZChatComposerSlotBuilder zChatMaterialSendFab({ZChatComposerChrome? chrome}) =>
    (BuildContext context, ZChatComposerSlot slot) =>
        ZChatMaterialSendFab(slot: slot, chrome: chrome);

/// Le widget du FAB d'envoi — montable directement quand l'hôte compose
/// lui-même son créneau.
class ZChatMaterialSendFab extends StatelessWidget {
  /// Construit le FAB d'envoi.
  const ZChatMaterialSendFab({
    required this.slot,
    this.chrome,
    this.icon,
    super.key,
  });

  /// Le contexte du créneau, fourni par `ZChatComposer`.
  final ZChatComposerSlot slot;

  /// {@macro zcrud.chat_material.chrome_param}
  final ZChatComposerChrome? chrome;

  /// Glyphe de remplacement. `null` ⇒ `Icons.send`, miroité en RTL.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Chaque dimension vient du chrome résolu : le côté du disque est la
    // cible tactile d'envoi (écrêtée à la taille minimale par le résolveur
    // quoi qu'il arrive), le glyphe en est la moitié.
    final double side = style.sendTargetSize;
    final Widget glyph =
        icon ??
        _mirrorInRtl(
          context,
          Icon(
            Icons.send,
            color: scheme.onPrimary,
            size: side / _kGlyphRatio,
          ),
        );
    return ZChatComposerSendTarget(
      slot: slot,
      chrome: chrome,
      // Un glyphe, pas un bouton : le tap, la sémantique, l'échelle et la
      // réduction d'animation appartiennent à la primitive du socle — jamais
      // contournés.
      child: Material(
        elevation: _kFlat,
        color: scheme.primary,
        shape: const CircleBorder(),
        child: SizedBox(
          width: side,
          height: side,
          child: Center(child: glyph)),
      ),
    );
  }
}

/// Rapport entre le côté de la cible et le côté du glyphe.
const double _kGlyphRatio = 2;

/// Élévation nulle : un disque plat.
const double _kFlat = 0;

/// `Icons.send` pointe vers la FIN de la ligne : sous RTL il doit être
/// retourné (le défaut « flèche qui pointe hors du champ » de tout hôte RTL).
Widget _mirrorInRtl(BuildContext context, Widget child) =>
    Directionality.of(context) == TextDirection.rtl
        ? Transform.flip(flipX: true, child: child)
        : child;
