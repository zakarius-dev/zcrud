# Changelog

Toutes les modifications notables de `zcrud_document` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.3.1 — 2026-08-21

### Modifié — un seul calculateur de contraste dans tout le dépôt

La barre d'annotation portait un calculateur WCAG privé, bâti sur la luminance du
SDK ; elle consomme désormais celui de `zcrud_core`.

**Rendu strictement inchangé** — et mesuré, pas supposé : les deux
implémentations rendent le même nombre à **0.0 près** sur 1 257 couleurs et
5 028 couples teinte/surface, et classent tous ces couples du même côté des
planchers 3:1 et 4,5:1.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_document.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` (fichier créé
  — absent jusqu'ici) : l'exhaustivité de la documentation de l'API publique
  devient un invariant vérifié par l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel (domaine et présentation) : première phrase autonome, invariants
  d'architecture cités par leur nom stable (`docs/site/concepts/invariants.md`).
  Purge des références de story et d'epic, des emoji de journal, des
  codenames de remédiation internes et des comparatifs à des applications
  legacy utilisés comme justification — conservation des invariants, cas
  limites et avertissements de contrat. Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_document/`.
