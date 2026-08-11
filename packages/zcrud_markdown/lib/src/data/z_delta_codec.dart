/// `ZDeltaCodec` — codec **identité** (format persisté = Delta JSON), la voie
/// interne factorisée (AD-7). Round-trip **sans perte**.
library;

import 'dart:convert';

import '../domain/z_codec.dart';
import 'delta_neutral_ops.dart';

/// Codec par DÉFAUT : le format persisté EST le Delta JSON neutre.
///
/// - [encode] : ops → `String` JSON canonique (`jsonEncode`). Contrat documenté :
///   représentation persistée = **`String` JSON**. `encode(const [])` → `'[]'`.
/// - [decode] : `String` JSON / `List` Delta / valeur corrompue → ops neutres,
///   **DÉFENSIF** (AD-10 : `[]` sur corrompu, jamais de throw).
///
/// Round-trip **IDENTITÉ** : `jsonDecode(encode(ops)) == ops` exactement, y.c.
/// pour des ops embed opaques. Avec ce codec, persisté == tranche (Delta
/// JSON) ⇒ **rétrocompatibilité stricte** avec un contenu déjà en Delta.
final class ZDeltaCodec implements ZCodec {
  /// Codec identité `const` (aucun état).
  const ZDeltaCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) => jsonEncode(deltaOps);

  @override
  List<Map<String, dynamic>> decode(Object? persisted) =>
      DeltaNeutralOps.decodeDefensiveOps(persisted);
}
