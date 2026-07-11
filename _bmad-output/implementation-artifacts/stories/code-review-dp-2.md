# Code Review — DP-2 : `displayCondition` étendu (parité DODLP, gap B3)

- **Story** : `_bmad-output/implementation-artifacts/stories/dp-2-displaycondition-etendu.md` (18 ACs)
- **Périmètre revu** : `zcrud_core` uniquement (domaine `z_condition.dart` / `z_condition_evaluator.dart` ; présentation `z_form_controller.dart` / `dynamic_edition.dart` ; tests `z_condition_evaluator_test.dart` (M), `dp2_condition_context_test.dart` (A)).
- **Mode** : skill réel `bmad-code-review` (workflow disque `.claude/skills/bmad-code-review/steps/*`). Revue adversariale manuelle ciblée (subagents non disponibles en contexte orchestré ; layers Blind Hunter / Edge Case Hunter / Acceptance Auditor exécutés en revue directe).
- **Date** : 2026-07-11

## Verdict : **APPROVED** (avec 1 MEDIUM à corriger-ou-justifier + nits LOW)

Aucun finding HIGH/MAJEUR. Les 18 ACs sont satisfaits, la rétro-compat stricte tient, la pureté domaine et le graphe AD-1 sont intacts, et SM-1/AD-2 ne sont pas régressés sur les chemins testés. Un seul point substantiel (MEDIUM-1) : une classe de conditions (`source: persisted`) peut devenir **obsolète** après un `reseed()`/`markPristine()`, alors que les Dev Notes affirment le contraire — à corriger (petit câblage) ou à justifier/documenter explicitement comme reporté à E7.

---

## Vérifications rejouées réellement sur disque (RC réels)

| Vérification | Commande | RC | Résultat |
|---|---|---|---|
| Analyse statique | `dart analyze packages/zcrud_core` | **0** | `No issues found!` |
| Tests | `flutter test` (dans `packages/zcrud_core`) | **0** | `All tests passed!` — **+649** tests |
| Graphe de dépendances | `python3 scripts/dev/graph_proof.py` | **0** | `CORE OUT=0 OK` / `ACYCLIQUE OK` (14 nœuds, 19 arêtes) |
| Pureté domaine | `dart test test/purity/domain_entrypoint_dart_test.dart` | **0** | `All tests passed!` (domaine Flutter-free) |

---

## Findings

### HIGH — aucun

### MAJEUR — aucun

### MEDIUM

**MEDIUM-1 — Une condition `source: persisted` devient obsolète après `reseed()`/`markPristine()` (visibilité non recalculée).**
`dynamic_edition.dart` — `_bindGuards` (l.289-299), `didUpdateWidget` (l.226-253), `_recomputeVisibility` (l.307-321) ; `z_form_controller.dart` — `reseed` (l.207-215), `markPristine` (l.178-186).

- **Description** : le recalcul de visibilité n'est déclenché que par (a) les tranches des **champs de garde `state`** (`_bindGuards` → `_onGuardChanged`), (b) une bascule de **`conditionContext`** surveillée (`didUpdateWidget` + `_contextChanged`), ou (c) un changement structurel de `controller`/`fields`. Il **n'écoute PAS** `controller.reseedRevision` et les feuilles `persisted` ne sont **pas** dans `_guardFields` (exclues, correctement, pour SM-1). Or `reseed(values)` **mute `_baseline`** (l.210) — c'est précisément la valeur lue par `persistedValueOf` (`baselineValueOf`). Conséquence : après un `reseed()` (chargement async d'un enregistrement, documenté « Sert le chargement async d'un enregistrement (E7) ») ou un `markPristine()` (après soumission), la baseline change mais **aucune condition `persisted` n'est ré-évaluée** → un champ resté masqué/visible sur l'ancien `item[...]` conserve un état obsolète. Cas concret : `ZCondition.notEquals('reajusting', true, source: persisted)` (Forme C, `demande_depotage_form.dart:197`) après un `reseed({'reajusting': false})` devrait révéler le panneau, mais ne le fait pas.
- **Contradiction documentaire** : AC11 et les Dev Notes (« les feuilles `persisted` n'ont pas de companion : la baseline est immuable dans une session ; un `reseed`/`reset` recalcule déjà structurellement ») affirment que `reseed`/`reset` recalculent la visibilité. C'est **exact pour `reset()`** (baseline inchangée + restauration des tranches `state` → notification des gardes `state`) mais **inexact pour `reseed()`/`markPristine()`** qui, eux, **modifient la baseline** sans déclencher de recalcul des conditions `persisted`. La prémisse « baseline immuable dans une session » est fausse dès qu'un `reseed` intervient — et `reseed` est justement le point d'entrée du chargement d'`item` (Forme C).
- **Portée / criticité** : réel sur le chemin d'intégration visé (E7 offline-first : `reseed` = source autoritaire), mais (1) aucun AC ne **teste** explicitement le recalcul `persisted` post-`reseed`, (2) le contrat principal (baseline capturée à la construction) fonctionne et est couvert, (3) E7 n'est pas encore câblé. D'où MEDIUM (et non MAJEUR).
- **Remédiation proposée** (petite, sans impact SM-1 — `reseedRevision` ne notifie que sur `reset`/`reseed`, jamais par frappe) :
  - Calculer un flag `_hasPersistedLeaf` (union récursive analogue à `zGuardFieldsOf`, filtrée `ZValueSource.persisted`) et, s'il est vrai, s'abonner à `controller.reseedRevision` avec un handler qui appelle `_recomputeVisibility()` (canal structurel unique `setVisibleFields`, no-op si inchangé). Retrait symétrique en `dispose`/`didUpdateWidget` (comme `_guardListenables`).
  - **À défaut de correction** : retirer/reformuler la phrase « un `reseed`/`reset` recalcule déjà structurellement » (Dev Notes + AC11) et documenter explicitement que les conditions `persisted` ne sont ré-évaluées **que** sur construction/changement de `controller`, le recalcul post-`reseed` étant **reporté à E7**.

### LOW / nits (optionnels)

**LOW-1 — Angle mort de `_contextChanged` sur mutation en place de `conditionContext`.** `dynamic_edition.dart:261` : `if (identical(before, after)) return false;`. Si l'hôte **mute la même instance** de map de contexte (au lieu d'en fournir une nouvelle), le changement n'est pas détecté et la visibilité `context` reste obsolète. C'est un anti-pattern côté hôte et le doc-comment précise « comparaison de contenu » (nouvelle instance attendue), mais un `assert`/note dans le doc-comment de `conditionContext` (« fournir une NOUVELLE map à chaque bascule ») lèverait l'ambiguïté. Non bloquant.

**LOW-2 — Allocation d'une closure par recalcul.** `dynamic_edition.dart:316` : `contextValueOf: (k) => ctx[k]` alloue une nouvelle closure à chaque `_recomputeVisibility`. Négligeable (le recalcul est **structurel**, jamais dans la voie de frappe sur un champ non-garde). Aucune action requise.

**LOW-3 — `ZCondition.toString()` n'expose ni `value` ni `length`.** `z_condition.dart:245` : `'ZCondition(${op.name}, field: $field, source: ${source.name})'`. Pour une feuille `equals`/`lengthGt`, le `value`/`length` seraient utiles au débogage. Non-régression (le format historique ne les portait pas). Cosmétique.

---

## Vérification adversariale des 7 axes demandés

1. **Exhaustivité du `switch ZConditionOp` (totalité, AD-10)** — ✅ `switch` **total** sur les 13 variantes, **sans `default`** (le compilateur garantit l'exhaustivité ; l'ajout futur d'une variante forcerait la mise à jour). Les 5 nouveaux ops de forme/longueur sont tous traités. Le cas « op inconnu » n'a pas de chemin runtime (enum `const`) et est neutralisé en amont par `unknownEnumValue` (AD-10) — cohérent avec la doc de l'évaluateur. Combinateurs mal formés (`operands`/`operand` `null`) → retour neutre, jamais de throw. **Conforme.**

2. **`zLengthOf` sur types hétérogènes** — ✅ `String`→`.length`, `Iterable`→`.length` (couvre `List`/`Set`), `Map`→`.length`, `null`→`0`, `num`/`bool`/autre→`0`. Total, ne lève jamais. Aligné `zIsTruthy` (collection vide = non-truthy = vide). Seuil `condition.length ?? 0` défensif (les constructeurs de longueur exigent un `int`, donc `null` impossible via l'API publique). **Conforme AC6.**

3. **SM-1 / AD-2 — garde par frappe** — ✅ `zGuardFieldsOf` ne retient QUE `source == state` (feuilles de forme `state` incluses) ; `persisted`/`context` exclues (testé). `_bindGuards` n'abonne `_onGuardChanged` qu'aux tranches de `_guardFields`. `persistedValueOf` = lecture seule pure de `_baseline` (aucune mutation, aucun `notifyListeners`). Le recalcul `context` passe par `didUpdateWidget` (bascule structurelle), **jamais** par frappe. Test `dp2_condition_context_test.dart` : 10 frappes sur un champ `persisted` homonyme ⇒ **0** build structurel. **Conforme AC10/AC14** (sous réserve MEDIUM-1 sur le chemin `reseed`, hors frappe).

4. **Rétro-compat stricte** — ✅ `evaluateZCondition(c, valueOf)` 2-args inchangé (paramètres `persistedValueOf`/`contextValueOf` nommés optionnels). `ZCondition` défaut `source: state` : `const ZCondition.equals('a', 1)` conserve l'égalité/évaluation historiques (testé). `DynamicEdition` défaut `conditionContext: const {}` → comportement identique (testé AC16). Gate d'amorçage passé de `_guardFields.isNotEmpty` à `_hasConditions` : **aucun** formulaire pré-DP-2 affecté (avant DP-2 toute condition était `state` ⇒ `_guardFields` non vide dès qu'une condition existait). **Conforme AC16.**

5. **Pureté domaine (AD-3/AD-14)** — ✅ `z_condition.dart`/`z_condition_evaluator.dart` : aucun import Flutter, aucun `Function` embarqué, tout `const`. `ZValueSource` co-localisé, exporté par `domain.dart`. Garde pureté `dart test` verte (RC=0). `ConstantReader`/`_emitConst`-compatible (enum + `int? length` + `String`/primitifs). **Conforme AC17.**

6. **AD-1 graphe inchangé** — ✅ `graph_proof.py` : `out-degree(zcrud_core) = 0`, acyclique. Aucune dépendance ajoutée. **Conforme.**

7. **A11y non régressée** — ✅ Aucune modification des `Semantics`/cibles tactiles ; le câblage ne touche que la logique de visibilité (`setVisibleFields`), pas le rendu accessible. En-têtes repliables (`Semantics(button, expanded)`, ≥ 48 dp, `EdgeInsetsDirectional`) inchangés. **Conforme.**

## Traçabilité de parité (AC18)

Les 3 formes DODLP sont reproduites avec traçabilité fichier:ligne dans `z_condition_evaluator_test.dart` : Forme A (`cargaison_form.dart:57`, `alert_capri_form.dart:143`, `operateurs:224`), Forme B (`besc_detail:375-377`, `mes_dossiers:127,135`), Forme C (`demande_depotage:197,484`) + combinée A+C (`demande_depotage:544`). **Couvert.**

---

## Recommandation à l'orchestrateur

Story **verte et approuvable**. Avant `done` : traiter **MEDIUM-1** — soit (a) câbler l'abonnement `reseedRevision` conditionné à la présence d'une feuille `persisted` (correction recommandée, ~15 lignes, sans risque SM-1), soit (b) justifier par écrit le report à E7 **et** corriger la phrase inexacte des Dev Notes/AC11. Les LOW-1/2/3 sont optionnels.

---

## Résolution des findings (orchestrateur, post-review)

- **MEDIUM-1 — CORRIGÉ** (option (a) recommandée). Ajout d'un helper de domaine **pur**
  `zHasPersistedGuard(Iterable<ZCondition?>)` (companion « en bloc » de
  `zGuardFieldsOf`/`zContextGuardKeysOf`) dans `z_condition_evaluator.dart`, et câblage
  dans `dynamic_edition.dart` : quand au moins une feuille `persisted` existe,
  l'état s'abonne à `controller.reseedRevision` (`_bindReseed`/`_onReseed`) et
  recalcule la visibilité sur chaque révision. **`reset()` et `reseed()` incrémentent
  tous deux `reseedRevision`** → la visibilité `persisted` est désormais rafraîchie
  après un chargement async (E7). Canal **structurel** (par révision, jamais par
  frappe) ⇒ **SM-1 préservé**. La phrase inexacte du doc `zContextGuardKeysOf` a été
  corrigée. Test de non-régression ajouté : `dp2_condition_context_test.dart`
  → « DP-2 MEDIUM-1 — condition persisted recalculée sur reseed ».
- **Report justifié — `markPristine()`** : `markPristine()` **n'incrémente pas**
  `reseedRevision` (par conception, cf. `z_form_controller.dart:177` — il ne doit PAS
  re-amorcer les widgets bufferisés hors focus après un submit réussi ; effet de bord
  sur le rich-text E6/E9). Forcer un signal ici sortirait du périmètre DP-2 et
  toucherait des invariants d'autres epics. Le cas (baseline redéfinie sur l'état
  courant sans changement de valeurs d'affichage) est **marginal** : après un submit
  réussi les valeurs sont inchangées, la visibilité `persisted` ne bascule donc pas en
  pratique. **Reporté** (à revoir si un besoin réel émerge en E7) — la couverture
  `reset`/`reseed` traite le vrai scénario async.
- **LOW-1/2/3** : optionnels, consignés, non traités (nits cosmétiques/doc).

**Vérif verte re-jouée sur disque après correction** : `dart analyze packages/zcrud_core`
RC=0 (No issues) · `flutter test packages/zcrud_core` **650 tests** RC=0 · purity domaine
RC=0 · `graph_proof.py` CORE OUT=0 + ACYCLIQUE. **DP-2 → done.**
