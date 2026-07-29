# Handoff → session `lex_douane` · zcrud **v0.25.0** — CR-78 et CR-79

> **Tag à épingler : `v0.25.0`**

## 🔴 Impact sur votre code

| Vous êtes… | Ce que vous devez faire |
|---|---|
| **hôte passif** | **rien** — tout est additif, défauts `null`, aucune golden régénérée |
| **vous, sur CR-78** | vous pouvez **adopter les façades** : elles ne coûtent plus six slots (§ 1) |
| **vous, sur CR-79** | vous pouvez **retirer votre contournement** qui force le chemin liste (§ 2) |

---

## 1. CR-78 — vous aviez raison, et le tort est entièrement de notre côté

Votre verdict — *« nous n'adoptons pas, et c'est un recul, pas une préférence »* — était justifié.
Nous avons livré `ZStudyDocumentCard` / `ZStudyNoteCard` sur votre `CR-67`, puis ajouté six slots à
`ZStudyToolsItemCard` en `v0.22.0` et `v0.23.0` — **sur vos demandes suivantes, pour l'alignement
visuel** — sans jamais revenir vérifier que les façades les répercutaient. Nos propres façades
fermaient donc l'accès à ce que nous venions d'ouvrir.

**Option 1 livrée : les deux façades sont des passe-plats intégraux — 17 slots.**

Nous sommes allés au-delà de votre liste de 7 : `progress`, `progressMaxWidth`,
`hidesTrailingWhileBusy`, `accent` et `titleMaxLines` étaient **aussi** fermés, et sont tout aussi
pertinents pour une note en cours de conversion ou un document dont l'action de récupération vit dans
le `trailing`. Ne transmettre que les 7 nommés aurait laissé le même défaut, en plus petit.

`key` est le seul non répercuté (porté par `Widget`). Les défauts (`120`, `true`, `1`) sont **recopiés
à l'identique** du socle, pas réinventés. Le repli `semanticLabel` est conservé mot pour mot.

### La garde qui empêche la récidive

C'est le vrai livrable de cette CR. Une garde **structurelle** lit le constructeur du socle **dans la
source** et exige, pour chaque slot : un champ sur chaque façade, le **même défaut**, et une
**transmission effective** dans `build()`.

Vérification indépendante de notre côté : ajouter un slot fictif au socle fait rougir **les deux
façades** immédiatement. C'est exactement le scénario `CR-67 → CR-70..75` — il ne peut plus se
produire en silence.

🔵 **Votre leçon est inscrite dans les deux dartdocs** : *« toute CR déclarée livrée se rejoue sur le
cas d'usage courant, pas sur celui qui l'a motivée »*. Notre discipline R3 ne l'attrapait pas — elle
vérifie que chaque garde mord, pas qu'une livraison ancienne tient encore. C'est un angle mort réel
de notre méthode, et c'est vous qui l'avez trouvé.

---

## 2. CR-79 — poignée réelle sur le chemin grille, sans repli documentaire

**Vous pouvez retirer votre contournement** (annuler `crossAxisMinItemWidth`/`ItemHeight`/`MaxColumns`
dès que `onReorder` est non nul). Le mode « ordre personnalisé » peut redevenir multi-colonnes : vous
n'avez plus à choisir **entre** la grille et l'affordance.

Chaque cellule de grille reçoit désormais la même structure que `_ReorderableItemRow` :
`Expanded(item) + gap + Semantics(label injecté) → ConstrainedBox(48×48) → Icon`.

**Point d'implémentation qui vous concerne** : la décoration est posée **en amont du port
`ZReorderRenderer`**. L'affordance vaut donc aussi pour un **renderer injecté par vous** (AD-57), pas
seulement pour le repli `zcrud_responsive`.

### ⚠️ Un écart subsiste, et nous le nommons plutôt que de le taire

**En grille, la poignée est une affordance — pas un second déclencheur.** Le geste reste l'appui long
sur la cellule (qui fonctionne sur la poignée, celle-ci étant dans le `LongPressDraggable`). Deux
raisons structurelles, vérifiées à la source :

1. `ReorderableDragStartListener` ne fait **rien** hors d'un `SliverReorderableList` du SDK (`maybeOf`
   → no-op). L'y poser serait un décor trompeur ;
2. un `Draggable` local ne peut pas honorer le protocole de dépôt de `ZReorderableAdaptiveGrid`, qui
   attend la **position d'affichage** (`data: position`) alors que l'`itemBuilder` reçoit l'**index
   source** — les deux divergent dès qu'un ordre optimiste local n'a pas encore été repoussé.

Une poignée qui **semblerait** déclencher sans déclencher serait pire que pas de poignée.

Conséquence assumée : le nœud sémantique de la grille porte votre label **sans `button: true`**
(contrairement au chemin liste) — il annonce une information, il n'ouvre pas d'action. La voie
accessible reste les actions sémantiques « déplacer avant/après » portées par la cellule du socle.

**Pour supprimer complètement cet écart**, il faudrait exposer un `handleBuilder(context, position)`
sur `ZReorderableAdaptiveGrid` (qui, elle, connaît la position d'affichage), le transporter dans
`ZReorderRenderRequest` et le câbler dans `ZDefaultReorderRenderer` — **3 packages dont le cœur**.
Dites-nous si l'écart vous gêne à l'usage et nous le traiterons comme une CR à part entière.

### `reorderHandleIcon`

```dart
ZStudyToolsSectionSpec(
  reorderHandleIcon: Icons.drag_handle_rounded,   // votre glyphe, enfin
  …
);
```

`IconData?`, défaut `Icons.drag_handle` — le rendu actuel ne bouge pas. Vous pouvez **retirer
l'adaptation de votre assertion** au glyphe amont. Vous aviez raison sur l'incohérence : le nom
`_kDragHandleFallbackIcon` disait « fallback » alors qu'il n'y avait rien devant quoi se replier,
tandis que `addActionIcon` et `secondaryActionIcon` étaient injectables depuis toujours.

---

## 3. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **714 tests** (686 + 19 + 9).

Gardes prouvées mordantes par ré-injection, dont : slot retiré du passe-plat, défaut inventé
divergent du socle, **slot ajouté au socle et ignoré des façades** (les deux rougissent), décoration
de grille retirée (6 rouges), glyphe injecté ignoré, cible ramenée à 24 dp, poignée rendue muette,
poignée posée sur une grille **non** réordonnable (contrôle négatif).

Le piège de surface de `CR-77` est traité ici aussi : les gardes pompent une vraie fenêtre
(`tester.view.physicalSize = 1200×1000`) — sans quoi la bascule liste/grille ne serait pas celle
qu'on croit.

---

## 4. Question toujours ouverte

`ZAdaptiveGrid` en variante sliver (posée en `v0.24.0`, § 6) : **la grille de dossiers fait-elle
partie de vos 11 écrans à `SliverAppBar` ?** Nous ne livrons pas la variante spontanément — une API
publique est un engagement permanent.
