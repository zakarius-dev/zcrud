/// `ZRelationSource` — **port neutre** d'une source d'options dynamique pour le
/// champ **relation** (DODLP `crudDataSelect`, gap B7) + son registre
/// instanciable `ZRelationSourceRegistry` (AD-4).
///
/// origine: `loadRessourcesStream(editionState)` DODLP (`models.dart:1045-1055`)
/// — un flux live d'entités liées issu d'un repository, filtré par
/// `ressourceFilter(editionState, item)` (`models.dart:596`). Ici le mécanisme
/// est **généralisé en port pur** : le cœur ne connaît NI le repository, NI
/// Firestore/Hive, NI SmartSelect — seulement une **abstraction** émettant des
/// `ZFieldChoice{value,label}` déjà mappés.
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1/AD-5)** : ce fichier est **pur-Dart**
/// (`dart:async` autorisé, AUCUN import Flutter/`cloud_firestore`/Hive/gestionnaire
/// d'état). **Aucune implémentation concrète ne vit dans le cœur** : l'app/le
/// binding (`zcrud_firestore`, app DODLP E7) implémente `ZRelationSource` sur son
/// backend (mapping entité→`ZFieldChoice` + filtre métier inclus) et l'enregistre
/// au runtime via `ZcrudScope(relationSourceRegistry: registry)`. Le cœur ne
/// fournit AUCUNE impl (comme `CloudStorageRepository`/`ZListRenderer`).
///
/// **Filtre cross-champ** : `options(filterContext)` reçoit un `Map<String,
/// Object?>` = **snapshot des valeurs** des champs déclarés par
/// `ZRelationConfig.filterKeys` (les « autres champs » de l'`editionState` DODLP).
/// La source filtre en interne (équivalent `ressourceFilter`). `filterKeys` vide
/// ⇒ `filterContext` vide ⇒ aucun filtre cross-champ. Le cœur ne présume AUCUNE
/// sémantique de filtre (neutralité totale).
///
/// **Hors périmètre (déféré au binding)** :
/// - **CRUD inline** (`showCrudButton`/`crudRepository` DODLP) : voie d'écriture
///   repository → binding + story de suivi (DP-12+), jamais ici.
/// - **`s2ChoiceDisabled`** (prédicat de désactivation par option, closure
///   runtime) : contournement = la source **n'émet pas** les options non
///   sélectionnables (elle filtre en amont).
library;

import 'dart:async';

import '../edition/z_field_choice.dart';
import '../registry/z_registry_error.dart';

/// Port **abstrait** (neutre) d'une source d'options dynamique pour un champ
/// `relation`. Aucune impl concrète dans `zcrud_core` (binding/app).
///
/// Contrat (AD-5) : `options(filterContext)` retourne un **`Stream<List<T>>`
/// nu** (jamais enveloppé dans un `Either`) émettant la liste live des options
/// `{value,label}` déjà mappées. L'émission est **défensive côté consommateur**
/// (AD-10) : le widget capture `onError`/vide sans jamais propager d'exception.
abstract class ZRelationSource {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZRelationSource();

  /// Flux **live** des options `{value,label}` filtrées par [filterContext].
  ///
  /// [filterContext] = snapshot des valeurs des champs `ZRelationConfig.filterKeys`
  /// (clé de champ → valeur courante). La source filtre en interne (équivalent
  /// `ressourceFilter(editionState, item)`). Repli attendu : un flux vide/`[]`
  /// plutôt qu'une erreur quand il n'y a rien (jamais de crash — AD-10).
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext);
}

/// Registre **instanciable** de sources de relation, discriminées par une clé
/// `String` (portée par `ZRelationConfig.sourceKey`). Injecté via
/// `ZcrudScope.relationSourceRegistry` (AD-4 — **jamais** un singleton statique
/// mutable).
///
/// API alignée sur `ZWidgetRegistry`/`ZOpenRegistry` (register/isRegistered/keys
/// + lookup strict/défensif) : `sourceFor` **throw** [ZUnregisteredTypeError] si
/// absent (bug de configuration, AD-3) ; `trySourceFor` retourne `null` (chemin
/// défensif utilisé par le dispatcher pour retomber sur le repli statique, AD-10).
///
/// **Pur-Dart** (couche `domain`) : un registre de sources n'a besoin QUE de
/// `ZRelationSource` (pur) — aucune dépendance Flutter, contrairement à
/// `ZWidgetRegistry` (widgets → `presentation`).
class ZRelationSourceRegistry {
  /// Construit un registre de sources vide.
  ZRelationSourceRegistry();

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZRelationSourceRegistry';

  final Map<String, ZRelationSource> _sources = <String, ZRelationSource>{};

  /// Enregistre la [source] sous [key]. Collision → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux, AD-3).
  void register(String key, ZRelationSource source) {
    if (_sources.containsKey(key)) {
      throw ZDuplicateRegistrationError(kind: key, registryName: _name);
    }
    _sources[key] = source;
  }

  /// `true` si une source est enregistrée pour [key].
  bool isRegistered(String key) => _sources.containsKey(key);

  /// Les clés actuellement enregistrées.
  Iterable<String> get keys => _sources.keys;

  /// Lookup **strict** : la source de [key], ou **`throw`**
  /// [ZUnregisteredTypeError] si absente (AD-3).
  ZRelationSource sourceFor(String key) {
    final source = _sources[key];
    if (source == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return source;
  }

  /// Lookup **défensif** : la source de [key], ou `null` si absente (AD-10) —
  /// utilisé par le dispatcher pour retomber sur le repli statique (dropdown).
  ZRelationSource? trySourceFor(String key) => _sources[key];
}
