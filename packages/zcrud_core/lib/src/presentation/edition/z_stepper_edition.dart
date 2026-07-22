/// `ZStepperEdition` — présentation d'un formulaire long en **assistant (wizard)
/// multi-étapes** partitionnant le **MÊME** `ZFormController` (E3-5, AD-2 /
/// OBJECTIF PRODUIT N°1 / SM-1). Enrichi DP-9 (parité DODLP `StepperConfig`) :
/// style/orientation/position d'indicateur configurables, icône + sous-titre par
/// étape, gate `validateOnNext` configurable, navigation par tap, et **steppers
/// IMBRIQUÉS** sur le même controller unique.
///
/// origine: `EditionFieldType.stepper` n'est PAS un champ-feuille — le dispatcher
/// (E3-3a) le classe volontairement `unsupported` car c'est un **REGROUPEMENT /
/// structure de navigation** renvoyé ici. E3-5 le sert donc au niveau
/// **orchestration**, posé AUTOUR du dispatcher existant, jamais comme un
/// `ZFieldWidget`. Le nesting (DP-9) est donc **structurel** (porté par
/// [ZEditionStep.nestedSteps]), PAS routé via `ZWidgetRegistry` (qui mappe un
/// `kind` → widget-feuille et casserait le single-writer de `visibleFields`).
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - **UN seul `ZFormController` partagé** à **tous** les niveaux de nesting :
///   toutes les étapes (racine et imbriquées) lisent/écrivent le même controller
///   (mêmes tranches). Il n'existe JAMAIS de controller par étape/niveau, ni de
///   recréation → l'**état est préservé** en va-et-vient (les tranches survivent
///   au démontage des sous-arbres d'étape ; libérées seulement au `dispose` du
///   controller, possédé par l'hôte).
/// - **SINGLE WRITER de `controller.visibleFields`** (DP-9, AC13) : le stepper
///   **RACINE** est le SEUL écrivain ; il publie l'**union des champs visibles le
///   long du chemin d'étapes actif** (étape parente active → sous-étape active du
///   nested → récursivement). Un stepper **imbriqué** tourne en mode « sans
///   fenêtre » : il ne fait PAS `setVisibleFields` ; il **remonte** sa
///   contribution au parent (via [onNestedWindowChanged]) que le racine agrège.
///   Deux niveaux ne se battent donc jamais sur `visibleFields`. Les zones
///   d'étape (imbriquées) rendent `DynamicEdition` en **mode passif**
///   (`manageVisibility:false`).
/// - **AUCUN `Form`/`FormBuilder` global** à aucun niveau : chaque étape réutilise
///   [DynamicEdition] (donc des `TextFormField` **autonomes**). `find.byType(Form)`
///   reste `findsNothing`. La validation reste **par champ**.
/// - **Validation PAR ÉTAPE configurable** : la transition « suivant » valide les
///   champs **visibles** de l'étape courante **ssi `config.validateOnNext`**
///   (défaut `true` = gate strict E3-5 ; `false` = navigation LIBRE, parité DODLP
///   §2.6). Le gate d'un parent honore la **sous-étape active du nested**
///   (l'union). Étape invalide ⇒ navigation bloquée + erreurs **révélées** (bascule
///   locale `AutovalidateMode.always` via un seam additif — jamais un `Form`
///   global). « Précédent » est inconditionnel.
/// - **Chrome = canaux STRUCTURELS only** (SM-1) : la barre d'étapes + la
///   navigation + la zone d'étape n'observent QUE l'index courant ([_currentStep]),
///   le canal de révélation ([_reveal]) et `controller.visibleFields` — JAMAIS une
///   tranche de valeur (sauf les champs de **garde** conditionnels, canal
///   structurel). Une frappe (champ non-garde) ne reconstruit donc QUE le champ
///   courant, jamais le chrome (zéro perte de focus), à tout niveau de nesting.
///
/// **Frontière E3-6** : la dernière étape délègue la **soumission** à E3-6 (slot
/// [onComplete]) ; E3-5 ne fait PAS de `onSubmit`, de détection *dirty*, ni de
/// validateurs **inter-champs**. Composition orthogonale E3-4 : une étape peut
/// contenir sections repliables + champs conditionnels (hérités de [DynamicEdition]).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/edition/z_condition.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import '../z_form_controller.dart';
import 'dynamic_edition.dart';
import 'z_field_widget.dart';
import 'z_responsive_grid.dart';
import 'z_stepper_config.dart';
import 'z_validator_compiler.dart';

export 'z_stepper_config.dart';

/// Descripteur **présentation** d'une étape : un titre + le sous-ensemble de
/// **noms de champs** du catalogue qu'elle regroupe (aligné sur [ZEditionSection]
/// — titre + noms, PAS une nouvelle donnée de formulaire). Additif, `const`.
///
/// DP-9 (parité DODLP `stepIcon`/`stepSubtitle` + stepper récursif) ajoute, de
/// façon strictement additive : [icon] et [subtitle] (métadonnées d'affichage
/// par étape), et [nestedSteps]/[nestedConfig] (sous-stepper imbriqué rendu sur
/// le MÊME controller). Le constructeur reste `const` et source-compatible (les
/// sites existants sans ces paramètres compilent inchangés).
@immutable
class ZEditionStep {
  /// Construit une étape de titre [title] regroupant les champs [fields] (par
  /// nom, dans l'ordre indicatif ; l'ordre effectif de rendu suit l'ordre
  /// canonique du catalogue via [DynamicEdition]).
  const ZEditionStep({
    required this.title,
    required this.fields,
    this.sections = const <ZEditionSection>[],
    this.icon,
    this.subtitle,
    this.nestedSteps,
    this.nestedConfig,
  });

  /// Titre affiché de l'étape (clé l10n ou littéral — résolu côté hôte).
  final String title;

  /// Noms de champs appartenant à l'étape (sous-ensemble du catalogue).
  final List<String> fields;

  /// Sections **visuelles** internes à l'étape (E3-4), restreintes à ses champs.
  /// Vide = liste plate. Orthogonal au partitionnement en étapes.
  final List<ZEditionSection> sections;

  /// Icône d'étape (DP-9, parité `stepIcon`) — consommée en style
  /// [ZStepStyle.icons] (repli sur le numéro si `null`). Défaut `null`.
  final IconData? icon;

  /// Sous-titre d'étape (DP-9, parité `stepSubtitle`) — clé l10n ou littéral,
  /// affiché ssi `config.showSubtitles` (via `label(context, …)`). Défaut `null`.
  final String? subtitle;

  /// Sous-étapes d'un **stepper imbriqué** (DP-9, AC11). Quand non `null`,
  /// l'étape rend, dans son contenu, un [ZStepperEdition] imbriqué partageant le
  /// **MÊME** controller (jamais un controller par niveau). Défaut `null`.
  final List<ZEditionStep>? nestedSteps;

  /// Configuration du sous-stepper imbriqué (défaut `null` ⇒ `ZStepperConfig()`).
  /// Son `validateOnNext` est **indépendant** de celui du parent.
  final ZStepperConfig? nestedConfig;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZEditionStep &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          listEquals(fields, other.fields) &&
          listEquals(sections, other.sections) &&
          icon == other.icon &&
          subtitle == other.subtitle &&
          listEquals(nestedSteps, other.nestedSteps) &&
          nestedConfig == other.nestedConfig;

  @override
  int get hashCode => Object.hash(
        title,
        Object.hashAll(fields),
        Object.hashAll(sections),
        icon,
        subtitle,
        nestedSteps == null ? null : Object.hashAll(nestedSteps!),
        nestedConfig,
      );

  @override
  String toString() => 'ZEditionStep(title: $title, fields: $fields, '
      'icon: $icon, subtitle: $subtitle, '
      'nested: ${nestedSteps?.length ?? 0})';
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
    this.config = const ZStepperConfig(),
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
    this.nested = false,
    this.onNestedWindowChanged,
    this.revealTrigger,
    super.key,
  });

  /// Contrôleur **unique** détenant l'état (créé/possédé par l'hôte ; jamais
  /// recréé ici, jamais un par étape/niveau).
  final ZFormController controller;

  /// Catalogue complet des champs connus (source des [ZFieldSpec] par nom). Le
  /// MÊME catalogue est transmis à un sous-stepper imbriqué.
  final List<ZFieldSpec> fields;

  /// Étapes ordonnées partitionnant le catalogue.
  final List<ZEditionStep> steps;

  /// Configuration visuelle & comportementale (DP-9). Défaut `const
  /// ZStepperConfig()` = comportement E3-5 **inchangé** (top/horizontal/numbered
  /// « k/N » + titre, gate strict).
  final ZStepperConfig config;

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

  /// **Interne (DP-9)** : `true` quand ce stepper est **imbriqué** dans une étape
  /// parente. Un stepper imbriqué tourne en mode « sans fenêtre » (n'écrit JAMAIS
  /// `visibleFields` ; remonte sa contribution via [onNestedWindowChanged]).
  @visibleForTesting
  final bool nested;

  /// **Interne (DP-9)** : callback par lequel un stepper imbriqué **remonte** sa
  /// contribution de fenêtre (union de son chemin actif) au parent, qui agrège
  /// jusqu'au racine (seul écrivain de `visibleFields`).
  @visibleForTesting
  final ValueChanged<List<String>>? onNestedWindowChanged;

  /// **Interne (DP-9)** : signal de **révélation** poussé par le parent (gate
  /// bloqué) pour forcer ce stepper imbriqué à révéler les erreurs de sa
  /// sous-étape active. Chaque incrément déclenche `AutovalidateMode.always`.
  @visibleForTesting
  final ValueListenable<int>? revealTrigger;

  @override
  State<ZStepperEdition> createState() => _ZStepperEditionState();
}

class _ZStepperEditionState extends State<ZStepperEdition> {
  /// Canal STRUCTUREL local : index de l'étape montée (jamais une tranche).
  late final ValueNotifier<int> _currentStep;

  /// Canal STRUCTUREL local : révélation forcée des erreurs de l'étape courante
  /// (bascule `AutovalidateMode.always`). Piloté par un « suivant » bloqué ou par
  /// un [revealTrigger] parent ; remis à `false` à toute navigation effective.
  late final ValueNotifier<bool> _reveal;

  /// Signal de révélation poussé aux sous-steppers imbriqués (DP-9) quand un gate
  /// bloque : incrémenté pour révéler les champs de la sous-étape active.
  late final ValueNotifier<int> _childRevealTick;

  /// Listenable fusionné observé par le chrome : index + révélation +
  /// `visibleFields` (structurel). AUCUNE tranche de valeur (SM-1/AC11).
  late Listenable _structural;

  /// Index `name → spec` (identité de valeur ; recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Cache de validateurs compilés **mémoïsés** par nom de champ (E3-2 réutilisé).
  final Map<String, FormFieldValidator<String>?> _validatorCache =
      <String, FormFieldValidator<String>?>{};

  /// Tranches des champs de **garde** (mode nesting) auxquelles [_onGuardChanged]
  /// est abonné pour recalculer la fenêtre du chemin actif.
  final List<Listenable> _guardListenables = <Listenable>[];

  /// Dernière contribution de fenêtre remontée par le sous-stepper imbriqué monté
  /// (`null` = pas encore remontée ⇒ on retombe sur le calcul structurel initial).
  List<String>? _childContribution;

  int get _lastStep => widget.steps.length - 1;

  ZStepperConfig get _config => widget.config;

  /// `true` si au moins une étape porte un sous-stepper imbriqué.
  bool get _hasNesting => widget.steps.any((s) => s.nestedSteps != null);

  /// **Mode « pilotage racine/nesting »** : ce stepper (racine avec nesting, ou
  /// lui-même imbriqué) gère la fenêtre = union du chemin actif, et rend ses
  /// zones d'étape en `DynamicEdition` **passif** (`manageVisibility:false`). En
  /// mode LEGACY (ni imbriqué, ni de nesting), le comportement E3-5 est **exact**
  /// (DynamicEdition gère `visibleFields`, `_syncWindow` sur navigation).
  bool get _driving => widget.nested || _hasNesting;

  @override
  void initState() {
    super.initState();
    final start = widget.initialStep.clamp(0, _lastStep < 0 ? 0 : _lastStep);
    _currentStep = ValueNotifier<int>(start);
    _reveal = ValueNotifier<bool>(false);
    _childRevealTick = ValueNotifier<int>(0);
    _rebuildIndexes();
    _bindStepperGuards();
    _structural = _mergeStructural();
    widget.revealTrigger?.addListener(_onRevealTrigger);
    _initWindow(start);
  }

  Listenable _mergeStructural() => Listenable.merge(<Listenable?>[
        _currentStep,
        _reveal,
        widget.controller.visibleFields,
      ]);

  @override
  void didUpdateWidget(ZStepperEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged || !identical(oldWidget.fields, widget.fields)) {
      _rebuildIndexes();
      _validatorCache.clear();
      _bindStepperGuards();
    }
    if (controllerChanged) {
      _structural = _mergeStructural();
      _initWindow(_currentStep.value);
    }
    if (oldWidget.revealTrigger != widget.revealTrigger) {
      oldWidget.revealTrigger?.removeListener(_onRevealTrigger);
      widget.revealTrigger?.addListener(_onRevealTrigger);
    }
  }

  void _rebuildIndexes() {
    _specByName = <String, ZFieldSpec>{
      for (final f in widget.fields) f.name: f,
    };
  }

  @override
  void dispose() {
    widget.revealTrigger?.removeListener(_onRevealTrigger);
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    _currentStep.dispose();
    _reveal.dispose();
    _childRevealTick.dispose();
    super.dispose();
  }

  // ── Fenêtre d'étape (single-writer racine / contribution nested) ────────────

  /// Specs (dans l'ordre déclaré de l'étape) des champs connus de l'étape [i].
  List<ZFieldSpec> _stepSpecs(int i) => <ZFieldSpec>[
        for (final name in widget.steps[i].fields)
          if (_specByName[name] != null) _specByName[name]!,
      ];

  bool _condVisible(ZFieldSpec f) =>
      f.condition == null ||
      evaluateZCondition(f.condition!, widget.controller.valueOf);

  /// Champs **directs visibles** (conditionnels honorés) d'une étape, en ordre
  /// canonique du catalogue (cohérent avec [DynamicEdition]).
  List<String> _visibleDirectOf(ZEditionStep step) {
    final names = step.fields.toSet();
    return <String>[
      for (final f in widget.fields)
        if (names.contains(f.name) && _condVisible(f)) f.name,
    ];
  }

  /// Fenêtre directe (compat E3-5) des champs visibles de l'étape [i].
  List<String> _windowFor(int i) => _visibleDirectOf(widget.steps[i]);

  /// Calcul **structurel** récursif de la fenêtre = union du chemin actif à
  /// partir de [steps]/[index], en supposant chaque nested à sa sous-étape 0.
  /// Sert l'amorçage racine et le repli quand un sous-stepper n'a pas encore
  /// remonté sa contribution.
  List<String> _initialUnion(List<ZEditionStep> steps, int index) {
    if (steps.isEmpty) return const <String>[];
    final i = index.clamp(0, steps.length - 1);
    final step = steps[i];
    final base = _visibleDirectOf(step);
    final nested = step.nestedSteps;
    if (nested == null) return base;
    return <String>[...base, ..._initialUnion(nested, 0)];
  }

  /// Contribution de fenêtre de CE stepper pour son étape courante : champs
  /// directs visibles + (si l'étape courante porte un nested) la contribution
  /// remontée par le sous-stepper (ou son calcul structurel initial en repli).
  List<String> _contribution() {
    final i = _currentStep.value.clamp(0, _lastStep < 0 ? 0 : _lastStep);
    final base = _windowFor(i);
    final nested = widget.steps[i].nestedSteps;
    if (nested == null) return base;
    final childPart = _childContribution ?? _initialUnion(nested, 0);
    return <String>[...base, ...childPart];
  }

  /// Amorçage de la fenêtre selon le mode.
  /// CR-IFFD-22 — le stepper est le **seul écrivain** de `visibleFields` et
  /// calcule sa fenêtre depuis `ZCondition` uniquement. Une cible `visible` de
  /// `ZDerivation` n'y est donc **PAS appliquée** : le champ resterait visible
  /// alors que la dérivation le masque.
  ///
  /// Cette limite est **signalée**, jamais silencieuse (même idiome que
  /// `ZSyncMeta.collidingReservedKeys`) : une capacité déclarée que personne
  /// n'applique est précisément le défaut que ces demandes reprochent. Le
  /// correctif — faire porter la composition au stepper — touche son invariant
  /// de single-writer et relève d'un chantier à part, pas d'un ajout de passage.
  ///
  /// ⚠️ Les cibles `value`, `options` et `bounds`, elles, fonctionnent
  /// normalement sous stepper : seule `visible` est concernée.
  void _warnDerivedVisibilityUnsupported() {
    assert(() {
      final ignored = <String>[
        for (final f in widget.fields)
          if (f.derivedFrom?.visible != null) f.name,
      ];
      if (ignored.isEmpty) return true;
      // ignore: avoid_print
      print(
        'ZStepperEdition — ⚠️ VISIBILITÉ DÉRIVÉE NON APPLIQUÉE : '
        '${ignored.join(', ')}. Le stepper compose sa fenêtre depuis '
        '`ZCondition` seule ; la cible `visible` de `ZDerivation` est IGNORÉE '
        'ici (elle fonctionne sous `DynamicEdition`). Exprimez la condition '
        'avec `ZCondition` si elle doit valoir dans un stepper.',
      );
      return true;
    }());
  }

  void _initWindow(int start) {
    _warnDerivedVisibilityUnsupported();
    if (widget.nested) {
      // Imbriqué : reporter la contribution APRÈS la première frame (éviter un
      // `notifyListeners` du controller pendant le build du parent).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishWindow();
      });
      return;
    }
    if (_driving) {
      // Racine avec nesting : seul écrivain — pose l'union initiale du chemin.
      widget.controller.setVisibleFields(_initialUnion(widget.steps, start));
      return;
    }
    // LEGACY (aucun nesting) : comportement E3-5 exact.
    _syncWindow(start);
  }

  /// Publie la fenêtre : le RACINE écrit `visibleFields` (single-writer) ; un
  /// stepper IMBRIQUÉ remonte sa contribution au parent (jamais d'écriture).
  void _publishWindow() {
    final w = _contribution();
    if (widget.nested) {
      widget.onNestedWindowChanged?.call(w);
    } else {
      widget.controller.setVisibleFields(w);
    }
  }

  /// Reçoit la contribution d'un sous-stepper imbriqué et ré-agrège vers le haut.
  void _onChildWindow(List<String> w) {
    _childContribution = w;
    _publishWindow();
  }

  /// LEGACY only : aligne `controller.visibleFields` sur la fenêtre directe de
  /// l'étape [i] (no-op si inchangé). Ne DÉTRUIT jamais de tranche.
  void _syncWindow(int i) {
    if (i < 0 || i > _lastStep) return;
    widget.controller.setVisibleFields(_windowFor(i));
  }

  // ── Souscription aux champs de garde (mode nesting) ─────────────────────────

  /// (Ré)abonne [_onGuardChanged] aux champs de garde de CE niveau (union des
  /// `field` référencés par les conditions des champs de ses étapes) — UNIQUEMENT
  /// en mode `_driving` (le racine/nested pilote alors la fenêtre lui-même, les
  /// `DynamicEdition` étant passifs). En mode LEGACY, c'est [DynamicEdition] qui
  /// gère les gardes (aucun abonnement ici). Une frappe sur un champ **non-garde**
  /// ne déclenche donc AUCUN recalcul (SM-1).
  void _bindStepperGuards() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    if (!_driving) return;
    final conditions = <ZCondition?>[
      for (final step in widget.steps)
        for (final name in step.fields)
          if (_specByName[name]?.condition != null) _specByName[name]!.condition,
    ];
    for (final g in zGuardFieldsOf(conditions)) {
      final l = widget.controller.fieldListenable(g);
      l.addListener(_onGuardChanged);
      _guardListenables.add(l);
    }
  }

  void _onGuardChanged() => _publishWindow();

  void _onRevealTrigger() {
    _reveal.value = true;
    // Propage aux niveaux plus profonds (nesting de nesting).
    _childRevealTick.value = _childRevealTick.value + 1;
  }

  // ── Validation PAR ÉTAPE (gate de navigation) ──────────────────────────────

  FormFieldValidator<String>? _validatorFor(ZFieldSpec spec) =>
      _validatorCache.putIfAbsent(
        spec.name,
        () => ZValidatorCompiler.compile(spec.validators),
      );

  static String _stringOf(Object? value) => value == null ? '' : '$value';

  bool _validatorPasses(ZFieldSpec spec) {
    final validator = _validatorFor(spec);
    if (validator == null) return true;
    return validator(_stringOf(widget.controller.valueOf(spec.name))) == null;
  }

  /// `true` ssi TOUS les champs **visibles** de l'étape [i] passent leurs
  /// validateurs champ-locaux (E3-2). Un champ masqué par condition n'est PAS
  /// validé (AC13) ; une étape sans champ visible passe trivialement.
  bool _validateStep(int i) {
    if (i < 0 || i > _lastStep) return true;
    final visible = _windowFor(i).toSet();
    for (final spec in _stepSpecs(i)) {
      if (!visible.contains(spec.name)) continue;
      if (!_validatorPasses(spec)) return false;
    }
    return true;
  }

  /// `true` ssi tous les champs de l'ensemble [names] (déjà visibles) passent.
  bool _validateNames(Iterable<String> names) {
    for (final name in names) {
      final spec = _specByName[name];
      if (spec == null) continue;
      if (!_validatorPasses(spec)) return false;
    }
    return true;
  }

  /// Gate de l'étape courante : en mode `_driving`, valide l'**union** du chemin
  /// actif (parent direct + sous-étape active du nested — AC12) ; en LEGACY,
  /// valide la fenêtre directe (E3-5 exact).
  bool _validateGate(int i) =>
      _driving ? _validateNames(_contribution()) : _validateStep(i);

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(int target) {
    if (target < 0 || target > _lastStep || target == _currentStep.value) {
      return;
    }
    _reveal.value = false;
    if (_driving) {
      _childContribution = null; // le sous-arbre change : recalcul structurel.
      _currentStep.value = target;
      _publishWindow();
    } else {
      _syncWindow(target);
      _currentStep.value = target;
    }
    widget.onStepChanged?.call(target);
  }

  void _revealBlock() {
    _reveal.value = true; // canal structurel → révèle sans `Form` global.
    if (_driving) {
      // Révèle aussi les champs de la sous-étape active d'un nested (AC12).
      _childRevealTick.value = _childRevealTick.value + 1;
    }
  }

  /// « Suivant » : gate configurable (AC12). Bloqué ⇒ erreurs révélées. Sur la
  /// dernière étape ⇒ délègue à [onComplete] (E3-6).
  void _next() {
    final current = _currentStep.value;
    final passes = !_config.validateOnNext || _validateGate(current);
    if (current >= _lastStep) {
      if (passes) {
        widget.onComplete?.call();
      } else {
        _revealBlock();
      }
      return;
    }
    if (passes) {
      _goTo(current + 1);
    } else {
      _revealBlock();
    }
  }

  /// « Précédent » : INCONDITIONNEL (jamais de gate en arrière — AC6).
  void _previous() {
    final current = _currentStep.value;
    if (current > 0) _goTo(current - 1);
  }

  /// Navigation par **tap** sur l'indicateur (AC10) : retour arrière libre ; saut
  /// avant soumis au même gate que « Suivant » (`validateOnNext`).
  void _jumpTo(int target) {
    final current = _currentStep.value;
    if (target < 0 || target > _lastStep || target == current) return;
    if (target < current) {
      _goTo(target); // retour arrière inconditionnel.
      return;
    }
    if (_config.validateOnNext) {
      if (!_validateGate(current)) {
        _revealBlock();
        return;
      }
      for (var k = current + 1; k < target; k++) {
        if (!_validateStep(k)) {
          _revealBlock();
          return;
        }
      }
    }
    _goTo(target);
  }

  // ── Rendu ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    // Chrome scellé sur les canaux STRUCTURELS uniquement (SM-1/AC11).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final index = _currentStep.value.clamp(0, _lastStep);
        final reveal = _reveal.value;
        final indicator = _StepIndicator(
          index: index,
          total: widget.steps.length,
          steps: widget.steps,
          config: _config,
          onStepTap: _config.allowStepTap ? _jumpTo : null,
        );
        final content = _stepContent(index, reveal);
        final nav = _StepNavigationBar(
          isFirst: index == 0,
          isLast: index == _lastStep,
          previousLabel: widget.previousLabel ??
              label(context, 'z.stepper.previous', fallback: 'Précédent'),
          nextLabel: widget.nextLabel ??
              label(context, 'z.stepper.next', fallback: 'Suivant'),
          finishLabel: widget.finishLabel ??
              label(context, 'z.stepper.finish', fallback: 'Terminer'),
          onPrevious: index == 0 ? null : _previous,
          onNext: _next,
          finishEnabled: widget.onComplete != null,
        );
        return _layout(indicator, content, nav);
      },
    );
  }

  /// Compose indicateur / contenu / navigation selon `indicatorPosition`
  /// (directionnel — `start` = côté début de lecture).
  Widget _layout(Widget indicator, Widget content, Widget nav) {
    final expandedContent = Expanded(child: content);
    switch (_config.indicatorPosition) {
      case ZStepIndicatorPosition.start:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[indicator, Expanded(child: content)],
              ),
            ),
            nav,
          ],
        );
      case ZStepIndicatorPosition.bottom:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[expandedContent, indicator, nav],
        );
      case ZStepIndicatorPosition.top:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[indicator, expandedContent, nav],
        );
    }
  }

  /// Zone d'étape : réutilise [DynamicEdition] (place stable/conditionnels/
  /// sections/grille). En mode `_driving`, le formulaire est **passif**
  /// (`manageVisibility:false`) — le racine est seul écrivain de `visibleFields`.
  /// Si l'étape porte un sous-stepper (AC11), il est rendu **après** les champs
  /// directs sur le MÊME controller (imbriqué, mode « sans fenêtre »).
  Widget _stepContent(int index, bool reveal) {
    final step = widget.steps[index];
    final mode = reveal
        ? AutovalidateMode.always
        : AutovalidateMode.onUserInteraction;
    final custom = widget.fieldBuilder;
    final hasNested = step.nestedSteps != null;

    final edition = DynamicEdition(
      key: ValueKey<String>('zstep:$index'),
      controller: widget.controller,
      fields: _stepSpecs(index),
      sections: step.sections,
      padding: widget.padding,
      physics: hasNested ? const NeverScrollableScrollPhysics() : widget.physics,
      shrinkWrap: hasNested,
      manageVisibility: !_driving,
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

    if (!hasNested) return edition;

    // Étape porteuse d'un sous-stepper imbriqué : champs directs (dimensionnés
    // au contenu) au-dessus, sous-stepper dans l'espace restant. MÊME controller.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (step.fields.isNotEmpty) edition,
        Expanded(
          child: ZStepperEdition(
            key: ValueKey<String>('znest:$index'),
            controller: widget.controller,
            fields: widget.fields,
            steps: step.nestedSteps!,
            config: step.nestedConfig ?? const ZStepperConfig(),
            padding: widget.padding,
            physics: widget.physics,
            readOnly: widget.readOnly,
            layout: widget.layout,
            gridGutter: widget.gridGutter,
            fieldBuilder: widget.fieldBuilder,
            previousLabel: widget.previousLabel,
            nextLabel: widget.nextLabel,
            finishLabel: widget.finishLabel,
            nested: true,
            onNestedWindowChanged: _onChildWindow,
            revealTrigger: _childRevealTick,
          ),
        ),
      ],
    );
  }
}

/// Indicateur d'étape accessible & configurable (DP-9). `Semantics(header:true)`
/// avec libellé « Étape k sur N : titre » (rétro-compat E3-5), insets et
/// alignements **directionnels**, couleurs dérivées du `ColorScheme` ou des
/// overrides nullables de [ZStepperConfig] (aucun littéral — AD-13/FR-26/AD-6).
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.index,
    required this.total,
    required this.steps,
    required this.config,
    required this.onStepTap,
  });

  final int index;
  final int total;
  final List<ZEditionStep> steps;
  final ZStepperConfig config;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedTitle = label(context, steps[index].title,
        fallback: steps[index].title);
    final subtitle = steps[index].subtitle;

    final children = <Widget>[
      _indicatorBody(context, scheme, resolvedTitle),
      if (config.showSubtitles && subtitle != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: Text(
            label(context, subtitle, fallback: subtitle),
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];

    return Semantics(
      header: true,
      label: 'Étape ${index + 1} sur $total : $resolvedTitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _indicatorBody(
      BuildContext context, ColorScheme scheme, String resolvedTitle) {
    switch (config.style) {
      case ZStepStyle.numbered:
        return _compact(
          context,
          leading: Text(
            '${index + 1}/$total',
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          title: resolvedTitle,
        );
      case ZStepStyle.icons:
        final icon = steps[index].icon;
        return _compact(
          context,
          leading: icon != null
              ? Icon(icon, color: config.activeOf(scheme))
              : Text(
                  '${index + 1}/$total',
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
          title: resolvedTitle,
        );
      case ZStepStyle.dots:
        return _dots(context, scheme, resolvedTitle);
      case ZStepStyle.progressBar:
        return _progressBar(context, scheme, resolvedTitle);
    }
  }

  /// Rendu compact « leading + titre » (numbered/icons) — reproduit l'indicateur
  /// historique E3-5 en style `numbered` par défaut.
  Widget _compact(BuildContext context,
      {required Widget leading, required String title}) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          leading,
          if (config.showLabels) ...<Widget>[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Rendu `dots` : un marqueur par étape (tappable si `allowStepTap`), en `Row`
  /// (horizontal) ou `Column` (vertical). Couleurs dérivées de l'état.
  Widget _dots(BuildContext context, ColorScheme scheme, String title) {
    final markers = <Widget>[
      for (var k = 0; k < total; k++)
        _dot(context, scheme, k),
    ];
    final band = config.orientation == ZStepOrientation.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: markers)
        : Row(mainAxisSize: MainAxisSize.min, children: markers);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          band,
          if (config.showLabels) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, ColorScheme scheme, int k) {
    final color = k == index
        ? config.activeOf(scheme)
        : (k < index ? config.completedOf(scheme) : config.inactiveOf(scheme));
    final size = config.indicatorSize.clamp(8.0, 24.0);
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    final labelled = Semantics(
      button: onStepTap != null,
      label: 'Étape ${k + 1} sur $total',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: Padding(
            padding: EdgeInsetsDirectional.all(config.stepSpacing.clamp(2.0, 12.0)),
            child: dot,
          ),
        ),
      ),
    );
    if (onStepTap == null) return labelled;
    return InkResponse(onTap: () => onStepTap!(k), child: labelled);
  }

  /// Rendu `progressBar` : progression continue `(k+1)/N`.
  Widget _progressBar(BuildContext context, ColorScheme scheme, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LinearProgressIndicator(
            value: total == 0 ? 0 : (index + 1) / total,
            color: config.activeOf(scheme),
            backgroundColor: config.inactiveOf(scheme),
          ),
          if (config.showLabels) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
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
