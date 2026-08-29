# Changelog

Toutes les modifications notables de `zcrud_study` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.29.0 — 2026-08-28

### Ajouté
- `ZMindmapGenerationController` : orchestration du flux de génération de carte
  mentale par IA au-dessus de `ZMindmapGenerationPort`, jusque-là sans aucun
  consommateur de présentation (le port existait, rien ne l'appelait).
  `ChangeNotifier` pur, statut en enum `idle → generating → reviewing | empty |
  failed`, jeton de fraîcheur monotone, anti-double-soumission.
- `ZMindmapGenerationSheet` : feuille de saisie (sources, contenu, instructions
  libres, option « résumer »), revue des nœuds générés dans
  `ZMindmapOutlineEditor` — la surface d'édition d'outline existante, pas un
  éditeur parallèle — puis validation.
- `ZMindmapGenerationScope` : injection Flutter-native d'un port optionnel.
- `ZMindmapGenerationLabels` / `ZMindmapGenerationMessages` /
  `ZMindmapGenerationSourceOption` : libellés et sources INJECTÉS, tous requis.
- `ZStudyMindmapSection.generationPort` / `.onGenerate` /
  `.generateSemanticLabel` / `.generateIcon` (et les mêmes sur `sectionSpec`) :
  action « générer par IA » dans le chrome de la section.
- `ZMindmapGenerationRequest.summarize` (défaut `false`) : demande de
  condensation plutôt que de développement.
- `ZMindmapGenerationRequest.routeId` + `withRouteId` : identifiant de ROUTE
  opaque, transporté verbatim. Le mode « une route par intention de
  génération » est désormais porté par la requête au même rang que
  l'endpoint unique ; sa résolution en transport reste côté application.

### Garanties
- **Hôte passif strictement inchangé** : sans port, `ZStudyMindmapSection` rend
  un arbre IDENTIQUE au widget près (recensement ordonné de 69 entrées capturé
  AVANT le lot et figé en garde), et le même nombre d'actions. L'action de
  génération est ABSENTE de l'arbre, jamais grisée ni inerte : port, rappel et
  libellé sont indissociables.
- **Rien n'est écrit avant validation** : le seul canal de sortie est le
  handoff `onGenerated`, et c'est l'application qui écrit. `Left` ⇒ `failed`
  avec le `ZFailure` typé exposé (`lastFailure`) ; exception du port ⇒ `failed`
  sans `ZFailure` fabriqué ; forêt vide ⇒ `empty`, qui n'est pas un échec.
  Dans les trois cas, zéro écriture (mesuré par un dépôt en mémoire à
  compteur). Aucune exception ne remonte de `generate`.
- **Les nœuds ÉDITÉS sont ceux qui partent à l'écriture** : la validation émet
  la forêt mutée dans la revue, jamais la forêt d'origine. La carte remise
  porte un `id` vide — aucune identité n'est fabriquée par ce paquet.
- **SM-1** : les `TextEditingController` sont créés une seule fois ; la saisie
  et le focus survivent aux changements d'état, et un changement d'état ne
  reconstruit pas la surface hôte.
- `generateMindmap(` n'est appelé que depuis le contrôleur (garde de source :
  toute seconde voie d'appel dans `lib/` fait rougir).
- Aucun libellé ni couleur en dur dans les fichiers du lot ; le libellé de
  l'action de génération n'a délibérément aucun défaut de constructeur.

### Impact hôte
- Hôte **passif** : rien à faire, rien ne change.
- Hôte ayant **assemblé lui-même** la génération autour de
  `ZMindmapGenerationPort` (contrôleur maison, feuille maison, bouton posé à
  côté de la section) : sa surface s'ADDITIONNE désormais à celle du socle dès
  qu'il câble `generationPort`. Deux actions « générer » apparaîtraient dans le
  chrome de `ZStudyMindmapSection` — retirer la sienne, ou ne pas câbler le
  paramètre et conserver la sienne.
- Hôte ayant **assemblé lui-même** le résumé de note autour de
  `ZNoteSummaryPort` : même règle, à propos de `ZDefaultNoteCard.summaryPort`
  et de son action « résumer ».

### Ajouté — résumé de note par IA (consommateur de `ZNoteSummaryPort`)
- `ZNoteSummaryController` : orchestration du flux de résumé au-dessus de
  `ZNoteSummaryPort`, jusque-là sans aucun consommateur de présentation (le
  port existait, rien ne l'appelait). `ChangeNotifier` pur, statut en enum
  `idle → summarizing → reviewing | empty | failed`, jeton de fraîcheur
  monotone, anti-double-soumission.
- `ZNoteSummarySheet` : saisie du contenu à résumer, revue du texte produit,
  puis **deux issues** remises à l'application — `onInsertAtTop` (insérer le
  résumé en tête de la note) et `onCreateNote` (nouvelle note).
- `ZNoteSummarySheet.summaryBuilder` : slot de rendu injecté du résumé
  (`null` ⇒ texte brut thématisé). C'est par là qu'une lecture Markdown entre,
  **fournie par l'application** : `zcrud_study` ne dépend d'aucun moteur de
  rich-text, et une garde de source interdit d'en importer un ici (AD-1).
- `ZNoteSummaryScope` : injection Flutter-native d'un port optionnel.
- `ZNoteSummaryLabels` / `ZNoteSummaryMessages` : libellés et messages
  INJECTÉS, tous requis.
- `ZDefaultNoteCard.summaryPort` / `.onSummarize` / `.summarizeSemanticLabel` /
  `.summarizeIcon` : action « résumer » dans le créneau d'actions de la carte,
  qui **s'ajoute** au `trailing` de l'hôte sans le remplacer.

### Garanties — résumé de note
- **Hôte passif strictement inchangé** : sans port, `ZDefaultNoteCard` rend un
  arbre IDENTIQUE au widget près (recensement ordonné de 45 entrées capturé
  AVANT le lot et figé en garde), le même nombre d'actions (aucune), et le
  `trailing` de l'hôte traverse **tel quel**, sans rangée interposée. L'action
  est ABSENTE de l'arbre, jamais grisée ni inerte : port, rappel et libellé
  sont indissociables.
- **Le socle ne persiste rien** : aucun dépôt n'est importé en présentation.
  Le résumé sort par les deux handoffs, et c'est l'application qui écrit.
  `Left` ⇒ `failed` avec le `ZFailure` typé exposé (`lastFailure`) ; exception
  du port ⇒ `failed` sans `ZFailure` fabriqué ; texte vide ⇒ `empty`, qui n'est
  pas un échec. Dans les trois cas, zéro handoff (mesuré par un dépôt en
  mémoire à compteur). Aucune exception ne remonte de `generate`.
- **Le texte remis est celui du port, à l'octet près** : la revue est en
  LECTURE, blancs de bord compris. Une issue sans handoff est absente de
  l'arbre ; un geste appelle au plus un handoff, et le retour à `idle` rend un
  second appel inopérant.
- **`summarize` n'est appelé qu'une fois par geste** : anti-double-soumission
  du contrôleur, doublée du désarmement du bouton pendant la requête.
- La requête voyage verbatim (contenu, longueur cible, langue, échappatoire).
  `ZNoteSummaryRequest` **ne porte aucun identifiant de route** : rien n'en est
  donc transporté de ce côté, et rien n'en est fabriqué.
- **SM-1** : le `TextEditingController` est créé une seule fois ; la saisie et
  le focus survivent aux changements d'état, et un changement d'état ne
  reconstruit pas la surface hôte.
- `summarize(` n'est appelé que depuis le contrôleur (garde de source : toute
  seconde voie d'appel dans `lib/` fait rougir).
- Aucun libellé ni couleur en dur dans les fichiers du lot ; le libellé de
  l'action « résumer » n'a délibérément aucun défaut de constructeur.

### Limite connue — résumé de note
- La revue **n'édite pas** le résumé. Une application qui veut le laisser
  retoucher avant écriture le fait dans sa propre surface, à partir du texte
  reçu par le handoff.
- Le slot d'échappatoire de la feuille s'appelle `requestExtra`, pas `extra` :
  une surface de présentation n'est pas un porteur d'`extra` persisté et n'a
  donc ni stockage ni filtre propre (AD-19.1) — elle relaie vers
  `ZNoteSummaryRequest`, qui écarte les clés de synchronisation réservées.

## 3.28.0 — 2026-08-28

### Ajouté
- `ZExamEditor.showWeeklyReminders` (défaut `false`) : section de **rappel
  hebdomadaire éditable**. Activée, elle rend les sept jours de la semaine
  (ordre de la locale) puis la ligne d'heure existante, et compose
  `ZExam.reminderRecurrence.weekdays` en convention ISO-8601.
- `ZExamWeekdayLabeler` + `ZExamEditor.weekdayLabeler` : libellé de jour
  INJECTÉ. Repli `MaterialLocalizations.narrowWeekdays` — aucun nom de jour
  n'est écrit dans le paquet.
- `ZExamEditor.weeklyRemindersLabel` : intitulé injecté de la section.

### Garanties
- **Hôte passif inchangé** : sans `showWeeklyReminders`, l'arbre rendu et le
  `ZExam` émis sont strictement identiques à la version précédente, et
  `reminderRecurrence` n'entre pas dans le `copyWith` de soumission — une
  récurrence portée par l'examen édité est donc préservée à l'octet, sans être
  affichée ni effacée.
- La section n'édite que la famille **hebdomadaire** : `daysBefore` de la
  récurrence initiale est reporté tel quel, et `ZExam.reminderDaysBefore`
  (champ distinct, édité par la liste de seuils) n'est jamais touché. Aucun
  jour coché et aucun `daysBefore` à reporter ⇒ `reminderRecurrence == null`,
  emplacement absent plutôt que récurrence vide.
- Chaque puce de jour : cible ≥ 48 dp sur les deux axes, nœud `Semantics` avec
  label et état `selected`, couleurs par jetons de thème
  (`selectTileSelectedBorderColor` / `selectTileBorderColor`, replis
  `ColorScheme`).

### Limite connue
- Le repli `MaterialLocalizations.narrowWeekdays` est **ambigu au lecteur
  d'écran** : en `en_US` il rend `S M T W T F S`, soit cinq libellés pour sept
  jours (mardi/jeudi et samedi/dimanche homographes). Flutter n'expose aucun
  nom de jour complet sans une date réelle. Un hôte soucieux d'accessibilité
  injecte `weekdayLabeler` avec ses noms complets ; c'est cette chaîne qui
  devient le `Semantics.label`.

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral de test remplacé par `\u0000`.

## 3.3.0 — 2026-08-21

### Modifié — le calculateur de teinte lisible est remonté au cœur

L'implémentation vit désormais dans `zcrud_core`. **Aucune rupture** : le barrel
de ce paquet ré-exporte les mêmes symboles sous les mêmes noms, et un test
existant qui les importe ainsi passe sans modification.

## 3.2.0 — 2026-08-21

### 🔴 Corrigé — la pastille de compte volait le tap qu'elle surmonte

Le badge livré en 3.0.0 pose son label **par-dessus** la tuile, et ce label est
**sensible aux gestes** : il absorbait les taps de son rectangle. Mesuré : tap au
centre **1**, tap à 8 px du coin **0**. Le tap perdu **n'émettait rien** — ni
erreur, ni retour visuel — et c'est l'action portant un artefact existant, donc
celle sur laquelle on appuie le plus.

La pastille est sortie du hit-test. Cinq montages ont été mesurés : neutraliser le
seul label **ne suffit pas** — l'absorbeur est la boîte décorée du stade, pas le
texte. **Rendu iso-pixel prouvé** : tuile, pastille, nombre et glyphe aux mêmes
rectangles.

### 🔴 Corrigé — la pastille rétrécissait la tuile, tuant la moitié de la cellule

Défaut **plus large que le précédent**, trouvé en marge et gardé : le `Stack`
portant la pastille donnait des contraintes lâches, si bien qu'une tuile **avec**
compte mesurait `93,3 × 48` là où sa voisine **sans** compte mesurait
`93,3 × 96`. La moitié basse de la cellule était **morte** — et avec un libellé
court, les **trois quarts**.

Conséquence visible : dans la même grille, le glyphe d'une action avec compte
était **24 dp plus haut** que celui d'une action sans compte. Le correctif les
**aligne** ; la pastille, elle, ne bouge pas d'un pixel (asserté en absolu et en
relatif).

La garde de preuve a été écrite **avant** le correctif et rougissait en cinq
assertions chiffrées.

## 3.1.0 — 2026-08-18

### 🔴 Corrigé — la teinte d'état n'atteignait pas un slot d'hôte

La teinte d'état livrée en 3.0.0 passait par `IconTheme.merge`, qui n'atteint
**que le contenu qui hérite**. Un slot d'hôte stylé depuis
`Theme.of(context).textTheme.*` (rôles `inherit: false`) gardait donc la couleur
ambiante et **restait illisible** — le défaut même que la teinte prétend
corriger.

Remplacé par `ZForegroundOverride`, la primitive prévue, qui réécrit **aussi**
`ThemeData.textTheme`/`iconTheme`. Trouvé par une garde **inter-paquets** de
`zcrud_core` qui scanne les sources de tous les paquets.

### Modifié — la re-pose du scope devient infaillible par construction

Les deux sites qui recopiaient le `ZcrudScope` **seam par seam** sous un
`Overlay` emploient désormais `copyWith`, qui **hérite de tout paramètre omis**.
Le défaut ne peut plus se produire, au lieu d'être rattrapé après coup.

Les commentaires du fichier recensaient **cinq** ports oubliés puis rattrapés un
par un ; les deux derniers dataient de la veille, et le **site jumeau** portait
les mêmes manquants sans qu'aucune garde ne le surveille.

La garde de structure a été **repensée, pas supprimée** : elle vérifie désormais
le **comportement** — huit seams survivent par **identité** dans la feuille et
dans la carte — et couvre **les deux** sites. Elle échouerait aussi si quelqu'un
revenait à une énumération manuelle.

## 3.0.0 — 2026-08-18

### 🔴 Corrigé — deux canaux de seams disparaissaient sous la feuille

`subListSeamRegistry` (ajouté en 1.8.0) et `selectChoiceBuilderRegistry`
(ajouté en 2.1.0) n'étaient **pas re-posés** lors de la recopie du `ZcrudScope`.
Sous l'`Overlay`, un hôte perdait donc **en silence** le rendu déclaré qu'il
venait d'obtenir.

Trouvé par la garde de structure de `cr_iffd41_subfolder_sheet_test`, qui lit la
liste **réelle** des paramètres dans la source de `zcrud_core` et exige que
chacun soit re-posé. C'est la **quatrième et cinquième** fois qu'elle mord.

**Un site jumeau, non couvert par cette garde, portait le même défaut** :
`z_default_flashcard_card` recopie le scope de la même façon. Corrigé aussi —
trouvé en cherchant le jumeau, pas en attendant qu'il se manifeste.

### ⚠️ Modifié — RUPTURE : le menu d'actions rend une grille par défaut

`ZItemActionsMenu` rendait une **colonne unique** quand aucune présentation
n'était injectée. Mesuré chez l'hôte : **aucun** de ses cinq menus n'est en
colonne, et son portage a dû réinjecter la grille à la main.

Le défaut est désormais une **grille de 3 colonnes**, via le
`ZMenuEntryTile.gridDelegate` qui existait déjà et porte le plancher de cible
tactile par construction. `crossAxisCount` est déclarable au point d'appel.

**Retour arrière en une ligne : `crossAxisCount: 1`** — prouvé par garde, pas
promis.

Trois colonnes et non deux est un **arbitrage assumé de l'hôte**, contre son
propre legacy qui en rend deux : il demande le meilleur défaut pour l'ensemble
des applications d'étude, quitte à déclarer `2` chez lui.

### Ajouté — une action porte son état

`ZItemActionState { absent, inProgress, present }` et un **compte** optionnel :
la couleur d'une action signale l'existence de ce qu'elle produit, le badge dit
combien. *« Retirer la couleur ne retire pas un ornement : cela retire
l'information. »*

**Aucune couleur codée en dur** (FR-26) : teinte dérivée du `ColorScheme` par le
patron déjà employé par `ZDefaultFolderCard` (`zReadableTintOn`, plancher de
contraste). L'état est **annoncé**, pas seulement peint — une information portée
par la seule couleur est invisible à un lecteur d'écran, et ce serait reproduire
le défaut à l'envers. Un état invalide **échoue fermé** : aucune teinte sans
annonce.

Sans état ni compte déclarés : aucun enrobage, aucun badge, aucune teinte —
rendu identique (contre-témoin à comptes absolus).

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  des sections composables, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du domaine, de la couche données et d'une
  partie de la couche présentation : première phrase autonome, invariants
  d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal, des comparatifs legacy nominatifs et des
  historiques de correctifs — conservation des invariants, cas limites et
  avertissements de contrat. Aucun changement de code — la revue ne porte
  que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study/`.
