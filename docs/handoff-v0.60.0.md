# Handoff **v0.60.0** — les quatre CR DODLP, la feuille encadrée, et trois défauts trouvés en chemin

> **Tag à épingler : `v0.60.0`**
> 🔴 **Ce lot DÉPLACE les hôtes passifs sur quatre axes visibles.** Ce n'est pas une livraison
> additive : lisez le § 6 avant de bumper. Aucun paquet nouveau (toujours 38).

---

## 0. Ce qui a déclenché ce lot

Quatre CR de **DODLP**, émises depuis son pilote de migration, restées non traitées jusqu'à ce
qu'il relocalise son registre dans `dodlp-otr/docs/cr-zcrud/`. Plus une demande du propriétaire sur
la présentation des feuilles, tirée d'IFFD.

Trois de ces CR étaient **exactes sur le symptôme et fausses sur le remède** — c'est devenu le fil
conducteur du lot, et chaque écart est justifié ci-dessous par une mesure, pas par un avis.

---

## 1. Le `select` qui déborde — corrigé sur DEUX sites

`DropdownButtonFormField` sans `isExpanded` se dimensionne sur son option la plus large ; avec un
`prefixIcon` et des libellés longs, la `Row` interne déborde (`RenderFlex overflowed by 33 pixels`).

Corrigé — et 🔵 **la CR n'en signalait qu'un**. Le second, `ZRelationFieldWidget`, porte des
libellés au moins aussi longs et souffrait à l'identique. Grep de départ : **zéro** occurrence
d'`isExpanded` dans tout `zcrud_core/lib`.

Deux gardes rougissent sur `takeException()` non nul : **le débordement se reproduit réellement**
sous injection. C'est un rouge de comportement, pas une propriété asserte à côté.

⇒ **DODLP : vous pouvez retirer le contournement `ZSelectConfig(searchable: true)`** posé sur vos
`select` à listes longues — sauf si vous préférez la modale pour l'UX, ce qui reste un choix
légitime et indépendant.

## 2. Les jetons de champ, câblés — mais pas comme la CR le proposait

`inputDecoration()` codait en dur `scheme.surfaceContainerHighest` et `scheme.outline`. C'est
corrigé. **Le remède proposé par la CR ne l'était pas** :

> 🔴 La CR affirmait que `fillColor: surfaceColor ?? …` serait « rétro-compatible strict ». Mesuré :
> `ZcrudTheme.fallback()` pose `surfaceColor = scheme.surface` (**`#FEF7FF`**) sur le chemin de
> résolution par défaut, alors que le fond rendu aujourd'hui est `surfaceContainerHighest`
> (**`#E6E0E9`**). Appliquer la CB à la lettre aurait déplacé **tous** les hôtes, silencieusement.
> Une garde asserte d'abord que les deux rôles **diffèrent**, pour ne pas être vacante.

Livré à la place — **trois jetons nullables, absents de `fallback()`**, donc hôte passif **immobile
au pixel** :

| Jeton | Consommé par | Repli |
|---|---|---|
| `fieldBorderColor` (existant) | `border` + `enabledBorder` | `scheme.outline` |
| **`fieldFillColor`** (neuf) | `fillColor` | `scheme.surfaceContainerHighest` |
| **`fieldFocusedBorderColor`** (neuf) | `focusedBorder` | `scheme.primary` |

`fieldBorderColor` était **déjà** le jeton de bordure de champ du paquet (15+ sites le consomment) :
`inputDecoration` était le seul à l'ignorer. Il rejoint le rang.

### 🔴 `labelColor` n'est PAS câblé — et c'est mesuré, pas oublié
Trois mesures : (1) sans couleur, le label passe de `onSurfaceVariant` à `primary` **au focus** ;
(2) coloré via `floatingLabelStyle`, **il reste à la couleur imposée même au focus** — le canal est
détruit, exactement le défaut de CR-IFFD-74 ; (3) coloré via `labelStyle` seul, le focus survit,
mais `fallback()` pose une couleur ≠ celle rendue aujourd'hui, donc l'hôte passif bougerait.
⇒ non câblé, **documenté** : la couleur du label passe par `labelTextStyle`.

🔵 **Un `_lerpNullableColor` est né** au passage : `Color.lerp(null, c, 0)` rend `c` **à alpha 0** —
un fond et une bordure qui **clignotent** pendant une transition de thème.

## 3. 🔴 L'aération inter-champs — DÉFAUT CHANGÉ, et la CR était fausse sur le modèle

**Arbitrage du propriétaire : `interFieldGap` passe d'un défaut NUL à 12 dp, et s'applique désormais
à la voie PLATE** (le cas courant), pas seulement aux formulaires à sections repliables.

### Ce que la CR décrivait, et ce que votre code fait
| La CR dit | Mesuré dans votre code |
|---|---|
| `SizedBox(height: 8)` **systématique entre chaque champ** | 🔴 **Faux.** `edition_screen.dart` fait `<Widget>[const SizedBox(height: 8)] + formFields.map(…)` — c'est un espaceur **de tête**, posé une fois. L'autre `8` est la gouttière de grille (`ResponsiveFormRow`), que nous avions déjà. **Votre métrique inter-champs unique est 12.** |
| 12 dp après `text/float/number/…` via `withSpaceer` | ✅ exact (`models.dart`), à deux conditions près que la CR omet : `name != null` et `!readOnly` |

Nous avions donc failli livrer « systématique + supplément », c'est-à-dire **20 ou 24 dp** — des
valeurs qui n'existent nulle part chez vous. Livré : **12 uniforme**, sur les deux voies. Cela
reproduit exactement DODLP là où il aère, et n'enlève d'air nulle part.

🔵 **Et la contre-intuition n'existe pas** : votre `EditionFieldTypes` n'a **pas** de type
`multiline` (le multiligne est un `text` à plusieurs lignes) — il reçoit donc bien ses 12 dp.

### Ce qui rend ce changement sûr
L'écart est un **habillage du champ**, jamais une ligne d'espacement : une ligne non keyée dans un
sliver paresseux doublerait `itemCount` et ferait réconcilier **par position**, ce qui casse la
préservation du focus (AC6/AD-2, objectif produit n°1). Et le `Padding` est **toujours émis, même à
zéro** — sinon la forme du sous-arbre bascule quand un champ cesse d'être le dernier.
Deux gardes le prouvent, dont une où l'écart passe **de 0 à 12 pendant la frappe**.

Chaîne complète : **`DynamicEdition.interFieldGap` > `ZcrudTheme.fieldGap` > référence (12)**.
⚠️ `interFieldGap` passe de `double` à **`double?`** (sans quoi le jeton serait inatteignable, `12`
étant toujours `> 0`). Aucune lecture externe mesurée. **Échappatoire : `interFieldGap: 0`** rend
strictement le rendu d'avant.

> 🔵 **Le fait le plus instructif du lot** : le défaut de 12 dp avait d'abord été livré **inerte**
> sans qu'une seule garde ne rougisse — parce qu'**aucun** des 1 350 tests ne mesurait la voie plate.

## 4. Le chrome d'édition, le mode forcé, et le trou de saisie

### `ZEditionScaffold` + `ZEditionChrome` — opt-in strict
Titre, actions, et comportement d'en-tête **par mode** : `page` → `SliverAppBar` repliable ;
`dialog` → en-tête + corps + barre d'actions en pied ; `sheet` → poignée + en-tête + corps
scrollable + actions ancrées en `SafeArea`. `chrome: null` (le défaut) rend l'arbre **identique**,
épinglé par un étalon sérialisé dont on a prouvé qu'il **voit** une différence réelle.
Aucune clé de localisation ne manquait (`save`/`cancel`/`close` existaient en fr et en).

### 🔴 La fermeture par GLISSEMENT perdait la saisie — avéré, et bouché
Mesuré sur Flutter 3.44.4 : fermer par la **barrière** appelle le garde d'abandon ; fermer par
**glissement** ferme la feuille et **n'appelle rien**. La cause est dans le SDK — `BottomSheet.onClosing`
va droit à `Navigator.pop`, et `PopScope` n'est consulté que par `maybePop`. **Aucun widget monté
dans la feuille ne peut l'intercepter** : la décision appartient au présentateur.

Élargir `ZFormPresenter.present` aurait **cassé** toute implémentation externe. Livré : un **port
additionnel optionnel** `ZImplicitDismissControl`, testé par `is`, repli silencieux (AD-10). En
feuille gardée : glissement désactivé, **barrière laissée fermante** (elle honore le garde).
La garde n'affirme pas qu'un widget est monté — elle affirme que **la valeur saisie est intacte**.

### `forcedMode` — le troisième point de contrôle
Priorité écrite : **`forcedMode` (un appel) > `policy` (l'app) > politique par défaut**.
Trois propriétés **mesurées**, pas supposées : sans forçage le site appelant se reconstruit au
changement de taille, **avec forçage il ne se reconstruit plus** (la lecture du breakpoint est
court-circuitée, donc aucune dépendance `MediaQuery` n'est enregistrée) ; **aucune cohérence n'est
exigée** avec le breakpoint (`page` forcé à 400 dp, `sheet` forcée à 1000 dp) ; et le chrome est
monté sur le mode **effectif**.

## 5. 🔴 La feuille contrainte et encadrée (demande du propriétaire, inspirée d'IFFD)

### Ce que fait réellement IFFD
Ce n'est **pas** dans son thème global (`kBottomSheetTheme` ne porte qu'une `shape` à rayon 50).
C'est dans son présentateur : `Container(constraints: maxWidth: screenWidth * 0.9)` — un **ratio** —
puis `Card.outlined`, dont le gris est en M3 le rôle **`outlineVariant`**. Donc **aucune couleur
littérale n'est en jeu**, à aucun moment.

### 🔵 Un défaut du socle trouvé en chemin, dans aucune CR
`_BottomSheetDefaultsM3` plafonne une feuille à **640 dp** (`bottom_sheet.dart`), mais
`ZAdaptivePresenter` passait toujours des contraintes à `maxWidth: double.infinity` — **le plafond
du SDK était neutralisé**. Sur 1 600 dp, notre feuille faisait 1 600 là où une feuille Flutter nue
en fait 640.

### Livré
**Largeur = `min(largeur × 0,9 ; 640)`.** Aucune des deux valeurs n'est inventée : le 0,9 vient
d'IFFD, le 640 du SDK. Le ratio seul donnait 1 440 dp sur 1 600 ; le plafond seul est **inactif sous
640 dp**, donc ne donnerait aucune marge sur petit écran — précisément ce qui était demandé.

**Le cadre passe par la `shape` de la feuille**, pas par un conteneur ajouté : l'arrondi de l'hôte
est préservé, on ajoute un `side`. **Un seul bord.** 🔵 IFFD, lui, en peint **deux concentriques**
(`Card.outlined` à rayon 12 dans une feuille à rayon 50) — non reproduit.

**`ZSheetFrameMode { always, never, unlessChrome }`**, et non un booléen. `unlessChrome` restitue
l'intention d'IFFD **sans heuristique** : « c'est une édition » devient « l'appelant a **déclaré** un
chrome ». 🔴 L'heuristique `runtimeType.toString().endsWith("EditionScreen")` d'IFFD n'est **pas**
reproduite — un test de nom de type change le rendu au premier renommage.
Marge et cadre restent **deux réglages indépendants** (gardé dans les deux sens).

### GetX aligné — parce que c'est là que vivent DODLP et IFFD
`ZGetFormPresenter implements ZFormPresenter, ZImplicitDismissControl` et consomme la chaîne
partagée (garde de source : **aucune valeur recopiée**).
🔵 **Un diagnostic corrigé en cours de route** : le `double.infinity` ne neutralisait pas le plafond
M3 sous GetX (`Get.bottomSheet` ne transmet jamais de contraintes) — ce qui manquait était la
**marge**, pas le plafond. Cette nuance a démasqué une garde **vacante** qui mesurait le plancher du
SDK au lieu du nôtre.
🔵 **Une injection a prouvé qu'un tripwire de CONTRAT était nécessaire** : amputer le `implements` ne
fait rougir **aucune** garde de comportement, puisque `presentEdition` retombe alors silencieusement
sur le chemin non gardé.

### 🔴 Et le fond : GetX tuait un canal de thème
`Get.bottomSheet` force `backgroundColor ?? Colors.transparent`, ce qui rend **inatteignable** le
`BottomSheetThemeData` de l'hôte. Le cadre s'y serait peint **sans surface**, en contour flottant.
C'est très probablement pourquoi IFFD enveloppe dans un `Card.outlined` : la carte fournit la
**surface** que GetX avait effacée.
Décision du propriétaire : **la surface revient avec le cadre**. La couleur n'est pas inventée — la
résolution du SDK est **reproduite à l'identique** (thème de l'hôte d'abord, puis le rôle M3).
Cadre désactivé ⇒ comportement GetX d'aujourd'hui **strictement conservé**.

## 6. 🔴 Votre ligne — lisez la vôtre avant de bumper

| Vous êtes… | Geste |
|---|---|
| **hôte passif (tous)** | 🔴 **vos formulaires s'aèrent de 12 dp entre champs.** Échappatoire : `interFieldGap: 0`. Si vous intercaliez vos propres espaceurs, **retirez-les** — ils s'additionnent |
| **hôte passif sur GetX** | 🔴 **vos feuilles deviennent plus étroites (`min(0,9× ; 640)`), encadrées, et OPAQUES.** Trois changements visibles. Échappatoires : `ZSheetFrameMode.never` et un fond explicite |
| 🔴 **IFFD** | vous **compensiez** : retirez le `Container(maxWidth: screenWidth * 0.9)`, retirez le `Card.outlined` (sinon **double surface et double contour**), retirez l'heuristique `isEditionScreen` (→ `unlessChrome`). ⚠️ **Vos écrans d'édition gagneront une surface qu'ils n'avaient pas.** **Conservez** votre `elevation: 8` : le socle ne la pilote pas |
| **DODLP** | retirez `ZSelectConfig(searchable: true)` si vous ne le vouliez que pour le débordement ; retirez vos `interFieldGap: 12` explicites ; posez `fieldFillColor`/`fieldBorderColor` dans **votre** `ZcrudTheme` — plus jamais d'override de `ColorScheme` |
| **lex_douane** | l'aération vous déplace ; les feuilles aussi si vous utilisez `presentEdition`. Le reste est opt-in |
| **hôte lisant `interFieldGap`** | le type passe à `double?` (erreur de compilation, pas de silence) — aucune lecture externe mesurée |

### 🔴 DODLP : ce que nous n'avons PAS fait, et pourquoi
Votre CR « défauts = DODLP legacy » demandait que le socle rende **par défaut** des champs blancs
bordés de gris. **Décision du propriétaire : on n'impose aucune couleur.** Les défauts restent
hérités du `Theme` de l'app.

Mais mesurez ce que cela vous coûte réellement : votre blocage, répété trois fois dans vos
documents, est *« l'app ne doit jamais avoir à surcharger `ColorScheme.surfaceContainerHighest`
elle-même »*. **Il est entièrement résolu** — par le câblage du § 2. Vous passez d'un override
invasif de `ColorScheme` à **deux lignes dans votre propre `ZcrudTheme`**. Seul le « sans
configuration » n'est pas accordé, et il ne l'est pas pour une raison qui vous protège aussi : un
fond blanc imposé déplacerait IFFD et lex sans qu'ils l'aient demandé.

🟢 **Tripwire recommandé** (tous) : sur chaque compensation que vous retirez, gardez d'abord un test
qui **affirme la perte** — il rougira à l'adoption et vous désignera les lignes à supprimer, au lieu
de vous faire croire ce handoff sur parole.

## 7. Vérification

`melos generate` **RC=0**, **aucun `.g.dart` modifié** · `melos analyze` **RC=0** (4 infos, toutes
préexistantes dans `example/`) · `melos verify` **RC=0** — les deux **rejoués après le bump** des 38
versions et des 91 contraintes.

`zcrud_core` **1370** (+34) · `zcrud_navigation` **113** (+80) · `zcrud_get` **119** (+45) ·
`example` **97** · jumelles rejouées vertes : `zcrud_flashcard` 586, `zcrud_markdown` 504,
`zcrud_intl` 183, `zcrud_geo` 174, `zcrud_media` 31, `zcrud_field_extras` 26.
**0 erreur, 0 avertissement.**

**R3 — 90 injections sur six lots, toutes rouges d'ASSERTION** ; restaurations par copie, `sha256`
vérifié après chaque pas, résidus : greps négatifs montrés.

🟢 **Quatre gardes vacantes démasquées par les agents sur leur PROPRE travail** : une qui mesurait
`getBottomLeft` (lequel **exclut** l'écart qu'elle prétendait mesurer) ; une qui lisait le plancher
**ambiant du SDK** au lieu du nôtre ; une qui rougissait sur **sa propre prose** (son dartdoc citait
le motif recherché) ; une qui lisait un fichier brut dont le commentaire contenait le symbole
interdit. Toutes re-scopées, campagnes rejouées.
🟢 **Deux gardes refusées plutôt qu'écrites inertes** : un chemin non atteignable par construction,
et un paramètre résolu en amont donc structurellement inerte dans le présentateur.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement — c'est la seule
ligne de défense, et ce n'est plus un doublon.

## 8. Non couvert

* `elevation` et `surfaceTintColor` des feuilles GetX restent divergents du socle — hors décision.
* `Get.bottomSheet` n'exposant pas de contraintes, l'échappatoire « pleine largeur » reste plafonnée
  à 640 dp au-delà ; seul recours hôte : votre `BottomSheetThemeData(constraints:)`. Épinglé par une
  garde, pas par un commentaire.
* Pas de jeton de **fond** de feuille dans `zcrud_core` — délibéré : il créerait un second canal de
  thème pour une propriété déjà portée (le motif de divergence CR-LEX-78).
* Chrome : `gap` lit le jeton générique `gapM` existant plutôt qu'un jeton dédié ; le padding
  d'action reste atteignable par paramètre seul (micro-détail d'un widget, pas une décision app-wide).
* ~~La table type → statut demandée par votre § 7 (découvrabilité) et le stepper *data-driven inline*
  restent **non traités**.~~
  🔴 **Correction (2026-08-09, même jour)** — les deux affirmations étaient fausses :
  * le **stepper *data-driven inline* était DÉJÀ livré** : `z_step_partition.dart` (344 lignes,
    exporté) regroupe une liste **plate** de `ZFieldSpec` annotés `ZStepFieldConfig` en
    `List<ZEditionStep>` par une fonction **pure et totale**, consommée telle quelle par
    `ZStepperEdition`. C'est exactement votre G1. `EditionFieldType.stepper` reste `unsupported`
    **délibérément** — un stepper est un regroupement single-writer de `visibleFields`, pas un
    widget-feuille ; le router par le dispatcher casserait l'invariant. Rien à attendre de nous ;
  * la **table type → statut** est livrée en **v0.60.1** (cf. `docs/handoff-v0.60.1.md`).

  ⇒ **ce lot a couvert vos cinq CR**, et la cinquième était en partie déjà servie.
* Dettes antérieures : cf. v0.59.0.
