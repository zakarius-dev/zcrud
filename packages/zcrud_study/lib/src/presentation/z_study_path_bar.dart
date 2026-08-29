/// `ZStudyPathBar` — fil d'Ariane d'un `ZStudyContext`.
///
/// ## Instantané d'abord : aucune résolution
///
/// Les libellés affichés sont ceux que les [ZStudyRef] du contexte portent
/// déjà (`label`, puis `code`, puis l'identifiant). La barre **ne lit aucun
/// dépôt, n'ouvre aucun flux et n'attend rien** : un contexte résolu sur un
/// instantané partiel s'affiche tel quel, avec ce qu'il sait, plutôt que de
/// déclencher une lecture réseau au rendu.
///
/// ## Ce que sont les segments
///
/// Exactement `ZStudyContext.refs` : les organisations, puis les unités, les
/// programmes, les groupes, les périodes, puis la matière, le cours, l'offre
/// et le curriculum — dans cet ordre, dédoublonnés. C'est l'ordre que le noyau
/// déclare, racine d'abord ; la barre n'en invente ni n'en réordonne aucun. Un
/// hôte qui veut un chemin plus court passe un contexte plus court.
///
/// ## Débordement
///
/// [ZStudyPathBar.maxVisibleSegments] borne le nombre de segments **peints en
/// ligne** : ce sont les DERNIERS (le plus proche de la position courante
/// reste toujours visible), les précédents passant dans un menu au début du
/// fil. Un segment choisi dans le menu rend la même référence que s'il avait
/// été peint en ligne.
///
/// Séparateurs et placements sont directionnels (AD-13) ; aucun libellé ni
/// aucune couleur ne sont codés en dur (FR-26).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyContext, ZStudyRef;

/// Fil d'Ariane d'une position résolue dans la structure d'étude.
class ZStudyPathBar extends StatelessWidget {
  /// Construit un fil d'Ariane. Seul [studyContext] est requis.
  const ZStudyPathBar({
    required this.studyContext,
    this.onSelect,
    this.maxVisibleSegments,
    this.labelBuilder,
    this.overflowSemanticLabel,
    super.key,
  });

  /// Position résolue dont le chemin est affiché.
  final ZStudyContext studyContext;

  /// Appelée avec la **référence exacte** du segment tapé. `null` ⇒ les
  /// segments sont affichés sans être tapables.
  final ValueChanged<ZStudyRef>? onSelect;

  /// Nombre maximal de segments peints en ligne ; `null` ⇒ tous.
  final int? maxVisibleSegments;

  /// Libellé d'un segment. `null` ⇒ `ZStudyRef.label`, puis `ZStudyRef.code`,
  /// puis l'identifiant.
  final String Function(ZStudyRef ref)? labelBuilder;

  /// Libellé d'accessibilité du menu de débordement, `null` ⇒ aucun.
  final String? overflowSemanticLabel;

  /// Segments du fil, racine d'abord — exactement `ZStudyContext.refs`.
  List<ZStudyRef> get segments => studyContext.refs;

  String _label(ZStudyRef ref) =>
      labelBuilder?.call(ref) ?? ref.label ?? ref.code ?? ref.id;

  @override
  Widget build(BuildContext buildContext) {
    final List<ZStudyRef> all = segments;
    if (all.isEmpty) return const SizedBox.shrink();

    final int? max = maxVisibleSegments;
    final bool overflowing = max != null && max > 0 && all.length > max;
    final List<ZStudyRef> hidden = overflowing
        ? all.sublist(0, all.length - max)
        : const <ZStudyRef>[];
    final List<ZStudyRef> visible = overflowing
        ? all.sublist(all.length - max)
        : all;

    final List<Widget> children = <Widget>[];
    if (hidden.isNotEmpty) {
      children.add(_buildOverflow(buildContext, hidden));
      children.add(_buildSeparator(buildContext));
    }
    for (int i = 0; i < visible.length; i++) {
      if (i > 0) children.add(_buildSeparator(buildContext));
      children.add(_buildSegment(buildContext, visible[i]));
    }

    return SingleChildScrollView(
      key: const ValueKey<String>('zStudyPathBar.scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSeparator(BuildContext buildContext) {
    final bool rtl = Directionality.of(buildContext) == TextDirection.rtl;
    // Aucune `Key` : les séparateurs sont des frères multiples dans la même
    // `Row`, et deux frères ne peuvent pas partager la même clé.
    return Icon(rtl ? Icons.chevron_left : Icons.chevron_right, size: 16);
  }

  Widget _buildSegment(BuildContext buildContext, ZStudyRef ref) {
    final String label = _label(ref);
    final ValueChanged<ZStudyRef>? onSelect = this.onSelect;
    final Widget text = Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Text(
        label,
        textAlign: TextAlign.start,
        style: Theme.of(buildContext).textTheme.labelLarge,
      ),
    );
    if (onSelect == null) {
      return Semantics(label: label, container: true, child: text);
    }
    return Semantics(
      button: true,
      label: label,
      container: true,
      child: InkWell(
        key: ValueKey<String>('zStudyPathBar.segment:${ref.id}'),
        onTap: () => onSelect(ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(widthFactor: 1, child: text),
        ),
      ),
    );
  }

  Widget _buildOverflow(BuildContext buildContext, List<ZStudyRef> hidden) {
    final ValueChanged<ZStudyRef>? onSelect = this.onSelect;
    return PopupMenuButton<ZStudyRef>(
      key: const ValueKey<String>('zStudyPathBar.overflow'),
      tooltip: overflowSemanticLabel,
      enabled: onSelect != null,
      onSelected: onSelect,
      itemBuilder: (BuildContext _) => <PopupMenuEntry<ZStudyRef>>[
        for (final ZStudyRef ref in hidden)
          PopupMenuItem<ZStudyRef>(
            key: ValueKey<String>('zStudyPathBar.overflowItem:${ref.id}'),
            value: ref,
            child: Text(_label(ref), textAlign: TextAlign.start),
          ),
      ],
      icon: const Icon(Icons.more_horiz),
    );
  }
}
