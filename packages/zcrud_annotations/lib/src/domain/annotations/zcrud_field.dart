import 'package:zcrud_core/edition.dart';

import 'z_persist_as.dart';

/// Annotation de **champ d'instance** déclarant la surface d'autorité d'un
/// champ du schéma `zcrud` : un même schéma pilote formulaire (`DynamicEdition`,
/// E3) **et** liste (`DynamicList`, E4).
///
/// Le générateur E2-5 lit chaque paramètre **statiquement** (`ConstantReader`)
/// et le projette dans le `ZFieldSpec` correspondant (table de correspondance
/// ci-dessous). Classe `const` **pur-données** : tous champs `final`, tous
/// optionnels avec défaut sûr, **zéro closure** (AC1/AC3).
///
/// **Table de correspondance `@ZcrudField` → `ZFieldSpec` (émis en E2-5)** :
/// | Paramètre | `ZFieldSpec` | Interprète |
/// |---|---|---|
/// | [name] (ou dérivé via `fieldRename`) | `name` (clé persistée) | E2-5 |
/// | [label] | `label` | E3/E4 (résolution l10n) |
/// | [type] (`null` ⇒ inféré) | `type` | E3 (widget), E4 (colonne) |
/// | [validators] | `validators` | E3 compose → `FormBuilderValidators` |
/// | [config] | `config` | E3 (config par type) |
/// | [choices] | `choices` | E3 (select/radio/checkbox) |
/// | [condition] | `condition` (displayCondition) | E3 évalue (AD-2) |
/// | [searchable] | `searchable` | E4 (filtre/recherche) |
/// | [defaultValue] | `defaultValue` | E3/E2-5 (`fromMap` défaut) |
/// | [readOnly] / [showIfNull] | idem | E3 (mode lecture) |
/// | [multiple] | `multiple` | E3 (multi-select) |
/// | [persistAs] | *(métadonnée neutre `Set<String>` séparée)* | `zcrud_firestore` (encode `Timestamp`) |
///
/// **Hint de persistance (`persistAs`, gap B14)** : contrairement aux autres
/// paramètres, [persistAs] n'est **pas** projeté dans le `ZFieldSpec` mais dans
/// un artefact généré **neutre** (`const Set<String> $XxxTimestampFields`) — un
/// ensemble de clés persistées consommé par l'adaptateur Firestore pour encoder
/// ces champs en `Timestamp` natif (AD-5 : `Timestamp` reste confiné à
/// `zcrud_firestore`).
///
/// **N'entre PAS dans l'annotation** (exige une closure/valeur runtime,
/// illisible par `ConstantReader`) — **attaché au runtime** :
/// - builder `widget` libre → `EditionFieldType.widget` **nomme** le type ; la
///   closure est fournie via `ZTypeRegistry` / la config de champ (E3-3b) ;
/// - `stateValidators` (dépendant de l'état) → `ZFormController` (E3) ;
/// - `displayCondition` dynamique dépendant du CRUD → remplacé par [ZCondition]
///   déclaratif ; cas irréductibles via surcouche runtime (E3) ;
/// - relation dynamique (`choiceItemsRepository`) → `EditionFieldType.relation`
///   nomme le type ; la source est câblée au runtime (E4/ports E2-2).
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
    this.showIfNull = true,
    this.name,
    this.multiple = false,
    this.persistAs = ZPersistAs.iso8601,
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

  /// En mode lecture, afficher le champ même si la valeur est `null`
  /// (DODLP `showIfNull`).
  final bool showIfNull;

  /// Override de la clé persistée. `null` ⇒ dérivée du nom Dart via
  /// `@ZcrudModel.fieldRename`.
  final String? name;

  /// Multi-sélection (`multiple=true` — inventaire §3).
  final bool multiple;

  /// Hint de **format de persistance** d'un champ date (défaut
  /// [ZPersistAs.iso8601]). Avec [ZPersistAs.timestamp], le générateur collecte
  /// la clé persistée du champ dans l'artefact neutre `$XxxTimestampFields`
  /// (`Set<String>`) que `zcrud_firestore` consomme pour encoder le champ en
  /// `Timestamp` natif (gap B14, AD-5 préservé). Sans effet hors du chemin
  /// Firestore distant.
  final ZPersistAs persistAs;
}
