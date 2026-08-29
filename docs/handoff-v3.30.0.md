# Handoff v3.30.0 — l'explication qui coule, l'occupation partagée, le chat aligné

> **Date** : 2026-08-29. **Portée** : `zcrud_study`, `zcrud_core`, `zcrud_chat` (+ suite de la
> vague en cours). **Plan** : Partie III, Vague 2. _(en cours de rédaction — complété lot par lot)_

## 1. Ce que le socle livre

| Lot | Paquet | Livré |
|---|---|---|
| **busy** | `zcrud_core` | `ZBusyPaletteReference` — les 7 teintes du cycle « génération en cours » du legacy (jusqu'ici enfermées dans `zcrud_chat`, hors de portée des feuilles d'étude par AD-1), `interval` 300 ms/teinte, `period` 2 100 ms ; jetons `busyPalette`/`busyCycleInterval` ; lecteurs `zBusyPaletteOf`/`zBusyCycleIntervalOf` (jeton > profil : `legacy` ⇒ référence, `neutral` ⇒ `null` → l'appelant retombe sur `primary` seul) ; `ZColorCycle.busy(context)` additif |
| **P1-D** | `zcrud_study` | contrat progressif d'explication IA : `ZGenerationProgress {text cumulatif, isDone}`, `ZAiExplanationStreamPort` (flux nu, inerte const) ; `ZAiExplanationRequest.style/operation/routeId` (clés **opaques** de l'hôte, `null` par défaut) ; `ZExplanationController` (tranche `streamingText` seule notifiée pendant le flux, **historique de versions en mémoire** — `select`/`undo`/`redo`, jeton de fraîcheur, un `Left` en cours de flux n'écrase pas la version courante) ; les 4 opérations (résumer/régénérer/développer/styliser) = même port, `operation` différente, clés **injectées** par `ZExplanationOperationKeys` — le socle n'en déclare aucune ; `ZExplanationView` (slot de rendu riche injecté, barre d'opérations absente sans clés, `onPersist(ZStudyExplanation)` sans écriture) |
| **App-C** | `zcrud_study` | `ZDefaultFolderCard` : dégradé signature en **repli** quand aucune couleur n'est déclarée par le seam (la couleur utilisateur prime — préséance gardée) ; en-têtes de `ZSectionedStudyLayout/Sliver` : bande 3 dp + tuile 36/10 à ombre teintée (jetons `sectionHeader*` de core, `ZStudyToolsSectionSpec.icon` additif) ; **L11 tranché par la mesure** : les cartes d'outils du legacy sont à rayon 16 (`folder_study_tools_page.dart:147`), la référence reste 16 — le 12 dominant appartient à d'autres familles ; `z_study_empty_state_reference.dart` (6 natures, 0 couleur, `folderOpen` 200) ; `ZSubfolderAccentPastille.signatureIdentity` opt-in ; tripwire visuel rougi sur la rupture voulue, diff inspecté (les 4 bandes, rien d'autre), re-figé jamais affaibli. Divergence assumée : indexation par **identité** (legacy : ordinal) — réglable via `signaturePaletteIndexStrategy` |
| **P1-G** | `zcrud_study` | podcast : `ZPodcastCard` (statut/fraîcheur par fabriques de libellés injectées, « régénérer » monté ssi callback), `ZPodcastAudioPlayer` (miroir du lecteur de note : `load` une fois, `Left` affiché sans levée, port jamais disposé, tranche `position` isolée), `ZPodcastGenerationController`, `zPodcastHubEntry` (`null` tant que tout n'est pas câblé) ; **`routeId` + `withRouteId` sur `ZNoteSummaryRequest`/`ZPodcastGenerationRequest`/`ZFlashcardGenerationRequest`** — les adaptateurs routés peuvent désormais estampiller les six chaînes ; défaut corrigé au passage : `withResolvedSources` perdait la route |
| **P1-H** | `zcrud_study` | partage **fail-closed** : portail `zSharingAccessGranted` (disponibilité **et** `ZAcl` du scope — absence de scope ⇒ refus), `ZFolderSharingSheet` (lien révocable, adhésions en flux virtualisé, octroi via `principalResolver` — le socle n'interprète jamais un e-mail : `actorUid` = la valeur **résolue**, gardé —, publication/dépublication, verrou par geste, `Left` ⇒ annoncé, état intact), `ZPublicGalleryView` (flux **en paramètre** — le port n'a pas de lecture de galerie, l'étendre casserait ses implémenteurs), `zFolderSharingItemAction`/`zPublicGalleryItemAction` (`null` tant que câblage ou autorisation manquent). Limites de contrat consignées : pas de révocation d'adhésion ni de mutation des interrupteurs dans le port ⇒ callbacks hôte |
| **P2-D** | `zcrud_study` | `ZFolderProgressSummary` + `zSummarizeFolderProgress` — valeur **pure** qui **délègue** à la partition SRS existante (`zCategorize`/`zIndexSrsById`, aucune seconde formule, gardé par une garde de source) ; `ZFolderProgressBar` segmentée à 3 seaux (consomme la valeur, jamais les flux — la fin du recalcul par build du legacy) ; `ZSubjectChip` + `ZSubjectRefResolver` (premier consommateur de `ZStudySubjectRef` : snapshot affiché sans résolution, résolution optionnelle) ; `ZDefaultFolderCard.subjectRef/subjectLabelResolver` ; `ZDefaultExamCard.now/pastLabel` (règle `ZExam.isPast`, atténuation par opacité, état dit en texte) |
| **P1-F** | `zcrud_chat_study` | **six adaptateurs « par route »** (`ZChatRouted{Mindmap,NoteSummary,AiExplanation,AiExplanationStream,Podcast,Flashcard}…Port`) sur une mécanique commune (catalogue → résolution → gate → handler → repli ; route inconnue ⇒ `ZNotFoundFailure` **unique**, port par défaut jamais inventé ; gate refusé ⇒ 0 appel) + `buildRoutedStudyPorts` (câblage hôte en une expression). Seuls trois contrats d'étude portent un `routeId` (mindmap, explication ×2) — il **prime** puis est estampillé verbatim ; résumé/podcast/flashcards sont routés **par configuration**. AD-1 tenu et gardé (`zcrud_study` sans arête chat, contrôle discriminant) ; arête `zcrud_mindmap` ajoutée (transitive, zéro poids nouveau) |
| **App-D** | `zcrud_chat` | `ZChatNotebookReference.busyPalette` = alias de `ZBusyPaletteReference.colors` (les 7 littéraux ont quitté le chat ; garde de source, pas `identical` — les listes `const` sont canonicalisées, une garde `identical` sur un alias est **vacuous**, mesuré par R3) ; la barre d'artefacts lit `paramètre > chatBusyPalette > zBusyPaletteOf(context)` — le jeton de socle et le profil l'atteignent ; `ZChatNotebookSkin.resolve` arbitre ses couleurs par `zLegacyOrIn` (défaut `legacy` inchangé **valeur par valeur** ; `neutral` ⇒ rôles M3, accents de capacité en `primary`, distinction par libellé + pastille) ; tempo du chat conservé (2 000 ms — l'unifier sur les 2 100 ms de core aurait changé le rendu par défaut, refusé) |

## 2. Ce qui change pour un hôte

**Hôte passif : rien**, sauf la **rupture voulue d'Apparence C** (suite de la doctrine « le legacy
est le défaut ») : `ZDefaultFolderCard` sans couleur déclarée par le seam gagne le dégradé
signature ; les en-têtes de `ZSectionedStudyLayout/Sliver` gagnent bande 3 dp + tuile 36/10.
Échappatoire inchangée et prouvée : `referenceProfile: neutral`. Le défaut d'App-D ne change rien
au rendu du chat ; seule la sortie `neutral` s'ouvre.

**Hôte ayant compensé — à retirer, sinon ça s'additionne** : les 5 dégradés recopiés
(`getFolderGradients`) et le `MyStickyHeader` d'IFFD ; un contrôleur d'explication maison à 10
styles (deux historiques concurrents sinon) ; une carte de podcast maison (deux cartes s'il câble
le hub) ; un dialogue de collaborateurs maison (deux dialogues s'il câble la feuille) ; une
partition de progression recalculée par build (deux partitions + le jank conservé) ; matière
bricolée dans le sous-titre ou opacité posée autour de la tuile d'examen (doublons visuels).

⚠️ Un hôte dont l'ACL n'implémente pas `ZKeyedAcl` verra les surfaces de partage **refusées**
(fail-closed voulu — déclarer son ACL explicitement). Un hôte doit injecter
`ZExplanationOperationKeys` pour que la barre d'opérations d'explication existe.

## 3. Vérification

Rejouée par l'orchestrateur, tous les lots au repos, chaque paquet depuis son dossier.

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_core` | 2 655 | **2 669** (analyze 13 infos préexistantes) |
| `zcrud_chat` | 1 057 | **1 068** (analyze 0, 19 s) |
| `zcrud_chat_study` | 67 | **101** (analyze 0) |
| `zcrud_study` | 1 621 | **1 780** (analyze 72 infos, 71 préexistantes + 1 du patron miroir) |

| Contrôle | Résultat |
|---|---|
| `melos run generate` | SUCCESS — 0 `.g.dart` modifié |
| `melos run analyze` repo-wide | **RC=0** (4 infos préexistants) |
| `melos run verify` (12 gates) | **RC=0** |
| Balayage des 41 paquets, chacun depuis son dossier | **40 verts** ; `zcrud_generator` rouge **environnemental** inchangé ; `zcrud_chat_kernel` avait 1 rouge — la garde inter-paquets G-U1 (« un verbe = un seul site d'appel ») mordait sur l'homonyme `ZExplanationController.regenerate` d'un autre domaine : **ancrage resserré** (seuls les fichiers qui voient `ZChatAction*`/`zcrud_chat` comptent), R3 rejouée (verte avec l'homonyme, rouge par assertion sur une vraie violation chat), 717 verts |
| Résidus d'injection R3 | **0** marqueur |

Dette consignée pour un lot de durcissement : la garde de style FR-26 ne reconnaît pas un
`Color(<entier décimal>)` — découvert par une injection restée inerte pendant la campagne du lot
busy (le constat vient d'une R3, pas d'une relecture).
