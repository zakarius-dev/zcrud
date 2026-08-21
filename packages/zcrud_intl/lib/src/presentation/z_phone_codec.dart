/// `ZPhoneCodec` — **pont interne** entre la lib `phone_numbers_parser` et
/// le modèle neutre [ZPhoneNumber] (invariant AD-1).
///
/// **Confinement (invariant AD-1)** : c'est le **seul** fichier de
/// `zcrud_intl` qui importe `phone_numbers_parser`. Aucun type de la lib
/// (`PhoneNumber`, `IsoCode`) ne franchit cette frontière : l'API ne
/// prend/rend que des `String`/[ZPhoneNumber] neutres. Ce fichier n'est
/// **jamais** exporté par le barrel `lib/zcrud_intl.dart`.
///
/// **Défensif (invariant AD-10)** : [parse] ne throw jamais — un numéro
/// non parsable rend un [ZPhoneNumber] « brut » (national tel quel, sans
/// E.164), jamais une exception.
library;

import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

import '../domain/z_phone_number.dart';

/// Pont pur-fonction lib téléphone ⇄ modèle neutre. Aucun état.
abstract final class ZPhoneCodec {
  const ZPhoneCodec._();

  /// Index `nom alpha-2 → IsoCode` construit **une seule fois** (remplace
  /// le scan linéaire de `IsoCode.values` à chaque appel).
  static Map<String, pnp.IsoCode>? _isoByName;

  /// Résout l'`IsoCode` de la lib pour un code alpha-2 [iso] (insensible à
  /// la casse) ; `null` si inconnu (invariant AD-10, jamais de throw).
  static pnp.IsoCode? _isoOf(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final index = _isoByName ??= <String, pnp.IsoCode>{
      for (final code in pnp.IsoCode.values) code.name: code,
    };
    return index[iso.toUpperCase()];
  }

  /// Indicatif d'appel (`"+227"`) d'un code pays [iso], ou `null` si inconnu.
  /// Défensif — ne throw jamais (AD-10).
  static String? dialCodeOf(String iso) {
    final code = _isoOf(iso);
    if (code == null) return null;
    try {
      final n = pnp.PhoneNumber(isoCode: code, nsn: '');
      return '+${n.countryCode}';
    } catch (_) {
      return null;
    }
  }

  /// Parse [raw] (saisie utilisateur) pour le pays [iso] et retourne un
  /// [ZPhoneNumber] **neutre**. Si le numéro est valide, [ZPhoneNumber.e164] est
  /// renseigné; sinon on retourne un modèle « brut » (national = saisie
  /// nettoyée, dialCode/iso du pays) **sans** E.164 — jamais de throw (AD-10).
  static ZPhoneNumber parse(String raw, {String? iso}) {
    final trimmed = raw.trim();
    final code = _isoOf(iso);
    final dial = code == null ? null : dialCodeOf(iso!);
    if (trimmed.isEmpty) {
      return ZPhoneNumber(isoCode: code?.name, dialCode: dial);
    }
    try {
      final parsed = pnp.PhoneNumber.parse(
        trimmed,
        destinationCountry: code,
        callerCountry: code,
      );
      if (parsed.isValid()) {
        return ZPhoneNumber(
          e164: parsed.international,
          isoCode: parsed.isoCode.name,
          dialCode: '+${parsed.countryCode}',
          nationalNumber: parsed.nsn,
        );
      }
      // Parsé mais invalide (longueur/pattern) → neutre « brut », pas d'E.164.
      return ZPhoneNumber(
        isoCode: parsed.isoCode.name,
        dialCode: '+${parsed.countryCode}',
        nationalNumber: parsed.nsn,
      );
    } catch (_) {
      // Non parsable → conserve la saisie en national, sans E.164 (AD-10).
      return ZPhoneNumber(
        isoCode: code?.name,
        dialCode: dial,
        nationalNumber: trimmed,
      );
    }
  }

  /// Chiffres seuls de [s] (`null`/vide → `''`). Ne throw jamais.
  static String _digits(String? s) =>
      s == null ? '' : s.replaceAll(RegExp(r'[^0-9]'), '');

  /// **CONTRAT DE LA VALEUR EXPOSÉE**.
  ///
  /// Canonise ce que le paquet de rendu produit en la chaîne **persistée** par le
  /// champ `phoneNumber`. Invariant, vérifié par garde:
  ///
  /// > la valeur, quand elle est non `null`, correspond TOUJOURS à `^\+[0-9]+$` —
  /// > **forme internationale complète**, indicatif pays inclus, chiffres seuls
  /// > après le `+`. Elle vaut l'**E.164 canonique** dès que le numéro est valide
  /// > pour le pays sélectionné; sinon la **même forme internationale**,
  /// > simplement incomplète.
  ///
  /// **Pourquoi pas `value.phoneNumber` brut** : mesuré sur
  /// `intl_phone_number_input 0.7.5`, ce champ vaut l'E.164
  /// quand le numéro est valide, mais sinon `dialCode` **concaténé à la saisie
  /// non nettoyée** — la sonde a produit `'+228+++++'` pour une saisie `'+++++'`
  /// et `'+228901'` pour une saisie partielle. Persister cela donnerait une
  /// donnée qu'on ne peut plus interpréter (ni E.164, ni national, ni même
  /// « chiffres »). On persiste donc une forme **toujours** interprétable.
  ///
  /// **Repli (AD-10)**: `null` si aucun chiffre n'est saisi, ou si aucun
  /// indicatif pays n'est déterminable — sans indicatif la chaîne ne serait pas
  /// internationale, donc pas interprétable; on préfère l'absence de valeur à
  /// une valeur ambiguë. Ne throw jamais.
  ///
  /// [raw] = chaîne du paquet; [dialCode] / [iso] = pays sélectionné.
  static String? toInternationalString(
    String? raw, {
    String? dialCode,
    String? iso,
  }) {
    final dial = (dialCode != null && dialCode.isNotEmpty)
        ? dialCode
        : (iso == null ? null : dialCodeOf(iso));
    final cc = _digits(dial);
    var rest = raw?.trim() ?? '';
    // Le paquet préfixe sa sortie par l'indicatif du pays SÉLECTIONNÉ: on le
    // retire UNE fois pour ne pas le compter deux fois (`'+228' + '+22890…'`).
    if (dial != null && dial.isNotEmpty && rest.startsWith(dial)) {
      rest = rest.substring(dial.length);
    }
    // Ce qui reste porte-t-il DÉJÀ son propre indicatif ? Deux chemins mesurés:
    //  - la saisie d'un numéro international d'un AUTRE pays que le pays
    //    sélectionné: le paquet rend son E.164 réel (`'+33612345678'` alors que
    //    le sélecteur est sur TG). Le re-préfixer donnerait `'+22833612345678'`;
    //  - un indicatif doublé sur une saisie absurde (`'+228' + '+++++'`).
    // Dans les deux cas le pays est porté par la chaîne: on ne re-préfixe pas,
    // et on laisse le préfixe décider du pays (aucun indice `iso` imposé).
    final alreadyInternational = rest.startsWith('+');
    final String candidate;
    if (alreadyInternational) {
      final d = _digits(rest);
      if (d.isEmpty) return null;
      candidate = '+$d';
    } else {
      final nsn = _digits(rest);
      if (nsn.isEmpty) return null;
      if (cc.isEmpty) return null;
      candidate = '+$cc$nsn';
    }
    try {
      final hint = alreadyInternational ? null : _isoOf(iso);
      final parsed = pnp.PhoneNumber.parse(
        candidate,
        destinationCountry: hint,
        callerCountry: hint,
      );
      // `phone_numbers_parser` reste le moteur de VALIDATION/normalisation
      // canonique (pur-Dart, synchrone); le paquet de rendu, lui, ne sert que
      // l'affichage. Les deux servent — aucun n'est mort.
      if (parsed.isValid()) return parsed.international;
    } catch (_) {
      // AD-10: numéro absurde → on garde la forme internationale brute.
    }
    return candidate;
  }

  /// Partie **nationale** (chiffres seuls) d'une valeur persistée [stored]
  /// (forme internationale). Sert à ré-amorcer l'affichage quand le numéro
  /// stocké n'est pas (encore) valide. `''` si rien d'exploitable. Ne throw
  /// jamais (AD-10).
  static String nationalDigitsOf(String? stored, {String? iso}) {
    final s = stored?.trim() ?? '';
    if (s.isEmpty) return '';
    try {
      final parsed = pnp.PhoneNumber.parse(
        s,
        destinationCountry: _isoOf(iso),
        callerCountry: _isoOf(iso),
      );
      return parsed.nsn;
    } catch (_) {
      final dial = iso == null ? null : dialCodeOf(iso);
      var rest = s;
      if (dial != null && rest.startsWith(dial)) rest = rest.substring(dial.length);
      return _digits(rest);
    }
  }

  /// Code ISO alpha-2 déduit d'une valeur persistée [stored] (forme
  /// internationale), ou `null`. Ne throw jamais (AD-10).
  static String? isoOfInternational(String? stored) {
    final s = stored?.trim() ?? '';
    if (s.isEmpty) return null;
    try {
      return pnp.PhoneNumber.parse(s).isoCode.name;
    } catch (_) {
      return null;
    }
  }

  /// `true` si [stored] est un numéro **valide** (donc en E.164 canonique) pour
  /// le pays [iso]. Ne throw jamais (AD-10).
  static bool isValidInternational(String? stored, {String? iso}) {
    final s = stored?.trim() ?? '';
    if (s.isEmpty) return false;
    try {
      final parsed = pnp.PhoneNumber.parse(
        s,
        destinationCountry: _isoOf(iso),
        callerCountry: _isoOf(iso),
      );
      return parsed.isValid();
    } catch (_) {
      return false;
    }
  }
}
