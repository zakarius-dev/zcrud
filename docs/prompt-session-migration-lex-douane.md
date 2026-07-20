# Prompt — Session Claude dédiée : intégration & migration progressive de zcrud dans lex_douane

> À coller tel quel comme **premier message** d'une session Claude Code ouverte dans
> `/home/zakarius/DEV/lex_douane`.

---

## 0. Rôle, périmètre et inversion de la contrainte d'écriture

Tu ouvres une session dédiée à l'**intégration progressive du monorepo `zcrud`** dans
l'application **lex_douane**. Le travail zcrud-side est **terminé et figé** : tout ce qui reste
est **100 % app-side**.

**Contrainte d'écriture — NON-NÉGOCIABLE, inversée par rapport aux sessions zcrud :**

| Repo | Droit |
|---|---|
| `/home/zakarius/DEV/lex_douane` | **ÉCRITURE AUTORISÉE** (seul repo modifiable) |
| `/home/zakarius/DEV/zcrud` | **LECTURE SEULE** — référence canonique, jamais édité |
| `/home/zakarius/DEV/iffd`, `/home/zakarius/DEV/dodlp-otr`, `/home/zakarius/DEV/dlcfti-otr` | **LECTURE SEULE** — comparaison de parité uniquement |

Si un besoin réel exige de **modifier zcrud** (API manquante, bug dans un package), tu ne le fais
**pas** : tu **consignes une demande de changement** dans
`docs/zcrud-change-requests.md` (côté lex_douane) — chemin du package, symbole, comportement
attendu, cas d'usage lex, sévérité — et tu **contournes app-side** si possible. La correction
sera faite dans une session zcrud dédiée, suivie d'un nouveau tag.

---

## 1. Ce qu'est zcrud (état réel au 2026-07-20)

Monorepo Flutter (pub workspaces + melos), **29 packages** sous `packages/`, distribué **en
privé par dépendance git sur tag** (`github.com/zakarius-dev/zcrud`) — jamais publié sur pub.dev.
Doc de consommation faisant foi : **`zcrud/docs/private-git-consumption.md`** (lis-la en entier
avant toute manipulation de `pubspec.yaml`).

**Familles de packages :**

- **Socle** : `zcrud_core` (domaine pur + moteur d'édition + `ZFieldSpec` + l10n + `ZcrudScope`),
  `zcrud_annotations`, `zcrud_generator` (dev_dependency).
- **Étude** : `zcrud_study_kernel` (`ZStudyFolder`, hiérarchie, `ZFolderContentsOrder`,
  `ZStudySessionConfig`), `zcrud_document`, `zcrud_note`, `zcrud_exam`, `zcrud_flashcard`,
  `zcrud_mindmap`, `zcrud_session` (runtimes SRS/cramming/liste), `zcrud_study` (orchestration
  `ZStudyToolsPage`).
- **UI transverse** : `zcrud_responsive` (`ZWindowSizeClass`, `ZBreakpointValue<T>`),
  `zcrud_navigation` (`ZEditionPresentation`, `ZPresentationPolicy`), `zcrud_ui_kit`
  (`ZContentState`, `ZEmptyState/Loading/Error`, `ZConfirmDialog`).
- **Champs & rendu** : `zcrud_markdown` (Quill + `ZCodec`), `zcrud_html`, `zcrud_media`,
  `zcrud_select` (+ fork vendorisé `awesome_select`), `zcrud_field_extras`, `zcrud_geo`,
  `zcrud_intl`, `zcrud_list` (Syncfusion `SfDataGrid` derrière `ZListRenderer`), `zcrud_export`,
  `zcrud_export_ui`.
- **Data** : `zcrud_firestore` (adapters Firestore + Hive offline-first).
- **Bindings** : **`zcrud_riverpod`** ← *c'est le tien*, `zcrud_get`, `zcrud_provider`.

**Invariants d'architecture** (16 AD de base + extensions AD-17..AD-56) — source de vérité :
`zcrud/_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`
et les spines d'extension du même dossier. Les plus structurants pour toi :

- **AD-1** : graphe acyclique, `zcrud_core` ne dépend d'aucun autre `zcrud_*` (CORE OUT = 0).
- **AD-2 / AD-15** : réactivité **Flutter-native** dans le cœur (`ChangeNotifier` /
  `ValueListenable`). **Aucun gestionnaire d'état dans `zcrud_core`.** Riverpod n'existe que dans
  `zcrud_riverpod`. Corollaire pour toi : **ne cherche pas de `ConsumerWidget` dans le cœur** —
  tu branches Riverpod *autour*, pas *dedans*.
- **AD-5 / AD-11 / AD-16** : repositories → `Either<ZFailure, T>` (dartz), flux =
  `Stream<List<T>>` **nus**, domaine backend-agnostique (`Timestamp`/`Filter` confinés à
  `zcrud_firestore`).
- **AD-10** : désérialisation défensive — un champ absent/corrompu ne fait jamais échouer le
  parent.
- **AD-13** : RTL (variantes directionnelles) + `Semantics` + cibles ≥ 48 dp.
- **SM-1** (objectif produit n° 1) : taper 100 caractères dans un formulaire ne reconstruit que
  le champ courant, zéro perte de focus.

---

## 2. Pourquoi lex_douane est le consommateur privilégié

Le **schéma canonique** de zcrud a été **porté depuis lex_douane** (module « Étude »,
`packages/lex_core/lib/domain/entities/education/`) : ~25 entités pures Dart,
`@JsonSerializable(fieldRename: snake)`, enums camelCase, désérialisation défensive systématique,
séparation stricte contenu-partageable / état-personnel. C'est **la source la plus propre des
trois apps**, sans fuite backend dans les entités.

Conséquence pratique : la migration lex est **surtout un remplacement d'implémentation**, pas une
refonte de modèle. Les entités canoniques `Z*` de zcrud sont, pour l'essentiel, tes propres
entités remontées d'un cran.

### État mesuré de lex_douane (2026-07-20) — à re-vérifier, pas à croire

- **2 793 fichiers Dart / ~174 k lignes** : `lex_core` 611, `lex_data` 350, `lex_ui` 882,
  `lex_localizations` 26, `apps/lex_douane` 108, `apps/lex_douane_admin` 796.
- **Aucun moteur CRUD déclaratif n'existe dans lex** (aucun `DynamicEdition`, `EditionFieldType`,
  `FieldSpec`). Ces noms n'apparaissent que dans l'artefact d'exploration **IFFD**
  (`_bmad-output/planning-artifacts/exploration-iffd-2026-07-05.md`), pas dans le code lex.
  ⇒ **`DynamicEdition` est un ajout net, pas un remplacement** : risque de régression faible,
  mais aussi **aucun code existant à supprimer** — la valeur vient des écrans que tu réécris.
- **Entités `education/` déjà canoniques** (~29 fichiers dans
  `lex_core/lib/domain/entities/education/`) : `flashcard`, `mindmap`, `smart_note`,
  `study_document`, `study_folder`, `study_session(_config)`, `exam`, `repetition_info`,
  `document_annotation`, `document_reading_state`, `folder_contents_order`, `share_link`,
  `public_study_folder`, `study_membership`, `study_podcast`… — **ce sont les originaux dont les
  `Z*` de zcrud sont dérivés**.
- **Repositories** : ports dans `lex_core/lib/domain/repositories/**`, adapters Firestore dans
  `lex_data/lib/data/repositories/**` — tous en `Either<Failure, T>` (dartz). Sync :
  `lex_data/lib/data/services/study_sync_manager.dart`.
- **UI d'étude** : `lex_ui/lib/presentation/screens/study_screen.dart`,
  `study_document_viewer_screen.dart`, `widgets/study/exam_editor_sheet.dart`,
  `providers/study_folders_provider.dart`.
- **Corpus BMAD existant** : `_bmad-output/implementation-artifacts/stories-vue-simplifiee-education/`
  (épics 1→17). **Aucun artefact « zcrud » n'existe encore côté lex** — tu pars d'une page blanche
  sur ce sujet.
- **l10n** : 7 locales (fr template, en, es, pt, ar, it, de) dans `lex_localizations`, gate
  `melos run l10n-check`.
- **Rich text** : lex n'utilise **pas** Quill mais `flutter_markdown_plus`,
  `flutter_markdown_latex`, `gpt_markdown`, `flutter_math_fork`, `flutter_tex`. Tirer
  `zcrud_markdown` introduirait **une seconde pile de rendu riche** — à trancher, pas à subir.

Lectures obligatoires avant de planifier (dans zcrud, lecture seule) :

- `zcrud/docs/study-integration-inventory.md` — inventaire d'intégration + décisions verrouillées.
- `zcrud/docs/parity-study-ui-2026-07-16/rapport.md` (+ `annexes/`) — **matrice de parité
  flashcards & mindmaps** IFFD ∥ lex_douane → zcrud. **Section décisive** : elle nomme les
  vraies pertes fonctionnelles.
- `zcrud/docs/canonical-schema.md` — schéma canonique.
- `zcrud/_bmad-output/implementation-artifacts/stories/es-10-1-*.md` et `es-10-2-*.md` — la
  surface exacte que tu vas consommer et la **dette de portage `DW-ES102-1`** (= ta feuille de
  route de câblage).

---

## 3. Ce qui est LIVRÉ zcrud-side vs ce qui est TON travail

### Livré (à consommer tel quel, ne rien réécrire)

**Binding `zcrud_riverpod`** — volontairement **GÉNÉRIQUE** (décision d'architecture 2026-07-16,
Option B) : il dépend **uniquement** de `zcrud_core` + `zcrud_study_kernel`, **jamais** d'un
package d'entité ni de `zcrud_firestore`. Il expose :

- `ZRiverpodResolver` — seam de résolution via `ProviderContainer`.
- `ZcrudRiverpodScope` — scope de binding (+ `ProviderScope`).
- `zFormControllerProvider` — provider auto-dispose du `ZFormController`.
- `zStudyRepositoryProvider<T>()` — **seam générique** : `Provider` qui **throw un `ZScopeError`
  actionnable nommant le `Type`** tant qu'il n'est pas surchargé. C'est **ton point d'injection**.
- `zStudyWatchAllProvider<T>({required repo})` → `AutoDisposeStreamProvider<List<T>>` — fabrique
  générique émettant la `Stream<List<T>>` **nue** du port (aucune transformation).
- `ZSessionConfigKey` + `zStudySessionSelectorProvider` — family clée par config, **égalité
  profonde portée par le binding** (AD-24). Réutiliser tel quel, ne pas redéclarer.

**Adapter Firestore folder-scopé** (`zcrud_firestore`) :
`buildFolderScopedStudyRepository<T extends ZEntity>({ firestore, local, kind, collection,
parentCollection, decode, encode, userId, folderId, userScoped = true, … })` →
retourne un **`ZStudyRepository<T>` (port neutre)**, composant `ZOfflineFirstBoxRepository<T>` +
une règle `ZFirestorePathRule.nestedUnderParent`. Chemin résolu :
`users/{uid}/{parentCollection}/{folderId}/{collection}` — **exactement la topologie imbriquée
lex**. Un `folderId` vide remonte un `Left(DomainFailure)` explicite, jamais un chemin tronqué.

**Formulaires** : `DynamicEdition` + `ZFieldSpec` + **46 `EditionFieldType`** couverts (parité
DODLP totale, itération FP-1..5), dispatch par `ZWidgetRegistry` (`tryBuilderFor(field.type.name)`),
repli `ZUnsupportedFieldWidget`. Un **showcase exhaustif** vit dans `zcrud/example/` : c'est ta
**documentation exécutable** — lis-le avant d'écrire le moindre formulaire.

### TON travail (dette `DW-ES102-1`, explicitement déférée à cette session)

1. **Enregistrement au seam** dans le composition-root lex : surcharger
   `zStudyRepositoryProvider<ZStudyDocument>` (etc.) par un `Provider` construisant
   `buildFolderScopedStudyRepository<ZStudyDocument>(collection: 'study_documents',
   parentCollection: 'study_folders', userId: uid, folderId: …)`.
2. **Providers typés app-side** — one-liners : `final zStudyDocumentsProvider =
   zStudyWatchAllProvider<ZStudyDocument>(repo: zStudyDocumentRepositoryProvider);`
   (le binding ne les exporte volontairement pas).
3. **Cutover repo par repo, jamais big-bang** : remplacer `smart_notes_repository`,
   `study_documents_repository`, `study_folders_repository`, `exams_repository`,
   `flashcards_repository` **un par un**.
4. **Migration des écrans** (ex-epic E8, `deferred-app-side`) : formulaires riches
   `lex_douane_admin` + écrans d'étude de `lex_douane`, avec **non-régression prouvée**.

---

## 4. ⚠️ Pré-vol — points bloquants à traiter AVANT toute ligne de code

Une reconnaissance croisée des deux dépôts a déjà été faite. **Vérifie chaque point toi-même sur
disque** — ne me crois pas sur parole, ces mesures datent du 2026-07-20.

### 🔴 (0) CONFLIT DE RÉSOLUTION MAJEUR — Riverpod 2 vs 3

| Dépendance | lex_douane | zcrud | Verdict |
|---|---|---|---|
| `flutter_riverpod` | `^3.3.0` (**résolu 3.3.2**) + `riverpod_annotation` 4.0.3 / `riverpod_generator` 4.0.4 | **`^2.6.1`** (`zcrud_riverpod`) | 🔴 **BLOQUANT** — majeures incompatibles, `^2.6.1` refuse 3.3.2 |
| `syncfusion_flutter_*` | `^33.2.12` (**résolu 33.2.15**) | **`^34.1.31`** (`zcrud_list`, `zcrud_export`) | 🔴 **BLOQUANT** si `zcrud_list`/`zcrud_export` sont tirés (Syncfusion exige des majeures alignées entre modules) |
| `cloud_firestore` | `^6.1.1` (résolu 6.6.0) | `^6.0.0` | ✅ compatible |
| `hive` / `hive_flutter` / `dartz` | 2.2.3 / 1.1.0 / 0.10.1 | `^2.2.3` / `^1.1.0` / `^0.10.1` | ✅ compatible |
| `flutter_quill` | **absent de lex** | `^11.5.0` (`zcrud_markdown`) | ⚠️ nouvelle dépendance transitive lourde |
| `analyzer` | contraint par `freezed 3.2.6-dev.1` / `build_runner 2.15.0` ; `lex_aa7_lint` **déjà sorti du workspace** car `custom_lint 0.8.1` épingle `analyzer 8.4.0` | `^8.0.0` (`zcrud_generator`, dev) | ⚠️ à re-tester — lex a déjà un historique de blocage sur ce point |

**Le conflit Riverpod est le premier obstacle réel, et il n'a pas de contournement app-side
propre.** Trois voies, à m'exposer avec ta recommandation motivée **avant** toute autre décision :

1. **Faire monter `zcrud_riverpod` en Riverpod 3** — change-request zcrud (le binding est mince :
   `ZRiverpodResolver`, `ZcrudRiverpodScope`, `zFormControllerProvider`, seam + fabrique study).
   Probablement la bonne réponse, mais **hors de ton périmètre d'écriture**.
2. **Ne pas consommer `zcrud_riverpod` du tout** : câbler toi-même, dans `lex_ui`/`lex_data`, des
   providers `@riverpod` (v3, codegen — l'idiome lex) au-dessus des ports **purs** de
   `zcrud_core`/`zcrud_study_kernel`, qui **n'ont aucune dépendance Riverpod**. Tu perds ~200
   lignes de binding et le patron d'égalité profonde `ZSessionConfigKey`, mais tu débloques tout
   le reste immédiatement et tu restes 100 % idiomatique lex.
3. **Différer** toute consommation Riverpod et n'intégrer d'abord que les packages purs.

**Mesure la contrainte réellement** (`dart pub get --dry-run` avec la dépendance git ajoutée)
avant de conclure. Un `pubspec.lock` qui résout est la seule preuve acceptable.

### (a) Le tag `v0.2.1` est PÉRIMÉ. Le dernier tag zcrud (`v0.2.1`, 2026-07-16) est **10 commits
en retard** sur `main` : il **ne contient PAS** l'epic E-STUDY-UI, E-MULTI-EDIT, ni l'itération
form-parity (4 satellites neufs + fork vendorisé + 46 types de champs). **Un nouveau tag
(`v0.3.0`) doit être coupé côté zcrud avant l'intégration.** C'est une **action owner** — ne
l'exécute pas depuis cette session (zcrud est en lecture seule). Signale-la et attends. En
attendant, tu peux prototyper avec un `ref:` sur un **SHA de commit** (`cdb1f39`), jamais sur
`main`.

**(b) Piège de résolution `awesome_select`.** `zcrud_select` déclare `awesome_select: ^6.0.0` en
contrainte **hosted**. Dans le workspace zcrud, `resolution: workspace` fait gagner le **fork
vendorisé** (`packages/awesome_select`, `publish_to: none`). **Pour un consommateur externe en
dépendance git, cette contrainte se résout depuis pub.dev — donc sur le VRAI `awesome_select`,
pas sur le fork.** Si tu tires `zcrud_select`, tu dois soit ajouter une dépendance git explicite
sur `path: packages/awesome_select`, soit un `dependency_overrides`. **Vérifie le
`pubspec.lock` résolu** et prouve quelle source a gagné avant de conclure que ça marche.

**(c) Déclaration transitive obligatoire.** Les dépendances inter-`zcrud_*` sont des contraintes
hosted (`zcrud_core: ^0.2.1`). Tout package `zcrud_*` **transitivement requis** doit être déclaré
comme dépendance git (même `url`, même `ref`), sinon pub le cherche sur pub.dev où il n'existe
pas. Établis le graphe des paquets dont tu as besoin **avant** d'éditer le pubspec.

---

## 5. Séquencement imposé — du risque le plus faible au plus fort

Le rapport de parité tranche l'ordre. **Ne l'inverse pas.**

| Vague | Contenu | Risque | Justification |
|---|---|---|---|
| **V0** | Reconnaissance + plomberie de dépendance + composition-root, **zéro écran migré** | — | Prouver que ça résout, compile et boote |
| **V1** | **Mindmaps** | **FAIBLE** | `zcrud_mindmap` **égale ou dépasse** lex (auto-layout, outline editor qui corrige un bug historique, tree-ops plus riches). Seule absence : génération IA = app-side légitime |
| **V2** | **Entités study en lecture** (folder / document / note / exam) via les seams, **repo par repo**, ancien repo conservé derrière un flag | MOYEN | Le cutover est réversible tant que l'ancien chemin existe |
| **V3** | **Formulaires riches** `lex_douane_admin` (`DynamicEdition`) | MOYEN | Ajout net (lex n'a aucun moteur déclaratif) : pas de régression possible, mais 796 fichiers Dart d'admin — cibler **un seul** écran pilote |
| **V4** | **Écriture** (create/update/delete) via `ZStudyRepository` offline-first | ÉLEVÉ | LWW sur `updatedAt`, soft-delete `is_deleted`, cascade ≤ 450 écritures/lot — à prouver sur données réelles |
| **V5** | **Flashcards** | **ÉLEVÉ — NE PAS COMMENCER SANS DÉCISION** | voir ci-dessous |

### 🔴 Flashcards — pertes fonctionnelles CONNUES et non comblées

Le rapport de parité est catégorique : zcrud a porté **le domaine, l'édition, le SRS et le moteur
de session**, mais **PAS la couche présentation de révision**, qui vit dans **`lex_ui`** — donc
ce sont de **vraies pertes** en cas de migration à l'aveugle, pas des extras d'une autre app :

- ❌ **Carte de révision FLIP** (`SessionFlashcardView` : `AnimatedSwitcher` 250 ms, **adaptée par
  type** — QCM cliquable avec correction, vrai/faux, réponse ouverte + évaluation IA) — **ABSENT**.
- ❌ **Pile swipeable de session** (`SessionCardSwiper`, `flutter_card_swiper`, swipe neutralisé
  pour la notation) — **ABSENT**.
- ⚠️ **Écran de fin / célébration** (`SessionSummaryView` : trophée, répartition qualités,
  confetti conditionné à Reduce Motion) — **partiel** : les primitives existent
  (`ZSessionQualityBreakdown`, `ZStudyProgressRings`), **l'écran assemblé non**.
- ❌ **Liste/grille de flashcards + filtres UI** (`study_folder_screen` : tri date/titre/custom,
  filtre sous-dossier + tags composables) — **widget absent** côté zcrud.
- 🟡 **Génération IA** et **export PDF de flashcards** : ports génériques seuls
  (`ZFlashcardGenerationPort`, `ZExporter`/`ZPdfCreationService`) — **impl et gabarit app-side**.

**Décision à me remonter avant V5, avec une recommandation motivée** : (A) garder ces widgets
dans `lex_ui` et ne consommer que le domaine/moteur zcrud, ou (B) demander un epic
d'enrichissement zcrud (change-request) qui les remonte pour IFFD aussi. **Ne tranche pas seul.**

---

## 6. Phase 0 — reconnaissance obligatoire (avant toute planification)

Le § 2 te donne un **point de départ mesuré**, pas un inventaire. Produis
`docs/zcrud-integration-inventory.md` (côté lex_douane) répondant, **preuves sur disque à
l'appui** (chemin:ligne), à :

1. **Cartographie des repos « education »** : chaque repository lex, sa signature, son type de
   retour, ses appelants. Lequel est le plus isolé ⇒ **premier candidat au cutover**.
2. **Correspondance d'entités** : pour chaque entité lex `education/`, son homologue `Z*` zcrud —
   champs identiques / renommés / absents des deux côtés. **Tout écart est un risque de perte de
   données** : liste-les explicitement.
3. **Topologie Firestore réelle** : les chemins de collection utilisés aujourd'hui
   correspondent-ils bien à `users/{uid}/{parent}/{parentId}/{collection}` attendu par
   `buildFolderScopedStudyRepository` ? **Toute divergence est bloquante** — remonte-la.
4. **Composition-root actuel** : où vivent le `ProviderScope`, la DI, l'init Firebase/Hive ?
5. **Compatibilité de résolution** : versions lex vs zcrud de `flutter_riverpod`, `cloud_firestore`,
   `flutter_quill`, `syncfusion_*`, `dartz`, `hive`, `analyzer`. **Tout conflit de contrainte est
   bloquant** — `dart pub get --dry-run` fait foi, pas ton estimation.
6. **Écrans consommateurs** : quels écrans lex touchent chaque repo (= surface de non-régression).
7. **Couverture de test existante** : qu'est-ce qui te protège aujourd'hui d'une régression ?
   Là où il n'y a rien, **il faudra écrire le test AVANT de migrer**.

---

## 7. Processus — BMAD strict

lex_douane est déjà piloté en BMAD (`_bmad/`, `_bmad-output/`). Applique le **cycle strict**,
sans sauter d'étape :

```
bmad-create-story → bmad-dev-story → vérif verte → bmad-code-review → fix findings → done
backlog → ready-for-dev → in-progress → review → done      (aucun saut)
```

- Avant les stories : `bmad-product-brief` (léger) → `bmad-create-epics-and-stories` →
  `bmad-sprint-planning` sur le périmètre de migration. **Étends** le `sprint-status.yaml`
  existant par **édition ciblée** — jamais de réécriture globale, jamais de perte d'historique.
- **Effort** : `create-story` medium (high si complexe), `dev-story` high, `code-review` high,
  `retrospective` medium. Modèle **hérité** (paramètre `model` omis) sur les étapes BMAD ;
  `sonnet` réservé à l'exploration read-only.
- **`code-review` = Workflow MULTI-AGENT à lentilles** — tu dimensionnes seul, sans demander.
  Lentilles pertinentes ici : *non-régression fonctionnelle*, *parité de données* (aucun champ
  perdu au round-trip), *conformité AD*, *tests porteurs* (un test qui ne rougit pas quand la
  logique casse est un test mort), *SM-1/perf*, *réalité du code* (**toute affirmation d'absence
  doit être prouvée par un grep négatif**).
- **Un seul commit en fin d'epic.** Exclure les `pubspec.lock` du commit **sauf** quand le lock
  **est** le livrable (épinglage de la dépendance git — dans ce cas, commit-le délibérément et
  dis-le).

**Vérif verte, rejouée TOI-MÊME sur disque avant tout `done`** (jamais sur la foi d'un rapport
d'agent) :

```bash
dart pub get                       # doit résoudre sans conflit
dart run melos run generate        # si des modèles annotés sont touchés
dart run melos run analyze         # RC=0 REPO-WIDE, pas seulement le package touché
dart run melos run test            # RC=0
dart run melos run l10n-check      # gate « 0 untranslated », 7 locales
```

⚠️ Une vérif **ciblée sur un package ne détecte pas** une régression cross-package (symbole
public supprimé ailleurs). À chaque gate de commit d'epic : **analyze + test REPO-WIDE**.

---

## 8. Tensions connues entre les conventions lex et celles de zcrud

Ces frictions sont **structurelles, pas accidentelles**. Tranche-les explicitement, une fois,
et documente la règle retenue — ne les rejoue pas à chaque story.

1. **`ConsumerWidget` obligatoire (lex) vs widgets Flutter-natifs (zcrud).** Le `CLAUDE.md` de lex
   interdit tout `StatelessWidget`/`StatefulWidget` nu. Les widgets zcrud sont **délibérément**
   pur-Flutter (`ChangeNotifier`/`ValueListenable`, AD-2/AD-15) et ne connaissent aucun
   gestionnaire d'état. **Règle proposée** : la contrainte lex s'applique aux widgets **écrits
   dans lex** ; les widgets **consommés** depuis un package zcrud en sont exemptés, et le pont se
   fait dans un `ConsumerWidget` lex qui les enveloppe. À valider avec moi et à inscrire dans le
   `CLAUDE.md` de lex.
2. **`@riverpod` + codegen obligatoire (lex) vs providers manuels (zcrud_riverpod).** Même
   raisonnement : les providers que **tu** écris sont en codegen ; ceux fournis par un package
   tiers ne le sont pas. Cela **renforce** l'option 2 du § 4.0.
3. **Clean Architecture 3 couches stricte (lex)** : `presentation` ne doit jamais importer `data`.
   Les entités `Z*` viennent de packages **externes** — décide une fois pour toutes de quelle
   couche lex elles relèvent (recommandation : `domain`, avec les adapters zcrud confinés à
   `lex_data`) et respecte-le.
4. **Deux piles de rendu riche** (markdown lex vs Quill zcrud) : ne tire `zcrud_markdown` que si
   un besoin réel le justifie, et alors documente laquelle fait autorité pour quel contenu.

---

## 9. Règles de migration — non négociables

- ✅ **Strangler fig, jamais big-bang.** Chaque repo migré garde son ancien chemin accessible
  jusqu'à ce que la non-régression soit prouvée. Une story = un repo ou un écran.
- ✅ **Aucune perte de donnée silencieuse.** Tout champ lex sans homologue zcrud est soit mappé
  vers `extra: Map<String,dynamic>` / le slot `ZExtension` versionné, soit **explicitement
  documenté comme abandonné, avec mon accord**.
- ✅ **Test de round-trip** sur chaque entité migrée : `entité lex → Z* → Firestore → Z* →
  entité lex` sans perte. C'est le filet principal.
- ✅ **Injection au seam, jamais d'import concret** : le binding ne doit jamais importer
  `zcrud_firestore` ; c'est toi qui injectes l'adapter dans le `ProviderScope`.
- ✅ **`Semantics` + ≥ 48 dp + variantes directionnelles** sur tout widget touché (AD-13).
- ✅ **Aucune couleur ni libellé en dur** — thème via `ZcrudScope`/`ThemeExtension`, textes via la
  l10n lex (7 locales, gate `l10n-check`).
- 🚫 **Jamais** `git checkout` / `git restore` / `git stash` sur du travail non committé
  (destructif — incident avéré).
- 🚫 **Jamais** `dart format` en masse (le repo n'est pas en style formaté par défaut).
- 🚫 **Jamais** modifier un fichier de `zcrud/`, `iffd/`, `dodlp-otr/`, `dlcfti-otr/`.
- 🚫 **Jamais** valider une étape sur la foi du rapport d'un sous-agent : **relis le disque**.

---

## 10. Livrables attendus de cette première session

1. `docs/zcrud-integration-inventory.md` — la reconnaissance de la Phase 0, avec les **écarts et
   points bloquants** en tête de document.
2. Une **note de décision** sur les points de pré-vol (§ 4), en tête desquels **le conflit
   Riverpod 2 vs 3** avec ta recommandation motivée entre les 3 voies — puis le tag périmé, la
   résolution `awesome_select`, les majeures Syncfusion, le graphe transitif à déclarer.
3. Un **plan de migration séquencé** (epics + stories BMAD), respectant l'ordre V0→V5 du § 5, avec
   pour chaque story : périmètre, critère de non-régression, et **critère de rollback**.
4. `docs/zcrud-change-requests.md` — initialisé, même vide.
5. La **question flashcards** (§ 5) posée avec ta recommandation motivée.

**Ne commence AUCUNE implémentation avant que j'aie validé le plan.** Commence par la Phase 0 et
présente-moi les résultats.

---

## 11. Communication

**Français**, avec toute l'orthographe correcte (accents et diacritiques inclus). Termes
techniques et identifiants de code inchangés. Après **chaque** étape BMAD, un **résumé concis
non sollicité** : étape + skill réel invoqué, ce qui a été produit, **résultats de vérification
réellement rejoués sur disque**, findings de code-review avec leur statut, transition de statut
appliquée.
