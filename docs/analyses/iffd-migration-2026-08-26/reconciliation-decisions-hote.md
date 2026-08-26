# Réconciliation — le relevé face aux DÉCISIONS DÉJÀ PRISES par le propriétaire d'IFFD

> **Lentille** : confronter les 22 756 lignes du relevé aux arbitrages que le propriétaire d'IFFD a
> déjà tranchés. Un relevé qui recommande ce qui a été tranché **contre** est pire qu'inutile.
> Sources hôte lues en **lecture seule** sous `/home/zakarius/DEV/iffd/docs/`.
> Écrit le 2026-08-26. Toute affirmation d'absence porte son grep négatif.

**Grep négatif fondateur** — le relevé ne cite aucune de ces sources :
```
$ grep -rl "decisions-adoption-zcrud\|plan-modeles-zentity-codegen\|chiffrage-migration-chat\|dette-bugs-preexistants" \
    docs/analyses/iffd-migration-2026-08-26/ | grep -v critique-completude ; echo "RC=$?"
RC=1
$ grep -rn "RACINE-1\|RACINE-2\|RACINE-3\|DEC-9\|DEC-14\|DEC-16" docs/analyses/…/ | grep -v critique-completude ; echo "RC=$?"
RC=1
```
Seul `critique-completude.md` (écrit après coup) les mentionne. Les 5 catalogues, 11 cartes,
11 confrontations et 33 réfutations sont écrits **sans connaissance des arbitrages**.

---

## 1. Les décisions déjà prises qui contraignent la migration

### 1.1 Les racines — tranchées le 2026-08-19 (`decisions-adoption-zcrud.md:9-19`)

| # | Décision | Source | Portée |
|---|---|---|---|
| **RACINE-1** | **Frontière mobile, cible = remplacement** : un écran porté consomme l'entité du socle et **ne reconvertit pas** ; le mapper reste à la frontière ⇒ **la vague N2 est annulée** | `:13`, `:60-69`, `:275-291` | commande DEC-9, DEC-10, DEC-11, l'ordre M3/M5 |
| **RACINE-2** | **③ — les deux de front** : fil A (mise en service des 40 bascules) et fil B (capacités neuves) en parallèle. *La recommandation était ① ; le propriétaire a retenu ③* | `:14`, `:106-121` | impose la **règle de non-collision** (`:162-168`) et l'**indicateur de solde** (`:170-182`) |
| **RACINE-3** | **Une seule migration de schéma, dans M7** ⇒ **`ZFieldRename.none`** d'ici là ; clés fautives `accademicYear` / `folderExplaination` **préservées** | `:15`, `:139-146`, `:388` | tout modèle annoté avant M7 |
| **Produit** | **Quatre ouvertures autorisées** : B-30, B-28, `ZStudySharingPort`, + les 4 ports absents | `:16`, `:241-254` | élargit le périmètre de 5 fonctionnalités neuves |

**Préalable absolu des deux fils** : `M0` (`v1.2.0` → `v2.5.0`) — ✅ **CLOSE le 2026-08-19**
(`plan-migration-zcrud-v2.md:89`). Et **remplir `FIREBASE_COLLECTION_NAMES` avant tout renommage de
classe** (`decisions-adoption-zcrud.md:145`, `:411`) : la map est `const` **vide**, le nom de
collection est `T.toString()`.

### 1.2 DEC-4 → DEC-18 — validées en bloc le 2026-08-19

| # | Décision | Source |
|---|---|---|
| **DEC-4** | Adopter 12 paquets (dont `zcrud_generator`+`zcrud_annotations`) ; `zcrud_dnd` **sur besoin** ; **écarter, motivé** : `zcrud_html`, `zcrud_geo`, `zcrud_geo_location`, `zcrud_reorder` ; **écarter, définitif** : `zcrud_provider`, `zcrud_get` | `:196-209` |
| **DEC-5** | Monter `ZcrudRiverpodScope`, **et réinjecter les seams** sous le binding (il ne propage que `resolver` et `acl`) | `:210-221` |
| **DEC-6** | `discovery` → `zcrud_chat` : **oui**, et **la persistance reste à IFFD** | `:223-233` |
| **DEC-7** | **Les cinq ports absents adoptés** (dictée, OCR, épinglage, partage de conversation, modération) — 5 **fonctionnalités neuves**, 0 dette retirée | `:241-254` |
| **DEC-8** | `ai_experts` **dans le périmètre** (critère = la fonction, pas le répertoire) | `:256-264` |
| **DEC-9** | Groupe A (16 modèles à homologue) : 🔴 **NE PAS ANNOTER** — annoter `FolderModel` créerait une seconde entité canonique concurrente de `ZStudyFolder`, déjà tranché par **CR-IFFD-9**. Voie = mapper + recul écran par écran | `:271-274` |
| **DEC-10** | **N2 annulée**. ⚠️ mais `DynamicModel._deepEquals` (bug B-7) doit être réimplanté explicitement en N7 | `:275-291` |
| **DEC-11** | `workflow` (`Task`, `Event`, `Appointment`) **hors codegen** — héritage de types tiers, `part of workspace.dart`, 4 conventions de date | `:292-302` |
| **DEC-12** | Les 3 portages sans site d'appel : **leur créer leur site d'appel** | `:304-312` |
| **DEC-13** | Six conventions de date : **préserver modèle par modèle**, unifier dans M7 | `:314-321` |
| **DEC-14** | 🔴 `ZPersistAs.timestamp` : **NON — conversion au repository**. « IFFD ne sera pas le premier utilisateur d'un mécanisme non exercé » (aucune des 17 entités du socle ne l'emploie) | `:323-333` |
| **DEC-15** | Sous-listes : **adopter le nouveau défaut** (table compacte), vérifier à l'écran à la bascule | `:335-343` |
| **DEC-16** | B-30 (SRS à 5 paliers) : ✅ **oui** — story dédiée **M1-3b**, famille « données » | `:351-360` |
| **DEC-17** | B-28 (compteurs de dossier) : ✅ **oui**, **le chiffrage est la première étape de la story** | `:362-373` |
| **DEC-18** | B-29 (brouillon éditeur multi) : story dédiée, relevé avant/après | `:375-380` |

Report identique dans `plan-modeles-zentity-codegen.md:528-540` (D1→D6) et
`plan-migration-zcrud-v2.md:558`.

### 1.3 DEC-19 → DEC-32 — décisions des 2026-08-24 et 2026-08-25, **déjà exécutées**

| # | Décision | Source | État |
|---|---|---|---|
| DEC-19 | Champ téléphone rendu **visible** via `zcrud_intl` (`iffdTogoNationalPhone`) | `:431` | ✅ fait |
| DEC-20 | Défauts legacy réparés par les jumeaux : **garder les corrections**, pas de parité sur les défauts | `:432` | ✅ |
| DEC-21 | Honorer les specs de hauteur déclarées (`minLines`/`maxLines`), champ par champ en S4 | `:433` | 🟡 en cours |
| DEC-22 | Jumeaux flashcard / ai_router **complétés côté hôte** | `:434` | ✅ fait |
| **DEC-23** | 🔴 **Adoption AUTOMATIQUE des versions du socle** — « adopte toujours sans demander ». Reste soumis au propriétaire : les **choix de produit** que la livraison ouvre | `:461-478` | ✅ permanent |
| **DEC-24** | 🔴 **Le scope zcrud est monté par `MaterialApp.builder`** (`main.dart:270`), au-dessus du `Navigator`. **Les scopes locaux restent légitimes et nécessaires** (sources de relation, données de flux) | `:480-503` | ✅ fait |
| DEC-25 | La matrice d'autorisations **délègue** au select du socle (`ZSelectConfig.choiceBuilderKey`) ; un widget d'hôte subsiste car le contexte du builder n'a qu'une action `select(bool)` | `:505-526` | ✅ **aucune CR** |
| DEC-26 | Deux coquilles legacy **corrigées** à l'écran (libellés, pas comportements) | `:528-540` | ✅ |
| **DEC-29** | 🔴 **Les ÉTAPES « tout affiché » remplacent les SECTIONS** sur **quatre** formulaires (matières, promotions, routeurs IA, expert IA). Config déclarée une seule fois : `ZStepperConfig(stepsDisplay: ZStepsDisplay.allExpanded)`. **Deux pertes assumées** : le décor de section du routeur est **retiré** ; deux gardes ont changé de sens | `:583-628` | ✅ fait |
| DEC-30 | QA on-device : `dateDisplayFormatter` fourni, `indicatorSize: 28`, `forcedMode: ZEditionPresentation.page` dès qu'il y a des étapes | `:630-659` | ✅ fait |
| DEC-31 | `deferWrites` de DODLP : **essayé puis RETIRÉ le jour même** — trois gardes l'ont refusé, la tranche restait vide à la soumission | `:684-690` | ✅ écarté |
| **DEC-32** | Le booléen d'IFFD passe à **`FlutterSwitch`**, enregistré sous le kind `'boolean'` au `ZWidgetRegistry` | `:692-710` | ✅ **aucune CR** |

### 1.4 Deux règles de séquencement non négociables

| Règle | Source | Énoncé |
|---|---|---|
| 🔴 **Capturer avant de corriger** | `dette-bugs-preexistants.md:7-21` | « test de caractérisation capturant le comportement **actuel (bogué)** → story de correction ». *« Corriger avant d'avoir capturé rendrait toute régression post-cutover indémêlable de la migration elle-même. »* Repris en `plan-migration-zcrud-v2.md:330-335` : les 6 bugs de perte de données sont à **reproduire**, pas à corriger. |
| 🔴 **Le retrait vient EN DERNIER** | `plan-migration-zcrud-v2.md:544-546` | « **Ne pas commencer M9 avant que M3, M4 et M5 soient intégralement terminées.** Supprimer 16 889 lignes encore référencées par 48 fichiers est irréversible en pratique. » |

### 1.5 Le chat — option **B** retenue (2026-08-02, `chiffrage-migration-chat.md`)

| Option | Retenue | Ce qu'elle engage |
|---|---|---|
| A — ne pas migrer | ❌ | — |
| **B — migrer la présentation seule, garder `ChatbotMessage`** | ✅ **`:290-313`** | ~5 900 l. d'écrans, **zéro migration Firestore**. Traduction technique : **projection unidirectionnelle**, gardée par deux tests structurels (`test/w9a/`) qui échouent si une fonction rend un `ChatbotMessage` dans l'adaptateur, ou si un `ZChatMessage` est **sérialisé où que ce soit** dans `lib/` (`:342-356`) |
| C — migration complète du schéma | ❌ pour l'instant | exigerait un migrateur de corpus + un patch de compatibilité du codec |

---

## 2. 🔴 CE QUE LE RELEVÉ PROPOSE ET QUI CONTREDIT UNE DÉCISION PRISE

### C1 — Annoter les modèles du **groupe A** contre DEC-9 (« ne pas annoter »)

| | |
|---|---|
| **Ce que le relevé propose** | `confrontation-etude-dossiers.md:173-182` — « M6 : la (dé)sérialisation à la main des **6 modèles de dossier** → codegen `@ZcrudModel` », **639 l** : `folder_model.dart` (489), `folder_document.dart` (246), `folder_document_annotation.dart` (259), `folder_invitation.dart` (129), `folder_document_reading.dart` (105), `folder_document_learning_info.dart` (82). Idem `confrontation-ia-chat-generation.md:165-180` sur `chatbot_conversation.dart` + `chatbot_message.dart` (dans les ≈ 677 l). |
| **Ce que le propriétaire a tranché** | **DEC-9** (`decisions-adoption-zcrud.md:271-274`) : « **Ne pas annoter.** Annoter `FolderModel` créerait une seconde entité canonique concurrente de `ZStudyFolder`, ce que **CR-IFFD-9 a déjà tranché**. » Cinq des six modèles visés sont nommément du **groupe 🅰️** (`plan-modeles-zentity-codegen.md:115-121` : `FolderModel`, `FolderDocument`, `FolderDocumentAnnotation`, `FolderDocumentReading`, `FolderDocumentLearningInfo`, `ChatbotConversation`, `ChatbotMessage`). |
| **Laquelle prime** | 🔴 **La décision du propriétaire.** Le relevé propose d'investir dans une seconde vérité de donnée sur des entités **destinées à reculer puis disparaître** — exactement le motif pour lequel N2 a été annulée. |
| **Ce qui survit** | `folder_invitation.dart` est du groupe 🅱️ (famille « Utilisateurs/scolarité », `:135`) : recevable, et déjà planifié en **N3-e**. Le relevé lui compte **77 l** de sérialisation sur les 639 ⇒ le chiffre défendable est **77 l**, pas 639 ; les **562 l** restantes portent toutes sur des modèles du groupe 🅰️. Côté IA, `AiExpert*` et `IffdAiRouterModel` sont groupe 🅱️ (famille « IA », ~1 090 l, N3-c) ; les deux modèles de chat ne le sont pas. |

### C2 — `ZPersistAs.timestamp` contre DEC-14 (« conversion au repository »)

| | |
|---|---|
| **Ce que le relevé propose** | `confrontation-ia-chat-generation.md:174` : `ZPersistAs.timestamp` est présenté comme **le canal** ; `:177` — « `$XxxTimestampFields` … **c'est le canal qui retire `Timestamp` du domaine sans changer le format persisté** ». Repris `refutation-…-S-rialisation-manuelle-des-5-mod-les-du-.md:138`, `:194`. |
| **Ce que le propriétaire a tranché** | **DEC-14** / **D6** : « **conversion au repository**, comme les six mappers le font déjà. C'est le chemin éprouvé, et il évite d'être le premier utilisateur d'un mécanisme non exercé » — **aucune des 17 entités du socle** ne l'emploie (`decisions-adoption-zcrud.md:323-333`, `plan-modeles-zentity-codegen.md:539`). |
| **Laquelle prime** | 🔴 **La décision.** Le relevé ne pose pas la précondition qui la rendrait tenable : `$XxxTimestampFields` n'est appliqué que par `FirebaseZRepositoryImpl`, or IFFD écrit par son propre `FirebaseCrudRepositoryImpl`. |
| **Nuance à porter au crédit du relevé** | `confrontation-etude-dossiers.md:182` **énonce correctement le piège** (« Le socle documente le contournement ; il ne l'automatise pas »). Le relevé se contredit donc lui-même d'une confrontation à l'autre. |

### C3 — Le codegen proposé sans la contrainte `ZFieldRename.none` (RACINE-3)

Aucune des quatre propositions de codegen ne pose `fieldRename: ZFieldRename.none`.
```
$ grep -rn "ZFieldRename.none" docs/analyses/iffd-migration-2026-08-26/ | grep -v critique-completude
  refutation-…-S-rialisation-manuelle-des-5-mod-les-du-.md:35   (mention d'existence, pas de prescription)
```
`capacites-zcrud-donnees-transverse.md:412` note même le **défaut `ZFieldRename.snake`** sans
signaler que l'appliquer à IFFD écrirait `subject_id` là où la base contient `subjectId`.
L'hôte le mesure : *« perte silencieuse à la première écriture »* et deux clés fautives en
production à préserver (`plan-modeles-zentity-codegen.md:141-153`).
🔴 **La décision prime**, et c'est une omission de sûreté, pas un désaccord.

### C4 — « Le lot de suppression d'abord » contre M9 (« le retrait en dernier »)

| | |
|---|---|
| **Ce que le relevé propose** | `etat-des-lieux.md:281-290` — « **Lot 2 — La suppression… À faire avant tout portage.** » ≈ **12 250 l**, dont `lib/data_crud/dynamic_list_screen.dart`. |
| **Ce que le propriétaire a planifié** | **M9** ne démarre pas avant M3/M4/M5 closes (`plan-migration-zcrud-v2.md:544-546`) ; **M2-2** caractérise `dynamic_list_screen.dart` (recherche sans accents, tri Syncfusion, pagination, corbeille) pour produire *« un harnais réutilisable par M3 et M4 »* (`:322`) ; **M3-2** migre « les **deux consommateurs** » (`:339`, `:371`). |
| **Laquelle prime** | 🟡 **Partage.** Le **fait** du relevé est juste et plus récent — re-mesuré ici : `grep -rn "DynamicListScreen" lib` hors sa propre définition → **1 seule ligne** (`agents_screens.dart:176`), et le fichier fait **1 753 l**, pas 2 020. Le plan hôte s'appuie sur une mesure **périmée** (`etat-des-lieux-zcrud-v2.5.0.md:287` dit déjà « 2 ») : **M2-2 et M3-2 sont sans objet si le seul consommateur est mort**. Mais la **règle** de séquencement, elle, tient : le retrait est irréversible et se fait **après** preuve de non-référence, pas avant. |
| **À faire** | Ne pas ranger `dynamic_list_screen.dart` dans « suppression avant portage » : le remonter au propriétaire comme **remise en cause de M2-2/M3-2**, avec le grep. |

### C5 — Corriger cinq défauts « en premier » contre la règle « capturer avant de corriger »

| | |
|---|---|
| **Ce que le relevé propose** | `etat-des-lieux.md:263-278` — « **Lot 1 — À LANCER EN PREMIER** : `ZSrsConfig(minQuality: 1)`, `ZHintPenaltyPolicy(floor: 5)`, `ZcrudScope.derive`, `revealController` ». Lot 3 corrige en outre **un bug livré** (la flamme au changement d'heure, entrée 11). |
| **Ce que le propriétaire a tranché** | `dette-bugs-preexistants.md:7-21` : caractériser **avant** de corriger, *sans exception* ; `plan-migration-zcrud-v2.md:330-335` : reproduire les bugs, ne pas les corriger pendant la migration. Et **DEC-16** range explicitement la notation SRS dans une **story dédiée M1-3b, famille « données »**, avec relevé de la `quality` écrite avant/après. |
| **Laquelle prime** | 🔴 **La règle de séquencement.** Deux des cinq entrées du Lot 1 (`minQuality`, `floor`) **changent une donnée persistée** — ce sont des bascules de famille C (`M1-3`, « les HUIT bascules qui changent des données »), pas des « corrections à un paramètre ». |
| **Ce qui survit intact** | `revealController` (la seule affirmation du relevé tenue à la réfutation) et `ZcrudScope.derive` : ni l'un ni l'autre ne touche à une donnée. |

### C6 — Le codegen du chat contre l'option B (« zéro migration Firestore »)

| | |
|---|---|
| **Ce que le relevé propose** | `confrontation-ia-chat-generation.md:165-180` : annoter `chatbot_conversation.dart` / `chatbot_message.dart`, « **16 `Timestamp`** retirés du domaine », ≈ 677 l. |
| **Ce que le propriétaire a tranché** | **Option B** (`chiffrage-migration-chat.md:290-313`) : garder `ChatbotMessage`, **aucune écriture ne change**, projection **unidirectionnelle** gardée par deux tests structurels (`:342-356`). Et **§4.2** est nommément *« le point qui interdit la migration message par message »* : une date passée en chaîne ISO est relue **`null`** par le codec legacy, le tri rend `return 0`, et *« la conversation s'affiche dans le désordre, sans erreur, sans journal, sans que rien ne rougisse »* (`:154-177`). |
| **Laquelle prime** | 🔴 **La décision.** La proposition du relevé fait exactement ce que la garde `test/w9a/` **fait rougir par construction**, et déclenche le §4.2. Elle est irrecevable en l'état. |

### C7 — Les six paquets **écartés avec motif** présentés comme un manque

`etat-des-lieux.md:28` liste « **16 paquets du socle non déclarés du tout** », dont
`zcrud_html`, `zcrud_geo`, `zcrud_geo_location`, `zcrud_reorder`, `zcrud_provider`, `zcrud_get` —
les **six écartés, motivés** de **DEC-4** (`:196-209`) : Markdown déjà tranché contre HTML, aucune
coordonnée persistée, `ZDefaultReorderRenderer` explicitement retenu, bindings d'état concurrents
de Riverpod. Le relevé ne recommande nulle part de les adopter (grep : ils n'apparaissent que dans
des **listes**), mais il présente leur absence comme un écart **sans la motivation qui la ferme** —
c'est précisément ce que DEC-4 dit vouloir empêcher : *« pour que la question ne se repose pas »*.
🟡 **Correction rédactionnelle**, pas contradiction de fond : reclasser 6 des 16 en « écartés,
motivés » et 1 (`zcrud_dnd`) en « sur besoin ».

---

## 3. Ce que le relevé propose et qui était **DÉJÀ PLANIFIÉ** — ne pas facturer deux fois

| Proposition du relevé | Déjà planifié par l'hôte | Statut |
|---|---|---|
| `etat-des-lieux.md:325` — « Allumer les 12 bascules du domaine dossiers d'étude » | **M1 / fil A** : les 40 bascules, classées par nature de risque le 2026-08-19 (`plan-migration-zcrud-v2.md:178-312`) | **M1-0 FAIT** ; le relevé redécouvre le fil A sans le nommer |
| `confrontation-etude-matieres-corpus.md:235` — « M6 — Le corpus par codegen, ≈ 1 230 l » (Valuation + CGI) | **N3-a** (Valuation, 11 classes, 581 l, **aucune fuite**) et **N3-b** (CGI, 8 classes, ~810 l) — `plan-modeles-zentity-codegen.md:126-137`, `:393-414` | ✅ **recevable et déjà cadré** — c'est le meilleur candidat, à condition de passer par **N1 (pilote)** d'abord |
| Lot 9 — `zcrud_generator` (GEN-1..3) en dernier | **N0** (les trois verrous) puis **N1** (un seul modèle de bout en bout) ; « le coût d'une story N3 n'est pas connu tant que N1 n'a pas été fait » (`:581`) | convergent sur l'ordre, divergent sur l'unité : l'hôte impose un **pilote mesuré**, le relevé non |
| Lot 6 — `CORE-1` (`ZCrudAction` ouvert) | non planifié côté hôte — **apport propre du relevé** | ✅ neuf |
| Lot 5 — `SES-1..4` (saisie de réponse) | recoupe **M1-3** (bascules de données de la révision) et **DEC-16** | à articuler avec M1-3b |
| Entrées 21/22 — `minQuality`, `floor` | **DEC-16** (story M1-3b) et **DEC-18** | déjà tranché ; le relevé apporte la **mesure**, pas la décision |
| §5 — « ce qui reste à l'hôte » (matrice d'ACL, prompts, SH, `IffdRichTextCodec`, `Task extends google_api.Task`) | **DEC-11**, **DEC-25**, `perimetre` | ✅ **concordant** — c'est la partie la mieux alignée du relevé |
| DEC-24 / scope global | `confrontation-etude-matieres-corpus.md:52`, `:107` voient bien `main.dart:270` | ✅ le relevé est à jour ici |
| Entrée 20 — `ZcrudScope.derive` | **compatible** avec DEC-24 (« les scopes locaux restent légitimes ») : `.derive` est exactement le correctif du masquage | ✅ apport propre, à conserver |

---

## 4. Ce que les documents de l'hôte savent et que le relevé ignore

### 4.1 Cinq obstacles de codegen mesurés, aucun repris

`plan-modeles-zentity-codegen.md:139-224` — le relevé n'en cite **aucun** :

| # | Obstacle | Source | Effet sur les chiffres du relevé |
|---|---|---|---|
| 2.1 | **camelCase contre snake_case** — perte silencieuse à la première écriture | `:141-153` | invalide tout chiffrage sans `ZFieldRename.none` (C3) |
| 2.2 | **Le piège des dates**, documenté par le socle lui-même | `:154-183` | cf. C2 |
| 2.3 | **Types Flutter et tiers** — **échec de build**, pas cast silencieux | `:184-196` | 36 champs `Map<…>` + 13 autres types non classifiables (`refutation-…-M3-…:159`, seul point où le relevé le mesure) |
| 2.4 | **`ZExtensible` obligatoire** dès qu'une clé hors schéma existe | `:197-203` | aucun chiffrage du relevé ne l'intègre |
| 2.6 | 🔴 **Douze modèles sont des `part of`** — la granularité du codegen leur échappe | `:208-224` | non mentionné du tout par le relevé |

Et **trois défauts structurels à fermer AVANT de toucher un modèle** (`:225-284`) :
`FIREBASE_COLLECTION_NAMES` **vide** (le nom de collection est `T.toString()`) ; le registre
`fromMap<T>` **casse un `null` en `T`** (`data_functions.dart:411-412`) ; le graphe de données est
construit **hors de Riverpod** (38 `RepositoryImpl()` hors `ProviderScope`, `smartLearnInstance`
court-circuitant les providers dans 17 fichiers).

### 4.2 Un registre de **61 bugs préexistants** ignoré (2 669 lignes)

`dette-bugs-preexistants.md` recense **B-1 → B-61**, dont **6 pertes de données** à reproduire
telles quelles (`ExamModel.reminderTime`, `MindmapNode.resizable`, `AppUserData.fromMap`,
`AnneeAccademique.copyWith`, `Paragraphe.copyWith`, `FlashcardModel.hsChapter`) et **B-7** — les
11 modèles en `implements DynamicModel`, donc **égalité référentielle**, `props` mort, marqué
« ne pas corriger seul ». Le relevé cite `B-2`, `B-11`, `B-12`, `B-24`, `B-58`, `B-60` **au fil
des cartes**, jamais le registre ni sa règle de séquencement. Conséquence directe : **C5**.

### 4.3 Un chiffrage du chat déjà fait, et **six points de perte** identifiés

`chiffrage-migration-chat.md` : **8 250 l** de présentation, **27 champs → 17 + `extra`**,
**18 champs sans équivalent**, **6 points de perte** — dont le **§4.5 (le fuseau horaire disparaît
à la réécriture) trouvé par le test de caractérisation, pas par la lecture du code**, et
**13 gardes** figées dans `test/chat/chatbot_message_characterization_test.dart`. Le relevé chiffre
le chat sans rien de tout cela.

### 4.4 Deux périmètres décidés, dont un **révisé le jour même**

- `perimetre-portage-apprentissage.md:15-37` (2026-07-30) exclut `administration`, `auth`, `tasks`,
  `home`, `valuation_tools`. **Mais** `retrait-modules-juridiques.md:10-31` (même jour) porte le
  **changement de stratégie du propriétaire** : *« je veux qu'on porte intégralement IFFD »* ⇒
  Valuation **rouvert**, dans le périmètre ; puis **DEC-8** (2026-08-19) fait entrer `ai_experts`
  (rangé sous `administration/`) et **DEC-25** (2026-08-25) travaille les formulaires
  d'administration. ⇒ 🔴 **Le document de périmètre est périmé ; le citer tel quel ferait sortir du
  périmètre des chantiers que le propriétaire y a remis.** Le relevé ne le cite pas — il tombe juste
  par accident, pas par lecture.
- `retrait-modules-juridiques.md:7` : **bloc A déjà supprimé** — 19 fichiers, **9 931 lignes**. Tout
  chiffrage de « lignes à porter » antérieur à cette date est faussé d'autant.

### 4.5 Une source que le propriétaire a déclarée **fausse**

**DEC-6** (`decisions-adoption-zcrud.md:225`) : *« L'affirmation "le socle n'a aucune primitive de
chat" (`etat-migration-zcrud.md` § 2.4) est **fausse**. »* ⇒ `etat-migration-zcrud.md` (108 l) ne
doit pas être repris sans cette réserve.

### 4.6 Deux pratiques d'hôte que le relevé aurait dû nommer comme contraintes

- **Le tripwire** : le relevé le remonte bien (`etat-des-lieux.md:392-397`), mais comme une *bonne
  pratique à propager*. Côté chat c'est une **contrainte dure** : deux gardes structurelles
  interdisent l'écriture (`chiffrage-migration-chat.md:342-356`). Toute proposition qui les fait
  rougir est refusée par construction, pas par arbitrage.
- **DEC-23** : les versions du socle sont adoptées **automatiquement**. Un relevé qui présente une
  montée de version comme un chantier à décider se trompe de sujet ; ce qui reste soumis au
  propriétaire, ce sont les **choix de produit** que la livraison ouvre (poser un jeton qui change
  le rendu, adopter un paquet optionnel).

---

## 5. Verdict de la lentille

| | Compte |
|---|---:|
| Décisions recensées qui contraignent la migration | **35** (3 racines + DEC-4→DEC-32 + 2 règles de séquencement + option B chat) |
| Recommandations du relevé qui **contredisent** une décision prise | **6** (C1, C2, C3, C5, C6 + C4 partiel) |
| Recommandation à corriger rédactionnellement | **1** (C7) |
| Lignes de « migrable aujourd'hui » que ces contradictions retirent | **≈ 1 239** : **562** (C1, groupe 🅰️ du domaine dossier : 639 − 77) + **677** (C6, chat) |
| Propositions déjà planifiées par l'hôte, à ne pas refacturer | **≥ 7** |
| Documents de l'hôte à intégrer avant toute nouvelle version du relevé | **12** (7 364+ l) |

**Ce qui doit être retiré ou requalifié avant que le relevé soit exploitable** :
1. le codegen sur le **groupe A** (dossiers **et** chat) — C1, C6 ;
2. `ZPersistAs.timestamp` comme canal recommandé — C2 ;
3. « le lot de suppression d'abord » et « les cinq corrections en premier » — C4, C5 ;
4. tout chiffrage codegen ne portant pas `ZFieldRename.none` et les cinq obstacles — C3, §4.1.

**Ce qui reste intact et gagne à être remonté au propriétaire** : `revealController`,
`ZcrudScope.derive`, `CORE-1` (`ZCrudAction` ouvert), le codegen du **groupe 🅱️** (Valuation + CGI,
via le pilote N1), `zFoldDiacritics`, `ZCascadeRegistry`, `zAdvanceStreak` (**comme mesure**, la
correction restant subordonnée à la caractérisation), et le §5 « ce qui reste à l'hôte » —
la partie du relevé la plus alignée avec les décisions.
