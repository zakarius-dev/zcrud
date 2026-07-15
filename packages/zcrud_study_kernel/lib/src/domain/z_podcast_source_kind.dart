/// Nature de la **source d'étude** d'un podcast généré (ES-2.8, FR-S11).
///
/// origine: lex_core (module « Étude ») — `enums/podcast_source_kind.dart`
/// `PodcastSourceKind {note, folder, document}` (fallback défensif `note`,
/// `fromJson → note`). Forme canonique retenue à l'identique.
///
/// 🔴 **L'ORDRE DE DÉCLARATION EST NORMATIF** (D3) : le générateur `zcrud` décode
/// un enum **par NOM** (`_$enumFromName`) et, pour un champ **non-nullable sans
/// `defaultValue`**, son repli défensif (AD-10) est **`T.values.first`**. **La
/// première constante déclarée EST donc le défaut** d'une valeur absente / `null`
/// / non-`String` / inconnue. Réordonner cet enum changerait **silencieusement**
/// le comportement défensif de `ZStudyPodcast.sourceKind` — un test l'épingle.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto (NFR-S3/NFR-S10/SM-S5).
library;

/// Type de source à partir de laquelle un podcast est synthétisé.
enum ZPodcastSourceKind {
  /// Note intelligente (**défaut défensif** — 1ʳᵉ constante, D3 ; parité lex).
  note,

  /// Dossier d'étude entier.
  folder,

  /// Document (PDF / support).
  document,
}
