/// Barre des transformations offertes pour le niveau courant.
///
/// Le socle affiche les entrées autorisées et celles qui restent visibles
/// mais verrouillées. Il ne lance aucune génération : [onSelect] appartient
/// à l'écran, qui détient le contrôleur. Une entrée occupée ignore un second
/// geste jusqu'à la fin de son futur.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_message_tile.dart';

/// Rangée de la [palette], filtrée par [level].
class ZTransformPaletteBar extends StatefulWidget {
  /// Construit la barre.
  const ZTransformPaletteBar({
    required this.palette,
    required this.onSelect,
    this.onLocked,
    this.level,
    super.key,
  });

  /// Catalogue déclaré par l'hôte.
  final ZTransformPalette palette;

  /// Niveau d'accès courant, ou `null` si l'hôte n'en a pas.
  final String? level;

  /// Choix d'une entrée actionnable. Le futur borne l'état occupé.
  final Future<void> Function(ZTransformPaletteEntry entry) onSelect;

  /// Geste d'une entrée verrouillée. `null` : le geste ne fait rien.
  final void Function(ZTransformPaletteEntry entry)? onLocked;

  @override
  State<ZTransformPaletteBar> createState() => _ZTransformPaletteBarState();
}

class _ZTransformPaletteBarState extends State<ZTransformPaletteBar> {
  final ValueNotifier<String?> _busy = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<void> _run(ZTransformPaletteEntry entry) async {
    if (_busy.value == entry.artifactKey) return;
    _busy.value = entry.artifactKey;
    try {
      await widget.onSelect(entry);
    } finally {
      if (_busy.value == entry.artifactKey) _busy.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ZTransformPaletteEntry> offered = widget.palette.offeredFor(
      widget.level,
    );
    if (offered.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: _busy,
      builder: (BuildContext context, String? busy, Widget? _) => Wrap(
        children: <Widget>[
          for (final ZTransformPaletteEntry entry in offered)
            _item(entry, busy == entry.artifactKey),
        ],
      ),
    );
  }

  Widget _item(ZTransformPaletteEntry entry, bool busy) {
    final bool locked = entry.lockedFor(widget.level);
    final bool enabled = !locked && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: entry.label,
      child: GestureDetector(
        onTap: !enabled
            ? (locked ? () => widget.onLocked?.call(entry) : null)
            : () => unawaited(_run(entry)),
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
    );
  }
}
