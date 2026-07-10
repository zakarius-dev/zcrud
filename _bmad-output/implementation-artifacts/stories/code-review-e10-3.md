# Code Review — E10-3 : Éditeur outline corrigé (`zcrud_mindmap`)

- **Mode** : VRAI skill `bmad-code-review` invoqué via le tool `Skill` (step-file architecture, step-01 gather-context). Pas de fallback disque.
- **Date** : 2026-07-10
- **Story** : `_bmad-output/implementation-artifacts/stories/e10-3-editeur-outline-corrige.md` (status `review`)
- **Baseline** : `04aaaf0` (frontmatter). E10-1/E10-2/E10-3 non commités → tous les fichiers mindmap sont untracked par rapport à la baseline.
- **Périmètre revu (E10-3 uniquement)** :
  - `lib/src/presentation/z_mindmap_outline_controller.dart`
  - `lib/src/presentation/z_mindmap_outline_editor.dart`
  - `lib/src/presentation/z_mindmap_outline_labels.dart`
  - `lib/zcrud_mindmap.dart` (barrel — exports E10-3)
  - `test/z_mindmap_outline_editor_test.dart`
  - (contexte lu, non revu : `z_mindmap_tree_ops.dart`, `z_mindmap_node.dart`, `z_mindmap_view_config.dart` — E10-1/E10-2, `done`)

## Vérif verte rejouée (depuis la racine du workspace)

- `dart analyze packages/zcrud_mindmap` → **RC=0, No issues found**.
- `flutter test packages/zcrud_mindmap` → **RC=0, +109 tests, All tests passed!** (89 E10-1/E10-2 + 20 `testWidgets` E10-3 + 2 tests de garde grep). Les tests de garde grep résolvent leur chemin au cwd (`resolve()` essaie `''` puis `packages/zcrud_mindmap/`) → **passent bien depuis la racine**.

## Invariant central AC2 — VÉRIFIÉ (le bug lex est corrigé par conception)

- La forêt du `ZMindmapOutlineController` (`_forest`) est la **source de vérité unique**. Toutes les mutations passent **exclusivement** par `ZMindmapTreeOps` (`updateNode`/`addChild`/`deleteNode`/`indentNode`/`outdentNode`/`reorderChild`) — aucun `copyWith`, aucune reconstruction manuelle, aucun recalcul de `level` côté éditeur.
- Édition « live » : chaque frappe (`onChanged → editLabel/editContent`) réassigne `_forest` en continu ; `onSave` émet `() => widget.onSave!(_controller.forest)` — le getter retourne l'état **courant muté**. **Aucun chemin** ne re-persiste un instantané d'origine. L'invariant tient.
- **Preuve testée réellement** : `z_mindmap_outline_editor_test.dart:134-157` monte l'éditeur, `enterText('Child1' → 'ChildEdited')`, tape « Enregistrer », puis **asserte `findNode(saved,'c1').label == 'ChildEdited'` ET `isNot('Child1')`** — c'est exactement le test qui aurait attrapé le bug lex. Idem `content` (169-179), add child/sibling, delete, indent, outdent, moveUp/moveDown, et **cohérence de `level`** (`_levelsCoherent` + `normalizeLevels(saved)` renvoie `identical`, 312-328). Confirmé : la preuve AC2 est authentique, pas cosmétique.
- Composition `addSibling` (addChild sous le nœud → `outdentNode`) tracée manuellement pour un nœud non-racine porteur d'enfants : insère bien le frère à `index+1`, `level` recalculé, enfants existants intacts. `addRoot` sur forêt vide crée `[newRootNode()]`. Corrects.
- AD-2/AD-15 : `ChangeNotifier` pur, zéro import gestionnaire d'état ; `TextEditingController` **stables** keyés par `id` (`putIfAbsent`, jamais réaffectés `.text` pendant la frappe) ; édition de texte = **0 `notifyListeners`** (testé 367-380) → rebuild ciblé, focus conservé (testé 331-365). Conforme SM-1.
- Isolation AD-1 : les 3 fichiers de présentation n'importent que `flutter` + `zcrud_core` + domaine local ; **aucune** modif de `zcrud_core` attribuable à E10-3 (les changements présents dans `zcrud_core` appartiennent au workstream parallèle E5-sync) ; **aucune** nouvelle arête pubspec (le diff pubspec est celui d'E10-2 ; la File List E10-3 n'inclut pas pubspec).

## Findings

### MEDIUM-1 — Cibles tactiles des champs éditables non garanties ≥ 48 dp (AC4/AD-13)
- **Fichier** : `z_mindmap_outline_editor.dart:265-286` (champ `label`) et `:296-318` (champ `content`).
- **Impact** : Les deux `TextField` utilisent `isDense: true` **sans** contrainte de hauteur minimale. AC4 exige explicitement « chaque **champ éditable** et chaque bouton d'action … cibles tactiles ≥ 48 dp ». `isDense` réduit délibérément la hauteur du champ (~40 dp), sous le plancher AD-13. Le champ label est pourtant l'affordance d'édition **principale**. Le test « cibles ≥ 48 dp » (`test:414-421`) ne vérifie que le bouton « Supprimer », jamais les champs → la régression n'est pas couverte.
- **Recommandation** : envelopper chaque champ dans un `ConstrainedBox(minHeight: config.minTapTarget)` (ou retirer `isDense` et régler `contentPadding`/`constraints` via `InputDecoration` pour garantir ≥ 48 dp), puis ajouter une assertion de hauteur du `TextField` dans le test AC4.

### MEDIUM-2 — Guard grep FR-26 incomplet : `Color(0x…)` non couvert (AC5)
- **Fichier** : `z_mindmap_outline_editor_test.dart:505-522`.
- **Impact** : AC5 interdit « **AUCUNE `Color(0x…)`, `Colors.*`** ». Le test de garde ne scanne que `Colors.` (+ API non-directionnelles). Un futur `Color(0xFF…)` codé en dur dans les 3 fichiers de présentation **passerait le garde-fou sans détection**. Le code de prod actuel est propre (aucune couleur littérale — toutes via `ZcrudTheme.of(context)` avec repli `Theme.of(context)`), donc **pas de défaut vivant**, mais le garde-fou ne remplit pas la promesse affichée (rappel de la leçon E11a : un garde vert ne prouve que ce qu'il scanne).
- **Recommandation** : ajouter `'Color(0x'` (et éventuellement `const Color('`) à la liste des motifs bannis du garde.

### LOW-1 — Fuite de `TextEditingController` des nœuds supprimés
- **Fichier** : `z_mindmap_outline_controller.dart:43-48, 138, 202-214`.
- **Impact** : `_labelControllers`/`_contentControllers` croissent de façon monotone (`putIfAbsent` à l'affichage) et ne sont purgés qu'au `dispose()` du contrôleur. `deleteNode(id)` retire le nœud de la forêt mais **laisse ses deux controllers** en carte. Sur un éditeur longue durée à fort churn add/delete, accumulation mineure (jamais réutilisée, les `id` étant des UUID). Aucun impact fonctionnel.
- **Recommandation** : purger `_labelControllers.remove(id)?.dispose()` / `_contentControllers.remove(id)?.dispose()` pour le sous-arbre supprimé dans `deleteNode`, ou documenter le compromis.

### LOW-2 — Sémantique `textField` imbriquée/redondante
- **Fichier** : `z_mindmap_outline_editor.dart:262-287` et `:293-318`.
- **Impact** : chaque `TextField` (qui expose déjà une sémantique `textField` via son `EditableText` interne) est enveloppé dans `Semantics(textField: true, label: …)`. Le wrapper crée un **second** nœud sémantique `textField`, produisant un arbre a11y légèrement redondant. Fonctionne (tests verts, `find.bySemanticsLabel('Titre')` OK) ; concerne la qualité du parcours lecteur d'écran, pas la correction.
- **Recommandation** : fournir le `label` sans redoubler le flag `textField:true` sur le wrapper (ou passer par `InputDecoration`/`SemanticsLabel` du champ) pour un seul nœud `textField` labellisé.

## Verdict

**Prêt pour `done` après traitement des 2 MEDIUM** (correction par défaut, ou justification écrite conforme à la politique projet).

- **AC2 (invariant central)** : correct et **réellement démontré** par test anti-bug-lex — aucun HIGH/MAJEUR. La sauvegarde applique bien les modifications ; aucune perte d'edit (label/content/add/delete/indent/outdent/reorder) ; `level` cohérent via `ZMindmapTreeOps`.
- **AD-2/AD-15/AD-1/FR-26/`ListView.builder`/directionnel-RTL/composition addSibling-addRoot** : conformes.
- Les 2 MEDIUM (tap target des champs ≥ 48 dp ; garde `Color(0x`) sont périphériques à l'invariant mais relèvent de règles dures (AD-13, FR-26) et sont peu coûteux à corriger dans le périmètre. Les 2 LOW sont optionnels.

---

## Résolution (orchestrateur)

Re-vérif verte (depuis la racine) : `dart analyze packages/zcrud_mindmap` RC=0, `flutter test packages/zcrud_mindmap` **110 tests** RC=0.

- **MEDIUM-1 (cibles ≥48dp) — CORRIGÉ.** `InputDecoration.constraints: BoxConstraints(minHeight: config.minTapTarget)` sur les TextField label ET content. **Test ajouté** : chaque `TextField` rendu est asserté ≥ 48 dp de haut.
- **MEDIUM-2 (garde FR-26 incomplet) — CORRIGÉ.** Motif `Color(0x` ajouté à la denylist du grep de garde (en plus de `Colors.`) → un littéral couleur hexadécimal serait désormais détecté.
- **LOW-1 (fuite controllers) — CORRIGÉ.** `deleteNode` purge récursivement les `TextEditingController` du sous-arbre supprimé (`_disposeSubtreeControllers`), avec garde `identical` (no-op si introuvable).
- **LOW-2 (Semantics redondant) — CORRIGÉ.** Retrait du flag `textField: true` redondant sur les deux champs (le `TextField` expose déjà ce rôle), label a11y conservé.

Rappel : bug lex (AC2, save applique réellement les edits) confirmé corrigé par conception et prouvé par test (`findNode(saved,id).label == édité`).

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
