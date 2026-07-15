# Code-review ES-8.1 — UI de tags + intégrité référentielle (`ZTagEditor` / `ZTagChips`)

Skill : **`bmad-code-review` réellement invoqué** (tool Skill, préfixe `bmad-*`) — pas de fallback disque.
Revue ADVERSARIALE. Périmètre écrit : `packages/zcrud_study/` uniquement. Aucune bascule pubspec / `dart pub get`.
`zcrud_document` et le kernel NON touchés (revue parallèle en cours).

## Verdict : APPROVE (green) — 0 HIGH / 0 MAJEUR ; 1 MEDIUM (test-coverage) ; 1 LOW.

Story structurellement conforme (AD-1/2/4/13/14/19, FR-26, SM-1). Les widgets sont des adaptateurs minces
qui composent les primitives kernel/core déjà livrées, sans réimplémentation ni nouvelle arête. Les tests
load-bearing ont un **pouvoir discriminant réel** (vérifié par injections R3 provoquées, ci-dessous), à une
exception près (AC3 aveugle à l'over-purge — MEDIUM).

## Preuves R3 rejouées réellement (RC hors pipe)

Baseline : `flutter test` (R14) sur les 2 fichiers ES-8.1 → **RC=0, 19 tests** (« All tests passed! »).
`python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK, CORE OUT=0 OK, arêtes=42 (0 delta), nœuds=20**.
`melos list` → **20**. `dart analyze` (scope zcrud_study) → **SUCCESS RC=0**.

Injections R3 rejouées par l'orchestrateur-reviewer (mutation d'UNE ligne de prod → RED → restauration
byte-identique vérifiée : `git diff --stat lib/` ne montre plus que les 2 exports barrel = la vraie modif de
la story) :

| Ref | AC | Ligne de prod neutralisée (réellement) | Résultat observé |
|-----|----|----------------------------------------|------------------|
| R3-I3 | AC3 | `z_tag_editor.dart` purge `if (!orphans.contains(id)) id` → `id` (émission inchangée) | **RED** (AC3 fail) |
| R3-I1 | AC1 | `z_tag_chips.dart` `remapColorKey(palette: palette…)` → `defaultStudy()` en dur | **RED** (les 2 tests AC1 fail) |
| R3-I6 | AC5/SM-1 | `z_tag_editor.dart` `TextField` + `onChanged: (_) => setState(() {})` (état lifté) | **RED** (SM-1 fail) |

Suite re-verte après restauration (RC=0, 19). Les 8 autres injections (I2/I4/I5/I7/I8/I9/I10/I11) sont
attestées par le Dev Agent Record et cohérentes avec les assertions lues (ancrage sur les lignes propres au
widget : garde de création, dérivation compteur, identité controller détenu, titre textuel, cible 48 dp, label
injecté, absence de matérialisation à l'affichage, garde de dédup en confirmation). Non re-rejouées faute de
valeur marginale — les 3 rejouées couvrent les axes structurels les plus à risque (purge, fil palette, SM-1).

## Conformité AD / R20-R24

- **AD-1** : 0 nouvelle arête. `pubspec.yaml` INCHANGÉ ; seul diff `lib/` = les 2 exports barrel. graph_proof
  delta nul (42/20). CORE OUT=0. ✓
- **AD-2/AD-15/SM-1** : aucun import `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.`/`Provider.of`.
  Controller possédé créé en `initState` (jamais `build`), disposé au `dispose` ssi possédé ; injecté jamais
  disposé ; zone de suggestions dans un `ValueNotifier` LOCAL + `ValueListenableBuilder` scopé. Transition
  owned↔injected défensive dans `didUpdateWidget` (vérifiée logiquement : injecté→injecté ne dispose pas A ;
  injecté→null recrée owned ; null→injecté dispose owned). ✓
- **AD-4** : `tag.id`/`title` opaques ; callbacks `null` = capacité absente (pas de no-op). ✓
- **AD-13/FR-26** : titre textuel TOUJOURS rendu (couleur jamais seul canal), cibles ≥ 48 dp
  (`ConstrainedBox` minWidth/minHeight), `Semantics`/`tooltip` + `semanticLabel` INJECTÉS, chrome directionnel
  (`EdgeInsetsDirectional`, `TextAlign.start`), couleurs via `zResolveColorKeyOrSlot`/`ZcrudTheme.of` (repli
  `Theme.of` en dernier ressort ligne 442). Verrou-source (pas de `Colors.`/hex/`EdgeInsets.only(left`) présent
  dans les 2 suites. ✓
- **AD-14** : `onCreateTag`/`onSuggestionConfirmed` émettent un `ZFlashcardTag` d'`id == null` (test l.86,329). ✓
- **AD-19 / DW-ES81-1** : aucun champ `usageCount` stocké ; compteur DÉRIVÉ au rendu via
  `referencingCardsCountOf`. ✓
- **DW-ES81-2 (frontière R24)** : le widget ne prétend PAS purger le store — il émet seulement un modèle de
  références sans orphelin via `onReferencesPurged` (callback de présentation) ; la persistance reste déléguée
  au repository ES-3. Documentation honnête, pas de sur-promesse. ✓
- **R20/R24** : les AC ancrent bien sur les lignes propres aux widgets (fil palette→chip, garde de création,
  composition purge-sur-émission, dérivation, identité du controller détenu), pas sur la correction des
  primitives kernel. Pas de re-test de `normalizeTagTitle`/`orphanTagIds`/`remapColorKey` en boîte noire. ✓

## Findings

### MEDIUM — F1 (test-coverage / discriminant incomplet) : AC3 est aveugle à l'over-purge (perte de références légitimes)
`test/z_tag_editor_test.dart:126-137`. L'assertion AC3 vérifie uniquement (a) `orphanTagIds(refsÉmises,
existantsAprès) == {}` et (b) `t` absent de chaque liste émise. **Les deux sont satisfaits par une émission de
listes VIDES.** Une régression où `_deleteTag` (`z_tag_editor.dart:298-326`) purgerait TROP — retirant aussi
les références LÉGITIMES `a`/`b` (p.ex. un `orphans` mal calculé englobant tout, ou un `purged` réduit à
`<String>[]`) — resterait **VERTE** : c'est exactement une perte de données silencieuse (association carte↔tag
valide effacée), classe de bug orthogonale à l'orphelin que l'AC prétend cerner « STRUCTURELLEMENT ».
Scénario concret : si le corps de purge devenait `for (final l in cards) <String>[]`, orphans=∅ et aucun `t`
n'apparaît → test PASS à tort, alors que toutes les cartes ont perdu leurs tags.
**Correctif recommandé (in-scope)** : ajouter une assertion de PRÉSERVATION des non-orphelins — p.ex.
`expect(purged, <List<String>>[['a'], ['b'], ['a']])` (retrait de `t` uniquement) ou vérifier que chaque
référence non-orpheline d'origine survit. Cela ferme le flanc « valide sur existence, pas sur préservation ».

### LOW — F2 : `_removeSuggestion` retire toutes les suggestions VALEUR-ÉGALES ensemble
`z_tag_editor.dart:347-352`. `if (!identical(s, suggestion) && s != suggestion)` : `ZSuggestedTag` ayant une
égalité de valeur, deux suggestions de même `{title, colorKey}` sont retirées ensemble à la première
confirmation/rejet. Cas-limite (le port IA propose rarement des doublons stricts) ; sans test de couverture.
Si l'unicité par instance est voulue, garder `!identical(s, suggestion)` seul ; sinon documenter que les
suggestions value-égales sont fusionnées. Non bloquant.

## Vérif verte finale (rejouée)
- `flutter test test/z_tag_chips_test.dart test/z_tag_editor_test.dart` → **RC=0, 19/19** (« All tests passed! »).
- `dart analyze` (scope `zcrud_study`) → **SUCCESS, RC=0**.
- `graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK / 42 arêtes (0 delta) / 20 nœuds**.
- `melos list` → **20**.
- SRC restauré : seul diff `lib/` = `zcrud_study.dart` (+2 exports barrel), aucune injection résiduelle.

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| F1 (AC3 aveugle à l'over-purge) | 🟠 MEDIUM | ✅ **CORRIGÉ** | `test/z_tag_editor_test.dart` (AC3) : ajout d'une assertion de **préservation EXACTE** — après purge de l'orphelin `t`, `[['t','a'],['b','t'],['a']]` doit devenir **exactement** `[['a'],['b'],['a']]`. **Prouvé par l'orchestrateur** : injection de sur-purge (`for (final l in cards) <String>[]`) fait ROUGIR l'assertion de préservation (`Expected: [['a'],['b'],['a']], Actual: [[],[],[]]`, RC=1) — là où l'ancien test (orphans vide + pas de `t`) restait faussement vert ; restauré → RC=0. La classe « perte silencieuse d'associations carte↔tag » (orthogonale à l'orphelin) est désormais gardée. |
| F2 (suggestions value-égales) | 🟡 LOW | 🟡 **CONSIGNÉ** | `_removeSuggestion` retire toutes les suggestions value-égales ensemble (`s != suggestion`). Cas-limite : deux `ZSuggestedTag` de contenu identique. **Choix de design cohérent** (unicité par valeur, pas par instance) ; `ZSuggestedTag` est un value-object sans `id`. Consigné ; à revisiter si l'unicité par instance devient requise. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **84 tests** · `dart analyze` (scope zcrud_study) → SUCCESS · graph_proof RC=0 (42 arêtes, 0 delta) · melos list=20. Prod restauré (édition inverse byte-précise).

**Verdict final** : ✅ **PRÊT POUR `done`** — MEDIUM F1 corrigé et prouvé non-powerless ; LOW F2 consigné.
