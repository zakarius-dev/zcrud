/// Container **générique interne** partagé des registres d'extensibilité (AD-4).
///
/// Factorise register/lookup/erreurs pour ne pas tripler le code entre
/// `ZcrudRegistry`, `ZTypeRegistry` et `ZSourceRegistry` — trois registres qui
/// suivent le même patron « registre ouvert ».
///
/// **`ZCodecRegistry<T>` est un générique de CONTENEUR** (comme `ZRepository<T>`
/// ou `Map<K,V>`), **PAS** un generic de **sérialisation** : `T` est le type de
/// l'entrée *stockée* (un codec/couple de fonctions), jamais un mécanisme
/// (dé)sérialisant via le paramètre de type. AD-4 rejette les generics **comme
/// mécanisme de sérialisation** ; ce conteneur ne l'est pas.
///
/// **Thread-safety** : non requise. Dart est mono-thread par isolate (aucune
/// mémoire partagée concurrente) et l'enregistrement se fait en phase de
/// bootstrap séquentielle — aucun verrou (pas de `synchronized`).
library;

import 'z_registry_error.dart';

/// Registre générique `String kind → T` (entrée = un codec ou couple de
/// fonctions). Instanciable et **isolé** : deux instances ne partagent aucun
/// état, ce qui isole une app d'une autre et un test du suivant.
class ZCodecRegistry<T extends Object> {
  /// Construit un registre vide identifié par [registryName] (utilisé dans les
  /// messages d'erreur actionnables).
  ZCodecRegistry(this.registryName);

  /// Nom logique du registre (propagé dans [ZUnregisteredTypeError] /
  /// [ZDuplicateRegistrationError]).
  final String registryName;

  final Map<String, T> _entries = <String, T>{};

  /// Enregistre [value] sous [kind].
  ///
  /// Collision → **`throw [ZDuplicateRegistrationError]`** (jamais un
  /// remplacement silencieux « last-wins », AD-3 / Dev Notes #4).
  void register(String kind, T value) {
    if (_entries.containsKey(kind)) {
      throw ZDuplicateRegistrationError(kind: kind, registryName: registryName);
    }
    _entries[kind] = value;
  }

  /// `true` si [kind] est enregistré.
  bool isRegistered(String kind) => _entries.containsKey(kind);

  /// Lookup **strict** : retourne l'entrée de [kind], ou
  /// **`throw [ZUnregisteredTypeError]`** si absent (frontière modèle, AD-3).
  T entryFor(String kind) {
    final entry = _entries[kind];
    if (entry == null) {
      throw ZUnregisteredTypeError(kind: kind, registryName: registryName);
    }
    return entry;
  }

  /// Lookup **défensif** : retourne l'entrée de [kind], ou `null` si absent
  /// (échappatoire pour un appelant tolérant, AD-10).
  T? tryEntryFor(String kind) => _entries[kind];

  /// Les `kind` actuellement enregistrés (ordre d'insertion).
  Iterable<String> get kinds => _entries.keys;
}
