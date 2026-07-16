/// Sévérité d'un toast, modélisée par un **enum** (NFR-U7, AD-32).
///
/// `ZToastSeverity` remplace les trois méthodes ad hoc `showErrorToast` /
/// `showSuccessToast` / `showInfoToast` (dodlp `toast_service.dart`) et tout
/// `bool isError` / `String` de type libre : les variantes de notification sont
/// les **valeurs d'un enum nommé**, jamais un flag binaire opaque. Le widget de
/// présentation ([ZScaffoldMessengerToaster]) **dérive** la couleur du toast du
/// `ColorScheme` courant selon cette sévérité — jamais un littéral hex.
///
/// Type **UI-pur, non persisté** (aucune (dé)sérialisation, aucun `@JsonKey`,
/// aucun `*.g.dart`). Valeurs en **camelCase**. L'ordre `info → success →
/// warning → error` suit une sévérité croissante (informatif à titre de
/// documentation ; aucune logique ne dépend de l'`index`).
enum ZToastSeverity {
  /// Information neutre : couleur dérivée d'un rôle « primaire » du
  /// `ColorScheme` (accent sobre), icône informative.
  info,

  /// Succès d'une opération : couleur dérivée d'un rôle « tertiaire » du
  /// `ColorScheme`, icône de validation.
  success,

  /// Avertissement (non bloquant) : couleur dérivée d'un rôle « secondaire »
  /// du `ColorScheme`, icône d'alerte.
  warning,

  /// Erreur : couleur dérivée de `ZcrudTheme.errorColor` → repli
  /// `ColorScheme.error`, icône d'erreur.
  error,
}
