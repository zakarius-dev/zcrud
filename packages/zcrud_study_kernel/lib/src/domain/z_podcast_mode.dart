/// Mode de synthèse d'un podcast généré (ES-2.8, FR-S11).
///
/// origine: lex_core (module « Étude ») — `enums/podcast_mode.dart`
/// `PodcastMode {simple, dialogue}` (fallback défensif `simple`,
/// `fromJson → simple`, mode par défaut du contrat backend). Forme canonique
/// retenue à l'identique.
///
/// 🔴 **L'ORDRE DE DÉCLARATION EST NORMATIF** (D3) : le générateur `zcrud` décode
/// un enum **par NOM** et, pour un champ **non-nullable sans `defaultValue`**, son
/// repli défensif (AD-10) est **`T.values.first`**. **La première constante
/// déclarée EST donc le défaut** — réordonner cet enum changerait
/// **silencieusement** le comportement défensif de `ZStudyPodcast.mode` et le
/// suffixe de `ZStudyPodcast.buildId`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto (NFR-S3/NFR-S10/SM-S5).
library;

/// Mode de génération d'un podcast (voix unique vs dialogue).
enum ZPodcastMode {
  /// Narration à voix unique (**défaut défensif** — 1ʳᵉ constante, D3 ; parité lex).
  simple,

  /// Dialogue à deux voix.
  dialogue,
}
