import 'package:flutter/material.dart';

import 'demos/edition_demo_screen.dart';
import 'demos/export_demo_screen.dart';
import 'demos/geo_demo_screen.dart';
import 'demos/intl_demo_screen.dart';
import 'demos/list_demo_screen.dart';
import 'demos/markdown_demo_screen.dart';
import 'demos/offline_demo_screen.dart';
import 'demos/showcase/showcase_screen.dart';
import 'demos/study_session_demo_screen.dart';

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

/// Écran d'accueil : liste des démos PAR DOMAINE. Depuis EX-3 (CLÔTURE de l'epic
/// EX), TOUTES les features MVP sont actives : Édition (EX-1), Liste (EX-2),
/// Markdown (E6), Geo / Intl / Export (E11a) et Offline/Firestore (E5). Plus
/// AUCUNE entrée « à venir » ne subsiste (flashcards E9 / mindmaps E10 = v1.x,
/// hors périmètre — non listées). Regroupement (ambiguïté #6 tranchée) : entrées
/// SÉPARÉES par feature (une démo dédiée chacune), plus lisibles qu'un hub.
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

  List<_DemoEntry> get _entries => <_DemoEntry>[
        _DemoEntry(
          title: 'Édition',
          subtitle: 'DynamicEdition : familles, sections, stepper, SM-1',
          icon: Icons.edit_document,
          available: true,
          onOpen: (_) => const EditionDemoScreen(),
        ),
        _DemoEntry(
          title: 'Liste',
          subtitle: 'DynamicList / Syncfusion : colonnes dérivées, '
              'recherche/tri, actions, corbeille, onglets',
          icon: Icons.table_rows,
          available: true,
          onOpen: (_) => const ListDemoScreen(),
        ),
        _DemoEntry(
          title: 'Markdown',
          subtitle: 'ZMarkdownField : embeds LaTeX/tableau, codec Delta/Markdown',
          icon: Icons.notes,
          available: true,
          onOpen: (_) => const MarkdownDemoScreen(),
        ),
        _DemoEntry(
          title: 'Geo',
          subtitle: 'Champs location / geoArea via registre + carte OSM',
          icon: Icons.map_outlined,
          available: true,
          onOpen: (_) => const GeoDemoScreen(),
        ),
        _DemoEntry(
          title: 'Intl',
          subtitle: 'Téléphone (E.164) / pays / adresse via registre',
          icon: Icons.public,
          available: true,
          onOpen: (_) => const IntlDemoScreen(),
        ),
        _DemoEntry(
          title: 'Export',
          subtitle: 'ZExporter : Excel (.xlsx) / PDF via Syncfusion',
          icon: Icons.file_download_outlined,
          available: true,
          onOpen: (_) => const ExportDemoScreen(),
        ),
        _DemoEntry(
          title: 'Offline / Firestore',
          subtitle: 'CRUD offline via HiveZLocalStore (port ZLocalStore)',
          icon: Icons.cloud_sync,
          available: true,
          onOpen: (_) => const OfflineDemoScreen(),
        ),
        _DemoEntry(
          title: 'Showcase',
          subtitle: 'Preuve MVP : socle via le vrai dispatcher, états '
              'transverses, banc SM-1, harnais par axes',
          icon: Icons.grid_view_outlined,
          available: true,
          onOpen: (_) => const ShowcaseScreen(),
        ),
        _DemoEntry(
          title: 'Parcours d\'étude',
          subtitle: 'Sélecteur → pile swipeable → carte interactive → '
              'célébration (widgets publics + fakes, SM-1)',
          icon: Icons.school_outlined,
          available: true,
          onOpen: (_) => const StudySessionDemoScreen(),
        ),
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
