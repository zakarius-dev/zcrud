import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_media/zcrud_media.dart';

import 'axis_harness.dart';
import 'showcase_coverage.dart';
import 'showcase_data.dart';
import 'showcase_native_vs_package.dart';
import 'showcase_registry.dart';

/// Page **Showcase** (fp-3-1) : monte un **socle représentatif** de familles MVP
/// via le VRAI moteur (`DynamicEdition` → `ZFieldWidget`), sur un
/// [ZFormController] **STABLE** (créé en `initState`, `dispose`é — AD-2). Le
/// registre satellite est PEUPLÉ par le composeur fp-2-2 (`registerZcrudFormFields`
/// via [buildShowcaseWidgetRegistry]) et injecté via `ZcrudScope.widgetRegistry`
/// (app-owned, AD-4).
///
/// La page décline les **états transverses** (AC3) : mode lecture GLOBAL,
/// désactivé (champ `readOnly`), erreur de validation (bouton « Valider » →
/// `revealErrors`), valeur initiale (via `initialValues`), conditionnel
/// (`sPremium` gardé par `sBoolean`), **RTL** (`Directionality`) et **thème
/// clair/sombre** (`Theme` local). Elle liste aussi les capacités **ABSENTES /
/// à combler** (AC2) et route vers le **harnais par axes** (AC6).
class ShowcaseScreen extends StatefulWidget {
  /// Construit la page showcase.
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  /// Contrôleur STABLE du socle (AD-2 : créé 1×, jamais recréé au rebuild).
  late final ZFormController _controller;

  /// Registre satellite app-owned, PEUPLÉ par le composeur fp-2-2 (AD-4/AD-55) —
  /// construit UNE fois (jamais un singleton statique mutable).
  late final ZWidgetRegistry _registry;

  /// Seam d'acquisition média (fp-4-2) — injecté DANS le registre (closure des
  /// builders média) ET dans `ZcrudScope.filePicker` (même instance, AD-4).
  final ZMediaFilePicker _mediaPicker = ZMediaFilePicker();

  bool _rtl = false;
  bool _dark = false;
  bool _readOnly = false;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(initialValues: ShowcaseData.socleInitialValues());
    _registry = buildShowcaseWidgetRegistry(mediaPicker: _mediaPicker);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeData _themedData(BuildContext context) => ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: _dark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Showcase MVP'),
        actions: <Widget>[
          IconButton(
            tooltip: _readOnly ? 'Mode lecture' : 'Mode édition',
            icon: Icon(_readOnly ? Icons.lock : Icons.lock_open),
            onPressed: () => setState(() => _readOnly = !_readOnly),
          ),
          IconButton(
            tooltip: _rtl ? 'Sens : RTL' : 'Sens : LTR',
            icon: const Icon(Icons.format_textdirection_r_to_l),
            onPressed: () => setState(() => _rtl = !_rtl),
          ),
          IconButton(
            tooltip: _dark ? 'Thème sombre' : 'Thème clair',
            icon: Icon(_dark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => setState(() => _dark = !_dark),
          ),
        ],
      ),
      // États transverses RTL + thème appliqués au SOUS-ARBRE du socle (AC3). Le
      // registre satellite (composeur fp-2-2) est injecté ICI, app-owned (AD-4) :
      // il masque volontairement le registre racine (sans markdown) pour exercer
      // la voie satellite complète via le VRAI dispatcher.
      body: Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Theme(
          data: _themedData(context),
          // `Material` (et non un simple `ColoredBox`) : porte la couleur de
          // surface dérivée du thème local ET sert d'ancêtre Material aux
          // `ListTile`/encres du corps (aucune couleur codée en dur — FR-26).
          child: Builder(
            builder: (context) => Material(
              color: Theme.of(context).colorScheme.surface,
              child: ZcrudScope(
                // Seam média (fp-4-2) partagé avec le registre (AC7). Aucun
                // presenter de sélection injecté ICI → le socle rend les `select`
                // en NATIF ; la voie modale est démontrée côte à côte (AC3).
                filePicker: _mediaPicker,
                widgetRegistry: _registry,
                child: _ShowcaseBody(
                  controller: _controller,
                  readOnly: _readOnly,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corps scrollable : contrôles + gaps ABSENTS + socle `DynamicEdition` + accès
/// au harnais par axes. Extrait en widget pour garder un `build` léger (le socle
/// reste monté par le VRAI moteur, granularité SM-1 intacte — AD-2).
class _ShowcaseBody extends StatelessWidget {
  const _ShowcaseBody({required this.controller, required this.readOnly});

  final ZFormController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Accès au harnais par axes (AC6).
          Card(
            child: ListTile(
              key: const ValueKey<String>('showcase-open-harness'),
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Harnais par axes', textAlign: TextAlign.start),
              subtitle: const Text(
                'Axes MVP 1/5/6 exécutables + axes 2/3/4 « à venir »',
                textAlign: TextAlign.start,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const AxisHarnessScreen(axes: ShowcaseData.axes),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Couverture EXHAUSTIVE (AC1 / SM-4) : un statut CONNU par
          // `EditionFieldType` (dérivé de l'enum, jamais un nombre figé).
          const _CoverageSummary(),
          const SizedBox(height: 12),

          // Décisions natif-vs-package côte à côte (AC3 / D1-D4).
          const NativeVsPackageSection(),
          const SizedBox(height: 12),

          // Capacités ABSENTES / à combler (AC4) — jamais masquées, jamais
          // faux-rendues (gaps assumés restants : icon / LaTeX SVG / itemsAreTags).
          const _AbsentSection(),
          const SizedBox(height: 12),

          // Bouton « Valider » : révèle les erreurs (AC3 — état d'erreur du champ
          // requis `sRequired`).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const ValueKey<String>('showcase-validate'),
              onPressed: controller.revealErrors,
              icon: const Icon(Icons.rule),
              label: const Text('Valider (révéler les erreurs)'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Socle représentatif — chaque champ rendu par son adaptateur réel',
            textAlign: TextAlign.start,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // SOCLE via le VRAI moteur. `shrinkWrap` + physique non-scrollable :
          // le socle est imbriqué dans le scroll parent (tous les champs bâtis).
          DynamicEdition(
            controller: controller,
            fields: ShowcaseData.socleFields,
            sections: ShowcaseData.socleSections,
            layout: ShowcaseData.socleLayout,
            readOnly: readOnly,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.zero,
          ),
        ],
      ),
    );
  }
}

/// Résumé de **couverture EXHAUSTIVE** (AC1 / SM-4) : décompte par statut sur les
/// `EditionFieldType.values` (dérivé de l'enum). Rend l'audit de parité visible :
/// livré-natif / câblé-satellite / comportement-seam / gap-assumé.
class _CoverageSummary extends StatelessWidget {
  const _CoverageSummary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = EditionFieldType.values.length;
    int count(CoverageStatus s) => ShowcaseCoverage.byType.values
        .where((c) => c.status == s)
        .length;
    return Card(
      key: const ValueKey<String>('showcase-coverage'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Couverture exhaustive — $total types (dérivé de l\'enum)',
              textAlign: TextAlign.start,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip('Livré natif', count(CoverageStatus.liveNative)),
                _StatusChip('Câblé satellite', count(CoverageStatus.liveSatellite)),
                _StatusChip('Comportement / seam', count(CoverageStatus.behavior)),
                _StatusChip('Gap assumé', count(CoverageStatus.assumedGap)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label : $count'),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Section listant les capacités **ABSENTES / à combler** (AC4). Chaque entrée
/// est visible et étiquetée (`Chip` « ABSENT »), jamais rendue via un faux widget.
class _AbsentSection extends StatelessWidget {
  const _AbsentSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Capacités ABSENTES / à combler',
              textAlign: TextAlign.start,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final cap in ShowcaseData.absentCapabilities)
              Padding(
                key: ValueKey<String>('absent-${cap.kind}'),
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                      child: Chip(
                        label: const Text('ABSENT'),
                        backgroundColor: theme.colorScheme.errorContainer,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            cap.label,
                            textAlign: TextAlign.start,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${cap.kind} — ${cap.reason}',
                            textAlign: TextAlign.start,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
