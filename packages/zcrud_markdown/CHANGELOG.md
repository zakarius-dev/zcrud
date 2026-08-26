# Changelog

Toutes les modifications notables de `zcrud_markdown` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.22.0 — 2026-08-26

### Ajouté
- **Retour à la ligne souple déclarable** (`ZMarkdownCodec.softBreak`) — défaut inchangé. Un corpus dont chaque note et chaque explication était recollée en pavé se relit enfin comme il a été écrit. Le réglage porte sur les **deux** chemins du retour souple : sans le second, il gardait un angle mort d'une espace de large.
- **Largeur de tableau déclarable** (`ZTableWidthScope` / `ZTableWidth`) — l'échappatoire que le bloc de formule avait déjà, portée telle quelle sur le chemin de rendu partagé.
- **Sous-titre du dialogue plein écran** (`subtitle`) — absent de l'arbre quand il n'est pas déclaré.
- **Forçage de la présentation plein cadre** (`fullscreen` sur le point d'entrée) — `null` conserve la décision automatique par la largeur.

### Attention
- Poser une largeur de tableau a **deux effets au-delà du débordement** : les petits tableaux **cessent de s'étirer**, et le texte **ne se replie plus** en cellule.

## 3.21.0 — 2026-08-25

### Ajouté
- **Le champ compact a un chrome et une barre d'outils PAR DÉFAUT** : carte, en-tête et barre habillée à fleur, sans qu'un hôte n'écrive quoi que ce soit. Tout reste remplaçable par paramètre et par jeton.
- **Préréglage `ZRichTextToolbarConfig.inline`** : les seize boutons du champ compact, dans leur ordre, groupés — et sans ceux qu'il n'a pas. Un préréglage est une **donnée**, jamais un comportement.
- **Géométrie de barre exprimable** : `showSectionDividers`, `iconSize`, `iconButtonFactor`, `iconColor`, `selectedIconColor`, `barHeight`.
- **Quatre libellés du chrome sortis du code** vers les tables de localisation ; la garde de couverture des clés balaie désormais aussi ce paquet, qui lui échappait.
- **Garde de source** pour ce paquet, qui n'en avait aucune : elle encadre le fichier de référence et **déclare** ce qu'elle ne couvre pas encore, au lieu de le prétendre couvert.

### Corrigé
- 🔴 **`themedBarBackground` était INERTE** en affichage sur une seule ligne — le mode dans lequel la barre de formulaire est **toujours** rendue : basculer le drapeau changeait **0 pixel sur 1 823 500**. Quill peignait son propre conteneur aux bornes exactes de la décoration du socle, et **après** elle — fond et liseré compris. Le drapeau agit désormais, et une garde l'asserte **au pixel** : les sept tests qui le citaient montaient un carré de 10 dp à la place de la vraie barre et seraient restés verts.

### Modifié
- Les dartdocs qui promettaient « aucun chrome déclaré ⇒ rendu inchangé » sont **réécrites** : la promesse a changé en même temps que le code.

### Attention
- **Le rendu d'un hôte passif change** — c'est l'objet de cette version.
- 🔴 **Un hôte francophone qui ne monte pas le delegate de localisation verra l'anglais** là où le paquet écrivait le français en dur.
- La hauteur de barre du legacy (42 dp) **n'est pas adoptée en défaut** : les boutons portent le plancher interactif de 48 dp, que la forcer rognerait. `barHeight` est exposé, avec cet avertissement.

## 3.14.0 — 2026-08-24

### Ajouté
- **Copie multi-format** : au geste de copie du lecteur, un menu propose les formats déclarés par l'hôte (clé, libellé par clé l10n, transformation du contenu) ; sans déclaration, la copie directe actuelle est inchangée.
- **État vide relayé** : `placeholder`, `emptyIcon`, `emptySubtitle` et `emptyBuilder` du lecteur sont atteignables depuis le champ de formulaire ; sans déclaration, rendu inchangé.

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
