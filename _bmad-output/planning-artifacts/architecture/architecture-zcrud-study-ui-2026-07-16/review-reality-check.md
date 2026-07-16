---
title: 'Revue — reality check du spine E-STUDY-UI + E-MULTI-EDIT'
target: ARCHITECTURE-SPINE.md
lens: 'chaque décision engagée a-t-elle été confrontée au réel (web / code) plutôt qu''affirmée de mémoire ?'
reviewed: '2026-07-16'
verdict: 'ADOPTABLE APRÈS CORRECTION — 2 décisions reposent sur un état du code non vérifié'
---

# Revue — reality check

## Verdict

Le spine est **bien étayé sur ses seams de session et ses symboles** : 21/21 des symboles zcrud
cités existent réellement sur disque, et les affirmations porteuses d'AD-33 sont vérifiées ligne à
ligne. En revanche **deux décisions engagées (AD-34, AD-40) reposent sur un état du code qui n'a pas
été vérifié** et qui est, en réalité, faux — le memlog a manqué deux fichiers existants. Les
versions de paquets sont globalement exactes, à une exception près (Syncfusion) et une omission
(`printing`, jamais contrôlé).

## Méthode

- Grep exhaustif de 42 symboles dans `/home/zakarius/DEV/zcrud/packages` (`grep -rlw --include='*.dart'`).
- Lecture des pubspecs réels des 7 paquets engagés + du barrel public de `zcrud_export`/`zcrud_session`.
- Interrogation de l'**API pub.dev** (`/api/packages/<p>`) pour les 7 paquets nommés — versions et
  dates de publication réelles, pas de mémoire modèle.
- Lecture seule de `/home/zakarius/DEV/lex_douane` et `/home/zakarius/DEV/iffd` (aucune écriture).

---

## Ce qui est CONFIRMÉ (à conserver tel quel)

### Symboles zcrud — 21/21 existent

Tous les symboles cités par le spine et par les Conventions sont réels :

| Symbole | Preuve |
|---|---|
| `ZStudySessionEngine` | `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart:123` |
| `ZWhiteExamSessionEngine` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:249` |
| `ZSessionReviewer` | `packages/zcrud_session/lib/src/domain/z_session_reviewer.dart` |
| `reduceGrade` | `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` (exporté, réducteur pur) |
| `ZSessionState` | `packages/zcrud_session/lib/src/domain/z_session_state.dart` (value-object immuable) |
| `ZStudySessionSelector`, `ZStudySessionConfig` | `zcrud_study_kernel` (15 / 25 fichiers) |
| `ZSrsConfig`, `ZSrsQualityButtons`, `ZQualityScale` | confirmés |
| `ZPdfCreationService` | `packages/zcrud_export/lib/src/data/z_pdf_creation_service.dart:18` |
| `ZMindmapView` / `nodeContentBuilder` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart` |
| `ZMindmapMarkdownContent` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart` |
| `ZMindmapOutlineEditor`, `ZAdaptiveGrid`, `ZItemActionsMenu`, `ZDiscardChangesGuard`, `ZToaster`, `ZcrudLabels`, `ZTagChips`, `ZTagEditor` | confirmés |

Les 6 symboles introuvables (`ZCrammingSessionEngine`, `ZContentOrder`, `ZLatexRasterizer`,
`ZRevealTransition`, `ZTimerDisplay`, `ZCardAdvanceBehavior`) sont **neufs par conception** — le
spine les annonce comme tels (`ZReviewMode (existant)` est d'ailleurs correctement marqué). Aucun
faux positif de mémoire.

### AD-33 — entièrement vérifié

- `ZStudySessionEngine({required List<ZSessionItem> queue, required ZSessionReviewer reviewer, ...})`
  — se construit bien **sur une file déjà résolue**, l'écriture SRS passe bien par le seam.
- `ZWhiteExamSessionEngine({queue, config, scorer})` — **aucun** paramètre reviewer/scheduler :
  l'invariant zéro-SRS est bien garanti **par le type**, gardé par `test/z_white_exam_no_srs_test.dart`.
- `reduceGrade` est bien un **réducteur pur top-level exporté**, et `ZSessionState` un value-object
  immuable. La rationale d'AD-34 sur la non-duplication tient donc techniquement.

### AD-41 — vérifié, et plus favorable que le memlog ne le dit

`cellSize` est **déjà configurable** : `ZMindmapViewConfig({this.cellSize = const Size(180, 72), ...})`
(`z_mindmap_view_config.dart:56`), passé à `defaultCellSize: widget.config.cellSize`
(`z_mindmap_view.dart:304`). Le mode compact court-circuite bien le builder pour ne garder que le
label brut (`z_mindmap_node_card.dart:96-102`). **Le spine est ici plus exact que son propre
memlog** (qui écrit « cellSize FIXE 180x72 » : c'est un *défaut*, pas une fixité). Rien à corriger.

### Versions — 6/7 exactes (pub.dev, 2026-07-16)

| Paquet | Dernière version réelle | Publiée | Verdict vs memlog |
|---|---|---|---|
| `flutter_card_swiper` | 7.2.0 | 2025-11-02 | ✅ exact |
| `confetti` | 0.8.0 | 2024-09-28 | ✅ exact (dormance ~22 mois, memlog disait 21) |
| `graphite` | 1.2.1 | 2025-03-28 | ✅ exact (dormance ~16 mois) |
| `flutter_math_fork` | 0.7.4 | 2025-05-21 | ✅ exact (dormance ~14 mois) |
| `flutter_tex` (plan B) | 5.2.7 | 2026-04-14 | ✅ exact |
| `syncfusion_flutter_pdf` | 34.1.31 | 2026-07-14 | ⚠️ voir F3 |
| `printing` | 5.15.0 | 2026-06-16 | ⚠️ voir F4 (jamais contrôlé par le memlog) |

Le constat de dormance qui motive le confinement en satellite (AD-1) est **réel et bien mesuré**.

---

## Findings

### F1 — HIGH — AD-34 repose sur une prémisse FAUSSE : le moteur cramming zéro-SRS existe déjà

**Le memlog affirme** (OA-4, ligne 24) : « `ZReviewMode.cramming` existe ; **cramming SANS moteur
dédié** », et (ligne 23) « ATTENTION : mode ne conditionne pas le reviewer dans
`ZStudySessionEngine` ». Toute la délibération OA-4 (reviewer no-op → révision en moteur dédié,
lignes 41 et 43) découle de ce constat.

**La réalité sur disque le contredit** :
`packages/zcrud_session/lib/src/domain/z_linear_session_state.dart` contient déjà
**`ZLinearSessionState`**, publiquement exporté (`lib/zcrud_session.dart:21`), qui est exactement le
moteur que AD-34 propose de créer :

- runtime **linéaire list/cramming** — cramming implémenté avec re-boucle des ratés à l'offset
  **+2/+4** selon la sévérité du lapse ;
- **aucun paramètre reviewer/scheduler/store** → *« il n'existe aucun seam/scheduler/store SRS à
  appeler (AD-23, **par construction**) »* (docstring, l. 131-133) — le zéro-SRS est **déjà garanti
  par le type**, exactement comme `ZWhiteExamSessionEngine` ;
- **assert** refusant les modes SRS : `mode == ZReviewMode.list || mode == ZReviewMode.cramming` ;
- `passThreshold` **injecté** depuis `ZSrsConfig` (jamais codé en dur) ;
- constantes de lapse **réutilisées** d'ES-4.2, jamais recopiées ;
- gardé par un test dédié **`test/z_linear_no_srs_test.dart`**, jumeau de `z_white_exam_no_srs_test.dart`.

**Conséquences** :
1. AD-34 tel qu'écrit ferait créer un **troisième runtime** (`ZCrammingSessionEngine`) qui
   **duplique** `ZLinearSessionState` — précisément la duplication qu'AD-34 dit éviter. Le débat
   « no-op vs moteur dédié » du memlog portait sur un **trou qui n'existe pas**.
2. La sous-affirmation d'AD-34 « il **réutilise** le réducteur pur `reduceGrade` » est également
   inexacte : cramming a déjà **son propre** réducteur pur, `reduceLinearGrade`
   (`z_linear_session_state.dart:71`) ; `reduceGrade` est le réducteur des modes **SRS**. Réutiliser
   `reduceGrade` pour cramming serait un contresens.

**Correction attendue** : AD-34 doit devenir une décision de **consolidation** (« cramming est servi
par le `ZLinearSessionState` **existant** ; aucun nouveau moteur ; aucun `ZSessionReviewer` no-op ne
sera fourni »), et non de création. La clause « aucun no-op fourni » reste juste et vaut d'être
gardée.

### F2 — HIGH — AD-34 laisse ouverte la porte dérobée qu'il prétend fermer

Vérifié : **`ZStudySessionEngine` n'a aucune garde sur `mode`** — ni assert, ni validation
(`z_study_session_engine.dart:123-135`). Sa signature accepte **n'importe quel** `ZReviewMode`
(y compris `cramming`, `list`, `test`, `whiteExam`) **avec un `reviewer` requis et réel**.

Donc `ZStudySessionEngine(queue: q, reviewer: vraiReviewer, mode: ZReviewMode.cramming)` reste
**parfaitement constructible et écrit le SRS**. Créer un moteur dédié ferme la porte d'entrée mais
**pas** celle-là. AD-34 revendique une garantie « par construction » qu'il n'établit qu'à moitié —
exactement le reproche (« invariant garanti par convention, pas par le type ») qu'il adresse à
l'option no-op.

**Correction attendue** : AD-34 doit **exiger la garde symétrique** dans `ZStudySessionEngine`
(assert `mode == spaced || mode == learn`, miroir de celui de `ZLinearSessionState`) — c'est ce qui
rend l'invariant vrai par le type, et c'est un ajout de 3 lignes.

### F3 — MEDIUM — Le memlog affirme un alignement de versions qui est faux pour Syncfusion

Le memlog (ligne 15) conclut la veille web par : « toutes = dernière version publiée, **^ du projet
aligné** ». C'est **faux pour Syncfusion** :

- réel sur disque : `packages/zcrud_export/pubspec.yaml:41` → `syncfusion_flutter_pdf: ^32.1.19`
  (et `syncfusion_flutter_xlsio: ^32.1.19`) ;
- réel sur pub.dev : **34.1.31** (publiée le **2026-07-14**, soit 2 jours avant le spine).

`^32.1.19` **ne peut pas** résoudre 34.x : le projet est **deux majeures en retard**, et la chaîne
`PdfBitmap`/`drawImage` d'AD-42 a été validée sur le web contre **34.1.31** alors que le projet
compile sur **32.x**. Le décalage n'est confronté nulle part.

Atténuation : `PdfBitmap` + `page.graphics.drawImage` sont **réellement utilisés** aujourd'hui en
32.x (`z_pdf_document_builder.dart:54-73`) — la primitive existe bien dans la version réellement
utilisée, donc AD-42 n'est pas invalidée. Seule l'affirmation d'alignement l'est.

**Correction attendue** : corriger la ligne de memlog, et acter explicitement que AD-42 vise
Syncfusion **32.x** (ou décider la montée de version, hors périmètre).

### F4 — MEDIUM — `printing` est la seule dépendance engagée jamais confrontée au réel

AD-42 crée un satellite `zcrud_export_ui` « (dépendance `printing`) ». **Le memlog ne contient
aucune ligne `(version)` pour `printing`** — c'est la seule dépendance nommée du spine à n'avoir
subi **aucun** contrôle d'existence, de version, de maintenance ou d'adéquation. Elle est engagée
depuis la mémoire.

**Contrôle effectué ici (pub.dev)** : `printing` **5.15.0**, publiée le **2026-06-16**, activement
maintenue, plugin sur **les 6 plateformes** (android, ios, linux, macos, web, windows). La décision
**tient** — mais elle tenait par chance, pas par vérification.

Deux points que le contrôle révèle et que AD-42 ne mentionne pas :

1. **`printing` tire `pdf: ^3.13.0`** — un **second moteur PDF complet**, rival de Syncfusion, dans
   le même arbre ; plus `image: >=4.1.0 <=5.0.0` (borne **haute fermée** — source classique de
   conflit de résolution futur), `ffi`, `http`, `web`, `pdf_widget_wrapper`. La formule « conséquence
   nulle pour qui ne l'importe pas » est vraie **pour le consommateur**, mais masque une vraie
   surface de maintenance et une seconde chaîne PDF pour le monorepo.
2. **Le PRD l'interdit nommément** : `prd.md:212` (« pas de nouvelle dépendance tierce **au-delà des
   deux décidées** ») et surtout `prd.md:226` (« pas de nouvelle dépendance **type `printing`** sans
   décision »). Le memlog **acte qu'il faut amender le PRD** (ligne 38) — mais **le spine ne le dit
   nulle part** : ni dans AD-42, ni dans `Deferred`. Le spine outrepasse silencieusement une
   contre-métrique du PRD qui cite le paquet par son nom.

**Correction attendue** : consigner dans AD-42 (ou `Deferred`) l'**obligation d'amender la
contre-métrique PRD**, et acter le second moteur PDF comme coût assumé.

### F5 — MEDIUM — « Insertion image OK » surestime ce que `zcrud_export` sait faire

Le memlog (OA-6, ligne 25) affirme : « `ZPdfCreationService.buildFromImages` + `PdfBitmap`/`drawImage`
**EXISTENT (insertion image OK)** », et conclut que le seul maillon manquant d'OA-1 est « le pont
LaTeX→image ». AD-42 s'appuie dessus.

**Réalité** : la seule API publique d'image du paquet est
`Uint8List buildFromImages(List<Uint8List> images, {ZPdfExportOptions? options})`
(`z_pdf_creation_service.dart:28`), documentée « **une image par page** », fit-to-page centré.
`drawImage` n'existe **que** dans `z_pdf_document_builder.dart` (non exporté — le barrel n'expose que
`ZExportApi`, `ZExportTable`, `ZExporter`, `ZFileSaveResult`, `ZFileSaver`, `ZPdfCreationService`,
`ZPdfExportOptions`/`ZPdfOrientation`).

Or FR-SU16 veut une **formule LaTeX rasterisée *dans* une page de flashcard**, mêlée au texte — pas
une page-par-image. **Aucune API de composition inline (texte + bitmap placé) n'existe ni n'est
exposée.** Le maillon manquant n'est donc pas seulement le pont LaTeX→image : c'est **aussi** une
API de composition PDF à créer. AD-42 est sous-dimensionnée, et son coût sous-estimé.

**Correction attendue** : AD-42 doit nommer les **deux** maillons manquants (rasterisation **et**
composition inline), sans quoi une story les découvrira en cours de route.

### F6 — HIGH — AD-40 : le graphe mermaid est faux, et l'invariant est déjà violé

Le graphe du spine représente `md -. "adaptateurs injectables (AD-40)" .-> flash` et
`md -. .-> mind` : arêtes **pointillées** (donc « injectable, pas de dépendance dure »), et
**orientées de `md` vers `flash`/`mind`**.

**Les pubspecs réels disent l'inverse** — ce sont des **dépendances dures**, en **sens opposé** :

- `packages/zcrud_flashcard/pubspec.yaml` → `zcrud_markdown: ^0.2.1` (utilisée dans
  `z_flashcard_api.dart:3`, arête AD-1 **déclarée** depuis E1-2 via `ZFlashcardApi.markdownApiVersion`) ;
- `packages/zcrud_mindmap/pubspec.yaml` → `zcrud_markdown: ^0.2.1` (`z_mindmap_api.dart:2`) ;
- `packages/zcrud_markdown/pubspec.yaml` → `flutter_quill: ^11.5.0` **et** `flutter_math_fork: ^0.7.4`.

Trois conséquences, aucune confrontée :

1. **Le « Prevents » d'AD-40 est déjà faux.** AD-40 dit prévenir « `zcrud_flashcard`/`zcrud_mindmap`
   qui tirent Quill ». Or **les deux tirent déjà Quill et `flutter_math_fork`**, transitivement, via
   leur dépendance dure à `zcrud_markdown`. AD-40 n'est pas un invariant à *préserver* mais un état à
   *établir* — ce qui suppose de **retirer** l'arête `zcrud_flashcard → zcrud_markdown` (et donc de
   casser une arête AD-1 déclarée en E1-2 + le marqueur `ZFlashcardApi.markdownApiVersion`). Ce
   travail de démolition n'est **cadré nulle part**.
2. **Risque de CYCLE AD-1.** AD-40 exige que « `zcrud_markdown` **fournit les adaptateurs prêts à
   injecter** … pour la carte de révision et l'éditeur outline ». Pour fabriquer un adaptateur de
   nœud, `zcrud_markdown` doit connaître `ZMindmapNode` → arête **`md → mind`**, alors que
   **`mind → md` existe déjà** ⇒ **cycle**, violation frontale d'AD-1 (CORE OUT=0 / graphe
   acyclique). Idem pour `md → flash`. Le spine engage une décision **structurellement
   irréalisable en l'état** sans avoir regardé le sens des arêtes.
3. **Le patron cité vit à l'autre bout.** AD-40 s'appuie sur le « patron
   `ZMindmapMarkdownContent.builder(slotKey:)` » comme s'il venait de `zcrud_markdown`. Il vit en
   réalité dans **`zcrud_mindmap`** (`z_mindmap_markdown_content.dart`), et sa propre docstring
   l'assume : *« L'arête `zcrud_mindmap → zcrud_markdown` **préexiste** (aucune nouvelle arête,
   AD-1) »*. Le modèle réel est donc « **le satellite héberge l'adaptateur mince et dépend de
   markdown** » — soit **l'exact inverse** de ce qu'AD-40 décide.

**Correction attendue** : soit AD-40 adopte le patron **réellement en vigueur** (l'adaptateur mince
vit dans le satellite consommateur, qui garde son arête vers `zcrud_markdown` — et alors le
« Prevents » doit être réécrit, car Quill *est* tiré), soit il assume un **plan de démolition**
explicite (retrait des arêtes dures + relogement des adaptateurs + preuve d'acyclicité). En l'état,
le graphe mermaid documente une architecture qui n'existe pas.

### F7 — LOW — `flutter_card_swiper` / `confetti` présentés comme « confinés », alors qu'ils sont absents

Le spine écrit : « `zcrud_session` (deps **confinées** `flutter_card_swiper`, `confetti`) ». Le
participe passé suggère un état acquis. Réalité :
`packages/zcrud_session/pubspec.yaml` ne déclare **aucune** dépendance tierce (uniquement
`flutter`, `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel`) ; `grep -rn "card_swiper\|confetti"`
sur tout le code et tous les pubspecs → **zéro occurrence**.

Ce sont donc **deux nouvelles dépendances à introduire**, ce que le PRD assume explicitement
(FR-SU6, FR-SU9, NFR-SU7 « confinés à ») — la décision est saine et les versions sont exactes, seule
la formulation induit en erreur. À reformuler au futur (« à confiner »).

### F8 — LOW — Petites imprécisions héritées, déjà tracées

- **Streak** : le spine corrige à juste titre le « remise à zéro » de `prd.md:78` en **reset à 1**.
  Le memlog note qu'il faut **amender le PRD** (ligne 36) ; le spine ne le rappelle pas. Sans trace,
  l'amendement se perdra.
- **AD-42 « sans dépendance de plateforme »** : `zcrud_export` a **déjà** des arêtes de plateforme
  (`z_file_saver_io.dart`/`z_file_saver_web.dart` → `dart:io`, `package:web` + `dart:js_interop`,
  `web: ^1.1.0` au pubspec). L'esprit (« bytes in / bytes out, pas de UI ») est juste ; la lettre est
  inexacte.

---

## Vérification des faits lex_douane / iffd

Investigation menée en **lecture seule** (aucune écriture dans les deux repos). Les 17 affirmations
du memlog présentées comme des « FAITS lex/iffd » ont été reprises une à une et confrontées au code.

### lex_douane — 9/9 CONFIRMÉS

Les faits lex du memlog sont **exacts, y compris dans le détail**. Ils ne sont manifestement pas des
souvenirs : chacun se retrouve au fichier et au symbole près.

| # | Fait | Verdict | Preuve |
|---|---|---|---|
| L1 | `FolderContentsOrder{folderId, Map<sectionKey, List<id>>}`, pas de `position` inline | ✅ | `packages/lex_core/lib/domain/entities/education/folder_contents_order.dart` + `static String sectionKey(kind, {subFolderId})` |
| L2 | Collection personnelle `users/{uid}/study_content_orders/{folderId}` | ✅ | `packages/lex_data/lib/data/repositories/study_content_order_repository_impl.dart` → `_orderRef()` |
| L3 | `applyOrder` pur (mémorisés d'abord, append stable, orphelins ignorés) | ✅ | même fichier que L1 — `result.addAll(remaining)`, `if (idx != -1)` |
| L4 | Drag **et** Monter/Descendre → voie unique `reorderSection` | ✅ | `study_content_order_provider.dart` (`moveItem` délègue à `reorderSection`) + `study_folder_screen.dart:1501` |
| L5 | Génération : requête/résultat, cartes éphémères, flux 2-phases | ✅ | `flashcard_generation_request.dart`, `flashcard_generation_result.dart`, `flashcard.dart:137` (`isEphemeral => id == null`), `flashcard_generation_controller.dart:193/276` |
| L6 | Éval `{…}` → `{feedback, suggestedQuality, isCorrect?}`, n'écrit jamais le SRS | ✅ | `answer_evaluation_request/result.dart` ; `education_generation_repository.dart:57` documente « `reviewCard` voie unique » |
| L7 | PDF `{bytes, suggestedFileName, mimeType}`, aucun `printing`, partage par seam | ✅ | `pdf_export_result.dart` ; `PdfShareSink`/`SystemPdfShareSink` ; `printing` absent de **tous** les pubspecs du repo |
| L8 | Dette : suppression d'une carte ne purge pas son `RepetitionInfo` | ✅ | `flashcards_repository_impl.dart:161` — soft-delete seul, zéro référence à `study_repetitions` |
| L9 | Répartition équitable pure `distributeTypes(count, types)` | ✅ | `flashcard_generation_sheet.dart:31` — `base = count ~/ types.length`, reste aux premiers |

**Deux nuances mineures**, sans effet sur les décisions :
- **L5** — la borne `1..50` observée est le **slider de l'UI** (`flashcard_generation_sheet.dart:485`) ;
  le VO ne ré-applique pas le clamp (« borné backend »). AD-37 dit « `count` **borné** » : bien voir
  que côté zcrud le clamp est donc **à créer dans le domaine**, pas à hériter.
- **L5** — « aucune source du backend » est vrai **au sens wire**, mais les cartes portent une
  `source` **injectée en couche data** depuis la requête. La formulation d'AD-37 (« ni id ni source
  du backend ») reste juste, à condition de ne pas en conclure que la carte n'a pas de `source`.

### iffd — 5/8 confirmés, 3 réserves

| # | Fait | Verdict |
|---|---|---|
| I1 | `evaluateFlashcardAnswer(...)` → score 1-5 texte brut, `int.tryParse` + borne | ⚠️ partiel |
| I2 | Repli déterministe QCM/VF 5\|1, ouvert/exercice 3, « je ne sais pas » → 1 sans IA | ⚠️ partiel |
| I3 | `generateFlashcardHint(...)`, stock local d'abord, indices générés non persistés | ✅ |
| I4 | Génération 3 modes, réponse JSON array (`jsonMode`) | ⚠️ partiel |
| I5 | Divergence des défauts + `showQuestionsTypesSelectionDialig` orphelin | ✅ |
| I6 | Purge = `batchDelete(where flashcardId)` en UN WriteBatch, « pas de lots de 10 » | ⚠️ voir F9 |
| I7 | Streak : jour civil local, idempotent, +1 ou reset à **1**, `listOnly` exclu, échec silencieux | ✅ |
| I8 | Purge fire-and-forget, exceptions avalées, `smartDelete` non await | ✅ |

Points **solidement confirmés** et structurants :
- **I5** — la divergence est réelle : défaut **modèle** `{multipleChoice:5, trueOrFalse:4, openQuestion:3, exercise:3}`
  (`ai_models.dart:262-267`) vs défaut **écran** `{openQuestion:5, multipleChoice:4, trueOrFalse:3, exercise:3}`
  (`flashcard_edition_screen.dart:586-592`). `showQuestionsTypesSelectionDialig` (orthographe exacte,
  `Dialig`) est déclaré à `flashcards_dialogs.dart:263` et c'est sa **seule occurrence du repo** :
  zéro site d'appel. **AD-37 « source unique » est donc pleinement justifiée.**
- **I7** — le streak est confirmé au détail près, y compris le **reset à 1 (jamais 0)**. La
  correction que le spine apporte au « remise à zéro » du PRD (`prd.md:78`) est **fondée**.
- **I8** — `smartDelete?.call(...)` non await dans une boucle synchrone
  (`firebase_crud_repository_impl.dart:401`), `catch (_) {}` à **trois** niveaux. **AD-39 (awaited +
  rapport d'échecs) corrige une dette réelle et bien identifiée.**

### F9 — MEDIUM — Le memlog « corrige un mythe » qui n'en était pas un

Le memlog affirme deux fois, en capitales, que la purge iffd se fait « en UN WriteBatch (**PAS de
lots de 10 — mythe corrigé**) », et discrédite un rapport antérieur.

**Vérifié** : l'affirmation n'est vraie que **strictement à l'intérieur de `batchDelete`**
(`firebase_crud_repository_impl.dart:381` — un seul `db.batch()`, une `query.get()`, un
`batch.commit()`, aucun chunking). **Mais un `const batchSize = 10;` existe réellement** une frame
au-dessus, à `folder_flashcards_list_page.dart:685` : il découpe la suppression **des flashcards**
(contrainte `whereIn` de Firestore, avec `Future.delayed(500ms)` entre lots) — et **c'est ce lot de
10 qui pilote les appels à la purge**. Le rapport antérieur visait très probablement cette ligne.

Le memlog a donc **sur-corrigé** : il a réfuté une observation exacte en la testant au mauvais
endroit, et a inscrit la réfutation comme un fait acquis. C'est le seul cas de la revue où une
vérification a produit une **régression de fidélité**.

**Impact sur AD-39** : la contrainte réelle qui force le chunking iffd n'est pas la limite d'écriture
(≤450, AD-21) mais la **limite `whereIn` = 10 de Firestore en lecture**. AD-39 (« cascade AD-21,
awaited, rapport par élément ») ne dit **rien** de cette contrainte de requête. Une story qui
implémente la suppression **par lot** (FR-SU19) la rencontrera.

### F10 — MEDIUM — AD-35 s'appuie sur une lecture inexacte du repli iffd

AD-35 décide : « **QCM/VF évalués localement** (déterministe, hors ligne), **jamais par le port** »,
et le memlog présente cela comme le comportement iffd (« repli déterministe : QCM/VF localement 5|1 »).

**Vérifié** : `_manualEvaluateAnswer()` **est un repli** (`catch`), **pas la voie normale** — dans
iffd, **QCM/VF passent d'abord par l'IA**, et le local ne s'applique qu'en cas d'échec IA ou de score
hors bornes. De même **I1** : `int.tryParse` n'est **pas suivi d'un clamp** mais d'un **test
d'appartenance** `if (aiScore != null && aiScore >= 1 && aiScore <= 5)` — hors bornes ⇒ **chute dans
le repli manuel**, pas de valeur bornée.

**Cela n'invalide pas AD-35** — évaluer QCM/VF localement est *meilleur* que ce que fait iffd, et
c'est un choix défendable. Mais AD-35 est présentée comme une **consolidation** de l'existant alors
qu'elle est une **rupture** avec le comportement iffd. Le « Prevents » (« divergence lex vs iffd »)
sous-estime l'ampleur : c'est un changement de comportement produit pour IFFD, à assumer comme tel.

Deux écarts d'échelle à trancher, non relevés par le spine :
- **échelles incompatibles** : iffd = **1..5**, lex et zcrud (`ZSrsConfig`) = **0..5**. AD-35 dit
  « suggestedQuality (échelle `ZSrsConfig`) » — donc **0..5**. Le prompt iffd ne couvre pas 0
  (`ai_prompt_generator.dart:570`) alors qu'un commentaire résiduel évoque encore
  « 0 - complete blackout » (l.546). La **conversion 1..5 → 0..5 est à la charge de l'adaptateur
  app-side** — à consigner, sinon un `1` iffd sera lu comme un `1` zcrud (deux sémantiques
  différentes).
- **AD-35 « repli QCM/VF exact → max sinon min »** : « max/min » de l'échelle **0..5** donne **5|0**,
  là où iffd fait **5|1**. Écart silencieux.

**Correction attendue** : AD-35 doit acter (a) qu'elle **rompt** avec le flux iffd, (b) la
conversion d'échelle 1..5 → 0..5 comme responsabilité d'adaptateur, (c) la valeur exacte du repli
bas (0 ou 1).

---

## Synthèse — qu'est-ce qui a été « affirmé de mémoire » ?

| Objet | Confronté au réel ? | Résultat |
|---|---|---|
| 21 symboles zcrud cités | ✅ oui (grep) | 21/21 exacts — aucun symbole halluciné |
| AD-33 (seams de session) | ✅ oui | intégralement corroboré |
| AD-39 (cascade) | ✅ oui | `ZCascadeEdge`/`ZCascadeRegistry`/`ZCascadeReport` existent ; dette lex/iffd réelle |
| AD-41 (cellule graphe) | ✅ oui | corroboré, et plus favorable que le memlog |
| Faits lex_douane (9) | ✅ oui | 9/9 exacts |
| Faits iffd (8) | ⚠️ partiellement | 5/8 ; 3 réserves (F9, F10) |
| Versions de 6 paquets | ✅ oui (pub.dev) | exactes |
| **`printing`** | ❌ **non** | **engagé sans aucun contrôle** (F4) — vérifié OK *a posteriori* ici |
| **Version Syncfusion du projet** | ❌ **non** | « ^ aligné » **faux** : ^32.1.19 vs 34.1.31 (F3) |
| **AD-34 (état du code cramming)** | ❌ **non** | **`ZLinearSessionState` manqué** (F1, F2) |
| **AD-40 (sens des arêtes)** | ❌ **non** | **arêtes inversées, invariant déjà violé, cycle** (F6) |
| **AD-42 (surface d'export réelle)** | ⚠️ partiellement | primitive vue, mais API de composition manquante (F5) |

**Le pattern** : tout ce qui a été **explicitement investigué** (OA-1..OA-6, faits lex, versions web)
est solide — le travail d'investigation est de bonne qualité. Les erreurs se concentrent **là où le
memlog a conclu à une absence** (« cramming SANS moteur dédié », « pas d'adaptateur ailleurs ») :
**une absence n'a jamais été vérifiée par un grep négatif**. Deux fichiers existants
(`z_linear_session_state.dart`, les arêtes `pubspec` vers `zcrud_markdown`) suffisent à invalider
deux décisions engagées.

## Recommandation

**Ne pas figer le spine en l'état.** Corrections requises avant adoption :

1. **AD-34** → réécrire en décision de *consolidation* sur `ZLinearSessionState` (F1) + **exiger la
   garde symétrique** `assert(mode == spaced || mode == learn)` dans `ZStudySessionEngine` (F2).
2. **AD-40** → trancher entre patron réel (adaptateur mince dans le satellite) et plan de démolition
   explicite ; **corriger le graphe mermaid** (sens des arêtes, arêtes dures vs pointillées, ajout de
   `zcrud_ui_kit`/`zcrud_responsive`/`zcrud_exam` — voir F6) ; **prouver l'acyclicité** avant
   d'engager « `zcrud_markdown` fournit les adaptateurs ».
3. **AD-42** → nommer les **deux** maillons manquants (F5) ; acter Syncfusion **32.x** (F3) ; acter
   `printing` + son second moteur PDF + **l'amendement de la contre-métrique PRD** `prd.md:212/226` (F4).
4. **AD-35** → acter la rupture avec iffd, la conversion d'échelle 1..5 → 0..5, la valeur du repli bas (F10).
5. **Memlog** → corriger la ligne « ^ du projet aligné » (F3), la ligne « mythe des lots de 10 » (F9),
   les lignes OA-4 (F1) et « cellSize FIXE » ; tracer les **deux amendements PRD** dus (streak, `printing`).
