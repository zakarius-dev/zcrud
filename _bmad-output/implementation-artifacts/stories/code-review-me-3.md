# Code-review me-3 — Branchement sélection multiple (`ZFlashcardListView`)

Story : `me-3-branchement-selection-liste-flashcards.md`
Périmètre : `packages/zcrud_study` (widget + seam) ; `packages/zcrud_flashcard` (aucune modif en remédiation).
Verdict entrée : **0 HIGH / 0 MAJEUR** (cascade SRS solide, falsifiable 4 étages) ; **5 MEDIUM** + LOW éditoriaux.

## Vérif verte (rejouée réellement sur disque, post-remédiation)
- `flutter test packages/zcrud_study` → **490** tests, **RC=0** (baseline 483 + 7 porteurs).
- `flutter test packages/zcrud_flashcard` → **545** tests, **RC=0** (inchangé).
- `dart analyze packages/zcrud_study packages/zcrud_flashcard` (= gate `melos run analyze` = `dart analyze .`) → **RC=0**. 42 infos pré-existantes (fichiers non touchés : ports, tests dev-story) ; **0 introduite** par la remédiation ; `z_flashcard_list_view.dart` non flaggé. (`flutter analyze` rend RC=1 car il traite les infos comme fatales — ce n'est PAS le gate projet.)
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK**, 57 arêtes, **aucune nouvelle arête**.

## Findings × sévérité × statut × test porteur

| # | Sévérité | Finding | Statut | Correctif | Test porteur (rouge AVANT → vert APRÈS) |
|---|----------|---------|--------|-----------|------------------------------------------|
| MED-1 | MEDIUM | AD-39 : `onBatchResult` (canal app, rapport de lot incl. échecs partiels) **avalé** si la liste se démonte pendant l'`await` — garde `if (!mounted) return;` avant la remontée (delete l.755-756, move l.777-778). | ✅ Corrigé | Retrait de la garde `!mounted` **de la remontée du rapport** (delete + move) : `onBatchResult` est livré **inconditionnellement** (callback appelant, pas un `setState` ; aucun code UI/`context` ne suit). | `MED-1 SUPPRIMER` + `MED-1 DÉPLACER` : seam lent (`Future.delayed`) → tap → `pumpWidget(SizedBox())` (démonte) mid-await → `expect(received, isNotNull)`. **AVANT** : `received == null` (E). **APRÈS** : reçu. |
| MED-2 | MEDIUM | AD-44 : `_SelectionCheckbox` **sans `didUpdateWidget`** ne se réconcilie pas au **swap** de contrôleur (la liste le swappe légitimement, l.532-539) → case **affiche** l'ancien contrôleur + **listener orphelin** sur l'ancien. | ✅ Corrigé | Ajout de `didUpdateWidget` à `_SelectionCheckboxState` : si `oldWidget.controller != widget.controller` ⇒ désabonne l'ancien, réabonne le nouveau, resync `_selected`. Dispose inchangé (retire du contrôleur courant). | `MED-2 swap A(coché)→B(vide)` : (a) case **décochée** reflète B ; (b) toggle mute **B** ; (c) muter **A** n'affecte plus la case (listener de A désabonné). **AVANT** : `value == true` (reflétait A) (E). **APRÈS** : reflète B. |
| MED-3 | MEDIUM | AD-10 : `await move.resolveDestination(context)` (picker INJECTÉ) **sans try/catch** ; `_runBatchMove` étant `unawaited`, un `throw` (picker KO, assertion Navigator) rejette un Future non-awaité et **traverse la surface** (Zone/FlutterError). | ✅ Corrigé | `try { chosen = await move.resolveDestination(context); } catch (_) { return; }` — chemin **défini** (no-op, sélection conservée), jamais de traversée. Symétrie avec le seam d'écriture déjà capté par `batchMove`. | `MED-3 picker KO (throw)` : `resolveDestination: (_) async => throw StateError('picker KO')` → tap → `expect(tester.takeException(), isNull)` + `moveCalls == 0` + sélection conservée. **AVANT** : exception non captée (E). **APRÈS** : no-op propre. |
| MED-4 | MEDIUM | SM-1 : le garde de granularité **PAR CASE** (`if (now != _selected)`) n'avait **aucun compteur dédié** (R3 : le retirer laissait la suite verte ⇒ infalsifiable). Le code du garde EXISTAIT et était correct. | ✅ Renforcé (test) | Aucune modif de prod. Ajout d'un **compteur PAR CASE** (via `checkboxSemanticLabel`, invoqué à chaque build de case) prouvant que cocher c1 ⇒ delta(c1)==1, delta(c2)==delta(c3)==0. | `MED-4/SM-1` : toggle c1 → deltas. **Contrôle R3 réel exécuté** : garde retiré ⇒ delta(c2)==1 attendu 0 (E, ROUGE) ; garde restauré ⇒ vert. Falsifiabilité prouvée. |
| MED-5 | MEDIUM | a11y : `label: sel.deleteActionLabel ?? ''` — action « supprimer » de lot **muette** si `deleteActionLabel` omis alors que `deleteRoot` fourni (`String?` sans assert ; récidive su-9). me-1 bloque pourtant le couple par assert (`z_batch_action.dart:98-104`). | ✅ Corrigé | `assert(deleteRoot == null \|\| deleteActionLabel != null, ...)` au constructeur de `ZFlashcardListSelection` (miroir me-1) **+ retrait du `?? ''`** (`sel.deleteActionLabel!`). Couple move/label déjà sûr (`label` requis non-null). | `MED-5` : `ZFlashcardListSelection(deleteRoot: <seam>, deleteActionLabel: null)` ⇒ `throwsAssertionError` ; `deleteRoot: null` ⇒ `returnsNormally`. **AVANT** : construit sans lever (E). **APRÈS** : assert lève. |

## LOW — traitement

| # | Sévérité | Finding | Statut | Détail |
|---|----------|---------|--------|--------|
| LOW-A | LOW | `z_flashcard_cascade_delete.dart` : la prose « dette d'orphelins corrigée par conception » vaut pour le **lot seulement** ; la suppression **unitaire** (menu, `onDelete`, prop su-8) ne passe pas par le seam. | ✅ Corrigé (éditorial) | Ajout d'un paragraphe **« bornage »** : la garantie est bornée au chemin de lot ; **l'app DOIT router la suppression unitaire par le MÊME seam** ; le câblage exhaustif est la responsabilité du consommateur. |
| LOW-B | LOW | dartdoc de `_SelectionCheckbox` disait « keyée par id stable » alors que la case ne porte **aucune** `key` (l'identité vit sur la tuile parente `ValueKey('tile-<id>')`). | ✅ Corrigé (éditorial) | Reformulation : la case n'a aucune `key` ; son identité stable vient de la **tuile parente** keyée par l'`id`. (Comportement inchangé, prose corrigée.) |
| LOW-C | LOW | test AC7 n'assérait que `hasLength(4)` — ne prouvait pas l'await-par-racine séquentiel. | ✅ Renforcé | Ajout d'assertions d'**ORDRE exact** : `del.deletedCards == ['A','B','C','D']` **et** `store.deletedIds == ['A','B','C','D']` (await séquentiel dans l'ordre de la sélection). La preuve stricte de non-parallélisme (un seul await en vol) reste **couverte côté me-1** (`batchApply`) — non dupliquée ici. |
| LOW-D | LOW | test AC9 vérifiait le compteur par `find.text` seulement. | ✅ Renforcé | Ajout de `expect(tester.getSemantics(find.text(_count(3))).label, contains('3'))` (le compteur est ANNONCÉ, pas qu'affiché). Source unique me-1 (`ZBatchActionBar`). |

**Aucun MEDIUM reporté ; aucun LOW reporté** (tous corrigés ou renforcés dans le périmètre, sans régression).

## Notes de conformité AD (re-vérifiées)
- **AD-39** (MED-1) : rapport de lot désormais toujours remonté (delete + move).
- **AD-44** (MED-2, MED-5) : contrôleur propriétaire unique réconcilié au swap ; action absente si seam `null` mais **jamais muette** si présente.
- **AD-10** (MED-3) : seam picker enveloppé, aucune traversée.
- **AD-2 / SM-1** (MED-4) : rebuild granulaire par case prouvé falsifiable.
- **AD-1 / CORE OUT=0** : `graph_proof` inchangé, aucune arête ajoutée ; `z_flashcard_list_view.dart` reste pur (aucun store importé).
