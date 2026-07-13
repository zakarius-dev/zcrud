/// Ergonomie typée `ZFlashcardType` sur `ZStudySessionConfig` (Story ES-1.1,
/// AC6) — restituée **côté `zcrud_flashcard`**.
///
/// Le noyau `zcrud_study_kernel` neutralise `ZStudySessionConfig.types` en
/// `List<String>?` (clés opaques camelCase) pour préserver l'acyclicité (AD-1)
/// et bannir `ZFlashcardType` du noyau (AD-17). Cette extension rend l'API typée
/// aux consommateurs flashcard **sans** modifier le wire ni le noyau :
/// - [flashcardTypes] : lit `types` et le mappe vers `List<ZFlashcardType>` en
///   **ignorant défensivement** toute clé inconnue (AD-10) — l'ancien
///   comportement de drop d'enum inconnu (E9) vit désormais ici ;
/// - [withFlashcardTypes] : écrit `types` depuis une `List<ZFlashcardType>?`
///   (mappée vers les `name` camelCase), ou `null` (pas de filtre).
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_flashcard_type.dart';

/// Adaptateur typé `ZFlashcardType` pour `ZStudySessionConfig` (AC6).
extension ZStudySessionConfigFlashcardX on ZStudySessionConfig {
  /// Types filtrants **typés** : `types` mappé en `ZFlashcardType`, clés
  /// inconnues **ignorées** (drop défensif AD-10). Retourne `null` si `types`
  /// est `null` (pas de filtre), sinon une liste (éventuellement vide).
  List<ZFlashcardType>? get flashcardTypes {
    final raw = types;
    if (raw == null) return null;
    return <ZFlashcardType>[
      for (final key in raw)
        if (_flashcardTypeFromName(key) case final t?) t,
    ];
  }

  /// Copie la config avec `types` dérivé de [typed] (mappé vers les `name`
  /// camelCase), ou `null` pour retirer le filtre.
  ZStudySessionConfig withFlashcardTypes(List<ZFlashcardType>? typed) =>
      copyWith(
        types: typed?.map((t) => t.name).toList(),
      );
}

/// Résout un [ZFlashcardType] depuis son `name` camelCase, ou `null` si inconnu.
ZFlashcardType? _flashcardTypeFromName(String name) {
  for (final t in ZFlashcardType.values) {
    if (t.name == name) return t;
  }
  return null;
}
