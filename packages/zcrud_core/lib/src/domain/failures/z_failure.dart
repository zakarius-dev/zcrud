/// Hiérarchie d'erreurs maison du domaine `zcrud_core` + type de résultat.
///
/// origine: lex_core (module « Étude ») — `Failure` (base abstraite + sous-types)
/// avec `==`/`hashCode` via `Object.hash`. Canonique §5 (`Equatable` jamais) ;
/// AD-11 (`Either<ZFailure,T>` / `Unit`) ; AD-4 (extension inter-package).
library;

import 'package:dartz/dartz.dart';

/// Base **abstraite extensible** de la hiérarchie d'erreurs du domaine.
///
/// Déclarée `abstract class` — **jamais `sealed`** — précisément parce que
/// AD-4 rejette `sealed` pour l'extension **inter-package** : les satellites
/// (`zcrud_flashcard` → `FlashcardGenerationFailure`, E9) et les apps hôtes
/// doivent pouvoir ajouter leurs propres `ZFailure` sans forker le cœur. On
/// renonce donc à l'exhaustivité compilateur d'un `switch` : le traitement
/// d'erreur passe par `fold`/`is`/[message], pas par pattern-matching exhaustif.
///
/// Égalité de base sur `(runtimeType, message)` via `Object.hash` (AD-11,
/// canonique §5 — `Equatable` proscrit). Les sous-classes portant des champs
/// propres **doivent** surcharger `==`/`hashCode` pour les inclure.
abstract class ZFailure {
  /// Construit une failure avec son [message] humainement lisible.
  const ZFailure(this.message);

  /// Message décrivant l'échec (jamais `null`).
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => '$runtimeType($message)';
}

/// Échec d'une **règle métier** du domaine (invariant violé, opération invalide).
class ZDomainFailure extends ZFailure {
  /// Construit un [ZDomainFailure].
  const ZDomainFailure(super.message);
}

/// Échec du **cache/store local** (lecture/écriture offline, corruption Hive…).
class ZCacheFailure extends ZFailure {
  /// Construit un [ZCacheFailure].
  const ZCacheFailure(super.message);
}

/// Entité **introuvable**. Peut porter l'[id] et le type d'[entity] recherchés.
class ZNotFoundFailure extends ZFailure {
  /// Construit un [ZNotFoundFailure], avec [id]/[entity] optionnels pour le contexte.
  const ZNotFoundFailure(super.message, {this.id, this.entity});

  /// Identité recherchée (opaque), si connue.
  final String? id;

  /// Nom logique du type d'entité recherché, si connu.
  final String? entity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNotFoundFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          id == other.id &&
          entity == other.entity;

  @override
  int get hashCode => Object.hash(runtimeType, message, id, entity);

  @override
  String toString() => 'ZNotFoundFailure($message, id: $id, entity: $entity)';
}

/// Échec du **backend distant** (I/O réseau, erreur serveur, quota…).
class ZServerFailure extends ZFailure {
  /// Construit un [ZServerFailure].
  const ZServerFailure(super.message);
}

/// Type de résultat ergonomique du domaine : `Either<ZFailure, T>` (AD-11).
///
/// Convention : `Left` = échec ([ZFailure]), `Right` = succès (`T`). Pour les
/// opérations « void », utiliser `ZResult<Unit>` avec `right(unit)`. Les **flux**
/// restent des `Stream<List<T>>` **nus** (jamais enveloppés — AD-11).
typedef ZResult<T> = Either<ZFailure, T>;

// ─────────────────────────────────────────────────────────────────────────────
// CR-LEX-11 — alias de TRANSITION vers les noms préfixés `Z`.
//
// Les 4 spécialisations de `ZFailure` s'appelaient `DomainFailure`,
// `CacheFailure`, `NotFoundFailure`, `ServerFailure` — sans le préfixe `Z`
// appliqué partout ailleurs dans la surface publique. Or ce sont EXACTEMENT les
// noms de la hiérarchie `Failure` de Clean Architecture + dartz, la plus
// répandue de l'écosystème : tout hôte suivant ce patron voyait 4 collisions de
// compilation sur 4 à l'import nu du barrel (mesuré côté lex_douane).
//
// Les alias ci-dessous gardent le code existant compilable. Ils sont
// **dépréciés** : un hôte en collision peut les masquer par une liste `hide`
// FIXE de 4 noms —
//
//   import 'package:zcrud_core/zcrud_core.dart'
//       hide DomainFailure, CacheFailure, NotFoundFailure, ServerFailure;
//
// — au lieu d'un `show` qu'il faudrait étendre à chaque nouveau symbole utilisé.
// Ces alias seront retirés dans une version majeure ultérieure ; la collision
// disparaîtra alors complètement.
// ─────────────────────────────────────────────────────────────────────────────

/// Alias déprécié de [ZDomainFailure] (CR-LEX-11).
@Deprecated('Renommé ZDomainFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef DomainFailure = ZDomainFailure;

/// Alias déprécié de [ZCacheFailure] (CR-LEX-11).
@Deprecated('Renommé ZCacheFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef CacheFailure = ZCacheFailure;

/// Alias déprécié de [ZNotFoundFailure] (CR-LEX-11).
@Deprecated('Renommé ZNotFoundFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef NotFoundFailure = ZNotFoundFailure;

/// Alias déprécié de [ZServerFailure] (CR-LEX-11).
@Deprecated('Renommé ZServerFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef ServerFailure = ZServerFailure;
