# Handoff v3.51.0 — la surface de saisie prend la forme qu'on lui donne

Origine : une application hôte a mesuré, élément par élément contre deux captures de sa
référence, la distance qui restait après v3.50.0. Quinze éléments : un fait, **huit
posables chez elle sans rien demander**, quatre structurels chez nous, un défaut du socle,
une décision qui lui revient. Sa formule résume les quatre structurels : *« les seams de
couleur existent, ceux de forme n'existent pas »*.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Constats vérifiés sur disque avant tout travail

| # | Constat de l'hôte | Vérification | Verdict |
|---|---|---|---|
| 1 | Les choix sont des puces compactes (`InkWell` + `Row`) sans réglage de forme | `z_flashcard_answer_input.dart:1375,1442,1446` ; `grep choiceLayout` ⇒ 0 | réel |
| 2 | « Indice » / « Je ne sais pas » empilés, soumission en puce, aucun réglage | idem, 0 occurrence de `actionsLayout`/`submitWidth` | réel |
| 3 | La rangée de paliers n'apparaît qu'après soumission | `_CorrectionSection` gaté sur `corrected != null` (`:1109`, `:1322`, `:1552`) | réel |
| 4 | La pile laisse voir la carte suivante par-dessus la carte de devant | `Stack` (`z_session_card_swiper.dart:834`), `Material` opaque (`:939`) — **mécanisme à mesurer** avant de corriger | à mesurer |
| 5 | La carte de révision arrondit avec le jeton des formulaires, sans rayon propre | `z_flashcard_review_card.dart:1097` lit `theme.radiusM` | réel |
| 6 | Elle n'a aucune ombre ; les jetons `flashcardCard*` ne la gouvernent pas | `Material(color:)` sans `elevation` (`:1095`) ; `flashcardCardShadowColor` lu seulement par `z_default_flashcard_card.dart:502` | réel |

Sur le point 6, la demande proposait deux jetons de plus (`reviewCardRadius`,
`reviewCardShadowColor`) **ou** de faire lire à la carte de révision les jetons existants.
C'est la seconde voie qui est retenue : **un seul canal** par propriété. Deux jetons pour un
même fond ou une même ombre, selon la carte, seraient le doublon que les versions
précédentes ont passé leur temps à supprimer.

## La surface de saisie prend la forme qu'on lui donne

Après v3.48.0, les seams de **couleur** de la rangée de notation traversaient l'assemblage.
Mais la surface elle-même — choix, boutons d'indice et d'abandon, soumission, moment
d'apparition des paliers — rendait ses contrôles dans une forme fixe. La seule voie pour
changer la forme de trois boutons était `gradingBuilder` : réimplémenter champ de réponse,
choix, correction, indices, évaluation et soumission.

Quatre réglages nullables sur `ZFlashcardAnswerInput`, chaîne `paramètre > jeton
ZcrudTheme.answerInput* > référence`, **défauts strictement égaux au rendu d'aujourd'hui** :

| Réglage | Valeurs | `null` ⇒ |
|---|---|---|
| `choiceLayout` | `compact` \| `tile` (tuile pleine largeur, radio, coins arrondis) | `compact` |
| `actionsLayout` | `stacked` \| `sideBySide` (deux boutons **contour**, côte à côte) | `stacked` |
| `submitWidth` | `content` \| `full` | `content` |
| `gradingVisibility` | `afterSubmit` \| `always` | `afterSubmit` |

Les contours se colorent par **clé** (`hintOutlineColorKey`, `dontKnowOutlineColorKey`),
résolue par votre thème — aucune valeur chromatique n'entre dans le socle. Les dimensions
de référence (rayon 12, marge 6, liserés 1/2, pourtour 1) vivent dans
`ZAnswerInputReference`. Une nuance mesurée : la ligne de choix était **déjà** pleine
largeur ; ce qui manquait était la décoration de tuile.

⚠️ **`gradingVisibility: always` change l'ordre des gestes.** La rangée de paliers est
montée et **active avant** la réponse. Un cran tapé alors est une **notation manuelle par
la voie unique** (`onQualitySelected`), et il **verrouille** la soumission : une seule
écriture, jamais deux. Prouvé par compteur : cran avant réponse ⇒ 1 ; soumettre ensuite
⇒ impossible, toujours 1 ; second cran ⇒ toujours 1 ; réponse puis cran ⇒ 1. Sans
`always`, rien ne change.

- **Application passive** : rien ne change, arbre et couleurs identiques.
- **Application qui avait fourni un `gradingBuilder` uniquement pour la forme** : retirez-le
  et posez les réglages — vous récupérez la correction, les indices et l'évaluation que
  votre réimplémentation devait porter. Le test qui doit rougir chez vous : celui qui
  affirme que votre `gradingBuilder` est appelé.

## La pile : le signalement était inexact, le défaut était réel

L'hôte voyait « la carte suivante par-dessus la carte de devant ». Mesuré : la carte
suivante **n'était pas** peinte par-dessus — l'ordre de peinture de la pile est correct.
C'était notre `Stack` interne qui **desserrait** la hauteur imposée par la pile : la carte
de devant, plus courte que sa cellule, mesurait 100 dp dans une cellule de 528, et 416 dp
de la carte suivante étaient peints **dans le vide** au-dessous. Corrigé par
`StackFit.passthrough` : la carte de devant occupe sa cellule, le débord tombe à 13,6 dp
— les bords des cartes suivantes, comme une profondeur.

Le cas « cartes de même hauteur » reste identique avec et sans le correctif — c'est la
preuve que le changement ne touche que le cas défectueux.

- **Application passive** : rien à faire.
- **Application ayant compensé** en forçant une hauteur minimale à sa carte pour masquer la
  suivante : retirez la contrainte — elle s'additionne au correctif. Le test qui doit
  rougir : celui qui affirme la hauteur forcée.

## La carte de révision lit enfin les jetons de carte

Les trois jetons `flashcardCard*` de v3.49.0 ne gouvernaient que la carte de **liste**. La
carte de **session** arrondissait ses coins avec le jeton des formulaires et ne portait
aucune ombre. Un hôte qui posait ces jetons croyait teinter ses cartes de session et ne
teintait rien.

`ZFlashcardReviewCard` lit désormais `flashcardCardBackgroundColor`,
`flashcardCardShadowColor` et un jeton **neuf**, `flashcardCardRadius` — aucun jeton de rayon
de flashcard n'existait, la carte de liste lisant une constante de référence. Chaîne
`paramètre (backgroundColor, shadowColor, radius) > jeton > comportement actuel`.
`null` partout ⇒ arbre identique à l'octet, coins sur `radiusM` comme avant.

L'ombre suit **la même résolution que la carte de liste**, prouvée : les jetons
`cardShadow{Blur,Offset,Alpha}` priment dès qu'un seul est posé ; sinon la teinte seule
porte l'ombre de référence. Un seul écart, imposé par l'inertie : ici la couche d'ombre
n'est construite que si une teinte est résolue — teinte nulle ⇒ aucune boîte.

Un constat de l'hôte a été **démenti à raison** : le troisième site qu'il croyait être un
coin de carte est le pourtour d'onde d'un bouton d'action, à 48 dp de cible. Il reste sur
`radiusM`, et une assertion le garde ainsi.

La référence visuelle mesurée — rayon 20, ombre flou 20 / décalage (0, 8), teinte
**dérivée du dégradé du type** — n'entre **pas** comme défaut : elle se pose par le thème
et le preset. Un point mérite d'être dit : la référence a **quatre** teintes d'ombre, une
par type de carte. Un thème n'en porte qu'une ; figer une teinte unique serait faux. C'est
donc le preset qui, par carte, passe la première couleur du dégradé du type.

- **Application passive** : rien ne change.
- **Application ayant compensé** par un `Card`/`DecoratedBox` enveloppant la carte de
  session pour lui donner rayon ou ombre : retirez-le — il s'additionne au rendu natif (deux
  ombres, deux rayons). Le test qui doit rougir chez vous : celui qui affirme la présence de
  votre enveloppe.

## Les formes traversent jusqu'au preset — et `.classic` change

Les quatre réglages de forme sont relayés du scaffold au host, à plat comme en `.wired`,
toujours nullables (`paramètre ?? preset ?? null`), et `ZStudySessionPreset` les porte.
**`ZStudySessionPreset.classic` pose désormais `tile`, `sideBySide`, `full` et `always`.**
Un paramètre explicite sur l'écran bat le preset, forme par forme.

Ces quatre types sont classés **cosmétiques** par la garde de partition du montage énuméré
— admission nominative, avec sa contre-preuve (`ZFutureLayout?` reste un seam). Ils ne
rejoignent donc **pas** `ZStudySessionWiring` : les oublier coûte une forme, jamais une
capacité. Un cas limite est tranché et documenté : `always` déplace le moment d'une
affordance **déjà branchée** — sans `onQualitySelected`, aucune rangée n'est montée et le
réglage est inerte.

⚠️ **Rupture pour qui est DÉJÀ sur `.classic`.** Ce preset existait depuis la version
précédente ; une application qui l'avait adopté voit sa surface de saisie **changer de
forme** (tuiles, boutons contour côte à côte, soumission pleine largeur) **et d'ordre des
gestes** (paliers actifs avant la réponse). C'est le sens d'une direction de design nommée
— mais c'est un changement visible.
- **Application passive** (sans preset, ou preset nu) : rien ne change, inertie prouvée à
  l'octet sur quatre scènes.
- **Application sur `.classic`** : si vous vouliez la forme sans l'ordre des gestes, posez
  `gradingVisibility: ZAnswerGradingVisibility.afterSubmit` sur l'écran — le paramètre bat le
  preset. Toute compensation maison de forme (tuile, boutons côte à côte) **s'additionne** :
  retirez-la ; le test qui doit rougir chez vous est celui qui affirme que votre composition
  est montée.

## Le thème « Classic » pose la carte et les formes — pas l'ordre des gestes

- **`flashcardCardRadius: 20`** — ce jeton n'a qu'un lecteur, la carte de session ; la carte
  de liste garde son rayon de référence.
- **Trois formes de saisie** posées : `tile`, `sideBySide`, `full`. Elles reproduisent la
  branche compacte de la référence.
- **`always` n'est jamais posé par le thème**, et une garde le vérifie au jeton (deux
  luminosités) **et au rendu** (aucune rangée de paliers avant la réponse sous Classic seul).
  Un thème pose des couleurs et des formes ; il ne change pas l'ordre des gestes d'une
  session. Ce comportement est réservé au **preset** `.classic`, que l'application choisit
  explicitement.
- **Aucune ombre posée dans le thème**, pour une raison mesurée : dans la carte, la branche
  des jetons `cardShadow{Blur,Offset,Alpha}` est testée **avant** la teinte et rend
  immédiatement — les poser rendrait le paramètre `shadowColor` **inerte**, donc casserait
  la voie par laquelle le preset donne à chaque type sa teinte. Et un jeton d'ombre unique
  serait faux : la référence en a quatre.

⚠️ **Trois contrastes échouent, et nous préférons le dire que le masquer.** Sur le fond de
Classic, les traits de **groupement** de la tuile et des boutons contour valent 1,70 / 1,30 /
1,27 (rôles `outlineVariant`, `tertiaryContainer`, `errorContainer`) contre 3,0 requis pour
un élément graphique. Aucune correction n'est possible sans **inventer** une couleur —
ce que le socle s'interdit. L'information est portée ailleurs : libellés ≥ 9:1, sélection
marquée par l'épaisseur du liseré (1 → 2). La référence d'origine fait pire (~1,1:1).
L'arbitrage est figé par une garde, pour qu'il ne soit ni oublié ni « corrigé » par une
valeur en dur.

- **Application passive** : rien ne change.
- **Application sous Classic** : ses cartes de session gagnent le rayon 20 et sa saisie les
  trois formes. Si elle avait posé elle-même `flashcardCardRadius` ou l'une des formes, son
  réglage explicite continue de gagner — le thème n'écrase jamais un jeton posé par l'hôte
  au-dessus de lui.

## Sous `.classic`, l'ombre suit le type de la carte

La référence teinte l'ombre de chaque carte avec la **première couleur de son dégradé de
type** — quatre teintes, une par type. Un thème n'a qu'un jeton d'ombre ; c'est donc le
**preset** qui, par carte, passe la bonne teinte : `ZCardChromeSpec.shadowColor` (valeur)
et `shadowColorResolver` (`Color? Function(BuildContext, ZFlashcard)`, évalué au site de
montage), priorité valeur > résolveur > rien. `.classic` pose le résolveur
`zFlashcardTypeShadowColor`, publié et composable.

Sans preset : aucune ombre, arbre identique à l'octet. Un jeton `flashcardCardShadowColor`
posé par le thème **et** un preset nu : le jeton s'applique — le preset nu n'écrase rien.

⚠️ **Une limite, mesurée, que nous préférons écrire.** La carte applique sa propre
opacité à la teinte reçue (`0.06` clair / `0.2` sombre) : l'alpha transmis est écrasé. Et
la géométrie exacte de la référence (flou 20, décalage (0, 8), alpha 50/30 sur 255) passe
par les jetons `cardShadow{Blur,Offset,Alpha}` — qui, dans la carte, sont testés **avant**
la teinte et rendent `shadowColor` **inerte**. Aujourd'hui, une application obtient donc
**soit** la teinte par type (preset), **soit** la géométrie exacte (jetons), pas les deux.
Lever cette limite demande de découpler géométrie et teinte dans la carte ; c'est un lot
à part, et il n'a pas été fait dans cette version pour ne pas élargir le contrat de la
carte sans mesure.

- **Application passive** : rien ne change.
- **Application ayant compensé** l'absence d'ombre — décoration propre autour de la carte,
  ou `flashcardCardShadowColor` posé pour tous les types — : sous `.classic`, retirez-la,
  elle s'additionnerait. Le test qui doit rougir chez vous : celui qui affirme que votre
  décoration est montée, ou que l'ombre est d'une teinte unique quel que soit le type.

## La résolution du dégradé de type est désormais publique

Le preset avait dû **réécrire l'ordre** des trois maillons de résolution du dégradé de type
pour teinter l'ombre par carte, parce que cette résolution était privée à la carte de
session. C'était un doublon de logique, gardé mais réel. Il est retiré à la source :
`zResolveFlashcardTypeGradient(context, card, {typeGradientKey})` est publiée par
`zcrud_flashcard`, la carte l'appelle, le preset l'appelle — **une seule chaîne** dans le
socle, et une garde interdit désormais toute réécriture de ses maillons dans le preset.
La constante de préfixe de clé garde son nom et sa valeur ; elle change seulement de
fichier. Aucun changement de rendu.

## Si vous n'adoptez rien

Une application **passive** — qui ne pose aucun des réglages nouveaux et n'utilise pas le
preset `.classic` — ne voit **aucun** changement d'arbre ni de couleur peinte. Une
exception, corrective : la carte de devant d'une pile occupe désormais sa cellule quand
elle est plus courte que son contenu, au lieu de laisser 400 dp de la carte suivante peints
dans le vide.

Une application **sur `.classic`** voit sa saisie changer de forme **et d'ordre des
gestes**, et ses cartes gagner rayon et ombre par type. C'est le sens d'une direction de
design nommée ; chaque section dit comment garder la forme sans l'ordre des gestes.

Une application qui **compensait** l'un des défauts corrigés doit retirer sa compensation :
elle s'additionne au comportement natif.

## Les tripwires à écrire chez vous

| Vous compensiez… | Le test qui doit rougir |
|---|---|
| un `gradingBuilder` fourni pour la seule forme des boutons | « mon `gradingBuilder` est appelé » |
| une hauteur minimale forcée sur la carte pour masquer la suivante | « ma contrainte de hauteur est présente » |
| un `Card`/`DecoratedBox` autour de la carte de session pour un rayon ou une ombre | « mon enveloppe est montée » |
| `flashcardCardShadowColor` posé pour tous les types sous `.classic` | « l'ombre est d'une teinte unique quel que soit le type » |
| une composition de tuile ou de boutons côte à côte | « ma composition est montée » |

## Vérification, rejouée au repos

- `melos run generate` → RC=0, **0 fichier généré modifié** ;
- `melos run analyze` **repo-wide** → RC=0 ;
- `melos run verify` (gates, dont `web`, `reserved-keys`, graphe acyclique et recette de
  consommation) → RC=0 ;
- balayage des **42 paquets**, `flutter test --no-pub -j 4` lancé **depuis le dossier de
  chaque paquet** → **41 verts**. `zcrud_generator` est rouge pour une raison
  d'environnement, qualifiée et non imputable au code : son `lib` et son `test` sont
  **identiques à l'octet** à la version précédente (`Unsupported operation:
  Isolate.packageConfig` via `build_test`) ;
- comptes par paquet, mesurés à la clôture de chaque lot : `zcrud_core` 2707, `zcrud_study`
  2355, `zcrud_session` 762, `zcrud_flashcard` 670, `zcrud_themes` 138 ;
- aucun résidu d'injection R3 (`grep --no-ignore-files -a`), aucun `if (false` en
  production.

Les gardes de cette version ont été posées sous discipline R3 — rouge **par assertion**,
restauration par copie de fichier, sha256 publiés avant/après, résidus prouvés par grep
négatif. **Sept gardes étaient vertes au premier passage sous injection** ; aucune n'a été
déclarée solide — toutes reformulées sur la propriété réelle. **Deux constats de l'hôte ont
été démentis à raison** par les agents chargés de les corriger : la carte suivante n'était
pas peinte par-dessus, et le troisième « coin » de la carte était le pourtour d'un bouton.
