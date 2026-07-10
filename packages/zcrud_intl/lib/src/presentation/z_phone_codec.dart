/// `ZPhoneCodec` — **pont interne** entre la lib `phone_numbers_parser` et le
/// modèle neutre [ZPhoneNumber] (E11a-2, AD-1).
///
/// **CONFINEMENT (AD-1)** : c'est le **SEUL** fichier de `zcrud_intl` qui importe
/// `phone_numbers_parser`. Aucun type de la lib (`PhoneNumber`, `IsoCode`) ne
/// franchit cette frontière : l'API ne prend/rend que des `String`/[ZPhoneNumber]
/// neutres. Ce fichier n'est **jamais** exporté par le barrel `lib/zcrud_intl.dart`.
///
/// **Défensif (AD-10)** : [parse] ne throw jamais — un numéro non parsable rend
/// un [ZPhoneNumber] « brut » (national tel quel, sans E.164), jamais une
/// exception.
library;

import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

import '../domain/z_phone_number.dart';

/// Pont pur-fonction lib téléphone ⇄ modèle neutre. Aucun état.
abstract final class ZPhoneCodec {
  const ZPhoneCodec._();

  /// Index `nom alpha-2 → IsoCode` construit **une seule fois** (LOW-2 :
  /// remplace le scan linéaire de `IsoCode.values` à chaque appel).
  static Map<String, pnp.IsoCode>? _isoByName;

  /// Résout l'`IsoCode` de la lib pour un code alpha-2 [iso] (insensible à la
  /// casse) ; `null` si inconnu (AD-10, jamais de throw).
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
  /// renseigné ; sinon on retourne un modèle « brut » (national = saisie
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
}
