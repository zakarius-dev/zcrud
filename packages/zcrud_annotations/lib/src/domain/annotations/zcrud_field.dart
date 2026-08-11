import 'package:zcrud_core/edition.dart';

import 'z_persist_as.dart';

/// Annotation de **champ d'instance** déclarant la surface d'autorité d'un
/// champ du schéma `zcrud` : un même schéma pilote formulaire d'édition **et**
/// liste.
///
/// Le générateur `zcrud_generator` lit chaque paramètre **statiquement**
/// (`ConstantReader`) et le projette dans le `ZFieldSpec` correspondant (table
/// de correspondance ci-dessous). Classe `const` **pur-données** : tous champs
/// `final`, tous optionnels avec défaut sûr, **zéro closure**.
///
/// **Table de correspondance `@ZcrudField` → `ZFieldSpec`** :
/// | Paramètre | `ZFieldSpec` | Interprète |
/// |---|---|---|
/// | [name] (ou dérivé via `fieldRename`) | `name` (clé persistée) | générateur |
/// | [label] | `label` | résolution l10n |
/// | [type] (`null` ⇒ inféré) | `type` | rendu du widget / de la colonne |
/// | [validators] | `validators` | compose `FormBuilderValidators` |
/// | [config] | `config` | config par type |
/// | [choices] | `choices` | select/radio/checkbox |
/// | [condition] | `condition` (displayCondition) | visibilité conditionnelle (invariant AD-2) |
/// | [searchable] | `searchable` | filtre/recherche de la liste |
/// | [defaultValue] | `defaultValue` | défaut de `fromMap` |
/// | [readOnly] / [showIfNull] | idem | mode lecture |
/// | [multiple] | `multiple` | multi-sélection |
/// | [persistAs] | *(métadonnée neutre `Set<String>` séparée)* | `zcrud_firestore` (encode `Timestamp`) |
///
/// **Hint de persistance (`persistAs`)** : contrairement aux autres
/// paramètres, [persistAs] n'est **pas** projeté dans le `ZFieldSpec` mais dans
/// un artefact généré **neutre** (`const Set<String> $XxxTimestampFields`) — un
/// ensemble de clés persistées consommé par l'adaptateur Firestore pour encoder
/// ces champs en `Timestamp` natif (invariant AD-5 : `Timestamp` reste confiné
/// à `zcrud_firestore`).
///
/// **N'entre PAS dans l'annotation** (exige une closure/valeur runtime,
/// illisible par `ConstantReader`) — attaché au runtime à la place :
/// - builder `widget` libre → `EditionFieldType.widget` **nomme** le type ; la
///   closure est fournie via `ZTypeRegistry` / la config de champ ;
/// - `stateValidators` (dépendant de l'état) → `ZFormController` ;
/// - `displayCondition` dynamique dépendant du CRUD → remplacé par [ZCondition]
///   déclaratif ; cas irréductibles via surcouche runtime ;
/// - relation dynamique (`choiceItemsRepository`) → `EditionFieldType.relation`
///   nomme le type ; la source est câblée au runtime.
class ZcrudField {
  /// Construit l'annotation `const` avec des défauts sûrs.
  const ZcrudField({
    this.label,
    this.type,
    this.validators,
    this.config,
    this.choices,
    this.condition,
    this.searchable = false,
    this.defaultValue,
    this.readOnly = false,
    this.showIfNull = false,
    this.name,
    this.multiple = false,
    this.persistAs = ZPersistAs.iso8601,
    this.leading,
    this.prefix,
    this.suffix,
    this.hintText,
    this.helperText,
  });

  /// Libellé d'affichage (clé l10n ou littéral ; résolu côté UI en E3/E4).
  final String? label;

  /// Type de champ. `null` ⇒ le générateur **E2-5** l'infère du type statique
  /// Dart (`String`→`text`, `int`→`integer`, `bool`→`boolean`,
  /// `DateTime`→`dateTime`, `enum`→`select`, …). L'inférence est **implémentée
  /// en E2-5** (E2-4 ne fait que la documenter).
  final EditionFieldType? type;

  /// Validateurs **déclaratifs** (composés en `FormBuilderValidators` par E3).
  final List<ZValidatorSpec>? validators;

  /// Config spécialisée par type (base d'extension [ZFieldConfig]).
  final ZFieldConfig? config;

  /// Options statiques pour `select`/`radio`/`checkbox`.
  final List<ZFieldChoice>? choices;

  /// Visibilité conditionnelle **déclarative** (`displayCondition`) ; évaluée
  /// par E3 dans un sélecteur de visibilité dédié (AD-2). Jamais une closure.
  final ZCondition? condition;

  /// Participation à la recherche/filtre de la liste (E4).
  final bool searchable;

  /// Valeur par défaut si absente (appliquée par `fromMap`/E3).
  final Object? defaultValue;

  /// Champ non éditable (mode lecture — DODLP `readOnly`).
  final bool readOnly;

  /// En **mode lecture global**, afficher le champ même si sa valeur est
  /// vide/nulle.
  ///
  /// **Défaut `false`** : un champ vide est **masqué** en lecture, sauf
  /// `showIfNull: true` explicite. Sans effet hors mode lecture.
  final bool showIfNull;

  /// Override de la clé persistée. `null` ⇒ dérivée du nom Dart via
  /// `@ZcrudModel.fieldRename`.
  final String? name;

  /// Multi-sélection.
  final bool multiple;

  /// Hint de **format de persistance** d'un champ date (défaut
  /// [ZPersistAs.iso8601]). Avec [ZPersistAs.timestamp], le générateur collecte
  /// la clé persistée du champ dans l'artefact neutre `$XxxTimestampFields`
  /// (`Set<String>`) que `zcrud_firestore` consomme pour encoder le champ en
  /// `Timestamp` natif (invariant AD-5 préservé). Sans effet hors du chemin
  /// Firestore distant.
  final ZPersistAs persistAs;

  /// Ornement de **tête** du champ — projeté dans `ZFieldSpec.leading`.
  /// Pur-données ([ZFieldAdornment], `text`/`icon`/`widget` — jamais une
  /// closure/`IconData`, invariants AD-3/AD-14).
  final ZFieldAdornment? leading;

  /// Ornement **préfixe interne** du champ — projeté dans `ZFieldSpec.prefix`.
  final ZFieldAdornment? prefix;

  /// Ornement **suffixe interne** du champ — projeté dans `ZFieldSpec.suffix`.
  /// Le cas état-dépendant passe par `ZFieldAdornment.widget(kind)`.
  final ZFieldAdornment? suffix;

  /// Texte indicatif, projeté dans `ZFieldSpec.hintText`. Clé l10n ou littéral.
  final String? hintText;

  /// Texte d'aide, projeté dans `ZFieldSpec.helperText`. Clé l10n ou littéral.
  final String? helperText;
}
