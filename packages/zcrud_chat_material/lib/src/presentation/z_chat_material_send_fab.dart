/// Le **FAB d'envoi** pixel-perfect lex — lot K3.
///
/// lex rend son envoi comme un disque `CircleBorder` de 48 dp, élévation 0,
/// mis à l'échelle 0.7 → 1.0 en 150 ms selon la vacuité de la saisie
/// (`chat_input.dart:651-697`). Ici :
///
/// * la **géométrie et le geste** (cible, échelle, durées, Semantics, Reduce
///   Motion) viennent de [ZChatComposerSendTarget] — la primitive K2 du socle,
///   jamais contournée : ce fichier ne pose AUCUNE dimension en dur, il lit le
///   chrome résolu ([zChatComposerChromeOf]) ;
/// * le **disque et le glyphe** sont le Material vrai que le socle ne peut pas
///   rendre : `ColorScheme.primary`/`onPrimary` + `Icons.send`.
///
/// 🔴 **Aucun second site d'envoi** : le tap est celui de
/// [ZChatComposerSendTarget], qui appelle [ZChatComposerSlot.submit]. Le disque
/// rendu ici est un GLYPHE — aucun `onPressed`, aucun `InkWell` : un vrai
/// `FloatingActionButton` porterait son propre handler et créerait le second
/// chemin que G-CH1/G-U1 interdisent.
///
/// 🔴 **Miroir RTL** : `Icons.send` n'est pas auto-miroité — lex le corrige par
/// `_DirectionalSendIcon` (`chat_input.dart:1219-1231`). Même correction ici,
/// par retournement horizontal sous `TextDirection.rtl` (AD-13).
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

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
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
    // 🔴 CHAQUE dimension vient du chrome résolu : le côté du disque est la
    // cible d'envoi (48 chez lex, écrêtée ≥ 48 par le résolveur quoi qu'il
    // arrive), le glyphe en est la moitié (24 chez lex, `:651-697`).
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
      // Un GLYPHE, pas un bouton : le tap, la sémantique, l'échelle et le
      // Reduce-Motion appartiennent à la primitive K2 — jamais contournés.
      child: Material(
        // Élévations 0/0/0 chez lex (`:658-661`) : un disque plat.
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

/// Rapport côté-de-cible / côté-de-glyphe de lex (48 → 24).
const double _kGlyphRatio = 2;

/// Élévation nulle du disque lex.
const double _kFlat = 0;

/// `Icons.send` pointe vers la FIN de la ligne : sous RTL il doit être
/// retourné (le défaut « flèche qui pointe hors du champ » de tout hôte RTL).
Widget _mirrorInRtl(BuildContext context, Widget child) =>
    Directionality.of(context) == TextDirection.rtl
        ? Transform.flip(flipX: true, child: child)
        : child;
