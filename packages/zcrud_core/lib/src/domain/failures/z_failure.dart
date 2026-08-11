/// Hiérarchie d'erreurs maison du domaine `zcrud_core` + type de résultat.
///
/// Base abstraite + sous-types avec `==`/`hashCode` via `Object.hash`
/// (`Equatable` n'est jamais utilisé). Invariants portés : AD-11
/// (`Either<ZFailure,T>` / `Unit`) ; AD-4 (extension inter-package).
library;

import 'package:dartz/dartz.dart';

/// Base **abstraite extensible** de la hiérarchie d'erreurs du domaine.
///
/// Déclarée `abstract class` — **jamais `sealed`** — précisément parce que
/// AD-4 rejette `sealed` pour l'extension **inter-package** : un paquet
/// satellite (par exemple `zcrud_flashcard` → `FlashcardGenerationFailure`)
/// et les apps hôtes doivent pouvoir ajouter leurs propres `ZFailure` sans
/// forker le cœur. On renonce donc à l'exhaustivité compilateur d'un
/// `switch` : le traitement d'erreur passe par `fold`/`is`/[message], pas
/// par pattern-matching exhaustif.
///
/// Égalité de base sur `(runtimeType, message)` via `Object.hash` (AD-11 ;
/// `Equatable` proscrit). Les sous-classes portant des champs
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

/// Échec du **backend distant** (I/O réseau, erreur serveur).
///
/// Pour un **quota dépassé**, préférer [ZQuotaExceededFailure] : sans un
/// sous-type dédié, tout aller-retour par un port zcrud **détruirait la
/// distinction** entre « le serveur est en panne » (réessayer) et « votre
/// quota est épuisé » (ne pas réessayer, informer l'utilisateur).
class ZServerFailure extends ZFailure {
  /// Construit un [ZServerFailure].
  const ZServerFailure(super.message);
}

/// **Quota dépassé** — l'appel est refusé pour épuisement d'un contingent
/// (requêtes IA, stockage, débit), pas pour une panne.
///
/// ## Pourquoi un sous-type dédié
///
/// La distinction quota / panne serveur **change ce que l'appelant doit
/// faire** : une panne se réessaie, un quota non — il faut informer
/// l'utilisateur, et éventuellement attendre [retryAfter]. Aucun sous-type ne
/// pouvant porter cette information, elle était aplatie dans le `message` d'un
/// [ZServerFailure] : l'hôte devait alors **parser du texte** pour décider,
/// ou traiter les deux pareil.
///
/// [retryAfter] est la durée AVANT laquelle un nouvel essai est inutile
/// (`null` si le backend ne la fournit pas — c'est le cas courant, et son
/// absence ne doit jamais être confondue avec « réessayable tout de suite »).
class ZQuotaExceededFailure extends ZFailure {
  /// Construit un [ZQuotaExceededFailure], avec un [retryAfter] optionnel.
  const ZQuotaExceededFailure(super.message, {this.retryAfter});

  /// Délai avant lequel réessayer est inutile — `null` si non fourni.
  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZQuotaExceededFailure &&
          other.message == message &&
          other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(runtimeType, message, retryAfter);

  @override
  String toString() =>
      'ZQuotaExceededFailure($message, retryAfter: $retryAfter)';
}

/// L'opération **n'est pas supportée** par cette implémentation — ce n'est PAS
/// une panne.
///
/// **Le défaut que ce type ferme.** Un membre de port peut avoir une
/// implémentation par défaut qui rend `Left(ZDomainFailure(<message>))` pour
/// dire « ce dépôt n'a pas de couche de sync / de couche distante ». Sans ce
/// type dédié, le refus serait **explicite mais indiscernable** : pour
/// distinguer « non supporté » (⇒ je bascule sur mon propre chemin) d'« une
/// panne réelle » (⇒ je remonte l'erreur), l'appelant n'aurait que la
/// **comparaison de chaîne** — fragile par nature, et qui casse à la première
/// reformulation d'un message.
///
/// Côté hôte, adopter un tel membre sans ce sous-type ferait passer une
/// garantie de **structurelle** à **conditionnelle à l'implémentation
/// injectée**, avec une dégradation **silencieuse** possible dans un cas
/// (index méta vide ⇒ tri faux) et un **échec visible par l'utilisateur**
/// dans l'autre.
///
/// ```dart
/// final r = await repo.getAllWithMeta();
/// r.fold(
///   (f) => f is ZUnsupportedOperationFailure
///       ? _monPropreIndexMeta()   // capacité absente : repli DÉTERMINISTE
///       : _remonterLErreur(f),    // panne réelle : ne jamais l'avaler
///   (entries) => _utiliser(entries),
/// );
/// ```
///
/// **Limite assumée, à lire avant de concevoir dessus** : la découverte est
/// **a posteriori** — on apprend l'indisponibilité en appelant. C'est sans
/// conséquence pour une lecture ; pour une opération à effet visible, sondez au
/// câblage plutôt qu'au geste de l'utilisateur. Un drapeau `supportsXxx` est
/// **écarté délibérément** : il constituerait une **seconde source de vérité**
/// qu'un implémenteur pourrait oublier de mettre à jour en surchargeant le
/// membre — exactement l'échec silencieux que ce type évite.
///
/// [operation] nomme le membre non supporté (ex. `'getAllWithMeta'`), pour un
/// diagnostic exploitable sans parser le message.
class ZUnsupportedOperationFailure extends ZFailure {
  /// Construit l'échec, en nommant l'[operation] non supportée.
  const ZUnsupportedOperationFailure(super.message, {required this.operation});

  /// Nom du membre non supporté (ex. `'purgeLocalPropagatingTombstone'`).
  final String operation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZUnsupportedOperationFailure &&
          other.message == message &&
          other.operation == operation;

  @override
  int get hashCode => Object.hash(runtimeType, message, operation);

  @override
  String toString() =>
      'ZUnsupportedOperationFailure($message, operation: $operation)';
}

/// Type de résultat ergonomique du domaine : `Either<ZFailure, T>` (AD-11).
///
/// Convention : `Left` = échec ([ZFailure]), `Right` = succès (`T`). Pour les
/// opérations « void », utiliser `ZResult<Unit>` avec `right(unit)`. Les **flux**
/// restent des `Stream<List<T>>` **nus** (jamais enveloppés — AD-11).
typedef ZResult<T> = Either<ZFailure, T>;

// ─────────────────────────────────────────────────────────────────────────────
// Alias de TRANSITION vers les noms préfixés `Z`.
//
// Les 4 spécialisations de `ZFailure` s'appelaient `DomainFailure`,
// `CacheFailure`, `NotFoundFailure`, `ServerFailure` — sans le préfixe `Z`
// appliqué partout ailleurs dans la surface publique. Or ce sont EXACTEMENT les
// noms de la hiérarchie `Failure` de Clean Architecture + dartz, la plus
// répandue de l'écosystème : tout hôte suivant ce patron verrait 4 collisions
// de compilation sur 4 à l'import nu du barrel.
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

/// Alias déprécié de [ZDomainFailure].
@Deprecated('Renommé ZDomainFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef DomainFailure = ZDomainFailure;

/// Alias déprécié de [ZCacheFailure].
@Deprecated('Renommé ZCacheFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef CacheFailure = ZCacheFailure;

/// Alias déprécié de [ZNotFoundFailure].
@Deprecated('Renommé ZNotFoundFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef NotFoundFailure = ZNotFoundFailure;

/// Alias déprécié de [ZServerFailure].
@Deprecated('Renommé ZServerFailure (préfixe Z, anti-collision). '
    'Sera retiré dans une version majeure ultérieure.')
typedef ServerFailure = ZServerFailure;
