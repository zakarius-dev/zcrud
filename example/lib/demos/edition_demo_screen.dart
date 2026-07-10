import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../binding/binding_selector.dart';
import '../support/rebuild_indicator.dart';
import 'edition_stepper_demo.dart';
import 'reference_form.dart';

/// Écran de démo ÉDITION (EX-1, AC4→AC7). Monte [DynamicEdition] sur le
/// formulaire de référence, avec :
///  - un `ZFormController` STABLE (créé dans `initState`, `dispose`é) ;
///  - un indicateur de rebuild GRANULAIRE par champ (SM-1, AC6) ;
///  - sections repliables + champ conditionnel + grille responsive (AC5) ;
///  - soumission `ZEditionSubmitController` + `ZSubmitButton` + bannière dirty
///    + `ZDiscardGuard` (AC5) ;
///  - un sélecteur de binding qui re-monte le MÊME formulaire sous chaque
///    mécanisme d'injection (parité AD-15, AC7) — un NOUVEAU controller par wrap.
class EditionDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo d'édition.
  const EditionDemoScreen({
    this.initialBinding = DemoBinding.scope,
    this.rebuildLog,
    super.key,
  });

  /// Binding initial (permet aux tests de cibler un wrap donné).
  final DemoBinding initialBinding;

  /// Journal de rebuild injectable (les tests lisent les compteurs par champ) ;
  /// un nouveau [RebuildLog] est créé si `null`.
  final RebuildLog? rebuildLog;

  @override
  State<EditionDemoScreen> createState() => _EditionDemoScreenState();
}

class _EditionDemoScreenState extends State<EditionDemoScreen> {
  late DemoBinding _binding;
  late ZFormController _controller;
  late ZEditionSubmitController<Map<String, Object?>> _submit;

  /// Journal de rebuild partagé (injecté ou créé localement).
  late final RebuildLog rebuildLog = widget.rebuildLog ?? RebuildLog();

  @override
  void initState() {
    super.initState();
    _binding = widget.initialBinding;
    _buildControllers();
  }

  void _buildControllers() {
    _controller = ZFormController(initialValues: ReferenceForm.initialValues());
    _submit = ZEditionSubmitController<Map<String, Object?>>(
      controller: _controller,
      fields: ReferenceForm.fields,
      onSubmit: (values) async =>
          Right<ZFailure, Map<String, Object?>>(values),
    );
  }

  void _changeBinding(DemoBinding next) {
    if (next == _binding) return;
    // AC7 : un NOUVEAU controller par wrap ; on dispose proprement l'ancien.
    // MAJEUR-1 (code-review EX-1) : le `ZEditionSubmitController` possède un
    // `ValueNotifier` interne à libérer AUSSI (sinon fuite à chaque switch). On
    // dispose le submit AVANT le form controller dont il dépend.
    final oldSubmit = _submit;
    final oldController = _controller;
    setState(() {
      _binding = next;
      _buildControllers();
    });
    oldSubmit.dispose();
    oldController.dispose();
  }

  @override
  void dispose() {
    // MAJEUR-1 : libère le submit (dépendant) avant le form controller.
    _submit.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Les changements non enregistrés seront perdus.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Démo Édition (E3)'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Variante Stepper',
            icon: const Icon(Icons.view_stream),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EditionStepperDemo(),
              ),
            ),
          ),
        ],
      ),
      // ZDiscardGuard : intercepte le retour si le formulaire est *dirty* (AC5).
      body: ZDiscardGuard(
        controller: _controller,
        onConfirmDiscard: _confirmDiscard,
        // Le sous-arbre est IDENTIQUE sous chaque binding (AD-15) : seul le
        // `wrap` d'injection change. Clé sur le binding → remontage propre.
        child: KeyedSubtree(
          key: ValueKey<DemoBinding>(_binding),
          // MEDIUM-1 : capte le ZcrudScope racine (filePicker/thème/l10n) pour le
          // re-propager SOUS le scope du binding (sinon masqué → familles
          // file/image/document inertes sous get/riverpod/provider).
          child: wrapWithBinding(
            _binding,
            _buildBody(context),
            rootScope: ZcrudScope.maybeOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BindingSelector(value: _binding, onChanged: _changeBinding),
        const _Sm1Legend(),
        _DirtyBanner(controller: _controller),
        Expanded(
          child: DynamicEdition(
            controller: _controller,
            fields: ReferenceForm.fields,
            sections: ReferenceForm.sections,
            layout: ReferenceForm.layout,
            padding: const EdgeInsetsDirectional.all(12),
            // fieldBuilder : rend le VRAI dispatcher `ZFieldWidget` précédé d'un
            // badge de rebuild scellé sur la MÊME tranche (granularité SM-1).
            fieldBuilder: (context, controller, field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RebuildBadge(
                  controller: controller,
                  name: field.name,
                  log: rebuildLog,
                ),
                ZFieldWidget(controller: controller, field: field),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: ZSubmitButton<Map<String, Object?>>(
            controller: _submit,
            label: 'Enregistrer',
            onDone: (outcome) {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    outcome.isSuccess
                        ? 'Soumission réussie (${outcome.value?.length ?? 0} champs).'
                        : 'Soumission bloquée : formulaire invalide.',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Légende expliquant l'indicateur SM-1.
class _Sm1Legend extends StatelessWidget {
  const _Sm1Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'SM-1 : chaque « rebuilds(champ) » ci-dessous ne s\'incrémente que '
        'lorsque CE champ change. Tapez dans un champ : seul son compteur bouge.',
        textAlign: TextAlign.start,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// Bannière *dirty* n'écoutant QUE `controller.isDirty` (tranche dédiée, SM-1).
class _DirtyBanner extends StatelessWidget {
  const _DirtyBanner({required this.controller});

  final ZFormController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isDirty,
      builder: (context, dirty, _) {
        if (!dirty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Container(
          width: double.infinity,
          color: theme.colorScheme.tertiaryContainer,
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.edit_note, color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modifications non enregistrées',
                  textAlign: TextAlign.start,
                  style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
