# Revue de spine — rubric walker + réconciliation des entrées

- **Cible** : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md`
- **Entrées confrontées** : PRD `prd-zcrud-study-ui-2026-07-16/prd.md` (FR-SU1..21, NFR-SU1..10, OA-1..6) · `.memlog.md` (36 entrées) · rubrique `bmad-architecture/references/reviewer-gate.md`
- **Calibration appliquée** : altitude **epic**, héritage AD-1..32 non re-décidé, détail par story hors périmètre. Ne sont retenus que les points où **deux stories pourraient trancher incompatiblement**.
- **Date** : 2026-07-16

## Verdict

Spine solide et inhabituellement bien investigué sur le groupe A/C (les 10 AD tranchent les OA-1..6 avec des règles réellement enforçables, dont plusieurs *par le type*), mais **il n'est pas prêt pour le handoff** : un trou d'invariant laisse le SRS atteignable depuis deux modes non-SRS, l'epic E-MULTI-EDIT est quasi dépourvu de décisions alors qu'il est le seul à écrire dans le cœur, et trois overrides du PRD (dont une nouvelle dépendance non vérifiée) ne sont tracés nulle part.

---

## 1. Rubric walker — checklist du bon spine

### 1.1 « Il fixe les vrais points de divergence pour le niveau du dessous, et n'en manque aucun »

**Partiellement.** Les divergences investiguées (éval IA, indices, ordre manuel, génération, cramming, rendu riche, export) sont tranchées avec précision. Mais trois points de divergence structurants sont **absents** :

| Point de divergence | Statut | Sévérité |
|---|---|---|
| Moteur assigné aux modes `list` (consultation) et `test` | **silencieux** — cf. F-1 | HIGH |
| Mécanique de multi-édition (FR-SU19 : état de sélection, édition de champ commun depuis `ZFieldSpec`, champ de rattachement de « Déplacer », slot d'actions de lot) | **silencieux** — cf. F-2 | HIGH |
| Frontière brouillon ↔ persistance entre FR-SU19 et FR-SU20 | **contradictoire** — cf. F-2 | HIGH |

### 1.2 « Chaque Rule est enforçable et prévient réellement sa divergence »

**Oui, sauf AD-39.** Qualité remarquable sur AD-34 (zéro-SRS *par le type*, pas par convention — le revirement acté en `(override)` du memlog est le bon), AD-37 (`modelId` opaque : la règle « transporté, jamais interprété » est vérifiable par grep d'un nom de modèle dans zcrud), AD-40 (« aucun type Quill/`flutter_math_fork` dans une signature publique » : testable par API-surface), AD-42 (bytes in / bytes out).

- **AD-39** — la Rule « **toute** suppression, unitaire comme par lot, awaited » est enforçable *isolément*, mais elle **n'est pas satisfiable** dans le contexte du brouillon FR-SU20 (cf. F-2). Une Rule qu'une story devra violer pour livrer sa FR n'est pas une Rule.
- **AD-35** — « qualité min » / « qualité max » n'est pas décidable : le memlog acte que l'**échelle zcrud est 0..5** (`ZSrsConfig.passThreshold`) alors que le PRD glossaire et FR-SU2 disent **1..5** avec « Je ne sais pas = qualité **1** ». `min` vaut donc 0 ou 1 selon la story. Cf. tail T-1.
- **AD-36** — « plancher configurable » perd le **défaut « plancher 2 »** écrit en FR-SU3. Deux stories choisiront deux défauts. Cf. T-2.

### 1.3 « Rien sous Deferred ne peut faire diverger deux unités »

**Un doute.** « Édition de champ commun **au-delà** des types scalaires du `ZFieldSpec` (champs conditionnels, validations croisées) — à cadrer si une story le demande » diffère une extension, ce qui est légitime — **mais le cas nominal (types scalaires) n'est décidé nulle part non plus** (cf. F-2). Un Deferred qui borne un invariant inexistant ne borne rien. Les quatre autres entrées Deferred (LaTeX vectoriel, mesure intrinsèque graphite, normalisation des réponses IA, frontière UTC du streak) sont correctement inertes.

### 1.4 « La techno nommée est vérifiée-courante »

**Non — une exception.** Le memlog porte une veille datée du 2026-07-16 sur `flutter_card_swiper 7.2.0`, `confetti 0.8.0`, `graphite 1.2.1`, `flutter_math_fork 0.7.4`, `syncfusion_flutter_pdf 34.1.31` — toutes dernières publiées, dormance documentée, plan B (`flutter_tex 5.2.7`) pour le maillon fragile. Excellent.

**Mais `printing`**, introduit *ex nihilo* par AD-42 (nouveau satellite `zcrud_export_ui`), **n'apparaît dans aucune entrée `(version)`** : ni version, ni vérification de currency, ni évaluation de la dormance, ni support plateforme (web/desktop). C'est la seule dépendance du spine qui n'a pas payé le prix d'entrée que le spine a fait payer aux cinq autres. Cf. F-4.

### 1.5 « Il ratifie plutôt qu'il ne contredit le code brownfield »

**Oui — le meilleur axe du spine.** Chaque décision est adossée à un fait d'investigation vérifié : AD-38 sur `FolderContentsOrder` lex, AD-33 sur la séparation sélecteur/runtime déjà en place, AD-40 sur le patron `nodeContentBuilder` existant, AD-41 sur `cellSize` 180x72 + court-circuit du mode compact, AD-42 sur `ZPdfCreationService.buildFromImages`. Les deux dettes constatées (orphelins `RepetitionInfo` lex, fire-and-forget IFFD) sont **corrigées consciemment**, pas héritées. AD-34 s'aligne sur le patron prouvé `ZWhiteExamSessionEngine` (`z_white_exam_no_srs_test`).

### 1.6 « Si un spec l'a piloté, il couvre les capacités de ce spec »

**Non — une FR entière manque.** Couverture des `Binds` déclarés :

| FR | AD porteur | FR | AD porteur |
|---|---|---|---|
| FR-SU1 | AD-40 | FR-SU12 | AD-33 |
| FR-SU2 | AD-35 | FR-SU13 | (AD-34/23 hérités) |
| FR-SU3 | AD-35, AD-36 | FR-SU14 | AD-38, AD-40 |
| FR-SU4 | *conventions (enum)* | FR-SU15 | AD-37 |
| FR-SU5 | *conventions (enum)* | FR-SU16 | AD-42 |
| FR-SU6 | AD-33 | FR-SU17 | AD-40, AD-41 |
| FR-SU7 | AD-33, AD-34 | FR-SU18 | AD-37 |
| FR-SU8 | *conventions (Reduce Motion)* | FR-SU19 | AD-39 *(partiel)* |
| FR-SU9 | *(AD-13 hérité)* | FR-SU20 | AD-39 *(partiel)* |
| FR-SU10 | AD-33 | **FR-SU21** | **— aucun** |
| FR-SU11 | *conventions (streak)* | | |

FR-SU4/5/8/9/13 sans AD sont **acceptables à l'altitude epic** (portés par les enums de la section Conventions et par AD-13/AD-10 hérités). **FR-SU21 est absent de bout en bout** : le mot « lecture seule », `isReadOnly` et « Dupliquer pour modifier » n'apparaissent nulle part dans le spine. Cf. F-3.

### 1.7 « Aucun nouvel AD n'affaiblit ou ne contredit un AD hérité »

**Oui.** AD-34 *renforce* AD-23 (garantie par le type plutôt que par convention, et refus explicite d'un `ZSessionReviewer` no-op comme porte dérobée). AD-38 se range sous AD-9/AD-19 (état personnel hors entité partagée). AD-40/42 respectent AD-1/AD-8. AD-33 verrouille la voie unique. Aucun affaiblissement détecté.

*Nit mécanique* : AD-42 invoque « patron **AD-8** » dans sa Rule, mais AD-8 n'est ni dans le `binds` du frontmatter ni dans la table « Invariants hérités » (à l'inverse d'AD-21/AD-23, correctement listés). Cf. T-3.

### 1.8 « Chaque dimension que l'altitude possède est décidée, différée, ou question ouverte »

**Deux dimensions silencieuses.**

- **Multi-édition** (la moitié du périmètre : epic E-MULTI-EDIT, FR-SU19/20) — cf. F-2. Une section « Placement des paquets » d'une ligne (« seul epic autorisé à écrire dans le cœur, une story à la fois ») n'est pas une décision d'architecture, c'est une règle de séquencement déjà présente dans CLAUDE.md.
- **Enveloppe opérationnelle / de distribution** — la dimension que la rubrique signale explicitement comme « celle qu'un brouillon centré domaine saute ». Pour une bibliothèque consommée **en dépendance git**, c'est la distribution : le spine **crée un package neuf (`zcrud_export_ui`)** sans rien dire de son enregistrement melos, de sa contrainte inter-packages (`^0.2.1`), de sa position vis-à-vis des gates CI (`codegen-distribution`, `graph_proof`, secrets), ni de son statut « optionnel » vis-à-vis du dry-run de compatibilité. NFR-SU10 n'est bound par aucun AD ni mentionné. Cf. F-5.

*Nit* : le diagramme « Placement des paquets » omet `zcrud_ui_kit` / `zcrud_responsive`, alors que la section Conventions y puise quatre seams réutilisés (`ZToaster`, `ZDiscardChangesGuard`, `ZAdaptiveGrid`, `ZItemActionsMenu`). Cf. T-6.

---

## 2. Réconciliation des entrées

### 2.1 (b) Points ouverts OA-1..6

| OA | Verdict | Où |
|---|---|---|
| OA-1 — LaTeX dans le PDF | ✅ **tranché** | AD-42 : `flutter_math_fork` → capture off-screen → `PdfBitmap`, derrière un port de rasterisation ; plan B `flutter_tex` porté au Deferred |
| OA-2 — label riche dans le graphe | ✅ **tranché** | AD-41 : borné à la cellule, troncature, jamais de mesure intrinsèque ; compact conserve le brut |
| OA-3 — persistance de l'ordre manuel | ✅ **tranché** | AD-38 : entité séparée générique, voie d'écriture unique, interdit `position` inline |
| OA-4 — mapping cramming | 🟠 **tranché à moitié** | AD-34 tranche `cramming` par un moteur dédié, mais **`list` et `test` restent sans moteur assigné** — or OA-4 porte le mapping des modes « sans écriture SRS » au pluriel. Cf. F-1 |
| OA-5 — contrats des ports et hooks | 🟠 **tranché sauf les hooks** | AD-35 (éval), AD-36 (indices), AD-37 (génération, FR-SU15+FR-SU18) sont nets. Le dernier item d'OA-5 — « **hooks de cascade de suppression FR-SU19** » — n'a pas de contrat : AD-39 renvoie à AD-21 sans définir le point d'extension app-side que FR-SU19 exige explicitement. Deux pertes de contrat vs le memlog : `quota?` (résultat de génération **et** d'éval) et `errorKind` typé `{offline, quotaExceeded, rateLimited, serviceUnavailable, network, server}` — les deux investigués côté lex, les deux absents d'AD-35/AD-37 |
| OA-6 — preview/impression/partage PDF | ✅ **tranché** (mais conséquence non tracée) | AD-42 : satellite `zcrud_export_ui`. La conséquence explicitement notée au memlog (« amender la contre-métrique PRD + OA-6 ») n'est pas portée. Cf. F-4 |

### 2.2 (a) FR/NFR sans invariant alors que deux stories peuvent diverger

| # | Exigence | Divergence possible | Sév. |
|---|---|---|---|
| F-1 | FR-SU7 + NFR-SU6 | modes `list`/`test` → quel moteur ? | HIGH |
| F-2 | FR-SU19 / FR-SU20 | toute la mécanique multi-édition + frontière brouillon | HIGH |
| T-1 | FR-SU2 | `min`/`max` sur échelle 0..5 vs 1..5 | MEDIUM |
| T-2 | FR-SU3 | défaut du plancher d'indices | LOW |
| T-4 | FR-SU5 | défaut de `ZCardAdvanceBehavior` **par mode** (auto en test/examen, manual en apprentissage/consultation) : la table de défauts n'est fixée nulle part | LOW |
| T-5 | FR-SU14 | « recherche **normalisée** (insensible accents/espaces) » : aucune règle de normalisation canonique ; la liste et le panneau de filtre du multi-éditeur peuvent normaliser différemment | LOW |
| F-5 | NFR-SU10 | distribution du nouveau package | MEDIUM |

### 2.3 (c) Décisions du memlog absentes du spine

| Décision memlog | Statut dans le spine |
|---|---|
| `(decision) AD(streak)` — « **Corrige l'imprécision 'remise à zéro' du PRD (FR-SU11) → amender le PRD en aval** » | Règle portée (reset à 1) ✅, **override du PRD non tracé** ❌ — le PRD dit toujours « remise à zéro », les deux textes cohabitent contradictoires |
| `(decision) AD(export)` — « **CONSÉQUENCE : amender la contre-métrique PRD 'pas de nouvelle dep au-delà des 2 décidées' (+printing confiné à zcrud_export_ui) et OA-6** » | Décision portée ✅, **conséquence non tracée** ❌ |
| `(override) AD-34 RÉVISÉ` — moteur dédié | Portée ✅ avec son rationale. Mais FR-SU7 dit littéralement « chacun mappé sur les moteurs existants…, **aucun nouveau moteur** » → **override du PRD non tracé** ❌ |
| `(decision) AD(génération IA)` — résultat « + suggestedTags **+ quota?** » | `quota?` **perdu** dans AD-37 |
| `(decision) AD(éval)` / faits lex — `errorKind` typé | **perdu** (AD-35 se contente des replis AD-10) |
| `(constraint) FAIT zcrud (OA-4)` — « **ATTENTION : mode ne conditionne pas le reviewer dans `ZStudySessionEngine`** » + « Invariant à tester : aucun mode non-SRS (**list/test**/whiteExam/cramming) n'atteint `reviewCard` » | **Le fait le plus dangereux du memlog, et le seul non porté** ❌ — cf. F-1 |
| Faits lex/IFFD sur l'ordre, la génération, les indices, la cascade, le streak | Tous portés fidèlement ✅ |

### 2.4 (d) Exigence qualitative discrètement perdue

Le PRD §1 énonce **deux** intentions qualitatives « qui guident toutes les exigences ». Le spine en porte une et perd l'autre :

- ✅ « **chaque app garde son identité visuelle** » → portée fidèlement par la convention `enums > booléens` et les quatre enums nommés. Bien vu.
- ❌ « l'API est calibrée **bi-consommateur** (IFFD + lex_douane) — **généricité au juste besoin, pas de sur-ingénierie multi-futur** » → **introuvable dans le spine**, alors que c'est précisément le garde-fou qui arbitre les décisions que le spine prend : dé-flashcardiser `ZContentOrder` (AD-38), ouvrir un registre de sources (AD-37), créer un package neuf (AD-42), ajouter un type public (AD-34). La contre-métrique associée (« pas d'explosion de l'API publique — chaque nouveau widget justifié par une ligne de la matrice ») disparaît avec elle. Sans ce garde-fou, chaque story arbitrera seule « générique ou pas », et le spine aura enseigné par l'exemple que la réponse est « générique ». Une ligne en Conventions suffirait.

---

## 3. Findings

### F-1 — HIGH — Les modes `list` (consultation) et `test` n'ont pas de moteur, et le memlog dit que le mode ne protège pas le reviewer

AD-34 assigne : `whiteExam` → `ZWhiteExamSessionEngine`, `cramming` → `ZCrammingSessionEngine`, « **seuls `spaced`/`learn` (`ZStudySessionEngine`) reçoivent un reviewer** ». Restent `list` et `test`, tous deux **non-SRS** au PRD (FR-SU7 : « consultation (sans SRS) » ; FR-SU12/FR-SU13 : test/examen sans écriture SRS ; FR-SU11 : streak exclu en consultation).

Le memlog établit deux faits qui se conjuguent :
1. « `ZReviewMode {spaced, learn, list, test, whiteExam, cramming}` existe » ;
2. « **ATTENTION : mode ne conditionne pas le reviewer dans `ZStudySessionEngine`** ».

Donc rien — ni type, ni règle du spine — n'empêche la story FR-SU13/FR-SU12 de construire `ZStudySessionEngine(mode: test, reviewer: reviewCard)` et d'écrire le SRS pendant un test. Le raisonnement même qui a justifié le revirement d'AD-34 (« le no-op est une valeur passable, donc l'invariant n'était garanti que par convention ») s'applique **à l'identique** à `list` et `test` — sauf qu'ici il n'y a même pas de convention.

L'invariant que le memlog demandait explicitement de tester — « aucun mode non-SRS (**list/test**/whiteExam/cramming) n'atteint `reviewCard` » — est donc tenu à moitié.

**Fix** : étendre la Rule d'AD-34 pour couvrir les quatre modes non-SRS (moteur sans paramètre reviewer, ou refus au constructeur de `ZStudySessionEngine` si `mode` n'est pas `spaced`/`learn`), et porter l'invariant de test au spine. C'est une ligne de Rule, pas un chantier.

### F-2 — HIGH — E-MULTI-EDIT est sans invariants, et AD-39 collisionne avec le brouillon de FR-SU20

Deux problèmes liés, sur l'epic qui est **le seul autorisé à écrire dans `zcrud_core`** (donc celui où une divergence coûte le plus cher).

**(a) Aucun AD ne couvre le cœur de FR-SU19.** Le spine tranche 10 décisions dont **9 pour E-STUDY-UI** ; FR-SU19 n'est touchée que par AD-39 (suppression). Restent sans invariant, alors que FR-SU19 (capacité moteur) et FR-SU20 (premier consommateur) seront **deux stories distinctes** qui doivent s'accorder :
- où vit l'**état de sélection** (mode sélection, « tout sélectionner », compteur) et qui le possède ;
- comment l'**édition de champ commun** se dérive du `ZFieldSpec` (quels types sont éligibles, où vit la validation par lot, quelle forme a le rapport d'échecs par élément) ;
- comment le modèle **déclare son champ de rattachement** pour « Déplacer » (annotation ? convention `ZFieldSpec` ? paramètre ?) ;
- le contrat du **slot d'actions de lot personnalisées** (registre AD-4 ? callback ?).

Chacun de ces quatre points est un choix que deux stories trancheront différemment, et trois d'entre eux touchent `zcrud_core`.

**(b) AD-39 et FR-SU20 se contredisent frontalement.** AD-39 : « **toute** suppression — unitaire comme par lot — passe par la cascade déclarative AD-21, **awaited**, avec rapport d'échecs par élément ». FR-SU20 : « toutes les modifications (édition par carte, ajouts, **suppressions**, applications groupées) s'appliquent immédiatement à une **liste de travail en mémoire** — **rien n'est persisté avant la sauvegarde finale groupée explicite** ».

Supprimer une carte dans le multi-éditeur, c'est donc soit violer AD-39 (pas de cascade awaited au moment du geste), soit violer FR-SU20 (persistance avant sauvegarde). L'intention d'AD-39 est manifestement la suppression **effective** (elle vise les dettes lex/IFFD), mais la Rule dit « toute ». Le spine ne nomme nulle part la **frontière brouillon ↔ persistance** — qui est pourtant *l'*invariant de FR-SU20 et exactement le genre de chose que la story FR-SU19 et la story FR-SU20 trancheront de deux façons incompatibles.

**Fix** : (1) un AD « multi-édition » fixant les 3-4 points de (a) ; (2) qualifier AD-39 (« toute suppression **persistée** … ; une suppression en brouillon ne persiste rien jusqu'au commit, qui passe alors par la cascade »).

### F-3 — MEDIUM — FR-SU21 (carte en lecture seule) n'existe pas dans le spine

`isReadOnly`, l'aperçu lecture seule et « **Dupliquer pour modifier** » ne sont mentionnés nulle part : ni AD, ni convention, ni Deferred, ni question ouverte. Or la sémantique de duplication est un point de divergence classique : la copie repart-elle à zéro côté SRS (état personnel, AD-9/AD-19) ? conserve-t-elle `source`/tags ? `isReadOnly` est-il remis à `false` ? La story « liste » (FR-SU14, qui affiche l'entrée) et la story « multi-éditeur » (FR-SU20, qui possède le cycle de vie d'édition) répondront séparément. À l'altitude epic, une ligne de Convention ou une entrée Deferred explicite suffit — le **silence** est le problème, pas l'absence d'AD.

### F-4 — MEDIUM — Trois overrides du PRD non tracés, dont une dépendance jamais vérifiée

Les trois overrides sont **justes sur le fond** (le memlog les argumente), mais aucun n'est signalé dans le spine, qui se lit donc comme s'il était aligné sur un PRD qu'il contredit sur trois points :

1. **AD-34 vs FR-SU7** : « aucun nouveau moteur » → un moteur nouveau (`ZCrammingSessionEngine`). Le rationale est excellent et présent dans le memlog en `(override)` ; il n'est pas dans le spine.
2. **Streak vs FR-SU11** : « remise à zéro » (PRD) → « reset à **1** » (spine). Le memlog écrit noir sur blanc « **amender le PRD en aval** » — non fait, et le spine ne signale pas qu'il s'écarte. Deux documents « final »/liants se contredisent.
3. **AD-42 vs contre-métrique PRD §6** : « pas de nouvelle dépendance tierce **au-delà des deux décidées** » et OA-6 « **pas de nouvelle dépendance type `printing` sans décision** » → AD-42 décide `printing`. Le memlog note « CONSÉQUENCE : amender la contre-métrique » — non fait.

**Aggravant sur (3)** : le spine a soumis `flutter_card_swiper`, `confetti`, `graphite`, `flutter_math_fork` et `syncfusion_flutter_pdf` à une veille datée (version courante, dormance, plan B) — mais **`printing` n'a jamais été vérifié** : aucune entrée `(version)`, pas de version épinglée, pas d'évaluation de maintenance ni de support plateforme. La rubrique « named tech is verified-current » échoue sur le seul choix que le PRD interdisait de faire sans décision. Par ailleurs le memlog relève que **lex ne fait ni preview ni impression** (partage `share_plus` via seam `PdfShareSink`) : le besoin bi-consommateur de `printing` mérite d'être établi, pas supposé.

### F-5 — MEDIUM — Enveloppe de distribution silencieuse pour le package neuf

La rubrique demande explicitement que l'enveloppe opérationnelle/environnementale ne soit pas sautée. Pour ce repo, elle est **la distribution en dépendance git** : code généré committé sous `packages/*/lib`, gates `codegen-distribution` / `graph_proof` / secrets, contraintes inter-packages (`^0.2.1`), dry-run de compatibilité lex_douane. NFR-SU10 la formalise ; **aucun AD ne la bind et le spine n'en dit rien** — alors qu'il **crée un package** (`zcrud_export_ui`), c'est-à-dire précisément l'événement qui touche cette enveloppe (enregistrement melos, versioning, position dans le graphe de gates, statut « optionnel » pour un consommateur qui ne l'importe pas). Une ligne dans « Placement des paquets » suffit.

---

## 4. Tail — MEDIUM/LOW

- **T-1 (MEDIUM)** — AD-35 : « QCM/VF exact → **max** sinon **min** » et « Je ne sais pas → **qualité min** » sont indécidables. Le memlog acte l'échelle zcrud **0..5** (`ZSrsConfig.passThreshold = 3`), le PRD (glossaire, FR-SU2) écrit **1..5** avec « Je ne sais pas = **1** » et IFFD répond en 1-5. `min` = 0 ou 1 selon la story. Ancrer sur `ZSrsConfig` explicitement, ou nommer les bornes.
- **T-2 (LOW)** — AD-36 perd le défaut « **plancher 2** » de FR-SU3 (garde « plancher configurable »). Fixer le défaut.
- **T-3 (LOW)** — AD-42 cite « patron **AD-8** » ; AD-8 n'est ni dans `binds:` ni dans la table « Invariants hérités » (contrairement à AD-21/AD-23, correctement portés). Ajouter, ou citer AD-1.
- **T-4 (LOW)** — FR-SU5 : la table des **défauts de `ZCardAdvanceBehavior` par mode** (auto en test/examen, manual en apprentissage/consultation) n'est fixée nulle part ; l'enum seul ne l'impose pas.
- **T-5 (LOW)** — FR-SU14 : la **normalisation de recherche** (insensible accents/espaces) n'a pas de règle canonique ; liste (FR-SU14) et panneau de sélection (FR-SU20) peuvent normaliser différemment.
- **T-6 (LOW)** — Le diagramme « Placement des paquets » omet `zcrud_ui_kit`/`zcrud_responsive`, d'où proviennent quatre seams réutilisés (`ZToaster`, `ZDiscardChangesGuard`, `ZAdaptiveGrid`, `ZItemActionsMenu`).
- **T-7 (LOW)** — AD-37 et AD-35 perdent `quota?` (présent dans la décision memlog `AD(génération IA)` et dans les deux contrats lex) et `errorKind` typé. Le repli AD-10 couvre la robustesse, pas la restitution du quota à l'UI.

---

## 5. Ce que le spine fait remarquablement bien (à ne pas casser en corrigeant)

- **AD-34** : le revirement no-op → moteur dédié, avec son rationale (« le no-op est une valeur passable, donc l'invariant n'était garanti que par convention+test, pas par le type ») et le refus explicite de fournir un `ZSessionReviewer` no-op comme porte dérobée. C'est de l'invariant-par-construction, le plus haut niveau d'enforçabilité.
- **AD-37** : `modelId` **opaque** — la règle qui interdit à zcrud de connaître un nom de modèle est vérifiable mécaniquement et tranche net une fuite d'app dans la bibliothèque.
- **AD-38** : la dé-flashcardisation de `FolderContentsOrder` en `{scopeId, Map<sectionKey, List<id>>}`, rangée sous AD-9/AD-19 (état personnel), avec la double affordance drag + Monter/Descendre sur **une seule** voie d'écriture.
- **La discipline d'investigation** : chaque AD est adossé à un fait vérifié en lecture seule sur lex/IFFD/zcrud, et les trois dettes constatées (orphelins `RepetitionInfo`, fire-and-forget à erreurs avalées, deux défauts de `typesDistribution` divergents) sont **corrigées** plutôt qu'héritées.
