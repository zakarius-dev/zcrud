# Changelog

Toutes les modifications notables de `zcrud_get` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_get.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E2-9`, `E7`, `fp-2-2`,
  `ES-11.1`, `ES-10.1`, codes `AC`/`R2x`/`R3-Ix`) et des mentions
  `origine:`, conservation des invariants citables (`AD-1` à `AD-7`, `AD-10`,
  `AD-12`, `AD-15`). Aucun changement de code — la revue ne porte que sur des
  commentaires.

### Inchangé

- `doc/parameter-matrix-z-get-form-presenter.md` — comparé byte à byte par
  des tests, jamais touché dans ce chantier.

Historique antérieur : voir `git log` sur `packages/zcrud_get/`.
