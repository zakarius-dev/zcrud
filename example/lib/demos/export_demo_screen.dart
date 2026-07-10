import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

import 'list_demo_data.dart';

/// Écran de démo EXPORT (EX-3, AC6, AC11). Réutilise le **schéma + données de
/// démo EX-2** (`demoSchema` + lignes du `DemoStore`) pour construire un
/// `ZListRenderRequest.fromSchema` (colonnes dérivées + `ZListRow`), puis exporte
/// en **Excel** / **PDF** via `const ZExporter()` — sorties `Uint8List` NON vides
/// (Excel = `.xlsx` ; PDF = préfixe `%PDF-`).
///
/// Ambiguïté #5 tranchée : la confirmation se fait par **snackbar** annonçant
/// `bytes.length` (démo hermétique, aucun secret/écriture disque requise). Le
/// dernier résultat est aussi affiché à l'écran (taille + type). Syncfusion
/// xlsio/pdf vient EXCLUSIVEMENT de `zcrud_export` (SM-5) ; aucune licence
/// Syncfusion committée.
class ExportDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo export.
  const ExportDemoScreen({super.key});

  @override
  State<ExportDemoScreen> createState() => _ExportDemoScreenState();
}

class _ExportDemoScreenState extends State<ExportDemoScreen> {
  /// Magasin partagé (source des lignes exportées) — possédé par le `State`.
  late final DemoStore _store;

  /// Exporteur neutre (Syncfusion confiné à `zcrud_export`).
  static const ZExporter _exporter = ZExporter();

  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _store = DemoStore();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  /// Construit le `ZListRenderRequest` neutre depuis le schéma + les lignes
  /// visibles (non soft-deleted).
  ZListRenderRequest _request() {
    final rows = <ZListRow>[
      for (final r in _store.visible(includeDeleted: false)) toDemoRow(r),
    ];
    return ZListRenderRequest.fromSchema(
      demoSchema,
      rows,
      policy: const ZColumnPolicy(),
    );
  }

  void _exportExcel() {
    final bytes = _exporter.toExcelBytes(_request());
    _confirm('Excel (.xlsx)', bytes, ok: bytes.isNotEmpty);
  }

  void _exportPdf() {
    final bytes = _exporter.toPdfBytes(_request());
    // Un PDF valide commence par `%PDF-`.
    final isPdf = bytes.length >= 5 &&
        String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
    _confirm('PDF', bytes, ok: isPdf);
  }

  void _confirm(String kind, Uint8List bytes, {required bool ok}) {
    final message = ok
        ? '$kind exporté : ${bytes.length} octets.'
        : '$kind : export invalide (${bytes.length} octets).';
    setState(() => _lastResult = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Démo Export (E11a)')),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Exporte le jeu de démo (${_store.visible(includeDeleted: false).length} '
              'lignes, schéma partagé avec la démo Liste) via ZExporter — '
              'Syncfusion xlsio/pdf confiné à zcrud_export (SM-5).',
              textAlign: TextAlign.start,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey<String>('exportExcelButton'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.grid_on),
              label: const Text('Exporter Excel'),
              onPressed: _exportExcel,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('exportPdfButton'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Exporter PDF'),
              onPressed: _exportPdf,
            ),
            const SizedBox(height: 24),
            if (_lastResult != null)
              Text(
                _lastResult!,
                key: const ValueKey<String>('exportResult'),
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}
