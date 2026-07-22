# Handoff → session `IFFD` · zcrud **v0.4.2** — réponse à CR-IFFD-10

> **Tag à épingler : `v0.4.2`** (et non `v0.4.1` — voir § 5).
> **CR-IFFD-10 : ✅ livrée — les QUATRE points, pas seulement les deux bloquants.**

---

## 1. Votre CR était juste sur les quatre points

Vérifié sur disque : `ZStudyToolsSectionSpec` n'exposait ni `collapsible`, ni
`initiallyExpanded`, ni `crossAxis*`, ni `headerCount`, ni `secondaryAction` — votre grep
négatif était exact.

Le contexte que vous souligniez pesait dans la décision : **`ZStudyToolsPage` a été portée
depuis votre propre `folder_study_tools_page.dart`**. Une capacité de la page d'origine
absente du portage n'est pas une demande d'évolution, c'est une **régression de parité**.
Nous avons donc livré les quatre, y compris les deux que vous aviez contournés.

---

## 2. Ce qui est ajouté

### §1 — Sections repliables

```dart
ZStudyToolsSectionSpec(
  collapsible: true,
  initiallyExpanded: items.isNotEmpty,   // ← votre patron d'origine
  …
)
```

**Le point qui méritait de l'attention** : l'état plié/déplié vit **localement**, dans un
`StatefulWidget` sous la frontière keyée `ValueKey('section:$id')` — exactement comme
l'ordre optimiste du réordonnancement. **Replier une section ne reconstruit ni les autres
sections ni la page** (SM-1/AD-2). Une implémentation naïve, avec l'état remonté à la page,
aurait livré la capacité en cassant l'invariant produit n° 1.

Bouton de bascule : clé `ValueKey('section:$id:collapse')`, cible ≥ 48 dp, `semanticLabel`
« Replier/Déplier {titre} ».

### §2 — Grille multi-colonnes

```dart
ZStudyToolsSectionSpec(crossAxisMinItemWidth: 300, …)   // votre itemMinWidth
```

Le nombre de colonnes est dérivé de la **largeur disponible**, jamais d'un breakpoint figé.
`null` (défaut) ⇒ une colonne, rendu antérieur inchangé.

### §3 — Action d'en-tête secondaire

```dart
ZStudyToolsSectionSpec(
  addAction: _create,                    // « Ajouter »
  secondaryAction: _showAll,             // « Afficher tout » — enfin distincte
  secondaryActionIcon: Icons.arrow_forward,
  secondaryActionSemanticLabel: 'Afficher tous les documents',
  …
)
```

Rendue **avant** l'ajout (consultation avant création). Vous pouvez **abandonner le
détournement d'`addAction`** : les deux coexistent, chacune avec sa sémantique propre.

### §4 — Compteur d'en-tête découplé

```dart
ZStudyToolsSectionSpec(itemCount: 10, headerCount: 42, …)   // rail tronqué, badge exact
```

Votre patron d'origine est de nouveau exprimable.

---

## 3. Rétro-compatibilité — prouvée, pas annoncée

Tous les défauts (`collapsible: false`, `crossAxisMinItemWidth: null`, `headerCount: null`,
`secondaryAction: null`) préservent le rendu antérieur à l'identique.

**La preuve : le golden de `zcrud_study` passe SANS régénération.** C'est le contrôle qui
compte pour un changement de layout — un golden qu'il faut régénérer signalerait un
déplacement de pixels non voulu.

`zcrud_study` **501/501**, gardes CR-IFFD-10 **11/11**, `melos run verify` RC=0 (11 gates).

---

## 4. Ce que vous pouvez retirer côté IFFD

- le **détournement d'`addAction`** pour la navigation (§3) ;
- l'**écart documenté** sur le badge vs le rail (§4) ;
- les deux **écarts d'apparence assumés** (§1 repliage, §2 grille) — ce ne sont plus des
  écarts.

La première étape W6 peut passer du flag LEGACY au flag zcrud sur ces quatre points.

---

## 5. ⚠️ Pourquoi `v0.4.2` et pas `v0.4.1`

`v0.4.1` livrait les quatre capacités, mais la grille (§2) y était **réimplémentée à la
main** — calcul de colonnes et assemblage `Row`/`Column` écrits pour l'occasion.

L'owner a demandé : *« le package `zcrud_responsive` n'est pas utile ici ? »*. Il l'était.
`zcrud_study` **en dépend déjà** (arête ajoutée en SU-8) et l'utilise déjà dans
`z_flashcard_list_view` et `z_multi_flashcard_editor` — et ce package expose exactement
cette primitive : **`ZAdaptiveGrid`** et **`computeCrossAxisCount`**.

La brique existante est **meilleure** que la réimplémentation : elle gère la gouttière, le
padding horizontal, le plancher/plafond de colonnes et les replis AD-10 (NaN, infini,
négatif) — tous absents de notre code. Elle offre en outre un constructeur `.builder`
**virtualisé** (NFR-SU9), qui sera la réponse immédiate si une de vos sections devient
volumineuse.

`v0.4.2` corrige cela. **Aucun changement de comportement** : mêmes gardes, mêmes
résultats. Épinglez `v0.4.2`.

C'est la règle « ne réimplémente rien » que nous vous imposons, enfreinte de notre côté. Le
réflexe qui a manqué : **vérifier ce que les packages déjà dépendus exposent avant d'écrire
une primitive**. Il vaut pour vous aussi — `zcrud_responsive` est atteignable depuis votre
graphe dès que vous consommez `zcrud_study`.

---

## 6. Registre

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque |
| CR-IFFD-2..7 | — | ✅ livrées (v0.3.2 → v0.3.6) |
| CR-IFFD-8 | majeur | ✅ livrée (v0.3.7) |
| CR-IFFD-9 | mineur | ✅ traitée (v0.3.7) — décision owner appliquée de votre côté |
| CR-IFFD-10 | majeur | ✅ **livrée (v0.4.2)** |

**Aucune CR ouverte.**

---

## 7. Deux points à connaître avant de câbler

**`ZAdaptiveGrid.builder` existe** — si une section dépasse quelques dizaines d'items, la
grille actuelle (eager, `shrinkWrap`) layoute **tout**. Signalez-le et nous exposerons le
mode virtualisé sur la spec ; la primitive est déjà là, seul le câblage manque.

**Le repliage n'est pas animé.** Le corps apparaît/disparaît sans transition — délibéré :
une animation exigerait un `AnimationController`, donc un arbitrage Reduce Motion
(`zReduceMotionOf`). Si la parité visuelle avec votre `ExpandablePanel` l'exige, émettez une
CR en précisant le comportement attendu sous Reduce Motion — c'est ce point qui décidera de
la forme.
