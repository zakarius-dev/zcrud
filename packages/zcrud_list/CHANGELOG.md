# Changelog

Toutes les modifications notables de `zcrud_list` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants — y compris `onLoadMore` et
  `cellColorBuilder`.
- Fiche `docs/site/paquets/zcrud_list.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E4-1` à `E4-4`, `AC5`,
  `AC9`, `Lot 5`, `MEDIUM-1`, `L2`) et conservation des invariants citables
  (`AD-1`, `AD-8`, `AD-10`, `AD-13`). Aucun changement de code — la revue ne
  porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_list/`.
