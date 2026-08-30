# Changelog

Toutes les modifications notables de `zcrud_mindmap` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.37.0 — 2026-08-30

### Ajouté

- `ZMindmap.withNodes(List<ZMindmapNode> nodes)` — voie de **remplacement de
  l'arbre** qui préserve tous les autres champs par construction (`id`,
  `folderId`, `title`, `description`, `extension`, `extra`).

  Motivation (CR-LEX-83, MAJEUR, état `CONTOURNÉ`) : `copyWithPreservingTree`
  reprenait `nodes` tel quel et était donc inutilisable par un éditeur de carte,
  qui ne produit rien d'autre qu'une nouvelle forêt. `ZMindmapTreeOps` rendait
  une `List<ZMindmapNode>` que **rien n'acceptait** pour la reposer dans
  l'entité : la chaîne prescrite s'interrompait sur son dernier maillon, et
  l'hôte était renvoyé au constructeur nominal — c'est-à-dire au geste « champ
  par champ » que la dartdoc de `copyWithPreservingTree` désigne elle-même comme
  le défaut. Mesuré chez lex_douane : quatre champs sur sept reconstruits dans
  `study_mindmap_screen._buildMindmap`, les trois autres ne survivant que par une
  couche aval qui les relisait et les réinjectait.

  L'invariant « la mutation de l'arbre passe par `ZMindmapTreeOps` » reste
  protégé — par la **provenance** de la liste (documentée comme sortie de
  `ZMindmapTreeOps`, ou forêt dont l'appelant assume la cohérence), pas par
  l'absence du paramètre.

  Normalisation **identique au constructeur nominal** : copie non-modifiable,
  `level` non renormalisés (seule `fromJson` renormalise, parce qu'elle lit une
  donnée dont la cohérence n'est pas garantie).

### Inchangé (inertie stricte)

- `copyWithPreservingTree` : signature et comportement inchangés — elle n'a
  **pas** gagné de paramètre `nodes`, et une garde de source le vérifie.

### Tests

- `test/cr_lex_83_with_nodes_test.dart` (12 tests). La préservation est prouvée
  par la **machine**, jamais par une énumération de champs à la main — qui
  reproduirait exactement le défaut de l'hôte et se tairait au huitième champ :
  - `toJson()` comparé **clé par clé** entre l'original et le résultat sur une
    instance dont **tous** les champs sont renseignés et distincts des défauts,
    seule la clé des nœuds pouvant différer ;
  - **cardinalité** de `toJson().keys` figée (filet du champ futur) ;
  - garde de **source** (`@TestOn('vm')`) confrontant les paramètres nommés du
    constructeur nominal aux arguments réellement transmis par `withNodes` —
    elle mord même sur un champ qui n'atteindrait jamais `toJson` ;
  - remplacement effectif de la forêt (ordre, descendance, non-fusion), forêt
    vide admise, liste rendue non-modifiable, découplage de la liste appelante,
    `level` non renormalisés ;
  - inertie de `copyWithPreservingTree` et absence de journal dans la dartdoc.

  Campagne R3 : **9 injections**, toutes rouges **par assertion** (aucune par
  erreur de compilation), restauration par copie, aucun résidu.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet en français, au gabarit de la charte documentaire
  (remplace le README anglais initial) : aperçu, installation, démarrage
  rapide, concepts clés, API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_mindmap.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` au format Keep a Changelog FR (remplace le changelog
  anglais initial ; ce fichier).

### Modifié

- Normalisation de la dartdoc et des commentaires internes de l'ensemble du
  paquet : purge des références de story, d'AC et de revue de code, et des
  comparatifs d'historique de correctifs — conservation des invariants, des
  cas limites et des avertissements de contrat cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_mindmap/`.
