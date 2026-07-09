# Code Review — E2-10 : Gate de rétro-compatibilité de sérialisation (AD-10)

- **Story** : `_bmad-output/implementation-artifacts/stories/e2-10-gate-retro-compatibilite-serialisation.md` (8 ACs, statut `review`)
- **Baseline** : `8f2875559aee498774eca8590744e816f8a5c93f`
- **Reviewer** : bmad-code-review (skill réel — **chemin pris : tool `Skill{bmad-code-review}`** ; `resolve_customization.py --key workflow` RC=0, step-01-gather-context.md chargé et suivi ; fallback disque non nécessaire)
- **Date** : 2026-07-09
- **Enjeu central** : le gate `verify:serialization` ne doit PAS être décoratif (faux vert), et le corpus doit PROUVER que le parent ne casse JAMAIS (AD-10) sur les deux voies (codegen direct + registre).
- **Fichiers sous revue (NEW, tests uniquement)** :
  - `packages/zcrud_generator/test/models/serialization_corpus.dart` (corpus partagé, source unique de vérité)
  - `packages/zcrud_generator/test/serialization_corpus_test.dart` (voie codegen directe + voie registre, `@Tags(['serialization-compat'])`)
- **Inchangés (vérifiés)** : `article.dart`/`article.g.dart` (E2-5), `serialization_compat_test.dart` (amorce E2-5, non dupliquée), `scripts/ci/verify_serialization.dart` (branchement stable par tag), `dart_test.yaml` (tag déjà déclaré), `zcrud_core`/adaptateurs (E2-6).

## Verdict : **APPROVED**

**0 HIGH · 0 MAJEUR · 0 MEDIUM · 4 LOW.** Le gate est **NON décoratif** (preuve de régression reproduite par le reviewer : 2 RC opposés). Le parent **survit sur les 7 familles × 2 voies** (aucune exception non rattrapée). Aucun finding bloquant. Les 4 LOW sont des nits de documentation/couverture marginale, safe par construction du `.g.dart` défensif.

---

## PREUVE RÉELLE que le gate capte une régression (AC5 rejoué par le reviewer)

Probe éphémère injectée par le reviewer (`test/_ephemeral_regression_probe_test.dart`, taggé `serialization-compat`) : décodeur STRICT `c.map['views'] as int` sur la fixture `views_string_non_num` (`'abc'`) → lève `CastError`.

| État | `dart run scripts/ci/verify_serialization.dart` |
|------|--------------------------------------------------|
| **AVEC probe** (décodeur strict qui throw) | **RC = 1** — `Some tests failed` ; `+52 -1`, probe rouge |
| **APRÈS suppression de la probe** | **RC = 0** — `zcrud_generator: +52: All tests passed!` |

→ **Le gate n'est PAS décoratif** : une régression AD-10 (un décodeur qui casse le parent) fait bien passer `verify_serialization.dart` en **RC ≠ 0**. Probe **supprimée** après preuve — répertoire propre vérifié (`ls _ephemeral*` → aucun fichier ; `git status` ne montre que les 2 fichiers de corpus attendus). C'est la reproduction indépendante de la procédure T4/AC5 consignée dans la story.

---

## Résultats de vérification RÉELLEMENT rejoués sur disque

| Contrôle | Résultat |
|---|---|
| `dart test --tags serialization-compat` (zcrud_generator) | **RC = 0** — **52 tests** `serialization-compat` exécutés (50 corpus + 2 amorce E2-5) ✅ |
| `dart run scripts/ci/verify_serialization.dart` | **RC = 0** — `zcrud_generator (runner: dart)` exécute **52 tests** ; autres packages `exit 79` (no tests) toléré ✅ |
| `melos run analyze` | **RC = 0** — SUCCESS / 14 pkgs, `dart analyze .` ✅ |
| `melos run test` | **RC = 0** — generator **80**, core **198**, get **17**, provider **8**, riverpod **8**, annotations **8** ✅ |
| `melos run verify` | **RC = 0** (agrégat des gates) ✅ |
| `dart run scripts/ci/prove_gates.dart` | **RC = 0** — **22 OK / 0 FAIL** ✅ |
| `scripts/dev/graph_proof.py` | **CORE OUT = 0**, 14 nœuds, 17 arêtes, **ACYCLIQUE OK** ✅ |
| `melos list` | **14** ✅ |
| `.g.dart` suivis par git | **0** (`article.g.dart` gitignoré confirmé via `git check-ignore`) ✅ |
| Probe éphémère nettoyée | **Oui** — 0 résidu, working tree = 2 fichiers corpus attendus ✅ |

---

## Couverture des Acceptance Criteria

| AC | Statut | Preuve |
|----|--------|--------|
| **AC1** — corpus des 7 familles (a…g) | ✅ | 20 cas nommés groupés par famille (a:2, b:2, c:1, d:3, e:9, f:2, g:1). Chaque famille a un test d'assertion de repli ciblé (pas seulement `returnsNormally`). |
| **AC2** — invariant « le parent survit » (voie codegen directe) | ✅ | Boucle sur les 20 cas : `expect(() => Article.fromMap(asTopLevelMap(c)), returnsNormally)` + assertions de valeur par famille + `Author.fromMap` seul. |
| **AC3** — voie registre codegen défensive | ✅ | `registerArticle(registry)` puis boucle `registry.decode('article', …)` `returnsNormally` sur les 20 cas + 1 cas décodé (`null_partout` → `title:''`, `status:draft`). |
| **AC4** — tag & branchement gate (no-op → corpus réel) | ✅ | `@Tags(['serialization-compat'])` + `library;` ; slot passe de 2 (amorce) à 52 tests SANS modif du script/workflow. |
| **AC5** — le gate ÉCHOUE sur régression | ✅ | **Reproduit par le reviewer** (voir ci-dessus) : RC=1 avec probe, RC=0 sans. |
| **AC6** — intégré au `verify`/CI de merge | ✅ | `verify_serialization.dart` RC=0, `melos run verify` RC=0, `prove_gates` 22/0. Chaîne verte generate→analyze→test→verify. |
| **AC7** — évolution additive documentée | ✅ | Docstring en tête du corpus (discipline « additif seulement », gate de merge, AD-10) + cas `historique_v_n_champ_ajoute_absent` (compat ascendante) et `futur_v_n1_champ_inconnu_ignore` (compat descendante) étiquetés. |
| **AC8** — MEDIUM-1 (E2-6) tranché & consigné | ✅ (voir LOW-2) | Story §« Décision MEDIUM-1 » + Completion Notes : couvert voie codegen (AC3), déféré voie adaptateur à E5, contrat gelé `ZcrudRegistry` (E2-3) NON modifié. |

---

## Couverture 7 familles × 2 voies (vérifiée cas par cas contre `article.g.dart`)

Chaque fixture confrontée au comportement RÉEL des helpers générés (`_$asInt/_$asDouble/_$enumFromName/_$asStringMap/_$decodeModel`) :

| Famille | Cas | Repli attendu | Conforme `.g.dart` |
|---|---|---|---|
| (a) historiques | `historique_v_n_champ_ajoute_absent`, `historique_scalaires_absents` | `views→0, rating→0.0, published→false, status→draft, tags→[], author→null, coauthors→[], createdAt→null` | ✅ |
| (b) tronqués | `tronque_toplevel_et_sous_objet_vide`, `sous_objet_author_sans_name` | `author:{}→Author('')` (défensif, PAS null), coauthors non-Map filtrés → len 1 | ✅ (voir LOW-1) |
| (c) champs inconnus | `futur_v_n1_champ_inconnu_ignore` | clés futures ignorées, `views→5` décodé | ✅ |
| (d) enums inconnus | `enum_legacy_retire`, `enum_futur`, `enum_non_string` | `status→draft` (`_$enumFromName→null ?? draft`) | ✅ |
| (e) types faux | 9 cas (`'abc'→0`, `'42'→42`, `'3.5'→3.5`, `'x'→0.0`, `tags:{}→[]`, `coauthors:{}→[]`, `1→false`, `author:'x'→null`, `['a',7,null,'b']→['a','b']`) | coercition douce + repli | ✅ |
| (f) clés non-String (H1) | `author_cles_int_hive`, `author_cles_mixtes_avec_name` | `_$asStringMap` coerce sans throw ; `name` préservé malgré clé int | ✅ |
| (g) null partout | `null_partout` | `title→''`, tous les autres → repli | ✅ |

Les DEUX voies (`Article.fromMap` direct ET `registry.decode('article', …)`) itèrent la **même** source de vérité `serializationCorpus` → un cas cassant casserait mécaniquement les deux voies. **Aucune ligne de `_$ArticleFromMap`/`_$AuthorFromMap` ne peut throw sur entrée corrompue** (gardes `is String/bool/List` + helpers avec try/catch internes) : confirmé par lecture ligne à ligne du `.g.dart` régénéré. **0 famille où le parent casse.**

---

## Triage des findings

### HIGH — aucun
Le gate capte la régression (prouvé) ; le parent survit sur les 7 familles × 2 voies (prouvé). Ni gate décoratif, ni parent qui casse.

### MAJEUR — aucun

### MEDIUM — aucun

### LOW (optionnels — répertoriés, non bloquants)

**LOW-1 — Divergence texte AC1(b) ↔ comportement réel (documentée, non corrigée dans le texte de l'AC).**
`serialization_corpus.dart` / `serialization_corpus_test.dart` — AC1(b) écrit littéralement `author:{}` → « `name` requis manquant → `_$decodeModel` capte → `author == null` ». Le comportement RÉEL du codegen E2-5 est `author:{}` → `Author(name:'')` (le `_$AuthorFromMap` du sous-modèle est lui-même défensif et ne lève pas). Le test asserte correctement le comportement réel (`author != null`, `author.name == ''`) et la Completion Note (1) tranche explicitement l'ambiguïté. **L'invariant AD-10 (parent survit) tient dans les deux lectures** — c'est un décalage de TEXTE d'AC, pas un défaut. *Reco* : amender le libellé d'AC1(b) pour refléter `Author('')` (idem AC1(b) « coauthors élément tronqué filtré » : un élément **Map vide** est CONSERVÉ en `Author('')`, seuls les **non-Map** sont filtrés — Completion Note (3)).

**LOW-2 — MEDIUM-1 (E2-6) déféré à E5 : hand-off à garantir hors de cette story.**
La coupe est architecturalement saine (la voie adaptateur `JsonSerializableAdapter`/`ReflectableCodec` enregistre un `fromMap` STRICT pouvant throw ; la corriger touche le contrat gelé `ZcrudRegistry` E2-3 et la frontière repository E5) et bien consignée dans la story. **Risque résiduel** : le report « frontière défensive AD-10 pour modèles adaptateur (`decodeSafe(kind,map)` additif OU rétention d'adaptateur pour `fromMapSafe` + test docs Firestore corrompus) » n'est traçable QUE dans cette story. *Reco (action orchestrateur)* : injecter ce report au `create-story` d'E5 pour qu'il ne se perde pas — le gap AD-10 côté adaptateur reste ouvert jusque-là.

**LOW-3 — Voie registre : assertions de repli par famille non répétées (couverture par délégation).**
`serialization_corpus_test.dart` (groupe registre) n'asserte `returnsNormally` sur les 20 cas + une seule valeur décodée (`null_partout`). AC3 est littéralement satisfait, et `registry.decode` délègue au **même** `_$ArticleFromMap` que la voie directe (répéter les valeurs par famille serait redondant). *Reco (nit)* : acceptable en l'état ; si l'on voulait blinder contre une future divergence registre/direct, ajouter 1–2 assertions de valeur côté registre.

**LOW-4 — Trous de couverture marginaux (safe par construction, non testés).**
Cas non présents au corpus, tous couverts par le `.g.dart` défensif donc sans risque : (a) élément de LISTE `coauthors` à **clés non-String** ou dont le sous-`fromMap` throw (famille f appliquée à la liste — seul `author` singulier est testé pour f ; géré par `_$decodeModel`+try/catch) ; (b) `created_at` corrompu (String non-parseable / type faux `int` → `_$asDateTime→null`) — la voie DateTime n'a aucun cas corrompu au corpus. *Reco (nit)* : 2 fixtures additionnelles fermeraient ces angles ; non bloquant (repli prouvé par lecture du helper).

---

## Notes de cohérence (observations, pas des findings)

- **Comptage** : la Completion Note annonce « 21 fixtures » ; le décompte réel est **20** (`grep -c family:` = 20 ; a:2,b:2,c:1,d:3,e:9,f:2,g:1 = 20). Le nombre de tests annoncé (« 52 ») est en revanche **exact** (50 corpus + 2 amorce). Simple erreur d'arithmétique dans la note, sans impact.
- **AD-1/AD-3** : fixtures cantonnées à `zcrud_generator/test/` ; import de la surface **pure** `package:zcrud_core/edition.dart` (aucun Flutter, runner `dart`) ; zéro `reflectable`. CORE OUT=0 préservé.
- **Amorce E2-5** conservée telle quelle (non dupliquée), toujours taggée — cohérente avec le corpus.
- **Contrat gelé E2-3** (`ZcrudRegistry.decode`) non modifié ; `article.g.dart` régénéré (jamais édité/committé, gitignoré).

---

## Conclusion

Story **E2-10 APPROVED**. Le slot `verify:serialization` est transformé d'amorce (2 tests) en **corpus réel exécuté à chaque merge (52 tests)**, la garantie AD-10 « le parent ne casse jamais » est **prouvée en continu sur 7 familles × 2 voies**, et le caractère **non-décoratif du gate est reproduit indépendamment** (RC=1 avec régression / RC=0 sans). Les 4 LOW sont optionnels : LOW-1 (amender le texte des AC), LOW-2 (garantir le hand-off E5 côté orchestrateur), LOW-3/LOW-4 (durcissements de couverture facultatifs). Aucun blocage avant `done`.
