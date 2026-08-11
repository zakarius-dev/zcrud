# Changelog

Toutes les modifications notables de `zcrud_export_ui` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet en français au gabarit de la charte documentaire
  (remplace le README anglais initial) : aperçu, installation, démarrage
  rapide, concepts clés, API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_export_ui.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`su-11`, `E-STUDY-UI`,
  `FR-SU16`, `AC4`, `AC6`, `AC9`) et des mentions `origine:`/emoji de journal,
  conservation des invariants citables (`AD-1`, `AD-8`, `AD-10`, `AD-13`).
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_export_ui/`.
