/// `ZcrudLocalizations` + `ZcrudLocalizationsDelegate` — l10n GÉNÉRIQUE du chrome
/// CRUD (FR-23, AD-13).
///
/// origine : delegate custom **sans aucune ressource métier** — il ne connaît
/// que des libellés d'UI CRUD (verbes/états : enregistrer/annuler/supprimer,
/// requis/valeur invalide, chargement/vide/réessayer…). Les libellés **métier**
/// (noms d'entités applicatives) sont du ressort de `ZcrudLabels`, injecté par
/// l'app via `ZcrudScope(labels:)`.
///
/// `Localizations`/`LocalizationsDelegate`/`Locale` vivent dans
/// `package:flutter/widgets.dart` : **`flutter_localizations` n'est PAS requis**
/// (delegate générique). Ne PAS l'ajouter (tirerait GlobalMaterialLocalizations
/// inutilement).
library;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import '../zcrud_scope.dart';

/// Convention de clés : **actions/états d'UI CRUD** en camelCase, jamais de
/// terme métier. Étendre = ajouter une clé générique ici (delegate) OU un
/// libellé applicatif via `ZcrudLabels` (scope).
const _enLabels = <String, String>{
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'edit': 'Edit',
  'add': 'Add',
  'confirm': 'Confirm',
  'search': 'Search',
  'required': 'This field is required',
  'invalidValue': 'Invalid value',
  'loading': 'Loading…',
  'empty': 'Nothing to display',
  'retry': 'Retry',
  'yes': 'Yes',
  'no': 'No',
  'select': 'Select',
  'selectDate': 'Select a date',
  'close': 'Close',
  'reset': 'Reset',
  'remove': 'Remove',
  'next': 'Next',
  'previous': 'Previous',
};

const _frLabels = <String, String>{
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'delete': 'Supprimer',
  'edit': 'Modifier',
  'add': 'Ajouter',
  'confirm': 'Confirmer',
  'search': 'Rechercher',
  'required': 'Ce champ est requis',
  'invalidValue': 'Valeur invalide',
  'loading': 'Chargement…',
  'empty': 'Aucun élément à afficher',
  'retry': 'Réessayer',
  'yes': 'Oui',
  'no': 'Non',
  'select': 'Sélectionner',
  'selectDate': 'Sélectionner une date',
  'close': 'Fermer',
  'reset': 'Réinitialiser',
  'remove': 'Retirer',
  'next': 'Suivant',
  'previous': 'Précédent',
};

/// Tables de libellés génériques par `languageCode` (baseline `en`/`fr`).
const _tables = <String, Map<String, String>>{
  'en': _enLabels,
  'fr': _frLabels,
};

/// Porteur immuable des **libellés génériques** d'une locale (aucun terme
/// métier). Résolution locale-aware ; les surcharges/libellés métier passent
/// par `ZcrudLabels` (scope).
@immutable
class ZcrudLocalizations {
  /// Construit les localisations pour [locale] avec la table [_labels].
  const ZcrudLocalizations(this.locale, this._labels);

  /// Locale résolue par le delegate.
  final Locale locale;

  final Map<String, String> _labels;

  /// Retourne le libellé générique de [key], ou `null` si absent.
  String? maybeResolve(String key) => _labels[key];

  /// Clés effectivement livrées pour cette locale (table réelle du delegate).
  ///
  /// Exposé pour permettre aux gardes/sentinelles d'itérer les entrées réelles
  /// livrées (valeurs en/fr) plutôt qu'une liste de clés dupliquée (L-4).
  Iterable<String> get keys => _labels.keys;

  /// Retourne le libellé générique de [key] ; à défaut la clé elle-même (jamais
  /// de throw sur clé absente).
  String resolve(String key) => _labels[key] ?? key;

  /// Les localisations les plus proches, ou `null` si le delegate n'est pas
  /// monté (`MaterialApp.localizationsDelegates`).
  static ZcrudLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<ZcrudLocalizations>(context, ZcrudLocalizations);

  /// Les localisations les plus proches. Retombe sur la table `en` intégrée si
  /// le delegate n'est pas monté — garantit un rendu sans crash (FR-23).
  static ZcrudLocalizations of(BuildContext context) =>
      maybeOf(context) ?? const ZcrudLocalizations(Locale('en'), _enLabels);
}

/// Delegate l10n **générique** : n'énumère AUCUNE ressource métier.
class ZcrudLocalizationsDelegate
    extends LocalizationsDelegate<ZcrudLocalizations> {
  /// Delegate `const` à monter dans `MaterialApp.localizationsDelegates`.
  const ZcrudLocalizationsDelegate();

  /// Locales pour lesquelles une table générique intégrée existe.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  @override
  bool isSupported(Locale locale) => _tables.containsKey(locale.languageCode);

  @override
  Future<ZcrudLocalizations> load(Locale locale) => SynchronousFuture(
        ZcrudLocalizations(locale, _tables[locale.languageCode] ?? _enLabels),
      );

  @override
  bool shouldReload(ZcrudLocalizationsDelegate old) => false;
}

/// Résout le libellé de [key] par **composition** (FR-23, AD-13) :
///   `ZcrudScope.labels?.maybeResolve` → `ZcrudLocalizations` (delegate) →
///   **table `en` de repli** → [fallback] ?? [key].
///
/// Ordre : la surcharge/lib métier du scope l'emporte sur le défaut générique
/// locale-aware (delegate), qui l'emporte sur le repli `en` intégré, qui
/// l'emporte sur la clé brute. **Jamais de throw** sur clé absente. [fallback]
/// remplace la clé brute en dernier recours.
///
/// Corrige L-1 : `label()` honore désormais le **même repli `en`** que
/// `ZcrudLocalizations.of` — sans delegate monté, une clé générique connue rend
/// son libellé `en` (`'save' → 'Save'`) au lieu de la clé brute. On passe par
/// `ZcrudLocalizations.of` (qui retombe sur la table `en` si le delegate n'est
/// pas monté) puis, si le delegate est monté mais la clé absente de sa locale,
/// on retente explicitement la table `en` de repli avant [fallback]/[key].
///
/// Décision de forme (ambiguïté story #3) : **fonction top-level** `label(...)`
/// (plutôt qu'une extension sur `BuildContext` — évite de polluer l'espace des
/// méthodes de `BuildContext` et reste explicitement importable via le barrel).
String label(BuildContext context, String key, {String? fallback}) {
  final fromScope = ZcrudScope.maybeOf(context)?.labels?.maybeResolve(key);
  if (fromScope != null) return fromScope;
  final fromLocale = ZcrudLocalizations.of(context).maybeResolve(key);
  if (fromLocale != null) return fromLocale;
  final fromEn = _enLabels[key];
  if (fromEn != null) return fromEn;
  return fallback ?? key;
}
