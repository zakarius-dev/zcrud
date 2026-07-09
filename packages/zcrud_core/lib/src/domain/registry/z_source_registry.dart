/// Registre **ouvert** de provenance (AD-4 pt.3).
///
/// origine: lex_core (module « Étude ») — `flashcard_source.dart:13`
/// (`FlashcardSource` : union `sealed` interne + variant `custom` + registre).
/// **Consommé par E9-1** : le variant « article » (douane) est branché par
/// l'app hôte via [ZSourceRegistry.register], sans forker le package flashcard
/// ni le cœur. La `sealed` interne du package flashcard reste `sealed` **en
/// interne** (exhaustivité) ; l'ouverture inter-package passe par ce registre —
/// deux usages distincts (E9).
///
/// Espace de noms **distinct** de [ZTypeRegistry] (Dev Notes #3, OQ-6 « par
/// axe »).
library;

import 'z_open_registry.dart';

/// Registre **instanciable** de provenance ouverte.
///
/// `register(kind, fromJson: …, toJson: …)`, `isRegistered`, `kinds`,
/// `codecFor` (strict → **throw**) et `tryCodecFor` (défensif → `null`) sont
/// hérités de [ZOpenRegistry]. Instance injectée via `ZcrudScope`/binding (pas
/// de singleton statique mutable — Dev Notes #2).
class ZSourceRegistry extends ZOpenRegistry {
  /// Construit un registre de provenance vide.
  ZSourceRegistry() : super('ZSourceRegistry');
}
