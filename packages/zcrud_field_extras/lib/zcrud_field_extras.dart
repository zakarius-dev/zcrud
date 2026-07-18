/// Barrel d'API publique de `zcrud_field_extras` — satellite CHAMPS SPÉCIALISÉS
/// (fp-1-2, AD-53).
///
/// **Squelette de substrat** : coquille conforme (pubspec + arbre
/// `lib/src/{domain,data,presentation}` + garde de confinement) posée AVANT
/// l'écriture des adaptateurs (Finitions) — champs PIN / autocomplete / table
/// éditable / icon servis par `ZWidgetRegistry`. Il n'expose encore que
/// [kZcrudFieldExtrasPlaceholder].
///
/// **Isolation (AD-53)** : aucune dépendance (`pinput` / …) ; elles arriveront
/// aux Finitions, confinées à `lib/src/`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_field_extras_placeholder.dart'
    show kZcrudFieldExtrasPlaceholder;
