/// `ZDefaultFlashcardCard` — carte de flashcard par défaut de ce paquet :
/// ligne d'en-tête tuile et balises, énoncé riche borné en dessous pleine
/// largeur, aperçu de réponse selon le mode, tampon vrai/faux, liseré teinté
/// par type.
///
/// ## Le besoin, et la forme qu'il ne pouvait pas prendre
///
/// L'`itemBuilder` d'une section d'outils d'étude est requis : chaque
/// application d'étude réécrirait donc la même carte de flashcard sans ce
/// widget.
///
/// Rendre cet `itemBuilder` facultatif avec un rendu par défaut ne peut pas
/// fonctionner, et c'est vérifiable sur le descripteur de section
/// lui-même : il porte `itemCount` et `itemBuilder(context, index)` et
/// aucune donnée. Sans `itemBuilder`, ce paquet ne sait pas ce qu'est l'item
/// numéro *i* : il ne pourrait rendre rien du tout. Le défaut n'est pas un
/// manque de volonté, c'est une absence d'information.
///
/// Deux éléments remplacent donc cette forme, et suppriment réellement le
/// travail répété :
/// 1. ce widget — autonome, instanciable dans l'`itemBuilder` de l'hôte ;
/// 2. `ZStudyToolsSectionSpec.flashcards(cards: …)` — la voie typée qui
///    porte les données, et fabrique elle-même `itemCount` et un
///    `itemBuilder` bâti sur ce widget.
///
/// ## Le rendu de référence
///
/// Centralisé dans [ZFlashcardCardReference] — l'unique fichier autorisé à
/// porter des valeurs de dégradé de référence (exception encadrée à
/// l'invariant sur les couleurs codées en dur, voir sa dartdoc) :
/// - une bande dégradée en tête, par type (violet pour un QCM, vert pour un
///   vrai/faux, cyan pour une question ouverte, rose pour un exercice) ;
/// - une tuile d'icône teintée à 15 % de la couleur primaire du type, rayon
///   8, glyphe teinté ;
/// - une zone de balises : puces colorées, invite « + Tags » quand vide
///   ([emptyTagsLabel]) ;
/// - une pastille de type en pied : point dégradé et libellé teintés par le
///   type — l'information de type reste toujours en texte (invariant
///   AD-13) ;
/// - une carte au rayon 12, liseré `outline`, ombre douce, fond
///   `scaffoldBackground`.
///
/// ## Deux axes de couleur, préséance arbitrée
///
/// - **Axe type** ([typeColors] → jeton `ZcrudTheme.flashcardTypeGradients` →
///   seam `ZcrudScope.gradientResolver` (clé `flashcard.type.<type.name>`) →
///   référence [ZFlashcardCardReference.typeGradients]) : gouverne la bande,
///   la teinte de la tuile d'icône et la pastille de type.
/// - **Axe IDENTITÉ** ([colorKey]/[palette]) : gouverne la palette des balises
///   ([ZTagChips]) — ce qu'il gouvernait déjà — et sert de **repli TOTAL** de
///   l'axe type (clé de type inconnue de toute la chaîne ⇒ accent uni dérivé,
///   AD-10 : jamais de carte sans accent).
/// - **Conflit réel MESURÉ** : par défaut (`colorKey == null`) il n'y en a
///   PAS — l'accent d'identité est lui-même dérivé de `card.type.name`, les
///   deux axes coïncident par construction. Les cas explicites sont arbitrés :
///   1. [typeColors] porte une entrée pour le type ⇒ elle gouverne les
///      surfaces de type, même face à un [colorKey] explicite (le paramètre
///      SPÉCIFIQUE à la surface gagne) ;
///   2. [colorKey] explicite sans entrée [typeColors] ⇒ il prime les DÉFAUTS
///      de l'axe type (bande unie `pair.color`, tuile et pastille teintées
///      `pair`) — le rendu v0.42-v0.45 des hôtes à `colorKey` est préservé,
///      par la règle « paramètre > jeton > référence ».
///
/// ## Invariants
///
/// - **FR-26/NFR-S7** : hors [ZFlashcardCardReference] (exception encadrée),
///   aucune couleur en dur — rôles et jetons. « QCM », « Vrai/Faux » arrivent
///   par [typeLabels] (repli clé opaque).
/// - **AD-13** : le type est **aussi** en texte (pastille de pied) ; insets et
///   alignements directionnels ; `Semantics`.
/// - **AD-4** : tout créneau non fourni est **absent de l'arbre**.
/// - **AD-1** : aucune nouvelle arête. **AD-2/SM-1** : `StatelessWidget` pur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZForegroundOverride,
        ZGradientSpec,
        ZStudyCardContentAlignment,
        ZcrudScope,
        ZcrudTheme,
        zResolveColorKeyOrSlot,
        zResolveGradient;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZChoice, ZFlashcard, ZFlashcardContentBuilder, ZFlashcardMarkdownContent;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import 'z_faded_overflow.dart';
import 'z_flashcard_card_reference.dart';
import 'z_readable_tint.dart';
import 'z_study_tools_item_card.dart';
import 'z_tag_chips.dart';

/// Épaisseur de la bande d'accent de tête (dimension de LAYOUT — la valeur de
/// référence vit dans [ZFlashcardCardReference.accentBandHeight]).
const double kZDefaultFlashcardAccentHeight =
    ZFlashcardCardReference.accentBandHeight;

/// Préfixe de la clé de dégradé soumise au seam `ZcrudScope.gradientResolver`
/// (couture EXISTANTE de l'epic VIS — aucun second mécanisme) : la clé
/// complète est `'$kZFlashcardTypeGradientKeyPrefix<type.name>'`.
const String kZFlashcardTypeGradientKeyPrefix = 'flashcard.type.';

/// Cible tactile minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Teinte de type **LISIBLE** pour un premier plan (texte, glyphe) — dérivée
/// de la couleur primaire du type par transformation HSL, **jamais** une
/// couleur nouvelle.
///
/// Appliquée aux premiers plans TEINTÉS PAR LE TYPE : peindre le libellé de
/// pied en `primaryColor` BRUT mesure **2,30:1** sur thème clair (`#4facfe`
/// sur blanc), sous le plancher WCAG AA (4,5:1) que la garde de contraste du
/// package impose à tout ce qui est peint. La saturation est bornée en bas
/// (≥ 0.4, la teinte reste identifiable) et la clarté est ramenée dans la
/// fenêtre lisible de la luminosité courante (0.25-0.45 en clair, 0.55-0.75
/// en sombre). Les FONDS décoratifs (tuile à 15 %, pastille à 10 %) gardent
/// la couleur brute — seul le premier plan est ajusté.
///
/// ## La fenêtre HSL ne GARANTIT rien, [surface] la garantit
///
/// Mesuré sur pièces : la fenêtre de clarté ci-dessus est une bande de
/// **clarté HSL**, pas de **luminance relative WCAG**. Sur une couleur
/// **arbitraire** (une couleur de dossier est choisie par l'utilisateur), elle
/// rend `#FFFF00 → #B3B300` à **2.13:1** et `#FFFFFE → #E5E500` à **1.28:1**
/// sur thème clair — c'est-à-dire PIRE que la couleur non traitée.
///
/// Passer [surface] (la couleur réellement peinte SOUS le premier plan) ajoute
/// une correction de luminance qui **garantit** [minContrast] sur la couleur
/// retournée (cf. [zReadableTintOn]).
///
/// **Rendu INCHANGÉ sur le jeu fermé des quatre types** : leurs contrastes
/// mesurés valent 5.28 à 9.59 en clair et 7.49 à 13.00 en sombre — tous
/// au-dessus de [kZTextMinContrast], donc la correction ne s'y applique pas et
/// les quatre sorties RVB restent bit-identiques (garde dédiée).
///
/// `surface == null` ⇒ comportement legacy STRICT, **sans garantie** : la
/// fonction ne peut pas deviner la surface, et fabriquer une surface de repli
/// serait coder une couleur en dur (FR-26). Préférer [zReadableTintOn], dont
/// la surface est REQUISE — et qui préserve en outre les teintes achromatiques
/// (`#808080` reste gris au lieu de virer au rouge `#7D3636`).
Color zReadableTypeTint(
  Color base, {
  required bool isDark,
  Color? surface,
  double minContrast = kZTextMinContrast,
}) {
  final HSLColor hsl = HSLColor.fromColor(base);
  final double saturation = hsl.saturation < 0.4 ? 0.4 : hsl.saturation;
  final double lightness;
  if (isDark) {
    lightness = hsl.lightness < 0.55
        ? 0.55 + (hsl.lightness * 0.3)
        : (hsl.lightness + 0.15 > 0.75 ? 0.75 : hsl.lightness + 0.15);
  } else {
    lightness = hsl.lightness > 0.45
        ? 0.45 - ((1 - hsl.lightness) * 0.2)
        : (hsl.lightness - 0.1 < 0.25 ? 0.25 : hsl.lightness - 0.1);
  }
  final Color placed = hsl
      .withSaturation(saturation)
      .withLightness(lightness.clamp(0.0, 1.0))
      .toColor();
  final Color? measured = surface;
  if (measured == null) return placed;
  return zReadableTintOn(placed, surface: measured, minContrast: minContrast);
}

/// Carte de flashcard **par défaut** du socle — autonome, sur le modèle
/// [ZFlashcard] (rendu de référence).
///
/// ```dart
/// ZDefaultFlashcardCard(
///   card: card,
///   typeLabels: {'multipleChoice': l10n.qcm, 'trueFalse': l10n.trueFalse},
///   tags: tagsOf(card),                 // résolus par l'hôte (ids → entités)
///   emptyTagsLabel: l10n.addTags,       // zone de balises = appel à l'action
///   onTagsTap: () => openTagEditor(card),
///   trailing: myCardMenu,               // le socle ignore ce qu'il contient
///   onTap: () => open(card),
///   onLongPress: () => showActions(card),
/// )
/// ```
class ZDefaultFlashcardCard extends StatelessWidget {
  /// Construit la carte ; seule [card] est requise.
  const ZDefaultFlashcardCard({
    required this.card,
    this.typeLabels,
    this.tags = const <ZFlashcardTag>[],
    this.emptyTagsLabel,
    this.onTagsTap,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.typeColors,
    this.icon,
    this.questionBuilder,
    this.questionMaxHeight = ZFlashcardCardReference.questionMaxHeight,
    this.questionFadeExtent = ZFlashcardCardReference.questionFadeExtent,
    this.showAnswerPreview = false,
    this.answerLabels,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderSide,
    this.borderRadius,
    this.backgroundColor,
    this.height = ZFlashcardCardReference.cardHeight,
    this.contentAlignment,
    super.key,
  }) : assert(
          questionMaxHeight > 0,
          'questionMaxHeight doit être > 0 (l\'énoncé est le contenu principal '
          'de la carte : le borner à zéro la viderait).',
        );

  /// Carte rendue — **seule** entrée requise. Le dessin ne lit que `type`,
  /// `question`, `tagIds` et `id` (cf. dartdoc de bibliothèque).
  final ZFlashcard card;

  /// Résolution `type.name → libellé LOCALISÉ` (FR-26/AD-13).
  ///
  /// `null` ou clé absente ⇒ **repli sur la clé opaque** (`'openQuestion'`) —
  /// patron EXACT de `ZFlashcardListView.typeLabels`. Le socle ne traduit
  /// **jamais** en dur.
  final Map<String, String>? typeLabels;

  /// Balises **résolues par l'hôte** (`tagIds` → entités). `ZFlashcard` ne porte
  /// que des **ids** : le socle ne peut pas les résoudre lui-même sans un store,
  /// ce qu'AD-2 lui interdit.
  ///
  /// Vide ⇒ la zone devient un **appel à l'action** si [emptyTagsLabel] est
  /// fourni, sinon elle est **absente** de l'arbre (AD-4).
  final List<ZFlashcardTag> tags;

  /// Libellé LOCALISÉ **INJECTÉ** de la zone de balises **vide** (appel à
  /// l'action). `null` ⇒ zone **absente** quand [tags] est vide (AD-4) —
  /// jamais un texte en dur, jamais un espace réservé muet.
  final String? emptyTagsLabel;

  /// Activation de la zone de balises **vide** (ex. ouvrir l'éditeur de tags).
  ///
  /// `null` ⇒ l'appel à l'action reste **affiché** mais n'est pas un bouton
  /// (invariant AD-4 : pas de bouton inerte). Sans effet si [emptyTagsLabel] est `null`.
  final VoidCallback? onTagsTap;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**) — l'axe IDENTITÉ.
  ///
  /// `null` (défaut) ⇒ l'accent d'identité est dérivé du **type** de la carte
  /// (`card.type.name`) et l'axe TYPE ([typeColors] et sa chaîne) gouverne les
  /// surfaces colorées. **Non-null** ⇒ choix d'identité EXPLICITE de l'hôte :
  /// il PRIME l'axe type sur la bande, la tuile et la pastille (préséance
  /// arbitrée, cf. dartdoc de bibliothèque).
  final String? colorKey;

  /// Dégradés par type **INJECTÉS** (paramètre — l'axe TYPE).
  ///
  /// Clé = `ZFlashcardType.name` opaque. Priorité de résolution (chaîne
  /// TOTALE, invariant AD-10) :
  /// **ce paramètre** > jeton `ZcrudTheme.flashcardTypeGradients` > seam
  /// `ZcrudScope.gradientResolver` (clé `flashcard.type.<type.name>` — la
  /// couture EXISTANTE, jamais un second mécanisme) >
  /// [ZFlashcardCardReference.typeGradients] > accent uni dérivé de l'axe
  /// identité (clé de type inconnue de TOUTE la chaîne).
  final Map<String, ZGradientSpec>? typeColors;

  /// Glyphe de la tuile d'icône. `null` ⇒ [ZFlashcardCardReference.glyph].
  final IconData? icon;

  /// Rendu de l'énoncé **INJECTABLE** — l'hôte qui veut SON moteur fournit
  /// ici son builder ; il gouverne AUSSI l'aperçu de réponse (« l'aperçu
  /// riche suit le même rendu que l'énoncé »).
  ///
  /// `null` (défaut) ⇒ **rendu RICHE** par [ZFlashcardMarkdownContent]
  /// (markdown + LaTeX, `zcrud_flashcard` → `zcrud_markdown`, dépendances déjà
  /// déclarées — invariant AD-1 : aucune arête nouvelle). Un simple `Text`
  /// tronquerait silencieusement l'information mathématique. Le style de
  /// référence (13/w600) est appliqué au défaut ; un builder fourni porte
  /// son propre style.
  ///
  /// Le rendu riche n'a pas de notion de ligne — la borne de référence est
  /// une HAUTEUR ([questionMaxHeight]), pas un nombre de lignes.
  final ZFlashcardContentBuilder? questionBuilder;

  /// Hauteur maximale de l'énoncé. Défaut :
  /// [ZFlashcardCardReference.questionMaxHeight].
  final double questionMaxHeight;

  /// Étendue du **fondu de continuation** peint au bas de l'énoncé **quand il
  /// déborde réellement** [questionMaxHeight].
  ///
  /// Défaut : [ZFlashcardCardReference.questionFadeExtent] (12 dp). `0` ⇒
  /// aucun fondu — l'énoncé est simplement écrêté, c'est-à-dire **exactement**
  /// le rendu v0.47.0 (voie de retour explicite pour un hôte que le fondu
  /// dérange).
  ///
  /// **Ce n'est PAS une ellipse, et le mot serait un mensonge** :
  /// `TextOverflow.ellipsis` est une propriété de *paragraphe*, sans prise sur
  /// le rendu RICHE par défaut (une colonne de blocs markdown/Quill — cf.
  /// [ZFadedOverflow]). Un hôte qui veut une VRAIE ellipse passe un
  /// [questionBuilder] rendant un `Text(overflow: TextOverflow.ellipsis)` :
  /// ce texte-là ne déborde alors jamais, donc aucun fondu ne se peint —
  /// les deux mécanismes ne se superposent pas.
  ///
  /// ♿ Le fondu n'est **pas** le seul canal : le `label` sémantique de la
  /// carte porte l'énoncé INTÉGRAL (AD-13).
  final double questionFadeExtent;

  /// Aperçu de réponse **en MODE** (mode surface, ex. rail de sections).
  ///
  /// `false` (défaut) ⇒ aperçu **ABSENT** (invariant AD-4) — le rail de
  /// sections ne l'affiche pas. `true` ⇒ `Divider` (hauteur
  /// [ZFlashcardCardReference.answerDividerHeight]) puis aperçu **teinté par
  /// type** : tampon « Vrai »/« Faux » pour `trueOrFalse` ([answerLabels]),
  /// liste des choix (✓/✕) pour `multipleChoice`, réponse riche sinon. Une
  /// carte SANS donnée de réponse (`answer`/`isTrue`/`choices` absents) ne
  /// rend NI divider NI aperçu — jamais une donnée fabriquée (invariant AD-10).
  final bool showAnswerPreview;

  /// Libellés LOCALISÉS **INJECTÉS** du tampon Vrai/Faux (FR-26 — patron
  /// [typeLabels]) : clés opaques `'true'` / `'false'`. `null` ou clé absente
  /// ⇒ repli sur la clé opaque — le socle ne traduit **jamais** en dur.
  final Map<String, String>? answerLabels;

  /// Créneau d'actions de fin de carte (menu contextuel de l'hôte, avec ses
  /// propres règles de droits — que le socle ignore). `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ carte non
  /// interactive (invariant AD-4 — aucun `InkWell` inerte).
  final VoidCallback? onTap;

  /// Appui long (menu contextuel). `null` ⇒ capacité **ABSENTE** (invariant AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : l'énoncé.
  final String? semanticLabel;

  /// Liseré EXPLICITE de la carte. `null` ⇒ référence : rôle `outline` à
  /// [ZFlashcardCardReference.borderWidth] (jamais un hex — FR-26).
  final BorderSide? borderSide;

  /// Rayon EXPLICITE de la carte. `null` ⇒
  /// [ZFlashcardCardReference.cardRadius] (12).
  final Radius? borderRadius;

  /// Fond EXPLICITE de la carte. `null` ⇒ référence : le rôle
  /// `scaffoldBackgroundColor` de l'hôte (jamais un hex — FR-26).
  final Color? backgroundColor;

  /// Hauteur FIXE de la carte.
  ///
  /// Défaut : [ZFlashcardCardReference.cardHeight] (200) — c'est la hauteur
  /// fixe qui rend la grille et le rail **réguliers** (toutes les cartes d'une
  /// rangée à la même hauteur, quel que soit leur contenu). Passer **`null`
  /// explicitement** rend la hauteur **intrinsèque** (la carte suit son
  /// contenu). Sous des contraintes verticales **serrées** (cellule de grille
  /// à hauteur imposée), la contrainte du parent PRIME — jamais de
  /// débordement par construction.
  final double? height;

  /// Alignement VERTICAL du contenu **dans le cadre**.
  ///
  /// `null` ⇒ jeton `ZcrudTheme.studyCardContentAlignment`, puis la RÉFÉRENCE
  /// [ZFlashcardCardReference.contentAlignment] (`spread` : l'énoncé absorbe
  /// l'espace libre, la pastille de type est POUSSÉE au bas de la carte —
  /// toutes les cartes d'un rail ont alors la même ligne de base).
  ///
  /// **Sans cadre, il n'a AUCUN effet** : passer `height: null` **et** ne
  /// pas borner la carte de l'extérieur rend exactement la hauteur
  /// intrinsèque, identique pour les trois valeurs (il n'y a pas d'espace
  /// libre à répartir). La bascule est mesurée sur les contraintes reçues.
  final ZStudyCardContentAlignment? contentAlignment;

  /// Libellé de type **affiché** : injecté, repli sur la clé opaque.
  String get _typeLabel => typeLabels?[card.type.name] ?? card.type.name;

  /// Paire fond/premier plan de l'axe IDENTITÉ — **dérivée** d'une clé stable,
  /// via le remap du kernel puis le résolveur TOTAL du cœur (jamais `null`,
  /// jamais de throw — AD-10). Aucune table de couleurs locale.
  ZColorPair _identityPair(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      seedTitle: card.type.name,
    );
    return zResolveColorKeyOrSlot(
      context,
      key,
      slotIndex: palette.indexOf(key),
    );
  }

  /// Dégradé de l'axe TYPE — chaîne de résolution (cf. [typeColors]).
  ///
  /// `null` ⇒ clé de type inconnue de TOUTE la chaîne, OU [colorKey] explicite
  /// (l'identité prime) : les surfaces replient sur l'accent uni.
  ZGradientSpec? _typeSpec(BuildContext context) {
    final String typeName = card.type.name;
    // Préséance arbitrée (les DEUX axes posés ensemble) :
    // 1. [typeColors] EXPLICITE pour ce type : le paramètre SPÉCIFIQUE à la
    //    surface gagne toujours — même face à un [colorKey] explicite.
    final ZGradientSpec? explicit = typeColors?[typeName];
    if (explicit != null) return explicit;
    // 2. [colorKey] EXPLICITE (sans entrée [typeColors]) : choix d'identité de
    //    l'hôte — il prime les DÉFAUTS de l'axe type (jeton, seam, référence).
    //    Sans colorKey, les deux axes coïncident par construction (l'accent
    //    d'identité dérive de `card.type.name`) : aucun conflit mesurable.
    if (colorKey != null) return null;
    return ZcrudTheme.of(context).flashcardTypeGradients?[typeName] ??
        zResolveGradient(
          context,
          '$kZFlashcardTypeGradientKeyPrefix$typeName',
        ) ??
        ZFlashcardCardReference.typeGradients[typeName];
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ThemeData material = Theme.of(context);
    final ZColorPair pair = _identityPair(context);
    final ZGradientSpec? spec = _typeSpec(context);
    // Couleur « primaire » du type : la PREMIÈRE couleur du dégradé
    // (`gradientColors[0]`), repli sur l'accent d'identité (chaîne totale).
    final Color primary = spec == null
        ? pair.color
        : (spec.gradient is LinearGradient
            ? (spec.gradient as LinearGradient).colors.first
            : pair.color);
    final Widget? tagsZone = _buildTagsZone(context, theme);

    // Ombre douce de référence — REPLI sous les jetons `cardShadow*`
    // (`ZStudyToolsItemCard.defaultShadow`), rôle `shadow`, opacité par
    // luminosité (0.06 clair / 0.2 sombre, scalaires de référence).
    final bool isDark = material.brightness == Brightness.dark;
    // Premier plan teinté LISIBLE (texte/glyphe) — cf. [zReadableTypeTint] :
    // la teinte brute mesure 2,30:1 sur clair, sous le plancher AA.
    // La SURFACE réellement peinte sous ces premiers plans est passée : la
    // fenêtre HSL seule ne borne pas le contraste (elle rendrait 2.13:1 sur
    // un jaune). Sur les quatre types de référence la correction ne mord pas
    // (contrastes mesurés 5.28 à 13.00) : rendu bit-identique.
    final Color cardSurface = backgroundColor ?? material.scaffoldBackgroundColor;
    final Color readable = zReadableTypeTint(
      primary,
      isDark: isDark,
      surface: cardSurface,
    );
    final Radius corner =
        borderRadius ?? ZFlashcardCardReference.cardRadius;
    final BoxDecoration referenceShadow = BoxDecoration(
      borderRadius: BorderRadius.all(corner),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: material.shadowColor.withValues(
            alpha: isDark
                ? ZFlashcardCardReference.shadowAlphaDark
                : ZFlashcardCardReference.shadowAlphaLight,
          ),
          blurRadius: ZFlashcardCardReference.shadowBlurRadius,
          offset: ZFlashcardCardReference.shadowOffset,
        ),
      ],
    );

    final Widget cardWidget = ZStudyToolsItemCard(
      // Chrome de référence (priorité paramètre > référence ; les couleurs
      // sont des RÔLES ou DÉRIVÉES de la référence des dégradés, exception
      // invariant FR-26 encadrée).
      borderRadius: corner,
      // Liseré TEINTÉ PAR TYPE, très fin et léger (la bande épaisse de tête
      // reste) : couleur DÉRIVÉE de la primaire du type (chaîne totale —
      // jamais une couleur nouvelle), surchargeable par [borderSide].
      borderSide: borderSide ??
          BorderSide(
            color: primary.withValues(
              alpha: ZFlashcardCardReference.borderTintAlpha,
            ),
            width: ZFlashcardCardReference.borderWidth,
          ),
      color: cardSurface,
      defaultShadow: referenceShadow,
      // ① Bande d'accent de tête — DÉGRADÉE par type (uni sur l'axe identité
      // ou clé inconnue). Décor : ni geste, ni sémantique — c'est
      // `ZStudyToolsItemCard` qui l'isole.
      accent: SizedBox(
        key: accentKey,
        height: kZDefaultFlashcardAccentHeight,
        child: DecoratedBox(
          decoration: spec == null
              ? BoxDecoration(color: pair.color)
              : BoxDecoration(gradient: spec.gradient),
        ),
      ),
      // ② + ③ Ligne d'EN-TÊTE de référence : tuile d'icône ET zone de
      // balises SUR LA MÊME LIGNE (+ le créneau d'actions de l'hôte) —
      // l'énoncé vient EN DESSOUS pleine largeur. C'est pourquoi la tuile ne
      // passe PAS par `leading` (qui vivrait À CÔTÉ de toute la colonne) ni
      // les actions par `trailing`.
      aboveTitle: _buildHeaderRow(theme, primary, readable, tagsZone),
      // ④ Énoncé — [title] reste la SOURCE SÉMANTIQUE ; le rendu est RICHE
      // (markdown + LaTeX) par défaut, borné à [questionMaxHeight].
      title: card.question,
      titleWidget: _buildQuestion(context),
      // ⑤ Pied : aperçu de réponse EN MODE (divider + aperçu teinté par
      // type) puis pastille de type — le type redit **en TEXTE** (invariant
      // AD-13 : la couleur n'est jamais le seul canal).
      belowSubtitle: _buildFooter(context, spec, primary, readable),
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? card.question,
      // La carte est construite en CONTRAINTES DESCENDANTES :
      // sous un cadre de hauteur (le sien, [height], ou celui d'un
      // `ZRailItem(height:)`/d'une cellule), le corps le REMPLIT et le pied
      // est poussé en bas. Priorité paramètre > jeton > référence (`spread`).
      contentAlignment: contentAlignment ??
          theme.studyCardContentAlignment ??
          ZFlashcardCardReference.contentAlignment,
    );
    // Hauteur FIXE de référence (200) : c'est elle qui rend grille et rail
    // réguliers. `height: null` EXPLICITE ⇒ hauteur intrinsèque ; sous des
    // contraintes serrées (cellule de grille), la contrainte du parent prime
    // (comportement `SizedBox` du SDK — la carte ne déborde pas sa cellule).
    final double? fixedHeight = height;
    return fixedHeight == null
        ? cardWidget
        : SizedBox(height: fixedHeight, child: cardWidget);
  }

  /// ② + ③ Ligne d'en-tête de référence : tuile d'icône et zone de balises
  /// **sur la même ligne** (l'énoncé vient en dessous, pleine largeur) + le
  /// créneau [trailing] de l'hôte en fin de ligne — sa sémantique est
  /// PRÉSERVÉE.
  Widget _buildHeaderRow(
    ZcrudTheme theme,
    Color primary,
    Color readable,
    Widget? tagsZone,
  ) =>
      Row(
        key: headerRowKey,
        children: <Widget>[
          _buildIconTile(primary, readable),
          SizedBox(width: theme.gapS),
          Expanded(child: tagsZone ?? const SizedBox.shrink()),
          if (trailing != null) ...<Widget>[
            SizedBox(width: theme.gapS),
            trailing!,
          ],
        ],
      );

  /// ④ Énoncé — rendu RICHE par défaut ([questionBuilder] en surcharge),
  /// borné en HAUTEUR ([questionMaxHeight]).
  ///
  /// Le débordement est ABSORBÉ **et SIGNALÉ** : la hauteur rendue reste
  /// `min(contenu, borne)` — la carte ne défile jamais elle-même — mais un
  /// **fondu de continuation** est peint sur les dernières
  /// [questionFadeExtent] dp **quand, et seulement quand, le contenu déborde
  /// réellement**. Jamais un `RenderFlex overflowed` par construction, jamais
  /// un contenu qui déborde la carte.
  Widget _buildQuestion(BuildContext context) {
    final ZFlashcardContentBuilder? custom = questionBuilder;
    final Widget content = custom != null
        ? custom(context, card.question)
        : _ZFlashcardRichText(
            content: card.question,
            fontWeight: ZFlashcardCardReference.questionFontWeight,
          );
    // FR-26 — les deux bornes du masque sont DÉRIVÉES d'un rôle : sous
    // `BlendMode.dstIn` seul leur ALPHA compte, elles ne peignent aucune
    // matière (aucune couleur nouvelle n'entre par cette porte).
    final Color stencil = Theme.of(context).colorScheme.onSurface;
    // IgnorePointer — MESURÉ : le lecteur rich-text (Quill) porte ses propres
    // gestes (sélection à l'appui long) et VOLE l'arène au `InkWell` de la
    // carte (l'appui long de l'hôte ne déclenchait plus). Dans une carte,
    // l'énoncé est un APERÇU : aucun geste propre.
    return ConstrainedBox(
      key: questionKey,
      constraints: BoxConstraints(maxHeight: questionMaxHeight),
      child: IgnorePointer(
        child: ZFadedOverflow(
          fadeExtent: questionFadeExtent,
          opaque: stencil.withValues(alpha: 1),
          clear: stencil.withValues(alpha: 0),
          child: content,
        ),
      ),
    );
  }

  /// ⑤ Pied de carte : aperçu de réponse **en mode** puis pastille de type.
  /// Sans donnée de réponse, NI divider NI aperçu (invariant AD-4).
  Widget _buildFooter(
    BuildContext context,
    ZGradientSpec? spec,
    Color primary,
    Color readable,
  ) {
    final Widget? preview =
        showAnswerPreview ? _buildAnswerPreview(context, readable) : null;
    final Widget pill = _buildTypePill(context, spec, primary, readable);
    if (preview == null) return pill;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Divider(
          key: answerDividerKey,
          height: ZFlashcardCardReference.answerDividerHeight,
          // Rôle : le trait de séparation legacy (`grey.shade200/800`) est le
          // rôle `outlineVariant` — jamais un hex (FR-26).
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Flexible(
          // IgnorePointer — même mesure que l'énoncé : l'aperçu est INERTE,
          // les gestes appartiennent à la carte.
          child: IgnorePointer(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: preview,
            ),
          ),
        ),
        SizedBox(height: ZcrudTheme.of(context).gapS),
        pill,
      ],
    );
  }

  /// Aperçu de réponse **teinté par type** — trois formes :
  ///
  /// - `trueOrFalse` ⇒ **tampon** « Vrai »/« Faux » ([answerLabels], clés
  ///   opaques) — vrai = teinte de type LISIBLE, faux = rôle `error` (jamais
  ///   de couleur codée en dur ; l'information reste AUSSI en texte,
  ///   invariant AD-13). `isTrue` absent ⇒ aperçu ABSENT — jamais un « Faux » fabriqué
  ///   depuis `null` (écart assumé avec le legacy `isTrue ?? false`) ;
  /// - `multipleChoice` ⇒ liste des choix « ✓/✕ » (fidélité au CODE legacy,
  ///   qui dit plus que sa CR) — corrects en teinte de type, incorrects en
  ///   rôle `error`, contenu RICHE ;
  /// - sinon ⇒ [ZFlashcard.answer] en rendu riche teinté par type ; réponse
  ///   absente/vide ⇒ `null` (l'appelant n'affiche pas non plus le divider).
  Widget? _buildAnswerPreview(BuildContext context, Color readable) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (card.type.name) {
      case 'trueOrFalse':
        final bool? isTrue = card.isTrue;
        if (isTrue == null) return null;
        final Color tint = isTrue ? readable : scheme.error;
        final String label = answerLabels?[isTrue ? 'true' : 'false'] ??
            (isTrue ? 'true' : 'false');
        // Tampon legacy : 200×40, rotation −0.45 rad puis translation (0, 40),
        // fond teinté (alpha 100/255), liseré teinté, texte italique gras.
        // Taille : `headlineSmall` (24 en Material — la valeur legacy) via le
        // thème, jamais un `fontSize:` littéral (a11y/`textScaler`).
        return Center(
          child: Container(
            key: stampKey,
            width: ZFlashcardCardReference.stampWidth,
            height: ZFlashcardCardReference.stampHeight,
            transform: Matrix4.rotationZ(
              ZFlashcardCardReference.stampRotationRadians,
            )..translateByDouble(
                0, ZFlashcardCardReference.stampTranslationY, 0, 1),
            decoration: BoxDecoration(
              color: tint.withValues(
                alpha: ZFlashcardCardReference.stampBackgroundAlpha,
              ),
              borderRadius:
                  BorderRadius.all(ZFlashcardCardReference.stampRadius),
              border: Border.all(color: tint),
            ),
            child: Center(
              child: Text(
                label,
                key: stampLabelKey,
                style: (Theme.of(context).textTheme.headlineSmall ??
                        const TextStyle())
                    .copyWith(
                  color: tint,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      case 'multipleChoice':
        final List<ZChoice> choices = card.choices ?? const <ZChoice>[];
        final List<ZChoice> visible = <ZChoice>[
          for (final ZChoice c in choices)
            if (c.content.trim().isNotEmpty) c,
        ];
        if (visible.isEmpty) {
          // Sans choix, replie sur la réponse libre si elle existe (AD-10).
          return _buildRichAnswer(context, readable);
        }
        return Column(
          key: answerPreviewKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ZChoice choice in visible)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Marque TEXTUELLE (✓/✕) — l'information n'est jamais
                  // portée par la seule couleur (AD-13). Legacy :
                  // `flashcard_widgets.dart:513-514`.
                  Text(
                    choice.isCorrect ? '✓ ' : '✕ ',
                    style: (Theme.of(context).textTheme.labelSmall ??
                            const TextStyle())
                        .copyWith(
                      color: choice.isCorrect ? readable : scheme.error,
                    ),
                  ),
                  Expanded(
                    child: _buildContent(
                      context,
                      choice.content,
                      tint: choice.isCorrect ? readable : scheme.error,
                    ),
                  ),
                ],
              ),
          ],
        );
      default:
        return _buildRichAnswer(context, readable);
    }
  }

  /// Réponse libre riche teintée par type ; absente/vide ⇒ `null` (AD-4).
  /// Passe par [_buildContent] : « l'aperçu SUIT le rendu de l'énoncé »
  /// (un [questionBuilder] injecté gouverne aussi ici).
  Widget? _buildRichAnswer(BuildContext context, Color readable) {
    final String? answer = card.answer;
    if (answer == null || answer.trim().isEmpty) return null;
    return KeyedSubtree(
      key: answerPreviewKey,
      child: _buildContent(context, answer, tint: readable),
    );
  }

  /// Contenu riche via [questionBuilder] s'il est fourni (« l'aperçu suit le
  /// même rendu que l'énoncé »), sinon le rendu riche par défaut teinté.
  Widget _buildContent(BuildContext context, String content, {Color? tint}) {
    final ZFlashcardContentBuilder? custom = questionBuilder;
    if (custom != null) return custom(context, content);
    return _ZFlashcardRichText(content: content, tint: tint);
  }

  /// ② Tuile d'icône — **décorative et MUETTE** (le glyphe ne porte aucune
  /// information que le texte de la carte ne porte déjà).
  Widget _buildIconTile(Color primary, Color readable) => ExcludeSemantics(
        child: SizedBox(
          key: iconTileKey,
          width: ZFlashcardCardReference.iconTileSize,
          height: ZFlashcardCardReference.iconTileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: primary.withValues(
                alpha: ZFlashcardCardReference.iconTileTintAlpha,
              ),
              borderRadius:
                  BorderRadius.all(ZFlashcardCardReference.iconTileRadius),
            ),
            child: Icon(
              icon ?? ZFlashcardCardReference.glyph,
              // Premier plan AJUSTÉ (lisible) — le fond à 15 % reste brut.
              color: readable,
              size: ZFlashcardCardReference.glyphSize,
            ),
          ),
        ),
      );

  /// ③ Zone de balises — **affichée même vide**, sous forme d'appel à l'action.
  ///
  /// `null` ⇒ zone **absente** de l'arbre (AD-4) : c'est le cas « aucune balise
  /// ET aucun libellé d'appel à l'action injecté ».
  Widget? _buildTagsZone(BuildContext context, ZcrudTheme theme) {
    if (tags.isNotEmpty) {
      // Aucune rangée de puces réécrite : `ZTagChips` porte déjà la palette
      // filée, le titre textuel systématique (AD-13) et les cibles ≥ 48 dp.
      return ZTagChips(key: tagsKey, tags: tags, palette: palette);
    }
    final String? label = emptyTagsLabel;
    if (label == null) return null;

    final Widget text = Text(
      label,
      key: emptyTagsKey,
      textAlign: TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    );
    final VoidCallback? tap = onTagsTap;
    if (tap == null) {
      // AD-45 — pas de bouton inerte : sans action, c'est une simple invite.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        // `heightFactor: 1` — MESURÉ, pas supposé : un `Align` sans facteur
        // **remplit** la hauteur disponible. Sous une colonne à hauteur non
        // bornée (rail, cellule libre), la carte passait ainsi de ~140 dp à
        // **854 dp** — un vide de ~400 dp entre les balises et la puce de pied.
        heightFactor: 1,
        child: text,
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.all(theme.radiusM),
            // La sémantique est portée UNE seule fois — par le nœud ci-dessus.
            excludeFromSemantics: true,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapS),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⑤ Pastille de type de pied : point dégradé + libellé **en texte** teinté
  /// par le type, sur un fond teinté à 10 % (référence).
  ///
  /// Le point est **décoratif et MUET** ([ExcludeSemantics]) : l'information
  /// est portée par le libellé texte, jamais par la couleur seule (invariant AD-13).
  Widget _buildTypePill(
    BuildContext context,
    ZGradientSpec? spec,
    Color primary,
    Color readable,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // `heightFactor: 1` — cf. la zone de balises : sans lui, l'`Align`
        // remplit la hauteur disponible et gonfle la carte (mesuré).
        heightFactor: 1,
        child: DecoratedBox(
          key: typeChipKey,
          decoration: BoxDecoration(
            color: primary.withValues(
              alpha: ZFlashcardCardReference.typePillBackgroundAlpha,
            ),
            borderRadius:
                BorderRadius.all(ZFlashcardCardReference.typePillRadius),
          ),
          child: Padding(
            padding: ZFlashcardCardReference.typePillPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: SizedBox(
                    key: typeDotKey,
                    width: ZFlashcardCardReference.typePillDotSize,
                    height: ZFlashcardCardReference.typePillDotSize,
                    child: DecoratedBox(
                      decoration: spec == null
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                            )
                          : BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: spec.gradient,
                            ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: ZFlashcardCardReference.typePillGap,
                ),
                Flexible(
                  child: Text(
                    _typeLabel,
                    key: typeLabelKey,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Taille depuis le thème (jamais un `fontSize:`
                    // littéral : a11y/`textScaler`) ; le premier plan est la
                    // teinte de type AJUSTÉE lisible ([zReadableTypeTint]) sur
                    // le fond teinté à 10 % — la couleur brute, non ajustée,
                    // mesure 2,30:1 en clair (sous AA).
                    style: (Theme.of(context).textTheme.labelSmall ??
                            const TextStyle())
                        .copyWith(
                      color: readable,
                      fontWeight:
                          ZFlashcardCardReference.typeLabelFontWeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Clé de la bande d'accent (testabilité).
  static const ValueKey<String> accentKey =
      ValueKey<String>('zDefaultFlashcardCard_accent');

  /// Clé de la tuile d'icône de tête (testabilité).
  static const ValueKey<String> iconTileKey =
      ValueKey<String>('zDefaultFlashcardCard_iconTile');

  /// Clé du point de type de la pastille de pied (testabilité).
  ///
  /// Le point vit DANS la pastille de pied (forme de référence) — il n'y a
  /// pas de pastille d'en-tête.
  static const ValueKey<String> typeDotKey =
      ValueKey<String>('zDefaultFlashcardCard_typeDot');

  /// Clé de la pastille de type de pied (testabilité).
  static const ValueKey<String> typeChipKey =
      ValueKey<String>('zDefaultFlashcardCard_typeChip');

  /// Clé du **texte** de type de pied (testabilité — AD-13).
  static const ValueKey<String> typeLabelKey =
      ValueKey<String>('zDefaultFlashcardCard_typeLabel');

  /// Clé de la zone de balises renseignée (testabilité).
  static const ValueKey<String> tagsKey =
      ValueKey<String>('zDefaultFlashcardCard_tags');

  /// Clé de l'appel à l'action « aucune balise » (testabilité).
  static const ValueKey<String> emptyTagsKey =
      ValueKey<String>('zDefaultFlashcardCard_emptyTags');

  /// Clé de la ligne d'en-tête tuile + balises (testabilité).
  static const ValueKey<String> headerRowKey =
      ValueKey<String>('zDefaultFlashcardCard_headerRow');

  /// Clé de l'énoncé borné (testabilité).
  static const ValueKey<String> questionKey =
      ValueKey<String>('zDefaultFlashcardCard_question');

  /// Clé du `Divider` de l'aperçu de réponse (testabilité).
  static const ValueKey<String> answerDividerKey =
      ValueKey<String>('zDefaultFlashcardCard_answerDivider');

  /// Clé de l'aperçu de réponse (testabilité).
  static const ValueKey<String> answerPreviewKey =
      ValueKey<String>('zDefaultFlashcardCard_answerPreview');

  /// Clé du tampon « Vrai »/« Faux » (testabilité).
  static const ValueKey<String> stampKey =
      ValueKey<String>('zDefaultFlashcardCard_stamp');

  /// Clé du **texte** du tampon (testabilité — AD-13).
  static const ValueKey<String> stampLabelKey =
      ValueKey<String>('zDefaultFlashcardCard_stampLabel');
}

/// Rendu **RICHE par défaut** d'un contenu de carte —
/// [ZFlashcardMarkdownContent] (markdown + LaTeX) ADAPTÉ au chrome d'une
/// carte, mesures à l'appui :
///
/// - **liseré de champ ÉTEINT** : `ZMarkdownReader` peint toujours le liseré
///   `fieldBorderColor`/`outline` d'un CHAMP de formulaire — dans une carte,
///   l'énoncé n'en est pas un. Neutralisé par une ré-injection LOCALE du thème
///   ([ZFlashcardCardReference.neutralizedFieldBorder], alpha 0 — le
///   `DecoratedBox` du lecteur ne réservant aucune place au trait, le layout
///   est STRICTEMENT celui d'un contenu nu) ;
/// - **padding de champ ÉTEINT** (`fieldPadding` → zéro, même mécanisme) ;
/// - **corps 13** : Quill fixe son paragraphe à 16
///   ([ZFlashcardCardReference.quillBaseFontSize], mesuré sur pièces) et
///   ignore la taille du `DefaultTextStyle` ambiant — la référence (13) est
///   obtenue par un `TextScaler` COMPOSÉ avec l'échelle ambiante (le facteur
///   utilisateur reste appliqué : a11y) ;
/// - **graisse/teinte** : passées par `DefaultTextStyle.merge` — Quill les
///   hérite (seuls `fontSize`/`height`/`decoration` sont forcés par sa base).
///
/// Quand un [ZcrudScope] parent existe, la ré-injection passe par
/// [ZcrudScope.copyWith] : l'ancienne copie manuelle pouvait oublier un seam
/// ajouté au cœur et faire disparaître silencieusement une personnalisation de
/// l'hôte. Sans scope, une extension de `Theme` conserve le contre-chemin
/// historique. Dans les DEUX cas, seule la paire
/// `fieldBorderColor`/`fieldPadding` change, pour le SEUL sous-arbre du lecteur.
class _ZFlashcardRichText extends StatelessWidget {
  const _ZFlashcardRichText({
    required this.content,
    this.tint,
    this.fontWeight,
  });

  /// Source markdown/LaTeX (l'énoncé, une réponse ou un choix).
  final String content;

  /// Teinte du premier plan (aperçu de réponse « teinté par type »). `null`
  /// ⇒ couleur ambiante.
  final Color? tint;

  /// Graisse (l'énoncé de référence : `w600`). `null` ⇒ graisse ambiante.
  final FontWeight? fontWeight;

  /// Impose [tint] par la primitive — ou rend [child] TEL QUEL si nul (AD-4).
  Widget _withTint(Widget child) {
    final Color? color = tint;
    if (color == null) return child;
    return ZForegroundOverride(color: color, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme neutralized = ZcrudTheme.of(context).copyWith(
      fieldBorderColor: ZFlashcardCardReference.neutralizedFieldBorder,
      fieldPadding: EdgeInsetsDirectional.zero,
    );

    // Échelle 16 → 13 COMPOSÉE avec l'échelle utilisateur : la cible est
    // « ce que rendrait un Text(13) sous l'échelle ambiante ».
    final TextScaler ambient = MediaQuery.textScalerOf(context);
    final TextScaler scaler = TextScaler.linear(
      ambient.scale(ZFlashcardCardReference.questionFontSize) /
          ZFlashcardCardReference.quillBaseFontSize,
    );

    Widget child = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      // La COULEUR passe par la primitive (garde v0.39.0 : aucun `merge`
      // coloré hors de `ZForegroundOverride` — elle seule ferme les trois
      // chemins, `textTheme` compris). Le `merge` ne porte que la GRAISSE,
      // ajustement expressément légitime pour la garde. `tint` nul ⇒ la
      // primitive est ABSENTE de l'arbre (AD-4), couleur ambiante conservée.
      child: _withTint(
        DefaultTextStyle.merge(
          style: TextStyle(fontWeight: fontWeight),
          // Vide ⇒ RIEN (placeholder vide) : la carte rendait déjà un énoncé
          // vide comme un blanc — jamais un « Aucun contenu » non injecté.
          child: ZFlashcardMarkdownContent(content: content, placeholder: ''),
        ),
      ),
    );

    final ZcrudScope? scope = ZcrudScope.maybeOf(context);
    if (scope != null) {
      return scope.copyWith(
        theme: neutralized,
        child: child,
      );
    }
    final ThemeData material = Theme.of(context);
    return Theme(
      data: material.copyWith(
        extensions: (Map<Object, ThemeExtension<dynamic>>.of(
          material.extensions,
        )..[ZcrudTheme] = neutralized)
            .values,
      ),
      child: child,
    );
  }
}
