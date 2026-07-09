/// Contrat de **slot d'extension** `ZExtensible` (AD-4).
///
/// origine: lex_core (module « Étude ») — patron « slots d'extension » :
/// composition d'un [ZExtension] typé versionné + échappatoire non typée
/// [extra] (`TariffDetails.metadata`, canonique §4 pt.2).
///
/// Point d'ancrage des « slots `extra` + `ZExtension?` » requis par E9-1. Mixé
/// **en plus** par les entités canoniques concrètes (E9/E10) — **jamais** dans
/// `ZEntity`, qui reste un contrat pur d'identité (E2-1).
library;

import 'z_extension.dart';

/// Mixin exposant les deux voies d'extension AD-4 sur une entité :
/// - [extension] : slot type additif **versionné** (`null` si absent) ;
/// - [extra] : échappatoire **non typée** (défaut `const {}` côté
///   implémentation), préservant des clés inconnues du cœur.
mixin ZExtensible {
  /// Extension type additive versionnée, ou `null` si l'entité n'en porte pas.
  ZExtension? get extension;

  /// Échappatoire non typée : paires arbitraires préservées telles quelles
  /// (round-trip), y compris des clés inconnues du cœur. L'implémentation
  /// fournit le défaut `const {}` (jamais `null`).
  Map<String, dynamic> get extra;
}

/// Lecture **typée défensive** d'une clé d'[extra] : renvoie la valeur si elle
/// est présente **et** du type `T` attendu, sinon `null` (jamais de throw,
/// AD-10). Commodité pour consommer l'échappatoire non typée sans cast risqué.
T? zExtraRead<T>(Map<String, dynamic> extra, String key) {
  final value = extra[key];
  return value is T ? value : null;
}
