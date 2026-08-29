/// **Unique** fichier de référence COULEUR de la famille « indicateur
/// d'occupation » : la séquence de teintes qui signale « quelque chose se
/// génère ».
///
/// ## Ce que ce fichier est
///
/// Les sept teintes du cycle d'occupation, sous forme de littéraux
/// hexadécimaux, et le tempo qui les fait défiler. C'est le seul endroit du
/// paquet où ces littéraux ont le droit d'exister : la garde de source
/// anti-couleurs (FR-26) l'exempte **nominativement par chemin exact**, et
/// elle seule. Toute recopie de ces valeurs ailleurs est un défaut, et la
/// garde le dit.
///
/// ## Ce que ce fichier n'est pas
///
/// Ce n'est pas un défaut inconditionnel. Les valeurs d'ici ne sont peintes
/// que par le **dernier maillon** d'une chaîne de priorité
/// **paramètre > jeton > référence**, et seulement sous le profil
/// [ZReferenceProfile.legacy], opt-in de l'hôte. Sous
/// [ZReferenceProfile.neutral] — **le défaut** —, [zBusyPaletteOf] rend `null`
/// et l'appelant peint sa propre couleur ambiante — une seule teinte, sans
/// séquence.
///
/// ## Une référence de socle, pas une référence de module
///
/// Le cycle d'occupation n'appartient à aucun module : une feuille de
/// génération d'étude (flashcards, carte mentale, résumé, explication) et une
/// conversation le rendent à l'identique. La référence vit donc dans le socle,
/// que tous consomment, plutôt que dans l'un d'eux — un module ne dépend
/// jamais d'un autre module (invariant AD-1).
///
/// ## AD-13 — une couleur qui bouge n'annonce rien
///
/// Un cycle de couleurs est une animation : l'appelant respecte « Réduire les
/// animations » (ce que [ZColorCycle] fait pour lui) et ne fait **jamais**
/// reposer l'information « occupé » sur la seule teinte — le canal d'annonce
/// reste sémantique.
library;

import 'package:flutter/widgets.dart';

import 'z_color_cycle.dart';
import 'z_reference_profile.dart';
import 'z_theme.dart';

/// Les valeurs de référence du cycle « génération en cours ».
abstract final class ZBusyPaletteReference {
  /// Séquence des **7** teintes parcourues en boucle, dans cet ordre.
  ///
  /// Non dérivable : aucun rôle de `ColorScheme` ne porte une *séquence*.
  /// Remplaçable par jeton ([ZcrudTheme.busyPalette]) et, au dernier maillon,
  /// neutralisable par [ZReferenceProfile.neutral].
  ///
  /// Ces teintes sont sous le plancher de contraste sur certaines surfaces :
  /// un appelant qui les pose sur un fond connu passe par
  /// [ZColorCycle.surface], qui les y porte.
  //
  // Valeurs recopiées à l'octet près de la table de référence du chat,
  // `packages/zcrud_chat/lib/src/presentation/view/z_chat_notebook_reference.dart:476`
  // (`ZChatNotebookReference.busyPalette`) — elle-même relevée sur le legacy.
  // Une garde de ce paquet fige la table et exige l'égalité stricte des sept
  // teintes : les deux listes ne peuvent plus diverger en silence.
  static const List<Color> colors = <Color>[
    Color(0xFF2196F3), // Colors.blue
    Color(0xFFF44336), // Colors.red
    Color(0xFFFFEB3B), // Colors.yellow
    Color(0xFFFF9800), // Colors.orange
    Color(0xFF795548), // Colors.brown
    Color(0xFF009688), // Colors.teal
    Color(0xFF4CAF50), // Colors.green
  ];

  /// Durée d'**un segment** — le temps passé sur une teinte avant la suivante.
  ///
  /// 🔴 Ce n'est pas la durée d'un tour. [ZColorCycle.period] attend un
  /// **tour complet** : un appelant qui branche cette référence multiplie donc
  /// l'intervalle par le nombre de teintes (ce que fait [ZColorCycle.busy]).
  /// Confondre les deux fait défiler la palette sept fois trop vite.
  static const Duration interval = Duration(milliseconds: 300);

  /// Durée d'un **tour complet** de [colors] au tempo de [interval].
  static Duration get period => interval * colors.length;
}

/// La séquence de teintes « occupé » due pour [context], ou `null` quand
/// aucune séquence n'est due.
///
/// Chaîne de priorité : jeton [ZcrudTheme.busyPalette] d'abord ; à défaut, la
/// référence [ZBusyPaletteReference.colors] sous le profil
/// [ZReferenceProfile.legacy], et `null` sous [ZReferenceProfile.neutral],
/// **qui est le défaut**.
///
/// `null` n'est pas une panne : c'est le choix explicite d'un hôte neutre.
/// L'appelant peint alors **une** couleur ambiante de son choix — typiquement
/// `ColorScheme.primary` — sans séquence et donc sans animation.
List<Color>? zBusyPaletteOf(BuildContext context) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  return theme.busyPalette ??
      zLegacyOrIn<List<Color>>(
        theme.referenceProfile,
        ZBusyPaletteReference.colors,
      );
}

/// Le temps passé sur **une** teinte du cycle « occupé » pour [context].
///
/// Scalaire : le jeton [ZcrudTheme.busyCycleInterval] prime, sinon
/// [ZBusyPaletteReference.interval] — dans les **deux** profils. Un profil
/// neutre efface les couleurs de référence, jamais les tempos.
Duration zBusyCycleIntervalOf(BuildContext context) =>
    ZcrudTheme.of(context).busyCycleInterval ?? ZBusyPaletteReference.interval;
