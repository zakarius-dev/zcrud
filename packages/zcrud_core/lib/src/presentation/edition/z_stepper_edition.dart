/// `ZStepperEdition` — présentation d'un formulaire long en **assistant (wizard)
/// multi-étapes** partitionnant le **MÊME** `ZFormController` (invariant AD-2).
/// Style/orientation/position d'indicateur configurables, icône + sous-titre par
/// étape, gate `validateOnNext` configurable, navigation par tap, et **steppers
/// IMBRIQUÉS** sur le même controller unique.
///
/// `EditionFieldType.stepper` n'est PAS un champ-feuille — le dispatcher le
/// classe volontairement `unsupported` car c'est un **REGROUPEMENT / structure
/// de navigation** renvoyé ici. Ce widget sert donc au niveau **orchestration**,
/// posé AUTOUR du dispatcher existant, jamais comme un `ZFieldWidget`. Le
/// nesting est donc **structurel** (porté par [ZEditionStep.nestedSteps]), PAS
/// routé via `ZWidgetRegistry` (qui mappe un `kind` → widget-feuille et
/// casserait le single-writer de `visibleFields`).
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - **UN seul `ZFormController` partagé** à **tous** les niveaux de nesting :
///   toutes les étapes (racine et imbriquées) lisent/écrivent le même controller
///   (mêmes tranches). Il n'existe JAMAIS de controller par étape/niveau, ni de
///   recréation → l'**état est préservé** en va-et-vient (les tranches survivent
///   au démontage des sous-arbres d'étape ; libérées seulement au `dispose` du
///   controller, possédé par l'hôte).
/// - **SINGLE WRITER de `controller.visibleFields`** : le stepper **RACINE**
///   est le SEUL écrivain ; il publie l'**union des champs visibles le long du
///   chemin d'étapes actif** (étape parente active → sous-étape active du
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
///   (défaut `true` = gate strict ; `false` = navigation LIBRE). Le gate d'un
///   parent honore la **sous-étape active du nested** (l'union). Étape invalide
///   ⇒ navigation bloquée + erreurs **révélées** (bascule locale
///   `AutovalidateMode.always` via un seam additif — jamais un `Form` global).
///   « Précédent » est inconditionnel.
/// - **Chrome = canaux STRUCTURELS only** (invariant AD-2) : la barre d'étapes +
///   la navigation + la zone d'étape n'observent QUE l'index courant
///   ([_currentStep]), le canal de révélation ([_reveal]) et
///   `controller.visibleFields` — JAMAIS une tranche de valeur (sauf les champs
///   de **garde** conditionnels, canal structurel). Une frappe (champ non-garde)
///   ne reconstruit donc QUE le champ courant, jamais le chrome (zéro perte de
///   focus), à tout niveau de nesting.
///
/// La dernière étape délègue la **soumission** à l'hôte (slot [onComplete]) ;
/// ce widget ne fait PAS de `onSubmit`, de détection *dirty*, ni de validateurs
/// **inter-champs**. Composition orthogonale : une étape peut contenir sections
/// repliables + champs conditionnels (hérités de [DynamicEdition]).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/edition/z_condition.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_read_field_layout.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_theme.dart';
import '../z_form_controller.dart';
import '../z_rich_text_renderer.dart';
import '../zcrud_scope.dart';
import 'dynamic_edition.dart';
import 'z_field_widget.dart';
import 'z_read_mode_scope.dart';
import 'z_responsive_grid.dart';
import 'z_section_collapse_store.dart';
import 'z_step_index_store.dart';
import 'z_stepper_config.dart';
import 'z_validator_compiler.dart';
import 'z_value_emptiness.dart';

export 'z_step_index_store.dart';
export 'z_stepper_config.dart';

/// Profondeur maximale de steppers imbriqués (invariant AD-10 : repli défini
/// plutôt qu'une exception).
///
/// [ZEditionStep.nestedSteps] est une `List<ZEditionStep>?` **mutable** : un
/// hôte PEUT construire un cycle (`l = []; s = ZEditionStep(nestedSteps: l);
/// l.add(s);`). Sans plafond, le calcul de fenêtre comme le montage de widgets
/// récursent sans fin (StackOverflow, écran blanc). Au-delà de ce plafond, le
/// sous-stepper n'est **pas monté** et sa contribution n'est **pas comptée** :
/// repli DÉFINI, jamais d'exception.
const int kZStepperMaxNestingDepth = 8;

/// Largeur maximale (dp) de référence de la bande latérale `start`. Surchargée
/// par `ZcrudTheme.stepperSideBandMaxWidth`.
const double _kStepperSideBandMaxWidth = 220;

/// Épaisseur (dp) de référence du rail.
const double _kStepperRailThickness = 1;

/// Écart vertical (dp) de référence entre deux étapes dépliées.
const double _kStepperAllStepsGap = 24;

/// Descripteur **présentation** d'une étape : un titre + le sous-ensemble de
/// **noms de champs** du catalogue qu'elle regroupe (aligné sur [ZEditionSection]
/// — titre + noms, PAS une nouvelle donnée de formulaire). Additif, `const`.
///
/// [icon] et [subtitle] portent les métadonnées d'affichage par étape ;
/// [nestedSteps]/[nestedConfig] portent un sous-stepper imbriqué rendu sur le
/// MÊME controller. Tous ces paramètres sont additifs : les sites existants
/// sans eux compilent inchangés.
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

  /// Sections **visuelles** internes à l'étape, restreintes à ses champs.
  /// Vide = liste plate. Orthogonal au partitionnement en étapes.
  final List<ZEditionSection> sections;

  /// Icône d'étape — consommée en style [ZStepStyle.icons] (repli sur le
  /// numéro si `null`). Défaut `null`.
  final IconData? icon;

  /// Sous-titre d'étape — clé l10n ou littéral, affiché ssi
  /// `config.showSubtitles` (via `label(context, …)`). Défaut `null`.
  ///
  /// C'est une **`String`**, jamais un widget : la chaîne traverse le seam de
  /// rendu riche (`ZcrudScope.richTextRenderer`) telle quelle. Pour fournir un
  /// widget déjà construit, utiliser [subtitleWidget].
  final String? subtitle;

  /// Sous-titre d'étape **déjà construit** par l'hôte. Défaut `null`.
  ///
  /// **[subtitleWidget] PRIME sur [subtitle]**, et le seam de rendu riche
  /// n'est alors **pas consulté** : le widget est rendu **tel que reçu**. C'est
  /// exactement la règle — et le nommage — de `ZcrudTheme.inputDecoration`
  /// (`label` widget prioritaire, `labelText` chaîne sinon) ; une troisième
  /// convention pour la même idée serait une divergence.
  ///
  /// ## Pourquoi DEUX entrées, et non un seul champ `Object?`
  ///
  /// Un `Widget` unique obligerait à redéballer la chaîne par un cast
  /// (`if (subtitle is Text) … (subtitle as Text).data`) pour toute
  /// consommation qui a besoin du texte brut — une donnée qui voyage dans un
  /// widget et qu'on récupère au cast. Avec deux entrées typées, ce cast n'a
  /// plus de raison d'être : le défaut devient **inexprimable**, ce qui vaut
  /// mieux que de le corriger.
  ///
  /// [ZStepperConfig.showSubtitles] gouverne les **deux** entrées : le drapeau
  /// dit « cette présentation montre des sous-titres », pas « cette présentation
  /// montre les sous-titres de type chaîne ». Un hôte qui veut un contenu
  /// toujours visible ne le met pas en sous-titre.
  final Widget? subtitleWidget;

  /// Sous-étapes d'un **stepper imbriqué**. Quand non `null`, l'étape rend,
  /// dans son contenu, un [ZStepperEdition] imbriqué partageant le **MÊME**
  /// controller (jamais un controller par niveau). Défaut `null`.
  final List<ZEditionStep>? nestedSteps;

  /// Configuration du sous-stepper imbriqué (défaut `null` ⇒ `ZStepperConfig()`).
  /// Son `validateOnNext` est **indépendant** de celui du parent.
  final ZStepperConfig? nestedConfig;

  /// Condition d'**EXISTENCE** de l'étape. `null` (défaut) ⇒ l'étape est
  /// toujours là — comportement historique **strictement inchangé**.
  ///
  /// ## Le besoin, nommé
  ///
  /// Un formulaire multi-étapes avancé **branche** : un choix fait à une
  /// étape précoce peut décider si une étape ultérieure existe. Jusqu'ici,
  /// seuls les **CHAMPS** étaient conditionnels (`ZFieldSpec.condition`) : une
  /// étape dont tous les champs disparaissaient restait **présente et vide**,
  /// comptée dans le « k/N » et traversée par la navigation. L'hôte n'avait
  /// qu'un recours — recomposer lui-même sa `List<ZEditionStep>` à chaque
  /// frappe, donc reconstruire le stepper entier (exactement ce que
  /// l'invariant AD-2 interdit).
  ///
  /// ## Ce que la condition gouverne
  ///
  /// Une étape dont la condition est **fausse** est **absente** : pas rendue,
  /// pas comptée dans le total, non atteignable par « suivant »/tap, non
  /// validée par le gate, et ses champs ne sont pas dans la fenêtre.
  ///
  /// Le mécanisme **réutilise `ZCondition`** — l'arbre déjà utilisé par les
  /// champs — et son évaluateur : aucun second langage de condition n'est
  /// introduit. Les champs de garde référencés sont abonnés **nommément**
  /// (une frappe sur un champ non-garde ne recalcule rien — invariant AD-2).
  final ZCondition? condition;

  /// Étape **OPTIONNELLE** : le gate `validateOnNext` ne s'y applique pas.
  /// Défaut `false` ⇒ comportement historique inchangé.
  ///
  /// Besoin nommé : les formulaires longs ont des étapes « pièces jointes » /
  /// « commentaires » qu'un utilisateur doit pouvoir **traverser sans rien
  /// saisir**, sans pour autant relâcher le gate des étapes obligatoires — ce
  /// que `ZStepperConfig.validateOnNext: false` ferait globalement, tout ou
  /// rien.
  ///
  /// Ne dispense PAS de la validation à la **soumission** : c'est un
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
/// un builder custom DOIT le propager pour révéler les erreurs sans `Form`
/// global.
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
    this.readLayout,
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
    this.collapseStore,
    this.formId,
    super.key,
  });

  /// Seam de **reprise** : persiste/restaure l'étape courante.
  /// `null` (défaut) ⇒ aucune persistance, comportement inchangé.
  ///
  /// Même patron que [collapseStore] — un hôte branche le même stockage pour
  /// les deux, et le cœur n'en dépend pas (AD-1).
  final ZStepIndexStore? stepStore;

  /// Seam de **persistance du repli des sections** d'étape.
  ///
  /// Une `ZEditionStep` porte ses propres `sections` : celles qui sont
  /// déclarées `collapsible` se replient, et ce repli se perd à chaque
  /// fermeture tant qu'aucun store n'est branché. Ce paramètre est relayé à la
  /// `DynamicEdition` de **chaque** étape ; `null` (défaut) ⇒ aucune lecture,
  /// aucune écriture, comportement strictement inchangé.
  ///
  /// **Chaque étape a sa propre portée.** Le store n'échange qu'un ensemble de
  /// titres repliés par portée, et une écriture remplace la portée entière :
  /// sous une portée commune, replier une section de l'étape 2 **effacerait**
  /// le repli enregistré à l'étape 1. La portée transmise à chaque étape est
  /// donc dérivée de [formId] **et du titre de l'étape** (`"<formId>/étape:<titre>"`,
  /// ou `"étape:<titre>"` quand [formId] est `null`) — même convention que le
  /// reste du seam, qui est titre-adressé de bout en bout. Un sous-stepper
  /// imbriqué reçoit à son tour la portée de l'étape qui le porte, et dérive
  /// la sienne par-dessus.
  ///
  /// Conséquence pratique : **renommer une étape** repart d'un repli neuf pour
  /// ses sections, comme renommer une section repart d'un repli neuf pour
  /// elle-même. Réordonner les étapes, en revanche, ne perd rien.
  final ZSectionCollapseStore? collapseStore;

  /// Clé de portée opaque du formulaire (`null` ⇒ portée « globale »), lue par
  /// [stepStore] telle quelle et par [collapseStore] comme **préfixe** de la
  /// portée par étape (cf. [collapseStore]). Sans aucun des deux stores, elle
  /// n'a aucun effet.
  final String? formId;

  /// Contrôleur **unique** détenant l'état (créé/possédé par l'hôte ; jamais
  /// recréé ici, jamais un par étape/niveau).
  final ZFormController controller;

  /// Catalogue complet des champs connus (source des [ZFieldSpec] par nom). Le
  /// MÊME catalogue est transmis à un sous-stepper imbriqué.
  final List<ZFieldSpec> fields;

  /// Étapes ordonnées partitionnant le catalogue.
  final List<ZEditionStep> steps;

  /// Configuration visuelle & comportementale. Défaut `const ZStepperConfig()`
  /// = top/horizontal/numbered « k/N » + titre, gate strict.
  final ZStepperConfig config;

  /// Index d'étape initial (borné à `[0, steps.length-1]`).
  final int initialStep;

  /// Marge du `ListView` de chaque étape (héritée par [DynamicEdition]).
  final EdgeInsetsGeometry? padding;

  /// `ScrollPhysics` de la zone d'étape.
  final ScrollPhysics? physics;

  /// **Mode lecture global** propagé à chaque étape
  /// ([DynamicEdition.readOnly]) et posé pour tous les champs de l'assistant
  /// ([ZReadModeScope]) : en consultation, un assistant rend des **fiches**,
  /// exactement comme un formulaire à plat.
  final bool readOnly;

  /// **Forme** des champs présentés en consultation, pour tout l'assistant —
  /// posée sur le même canal que le mode lui-même ([ZReadModeScope]), donc
  /// atteinte par les champs de chaque étape sans que le `fieldBuilder` des
  /// étapes ait à la connaître.
  ///
  /// `null` (défaut) ⇒ le jeton `ZcrudTheme.readLayout`, à défaut
  /// [ZReadFieldLayout.card]. **Inerte hors consultation.**
  final ZReadFieldLayout? readLayout;

  /// Grille 12 colonnes (span par nom de champ) propagée à chaque étape.
  final Map<String, ZResponsiveSpan> layout;

  /// Gouttière (dp) de la grille responsive.
  final double gridGutter;

  /// Seam de rendu de champ (reçoit le mode d'autovalidation piloté). À défaut :
  /// le dispatcher [ZFieldWidget], place stable garantie par [DynamicEdition].
  final ZStepFieldBuilder? fieldBuilder;

  /// Libellé du bouton « précédent » (défaut l10n `z.stepper.previous`).
  final String? previousLabel;

  /// Libellé du bouton « suivant » (défaut l10n `z.stepper.next`).
  final String? nextLabel;

  /// Libellé du bouton final de la **dernière** étape (défaut `z.stepper.finish`).
  /// Son action délègue à [onComplete] (soumission déléguée à l'hôte).
  final String? finishLabel;

  /// Slot de **fin d'assistant** (dernière étape) : ce widget ne soumet PAS ;
  /// il délègue à l'hôte. `null` ⇒ le bouton final est présent mais désactivé.
  final VoidCallback? onComplete;

  /// Notifié après un changement d'étape effectif (index cible).
  final ValueChanged<int>? onStepChanged;

  /// Hook d'instrumentation : appelé à chaque (re)build **structurel** du chrome
  /// (compteur de test — reste inchangé pendant la saisie, invariant AD-2).
  @visibleForTesting
  final VoidCallback? onStructuralBuild;

  /// **Interne** : `true` quand ce stepper est **imbriqué** dans une étape
  /// parente. Un stepper imbriqué tourne en mode « sans fenêtre » (n'écrit JAMAIS
  /// `visibleFields` ; remonte sa contribution via [onNestedWindowChanged]).
  @visibleForTesting
  final bool nested;

  /// **Interne** : callback par lequel un stepper imbriqué **remonte** sa
  /// contribution de fenêtre (union de son chemin actif) au parent, qui agrège
  /// jusqu'au racine (seul écrivain de `visibleFields`).
  @visibleForTesting
  final ValueChanged<List<String>>? onNestedWindowChanged;

  /// **Interne** : ce stepper est monté dans un contexte de hauteur **NON
  /// BORNÉE** (item de `ListView.builder` du mode « tout affiché »). Il se
  /// dimensionne alors **au contenu** (`MainAxisSize.min`, aucun `Expanded`
  /// vertical) au lieu de remplir l'espace disponible.
  ///
  /// Sans ce mode, un sous-stepper **paginé** posé dans une étape dépliée
  /// lèverait « RenderFlex children have non-zero flex but incoming height
  /// constraints are unbounded » : un enfant flexible sous une contrainte de
  /// hauteur non bornée.
  @visibleForTesting
  final bool unbounded;

  /// **Interne** : profondeur d'imbrication de CE stepper (0 = racine). Plafonné
  /// par [kZStepperMaxNestingDepth] (invariant AD-10 — `nestedSteps` circulaires).
  @visibleForTesting
  final int depth;

  /// **Interne** : signal de **révélation** poussé par le parent (gate bloqué)
  /// pour forcer ce stepper imbriqué à révéler les erreurs de sa sous-étape
  /// active. Chaque incrément déclenche `AutovalidateMode.always`.
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

  /// Signal de révélation poussé aux sous-steppers imbriqués quand un gate
  /// bloque : incrémenté pour révéler les champs de la sous-étape active.
  late final ValueNotifier<int> _childRevealTick;

  /// Listenable fusionné observé par le chrome : index + révélation +
  /// `visibleFields` (structurel). AUCUNE tranche de valeur (invariant AD-2).
  late Listenable _structural;

  /// Index `name → spec` (identité de valeur ; recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Cache de validateurs compilés **mémoïsés** par nom de champ.
  final Map<String, FormFieldValidator<String>?> _validatorCache =
      <String, FormFieldValidator<String>?>{};

  /// Tranches des champs de **garde** (mode nesting) auxquelles [_onGuardChanged]
  /// est abonné pour recalculer la fenêtre du chemin actif.
  final List<Listenable> _guardListenables = <Listenable>[];

  /// Dernières contributions de fenêtre remontées par les sous-steppers
  /// imbriqués montés, **indexées par index d'étape**.
  ///
  /// Une `Map` et non un champ unique : en mode `showAllSteps`, PLUSIEURS
  /// sous-steppers sont montés **simultanément** (une étape dépliée peut en
  /// porter un chacune). Un champ unique ferait que la dernière remontée écrase
  /// toutes les autres — la fenêtre publiée perdrait les champs des autres
  /// sous-steppers. Absent = pas encore remontée ⇒ repli structurel.
  final Map<int, List<String>> _childContributions = <int, List<String>>{};

  /// Mémo des **zones d'étape** déjà construites, par index d'étape, valable
  /// tant que [_contentInputs] est inchangé.
  ///
  /// Raison d'être : `config` porte 13 canaux **purement visuels** (couleurs,
  /// tailles, style, position d'indicateur…) que le contenu d'étape ne lit PAS.
  /// Sans mémo, un hôte qui change une couleur reconstruit le widget
  /// `ZStepperEdition`, donc `build`, donc un NOUVEAU `DynamicEdition` par
  /// étape — et tous les champs sont reconstruits. En rendant le **MÊME**
  /// instance de widget, `Element.updateChild` court-circuite le sous-arbre
  /// entier (`identical(newWidget, child.widget)`) : zéro rebuild de champ,
  /// exactement ce que demande l'invariant AD-2 appliqué au canal `config`.
  final Map<int, Widget> _contentMemo = <int, Widget>{};
  List<Object?>? _contentMemoKey;

  /// Étapes **EFFECTIVES** : celles dont la [ZEditionStep.condition] est
  /// satisfaite, dans l'ordre déclaré. Recalculées UNIQUEMENT quand un champ de
  /// garde change (invariant AD-2) — jamais à chaque frappe.
  ///
  /// Tout le reste de l'état raisonne sur CETTE liste, jamais sur
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
  /// mode simple (ni imbriqué, ni de nesting), `DynamicEdition` gère
  /// `visibleFields` directement (`_syncWindow` sur navigation).
  /// `showAllSteps` FORCE le mode pilotage : toutes les étapes montent leur
  /// `DynamicEdition` **en même temps**. Si chacune gérait `visibleFields`
  /// (`manageVisibility: true`), elles se battraient pour l'écrire — la dernière
  /// montée gagnerait et masquerait les champs de toutes les autres. Le stepper
  /// reste donc le **single writer** et publie l'union.
  bool get _driving => widget.nested || _hasNesting || _allExpanded;

  /// Forme d'affichage EFFECTIVE (règle de préséance : cf.
  /// [ZStepperConfig.effectiveDisplay]). Seul point de lecture du mode dans
  /// tout l'état — `config.showAllSteps` n'est plus consulté nulle part ici.
  ZStepsDisplay get _display => _config.effectiveDisplay;

  /// `true` en mode « TOUT AFFICHÉ » (toutes les étapes dépliées).
  ///
  /// L'accordéon n'en fait **PAS** partie, et c'est le point dur de ce mode :
  /// il ne monte qu'**UNE** zone d'étape (l'active), exactement comme le paginé.
  /// Le rattacher ici forcerait [_driving], publierait l'UNION de toutes les
  /// étapes et casserait le single-writer.
  bool get _allExpanded => _display == ZStepsDisplay.allExpanded;

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

  /// `true` si le passage de [a] à [b] change la **STRUCTURE** de ce qui est
  /// monté — par opposition aux canaux purement **VISUELS**.
  ///
  /// ## La table, établie sur les seuls sites où `config` est lu HORS rendu
  ///
  /// | Canal | Nature | Invalidation nécessaire |
  /// |---|---|---|
  /// | `showAllSteps` **et** `stepsDisplay` (via `effectiveDisplay`) | **STRUCTUREL** — pilote [_driving], donc le `manageVisibility` des zones d'étape, le jeu de gardes abonnées, et la fenêtre publiée (union de TOUTES les étapes vs fenêtre de l'étape active) | fenêtre republiée + gardes réabonnées + contributions enfants purgées + mémo de contenu invalidé |
  /// | `validateOnNext` | comportemental, lu **à l'appel** (`_next`/`_jumpTo`) | **aucune** |
  /// | `allowStepTap` | comportemental, lu **au build** du chrome | **aucune** |
  /// | `orientation`, `style`, `indicatorPosition`, `showLabels`, `showSubtitles`, `indicatorSize`, `stepSpacing`, `activeColor`, `completedColor`, `inactiveColor`, `errorColor`, `railColor`, `badgeForegroundColor` | **VISUEL** — lus uniquement par `_StepIndicator`/`_AllStepsRow` | **aucune** |
  ///
  /// C'est la raison d'être de cette fonction : recalculer la fenêtre sur un
  /// simple changement de couleur republierait `visibleFields` et, via le
  /// mémo, reconstruirait tous les champs (invariant AD-2 : jamais de rebuild
  /// global du formulaire pour une frappe ou un changement purement visuel).
  static bool _isStructuralConfigChange(ZStepperConfig a, ZStepperConfig b) =>
      a.effectiveDisplay != b.effectiveDisplay;

  @override
  void didUpdateWidget(ZStepperEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    // `config` doit être observé : basculer `showAllSteps` sur un stepper déjà
    // monté change la mise en page (le chrome se rebuild) et doit recalculer
    // la fenêtre — sinon les en-têtes des étapes suivantes s'affichent avec un
    // contenu resté vide.
    final configStructural =
        _isStructuralConfigChange(oldWidget.config, widget.config);
    if (controllerChanged || !identical(oldWidget.fields, widget.fields)) {
      _rebuildIndexes();
      _validatorCache.clear();
      _bindStepperGuards();
    } else if (configStructural) {
      // `_driving` vient de basculer : les conditions de CHAMP ne sont abonnées
      // qu'en mode pilotage (en mode simple c'est `DynamicEdition` qui s'en
      // charge).
      _bindStepperGuards();
    }
    if (!identical(oldWidget.steps, widget.steps)) {
      _bindStepperGuards();
      if (_recomputeEffective()) _onEffectiveStepsChanged();
    }
    if (controllerChanged) {
      _structural = _mergeStructural();
      _initWindow(_currentStep.value);
    } else if (configStructural) {
      // Les contributions des sous-steppers sont indexées par étape : en paginé
      // un seul nested est monté, en déplié ils le sont tous. Les garder ferait
      // publier la contribution d'un sous-stepper démonté (fenêtre fantôme).
      _childContributions.clear();
      _applyWindowForMode(_boundedStep(_currentStep.value));
    }
    if (oldWidget.revealTrigger != widget.revealTrigger) {
      oldWidget.revealTrigger?.removeListener(_onRevealTrigger);
      widget.revealTrigger?.addListener(_onRevealTrigger);
    }
  }

  int _boundedStep(int i) => i.clamp(0, _lastStep < 0 ? 0 : _lastStep);

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

  /// Fenêtre directe des champs visibles de l'étape [i].
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
    // Garde de VACUITÉ : indispensable ici comme aux deux autres sites qui
    // indexent `_steps` (`_initialUnion`, `build`).
    //
    // Un sous-stepper dont TOUTES les étapes sont filtrées par leur `condition`
    // lèverait un `RangeError` — au montage comme en vol. L'écrêtage d'index
    // ci-dessous ne suffit pas : sur une liste vide `_lastStep` vaut -1, donc
    // `i` retombe à 0 et `_steps[0]` lève. Deux accès sont concernés (la fenêtre
    // directe ET la lecture de `nestedSteps`), d'où la garde ici plutôt que
    // dans `_windowFor`.
    if (_steps.isEmpty) return const <String>[];
    if (_allExpanded) return _allStepsUnion();
    final i = _currentStep.value.clamp(0, _lastStep < 0 ? 0 : _lastStep);
    final base = _windowFor(i);
    final nested = _steps[i].nestedSteps;
    if (nested == null) return base;
    final childPart = _childContributions[i] ?? _initialUnion(nested, 0);
    // UNION, pas concaténation. Un même nom peut apparaître à deux niveaux
    // (étape parente ET sous-étape) : le publier deux fois ferait monter le
    // champ deux fois dans `DynamicEdition` — deux widgets sur la même tranche.
    // Cas limite couvert par l'invariant AD-10 (`nestedSteps` circulaires) :
    // sans dédoublonnage la fenêtre sortirait dupliquée (`['a'] × 10`).
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
  /// Le stepper est le **seul écrivain** de `visibleFields` et calcule sa
  /// fenêtre depuis `ZCondition` uniquement. Une cible `visible` de
  /// `ZDerivation` n'y est donc **PAS appliquée** : le champ resterait visible
  /// alors que la dérivation le masque.
  ///
  /// Cette limite est **signalée**, jamais silencieuse (même idiome que
  /// `ZSyncMeta.collidingReservedKeys`) : une capacité déclarée que personne
  /// n'applique est précisément le défaut qu'il faut éviter.
  ///
  /// Les cibles `value`, `options` et `bounds`, elles, fonctionnent
  /// normalement sous stepper : seule `visible` est concernée.
  void _warnDerivedVisibilityUnsupported() {
    // Le correctif de fond — faire porter la composition de la cible `visible`
    // au stepper — touche son invariant de single-writer sur `visibleFields` :
    // c'est un chantier à part, pas un ajout ponctuel greffé ici.

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
    _applyWindowForMode(start);
  }

  /// Pose la fenêtre correspondant au **mode courant** (déplié / pilotage /
  /// simple). Extrait de [_initWindow] pour être rejouable sur un changement
  /// STRUCTUREL de `config` sans re-émettre l'avertissement de montage.
  void _applyWindowForMode(int start) {
    if (widget.nested) {
      // Imbriqué : reporter la contribution APRÈS la première frame (éviter un
      // `notifyListeners` du controller pendant le build du parent).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishWindow();
      });
      return;
    }
    if (_allExpanded) {
      // Racine « tout affiché » : seul écrivain — union de TOUTES les étapes.
      widget.controller.setVisibleFields(_allStepsUnion());
      return;
    }
    if (_driving) {
      // Racine avec nesting : seul écrivain — pose l'union initiale du chemin.
      widget.controller.setVisibleFields(_initialUnion(_steps, start));
      return;
    }
    // Mode simple (aucun nesting) : `DynamicEdition` gère `visibleFields`.
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

  /// Mode simple uniquement : aligne `controller.visibleFields` sur la fenêtre
  /// directe de l'étape [i] (no-op si inchangé). Ne DÉTRUIT jamais de tranche.
  void _syncWindow(int i) {
    if (i < 0 || i > _lastStep) return;
    widget.controller.setVisibleFields(_windowFor(i));
  }

  // ── Souscription aux champs de garde (mode nesting) ─────────────────────────

  /// (Ré)abonne [_onGuardChanged] aux champs de garde de CE niveau (union des
  /// `field` référencés par les conditions des champs de ses étapes) — UNIQUEMENT
  /// en mode `_driving` (le racine/nested pilote alors la fenêtre lui-même, les
  /// `DynamicEdition` étant passifs). En mode simple, c'est [DynamicEdition] qui
  /// gère les gardes (aucun abonnement ici). Une frappe sur un champ **non-garde**
  /// ne déclenche donc AUCUN recalcul (invariant AD-2).
  void _bindStepperGuards() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    final conditions = <ZCondition?>[
      // Conditions de CHAMP : uniquement en mode pilotage (en mode simple,
      // c'est `DynamicEdition` qui gère la fenêtre — inchangé).
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
  /// Bornage, pas remise à zéro : si l'étape qui disparaît est APRÈS la
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

  /// **Projection de validation partagée** [zValidationText] : une copie
  /// locale ad hoc projetterait à tort une **collection/map vide** vers
  /// `"[]"` / `"{}"` — non vides pour `FormBuilderValidators.required<String>`.
  /// Le gate d'étape laisserait alors passer « Suivant » sur un `subItems`
  /// requis **sans aucune ligne** ou sur un champ custom requis portant une
  /// **map vide**, alors que `DynamicEdition` (`_wrapError`) et la soumission
  /// (`_aggregateValidate`) mordent déjà, tous deux via [zValidationText]. La
  /// règle de projection reste donc **unique** à travers les trois voies de
  /// validation.
  bool _validatorPasses(ZFieldSpec spec) {
    final validator = _validatorFor(spec);
    if (validator == null) return true;
    return validator(zValidationText(widget.controller.valueOf(spec.name))) ==
        null;
  }

  /// `true` ssi TOUS les champs **visibles** de l'étape [i] passent leurs
  /// validateurs champ-locaux. Un champ masqué par condition n'est PAS validé ;
  /// une étape sans champ visible passe trivialement.
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

  /// Gate de l'étape courante : en mode `_driving`, valide l'**union** du
  /// chemin actif (parent direct + sous-étape active du nested) ; en mode
  /// simple, valide la fenêtre directe.
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
      // Révèle aussi les champs de la sous-étape active d'un nested.
      _childRevealTick.value = _childRevealTick.value + 1;
    }
  }

  /// « Suivant » : gate configurable. Bloqué ⇒ erreurs révélées. Sur la
  /// dernière étape ⇒ délègue à [onComplete] (soumission de l'hôte).
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

  /// « Précédent » : INCONDITIONNEL (jamais de gate en arrière).
  void _previous() {
    final current = _currentStep.value;
    if (current > 0) _goTo(current - 1);
  }

  /// Navigation par **tap** sur l'indicateur : retour arrière libre ; saut
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
    // Mode de présentation posé pour TOUT l'assistant — y compris le
    // `fieldBuilder` que chaque étape passe à sa `DynamicEdition` (lequel
    // remplace justement le dispatcher qui, autrefois, portait seul le
    // drapeau). Sans ce scope, la consultation se perdrait entre l'assistant et
    // ses champs, alors même que `readOnly` est propagé étape par étape.
    return ZReadModeScope(
      readMode: widget.readOnly,
      layout: widget.readLayout,
      child: _buildChrome(context),
    );
  }

  Widget _buildChrome(BuildContext context) {
    // Chrome scellé sur les canaux STRUCTURELS uniquement (invariant AD-2).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        // La garde de vacuité en tête de `build` ne protège PAS cette
        // fermeture : elle est capturée une fois et rejouée à chaque
        // notification structurelle, donc `_steps` peut devenir vide APRÈS le
        // dernier passage dans `build`. Sans cette seconde garde, filtrer
        // toutes les étapes EN VOL ferait lever `clamp(0, -1)`.
        //
        // Second défaut du même scénario que celui de `_contribution` ci-dessus,
        // mais sur un chemin distinct : l'un se produit au montage, l'autre au
        // recalcul. Une garde posée sur un seul des deux laisserait l'autre
        // ouvert — d'où les deux sens gardés.
        if (_steps.isEmpty) return const SizedBox.shrink();
        final reveal = _reveal.value;
        switch (_display) {
          case ZStepsDisplay.allExpanded:
            return _allStepsLayout(reveal);
          case ZStepsDisplay.accordion:
            return _accordionLayout(reveal);
          case ZStepsDisplay.paged:
            break;
        }
        final index = _currentStep.value.clamp(0, _lastStep);
        final indicator = _StepIndicator(
          index: index,
          total: _steps.length,
          steps: _steps,
          config: _config,
          onStepTap: _config.allowStepTap ? _jumpTo : null,
        );
        final content = _stepContentCached(index, reveal);
        final nav = _StepNavigationBar(
          isFirst: index == 0,
          isLast: index == _lastStep,
          previousLabel: widget.previousLabel ??
              label(context, 'z.stepper.previous', fallback: 'Previous'),
          nextLabel: widget.nextLabel ??
              label(context, 'z.stepper.next', fallback: 'Next'),
          finishLabel: widget.finishLabel ??
              label(context, 'z.stepper.finish', fallback: 'Finish'),
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
        // Dans une `Row`, un enfant NON flexible est mesuré avec
        // `maxWidth: infinity`. Le `_StepIndicator` posé nu ici recevrait
        // donc une largeur **non bornée** — et le `Expanded` de son rendu
        // compact (`numbered`/`icons` + `showLabels`) lèverait alors
        // « RenderFlex children have non-zero flex but incoming width
        // constraints are unbounded », même sous une largeur d'hôte
        // parfaitement bornée.
        //
        // La bande est donc BORNÉE (`maxWidth`), ce qui rend le `Expanded`
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

  /// **Mode « TOUT AFFICHÉ »** (`showAllSteps: true`) : toutes les étapes
  /// effectives sont dépliées, reliées par un rail vertical à badges numérotés.
  ///
  /// **VIRTUALISÉ** — `ListView.builder`, jamais `ListView(children:)` : une
  /// racine « tout affiché » monte l'intégralité des champs du formulaire ; un
  /// `children:` les construirait tous à chaque build du chrome.
  ///
  /// **Pas de barre de navigation ni de gate** à ce niveau (il n'existe pas
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
                              fallback: 'Finish'),
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
          content: _stepContentCached(i, reveal, bounded: false),
        );
      },
    );
  }

  /// **Mode « ACCORDÉON MATERIAL »** : **tous les en-têtes** des étapes
  /// effectives sont rendus dans le rail numéroté, **une seule est dépliée**
  /// (l'active), et un en-tête est **tapable** pour y aller.
  ///
  /// ## Le rail est RÉUTILISÉ, pas réécrit
  ///
  /// Ce mode rend exactement les mêmes [_AllStepsRow] / [_RailPainter] que le
  /// mode « tout affiché » (badge, gouttière, segment de rail directionnel,
  /// titre + sous-titre). Les deux modes ne diffèrent QUE par trois arguments :
  /// `content` (`null` ⇒ repliée), `onHeaderTap`, et les marques d'état. Une
  /// seconde implémentation de rail aurait dupliqué le painter, le calcul de
  /// gouttière, la chaîne de couleurs (invariant FR-26) et la dérivation de
  /// contraste du badge — quatre occasions de diverger.
  ///
  /// ## Le verrou de validation : la règle, et ce qui la fonde
  ///
  /// **`validateOnNext` est HONORÉ en accordéon**, par la voie EXACTE du mode
  /// paginé : un tap d'en-tête appelle [_jumpTo] (retour arrière libre ; saut
  /// avant soumis au gate), « Suivant » appelle [_next]. Un hôte qui change de
  /// FORME D'AFFICHAGE ne perd donc jamais silencieusement son gate de
  /// données : une capacité déclarée que personne n'applique serait
  /// précisément le défaut à éviter. L'hôte qui veut une navigation libre
  /// pose `validateOnNext: false` — canal existant, explicite, déjà documenté.
  ///
  /// ## Single writer, garanti par le COMPTE
  ///
  /// Une seule zone d'étape est montée : il n'existe donc **qu'un**
  /// `DynamicEdition` à ce niveau, et la fenêtre publiée est celle de l'étape
  /// **active** (via [_contribution]), jamais l'union — [_allExpanded] est
  /// `false` ici, et c'est ce qui le garantit.
  ///
  /// **VIRTUALISÉ** — `ListView.builder` : un formulaire à nombreuses
  /// sous-étapes ne monte que le contenu de l'étape active, tous les autres
  /// en-têtes restant repliés.
  Widget _accordionLayout(bool reveal) {
    final int n = _steps.length;
    final int index = _currentStep.value.clamp(0, _lastStep);
    return ListView.builder(
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.unbounded,
      itemCount: n,
      itemBuilder: (BuildContext context, int i) {
        final bool isActive = i == index;
        return _AllStepsRow(
          index: i,
          total: n,
          step: _steps[i],
          config: _config,
          isLast: i == n - 1,
          // Repliée ⇒ AUCUN contenu monté (ni champs, ni sous-stepper).
          content: isActive ? _accordionActiveBody(i, reveal) : null,
          // Tapable pour TOUTES les lignes, active comprise : sans cela,
          // l'en-tête actif perdrait son rôle `button` et l'annonce
          // « déplié » du lecteur d'écran serait portée par un nœud de nature
          // différente des autres. `_jumpTo` sort sans effet quand la cible
          // est déjà l'étape courante.
          onHeaderTap: _config.allowStepTap ? () => _jumpTo(i) : null,
          accordionState: isActive
              ? _RowAccordionState.active
              : (i < index
                  ? _RowAccordionState.completed
                  : _RowAccordionState.pending),
        );
      },
    );
  }

  /// Corps de l'étape ACTIVE en accordéon : contenu mémoïsé + barre de
  /// navigation (parité legacy `_buildStepContentWithControls`, qui pose
  /// « Précédent »/« Suivant » **sous** le contenu de l'étape dépliée).
  Widget _accordionActiveBody(int index, bool reveal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _stepContentCached(index, reveal, bounded: false),
        _StepNavigationBar(
          isFirst: index == 0,
          isLast: index == _lastStep,
          previousLabel: widget.previousLabel ??
              label(context, 'z.stepper.previous', fallback: 'Previous'),
          nextLabel: widget.nextLabel ??
              label(context, 'z.stepper.next', fallback: 'Next'),
          finishLabel: widget.finishLabel ??
              label(context, 'z.stepper.finish', fallback: 'Finish'),
          onPrevious: index == 0 ? null : _previous,
          onNext: _next,
          finishEnabled: widget.onComplete != null,
        ),
      ],
    );
  }

  /// Zone d'étape : réutilise [DynamicEdition] (place stable/conditionnels/
  /// sections/grille). En mode `_driving`, le formulaire est **passif**
  /// (`manageVisibility:false`) — le racine est seul écrivain de `visibleFields`.
  /// Si l'étape porte un sous-stepper, il est rendu **après** les champs
  /// directs sur le MÊME controller (imbriqué, mode « sans fenêtre »).
  /// TOUTES les entrées dont [_stepContent] dépend, HORS index d'étape. Un
  /// canal visuel de `config` n'y figure pas — c'est ce qui rend le mémo légitime.
  ///
  /// Volontairement exhaustive : chaque paramètre transmis à `DynamicEdition` ou
  /// au sous-stepper imbriqué y est, plus les états dérivés ([_driving],
  /// [_tooDeep]) et le tic structurel des étapes effectives. Un ajout de
  /// paramètre au constructeur DOIT être répercuté ici (sinon contenu périmé).
  List<Object?> _contentInputs(bool reveal, bool? bounded) => <Object?>[
        reveal,
        bounded,
        widget.unbounded,
        widget.controller,
        widget.fields,
        widget.steps,
        _stepsTick.value,
        widget.padding,
        widget.physics,
        widget.readOnly,
        widget.layout,
        widget.gridGutter,
        widget.fieldBuilder,
        widget.previousLabel,
        widget.nextLabel,
        widget.finishLabel,
        widget.depth,
        _driving,
        _tooDeep,
      ];

  /// [_stepContent] mémoïsé (cf. [_contentMemo]).
  Widget _stepContentCached(int index, bool reveal, {bool? bounded}) {
    final List<Object?> inputs = _contentInputs(reveal, bounded);
    if (!listEquals(_contentMemoKey, inputs)) {
      _contentMemo.clear();
      _contentMemoKey = inputs;
    }
    return _contentMemo.putIfAbsent(
      index,
      () => _stepContent(index, reveal, bounded: bounded),
    );
  }

  /// Portée du repli propre à [step] : `"<formId>/étape:<titre>"`, ou
  /// `"étape:<titre>"` en l'absence de [ZStepperEdition.formId].
  ///
  /// Chaque étape range ses sections repliées sous SA clé — sans quoi la
  /// dernière étape repliée effacerait le repli de toutes les autres, le store
  /// n'échangeant qu'un ensemble de titres par portée. Adressage par **titre**,
  /// comme le reste du seam (la section elle-même est adressée par son titre) :
  /// réordonner les étapes ne perd donc rien.
  String _collapseScope(ZEditionStep step) {
    final String? scope = widget.formId;
    return scope == null ? 'étape:${step.title}' : '$scope/étape:${step.title}';
  }

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
      // Le repli des sections de CETTE étape, sous SA portée : une écriture
      // remplace la portée entière, donc une portée commune à toutes les
      // étapes ferait effacer par la dernière repliée ce que les autres
      // avaient enregistré (mesuré). `null` ⇒ aucun accès au store.
      collapseStore: widget.collapseStore,
      formId: widget.collapseStore == null ? null : _collapseScope(step),
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
            // Le sous-stepper hérite du store et prend pour préfixe la portée
            // de l'étape qui le porte : ses propres sous-étapes dérivent la
            // leur par-dessus, sans jamais retomber sur la portée d'une autre
            // branche. `stepStore` reste non relayé (la reprise d'étape est
            // pilotée par le stepper RACINE) : `formId` n'y sert donc qu'au
            // repli.
            collapseStore: widget.collapseStore,
            formId: widget.collapseStore == null ? null : _collapseScope(step),
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

/// Indicateur d'étape accessible & configurable. `Semantics(header:true)`
/// avec libellé « Étape k sur N : titre », insets et alignements
/// **directionnels**, couleurs dérivées du `ColorScheme` ou des overrides
/// nullables de [ZStepperConfig] (aucun littéral — invariants AD-13/FR-26/AD-6).
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

  /// Rendu compact « leading + titre » (numbered/icons) — style `numbered`
  /// par défaut.
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

/// État d'une ligne de rail **en accordéon** ([ZStepsDisplay.accordion]).
/// `null` (absence de valeur) = mode « tout affiché », où la notion n'existe pas.
enum _RowAccordionState {
  /// L'étape **active** : la seule dépliée.
  active,

  /// Une étape **déjà franchie** (index < index actif).
  completed,

  /// Une étape **à venir** (index > index actif).
  pending,
}

/// Une **étape dépliée** du mode « tout affiché » : badge circulaire numéroté,
/// segment de rail, titre + sous-titre, puis le contenu de l'étape.
///
/// ## Rendu du rail : directionnel, pas positionné en dur
///
/// Un rail peint avec des `Positioned` **`left:`** (physique) dans un `Stack`
/// se placerait du mauvais côté en RTL (invariant AD-13). Ici le rail est
/// peint par un [_RailPainter] qui reçoit la [TextDirection] : côté **début
/// de lecture** dans les deux sens.
///
/// ## Pourquoi un `CustomPaint` et pas un `IntrinsicHeight`
///
/// Composer `IntrinsicHeight` + `Row(stretch)` pour qu'une colonne de rail
/// atteigne la hauteur de l'étape mesurerait DEUX fois le sous-arbre — sur
/// une étape qui contient un formulaire entier, et répété pour chaque étape
/// d'une liste virtualisée, le coût serait significatif. Le `CustomPaint` se
/// dimensionne sur son enfant et peint le rail dans la gouttière : **une**
/// passe de layout.
class _AllStepsRow extends StatelessWidget {
  const _AllStepsRow({
    required this.index,
    required this.total,
    required this.step,
    required this.config,
    required this.isLast,
    required this.content,
    this.onHeaderTap,
    this.accordionState,
  });

  final int index;
  final int total;
  final ZEditionStep step;
  final ZStepperConfig config;
  final bool isLast;

  /// Contenu de l'étape, ou **`null`** si elle est **repliée** (accordéon) :
  /// rien n'est alors monté sous l'en-tête.
  final Widget? content;

  /// Rend l'en-tête **tapable** (accordéon). `null` (défaut) ⇒ en-tête inerte,
  /// c'est-à-dire le mode « tout affiché » **inchangé**.
  final VoidCallback? onHeaderTap;

  /// État d'accordéon de la ligne, ou **`null`** en mode « tout affiché ».
  ///
  /// UN seul canal nullable, et non deux booléens : `null` est alors la
  /// preuve syntaxique que le mode « tout affiché » emprunte exactement les
  /// mêmes branches (badge `activeOf`, titre gras, numéro dans le badge,
  /// aucun drapeau sémantique `expanded`). Deux booléens auraient autorisé la
  /// combinaison « replié ET complété », qui n'existe pas ici.
  final _RowAccordionState? accordionState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ZcrudTheme tokens = ZcrudTheme.of(context);

    // Chaîne FR-26 stricte : paramètre (`ZStepperConfig`) > jeton (`ZcrudTheme`)
    // > rôle (`ColorScheme`) / mesure de référence. AUCUN littéral de couleur.
    // Mode « tout affiché » : `expanded`/`completed` valent leur défaut, donc
    // `badgeColor == config.activeOf(scheme)`. En accordéon, l'état pilote la
    // couleur.
    final Color badgeColor = switch (accordionState) {
      null || _RowAccordionState.active => config.activeOf(scheme),
      _RowAccordionState.completed => config.completedOf(scheme),
      _RowAccordionState.pending => config.inactiveOf(scheme),
    };
    final Color railColor =
        config.railColor ?? tokens.stepperRailColor ?? scheme.outlineVariant;
    // Un blanc littéral serait illisible dès qu'un hôte choisit un
    // `activeColor` clair. À défaut de réglage, on DÉRIVE le contraste.
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

    // Invariant AD-13 — l'étape active ne peut PAS être signalée par la seule
    // couleur. Deux marques NON chromatiques s'y ajoutent en accordéon : le
    // titre en **gras** (l'étape en attente est en graisse normale) et le
    // **contenu déplié**, qui n'existe que là. En mode « tout affiché »,
    // `accordionState` est `null` ⇒ gras partout.
    final bool isPending = accordionState == _RowAccordionState.pending;
    final Widget titleText = Text(
      title,
      textAlign: TextAlign.start,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: isPending ? FontWeight.normal : FontWeight.bold,
      ),
    );

    final Widget headerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (config.showLabels) titleText,
        if (config.showSubtitles && (subtitleWidget != null || subtitle != null))
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
            child: _StepSubtitle(source: subtitle, provided: subtitleWidget),
          ),
      ],
    );

    // Patron `_CollapsibleSectionHeader` (`dynamic_edition.dart`), à la lettre :
    // `Semantics(button/expanded/label) > InkWell > ConstrainedBox(minHeight:48)`.
    // La `ConstrainedBox` est DANS l'`InkWell` : la zone tapable elle-même fait
    // donc ≥ 48 dp, et la contrainte est LIANTE sur l'enfant clé.
    final Widget header = Semantics(
      header: true,
      button: onHeaderTap != null,
      expanded: accordionState == null
          ? null
          : accordionState == _RowAccordionState.active,
      label: 'Étape ${index + 1} sur $total : $title',
      child: onHeaderTap == null
          ? headerColumn
          : InkWell(
              onTap: onHeaderTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  key: ValueKey<String>('zstep:header:$index'),
                  alignment: AlignmentDirectional.centerStart,
                  child: headerColumn,
                ),
              ),
            ),
    );

    final Widget badge = Container(
      width: badgeSize,
      height: badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      // Marque NON chromatique d'une étape franchie (parité legacy : le badge
      // d'une étape complétée porte une coche, pas son numéro).
      child: accordionState == _RowAccordionState.completed
          ? Icon(Icons.check, size: badgeSize * 0.6, color: badgeForeground)
          : Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: badgeForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    final Widget? content = this.content;
    final Widget body = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, 0, isLast ? 0 : gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(alignment: AlignmentDirectional.centerStart, child: header),
          // Étape REPLIÉE : ni contenu, ni l'espace qui l'accompagne.
          if (content != null) ...<Widget>[
            const SizedBox(height: 8),
            content,
          ],
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
/// Un sous-titre peut se rendre en texte riche (Markdown, par exemple). Le
/// moteur de rendu n'entre PAS dans `zcrud_core` (invariant AD-1) : il est
/// injecté par l'hôte via le port [ZRichTextRenderer]
/// (`ZcrudScope.richTextRenderer`).
///
/// * **Aucun renderer** (défaut) ⇒ `Text` simple, comportement inchangé pour
///   un hôte passif.
/// * **Renderer qui décline** (`null`) ⇒ même repli texte simple.
/// * **Renderer qui LÈVE** ⇒ même repli texte simple (invariant AD-10 : un
///   seam d'hôte fautif ne fait jamais tomber le formulaire).
///
/// ## L'annonce au lecteur d'écran (invariant AD-13)
///
/// Les deux voies doivent annoncer **exactement une fois**. Le rendu riche
/// porte DÉJÀ ses propres nœuds de texte : y superposer un `Semantics(label:)`
/// **doublerait** l'annonce. Mais un renderer libre peut aussi ne produire
/// AUCUNE sémantique (un `CustomPaint`, par exemple), et l'annonce serait
/// alors **perdue**.
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
