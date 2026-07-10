# Code Review — E3-3b-3 : Signature + widget libre

- **Story** : `e3-3b-familles-avancees-sous-listes.md` (sous-story **E3-3b-3**, ACs `[→ -3]` : 10, 11 + a11y/0-default/SM-1/UJ-2/vérif transverses)
- **Périmètre revu (STRICT -3)** : famille `signature` (AC10) + famille `freeWidget` / `widget` libre (AC11) ; complément 0-default (AC14), catalogue a11y (AC13), SM-1/UJ-2 (AC15), vérif (AC16). **Hors périmètre** : registre + feuilles simples (-1, done), sous-listes/dynamicItem (-2, done).
- **Baseline** : `acc6a21` — changements non committés (fichiers neufs `families/z_{signature,free_widget}_field_widget.dart` + tests).
- **Chemin skill pris** : `Skill(bmad-code-review)` chargé, workflow step-01 → step-02 exécuté ; revue adversariale menée en direct par le reviewer (Blind Hunter + Edge-Case Hunter + Acceptance Auditor internalisés — sous-agents parallèles non disponibles dans ce contexte d'exécution, exécution mono-agent conforme au fallback disque `.claude/skills/bmad-code-review/`).
- **Verdict** : ✅ **APPROVED**

---

## 1. Résultats de vérification RÉELLEMENT rejoués sur disque

| Gate | Commande | Résultat |
|---|---|---|
| Analyze | `melos run analyze` | **RC=0** — 14/14 packages « No issues found » |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0 — 311 tests « All tests passed! »** (dont `z_signature_test`, `z_free_widget_test`, `z_field_dispatch_test`, `catalogue_a11y_test`) |
| Verify | `melos run verify` | **RC=0** — `out-degree(zcrud_core)=0`, **ACYCLIQUE OK**, **CORE OUT=0 OK**, gate:melos/reflectable/secrets/codegen/compat OK |
| Graphe | `graph_proof.py` | **CORE OUT=0**, acyclique, cœur agnostique |
| Packages | `melos list` | **14** |
| Codegen | `git ls-files '*.g.dart'` | **0** committé (gitignorés) |

Non-régression E3-1/E3-2/E3-3a/E3-3b-1/E3-3b-2 : verte (suite complète 311, +14 vs 297 après -2, cohérent avec l'ajout des tests -3).

## 2. Vérification adversariale des points de vigilance

### Signature (AC10)
- **Encodage stable & sérialisable** ✅ — `Map` VERSIONNÉE `{formatVersion:1, strokes:[[x,y,…]]}`, coordonnées **normalisées `[0,1]`**, listes de `double` **uniquement** (PAS de bytes image). `encode`/`decode` `@visibleForTesting`.
- **Round-trip idempotent** ✅ — test `jsonEncode(value)` → `jsonDecode` → `equals(value)` vert ; `decode(round)` re-parse non vide.
- **Lecture DÉFENSIVE (AD-10)** ✅ — `decode` : `value is! Map` → `[]` ; `strokes is! List` → `[]` ; élément non-`List` → `continue` ; coord non-`num` → ignorée ; **aucun `throw`**. Le parent ne casse jamais. Test défensif couvre `'x'`, `null`, `{'strokes':42}`, `'corrompu'`.
- **clear → null / undo cohérent** ✅ — `_clear` vide `_strokes` puis `_emit()` → `encode([])` = `null`. `_undo` garde `if (_strokes.isEmpty) return;` **et** bouton désactivé (`_strokes.isEmpty ? null`) → pas de throw sur pile vide.
- **a11y** ✅ — `Semantics(container, label:"<label>: Signature area", value: signé/vide, readOnly)` = alternative NON gestuelle ; boutons clear/undo = `IconButton` (cible ≥ 48 dp), tooltips l10n (`clearSignature`/`undoSignature`). `meetsGuideline(androidTapTargetGuideline)` vert.
- **RTL** ✅ — `EdgeInsetsDirectional.fromSTEB` partout, `Row(mainAxisAlignment:end)` directionnel ; couleurs dérivées du thème (`ZcrudTheme.of` + `colorScheme`, aucun littéral — FR-26).
- **Geste NON écrasé par un rebuild** ✅ — `_strokes` = `late final`, amorcé **une fois** en `initState` depuis `initialValue` ; `_emit` n'est appelé qu'à `onPanEnd`/`clear`/`undo` (jamais pendant le pan) → le `setValue` reconstruit le slice mais **préserve le `State`** (même type/place) ; aucune ré-injection mid-geste.
- **PAS de dépendance lourde (AD-1)** ✅ — `CustomPaint` + `GestureDetector` **natifs** ; point isolé rendu via `drawCircle` (évite `PointMode`/`drawPoints`) ; grep : **0** import `dart:ui` (seules 2 occurrences en commentaire), **0** package `signature` externe, **0** ligne dans `pubspec.yaml`. Garde de pureté `presentation/` (bannit `dart:ui`) reste **verte SANS relâchement**. `CORE OUT=0` inchangé.

### Widget libre (AC11)
- **CONSOMME `ZWidgetRegistry` (E3-3b-1)** ✅ — `ZcrudScope.maybeOf(context)?.widgetRegistry` + `tryBuilderFor(field.type.name)` ; ne réimplémente pas le registre.
- **Repli `ZUnsupportedFieldWidget` si non enregistré** ✅ — builder `null` → repli, **aucune** exception ; tests : registre présent (`kind:'widget'`) → hôte rendu & écrit la tranche ; absent → repli ; registre avec un AUTRE kind (`'markdown'`) → repli.
- **Value-in-slice / seam prouvé** ✅ — widget démo lit `value` (`host v0`) et écrit via `onChanged('written')` → tranche mise à jour, rebuild granulaire.
- **`kind` enregistré renvoyant `null`** — impossible au niveau du type (`ZFieldWidgetBuilder = Widget Function(...)`, `Widget` non-nullable) → aucun trou.

### 0 default (AC14)
- ✅ `familyOf` reste un `switch` **exhaustif SANS `default:`** ; `signature → EditionFamily.signature`, `widget → EditionFamily.freeWidget` **quittent** `unsupported`. Partition **39 re-vérifiée** par test runtime : **13** base + **1** hidden + **8** feuilles + **1** freeWidget + **12** registryOrFallback + **4** unsupported (`stepper`,`file`,`image`,`document`) = **39**, sans doublon, couverture totale de `EditionFieldType.values`.

### SM-1 / UJ-2 (AC15)
- ✅ `signature`/`freeWidget` rendus **sous l'unique `ZFieldListenableBuilder`** du dispatcher → pas de nouveau chemin de rebuild ; `onChanged → setValue` cible la seule tranche. Catalogue a11y : `find.byType(Form)` **findsNothing** ; aucune famille avancée n'introduit de `Form` global. Suite SM-1/UJ-2 E3-3a rejouée verte.

## 3. Triage des findings

| Sévérité | Nb |
|---|---|
| HIGH / MAJEUR | 0 |
| MEDIUM | 0 |
| LOW / nit | 3 |

**Aucun finding HIGH/MAJEUR/MEDIUM.** Ni lecture non-défensive, ni dépendance lourde, ni rebuild global détecté.

### LOW-1 — Signature « write-mostly » : pas de re-sync d'une valeur externe post-montage
`ZSignatureFieldWidget` lit `initialValue` **une seule fois** en `initState` ; le dispatcher lui repasse `initialValue: value` à chaque rebuild mais le `State` l'ignore. Conséquence : un `setValue('sig', map)` **postérieur au montage** (chargement asynchrone d'un enregistrement, reset de formulaire piloté depuis le parent) **ne s'affiche pas** sur le canvas — asymétrie vs `date`/`boolean`/`select` qui relisent `value` à chaque build.
- **Nature** : tradeoff **délibéré et documenté** (« amorcé une fois », AD-2 « geste non écrasé »), **cohérent** avec le patron value-in-slice à état local déjà utilisé par `subList`/`dynamicItem` (-2, approuvé). N'est donc pas une régression -3.
- **Reco** (optionnel, hors périmètre) : si un scénario de rechargement async est visé plus tard, exposer une re-amorce contrôlée par clé (`ValueKey(revision)`) plutôt qu'un write-back mid-geste. **Non bloquant.**

### LOW-2 — Duplication du seam registre entre `ZFreeWidgetFieldWidget` et `_dispatchRegistry`
La résolution `registry?.tryBuilderFor(field.type.name)` + repli est écrite **deux fois** : dans `ZFieldWidget._dispatchRegistry` (famille `registryOrFallback`) et dans `ZFreeWidgetFieldWidget.build` (famille `freeWidget`). DRY mineur — factorisation possible (helper commun), sans impact fonctionnel. **Nit.**

### LOW-3 — Couverture : décodage-au-montage & sync externe non exercés
Le test `valeur initiale` vérifie que le bouton clear est actif (donc l'état initial est lu) mais **pas** que les strokes initiaux **se peignent** réellement, ni le scénario `setValue` post-montage (cf. LOW-1). Trou de couverture mineur, sans risque de crash (chemin défensif couvert par ailleurs). **Nit.**

## 4. Trous de couverture identifiés

- Aucun test d'un `setValue` **après** le premier build de la signature (limitation LOW-1 non caractérisée par un test — acceptable car by-design).
- Aucun test que les strokes **initiaux** sont effectivement rendus (peints), seulement que l'état « signé » est détecté.
- `freeWidget` : builder hôte qui **throw** non testé (hors responsabilité du cœur — AD-7, laissé à l'hôte).
- RTL signature : vérifie l'absence d'overflow + la direction ambiante, pas le **côté** effectif des boutons (couvert par le token directionnel dans le code).

Ces trous sont **mineurs** et n'affectent pas les invariants AD-1/AD-2/AD-10/AD-13. **Non bloquants.**

## 5. Conclusion

Le périmètre -3 satisfait AC10 et AC11 : encodage signature **stable, versionné, normalisé, sérialisable et défensif** (AD-10), rendu **100 % natif sans dépendance lourde** (AD-1, CORE OUT=0), widget libre **consommant le registre** avec repli contrôlé (AD-4), exhaustivité **0-default préservée** (partition 39), SM-1/UJ-2 **intacts** (frontière de rebuild unique, aucun `Form` global), a11y/RTL conformes (AD-13). Vérif verte réelle rejouée (analyze RC=0 · **311** tests RC=0 · verify RC=0 · CORE OUT=0 · 14 pkgs · 0 `.g.dart`). **0 HIGH/MAJEUR/MEDIUM.**

**Verdict : ✅ APPROVED.** Les 3 LOW sont optionnels/consignés ; aucun ne bloque le passage à `done`.
