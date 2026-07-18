# Code-review — me-2 (`ZMultiFlashcardEditor`)

Story : `me-2-multi-editeur-flashcards.md` · Package : `packages/zcrud_study` · Statut : `review`
Skill : cycle `bmad-code-review` (multi-lentilles) + remédiation dev (effort high, model hérité).

## Vérif verte rejouée RÉELLEMENT (avant `done`)

- `flutter test` (`packages/zcrud_study`) : **462 tests, RC=0** (baseline me-2 = 451 → +11 tests porteurs).
- `dart analyze .` (`packages/zcrud_study`, = gate `melos run analyze` réel `exec: dart analyze .`) : **RC=0, 0 issue**.
  - Note : `flutter analyze` remonte 32 `info` non fatals (`containsSemantics` déprécié, `depend_on_referenced_packages` dartz dans les tests) — patrons PRÉ-EXISTANTS partagés avec les tests déjà livrés (`z_flashcard_a11y_test.dart`, `z_flashcard_list_view_test.dart`) ; 0 error / 0 warning ; aucun `info` dans le code `lib/`.
- Graphe de dépendances : **inchangé** (aucune arête nouvelle — seuls des fichiers existants de `zcrud_study` sont édités).

## Tableau des findings

| # | Sévérité | Finding | Statut | Preuve (test porteur + falsifiabilité) |
|---|---|---|---|---|
| BUG-1 | **MAJEUR** | Perte de données : champ commun appliqué à la carte focalisée reverté à null à la frappe suivante (`_rebuild` repartait de `widget.initialCard` figé). | **Corrigé** | `z_multi_flashcard_editor_test.dart` → groupe `🔴 BUG-1`. Rouge AVANT (`folderId == null`, `Actual: <null>`), vert APRÈS (relecture de `_draft.cardOf(key)` via `baseCardOf`). |
| BUG-2 | **MAJEUR** | AD-10 : un `onCommit` qui `throw` traversait la surface (aucun repli). | **Corrigé** | `try/catch` → `Left(ServerFailure)` (patron `ZListSelectionController.batchApply`). Tests `🔴 BUG-2` (controller : `commit` retourne `Left`, reste dirty ; widget : message `Échec` + `takeException()==null`). Rouge AVANT (throw non capté), vert APRÈS. |
| BUG-3 | **MEDIUM** | Commit ré-entrant : double-tap = 2 salves (viole AC4 « exactement une salve »). | **Corrigé** | Garde `_isCommitting` (try/finally). Test `🔴 BUG-3` : rouge AVANT (`writes == 2`), vert APRÈS (`writes == 1`). |
| FIX-4 | **MAJEUR** | Test infalsifiable : l'espion (étage b) était appelé directement, jamais câblé au sujet ⇒ `writes==witnessed` tautologique. | **Corrigé (test)** | Restructuré : mutations SANS commit ⇒ `spy.writes==0`, PUIS `draft.commit(spy.commit)` ⇒ `writes==1` (témoin et sujet partagent le SEUL canal de persistance `commit`). Retirer le commit final fait rougir `writes==1`. |
| FIX-5 | **MAJEUR** | Aucun test ne prouvait qu'éditer un champ de carte atteint la liste committée. | **Corrigé (test)** | Test `🔴 FIX-5` : édite `z-card-question` → commit → `payloads.last.single.question == 'Éditée'`. Falsifié : neutraliser `onChanged` → rouge. |
| FIX-6 | **MEDIUM** | AC7 : la mutation in-memory du champ commun n'était jamais assertée (seul le rapport l'était). | **Corrigé (test)** | Test `🔴 FIX-6` : apply folderId → commit → `payloads.last` tous `folderId=='dossier-x'`. Falsifié : `writeRootInMemory` apply→identité → rouge. |
| FIX-7 | **MEDIUM** | a11y : launcher de génération non MESURÉ ; harness a11y sans generation/commonFields. | **Corrigé** | Launcher enveloppé `_minTarget` + harness `full` (generation + commonFields). Tests `🔴 FIX-7` mesurent launcher (`z-generation-launch`), champ commun et dropdown type ≥48dp. |
| FIX-8 | **MEDIUM** | a11y : `MergeSemantics` fusionnait case (toggle) et ouverture (navigate) ⇒ une seule action de tap survivait. | **Corrigé** | `MergeSemantics` retiré. Test `🔴 FIX-8` : bascule (`hasCheckedState`) ET ouverture (`hasTapAction`) sur nœuds SÉPARÉS (`cb.id != open.id`). Rouge AVANT (même nœud fusionné), vert APRÈS. |
| FIX-9 | **MEDIUM** | perf/SM-1 : recalcul du *dirty* en O(N) (reconstruction + égalité profonde) à CHAQUE frappe. | **Corrigé** | Décompte incrémental `_divergentCount` : chemin CHAUD (`updateCard`) ajuste en O(1) (une seule comparaison vs snapshot) ; chemins FROIDS (add/remove/gen/commit/abandon) recalculent en entier. Sémantique IDENTIQUE (comparaison positionnelle par valeur). Test `🔴 FIX-9` (éditions multiples + revert partiel + interleaving structurel) — falsifié : `_setDirty(nowDivergent)` naïf → rouge. |
| LOW#10 | LOW | `failure.message` non localisé concaténé au message d'échec. | **Corrigé** | `_commit` affiche `labels.commitFailed` LOCALISÉ seul (n'accole plus la `ZFailure.message` brute — évite aussi de fuiter la trace de BUG-2 à l'UI). |
| LOW#13 | LOW | Échec de génération `Left`/`throw` non exercé au niveau me-2. | **Corrigé** | Test `🔴 LOW#13` : port renvoie `Left(ServerFailure('port en panne'))` → message rendu, aucune carte ajoutée, `writes==1` (témoin), `takeException()==null`. |
| LOW#15 | LOW | Résumé de ligne stale en split-view (la liste écoute `orderKeys`, pas les édits de champ). | **Consigné (reporté)** | Tradeoff SM-1 ASSUMÉ : la liste ne se reconstruit pas à la frappe (objectif produit n°1). Rafraîchir le résumé à chaque frappe réintroduirait le rebuild global. Comportement documenté ; hors correctif. |

## MEDIUM / LOW reportés — justification écrite

- **LOW#15 (reporté)** : corriger imposerait à la liste d'écouter les édits de champ (`updateCard`), ce qui casserait l'invariant SM-1 (objectif produit n°1 : taper ne reconstruit QUE le champ courant, `orderKeys` inchangé). Le résumé de ligne se met à jour aux changements structurels et au retour sur la liste. Décision : documenter, ne pas corriger (le remède serait pire que le mal).
- Aucun autre MEDIUM reporté : BUG-3, FIX-6, FIX-7, FIX-8, FIX-9 sont tous CORRIGÉS dans le périmètre me-2 sans régression (462 verts).

## Invariants AD vérifiés (rejoués sur disque)

- **AD-2 / SM-1** : `baseCardOf` ne recrée JAMAIS les `TextEditingController` (relit seulement la base au `copyWith`) — le test AC10/SM-1 existant (controller stable + `rowBuilds==0` à la frappe) reste vert ; FIX-9 renforce l'O(1) par frappe.
- **AD-10** : BUG-2 (throw capté → `Left`) ; LOW#13 (`Left` génération → repli) ; `takeException()==null` partout.
- **AD-13** : FIX-7 (cibles ≥48dp mesurées sur TOUS les contrôles) ; FIX-8 (deux actionnables sémantiques distincts) ; variantes directionnelles inchangées.
- **AD-43** : la seule frontière de persistance reste `commit` (FIX-4 le prouve sur le canal réel ; garde de pureté vm inchangée) ; aucune arête/CORE OUT modifiée.
