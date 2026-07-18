# Code-review — fp-1-2 (substrat satellites : squelettes 4 packages + vendoring awesome_select)

**Dispositif** : Workflow multi-lentilles (4 lentilles adversariales lecture-seule) + phase R3 sérialisée (injections réelles sur l'arbre). Rapports : `$CLAUDE_JOB_DIR/tmp/cr-fp-1-2/`.

**Verdict** : **0 HIGH / 0 MAJEUR**, 3 LOW. Les 4 gardes de confinement sont **génuinement falsifiables** (R3 : 6 injections réelles rougissent — import + dep interdits dans chaque satellite, vendor déclaré par un 2ᵉ package). Isolation vendor AD-49 intègre (déclarant unique `zcrud_select`, zéro fuite import/export, LICENSE MIT + attribution Akbar Pulatov, `publish_to:none`, `lib/**` byte-identique amont). Graphe ACYCLIQUE + CORE OUT=0 (61 arêtes) ; `zcrud_core`/`zcrud_generator` non touchés par fp-1-2.

## Findings & résolutions

| # | Sévérité | Finding | Statut |
|---|---|---|---|
| 1 | LOW | Volet import (volet 2) des 4 tests de confinement sans assertion anti-vacuité (`_dartFiles(_selfLib())` bouclé sans `expect(scanned, isNotEmpty)`) — tautologie **latente** confirmée par R3 (glob forcé à 0 fichier + import interdit réel → garde reste verte). | **CORRIGÉ** — ajout de `final files = _dartFiles(_selfLib()).toList(); expect(files, isNotEmpty, …)` aux 4 tests (`z_{select,html,media,field_extras}_confinement_test.dart`). Re-vérif : 4 packages verts (7/4/4/4). |
| 2 | LOW | `awesome_select/analysis_options.yaml` : `undefined_getter:ignore` est un blanket par catégorie (plus large que les 3 sites API amont réels : `errorColor`×1, `headline6`×2). | **CONSIGNÉ (vigilance fp-4-1)** — non exploitable au stade squelette (rien n'importe le vendor). fp-4-1 devra resserrer en `// ignore:` ligne-à-ligne en rétablissant la compat Flutter du fork. |
| 3 | LOW | Assouplissement `analysis_options` vendor par classe de règle (idem #2, angle règle). | **CONSIGNÉ (vigilance fp-4-1)** — borné au scope vendor, documenté en en-tête. |

## Dette transmise à fp-4-1 (NON bloquant fp-1-2)
La source vendorée d'`awesome_select` cible Flutter 3.0 et casse (4 erreurs API : `errorColor`, `headline6`) sous la toolchain workspace. Assouplie via le seul `analysis_options.yaml` du vendor (logique amont intacte). **fp-4-1 doit rétablir la compat Flutter du fork** avant de compiler l'adaptateur `ZSelectPresenter` contre lui, et remplacer le blanket par des ignores ciblés.

## Vérif verte (rejouée par l'orchestrateur)
`flutter test` : `zcrud_select` 7 · `zcrud_html` 4 · `zcrud_media` 4 · `zcrud_field_extras` 4 — RC=0. `graph_proof` ACYCLIQUE + CORE OUT=0. Fix limité aux fichiers de test (lib inchangée ⇒ graphe inchangé).
