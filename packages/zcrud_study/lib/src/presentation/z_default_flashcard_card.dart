/// `ZDefaultFlashcardCard` — **carte de flashcard PAR DÉFAUT** du socle
/// (CR-IFFD-47, rendu de référence CR-IFFD-57).
///
/// ## Le besoin, et la forme qu'il ne pouvait PAS prendre
///
/// `ZStudyToolsSectionSpec.itemBuilder` est **requis** : chaque application
/// d'étude réécrit donc la même carte de flashcard. Le besoin est réel.
///
/// 🔴 La forme demandée — « rendre `itemBuilder` facultatif, avec un rendu par
/// défaut » — **ne peut pas fonctionner**, et c'est vérifiable sur la data-class
/// elle-même : `ZStudyToolsSectionSpec` porte `itemCount` + `itemBuilder(context,
/// index)` et **AUCUNE donnée**. Sans `itemBuilder`, le socle ne sait pas ce
/// qu'est l'item numéro *i* : il ne pourrait rendre **rien du tout**. Le défaut
/// n'est pas un manque de volonté, c'est une **absence d'information**.
///
/// Deux livrables remplacent donc cette forme, et suppriment réellement le
/// travail répété :
/// 1. **ce widget** — autonome, instanciable dans l'`itemBuilder` de l'hôte ;
/// 2. **`ZStudyToolsSectionSpec.flashcards(cards: …)`** — la voie TYPÉE qui
///    porte les données, et fabrique elle-même `itemCount` **et** un
///    `itemBuilder` bâti sur ce widget.
///
/// ## Le rendu de référence (CR-IFFD-57)
///
/// Mesuré chez IFFD (`flashcard_widgets.dart:88-156, 265-340`) et centralisé
/// dans [ZFlashcardCardReference] — l'unique fichier autorisé à porter les hex
/// des dégradés (exception FR-26 encadrée, cf. sa dartdoc) :
/// - **bande DÉGRADÉE en tête, par type** (violet QCM, vert V/F, cyan question
///   ouverte, rose exercice) ;
/// - **tuile d'icône** teintée à 15 % de la couleur primaire du type, rayon 8,
///   glyphe teinté ;
/// - **zone de balises** : puces colorées, « + Tags » appel à l'action quand
///   vide ([emptyTagsLabel]) ;
/// - **pastille de type en pied** : point dégradé + libellé teintés par le
///   type — l'information type reste EN TEXTE (AD-13) ;
/// - carte : rayon 12, liseré `outline`, ombre douce (repli SOUS les jetons
///   `cardShadow*`), fond `scaffoldBackground`.
///
/// ## Deux axes de couleur — préséance ARBITRÉE (CR-IFFD-57, « non mesuré » n°2)
///
/// - **Axe TYPE** ([typeColors] → jeton `ZcrudTheme.flashcardTypeGradients` →
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
        ZGradientSpec,
        ZcrudTheme,
        zResolveColorKeyOrSlot,
        zResolveGradient;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import 'z_flashcard_card_reference.dart';
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

/// Cible tactile minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Teinte de type **LISIBLE** pour un premier plan (texte, glyphe) — dérivée
/// de la couleur primaire du type par transformation HSL, **jamais** une
/// couleur nouvelle (CR-IFFD-57, « non mesuré » n°1).
///
/// Port du `adjustTagColor` legacy IFFD (`flashcard_widgets.dart:32-58`),
/// appliqué ici aux premiers plans TEINTÉS PAR LE TYPE : le legacy peignait le
/// libellé de pied en `primaryColor` BRUT — mesuré chez nous à **2,30:1** sur
/// thème clair (`#4facfe` sur blanc), sous le plancher WCAG AA (4,5:1) que la
/// garde de contraste du package impose à tout ce qui est peint. La saturation
/// est bornée en bas (≥ 0.4, la teinte reste identifiable) et la clarté est
/// ramenée dans la fenêtre lisible de la luminosité courante (0.25-0.45 en
/// clair, 0.55-0.75 en sombre). Les FONDS décoratifs (tuile à 15 %, pastille
/// à 10 %) gardent la couleur brute — seul le premier plan est ajusté.
Color zReadableTypeTint(Color base, {required bool isDark}) {
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
  return hsl
      .withSaturation(saturation)
      .withLightness(lightness.clamp(0.0, 1.0))
      .toColor();
}

/// Carte de flashcard **par défaut** du socle — autonome, sur le modèle
/// [ZFlashcard] (CR-IFFD-47 ; rendu de référence CR-IFFD-57).
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
    this.questionMaxLines = 3,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderSide,
    this.borderRadius,
    this.backgroundColor,
    this.height = ZFlashcardCardReference.cardHeight,
    super.key,
  }) : assert(
          questionMaxLines > 0,
          'questionMaxLines doit être ≥ 1 (l\'énoncé est le contenu principal '
          'de la carte : le tronquer à zéro ligne la viderait).',
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
  /// (AD-45 : pas de bouton inerte). Sans effet si [emptyTagsLabel] est `null`.
  final VoidCallback? onTagsTap;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**) — l'axe IDENTITÉ.
  ///
  /// `null` (défaut) ⇒ l'accent d'identité est dérivé du **type** de la carte
  /// (`card.type.name`) et l'axe TYPE ([typeColors] et sa chaîne) gouverne les
  /// surfaces colorées. **Non-null** ⇒ choix d'identité EXPLICITE de l'hôte :
  /// il PRIME l'axe type sur la bande, la tuile et la pastille (préséance
  /// arbitrée CR-IFFD-57, cf. dartdoc de bibliothèque).
  final String? colorKey;

  /// Dégradés par type **INJECTÉS** (paramètre — l'axe TYPE, CR-IFFD-57).
  ///
  /// Clé = `ZFlashcardType.name` opaque. Priorité de résolution (patron
  /// `formatColors` CR-55/56, chaîne TOTALE — AD-10) :
  /// **ce paramètre** > jeton `ZcrudTheme.flashcardTypeGradients` > seam
  /// `ZcrudScope.gradientResolver` (clé `flashcard.type.<type.name>` — la
  /// couture VIS existante, jamais un second mécanisme) >
  /// [ZFlashcardCardReference.typeGradients] > accent uni dérivé de l'axe
  /// identité (clé de type inconnue de TOUTE la chaîne).
  final Map<String, ZGradientSpec>? typeColors;

  /// Glyphe de la tuile d'icône. `null` ⇒ [ZFlashcardCardReference.glyph].
  final IconData? icon;

  /// Nombre maximal de lignes de l'énoncé (2-3 en pratique). Défaut `3`.
  final int questionMaxLines;

  /// Créneau d'actions de fin de carte (menu contextuel de l'hôte, avec ses
  /// propres règles de droits — que le socle ignore). `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ carte non
  /// interactive (AD-45 — aucun `InkWell` inerte).
  final VoidCallback? onTap;

  /// Appui long (menu contextuel). `null` ⇒ capacité **ABSENTE** (AD-4).
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

  /// Hauteur FIXE de la carte (**CR-IFFD-57**, legacy `SizedBox(height: 200)`).
  ///
  /// Défaut : [ZFlashcardCardReference.cardHeight] (200) — c'est la hauteur
  /// fixe qui rend la grille et le rail **réguliers** (toutes les cartes d'une
  /// rangée à la même hauteur, quel que soit leur contenu). Passer **`null`
  /// explicitement** rend la hauteur **intrinsèque** (la carte suit son
  /// contenu). Sous des contraintes verticales **serrées** (cellule de grille
  /// à hauteur imposée), la contrainte du parent PRIME — jamais de
  /// débordement par construction.
  final double? height;

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

  /// Dégradé de l'axe TYPE — chaîne de résolution CR-IFFD-57 (cf. [typeColors]).
  ///
  /// `null` ⇒ clé de type inconnue de TOUTE la chaîne, OU [colorKey] explicite
  /// (l'identité prime) : les surfaces replient sur l'accent uni.
  ZGradientSpec? _typeSpec(BuildContext context) {
    final String typeName = card.type.name;
    // Préséance arbitrée (les DEUX axes posés ensemble — CR-IFFD-57) :
    // 1. [typeColors] EXPLICITE pour ce type : le paramètre SPÉCIFIQUE à la
    //    surface gagne toujours — même face à un [colorKey] explicite.
    final ZGradientSpec? explicit = typeColors?[typeName];
    if (explicit != null) return explicit;
    // 2. [colorKey] EXPLICITE (sans entrée [typeColors]) : choix d'identité de
    //    l'hôte — il prime les DÉFAUTS de l'axe type (jeton, seam, référence),
    //    ce qui préserve exactement le rendu v0.42-v0.45 de ces hôtes. Sans
    //    colorKey, les deux axes coïncident par construction (l'accent
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
    final ColorScheme scheme = material.colorScheme;
    final ZColorPair pair = _identityPair(context);
    final ZGradientSpec? spec = _typeSpec(context);
    // Couleur « primaire » du type : la PREMIÈRE couleur du dégradé (legacy :
    // `gradientColors[0]`), repli sur l'accent d'identité (chaîne totale).
    final Color primary = spec == null
        ? pair.color
        : (spec.gradient is LinearGradient
            ? (spec.gradient as LinearGradient).colors.first
            : pair.color);
    final Widget? tagsZone = _buildTagsZone(context, theme);

    // Ombre douce de référence — REPLI sous les jetons `cardShadow*`
    // (`ZStudyToolsItemCard.defaultShadow`), rôle `shadow`, opacité par
    // luminosité (0.06 clair / 0.2 sombre — legacy, scalaires de référence).
    final bool isDark = material.brightness == Brightness.dark;
    // Premier plan teinté LISIBLE (texte/glyphe) — cf. [zReadableTypeTint] :
    // la teinte brute mesurait 2,30:1 sur clair, sous le plancher AA.
    final Color readable = zReadableTypeTint(primary, isDark: isDark);
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
      // Chrome de référence CR-IFFD-57 (priorité paramètre > référence ; les
      // couleurs sont des RÔLES — le seul hex du dessin vit dans la référence
      // des dégradés, exception FR-26 encadrée).
      borderRadius: corner,
      borderSide: borderSide ??
          BorderSide(
            color: scheme.outline,
            width: ZFlashcardCardReference.borderWidth,
          ),
      color: backgroundColor ?? material.scaffoldBackgroundColor,
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
      // ② Tuile d'icône teintée par le type (15 %, rayon 8, glyphe teinté).
      leading: _buildIconTile(primary, readable),
      // ③ Zone de balises AU-DESSUS de l'énoncé (ordre de lecture de la
      // référence) — ABSENTE si vide sans appel à l'action (AD-4).
      aboveTitle: tagsZone,
      // ④ Énoncé, tronqué proprement sur 2-3 lignes.
      title: card.question,
      titleMaxLines: questionMaxLines,
      // ⑤ Pied : pastille de type — point dégradé + libellé, le type redit
      // **en TEXTE** (AD-13 : la couleur n'est jamais le seul canal).
      belowSubtitle: _buildTypePill(context, spec, primary, readable),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? card.question,
    );
    // CR-IFFD-57 (complément owner) — hauteur FIXE de référence (200,
    // legacy `SizedBox(height: 200)`) : c'est elle qui rend grille et rail
    // réguliers. `height: null` EXPLICITE ⇒ hauteur intrinsèque ; sous des
    // contraintes serrées (cellule de grille), la contrainte du parent prime
    // (comportement `SizedBox` du SDK — la carte ne déborde pas sa cellule).
    final double? fixedHeight = height;
    return fixedHeight == null
        ? cardWidget
        : SizedBox(height: fixedHeight, child: cardWidget);
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
        // 🔴 `heightFactor: 1` — MESURÉ, pas supposé : un `Align` sans facteur
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
  /// par le type, sur un fond teinté à 10 % (référence CR-IFFD-57).
  ///
  /// Le point est **décoratif et MUET** ([ExcludeSemantics]) : l'information
  /// est portée par le libellé texte, jamais par la couleur seule (AD-13).
  Widget _buildTypePill(
    BuildContext context,
    ZGradientSpec? spec,
    Color primary,
    Color readable,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // 🔴 `heightFactor: 1` — cf. la zone de balises : sans lui, l'`Align`
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
                    // 🔴 Taille depuis le thème (jamais un `fontSize:`
                    // littéral : a11y/`textScaler`) ; le premier plan est la
                    // teinte de type AJUSTÉE lisible ([zReadableTypeTint]) sur
                    // le fond teinté à 10 % — le legacy peignait la couleur
                    // brute, MESURÉE à 2,30:1 en clair (sous AA).
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

  /// Clé de la tuile d'icône de tête (testabilité — CR-IFFD-57).
  static const ValueKey<String> iconTileKey =
      ValueKey<String>('zDefaultFlashcardCard_iconTile');

  /// Clé du point de type de la pastille de pied (testabilité).
  ///
  /// ⚠️ CR-IFFD-57 : le point vit désormais DANS la pastille de pied (forme de
  /// référence) — il n'y a plus de pastille d'en-tête.
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
}
