# Changelog

Toutes les modifications notables de `zcrud_mindmap` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

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
