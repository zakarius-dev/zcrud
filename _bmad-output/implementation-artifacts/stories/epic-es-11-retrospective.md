# Rétrospective — Epic ES-11 (Binding GetX `zcrud_get` + migration IFFD flat→canonique, surface zcrud-side) + CLÔTURE ROADMAP ES-1..ES-11

> Skill réel : **`bmad-retrospective`** (tool `Skill`, workflow step-file chargé et suivi — pas de fallback disque). Rétro autonome (subagent non-interactif) : le format party-mode conversationnel du skill est transposé en synthèse écrite ; la substance (Epic Review + Next Epic Preparation + action items + readiness + détection de changement significatif) est intégralement traitée sur les **artefacts réels lus sur disque** (2 stories ES-11.1/ES-11.2 + 2 code-reviews + architecture § Deferred DW-ES111-1/DW-ES102-1, DW-ES112-1, DW-ES113-1 + rétros ES-6..ES-10 / R20..R28). Aucune reconstitution de mémoire.
> `sprint-status.yaml` **NON touché** (ressort de l'orchestrateur).
> État réel rejoué à la clôture : `graph_proof.py` → **46 arêtes / 20 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** ; `git status` → écritures confinées à `packages/zcrud_get/**` + `packages/zcrud_firestore/**` + artefacts BMAD (aucun fichier lex/iffd/dodlp).

---

## 1. Résumé de l'epic

**ES-11 — Second binding (GetX) + mécanique de migration IFFD.** ES-11 est le **dernier epic de la roadmap study côté monorepo**. Il livre le **2ᵉ binding de gestionnaire d'état** (GetX, miroir d'ES-10 Riverpod) et la **mécanique réutilisable de migration IFFD flat→canonique** (zcrud-side), puis **défère proprement** le seul chantier 100 % app-side (ES-11.3). Chaîne **séquentielle stricte** (11.2 s'appuie sur le socle codec ES-3.5, une seule story en vol).

| Story | Statut | Taille | Package(s) écrit(s) | Livrable | Δ arêtes graphe | Verdict code-review |
|-------|--------|--------|---------------------|----------|-----------------|---------------------|
| **ES-11.1** Binding GetX (`zcrud_get`) — miroir GetX d'ES-10.1 | ✅ DONE | L | `zcrud_get` | `ZSessionConfigKey` (égalité profonde AU BINDING, AD-24) **+ `tag` déterministe** (`a==b ⟺ a.tag==b.tag`) ; `ZStudyWatchController<T>` (flux nu re-émis, `onClose` anti-fuite) ; `buildStudyWatchController<T>` (seam throw) ; `zPutStudySessionSelector` (dedup GetX par `Type`+`tag`, **SM-1 prouvé au binding GetX**) | **45 → 46 (+1** = `zcrud_get → zcrud_study_kernel`, SORTANTE) | ✅ **APPROVE** — **0 HIGH / 0 MAJEUR / 0 MEDIUM**, LOW-2 corrigé, LOW-1→DW-ES111-1 |
| **ES-11.2** Migration IFFD flat→canonique — mécanique zcrud-side | ✅ DONE | M | `zcrud_firestore` | `ZLegacyStudyMigrator` (pur / idempotent / défensif / R26) **composant** `ZStudyLegacyCodec` (ES-3.5, inchangé) ; `ZDocumentMigrationOutcome`/`ZLegacyMigrationReport` (census + dry-run) ; fixtures synthétiques | **46 → 46 (Δ 0** : deps `zcrud_core`+`zcrud_study_kernel` déjà présentes, aucune arête d'entité) | ✅ **APPROVE** — **0 HIGH / 0 MAJEUR / 0 MEDIUM**, 4 LOW/nit consignés, DW-ES112-1 escaladée |
| **ES-11.3** Suppression `data_crud`+god-controller IFFD | ⏸️ **DÉFÉRÉE app-side** | — | **AUCUN** (zcrud) | 100 % app IFFD : consommer `ZStudyToolsPage` (déjà livré ES-5), supprimer `data_crud`/god-controller GetX IFFD, valider parité + SM-1 (déjà prouvé côté socle) | 0 | n/a (aucun livrable zcrud — dette **DW-ES113-1**) |

**Vérif verte finale (rejouée sur disque, RC hors pipe R15, runner `flutter test` R14)** — état à la clôture d'ES-11 :
- `flutter test packages/zcrud_get` → **38 tests, RC=0** (34 E2-9 + 4 suites study : égalité+tag mono-champ ×7, dedup SM-1, watch/seam/onClose, isolation backend/entité).
- `flutter test packages/zcrud_firestore` → **209 tests, RC=0** (codec ES-3.5 inclus, inchangé + migrateur + isolation).
- `python3 scripts/dev/graph_proof.py` → **46 arêtes, 20 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** (arête binding GetX = `→ zcrud_core`, `→ zcrud_study_kernel` seulement ; binding = PUITS, aucune arête binding→entité).
- `dart run melos run analyze` **ET** `dart run melos run verify` **REPO-WIDE** → **RC=0** (`gate:reserved-keys`, `gate:secrets`, `gate:web`, `codegen-distribution`, `verify:serialization`, isolement d'idiome) — **frontière EX-3 respectée, `example/` résout, aucune entité déférée v1.x tirée**.
- `dart run melos list` → **20 packages**.

Bilan findings de l'epic : **0 HIGH · 0 MAJEUR · 0 MEDIUM · 6 LOW/nit** (2 sur 11.1 dont 1 corrigé + 1 escaladé ; 4 sur 11.2 consignés). **Aucune story n'est passée `done` avec un finding bloquant ouvert.** Aucune remédiation majeure, aucune révision d'architecture : c'est l'epic **le plus lisse de toute la roadmap** — la discipline a convergé (cf. §5).

---

## 2. Ce qui a bien marché (spécifique ES-11)

- **ES-11.1 : la discipline a CONVERGÉ — R28/R27.4 appliqués D'EMBLÉE, 0 finding structurel.** Le second fan-in binding naît **générique par conception** : deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` **uniquement**, aucune entité concrète, graphe +1 (kernel seul). C'est **exactement** l'inverse de la trajectoire d'ES-10.2 (qui avait d'abord fait dépendre le binding de 4 entités → conflit EX-3 → révision Option B jetant un cycle dev-story). Ici, **aucun cycle jeté** : R28 était un critère de `create-story` (AC6/AC7/AC8 posent le fan-in générique + le gate `melos verify` repo-wide dès la story). La leçon d'ES-10.2 n'est plus « rattrapée en code-review » : elle est **intériorisée en amont**.
- **SM-1 (objectif produit n°1) verrouillé AUSSI côté GetX — avec une adaptation non triviale du miroir.** Riverpod a `family` + dedup natif par `==`/`hashCode` de clé ; **GetX N'A PAS de family**. Le dev n'a pas tenté une transposition littérale : le miroir GetX de la clé de family est un **`tag` déterministe** (JSON canonique à clés récursivement triées) dérivé de l'égalité profonde, tel que `a == b ⟺ a.tag == b.tag` — GetX indexe par `Type`+`tag`, donc deux configs structurellement égales ⇒ **même `tag`** ⇒ **même instance réutilisée** (zéro rebuild superflu). Le spot-check orchestrateur (`tag` dégradé en `identityHashCode(config)` → dedup cassé → compteur de constructions `1→2`, RC=1) confirme la garantie exactement là où DODLP la ressentira. **L'objectif produit n°1 est désormais prouvé sur les DEUX gestionnaires d'état.**
- **R27.4 respecté de série : le verrou vise le SYMBOLE PUBLIC.** Le test de dedup SM-1 exerce **`zPutStudySessionSelector`** (factory exportée au barrel), pas `ZSessionConfigKey.tag` en isolation ; le test de seam exerce **`buildStudyWatchController`** (factory exportée) et asserte le **TYPE** `ZScopeError` (pas « throws »). Le corollaire R27.4 né d'ES-10.2 est appliqué sans rappel.
- **ES-11.2 : le TRAP d'idempotence a été DÉTECTÉ AU CREATE-STORY et fermé sans toucher le codec.** Le point subtil : `ZStudyLegacyCodec.toCanonical` (ES-3.5) **n'est PAS idempotent sur `status`** — `mapDocumentStatus` ne connaît que les 6 valeurs legacy, une valeur **déjà canonique** (`ready`/`validating`) tombe dans le `default → uploading`. Donc `toCanonical(toCanonical(doc))` **rétrograde** un statut déjà migré (perte silencieuse à la ré-exécution). Or une migration de corpus réel **est ré-exécutée** (reprise, cutover progressif) ⇒ elle **doit** être idempotente. La story a nommé ce TRAP explicitement (AC3) **avant** l'implémentation, et l'a fermé par une **garde « déjà canonique »** (`is_deleted` présent ET aucune clé camelCase) qui **compose le codec derrière une garde plutôt que de le modifier** — le codec ES-3.5 reste intact, son test resté vert (209 tests). Le spot-check orchestrateur (`_isAlreadyCanonical → false` → le point fixe casse → AC3 RC=1, restauré) verrouille la fermeture du TRAP.
- **R26 (préservation exacte) prouvé par census discriminant, pas par existence.** `migrateDocument` calcule un census (clés métier d'entrée → clés canoniques + `_legacy_`) ; un drop de clé (`assistantFileId` filtré) fait chuter la couverture ⇒ RED (R3-I1 prouvé). Le test **nomme chaque clé** attendue, jamais « la map n'est pas vide ». Le motif dominant du repo (garde sur le POUVOIR, pas l'EXISTENCE) est appliqué de série.
- **Défensif PAR CONSTRUCTION (AD-10), sans blanket try/catch.** Le migrateur ne throw jamais parce que ses helpers sont type-gardés et le codec non-throwant — **et non** parce qu'un `try/catch` avale tout. Conséquence : l'injection R3-I4 (hard-cast `value as int`) **remonte réellement** (`_TypeError` observé) ⇒ la garde défensive reste **discriminante** (un blanket catch l'aurait rendue impuissante). C'est la bonne façon d'être défensif : la robustesse ne masque pas le pouvoir de test.

---

## 3. Ce qui est à améliorer / points de friction (spécifique ES-11)

- **ES-11 n'a produit AUCUN finding bloquant et AUCUN angle mort majeur.** C'est le signe d'une roadmap arrivée à maturité — mais cela réduit la matière « à améliorer » à des raffinements de puissance de garde (LOW), listés ci-dessous. Aucun coût de révision, aucun cycle dev-story jeté (contraste net avec ES-10.2).
- **LOW-1 GetX (ES-11.1) — cache de sélecteurs sans éviction (divergence avec l'autoDispose Riverpod).** `zPutStudySessionSelector` fait `Get.put(tag:)` sans `Get.delete(tag:)` : le registre GetX **croît de façon non bornée** au fil des configs distinctes (là où le miroir Riverpod s'appuie sur `autoDispose`). Impact **borné en pratique** (objets-valeur immuables minuscules, aucun handle/stream détenu — pas de fuite de ressource). Escaladé en **DW-ES111-1** (éviction possible app-side). C'est une asymétrie **structurelle** entre les deux gestionnaires (GetX n'a pas d'équivalent natif d'`autoDispose` sur une instance taguée) — pas un défaut d'implémentation.
- **LOW-2 GetX (ES-11.1) — corrigé : la value-equality de `extension` n'était pas épinglée.** Le cas « égales-mais-distinctes » utilisait `const _FakeExt(1)` (canonicalisé → **même identité** partagée) ⇒ une régression `extension ==` → `identical(extension)` **passait tous les tests**. Corrigé : `_FakeExt(1)` **non-const** (instances distinctes-mais-égales) + assertion `identical(a.extension, b.extension) isFalse`, prouvé RED sous dégradation. **Note de portée** : le même durcissement s'appliquerait à ES-10.1 (déjà committé) — la lacune était **héritée du patron miroité**, pas introduite par ES-11.1. Elle illustre un risque du **miroitage** : copier un patron copie aussi ses angles morts de test.
- **ES-11.2 : LOW-1/LOW-2/LOW-3/LOW-4 consignés (aucun bloquant).** (a) **LOW-1** — le census est aveugle aux collisions camelCase↔snake (deux clés collidant en un snake sont comptées « couvertes » alors qu'une valeur est écrasée) ; **impact réel nul** (les clés legacy IFFD sont camelCase pures ⇒ `camelToSnake` injectif, aucune collision possible) — l'AC2 **sur-promet**, le besoin réel (détection de DROP) est prouvé. (b) **LOW-2** — l'invariant `isConsistent` (`migrated+alreadyCanonical==total`) est **tautologique** par construction (aucune catégorie d'erreur) : auto-contrôle défensif acceptable, mais **pas load-bearing** (la discrimination vient des compteurs nommés voisins). (c) **LOW-3** — l'heuristique `_isAlreadyCanonical` misclasserait un doc `is_deleted`+zéro-camelCase+status-legacy (sauterait le remap 6→4) ; aucun doc IFFD réel n'y tombe, tradeoff documenté, jamais de throw. (d) **LOW-4** — la non-mutation dry-run est prouvée **shallow** ; le chemin `alreadyCanonical` renvoie une copie superficielle (refs imbriquées partagées) — sûr aujourd'hui, **latent pour le write-back déféré** ⇒ **noté comme point de vigilance de DW-ES112-1** (cloner en profondeur avant write-back si mutation).

---

## 4. LE 2ᵉ BINDING & LA MIGRATION — les deux leçons centrales de l'epic

### 4.1 Second binding (GetX) : le miroir avec ADAPTATION, et la convergence de discipline

**ES-11.1 est le second fan-in binding du monorepo.** Sa leçon n'est pas topologique (R28 était déjà codifiée par ES-10) mais **méthodologique** : **une règle codifiée en rétro (R28/R27.4) est-elle appliquée D'EMBLÉE au cas suivant, ou re-découverte en douleur ?** ES-11.1 répond **appliquée d'emblée** — 0 finding structurel, aucune arête d'entité, aucun cycle jeté. La rétro ES-10 §9 avait explicitement recommandé « APPLIQUER R28 dès `create-story` [pour ES-11.1], ne PAS répéter l'erreur de fan-in typé d'ES-10.2 ». **Cette recommandation a été suivie à la lettre.** C'est la preuve que la boucle rétro→story fonctionne : la douleur d'ES-10.2 (un cycle dev-story produit puis retiré) ne s'est **pas** reproduite.

**L'adaptation non triviale : GetX n'a pas de family.** Le miroir n'est pas littéral. Là où Riverpod déduplique par `==`/`hashCode` de la clé de `family`, GetX indexe son gestionnaire d'instances par `Type`+`tag` (String). Le miroir correct de la clé de family est donc un **`tag` déterministe** dérivé de l'égalité profonde (`a == b ⟺ a.tag == b.tag`), et **c'est ce `tag` qui matérialise SM-1 côté GetX**. Le dev a résisté à deux tentations symétriques : (1) recopier `family` (impossible en GetX) ; (2) déduire le `tag` d'une composante d'identité/shallow (casserait le dedup). Le `tag` = JSON canonique à clés récursivement triées des 7 champs — value-based de bout en bout. **Leçon : miroiter un patron entre deux gestionnaires d'état, c'est préserver l'INVARIANT (dedup par valeur profonde, SM-1), pas le MÉCANISME (family vs Type+tag).**

### 4.2 Migration : le TRAP d'idempotence et la composition-derrière-garde

**ES-11.2 porte la leçon la plus subtile de l'epic.** Une mécanique de migration/reprise **doit prouver son idempotence par un test point-fixe** (`migrate(migrate(x)) == migrate(x)`), parce qu'un corpus réel est ré-exécuté (reprise après interruption, cutover repo-par-repo). Le TRAP était **caché dans une brique réutilisée** : `ZStudyLegacyCodec` (ES-3.5) est un **shim d'interop de LECTURE**, pas un migrateur ré-entrant — son `mapDocumentStatus` rétrograde un statut déjà canonique (`ready → uploading`) au 2ᵉ passage. Un migrateur naïf qui ré-applique aveuglément `codec.toCanonical` aurait **corrompu silencieusement** tout doc déjà migré rencontré lors d'une reprise.

**La bonne fermeture : composer le codec non-idempotent DERRIÈRE UNE GARDE, sans le modifier.** Deux options existaient : (a) rendre `mapDocumentStatus` idempotent (accepter les 4 valeurs canoniques comme points fixes) — modifie le codec, risque de régression sur ses cas 6→4 ; (b) **garde « déjà canonique »** en amont (le doc porte `is_deleted` ET aucune clé camelCase ⇒ il traverse inchangé) — le codec reste intact. Le dev a retenu (b) : **le codec ES-3.5 n'est pas touché, son test reste vert**, et le TRAP est franchi par une garde **co-livrée avec le test point-fixe** qui la verrouille (R3-I2 : retirer la garde → `ready` rétrogradé → AC3 RED). C'est un cas d'école du principe « ne modifie pas une brique éprouvée pour un besoin nouveau — compose-la derrière une garde qui porte le nouvel invariant ».

### 4.3 → Règle R29 (nouvelle, codifiée par ES-11.2)

> **R29 — Une mécanique de REPRISE / MIGRATION / ré-application doit PROUVER SON IDEMPOTENCE par un test POINT-FIXE (`op(op(x)) == op(x)`, égalité profonde), co-livré comme verrou à rouge provoqué. Quand elle COMPOSE une brique non-idempotente (codec/shim de lecture), elle place cette brique DERRIÈRE UNE GARDE de ré-entrance (détection « déjà transformé ») plutôt que de MODIFIER la brique — la brique éprouvée reste intacte (son test reste vert), et la garde neuve porte seule le nouvel invariant, verrouillée par le test point-fixe.**
>
> Trois volets :
> 1. **Idempotence prouvée, pas supposée.** Toute op ré-exécutée sur un corpus réel (migration, cutover, reprise) est un point fixe testé sur des valeurs qui traversent réellement le TRAP (ici `status ready`), pas seulement sur un doc « propre ». La garde d'idempotence est **co-livrée** avec ce test (R27) et vise le **symbole public** consommé (R27.4).
> 2. **Composer-derrière-garde, pas modifier.** Une brique de LECTURE (interop, shim) réutilisée dans un contexte de RÉ-ÉCRITURE reste inchangée ; l'idempotence est ajoutée en amont par une garde de ré-entrance. Modifier la brique diffuserait le risque à tous ses autres appelants.
> 3. **Défensif SANS masquer le pouvoir.** La robustesse (jamais de throw, AD-10) s'obtient par des helpers type-gardés, **pas** par un blanket `try/catch` — sinon les injections de correctness (hard-cast) sont avalées et les gardes deviennent impuissantes.

### 4.4 → Règle R30 (nouvelle, codifiée par ES-11.3)

> **R30 — AVANT de lancer une story, vérifier son PÉRIMÈTRE DE FICHIERS réel dans l'epic. Si le livrable est 100 % APP-SIDE (aucun fichier `zcrud_*` à écrire, la surface zcrud consommée étant DÉJÀ livrée), la story est DÉFÉRÉE à la session de l'app dédiée avec une dette DW tracée — jamais forcée en inventant un livrable zcrud pour « justifier » la story, jamais exécutée en touchant lex/iffd/dodlp depuis le monorepo.**
>
> Trois volets :
> 1. **Détection amont, au create-story.** Le périmètre de fichiers d'une story se lit dans l'epic AVANT toute implémentation. Une story dont la cible est un repo d'app (`app IFFD — lib/data_crud/** supprimé, …`) et dont tous les prérequis zcrud sont livrés (`ZStudyToolsPage` en ES-5, binding en ES-11.1, migration en ES-11.2) est **app-side pure**.
> 2. **Défère, n'invente pas.** Ne rien fabriquer côté zcrud pour rendre la story « non vide ». Inventer un livrable zcrud artificiel ajouterait du code non requis et brouillerait la frontière. La dette DW (dartdoc + `architecture.md § Deferred`) est le bon réceptacle.
> 3. **Frontière de re-scope respectée.** Consigne utilisateur : aucune modification d'app depuis le monorepo. R30 est la généralisation de la frontière zcrud-side / app-side (déjà tracée par DW-ES102-1/DW-ES111-1/DW-ES112-1) au cas **story entièrement app-side** — le 1er cas 100 % app-side correctement **détecté et déféré** (ES-11.3, DW-ES113-1), pas forcé.

**R30 complète le triptyque de frontière** : DW-ES102-1 (binding Riverpod, câblage app-side), DW-ES111-1 (binding GetX, câblage app-side), DW-ES112-1 (exécution migration IFFD app-side) tracent la frontière **au niveau d'une PARTIE de story** (le zcrud-side est livré, le branchement réel déféré) ; R30 la trace au niveau d'une **story ENTIÈRE** (ES-11.3, zéro livrable zcrud).

---

## 5. Le motif dominant — TRAJECTOIRE sur l'epic (et sur toute la roadmap)

Le motif dominant du repo — **« un artefact validé sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT » / « une garde qu'aucune machine n'exige est un vœu »** (R12/R18/R20/R24/R26/R27/R27.4) — atteint sur ES-11 son **plancher de discipline le plus haut de toute la roadmap** :

| Story | Niveau atteint | Description |
|-------|----------------|-------------|
| **ES-11.1** | ✅✅ **Exemplaire — R28/R27.4/R27 appliqués DE SÉRIE** | 0 HIGH/MAJEUR/MEDIUM. Binding **né générique** (R28 dès create-story) — aucun cycle jeté (contraste net avec ES-10.2). SM-1 prouvé au binding GetX (dedup `1→2` sous identité rougit), égalité **par champ un à un** (7 cas mono-champ), seam throw typé, `onClose` anti-fuite. Les verrous visent le **symbole public** (R27.4). LOW-2 (héritée du patron miroité ES-10.1) corrigée. |
| **ES-11.2** | ✅✅ **Exemplaire — TRAP anticipé au create-story** | 0 HIGH/MAJEUR/MEDIUM. Le TRAP d'idempotence (codec non-idempotent sur `status`) est **nommé dans l'AC3 AVANT l'implémentation** et fermé par composition-derrière-garde. R26 census discriminant, défensif-par-construction (préserve le pouvoir des injections). Les 3 gardes structurantes prouvées LOAD-BEARING par mutation réelle. 4 LOW/nit = raffinements (AC2 qui sur-promet, invariant tautologique) — aucun défaut de correctness. |

**La discipline a convergé — elle n'est plus « rattrapée », elle est « native ».** La trajectoire de la roadmap est nette : ES-1..ES-5 découvraient le motif en douleur (gates enseignant la dette, gardes powerless masquées) ; ES-6..ES-9 le faisaient converger vers « verrouillé de série » ; ES-10.1 atteignait le plancher R27-de-série mais ES-10.2 rechutait sur un angle mort fin (fan-in typé + helper-vs-symbole-public) ; **ES-11 ne rechute plus** — les deux stories naissent au niveau-cible, les leçons R28/R27.4/R27/R26 sont des critères de `create-story`, pas des découvertes de code-review. La question de rétro ES-9 (« comment faire du niveau-cible le DÉFAUT, pas l'aboutissement d'une courbe ? ») trouve ici sa **confirmation sur un epic entier**.

---

## 6. Dettes techniques — état après ES-11 (et à la clôture de la roadmap)

| Dette | État | Détail |
|-------|------|--------|
| **DW-ES111-1 / DW-ES102-1** (ES-11.1 / ES-10.2) | 🟡 **OUVERTE, non bloquante — sessions APP dédiées** | **Câblage app-side des bindings Riverpod + GetX.** Depuis le monorepo les bindings restent GÉNÉRIQUES (R28) : fabriques/seams génériques (`zStudyWatchAllProvider<T>` / `buildStudyWatchController<T>`, `ZSessionConfigKey`, seams de résolution) + adapter firestore folder-scopé générique. Résiduel app-side : (1) spécialisation typée par entité = one-liners app-side ; (2) enregistrement des seams au `ProviderScope`/locator avec l'adapter injecté ; (3) cutover repo-par-repo + parité écran & SRS SM-2 sur données réelles. **Point de vigilance** : LOW-1 GetX (cache sélecteurs sans éviction — croissance bornée, l'app peut ajouter une éviction). Aucun fichier lex/iffd/dodlp touché côté zcrud. |
| **DW-ES112-1** (ES-11.2) | 🟡 **OUVERTE, non bloquante — session IFFD dédiée** | **Exécution de la migration flat→canonique sur les données RÉELLES IFFD.** La MÉCANIQUE est livrée et verrouillée zcrud-side (`ZLegacyStudyMigrator` : pur, idempotent — TRAP franchi —, défensif, préservant R26, rapport + dry-run, fixtures synthétiques). Résiduel : branchement sur collections Firestore réelles, **write-back batché** (`WriteBatch` ≤ 450/lot, `serverTimestamp` pour `updated_at`), cutover repo-par-repo, validation corpus réel. **Vigilance LOW-4** : cloner en profondeur avant write-back (la copie dry-run est shallow). Aucun fichier IFFD touché. |
| **DW-ES113-1** (ES-11.3) | 🟡 **OUVERTE, non bloquante — session IFFD dédiée (100 % app-side)** | **Suppression `data_crud` legacy + god-controller GetX IFFD.** AUCUN livrable zcrud : `ZStudyToolsPage` déjà livré (ES-5), binding GetX (ES-11.1), mécanique migration (ES-11.2). IFFD ne fait que consommer + supprimer son `data_crud`/god-controller + valider parité + SM-1 (déjà prouvé côté socle). **1er cas 100 % app-side correctement détecté et déféré (R30), pas forcé.** |
| **DW-ES94-1** (héritée ES-9.4) | 🟡 **OUVERTE, non bloquante — enforcement app/serveur** | **Enforcement SERVEUR de l'ACL de partage.** Le domaine fournit le prédicat pur de vérité `ZStudySharingAcl.canMutateControl` (verrouillé en machine, révocation monotone, état personnel structurellement séparé) ; l'app doit **répliquer** ce prédicat au serveur (règles backend rejetant à la source). Documenté en dartdoc impossible à rater. Signalé, jamais hérité en silence (NFR-S11). |
| **DW-ES14-2** (héritée ES-2.0) | 🟡 **OUVERTE, tracée — refonte `ZcrudRegistry`** | `ZcrudRegistry` n'offre aucun slot d'injection ⇒ la voie registre ne type jamais `extension` (et court-circuite le `ZSourceRegistry` app). **Latente** (`fromRegistry` sans appelant ; le store study est câblé via le codec ES-3.5, pas via cette voie). Épinglée en machine (verrou bi-régime `kExtensionPayloadPreservers`). À solder avant toute adoption de la voie registre pour une entité `ZExtensible`. |
| **DW-ES82-1 / DW-ES-6.1-1** (héritées) | 🟡 **OUVERTES — signal récurrent `gate:web`** | Chaque satellite domaine gagnant une UI Flutter (`zcrud_note`, `zcrud_document`) sort de `gate:web` (perte du filet cross-runtime JS sur sa (dé)sérialisation). Aucune régression de test ; arbitrer une solution GÉNÉRIQUE (runner web pour packages Flutter, ou séparation domaine-pur/présentation-Flutter). |
| **DW-ES22-5** (ouverte ES-2.2b) | 🟡 **OUVERTE — préexistante** | `ZMindmap`/`ZMindmapNode` sans égalité de valeur (`operator ==` absent). Défaut préexistant plus large que le périmètre nommé. |
| **DW-ES13-2** (héritée) | 🟡 **OUVERTE — cosmétique** | `ZFlashcard.updatedAt` : miroir de compat non déprécié (surface E9 consommée par la migration DODLP). Dépréciation formelle à re-statuer hors roadmap study. |
| **DW-ES14-1 / DW-ES22-1 / DW-ES22-3 / DW-ES22-4** | ✅ **SOLDÉES** | Round-trip `extra` préservé par le registre (émission `fromMap` domaine + garde runtime bi-jambe) ; réconciliation source-policy note/markdown ; voie d'écriture publique/constructeur nominal filtrant les clés réservées ; égalité profonde `zJsonEquals`/`zJsonHash`. |

**Aucune dette bloquante côté zcrud pour la clôture de la roadmap.** Les dettes ouvertes se partitionnent en : (a) **frontière app-side** (DW-ES111-1/DW-ES102-1, DW-ES112-1, DW-ES113-1, DW-ES94-1 enforcement) — honnêtes, tracées, résiduel = travail hors monorepo ; (b) **dettes d'infrastructure latentes** (DW-ES14-2 refonte registre, DW-ES82-1 gate:web, DW-ES22-5 égalité mindmap) — non déclenchées par le périmètre livré, à arbitrer sur besoin. Le zcrud-side de chaque epic est **complet et prouvé isolément**.

---

## 7. Détection de changement significatif

**Aucun changement de PLAN invalidant, aucun changement de PROCESS structurant.** Contrairement à ES-10 (qui avait révélé le fan-in générique → R28), ES-11 **n'a produit aucune surprise architecturale** : les deux bindings sont symétriques, la mécanique de migration compose proprement le socle existant. Les invariants AD-1/AD-2/AD-5/AD-6/AD-10/AD-15/AD-19/AD-24/AD-27 sont tous respectés et verrouillés ; le graphe est resté acyclique CORE OUT=0 (45→46 pour le fan-in GetX, delta 0 pour la migration). **C'est le dernier epic de la roadmap study côté monorepo — il n'y a pas de « next epic » à préparer côté zcrud** (cf. §8 Clôture). Les seuls travaux résiduels sont **app-side** (sessions lex/IFFD/DODLP dédiées), gouvernés par R30 et les dettes DW de frontière.

---

## 8. 🏁 CLÔTURE DE LA ROADMAP BMAD MONOREPO — ES-1..ES-11 (côté zcrud) = COMPLET

**La roadmap study côté monorepo est CLÔTURÉE.** Les 11 epics (ES-1 fondations → ES-11 second binding + migration) sont livrés, verts, et prouvés isolément côté zcrud. Ce qui reste est **exclusivement du travail APP-SIDE** (sessions dédiées lex_douane / IFFD / DODLP), hors monorepo, gouverné par la frontière de re-scope (R30 + dettes DW).

### 8.1 État final vérifié sur disque (à la clôture)

| Métrique | Valeur | Preuve |
|----------|--------|--------|
| **Packages** | **20** | `dart run melos list` / `ls packages` |
| **Graphe de dépendances** | **46 arêtes / 20 nœuds** | `graph_proof.py` |
| **Acyclicité** | **ACYCLIQUE OK** | `graph_proof.py` |
| **Cœur découplé** | **CORE OUT=0 OK** (`zcrud_core` ne dépend d'aucun `zcrud_*`) | `graph_proof.py` |
| **Analyze repo-wide** | **RC=0** | `dart run melos run analyze` |
| **Verify repo-wide** | **RC=0** (reserved-keys, secrets, web, codegen-distribution, serialization, idiome) | `dart run melos run verify` |
| **Frontière v1.x EX-3** | **RESPECTÉE** (`example/` résout, aucune entité déférée tirée) | `melos verify` |
| **Objectif produit n°1 (SM-1)** | **PROUVÉ exécutablement sur les 2 gestionnaires** (Riverpod ES-10.1 + GetX ES-11.1) | compteurs de builds/constructions, spot-checks R18 |

### 8.2 Ce qui a été construit (récapitulatif roadmap)

- **20 packages** en architecture hexagonale melos, graphe **acyclique CORE OUT=0** — `zcrud_core` (domaine pur, réactivité Flutter-native, zéro gestionnaire d'état) au centre, satellites en périphérie (codegen, markdown, note, document, exam, session, study, study_kernel, flashcard, mindmap, geo, intl, export, list, firestore) + **3 bindings** (Riverpod, GetX, provider) confinant chacun son manager (AD-15).
- **Étage study complet** : kernel (`ZStudySessionConfig`/`ZStudyRepository<T>`/`ZStudySessionSelector` purs), entités (`ZSmartNote`, `ZStudyDocument`, `ZExam`, `ZStudyFolder`, `ZStudySession`…), SRS, partage (ACL pure), `ZStudyToolsPage`.
- **Codegen zcrud** (`@ZcrudModel`/`@ZcrudField`) : (dé)sérialisation défensive + `ZFieldSpec[]` + registre, round-trip `extra`/`extension` préservé et **verrouillé en machine** (gates reserved-keys / codegen-distribution / serialization).
- **2 bindings de gestionnaire d'état** (Riverpod + GetX), génériques (R28), avec égalité profonde de config AU BINDING (AD-24) et **SM-1 prouvé sur les deux** (objectif produit n°1).
- **Mécanique de migration IFFD** flat→canonique (pure, idempotente, défensive, préservante), prête à brancher app-side.
- **Adapter firestore** offline-first folder-scopé générique-par-topologie, backend isolé (aucun type `cloud_firestore` en signature de domaine, AD-5).

### 8.3 Règles accumulées R1..R30 (discipline de méthode codifiée)

La roadmap a accumulé **30 règles de discipline** (une par leçon structurante), du socle (R1..R13 : gates par machine, RC hors pipe, runner Flutter, injections R3 load-bearing) aux règles topologiques et de frontière les plus récentes :
- **R14/R15** — runner `flutter test` ; RC capturé hors pipe.
- **R16/R21** — gate à population self-déclarée = faux-vert ; scan récursif dérivé du disque, jamais liste figée.
- **R17/R23/R25** — sérialisation du dev au niveau workspace/package partagé (concurrence d'écriture).
- **R18** — spot-check orchestrateur prouve le POUVOIR indépendamment du callback.
- **R19** — golden = byte-diff + comptage structurel.
- **R20/R22/R24/R26/R27** — garde ancrée sur la ligne de prod / critère canonique partagé / préservation par census discriminant / verrou co-livré avec la garde.
- **R27.4** — le verrou vise le SYMBOLE PUBLIC consommé, pas le helper interne (ES-10.2).
- **R28** — binding/agrégateur GÉNÉRIQUE, aucune dep d'entité ; spécialisation app-side ; arête de fan-in validée `melos verify` REPO-WIDE (ES-10).
- **🆕 R29** — mécanique de reprise/migration prouve son IDEMPOTENCE par test point-fixe ; compose une brique non-idempotente DERRIÈRE UNE GARDE plutôt que de la modifier (ES-11.2).
- **🆕 R30** — story 100 % app-side détectée au create-story ⇒ DÉFÉRÉE avec dette DW, jamais forcée ni exécutée en touchant lex/iffd/dodlp depuis le monorepo (ES-11.3).

### 8.4 Ce qui reste = travail APP-SIDE (hors monorepo)

Toutes les dettes ouvertes de frontière sont des **sessions d'application dédiées**, jamais exécutées depuis le monorepo (consigne de re-scope utilisateur) :
- **DODLP** (GetX) : câblage du binding GetX (DW-ES111-1) — spécialisation typée, enregistrement des seams, cutover repo-par-repo ; suppression du god-controller.
- **lex_douane** (Riverpod) : câblage du binding Riverpod (DW-ES102-1) — one-liners typés, seams au `ProviderScope`, cutover éducation lex.
- **IFFD** (GetX) : exécution de la migration flat→canonique sur données réelles (DW-ES112-1, write-back batché) ; suppression `data_crud`+god-controller + consommation `ZStudyToolsPage` (DW-ES113-1).
- **Enforcement serveur** de l'ACL de partage (DW-ES94-1) : réplication du prédicat pur `canMutateControl` dans les règles backend.

Le monorepo fournit **la surface de vérité** (ports, fabriques génériques, prédicats purs, mécaniques prouvées) ; chaque app la **branche** dans sa session dédiée. Aucune de ces dettes n'est bloquante côté zcrud.

---

## 9. Readiness — ES-11 & roadmap production-ready ?

- **Tests & qualité** : **VERT** (38 GetX + 209 firestore, verify repo-wide RC=0, chaque garde load-bearing prouvée RED, LOW-2 corrigée). 
- **Objectif produit n°1 (SM-1)** : **PROUVÉ exécutablement sur les DEUX gestionnaires d'état** (Riverpod + GetX) — zéro rebuild superflu, verrouillé par compteur.
- **Frontière v1.x (EX-3)** : **RESPECTÉE** (bindings génériques, `example/` résout).
- **Idempotence de migration** : **PROUVÉE** (point fixe, TRAP `status` fermé et verrouillé).
- **Dettes** : toutes ouvertes **non bloquantes** (frontière app-side + infra latente), tracées en dartdoc + `architecture.md § Deferred`.
- **Blocages résiduels côté zcrud** : **AUCUN**. Réserve honnête : le branchement app-side réel (données vivantes lex/IFFD/DODLP) est déféré à des sessions dédiées.

**Verdict : la roadmap BMAD monorepo (ES-1..ES-11, côté zcrud) est COMPLÈTE et production-ready au sens du périmètre monorepo.** Le reste est de l'intégration app-side, hors du champ de ce dépôt.

---

## 10. Action items

| # | Action | Catégorie | Propriétaire | Critère de complétion |
|---|--------|-----------|--------------|------------------------|
| 1 | Porter le durcissement value-equality de `extension` (LOW-2) sur ES-10.1 (`zcrud_riverpod`) — le patron miroité partageait la lacune | technique (test) | session zcrud (trivial, ~4 lignes) | test `z_session_config_key_equality_test.dart` riverpod épingle deux `extension` distinctes-mais-égales |
| 2 | Session DODLP : câbler le binding GetX (DW-ES111-1) — spécialisation typée + seams + cutover + god-controller | app-side | session DODLP dédiée | repos DODLP consomment `buildStudyWatchController<Entity>` ; god-controller supprimé ; SM-1 vérifié sur écran vivant |
| 3 | Session IFFD : exécuter la migration réelle (DW-ES112-1) — write-back batché + cutover + **clonage profond avant write** (vigilance LOW-4) | app-side | session IFFD dédiée | corpus IFFD migré sans perte (audit `ZLegacyMigrationReport`), idempotence vérifiée sur reprise |
| 4 | Session IFFD : ES-11.3 (DW-ES113-1) — supprimer `data_crud`+god-controller, consommer `ZStudyToolsPage` | app-side | session IFFD dédiée | `lib/data_crud/**` supprimé, parité d'apparence + non-perte-de-focus validées |
| 5 | Session lex : câbler le binding Riverpod (DW-ES102-1) + enforcement serveur ACL (DW-ES94-1) | app-side | session lex dédiée | one-liners typés au `ProviderScope` ; règles backend répliquent `canMutateControl` |
| 6 | Arbitrer une solution GÉNÉRIQUE `gate:web` pour les satellites domaine Flutter (DW-ES82-1, signal récurrent) | infra (à planifier) | orchestrateur / session infra | runner web pour packages Flutter, ou séparation domaine-pur/présentation |

**Aucun action item bloquant côté monorepo.** #1 et #6 sont zcrud-side (trivial / à planifier) ; #2–#5 sont les sessions app-side de fin de roadmap.

---

## 11. Transitions de statut (ressort de l'orchestrateur — hors cette rétro)

À appliquer par l'orchestrateur (édition ciblée du sprint-status, **non touché par cette rétro**) :
- `es-11-1-...` : `review` → `done`
- `es-11-2-...` : `review` → `done`
- `es-11-3-...` : `deferred` (app-side, DW-ES113-1) — jamais `done` (aucun livrable zcrud), tracée comme déférée
- `epic-es-11` : `in-progress` → `done`
- `epic-es-11-retrospective` : `optional` → `done`
- **Commit unique de fin d'epic ES-11** — message `feat(zcrud_get,zcrud_firestore): epic ES-11 — binding GetX (ZSessionConfigKey+tag, SM-1 au binding, R28) + mécanique migration IFFD flat→canonique (ZLegacyStudyMigrator idempotent/défensif/R26)` ; **inclure** les `*.g.dart` régénérés éventuels de `packages/*/lib/` ; **exclure** les `pubspec.lock` (racine et `example/`) et fichiers d'env.
- **Marqueur de clôture roadmap** : ES-1..ES-11 côté zcrud = COMPLET ; travaux résiduels = sessions app-side (DW-ES111-1/DW-ES102-1, DW-ES112-1, DW-ES113-1, DW-ES94-1).

---

_Fin de la rétrospective ES-11 — et de la roadmap BMAD monorepo study (ES-1..ES-11, côté zcrud)._
