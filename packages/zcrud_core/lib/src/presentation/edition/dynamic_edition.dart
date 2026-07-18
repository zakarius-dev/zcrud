/// `DynamicEdition` — formulaire d'édition de **référence** assemblant N champs à
/// partir d'un `ZFormController` (AD-2, OBJECTIF PRODUIT N°1 / SM-1).
///
/// origine: E3-1 porte la preuve **plein-formulaire** de SM-1 (≥ 30 champs, ≥ 3
/// sections, 100 caractères). Le montage garantit par conception qu'une frappe
/// ne reconstruit QUE le champ courant :
/// - le `build` du formulaire n'observe QUE des canaux **structurels**
///   (`controller.visibleFields` + l'état de repli local `_collapsed`) via un
///   `ListenableBuilder` — il n'écoute JAMAIS une tranche de valeur ; une frappe
///   (qui ne touche aucun de ces canaux) ne le ré-exécute donc pas ;
/// - les champs sont montés via **`ListView.builder`** (jamais
///   `ListView(children: [...])`) — chaque champ porte `key: ValueKey(name)`
///   (place stable → réutilisation d'`Element`/`State` au rebuild, UJ-2) ;
/// - **aucun** `setState` de niveau formulaire dans la voie de frappe.
///
/// **E3-4** ajoute AUTOUR de ce cœur, sans jamais élargir la frontière de rebuild :
/// - **Champs conditionnels** (`ZFieldSpec.condition`) : un sélecteur de
///   visibilité **dérivé** ([_ConditionalVisibilityBinder]-like, fondu dans le
///   `State`) abonné UNIQUEMENT aux **champs de garde** (union des `field`
///   référencés par les conditions — [zGuardFieldsOf]) recalcule l'ensemble
///   visible en **ordre canonique** et pilote `setVisibleFields` (no-op si
///   inchangé). Une frappe sur un champ **non-garde** ne déclenche AUCUN recalcul.
/// - **Sections repliables** ([ZEditionSection.collapsible]) : en-tête accessible
///   (`Semantics(button, expanded, label)`, cible ≥ 48 dp, `EdgeInsetsDirectional`)
///   ; l'état d'expansion vit dans le `State` (canal `_collapsed`), survit à un
///   rebuild structurel, et n'affecte PAS `visibleFields` (orthogonal, AC9) ; le
///   repli masque VISUELLEMENT les membres sans détruire leurs tranches.
/// - **Mode lecture** (`readOnly` global) : chaque champ est rendu via une spec
///   effective `spec.copyWith(readOnly: true)` (réutilise le respect de
///   `field.readOnly` déjà présent dans toutes les familles). `showIfNull:false`
///   masque en lecture les champs vides (sans effet hors mode lecture).
/// - **Grille responsive 12 colonnes** ([layout]) : chaque champ reçoit un
///   [ZResponsiveSpan] ; disposition via [ZResponsiveGrid] (reflow par
///   breakpoint, gouttières directionnelles).
///
/// **Contrat de reflet de valeur EXTERNE (documenté, câblage reporté E3-6/E7)** :
/// l'état DÉRIVÉ d'E3-4 (visibilité/lecture/showIfNull) relit `valueOf`/la tranche
/// à CHAQUE calcul — il reflète donc nativement toute écriture externe d'un champ
/// de garde, sans buffer interne. Le write-back des widgets à buffer d'édition
/// (texte/signature/sous-liste) se fera par re-amorçage clé-de-révision
/// (`ValueKey(name + reseedRevision)`) appliqué **hors focus** — livré par E3-6/E7.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_acl.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_theme.dart';
import '../z_form_controller.dart';
import 'z_field_widget.dart';
import 'z_responsive_grid.dart';
import 'z_section_collapse_store.dart';

/// MIN-2 (parité DODLP `withSpaceer`) — **espacement inter-champ type-dépendant**.
///
/// DODLP insère un `SizedBox` (≈ 12 dp) APRÈS certains types de champ « blocs »
/// (multi-ligne, sous-liste, fichier, signature…) pour aérer la densité, et rien
/// après les champs compacts. Cette fonction **pure** projette cette règle : elle
/// retourne [base] pour les types « blocs », et `0` sinon. `base` (défaut `0`) ⇒
/// **aucun** espacement (rétro-compat pixel stricte) ; l'app/le formulaire l'active
/// en passant `DynamicEdition.interFieldGap > 0`.
double zFieldGapAfter(EditionFieldType type, {double base = 0}) {
  if (base <= 0) return 0;
  switch (type) {
    case EditionFieldType.multiline:
    case EditionFieldType.subItems:
    case EditionFieldType.dynamicItem:
    case EditionFieldType.signature:
    case EditionFieldType.file:
    case EditionFieldType.image:
    case EditionFieldType.document:
    case EditionFieldType.markdown:
      return base;
    // ignore: no_default_cases
    default:
      return 0;
  }
}

/// Descripteur **présentation** d'une action de **niveau formulaire** (barre
/// d'actions en-tête de `DynamicEdition`, DP-14, gap M7).
///
/// Porte les métadonnées d'UI (`label`/`icon`/`tooltip`) + la permission requise
/// (`requiredPermission`, un [ZCrudAction] du port domaine — sens de dépendance
/// présentation → domaine) + le handler `onInvoke`. **Aucune règle métier** : le
/// gate se contente d'appeler `acl.can(requiredPermission, …)` (AD-16). Le
/// filtrage est cohérent avec les actions de LIGNE (`ZRowAction`) et la sous-liste
/// compacte (DP-6, mode `hide`).
@immutable
class ZFormAction {
  /// Construit une action de formulaire.
  ///
  /// [label]/[tooltip] sont des **clés l10n ou des littéraux** (résolus via
  /// `label(context, …)` — repli défensif sur la clé brute). À défaut, [tooltip]
  /// reprend [label].
  const ZFormAction({
    required this.id,
    required this.label,
    required this.requiredPermission,
    required this.onInvoke,
    this.icon,
    this.tooltip,
  });

  /// Identifiant stable (déterministe, pour les clés/tests).
  final String id;

  /// Libellé affiché (clé l10n ou littéral).
  final String label;

  /// Info-bulle (clé l10n ou littéral) ; à défaut, reprend [label].
  final String? tooltip;

  /// Icône optionnelle du bouton d'action.
  final IconData? icon;

  /// Permission requise, filtrée par `ZAcl` (AD-16). L'action est **masquée**
  /// (mode `hide`, cohérent DP-6) si `acl.can(requiredPermission, …)` est `false`.
  final ZCrudAction requiredPermission;

  /// Handler invoqué au tap (déjà lié par l'app ; le cœur ne l'interprète pas).
  final VoidCallback onInvoke;
}

/// Constructeur d'un widget de champ à partir de sa [ZFieldSpec] et du
/// [ZFormController]. Seam d'extension : à défaut, [DynamicEdition] rend le
/// dispatcher par type [ZFieldWidget] (E3-3a). La place stable
/// (`ValueKey(field.name)`) est garantie par [DynamicEdition] via `KeyedSubtree`
/// — un builder custom n'a donc PAS à la poser (garde L3/AC7).
typedef ZEditionFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController controller,
  ZFieldSpec field,
);

/// Section **visuelle** d'un formulaire : un titre et l'ensemble des noms de
/// champs qu'elle regroupe. Peut être **repliable** ([collapsible], E3-4).
@immutable
class ZEditionSection {
  /// Construit une section de titre [title] regroupant les champs [fields].
  ///
  /// [collapsible] (défaut `false`) rend l'en-tête actionnable (accordéon) ;
  /// [initiallyExpanded] (défaut `true`) fixe l'état de repli initial. Une
  /// section non repliable ignore [initiallyExpanded].
  const ZEditionSection({
    required this.title,
    required this.fields,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  /// Titre affiché de la section (clé l10n ou littéral — résolu côté hôte).
  final String title;

  /// Noms de champs appartenant à la section (ordre indicatif ; l'ordre effectif
  /// suit `visibleFields`).
  final List<String> fields;

  /// La section est-elle repliable (en-tête accordéon accessible — E3-4) ?
  final bool collapsible;

  /// État de repli initial d'une section repliable (`true` = dépliée).
  final bool initiallyExpanded;
}

/// Assemble un formulaire d'édition réactif **par tranche** depuis un
/// [controller] et la liste des [fields] connus, regroupés en [sections]
/// visuelles.
class DynamicEdition extends StatefulWidget {
  /// Construit le formulaire de référence.
  const DynamicEdition({
    required this.controller,
    required this.fields,
    this.sections = const <ZEditionSection>[],
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.fieldBuilder,
    this.readOnly = false,
    this.layout = const <String, ZResponsiveSpan>{},
    this.gridGutter = 8,
    this.gridRunGutter,
    this.conditionContext = const <String, Object?>{},
    this.manageVisibility = true,
    this.acl = const ZAllowAllAcl(),
    this.formActions = const <ZFormAction>[],
    this.collectionId,
    this.collapseStore,
    this.formId,
    this.interFieldGap = 0,
    this.onStructuralBuild,
    super.key,
  });

  /// Contrôleur détenant l'état (créé/possédé par l'hôte ; jamais recréé ici).
  final ZFormController controller;

  /// Catalogue des champs connus (source des [ZFieldSpec] par nom).
  final List<ZFieldSpec> fields;

  /// Sections visuelles (en-têtes ; repliables si `collapsible`). Vide = liste
  /// plate.
  final List<ZEditionSection> sections;

  /// Marge du `ListView` (héritée par l'hôte ; défaut : aucune).
  final EdgeInsetsGeometry? padding;

  /// `ListView.shrinkWrap` — pour imbrication dans un scroll parent.
  final bool shrinkWrap;

  /// `ListView.physics` — pour imbrication dans un scroll parent.
  final ScrollPhysics? physics;

  /// Seam de rendu de champ. À défaut : le dispatcher par type [ZFieldWidget]
  /// (E3-3a). La place stable est garantie par [DynamicEdition] (KeyedSubtree).
  final ZEditionFieldBuilder? fieldBuilder;

  /// **Mode lecture global** (E3-4) : quand `true`, chaque champ est rendu non
  /// éditable via une spec effective `readOnly: true` (le per-champ reste
  /// respecté hors mode global). Active aussi le filtre `showIfNull`.
  final bool readOnly;

  /// **Grille 12 colonnes** (E3-4) : span responsif par nom de champ. Vide = pas
  /// de grille (disposition en colonne pleine largeur — compat ascendante).
  final Map<String, ZResponsiveSpan> layout;

  /// Gouttière (dp) de la grille responsive (quand [layout] est non vide) —
  /// horizontale, et verticale par défaut si [gridRunGutter] est `null`.
  final double gridGutter;

  /// **Gouttière inter-rangées** (dp) de la grille responsive (AD-54, FR-38) :
  /// relayée à `ZResponsiveGrid.runGutter`. **Additif non-cassant** : `null`
  /// (défaut) ⇒ repli sur [gridGutter] (comportement symétrique inchangé). Non
  /// `null` ⇒ aération verticale distincte (parité DODLP `verticalSpacing`, ex.
  /// `gridGutter: 16, gridRunGutter: 8`). Sans effet hors grille ([layout] vide).
  final double? gridRunGutter;

  /// **Contexte d'édition** (DP-2, B3) : clés externes au formulaire lues par les
  /// feuilles `ZCondition` de source `ZValueSource.context` (`crud`/`mode`/
  /// drapeaux applicatifs). Défaut vide ⇒ **rétro-compat totale** (une condition
  /// `context` sur une clé absente résout `null`, défensif — AD-10).
  ///
  /// Convention : `crud` en `String` camelCase (`'read'`/`'create'`/`'update'`/
  /// `'delete'`, miroir de l'enum `Crud` DODLP), `mode` en `String`, drapeaux en
  /// `bool`. Un changement de contenu déclenche **un** recalcul structurel de
  /// visibilité (via `didUpdateWidget`), **jamais** un abonnement par frappe :
  /// seules les clés de `zContextGuardKeysOf` sont surveillées.
  final Map<String, Object?> conditionContext;

  /// **Pilotage de `visibleFields`** (DP-9, imbrication de steppers) : quand
  /// `true` (défaut → comportement E3-1..E3-4 **inchangé**), ce formulaire GÈRE
  /// `controller.visibleFields` (amorçage + souscription aux champs de garde +
  /// `setVisibleFields`). Quand `false`, il n'écrit JAMAIS `visibleFields` et ne
  /// s'abonne PAS aux gardes : il rend **passivement** l'intersection de
  /// `controller.visibleFields` avec ses `fields`. Sert le nesting de steppers où
  /// un **unique** propriétaire (le stepper RACINE) écrit la fenêtre = union du
  /// chemin actif (AD-2, single-writer) ; les zones d'étape imbriquées ne se
  /// battent alors jamais sur `visibleFields`.
  final bool manageVisibility;

  /// **Port d'autorisation** (DP-14, gap M7) filtrant les [formActions] de niveau
  /// formulaire. Défaut `const ZAllowAllAcl()` (permissif) ⇒ comportement
  /// **strictement identique** à E3-1..E3-4/DP-2/DP-9 quand [formActions] est vide.
  /// **Aucune règle métier** dans le cœur : le gate appelle `acl.can(…)` (AD-16).
  final ZAcl acl;

  /// **Actions de niveau formulaire** (barre d'actions en-tête, DP-14). Chaque
  /// action est **masquée** (mode `hide`, cohérent DP-6) si son
  /// `requiredPermission` n'est pas autorisé par [acl]. Défaut `const []` ⇒
  /// **aucune zone d'actions rendue** (rétro-compat pixel). Le gate est évalué
  /// **uniquement** dans la voie de build **structurel** (jamais par frappe —
  /// SM-1) : voir [build].
  final List<ZFormAction> formActions;

  /// Identifiant de collection éventuel, propagé **tel quel** à
  /// `acl.can(…, collectionId:)` (seam neutre, aucune règle métier — AD-16).
  final String? collectionId;

  /// **Seam de persistance NEUTRE du repli des sections** (MIN-2, parité DODLP
  /// GetStorage). `null` (défaut) ⇒ état de repli **en mémoire** uniquement
  /// (comportement historique inchangé). Non `null` ⇒ l'état de repli est
  /// (dé)chargé via ce port (impl GetStorage/shared_preferences déférée au
  /// binding/app — AD-1). Voir [ZSectionCollapseStore].
  final ZSectionCollapseStore? collapseStore;

  /// Clé de portée passée telle quelle à [collapseStore] (`null` ⇒ portée
  /// globale). Sert à distinguer l'état de repli de plusieurs formulaires.
  final String? formId;

  /// **Espacement inter-champ** (MIN-2, parité DODLP `withSpaceer`). `0` (défaut)
  /// ⇒ **aucun** espace additionnel (rétro-compat pixel stricte). `> 0` ⇒ un
  /// `SizedBox` type-dépendant ([zFieldGapAfter]) est inséré APRÈS les champs
  /// « blocs » dans le rendu en colonne (jamais après un champ compact). Sans
  /// effet en grille (l'espacement y est porté par [gridGutter]).
  final double interFieldGap;

  /// Hook d'instrumentation : appelé à chaque (re)build **structurel** — compteur
  /// de build de niveau formulaire pour SM-1 (reste inchangé pendant la saisie).
  @visibleForTesting
  final VoidCallback? onStructuralBuild;

  @override
  State<DynamicEdition> createState() => _DynamicEditionState();
}

class _DynamicEditionState extends State<DynamicEdition> {
  /// Index `name → spec` (identité de valeur, recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Index `name → titre de section` (pour l'interleave des en-têtes).
  late Map<String, String> _sectionByField;

  /// Champs de **garde** : union des `field` de source `state` référencés par les
  /// conditions. Le sélecteur de visibilité s'abonne UNIQUEMENT à ceux-ci (AC3,
  /// SM-1) — les feuilles `persisted`/`context` en sont exclues (DP-2, B3).
  late Set<String> _guardFields;

  /// Clés de **contexte** référencées par les conditions (source `context`). Un
  /// changement de leur valeur dans `widget.conditionContext` déclenche **un**
  /// recalcul structurel (jamais un abonnement par frappe — DP-2, B3).
  late Set<String> _contextGuardKeys;

  /// `true` s'il existe AU MOINS une condition (toutes sources confondues). Gate
  /// du recalcul d'amorçage : sans condition on respecte l'ensemble visible fourni
  /// par l'hôte (compat ascendante), même si `_guardFields` est vide (cas d'une
  /// condition uniquement `context`/`persisted`).
  late bool _hasConditions;

  /// `true` s'il existe AU MOINS une feuille de source `persisted` (DP-2
  /// MEDIUM-1). La baseline n'est pas immuable : `reseed`/`markPristine` la mutent
  /// (le `reset` la restaure). Quand c'est vrai, la visibilité doit être
  /// recalculée sur chaque `reseedRevision` (canal STRUCTUREL, hors SM-1).
  late bool _hasPersistedGuard;

  /// Tranches réactives des champs de garde auxquelles [_onGuardChanged] est
  /// abonné (référence stable pour le retrait en `dispose`/`didUpdateWidget`).
  final List<Listenable> _guardListenables = <Listenable>[];

  /// `reseedRevision` du controller courant auquel [_onReseed] est abonné
  /// UNIQUEMENT si [_hasPersistedGuard] (référence stable pour le retrait).
  Listenable? _reseedListenable;

  /// Canal STRUCTUREL local : titres des sections **repliées**. Piloté par les
  /// en-têtes ; orthogonal à `controller.visibleFields` (AC9). Vit dans le
  /// `State` ⇒ survit aux rebuilds structurels ET au recyclage `ListView.builder`.
  late final ValueNotifier<Set<String>> _collapsed;

  /// Listenable fusionné observé par le `build` structurel : `visibleFields`
  /// (conditionnel) + `_collapsed` (repli). Aucune tranche de valeur.
  late Listenable _structural;

  @override
  void initState() {
    super.initState();
    _collapsed = ValueNotifier<Set<String>>(_initialCollapsed());
    _rebuildIndexes();
    _bindGuards();
    _bindReseed();
    _structural = Listenable.merge(<Listenable?>[
      widget.controller.visibleFields,
      _collapsed,
    ]);
    // Amorçage : calcule la visibilité initiale depuis les valeurs du controller,
    // la baseline (persisted) et le contexte (uniquement s'il existe des
    // conditions — sinon on respecte l'ensemble visible fourni par l'hôte, compat
    // ascendante ; une condition `context`/`persisted` seule doit aussi amorcer).
    if (widget.manageVisibility && _hasConditions) {
      _recomputeVisibility();
    }
  }

  @override
  void didUpdateWidget(DynamicEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final fieldsChanged = !identical(oldWidget.fields, widget.fields);
    if (controllerChanged || fieldsChanged) {
      _rebuildIndexes();
      _bindGuards();
      _bindReseed();
      if (controllerChanged) {
        _structural = Listenable.merge(<Listenable?>[
          widget.controller.visibleFields,
          _collapsed,
        ]);
      }
      if (widget.manageVisibility && _hasConditions) {
        _recomputeVisibility();
      }
      return;
    }
    // Changement de CONTEXTE d'édition (crud/mode/drapeaux) hors changement
    // structurel de controller/fields : recalcul UNIQUE de la visibilité si une
    // clé de contexte réellement surveillée a changé de valeur (DP-2, B3). Jamais
    // un abonnement par frappe — le canal structurel `setVisibleFields` est no-op
    // si l'ensemble visible est inchangé.
    if (widget.manageVisibility &&
        _contextGuardKeys.isNotEmpty &&
        _contextChanged(oldWidget.conditionContext, widget.conditionContext)) {
      _recomputeVisibility();
    }
  }

  /// `true` si au moins une clé de [_contextGuardKeys] a changé de valeur entre
  /// [before] et [after] (comparaison de contenu, `null`-safe).
  bool _contextChanged(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) {
    if (identical(before, after)) return false;
    for (final k in _contextGuardKeys) {
      if (before[k] != after[k]) return true;
    }
    return false;
  }

  /// État de repli initial. Défauts = sections `collapsible` déclarées
  /// `initiallyExpanded: false`. MIN-2 : si un [DynamicEdition.collapseStore] est
  /// fourni, l'état **persisté** est autoritaire (restreint aux titres repliables
  /// courants) ; à défaut de persistance, les défauts sont **amorcés** dans le
  /// store. Défensif (AD-10) : toute erreur du store ⇒ repli sur les défauts
  /// mémoire, jamais un crash.
  Set<String> _initialCollapsed() {
    final defaults = <String>{
      for (final s in widget.sections)
        if (s.collapsible && !s.initiallyExpanded) s.title,
    };
    final store = widget.collapseStore;
    if (store == null) return defaults;
    final collapsibleTitles = <String>{
      for (final s in widget.sections)
        if (s.collapsible) s.title,
    };
    try {
      final persisted = store.loadCollapsed(widget.formId);
      if (persisted.isEmpty) {
        // Aucune persistance encore : amorce le store avec les défauts.
        if (defaults.isNotEmpty) store.saveCollapsed(widget.formId, defaults);
        return defaults;
      }
      return persisted.intersection(collapsibleTitles);
    } catch (_) {
      return defaults;
    }
  }

  /// Persiste l'état de repli courant via le store (défensif — AD-10).
  void _persistCollapsed(Set<String> collapsed) {
    final store = widget.collapseStore;
    if (store == null) return;
    try {
      store.saveCollapsed(widget.formId, collapsed);
    } catch (_) {
      // Une impl de store fautive ne casse jamais le formulaire.
    }
  }

  void _rebuildIndexes() {
    _specByName = <String, ZFieldSpec>{
      for (final f in widget.fields) f.name: f,
    };
    _sectionByField = <String, String>{
      for (final s in widget.sections)
        for (final n in s.fields) n: s.title,
    };
    final conditions =
        widget.fields.map((f) => f.condition).toList(growable: false);
    _guardFields = zGuardFieldsOf(conditions);
    _contextGuardKeys = zContextGuardKeysOf(conditions);
    _hasPersistedGuard = zHasPersistedGuard(conditions);
    _hasConditions = widget.fields.any((f) => f.condition != null);
  }

  /// (Ré)abonne [_onGuardChanged] aux tranches des champs de garde UNIQUEMENT.
  ///
  /// En mode passif (`manageVisibility == false`, DP-9 nesting) : aucun abonnement
  /// — la fenêtre est pilotée par le stepper RACINE (single-writer), ce formulaire
  /// ne recalcule ni n'écrit `visibleFields`.
  void _bindGuards() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    if (!widget.manageVisibility) return;
    for (final g in _guardFields) {
      final l = widget.controller.fieldListenable(g);
      l.addListener(_onGuardChanged);
      _guardListenables.add(l);
    }
  }

  void _onGuardChanged() => _recomputeVisibility();

  /// (Ré)abonne [_onReseed] à `controller.reseedRevision` UNIQUEMENT si une
  /// feuille `persisted` existe (DP-2 MEDIUM-1). `reseed`/`markPristine` mutent la
  /// baseline lue par les conditions `persisted` sans changer les tranches d'état
  /// ni le contexte : sans cet abonnement, la visibilité resterait obsolète après
  /// un chargement async (E7). Canal STRUCTUREL (par revision, jamais par frappe).
  void _bindReseed() {
    _reseedListenable?.removeListener(_onReseed);
    _reseedListenable = null;
    if (widget.manageVisibility && _hasPersistedGuard) {
      final l = widget.controller.reseedRevision;
      l.addListener(_onReseed);
      _reseedListenable = l;
    }
  }

  void _onReseed() => _recomputeVisibility();

  /// Recalcule l'ensemble visible = **ordre canonique** de [widget.fields] filtré
  /// par [evaluateZCondition], puis pilote `setVisibleFields` (no-op si inchangé
  /// — AC4). Préserve la PLACE ordinale (réinsertion à l'index canonique — AC5)
  /// et ne détruit JAMAIS de tranche (le controller conserve ses slices).
  void _recomputeVisibility() {
    final ctx = widget.conditionContext;
    final next = <String>[
      for (final f in widget.fields)
        if (f.condition == null ||
            evaluateZCondition(
              f.condition!,
              widget.controller.valueOf,
              persistedValueOf: widget.controller.baselineValueOf,
              contextValueOf: (k) => ctx[k],
            ))
          f.name,
    ];
    widget.controller.setVisibleFields(next);
  }

  @override
  void dispose() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    _reseedListenable?.removeListener(_onReseed);
    _reseedListenable = null;
    _collapsed.dispose();
    super.dispose();
  }

  // ── Filtres de présentation (mode lecture) ────────────────────────────────

  /// `true` si une valeur compte comme **vide** pour `showIfNull` : `null` ou
  /// collection/chaîne vide. `false`/`0` NE sont PAS vides (valeurs affichables).
  static bool _isEmptyValue(Object? v) {
    if (v == null) return true;
    if (v is String) return v.isEmpty;
    if (v is Iterable) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  /// En mode lecture, masque les champs vides dont `showIfNull == false`. Hors
  /// mode lecture : toujours affiché (AC11).
  bool _renderInReadMode(ZFieldSpec spec) {
    if (!widget.readOnly) return true;
    if (spec.showIfNull) return true;
    return !_isEmptyValue(widget.controller.valueOf(spec.name));
  }

  /// Spec **effective** : force `readOnly` en mode lecture global (réutilise le
  /// respect de `field.readOnly` par les familles — aucune réécriture).
  ZFieldSpec _effective(ZFieldSpec spec) =>
      widget.readOnly && !spec.readOnly ? spec.copyWith(readOnly: true) : spec;

  /// Padding **effectif** du `ListView` : le [DynamicEdition.padding] explicite
  /// prime ; sinon repli sur le token d'aération `ZcrudTheme.formPadding` (AD-54,
  /// FR-26 — jamais une constante littérale). Lu via `ZcrudTheme.of(context)`
  /// (scope → extension → repli dérivé du `Theme`).
  EdgeInsetsGeometry _resolvedPadding(BuildContext context) =>
      widget.padding ?? ZcrudTheme.of(context).formPadding;

  bool get _grouped =>
      widget.layout.isNotEmpty ||
      widget.sections.any((s) => s.collapsible);

  /// Actions de formulaire **autorisées** (ACL), dans l'ordre déclaré. Évalué
  /// UNIQUEMENT dans la voie structurelle (jamais par frappe — SM-1). Défensif
  /// (AD-10) : une ACL app-supplied qui **lève** ⇒ action masquée (fail-closed),
  /// jamais de crash du formulaire ; liste vide ⇒ `const []`.
  List<ZFormAction> _permittedFormActions() {
    final actions = widget.formActions;
    if (actions.isEmpty) return const <ZFormAction>[];
    final acl = widget.acl;
    final result = <ZFormAction>[];
    for (final a in actions) {
      if (_can(acl, a.requiredPermission)) result.add(a);
    }
    return result;
  }

  bool _can(ZAcl acl, ZCrudAction action) {
    try {
      return acl.can(action, collectionId: widget.collectionId);
    } catch (_) {
      // Défensif (AD-10) : une ACL app-supplied défaillante ne plante jamais le
      // formulaire — l'action est simplement non rendue.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Canaux STRUCTURELS uniquement : ce builder ne se ré-exécute que lorsque
    // l'ensemble visible OU l'état de repli change (jamais sur une frappe). Le
    // gate ACL + la barre d'actions vivent DANS cette voie structurelle : une
    // frappe ne les recalcule pas (SM-1, objectif produit n°1).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final visible = widget.controller.visibleFields.value;
        final list = _grouped ? _buildGrouped(visible) : _buildFlat(visible);

        // Rétro-compat pixel : sans action AUTORISÉE (défaut `formActions` vide,
        // ou toutes refusées par l'ACL), aucune zone d'actions n'est rendue — le
        // rendu est strictement celui d'avant DP-14.
        final actions = _permittedFormActions();
        if (actions.isEmpty) return list;

        // Barre d'actions en TÊTE + liste. En `shrinkWrap`, la liste garde sa
        // hauteur intrinsèque (pas d'`Expanded`) ; sinon elle occupe l'espace
        // restant (`Expanded`) — parent borné requis, cohérent avec l'usage
        // habituel de `DynamicEdition`.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            _FormActionBar(actions: actions),
            if (widget.shrinkWrap) list else Expanded(child: list),
          ],
        );
      },
    );
  }

  // ── Rendu PLAT (compat E3-1 : pas de grille, pas de section repliable) ─────

  Widget _buildFlat(List<String> visible) {
    final rows = <_EditionRow>[];
    String? currentSection;
    for (final name in visible) {
      final spec = _specByName[name];
      if (spec == null) continue;
      if (!_renderInReadMode(spec)) continue;
      final section = _sectionByField[name];
      if (section != null && section != currentSection) {
        rows.add(_EditionRow.header(section));
      }
      currentSection = section;
      rows.add(_EditionRow.field(_effective(spec)));
    }

    // Index inverse `Key → position` : permet au `ListView.builder` (sliver
    // paresseux) de RETROUVER l'`Element` d'un champ keyé qui a CHANGÉ d'index
    // (insertion/retrait d'un champ conditionnel voisin) et de PRÉSERVER son
    // `State`/focus (AC6). Sans lui, un champ décalé serait remonté à neuf
    // (focus perdu) — le simple `ValueKey` ne suffit pas dans un sliver lazy.
    final keyIndex = <Key, int>{};
    for (var i = 0; i < rows.length; i++) {
      final k = rows[i].key;
      if (k != null) keyIndex[k] = i;
    }

    return ListView.builder(
      padding: _resolvedPadding(context),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: rows.length,
      findChildIndexCallback: (key) => keyIndex[key],
      itemBuilder: (context, i) => rows[i].build(context, this),
    );
  }

  // ── Rendu GROUPÉ (sections repliables et/ou grille responsive) ────────────

  Widget _buildGrouped(List<String> visible) {
    final visibleSet = visible.toSet();
    final blocks = <Widget>[];

    // Index inverse `Key → position` des BLOCS : comme le chemin plat, il permet
    // au `ListView.builder` (sliver paresseux) de RETROUVER l'`Element` d'un bloc
    // keyé qui a CHANGÉ d'index — bloc « loose » de tête qui bascule (l.369) ou
    // section qui se vide et est sautée (`if (members.isEmpty) continue`) — et de
    // PRÉSERVER le `State`/focus des champs des blocs aval (AC5/AC6/AD-2). Chaque
    // bloc est keyé sur une identité STABLE (`__loose__` / titre de section).
    final blockKeyIndex = <Key, int>{};
    void addBlock(Key key, Widget child) {
      blockKeyIndex[key] = blocks.length;
      blocks.add(KeyedSubtree(key: key, child: child));
    }

    // (1) Champs sans section, dans l'ordre visible (bloc de tête sans en-tête).
    final loose = <ZFieldSpec>[
      for (final name in visible)
        if (_specByName[name] != null &&
            !_sectionByField.containsKey(name) &&
            _renderInReadMode(_specByName[name]!))
          _effective(_specByName[name]!),
    ];
    if (loose.isNotEmpty) {
      addBlock(const ValueKey<String>('block:__loose__'), _membersLayout(loose));
    }

    // (2) Sections dans leur ordre déclaré ; membres filtrés par visibilité +
    //     mode lecture. Une section repliée cache ses membres (slices intacts).
    for (final section in widget.sections) {
      final members = <ZFieldSpec>[
        for (final name in section.fields)
          if (visibleSet.contains(name) &&
              _specByName[name] != null &&
              _renderInReadMode(_specByName[name]!))
            _effective(_specByName[name]!),
      ];
      if (members.isEmpty) continue;

      final expanded =
          !(section.collapsible && _collapsed.value.contains(section.title));

      final header = section.collapsible
          ? _CollapsibleSectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
              expanded: expanded,
              onToggle: () => _toggleSection(section.title),
            )
          : _SectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
            );

      addBlock(
        ValueKey<String>('block:section:${section.title}'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            // Repli = masquage VISUEL sans destruction de slice (les membres ne
            // sont simplement pas montés ; le controller conserve leurs tranches).
            if (expanded) _membersLayout(members),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: _resolvedPadding(context),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: blocks.length,
      findChildIndexCallback: (key) => blockKeyIndex[key],
      itemBuilder: (context, i) => blocks[i],
    );
  }

  /// Dispose une liste de champs : en **grille 12 colonnes** si [widget.layout]
  /// est fourni, sinon en colonne pleine largeur. Chaque cellule est keyée
  /// `ValueKey(name)` (place stable NON contournable).
  Widget _membersLayout(List<ZFieldSpec> members) {
    if (widget.layout.isEmpty) {
      // MIN-2 (`withSpaceer`) : insère un `SizedBox` type-dépendant APRÈS les
      // champs « blocs » quand `interFieldGap > 0` (jamais après le dernier ;
      // aucun espace si `interFieldGap == 0` — rétro-compat pixel stricte).
      final children = <Widget>[];
      for (var i = 0; i < members.length; i++) {
        final spec = members[i];
        children.add(_buildField(context, spec));
        if (i < members.length - 1) {
          final gap = zFieldGapAfter(spec.type, base: widget.interFieldGap);
          if (gap > 0) children.add(SizedBox(height: gap));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
    // Grille : la place stable est portée par les CELLULES (enfants directs du
    // `Wrap`) via `keys`, PAS par un `KeyedSubtree` descendant — sinon `Wrap`
    // réconcilierait par position et un conditionnel inséré avant un champ
    // focalisé détruirait son `State` (focus/curseur perdus — AD-2/FR-1). On
    // fournit donc les enfants NON keyés à la racine (`_fieldChild`) + les clés à
    // part (la garde L3 « place stable non contournable » reste tenue par `keys`).
    return ZResponsiveGrid(
      gutter: widget.gridGutter,
      // AD-54/FR-38 : gouttière inter-rangées distincte si fournie (repli sur
      // `gutter` côté `ZResponsiveGrid` quand `null` — additif non-cassant).
      runGutter: widget.gridRunGutter,
      spans: <ZResponsiveSpan>[
        for (final spec in members)
          widget.layout[spec.name] ?? const ZResponsiveSpan(),
      ],
      keys: <Key?>[
        for (final spec in members) ValueKey<String>(spec.name),
      ],
      children: <Widget>[
        for (final spec in members) _fieldChild(context, spec),
      ],
    );
  }

  void _toggleSection(String title) {
    final next = Set<String>.of(_collapsed.value);
    if (!next.remove(title)) next.add(title);
    _collapsed.value = next; // notifie → rebuild STRUCTUREL (jamais une frappe).
    // MIN-2 : persiste l'état de repli (no-op si aucun store injecté).
    _persistCollapsed(next);
  }

  /// Sous-arbre RENDU d'un champ (dispatcher par type ou `fieldBuilder` custom),
  /// **sans** la place stable — celle-ci est posée par l'appelant (`KeyedSubtree`
  /// en colonne/plat, ou la clé de cellule `keys` en grille).
  Widget _fieldChild(BuildContext context, ZFieldSpec spec) {
    final builder = widget.fieldBuilder;
    return builder != null
        ? builder(context, widget.controller, spec)
        // DP-13 : propage le mode lecture global → fiche de consultation pour les
        // familles fiche-ables. `_effective` conserve `readOnly:true` (repli sûr
        // des familles non fiche-ables). Le `fieldBuilder` custom reste prioritaire.
        : ZFieldWidget(
            controller: widget.controller,
            field: spec,
            readMode: widget.readOnly,
          );
  }

  Widget _buildField(BuildContext context, ZFieldSpec spec) {
    // Garde L3 (AC7) : place stable NON contournable — même si un `fieldBuilder`
    // custom omet la clé, le champ reste keyé sur `spec.name` (préserve SM-1/
    // UJ-2 : rebuild externe ⇒ Element/State réutilisés).
    return KeyedSubtree(
      key: ValueKey<String>(spec.name),
      child: _fieldChild(context, spec),
    );
  }
}

/// Ligne du `ListView` PLAT : soit un **en-tête** de section, soit un **champ**.
@immutable
class _EditionRow {
  const _EditionRow.header(this.title) : spec = null;
  const _EditionRow.field(this.spec) : title = null;

  final String? title;
  final ZFieldSpec? spec;

  /// Clé du widget d'item (celle posée par `_buildField` : `ValueKey(name)`) —
  /// `null` pour un en-tête (non keyé). Alimente `findChildIndexCallback`.
  Key? get key {
    final s = spec;
    return s == null ? null : ValueKey<String>(s.name);
  }

  Widget build(BuildContext context, _DynamicEditionState parent) {
    final header = title;
    if (header != null) return _SectionHeader(title: header);
    return parent._buildField(context, spec!);
  }
}

/// En-tête de section **visuel** (non repliable). Style dérivé du thème (aucune
/// couleur codée en dur — FR-26) ; insets **directionnels** (AD-13).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
}

/// En-tête de section **repliable** (accordéon accessible — E3-4, AD-13).
///
/// - `Semantics(button, expanded, label)` explicite (AC7) ;
/// - **cible tactile ≥ 48 dp** (`minHeight`) ;
/// - insets **directionnels** (`EdgeInsetsDirectional`) et icône reflétant l'état
///   (aucune couleur codée en dur — thème).
///
/// L'état d'expansion est **détenu par le parent** ([_DynamicEditionState._collapsed])
/// : ce widget est sans état (rend [expanded], remonte [onToggle]). Justification
/// (résout l'ambiguïté story) : un état d'expansion porté par le `State` du parent
/// **survit** non seulement au rebuild structurel mais AUSSI au recyclage
/// `ListView.builder` (un `State` local d'en-tête serait perdu au défilement),
/// tout en restant orthogonal à `visibleFields` (AC9).
class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre d'actions de **niveau formulaire** (DP-14, gap M7). Rend les actions
/// **déjà filtrées** par l'ACL (mode `hide`). Insets **directionnels** ; couleurs
/// dérivées du thème (aucune couleur codée en dur — FR-26/AD-13).
class _FormActionBar extends StatelessWidget {
  const _FormActionBar({required this.actions});

  final List<ZFormAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final a in actions)
            _FormActionButton(
              key: ValueKey<String>('formAction:${a.id}'),
              action: a,
            ),
        ],
      ),
    );
  }
}

/// Bouton d'une action de formulaire : accessible (`Semantics(button)` + tooltip),
/// cible tactile **≥ 48 dp**, style dérivé du thème (AD-13, FR-26).
class _FormActionButton extends StatelessWidget {
  const _FormActionButton({required this.action, super.key});

  final ZFormAction action;

  @override
  Widget build(BuildContext context) {
    final labelText = label(context, action.label);
    final tip =
        action.tooltip == null ? labelText : label(context, action.tooltip!);
    final icon = action.icon;
    return Semantics(
      button: true,
      label: labelText,
      child: Tooltip(
        message: tip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: icon == null
              ? TextButton(
                  onPressed: action.onInvoke,
                  child: Text(labelText),
                )
              : TextButton.icon(
                  onPressed: action.onInvoke,
                  icon: Icon(icon),
                  label: Text(labelText),
                ),
        ),
      ),
    );
  }
}
