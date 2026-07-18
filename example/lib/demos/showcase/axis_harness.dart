import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/rebuild_indicator.dart';

/// Statut d'un **axe** de la showcase (fp-3-1, AC6). Un axe MVP est peuplé de
/// formulaires exécutables ; un axe « à venir » est déclaré dans l'ossature mais
/// non encore livré par son satellite (cohérent avec les gaps AC2).
enum AxisStatus {
  /// Axe MVP livré (Epics 1-2) — formulaires exécutables présents.
  mvp,

  /// Axe non-MVP (satellites Epic 4+) — déclaré, étiqueté « à venir ».
  upcoming,
}

/// Un **formulaire de démo** d'un axe : un schéma `ZFieldSpec[]` pur-données +
/// ses sections/grille/valeurs initiales, monté tel quel par [AxisFormScreen]
/// via le VRAI moteur (`DynamicEdition` → `ZFieldWidget`).
///
/// **OSSATURE RÉUTILISABLE (fp-3-2)** : fp-3-2 branche les 6 formulaires DODLP
/// complets et les axes 2/3/4 en ajoutant des [AxisForm] à [ShowcaseAxis.forms]
/// — SANS réécrire ni [AxisForm], ni [AxisFormScreen], ni [AxisHarnessScreen].
/// C'est le point d'extension unique du harnais.
@immutable
class AxisForm {
  /// Construit un formulaire de démo pur-données.
  const AxisForm({
    required this.id,
    required this.title,
    required this.fields,
    this.sections = const <ZEditionSection>[],
    this.layout = const <String, ZResponsiveSpan>{},
    this.initialValues = const <String, Object?>{},
    this.intensiveFieldName,
  });

  /// Identifiant stable (clé de navigation / de test).
  final String id;

  /// Titre affiché.
  final String title;

  /// Schéma des champs (source des `ZFieldSpec`).
  final List<ZFieldSpec> fields;

  /// Sections visuelles (facultatives).
  final List<ZEditionSection> sections;

  /// Grille responsive 12 colonnes par nom de champ (facultative).
  final Map<String, ZResponsiveSpan> layout;

  /// Valeurs initiales fictives (seede les tranches + `visibleFields`).
  final Map<String, Object?> initialValues;

  /// Nom du champ texte cible du **banc SM-1** (facultatif). Non-`null` ⇒ le
  /// formulaire est un banc de frappe intensive (badges de rebuild par champ).
  final String? intensiveFieldName;
}

/// Un **axe** = une famille / capacité. Décrit un axe → 1..n [AxisForm] +
/// métadonnées. Ossature réutilisée telle quelle par fp-3-2.
@immutable
class ShowcaseAxis {
  /// Construit un axe.
  const ShowcaseAxis({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.forms = const <AxisForm>[],
  });

  /// Identifiant stable de l'axe (ex. `axis-1`).
  final String id;

  /// Titre de l'axe.
  final String title;

  /// Sous-titre descriptif (familles couvertes).
  final String subtitle;

  /// Statut (MVP peuplé / à venir).
  final AxisStatus status;

  /// Formulaires de démo de l'axe (vide pour un axe « à venir »).
  final List<AxisForm> forms;
}

/// Une **capacité ABSENTE / à combler** (fp-3-1, AC2) : un `kind`/variante non
/// encore livré par son satellite, déclaré EXPLICITEMENT (jamais masqué, jamais
/// faux-rendu). fp-3-2 en retirera au fur et à mesure des livraisons Epic 4+.
@immutable
class AbsentCapability {
  /// Construit une entrée de gap.
  const AbsentCapability({
    required this.kind,
    required this.label,
    required this.reason,
  });

  /// `kind`/variante concerné (ex. `select modal`, `html`, `editableTable`).
  final String kind;

  /// Libellé lisible.
  final String label;

  /// Raison / satellite attendu.
  final String reason;
}

/// Écran RUNNER d'un [AxisForm] : monte le VRAI moteur (`DynamicEdition`) sur un
/// `ZFormController` **STABLE** (créé en `initState`, `dispose`é — AD-2). Quand
/// [rebuildLog] est fourni (ou que le formulaire porte un `intensiveFieldName`),
/// chaque champ est précédé d'un [RebuildBadge] scellé sur SA tranche : c'est le
/// banc SM-1 (granularité de rebuild prouvée, AD-2/SM-1).
///
/// Réutilisé à l'identique par fp-3-2 (aucune réécriture).
class AxisFormScreen extends StatefulWidget {
  /// Construit le runner pour [form].
  const AxisFormScreen({required this.form, this.rebuildLog, super.key});

  /// Formulaire de démo à monter.
  final AxisForm form;

  /// Journal de rebuild injectable (les tests lisent les compteurs par champ) ;
  /// un [RebuildBadge] est monté par champ dès qu'il est non-`null`.
  final RebuildLog? rebuildLog;

  @override
  State<AxisFormScreen> createState() => _AxisFormScreenState();
}

class _AxisFormScreenState extends State<AxisFormScreen> {
  late final ZFormController _controller;
  late final RebuildLog? _log =
      widget.rebuildLog ?? (widget.form.intensiveFieldName != null ? RebuildLog() : null);

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(initialValues: widget.form.initialValues);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    return Scaffold(
      appBar: AppBar(title: Text(widget.form.title)),
      body: DynamicEdition(
        controller: _controller,
        fields: widget.form.fields,
        sections: widget.form.sections,
        layout: widget.form.layout,
        padding: const EdgeInsetsDirectional.all(12),
        // Badge de rebuild par champ (banc SM-1) uniquement si un journal existe ;
        // sinon rendu direct du dispatcher (place stable garantie par le moteur).
        fieldBuilder: log == null
            ? null
            : (context, controller, field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RebuildBadge(
                        controller: controller, name: field.name, log: log),
                    ZFieldWidget(controller: controller, field: field),
                  ],
                ),
      ),
    );
  }
}

/// Écran HARNAIS : liste les [axes] (MVP + à venir). Les formulaires d'un axe MVP
/// sont navigables (→ [AxisFormScreen]) ; un axe « à venir » est étiqueté et non
/// actionnable (cohérent AC2/AC6). Réutilisé tel quel par fp-3-2.
class AxisHarnessScreen extends StatelessWidget {
  /// Construit le harnais sur [axes].
  const AxisHarnessScreen({required this.axes, super.key});

  /// Axes affichés (MVP peuplés + à venir déclarés).
  final List<ShowcaseAxis> axes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Harnais par axes')),
      body: ListView.builder(
        padding: const EdgeInsetsDirectional.all(8),
        itemCount: axes.length,
        itemBuilder: (context, index) => _AxisCard(axis: axes[index]),
      ),
    );
  }
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({required this.axis});

  final ShowcaseAxis axis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = axis.status == AxisStatus.upcoming;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    axis.title,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (upcoming)
                  const Chip(label: Text('à venir'))
                else
                  Chip(
                    label: const Text('MVP'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8),
              child: Text(
                axis.subtitle,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (upcoming)
              Text(
                'Formulaires à venir (satellites Epic 4+) — branchés par fp-3-2.',
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              )
            else
              Column(
                children: <Widget>[
                  for (final form in axis.forms)
                    ListTile(
                      key: ValueKey<String>('axis-form-${form.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dynamic_form),
                      title: Text(form.title, textAlign: TextAlign.start),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AxisFormScreen(form: form),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
