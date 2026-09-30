/// Panneau standard des sources d'un notebook.
///
/// Il liste, retire, et — si l'hôte fournit [onAttach] — propose le
/// rattachement. Le sélecteur de document reste dans [onAttach] : ce
/// panneau ne lit aucun fichier. L'état d'ingestion est affiché par les
/// libellés du socle, jamais par une couleur choisie ici.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart';

/// Panneau des sources branché sur [port].
class ZNotebookSourcesPanel extends StatefulWidget {
  /// Construit le panneau.
  const ZNotebookSourcesPanel({required this.port, this.onAttach, super.key});

  /// Lecture, retrait, et rattachement côté hôte.
  final ZNotebookSourcesPort port;

  /// Geste de rattachement. `null` : aucun bouton d'ajout (invariant AD-4).
  ///
  /// L'hôte ouvre son sélecteur puis appelle [ZNotebookSourcesPort.attach].
  /// Le panneau recharge la liste au retour du futur.
  final Future<void> Function()? onAttach;

  @override
  State<ZNotebookSourcesPanel> createState() => _ZNotebookSourcesPanelState();
}

class _ZNotebookSourcesPanelState extends State<ZNotebookSourcesPanel> {
  final ValueNotifier<List<ZNotebookSource>> _items =
      ValueNotifier<List<ZNotebookSource>>(const <ZNotebookSource>[]);
  final ValueNotifier<ZFailure?> _failure = ValueNotifier<ZFailure?>(null);

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(ZNotebookSourcesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.port, widget.port)) unawaited(_reload());
  }

  @override
  void dispose() {
    _items.dispose();
    _failure.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final ZResult<List<ZNotebookSource>> result;
    try {
      result = await widget.port.list();
    } catch (error) {
      if (!mounted) return;
      _failure.value = ZDomainFailure('${error.runtimeType}');
      return;
    }
    if (!mounted) return;
    result.fold((ZFailure failure) => _failure.value = failure, (
      List<ZNotebookSource> list,
    ) {
      _failure.value = null;
      _items.value = List<ZNotebookSource>.unmodifiable(list);
    });
  }

  Future<void> _remove(ZNotebookSource source) async {
    try {
      await widget.port.remove(source.id);
    } catch (error) {
      if (!mounted) return;
      _failure.value = ZDomainFailure('${error.runtimeType}');
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ZNotebookSource>>(
      valueListenable: _items,
      builder: (BuildContext context, List<ZNotebookSource> items, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              zChatLabel(context, kZChatLabelSources),
              textAlign: TextAlign.start,
            ),
            if (widget.onAttach != null)
              _ZSourceButton(
                label: zChatLabel(context, kZChatLabelSources),
                onTap: () async {
                  await widget.onAttach!();
                  await _reload();
                },
              ),
            for (final ZNotebookSource source in items)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      source.title.isEmpty ? source.id : source.title,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    label: _stateLabel(context, source.state),
                    child: Text(
                      _stateLabel(context, source.state),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  _ZSourceButton(
                    label: zChatLabel(context, kZChatLabelRemoveSource),
                    onTap: () => _remove(source),
                  ),
                ],
              ),
            ValueListenableBuilder<ZFailure?>(
              valueListenable: _failure,
              builder: (BuildContext context, ZFailure? failure, Widget? _) {
                if (failure == null) return const SizedBox.shrink();
                return Text(failure.message, textAlign: TextAlign.start);
              },
            ),
          ],
        );
      },
    );
  }

  String _stateLabel(BuildContext context, ZNotebookIngestionState state) {
    switch (state) {
      case ZNotebookIngestionState.pending:
        return zChatLabel(context, kZChatLabelIngestionPending);
      case ZNotebookIngestionState.running:
        return zChatLabel(context, kZChatLabelIngestionRunning);
      case ZNotebookIngestionState.ready:
        return zChatLabel(context, kZChatLabelIngestionReady);
      case ZNotebookIngestionState.failed:
        return zChatLabel(context, kZChatLabelIngestionFailed);
    }
  }
}

class _ZSourceButton extends StatelessWidget {
  const _ZSourceButton({required this.label, required this.onTap});

  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => unawaited(onTap()),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, textAlign: TextAlign.start),
          ),
        ),
      ),
    );
  }
}
