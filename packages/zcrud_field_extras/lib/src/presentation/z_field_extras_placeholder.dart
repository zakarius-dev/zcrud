/// Placeholder de PRÉSENTATION du satellite `zcrud_field_extras` (fp-1-2, AD-53).
///
/// 🔴 **Substrat, pas d'implémentation.** Matérialise la couche `presentation`
/// de l'hexagone en attendant les champs spécialisés (à écrire aux **Finitions**)
/// — PIN / autocomplete / table éditable / icon — servis par le `ZWidgetRegistry`
/// du cœur, avec des dépendances légères CONFINÉES à l'impl.
///
/// ⚠️ Aucune dépendance (`pinput` / …) n'est tirée à ce stade. Le confinement
/// est gardé par `test/z_field_extras_confinement_test.dart`.
library;

/// Marqueur de substrat du satellite `zcrud_field_extras`.
///
/// Remplacé par les adaptateurs de champs spécialisés aux Finitions (AD-53).
/// Donne au barrel un symbole réel à exporter tant qu'ils n'existent pas.
const String kZcrudFieldExtrasPlaceholder = 'zcrud_field_extras:substrat:fp-1-2';
