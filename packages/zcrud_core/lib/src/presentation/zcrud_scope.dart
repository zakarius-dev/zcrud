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
import 'edition/z_file_picker.dart';
import 'edition/z_widget_registry.dart';
import 'l10n/z_labels.dart';
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
    this.filePicker,
    this.cloudStorage,
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

  /// Seam d'acquisition de fichiers (E3-3c, AD-1/AD-6 ; défaut `null` → actions
  /// scan/caméra/galerie/picker désactivées proprement). Impl concrète
  /// (image_picker/file_picker) fournie par l'app/binding (E7), jamais le cœur.
  final ZFilePicker? filePicker;

  /// Port de stockage cloud (E3-3c, AD-1/AD-5/AD-6 ; défaut `null` → fichier
  /// reste `pending`, orchestration draft→cloud déférée à l'app/`onSubmit`).
  /// Impl concrète (Firebase Storage) fournie par `zcrud_firestore` (E5),
  /// jamais le cœur.
  final CloudStorageRepository? cloudStorage;

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
      !identical(filePicker, oldWidget.filePicker) ||
      !identical(cloudStorage, oldWidget.cloudStorage);
}
