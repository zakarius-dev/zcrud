/// Chaîne de résolution du rendu notebook : paramètre > jeton > référence.
///
/// ## Pourquoi ce fichier vit dans `zcrud_chat` et non dans un satellite
///
/// Le rendu de référence du notebook doit rester pur : `zcrud_chat` n'a
/// aucune arête vers un moteur de rendu tiers, et l'arbitrage de priorité —
/// la seule chose qui puisse se tromper — doit pouvoir être prouvé sans
/// monter de dépendance de rendu. [ZChatNotebookSkin] ne connaît donc aucun
/// type de coquille : il résout des valeurs neutres, qu'un satellite de rendu
/// se contente de mapper sur son propre modèle.
///
/// ## Trois niveaux, jamais deux
///
/// ```
/// parametre  ZChatNotebookSkin.<champ>          <- l'hote, ici et maintenant
///     v (si null)
/// jeton      ZcrudTheme.chat<...>               <- l'hote, pour toute sa surface
///     v (si null)
/// reference  ZChatNotebookReference.<...>        <- valeurs de reference auditees
/// ```
///
/// ## Ce que le thème ne peut pas écraser
///
/// Les canaux non chromatiques des capacités
/// ([ZChatNotebookCapabilityStyle.generatedLabelKey] et
/// [ZChatNotebookCapabilityStyle.generatedMarkSize]) n'ont aucun jeton et
/// aucun paramètre. Seul l'accent — le canal décoratif — est remplaçable :
/// une information ne repose ainsi jamais sur la seule couleur.
///
/// ## Hôte passif
///
/// Le skin est **opt-in** : ne pas en passer laisse l'arbre des vues
/// strictement inchangé. En passer un ne suffit d'ailleurs pas à changer le
/// rendu — chaque champ est lu par le seul rendu qui le concerne, et
/// [ZChatNotebookSkin.tile] doit être **déclaré** pour qu'une tuile prenne
/// une coquille. Un skin qui ne porterait que des accents de capacité ne
/// dessine donc aucune carte.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_notebook_reference.dart';
import 'z_chat_tile_shell.dart';

/// Arbitre un membre COULEUR du carnet entre sa référence auditée et le rôle
/// de l'hôte : [reference] partout, sauf sous un [ZReferenceProfile.neutral]
/// **déclaré**, où [neutral] l'emporte.
///
/// Le carnet de chat possède sa propre référence et la garde comme **défaut** :
/// il faut déclarer le profil neutre pour l'éteindre, un profil simplement
/// absent ne suffit pas. C'est la seule différence avec `zLegacyOrIn`, qui rend
/// la valeur neutre dès que le profil est absent.
//
// Le socle a basculé son défaut global sur `neutral`. Le carnet ne suit pas :
// son apparence de référence EST son rendu, et la faire disparaître chez tous
// les hôtes non déclarants aurait changé un écran entier sans que personne ne
// l'ait demandé. L'échappatoire reste entière — `referenceProfile: neutral`
// éteint la référence ici comme partout ailleurs.
T? _zChatReferenceUnlessNeutral<T>(
  ZReferenceProfile? profile,
  T reference, [
  T? neutral,
]) =>
    profile == ZReferenceProfile.neutral ? neutral : reference;

/// Réglage **partiel** du rendu Notebook : tout champ `null` délègue au niveau
/// suivant (jeton, puis référence).
///
/// Strictement additif et **immuable** : un champ de plus ne casse aucun hôte.
@immutable
class ZChatNotebookSkin {
  /// Construit un réglage. Aucun champ n'est requis : `const
  /// ZChatNotebookSkin()` signifie « le rendu de référence, tel quel ».
  const ZChatNotebookSkin({
    this.bubbleWidthFactor,
    this.requestBubbleRadius,
    this.responseBubbleRadius,
    this.showAuthorAvatar,
    this.showAuthorName,
    this.showTimestamp,
    this.toolAccentColor,
    this.capabilityAccents,
    this.busyPalette,
    this.tile,
  });

  /// Fraction de largeur des bulles. `null` ⇒ jeton, puis
  /// [ZChatNotebookReference.bubbleWidthFactor].
  final double? bubbleWidthFactor;

  /// Rayon de la bulle de **requête**. `null` ⇒ jeton, puis référence.
  final Radius? requestBubbleRadius;

  /// Rayon de la bulle de réponse.
  ///
  /// La référence n'en pose aucun
  /// ([ZChatNotebookReference.responseBubbleRadius] vaut `null`) : laissé
  /// nul, la coquille garde son propre défaut. Le renseigner est un choix de
  /// l'hôte, pas une valeur de référence.
  final Radius? responseBubbleRadius;

  /// Afficher l'avatar d'auteur ? `null` ⇒ jeton, puis référence (`false`).
  final bool? showAuthorAvatar;

  /// Afficher le nom d'auteur ? `null` ⇒ jeton, puis référence (`false`).
  final bool? showAuthorName;

  /// Afficher l'horodatage ? `null` ⇒ jeton, puis référence (`true`).
  final bool? showTimestamp;

  /// Teinte d'identité des affordances d'outils.
  final Color? toolAccentColor;

  /// Accents **par capacité**, indexés par clé (`mindmap`, `flashcards`, …).
  ///
  /// La table est consultée **clé par clé** : renseigner `mindmap` seul ne fait
  /// pas disparaître les quatre autres accents de référence.
  final Map<String, Color>? capabilityAccents;

  /// Séquence de teintes de l'indicateur d'occupation.
  final List<Color>? busyPalette;

  /// La **coquille** des tuiles : carte, filet, coiffe, style du bouton de
  /// dépli, format d'horodatage.
  ///
  /// `null` (défaut) signifie **aucune coquille** : les tuiles rendent
  /// exactement l'arbre qu'elles rendaient sans ce champ. Déclarer
  /// `const ZChatTileShell()` demande le rendu de référence, corrigeable
  /// champ par champ — cf. [ZChatTileShell].
  final ZChatTileShell? tile;

  /// Résout les trois niveaux contre le thème ambiant.
  ///
  /// Ne lève jamais (invariant AD-10) : un thème absent retombe sur
  /// `ZcrudTheme.fallback`, et une table de jetons vide sur la référence.
  ///
  /// ## Le quatrième maillon : le profil de référence
  ///
  /// Les membres **couleur** — et eux seuls — passent au dernier maillon par
  /// [ZReferenceProfile]. Un profil **absent** rend la référence : le carnet de
  /// chat garde son apparence comme défaut, et rien ne change pour un hôte qui
  /// n'a rien déclaré. Seul un [ZReferenceProfile.neutral] **déclaré** efface
  /// la référence au profit du **rôle Material 3 de l'hôte** : accent d'outils
  /// et accents de capacité prennent le premier plan du slot
  /// [ZColorSlot.primary], et [ZChatNotebookStyle.busyPalette] devient vide —
  /// aucune séquence n'est due, l'appelant peint une teinte ambiante unique.
  ///
  /// Les membres non chromatiques (fractions, rayons, drapeaux, coquille) ne
  /// sont **jamais** concernés : un profil neutre efface des couleurs, pas une
  /// géométrie.
  ZChatNotebookStyle resolve(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZReferenceProfile? profile = theme.referenceProfile;
    // Le rôle M3 de l'hôte, obtenu SANS `package:flutter/material.dart` (banni
    // dans ce paquet, garde de pureté) : la chaîne de `zcrud_core` rend la
    // paire du slot `primary` du `ColorScheme` ambiant — ou celle que le
    // `colorKeyResolver` de l'hôte déclare pour cette clé, ce qui est
    // précisément le vocabulaire qu'un hôte neutre veut voir gagner.
    final ZColorPair neutralPair = zResolveColorKeyOrSlot(
      context,
      ZColorSlot.primary.name,
      slotIndex: ZColorSlot.primary.index,
    );
    return ZChatNotebookStyle(
      bubbleWidthFactor:
          bubbleWidthFactor ??
          theme.chatBubbleWidthFactor ??
          ZChatNotebookReference.bubbleWidthFactor,
      requestBubbleRadius:
          requestBubbleRadius ??
          theme.chatRequestBubbleRadius ??
          ZChatNotebookReference.requestBubbleRadius,
      responseBubbleRadius:
          responseBubbleRadius ??
          theme.chatResponseBubbleRadius ??
          ZChatNotebookReference.responseBubbleRadius,
      showAuthorAvatar:
          showAuthorAvatar ??
          theme.chatBubbleShowAuthorAvatar ??
          ZChatNotebookReference.showAuthorAvatar,
      showAuthorName:
          showAuthorName ??
          theme.chatBubbleShowAuthorName ??
          ZChatNotebookReference.showAuthorName,
      showTimestamp:
          showTimestamp ??
          theme.chatBubbleShowTimestamp ??
          ZChatNotebookReference.showTimestamp,
      toolAccentColor:
          toolAccentColor ??
          theme.chatToolAccentColor ??
          _zChatReferenceUnlessNeutral<Color>(
            profile,
            ZChatNotebookReference.toolAccentColor,
            neutralPair.onColor,
          )!,
      // Avant-dernier maillon : le jeton `ZcrudTheme.busyPalette` du socle, lu
      // par `zBusyPaletteOf` — c'est ce qui branche le chat sur le jeton commun
      // au lieu de sa copie. Le socle ne rend sa RÉFÉRENCE que sous le profil
      // `legacy`; en dessous, le carnet prend la sienne, qui EST la référence
      // commune (`ZChatNotebookReference.busyPalette`) — d'où un rendu par
      // défaut inchangé, et un `neutral` déclaré qui éteint bien la séquence.
      busyPalette:
          busyPalette ??
          theme.chatBusyPalette ??
          zBusyPaletteOf(context) ??
          _zChatReferenceUnlessNeutral<List<Color>>(
            profile,
            ZChatNotebookReference.busyPalette,
            const <Color>[],
          )!,
      capabilityAccents: capabilityAccents,
      themeCapabilityAccents: theme.chatCapabilityAccents,
      neutralAccent:
          _zChatReferenceUnlessNeutral<Color?>(profile, null, neutralPair.onColor),
      tile: tile,
    );
  }
}

/// Les valeurs **résolues** du rendu Notebook — aucune n'est nulle, sauf celles
/// dont l'absence est elle-même la valeur de référence
/// ([responseBubbleRadius]).
@immutable
class ZChatNotebookStyle {
  /// Construit un style résolu. Réservé à [ZChatNotebookSkin.resolve] et aux
  /// tests ; un hôte règle par [ZChatNotebookSkin], pas ici.
  const ZChatNotebookStyle({
    required this.bubbleWidthFactor,
    required this.requestBubbleRadius,
    required this.responseBubbleRadius,
    required this.showAuthorAvatar,
    required this.showAuthorName,
    required this.showTimestamp,
    required this.toolAccentColor,
    required this.busyPalette,
    this.capabilityAccents,
    this.themeCapabilityAccents,
    this.neutralAccent,
    this.tile,
  });

  /// Fraction de largeur des bulles.
  final double bubbleWidthFactor;

  /// Rayon de la bulle de requête.
  final Radius requestBubbleRadius;

  /// Rayon de la bulle de réponse — `null` ⇒ défaut de la coquille (le legacy
  /// n'en pose aucun).
  final Radius? responseBubbleRadius;

  /// Avatar d'auteur affiché ?
  final bool showAuthorAvatar;

  /// Nom d'auteur affiché ?
  final bool showAuthorName;

  /// Horodatage affiché ?
  final bool showTimestamp;

  /// Teinte d'identité des affordances d'outils.
  final Color toolAccentColor;

  /// Séquence de teintes de l'indicateur d'occupation.
  ///
  /// **Vide** signifie « aucune séquence n'est due » — c'est ce que rend un
  /// profil de référence neutre quand ni paramètre ni jeton n'en déclarent
  /// une. Ce n'est pas une panne : l'appelant peint alors **une** teinte
  /// ambiante, sans séquence donc sans animation.
  final List<Color> busyPalette;

  /// Accents de capacité fournis en **paramètre** (niveau 1).
  final Map<String, Color>? capabilityAccents;

  /// Accents de capacité fournis en **jeton** (niveau 2).
  final Map<String, Color>? themeCapabilityAccents;

  /// Teinte qui remplace les accents de **référence** des capacités, ou `null`
  /// quand la référence s'applique (profil de référence par défaut).
  ///
  /// Non nulle, elle porte un rôle du `ColorScheme` de l'hôte et se substitue
  /// à l'accent de référence de **chaque** capacité que ni paramètre ni jeton
  /// ne déclarent : le code-couleur de référence disparaît alors en bloc, et
  /// c'est le but. La distinction entre capacités reste portée par les canaux
  /// non chromatiques ([ZChatNotebookCapabilityStyle.generatedLabelKey] et
  /// [ZChatNotebookCapabilityStyle.generatedMarkSize]), qu'aucun profil
  /// n'efface.
  final Color? neutralAccent;

  /// La coquille déclarée, relayée telle quelle — `null` signifie aucune
  /// coquille. Elle n'a pas de niveau « jeton » : c'est une **déclaration**,
  /// pas une valeur, et un thème ne doit pas pouvoir faire naître une carte
  /// que l'hôte n'a pas demandée.
  final ZChatTileShell? tile;

  /// Style complet d'une capacité — accent résolu aux trois niveaux, canaux non
  /// chromatiques **toujours** ceux de la référence.
  ///
  /// Rend `null` pour une clé que la référence ne connaît pas : une capacité
  /// future n'obtient pas un style inventé (invariant AD-10). Un accent
  /// fourni pour une clé inconnue est donc ignoré, jamais promu en style
  /// incomplet.
  ZChatNotebookCapabilityStyle? capability(String key) {
    final ZChatNotebookCapabilityStyle? base =
        ZChatNotebookReference.capabilities[key];
    if (base == null) return null;
    final Color? accent =
        capabilityAccents?[key] ?? themeCapabilityAccents?[key] ??
        // Dernier maillon : la référence, sauf sous un profil neutre où
        // l'accent de l'hôte la remplace (`neutralAccent` non nul).
        neutralAccent;
    if (accent == null) return base;
    return ZChatNotebookCapabilityStyle(
      accent: accent,
      generatedLabelKey: base.generatedLabelKey,
      generatedMarkSize: base.generatedMarkSize,
    );
  }
}
