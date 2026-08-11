/// Source de temps injectable pour la clé LWW `updated_at`.
///
/// ## Le défaut que cette couture atténue
///
/// Si la clé d'arbitrage du merge Last-Write-Wins (`updated_at`) est
/// estampillée **en dur** à `DateTime.now()`, elle dépend de l'horloge de
/// l'appareil qui écrit. Deux appareils aux horloges désynchronisées (dérive
/// batterie, NTP absent, appareil longtemps hors-ligne) produisent alors un
/// ordre d'arbitrage qui **ne reflète pas** l'ordre réel des écritures : la
/// version réellement la plus récente peut être **silencieusement perdue**.
///
/// `updated_at` est une clé réservée (`ZSyncMeta.reservedKeys`) que zcrud
/// strippe du corps métier : sa valeur vient exclusivement de l'horloge
/// injectée, jamais d'un champ que l'hôte écrirait — une « garde » côté
/// application ne peut donc rien corriger sans ce seam.
///
/// [ZClock] est le **levier** : un hôte capable de mesurer le décalage entre
/// son horloge et une autorité (offset serveur relevé à la connexion, NTP)
/// peut injecter une horloge **corrigée** — sans changer la sémantique
/// offline-first (la clé reste lisible localement, contrairement à un
/// `FieldValue.serverTimestamp()` qui exigerait un aller-retour serveur).
///
/// ⚠️ **Ce n'est PAS une autorité temporelle commune.** Sans horloge corrigée
/// injectée, le défaut de convergence subsiste : la couture rend le skew
/// **atténuable et TESTABLE**, elle ne l'élimine pas par elle-même. Le
/// remède complet (estampille serveur-autoritaire) est un choix d'architecture
/// distinct, qui échange la lisibilité locale immédiate de la clé LWW.
///
/// Contrat : **retourne toujours un instant UTC**. Le défaut
/// ([ZSystemClock.utc]) est `DateTime.now().toUtc()`.
typedef ZClock = DateTime Function();

/// Horloges prêtes à l'emploi.
abstract final class ZSystemClock {
  /// Horloge système en UTC — le comportement historique (défaut partout).
  static DateTime utc() => DateTime.now().toUtc();

  /// Horloge **fixe** (tests) : renvoie toujours [instant]. Rend le skew LWW
  /// reproductible dans un test — deux stores, deux horloges figées différentes.
  static ZClock fixed(DateTime instant) {
    final DateTime utc = instant.toUtc();
    return () => utc;
  }

  /// Horloge **décalée** d'[offset] par rapport au système — modèle d'un
  /// appareil dont l'horloge avance ou retarde, et aussi la forme d'une
  /// correction côté application (offset serveur mesuré).
  static ZClock offset(Duration offset) =>
      () => DateTime.now().toUtc().add(offset);
}
