# Changelog

Toutes les modifications notables de `zcrud_navigation` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_navigation.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`EX-UI.*`, codes `AC`/`NFR`),
  des comparatifs nominatifs à des applications legacy et des dates de
  correctif, conservation des invariants citables (`AD-1` à `AD-15`) et de
  la substance technique (chaîne de résolution paramètre/jeton/référence,
  inertie déclarée par mode, garde d'identité d'arbre). Aucun changement de
  code — la revue ne porte que sur des commentaires.

### Inchangé

- `doc/parameter-matrix-z-adaptive-presenter.md` — comparé byte à byte par
  des tests, jamais touché dans ce chantier.

Historique antérieur : voir `git log` sur `packages/zcrud_navigation/`.
