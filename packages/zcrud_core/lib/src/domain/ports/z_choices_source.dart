/// `ZChoicesSource` — **port neutre** d'une source d'options **calculées** pour un
/// champ `select` (DP-15/M22, parité `choiceItemsRepository`/`choicesBuilder`
/// DODLP) + son registre instanciable `ZChoicesSourceRegistry` (AD-4).
///
/// origine: le besoin DODLP de choix **recalculés arbitrairement** (au-delà de la
/// simple lecture cross-champ `stateChoiceItems`, couverte par
/// `ZSelectConfig.choicesFromKey`). Ici le mécanisme est **généralisé en port
/// pur** : le cœur ne connaît NI le calcul métier, NI un repository, NI
/// SmartSelect — seulement une **abstraction synchrone** retournant des
/// `ZFieldChoice{value,label}` déjà mappés.
///
/// **Différence clé avec `ZRelationSource` (DP-5)** : `options(...)` est
/// **SYNCHRONE** (`List<ZFieldChoice>`), pas un `Stream`. Un `select` recalcule
/// ses choix **à la lecture** depuis un snapshot de contexte cross-champ ; il n'a
/// pas de flux repository live (contrairement à `relation`).
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1/AD-5)** : ce fichier est **pur-Dart**
/// (AUCUN import Flutter/`cloud_firestore`/Hive/gestionnaire d'état). **Aucune
/// implémentation concrète ne vit dans le cœur** : l'app/le binding implémente
/// `ZChoicesSource` (calcul métier des options depuis l'état) et l'enregistre au
/// runtime via `ZcrudScope(choicesSourceRegistry: registry)`.
///
/// **Filtre cross-champ** : `options(filterContext)` reçoit un `Map<String,
/// Object?>` = **snapshot des valeurs** des champs déclarés par
/// `ZSelectConfig.filterKeys`. La source calcule en interne. `filterKeys` vide ⇒
/// `filterContext` vide ⇒ calcul non filtré. Le cœur ne présume AUCUNE sémantique
/// (neutralité totale).
library;

import '../edition/z_field_choice.dart';
import '../registry/z_registry_error.dart';

/// Port **abstrait** (neutre) d'une source d'options **calculées** pour un champ
/// `select`. Aucune impl concrète dans `zcrud_core` (binding/app).
///
/// Contrat (AD-5) : `options(filterContext)` retourne une **`List<ZFieldChoice>`
/// nue** (jamais enveloppée dans un `Either`) — la liste des options
/// `{value,label}` déjà mappées pour le contexte donné. Repli attendu : une liste
/// vide plutôt qu'une erreur (jamais de crash — AD-10 ; le dispatcher capture
/// défensivement une éventuelle exception et retombe sur le repli statique).
abstract class ZChoicesSource {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZChoicesSource();

  /// Options `{value,label}` **calculées** pour le [filterContext].
  ///
  /// [filterContext] = snapshot des valeurs des champs `ZSelectConfig.filterKeys`
  /// (clé de champ → valeur courante). La source calcule en interne. Repli
  /// attendu : une liste vide plutôt qu'une exception (AD-10).
  List<ZFieldChoice> options(Map<String, Object?> filterContext);
}

/// Registre **instanciable** de sources de choix, discriminées par une clé
/// `String` (portée par `ZSelectConfig.choicesSourceKey`). Injecté via
/// `ZcrudScope.choicesSourceRegistry` (AD-4 — **jamais** un singleton statique
/// mutable).
///
/// API alignée sur `ZRelationSourceRegistry`/`ZWidgetRegistry`
/// (register/isRegistered/keys + lookup strict/défensif) : `sourceFor` **throw**
/// [ZUnregisteredTypeError] si absent (bug de configuration, AD-3) ;
/// `trySourceFor` retourne `null` (chemin défensif du dispatcher pour retomber
/// sur `choicesFromKey`/`field.choices`, AD-10).
///
/// **Pur-Dart** (couche `domain`) : un registre de sources n'a besoin QUE de
/// `ZChoicesSource` (pur) — aucune dépendance Flutter.
class ZChoicesSourceRegistry {
  /// Construit un registre de sources vide.
  ZChoicesSourceRegistry();

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZChoicesSourceRegistry';

  final Map<String, ZChoicesSource> _sources = <String, ZChoicesSource>{};

  /// Enregistre la [source] sous [key]. Collision → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux, AD-3).
  void register(String key, ZChoicesSource source) {
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
  ZChoicesSource sourceFor(String key) {
    final source = _sources[key];
    if (source == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return source;
  }

  /// Lookup **défensif** : la source de [key], ou `null` si absente (AD-10) —
  /// utilisé par le dispatcher pour retomber sur `choicesFromKey`/`field.choices`.
  ZChoicesSource? trySourceFor(String key) => _sources[key];
}
