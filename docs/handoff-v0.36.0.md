# Handoff **v0.36.0** — CR-IFFD-41 : la référence visuelle de la barre de fratrie

> **Tag à épingler : `v0.36.0`** · aucune rupture d'API · 🔴 **changement de comportement** :
> la fratrie se déploie désormais en **feuille modale**, plus en ligne.

---

## 1. Vos neuf écarts, et ce qu'ils sont devenus

Votre revirement était légitime et vous l'avez dit franchement — la CR-40 avait laissé la forme
« à l'appréciation du socle » faute de l'avoir spécifiée. Elle est désormais fixée.

**Cinq points sont livrés en STRUCTURE, codés dans le socle :**

| # | Ce qui est fait |
|---|---|
| 3 | **feuille modale**, plafonnée à **80 % de la hauteur d'écran** — remplace le panneau en ligne |
| 5 | **indentation 24 dp + filet vertical**, tous deux **directionnels** (votre `EdgeInsets.only(left:)` d'origine aurait cassé en RTL) |
| 7 | la **racine est toujours visible**, hors de la liste défilante, même chrome, même voie de sélection, **sans indentation** |
| 8 | **`itemActionBuilder`** — nouveau slot d'action par élément |
| 9 | **câblé, rien créé** — `addAction`/`addLabel`/`addIcon` existaient déjà ; `addLabel` devient un libellé **affiché** dans le pied, au lieu d'être seulement annoncé |

**Quatre points sont livrés en TOKENS**, parce que **FR-26 interdit toute couleur ou tout style codé
en dur dans un paquet** — sinon DODLP et DLCFTI hériteraient d'un look qui ne les concerne pas :

| # | Token | Sans préréglage |
|---|---|---|
| 1 | variante du déclencheur (`flat`/`outlined`/`filled`) | `flat` — **aucun élément** ajouté à l'arbre |
| 2 | glyphes du chevron (replié / déployé) | `expand_more` / `expand_less` |
| 6 | emphase de l'élément courant (`highlight`/`inverted`) | `highlight` — rendu historique |

👉 Le **préréglage « façon IFFD »** est livré dans `example/lib/demos/iffd_visual_preset.dart` :
posez-le, et le socle rend **exactement votre maquette**.

⚠️ **Le point 4 (titre de la surface) ne pouvait pas être un token** : c'est une **chaîne visible**,
donc de la localisation, qui vous appartient. Elle passe par un slot de la spec, `null` par défaut.

## 2. 🔴 L'inversion : livrée comme capacité, pas comme deux couleurs

Vous insistiez, à raison : *« l'élément courant est INVERSÉ, pas surligné — c'est ce contraste maximal
qui le rend lisible d'un coup d'œil »*.

Nous l'avons modélisée par le couple de rôles **`inverseSurface` / `onInverseSurface`** — par
définition le contraste maximal du schéma courant, **dans les deux luminosités**. Vous obtenez
l'effet voulu ; un hôte au thème sombre l'obtient aussi, sans hériter de vos deux valeurs.

🟢 **Un défaut a été corrigé en route, et il ne vous aurait frappé que si vous faisiez bien votre
travail** : le contenu est désormais **construit sous** les enveloppes d'inversion. Auparavant, un
`itemBuilder` qui lit `IconTheme.of(context)` pour se colorer récupérait la couleur **ambiante** —
donc illisible sur le fond opaque — alors que les icônes et textes nus, eux, s'inversaient bien.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans préréglage, seul le déploiement change (modale au lieu d'en ligne) |
| **vous, IFFD** | posez le préréglage, renseignez le titre de la feuille et le libellé d'ajout, branchez `itemActionBuilder` sur votre menu de sous-dossier |
| 🔴 **hôte ayant COMPENSÉ le déploiement en ligne de `v0.34.0`** | **retirez votre compensation** — réserve de hauteur sous la barre, défilement vers le panneau, fermeture pilotée : **la fratrie ne pousse plus le corps de la page** |
| vous préférez l'ancien défileur | `narrowMode: ZSubfolderNarrowMode.compact` — inchangé, garde de non-régression dédiée |

⚠️ **Ce changement n'est pas une correction de défaut.** Contrairement à la CR-40, personne n'a
prétendu que le déploiement en ligne était mauvais : c'est un **choix de référence visuelle**, tranché
par le propriétaire. Nous le disons ainsi plutôt que de le déguiser.

## 4. 🟢 Tripwire recommandé

Si vous compensiez le panneau en ligne, gardez un test qui **affirme votre compensation** — par
exemple que le corps de page est décalé quand la fratrie est ouverte. Il rougira à l'adoption de
`v0.36.0` et vous désignera le code devenu inutile.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **861** (+30) · `zcrud_core` **1136** (+5) · **0 error, 0 warning** ·
**zéro couleur littérale ajoutée dans un paquet** (vérifié).

**17 injections R3**, toutes rouges d'assertion, aucune de compilation.

🟢 **Deux gardes de nous trouvées vertes-pour-rien, et retendues** — nous les signalons parce que
la seconde touche votre affirmation :
* la mesure de contraste comparait l'inversion au *« texte ordinaire sur surface »* : **verte sur
  rien**, le noir sur blanc gagnant toujours en écart brut. Remplacée par les deux propriétés
  réellement en jeu — le couple est lisible, **et** il détache l'élément courant **plus que le
  surlignage qu'il remplace**. C'est exactement votre affirmation, désormais mesurée ;
* la garde d'icônes inversées piégeait le thème depuis l'`itemBuilder` — or le **déclencheur invoque
  le même builder** : la trace ne savait pas de qui elle parlait.

Un **défaut de production** a aussi été révélé par une garde : ouvrir les sémantiques de l'élément
pour laisser passer l'action faisait annoncer le libellé **deux fois**. L'action est désormais posée
**hors** du conteneur sémantique.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 6. Ce que nous savons ne pas avoir couvert

* **`example/` ne rend aucun écran de détail de dossier** (il ne dépend pas de `zcrud_study`) : seule
  la moitié « tokens » du préréglage est **vivante à l'exécution**. Les deux libellés y sont des
  constantes documentées, jamais assemblées.
* **Aucun golden** : le rendu est asserté par rôles, clés et géométrie — jamais au pixel. Votre QA
  sur appareil reste la seule preuve visuelle.
* Le contraste est mesuré en **écart de luminance**, pas en ratio WCAG 4.5:1.
* Le plafond de 80 % est calculé **à l'ouverture** : une rotation pendant que la feuille est ouverte
  n'est pas recalculée.
* Les points 3 à 9 ne concernent que la surface **étroite** : la sidebar n'est pas touchée — c'est le
  périmètre de votre CR, mais **l'écart de forme entre les deux côtés du seuil s'en trouve creusé**.
