/// Le RENDU DE RÉFÉRENCE du hub d'ajout de contenu, centralisé en UN SEUL
/// endroit (même patron que [ZStudyCardReference], `ZFlashcardCardReference`,
/// `ZFolderCardReference`).
///
/// ## Ce que ce fichier fige, et sur DÉCISION DU PROPRIÉTAIRE
///
/// `ZContentHubSheet` pouvait rendre une liste plate de `ListTile` nus : aucun
/// groupement, aucune identité par entrée, aucune mise en avant, aucune forme
/// réglable. Le propriétaire du socle a arbitré que le rendu de référence
/// (portage annoté d'un design éprouvé) devienne le **DÉFAUT**, hauteur
/// d'item de référence **assumée** et **défilement attendu**.
///
/// L'argument d'ÉCHELLE (douze types ⇒ trois ou quatre écrans) est répondu par
/// le RÉGLAGE — [ZContentHubDensity.compact], atteignable par paramètre ET
/// par jeton, restitue une densité plus compacte.
///
/// ## Exception FR-26 ENCADRÉE
///
/// L'exception vaut **par famille**. Ce fichier est l'un des rares du package
/// autorisés à porter des couleurs littérales — les **six teintes
/// d'identité** de la référence (hex vérifiés dans `colors.dart` du SDK) et
/// le vert du badge de mise en avant. Aucune n'est dérivable d'un rôle
/// `ColorScheme` : ce sont des teintes **arbitraires par type de contenu**,
/// exactement comme les quatre dégradés de `ZFlashcardCardReference`. Les
/// trois conditions :
///
/// 1. **Centralisation** : elles vivent ICI et nulle part ailleurs — aucun
///    widget du package n'écrit d'hex ;
/// 2. **Remplaçabilité** : par **paramètre** (`ZContentHubEntry.tint`,
///    `ZContentHubSheet.accents`, `ZContentHubSheet.badgeColor`) ET par
///    **jeton** (`ZcrudTheme.contentHubAccents`,
///    `ZcrudTheme.contentHubBadgeColor`) — priorité **paramètre > jeton >
///    référence** ;
/// 3. **Exemption nominative** : la garde de source anti-couleurs
///    (`z_widgets_hardcode_scan_test.dart`) exempte CE fichier par chemin
///    EXACT, et lui seul — jamais un motif large.
///
/// Toute couleur **dérivable** reste un RÔLE : liseré `outlineVariant`, chevron
/// `onSurfaceVariant`, fond de carte `CardTheme`/`surface` — aucun hex ici pour
/// elles.
///
/// ## Le contraste — mesuré, jamais reproduit à l'aveugle
///
/// **MESURÉ, le thème sombre en particulier** : une adaptation naïve
/// n'adapterait **RIEN** en sombre — les six teintes et l'alpha `0.1` de la
/// pastille resteraient des constantes appliquées à l'identique dans les
/// deux luminosités, donc le contraste réel du glyphe dépendrait d'un fond
/// que personne n'aurait mesuré. Le socle **évite ce défaut** : toute teinte
/// peinte passe par `zReadableTintOn` avec le plancher
/// [ZContentHubReference.minContrast], mesuré contre la surface **réellement
/// peinte**.
///
/// ## Ce que ce fichier ne contient PAS, et pourquoi
///
/// * **La hauteur de feuille (480 lp)** : elle est posée par l'HÔTE
///   (`showPushedDialog(maxHeight: 480)`), pas par le hub — ce sont des
///   enveloppes, pas des capacités du hub.
/// * **Les libellés** (« Flashcards », « Recommandé », les six titres) : ils
///   sont **INJECTÉS**. Un défaut de constructeur `badgeLabel = 'Recommandé'`
///   déclencherait la règle « défaut de constructeur en dur » de la garde —
///   ici tout libellé est requis ou nullable **sans** défaut littéral.
library;

import 'package:flutter/material.dart';

/// Les valeurs de RÉFÉRENCE du hub d'ajout de contenu, le point d'audit
/// unique. Modifier une valeur ici change le défaut du hub partout.
abstract final class ZContentHubReference {
  // ── Clés de couleur STABLES — le SEUL vocabulaire ajouté ──────────────────

  /// Les clés d'identité **stables** des familles de contenu courantes, à passer
  /// à `ZContentHubEntry.colorKey`.
  ///
  /// **Ce ne sont PAS des libellés** — ni rendus, ni traduits, ni affichés.
  /// Ce sont des **identités opaques** dont la seule fonction est de fixer le
  /// créneau de teinte d'une entrée (`zAccentSlot`). C'est ce qui rend la teinte
  /// STABLE quand une application **insère un type au milieu** de sa liste,
  /// et **d'une langue à l'autre** — le repli par libellé, lui, change de
  /// créneau dès que le libellé change.
  ///
  /// **Aucune table type → teinte n'est introduite ici** : le socle ne
  /// connaît toujours aucun « type de contenu » (cf. [accents], « c'est une
  /// PALETTE, pas une table par type »). Ces constantes ne font que **nommer**
  /// des identités, pour que deux écrans d'une même application n'inventent pas
  /// deux orthographes de la même chose et ne se retrouvent pas avec deux
  /// teintes pour un même type.
  ///
  /// Une application libre d'en utiliser d'autres : `colorKey` reste un `String`
  /// opaque quelconque.
  static const String colorKeyFlashcards = 'flashcards';

  /// Clé d'identité stable de la famille « note » — cf. [colorKeyFlashcards].
  static const String colorKeyNote = 'note';

  /// Clé d'identité stable de la famille « document » — cf. [colorKeyFlashcards].
  static const String colorKeyDocument = 'document';

  /// Clé d'identité stable de la famille « carte mentale » — cf.
  /// [colorKeyFlashcards].
  static const String colorKeyMindmap = 'mindmap';

  /// Clé d'identité stable de la famille « examen » — cf. [colorKeyFlashcards].
  static const String colorKeyExam = 'exam';

  /// Clé d'identité stable de la famille « podcast » — cf. [colorKeyFlashcards].
  static const String colorKeyPodcast = 'podcast';

  /// Les six clés ci-dessus, dans un ordre **stable et déclaré** (support de
  /// garde : une clé ajoutée sans être recensée fait rougir).
  ///
  /// L'ordre de cette liste n'a **aucun** effet sur les teintes : le créneau
  /// est une fonction de l'identité, jamais de la position (`zAccentSlot`).
  static const List<String> colorKeys = <String>[
    colorKeyFlashcards,
    colorKeyNote,
    colorKeyDocument,
    colorKeyMindmap,
    colorKeyExam,
    colorKeyPodcast,
  ];

  // ── Teintes d'identité (exception FR-26 encadrée — cf. dartdoc de tête) ────

  /// Les **six teintes d'identité** de la référence legacy, dans l'ordre de
  /// rendu du legacy : IA (`purple`), création manuelle (`blue`), téléversement
  /// (`orange`), numérisation (`teal`), note (`green`), carte mentale
  /// (**`deepPurple`**).
  ///
  /// **La sixième n'est PAS l'indigo annoncé par la CR.** Le legacy pose
  /// `iconColor: Colors.deepPurple` (`folder_content_add_dialog_widget.dart:337`),
  /// soit `0xFF673AB7` — et non `Colors.indigo` (`0xFF3F51B5`), qui n'apparaît
  /// **nulle part** dans le fichier legacy (recherche négative exécutée). La CR
  /// (§ ② et sa vérification par défilement § ⑤) confond deux teintes Material
  /// distinctes.
  ///
  /// **C'est une PALETTE, pas une table par type.** Le socle ne connaît
  /// aucun « type de contenu » : une entrée reçoit sa teinte par
  /// `ZContentHubEntry.tint` (injectée), ou à défaut par un créneau
  /// **déterministe de son identité** (`colorKey`, à défaut son libellé) — donc
  /// **stable quand une application insère un type au milieu** (« non mesuré »
  /// n°4 de la CR, mesuré par garde). Jamais par sa POSITION.
  static const List<Color> accents = <Color>[
    Color(0xFF9C27B0), // purple    — « Générer des flashcards avec l'IA »
    Color(0xFF2196F3), // blue      — « Créer des flashcards manuellement »
    Color(0xFFFF9800), // orange    — « Upload un fichier »
    Color(0xFF009688), // teal      — « Scanner un document »
    Color(0xFF4CAF50), // green     — « Créer une note »
    Color(0xFF673AB7), // deepPurple— « Créer une carte mentale »
  ];

  /// Teinte du badge de MISE EN AVANT (legacy `Colors.green.shade700`, soit
  /// `0xFF388E3C` — le fond est cette famille à [badgeTintAlpha]).
  ///
  /// Le legacy peint `Colors.green` pour le fond et `Colors.green.shade700`
  /// pour le texte ; le socle part de la **même** teinte et laisse
  /// `zReadableTintOn` porter le premier plan au plancher du TEXTE
  /// ([textMinContrast]) contre le fond réellement composé — ce que le legacy
  /// ne fait pas.
  static const Color badgeAccent = Color(0xFF388E3C);

  // ── Carte d'entrée (dimensions et scalaires — jamais des couleurs) ─────────

  /// Hauteur d'item de RÉFÉRENCE (**112** — `kToolbarHeight × 2`, l'aspect
  /// ratio du legacy `_buildContentGrid` l.380 : `cardWidth / (kToolbarHeight *
  /// 2)` rend une hauteur de **112 quelle que soit la largeur**).
  ///
  /// C'est la « hauteur d'item de référence assumée » de la décision du
  /// propriétaire. Le plancher AD-13 de **48 dp** ([minTapTarget]) reste, mais
  /// il n'est plus la hauteur CIBLE — il redevient ce qu'il est : un plancher.
  static const double itemExtent = kToolbarHeight * 2;

  /// Cible de taille interactive minimale (invariant AD-13) — **plancher**,
  /// jamais une hauteur cible.
  static const double minTapTarget = 48;

  /// Rayon de la carte d'entrée (**16** — legacy l.418).
  static const Radius itemRadius = Radius.circular(16);

  /// Padding interne de la carte d'entrée (**8**, directionnel — AD-13 ;
  /// legacy `EdgeInsets.all(8)` l.428).
  static const EdgeInsetsGeometry itemPadding = EdgeInsetsDirectional.all(8);

  /// Épaisseur du liseré de la carte (**1** ; couleur = rôle `outlineVariant`,
  /// jamais un hex — legacy l.419-422).
  static const double borderWidth = 1;

  /// Élévation de la carte (**0** — legacy l.416).
  static const double elevation = 0;

  /// Opacité de la teinte de FOND de la carte d'entrée (**0** — carte
  /// NEUTRE).
  ///
  /// **MESURÉ, et il INFIRME la formulation « entrées en cartes (fond
  /// teinté) »** de la décision-cadre : le legacy pose un `Card(elevation: 0,
  /// shape: … side: outlineVariant)` **sans aucune couleur de fond** — le fond
  /// est celui du `CardTheme` ambiant. Ce qui est teinté, c'est la **pastille**
  /// ([avatarTintAlpha]) et le **badge** ([badgeTintAlpha]), pas la carte. Le
  /// jeton existe pour que le fond teinté reste **atteignable**, il n'est pas
  /// le défaut.
  static const double itemTintAlpha = 0;

  // ── Pastille circulaire d'identité ────────────────────────────────────────

  /// Diamètre de la pastille (**40** — legacy : `EdgeInsets.all(8)` autour d'un
  /// glyphe de 24, soit 8 + 24 + 8).
  ///
  /// **AD-13** : la pastille est sous les 48 dp de la cible tactile, et ce
  /// n'est **pas** un défaut — dans le legacy comme ici, elle n'est **jamais**
  /// une cible tactile indépendante : toute la carte est un **seul** `InkWell`.
  static const double avatarSize = 40;

  /// Opacité du fond de la pastille (**0.1** — legacy l.438).
  static const double avatarTintAlpha = 0.1;

  /// Taille du glyphe dans la pastille (**24** — legacy l.444).
  static const double glyphSize = 24;

  // ── Chevron d'affordance ──────────────────────────────────────────────────

  /// Glyphe du chevron (`arrow_forward_ios` — legacy l.469).
  ///
  /// **MESURÉ, et il INFIRME le grief RTL** porté contre le legacy : `Icon`
  /// **n'a pas** de propriété `matchTextDirection` (elle vit sur `IconData`), et
  /// `Icons.arrow_forward_ios` la porte **déjà à `true`** dans le SDK
  /// (`icons.dart:2510-2514`). Le chevron legacy **se retourne donc bien** en
  /// RTL. Le socle ne s'en remet pas au glyphe pour autant : il **force**
  /// `matchTextDirection` sur le chevron RÉELLEMENT rendu, y compris quand un
  /// hôte en injecte un autre (garde dédiée).
  static const IconData chevronGlyph = Icons.arrow_forward_ios;

  /// Taille du chevron (**16** — legacy l.470 ; couleur = rôle
  /// `onSurfaceVariant`).
  static const double chevronSize = 16;

  // ── Badge de mise en avant ────────────────────────────────────────────────

  /// Padding du badge (**8 / 4**, directionnel — legacy l.449-452).
  static const EdgeInsetsGeometry badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4);

  /// Rayon du badge (**8** — legacy l.455).
  static const Radius badgeRadius = Radius.circular(8);

  /// Opacité du fond du badge (**0.1** — legacy l.454).
  static const double badgeTintAlpha = 0.1;

  /// Graisse du libellé de badge (`w600` — legacy l.461).
  static const FontWeight badgeFontWeight = FontWeight.w600;

  // ── Typographie ───────────────────────────────────────────────────────────

  /// Graisse du libellé d'entrée (`w600` — legacy l.479). La TAILLE reste celle
  /// de `bodyMedium` du thème de l'hôte : aucune valeur de fonte en dur (a11y).
  static const FontWeight labelFontWeight = FontWeight.w600;

  /// Graisse d'un intitulé de section (`w600` — legacy l.142-144). La taille
  /// reste celle de `titleMedium`.
  static const FontWeight sectionTitleFontWeight = FontWeight.w600;

  // ── Espacements ───────────────────────────────────────────────────────────

  /// Écart pastille → libellé (**8** — legacy `EdgeInsets.only(left: 8)`
  /// l.475, **converti en directionnel** : reproduit tel quel, il ferait rougir
  /// la garde AD-13 du package, et casserait l'UI en arabe).
  static const double labelGap = 8;

  /// Padding de la zone défilante (**horizontal 8** — legacy l.129) combiné au
  /// padding de grille (**vertical 4 / horizontal 8** — legacy l.383).
  static const EdgeInsetsGeometry listPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4);

  /// Écart au-dessus d'un intitulé de section (**8** — legacy l.138-139).
  static const double sectionTitleGap = 8;

  /// Écart ENTRE deux cartes, sur les deux axes (**8 / 8** — legacy
  /// l.386-387).
  static const double itemSpacing = 8;

  // ── Grille (le cas que la CR déclarait « non mesuré ») ─────────────────────

  /// Largeur à partir de laquelle le legacy passe à **deux** colonnes
  /// (**600** — legacy l.376 : `isSmallScreen = constraints.maxWidth < 600`).
  ///
  /// **MESURÉ, contre un « non mesuré » de la CR.** La CR a retiré l'écart
  /// de grille en le déclarant non comparé en large. Le code legacy, lui,
  /// impose **sans ambiguïté** `crossAxisCount = 2` au-delà de 600 lp
  /// (l.377) — jamais une colonne unique. Reproduire le legacy intégralement
  /// l'inclut.
  static const double gridBreakpoint = 600;

  /// Nombre de colonnes au-delà de [gridBreakpoint] (**2** — legacy l.377).
  static const int gridCrossAxisCount = 2;

  // ── Contraste (les seuls scalaires qui ne viennent PAS du legacy) ──────────

  /// Plancher de contraste des SURFACES et COMPOSANTS graphiques — pastille,
  /// glyphe (**3.0:1**, WCAG 2.2 §1.4.11).
  ///
  /// **Ce n'est PAS une valeur du legacy** : le legacy peint la teinte
  /// BRUTE, sans aucune mesure et sans branche de luminosité. C'est une valeur
  /// de socle — une teinte d'entrée peut être **injectée par l'hôte**, donc
  /// arbitraire.
  static const double minContrast = 3;

  /// Plancher de contraste des premiers plans TEXTE — libellé de badge
  /// (**4.5:1**, WCAG 2.2 §1.4.3 AA).
  static const double textMinContrast = 4.5;
}
