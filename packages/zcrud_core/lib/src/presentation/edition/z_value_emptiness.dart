/// LOT 2 — **règle UNIQUE de vacuité d'une valeur de tranche** + projection de
/// cette valeur vers le texte soumis aux validateurs `FormFieldValidator<String>`.
///
/// ## Le défaut corrigé (mesuré)
///
/// `_stringOf(o) => o == null ? '' : '$o'` (ancien `z_field_widget.dart:253` et
/// `z_submission.dart:272`) projetait une **collection vide** `[]` vers la
/// chaîne `"[]"` — qui n'est PAS vide. `FormBuilderValidators.required<String>`
/// l'acceptait donc : **un champ obligatoire non rempli passait la validation**
/// (multi-sélection, tags, sous-liste, fichiers multiples…).
///
/// ## La règle, alignée sur l'existant (pas une seconde règle)
///
/// [zIsEmptyValue] est le **portage** littéral de la règle déjà en vigueur dans
/// le dépôt (`DynamicEdition._isEmptyValue`, `z_read_only_value._isEmpty`) :
/// `null`, `String` vide, `Iterable` vide et `Map` vide sont **vides** ; tout le
/// reste est **présent** — en particulier `false`, `0` et `'0'`, qui sont des
/// valeurs légitimement renseignées (le mode lecture les affiche déjà).
///
/// ## Portée du correctif
///
/// La correction porte sur la **projection de valeur**, pas sur un `kind` de
/// champ : elle vaut donc **uniformément** pour toutes les familles dont la
/// tranche porte une collection (multi-`select`, `relation` multiple, `tags`,
/// `rowChips`, `checkbox` groupé, `subList`, `dynamicItem`, `file`/`image`/
/// `document` multiples, `colorMulti`) — aucune incohérence par famille.
///
/// ⚠️ **Changement de comportement ASSUMÉ** : un formulaire dont un champ requis
/// portait une collection vide était soumissible ; il devient bloquant. C'est
/// l'objet du lot.
library;

/// `true` si [value] compte comme **vide**.
///
/// Règle unique du dépôt : `null` / `String` vide / `Iterable` vide / `Map`
/// vide. `false` et `0` NE sont **PAS** vides (valeurs présentes).
bool zIsEmptyValue(Object? value) {
  if (value == null) return true;
  if (value is String) return value.isEmpty;
  if (value is Iterable) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}

/// Projette une valeur de tranche vers le **texte soumis aux validateurs**
/// (`FormFieldValidator<String>`).
///
/// Une valeur **vide au sens de [zIsEmptyValue]** produit `''` — c'est ce qui
/// fait mordre `required` sur une collection ou une map vide. Toute valeur
/// présente conserve sa représentation `'$value'` (donc `false` → `'false'`,
/// `0` → `'0'` : présentes, jamais requalifiées en vide).
String zValidationText(Object? value) =>
    zIsEmptyValue(value) ? '' : '$value';
