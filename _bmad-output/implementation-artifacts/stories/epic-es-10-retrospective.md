# Rétrospective — Epic ES-10 (Binding Riverpod : providers `zcrud_riverpod` + intégration lex_douane, surface zcrud-side)

> Skill réel : **`bmad-retrospective`** (tool `Skill`, workflow step-file chargé et suivi). Rétro autonome (subagent non-interactif) : le format party-mode conversationnel du skill est transposé en synthèse écrite, la substance (Epic Review + Next Epic Preparation + action items + readiness + détection de changement significatif) est intégralement traitée sur les **artefacts réels lus sur disque** (2 stories + 2 code-reviews + architecture § Deferred DW-ES102-1/2, DW-ES94-1 + rétros ES-6..ES-9 / R20..R27). Aucune reconstitution de mémoire.
> `sprint-status.yaml` **NON touché** (ressort de l'orchestrateur).

## 1. Résumé de l'epic

**ES-10 — Binding Riverpod pour lex_douane.** ES-10 est le **1er binding livré** : il ne construit aucune entité, il **agrège l'étage study** (fan-in) et le projette sous Riverpod, sans qu'aucun package du cœur/kernel ne connaisse Riverpod (AD-2/AD-15). 2 stories, **toutes DONE**. Chaîne **SÉQUENTIELLE STRICTE** (10.2 dépend du binding posé en 10.1, mute le workspace — une seule en vol).

| Story | Taille | Package(s) écrit(s) | Livrable | Δ arêtes graphe | Verdict code-review |
|-------|--------|---------------------|----------|-----------------|---------------------|
| **ES-10.1** Providers Riverpod + égalité profonde config au binding | L | `zcrud_riverpod` | fabrique générique `zStudyWatchAllProvider<T>` (seam `zStudyRepositoryProvider<T>` throw) + `ZSessionConfigKey` (égalité profonde AU BINDING, AD-24) + `zStudySessionSelectorProvider` (family clée par égalité profonde) + **SM-1 prouvé exécutablement** | **44 → 45 (+1** = `zcrud_riverpod → zcrud_study_kernel`, SORTANTE) | ✅ **APPROVED** — **0 HIGH / 0 MAJEUR / 0 MEDIUM**, 3 LOW consignés |
| **ES-10.2** Intégration lex repo-par-repo (surface zcrud-side) | M | `zcrud_firestore` (+ garde d'isolation `zcrud_riverpod`) | adapter firestore **folder-scopé générique-par-topologie** `buildFolderScopedStudyRepository<T>` (compose ES-3, retour `ZStudyRepository<T>` neutre) ; providers concrets **RETIRÉS → app-side** (Option B) | **49 → 45 (Δ 0** après révision : le binding reste générique, aucune arête d'entité) | ✅ **APPROVED** — 0 HIGH / 0 MAJEUR, **1 MEDIUM corrigé**, 2 LOW |

**Vérif verte finale (rejouée sur disque, RC hors pipe R15, runner `flutter test` R14)** — état à la clôture d'ES-10.2 :
- `flutter test packages/zcrud_riverpod` → **25 tests, RC=0** ; `flutter test packages/zcrud_firestore` → **176 tests, RC=0**.
- `dart run melos run verify` **REPO-WIDE** → **RC=0** (`gate:reserved-keys OK`, `gate:secrets OK`, `gate:web OK`, `codegen-distribution OK`, `verify:serialization OK`) — **frontière EX-3 respectée, `example/` résout**.
- `python3 scripts/dev/graph_proof.py` → **45 arêtes, 20 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** ; arêtes du binding = `→ zcrud_core`, `→ zcrud_study_kernel` **seulement** (aucune arête binding→entité ni binding→firestore).
- `dart run melos list` → **20 packages**.

Bilan findings de l'epic : **0 HIGH · 0 MAJEUR · 1 MEDIUM (corrigé & prouvé discriminant) · 5 LOW** (consignés / 1 hors-périmètre ES-3). Aucune story n'est passée `done` avec un finding bloquant ouvert. **Un événement structurant** : une révision d'architecture majeure en 10.2 (binding couplé à 4 entités → conflit frontière v1.x, attrapé par `melos verify` REPO-WIDE, corrigé en binding générique — cf. §4).

---

## 2. Ce qui a bien marché (spécifique ES-10)

- **ES-10.1 est le cas rare : 0 finding, toutes gardes prouvées POWERFUL d'emblée, R27 appliqué de série.** Le code-review adversarial (mutation testing R3) confirme chaque garde load-bearing sans une seule intervention de rattrapage : SM-1 (objectif produit n°1) rougit `1→2` builds sous keying par identité ; l'égalité par valeur varie **les 7 champs un à un** (`mode`, `folderId`, `tagIds`, `types`, `count`, `extension`, `extra`), jamais « tous à la fois » — leçon ES-9.3 MEDIUM-1 **intériorisée dès l'écriture de la story** (AC2 exige explicitement les 7 cas mono-champ, injections R3-I2a..g). Le seam throw discrimine le **TYPE** `ZScopeError` (pas « throws »), l'auto-dispose rougit sur `onCancel` non appelé. C'est la matérialisation de la question de rétro ES-9 : « comment faire d'ES-9.4 le DÉFAUT, pas l'aboutissement d'une courbe ? » → **ES-10.1 répond : R27 co-conçu dans les ACs de `create-story`.**
- **AD-24 matérialisé proprement : l'égalité de clé de family vit AU BINDING, pas dans le kernel.** Le piège était réel et subtil — le kernel a DÉJÀ un `==` par valeur légitime (forme persistable) ; clef la family directement dessus « marchait ». Le dev a résisté à la tentation : `ZSessionConfigKey` (possédé par `zcrud_riverpod`) porte le contrat de caching Riverpod, le kernel garde son unique `ZStudySessionConfig` **inchangée** (`git status` le prouve). Le domaine ne devient jamais garant d'un contrat Riverpod (couplage inverse interdit, AD-15).
- **SM-1 (objectif produit n°1) prouvé exécutablement AU BINDING.** Deux `ZStudySessionConfig` structurellement égales mais distinctes en mémoire ⇒ **1 seul build** de provider (dédup par `==`/`hashCode` de `ZSessionConfigKey`) ; une config différant d'un champ ⇒ rebuild. Le spot-check orchestrateur (dégrader `==` en `identical` ⇒ compteur `1→2`, RC=1) verrouille la garantie « zéro rebuild inutile » exactement là où le consommateur lex la ressentira.
- **L'adapter firestore (B) est resté GÉNÉRIQUE-PAR-TOPOLOGIE — zéro couplage consommateur.** `buildFolderScopedStudyRepository<T>` compose les briques ES-3 (`ZOfflineFirstBoxRepository` + `nestedUnderParent`) avec `collection`/`parentCollection` en **`String`** — aucun nom lex codé en dur, **aucune arête d'entité** dans `zcrud_firestore`, retour = port neutre `ZStudyRepository<T>`, seul `FirebaseFirestore` en paramètre est une couture backend voulue (AD-5). Le chemin nested est prouvé exact (`users/u1/study_folders/f1/study_documents`) et le `folderId` vide → `Left(DomainFailure)` explicite (AD-10).
- **R9 (orchestrateur rejoue `melos verify` REPO-WIDE) a attrapé le conflit d'architecture le plus grave de l'étage study.** Le fan-in du binding vers `zcrud_flashcard` (entité v1.x interdite par EX-3) n'était visible NI par `graph_proof`, NI par les tests par-package, NI par l'analyze ciblé — **seulement** par `melos verify` repo-wide (échec de résolution `example/` + boundary EX-3). C'est **exactement le cas anticipé par la rétro ES-9 §9** (« un fan-in binding est précisément le cas où une régression cross-package ne se voit QUE repo-wide, cf. incident `ZExportApi` »). La garde a fonctionné avant tout `done`.

---

## 3. Ce qui est à améliorer / points de friction (spécifique ES-10)

- **ES-10.2 : le dev-story initial a franchi une frontière v1.x (le point noir de l'epic — cf. §4).** Le plan de story (issu de `create-story`) prescrivait des **providers TYPÉS par entité DANS le binding** ⇒ 4 arêtes de fan-in vers `zcrud_document`/`zcrud_note`/`zcrud_exam`/`zcrud_flashcard`, cible 49 arêtes. Or `zcrud_flashcard` est une entité **E9 DÉFÉRÉE v1.x**, verrouillée par la frontière **EX-3** (`example/test/boundary_deps_test.dart`). Faire dépendre un **binding réutilisable** d'une entité déférée force tout consommateur (dont `example/`) à la tirer transitivement. **La story elle-même contenait l'erreur** : ce n'est pas un écart du dev par rapport à la story, c'est un défaut de conception qui a traversé `create-story` sans que la frontière v1.x soit vérifiée contre la nouvelle arête de fan-in.
- **MEDIUM-1 (10.2) : la FABRIQUE PUBLIQUE que lex consomme n'était pas testée de façon discriminante.** AC3/AC4 testaient `buildFolderScopedResolver` (helper interne) en isolation ; le test qui instanciait la **fabrique publique** `buildFolderScopedStudyRepository` n'assérait que le **TYPE de retour**. Preuve par mutation : intervertir `collection`/`parentCollection` **au site d'appel interne de la fabrique** laissait **les 3 tests VERTS** — un mauvais câblage du symbole que lex consommera **shipperait au vert**. Corrigé : getter `@visibleForTesting resolver` exposé sur `ZOfflineFirstBoxRepository`, le test AC3-fabrique assère désormais le chemin résolu à travers le dépôt réellement construit (swap au site d'appel ⇒ RED, prouvé).
- **Le corps de la story ES-10.2 a divergé de l'implémenté (LOW-1).** Après la révision Option B, seule la section finale « DÉCISION D'ARCHITECTURE » reflétait la réalité (45 arêtes, binding générique) ; AC1/AC5/AC7 (« 49 arêtes / +4 »), T1/T2/T6 (`z_study_entity_providers`) restaient caducs. Corrigé par un bandeau « CORPS PARTIELLEMENT SUPERSEDED » en tête. Dette d'hygiène doc inhérente à une révision en cours de story : un lecteur (rétro, session lex) doit pouvoir se fier au document sans reconstituer l'historique.
- **Coût de la révision : un cycle dev-story jeté partiellement.** Le travail « providers typés + 4 deps + test entités » a été produit puis **retiré** (fichier supprimé, deps retirées, graphe ramené 49→45). Ce coût était **inévitable une fois l'erreur commise** (il fallait matérialiser puis constater le conflit EX-3), mais il aurait été **entièrement évitable** si la frontière v1.x avait été un critère de `create-story` (→ R28, §5).

---

## 4. FAN-IN & FRONTIÈRE — la leçon CENTRALE de l'epic

**ES-10 est le premier fan-in du monorepo : un package qui AGRÈGE l'étage study au lieu de le construire.** Cette bascule topologique a produit la leçon centrale, et elle est structurelle, pas anecdotique.

### Le mécanisme du défaut

Un binding réutilisable qui dépend d'une entité **concrète** propage cette dépendance à **tous ses consommateurs par transitivité**. Quand l'entité est **déférée v1.x** (`zcrud_flashcard`, `zcrud_mindmap` — frontière EX-3), le binding devient un **vecteur de violation de frontière** : il force `example/` (et demain lex/IFFD) à tirer une entité que l'architecture a explicitement sortie du périmètre v1. La direction d'arête est légale au sens du graphe (SORTANTE, acyclique, CORE OUT=0 préservé) — **`graph_proof` ne l'attrape PAS**. Seul `melos verify` REPO-WIDE, qui rejoue la résolution `example/` + le boundary EX-3, révèle le conflit.

### Pourquoi c'est exactement le scénario anticipé par ES-9

La rétro ES-9 §9 avait écrit, en préparation d'ES-10 : *« un fan-in binding est précisément le cas où une régression cross-package ne se voit QUE repo-wide, cf. incident `ZExportApi`. Un `graph_proof`/`secrets`/`melos list` verts ne remplacent PAS `melos analyze`/`verify`. »* ES-10.2 a matérialisé ce risque **au sens propre** : un artefact vert sur toutes les vérifs locales (tests par-package, analyze ciblé, graph_proof) mais RED sur la seule vérif repo-wide. La discipline R9 a tenu ; sans elle, un binding cassant la frontière v1.x aurait pu passer `done`.

### La décision (validée utilisateur) : BINDING GÉNÉRIQUE (Option B)

- ❌ **Retirés** : `z_study_entity_providers.dart` + son test, l'export barrel, les **4 deps d'entités**. Le binding redevient **thin/générique** (AD-15) : deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` uniquement. Graphe **retour à 45** (Δ 0). Aucun couplage binding→entité.
- ✅ **Conservé (livrable zcrud-side)** : l'adapter firestore **générique-par-topologie** `buildFolderScopedStudyRepository<T>` + la garde d'isolation backend AC2 du binding.
- ✅ **Déféré CÔTÉ APP (DW-ES102-1)** : les providers TYPÉS par entité deviennent des **one-liners app-side** (`zStudyWatchAllProvider<ZStudyDocument>(repo: …)`), instanciés par l'app hôte (lex/IFFD) dans sa session dédiée. La spécialisation typée vit là où l'entité est déjà tirée légitimement — **jamais dans le binding réutilisable**.

### → Règle R28 (nouvelle, codifiée par ES-10)

> **R28 — Un package d'AGRÉGATION (binding manager, ou tout package en position de fan-in réutilisable) reste GÉNÉRIQUE : il ne dépend JAMAIS d'un package d'ENTITÉ concrète. La spécialisation typée par entité vit CÔTÉ APP (composition-root), jamais dans le binding. Toute nouvelle arête de fan-in est validée contre les FRONTIÈRES v1.x (EX-3) AVANT merge — par un replay `melos run verify` REPO-WIDE, `graph_proof` ne suffisant PAS.**
>
> Trois volets :
> 1. **Binding = puits générique.** Un binding (`zcrud_riverpod`, demain `zcrud_get`/`zcrud_provider`) dépend au plus de `zcrud_core` + le(s) point(s) d'agrégation générique(s) (`zcrud_study_kernel`) — jamais d'une entité (`zcrud_document`/`note`/`exam`/`flashcard`/`mindmap`). Le générique se paramètre par `T` (port `ZStudyRepository<T>`) et par `String` (topologie : `collection`/`parentCollection`) ; il ne nomme aucune entité.
> 2. **Spécialisation app-side.** Riverpod n'ayant pas de provider générique sur `T`, le bundle typé par entité (`zStudy<Entity>Provider`) est une **instanciation app-side** de la fabrique générique — one-liner dans le composition-root de l'app hôte, où l'entité est déjà dans le périmètre.
> 3. **Frontière v1.x vérifiée repo-wide avant merge.** Toute arête de fan-in ajoutée passe `melos run verify` REPO-WIDE (résolution `example/` + boundary EX-3) — pas seulement `graph_proof`/analyze ciblé, qui déclarent VERT une arête pourtant interdite v1.x. R28 est la spécialisation-frontière de R9 (orchestrateur rejoue verify repo-wide) pour le cas fan-in.

R28 complète R25 (workspace partagé → sériel) et l'extension ES-9 (package partagé → sériel) : là où celles-ci gouvernent la **concurrence d'écriture**, R28 gouverne la **topologie de dépendance d'un agrégateur** — un axe orthogonal, révélé par le premier fan-in.

---

## 5. Le motif dominant — TRAJECTOIRE sur l'epic

Le motif dominant du repo — **« un artefact validé sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT » / « une garde qu'aucune machine n'exige est un vœu »** (R12/R18/R20/R24/R26/R27) — a sur ES-10 une trajectoire à **deux temps** : un sommet d'emblée, puis une rechute fine rattrapée.

| Story | Niveau atteint | Description |
|-------|----------------|-------------|
| **ES-10.1** | ✅✅ **Exemplaire — R27 appliqué de série** | 0 HIGH/MAJEUR/MEDIUM. Toutes gardes prouvées POWERFUL par mutation **dès l'écriture** : SM-1 (`1→2` sous identité), égalité **par champ un à un** (7 cas mono-champ, leçon ES-9.3 déjà dans l'AC2), seam throw typé, auto-dispose. **Le niveau-cible ES-9.4 est atteint sans rattrapage** — la question de rétro ES-9 trouve sa réponse : R27 co-conçu dans `create-story`. Les 3 LOW sont des durcissements de test / une non-revendication honnête (R3-I2h `hashCode` non réalisable — correctement NON revendiqué par le dev). |
| **ES-10.2** | ⚠️ → ✅ **1 angle mort fin, plus subtil que jamais, rattrapé** | MEDIUM-1 : la garde de chemin nested était PUISSANTE **sur le helper interne** (`buildFolderScopedResolver`, R3-I6 rougit) mais **POWERLESS sur la fabrique publique** — le test n'assérait que le type de retour, un swap au site d'appel de la fabrique publiée passait vert. **La leçon : tester le SYMBOLE PUBLIC que le consommateur appelle, pas seulement le helper interne** (le helper peut être parfait et le câblage public faux). Corrigé (getter `resolver` `@visibleForTesting` + assertion à travers le dépôt construit). |

**La discipline est haute et se raffine.** ES-9 avait fait converger le défaut de « masqué+powerless » vers « verrouillé de série ». ES-10.1 confirme ce plancher (R27 de série). ES-10.2 déplace l'angle mort d'un cran encore plus fin : **le pouvoir discriminant d'un test peut être réel sur le nœud de composition interne et NUL sur le point d'entrée public** — car les deux sont séparés par un pass-through d'une ligne que rien n'exerçait. C'est la spécialisation-frontière de R27 : *co-livrer le verrou avec la garde* ne suffit pas si le verrou vise le helper au lieu du symbole exporté.

### → Corollaire R27.4 (précision apportée par ES-10.2)

> **Le test à rouge provoqué doit exercer le SYMBOLE PUBLIC consommé (la fabrique/le provider exporté par le barrel), pas seulement le helper interne qu'il compose.** Un helper prouvé POWERFUL n'implique PAS que son câblage dans le point d'entrée public l'est. Muter le SITE D'APPEL de la fabrique publique doit rougir un test. (Cf. MEDIUM-1 ES-10.2 : swap `collection`/`parentCollection` au site d'appel → helper VERT, fabrique publique VERT ⇒ trou ; corrigé par assertion à travers le dépôt construit.)

---

## 6. Dettes techniques — état après ES-10

| Dette | État | Détail |
|-------|------|--------|
| **DW-ES102-1** (ES-10.2) | 🟡 **OUVERTE, non bloquante — session lex dédiée** | Câblage lex-side : (1) enregistrement des seams `zStudyRepositoryProvider<Entity>` au `ProviderScope` lex avec `buildFolderScopedStudyRepository<Entity>` ; (2) providers TYPÉS par entité = **one-liners app-side** (décision Option B) ; (3) cutover repo-par-repo des repos éducation lex (smart_notes / study_documents / study_folders / exams / flashcards), **sans big-bang** ; (4) injection `FirebaseFirestore`+`userId`/`folderId` depuis l'auth lex + `ZLocalStore` Hive lex ; (5) parité écran + SRS SM-2 sur données lex vivantes ; (6) branchement éventuel `ZStudyLegacyCodec`. **Aucun fichier lex/iffd/dodlp touché côté zcrud** (re-scope utilisateur respecté). Marqueur dartdoc `DW-ES102-1` sur chaque déliverable. |
| **DW-ES102-2** (ES-10.2) | 🟢 **RÉSOLUE par la décision Option B** | Le conflit `example/` (overrides + boundary EX-3) causé par le fan-in vers `zcrud_flashcard` disparaît puisque le binding ne tire plus d'entités. Graphe 45, `example/` résout, `melos verify` VERT. |
| **DW-ES94-1** (héritée ES-9.4) | 🟡 **OUVERTE — inchangée** | Enforcement SERVEUR de l'ACL de partage (prédicat pur `canMutateControl` fourni côté domaine, réplication serveur app-side). Non touchée par ES-10. Reste inscrite `architecture.md § Deferred`. |

**Aucune dette bloquante.** DW-ES102-1 est une frontière zcrud-side / lex-side **honnête et tracée** (le zcrud-side est complet et prouvé isolément) ; DW-ES102-2 est fermée ; DW-ES94-1 est stable.

---

## 7. Détection de changement significatif (impact sur ES-11)

**Un changement de PROCESS significatif détecté, aucun changement de PLAN invalidant.** La révision Option B **confirme** l'architecture (AD-15 binding thin/générique) plutôt qu'elle ne la contredit — elle corrige une story qui s'en était écartée. Les invariants AD-1/AD-2/AD-5/AD-6/AD-10/AD-15/AD-24 sont tous respectés et verrouillés ; le graphe est resté acyclique CORE OUT=0. **Le plan ES-11 (binding GetX + migration IFFD) reste sain — pas de session de re-planification requise**, MAIS **R28 devient un prérequis de conception d'ES-11.1** (le miroir GetX doit naître générique, pas répéter l'erreur de fan-in typé d'ES-10.2).

**Readiness ES-10 (production-ready ?)** :
- Tests & qualité : **VERT** (25 riverpod + 176 firestore, verify repo-wide RC=0, chaque garde load-bearing prouvée RED, MEDIUM-1 corrigé).
- Objectif produit n°1 (SM-1) : **PROUVÉ exécutablement** au binding (zéro rebuild inutile, verrouillé par compteur de builds).
- Frontière v1.x (EX-3) : **RESPECTÉE** (binding générique, `example/` résout).
- Dettes : DW-ES102-1 ouverte non bloquante (session lex), DW-ES102-2 résolue.
- Blocages résiduels : **aucun** pour démarrer ES-11. Réserve : la migration lex/IFFD réelle est déférée à des sessions app-side dédiées.

---

## 8. Décisions verrouillées réutilisables pour ES-11+ (suite § 8 d'ES-9)

- **R28 — Binding/agrégateur GÉNÉRIQUE : aucune dep d'entité concrète ; spécialisation typée app-side ; toute arête de fan-in validée contre les frontières v1.x par `melos verify` REPO-WIDE avant merge.** (cf. §4). La règle-topologie révélée par le 1er fan-in.
- **R27.4 — Le verrou à rouge provoqué vise le SYMBOLE PUBLIC consommé, pas seulement le helper interne composé.** Muter le site d'appel de la fabrique/provider exporté doit rougir un test. (cf. §5, MEDIUM-1).
- **Binding thin/générique CONFIRMÉ (AD-15).** Deps `zcrud_*` d'un binding = `zcrud_core` + point(s) d'agrégation générique(s) (`zcrud_study_kernel`) ; le binding est un **PUITS** (aucun package ne dépend de lui). Riverpod (le manager) confiné à `zcrud_riverpod`, garanti structurellement par le graphe.
- **Égalité profonde de clé de family AU BINDING (AD-24 CONFIRMÉ).** Le contrat de caching d'un gestionnaire d'état (clé de provider/observable) est porté par un type **du binding** (`ZSessionConfigKey`), jamais par le kernel/cœur — même quand le kernel a déjà un `==` par valeur légitime. Égalité **par champ un à un** (R27) ; SM-1 prouvé par compteur de builds (`1→2` sous keying par identité rougit).
- **Adapter firestore GÉNÉRIQUE-PAR-TOPOLOGIE (composition ES-3, aucune arête d'entité).** Une fabrique d'adapter se paramètre par `String` (`collection`/`parentCollection`/`kind`) + `T Function(Map)` decode/encode ; retour = port neutre `ZStudyRepository<T>` ; seule couture backend = le paramètre `FirebaseFirestore` (AD-5). `folderId` manquant → `Left(DomainFailure)` explicite (AD-10). Zéro couplage consommateur, zéro nom d'app codé en dur.
- **Frontière zcrud-side / app-side tracée par dette DW (re-scope utilisateur).** Quand la consigne interdit de toucher lex/iffd/dodlp, la story produit **la seule surface zcrud** que l'app consommera, et le branchement réel (cutover, données vivantes) est une **dette de portage tracée** (dartdoc + `architecture.md § Deferred`), jamais exécutée en silence côté monorepo.

---

## 9. Préparation ES-11 — recommandations de séquencement / parallélisation & RE-SCOPE zcrud-side

**ES-11 = Binding GetX (`zcrud_get`) + migration IFFD (flat→canonique) + suppression god-controller DODLP.** Dépend d'ES-10. 3 stories attendues. Chantier de migration finale → **séquentiel par défaut**.

- **ES-11.1 — `zcrud_get` (binding GetX) = MIROIR d'ES-10 côté GetX.** APPLIQUER **R28 dès `create-story`** : le binding GetX naît **GÉNÉRIQUE** (deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` uniquement, **aucune** entité), la spécialisation typée par entité est **app-side** (DODLP composition-root). Ne PAS répéter l'erreur de fan-in typé d'ES-10.2. Vérifier le graphe (arête `zcrud_get → zcrud_core`/`zcrud_study_kernel`, acyclique, CORE OUT=0, binding = puits) et **rejouer `melos verify` REPO-WIDE** (frontière EX-3 : `get` ne doit pas tirer `zcrud_flashcard`/`mindmap`). Réutiliser le gabarit `ZcrudScope`/resolver + seam-throw d'ES-10.1, transposé GetX/get_it (le code manager-spécifique vit exclusivement dans `zcrud_get`, AD-15). Égalité profonde de config au binding = **miroir de `ZSessionConfigKey`** (AD-24), R27 par champ un à un.
- **ES-11.2 — Migration données IFFD (flat→canonique) : RE-SCOPER côté zcrud.** Produire côté monorepo **la mécanique de migration + les tests sur fixture COPIÉE** (corpus IFFD anonymisé/échantillon committé dans `test/fixtures/`), backend-agnostique, additive (`ZSyncMeta`, `fromJsonSafe` défensif). **L'exécution sur données IFFD réelles est DÉFÉRÉE à une session IFFD dédiée** (dette `DW-ES11x`, miroir de DW-ES102-1 : aucun accès aux données/repos IFFD vivants côté zcrud). Tester le mapper de migration de façon discriminante (round-trip flat→canonique→flat, champ par champ, R27).
- **ES-11.3 — Suppression du god-controller DODLP : potentiellement ENTIÈREMENT app-side.** Si aucun livrable zcrud (le refactor vit dans le repo DODLP), **le signaler comme HORS PÉRIMÈTRE de la session monorepo** dès `create-story` — la surface zcrud consommée (bindings, providers/controllers génériques, ports) est déjà livrée par ES-10/ES-11.1. Ne rien inventer côté zcrud pour « justifier » une story vide ; tracer le refactor DODLP en dette app-side si besoin.
- **Gate de commit d'epic (NON-NÉGOCIABLE, renforcé par R28)** : au repos de tous les workstreams, rejouer **`dart run melos run analyze` ET `dart run melos run verify` REPO-WIDE**. ES-11.1 est un **second fan-in binding** — précisément le cas où une arête vers une entité déférée v1.x (ou un symbole study disparu) ne se voit QUE repo-wide (cf. §4, incident EX-3 d'ES-10.2 ; précédent `ZExportApi`). Un `graph_proof`/`secrets`/`melos list` verts ne remplacent PAS `melos verify`.

**Au-delà d'ES-11** : intégration DODLP finale, rich-forms, flashcards/mindmaps (E9/E10, sortie de frontière v1.x) — à re-planifier après clôture ES-11. Note : la levée de la frontière EX-3 (réintégration `zcrud_flashcard`/`mindmap` en périmètre) permettra ALORS des providers typés binding-side — mais **seulement** après décision architecturale explicite, jamais par dérive de story (R28).

---

## 10. Transitions de statut (ressort de l'orchestrateur — hors cette rétro)

À appliquer par l'orchestrateur (édition ciblée du sprint-status, **non touché par cette rétro**) :
- `epic-es-10` : `in-progress` → `done`
- `epic-es-10-retrospective` : `optional` → `done`
- Commit unique de fin d'epic ES-10 (message `feat(zcrud_riverpod,zcrud_firestore): epic ES-10 — binding Riverpod (providers génériques + égalité profonde config AD-24) + adapter firestore folder-scopé générique`), incluant les `*.g.dart` régénérés éventuels de `packages/*/lib/`, excluant les `pubspec.lock` (racine et `example/`) et fichiers d'env.
