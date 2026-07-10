# Rétrospective — Epic 9 : Flashcards (`zcrud_flashcard`)

- **Mode d'exécution** : skill réel `bmad-retrospective` invoqué via le tool `Skill` (workflow step-file chargé, args `epic-9`). Rétro conduite en mode **non-interactif** (subagent, pas d'utilisateur live) : les phases « party mode » du skill sont synthétisées en analyse écrite, la structure du workflow (epic discovery → deep story analysis → previous-retro continuity → next-epic prep → action items → readiness) est respectée. **Aucune écriture de `sprint-status.yaml`** (réservé à l'orchestrateur), **aucun commit**.
- **Date** : 2026-07-10
- **Package** : `zcrud_flashcard`
- **Périmètre couvert** : FR-16..FR-18 · AD-4 (extensibilité), AD-9 (offline-first / voie SRS unique), AD-10 (désérialisation défensive), AD-1 (isolation). Phase **v1.x**.
- **Sources lues** : `sprint-status.yaml`, epics.md (def E9), les 5 stories E9-1..E9-5 + leurs 5 code-reviews, architecture (AD-1/AD-4/AD-9/AD-10/AD-11/AD-14), rétros E5 / E10 / E11a / E11b (continuité des action items).

---

## 1. Statut & métriques de l'épic

| Story | Titre | Statut | Tests (cumulés) | Findings bloquants |
|-------|-------|--------|------------------|--------------------|
| E9-1 | `ZFlashcard` + `ZChoice` + `ZFlashcardType` + provenance registre | done | 27 | 0 (4 LOW) |
| E9-2 | SRS pluggable (`ZRepetitionInfo` + `ZSrsScheduler`, SM-2) | done | 59 (+32) | 0 HIGH/MAJEUR ; 1 MEDIUM justifié |
| E9-3 | Dossiers & sessions d'étude | done | 117 (+58) | 0 (3 LOW + 2 nits) |
| E9-4 | Dépôt offline-first + invariant SRS top-level | done | 135 (+18) | 0 HIGH/MAJEUR ; 1 MEDIUM déféré→E9-5 |
| E9-5 | Édition & widgets additifs (lex_douane) | done | 165 (+30) | 2 MEDIUM **corrigés** ; 2 LOW consignés |

- **Complétion** : 5/5 stories `done` (100 %). Épic **complet et vert**.
- **Couverture de test** : **165 tests** `flutter test` RC=0 sur `zcrud_flashcard` (croissance monotone, aucune régression story-à-story).
- **Gates transverses** : `graph_proof` ACYCLIQUE / **CORE OUT=0** ; `zcrud_flashcard → {annotations, core, export, generator, markdown}` — **aucune arête vers `zcrud_firestore`** (AD-1 tenu) ; grep AD-1 backend/manager/Syncfusion = 0 ; `verify:serialization` → SKIP **vert** (voir §3).
- **Findings HIGH/MAJEUR sur toute l'épic** : **0**. MEDIUM : 4 au total (2 justifiés par écrit E9-2/E9-4, 2 corrigés E9-5).

---

## 2. Réussites

**(a) Invariant SRS top-level tenu par construction (AD-9), pas seulement par convention.**
`ZFlashcard` ne déclare **aucun** champ SRS → `card.toMap()` ne peut structurellement pas en émettre. Le dépôt (E9-4) écrit l'état d'ordonnancement **exclusivement** via `ZRepetitionStore.put` (keyed par `flashcardId`), jamais via `_cards`. Prouvé par test : relecture de la map carte après `save + reviewCard` → 0 clé SRS ; carte partagée (`copyWith(id:null)`) → aucun état SRS hérité. La séparation carte/état SRS demandée par le canonique §2.7/§7 est garantie au niveau du **type**, pas d'un commentaire.

**(b) Voie d'écriture SRS UNIQUE respectée (AD-9).** Inventaire des méthodes publiques du dépôt : seules `initRepetition`/`reviewCard`/`resetRepetition`/`moveCard` touchent le store SRS ; seule `reviewCard → scheduler.apply` **avance** l'état. Le `copyWith` généré de `ZRepetitionInfo` est masqué par `hide ZRepetitionInfoZcrud` dans le barrel — la seule porte d'avancement algorithmique reste `apply()`.

**(c) SRS pluggable réellement remplaçable (FR-17).** `ZSrsScheduler` = `abstract interface class` (pas `sealed`), substitution inter-package prouvée par le `_FixedStepScheduler` de test qui produit un planning différent (1,2,3,4 vs 1,6,15,38) sur un modèle inchangé. `ZSrsConfig` injecté ; toutes les bornes/seuils lus depuis la config ; seuls les coefficients intrinsèques SM-2 sont hardcodés (définition même de « SM-2 »).

**(d) Désérialisation défensive bout-en-bout (AD-10), zéro throw parent.** Sur les 4 entités codegen (`ZFlashcard`, `ZRepetitionInfo`, `ZStudyFolder`, `ZStudySessionConfig`) : map vide, choix malformés, source `kind` inconnu, extension corrompue, `types`/`ease_factor`/`interval` du mauvais type, dates illisibles → replis sûrs, jamais de throw. Le canal hors-codegen (`source`/`extension`/`extra`) est correctement câblé **autour** du généré (sentinelle `_$undefined`, `_reservedKeys` dérivées des `$…FieldSpecs`, `copyWith` manuel couvrant les 3 canaux → perte silencieuse évitée).

**(e) Isolation AD-1 exemplaire sur 5 stories parallélisées.** Aucune story E9 n'a édité `zcrud_core` (les modifs `zcrud_core` visibles en `git status` relevaient des workstreams parallèles E5/E10, fichiers disjoints). Réutilisation du cœur (`ZEntity`, `ZExtensible`, `ZExtension`, `ZResult`, `DomainFailure`, `unit`) sans recréer aucun contrat.

**(f) Continuité des outils AI-E10/E11a confirmée (leçons outillées, plus seulement documentées).**
- **AI-E10-1 (helper a11y outillé)** — `assertSemanticActionTap` + `assertMinTapTarget` **copiés verbatim et consommés** par les widgets E9-5 (`ZFlashcardOptionTile`, toggle, boutons up/down/remove ; cibles ≥48 dp ; RTL testé).
- **AI-E10-2 (template de garde grep exhaustif)** — la garde FR-26/AD-13 d'E9-5 est cwd-robuste + strip-comment + méta-test (détecte un `Colors.` injecté), denylist complète.
- **AI-E10-3 (rebuild ciblé O(1), SM-1)** — prouvé sur l'éditeur QCM : contrôleurs/focus par ligne créés 1× / disposés / jamais recréés ; taper 100 caractères → `initA==1`, voisin non reconstruit, focus + identité contrôleur stables.
- **AI-E11a-1 (fabrique-par-montage)** — appliqué aux contrôleurs/focus des `_ChoiceRow`.

---

## 3. Point de friction n°1 (DÉCISIF) — Défaut latent CI `verify:serialization` RED, invisible aux gates par-package

**Ce qui s'est passé.** `zcrud_flashcard` ne déclarait **pas** `flutter: sdk: flutter` dans son bloc `dependencies` — le SDK Flutter était tiré **transitivement** via le barrel `package:zcrud_core/zcrud_core.dart` (qui ré-exporte la couche `presentation` → `dart:ui`). Or le gate CI `scripts/ci/verify_serialization.dart` détecte un package Flutter par la présence d'un `flutter:` **sous `dependencies:`** (`_isFlutterPackage`). Sans cette déclaration, le runner sélectionné était `dart` → `dart test` tentait de compiler des tests important `flutter_test`/`dart:ui` → **échec de compilation** (exit ≠ 79) → **gate `verify:serialization` RED**.

**Pourquoi il est resté invisible.** Introduit dès **E9-1** (première déclaration de package), il était **impossible à voir par les vérifs par-package** de dev : celles-ci lancent `flutter test` (qui compile parfaitement), pas le gate CI `verify_serialization.dart`. Le RED n'apparaît que sous un **`melos verify` REPO-WIDE**. Il a été révélé par le passage repo-wide de **E11b-1** (rétro E11b, tracé comme **AI-E11b-2**), qui a mécaniquement traversé tous les packages.

**Correction (E9-4).** Ajout explicite de `flutter: sdk: flutter` dans `dependencies` de `packages/zcrud_flashcard/pubspec.yaml` (même convention que `zcrud_mindmap`), avec commentaire documentant le raisonnement. Aucune dépendance runtime lourde ajoutée (le SDK était déjà tiré transitivement). Après fix : runner = `flutter` → `flutter test --tags serialization-compat` → exit 79 → **SKIP vert**. Vérifié empiriquement sur disque (SKIP réel) ; le sweep a confirmé que flashcard était **le seul** package fautif. **AI-E11b-2 est donc clos.**

**LEÇON (non-négociable).** Tout package Flutter — c'est-à-dire tout package dont les tests importent `flutter_test`, **ou** dont le `lib` tire le SDK Flutter au transitif via le barrel `zcrud_core` — **DOIT déclarer `flutter: sdk: flutter` dans `dependencies`**, sinon le gate CI aiguille sur `dart test` et casse silencieusement. Corollaire process : le **gate repo-wide au repos est non-négociable** — une vérif par-package (`flutter test`) NE détecte PAS ce type de défaut (le package « paraît » vert localement). C'est la **troisième confirmation empirique** du même méta-motif déjà documenté dans CLAUDE.md (`ZExportApi` E11a-3, RED cross-package E11b-1) : *un gate ciblé ne prouve QUE ce qu'il exécute sur le sous-graphe qu'il touche.*

---

## 4. Point de friction n°2 (bien géré) — Chaîne de dettes SRS/dossier tracée et purgée story-à-story

La rétro souligne une **chaîne de dettes correctement gérée**, sans report silencieux :

1. **E9-4 / MEDIUM M1** — `folderId` dénormalisé de la ligne SRS peut devenir périmé : `reviewCard` ignore le `folderId` passé quand un état existe (`apply` préserve `current.folderId`), donc après un déplacement de carte `getDue(folderId)` filtrerait sur un dossier périmé. **Déféré avec justification écrite** : E9-4 **n'expose aucune opération de déplacement** → aucun chemin ne rend le `folderId` périmé, aucun AC violé. Explicitement **rattaché à E9-5** (là où le move serait introduit) et consigné en dette.
2. **E9-4 / LOW L2** — `initRepetition` sans garde d'idempotence (un second appel écrase l'historique SRS). Footgun documenté, à trancher en E9-5.
3. **E9-5 introduit `moveCard`** → **corrige M1 en folder-only** : re-sync via `ZRepetitionInfo.withFolder(folderId)` (copie **sans aucun paramètre d'ordonnancement** — `interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`learnedAt`/`lastQuality` recopiés à l'identique) ; `getDue(new)` inclut / `getDue(old)` exclut ; carte sans SRS → aucun `put` ; carte absente → `Left(NotFoundFailure)`. AD-9 tenu par construction (aucun champ d'avancement ne bouge).
4. **E9-5 corrige L2** : `initRepetition` fait `getByCard` d'abord → no-op si présent (historique préservé) ; `resetRepetition` = reset explicite inconditionnel. La sémantique « créer » vs « réinitialiser » est désormais séparée.

Puis le **code-review E9-5** attrape 2 MEDIUM neufs, **corrigés avant `done`** (politique CLAUDE.md : MEDIUM corrigés par défaut si faisables dans le périmètre) :
- **MEDIUM-1** — surface d'erreur QCM révélée **sans gating de type** → message « Un QCM requiert au moins 2 choix » parasite sur une carte `openQuestion` (le widget `_buildErrorSurface` appelait `validateChoices` inconditionnellement, alors que `validate()` est type-gated). **Corrigé** : révélation gatée sur `coerceFlashcardType(controller.values[typeFieldName]) == multipleChoice` (aligné sur le validateur, source de vérité unique) ; test ajouté.
- **MEDIUM-2** — `moveCard` **avalait silencieusement** un `Left(CacheFailure)` du `put` SRS de re-sync (contredit l'invariant AD-11 « jamais silencieux » proclamé par le doc de classe ; asymétrie avec la branche `getByCard` loggée). **Corrigé** : `resynced.leftMap((f) => _log(...))` → best-effort loggé, carte reste déplacée ; test ajouté (fake `failPut`).

**Enseignement** : la discipline « déférer ≠ oublier » a fonctionné — chaque dette portait un **rattachement nominatif** (M1 → E9-5) et a été **effectivement purgée** à l'étape désignée. C'est le patron à reconduire.

---

## 5. Findings récurrents (motifs cross-story)

1. **Immutabilité partielle des slots `extra` (LOW récurrent E9-1/E9-3).** `_extraFrom` (voie `fromMap`) rend `extra` non-modifiable, mais une instance construite directement avec un `Map` mutable conserve un map modifiable ; `_mapEquals`/`_extraFrom` font une **égalité superficielle** des valeurs collection nichées dans `extra`. Patron **calqué à l'identique** d'`z_flashcard.dart` sur les 3 entités → non corrigé au niveau story (corriger une seule entité divergerait du patron du package). **Décision transverse à trancher hors story.**

2. **Défaut codegen figé vs config runtime (LOW E9-2).** Le repli de désérialisation `ease_factor ?? 2.5` est une **constante `const`** insensible à `ZSrsConfig(defaultEaseFactor: …)` — incontournable (le codegen `const` ne peut injecter une config runtime). Conforme à l'AC ; informationnel.

3. **Couverture a11y partielle en test (LOW-1 E9-5).** `assertSemanticActionTap` appliqué à `choice-correct-0` seulement, les autres cibles n'ayant que `assertMinTapTarget` (les widgets **sont** opérables en pratique). Manque de **rigueur de test**, pas défaut produit. C'est un rappel que l'exigence AI-E10-1 (« sur CHAQUE cible, pas un échantillon ») demande une vigilance active tant qu'elle n'est pas un *lint*/*helper de parcours exhaustif*.

4. **Preuves d'invariant par denylist plutôt qu'allowlist (LOW-3 E9-4).** Le test d'invariant SRS vérifie l'**absence** d'un ensemble **fixe** de clés — une future clé SRS nommée autrement passerait au travers. Reco : dériver l'ensemble interdit de `$ZRepetitionInfoFieldSpecs`.

---

## 6. Follow-up cross-cutting à trancher (LOW-1 E9-1, partagé flashcard + mindmap)

**Pureté AD-14 du barrel `zcrud_core`.** Les 4 APIs **pur-Dart** `ZEntity` / `ZExtensible` / `ZExtension` / `ZSourceRegistry` ne sont exportées que par le barrel principal `zcrud_core.dart` (qui ré-exporte la couche `presentation` → tire `dart:ui`), **pas** par la surface pure `edition.dart`. Conséquence : le domaine `zcrud_flashcard` (et déjà `zcrud_mindmap` en E10) doit importer le barrel Flutter → le domaine n'est **pas** Flutter-free au transitif et ne peut pas tourner sous `dart test` pur. **Non bloquant** (graphe acyclique, aucun state-manager/Firebase/Syncfusion importé, CORE OUT=0) et **forcé par le périmètre** (l'édition de `zcrud_core` était interdite dans ces stories parallélisées). C'est une **dette d'architecture du cœur**, pas une violation imputable à E9.

> **Décision à planifier hors epic-9** (petite story `zcrud_core`) : surfacer ces 4 types domaine purs sur un point d'entrée Flutter-free (soit `edition.dart`, soit un nouveau `contracts.dart`/`domain.dart`), puis rebasculer `z_flashcard.dart`/`z_flashcard_source.dart` **et** `zcrud_mindmap` vers cet import pur + `dart test`. C'est le **même défaut latent CI que §3** vu par l'autre bout : tant que le domaine tire Flutter, ces packages restent « Flutter » et dépendent du bon aiguillage `flutter: sdk: flutter`.

---

## 7. Continuité — suivi des action items antérieurs

| Action item | Origine | Statut en E9 |
|-------------|---------|--------------|
| **AI-E11b-2** — résoudre le RED latent `verify:serialization` de `zcrud_flashcard` | E11b (révélé par repo-wide) | ✅ **CLOS** — `flutter: sdk: flutter` ajouté en E9-4, gate → SKIP vert, seul package fautif (voir §3). |
| **AI-E10-1** — helper a11y outillé (`assertSemanticActionTap`/`assertMinTapTarget`) | E10 | ✅ **appliqué et consommé** sur les widgets E9-5 ; récurrence a11y non reproduite. |
| **AI-E10-2** — template de garde grep exhaustif (cwd-robuste, strip-comment) | E10 | ✅ **réutilisé** — garde FR-26/AD-13 E9-5 conforme (méta-test inclus). |
| **AI-E10-3** — vérif rebuild ciblé O(1) (SM-1) | E10 | ✅ **appliqué** — éditeur QCM E9-5 (100 car., voisin non reconstruit, focus/identité stables). |
| **AI-E11a-1** — fabrique-par-montage (ressource disposable possédée par `State`) | E11a | ✅ **appliqué** — contrôleurs/focus `_ChoiceRow` créés 1×/disposés. |
| **AI-E11b-1** — rejouer `melos analyze` + `verify` REPO-WIDE au gate d'epic | E11b | ⏳ **à exécuter par l'orchestrateur** au gate de commit E9 (workstreams au repos) — condition de clôture formelle (voir §9). |
| **AI-E5 (A1/A2)** — dettes réseau/serveur + requête→cache du patron offline-first | E5 | ⏳ **partiellement porté** — E9-4 consomme le patron offline-first E5 (délégation `_cards`/`_reps` typée `ZSyncableRepository`) ; les adaptateurs backend concrets restent déférés (frontière réseau/serveur à re-valider en E7). |

---

## 8. Préparation des épics suivants (E7/E8, publication REL)

Épic E9 est **v1.x** (pas sur le chemin critique MVP), mais ses livrables alimentent l'intégration apps et la publication.

**Dépendances sortantes / points d'attention pour E7 (DODLP) & E8 (lex_douane) :**
- **Adaptateur backend SRS déféré** — E9-4 pose un port flashcard-local `ZRepetitionStore` (collection top-level `study_repetitions/{cardId}`) mais **aucun adaptateur concret**. Point de vigilance archi signalé par E9-4 : si l'adaptateur concret est placé côté `zcrud_firestore`, une arête `zcrud_firestore → zcrud_flashcard` apparaîtrait — **à valider au moment de l'intégration** (graph_proof), pour ne pas casser CORE OUT=0 / l'acyclicité.
- **`overdueBonusFactor` inerte (LOW E9-2)** — champ `ZSrsConfig` déclaré mais non lu par `ZSm2Scheduler` (autorisé au MVP). À activer ou retirer lors d'un besoin app réel, pour ne pas devenir une constante morte. Généralise **AI-E11b-3** (« config surchargeable » exige un test prouvant qu'elle atteint le consommateur).
- **`getDue` ne remonte pas une carte sans ligne SRS (LOW L1 E9-4)** — l'inscription d'une carte à l'étude passe par `initRepetition` ; documenté, mais à garder à l'esprit lors du branchement du module « Étude » de lex_douane (E8) qui pourrait attendre une jointure cards×reps.
- **Widgets additifs, PAS de remplacement (UJ-4)** — E9-5 livre des widgets **paramétrés par l'entité de l'app**, additifs ; ils **ne remplacent pas** le module « Étude » existant. À respecter en E8.

**Pour la publication REL (v1.x) :** le fix `flutter: sdk: flutter` doit rester en place ; toute nouvelle entité codegen d'un package Flutter doit le déclarer d'emblée (checklist de création de package). Le follow-up §6 (`zcrud_core` pureté du barrel) est à trancher avant/pendant REL v1.x si l'on veut que flashcard+mindmap redeviennent testables sous `dart test`.

**Aucune découverte d'E9 ne remet en cause le plan des épics suivants** — pas de « significant change alert ». Les 4 points ci-dessus sont des dettes/vigilances tracées, non des remises en cause de scope.

---

## 9. Readiness — état réel avant clôture formelle de l'épic

| Dimension | État | Réserve |
|-----------|------|---------|
| Stories | 5/5 `done` | — |
| Tests par-package | `flutter test` **165** RC=0 | — |
| Isolation AD-1 | graph_proof ACYCLIQUE / CORE OUT=0, grep=0 | — |
| Gate `verify:serialization` | SKIP **vert** (fix E9-4 vérifié sur disque) | — |
| Findings ouverts | **0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert** | 2 MEDIUM justifiés (E9-2/E9-4→purgé E9-5), 2 corrigés (E9-5) |
| **Gate REPO-WIDE** | ⏳ **À rejouer par l'orchestrateur** (`melos run analyze` + `melos run verify`, workstreams au repos) | **Condition NON-NÉGOCIABLE avant `done` d'épic / commit** (AI-E11b-1) — une vérif par-package NE détecte PAS une régression cross-package. |

**Conclusion readiness** : Epic E9 est **complet et vert au niveau package**. La **seule** action restante avant clôture formelle (`epic-9` → `done`) et commit de fin d'épic est le **gate repo-wide** rejoué par l'orchestrateur une fois tous les workstreams parallèles au repos — précisément la leçon centrale de cette épic (§3).

---

## 10. Action items

| ID | Libellé | Catégorie | Owner |
|----|---------|-----------|-------|
| **AI-E9-1** | **Rejouer `melos run analyze` ET `melos run verify` REPO-WIDE au gate de fin d'épic E9** (workstreams au repos) avant tout `done`/commit — reconfirmer `verify:serialization` vert sur TOUS les packages, pas seulement flashcard. Clôt AI-E11b-1 pour E9. | Process / CI | Orchestrateur |
| **AI-E9-2** | **Checklist de création de package Flutter** : tout package dont les tests importent `flutter_test` OU dont le `lib` tire le SDK via le barrel `zcrud_core` DOIT déclarer `flutter: sdk: flutter` dans `dependencies` dès sa création (sinon le gate CI aiguille sur `dart test` et casse silencieusement). Généralise la leçon §3. | Process / CI | Dev |
| **AI-E9-3** | **Follow-up `zcrud_core` (cross-cutting, hors E9)** : surfacer `ZEntity`/`ZExtensible`/`ZExtension`/`ZSourceRegistry` (4 APIs pur-Dart) sur un point d'entrée Flutter-free (`edition.dart` ou nouveau `contracts.dart`), puis rebasculer `zcrud_flashcard` + `zcrud_mindmap` vers cet import pur + `dart test`. Petite story `zcrud_core` à planifier v1.x. | Archi | Dev / Archi |
| **AI-E9-4** | **Helper d'égalité profonde partagé pour les slots `extra`** (+ `Map.unmodifiable` au constructeur) : décision transverse pour toutes les entités codegen (`z_flashcard`/`z_study_folder`/`z_study_session_config`…) plutôt qu'un patch par entité qui divergerait du patron. | Dev | Dev |
| **AI-E9-5** | **Renforcer les preuves d'invariant en allowlist** : dériver l'ensemble de clés interdites du `$…FieldSpecs` (test invariant SRS AC2 E9-4) plutôt qu'une denylist fixe ; étendre `assertSemanticActionTap` à CHAQUE cible QCM (LOW-1 E9-5). | Test / Review | Dev |
| **AI-E9-6** | **Valider l'arête backend SRS à l'intégration** : lors du branchement de l'adaptateur concret `ZRepetitionStore` (E7/E8), rejouer `graph_proof` pour garantir qu'aucune arête `zcrud_firestore → zcrud_flashcard` ne casse CORE OUT=0 / l'acyclicité. Statuer aussi sur `overdueBonusFactor` (activer ou retirer) et sur `getDue` sans ligne SRS. | Archi / Dev | Dev (E7/E8) |

---

## 11. Synthèse (3-5 points clés)

1. **Épic techniquement irréprochable** : 5/5 stories `done`, **165 tests** verts, **0 HIGH/MAJEUR/MEDIUM ouvert**, AD-1/AD-9/AD-10 tenus **par construction** (invariant SRS top-level, voie d'écriture unique, défensif zéro-throw).
2. **La leçon centrale est un défaut *process*, pas *code*** : le RED CI `verify:serialization` (manque de `flutter: sdk: flutter`, aiguillage `dart test`) était **invisible aux vérifs par-package** et n'a été révélé que par un `melos verify` repo-wide (E11b-1). Corrigé en E9-4, **AI-E11b-2 clos**. Le **gate repo-wide au repos reste non-négociable** (3ᵉ confirmation empirique du méta-motif).
3. **Gestion de dette exemplaire** : la chaîne E9-4 (M1 folderId périmé, L2 idempotence — déférés avec **rattachement nominatif**) → E9-5 (`moveCard` folder-only corrige M1, `getByCard` corrige L2) → code-review E9-5 (2 MEDIUM QCM parasite + Left avalé **corrigés avant `done`**). « Déférer ≠ oublier » a fonctionné.
4. **Outillage AI-E10/E11a réutilisé et efficace** : helper a11y (AI-E10-1), garde grep (AI-E10-2), rebuild O(1) (AI-E10-3), fabrique-par-montage (AI-E11a-1) — les récurrences de findings des épics précédentes ne se reproduisent pas.
5. **Une dette d'archi du cœur à trancher hors épic** (LOW-1 E9-1, partagée flashcard+mindmap) : les 4 APIs pur-Dart de `zcrud_core` ne sont surfacées que côté Flutter → follow-up `zcrud_core` (AI-E9-3), lié au même défaut d'aiguillage que §3.

**Action items** : AI-E9-1 (gate repo-wide, **condition de clôture**), AI-E9-2 (checklist package Flutter), AI-E9-3 (follow-up pureté `zcrud_core`), AI-E9-4 (égalité profonde `extra`), AI-E9-5 (preuves allowlist + a11y exhaustif), AI-E9-6 (arête backend SRS à l'intégration E7/E8).
