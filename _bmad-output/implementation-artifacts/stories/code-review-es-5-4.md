# Code Review — ES-5.4 · `ZFeatureAvailability` injectable (workstream B)

Revue ADVERSARIALE (effort high). Skill `bmad-code-review` invoqué (step-01/02). Vérifs CIBLÉES `packages/zcrud_study` (isolation vs workstream A — aucun `melos verify/analyze` repo-wide, aucun `git checkout/restore/stash`, sprint-status/zcrud_session/scripts/ci non touchés).

## VERDICT : APPROVED (done autorisé)

5 ACs discriminants, tous couverts. Pouvoir discriminant CENTRAL REJOUÉ réellement sur disque (I1/I2 → RED capturé, restaurés par édition ciblée, retour au vert prouvé). Aucun finding HIGH/MAJEUR/MEDIUM. 2 LOW/nits consignés (non bloquants).

## Preuve REJOUÉE — gating + fail-open (Axe n°1, R12)

| Injection (édition ciblée PROD) | AC visé | Résultat REJOUÉ | RC |
|---|---|---|---|
| **I1** `gate(k, action) => action;` (ignore `isAvailable`) | AC1 gating CENTRAL | **RED** — unité : `Expected null / Actual <Closure: () => void>` ; menu : `EXAM-XYZ` PRÉSENT (`Found 1 widget`) au lieu de `findsNothing`. Une feature indisponible redevient actionnable/présente. | 1 |
| **I2** `ZAllFeaturesAvailable.isAvailable => false;` | AC2 défaut fail-OPEN CENTRAL | **RED** — `Expected true / Actual false` sur `ZAllFeaturesAvailable().isAvailable` ET sur `of(context)` sans ancêtre. Le défaut deviendrait fail-safe. | 1 |
| Restauration (édition ciblée inverse) + re-vert | AC5 | **GREEN** — `flutter test` **51** RC=0 ; `dart analyze` RC=0 | 0 |

I1/I2 confirment que AC1 et AC2 ROUGISSENT si l'implémentation dévie : les ACs centraux ne sont PAS powerless. I3 (scope ignore ancêtre) et I4 (`ZMapFeatureAvailability` ignore `flags`) sont couverts par les tests AC3 (`underA == underB` / `resA == resB` rougiraient) et déjà rejoués RED au Debug Log dev-story ; non re-rejoués ici (I1/I2 centraux suffisent + budget isolation), mais les assertions discriminantes correspondantes sont présentes et vertes (`expect(underA, isNot(underB))`, `expect(resA, isNot(resB))`).

### Fail-open JUSTIFIÉ (D1) + opt-in fail-safe présent
- Le défaut `ZAllFeaturesAvailable` (fail-open) est justifié (D1) : le package PARTAGÉ ne masque jamais une feature réellement câblée par une app faute d'injection — la restriction est un OPT-IN d'app, cohérent AD-4 (la « capacité absente » réelle reste portée par les callbacks `null` de l'app en ES-5.3). Préserve la baseline goldens ES-5.1/5.2/5.3 (SM-SC2) — golden INCHANGÉ.
- L'opt-in fail-safe LOCAL existe et est testé : `ZMapFeatureAvailability({'x': true}, availableWhenUnspecified: false).isAvailable('y') == false` (test AC2, vert).
- `maybeOf` renvoie `null` sans ancêtre (distingue « aucune injection » du repli fail-open de `of`) — testé et vert.

## Vérif verte CIBLÉE (RC hors pipe, R15/R14)

| Gate | Commande | RC | Résultat |
|---|---|---|---|
| Analyse | `dart analyze` (zcrud_study) | 0 | `No issues found!` |
| Tests | `flutter test` (RUNNER Flutter, R14) | 0 | `All tests passed!` — **51** tests (13 ES-5.4) ; non-régr. ES-5.1/5.2/5.3 |
| Acyclicité | `python3 scripts/dev/graph_proof.py` | 0 | `ACYCLIQUE OK` + `out-degree(zcrud_core)=0` + `CORE OUT=0 OK` ; 40 arêtes, 20 nœuds ; `zcrud_study → zcrud_core/zcrud_study_kernel/zcrud_annotations` INCHANGÉ |
| Packages | `dart run melos list` | — | **20** (INCHANGÉ) |
| Scans interdits | `grep` state-manager/material/mapEquals/INJECTION sur le fichier PROD | — | **VIDE** (seul import : `package:flutter/widgets.dart`) |

## Analyse par axe (effort high)

- **AD-4** — `featureKey` = `String` OPAQUE, AUCUN enum/sealed couplé aux satellites. `ZFeatureAvailability` = `abstract interface class` (extensible inter-package, D2). Impls de référence `extends` (non `implements`) → héritent `gate`/`enabledFor` sans duplication (anti-inertie D3). CONFORME.
- **AD-2/AD-15** — `ZFeatureAvailabilityScope` = `InheritedWidget` PUR (`updateShouldNotify` sur égalité de `availability`, crée bien la dépendance via `dependOnInheritedWidgetOfExactType`). AUCUN gestionnaire d'état / `setState` / état mutable. Impls `@immutable` const-compatibles (`identical(const …)` testé). CONFORME.
- **AD-1** — import MINIMAL `package:flutter/widgets.dart` seul (aucune arête material/tierce ; `_flagsEqual` inline car `mapEquals` non surfacé par `widgets.dart`). Graphe INCHANGÉ, CORE OUT=0, melos=20. CONFORME.
- **Composition D3** — AUCUN nouveau chemin de rendu : `gate`⇒`onTap:null`/`addAction:null`/`onSelected:null` (filtré par `ZItemActionsMenu.where(onSelected != null)`), `enabledFor`⇒`ZContentHubEntry.enabled` (vérifié dans `z_content_hub_sheet.dart:53,106` / `z_item_actions_menu.dart:101`). Golden INCHANGÉ, cohérent. CONFORME.
- **Couverture 5 ACs** — tous discriminants (AC1 I1, AC2 I2 rejoués RED ; AC3 I3/I4 ; AC4 const/égalité/updateShouldNotify). Aucun AC powerless. `_flagsEqual` + `hashCode` (`Object.hashAllUnordered`) cohérents pour l'égalité profonde SM-SC2 (testé instances distinctes ⇒ égales). CONFORME.

## Findings

### LOW-1 (nit) — branche morte dans `_flagsEqual`
`z_feature_availability.dart:129` : `if (other == null && !b.containsKey(entry.key)) return false;`. Les valeurs de `flags` étant `bool` NON nullable, `b[key] == null` équivaut déjà à « clé absente » ; la ligne suivante `if (other != entry.value) return false;` couvre déjà ce cas (`null != true/false`). La condition `!b.containsKey` est donc redondante (dead branch). Correct et sûr — simple bruit. Non bloquant (LOW). Non corrigé (édition cosmétique ; hors gain de correction).

### LOW-2 (nit) — `flags` est une `Map` mutable dans une classe `@immutable`
`z_feature_availability.dart:103` : `final Map<String, bool> flags;`. `@immutable` garantit le champ `final` mais pas la profondeur : une app construisant `ZMapFeatureAvailability(mutableMap)` en NON-const pourrait muter `flags` après coup, ce qui fausserait `==`/`hashCode`/`updateShouldNotify`. Idiome Flutter standard (const map = non-modifiable ; nombreux `InheritedWidget` du SDK portent des `List`/`Map` finaux) et le chemin documenté est `const`. Non bloquant (LOW) ; envelopper en `Map.unmodifiable` dans le ctor serait plus robuste mais casserait la const-compatibilité (AC4) — donc VOLONTAIREMENT non fait. Consigné.

## Statut
Aucun HIGH/MAJEUR/MEDIUM ⇒ correction obligatoire : néant. Les 2 LOW sont justifiés/consignés (non corrigés : cosmétique / conflit avec la const-compatibilité AC4). Story RESTE verte (51/RC=0). Prête pour `done`. Transition sprint-status + rétro ES-5 = ressort de l'orchestrateur (non touché ici).
