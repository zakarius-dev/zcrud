/// Barre des transformations offertes pour le niveau courant.
///
/// Le socle affiche les entrées autorisées et celles qui restent visibles
/// mais verrouillées. Il ne lance aucune génération : [onSelect] appartient
/// à l'écran, qui détient le contrôleur. Une entrée occupée ignore un second
/// geste jusqu'à la fin de son futur.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart';

/// Rangée de la [palette], filtrée par [level].
class ZTransformPaletteBar extends StatefulWidget {
  /// Construit la barre.
  const ZTransformPaletteBar({
    required this.palette,
    required this.onSelect,
    this.onLocked,
    this.level,
    this.busyKeys,
    this.oneAtATime = true,
    this.entryBuilder,
    this.sections,
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

  /// Occupations fournies par l'hôte. Une clé présente ignore le geste.
  final ValueListenable<Set<String>>? busyKeys;

  /// `true` : une entrée occupée bloque toutes les autres.
  final bool oneAtATime;

  /// Remplace le libellé d'une entrée. `locked` et `busy` décrivent l'état.
  final Widget Function(
    BuildContext context,
    ZTransformPaletteEntry entry, {
    required bool locked,
    required bool busy,
  })?
  entryBuilder;

  /// Regroupement optionnel. `null` : une seule rangée.
  final List<ZTransformPaletteSection>? sections;

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

  bool _occupied(String key, String? local, Set<String> host) {
    if (local == key || host.contains(key)) return true;
    if (widget.oneAtATime && (local != null || host.isNotEmpty)) return true;
    return false;
  }

  Future<void> _run(ZTransformPaletteEntry entry) async {
    final Set<String> host = widget.busyKeys?.value ?? const <String>{};
    if (_occupied(entry.artifactKey, _busy.value, host)) return;
    _busy.value = entry.artifactKey;
    try {
      await widget.onSelect(entry);
    } finally {
      if (mounted && _busy.value == entry.artifactKey) {
        _busy.value = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ZTransformPaletteEntry> offered = widget.palette.offeredFor(
      widget.level,
    );
    if (offered.isEmpty) return const SizedBox.shrink();
    final ValueListenable<Set<String>> host =
        widget.busyKeys ?? _zPaletteIdleBusy;
    return ValueListenableBuilder<String?>(
      valueListenable: _busy,
      builder: (BuildContext context, String? local, Widget? _) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: host,
          builder: (BuildContext context, Set<String> keys, Widget? _) {
            final List<Widget> rows = widget.sections == null
                ? <Widget>[_row(offered, local, keys)]
                : <Widget>[
                    for (final ZTransformPaletteSection section
                        in widget.sections!)
                      _section(section, offered, local, keys),
                  ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            );
          },
        );
      },
    );
  }

  Widget _section(
    ZTransformPaletteSection section,
    List<ZTransformPaletteEntry> offered,
    String? local,
    Set<String> host,
  ) {
    final List<ZTransformPaletteEntry> mine = <ZTransformPaletteEntry>[
      for (final ZTransformPaletteEntry entry in offered)
        if (section.keys.contains(entry.artifactKey)) entry,
    ];
    if (mine.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(section.label, textAlign: TextAlign.start),
        _row(mine, local, host),
      ],
    );
  }

  Widget _row(
    List<ZTransformPaletteEntry> entries,
    String? local,
    Set<String> host,
  ) {
    return Wrap(
      children: <Widget>[
        for (final ZTransformPaletteEntry entry in entries)
          _item(entry, _occupied(entry.artifactKey, local, host)),
      ],
    );
  }

  Widget _item(ZTransformPaletteEntry entry, bool busy) {
    final bool locked = entry.lockedFor(widget.level);
    final bool tappable = locked ? widget.onLocked != null : !busy;
    final Widget Function(
      BuildContext context,
      ZTransformPaletteEntry entry, {
      required bool locked,
      required bool busy,
    })?
    paint = widget.entryBuilder;
    return Semantics(
      button: true,
      enabled: tappable,
      label: entry.label,
      hint: locked ? zChatLabel(context, kZChatLabelPaletteLocked) : null,
      child: GestureDetector(
        onTap: !tappable
            ? null
            : locked
            ? () => widget.onLocked?.call(entry)
            : () => unawaited(_run(entry)),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: paint == null
                ? Text(entry.label, textAlign: TextAlign.start)
                : paint(context, entry, locked: locked, busy: busy),
          ),
        ),
      ),
    );
  }
}

/// Groupe d'entrées de la barre de transformations.
class ZTransformPaletteSection {
  /// Construit un groupe. [keys] filtre les entrées déjà offertes.
  const ZTransformPaletteSection({required this.label, required this.keys});

  /// Titre déjà localisé par l'hôte.
  final String label;

  /// Clés d'artefact du groupe.
  final Set<String> keys;
}

final ValueNotifier<Set<String>> _zPaletteIdleBusy = ValueNotifier<Set<String>>(
  const <String>{},
);
