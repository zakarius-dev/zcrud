# Changelog

Toutes les modifications notables de `zcrud_study` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.0.0 — 2026-08-18

### 🔴 Corrigé — deux canaux de seams disparaissaient sous la feuille

`subListSeamRegistry` (ajouté en 1.8.0) et `selectChoiceBuilderRegistry`
(ajouté en 2.1.0) n'étaient **pas re-posés** lors de la recopie du `ZcrudScope`.
Sous l'`Overlay`, un hôte perdait donc **en silence** le rendu déclaré qu'il
venait d'obtenir.

Trouvé par la garde de structure de `cr_iffd41_subfolder_sheet_test`, qui lit la
liste **réelle** des paramètres dans la source de `zcrud_core` et exige que
chacun soit re-posé. C'est la **quatrième et cinquième** fois qu'elle mord.

**Un site jumeau, non couvert par cette garde, portait le même défaut** :
`z_default_flashcard_card` recopie le scope de la même façon. Corrigé aussi —
trouvé en cherchant le jumeau, pas en attendant qu'il se manifeste.

### ⚠️ Modifié — RUPTURE : le menu d'actions rend une grille par défaut

`ZItemActionsMenu` rendait une **colonne unique** quand aucune présentation
n'était injectée. Mesuré chez l'hôte : **aucun** de ses cinq menus n'est en
colonne, et son portage a dû réinjecter la grille à la main.

Le défaut est désormais une **grille de 3 colonnes**, via le
`ZMenuEntryTile.gridDelegate` qui existait déjà et porte le plancher de cible
tactile par construction. `crossAxisCount` est déclarable au point d'appel.

**Retour arrière en une ligne : `crossAxisCount: 1`** — prouvé par garde, pas
promis.

Trois colonnes et non deux est un **arbitrage assumé de l'hôte**, contre son
propre legacy qui en rend deux : il demande le meilleur défaut pour l'ensemble
des applications d'étude, quitte à déclarer `2` chez lui.

### Ajouté — une action porte son état

`ZItemActionState { absent, inProgress, present }` et un **compte** optionnel :
la couleur d'une action signale l'existence de ce qu'elle produit, le badge dit
combien. *« Retirer la couleur ne retire pas un ornement : cela retire
l'information. »*

**Aucune couleur codée en dur** (FR-26) : teinte dérivée du `ColorScheme` par le
patron déjà employé par `ZDefaultFolderCard` (`zReadableTintOn`, plancher de
contraste). L'état est **annoncé**, pas seulement peint — une information portée
par la seule couleur est invisible à un lecteur d'écran, et ce serait reproduire
le défaut à l'envers. Un état invalide **échoue fermé** : aucune teinte sans
annonce.

Sans état ni compte déclarés : aucun enrobage, aucun badge, aucune teinte —
rendu identique (contre-témoin à comptes absolus).

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  des sections composables, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du domaine, de la couche données et d'une
  partie de la couche présentation : première phrase autonome, invariants
  d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal, des comparatifs legacy nominatifs et des
  historiques de correctifs — conservation des invariants, cas limites et
  avertissements de contrat. Aucun changement de code — la revue ne porte
  que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study/`.
