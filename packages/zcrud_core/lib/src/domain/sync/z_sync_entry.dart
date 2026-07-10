/// Entrée de **synchronisation** du domaine `zcrud_core` : une entité **plus** ses
/// métadonnées de sync hors-entité ([ZSyncMeta]), transportées **ensemble** pour
/// le merge Last-Write-Wins (E5-3).
///
/// origine: canonique §7 — le merge LWW a besoin, de **chaque côté**, de voir
/// l'`updated_at` ET l'`is_deleted` de **toutes** les entrées, **y compris** les
/// soft-deletées (tombstones). Les lectures ordinaires (`getAll`/`pull`) excluent
/// les tombstones : `ZSyncEntry` est le véhicule de la **voie de lecture de sync**
/// (`syncEntries()`) qui, elle, les inclut.
/// AD-5 (backend-agnostique) ; AD-9 (offline-first LWW) ; AD-16 (soft-delete
/// hors-entité).
library;

import '../contracts/z_entity.dart';
import 'z_sync_meta.dart';

/// Value object **immuable** appariant une entité [T] et son [ZSyncMeta]
/// hors-entité (la clé LWW `updatedAt` + le drapeau `isDeleted`).
///
/// **Transporte les tombstones** : une entrée soft-deletée reste un `ZSyncEntry`
/// valide ([isDeleted] `== true`, [entity] décodée). C'est précisément ce qui
/// permet au merge LWW (E5-3) de **propager une suppression** d'un côté à l'autre
/// — impossible via `getAll`/`pull` qui excluent les soft-deletés.
///
/// **Dart pur** (AD-5) : aucun type backend (`Box`/`Timestamp`/…) — uniquement
/// [T] (contraint `ZEntity`) et [ZSyncMeta] (ISO-8601, snake_case).
class ZSyncEntry<T extends ZEntity> {
  /// Construit une entrée de sync appariant [entity] et son [meta].
  const ZSyncEntry({required this.entity, required this.meta});

  /// L'entité décodée (jamais `null` — un tombstone porte son corps décodé).
  final T entity;

  /// Les métadonnées de sync **hors-entité** (clé LWW + soft-delete).
  final ZSyncMeta meta;

  /// Identité opaque dérivée de l'entité (`null` si éphémère — hors sync).
  String? get id => entity.id;

  /// Clé de merge Last-Write-Wins dérivée du [meta] (`null` = jamais synchronisé).
  DateTime? get updatedAt => meta.updatedAt;

  /// Drapeau de soft-delete dérivé du [meta] (un tombstone porte `true`).
  bool get isDeleted => meta.isDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSyncEntry<T> &&
          runtimeType == other.runtimeType &&
          entity == other.entity &&
          meta == other.meta;

  @override
  int get hashCode => Object.hash(runtimeType, entity, meta);

  @override
  String toString() => 'ZSyncEntry(entity: $entity, meta: $meta)';
}
