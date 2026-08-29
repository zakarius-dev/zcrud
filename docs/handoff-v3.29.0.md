# Handoff v3.29.0 — le kernel pédagogique universel, et les chaînes qui se complètent

> **Date** : 2026-08-28. **Portée** : `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_session`,
> `zcrud_ui_kit`, `zcrud_note`, `zcrud_core`. **Plan** : Partie III, Vague 0 bis (structure d'étude
> universelle, décision du propriétaire) + Vague 1 (chaînes complètes) + premier lot d'apparence.
> _(en cours de rédaction — complété lot par lot)_

## 1. Pourquoi cette vague

Deux décisions du propriétaire structurent cette livraison. (1) **Le legacy est le défaut** : le
socle rend, sans configuration, l'apparence d'IFFD — palette signature cyclée, bandes d'accent,
tuiles d'icône — avec une échappatoire unique `referenceProfile: neutral`. (2) **Un kernel
pédagogique universel** : plutôt qu'une hiérarchie figée école › filière › classe, le socle porte
des entités aux responsabilités distinctes (organisation, programme, groupe, matière, cours,
offering, période, curriculum, topic…) partageant un même protocole (référençables, scopables,
liables, filtrables, archivables) — le vocabulaire institutionnel reste une donnée de l'hôte.

## 2. Ce que le socle livre

| Lot | Paquet | Livré |
|---|---|---|
| **P1-A** | `zcrud_flashcard` | `ZEaseFactorAdjustment` — stratégie d'ajustement du facteur de facilité sur `ZSrsConfig.easeFactorAdjustment` : `canonical()` (formule SM-2 inchangée, **120 vecteurs à l'égalité exacte**) ou `table({deltaByQuality, penalizeLapse})` (delta additif par qualité, lapse sans pénalité optionnel — la table est une donnée de l'hôte) ; `ZSrsConfig.neutralQuality` (clampé) + `effectiveNeutralQuality` (`?? passThreshold`) ; les bandes de niveau existaient déjà (`ZMasteryLevel`), rien de doublé |
| **P1-B** | `zcrud_session` | `ZSessionCardSwiper.preserveIndexOnMutation` ; 5ᵉ seau `ZFlashcardSubmission.skipped` / `ZFeedbackTier.skipped` (opt-in `markSkippedSubmissions` sur « je ne sais pas » ; les quatre comptes existants intacts) ; `ZTestFiltersDialog.availableSourceIds` — **et correction d'une perte de donnée** : le dialogue effaçait `sourceIds` à chaque aller-retour ; `ZLapseRequeuePolicy(offsetSevere, offsetLight, severeMaxQuality)` injectable, défauts = constantes historiques |
| **P1-B-bis** | `zcrud_session` | `ZSessionCardSwiper.onSwipeDirection(index, ZSwipeDirection.start\|end)` — une fois par geste, index de la carte chassée, **avant** `onIndexChanged`, direction logique résolue contre `TextDirection` ; le swipe **ne note toujours pas** (FR-SU6/AD-33, garde de source inchangée à l'octet) : l'hôte mappe la direction chez lui. Le bouton accessible « carte suivante » et `indexController` **n'émettent pas** de direction — relayer aurait attribué une note silencieuse, inversée sous RTL, au seul utilisateur de lecteur d'écran |
| **P0-E** | `zcrud_study` | **le manque B1 est comblé** : `ZMindmapGenerationController` (miroir du contrôleur flashcards : `idle → generating → reviewing | empty | failed`, `Left` ⇒ échec typé sans levée, `Right([])` ⇒ `empty` distinct, anti-double-soumission), `ZMindmapGenerationSheet` (sources, instructions, « résumer », revue dans `ZMindmapOutlineEditor`, validation ⇒ `ZMindmap` remis à `onGenerated` — la voie exacte des flashcards), `ZStudyMindmapSection.generationPort/onGenerate` (action absente sans câblage complet, jamais grisée), `ZMindmapGenerationRequest.summarize/routeId` (route opaque verbatim) ; les nœuds **édités** en revue sont ceux persistés |
| **P0-F** | `zcrud_study` | **le manque B2 est comblé** : `ZNoteSummaryController` (miroir du contrôleur mindmap), `ZNoteSummarySheet`/`ZNoteSummaryScope` (revue en texte brut + slot `summaryBuilder` injecté — `zcrud_markdown` n'est pas une dépendance, garde AD-1 à l'appui ; deux issues `onInsertAtTop`/`onCreateNote`, le socle ne persiste rien), action « résumer » sur `ZDefaultNoteCard` (port + callback + libellé requis, sinon absente) ; texte remis **exact à l'octet** ; `ZNoteSummaryRequest` ne porte pas de `routeId` (constat) — l'acheminement par route viendra de l'adaptateur `zcrud_chat_study` (P1-F) |
| **P1-C** | `zcrud_session` | `ZWhiteExamVerdict {passed, ratio, correct, total}` + `zWhiteExamVerdictFor` pure (seuil borné [0,1], `NaN` ⇒ aucun verdict, `total == 0` ⇒ 0, comparaison large) ; `ZWhiteExamSessionEngine(successRatio:)` (défaut `null` = aucun verdict — **le seuil de 70 % est une donnée de l'hôte, jamais un littéral du socle**), `verdict` dérivé, relayé jusqu'à `ZSessionSummaryView.verdict` : réussite ⇒ célébration existante (jetons `celebrationDuration`/`celebrationCurve`, couleurs signature sous `legacy`, rôles M3 sous `neutral`) ; échec ⇒ aucune célébration, libellé l10n |
| **P2-B** | `zcrud_ui_kit` | `ZEmptyState` lit `ZEmptyStateStyle` (+ `illustration`, `iconSize`, `compact`, `ZEmptyStateSpec`/`fromSpec` — aucune nature de contenu nommée) ; `showZConfirmDialog` lit `ZConfirmDialogStyle` (+ `icon`, `content`, `barrierDismissible` ; destructif par `ZConfirmTone`) ; `ZSkeleton.line/box/tile`, `ZSkeletonList` (rôles M3, `ZColorCycle`, `ExcludeSemantics`, aucune dépendance) |
| **P2-E** | `zcrud_note` | `ZNoteAudioPlayer` sur `ZAudioPlaybackPort` (lecture/pause, position, seek, échec sans levée, port jamais disposé, rebuild granulaire) ; `ZSmartNoteReader.audioPort` / `ZSmartNoteEditor.audioPort` — monté seulement si port disponible **et** source typée |
| **Apparence A** | `zcrud_core` | `ZReferenceProfile { legacy, neutral }` + jeton `referenceProfile` (défaut `legacy`) + `zLegacyOr`/`zLegacyOrIn` (couleurs, dernier maillon) ; **`z_signature_palette_reference.dart`**, unique fichier de référence de la famille, exempté nominativement : `gradients` (5), `deepGradients` (5), `mutedGradients` (5), `subjectGradients` (8) — 18 dégradés distincts, 36 hex, chacun cité `fichier:ligne` du legacy, `onGradient` **mesuré** par contraste ; jetons `signaturePalette`, `signaturePaletteIndexStrategy` (`titleHash` = fidélité, `ordinal`, `stableFnv` — stable entre plateformes), `sectionHeaderAccentHeight` (3), `sectionHeaderIconTileSize` (36), `sectionHeaderIconTileRadius` (10) ; `zSignatureGradientFor`/`zPaletteIndexFor` purs ; `zResolveGradient` gagne le maillon `zcrud.signature.*` (les préfixes `fieldType`/`fieldAccent` restent seam-only) ; `_SectionHeader`/`_CollapsibleSectionHeader` rendent bande + tuile |
| **Apparence B** | `zcrud_ui_kit` | app bar **teintée par défaut** sur toute page à titre `String` : lavis vertical de la teinte signature (rampe 0.15/0.10/0.05/0.02 — le vécu du legacy, remesuré : 66/67 app bars sans dégradé plein), élévation 0, premier plan posé **seulement si** l'ambiant tient 4.5:1 ; `signatureKey` additif, priorité `gradientKey` > `signatureKey` > titre ; `ZPageShellReference` (0 couleur) ; `ZGradientFab` (rayon 20, ombre teintée, sans dégradé ⇒ FAB Material nu) ; `ZChoiceChipStyle`/`zChipThemeFor`. Échappatoires prouvées par égalité d'arbre : `referenceProfile: neutral`, `gradientKey: ''`, titre `Widget` |
| **Apparence E** | `zcrud_document` | `z_annotation_palette_reference.dart` — seul fichier couleur du paquet, exempté par chemin exact : palette d'annotation du legacy remesurée (**40 teintes + 7 compactes**, pas « 20+ »), `onColor` mesuré (plancher 4.58:1) ; `z_document_viewer_reference.dart` (géométrie seule, 0 couleur, non exempté) ; chaîne `zResolveAnnotationColor` (paramètre → hôte/rôles → référence sous `legacy`) ; 6 paramètres additifs. AD-13 : les 56/40 dp du legacy sont **sous** le plancher — appliqués en minimum (pastille peinte 40 dans une cible de 48). **Rupture voulue** sous profil par défaut (4 clés de `ZColorPalette.defaultStudy()` changent, pastille 48→40 peinte, glyphe 24→20) ; échappatoire `referenceProfile: neutral` prouvée par égalité d'arbre ; hôte au résolveur maison : sa compensation **prime**, rien à faire |
| **P1-S** | `zcrud_core` | `ZcrudScope extends InheritedTheme` (`wrap` re-pose le **même** bundle, identité des seams préservée, `updateShouldNotify` inchangé) : `showDialog`/`showModalBottomSheet`/`showMenu`/`showDatePicker`/`showTimePicker` capturent d'eux-mêmes les `InheritedTheme` ; la seule route nue du paquet (forme `page` du formulaire d'item de sous-liste) perd sa compensation interne au profit de `InheritedTheme.capture` + `wrap` |
| **P0b-A1** | `zcrud_study_kernel` | `lib/src/domain/structure/` — primitives transversales (`ZStudyRef` snapshot, `ZExternalRef`, `ZStudyBinding` à propagation, `ZStudyRelation`, protocole `ZStudyArtifact`), tenancy (`ZStudyWorkspace`, `ZStudyPrincipal`, `ZStudyOrganization`, `ZStudyOrgUnit`), structure (`ZStudyProgram`, `ZStudyGroup`, `ZStudyVocabulary`, `ZStudyClassification` historisée), catalogue (`ZStudySubject`, `ZStudyCourse`, `ZStudyProgramCourse` — le coefficient vit sur la relation), temps (`ZStudyCalendar`, `ZStudyPeriod`, `ZStudySession`), ontologie en données (`ZStudyOntology`, `ZStudyKindSpec` à **capabilities**, règles de contenance, `zHasCapability`/`zValidatePlacement`/`zValidateVocabularyUse` — ontologie absente ⇒ tout est permis), cinq préréglages (`lyceeFr`, `universiteLmd`, `formationPro`, `primaire`, `personnel` : seul fichier autorisé à nommer un contexte), projections `zRecomputeAncestorIds`/`zDepthOf`, `ZStudyScopeFilter`. Tout vocabulaire est opaque et survit au round-trip ; `ZStudyFolder` inchangé à l'octet |
| **P0b-A2** | `zcrud_study_kernel` | enseignement réel (`ZStudyOffering` à statut opaque — **sans `unitId` ni `teacherId`**, `ZStudyOfferingAudience` many-to-many, `ZStudyParticipation` unifiant adhésion/inscription/staff), contenu pédagogique (`ZStudyCurriculum` versionné, `ZStudyTopic` arborescent, référentiel de compétences en **graphe** — `zDetectCycle` refuse un cycle de `prerequisite`/`contains`, admet `related`), `ZStudyFolder` porteur du protocole `ZStudyArtifact` (`ownerRef`, `primaryScopeRef`, `bindings` — clés non émises quand vides : map inchangé), `ZStudyExplanation`, faits de sécurité (`ZStudyRoleBinding`, `ZStudyShareGrant` — jamais des droits : l'autorisation reste hôte via `ZActionKey`), `ZStudyContext` + résolveur **pur** sur snapshot (5 scénarios figés : lycée, LMD, bootcamp, primaire, personnel), `zIsVisibleFrom` (propagation calculée, jamais dupliquée), 3 ports + inertes. Défaut réel corrigé au passage : `ZStudyRef.fromMap` confondait absence et chaîne vide (round-trip non inverse) |

## 3. Ce qui change pour un hôte

**Hôte passif : rien** pour P1-A (résultats SRS identiques, contrat gelé inchangé à l'octet), P1-B,
P2-B, P2-E — prouvé par des gardes d'inertie à égalité stricte.

🔴 **Apparence A — RUPTURE VOULUE, pour tout hôte, passif compris** (décision du propriétaire : le
legacy est le défaut). Les en-têtes de section de `DynamicEdition` (`_SectionHeader`,
`_CollapsibleSectionHeader`, chemin natif **et** stylé) gagnent une **bande d'accent de 3 dp**
colorée par la palette signature indexée sur le titre ; une section à icône gagne une **tuile
36 × 36, rayon 10**. Hauteurs mesurées : **44 → 47 dp** sans icône, **48 → 63 dp** avec.
`zResolveGradient('zcrud.signature.<clé>')` rend désormais un dégradé sans seam.
**Échappatoire unique, prouvée par égalité stricte de l'arbre complet sur trois largeurs** :
`ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.neutral))` — rendu identique à
v3.28.0. Lex, DODLP, DLCFTI : poser ce jeton à la racine s'ils ne veulent pas de la bande ; ou
poser `signaturePalette:` pour leur propre palette. `String.hashCode` n'étant pas stable entre
plateformes, un hôte qui exige la même couleur partout choisit `signaturePaletteIndexStrategy:
ZPaletteIndexStrategy.stableFnv` (fidélité au legacy = `titleHash`, défaut).
**IFFD compensait** : cinq dégradés recopiés dans 18 fichiers et `MyStickyHeader` réimplémentant
bande et tuile — à **retirer** (double bande et deux sources de vérité sinon).

**Hôte ayant compensé** :
- avait implémenté son propre `ZSrsScheduler` pour une table d'ajustement d'EF → peut revenir au
  socle avec `ZEaseFactorAdjustment.table(...)` ;
- enveloppait `ZEmptyState` pour poser une illustration → deux visuels s'il passe aussi `icon:` ;
  déplacer l'image dans `illustration:` et retirer l'enveloppe ;
- superposait son propre lecteur audio à une note → deux lecteurs dès qu'il passe `audioPort`, sur
  le lecteur **et** l'éditeur ;
- ⚠️ `ZFeedbackTier` gagne une valeur : un `switch` exhaustif sans `default` casse (aucun hôte n'en
  a aujourd'hui, grep sur les quatre dépôts).

**Défaut transversal découvert (P2-B), non corrigé dans cette vague** : `ZcrudScope` est un
`InheritedWidget` ordinaire — un dialogue, une feuille ou un menu **poussés** sous un scope ne
voient ni ses jetons, ni ses libellés, ni ses seams (seuls les `ThemeData.extensions` passent).
`showZConfirmDialog` transporte désormais son style au point d'appel, **et** P1-S corrige la cause :
`ZcrudScope` est un `InheritedTheme`. Conséquence pour un hôte : dans une route poussée, le scope
devient visible — donc **l'ACL réelle de l'hôte s'y applique enfin** là où `ZDenyAllAcl` masquait
des gestes par accident (un dialogue qui montrait « accès refusé » sans raison les retrouve). Un
hôte qui **re-posait un `ZcrudScope` identique** dans ses dialogues peut le retirer sans danger ;
s'il re-posait un scope **différent** (ACL plus restrictive), il le garde. Hors du socle,
`zcrud_geo/z_geo_field_widget.dart` et `zcrud_navigation/{z_adaptive_presenter,z_edition_presentation}.dart`
poussent encore une route nue — lots suivants.

## 4. Vérification

Rejouée par l'orchestrateur, tous les lots au repos, chaque paquet depuis son dossier.

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_study_kernel` (`dart test` ; `-p node` : 661) | 407 | **698** (analyze 3 infos préexistantes) |
| `zcrud_study` | 1 563 | **1 621** (analyze 71 infos, 70 préexistantes + 1 du patron miroir) |
| `zcrud_flashcard` | 594 | **621** (analyze 16 infos préexistantes ; `hide` 41 → 210 entrées) |
| `zcrud_session` | 595 | **652** (analyze 44 infos préexistantes) |
| `zcrud_ui_kit` | 232 | **318** (analyze 0) |
| `zcrud_note` | 173 | **197** (analyze 0) |
| `zcrud_document` | 292 | **330** (analyze 11 infos préexistantes) |
| `zcrud_core` | 2 586 | **2 655** (analyze 13 infos préexistantes) |
| `tool/reserved_keys_gate` | 133 | **248** (23 kinds neufs câblés, 40/40, 78 voies d'écriture sondées) |

| Contrôle | Résultat |
|---|---|
| `melos run generate` | SUCCESS — 0 `.g.dart` résiduel, codegen du kernel idempotent |
| `melos run analyze` repo-wide | **RC=0** (4 `info` préexistants) |
| `melos run verify` (12 gates) | **RC=0** — `reserved-keys` : 104 violations à l'arrivée du modèle de structure, toutes sondées |
| Balayage des 41 paquets, chacun depuis son dossier | **40 verts** (dont `zcrud_screen` 390 après re-figement de l'étalon P2-C — rompu par la rupture **voulue** d'Apparence B, pas par une régression : le tripwire a fait son travail) ; `zcrud_generator` rouge **environnemental** de signature inchangée (`Isolate.packageConfig`) |
| `melos run verify` après bump (41 pubspecs, `^3.29.0`, `tool/*`, recette 47 `ref: v3.29.0`) | **RC=0** |
| Résidus d'injection R3 | **0** marqueur dans `packages/*/{lib,test}` et `tool/*/lib` |

Discipline R3 tenue sur chaque garde (rouge par assertion, restauration par copie, sha256, grep
négatif). Incidents de la vague, tous absorbés par les règles en place : un redémarrage de session
a fauché cinq agents et **purgé le scratchpad** (deux injections résiduelles retirées par retrait
ciblé à motif asserté ; ce handoff, écrit tôt, est la trace qui a survécu) ; six gardes ont été
trouvées **faibles par leur propre R3** et réécrites avant livraison (empreinte aveugle au contenu,
inertie tautologique, plancher mesurant le SDK, ancrage sur la mauvaise tête de palette,
contre-preuve fausse, sonde SM-1 posée dans `State.build`) ; le scan de surface de
`zcrud_flashcard` ignorait les exports **multi-lignes** du kernel (24 symboles pouvaient fuiter
sans classement) — corrigé et méta-gardé ; la garde d'inertie du dossier s'est révélée
insuffisante seule (une inertie parfaite se satisfait en n'émettant jamais rien) — complétée par
sa garde symétrique d'émission.
