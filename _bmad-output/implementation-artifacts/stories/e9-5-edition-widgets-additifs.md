---
baseline_commit: 04aaaf09d72ad2d56178e2b240f5f1f62570cc3e
---

# Story 9.5 : Édition & widgets additifs pour lex_douane (`zcrud_flashcard`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **intégrateur de lex_douane (module « Étude » en développement actif), puis DODLP**,
I want **des widgets d'édition flashcard **additifs**, paramétrés par MES entités (via `ZWidgetRegistry`/adaptateurs, sans imposer un second modèle), qui branchent la validation éditeur (QCM min 2 choix + ≥1 correct, question requise — déférée d'E9-1) et composent le dépôt E9-4 (`ZFlashcardRepository`/`ZSrsScheduler`) ; qui déplacent une carte entre dossiers **en re-synchronisant le `folderId` dénormalisé de la ligne SRS** (dette M1 d'E9-4) ; et qui rendent `initRepetition` idempotent (dette L2 d'E9-4)**,
so that **lex_douane bénéficie du socle d'édition partagé (réactivité Flutter-native SM-1, a11y AD-13, thème injecté FR-26) **sans remplacer** son module « Étude » ni son offline-first (UJ-4), le SRS restant piloté par l'app ; le tout **sans** tirer Firebase/gestionnaire d'état/Syncfusion dans `zcrud_flashcard` (AD-1) et **sans** modifier `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

**Dernière story de l'épic E9 — Flashcards (`zcrud_flashcard`)**, et **première couche `presentation/`** du package (aujourd'hui : `domain/` + `data/`). Elle réalise **FR-16 (édition)** et **UJ-4** (widgets additifs paramétrés par les entités de l'app).

**Positionnement produit (NON-NÉGOCIABLE — UJ-4, PRD §346, §411)** : zcrud **ne remplace pas** le module « Étude » de lex_douane ni son offline-first Hive+Firestore. E9-5 fournit des **widgets additifs** que l'app **enregistre et paramètre par ses propres entités** (adaptateurs/closures), branchés sur `DynamicEdition` du cœur **via `ZWidgetRegistry`** — jamais un second moteur concurrent. Le SRS **reste piloté par l'app** (branchable sur `ZSrsScheduler`, défaut SM-2).

**État de l'épic à l'entrée (tout `done`)** :
- **E9-1** : `ZFlashcard` (`ZEntity` codegen, 6 types, `choices: List<ZChoice>?`, `folderId`/`subFolderId`, slots AD-4 `source`/`extension`/`extra`, **zéro champ SRS**), `ZChoice` (`content`/`isCorrect`), `ZFlashcardType` (6 valeurs), `ZFlashcardSource`. **Note explicite E9-1** : « validation min 2 choix + 1 correct **déférée à E9-5** » (`z_flashcard.dart:152`, `z_choice.dart` docstring).
- **E9-2** : `ZRepetitionInfo` (contenant pur, clé `flashcardId` + `folderId` dénormalisé, `nextReviewDate`, **pas de `copyWith` SRS public**), `ZSrsScheduler`/`ZSm2Scheduler`/`ZSrsConfig` (voie pure `apply`/`initial`).
- **E9-3** : `ZStudyFolder` (hiérarchie 2 niveaux), `ZReviewMode`, `ZStudySessionConfig`, primitives pures `validatePlacement`/`ZStudySessionSelector`.
- **E9-4** : couche `data/` offline-first — `ZFlashcardRepository` (coordinateur composant les ports E5 injectés) + `ZRepetitionStore` (canal SRS séparé top-level, voie d'écriture unique `reviewCard`→`apply`, `initRepetition`→`initial`). **135 tests verts.**

**Cette story branche enfin l'UI d'édition** : widgets de champ flashcard-spécifiques (sélecteur de type, éditeur QCM `ZChoice`, vrai/faux, énoncé/réponse/explication/indice, tags) montés **dans** `DynamicEdition` par le dispatcher `ZFieldWidget` → `ZWidgetRegistry`, **plus** la validation éditeur déférée, **plus** la fermeture des deux dettes d'E9-4 (M1 déplacement/re-sync `folderId` SRS ; L2 idempotence `initRepetition`).

### Invariants d'architecture applicables (NON-NÉGOCIABLES)

- **AD-2 / AD-15 (réactivité Flutter-native — OBJECTIF PRODUIT N°1 / SM-1)** [Source: architecture.md#AD-2,#AD-15 ; z_form_controller.dart] : l'état vit dans `ZFormController` (`ChangeNotifier`/`ValueListenable` **pur-Flutter**). **Un champ = un widget qui n'écoute que sa tranche** via `ZFieldListenableBuilder`/`ValueListenableBuilder`. Le widget reçoit un `ZFieldWidgetContext` (`field`/`value`/`onChanged`) : il **lit** `value`, **écrit** via `onChanged` (branché sur `setValue`) — **jamais** de souscription élargie, jamais de rebuild global. `TextEditingController`/`FocusNode` **stables** (créés 1× en `initState`, disposés) ; jamais recréés ni `.text=` réinjectés dans la voie de frappe (sync guardée **hors focus** via le canal `reseedRevision`). **CONTRAINTE DURE : aucun `import` de gestionnaire d'état** (`flutter_riverpod`/`get`/`provider`) dans `zcrud_flashcard` ; branchement injection/cycle de vie par `ZcrudScope` uniquement.
- **AD-4 (extensibilité — widgets paramétrés par l'entité)** [Source: architecture.md#AD-4 ; z_widget_registry.dart] : les widgets sont fournis par le **satellite/app**, enregistrés dans un `ZWidgetRegistry` **instanciable** (jamais un singleton statique mutable), injecté via `ZcrudScope.widgetRegistry`. La paramétrisation par l'entité de l'app passe par **closures/adaptateurs** capturés à l'enregistrement du `builder` (patron E11a-2/E11b : `ZAddressFieldWidget.builder({catalog})`, `ZGeoFieldWidget.builder({adapterFactory})`), pas par du code lex codé en dur.
- **AD-13 (a11y / RTL / directionnel)** [Source: architecture.md#AD-13 ; retro E10 §3(a), AI-E10-1] : **chaque** cible interactive (boutons ET champs éditables) expose une **action sémantique opérable** (`SemanticsAction.tap` déclenchable par lecteur d'écran) ET mesure **≥ 48 dp** ; `Semantics` explicites. Directionnel **obligatoire** : `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end` (jamais `left`/`right`). Listes = `ListView.builder`. `const` partout où immuable.
- **FR-26 (thème & design-tokens injectables)** [Source: prd.md#FR-26 ; z_theme.dart] : **aucun** style/couleur codé en dur ; tout via `ZcrudTheme.of(context)` / `ZcrudScope` / `ThemeExtension`, repli `Theme.of(context)`.
- **AD-9 (voie d'écriture SRS UNIQUE)** [Source: architecture.md#AD-9] : l'**avancement** de l'état SRS (`interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`lastQuality`/`learnedAt`) passe **exclusivement** par `reviewCard()→ZSrsScheduler.apply`. La re-sync du **`folderId` dénormalisé** (M1) est une **relocalisation de routage**, PAS un avancement SRS → n'introduit **aucune** nouvelle voie d'avancement (garantie par construction : la relocalisation **ne peut pas** toucher les champs d'ordonnancement).
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `zcrud_flashcard` dépend de `zcrud_core` (+ `annotations`/`markdown`/`export`). **CONTRAINTE DURE : ne PAS ajouter** `zcrud_firestore`/`cloud_firestore`/`hive`/`firebase_core`/Syncfusion/gestionnaire d'état au pubspec flashcard ; `grep -R "cloud_firestore\|package:hive\|firebase_core\|zcrud_firestore\|flutter_riverpod\|package:get/\|package:provider/" packages/zcrud_flashcard/lib` = **0**. **CONTRAINTE DURE : ne PAS modifier `zcrud_core`** — tout le neuf vit dans `zcrud_flashcard/lib/src/presentation/` (+ ajouts data/domain minimalement ciblés pour M1/L2). Si un besoin core **réel** émerge (ex. hook de dispatcher manquant) → **STOP** et signaler à l'orchestrateur.

### Leçons E10 (retro) à appliquer d'emblée — clôture des motifs récurrents

- **AI-E10-1 (a11y outillée)** [Source: epic-10-retrospective.md §5 ; z_intl `test/support/a11y_asserts.dart`] : **réutiliser** les helpers `assertSemanticActionTap(tester, finder)` + `assertMinTapTarget(tester, finder, 48)` créés en E11b-2. Ils sont **locaux au package** (pas de package de test partagé) → **copier** `a11y_asserts.dart` verbatim dans `packages/zcrud_flashcard/test/support/`. Les appliquer à **chaque** cible interactive (add/remove choix, toggle « correct », sélecteur de type, boutons d'action, champs éditables) — pas un échantillon.
- **AI-E10-2 (garde grep exhaustif)** [Source: epic-10-retrospective.md §5] : le garde de conformité FR-26/directionnel doit (1) scanner la **denylist complète** par AC (`Colors.`, `Color(0x`, `EdgeInsets.only(left`, `EdgeInsets.only(right`, `Alignment.centerLeft`, `Alignment.centerRight`, `Positioned(left`, `Positioned(right`, `TextAlign.left`, `TextAlign.right`, imports gestionnaires d'état) ; (2) être **cwd-robuste** (essayer `''` puis `packages/zcrud_flashcard/`) ; (3) **strip-comment** avant scan (les docstrings nomment légitimement des API interdites).
- **AI-E10-3 (rebuild ciblé O(1))** [Source: epic-10-retrospective.md §5] : **un seul point d'écoute par tranche**. Ne PAS empiler deux `ValueListenableBuilder` sur le même notifier (motif #3 E10-2 M1). Un sous-widget (ligne de choix QCM) reçoit un état **déjà résolu** par le parent, pas un ré-abonnement interne au notifier partagé. Test : une frappe/interaction ne reconstruit **littéralement que la tranche concernée**.

## Acceptance Criteria

1. **Widgets d'édition flashcard ADDITIFS, paramétrés par l'entité, enregistrés via `ZWidgetRegistry` (UJ-4, AD-4).** `zcrud_flashcard/lib/src/presentation/` fournit des `ZFieldWidgetBuilder` flashcard-spécifiques, **enregistrables** dans un `ZWidgetRegistry` injecté (via `ZcrudScope.widgetRegistry`) et rendus **dans** `DynamicEdition` du cœur par le dispatcher `ZFieldWidget` — **sans modifier `zcrud_core`** et **sans** second moteur d'édition. Au minimum : (a) **sélecteur de type** `ZFlashcardType` (6 valeurs, défensif → `openQuestion`) ; (b) **éditeur QCM** de `List<ZChoice>` (ajouter/supprimer/réordonner un choix, éditer `content`, basculer `isCorrect`) ; (c) **vrai/faux** (`isTrue`) ; (d) champs texte énoncé/réponse/explication/indice ; (e) **tags** (`tagIds`). La **paramétrisation par l'entité de l'app** passe par **closures/adaptateurs** capturés à l'enregistrement (patron `Xxx.builder({...})` de E11a-2/E11b) : aucune référence au modèle `Flashcard` de lex codée en dur. *Test : un `ZWidgetRegistry` peuplé par la factory publique du package sert chaque `kind` ; `DynamicEdition`/`ZFieldWidget` monte le widget dans la frontière de rebuild sans repli `ZUnsupportedFieldWidget`.*
2. **Validation éditeur déférée d'E9-1, révélée sans `Form` global (AD-2).** QCM : **≥ 2 choix** ET **≥ 1 choix `isCorrect == true`** (message actionnable sinon) ; `question` requise (déjà `ZValidatorSpec.required()` côté spec) ; les messages de **toutes** les familles (y compris QCM/type/vrai-faux, non-texte) sont révélés à la **soumission agrégée** via le **canal `reveal`** du `ZFormController` — **jamais** un `Form`/`FormBuilder` global (AD-2). *Test : soumettre un QCM à 1 choix (ou 0 correct) → message d'erreur révélé, soumission bloquée ; corriger → soumission passe ; la révélation n'entraîne aucun rebuild global (SM-1 intact).*
3. **Réactivité Flutter-native AD-2/AD-15 — rebuild ciblé SM-1, focus préservé, controller stable.** Écriture **exclusivement** via `ctx.onChanged` (branché `setValue`) ; `TextEditingController`/`FocusNode` créés **1×** en `initState`, disposés, **jamais** recréés ni `.text=` réinjectés pendant la frappe ; sync valeur↔buffer **guardée hors focus** (canal `reseedRevision`). **Un seul point d'écoute par tranche** (AI-E10-3). *Test SM-1 : taper 100 caractères dans l'énoncé ne reconstruit **que** le champ courant (compteur `onBuild` ciblé), **zéro** perte de focus, aucun saut de curseur ; ajouter un choix QCM ne reconstruit que l'éditeur QCM ; identité du `TextEditingController` stable entre frappes.*
4. **a11y AD-13 — action sémantique opérable + ≥ 48 dp + directionnel, via helpers réutilisés.** Chaque cible interactive (boutons ajouter/supprimer choix, toggle « correct », sélecteur de type, champs éditables, boutons d'action) expose `SemanticsAction.tap` **opérable** (déclenchable via lecteur d'écran) ET mesure **≥ 48 dp** ; `Semantics` explicites ; layout **directionnel** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start/end`), listes en `ListView.builder`. *Test : `assertSemanticActionTap` + `assertMinTapTarget(…, 48)` (helpers copiés de E11b-2 dans `test/support/a11y_asserts.dart`) sur **chaque** cible interactive — pas un échantillon ; un test RTL (`Directionality.rtl`) ne casse pas le rendu.*
5. **Thème injecté FR-26 — zéro style/couleur codé en dur + garde grep exhaustif.** Couleurs/styles via `ZcrudTheme.of(context)` / `ZcrudScope` / `ThemeExtension`, repli `Theme.of(context)` ; **aucun** `Colors.` / `Color(0x…)` en dur. Un **test de garde** grep exhaustif (denylist complète AI-E10-2 : `Colors.`, `Color(0x`, `EdgeInsets.only(left`, `EdgeInsets.only(right`, `Alignment.centerLeft`, `Alignment.centerRight`, `Positioned(left`, `Positioned(right`, `TextAlign.left`, `TextAlign.right`, imports gestionnaires d'état), **cwd-robuste** + **strip-comment**) scanne `packages/zcrud_flashcard/lib/` et **échoue** si un motif interdit apparaît. *Test : garde vert sur le code livré ; (méta) le garde détecte un motif injecté.*
6. **Intégration `ZFlashcardRepository`/`ZSrsScheduler` — SRS piloté par l'app.** Les widgets/écran d'édition composent le **dépôt E9-4 injecté** : la sauvegarde d'une carte éditée délègue à `ZFlashcardRepository.save` (matérialisation éphémère + garde `folderId` héritées d'E9-4, **inchangées**) ; l'inscription d'une carte à l'étude passe par `initRepetition` (cf. AC8) ; le SRS **reste piloté par l'app** (branchable `ZSrsScheduler`). **Aucune** voie SRS **avancée** n'est introduite hors `reviewCard` (AD-9). *Test : édition→`save` délègue au dépôt (fake) ; aucun chemin widget n'avance l'état SRS hors `reviewCard`.*
7. **[Dette M1 d'E9-4 — INTÉGRÉE] Déplacement de carte + re-sync du `folderId` SRS dénormalisé.** E9-5 introduit une opération de **déplacement** de carte entre dossiers : `ZFlashcardRepository.moveCard({required String flashcardId, required String folderId, String? subFolderId})` met à jour **atomiquement** (1) le `folderId`/`subFolderId` de la **carte** (via le port carte) **et** (2) le `folderId` **dénormalisé de la ligne SRS** (relocalisation **folder-only** via `ZRepetitionStore` — **sans** toucher aucun champ d'ordonnancement : `interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`lastQuality`/`learnedAt` **inchangés**, donc **pas** une voie d'avancement AD-9). Si la carte n'a **aucune** ligne SRS, seule la carte est déplacée (`vide ≠ erreur`). *Test : après `moveCard(old→new)`, `getDue(folderId: new)` **inclut** la carte et `getDue(folderId: old)` l'**exclut** ; les champs d'ordonnancement de la ligne SRS sont **identiques** avant/après (relocalisation pure) ; carte sans ligne SRS → déplacement carte OK, aucun `put` SRS.*
8. **[Dette L2 d'E9-4 — TRANCHÉE] Idempotence de `initRepetition` (garde par défaut + reset explicite documenté).** `initRepetition({flashcardId, folderId})` devient **idempotent** : si un état SRS **existe déjà** pour la carte, il est **préservé** et **renvoyé tel quel** (no-op — **aucun** écrasement de `repetitions`/`interval`/`learnedAt`) ; il n'écrit un état neuf que si **absent** (première inscription). Un **reset délibéré** passe par une voie **explicite documentée** (`resetRepetition({flashcardId, folderId})`, ou un paramètre `force`), qui réinitialise via `scheduler.initial`. *Test : double `initRepetition` sur une carte avec historique → l'historique est **préservé** (état renvoyé == existant) ; `resetRepetition` → état remis à neuf (`initial`) ; les deux restent conformes à la voie d'écriture unique (ni l'un ni l'autre n'appelle `apply`).*
9. **Isolation AD-1 — flashcard ne tire ni Firebase, ni gestionnaire d'état, ni Syncfusion ; `zcrud_core` intact.** `pubspec.yaml` **n'ajoute aucune** dép backend/manager/Syncfusion ; `grep -R` (motifs AC5 + backend) sous `lib/` = **0** ; graphe **acyclique** inchangé (`zcrud_flashcard → {annotations, core, export, generator, markdown}`) ; **aucune** édition de `zcrud_core` (diff confiné à `packages/zcrud_flashcard/**`). *Gate : `graph_proof` ACYCLIQUE + CORE OUT=0 ; grep=0 ; `git diff --name-only` ne touche pas `packages/zcrud_core/`.*
10. **Non-régression E9-1..4.** Tous les tests existants du package restent **verts** (baseline 135) : invariant SRS top-level (AC2 E9-4), non-duplication au partage (AC3 E9-4), voie d'écriture SRS unique, matérialisation éphémère + garde `folderId` (AC5/AC6 E9-4), `getDue` filtré, défensif AD-10. Les ajouts M1/L2 **n'altèrent pas** ces invariants. *Gate : `flutter test packages/zcrud_flashcard` RC=0, total ≥ 135 + nouveaux.*

## Tasks / Subtasks

- [x] **T1. Couche `presentation/` + factory d'enregistrement des widgets** (AC1, AC4, AC5)
  - [x] Créer `packages/zcrud_flashcard/lib/src/presentation/`.
  - [x] Widgets `StatefulWidget` flashcard-spécifiques (`ctx` en champ, `onInit`/`onBuild` `@visibleForTesting`, `TextEditingController`/`FocusNode` créés 1× par ligne + disposés) : sélecteur de type, éditeur QCM `ZChoice` (`ListView.builder`, add/remove/reorder/toggle-correct), vrai/faux. Champs texte (énoncé/réponse/explication/indice) et tags via familles du cœur (`multiline`/`text`/`tags`) exposés par les fabriques `ZFlashcardEditionFields`.
  - [x] Factory publique `registerZFlashcardEditors(ZWidgetRegistry, {closures})` — un **unique** builder sous le `kind` `custom` discriminé par `ZFlashcardFieldConfig.editorKind` (contrainte : le cœur ne route le registre que par `field.type.name` ; `zcrud_core` non modifié). Libellés/messages capturés par closure (AD-4), **aucun** singleton statique.
  - [x] Thème 100 % `ZcrudTheme.of` (repli `Theme.of`), directionnel, `Semantics`+≥48 dp sur chaque cible.
  - [x] Exporter l'API publique au barrel `zcrud_flashcard.dart` (préserver les `hide …Zcrud` existants).
- [x] **T2. Validation éditeur déférée d'E9-1** (AC2)
  - [x] QCM : ≥ 2 choix + ≥ 1 `isCorrect`, message actionnable (`ZFlashcardEditionValidator`) ; révélation via canal `reveal` du `ZFormController` (exposé par `ZFlashcardEditingScope`, pas de `Form` global).
  - [x] `validateAndReveal(controller)` : brique d'intégration soumission (bloque + `revealErrors`), le SRS/persistance restant pilotés par l'app.
- [x] **T3. Intégration dépôt E9-4** (AC6)
  - [x] Composition `ZFlashcardRepository` injecté : `save` (édition), `initRepetition` (inscription, cf. T5), sans introduire de voie SRS avancée hors `reviewCard`.
- [x] **T4. [M1] `moveCard` + relocalisation folder-only du SRS** (AC7, AC9, AC10)
  - [x] `ZFlashcardRepository.moveCard({flashcardId, folderId, subFolderId})` : maj carte (port carte) **et** relocalisation `folderId` de la ligne SRS **sans** toucher les champs d'ordonnancement.
  - [x] `ZRepetitionInfo.withFolder(folderId)` (copie **folder-only**, additif minimal au modèle E9-2, ne peut PAS changer l'ordonnancement — AD-9). Carte sans ligne SRS → déplacement carte seul.
- [x] **T5. [L2] Idempotence `initRepetition` + `resetRepetition`** (AC8, AC10)
  - [x] `initRepetition` : `getByCard` d'abord → si présent, renvoyer l'existant (no-op) ; sinon `initial`+`put`.
  - [x] `resetRepetition({flashcardId, folderId})` (voie de reset **explicite**, documentée) → `initial`+`put` inconditionnel.
- [x] **T6. Helpers a11y + fakes** (AC4, tests)
  - [x] Copier `test/support/a11y_asserts.dart` (verbatim de `zcrud_intl`, AI-E10-1).
  - [x] Réutiliser `test/support/fakes.dart` (fakes carte + `ZRepetitionStore` d'E9-4) pour move/init/édition.
- [x] **T7. Tests** — `test/z_flashcard_editors_test.dart` + `test/z_flashcard_repository_move_init_test.dart` + `test/flashcard_guard_gates_test.dart` : AC1 montage via registry, AC2 validation QCM révélée, AC3 SM-1 (100 car., focus, controller stable, rebuild ciblé), AC4 a11y opérable+48dp+RTL, AC5 garde grep, AC6 intégration dépôt, AC7 move+re-sync (getDue), AC8 idempotence+reset, AC10 non-régression.
- [x] **T8. Gates** : garde grep FR-26/directionnel/manager (cwd-robuste, strip-comment) = 0 ; `grep` AD-1 backend = 0 ; aucun `@ZcrudModel` nouveau (codegen inchangé) → `dart analyze` RC=0 → `flutter test` RC=0 (163 : 135 baseline + 28) → `graph_proof` ACYCLIQUE + CORE OUT=0 ; diff confiné à `packages/zcrud_flashcard/**`.

## Dev Notes

### API du cœur réutilisée **verbatim** (aucune réécriture, `zcrud_core` intact)
- `ZWidgetRegistry` / `ZFieldWidgetBuilder` / `ZFieldWidgetContext(field,value,onChanged)` [z_widget_registry.dart] — point d'ancrage des widgets externes. Le dispatcher `ZFieldWidget` (cœur) rend le builder **dans** `ZFieldListenableBuilder` (value-in-slice). Injection via `ZcrudScope.widgetRegistry` (E3-3b).
- `ZFormController` [z_form_controller.dart] — `fieldListenable(name)` (tranche stable mémoïsée), `setValue` (notifie **seulement** la tranche, jamais global), canaux dédiés : **`reveal`** (révélation d'erreurs à la soumission, **sans** `Form` global), **`reseedRevision`** (write-back **hors focus**), `isDirty`. **Ne jamais** élargir la frontière de rebuild.
- `DynamicEdition` / `ZFieldWidget` / `ZValidatorSpec` / `ZFieldSpec` [presentation/edition/*] — moteur d'édition existant ; E9-5 **branche** ses widgets dedans, **ne le réécrit pas**.
- `ZcrudTheme.of` / `ZcrudScope` [z_theme.dart, zcrud_scope.dart] — thème injecté (FR-26), repli `Theme.of`.

### Patron de widget de champ à copier (E11a-2/E11b — exemplaire AD-2)
[Source: zcrud_intl `z_address_field_widget.dart`, zcrud_geo `z_geo_field_widget.dart`]
- `StatefulWidget` ; `final ZFieldWidgetContext ctx;` ; `@visibleForTesting final VoidCallback? onInit/onBuild;` (preuves SM-1) ; `static ZFieldWidgetBuilder builder({...closures...})` capturant les adaptateurs par closure (**paramétrisation par l'entité de l'app**, AD-4) ; chaque **montage** crée SES `TextEditingController`/`FocusNode` (jamais aliasés) et les dispose. Écriture `ctx.onChanged(newValue)` uniquement. **Ne PAS** créer les contrôleurs dans `build()`, **ne PAS** `.text=` pendant la frappe.

### Domaine/data flashcard touché
- **NEW** `lib/src/presentation/` (widgets d'édition + factory d'enregistrement).
- **UPDATE (ciblé, M1/L2)** `lib/src/data/z_flashcard_repository.dart` — ajouter `moveCard` (T4) ; rendre `initRepetition` idempotent + `resetRepetition` (T5). Préserver **inchangés** `save` (garde `folderId`/matérialisation), `reviewCard` (voie unique), `getDue`, `sync`.
- **UPDATE (ciblé, M1, si retenu)** `lib/src/domain/z_repetition_info.dart` — ajout **additif minimal** `withFolder(folderId,{subFolderId})` **folder-only** (ne touche PAS l'ordonnancement ; ne réintroduit PAS de `copyWith` SRS d'avancement). Alternative : relocalisation portée par `ZRepetitionStore` sans toucher le modèle — au choix, tant qu'AD-9 tient.
- **UPDATE** `lib/zcrud_flashcard.dart` — exporter l'API `presentation/` (préserver `hide ZRepetitionInfoZcrud`/`ZStudyFolderZcrud`/`ZStudySessionConfigZcrud`).
- **REUSE (ne pas modifier)** : `ZFlashcard`, `ZChoice`, `ZFlashcardType`, `ZSrsScheduler`/`ZSm2Scheduler`, `ZRepetitionStore` (port).

### Traitement des dettes E9-4 (décisions verrouillées pour cette story)
- **M1 (MEDIUM E9-4) → INTÉGRÉE (AC7/T4).** E9-4 avait **différé avec justification** : « aucune opération de déplacement exposée ». E9-5 **introduit** le déplacement (édition = changer le dossier d'une carte est une affordance d'édition naturelle) → la re-sync du `folderId` SRS **devient live** et **doit** être traitée ici (politique MEDIUM CLAUDE.md : corriger dès que possible dans le périmètre). Fait **par conception** : `moveCard` atomique + relocalisation **folder-only** (garantit qu'aucun champ d'ordonnancement ne bouge → AD-9 intact). C'est la **dernière** story de l'épic : ne pas fermer M1 ici le ferait échapper au périmètre de l'épic.
- **L2 (LOW E9-4) → TRANCHÉE (AC8/T5).** Décision : **garde d'idempotence par défaut** (protège la perte de `repetitions`/`interval`/`learnedAt`) **+ voie de reset explicite documentée** (`resetRepetition`). Rationale : l'UI d'inscription (E9-5) appellera `initRepetition` ; un double-appel accidentel ne doit **jamais** écraser un historique ; le reset délibéré reste possible mais **nommé**.

### Pièges LLM à éviter
- **NE PAS** modifier `zcrud_core` — les widgets se branchent via `ZWidgetRegistry` (déjà prévu pour ça). Besoin core réel → STOP + signaler.
- **NE PAS** importer un gestionnaire d'état (`flutter_riverpod`/`get`/`provider`) ni Firebase/Hive/Syncfusion dans `zcrud_flashcard`.
- **NE PAS** remplacer/dupliquer `DynamicEdition` ni le module « Étude » de lex — widgets **additifs** paramétrés par l'entité (UJ-4).
- **NE PAS** créer un `TextEditingController` dans `build()` ni `.text=` pendant la frappe ; **NE PAS** empiler 2 `ValueListenableBuilder` sur le même notifier (AI-E10-3).
- **NE PAS** introduire une voie SRS **avancée** hors `reviewCard` ; `moveCard`/`initRepetition`/`resetRepetition` **ne calculent jamais** d'ordonnancement (`apply`).
- **NE PAS** coder couleur/`Colors.`/`Color(0x…)` en dur (FR-26) ; **NE PAS** utiliser `left/right` (directionnel obligatoire).
- **NE PAS** tester l'a11y au pointeur seul : exercer `SemanticsAction.tap` (helper) sur **chaque** cible + asserter ≥ 48 dp (champs inclus).

### Project Structure Notes
- Alignement : `zcrud_<domaine>` ; barrel `lib/<pkg>.dart` ; impl `lib/src/{domain,data,presentation}`. E9-5 introduit `lib/src/presentation/` (premier de ce package).
- Aucun conflit structurel ; les widgets flashcard sont un ajout **satellite** légitime (le cœur reste agnostique — `ZWidgetRegistry` OUT=0 inchangé).

### References
- [Source: epics.md#E9] — Story E9-5 : widgets additifs paramétrés par l'entité ; **ne remplace pas** « Étude » (UJ-4).
- [Source: prd.md#UJ-4, §346, §411, #FR-16, #FR-26] — widgets additifs paramétrés par les entités de l'app, sans second modèle ; validation d'édition ; thème injecté.
- [Source: architecture.md#AD-2,#AD-15,#AD-4,#AD-13,#AD-9,#AD-1] — réactivité Flutter-native/SM-1 ; extensibilité (registre widgets) ; a11y/RTL ; voie SRS unique ; isolation.
- [Source: stories/code-review-e9-4.md#M1,#L2] — dettes rattachées à E9-5 : re-sync `folderId` SRS au déplacement (M1) ; idempotence `initRepetition` (L2).
- [Source: stories/e9-4-depot-offline-first-invariant-srs.md] — `ZFlashcardRepository`/`ZRepetitionStore` (dépôt composé, voie unique, garde `folderId`).
- [Source: epic-10-retrospective.md#AI-E10-1,#AI-E10-2,#AI-E10-3] — helpers a11y outillés, garde grep exhaustif/cwd-robuste/strip-comment, rebuild ciblé O(1).
- [Source: z_widget_registry.dart, z_form_controller.dart] — `ZFieldWidgetContext`/`ZFieldWidgetBuilder` ; canaux `reveal`/`reseedRevision`/`setValue` (SM-1).
- [Source: zcrud_intl/test/support/a11y_asserts.dart] — helpers `assertSemanticActionTap`/`assertMinTapTarget` à copier.
- [Source: zcrud_intl `z_address_field_widget.dart`, zcrud_geo `z_geo_field_widget.dart`] — patron de widget de champ AD-2 (contrôleurs stables, `builder({closures})`, hooks `onInit`/`onBuild`).
- [Source: z_flashcard.dart:152, z_choice.dart] — validation QCM (min 2 + 1 correct) **déférée à E9-5**.

### Testing
Framework : `flutter test` (le package tire Flutter via `zcrud_core`). Fichiers `*_test.dart` sous `packages/zcrud_flashcard/test/`. Helpers a11y : `test/support/a11y_asserts.dart` (copié). Fakes en mémoire (pas de Firebase). Cas obligatoires :
- **AC1** : registry peuplé par la factory publique sert chaque `kind` ; `ZFieldWidget`/`DynamicEdition` monte le widget (pas de repli `ZUnsupportedFieldWidget`).
- **AC2** : QCM 1 choix / 0 correct → erreur révélée (canal `reveal`), soumission bloquée ; corrigé → passe ; révélation sans rebuild global.
- **AC3 (SM-1)** : 100 caractères dans l'énoncé → seul le champ courant reconstruit (compteur `onBuild`), focus conservé après `enterText`, curseur non déplacé, identité `TextEditingController` stable ; ajout d'un choix ne reconstruit que l'éditeur QCM ; **un seul** point d'écoute par tranche.
- **AC4 (a11y)** : `assertSemanticActionTap` + `assertMinTapTarget(…,48)` sur **chaque** cible (add/remove choix, toggle correct, sélecteur de type, champs, boutons) ; rendu `Directionality.rtl` sans casse.
- **AC5 (FR-26)** : garde grep exhaustif (denylist AI-E10-2, cwd-robuste, strip-comment) vert sur le livré ; (méta) détecte un motif injecté.
- **AC6** : édition→`save` délègue au dépôt (fake) ; aucun chemin widget n'avance le SRS hors `reviewCard`.
- **AC7 (M1)** : `moveCard(old→new)` → `getDue(new)` inclut / `getDue(old)` exclut ; champs d'ordonnancement SRS **identiques** avant/après ; carte sans ligne SRS → carte déplacée, aucun `put` SRS.
- **AC8 (L2)** : double `initRepetition` préserve l'historique (== existant) ; `resetRepetition` → `initial` neuf ; ni l'un ni l'autre n'appelle `apply`.
- **AC9/AC10** : grep AD-1 = 0 ; `graph_proof` ACYCLIQUE + CORE OUT=0 ; `git diff` hors `zcrud_core` ; 135 baseline verts + nouveaux.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill chargé via le tool `Skill`).

### Debug Log References

- `dart analyze packages/zcrud_flashcard` → **No issues found** (RC=0).
- `flutter test packages/zcrud_flashcard` → **All tests passed** (163 tests : 135 baseline E9-1..4 + 28 nouveaux).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK ; CORE OUT=0 OK** (RC=0). `zcrud_flashcard → {annotations, core, export, generator, markdown}` uniquement — aucune arête firestore/manager/Syncfusion.
- `flutter test packages/zcrud_flashcard --tags serialization-compat` → **No tests ran** (SKIP attendu — aucun test tagué).

### Completion Notes List

- **Contrainte `zcrud_core` intact** : le dispatcher du cœur route le registre par `field.type.name`. Comme on **ne modifie pas** `zcrud_core` et qu'il n'existe qu'un `kind` `custom`, les 3 widgets flashcard-spécifiques (type/QCM/vrai-faux) sont servis par **un unique** builder enregistré sous `custom`, **discriminé** par `ZFlashcardFieldConfig.editorKind` (sous-classe additive `ZFieldConfig`, AD-4). Chaque champ reste sa **propre tranche** (SM-1 préservé). **Aucun** besoin core réel détecté.
- **AC2 — reveal sans core** : le canal `reveal` du `ZFormController` n'est pas accessible via `ZFieldWidgetContext`. Introduit `ZFlashcardEditingScope` (InheritedWidget **flashcard-local**, additif) qui expose le contrôleur ; l'éditeur QCM observe **uniquement** `controller.reveal` (tranche dédiée). La validation métier (List<ZChoice> — inexprimable en `ZValidatorSpec` chaîne-orienté) vit dans `ZFlashcardEditionValidator` (pur) + `validateAndReveal` (bloque la soumission + `revealErrors`).
- **[M1]** `ZFlashcardRepository.moveCard` : maj carte (port carte) puis re-sync **folder-only** de la ligne SRS via `ZRepetitionInfo.withFolder` (aucun champ d'ordonnancement touché → AD-9 par construction). Carte sans ligne SRS → aucun `put` (vide ≠ erreur) ; carte introuvable → `Left(NotFoundFailure)` sans écriture.
- **[L2]** `initRepetition` idempotent (getByCard → no-op si présent) ; `resetRepetition` = reset explicite (`scheduler.initial` inconditionnel). Ni l'un ni l'autre n'appelle `apply`.
- **AD-2/SM-1** : contrôleurs/focus stables par ligne QCM (réordonnancement = déplacement, pas recréation) ; sync guardée hors focus dans `didUpdateWidget` ; écriture via `ctx.onChanged` seul.
- **FR-26/AD-13** : thème injecté (zéro couleur en dur), directionnel, `ListView.builder`, cibles ≥ 48 dp + action sémantique `tap` opérable sur chaque cible (helpers `assertSemanticActionTap`/`assertMinTapTarget` copiés d'E11b-2).
- Non-régression : les 135 tests E9-1..4 restent verts (invariant SRS top-level, non-duplication au partage, voie SRS unique, matérialisation + garde `folderId`, getDue, défensif). Le test AC1 d'E9-4 (`initRepetition` → putCount 1) reste vert (getByCard→null→put).

### File List

**NEW (lib — presentation E9-5)**
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editor_config.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editing_scope.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editor_values.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_edition_validator.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_option_tile.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_type_field_widget.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_true_false_field_widget.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_choices_field_widget.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editors.dart`

**UPDATE (lib)**
- `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` (ajout `withFolder`, folder-only, AD-9)
- `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart` (`moveCard` [M1] ; `initRepetition` idempotent + `resetRepetition` [L2])
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (exports presentation/)

**NEW (test)**
- `packages/zcrud_flashcard/test/support/a11y_asserts.dart` (copié verbatim d'E11b-2)
- `packages/zcrud_flashcard/test/z_flashcard_editors_test.dart`
- `packages/zcrud_flashcard/test/z_flashcard_repository_move_init_test.dart`
- `packages/zcrud_flashcard/test/flashcard_guard_gates_test.dart`
