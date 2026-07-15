# Code Review — ES-5.3 : Sections réordonnables + hub d'ajout + menu d'actions

**Story** : `es-5-3-sections-reordonnables-hub-menu.md` · **Statut** : review · **Package** : `zcrud_study` (workstream B, isolation)
**Revue** : bmad-code-review adversariale (effort high) · **Date** : 2026-07-15

## Verdict : APPROUVÉ SOUS RÉSERVE (1 MEDIUM à corriger ou justifier)

Les deux AC centraux sont prouvés **load-bearing** par injection rejouée (I1 → RED, I2 → RED). Acyclicité, isolation, AD-4/AD-13/AD-15 vérifiés. **Un trou de couverture MEDIUM confirmé** : le mécanisme d'ordre optimiste LOCAL (`_ids` ValueNotifier — la raison d'être du `_ReorderableItemList` StatefulWidget et le mécanisme de retour visuel SM-1) n'est asserté par AUCUN test ; sa neutralisation laisse les 37 tests VERTS.

---

## Preuves REJOUÉES (injection ciblée → RED → restauration → GREEN)

| # | Injection (prod, édition ciblée) | Résultat mesuré | Restauré |
|---|---|---|---|
| **I1** (AC1 ordre persisté — CENTRAL) | `_handleReorder` : `widget.spec.onReorder!(oldIndex,newIndex)` neutralisé | **RED** `Expected: ['b','a','c']` / `Actual: []` | ✅ GREEN |
| **I2** (AC2 SM-1 — CENTRAL) | `ZStudyToolsPage.build` enveloppe le corps dans un `ValueListenableBuilder(fieldListenable('a'))` reconstruisant un `ZSectionedStudyLayout` NEUF par frappe | **RED** `buildsFieldB Expected: <1>` / `Actual: <101>` | ✅ GREEN |
| **COVERAGE-PROBE** (ordre optimiste local) | `_handleReorder` : `_ids.value = zReorderIds(...)` neutralisé (callback INTACT) | **VERT — 37/37 tests passent** ⇒ trou de couverture | ✅ restauré |

Vérif verte finale rejouée réellement : `flutter test` **RC=0 (37)**, `dart analyze` **RC=0**, `graph_proof.py` **RC=0 — ACYCLIQUE, out-degree(core)=0**, arêtes `zcrud_study → {core, study_kernel, annotations}` inchangées (aucune `reorderable_grid_view`), `melos list = 20`, scans interdits vides (seule occurrence = commentaire docstring `ListView(children:)`).

---

## Findings

### MEDIUM-1 — Trou de couverture : l'ordre optimiste LOCAL (`_ids`) n'est pas asserté positivement
**Fichier** : `test/z_study_tools_reorder_test.dart` (couverture) · `lib/src/presentation/z_sectioned_study_layout.dart:248`
**Catégorie** : test-coverage · **Verdict** : CONFIRMED (rejoué)

Le seul test qui déclenche un réordonnancement RÉEL avec assertion visuelle (AC1 test 1, l.62-90) utilise `rebuildOnReorder: true` : le harnais appelle `setState(() => order = next)`, donc le changement visuel est **entièrement porté par le re-render de l'appelant via `applyTo`** — il masque complètement le chemin optimiste local. Le chemin documenté `rebuildOnReorder: false` (persistance silencieuse où, selon les commentaires prod l.216-217 et le harnais l.306-308, « le retour visuel vient de l'état LOCAL de la section — SM-1 ») n'est JAMAIS exercé pour son effet visuel.

**Scénario d'échec** : neutraliser la ligne 248 (`_ids.value = zReorderIds(_ids.value, oldIndex, newIndex)`) — c.-à-d. supprimer tout l'intérêt du `_ReorderableItemList`/`ValueNotifier` — laisse **les 37 tests VERTS** (rejoué ci-dessus). En production, une app qui persiste silencieusement (le patron optimiste que le code revendique) n'afficherait AUCUN retour visuel de drag, et aucun test ne l'attraperait. AC2 (l.219-229) n'assert que la NON-reconstruction de B/page après réordonnancement, jamais la reconstruction POSITIVE de la tranche de A.

**Remédiation (dans le périmètre)** : ajouter un test qui, avec `_OrderHarness(rebuildOnReorder: false)`, déclenche `rlv.onReorderItem!(1,0)` puis assert que l'ordre VISUEL local a changé (`_contentDy('b') < _contentDy('a')`) — ce test rougit si la ligne 248 est neutralisée, verrouillant le mécanisme optimiste.

### LOW-1 — `_listEquals` réimplémente `listEquals` du SDK
**Fichier** : `lib/src/presentation/z_sectioned_study_layout.dart:341-348`
**Catégorie** : simplification · Le helper positionnel duplique `package:flutter/foundation.dart` `listEquals`. Remplacement trivial (import déjà transitif). Non bloquant.

### LOW-2 — Métadonnée story périmée (`melos list = 19`)
La story annonce 19 packages ; le workspace en compte désormais **20** (`+zcrud_document`/`zcrud_note`). Déjà noté au Debug Log par le dev. Cosmétique.

---

## Axes vérifiés (conformes)

- **AD-1 / arête lourde** : `ReorderableListView.builder` du **SDK Flutter** (`package:flutter/material`), aucun `reorderable_grid_view`. `graph_proof.py` inchangé, ACYCLIQUE, CORE OUT=0. ✅
- **AD-4 (`null` = capacité absente)** : `onReorder == null` ⇒ rendu ES-5.2 strictement inchangé (test « onReorder null ⇒ AUCUN ReorderableListView » VERT) ; `ZContentHubEntry.enabled:false`/`onTap:null` ⇒ `isActionable==false`, `ListTile.onTap:null` (tests AC3 discriminants) ; `ZItemAction.onSelected:null` ⇒ filtrée via `where(onSelected != null)`, ABSENTE (`findsNothing` AC4). Prouvés par I3/I4 au dev-log ; contrôlés ici par lecture + suite verte. ✅
- **AD-13/FR-26** : poignée `Semantics(label: reorderHandleSemanticLabel ?? title)` INJECTÉ, cible `ConstrainedBox(min 48)` (test AC6 : 3 Semantics + `getSize ≥ 48`) ; directionnel (`EdgeInsetsDirectional`/`TextAlign.start`) ; aucune couleur/label/icône hardcodé hors replis d'icônes neutres documentés (`Icons.add`/`drag_handle`/`more_vert`). ✅
- **AD-2/AD-15** : aucun `ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`/`setState` en code (scan vide) ; ordre optimiste sous la frontière keyée `ValueKey('section:$id')` via `ValueNotifier`/`ValueListenableBuilder`, pas `setState`. ✅
- **ZFolderContentsOrder réutilisé EN LECTURE + `copyWith`** ; kernel NON modifié ; `zReorderIds` = helper PUR distinct d'`applyOrder` (removeAt/insert, clamp AD-10, ne mute pas la source — tests unitaires VERTS). ✅
- **Golden** : inchangé (fixture canonique non réordonnable ⇒ pas de poignée). Cohérent avec AC5 « SI l'apparence change ». Pouvoir discriminant du réordonnancement porté par le byte-diff `_captureReorderable` (hauteurs distinctes par id ⇒ permutation change les octets, écueil Ahem/powerless évité). Discriminance ES-5.1 (m1/m2/m3, N→N-1) intacte. ✅
- **Couverture des 7 ACs** : AC1 (I1 RED), AC2 (I2 RED), AC3/AC4 (discriminants, I3/I4 dev-log), AC5 (byte-diff), AC6 (a11y), AC7 (gates verts). Discriminants SAUF le chemin optimiste local (MEDIUM-1). ✅ (sous réserve MEDIUM-1)

---

## Recommandation
Corriger **MEDIUM-1** (ajout du test optimiste local `rebuildOnReorder:false`) avant `done` — trivial, dans le périmètre, verrouille un mécanisme central load-bearing. LOW-1/LOW-2 optionnels.
