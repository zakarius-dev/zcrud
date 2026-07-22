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

  /// Clé persistée (snake_case) de l'horodatage Last-Write-Wins (AD-9) —
  /// **hors-entité**. Définition **machine** d'AD-19 : aucun site ne doit
  /// redéclarer ce littéral.
  static const String kUpdatedAt = 'updated_at';

  /// Clé persistée (snake_case) du drapeau de soft-delete (AD-9/AD-16) —
  /// **hors-entité**. Définition **machine** d'AD-19.
  static const String kIsDeleted = 'is_deleted';

  /// Clés **RÉSERVÉES** à la couche de synchronisation (AD-19).
  ///
  /// Une entité de domaine ne les capture **JAMAIS** dans son échappatoire
  /// `extra` (AD-4) et ne les réémet **JAMAIS** depuis son `toMap`/`toJson` :
  /// elles appartiennent au **store**, pas au domaine métier. Le merge LWW se
  /// fait **toujours** sur `ZSyncMeta.updatedAt` (hors-entité), **jamais** sur
  /// un `T.updatedAt` interne (qui n'est, au mieux, qu'un miroir de compat).
  ///
  /// C'est la **définition machine unique** de la convention AD-19 : toute
  /// entité annotée dérive ses clés réservées de cet ensemble plutôt que de
  /// redéclarer les littéraux.
  static const Set<String> reservedKeys = <String>{kUpdatedAt, kIsDeleted};

  /// Retire les [reservedKeys] de [map] (helper de garde AD-19).
  ///
  /// **Pur et défensif** : ne mute **jamais** [map], retourne toujours une
  /// **nouvelle** map (map vide → map vide ; map sans clé réservée → copie
  /// égale). Sert aux entités/adapters qui doivent isoler le corps métier des
  /// métadonnées de sync.
  static Map<String, dynamic> stripReserved(Map<String, dynamic> map) {
    assert(() {
      final collided = collidingReservedKeys(map);
      if (collided.isEmpty) return true;
      // ignore: avoid_print
      print(
        'ZSyncMeta — ⚠️ COLLISION DE CLÉ RÉSERVÉE : le corps métier porte '
        '${collided.join(', ')}. Ces clés sont possédées par la couche de '
        'synchronisation (AD-19) et seront ÉCRASÉES par la méta hors-entité — '
        'la valeur métier serait perdue SANS SIGNAL. Renommez le champ (ex. '
        '`content_updated_at`) ou portez-le dans `extra`.',
      );
      return true;
    }());
    return <String, dynamic>{
      for (final e in map.entries)
        if (!reservedKeys.contains(e.key)) e.key: e.value,
    };
  }

  /// Clés RÉSERVÉES qu'un corps métier porterait à tort (CR-IFFD-14).
  ///
  /// La collision est **probable** : `updatedAt` est l'un des noms les plus
  /// répandus des modèles applicatifs, et un hôte peut légitimement porter un
  /// « dernière modification par l'utilisateur » — qui n'est PAS l'estampille
  /// Last-Write-Wins. Le contrat de clé réservée n'est pas remis en cause ; ce
  /// qui l'est, c'est que l'écrasement soit **muet**.
  ///
  /// Exposé pour qu'un hôte puisse **vérifier avant d'écrire** plutôt que de
  /// découvrir la perte en production :
  ///
  /// ```dart
  /// final collided = ZSyncMeta.collidingReservedKeys(monEntite.toMap());
  /// if (collided.isNotEmpty) { /* renommer, ou porter dans `extra` */ }
  /// ```
  ///
  /// En debug, [stripReserved] journalise déjà la collision ; cette fonction
  /// permet de la traiter **programmatiquement**, y compris en release.
  static Set<String> collidingReservedKeys(Map<String, dynamic> map) =>
      <String>{
        for (final k in map.keys)
          if (reservedKeys.contains(k)) k,
      };

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
      updatedAt: _parseIso(json[kUpdatedAt]),
      isDeleted: json[kIsDeleted] is bool ? json[kIsDeleted] as bool : false,
    );
  }

  /// Parse tolérant d'un horodatage ISO-8601 ; toute valeur invalide → `null`.
  static DateTime? _parseIso(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Sérialise en clés **snake_case** ; [updatedAt] en ISO-8601 (ou `null`).
  Map<String, dynamic> toJson() => <String, dynamic>{
        kUpdatedAt: updatedAt?.toIso8601String(),
        kIsDeleted: isDeleted,
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
