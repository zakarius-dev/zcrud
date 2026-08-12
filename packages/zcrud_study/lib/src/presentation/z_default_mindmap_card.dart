/// `ZDefaultMindmapCard` — carte de carte mentale par défaut du socle, au
/// rendu de référence.
///
/// ## Le défaut est le rendu de référence
///
/// Sans aucun réglage : tuile d'icône neutre (`surface`, jetons
/// `studyCardIconTile*`), glyphe [zDefaultMindmapReferenceIcon] neutre
/// (`onSurfaceVariant`), et le chrome commun de [ZStudyCardReference] (rayon
/// 16, padding 12, marge 4, liseré `outlineVariant` à 50 %, titre
/// `titleMedium/w600/15` une ligne, sous-titre `bodySmall`/`onSurfaceVariant`).
/// Le compteur de nœuds reste une option ([nodeCountLabel] — `null` ⇒
/// puce absente, invariants AD-4/FR-26) : il se rend dans les deux
/// hiérarchies quand le libellé est injecté.
///
/// Un rendu antérieur (tuile colorée + vignette structurelle dessinée
/// depuis [ZMindmap.nodes]) reste atteignable par réglage : [hierarchy]
/// = [ZStudyCardHierarchy.tintedTile] (ou le jeton
/// `ZcrudTheme.studyCardHierarchy`) — restitution exacte gardée par test.
///
/// Priorité, partout : paramètre > jeton `studyCard*` > défaut-référence
/// (résolution centralisée dans [zStudyCardChromeOf]).
///
/// La voie typée est possible ici : le modèle [ZMindmap] vit dans
/// `zcrud_mindmap`, dépendance déjà déclarée de `zcrud_study` — aucune arête
/// nouvelle (invariant AD-1). Le pendant qui porte les données est
/// `ZStudyToolsSectionSpec.mindmaps(maps:)`.
///
/// ## La vignette (`tintedTile`) : structurelle, pas un rendu du graphe
///
/// Un vrai rendu `ZMindmapView` par carte serait un moteur de graphe complet
/// par cellule de rail — à rebours de la réactivité granulaire attendue
/// (invariant AD-2). La vignette est un croquis déterministe dessiné depuis
/// la structure réelle ([ZMindmap.nodes]) : un nœud central + jusqu'à
/// [kZDefaultMindmapVignetteMaxSatellites] satellites reliés, disposés
/// radialement (donc neutres en RTL). Elle est décorative
/// (`ExcludeSemantics`) : l'information (nombre de nœuds) est redite en
/// texte par la puce [nodeCountLabel] (invariant AD-13) — sans libellé
/// injecté, la puce est absente (le socle ne traduit jamais, invariant
/// FR-26).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZStudyCardHierarchy, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmap, ZMindmapNode;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_study_card_reference.dart';
import 'z_study_tools_item_card.dart';

/// Côté de la vignette en hiérarchie `tintedTile` (dimension de layout,
/// jamais une couleur). En référence, le côté vient de
/// `studyCardIconTileSize` (repli [ZStudyCardReference.iconTileSize]).
const double kZDefaultMindmapVignetteSize = 40;

/// Glyphe du rendu de référence — neutre, surchargable par
/// [ZDefaultMindmapCard.icon].
const IconData zDefaultMindmapReferenceIcon = Icons.hub_outlined;

/// Nombre maximal de satellites dessinés dans la vignette (croquis, pas
/// inventaire — l'inventaire exact passe par [ZDefaultMindmapCard.nodeCountLabel]).
const int kZDefaultMindmapVignetteMaxSatellites = 6;

/// Nombre total de nœuds de la forêt [nodes] (racines comprises) — parcours
/// itératif défensif (aucune récursion non bornée sur pile).
int zMindmapNodeCount(List<ZMindmapNode> nodes) {
  int count = 0;
  final List<ZMindmapNode> stack = List<ZMindmapNode>.of(nodes);
  while (stack.isNotEmpty) {
    final ZMindmapNode node = stack.removeLast();
    count++;
    stack.addAll(node.children);
  }
  return count;
}

/// Carte de carte mentale par défaut du socle, au rendu de référence.
///
/// ```dart
/// ZDefaultMindmapCard(
///   map: mindmap,
///   untitledLabel: l10n.untitledMindmap,     // libellé visible ⇒ injecté
///   nodeCountLabel: (n) => l10n.nodeCount(n), // option (invariant AD-4)
///   onTap: () => open(mindmap),
/// )
/// ```
class ZDefaultMindmapCard extends StatelessWidget {
  /// Construit la carte ; seule [map] est requise.
  const ZDefaultMindmapCard({
    required this.map,
    this.untitledLabel,
    this.nodeCountLabel,
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

  /// Carte mentale rendue — seule entrée requise. Le dessin lit `title`,
  /// `description`, `nodes` et `id`.
  final ZMindmap map;

  /// Libellé localisé injecté pour une carte au titre vide. `null` ⇒ le
  /// titre vide est rendu tel quel (le socle ne traduit jamais en dur).
  final String? untitledLabel;

  /// Fabrique le libellé localisé du nombre de nœuds (« 12 nœuds ») —
  /// option. `null` ⇒ puce absente (invariant AD-4) — jamais un
  /// nombre nu non localisé.
  final String Function(int nodeCount)? nodeCountLabel;

  /// Glyphe de la tuile (référence). `null` ⇒ [zDefaultMindmapReferenceIcon].
  /// Ignoré en `tintedTile` (le rendu antérieur dessine la vignette
  /// structurelle — restitution littérale).
  final IconData? icon;

  /// Palette injectée bornant la clé d'accent.
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` opaque). `null` ⇒ dérivée de
  /// l'identité de la carte (`map.id`, repli titre) — stable, remap
  /// déterministe du kernel.
  final String? colorKey;

  /// Hiérarchie. `null` ⇒ jeton `ZcrudTheme.studyCardHierarchy`,
  /// puis [ZStudyCardHierarchy.tintedGlyph] (référence).
  /// [ZStudyCardHierarchy.tintedTile] restitue exactement le rendu
  /// antérieur (vignette).
  final ZStudyCardHierarchy? hierarchy;

  /// Nombre maximal de lignes du titre. `null` ⇒ défaut de la hiérarchie :
  /// `1` en référence, `2` en `tintedTile`.
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton `studyCardTitleStyle`, puis référence —
  /// en `tintedTile`, repli `titleSmall`.
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton `studyCardSubtitleStyle`, puis
  /// référence — en `tintedTile`, repli `bodySmall`.
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton, puis référence (12) — en `tintedTile`,
  /// repli `gapM`.
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton, puis `CardTheme.margin`, puis référence
  /// (4) — en `tintedTile`, repli du rendu antérieur.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton, puis référence (`outlineVariant` à 50 %) — en
  /// `tintedTile`, repli aucun.
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton, puis référence (16) — en `tintedTile`,
  /// repli `radiusM`.
  final Radius? borderRadius;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (invariant AD-4).
  final Widget? trailing;

  /// Indicateur de traitement — relayé à la carte de base.
  final Widget? progress;

  /// Largeur maximale du slot [progress].
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` et [onLongPress] `null` ⇒ non
  /// interactive.
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité absente (invariant AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : titre effectif, complété
  /// de la description et du libellé de compte (l'info de la vignette est
  /// ainsi annoncée — invariant AD-13).
  final String? semanticLabel;

  String get _effectiveTitle {
    if (map.title.isNotEmpty) return map.title;
    return untitledLabel ?? map.title;
  }

  ZColorPair _accent(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      seedTitle: map.id.isNotEmpty ? map.id : map.title,
    );
    return zResolveColorKeyOrSlot(context, key, slotIndex: palette.indexOf(key));
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZColorPair pair = _accent(context);
    final int count = zMindmapNodeCount(map.nodes);
    final String? countText = nodeCountLabel?.call(count);
    final ZStudyCardHierarchy effective = hierarchy ??
        theme.studyCardHierarchy ??
        ZStudyCardHierarchy.tintedGlyph;

    if (effective == ZStudyCardHierarchy.tintedTile) {
      return _buildTintedTile(context, theme, pair, count, countText);
    }
    return _buildReference(context, theme, pair, countText);
  }

  // ── Hiérarchie de référence (défaut) ───────────────────────────

  Widget _buildReference(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    String? countText,
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

    return ZStudyToolsItemCard(
      // Tuile neutre, glyphe neutre — décorative (l'info est en texte via la
      // puce de compte et le libellé sémantique, invariant AD-13).
      leading: ExcludeSemantics(
        child: SizedBox(
          key: vignetteKey,
          width: chrome.iconTileSize,
          height: chrome.iconTileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.tileColor,
              borderRadius: BorderRadius.all(chrome.iconTileRadius),
            ),
            child: Center(
              child: Icon(
                icon ?? zDefaultMindmapReferenceIcon,
                color: chrome.neutralGlyphColor,
              ),
            ),
          ),
        ),
      ),
      title: _effectiveTitle,
      titleMaxLines: titleMaxLines ?? ZStudyCardReference.titleMaxLines,
      titleStyle: chrome.titleStyle,
      subtitle: map.description,
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
      belowSubtitle:
          countText == null ? null : _buildCountChip(context, theme, pair),
      trailing: trailing,
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel(countText),
    );
  }

  // ── Hiérarchie `tintedTile` — restitution exacte du rendu antérieur ──────
  //
  // Ne pas « moderniser » ce chemin : gardé par un test de restitution aux
  // valeurs mesurées du rendu antérieur. Les paramètres de chrome restent
  // non inertes (invariant AD-4) : fournis, ils s'appliquent ; nuls, rendu
  // littéral.

  Widget _buildTintedTile(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    int count,
    String? countText,
  ) =>
      ZStudyToolsItemCard(
        // Vignette structurelle — décorative : l'information est redite en
        // texte (puce de compte) et dans le libellé sémantique (invariant
        // AD-13).
        leading: ExcludeSemantics(
          child: SizedBox(
            key: vignetteKey,
            width: kZDefaultMindmapVignetteSize,
            height: kZDefaultMindmapVignetteSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pair.color,
                borderRadius: BorderRadius.all(theme.radiusM),
              ),
              child: CustomPaint(
                painter: _ZMindmapVignettePainter(
                  // Satellites = nœuds au-delà du central (borné, ≥ 0,
                  // invariant AD-10).
                  satelliteCount: math.min(
                    math.max(count - 1, 0),
                    kZDefaultMindmapVignetteMaxSatellites,
                  ),
                  color: pair.onColor,
                ),
              ),
            ),
          ),
        ),
        title: _effectiveTitle,
        titleMaxLines: titleMaxLines ?? 2,
        titleStyle: titleStyle,
        subtitle: map.description,
        subtitleStyle: subtitleStyle,
        contentPadding: contentPadding,
        margin: margin,
        borderSide: borderSide,
        borderRadius: borderRadius,
        belowSubtitle:
            countText == null ? null : _buildCountChip(context, theme, pair),
        trailing: trailing,
        progress: progress,
        progressMaxWidth: progressMaxWidth,
        hidesTrailingWhileBusy: hidesTrailingWhileBusy,
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: semanticLabel ?? _defaultSemanticLabel(countText),
      );

  String _defaultSemanticLabel(String? countText) {
    final StringBuffer buffer = StringBuffer(_effectiveTitle);
    final String? description = map.description;
    if (description != null) buffer.write(', $description');
    if (countText != null) buffer.write(', $countText');
    return buffer.toString();
  }

  Widget _buildCountChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // `heightFactor: 1` — leçon mesurée : un `Align` sans
        // facteur remplit la hauteur disponible (carte gonflée).
        heightFactor: 1,
        child: DecoratedBox(
          key: countChipKey,
          decoration: BoxDecoration(
            color: pair.color,
            borderRadius: BorderRadius.all(theme.radiusM),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            ),
            child: Text(
              nodeCountLabel!.call(zMindmapNodeCount(map.nodes)),
              key: countLabelKey,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (Theme.of(context).textTheme.labelSmall ??
                      const TextStyle())
                  .copyWith(color: pair.onColor),
            ),
          ),
        ),
      );

  /// Clé de la tuile/vignette (testabilité).
  static const ValueKey<String> vignetteKey =
      ValueKey<String>('zDefaultMindmapCard_vignette');

  /// Clé de la puce de compte de nœuds (testabilité).
  static const ValueKey<String> countChipKey =
      ValueKey<String>('zDefaultMindmapCard_countChip');

  /// Clé du texte de compte (testabilité — invariant AD-13).
  static const ValueKey<String> countLabelKey =
      ValueKey<String>('zDefaultMindmapCard_countLabel');
}

/// Croquis radial déterministe : nœud central + satellites reliés. Les
/// couleurs sont dérivées ([ZColorPair]) ; la disposition radiale est neutre
/// en RTL (aucun biais gauche/droite porteur de sens).
class _ZMindmapVignettePainter extends CustomPainter {
  const _ZMindmapVignettePainter({
    required this.satelliteCount,
    required this.color,
  });

  final int satelliteCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double unit = math.min(size.width, size.height);
    final double orbit = unit * 0.32;
    final double rootRadius = unit * 0.11;
    final double satelliteRadius = unit * 0.07;

    final Paint dot = Paint()..color = color;
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = math.max(unit * 0.03, 1);

    for (int i = 0; i < satelliteCount; i++) {
      final double angle = (2 * math.pi * i) / math.max(satelliteCount, 1);
      final Offset satellite =
          center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      canvas.drawLine(center, satellite, line);
      canvas.drawCircle(satellite, satelliteRadius, dot);
    }
    canvas.drawCircle(center, rootRadius, dot);
  }

  @override
  bool shouldRepaint(_ZMindmapVignettePainter oldDelegate) =>
      oldDelegate.satelliteCount != satelliteCount ||
      oldDelegate.color != color;
}
