# Handoff **v0.46.0** — CR-IFFD-57 + CR-IFFD-58 : une seule carte de flashcard, au dessin de référence, sur toutes les surfaces

> **Tag à épingler : `v0.46.0`** · aucune rupture d'API.
> 🔴 **Deux changements de rendu par défaut, assumés** : la carte de flashcard prend le dessin
> de référence (bandes dégradées par type), et la LISTE rend désormais cette carte (la tuile
> devient un mode). Un hôte qui passait `contentBuilder` ne bouge pas d'une ligne — gardé.

---

## 1. La décision d'invariant qui gouverne ce lot — arbitrée par le propriétaire

Les dégradés de référence ne sont **pas dérivables** du `ColorScheme` — vous l'écriviez, c'est
exact. Le propriétaire a tranché : **exception FR-26 encadrée**. Les hex de référence entrent
comme **défauts de jetons nullables**, à trois conditions désormais inscrites dans la gouvernance
du socle : centralisés dans un **unique fichier de référence audité** (`ZFlashcardCardReference` —
le seul du package autorisé à porter ces valeurs), **remplaçables** par thème et paramètre
(priorité paramètre > jeton > référence), et la garde de source anti-couleurs les **exempte
nominativement** — sa mordance partout ailleurs a été re-prouvée par injection réelle (un hex posé
dans la carte elle-même rougit).

## 2. CR-57 — le dessin de référence, vérifié dans votre code

Vos 4 paires de dégradé sont exactes (`flashcard_widgets.dart:143-156`). **Votre code disait plus
que votre CR**, et c'est le code qui a fait foi : tuile d'icône **32 dp / glyphe 18** (non cotés
par la CR), pastille de pied 6/3 avec point de 6 dp dégradé et texte w500, fond `primary@0.10`,
et une **hauteur fixe de 200** (`:196`) absente de la CR — portée (`cardHeight` par défaut 200,
`height: null` explicite ⇒ hauteur intrinsèque).

* **`typeColors`** (`Map<String, ZGradientSpec>`) — chaîne complète : paramètre → jeton
  `ZcrudTheme.flashcardTypeGradients` → **seam existant `ZcrudScope.gradientResolver`** (clé
  publique `flashcard.type.<name>`) → référence → accent uni. **Aucun second mécanisme de
  dégradé** : la couture de l'epic VIS est réutilisée telle quelle.
* ⚠️ Notre modèle a **6 types**, votre legacy 4 : `fillBlank`/`shortAnswer` replient sur l'accent
  uni dérivé (AD-10) — aucun hex inventé pour eux. Si vous voulez leur dégradé, `typeColors` est là.
* **Votre « non mesuré » n°1 — le contraste, chiffré** : le premier plan sur dégradé est **choisi
  par mesure** (patron `ZGradientSpec.onGradient`, jamais deviné) — blanc pour `multipleChoice`
  (3,66 contre 3,30), noir pour les trois autres (5,97 / 8,66 / 6,46). Et une trouvaille qui vous
  concerne : **votre teinte brute legacy mesurait 2,30:1** en clair sur le libellé de pied —
  le socle porte `zReadableTypeTint` (le port de votre `adjustTagColor`) qui ramène tous les
  premiers plans teintés au-dessus du plancher AA.
* **Votre « non mesuré » n°2 — la préséance** : par défaut, **aucun conflit mesurable** (l'accent
  d'identité dérive déjà de `type.name`). Arbitré et gardé : `typeColors` explicite >
  `colorKey` explicite > défauts de l'axe type ; `colorKey`/`palette` garde les balises et le
  repli total. Un hôte v0.42-45 à `colorKey` explicite conserve son rendu (bande unie) — gardé.

## 3. CR-58 — une carte, toutes les surfaces

`ZFlashcardListItemStyle { card (défaut), tile }` — la liste rend la carte de référence ;
**la tuile n'est pas supprimée** (votre propre réserve) : elle reste le mode compact explicite.
`contentBuilder` fourni ⇒ comportement **strictement inchangé** (gardé) ; `card` + `contentBuilder`
⇒ refus à la construction (AD-4, jamais deux vérités).

* **Coût en liste longue, mesuré** (300 items) : le culling du viewport construit ≈ 12 cartes —
  autant que de tuiles. La virtualisation est gardée **par son mécanisme** (l'injection « grille
  matérialisée » rougit), pas par comptage.
* **Sélection et réordonnancement, gestes réels** : tap sur la case ⇒ sélection ; tap sur la carte
  ⇒ ouverture ; **drag d'appui long réel** ⇒ réordonne sans ouvrir (la carte ne pose pas
  d'`onLongPress` en liste — la leçon CR-54 appliquée avant qu'elle ne morde).

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | adoptez : le rail, la grille et la liste rendent désormais votre dessin sans réglage ; **supprimez votre `FlashcardCard`** et sa recopie de dégradés ; si vous teintiez le libellé de pied avec la couleur brute, **retirez l'ajustement local** — `zReadableTypeTint` est natif |
| **hôte à `colorKey` explicite (v0.42-45)** | rien — bande unie conservée, gardée |
| **hôte passant `contentBuilder` à la liste** | rien — rendu strictement inchangé, gardé |
| **hôte voulant l'ancienne tuile en liste** | `itemStyle: ZFlashcardListItemStyle.tile` — une ligne |
| 🔴 **hôte ayant compensé la rupture rail/liste** (deux builders pour un même objet) | **retirez le doublon de liste** : la carte du rail est désormais la carte de la liste |

🟢 **Tripwire recommandé** : un test qui affirme votre `FlashcardCard` dans l'arbre. Il rougira à
l'adoption, écran par écran.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1175** (+25) · `zcrud_core` **1187** (+5) · **0 error, 0 warning, infos = baseline
exacte (57/10)** · voisins verts : flashcard 586, session 565.

**R3 — 8 injections du lot, toutes ROUGES d'assertion** (bande unie, `onGradient` inversé,
préséance inversée, neutralité rompue, hex hors référence, hauteur retirée, `lerp` matérialisé,
virtualisation cassée) + **1 injection indépendante de l'orchestrateur** sur la garde
anti-couleurs (mord hors exemption). Pendant le développement, la garde de **parité** (CR-48) et le
passe-plat **CR-LEX-78** ont rougi en réel et imposé leurs relais — elles font leur travail.

🔴 **Un warning attrapé par le SEUL gate repo-wide** : un `show` d'import visait le mauvais package
(symbole réel, mauvais propriétaire) — vert en test, invisible au contrôle du lot, rouge à
`melos analyze`. Quatrième régression attrapée par ce gate depuis sa mise en place ; corrigé avant
publication.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 6. Ce que nous savons ne pas avoir couvert

* Pas de dégradé de référence pour `fillBlank`/`shortAnswer` (votre legacy n'en a pas) — repli uni.
* Le mode carte en liste n'affiche pas la **source**, l'**aperçu de réponse** ni le **« +n » de
  balises** que la tuile porte — la tuile reste là pour cela ; candidat CR si vous les voulez sur
  la carte.
* Aucun golden — dégradés et contrastes mesurés en valeurs, jamais au pixel.
* La garde de parité n'est pas injectable en source (l'injection casserait la compilation) — sa
  mordance est observée en réel, pas simulée.
