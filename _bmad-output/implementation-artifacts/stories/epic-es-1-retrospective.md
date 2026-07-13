# Rétrospective — Epic ES-1 : Fondations `zcrud_study_kernel` + remontée `ZStudyFolder`

- **Date** : 2026-07-13
- **Mode** : skill BMAD **`bmad-retrospective` réellement invoqué** via le tool `Skill` (pas de fallback disque). Exécution en **sous-agent non interactif** : les steps de dialogue party-mode (6–8, 10–11) sont dérivés du disque (stories, code-reviews, architecture, epics, inventaire) au lieu d'être joués en conversation ; **aucune écriture du `sprint-status.yaml`** (réservé à l'orchestrateur).
- **Epic** : ES-1 — 4 stories `done` (ES-1.1, ES-1.2, ES-1.3, ES-1.4). Premier epic de la phase **zcrud_study**.
- **Epic suivant** : **ES-2 — Domaine canonique éducatif + codegen** (~8 entités nouvelles). C'est le terrain exact où le motif de cet epic se rejouerait.

---

## 1. Ce qui a été livré

| Story | Livrable | Cœur du travail |
|---|---|---|
| **ES-1.1** | Package `zcrud_study_kernel` (15ᵉ package) | Remontée de `ZStudyFolder` + `validatePlacement` + `ZReviewMode` + `ZStudySessionConfig`/`Selector` depuis `zcrud_flashcard`. **Découplage acyclique** non prévu par le littéral d'AD-18 : `types: List<ZFlashcardType>?` → `List<String>?` (wire byte-identique) et port neutre **`ZSessionCandidate`** implémenté par `ZFlashcard`. Refactor non-régressif + réexport transitoire. |
| **ES-1.2** | 3 utilitaires purs + 1 seam cœur | `ZColorPalette` (registre borné + remap **FNV-1a 32 JS-safe**, zéro `Color` dans le kernel), `applyOrder<T>` (tri stable pur), `normalizeTagTitle`/`dedupeByNormalizedTitle`. Seam `ZColorKeyResolver`/`ZColorPair`/`ZColorSlot` + `ZcrudScope.colorKeyResolver` dans `zcrud_core`. Narrowing `hide` du réexport kernel (solde LOW-1 d'ES-1.1) + **garde outillé** de surface. |
| **ES-1.3** | Convention `ZSyncMeta` hors-entité verrouillée (OQ #3 **tranchée**) | Clés réservées en **membres statiques** de `ZSyncMeta` (`kUpdatedAt`/`kIsDeleted`/`reservedKeys`/`stripReserved`) — zéro nouveau symbole public. Correction de la fuite `is_deleted`/`updated_at` dans `extra` sur **4 entités** (dont 2 découvertes en revue). Miroir `ZStudyFolder.updatedAt` déprécié. **Test STAR** d'autorité de la méta. AD-19.1 / AD-19.1.a / AD-19.1.b / AD-19.1.c / AD-19.2 écrites. |
| **ES-1.4** | Infra de gates exécutoire | **`gate:reserved-keys`** (volet A comportemental via harnais `tool/reserved_keys_gate/` + volet B **AST `package:analyzer`** + contrôle de couverture anti-omission), `gate:web` **généralisé** (plus de chemin en dur), `verify:serialization` **SKIP bruyant + interrupteur** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`, CI refondue en **step unique `melos run verify`** + `actions/setup-node`. |

### Métriques réelles (rejouées sur disque par l'orchestrateur, jamais sur la foi d'un agent)

| Mesure | Avant ES-1 | Après ES-1 |
|---|---|---|
| Packages (`melos list`) | 14 | **15** (+ `zcrud_study_kernel`) |
| Harnais hors-`packages/**` | 1 (`binding_conformance`) | **2** (+ `reserved_keys_gate`) |
| Tests `zcrud_flashcard` | 165 (baseline E9) | **189** |
| Tests `zcrud_study_kernel` | — | **108** (VM) / **98** (node/JS) |
| Tests `zcrud_core` | 890 | **911** |
| Tests `zcrud_firestore` / `zcrud_mindmap` | 90 / 110 (E5/E10) | **90 / 110** (non régressés, entités corrigées) |
| Scripts melos (`gate:melos`) | 13 | **15** |
| Gates dans `verify` | 7 | **9** (`gate:web` + `gate:reserved-keys`) |
| Fixtures `prove_gates` | 23 | **32 OK / 0 FAIL** (26 à la livraison dev d'ES-1.4, **+6 en remédiation** pour isoler la règle de couverture) |
| Graphe AD-1 | acyclique, 14 nœuds | **acyclique, 15 nœuds, `CORE OUT=0`** — arête `flashcard → study_kernel → core`, **aucune** arête retour |
| Déterminisme web | non vérifié | **vérifié en CI** (Node installé, `gate:web` réellement exécuté) |

**Findings de code-review sur l'epic** : **3 HIGH** (H1/H2 d'ES-1.3, H1 d'ES-1.4) · **12 MEDIUM** · **12 LOW**. Tous les HIGH et 11/12 MEDIUM corrigés et **prouvés par injection de régression** ; 1 MEDIUM reporté avec justification écrite (M5 → ES-1.4, qui l'a soldé).

---

## 2. Le motif central : **« le filet existait, il n'était pas accroché » — cinq fois**

| # | Étage | Le filet existait… | …mais |
|---|---|---|---|
| 1 | **Entités** (ES-1.3, H1/H2) | `ZSyncMeta.reservedKeys` était défini | **2 entités sur 4** ne le consommaient pas — **sous 1193 tests verts**. L'une était `ZRepetitionInfo`, que la doc venait de désigner « **exemplaire de référence** » : l'exemplaire violait la règle qu'il illustre. |
| 2 | **Règle** (ES-1.3, M5) | AD-19.1 était écrite, normative, précise | **aucune machine ne la vérifiait**. C'est exactement ce qui a laissé passer (1). |
| 3 | **CI** (ES-1.4) | `gate:web` était écrit **et prouvé localement par injection** (ES-1.2) | **jamais invoqué dans `ci.yml`** (qui énumérait les gates à la main au lieu d'appeler `melos run verify`) — **et Node n'était pas installé**. Le gate SKIPait silencieusement **à chaque build depuis ES-1.2**, pendant que son propre dartdoc affirmait le contraire. |
| 4 | **Spec figée** (ES-1.4) | AD-19.1.c était figée, détaillée, déclarée « exécutoire » | `registry.decode` **ne peuple pas `extra`** ⇒ le gate censé prévenir (1) aurait été **vacuellement vert** (assertion (a) portant toujours sur un `extra` vide). La lettre de la spec produisait un faux vert. |
| 5 | **Le gate lui-même** (ES-1.4, H1) | le contrôle de couverture `E_disk \ E_covered` existait | **regex ligne-à-ligne aveugle** à 3 formes de déclaration légales — dont **celle que `dart format` produit lui-même** au-delà de 80 colonnes. *Le gate qui impose « accrochez le filet » avait son propre filet décroché.* Détail révélateur : c'était **la seule des 3 règles de couverture sans fixture propre** dans `prove_gates` — 26 OK / 0 FAIL **sans qu'aucun cas ne l'exerce isolément**. |

### La CAUSE COMMUNE

> **Un artefact de vérification a été déclaré valide sur la base de son EXISTENCE, jamais sur la base de son POUVOIR DISCRIMINANT observé.**

Les cinq occurrences sont la même erreur épistémique, à cinq étages différents :

1. On a produit un artefact censé attraper un défaut : une constante (`reservedKeys`), une règle (AD-19.1), un script (`gate:web`), une spécification (AD-19.1.c), un contrôle de couverture (règle 3).
2. On a **constaté qu'il était là** (le code compile, l'AD est écrite, le script existe, la spec est figée, `26 OK / 0 FAIL`).
3. On n'a **jamais observé l'artefact ROUGIR sur le défaut exact qu'il existe pour prévenir**.
4. Le vert obtenu n'était donc pas une preuve d'absence de défaut, mais **une absence de preuve** — indistinguable, de l'extérieur, d'un vrai vert.

**Asymétrie systématique de notre chaîne de vérification** : nous testions abondamment que **le code correct passe** ; nous ne testions jamais que **le code incorrect échoue**. Or seule la seconde propriété a une valeur informative pour un filet. Un test qui passe sur du code sain ne dit rien ; un test qui ne rougit pas sur du code malade **ment**.

**Aggravant structurel** : un faux vert est **auto-renforçant**. Il produit exactement le signal (vert) que le processus consomme pour décider d'avancer. Plus il dure, plus il accumule de « preuves » de sa propre validité — 1193 tests verts sur des entités fuyantes, `26 OK / 0 FAIL` sur une règle jamais exercée, une CI verte sur un gate qui n'a jamais tourné. **Aucune quantité de vert ne peut détecter un faux vert. Seul un rouge provoqué le peut.**

**Ce qu'il faut changer dans le PROCESSUS** : la définition de « fait » pour tout artefact de vérification doit passer de *« il existe et la suite est verte »* à *« je l'ai vu échouer, sur cette régression précise, et le rouge a été rejoué par l'orchestrateur »*. C'est le seul geste qui casse l'auto-renforcement.

---

## 3. Règles actionnables, applicables **dès ES-2** (NON NÉGOCIABLES)

ES-2 crée **~8 entités canoniques** (`ZStudyDocument`, `ZSmartNote`, `ZFlashcardTag`/`ZSuggestedTag`, `ZFolderContentsOrder`, `ZDocumentAnnotation`, `ZExam`, `ZStudySessionResult`/`ZDailyStudyTask`, `ZStudyPodcast`) — c'est **précisément le terrain** du motif ci-dessus (8 occasions de reproduire l'oubli d'ES-1.3 H1/H2, sur des entités dont plusieurs seront **écrites à la main**, cas exact de la cécité H1 d'ES-1.4).

### R1 — Toute règle d'architecture naît **avec son gate**, ou elle n'est pas normative

Une AD sans machine qui la vérifie n'est pas une règle, **c'est un vœu** (leçon n°2). Interdiction d'écrire une AD prescriptive (« toute entité DOIT… ») sans, **dans la même story ou dans une story explicitement nommée en dette bloquante**, le gate qui la rend exécutoire. Une AD normative sans gate porte obligatoirement, en toutes lettres, la phrase : *« NON APPLIQUÉE PAR MACHINE — gate dû en \<story\> ; jusque-là, cette règle sera violée sans signal. »*

### R2 — Tout gate naît **avec sa fixture d'échec, isolée par règle**

Un gate à N règles exige **N fixtures**, une par règle, chacune **verte sur toutes les autres règles** pour que seule la règle visée puisse la faire rougir. Une fixture qui déclenche 2 règles à la fois ne prouve **aucune des deux** (c'est exactement ce qui a masqué H1 d'ES-1.4 : `fixture-syntaxique` rougissait via le volet B, donc la règle de couverture n'a jamais été exercée seule). **`prove_gates.dart` est le lieu de ces fixtures** — permanentes, jamais éphémères, jamais dans le scratchpad.

### R3 — Aucun gate n'est `done` sans **injection de régression rejouée par l'orchestrateur**

*Un filet qu'on n'a pas vu échouer n'est pas un filet.* Le protocole (déjà appliqué 4 fois dans cet epic, à généraliser) : (1) casser volontairement le code réel que le gate protège, (2) constater le **ROUGE** et **coller la sortie brute** dans les Completion Notes, (3) restaurer **à l'octet près** (`diff` vide), (4) constater le **VERT**, (5) **l'orchestrateur rejoue lui-même 1→4** — le rapport de l'agent ne vaut rien. Pour ES-2 : chaque nouvelle entité passe par une injection « retirer `...ZSyncMeta.reservedKeys` » **au moins une fois sur le lot**.

### R4 — Toute spec figée est validée par un **prototype exécutable** avant d'être déclarée normative

AD-19.1.c a été figée « prête à implémenter » avec une faille (`registry.decode` ne peuple pas `extra`) qui aurait rendu le gate vacuellement vert, et une seconde (cast `as ZExtensible` sur `ZChoice`) qui l'aurait fait crasher. **Coût de découverte de ces deux failles : une story entière.** Coût d'un spike de 10 lignes en amont : nul. Règle : une spec qui prescrit un **appel d'API précis** (`registry.decode(...)`, `entity as X`) doit avoir été **exécutée une fois** sur l'arbre réel avant d'être écrite comme normative. Sinon elle est écrite en **intention** (« décoder par la voie qui peuple `extra` »), pas en **littéral d'API**.

### R5 — Aucun scan **textuel** (regex) pour reconnaître une structure Dart

H1 d'ES-1.4 : la regex ligne-à-ligne était aveugle à l'en-tête enroulée **que `dart format` produit lui-même**, aux modificateurs Dart 3 (`final`/`base`/`sealed`/`interface`), et à l'alias de classe. Une « regex plus grosse » aurait reconduit la fragilité. Tout gate qui raisonne sur des **déclarations Dart** parse via **`package:analyzer` (AST)** ; un fichier non parsable est un **ÉCHEC**, jamais un skip. Corollaire : le câblage d'un harnais se lit comme une **valeur** (éléments de littéral), jamais comme une **mention textuelle** (M3 d'ES-1.4).

### R6 — Aucun mécanisme de **dégradation silencieuse**

Trois faux verts sur cinq viennent d'un skip qui n'a pas crié : `gate:web` sans Node, `exit 79` toléré, `verify:serialization` sans corpus. Règle : tout skip est **BRUYANT** (bannière nommant ce qui n'a PAS été vérifié + la story qui le doit), **refusé sous `CI=true`**, et tout « aucun test exécuté » (`exit 79`) est **FATAL** dans un gate d'autorité. Un interrupteur d'environnement qui **verdit** un gate est un secours de poste de dev, **jamais** un échappatoire de CI.

### R7 — Aucune liste de gates dupliquée ; la CI appelle **un step unique**

La dérive « gate présent dans `verify`, absent de `ci.yml` » est désormais **impossible par construction** (`ci.yml` → `dart run melos run verify`). À préserver : **jamais** de ré-énumération des gates ailleurs. Idem pour `pubspec.yaml` (source de vérité) / `melos.yaml` (miroir), gardés par `gate:melos`.

### R8 — Toute nouvelle entité ES-2 est **câblée au gate dans la même story**

Contrat d'extension (déjà documenté dans le harnais) : créer une entité ⇒ ajouter son `registerZXxx` à `kRegistrars` **et** son corps à `kProbeBodies` (+ `kDomainDecoders`) ; une entité écrite à la main ⇒ `manual_probes.dart`. **L'oublier est ROUGE** (contrôle de couverture AST). La story n'est pas `done` si le gate n'a pas été vu rougir sur au moins une des entités qu'elle crée. **Checklist par entité ES-2** :
- [ ] `_reservedKeys ⊇ ...ZSyncMeta.reservedKeys` (AD-19.1) ;
- [ ] `$XxxFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` — **aucun champ métier** sous `updated_at`/`is_deleted` (AD-19.1.a : clé distincte `edited_at`/`published_at`/`reviewed_at`) ;
- [ ] **aucun** `persistAs: timestamp` sur une clé réservée (AD-19.1.b) ;
- [ ] câblage du harnais `reserved_keys_gate` fait dans la **même** story ;
- [ ] round-trip `extra` (clé inconnue préservée) testé — l'assertion (b) est l'**anti-vacuité** de (a) ;
- [ ] désérialisation défensive AD-10 (champ absent/corrompu ⇒ défaut sûr, **jamais** de throw).

### R9 — La vérif verte est rejouée **repo-wide** et **par l'orchestrateur**, à chaque gate de commit

`melos run analyze` **ET** `melos run verify` repo-wide (leçon `ZExportApi` d'E11a-3 : la vérif par package **ne voit pas** une régression cross-package). Un `graph_proof`/`melos list`/`secrets` vert **ne remplace pas** `melos analyze`. Et — leçon ES-1.4 — **aucun rapport d'agent ne vaut preuve** : l'agent de remédiation a planté (`API Error`) sans rendre de rapport ; l'orchestrateur a vérifié l'intégralité de l'état sur disque et a trouvé un arbre cohérent. La règle a payé.

---

## 4. Ce qui a bien marché (à conserver tel quel)

1. **Investigation disque réelle en `create-story`.** ES-1.1 a découvert le **couplage retour** (`ZStudySessionConfig.types → ZFlashcardType`, `Selector → ZFlashcard`) que la formulation d'AD-18 (« remonter les 4 types ») masquait ; un déplacement verbatim aurait créé le cycle interdit. ES-1.3 a découvert que `ZSyncMeta` **existait déjà** (l'epic disait « si absent »), évitant un doublon et un réexport toxique. **Les stories qui lisent le disque avant d'écrire trouvent les vraies contraintes ; celles qui paraphrasent l'epic écrivent des specs fausses.**
2. **Revue adversariale qui COMPILE et EXÉCUTE au lieu de raisonner.** ES-1.2 : le déterminisme web de `zFnv1a32` a été **prouvé par `dart compile js` + Node** (et la variante naïve démasquée : elle passe les 3 vecteurs golden **sur la VM** et diverge sur le web). ES-1.3 : H1/H2 prouvés par **sondes jetables exécutées**. ES-1.4 : `exit 79 == 79` **mesuré** (le premier essai mesurait `tail` et rendait un faux `EXIT=0` — ironie notée). ES-1.3 : la sévérité de `deprecated_member_use` prouvée par `dart analyze` réel. **Aucun de ces défauts n'était trouvable par raisonnement.**
3. **Injection de régression comme critère de clôture.** Elle a fonctionné 4 fois (M1 d'ES-1.2 : variante naïve → JS rouge ; L4 d'ES-1.2 : `hide` amputé → garde rouge ; ES-1.3 : sondes rouges sans correctif ; ES-1.4 : 2 entités + 3 formes de déclaration). **C'est la seule technique qui a jamais attrapé un faux vert dans cet epic.**
4. **Vérif verte rejouée par l'orchestrateur, indépendamment de l'agent.** A payé littéralement (agent planté en ES-1.4).
5. **Tranchages fermés en amont dans la story (D1/D2/D3…), avec justification à recopier en Completion Notes.** Le dev n'a rejoué aucune décision ; les revues ont pu auditer l'**intention** autant que le code.
6. **Corrections structurelles plutôt que rustines.** Regex → AST (refus explicite d'une « regex plus grosse ») ; liste de gates dupliquée → step unique ; clés dupliquées kernel/cœur → pont par un **entier** (`ZColorSlot`), pas par une liste de `String` répliquée ; littéraux `'updated_at'` × 4 sites → `ZSyncMeta` (DW-ES13-1 soldée en bonus).
7. **Politique de modèle corrigée en cours d'epic sur preuve empirique.** ES-1.2 (seule story en Sonnet) a coûté **deux passes de dev au lieu d'une** (4 MEDIUM en remédiation). Cause racine : **Sonnet suit la spec fidèlement, failles comprises** — et la spec elle-même portait le défaut (seam qui ne compose pas, vecteurs golden sans exécution web). Retour au **tout-Opus** pour le cycle BMAD (inventaire §0, décision 5). *Note : ce n'est pas un procès de Sonnet — c'est la démonstration que dans ce dépôt, **la spec est faillible et le dev doit la remettre en cause**. Le « portage mécanique » y est largement illusoire.*

---

## 5. Dettes ouvertes et **ordonnancement**

| Dette | Sévérité | Nature | Quand |
|---|---|---|---|
| **DW-ES14-1** — `registry.decode` **DÉTRUIT `extra`** (AD-4 cassé sur la voie registre) | 🔴 **BLOQUANTE** | `zcrud_generator` émet `fromMap: _$ZXxxFromMap` (factory codegen, ignore `extra`) au lieu de `ZXxx.fromMap` (factory domaine, la peuple). `FirebaseZRepositoryImpl.fromRegistry` — fabrique **publique, présentée comme « la voie stricte »** — perd donc **silencieusement et irréversiblement** toutes les clés métier inconnues à chaque cycle lecture→écriture. **Latent aujourd'hui** (zéro appelant), **destructif dès la première adoption**. | **Story dédiée à ouvrir AVANT tout câblage du store — c.-à-d. avant ES-3.2/ES-3.5.** Peut être traitée **pendant ES-2** (packages disjoints : `zcrud_generator` + `zcrud_firestore`, aucune écriture du kernel). **Critère de clôture** : round-trip `registry.decode → registry.encode` préservant une clé inconnue **pour chaque kind**, câblé comme **5ᵉ assertion (e)** du volet (A) de `gate:reserved-keys` — ce qui supprimera du même coup la déviation `kDomainDecoders`. |
| **DW-ES13-2** — `ZFlashcard.updatedAt` non déprécié | 🟡 LOW | Miroir de compat toléré (surface E9 consommée par la migration DODLP). Deux conventions visibles simultanément (L2 d'ES-1.3). | **Re-statuer en ES-2 ou ES-11.** Sortie de `kLegacyUpdatedAtMirrors` (le **test de verrou** rendra le geste visible). |
| **L3 d'ES-1.3** — les `*.g.dart` lisent le membre déprécié | 🟡 LOW | Invisible **conditionnellement** (`analysis_options` exclut `**/*.g.dart`). Si l'exclusion saute ou si la CI passe `--fatal-infos`, l'analyse rougit sur du code **non éditable**. | **Opportuniste** — piste : faire émettre `// ignore_for_file: deprecated_member_use` par `zcrud_generator` **en même temps que DW-ES14-1** (même package, même story). |
| **L2 d'ES-1.2** — `ZColorPalette.keys` exposée mutable | 🟡 LOW | `List.unmodifiable` absent, mais **aucune convention du repo** ne l'impose ; corriger localement créerait une incohérence. | **Différée** — à traiter globalement si/quand une convention est adoptée. |
| **L4 d'ES-1.2 / ES-1.3** — `ZSyncMeta.stripReserved` sans appelant | ✅ **SOLDÉE** | Le volet (A) de `gate:reserved-keys` en fait la **définition machine unique** du dépouillement. | — |
| **DW-ES13-1** — 4 sites à littéraux durs | ✅ **SOLDÉE** (bonus ES-1.3) | Plus **aucun** littéral `'updated_at'`/`'is_deleted'` en code hors `z_sync_meta.dart`. | — |
| **M5 d'ES-1.3** — AD-19.1 sans application machine | ✅ **SOLDÉE** (ES-1.4) | `gate:reserved-keys` câblé dans `verify` ⇒ en CI par construction. | — |
| **ES-3.5** — corpus de rétro-compat de sérialisation | 🟡 Planifiée | Point d'accroche **prêt** (`dart_test.yaml`, tag `serialization-compat`) + interrupteur `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` (bascule SKIP → ÉCHEC **sans toucher au script ni au workflow**). | **ES-3.5** — activer l'interrupteur en CI **fait partie du `done`**, sinon le SKIP bruyant devient un faux vert de plus. |

**Ordre recommandé** : **DW-ES14-1 (story dédiée, en parallèle d'ES-2 — packages disjoints) → ES-2 → ES-3**. Câbler le store en ES-3 sur un `registry.decode` destructeur transformerait une dette latente en **perte de données irréversible**.

---

## 6. Risques pour ES-2 (~8 entités canoniques), au vu de ce qu'on a appris

| # | Risque | Ce que l'epic ES-1 nous en apprend | Contre-mesure (déjà en place ou à poser) |
|---|---|---|---|
| **R-A** | **L'oubli de `...ZSyncMeta.reservedKeys`** sur une des 8 entités | Il s'est produit **2 fois sur 4** en ES-1.3, **sous 1193 tests verts**, dont sur l'« exemplaire de référence » | ✅ **`gate:reserved-keys` mord désormais** (prouvé par injection). ⚠️ **Ne PAS s'en contenter** : appliquer **R8** (câblage du harnais dans la même story) — *une entité non câblée n'est pas sondée*, et c'est le contrôle de couverture (le plus fragile des trois) qui doit l'attraper. |
| **R-B** | **Entité écrite à la main** (sans `@ZcrudModel`) échappant au volet (A) | C'est **exactement** le scénario H1 d'ES-1.4 : pas de registrar ⇒ `R_disk \ R_wired` ne mord pas ; la règle (3) était aveugle. Précédent réel : `ZMindmap`/`ZMindmapNode`. | ✅ Détection **AST** + 5 fixtures isolées par forme de déclaration. ⚠️ Toute entité hand-written d'ES-2 ⇒ **`manual_probes.dart` obligatoire**, avec injection de régression. |
| **R-C** | **Champ métier sous une clé réservée** (`ZSmartNote.updatedAt` « dernière édition ») | Le geste est **naturel** et **détruit la donnée silencieusement** (le store écrit la méta **après** le corps, à chaque `put`). Ce n'est plus un miroir bénin : c'est une **perte de valeur métier**. | ✅ AD-19.1.a + table de décision (`edited_at`/`published_at`/`reviewed_at`). ⚠️ Ajouter le contrôle `$XxxFieldSpecs ∩ reservedKeys == {}` à la **checklist R8** — le gate ne le couvre pas directement. |
| **R-D** | **DW-ES14-1 rattrape ES-2/ES-3** | `extra` est **le** mécanisme d'extensibilité AD-4 sur lequel ES-2 fonde 8 entités (`ZSmartNote` audio, `ZStudyFolder` partage…). La voie registre le **détruit**. | ⛔ **Ouvrir la story dédiée avant tout câblage du store.** Ne jamais utiliser `fromRegistry` (avertissement dartdoc posé sur la fabrique). |
| **R-E** | **Parallélisation** : `ES-2.3/2.4/2.7/2.8` écrivent tous le **kernel** | Le kernel est le seul point de contact possible ; deux écritures concurrentes = régression cross-package invisible aux vérifs ciblées (leçon `ZExportApi`). | ✅ Règle epics : `ES-2.1` (`zcrud_document`) ∥ `ES-2.2` (`zcrud_note`) ∥ `ES-2.6` (`zcrud_exam`) **disjoints** ; les 4 stories kernel **strictement sérialisées**. `melos analyze` + `verify` **repo-wide** au gate de commit. |
| **R-F** | **Surface publique** : chaque symbole ajouté au barrel kernel **fuite** dans `zcrud_flashcard` (réexport) | LOW-1 d'ES-1.1, soldé par le `hide` d'ES-1.2 — puis **outillé** par `z_kernel_surface_guard_test.dart` (L4) | ✅ Le garde **mord** (prouvé). ⚠️ ES-2 ajoute `ZFlashcardTag`, `ZFolderContentsOrder`… au kernel : **décider explicitement**, pour chacun, `hide` ou allowlist flashcard. Le garde force la décision, il ne la prend pas. |
| **R-G** | **La spec d'une story ES-2 porte elle-même le défaut** | ES-1.2 : les 4 MEDIUM venaient **de la story**, pas du dev. ES-1.4 : 2 failles venaient de la **spec figée AD-19.1.c**. | ✅ Tout-Opus (le dev doit **remettre la spec en cause**) + **R4** (prototype exécutable avant de figer une prescription d'API). |
| **R-H** | **`ZStudyPodcast` content-addressed, `ZAnnotationBounds [0,1]`, `ZReminderTime HH:mm`** — invariants de valeur non gardés | Aucun précédent d'échec dans cet epic, mais ce sont des invariants **exprimés en prose** dans l'architecture. Motif n°2 (« règle écrite, aucune machine ») applicable. | ⚠️ **R1** : chaque invariant de valeur d'ES-2 naît avec son test de garde (bornes, clamp, format) **et** un cas de désérialisation corrompue (AD-10, jamais de throw). |

---

## 7. Enseignement opératoire de l'epic (à porter dans le processus)

> **Un filet qu'on n'a pas vu échouer n'est pas un filet.**
> **Aucune quantité de vert ne peut détecter un faux vert — seul un rouge provoqué le peut.**

Corollaires structurels acquis en ES-1, à ne jamais défaire :
- `ci.yml` appelle **`melos run verify` en step unique** ⇒ la dérive « gate dans `verify`, absent de la CI » est **impossible par construction**.
- `pubspec.yaml` (source de vérité) / `melos.yaml` (miroir) gardés par `gate:melos`.
- `ZSyncMeta` est la **définition machine unique** des clés de sync (zéro littéral résiduel dans tout `lib/`).
- Les gates raisonnant sur du Dart **parsent** (AST), ne **scannent** pas.
- Tout skip est **bruyant** et **refusé en CI**.
