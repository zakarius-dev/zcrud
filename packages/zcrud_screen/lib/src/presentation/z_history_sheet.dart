/// Consultation optionnelle d'un journal fourni par l'hôte.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Présente le journal sans imposer de route ou de backend à l'hôte.
Future<void> showZEntityHistory<T extends ZEntity>(
  BuildContext context, {
  required T entity,
  required ZEntityHistorySource<T> source,
  required Map<String, Object?> currentValue,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _ZHistorySheet<T>(
    entity: entity,
    source: source,
    currentValue: currentValue,
  ),
);

class _ZHistorySheet<T extends ZEntity> extends StatelessWidget {
  const _ZHistorySheet({
    required this.entity,
    required this.source,
    required this.currentValue,
  });
  final T entity;
  final ZEntityHistorySource<T> source;
  final Map<String, Object?> currentValue;

  @override
  Widget build(BuildContext context) {
    Stream<List<ZHistoryEntry>> stream;
    try {
      stream = source.watchHistory(entity);
    } catch (_) {
      stream = const Stream<List<ZHistoryEntry>>.empty();
    }
    return SafeArea(
      child: Semantics(
        container: true,
        label: label(context, 'history'),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: StreamBuilder<List<ZHistoryEntry>>(
            stream: stream,
            builder: (context, snapshot) {
              final entries = snapshot.hasError
                  ? const <ZHistoryEntry>[]
                  : snapshot.data ?? const <ZHistoryEntry>[];
              final valid = <ZHistoryEntry>[
                for (final entry in entries)
                  if (_isRenderable(entry)) entry,
              ];
              return _ZHistoryTable(entries: valid, currentValue: currentValue);
            },
          ),
        ),
      ),
    );
  }

  bool _isRenderable(ZHistoryEntry entry) =>
      entry.at != null &&
      (entry.action != null ||
          (entry.operationLabel != null && entry.operationLabel!.isNotEmpty));
}

class _ZHistoryTable extends StatelessWidget {
  const _ZHistoryTable({required this.entries, required this.currentValue});
  final List<ZHistoryEntry> entries;
  final Map<String, Object?> currentValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(16),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Semantics(
            header: true,
            child: Text(
              label(context, 'history'),
              style: theme.textTheme.titleLarge,
            ),
          );
        }
        final entryIndex = index - 1;
        final entry = entries[entryIndex];
        // CONTRAT DE DIFF : ordre décroissant. L'état d'avant d'une entrée est
        // comparé à son état d'après : entité courante (première), puis état
        // d'avant de l'entrée immédiatement plus récente. Maps/listes imbriquées
        // sont atomiques, donc explicitement hors périmètre du diff.
        final after = entryIndex == 0
            ? currentValue
            : entries[entryIndex - 1].previousValue;
        return _ZHistoryRow(entry: entry, after: after);
      },
    );
  }
}

class _ZHistoryRow extends StatelessWidget {
  const _ZHistoryRow({required this.entry, required this.after});
  final ZHistoryEntry entry;
  final Map<String, Object?>? after;

  @override
  Widget build(BuildContext context) {
    final operation = entry.action == null
        ? entry.operationLabel!
        : label(context, entry.action!.name);
    final date = zDateDisplayTextOf(
      ZcrudScope.maybeOf(context)?.dateDisplayFormatter,
      entry.at,
      mode: ZDateMode.dateTime,
      localeTag: Localizations.localeOf(context).toLanguageTag(),
    );
    final changes = _changes(entry.previousValue, after);
    return Semantics(
      container: true,
      label:
          '${label(context, 'date')}: $date; ${label(context, 'operation')}: $operation; ${label(context, 'author')}: ${entry.authorLabel ?? ''}',
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Table(
              columnWidths: const <int, TableColumnWidth>{
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: <TableRow>[
                _cell(context, 'date', date),
                _cell(context, 'operation', operation),
                _cell(context, 'author', entry.authorLabel ?? ''),
              ],
            ),
            for (final change in changes)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4),
                child: Text(change),
              ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  TableRow _cell(BuildContext context, String heading, String value) =>
      TableRow(
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Text(label(context, heading)),
          ),
          Text(value, textAlign: TextAlign.start),
        ],
      );

  List<String> _changes(
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) {
    if (before == null || after == null) return const <String>[];
    final keys = <String>{...before.keys, ...after.keys}.toList()..sort();
    return <String>[
      for (final key in keys)
        if (!before.containsKey(key))
          '$key: ${after[key]}'
        else if (!after.containsKey(key))
          '$key: ${before[key]}'
        else if (before[key] != after[key])
          '$key: ${before[key]} → ${after[key]}',
    ];
  }
}
