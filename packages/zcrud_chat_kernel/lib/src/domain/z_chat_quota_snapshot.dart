/// Instantané de quota d'usage — `ZChatQuotaSnapshot`.
///
/// **Ce qui n'est pas porté** : le vocabulaire d'abonnement propre à un hôte
/// (paliers d'offre, packs régionaux). Ce value object ne porte qu'une forme
/// de **rate-limit générique** — limite, reste, réinitialisation, solde prépayé.
library;

import 'package:zcrud_core/domain.dart';

/// Instantané de quota (valeurs déjà calculées par le backend), immuable.
class ZChatQuotaSnapshot {
  /// Construit un instantané (immuable, `const`).
  const ZChatQuotaSnapshot({
    this.limit = 0,
    this.remaining = 0,
    this.resetEpoch = 0,
    this.prepaidBalance,
  });

  /// Quota de la période. `0` (ou négatif) ⇒ **non borné**.
  final int limit;

  /// Reste disponible sur la période.
  final int remaining;

  /// Epoch (secondes) de réinitialisation du quota.
  final int resetEpoch;

  /// Solde prépayé restant, si exposé.
  final int? prepaidBalance;

  /// Quota épuisé : aucun reste **et** aucun solde prépayé.
  bool get isExhausted => remaining <= 0 && (prepaidBalance ?? 0) <= 0;

  /// Quota **borné** (donc affichable). `limit <= 0` ⇒ illimité.
  bool get isBounded => limit > 0;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatQuotaSnapshot? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatQuotaSnapshot(
      limit: zJsonInt(map['limit'], 0),
      remaining: zJsonInt(map['remaining'], 0),
      resetEpoch: zJsonInt(map['reset_epoch'], 0),
      prepaidBalance: zJsonIntOrNull(map['prepaid_balance']),
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'limit': limit,
        'remaining': remaining,
        'reset_epoch': resetEpoch,
        if (prepaidBalance != null) 'prepaid_balance': prepaidBalance,
      };

  /// Copie modifiée (champs omis conservés).
  ZChatQuotaSnapshot copyWith({
    int? limit,
    int? remaining,
    int? resetEpoch,
    int? prepaidBalance,
  }) =>
      ZChatQuotaSnapshot(
        limit: limit ?? this.limit,
        remaining: remaining ?? this.remaining,
        resetEpoch: resetEpoch ?? this.resetEpoch,
        prepaidBalance: prepaidBalance ?? this.prepaidBalance,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatQuotaSnapshot &&
          limit == other.limit &&
          remaining == other.remaining &&
          resetEpoch == other.resetEpoch &&
          prepaidBalance == other.prepaidBalance;

  @override
  int get hashCode =>
      Object.hash(limit, remaining, resetEpoch, prepaidBalance);

  @override
  String toString() => 'ZChatQuotaSnapshot(limit: $limit, '
      'remaining: $remaining, resetEpoch: $resetEpoch)';
}
