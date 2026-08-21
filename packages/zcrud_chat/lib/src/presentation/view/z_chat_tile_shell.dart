/// La **coquille déclarée** d'une tuile de message : sa carte, son filet, sa
/// coiffe, le style de son bouton de dépli et le format de son horodatage.
///
/// ## Ce que « déclarer » veut dire ici
///
/// [ZChatTileShell] n'est pas un réglage de plus : c'est l'**interrupteur**.
/// Tant qu'aucune coquille n'est déclarée, la tuile rend exactement l'arbre
/// qu'elle rendait sans ce fichier — aucun conteneur, aucun filet, aucune
/// coiffe, aucun horodatage, et un bouton de dépli inchangé. Déclarer
/// `const ZChatTileShell()` demande le **rendu de référence**, celui que
/// [ZChatNotebookReference] documente ; chaque champ renseigné le corrige.
///
/// C'est le sens retenu pour « le rendu de référence en défaut » : défaut **de
/// la référence**, servi à qui déclare la coquille — jamais défaut **du
/// paquet**, qui changerait le rendu de tout hôte n'ayant rien demandé.
///
/// ## Trois niveaux, comme partout ailleurs
///
/// ```
/// parametre  ZChatTileShell.<champ>          <- l'hote, ici et maintenant
///     v (si null)
/// jeton      ZcrudScope.theme.<...>          <- l'hote, pour toute sa surface
///     v (si null / scope absent)
/// reference  ZChatNotebookReference.<...>     <- valeurs de reference auditees
/// ```
///
/// Les champs propres à la coquille (filet, coiffe, bouton de dépli) n'ont pas
/// encore de jeton dédié dans `ZcrudTheme` : leur chaîne compte donc deux
/// niveaux — paramètre, puis référence. Le jeton s'insérera entre les deux
/// sans changer aucune valeur rendue, exactement comme pour le filet du
/// composer.
///
/// ## Aucune couleur inventée
///
/// Ce fichier ne porte **aucun littéral de couleur** (invariant FR-26). La
/// teinte du filet et celle du remplissage du bouton sont des **rôles**,
/// résolus par `zResolveColorKeyOrSlot` : le socle demande un slot de rôle, et
/// c'est le `ColorScheme` de l'hôte qui décide de la valeur peinte. Le
/// remplissage est rendu par une **paire** contrastée (fond + premier plan),
/// donc le libellé du bouton reste lisible quel que soit le thème
/// (invariant AD-13).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_notebook_reference.dart';

/// Formate l'horodatage d'un message — couture d'hôte.
///
/// C'est l'échappatoire du format : le socle n'a aucune dépendance de date et
/// ne connaît donc ni locale ni calendrier. Un hôte qui veut un format
/// localisé branche ici son propre formateur (`DateFormat` d'`intl`, par
/// exemple).
///
/// Un formateur qui **lève** ne casse rien : l'horodatage retombe sur le
/// rendu de référence [zChatReferenceTimestamp] et l'échec est relayé à
/// `FlutterError` (invariant AD-10).
typedef ZChatTimestampFormatter =
    String Function(BuildContext context, DateTime value);

/// Choisit le **sujet du tour** qui coiffe un message.
///
/// [request] est le message de l'utilisateur qui précède [message] dans le
/// fil, ou `null` s'il n'y en a pas.
///
/// 🔴 Ce n'est **pas** l'identité de l'interlocuteur — celle-ci a son propre
/// créneau (`ZChatMessageTile.identityBuilder`) et reste structurellement
/// absente de la surface notebook. Le sujet est ce dont le tour parle, pas
/// qui l'a écrit : les deux se règlent séparément, et l'un ne réactive
/// jamais l'autre.
///
/// Rendre `null` (ou une chaîne vide) signifie **aucune coiffe** pour ce
/// message : c'est ainsi qu'un résolveur ne coiffe que les réponses.
typedef ZChatTurnTopicResolver =
    String? Function(ZChatMessage message, ZChatMessage? request);

/// Résolveur prêt à l'emploi : coiffe une **réponse** du texte de la
/// **question** qui l'a produite.
///
/// Un message d'utilisateur n'est jamais coiffé — il **est** la question. Un
/// message sans question qui le précède ne l'est pas non plus.
String? zChatPrecedingRequestTopic(
  ZChatMessage message,
  ZChatMessage? request,
) {
  if (message.role == ZChatRole.user) return null;
  if (request == null) return null;
  final String text = zChatAccessibleTextOf(request.contentBlocks).trim();
  return text.isEmpty ? null : text;
}

/// Rendu de **référence** d'un horodatage : jour, mois, année, puis heures,
/// minutes et secondes sur deux chiffres.
///
/// Insensible à la locale, et c'est délibéré : c'est le format de la table de
/// référence ([ZChatNotebookReference.timestampFormatPattern]), celui qu'un
/// hôte attend quand il demande la parité stricte. Tout autre besoin passe
/// par un [ZChatTimestampFormatter].
String zChatReferenceTimestamp(DateTime value) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

/// Style du **bouton de dépli** d'une tuile : sa forme, son alignement, son
/// remplissage.
///
/// Tout champ `null` prend la valeur de référence — celle d'une pilule pleine
/// et centrée. Le style ne s'applique qu'à une tuile dont la coquille est
/// déclarée : sans coquille, le bouton reste le texte aligné au début qu'il a
/// toujours été.
@immutable
class ZChatTileToggleStyle {
  /// Construit un style de bouton. `const ZChatTileToggleStyle()` signifie
  /// « la pilule de référence ».
  const ZChatTileToggleStyle({
    this.alignment,
    this.radius,
    this.padding,
    this.filled,
    this.fillColorKey,
    this.fillSlotIndex,
  });

  /// Alignement du bouton dans la largeur de la tuile. `null` ⇒ référence
  /// (centré).
  ///
  /// **Directionnel** (invariant AD-13) : `AlignmentDirectional.centerStart`
  /// se rend à gauche en LTR et à droite en RTL, sans second réglage.
  final AlignmentDirectional? alignment;

  /// Rayon des coins. `null` ⇒ référence (une pilule : la moitié de la
  /// hauteur de cible minimale).
  final Radius? radius;

  /// Marge interne, entre le filet du bouton et son libellé. `null` ⇒
  /// référence. **Directionnelle** (invariant AD-13).
  final EdgeInsetsDirectional? padding;

  /// Peindre un fond ? `null` ⇒ référence (`true`).
  ///
  /// `false` garde la forme et l'alignement demandés mais ne peint rien : le
  /// libellé reprend la couleur de texte ambiante.
  final bool? filled;

  /// Clé de teinte du fond, résolue par le résolveur de l'hôte
  /// (`ZcrudScope.colorKeyResolver`). `null` ⇒ aucune clé, donc le slot de
  /// rôle.
  final String? fillColorKey;

  /// Slot de rôle servant de repli quand [fillColorKey] reste inconnue.
  /// `null` ⇒ référence.
  final int? fillSlotIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatTileToggleStyle &&
          runtimeType == other.runtimeType &&
          alignment == other.alignment &&
          radius == other.radius &&
          padding == other.padding &&
          filled == other.filled &&
          fillColorKey == other.fillColorKey &&
          fillSlotIndex == other.fillSlotIndex;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    alignment,
    radius,
    padding,
    filled,
    fillColorKey,
    fillSlotIndex,
  );
}

/// La coquille déclarée d'une tuile de message.
///
/// Déclarer une coquille — même vide — demande : une carte cernée d'un filet,
/// une coiffe quand [topicOf] rend un sujet, un horodatage quand le message
/// en porte un, et le bouton de dépli en pilule centrée. Ne rien déclarer
/// laisse la tuile strictement inchangée.
///
/// Immuable et strictement additive : un champ de plus ne casse aucun hôte.
@immutable
class ZChatTileShell {
  /// Construit une coquille. Aucun champ n'est requis : `const
  /// ZChatTileShell()` signifie « le rendu de référence, tel quel ».
  const ZChatTileShell({
    this.borderColor,
    this.borderWidth,
    this.radius,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.topicOf,
    this.topicMaxLines,
    this.showTimestamp,
    this.timestampFormatter,
    this.toggle = const ZChatTileToggleStyle(),
  });

  /// Teinte du filet. `null` ⇒ le **rôle** neutre du `ColorScheme` de l'hôte
  /// (le socle ne connaît aucune valeur de couleur).
  final Color? borderColor;

  /// Épaisseur du filet. `null` ⇒ référence.
  ///
  /// `0` ne peint aucun filet : c'est ainsi qu'on obtient une coquille sans
  /// cadre — une coiffe et un horodatage posés à plat.
  final double? borderWidth;

  /// Rayon des coins de la carte. `null` ⇒ jeton `radiusM`, puis référence.
  final Radius? radius;

  /// Fond de la carte. `null` ⇒ **transparent** : la carte est cernée, pas
  /// remplie, à la manière d'une carte à filet.
  final Color? backgroundColor;

  /// Marge **interne** de la carte. `null` ⇒ référence. Directionnelle
  /// (invariant AD-13).
  final EdgeInsetsDirectional? padding;

  /// Marge **externe** de la carte, entre deux tuiles voisines. `null` ⇒
  /// référence. Directionnelle (invariant AD-13).
  final EdgeInsetsDirectional? margin;

  /// Le sujet qui coiffe chaque message — cf. [ZChatTurnTopicResolver].
  ///
  /// `null` (défaut) signifie aucune coiffe : une coquille peut être une
  /// carte nue. [zChatPrecedingRequestTopic] donne la coiffe attendue d'un
  /// notebook — la question au-dessus de sa réponse.
  ///
  /// Ce résolveur est consommé par la vue, seule à connaître le message qui
  /// précède. Une [ZChatMessageTile] montée seule reçoit son sujet déjà
  /// résolu, par son paramètre `topic`.
  final ZChatTurnTopicResolver? topicOf;

  /// Nombre de lignes de la coiffe avant troncature. `null` ⇒ référence.
  ///
  /// La troncature est **visuelle seulement** : le sujet complet reste
  /// annoncé aux lecteurs d'écran.
  final int? topicMaxLines;

  /// Afficher l'horodatage du message ? `null` ⇒ jeton
  /// `ZcrudTheme.chatBubbleShowTimestamp`, puis référence (`true`).
  ///
  /// Un message qui ne porte pas de date (`ZChatMessage.createdAt` nul) n'en
  /// affiche évidemment aucune : le socle ne fabrique pas la donnée qui lui
  /// manque.
  ///
  /// C'est le même jeton et la même référence que
  /// `ZChatNotebookSkin.showTimestamp` — ce dernier sert au backend de
  /// coquille tierce, qui rend l'horodatage lui-même ; celui-ci sert à la
  /// tuile du socle. Les deux se règlent, aucun des deux ne dérive de
  /// l'autre.
  final bool? showTimestamp;

  /// Le format de l'horodatage. `null` ⇒ [zChatReferenceTimestamp].
  final ZChatTimestampFormatter? timestampFormatter;

  /// Le style du bouton de dépli. Le défaut est la pilule de référence.
  final ZChatTileToggleStyle toggle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatTileShell &&
          runtimeType == other.runtimeType &&
          borderColor == other.borderColor &&
          borderWidth == other.borderWidth &&
          radius == other.radius &&
          backgroundColor == other.backgroundColor &&
          padding == other.padding &&
          margin == other.margin &&
          topicOf == other.topicOf &&
          topicMaxLines == other.topicMaxLines &&
          showTimestamp == other.showTimestamp &&
          timestampFormatter == other.timestampFormatter &&
          toggle == other.toggle;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    borderColor,
    borderWidth,
    radius,
    backgroundColor,
    padding,
    margin,
    topicOf,
    topicMaxLines,
    showTimestamp,
    timestampFormatter,
    toggle,
  );
}

/// Les valeurs **résolues** d'une coquille : ce que la tuile peint réellement.
///
/// Réservé à [zChatTileShellStyleOf] et aux tests ; un hôte règle par
/// [ZChatTileShell], pas ici.
@immutable
class ZChatTileShellStyle {
  /// Construit un style résolu.
  const ZChatTileShellStyle({
    required this.borderColor,
    required this.borderWidth,
    required this.radius,
    required this.backgroundColor,
    required this.padding,
    required this.margin,
    required this.topicMaxLines,
    required this.topicWeight,
    required this.showTimestamp,
    required this.toggleAlignment,
    required this.toggleRadius,
    required this.togglePadding,
    required this.toggleFill,
  });

  /// Teinte du filet — jamais nulle : le rôle neutre est le repli.
  final Color borderColor;

  /// Épaisseur du filet. `0` signifie aucun filet peint.
  final double borderWidth;

  /// Rayon des coins de la carte.
  final Radius radius;

  /// Fond de la carte — `null` signifie transparent.
  final Color? backgroundColor;

  /// Marge interne de la carte.
  final EdgeInsetsDirectional padding;

  /// Marge externe de la carte.
  final EdgeInsetsDirectional margin;

  /// Lignes de la coiffe avant troncature visuelle.
  final int topicMaxLines;

  /// Graisse de la coiffe — une graisse seule, jamais un style complet : la
  /// police et la couleur restent celles de l'hôte (invariant FR-26).
  final FontWeight topicWeight;

  /// L'horodatage est-il affiché ?
  final bool showTimestamp;

  /// Alignement du bouton de dépli.
  final AlignmentDirectional toggleAlignment;

  /// Rayon du bouton de dépli.
  final Radius toggleRadius;

  /// Marge interne du bouton de dépli.
  final EdgeInsetsDirectional togglePadding;

  /// Fond et premier plan du bouton de dépli — `null` signifie **aucun
  /// remplissage** : le libellé garde la couleur de texte ambiante.
  ///
  /// La paire vient du `ColorScheme` de l'hôte : le contraste entre le fond
  /// et le libellé est donc garanti, quel que soit le thème (AD-13).
  final ZColorPair? toggleFill;

  /// Le filet est-il réellement peint ?
  ///
  /// Une épaisseur nulle ne peint rien : sans elle, on ne pose pas de côté
  /// (invariant AD-4 — on n'insère pas un décor invisible).
  bool get hasBorder => borderWidth > 0;
}

/// Résout une coquille contre le thème ambiant : paramètre, puis jeton, puis
/// référence.
///
/// Ne lève jamais (invariant AD-10) : une valeur absurde est écrêtée, un
/// scope absent retombe sur la référence.
ZChatTileShellStyle zChatTileShellStyleOf(
  BuildContext context, {
  required ZChatTileShell shell,
}) {
  final ZcrudTheme? theme = ZcrudScope.maybeOf(context)?.theme;
  final bool filled =
      shell.toggle.filled ?? ZChatNotebookReference.tileToggleFilled;
  return ZChatTileShellStyle(
    // Le filet ne connaît aucune valeur : il demande un RÔLE au thème de
    // l'hôte. `''` n'est pas une clé — c'est l'absence de clé, qui envoie
    // directement au slot de repli.
    borderColor:
        shell.borderColor ??
        zResolveColorKeyOrSlot(
          context,
          '',
          slotIndex: ZChatNotebookReference.tileBorderColorSlot,
        ).onColor,
    // Une épaisseur négative est écrêtée à 0 : un paramètre absurde ne fait
    // pas lever le rendu.
    borderWidth: (shell.borderWidth ?? ZChatNotebookReference.tileBorderWidth)
        .clamp(0.0, double.infinity),
    radius:
        shell.radius ?? theme?.radiusM ?? ZChatNotebookReference.tileRadius,
    backgroundColor: shell.backgroundColor,
    padding: shell.padding ?? ZChatNotebookReference.tilePadding,
    margin: shell.margin ?? ZChatNotebookReference.tileMargin,
    // Une coiffe de zéro ligne serait une coiffe invisible mais annoncée :
    // le plancher est 1.
    topicMaxLines: (shell.topicMaxLines ??
            ZChatNotebookReference.tileTopicMaxLines)
        .clamp(1, 0x7fffffff),
    topicWeight: ZChatNotebookReference.messageTitleWeight,
    showTimestamp:
        shell.showTimestamp ??
        theme?.chatBubbleShowTimestamp ??
        ZChatNotebookReference.showTimestamp,
    toggleAlignment:
        shell.toggle.alignment ?? ZChatNotebookReference.tileToggleAlignment,
    toggleRadius:
        shell.toggle.radius ?? ZChatNotebookReference.tileToggleRadius,
    togglePadding:
        shell.toggle.padding ?? ZChatNotebookReference.tileTogglePadding,
    toggleFill: filled
        ? zResolveColorKeyOrSlot(
            context,
            shell.toggle.fillColorKey ?? '',
            slotIndex:
                shell.toggle.fillSlotIndex ??
                ZChatNotebookReference.tileToggleFillSlot,
          )
        : null,
  );
}
