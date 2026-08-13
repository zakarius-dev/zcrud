# Changelog

Toutes les modifications notables de `zcrud_menu` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.93.0 — 2026-08-13

### Ajouté

- **`ZGridMenuRenderer`** — rendu du menu en **grille de tuiles**, à côté du
  rendu par défaut : colonnes configurables, tuiles bâties sur
  `ZMenuEntryTile`. Le plancher de 48 dp est tenu par la **disposition** (un
  enfant ne peut pas se rendre plus grand que la place reçue, la cellule seule
  n'y suffit donc pas), et le libellé n'est annoncé qu'**une fois** — deux
  corrections d'accessibilité qu'une application avait dû écrire chez elle
  avant de pouvoir s'en servir.
- **`ZContextMenuRegion`** — ouverture du menu par **geste contextuel** : clic
  droit sur pointeur, appui long sur tactile. Le geste **s'ajoute** à
  l'affordance visible, il ne la remplace jamais : un chemin offert au seul
  clic droit serait inatteignable au clavier et aux lecteurs d'écran
  (invariant AD-13). La surface ouverte reste celle du renderer ambiant.
- **`ZMenuPanelEntry`** — entrée de panneau pour les surfaces de menu
  composées.

### Modifié

- La **voie de sélection est unique** pour tous les renderers et tous les
  gestes : l'entrée reçue est **re-résolue** dans la liste courante avant
  invocation. Un renderer — y compris un adaptateur tiers — ne peut donc ni
  exécuter une entrée désactivée, ni imposer l'effet d'une entrée qu'il aurait
  fabriquée lui-même. La re-résolution n'est pas décorative : une surface
  flottante capture l'entrée à l'ouverture, et un rebuild survenu entre-temps
  rendrait la comparaison par valeur fausse — la sélection serait avalée sans
  la moindre trace.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_menu.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic et des comparatifs nominatifs
  à des applications hôtes, conservation des invariants citables (`AD-1`,
  `AD-4`, `AD-10`, `AD-13`) et de la substance technique (les trois états
  d'une entrée, le rôle de `permitted`, la garde de cible tactile en grille).
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_menu/`.
