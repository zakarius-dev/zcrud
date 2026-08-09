# Handoff **v0.66.0** — le stepper vertical à rail numéroté, et un bug de layout refermé

> **Tag à épingler : `v0.66.0`** · strictement **additif** — le mode paginé actuel rend à
> l'identique, aucune signature cassée, aucun paquet nouveau (38).
> **Aucun paquet externe intégré** : tout est en Material pur, `CORE OUT = 0` intact.

---

## 1. Ce que votre stepper legacy fait RÉELLEMENT

Avant d'écrire une ligne, nous avons lu vos 868 lignes et confronté chaque canal de configuration à
son usage. **Le résultat renverse la lecture du CR** :

| | |
|---|---|
| **4 canaux vivants sur 17** | `showAllSteps`, `orientation`, `activeColor`, `allowStepTap` |
| 🔴 **`indicatorPosition`** | **posé par 4 de vos écrans**, **lu 0 fois** par le moteur |
| **13 canaux morts** | `style`, `completedColor`, `inactiveColor`, `errorColor`, `indicatorSize`, `stepSpacing`, `showLabels`, `showSubtitles`, `validateOnNext`, l'auto-sauvegarde, les animations, et **vos deux builders** |

Votre « vertical, indicateur à gauche » ne vient donc **pas** de `indicatorPosition` : il vient de
`orientation` **seule**. Le paramètre que vous posez sur quatre écrans n'a jamais rien fait.

🔵 Et le précédent que nous redoutions s'est confirmé une fois de plus : `stepDataList` est passé aux
**deux** branches « tout affiché » et n'y est **jamais utilisé**. En mode déplié, la taille
d'indicateur est codée en dur, le badge est **toujours** `activeColor` (aucun état visible), le
numéro est un blanc littéral, et le rail est positionné en `left:` **physique** (donc faux en RTL).

**Aucun paquet externe** — recherche négative montrée sur votre `pubspec.yaml`. Le seul tiers,
`gpt_markdown`, ne sert **que** le sous-titre (deux sites). Il n'entre donc pas chez nous : § 3.

## 2. Le mode « tout affiché » vertical à rail numéroté

Livré sur `ZStepperEdition` : badge circulaire numéroté, rail vertical continu, titre **et**
sous-titre par étape, toutes les étapes dépliées, et **sous-steppers paginés** à l'intérieur — le
primitif qui unifie vos deux exemples (agents dépliés ; navires = racine dépliée + sous-steppers
paginés). Vérifié : **racine dépliée + 2 sous-steppers paginés indépendants**.

**Nous n'avons pas reproduit votre implémentation, seulement votre rendu** : votre rail passe par
`IntrinsicHeight` + `Row(stretch)`, qui **mesure deux fois chaque formulaire**. Nous peignons le rail
en `CustomPaint` **directionnel** (donc juste en RTL) au-dessus d'un `ListView.builder`.

**L'invariant tient** : `ZStepperEdition` reste le **single writer** de `visibleFields` — en mode
déplié il force le pilotage, tous les `DynamicEdition` internes sont passifs, et la fenêtre visible
est l'**union dédoublonnée** des étapes.

🔵 **Un défaut trouvé au passage, et corrigé** : le calcul de contribution **concaténait**. Sur des
étapes imbriquées circulaires, `visibleFields` devenait `['a'] × 10`. Le suivi des contributions est
désormais une **carte indexée**, ce qui gère aussi plusieurs sous-steppers montés simultanément.

**Couleurs** : les 4 emplacements existaient déjà chez nous. 5 jetons et 3 paramètres complètent la
chaîne **paramètre > jeton `ZcrudTheme.*` > rôle `ColorScheme`**. La **forme** est la vôtre, la
**teinte** vient du thème de l'hôte — aucun hex n'entre dans le socle.

### Ce qui est dit inerte au lieu d'être simulé
**96 combinaisons** (orientation × position d'indicateur × style × mode × direction) rendues sans une
exception. Et en mode déplié, `indicatorPosition`, `orientation`, `style`, `allowStepTap` et
`validateOnNext` sont **inertes** — c'est écrit, pas maquillé. C'est la règle posée par CR-IFFD-78 :
un paramètre est honoré, ou son inertie est déclarée.

## 3. Le sous-titre riche — sans faire entrer de paquet tiers

Votre moteur rend le sous-titre en Markdown via `gpt_markdown`, en stockant un `Widget` puis en
faisant `if (subtitle is Text)` et `(subtitle as Text).data` pour en **récupérer la chaîne**.

Livré à la place : un **port** `ZRichTextRenderer` sur `ZcrudScope` (choix justifié — les 9 seams
existants du scope sont **tous** des ports, zéro fermeture), et **deux entrées distinctes** sur
l'étape, au patron déjà établi ici pour `label`/`labelWidget` :
* **`subtitle`** (chaîne) ⇒ passe par le port ; sans port injecté, **texte simple** — hôte passif
  inchangé ;
* **`subtitleWidget`** ⇒ rendu **tel quel**, le port n'est pas consulté ; il **prime** si les deux
  sont fournis.

🔴 **Le cast devient inexprimable** : avec deux entrées séparées, faire voyager une chaîne dans un
widget pour la déballer n'a plus de raison d'exister. Nous n'avons pas corrigé le défaut, nous
l'avons rendu impossible.
`showSubtitles` gouverne **les deux** entrées, gardé dans les deux sens.

⚠️ **Aucune arête** vers `zcrud_markdown` depuis le cœur. Le satellite fournira
`ZMarkdownRichTextRenderer` — **pas encore écrit**, c'est le lot suivant.

## 4. Bug 1 — `vertical` + indicateur au début

Corrigé. 🔵 **Et notre analyse initiale était fausse** : nous pensions qu'il fallait un hôte à largeur
non bornée pour le reproduire. **Non** — dans une `Row`, un enfant non flexible est mesuré à largeur
**infinie quelles que soient** les contraintes de la `Row`. Le bug se produit donc bien sous l'hôte
**borné** de votre CR, et la garde y est montée. Tenter un hôte réellement non borné révèle un
**autre** défaut (l'alignement étiré n'a plus de sens), qu'aucun stepper ne peut traiter — dit plutôt
que contourné.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **DODLP** | activez le mode déplié sur `ZStepperEdition` ; vos sous-steppers paginés s'y imbriquent. ⚠️ **Retirez `indicatorPosition` de vos 4 écrans en mode déplié** : il ne faisait déjà rien chez vous, et chez nous il est **déclaré inerte** dans ce mode. Pour le sous-titre Markdown, injectez un `ZRichTextRenderer` — ou passez `subtitleWidget` et gardez votre rendu |
| **hôte passif** | **rien** — mode paginé rendu à l'identique, sous-titre en texte simple sans port injecté |
| **hôte en RTL** | 🔵 le rail est **directionnel** chez nous ; il était en `left:` physique dans le legacy |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1526** (+40) · `zcrud_study` 1521 · `zcrud_firestore` 770 · `zcrud_flashcard` 586 ·
`zcrud_markdown` 504 · `zcrud_select` 135 · `example` 97. **0 erreur, 0 avertissement.**

### 🔴 La même garde jumelle a mordu — une seconde fois
Ajouter le port `richTextRenderer` à `ZcrudScope` a fait **rougir `zcrud_study`**, exactement comme
`appFileResolver` la veille. Sa garde affirme que **chaque** paramètre du scope est re-posé dans sa
feuille, en lisant la liste **réelle dans la source de `zcrud_core`**. **Deux ports différents, deux
morsures, deux jours de suite** — sans elle, un sous-titre riche rendu dans cette feuille aurait
silencieusement perdu son moteur. Corrigé sur les deux sites de re-pose.

**R3 — 16 injections, toutes rouges d'assertion**, sha avant/après, restauration par copie, résidus :
greps négatifs montrés.

🟢 **Deux gardes réellement faibles démasquées et renforcées** :
* la garde d'imbrication restait verte parce que le repli rendait **par hasard** la valeur attendue
  tant qu'**un seul** sous-stepper avait bougé — elle en sollicite désormais **deux** ;
* la garde d'accessibilité comptait les **nœuds**, or un `Semantics(label:)` posé sur un rendu déjà
  textuel **fusionne** au lieu d'en créer un — elle compte désormais les **occurrences**.

🟢 Et deux « verts » se sont révélés être des **injections mal placées** de l'agent lui-même,
requalifiées et rejouées correctement plutôt que comptées comme preuves.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* **`ZMarkdownRichTextRenderer`** dans `zcrud_markdown` — le port existe, l'implémentation suit.
* Le littéral **« Étape k sur N »** reste en dur dans le cœur. Non converti **délibérément** : la
  chaîne de résolution ferait gagner l'anglais dans les tests sans délégué et **rougirait 8 gardes
  existantes**, et le socle n'a **aucun précédent d'interpolation** de libellé (recherche négative
  montrée). C'est un lot à part, pas un oubli.
* Vos **Gaps 2, 3 et 4** (mode chips, sous-listes en étape, éditeur de permissions) — non traités.
* Dettes antérieures : cf. v0.65.0 et les handoffs précédents.
