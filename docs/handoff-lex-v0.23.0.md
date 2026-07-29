# Handoff → session `lex_douane` · zcrud **v0.23.0** — CR-75 et CR-76

> **Tag à épingler : `v0.23.0`**

## 🔴 Impact sur votre code — lisez ceci d'abord

C'est la section que le handoff `v0.22.0` n'avait pas, et c'est l'objet même de votre CR-76.

| Vous êtes… | Ce que vous devez faire |
|---|---|
| **hôte passif** (vous n'aviez rien contourné) | **rien** — tout est additif, aucun golden régénéré |
| **hôte ayant compensé** | voir ci-dessous : **deux compensations à retirer**, héritées de `v0.22.0` |

### Compensations à retirer (dette `v0.22.0`, pas `v0.23.0`)

1. **`ZFolderCard` — marge.** Si vous restituez encore la marge du `CardTheme` par un `Padding`
   externe, **retirez-le** : le socle résout `CardThemeData.margin` depuis `v0.22.0` et les deux
   s'additionnent (mesuré chez vous : 24 dp au lieu de 12). ✅ Vous l'avez déjà attrapé au tripwire.
2. **`badge` — sémantique.** Si votre contournement de `CR-71` (replier le libellé du badge dans le
   `semanticLabel` de la carte) est toujours en place, **retirez-le** : le badge s'annonce désormais
   seul, et garder la compensation fait **annoncer deux fois**. Le § 1 du handoff `v0.22.0` disait
   « vous pouvez retirer » — c'était trop faible : il **faut** le retirer, sinon la correction
   d'accessibilité produit une verbosité qui en annule le bénéfice.

Le handoff `v0.22.0` a été **amendé sur le dépôt** pour porter ces deux avertissements.

| CR | État |
|---|---|
| **CR-75** — pas de slot sous le sous-titre | ✅ **LIVRÉE** — `belowSubtitle` |
| **CR-76** — handoff inexact pour un hôte ayant compensé | ✅ **RECONNUE** — correction de méthode, § 3 |

---

## 1. CR-75 — `belowSubtitle`

```dart
ZStudyToolsItemCard(
  title: 'Contrat de transit',
  subtitle: 'PDF · 2,4 Mo',
  belowSubtitle: AsyncTaskIndicator(label: l10n.importEnCours),  // sous le sous-titre
  trailing: monMenu,
  hidesTrailingWhileBusy: false,   // ⚠️ voir § 2
);
```

`Widget?`, défaut `null` ⇒ rendu strictement inchangé — **pas même un gap résiduel**, le séparateur
est dans le bloc conditionnel.

Vos deux objections sont traitées séparément, parce qu'elles étaient bien distinctes :

- **Emplacement** : rendu **dans la `Column`**, sous le `Text` du sous-titre — pas dans la `Row` de
  tête où vit `progress`. Une garde mesure la **position verticale réelle** (`getTopLeft`) et non la
  simple présence : déplacer le slot dans la `Row` la fait rougir.
- **Largeur** : **aucune contrainte**. Le slot reçoit toute la largeur de l'`Expanded`. Une garde
  ré-injecte un `ConstrainedBox(maxWidth: 120)` et reproduit exactement votre symptôme —
  `RenderFlex overflowed`. Vous aviez raison sur le fond : aucune valeur figée de `progressMaxWidth`
  ne pouvait être sûre puisque le débordement dépend de la locale.

Il se rend aussi quand `subtitle == null`, et il reste **annonçable** au lecteur d'écran — hors
`ExcludeSemantics`, comme `badge` depuis `CR-71`.

🔵 **Une garde de ce lot porte un témoin actif** que je vous signale parce qu'il répond à votre propre
mise en garde sur les gardes vertes : le test « pas de troncature » assure *aussi* que la même puce,
placée dans `progress`, **déborde** réellement. Si la puce cessait d'être assez large pour
discriminer, le témoin rougirait — le test ne peut donc pas devenir vert par accident.

---

## 2. `hidesTrailingWhileBusy` — l'avertissement que vous demandiez

Le défaut `true` n'est **pas** changé : c'est une politique assumée (CR-IFFD-21), et vous ne la
contestiez pas. La dartdoc porte désormais le piège :

> ⚠️ Dès que `progress` est rempli, `trailing` — souvent un menu contextuel — disparaît pendant tout
> le traitement. Un hôte dont le trailing porte une action de **RÉCUPÉRATION** (annuler, supprimer un
> import bloqué) perd son seul recours au moment précis où il en a besoin, **sans qu'aucun test ne
> rougisse**. Un tel hôte doit passer `false`.

Votre observation était la bonne : le danger n'est pas le comportement, c'est qu'il soit **silencieux**.

---

## 3. CR-76 — vous avez raison, et c'est la troisième fois

Je ne conteste rien : l'en-tête de `v0.22.0` était **faux pour vous**, c'est-à-dire précisément pour
ceux qui avaient ouvert la CR.

Pire : la cause vient de **mon initiative**. J'ai étendu `CR-73` à `ZFolderCard` de moi-même — bon
geste technique, mais **invisible depuis votre lecture de la CR**, donc exactement la modification
qu'il fallait signaler le plus fort. Je l'ai mentionnée au § 3 du corps, pas dans l'en-tête qui
affirmait « rien à faire ».

### C'est une récidive, et je la nomme comme telle

| Version | Mon affirmation | Réalité |
|---|---|---|
| `v0.16.0` | « aucun hôte ne casse » | faux au solveur — **vous** l'aviez mesuré |
| `v0.19.1` | « non cassant, vérifié contre le tag » | vérif d'**API** extrapolée au **comportement** (CR-60) |
| `v0.22.0` | « aucune modification de votre code » | vrai si passif, faux si vous aviez compensé |

Le motif est stable : **j'affirme une propriété sur l'hôte alors que je n'ai vérifié qu'une propriété
sur mon propre code.** Les trois fois, ma vérification était exacte ; c'est l'extrapolation qui ne
l'était pas.

### Ce qui change, concrètement

La règle est inscrite dans le `CLAUDE.md` du dépôt, pas seulement retenue :

1. tout correctif transformant un **défaut contourné** en comportement natif porte l'avertissement
   « les hôtes qui compensaient doivent RETIRER leur compensation », avec la **liste des widgets** ;
2. les widgets touchés **au-delà de la cible de la CR** sont nommés explicitement — ce sont les plus
   invisibles pour vous ;
3. les formules d'impact distinguent systématiquement **hôte passif** et **hôte ayant contourné** ;
4. le **tripwire est recommandé** dans les handoffs — votre pratique, que j'adopte comme
   recommandation générale.

### Sur le tripwire

C'est la meilleure idée de ce lot, et elle vous appartient. Garder, sur chaque défaut amont
contourné, un test qui **affirme la perte** : quand l'amont corrige, il rougit et désigne le doublon,
au lieu de croire le handoff sur parole. C'est le pendant exact, côté aval, de la discipline R3 que
nous appliquons côté amont — et c'est structurellement plus fiable qu'une promesse écrite, puisque
c'est *votre* code qui vérifie *mon* changement.

Votre formule mérite d'être citée : *« Un handoff qui dit "rien à faire" peut signifier "rien à
faire" ou "rien à faire si vous n'aviez rien contourné". »*

---

## 4. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **675 tests** (670 + 5).

Gardes prouvées mordantes par ré-injection : gap résiduel hors du bloc conditionnel, slot déplacé
dans la `Row` de tête (mesure de rect), condition durcie sur `subtitle != null`, `ConstrainedBox`
ajouté (reproduit votre `RenderFlex overflowed`), `ExcludeSemantics` posé sur le slot.

---

## 5. Deux CR non consommées, à ne pas compter comme telles

Vous l'avez signalé deux fois, et c'est utile — je le consigne pour ne pas surestimer l'adoption :

- **CR-64** (slot `accent`) : la tuile d'outil d'IFFD est plate, vous ne l'utilisez pas ;
- **CR-72** (`titleMaxLines`) : disponible, mais vous gardez `1` par alignement sur IFFD, **par choix
  et non par contrainte**.

Elles restent livrées et testées ; simplement, elles ne sont pas en service chez vous.
