# Changelog

Toutes les modifications notables de `zcrud_flashcard` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.47.0 — 2026-09-08

### Documenté

- `ZSrsConfig.minQuality` — la dartdoc dit désormais ce que cette borne
  **écrit**, et pas seulement ce qu'elle clampe. C'est la note réellement
  posée sur la répétition par le geste le plus bas d'une session (« je ne sais
  pas »), reportée en persistance dans `ZRepetitionInfo.lastQuality`. Une
  application dont l'échelle **persistée** ne comporte pas de `0` (énumération
  démarrant à `1`) doit déclarer `ZSrsConfig(minQuality: 1)` : le `0` par
  défaut lui est légal — c'est l'échelle qu'elle a elle-même fournie — mais
  non représentable chez elle, et sa propre conversion le ramène à « aucune
  note » sans exception ni test rouge. La configuration ne peut pas détecter
  la situation : elle ne connaît que l'échelle qu'on lui donne. **Aucun
  changement de contrat** : ni assertion nouvelle, ni valeur par défaut
  modifiée — un hôte au défaut n'a rien à faire.
  La dartdoc chiffre aussi le **coût** de la bascule `0 → 1` :
  `interval`/`repetitions` sont inchangés (deux lapses), mais le facteur de
  facilité diffère (`-0,80` contre `-0,54`, formule SM-2 en `(5 - q)`), et
  l'écart se reporte sur toutes les échéances ultérieures.
- `ZFlashcardHintPort` — la dartdoc dit ce qu'un hôte **sans port** conserve :
  l'indice **stocké** (`ZFlashcard.hint`) reste servi à la première demande,
  exactement comme avec un port ; seule la **génération** des indices suivants
  est perdue. Ne pas implémenter ce port est un choix tenable, pas une
  dégradation de la carte.

### Tests

- `z_min_quality_written_note_test.dart` — fige, par la mesure, que le socle
  **reporte** la note dans `ZRepetitionInfo.lastQuality` sur les deux échelles
  admises (la perte éventuelle n'est donc jamais la sienne), que
  `ZSrsConfig(minQuality: 1)` reste constructible et clampe `0` vers `1`, et
  que la bascule `0 → 1` laisse `interval`/`repetitions` identiques tout en
  déplaçant le facteur de facilité de `1,70` à `1,96`.
- `z_optional_port_and_low_bound_doc_guard_test.dart` — garde de source : les
  deux règles ci-dessus doivent rester **écrites** dans le bloc de dartdoc de
  leur déclaration. Le comportement « sans port, l'indice stocké est servi »
  est réalisé par la surface de saisie, dans un autre paquet, hors d'atteinte
  d'un test d'ici (invariant AD-1) ; et la disparition d'un avertissement au
  consommateur n'est attrapée par aucun test de comportement.

## 3.29.0 — 2026-08-28

### Ajouté

- `ZEaseFactorAdjustment` — **stratégie d'ajustement du facteur de facilité**,
  déclarée sur `ZSrsConfig.easeFactorAdjustment` et consommée par
  `ZSm2Scheduler`. Deux implémentations livrées :
  - `ZEaseFactorAdjustment.canonical()` (le **défaut**) : la formule
    SuperMemo-2 historique `EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))`,
    déplacée telle quelle depuis le corps du planificateur — mêmes opérations,
    même ordre, **mêmes doubles au bit près** ;
  - `ZEaseFactorAdjustment.table(deltaByQuality:, penalizeLapse:)` : delta
    **additif par qualité** déclaré par l'application. Une qualité absente de
    la table laisse le facteur de facilité inchangé ; `penalizeLapse: false`
    neutralise toute variation sous `passThreshold`. **Aucune valeur de delta
    n'est fournie par le paquet** — la table est une donnée de l'application.
  La stratégie rend une valeur **brute** : le bornage à
  `[minEaseFactor, maxEaseFactor]` reste au planificateur, jamais dupliqué.
  `toMap`/`fromMap` tolérants (clés de table en chaînes, contrainte JSON) :
  toute forme non reconnue — map nulle, discriminant absent/inconnu, table
  absente ou illisible — se replie sur la stratégie canonique, jamais une
  levée (AD-10).
- `ZSrsConfig.neutralQuality` (`int?`, défaut `null`) : qualité posée quand
  aucune évaluation n'est disponible (type non évalué localement **et** port
  d'évaluation absent/indisponible/muet). `null` ⇒ `passThreshold`, résolu par
  l'accesseur dérivé `ZSrsConfig.effectiveNeutralQuality` — **source unique**
  de la règle, pour qu'aucun consommateur n'écrive `?? passThreshold` chez
  lui. La valeur est **bornée** à `[minQuality, maxQuality]` à la construction
  (clamp, jamais une levée). Ce paquet ne consomme pas ce réglage : il décrit
  la politique du flux de session, et il est déclaré ici parce que l'échelle
  de qualité est possédée ici.

### Inchangé (vérifié)

- `z_sm2_contract_test.dart` — le golden numérique SM-2 — **n'a pas été
  touché** et reste vert : le passage par la stratégie est strictement
  iso-comportemental pour la configuration par défaut. Une garde
  supplémentaire (`z_ease_factor_adjustment_test.dart`) le prouve sur une
  grille de 20 facteurs de facilité de départ × 6 qualités, en **égalité
  exacte** contre la formule littérale réécrite dans le test.
- `ZMasteryLevel` couvrait **déjà** les bandes de qualité demandées
  (`bad` = `[minQuality .. passThreshold-1]`, `good` =
  `[passThreshold .. masteredThreshold-1]`, `mastered` =
  `[masteredThreshold .. maxQuality]`, soit q0-2 / q3 / q4-5 en configuration
  canonique) : aucun type de bande supplémentaire n'a été introduit — un
  second classement aurait été une seconde source de vérité.

### Modifié

- Surface publique : les **169 symboles du modèle de structure** de
  `zcrud_study_kernel` (entités study et leurs analyseurs d'extension, ports
  neutres de structure et leurs implémentations inertes, ontologie et ses
  validateurs, primitives de graphe/visibilité, primitives de (dé)sérialisation
  partagées, clés canoniques `kZStudy…`) sont **masqués** au réexport du barrel
  du noyau : ils sont study-niveau et n'ont jamais appartenu à la surface
  flashcard. Un consommateur qui en a besoin importe `zcrud_study_kernel`
  directement (foyer unique). La surface flashcard historique est intégralement
  préservée — aucun symbole retiré, aucune allowlist étendue.
- `z_kernel_surface_guard_test.dart` : le scan de la surface du noyau lisait le
  barrel **ligne à ligne** et rendait donc invisibles les directives `export`
  écrites sur plusieurs lignes (`export '…'` puis `hide …;`). Onze sources du
  noyau — 24 symboles, dont `ZStudyOrganization`, `ZStudyCompetency` et
  `ZStudyShareGrant` — échappaient ainsi à toute classification et pouvaient
  fuiter en silence. Le scan porte désormais sur le texte joint, et deux
  assertions de méta-garde interdisent le retour de l'angle mort.

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
