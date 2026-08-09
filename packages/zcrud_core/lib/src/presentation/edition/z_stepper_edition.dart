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
import '../theme/z_theme.dart';
import '../z_form_controller.dart';
import '../z_rich_text_renderer.dart';
import '../zcrud_scope.dart';
import 'dynamic_edition.dart';
import 'z_field_widget.dart';
import 'z_responsive_grid.dart';
import 'z_step_index_store.dart';
import 'z_stepper_config.dart';
import 'z_validator_compiler.dart';

export 'z_step_index_store.dart';
export 'z_stepper_config.dart';

/// Profondeur maximale de steppers imbriqués (AD-10).
///
/// 🔴 [ZEditionStep.nestedSteps] est une `List<ZEditionStep>?` **mutable** : un
/// hôte PEUT construire un cycle (`l = []; s = ZEditionStep(nestedSteps: l);
/// l.add(s);`). Sans plafond, le calcul de fenêtre comme le montage de widgets
/// récursent sans fin (StackOverflow, écran blanc). Au-delà de ce plafond, le
/// sous-stepper n'est **pas monté** et sa contribution n'est **pas comptée** :
/// repli DÉFINI, jamais d'exception.
const int kZStepperMaxNestingDepth = 8;

/// Largeur maximale (dp) de référence de la bande latérale `start` — bornage du
/// Bug 1. Surchargée par `ZcrudTheme.stepperSideBandMaxWidth`.
const double _kStepperSideBandMaxWidth = 220;

/// Épaisseur (dp) de référence du rail — mesure du legacy DODLP.
const double _kStepperRailThickness = 1;

/// Écart vertical (dp) de référence entre deux étapes dépliées — mesure legacy.
const double _kStepperAllStepsGap = 24;

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
    this.subtitleWidget,
    this.nestedSteps,
    this.nestedConfig,
    this.condition,
    this.optional = false,
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
  ///
  /// C'est une **`String`**, jamais un widget : la chaîne traverse le seam de
  /// rendu riche (`ZcrudScope.richTextRenderer`) telle quelle. Pour fournir un
  /// widget déjà construit, utiliser [subtitleWidget].
  final String? subtitle;

  /// Sous-titre d'étape **déjà construit** par l'hôte. Défaut `null`.
  ///
  /// 🔴 **[subtitleWidget] PRIME sur [subtitle]**, et le seam de rendu riche
  /// n'est alors **pas consulté** : le widget est rendu **tel que reçu**. C'est
  /// exactement la règle — et le nommage — de `ZcrudTheme.inputDecoration`
  /// (`label` widget prioritaire, `labelText` chaîne sinon) ; une troisième
  /// convention pour la même idée serait une divergence.
  ///
  /// ## Pourquoi DEUX entrées, et non un seul champ `Object?`
  ///
  /// Le legacy DODLP stocke un `Widget` puis **redéballe la chaîne** par
  /// `if (step.subtitle is Text) … (step.subtitle as Text).data ?? ""`
  /// (`dynamic_stepper.dart` l. 397-407 et 789-793) : une donnée qui voyage
  /// dans un widget et qu'on récupère au cast. Avec deux entrées typées, ce cast
  /// n'a plus de raison d'être — le défaut devient **inexprimable**, ce qui vaut
  /// mieux que de le corriger.
  ///
  /// [ZStepperConfig.showSubtitles] gouverne les **deux** entrées : le drapeau
  /// dit « cette présentation montre des sous-titres », pas « cette présentation
  /// montre les sous-titres de type chaîne ». Un hôte qui veut un contenu
  /// toujours visible ne le met pas en sous-titre.
  final Widget? subtitleWidget;

  /// Sous-étapes d'un **stepper imbriqué** (DP-9, AC11). Quand non `null`,
  /// l'étape rend, dans son contenu, un [ZStepperEdition] imbriqué partageant le
  /// **MÊME** controller (jamais un controller par niveau). Défaut `null`.
  final List<ZEditionStep>? nestedSteps;

  /// Configuration du sous-stepper imbriqué (défaut `null` ⇒ `ZStepperConfig()`).
  /// Son `validateOnNext` est **indépendant** de celui du parent.
  final ZStepperConfig? nestedConfig;

  /// Condition d'**EXISTENCE** de l'étape (lot G1+). `null` (défaut) ⇒ l'étape
  /// est toujours là — comportement historique **strictement inchangé**.
  ///
  /// ## Le besoin, nommé
  ///
  /// Un formulaire multi-étapes avancé **branche** : le mode de cargaison
  /// choisi à l'étape 1 décide si l'étape « conteneurs » existe (cas réel
  /// DODLP `cargaison_stepper_form`). Jusqu'ici, seuls les **CHAMPS** étaient
  /// conditionnels (`ZFieldSpec.condition`) : une étape dont tous les champs
  /// disparaissaient restait **présente et vide**, comptée dans le « k/N » et
  /// traversée par la navigation. L'hôte n'avait qu'un recours — recomposer
  /// lui-même sa `List<ZEditionStep>` à chaque frappe, donc reconstruire le
  /// stepper entier (exactement ce que SM-1 interdit).
  ///
  /// ## Ce que la condition gouverne
  ///
  /// Une étape dont la condition est **fausse** est **absente** : pas rendue,
  /// pas comptée dans le total, non atteignable par « suivant »/tap, non
  /// validée par le gate, et ses champs ne sont pas dans la fenêtre.
  ///
  /// 🔴 Le mécanisme **réutilise `ZCondition`** — l'arbre déjà utilisé par les
  /// champs — et son évaluateur : aucun second langage de condition n'est
  /// introduit. Les champs de garde référencés sont abonnés **nommément**
  /// (SM-1 : une frappe sur un champ non-garde ne recalcule rien).
  final ZCondition? condition;

  /// Étape **OPTIONNELLE** (lot G1+) : le gate `validateOnNext` ne s'y applique
  /// pas. Défaut `false` ⇒ comportement historique inchangé.
  ///
  /// Besoin nommé : les formulaires longs ont des étapes « pièces jointes » /
  /// « commentaires » qu'un utilisateur doit pouvoir **traverser sans rien
  /// saisir**, sans pour autant relâcher le gate des étapes obligatoires — ce
  /// que `ZStepperConfig.validateOnNext: false` ferait globalement, tout ou
  /// rien.
  ///
  /// ⚠️ Ne dispense PAS de la validation à la **soumission** (E3-6) : c'est un
  /// assouplissement de la NAVIGATION, pas de la validité des données.
  final bool optional;

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
          subtitleWidget == other.subtitleWidget &&
          listEquals(nestedSteps, other.nestedSteps) &&
          nestedConfig == other.nestedConfig &&
          condition == other.condition &&
          optional == other.optional;

  @override
  int get hashCode => Object.hash(
        title,
        Object.hashAll(fields),
        Object.hashAll(sections),
        icon,
        subtitle,
        subtitleWidget,
        nestedSteps == null ? null : Object.hashAll(nestedSteps!),
        nestedConfig,
        condition,
        optional,
      );

  @override
  String toString() => 'ZEditionStep(title: $title, fields: $fields, '
      'icon: $icon, subtitle: $subtitle, '
      'subtitleWidget: ${subtitleWidget != null}, '
      'nested: ${nestedSteps?.length ?? 0}, '
      'conditional: ${condition != null}, optional: $optional)';
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
    this.depth = 0,
    this.unbounded = false,
    this.stepStore,
    this.formId,
    super.key,
  });

  /// Seam de **reprise** : persiste/restaure l'étape courante (lot G1+).
  /// `null` (défaut) ⇒ aucune persistance, comportement inchangé.
  ///
  /// Même patron que `DynamicEdition.collapseStore` — un hôte branche le même
  /// stockage pour les deux, et le cœur n'en dépend pas (AD-1).
  final ZStepIndexStore? stepStore;

  /// Clé de portée opaque du formulaire pour [stepStore] (`null` ⇒ portée
  /// « globale »). Ignoré si [stepStore] est `null`.
  final String? formId;

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

  /// **Interne** : ce stepper est monté dans un contexte de hauteur **NON
  /// BORNÉE** (item de `ListView.builder` du mode « tout affiché »). Il se
  /// dimensionne alors **au contenu** (`MainAxisSize.min`, aucun `Expanded`
  /// vertical) au lieu de remplir l'espace disponible.
  ///
  /// 🔴 Sans ce mode, un sous-stepper **paginé** posé dans une étape dépliée
  /// lèverait « RenderFlex children have non-zero flex but incoming height
  /// constraints are unbounded » — le pendant exact du Bug 1 sur l'autre axe.
  @visibleForTesting
  final bool unbounded;

  /// **Interne** : profondeur d'imbrication de CE stepper (0 = racine). Plafonné
  /// par [kZStepperMaxNestingDepth] — cf. AD-10 (`nestedSteps` circulaires).
  @visibleForTesting
  final int depth;

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

  /// Dernières contributions de fenêtre remontées par les sous-steppers
  /// imbriqués montés, **indexées par index d'étape**.
  ///
  /// 🔴 Une `Map` et non plus un champ unique : en mode `showAllSteps`, PLUSIEURS
  /// sous-steppers sont montés **simultanément** (une étape dépliée peut en
  /// porter un chacune). Un champ unique ferait que la dernière remontée écrase
  /// toutes les autres — la fenêtre publiée perdrait les champs des autres
  /// sous-steppers. Absent = pas encore remontée ⇒ repli structurel.
  final Map<int, List<String>> _childContributions = <int, List<String>>{};

  /// Étapes **EFFECTIVES** : celles dont la [ZEditionStep.condition] est
  /// satisfaite, dans l'ordre déclaré. Recalculées UNIQUEMENT quand un champ de
  /// garde change (SM-1) — jamais à chaque frappe.
  ///
  /// 🔴 Tout le reste de l'état raisonne sur CETTE liste, jamais sur
  /// `widget.steps` : un index d'étape est donc toujours un index EFFECTIF.
  /// C'est ce qui rend l'absence d'une étape indistinguable, pour la
  /// navigation, le « k/N » et le gate, d'une étape jamais déclarée.
  List<ZEditionStep> _effective = const <ZEditionStep>[];

  List<ZEditionStep> get _steps => _effective;

  /// Tic structurel bumpé quand l'ENSEMBLE des étapes effectives change — le
  /// chrome le observe au même titre que l'index courant (canal STRUCTUREL,
  /// jamais une tranche de valeur).
  late final ValueNotifier<int> _stepsTick = ValueNotifier<int>(0);

  /// Recalcule les étapes effectives. Rend `true` si l'ensemble a CHANGÉ.
  bool _recomputeEffective() {
    final List<ZEditionStep> next = <ZEditionStep>[
      for (final ZEditionStep s in widget.steps)
        if (s.condition == null ||
            evaluateZCondition(s.condition!, widget.controller.valueOf))
          s,
    ];
    final bool changed = !listEquals(next, _effective);
    _effective = next;
    return changed;
  }

  int get _lastStep => _steps.length - 1;

  ZStepperConfig get _config => widget.config;

  /// `true` si au moins une étape porte un sous-stepper imbriqué.
  bool get _hasNesting => _steps.any((s) => s.nestedSteps != null);

  /// **Mode « pilotage racine/nesting »** : ce stepper (racine avec nesting, ou
  /// lui-même imbriqué) gère la fenêtre = union du chemin actif, et rend ses
  /// zones d'étape en `DynamicEdition` **passif** (`manageVisibility:false`). En
  /// mode LEGACY (ni imbriqué, ni de nesting), le comportement E3-5 est **exact**
  /// (DynamicEdition gère `visibleFields`, `_syncWindow` sur navigation).
  /// 🔴 `showAllSteps` FORCE le mode pilotage : toutes les étapes montent leur
  /// `DynamicEdition` **en même temps**. Si chacune gérait `visibleFields`
  /// (`manageVisibility: true`), elles se battraient pour l'écrire — la dernière
  /// montée gagnerait et masquerait les champs de toutes les autres. Le stepper
  /// reste donc le **single writer** (DP-9/AC13) et publie l'union.
  bool get _driving => widget.nested || _hasNesting || _config.showAllSteps;

  /// `true` si CE niveau est au-delà du plafond d'imbrication (AD-10).
  bool get _tooDeep => widget.depth >= kZStepperMaxNestingDepth;

  @override
  void initState() {
    super.initState();
    _recomputeEffective();
    final start = _resolveStartStep();
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
        _stepsTick,
        widget.controller.visibleFields,
      ]);

  /// Étape de DÉPART : reprise persistée si un [ZStepIndexStore] est branché et
  /// rend un index exploitable, sinon [ZStepperEdition.initialStep]. Bornée
  /// dans tous les cas.
  ///
  /// AD-10 — un store d'hôte qui lève ou qui rend un index hors bornes ne fait
  /// PAS échouer le montage : on retombe sur `initialStep`.
  int _resolveStartStep() {
    final int max = _lastStep < 0 ? 0 : _lastStep;
    int? resumed;
    final ZStepIndexStore? store = widget.stepStore;
    if (store != null) {
      try {
        resumed = store.loadStepIndex(widget.formId);
      } catch (_) {
        resumed = null;
      }
    }
    if (resumed != null && resumed >= 0 && resumed <= max) return resumed;
    return widget.initialStep.clamp(0, max);
  }

  /// Persiste l'étape courante si un store est branché (jamais bloquant).
  void _persistStep(int index) {
    final ZStepIndexStore? store = widget.stepStore;
    if (store == null) return;
    try {
      store.saveStepIndex(widget.formId, index);
    } catch (_) {
      // Une persistance fautive ne casse pas la navigation (AD-10).
    }
  }

  @override
  void didUpdateWidget(ZStepperEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged || !identical(oldWidget.fields, widget.fields)) {
      _rebuildIndexes();
      _validatorCache.clear();
      _bindStepperGuards();
    }
    if (!identical(oldWidget.steps, widget.steps)) {
      _bindStepperGuards();
      if (_recomputeEffective()) _onEffectiveStepsChanged();
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
    _stepsTick.dispose();
    _reveal.dispose();
    _childRevealTick.dispose();
    super.dispose();
  }

  // ── Fenêtre d'étape (single-writer racine / contribution nested) ────────────

  /// Specs (dans l'ordre déclaré de l'étape) des champs connus de l'étape [i].
  List<ZFieldSpec> _stepSpecs(int i) => <ZFieldSpec>[
        for (final name in _steps[i].fields)
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
  List<String> _windowFor(int i) => _visibleDirectOf(_steps[i]);

  /// Calcul **structurel** récursif de la fenêtre = union du chemin actif à
  /// partir de [steps]/[index], en supposant chaque nested à sa sous-étape 0.
  /// Sert l'amorçage racine et le repli quand un sous-stepper n'a pas encore
  /// remonté sa contribution.
  List<String> _initialUnion(List<ZEditionStep> steps, int index,
      [int depth = 0]) {
    if (steps.isEmpty) return const <String>[];
    final i = index.clamp(0, steps.length - 1);
    final step = steps[i];
    final base = _visibleDirectOf(step);
    final nested = step.nestedSteps;
    // AD-10 : au-delà du plafond, on ARRÊTE la descente (cycle possible).
    if (nested == null || widget.depth + depth + 1 >= kZStepperMaxNestingDepth) {
      return base;
    }
    return <String>[...base, ..._initialUnion(nested, 0, depth + 1)];
  }

  /// Union de TOUTES les étapes effectives (mode `showAllSteps`) : c'est la
  /// fenêtre publiée, puisqu'il n'existe pas d'étape « courante ».
  List<String> _allStepsUnion() {
    final out = <String>[];
    final seen = <String>{};
    for (var i = 0; i < _steps.length; i++) {
      for (final n in _windowFor(i)) {
        if (seen.add(n)) out.add(n);
      }
      final nested = _steps[i].nestedSteps;
      if (nested == null) continue;
      for (final n in _childContributions[i] ?? _initialUnion(nested, 0)) {
        if (seen.add(n)) out.add(n);
      }
    }
    return out;
  }

  /// Contribution de fenêtre de CE stepper pour son étape courante : champs
  /// directs visibles + (si l'étape courante porte un nested) la contribution
  /// remontée par le sous-stepper (ou son calcul structurel initial en repli).
  List<String> _contribution() {
    if (_config.showAllSteps) return _allStepsUnion();
    final i = _currentStep.value.clamp(0, _lastStep < 0 ? 0 : _lastStep);
    final base = _windowFor(i);
    final nested = _steps[i].nestedSteps;
    if (nested == null) return base;
    final childPart = _childContributions[i] ?? _initialUnion(nested, 0);
    // 🔴 UNION, pas concaténation. Un même nom peut apparaître à deux niveaux
    // (étape parente ET sous-étape) : le publier deux fois ferait monter le
    // champ deux fois dans `DynamicEdition` — deux widgets sur la même tranche.
    // Mesuré sur le cas limite AD-10 (`nestedSteps` circulaires) : la fenêtre
    // sortait à `['a'] × 10`.
    return _dedup(<String>[...base, ...childPart]);
  }

  static List<String> _dedup(List<String> names) {
    final seen = <String>{};
    return <String>[
      for (final n in names)
        if (seen.add(n)) n,
    ];
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
    if (_config.showAllSteps) {
      // Racine « tout affiché » : seul écrivain — union de TOUTES les étapes.
      widget.controller.setVisibleFields(_allStepsUnion());
      return;
    }
    if (_driving) {
      // Racine avec nesting : seul écrivain — pose l'union initiale du chemin.
      widget.controller.setVisibleFields(_initialUnion(_steps, start));
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
  void _onChildWindow(int stepIndex, List<String> w) {
    _childContributions[stepIndex] = w;
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
    final conditions = <ZCondition?>[
      // Conditions de CHAMP : uniquement en mode pilotage (en LEGACY, c'est
      // `DynamicEdition` qui gère la fenêtre — inchangé).
      if (_driving)
        for (final step in widget.steps)
          for (final name in step.fields)
            if (_specByName[name]?.condition != null)
              _specByName[name]!.condition,
      // Conditions d'ÉTAPE : dans TOUS les modes — c'est le stepper, et lui
      // seul, qui décide de l'existence d'une étape. Sans cet abonnement, une
      // étape conditionnelle n'apparaîtrait qu'au prochain rebuild fortuit.
      for (final step in widget.steps)
        if (step.condition != null) step.condition,
    ];
    if (conditions.isEmpty) return;
    for (final g in zGuardFieldsOf(conditions)) {
      final l = widget.controller.fieldListenable(g);
      l.addListener(_onGuardChanged);
      _guardListenables.add(l);
    }
  }

  void _onGuardChanged() {
    final bool changed = _recomputeEffective();
    if (changed) {
      _onEffectiveStepsChanged();
      return;
    }
    if (_driving) _publishWindow();
  }

  /// L'ensemble des étapes effectives vient de changer : borner l'étape
  /// courante, republier la fenêtre, et réveiller le chrome par le canal
  /// STRUCTUREL.
  ///
  /// 🔴 Bornage, pas remise à zéro : si l'étape qui disparaît est APRÈS la
  /// courante, l'utilisateur ne doit rien sentir ; si c'est la dernière et
  /// qu'on y était, on recule d'un cran plutôt que de rejeter à l'étape 0 (ce
  /// qui ferait perdre le contexte de saisie).
  void _onEffectiveStepsChanged() {
    final int max = _lastStep < 0 ? 0 : _lastStep;
    if (_currentStep.value > max) _currentStep.value = max;
    if (_driving || widget.nested) {
      _publishWindow();
    } else {
      _syncWindow(_currentStep.value);
    }
    _stepsTick.value = _stepsTick.value + 1;
  }

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
  bool _validateGate(int i) {
    // Une étape OPTIONNELLE ne bloque jamais la navigation (le gate global
    // reste strict pour les autres — c'est tout l'intérêt face à
    // `validateOnNext: false`, qui relâche TOUT).
    if (_isOptional(i)) return true;
    return _driving ? _validateNames(_contribution()) : _validateStep(i);
  }

  bool _isOptional(int i) =>
      i >= 0 && i <= _lastStep && _steps[i].optional;

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(int target) {
    if (target < 0 || target > _lastStep || target == _currentStep.value) {
      return;
    }
    _reveal.value = false;
    if (_driving) {
      _childContributions.clear(); // le sous-arbre change : recalcul structurel.
      _currentStep.value = target;
      _publishWindow();
    } else {
      _syncWindow(target);
      _currentStep.value = target;
    }
    _persistStep(target);
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
        if (_isOptional(k)) continue;
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
    if (_steps.isEmpty) return const SizedBox.shrink();
    // Chrome scellé sur les canaux STRUCTURELS uniquement (SM-1/AC11).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final reveal = _reveal.value;
        if (_config.showAllSteps) return _allStepsLayout(reveal);
        final index = _currentStep.value.clamp(0, _lastStep);
        final indicator = _StepIndicator(
          index: index,
          total: _steps.length,
          steps: _steps,
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
    final bool unbounded = widget.unbounded;
    final Widget expandedContent =
        unbounded ? content : Expanded(child: content);
    final MainAxisSize axis =
        unbounded ? MainAxisSize.min : MainAxisSize.max;
    switch (_config.indicatorPosition) {
      case ZStepIndicatorPosition.start:
        // 🔴 CR-DODLP « Bug 1 ». Dans une `Row`, un enfant NON flexible est
        // mesuré avec `maxWidth: infinity`. Le `_StepIndicator` étant posé nu
        // ici, il recevait une largeur **non bornée** — et le `Expanded` de son
        // rendu compact (`numbered`/`icons` + `showLabels`) levait alors
        // « RenderFlex children have non-zero flex but incoming width
        // constraints are unbounded ». Le défaut ne venait PAS de l'hôte : il
        // se produisait même sous une largeur d'hôte parfaitement bornée.
        //
        // Le correctif BORNE la bande (`maxWidth`), ce qui rend le `Expanded`
        // interne légal. La borne est thémable (`stepperSideBandMaxWidth`).
        final Widget band = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ZcrudTheme.of(context).stepperSideBandMaxWidth ??
                          _kStepperSideBandMaxWidth,
                    ),
                    child: indicator,
                  ),
                  Expanded(child: content),
                ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: axis,
          children: <Widget>[
            if (unbounded) band else Expanded(child: band),
            nav,
          ],
        );
      case ZStepIndicatorPosition.bottom:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: axis,
          children: <Widget>[expandedContent, indicator, nav],
        );
      case ZStepIndicatorPosition.top:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: axis,
          children: <Widget>[indicator, expandedContent, nav],
        );
    }
  }

  /// **Mode « TOUT AFFICHÉ »** (parité legacy DODLP `showAllSteps: true`) :
  /// toutes les étapes effectives sont dépliées, reliées par un rail vertical à
  /// badges numérotés.
  ///
  /// 🔴 **VIRTUALISÉ** — `ListView.builder`, jamais `ListView(children:)` : une
  /// racine « tout affiché » monte l'intégralité des champs du formulaire ; un
  /// `children:` les construirait tous à chaque build du chrome.
  ///
  /// 🔴 **Pas de barre de navigation ni de gate** à ce niveau (il n'existe pas
  /// d'étape courante). Un bouton final n'apparaît QUE si [onComplete] est
  /// fourni — sinon ce canal serait mort. Les sous-steppers imbriqués, eux,
  /// paginent normalement avec LEUR propre gate.
  Widget _allStepsLayout(bool reveal) {
    final int n = _steps.length;
    final bool hasFinish = widget.onComplete != null;
    return ListView.builder(
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.unbounded,
      itemCount: n + (hasFinish ? 1 : 0),
      itemBuilder: (BuildContext context, int i) {
        if (i >= n) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            child: Row(
              children: <Widget>[
                const Spacer(),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: FilledButton(
                    onPressed: widget.onComplete,
                    child: Text(
                      widget.finishLabel ??
                          label(context, 'z.stepper.finish',
                              fallback: 'Terminer'),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _AllStepsRow(
          index: i,
          total: n,
          step: _steps[i],
          config: _config,
          isLast: i == n - 1,
          content: _stepContent(i, reveal, bounded: false),
        );
      },
    );
  }

  /// Zone d'étape : réutilise [DynamicEdition] (place stable/conditionnels/
  /// sections/grille). En mode `_driving`, le formulaire est **passif**
  /// (`manageVisibility:false`) — le racine est seul écrivain de `visibleFields`.
  /// Si l'étape porte un sous-stepper (AC11), il est rendu **après** les champs
  /// directs sur le MÊME controller (imbriqué, mode « sans fenêtre »).
  Widget _stepContent(int index, bool reveal, {bool? bounded}) {
    final bool isBounded = bounded ?? !widget.unbounded;
    final step = _steps[index];
    final mode = reveal
        ? AutovalidateMode.always
        : AutovalidateMode.onUserInteraction;
    final custom = widget.fieldBuilder;
    // AD-10 : au-delà du plafond d'imbrication, le sous-stepper n'est PAS monté
    // (cycle possible dans `nestedSteps`) — repli défini, jamais d'exception.
    final hasNested = step.nestedSteps != null && !_tooDeep;

    final edition = DynamicEdition(
      key: ValueKey<String>('zstep:$index'),
      controller: widget.controller,
      fields: _stepSpecs(index),
      sections: step.sections,
      padding: widget.padding,
      physics: (hasNested || !isBounded)
          ? const NeverScrollableScrollPhysics()
          : widget.physics,
      shrinkWrap: hasNested || !isBounded,
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
    // En mode « tout affiché », l'étape vit dans un item de `ListView.builder` :
    // la hauteur y est **non bornée**, donc AUCUN `Expanded` (il lèverait
    // « RenderFlex children have non-zero flex but incoming height constraints
    // are unbounded » — le pendant exact du Bug 1 sur l'autre axe).
    final Widget nestedStepper = ZStepperEdition(
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
            depth: widget.depth + 1,
            unbounded: !isBounded,
            onNestedWindowChanged: (w) => _onChildWindow(index, w),
            revealTrigger: _childRevealTick,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        if (step.fields.isNotEmpty) edition,
        if (isBounded)
          Expanded(child: nestedStepper)
        else
          nestedStepper,
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
    final subtitleWidget = steps[index].subtitleWidget;

    final children = <Widget>[
      _indicatorBody(context, scheme, resolvedTitle),
      if (config.showSubtitles && (subtitleWidget != null || subtitle != null))
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: _StepSubtitle(source: subtitle, provided: subtitleWidget),
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

/// Une **étape dépliée** du mode « tout affiché » : badge circulaire numéroté,
/// segment de rail, titre + sous-titre, puis le contenu de l'étape.
///
/// ## Forme (mesurée sur le legacy DODLP `_buildVerticalExpandedSteps`)
///
/// Le legacy peint le rail avec deux `Positioned` **`left:`** (physique) dans un
/// `Stack`, ce qui le place du mauvais côté en RTL (AD-13). Ici le rail est peint
/// par un [_RailPainter] qui reçoit la [TextDirection] : côté **début de
/// lecture** dans les deux sens.
///
/// ## Pourquoi un `CustomPaint` et pas un `IntrinsicHeight`
///
/// Le legacy compose `IntrinsicHeight` + `Row(stretch)` pour qu'une colonne de
/// rail atteigne la hauteur de l'étape. `IntrinsicHeight` mesure DEUX fois son
/// sous-arbre — sur une étape qui contient un formulaire entier, et répété pour
/// chaque étape d'une liste virtualisée, c'est le contraire de ce que SM-1
/// demande. Le `CustomPaint` se dimensionne sur son enfant et peint le rail dans
/// la gouttière : **une** passe de layout.
class _AllStepsRow extends StatelessWidget {
  const _AllStepsRow({
    required this.index,
    required this.total,
    required this.step,
    required this.config,
    required this.isLast,
    required this.content,
  });

  final int index;
  final int total;
  final ZEditionStep step;
  final ZStepperConfig config;
  final bool isLast;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ZcrudTheme tokens = ZcrudTheme.of(context);

    // Chaîne FR-26 stricte : paramètre (`ZStepperConfig`) > jeton (`ZcrudTheme`)
    // > rôle (`ColorScheme`) / mesure de référence. AUCUN littéral de couleur.
    final Color badgeColor = config.activeOf(scheme);
    final Color railColor =
        config.railColor ?? tokens.stepperRailColor ?? scheme.outlineVariant;
    // Le legacy écrit un BLANC LITTÉRAL — illisible dès qu'un hôte choisit
    // un `activeColor` clair. À défaut de réglage, on DÉRIVE le contraste.
    final Color badgeForeground = config.badgeForegroundColor ??
        tokens.stepperBadgeForegroundColor ??
        (ThemeData.estimateBrightnessForColor(badgeColor) == Brightness.dark
            ? scheme.surface
            : scheme.onSurface);

    final double badgeSize = config.indicatorSize;
    final double gutter = badgeSize + 16;
    final double thickness =
        tokens.stepperRailThickness ?? _kStepperRailThickness;
    final double gap = tokens.stepperAllStepsGap ?? _kStepperAllStepsGap;

    final String title = label(context, step.title, fallback: step.title);
    final String? subtitle = step.subtitle;
    final Widget? subtitleWidget = step.subtitleWidget;

    final Widget header = Semantics(
      header: true,
      label: 'Étape ${index + 1} sur $total : $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (config.showLabels)
            Text(
              title,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          if (config.showSubtitles &&
              (subtitleWidget != null || subtitle != null))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
              child: _StepSubtitle(source: subtitle, provided: subtitleWidget),
            ),
        ],
      ),
    );

    final Widget badge = Container(
      width: badgeSize,
      height: badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          color: badgeForeground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final Widget body = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, 0, isLast ? 0 : gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(alignment: AlignmentDirectional.centerStart, child: header),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _RailPainter(
              color: railColor,
              thickness: thickness,
              centerOffset: badgeSize / 2,
              startY: badgeSize,
              drawBelow: !isLast,
              direction: Directionality.of(context),
            ),
          ),
        ),
        body,
        PositionedDirectional(start: 0, top: 0, child: badge),
      ],
    );
  }
}

/// Peint le **segment de rail** d'une étape dépliée : une ligne verticale dans
/// la gouttière, du bas du badge jusqu'au bas de la ligne (donc jusqu'au badge
/// suivant, dont l'écart appartient à la marge basse de CETTE ligne).
///
/// La position horizontale suit la [direction] : gouttière côté **début de
/// lecture** (AD-13) — le legacy la fige à gauche.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.thickness,
    required this.centerOffset,
    required this.startY,
    required this.drawBelow,
    required this.direction,
  });

  final Color color;
  final double thickness;
  final double centerOffset;
  final double startY;
  final bool drawBelow;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawBelow || thickness <= 0 || size.height <= startY) return;
    final double dx = direction == TextDirection.rtl
        ? size.width - centerOffset
        : centerOffset;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(dx, startY), Offset(dx, size.height), paint);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.centerOffset != centerOffset ||
      old.startY != startY ||
      old.drawBelow != drawBelow ||
      old.direction != direction;
}


/// Sous-titre d'étape — **unique** point de rendu, partagé par l'indicateur
/// paginé et par le rail « tout affiché ».
///
/// ## Le seam
///
/// Le legacy DODLP rend ce sous-titre en Markdown (`GptMarkdown`, deux sites).
/// Ici, le moteur de rendu n'entre PAS dans `zcrud_core` (AD-1) : il est injecté
/// par l'hôte via le port [ZRichTextRenderer] (`ZcrudScope.richTextRenderer`).
///
/// * **Aucun renderer** (défaut) ⇒ `Text` simple — comportement d'aujourd'hui,
///   strictement inchangé pour un hôte passif.
/// * **Renderer qui décline** (`null`) ⇒ même repli texte simple.
/// * **Renderer qui LÈVE** ⇒ même repli texte simple (AD-10 : un seam d'hôte
///   fautif ne fait jamais tomber le formulaire).
///
/// ## L'annonce au lecteur d'écran (AD-13)
///
/// 🔴 Les deux voies doivent annoncer **exactement une fois**. Le rendu riche
/// porte DÉJÀ ses propres nœuds de texte : y superposer un `Semantics(label:)`
/// **doublerait** l'annonce (précédent mesuré dans ce dépôt). Mais un renderer
/// libre peut aussi ne produire AUCUNE sémantique (un `CustomPaint`, par
/// exemple), et l'annonce serait alors **perdue**.
///
/// La seule composition qui garantit « ni perdue, ni doublée » quel que soit le
/// renderer est donc `Semantics(label:) + ExcludeSemantics(child:)` : le socle
/// impose l'annonce depuis la **donnée** (la source de vérité) et neutralise
/// celle du rendu. Contrepartie assumée : la sémantique fine du balisage (rôles
/// de lien, de titre) n'est pas exposée — un sous-titre est une phrase courte,
/// pas un document.
class _StepSubtitle extends StatelessWidget {
  const _StepSubtitle({required this.source, required this.provided});

  /// Clé l10n ou littéral du sous-titre (une **String**, jamais un widget).
  final String? source;

  /// Widget déjà construit par l'hôte. **Prioritaire** ; le seam de rendu riche
  /// n'est alors pas consulté (patron `label`/`labelText`).
  final Widget? provided;

  @override
  Widget build(BuildContext context) {
    // VOIE 3 — widget fourni : rendu TEL QUE REÇU. Aucun cast, aucun déballage,
    // aucun `Semantics` surajouté (il porte déjà la sienne — en ajouter une
    // DOUBLERAIT l'annonce, et le socle n'a de toute façon aucune chaîne à
    // annoncer à sa place).
    if (provided != null) return provided!;

    final String raw = source!;
    final String text = label(context, raw, fallback: raw);
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final ZRichTextRenderer? renderer =
        ZcrudScope.maybeOf(context)?.richTextRenderer;

    Widget? rich;
    if (renderer != null) {
      try {
        rich = renderer.build(context, text, baseStyle: style);
      } catch (_) {
        rich = null; // AD-10 : repli DÉFINI, jamais d'exception propagée.
      }
    }

    if (rich == null) {
      return Text(text, textAlign: TextAlign.start, style: style);
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(child: rich),
    );
  }
}
