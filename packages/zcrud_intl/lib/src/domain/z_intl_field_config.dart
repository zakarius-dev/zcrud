/// `ZIntlFieldConfig` — **config additive des champs intl** (E11b-2, AD-4/AD-12).
///
/// origine: les champs `phoneNumber`/`country`/`address` d'E11a-2 amorçaient leur
/// pays initial via un paramètre de factory (`defaultIsoCode`) — un défaut **par
/// registre**, pas **par champ**. FR-21 exige des **défauts nationaux
/// surchargeables** sans **aucun** défaut codé en dur non surchargeable, et le
/// cœur `zcrud_core` est **interdit d'édition** (AD-1). Comme E11b-1
/// (`ZGeoFieldConfig`), on porte ces défauts **par champ** via une sous-classe
/// concrète `const` de [ZFieldConfig] (point d'extension AD-4 déjà prévu par le
/// cœur). Posée sur `ZFieldSpec.config`, elle est lue via `ctx.field.config` par
/// les widgets `phoneNumber`/`country`/`address` **existants**.
///
/// **Rétro-compat E11a-2 STRICTE** : `config == null` → comportement **identique**
/// à E11a-2 (le pays initial suit `slice?.isoCode ?? widget.defaultIsoCode`). La
/// config ne fait que **surcharger par champ** un défaut sinon absent.
///
/// **AD-12 (aucun défaut national codé en dur non surchargeable)** : tous les
/// champs sont **neutres** (défauts vides) et **surchargeables** par l'app hôte.
/// Aucune clé/secret.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-14) : aucune closure,
/// aucun widget, aucune dépendance lourde. Seule dépendance : la base
/// [ZFieldConfig] de `zcrud_core`.
library;

import 'package:zcrud_core/zcrud_core.dart';

import 'z_national_phone_validator.dart';

/// Config additive `const` des champs intl (AD-4). Vit dans `zcrud_intl` ; aucune
/// modification du cœur. Tous les défauts sont neutres/surchargeables (AD-12).
class ZIntlFieldConfig extends ZFieldConfig {
  /// Construit une config intl `const`.
  ///
  /// - [defaultCountryIso] : pays initial (code ISO alpha-2) pour
  ///   `phoneNumber`/`country`/`address` — **surcharge par champ** le
  ///   `defaultIsoCode` de factory ; `null` → aucun défaut imposé (AD-12) ;
  /// - [preferredCountryIsos] : codes ISO remontés **en tête** du picker pays
  ///   (défaut `const []` → ordre catalogue inchangé, rétro-compat E11a-2) ;
  /// - [showDialCode] : afficher l'indicatif dans le picker compact (neutre) ;
  /// - [searchable] : autoriser la recherche dans le picker (neutre) ;
  /// - [defaultCurrencyCode] : code ISO 4217 d'amorçage pour `ZCurrencyField`
  ///   (`null` → aucun défaut) ;
  /// - [nationalPhone] : validateur national **opt-in** (DP-20) posé sur le champ
  ///   `phoneNumber` ; `null` (défaut) → **aucune** validation nationale, aucun
  ///   message (rétro-compat E11a-2/E11b-2 STRICTE). Non-`null` → le message
  ///   d'erreur du validateur est affiché sous le champ numéro (opt-in, AD-12 :
  ///   la politique nationale est fournie par l'app, jamais codée en dur ici).
  const ZIntlFieldConfig({
    this.defaultCountryIso,
    this.preferredCountryIsos = const <String>[],
    this.showDialCode = true,
    this.searchable = true,
    this.defaultCurrencyCode,
    this.nationalPhone,
  });

  /// Pays initial (code ISO alpha-2), **surchargeable** ; `null` = aucun défaut.
  final String? defaultCountryIso;

  /// Pays remontés en tête du picker (codes ISO alpha-2) ; `const []` = ordre
  /// catalogue inchangé (rétro-compat).
  final List<String> preferredCountryIsos;

  /// Afficher l'indicatif dans le sélecteur compact (option neutre).
  final bool showDialCode;

  /// Autoriser la recherche dans le sélecteur (option neutre).
  final bool searchable;

  /// Code devise ISO 4217 d'amorçage pour `ZCurrencyField` ; `null` = aucun.
  final String? defaultCurrencyCode;

  /// Validateur national **opt-in** du champ `phoneNumber` (DP-20) ; `null` =
  /// aucune validation nationale (rétro-compat stricte).
  final ZNationalPhoneValidator? nationalPhone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZIntlFieldConfig &&
          runtimeType == other.runtimeType &&
          defaultCountryIso == other.defaultCountryIso &&
          _listEq(preferredCountryIsos, other.preferredCountryIsos) &&
          showDialCode == other.showDialCode &&
          searchable == other.searchable &&
          defaultCurrencyCode == other.defaultCurrencyCode &&
          nationalPhone == other.nationalPhone;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        defaultCountryIso,
        Object.hashAll(preferredCountryIsos),
        showDialCode,
        searchable,
        defaultCurrencyCode,
        nationalPhone,
      );

  static bool _listEq(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
