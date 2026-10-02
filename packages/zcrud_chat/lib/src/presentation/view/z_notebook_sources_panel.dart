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
  const ZNotebookSourcesPanel({
    required this.port,
    this.onAttach,
    this.confirmRemove,
    this.sourceBuilder,
    this.failureBuilder,
    super.key,
  });

  /// Lecture, retrait, et rattachement côté hôte.
  final ZNotebookSourcesPort port;

  /// Geste de rattachement. `null` : aucun bouton d'ajout (invariant AD-4).
  ///
  /// L'hôte ouvre son sélecteur puis appelle [ZNotebookSourcesPort.attach].
  /// Le panneau recharge la liste au retour du futur.
  final Future<void> Function()? onAttach;

  /// Confirmation avant retrait. `null` : le retrait est immédiat.
  /// `false` annule. Une erreur du rappel annule aussi.
  final Future<bool> Function(ZNotebookSource source)? confirmRemove;

  /// Remplace la ligne d'une source.
  final Widget Function(BuildContext context, ZNotebookSource source)?
  sourceBuilder;

  /// Remplace le message d'échec. Le texte brut du serveur n'est pas affiché.
  final Widget Function(BuildContext context, ZFailure failure)? failureBuilder;

  @override
  State<ZNotebookSourcesPanel> createState() => _ZNotebookSourcesPanelState();
}

class _ZNotebookSourcesPanelState extends State<ZNotebookSourcesPanel> {
  final ValueNotifier<List<ZNotebookSource>> _items =
      ValueNotifier<List<ZNotebookSource>>(const <ZNotebookSource>[]);
  final ValueNotifier<ZFailure?> _failure = ValueNotifier<ZFailure?>(null);
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _importing = ValueNotifier<bool>(false);

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
    _loading.dispose();
    _importing.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _loading.value = true;
    final ZResult<List<ZNotebookSource>> result;
    try {
      result = await widget.port.list();
    } catch (error) {
      if (!mounted) return;
      _loading.value = false;
      _failure.value = ZDomainFailure('${error.runtimeType}');
      return;
    }
    if (!mounted) return;
    _loading.value = false;
    result.fold((ZFailure failure) => _failure.value = failure, (
      List<ZNotebookSource> list,
    ) {
      _failure.value = null;
      _items.value = List<ZNotebookSource>.unmodifiable(list);
    });
  }

  Future<void> _remove(ZNotebookSource source) async {
    final Future<bool> Function(ZNotebookSource source)? confirm =
        widget.confirmRemove;
    if (confirm != null) {
      bool ok = false;
      try {
        ok = await confirm(source);
      } catch (error) {
        ok = false;
      }
      if (!ok || !mounted) return;
    }
    try {
      await widget.port.remove(source.id);
    } catch (error) {
      if (!mounted) return;
      _failure.value = ZDomainFailure('${error.runtimeType}');
      return;
    }
    await _reload();
  }

  String _sourceLine(BuildContext context, ZNotebookSource source) {
    final String title = source.title.isEmpty ? source.id : source.title;
    final int? pages = source.pageCount;
    final String? error = source.errorKey;
    final String? errorLabel = error == null || error.isEmpty
        ? null
        : zChatLabel(context, error);
    return <String>[
      title,
      if (pages != null)
        zChatCountLabel(context, kZChatLabelSourcePageCount, pages),
      ?errorLabel,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _loading,
      builder: (BuildContext context, bool loading, Widget? _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _importing,
          builder: (BuildContext context, bool importing, Widget? _) {
            return ValueListenableBuilder<List<ZNotebookSource>>(
              valueListenable: _items,
              builder:
                  (
                    BuildContext context,
                    List<ZNotebookSource> items,
                    Widget? _,
                  ) {
                    return LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double height = constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : MediaQuery.sizeOf(context).height * 0.4;
                        return SizedBox(
                          height: height,
                          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          zChatLabel(context, kZChatLabelSources),
                          textAlign: TextAlign.start,
                        ),
                        if (widget.onAttach != null)
                          _ZSourceButton(
                            label: zChatLabel(context, kZChatLabelAttachSource),
                            onTap: () async {
                              _importing.value = true;
                              try {
                                await widget.onAttach!();
                              } finally {
                                if (mounted) _importing.value = false;
                              }
                              await _reload();
                            },
                          ),
                        _ZSourceButton(
                          label: zChatLabel(context, kZChatLabelRefreshSources),
                          onTap: _reload,
                        ),
                        if (importing)
                          Text(
                            zChatLabel(context, kZChatLabelSourcesImporting),
                            textAlign: TextAlign.start,
                          ),
                        Expanded(child: _body(context, items, loading)),
                        ValueListenableBuilder<ZFailure?>(
                          valueListenable: _failure,
                          builder:
                              (
                                BuildContext context,
                                ZFailure? failure,
                                Widget? _,
                              ) {
                                if (failure == null) {
                                  return const SizedBox.shrink();
                                }
                                final Widget Function(
                                  BuildContext context,
                                  ZFailure failure,
                                )?
                                paint = widget.failureBuilder;
                                if (paint != null) return paint(context, failure);
                                return Text(
                                  zChatLabel(
                                    context,
                                    kZChatLabelSourcesUnavailable,
                                  ),
                                  textAlign: TextAlign.start,
                                );
                              },
                        ),
                      ],
                          ),
                        );
                      },
                    );
                  },
            );
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, List<ZNotebookSource> items, bool loading) {
    if (loading && items.isEmpty) {
      return Text(
        zChatLabel(context, kZChatLabelSourcesLoading),
        textAlign: TextAlign.start,
      );
    }
    if (items.isEmpty) {
      return Text(
        zChatLabel(context, kZChatLabelSourcesEmpty),
        textAlign: TextAlign.start,
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final ZNotebookSource source = items[index];
        final Widget Function(BuildContext context, ZNotebookSource source)?
        custom = widget.sourceBuilder;
        if (custom != null) return custom(context, source);
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _sourceLine(context, source),
                textAlign: TextAlign.start,
                maxLines: 2,
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
      case ZNotebookIngestionState.unknown:
        return zChatLabel(context, kZChatLabelIngestionUnknown);
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
