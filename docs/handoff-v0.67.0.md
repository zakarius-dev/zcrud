# Handoff **v0.67.0** — vos trois gaps se refermaient sur UN seul défaut, et le rendu Markdown a son moteur

> **Tag à épingler : `v0.67.0`**
> 🔴 **Un changement de comportement** : le bouton « Suivant » d'une étape **bloque enfin** sur une
> sous-liste requise vide et sur une map requise vide (§ 1). C'est un correctif, pas une régression.
> Aucune signature cassée, aucun paquet nouveau (38), aucune arête ajoutée.

---

## 1. 🔴 Le résultat central : vos Gaps 2, 3 et 4 se refermaient sur le MÊME défaut

Nous avons mesuré vos trois gaps **avant** d'écrire. Verdicts :

| Gap | Verdict mesuré | Ce qui manquait **réellement** |
|---|---|---|
| **2** — chips | **déjà couvert (mono)** — `rowChips` **EST** le « select en chips ». Chez vous : 2 sites, **mono**, choix **statiques** | choix **dynamiques** et **multi** |
| **3** — sous-listes en étape | **déjà couvert** — l'imbrication monte, `visibleFields` reste intact, SM-1 était déjà bon | le gate d'étape, une **ACL morte**, un **refus muet** |
| **4** — valeur structurée | **déjà couvert** sous `DynamicEdition` et à la soumission | le seul gate d'étape |

**Et le dénominateur commun est un défaut de NOTRE correctif de la veille.** `z_stepper_edition.dart`
portait sa **copie locale** de la projection de validation. La règle unique posée en v0.64.0 avait
atterri dans **deux voies sur trois** — l'affichage et la soumission — et **manqué le gate d'étape**.

Conséquence mesurée : `[]` devenait `"[]"` et `{}` devenait `"{}"`, non vides — donc un `subItems`
**requis sans aucune ligne** et une **map requise vide** franchissaient « Suivant ». C'est exactement
la classe de défaut « garde jumelle manquée » que notre propre discipline décrit. Les **quatre**
voies partagent désormais la source unique.

🔵 **Aucun mode d'affichage n'a été ajouté à `ZSelectConfig`** : cela aurait dupliqué un widget qui
existe. Vos `S2ChoiceType.chips` se déclarent en `rowChips`, qui gagne ici les **choix dynamiques**
et le **multi** — ce dernier via `ZFieldSpec.multiple`, **sans un seul champ de configuration
nouveau**.

## 2. Deux canaux morts, prouvés et rebranchés

* 🔴 **L'ACL de sous-liste était lue à 8 endroits et alimentée nulle part** (recherche négative
  montrée). Elle est désormais câblée, **en opt-in** : sans identifiant de collection déclaré, l'hôte
  passif ne bouge pas — c'est gardé.
* Le multi des chips n'existait pas (recherche négative montrée) ; il passe par le drapeau existant.

## 3. Deux défauts trouvés **par les gardes**, pendant l'écriture

1. 🔴 **Refus muet** : les mini-CRUD étaient montés **avant** la souscription à la surface d'erreur —
   donc un requis vide bloquait **sans afficher le moindre message**. L'utilisateur voyait un bouton
   inerte sans savoir pourquoi.
2. Le premier correctif faisait **alterner la forme de l'arbre**, ce qui reparentait le mini-CRUD et
   **détruisait son élément** (compteur de construction 1 → 2), perdant l'état des lignes en cours.
   Corrigé par une place stable.

Le second n'a été vu que parce que la garde a d'abord été posée sur le **mauvais sujet** — un canal
**structurel** — puis refaite sur le canal de construction réel. Elle a alors rougi pour de vrai.

## 4. Le rendu Markdown a son moteur — sans nouveau paquet

`ZMarkdownRichTextRenderer` implémente le port `ZRichTextRenderer` livré en v0.66.0. Injectez-le dans
votre `ZcrudScope` et vos sous-titres d'étape deviennent du Markdown rendu.

🔴 **Aucune arête ajoutée** : `pubspec.yaml` du satellite **intouché** (vérifié), et la seule mention
d'un paquet Markdown tiers dans tout le paquet est un **commentaire** expliquant pourquoi il n'entre
pas. Le satellite avait déjà les **deux moitiés** du moteur — un parseur et un lecteur — jamais
raccordées pour une source Markdown nue.

### Ce que vos sous-titres contiennent réellement
Mesuré sur vos ~40 `stepSubtitle` : l'écrasante majorité est du **texte pur**. Le balisage se
concentre sur deux champs et se réduit à **quatre constructions** — paragraphes, gras, listes à
puces, listes numérotées. Comptés à **zéro** : titres, citations, tableaux, images, barré, séparateur.
**Le CommonMark complet n'était pas l'objectif.**

🔵 **Le renderer DÉCLINE quand il n'y a aucun balisage**, et c'est délibéré : votre repli en texte
simple est alors **strictement équivalent** et bien moins cher qu'un éditeur monté pour afficher une
ligne. Il décline aussi sur source vide, parseur en échec, et présence d'un embed (qui réclamerait
une place de bloc — zéro occurrence chez vous). **Décliner, jamais lever, jamais approximer.**

🔵 **Un piège de style mesuré dans le SDK** : un style ambiant ne suffit pas — Quill repart de
l'ambiant mais **écrase la taille à 16**. Il a fallu fusionner jusqu'au style du *meneur* de ligne,
sans quoi le texte tombait à 11 pendant que les puces restaient à 16.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| 🔴 **tous** | « Suivant » **bloque désormais** sur une sous-liste ou une map **requise et vide**. Seul bouge l'hôte qui *s'appuyait* sur le défaut |
| **hôte qui compensait** | si vous affichiez **vous-même** un message pour ce refus, vous aurez un **doublon** — retirez votre compensation |
| 🔴 **attention, au-delà de votre CR** | la surface d'erreur touche `subItems` **et `dynamicItem`**. `dynamicItem` **n'est pas dans votre CR** : c'est notre extension, donc invisible à votre lecture. Nous le signalons plutôt que de vous laisser le découvrir |
| **DODLP** | Gap 2 ⇒ déclarez vos deux `S2ChoiceType.chips` en `rowChips` ; Gap 3 ⇒ l'imbrication marchait déjà, l'ACL de ligne est maintenant câblable ; Gap 4 ⇒ écrire une map marchait déjà, seul le gate manquait. Pour le Markdown, injectez `ZMarkdownRichTextRenderer` |
| **hôte passif** | rien — ACL opt-in, renderer non câblé par défaut, mode paginé inchangé |

⚠️ **Un risque de collision signalé** : `zIsEmptyValue` et `zValidationText` deviennent **publics**.

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.

`zcrud_core` **1546** (+20) · `zcrud_markdown` **516** (+12) · `zcrud_study` 1521 · `zcrud_firestore`
770 · `zcrud_flashcard` 586 · `zcrud_intl` 183 · `zcrud_geo` 174 · `zcrud_select` 135 ·
`zcrud_media` 31 · `zcrud_field_extras` 26 · `example` 97. **0 erreur, 0 avertissement.**
**Aucune garde préexistante retouchée** dans aucun des deux paquets.

**R3 — 34 injections**, sha avant **et** après chacune, restauration par copie, résidus : greps
négatifs montrés.

🟢 **Le geste le plus notable du lot** : une injection est restée **VERTE**, et l'agent en a conclu
que **son propre dartdoc mentait**. Il affirmait qu'un certain mode de passage protégeait la
granularité des rebuilds ; la mesure a montré que la protection réelle venait d'ailleurs. **Il a
corrigé la documentation, pas forcé l'injection.** Une injection verte est une information, pas un
échec à contourner.

🟢 Et deux autres qualifications honnêtes : un rouge de **compilation** compté comme tel et non comme
une assertion ; une **redondance** de règles consignée — neutraliser une règle de refus laisse une
garde verte parce que deux autres l'attrapent, ce qui n'est pas une vacuité (prouvé en **inversant**
la règle) mais méritait d'être dit.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* **Votre éditeur de permissions** : c'est du métier (3 usages chez vous, 0 ailleurs). Le socle porte
  le **moyen** — écrire une valeur structurée et la valider — pas votre écran.
* Un **exemple** « stepper + sous-listes + ACL + champ à valeur structurée + chips » est spécifié mais
  pas encore écrit dans notre vitrine.
* `itemTitleBuilder` reste non déclaratif : c'est une fermeture, et AD-3/AD-14 l'interdit dans une
  spécification sérialisable.
* Le littéral « Étape k sur N » (cf. v0.66.0) reste en dur — lot à part.
* Dettes antérieures : cf. v0.66.0 et les handoffs précédents.
