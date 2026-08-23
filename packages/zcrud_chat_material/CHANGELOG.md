# Changelog

Toutes les modifications notables de `zcrud_chat_material` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.7.0 — 2026-08-23

### Ajouté
- **Feuille de réglages riche par défaut** : `ZChatMaterialSettingsSheet` pose un builder Material pour **chacune des neuf familles** de `ZChatSettingsSheet` (`header`, `presets`, `responseLength`, `lengthBias`, `computeBudget`, `revealThinking`, `capabilities`, `corpus`, `unknownEntry`), chacun remplaçable par paramètre nommé — un builder fourni par l'hôte **gagne** sur le défaut. Formes : `ChoiceChip` en `Wrap` (longueur, biais, préréglages), `SwitchListTile` à **sous-titre d'état** fourni par l'hôte (raisonnement, capacités), `FilterChip` avec puce « Tous » et entrée indisponible **grisée avec sa raison** (corpus), en-tête titre + réinitialiser + fermer, titres de section `titleSmall` en couleur de rôle.
- `ZChatMaterialSettingsLabels` : tous les libellés viennent de l'hôte ; libellé absent ⇒ affordance absente.
- `ZChatMaterialSettingsReference` : la géométrie, sans littéral dans les widgets.

### Garde
- Aucun `ZChatTool*` dans les builders des familles standard : un réglage standard ne se redéclare pas comme outil d'hôte (deux états pour un même réglage, dont un seul part dans la requête).

## 3.6.0 — 2026-08-23

### Ajouté
- **Feuille d'outils Material** : `ZChatMaterialToolsSheet` (`DraggableScrollableSheet`, en-tête titre + badge + réinitialiser + fermer, en-tête **« Actifs »** en puces retirables, recherche conditionnelle, sections séparées **entre** elles — aucun index magique), `ZChatMaterialToolTile` (une forme par nature : `SwitchListTile` à sous-titre d'**état**, cycle à badge de cran, `SegmentedButton`, curseur à repères, `FilterChip` + puce « tout », bouton ; entrée désactivée **grisée avec sa raison**, jamais masquée), `ZChatMaterialToolLabels` (tous les libellés viennent de l'hôte — absent ⇒ affordance absente), `ZChatMaterialToolCatalogBadge`.
- `ZChatMaterialLabelledSlider` extrait du curseur de budget, qui en devient l'appelant.

### Garde
- Aucun libellé écrit dans le satellite (nouvelle garde de source).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_chat_material.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`), texte de chrome
  factorisé en `{@template}`/`{@macro}`. Purge des références de lot et de
  correctif, des emoji de journal et des comparaisons pixel à une référence
  externe nominative — conservation des invariants, cas limites et
  avertissements de contrat (notamment la migration de `borderColor` pour un
  hôte qui compensait déjà). Aucun changement de code — la revue ne porte que
  sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_material/`.
