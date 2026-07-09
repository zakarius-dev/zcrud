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
class DomainFailure extends ZFailure {
  /// Construit un [DomainFailure].
  const DomainFailure(super.message);
}

/// Échec du **cache/store local** (lecture/écriture offline, corruption Hive…).
class CacheFailure extends ZFailure {
  /// Construit un [CacheFailure].
  const CacheFailure(super.message);
}

/// Entité **introuvable**. Peut porter l'[id] et le type d'[entity] recherchés.
class NotFoundFailure extends ZFailure {
  /// Construit un [NotFoundFailure], avec [id]/[entity] optionnels pour le contexte.
  const NotFoundFailure(super.message, {this.id, this.entity});

  /// Identité recherchée (opaque), si connue.
  final String? id;

  /// Nom logique du type d'entité recherché, si connu.
  final String? entity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotFoundFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          id == other.id &&
          entity == other.entity;

  @override
  int get hashCode => Object.hash(runtimeType, message, id, entity);

  @override
  String toString() => 'NotFoundFailure($message, id: $id, entity: $entity)';
}

/// Échec du **backend distant** (I/O réseau, erreur serveur, quota…).
class ServerFailure extends ZFailure {
  /// Construit un [ServerFailure].
  const ServerFailure(super.message);
}

/// Type de résultat ergonomique du domaine : `Either<ZFailure, T>` (AD-11).
///
/// Convention : `Left` = échec ([ZFailure]), `Right` = succès (`T`). Pour les
/// opérations « void », utiliser `ZResult<Unit>` avec `right(unit)`. Les **flux**
/// restent des `Stream<List<T>>` **nus** (jamais enveloppés — AD-11).
typedef ZResult<T> = Either<ZFailure, T>;
