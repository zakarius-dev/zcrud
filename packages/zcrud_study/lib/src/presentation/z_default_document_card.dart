/// `ZDefaultDocumentCard` — **carte de document PAR DÉFAUT** du socle
/// (CR-IFFD-48), avec **icône typée par format**.
///
/// ## La règle CR-48, et sa résolution appliquée ici
///
/// Quand le socle offre une fonctionnalité, il offre un rendu par défaut. Le
/// socle porte la **structure et les proportions** (tuile d'icône en tête,
/// titre, sous-titre, puce de format en texte) ; chaque **couleur et graisse**
/// s'exprime en **rôles** du `ColorScheme`/`TextTheme` de l'hôte — l'accent
/// passe par `zResolveColorKeyOrSlot` (paire `*Container`/`on*Container`),
/// les graisses par `titleSmall`/`bodySmall`/`labelSmall`. **Aucune constante
/// de couleur, aucun jeton nouveau n'a été nécessaire** (mesuré : les 5 slots
/// de `ZColorSlot` couvrent l'accent par format).
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
/// L'icône est résolue par [zResolveDocumentFormatIcon] : mapping **injecté**
/// ([formatIcons]) prioritaire, puis table par défaut **sensée**
/// ([zDefaultDocumentFormatIcons]), puis repli neutre. Un format nouveau
/// demain = une entrée de map chez l'hôte, **jamais une CR**.
///
/// ## Invariants
///
/// - **FR-26/NFR-S7** : aucun libellé en dur — « PDF » est un libellé VISIBLE,
///   il arrive par [formatLabel]. `null` ⇒ puce **absente** (AD-4).
/// - **AD-13** : l'information portée par l'icône et la couleur est **aussi**
///   en texte (la puce de format) **et** dans le libellé sémantique par défaut ;
///   insets/alignements directionnels ; la tuile d'icône est décorative
///   (`ExcludeSemantics`).
/// - **AD-2/SM-1** : `StatelessWidget` pur, aucun état, aucun controller.
/// - Composition : [ZStudyDocumentCard] (façade) → `ZStudyToolsItemCard` —
///   aucune carte réécrite.
///
/// ℹ️ Aucune enveloppe colorée sous du contenu d'HÔTE : les seules surfaces
/// teintées (tuile d'icône, puce de format) ne portent que du contenu rendu
/// par le socle, premier plan apparié appliqué directement —
/// `ZForegroundOverride` sans objet, aucun `merge` écrit dans ce fichier.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_study_document_card.dart';

/// Côté de la tuile d'icône de tête (dimension de LAYOUT — jamais une couleur).
const double kZDefaultDocumentIconTileSize = 40;

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

/// Résout la clé de format OPAQUE [formatKey] en glyphe — **totale** (AD-10).
///
/// Normalisation : minuscules, point d'extension retiré (`'.PDF'` → `'pdf'`).
/// Pour un type MIME (`'image/png'`), trois essais dans l'ordre : la forme
/// complète, le sous-type (`'png'`), la famille (`'image'`).
///
/// Chaîne : [icons] (injecté, prioritaire) → [zDefaultDocumentFormatIcons] →
/// [fallback]. Jamais `null`, jamais de throw.
IconData zResolveDocumentFormatIcon(
  String? formatKey, {
  Map<String, IconData>? icons,
  IconData fallback = zDefaultDocumentFallbackIcon,
}) {
  final String raw = (formatKey ?? '').trim().toLowerCase();
  if (raw.isEmpty) return fallback;
  final String noDot = raw.startsWith('.') ? raw.substring(1) : raw;
  final List<String> candidates = <String>[
    noDot,
    if (noDot.contains('/')) ...<String>[
      noDot.substring(noDot.indexOf('/') + 1),
      noDot.substring(0, noDot.indexOf('/')),
    ],
  ];
  for (final String candidate in candidates) {
    final IconData? injected = icons?[candidate];
    if (injected != null) return injected;
    final IconData? preset = zDefaultDocumentFormatIcons[candidate];
    if (preset != null) return preset;
  }
  return fallback;
}

/// Carte de document **par défaut** du socle — autonome, sur primitives
/// (CR-IFFD-48).
///
/// ```dart
/// ZDefaultDocumentCard(
///   title: doc.name,
///   subtitle: l10n.modifiedAt(doc.updatedAt),
///   formatKey: doc.mimeType,            // clé OPAQUE (mime, extension…)
///   formatLabel: l10n.formatPdf,        // libellé VISIBLE ⇒ injecté (FR-26)
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
    this.icon,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.titleMaxLines = 2,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  }) : assert(
          titleMaxLines > 0,
          'titleMaxLines doit être ≥ 1 (le titre est le contenu principal).',
        );

  /// Nom du document (déjà localisé/résolu par l'hôte) — **seule** entrée
  /// requise.
  final String title;

  /// Méta-information secondaire (date, taille…), déjà localisée. `null` ⇒
  /// **absente** de l'arbre (AD-4).
  final String? subtitle;

  /// Clé de format **OPAQUE** (extension `'pdf'`, MIME `'image/png'`…). Elle
  /// pilote l'icône typée ([zResolveDocumentFormatIcon]) **et**, à défaut de
  /// [colorKey], l'accent (stable : deux documents du même format portent le
  /// même accent). `null` ⇒ glyphe et accent de repli.
  final String? formatKey;

  /// Libellé de format **VISIBLE et LOCALISÉ**, injecté (« PDF », « Image »…)
  /// — jamais déduit de [formatKey] (le socle ne traduit pas, FR-26). `null` ⇒
  /// puce de format **absente** (AD-4) ; l'icône reste, décorative.
  final String? formatLabel;

  /// Mapping `clé de format → glyphe` **injecté**, prioritaire sur
  /// [zDefaultDocumentFormatIcons]. `null` ⇒ table par défaut seule.
  final Map<String, IconData>? formatIcons;

  /// Glyphe EXPLICITE de la tuile — court-circuite la résolution par format.
  /// `null` ⇒ [zResolveDocumentFormatIcon] sur [formatKey].
  final IconData? icon;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron `ZTagChips`).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ dérivée du
  /// **format** ([formatKey]) — stable par format, remap déterministe du
  /// kernel.
  final String? colorKey;

  /// Nombre maximal de lignes du titre. Défaut `2`.
  final int titleMaxLines;

  /// Créneau d'actions de fin de carte (menu de l'hôte). `null` ⇒ absent
  /// (AD-4).
  final Widget? trailing;

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
    final String? label = formatLabel;

    return ZStudyDocumentCard(
      // Tuile d'icône typée par format — DÉCORATIVE (l'info est en texte via
      // la puce de format et le libellé sémantique, AD-13).
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
      titleMaxLines: titleMaxLines,
      subtitle: subtitle,
      // Puce de format : le format redit **EN TEXTE**, fond d'accent + premier
      // plan APPARIÉ (contraste Material 3). `null` ⇒ ABSENTE (AD-4).
      metadata: label == null ? null : _buildFormatChip(context, theme, pair),
      actions: trailing,
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

  /// Clé de la puce de format (testabilité).
  static const ValueKey<String> formatChipKey =
      ValueKey<String>('zDefaultDocumentCard_formatChip');

  /// Clé du **texte** de format (testabilité — AD-13).
  static const ValueKey<String> formatLabelKey =
      ValueKey<String>('zDefaultDocumentCard_formatLabel');
}
