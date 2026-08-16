/// `ZcrudScope` — point d'injection des **seams** du cœur (AD-6, AD-15).
///
/// `InheritedWidget` zéro-dépendance qui porte le bundle immuable de
/// seams résolus et les expose aux widgets du moteur d'édition, SANS imposer un
/// gestionnaire d'état. Un binding peut fournir un scope enrichi ; le
/// chemin par défaut reste utilisable sans aucun manager (preuve du chemin
/// « zéro-dépendance » d'AD-15).
library;

import 'package:flutter/widgets.dart';

import '../domain/ports/cloud_storage_repository.dart';
import '../domain/ports/z_acl.dart';
import '../domain/ports/z_app_file_resolver.dart';
import '../domain/ports/z_choices_source.dart';
import '../domain/ports/z_date_display_formatter.dart';
import '../domain/ports/z_relation_crud.dart';
import '../domain/ports/z_relation_source.dart';
import 'dnd/z_drop_region_renderer.dart';
import 'edition/families/z_color_field_widget.dart';
import 'edition/z_field_adornment_view.dart';
import 'edition/z_file_picker.dart';
import 'edition/z_select_presenter.dart';
import 'edition/z_sub_list_seams.dart';
import 'edition/z_widget_registry.dart';
import 'l10n/z_labels.dart';
import 'list/z_list_renderer.dart';
import 'reorder/z_reorder_renderer.dart';
import 'theme/z_color_key_resolver.dart';
import 'theme/z_gradient_resolver.dart';
import 'theme/z_theme.dart';
import 'z_dependency_resolver.dart';
import 'z_rich_text_renderer.dart';
import 'z_scope_error.dart';

/// Sentinelle interne « argument non fourni » de [ZcrudScope.copyWith] et
/// [ZcrudScope.derive].
///
/// Même patron que le `copyWith` généré par `zcrud_generator` : elle permet de
/// distinguer un paramètre **omis** (la valeur du scope courant est héritée)
/// d'un `null` **explicite** (le seam nullable est remis à `null`, donc à son
/// repli par défaut).
const Object _zScopeUndefined = Object();

/// Scope d'injection Flutter-natif du cœur `zcrud_core`.
///
/// Porte un **bundle immuable de seams** résolus :
/// - [resolver] : seam de résolution de dépendances applicatives (défaut :
///   [ZDependencyResolver.throwing]) — inclut, côté binding, le **seam de cycle
///   de vie** du `ZFormController` (défaut zéro-config : cycle local possédé par
///   l'hôte) ;
/// - [acl] : port d'autorisation (défaut **fail-closed** [ZDenyAllAcl] : sans
///   ACL déclarée, aucun geste n'est offert) ;
/// - [labels] : registre de libellés surchargeables (défaut `null` →
///   résolution retombe sur `ZcrudLocalizations`) ;
/// - [theme] : design-tokens injectés (défaut `null` → `ZcrudTheme.of`
///   retombe sur `Theme.of(context)`) ;
/// - [widgetRegistry] : registre de widgets d'édition servis **ailleurs**
///   (AD-4 ; défaut `null` → tout type `registryOrFallback` retombe sur le repli
///   `ZUnsupportedFieldWidget`). Instanciable, jamais un singleton statique.
///
/// Résolution via [of] / [maybeOf]. Le constructeur par défaut (zéro-config) est
/// utilisable sans fournir de manager : il expose un [ZDenyAllAcl] et un
/// resolver throwing, `labels`/`theme` à `null` — les dépendances applicatives
/// DOIVENT être fournies explicitement (« seams throw par défaut », AD-6).
///
/// **Autorisations — refus par défaut.** Tant qu'aucune ACL n'est déclarée,
/// aucun geste (créer, modifier, mettre à la corbeille, restaurer, actions de
/// ligne) n'est offert. Déclarez la vôtre — `ZcrudScope(acl: MonAcl())` — ou,
/// en développement, déclarez explicitement l'ouverture totale :
/// `ZcrudScope(acl: const ZAllowAllAcl())`.
class ZcrudScope extends InheritedWidget {
  /// Construit le scope. Zéro-config par défaut : [resolver] throwing + [acl]
  /// **refusante** + [labels]/[theme] `null`. Un binding/app fournit des seams
  /// concrets en les passant ici.
  const ZcrudScope({
    required super.child,
    this.resolver = ZDependencyResolver.throwing,
    this.acl = const ZDenyAllAcl(),
    this.labels,
    this.theme,
    this.widgetRegistry,
    this.subListSeamRegistry,
    this.relationSourceRegistry,
    this.choicesSourceRegistry,
    this.relationCrudRegistry,
    this.filePicker,
    this.cloudStorage,
    this.appFileResolver,
    this.listRenderer,
    this.reorderRenderer,
    this.dropRegionRenderer,
    this.selectPresenter,
    this.iconResolver,
    this.colorPicker,
    this.colorKeyResolver,
    this.gradientResolver,
    this.richTextRenderer,
    this.dateDisplayFormatter,
    super.key,
  });

  /// Seam de résolution des dépendances applicatives (défaut : throwing).
  final ZDependencyResolver resolver;

  /// Port d'autorisation (défaut **fail-closed** : [ZDenyAllAcl]).
  ///
  /// Sans ACL déclarée, aucun geste n'est offert. Pour une ouverture totale
  /// assumée (développement, prototype), déclarez-la :
  /// `ZcrudScope(acl: const ZAllowAllAcl())`.
  final ZAcl acl;

  /// Registre de libellés surchargeables (défaut `null`).
  final ZcrudLabels? labels;

  /// Design-tokens injectés (défaut `null` → repli `Theme.of`).
  final ZcrudTheme? theme;

  /// Registre de widgets d'édition servis **ailleurs** (AD-4 ; défaut
  /// `null` → repli `ZUnsupportedFieldWidget`). Instanciable, injecté (jamais
  /// un singleton statique mutable).
  final ZWidgetRegistry? widgetRegistry;

  /// Registre des **seams de présentation** des sous-listes (`subItems`) et des
  /// items dynamiques (`dynamicItem`) — AD-4 ; défaut `null` ⇒ rendu natif
  /// **strictement** inchangé pour un hôte passif.
  ///
  /// C'est le canal par lequel un hôte déclare un titre d'item, un rendu libre
  /// de ligne, des actions supplémentaires, un conteneur de liste, un habillage
  /// d'en-tête, une transformation d'affichage ou une ACL propre au champ —
  /// **sans** remplacer le champ par un `fieldBuilder`, donc sans renoncer à
  /// l'agrégation vers la tranche parente, à la granularité (invariant AD-2),
  /// aux dialogues ni au soft-delete. Voir `ZSubListSeams` pour la matrice
  /// d'applicabilité par mode d'affichage.
  ///
  /// Chaînable (`ZSubListSeamRegistry(parent: …)`, ombrage enfant > parent),
  /// instanciable, injecté (jamais un singleton statique mutable).
  final ZSubListSeamRegistry? subListSeamRegistry;

  /// Registre de sources dynamiques du champ `relation` (AD-4 ;
  /// défaut `null` → tout champ `relation` retombe sur le **dropdown statique**
  /// sur `choices` — repli universel rétro-compatible). Instanciable, injecté
  /// (jamais un singleton statique mutable). L'impl concrète de `ZRelationSource`
  /// (flux repository + mapping entité→`ZFieldChoice` + filtre
  /// métier) vit hors du cœur (`zcrud_firestore`/app), jamais ici (AD-1).
  final ZRelationSourceRegistry? relationSourceRegistry;

  /// Registre de sources d'options **calculées** du champ `select` (AD-4 ;
  /// défaut `null` → tout `select` retombe sur `choicesFromKey` puis sur
  /// le **dropdown statique** sur `choices` — repli universel rétro-compatible).
  /// Instanciable, injecté (jamais un singleton statique mutable). L'impl concrète
  /// de `ZChoicesSource` (calcul métier des options depuis l'état) vit hors du
  /// cœur (binding/app), jamais ici (AD-1).
  final ZChoicesSourceRegistry? choicesSourceRegistry;

  /// Registre de handlers **CRUD inline** du champ `relation` (AD-4 ;
  /// défaut `null` → aucun bouton créer/modifier/copier — comportement du
  /// dropdown statique identique). Instanciable, injecté (jamais un singleton
  /// statique mutable). L'impl concrète
  /// de `ZRelationCrudHandler` (formulaire d'édition + repository create/update/copy)
  /// vit hors du cœur (app/`zcrud_firestore`), jamais ici (AD-1).
  final ZRelationCrudRegistry? relationCrudRegistry;

  /// Seam d'acquisition de fichiers (AD-1/AD-6 ; défaut `null` → actions
  /// scan/caméra/galerie/picker désactivées proprement). Impl concrète
  /// (image_picker/file_picker) fournie par l'app/binding, jamais le cœur.
  final ZFilePicker? filePicker;

  /// Port de stockage cloud (AD-1/AD-5/AD-6 ; défaut `null` → fichier
  /// reste `pending`, orchestration draft→cloud déférée à l'app/`onSubmit`).
  /// Impl concrète (Firebase Storage) fournie par `zcrud_firestore`,
  /// jamais le cœur.
  final CloudStorageRepository? cloudStorage;

  /// Port de résolution des **références opaques** de fichiers (`String` →
  /// `AppFile`), pour un hôte qui stocke des identifiants et non des objets
  /// fichier.
  ///
  /// Défaut `null` ⇒ comportement historique **strictement conservé** : les
  /// valeurs non-`AppFile` restent ignorées et AUCUN état n'est ajouté au rendu
  /// (hôte passif immobile). Injecter un résolveur active la voie de résolution
  /// **asynchrone**, tenue SOUS la frontière de rebuild du champ (AD-2 :
  /// jamais un rebuild du formulaire, jamais un élargissement de tranche) et
  /// intégralement dégradée (AD-10 : erreur, délai de garde, référence
  /// introuvable ⇒ états VISIBLES, jamais une exception ni un champ bloqué).
  ///
  /// Impl concrète (Firestore/Storage) hors du cœur (`zcrud_firestore`/app),
  /// jamais ici (AD-1). Jamais un singleton statique mutable.
  final ZAppFileResolver? appFileResolver;

  /// Seam de rendu de liste (AD-8 ; défaut `null` → `DynamicList`
  /// lève une [ZScopeError] actionnable tant qu'aucun backend n'est injecté).
  /// `zcrud_core` ne fournit AUCUNE implémentation concrète : le rendu Syncfusion
  /// (`ZSfDataGridRenderer`) vit dans `zcrud_list` et est injecté par l'app/le
  /// binding (`ZcrudScope(listRenderer: const ZSfDataGridRenderer())`). Un
  /// backend Material `DataTable` reste implémentable sur le même port. Jamais
  /// un singleton statique mutable.
  final ZListRenderer? listRenderer;

  /// Seam de **rendu réordonnable** (défaut `null` → le repli
  /// zéro-dépendance s'applique, donc AUCUNE régression
  /// pour un hôte qui n'injecte rien).
  ///
  /// Contrairement à [listRenderer], l'absence d'injection ne lève PAS : la
  /// capacité reste **fonctionnelle**, seulement non spécialisée — c'est
  /// l'exigence de défaut zéro-dépendance du port. Injecter permet de brancher
  /// un satellite adossé à un paquet de l'écosystème, ou une implémentation
  /// propre à l'application. Jamais un singleton statique mutable.
  final ZReorderRenderer? reorderRenderer;

  /// Seam de **zone de dépôt NATIVE** (défaut `null` →
  /// [ZNoDropRegionRenderer], qui rend le contenu SANS capacité de dépôt).
  ///
  /// Capacité DISTINCTE du réordonnancement : recevoir un fichier du système ou
  /// d'une autre application. Elle est isolée dans le satellite opt-in
  /// `zcrud_dnd` parce que son backend impose une CHAÎNE DE BUILD NATIVE à
  /// toute application consommatrice — coût qu'un hôte sans besoin de dépôt ne
  /// doit pas payer. Jamais un singleton statique mutable.
  final ZDropRegionRenderer? dropRegionRenderer;

  /// Seam de **présentation riche des familles de sélection** (défaut
  /// `null` → rendu **natif** zcrud strictement conservé). Injecté par l'app/le
  /// binding pour brancher un présentateur riche
  /// sur `select`/`radio`/`checkbox`/`relation`. `zcrud_core` ne fournit AUCUNE
  /// implémentation concrète : l'impl vit dans le paquet de sélection riche,
  /// jamais dans le cœur (AD-1). Le présentateur ne
  /// reçoit qu'un `ZSelectPresentation` neutre (jamais le `ZFormController` —
  /// AD-2). Jamais un singleton statique mutable.
  final ZSelectPresenter? selectPresenter;

  /// Résolveur d'**icône d'ornement** host-fourni (défaut `null` →
  /// le cœur retombe sur sa **table Material bornée** par défaut, puis `null` si
  /// la clé reste inconnue — AD-10). Traduit une **clé neutre** (`String`) de
  /// `ZFieldAdornment.icon(key)` en `IconData` **sans** que le domaine ne porte
  /// jamais d'`IconData` (AD-3/AD-14). Instanciable, injecté (jamais un singleton).
  final ZAdornmentIconResolver? iconResolver;

  /// **Seam de picker de couleur** host-fourni (roue HSV/hex/
  /// opacité tierce, ex. `flex_color_picker` ; défaut `null` → repli sur le
  /// **picker built-in NEUTRE** du cœur). Le cœur ne dépend d'AUCUN package de
  /// picker (AD-1) : l'impl concrète vit dans l'app/le binding. Instanciable,
  /// injecté (jamais un singleton statique mutable).
  final ZColorPicker? colorPicker;

  /// Résolveur de **couleur de clé de palette** host-fourni.
  ///
  /// Traduit une **clé neutre** (`String`, résolue par la palette applicative) en
  /// [ZColorPair] (fond + `on-` contrasté, AD-13) **sans** que le domaine
  /// applicatif ne porte jamais de `Color` (AD-1/AD-3).
  ///
  /// Ce champ est le **premier maillon** de la chaîne implémentée par
  /// [zResolveColorKey] / [zResolveColorKeyOrSlot] : seam hôte (ici) → repli du
  /// cœur dérivé du `ColorScheme` ([zDefaultColorKeyResolver], vocabulaire de
  /// rôles Material 3 uniquement) → slot déterministe ([zColorSlotPair]) ou
  /// `null` — jamais de throw (AD-10). C'est **ici** qu'une app injecte sa
  /// sémantique réelle (`success` en vert, `warning` en ambre… : Material 3 n'a
  /// pas ces rôles, le cœur ne les invente pas).
  ///
  /// Jumeau d'[iconResolver] (même nullabilité, même priorité, même ligne
  /// dans `updateShouldNotify`). Instanciable, injecté (jamais un singleton
  /// statique mutable).
  final ZColorKeyResolver? colorKeyResolver;

  /// Couture de dégradé hôte. `null` conserve le repli neutre ou
  /// l'accent uni ; fournir une instance `const` ou mémoïsée hors de `build`.
  final ZGradientResolver? gradientResolver;

  /// Seam de **rendu de texte riche**. `null` (défaut) ⇒
  /// tout balisage est rendu en **texte simple**, comportement d'aujourd'hui
  /// **strictement inchangé** pour un hôte passif.
  ///
  /// C'est par ce port qu'un hôte branche un moteur (par exemple celui de
  /// `zcrud_markdown`) pour rendre les **sous-titres d'étape** en Markdown, sans
  /// qu'aucune arête de rendu riche n'entre dans `zcrud_core` (AD-1). Fournir
  /// une instance `const` ou mémoïsée hors de `build`.
  final ZRichTextRenderer? richTextRenderer;

  /// Seam de **formatage d'affichage des dates**.
  /// `null` (défaut) ⇒ toute voie de lecture rend la **chaîne stockée brute**
  /// (l'ISO-8601) — comportement d'aujourd'hui **strictement inchangé** pour un
  /// hôte passif. C'est un changement visible UNIQUEMENT pour qui injecte.
  ///
  /// L'impl localisée (`intl`) vit hors du cœur (`zcrud_intl`) : AD-1 interdit à
  /// `zcrud_core` de dépendre d'`intl`. Fournir une instance `const` ou mémoïsée
  /// hors de `build` (AD-2 : aucun objet coûteux recréé par build).
  final ZDateDisplayFormatter? dateDisplayFormatter;

  /// Dérive un nouveau scope à partir de celui-ci en ne remplaçant que les
  /// seams nommés.
  ///
  /// Tout paramètre **omis** hérite de la valeur du scope courant — les seams
  /// non nommés ne sont jamais recopiés à la main, donc jamais perdus quand le
  /// paquet en ajoute un. Pour les seams **nullables** (par exemple [labels] ou
  /// [theme]), un `null` **explicite** remet le seam à `null` (son repli par
  /// défaut) : la distinction omis / `null` est portée par une sentinelle,
  /// comme dans le `copyWith` généré par `zcrud_generator`.
  ///
  /// [child] est requis : un scope dérivé enveloppe toujours son propre
  /// sous-arbre. [key] n'est jamais héritée du scope source (réutiliser une
  /// clé d'un widget encore monté serait une erreur d'arbre) ; fournissez-en
  /// une explicitement si nécessaire.
  ///
  /// Cas d'usage type : surcharger l'ACL d'un seul écran sans re-poser les
  /// autres seams. Voir aussi [derive], qui lit le scope ambiant depuis un
  /// `BuildContext`.
  ///
  /// ```dart
  /// ZcrudScope.of(context).copyWith(
  ///   acl: aclDeCetEcran,
  ///   child: monEcran,
  /// )
  /// ```
  ZcrudScope copyWith({
    required Widget child,
    Key? key,
    ZDependencyResolver? resolver,
    ZAcl? acl,
    Object? labels = _zScopeUndefined,
    Object? theme = _zScopeUndefined,
    Object? widgetRegistry = _zScopeUndefined,
    Object? subListSeamRegistry = _zScopeUndefined,
    Object? relationSourceRegistry = _zScopeUndefined,
    Object? choicesSourceRegistry = _zScopeUndefined,
    Object? relationCrudRegistry = _zScopeUndefined,
    Object? filePicker = _zScopeUndefined,
    Object? cloudStorage = _zScopeUndefined,
    Object? appFileResolver = _zScopeUndefined,
    Object? listRenderer = _zScopeUndefined,
    Object? reorderRenderer = _zScopeUndefined,
    Object? dropRegionRenderer = _zScopeUndefined,
    Object? selectPresenter = _zScopeUndefined,
    Object? iconResolver = _zScopeUndefined,
    Object? colorPicker = _zScopeUndefined,
    Object? colorKeyResolver = _zScopeUndefined,
    Object? gradientResolver = _zScopeUndefined,
    Object? richTextRenderer = _zScopeUndefined,
    Object? dateDisplayFormatter = _zScopeUndefined,
  }) =>
      ZcrudScope(
        key: key,
        resolver: resolver ?? this.resolver,
        acl: acl ?? this.acl,
        labels: identical(labels, _zScopeUndefined)
            ? this.labels
            : labels as ZcrudLabels?,
        theme: identical(theme, _zScopeUndefined)
            ? this.theme
            : theme as ZcrudTheme?,
        widgetRegistry: identical(widgetRegistry, _zScopeUndefined)
            ? this.widgetRegistry
            : widgetRegistry as ZWidgetRegistry?,
        subListSeamRegistry: identical(subListSeamRegistry, _zScopeUndefined)
            ? this.subListSeamRegistry
            : subListSeamRegistry as ZSubListSeamRegistry?,
        relationSourceRegistry:
            identical(relationSourceRegistry, _zScopeUndefined)
                ? this.relationSourceRegistry
                : relationSourceRegistry as ZRelationSourceRegistry?,
        choicesSourceRegistry:
            identical(choicesSourceRegistry, _zScopeUndefined)
                ? this.choicesSourceRegistry
                : choicesSourceRegistry as ZChoicesSourceRegistry?,
        relationCrudRegistry: identical(relationCrudRegistry, _zScopeUndefined)
            ? this.relationCrudRegistry
            : relationCrudRegistry as ZRelationCrudRegistry?,
        filePicker: identical(filePicker, _zScopeUndefined)
            ? this.filePicker
            : filePicker as ZFilePicker?,
        cloudStorage: identical(cloudStorage, _zScopeUndefined)
            ? this.cloudStorage
            : cloudStorage as CloudStorageRepository?,
        appFileResolver: identical(appFileResolver, _zScopeUndefined)
            ? this.appFileResolver
            : appFileResolver as ZAppFileResolver?,
        listRenderer: identical(listRenderer, _zScopeUndefined)
            ? this.listRenderer
            : listRenderer as ZListRenderer?,
        reorderRenderer: identical(reorderRenderer, _zScopeUndefined)
            ? this.reorderRenderer
            : reorderRenderer as ZReorderRenderer?,
        dropRegionRenderer: identical(dropRegionRenderer, _zScopeUndefined)
            ? this.dropRegionRenderer
            : dropRegionRenderer as ZDropRegionRenderer?,
        selectPresenter: identical(selectPresenter, _zScopeUndefined)
            ? this.selectPresenter
            : selectPresenter as ZSelectPresenter?,
        iconResolver: identical(iconResolver, _zScopeUndefined)
            ? this.iconResolver
            : iconResolver as ZAdornmentIconResolver?,
        colorPicker: identical(colorPicker, _zScopeUndefined)
            ? this.colorPicker
            : colorPicker as ZColorPicker?,
        colorKeyResolver: identical(colorKeyResolver, _zScopeUndefined)
            ? this.colorKeyResolver
            : colorKeyResolver as ZColorKeyResolver?,
        gradientResolver: identical(gradientResolver, _zScopeUndefined)
            ? this.gradientResolver
            : gradientResolver as ZGradientResolver?,
        richTextRenderer: identical(richTextRenderer, _zScopeUndefined)
            ? this.richTextRenderer
            : richTextRenderer as ZRichTextRenderer?,
        dateDisplayFormatter: identical(dateDisplayFormatter, _zScopeUndefined)
            ? this.dateDisplayFormatter
            : dateDisplayFormatter as ZDateDisplayFormatter?,
        child: child,
      );

  /// Dérive le scope **ambiant** en ne remplaçant que les seams nommés.
  ///
  /// Lit le [ZcrudScope] le plus proche via [maybeOf] — l'appelant devient
  /// donc **dépendant** du scope parent : si celui-ci change, le widget qui a
  /// appelé [derive] se reconstruit et le scope dérivé se recalcule. En
  /// l'absence de scope ambiant, la dérivation part du scope **zéro-config**
  /// (mêmes défauts que le constructeur).
  ///
  /// La sémantique des paramètres est celle de [copyWith] : un paramètre omis
  /// hérite, un `null` explicite remet un seam nullable à son repli par
  /// défaut.
  ///
  /// C'est la forme recommandée pour poser une surcharge **par écran** —
  /// typiquement une ACL propre à la ressource affichée :
  ///
  /// ```dart
  /// ZcrudScope.derive(
  ///   context,
  ///   acl: aclDeCetEcran,
  ///   child: monEcran,
  /// )
  /// ```
  static ZcrudScope derive(
    BuildContext context, {
    required Widget child,
    Key? key,
    ZDependencyResolver? resolver,
    ZAcl? acl,
    Object? labels = _zScopeUndefined,
    Object? theme = _zScopeUndefined,
    Object? widgetRegistry = _zScopeUndefined,
    Object? subListSeamRegistry = _zScopeUndefined,
    Object? relationSourceRegistry = _zScopeUndefined,
    Object? choicesSourceRegistry = _zScopeUndefined,
    Object? relationCrudRegistry = _zScopeUndefined,
    Object? filePicker = _zScopeUndefined,
    Object? cloudStorage = _zScopeUndefined,
    Object? appFileResolver = _zScopeUndefined,
    Object? listRenderer = _zScopeUndefined,
    Object? reorderRenderer = _zScopeUndefined,
    Object? dropRegionRenderer = _zScopeUndefined,
    Object? selectPresenter = _zScopeUndefined,
    Object? iconResolver = _zScopeUndefined,
    Object? colorPicker = _zScopeUndefined,
    Object? colorKeyResolver = _zScopeUndefined,
    Object? gradientResolver = _zScopeUndefined,
    Object? richTextRenderer = _zScopeUndefined,
    Object? dateDisplayFormatter = _zScopeUndefined,
  }) {
    final ZcrudScope base = maybeOf(context) ?? ZcrudScope(child: child);
    return base.copyWith(
      key: key,
      resolver: resolver,
      acl: acl,
      labels: labels,
      theme: theme,
      widgetRegistry: widgetRegistry,
      subListSeamRegistry: subListSeamRegistry,
      relationSourceRegistry: relationSourceRegistry,
      choicesSourceRegistry: choicesSourceRegistry,
      relationCrudRegistry: relationCrudRegistry,
      filePicker: filePicker,
      cloudStorage: cloudStorage,
      appFileResolver: appFileResolver,
      listRenderer: listRenderer,
      reorderRenderer: reorderRenderer,
      dropRegionRenderer: dropRegionRenderer,
      selectPresenter: selectPresenter,
      iconResolver: iconResolver,
      colorPicker: colorPicker,
      colorKeyResolver: colorKeyResolver,
      gradientResolver: gradientResolver,
      richTextRenderer: richTextRenderer,
      dateDisplayFormatter: dateDisplayFormatter,
      child: child,
    );
  }

  /// Retourne le [ZcrudScope] le plus proche.
  ///
  /// Lève [ZScopeError] (message actionnable) si aucun scope n'est présent dans
  /// l'arbre — utilisez [maybeOf] pour une résolution tolérante.
  static ZcrudScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw ZScopeError(
        'Aucun ZcrudScope dans l\'arbre. Enveloppez votre application dans '
        'ZcrudScope(child: ...) ou un binding (E2-9) avant d\'utiliser les '
        'seams du cœur.',
      );
    }
    return scope;
  }

  /// Retourne le [ZcrudScope] le plus proche, ou `null` s'il n'y en a pas.
  static ZcrudScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZcrudScope>();

  @override
  bool updateShouldNotify(ZcrudScope oldWidget) =>
      !identical(resolver, oldWidget.resolver) ||
      !identical(acl, oldWidget.acl) ||
      !identical(labels, oldWidget.labels) ||
      !identical(theme, oldWidget.theme) ||
      !identical(widgetRegistry, oldWidget.widgetRegistry) ||
      !identical(subListSeamRegistry, oldWidget.subListSeamRegistry) ||
      !identical(relationSourceRegistry, oldWidget.relationSourceRegistry) ||
      !identical(choicesSourceRegistry, oldWidget.choicesSourceRegistry) ||
      !identical(relationCrudRegistry, oldWidget.relationCrudRegistry) ||
      !identical(filePicker, oldWidget.filePicker) ||
      !identical(cloudStorage, oldWidget.cloudStorage) ||
      !identical(appFileResolver, oldWidget.appFileResolver) ||
      !identical(listRenderer, oldWidget.listRenderer) ||
      !identical(reorderRenderer, oldWidget.reorderRenderer) ||
      !identical(dropRegionRenderer, oldWidget.dropRegionRenderer) ||
      !identical(selectPresenter, oldWidget.selectPresenter) ||
      !identical(iconResolver, oldWidget.iconResolver) ||
      !identical(colorPicker, oldWidget.colorPicker) ||
      !identical(colorKeyResolver, oldWidget.colorKeyResolver) ||
      !identical(gradientResolver, oldWidget.gradientResolver) ||
      // Chaque seam DOIT participer à cette comparaison : un seam déclaré,
      // propagé et consommé mais absent d'ici laisserait un hôte qui le change
      // à chaud sans AUCUN dépendant qui se reconstruit — défaut silencieux,
      // rien ne lève, le rendu reste simplement périmé (couvert par
      // `z_scope_notify_parity_test.dart`).
      !identical(richTextRenderer, oldWidget.richTextRenderer) ||
      !identical(dateDisplayFormatter, oldWidget.dateDisplayFormatter);
}
