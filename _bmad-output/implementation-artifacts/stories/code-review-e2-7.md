# Code Review — Story E2-7 : Réactivité Flutter-native (`ZFormController`) + seams

- **Story** : `_bmad-output/implementation-artifacts/stories/e2-7-reactivite-flutter-native.md` (11 ACs, statut `review`)
- **Baseline** : `8f28755` (HEAD) — implémentation E2-7 non commitée (untracked par-dessus)
- **Reviewer** : agent BMAD `bmad-code-review` (skill réel invoqué ; step-file architecture suivie)
- **Chemin pris** : `Skill(bmad-code-review)` OK (step-01 gather-context → step-02 review → triage). Revue adversariale menée par l'orchestrateur selon les 3 lentilles du skill (Blind Hunter / Edge Case Hunter / Acceptance Auditor) — sous-agents non essaimés, revue conduite en direct avec rejouage réel sur disque.
- **Date** : 2026-07-09

## Verdict : ✅ APPROVED

Story exécutée proprement. **Objectif produit n°1 (SM-1) matériellement prouvé au niveau controller** : la granularité du rebuild est réelle et non contournable (voir §Vérif). Aucun anti-pattern AD-2, aucun manager d'état, aucun faux vert détecté. **0 HIGH, 0 MAJEUR, 0 MEDIUM.** 5 findings LOW/nits, tous optionnels (aucun ne bloque `done`).

## Décompte findings

| Sévérité | Nombre |
|---|---|
| HIGH / CRITIQUE | 0 |
| MAJEUR | 0 |
| MEDIUM | 0 |
| LOW / nit | 5 |

## Vérifications RÉELLEMENT rejouées sur disque

| Contrôle | Résultat |
|---|---|
| `graph_proof.py` | **17 arêtes**, `out-degree(zcrud_core)=0 (runtime)`, **CORE OUT=0 OK**, **ACYCLIQUE OK**, 14 nœuds. Le SDK Flutter n'ajoute **aucune** arête `zcrud_*`. ✓ |
| `gate:melos` (M-1) | **OK — blocs scripts identiques (13 scripts)**. Split `test:dart`/`test:flutter`/`test` répliqué à l'identique pubspec.yaml ↔ melos.yaml. ✓ |
| **SM-1** `sm1_granular_rebuild_test.dart` | **2 tests PASS**. Compteurs confirmés : après `setValue('a')`×25 → **buildsA=26, buildsB=1, buildsGlobal=1** (zéro rebuild croisé, zéro rebuild global). Variante `EditableText` : focus conservé, `selection.baseOffset==text.length` (curseur non réinitialisé), voisin jamais reconstruit. ✓ |
| `melos run analyze` | **RC=0**, 14 packages, `No issues found` partout. ✓ |
| `flutter test` (zcrud_core) | **96 tests PASS** (dont ~80 E2-1/E2-2 non-régressés + 16 E2-7). ✓ |
| `melos run test` (agrégat) | **SUCCESS** — `test:flutter` route `zcrud_core` → `flutter test` (96) ; `test:dart` no-op propre (13 pur-Dart sans `test/`). ✓ |
| `melos run verify` | **RC=0** — tous les gates verts (graph, melos, reflectable, secrets, codegen, compat, serialization). ✓ |
| `verify:serialization` (Flutter-aware) | **RC=0** — aiguillage runner correct (`_isFlutterPackage(zcrud_core)=true` → `flutter test --tags serialization-compat`). ✓ |
| `prove_gates.dart` | **22 OK / 0 FAIL**. ✓ |
| Greps pureté | domain/ flutter=**0** ; `dart:ui` direct=**0** ; material/cupertino/services en presentation=**0** ; imports managers=**0** ; tokens `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` (hors commentaires)=**0** ; presentation n'importe que `foundation`+`widgets`(+internes+dartz). ✓ |
| Anti-patterns AD-2 | `setState`=**0** ; `StatefulWidget` en presentation=**0** (helper `Stateless`) ; `.text=`=**2 uniquement dans des doc-comments** (documentent l'interdit, aucune ré-injection réelle). ✓ |
| Non-régression | `melos list`=**14** ; `git ls-files '*.g.dart'`=**0** ; barrel conserve tous les exports E2-1/E2-2 + `ZCoreApi` + dartz curaté +5 exports presentation (ordre alpha). ✓ |

## Analyse adversariale des points de vigilance (objectif n°1)

### Rebuild réellement granulaire (SM-1) — SOLIDE, non contournable
- `setValue(name, v)` écrit exclusivement `_slice(name).value = v` (ValueNotifier isolé). Le `ChangeNotifier` global n'est JAMAIS notifié sur un changement de valeur (`notifyListeners()` réservé à `setVisibleFields`). Prouvé : `globalNotified=0` après 25 `setValue` (`z_form_controller_test.dart`) ET `buildsGlobal=1` (SM-1).
- **Tranche `ValueListenable` isolée** : chaque champ = un `ValueNotifier` distinct ; `setValue('a')` ne touche pas la tranche `'b'` (`bNotified=0`, `buildsB=1`).
- **Création paresseuse mémoïsée jamais recréée** : `fieldListenable` délègue à `_slice` = `putIfAbsent` → identité stable garantie ; testé `identical(a1,a2)==true`. Aucune perte d'état possible au rebuild.
- **Verdict** : SM-1 n'est PAS contournable au niveau controller. Le harnais de preuve (2 champs + builder structurel + compteurs) est correct et non trivial pour la granularité croisée.

### Anti-patterns AD-2 — ABSENTS
- Aucun `setState` (global ou local) ; helper de slice est `StatelessWidget`.
- Aucune recréation de `TextEditingController` (le cœur n'en gère aucun — délégué à E3-2, correctement hors-périmètre).
- Aucune ré-injection `.text=` (les 2 occurrences sont des doc-comments prescriptifs). Saisie SM-1 à sens unique `onChanged→setValue`.
- `dispose()` itère et dispose toutes les tranches + `_visibleFields` + `super.dispose()` — pas de fuite (testé : accès post-dispose sur une tranche lève).

### Pureté par couche — CONFORME
domain/ strict pur-Dart (garde renforcée + étendue à data/) ; presentation/ borné à `foundation`+`widgets` ; transverse 0 token manager. Gardes de test réelles (pas seulement grep) : `domain_purity_test.dart` + `presentation_purity_test.dart`.

### Faux vert `verify_serialization` — ÉCARTÉ
Vérifié empiriquement : `flutter test --tags serialization-compat` sur un package sans test taggé retourne **RC=79** (« no tests ran »), tandis qu'un **échec réel de test retourne RC=1**. La tolérance `exitCode==79` ne masque donc PAS un vrai échec. L'aiguillage `_isFlutterPackage` (regex `flutter:` sous `dependencies:`) détecte correctement zcrud_core. No-op vert légitime jusqu'à E2-10.

### ZcrudScope / seams — CORRECTS
`of` lève `ZScopeError` actionnable (message : « Enveloppez… dans ZcrudScope(...) ou un binding »), `maybeOf` → null ; `updateShouldNotify` sur identité `resolver`/`acl` (défaut const → no-notify) ; défaut zéro-config = `ZAllowAllAcl` + resolver throwing. Aucune fuite de manager.

## Findings LOW (optionnels — aucun ne bloque `done`)

### L-1 — Réutilisation post-`dispose()` recrée des tranches orphelines (robustesse)
`packages/zcrud_core/lib/src/presentation/z_form_controller.dart:76` (`_slice` via `putIfAbsent`) et `:88` (`setValue`).
Après `dispose()`, `_slices` est vidé ; un appel ultérieur à `fieldListenable`/`setValue` recrée silencieusement un `ValueNotifier` jamais disposé (petite fuite), sans lever — alors que `setVisibleFields` lèverait (via `ChangeNotifier` disposé). Comportement asymétrique en cas de mauvais usage.
**Correctif suggéré (optionnel)** : garde `assert(!_disposed)` en tête de `_slice`/`setValue` pour un échec précoce cohérent en debug. Non requis pour E2-7.

### L-2 — Variante `EditableText` du test SM-1 : preuve « facile »
`packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart:72`.
Le harnais one-way (aucun `ValueListenableBuilder` ne réinjecte la valeur dans le `EditableText`) ne pourrait de toute façon pas réinitialiser le curseur — le test prouve le pattern mais ne garde pas contre une régression two-way. C'est le périmètre correct d'E2-7 (la vraie garde curseur two-way appartient à E3-2). Simple note ; pas d'action.

### L-3 — Tolérance exit 79 : angle mort futur possible
`scripts/ci/verify_serialization.dart:77`.
Sans risque aujourd'hui (79 = « aucun test » ≠ échec). Mais quand E2-10 ajoutera des tests taggés, un tag mal orthographié laisserait le slot vert (79) — gap de couverture silencieux. À garder à l'esprit lors de la livraison E2-10 (ex. sentinelle « au moins un test taggé attendu »). Hors périmètre E2-7.

### L-4 — `updateShouldNotify` basé sur l'identité
`packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:66`.
Un binding qui reconstruit `ZcrudScope` avec un `resolver`/`acl` **non-const** à chaque build déclencherait `updateShouldNotify==true` à chaque rebuild → réveil des dépendants. C'est le contrat d'identité documenté et la responsabilité du binding (E2-9), pas un défaut du cœur. Note pour E2-9.

### L-5 — Whitelist `presentation_purity_test` permissive sur `dart:`
`packages/zcrud_core/test/purity/presentation_purity_test.dart:121`.
`isDartSafe = uri.startsWith('dart:') && uri != 'dart:ui'` autorise tout `dart:*` (ex. `dart:io`) sous presentation/. Aucune violation présente ; les ACs ne l'interdisent pas. Durcissement optionnel (whitelist `dart:async`/`dart:collection`…) si l'on veut fermer la porte. Nit.

## Couverture des ACs (Acceptance Auditor)

AC1 (pureté par couche) ✓ · AC2 (préfixe Z + presentation) ✓ · AC3 (granularité par tranche) ✓ · AC4 (seams throw) ✓ · AC5 (ZcrudScope zéro-config) ✓ · AC6 (0 manager/0 token) ✓ · AC7 (helper slice) ✓ · AC8 (SM-1 proto) ✓ · AC9 (CI verte malgré Flutter, split M-1) ✓ · AC10 (barrel + non-régression, list=14, g.dart=0) ✓ · AC11 (vérif verte finale rejouée) ✓.

**11/11 ACs satisfaits, tous rejoués réellement sur disque.**
