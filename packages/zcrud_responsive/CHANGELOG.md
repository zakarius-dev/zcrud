# Changelog

Format « Keep a Changelog » (sections Ajouté / Modifié / Corrigé, versions
antéchronologiques). Toutes les modifications notables de `zcrud_responsive`
sont documentées ici.

## 3.19.0 — 2026-08-24

### Ajouté
- **Le renderer par défaut honore le contrat de poignée** : un glissement parti de la poignée réorganise immédiatement, sans appui long, en alimentant exactement la machinerie existante — même aperçu flotté, même resynchronisation, même restauration sur échec. L'appui long sur la cellule **reste** disponible.
- **L'aperçu flotté accepte l'habillage déclaré par l'appelant** (`dragPreviewWrapper` de la requête).

### Corrigé
- **Une ligne portant un sous-widget Material ne fait plus lever l'aperçu.** L'aperçu vivant dans l'`Overlay`, un `TextField` glissé y perdait son ancêtre `Material` et levait en debug, sur les deux chemins. Le paquet n'importe toujours **pas** Material : c'est l'appelant qui déclare la surface.
- La zone sensible de la poignée couvre désormais **toute** sa cible tactile : au défaut, seule sa part peinte l'était, la moitié de la cible restant transparente au geste.

## 0.93.0 — 2026-08-13

### Modifié

- Chantier documentation : README réécrit au gabarit du monorepo, dartdoc de
  l'API publique normalisée (orientée consommateur), fiche `docs/site/paquets/`
  ajoutée, `public_member_api_docs` activé.

Historique antérieur : voir `git log` sur `packages/zcrud_responsive/`.
