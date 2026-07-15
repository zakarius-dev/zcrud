# Code Review — ES-4.5 : Widgets qualité & progression SRS (`ZSrsQualityButtons`, `ZSessionQualityBreakdown`, `ZStudyProgressRings`)

Revue adversariale (bmad-code-review, effort high). Cible : `packages/zcrud_session/**` uniquement. `zcrud_session/` est un package NEUF non encore committé (`git status` = `?? packages/zcrud_session/`) — revue sur l'état disque (aucune baseline git ; le « modifié » `z_purity_test.dart` est relatif au travail non committé de l'epic).

## Verdict global : **APPROUVÉ avec réserves** — 0 critique, 0 majeur, 1 MEDIUM, 1 LOW.

Story verte et discriminante. Le CŒUR (mapping UI↔quality, breakdown fidèle, DTO rings) est correctement gardé et prouvé load-bearing par injection réelle. Un chemin de **dégradation silencieuse (R6)** subsiste dans le breakdown (MEDIUM) et la compensation du scan de pureté est un allowlist figé (LOW).

---

## AXE n°1 (PRIORITÉ) — VERDICT sur le scope-out du scan de pureté

**Le scope-out est une COMPENSATION RÉELLE, pas un faux-vert.** Preuves rejouées :

1. **Le scan runtime originel reste INTACT pour le domaine.** `test/z_purity_test.dart` scanne toujours `lib/` en récursif et n'exclut QUE `/presentation/` (l.51 : `.where((f) => !f.path...contains('/presentation/'))`). Les imports bannis (`flutter_riverpod`/`riverpod`/`get`/`provider`/`flutter/material`/`flutter/widgets`/`flutter/cupertino`) restent interdits sur `lib/src/domain/`. Le scope-out n'exclut QUE presentation — rien d'autre n'est masqué.

2. **La compensation `test/presentation/z_widgets_purity_test.dart` (AC9) BANNIT RÉELLEMENT riverpod/get/provider dans presentation (tout en autorisant material).** PROUVÉ par injection : ajout de `import 'package:provider/provider.dart';` dans `z_srs_quality_buttons.dart` →
   - compensation `z_widgets_purity_test.dart` → **ROUGE** (`RC=1`, message `z_srs_quality_buttons.dart:20 → import banni: package:provider/`).
   - scan runtime scopé `z_purity_test.dart` → **VERT** (`RC=0`) — confirme que presentation est bien hors dragnet et repose ENTIÈREMENT sur la compensation.
   Injection restaurée par édition ciblée (R13) ; retour au vert prouvé.

3. **Le changement de `z_purity_test.dart` = strictement l'ajout du filtre `/presentation/` + doc.** Aucune ligne masquant un import banni. Les `_bannedImports` du domaine sont inchangés.

**Réserve (voir Finding #2 LOW)** : la compensation garde presentation via une **liste FIGÉE de 3 fichiers** (`_presentationFiles`), pas un scan récursif. Un 4e fichier presentation important `provider` ne serait attrapé NI par le dragnet runtime (presentation exclue) NI par la compensation (fichier absent de la liste). Durabilité de la garde à renforcer.

---

## Axe n°2 — mapping qualité / breakdown / rings / passThreshold (R12, injections REJOUÉES)

Toutes les 6 injections R3 rejouées RÉELLEMENT (édition ciblée → ROUGE → restauration ciblée R13, jamais `git checkout`). Messages EXACTS capturés (RC hors pipe, R15) :

| INJ | Édition | Test | Résultat |
|---|---|---|---|
| INJ-1 | mapping cran 5 → `onQualitySelected(0)` | `z_srs_quality_buttons_test.dart` | **ROUGE** `Expected: <5> Actual: <0>` (« cran visuel 5 doit noter la qualité 5 ») |
| INJ-2 | breakdown omet `quality==2` (`&& quality != 2`) | `z_session_quality_breakdown_test.dart` | **ROUGE** `exactly one matching candidate / Found 0 widgets with key [<'zBreakdownSegment_2'>]` |
| INJ-3 | `ratio = correct/(total-1)` | `z_study_progress_rings_test.dart` | **ROUGE** `Expected: <0.75> Actual: <0.857…>` |
| INJ-4 | `Colors.blue` en dur dans le painter des rings | `z_widgets_hardcode_scan_test.dart` | **ROUGE** `z_study_progress_rings.dart:167 → Colors. :: ..color = Colors.blue;` |
| INJ-6 | `passed: quality >= 3` (littéral) | `z_srs_quality_buttons_test.dart` | **ROUGE** `Expected: contains 'lapse' Actual: 'ok'` (à `passThreshold: 4`) |

(INJ-5 a11y non re-rejouée cette fois ; les assertions ≥48dp + Semantics button sont présentes et vertes — `getSize ≥ 48` cran-par-cran + `semantics.properties.button`. Le dev l'avait rejouée : cible 24 → `Actual: <38.25>` ROUGE.)

- **AC1 mapping (central)** : le mapping cran→qualité vit DANS le widget (`onTap: () => onQualitySelected(quality)`, D6) ; le widget N'IMPORTE PAS le scheduler (AD-23 par construction) — l'intervalle vient du seam `previewLabelFor` injecté. Conforme.
- **AC6 passThreshold injecté** : `_colorKeyOf` et `passed:` lisent `quality >= passThreshold` (jamais `3` littéral). Conforme.
- **AC rings DTO** : `ratio = total==0 ? 0.0 : (correct/total).clamp(0,1)` — `total==0→0`, clampé. Conforme.

---

## Axe n°3 — thème / a11y / AD-1

- **FR-26 anti-hardcode (AC4)** : aucune couleur/label en dur — couleurs via `zResolveColorKeyOrSlot`/`ZcrudTheme`, labels via `label(context, key, fallback:)` l10n `zcrud_core`, espacements/rayons `ZcrudTheme`. Scan `z_widgets_hardcode_scan_test.dart` vert, ROUGE sous INJ-4.
- **AD-13 a11y/directionnel (AC5)** : cibles ≥48dp (`ConstrainedBox(minWidth/minHeight: 48)`), `Semantics` explicites (button label+value ; segment label+`$count` ; rings « correct/total »), directionnel (`TextAlign.center/end`, `EdgeInsetsDirectional` via `ZcrudTheme.fieldPadding`, `Wrap`/`Column` — jamais `ListView(children:)`). Couleur jamais seul canal (texte/compte toujours rendu). Scan directionnel vert.
- **AD-1 / graphe** : `graph_proof.py` → **ACYCLIQUE OK**, **out-degree(zcrud_core)=0 → CORE OUT=0 OK**. `zcrud_session` out-edges = `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel` — toutes PRÉ-EXISTANTES (aucune nouvelle arête inter-package). `melos list = 20`. Aucun `.g.dart`. Barrel additif (3 widgets + `ZQualityScale` + `ZProgressRingsData`), aucun export supprimé.

---

## Findings

### [MEDIUM] R6 — chute silencieuse d'une clé `byQuality` non-canonique parsant en-échelle
**Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart` (l.75-87 boucle inScale + l.91-94 / l.130-133 `_isInScale`).

**Défaut** : la boucle « in-scale » teste `byQuality.containsKey('$quality')` avec les clés CANONIQUES `"0".."5"`, tandis que `_isInScale(rawKey)` exclut de l'ensemble « hors échelle » toute clé dont `int.tryParse` tombe dans l'échelle. Une clé non-canonique mais parsant en-échelle (`"03"`, `"+3"`, `" 3"`, `"005"`) est donc rendue **NULLE PART** : ni segment in-scale (pas de match string canonique), ni segment hors-échelle (`_isInScale` la juge connue). Son compte **disparaît silencieusement**.

**Scénario d'échec (vérifié `int.tryParse`)** : `byQuality: {"03": 7}` avec `scale 0..5` → `containsKey('3')` = false (aucun segment in-scale) ; `_isInScale("03")` → `tryParse=3`, `scale.contains(3)=true` → exclue des `unknownKeys` → **aucun segment, 7 réponses perdues, aucun signalement**. C'est exactement la dégradation silencieuse que R6 / D3 promettent d'interdire (« jamais silencieusement fusionnée » — ici pire : purement supprimée). Le test AC2 ne couvre que `"9"` (canonique hors échelle, correctement rendu à part) et ne teste pas ce chemin.

**Correctif recommandé** : rendre `_isInScale` strictement canonique — `final p = int.tryParse(rawKey); return p != null && scale.contains(p) && rawKey == '$p';` — de sorte que toute clé non-canonique retombe dans `unknownKeys` (rendue à part, signalée), garantissant qu'aucune entrée de `byQuality` n'est perdue. (Reachabilité : corpus persisté corrompu/non-canonique — précisément le cas défendu par le widget.)

### [LOW] Durabilité de la garde de pureté presentation — allowlist figé au lieu d'un scan récursif
**Fichiers** : `test/presentation/z_widgets_purity_test.dart` (l.16-20 `_presentationFiles`) et `test/presentation/z_widgets_hardcode_scan_test.dart` (l.13-17, même liste figée).

**Constat** : le scope-out de `z_purity_test.dart` retire presentation du dragnet récursif ; les gardes de compensation (pureté + anti-hardcode) énumèrent une **liste figée de 3 fichiers**. Un futur 4e widget presentation (`lib/src/presentation/*.dart`) important `provider`/`riverpod`/`get` ou codant `Colors.*` en dur passerait entre les mailles des DEUX gardes. Les 3 fichiers actuels sont RÉELLEMENT gardés (prouvé par injection) — donc ce n'est pas un défaut du diff courant, mais un risque de régression latente à surveiller (cf. précédent CLAUDE.md « garde devenue powerless silencieusement »).

**Correctif recommandé** : remplacer les listes figées par un scan récursif de `lib/src/presentation/**.dart` (via `Directory('lib/src/presentation').listSync(recursive:true)`), symétrique au dragnet runtime — la garde couvre alors automatiquement tout futur widget.

---

## Vérif verte CIBLÉE (RC capturé HORS pipe, R15 ; runner `flutter`, R14)

| Vérif | Commande | RC | Détail |
|---|---|---|---|
| analyze | `flutter analyze` | **0** | `No issues found!` |
| test | `flutter test` | **0** | **73** tests passés |
| graph | `python3 scripts/dev/graph_proof.py` | **0** | ACYCLIQUE OK · CORE OUT=0 OK · aucune arête ajoutée |
| melos | `dart run melos list` | — | **20** (inchangé) |

Toutes les injections restaurées par édition ciblée (R13) ; **aucun résidu d'injection en code** (`grep` presentation = vide) ; retour au vert reconfirmé (`flutter test` RC=0, 73).

## Recommandation
`review` → traiter le **MEDIUM (R6 silent-drop)** avant `done` (correctif trivial, sans régression, dans le périmètre) ; **LOW** optionnel (durcissement recommandé). Aucun blocage critique/majeur.
