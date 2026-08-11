# Changelog

Toutes les modifications notables de `zcrud_chat_markdown` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_chat_markdown.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et de correctif, des emoji de journal et des mesures de banc
  ponctuelles — conservation des invariants, cas limites et avertissements de
  contrat (streaming, périmètre de blocs, confinement de la dépendance
  riche). Aucun changement de code — la revue ne porte que sur des
  commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_markdown/`.
