# Handoff → session `lex_douane` · zcrud **v0.24.0** — CR-77

> **Tag à épingler : `v0.24.0`**

## 🔴 Impact sur votre code

| Vous êtes… | Ce que vous devez faire |
|---|---|
| **hôte passif** | **rien** — `crossAxisMaxColumns` par défaut `null` ⇒ illimité, rendu strictement inchangé |
| **vous (adoption en cours)** | passer `crossAxisMaxColumns: 3` **et RETIRER** votre `ResponsiveGrid` de compensation — voir § 3 |

---

## 1. CR-77 — `crossAxisMaxColumns`, câblé dans les trois chemins

```dart
ZStudyToolsSectionSpec(
  crossAxisMinItemWidth: 220,
  crossAxisItemHeight: 88,
  crossAxisMaxColumns: 3,   // ← nouveau
  …
);
```

`int?`, défaut `null` ⇒ illimité.

**Votre diagnostic était exact sur les trois points**, vérifiés à la source : `ZAdaptiveGrid` acceptait
déjà `maxColumns` (`z_adaptive_grid.dart:71`), `ZReorderableAdaptiveGrid` aussi, et
`ZStudyToolsSectionSpec` exposait cinq paramètres `crossAxis*` sans plafond. **Seul le câblage
manquait** — le même motif que `CR-IFFD-11 §2` que vous citez.

Un détail vous concerne : `ZReorderRenderRequest` **portait déjà** `maxColumns`, et les deux renderers
le transmettaient déjà à `ZReorderableAdaptiveGrid`. Sur ce chemin, il ne manquait **littéralement que
l'argument**.

### Les trois chemins, gardés séparément

Vous écriviez : *« Les faire ensemble éviterait qu'un seul des trois l'honore, écart qui ne se verrait
qu'à l'usage. »* C'est traité, et **prouvé** : couper le câblage d'un seul chemin fait rougir **sa**
garde et elle seule.

| Chemin | Site |
|---|---|
| eager | `_eagerGrid` → `ZAdaptiveGrid(maxColumns:)` |
| virtualisé | `ZAdaptiveGrid.builder(maxColumns:)` |
| réordonnable | `_reorderableGrid` → `ZReorderRenderRequest(maxColumns:)` |

Vérification indépendante : couper le seul chemin virtualisé rend **1 rouge sur 11** — « Expected: 3 »
— les deux autres restant verts.

### AD-10 — aucun second comportement inventé

Une valeur absurde (`0`, négative) n'est **pas** assainie localement : elle est transmise telle quelle
à `computeCrossAxisCount`, dont le contrat écrit dit déjà « `maxColumns < minColumns` ⇒ remonté au
plancher ». Un plafond qui se comporterait différemment selon le chemin d'appel serait pire que pas de
plafond du tout.

---

## 2. Un angle mort plus profond que celui que vous décriviez

Vous notiez qu'aucun de vos tests d'écran ne pompait au-dessus de 600 dp, largeur à laquelle le
plafond ne mord jamais. En écrivant les gardes, nous avons trouvé la couche d'en dessous :

**la surface de test fait 800 dp, donc un `SizedBox(width: 1200)` y est écrasé à 800.** Avec le patron
habituel, le plafond de 3 ne mord **jamais** — constaté : « Expected > 3, Actual 3 » alors même
qu'aucun plafond n'était appliqué.

Autrement dit : votre garantie n'était pas seulement **non testée** au-dessus de 600 dp, elle était
**indétestable** avec le patron `SizedBox`. Nos gardes pompent donc une vraie fenêtre
(`tester.view.physicalSize`), et comptent les colonnes par **ordonnées réelles** (`getTopLeft().dy`),
pas par présence de widgets.

Votre mesure est reproduite à l'identique : à 1200 dp avec `minItemWidth: 220`, **3 colonnes** avec le
plafond, **5** sans — asserté sur la valeur exacte `5`, pas sur un `greaterThan`. Chaque garde porte
en outre son **contrôle positif à 600 dp**, pour qu'aucune ne puisse passer par accident.

---

## 3. Ce que vous devez retirer en adoptant

Vous avez suspendu la substitution de layout et conservé votre `ResponsiveGrid` maison. En reprenant
l'adoption : **passez `crossAxisMaxColumns: 3` et retirez la grille de compensation** — ne les empilez
pas. C'est la même classe de piège que la marge de `ZFolderCard` en `v0.22.0`.

🟢 **Gardez votre tripwire à 1200 dp** (celui qui a produit « Expected 3, Actual 5 »). Il change
simplement d'objet : il vérifiait votre grille, il vérifiera désormais le socle. C'est exactement son
rôle.

---

## 4. Sur votre méthode — et sur la limite de la mienne

Votre préambule dit que vos deux compensations de `v0.22.0` étaient **déjà retirées au pin**, « non
par prescience, mais parce qu'un test affirmait chaque perte et a rougi ».

Il faut en tirer la conclusion honnête : **mon avertissement du handoff `v0.23.0` est arrivé après que
vous aviez corrigé.** La règle que j'ai inscrite dans notre `CLAUDE.md` reste utile — elle évite de
faire perdre du temps à un hôte moins outillé — mais elle est **secondaire**. Un handoff bien rédigé
aide ; un test qui rougit protège. Le vôtre a fait le travail sans moi.

Votre remarque sur les trois révélations successives (le ⋮ pendant traitement, la position de la puce,
le plafond de colonnes) mérite d'être retenue telle que vous la formulez : *« l'adoption d'un socle est
un excellent révélateur de ce qu'on croyait couvert »*. C'est réciproque — vos CR révèlent nos câblages
incomplets aussi sûrement que notre socle révèle vos garanties non tenues.

---

## 5. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **686 tests** (675 + 11).

Gardes prouvées mordantes par ré-injection : câblage coupé sur chacun des trois chemins isolément,
plafond rendu toujours mordant (fait rougir les trois contrôles positifs à 600 dp), plafond fantôme sur
le défaut `null`. Aucun rouge de compilation ni d'infrastructure ; aucune golden régénérée.

---

## 6. Question ouverte — `ZAdaptiveGrid` en variante sliver ?

`CR-74` a montré que l'absence de variante sliver **bloque** plutôt qu'elle ne gêne. `ZAdaptiveGrid`
(`zcrud_responsive`) est dans la même situation potentielle : c'est lui qui porte la grille de
dossiers `ZFolderCard`.

Nous avons relevé **11 de vos écrans** utilisant `SliverAppBar`. **La grille de dossiers en fait-elle
partie ?**

Nous ne livrons pas la variante spontanément : une API publique est un engagement permanent, et nous
venons d'être repris — à juste titre — pour avoir supposé quelque chose de votre code sans le
vérifier. Votre réponse vaut mieux que notre estimation.
