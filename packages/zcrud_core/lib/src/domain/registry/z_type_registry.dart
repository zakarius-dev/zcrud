/// Registre **ouvert** des types de champ/valeur (AD-4 pt.3).
///
/// Les familles de champ dont le widget/codec vit **hors du cœur** (markdown,
/// géo/téléphone…) sont servies via [ZTypeRegistry.register] par l'app hôte,
/// sans forker `zcrud_core`.
///
/// Espace de noms **distinct** de [ZSourceRegistry] : un `kind` de type de
/// champ n'entre jamais en collision avec un `kind` de provenance.
library;

import 'z_open_registry.dart';

/// Registre **instanciable** des types de champ/valeur ouverts.
///
/// `register(kind, fromJson: …, toJson: …)`, `isRegistered`, `kinds`,
/// `codecFor` (strict → **throw**) et `tryCodecFor` (défensif → `null`) sont
/// hérités de [ZOpenRegistry]. Instance injectée via `ZcrudScope`/binding (pas
/// de singleton statique mutable — Dev Notes #2).
class ZTypeRegistry extends ZOpenRegistry {
  /// Construit un registre de types vide.
  ZTypeRegistry() : super('ZTypeRegistry');
}
