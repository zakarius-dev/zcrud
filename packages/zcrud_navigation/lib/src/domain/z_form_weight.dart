/// Poids d'un **formulaire d'édition** — enum PUR de domaine.
///
/// [ZFormWeight] qualifie la « lourdeur » d'un formulaire (nombre/richesse des
/// champs). C'est le critère qui départage, sur **grand écran** (`expanded`), un
/// mode `dialog` d'un mode `page` (cf. [ZPresentationPolicy]). C'est un **enum**
/// — **jamais** un `bool isHeavy`/`isLong` : un booléen se prêterait mal à un
/// futur palier intermédiaire.
///
/// **Domaine pur (invariants AD-5/AD-14)** : aucun `import 'package:flutter/...'`,
/// aucun `BuildContext`.
library;

/// Poids d'un formulaire d'édition (valeurs **camelCase**).
enum ZFormWeight {
  /// Formulaire **court** (peu de champs) — se présente confortablement en
  /// `dialog` modale, même sur grand écran. **C'est le défaut** de
  /// `ZPresentationPolicy.resolve` (le cas courant).
  light,

  /// Formulaire **long / riche** — mérite une `page` pleine sur grand écran
  /// (`expanded`) plutôt qu'une dialog à l'étroit.
  heavy,
}
