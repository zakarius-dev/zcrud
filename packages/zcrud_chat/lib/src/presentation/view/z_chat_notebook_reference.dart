/// Les valeurs de rendu de référence de la surface notebook, centralisées
/// en un seul endroit — même patron que `ZChatComposerReference`.
///
/// ## Ce que ce fichier est — et n'est pas
///
/// Ce fichier est deux choses distinctes, et le dartdoc de chaque constante
/// le dit :
/// 1. les quelques valeurs que le socle résout et applique lui-même (par
///    [ZChatNotebookSkin], mappées sur un modèle de rendu par un satellite) ;
/// 2. le catalogue des valeurs de chrome (composer, feuille d'outils, badges,
///    indicateur d'occupation) qu'un hôte qui reproduit ce chrome doit lire
///    ici plutôt que les figer de nouveau chez lui.
///
/// ## Exception encadrée sur les couleurs codées en dur
///
/// Ce fichier est l'un des deux seuls de `zcrud_chat` autorisés à porter des
/// couleurs littérales, à trois conditions strictes :
///
/// 1. Centralisation — toutes les valeurs vivent ici, dans l'unique fichier
///    de référence audité de la famille « notebook » ;
/// 2. Remplaçabilité — chaque couleur est remplaçable par paramètre
///    ([ZChatNotebookSkin]) et par jeton (`ZcrudTheme.chatToolAccentColor`,
///    `ZcrudTheme.chatCapabilityAccents`, `ZcrudTheme.chatBusyPalette`),
///    priorité paramètre > jeton > référence ;
/// 3. Exemption nominative — la garde de source qui interdit les couleurs
///    codées en dur exempte ce fichier par son nom exact, et seulement de sa
///    règle de couleur : l'invariant AD-13 (directionnalité) y reste
///    appliqué, comme partout ailleurs.
///
/// ## Trois familles de couleurs portées, quatre refusées
///
/// Le critère retenu est « non dérivable d'un `ColorScheme` » :
///
/// | Famille | Décision |
/// |---|---|
/// | dégradé de l'indicateur d'occupation (7 teintes) | portée ([busyPalette]) — aucune séquence de rôles n'existe |
/// | teinte des interrupteurs/chevrons d'outils | portée ([toolAccentColor]) — teinte d'identité, pas un rôle |
/// | code-couleur par capacité (mindmap/flashcards/variantes) | portée ([capabilities]) — vocabulaire produit, jamais un rôle |
/// | couleur des badges compteurs | refusée — dérivable de `ColorScheme.error` |
/// | couleur de l'icône « joindre » active | refusée — dérivable de `ColorScheme.primary` |
/// | couleur de repli de la bordure de focus | refusée — un repli doit être un rôle |
/// | couleur des sous-titres | refusée — dérivable de `ColorScheme.onSurfaceVariant` |
///
/// ## Ce que ce fichier ne déclare délibérément pas
///
/// Une valeur qui ne peut pas être lue ici ne peut pas être reproduite par
/// inadvertance. Ce fichier ne déclare aucune cible tactile sous 48 dp, aucun
/// décalage non directionnel (toutes les marges sont `EdgeInsetsDirectional`,
/// tous les décalages sont nommés `…TopInset`/`…EndInset`, invariant AD-13),
/// aucun libellé en dur ([ZChatNotebookCapabilityStyle.generatedLabelKey]
/// porte une clé, résolue par `zChatLabel`), et aucune échelle de texte qui
/// écraserait le réglage d'accessibilité de l'utilisateur. Une information ne
/// repose jamais sur la seule couleur : [ZChatNotebookCapabilityStyle] exige,
/// en plus de l'accent, deux canaux non chromatiques, requis, donc une
/// teinte seule est inexprimable.
///
/// ## Contraste et thème sombre
///
/// Contraste WCAG 2.x mesuré :
///
/// | teinte | sur surface claire `#FFFFFF` | sur surface sombre `#121212` |
/// |---|---|---|
/// | mindmap / outils `#FF9800` | 2.16 (insuffisant) | 8.69 |
/// | flashcards `#2196F3` | 3.12 | 6.00 |
/// | histoire `#009688` | 3.67 | 5.10 |
/// | humour `#FFEB3B` | 1.22 (insuffisant) | 15.34 |
/// | classe `#8BC34A` | 2.10 (insuffisant) | 8.92 |
/// | occupation `#F44336` (rouge) | 3.68 | 5.09 |
/// | occupation `#4CAF50` (vert) | 2.78 (insuffisant) | 6.74 |
/// | occupation `#795548` (brun) | 6.55 | 2.86 (insuffisant) |
///
/// Sur les 8 teintes distinctes portées ici, 5 échouent au seuil WCAG 3.0
/// dans au moins une des deux luminosités — majoritairement en thème clair.
/// La correction retenue n'est pas de les recolorer (ce serait renoncer à la
/// fidélité visuelle sur le seul axe où elle est demandée) : c'est de
/// garantir qu'aucune information ne repose sur elles, ce que le type
/// [ZChatNotebookCapabilityStyle] rend structurel en exigeant deux canaux
/// non chromatiques. Un hôte qui veut une teinte conforme la pose par jeton
/// ou par paramètre — la chaîne est faite pour cela.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_labels.dart';

/// Style de référence d'une capacité du notebook (carte mentale, flashcards,
/// variantes de transformation).
///
/// La teinte n'existe jamais seule. Si la présence d'un contenu déjà généré
/// se signalait par le seul changement de couleur d'une icône, un
/// utilisateur daltonien — ou un utilisateur d'un thème qui écrase la teinte
/// — perdrait le signal. Les deux canaux non chromatiques sont donc
/// `required` : le type rend ce défaut inexprimable, au lieu de le
/// déconseiller.
@immutable
class ZChatNotebookCapabilityStyle {
  /// Construit un style de capacité — les trois canaux sont obligatoires.
  const ZChatNotebookCapabilityStyle({
    required this.accent,
    required this.generatedLabelKey,
    required this.generatedMarkSize,
  });

  /// Canal chromatique — décoratif, jamais porteur d'information seul.
  ///
  /// Remplaçable par jeton (`ZcrudTheme.chatCapabilityAccents`) et par
  /// paramètre (`ZChatNotebookSkin.capabilityAccents`).
  final Color accent;

  /// Canal textuel — la clé de libellé annoncée quand la capacité a déjà
  /// produit un contenu. C'est une clé, jamais un libellé : elle traverse
  /// `zChatLabel` (registre de l'hôte → traduction → repli lisible).
  ///
  /// Non remplaçable par thème — un jeton qui pourrait l'effacer rouvrirait
  /// la porte à une information portée par la seule couleur.
  final String generatedLabelKey;

  /// Canal de forme — diamètre de la pastille visible qui marque l'état
  /// « déjà généré ». Une forme se voit sans distinguer les teintes.
  ///
  /// Non remplaçable par thème, même raison.
  final double generatedMarkSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatNotebookCapabilityStyle &&
          runtimeType == other.runtimeType &&
          accent == other.accent &&
          generatedLabelKey == other.generatedLabelKey &&
          generatedMarkSize == other.generatedMarkSize;

  @override
  int get hashCode =>
      Object.hash(runtimeType, accent, generatedLabelKey, generatedMarkSize);

  @override
  String toString() =>
      'ZChatNotebookCapabilityStyle(accent: $accent, mark: $generatedMarkSize)';
}

/// Clé de capacité « carte mentale ».
const String kZChatCapabilityMindmap = 'mindmap';

/// Clé de capacité « flashcards ».
const String kZChatCapabilityFlashcards = 'flashcards';

/// Clé de variante « histoire fantastique ».
const String kZChatCapabilityStory = 'story';

/// Clé de variante « humour ».
const String kZChatCapabilityHumour = 'humour';

/// Clé de variante « chat / salle de classe ».
const String kZChatCapabilityClassroom = 'classroom';

/// Les valeurs de référence du rendu notebook — le point d'audit unique.
///
/// Modifier une valeur ici change le défaut du skin partout ; ajouter une
/// couleur ici, et nulle part ailleurs, reste dans le cadre de l'exception
/// encadrée (cf. le dartdoc de bibliothèque).
abstract final class ZChatNotebookReference {
  // ── Bulle de message ─────────────────────────────────────────────────

  /// Fraction de largeur d'une bulle en usage notebook.
  static const double bubbleWidthFactor = 0.95;

  /// Fraction de largeur d'une bulle en usage conversation.
  ///
  /// Portée pour que le contraste des deux usages soit lisible ici, à
  /// l'endroit où l'arbitrage se fait.
  static const double conversationBubbleWidthFactor = 1;

  /// Rayon de la bulle de requête.
  static const Radius requestBubbleRadius = Radius.circular(12);

  /// La bulle de réponse n'a aucun rayon de référence : elle hérite du
  /// défaut de la coquille de rendu. En inventer un ici serait une valeur
  /// que personne n'a mesurée — le skin laisse donc `responseBubbleRadius`
  /// à `null`, et c'est intentionnel.
  static const Radius? responseBubbleRadius = null;

  /// Avatar d'auteur affiché ? Non en usage notebook.
  static const bool showAuthorAvatar = false;

  /// Nom d'auteur affiché ? Non en usage notebook.
  static const bool showAuthorName = false;

  /// Horodatage affiché ? Oui hors lecture seule.
  static const bool showTimestamp = true;

  /// Motif d'horodatage de référence.
  ///
  /// Le socle ne l'applique pas automatiquement : c'est un format figé,
  /// insensible à la locale, et l'imposer à tout hôte reproduirait un
  /// défaut de libellé en dur une couche plus bas. La valeur est publiée
  /// pour l'hôte qui veut une parité stricte
  /// (`DateFormat(ZChatNotebookReference.timestampFormatPattern)`) ; à
  /// défaut, le format reste celui du backend de coquille, qui suit la
  /// locale.
  static const String timestampFormatPattern = 'dd/MM/yyyy HH:mm:ss';

  // ── Composer ─────────────────────────────────────────────────────────

  /// Marge du conteneur de saisie — rendue directionnelle (invariant AD-13).
  static const EdgeInsetsDirectional composerPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8);

  /// Rayon du conteneur de saisie et du champ.
  static const Radius composerRadius = Radius.circular(12);

  /// Nombre minimal de lignes du champ.
  static const int composerMinLines = 1;

  /// Nombre maximal de lignes du champ.
  static const int composerMaxLines = 5;

  /// Espacement de la rangée d'affordances sous le champ.
  static const double composerActionRowSpacing = 5;

  /// Opacité du filet qui sépare le champ de sa rangée d'affordances — la
  /// couleur reste un rôle de thème, seule l'opacité est une valeur de
  /// référence.
  ///
  /// Cette valeur appartient à la famille « notebook » : la famille
  /// composer a son propre point d'audit (`ZChatComposerReference`). Son
  /// unique consommateur légitime serait un champ de [ZChatNotebookSkin]
  /// rendu par la vue notebook. Tant qu'il n'existe pas, elle reste une
  /// mesure publiée et auditable, que l'hôte qui veut ce filet peut lire et
  /// appliquer lui-même.
  static const double composerHelperDividerAlpha = 0.1;

  /// Côté du bouton d'envoi.
  ///
  /// C'est le plancher tactile de l'invariant AD-13, le même que
  /// `kZChatMinTapTarget` — deux planchers qui divergeraient seraient pires
  /// qu'un seul.
  static const double sendButtonSize = 48;

  /// Échelle du bouton d'envoi quand la saisie est vide.
  static const double sendButtonScaleIdle = 0.7;

  /// Échelle du bouton d'envoi quand la saisie est non vide.
  static const double sendButtonScaleActive = 1;

  /// Durée de la transition d'échelle du bouton d'envoi.
  static const Duration sendButtonScaleDuration = Duration(milliseconds: 150);

  /// Rayon des puces de réglage (« Réfléchir », résumé).
  static const Radius chipRadius = Radius.circular(12);

  /// Marge d'un badge compteur — rendue directionnelle.
  static const EdgeInsetsDirectional counterBadgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4);

  /// Rayon d'un badge compteur.
  static const Radius counterBadgeRadius = Radius.circular(8);

  /// Rayon de la pastille compteur de l'icône « joindre ».
  static const double attachBadgeRadius = 8;

  /// Décalage haut de la pastille « joindre ».
  static const double attachBadgeTopInset = 0;

  /// Décalage de fin de la pastille « joindre » (invariant AD-13 : nommé
  /// `End`, pas `Right`, pour rester utilisable via
  /// `PositionedDirectional(end:)`).
  static const double attachBadgeEndInset = 0;

  // ── Actions par message ──────────────────────────────────────────────

  /// Côté d'une icône d'action par message.
  ///
  /// C'est la taille du glyphe, jamais celle de la cible tactile : celle-ci
  /// reste `kZChatMinTapTarget`.
  static const double perMessageActionIconSize = 24;

  /// Rayon de la pastille compteur d'une action par message.
  static const double perMessageActionBadgeRadius = 8;

  /// Corps du compteur d'une action par message.
  static const double perMessageActionBadgeFontSize = 10;

  /// Décalage haut de la pastille compteur.
  static const double perMessageActionBadgeTopInset = 5;

  /// Décalage de fin de la pastille compteur (invariant AD-13).
  static const double perMessageActionBadgeEndInset = 5;

  // ── Feuille d'outils ─────────────────────────────────────────────────

  /// Marge du corps de la feuille d'outils.
  static const EdgeInsetsDirectional toolsSheetPadding =
      EdgeInsetsDirectional.all(4);

  /// Espacement courant entre sections de la feuille.
  static const double toolsSheetSectionGap = 10;

  /// Espacement appuyé avant une famille de sections.
  static const double toolsSheetSectionGapLarge = 20;

  /// Côté du glyphe d'en-tête de la feuille.
  static const double toolsSheetHeaderIconSize = 30;

  /// Marge d'une tuile d'outil.
  static const EdgeInsetsDirectional toolTilePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8);

  // ── Contenu replié d'un message ──────────────────────────────────────

  /// Hauteur minimale d'un contenu replié.
  static const double collapsedContentMinHeight = 100;

  /// Hauteur maximale absolue d'un contenu replié.
  static const double collapsedContentMaxHeight = 250;

  /// Fraction de hauteur d'écran bornant un contenu replié.
  static const double collapsedContentMaxHeightFactor = 0.3;

  /// Durée du dépli/repli.
  static const Duration collapsedContentDuration = Duration(milliseconds: 300);

  // ── Indicateur d'occupation ──────────────────────────────────────────

  /// Durée d'un tour complet du cycle.
  static const Duration busyCycleDuration = Duration(seconds: 2);

  /// Durée d'un segment du cycle.
  static const Duration busySegmentDuration = Duration(milliseconds: 300);

  /// Flou du halo.
  static const double busyHaloBlurRadius = 5;

  /// Rayon du halo.
  static const Radius busyHaloRadius = Radius.circular(12);

  // ── Typographie (graisses et corps ; jamais un `TextStyle` complet) ──

  /// Graisse du titre d'un message en usage notebook.
  static const FontWeight messageTitleWeight = FontWeight.w600;

  /// Graisse d'un titre de section de la feuille d'outils.
  static const FontWeight sectionTitleWeight = FontWeight.bold;

  /// Corps d'un titre de section.
  static const double sectionTitleFontSize = 16;

  /// Corps du titre de la feuille d'outils.
  static const double sheetTitleFontSize = 18;

  // ── Couleurs — exception encadrée (cf. dartdoc de bibliothèque) ──────

  /// Teinte d'identité des affordances d'outils.
  ///
  /// Non dérivable : aucun rôle de `ColorScheme` ne garantit cette teinte
  /// contre le thème de l'hôte. Remplaçable par jeton
  /// `ZcrudTheme.chatToolAccentColor` et par paramètre
  /// `ZChatNotebookSkin.toolAccentColor`.
  ///
  /// Contraste mesuré à environ 2.1:1 sur une surface claire — sous le
  /// seuil WCAG de 3.0 pour un composant. Elle ne doit donc porter qu'une
  /// emphase, jamais un état : l'état d'un interrupteur reste porté par sa
  /// sémantique native (`selected`).
  static const Color toolAccentColor = Color(0xFFFF9800);

  /// Séquence des 7 teintes de l'indicateur d'occupation, en cycle.
  ///
  /// Non dérivable : aucun rôle ne porte une séquence. Remplaçable par jeton
  /// `ZcrudTheme.chatBusyPalette` et par paramètre
  /// `ZChatNotebookSkin.busyPalette`.
  ///
  /// Un cycle de couleurs est une animation : un hôte qui l'applique doit
  /// respecter « Réduire les animations » (invariant AD-13) et ne jamais y
  /// faire reposer l'information « occupé » — le canal d'annonce reste la
  /// région live.
  static const List<Color> busyPalette = <Color>[
    Color(0xFF2196F3), // Colors.blue
    Color(0xFFF44336), // Colors.red
    Color(0xFFFFEB3B), // Colors.yellow
    Color(0xFFFF9800), // Colors.orange
    Color(0xFF795548), // Colors.brown
    Color(0xFF009688), // Colors.teal
    Color(0xFF4CAF50), // Colors.green
  ];

  /// Code-couleur des capacités du notebook, jamais seul : chaque entrée
  /// porte aussi un canal textuel et un canal de forme
  /// ([ZChatNotebookCapabilityStyle]).
  ///
  /// Une clé inconnue rend `null` côté [ZChatNotebookSkin] : une capacité
  /// future n'a pas d'accent de référence, elle n'en fabrique pas un au
  /// hasard (invariant AD-10).
  static const Map<String, ZChatNotebookCapabilityStyle> capabilities =
      <String, ZChatNotebookCapabilityStyle>{
        kZChatCapabilityMindmap: ZChatNotebookCapabilityStyle(
          accent: Color(0xFFFF9800),
          generatedLabelKey: kZChatLabelGenerated,
          generatedMarkSize: generatedMarkSize,
        ),
        kZChatCapabilityFlashcards: ZChatNotebookCapabilityStyle(
          accent: Color(0xFF2196F3),
          generatedLabelKey: kZChatLabelGenerated,
          generatedMarkSize: generatedMarkSize,
        ),
        kZChatCapabilityStory: ZChatNotebookCapabilityStyle(
          accent: Color(0xFF009688),
          generatedLabelKey: kZChatLabelGenerated,
          generatedMarkSize: generatedMarkSize,
        ),
        kZChatCapabilityHumour: ZChatNotebookCapabilityStyle(
          accent: Color(0xFFFFEB3B),
          generatedLabelKey: kZChatLabelGenerated,
          generatedMarkSize: generatedMarkSize,
        ),
        kZChatCapabilityClassroom: ZChatNotebookCapabilityStyle(
          accent: Color(0xFF8BC34A),
          generatedLabelKey: kZChatLabelGenerated,
          generatedMarkSize: generatedMarkSize,
        ),
      };

  /// Diamètre de la pastille « déjà généré » — le canal de forme commun aux
  /// capacités. Aligné sur la pastille compteur de référence
  /// ([perMessageActionBadgeRadius] × 2 = 16).
  ///
  /// C'est une valeur de socle : rien d'équivalent n'existait avant, c'est
  /// précisément le défaut que ce canal comble.
  static const double generatedMarkSize = 16;
}
