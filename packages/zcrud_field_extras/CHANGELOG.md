# Changelog

Toutes les modifications notables de `zcrud_field_extras` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet en français au gabarit de la charte documentaire :
  aperçu, installation, démarrage rapide, concepts clés, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_field_extras.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`fp-1-2`, `fp-4-2`, `fp-5-1`,
  `fp-5-2`, `FR-34`, `FR-35`, `FR-36`, `AC-B3`, `AC-C2`, `AC-D`, `MED-1`,
  `MED-3`) et des emoji de journal, conservation des invariants citables
  (`AD-1`, `AD-2`, `AD-10`, `AD-13`). Aucun changement de code — la revue ne
  porte que sur des commentaires.

## [0.2.1]

Substrat initial du satellite champs spécialisés.

- Arbre `pubspec`, barrel, `lib/src/{domain,data,presentation}`, garde de
  confinement.
- Ne dépend que de `zcrud_core` parmi les paquets zcrud.
- Publié sous licence MIT.

Historique antérieur : voir `git log` sur `packages/zcrud_field_extras/`.
