# Changelog

Toutes les modifications notables de `zcrud_chat_markdown` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.4.0 — 2026-08-22

### Ajouté — le jeu de styles du lecteur devient déclarable

`styleSet` — jeu de styles rich-text **par axe Markdown**, relayé au lecteur.
C'est le seul canal permettant de viser séparément un titre, le gras,
l'italique, la citation ou le code : le style global ne distingue pas ces axes,
et le thème de l'application viserait tout l'écran.

Chaque axe est fusionné par-dessus le style courant ; un jeu **partiel** est
légitime, les axes non couverts ne bougent pas.

`textScaleFactor` — facteur d'échelle du texte rendu, relayé au lecteur.

⚠️ **Il est ABSOLU** : il **remplace** l'échelle ambiante au lieu de s'y
multiplier. Un hôte qui veut composer avec l'échelle d'accessibilité du système
doit multiplier lui-même avant de la passer — l'ignorer écraserait le réglage
d'un utilisateur malvoyant sans que rien ne le signale.

### Précisé — l'articulation avec le style global

Sur un axe couvert par le jeu de styles, c'est lui qui l'emporte ; sur les axes
qu'il ne couvre pas, le style global — puis le thème — reste seul en vigueur.
Ce n'est pas un arbitrage : c'est la mécanique de composition, le style global
servant de base sous le lecteur et le jeu étant fusionné par-dessus.

### Inchangé

Sans déclaration, le rendu est **strictement** celui d'avant : aucun des deux
paramètres n'a de valeur par défaut, et ce paquet ne pose de lui-même ni couleur
ni taille.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_chat_markdown.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et de correctif, des emoji de journal et des mesures de banc
  ponctuelles — conservation des invariants, cas limites et avertissements de
  contrat (streaming, périmètre de blocs, confinement de la dépendance
  riche). Aucun changement de code — la revue ne porte que sur des
  commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_markdown/`.
