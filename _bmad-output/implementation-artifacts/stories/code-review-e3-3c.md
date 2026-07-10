# Code Review — Story E3-3c : Champ fichier / image / document (`ZAppFileField`)

- **Date** : 2026-07-10
- **Reviewer** : bmad-code-review (adversarial, effort high)
- **Skill invoqué** : `Skill(bmad-code-review, "review E3-3c")` — chemin pris : **skill BMAD réel** (`steps/step-01…03`) via `.claude/skills/bmad-code-review/SKILL.md`. Résolution `resolve_customization.py` OK (workflow vide, aucun prepend/append).
- **Baseline** : `acc6a2138a437fd3d1c53886246fa3340c0b540f` (== HEAD ; tout E3 est non committé — diff = working tree).
- **Périmètre** : les fichiers E3-3c uniquement (App/port/picker/widget/config/famille/dispatch/scope/l10n/barrel + tests).
- **Verdict** : **APPROVED** (0 HIGH / 0 MAJEUR ; 1 MEDIUM à corriger-ou-justifier avant `done` ; 4 LOW).

---

## Vérifications RÉELLEMENT rejouées sur disque

| Gate | Commande | Résultat |
|---|---|---|
| Analyze | `dart analyze lib test` (zcrud_core) | **No issues found!** RC=0 |
| Tests | `flutter test` (zcrud_core) | **+427 All tests passed!** RC=0 |
| Graphe | `scripts/dev/graph_proof.py` | `out-degree(zcrud_core) = 0 (runtime)` → **ACYCLIQUE OK / CORE OUT=0 OK**, 14 nœuds, 17 arêtes |
| Packages | `melos list` | **14** |
| Codegen committé | `git ls-files '*.g.dart' '*.freezed.dart'` | **0** |
| **AD-1 grep lourd** | `grep -rE 'package:(image_picker\|file_picker\|firebase)' lib/` | **0** (RC=1 clean) |
| **AD-1 pubspec** | `grep image_picker\|file_picker\|firebase\|syncfusion\|quill pubspec.yaml` | **0** (RC=1 clean) |
| **dart:io** | `grep -r 'dart:io' lib/` | **0 import** (unique occurrence = doc-comment expliquant qu'il est hors whitelist) |
| Port neutre | `grep Timestamp\|Filter\|FirebaseException\|firebase port.dart` | **0** dans le code (uniquement en doc-comment) |

Tous les invariants critiques verts. `melos run verify` n'a pas été relancé séparément mais ses composantes (analyze + graph_proof CORE OUT=0 + no-heavy-dep gate + 0 `.g.dart`) sont vertes individuellement.

---

## Jugement sur le contournement `liveValue` (course read-modify-write) — **SOUND**

La course signalée par le dev est **correctement résolue**. Analyse :

- `ZFormController.setValue` est **synchrone** (`_slice(name).value = value`) et `valueOf` lit immédiatement la valeur committée. Le getter `liveValue = () => controller.valueOf(field.name)` (câblé par le dispatcher, `z_field_widget.dart:408`) donne donc **l'état le plus récent réellement écrit**, indépendamment du rebuild value-in-slice différé qui n'a pas encore propagé `widget.value`.
- `_files`, `_replace`, `_commit`, `_pick` lisent **tous** `liveValue` → chaîne read-modify-write cohérente. `mounted` est vérifié après chaque `await`.
- **2 uploads concurrents** (multiple, pick [A,B]) : chaque `_startUpload` lit le slice vivant avant/après son `await` → `[A(uploading),B]` puis `[A(uploading),B(uploading)]` puis complétions séquentielles (mono-thread Dart) `[uploadedA,B(up)]` → `[uploadedA,uploadedB]`. **Aucun fichier perdu.**
- **Add pendant upload** : `_pick` en vol pendant qu'un upload se termine → au retour du picker, `combined = [..._files vivant, ...picked]` intègre le fichier déjà uploadé (via `liveValue`). **Aucune perte** — c'est précisément le bug qu'aurait produit une lecture de `widget.value` périmé.
- **Suppression pendant upload** : `_remove` retire l'entrée ; à la complétion, `_replace(old, uploaded)` ne trouve plus l'identité → **no-op** (pas de résurrection). Comportement correct.

L'approche **ne casse ni SM-1 ni AD-2** : `valueOf` est une lecture ponctuelle **sans abonnement** (aucun `notifyListeners` global, aucune souscription élargie) ; la frontière de rebuild reste `ZFieldListenableBuilder` sur la seule tranche. Test SM-1 dédié vert (100 frappes, structurel==1, `find.byType(Form) findsNothing`).

---

## Résultats des contrôles adversariaux ciblés

- **AD-1 (cœur OUT=0)** : ✅ picker (`ZFilePicker`) et storage (`CloudStorageRepository`) sont de **vraies interfaces** injectées via `ZcrudScope` (nullable, dégradation propre). Aucune impl concrète dans le cœur. `Image.network` (web-safe) ne tire pas `dart:io` ; chemin local rendu en icône+nom (rendu binaire local déféré). Nouveau garde `test/purity/no_heavy_file_dep_test.dart` (pubspec + imports lib/). **CORE OUT=0**.
- **Famille file / 0 default** : ✅ `familyOf` route `file`/`image`/`document` → `EditionFamily.file` ; `switch` **exhaustif sans `default:`** ; `stepper` = **seul** `unsupported` (asserté). Partition 39 = base(13)+hidden(1)+feuilles(8)+freeWidget(1)+registre(12)+file(3)+unsupported(1). `z_field_dispatch_test.dart` (T9) mis à jour.
- **AppFile défensif (AD-10)** : ✅ `fromMap` sur map vide / champs corrompus / `upload_state` inconnu → défauts sûrs, `ZAppFileUploadState.fromName` retombe sur `pending`, **jamais un throw**. **Aucun champ bytes/`Uint8List`** (référence seule → tranche légère). `copyWith`/`==`/`hashCode`/round-trip présents.
- **Port neutre (AD-5/AD-11)** : ✅ `Either<ZFailure,_>` (`ZResult`), `Unit` pour delete, `Stream<double>` **nu** pour la progression, `AppFile` + `dartz.Unit` seuls types exposés. Fake prouve `upload→Right(uploaded)`, `Left(ServerFailure)`, `delete→Right(unit)`, retry (`uploadCount++`), sans-storage → `pending`.
- **a11y/RTL/SM-1 (AD-13)** : ✅ `IconButton` (≥48 dp, `meetsGuideline(androidTapTargetGuideline)` vert) + tooltips l10n ; `failed`/`uploading` annoncés (`Semantics liveRegion`) ; insets `EdgeInsetsDirectional` exclusifs, `TextAlign.start`, `Wrap`/`Row` directionnels ; couleurs dérivées du thème ; RTL sans overflow ; l10n en/fr complètes (9 clés).

---

## Findings

### MEDIUM

**M1 — `maxFiles` : troncature SILENCIEUSE, « refus accessible » (AC8) non implémenté.**
`z_app_file_field_widget.dart:129` `combined.sublist(0, max)` élimine les fichiers excédentaires **sans aucun retour accessible** (ni `Semantics`, ni message l10n, ni annonce). L'AC8 exige explicitement « au-delà, **refus accessible** sans crash ». *Absence de crash ✓, mais le volet « accessible » du refus manque.* Un utilisateur (a fortiori lecteur d'écran) sélectionnant N>maxFiles fichiers ne reçoit **aucune** indication que certains ont été écartés.
- **Reco** : émettre un message accessible (clé l10n `fileMaxReached` + `Semantics liveRegion` ou `SnackBar`) quand `combined.length > max`. Ajouter un test. À **corriger dans le périmètre** ou **justifier par écrit** (CLAUDE.md — politique MEDIUM) avant `done`.
- Sévérité : MEDIUM (déviation d'AC + a11y AD-13/FR-23 ; non bloquant fonctionnellement, dégradation gracieuse).

### LOW

**L1 — Commentaire trompeur sur `_ActionButton` (`z_app_file_field_widget.dart:272-274`).** Le doc-comment affirme « `Semantics(button, label)` explicite … on le renforce pour la robustesse des tests a11y », mais **aucun** wrapper `Semantics` n'existe : le bouton s'appuie uniquement sur `IconButton` + `tooltip`. Fonctionnellement correct (IconButton porte la sémantique `button` + le tooltip alimente le label), mais le commentaire décrit du code absent. Aligner le commentaire sur la réalité.

**L2 — Collision d'identité sur fichiers homonymes sans `localPath`/`id`.** `_identity(f) = localPath ?? id ?? name` (`:98`). Deux `AppFile` de même `name` avec `localPath==null && id==null` partagent la même identité ⇒ `_remove`/`_replace` affectent **les deux**. Risque réel faible (le contrat `ZFilePicker` renseigne `localPath`), mais à surveiller pour un picker non conforme. Envisager une identité de repli plus robuste (index/uuid) ou documenter l'invariant « picker fournit toujours localPath ».

**L3 — Course concurrente NON couverte par un test.** Le mécanisme `liveValue` (jugé sound ci-dessus) répond exactement au scénario « 2 uploads concurrents / add pendant upload », mais **aucun test** ne l'exerce (les tests upload sont mono-fichier). Ajouter un test multiple avec 2 acquisitions/uploads concurrents et un add-during-upload verrouillerait la non-régression du contournement.

**L4 — `watchProgress` / `AppFile.progress` : surface non câblée.** Le port expose `Stream<double> watchProgress` et `AppFile.progress` existe, mais le widget n'y souscrit **jamais** (spinner indéterminé pendant `uploading`, `progress` jamais mis à jour). La progression est optionnelle par AC, donc acceptable — mais c'est de l'API morte côté cœur pour E3-3c. Documenter comme « progression fine = extension future (E5/E7) » ou retirer du périmètre affiché.

---

## Trous de couverture (récapitulatif)

- ❌ `maxFiles` atteint → **feedback accessible** (M1) : borne testée (`length==2`) mais pas le refus accessible.
- ⚠️ Uploads **concurrents** / **add pendant upload** (L3) : non testés (mécanisme sound par revue).
- ⚠️ **Suppression pendant upload** : couverte par raisonnement (no-op à la complétion) mais pas de test explicite.
- ⚠️ **mime non reconnu** → `isImage==false` → icône générique : comportement correct, pas de test dédié (LOW, acceptable).
- ⚠️ `single` mode avec picker renvoyant >1 fichier : seul `first` retenu/uploadé, reste écarté silencieusement (cohérent single, non testé).

---

## Conclusion

Story techniquement **solide et verte** : AD-1 rigoureusement respecté (cœur OUT=0, 0 dep lourde, 0 `dart:io` import, port neutre), AppFile défensif (AD-10), value-in-slice/SM-1 préservés (AD-2), a11y/RTL/l10n conformes (AD-13). Le contournement `liveValue` de la course read-modify-write est **correct** et ne dégrade ni SM-1 ni AD-2. **Aucun finding HIGH/MAJEUR.**

**Verdict : APPROVED.** Traiter **M1** (corriger le refus accessible `maxFiles`, ou le justifier par écrit) et, idéalement, ajouter le test de course concurrente (L3) avant de passer la story à `done`. L1/L2/L4 sont optionnels (nits/dette documentée).
