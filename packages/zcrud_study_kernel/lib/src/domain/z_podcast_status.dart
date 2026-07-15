/// Cycle de vie d'un podcast généré (ES-2.8, FR-S11).
///
/// origine: lex_core (module « Étude ») — `enums/podcast_status.dart`
/// `PodcastStatus {pending, processing, ready, failed, stale}`, dont le
/// `fromJson` **défensif** retombe sur **`ready`**.
///
/// 🔴 **L'ORDRE DE DÉCLARATION EST NORMATIF** (D3) : le générateur `zcrud` décode
/// un enum **par NOM** (`_$enumFromName`) et, pour un champ **non-nullable sans
/// `defaultValue`**, son repli défensif (AD-10) est **`T.values.first`**. **La
/// première constante déclarée EST donc le défaut** d'une valeur absente / `null`
/// / non-`String` / inconnue.
///
/// ## ⚠️ [ready] en TÊTE — DIVERGE de l'ordre lex, PRÉSERVE sa sémantique de repli
///
/// lex déclare l'enum dans l'ordre `pending, processing, ready, …` mais fait
/// **replier `fromJson` sur `ready`**. Le générateur zcrud n'émet pas de `fromJson`
/// manuel : son repli EST la 1ʳᵉ constante. Pour préserver la sémantique lex
/// (**repli défensif = `ready`**) tout en restant piloté par l'ordre, [ready] est
/// donc déclaré **en PREMIER**. Rationale (comme le D5 de `ZDocumentStatus`, mais
/// fallback inversé) : **seul un podcast `ready` est persisté durablement**
/// (`failed`/`stale`/`pending`/`processing` sont transitoires) ⇒ toute valeur
/// inconnue/corrompue lue depuis le store est, par construction, une référence
/// *ready*. Replier sur `pending`/`processing` afficherait un spinner perpétuel ;
/// sur `failed` masquerait un podcast valide ; sur `stale` déclencherait une
/// régénération inutile ; **`ready` ne ment ni ne détruit rien** et colle à lex.
/// **Réordonner cet enum change SILENCIEUSEMENT le comportement défensif** — un
/// test l'épingle (`z_podcast_status_test.dart`).
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto (NFR-S3/NFR-S10/SM-S5).
library;

/// État du cycle de vie d'un [ZStudyPodcast] (généré → prêt / échec / obsolète).
enum ZPodcastStatus {
  /// Podcast prêt et écoutable (**défaut défensif** — 1ʳᵉ constante, D3 ;
  /// sémantique de repli lex `fromJson → ready`).
  ready,

  /// Génération demandée, en attente de traitement.
  pending,

  /// Génération en cours (synthèse audio).
  processing,

  /// Échec de génération.
  failed,

  /// La source a changé depuis la génération ⇒ podcast obsolète (à régénérer).
  stale,
}
