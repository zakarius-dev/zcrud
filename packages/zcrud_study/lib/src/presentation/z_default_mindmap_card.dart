/// `ZDefaultMindmapCard` — **carte de carte mentale PAR DÉFAUT** du socle,
/// avec **vignette** (CR-IFFD-48).
///
/// La voie typée est POSSIBLE ici : le modèle [ZMindmap] vit dans
/// `zcrud_mindmap`, dépendance **déjà déclarée** de `zcrud_study` (arête
/// ES-7.1) — aucune arête nouvelle (AD-1). Le pendant qui porte les données
/// est `ZStudyToolsSectionSpec.mindmaps(maps:)`.
///
/// ## La vignette : structurelle, pas un rendu du graphe
///
/// Un vrai rendu `ZMindmapView` par carte serait un moteur de graphe complet
/// par cellule de rail — à rebours de SM-1. La vignette est un **croquis
/// déterministe** dessiné depuis la structure réelle ([ZMindmap.nodes]) : un
/// nœud central + jusqu'à [kZDefaultMindmapVignetteMaxSatellites] satellites
/// reliés, disposés **radialement** (donc neutres en RTL). Elle est
/// **décorative** (`ExcludeSemantics`) : l'information (nombre de nœuds) est
/// redite **EN TEXTE** par la puce [nodeCountLabel] (AD-13) — sans libellé
/// injecté, la puce est **absente** (le socle ne traduit jamais, FR-26).
///
/// Couleurs et graisses : **rôles** de l'hôte uniquement
/// (`zResolveColorKeyOrSlot`, `TextTheme`) — aucun jeton nouveau nécessaire.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmap, ZMindmapNode;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_study_tools_item_card.dart';

/// Côté de la vignette (dimension de LAYOUT — jamais une couleur).
const double kZDefaultMindmapVignetteSize = 40;

/// Nombre maximal de satellites dessinés dans la vignette (croquis, pas
/// inventaire — l'inventaire exact passe par [ZDefaultMindmapCard.nodeCountLabel]).
const int kZDefaultMindmapVignetteMaxSatellites = 6;

/// Nombre TOTAL de nœuds de la forêt [nodes] (racines comprises) — parcours
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

/// Carte de carte mentale **par défaut** du socle (CR-IFFD-48).
///
/// ```dart
/// ZDefaultMindmapCard(
///   map: mindmap,
///   untitledLabel: l10n.untitledMindmap,     // libellé VISIBLE ⇒ injecté
///   nodeCountLabel: (n) => l10n.nodeCount(n),
///   onTap: () => open(mindmap),
/// )
/// ```
class ZDefaultMindmapCard extends StatelessWidget {
  /// Construit la carte ; seule [map] est requise.
  const ZDefaultMindmapCard({
    required this.map,
    this.untitledLabel,
    this.nodeCountLabel,
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

  /// Carte mentale rendue — **seule** entrée requise. Le dessin lit `title`,
  /// `description`, `nodes` et `id`.
  final ZMindmap map;

  /// Libellé LOCALISÉ **INJECTÉ** pour une carte au titre vide. `null` ⇒ le
  /// titre vide est rendu tel quel (le socle ne traduit **jamais** en dur).
  final String? untitledLabel;

  /// Fabrique le libellé LOCALISÉ du nombre de nœuds (« 12 nœuds »). `null` ⇒
  /// puce **absente** (AD-4) — jamais un nombre nu non localisé.
  final String Function(int nodeCount)? nodeCountLabel;

  /// Palette **INJECTÉE** bornant la clé d'accent.
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ dérivée de
  /// l'**identité** de la carte (`map.id`, repli titre) — stable, remap
  /// déterministe du kernel.
  final String? colorKey;

  /// Nombre maximal de lignes du titre. Défaut `2`.
  final int titleMaxLines;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ non
  /// interactive (AD-45).
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité **ABSENTE** (AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : titre effectif, complété
  /// de la description et du libellé de compte (l'info de la vignette est
  /// ainsi **annoncée** — AD-13).
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

    return ZStudyToolsItemCard(
      // Vignette structurelle — DÉCORATIVE : l'information est redite en texte
      // (puce de compte) et dans le libellé sémantique (AD-13).
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
                // Satellites = nœuds au-delà du central (borné, ≥ 0 — AD-10).
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
      titleMaxLines: titleMaxLines,
      subtitle: map.description,
      belowSubtitle:
          countText == null ? null : _buildCountChip(context, theme, pair),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel(countText),
    );
  }

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
        // 🔴 `heightFactor: 1` — leçon MESURÉE de CR-47 : un `Align` sans
        // facteur REMPLIT la hauteur disponible (carte gonflée à 854 dp).
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

  /// Clé de la vignette (testabilité).
  static const ValueKey<String> vignetteKey =
      ValueKey<String>('zDefaultMindmapCard_vignette');

  /// Clé de la puce de compte de nœuds (testabilité).
  static const ValueKey<String> countChipKey =
      ValueKey<String>('zDefaultMindmapCard_countChip');

  /// Clé du **texte** de compte (testabilité — AD-13).
  static const ValueKey<String> countLabelKey =
      ValueKey<String>('zDefaultMindmapCard_countLabel');
}

/// Croquis radial déterministe : nœud central + satellites reliés. Les
/// couleurs sont DÉRIVÉES ([ZColorPair]) ; la disposition radiale est neutre
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
