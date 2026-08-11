# Changelog

Toutes les modifications notables de `zcrud_session` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_session.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel (trois moteurs de runtime, surface de saisie, boutons de notation,
  pile swipeable, sélecteur de session, écran de fin, dialog de filtres) :
  première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal et des historiques de correctifs — conservation
  des invariants, cas limites et avertissements de contrat (notamment la
  voie d'écriture SRS unique, l'arène des gestes de la surface de saisie et
  la correspondance carte ↔ réponse de l'examen blanc en liste). Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_session/`.
