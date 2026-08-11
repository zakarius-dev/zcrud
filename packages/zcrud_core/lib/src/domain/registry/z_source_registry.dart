/// Registre **ouvert** de provenance (AD-4 pt.3).
///
/// Permet à une app hôte de brancher une provenance additionnelle (par
/// exemple un variant de source de flashcard) via [ZSourceRegistry.register],
/// sans forker le paquet consommateur ni le cœur. Une union `sealed` interne
/// à un paquet peut rester `sealed` pour son exhaustivité locale : c'est ce
/// registre qui porte l'ouverture inter-paquet.
///
/// Espace de noms **distinct** de [ZTypeRegistry] : les deux registres ne
/// partagent pas leurs `kind`.
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
