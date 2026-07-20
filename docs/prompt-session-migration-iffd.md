# Prompt — Session Claude dédiée : migration progressive de IFFD vers zcrud

> À coller tel quel comme **premier message** d'une session Claude Code ouverte dans
> `/home/zakarius/DEV/iffd`.
>
> Mesures de reconnaissance datées du **2026-07-20**, zcrud au tag **`v0.3.1`**.
> Elles sont un point de départ, pas une vérité : **re-mesure tout ce sur quoi tu t'appuies.**

---

## 0. Rôle, périmètre et contrainte d'écriture

Tu conduis la **migration progressive de IFFD vers les packages `zcrud`**. IFFD est
historiquement **la source** de ce moteur : `lib/data_crud/` est le code dont zcrud a été
extrait, et son `folder_study_tools_page.dart` a servi de **référence d'apparence** à
`ZStudyToolsPage`. Tu ne branches donc pas une bibliothèque neuve : tu **remplaces du code
en production par sa version consolidée**.

**Contrainte d'écriture — NON-NÉGOCIABLE :**

| Repo | Droit |
|---|---|
| `/home/zakarius/DEV/iffd` | **ÉCRITURE AUTORISÉE** (seul repo modifiable) |
| `/home/zakarius/DEV/zcrud` | **LECTURE SEULE** — référence canonique, jamais édité |
| `/home/zakarius/DEV/lex_douane`, `/home/zakarius/DEV/dodlp-otr`, `/home/zakarius/DEV/dlcfti-otr` | **LECTURE SEULE** |

Tout besoin exigeant une modification de zcrud se consigne dans
`docs/zcrud-change-requests.md` (côté IFFD) — package, symbole, comportement attendu, cas
d'usage, sévérité — puis se contourne app-side si possible. Une session zcrud dédiée le
traitera, suivie d'un nouveau tag. **Ce canal fonctionne** : la session lex_douane a émis
4 CR, dont 2 livrées en `v0.3.1` et une qui a corrigé une documentation fausse.

---

## 1. 🔴 LA question à trancher AVANT tout le reste : GetX ou Riverpod ?

**Il existe une contradiction entre le plan zcrud et l'état réel de IFFD. Ne commence
rien avant de l'avoir tranchée avec l'owner.**

Le plan zcrud (epic ES-11) prévoyait pour IFFD le binding **`zcrud_get`** (GetX + `get_it`).
Or les mesures disent autre chose :

| Constat sur disque | Implication |
|---|---|
| `flutter_riverpod` **3.1.0** + `riverpod_generator` 4.0.0+1 déclarés | Riverpod est déjà en place |
| **117 fichiers** référencent Riverpod ; arbo dédiée `lib/src/features/*/providers/` avec 16 `*.g.dart` | Migration Riverpod **déjà bien avancée** |
| `_bmad-output/` contient une **roadmap de migration Riverpod** (9 stories, `1-1` → `1-9`) | C'est **votre chantier central documenté** |
| **`get_it` est ABSENT** du pubspec | `zcrud_get` l'imposerait comme dépendance neuve |
| **`reflectable` est ABSENT** (vestige commenté dans `reflector.dart`) | Le `ReflectableCodec` de `zcrud_get` est **inutile ici** (il visait DODLP) |
| GetX subsiste : `get` 4.7.3, 46 `Get.put/find`, base maison `Controller extends ChangeNotifier` | Legacy en cours de retrait |

**Adopter `zcrud_get` reviendrait à investir dans le paradigme que vous êtes en train de
quitter, et à introduire `get_it` que vous n'utilisez pas.** `zcrud_riverpod` (v0.3.1, en
Riverpod **3.3.x**) est aligné sur votre direction ; il vous faudrait monter de 3.1.0 à
3.3.x — même majeure, montée mineure.

**Recommandation à soumettre à l'owner : `zcrud_riverpod`.** Mais c'est **sa** décision :
expose-lui le constat, ta recommandation motivée, et attends. Ne présuppose pas que le
plan d'origine (ES-11.1) fait foi — il a été écrit avant que la migration Riverpod
d'IFFD n'atteigne ce niveau.

---

## 2. Ce que zcrud fournit (état réel au tag `v0.3.1`)

Monorepo Flutter, **28 packages**, distribué **en privé par dépendance git sur tag** —
jamais publié sur pub.dev. **Lis `zcrud/docs/private-git-consumption.md` en entier avant
de toucher au `pubspec.yaml`** : la recette y a été corrigée le 2026-07-20 (CR-1) et la
précédente **ne résolvait pas**.

- **Socle** : `zcrud_core` (domaine pur, `ZFieldSpec`, moteur d'édition, l10n, `ZcrudScope`),
  `zcrud_annotations`, `zcrud_generator` (dev).
- **Étude** : `zcrud_study_kernel` (`ZStudyFolder`, hiérarchie, `ZStudySessionConfig`),
  `zcrud_document`, `zcrud_note`, `zcrud_exam`, `zcrud_flashcard`, `zcrud_mindmap`,
  `zcrud_session` (runtimes SRS/cramming/liste), `zcrud_study` (**`ZStudyToolsPage`** —
  portée depuis VOTRE `folder_study_tools_page.dart`).
- **UI transverse** : `zcrud_responsive`, `zcrud_navigation`, `zcrud_ui_kit`.
- **Champs & rendu** : `zcrud_markdown` (Quill + `ZCodec`), `zcrud_html`, `zcrud_media`,
  `zcrud_select`, `zcrud_field_extras`, `zcrud_geo`, `zcrud_intl`, `zcrud_list`
  (Syncfusion), `zcrud_export`, `zcrud_export_ui`.
- **Data** : `zcrud_firestore` (Firestore + Hive offline-first) — **porte le migrateur
  legacy, cf. § 4**.
- **Bindings** : `zcrud_riverpod`, `zcrud_get`, `zcrud_provider`.

**Invariants (AD-1..AD-56)** — source : `zcrud/_bmad-output/planning-artifacts/architecture/`.
Ceux qui vont te contraindre le plus, parce que **IFFD les viole aujourd'hui** :

- **AD-5 / AD-16 — domaine backend-agnostique** : `Timestamp`, `Color`, `IconData` ne
  doivent **jamais** apparaître dans une entité. Vos modèles en sont truffés (§ 3).
- **AD-2 / AD-15 — réactivité Flutter-native dans le cœur** : `ChangeNotifier` /
  `ValueListenable`, aucun gestionnaire d'état dans `zcrud_core`.
- **AD-10 — désérialisation défensive** : un champ absent ou corrompu ne fait jamais
  échouer le parent.
- **AD-13 — RTL, `Semantics`, cibles ≥ 48 dp.**
- **SM-1** : taper 100 caractères ne reconstruit que le champ courant.

---

## 3. État mesuré d'IFFD (2026-07-20) — re-vérifie, ne crois pas

**Volume** : 462 fichiers `.dart`, ~151 700 LOC.

**Le moteur à remplacer** : `lib/data_crud/` = **32 fichiers, 16 889 LOC**, importé par
**53 fichiers hors du dossier**. Types clés : `EditionFieldTypes`
(`edition_field.dart:18`), `DynamicFormField<T>` (`:80`), `DynamicEditionScreen<T>`
(`edition_screen.dart:92`), `DynamicModel` (`lib/src/domain/models/dynamic_model.dart:3`),
`FirebaseCrudRepositoryImpl<T extends DynamicModel>`, `CrudRepository<T>` (≈33 sous-repos).

⚠️ **C'est l'écart fondamental avec la migration lex_douane** : lex n'avait aucun moteur
déclaratif, `DynamicEdition` y était une addition sans risque de régression. Ici, chaque
écran migré **retire du code qui fonctionne en production**. Le risque n'est pas
« ça manque », c'est « ça marchait avant ».

**God controller** : `DiscovryPageController` — **2 359 LOC**
(`lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart`),
`extends Controller with ChatbotMixin, AutoRouterMixin`, important flashcards, folders,
mindmap, smartnotes, subjects, ai + les 3 modules. C'est la dette `DW-ES113-1`.

**Modèles domaine** (`lib/src/domain/models/`, 31 fichiers) — **fuites backend massives** :
- **13 modèles importent `cloud_firestore`** (`Timestamp`) : `folder_model`,
  `flashcard_model`, `mindmap_model`, `smart_note_model`, `exam_model`,
  `flashcard_repetition_info`, `flashcard_tag_model`, `folder_document`, `subject_model`,
  `app_user`, `folder_invitation`, `annee_accademique`, `requests/data_request`.
- **10 modèles importent `flutter/material`** (`Color`/`IconData`).
- **1 modèle importe `flutter_flow_chart`** : `mindmap_model.dart`.

**Sérialisation** : **manuelle**, via `DynamicModel.toMap()`/`fromMap()` (29/31 modèles).
`json_serializable` et `freezed` sont déclarés mais **quasi inutilisés** (un seul
`.freezed.dart`, pour `Failure`). `build_runner` sert surtout les providers Riverpod et
`auto_route`.

**Tests** : **11 fichiers `*_test.dart` seulement**, dont 9 tests de providers Riverpod.
**Zéro test widget ou d'intégration** sur les écrans flashcards, mindmap ou
`folder_study_tools_page.dart`. Mindmap : **0 test**.

⚠️ **Conséquence directe et non négociable** : tu n'as **presque aucun filet**. Pour
chaque écran que tu migres, **le test de non-régression s'écrit AVANT la migration**, sur
le comportement legacy. Sans cela, tu ne migres pas — tu réécris à l'aveugle.

**Pas de `CLAUDE.md`** dans le repo. Le projet est piloté par BMAD (`_bmad/`,
`_bmad-output/`).

---

## 4. 🔴 La migration de DONNÉES — le risque n° 1, et le piège qui va avec

C'est le second écart majeur avec lex_douane, dont les entités étaient **déjà canoniques**.
Ici, **les données de production sont en schéma legacy plat** et doivent être converties.

### Ce que zcrud fournit (ne réimplémente rien)

`zcrud_firestore` exporte **`ZLegacyStudyMigrator`**
(`lib/src/data/z_study_migrator.dart`) :

- `ZDocumentMigrationOutcome migrateDocument(Map<String,dynamic> legacy)`
- `ZLegacyMigrationReport migrateCorpus(Iterable<Map<String,dynamic>> corpus)`
- Signatures **`Map<String,dynamic>` uniquement** — aucun type `cloud_firestore` ni `hive`.
- **Ne lève JAMAIS**, quel que soit l'input (AD-10).
- **Census R26** : chaque clé métier legacy est retrouvable en sortie — renommée en
  snake_case (`subjectId` → `subject_id`) **ou** préservée à l'identique sous
  `_legacy_<snake>`. Aucune clé n'est silencieusement perdue.
- `ZSyncMeta` **additif** : `is_deleted:false` via `putIfAbsent` (jamais d'écrasement),
  `updated_at` laissé absent (LWW « jamais synchronisé »). Ces clés vivent **hors-entité**
  et ne polluent ni le corps ni `extra`.

Suite de tests : `packages/zcrud_firestore/test/z_study_migrator_test.dart` — **30/30 verts
sous v0.3.1**. Lis-la : elle documente le comportement mieux que n'importe quelle prose.

### ⛔ LE PIÈGE — à lire deux fois

> **`ZStudyLegacyCodec.toCanonical` n'est PAS idempotent sur le champ `status`.**
> `mapDocumentStatus` ne connaît que les **6 valeurs legacy**
> (`uploading` ; `converting`/`embedding` → `validating` ;
> `uploaded`/`converted`/`embedded` → `ready` ; inconnu/null/non-String → `uploading`).
> Une valeur **déjà canonique** (`ready`, `validating`) tombe dans le `default` → elle est
> **rétrogradée en `uploading`**.

Autrement dit : **appliquer le codec deux fois corrompt les données, en silence, sans
lever la moindre erreur.** Et un second passage est *certain* — reprise après
interruption, relance manuelle, corpus mêlant documents déjà migrés et non migrés.

**`ZLegacyStudyMigrator` porte la garde d'idempotence** (`migrate ∘ migrate = migrate`,
point fixe prouvé, drapeau `alreadyCanonical`). **Le codec nu, non.**

🚫 **Règle absolue : n'appelle JAMAIS `ZStudyLegacyCodec.toCanonical` directement sur un
corpus. Passe TOUJOURS par `ZLegacyStudyMigrator`.**

### Ce qui est spécifique à IFFD et n'est PAS couvert par le migrateur

Le migrateur convertit la **forme des documents**. Il ne renomme **pas les collections**.
Or vos noms de collection sont dérivés du **nom de la classe Dart** :

```dart
// lib/src/utils/functions/databases_functions.dart:8-33
collectionName = FIREBASE_COLLECTION_NAMES[T] ?? T.toString()
// FIREBASE_COLLECTION_NAMES est une map const VIDE
//   → collections réelles : `FlashcardModel`, `FolderModel`, `MindmapModel`,
//     `SmartNoteModel`, `FolderDocument`, …
```

Schéma **plat confirmé** : aucun `parentPath` n'est passé pour Folder/Flashcard/Mindmap/
SmartNote — pas de sous-collections. zcrud, lui, attend une topologie imbriquée
`users/{uid}/{parent}/{parentId}/{collection}` avec des noms snake_case.

⚠️ **Le renommage de collections et le passage plat → imbriqué sont donc à ta charge**, et
c'est la partie la plus risquée du chantier. Traite-la comme une **migration de données de
production** : sauvegarde préalable, exécution idempotente, rapport de census, réversibilité.

---

## 5. ⚠️ Pré-vol — bloqueurs de résolution

**Mesure tout avec `dart pub get --dry-run`. Un `pubspec.lock` qui résout est la seule
preuve acceptable ; « ça devrait marcher » n'en est pas une.**

### 🔴 (a) `awesome_select` — conflit de source certain

**IFFD déclare déjà `awesome_select` en dépendance git sur l'AMONT :**

```yaml
awesome_select:
  git: { url: https://github.com/akbarpulatov/flutter_awesome_select.git, ref: master }
```

`zcrud_select` (v0.3.1) le déclare sur **notre fork** :
`https://github.com/zakarius-dev/awesome_select.git` `ref: v6.1.0`.
**Deux URL git différentes pour un même paquet ⇒ pub échoue.**

**Bascule vers notre fork** — et ce n'est pas une simple formalité : **l'amont que vous
utilisez aujourd'hui porte un bug de production**. Dans
`lib/src/state/choices.dart`, `load(S2ChoicesTask _task)` fait `task = task;` —
une auto-affectation du getter, donc un **no-op** : l'état de tâche n'est jamais mis à
jour. Notre fork corrige (`task = _task;`), en plus des correctifs Dart 3
(`abstract mixin class`) et Flutter M3 (`ColorScheme.error`).

### 🔴 (b) Syncfusion — **deux majeures** de retard

| | IFFD | zcrud |
|---|---|---|
| `syncfusion_flutter_*` | `^32.1.21` | **`^34.1.31`** |

Syncfusion exige des majeures **alignées entre modules**. Tant qu'IFFD reste en 32,
**`zcrud_list` et `zcrud_export` sont inconsommables**. C'est une montée app-side, à
traiter comme une vague dédiée (8 modules Syncfusion déclarés : core, calendar, charts,
datagrid, pdf, pdfviewer, sliders, chat) avec vérification **visuelle** — un `analyze`
vert ne prouve rien sur du rendu.

### ✅ (c) Bonne nouvelle : `file_picker` ne vous bloque PAS

Contrairement à lex_douane (bloquée en `12.0.0-beta.5`), IFFD est en **`^10.3.8`**,
compatible avec le `^10.3.3` de `zcrud_media`. **`zcrud_html` et `zcrud_media` sont donc
consommables par IFFD** — ils sont hors périmètre pour lex, pas pour vous.
`html_editor_enhanced ^2.7.1` et `flutter_quill 11.5.0` sont **identiques** des deux côtés.

### ⚠️ (d) Points à vérifier

- **SDK** : IFFD déclare `>=3.10.4 <4.0.0`, les packages zcrud `^3.12.2`. Ça passe si le
  SDK réellement installé est ≥ 3.12.2 — vérifie-le.
- **`hive` absent d'IFFD** : `zcrud_firestore` l'introduira (store local offline-first).
- **`get_it` absent** : ne l'ajoute que si l'owner tranche pour `zcrud_get` (§ 1).
- **Recette de consommation** : `dependency_overrides` **obligatoire** pour toute la
  fermeture transitive `zcrud_*` — cf. `zcrud/docs/private-git-consumption.md`.

---

## 6. Séquencement imposé

| Vague | Contenu | Risque |
|---|---|---|
| **W0** | Décision GetX/Riverpod (§ 1) + plomberie de dépendance + bascule `awesome_select` + composition-root. **Zéro écran migré.** | — |
| **W1** | **Filet de sécurité** : tests de caractérisation sur les écrans d'étude legacy (flashcards, mindmap, study tools). Aucun code de prod touché. | faible, **indispensable** |
| **W2** | Montée **Syncfusion 32 → 34** (vague dédiée, vérif visuelle) | moyen |
| **W3** | **Mindmaps** en lecture — `zcrud_mindmap` égale ou dépasse l'existant | faible |
| **W4** | **Migration de données** flat → canonique via `ZLegacyStudyMigrator`, **en lecture seule d'abord** (dry-run + rapport de census, aucune écriture) | **élevé** |
| **W5** | Cutover **repo par repo**, ancien chemin conservé derrière un flag | élevé |
| **W6** | Écrans d'étude → `ZStudyToolsPage` (parité d'apparence : c'est **votre** design d'origine) | moyen |
| **W7** | Formulaires : `DynamicEditionScreen` → `DynamicEdition`, **écran par écran** sur les 53 appelants | élevé |
| **W8** | Retrait de `lib/data_crud/` + démantèlement du god controller (`DW-ES113-1`) | **le plus élevé** — ne le commence pas avant que W7 soit intégralement terminé |

**Ne réordonne pas.** En particulier : **W1 avant tout le reste** (vous avez 11 tests pour
151 k lignes), et **W8 en dernier** — supprimer 16 889 lignes encore référencées par 53
fichiers est irréversible en pratique.

---

## 7. Règles de migration — non négociables

- ✅ **Strangler fig, jamais big-bang.** Chaque écran migré garde son chemin legacy
  accessible jusqu'à preuve de non-régression. Une story = un écran ou un repo.
- ✅ **Test de caractérisation AVANT migration.** Là où il n'existe rien (c'est le cas
  presque partout), écris d'abord un test qui capture le comportement **actuel**.
- ✅ **Aucune perte de donnée silencieuse.** Tout champ sans homologue zcrud va dans
  `extra: Map<String,dynamic>` ou le slot `ZExtension` versionné — ou est **explicitement
  documenté comme abandonné, avec accord de l'owner**.
- ✅ **Test de round-trip** sur chaque entité migrée : `modèle IFFD → Z* → Firestore → Z*
  → modèle IFFD`, sans perte. C'est ton filet principal.
- ✅ **Nettoyage des fuites backend** : `Timestamp` → ISO-8601, `Color`/`IconData` →
  valeurs neutres (clé de thème, nom d'icône) résolues en présentation. Le domaine ne doit
  plus importer `cloud_firestore` ni `material`.
- ✅ **`Semantics` + ≥ 48 dp + variantes directionnelles** sur tout widget touché (AD-13).
- 🚫 **Jamais** `ZStudyLegacyCodec` nu sur un corpus — toujours `ZLegacyStudyMigrator`.
- 🚫 **Jamais** `git checkout` / `git restore` / `git stash` sur du travail non committé.
- 🚫 **Jamais** modifier un fichier hors de `iffd`.
- 🚫 **Jamais** valider une étape sur le rapport d'un sous-agent : **relis le disque**.

---

## 8. Vérif verte — rejouée par toi, jamais sur la foi d'un rapport

```bash
dart pub get                  # doit résoudre sans conflit
dart run build_runner build --delete-conflicting-outputs   # providers Riverpod + auto_route
flutter analyze               # RC=0
flutter test                  # RC=0
```

⚠️ **`flutter analyze` vert ne prouve PAS que ça compile.** Vérifié à deux reprises côté
zcrud pendant la montée de version : `analyze` était vert sur du code qui **échouait à la
compilation** (une API supprimée dans une dépendance). Seuls `flutter test` et un build
réel compilent pour de bon. Sur les vagues UI (W2, W6, W7), ajoute un build et
**exerce les écrans à la main**.

---

## 9. Processus — BMAD

IFFD est déjà piloté en BMAD (`_bmad/`, `_bmad-output/` avec une roadmap Riverpod active).
Applique le cycle strict :

```
create-story → dev-story → vérif verte → code-review → fix findings → done
backlog → ready-for-dev → in-progress → review → done      (aucun saut)
```

⚠️ **Deux chantiers en vol** : votre migration Riverpod (9 stories) et celle-ci. **Ne les
entrelace pas sur les mêmes fichiers.** Au moment de planifier, croise ton périmètre avec
`_bmad-output/planning-artifacts/roadmap-migration-riverpod.md` et signale tout
recouvrement à l'owner — deux migrations simultanées sur un même écran, c'est la garantie
de ne plus savoir laquelle a cassé quoi.

Un commit par story, message explicite. Le `pubspec.lock` fait partie du livrable quand la
story **est** un changement de dépendance ; sinon exclus-le.

---

## 10. Livrables de cette première session

1. **La décision GetX/Riverpod (§ 1)**, posée à l'owner avec ta recommandation motivée.
   **Rien d'autre ne démarre avant.**
2. `docs/zcrud-integration-inventory.md` — inventaire de reconnaissance : correspondance
   modèle-par-modèle IFFD ↔ `Z*` (champs identiques / renommés / absents des deux côtés —
   **tout écart est un risque de perte**), cartographie des 53 appelants de `data_crud`,
   topologie Firestore réelle, et surface de non-régression par écran.
3. **Un plan de migration séquencé** (epics + stories BMAD) respectant W0→W8, avec pour
   chaque story : périmètre, critère de non-régression, **critère de rollback**.
4. `docs/zcrud-change-requests.md` — initialisé, même vide.
5. La **note de pré-vol** (§ 5) : bascule `awesome_select`, plan Syncfusion 32→34, SDK.

**N'écris aucun code de migration avant que le plan soit validé.** Commence par § 1, puis
la reconnaissance.

---

## 11. Communication

**Français**, orthographe et diacritiques complets ; termes techniques et identifiants de
code inchangés. Après **chaque** étape BMAD, un **résumé concis non sollicité** : étape et
skill réellement invoqué, ce qui a été produit, **résultats de vérification réellement
rejoués sur disque** (commandes, RC, nombre de tests), findings de revue avec leur statut,
transition de statut appliquée.
