/// `ZFieldSize` — variante de **taille/layout** d'un champ d'édition (parité
/// DODLP, gap B1).
///
/// Miroir 1:1 de `FieldSize {normal, large}` DODLP
/// (`dodlp-otr/lib/modules/data_crud/models.dart:87-94`) :
/// - [normal] : rendu **inline** standard (décor `InputDecoration` classique) ;
/// - [large]  : rendu enveloppé dans une **Card** (label porté AU-DESSUS du
///   champ, champ interne « bare » sans bordure), piloté par les tokens
///   `ZcrudTheme` (`large*`) — cf. `ZLargeFieldCard`.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-1, garde
/// `domain_purity_test.dart`) : aucune dépendance Flutter. Valeurs en camelCase
/// (canonique §5).
library;

/// Variante de taille/layout d'un champ d'édition (`normal` par défaut, `large`
/// pour le rendu en Card — parité DODLP B1).
enum ZFieldSize {
  /// Rendu inline standard (défaut, comportement historique inchangé).
  normal,

  /// Rendu enveloppé en Card avec label au-dessus et champ interne « bare ».
  large,
}
