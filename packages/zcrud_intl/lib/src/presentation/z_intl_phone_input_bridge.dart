/// `ZIntlPhoneInputBridge` — **pont interne** entre le paquet de rendu
/// `intl_phone_number_input` et l'API neutre de `zcrud_intl`
/// (CR-DODLP-PHONE-NATIF, 2026-08-10 — AD-1/AD-7/AD-10).
///
/// **CONFINEMENT (AD-1)** : c'est le **SEUL** fichier du dépôt qui importe
/// `intl_phone_number_input`. Aucun type du paquet (`InternationalPhoneNumberInput`,
/// `PhoneNumber`, `SelectorConfig`, `PhoneInputSelectorType`, `Country`) ne
/// franchit cette frontière : l'API ci-dessous ne prend/rend que des `String`,
/// des types Flutter et [ZPhoneInputChange]/[ZPhoneInputSeed], définis ici. Ce
/// fichier n'est **jamais** exporté par le barrel `lib/zcrud_intl.dart`. C'est
/// exactement le patron `flutter_quill` ⊂ `zcrud_markdown` et
/// `phone_numbers_parser` ⊂ `z_phone_codec.dart`.
///
/// **DÉFENSIF (AD-10)** — le paquet est un TIERS, et trois de ses chemins ont été
/// **mesurés crashants** (sonde du 2026-08-10, `intl_phone_number_input 0.7.5`) :
///
///  1. `initialValue` porteur d'un `phoneNumber` **sans** `isoCode` ⇒
///     `_TypeError` (« Null check operator used on a null value ») levé
///     **synchronement dans `initState`** (`input_widget.dart:438`, `isoCode!`).
///     C'est une `Error`, pas une `Exception` : aucun `catch (Exception)` du
///     paquet ne la rattrape. ⇒ [ZPhoneInputSeed.of] n'attache **jamais** un
///     numéro sans code pays résolu.
///  2. `countries: ['XX']` (ISO inconnu du paquet) ⇒ liste filtrée vide, puis
///     `RangeError` sur `countries[0]` (`Utils.getInitialSelectedCountry`).
///     Là encore une `Error`. ⇒ [sanitizeCountries] **intersecte** la demande
///     avec le catalogue RÉEL du paquet et retourne `null` (= tous les pays)
///     si l'intersection est vide.
///  3. Repasser au paquet un `initialValue` porteur d'un numéro **trop court**
///     fait remonter une `NumberParseException` **non rattrapée** :
///     `didUpdateWidget` → `initialiseWidget()` → `PhoneNumberUtil.isValidNumber`,
///     qui appelle `phoneUtil.parse` **hors de tout `try`**. Découvert par
///     campagne R3 (injection « graine reconstruite à chaque build ») : le champ
///     ne rend alors plus une frappe sur deux, il **plante**. ⇒ deux gardes :
///     la graine est créée 1× ([ZPhoneInputSeed]), et un numéro n'y est attaché
///     que si `phone_numbers_parser` l'a d'abord déclaré **valide**.
///  4. Le message d'erreur et le libellé d'invite du paquet sont des
///     **littéraux anglais codés en dur** (`'Invalid phone number'`,
///     `'Phone number'`) — FR-26. ⇒ le pont neutralise le validateur interne
///     (`validator: (_) => null`, `errorMessage: null`) et impose toujours une
///     `InputDecoration` injectée par l'appelant.
///
/// ⚠️ L'intersection de (2) lit `Countries.countryList`, qui n'est pas ré-exporté
/// par le barrel du paquet : c'est un import d'implémentation, **délibéré et
/// épinglé** (`intl_phone_number_input: ^0.7.5`). Une garde
/// (`z_intl_phone_input_bridge_test.dart`) affirme que [supportedIsoCodes] reste
/// non vide et contient `TG`/`FR` : si le paquet déplace ce fichier, la garde
/// rougit au lieu de laisser passer un `RangeError` en production.
library;

import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart' as ipni;
// Import d'implémentation DÉLIBÉRÉ et épinglé (`^0.7.5`) : le catalogue pays du
// paquet n'est PAS ré-exporté par son barrel, et sans lui on ne peut pas
// assainir la restriction `countries:` — ce qui laisserait passer le `RangeError`
// mesuré (cas 2 ci-dessus). Une garde affirme que ce catalogue reste lisible.
// ignore: implementation_imports
import 'package:intl_phone_number_input/src/models/country_list.dart'
    as ipni_countries;

/// Changement émis par le champ de rendu, en termes **neutres** (aucun type du
/// paquet). [number] est la chaîne telle que le paquet la produit — E.164
/// **seulement si le numéro est valide**, sinon `dialCode` concaténé à la saisie
/// brute (mesuré : `'+228+++++'`). Elle n'est donc **jamais** persistée telle
/// quelle : `ZPhoneCodec.toInternationalString` la canonise.
@immutable
class ZPhoneInputChange {
  /// Construit un changement neutre.
  const ZPhoneInputChange({this.number, this.isoCode, this.dialCode});

  /// Chaîne produite par le paquet (NON canonique — cf. doc de classe).
  final String? number;

  /// Code ISO alpha-2 du pays sélectionné dans le sélecteur.
  final String? isoCode;

  /// Indicatif du pays sélectionné (`'+228'`).
  final String? dialCode;
}

/// Valeur d'amorçage **opaque et STABLE** du champ de rendu.
///
/// **Pourquoi une graine et pas des paramètres** : le paquet compare
/// `oldWidget.initialValue?.hash != widget.initialValue?.hash`, où `hash` est un
/// **entier aléatoire tiré à la construction**. Reconstruire un `PhoneNumber` à
/// chaque `build` rendrait donc cette comparaison **toujours vraie** et
/// relancerait `initialiseWidget()` — qui **réécrit le contrôleur de texte** — à
/// chaque frappe (perte de curseur, objectif produit n°1 / AD-2). La graine est
/// donc créée **une seule fois** (`initState`) et repassée à l'identique.
@immutable
class ZPhoneInputSeed {
  const ZPhoneInputSeed._(this._value);

  /// Instance du paquet, **privée** : le type ne fuit pas hors de ce fichier.
  final ipni.PhoneNumber _value;

  /// Fabrique la graine.
  ///
  /// [isoCode] : pays d'amorçage (peut être inconnu — le paquet retombe alors
  /// sur le premier pays de son catalogue, sans lever).
  /// [e164] : numéro d'amorçage. **Ignoré si [isoCode] est `null`/vide** — c'est
  /// la garde contre le `_TypeError` mesuré (cf. doc de bibliothèque, cas 1).
  factory ZPhoneInputSeed.of({String? isoCode, String? e164}) {
    final iso = (isoCode == null || isoCode.isEmpty) ? null : isoCode;
    final number = (iso == null || e164 == null || e164.isEmpty) ? null : e164;
    return ZPhoneInputSeed._(
      ipni.PhoneNumber(phoneNumber: number, isoCode: iso),
    );
  }
}

/// Pont pur-fabrique paquet de rendu ⇄ API neutre. Aucun état global mutable.
abstract final class ZIntlPhoneInputBridge {
  const ZIntlPhoneInputBridge._();

  /// Clé du **bouton sélecteur de pays** rendu par le paquet.
  ///
  /// Ré-exposée en `Key` NEUTRE pour que les gardes de `zcrud_intl` puissent
  /// piloter le sélecteur sans importer le paquet (le confinement vaut aussi
  /// pour les tests). La valeur littérale vient du paquet ; si celui-ci la
  /// change, les gardes qui l'utilisent rougissent — c'est voulu.
  static const Key countrySelectorKey = Key('intl_dropdown_key');

  /// Clé du champ de recherche du dialogue pays.
  static const Key countrySearchKey = Key('intl_search_input_key');

  /// Clé de l'entrée pays [iso] dans le dialogue/la liste.
  static Key countryItemKey(String iso) =>
      Key('intl_country_${iso.toUpperCase()}_key');

  static Set<String>? _supported;

  /// Codes ISO alpha-2 **réellement** connus du paquet de rendu.
  ///
  /// Défensif (AD-10) : toute anomalie de lecture du catalogue du tiers rend un
  /// ensemble vide plutôt que de lever — [sanitizeCountries] retombe alors sur
  /// « tous les pays », qui est le comportement sûr du paquet.
  static Set<String> get supportedIsoCodes => _supported ??= _readSupported();

  static Set<String> _readSupported() {
    try {
      return <String>{
        for (final Object? c in ipni_countries.Countries.countryList)
          if (c is Map && c['alpha_2_code'] is String)
            (c['alpha_2_code'] as String).toUpperCase(),
      };
    } on Object {
      // AD-10 : on rattrape `Object` (et donc AUSSI les `Error`) — le précédent
      // mesuré deux fois cette semaine est un tiers qui ne rattrapait que les
      // `Exception` et laissait remonter l'échec normal.
      return const <String>{};
    }
  }

  /// Restreint la liste de pays offerte au sélecteur.
  ///
  /// Rend `null` (= **tous** les pays, comportement par défaut du paquet) quand
  /// [requested] est vide **ou** quand aucun des codes demandés n'existe dans
  /// [supportedIsoCodes] — c'est la garde contre le `RangeError` mesuré
  /// (cf. doc de bibliothèque, cas 2). Les codes sont normalisés en majuscules
  /// et dédupliqués en conservant l'ordre demandé.
  static List<String>? sanitizeCountries(Iterable<String> requested) {
    final known = supportedIsoCodes;
    if (known.isEmpty) return null;
    final out = <String>[];
    for (final raw in requested) {
      final iso = raw.trim().toUpperCase();
      if (known.contains(iso) && !out.contains(iso)) out.add(iso);
    }
    return out.isEmpty ? null : out;
  }

  /// Ramène un code ISO à un code **connu du paquet**, ou `null`.
  static String? sanitizeIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final up = iso.trim().toUpperCase();
    final known = supportedIsoCodes;
    if (known.isEmpty) return null;
    return known.contains(up) ? up : null;
  }

  /// Construit le champ de rendu (sélecteur pays drapeau/indicatif recherchable
  /// + saisie formatée « as-you-type »), en ne recevant QUE des types neutres.
  ///
  /// [seed] doit être créée **une seule fois** par montage (cf. [ZPhoneInputSeed]).
  /// [decoration] est **obligatoire** : elle porte le libellé, l'erreur et le
  /// style, tous injectés par l'appelant (FR-26 — aucun littéral du paquet).
  static Widget build({
    required ZPhoneInputSeed seed,
    required TextEditingController controller,
    required FocusNode focusNode,
    required InputDecoration decoration,
    required ValueChanged<ZPhoneInputChange> onChanged,
    Key? fieldKey,
    List<String>? countries,
    String? locale,
    bool enabled = true,
    bool searchable = true,
    TextStyle? textStyle,
    TextStyle? selectorTextStyle,
  }) =>
      ipni.InternationalPhoneNumberInput(
        fieldKey: fieldKey,
        initialValue: seed._value,
        textFieldController: controller,
        focusNode: focusNode,
        isEnabled: enabled,
        countries: countries,
        locale: locale,
        inputDecoration: decoration,
        textStyle: textStyle,
        selectorTextStyle: selectorTextStyle,
        // FR-26 : neutralise les littéraux anglais du paquet. Le message
        // d'erreur affiché vient de `decoration.errorText` (l10n injectée).
        errorMessage: null,
        validator: (_) => null,
        autoValidateMode: AutovalidateMode.disabled,
        // Parité legacy DODLP (`edition_screen.dart:2387`) : dialogue
        // recherchable, bouton sélecteur en préfixe, drapeaux emoji.
        selectorConfig: ipni.SelectorConfig(
          selectorType: searchable
              ? ipni.PhoneInputSelectorType.DIALOG
              : ipni.PhoneInputSelectorType.DROPDOWN,
          setSelectorButtonAsPrefixIcon: true,
          useEmoji: true,
          showFlags: true,
          // Le paquet complète sinon l'indicatif par `padRight(5, ' ')` : le
          // texte rendu deviendrait `'+33  '`, une chaîne d'affichage AMBIGUË
          // pour toute garde (et pour la copie utilisateur).
          trailingSpace: false,
        ),
        onInputChanged: (ipni.PhoneNumber n) => onChanged(
          ZPhoneInputChange(
            number: n.phoneNumber,
            isoCode: n.isoCode,
            dialCode: n.dialCode,
          ),
        ),
      );
}
