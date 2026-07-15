# Code Review — ES-5.2 : `ZStudyToolsPage` — scoping réactif isolé, non-régression SM-1

- **Story** : `es-5-2-zstudytoolspage-scoping-isole-sm1.md`
- **Reviewer** : bmad-code-review (revue adversariale, effort **high**, workstream B isolé)
- **Date** : 2026-07-15
- **Statut story à la revue** : `review`
- **VERDICT** : ✅ **APPROVED** — aucun finding HIGH/MAJEUR/MEDIUM. 3 LOW/nits non bloquants (consignés, aucun report requis avant `done`). SM-1 (AC2, objectif produit n°1) prouvé **load-bearing** par injection rejouée. DW-ES51-1 soldé et vérifié sur disque.

---

## 1. Vérif verte CIBLÉE rejouée RÉELLEMENT (RC hors pipe, isolation workstream B)

| Gate | Commande | Résultat | RC |
|------|----------|----------|----|
| Tests | `flutter test` (RUNNER Flutter, R14) | **All tests passed! — 19 tests** (6 golden + 13 rebuild/AC) | **0** |
| Analyse | `dart analyze` (zcrud_study) | `No issues found!` | **0** |
| Graphe | `python3 scripts/dev/graph_proof.py` | `ACYCLIQUE OK` · `out-degree(zcrud_core) = 0` · `CORE OUT=0 OK` · 19 nœuds/37 arêtes | **0** |
| Packages | `dart run melos list` | **19 packages** | **0** |

**Arêtes `zcrud_study`** (inchangées, aucun satellite lourd tiré) : `→ zcrud_core`, `→ zcrud_study_kernel`, `→ zcrud_annotations`. Aucune arête `zcrud_core -> *` (CORE OUT=0 confirmé grep explicite).

**Scans interdits** (`grep` sur `lib/`) : seules occurrences = **commentaires documentaires** + la constante de repli `_kAddActionFallbackIcon = Icons.add` (conditionnelle, documentée — cf. LOW-1). Aucun `setState(`, `ConsumerWidget`, `WidgetRef`, `Get.`, `Provider.of`, `flutter_riverpod`/`get`/`provider`, `EdgeInsets.only(`, `centerLeft/Right`, `Positioned(`, `TextAlign.left/right`, `ListView(children:` en code exécuté.

---

## 2. Axe n°1 — SM-1 load-bearing (R12) : injection R3-I1 REJOUÉE

**Méthode** : injection anti-rebuild-global par **édition ciblée** (R13, aucun `git checkout/restore/stash`), puis restauration exacte + re-vert prouvé.

- **Injection** (`z_study_tools_page.dart`, body de `build`) :
  ```dart
  : ListenableBuilder(
      listenable: _controller.fieldListenable('a'),
      builder: (_, __) => ZSectionedStudyLayout(sections: sections),
    );
  ```
  Variante **qui MORD** (la variante littérale `ListenableBuilder(listenable: formController)` est INERTE — `ZFormController.setValue` ne déclenche jamais `notifyListeners()` global, vérifié dans `z_form_controller.dart:19,127`, canal global réservé à `setVisibleFields`). Écouter `fieldListenable('a')` reproduit fidèlement un rebuild GLOBAL par frappe.

- **Résultat capturé** : `flutter test --plain-name "AC2 SM-1"` → **RC=1 RED**
  ```
  Expected: <1>
    Actual: <101>
  ```
  → le compteur du **champ voisin** `buildsB` (autre section, jamais reconstruit) passe **1 → 101**. L'assertion `expect(buildsB, 1)` ROUGIT. **Le test n'est PAS powerless** : `buildsB==1` est une assertion load-bearing sur compteurs de build RÉELS.

- **Restauration** : édition ciblée → `: ZSectionedStudyLayout(sections: sections);` (ligne 132). Re-vérif : **19/19 vert**, `dart analyze` RC=0. Scan résidu `ListenableBuilder` dans `lib/` → **aucune occurrence en code** (uniquement docstrings/commentaires). Working-tree du fichier prod propre.

**Conclusion** : la surface `ZStudyToolsPage` n'a **aucune** surface de rebuild global ; le scoping par champ via `ZFieldListenableBuilder` est bien la seule frontière réactive. **AC2 satisfait et prouvé discriminant.**

**AC3 (focus/sélection)** vérifié par lecture + green : `TextEditingController`/`FocusNode` **stables** (créés hors `build`, dans le test), saisie **sens unique** `onChanged → setValue` (jamais `.text=`), `expect(teA.selection.baseOffset, 100)` et `fnA.hasFocus == true` à chaque frappe. R3-I2 (controller recréé au build) documenté RED au Debug Log de la story (`baseOffset` → -1).

---

## 3. DW-ES51-1 soldé (AC4/AC7) — vérifié sur disque

| Finding ES-5.1 | Correctif attendu | Vérifié dans le code |
|---|---|---|
| **MEDIUM-1** icône hardcodée | icône INJECTÉE `spec.addActionIcon` | `z_sectioned_study_layout.dart:163-166` `Icon(spec.addActionIcon ?? _kAddActionFallbackIcon, …)` ✅ |
| **MEDIUM-1** sémantique ambiguë (`label: spec.title`) | label INJECTÉ prime sur `spec.title` | `:165` `semanticLabel: spec.addActionSemanticLabel ?? spec.title` ✅ ; test `find.bySemanticsLabel(kInjectedAddLabel) == 1` |
| **LOW-1** badge `circular(10)`/`8`/`2` en dur | tokens thème | `_CountBadge` `:192-198` `theme.gapM`/`theme.gapS` + `BorderRadius.all(theme.radiusM)` ✅ |
| **LOW-2** `Semantics` redondants | une seule source de sémantique | `Semantics(label:'$count')` supprimé du badge ; plus de `Semantics(button:true)` enveloppant l'`IconButton` ✅ |
| **LOW-3** commentaire `fusedSections` | corriger « fusion » → « retrait » | `study_tools_page_golden_test.dart:83-85` « RETRAIT-FUSION … section notes RETIRÉE » ✅ |

`addAction == null` ⇒ aucun bouton (AD-4) : test `find.byType(IconButton) == findsNothing` ✅. R3-I3 (icône/label hardcodés) documenté RED (icône injectée absente, label absent). ✅

---

## 4. Couverture des 8 ACs (pouvoir discriminant)

| AC | Verdict | Preuve |
|----|---------|--------|
| AC1 composition unique | ✅ | `find.byType(ZSectionedStudyLayout)==1` + 3 frontières `section:*` ; barrel exporte `ZStudyToolsPage` |
| **AC2 SM-1 (CENTRAL)** | ✅ **load-bearing prouvé** | `buildsA=101`, `buildsB=1`, `buildsPage=1` ; injection R3-I1 → `buildsB=101` RED rejoué |
| AC3 focus/sélection | ✅ | `baseOffset==100`, `hasFocus` continu ; controller stable, sens unique |
| AC4 addAction + icône/label injectés | ✅ | tap→1 ; `byIcon(injecté)==1` & `byIcon(Icons.add)==0` ; label injecté trouvé ; null→aucun bouton |
| AC5 état vide global | ✅ | 3 branches (toutes vides→global ; une peuplée→layout ; global null→layout) |
| AC6 axis rail/grille | ✅ | horizontal→1 `SingleChildScrollView(Axis.horizontal)` ; vertical→aucun |
| AC7 AD-2/13/15 + tokens | ✅ | scans propres ; directionnel ; ≥48 dp (`ConstrainedBox` 48 + `_kMinTapTarget`) ; tokens badge |
| AC8 acyclicité/vert | ✅ | graphe inchangé, CORE OUT=0, 19/19 vert, analyze RC=0 |

Cycle de vie du controller (test dédié) : controller **injecté non disposé** au démontage ; `didUpdateWidget` gère les 4 combinaisons possédé↔injecté sans recréation au rebuild ordinaire. ✅

---

## 5. Findings

### HIGH / MAJEUR : **aucun**
### MEDIUM : **aucun**

### LOW / nits (non bloquants — corrigés si triviaux au commit d'epic, sinon consignés)

- **LOW-1 (FR-26, tension puriste, SANCTIONNÉ par la story)** — `z_sectioned_study_layout.dart:27` `const IconData _kAddActionFallbackIcon = Icons.add`. Un `IconData` reste codé en dur DANS le package comme **repli conditionnel** (appliqué uniquement si l'appelant n'injecte pas `addActionIcon`). Lecture stricte de FR-26 = « aucun `IconData` codé en dur ». **Justification acceptée** : (a) la story T2 sanctionne explicitement un « repli documenté, jamais hardcode inconditionnel » ; (b) le glyphe « + » est un signe d'action d'ajout universel non locale/marque-dépendant ; (c) dès qu'une icône est injectée elle prime (test `byIcon(Icons.add)==0`). MEDIUM-1 (hardcode **inconditionnel**) est bien soldé. Piste future non bloquante : rendre `addActionIcon` requis, ou fournir le défaut via `ZcrudTheme`.

- **LOW-2 (perf, cohérent ES-5.1)** — les items d'une section sont rendus **eagerly** : rail horizontal via `SingleChildScrollView`+`Row(for …)` (`:102-114`), grille via `Column(for …)` (`:116-125`). Les **sections** utilisent bien `ListView.builder` (frontière lazy), mais les items intra-section ne sont pas paresseux. Sans impact SM-1 (bornes petites, structure conforme au design ES-5.1 approuvé). À réévaluer si une section porte de grands volumes → `ListView.builder(scrollDirection:)`.

- **LOW-3 (durcissement de test, optionnel)** — `AC4 : le label sémantique INJECTÉ prime` (`z_study_tools_rebuild_test.dart:269`) affirme la présence du label injecté mais pas explicitement le **négatif** (le bouton n'annonce pas `spec.title`). Le pouvoir discriminant est néanmoins préservé : sous R3-I3 (label = `spec.title`), `find.bySemanticsLabel(kInjectedAddLabel)` devient `findsNothing` → RED. Durcissement facultatif : ajouter un `find` négatif ciblant la sémantique du bouton.

---

## 6. Isolation workstream B respectée

- Modifs confinées à `packages/zcrud_study/**` (aucun `zcrud_core`, `zcrud_flashcard`, `scripts/ci`, `sprint-status.yaml` touché).
- Aucune commande repo-wide (`melos verify/analyze`, `melos bootstrap`) lancée. Aucun `git checkout/restore/stash`. Vérifs ciblées uniquement.
- L'injection R3-I1 a été restaurée par édition ciblée ; le re-vert 19/19 prouve l'absence de résidu.

**Recommandation orchestrateur** : story prête pour transition `review → done` (aucun MEDIUM+ à corriger). Les 3 LOW peuvent être laissés en l'état (justifiés) ou traités au commit d'epic ES-5.
