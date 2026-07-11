/// Hint de **format de persistance** d'un champ date/heure, déclaré par champ via
/// [ZcrudField.persistAs] et lu **statiquement** par le générateur E2-5
/// (`ConstantReader`, jamais `reflectable`).
///
/// **Enum pur-Dart, ZÉRO dépendance backend** (AD-5) : ce marqueur ne référence
/// **aucun** type `cloud_firestore` (`Timestamp` reste confiné à
/// `zcrud_firestore/lib/src/data`). Le générateur ne fait que projeter le hint
/// en une **métadonnée neutre** (`Set<String>` de clés persistées) ; c'est
/// l'adaptateur Firestore qui, seul, traduit ces clés en `Timestamp` natif.
///
/// **Parité DODLP (gap B14)** : DODLP persiste certains champs date en
/// `Timestamp` Firestore natif (`Timestamp.fromDate`) plutôt qu'en String
/// ISO-8601 (requêtes `orderBy`/plage temporelle, index, interop). Ce hint
/// permet à la migration DODLP → zcrud de **ne pas changer silencieusement** le
/// format sur disque de ces champs.
enum ZPersistAs {
  /// **Défaut** : le champ date est persisté en **String ISO-8601**
  /// (comportement historique de zcrud — `DateTime.toIso8601String()`).
  iso8601,

  /// Le champ date est persisté sur Firestore en **`Timestamp` natif** (via
  /// `Timestamp.fromDate` côté `zcrud_firestore`, décodé défensivement en
  /// bi-format `Timestamp`/String à la lecture). N'affecte **que** le chemin
  /// Firestore distant : le store local Hive et les métadonnées `ZSyncMeta`
  /// restent en ISO-8601 (AD-9).
  timestamp,
}
