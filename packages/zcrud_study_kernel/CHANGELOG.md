# Changelog

Toutes les modifications notables de `zcrud_study_kernel` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral Dart remplacé par `\u0000` (un `grep` sans `-a` voyait un fichier binaire ; `git diff` aussi).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study_kernel.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et d'epic, des emoji de journal, des codenames de remédiation internes
  et des comparatifs à des applications legacy utilisés comme justification —
  conservation des invariants, cas limites et avertissements de contrat.
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study_kernel/`.
