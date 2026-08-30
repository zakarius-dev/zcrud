# Handoff v3.37.0 — la forêt qui préserve le reste, et le renommage enfin déclarable

> **Date** : 2026-08-30. **Portée** : `zcrud_mindmap`, `zcrud_generator`, `zcrud_annotations`.
> **Traite** : CR-LEX-83 (MAJEUR) et CR-LEX-85 (MINEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : **0 `.g.dart` modifié**.

## 1. CR-LEX-83 — `ZMindmap.withNodes`

`ZMindmap` n'exposait qu'une voie de copie, `copyWithPreservingTree`, qui **exclut `nodes`** pour
protéger l'invariant « la mutation de l'arbre passe par `ZMindmapTreeOps` ». L'invariant est
juste, mais le moyen coûtait plus qu'il ne protégeait : `ZMindmapTreeOps` rend une
`List<ZMindmapNode>` que **rien n'acceptait** pour la reposer dans l'entité — la chaîne prescrite
s'interrompait sur son dernier maillon, et tout éditeur de carte mentale était renvoyé au
constructeur nominal, c'est-à-dire au geste que la dartdoc désigne elle-même comme le défaut
(perte de `description`, `extension`, `extra`).

Livré : `ZMindmap withNodes(List<ZMindmapNode> nodes)` — méthode **séparée**, pour laisser
`copyWithPreservingTree` strictement inerte (une garde de source le prouve). L'invariant tient
désormais par la **provenance** de la liste, documentée, pas par l'absence du paramètre.
Normalisation alignée sur le constructeur : copie non modifiable, `level` **non** renormalisés
(seule `fromJson` renormalise, parce qu'elle lit une donnée non fiable).

**La préservation est prouvée par la machine, pas par relecture** — c'était la condition pour ne
pas reproduire le défaut dont l'hôte se plaint : comparaison de `toJson()` **clé par clé** sur une
instance dont tous les champs sont renseignés et distincts des défauts, cardinalité figée à 8, et
une garde de source qui confronte les paramètres nommés du constructeur aux arguments réellement
transmis par `withNodes` — elle mord même sur un champ qui n'atteindrait jamais `toJson`.

## 2. CR-LEX-85 — `fieldRename` déclarable depuis un paquet consommateur

Cause **mesurée**, pas supposée : `ZFieldRename` est déclaré dans `zcrud_core`, et le barrel
`zcrud_annotations.dart` ne le ré-exportait pas. Dans une bibliothèque qui n'importe que ce
barrel, l'identifiant n'est pas résolu : l'analyzer laisse `fieldRename` **nul** dans la constante
de l'annotation pendant que `kind` reste lisible — le générateur ne voit donc pas une erreur de
compilation, il voit une constante nulle. Les entités du socle échappaient au défaut parce
qu'elles importent aussi un barrel de `zcrud_core`. Reproduit avant tout correctif sur quatre
configurations (barrel seul ⇒ échec ; avec `zcrud_core` ou un import préfixé ⇒ vert).

Livré : ① le barrel `zcrud_annotations` ré-exporte `ZFieldRename` (règle générale : un barrel rend
nommable tout type figurant dans la signature d'une annotation qu'il exporte) ; ② un filet de
lecture par l'**AST** quand la constante est illisible — seule la forme littérale
`ZFieldRename.<valeur>` est acceptée, un alias `const` ou une expression calculée **échoue** le
build ; ③ un message actionnable. **La propriété absolue est préservée** : aucun repli silencieux,
jamais de renommage de clés à l'insu de l'auteur (gardé par un test qui rougit si un repli muet
est introduit).

## 3. Ce qui change pour un hôte

- **Passif : rien** dans les deux cas (paramètre omis ⇒ `snake` inchangé ; livraison mindmap
  purement additive).
- 🔴 **Hôte ayant contourné CR-83** — « défaut contourné devenu comportement natif » : celui qui
  **énumérait les sept champs à la main** pour reposer une forêt doit **retirer cette
  énumération** au profit de `base.withNodes(nouvelleForêt)`. C'est ce retrait qui lui rend
  l'héritage automatique des champs futurs ; sans lui, chaque champ ajouté au cœur redeviendra une
  perte silencieuse chez lui. Une couche aval qui relisait et réinjectait les champs perdus
  devient elle aussi redondante. Tripwire recommandé : un test qui **affirme la perte** tant que
  l'énumération manuelle est en place — il rougira au retrait et désignera le doublon.
- **CR-85** : la déclaration explicite redevient possible, mais toute valeur autre que `snake`
  **change les clés persistées** — c'est un changement de format, pas un réglage cosmétique. Un
  fichier qui importait `zcrud_core` uniquement pour `ZFieldRename` peut voir apparaître un
  `unnecessary_import` (info).

**Note de suivi** : CR-LEX-84 est **livrée depuis v3.36.0** (`e95fe338a`) — le registre de l'hôte
la marque encore `CONTOURNÉ` parce qu'il a été écrit avant le tag. Et CR-IFFD-83 (pastille de
compte) reste marquée « OUVERTE » alors qu'elle est livrée : les deux remèdes sont vérifiés par R3
(voir handoff v3.36.0).

## 4. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_mindmap` | 223 | **235** (analyze : 5 infos préexistantes, inchangées) |
| `zcrud_generator` (`dart test`) | 198 | **206** (analyze propre) |
| `zcrud_annotations` (`dart test`) | 10 | **12** (analyze propre) |

`melos run generate` : SUCCESS, **0 `.g.dart` modifié** · `analyze` repo-wide RC=0 · `verify`
RC=0 (12 gates) · R3 : 12 injections (9 mindmap + 3 générateur/annotations), toutes rouges **par
assertion** — une variante rougissant par erreur de compilation a été écartée et refaite ·
restaurations par copie, sha256 identiques, greps négatifs · Balayage des 41 : **41/41 verts**.
