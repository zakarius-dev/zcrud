/// `ZcrudScope` — point d'injection des **seams** du cœur (AD-6, AD-15).
///
/// origine: `InheritedWidget` zéro-dépendance qui porte le bundle immuable de
/// seams résolus et les expose aux widgets du moteur d'édition, SANS imposer un
/// gestionnaire d'état. Un binding (E2-9) peut fournir un scope enrichi ; le
/// chemin par défaut reste utilisable sans aucun manager (preuve du chemin
/// « zéro-dépendance » d'AD-15).
library;

import 'package:flutter/widgets.dart';

import '../domain/ports/cloud_storage_repository.dart';
import '../domain/ports/z_acl.dart';
import '../domain/ports/z_choices_source.dart';
import '../domain/ports/z_relation_crud.dart';
import '../domain/ports/z_relation_source.dart';
import 'edition/families/z_color_field_widget.dart';
import 'edition/z_field_adornment_view.dart';
import 'edition/z_file_picker.dart';
import 'edition/z_select_presenter.dart';
import 'edition/z_widget_registry.dart';
import 'l10n/z_labels.dart';
import 'list/z_list_renderer.dart';
import 'theme/z_color_key_resolver.dart';
import 'theme/z_theme.dart';
import 'z_dependency_resolver.dart';
import 'z_scope_error.dart';

/// Scope d'injection Flutter-natif du cœur `zcrud_core`.
///
/// Porte un **bundle immuable de seams** résolus :
/// - [resolver] : seam de résolution de dépendances applicatives (défaut :
///   [ZDependencyResolver.throwing]) — inclut, côté binding, le **seam de cycle
///   de vie** du `ZFormController` (défaut zéro-config : cycle local possédé par
///   l'hôte) ;
/// - [acl] : port d'autorisation (E2-2 ; défaut sûr [ZAllowAllAcl]) ;
/// - [labels] : registre de libellés surchargeables (E2-8 ; défaut `null` →
///   résolution retombe sur `ZcrudLocalizations`) ;
/// - [theme] : design-tokens injectés (E2-8 ; défaut `null` → `ZcrudTheme.of`
///   retombe sur `Theme.of(context)`) ;
/// - [widgetRegistry] : registre de widgets d'édition servis **ailleurs** (E3-3b,
///   AD-4 ; défaut `null` → tout type `registryOrFallback` retombe sur le repli
///   `ZUnsupportedFieldWidget`). Instanciable, jamais un singleton statique.
///
/// Résolution via [of] / [maybeOf]. Le constructeur par défaut (zéro-config) est
/// utilisable sans fournir de manager : il expose un [ZAllowAllAcl] et un
/// resolver throwing, `labels`/`theme` à `null` — les dépendances applicatives
/// DOIVENT être fournies explicitement (« seams throw par défaut », AD-6).
class ZcrudScope extends InheritedWidget {
  /// Construit le scope. Zéro-config par défaut : [resolver] throwing + [acl]
  /// permissive + [labels]/[theme] `null`. Un binding/app fournit des seams
  /// concrets en les passant ici.
  const ZcrudScope({
    required super.child,
    this.resolver = ZDependencyResolver.throwing,
    this.acl = const ZAllowAllAcl(),
    this.labels,
    this.theme,
    this.widgetRegistry,
    this.relationSourceRegistry,
    this.choicesSourceRegistry,
    this.relationCrudRegistry,
    this.filePicker,
    this.cloudStorage,
    this.listRenderer,
    this.selectPresenter,
    this.iconResolver,
    this.colorPicker,
    this.colorKeyResolver,
    super.key,
  });

  /// Seam de résolution des dépendances applicatives (défaut : throwing).
  final ZDependencyResolver resolver;

  /// Port d'autorisation (défaut : permissif [ZAllowAllAcl]).
  final ZAcl acl;

  /// Registre de libellés surchargeables (E2-8, FR-23 ; défaut `null`).
  final ZcrudLabels? labels;

  /// Design-tokens injectés (E2-8, FR-26 ; défaut `null` → repli `Theme.of`).
  final ZcrudTheme? theme;

  /// Registre de widgets d'édition servis **ailleurs** (E3-3b, AD-4 ; défaut
  /// `null` → repli `ZUnsupportedFieldWidget`). Instanciable, injecté (jamais
  /// un singleton statique mutable).
  final ZWidgetRegistry? widgetRegistry;

  /// Registre de sources dynamiques du champ `relation` (DP-5, gap B7, AD-4 ;
  /// défaut `null` → tout champ `relation` retombe sur le **dropdown statique**
  /// sur `choices` — repli universel rétro-compatible). Instanciable, injecté
  /// (jamais un singleton statique mutable). L'impl concrète de `ZRelationSource`
  /// (flux repository Firestore/Hive + mapping entité→`ZFieldChoice` + filtre
  /// métier) vit hors du cœur (`zcrud_firestore`/app E7), jamais ici (AD-1).
  final ZRelationSourceRegistry? relationSourceRegistry;

  /// Registre de sources d'options **calculées** du champ `select` (DP-15/M22,
  /// AD-4 ; défaut `null` → tout `select` retombe sur `choicesFromKey` puis sur
  /// le **dropdown statique** sur `choices` — repli universel rétro-compatible).
  /// Instanciable, injecté (jamais un singleton statique mutable). L'impl concrète
  /// de `ZChoicesSource` (calcul métier des options depuis l'état) vit hors du
  /// cœur (binding/app E7), jamais ici (AD-1).
  final ZChoicesSourceRegistry? choicesSourceRegistry;

  /// Registre de handlers **CRUD inline** du champ `relation` (DP-15/M8, AD-4 ;
  /// défaut `null` → aucun bouton créer/modifier/copier — modal DP-5 identique).
  /// Instanciable, injecté (jamais un singleton statique mutable). L'impl concrète
  /// de `ZRelationCrudHandler` (form d'édition + repository create/update/copy)
  /// vit hors du cœur (app DODLP E7/`zcrud_firestore`), jamais ici (AD-1).
  final ZRelationCrudRegistry? relationCrudRegistry;

  /// Seam d'acquisition de fichiers (E3-3c, AD-1/AD-6 ; défaut `null` → actions
  /// scan/caméra/galerie/picker désactivées proprement). Impl concrète
  /// (image_picker/file_picker) fournie par l'app/binding (E7), jamais le cœur.
  final ZFilePicker? filePicker;

  /// Port de stockage cloud (E3-3c, AD-1/AD-5/AD-6 ; défaut `null` → fichier
  /// reste `pending`, orchestration draft→cloud déférée à l'app/`onSubmit`).
  /// Impl concrète (Firebase Storage) fournie par `zcrud_firestore` (E5),
  /// jamais le cœur.
  final CloudStorageRepository? cloudStorage;

  /// Seam de rendu de liste (E4-1, AD-8/SM-5 ; défaut `null` → `DynamicList`
  /// lève une [ZScopeError] actionnable tant qu'aucun backend n'est injecté).
  /// `zcrud_core` ne fournit AUCUNE implémentation concrète : le rendu Syncfusion
  /// (`ZSfDataGridRenderer`) vit dans `zcrud_list` et est injecté par l'app/le
  /// binding (`ZcrudScope(listRenderer: const ZSfDataGridRenderer())`). Un
  /// backend Material `DataTable` reste implémentable sur le même port. Jamais
  /// un singleton statique mutable.
  final ZListRenderer? listRenderer;

  /// Seam de **présentation riche des familles de sélection** (AD-48 ; défaut
  /// `null` → rendu **natif** zcrud strictement conservé). Injecté par l'app/le
  /// binding pour brancher un présentateur riche (parité DODLP `awesome_select`)
  /// sur `select`/`radio`/`checkbox`/`relation`. `zcrud_core` ne fournit AUCUNE
  /// implémentation concrète : l'impl (adossée à `awesome_select`) vit dans
  /// `zcrud_select` (fp-4-1), jamais dans le cœur (AD-1). Le présentateur ne
  /// reçoit qu'un `ZSelectPresentation` neutre (jamais le `ZFormController` —
  /// AD-2). Jamais un singleton statique mutable.
  final ZSelectPresenter? selectPresenter;

  /// Résolveur d'**icône d'ornement** host-fourni (DP-12, M1 ; défaut `null` →
  /// le cœur retombe sur sa **table Material bornée** par défaut, puis `null` si
  /// la clé reste inconnue — AD-10). Traduit une **clé neutre** (`String`) de
  /// `ZFieldAdornment.icon(key)` en `IconData` **sans** que le domaine ne porte
  /// jamais d'`IconData` (AD-3/AD-14). Instanciable, injecté (jamais un singleton).
  final ZAdornmentIconResolver? iconResolver;

  /// DP-17 (M14) — **Seam de picker de couleur** host-fourni (roue HSV/hex/
  /// opacité tierce, ex. `flex_color_picker` ; défaut `null` → repli sur le
  /// **picker built-in NEUTRE** du cœur). Le cœur ne dépend d'AUCUN package de
  /// picker (AD-1) : l'impl concrète vit dans l'app/le binding. Instanciable,
  /// injecté (jamais un singleton statique mutable).
  final ZColorPicker? colorPicker;

  /// Résolveur de **couleur de clé de palette** host-fourni (ES-1.2, D1, AC3).
  ///
  /// Traduit une **clé neutre** (`String`, ex. `ZColorPalette.resolveKey`) en
  /// [ZColorPair] (fond + `on-` contrasté, AD-13) **sans** que le domaine
  /// (`zcrud_study_kernel`) ne porte jamais de `Color` (AD-1/AD-3/SM-S5).
  ///
  /// Ce champ est le **premier maillon** de la chaîne implémentée par
  /// [zResolveColorKey] / [zResolveColorKeyOrSlot] : seam hôte (ici) → repli du
  /// cœur dérivé du `ColorScheme` ([zDefaultColorKeyResolver], vocabulaire de
  /// rôles Material 3 uniquement) → slot déterministe ([zColorSlotPair]) ou
  /// `null` — jamais de throw (AD-10). C'est **ici** qu'une app injecte sa
  /// sémantique réelle (`success` en vert, `warning` en ambre… : Material 3 n'a
  /// pas ces rôles, le cœur ne les invente pas — FR-26/NFR-S7).
  ///
  /// Jumeau réel d'[iconResolver] (même nullabilité, même priorité, même ligne
  /// dans `updateShouldNotify`). Instanciable, injecté (jamais un singleton
  /// statique mutable).
  final ZColorKeyResolver? colorKeyResolver;

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
      !identical(relationSourceRegistry, oldWidget.relationSourceRegistry) ||
      !identical(choicesSourceRegistry, oldWidget.choicesSourceRegistry) ||
      !identical(relationCrudRegistry, oldWidget.relationCrudRegistry) ||
      !identical(filePicker, oldWidget.filePicker) ||
      !identical(cloudStorage, oldWidget.cloudStorage) ||
      !identical(listRenderer, oldWidget.listRenderer) ||
      !identical(selectPresenter, oldWidget.selectPresenter) ||
      !identical(iconResolver, oldWidget.iconResolver) ||
      !identical(colorPicker, oldWidget.colorPicker) ||
      !identical(colorKeyResolver, oldWidget.colorKeyResolver);
}
