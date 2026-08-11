# Changelog

Toutes les modifications notables de `zcrud_export_pdf` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale — y compris
  `ZPdfHeaderSpec` —, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_export_pdf.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E11a-3`, `E11b-3`, `su-11`,
  `CR-LEX-38` à `CR-LEX-43`, codes `AC`) et des comparatifs nominatifs à des
  applications legacy, conservation des invariants citables (`AD-1`, `AD-2`,
  `AD-4`, `AD-8`, `AD-10`, `AD-12`, `AD-13`) et de la substance technique
  (chaîne de polices, anti-rognage, composition inline sans perte). Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_export_pdf/`.
