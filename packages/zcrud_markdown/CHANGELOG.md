# Changelog

Toutes les modifications notables de `zcrud_markdown` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.35.0 — 2026-08-29

### Ajouté

**Couture d'échec de formule (CR-IFFD-129).** `ZRichTextFormulaSpec` gagne un
`fallbackBuilder` : quand le moteur de rendu refuse une formule, c'est ce repli
qui rend, à la place de l'icône d'erreur. Il reçoit la source soumise au moteur
et l'erreur. `null` ⇒ **rendu strictement inchangé**. Un second moteur (WebView
ou autre) reste ainsi entièrement chez l'hôte : aucune dépendance n'entre dans
le paquet, et le gate d'isolation qui bannit `flutter_tex` reste intact et
vert. La spec voyageant par champ, une seule déclaration couvre le lecteur ET
l'éditeur. Un repli qui lève est neutralisé (AD-10) : l'icône du socle reprend
la main.

**Normalisation de sources LaTeX héritées (CR-IFFD-130).** Trois fonctions
PURES, publiques : `zFixLatexLineBreaks` (un `\` isolé en fin de ligne devient
`\\`, une formule multi-lignes sans environnement est enveloppée dans
`\begin{cases}…\end{cases}`), `zUnescapeLatexCommands` (`\\frac` → `\frac`, sur
le dictionnaire `kZLatexCommands`) et `zAutoDelimitLatex` (le LaTeX nu d'un
texte est entouré de `$…$`, les régions déjà délimitées étant repérées puis
exclues — jamais de doublement). Deux compositions : `zNormalizeLegacyLatexSource`
pour une source de formule, `zNormalizeLatexInText` pour un texte.

Les deux premières sont **ACTIVES** sur le chemin de lecture hérité
(`formula` / `formula_inline`) : ces charges viennent d'un pipeline d'écriture
qui n'est plus le nôtre, et sans réparation elles n'affichaient qu'une erreur.
Nos propres clés (`latex` / `latexBlock`) traversent nues. Rien n'est normalisé
à l'écriture : la migration reste à sens unique, la charge persistée n'est
jamais touchée. Une formule déjà valide traverse **octet pour octet**.

⚠️ **Écart assumé avec la demande.** La CR demandait les *trois* réparations sur
le chemin hérité. Mesuré : l'auto-délimitation opère sur du **texte**, pas sur
une source de formule ; entourer de `$…$` la charge nue d'un embed la rendrait
au contraire illisible pour le moteur. Elle est donc livrée comme fonction pure
applicable au Markdown avant décodage, jamais appliquée d'office à une source.
Le dictionnaire compte **79** commandes (la CR en annonçait 81 ; recomptage de
la source citée). Un `latexSourceNormalizer` (`sourceNormalizer` sur la spec)
permet en outre de brancher sa propre réparation, sur tous les types de formule
du champ.

**Éditeur de tableau paramétrable (CR-IFFD-131).** `ZTableEditorScope` (nouveau,
opt-in) porte trois réglages jusqu'au dialogue ouvert par la barre d'outils :
`maxDim` (borne des dimensions ; défaut `kZTableDefaultMaxDim` = **12**,
inchangé), `cellWidth` (largeur d'une colonne de saisie ; défaut 96) et
`cellBuilder` — un `ZTableCellEditorBuilder` qui reçoit contexte, coordonnées,
valeur et rappel de changement, et remplace le champ de texte d'une cellule par
ce que l'hôte veut y monter. Scope absent ⇒ **dialogue historique, rendu
inchangé**. Les mêmes paramètres existent sur `showZTableDialog`.

**Rendus d'embed déclarés par l'hôte (CR-IFFD-132).** `extraEmbedRenderers` sur
les trois points de montage publics (`ZMarkdownField` — deux voies —,
`ZMarkdownReader`, `ZRichTextFullscreenDialog`), sur le point d'entrée
`showZRichTextFullscreenDialog` et sur `registerZMarkdownFields`. Vide (défaut)
⇒ la liste passée à l'éditeur est la **constante du socle elle-même** (identité
préservée, aucune allocation, AD-2).

*Règle de collision, figée et gardée* : un rendu déclaré par l'hôte **gagne**
sur celui du socle pour la même clé, parce que les rendus déclarés sont placés
en TÊTE et que l'éditeur retient le premier builder dont la clé correspond
(mesuré dans `flutter_quill`). Entre deux rendus déclarés à même clé, le premier
de la liste gagne. Le socle n'est pas amputé : son builder reste dans la liste,
derrière.

⚠️ **Écart assumé avec la demande.** La CR demandait `List<EmbedBuilder>`, un
type de `flutter_quill` : l'accepter dans une signature publique aurait obligé
tout hôte à dépendre de l'éditeur (AD-1). Le paramètre prend donc un
`ZEmbedRenderer` **neutre** — une clé, un `Widget Function(context, data,
textStyle)`, un booléen « occupe sa ligne » — adapté au contrat de l'éditeur
sous `lib/src/`. Un rendu déclaré qui lève est neutralisé (AD-10).

**Règles de conversion HTML fournies par l'hôte (CR-IFFD-133).**
`ZHtmlCodec({customBlocks})` relaie ses règles à `HtmlToDelta`. Vide (défaut) ⇒
décodage strictement inchangé. C'est de la **conversion**, pas du rendu : un
fragment porteur de LaTeX devient une op Delta native au lieu de dégrader en
texte, et le rendu reste celui des embeds — AD-12 intact, aucune WebView.

### Corrigé
- `zAutoDelimitLatex` ne mange plus l'espace qui suit une formule nue (défaut
  présent dans le code d'origine porté) : les blancs de bord capturés par
  l'expression sont ré-émis hors des délimiteurs.

### Note aux hôtes
Livraison **entièrement additive** : un hôte **passif** n'a rien à faire, tous
les défauts reconduisent le comportement d'avant. Un hôte qui **compensait** en
revanche :
- s'il faisait tourner un second moteur de formules en amont du socle, il le
  retire du chemin socle le jour où il pose `fallbackBuilder` — sinon les deux
  s'additionnent ;
- s'il normalisait lui-même ses sources LaTeX héritées avant de les passer au
  socle, cette normalisation est désormais faite par le chemin de lecture
  hérité ; la sienne devient redondante (elle reste inoffensive, les fonctions
  étant idempotentes, mais elle n'a plus lieu d'être).

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
