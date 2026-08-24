/// `ZNumberDisplayFormatter` — **port neutre** de FORMATAGE D'AFFICHAGE d'un
/// nombre.
///
/// ## Le défaut fermé ici
///
/// Une valeur numérique est stockée telle quelle (`num`). Sans ce port, toutes
/// les voies de LECTURE du paquet la rendent par `'$value'` — `12.0` s'affiche
/// « 12.0 », `0.30000000000000004` s'affiche brut. La donnée est bonne ; seule
/// sa **projection** manque.
///
/// ## Pourquoi un port et pas un formatage en dur
///
/// Un rendu localisé de nombre (groupement des milliers, séparateur décimal,
/// précision) exige `package:intl` — le cœur n'en dépend jamais (invariant
/// AD-1) et n'invente **aucun format par défaut** (invariant FR-26). Le cœur
/// pose donc le **seam** ; l'implémentation localisée vit hors du cœur et est
/// injectée par `ZcrudScope(numberDisplayFormatter: …)`.
///
/// ## Repli DÉFINI (AD-10) — l'hôte passif ne bouge pas
///
/// Le repli est **la chaîne brute déjà rendue aujourd'hui** (`'$value'`), dans
/// **tous** les chemins dégradés :
/// - aucun port injecté ;
/// - valeur non numérique (`null`, chaîne libre, autre type) ;
/// - port qui retourne `null` (« je ne sais pas rendre cette valeur ») ou une
///   chaîne vide ;
/// - port qui **lève** (jamais d'exception propagée dans un `build`).
///
/// ⇒ **Le formatage est visible UNIQUEMENT pour l'hôte qui injecte le port.**
///
/// ## Portée
///
/// Le port formate le **nombre nu**. Les suffixes neutres déclarés par
/// `ZNumberConfig` (`%`, symbole monétaire) restent apposés par la voie de
/// lecture APRÈS ce formatage — le port n'a pas à les connaître.
library;

/// Port **abstrait** (neutre) de formatage d'affichage d'un nombre.
///
/// Contrat (AD-10) : [format] retourne la représentation lisible de [value], ou
/// `null` pour **déléguer au repli défini du socle** (la chaîne brute). Une
/// impl ne doit pas lever ; si elle lève, le socle replie de la même façon.
abstract class ZNumberDisplayFormatter {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZNumberDisplayFormatter();

  /// Rend [value] pour l'affichage.
  ///
  /// [localeTag] est la BCP-47 de la locale ambiante (`fr-FR`, `en`), ou `null`
  /// si l'arbre n'en porte pas — l'impl choisit alors sa locale par défaut.
  ///
  /// Retourner `null` (ou une chaîne vide) ⇒ repli du socle (chaîne brute).
  String? format(num value, {String? localeTag});
}

/// Applique le port [formatter] à [value] et **replie sur la chaîne brute**
/// dans tous les chemins dégradés (cf. dartdoc de bibliothèque, AD-10).
///
/// **Source UNIQUE de la règle de repli** — pur-Dart, sans `BuildContext` :
/// partagée entre la fiche de lecture et le résumé de sous-liste (qui lisent le
/// port dans le `ZcrudScope`), et réutilisable par une voie headless qui reçoit
/// le port déjà capturé. Aucune voie ne possède sa propre copie du repli.
///
/// [formatter] `null` ⇒ chaîne brute (hôte passif strictement immobile). Une
/// valeur non-`num` qui se parse en nombre (`'12.5'`) est routée vers le port ;
/// tout le reste rend `'$value'`.
String zNumberDisplayTextOf(
  ZNumberDisplayFormatter? formatter,
  Object? value, {
  String? localeTag,
}) {
  final raw = '$value';
  if (formatter == null) return raw;
  final num? n = value is num ? value : num.tryParse(raw.trim());
  if (n == null) return raw;
  try {
    final formatted = formatter.format(n, localeTag: localeTag);
    if (formatted == null || formatted.isEmpty) return raw;
    return formatted;
  } catch (_) {
    // AD-10 : un port hôte qui lève ne fait jamais échouer un `build`.
    return raw;
  }
}
