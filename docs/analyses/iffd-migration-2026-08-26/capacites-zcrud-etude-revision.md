# Ce que le socle zcrud SAIT FAIRE aujourd'hui — aire « Étude et révision »

**Mesuré le 2026-08-26** sur `/home/zakarius/DEV/zcrud` à `cc276c154` (tag `v3.21.0`).
Référence commune pour les onze agents de confrontation.

**Méthode** — pour chaque paquet : lecture du barrel `lib/<paquet>.dart` (l'API publique
**est** ce qu'il exporte), du `CHANGELOG.md`, puis extraction machine des déclarations
publiques de niveau supérieur de chaque fichier réellement exporté. Comptage des
paramètres déclarables par lecture du constructeur. Croisement avec l'hôte par
concaténation des `lib/**.dart` d'IFFD qui importent un `package:zcrud_*`, puis
appartenance lexicale du symbole à ce corpus.

**Limite de la mesure, à connaître avant de s'en servir** : « cité par IFFD » est une
correspondance **lexicale**, pas une analyse de flot. Elle compte une occurrence en
commentaire comme un usage ⇒ elle **surestime** l'usage. Donc la colonne « jamais cité »
est un **minorant sûr** du non-câblé : un canal listé comme jamais cité ne l'est
réellement nulle part, pas même en commentaire.

---

## 0. Le chiffre qui commande tout le reste

| | |
|---|---|
| Paquets du périmètre | **8** |
| Fichiers `lib/**.dart` | **215** (27 941 + 6 234 + 7 246 + 8 462 + 1 075 + 2 052 + 3 885 + 729 = **57 624 lignes**) |
| Fichiers réellement exportés par les barrels | **191** |
| **Canaux publics de niveau supérieur** | **423** |
| Cités quelque part dans IFFD | **75** |
| **Jamais cités par IFFD** | **348 — soit 82 %** |
| Jetons de thème `ZcrudTheme` du bloc « étude » (l. 425-500) | **76** (+ 21 partagés carte/pastille/accent, l. 404-424) |
| Jetons d'étude effectivement posés par IFFD | **≈ 18** |

Détail par paquet :

| Paquet | version | fichiers `lib/` | lignes | canaux publics | cités par IFFD | **jamais cités** |
|---|---|---|---|---|---|---|
| `zcrud_study` | 3.21.0 | 75 | 27 941 | 189 | 41 | **148** |
| `zcrud_study_kernel` | 3.21.0 | 37 | 6 234 | 44 | 4 | **40** |
| `zcrud_flashcard` | 3.21.0 | 39 | 7 246 | 68 | 10 | **58** |
| `zcrud_session` | 3.21.0 | 28 | 8 462 | 68 | 5 | **63** |
| `zcrud_exam` | 3.21.0 | 5 | 1 075 | 4 | 3 | **1** |
| `zcrud_note` | 3.21.0 | 10 | 2 052 | 11 | 2 | **9** |
| `zcrud_mindmap` | 3.21.0 | 16 | 3 885 | 26 | 10 | **16** |
| `zcrud_chat_study` | 3.21.0 | 5 | 729 | 13 | **0** | **13** |
| **Total** | | **215** | **57 624** | **423** | **75** | **348** |

`zcrud_chat_study` n'est **déclaré nulle part** chez l'hôte — grep négatif montré :

```
$ cd /home/zakarius/DEV/iffd && grep -n 'zcrud_chat_study' pubspec.yaml ; echo "RC=$?"
RC=1
$ grep -rn 'zcrud_chat_study' lib | wc -l
0
$ grep -rn 'zcrud_chat_study' docs | wc -l
17          # cité 17 fois en documentation, jamais en code, jamais en dépendance
```

---

## 1. 🔴 Une prémisse du brief est FAUSSE, et il faut le savoir avant de lire la suite

Le brief annonce : « beaucoup de canaux ont été livrés entre le 13 et le 25 août
(versions 3.13 → 3.21) : ils sont RÉCENTS et souvent inconnus de l'hôte ».

**Mesuré : pour cette aire, c'est l'inverse. Zéro fichier des huit paquets n'a bougé
entre `v3.12.0` et `v3.21.0`.**

```
$ git diff --name-only v3.12.0 v3.21.0 | wc -l
287
$ git diff --name-only v3.12.0 v3.21.0 | grep '/lib/' | awk -F/ '{print $2}' | sort | uniq -c | sort -rn
     24 zcrud_core
      8 zcrud_markdown
      4 zcrud_select
      4 zcrud_responsive
      1 zcrud_screen
      1 zcrud_reorder
$ git diff --stat v3.12.0 v3.21.0 -- packages/zcrud_study packages/zcrud_study_kernel \
    packages/zcrud_flashcard packages/zcrud_session packages/zcrud_exam \
    packages/zcrud_note packages/zcrud_mindmap packages/zcrud_chat_study
 packages/zcrud_chat_study/pubspec.yaml   | 12 +++---
 packages/zcrud_exam/pubspec.yaml         |  8 ++--
 packages/zcrud_flashcard/pubspec.yaml    | 12 +++---
 packages/zcrud_mindmap/pubspec.yaml      |  6 +--
 packages/zcrud_note/pubspec.yaml         | 10 ++---
 packages/zcrud_session/pubspec.yaml      | 10 ++---
 packages/zcrud_study/pubspec.yaml        | 22 +++++-----
 packages/zcrud_study_kernel/pubspec.yaml |  8 ++--
 8 files changed, 44 insertions(+), 44 deletions(-)   # QUE des bumps de version
```

La vague 3.13 → 3.21 est **entièrement une vague « formulaires d'édition »** (CR-IFFD-92
à 112 : `zcrud_core`, `zcrud_markdown`, `zcrud_select`, `zcrud_responsive`). Elle n'a
rien livré dans l'aire Étude.

**Et l'hôte est déjà sur `v3.21.0`** — `iffd/pubspec.yaml:308` et suivants, `ref: v3.21.0`
pour les 25 entrées `zcrud_*` ; `pubspec.lock:3489` `resolved-ref: cc276c15417919…`.

⇒ **« Inconnu de l'hôte » ne veut donc PAS dire « pas encore publié ». Ça veut dire
« publié, résolu dans son `pubspec.lock`, compilé dans son binaire — et jamais appelé ».**
C'est la lecture qui rend les 348 canaux exploitables : ils sont **disponibles tout de
suite, sans montée de tag**. La section 9 les rejoue avec les dates réelles de livraison.

### Quand l'aire Étude a réellement bougé (mesure par tag)

```
v3.0.0 (2026-08-20)  3 fichiers  — trois CR IFFD, et une régression que nous avions livrée
v3.1.0 (2026-08-20)  3 fichiers  — la marge de personnalisation rendue infaillible
v3.2.0 (2026-08-21)  1 fichier   — CR-IFFD-83/84, et un défaut plus large trouvé en chemin
v3.3.0 (2026-08-21) 38 fichiers  — remontée de zReadableTint au cœur + dette documentaire
v3.6.0 (2026-08-23)  1 fichier   — octet NUL dans un littéral
   (aucun autre tag jusqu'à v3.21.0 n'a touché un fichier de ces huit paquets)
```

Avant cela, le gros de l'aire a été livré du **2026-08-03 au 2026-08-12** (`v0.34.0` →
`v0.88.0`), point culminant `v0.54.0` (2026-08-06, 20 fichiers, « le domaine étude remonte
dans le socle ») et `v0.87.0` (2026-08-12, 212 fichiers, documentation).

⚠️ **Les `CHANGELOG.md` des paquets ne servent presque à rien ici.** Sept des huit sont
figés sur « [0.86.0] / [Non publié] — Chantier documentation » (29 à 35 lignes chacun) ;
seul `zcrud_study/CHANGELOG.md` porte des entrées 3.x (155 lignes, jusqu'à 3.6.0). La
matière récente vit dans `docs/handoff-v3.*.md`, pas dans les CHANGELOGs.

---

## 2. `zcrud_study` — la présentation d'étude (189 canaux, 41 cités, **148 jamais cités**)

### 2.1 Seams IA neutres (domaine) — **7 ports, AUCUN cité par IFFD**

Ports `abstract interface class` rendant `Either<ZFailure, T>`, sans SDK IA, prompt,
endpoint ni clé en surface (AD-12).

| Canal | fichier:ligne | Un hôte qui veut… écrit… | Défaut |
|---|---|---|---|
| `ZFlashcardGenerationPort` | `z_flashcard_generation_port.dart:289` | …générer des cartes par IA : implémente le port, l'injecte, et toute la chaîne UI s'allume | aucun — sans port, l'UI de génération est **structurellement absente** |
| `ZFlashcardGenerationRequest` | `z_flashcard_generation_port.dart:113` | …décrire la demande (source, compte, répartition par type, `extra`) | — |
| `ZResolvedGenerationSource` | `z_flashcard_generation_port.dart:43` | …résoudre une source (note/doc/conversation) en texte | — |
| `ZGenerationSourceResolver` | `z_flashcard_generation_port.dart:98` | …brancher sa propre résolution de source | — |
| `ZAiExplanationPort` | `z_ai_explanation_port.dart:67` | …demander une explication IA d'un contenu | — |
| `ZNoteSummaryPort` | `z_note_summary_port.dart:68` | …résumer une note | — |
| `ZMindmapGenerationPort` | `z_mindmap_generation_port.dart:189` | …générer une **forêt éphémère** de `ZMindmapNode` (jamais un `ZMindmap` persisté) | — |
| `ZPodcastGenerationPort` | `z_podcast_generation_port.dart:131` | …générer un podcast adressé par contenu (`sourceHash` **fourni par l'appelant**) | aucun hachage dans le domaine |
| `ZEducationQuotaInfo` | `z_education_quota_info.dart:20` | …exposer un quota/plan à l'UI de génération | — |

Défauts purs de génération, source unique jamais dupliquée dans un widget :
`zDefaultGenerationCount = 10` (`z_flashcard_generation_defaults.dart:30`),
`zClampGenerationCount` bornes `[1, 50]` (l. 39), `zEvenTypesDistribution` (l. 55),
`zNormalizeTypesDistribution` (l. 97). **Aucun des quatre n'est cité par IFFD.**

### 2.2 Partage communautaire et modération — **8 canaux, AUCUN cité**

| Canal | fichier:ligne | Ce qu'il permet |
|---|---|---|
| `ZStudySharingPort` | `z_study_sharing_port.dart:37` | port neutre de partage de dossier |
| `ZStudyModerationPort` | `z_study_moderation_port.dart:28` | port neutre de modération/signalement |
| `ZStudySharingAcl` | `z_study_sharing_acl.dart:43` | garde ACL **pure** (aucun backend) |
| `ZStudySharingExtension` | `z_study_sharing_extension.dart:39` | extension concrète opt-in à injecter comme `extensionParser` |
| `ZShareLink` | `z_share_link.dart:23` | lien de partage **révocable** |
| `ZStudyMembership` / `ZMembershipRole` | `z_study_membership.dart:51` / `:22` | appartenance et rôle |
| `ZPublicStudyFolder` | `z_public_study_folder.dart:16` | dossier publié |
| `ZStudyFolderReport` / `ZReportStatus` | `z_study_folder_report.dart:43` / `:15` | signalement et son cycle |

Invariant tenu : **aucun état personnel** (SRS, ordre, lecture) n'y transite jamais.

### 2.3 Assemblages d'écran — le gros morceau

| Canal | fichier:ligne | params | Un hôte qui veut… | Cité IFFD |
|---|---|---|---|---|
| `ZStudyFolderDetail` | `z_study_folder_detail.dart:119` | **44** | …une page-détail de dossier complète (onglet Matériel + Progression + nav de sous-dossiers adaptative) en un widget | ✅ |
| `ZStudyToolsSectionSpec` | `z_study_tools_section_spec.dart:96` | **36** | …déclarer une section d'outils (titre, compteur, pli, réordonnancement, grille) — **c'est ici que vivent les canaux**, pas dans le layout | ✅ |
| `ZSectionedStudyLayout` | `z_sectioned_study_layout.dart:72` | 3 | …empiler des sections dans un `ListView.builder` virtualisé (`sections`, `header`, `footer`) | ✅ |
| `ZSectionedStudySliver` | `z_sectioned_study_layout.dart:175` | 3 | …le **même contenu** en `slivers:` d'un `CustomScrollView`, sans défilement imbriqué | ❌ |
| `ZStudyToolsPage` | `z_study_tools_page.dart:35` | 3 | …la page d'outils assemblée | ✅ |
| `ZStudySessionHost` | `z_study_session_host.dart:120` | **27** | …détenir le runtime de session (table unique mode→runtime, jamais redécidée) | ❌ |
| `ZStudySessionView` | `z_study_session_view.dart:141` | 23 | …le **corps** de session composable, sans `Scaffold` ni route | ❌ |
| `ZStudySessionScaffold` | `z_study_session_scaffold.dart:64` | **46** | …l'enveloppe de page complète par-dessus le page-shell | ❌ |
| `ZStudySessionSlices` | `z_study_session_slices.dart:139` | — | …recomposer soi-même les tranches (progression / pile / notation) | ❌ |
| `ZDailyTasksView` | `z_daily_tasks_view.dart:212` | 21 | …un « rythme du jour » : bandeau 7 jours + liste virtualisée + état vide injecté | ❌ |
| `ZContentHubSheet` | `z_content_hub_sheet.dart:188` | 18 | …une feuille de hub de contenu (entrées + sections, densité, grille au-delà d'un point de rupture) | ✅ |
| `ZContentHubLauncher` / `ZContentHubScope` | `z_content_hub_launcher.dart:113` / `:287` | — | …ouvrir le hub depuis n'importe où via un présentateur injecté | ❌ |
| `ZFlashcardListView` | `z_flashcard_list_view.dart:343` | 25 | …une liste de cartes avec recherche, filtres, tri, ordre manuel, sélection multiple opt-in, déplacement en lot | ✅ |
| `ZMultiFlashcardEditor` | `z_multi_flashcard_editor.dart:242` | 8 | …éditer un **lot** de cartes en brouillon déclaré, avec un commit unique injecté | ✅ |
| `ZMultiFlashcardDraftController` | `z_multi_flashcard_editor_controller.dart:70` | — | …piloter le brouillon (`ZEditingMode`, `ZDraftEntry`) hors du widget | ❌ |
| `ZFlashcardGenerationSheet` | `z_flashcard_generation_sheet.dart:214` | 12 | …la feuille de génération IA complète | ❌ |
| `ZFlashcardGenerationController` | `z_flashcard_generation_controller.dart:84` | — | …piloter la génération (`ZFlashcardGenerationStatus`, anti-double-tap) | ❌ |
| `ZFlashcardGenerationLauncher` | `z_flashcard_generation_sheet.dart:868` | 4 | …un point d'entrée « Générer avec l'IA » **qui disparaît sans port** | ❌ |
| `ZFlashcardPreview` | `z_flashcard_preview.dart:37` | 5 | …un aperçu en lecture seule où éditer/supprimer sont **absents**, pas grisés | ❌ |
| `ZFlashcardTagConfirmSheet` | `z_flashcard_tag_confirm_sheet.dart:33` | — | …confirmer des tags suggérés | ❌ |
| `ZTagEditor` | `z_tag_editor.dart:74` | 22 | …éditer les tags avec suggestions | ✅ |
| `ZTagChips` | `z_tag_chips.dart:50` | 9 | …afficher des chips de tags avec compte d'usage et libellé a11y injectés | ✅ |
| `ZExamEditor` | `z_exam_editor.dart:72` | 25 | …composer un `ZExam` (saisie préservée, heure typée, pickers injectés) | ❌ |
| `ZExamRemindersSection` | `z_exam_reminders_section.dart:49` | 8 | …dériver et afficher les examens approchants (l'app garde la planification système) | ❌ |
| `ZStudyMindmapSection` | `z_study_mindmap_section.dart:76` | 18 | …une section de cartes mentales dans la page-détail (`ZStudyMindmapMode`) | ❌ |
| `ZItemActionsMenu` | `z_item_actions_menu.dart:283` | 6 | …un menu d'actions d'item, **grille 3 colonnes par défaut** | ✅ |
| `ZItemAction` | `z_item_actions_menu.dart:147` | 10 | …déclarer une action, son `ZItemActionKind`, son `ZItemActionState` et son compte | ✅ |

### 2.4 Cartes de rendu par défaut — une par type de contenu

| Canal | fichier:ligne | params | Cité IFFD |
|---|---|---|---|
| `ZDefaultFolderCard` | `z_default_folder_card.dart:141` | 28 | ✅ |
| `ZDefaultFlashcardCard` | `z_default_flashcard_card.dart:192` | 23 | ✅ |
| `ZDefaultDocumentCard` | `z_default_document_card.dart:195` | 24 | ✅ |
| `ZDefaultNoteCard` | `z_default_note_card.dart:73` | 23 | ✅ |
| `ZDefaultMindmapCard` | `z_default_mindmap_card.dart:90` | 21 | ❌ |
| `ZDefaultExamCard` | `z_default_exam_card.dart:44` | 11 | ❌ |
| `ZFolderCard` (primitive) | `z_folder_card.dart:115` | 21 | ✅ |
| `ZStudyToolsItemCard` (primitive à slots) | `z_study_tools_item_card.dart:51` | 27 | ✅ |
| `ZStudyDocumentCard` / `ZStudyNoteCard` | `z_study_document_card.dart:29` / `z_study_note_card.dart:28` | — | ❌ / ✅ |

Défauts notables : `ZDefaultFolderCard.palette = const ZColorPalette.defaultStudy()`
(l. 147, 8 clés sémantiques `primary…neutral`), `counts = const []` (l. 149),
`isArchived = false` (l. 158).

Icônes de repli **déclarées et remplaçables**, jamais codées dans un widget :
`zDefaultDocumentReferenceIcon` (`z_default_document_card.dart:83`),
`zDefaultDocumentFormatIcons` (l. 92), `zDefaultDocumentFallbackIcon` (l. 124),
`zDefaultMindmapReferenceIcon` (`z_default_mindmap_card.dart:61`),
`zDefaultNoteReferenceIcon` (`z_default_note_card.dart:59`). **Aucune citée par IFFD.**

### 2.5 Préréglages (« Reference ») — les valeurs de rendu centralisées

Patron `abstract final class` : la seule entrée FR-26 encadrée pour des valeurs legacy.
**Aucune ThemeExtension n'est déclarée dans les huit paquets** — grep négatif :

```
$ grep -rn "extends ThemeExtension<" zcrud_study/lib zcrud_study_kernel/lib zcrud_flashcard/lib \
    zcrud_session/lib zcrud_exam/lib zcrud_note/lib zcrud_mindmap/lib zcrud_chat_study/lib ; echo "RC=$?"
RC=1
```

Le thème passe donc **exclusivement** par `ZcrudScope(theme:)` / `ZcrudTheme` de
`zcrud_core` (§ 7).

| Préréglage | fichier:ligne | Cité IFFD |
|---|---|---|
| `ZStudyCardReference` + `ZStudyCardChrome` + `zStudyCardChromeOf` | `z_study_card_reference.dart:36` / `:114` / `:181` | ✅ / ❌ / ❌ |
| `ZFolderCardReference` | `z_folder_card_reference.dart:51` | ❌ |
| `ZFlashcardCardReference` | `z_flashcard_card_reference.dart:53` | ❌ |
| `ZContentHubReference` | `z_content_hub_reference.dart:68` | ❌ |
| `ZDailyTasksReference` + `ZDailyTasksChrome` + `zDailyTasksChromeOf` | `z_daily_tasks_reference.dart:75` / `:209` / `:312` | ❌ |
| `ZStudySessionReference` + `ZStudySessionChrome` + `zStudySessionChromeOf` | `z_study_session_reference.dart:32` / `:74` / `:132` | ❌ |

### 2.6 Navigation de sous-dossiers — 12 canaux, dont 9 jamais cités

| Canal | fichier:ligne | params | Cité IFFD |
|---|---|---|---|
| `ZSubfolderNavSpec` | `z_subfolder_nav_spec.dart:402` | **28** | ✅ |
| `ZSubfolderSidebar` | `z_subfolder_sidebar.dart:64` | 10 | ✅ |
| `ZSubfolderSelectorBar` | `z_subfolder_selector_bar.dart:90` | 3 (`spec`/`selected`/`onSelect`) | ❌ |
| `ZSubfolderCompactSelector` | `z_subfolder_compact_selector.dart:36` | 3 | ✅ |
| `ZSubfolderNarrowNav` | `z_subfolder_narrow_nav.dart:26` | — | ❌ |
| `ZSubfolderNavRenderer` + `…Scope` + `ZSubfolderNavRenderRequest` + `zResolveSubfolderNav` | `z_subfolder_nav_renderer.dart:104` / `:115` / `:75` / `:142` | — | ❌ |
| `ZSubfolderSelectionController` | `z_subfolder_selection_controller.dart:53` | — | ❌ |
| `ZSubfolderRef` | `z_subfolder_ref.dart:24` | — | ✅ |
| `ZSubfolderLayoutMode` / `ZSubfolderSurface` / `ZSubfolderNarrowMode` / `ZSubfolderNavPlacement` / `ZSubfolderAddPlacement` | `z_subfolder_nav_spec.dart:90/147/233/269/378` | — | partiel |
| `kZSubfolderNavBandHeight` | `z_study_folder_detail.dart` (exporté nommément) | — | ✅ |

### 2.7 Primitives de mise en page et d'accessibilité — **toutes jamais citées**

| Canal | fichier:ligne | Ce qu'il permet |
|---|---|---|
| `ZFadedOverflow` / `ZRenderFadedOverflow` | `z_faded_overflow.dart:52` / `:95` | fondu de dépassement **mesurable** (le render object est public pour être asserté) |
| `ZRailItem` + `zRailItemFallbackWidth = 280` | `z_rail_item.dart:40` / `:23` | item de rail borné en largeur |
| `zReorderIds` | `z_reorder_ids.dart:28` | réordonnancement d'index pur |
| `zReorderFlashcards` | `z_flashcard_reorder.dart:81` | **l'unique voie** de réordonnancement de cartes (glisser et boutons a11y y aboutissent tous deux) |
| `zFlashcardsSectionKey` | `z_flashcard_reorder.dart:54` | clé canonique de section flashcards |
| `ZCountBadge` / `ZCountBadgeRow` / `ZCountBadgeSpec` | `z_subfolder_item_chrome.dart:94` / `:176` / `:71` | pastille de compte, sortie du hit-test depuis 3.2.0 |
| `ZFeatureAvailability` + `ZAllFeaturesAvailable` + `ZMapFeatureAvailability` + `ZFeatureAvailabilityScope` | `z_feature_availability.dart:41/77/94/149` | déclarer qu'une capacité est absente ⇒ l'affordance **disparaît** au lieu d'être grisée |
| `zReadableTypeTint` | `z_default_flashcard_card.dart:150` | teinte lisible par type, plancher de contraste |
| `zResolveCardShadowDecoration` | `z_folder_card.dart:779` | ombre de carte résolue par thème |
| `zMirrorIfNeeded` / `zAccentSlot` | `z_content_hub_sheet.dart:521` / `:536` | miroir RTL et attribution d'accent déterministe |

---

## 3. `zcrud_study_kernel` — le noyau pur (44 canaux, 4 cités, **40 jamais cités**)

Pur-Dart, dépend seulement de `zcrud_core` + `zcrud_annotations`.

| Canal | fichier:ligne | Un hôte qui veut… | Cité IFFD |
|---|---|---|---|
| `ZStudyFolder` | `z_study_folder.dart:77` | …le dossier d'organisation multi-type (rattachement inverse) | ✅ |
| `validatePlacement` / hiérarchie | `z_study_folder_hierarchy.dart` | …la primitive pure de hiérarchie à 2 niveaux | ✅ |
| `ZFolderContentsOrder` + `zSectionKey` + `kSectionOrdersKey` | `z_folder_contents_order.dart:115`, `z_section_key.dart:52` | …un **ordre personnel** par section, clé par `folderId`, avec constructeur de clé canonique | ❌ |
| `applyOrder<T>` + `ZUnorderedPlacement` | `apply_order.dart:16` | …un tri stable à ordre personnel **partiel** (les non-ordonnés vont où on dit) | ❌ |
| `ZFlashcardTag` | `z_flashcard_tag.dart:59` | …un tag `ZExtensible` | ✅ |
| `ZSuggestedTag` | `z_suggested_tag.dart:35` | …une suggestion de tag (value object) | ❌ |
| `normalizeTagTitle` / `dedupeByNormalizedTitle<T>` | `normalize_tag_title.dart` | …normaliser et dédoublonner des titres de tag | ❌ |
| `tag_referential_integrity` | `tag_referential_integrity.dart` | …vérifier l'intégrité référentielle des tags | ❌ |
| `ZStudyStreak` + `zAdvanceStreak` + `ZStreakOutcome` + `ZStreakAdvance` | `z_study_streak.dart:148`, `z_advance_streak.dart:130/20/42` | …une **flamme d'assiduité** avec horloge paramétrée, reset à 1 jamais 0, jour civil local | ❌ |
| Jour civil : `ZCivilDayOf` `zLocalCivilDay` `zFormatCivilDay` `zIsCivilDay` `zParseCivilDayNumber` `zCivilDayNumber` | `z_study_streak.dart:59/70/73/101/109/134` | …manipuler un jour civil sans fuseau piégé | ❌ |
| `zIsGradedMode` | `z_advance_streak.dart:84` | …savoir si un mode compte pour la flamme | ❌ |
| `ZReviewMode` | `z_review_mode.dart:20` | **6 modes** : `spaced` `learn` `list` `test` `whiteExam` `cramming` | ✅ |
| `ZStudySessionConfig` | `z_study_session_config.dart:52` | …une config de session persistable (`types` neutralisé en `List<String>` pour l'acyclicité) | ❌ |
| `ZStudySessionSelector` | `z_study_session_selector.dart:34` | …une sélection **pure** sur `ZSessionCandidate` (`matches` + `selectFrom`) | ❌ |
| `ZSessionCandidate` | `z_session_candidate.dart:29` | …rendre filtrable n'importe quelle entité (implémenté par `ZFlashcard`) | ❌ |
| `ZStudySessionResult` | `z_study_session_result.dart:41` | …le résultat d'une session (value object, sans durée — elle est injectée à l'écran) | ❌ |
| `ZDailyStudyTask` + `ZDueCardsTask` + `ZExamTask` + `ZApproachingExam` + `aggregateDailyStudyTasks` | `z_daily_study_task.dart:41/50/79/119`, `aggregate_daily_study_tasks.dart` | …agréger un « rythme du jour » (cartes dues + examens approchants) **sans arête vers un satellite** | ❌ |
| `ZCascadeEdge` + `ZCascadeRegistry` | `z_cascade_registry.dart:40` / `:88` | …déclarer une cascade de suppression, pure, zéro backend, avec garde anti « deux propriétaires » et traversée bornée | ❌ |
| `ZColorPalette` + `ZKeyHash` + `zFnv1a32` + `remapColorKey` | `z_color_palette.dart:86/34/68`, `remap_color_key.dart` | …un registre borné de `colorKey` avec repli et remap **déterministe** (zéro `Color` : la résolution est injectée côté cœur) | ❌ |
| `ZStudyPodcast` + `ZPodcastSourceKind` `ZPodcastMode` `ZPodcastStatus` `ZPodcastFreshness` `podcastFreshness` | `z_study_podcast.dart:72`, `z_podcast_*.dart` | …un podcast **adressé par contenu** (`sourceHash` opaque comparé, jamais calculé ici) | ❌ |
| `ZStudyRepository<T>` | `z_study_repository.dart:52` | …un port CRUD offline-first générique (Template Method : `validate` avant `persist`) | ❌ |
| `ZStudyDocumentRef` / `ZStudyNoteRef` | `z_study_document_ref.dart:71` / `z_study_note_ref.dart:45` | …nommer un document/une note **sans arête** vers ces paquets (AD-1) | ❌ |

---

## 4. `zcrud_flashcard` — carte + SRS (68 canaux, 10 cités, **58 jamais cités**)

### 4.1 Domaine

| Canal | fichier:ligne | Ce qu'il permet | Cité IFFD |
|---|---|---|---|
| `ZFlashcard` | `z_flashcard.dart:64` | entité canonique, `ZExtensible`, canal hors schéma `source`, implémente `ZSessionCandidate` | ✅ |
| `ZFlashcardType` | `z_flashcard_type.dart:16` | **6 types** : `multipleChoice` `trueOrFalse` `openQuestion` `exercise` `fillBlank` `shortAnswer` | ✅ |
| `ZChoice` | `z_choice.dart:22` | un choix de QCM | ✅ |
| `ZFlashcardSource` (sealed) + `ZNoteSource` `ZConversationSource` `ZDocumentSource` `ZCustomSource` | `z_flashcard_source.dart:30/93/119/154/191` | provenance **ouverte** via `ZSourceRegistry` | ❌ |
| `ZRepetitionInfo` | `z_repetition_info.dart:79` | état SRS **séparé de la carte** (AD-9) | ✅ |
| `ZSrsScheduler` / `ZSm2Scheduler` / `ZSrsConfig` | `z_srs_scheduler.dart:31` / `z_sm2_scheduler.dart:23` / `z_srs_config.dart:17` | SRS **pluggable** ; défauts `minEase 1.3` `maxEase 2.5` `passThreshold 3` `quality [0,5]` `overdueBonus 0.0` | ❌ pour `ZSrsScheduler` |
| `zDuplicateFlashcardForEditing` | `z_flashcard_duplicate.dart:54` | « dupliquer pour modifier » : copie éphémère `id: null`, aucun état personnel copié, original jamais muté | ❌ |
| `ZFlashcardTestFilters` + `zApplyTestFilters` + `zDrawQuestions` + `zShuffleChoices` | `z_flashcard_filters.dart:107/206/461/511` | filtrer/tirer un test (aléa **injecté**) | ❌ |
| `ZFlashcardBrowseFilters` + `zApplyBrowseFilters` + `ZFlashcardSearchField` | `z_flashcard_filters.dart:293/362/264` | filtrer une **liste de gestion** (ne tronque jamais : passe par `matches`, pas `selectFrom`) | ❌ |
| `ZMasteryLevel` + `zMasteryLevelOf` | `z_flashcard_filters.dart:34` / `:75` | `bad` `good` `mastered`, bornes **toutes lues sur `ZSrsConfig`** | ❌ |
| `ZFlashcardSortMode` + `zSortFlashcards` | `z_flashcard_sort.dart:27` / `:53` | `dateDesc` `dateAsc` `title` `manual` — le mode manuel **ne trie pas** | ❌ |
| `ZSessionCategories` + `zCategorize` + `zIndexSrsById` | `z_session_categorization.dart:30/91/56` | catégorisation **O(1)** par carte (lookup Map, jamais `firstWhere`) | ❌ |
| `ZFlashcardHintPort` + `ZFlashcardHintRequest` | `z_flashcard_hint_port.dart:120` / `:48` | indices IA, appelés **après** épuisement de `ZFlashcard.hint`, résultat éphémère jamais persisté | ❌ |
| `ZHintPenaltyPolicy` + `zApplyHintCeiling` + `zHintCeilingFloor` | `z_hint_penalty.dart:42/110/79` | plafond de note par indices, **appliqué en dernier** — un port qui rend une note haute ne le contourne pas | ❌ |
| `ZFlashcardAnswerEvaluationPort` (+ Request/Evaluation) | `z_flashcard_answer_evaluation_port.dart:218/58/157` | évaluation **consultative** : suggère une qualité, n'écrit jamais le SRS | ❌ |
| `zIsLocallyEvaluatedType` + `zEvaluateLocally` + `zCorrectChoiceIndexes` + `zIsSingleChoiceQcm` | `z_flashcard_local_evaluation.dart:36/96/66/56` | QCM/vrai-faux évalués **localement et exactement** ; la table de routage décide **par le type**, jamais par un retour `null` | ❌ |
| `zFlashcardSearchText` | `z_flashcard_search_text.dart:82` | normalisation de recherche (marques combinantes U+0300–U+036F + repli `zFoldDiacritics` + espaces insécables) | ❌ |
| `ZRevealTransition` | `z_reveal_transition.dart:18` | transition question→réponse (**enum**, jamais un booléen) — Reduce Motion **prime** | ❌ |

### 4.2 Data

| `ZFlashcardRepository` | `z_flashcard_repository.dart:76` | coordinateur offline-first composant les ports du cœur ; idempotence de l'inscription/reset ; déplacement de carte **avec re-sync du `folderId` SRS** | ❌ |
|---|---|---|---|
| `ZRepetitionStore` | `z_repetition_store.dart:79` | port SRS séparé — **voie d'écriture unique `reviewCard`** | ✅ |

### 4.3 Présentation

| Canal | fichier:ligne | params | Cité IFFD |
|---|---|---|---|
| `ZFlashcardReviewCard` | `z_flashcard_review_card.dart:88` | 11 | ✅ |
| `ZFlashcardContentBuilder` + `ZFlashcardDefaultContent` | `z_flashcard_content_slot.dart:41` / `:51` | — | ❌ |
| `ZFlashcardMarkdownContent` | `z_flashcard_markdown_content.dart:56` | — | ❌ |
| `ZFlashcardEditionFields` (**8 fabriques** : `type` `choices` `trueFalse` `question` `answer` `explanation` `hint` `tags` + `all()`) | `z_flashcard_editors.dart:87` puis `:89/100/109/118/127/135/143/150/157` | — | ❌ |
| `registerZFlashcardEditors(registry)` | `z_flashcard_editors.dart:41` | — | l'entrée de registre de widgets du cœur |
| `ZFlashcardEditionValidator` + `ZFlashcardEditionMessages` | `z_flashcard_edition_validator.dart:41` / `:21` | — | ❌ |
| `ZFlashcardFieldConfig` + `ZFlashcardEditorKind` | `z_flashcard_editor_config.dart:33` / `:16` | — | ❌ |
| `ZChoicesFieldWidget` / `ZTrueFalseFieldWidget` / `ZFlashcardTypeFieldWidget` | `z_flashcard_choices_field_widget.dart:39` / `z_flashcard_true_false_field_widget.dart:17` / `z_flashcard_type_field_widget.dart:27` | — | ❌ |
| `ZFlashcardEditingScope` | `z_flashcard_editing_scope.dart:25` | — | ❌ |
| `zReduceMotionOf` | `z_reduce_motion.dart:57` | — | ❌ |

Défaut notable : `ZFlashcardReviewCard.revealTransition = ZRevealTransition.flip3d`
(`z_flashcard_review_card.dart:105`).

---

## 5. `zcrud_session` — les runtimes de révision (68 canaux, 5 cités, **63 jamais cités**)

C'est **le paquet le moins exploité de l'aire** : 92,6 % de sa surface publique n'est
citée nulle part chez l'hôte.

### 5.1 Moteurs (domaine, pur)

| Canal | fichier:ligne | Ce qu'il permet | Cité IFFD |
|---|---|---|---|
| `ZStudySessionEngine` | `z_study_session_engine.dart:116` | moteur SRS `ChangeNotifier` pur-Flutter (état immuable + reducer pur) ; réinsertion d'une carte ratée à **+2 / +4** selon la sévérité du lapse | ✅ |
| `kLapseOffsetSoft` / `kLapseOffsetHard` / `reduceGrade` | même fichier | constantes et reducer **exposés pour la testabilité** | — |
| `ZLinearSessionState` | `z_linear_session_state.dart:133` | runtime linéaire | ❌ |
| `ZWhiteExamSessionEngine` + `ZWhiteExamState` + `ZWhiteExamPhase` + `ZExamScoringPort` | `z_white_exam_session_engine.dart:274/90/64/218` | runtime d'**examen blanc** avec port de notation injecté | ❌ |
| `ZWhiteExamSessionController` (+ `…ViewState`, `…ViewPhase`) | `z_white_exam_session_controller.dart:53/26/19` | pilotage de l'examen blanc | ❌ |
| `ZSessionRuntimeKind` + `zSessionRuntimeForMode` | `z_session_runtime.dart:37` / `:64` | **table unique** mode→runtime : `srsEngine` `linear` `whiteExam` servent les 6 modes ; `switch` exhaustif sans `default` (un 7ᵉ mode casse la compilation) | ❌ |
| `ZSessionState` / `ZSessionItem` / `ZSessionReviewer` | `z_session_state.dart:25` / `z_session_item.dart:17` / `z_session_reviewer.dart:26` | instantané immuable, identité neutre de carte, **seam d'écriture SRS unique** | ❌ |
| `ZFlashcardSubmission` | `z_flashcard_submission.dart:19` | soumission advisory émise à l'hôte — la surface de saisie **n'écrit rien** | ❌ |
| `ZFeedbackTier` + `ZFeedbackThresholds` + `zFeedbackTierFor` + `zFeedbackKeyFor` | `z_session_feedback.dart:32/48/104/136` | `(qualité, temps, indices)` → clé l10n, pur, testable hors widget | ❌ |

### 5.2 Widgets purs

| Canal | fichier:ligne | params | Cité IFFD |
|---|---|---|---|
| `ZFlashcardAnswerInput` | `z_flashcard_answer_input.dart:102` | 17 | ✅ |
| `ZSessionCardSwiper` | `z_session_card_swiper.dart:134` | 10 | ❌ |
| `ZSrsQualityButtons` + `ZQualityScale` + `ZSrsQualityEmphasis` | `z_srs_quality_buttons.dart:187/38/111` | 8 | ✅ / ❌ / ❌ |
| `ZSessionSummaryView` + `ZSummaryCelebration` + `ZCelebrationSpec` + `zMasteredCount` | `z_session_summary_view.dart:206/62/82/190` | 12 | ❌ |
| `ZSessionQualityBreakdown` + `ZQualityBreakdownCoverage` | `z_session_quality_breakdown.dart:41` / `:25` | 6 | ❌ |
| `ZStudyProgressRings` + `ZProgressRingsData` | `z_study_progress_rings.dart:78` / `:27` | 5 | ❌ |
| `ZSessionProgressIndicator` + `ZSessionProgressStyle` | `z_session_progress_indicator.dart:77` / `:46` | 8 | ❌ |
| `ZSwipeEmotion` + `ZSwipeEmotionIndicator` | `z_session_progress_indicator.dart:359` / `:380` | — | ❌ |
| `ZSessionModeSelector` + `ZSessionModeKind` | `z_session_mode_selector.dart:89` / `:63` | 7 | ❌ |
| `ZTestFiltersDialog` + `zMasteryLabelKey` + `zMasteryFallback` | `z_test_filters_dialog.dart:54/42/45` | 4 | ❌ |
| `ZListSessionView` + `ZExamViewPhase` + `ZExamAnswerCallback` | `z_list_session_view.dart:128/105/124` | 11 | ❌ |
| `ZWhiteExamSessionView` + `ZWhiteExamSessionLabels` + 3 builders | `z_white_exam_session_view.dart:79/46/34/38/42` | 6 | ❌ |
| `ZStreakBadge` | `z_streak_badge.dart:25` | 2 | ❌ |
| `zShowStreakToast` + `zStreakToastSeverityFor` | `z_streak_toast.dart:46` / `:66` | — | ❌ |
| `ZTimerDisplay` | `z_timer_display.dart:21` | — | ❌ |
| `ZCardAdvanceBehavior` + `zDefaultAdvanceBehavior` | `z_card_advance_behavior.dart:17` / `:46` | — | ❌ |
| `ZCorrectionVisibility` + `ZCorrectionVisibilityX` | `z_correction_visibility.dart:29` / `:45` | — | ❌ |
| `ZFeedbackBank` + `ZDefaultFeedbackBank` + `ZSessionFeedbackText` + `zFeedbackText` | `z_session_feedback_bank.dart:38/51/118/99` | — | ❌ |

Défauts de `ZFlashcardAnswerInput` (`z_flashcard_answer_input.dart:107-118`) :
`srsConfig = const ZSrsConfig()`, `allowSkipEvaluation = false`, `revealStoredHint = false`,
`hintPolicy = const ZHintPenaltyPolicy()`, `timerDisplay = ZTimerDisplay.hidden`,
`autoAdvanceDelay = 200 ms`, `correctionVisibility = ZCorrectionVisibility.immediate`.

`ZSessionModeSelector` offre `learnNew` `review` `test` `cramming`, badge flamme, lot
configurable **défaut 30** ; il **produit une file**, il ne démarre aucun runtime.

---

## 6. Les petits paquets

### 6.1 `zcrud_exam` (4 canaux, 3 cités) — le mieux exploité de l'aire

| Canal | fichier:ligne | Cité IFFD |
|---|---|---|
| `ZExam` (+ `daysUntil`/`isPast`/`isApproaching` prenant `now` **en paramètre**) | `z_exam.dart:72` | ✅ |
| `ZReminderTime` (value object `'HH:mm'` défensif et total) | `z_reminder_time.dart:31` | ✅ |
| `ZReminderRecurrence` (récurrence hebdomadaire, **complète** le modèle relatif sans le remplacer) | `z_reminder_recurrence.dart:42` | ✅ |
| `ZExamExtensionParser` | `z_exam.dart:54` | ❌ |

### 6.2 `zcrud_note` (11 canaux, 2 cités, **9 jamais cités**)

| Canal | fichier:ligne | Ce qu'il permet | Cité IFFD |
|---|---|---|---|
| `ZSmartNote` | `z_smart_note.dart:78` | note à **corps typé** `List<Map<String,dynamic>>` d'ops Delta neutres, jamais une `String` ambiguë (AD-28) | ✅ |
| `normalizeNoteContentOps` | `z_note_content.dart` | coercition **totale** : une `String` markdown **survit VERBATIM**, jamais `[]` | ✅ |
| `ZSmartNoteEditor` | `z_smart_note_editor.dart:61` | adaptateur mince sur `ZMarkdownField` + `ZDeltaCodec` ; **`faithChannel` vérifié présent** (`:71`, `:92`) | ❌ |
| `ZSmartNoteReader` | `z_smart_note_reader.dart:29` | lecteur riche mince | ❌ |
| `ZNoteContentFaithChannel` + `ZNoteContentEncoder` | `z_note_faith_channel.dart:84` / `:78` | écrire les **deux** canaux (typé + clé de foi de l'hôte) depuis les **mêmes** ops, dans la **même** remontée | ❌ |
| `ZNoteAudio` | `z_note_audio.dart:83` | slot audio typé, versionné, **opt-in** — hors schéma | ❌ |
| `ZOpaqueNoteExtension` | `z_opaque_note_extension.dart:83` | canal de **survie** d'un `extension` que rien n'a su typer : réémis verbatim au lieu d'être détruit | ❌ |
| `zMigrateStickyNote` / `zMigrateNoteTables` / `zUpgradeLegacyNoteContent` | `z_note_table_migration.dart:51/61/82` | migration d'un corpus historique (sticky note, tables) | ❌ |

### 6.3 `zcrud_mindmap` (26 canaux, 10 cités, **16 jamais cités**)

| Canal | fichier:ligne | params | Cité IFFD |
|---|---|---|---|
| `ZMindmap` / `ZMindmapNode` / `ZMindmapTreeOps` / `ZMindmapApi` | `z_mindmap.dart:41` / `z_mindmap_node.dart:34` / `z_mindmap_tree_ops.dart:23` / `z_mindmap_api.dart:9` | — | ✅✅✅❌ |
| `ZMindmapView` + `ZMindmapViewConfig` + `ZMindmapViewMode` | `z_mindmap_view.dart:55` / `z_mindmap_view_config.dart:137` / `:123` | 10 / 9 | ✅ / ❌ |
| `ZMindmapListView` | `z_mindmap_list_view.dart:24` | 9 | ✅ |
| `ZMindmapOutlineEditor` + `ZMindmapOutlineController` + `ZMindmapOutlineLabels` | `z_mindmap_outline_editor.dart:50` / `z_mindmap_outline_controller.dart:35` / `z_mindmap_outline_labels.dart:17` | 11 | ✅ / ❌ / ✅ |
| `ZMindmapViewController` + `ZMindmapViewLabels` | `z_mindmap_view_controls.dart:27` / `:119` | — | ❌ |
| `ZMindmapMarkdownContent` / `ZMindmapMarkdownEditField` | `z_mindmap_markdown_content.dart:37` / `z_mindmap_markdown_edit_field.dart:44` | — | ❌ |
| `ZMindmapNodeCard` / `ZMindmapDefaultNodeContent` / `ZMindmapCellClip` | `z_mindmap_node_card.dart:124/26/88` | 6 | ❌ |
| `ZMindmapEditFieldKind` / `ZMindmapEditFieldContext` / `ZMindmapEditFieldBuilder` | `z_mindmap_view_config.dart:42/65/117` | — | ❌ |

Défauts de `ZMindmapViewConfig` (`:140-145`) : `minScale 0.25`, `maxScale 2.5`,
`cellSize 180×72`, `cellSpacing 24`, `indentStep 24`, `minTapTarget 48`.

### 6.4 `zcrud_chat_study` (13 canaux, **0 cité, paquet non déclaré**)

Le pont conversation ↔ SRS, délibérément mince : il ne redéclare **aucun** symbole des
quatre paquets qu'il câble.

| Canal | fichier:ligne | Ce qu'il permet |
|---|---|---|
| `ZChatFlashcardGenerator` | `z_chat_flashcard_generator.dart:36` | câble le port de génération existant avec **estampillage défensif de la provenance** |
| `zStampChatProvenance` | `z_chat_flashcard_generator.dart:153` | force la provenance conversationnelle sur une carte générée |
| `zChatMessageGenerationRequest` / `zChatConversationGenerationRequest` | `z_chat_flashcard_mapper.dart:113` / `:137` | message ou conversation → requête de génération |
| `zChatMessageProvenance` / `zChatConversationProvenance` | `z_chat_flashcard_mapper.dart:89` / `:101` | → `ZConversationSource` |
| `zChatMessageStudyText` / `zChatMessagesStudyText` | `z_chat_flashcard_mapper.dart:53` / `:69` | extrait le texte étudiable d'un message |
| `ZStudyPool` + `ZStudyPoolRequest` + `zBuildStudyPool` + `zStudyPoolKeys` | `z_chat_study_pool.dart:83/54/157/144` | pool de session = cartes du dossier **∪** cartes de la conversation, **dédoublonnées** |
| `zIsChatStudyLaunchMode` | `z_chat_study_launch.dart:51` | quels `ZReviewMode` sont offerts au départ d'une conversation |

---

## 7. Jetons de thème — le canal de personnalisation, largement inemployé

Aucun jeton d'étude ne vit dans les huit paquets (§ 2.5, grep négatif montré). Ils vivent
tous dans `ZcrudTheme`, `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart`
(**4 365 lignes, 220 jetons au total**).

- **Bloc « étude » strict, l. 425-500 : 76 jetons.**
- Bloc partagé carte/pastille/accent/animation, l. 404-424 : 21 jetons.

Familles et lignes exactes :

| Famille | lignes | nb | Exemples |
|---|---|---|---|
| `subfolder*` | 425-434, 445 | 11 | `subfolderTriggerVariant` `subfolderTriggerFill` `subfolderSelectedEmphasis` `subfolderSheetTitleAlign` |
| `railItem*` / `railPadding` | 435-438 | 4 | `railItemWidth` `railItemHeight` `railItemGap` |
| `studySection*` | 439-444 | 6 | `studySectionTitleStyle` `studySectionCountShape` `studySectionCollapsePlacement` |
| `studyCard*` | 446-459 | 14 | `studyCardHierarchy` `studyCardIconTileSize` `studyCardContentAlignment` |
| `flashcardTypeGradients` | 460 | 1 | dégradé par type de carte |
| `folderCard*` | 461-472 | 12 | `folderCardAccentHeight` `folderCardMinContrast` `folderCardFooterPlacement` |
| `studySession*` | 473-479 | 7 | `studySessionStackFlex` `studySessionInputFlex` `studySessionMinTarget` |
| `dailyTasks*` | 480-486 | 7 | `dailyTasksMonthBreakpoint` `dailyTasksDayCellRadius` |
| `contentHub*` | 487-500 | 14 | `contentHubDensity` `contentHubGridBreakpoint` `contentHubAccents` |

**IFFD pose ces jetons dans un seul fichier** — `lib/src/presentation/shared/zcrud/z_iffd_form_theme.dart`
— et n'en emploie qu'environ **18** de la famille étude, tous `subfolder*` (10),
`studySection*` (5), `studyCard*` (2), plus `subfolderNavBandHeight`/`subfolderNavPlacement`.
**Rien de `folderCard*`, rien de `studySession*`, rien de `dailyTasks*`, rien de
`contentHub*`, rien de `railItem*`, rien de `flashcardTypeGradients`.**

### Seams de `ZcrudScope` pertinents pour l'étude

`zcrud_core/lib/src/presentation/zcrud_scope.dart:81-105` — **24 paramètres**. Ceux qui
portent l'aire étude : `labels` (l. 83), `theme` (l. 84), `widgetRegistry` (l. 85),
`iconResolver` (l. 98), `colorKeyResolver` (l. 100), `gradientResolver` (l. 101),
`richTextRenderer` (l. 102), `reorderRenderer` (l. 95).

Scopes **locaux** au périmètre (InheritedWidget, pose ciblée) — 6, dont 5 jamais cités :

| Scope | fichier:ligne | Cité IFFD |
|---|---|---|
| `ZFeatureAvailabilityScope` | `zcrud_study/…/z_feature_availability.dart:149` | ❌ |
| `ZSubfolderLayoutScope` | `zcrud_study/…/z_subfolder_nav_spec.dart:189` | ❌ |
| `ZContentHubScope` | `zcrud_study/…/z_content_hub_launcher.dart:287` | ❌ |
| `ZSubfolderNavRendererScope` | `zcrud_study/…/z_subfolder_nav_renderer.dart:115` | ❌ |
| `ZFlashcardGenerationScope` | `zcrud_study/…/z_flashcard_generation_sheet.dart:841` | ❌ |
| `ZFlashcardEditingScope` | `zcrud_flashcard/…/z_flashcard_editing_scope.dart:25` | ❌ |

---

## 8. Pièges — ce qui existe mais n'agit pas comme on le lirait

### 8.1 Constats (vérifiés sur disque)

1. **`ZItemActionsMenu` a changé de défaut en `v3.0.0` — RUPTURE assumée.**
   `crossAxisCount = 3` (`z_item_actions_menu.dart:297`). Avant 3.0.0 : **colonne unique**.
   Retour arrière en une ligne : `crossAxisCount: 1`. Un hôte qui réinjectait sa grille à
   la main **superpose** désormais sa compensation au défaut — cf. la règle « hôte passif
   vs hôte ayant compensé ». C'est le piège le plus actionnable de l'aire.

2. **`ZFlashcardGenerationLauncher` est ABSENT de l'arbre sans port** — vérifié
   (`z_flashcard_generation_sheet.dart:900-903`, `return const SizedBox.shrink()`), jamais
   grisé. Un hôte qui cherche « pourquoi le bouton ne s'affiche pas » cherche un flag
   booléen qui n'existe pas : il manque un `port` ou un `ZFlashcardGenerationScope`.

3. **`ZSubfolderSelectorBar.triggerChromeKey` est ABSENT tant que
   `ZcrudTheme.subfolderTriggerVariant` vaut `null`/`flat`** — dartdoc explicite
   `z_subfolder_selector_bar.dart:108-112`. Un test qui cherche cette clé sans poser le
   jeton échoue pour la mauvaise raison.

4. **`ZFolderCard` : « la disposition n'a d'effet que si `counts` ET `footer` sont tous
   deux présents »** — `z_folder_card.dart:232`. Poser `folderCardFooterPlacement` sans
   `counts` est un no-op silencieux.

5. **Le glisser est inopérant si le descripteur ne le déclare pas** —
   `z_study_tools_section_spec.dart:46` : « inopérant (glisser mort). Seul le descripteur,
   qui connaît… ». Le canal est sur `ZStudyToolsSectionSpec` (36 params), pas sur le layout
   (3 params). Un hôte qui cherche à régler le layout cherche au mauvais endroit.

6. **`ZMindmapOutlineEditor` : état vide *entièrement* absent tant que l'hôte n'injecte
   rien** — `z_mindmap_outline_editor.dart:325`.

7. **`ZSmartNote` via le registre ne type JAMAIS le slot `extension`.**
   `ZcrudRegistry` / `FirebaseZRepositoryImpl.fromRegistry` appellent
   `ZSmartNote.fromMap(map)` **sans `extensionParser`** (dartdoc du barrel
   `zcrud_note.dart:15-24`). Pour utiliser `ZNoteAudio`, il faut le **constructeur nominal**
   avec `extensionParser: ZNoteAudio.fromJsonSafe`. Le payload survit (`ZOpaqueNoteExtension`),
   mais il n'est pas typé. **Piège de câblage, pas de code.**

8. **Le round-trip `String → ops → String` n'est PAS fidèle à l'octet** — chiffres portés
   par la dartdoc du barrel `zcrud_note.dart:88-94` : **2 %** de fidélité à l'octet sur
   46 constructions markdown, **67 %** en tolérant le `\n` terminal ; cassent le LaTeX
   bloc, la fusion du saut de ligne simple, les lignes vides multiples, les entités HTML.
   C'est **pourquoi** `ZNoteContentFaithChannel` existe et doit être écrit **à chaque**
   édition. ⚠️ **Je n'ai pas rejoué cette mesure** (aucun test lancé, consigne) : c'est un
   chiffre de dartdoc, à revérifier avant de s'appuyer dessus.

9. **`ZFlashcardBrowseFilters` délègue à `ZStudySessionSelector.matches`, jamais à
   `selectFrom`** — `z_flashcard_filters.dart:362` et sa dartdoc : `selectFrom` porte un
   **plafond** qui tronquerait une liste de gestion. Deux fonctions voisines, une seule
   correcte selon l'usage.

10. **`zApplyHintCeiling` s'applique EN DERNIER, y compris sur la valeur d'un port**
    (`z_hint_penalty.dart:110`). Un `ZFlashcardAnswerEvaluationPort` qui rend 5 avec trois
    indices consommés **ne contourne pas** le plafond. Un hôte qui débogue « ma note est
    rabaissée » cherchera dans le port ; ce n'est pas là.

### 8.2 Soupçons — dits comme soupçons, pas comme faits

- **Soupçon A — la surface de `zcrud_session` semble conçue pour un assemblage que
  personne ne fait.** 63 canaux sur 68 jamais cités, dont **tous** les moteurs sauf
  `ZStudySessionEngine`, et **tous** les écrans (`ZListSessionView`, `ZWhiteExamSessionView`,
  `ZSessionSummaryView`, `ZSessionModeSelector`). Je n'ai pas vérifié que ces assemblages
  se composent réellement bout à bout à partir des seuls canaux publics : c'est la première
  chose qu'une confrontation devrait falsifier.
- **Soupçon B — `zcrud_chat_study` pourrait ne pas être consommable en l'état.** Le paquet
  n'est ni en `dependencies` ni en `dependency_overrides` chez l'hôte (grep négatif § 0).
  Or `zcrud_menu` a déjà provoqué un échec de `pub get` chez IFFD pour exactement cette
  raison (commentaire `iffd/pubspec.yaml:334-339`, « TROISIÈME OCCURRENCE »). L'adopter
  demandera donc **aussi** de vérifier la fermeture transitive, pas seulement d'ajouter une
  entrée. Je n'ai pas résolu ce graphe.
- **Soupçon C — les `CHANGELOG.md` mentent par omission.** Sept sur huit annoncent
  « [0.86.0] — Chantier documentation » comme dernière entrée alors que les paquets sont
  en 3.21.0. Un hôte qui lit le CHANGELOG pour savoir ce qui est neuf conclut « rien depuis
  0.86 » — faux pour `zcrud_study` (5 entrées 3.x) et trompeur pour les autres, dont le
  contenu a bougé en `v3.3.0` (38 fichiers) sans une ligne de changelog. C'est un défaut de
  **notre** côté, pas du sien.
- **Soupçon D — six « Reference » coexistent avec 76 jetons de thème.** Je n'ai pas
  établi qui gagne quand les deux déclarent la même valeur. La règle annoncée ailleurs est
  « paramètre > jeton > référence » ; à falsifier sur au moins une paire.

---

## 9. Livré récemment, probablement inconnu de l'hôte

⚠️ **Redéfinition imposée par la mesure** (§ 1) : « récent » au sens 3.13 → 3.21 est
**vide** pour cette aire. Le critère utile n'est pas la date de livraison — l'hôte a déjà
tout le code, il est sur `v3.21.0` — mais **le fait qu'il ne l'appelle jamais**. Les deux
listes ci-dessous, dans cet ordre de priorité.

### 9.1 Livré dans les 6 derniers jours (v3.0.0 → v3.6.0, 20 → 23 août) — 3 canaux neufs

| Canal | fichier:ligne | Livré | Ce que l'hôte ne peut pas deviner |
|---|---|---|---|
| `ZItemActionState` (`absent`/`inProgress`/`present`) | `z_item_actions_menu.dart:104` | **v3.0.0, 2026-08-20** | une action **porte son état** : teinte dérivée du `ColorScheme` + **annonce** au lecteur d'écran ; un état invalide **échoue fermé** (aucune teinte sans annonce) |
| Compte optionnel sur `ZItemAction` (badge) | `z_item_actions_menu.dart:147` | **v3.0.0**, corrigé **v3.2.0** | le badge dit **combien** ; en 3.2.0 il a été **sorti du hit-test** (il volait le tap : centre 1, à 8 px du coin 0) **et** cessé de rétrécir la tuile (48 dp au lieu de 96) |
| `crossAxisCount` sur `ZItemActionsMenu` | `z_item_actions_menu.dart:297` | **v3.0.0** | défaut passé de 1 colonne à **grille 3 colonnes** — RUPTURE, cf. piège 8.1.1 |

Également en 3.x, sans nouveau symbole mais avec changement de comportement :
`ZDefaultFlashcardCard` et `ZSubfolderSelectorBar` re-posent désormais le `ZcrudScope` par
**`copyWith`** (v3.1.0) au lieu d'une énumération seam par seam qui perdait
`subListSeamRegistry` et `selectChoiceBuilderRegistry` (v3.0.0) ; et les six symboles de
teinte lisible (`zReadableTintOn`, `zContrastRatio`, `zRelativeLuminance`, `zCompositeOver`,
`kZTextMinContrast`, `kZNonTextMinContrast`) ont **remonté dans `zcrud_core`** en v3.3.0 —
**non-rupture**, `zcrud_study.dart:112-119` les ré-exporte sous les mêmes noms.

### 9.2 Les 348 canaux jamais appelés — par ordre de rendement

| Rang | Bloc | canaux | Pourquoi c'est du « migrable aujourd'hui » |
|---|---|---|---|
| 1 | **`zcrud_session` en entier** | **63** | trois runtimes, six écrans, feedback l10n, examen blanc — 92,6 % de la surface non appelée, alors que l'hôte a un moteur de révision |
| 2 | **Session assemblée de `zcrud_study`** | ~20 | `ZStudySessionHost` (27 params), `ZStudySessionView` (23), `ZStudySessionScaffold` (46), `ZStudySessionSlices`, `ZStudySessionReference` |
| 3 | **Génération IA (les 7 ports + la chaîne UI)** | ~20 | ports neutres + `ZFlashcardGenerationController`/`Sheet`/`Launcher`/`Scope` + les 4 défauts purs |
| 4 | **Filtres, tri, catégorisation, indices, évaluation locale** | ~25 | tout le domaine pur de `zcrud_flashcard` non appelé : un hôte réécrit forcément ces prédicats chez lui |
| 5 | **Flamme d'assiduité + jour civil** | 12 | `zAdvanceStreak` + 6 fonctions de jour civil + `ZStreakBadge` + `zShowStreakToast` |
| 6 | **Rythme du jour** | 10 | `aggregateDailyStudyTasks` + `ZDailyTasksView` (21 params) + `ZDailyTasksReference`/`Chrome` |
| 7 | **Partage et modération** | 8 | aucune brique n'est appelée ; entièrement disponible |
| 8 | **`zcrud_chat_study` en entier** | 13 | paquet non déclaré (cf. soupçon B) |
| 9 | **Ordre personnel + cascade + palette (kernel)** | ~12 | `ZFolderContentsOrder`, `applyOrder`, `ZCascadeRegistry`, `ZColorPalette` |
| 10 | **Note : audio, canal de foi, migrations** | 9 | `ZNoteAudio`, `ZNoteContentFaithChannel`, les 3 `zMigrate*` |
| 11 | **Mindmap : contrôleurs, seams rich-text, cartes de nœud** | 16 | `ZMindmapViewController`, `ZMindmapMarkdownEditField`, `ZMindmapNodeCard` |
| 12 | **58 jetons de thème d'étude jamais posés** | 58 | `folderCard*` (12), `studySession*` (7), `dailyTasks*` (7), `contentHub*` (14), `railItem*` (4), `flashcardTypeGradients`, et le reste de `studyCard*` |

### 9.3 Le signal le plus fort — l'hôte a retiré 4 CR sur 7 en découvrant que le canal existait

`iffd/docs/zcrud-change-requests.md`, lot « lecteur riche + éditeur plein écran » :

```
7589:## CR-IFFD-114 — le TABLEAU markdown rendu : sa géométrie est une décision fermée…
7675:## CR-IFFD-115 — le retour à la ligne SOUPLE est recollé en espace…
7734:## CR-IFFD-116 — le dialogue d'édition plein écran n'a pas de sous-titre : QUATRIÈME surface…
7787:## CR-IFFD-117 — RETIRÉE AVANT ÉMISSION — l'encodage à la sortie du dialogue plein écran : le canal existait
7825:## CR-IFFD-118 — RETIRÉE AVANT ÉMISSION — `onTapLink` du lecteur : le comportement existait…
7859:## CR-IFFD-119 — RETIRÉE AVANT ÉMISSION — `chrome: none` plus un `Padding` d'appelant sont l'équivalence exacte
7879:## CR-IFFD-120 — RETIRÉE AVANT ÉMISSION — forcer la présentation plein cadre : le paramètre est public
```

Quatre CR sur sept **retirées avant émission** parce que le canal existait déjà. Ces
quatre-là portaient sur `zcrud_markdown`, hors périmètre — mais le motif est le sujet même
de ce catalogue, et l'aire Étude affiche un taux de non-appel de **82 %** contre ces quatre
occurrences ponctuelles. **C'est la mesure qui justifie les onze confrontations.**

---

## 10. Ce que je n'ai pas mesuré (à ne pas supposer fait)

- **Aucun test lancé**, dans aucun dépôt (consigne). Donc : rien ici n'atteste qu'un canal
  *fonctionne* — seulement qu'il *existe*, à telle ligne, avec tels paramètres et tels
  défauts.
- **La fermeture transitive des dépendances** d'un paquet non déclaré chez l'hôte
  (`zcrud_chat_study`) n'a pas été résolue.
- **La composabilité bout à bout** des assemblages de `zcrud_session` à partir des seuls
  canaux publics (soupçon A).
- **L'ordre de priorité paramètre / jeton / référence** (soupçon D).
- **Les 52 bascules** de `iffd/docs/qa-plan-comparaison-legacy-zcrud.md` n'ont pas été
  croisées une à une avec ce catalogue ; j'ai seulement relevé les **52 identifiants** du
  registre `iffd/lib/src/presentation/shared/zcrud/z_qa_flags.dart` (985 lignes), dont
  **26** relèvent de l'aire Étude : `folderCard` `folderCardDefault` `folderDetail`
  `subfolderNav` `studyTools` `folderTags` `contentHub` `flashcardList`
  `flashcardListRichReader` `multiEditor` `reviewSession` `reviewRichReader` `srsQuality`
  `flashcardEdition` `flashcardsQuestionsCount` `flashcardTag` `testExamFilter`
  `folderFlashcardsFilter` `exportPdfOptions` `smartNote` `mindmapEdition` `mindmapOutline`
  `mindmapElementText` `mindmapViewer` `mindmapRichReader` `exam`.
- Le relevé `docs/analyses/iffd-migration-2026-08-25/` (8 fichiers, périmé et interrompu)
  **n'a servi à rien ici** : aucun de ses constats n'est repris. Tout ce qui précède a été
  remesuré à `cc276c154`.

---

## Annexe — les 348 canaux jamais cités par IFFD, avec leur `fichier:ligne`

### zcrud_study — 148 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZAiExplanationPort` | `packages/zcrud_study/lib/src/domain/z_ai_explanation_port.dart:67` |
| `ZAiExplanationRequest` | `packages/zcrud_study/lib/src/domain/z_ai_explanation_port.dart:17` |
| `ZAllFeaturesAvailable` | `packages/zcrud_study/lib/src/presentation/z_feature_availability.dart:77` |
| `ZApproachingReminder` | `packages/zcrud_study/lib/src/presentation/z_exam_reminders.dart:93` |
| `ZApproachingReminderTileBuilder` | `packages/zcrud_study/lib/src/presentation/z_exam_reminders_section.dart:32` |
| `ZCardTagIdsProvider` | `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart:62` |
| `ZContentHubLauncher` | `packages/zcrud_study/lib/src/presentation/z_content_hub_launcher.dart:113` |
| `ZContentHubPresenter` | `packages/zcrud_study/lib/src/presentation/z_content_hub_launcher.dart:72` |
| `ZContentHubReference` | `packages/zcrud_study/lib/src/presentation/z_content_hub_reference.dart:68` |
| `ZContentHubScope` | `packages/zcrud_study/lib/src/presentation/z_content_hub_launcher.dart:287` |
| `ZCountBadge` | `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:94` |
| `ZCountBadgeRow` | `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:176` |
| `ZCountBadgeSpec` | `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:71` |
| `ZDailyDayLabelBuilder` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:97` |
| `ZDailyTasksChrome` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_reference.dart:209` |
| `ZDailyTasksReference` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_reference.dart:75` |
| `ZDailyTasksView` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:212` |
| `ZDefaultExamCard` | `packages/zcrud_study/lib/src/presentation/z_default_exam_card.dart:44` |
| `ZDefaultMindmapCard` | `packages/zcrud_study/lib/src/presentation/z_default_mindmap_card.dart:90` |
| `ZDraftEntry` | `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor_controller.dart:58` |
| `ZDueCardsTaskBuilder` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:103` |
| `ZEditingMode` | `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor_controller.dart:47` |
| `ZEducationQuotaInfo` | `packages/zcrud_study/lib/src/domain/z_education_quota_info.dart:20` |
| `ZExamDateLabeler` | `packages/zcrud_study/lib/src/presentation/z_exam_editor.dart:65` |
| `ZExamDatePicker` | `packages/zcrud_study/lib/src/presentation/z_exam_editor.dart:55` |
| `ZExamRemindersSection` | `packages/zcrud_study/lib/src/presentation/z_exam_reminders_section.dart:49` |
| `ZExamTaskBuilder` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:107` |
| `ZExamTimePicker` | `packages/zcrud_study/lib/src/presentation/z_exam_editor.dart:62` |
| `ZFadedOverflow` | `packages/zcrud_study/lib/src/presentation/z_faded_overflow.dart:52` |
| `ZFeatureAvailability` | `packages/zcrud_study/lib/src/presentation/z_feature_availability.dart:41` |
| `ZFeatureAvailabilityScope` | `packages/zcrud_study/lib/src/presentation/z_feature_availability.dart:149` |
| `ZFlashcardBatchCommit` | `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart:68` |
| `ZFlashcardCardReference` | `packages/zcrud_study/lib/src/presentation/z_flashcard_card_reference.dart:53` |
| `ZFlashcardGeneratedCallback` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:78` |
| `ZFlashcardGenerationController` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:84` |
| `ZFlashcardGenerationLabels` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:124` |
| `ZFlashcardGenerationLauncher` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:868` |
| `ZFlashcardGenerationMessages` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:61` |
| `ZFlashcardGenerationPort` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:289` |
| `ZFlashcardGenerationRequest` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:113` |
| `ZFlashcardGenerationScope` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:841` |
| `ZFlashcardGenerationSheet` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:214` |
| `ZFlashcardGenerationStatus` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:41` |
| `ZFlashcardListItemStyle` | `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart:185` |
| `ZFlashcardPreview` | `packages/zcrud_study/lib/src/presentation/z_flashcard_preview.dart:37` |
| `ZFlashcardTagConfirmSheet` | `packages/zcrud_study/lib/src/presentation/z_flashcard_tag_confirm_sheet.dart:33` |
| `ZFlashcardTileContentBuilder` | `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart:198` |
| `ZFolderCardReference` | `packages/zcrud_study/lib/src/presentation/z_folder_card_reference.dart:51` |
| `ZGenerationSourceOption` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:62` |
| `ZGenerationSourceResolver` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:98` |
| `ZItemActionsMenuBuilder` | `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:275` |
| `ZMapFeatureAvailability` | `packages/zcrud_study/lib/src/presentation/z_feature_availability.dart:94` |
| `ZMaterialSectionsBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:90` |
| `ZMaterialSlotBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:115` |
| `ZMembershipRole` | `packages/zcrud_study/lib/src/domain/z_study_membership.dart:22` |
| `ZMindmapGenerationPort` | `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart:189` |
| `ZMindmapGenerationRequest` | `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart:81` |
| `ZMindmapSourceRef` | `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart:49` |
| `ZMultiFlashcardDraftController` | `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor_controller.dart:70` |
| `ZMultiFlashcardGeneration` | `packages/zcrud_study/lib/src/presentation/z_multi_flashcard_editor.dart:102` |
| `ZNoteSummaryPort` | `packages/zcrud_study/lib/src/domain/z_note_summary_port.dart:68` |
| `ZNoteSummaryRequest` | `packages/zcrud_study/lib/src/domain/z_note_summary_port.dart:16` |
| `ZPodcastGenerationPort` | `packages/zcrud_study/lib/src/domain/z_podcast_generation_port.dart:131` |
| `ZPodcastGenerationRequest` | `packages/zcrud_study/lib/src/domain/z_podcast_generation_port.dart:36` |
| `ZPublicStudyFolder` | `packages/zcrud_study/lib/src/domain/z_public_study_folder.dart:16` |
| `ZRailItem` | `packages/zcrud_study/lib/src/presentation/z_rail_item.dart:40` |
| `ZRemindersComputed` | `packages/zcrud_study/lib/src/presentation/z_exam_reminders_section.dart:41` |
| `ZRenderFadedOverflow` | `packages/zcrud_study/lib/src/presentation/z_faded_overflow.dart:95` |
| `ZReportStatus` | `packages/zcrud_study/lib/src/domain/z_study_folder_report.dart:15` |
| `ZResolvedGenerationSource` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:43` |
| `ZSectionedStudySliver` | `packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart:175` |
| `ZShareLink` | `packages/zcrud_study/lib/src/domain/z_share_link.dart:23` |
| `ZSourceAcquisitionGesture` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:100` |
| `ZStudyCardChrome` | `packages/zcrud_study/lib/src/presentation/z_study_card_reference.dart:114` |
| `ZStudyDocumentCard` | `packages/zcrud_study/lib/src/presentation/z_study_document_card.dart:29` |
| `ZStudyFolderReport` | `packages/zcrud_study/lib/src/domain/z_study_folder_report.dart:43` |
| `ZStudyMembership` | `packages/zcrud_study/lib/src/domain/z_study_membership.dart:51` |
| `ZStudyMindmapMode` | `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart:61` |
| `ZStudyMindmapSection` | `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart:76` |
| `ZStudyModerationPort` | `packages/zcrud_study/lib/src/domain/z_study_moderation_port.dart:28` |
| `ZStudySessionCelebrationBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:104` |
| `ZStudySessionChrome` | `packages/zcrud_study/lib/src/presentation/z_study_session_reference.dart:74` |
| `ZStudySessionCounterBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:86` |
| `ZStudySessionGradingBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:95` |
| `ZStudySessionGradingSlotBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart:110` |
| `ZStudySessionHeaderBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:80` |
| `ZStudySessionHost` | `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart:120` |
| `ZStudySessionLabels` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:113` |
| `ZStudySessionPhase` | `packages/zcrud_study/lib/src/presentation/z_study_session_slices.dart:47` |
| `ZStudySessionProgress` | `packages/zcrud_study/lib/src/presentation/z_study_session_slices.dart:79` |
| `ZStudySessionReference` | `packages/zcrud_study/lib/src/presentation/z_study_session_reference.dart:32` |
| `ZStudySessionResultBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart:87` |
| `ZStudySessionScaffold` | `packages/zcrud_study/lib/src/presentation/z_study_session_scaffold.dart:64` |
| `ZStudySessionSlices` | `packages/zcrud_study/lib/src/presentation/z_study_session_slices.dart:139` |
| `ZStudySessionSummaryBuilder` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:101` |
| `ZStudySessionView` | `packages/zcrud_study/lib/src/presentation/z_study_session_view.dart:141` |
| `ZStudySharingAcl` | `packages/zcrud_study/lib/src/domain/z_study_sharing_acl.dart:43` |
| `ZStudySharingExtension` | `packages/zcrud_study/lib/src/domain/z_study_sharing_extension.dart:39` |
| `ZStudySharingPort` | `packages/zcrud_study/lib/src/domain/z_study_sharing_port.dart:37` |
| `ZSubfolderAccentPastille` | `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:28` |
| `ZSubfolderItemActionBuilder` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart:73` |
| `ZSubfolderItemBuilder` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart:50` |
| `ZSubfolderItemContentBuilder` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_renderer.dart:63` |
| `ZSubfolderLayoutScope` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart:189` |
| `ZSubfolderNarrowMode` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart:233` |
| `ZSubfolderNarrowNav` | `packages/zcrud_study/lib/src/presentation/z_subfolder_narrow_nav.dart:26` |
| `ZSubfolderNavRenderRequest` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_renderer.dart:75` |
| `ZSubfolderNavRenderer` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_renderer.dart:104` |
| `ZSubfolderNavRendererScope` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_renderer.dart:115` |
| `ZSubfolderSelectionController` | `packages/zcrud_study/lib/src/presentation/z_subfolder_selection_controller.dart:53` |
| `ZSubfolderSelectorBar` | `packages/zcrud_study/lib/src/presentation/z_subfolder_selector_bar.dart:90` |
| `ZSubfolderSurface` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart:147` |
| `ZSuggestionSemanticLabel` | `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart:65` |
| `ZTagSemanticLabel` | `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart:42` |
| `ZTagUsageCount` | `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart:39` |
| `ZUnknownTaskBuilder` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:115` |
| `zAccentSlot` | `packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart:536` |
| `zClampGenerationCount` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart:39` |
| `zDailyTasksChromeOf` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_reference.dart:312` |
| `zDefaultDocumentFallbackIcon` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:124` |
| `zDefaultDocumentFormatIcons` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:92` |
| `zDefaultDocumentReferenceIcon` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:83` |
| `zDefaultGenerationCount` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart:30` |
| `zDefaultMindmapReferenceIcon` | `packages/zcrud_study/lib/src/presentation/z_default_mindmap_card.dart:61` |
| `zDefaultNoteReferenceIcon` | `packages/zcrud_study/lib/src/presentation/z_default_note_card.dart:59` |
| `zDocumentFormatKeyCandidates` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:133` |
| `zEvenTypesDistribution` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart:55` |
| `zExamAsApproaching` | `packages/zcrud_study/lib/src/presentation/z_exam_reminders.dart:66` |
| `zFlashcardsSectionKey` | `packages/zcrud_study/lib/src/presentation/z_flashcard_reorder.dart:54` |
| `zLookupDocumentFormatColor` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:170` |
| `zMenuEntryIdForKind` | `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:119` |
| `zMindmapNodeCount` | `packages/zcrud_study/lib/src/presentation/z_default_mindmap_card.dart:69` |
| `zMirrorIfNeeded` | `packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart:521` |
| `zNormalizeTypesDistribution` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart:97` |
| `zRailItemFallbackWidth` | `packages/zcrud_study/lib/src/presentation/z_rail_item.dart:23` |
| `zReadableTypeTint` | `packages/zcrud_study/lib/src/presentation/z_default_flashcard_card.dart:150` |
| `zReorderFlashcards` | `packages/zcrud_study/lib/src/presentation/z_flashcard_reorder.dart:81` |
| `zReorderIds` | `packages/zcrud_study/lib/src/presentation/z_reorder_ids.dart:28` |
| `zResolveCardShadowDecoration` | `packages/zcrud_study/lib/src/presentation/z_folder_card.dart:779` |
| `zResolveDocumentFormatIcon` | `packages/zcrud_study/lib/src/presentation/z_default_document_card.dart:151` |
| `zResolveSubfolderNav` | `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_renderer.dart:142` |
| `zReviewModeForKind` | `packages/zcrud_study/lib/src/presentation/z_study_session_mode.dart:52` |
| `zSessionQueueIdentity` | `packages/zcrud_study/lib/src/presentation/z_study_session_slices.dart:177` |
| `zStudyCardChromeOf` | `packages/zcrud_study/lib/src/presentation/z_study_card_reference.dart:181` |
| `zStudyDayOf` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:124` |
| `zStudyIsSameDay` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:154` |
| `zStudySessionChromeOf` | `packages/zcrud_study/lib/src/presentation/z_study_session_reference.dart:132` |
| `zStudyWeekDays` | `packages/zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:134` |

### zcrud_study_kernel — 40 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZApproachingExam` | `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart:119` |
| `ZCascadeEdge` | `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart:40` |
| `ZCascadeRegistry` | `packages/zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart:88` |
| `ZCivilDayOf` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:59` |
| `ZDailyStudyTask` | `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart:41` |
| `ZDueCardsTask` | `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart:50` |
| `ZExamTask` | `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart:79` |
| `ZFlashcardTagExtensionParser` | `packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart:53` |
| `ZFolderContentsOrder` | `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart:115` |
| `ZFolderContentsOrderExtensionParser` | `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart:101` |
| `ZFolderExtensionParser` | `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart:72` |
| `ZKeyHash` | `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:34` |
| `ZPodcastFreshness` | `packages/zcrud_study_kernel/lib/src/domain/z_podcast_freshness.dart:15` |
| `ZPodcastMode` | `packages/zcrud_study_kernel/lib/src/domain/z_podcast_mode.dart:13` |
| `ZPodcastSourceKind` | `packages/zcrud_study_kernel/lib/src/domain/z_podcast_source_kind.dart:14` |
| `ZPodcastStatus` | `packages/zcrud_study_kernel/lib/src/domain/z_podcast_status.dart:24` |
| `ZSessionCandidate` | `packages/zcrud_study_kernel/lib/src/domain/z_session_candidate.dart:29` |
| `ZSessionConfigExtensionParser` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart:47` |
| `ZStreakAdvance` | `packages/zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:42` |
| `ZStreakOutcome` | `packages/zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:20` |
| `ZStudyDocumentRef` | `packages/zcrud_study_kernel/lib/src/domain/z_study_document_ref.dart:71` |
| `ZStudyNoteRef` | `packages/zcrud_study_kernel/lib/src/domain/z_study_note_ref.dart:45` |
| `ZStudyPodcast` | `packages/zcrud_study_kernel/lib/src/domain/z_study_podcast.dart:72` |
| `ZStudyPodcastExtensionParser` | `packages/zcrud_study_kernel/lib/src/domain/z_study_podcast.dart:66` |
| `ZStudyRepository` | `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart:52` |
| `ZStudySessionConfig` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart:52` |
| `ZStudySessionResult` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart:41` |
| `ZStudySessionSelector` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_selector.dart:34` |
| `ZStudyStreak` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:148` |
| `ZSuggestedTag` | `packages/zcrud_study_kernel/lib/src/domain/z_suggested_tag.dart:35` |
| `ZUnorderedPlacement` | `packages/zcrud_study_kernel/lib/src/domain/apply_order.dart:16` |
| `zAdvanceStreak` | `packages/zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:130` |
| `zCivilDayNumber` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:134` |
| `zFnv1a32` | `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:68` |
| `zFormatCivilDay` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:73` |
| `zIsCivilDay` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:101` |
| `zIsGradedMode` | `packages/zcrud_study_kernel/lib/src/domain/z_advance_streak.dart:84` |
| `zLocalCivilDay` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:70` |
| `zParseCivilDayNumber` | `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart:109` |
| `zSectionKey` | `packages/zcrud_study_kernel/lib/src/domain/z_section_key.dart:52` |

### zcrud_flashcard — 58 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZChoicesFieldWidget` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_choices_field_widget.dart:39` |
| `ZConversationSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:119` |
| `ZCustomSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:191` |
| `ZDocumentSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:154` |
| `ZFlashcardAnswerEvaluation` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_answer_evaluation_port.dart:157` |
| `ZFlashcardAnswerEvaluationPort` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_answer_evaluation_port.dart:218` |
| `ZFlashcardAnswerEvaluationRequest` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_answer_evaluation_port.dart:58` |
| `ZFlashcardApi` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart:9` |
| `ZFlashcardBrowseFilters` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:293` |
| `ZFlashcardContentBuilder` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart:41` |
| `ZFlashcardDefaultContent` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart:51` |
| `ZFlashcardEditingScope` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editing_scope.dart:25` |
| `ZFlashcardEditionFields` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editors.dart:87` |
| `ZFlashcardEditionMessages` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_edition_validator.dart:21` |
| `ZFlashcardEditorKind` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editor_config.dart:16` |
| `ZFlashcardExtensionParser` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:53` |
| `ZFlashcardFieldConfig` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_editor_config.dart:33` |
| `ZFlashcardHintPort` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_hint_port.dart:120` |
| `ZFlashcardHintRequest` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_hint_port.dart:48` |
| `ZFlashcardMarkdownContent` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_markdown_content.dart:56` |
| `ZFlashcardQuestionTypeBadgeBuilder` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:84` |
| `ZFlashcardRepository` | `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart:76` |
| `ZFlashcardRepositoryLog` | `packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart:60` |
| `ZFlashcardReviewCardHalfTurn` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:73` |
| `ZFlashcardReviewCardMinTarget` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:76` |
| `ZFlashcardReviewCardPerspective` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:69` |
| `ZFlashcardSearchField` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:264` |
| `ZFlashcardSortMode` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_sort.dart:27` |
| `ZFlashcardSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:30` |
| `ZFlashcardTestFilters` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:107` |
| `ZFlashcardTypeFieldWidget` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_type_field_widget.dart:27` |
| `ZFlashcardTypeLabel` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_type_field_widget.dart:24` |
| `ZHintPenaltyPolicy` | `packages/zcrud_flashcard/lib/src/domain/z_hint_penalty.dart:42` |
| `ZMasteryLevel` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:34` |
| `ZNoteSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:93` |
| `ZRepetitionInfoExtensionParser` | `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart:73` |
| `ZSessionCategories` | `packages/zcrud_flashcard/lib/src/domain/z_session_categorization.dart:30` |
| `ZSrsScheduler` | `packages/zcrud_flashcard/lib/src/domain/z_srs_scheduler.dart:31` |
| `ZStudySessionConfigFlashcardX` | `packages/zcrud_flashcard/lib/src/domain/z_study_session_config_flashcard_x.dart:20` |
| `ZTrueFalseFieldWidget` | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_true_false_field_widget.dart:17` |
| `zApplyBrowseFilters` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:362` |
| `zApplyHintCeiling` | `packages/zcrud_flashcard/lib/src/domain/z_hint_penalty.dart:110` |
| `zApplyTestFilters` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:206` |
| `zCategorize` | `packages/zcrud_flashcard/lib/src/domain/z_session_categorization.dart:91` |
| `zCorrectChoiceIndexes` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:66` |
| `zDrawQuestions` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:461` |
| `zDuplicateFlashcardForEditing` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_duplicate.dart:54` |
| `zEvaluateLocally` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:96` |
| `zFlashcardSearchText` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_search_text.dart:82` |
| `zHintCeilingFloor` | `packages/zcrud_flashcard/lib/src/domain/z_hint_penalty.dart:79` |
| `zIndexSrsById` | `packages/zcrud_flashcard/lib/src/domain/z_session_categorization.dart:56` |
| `zIsLocallyEvaluatedType` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:36` |
| `zIsSingleChoiceQcm` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:56` |
| `zMasteryLevelOf` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:75` |
| `zMatchesSourceKind` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:174` |
| `zReduceMotionOf` | `packages/zcrud_flashcard/lib/src/presentation/z_reduce_motion.dart:57` |
| `zShuffleChoices` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:511` |
| `zSortFlashcards` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_sort.dart:53` |

### zcrud_session — 63 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZCardAdvanceBehavior` | `packages/zcrud_session/lib/src/presentation/z_card_advance_behavior.dart:17` |
| `ZCelebrationSpec` | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:82` |
| `ZCorrectionVisibility` | `packages/zcrud_session/lib/src/presentation/z_correction_visibility.dart:29` |
| `ZCorrectionVisibilityX` | `packages/zcrud_session/lib/src/presentation/z_correction_visibility.dart:45` |
| `ZDefaultFeedbackBank` | `packages/zcrud_session/lib/src/presentation/z_session_feedback_bank.dart:51` |
| `ZExamAnswerCallback` | `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart:124` |
| `ZExamScoringPort` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:218` |
| `ZExamViewPhase` | `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart:105` |
| `ZFeedbackBank` | `packages/zcrud_session/lib/src/presentation/z_session_feedback_bank.dart:38` |
| `ZFeedbackThresholds` | `packages/zcrud_session/lib/src/domain/z_session_feedback.dart:48` |
| `ZFeedbackTier` | `packages/zcrud_session/lib/src/domain/z_session_feedback.dart:32` |
| `ZLinearSessionState` | `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart:133` |
| `ZListSessionView` | `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart:128` |
| `ZProgressRingsData` | `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:27` |
| `ZQualityBreakdownCoverage` | `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart:25` |
| `ZQualityColorKeyResolver` | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:92` |
| `ZQualityLabelKeyResolver` | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:85` |
| `ZSessionCardBuilder` | `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart:128` |
| `ZSessionCardSwiper` | `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart:134` |
| `ZSessionFeedbackText` | `packages/zcrud_session/lib/src/presentation/z_session_feedback_bank.dart:118` |
| `ZSessionItem` | `packages/zcrud_session/lib/src/domain/z_session_item.dart:17` |
| `ZSessionModeKind` | `packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart:63` |
| `ZSessionModeSelector` | `packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart:89` |
| `ZSessionProgressIndicator` | `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:77` |
| `ZSessionProgressStyle` | `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:46` |
| `ZSessionQualityAtIndex` | `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:74` |
| `ZSessionQualityBreakdown` | `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart:41` |
| `ZSessionReviewer` | `packages/zcrud_session/lib/src/domain/z_session_reviewer.dart:26` |
| `ZSessionRuntimeKind` | `packages/zcrud_session/lib/src/domain/z_session_runtime.dart:37` |
| `ZSessionState` | `packages/zcrud_session/lib/src/domain/z_session_state.dart:25` |
| `ZSessionSummaryView` | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:206` |
| `ZSessionSummaryViewState` | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:338` |
| `ZSrsQualityEmphasis` | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:111` |
| `ZStreakBadge` | `packages/zcrud_session/lib/src/presentation/z_streak_badge.dart:25` |
| `ZStudyProgressRings` | `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:78` |
| `ZSummaryCelebration` | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:62` |
| `ZSwipeEmotion` | `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:359` |
| `ZSwipeEmotionIndicator` | `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:380` |
| `ZTestFiltersDialog` | `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:54` |
| `ZTimerDisplay` | `packages/zcrud_session/lib/src/presentation/z_timer_display.dart:21` |
| `ZWhiteExamCorrectionBuilder` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:38` |
| `ZWhiteExamPhase` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:64` |
| `ZWhiteExamQuestionBuilder` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:34` |
| `ZWhiteExamQuestionContext` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:15` |
| `ZWhiteExamResultBuilder` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:42` |
| `ZWhiteExamSessionController` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_controller.dart:53` |
| `ZWhiteExamSessionEngine` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:274` |
| `ZWhiteExamSessionLabels` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:46` |
| `ZWhiteExamSessionView` | `packages/zcrud_session/lib/src/presentation/z_white_exam_session_view.dart:79` |
| `ZWhiteExamSessionViewPhase` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_controller.dart:19` |
| `ZWhiteExamSessionViewState` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_controller.dart:26` |
| `ZWhiteExamState` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:90` |
| `zDefaultAdvanceBehavior` | `packages/zcrud_session/lib/src/presentation/z_card_advance_behavior.dart:46` |
| `zDefaultQualityLabelKey` | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:184` |
| `zFeedbackKeyFor` | `packages/zcrud_session/lib/src/domain/z_session_feedback.dart:136` |
| `zFeedbackText` | `packages/zcrud_session/lib/src/presentation/z_session_feedback_bank.dart:99` |
| `zFeedbackTierFor` | `packages/zcrud_session/lib/src/domain/z_session_feedback.dart:104` |
| `zMasteredCount` | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:190` |
| `zMasteryFallback` | `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:45` |
| `zMasteryLabelKey` | `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:42` |
| `zSessionRuntimeForMode` | `packages/zcrud_session/lib/src/domain/z_session_runtime.dart:64` |
| `zShowStreakToast` | `packages/zcrud_session/lib/src/presentation/z_streak_toast.dart:46` |
| `zStreakToastSeverityFor` | `packages/zcrud_session/lib/src/presentation/z_streak_toast.dart:66` |

### zcrud_exam — 1 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZExamExtensionParser` | `packages/zcrud_exam/lib/src/domain/z_exam.dart:54` |

### zcrud_note — 9 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZNoteAudio` | `packages/zcrud_note/lib/src/domain/z_note_audio.dart:83` |
| `ZNoteContentEncoder` | `packages/zcrud_note/lib/src/domain/z_note_faith_channel.dart:78` |
| `ZNoteContentFaithChannel` | `packages/zcrud_note/lib/src/domain/z_note_faith_channel.dart:84` |
| `ZOpaqueNoteExtension` | `packages/zcrud_note/lib/src/domain/z_opaque_note_extension.dart:83` |
| `ZSmartNoteExtensionParser` | `packages/zcrud_note/lib/src/domain/z_smart_note.dart:62` |
| `ZSmartNoteReader` | `packages/zcrud_note/lib/src/presentation/z_smart_note_reader.dart:29` |
| `zMigrateNoteTables` | `packages/zcrud_note/lib/src/data/z_note_table_migration.dart:61` |
| `zMigrateStickyNote` | `packages/zcrud_note/lib/src/data/z_note_table_migration.dart:51` |
| `zUpgradeLegacyNoteContent` | `packages/zcrud_note/lib/src/data/z_note_table_migration.dart:82` |

### zcrud_mindmap — 16 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZExtensionDecoder` | `packages/zcrud_mindmap/lib/src/domain/z_mindmap_node.dart:22` |
| `ZMindmapApi` | `packages/zcrud_mindmap/lib/src/domain/z_mindmap_api.dart:9` |
| `ZMindmapCellClip` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart:88` |
| `ZMindmapDefaultNodeContent` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart:26` |
| `ZMindmapEditFieldBuilder` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:117` |
| `ZMindmapEditFieldContext` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:65` |
| `ZMindmapEditFieldKind` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:42` |
| `ZMindmapForestCallback` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart:32` |
| `ZMindmapMarkdownContent` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart:37` |
| `ZMindmapMarkdownEditField` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_edit_field.dart:44` |
| `ZMindmapNodeCard` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart:124` |
| `ZMindmapNodeContentBuilder` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:27` |
| `ZMindmapOutlineController` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_controller.dart:35` |
| `ZMindmapOutlineEmptyBuilder` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart:40` |
| `ZMindmapViewController` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_controls.dart:27` |
| `ZMindmapViewLabels` | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_controls.dart:119` |

### zcrud_chat_study — 13 canaux jamais cités par IFFD

| Canal | fichier:ligne |
|---|---|
| `ZChatFlashcardGenerator` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_generator.dart:36` |
| `ZStudyPool` | `packages/zcrud_chat_study/lib/src/domain/z_chat_study_pool.dart:83` |
| `ZStudyPoolRequest` | `packages/zcrud_chat_study/lib/src/domain/z_chat_study_pool.dart:54` |
| `zBuildStudyPool` | `packages/zcrud_chat_study/lib/src/domain/z_chat_study_pool.dart:157` |
| `zChatConversationGenerationRequest` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:137` |
| `zChatConversationProvenance` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:101` |
| `zChatMessageGenerationRequest` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:113` |
| `zChatMessageProvenance` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:89` |
| `zChatMessageStudyText` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:53` |
| `zChatMessagesStudyText` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_mapper.dart:69` |
| `zIsChatStudyLaunchMode` | `packages/zcrud_chat_study/lib/src/domain/z_chat_study_launch.dart:51` |
| `zStampChatProvenance` | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_generator.dart:153` |
| `zStudyPoolKeys` | `packages/zcrud_chat_study/lib/src/domain/z_chat_study_pool.dart:144` |
