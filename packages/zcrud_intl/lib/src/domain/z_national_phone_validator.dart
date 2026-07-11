/// `ZNationalPhoneValidator` — **validateur de numéro national paramétrable**
/// (DP-20, gap M9, AD-1/AD-10/AD-12/AD-14).
///
/// origine: DODLP porte une politique téléphonique **nationale** (clé
/// `tgPhoneNumber` : longueur fixe + liste de préfixes autorisés) que le seul
/// [ZPhoneCodec] E.164 générique **ne capture pas**. Plutôt qu'étendre le
/// catalogue **fermé** `ZValidatorKind` du cœur (interdit — AD-1), DP-20 livre ce
/// validateur **autonome, pur-Dart** dans `zcrud_intl`, **paramétrable**
/// ([prefixes] + [length]) et **orthogonal** au codec (opt-in, n'altère jamais la
/// valeur émise).
///
/// **Neutralité (AD-12)** : **aucun** « Togo », préfixe ni longueur codé en dur.
/// La politique nationale est fournie **par paramètres** (recette ci-dessous),
/// jamais en défaut du package.
///
/// **Défensif (AD-10)** : [validate] **ne throw jamais** — accepte `null`, un
/// [ZPhoneNumber], une `Map` sérialisée ou une `String` brute, et normalise
/// défensivement toute entrée inattendue.
///
/// **Pur-Dart (AD-14)** : n'importe **ni** Flutter, **ni** `phone_numbers_parser`,
/// **ni** `zcrud_core` — seule dépendance : le modèle neutre [ZPhoneNumber].
///
/// ## Recette Togo (parité DODLP `tgPhoneNumber`) — NEUTRE et surchargeable
///
/// La politique DODLP : longueur fixe + préfixe ∈
/// `{70,71,77,78,79,90,91,92,93,96,97,98,99}`. DODLP valide la chaîne nationale
/// **formatée** (`"90 12 34 56"` = **11** caractères, espaces compris), tandis que
/// [ZPhoneNumber.nationalNumber] expose des **chiffres nus** (Togo = **8**
/// chiffres). Deux politiques équivalentes selon la cible :
///
/// ```dart
/// // Variante A — sur la partie nationale en CHIFFRES NUS (nationalNumber) :
/// const togoNationalPhone = ZNationalPhoneValidator(
///   prefixes: ['70', '71', '77', '78', '79', '90', '91', '92', '93', '96', '97', '98', '99'],
///   length: 8,            // 8 chiffres nus
///   required: true,
///   // digitsOnly: true (défaut) : "90 12 34 56" est normalisé en "90123456".
/// );
///
/// // Variante B — FIDÈLE à DODLP sur la chaîne nationale FORMATÉE ("90 12 34 56") :
/// const togoNationalPhoneFormatted = ZNationalPhoneValidator(
///   prefixes: ['70', '71', '77', '78', '79', '90', '91', '92', '93', '96', '97', '98', '99'],
///   length: 11,           // 11 caractères, espaces compris
///   required: true,
///   digitsOnly: false,
/// );
///
/// // Câblage opt-in : ZIntlFieldConfig(nationalPhone: togoNationalPhone) sur ZFieldSpec.config.
/// ```
library;

import 'z_phone_number.dart';

/// Discriminant d'erreur **neutre** (sans message) — la traduction vit dans la
/// couche présentation (`nationalPhoneErrorText`, AD-1/AD-13).
enum ZNationalPhoneError {
  /// Numéro requis mais absent/vide (n'apparaît que si [ZNationalPhoneValidator.required]).
  required,

  /// Longueur de la partie nationale ≠ [ZNationalPhoneValidator.length].
  invalidLength,

  /// La partie nationale ne commence par aucun des [ZNationalPhoneValidator.prefixes].
  invalidPrefix,
}

/// Validateur national **paramétrable** `const` (couche `domain`, pur-Dart).
///
/// Un numéro dont la partie nationale a la **bonne [length]** ET commence par
/// **l'un des [prefixes]** est **valide** ([validate] renvoie `null`) ; sinon
/// [validate] renvoie le [ZNationalPhoneError] discriminant (requis → longueur →
/// préfixe, ordre DODLP).
class ZNationalPhoneValidator {
  /// Construit un validateur national.
  ///
  /// - [prefixes] : préfixes nationaux autorisés (comparés en **début** de la
  ///   partie nationale normalisée) ; **obligatoire**, jamais codé en dur ;
  /// - [length] : longueur **exacte** attendue de la partie nationale (sur
  ///   chiffres nus si [digitsOnly], sinon sur la chaîne brute) ;
  /// - [required] : si `true`, une entrée vide → [ZNationalPhoneError.required] ;
  ///   sinon une entrée vide est **valide** (`null`) ;
  /// - [digitsOnly] : si `true` (défaut), l'entrée est normalisée en **chiffres
  ///   seuls** avant évaluation (`"90 12 34 56"` → `"90123456"`).
  const ZNationalPhoneValidator({
    required this.prefixes,
    required this.length,
    this.required = false,
    this.digitsOnly = true,
  });

  /// Préfixes nationaux autorisés (surchargeables, AD-12).
  final List<String> prefixes;

  /// Longueur exacte attendue de la partie nationale.
  final int length;

  /// Exige une valeur non vide.
  final bool required;

  /// Normalise l'entrée en chiffres seuls avant évaluation (défaut `true`).
  final bool digitsOnly;

  /// Valide [value] **sans jamais throw** (AD-10).
  ///
  /// Extrait la partie nationale ([ZPhoneNumber.nationalNumber] | `String` |
  /// `Map` via [ZPhoneNumber.fromMapSafe] ; tout autre type → vide), normalise
  /// ([digitsOnly]), puis applique **requis → longueur → préfixe**. Renvoie
  /// `null` si valide.
  ZNationalPhoneError? validate(Object? value) {
    final raw = _nationalOf(value);
    final normalized =
        digitsOnly ? raw.replaceAll(RegExp(r'[^0-9]'), '') : raw;
    if (normalized.isEmpty) {
      return required ? ZNationalPhoneError.required : null;
    }
    if (normalized.length != length) return ZNationalPhoneError.invalidLength;
    final hasPrefix = prefixes.any(normalized.startsWith);
    if (!hasPrefix) return ZNationalPhoneError.invalidPrefix;
    return null;
  }

  /// Extraction **défensive** (AD-10) de la partie nationale ; tout type
  /// inattendu → chaîne vide (jamais de throw).
  static String _nationalOf(Object? value) {
    if (value == null) return '';
    if (value is ZPhoneNumber) return value.nationalNumber ?? '';
    if (value is String) return value;
    if (value is Map) return ZPhoneNumber.fromMapSafe(value)?.nationalNumber ?? '';
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNationalPhoneValidator &&
          length == other.length &&
          required == other.required &&
          digitsOnly == other.digitsOnly &&
          _listEq(prefixes, other.prefixes);

  @override
  int get hashCode => Object.hash(
        length,
        required,
        digitsOnly,
        Object.hashAll(prefixes),
      );

  @override
  String toString() => 'ZNationalPhoneValidator(prefixes: $prefixes, '
      'length: $length, required: $required, digitsOnly: $digitsOnly)';

  static bool _listEq(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
