---
title: zcrud_study_kernel
description: Noyau Dart pur d'étude — dossiers, sessions et utilitaires d'assiduité partagés par les satellites d'étude.
---

# zcrud_study_kernel

## Rôle

`zcrud_study_kernel` est le paquet **kernel** de la capacité d'étude : il
porte les entités et règles métier bas-niveau communes à tous les
satellites d'étude — `ZStudyFolder` (dossier d'organisation multi-type,
rattachement inverse), la sélection de session (`ZStudySessionConfig` /
`ZStudySessionSelector`) opérant sur le port neutre `ZSessionCandidate`, le
dépôt CRUD offline-first générique `ZStudyRepository<T>`, les tags, la
flamme d'assiduité, l'ordre de contenu personnel d'un dossier, le podcast
content-addressed et des utilitaires domaine purs partagés (palette de
couleurs déterministe, tri à ordre personnel, normalisation de titre).
Aucune dépendance `flutter:` — ses tests tournent sous `dart test`.

## Quand l'utiliser

- Pour écrire un **nouveau satellite d'étude** qui a besoin du dossier
  d'organisation, de la sélection de session, ou des utilitaires partagés
  (couleur, tri, normalisation de tag) sans les redévelopper.
- Pour **traiter des données d'étude hors Flutter** (migration, script de
  maintenance, test unitaire) — ce paquet est pur-Dart.
- Pour **implémenter un port neutre** (`ZSessionCandidate`,
  `ZApproachingExam`, `ZStudyDocumentRef`, `ZStudyNoteRef`) sur une entité
  concrète, afin qu'un socle de présentation puisse la nommer sans arête
  directe vers son paquet.

## Quand ne pas l'utiliser

- Pour construire directement une interface d'étude Flutter : passez par un
  satellite (ex. `zcrud_document`) qui assemble ce kernel avec un
  contrôleur réactif et un rendu.
- Pour un modèle spécifique à un type de contenu (document, flashcard,
  note, mindmap, examen) : ce kernel reste délibérément générique et
  ignorant de ces types concrets (invariant [AD-1](../concepts/invariants.md#ad-1)).

## Types clés

| Type | Rôle |
|---|---|
| `ZStudyFolder` / `validatePlacement` | Dossier d'organisation multi-type et primitive pure de hiérarchie 2 niveaux. |
| `ZStudySessionConfig` / `ZStudySessionSelector` / `ZSessionCandidate` | Filtres de session persistables, sélection pure, et port neutre implémenté par les satellites. |
| `ZStudyRepository<T>` | Port CRUD offline-first générique à hook de validation métier (Template Method). |
| `ZColorPalette` / `remapColorKey` | Registre de `colorKey` borné et remap déterministe, zéro `Color` dans le domaine. |
| `ZStudyStreak` / `zAdvanceStreak` | Flamme d'assiduité et son avancement pur, sur une horloge paramétrée. |
| `ZStudyDocumentRef` / `ZStudyNoteRef` / `ZApproachingExam` | Ports neutres implémentés côté satellite, pour un socle de présentation sans arête directe. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_study_kernel/README.md) — installation, démarrage rapide, API complète.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- [`zcrud_document`](./zcrud_document.md) — satellite qui dépend de ce kernel.
