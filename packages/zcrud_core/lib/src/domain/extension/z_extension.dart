/// Slot type additif **versionné** `ZExtension` (AD-4 pt.1, AD-10).
///
/// origine: lex_core (module « Étude ») — `node_context.dart:68`
/// (`HierarchyNode.ragContext → NodeContext{formatVersion, fromJsonSafe}`,
/// canonique §4 pt.1) : extension **riche, rétro-compatible**, versionnée
/// **indépendamment** du parent, parsée **défensivement** (repli `null`,
/// **jamais** de throw).
///
/// **Base `abstract` — jamais `sealed`** (AD-4 : extension **inter-package**) :
/// les satellites (E9/E10) et apps hôtes déclarent leurs sous-classes
/// concrètes sans forker le cœur. `ZExtension` n'impose **ni** `freezed` **ni**
/// `@JsonSerializable` (contrat pur-Dart).
library;

/// Contrat abstrait d'une **extension type additive versionnée** portée par une
/// entité canonique (via `ZExtensible`).
///
/// Chaque sous-classe concrète (en satellite) :
/// 1. porte un [formatVersion] **propre**, indépendant du schéma du parent
///    (évolution additive — AD-10) ;
/// 2. sérialise via [toJson] ;
/// 3. expose par **convention** un `static X? fromJsonSafe(json)` bâti sur
///    [guard], renvoyant `null` si `json` est `null`, corrompu, ou de
///    [formatVersion] non gérée — **jamais** de throw (AD-10).
abstract class ZExtension {
  /// Constructeur `const` (sous-classes immuables).
  const ZExtension();

  /// Version du **sous-schéma** de l'extension, indépendante de celle du parent.
  ///
  /// Sert au parsing défensif : un `fromJsonSafe` renvoie `null` pour une
  /// version non gérée plutôt que de propager une exception (AD-10).
  int get formatVersion;

  /// Sérialise l'extension vers sa map JSON (doit inclure [formatVersion]).
  Map<String, dynamic> toJson();

  /// Exécute [parse] et renvoie son résultat, ou `null` **sur TOUTE exception**
  /// (jamais de propagation) — brique défensive réutilisable des `fromJsonSafe`
  /// concrets (AD-10).
  ///
  /// Volontairement générique et sans clause `on` : une donnée historique,
  /// tronquée, ou de type inattendu doit toujours retomber sur `null`, le
  /// parent survivant à la désérialisation.
  static T? guard<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }
}
