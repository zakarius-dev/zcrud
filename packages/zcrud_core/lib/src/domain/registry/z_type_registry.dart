/// Registre **ouvert** des types de champ/valeur (AD-4 pt.3).
///
/// origine: lex_core (module « Étude ») — patron « registre ouvert »
/// (canonique §4 pt.3). **Consommé par E3-3b** : les familles de champ dont le
/// widget/codec vit **hors du cœur** (markdown → E6, géo/tél → E11a) sont
/// servies via [ZTypeRegistry.register] par l'app hôte, sans forker `zcrud_core`.
///
/// Espace de noms **distinct** de [ZSourceRegistry] (Dev Notes #3, OQ-6 « par
/// axe ») : un `kind` de type de champ n'entre pas en collision avec un `kind`
/// de provenance.
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
