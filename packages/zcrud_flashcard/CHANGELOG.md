# Changelog

Toutes les modifications notables de `zcrud_flashcard` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.28.0 — 2026-08-28

### Ajouté

- `ZFlashcardTestFilters.sourceIds` et `ZFlashcardBrowseFilters.sourceIds` :
  filtre par **identifiant** de provenance, en complément du filtre par `kind`
  déjà présent. Défaut `const <String>{}` ⇒ aucun filtre, et inertie absolue
  des deux appliqueurs (`zApplyTestFilters`, `zApplyBrowseFilters`) tant que
  l'ensemble est vide.
- `zMatchesSourceId(card, sourceIds)` : prédicat public **unique** de
  comparaison d'identifiant de provenance, partagé par le tirage de session et
  la consultation — pendant exact de `zMatchesSourceKind`. Extraction
  canonique de `noteId` / `messageId` / `documentId` par `switch` exhaustif sur
  les variants scellés de `ZFlashcardSource` ; une `ZCustomSource` (registre
  ouvert, sans identifiant canonique) ne correspond jamais à un filtre non
  vide. Pur et total : aucun cas ne lève (AD-10).
- `sourceIds` participe à `==` et `hashCode` des deux value objects de filtres.

### Modifié

- `zApplyTestFilters` et `zApplyBrowseFilters` composent `sourceIds` **en ET**
  avec `sources` (`kind`). L'ordre d'application ne change rien au résultat :
  les deux critères sont des conjonctions.
- Barrel : `ZStudySubjectRef` (symbole study-niveau du noyau d'étude) rejoint
  le `hide` de la ré-export `zcrud_study_kernel` — il n'appartient pas à la
  surface publique flashcard.

### Tests

- `z_flashcard_source_id_filters_test.dart` : 2 gardes d'inertie absolue
  (60 cartes, identité d'instance index par index sur les deux appliqueurs) et
  5 gardes d'effet, de composition en ET et de participation à l'égalité.
- `z_flashcard_source_id_predicate_guard_test.dart` : garde de source
  interdisant toute comparaison applicative d'identifiant de provenance en
  dehors de `zMatchesSourceId`, corps du prédicat canonique neutralisé avant le
  scan (une disparition du prédicat fait échouer la garde au lieu de produire
  un faux vert). Les égalités structurelles des value objects de
  `z_flashcard_source.dart` restent autorisées.
- Les trois gardes sont qualifiées par injection R3 : rouge par assertion,
  restauration par copie, empreinte identique avant/après.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_flashcard.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables, invariants
  d'architecture cités par leur nom stable (`docs/site/concepts/invariants.md`).
  Purge des références de story et d'epic, des emoji de journal et des
  comparatifs applicatifs nominatifs — conservation des invariants, cas
  limites et avertissements de contrat. Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_flashcard/`.
