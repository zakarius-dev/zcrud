# Changelog

Toutes les modifications notables de `zcrud_export` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_export.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E11a-3`, `E11b-3`, `su-11`,
  `CR-LEX-40`, `AC9`, `AC10`) et des mentions `origine:`, conservation des
  invariants citables (`AD-1`, `AD-8`, `AD-10`, `AD-12`). Aucun changement de
  code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_export/`.
