# Changelog

Toutes les modifications notables de `zcrud_core` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu des
  couches domaine/présentation, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_core.md` (rôle, quand l'utiliser, types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du barrel (`zcrud_core.dart`, `domain.dart`,
  `edition.dart`) et du schéma déclaratif (`lib/src/domain/edition/`) :
  première phrase autonome, invariants d'architecture cités par leur nom
  stable (`docs/site/concepts/invariants.md`). Purge des références de story
  et d'epic, des comparatifs legacy nominatifs et des emoji de journal —
  conservation des invariants, cas limites et avertissements de contrat. Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_core/`.
