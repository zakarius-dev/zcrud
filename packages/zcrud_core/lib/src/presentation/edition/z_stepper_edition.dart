/// `ZStepperEdition` — présentation d'un formulaire long en **assistant (wizard)
/// multi-étapes** partitionnant le **MÊME** `ZFormController` (E3-5, AD-2 /
/// OBJECTIF PRODUIT N°1 / SM-1).
///
/// origine: `EditionFieldType.stepper` n'est PAS un champ-feuille — le dispatcher
/// (E3-3a) le classe volontairement `unsupported` car c'est un **REGROUPEMENT /
/// structure de navigation** renvoyé ici. E3-5 le sert donc au niveau
/// **orchestration**, posé AUTOUR du dispatcher existant, jamais comme un
/// `ZFieldWidget`.
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - **UN seul `ZFormController` partagé** : toutes les étapes lisent/écrivent le
///   même controller (mêmes tranches). Il n'existe JAMAIS de controller par
///   étape, ni de recréation au changement d'étape → l'**état est préservé** en
///   va-et-vient (les tranches survivent au démontage des champs d'une étape ;
///   elles ne sont libérées qu'au `dispose` du controller, possédé par l'hôte).
/// - **AUCUN `Form`/`FormBuilder` global** : chaque étape réutilise
///   [DynamicEdition] (donc des `TextFormField` **autonomes**). `find.byType(Form)`
///   reste `findsNothing` sur toutes les étapes. La validation reste **par champ**.
/// - **Validation PAR ÉTAPE** : la transition « suivant » ne valide QUE les
///   champs **visibles** de l'étape courante (via [ZValidatorCompiler] mémoïsé,
///   E3-2, évalué contre `controller.valueOf`). Étape invalide ⇒ navigation
///   bloquée + erreurs **révélées** (bascule locale `AutovalidateMode.always` via
///   un seam additif — jamais un `Form` global). « Précédent » est inconditionnel.
/// - **Chrome = canaux STRUCTURELS only** (SM-1) : la barre d'étapes + la
///   navigation + la zone d'étape n'observent QUE l'index courant ([_currentStep]),
///   le canal de révélation ([_reveal]) et `controller.visibleFields` — JAMAIS une
///   tranche de valeur. Une frappe (qui ne touche aucun canal structurel) ne
///   reconstruit donc QUE le champ courant, jamais le chrome (zéro perte de focus).
///
/// **Frontière E3-6** : la dernière étape délègue la **soumission** à E3-6 (slot
/// [onComplete]) ; E3-5 ne fait PAS de `onSubmit`, de détection *dirty*, ni de
/// validateurs **inter-champs** (`refKey`/`match`, déférés E3-6 par
/// [ZValidatorCompiler]). Composition orthogonale E3-4 : une étape peut contenir
/// sections repliables + champs conditionnels (hérités de [DynamicEdition]).
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import '../z_form_controller.dart';
import 'dynamic_edition.dart';
import 'z_field_widget.dart';
import 'z_responsive_grid.dart';
import 'z_validator_compiler.dart';

/// Descripteur **présentation** d'une étape : un titre + le sous-ensemble de
/// **noms de champs** du catalogue qu'elle regroupe (aligné sur [ZEditionSection]
/// — titre + noms, PAS une nouvelle donnée de formulaire). Additif, `const`.
@immutable
class ZEditionStep {
  /// Construit une étape de titre [title] regroupant les champs [fields] (par
  /// nom, dans l'ordre indicatif ; l'ordre effectif de rendu suit l'ordre
  /// canonique du catalogue via [DynamicEdition]).
  const ZEditionStep({
    required this.title,
    required this.fields,
    this.sections = const <ZEditionSection>[],
  });

  /// Titre affiché de l'étape (clé l10n ou littéral — résolu côté hôte).
  final String title;

  /// Noms de champs appartenant à l'étape (sous-ensemble du catalogue).
  final List<String> fields;

  /// Sections **visuelles** internes à l'étape (E3-4), restreintes à ses champs.
  /// Vide = liste plate. Orthogonal au partitionnement en étapes.
  final List<ZEditionSection> sections;
}

/// Constructeur d'un widget de champ d'étape. Reçoit le [autovalidateMode]
/// **piloté par le stepper** (révélation d'erreurs à une transition bloquée) —
/// un builder custom DOIT le propager pour honorer AC4 sans `Form` global.
typedef ZStepFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController controller,
  ZFieldSpec field,
  AutovalidateMode autovalidateMode,
);

/// Formulaire d'édition présenté en **étapes séquencées** sur un unique
/// [ZFormController].
class ZStepperEdition extends StatefulWidget {
  /// Construit le stepper sur le [controller] unique, le catalogue [fields] et
  /// la liste ordonnée d'[steps].
  const ZStepperEdition({
    required this.controller,
    required this.fields,
    required this.steps,
    this.initialStep = 0,
    this.padding,
    this.physics,
    this.readOnly = false,
    this.layout = const <String, ZResponsiveSpan>{},
    this.gridGutter = 8,
    this.fieldBuilder,
    this.previousLabel,
    this.nextLabel,
    this.finishLabel,
    this.onComplete,
    this.onStepChanged,
    this.onStructuralBuild,
    super.key,
  });

  /// Contrôleur **unique** détenant l'état (créé/possédé par l'hôte ; jamais
  /// recréé ici, jamais un par étape).
  final ZFormController controller;

  /// Catalogue complet des champs connus (source des [ZFieldSpec] par nom).
  final List<ZFieldSpec> fields;

  /// Étapes ordonnées partitionnant le catalogue.
  final List<ZEditionStep> steps;

  /// Index d'étape initial (borné à `[0, steps.length-1]`).
  final int initialStep;

  /// Marge du `ListView` de chaque étape (héritée par [DynamicEdition]).
  final EdgeInsetsGeometry? padding;

  /// `ScrollPhysics` de la zone d'étape.
  final ScrollPhysics? physics;

  /// Mode lecture global propagé à chaque étape ([DynamicEdition.readOnly]).
  final bool readOnly;

  /// Grille 12 colonnes (span par nom de champ) propagée à chaque étape.
  final Map<String, ZResponsiveSpan> layout;

  /// Gouttière (dp) de la grille responsive.
  final double gridGutter;

  /// Seam de rendu de champ (reçoit le mode d'autovalidation piloté). À défaut :
  /// le dispatcher [ZFieldWidget] (E3-3a), place stable garantie par
  /// [DynamicEdition].
  final ZStepFieldBuilder? fieldBuilder;

  /// Libellé du bouton « précédent » (défaut l10n `z.stepper.previous`).
  final String? previousLabel;

  /// Libellé du bouton « suivant » (défaut l10n `z.stepper.next`).
  final String? nextLabel;

  /// Libellé du bouton final de la **dernière** étape (défaut `z.stepper.finish`).
  /// Son action délègue à [onComplete] (soumission = E3-6).
  final String? finishLabel;

  /// Slot de **fin d'assistant** (dernière étape) : E3-5 ne soumet PAS ; il
  /// délègue à E3-6. `null` ⇒ le bouton final est présent mais désactivé.
  final VoidCallback? onComplete;

  /// Notifié après un changement d'étape effectif (index cible).
  final ValueChanged<int>? onStepChanged;

  /// Hook d'instrumentation : appelé à chaque (re)build **structurel** du chrome
  /// (compteur SM-1 — reste inchangé pendant la saisie).
  @visibleForTesting
  final VoidCallback? onStructuralBuild;

  @override
  State<ZStepperEdition> createState() => _ZStepperEditionState();
}

class _ZStepperEditionState extends State<ZStepperEdition> {
  /// Canal STRUCTUREL local : index de l'étape montée (jamais une tranche).
  late final ValueNotifier<int> _currentStep;

  /// Canal STRUCTUREL local : révélation forcée des erreurs de l'étape courante
  /// (bascule `AutovalidateMode.always`). Piloté par un « suivant » bloqué ;
  /// remis à `false` à toute navigation effective.
  late final ValueNotifier<bool> _reveal;

  /// Listenable fusionné observé par le chrome : index + révélation +
  /// `visibleFields` (structurel). AUCUNE tranche de valeur (SM-1/AC11).
  late Listenable _structural;

  /// Index `name → spec` (identité de valeur ; recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Cache de validateurs compilés **mémoïsés** par nom de champ (E3-2 réutilisé).
  final Map<String, FormFieldValidator<String>?> _validatorCache =
      <String, FormFieldValidator<String>?>{};

  int get _lastStep => widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    final start = widget.initialStep.clamp(0, _lastStep < 0 ? 0 : _lastStep);
    _currentStep = ValueNotifier<int>(start);
    _reveal = ValueNotifier<bool>(false);
    _rebuildIndexes();
    _structural = Listenable.merge(<Listenable?>[
      _currentStep,
      _reveal,
      widget.controller.visibleFields,
    ]);
    // Fenêtre initiale : n'exposer que les champs (visibles) de l'étape de départ.
    _syncWindow(start);
  }

  @override
  void didUpdateWidget(ZStepperEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged || !identical(oldWidget.fields, widget.fields)) {
      _rebuildIndexes();
      _validatorCache.clear();
    }
    if (controllerChanged) {
      _structural = Listenable.merge(<Listenable?>[
        _currentStep,
        _reveal,
        widget.controller.visibleFields,
      ]);
      _syncWindow(_currentStep.value);
    }
  }

  void _rebuildIndexes() {
    _specByName = <String, ZFieldSpec>{
      for (final f in widget.fields) f.name: f,
    };
  }

  @override
  void dispose() {
    _currentStep.dispose();
    _reveal.dispose();
    super.dispose();
  }

  // ── Fenêtre d'étape ────────────────────────────────────────────────────────

  /// Specs (dans l'ordre déclaré de l'étape) des champs connus de l'étape [i].
  List<ZFieldSpec> _stepSpecs(int i) => <ZFieldSpec>[
        for (final name in widget.steps[i].fields)
          if (_specByName[name] != null) _specByName[name]!,
      ];

  /// Noms des champs **visibles** (conditionnels honorés) de l'étape [i], dans
  /// l'ordre canonique du catalogue (cohérent avec [DynamicEdition]).
  List<String> _windowFor(int i) {
    final stepNames = widget.steps[i].fields.toSet();
    return <String>[
      for (final f in widget.fields)
        if (stepNames.contains(f.name) &&
            (f.condition == null ||
                evaluateZCondition(f.condition!, widget.controller.valueOf)))
          f.name,
    ];
  }

  /// Aligne `controller.visibleFields` sur la fenêtre de l'étape [i] (no-op si
  /// inchangé). Ne DÉTRUIT jamais de tranche (les slices survivent — AC7/AC9) :
  /// `visibleFields` est un canal purement STRUCTUREL reflétant l'étape montée.
  void _syncWindow(int i) {
    if (i < 0 || i > _lastStep) return;
    widget.controller.setVisibleFields(_windowFor(i));
  }

  // ── Validation PAR ÉTAPE (gate de navigation) ──────────────────────────────

  FormFieldValidator<String>? _validatorFor(ZFieldSpec spec) =>
      _validatorCache.putIfAbsent(
        spec.name,
        () => ZValidatorCompiler.compile(spec.validators),
      );

  static String _stringOf(Object? value) => value == null ? '' : '$value';

  /// `true` ssi TOUS les champs **visibles** de l'étape [i] passent leurs
  /// validateurs champ-locaux (E3-2). PUR (aucun `Form`, aucun `pump`) :
  /// évalue le validateur mémoïsé contre `_stringOf(valueOf(name))`. Un champ
  /// masqué par condition n'est PAS validé (AC13) ; une étape sans champ visible
  /// passe trivialement (AC13/ambiguïté #4).
  bool _validateStep(int i) {
    if (i < 0 || i > _lastStep) return true;
    final visible = _windowFor(i).toSet();
    for (final spec in _stepSpecs(i)) {
      if (!visible.contains(spec.name)) continue;
      final validator = _validatorFor(spec);
      if (validator == null) continue;
      final error = validator(_stringOf(widget.controller.valueOf(spec.name)));
      if (error != null) return false;
    }
    return true;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(int target) {
    if (target < 0 || target > _lastStep || target == _currentStep.value) {
      return;
    }
    _reveal.value = false;
    _syncWindow(target);
    _currentStep.value = target;
    widget.onStepChanged?.call(target);
  }

  /// « Suivant » : validation par étape (AC3/AC5). Invalide ⇒ blocage + erreurs
  /// révélées (AC4). Sur la dernière étape ⇒ délègue à [onComplete] (E3-6).
  void _next() {
    final current = _currentStep.value;
    if (current >= _lastStep) {
      if (_validateStep(current)) {
        widget.onComplete?.call();
      } else {
        _reveal.value = true;
      }
      return;
    }
    if (_validateStep(current)) {
      _goTo(current + 1);
    } else {
      _reveal.value = true; // canal structurel → révèle sans `Form` global.
    }
  }

  /// « Précédent » : INCONDITIONNEL (jamais de gate en arrière — AC6).
  void _previous() {
    final current = _currentStep.value;
    if (current > 0) _goTo(current - 1);
  }

  // ── Rendu ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    // Chrome scellé sur les canaux STRUCTURELS uniquement (SM-1/AC11) : une
    // frappe ne le ré-exécute pas.
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final index = _currentStep.value.clamp(0, _lastStep);
        final reveal = _reveal.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _StepIndicator(
              index: index,
              total: widget.steps.length,
              title: widget.steps[index].title,
            ),
            Expanded(child: _stepContent(index, reveal)),
            _StepNavigationBar(
              isFirst: index == 0,
              isLast: index == _lastStep,
              previousLabel:
                  widget.previousLabel ?? label(context, 'z.stepper.previous',
                      fallback: 'Précédent'),
              nextLabel: widget.nextLabel ??
                  label(context, 'z.stepper.next', fallback: 'Suivant'),
              finishLabel: widget.finishLabel ??
                  label(context, 'z.stepper.finish', fallback: 'Terminer'),
              onPrevious: index == 0 ? null : _previous,
              onNext: _next,
              finishEnabled: widget.onComplete != null,
            ),
          ],
        );
      },
    );
  }

  /// Zone d'étape : réutilise [DynamicEdition] sur le sous-ensemble de l'étape
  /// (hérite conditionnels/sections/grille/place stable d'E3-1..E3-4). Keyée par
  /// étape → chaque transition monte un sous-arbre neuf ; les VALEURS survivent
  /// dans le controller unique (AC7/AC8).
  Widget _stepContent(int index, bool reveal) {
    final mode = reveal
        ? AutovalidateMode.always
        : AutovalidateMode.onUserInteraction;
    final custom = widget.fieldBuilder;
    return DynamicEdition(
      key: ValueKey<String>('zstep:$index'),
      controller: widget.controller,
      fields: _stepSpecs(index),
      sections: widget.steps[index].sections,
      padding: widget.padding,
      physics: widget.physics,
      readOnly: widget.readOnly,
      layout: widget.layout,
      gridGutter: widget.gridGutter,
      fieldBuilder: (context, ctrl, field) => custom != null
          ? custom(context, ctrl, field, mode)
          : ZFieldWidget(
              controller: ctrl,
              field: field,
              autovalidateMode: mode,
            ),
    );
  }
}

/// Indicateur d'étape accessible : « Étape k/N » + titre. `Semantics` explicite,
/// insets **directionnels**, style dérivé du thème (aucun littéral — AD-13/FR-26).
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.index,
    required this.total,
    required this.title,
  });

  final int index;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final position = '${index + 1}/$total';
    final resolvedTitle =
        label(context, title, fallback: title);
    return Semantics(
      header: true,
      label: 'Étape ${index + 1} sur $total : $resolvedTitle',
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Row(
          children: <Widget>[
            Text(
              position,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                resolvedTitle,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de navigation accessible & directionnelle (AD-13) : boutons Précédent /
/// Suivant (ou Terminer sur la dernière étape), cibles ≥ 48 dp, `Semantics`
/// explicites, ordre visuel suivant le sens de lecture (Row respecte la
/// `Directionality`, aucun `left`/`right` en dur).
class _StepNavigationBar extends StatelessWidget {
  const _StepNavigationBar({
    required this.isFirst,
    required this.isLast,
    required this.previousLabel,
    required this.nextLabel,
    required this.finishLabel,
    required this.onPrevious,
    required this.onNext,
    required this.finishEnabled,
  });

  final bool isFirst;
  final bool isLast;
  final String previousLabel;
  final String nextLabel;
  final String finishLabel;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final bool finishEnabled;

  @override
  Widget build(BuildContext context) {
    final nextEnabled = !isLast || finishEnabled;
    // Les boutons Material exposent NATIVEMENT une sémantique explicite (rôle
    // `button`, `label` fusionné depuis le `Text`, état `enabled` dérivé de
    // `onPressed`, action de tap). On ne SURajoute PAS de `Semantics(label:)`
    // (nœud dupliqué) : la `ConstrainedBox` garantit seulement la cible ≥ 48 dp
    // (AD-13). L'ordre visuel Précédent→Suivant suit la `Directionality` (Row).
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      child: Row(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: OutlinedButton(
              onPressed: onPrevious,
              child: Text(previousLabel, textAlign: TextAlign.start),
            ),
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: FilledButton(
              onPressed: nextEnabled ? onNext : null,
              child: Text(
                isLast ? finishLabel : nextLabel,
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
