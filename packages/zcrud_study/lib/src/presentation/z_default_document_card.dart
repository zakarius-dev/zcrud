/// `ZDefaultDocumentCard` — carte de document par défaut du socle, au rendu
/// de référence.
///
/// ## Le défaut est le rendu de référence
///
/// Sans aucun réglage, la carte rend : tuile d'icône neutre (`surface`,
/// jetons `studyCardIconTile*`, référence 48 dp / rayon 12), glyphe
/// [zDefaultDocumentReferenceIcon] teinté par la couleur résolue du
/// format, badge d'extension en surimpression bas-fin (fond = couleur du
/// format, texte apparié inversé, rayon `studyCardBadgeRadius` repli `radiusS`),
/// et le chrome commun de [ZStudyCardReference] (rayon de carte 16, padding 12,
/// marge 4, liseré `outlineVariant` à 50 %, titre `titleMedium/w600/15` une
/// ligne, sous-titre `bodySmall`/`onSurfaceVariant`).
///
/// Un rendu antérieur (tuile colorée, glyphe apparié, puce de format en
/// [ZStudyDocumentCard.metadata]) reste atteignable par réglage :
/// [hierarchy] = [ZStudyCardHierarchy.tintedTile] (ou le jeton
/// `ZcrudTheme.studyCardHierarchy`) — restitution exacte gardée par test.
///
/// Priorité, partout : paramètre > jeton `studyCard*` > défaut-référence
/// (résolution centralisée dans [zStudyCardChromeOf] — jamais une constante
/// éparpillée ici).
///
/// ## La couleur par format est injectable, comme le glyphe
///
/// [formatColors] est le symétrique exact de [formatIcons] : l'hôte exprime sa
/// convention (« PDF rouge, tableur vert ») en paires injectées
/// ([ZColorPair]) — le socle ne fige jamais « rouge = pdf ». Sans entrée
/// injectée, la couleur reste le tirage de palette stable par format
/// (`remapColorKey(seedTitle: formatKey)`) — mais elle teinte le glyphe,
/// plus la tuile.
///
/// ## Pourquoi cette carte ne prend aucun type de domaine
///
/// Le modèle `ZStudyDocument` vit dans `zcrud_document`, qui n'est pas une
/// dépendance de `zcrud_study`. Une voie typée
/// `ZStudyToolsSectionSpec.documents(documents: List<ZStudyDocument>)`
/// exigerait donc une nouvelle arête — interdite ici (invariant AD-1). La
/// carte est donc autonome sur des primitives (`title`, `formatKey`,
/// `formatLabel`) : l'hôte projette son modèle en trois chaînes, le socle
/// dessine.
///
/// ## L'icône typée par format : un mapping ouvert, jamais un enum fermé
///
/// Le « format » est une clé opaque ([formatKey] : extension `'pdf'`, type
/// MIME `'image/png'`, peu importe — le socle normalise, ne classifie pas).
/// En hiérarchie de référence, le glyphe par défaut est unique
/// ([zDefaultDocumentReferenceIcon] — la différenciation par format passe par
/// la couleur et le badge d'extension) ; [icon] puis [formatIcons] priment.
/// En hiérarchie `tintedTile`, la résolution antérieure est conservée à
/// l'identique ([zResolveDocumentFormatIcon] : injecté →
/// [zDefaultDocumentFormatIcons] → repli).
///
/// ## Invariants
///
/// - Invariant FR-26 : aucun libellé en dur — « PDF » est un libellé visible,
///   il arrive par [formatLabel]. `null` ⇒ badge/puce absents (invariant AD-4).
/// - Invariant AD-13 : l'information portée par l'icône et la couleur est
///   aussi en texte (badge d'extension ou puce de format) et dans le libellé
///   sémantique par défaut ; insets/alignements directionnels ; la tuile
///   d'icône est décorative (`ExcludeSemantics`).
/// - Invariant AD-2 : `StatelessWidget` pur, aucun état, aucun controller.
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

/// Côté de la tuile d'icône en hiérarchie `tintedTile` (dimension de layout,
/// jamais une couleur). En hiérarchie de référence, le côté vient de
/// `studyCardIconTileSize` (repli [ZStudyCardReference.iconTileSize]).
const double kZDefaultDocumentIconTileSize = 40;

/// Glyphe unique du rendu de référence : la différenciation par
/// format passe par la couleur et le badge d'extension, pas par le glyphe.
const IconData zDefaultDocumentReferenceIcon = Icons.description_outlined;

/// Table par défaut `clé de format normalisée → glyphe` — sensée, pas
/// fermée : elle couvre les familles courantes, et tout hôte la complète ou
/// la remplace par [ZDefaultDocumentCard.formatIcons] (invariant AD-4 —
/// jamais un enum qui exigerait une évolution par format nouveau).
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

/// Glyphe de repli quand le format est inconnu ou absent (invariant AD-10 —
/// résolution totale, jamais un trou dans la tuile).
const IconData zDefaultDocumentFallbackIcon = Icons.insert_drive_file_outlined;

/// Candidats de résolution de la clé de format OPAQUE [formatKey], normalisés
/// (minuscules, point d'extension retiré ; un type MIME `'image/png'` produit
/// la forme complète, le sous-type `'png'`, la famille `'image'`).
///
/// Partagé par la résolution du glyphe ([zResolveDocumentFormatIcon]) et de la
/// couleur ([zLookupDocumentFormatColor]) : les deux portent la
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

/// Résout la clé de format opaque [formatKey] en glyphe — totale
/// (invariant AD-10).
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

/// Cherche une paire de couleurs injectée pour [formatKey] dans [colors]
/// (mêmes candidats normalisés que le glyphe, par symétrie glyphe/couleur).
/// `null` ⇒ aucune entrée injectée : l'appelant retombe sur
/// le tirage de palette stable par format — le socle ne fige aucune
/// convention `format → couleur` (invariant FR-26).
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

/// Carte de document par défaut du socle — autonome, sur primitives,
/// au rendu de référence.
///
/// ```dart
/// ZDefaultDocumentCard(
///   title: doc.name,
///   subtitle: l10n.modifiedAt(doc.updatedAt),
///   formatKey: doc.mimeType,            // clé opaque (mime, extension…)
///   formatLabel: l10n.formatPdf,        // libellé visible ⇒ injecté (invariant FR-26)
///   formatColors: myFormatPairs,        // convention de l'hôte
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
  /// absente de l'arbre (invariant AD-4).
  final String? subtitle;

  /// Clé de format opaque (extension `'pdf'`, MIME `'image/png'`…). Elle
  /// pilote le glyphe typé et, à défaut de [colorKey], la couleur du
  /// format (injectée par [formatColors], sinon tirage stable : deux documents
  /// du même format portent la même couleur). `null` ⇒ glyphe et accent de
  /// repli.
  final String? formatKey;

  /// Libellé de format visible et localisé, injecté (« PDF », « Image »…)
  /// — jamais déduit de [formatKey] (le socle ne traduit pas, invariant
  /// FR-26). `null` ⇒ badge d'extension (référence) ou puce de format
  /// (`tintedTile`) absents (invariant AD-4) ; le glyphe reste, décoratif.
  final String? formatLabel;

  /// Mapping `clé de format → glyphe` injecté, prioritaire sur le glyphe
  /// par défaut. `null` ⇒ défaut de la hiérarchie courante
  /// ([zDefaultDocumentReferenceIcon] en référence, table
  /// [zDefaultDocumentFormatIcons] en `tintedTile`).
  final Map<String, IconData>? formatIcons;

  /// Mapping `clé de format → paire de couleurs` injecté — symétrique exact
  /// de [formatIcons]. Mêmes candidats normalisés (extension,
  /// MIME complet, sous-type, famille). `null` ⇒ tirage de palette stable par
  /// format. [colorKey] (par item, plus spécifique) prime.
  final Map<String, ZColorPair>? formatColors;

  /// Glyphe EXPLICITE de la tuile — court-circuite toute résolution.
  final IconData? icon;

  /// Palette injectée bornant la clé d'accent (patron `ZTagChips`).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` opaque). `null` ⇒ couleur du
  /// format ([formatColors] injecté, sinon tirage stable).
  final String? colorKey;

  /// Hiérarchie tuile/glyphe. `null` ⇒ jeton
  /// `ZcrudTheme.studyCardHierarchy`, puis [ZStudyCardHierarchy.tintedGlyph]
  /// (le rendu de référence). [ZStudyCardHierarchy.tintedTile] restitue
  /// exactement le rendu antérieur.
  final ZStudyCardHierarchy? hierarchy;

  /// Nombre maximal de lignes du titre. `null` ⇒ défaut de la hiérarchie :
  /// `1` en référence ([ZStudyCardReference.titleMaxLines]), `2` en
  /// `tintedTile`.
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton `studyCardTitleStyle`, puis référence
  /// (`titleMedium/w600/15`) — en `tintedTile`, repli `titleSmall`.
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton `studyCardSubtitleStyle`, puis
  /// référence (`bodySmall`/`onSurfaceVariant`) — en `tintedTile`, repli
  /// `bodySmall`.
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton `studyCardContentPadding`, puis
  /// référence (12) — en `tintedTile`, repli `gapM`.
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton `studyCardMargin`, puis `CardTheme.margin`
  /// de l'hôte, puis référence (4) — en `tintedTile`, repli du rendu antérieur.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton `studyCardBorderSide`, puis référence
  /// (`outlineVariant` à 50 %) — en `tintedTile`, repli aucun.
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton `studyCardRadius`, puis référence (16) —
  /// en `tintedTile`, repli `radiusM`.
  final Radius? borderRadius;

  /// Créneau d'actions de fin de carte (menu de l'hôte). `null` ⇒ absent
  /// (invariant AD-4).
  final Widget? trailing;

  /// Indicateur de traitement en cours — relayé à la carte de base.
  /// Voir `ZStudyToolsItemCard.progress`.
  final Widget? progress;

  /// Largeur maximale du slot [progress]. Voir
  /// `ZStudyToolsItemCard.progressMaxWidth`.
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement. Voir
  /// `ZStudyToolsItemCard.hidesTrailingWhileBusy`.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` et [onLongPress] `null` ⇒ carte non
  /// interactive.
  final VoidCallback? onTap;

  /// Appui long (menu contextuel). `null` ⇒ capacité absente (invariant AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [subtitle] et [formatLabel] — l'information portée par l'icône/couleur
  /// est ainsi annoncée (invariant AD-13).
  final String? semanticLabel;

  ZColorPair _accent(BuildContext context) {
    // La couleur injectée par format prime sur le tirage, mais
    // jamais sur `colorKey` (réglage par item, plus spécifique).
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

  // ── Hiérarchie de référence (défaut) ───────────────────────────

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
    // Référence : glyphe unique par défaut ([zDefaultDocumentReferenceIcon] —
    // la différenciation par format passe par la couleur et le badge). `icon`
    // puis `formatIcons` injectés priment (invariant AD-4 : mapping ouvert) ;
    // la table [zDefaultDocumentFormatIcons] ne s'applique pas ici — elle
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
      // Tuile neutre, glyphe teinté par la couleur du format, badge
      // d'extension en surimpression — décoratif (l'info est en texte dans le
      // badge et dans le libellé sémantique, invariant AD-13).
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
                // Surimpression bas-fin — géométrie mesurée : le badge est
                // épinglé au coin bas-fin du glyphe centré, donc dans la
                // tuile, à `(tuile − glyphe) / 2` du bord. Jamais un débord.
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
      // L'écart tuile→titre (16) et l'élévation (0) de
      // la référence sont résolus par le chrome. Ils ne sont pas écrits en
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
  /// apparié (« inversé »), rayon `studyCardBadgeRadius` (repli `radiusS`).
  Widget _buildExtensionBadge(
    BuildContext context,
    ZStudyCardChrome chrome,
    ZColorPair pair,
    String label,
  ) {
    return DecoratedBox(
      key: extensionBadgeKey,
      decoration: BoxDecoration(
        // Fond = couleur du format ; texte apparié (« inversé ») — invariant
        // AD-13 : l'information couleur est aussi en texte, ici même.
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
          // Métriques fixes (8, bold) sur `labelSmall` : la famille vient de
          // l'hôte, les métriques de la référence (invariant FR-26 : pas une
          // couleur).
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

  // ── Hiérarchie `tintedTile` — restitution exacte du rendu antérieur ──────
  //
  // Ne pas « moderniser » ce chemin : il est gardé par un test de
  // restitution aux valeurs mesurées du rendu antérieur (géométrie et
  // couleurs) — un hôte qui a adopté ce rendu le retrouve à l'identique.
  // Les paramètres de chrome restent non inertes (invariant AD-4) : fournis,
  // ils s'appliquent ; nuls, le rendu antérieur est littéral.

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

  /// Clé du texte de format `tintedTile` (testabilité — invariant AD-13).
  static const ValueKey<String> formatLabelKey =
      ValueKey<String>('zDefaultDocumentCard_formatLabel');

  /// Clé du badge d'extension en surimpression (référence — testabilité).
  static const ValueKey<String> extensionBadgeKey =
      ValueKey<String>('zDefaultDocumentCard_extensionBadge');

  /// Clé du texte du badge d'extension (testabilité — invariant AD-13).
  static const ValueKey<String> extensionLabelKey =
      ValueKey<String>('zDefaultDocumentCard_extensionLabel');
}
