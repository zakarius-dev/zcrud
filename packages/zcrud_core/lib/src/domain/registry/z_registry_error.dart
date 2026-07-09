/// Erreurs de **configuration/bootstrap** des registres d'extensibilité (AD-3).
///
/// origine: lex_core (module « Étude ») — patron « registre ouvert » (canonique
/// §4 pt.3, §8.6). Ces erreurs matérialisent la **frontière de décodage de
/// MODÈLE** d'AD-3 : un `kind` non enregistré (ou doublonné) est un **défaut
/// programmatique** (l'app a oublié `register`, ou l'ordre d'init est faux),
/// PAS une donnée corrompue.
///
/// **Deux régimes d'erreur — ne pas confondre (Dev Notes E2-3) :**
/// - Config/bootstrap (ici) → sous-types de [Error] Dart, **non récupérables**,
///   **jamais** enveloppés dans un `Either`/`ZFailure`.
/// - Parsing de donnée (AD-10) → `fromJsonSafe → null`, **jamais** de throw.
///
/// À NE PAS confondre avec la hiérarchie `ZFailure` (échec **métier**
/// récupérable, `Either.Left`) : voir `failures/z_failure.dart`.
library;

/// Levée quand un `kind` demandé n'est **enregistré dans aucun** registre
/// (`ZcrudRegistry`, `ZTypeRegistry`, `ZSourceRegistry`).
///
/// Sous-type de [Error] (comme `StateError`/`ArgumentError`) : signale un
/// **bug de configuration** (enregistrement manquant ou ordre de bootstrap
/// fautif), non un flux métier récupérable. **Jamais** `fold`é dans un
/// `Either` (AD-3 — « échoue explicitement, jamais par cast null silencieux »).
class ZUnregisteredTypeError extends Error {
  /// Construit l'erreur pour le [kind] introuvable dans [registryName].
  ZUnregisteredTypeError({required this.kind, required this.registryName});

  /// Discriminant demandé mais absent du registre.
  final String kind;

  /// Nom logique du registre concerné (pour un message actionnable).
  final String registryName;

  @override
  String toString() =>
      'ZUnregisteredTypeError: aucun type enregistré pour le kind "$kind" '
      'dans le registre "$registryName". Vérifiez que l\'enregistrement '
      '(register("$kind", …)) est bien appelé au bootstrap, avant tout '
      'décodage (bug de configuration, AD-3).';
}

/// Levée quand un `kind` **déjà enregistré** est ré-enregistré sur le même
/// registre (collision).
///
/// Sous-type de [Error]. **Décision (E2-3, Dev Notes #4)** : on `throw` plutôt
/// qu'un remplacement silencieux « last-wins ». Un last-wins masquerait une
/// **double génération** (deux `part` codegen enregistrant le même modèle) ou
/// un **ordre de bootstrap** fautif — exactement le genre de bug qu'AD-3 veut
/// rendre explicite. Un besoin d'override légitime (hot-reload/tests) sera
/// ajouté **additivement** (paramètre `override: true`), sans changer ce défaut.
class ZDuplicateRegistrationError extends Error {
  /// Construit l'erreur pour le [kind] déjà présent dans [registryName].
  ZDuplicateRegistrationError({required this.kind, required this.registryName});

  /// Discriminant enregistré une seconde fois (collision).
  final String kind;

  /// Nom logique du registre concerné (pour un message actionnable).
  final String registryName;

  @override
  String toString() =>
      'ZDuplicateRegistrationError: le kind "$kind" est déjà enregistré dans '
      'le registre "$registryName". Enregistrement en double (double codegen '
      'ou bootstrap répété) — refusé au lieu d\'un « last-wins » silencieux '
      '(AD-3).';
}
