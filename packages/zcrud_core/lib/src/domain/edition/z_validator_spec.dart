/// Validateur **déclaratif** d'un champ, porté par `@ZcrudField.validators`
/// (authoring) et projeté dans `ZFieldSpec.validators` (runtime, E2-5).
///
/// origine: ensemble transverse `validators` → `FormBuilderValidators.compose`
/// de DODLP/IFFD (technical-inventory §3, ligne
/// « Validation transverse »). Type-valeur `const` **pur-données** : **aucune
/// closure, aucune exécution** — c'est ce qui rend `reflectable` inutile (AD-3)
/// et le schéma lisible par `ConstantReader`.
///
/// **Frontière statique/runtime** : E2-4 ne livre que la **donnée déclarative**.
/// La composition en `FormBuilderValidators` (et les `stateValidators`
/// dépendant de l'état du formulaire) est **E3** — attachée au `ZFormController`,
/// jamais au schéma statique.
library;

/// Famille de validateurs déclaratifs (discriminant de [ZValidatorSpec]).
enum ZValidatorKind {
  /// Valeur requise (non nulle / non vide).
  required,

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
class ZValidatorSpec {
  const ZValidatorSpec._(
    this.kind, {
    this.length,
    this.bound,
    this.refKey,
    this.value,
    this.pattern,
    this.errorText,
  });

  /// Valeur requise.
  const ZValidatorSpec.required({String? errorText})
      : this._(ZValidatorKind.required, errorText: errorText);

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

  /// Adresse postale.
  const ZValidatorSpec.address({String? errorText})
      : this._(ZValidatorKind.address, errorText: errorText);

  /// Pourcentage (0–100).
  const ZValidatorSpec.percentage({String? errorText})
      : this._(ZValidatorKind.percentage, errorText: errorText);

  /// Politique de mot de passe.
  const ZValidatorSpec.password({String? errorText})
      : this._(ZValidatorKind.password, errorText: errorText);

  /// Correspondance à l'expression régulière [pattern].
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
          errorText == other.errorText;

  @override
  int get hashCode =>
      Object.hash(runtimeType, kind, length, bound, refKey, value, pattern, errorText);

  @override
  String toString() => 'ZValidatorSpec(${kind.name})';
}
