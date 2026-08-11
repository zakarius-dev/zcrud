# Changelog

Toutes les modifications notables de `zcrud_select` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_select.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`fp-1-2`, `fp-4-1`, codes
  `CR-SELECT-*`, `CR-REQUIRED-INDICATOR`, `DP-15`) et des comparatifs
  nominatifs à des applications legacy, conservation des invariants citables
  (`AD-1`, `AD-2`, `AD-4`, `AD-10`, `AD-13`) et de la substance technique
  (chaîne de résolution, apparence de référence, correspondance couleur →
  rôle). Aucun changement de code — la revue ne porte que sur des
  commentaires.

## [0.2.1]

Substrat initial du satellite sélection.

- Arbre `pubspec`, barrel, `lib/src/{domain,data,presentation}`, garde de
  confinement.
- Ne dépend que de `zcrud_core` parmi les paquets zcrud.
- Déclare le fork vendorisé privé `awesome_select` comme dépendance feuille,
  gardée comme déclarée par ce seul paquet.
- Publié sous licence MIT.

Historique antérieur : voir `git log` sur `packages/zcrud_select/`.
