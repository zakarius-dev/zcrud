# Changelog

Toutes les modifications notables de `zcrud_markdown` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.12.0 — 2026-08-24

### Corrigé
- **Cellule de tableau nue** : une cellule riche (gras, lien, formule) est rendue sans cadre ni padding propres — c'est le tableau qui habille ses cellules, et lui seul. Les retraits d'une cellule riche et d'une cellule en texte pur sont identiques.
- **Formule LaTeX bloc** : un bloc plus large que la place disponible **défile horizontalement** au lieu de déborder ; une formule étroite garde son rendu centré. Un bloc dans une cellule de tableau se dimensionne sans exception.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit au gabarit de la charte documentaire : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_markdown.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel, ainsi que des en-têtes de module des fichiers internes majeurs :
  première phrase autonome, invariants d'architecture cités par leur nom
  stable (`docs/site/concepts/invariants.md`). Purge des références de story
  et d'epic, des emoji de journal et des noms d'applications legacy utilisés
  comme justification — conservation des invariants, cas limites et
  avertissements de contrat. Aucun changement de code — la revue ne porte que
  sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_markdown/`.
