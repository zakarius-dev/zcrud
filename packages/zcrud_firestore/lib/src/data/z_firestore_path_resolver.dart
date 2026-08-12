/// Résolveur de **chemins Firestore bi-topologie** (invariants AD-5/AD-11) —
/// l'unique endroit du système qui décide *où* vit une collection,
/// sans jamais coder un chemin en dur dans le domaine.
///
/// ## Le doublon factorisé
///
/// Deux topologies Firestore cohabitent couramment chez les applications
/// hôtes :
///  - **imbriquée** (nested) : `users/{uid}/study_folders/{folderId}/flashcards` ;
///  - **plate au premier niveau, par type** (flat) : `db.collection(name)` —
///    à l'exclusion de tout CRUD quasi-réflexif qui dériverait le nom de
///    collection de `T.toString()` (le nom de classe par réflexion). Une
///    topologie **globale** existe aussi (ex. des liens de partage, hors de
///    tout scope `users/{uid}`).
///
/// ## Ce que ce résolveur garantit (invariant AD-5)
///
/// - **Entrée NEUTRE, sortie `String`** : `resolveCollection`/`resolveDoc`
///   n'acceptent **aucun** type `cloud_firestore` (ni `CollectionReference`, ni
///   `DocumentReference`, ni `Query`) et **retournent un chemin `String`**. Le
///   dépôt fait `firestore.collection(path)` **en interne** — le type Firestore
///   reste **confiné** (invariants AD-5/AD-11).
/// - **Config explicite & STATIQUE** : la topologie de chaque `kind` est une
///   **règle littérale déclarée** ([ZFirestorePathRule]) injectée à la
///   construction. Le segment de collection est un **littéral** (`'flashcards'`),
///   **jamais** dérivé de `T.toString()`/`runtimeType` : un CRUD quasi-réflexif
///   est **structurellement impossible ici** (le résolveur ne connaît **aucun**
///   type générique `T` — seulement des `String kind`).
/// - **Aucun chemin en dur dans le domaine** : le
///   kernel/les entités n'importent **jamais** ce résolveur ; il vit dans
///   `zcrud_firestore`.
///
/// ## Erreur explicite plutôt que chemin muet (invariants AD-10/AD-11)
///
/// Une résolution impossible (kind inconnu, topologie imbriquée **sans**
/// `parentId`, topologie user-scopée **sans** `userId`) retourne un
/// `Left(ZDomainFailure)` **explicite** — **jamais** un chemin silencieusement
/// incorrect qui écrirait dans la mauvaise collection.
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Forme topologique d'un `kind` de collection.
enum ZFirestoreTopology {
  /// Collection **top-level par type**. Optionnellement préfixée par
  /// `users/{userId}` ([ZFirestorePathRule.userScoped]).
  flatTopLevel,

  /// Collection **imbriquée sous un parent** :
  /// `[users/{userId}/]{parentCollection}/{parentId}/{collection}`. Exige un
  /// `parentId` à la résolution.
  nestedUnderParent,

  /// Collection **globale top-level** (ex. `study_share_links`) — **hors** de
  /// tout scope `users/{uid}`.
  globalTopLevel,
}

/// Règle de résolution **littérale et immuable** d'un `kind` de collection.
///
/// Chaque champ est un **segment littéral déclaré** (jamais dérivé par
/// réflexion). Instanciable `const` : une table de topologie est une constante de
/// bootstrap.
class ZFirestorePathRule {
  const ZFirestorePathRule._(
    this.topology,
    this.collection, {
    this.parentCollection,
    this.userScoped = false,
    this.userSegment = 'users',
  });

  /// Collection **flat top-level** [collection]. Si [userScoped] est `true`, elle
  /// est préfixée par `{userSegment}/{userId}` (un `userId` devient alors requis).
  const ZFirestorePathRule.flatTopLevel({
    required String collection,
    bool userScoped = false,
    String userSegment = 'users',
  }) : this._(
          ZFirestoreTopology.flatTopLevel,
          collection,
          userScoped: userScoped,
          userSegment: userSegment,
        );

  /// Collection [collection] **imbriquée** sous `{parentCollection}/{parentId}`,
  /// elle-même optionnellement sous `{userSegment}/{userId}` ([userScoped],
  /// défaut `true` — topologie imbriquée usuelle). Un `parentId` est **requis**
  /// à la résolution.
  const ZFirestorePathRule.nestedUnderParent({
    required String collection,
    required String parentCollection,
    bool userScoped = true,
    String userSegment = 'users',
  }) : this._(
          ZFirestoreTopology.nestedUnderParent,
          collection,
          parentCollection: parentCollection,
          userScoped: userScoped,
          userSegment: userSegment,
        );

  /// Collection **globale** [collection] top-level, **hors** de tout `users/{uid}`.
  const ZFirestorePathRule.globalTopLevel({required String collection})
      : this._(ZFirestoreTopology.globalTopLevel, collection);

  /// Forme topologique.
  final ZFirestoreTopology topology;

  /// Segment **littéral** de la collection cible (ex. `'flashcards'`).
  final String collection;

  /// Segment **littéral** de la collection parente (topologie `nestedUnderParent`
  /// uniquement, ex. `'study_folders'`), sinon `null`.
  final String? parentCollection;

  /// `true` si le chemin est préfixé par `{userSegment}/{userId}` (un `userId`
  /// devient alors requis à la résolution).
  final bool userScoped;

  /// Segment de scope utilisateur (défaut `'users'`).
  final String userSegment;
}

/// Résolveur **immuable** de chemins Firestore par `kind`, à partir d'une **table
/// de topologie littérale** injectée à la construction.
///
/// **Backend-agnostique (AD-5/AD-11)** : ni entrée ni sortie n'expose un
/// type `cloud_firestore` ; la sortie est un chemin `String` (ou un
/// `Left(ZDomainFailure)` explicite). **Anti-réflexion** : aucune méthode ne
/// prend un `Type`/générique `T` ni n'appelle `.toString()`/`runtimeType` pour
/// dériver un segment — chaque segment provient d'une [ZFirestorePathRule]
/// littérale.
class ZFirestorePathResolver {
  /// Construit le résolveur depuis une table `kind → règle` (copiée
  /// défensivement : la table interne est **non modifiable**).
  ZFirestorePathResolver(Map<String, ZFirestorePathRule> rules)
      : _rules = Map<String, ZFirestorePathRule>.unmodifiable(rules);

  final Map<String, ZFirestorePathRule> _rules;

  /// Les `kind` déclarés dans la table de topologie.
  Iterable<String> get kinds => _rules.keys;

  /// **Topologie déclarée** du [kind], point d'extension public —
  /// ou un `Left(ZDomainFailure)` explicite si [kind] est inconnu.
  ///
  /// Sert au `ZFirestoreCascadeBatcher` à **choisir sa stratégie
  /// d'énumération** sans coder aucun chemin : `nestedUnderParent` ⇒ tous les
  /// docs de la sous-collection sont enfants ; `flatTopLevel`/`globalTopLevel` ⇒
  /// filtrer par la FK déclarée sur l'arête (`where(childParentRef == parentId)`).
  /// La table de topologie littérale reste **l'unique source** de la différence
  /// flat↔nested (aucun `runtimeType`/`.toString()`).
  ZResult<ZFirestoreTopology> topologyOf(String kind) {
    final rule = _rules[kind];
    if (rule == null) {
      return Left<ZFailure, ZFirestoreTopology>(
        ZDomainFailure(
          'ZFirestorePathResolver : aucune règle de topologie déclarée pour '
          'kind="$kind" (topologies connues : ${_rules.keys.join(', ')}).',
        ),
      );
    }
    return Right<ZFailure, ZFirestoreTopology>(rule.topology);
  }

  /// Résout le **chemin de collection** `String` du [kind] pour le contexte
  /// ([userId]/[parentId]) fourni, ou un `Left(ZDomainFailure)` **explicite** si :
  /// - [kind] n'est pas déclaré dans la table ;
  /// - la topologie est `nestedUnderParent` **sans** [parentId] ;
  /// - la règle est `userScoped` **sans** [userId].
  ZResult<String> resolveCollection({
    required String kind,
    String? userId,
    String? parentId,
  }) {
    final rule = _rules[kind];
    if (rule == null) {
      return Left<ZFailure, String>(
        ZDomainFailure(
          'ZFirestorePathResolver : aucune règle de topologie déclarée pour '
          'kind="$kind" (topologies connues : ${_rules.keys.join(', ')}).',
        ),
      );
    }

    final String? userPrefix;
    if (rule.userScoped) {
      if (userId == null || userId.isEmpty) {
        return Left<ZFailure, String>(
          ZDomainFailure(
            'ZFirestorePathResolver : la topologie user-scopée de kind="$kind" '
            'exige un userId non vide.',
          ),
        );
      }
      userPrefix = '${rule.userSegment}/$userId/';
    } else {
      userPrefix = '';
    }

    switch (rule.topology) {
      case ZFirestoreTopology.flatTopLevel:
        return Right<ZFailure, String>('$userPrefix${rule.collection}');
      case ZFirestoreTopology.globalTopLevel:
        // Globale : JAMAIS de scope users/{uid} (userScoped ignoré par
        // construction — le constructeur globalTopLevel ne l'expose pas).
        return Right<ZFailure, String>(rule.collection);
      case ZFirestoreTopology.nestedUnderParent:
        if (parentId == null || parentId.isEmpty) {
          return Left<ZFailure, String>(
            ZDomainFailure(
              'ZFirestorePathResolver : la topologie nested de kind="$kind" '
              'exige un parentId non vide.',
            ),
          );
        }
        return Right<ZFailure, String>(
          '$userPrefix${rule.parentCollection}/$parentId/${rule.collection}',
        );
    }
  }

  /// Résout le chemin de la **collection PARENTE** d'un `kind` *nested*
  /// (ex. `users/{uid}/study_folders`).
  ///
  /// Rend un hôte capable d'**énumérer les parents existants** au lieu de devoir
  /// les deviner. Sans cela, un repository folder-scopé est figé sur un unique
  /// `parentId`, et un appareil **neuf** (réinstallation, logout/login) n'a
  /// aucune source de découverte : store local vide ⇒ aucun dossier connu ⇒
  /// `sync()` ne parcourt rien ⇒ **succès silencieux, zéro donnée**.
  ///
  /// **Reste PUR** (AD-5) : rend un chemin `String`, n'interroge rien. C'est
  /// `ZOfflineFirstBoxRepository.listParentIds()` qui exécute la requête.
  ///
  /// `Left(ZDomainFailure)` si le `kind` est inconnu, si la topologie **n'est pas**
  /// nested (un `flat`/`global` n'a pas de parent), ou si le scope utilisateur
  /// exige un `userId` absent.
  ZResult<String> resolveParentCollection({
    required String kind,
    String? userId,
  }) {
    final rule = _rules[kind];
    if (rule == null) {
      return Left<ZFailure, String>(
        ZDomainFailure(
          'ZFirestorePathResolver : aucune règle de topologie déclarée pour '
          'kind="$kind" (topologies connues : ${_rules.keys.join(', ')}).',
        ),
      );
    }
    if (rule.topology != ZFirestoreTopology.nestedUnderParent) {
      return Left<ZFailure, String>(
        ZDomainFailure(
          'ZFirestorePathResolver : kind="$kind" n\'est pas une topologie '
          'nested — il n\'a pas de collection parente à énumérer.',
        ),
      );
    }
    if (rule.userScoped) {
      if (userId == null || userId.isEmpty) {
        return Left<ZFailure, String>(
          ZDomainFailure(
            'ZFirestorePathResolver : la topologie user-scopée de kind="$kind" '
            'exige un userId non vide.',
          ),
        );
      }
      return Right<ZFailure, String>(
        '${rule.userSegment}/$userId/${rule.parentCollection}',
      );
    }
    return Right<ZFailure, String>('${rule.parentCollection}');
  }

  /// Résout le **chemin de document** `String` (`<collection>/<id>`) du [kind],
  /// ou propage le `Left` de [resolveCollection].
  ZResult<String> resolveDoc({
    required String kind,
    required String id,
    String? userId,
    String? parentId,
  }) =>
      resolveCollection(kind: kind, userId: userId, parentId: parentId)
          .map((collection) => '$collection/$id');
}
