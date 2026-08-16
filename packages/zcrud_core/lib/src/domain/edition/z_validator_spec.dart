/// Validateur **déclaratif** d'un champ, porté par `@ZcrudField.validators`
/// (authoring) et projeté dans `ZFieldSpec.validators` (runtime).
///
/// Type-valeur `const` **pur-données** : **aucune closure, aucune
/// exécution** — c'est ce qui rend `reflectable` inutile (invariant AD-3) et
/// le schéma lisible par `ConstantReader`.
///
/// **Frontière statique/runtime** : ce type ne livre que la **donnée
/// déclarative**. La composition en `FormBuilderValidators` (et les
/// validateurs dépendant de l'état du formulaire) vit dans le moteur
/// d'édition — attachée au `ZFormController`, jamais au schéma statique.
library;

import 'z_condition.dart';

/// Famille de validateurs déclaratifs (discriminant de [ZValidatorSpec]).
enum ZValidatorKind {
  /// Valeur requise (non nulle / non vide).
  required,

  /// Valeur requise **quand une condition tient** — voir
  /// `ZValidatorSpec.requiredIf` et `ZValidatorSpec.condition`.
  requiredIf,

  /// Longueur minimale (chaîne/collection) — voir `ZValidatorSpec.length`.
  minLength,

  /// Longueur maximale (chaîne/collection) — voir `ZValidatorSpec.length`.
  maxLength,

  /// Borne minimale numérique — littérale (`bound`) OU clé d'un autre champ
  /// (`refKey` ⇒ `minValueKey`).
  min,

  /// Borne maximale numérique — littérale (`bound`) OU clé d'un autre champ
  /// (`refKey` ⇒ `maxValueKey`).
  max,

  /// Égalité à une valeur de référence (`value`).
  equal,

  /// Inégalité à une valeur de référence (`value`).
  notEqual,

  /// Égalité à la valeur d'un autre champ (`refKey` ⇒ `matchKey`).
  match,

  /// Format e-mail.
  email,

  /// Format URL.
  url,

  /// Format adresse IP.
  ip,

  /// Numéro de carte bancaire (checksum Luhn).
  creditCard,

  /// Numéro de téléphone.
  phone,

  /// Chaîne purement numérique.
  numeric,

  /// Chaîne représentant un entier.
  integer,

  /// Chaîne représentant une date.
  dateString,

  /// Adresse postale.
  address,

  /// Pourcentage (0–100).
  percentage,

  /// Politique de mot de passe.
  password,

  /// Correspondance à une expression régulière (`pattern`).
  pattern,
}

/// Spécification `const` d'un validateur de champ (pur-données).
///
/// Chaque variante est construite par un **constructeur de fabrique nommé**
/// `const` ; les paramètres non pertinents restent `null`. `errorText`
/// (optionnel, partout) porte un message d'erreur littéral ou une clé l10n
/// (résolu côté UI en E3).
///
/// ## Forme et présence sont deux exigences distinctes
///
/// Un validateur de **forme** — [ZValidatorSpec.pattern], [ZValidatorSpec.email],
/// [ZValidatorSpec.minLength], [ZValidatorSpec.min]… — décrit ce à quoi une
/// valeur doit ressembler **quand il y en a une**. Il laisse donc passer un
/// champ laissé vide.
///
/// La **présence** est exigée par la famille « requis », et par elle seule :
/// [ZValidatorSpec.required] l'exige toujours, [ZValidatorSpec.requiredIf]
/// l'exige quand sa condition tient. Un champ obligatoire ET contraint dans sa
/// forme déclare les deux :
///
/// ```dart
/// // Téléphone facultatif, mais valide dès qu'il est rempli :
/// validators: [ZValidatorSpec.pattern(r'^\+228[0-9]{8}$')],
///
/// // E-mail obligatoire ET bien formé :
/// validators: [ZValidatorSpec.required(), ZValidatorSpec.email()],
///
/// // Motif obligatoire seulement si le dossier est marqué « contentieux » :
/// validators: [ZValidatorSpec.requiredIf(ZCondition.truthy('contentieux'))],
/// ```
class ZValidatorSpec {
  const ZValidatorSpec._(
    this.kind, {
    this.length,
    this.bound,
    this.refKey,
    this.value,
    this.pattern,
    this.errorText,
    this.passwordMinLength,
    this.passwordMaxLength,
    this.requireUppercase,
    this.requireLowercase,
    this.requireDigit,
    this.requireSpecial,
    this.enforceFormat,
    this.enforceRange,
    this.rangeMin,
    this.rangeMax,
    this.condition,
  });

  /// Valeur requise — le **seul** validateur qui exige une présence : un champ
  /// vide n'est refusé que s'il le déclare.
  const ZValidatorSpec.required({String? errorText})
      : this._(ZValidatorKind.required, errorText: errorText);

  /// Valeur requise **seulement quand [condition] tient** — la présence
  /// devient une exigence conditionnelle, sans cesser d'être portée par un
  /// validateur (jamais par un validateur de forme).
  ///
  /// [condition] est une [ZCondition] : la même donnée déclarative que celle
  /// d'un `displayCondition`, évaluée contre l'état **courant** du formulaire.
  ///
  /// ```dart
  /// // Recherche par au moins un critère : chacun des trois champs est requis
  /// // tant que les deux autres sont vides.
  /// const ZFieldSpec(
  ///   name: 'nts',
  ///   type: EditionFieldType.text,
  ///   validators: <ZValidatorSpec>[
  ///     ZValidatorSpec.requiredIf(
  ///       ZCondition.and(<ZCondition>[
  ///         ZCondition.isEmpty('cst'),
  ///         ZCondition.isEmpty('marque'),
  ///       ]),
  ///       errorText: 'Renseignez au moins un critère',
  ///     ),
  ///   ],
  /// )
  /// ```
  ///
  /// **Articulation avec [ZValidatorSpec.required]** — la présence reste
  /// portée par la seule famille « requis » : `required` l'exige toujours,
  /// `requiredIf` l'exige quand sa condition tient. Les validateurs de
  /// **forme** ne changent pas de rôle : quand la condition ne tient pas, un
  /// champ laissé vide est **accepté**, exactement comme un champ sans
  /// `required` ; quand il est rempli, ses validateurs de forme gardent leur
  /// verrou. Les deux se cumulent sans se contredire — déclarer `required`
  /// **et** `requiredIf` sur un même champ revient à `required`.
  ///
  /// **Astérisque de label** : `ZFieldSpec.isRequired` reste `false` pour un
  /// champ qui ne déclare que `requiredIf` — l'exigence dépend de l'état, elle
  /// n'est pas une propriété du schéma. Le label n'affiche donc pas
  /// d'astérisque ; le message d'erreur, lui, apparaît dès que la condition
  /// tient et que le champ est vide.
  ///
  /// **Sources lues** : les feuilles de source [ZValueSource.state] (défaut) et
  /// [ZValueSource.persisted] sont honorées — l'état courant et la valeur
  /// d'origine sont l'un et l'autre lisibles là où le validateur s'exécute. Une
  /// feuille de source [ZValueSource.context] résout `null` (lecture défensive)
  /// : le contexte d'édition n'est pas accessible sous le champ, et une règle
  /// qui trancherait à la soumission sans jamais s'afficher sous le champ serait
  /// une impasse. Pour conditionner un requis sur un drapeau applicatif,
  /// exposez-le comme un champ du formulaire.
  const ZValidatorSpec.requiredIf(ZCondition condition, {String? errorText})
      : this._(
          ZValidatorKind.requiredIf,
          condition: condition,
          errorText: errorText,
        );

  /// Longueur minimale [length].
  const ZValidatorSpec.minLength(int length, {String? errorText})
      : this._(ZValidatorKind.minLength, length: length, errorText: errorText);

  /// Longueur maximale [length].
  const ZValidatorSpec.maxLength(int length, {String? errorText})
      : this._(ZValidatorKind.maxLength, length: length, errorText: errorText);

  /// Borne minimale **littérale** [bound].
  const ZValidatorSpec.min(num bound, {String? errorText})
      : this._(ZValidatorKind.min, bound: bound, errorText: errorText);

  /// Borne minimale **référencée** sur un autre champ ([refKey] ⇒
  /// `minValueKey`).
  const ZValidatorSpec.minKey(String refKey, {String? errorText})
      : this._(ZValidatorKind.min, refKey: refKey, errorText: errorText);

  /// Borne maximale **littérale** [bound].
  const ZValidatorSpec.max(num bound, {String? errorText})
      : this._(ZValidatorKind.max, bound: bound, errorText: errorText);

  /// Borne maximale **référencée** sur un autre champ ([refKey] ⇒
  /// `maxValueKey`).
  const ZValidatorSpec.maxKey(String refKey, {String? errorText})
      : this._(ZValidatorKind.max, refKey: refKey, errorText: errorText);

  /// Égalité à [value].
  const ZValidatorSpec.equal(Object? value, {String? errorText})
      : this._(ZValidatorKind.equal, value: value, errorText: errorText);

  /// Inégalité à [value].
  const ZValidatorSpec.notEqual(Object? value, {String? errorText})
      : this._(ZValidatorKind.notEqual, value: value, errorText: errorText);

  /// Égalité à la valeur du champ [refKey] (⇒ `matchKey`).
  const ZValidatorSpec.match(String refKey, {String? errorText})
      : this._(ZValidatorKind.match, refKey: refKey, errorText: errorText);

  /// Format e-mail.
  const ZValidatorSpec.email({String? errorText})
      : this._(ZValidatorKind.email, errorText: errorText);

  /// Format URL.
  const ZValidatorSpec.url({String? errorText})
      : this._(ZValidatorKind.url, errorText: errorText);

  /// Format adresse IP.
  const ZValidatorSpec.ip({String? errorText})
      : this._(ZValidatorKind.ip, errorText: errorText);

  /// Numéro de carte bancaire.
  const ZValidatorSpec.creditCard({String? errorText})
      : this._(ZValidatorKind.creditCard, errorText: errorText);

  /// Numéro de téléphone.
  const ZValidatorSpec.phone({String? errorText})
      : this._(ZValidatorKind.phone, errorText: errorText);

  /// Chaîne purement numérique.
  const ZValidatorSpec.numeric({String? errorText})
      : this._(ZValidatorKind.numeric, errorText: errorText);

  /// Chaîne représentant un entier.
  const ZValidatorSpec.integer({String? errorText})
      : this._(ZValidatorKind.integer, errorText: errorText);

  /// Chaîne représentant une date.
  const ZValidatorSpec.dateString({String? errorText})
      : this._(ZValidatorKind.dateString, errorText: errorText);

  /// Adresse postale — **no-op par défaut** (rôle indice de clavier, aucune
  /// validation de format). Le format n'est vérifié que si
  /// [enforceFormat] est `true` (opt-in ⇒ `FormBuilderValidators.street`).
  const ZValidatorSpec.address({bool enforceFormat = false, String? errorText})
      : this._(
          ZValidatorKind.address,
          enforceFormat: enforceFormat,
          errorText: errorText,
        );

  /// Pourcentage — **no-op par défaut** (indice/format d'affichage, saisie
  /// numérique libre). La plage n'est vérifiée que si
  /// [enforceRange] est `true` (opt-in ⇒ `between([min], [max])`, défaut 0–100).
  const ZValidatorSpec.percentage({
    bool enforceRange = false,
    num min = 0,
    num max = 100,
    String? errorText,
  }) : this._(
          ZValidatorKind.percentage,
          enforceRange: enforceRange,
          rangeMin: min,
          rangeMax: max,
          errorText: errorText,
        );

  /// Politique de mot de passe **paramétrable** — défauts permissifs :
  /// [minLength] `8`, [maxLength] `20`, [requireUppercase] &
  /// [requireLowercase] `true`, [requireDigit] & [requireSpecial] `false`. La
  /// politique stricte est **opt-in**
  /// (`password(minLength: 12, requireDigit: true, requireSpecial: true, …)`).
  const ZValidatorSpec.password({
    int minLength = 8,
    int maxLength = 20,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireDigit = false,
    bool requireSpecial = false,
    String? errorText,
  }) : this._(
          ZValidatorKind.password,
          passwordMinLength: minLength,
          passwordMaxLength: maxLength,
          requireUppercase: requireUppercase,
          requireLowercase: requireLowercase,
          requireDigit: requireDigit,
          requireSpecial: requireSpecial,
          errorText: errorText,
        );

  /// Correspondance à l'expression régulière [pattern].
  ///
  /// Décrit une **forme**, pas une présence : un champ laissé vide reste
  /// valide. Ajoutez [ZValidatorSpec.required] pour le rendre obligatoire.
  const ZValidatorSpec.pattern(String pattern, {String? errorText})
      : this._(ZValidatorKind.pattern, pattern: pattern, errorText: errorText);

  /// Famille du validateur.
  final ZValidatorKind kind;

  /// Longueur cible ([ZValidatorKind.minLength]/[ZValidatorKind.maxLength]).
  final int? length;

  /// Borne numérique **littérale** ([ZValidatorKind.min]/[ZValidatorKind.max]).
  final num? bound;

  /// Clé d'un autre champ référencé (`minValueKey`/`maxValueKey`/`matchKey`).
  final String? refKey;

  /// Valeur de référence ([ZValidatorKind.equal]/[ZValidatorKind.notEqual]).
  final Object? value;

  /// Expression régulière ([ZValidatorKind.pattern]).
  final String? pattern;

  /// Message d'erreur (littéral ou clé l10n ; résolu en E3).
  final String? errorText;

  /// Longueur minimale de la politique **mot de passe** ([ZValidatorKind.password]
  /// ; défaut `8`). Distinct de [length] (min/maxLength de chaîne générique).
  final int? passwordMinLength;

  /// Longueur maximale de la politique **mot de passe** (défaut `20`).
  final int? passwordMaxLength;

  /// Politique password : exige au moins une **majuscule** (défaut `true`).
  final bool? requireUppercase;

  /// Politique password : exige au moins une **minuscule** (défaut `true`).
  final bool? requireLowercase;

  /// Politique password : exige au moins un **chiffre** (défaut `false`).
  final bool? requireDigit;

  /// Politique password : exige au moins un **caractère spécial** (défaut
  /// `false`).
  final bool? requireSpecial;

  /// [ZValidatorKind.address] : `true` ⇒ valide le format (opt-in `street`) ;
  /// `false` (défaut) ⇒ **no-op**.
  final bool? enforceFormat;

  /// [ZValidatorKind.percentage] : `true` ⇒ valide la plage (opt-in `between`) ;
  /// `false` (défaut) ⇒ **no-op**.
  final bool? enforceRange;

  /// Borne basse de la plage `percentage` quand [enforceRange] (défaut `0`).
  final num? rangeMin;

  /// Borne haute de la plage `percentage` quand [enforceRange] (défaut `100`).
  final num? rangeMax;

  /// Condition d'exigence de [ZValidatorKind.requiredIf] ; `null` pour toutes
  /// les autres familles.
  final ZCondition? condition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZValidatorSpec &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          length == other.length &&
          bound == other.bound &&
          refKey == other.refKey &&
          value == other.value &&
          pattern == other.pattern &&
          errorText == other.errorText &&
          passwordMinLength == other.passwordMinLength &&
          passwordMaxLength == other.passwordMaxLength &&
          requireUppercase == other.requireUppercase &&
          requireLowercase == other.requireLowercase &&
          requireDigit == other.requireDigit &&
          requireSpecial == other.requireSpecial &&
          enforceFormat == other.enforceFormat &&
          enforceRange == other.enforceRange &&
          rangeMin == other.rangeMin &&
          rangeMax == other.rangeMax &&
          condition == other.condition;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        runtimeType,
        kind,
        length,
        bound,
        refKey,
        value,
        pattern,
        errorText,
        passwordMinLength,
        passwordMaxLength,
        requireUppercase,
        requireLowercase,
        requireDigit,
        requireSpecial,
        enforceFormat,
        enforceRange,
        rangeMin,
        rangeMax,
        condition,
      ]);

  @override
  String toString() => 'ZValidatorSpec(${kind.name})';
}
