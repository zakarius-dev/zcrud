import 'package:flutter/material.dart';

import 'demos/edition_demo_screen.dart';

/// Descripteur d'une entrée de démo par domaine (accueil, AC3/AC10).
class _DemoEntry {
  const _DemoEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.available,
    this.onOpen,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// `false` → entrée « à venir » (désactivée, frontière EX-2/EX-3, AC10).
  final bool available;
  final WidgetBuilder? onOpen;
}

/// Écran d'accueil : liste des démos PAR DOMAINE (AC3). Seule « Édition » est
/// active en EX-1 ; les autres domaines (Liste/Firestore/Markdown/Geo·Intl·
/// Export) sont présents mais DÉSACTIVÉS « à venir » (frontière EX-2/EX-3, AC10).
/// Porte aussi les bascules thème / langue / sens (RTL — AD-13).
class HomeScreen extends StatelessWidget {
  /// Construit l'accueil avec l'état des bascules et leurs callbacks.
  const HomeScreen({
    required this.locale,
    required this.rtl,
    required this.dark,
    required this.onToggleLocale,
    required this.onToggleRtl,
    required this.onToggleDark,
    super.key,
  });

  /// Locale courante (`fr`/`en`).
  final Locale locale;

  /// Sens d'écriture forcé (RTL si `true`).
  final bool rtl;

  /// Thème sombre actif.
  final bool dark;

  /// Bascule la langue fr↔en.
  final VoidCallback onToggleLocale;

  /// Bascule le sens LTR↔RTL.
  final VoidCallback onToggleRtl;

  /// Bascule clair↔sombre.
  final VoidCallback onToggleDark;

  static const List<_DemoEntry> _staticEntries = <_DemoEntry>[
    _DemoEntry(
      title: 'Liste',
      subtitle: 'DynamicList / Syncfusion — à venir (EX-2)',
      icon: Icons.table_rows,
      available: false,
    ),
    _DemoEntry(
      title: 'Firestore / offline',
      subtitle: 'Persistance offline-first — à venir (EX-3)',
      icon: Icons.cloud_sync,
      available: false,
    ),
    _DemoEntry(
      title: 'Markdown',
      subtitle: 'Éditeur riche Quill — à venir (EX-3)',
      icon: Icons.notes,
      available: false,
    ),
    _DemoEntry(
      title: 'Geo / Intl / Export',
      subtitle: 'Champs géo, téléphone, PDF/Excel — à venir (EX-3)',
      icon: Icons.public,
      available: false,
    ),
  ];

  List<_DemoEntry> get _entries => <_DemoEntry>[
        _DemoEntry(
          title: 'Édition',
          subtitle: 'DynamicEdition : familles, sections, stepper, SM-1',
          icon: Icons.edit_document,
          available: true,
          onOpen: (_) => const EditionDemoScreen(),
        ),
        ..._staticEntries,
      ];

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('zcrud — Démos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Langue (${locale.languageCode})',
            icon: const Icon(Icons.translate),
            onPressed: onToggleLocale,
          ),
          IconButton(
            tooltip: rtl ? 'Sens : RTL' : 'Sens : LTR',
            icon: const Icon(Icons.format_textdirection_r_to_l),
            onPressed: onToggleRtl,
          ),
          IconButton(
            tooltip: dark ? 'Thème sombre' : 'Thème clair',
            icon: Icon(dark ? Icons.dark_mode : Icons.light_mode),
            onPressed: onToggleDark,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsetsDirectional.all(8),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return Card(
            child: ListTile(
              leading: Icon(e.icon),
              title: Text(e.title),
              subtitle: Text(e.subtitle, textAlign: TextAlign.start),
              trailing: e.available
                  ? const Icon(Icons.chevron_right)
                  : const Chip(label: Text('à venir')),
              enabled: e.available,
              // Cible tactile ≥ 48 dp (AD-13) : ListTile Material respecte le minimum.
              onTap: e.available && e.onOpen != null
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: e.onOpen!),
                      )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
