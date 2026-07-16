/// Tonalité d'une confirmation, modélisée par un **enum** (NFR-U7, AD-32).
///
/// `ZConfirmTone` remplace le `bool isDestructive` (ou la couleur ad hoc tirée
/// de constantes globales `kErrorColor*` / `kSuccessColor*`) que dodlp et iffd
/// passaient à leur `buildConfirmDialog`. L'enum nomme l'intention plutôt qu'un
/// flag binaire opaque et laisse le widget **dériver** la couleur du
/// `ColorScheme` courant — jamais un littéral hex.
///
/// Type **UI-pur, non persisté** (aucune (dé)sérialisation). Valeurs en
/// **camelCase**.
enum ZConfirmTone {
  /// Confirmation neutre : le bouton de confirmation utilise la teinte primaire
  /// par défaut du thème.
  neutral,

  /// Confirmation destructive (suppression, action irréversible) : le bouton de
  /// confirmation est teinté avec `ColorScheme.error` (dérivé, jamais hex).
  destructive,
}
