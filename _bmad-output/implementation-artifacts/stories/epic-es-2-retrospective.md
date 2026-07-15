# Rétrospective — Epic ES-2 : Domaine canonique éducatif + codegen

- **Date** : 2026-07-15
- **Mode** : skill BMAD **`bmad-retrospective` réellement invoqué** via le tool `Skill` (pas de fallback disque). Exécution en **sous-agent non interactif** : les steps de dialogue party-mode (6–8, 10–11) sont **dérivés du disque** (10 stories, 9 code-reviews, rétro ES-1, sprint-status, `CLAUDE.md`, architecture) au lieu d'être joués en conversation ; **aucune écriture du `sprint-status.yaml`** (réservé à l'orchestrateur).
- **Epic** : **ES-2 — Domaine canonique éducatif + codegen** — **10 stories `done`** (ES-2.0, ES-2.1, ES-2.2, ES-2.2b, ES-2.3, ES-2.4, ES-2.5, ES-2.6, ES-2.7, ES-2.8).
- **Epic suivant** : **ES-3 — Ports & couche data offline-first bi-topologie.** C'est le premier epic qui **câble un store** — donc le premier où les dettes latentes d'`extra`/`extension` deviennent **destructrices**, pas seulement dormantes.

---

## 1. Ce qui a été livré (bilan factuel)

| Story | Livrable | Cœur du travail |
|---|---|---|
| **ES-2.0** | `zcrud_generator` + `zcrud_firestore` — solde **DW-ES14-1** (rétro ES-1) | `registry.decode` ne **DÉTRUIT plus** `extra` : le generator émet la voie qui **peuple** `extra`. Contrat `_requireDomainFromMap` transformé de **vérif de signature** en **vérif de comportement**. 5ᵉ assertion (e) du volet (A). Absorbe L3 d'ES-1.3 (même package). |
| **ES-2.1** | `zcrud_document` (16ᵉ package) | `ZStudyDocument` + `ZDocumentReadingState`/`ZDocumentLearningInfo` + `ZDocumentViewerPrefs`. Invariants R-H (page 1-based, `qualityByPage`), dégradation legacy IFFD 6→4 statuts épinglée (**DW-ES21-1**). Fait naître, en H1, la **première machine** qui observe le CORPS de sonde (fin de l'artisanat par canal). |
| **ES-2.2** | `zcrud_note` (17ᵉ package) | `ZSmartNote` (contenu via `ZCodec`), `ZNoteAudio` (**1ʳᵉ `ZExtension` concrète du repo**). A **révélé** DW-ES14-2 (registre détruit `extension`) et DW-ES22-3/4 (canal `extra`). Mitigation `ZOpaqueNoteExtension` (donnée verbatim préservée, type perdu). Test-verrou de divergence `normalizeNoteContentOps` (**DW-ES22-1**). |
| **ES-2.2b** | **TÊTE BLOQUANTE systémique** — `zcrud_core`+kernel+document+flashcard | Solde **DW-ES22-3** (`copyWith(extra:)` rouvrait le filtre des clés réservées — MESURÉ sur 3 entités déjà livrées) + **DW-ES22-4** (`_mapEquals`/`_mapHash` superficiels ⇒ `fromMap(m) != fromMap(m)` sur JSON imbriqué). Patron `extra` durci : **slot brut + accesseur normalisant**, garde partagée `fromMap`+`copyWith`+`toMap`. Assertions (i)/témoin d'écriture au gate. |
| **ES-2.3** | kernel — `ZFlashcardTag`/`ZSuggestedTag`/`remapColorKey` | Tags first-class. VO exportables SANS invariant (`ZSuggestedTag`, `ZChoice`) validés **exportés sans `hide`** — borne basse du futur fix DW-ES25-1. **Un test golden fortuit** laissé par le dev a été **attrapé par l'orchestrateur** en re-vérif. |
| **ES-2.4** | kernel — `ZFolderContentsOrder` | Ordre de contenu de dossier. `applyOrder` réutilisé. Trou de patron DW-ES24-1 (`sectionOrders`) recensé. |
| **ES-2.5** | `zcrud_document` — `ZDocumentAnnotation`/`ZAnnotationBounds` | Bornes `[0,1]` (VO à invariant). A **exhibé DW-ES25-1** : le test « AC13 » censé prouver que retirer le `hide` rougit était **POWERLESS** (import interne) — la garde n'existe que par convention. |
| **ES-2.6** | `zcrud_exam` (18ᵉ package) | `ZExam`/`ZReminderTime`, **horloge injectée** (zéro `DateTime.now()` en `lib/`, prouvé par machine AST). `ZApproachingExam` = **port neutre kernel** (AD-1/17). |
| **ES-2.7** | kernel — `ZStudySessionResult`/`ZDailyStudyTask`/`aggregate` | Agrégation quotidienne, **tri stable + tie-breaker déterministe** prouvé au bon `n=40` (load-bearing). Anti-`DateTime.now()` par machine. **0 finding** (verdict le plus propre de l'epic). |
| **ES-2.8** | kernel — `ZStudyPodcast` (content-addressed) | `sourceHash` **fourni, jamais calculé** (crypto-free : le domaine ne dépend d'aucune lib de hash). |

### Métriques réelles (rejouées repo-wide par l'orchestrateur, jamais sur la foi d'un agent)

| Mesure | Avant ES-2 | Après ES-2 |
|---|---|---|
| Packages (`melos list`) | 15 | **18** (+ `zcrud_document`, `zcrud_note`, `zcrud_exam`) |
| Tests `zcrud_study_kernel` | 108 (VM) | **~267** (tags, ordre, session-result, podcast) |
| Tests `zcrud_document` | — | **~166** |
| Tests `zcrud_note` | — | **~130** |
| Tests `zcrud_exam` | — | **41** (VM) / **39** (node ; 2 `@TestOn('vm')`) |
| `gate:reserved-keys` (volet A comportemental) | ~... | **~100 assertions VERT** |
| Fixtures `prove_gates` | 32 OK / 0 FAIL | **41 OK / 0 FAIL** |
| Graphe AD-1 | acyclique, 15 nœuds, CORE OUT=0 | **acyclique, 18 nœuds, CORE OUT=0** — aucune arête entrante parasite (NFR-S10 vérifié) |

**Findings de code-review sur l'epic** : sur 9 revues — **6 HIGH** (H1 ES-2.0, H1/H3 ES-2.1, HIGH-1 ES-2.2, HIGH-1/HIGH-2 ES-2.2b), **~8 MAJEUR**, une douzaine de MEDIUM, autant de LOW. **3 revues à 0 finding bloquant** (ES-2.3, ES-2.4, ES-2.7). **0 finding bloquant reporté sans justification écrite.** Chaque filet ajouté/modifié est **prouvé par injection de régression rejouée par l'orchestrateur** (R3).

---

## 2. LE MOTIF DOMINANT du projet — récidives, et la mutation qui l'attaque

> **Un artefact de vérification est déclaré valide sur la base de son EXISTENCE, jamais sur la base de son POUVOIR DISCRIMINANT observé.**
> **Aucune quantité de vert ne peut détecter un faux vert — seul un rouge provoqué le peut.**

ES-2 est le terrain où ce motif s'est **le plus rejoué** — mais aussi, pour la première fois, où on l'a systématiquement trouvé **DANS LES FILETS EUX-MÊMES**, y compris ceux ajoutés pour le contrer.

### 2.1 Recensement des récidives (ce que le motif a produit en ES-2)

| # | Story | Où le filet/artefact était impotent |
|---|---|---|
| 1 | **ES-2.0 H1** | `_requireDomainFromMap` validait la **SIGNATURE** d'un `fromMap`, jamais son **POUVOIR** de préserver `extra` — et son message d'erreur **prescrivait littéralement la forme impotente**. Hors de ce repo, le filet n'existait pas. |
| 2 | **ES-2.0 H2** | « `source` ✅ PRÉSERVÉ » : une **affirmation de prose** dans la dartdoc qui **autorise le câblage d'un store**. La perte réelle était **pire** que ce que la revue décrivait (voir DW-ES14-2). |
| 3 | **ES-2.1 H1** | Le filet anti-H2 était un **artisanat par canal** : les 5 assertions du volet (A) n'observaient que `reservedKeys` et l'unique `kProbeUnknownKey`. **Aucune ne regardait une clé du CORPS de sonde** (`learning`, `source`). Le correctif d'ES-2.0 (« ajouter `source` à `kProbeBodies` ») était donc lui-même **INERTE** — la sonde transportait la donnée, rien ne l'observait. **Rien ne ferait naître le prochain canal avec son observateur.** |
| 4 | **ES-2.1 H3** | `ZFlashcardZcrud` était **EXPORTÉE PUBLIQUEMENT** (9ᵉ occurrence du motif « extension générée exportée ») — **trouvée par la machine ajoutée en H1**, pas par relecture. La machine, sitôt dotée d'un pouvoir réel, a immédiatement mordu sur du code livré. |
| 5 | **ES-2.2 HIGH-1** | `normalizeNoteContentOps` : une `List` **partiellement valide** rendait `[]` ⇒ **perte TOTALE du corps de la note**. Le « filet » de normalisation détruisait ce qu'il devait préserver. |
| 6 | **ES-2.2b HIGH-1** | La garde `toMap()`/`toJson()` était **DÉCORATIVE sur 8 entités / 9** : aucune machine ne l'exigeait. |
| 7 | **ES-2.2b HIGH-2** | Le **constructeur nominal public `const`** restait une voie d'écriture **NON FILTRÉE** : 6 entités / 9 portaient `updated_at`+`is_deleted` dans leur `extra` **EN MÉMOIRE** — dont `ZSmartNote`, « LE MODÈLE ». |
| 8 | **ES-2.3** | **Test golden fortuit** : un test passait pour la mauvaise raison. Non détecté par le dev, **attrapé par l'orchestrateur** en re-vérif verte, corrigé. |
| 9 | **ES-2.5** | **Test « AC13 » POWERLESS** : censé prouver que retirer le `hide` de `ZAnnotationBounds` rougit, il passait par un **import interne** ⇒ VERT même sans la garde. Le filet « prouvait » par un chemin qui ne dépendait pas de ce qu'il prétendait garder (**DW-ES25-1**). |
| 10 | **ES-2.7** | À l'inverse : le tri stable `n=40` était **soupçonné fortuit** — la revue a **PROUVÉ qu'il était load-bearing** (le pouvoir discriminant observé, pas supposé). Contre-exemple positif. |

### 2.2 Ce qui a CHANGÉ : les gardes sont devenues des MACHINES dérivées du disque par AST

Le tournant d'ES-2 (H1 d'ES-2.1) est structurel : on a cessé d'écrire **un observateur artisanal par canal** (fragile, oubliable, et donc rejouant le motif à chaque nouvelle entité) pour faire **dériver l'ensemble des observateurs du disque réel par AST**. Conséquences acquises, à ne jamais défaire :

- Le harnais `reserved_keys_gate` **énumère les canaux** (`_channelsOf`) et **exige** que chacun soit observé — une entité non câblée ou un canal non observé est **ROUGE par couverture**, plus par relecture.
- La règle « aucune extension générée n'est exportée » ((h)) est **exécutée par machine** : c'est elle qui a trouvé H3 d'ES-2.1 (une 9ᵉ occurrence que 8 relectures avaient laissée passer).
- L'anti-`DateTime.now()` (ES-2.6/2.7) **parse `lib/` par AST**, avec fixture d'échec isolée (R2) et portée **honnêtement documentée** (n'attrape pas le tearoff argless sans parenthèses — limite écrite, **aucune surpromesse**).

**La leçon d'ES-1 (« R1 : une règle naît avec son gate ») a mûri en ES-2 en : "un gate ne vaut que s'il DÉRIVE ses cibles du disque et OBSERVE le comportement, pas la forme".** Un filet artisanal par cas est du faux vert en puissance : il ne couvre que les cas que son auteur a pensés.

### 2.3 Ce qui RÉSISTE encore

Trois zones où le motif n'est **pas** encore réduit à une machine, et **c'est exactement le contenu des dettes ci-dessous** :

1. **DW-ES25-1** — la garde (h) ne protège que les `ZExtensible`. Les **VO à invariant** (`ZAnnotationBounds`, `ZDocumentViewerPrefs`) ne sont protégés que par **convention `hide`** ; retirer le `hide` **laisse le gate VERT** (confirmé par injection). Le filet AC13 était powerless. *Aucune machine n'exige encore la convention.*
2. **DW-ES24-1** — l'immuabilité **profonde** des canaux Map/List est gardée sur `fromMap`/`copyWith` mais **pas** sur le ctor `const` invoqué non-const avec une réf mutable retenue. Le pouvoir discriminant n'est observé qu'aux deux frontières de (dé)sérialisation, pas à la frontière constructeur.
3. **DW-ES14-2** — le registre **DÉTRUIT `extension`** et **IGNORE `sourceRegistry`**. La clause d'échappement n°1 de la dette (« sauf si l'entité n'utilise pas le slot `extension` ») a été **FALSIFIÉE** par `ZNoteAudio` (1ʳᵉ `ZExtension` concrète). Un `firebase_z_repository_impl.dart:207-212` écrit encore cette clause comme vraie **et autorise le câblage d'un store** — un faux vert de prose qui deviendra une perte de données au premier store d'ES-3.

---

## 3. Patrons ÉTABLIS et durcis en ES-2 (à conserver tels quels)

1. **Patron `extra` (ES-2.2b)** — **slot brut + accesseur normalisant**, garde `_sanitizeExtra` **partagée** par `fromMap` + `copyWith` + `toMap`. Ferme les 3 voies d'un coup ; clôturé par l'assertion (i) du volet (A) + un **témoin d'écriture** au gate. *C'est le patron de référence pour DW-ES24-1.*
2. **Canal hors-codegen (`_channelsOf`, règles g1/g2)** — les canaux Map/List/extension sont **énumérés** et chacun **doit** avoir son observateur ; naître un canal sans observateur est ROUGE. Fin de l'artisanat par canal (H1 ES-2.1).
3. **Horloge injectée (ES-2.6)** — aucun `DateTime.now()`/argless en `lib/`, l'instant est un **littéral injecté**, prouvé par machine AST + fixture R2. Généralisé à ES-2.7.
4. **Tri stable / tie-breaker déterministe (ES-2.7)** — ordre total et stable, tie-breaker n'agissant que sur `DateTime` **strictement** égal, prouvé au bon `n` (40), **load-bearing démontré**.
5. **Port neutre kernel (`ZApproachingExam`, ES-2.6)** — le kernel expose une **abstraction** (`abstract interface class`, jamais `sealed`), l'implémentation reste chez le satellite. AD-1/AD-17 respectés, graphe CORE OUT=0 préservé sur 18 nœuds.
6. **`sourceHash` fourni non calculé (ES-2.8)** — content-addressing **crypto-free** : le domaine ne dépend d'aucune lib de hash ; l'empreinte est une donnée entrante. Conforme « `zcrud_core` sans dép lourde ».
7. **VO exportable vs VO à invariant** — `ZSuggestedTag`/`ZChoice` exportés **sans** `hide` (validé ES-2.3) ; `ZAnnotationBounds`/`ZDocumentViewerPrefs` **avec** `hide` (ES-2.5/2.1). La distinction est **posée et vécue** — mais pas encore **machine** (cf. DW-ES25-1).

---

## 4. Dettes à STATUER — décisions, priorité, risque, blocage

> Rappel d'ordonnancement : **ES-3 est le premier epic qui câble un store.** Toute dette « latente aujourd'hui, destructrice à l'adoption » doit être soldée **avant** son câblage. C'est le fil rouge des trois dettes 🔴.

### 🔴 DW-ES14-2 — `ZcrudRegistry` ne réinjecte pas `extension`/`sourceRegistry` (BLOQUANTE avant ES-3.2/3.5)

- **Nature** : une cause, deux symptômes. `ZcrudRegistry` n'offre **aucun slot d'injection** ⇒ sur la voie registre, `extension` est **DÉTRUITE** et `sourceRegistry` **IGNORÉ**. La clause d'échappement n°1 de la dette est **FALSIFIÉE** depuis `ZNoteAudio` (ES-2.2). Mitigation en place : `ZOpaqueNoteExtension` (donnée verbatim préservée, **type perdu**). `firebase_z_repository_impl.dart:207-212` écrit encore la clause fausse et **autorise le câblage d'un store**.
- **Décision** : **story dédiée `ES-3.0`, en TÊTE d'ES-3, AVANT tout `ZStudyRepository`/store (ES-3.1/3.2/3.5).** Le fix écrit `zcrud_core` (nouveau slot d'injection au registre) + corrige l'adapter firestore. **Sizing L/XL** (touche l'API publique du registre + le generator + l'adapter + le gate).
- **Critère de clôture** : round-trip `registry.decode → registry.encode` **préservant `extension` typée ET la provenance `sourceRegistry`** pour au moins un kind (`ZNoteAudio`), câblé comme **nouvelle assertion du volet (A)** ; suppression du `firebase_z_repository_impl.dart:207-212` mensonger.
- **Risque si ignorée** : câbler le store d'ES-3 sur un registre qui détruit `extension` = **perte de données irréversible dès la 1ʳᵉ écriture** de toute entité extensible. **Bloque ES-3.2 et ES-3.5.**

### 🔴 DW-ES24-1 — immuabilité PROFONDE des canaux Map/List conditionnelle (à traiter au niveau PATRON)

- **Nature** : gardée en profondeur sur `fromMap`/`copyWith` (`List.unmodifiable`), **NON** sur le ctor `const` invoqué non-const avec réf mutable retenue (`o.sectionOrders['a'].add(...)` ne throw pas). **Trou de patron PARTAGÉ par 5 entités** : `ZDocumentLearningInfo.qualityByPage`, `ZDocumentReadingState.learning`, `ZSmartNote.content`, `ZFolderContentsOrder.sectionOrders`.
- **Décision** : **fix uniforme au niveau PATRON, jamais story par story** (corriger 1 entité crée une incohérence). Réutiliser le patron `extra` d'ES-2.2b (**accesseur normalisant OU champ privé + getter**). **Prototyper l'uniformisation puis l'appliquer aux 5 entités en une story dédiée** — candidate à **ES-3.0** (même fichier `zcrud_core`/kernel, même geste que DW-ES14-2) ou à une story « durcissement patrons » juste après.
- **Risque / priorité** : **vecteur persistant FERMÉ** (le store passe par `fromMap` gardé) ⇒ c'est un **hasard in-memory, pas une perte au store**. **Priorité MOINDRE que DW-ES14-2** — mais à solder avant que du code applicatif (ES-4+/DODLP) ne s'appuie sur l'immuabilité supposée. Non bloquante pour le câblage store.

### 🔴 DW-ES25-1 — la garde (h) ne couvre que les `ZExtensible` (à PROTOTYPER R4, puis statuer en ES-3)

- **Nature** : `if (!index.isExtensibleDecl(d)) continue;` — un **VO à invariant** (`ZAnnotationBounds` `[0,1]`, `ZDocumentViewerPrefs`) **DOIT** être `hide` (son `copyWith`/`toMap` généré contourne la sanitisation, atteignable publiquement si exporté) mais **aucune machine ne l'exige** ; retirer le `hide` laisse le gate **VERT** (confirmé par injection ES-2.5). Filet AC13 powerless. Protection ACTUELLE = **convention** `hide` en place. **Le trou est l'ABSENCE de garde-régression machine, pas un bug actuel.**
- **Décision** : **PROTOTYPER (R4) AVANT de figer.** Le fix exige de distinguer **par AST** un « `@ZcrudModel` NON-`ZExtensible` à invariant de valeur » (à masquer) d'un **VO exportable SANS invariant** (`ZChoice`/`ZSuggestedTag` — exportés sans `hide`, validé ES-2.3) **SANS faux positif**. L'heuristique naïve « déclare `toMap`/`copyWith` d'instance » **mange les VO exportables** ⇒ non triviale. **Story dédiée en ES-3** (ou tôt en ES-4), **précédée d'un spike jetable** qui prouve la discrimination sur les 4 VO réels du repo avant d'écrire la règle normative.
- **Risque / priorité** : **pas de bug actuel** (convention respectée). Priorité = **empêcher la régression future** (un futur contributeur retire un `hide` sans signal). **Non bloquante pour ES-3**, mais R4 impose le spike avant toute promesse machine.

### 🟡 DW-ES22-1 — divergence sémantique `normalizeNoteContentOps` vs `DeltaNeutralOps.asDeltaOps` (avant ES-6.1)

- **Nature** : sens opposés — `asDeltaOps('# T') == []` **DÉTRUIT** vs `normalizeNoteContentOps('# T')` **PRÉSERVE**. En ES-6.1, un aller-retour domaine→éditeur→domaine **effacerait** ce que le domaine avait sauvé. Épinglée par un **test-verrou** (ES-2.2).
- **Décision** : **résolution en ES-6.1** (câblage éditeur `zcrud_markdown`). Le test-verrou tient la ligne d'ici là. Ne pas toucher au domaine (le domaine est correct ; c'est l'adapter éditeur qui devra converger).

### 🟡 DW-ES21-1 — mapping legacy IFFD 6 statuts → 4 canoniques (due en ES-3.5 / ES-11.2, AD-27)

- **Nature** : dû dans l'**ADAPTER**, jamais le domaine : `uploading→uploading` · `converting|embedding→validating` · `uploaded|converted|embedded→ready`. Sans lui, un document IFFD `embedded` (donc **PRÊT**) se lit `uploading` (« Traitement… » perpétuel). Épinglée par **8 tests** (ES-2.1).
- **Décision** : **ES-3.5** (compat sérialisation camelCase/snake, corpus IFFD legacy) — le mapping vit dans le codec d'adapter, activé avec le corpus de rétro-compat.

**Ordre recommandé** : **ES-3.0 (dédiée : DW-ES14-2 + uniformisation DW-ES24-1, écrit `zcrud_core`/kernel/generator/firestore) → ES-3.1… → ES-3.5 (DW-ES21-1)**, avec le **spike R4 de DW-ES25-1** planifié tôt dans ES-3 (indépendant, non bloquant). **Aucun store câblé avant que le registre ne préserve `extension`.**

---

## 5. Process — ce qui a bien / mal fonctionné

### A conserver (a payé littéralement)

1. **Délégation Workflow mono-agent, effort par étape.** `create-story` medium (high si complexe), `dev-story`/`code-review` high, modèle hérité (tout-Opus). La granularité a tenu sur 10 stories + 9 revues.
2. **L'orchestrateur rejoue la vérif verte, indépendamment de l'agent** — et **a attrapé un test golden fortuit en ES-2.3** que le dev avait laissé passer. La règle R9 d'ES-1 (« aucun rapport d'agent ne vaut preuve ») a **directement produit une prise**.
3. **Injection de régression comme critère de clôture (R3).** Seule technique qui a jamais attrapé un faux vert : elle a fait rougir H1/H2 d'ES-2.0, prouvé le pouvoir de la machine H1 d'ES-2.1 (qui a **ensuite trouvé H3**), démasqué le test powerless d'ES-2.5, et prouvé le `n=40` load-bearing d'ES-2.7.
4. **Reprise propre après crash d'agent.** Les **2 crashes API de `create-story`** (ES-2.2b, ES-2.5) ont été **relancés proprement** par l'orchestrateur après vérification de l'état réel sur disque (git/statut/tests), sans faire confiance à un rapport partiel — exactement le protocole « surveillance des sous-agents » de `CLAUDE.md`.
5. **Escalade d'une dette découverte en cours d'epic.** `ZNoteAudio` (ES-2.2) a **falsifié la clause d'échappement** de DW-ES14 ⇒ escaladée en DW-ES14-2 dans le sprint-status, avec mitigation (`ZOpaqueNoteExtension`) plutôt que déni. La dette a été **rendue visible et ordonnancée**, pas enterrée.

### Incidents corrigés (nouvelles consignes)

6. **`git checkout` dangereux d'un agent (ES-2.3).** Un sous-agent a tenté un `git checkout` qui aurait pu écraser du travail non committé. Consigne durcie et adoptée : **« édition ciblée, JAMAIS `git checkout` / restauration destructive par un sous-agent »** — la restauration d'une injection R3 se fait par **ré-édition ciblée à l'octet près**, vérifiée par `diff` vide.
7. **DW-ES22-3/4 mesurés dans du code DÉJÀ LIVRÉ.** Le défaut `copyWith(extra:)`/égalité superficielle existait dans 3–4 entités **déjà `done`**. Il a fallu une **story bloquante intercalée (ES-2.2b)** pour le solder **avant** que les 6 entités restantes ne le reproduisent. Enseignement : un défaut de **patron** doit être soldé **en tête**, pas story par story — d'où l'ajout d'ES-2.2b hors séquence numérique.

---

## 6. Nouvelles règles (dans la lignée de R1–R9 d'ES-1)

- **R10 — Un observateur naît de la DÉRIVATION du disque, jamais de l'artisanat par cas.** Un filet qui énumère à la main les canaux/entités qu'il surveille rejoue le motif (il ne couvre que les cas pensés par son auteur). Tout gate qui garde un **ensemble** (canaux, entités, exports) **dérive cet ensemble du disque par AST** et exige un observateur **pour chaque membre** ; un membre sans observateur est **ROUGE par couverture**. *(H1 ES-2.1 : le correctif ES-2.0 était inerte faute d'observateur ; la machine dérivée a immédiatement trouvé H3.)*
- **R11 — Un défaut de PATRON se solde EN TÊTE, jamais story par story.** Dès qu'un défaut est **mesuré dans ≥2 entités livrées** (copyWith/extra, immuabilité profonde, hide des VO…), on **intercale une story bloquante** qui corrige le patron partout, plutôt que de le reproduire N fois. Corriger une seule entité crée une **incohérence** et laisse le motif se répandre. *(ES-2.2b ; à rejouer pour DW-ES24-1.)*
- **R12 — Un test qui « prouve » par un chemin indépendant de la garde est un MENSONGE d'artefact (test powerless).** Tout test de garde doit rougir **par le retrait de la garde exacte** qu'il prétend prouver — pas par un import interne, un chemin de repli, ou une coïncidence de valeur. Vérifié par R3 (retirer la garde → ROUGE **par cette garde**). *(AC13 ES-2.5, golden fortuit ES-2.3.)*
- **R13 — La restauration d'une injection R3 se fait par ÉDITION CIBLÉE, jamais par `git checkout`.** Un sous-agent ne restaure jamais l'arbre par une commande destructive ; il ré-édite à l'octet près et prouve par `diff` vide. *(Incident ES-2.3.)*

---

## 7. Verdict — Prêt pour ES-3 ?

**Verdict : PRÊT SOUS CONDITION D'UNE STORY DÉDIÉE EN TÊTE (ES-3.0).**

Le domaine canonique éducatif est **complet, extensible et gardé par des machines** (18 packages, graphe CORE OUT=0, gates comportementaux dérivés du disque, 0 finding bloquant reporté). Les patrons `extra`/horloge/tri-stable/port-neutre sont **établis et durcis**. Mais ES-3 **câble le premier store**, et deux dettes 🔴 deviennent alors destructrices :

**Pré-requis NON NÉGOCIABLES avant tout store d'ES-3 :**

1. 🔴 **DW-ES14-2 en TÊTE (story ES-3.0 dédiée, sizing L/XL)** — `ZcrudRegistry` doit **réinjecter `extension` typée et la provenance** avant `ES-3.2`/`ES-3.5`. Supprimer le `firebase_z_repository_impl.dart:207-212` mensonger. **BLOQUANT.**
2. 🔴 **DW-ES24-1 uniformisé au niveau patron** — de préférence **dans la même ES-3.0** (même code `zcrud_core`/kernel, même geste que le patron `extra`). Non bloquant pour le store (vecteur persistant fermé) mais à solder avant appui applicatif.
3. 🔴 **DW-ES25-1 : spike R4 planifié tôt dans ES-3** (indépendant, non bloquant) — **prototyper la discrimination AST VO-à-invariant vs VO-exportable AVANT** d'écrire la règle normative ; jusque-là, la protection reste la **convention `hide`** (à mentionner en toutes lettres, R1).
4. 🟡 **DW-ES21-1** intégré à **ES-3.5** (adapter, corpus IFFD legacy) ; **DW-ES22-1** tenu par son test-verrou jusqu'à **ES-6.1**.

**Filet à ne jamais défaire en ES-3 :** `melos run analyze` **ET** `melos run verify` **repo-wide** au gate de commit (R9) ; les stories kernel **strictement sérialisées** (le kernel est le seul point de contact) ; toute nouvelle machine **dérivée du disque** (R10) ; tout défaut de patron soldé **en tête** (R11).

> **Enseignement opératoire d'ES-2, à porter dans le processus :**
> **Un filet artisanal par cas est du faux vert en puissance — il ne couvre que ce que son auteur a pensé. Un filet ne devient fiable que quand il DÉRIVE ses cibles du disque et OBSERVE le comportement, pas la forme. Et même alors : on ne le déclare `done` qu'après l'avoir vu ROUGIR par le retrait de la garde exacte.**
