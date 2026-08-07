/// **Lot γ (CR-IFFD-72)** — les valeurs de RENDU DE RÉFÉRENCE de la surface
/// Notebook, mesurées chez IFFD legacy et centralisées en UN SEUL endroit
/// (patron `ZStudyCardReference`/`ZFlashcardCardReference`, CR-IFFD-56/57).
///
/// ## 🔴 Le fait d'architecture qui commande ce fichier
///
/// La bulle de message du legacy **n'est pas du rendu maison** : elle délègue à
/// `SfAIAssistView` (`chatbot_conversation_screen.dart:3422`). Le « pixel près »
/// ne se joue donc PAS ici : le legacy ne fige, autour du widget tiers, que
/// `widthFactor: 0.95`, un rayon 12 sur la bulle de **requête**, et le masquage
/// avatar/nom. Tout le reste de la géométrie de bulle est le **défaut
/// Syncfusion**, non mesurable depuis le dépôt legacy.
///
/// Ce fichier est donc **deux choses distinctes**, et le dartdoc de chaque
/// constante le dit :
/// 1. les quelques valeurs que le **socle** résout et applique lui-même
///    (par [ZChatNotebookSkin], mappées sur `AssistMessageSettings` dans
///    `zcrud_chat_syncfusion`) ;
/// 2. le **catalogue** des valeurs que le legacy fige dans son chrome (composer,
///    feuille d'outils, badges, indicateur d'occupation) et qu'un hôte qui porte
///    ce chrome doit lire **ici** plutôt que les re-figer chez lui.
///
/// ## ⚠️ Exception FR-26 ENCADRÉE (arbitrage owner, 2026-08-04)
///
/// Ce fichier est le **SEUL** de `zcrud_chat` autorisé à porter des couleurs
/// littérales, aux trois conditions de l'arbitrage :
///
/// 1. **Centralisation** — toutes les valeurs vivent ici, dans l'unique fichier
///    de référence audité de la famille « notebook » ;
/// 2. **Remplaçabilité** — chaque couleur est remplaçable par **paramètre**
///    ([ZChatNotebookSkin]) ET par **jeton** (`ZcrudTheme.chatToolAccentColor`,
///    `ZcrudTheme.chatCapabilityAccents`, `ZcrudTheme.chatBusyPalette`),
///    priorité **paramètre > jeton > référence** ;
/// 3. **Exemption nominative** — la garde anti-couleurs
///    (`test/z_chat_purity_test.dart`) exempte CE fichier, **par nom exact**, et
///    uniquement de ses deux règles de COULEUR : les règles AD-13 (directionnel)
///    y restent appliquées, comme partout ailleurs. La garde de littéraux
///    (`test/z_chat_render_guard_test.dart`) l'exempte par le **même** mécanisme
///    nominatif que `z_chat_labels.dart`.
///
/// ## 🔴 Trois familles de couleurs portées, quatre REFUSÉES
///
/// Le relevé du volet B dénombrait sept familles « exigeant l'exception ». Le
/// critère de l'arbitrage est **« non dérivable d'un `ColorScheme` »** — quatre
/// d'entre elles ne le satisfont pas et ne sont donc **pas** portées :
///
/// | Famille legacy | Décision |
/// |---|---|
/// | dégradé de l'indicateur d'occupation (7 teintes) | **portée** ([busyPalette]) — aucune séquence de rôles n'existe |
/// | `Colors.orange` des interrupteurs/chevrons d'outils | **portée** ([toolAccentColor]) — teinte d'identité, pas un rôle |
/// | code-couleur par capacité (mindmap/flashcards/variantes) | **portée** ([capabilities]) — vocabulaire produit, jamais un rôle |
/// | `Colors.red` des badges compteurs (4+ sites) | **REFUSÉE** — c'est `ColorScheme.error`, dérivable |
/// | `Colors.lightBlue` de l'icône « joindre » active | **REFUSÉE** — c'est `ColorScheme.primary`, dérivable |
/// | repli `Colors.orange` de la bordure de focus | **REFUSÉE** — un repli doit être un RÔLE (le volet B le dit lui-même) |
/// | `Colors.grey` des sous-titres | **REFUSÉE** — c'est `ColorScheme.onSurfaceVariant` |
///
/// ## 🔴 Les défauts du legacy qui ne sont PAS reproduits
///
/// | Défaut mesuré | Ce que ce fichier fait |
/// |---|---|
/// | bouton d'envoi **40 dp** (`:3369-3372`) | [sendButtonSize] vaut **48** — la valeur legacy n'est pas même déclarée, pour qu'elle soit inexprimable |
/// | 5 sites non directionnels (`Positioned(right:)`, `BorderRadius.only(topLeft:)`) | toutes les marges sont `EdgeInsetsDirectional`, tous les décalages sont nommés `…TopInset`/`…EndInset` (AD-13) |
/// | information portée par la **seule couleur** (`:1720-1889`, `:3151-3159`) | [ZChatNotebookCapabilityStyle] exige, en plus de l'accent, **deux canaux non chromatiques** — ils sont `required`, donc une teinte seule est **inexprimable** |
/// | libellés français en dur | aucun libellé ici : [ZChatNotebookCapabilityStyle.generatedLabelKey] porte une **clé**, résolue par `zChatLabel` |
/// | `TextScaler.linear(1.1/1.15)` qui écrase l'échelle a11y de l'utilisateur (`:4243-4266`) | **non porté** — aucune constante d'échelle de texte ici |
/// | `contentBackgroundColor` / couleurs de suggestions | **non portés** : ils sont COMMENTÉS chez le legacy, donc inactifs (`:3581-3584`, `:1376-1388`) |
///
/// ## Thème sombre — le verdict, et ce qu'il impose
///
/// Les trois seules occurrences de `Brightness`/`isDark` de la vue legacy sont
/// **commentées** (`:1378`, `:1384`, `:3582`) : le legacy n'adapte **rien**.
///
/// Contraste WCAG 2.x **mesuré** (et re-calculé par
/// `test/z_chat_notebook_reference_test.dart`, qui rougit si une teinte d'ici
/// change sans que la mesure soit refaite) :
///
/// | teinte | sur surface CLAIRE `#FFFFFF` | sur surface SOMBRE `#121212` |
/// |---|---|---|
/// | mindmap / outils `#FF9800` | **2.16** ❌ | 8.69 ✅ |
/// | flashcards `#2196F3` | 3.12 ✅ | 6.00 ✅ |
/// | histoire `#009688` | 3.67 ✅ | 5.10 ✅ |
/// | humour `#FFEB3B` | **1.22** ❌❌ | 15.34 ✅ |
/// | classe `#8BC34A` | **2.10** ❌ | 8.92 ✅ |
/// | occupation `#F44336` (rouge) | 3.68 ✅ | 5.09 ✅ |
/// | occupation `#4CAF50` (vert) | **2.78** ❌ | 6.74 ✅ |
/// | occupation `#795548` (brun) | 6.55 ✅ | **2.86** ❌ |
///
/// **Verdict** : sur les **8 teintes distinctes** portées ici, **5 échouent** au
/// seuil WCAG 3.0 dans au moins une des deux luminosités — et le problème est
/// majoritairement en thème **CLAIR** (4 échecs), pas en sombre (1, le brun).
/// C'est l'inverse de l'intuition, et c'est la raison pour laquelle le legacy,
/// qui n'adapte rien, était déjà fautif sur son propre thème par défaut.
/// La correction retenue **n'est pas** de les recolorer
/// (ce serait renoncer au « pixel près » sur le seul axe où il est demandé) :
/// c'est de garantir qu'**aucune information ne repose sur elles**, ce que le
/// type [ZChatNotebookCapabilityStyle] rend **structurel** en exigeant deux
/// canaux non chromatiques. Un hôte qui veut, lui, une teinte conforme la pose
/// par jeton ou par paramètre — la chaîne est faite pour cela.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_labels.dart';

/// Style de RÉFÉRENCE d'une **capacité** du notebook (carte mentale,
/// flashcards, variantes de transformation).
///
/// 🔴 **La teinte n'existe jamais seule.** Chez IFFD, la présence d'un contenu
/// déjà généré se signale par le **seul** changement de couleur d'une icône
/// (`chatbot_conversation_screen.dart:1720-1889`) : un utilisateur daltonien —
/// ou un utilisateur d'un thème qui écrase la teinte — perd le signal. Les
/// deux canaux non chromatiques sont donc `required` : le type rend le défaut
/// **inexprimable**, au lieu de le déconseiller.
@immutable
class ZChatNotebookCapabilityStyle {
  /// Construit un style de capacité — les trois canaux sont obligatoires.
  const ZChatNotebookCapabilityStyle({
    required this.accent,
    required this.generatedLabelKey,
    required this.generatedMarkSize,
  });

  /// Canal **chromatique** — décoratif, jamais porteur d'information seul.
  ///
  /// Remplaçable par jeton (`ZcrudTheme.chatCapabilityAccents`) et par
  /// paramètre (`ZChatNotebookSkin.capabilityAccents`).
  final Color accent;

  /// Canal **textuel** — la clé de libellé annoncée quand la capacité a déjà
  /// produit un contenu. C'est une **clé**, jamais un libellé : elle traverse
  /// `zChatLabel` (registre de l'hôte → traduction → repli lisible).
  ///
  /// 🔴 **Non remplaçable par thème** — un jeton qui pourrait l'effacer
  /// rouvrirait la porte au « colour only ».
  final String generatedLabelKey;

  /// Canal de **forme** — diamètre de la pastille visible qui marque l'état
  /// « déjà généré ». Une forme se voit sans distinguer les teintes.
  ///
  /// 🔴 **Non remplaçable par thème**, même raison.
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

/// Clé de capacité « carte mentale » (legacy : icône teintée orange, `:1727`).
const String kZChatCapabilityMindmap = 'mindmap';

/// Clé de capacité « flashcards » (legacy : icône teintée bleu, `:1803`).
const String kZChatCapabilityFlashcards = 'flashcards';

/// Clé de variante « histoire fantastique » (legacy `:1333`, teinte `teal`).
const String kZChatCapabilityStory = 'story';

/// Clé de variante « humour » (legacy `:1342`, teinte `yellow`).
const String kZChatCapabilityHumour = 'humour';

/// Clé de variante « chat / salle de classe » (legacy `:1351`, teinte
/// `lightGreen`).
const String kZChatCapabilityClassroom = 'classroom';

/// Les valeurs de RÉFÉRENCE du rendu Notebook — le point d'audit **unique**.
///
/// Modifier une valeur ici change le défaut du skin partout ; ajouter une
/// couleur ici, et nulle part ailleurs, reste dans le cadre de l'exception
/// FR-26 encadrée (cf. le dartdoc de bibliothèque).
abstract final class ZChatNotebookReference {
  // ── Bulle de message — les SEULES valeurs que le legacy fige autour de
  //    `SfAIAssistView` (`chatbot_conversation_screen.dart:3568-3594`) ────────

  /// Fraction de largeur d'une bulle en usage **notebook** : `0.95`
  /// (`chatbot_conversation_screen.dart:3570,3587` — `isChatSession ? 1 : 0.95`,
  /// posé sur la requête ET sur la réponse).
  static const double bubbleWidthFactor = 0.95;

  /// Fraction de largeur d'une bulle en usage **conversation** : `1`
  /// (même ligne legacy). Portée pour que le contraste des deux usages soit
  /// lisible ici, à l'endroit où l'arbitrage se fait.
  static const double conversationBubbleWidthFactor = 1;

  /// Rayon de la bulle de **requête** : 12
  /// (`chatbot_conversation_screen.dart:3577-3579`).
  static const Radius requestBubbleRadius = Radius.circular(12);

  /// 🔴 **La bulle de RÉPONSE n'a AUCUN rayon de référence.** Le legacy ne pose
  /// `shape:` que sur `requestMessageSettings` ; `responseMessageSettings`
  /// (`:3586-3594`) n'en porte pas, et hérite donc du défaut Syncfusion. En
  /// inventer un ici serait une valeur que personne n'a mesurée — le skin laisse
  /// donc `responseBubbleRadius` à `null`, et c'est intentionnel.
  static const Radius? responseBubbleRadius = null;

  /// Avatar d'auteur affiché ? **Non** en notebook
  /// (`:3574` `showAuthorAvatar: isChatSession` ⇒ `false` ; `:3588` `false`
  /// inconditionnellement sur la réponse).
  static const bool showAuthorAvatar = false;

  /// Nom d'auteur affiché ? **Non** en notebook
  /// (`:3576,3593` `showAuthorName: isChatSession`).
  static const bool showAuthorName = false;

  /// Horodatage affiché ? **Oui** hors lecture seule
  /// (`:3575,3592` `showTimestamp: !readOnly`).
  static const bool showTimestamp = true;

  /// Motif d'horodatage du legacy (`:3571-3573,3589-3591`).
  ///
  /// ⚠️ **Le socle ne l'applique PAS.** C'est un format EU figé, insensible à la
  /// locale : l'imposer à tout hôte reproduirait le défaut « libellé en dur »
  /// une couche plus bas. La valeur est publiée pour l'hôte qui veut la parité
  /// stricte (`DateFormat(ZChatNotebookReference.timestampFormatPattern)`) ; à
  /// défaut, le format reste celui du backend de coquille, qui suit la locale.
  static const String timestampFormatPattern = 'dd/MM/yyyy HH:mm:ss';

  // ── Composer (`:2528-2622`, `:3355-3406`) ─────────────────────────────────

  /// Marge du conteneur de saisie (`:2530-2532`, `EdgeInsets.symmetric(
  /// horizontal: 8)` — rendue **directionnelle**, AD-13).
  static const EdgeInsetsDirectional composerPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8);

  /// Rayon du conteneur de saisie et du champ (`:2541`, `:2601`).
  static const Radius composerRadius = Radius.circular(12);

  /// Nombre minimal de lignes du champ (`:2594`).
  static const int composerMinLines = 1;

  /// Nombre maximal de lignes du champ (`:2593`).
  static const int composerMaxLines = 5;

  /// Espacement de la rangée d'affordances sous le champ (`:2620-2622`).
  static const double composerActionRowSpacing = 5;

  /// Opacité du filet qui sépare le champ de sa rangée d'affordances
  /// (`:2609-2615` — `dividerColor.withValues(alpha: .1)` ; la COULEUR reste un
  /// rôle, seule l'opacité est une valeur de référence).
  ///
  /// ## 🔴 CR-IFFD-77 ③ — pourquoi elle n'a PAS de consommateur, et ne doit
  /// pas en avoir dans la famille « composer »
  ///
  /// IFFD relève (à raison) qu'un `grep` sur les 38 paquets ne trouve que cette
  /// déclaration. Ce n'est pas un oubli, c'est la **garde REF-G7** :
  /// *aucun fichier de `lib/` hors ce fichier et `ZChatNotebookSkin` ne peut
  /// citer la référence notebook* — sans quoi tout hôte passif hériterait du
  /// rendu du monolithe IFFD sans l'avoir demandé. La tentative de la câbler
  /// dans `ZDefaultChatComposer` a été **écrite puis retirée** : la garde l'a
  /// rougie, et elle avait raison.
  ///
  /// Deux raisons de fond s'y ajoutent :
  /// * **partition des familles** — cette valeur est une mesure du *notebook*
  ///   IFFD ; la famille composer a son propre point d'audit
  ///   (`ZChatComposerReference`). Une consommation croisée est exactement ce
  ///   que la partition en deux fichiers de référence interdit ;
  /// * **lex n'a pas ce filet** — la référence du mode Chat (décision du
  ///   2026-08-05) peint une **bordure de conteneur**
  ///   (`Border.all(color: dividerColor)`), pas une règle interne. Le canal de
  ///   bordure demandé par CR-IFFD-77 ③ est donc `ZChatComposerSurface.
  ///   borderColor` + `ZChatComposerReference.borderWidth`, et il n'a rien à
  ///   voir avec cette opacité.
  ///
  /// ⇒ Son unique consommateur légitime serait un champ de [ZChatNotebookSkin]
  /// rendu par la vue notebook — un lot de la famille notebook, pas du
  /// composer. Tant qu'il n'existe pas, elle reste ce qu'elle est : une mesure
  /// **publiée et auditable**, que l'hôte qui veut ce filet peut lire et
  /// appliquer lui-même.
  static const double composerHelperDividerAlpha = 0.1;

  /// 🔴 Côté du bouton d'envoi : **48**, et non les **40 dp** du legacy
  /// (`:3369-3372`, `SizedBox(width: 40, height: 40)`).
  ///
  /// La valeur legacy n'est **pas déclarée** : un hôte ne peut pas la lire ici,
  /// donc il ne peut pas la reproduire par inadvertance. C'est le plancher
  /// AD-13, le même que `kZChatMinTapTarget`, et
  /// `test/z_chat_notebook_reference_test.dart` asserte l'égalité des deux —
  /// deux planchers qui divergeraient seraient pires qu'un seul.
  static const double sendButtonSize = 48;

  /// Échelle du bouton d'envoi quand la saisie est **vide** (`:3364-3365`).
  static const double sendButtonScaleIdle = 0.7;

  /// Échelle du bouton d'envoi quand la saisie est **non vide** (`:3362-3363`).
  static const double sendButtonScaleActive = 1;

  /// Durée de la transition d'échelle du bouton d'envoi (`:3366-3368`).
  static const Duration sendButtonScaleDuration = Duration(milliseconds: 150);

  /// Rayon des puces de réglage (« Réfléchir », résumé) — `:2807-2812`,
  /// `:2979-2982`.
  static const Radius chipRadius = Radius.circular(12);

  /// Marge d'un badge compteur (`:2828-2833`, `:2934-2939` —
  /// `EdgeInsets.symmetric(horizontal: 4, vertical: 0)`, rendue directionnelle).
  static const EdgeInsetsDirectional counterBadgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4);

  /// Rayon d'un badge compteur (`:2839-2841`, `:2943-2946`).
  static const Radius counterBadgeRadius = Radius.circular(8);

  /// Rayon de la pastille compteur de l'icône « joindre » (`:2763`,
  /// `CircleAvatar(radius: 8)`).
  static const double attachBadgeRadius = 8;

  /// Décalage HAUT de la pastille « joindre » (`:2759-2761`, `top: 0`).
  static const double attachBadgeTopInset = 0;

  /// Décalage de FIN de la pastille « joindre » (`:2759-2761`, `right: 0`).
  ///
  /// 🔴 Nommé `End`, pas `Right` : le legacy pose un `Positioned(right:)`, l'un
  /// des cinq sites non directionnels du relevé. Un hôte qui lit cette constante
  /// est conduit vers `PositionedDirectional(end:)` (AD-13).
  static const double attachBadgeEndInset = 0;

  // ── Actions par message (`:1359`, `:1735-1754`, `:1811-1831`) ─────────────

  /// Côté d'une icône d'action par message (`:1359`, `toolbarItemSize = 24.0`).
  ///
  /// ⚠️ C'est la taille du **glyphe**, jamais celle de la cible tactile : celle
  /// -ci reste `kZChatMinTapTarget`.
  static const double perMessageActionIconSize = 24;

  /// Rayon de la pastille compteur d'une action par message (`:1739`, `:1815`).
  static const double perMessageActionBadgeRadius = 8;

  /// Corps du compteur d'une action par message (`:1747`, `:1824`).
  static const double perMessageActionBadgeFontSize = 10;

  /// Décalage HAUT de la pastille compteur (`:1735-1737`, `top: 5`).
  static const double perMessageActionBadgeTopInset = 5;

  /// Décalage de FIN de la pastille compteur (`:1735-1737`, `right: 5` —
  /// directionnalisé, AD-13).
  static const double perMessageActionBadgeEndInset = 5;

  // ── Feuille d'outils (`:4551-4552`, `:4890-4899`, `:4931`, `:5132`) ───────

  /// Marge du corps de la feuille d'outils (`:4551-4552`).
  static const EdgeInsetsDirectional toolsSheetPadding =
      EdgeInsetsDirectional.all(4);

  /// Espacement courant entre sections de la feuille (`:4599`, `:4629`, `:4634`,
  /// `:4723`, `:4783`, `:4898`).
  static const double toolsSheetSectionGap = 10;

  /// Espacement APPUYÉ avant une famille de sections (`:4718`).
  static const double toolsSheetSectionGapLarge = 20;

  /// Côté du glyphe d'en-tête de la feuille (`:4895`).
  static const double toolsSheetHeaderIconSize = 30;

  /// Marge d'une tuile d'outil (`:4931`, `:5132`).
  static const EdgeInsetsDirectional toolTilePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8);

  // ── Contenu replié d'un message (`:4133-4151`) ────────────────────────────

  /// Hauteur minimale d'un contenu replié (`:4143`).
  static const double collapsedContentMinHeight = 100;

  /// Hauteur maximale ABSOLUE d'un contenu replié (`:4144-4150`).
  static const double collapsedContentMaxHeight = 250;

  /// Fraction de hauteur d'écran bornant un contenu replié (`:4144-4150` —
  /// `min(250, écran × 0.3)`).
  static const double collapsedContentMaxHeightFactor = 0.3;

  /// Durée du dépli/repli (`:4133-4135`).
  static const Duration collapsedContentDuration = Duration(milliseconds: 300);

  // ── Indicateur d'occupation (`loading_indicators.dart:44-100`) ────────────

  /// Durée d'un tour complet du cycle (`loading_indicators.dart:78-79`).
  static const Duration busyCycleDuration = Duration(seconds: 2);

  /// Durée d'un segment du cycle (`loading_indicators.dart:59-75` — 7 × 300 ms).
  static const Duration busySegmentDuration = Duration(milliseconds: 300);

  /// Flou du halo (`loading_indicators.dart:91-93`).
  static const double busyHaloBlurRadius = 5;

  /// Rayon du halo (`loading_indicators.dart:94`).
  static const Radius busyHaloRadius = Radius.circular(12);

  // ── Typographie (graisses et corps ; jamais un `TextStyle` complet) ───────

  /// Graisse du titre d'un message en usage notebook (`:3868-3871`,
  /// `FontWeight.w600`).
  static const FontWeight messageTitleWeight = FontWeight.w600;

  /// Graisse d'un titre de section de la feuille d'outils (`:4630-4633`).
  static const FontWeight sectionTitleWeight = FontWeight.bold;

  /// Corps d'un titre de section (`:4630-4633`, `fontSize: 16`).
  static const double sectionTitleFontSize = 16;

  /// Corps du titre de la feuille d'outils (`:4890-4894`, `fontSize: 18`).
  static const double sheetTitleFontSize = 18;

  // ── COULEURS — exception FR-26 encadrée (cf. dartdoc de bibliothèque) ─────

  /// Teinte d'identité des affordances d'outils : `Colors.orange` `#FF9800`
  /// (`chatbot_conversation_screen.dart:4942` interrupteur, `:5137` chevron).
  ///
  /// Non dérivable : aucun rôle de `ColorScheme` ne garantit cette teinte contre
  /// le thème de l'hôte. Remplaçable par jeton `ZcrudTheme.chatToolAccentColor`
  /// et par paramètre `ZChatNotebookSkin.toolAccentColor`.
  ///
  /// ⚠️ **Contraste mesuré ≈ 2.1:1 sur une surface claire** — sous le seuil WCAG
  /// de 3.0 pour un composant. Elle ne doit donc porter qu'une **emphase**,
  /// jamais un état : l'état d'un interrupteur reste porté par sa sémantique
  /// native (`selected`).
  static const Color toolAccentColor = Color(0xFFFF9800);

  /// Séquence des 7 teintes de l'indicateur d'occupation
  /// (`loading_indicators.dart:59-75` : `blue → red → yellow → orange → brown →
  /// teal → green`, puis retour au bleu).
  ///
  /// Non dérivable : aucun rôle ne porte une **séquence**. Remplaçable par jeton
  /// `ZcrudTheme.chatBusyPalette` et par paramètre
  /// `ZChatNotebookSkin.busyPalette`.
  ///
  /// ⚠️ Un cycle de couleurs est une **animation** : un hôte qui l'applique doit
  /// respecter « Réduire les animations » (AD-13) et ne jamais y faire reposer
  /// l'information « occupé » — le canal d'annonce reste la région live.
  static const List<Color> busyPalette = <Color>[
    Color(0xFF2196F3), // Colors.blue
    Color(0xFFF44336), // Colors.red
    Color(0xFFFFEB3B), // Colors.yellow
    Color(0xFFFF9800), // Colors.orange
    Color(0xFF795548), // Colors.brown
    Color(0xFF009688), // Colors.teal
    Color(0xFF4CAF50), // Colors.green
  ];

  /// Code-couleur des capacités du notebook, **jamais seul** : chaque entrée
  /// porte aussi un canal textuel et un canal de forme
  /// ([ZChatNotebookCapabilityStyle]).
  ///
  /// Teintes legacy : `:1727` mindmap `orange`, `:1803` flashcards `blue`,
  /// `:1333` histoire `teal`, `:1342` humour `yellow`, `:1351` chat
  /// `lightGreen`.
  ///
  /// Une clé inconnue rend `null` côté [ZChatNotebookSkin] : une capacité future
  /// n'a pas d'accent de référence, elle n'en fabrique pas un au hasard (AD-10).
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

  /// Diamètre de la pastille « déjà généré » — le canal de **forme** commun aux
  /// capacités. Aligné sur la pastille compteur du legacy
  /// ([perMessageActionBadgeRadius] × 2 = 16).
  ///
  /// 🔴 Ce n'est PAS une valeur du legacy : le legacy ne dessine **rien** pour
  /// cet état, c'est précisément le défaut. C'est une valeur de socle.
  static const double generatedMarkSize = 16;
}
