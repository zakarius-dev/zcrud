/// Barre des transformations offertes pour le niveau courant.
///
/// Le socle affiche les entrées visibles et relaie le choix. Il ne lance
/// aucune génération : [onSelect] appartient à l'écran, qui détient le
/// contrôleur.
library;

import 'package:flutter/widgets.dart';

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_message_tile.dart';

/// Rangée de la [palette], filtrée par [level].
class ZTransformPaletteBar extends StatelessWidget {
  /// Construit la barre.
  const ZTransformPaletteBar({
    required this.palette,
    required this.onSelect,
    this.level,
    super.key,
  });

  /// Catalogue déclaré par l'hôte.
  final ZTransformPalette palette;

  /// Niveau d'accès courant, ou `null` si l'hôte n'en a pas.
  final String? level;

  /// Choix d'une entrée visible.
  final void Function(ZTransformPaletteEntry entry) onSelect;

  @override
  Widget build(BuildContext context) {
    final List<ZTransformPaletteEntry> visible = palette.visibleFor(level);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      children: <Widget>[
        for (final ZTransformPaletteEntry entry in visible)
          Semantics(
            button: true,
            label: entry.label,
            child: GestureDetector(
              onTap: () => onSelect(entry),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kZChatMinTapTarget,
                  minHeight: kZChatMinTapTarget,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(entry.label, textAlign: TextAlign.start),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
