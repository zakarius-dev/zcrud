# Handoff **v0.49.0** — CR-IFFD-63 → 67 : cinq CR, dont une perte de données réelle

> **Tag à épingler : `v0.49.0`** · aucune rupture d'API.
> 🔴 **DEUX points à lire avant tout le reste** :
> * § 4 — **une perte de données silencieuse est CONFIRMÉE par la mesure** (CR-66), et une
>   **corruption de LaTeX en bloc** a été trouvée au passage. Elle vous concerne aujourd'hui.
> * § 3 — `ZContentHubSheet` **change de rendu par défaut**, sur **décision du propriétaire du
>   socle**, et cette décision **contredit délibérément** un passage de votre CR-65. Dit
>   franchement ci-dessous.

---

## 1. CR-IFFD-63 — la typographie de l'en-tête

Votre constat est **confirmé** : titre sans `style:` (22/w400), `TabBar` sans `labelStyle` ni
`unselectedLabelStyle`, aucun jeton d'en-tête (grep négatif : 0 résultat avant le lot). Les
onglets sont **tous deux en w500** — seule la couleur les distingue, avec l'indicateur.

### 🔴 Le contournement que vous n'aviez pas vu existe — et il CASSE

`ZPageScaffold.title` est typé **`Object`** : un `Text('…', style: …)` est accepté. Nous avons
donc cru un instant votre CR trop sévère. **Mesuré, l'échappement est un piège** :

> `Text('x', style: textTheme.titleLarge)` + `gradientKey` ⇒ couleur peinte **`0x1D1B20`**
> (`onSurface`) au lieu de `onGradient` — **titre sombre sur app-bar teintée**.
> Cause : les rôles `TextTheme` sont en **`inherit: false`** (c'est CR-IFFD-42 qui rejoue).

Un style **héritant** (`TextStyle(fontWeight: w700)` seul) fonctionne, lui. Votre CR avait
raison, pour une raison qu'aucun de nous deux n'avait identifiée.

### 🔴 Deux pièges du SDK — votre demande LITTÉRALE produisait l'inverse

1. Un `labelStyle` **coloré** **détruit la sélection** : les deux onglets rendent la même
   couleur (`_TabStyle._resolveWithLabelColor` : `… ?? labelStyle?.color ?? …`). « Métriques
   seules » n'est donc pas un choix de goût, c'est une **contrainte**.
2. Régler le **seul** `labelStyle` — ce que la CR demandait — met **TOUS** les onglets en gras
   (`unselectedLabelStyle ?? … ?? labelStyle`), en silence. Neutralisé : votre `TabBarTheme`
   est préservé.

### Livré
4 jetons `ZcrudTheme` (`pageHeaderTitleStyle`, `pageHeaderSubtitleStyle`,
`pageHeaderTabSelectedLabelStyle`, `pageHeaderTabUnselectedLabelStyle`) + les paramètres
correspondants sur `ZPageScaffold`, `ZPageShellBody` et `ZSearchableAppBar`.
**Priorité paramètre > jeton > défaut**, gardée. Mode recherche **explicitement hors
périmètre**, gardé.

### Vos « non mesuré », mesurés
* **`mode:` ne change RIEN** à la typographie : les 4 modes rendent 22/w400 et 14/w500.
* **`textScaler` SATURE à 1.34** (l'`AppBar` le borne) : 22 → 29,48 dp au maximum. Seuil
  d'ellipse ≈ **12 car. / 368 dp** dès 1.34, identique à 1.6, 2.0 et 3.0. Par taille :
  22→16 car., 24→15, 26→14, 28→13. Largeurs offertes : 288/368/568 dp sans voisins,
  184/264/464 dp avec leading + action.
* 🔴 **Le POIDS n'est pas mesurable dans notre harnais** : sa police a des avances
  **identiques** en w400/w500/w600/w700 (`largeur("M"×10) = 140.00` pour les quatre). Nous ne
  chiffrons donc **pas** « le gras s'ellipse plus tôt ». Nous ne l'inventons pas non plus.

### Défaut : **inchangé**, et c'est un arbitrage
Sans jeton ni paramètre, le rendu est **identique au pixel**. Nous n'appliquons pas le défaut
distinctif que votre § CR-56 suggère : `ZPageScaffold` est **générique**, un titre plus gras
coûterait des caractères à lex_douane, qui ne l'a pas demandé. La capacité vous est donnée ;
le défaut reste votre décision.

### 🔵 Défaut PRÉEXISTANT trouvé, NON corrigé
Sous dégradé, le **champ de recherche** rend `onSurface` — texte saisi sombre sur app-bar
teintée. Même famille que ci-dessus, hors périmètre du lot. **Signalez-vous si ça vous gêne**,
c'est une CR d'une ligne.

---

## 2. CR-IFFD-64 — la carte de dossier

### ③ est NUANCÉE : le patron existait déjà
Votre « aucun jeton de bordure n'existe » est vrai **pour `ZFolderCard`** — mais
`ZcrudTheme.studyCardBorderSide` existe pour la famille sœur et est consommé par le résolveur
de chrome. Le manque n'était pas une absence de patron, mais sa **non-réplication**. Nous
avons donc **répliqué**, sans inventer un second mécanisme.

### 🔴 Votre réserve ⑤.2 n'était pas une précaution de forme — l'algorithme CASSE

Vous écriviez ne pas avoir éprouvé `zReadableTypeTint` sur des couleurs arbitraires, et que
« c'est peut-être le vrai travail de cette CR ». **Ça l'était.** Mesuré (thème clair, contre
`scaffoldBackgroundColor`) :

| entrée | sortie | contraste | verdict |
|---|---|---|---|
| `#FFFF00` jaune | `#B3B300` | **2.13** | échec (< 3.0) |
| `#00FF00` vert | `#00B300` | **2.68** | échec |
| `#FFFFFE` quasi-blanc | `#E5E500` | **1.28** | **pire que sans traitement** |
| `#667EEA` (votre violet) | `#1732AB` | 9.59 | OK |

**Cause racine** : la fonction borne la **clarté HSL**, qui ne dit rien du contraste. À clarté
égale, un jaune pèse `0.2126 + 0.7152 = 0.928` de luminance WCAG contre `0.2126` pour un
rouge. Votre jeu fermé (violet/vert/cyan/rose) **évite la zone jaune par chance de
conception** — son pire score est 5.28. Une couleur de dossier est choisie par l'utilisateur :
un sélecteur libre y tombe trivialement.

### 🔵 Et un défaut PLUS BANAL, que personne n'avait vu
> **Un gris devient ROUGE.** HSL attribue la teinte `0` à tout achromatique, et la
> plancherisation de saturation à `0.4` le colorise : **`#808080` → `#7D3636`**.
> Un utilisateur choisissant un dossier gris obtenait un liseré rouge.

### Livré
`zReadableTintOn` (fichier dédié) corrige en **luminance linéaire**, pas en clarté HSL :
assombrir = baisser l'exposition des canaux linéarisés, ce qui **préserve la chromaticité
exactement** (un gris reste gris, mesuré). Plancher garanti sur un **balayage** de l'espace des
teintes, dans les deux luminosités.
🔴 **`zReadableTypeTint` est INCHANGÉE** : les 4 sorties de votre jeu fermé sont
**byte-identiques**, gardé par injection.

Plus : `ZFolderCardReference` (vos 17 constantes, exception FR-26 encadrée + exemption
nominative), `ZDefaultFolderCard` (la sixième de la famille), `borderSide` sur `ZFolderCard`,
et les jetons `folderCard*`.

### ④ archivé : il n'y a RIEN à porter
Triple grep négatif chez vous : **aucun rendu visuel d'archivage** dans `folders_page.dart`,
et `isArchived` n'est même pas câblé jusqu'à `ZFolderCard` dans votre port. Le socle est en
**avance** sur ce point. Nous n'avons donc rien inventé — nous avons seulement mesuré que le
cumul teinte + archive reste lisible.

---

## 3. CR-IFFD-65 — 🔴 DÉCISION DU PROPRIÉTAIRE, qui CONTREDIT votre CR

Votre CR écrit, section « Ce que nous ne demandons PAS » :

> « La densité du socle est meilleure […] nous ne demandons pas de le défaire. »
> « Le groupement et le repérage ne demandent pas de doubler la hauteur d'un item. »

**Le propriétaire du socle a arbitré l'inverse** : reproduire **intégralement** le design
legacy, **défilement assumé**. C'est une **décision de conception**, PAS une mesure et PAS une
parité que vous auriez réclamée — nous le disons dans les mêmes termes que vous avez employés
pour votre `studyCardElevation: 1`.

🟢 **Votre argument d'échelle n'est pas réfuté, il est déplacé** : à douze types, la mise en
page legacy demanderait plusieurs écrans. La réponse est un **réglage**, pas le défaut :

> **`density: ZContentHubDensity.compact`** (paramètre) **ou**
> **`ZcrudTheme(contentHubDensity: compact)`** (jeton) restitue **exactement** la densité
> d'avant. Les deux voies sont gardées.

### 🔴 CE QUI CHANGE À L'ÉCRAN POUR UN HÔTE PASSIF
`ListTile` → **carte** (liseré `outlineVariant`, rayon 16, padding 8) · hauteur **48 → 112 dp**
(défilement dès ~5 entrées) · glyphe nu → **pastille 40 dp teintée à 10 %** · **chevron
ajouté** · `hint` passe de `subtitle:` à une 2ᵉ ligne · **≥ 600 lp ⇒ grille 2 colonnes** ·
padding de liste modifié.
⇒ **Hôte ayant compensé** par un `Theme`/`ListTileTheme` englobant : **RETIREZ la
compensation**, elle s'additionnerait.

### Quatre de vos affirmations sont INFIRMÉES
1. **La 6ᵉ teinte n'est pas indigo** : `Colors.deepPurple` = `0xFF673AB7` (l.337).
   `grep -n "Colors.indigo"` ⇒ **vide**.
2. **Le badge n'est pas « une bande verte pleine largeur »** : c'est un `Container` confiné au
   slot `title:` d'un `ListTile` ; le libellé réel est un `Text` séparé en dessous (l.447-484).
3. 🔴 **Le chevron legacy n'a PAS de défaut RTL** — et c'est **notre** consigne de lot qui était
   fausse, pas votre CR : `Icon` ne porte aucune propriété `matchTextDirection` ; elle vit sur
   **`IconData`**, et `Icons.arrow_forward_ios` la porte **déjà à `true`**
   (`icons.dart:2510-2514`). Il se retourne correctement. Le socle force néanmoins le repli
   pour un chevron **injecté** qui ne la porterait pas.
4. **Le fond de carte n'est pas teinté** : legacy l.415-423 = `Card(elevation: 0)` sans couleur
   de fond. Seuls la pastille et le badge le sont (0.1). Le jeton `contentHubItemTintAlpha`
   existe, **défaut 0**.

### Vos « non mesuré », mesurés
* **Grille** : `crossAxisCount = 2` dès **600 lp** — vous aviez retiré cet écart par prudence,
  il est réel. Les deux régimes sont gardés.
* **Thème sombre** : votre legacy n'a **aucune** branche `Brightness` (grep vide) — mêmes hex,
  même alpha. Le socle **garantit** désormais glyphe ≥ 3.0:1 et badge ≥ 4.5:1 sur la surface
  réellement composée, pour les 6 teintes **et** un extrême injecté.
* **Insertion au milieu** : **aucune teinte ne bouge** — le créneau est fonction de `colorKey`,
  jamais de la position.
* **Échelle** ×1/×2/×3, étroit et large : zéro débordement.

### Livré
`ZContentHubReference` · `ZContentHubSection` · `ZContentHubEntry.{tint, colorKey, badgeLabel,
badgeSemanticLabel}` · 16 paramètres de forme · **14 jetons `contentHub*`** · `ZContentHubDensity`.
Votre détournement de `hint` pour « Recommandé » **devient inutile** : `badgeLabel` existe, et
il reste **textuel donc accessible**. Aucun libellé français en dur — tout est injecté.

---

## 4. CR-IFFD-66 — 🔴 LA PERTE EST RÉELLE, mesurée

Vous l'affirmiez « comme une lecture de deux contrats, pas comme une mesure ». **Nous l'avons
reproduite** (mapper hôte répliqué verbatim + éditeur + frappe réelle) :

```
content typé        = '# Titre markdown legacy MODIF'   ← la frappe est là
extra[iffd_content] = '# Titre markdown legacy'         ← figé
relecture hôte      = '# Titre markdown legacy'         ← LA MODIFICATION EST PERDUE
```

Vous aviez raison **sur le symptôme ET sur la cause**.

### 🔵 Mais la fidélité perdue est celle de VOTRE encodeur, pas du codec du socle
Round-trip caractérisé sur **46 constructions** — la mesure que vous demandiez et que personne
n'avait faite :

| banc | trajet | survie |
|---|---|---|
| A | `String → ops → String`, **octet** | 1/46 |
| A2 | idem, tolérant au `\n` final | 31/46 |
| B | `ops → String → ops` (sémantique) | **46/46** |
| C | votre trajet réel, contenu **non édité** | **46/46** |
| D | votre trajet sur ops **éditées** | **0/4** |

> La ligne D est décisive : la perte vient de **`_opsToStringOrNull`, que vous avez écrit**
> (concaténation des `insert` texte ⇒ jette gras, titres, listes, embeds).
> `ZMarkdownCodec.encode` fait nettement mieux sur ces quatre cas.

**Cassent réellement (8)** : LaTeX **bloc**, fusion du saut de ligne simple (`a\nb` → `a b`),
citation multi-lignes, retour souple, espaces de fin de ligne, lignes vides multiples, entités
HTML, espaces seuls. **7 autres ne sont que des normalisations de forme** (`*x*`→`_x_`,
indentation 2→4). **Survivent** : titres H1-H6, gras, barré, code inline et blocs, listes,
imbrication, cases, liens, images avec ALT, **LaTeX inline**, unicode, emoji, **RTL arabe /
hébreu / mixte**.

### 🔴 CORRUPTION DE DONNÉE trouvée au passage — elle vous concerne AUJOURD'HUI
> `$$\int_0^1 x\,dx$$` → `$$\\int\_0^1 x,dx$$`
> Antislash **doublé**, `\,` **détruit**. Ce n'est pas une perte de mise en forme, c'est une
> **altération**. Elle vit dans `zcrud_markdown`, **hors du périmètre de ce lot** (le paquet
> n'a été que *lu*). **Candidat CR amont** — signalez-vous, nous la traiterons en priorité.

### Pourquoi la voie (b) est écartée — et l'argument n'est pas celui qu'on attendait
Non seulement le round-trip parfait est inatteignable comme égalité de `String`, mais **il ne
réglerait rien** : même avec un codec parfait, l'éditeur n'écrirait toujours **qu'un canal sur
deux**. Le défaut est dans le **contrat d'écriture**, pas dans la fidélité du codec.

### Livré — strictement additif
`ZNoteContentFaithChannel {extraKey, encode}` + paramètre **optionnel** `faithChannel` sur
`ZSmartNoteEditor`. `onChanged` inchangé, aucun symbole supprimé, `const` préservé.
Deux détails : `encode → null` **retire** la clé (jamais une valeur périmée qui ressusciterait
le corps), et un `assert` en debug si vous déclarez une clé réservée (canal qui serait
silencieusement inerte).

⚠️ **`folderId`/`title`** : le motif **ne s'étend pas** par ce widget (grep négatif montré),
mais il frapperait tout futur widget du socle éditant ces champs. Consigné.

---

## 5. CR-IFFD-67 — les actions de nœud

Votre cause est **confirmée par mesure** : le bouton suivait littéralement le viewport —
**720 dp** de large à 720 dp, **1200 dp** à 1200 dp.

| à 720 dp, un nœud | avant | après |
|---|---|---|
| hauteur | **472 dp** | **160 dp** |
| largeur d'un bouton | **720 dp** | **48 dp** |
| **boutons par ligne** | **1** (7 lignes) | **7** (1 ligne) |

Le plancher devient **réellement actif** : `minTapTarget: 96` ⇒ 96×96 ; `120` ⇒ 2 lignes.

### 🔴 Ce que votre CR ne pouvait pas voir : nos gardes étaient VACANTES
Deux injections opposées, sur le code **avant** correction :
* `minWidth: 24` **et** `minHeight: 24` → **ROUGE** — mais c'est l'axe **hauteur** qui mordait ;
* `minWidth: 1` **seul** → **VERT** — l'axe **largeur** était **entièrement inerte**.

La garde ne défendait pas le défaut : elle le **couvrait**. Retournée, et la nouvelle est
falsifiable par construction (égalité à une valeur configurée, jamais un `>= 48`).

⚠️ **Honnêteté de mesure** : `heightFactor` est **inerte** ici (`Wrap` et `Row` offrent une
hauteur non bornée) — mesuré, conservé comme défense, et **écrit dans le code** plutôt que
laissé croire qu'une garde le prouve.

### ② État vide
`emptyBuilder` (reçoit `onAddRoot`), `emptyTitle`/`emptyMessage`/`emptyActionLabel`
(**`String?`, sans défaut littéral** — canal `ZMindmapOutlineLabels` existant),
`config.emptyIconSize`.
**Arbitrage** : la **structure est toujours rendue, le texte jamais imposé**. Sans injection ⇒
affordance **visible, centrée** (dx=360/720 mesuré), actionnable, ≥ 48 dp, annoncée — et
**aucun `Text`** (gardé). Un libellé français en dur aurait violé FR-26 ; un état vide absent
aurait redonné la page blanche que vous mesurez.

### Échelle et large
×1.0/×1.5/×2.0 → nœud 160/184/208 dp, **7 boutons sur 1 ligne dans les trois cas** (les icônes
Material ne suivent pas le `textScaler`). Le passage à la ligne est donc prouvé **séparément**.
**Large mesuré, NON implémenté** (hors périmètre, comme vous le demandiez) : 720 → 1600 dp
donnent une **colonne unique**, champs étirés, **aucun point de rupture** — le côte-à-côte
legacy n'est pas approché.

---

## 6. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | posez vos jetons `pageHeader*` (§ 1) ; adoptez `ZDefaultFolderCard` (§ 2) ; **retirez votre détournement de `hint`** au profit de `badgeLabel` (§ 3) ; **déclarez votre `faithChannel`** — c'est le § 4, et c'est le plus urgent ; rien à faire pour § 5 |
| **hôte passif du hub** | 🔴 **votre rendu CHANGE** (§ 3) — c'est assumé, `density: compact` restitue l'ancien |
| **hôte passif ailleurs** | rien — en-tête, carte de dossier, éditeur de note et mindmap sont **inchangés sans réglage**, gardés |
| 🔴 **hôte ayant compensé** le hub par un `Theme`/`ListTileTheme` | **RETIREZ la compensation** |
| 🔴 **hôte éditant des notes migrées** | **déclarez `faithChannel`** — sans lui, le défaut du § 4 reste entier |

🟢 **Tripwires recommandés** : un test qui affirme votre détournement de `hint` (il rougira à
l'adoption de `badgeLabel`) ; et surtout **un test de round-trip note qui affirme la perte du
§ 4** — il rougira le jour où vous déclarerez le canal, et vous désignera le doublon.

---

## 7. Vérification

`melos generate` **RC=0** (0 `.g.dart` modifié) · `melos analyze` **RC=0** · `melos verify`
**RC=0** (ACYCLIQUE + CORE OUT=0 + corpus de sérialisation, 36 paquets) · `dart pub get`
résolu (91 contraintes).

`zcrud_study` **1345** (+75) · `zcrud_core` **1236** (+23) · `zcrud_mindmap` **223** (+16) ·
`zcrud_ui_kit` **218** (+25) · `zcrud_note` **173** (+11) · voisins inchangés : flashcard 586,
session 565, study_kernel 383, exam 79, chat_study 67. **0 error, 0 warning** partout.

**R3 — 59 injections mordantes** : 10 (CR-63) + 14 (CR-64, **rejouées intégralement par
l'orchestrateur**, l'agent rédacteur ayant été perdu — intégrité prouvée bit à bit) +
18 (CR-65) + 5 (CR-66) + 12 (CR-67). Toutes **ROUGE-ASSERTION**, aucun rouge de compilation.

🟢 **Quatre gardes VACANTES démasquées et retournées** pendant ces lots : la cible tactile de
`zcrud_mindmap` (§ 5), un `MergeSemantics` inerte et une garde « ×3 » non mordante (CR-65), et
une garde de priorité insensible au paramètre (CR-63). Une garde verte n'est pas une garde qui
mord.

### 🔵 Correction d'une affirmation de NOS handoffs précédents
Nous avons écrit plusieurs fois « **aucun golden nulle part** ». **C'est faux** :
`zcrud_study/test/golden/` en porte trois, dont `z_folder_card_neutral.png`. Ils ont servi ici :
après CR-64, la carte de dossier d'un hôte passif est **byte-identique** — preuve au pixel,
indépendante de nos gardes de valeurs.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 8. Ce que nous savons ne pas avoir couvert

* 🔴 **La corruption LaTeX-bloc de `ZMarkdownCodec`** (§ 4) — altération de donnée réelle,
  candidat CR amont, non traitée dans ce lot.
* Le **défaut de couleur du champ de recherche** sous dégradé (§ 1) — préexistant, non corrigé.
* **Deux gardes de la même famille inerte** subsistent dans `ZMindmapView`
  (`z_mindmap_view_test.dart:164`, `z_mindmap_view_controls_test.dart:348`) : elles lisent les
  `constraints`, pas la géométrie rendue. Lot dédié.
* Le **côte-à-côte en large** de l'éditeur de mindmap (§ 5) : mesuré, non implémenté.
* Aucun **golden de la nouvelle carte de hub** : les valeurs sont gardées, la parité pixel ne
  l'est pas.
* La dette FR-26 des replis français de `ZMindmapOutlineLabels` — la corriger serait une
  rupture d'API.
* `hint` long en densité confortable : tronqué, aucun `maxLines` exposé.
