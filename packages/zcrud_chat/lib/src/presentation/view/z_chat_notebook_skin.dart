/// **Lot γ (CR-IFFD-72)** — la chaîne de résolution du rendu Notebook :
/// **paramètre > jeton > référence**.
///
/// ## Pourquoi ce fichier vit dans `zcrud_chat` et non dans le satellite
///
/// Le « skin » du notebook doit être **pur** : `zcrud_chat` n'a aucune arête
/// Syncfusion (garde `z_chat_purity_test`), et l'arbitrage de priorité — la
/// seule chose qui puisse se tromper — doit pouvoir être **prouvé sans monter
/// Syncfusion**. [ZChatNotebookSkin] ne connaît donc aucun type de coquille : il
/// résout des valeurs neutres, et `zcrud_chat_syncfusion` se contente de les
/// **mapper** sur `AssistMessageSettings`.
///
/// ## 🔴 Trois niveaux, jamais deux
///
/// ```
/// paramètre  ZChatNotebookSkin.<champ>          ← l'hôte, ici et maintenant
///     ▼ (si null)
/// jeton      ZcrudTheme.chat<…>                 ← l'hôte, pour toute sa surface
///     ▼ (si null)
/// référence  ZChatNotebookReference.<…>         ← IFFD legacy, mesuré
/// ```
///
/// Les trois niveaux sont atteints **séparément** par
/// `test/z_chat_notebook_skin_test.dart` : un test qui ne prouverait que
/// « paramètre gagne » serait vert sur une implémentation qui ignore le jeton.
///
/// ## 🔴 Ce que le thème ne peut PAS écraser
///
/// Les canaux **non chromatiques** des capacités
/// ([ZChatNotebookCapabilityStyle.generatedLabelKey] et
/// [ZChatNotebookCapabilityStyle.generatedMarkSize]) n'ont **aucun** jeton et
/// **aucun** paramètre. Seul l'accent — le canal décoratif — est remplaçable.
/// Un jeton qui pourrait effacer le canal textuel rouvrirait exactement le
/// défaut « information portée par la seule couleur » que ce lot ferme.
///
/// ## Hôte passif
///
/// Ce fichier n'est monté par **aucune** vue : `ZChatConversationView` et
/// `ZChatNotebookView` ne le lisent pas et leur arbre est inchangé. Le skin est
/// **opt-in**, consommé uniquement par le backend de coquille auquel l'hôte le
/// passe explicitement.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_notebook_reference.dart';

/// Réglage **partiel** du rendu Notebook : tout champ `null` délègue au niveau
/// suivant (jeton, puis référence).
///
/// Strictement additif et **immuable** : un champ de plus ne casse aucun hôte.
@immutable
class ZChatNotebookSkin {
  /// Construit un réglage. Aucun champ n'est requis : `const
  /// ZChatNotebookSkin()` signifie « le rendu de référence IFFD, tel quel ».
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
  });

  /// Fraction de largeur des bulles. `null` ⇒ jeton, puis
  /// [ZChatNotebookReference.bubbleWidthFactor].
  final double? bubbleWidthFactor;

  /// Rayon de la bulle de **requête**. `null` ⇒ jeton, puis référence.
  final Radius? requestBubbleRadius;

  /// Rayon de la bulle de **réponse**.
  ///
  /// 🔴 Le legacy n'en pose **aucun** ([ZChatNotebookReference.responseBubbleRadius]
  /// vaut `null`) : laissé nul, la coquille garde son propre défaut. Le renseigner
  /// est un choix de l'hôte, pas une valeur de référence.
  final Radius? responseBubbleRadius;

  /// Afficher l'avatar d'auteur ? `null` ⇒ jeton, puis référence (`false`).
  final bool? showAuthorAvatar;

  /// Afficher le nom d'auteur ? `null` ⇒ jeton, puis référence (`false`).
  final bool? showAuthorName;

  /// Afficher l'horodatage ? `null` ⇒ jeton, puis référence (`true`).
  final bool? showTimestamp;

  /// Teinte d'identité des affordances d'outils (exception FR-26 encadrée).
  final Color? toolAccentColor;

  /// Accents **par capacité**, indexés par clé (`mindmap`, `flashcards`, …).
  ///
  /// La table est consultée **clé par clé** : renseigner `mindmap` seul ne fait
  /// pas disparaître les quatre autres accents de référence.
  final Map<String, Color>? capabilityAccents;

  /// Séquence de teintes de l'indicateur d'occupation (exception FR-26).
  final List<Color>? busyPalette;

  /// Résout les trois niveaux contre le thème ambiant.
  ///
  /// **Ne lève jamais** (AD-10) : un thème absent retombe sur
  /// `ZcrudTheme.fallback`, et une table de jetons vide sur la référence.
  ZChatNotebookStyle resolve(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
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
          ZChatNotebookReference.toolAccentColor,
      busyPalette:
          busyPalette ??
          theme.chatBusyPalette ??
          ZChatNotebookReference.busyPalette,
      capabilityAccents: capabilityAccents,
      themeCapabilityAccents: theme.chatCapabilityAccents,
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
  final List<Color> busyPalette;

  /// Accents de capacité fournis en **paramètre** (niveau 1).
  final Map<String, Color>? capabilityAccents;

  /// Accents de capacité fournis en **jeton** (niveau 2).
  final Map<String, Color>? themeCapabilityAccents;

  /// Style complet d'une capacité — accent résolu aux trois niveaux, canaux non
  /// chromatiques **toujours** ceux de la référence.
  ///
  /// Rend `null` pour une clé que la référence ne connaît pas : une capacité
  /// future n'obtient pas un style inventé (AD-10). Un accent fourni pour une
  /// clé inconnue est donc **ignoré**, jamais promu en style incomplet.
  ZChatNotebookCapabilityStyle? capability(String key) {
    final ZChatNotebookCapabilityStyle? base =
        ZChatNotebookReference.capabilities[key];
    if (base == null) return null;
    final Color? accent =
        capabilityAccents?[key] ?? themeCapabilityAccents?[key];
    if (accent == null) return base;
    return ZChatNotebookCapabilityStyle(
      accent: accent,
      generatedLabelKey: base.generatedLabelKey,
      generatedMarkSize: base.generatedMarkSize,
    );
  }
}
