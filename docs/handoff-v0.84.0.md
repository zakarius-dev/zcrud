# Handoff **v0.84.0** — la barre d'outils dérive ses rangées de la surface

> **Tag à épingler : `v0.84.0`** — répond à `cr-markdown-toolbar-multirow-by-surface`.
> **Correction de défaut, sans configuration requise** : le bon rendu s'applique tout seul.
> Aucun jeton nouveau, aucune arête, 39 paquets.

---

## 1. Ce qui change

`multiRow` devient **tri-état** (`bool?`), exactement la forme suggérée :

| Valeur | Effet |
|---|---|
| `null` (défaut) | **AUTO** — une rangée défilante en flux, multi-rangées en plein écran |
| `true` / `false` | forçage hôte, respecté sur les **deux** surfaces (gardé) |

**Le danger était réel et il est chiffré** : sur 400 dp de large avec votre préset (markdown +
undo/redo), une barre forcée multi-rangées en flux mesure **261,6 dp** (~5,5 rangées) ; l'AUTO
rend **67,2 dp** (une rangée). C'est la différence entre un champ et un champ qui mange l'écran.

🔵 **Le mode `block`, tranché par la mesure — et la réponse est structurelle** : le rendu block en
flux ne monte **aucune** toolbar (prouvé) — sa seule barre vit dans le dialog plein écran, donc
multi-rangées via l'AUTO du dialog. La règle écrite : **une rangée pour toute barre en flux.**

## 2. Migration `bool` → `bool?`

**Personne ne casse — mesuré, pas affirmé** : le seul consommateur du drapeau sur vos quatre dépôts
est votre propre contournement (`copyWith(multiRow: false)`), qui compile inchangé et garde
exactement son comportement (c'est désormais un forçage). Aucun hôte ne lit `multiRow` comme `bool`.
Le `copyWith` distingue « omis » (valeur conservée) de « `null` explicite » (**retour à l'AUTO**) —
gardé.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| 🔴 **DODLP** | **retirez votre `multiRow: false`** de contournement — c'est lui qui vous prive du multi-rangées en plein écran. Si vous le gardez, rien ne change pour vous |
| **hôte passif** | rien — le flux est inchangé, le plein écran **gagne** le multi-rangées (le correctif demandé) |
| **hôte qui force `true`** | inchangé — mais sachez ce que ça mesure en flux (§ 1) |

## 4. Votre remarque de principe — inventoriée, non corrigée

Vous aviez raison de généraliser : le **jeu de boutons** (`showXxx`) est structurellement dans le
même cas (une config partagée par deux surfaces alors que le préset complet a du sens en plein
écran, moins en flux). Verdict mesuré : **pas flagrant** — la rangée défilante absorbe 17+ boutons
en 67 dp — mais le fix candidat existe (config par surface). `toolbarSize` (plancher 48 dp AD-13),
`roundedIcons`, `themedBarBackground`, `showSearch` : surface-indépendants ou mineurs.
**Votre arbitrage** : si vous voulez la config par surface, une CR d'une ligne suffit.

## 5. Vérification

`melos generate` **RC=0** (0 `.g.dart`) · `melos analyze` **RC=0** · `melos verify` **RC=0** —
rejoués **après** le bump.
`zcrud_markdown` **579** (+10). **0 erreur, 0 avertissement.**

**R3 — 4 injections, toutes rouges par ASSERTION** (AUTO du dialog, AUTO du champ, sentinelle du
`copyWith`, forçage ignoré), sha avant/après, restauration par copie, résidus par grep négatif
montré. **Lignes de base dans les deux sens** — les gardes du plein écran sont nées ROUGES sur
v0.83.0 ; celles du flux ont été vérifiées **discriminantes** (le flux rendait déjà une rangée :
une garde naïve aurait été verte par accident).

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.

* Dettes antérieures : cf. `v0.83.0` et les handoffs précédents (B3 vous attend toujours).
