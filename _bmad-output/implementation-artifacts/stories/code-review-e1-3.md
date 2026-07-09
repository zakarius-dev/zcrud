# Code Review — E1-3 : Lint, analyse, build_runner & gates CI (SM-6)

- **Story** : `_bmad-output/implementation-artifacts/stories/e1-3-lint-analyse-build-runner-gates-ci.md` (11 ACs, statut `review`)
- **Baseline** : `8f28755` (HEAD ; tout l'arbre est untracked par rapport à ce commit — diff = fichiers listés ci-dessous)
- **Skill invoqué** : `bmad-code-review` (tool `Skill`, chemin réel `.claude/skills/bmad-code-review/`), workflow step-01/02 suivi ; revue conduite en session (Blind Hunter + Edge Case Hunter + Acceptance Auditor fusionnés, subagents indisponibles → exécutés en session au même niveau de modèle).
- **Modèle** : claude-opus-4-8. **Date** : 2026-07-09.
- **Verdict** : **CHANGES REQUESTED** — 1 HIGH/MAJEUR, 3 MEDIUM, 4 LOW/nit.

Périmètre revu : `analysis_options.yaml` (racine) + 14 `packages/*/analysis_options.yaml`, `.github/workflows/ci.yml`, `.gitleaks.toml`, `scripts/ci/{gate_reflectable,gate_secret_scan,gate_codegen,gate_melos_divergence,verify_serialization,prove_gates}.dart`, `scripts/dev/graph_proof.py`, blocs `melos:`/`scripts:` de `pubspec.yaml` et `melos.yaml`.

---

## Preuves rejouées réellement sur disque

| Vérification | Commande | Résultat réel |
|---|---|---|
| Harnais fixtures dev | `dart run scripts/ci/prove_gates.dart` | **13 OK / 0 FAIL**, RC=0 ✅ (conforme au rapport dev) |
| Orchestrateur local | `dart run melos run verify` | RC=0 ✅ (graph 17 arêtes, melos OK, reflectable OK, secrets OK, codegen OK, slot E2-10 no-op vert) |
| Analyse | `dart run melos run analyze` | RC=0, 14/14 « No issues found » ✅ |
| Non-régression E1-1/E1-2 | `melos list` / lockfile / analysis_options / `.g.dart` | 14 membres, **1** `pubspec.lock` racine, 14 `analysis_options.yaml`, **0** `.g.dart` committé ✅ |
| M-1 robustesse | fixtures maison (whitespace / description) | whitespace insignifiant toléré (exit=0), divergence de `description` **détectée** (exit=1) ✅ **sémantiquement robuste** |

**Les gates fonctionnent sur les cas prévus.** Les findings ci-dessous portent sur des **variantes de violation que les gates LAISSENT PASSER** (faux négatifs), reproduites par fixtures **de mon cru**.

---

## HIGH / MAJEUR

### H-1 — Le gate secrets ne détecte PAS la seule forme réelle de `badCertificateCallback` (AD-12 quasi non gardé)
- **Fichier** : `scripts/ci/gate_secret_scan.dart:29` — `RegExp(r'badCertificateCallback\s*=>\s*true')`
- **Angle mort** : le motif exige `badCertificateCallback` **immédiatement** suivi de `=> true`. Or l'unique forme valide en Dart est une **affectation** :
  ```dart
  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  ```
  Entre `badCertificateCallback` et `=> true` il y a `= (cert, host, port) `, qui n'est **pas** `\s*`. Le motif ne matche donc que le littéral `badCertificateCallback => true` — une syntaxe **qui ne peut pas exister** dans du vrai code. La forme dangereuse réelle passe **verte**.
- **Fixture maison (reproduite)** : fichier `net.dart` avec l'affectation idiomatique → `gate:secrets OK`, **exit=0** (non détecté). Contrôle : le littéral `badCertificateCallback => true` → exit=1.
- **Aggravant** : gitleaks (autorité CI) n'a **aucune** règle par défaut pour ce motif Dart-spécifique → l'invariant AD-12 « `badCertificateCallback => true` interdit » (CLAUDE.md Key-Don'ts, Dev Notes AD-12) est **effectivement non gardé** en CI. Le seul filet est ce repli local, qui rate la forme réelle.
- **Aggravant²** : la « preuve » `prove_gates.dart:63` (`secrets/fixture-badCert`) utilise justement le **littéral impossible** `badCertificateCallback => true`, donnant un **faux sentiment de couverture** (AC 5 + AC 10 « prouvé »).
- **Correctif** : élargir le motif à la forme d'affectation, ex. `RegExp(r'badCertificateCallback\s*=\s*\(?[^;{]*=>\s*true')` (ou détecter `badCertificateCallback` + `=> true` sur la même instruction / multilignes), **et** remplacer la fixture `prove_gates.dart` par la forme d'affectation réelle. Ajouter éventuellement une règle gitleaks custom (`[[rules]]`) dans `.gitleaks.toml` pour couvrir aussi l'historique.
- **Sévérité** : gate de **sécurité** (AD-12), faux négatif sur la forme **canonique** et **triviale** à écrire → HIGH/MAJEUR. **Correction obligatoire avant `done`** (CLAUDE.md).

---

## MEDIUM

### M-1 — Allowlist reflectable basename-only : bypass AD-3 depuis N'IMPORTE quel package (y compris le cœur)
- **Fichier** : `scripts/ci/gate_reflectable.dart:19-22` — `_isAllowlisted` : `p.endsWith('/reflectable_codec.dart') || p.endsWith('reflectable_codec.dart')`
- **Angle mort** : l'allowlist est purement **par nom de fichier**, non scopée à un package/chemin. **Tout** fichier nommé `reflectable_codec.dart`, y compris `packages/zcrud_core/lib/src/reflectable_codec.dart` (cœur du moteur), peut importer `package:reflectable` et déclarer `@Reflector()` **sans faire échouer le gate**. Or AD-3 réserve l'exception au **seul** adaptateur `ReflectableCodec` DODLP (E2-6/E7), pas au cœur.
- **Fixture maison (reproduite)** : `--root` avec `zcrud_core/lib/src/reflectable_codec.dart` important reflectable + `@Reflector()` → `gate:reflectable OK`, **exit=0** (bypass confirmé).
- **Correctif** : ancrer l'allowlist au **chemin exact** de l'adaptateur cible (ex. package d'adaptateur DODLP dédié, ou `packages/<adapter>/lib/src/data/codecs/reflectable_codec.dart`), pas au basename. Documenter le chemin unique dans le gate.
- **Sévérité** : faux négatif d'un gate d'invariant d'architecture, déclenchable par un simple choix de nom de fichier → MEDIUM. **À corriger dans le périmètre** (CLAUDE.md MEDIUM par défaut).

### M-2 — Repli local du scan secrets aveugle hors d'un jeu d'extensions figé
- **Fichier** : `scripts/ci/gate_secret_scan.dart:33` — `_scanExtensions = {'.dart','.yaml','.yml','.json','.env','.sh','.toml'}`
- **Angle mort** : une clé `AIza…` (ou AWS/PEM/token) committée dans un fichier d'**autre extension** — `.txt`, `.properties`, `.gradle`, `.xml`, `.plist`, `.pem`/`.key`, `Dockerfile`, ou **sans extension** (`credentials`, `id_rsa`) — n'est **pas** scannée par le repli local, donc invisible pour `melos run verify` **et** pour l'étape CI `gate_secret_scan.dart`.
- **Fixture maison (reproduite)** : même clé `AIza`+35 dans `secrets.txt` / `local.properties` / `credentials` → `gate:secrets OK`, **exit=0**. Contrôle `.dart` → exit=1.
- **Mitigation** : gitleaks (autorité CI, `useDefault=true`) scanne **tous** les fichiers et **bloque** le merge (pas de `continue-on-error`) → le gate de merge reste couvert en CI. Le trou concerne le **pré-vol local** (dev hors réseau) et l'étape repli, qui donnent un faux « OK ».
- **Correctif** : soit scanner par défaut **tous** les fichiers texte (détection binaire déjà gérée par le `try/catch FileSystemException`) avec une denylist de répertoires, soit élargir sensiblement `_scanExtensions` (`.txt .properties .xml .gradle .plist .pem .key .cfg .ini .dockerfile` + fichiers sans extension). Aligner sur la couverture gitleaks pour supprimer l'écart repli↔autorité.
- **Sévérité** : MEDIUM (mitigé en CI par gitleaks, mais faux « vert » local trompeur sur un gate de sécurité).

### M-3 — Gate reflectable ne scanne que `/lib/` : `bin/`, `tool/`, `test/`, `example/` non couverts
- **Fichier** : `scripts/ci/gate_reflectable.dart:46` — `if (root == 'packages' && !norm.contains('/lib/')) continue;`
- **Angle mort** : sur l'arbre réel, seul le code sous `packages/*/lib/**` est scanné. Un `import 'package:reflectable/...'` + `@Reflector()` dans `packages/zcrud_core/bin/…`, `tool/…`, `test/…` ou `example/…` passe **vert**, alors que l'AC 4 vise « un fichier Dart d'un package moteur ».
- **Fixture maison (reproduite)** : `packages/zcrud_core/bin/probe_tool.dart` important reflectable → `gate:reflectable OK`, **exit=0** (non détecté).
- **Correctif** : scanner tout `.dart` du package (ou au moins `lib/` + `bin/` + `tool/`), en conservant l'exclusion `.g.dart` et l'allowlist (corrigée M-1). Impact moindre que `lib/` (code non publié) mais contredit l'intention « moteur ».
- **Sévérité** : MEDIUM (bas de fourchette) — faux négatif d'un gate d'invariant, chemin d'exploitation plus étroit.

---

## LOW / nit

### L-1 — Gate codegen : `@ZcrudModel` aliasé / non en début de ligne non détecté ; clause AC 6 « .g.dart obsolète » non implémentée
- **Fichier** : `scripts/ci/gate_codegen.dart:19` — `RegExp(r'^\s*@ZcrudModel\b', multiLine: true)`
- Un modèle annoté via **préfixe d'import** (`import '…' as z; @z.ZcrudModel()`) ou une annotation non ancrée en début de ligne n'est pas comptée → orphelin `.g.dart` manquant non détecté. **Fixture reproduite** : `@z.ZcrudModel()` sans `.g.dart` → exit=0. Impact réel **différé** (annotations = E2-4, convention documentée = `@ZcrudModel` nu), mais à durcir quand E2-4 arrive.
- La clause AC 6 « ou si l'arbre présente un `.g.dart` obsolète/divergent après régénération (`git diff` non vide) » **n'est pas implémentée**. Note : elle est de toute façon **incohérente** avec `.g.dart` gitignoré (rien de généré n'est suivi par git) — la vérification par présence-post-codegen retenue est le bon compromis. À clarifier/rectifier dans l'AC lors d'E2-5.

### L-2 — `graph_proof.py` durci (L-3) : sur-strict sur `dev_dependencies` + fail sur graphe sans arête
- **Fichier** : `scripts/dev/graph_proof.py:24,86`
- Les arêtes `dev_dependencies:` comptent désormais **à l'identique** des arêtes runtime dans `out-degree(zcrud_core)` et la détection de cycle. Un futur **dev-dependency légitime** d'un package zcrud sur `zcrud_core` (util de test) ferait **échouer** le gate (faux positif : `CORE OUT>0`), et un cycle **dev-only** (non transitif, inoffensif) est traité comme fatal. Le durcissement L-3 gagne des faux positifs — envisager de distinguer arêtes runtime (out-degree cœur, strict) et dev/override (cycle uniquement).
- `ok = … and len(edges) > 0` (L86) : un arbre légitimement **sans** arête zcrud échouerait (RC=1). Garde-fou « scanner a trouvé quelque chose » assumé, mais fragile si le périmètre évolue.

### L-3 — Étape CI gitleaks sans `GITHUB_TOKEN`
- **Fichier** : `.github/workflows/ci.yml:65-68`
- `gitleaks/gitleaks-action@v2` documente le besoin de `env: GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}` (et, pour une org, `GITLEAKS_LICENSE`). Seul `GITLEAKS_CONFIG` est fourni. Selon l'événement/visibilité du dépôt, l'action peut échouer ou ne pas commenter. À vérifier/wire pour que **l'autorité** du scan (mitigation de M-1/M-2) soit effective.

### L-4 — `graph_proof.py` : dépendance `path:` renommée non détectée (informational)
- L'EDGE key sur le **nom** de dépendance `zcrud_*`. Une arête `alias: { path: ../zcrud_core }` échapperait au scan — **mais** pub interdit un nom de package divergent du pubspec pointé, donc **non exploitable** en pratique. Consigné pour complétude (point de vigilance de la tâche : « arête via `path:` sans nom »).

---

## Points de vigilance vérifiés — CONFORMES (pas de finding)

- **M-1 (anti-divergence melos)** : comparaison **sémantique** (parse YAML + canonicalisation triée de tout le sous-arbre normalisé de chaque script). **Robuste** à l'ordre et au whitespace insignifiant ; détecte une divergence de `run`/`exec`/`description`/`packageFilters`/toute clé (pas d'angle mort « champ non couvert »). Fixtures maison confirmées.
- **CI `ci.yml`** : ordre **codegen → analyze → test → gates → slot E2-10** respecté (AC 3) ; **aucun** `continue-on-error` → toutes les étapes sont **bloquantes** ; slot E2-10 = **no-op vert wiré** (`verify:serialization`, auto-découverte tag `serialization-compat`), documenté — **pas un trou** ; `fetch-depth: 0` présent pour gitleaks/historique.
- **Baseline lint** : `package:lints/recommended.yaml` pur-Dart, `lints`/`yaml` en dev_deps racine uniquement ; **ne tire pas Flutter** ; `include: ../../analysis_options.yaml` relatif ×14 ; `analyzer.exclude` couvre `*.g.dart`/`*.freezed.dart`/fixtures ; `melos run analyze` **14/14 RC=0** (non-régression E1-2 OK).
- **Non-régression E1-1/E1-2** : 14 membres, 1 lockfile racine, `resolution: workspace`, backbone/arêtes AD-1 = **17** inchangé, 0 `.g.dart` committé.
- **Secret scan auto-exclusion** : `gate_secret_scan.dart` + `prove_gates.dart` + `scripts/ci/fixtures/**` exclus, cohérent avec l'allowlist `.gitleaks.toml` — pas de faux positif sur les définitions de motifs / harnais.
- **Fixtures inertes** : `prove_gates.dart` crée/détruit des fixtures éphémères en `systemTemp` ; aucune fixture de violation committée.

---

## Synthèse & décision

| Sévérité | # | IDs |
|---|---|---|
| HIGH/MAJEUR | 1 | H-1 |
| MEDIUM | 3 | M-1, M-2, M-3 |
| LOW/nit | 4 | L-1, L-2, L-3, L-4 |

**Verdict : CHANGES REQUESTED.**

Bloquant `done` (CLAUDE.md) :
- **H-1** (MAJEUR) — **correction obligatoire** : le gate AD-12 rate la forme réelle de `badCertificateCallback`, et sa fixture de preuve masque le trou.
- **M-1, M-2, M-3** (MEDIUM) — **correction par défaut** dans le périmètre (faux négatifs de gates d'invariant/sécurité, tous reproduits par fixture) ; tout MEDIUM reporté doit être **justifié par écrit** ici.

Les LOW sont optionnels (L-1/L-2 à revisiter en E2 ; L-3 recommandé pour l'efficacité de l'autorité gitleaks ; L-4 informational).

Le socle est solide et les 13 preuves dev sont authentiques ; les corrections visent la **robustesse adversariale** des gates (attraper les *variantes* de violation), qui est l'objet même de la story (« chaque gate prouvé échoue sur violation »).
