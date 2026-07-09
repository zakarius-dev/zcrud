/// Métadonnées de synchronisation **hors-entité** du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — divergence `Mindmap` (sync hors-entité)
/// vs `StudyFolder` (in-entité), tranchée par AD-16 en faveur du **standard
/// hors-entité** `updated_at`/`is_deleted`. Canonique §2.2 (invariant Story 5.4).
library;

/// Sentinelle interne pour distinguer « argument omis » de « argument `null` »
/// dans [ZSyncMeta.copyWith] (permet de remettre [updatedAt] à `null`).
const Object _unset = Object();

/// Value object immuable portant les **métadonnées de synchronisation**
/// standardisées **hors-entité** (AD-16) : la clé Last-Write-Wins [updatedAt]
/// et le drapeau de soft-delete [isDeleted].
///
/// Séparation stricte (canonique §2.2) : **aucun** champ métier de l'entité ne
/// vit ici. Persistance en clés **snake_case** `updated_at` / `is_deleted`
/// (convention canonique §5), dates en **ISO-8601** (AD-5 : backend-agnostique,
/// jamais de `Timestamp`).
class ZSyncMeta {
  /// Construit des métadonnées de sync immuables.
  const ZSyncMeta({this.updatedAt, this.isDeleted = false});

  /// Clé de merge Last-Write-Wins (AD-9), ou `null` si jamais synchronisé.
  final DateTime? updatedAt;

  /// Drapeau de soft-delete (AD-9). Défaut sûr : `false`.
  final bool isDeleted;

  /// Désérialisation **défensive** (AD-10) : ne **throw jamais**.
  ///
  /// - `updated_at` absent / non-`String` / ISO-8601 mal formé → [updatedAt] `null` ;
  /// - `is_deleted` absent / non-`bool` → [isDeleted] `false` (défaut sûr).
  ///
  /// Un champ corrompu n'invalide jamais le parent (évolution de schéma additive).
  factory ZSyncMeta.fromJson(Map<String, dynamic> json) {
    return ZSyncMeta(
      updatedAt: _parseIso(json['updated_at']),
      isDeleted: json['is_deleted'] is bool ? json['is_deleted'] as bool : false,
    );
  }

  /// Parse tolérant d'un horodatage ISO-8601 ; toute valeur invalide → `null`.
  static DateTime? _parseIso(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Sérialise en clés **snake_case** ; [updatedAt] en ISO-8601 (ou `null`).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted,
      };

  /// Copie modifiée. [updatedAt] utilise une **sentinelle** : l'omettre conserve
  /// la valeur courante, passer `null` explicitement la **remet à `null`**.
  ZSyncMeta copyWith({Object? updatedAt = _unset, bool? isDeleted}) {
    return ZSyncMeta(
      updatedAt:
          identical(updatedAt, _unset) ? this.updatedAt : updatedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSyncMeta &&
          runtimeType == other.runtimeType &&
          updatedAt == other.updatedAt &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode => Object.hash(updatedAt, isDeleted);

  @override
  String toString() =>
      'ZSyncMeta(updatedAt: $updatedAt, isDeleted: $isDeleted)';
}
