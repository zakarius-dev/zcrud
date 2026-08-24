/// `ZcrudLocalizations` + `ZcrudLocalizationsDelegate` — l10n GÉNÉRIQUE du chrome
/// CRUD (AD-13).
///
/// Delegate custom **sans aucune ressource métier** — il ne connaît
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
  'restore': 'Restore',
  'edit': 'Edit',
  // CRUD inline sur relation (créer une entité liée). `copy`/`edit`
  // réutilisés (déjà présents).
  'create': 'Create',
  'history': 'History',
  'date': 'Date',
  'operation': 'Operation',
  'author': 'Author',
  'update': 'Update',
  'view': 'View',
  'add': 'Add',
  'confirm': 'Confirm',
  'search': 'Search',
  'required': 'This field is required',
  'invalidValue': 'Invalid value',
  // Message générique de politique mot de passe (repli défensif).
  'invalidPassword': 'Invalid password',
  'loading': 'Loading…',
  'empty': 'Nothing to display',
  'retry': 'Retry',
  // Liste — états UI accessibles et DISTINCTS (`empty` ≠ `noResults`).
  'list.loading': 'Loading the list…',
  'list.empty': 'No data yet',
  'list.noResults': 'No results match your filters',
  'list.error': 'Failed to load the list',
  'yes': 'Yes',
  'no': 'No',
  // Bascule afficher/masquer de la famille mot de passe (œil).
  'showPassword': 'Show password',
  'hidePassword': 'Hide password',
  'select': 'Select',
  'selectDate': 'Select a date',
  'selectTime': 'Select a time',
  'selectDateTime': 'Select a date and time',
  'selectDateRange': 'Select a date range',
  // Refus d'AMPLITUDE d'une plage de dates : les deux entames de phrase sont
  // suivies du nombre autorisé, puis de `daysInclusive` — « The period must not
  // exceed 7 days (both bounds included) ». L'unité porte le comptage : le
  // nombre annoncé est celui des JOURS COUVERTS, jamais celui des intervalles.
  'dateRangeTooLong': 'The period must not exceed',
  'dateRangeTooShort': 'The period must cover at least',
  'daysInclusive': 'days (both bounds included)',
  'close': 'Close',
  'back': 'Back',
  'reset': 'Reset',
  // Croix d'effacement (date non requise).
  'clear': 'Clear',
  'remove': 'Remove',
  'next': 'Next',
  'previous': 'Previous',
  'unsupportedField': 'Unsupported field type here',
  'addTag': 'Add tag',
  'removeTag': 'Remove tag',
  'selectColor': 'Select a color',
  // Picker couleur enrichi (built-in neutre).
  'customColor': 'Custom color…',
  'colorHue': 'Hue',
  'colorSaturation': 'Saturation',
  'colorBrightness': 'Brightness',
  'colorOpacity': 'Opacity',
  'colorHex': 'Hex code',
  'colorRecent': 'Recent',
  // Mode couleur multiple (List<int> ARGB).
  'colorAddColor': 'Add a color',
  'removeColor': 'Remove color',
  'apply': 'Apply',
  // Suffixes numériques NEUTRES (données, jamais un style codé en dur).
  'percentSuffix': '%',
  'currencySuffix': r'$',
  'rate': 'Rating',
  'addItem': 'Add item',
  'removeItem': 'Remove item',
  'moveItemUp': 'Move item up',
  'moveItemDown': 'Move item down',
  'clearItem': 'Clear item',
  // Sous-liste compacte + dialog d'édition par item.
  'viewItem': 'View item',
  'editItem': 'Edit item',
  'deleteItem': 'Delete item',
  'confirmDeleteItem': 'Delete this item?',
  'noItems': 'No items',
  // Soft-delete/restore d'un item de sous-liste.
  'restoreItem': 'Restore item',
  'deletedItemBadge': '(deleted)',
  'signatureArea': 'Signature area',
  'signatureSigned': 'Signed',
  'signatureEmpty': 'Empty',
  'clearSignature': 'Clear signature',
  'undoSignature': 'Undo last stroke',
  'fileActionScan': 'Scan a document',
  'fileActionCamera': 'Take a photo',
  'fileActionGallery': 'Pick from gallery',
  'fileActionPick': 'Pick a file',
  'fileRemove': 'Remove file',
  'fileRetry': 'Retry upload',
  'fileUploading': 'Uploading…',
  'fileUploadFailed': 'Upload failed',
  'filePreviewAlt': 'File preview',
  'fileMaxReached':
      'Maximum number of files reached; extra files were not added',
  // Résolution des RÉFÉRENCES opaques de fichiers (port `ZAppFileResolver`) :
  // états VISIBLES d'une référence non encore résolue (AD-10).
  'fileResolving': 'Loading file…',
  'fileRefUnresolved': 'File unavailable',
  'fileResolveFailed': 'Could not load file',
  'fileResolveRetry': 'Retry loading',
  // Fiche de lecture (copie presse-papier + placeholder valeur vide).
  'copy': 'Copy',
  'copied': 'Value copied to clipboard',
  'emptyValue': '—',
  // Assistant multi-étapes (`ZStepperEdition`) — navigation entre étapes.
  'z.stepper.previous': 'Previous',
  'z.stepper.next': 'Next',
  'z.stepper.finish': 'Finish',
  // Corbeille : bascule vivants ⇄ éléments mis à la corbeille.
  'trash': 'Trash',
  // Annonce du COMPTEUR de corbeille, lue par les lecteurs d'écran à la suite
  // du nombre (« 3 items in trash ») : la pastille ne doit jamais être un
  // nombre nu, dont l'objet resterait à deviner.
  'trashCount': 'items in trash',
  // Fiche de DÉTAIL : le formulaire entier ouvert en consultation (distinct de
  // `edit`, qui annonce une modification, et de `viewItem`, qui désigne un
  // élément de sous-liste).
  'details': 'Details',
  // Troisième geste de la corbeille : suppression DÉFINITIVE. Libellé et
  // question distincts de `delete`/`confirmDeleteItem` — la mise à la corbeille
  // se défait, celle-ci non, et le texte doit le dire.
  'deleteForever': 'Delete permanently',
  'confirmDeleteForeverItem':
      'Delete this item permanently? This cannot be undone.',
  // Refus d'accès : l'ACL de l'application interdit la consultation.
  'accessDenied': 'Access denied',
  'accessDeniedMessage':
      'You are not allowed to view this content. Contact an administrator if '
      'you think this is a mistake.',
  // Valeur SÉLECTIONNÉE mais absente des options du moment (cascade).
  // Même règle que `fileRefUnresolved` : une identité non résolue se montre par
  // un libellé, JAMAIS par sa clé technique. La valeur, elle, est conservée.
  'choiceUnresolved': 'Option unavailable',
  // Actions de LIGNE présentées en menu : nom accessible du déclencheur de
  // débordement, et motif annoncé quand l'ACL refuse l'action mais que
  // l'application a choisi de la montrer inerte plutôt que de la masquer.
  'moreActions': 'More actions',
  'actionNotAllowed': 'You are not allowed to do this',
  // Motif générique d'une action montrée INERTE non pas faute de droit, mais
  // parce qu'elle ne s'applique pas à cette ligne-là (restaurer un élément
  // vivant, valider une pièce déjà validée).
  'actionNotApplicable': 'This action does not apply to this item',
  // Export du listing : entrée d'action, et les deux issues qu'un utilisateur
  // doit pouvoir distinguer — rien à exporter (la liste affichée est vide) et
  // export en échec (le format n'a pas pu produire son fichier).
  'export': 'Export',
  'exportEmpty': 'Nothing to export',
  'exportFailed': 'Export failed',
  // Sélection multiple : compteur d'éléments cochés et bouton « tout
  // sélectionner » de la barre d'actions de masse. Le compteur suit un nombre
  // (« 3 selected ») — le mot seul, jamais la phrase.
  'selectedCount': 'selected',
  'selectAll': 'Select all',
  // Compte rendu d'une action de masse : chaque terme suit son nombre
  // (« 7 succeeded · 2 failed · 1 skipped »). « Skipped » désigne les éléments
  // que la gouvernance a écartés du lot avant toute écriture.
  'batchSucceeded': 'succeeded',
  'batchFailed': 'failed',
  'batchSkipped': 'skipped',
};

const _frLabels = <String, String>{
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'delete': 'Supprimer',
  'restore': 'Restaurer',
  'edit': 'Modifier',
  // CRUD inline sur relation (créer une entité liée).
  'create': 'Créer',
  'history': 'Historique',
  'date': 'Date',
  'operation': 'Opération',
  'author': 'Auteur',
  'update': 'Modifier',
  'view': 'Consulter',
  'add': 'Ajouter',
  'confirm': 'Confirmer',
  'search': 'Rechercher',
  'required': 'Ce champ est requis',
  'invalidValue': 'Valeur invalide',
  // Message générique de politique mot de passe (repli défensif).
  'invalidPassword': 'Mot de passe invalide',
  'loading': 'Chargement…',
  'empty': 'Aucun élément à afficher',
  'retry': 'Réessayer',
  // Liste — états UI accessibles et DISTINCTS (`empty` ≠ `noResults`).
  'list.loading': 'Chargement de la liste…',
  'list.empty': 'Aucune donnée pour le moment',
  'list.noResults': 'Aucun résultat ne correspond à vos filtres',
  'list.error': 'Échec du chargement de la liste',
  'yes': 'Oui',
  'no': 'Non',
  // Bascule afficher/masquer de la famille mot de passe (œil).
  'showPassword': 'Afficher le mot de passe',
  'hidePassword': 'Masquer le mot de passe',
  'select': 'Sélectionner',
  'selectDate': 'Sélectionner une date',
  'selectTime': 'Sélectionner une heure',
  'selectDateTime': 'Sélectionner une date et une heure',
  'selectDateRange': 'Sélectionner une période',
  // Cf. commentaire de la table `en` — « La période ne doit pas dépasser 7
  // jours (bornes incluses) ».
  'dateRangeTooLong': 'La période ne doit pas dépasser',
  'dateRangeTooShort': 'La période doit couvrir au moins',
  'daysInclusive': 'jours (bornes incluses)',
  'close': 'Fermer',
  'back': 'Retour',
  'reset': 'Réinitialiser',
  // Croix d'effacement (date non requise).
  'clear': 'Effacer',
  'remove': 'Retirer',
  'next': 'Suivant',
  'previous': 'Précédent',
  'unsupportedField': 'Type de champ non pris en charge ici',
  'addTag': 'Ajouter une étiquette',
  'removeTag': 'Retirer l\'étiquette',
  'selectColor': 'Sélectionner une couleur',
  // Picker couleur enrichi (built-in neutre).
  'customColor': 'Couleur personnalisée…',
  'colorHue': 'Teinte',
  'colorSaturation': 'Saturation',
  'colorBrightness': 'Luminosité',
  'colorOpacity': 'Opacité',
  'colorHex': 'Code hexadécimal',
  'colorRecent': 'Récentes',
  // Mode couleur multiple (List<int> ARGB).
  'colorAddColor': 'Ajouter une couleur',
  'removeColor': 'Retirer la couleur',
  'apply': 'Appliquer',
  // Suffixes numériques NEUTRES (données, jamais un style codé en dur).
  'percentSuffix': '%',
  'currencySuffix': r'$',
  'rate': 'Note',
  'addItem': 'Ajouter un élément',
  'removeItem': 'Retirer l\'élément',
  'moveItemUp': 'Monter l\'élément',
  'moveItemDown': 'Descendre l\'élément',
  'clearItem': 'Effacer l\'élément',
  // Sous-liste compacte + dialog d'édition par item.
  'viewItem': 'Consulter l\'élément',
  'editItem': 'Modifier l\'élément',
  'deleteItem': 'Supprimer l\'élément',
  'confirmDeleteItem': 'Supprimer cet élément ?',
  'noItems': 'Aucun élément',
  // Soft-delete/restore d'un item de sous-liste.
  'restoreItem': 'Restaurer l\'élément',
  'deletedItemBadge': '(supprimé)',
  'signatureArea': 'Zone de signature',
  'signatureSigned': 'Signé',
  'signatureEmpty': 'Vide',
  'clearSignature': 'Effacer la signature',
  'undoSignature': 'Annuler le dernier trait',
  'fileActionScan': 'Numériser un document',
  'fileActionCamera': 'Prendre une photo',
  'fileActionGallery': 'Choisir dans la galerie',
  'fileActionPick': 'Choisir un fichier',
  'fileRemove': 'Retirer le fichier',
  'fileRetry': 'Réessayer l\'envoi',
  'fileUploading': 'Envoi en cours…',
  'fileUploadFailed': 'Échec de l\'envoi',
  'filePreviewAlt': 'Aperçu du fichier',
  'fileMaxReached':
      'Nombre maximal de fichiers atteint ; les fichiers en trop n\'ont pas été ajoutés',
  'fileResolving': 'Chargement du fichier…',
  'fileRefUnresolved': 'Fichier indisponible',
  'fileResolveFailed': 'Échec du chargement du fichier',
  'fileResolveRetry': 'Réessayer le chargement',
  // Fiche de lecture (copie presse-papier + placeholder valeur vide).
  'copy': 'Copier',
  'copied': 'Valeur copiée dans le presse-papier',
  'emptyValue': '—',
  // Assistant multi-étapes (`ZStepperEdition`) — navigation entre étapes.
  'z.stepper.previous': 'Précédent',
  'z.stepper.next': 'Suivant',
  'z.stepper.finish': 'Terminer',
  // Corbeille : bascule vivants ⇄ éléments mis à la corbeille.
  'trash': 'Corbeille',
  // Cf. commentaire de la table `en`.
  'trashCount': 'éléments dans la corbeille',
  // Cf. commentaire de la table `en`.
  'details': 'Détails',
  // Cf. commentaire de la table `en`.
  'deleteForever': 'Supprimer définitivement',
  'confirmDeleteForeverItem':
      'Supprimer définitivement cet élément ? Cette action est irréversible.',
  // Refus d'accès : l'ACL de l'application interdit la consultation.
  'accessDenied': 'Accès refusé',
  'accessDeniedMessage':
      'Vous n\'êtes pas autorisé à consulter ce contenu. Contactez un '
      'administrateur si vous pensez qu\'il s\'agit d\'une erreur.',
  // Cf. commentaire de la table `en`.
  'choiceUnresolved': 'Option indisponible',
  // Cf. commentaires de la table `en`.
  'moreActions': 'Plus d\'actions',
  'actionNotAllowed': 'Vous n\'êtes pas autorisé à effectuer cette action',
  // Cf. commentaire de la table `en`.
  'actionNotApplicable': 'Cette action ne s\'applique pas à cet élément',
  // Cf. commentaires de la table `en`.
  'export': 'Exporter',
  'exportEmpty': 'Rien à exporter',
  'exportFailed': 'L\'export a échoué',
  // Cf. commentaires de la table `en`.
  'selectedCount': 'sélectionné(s)',
  'selectAll': 'Tout sélectionner',
  // Cf. commentaires de la table `en`.
  'batchSucceeded': 'réussi(s)',
  'batchFailed': 'en échec',
  'batchSkipped': 'écarté(s)',
};

/// Tables de libellés génériques par `languageCode` (baseline `en`/`fr`).
const _tables = <String, Map<String, String>>{'en': _enLabels, 'fr': _frLabels};

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
  /// livrées (valeurs en/fr) plutôt qu'une liste de clés dupliquée.
  Iterable<String> get keys => _labels.keys;

  /// Retourne le libellé générique de [key] ; à défaut la clé elle-même (jamais
  /// de throw sur clé absente).
  String resolve(String key) => _labels[key] ?? key;

  /// Les localisations les plus proches, ou `null` si le delegate n'est pas
  /// monté (`MaterialApp.localizationsDelegates`).
  static ZcrudLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<ZcrudLocalizations>(context, ZcrudLocalizations);

  /// Les localisations les plus proches. Retombe sur la table `en` intégrée si
  /// le delegate n'est pas monté — garantit un rendu sans crash.
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

/// Résout le libellé de [key] par **composition** (AD-13) :
///   `ZcrudScope.labels?.maybeResolve` → `ZcrudLocalizations` (delegate) →
///   **table `en` de repli** → [fallback] ?? [key].
///
/// Ordre : la surcharge/lib métier du scope l'emporte sur le défaut générique
/// locale-aware (delegate), qui l'emporte sur le repli `en` intégré, qui
/// l'emporte sur la clé brute. **Jamais de throw** sur clé absente. [fallback]
/// remplace la clé brute en dernier recours.
///
/// `label()` honore le **même repli `en`** que
/// `ZcrudLocalizations.of` — sans delegate monté, une clé générique connue rend
/// son libellé `en` (`'save' → 'Save'`) au lieu de la clé brute. On passe par
/// `ZcrudLocalizations.of` (qui retombe sur la table `en` si le delegate n'est
/// pas monté) puis, si le delegate est monté mais la clé absente de sa locale,
/// on retente explicitement la table `en` de repli avant [fallback]/[key].
///
/// Décision de forme : **fonction top-level** `label(...)`
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
