/// `ZDeltaCodec` — codec **identité** (format persisté = Delta JSON), la voie
/// interne d'E6-1 factorisée (AD-7). Round-trip **sans perte** (AC2).
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
/// Round-trip **IDENTITÉ** : `jsonDecode(encode(ops)) == ops` exactement (y.c.
/// ops embed opaques — AC9). Avec ce codec, persisté == tranche (Delta JSON) ⇒
/// **rétrocompatibilité stricte** avec E6-1.
final class ZDeltaCodec implements ZCodec {
  /// Codec identité `const` (aucun état).
  const ZDeltaCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) => jsonEncode(deltaOps);

  @override
  List<Map<String, dynamic>> decode(Object? persisted) =>
      DeltaNeutralOps.decodeDefensiveOps(persisted);
}
