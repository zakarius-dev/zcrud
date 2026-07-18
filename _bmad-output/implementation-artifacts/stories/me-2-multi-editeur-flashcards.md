# Story 2.2: Multi-éditeur de flashcards (`ZMultiFlashcardEditor`)

Status: review

Story key: `me-2-multi-editeur-flashcards` · Epic: **E-MULTI-EDIT** (Epic 2) · Taille: **XL** ·
Séquençage: **SÉQ — après me-1 ; dépend su-2 + su-9** · Couvre **FR-SU20**.

<!-- Mode NON-INTERACTIF : option conservatrice retenue et consignée à chaque arbitrage (§ Écarts tranchés). -->

## Story

As an utilisateur,
I want éditer un lot de flashcards (souvent issues de l'IA) avant de les enregistrer,
So that je relis et corrige tout d'un coup, sans rien persister par accident.

## Contexte d'implémentation (à lire AVANT de coder)

### Où vit `ZMultiFlashcardEditor` — placement PROUVÉ acyclique

**Package d'accueil = `zcrud_study`** (fichier `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart`,
export via le barrel `packages/zcrud_study/lib/zcrud_study.dart`).

`zcrud_study` est le **seul** package qui possède déjà **toutes** les dépendances entrantes de me-2 :

| Capacité consommée | Vit dans | `zcrud_study` en dépend déjà ? |
|---|---|---|
| me-1 : `ZListSelectionController`, `ZBatchAction`, `ZBatchActionBar`, `batchApply`/`batchDelete`/`batchMove`/`applyCommonField`, `ZBatchReport`/`ZBatchDeletionReport` | `zcrud_core` (`lib/src/presentation/list/`) | ✅ `zcrud_core: ^0.2.1` |
| su-2 : `ZFlashcardReviewCard` (aperçu) | `zcrud_flashcard` | ✅ `zcrud_flashcard: ^0.2.1` |
| su-9 : `ZFlashcardGenerationController` / `ZFlashcardGenerationPort` / sheet | `zcrud_study` (`lib/src/presentation/`) | ✅ **même package** |
| Split-view responsive : `ZResponsiveLayout`, `ZAdaptiveGrid` | `zcrud_responsive` | ✅ `zcrud_responsive: ^0.2.1` |
| `ZDiscardChangesGuard` | `zcrud_ui_kit` | ❌ **arête à AJOUTER** |

**Seule arête nouvelle : `zcrud_study → zcrud_ui_kit`.** Elle est **acyclique** (grep prouvé) : la
**seule** arête sortante de `zcrud_ui_kit` est `zcrud_core` (aucune arête `zcrud_ui_kit → zcrud_study`
ni `→ zcrud_flashcard`). `zcrud_ui_kit` n'apporte **aucune dépendance tierce** (seulement `zcrud_core`
+ SDK Flutter). Ajouter `zcrud_ui_kit: ^0.2.1` aux `dependencies` de `packages/zcrud_study/pubspec.yaml`
(patron identique à l'arête `zcrud_responsive` ajoutée par su-8, cf. commentaire du pubspec).

> ⚠️ **NE PAS** ajouter d'arête vers `zcrud_list` : les primitives me-1 consommées par me-2
> (`ZListSelectionController`, `batchApply`, `applyCommonField`, `ZBatchActionBar`) vivent dans
> **`zcrud_core`**, pas dans `zcrud_list`. Vérifié : `class ZListSelectionController` →
> `packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart`.

### Le widget « naît gardé » — étendre, jamais dupliquer

`zcrud_study` possède déjà des gardes qui **scannent récursivement `lib/src/presentation/**`** — donc
`z_multi_flashcard_editor.dart` est **automatiquement couvert dès sa création**, sans nouveau test de garde :

- `packages/zcrud_study/test/presentation/z_widgets_purity_test.dart` — **scan récursif** ⇒ interdit tout
  import de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`) et tout appel SRS direct.
  Commentaire du test : « *N'énumère JAMAIS une liste figée : scan récursif ⇒ tout futur widget est
  capté sans édition du test* ». **Ne crée AUCUNE garde de pureté parallèle.**
- `packages/zcrud_study/test/presentation/z_flashcard_contrast_test.dart` — contraste WCAG.
- `z_exam_editor_a11y_test.dart` — patron d'énumération a11y (teste le **canal `Semantics`**, pas le rendu).

Si une garde existante requiert une **entrée** pour capter le nouveau widget (ex. liste de racines à
scanner), **étends** cette entrée — ne réécris pas la garde.

### Contrat RÉEL de `ZDiscardChangesGuard` (vérifié sur disque)

`packages/zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart` — **`StatelessWidget` pur** :

```dart
const ZDiscardChangesGuard({
  required ValueListenable<bool> isDirty,   // consommé EN LECTURE SEULE
  required Widget child,                     // NON reconstruit au flip dirty (SM-1)
  String? title, String? message, String? confirmLabel, String? cancelLabel,
  VoidCallback? onDiscard,                   // appelé JUSTE avant le pop (discard confirmé)
});
```

- Enveloppe un `PopScope` : **propre** (`isDirty.value == false`) → `canPop == true`, pop direct,
  **aucun** dialog, `onDiscard` **non** appelé ; **sale** (`true`) → `canPop == false`, sortie bloquée
  puis `showZConfirmDialog(tone: destructive)` ; confirmer → `onDiscard` puis `Navigator.pop` ;
  annuler / barrier → on **reste** (`?? false`, jamais de throw — AD-10).
- SM-1 déjà respecté : `child` passé au `child` du `ValueListenableBuilder` (jamais reconstruit).

⇒ **me-2 fournit un `ValueListenable<bool> isDirty`** (le brouillon est *dirty* dès qu'il diverge du
snapshot initial) et enveloppe la surface d'édition dans `ZDiscardChangesGuard`. **Aucune garde
réécrite** (l'AC de l'epic l'impose : « *jamais une garde réécrite* »).

### Le flag me-1 à CONSOMMER (pas à redéclarer)

`ZListSelectionController.applyCommonField(...)` expose **`clearSucceededFromSelection` — défaut `false`**
(vérifié, `z_list_selection.dart:253`). Dartdoc réel : « *l'édition d'un champ commun est une écriture
in-place, les éléments RESTENT visibles ⇒ la sélection est conservée (…) ex. multi-éditeur me-2, sans
tout re-sélectionner)* ». **me-2 consomme ce défaut** (édition in-place qui garde la sélection) — il **ne
le redéclare pas** et ne réimplémente aucune validation (les validateurs sont dérivés du `ZFieldSpec` via
`ZValidatorCompiler.compile`, AD-44). La sélection a **un seul propriétaire** : le `ZListSelectionController`
détenu par la liste du multi-éditeur, **passé** à `ZBatchActionBar` (jamais redéclaré par un widget d'action).

### Le flux de génération su-9 à INTÉGRER

`ZFlashcardGenerationController` (`zcrud_study`) expose `onGenerated: ZFlashcardGeneratedCallback` =
`void Function(List<ZFlashcard> cards, List<ZFlashcardTag> confirmedTags)`. Les cartes produites sont
**éphémères** (`id == null`, aucune source backend — AD-37). me-2 **branche `onGenerated`** pour
**ajouter** ces cartes à la liste de travail EN MÉMOIRE — **jamais persistées** avant le commit unique.
`ZFlashcard.id` est `String?` (nullable) et `ZFlashcard.copyWith(...)` existe (édition in-memory).

### `ZFlashcard` — édition in-memory

`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` : `final String? id;` + `ZFlashcard copyWith({...})`.
L'édition d'un champ dans le brouillon produit un `copyWith` **conservé en mémoire** dans la liste de
travail — **jamais** un `copyWith` remis à un store.

## Acceptance Criteria

**AC1 — Split-view responsive (réutilise l'infra existante).**
Given un lot de flashcards, When `ZMultiFlashcardEditor` s'affiche, Then il est en **split-view** sur grand
écran (sidebar liste à gauche + formulaire à droite) et en **navigation liste ↔ formulaire** sur mobile,
via `zcrud_responsive` (`ZResponsiveLayout`/`ZAdaptiveGrid`) — **aucune** ré-implémentation de breakpoint.
RTL: variantes directionnelles uniquement (AD-13). *Test porteur*: pump à largeur ≥ seuil ⇒ liste ET
formulaire présents simultanément ; pump < seuil ⇒ un seul volet visible + navigation. *Injection R3*:
forcer un seul volet à grande largeur ⇒ rouge.

**AC2 — Régime BROUILLON DÉCLARÉ (AD-43) : liste de travail en mémoire, RIEN persisté. [POINT CENTRAL]**
Given le régime brouillon, When l'utilisateur édite / ajoute / supprime / applique une action groupée,
Then **tout mute une liste de travail EN MÉMOIRE** et **rien n'est persisté** ; la surface **déclare** son
régime (propriété/enum publique, ex. `ZEditingMode.draft` — **jamais implicite**) ; **aucune cascade AD-39**
n'est déclenchée sur une carte jamais persistée. *Preuve à 3 étages* (cf. § Stratégie de preuve AD-43).

**AC3 — Sortie avec brouillon non committé ⇒ `ZDiscardChangesGuard` EXISTANT.**
Given des modifications non enregistrées, When l'utilisateur quitte, Then le garde-fou **`ZDiscardChangesGuard`
existant** (zcrud_ui_kit) intervient — **jamais** une garde réécrite. me-2 alimente son `isDirty`
(`ValueListenable<bool>`) : *dirty* ssi la liste de travail diverge du snapshot initial. *Test porteur*:
brouillon *dirty* ⇒ tentative de pop bloquée + dialog ; brouillon *propre* ⇒ pop direct sans dialog.
*Injection R3*: câbler `isDirty` sur une constante `false` ⇒ le test « quitter avec modifs → dialog » rougit.

**AC4 — Commit explicite UNIQUE = seul franchissement de la frontière de persistance.**
Given la sauvegarde finale groupée, When l'utilisateur la déclenche, Then c'est le **seul** franchissement
de la frontière (AD-43) et la **liste complète** est remise à l'appelant (callback `onCommit(List<ZFlashcard>)`
injecté — me-2 **ne persiste pas lui-même**, il **remet**). *Test porteur*: espion prouvé captant AVANT
(cf. AD-43) ⇒ un commit = **une seule** invocation de handoff portant l'intégralité de la liste ; zéro
handoff avant le commit.

**AC5 — Flux de génération IA (su-9) : résultats AJOUTÉS à la liste de travail, jamais persistés.**
Given le flux de génération IA (story 1.9 / su-9), When un lot est généré, Then les cartes éphémères
(`id == null`, AD-37) sont **ajoutées à la liste de travail** pour revue via le `onGenerated` de
`ZFlashcardGenerationController` — **jamais persistées**. *Test porteur*: espion persistance à 0 après
génération ; la liste de travail grandit du nombre de cartes générées.

**AC6 — Aperçu via `ZFlashcardReviewCard` (su-2), JAMAIS un rendu parallèle.**
Given l'aperçu d'une carte, When l'utilisateur le demande, Then il réutilise **`ZFlashcardReviewCard`**
(zcrud_flashcard, su-2) — **jamais** un rendu parallèle du contenu de carte. *Test porteur*: le panneau
d'aperçu construit bien un `ZFlashcardReviewCard` (`find.byType`). *Garde de réalité*: `grep -qF` prouvant
qu'aucun rendu markdown/Text de contenu de carte n'est réimplémenté dans le chemin d'aperçu.

**AC7 — Panneau « appliquer à la sélection » (tags / dossier / type) s'appuie sur me-1, sans le dupliquer.**
Given le panneau d'action groupée, When il s'exécute, Then il s'appuie sur la capacité me-1 :
`applyCommonField` (validateurs **dérivés du `ZFieldSpec`**, AD-44) avec **`clearSucceededFromSelection`
au défaut `false`** (sélection conservée pour enchaîner un 2ᵉ champ), la sélection provenant d'un
**`ZListSelectionController` unique** détenu par la liste et passé à `ZBatchActionBar`. **Aucune 2ᵉ
implémentation** de validation/sélection. *Note brouillon*: dans le régime draft, le seam `writeRoot`
injecté à `applyCommonField` **écrit la liste EN MÉMOIRE** (`copyWith`), pas un store — le rapport
`ZBatchReport` reste au grain de la racine (AD-10). *Injection R3*: brancher un second contrôleur de
sélection ⇒ garde « propriétaire unique » rougit.

**AC8 — Ajout / suppression groupée DANS le brouillon (aucune cascade, aucune persistance).**
Given l'ajout d'une carte vierge ou une suppression groupée dans le brouillon, When elle s'exécute, Then
elle mute **uniquement** la liste de travail (retrait d'entrée), **sans** cascade AD-39 (les cartes du
brouillon n'ont pas d'`id` persisté) et **sans** aucune écriture. La suppression d'une carte **déjà
persistée** (rentrée dans le lot pour édition) n'entraîne, elle non plus, **aucune** persistance avant le
commit (le retrait est enregistré et matérialisé par l'appelant au commit). *Test porteur*: espion
persistance inchangé après add + delete groupé + n'importe quelle action.

**AC9 — Robustesse AD-10 (états dégénérés + échecs).**
Then résultat **défini** (jamais de throw traversant la surface) pour : liste de travail **vide** ·
**1** carte · **N** cartes · **génération qui échoue** (su-9 : `Left`/throw/`Right([])` ⇒ message, liste de
travail intacte) · **suppression de lot partielle** (rapport me-1 par racine) · **commit qui échoue**
(le handoff appelant échoue ⇒ on **reste** dans le brouillon *dirty*, rapport à l'utilisateur, **aucune
perte** de la liste de travail — pas de vidage optimiste) · **abandon en cours de génération** (le brouillon
existant est préservé ; la génération en vol est ignorée à son retour — jeton de fraîcheur su-9).

**AC10 — SM-1 : granularité de rebuild.**
Given un brouillon potentiellement volumineux, When l'utilisateur édite un champ d'une carte, Then **seul
ce champ** (sa tranche `ValueListenable`) est reconstruit — **jamais** toute la liste ni tout le formulaire.
Le statut interne est porté par **enum(s), pas des booléens** dès qu'un état a plus de 2 issues.
*Test porteur*: compteur de builds — taper dans un champ n'incrémente que le build de ce champ. *Injection
R3*: remplacer la tranche par un `setState` de formulaire ⇒ le compteur explose, rouge.

## Stratégie de preuve AD-43 — brouillon, RIEN persisté (LE point dur)

> **Leçon su-9 / su-4 / su-7 / me-1 (même invariant) : une assertion « 0 écriture » est INFALSIFIABLE si
> l'espion n'est jamais prouvé capable de capter.** Reproduire à l'identique le défaut = échec de revue.

**Étage (a) — structurel.** La vue n'importe **aucun** store/repository/adaptateur de persistance
(`ZRepository`, `zcrud_firestore`, `ZLocalStore`, `ZRemoteStore`, seam d'écriture kernel). Prouvé par la
**garde de pureté récursive existante** (`z_widgets_purity_test.dart`) **+** un grep négatif dédié dans la
story (commande + RC) sur `z_multi_flashcard_editor.dart`. La persistance n'entre QUE par les callbacks
injectés (`onCommit`, seam `writeRoot` in-memory) — jamais par un import direct.

**Étage (b) — comportemental, espion PROUVÉ captant AVANT l'assertion à 0.**
1. L'espion (fake `onCommit`/repository) enregistre d'abord une **écriture témoin** ⇒ le test **assert que
   `writes == 1`** (preuve que l'espion capte réellement — sinon l'étape (c) serait infalsifiable).
2. Puis, sur une instance neuve : **éditer → ajouter → supprimer (groupé) → générer (su-9) → abandonner**
   (discard) ⇒ **`writes` inchangé** (0). L'abandon ne persiste rien.

**Étage (c) — commit unique = UNE seule salve.** Un `onCommit` déclenché ⇒ **exactement une** invocation
de handoff portant l'**intégralité** de la liste (aucune écriture par-carte au fil de l'eau).

**Chasse aux voies de fuite (leçon su-8 : le HIGH passait par une voie NON anticipée).** Prouver
l'**absence** (grep négatif, commande + RC) de chaque échappatoire :
- pas de `copyWith(...)` remis à un store au fil de l'édition ;
- pas d'`onDuplicate`/« dupliquer » qui persiste (AD-45 : la copie est **éphémère**, `id == null`,
  `isReadOnly` remis à faux, **aucun** état personnel copié, rejoint le régime draft) ;
- pas d'auto-sauvegarde implicite (timer, `didChangeDependencies`, `dispose` qui flush) ;
- pas de cascade AD-39 déclenchée sur une carte du brouillon (la suppression draft ne touche aucun seam
  de suppression persistée).

## Tasks / Subtasks

- [x] **T1 — Arête de graphe + squelette du widget** (AC1)
  - [x] Ajouter `zcrud_ui_kit: ^0.2.1` aux `dependencies` de `packages/zcrud_study/pubspec.yaml` (commentaire justifiant l'arête acyclique, patron su-8/`zcrud_responsive`) ; `dart pub get`. **Graph proof : ACYCLIQUE OK, CORE OUT=0 OK, 57 arêtes.**
  - [x] Créer `lib/src/presentation/z_multi_flashcard_editor.dart` + export dans `lib/zcrud_study.dart`.
  - [x] Split-view via `zcrud_responsive` (`ZResponsiveLayout` compact=navigation / medium+expanded=split) ; directionnel (AD-13).
- [x] **T2 — Contrôleur de brouillon EN MÉMOIRE, régime DÉCLARÉ** (AC2, AC10)
  - [x] `ChangeNotifier` pur-Flutter (`ZMultiFlashcardDraftController`) détenant la liste de travail (AD-2/AD-15) ; **zéro** import store/manager d'état.
  - [x] Régime **déclaré** en enum public (`ZEditingMode.draft`) ; tranches `orderKeys` (structurelle) / `isDirty` disjointes (SM-1) ; identité de travail LOCALE (jamais l'`id`).
  - [x] `ValueListenable<bool> isDirty` = divergence vs snapshot initial (revert exact ⇒ re-propre).
- [x] **T3 — Sélection + actions de lot (me-1 consommé)** (AC7, AC8)
  - [x] `ZListSelectionController` unique détenu par la surface, passé à `ZBatchActionBar` (jamais redéclaré).
  - [x] Panneau « appliquer à la sélection » → `applyCommonField` (seam `writeRoot` **in-memory** `writeRootInMemory`, `clearSucceededFromSelection` au défaut `false` **consommé, non redéclaré**) ; validateurs du `ZFieldSpec` (AD-44).
  - [x] Ajout carte vierge (`id == null`) ; suppression groupée = `removeKeys` in-memory (aucune cascade AD-39).
- [x] **T4 — Aperçu via `ZFlashcardReviewCard`** (AC6)
  - [x] Panneau d'aperçu = `ZFlashcardReviewCard` (su-2) ; **aucun** rendu parallèle (grep négatif : `ZMarkdownReader`/`MarkdownToDelta`/`QuillEditor` absents).
- [x] **T5 — Intégration du flux de génération su-9** (AC5, AC9-génération)
  - [x] Brancher `ZFlashcardGenerationSheet.onGenerated` → `addGenerated` des cartes éphémères à la liste de travail (launcher ABSENT sans port).
  - [x] Échec de génération (`Right([])`) ⇒ message, liste de travail intacte ; jeton de fraîcheur/abandon possédés par su-9.
- [x] **T6 — `ZDiscardChangesGuard` + commit unique** (AC3, AC4, AC9-commit)
  - [x] Envelopper la surface dans `ZDiscardChangesGuard` **existant** ; alimenter `isDirty` (`onDiscard` = `discardToSnapshot`).
  - [x] `onCommit` (`Future<ZResult<Unit>>`) injecté = **seul** franchissement ; échec de commit ⇒ on reste *dirty*, message, aucune perte (pas de vidage optimiste).
- [x] **T7 — Tests porteurs + preuve AD-43 (3 étages) + greps négatifs** (tous ACs)
  - [x] Espion **prouvé captant AVANT** (writes==1 témoin) puis édit→add→delete→gen→abandon ⇒ writes inchangé ; commit ⇒ 1 salve portant toute la liste (controller_test + widget_test).
  - [x] Grep négatif dédié (commande + RC) fermant chaque voie de fuite (store/persist/scheduler/`Timer(`/`didChangeDependencies`/cascade draft) — encodé aussi en garde vm (`ad43_structure_test`).
  - [x] Garde de pureté récursive existante (`z_widgets_purity_test.dart`) capte les 2 nouveaux fichiers (verte dans la suite ; aucune garde parallèle).
  - [x] a11y : canal `Semantics` (libellé injecté atteignable + annoncé UNE fois) ; cibles ≥ 48 dp sur TOUS les contrôles ; libellés l10n injectés (0 littéral, hardcode-scan vert).
  - [x] SM-1 : compteur de builds — taper dans la question ⇒ 0 rebuild de ligne + controller stable ; ajouter ⇒ rebuild (sonde vivante).
- [x] **T8 — Vérif verte** : `flutter test` (`zcrud_study` = **451 tests, RC=0**) → `flutter analyze` **RC=0** → `graph_proof` OK. Codegen sans objet (aucun `@ZcrudModel` ajouté). `zcrud_core`/`zcrud_flashcard` NON touchés (consommés seulement).

## Dev Notes

- **AD-2/AD-15** : contrôleur `ChangeNotifier`/`ValueListenable` pur-Flutter ; **jamais** de gestionnaire
  d'état importé ; **jamais** `setState` à l'échelle du formulaire ; `ValueKey(field.name)` ; validateurs
  mémoïsés ; `TextEditingController` stable (create/dispose), jamais recréé au rebuild.
- **AD-43** : régime **déclaré**, liste de travail **en mémoire**, **commit unique** seul franchissement.
- **AD-39** : aucune cascade sur une carte jamais persistée (les suppressions du brouillon ne cascadent pas).
- **AD-44** : sélection à **propriétaire unique** ; actions **déclarées en données** ; champ commun
  **dérivé du `ZFieldSpec`** (mêmes validateurs que le formulaire unitaire).
- **AD-45** : « dupliquer pour modifier » ⇒ entité **éphémère** (`id == null`, `isReadOnly=false`, aucun
  état personnel copié), rejoint le régime draft — l'original n'est jamais muté.
- **AD-10** : chaque état dégénéré/échec a un résultat **défini** ; jamais de `throw` traversant la surface.
- **AD-13** : directionnel (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`),
  `Semantics` explicites, cibles ≥ 48 dp, `ListView.builder`.
- **SM-1** (objectif produit n°1) : rebuild granulaire ; **enums > booléens**.
- **Distribution en dép. git** : après un `copyWith`/annotation touchant du codegen, régénérer et
  **committer les `*.g.dart`** de `packages/*/lib/` (mais **aucun commit** dans cette story — commit en fin d'epic).

### Frontières (hors périmètre me-2)

- **PAS** de branchement de la sélection dans la **liste flashcard existante** (`ZFlashcardListView`) ⇒ **me-3**.
- **PAS** de nouvelle capacité moteur (sélection/actions de lot) ⇒ déjà livrée par **me-1**, à consommer.
- **PAS** d'implémentation IA réelle du port de génération ⇒ **app-side** (le port su-9 est advisory/injecté).

### Project Structure Notes

- Nouveau fichier : `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart` (+ contrôleur
  de brouillon éventuel `z_multi_flashcard_editor_controller.dart` même dossier).
- Export via `packages/zcrud_study/lib/zcrud_study.dart` (barrel — API publique).
- Tests sous `packages/zcrud_study/test/` (et/ou `test/presentation/`) : `z_multi_flashcard_editor_*_test.dart`.
- Une seule arête pubspec ajoutée : `zcrud_study → zcrud_ui_kit` (acyclique, prouvé).

### Écarts tranchés (mode non-interactif — option conservatrice)

1. **Placement dans `zcrud_study`** (et non `zcrud_flashcard`) : c'est le seul package possédant su-9 +
   l'infra responsive + me-1 sans créer de cycle ; `zcrud_flashcard` ne connaît ni su-9 ni `zcrud_responsive`.
2. **Persistance par callbacks injectés** (`onCommit`, seam `writeRoot` in-memory) plutôt qu'un repository
   importé : conforme AD-43/AD-1 (CORE OUT=0) et rend la preuve « rien persisté » testable.
3. **Régime déclaré via enum public** (option la plus explicite) plutôt qu'un booléen implicite (SM-1/AD-43).
4. **Échec de commit ⇒ conservation du brouillon** (pas de vidage optimiste) : option sûre (aucune perte).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 2.2]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-43]
- [Source: …/ARCHITECTURE-SPINE.md#AD-44] · [#AD-39] · [#AD-45] · [#AD-37] · [#AD-2] · [#AD-15] · [#AD-10] · [#AD-13]
- [Source: packages/zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart] (contrat réel)
- [Source: packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart#applyCommonField] (`clearSucceededFromSelection` défaut `false`)
- [Source: packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart#onGenerated] (su-9)
- [Source: packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart] (su-2, aperçu)
- [Source: packages/zcrud_study/test/presentation/z_widgets_purity_test.dart] (garde récursive existante)
- Réf. compteurs tests (avant me-2) : `zcrud_core` ~946 · `zcrud_list` ~21 · `zcrud_flashcard` ~520 · `zcrud_study` ~379.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (dev-story, effort high) — skill `bmad-dev-story`.

### Debug Log References

- `flutter test` (packages/zcrud_study) : **451 tests, RC=0** (baseline 411 + 40 me-2).
- `flutter analyze` (packages/zcrud_study) : **RC=0** (info-only : `depend_on_referenced_packages` dartz dans les tests — même patron que les tests su-9 existants ; `directives_ordering` pré-existant du barrel).
- `python3 scripts/dev/graph_proof.py` : **ACYCLIQUE OK · CORE OUT=0 OK · 57 arêtes** (arête ajoutée `zcrud_study -> zcrud_ui_kit`).
- Greps négatifs code-only (RC=1 = absence) sur `z_multi_flashcard_editor.dart` + `_controller.dart` : `Repository` · `LocalStore` · `RemoteStore` · `.save(` · `.persist(` · `ZSrsScheduler` · `.reviewCard(` · `Timer(` · `didChangeDependencies` · `onDuplicate` → tous RC=1. Présence RC=0 : `ZFlashcardReviewCard`, `applyCommonField`. `clearSucceededFromSelection` absent du code éditeur (défaut `false` **consommé**, non redéclaré).

### Completion Notes List

- **Placement** : `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart` (+ contrôleur brouillon `z_multi_flashcard_editor_controller.dart`), export via le barrel. Seule arête pubspec ajoutée : `zcrud_study → zcrud_ui_kit: ^0.2.1` (acyclique prouvé).
- **AD-43 (3 étages)** : (a) structurel — aucun import store (garde de pureté récursive existante + `ad43_structure_test` vm) ; (b) espion de commit **prouvé captant AVANT** (écriture témoin ⇒ `writes==1`) puis édit→add→delete→gen→abandon ⇒ `writes` inchangé (controller_test **et** widget_test) ; (c) commit ⇒ **1 seule** salve portant l'intégralité de la liste. Chasse aux fuites : greps négatifs ci-dessus + garde vm.
- **me-1 consommé** : `ZListSelectionController` unique passé à `ZBatchActionBar` ; `applyCommonField` avec seam `writeRoot` in-memory ; `clearSucceededFromSelection` défaut `false` consommé (sélection conservée — testé « 2 sélectionnée(s) » après apply).
- **su-2** : aperçu = `ZFlashcardReviewCard` (jamais un rendu parallèle). **su-9** : `onGenerated` → `addGenerated` (cartes éphémères `id==null`, jamais persistées ; launcher absent sans port). **`zcrud_responsive`** : split-view via `ZResponsiveLayout`. **`ZDiscardChangesGuard`** existant enveloppe la surface (`isDirty` alimenté).
- **SM-1** : tranches `orderKeys`/`isDirty` disjointes ⇒ éditer un champ n'émet PAS la structure (compteur de builds de ligne = 0 pendant la frappe ; controller stable) ; enum `ZEditingMode` (pas de booléen implicite).
- **AC9** : commit qui échoue ⇒ brouillon *dirty* préservé, aucune perte (pas de vidage optimiste) ; génération `Right([])` ⇒ liste intacte ; liste vide / 1 / N ⇒ rendu défini, aucun throw.
- Aucun `@ZcrudModel`/codegen touché (gate `codegen-distribution` sans objet). `zcrud_core`/`zcrud_flashcard` NON modifiés (CORE OUT=0 préservé).

### Remédiation code-review (post-review)

Skill : cycle `bmad-code-review` (dev remédiation, effort high). Rapport complet : `_bmad-output/implementation-artifacts/stories/code-review-me-2.md`.

- **BUG-1 (MAJEUR, perte de données) corrigé** : `_ZCardForm._rebuild()` repartait de `widget.initialCard` (snapshot figé) ⇒ un champ commun appliqué à la carte focalisée était reverté à null à la frappe suivante. Correctif : base VIVANTE relue via `baseCardOf: () => _draft.cardOf(key)` (controllers NON recréés — AD-2 préservé). Test porteur `BUG-1` (rouge : folderId=null avant ; vert après).
- **BUG-2 (MAJEUR, AD-10) corrigé** : `commit()` awaitait `onCommit` sans garde ⇒ un throw traversait la surface. Correctif : `try/catch` mappant le throw en `Left(ServerFailure)` (patron `batchApply`). Tests porteurs `BUG-2` (controller + widget).
- **BUG-3 (MEDIUM, commit ré-entrant) corrigé** : garde `_isCommitting` (try/finally) ⇒ un double-tap ne déclenche qu'UNE salve. Test porteur `BUG-3` (rouge : writes=2 ; vert : writes=1).
- **FIX-4/FIX-5/FIX-6** : tests rendus falsifiables / ajoutés (espion câblé au MÊME canal `commit` ; édit de champ → commit prouvé ; mutation champ commun → commit prouvé).
- **FIX-7/FIX-8 (a11y)** : launcher de génération borné + MESURÉ ≥48dp (+ champ commun + dropdown type) ; `MergeSemantics` retiré du rang (bascule ET ouverture = deux nœuds sémantiques distincts).
- **FIX-9 (MEDIUM, SM-1) corrigé** : recalcul du *dirty* rendu INCRÉMENTAL (`_divergentCount` ajusté en O(1) par frappe) au lieu d'une reconstruction O(N) + égalité profonde à chaque `onChanged`.
- **LOW#10 corrigé** (message d'échec localisé seul, plus de concat de `failure.message` brute), **LOW#13 corrigé** (test génération `Left`). **LOW#15 consigné** (résumé de ligne stale en split-view — tradeoff SM-1 documenté, pas de correctif).

Vérif verte rejouée : `flutter test` (packages/zcrud_study) = **462 tests, RC=0** (451 → 462, +11 porteurs) · `dart analyze .` = **RC=0** · graphe inchangé (aucune arête nouvelle).

### File List

- `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart` (nouveau ; remédié BUG-1/BUG-3/FIX-7/FIX-8/LOW#10)
- `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor_controller.dart` (nouveau ; remédié BUG-2/FIX-9)
- `packages/zcrud_study/lib/zcrud_study.dart` (modifié — exports me-2)
- `packages/zcrud_study/pubspec.yaml` (modifié — arête `zcrud_ui_kit: ^0.2.1`)
- `packages/zcrud_study/test/presentation/z_multi_flashcard_editor_controller_test.dart` (nouveau ; +BUG-2/+FIX-9, FIX-4 falsifiable)
- `packages/zcrud_study/test/presentation/z_multi_flashcard_editor_test.dart` (nouveau ; +BUG-1/+BUG-2/+BUG-3/+FIX-5/+FIX-6)
- `packages/zcrud_study/test/presentation/z_multi_flashcard_editor_generation_test.dart` (nouveau ; +LOW#13)
- `packages/zcrud_study/test/presentation/z_multi_flashcard_editor_ad43_structure_test.dart` (nouveau — 6 tests vm, greps de fuite durables)
- `packages/zcrud_study/test/presentation/z_multi_flashcard_editor_a11y_test.dart` (nouveau ; +FIX-7 launcher/type, +FIX-8 nœuds distincts)
- `_bmad-output/implementation-artifacts/stories/code-review-me-2.md` (nouveau — rapport de revue + remédiation)
