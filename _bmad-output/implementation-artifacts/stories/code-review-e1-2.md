# Code Review — Story E1-2 : Squelettes de packages avec API/barrel

- **Skill invoqué** : `bmad-code-review` (via le tool `Skill`, `args: "review E1-2"`) — step-file architecture (`steps/step-01…03`). Workflow résolu via `resolve_customization.py` (RC=0).
- **Story** : `_bmad-output/implementation-artifacts/stories/e1-2-squelettes-packages-api-barrel.md` (10 ACs, statut `review`).
- **Baseline** : `baseline_commit = 8f28755` (= HEAD). Le diff est constitué de fichiers **untracked** (`packages/`, `scripts/dev/graph_proof.py`, root `pubspec.yaml`/`melos.yaml` déjà posés en E1-1).
- **Mode** : `full` (spec fournie ⇒ Acceptance Auditor actif).
- **Grounding** : `architecture.md` (AD-1 graphe mermaid + règle du puits ; AD-14 ; AD-15), `CLAUDE.md` (Key Don'ts, conventions barrel/src).
- **Date** : 2026-07-09.

---

## Verdict global : **APPROVED**

Les 10 ACs sont satisfaits et **rejoués réellement sur disque**. Le graphe déclaré est **exactement** conforme au mermaid AD-1 (17 arêtes, ni parasite ni manquante), le cœur est un **puits isolé** (out-degree 0, aucune dep lourde/manager), les 14 barrels sont propres, l'analyse est verte 14/14, et la non-régression E1-1 tient. **Aucun finding HIGH/MAJEUR ni MEDIUM.** Trois findings **LOW/doc-robustesse** (recettes de test de la story encore buggées + angle mort du script sur `dev_dependencies`), non bloquants.

### Décompte findings

| Sévérité | Nombre |
| --- | --- |
| HIGH / MAJEUR | **0** |
| MEDIUM | **0** |
| LOW / nit | **3** |

---

## Preuve d'acyclicité rejouée réellement (AC 7)

`python3 scripts/dev/graph_proof.py` → **RC=0** :

```
total arêtes = 17
out-degree(zcrud_core) = 0
noeuds = 14, triés = 14
ACYCLIQUE OK
CORE OUT=0 OK
```

**17 arêtes extraites, identiques à l'ensemble mermaid AD-1** (relu lignes 36–54 de `architecture.md`) — vérification une-à-une :

| Arête | Mermaid AD-1 | Pubspec | OK |
| --- | --- | --- | --- |
| annotations → core | ✅ | ✅ | ✅ |
| generator → annotations | ✅ | ✅ | ✅ |
| generator → core | ✅ | ✅ | ✅ |
| markdown → core | ✅ | ✅ | ✅ |
| list → core | ✅ | ✅ | ✅ |
| mindmap → core | ✅ | ✅ | ✅ |
| mindmap → markdown | ✅ | ✅ | ✅ |
| flashcard → core | ✅ | ✅ | ✅ |
| flashcard → markdown | ✅ | ✅ | ✅ |
| flashcard → export | ✅ | ✅ | ✅ |
| firestore → core | ✅ | ✅ | ✅ |
| geo → core | ✅ | ✅ | ✅ |
| intl → core | ✅ | ✅ | ✅ |
| export → core | ✅ | ✅ | ✅ |
| riverpod → core | ✅ | ✅ | ✅ |
| get → core | ✅ | ✅ | ✅ |
| provider → core | ✅ | ✅ | ✅ |

Aucune arête entrante sur `zcrud_core`. Tri topologique de Kahn : 14/14 nœuds ordonnés ⇒ **acyclique**. Les 3 arêtes de composition (mm→md, fc→md, fc→exp) sont **tout-interne `zcrud_*`**, figurent au mermaid, et sont **réellement utilisées** (imports + référence des marqueurs `Z*Api.version`) ⇒ pas de dépendance déclarée-inutilisée ni de `depend_on_referenced_packages`.

> Note harnais : ma variante ad-hoc `edges | tsort` a échoué (« nombre impair de jetons ») à cause de **mon** awk d'appoint, pas du script livré. Le script retenu `graph_proof.py` — seul committé et seul faisant foi — est correct et robuste (gestion de l'indentation, fermeture du bloc sur clé top-level, Kahn, assertion out-degree, exit≠0 sur échec).

## Autres vérifications vertes rejouées

| Contrôle | Attendu | Réel |
| --- | --- | --- |
| `dart pub get` (racine) | RC=0 | **RC=0** |
| `dart run melos run analyze` | SUCCESS (14) | **RC=0, SUCCESS 14/14** |
| `dart analyze` par package | RC=0 ×14 | **14/14 « No issues found! »** |
| `melos list` | 14 | **14** |
| `pubspec.lock` | 1 racine, 0 par-package | **1 / 0** |
| `sdk: ^3.12.2` | 14/14 | **14** |
| `resolution: workspace` | 14/14 | **14** |
| Backbone satellites → core | 13 | **13** |
| Cœur : arêtes `zcrud_*` | 0 | **0** (pas de bloc `dependencies:`) |
| Dep lourde/manager (bloc deps) | aucune | **aucune** (hits `grep` uniquement dans `description:`) |
| Barrels exportant `src/` | 14 | **14** |
| Impl inline dans un barrel | 0 | **0** (seulement `library;` + doc + `export 'src/…'`) |
| `.gitignore` codegen | présent | **`*.g.dart` / `*.freezed.dart` OK** |
| `*.g.dart`/`*.freezed.dart` committés | 0 | **aucun** |

Isolation cœur (AC 5) confirmée par lecture directe : `packages/zcrud_core/pubspec.yaml` **n'a aucun bloc `dependencies:`** ⇒ ni Firebase/Syncfusion/Quill/Maps/Hive, ni riverpod/get/provider. Placeholders **pur-Dart** partout (aucun `flutter: sdk: flutter` ajouté) ⇒ `dart analyze` sans Flutter reste vert (conforme AD-14).

---

## Findings

### LOW / doc

**L-1 — La recette AC 1 de la « Stratégie de tests » produit des faux positifs sur les barrels réels.**
- **Fichier** : `e1-2-squelettes-packages-api-barrel.md:203-206` (§ Stratégie de tests, point 1).
- **Problème** : le motif d'exclusion `^\s*(//|/\*|\*|library |export )` attend `library ` (avec **espace final**), alors que les 14 barrels utilisent la forme `library;` (point-virgule). Rejouée verbatim, la commande imprime `library;` puis `IMPL DANS BARREL: <barrel>` pour **les 14 packages** — faux positif. Les barrels sont en réalité **propres** (vérifié : uniquement doc + `library;` + `export 'src/…';`). Même classe de bug que l'awk §7 et la regex SDK §9 déjà repérés par le dev.
- **Correctif** : remplacer `library ` par `library;?` (ou `library\b`) dans le motif, ou renvoyer vers `graph_proof.py`/un contrôle dédié. La conformité réelle de l'AC 1 n'est **pas** en cause.

**L-2 — Les recettes buggées §7 (awk) et §9 (regex SDK) subsistent dans le corps de la story.**
- **Fichier** : `e1-2-squelettes-packages-api-barrel.md:238-248` (awk `gsub` vidant la ligne → « ACYCLIQUE OK » sur graphe vide) et `:261` (`grep -rl 'sdk: ..3.12.2'` — deux jokers ne matchant pas `^3.12.2`).
- **Problème** : le dev a **correctement** diagnostiqué ces deux bugs (Debug Log References, l.292) et fourni `graph_proof.py` en remplacement fonctionnel de §7, mais le **markdown de la Stratégie de tests n'a pas été amendé** : un lecteur futur qui exécute §7/§9 verbatim obtient une preuve d'acyclicité **faussement verte** (graphe vide) et un décompte SDK erroné. Le script retenu (`graph_proof.py`) est, lui, correct.
- **Correctif** : ajouter une bannière « superseded → `scripts/dev/graph_proof.py` » sur §7 et corriger §9 en `sdk: \^3\.12\.2` (comme fait dans les Debug Log References), pour que la story reste une source de repro fiable.

**L-3 — `graph_proof.py` n'inspecte que `dependencies:` (angle mort `dev_dependencies:` / `dependency_overrides:`).**
- **Fichier** : `scripts/dev/graph_proof.py:20` (`re.match(r"^dependencies:\s*$", raw)`).
- **Problème** : la preuve AD-1 destinée à être **reproductible et réutilisée** (FR-24, futur garde-fou CI E1-3) ne scanne que le bloc `dependencies:`. Pour le graphe **actuel**, toutes les arêtes `zcrud_*` sont des deps runtime (y compris `generator → annotations/core`) ⇒ **correct aujourd'hui, aucun impact**. Mais une future arête `zcrud_*` placée sous `dev_dependencies:` (usage naturel pour un build tool) serait **silencieusement omise** du graphe ⇒ risque de faux « ACYCLIQUE OK ».
- **Correctif (optionnel, robustesse)** : étendre l'ouverture de bloc à `dev_dependencies:`/`dependency_overrides:`, ou documenter explicitement le périmètre du script. À traiter au plus tard lors du durcissement CI (E1-3).

---

## Auditeurs (synthèse)

- **Acceptance Auditor (spec E1-2)** : 10/10 ACs satisfaits — barrels (AC1-2), backbone 13 (AC3), generator→annotations + 3 arêtes de composition déclarées et conformes (AC4), cœur isolé (AC5), aucune dep lourde globale (AC6), acyclicité + out-degree 0 rejoués (AC7), compilation 14/14 (AC8), non-régression workspace (AC9), hygiène codegen (AC10). Décisions du dev (composition déclarée, résolution par version `^0.0.1`, placeholders pur-Dart) justifiées et cohérentes avec la story.
- **Blind Hunter (adversarial général)** : idiome `abstract final class … { const _(); static const version }` valide en Dart 3, sans instance, sans lint (analyze vert). Imports croisés ⇔ deps déclarées ⇒ pas d'import mort. Aucun secret, aucune dep lourde, aucun manager, aucune fuite backend. RAS bloquant.
- **Edge Case Hunter** : angle mort `dev_dependencies` du script (L-3) ; recettes de test buggées non amendées (L-1, L-2). Aucun cycle, aucune arête parasite/manquante ; cœur puits confirmé.

---

## Conclusion

**APPROVED.** Story prête à passer `done` (après application/justification des LOW au gré de l'orchestrateur — tous non bloquants et hors chemin critique, la substance E1-2 étant intégralement verte). Recommandation : corriger L-1/L-2 (édition doc triviale de la Stratégie de tests) tant que la story est ouverte ; consigner L-3 pour E1-3.
