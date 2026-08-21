# Handoff **v3.2.0** — CR-IFFD-83 et 84 (volet A, lot 1), et un défaut plus large trouvé en chemin

> **Tag à épingler : `v3.2.0`** — paquets porteurs : **`zcrud_study`**, **`zcrud_chat`**,
> **`zcrud_chat_kernel`**. Additif, sauf deux corrections de géométrie décrites au §2.

---

## 1. CR-IFFD-83 — la pastille volait le tap

Corrigé. Votre mesure était exacte, et votre avertissement aussi : **neutraliser le seul label ne
suffit pas.** Cinq montages ont été mesurés sur le même harnais, et la cause exacte est nommée —
l'absorbeur n'est ni le texte ni le badge, mais **la boîte décorée du stade**, qui se déclare
sensible dès que sa forme contient le point.

**Rendu iso-pixel prouvé** : tuile, pastille, nombre et glyphe aux mêmes rectangles avant/après.

Notre garde ne se contente pas de taper « près du coin » : elle **calcule** le centre de
l'intersection tuile ∩ pastille et **asserte** que le point y tombe avant de taper — parce qu'avec un
libellé court, la pastille ne recouvre aucun pixel tappable et la garde serait inerte.

## 2. 🔴 Un défaut PLUS LARGE que celui que vous signaliez

En corrigeant le vôtre, nous avons mesuré que la pastille **rétrécissait la tuile** :

| tuile d'action | dimensions |
|---|---|
| **avec** compte | `93,3 × 48` |
| **sans** compte | `93,3 × 96` |

**La moitié basse de la cellule était morte** pour toute action portant un compte — et avec un
libellé court, **les trois quarts**. C'est bien plus de taps perdus que le rectangle de la pastille.

Conséquence que personne n'avait vue : dans la même grille, le glyphe d'une action **avec** compte
était **24 dp plus haut** que celui d'une action sans compte. Le correctif les **aligne** — ce n'est
donc pas un déplacement, c'est la fin d'une incohérence. La pastille, elle, ne bouge pas d'un pixel.

⚠️ **Conséquence pour votre relevé** : avec des libellés courts — le cas de la grille par défaut —
le scénario exact de votre CR **ne se reproduisait pas**, un autre s'y substituait. Si vous aviez
tenté de le reproduire ainsi sans succès, c'est pourquoi.

## 3. CR-IFFD-84 volet A, lot 1 — les artefacts se déclarent

`ZChatArtifactSpec` : une **clé opaque**, un glyphe, un libellé, trois lectures d'état (présence,
compte, occupation) et une liste de verbes. Le socle **ne connaît ni `mindmap` ni `flashcards`** —
vos identités et votre stockage restent chez vous, comme vous le demandiez.

Rendu par le socle : le glyphe **teinté quand l'artefact existe** — *« c'est un ÉTAT, pas un
style »*, votre formule est devenue la garde —, la pastille, le menu conditionnel, la confirmation.

**Vos deux exigences de parité sont tenues** : l'**ordre** des verbes est celui que vous déclarez, et
leur teinte est déclarable **par artefact**. Un mécanisme qui imposerait un ordre unique vous
forcerait à choisir entre le socle et vos repères — nous ne l'avons pas fait.

**Et votre constat d'ouverture était juste** : `capabilityAccents` existait **sans aucun
consommateur**. La chaîne `spec > skin > jeton > référence` en est le premier lecteur, résolue **par
clé** — donc une clé que vous inventez est servie aussi.

**Contraste** : la teinte respecte le plancher **même si vous en déclarez une qui ne le respecte
pas**. Et sans surface mesurable, **aucune teinte n'est peinte** — l'état reste porté par l'annonce
et la pastille, jamais perdu.

⚠️ **Votre chiffre de contraste et le nôtre sont tous deux exacts** : `#FF9800` rend **2,155** sur
blanc pur (notre référence) et **2,049** sur la surface réelle du thème clair (votre mesure). Notre
référence gagnerait à nommer sa surface ; nous le ferons.

### Ce que ce lot ne fait PAS — les trois autres tranches
L'**animation d'occupation** et « Réduire les animations » ; l'extension de la table de référence de
**5 à 9** entrées ; le **volet B** (la coquille de carte) ; le **débordement** au-delà d'un
téléphone. Chacune aura son lot. `busy` est déjà **déclaré et consommé par l'annonce** — il n'est
simplement pas encore animé.

## 4. Deux dettes que nous nous créons, et que nous nommons

- **Un calculateur de teinte lisible a été dupliqué** dans `zcrud_chat` : l'original vit dans un
  satellite frère, et une arête entre satellites violerait notre invariant de dépendances. Le
  duplicata est fonctionnellement identique et sans couleur littérale. Son vrai domicile est le
  cœur ; nous l'y remonterons dans un lot dédié.
- **Une garde de notre socle a dû être élargie** (`capabilityAccents` ne pouvait plus rester sans
  lecteur), et l'arbitrage est écrit dans la garde elle-même. Ce qu'elle protégeait — l'hôte passif —
  l'est désormais par **deux mesures plus précises** : un contre-témoin à comptes absolus, et une
  garde neuve « la vue **relaie** le skin, elle ne le **construit** ni ne le **résout** ».

## 5. Une garde de contrat corrigée

Votre nouveau mécanisme a fait rougir une garde du noyau qui interdit d'invoquer un verbe hors du
répartiteur — elle attrapait un **constructeur nommé** homonyme, donc une déclaration et non un
appel. **La propriété est inchangée** ; seul le proxy a été resserré, et prouvé dans les deux sens.

## 6. État des vérifications

`melos run generate` RC=0 · `melos run analyze` **repo-wide** RC=0 · `melos run verify` RC=0.
**Balayage complet des 40 paquets** : `zcrud_study` **1551** (+11) · `zcrud_chat` **579** (+23) ·
`zcrud_chat_kernel` **411** (base retrouvée) · tous les autres inchangés et verts.
⚠️ `zcrud_generator` échoue de façon **environnementale** (`Isolate.packageConfig` via `build_test`)
— paquet intact, rouge qualifié.

Injections R3 sur les quatre lots, rouges **par assertion**. **Trois gardes sont restées vertes sous
injection, et leurs auteurs l'ont dit** plutôt que de les compter comme mordantes : deux ont été
renforcées jusqu'à mordre, la troisième déclarée comme contre-témoin avec la raison. C'est ce que la
discipline attend, et c'est ce qui rend les autres chiffres crédibles.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
