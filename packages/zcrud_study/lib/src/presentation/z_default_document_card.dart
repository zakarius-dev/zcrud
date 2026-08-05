/// `ZDefaultDocumentCard` — **carte de document PAR DÉFAUT** du socle
/// (CR-IFFD-48, rendu de référence CR-IFFD-55/56).
///
/// ## Le DÉFAUT est le rendu de RÉFÉRENCE (CR-IFFD-56)
///
/// Gouvernance CR-41 : le design d'IFFD est la référence visuelle du socle.
/// Sans aucun réglage, la carte rend : tuile d'icône **NEUTRE** (`surface`,
/// jetons `studyCardIconTile*`, référence 48 dp / rayon 12), glyphe
/// [zDefaultDocumentReferenceIcon] **TEINTÉ par la couleur résolue du
/// format**, **badge d'extension en surimpression** bas-fin (fond = couleur du
/// format, texte apparié inversé, rayon `studyCardBadgeRadius` repli `radiusS`),
/// et le chrome commun de [ZStudyCardReference] (rayon de carte 16, padding 12,
/// marge 4, liseré `outlineVariant` à 50 %, titre `titleMedium/w600/15` une
/// ligne, sous-titre `bodySmall`/`onSurfaceVariant`).
///
/// L'ancien rendu v0.43.0 (tuile colorée, glyphe apparié, puce de format en
/// [ZStudyDocumentCard.metadata]) reste **atteignable par réglage** :
/// [hierarchy] `=` [ZStudyCardHierarchy.tintedTile] (ou le jeton
/// `ZcrudTheme.studyCardHierarchy`) — restitution EXACTE gardée par test.
///
/// Priorité, partout : **paramètre > jeton `studyCard*` > défaut-référence**
/// (résolution centralisée dans [zStudyCardChromeOf] — jamais une constante
/// éparpillée ici).
///
/// ## La COULEUR par format est injectable, comme le glyphe (CR-IFFD-55)
///
/// [formatColors] est le symétrique exact de [formatIcons] : l'hôte exprime sa
/// convention (« PDF rouge, tableur vert ») en **paires injectées**
/// ([ZColorPair]) — le socle ne fige jamais « rouge = pdf ». Sans entrée
/// injectée, la couleur reste le tirage de palette **stable par format**
/// (`remapColorKey(seedTitle: formatKey)`) — mais elle teinte désormais le
/// GLYPHE, plus la tuile.
///
/// ## 🔴 Pourquoi cette carte ne prend AUCUN type de domaine
///
/// Le modèle `ZStudyDocument` vit dans `zcrud_document`, qui n'est **pas** une
/// dépendance de `zcrud_study` (pubspec : « AUCUN autre satellite lourd
/// (`zcrud_note`/`zcrud_document`) »). Une voie typée
/// `ZStudyToolsSectionSpec.documents(documents: List<ZStudyDocument>)`
/// exigerait donc une **nouvelle arête** — interdite ici (AD-1). La carte est
/// donc **autonome sur des primitives** (`title`, `formatKey`, `formatLabel`) :
/// l'hôte projette son modèle en trois chaînes, le socle dessine.
///
/// ## L'icône typée par format : un MAPPING OUVERT, jamais un enum fermé (AD-4)
///
/// Le « format » est une **clé opaque** ([formatKey] : extension `'pdf'`, type
/// MIME `'image/png'`, peu importe — le socle normalise, ne classifie pas).
/// En hiérarchie de référence, le glyphe par défaut est UNIQUE
/// ([zDefaultDocumentReferenceIcon] — la différenciation par format passe par
/// la COULEUR et le badge d'extension, comme chez IFFD) ; [icon] puis
/// [formatIcons] priment. En hiérarchie `tintedTile`, la résolution v0.43.0
/// est conservée à l'identique ([zResolveDocumentFormatIcon] : injecté →
/// [zDefaultDocumentFormatIcons] → repli).
///
/// ## Invariants
///
/// - **FR-26/NFR-S7** : aucun libellé en dur — « PDF » est un libellé VISIBLE,
///   il arrive par [formatLabel]. `null` ⇒ badge/puce **absents** (AD-4).
/// - **AD-13** : l'information portée par l'icône et la couleur est **aussi**
///   en texte (badge d'extension ou puce de format) **et** dans le libellé
///   sémantique par défaut ; insets/alignements directionnels ; la tuile
///   d'icône est décorative (`ExcludeSemantics`).
/// - **AD-2/SM-1** : `StatelessWidget` pur, aucun état, aucun controller.
/// - Composition : [ZStudyDocumentCard] (façade) → `ZStudyToolsItemCard` —
///   aucune carte réécrite.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZStudyCardHierarchy, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_study_card_reference.dart';
import 'z_study_document_card.dart';

/// Côté de la tuile d'icône en hiérarchie `tintedTile` (rendu v0.43.0 —
/// dimension de LAYOUT, jamais une couleur). En hiérarchie de référence, le
/// côté vient de `studyCardIconTileSize` (repli
/// [ZStudyCardReference.iconTileSize]).
const double kZDefaultDocumentIconTileSize = 40;

/// Glyphe UNIQUE du rendu de référence (CR-IFFD-56) : la différenciation par
/// format passe par la couleur et le badge d'extension, pas par le glyphe.
const IconData zDefaultDocumentReferenceIcon = Icons.description_outlined;

/// Table PAR DÉFAUT `clé de format normalisée → glyphe` — **sensée, pas
/// fermée** : elle couvre les familles courantes, et tout hôte la complète ou
/// la remplace par [ZDefaultDocumentCard.formatIcons] (AD-4 — jamais un enum
/// qui exigerait une CR par format nouveau).
///
/// Les clés sont **minuscules, sans point** ; [zResolveDocumentFormatIcon]
/// normalise l'entrée (`'.PDF'`, `'application/pdf'`, `'image/png'`…).
const Map<String, IconData> zDefaultDocumentFormatIcons = <String, IconData>{
  'pdf': Icons.picture_as_pdf_outlined,
  'image': Icons.image_outlined,
  'png': Icons.image_outlined,
  'jpg': Icons.image_outlined,
  'jpeg': Icons.image_outlined,
  'gif': Icons.image_outlined,
  'webp': Icons.image_outlined,
  'svg': Icons.image_outlined,
  'text': Icons.description_outlined,
  'txt': Icons.description_outlined,
  'md': Icons.description_outlined,
  'doc': Icons.description_outlined,
  'docx': Icons.description_outlined,
  'rtf': Icons.description_outlined,
  'audio': Icons.audiotrack_outlined,
  'mp3': Icons.audiotrack_outlined,
  'wav': Icons.audiotrack_outlined,
  'video': Icons.videocam_outlined,
  'mp4': Icons.videocam_outlined,
  'csv': Icons.table_chart_outlined,
  'xls': Icons.table_chart_outlined,
  'xlsx': Icons.table_chart_outlined,
  'ppt': Icons.co_present_outlined,
  'pptx': Icons.co_present_outlined,
  'html': Icons.language_outlined,
  'url': Icons.link_outlined,
  'zip': Icons.folder_zip_outlined,
};

/// Glyphe de repli quand le format est inconnu ou absent (AD-10 — résolution
/// TOTALE, jamais un trou dans la tuile).
const IconData zDefaultDocumentFallbackIcon = Icons.insert_drive_file_outlined;

/// Candidats de résolution de la clé de format OPAQUE [formatKey], normalisés
/// (minuscules, point d'extension retiré ; un type MIME `'image/png'` produit
/// la forme complète, le sous-type `'png'`, la famille `'image'`).
///
/// Partagé par la résolution du GLYPHE ([zResolveDocumentFormatIcon]) et de la
/// COULEUR ([zLookupDocumentFormatColor]) — CR-IFFD-55 : les deux portent la
/// même information, ils se résolvent par la même normalisation.
List<String> zDocumentFormatKeyCandidates(String? formatKey) {
  final String raw = (formatKey ?? '').trim().toLowerCase();
  if (raw.isEmpty) return const <String>[];
  final String noDot = raw.startsWith('.') ? raw.substring(1) : raw;
  return <String>[
    noDot,
    if (noDot.contains('/')) ...<String>[
      noDot.substring(noDot.indexOf('/') + 1),
      noDot.substring(0, noDot.indexOf('/')),
    ],
  ];
}

/// Résout la clé de format OPAQUE [formatKey] en glyphe — **totale** (AD-10).
///
/// Chaîne : [icons] (injecté, prioritaire) → [zDefaultDocumentFormatIcons] →
/// [fallback]. Jamais `null`, jamais de throw.
IconData zResolveDocumentFormatIcon(
  String? formatKey, {
  Map<String, IconData>? icons,
  IconData fallback = zDefaultDocumentFallbackIcon,
}) {
  for (final String candidate in zDocumentFormatKeyCandidates(formatKey)) {
    final IconData? injected = icons?[candidate];
    if (injected != null) return injected;
    final IconData? preset = zDefaultDocumentFormatIcons[candidate];
    if (preset != null) return preset;
  }
  return fallback;
}

/// Cherche une paire de couleurs **INJECTÉE** pour [formatKey] dans [colors]
/// (mêmes candidats normalisés que le glyphe — CR-IFFD-55, symétrie
/// glyphe/couleur). `null` ⇒ aucune entrée injectée : l'appelant retombe sur
/// le tirage de palette stable par format — le socle ne fige **aucune**
/// convention `format → couleur` (FR-26/CR-48).
ZColorPair? zLookupDocumentFormatColor(
  String? formatKey,
  Map<String, ZColorPair>? colors,
) {
  if (colors == null) return null;
  for (final String candidate in zDocumentFormatKeyCandidates(formatKey)) {
    final ZColorPair? injected = colors[candidate];
    if (injected != null) return injected;
  }
  return null;
}

/// Carte de document **par défaut** du socle — autonome, sur primitives
/// (CR-IFFD-48), au rendu de référence (CR-IFFD-56).
///
/// ```dart
/// ZDefaultDocumentCard(
///   title: doc.name,
///   subtitle: l10n.modifiedAt(doc.updatedAt),
///   formatKey: doc.mimeType,            // clé OPAQUE (mime, extension…)
///   formatLabel: l10n.formatPdf,        // libellé VISIBLE ⇒ injecté (FR-26)
///   formatColors: myFormatPairs,        // convention de l'hôte (CR-55)
///   onTap: () => open(doc),
/// )
/// ```
class ZDefaultDocumentCard extends StatelessWidget {
  /// Construit la carte ; seul [title] est requis.
  const ZDefaultDocumentCard({
    required this.title,
    this.subtitle,
    this.formatKey,
    this.formatLabel,
    this.formatIcons,
    this.formatColors,
    this.icon,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.hierarchy,
    this.titleMaxLines,
    this.titleStyle,
    this.subtitleStyle,
    this.contentPadding,
    this.margin,
    this.borderSide,
    this.borderRadius,
    this.trailing,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  }) : assert(
          titleMaxLines == null || titleMaxLines > 0,
          'titleMaxLines doit être ≥ 1 (le titre est le contenu principal).',
        );

  /// Nom du document (déjà localisé/résolu par l'hôte) — **seule** entrée
  /// requise.
  final String title;

  /// Méta-information secondaire (date, taille…), déjà localisée. `null` ⇒
  /// **absente** de l'arbre (AD-4).
  final String? subtitle;

  /// Clé de format **OPAQUE** (extension `'pdf'`, MIME `'image/png'`…). Elle
  /// pilote le glyphe typé **et**, à défaut de [colorKey], la couleur du
  /// format (injectée par [formatColors], sinon tirage stable : deux documents
  /// du même format portent la même couleur). `null` ⇒ glyphe et accent de
  /// repli.
  final String? formatKey;

  /// Libellé de format **VISIBLE et LOCALISÉ**, injecté (« PDF », « Image »…)
  /// — jamais déduit de [formatKey] (le socle ne traduit pas, FR-26). `null` ⇒
  /// badge d'extension (référence) ou puce de format (`tintedTile`)
  /// **absents** (AD-4) ; le glyphe reste, décoratif.
  final String? formatLabel;

  /// Mapping `clé de format → glyphe` **injecté**, prioritaire sur le glyphe
  /// par défaut. `null` ⇒ défaut de la hiérarchie courante
  /// ([zDefaultDocumentReferenceIcon] en référence, table
  /// [zDefaultDocumentFormatIcons] en `tintedTile`).
  final Map<String, IconData>? formatIcons;

  /// Mapping `clé de format → paire de couleurs` **injecté** (CR-IFFD-55) —
  /// symétrique exact de [formatIcons]. Mêmes candidats normalisés (extension,
  /// MIME complet, sous-type, famille). `null` ⇒ tirage de palette stable par
  /// format. [colorKey] (par item, plus spécifique) prime.
  final Map<String, ZColorPair>? formatColors;

  /// Glyphe EXPLICITE de la tuile — court-circuite toute résolution.
  final IconData? icon;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron `ZTagChips`).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ couleur du
  /// **format** ([formatColors] injecté, sinon tirage stable).
  final String? colorKey;

  /// Hiérarchie tuile/glyphe (CR-IFFD-56). `null` ⇒ jeton
  /// `ZcrudTheme.studyCardHierarchy`, puis [ZStudyCardHierarchy.tintedGlyph]
  /// (le rendu de RÉFÉRENCE). [ZStudyCardHierarchy.tintedTile] restitue
  /// exactement le rendu v0.43.0.
  final ZStudyCardHierarchy? hierarchy;

  /// Nombre maximal de lignes du titre. `null` ⇒ défaut de la hiérarchie :
  /// `1` en référence ([ZStudyCardReference.titleMaxLines]), `2` en
  /// `tintedTile` (v0.43.0).
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton `studyCardTitleStyle`, puis référence
  /// (`titleMedium/w600/15`) — en `tintedTile`, repli v0.43.0 (`titleSmall`).
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton `studyCardSubtitleStyle`, puis
  /// référence (`bodySmall`/`onSurfaceVariant`) — en `tintedTile`, repli
  /// v0.43.0 (`bodySmall`).
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton `studyCardContentPadding`, puis
  /// référence (12) — en `tintedTile`, repli v0.43.0 (`gapM`).
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton `studyCardMargin`, puis `CardTheme.margin`
  /// de l'hôte, puis référence (4) — en `tintedTile`, repli v0.43.0.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton `studyCardBorderSide`, puis référence
  /// (`outlineVariant` à 50 %) — en `tintedTile`, repli v0.43.0 (aucun).
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton `studyCardRadius`, puis référence (16) —
  /// en `tintedTile`, repli v0.43.0 (`radiusM`).
  final Radius? borderRadius;

  /// Créneau d'actions de fin de carte (menu de l'hôte). `null` ⇒ absent
  /// (AD-4).
  final Widget? trailing;

  /// Indicateur de traitement en cours — **relayé** à la carte de base
  /// (CR-IFFD-56, « non mesuré » n°2 : le repli par item des hôtes n'est plus
  /// nécessaire). Voir `ZStudyToolsItemCard.progress`.
  final Widget? progress;

  /// Largeur maximale du slot [progress]. Voir
  /// `ZStudyToolsItemCard.progressMaxWidth`.
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement. Voir
  /// `ZStudyToolsItemCard.hidesTrailingWhileBusy`.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ carte non
  /// interactive (AD-45).
  final VoidCallback? onTap;

  /// Appui long (menu contextuel). `null` ⇒ capacité **ABSENTE** (AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [subtitle] et [formatLabel] — l'information portée par l'icône/couleur
  /// est ainsi **annoncée** (AD-13).
  final String? semanticLabel;

  ZColorPair _accent(BuildContext context) {
    // CR-IFFD-55 — la couleur injectée par FORMAT prime sur le tirage, mais
    // JAMAIS sur `colorKey` (réglage par item, plus spécifique).
    if (colorKey == null) {
      final ZColorPair? injected =
          zLookupDocumentFormatColor(formatKey, formatColors);
      if (injected != null) return injected;
    }
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      // Graine STABLE : le format (clé opaque), jamais l'identité de l'item.
      seedTitle: formatKey ?? 'document',
    );
    return zResolveColorKeyOrSlot(context, key, slotIndex: palette.indexOf(key));
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZColorPair pair = _accent(context);
    final ZStudyCardHierarchy effective = hierarchy ??
        theme.studyCardHierarchy ??
        ZStudyCardHierarchy.tintedGlyph;
    if (effective == ZStudyCardHierarchy.tintedTile) {
      return _buildTintedTile(context, theme, pair);
    }
    return _buildReference(context, theme, pair);
  }

  // ── Hiérarchie de RÉFÉRENCE (défaut CR-IFFD-56) ───────────────────────────

  Widget _buildReference(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) {
    final ZStudyCardChrome chrome = zStudyCardChromeOf(
      context,
      borderSide: borderSide,
      borderRadius: borderRadius,
      contentPadding: contentPadding,
      margin: margin,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
    final String? label = formatLabel;
    // Référence : glyphe UNIQUE par défaut ([zDefaultDocumentReferenceIcon] —
    // la différenciation par format passe par la COULEUR et le badge). `icon`
    // puis `formatIcons` INJECTÉS priment (AD-4 : mapping ouvert) ; la table
    // v0.43.0 [zDefaultDocumentFormatIcons] ne s'applique PAS ici — elle
    // rendrait `picture_as_pdf` là où la référence rend le glyphe unique.
    IconData? injected;
    final Map<String, IconData>? injectedIcons = formatIcons;
    if (injectedIcons != null) {
      for (final String candidate in zDocumentFormatKeyCandidates(formatKey)) {
        injected = injectedIcons[candidate];
        if (injected != null) break;
      }
    }
    final IconData glyph = icon ?? injected ?? zDefaultDocumentReferenceIcon;

    return ZStudyDocumentCard(
      // Tuile NEUTRE, glyphe TEINTÉ par la couleur du format, badge
      // d'extension en surimpression — DÉCORATIF (l'info est en texte dans le
      // badge et dans le libellé sémantique, AD-13).
      leading: ExcludeSemantics(
        child: SizedBox(
          key: iconTileKey,
          width: chrome.iconTileSize,
          height: chrome.iconTileSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chrome.tileColor,
                    borderRadius: BorderRadius.all(chrome.iconTileRadius),
                  ),
                  child: Center(
                    child: Icon(
                      glyph,
                      color: pair.color,
                      size: chrome.glyphSize,
                    ),
                  ),
                ),
              ),
              if (label != null)
                // Surimpression bas-fin — géométrie LEGACY mesurée
                // (`_iconeDocumentLegacy`) : le badge est épinglé au coin
                // bas-fin du GLYPHE centré, donc DANS la tuile, à
                // `(tuile − glyphe) / 2` du bord. Jamais un débord.
                PositionedDirectional(
                  bottom: (chrome.iconTileSize - chrome.glyphSize) / 2,
                  end: (chrome.iconTileSize - chrome.glyphSize) / 2,
                  child: _buildExtensionBadge(context, chrome, pair, label),
                ),
            ],
          ),
        ),
      ),
      title: title,
      titleMaxLines: titleMaxLines ?? ZStudyCardReference.titleMaxLines,
      titleStyle: chrome.titleStyle,
      subtitle: subtitle,
      subtitleStyle: chrome.subtitleStyle,
      contentPadding: chrome.contentPadding,
      margin: chrome.margin,
      borderSide: chrome.borderSide,
      borderRadius: chrome.borderRadius,
      // CR-IFFD-61 ①/② — l'écart tuile→titre (16) et l'élévation (0) de
      // la RÉFÉRENCE, résolus par le chrome. Ils ne sont pas écrits en
      // dur dans la primitive de base : celle-ci garde `gapM` et
      // l'élévation du `CardTheme` pour ses hôtes directs.
      leadingGap: chrome.leadingGap,
      elevation: chrome.elevation,
      actions: trailing,
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel,
    );
  }

  /// Badge d'extension de la référence : fond = couleur du format, texte
  /// APPARIÉ (« inversé »), rayon `studyCardBadgeRadius` (repli `radiusS`).
  Widget _buildExtensionBadge(
    BuildContext context,
    ZStudyCardChrome chrome,
    ZColorPair pair,
    String label,
  ) {
    return DecoratedBox(
      key: extensionBadgeKey,
      decoration: BoxDecoration(
        // Fond = couleur du format ; texte APPARIÉ (« inversé ») — AD-13 :
        // l'information couleur est AUSSI en texte, ici même.
        color: pair.color,
        borderRadius: BorderRadius.all(chrome.badgeRadius),
      ),
      child: Padding(
        padding: ZStudyCardReference.badgePadding,
        child: Text(
          label,
          key: extensionLabelKey,
          textAlign: TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Métriques LEGACY (8, bold) sur `labelSmall` : la FAMILLE vient de
          // l'hôte, les métriques de la référence (FR-26 : pas une couleur).
          style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
              .copyWith(
                color: pair.onColor,
                fontSize: ZStudyCardReference.badgeFontSize,
                fontWeight: ZStudyCardReference.badgeFontWeight,
              ),
        ),
      ),
    );
  }

  // ── Hiérarchie `tintedTile` — restitution EXACTE du rendu v0.43.0 ─────────
  //
  // 🔴 NE PAS « moderniser » ce chemin : il est gardé par un test de
  // restitution aux valeurs POMPÉES depuis v0.43.0 (géométrie et couleurs
  // mesurées) — un hôte qui a adopté ce rendu le retrouve à l'identique.
  // Les paramètres de chrome restent NON-inertes (AD-4) : fournis, ils
  // s'appliquent ; nuls, le rendu v0.43.0 est littéral.

  Widget _buildTintedTile(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) {
    final String? label = formatLabel;
    return ZStudyDocumentCard(
      leading: ExcludeSemantics(
        child: SizedBox(
          key: iconTileKey,
          width: kZDefaultDocumentIconTileSize,
          height: kZDefaultDocumentIconTileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pair.color,
              borderRadius: BorderRadius.all(theme.radiusM),
            ),
            child: Center(
              child: Icon(
                icon ?? zResolveDocumentFormatIcon(formatKey, icons: formatIcons),
                color: pair.onColor,
              ),
            ),
          ),
        ),
      ),
      title: title,
      titleMaxLines: titleMaxLines ?? 2,
      titleStyle: titleStyle,
      subtitle: subtitle,
      subtitleStyle: subtitleStyle,
      contentPadding: contentPadding,
      margin: margin,
      borderSide: borderSide,
      borderRadius: borderRadius,
      metadata: label == null ? null : _buildFormatChip(context, theme, pair),
      actions: trailing,
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel,
    );
  }

  String get _defaultSemanticLabel {
    final StringBuffer buffer = StringBuffer(title);
    final String? sub = subtitle;
    if (sub != null) buffer.write(', $sub');
    final String? label = formatLabel;
    if (label != null) buffer.write(', $label');
    return buffer.toString();
  }

  Widget _buildFormatChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) =>
      DecoratedBox(
        key: formatChipKey,
        decoration: BoxDecoration(
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapS,
            vertical: theme.gapS,
          ),
          child: Text(
            formatLabel!,
            key: formatLabelKey,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Taille depuis le thème (a11y/`textScaler`) ; couleur = premier
            // plan APPARIÉ au fond réellement peint.
            style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                .copyWith(color: pair.onColor),
          ),
        ),
      );

  /// Clé de la tuile d'icône (testabilité).
  static const ValueKey<String> iconTileKey =
      ValueKey<String>('zDefaultDocumentCard_iconTile');

  /// Clé de la puce de format `tintedTile` (testabilité).
  static const ValueKey<String> formatChipKey =
      ValueKey<String>('zDefaultDocumentCard_formatChip');

  /// Clé du **texte** de format `tintedTile` (testabilité — AD-13).
  static const ValueKey<String> formatLabelKey =
      ValueKey<String>('zDefaultDocumentCard_formatLabel');

  /// Clé du badge d'extension en surimpression (référence — testabilité).
  static const ValueKey<String> extensionBadgeKey =
      ValueKey<String>('zDefaultDocumentCard_extensionBadge');

  /// Clé du **texte** du badge d'extension (testabilité — AD-13).
  static const ValueKey<String> extensionLabelKey =
      ValueKey<String>('zDefaultDocumentCard_extensionLabel');
}
