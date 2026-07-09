# Schema canonique zcrud (porte de lex_douane)

> Synthese d'architecture pour le futur package `zcrud`, portant les modeles les plus aboutis du module « Etude » de lex_douane (packages `lex_core` = domain, `lex_data` = data, `lex_ui` = presentation). Objectif : extraire le schema canonique **generique** et isoler les points d'extension du domaine douane/lex.

---

## 1. Principes (canonique verrouille + extension par app ; module Etude en dev actif -> versionnage/re-portage)

1. **Canonique verrouille tot, extension par l'app.** lex fige ses schemas avant meme que la logique soit branchee : `StudyFolder` (`packages/lex_core/lib/domain/entities/education/study_folder.dart:15`) porte deja les champs de partage collaboratif V2c (`isPublic`, `sharedWith`, `canBeJoinedWithLink`, `coWorkersCanInviteOthers`, `shareId`) **declares mais inertes** (defauts surs). zcrud reprend cette discipline : figer la structure et les invariants, laisser la logique se brancher plus tard sans migration de schema.

2. **Le domaine ne fuit qu'a des seams identifies.** Le couplage douane est remarquablement contenu : hors `FlashcardArticleSource` (`packages/lex_core/lib/domain/entities/education/flashcard_source.dart:13`) et du mapping wire backend, l'entite `Flashcard` (`.../education/flashcard.dart:37`) n'a **aucun** champ metier douane. Le port est donc a faible risque.

3. **Separation stricte domain / data / ui (Melos).** `lex_core` = entites/enums/contrats purs Dart (aucune dependance Flutter/Firebase/Hive) ; `lex_data` = impl Hive/Firestore ; `lex_ui` = providers/screens. zcrud herite de cette purete : le canonique est du Dart pur, la persistance est une couche adaptable.

4. **Deux modeles offline DISTINCTS a ne jamais confondre.** (A) Donnees utilisateur = sync bidirectionnelle Hive<->Firestore, LWW sur `updated_at`, soft-delete `is_deleted`. (B) Contenu publie = cache-first + download/epinglage + veille checksum, unidirectionnel lecture seule (`comparative_study_repository_impl.dart:70-116`). Les melanger serait une erreur d'architecture.

5. **Module Etude vivant -> versionnage + re-portage.** Le docstring FR-30 de `MindmapTreeOps` (`packages/lex_core/lib/domain/utils/mindmap_tree_ops.dart`) annonce add/move/indent/outdent mais **seuls add/update/delete/find sont codes** : le reparentage (move/indent/outdent) n'existe pas. Le canonique zcrud doit donc etre **versionne** (chaque sous-schema porte son `formatVersion`, cf. `node_context.dart`) et concu pour un **re-portage incrementiel** a mesure que lex avance, sans casser les apps consommatrices.

6. **Extensibilite retro-compatible obligatoire.** Convention transverse (Enforcement Guideline #15) : un champ absent -> defaut sur, jamais d'echec de parsing (`@JsonKey(unknownEnumValue:)`, `@JsonKey(defaultValue:)`, `fromJsonSafe -> null`). Erige en contrat zcrud.

7. **Cohabitation multi-techno.** lex = `json_serializable` code-gen only, **reflectable totalement absent** ; DODLP repose au contraire sur reflectable/GetX. zcrud NE DOIT imposer ni freezed ni reflectable : il partage la **structure et les invariants**, pas la mecanique de serialisation.

---

## 2. Modeles canoniques

### 2.1 ZFlashcard (+ enum type, SRS)

Porte de `Flashcard` (`packages/lex_core/lib/domain/entities/education/flashcard.dart:37`) — modele le plus abouti du module, schema canonique zero-perte partage chat LexIA <-> education (l'ancienne `LexiaFlashcard` a ete retiree, story 5.1b).

**ZFlashcard**

| Champ | Type | Nullable | Sens | Generique / Specifique | Origine lex_douane |
|---|---|---|---|---|---|
| id | String? | oui | `null` => carte ephemere (`isEphemeral`), materialisee par le repo avant ecriture ; sentinelle `'new'` cote route edition | **generique** | flashcard.dart:37 |
| folderId (`collectionId`) | String? | oui | dossier d'appartenance ; cle de partitionnement Firestore/Hive | **generique** | flashcard.dart |
| subFolderId (`subCollectionId`) | String? | oui | sous-dossier (hierarchie 2 niveaux) | **generique** | flashcard.dart |
| type | ZFlashcardType | non | type canonique, `@JsonKey(unknownEnumValue: openQuestion)` | **generique** | flashcard.dart |
| question (`front`) | String | non | enonce (recto), seul champ texte requis | **generique** | flashcard.dart |
| answer (`back`) | String? | oui | reponse libre (openQuestion/exercise/fillBlank/shortAnswer) | **generique** | flashcard.dart |
| isTrue (`boolAnswer`) | bool? | oui | reponse type trueOrFalse | **generique** | flashcard.dart |
| choices | List\<ZChoice\>? | oui | options QCM (min 2 + 1 correct, validation editeur) | **generique** | flashcard.dart |
| explanation | String? | oui | explication pedagogique post-reponse | **generique** | flashcard.dart |
| hint | String? | oui | indice | **generique** | flashcard.dart |
| tagIds | List\<String\> | non | etiquettes, defaut `const []` ; filtrage de session | **generique** | flashcard.dart |
| source | ZFlashcardSource? | oui | provenance polymorphe | **generique en concept ; variant article = specifique** | flashcard.dart / flashcard_source.dart:13 |
| isReadOnly | bool | non | carte issue d'un partage (lecture seule), defaut `false` | **generique** | flashcard.dart |
| createdAt | DateTime? | oui | ISO-8601 ; `null` si ephemere | **generique** | flashcard.dart |
| updatedAt | DateTime? | oui | ISO-8601 ; cle de merge LWW | **generique** | flashcard.dart |

**ZChoice** (porte `FlashcardChoice`, `packages/lex_core/lib/domain/entities/lexia_flashcard.dart:15`) — deja generique, zero dependance.

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| content | String | non | libelle du choix | **generique** | lexia_flashcard.dart:15 |
| isCorrect | bool | non | `@JsonKey(name:'is_correct')` persiste, `isCorrect` camelCase wire chat | **generique** | lexia_flashcard.dart |

**ZFlashcardType** (enum, `packages/lex_core/lib/domain/enums/flashcard_type.dart:13`) — superset union chat ∪ admin, `jsonValue=name` camelCase, `fromJson` defensif -> `openQuestion`.

`multipleChoice`, `trueOrFalse`, `openQuestion`, `exercise`, `fillBlank`, `shortAnswer` — **tous generiques**. Point d'extension recommande : documenter une valeur ouverte `unknown/custom` + fallback defensif.

**ZRepetitionInfo — SRS (porte `RepetitionInfo`, `packages/lex_core/lib/domain/entities/education/repetition_info.dart:14`).** SEPARE deliberement de la carte : partage/duplication n'emportent jamais l'historique d'autrui. Contenant pur, aucune formule (l'algo vit dans `Sm2`).

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| flashcardId | String | non | cle de jointure 1<->1 | **generique** | repetition_info.dart:14 |
| folderId | String | non | dossier denormalise (requetes de session sans jointure) | **generique** | repetition_info.dart |
| interval | int | non | intervalle courant (jours) SM-2 | **generique** | repetition_info.dart |
| repetitions | int | non | reussites consecutives ; 0 apres lapse | **generique** | repetition_info.dart |
| easeFactor | double | non | facteur de facilite, borne [1.3 ; 2.5] (IFFD) | **generique** | repetition_info.dart |
| nextReviewDate | DateTime? | oui | prochaine echeance ; `null` = jamais planifiee ; due = date <= now | **generique** | repetition_info.dart |
| learnedAt | DateTime? | oui | 1re reussite (quality>=3), jamais remis a null sur lapse | **generique** | repetition_info.dart |
| lastQuality | int? | oui | derniere qualite 0-5 | **generique** | repetition_info.dart |

**ZSrs (algorithme, porte `Sm2`, `packages/lex_core/lib/domain/usecases/education/sm2.dart:74`).** Pur, sans etat mutable, horloge injectee (`now`). Constantes injectables via `ZSrsConfig` : `minEaseFactor`/`maxEaseFactor` (1.3/2.5), `defaultEaseFactor` (2.5), `defaultIntervalModifier` (1.0), `overdueBonusFactor` (0.5), `passThreshold` (3). Expose `apply()`, `simulate()`, `previewLabel()`. **Voie d'ecriture UNIQUE** : `reviewCard()` -> `Sm2.apply` (invariant AC6). Enum `Sm2QualityLevel` : `complique(1)`, `difficile(2)`, `ok(3)`, `facile(4)`, `tresFacile(5)`. Interface cible `ZSrsScheduler.apply/simulate` pour brancher FSRS/Leitner.

**ZFlashcardSource** (porte l'union scellee `FlashcardSource`, `flashcard_source.dart:13`). `sealed class` + discriminant `kind`, `toJson` switch exhaustif sans `default`, `FormatException` si `kind` inconnu.

| Variant / champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| `ArticleSource.codeId` | String | non | code juridique/TEC (kind='article') | **douane-specifique** | flashcard_source.dart:13 |
| `ArticleSource.articleId` | String | non | article/noeud SH-TEC ; ouvre la navigation 'article' | **douane-specifique** | flashcard_source.dart |
| `NoteSource.noteId` | String | non | note personnelle (kind='note') | **generique** | flashcard_source.dart |
| `ConversationSource.conversationId` | String | non | conversation LexIA (kind='conversation') | **generique** | flashcard_source.dart |
| `ConversationSource.messageId` | String | non | message precis | **generique** | flashcard_source.dart |
| `DocumentSource.documentId` | String | non | document importe (kind='document') | **generique** | flashcard_source.dart |
| `DocumentSource.page` | int? | oui | page optionnelle | **generique** | flashcard_source.dart |

> Recommandation zcrud : conserver le contrat (discriminant `kind`, switch exhaustif) mais **router les kinds non reconnus vers un variant `ZFlashcardSource.custom(String kind, Map<String,dynamic> payload)`** au lieu de lever — l'app hote branche `article` sans forker le package.

---

### 2.2 ZMindmap / ZMindmapNode (+ tree ops)

Porte de `MindmapNode` (`packages/lex_core/lib/domain/entities/lexia_mindmap.dart:22-41`) et `Mindmap` (`packages/lex_core/lib/domain/entities/education/mindmap.dart:15-38`). Un **seul** noeud canonique, immuable par convention (pas de copyWith, mute uniquement via `MindmapTreeOps` — « schema canonique verrouille 5.1, Enforcement n°3 »).

**ZMindmapNode** (arbre recursif par NESTING, pas par adjacence)

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| id | String | non | UUID v4 (fabrique par `MindmapTreeOps`), cle de reconciliation graphview | **generique** | lexia_mindmap.dart:22 |
| label | String | non | titre court mono-ligne ; vide -> defaut UI | **generique** | lexia_mindmap.dart |
| content | String? | oui | contenu long multiligne, rendu **texte brut** (PAS markdown) ; `''`=efface, `null`=non touche | **generique** (renderer pluggable = extension) | lexia_mindmap.dart |
| children | List\<ZMindmapNode\> | non | enfants imbriques (topologie par nesting) | **generique** | lexia_mindmap.dart |
| level | int | non | cache de profondeur denormalise (racine=0), maintenu par l'appelant | **generique** | lexia_mindmap.dart |
| data (`TPayload?` / `attributes`) | opt. | oui | **PROPOSE** : sac d'extension typé/dynamique pour capacites domaine (audio/sources/RAG/confiance) sans polluer le coeur | **point d'extension** | (cf. ComparativeNode) |

**ZMindmap** (foret titree dans un container ; unifie `Mindmap.nodes` [foret] et `LexiaMindmap.root` [mono-racine cas degenere])

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| id | String | non | UUID v4 de la carte | **generique** | mindmap.dart:15 |
| folderId (`containerId`) | String | non | dossier/container ; cle sous-collection + filtrage stream | **generique** | mindmap.dart |
| title | String | non | titre (defaut UI si vide) | **generique** | mindmap.dart |
| description | String? | oui | recuperee de `LexiaMindmap.description` (absente de Mindmap education) | **generique** | lexia_mindmap.dart:5-20 |
| nodes | List\<ZMindmapNode\> | non | racines de la foret (>=1 garanti par l'UI) ; multi-racine -> super-racine invisible au rendu | **generique** | mindmap.dart |

> Note d'invariant : `Mindmap` ne porte PAS `updatedAt` ni `is_deleted` dans l'entite — metadonnees de sync **HORS-ENTITE** (map Hive / doc Firestore), invariant Story 5.4.

**ZMindmapTreeOps** (porte `MindmapTreeOps`, `packages/lex_core/lib/domain/utils/mindmap_tree_ops.dart:16-178`) — pur, immuable, structural sharing via `identical()`.

Implemente : `updateNode(roots,nodeId,{label,content})` (l.28-44), `addChild(roots,parentId,child)` (l.53-68), `deleteNode(roots,nodeId)` (l.73-107), `findNode` (l.133-140), `newRootNode()` (l.111-117), `newChildNode(parentLevel)` (l.122-128), moteur prive `_mapForest` (l.147-177).

**MANQUANT (dette a porter avec vigilance) :** `moveNode/reparent`, `indentNode/outdentNode`, `reorderChild` — annonces au docstring FR-30 mais **non codes**. A ajouter au canonique avec **recalcul du `level`** du sous-arbre deplace (le `level` est un cache fragile maintenu a la main).

**ZMindmapView** (porte `MindmapView`) : auto-layout `graphview` + `BuchheimWalkerAlgorithm`, `InteractiveViewer` zoom/pan, **aucun drag libre**, mode compact/plein ecran, vue liste semantique a11y indentee par `level`. Extension : injecter un `nodeCardBuilder`/`nodeContentBuilder` pour brancher un rendu de contenu riche/domaine.

---

### 2.3 ZStudyFolder / ZStudySession (organisation + offline-first)

**ZStudyFolder** (porte `StudyFolder`, `packages/lex_core/lib/domain/entities/education/study_folder.dart:15-141`). Container generique multi-type ; **rattachement INVERSE** (chaque item porte `folder_id`, le dossier ne liste jamais ses items) ; hierarchie 2 niveaux max (invariant porte par le **repository**, pas l'entite).

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| id | String | non | UUID v4 (genere cote controller, study_folders_provider.dart:106) | **generique** | study_folder.dart:15 |
| title | String | non | titre affiche | **generique** | study_folder.dart |
| colorKey | String | non | cle de theme couleur (libre, resolue cote UI) | **generique** | study_folder.dart |
| parentId | String? | oui | `null`=racine ; profondeur 2 max validee au repo | **generique** | study_folder.dart |
| ownerId | String | non | uid Firebase (ou `'local'` hors-ligne/anonyme) | **generique** | study_folder.dart |
| archivedAt | DateTime? | oui | soft-archive reversible, DISTINCT du soft-delete | **generique** | study_folder.dart |
| createdAt | DateTime | non | date de creation | **generique** | study_folder.dart |
| updatedAt | DateTime | non | cle LWW ; ici DANS l'entite (divergence vs Mindmap) | **generique** | study_folder.dart |
| isPublic / sharedWith / canBeJoinedWithLink / coWorkersCanInviteOthers / shareId | bool/List/String? | oui | bloc partage V2c **declare mais inerte** | **generique** | study_folder.dart |
| relatedTopics / folderExplanation | List/String? | oui | metadonnees libres (V2c inerte) | **generique** (a pousser dans `extra`) | study_folder.dart |
| countryCode | String? | oui | code pays associe (V2c) | **douane/lex-specifique** (-> `extra`) | study_folder.dart |

**FolderContentCount** (porte, `packages/lex_core/lib/domain/repositories/study_folders_repository.dart`) — rollup multi-type pre-cascade (`subFolders`, `cards`, `repetitions`, `notes`, `mindmaps`), **tous generiques**, non persiste. Chaque nouveau type de contenu ajoute un compteur.

**SmartNote / Mindmap comme autres ZItem** (`packages/lex_core/lib/domain/entities/education/smart_note.dart`) : `SmartNote` = note markdown + piste audio optionnelle (`audioUrl`/`audioPath`/`audioTextHash` = cache TTS). Confirme le pattern **un dossier, N types heterogenes** (`folder_id`/`sub_folder_id` + dates + soft-delete). Asymetrie documentee : `Mindmap` n'a PAS de `subFolderId` (study_folder_detail_provider.dart:120).

**ZStudySessionConfig** (persiste, porte `StudySessionConfig`, `packages/lex_core/lib/domain/entities/education/study_session.dart`)

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| mode | ReviewMode | non | `spaced/learn/list/test/whiteExam/cramming` ; defensif -> `spaced` | **generique** | study_session.dart |
| folderId | String? | oui | dossier cible ; `null`=toutes cartes eligibles | **generique** | study_session.dart |
| tagIds | List\<String\>? | oui | filtre etiquettes | **generique** | study_session.dart |
| types | List\<FlashcardType\>? | oui | filtre types de cartes | **generique** | study_session.dart |
| count | int? | oui | nombre max ; `null`=illimite | **generique** | study_session.dart |

**ZStudySessionState** (runtime, non persiste, porte `StudySessionState` + `StudySessionItem`, `packages/lex_ui/lib/presentation/providers/study_session_provider.dart`) : file `queue` (courante=`first`), `phase` (question|answer), `initialTotal`, `completedCount`, `reviewedCardIds`, `qualityHistogram`, `started`, `finished`, `mutationError`. Politique de reinsertion enfichable `reinsertOffsetFor` (l.144 : complique +2, difficile +4). Deux scopes : `dues` (echeances) vs `ahead` (cycle libre, decision post-archi n°7). Resultat agrege persistable = `StudySessionResult` (mode/total/correct/byQuality).

**Enums de session** : `ReviewMode` (review_mode.dart, seuls spaced/learn ecrivent du SRS), `StudySessionPhase` (question/answer).

**Offline-first (donnees utilisateur).** Hive = source de verite (`jsonEncode` dans une Box generique, **pas de TypeAdapter type**) ; Firestore fire-and-forget ; merge **Last-Write-Wins sur `updated_at`** ; soft-delete via cle **hors-entite `is_deleted`** ; cascade bornee **450 writes/batch** (`study_folders_repository_impl.dart:467-553`). `StudySyncManager` (keepAlive) orchestre le **QUAND** (login + reconnexion deboundee 400ms, best-effort) en deleguant le **COMMENT** (merge/listener) a chaque repo.

---

### 2.4 Types de base & noeud a contenu riche

**ZHierarchyNode (base d'arbre canonique, topologie FLAT).** Le squelette `{id, parentId, sortOrder, depth, levelType, code/numero, designation/titre, contentHash}` est **repete a l'identique** dans `HierarchyNode` (`packages/lex_core/lib/domain/entities/hierarchy_models.dart:194`), `ShNode` (`sh_node.dart:7`), `TecNode` (`tec_node.dart:8`), `ComparativeNode` (`comparative_node.dart:31`) **sans base commune** — c'est LE generique evident a factoriser. `HierarchyNode` est l'aboutissement architectural de lex : **un seul type + enum `levelType`** (`@JsonKey(unknownEnumValue: custom)` + `customLevelName`), qui a **remplace l'heritage** `AbstractModel->...->Article->Alinea->Paragraphe` (hierarchy_models.dart:492+).

| Champ (ZHierarchyNode) | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| id / parentId / sortOrder / depth | String/String?/int/int | mix | topologie FLAT (position via parentId/sortOrder/depth, jamais l'id) | **generique** | hierarchy_models.dart:194 |
| levelType | enum ouvert | non | discriminant, valeur `custom` = extension de taxonomie | **generique** | hierarchy_models.dart |
| customLevelName | String? | oui | libelle libre quand `levelType==custom` (assert le lie) | **generique** | hierarchy_models.dart |
| numero / titre / content / contexte | int?/String? | oui | numerotation + contenu + breadcrumb | **generique** | hierarchy_models.dart |
| contentHash | String? | oui | empreinte de fraicheur (staleness) / cle de cache | **generique** | hierarchy_models.dart |
| badges | List\<String\>? | oui | ids d'annotations resolus contre un registre (`badgeDefinitions`) | **generique** (pattern registre) | tec_node.dart:8 |
| officialReference / codeDesDouanesId / notesLegales / tariffDetails / imageUrl | mix | oui | reference d'acte, taxation, notes SH, illustration IA | **douane-specifique** (slot `details` polymorphe) | hierarchy_models.dart / sh_node.dart / tec_node.dart |
| ragContext | ZSemanticContext? | oui | sous-schema RAG additif versionne | **lex-specifique en contenu, generique en mecanique** | node_context.dart:68 |

**ZSemanticContext — noeud a contenu riche versionne** (porte `NodeContext` + `CrossReference`, `packages/lex_core/lib/domain/entities/node_context.dart:19-158`). **Incarne le mecanisme d'extension recommande** : canal parallele additif, attache par champ nullable, versionne independamment, parse defensivement.

| Champ | Type | Nullable | Sens | Gen./Spe. | Origine |
|---|---|---|---|---|---|
| summary / keywords / thematicTags | String?/List | mix | enrichissement RAG ; `@JsonKey(defaultValue)` => cle absente n'echoue jamais | **mecanique generique** | node_context.dart:19 |
| crossReferences | List\<CrossReference\> | non | renvois `{label, targetNodeId?}` resolus tardivement (arêtes hors-arbre) | **generique** | node_context.dart |
| formatVersion | int | non | **version de sous-schema INDEPENDANTE du noeud parent** | **generique (cle d'extensibilite)** | node_context.dart |
| `fromJsonSafe` | static -> null | — | parsing defensif : malformé => `null`, jamais d'echec du parent | **generique (convention)** | node_context.dart |

> **Piege de nommage a eviter :** `node_content_view.dart` / `node_context_card.dart` / `listen_node_button.dart` operent sur `ComparativeNode`/`NodeContext`/`HierarchyNode` (univers douane/RAG a **adjacence plate** + contenu markdown par `GranularityLevel` + audio), **PAS** sur `MindmapNode` (generique, **nesting + level**, texte brut, aucun audio/RAG). Le canonique zcrud committe sur le **nesting** pour le mindmap et fournit un adaptateur flatten/unflatten si un pont vers l'adjacence est requis.

---

## 3. Frontiere generique vs douane-specifique

**ENTRE dans zcrud (GENERIQUE, a porter tel quel) :**
- Structure de carte (`question/answer/isTrue/choices/explanation/hint`), les 6 `FlashcardType`, `FlashcardChoice`, `tagIds`, `isReadOnly`, timestamps.
- Etat ephemere + **invariant de materialisation** ; **separation carte/SRS** ; `RepetitionInfo` + algo SM-2 complet (`Sm2`/`Sm2QualityLevel`) ; `ReviewMode` ; `StudySessionConfig/State/Result`.
- `MindmapNode {id,label,content?,children,level}` + enveloppes forêt/mono-racine ; `MindmapTreeOps` ; `MindmapView` (auto-layout, vue liste a11y).
- `StudyFolder` comme container (rattachement inverse, copyWith preservant l'integrite, bloc partage inerte) ; `FolderContentCount`.
- Pattern offline-first Hive+Firestore LWW soft-delete ; `StudySyncManager` (separation quand/comment) ; cascade bornee.
- Squelette d'arbre `ZHierarchyNode` ; conventions `formatVersion` + `fromJsonSafe`.
- Pipeline de generation LLM (`Request/Result/Controller/Phase/Outcome/Failure`) et erreurs typees.

**GENERIQUE MAIS A ABSTRAIRE :** le concept de provenance `FlashcardSource` (union scellee, discriminant `kind`) ; variants `note`/`conversation`/`document` reutilisables tels quels ; le modele « contenu publie epingle + veille checksum » (a extraire en `ZPublishedDoc` + `ZDownloadCache`).

**RESTE dans l'app (DOUANE/LEX-SPECIFIQUE, points d'extension) :**
- Variant `FlashcardArticleSource` (`codeId`+`articleId`) et la navigation 'article'.
- Mapping wire backend (`toWireJson`/`toSourcePayload` camelCase, `codeId`/`nodeIds[]`) ; `EducationQuotaInfo` + `FlashcardGenerationErrorKind.quotaExceeded`.
- Chemins de collection nommes `study_folders`/`study_flashcards`/`study_repetitions` ; integration chat `FlashcardBlock` (`:::lexia[Flashcards]`) + `fromChatJson`/`toChatJson`.
- Etude comparative complete : `ComparativeStudy`/`ComparativeNode`/`ComparisonSide`/`ConvergenceSummary`/`FauxAmi` + enums (`AlignmentType`, `GranularityLevel`, `ComparativeLevelType`, `GenerationMode`, `ReviewStatus`, `StalenessReason`).
- Nomenclatures `TecNode`/`ShNode` (taxation, `tariffDetails`, notes) ; veille reglementaire (`amendment_entities`/`translation_entities`, checksum).

**SPECIFIQUE APP (ni douane ni zcrud-core) :** champs de partage V2c, stories/AC references, l10n francaise codee en dur (`Sm2.previewLabel`, libelles `Sm2QualityLevel`).

---

## 4. Mecanisme d'extension recommande

**Options observees EN VRAI dans lex (4 mecanismes) :**

| Mecanisme | Exemple lex | Portee | Verdict |
|---|---|---|---|
| **Union `sealed` a discriminant `kind`** | `FlashcardSource` (flashcard_source.dart:13) | fermee au package | Parfait pour un ensemble **interne** (exhaustivite compilateur), mais **une app tierce ne peut pas ajouter un variant** -> inadapte inter-package |
| **Sous-schema type additif versionne** | `HierarchyNode.ragContext -> NodeContext{formatVersion, fromJsonSafe}` (node_context.dart:68) | ouverte, retro-compatible | **Recommande** : canal parallele, versionne independamment, parse defensivement |
| **Map ouverte non typee** | `TariffDetails.metadata`, `SuggestionAction.payload`, `ScheduledReminder.payload` | ouverte, non typee | Echappatoire utile, mais sans garantie de type |
| **Heritage `@JsonSerializable`** | `AbstractModel->...->Article` (hierarchy_models.dart:492+) | — | **ABANDONNE par lex** au profit de composition + enum `levelType` |

**A REJETER :**
- **Heritage de classes serialisees** : lex l'a essaye puis abandonne. Une base **abstraite FINE sans serialisation** (mixin `ZEntity`/`ZNode`) reste OK ; une hierarchie de classes serialisees, non.
- **Generics `<T extends ZEntity>` comme extension PRIMAIRE** : `json_serializable` gere mal le polymorphisme ; le seul cas generique de lex (`ValuationToolModel.copyToolWith<T>`) a du recourir a un dispatch manuel `if (T == Decision)`. Reserver les generics au **typage des repositories** (`ZRepository<T>`), pas a la serialisation.
- **`sealed` pour la provenance extensible** : ferme a l'extension inter-package. DODLP/IFFD ne peuvent pas ajouter un variant a une `sealed` d'un autre package.

**RECOMMANDATION — mecanisme principal : COMPOSITION + sous-schema type additif versionne**, double d'un champ `extra` ouvert et servi par un **registre**.

Concretement, chaque entite zcrud expose :
1. **Un slot type additif versionne** `ZExtension?` — pattern `HierarchyNode.ragContext` : `formatVersion` propre + `fromJsonSafe` (repli `null`, jamais throw) + `@JsonKey(defaultValue)`. Extension RICHE retro-compatible.
2. **Un champ `Map<String,dynamic> extra`** (defaut `const {}`, `@JsonKey(includeIfNull:false)`) — echappatoire non typee (pattern `TariffDetails.metadata`).
3. **Un `ZTypeRegistry` / `ZSourceRegistry.register(kind, fromJson, toJson)`** — pour la provenance et les types ouverts : chaque app enregistre les `fromJson/toJson` de ses variants (article douane), levant la frontiere inter-package qu'une `sealed` interdit.
4. **Enums ouverts** — valeur `custom` + `customLevelName` (pattern `HierarchyLevelType`), `@JsonKey(unknownEnumValue:)` obligatoire sur tous les enums zcrud.

**Justification vs contraintes lex ET DODLP :** ce mecanisme (a) n'exige ni `freezed` ni `reflectable` (lex = code-gen only, reflectable **absent** ; DODLP = reflectable/GetX) ; (b) est retro-compatible sans reflexion runtime (compatible `json_serializable`) ; (c) partage la STRUCTURE et les INVARIANTS sans imposer la mecanique de (de)serialisation. zcrud expose donc des **contrats abstraits** (`ZEntity`/`ZSyncable`/`ZNode`) + un **registre**, et laisse chaque app choisir sa techno de generation.

---

## 5. Conventions imposees

- **PAS de freezed** (2 fichiers sur ~90 seulement, usage hybride) ; **Equatable jamais** (0 occurrence). Convention dominante : **`@JsonSerializable` PUR** — `final` + constructeur `const` + `factory X.fromJson => _$XFromJson` + `toJson => _$XToJson` + `part 'x.g.dart'`.
- **Serialisation :** `@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)` pour les entites persistees ; dates ISO-8601. **Valeurs d'enum en camelCase** (`jsonValue = name`) MEME quand les champs sont snake_case (« toute divergence de casse = bug de contrat »). **Incoherence a uniformiser :** `MindmapNode`/`LexiaMindmap` sont en camelCase brut (pas de `fieldRename`), contrairement aux entites education.
- **copyWith ECRIT A LA MAIN**, motif `x ?? this.x` **sans sentinelle** -> un champ nullable ne peut pas etre remis a `null` (limitation documentee dans `StudyFolder.copyWith`, assumee). `Flashcard`/`RepetitionInfo`/`MindmapNode` **n'ont PAS de copyWith** (reconstruction explicite au repo `_rebuild` / editeur). zcrud devrait fournir un copyWith genere pour reduire la friction, tout en gardant les factories de wire.
- **`==`/`hashCode` a la main UNIQUEMENT ou l'egalite de valeur est requise** (`HierarchyNode`, `NodeContext`, `CrossReference`, `ScheduledReminder`, `Failure`) via `Object.hash`/`hashAll`. `Flashcard`/`StudyFolder`/`Mindmap` = identite par reference (pas de `==`).
- **`Either<Failure,T>` (dartz) sur TOUS les contrats repository** ; `Unit` pour void ; **`Stream<List<T>>` NUS** (un flux ne s'enveloppe pas dans Either). Hierarchie `Failure` maison : `DomainFailure`, `CacheFailure`, `NotFoundFailure`, `ServerFailure`, + `FlashcardGenerationFailure` (porteur `kind`/`retryAfter`/`quota`), `==`/`hashCode` manuels.
- **IDs = `String` opaques.** `id` non-nullable pour le persiste ; **nullable pour l'ephemere** (`Flashcard.isEphemeral`). ULID valide (`isUlid`, Crockford base32, 26 chars) mais **jamais genere cote Dart ni parse** (position = `parentId/sortOrder/depth`). UUID v4 pour folders/mindmaps.
- **Desserialisation DEFENSIVE systematique :** `unknownEnumValue`, `@JsonKey(defaultValue:)`, `fromJsonSafe -> null`, helpers tolerants (`_parseHierarchyNumero` accepte int|String). Un champ absent/corrompu ne fait JAMAIS echouer le parent (Enforcement Guideline #15).
- **Metadonnees de sync HORS-ENTITE** pour les entites qui ne veulent pas polluer leur JSON metier (`Mindmap` : `updated_at`/`is_deleted` en map). Standardiser un `ZSyncMeta` hors-schema.
- **Double-wire :** `fromJson/toJson` (persiste snake_case) vs `fromChatJson/toChatJson` (wire chat camelCase). Formaliser des **codecs nommes `ZCodec`** plutot qu'un unique `toJson`.
- **Riverpod 3** codegen (`@riverpod` / `@Riverpod(keepAlive:true)`, `part '*.g.dart'`) ; keepAlive pour repos et controllers-dispatchers (evite `UnmountedRefException`/`AsyncLoading` bloque durant le gap async).
- **RTL / a11y :** `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`, `PositionedDirectional` partout ; `Semantics` explicites + `ExcludeSemantics` sur le visuel (vue liste = surface a11y de reference) ; libelles externalises `context.l10n`. Les entites sont des `String` opaques, RTL-neutres.
- **Purete des couches :** `lex_core` = pur Dart (aucune dep Flutter/Firebase/Hive) ; Firebase/Hive uniquement en `lex_data`. Invariants metier (2 niveaux, materialisation, avancement SM-2) portes par le **repository**, jamais par l'entite.

---

## 6. Strategie de portage & re-synchronisation (module Etude vivant)

1. **Committer un socle « le plus avance » d'abord.** Porter en priorite `Flashcard`+`RepetitionInfo`+`Sm2` (dimension la plus consolidee, story 5.1b/AC6) et `MindmapNode`+`MindmapTreeOps` (schema verrouille 5.1). Ces schemas sont les plus stables.

2. **Versionner chaque sous-schema (`formatVersion`) et le canonique global.** Le module Etude evolue (reparentage mindmap absent, generation LLM story 10.1, partage V2c a venir). Chaque `ZExtension` porte son `formatVersion` independant (pattern `NodeContext`) ; un document historique sans un champ deserialize sur le defaut, jamais d'echec.

3. **Additif seulement.** Toute evolution portee de lex doit etre **retro-compatible** : nouveaux champs nullable ou `@JsonKey(defaultValue)`, jamais de renommage/suppression sans passage de version. C'est la discipline transverse d'Enforcement Guidelines.

4. **Figer tot les champs a venir (pattern V2c inerte).** Declarer des maintenant les champs de partage/collaboration avec defauts surs (comme `StudyFolder`) pour eviter les migrations quand la logique sera branchee.

5. **Combler les manques cotes lors du portage, en les signalant.** Ajouter `moveNode/indent/outdent` (recalcul de `level`) au moment du port, en les marquant comme extensions du canonique zcrud (au-dela de ce que lex implemente), pour ne pas re-diverger.

6. **Re-portage traçable.** Chaque entite zcrud garde en commentaire son **origine `fichier:ligne`** lex (comme les tableaux ci-dessus) pour permettre un diff cible lors des re-synchronisations futures.

7. **Registre plutot que fork.** Comme l'extension passe par `ZTypeRegistry`/`ZSourceRegistry`, l'app douane branche ses variants (`article`) et ses codecs wire **sans modifier zcrud** — donc une mise a jour du canonique n'ecrase jamais le code douane.

---

## 7. Mapping repository / persistence

**Contrat canonique de reference** (porte `StudyFoldersRepository`, `study_folders_repository.dart` ; miroir de `FlashcardsRepository` `flashcards_repository.dart:20`, `MindmapsRepository` `mindmaps_repository.dart:23-51`, `RepetitionRepository` `repetition_repository.dart:20`, `SmartNotesRepository`) :

**`ZRepository<T extends ZEntity>` (Either\<ZFailure,T\>) :**
- `Stream<List<T>> dataChanges` — flux global, **seed immediat depuis Hive** puis broadcast (evite `AsyncLoading` bloque).
- `Stream<List<T>> streamByContainer(collectionId)` — flux filtre derive.
- `Future<Either<ZFailure,List<T>>> getAll/scoped` ; `getById` (exclut soft-deleted).
- `Future<Either<ZFailure,T>> save(item,{collectionId})` — **materialise l'ephemere** (id UUID v4 + folderId + dates) et **rejette `Left(DomainFailure)`** si pas de cible (invariant AC6) ; carte persistee -> update en place (`updatedAt=now`).
- `Future<Either<ZFailure,Unit>> softDelete(id)` — `is_deleted=true`.
- `Future<Either<ZFailure,Unit>> sync()` — pull one-shot + merge LWW ; **`Right(unit)` si deconnecte**.
- `void dispose()`.

**Contrats specialises a preserver :**
- `RepetitionRepository` : `initRepetition{flashcardId,folderId}` (**SEUL write hors `Sm2.apply`**, etat neuf) ; `reviewCard(current,quality,{now})` applique `Sm2.apply` **en interne** (voie d'avancement UNIQUE, aucun setter SM-2 brut) ; `getDue({now})`.
- `StudyFoldersRepository` : `saveFolder` **valide l'invariant 2 niveaux** (`Left(DomainFailure)` si depth>=3, sans ecrire) ; `countContents -> FolderContentCount` avant cascade ; `deleteFolder` en **cascade soft-delete bornee** (450 writes/batch).
- **Generation** : `EducationGenerationRepository.generateFlashcards({request}) -> Either<FlashcardGenerationFailure, FlashcardGenerationResult>` (mappe statut HTTP/code backend -> `FlashcardGenerationErrorKind`).

**Impl offline-first (a abstraire derriere `ZLocalStore`/`ZRemoteStore`) :**
- **Hive = source de verite** : Box generique, valeur = `jsonEncode(toJson() + is_deleted)`, **pas de TypeAdapter type**. (Extension : abstraire pour supporter Isar/Drift/SQLite sans toucher le domaine.)
- **Firestore = sync fire-and-forget** : sous-collection `users/{uid}/study_folders/{folderId}/flashcards/{cardId}` (le SRS va en top-level `users/{uid}/study_repetitions/{cardId}` — **jamais dans le sous-arbre partageable**). `try/catch` silencieux (`debugPrint` en debug).
- **Merge LWW** sur `updated_at` ; soft-delete `is_deleted` (cle hors-entite ou champ selon l'entite) ; `Mindmap`/`RepetitionInfo` merge la map **telle quelle** (jamais `Sm2.apply` a la sync).
- **`ZSyncOrchestrator`** (porte `StudySyncManager`, keepAlive) : declenche `sync()` d'un **ensemble de repos enregistres** sur login + reconnexion deboundee, best-effort (un echec n'arrete pas les autres). Separe strictement le **quand** (orchestrateur) du **comment** (merge/listener per-repo). Gate par un flag d'activation.

**Second modele offline (contenu publie, `ZPublishedDocRepository`)** — a garder DISTINCT (porte `ComparativeStudyRepository`, `comparative_study_repository_impl.dart:70-116`) : `watch/getDetails` cache-first ; `downloadForOffline()` = fetch JSON + `markDownloaded(checksum)` ; `isDownloaded`/`getLocalChecksum` ; predicat pur `isStale(localChecksum, remoteChecksum)`. Lecture seule, unidirectionnel.

**Providers** (keepAlive) : `flashcardsRepository`, `mindmapsRepository`, `educationGenerationRepositoryProvider`, `FlashcardGenerationController` (family par `targetFolderId`) ; families UI `mindmapByIdProvider`, `folderMindmapsProvider`. Les providers deplient l'Either et re-throw une Exception typee (`only_throw_errors`) pour alimenter `AsyncValue.error`.

---

## 8. Questions ouvertes pour l'architecture

1. **Uniformisation de la casse.** `MindmapNode`/`LexiaMindmap` sont en camelCase brut alors que les entites education sont en `fieldRename: snake`. zcrud doit-il tout uniformiser en snake_case (avec migration/lecture tolerante) ou preserver les deux frontieres via `ZCodec` ?

2. **copyWith genere vs manuel.** Fournir un copyWith genere (build/freezed limite a `ZFlashcard`/`ZRepetitionInfo`) pour reduire la friction de reconstruction — au risque de reintroduire freezed que lex evite ? Ou generer un copyWith **avec sentinelle** custom pour permettre le reset a `null` (que lex interdit volontairement) ?

3. **Metadonnees de sync : dans l'entite ou hors-entite ?** `StudyFolder` porte `updatedAt` DANS l'entite ; `Mindmap` le met HORS-ENTITE. Diverence a trancher : standardiser un `ZSyncMeta` hors-schema pour tout, ou tolerer les deux ?

4. **Topologie d'arbre unique ou double ?** zcrud doit-il exposer les DEUX (`ZTreeNode` nesting pour mindmap + `ZHierarchyNode` flat pour hierarchie juridique) avec adaptateur flatten/unflatten, ou forcer une seule representation ?

5. **`level` : cache stocke ou derive ?** Le `level` du mindmap est un cache fragile maintenu a la main (`newChildNode`). Le securiser par recalcul systematique (surtout pour le reparentage manquant) ou le rendre derive a la volee ?

6. **Portee du registre d'extension.** Faut-il un unique `ZTypeRegistry` global, ou des registres par axe (`ZSourceRegistry`, `ZNodeTypeRegistry`, `ZSrsSchedulerRegistry`) ? Impact sur la testabilite et l'isolation inter-app (lex vs DODLP).

7. **Interface SRS pluggable.** Formaliser `ZSrsScheduler.apply/simulate` + `ZSrsConfig` des maintenant (pour FSRS/Leitner/Anki) ou porter d'abord `Sm2` tel quel et abstraire plus tard ?

8. **Abstraction du store local.** Introduire `ZLocalStore`/`ZRemoteStore` des le portage (pour Isar/Drift/SQLite) ou conserver le Hive-JSON-string simple de lex et abstraire seulement si un besoin concret apparait ?

9. **Generation LLM : dans zcrud ou hors ?** Le pipeline `Request/Result/Controller/Phase/Outcome/Failure` est generique, mais le wire et le quota (`EducationQuotaInfo`, `FlashcardGenerationErrorKind.quotaExceeded`) sont douane. Le porter comme module optionnel `ZFlashcardGeneration` avec adaptateurs (`ZGenerationWireAdapter`, `ZQuotaInfo`), ou le laisser entierement a l'app ?

10. **Reparentage mindmap.** `moveNode/indent/outdent` n'existent pas dans lex. zcrud les implemente-t-il de son cote (devenant en avance sur lex, risque de re-divergence) ou attend-il le portage depuis lex ?

11. **Champs denormalises lecture-seule.** `RepetitionInfo.folderId`, `ComparativeStudy.countryCodes/themes` sont denormalises pour les filtres serveur `arrayContains`. zcrud fournit-il un mecanisme standard de champs denormalises alimentes a la publication, ou laisse-t-il chaque app le gerer ?
