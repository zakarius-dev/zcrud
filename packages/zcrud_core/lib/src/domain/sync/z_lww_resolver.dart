/// Résolveur **Last-Write-Wins** PUR du domaine `zcrud_core` (E5-3).
///
/// origine: canonique §7 / AD-9 — « merge Last-Write-Wins sur `updatedAt` ». Le
/// *comment* du merge (décision par `id`) vit ici, en **Dart pur** ; le *quand*
/// (débounce/multi-dépôts, E5-4) et l'application concrète (stores, E5-3) vivent
/// ailleurs. Ce résolveur ne fait **aucune** I/O, ne lit **aucune** horloge et ne
/// connaît **aucun** type backend : il compare deux [ZSyncEntry] et retourne une
/// [ZLwwDecision] **déterministe**.
/// AD-5 (backend-agnostique) ; AD-9 (LWW) ; AD-16 (soft-delete hors-entité).
library;

import '../contracts/z_entity.dart';
import 'z_sync_entry.dart';

/// Action décidée par le [ZLwwResolver] pour un `id` donné.
enum ZLwwAction {
  /// Les deux côtés sont **convergents** : aucune écriture.
  noop,

  /// Le **distant** gagne : l'adopter **dans** le local (`local.applyMerged`).
  adoptRemoteIntoLocal,

  /// Le **local** gagne : le **pousser** vers le distant (`remote.applyMerged`).
  pushLocalToRemote,
}

/// Décision de merge pour un `id` : une [action] et l'[entry] **gagnante** à
/// appliquer (`null` pour [ZLwwAction.noop]).
class ZLwwDecision<T extends ZEntity> {
  const ZLwwDecision._(this.action, this.entry);

  /// Aucune écriture (états déjà convergents).
  const ZLwwDecision.noop() : this._(ZLwwAction.noop, null);

  /// Adopter le gagnant [entry] **distant** dans le local (préserve sa méta).
  const ZLwwDecision.adoptRemoteIntoLocal(ZSyncEntry<T> entry)
      : this._(ZLwwAction.adoptRemoteIntoLocal, entry);

  /// Pousser le gagnant [entry] **local** vers le distant (préserve sa méta).
  const ZLwwDecision.pushLocalToRemote(ZSyncEntry<T> entry)
      : this._(ZLwwAction.pushLocalToRemote, entry);

  /// L'action à appliquer.
  final ZLwwAction action;

  /// L'entrée gagnante à appliquer **verbatim** (`null` ssi [ZLwwAction.noop]).
  final ZSyncEntry<T>? entry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZLwwDecision<T> &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          entry == other.entry;

  @override
  int get hashCode => Object.hash(runtimeType, action, entry);

  @override
  String toString() => 'ZLwwDecision(action: $action, entry: $entry)';
}

/// Résolveur **Last-Write-Wins** — fonction pure `resolve` (aucun état, aucune
/// horloge). Instanciable `const` : le dépôt offline-first en injecte une
/// instance par défaut.
///
/// **Règles déterministes** (testées, AD-9) pour un `id` présent d'un côté et/ou
/// de l'autre :
/// - `local` seul (absent du distant) → [ZLwwAction.pushLocalToRemote] ;
/// - `remote` seul (absent du local) → [ZLwwAction.adoptRemoteIntoLocal] ;
/// - les **deux** présents → le plus grand [ZSyncEntry.updatedAt] gagne
///   (distant plus récent → adopt ; local plus récent → push) ;
/// - un [ZSyncEntry.updatedAt] **`null`** est le **plus ancien** (perd contre
///   toute date non-`null`) ;
/// - **égalité stricte** de `updatedAt` (y compris deux `null`) → **le LOCAL fait
///   foi** (source de vérité, AD-9) : [ZLwwAction.noop] si les états sont
///   **identiques** (même corps + même `is_deleted`), sinon
///   [ZLwwAction.pushLocalToRemote] (le local, autoritaire, réaligne le distant).
///
/// > Alternative consignée (Ambiguïté #2) : « précédence-tombstone » à égalité
/// > (le soft-delete gagne pour éviter toute résurrection). **Tranché** en faveur
/// > de « local fait foi » (AD-9) : à égalité stricte de milliseconde le local
/// > est autoritaire ; la résurrection n'est possible que si le local est
/// > **réellement** plus récent, ce qui est la sémantique LWW attendue.
class ZLwwResolver {
  /// Construit le résolveur (sans état).
  const ZLwwResolver();

  /// Résout la décision LWW pour un `id` dont l'entrée [local] et/ou [remote]
  /// est fournie (au moins une des deux est non-`null` en usage normal).
  ZLwwDecision<T> resolve<T extends ZEntity>(
    ZSyncEntry<T>? local,
    ZSyncEntry<T>? remote,
  ) {
    // Cas dégénéré (aucun côté) : rien à faire (défensif, ne survient pas dans
    // une union d'`id` réels).
    if (local == null && remote == null) return ZLwwDecision<T>.noop();
    if (remote == null) return ZLwwDecision<T>.pushLocalToRemote(local!);
    if (local == null) return ZLwwDecision<T>.adoptRemoteIntoLocal(remote);

    final cmp = _compareUpdatedAt(local.updatedAt, remote.updatedAt);
    if (cmp > 0) return ZLwwDecision<T>.pushLocalToRemote(local);
    if (cmp < 0) return ZLwwDecision<T>.adoptRemoteIntoLocal(remote);

    // Égalité stricte de `updatedAt` (ou deux `null`) → le LOCAL fait foi.
    if (_sameState(local, remote)) return ZLwwDecision<T>.noop();
    return ZLwwDecision<T>.pushLocalToRemote(local);
  }

  /// Compare deux `updatedAt` avec la règle « `null` = le plus ancien » :
  /// retourne `>0` si [a] est plus récent, `<0` si [b] est plus récent, `0` à
  /// égalité (y compris deux `null`).
  int _compareUpdatedAt(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1; // a (local) est le plus ancien → b gagne
    if (b == null) return 1; // b (distant) est le plus ancien → a gagne
    return a.compareTo(b);
  }

  /// Deux entrées ont le **même état** ssi même drapeau de soft-delete ET même
  /// corps métier (`==` de l'entité). Sert au [ZLwwAction.noop] à égalité.
  bool _sameState<T extends ZEntity>(ZSyncEntry<T> a, ZSyncEntry<T> b) =>
      a.isDeleted == b.isDeleted && a.entity == b.entity;
}
