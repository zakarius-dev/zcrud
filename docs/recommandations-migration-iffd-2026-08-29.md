# Recommandations de migration IFFD — les lots hôte H1 → H13

> **Date** : 2026-08-29. **Émetteur** : socle zcrud. **Destinataire** : équipe IFFD.
> **Nature** : lots que **l'hôte exécute lui-même** (Partie III du plan). Le socle n'écrit rien
> dans `iffd` ; ce document est une recommandation datée, pas une livraison.
>
> **Base de mesure** : dépôt `/home/zakarius/DEV/iffd`, branche **`feat/migration-zcrud`**,
> HEAD `ef730cc` (2026-08-28). Dépôt socle `/home/zakarius/DEV/zcrud`, HEAD `6c6dfac6b`
> (v3.31.0 taguée ; **v3.32.0 rédigée, non taguée au moment de la mesure**).
> Toute affirmation ci-dessous porte son `fichier:ligne` mesuré, ou la mention
> **« à remesurer côté hôte »**.

---

## 0. Le fait qui commande l'ordre des lots

**IFFD est épinglé sur `v3.27.0`.** Mesuré : `pubspec.yaml` porte **48 entrées `ref: v3.27.0`**
(plus une `v6.1.0`, fork tiers). Le socle a livré depuis **v3.28.0, v3.29.0, v3.30.0, v3.31.0**
et prépare v3.32.0.

Conséquence directe, vérifiée symbole par symbole (`git grep <symbole> v3.27.0 -- 'packages/*/lib/*'`) :

| Brique | Présente en v3.27.0 ? | Lot qui en dépend |
|---|---|---|
| `ZcrudScope.derive` (`zcrud_core/lib/src/presentation/zcrud_scope.dart:511` en v3.27.0) | **oui** | H1 |
| `ZFlashcardReviewCard.revealController` (5 occurrences en v3.27.0) | **oui** | H1 |
| `preserveInitialValues` (`zcrud_screen/.../present_form_edition.dart`) | **oui** | H4 |
| `zApplyTestFilters`, `zCategorize`, `zFeedbackTierFor`, `zFoldDiacritics`, `ZFlashcardEditionFields`, `ZFolderContentsOrder`, `ZEmptyState`, `showZConfirmDialog`, `ZDiscardChangesGuard`, `ZAdaptiveGrid` | **oui, les dix** | H3 |
| `sourceIds`, `choiceContentBuilder`, `writtenAnswerFieldBuilder`, `showWeeklyReminders`, `emptyStateBuilder`, `ZAudioPlaybackPort` | **non** (0 occurrence en v3.27.0) | H6, H7, H8, H10 |
| `markSkippedSubmissions`, `ZLapseRequeuePolicy`, `onSwipeDirection` | **non** | H6 |
| `ZMindmapGenerationController`, `ZNoteSummaryController`, `ZExplanationController`, `buildRoutedStudyPorts` | **non** | H9 |
| `ZPodcastCard`, `ZFolderSharingSheet` | **non** | H8, H10 |

⇒ **H1, H3, H4 sont exécutables aujourd'hui, sans bump.** Tous les autres exigent un bump du
pubspec, au minimum aux versions indiquées lot par lot. Le bump lui-même n'est pas un lot : c'est
un prérequis, à faire **en une fois vers v3.31.0** (ou v3.32.0 dès qu'elle est taguée) plutôt
qu'en quatre paliers — v3.32.0 ne touche aucun octet de `lib/` du socle (durcissement de gardes
seul), et v3.31.0 est passive pour un hôte (« les surfaces n'existaient pas »).

⚠️ **Le bump n'est pas neutre visuellement.** v3.29.0 porte une **rupture voulue** (décision du
propriétaire : *le legacy est le défaut*) : bande d'accent 3 dp + tuile 36/10 sur les en-têtes de
section de `DynamicEdition`, hauteurs **44 → 47 dp** sans icône et **48 → 63 dp** avec ; v3.30.0
l'étend à `ZDefaultFolderCard` et aux en-têtes de `ZSectionedStudyLayout`. L'échappatoire unique
est `referenceProfile: ZReferenceProfile.neutral`. **IFFD ne pose ce jeton nulle part** : grep de
`referenceProfile` et `signaturePalette` dans `iffd/lib` → **0 occurrence**. Le bump doit donc être
suivi d'une passe de re-QA visuelle, ou d'une décision explicite (cf. H11).

---

## 1. Ordre recommandé et dépendances

```
H1 ──► H2 ──► H3 ──► H4 ─┬─► H6 ──► H7
 (socle courant)         ├─► H8
                         ├─► H9 ──► H10
                         └─► H11 ──► H12 ──► H13 ──► H5
```

Lecture :

1. **H1 d'abord** — il change ce que *toutes* les autres mesures voient. Tant que 25 scopes locaux
   masquent la racine, chaque lot suivant est mesuré dans un contexte qui va changer sous lui.
2. **H2 ensuite** — caractériser la dette **avant** qu'un lot d'adoption ne déplace les symptômes.
3. **H3 / H4** — adoption du domaine pur et discipline de fusion : ce sont les deux lots qui ne
   coûtent aucun bump et qui réduisent la surface à re-QA plus tard.
4. **bump vers v3.31.0** (jalon technique, pas un lot).
5. **H6 → H7**, **H8**, **H9 → H10** en parallèle possible (paquets et écrans disjoints).
6. **H11** (jetons/skin) après les lots de rendu, sinon on re-QA deux fois.
7. **H12** en continu, mais son inventaire ne se ferme qu'après H11.
8. **H13** = jalon de clôture.
9. **H5 en DERNIER**, jamais avant la case QA correspondante.

---

## 2. État général mesuré côté IFFD (2026-08-29)

| Indicateur | Mesure | Commande |
|---|---|---|
| `lib/` total | **554 fichiers Dart, 179 945 lignes** | `find lib -name '*.dart' \| wc -l` / `… -exec cat {} + \| wc -l` |
| `lib/data_crud/` | **23 fichiers, 13 227 lignes** | idem sur `lib/data_crud` |
| l10n `data_crud` | **3 fichiers, 523 lignes** (`lib/src/l10n/data_crud/`) | `find … \| xargs wc -l` |
| Importeurs de `data_crud` hors du dossier | **64** | `grep -rl data_crud lib \| grep -v "/data_crud/" \| wc -l` |
| Tests | **242 fichiers `*_test.dart`** | `find test -name '*_test.dart' \| wc -l` |
| Bascules QA | **55 entrées `ZQaFlag(`**, dont **16 `changesData: true`** | `grep -c` sur `z_qa_flags.dart` |
| Cases QA du plan de comparaison | **198 au total, 0 cochée** | `grep -c "^\s*- \[x\]"` / `"- \[ \]"` sur `docs/qa-plan-comparaison-legacy-zcrud.md` |
| Paquets zcrud importés | **22 distincts**, 67 imports de `zcrud_core` en tête | `grep -rho "package:zcrud_[a-z_]*" lib \| sort \| uniq -c` |

Deux écarts avec le plan, à acter : le plan annonçait **57 bascules** et « quatorze changent des
données » ; la mesure donne **55** et **16**. Le commentaire d'en-tête de `z_qa_flags.dart:31` dit
lui-même « QUATORZE » — il est **périmé par rapport à son propre fichier**. À corriger dans le même
geste que H2.

---

## 3. Les lots

### H1 — Un seul scope racine, dérivé partout

**Prérequis socle** : v3.27.0 (déjà en place). Aucun bump.

**Constat vérifié.** `lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:351` construit
un `ZcrudScope(` **complet**, pas une dérivation :

```
351:  Widget build(BuildContext context) => ZcrudScope(
```

`grep -rn "ZcrudScope.derive(" lib --include="*.dart"` → **0**. Grep négatif montré : **aucune
dérivation dans tout `iffd/lib`**.

Le wrapper `IffdZcrudScope` (déclaré `z_iffd_field_registry.dart:235`) est monté **25 fois**, plus
deux `ZcrudScope(` nus hors registre (`folders/zcrud/folder_card_default_zcrud.dart:188`,
`folders/zcrud/folder_detail_zcrud.dart:454`) — **28 sites** au total, cohérent avec le plan.
Le scope racine est posé une fois en `lib/main.dart:413`.

**Ce qu'il faut faire.**
1. `ZcrudScope(` → `ZcrudScope.derive(` dans `z_iffd_field_registry.dart:351`, et sur les deux
   sites nus (188 / 454) s'ils sont bien sous la racine — **à remesurer côté hôte** : je n'ai pas
   prouvé que ces deux-là sont toujours montés sous `main.dart:413`.
2. Raccorder `revealController`. Le socle l'expose depuis v3.27.0
   (`zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:110`, `:175`, `bind` en
   `:314` et `:358`). Côté IFFD, `revealController` n'apparaît **que dans un commentaire de test** :
   `test/w8m/review_card_reveal_command_test.dart:79`. Le tripwire existe et est exactement celui
   attendu : il gèle le constat « le mode apprentissage COMMANDE le retournement »
   (`flipCardController?.toggleCard`, bouton « Voir la réponse ») et dit lui-même que le raccordement
   devra **le faire rougir d'abord**. C'est la conduite à tenir : rougir, lire la mesure, puis
   re-figer — jamais supprimer.

⚠️ **Effet de bord à budgéter.** Les 28 scopes locaux **cessent de masquer les seams racine** dès
qu'ils dérivent. Tout ce que la racine déclare (thème, libellés, ACL, registre de widgets,
`referenceProfile` si vous en posez un) devient visible dans les 28 sous-arbres. Rappel du socle
(handoff v3.29.0, §3, lot P1-S) : `ZcrudScope` est devenu un `InheritedTheme` — donc **l'ACL réelle
de l'hôte s'applique enfin** dans les routes poussées, là où un `ZDenyAllAcl` masquait des gestes
par accident. ⇒ **re-QA de tous les lots de rendu déjà validés** après H1.

**Preuves de clôture** : `grep -c "ZcrudScope(" lib` ne compte plus que la racine ;
`grep -c "ZcrudScope.derive(" lib` ≥ 26 ; le test w8m re-figé après rougissement ; les cases QA des
écrans re-QA cochées.

---

### H2 — Caractériser la dette AVANT de la corriger

**Prérequis socle** : aucun. Lot purement hôte.

**Constat vérifié.** `test/dette/` ne contient que **deux** fichiers :
`b16_scheduler_adoption_test.dart` et `b1_reminder_time_test.dart`. Les trois sujets du plan n'y
sont pas.

`test/characterization/` existe et porte 5 fichiers de round-trip + un dossier `screens` — c'est le
bon patron, à étendre.

**Les trois caractérisations à écrire** (dans `test/dette/`, avant tout correctif) :
1. **Flamme au changement d'heure** — la série de révisions doit se comporter de façon définie au
   passage heure d'été/hiver. Aucun test ne le couvre aujourd'hui (grep `DST|heure d'été|changement
   d'heure` sur `lib` et `test` → aucun test dédié ; seules des occurrences non liées sortent).
   **À remesurer côté hôte** : je n'ai pas isolé le site de calcul de la flamme.
2. **Cascade sans `await`** — écrire le test qui *observe* la cascade actuelle (nombre d'écritures,
   ordre, absence d'attente), pas celui qui la corrige.
3. **`minQuality` / `floor`** — `lib/src/presentation/features/flashcards/zcrud/srs_quality_zcrud.dart`
   et son test `test/w8f/srs_quality_zcrud_test.dart` existent : partir de là et geler le
   comportement actuel avant de toucher au plancher.

**Relevé Firestore (DEC-16), non négociable** : avant / après, **clé par clé**, sur un **compte
étudiant — jamais un compte admin**. 16 bascules sont marquées `changesData: true` : ce sont
exactement celles qui exigent ce relevé.

**Preuves de clôture** : 3 tests de caractérisation verts et versionnés dans `test/dette/` ; deux
exports Firestore joints (avant/après) diffés clé par clé ; commentaire d'en-tête de
`z_qa_flags.dart` corrigé (14 → **16**), et compte des bascules corrigé (57 → **55**).

---

### H3 — Adopter le domaine pur

**Prérequis socle** : v3.27.0. **Aucun bump.** Les dix symboles sont présents en v3.27.0 (tableau §0).

**Constat vérifié — adoption réelle : zéro.** Un `grep -rl <symbole> lib --include='*.dart'` sur
chacun des dix donne **0 fichier**, sauf `ZAdaptiveGrid` qui sort **1 fichier** —
`lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart:44,68,69` — et
**uniquement en commentaire** (le fichier explique pourquoi la variante `builder` n'est pas
exposée). Grep négatif montré ; aucune adoption effective.

Corollaires mesurés :
- `showZConfirmDialog` / `ZConfirmTone` / `ZConfirm*` : **0 occurrence** dans `lib`. Or le commit
  `90c878c` (2026-08-26) annonce « les quatre confirmations recopiées ramenées — après avoir comblé
  le manque ». **Contradiction apparente à trancher côté hôte** : soit le ramené passe par un autre
  symbole, soit il a été perdu. À remesurer.
- `ZEmptyState` : **0 occurrence**. Il existe un `_buildEmptyState()` maison
  (`mindmap/widgets/graphite_editor_widget.dart:257,279`) et un slot `globalEmptyState`
  (`folders/zcrud/study_tools_zcrud_view.dart:21,30,36`) — deux implémentations locales là où le
  socle en porte une.
- `zFoldDiacritics` : aucun équivalent local trouvé non plus (`removeDiacritics|foldDiacritics|
  sansAccent|normalizeAccents` → 0 fichier). L'adoption serait donc un **ajout**, pas un
  remplacement : à qualifier avant d'écrire quoi que ce soit.

Le plan chiffre le gain à **≈ 1 084 lignes** ; ce chiffre vient du plan, **je ne l'ai pas remesuré**.
Ce qui est mesuré, c'est que **rien n'est adopté** — le gain est donc intégralement devant vous.

**Preuves de clôture** : pour chaque symbole adopté, le code local correspondant **supprimé** (pas
seulement contourné), prouvé par un grep négatif du symbole local ; delta de lignes de `lib/`
mesuré et consigné ; cases QA des écrans concernés cochées.

---

### H4 — DEC-25 bis : la fusion reste, `preserveInitialValues` devient la règle

**Prérequis socle** : v3.27.0 (`preserveInitialValues` présent dans
`zcrud_screen/lib/src/presentation/present_form_edition.dart`, `:330` sur HEAD).

**Constat vérifié.** `presentFormEdition` est appelé **58 fois** dans `lib`.
`preserveInitialValues` : **0 occurrence**. Grep négatif montré.

**Règle à appliquer** :
- Les **12 fusions existantes RESTENT** — elles ne sont pas une dette, elles sont la compensation
  correcte du contrat par défaut (la fenêtre ne rend que les valeurs éditées).
  ⚠️ **À remesurer côté hôte** : je n'ai pas su isoler ces 12 sites par grep (le motif « fusion »
  sort surtout des commentaires de précédence de scope, ex.
  `z_iffd_field_registry.dart:398`, `mindmap/zcrud/text_menu_zcrud_edition.dart:41`). Le chiffre 12
  vient du plan.
- **Tout nouveau** `presentFormEdition` pose `preserveInitialValues: true` et **ne fusionne pas**.
  C'est la voie documentée du socle (`present_form_edition.dart:252-286` : « la carte rendue reste
  un document COMPLET »).

**Preuves de clôture** : une garde de source dans `test/` qui compte les appels à
`presentFormEdition` **sans** `preserveInitialValues` et **fige ce compte à 12** — tout appel neuf
la fait rougir. C'est le seul moyen de tenir la règle dans la durée.

---

### H6 — Adopter la session riche

**Prérequis socle** : **v3.29.0** (v3.28.0 pour `choiceContentBuilder` / `writtenAnswerFieldBuilder`,
v3.29.0 pour le seau `skipped`, `ZLapseRequeuePolicy` et `onSwipeDirection`).

**Constat vérifié.** `lib/src/presentation/features/flashcards/zcrud/review_session_zcrud.dart:15-33`
porte le tableau de « négociation de surface » : six capacités laissées à leur défaut, chacune
justifiée (`timerDisplay: hidden`, `timeLimit: null`, `correctionVisibility: immediate`,
`hintPolicy` défaut, `evaluationPort: null`, `allowSkipEvaluation: false`). **Ces défauts restent
bons** — ils décrivent le legacy. Ce qui a changé, c'est ce qui **n'existait pas** au moment de la
négociation :

| Brique livrée depuis | Version | Ce qu'elle débloque |
|---|---|---|
| `choiceContentBuilder`, `writtenAnswerFieldBuilder`, `initialAnswer`, `onAnswerChanged`, `isSubmitted` | v3.28.0 | rendre les choix de QCM en markdown/LaTeX, remplacer le champ de rédaction, observer la saisie, **geler la surface sans `IgnorePointer`** |
| 5ᵉ seau `ZFlashcardSubmission.skipped` / `ZFeedbackTier.skipped` (opt-in `markSkippedSubmissions`) | v3.29.0 | « je ne sais pas » compté à part, les 4 comptes existants intacts |
| `ZLapseRequeuePolicy(offsetSevere, offsetLight, severeMaxQuality)` | v3.29.0 | la politique de remise en file devient une donnée d'IFFD |
| `ZSessionCardSwiper.onSwipeDirection(index, start\|end)` | v3.29.0 | le swipe **ne note toujours pas** côté socle : IFFD mappe la direction chez lui |
| `ZSessionCardSwiper.preserveIndexOnMutation` | v3.29.0 | l'index survit à une mutation de liste |

Le plan chiffre à **≈ 1 800 lignes** les **3 saisies recopiées** à supprimer. Chiffre du plan,
non remesuré ici.

⚠️ **`ZFeedbackTier` gagne une valeur** : un `switch` exhaustif sans `default` casse à la compilation.
Le socle a grepé les quatre dépôts et n'en a trouvé aucun — **à reconfirmer côté IFFD après bump**.

⚠️ **Compensation à retirer** : si une surface est gelée par un `IgnorePointer`, le remplacer par
`isSubmitted: true` — l'enveloppe neutralisait aussi la rangée SRS et la correction, que
`isSubmitted` laisse vivantes.

**Tripwire à écrire** : « **QCM LaTeX/SH rendu droit** » — un test qui affirme aujourd'hui la
**perte** (les choix de QCM ne rendent pas le markdown/LaTeX). Il rougira au câblage de
`choiceContentBuilder`, et c'est ainsi qu'on saura que la chaîne est vraiment passée.
Modèle disponible : `test/qa-w2/latex_corruption_tripwire_test.dart` existe déjà.

**Preuves de clôture** : les 3 saisies recopiées supprimées (grep négatif de leur classe) ; tripwire
LaTeX rougi puis re-figé ; relevé Firestore avant/après sur le seau `skipped` (il change des
données) ; cases QA des écrans de session cochées.

---

### H7 — Filtre par source, et le cramming décommenté

**Prérequis socle** : **v3.28.0** (`ZFlashcardTestFilters.sourceIds` / `ZFlashcardBrowseFilters.sourceIds`,
prédicat public `zMatchesSourceId`) + **v3.29.0** (`ZTestFiltersDialog.availableSourceIds`, qui
corrige au passage une **perte de donnée** : le dialogue effaçait `sourceIds` à chaque aller-retour).

**Constat vérifié.** `grep -rn "sourceIds" lib` → **aucune occurrence dans le domaine flashcards**
(les seuls résultats sont des `resourceIds` du module `workflow`, sans rapport). Filtre par source :
**non adopté**.

**Cramming — remesuré sur la branche migration.** Le plan citait
`flashcard_widgets.dart:1090` ; sur `feat/migration-zcrud` le bloc commenté est à
**`lib/src/presentation/features/flashcards/widgets/flashcard_widgets.dart:1224-1255`**
(« Croulage (Cramming) », `FlashcardRepetitionPageType.cramming`). Le chemin d'exécution, lui,
**existe et est vivant** :
- `lib/src/presentation/features/flashcards/pages/folder_flashcards_repetitions_page.dart:36`
  déclare la valeur `cramming` ;
- `:863-866` passe `isCramming:` ;
- `lib/src/presentation/features/flashcards/controllers/flashcards_learing_controller.dart:86-94`
  porte la règle : `bool isCramming = false, // For cramming mode - no SRS update`.

⇒ **Seule l'entrée UI est commentée.** Le décommenter rebranche un chemin déjà écrit.

⚠️ **Limite mesurée du socle, à connaître** : les cartes projetées sur `ZCustomSource` sont **hors
d'atteinte** de `sourceIds` (`zMatchesSourceId` rend `false` pour une source custom). Si IFFD
projette des cartes ainsi, le filtre les exclura silencieusement — **à remesurer côté hôte**.

**Tripwire à écrire** : « **le cramming n'écrit rien** » — un test qui affirme qu'aucune écriture
SRS ne part en mode croulage. Il porte la règle de
`flashcards_learing_controller.dart:88-94`, aujourd'hui garantie par un commentaire seul.

**Preuves de clôture** : `sourceIds` passé aux appliqueurs et le `where` aval **supprimé** (grep
négatif) ; bloc `:1224-1255` décommenté et l'écran atteignable ; tripwire cramming vert ; relevé
Firestore prouvant zéro écriture SRS en croulage.

---

### H8 — Routes réactivées, hebdo éditable, partage

**Prérequis socle** : **v3.28.0** (`ZExamEditor.showWeeklyReminders`) + **v3.30.0**
(`ZFolderSharingSheet`, `zSharingAccessGranted`).

**Constat vérifié — routes.** Le plan citait `app_router.dart:136-165` ; le fichier réel est
**`lib/src/config/router/app_router.dart`** et les blocs commentés mesurés sont :
- `:131-149` — enfants de `HomePageRoute` : `DailyTasksPageRoute` (« Tâches quotidiennes ») et
  `ExamsPageRoute` (« Examens ») ;
- `:158-165` — `PublicFoldersPageRoute` (« Espace partagé ») ;
- `:167-175` — `DiscovryPageRoute` (« Assistant IA ») et ses enfants.

**Constat vérifié — hebdo.** `showWeeklyReminders` : **0 occurrence** dans `lib`. En revanche
`lib/src/data/repositories/z_backed_exam_repository.dart` porte déjà tout le pont :
`:127` documente `reminderDays (List<WeekDays>) → reminderRecurrence.weekdays` avec conversion ISO
explicite (dimanche `0`→`7`, CR-IFFD-17), `:239` fait la conversion. **Le modèle est prêt, seul
l'éditeur ne l'expose pas.** Poser `showWeeklyReminders: true` suffit.

⚠️ **Compensation à retirer** : si une section hebdomadaire maison entoure `ZExamEditor`, elle
produira **deux jeux de cases et deux écritures de `reminderRecurrence`**, la vôtre gagnant après
`onSubmit`. À remesurer côté hôte.
⚠️ **Limite mesurée** : `narrowWeekdays` Material rend 5 libellés distincts pour 7 jours en `en_US`.
L'échappatoire est `weekdayLabeler`. Et il n'existe **aucun repli `showTimePicker`** : sans
`onPickTime`, le bouton d'heure reste désactivé — c'est voulu (AD-26).

**Constat vérifié — collaborateurs.** `lib/src/presentation/features/folders/widgets/folder_coworkers_dialog_widget.dart`
existe : c'est le dialogue maison à remplacer par `ZFolderSharingSheet`.

🔴 **`ZFolderSharingSheet` est fail-closed.** Le portail `zSharingAccessGranted` exige la
disponibilité **et** une `ZAcl` du scope ; **absence de scope ⇒ refus**. Le socle interroge
`ZKeyedAcl` (`zcrud_core/lib/src/domain/ports/z_acl.dart:218`). ⇒ **l'ACL d'IFFD doit implémenter
`ZKeyedAcl`**, sinon toutes les surfaces de partage seront refusées, silencieusement du point de
vue de l'utilisateur. **À vérifier côté hôte avant de câbler** — je n'ai pas mesuré la classe d'ACL
d'IFFD. Ce point est aussi une **dépendance de H1** : c'est le scope racine dérivé qui porte l'ACL.

Limites de contrat consignées par le socle : **pas** de révocation d'adhésion ni de mutation des
interrupteurs dans le port ⇒ ces deux gestes restent des callbacks hôte.

**Preuves de clôture** : les 3 grappes de routes décommentées et atteignables ; `showWeeklyReminders:
true` posé et la section maison **supprimée** (grep négatif) ; `folder_coworkers_dialog_widget.dart`
supprimé ; une garde qui affirme que l'ACL d'IFFD implémente `ZKeyedAcl` ; cases QA correspondantes.

---

### H9 — Rebrancher les générations

**Prérequis socle** : **v3.29.0** (mindmap IA `ZMindmapGenerationController` / `ZMindmapGenerationSheet` ;
résumé de note `ZNoteSummaryController` / `ZNoteSummarySheet`) + **v3.30.0** (explication progressive
`ZExplanationController` / `ZExplanationView` / `ZAiExplanationStreamPort` ; adaptateurs par route
`zcrud_chat_study`, `buildRoutedStudyPorts`).

**Constat vérifié.** `grep -rn "ZMindmapGenerationController\|ZNoteSummaryController\|
ZExplanationController\|buildRoutedStudyPorts\|ZPodcastCard\|ZAudioPlaybackPort" lib` → **0
occurrence**. Grep négatif montré. Rien n'est adopté (attendu : rien n'existait en v3.27.0).

Le code hôte concerné existe et est vivant :
`features/explain_ai/pages/explain_ai_page.dart`,
`features/explain_ai/controllers/explain_ai_page_controller.dart`,
`features/explain_ai/zcrud/ai_explanation_zcrud_reader.dart`,
`features/explain_ai/zcrud/ai_explanation_reader_zcrud_flag.dart`,
`features/discovery/controllers/discovry_page_controller.dart`,
`data/repositories/{openai,iffd,cloud_functions}_ai_repository_impl.dart`.

**Le transport PAR ROUTE est le mode d'IFFD** — c'est acté côté socle (décision du propriétaire du
2026-08-23) et c'est ce que `buildRoutedStudyPorts` sert : catalogue → résolution → gate → handler
→ repli ; route inconnue ⇒ **`ZNotFoundFailure` unique** ; gate refusé ⇒ **0 appel**, jamais un port
par défaut inventé. Six adaptateurs sont livrés (`ZChatRouted{Mindmap,NoteSummary,AiExplanation,
AiExplanationStream,Podcast,Flashcard}…Port`). Trois contrats portent un `routeId` (mindmap,
explication ×2) : il **prime** et est estampillé verbatim ; résumé / podcast / flashcards sont
routés **par configuration**.

⚠️ **Compensations à retirer** : un contrôleur d'explication maison à 10 styles (sinon **deux
historiques concurrents** — le socle porte `select`/`undo`/`redo` en mémoire). Et il faut **injecter
`ZExplanationOperationKeys`** : sans clés, la barre d'opérations d'explication **n'existe pas**
(elle n'est pas grisée, elle est absente — c'est le contrat).

**Preuves de clôture** : `buildRoutedStudyPorts` câblé en une expression ; le contrôleur
d'explication maison supprimé (grep négatif) ; un test par chaîne prouvant qu'une route inconnue
rend `ZNotFoundFailure` et qu'un gate refusé fait **0 appel** ; cases QA des quatre chaînes.

---

### H10 — Podcast

**Prérequis socle** : **v3.28.0** (`ZAudioPlaybackPort` pur Dart, `ZAudioSource`,
`ZAudioPlaybackState` à six états, `ZInertAudioPlaybackPort`) + **v3.30.0** (`ZPodcastCard`,
`ZPodcastAudioPlayer`, `ZPodcastGenerationController`, `zPodcastHubEntry`).

**Constat vérifié.** `ZAudioPlaybackPort` : **0 occurrence** dans `lib`. Le podcast d'IFFD vit
aujourd'hui dans `features/discovery/controllers/discovry_page_controller.dart` et les trois
`*_ai_repository_impl.dart`.

Règle du socle : **le socle ne monte un lecteur que si `isAvailable`**, et `zPodcastHubEntry` rend
`null` tant que tout n'est pas câblé. Rien ne s'affiche à moitié.

⚠️ **Compensation à retirer** : une carte de podcast maison ⇒ **deux cartes** dès que le hub est
câblé.

🔴 **La note audio n'est PAS dans ce lot.** `ZNoteAudioPlayer` (v3.29.0) et
`ZSmartNoteReader.audioPort` / `ZSmartNoteEditor.audioPort` existent, mais les brancher **ajoute
une fonctionnalité au legacy**. ⇒ **décision produit requise**, pas une décision de migration.
Si un lecteur audio maison est superposé à une note, le câblage produira **deux lecteurs**, sur le
lecteur **et** l'éditeur.

**Preuves de clôture** : `ZPodcastCard` monté, carte maison supprimée ; une garde prouvant que le
hub reste absent quand le port est indisponible ; décision produit **écrite** sur la note audio
(oui/non, datée), quelle qu'elle soit.

---

### H11 — Jetons et skin posés UNE fois, au scope racine (DEC-24)

**Prérequis socle** : **v3.29.0** (`ZReferenceProfile`, jeton `referenceProfile`,
`z_signature_palette_reference.dart`, jetons `signaturePalette`, `signaturePaletteIndexStrategy`,
`sectionHeader*`) + **v3.30.0** (App-C sur `ZDefaultFolderCard` et `ZSectionedStudyLayout`).

**Constat vérifié — IFFD compense encore.**
- `getFolderGradients` : **3 occurrences dans 1 fichier** — moins que les « 18 fichiers » du plan.
  ⚠️ **Écart à trancher côté hôte** : soit la recopie a déjà été centralisée depuis le relevé du
  plan, soit le motif de grep du plan visait autre chose. **À remesurer.**
- `MyStickyHeader` : déclaré `lib/src/utils/functions/forms_utils.dart:68`
  (`class MyStickyHeader extends StatelessWidget`), utilisé dans **2 fichiers**.
  C'est bien la réimplémentation de la bande d'accent + tuile que le socle porte désormais.
- `referenceProfile` / `signaturePalette` : **0 occurrence**. Grep négatif montré.

**Ce qu'il faut faire.**
1. Poser les jetons **une seule fois**, au scope racine (`main.dart:413`) — c'est DEC-24, et c'est
   ce que H1 rend effectif : sans dérivation, un jeton racine n'atteint pas les 28 sous-arbres.
2. **Retirer** `MyStickyHeader` et ses 2 usages, et les dégradés recopiés. Sinon : **double bande**
   et deux sources de vérité.
3. **L'habillage legacy s'active par `referenceProfile`** — et il est **déjà le défaut**
   (`ZReferenceProfile.legacy`). IFFD n'a donc **rien à poser** pour l'obtenir ; c'est l'inverse
   qui coûte un jeton (`neutral`).
   ⚠️ **L'arbitrage du défaut `neutral` / `legacy` est en cours côté socle** : ne construisez pas
   d'écran sur l'hypothèse que le défaut ne bougera jamais. Posez **explicitement**
   `referenceProfile: ZReferenceProfile.legacy` à la racine : c'est aujourd'hui redondant, et
   demain c'est votre garantie.
4. `String.hashCode` n'est **pas stable entre plateformes** : si vous exigez la même couleur partout,
   choisissez `signaturePaletteIndexStrategy: ZPaletteIndexStrategy.stableFnv` (le défaut
   `titleHash` est la fidélité au legacy). Divergence assumée du socle sur `ZDefaultFolderCard` :
   indexation par **identité**, le legacy indexait par **ordinal** — réglable par le même jeton.

**Preuves de clôture** : `grep -c "MyStickyHeader" lib` = 0 ; `getFolderGradients` = 0 ;
`referenceProfile` posé exactement **une fois** ; captures avant/après des en-têtes de section
(hauteur 44→47 / 48→63 attendue) ; cases QA visuelles.

---

### H12 — Retirer une compensation à chaque CR livrée

**Prérequis socle** : suit les lots. Continu.

**Constat vérifié.** `grep -rln "tripwire\|TRIPWIRE" test` → **17 fichiers**, dont
`test/qa-w2/latex_corruption_tripwire_test.dart`, `test/qa-w2/notebook_markdown_tripwire_test.dart`,
`test/m0/formulaires_socle_tripwires_test.dart`, `test/s1/mort_confirme_test.dart`,
`test/w8m/review_card_reveal_command_test.dart`. **La pratique est en place** — c'est exactement ce
que le socle recommande aux quatre hôtes, et IFFD est le dépôt qui la tient le mieux.

**La règle** : quand un tripwire rougit, il désigne un doublon. **On retire la compensation, on ne
fait pas taire le tripwire.**

**Inventaire des compensations à retirer, relevé dans les §« hôte ayant compensé » des handoffs
v3.28.0 → v3.31.0** (chacune est **à remesurer côté hôte** — le socle décrit une classe, pas votre
code) :

| Compensation | Handoff | Ce qui s'additionne si on la garde |
|---|---|---|
| `where` sur l'identifiant de source **en aval** des appliqueurs | v3.28.0 | double filtrage |
| clone de `ZFlashcardAnswerInput` (markdown / champ de rédaction) | v3.28.0 | surface dupliquée |
| `IgnorePointer` pour geler la saisie | v3.28.0 | rangée SRS + correction neutralisées par erreur |
| matière rangée dans `extra['subject_id']` | v3.28.0 | **clé désormais réservée** : lecture `null`, `copyWith(extra:)` la filtre ⇒ migrer vers `folder.subjectId` |
| section hebdomadaire maison autour de `ZExamEditor` | v3.28.0 | deux jeux de cases, deux écritures de `reminderRecurrence` |
| `ConstrainedBox` maison / présentateur maison / FAB par `Stack` | v3.28.0 | borne la plus petite, deux cadres, deux boutons |
| `ZSrsScheduler` maison pour une table d'ajustement d'EF | v3.29.0 | remplaçable par `ZEaseFactorAdjustment.table(...)` |
| enveloppe autour de `ZEmptyState` pour une illustration | v3.29.0 | deux visuels ⇒ passer par `illustration:` |
| lecteur audio superposé à une note | v3.29.0 | deux lecteurs (lecteur **et** éditeur) |
| `ZcrudScope` re-posé **à l'identique** dans un dialogue | v3.29.0 | retirable sans danger (P1-S) — **sauf** si l'ACL re-posée est plus restrictive : la garder |
| **5 dégradés recopiés + `MyStickyHeader`** | v3.29.0 / v3.30.0 | double bande, deux sources de vérité (= H11) |
| contrôleur d'explication maison à 10 styles | v3.30.0 | deux historiques concurrents |
| carte de podcast maison | v3.30.0 | deux cartes |
| dialogue de collaborateurs maison | v3.30.0 | deux dialogues (= H8) |
| partition de progression recalculée **par build** | v3.30.0 | deux partitions + le jank conservé |
| matière bricolée dans le sous-titre / opacité autour de la tuile d'examen | v3.30.0 | doublons visuels |

⚠️ **Un tripwire qui rougit sans qu'une CR ait été livrée n'est pas un doublon** : c'est une
régression. Les distinguer par la version consommée, pas par l'intuition.

**Preuves de clôture** : par ligne du tableau, soit la compensation supprimée (grep négatif montré),
soit une **justification écrite** disant pourquoi elle reste.

---

### H13 — JALON DE CLÔTURE : suppression de `lib/data_crud`

**Prérequis socle** : tous les lots précédents clos. C'est le jalon, pas un lot d'adoption.

**Constat remesuré le 2026-08-29 sur `feat/migration-zcrud`** — le chiffre du plan est **confirmé
à l'identique** :

```
grep -rl data_crud lib | grep -v "/data_crud/" | wc -l   →  64
find lib/data_crud -name '*.dart' | wc -l                →  23
find lib/data_crud -name '*.dart' -exec cat {} + | wc -l →  13 227
find lib/src/l10n/data_crud -name '*.dart' | xargs wc -l →  523  (3 fichiers)
```

**Répartition des 64 importeurs, par cible** :

| Cible importée | Importeurs | Correspondance socle |
|---|---|---|
| `data_crud/edition_screen.dart` (4 073 l) | **40** | `presentFormEdition` / `ZCrudScreen` |
| `data_crud/edition_field.dart` (444 l) | **27** | `ZFieldSpec` + registre de widgets |
| `data_crud/localizations_delegate.dart` | **25** | delegate l10n zcrud |
| `data_crud/messages/abstract.dart` | **22** | idem |
| `data_crud/rich_text_editor_screen.dart` (773 l) | **21** | `zcrud_markdown` |
| `data_crud/rich_text_editor/delta_to_markdown_helper.dart` (613 l) | **7** | `ZCodec` |
| `data_crud/subitem_menu_option.dart` (46 l) | **3** | `ZSubListSeams` |
| `data_crud/rich_text_editor/editors/markdown_edition_field.dart` (493 l) | **3** | `zcrud_markdown` |
| `data_crud/dynamic_list_field.dart` (37 l) | **2** | `subItems` |
| `data_crud/rich_text_editor/markdown_to_delta_helper.dart` (383 l) | **1** | `ZCodec` |

**Les deux fichiers présumés morts — preuve par grep, faite :**

- `lib/data_crud/categorysation_screens.dart` (43 l) :
  `grep -rn "categorysation" lib test --include='*.dart' | grep -v "^lib/data_crud/"` ne rend
  **qu'une ligne, dans un commentaire de test** : `test/s1/mort_confirme_test.dart:22`. **Aucun
  importeur de code.** → mort, confirmé, et déjà gardé par `mort_confirme_test.dart`.
- `lib/data_crud/notifications.dart` (80 l) :
  `grep -rn "data_crud/notifications" lib test --include='*.dart'` → **aucun résultat**. → mort,
  confirmé.

Ces deux-là peuvent partir **avant** le reste : 123 lignes, zéro consommateur, zéro risque.

**Critère de clôture, non négociable** : `grep -rn data_crud lib` → **0**, et le dossier
`lib/data_crud/` **supprimé** (ainsi que `lib/src/l10n/data_crud/`, 523 l, une fois le delegate
zcrud en place).

**Indicateurs de jalon à publier** (valeurs de départ mesurées ce jour) :

| Indicateur | 2026-08-29 | Cible |
|---|---|---|
| `lib/` (lignes Dart) | **179 945** | — (baisse attendue ≥ 13 750) |
| Fichiers `lib/data_crud/` | **23** | **0** |
| Lignes `lib/data_crud/` + l10n | **13 227 + 523** | **0** |
| Importeurs `data_crud` | **64** | **0** |
| Cases QA cochées | **0 / 198** | **198 / 198** |

---

### H5 — Le code mort, en DERNIER

**Prérequis** : **la case QA de l'écran concerné doit être cochée.** Aujourd'hui : **0 / 198**.
⇒ **H5 ne peut pas commencer.**

**Constat remesuré.** Deux chiffres du plan ne tiennent pas :

| Élément | Chiffre du plan | Mesure du 2026-08-29 |
|---|---|---|
| `z_qa_flags.dart` | ≈ 2 400 l | **1 125 l** (`lib/src/presentation/shared/zcrud/z_qa_flags.dart`) |
| `z_backed_*.dart` | 4 648 l | **4 648 l** — confirmé (6 fichiers, `wc -l` total) |
| Bascules | 57 | **55** entrées `ZQaFlag(` |
| Code mort certifié | ≈ 2 181 l | **non remesuré** — à requalifier écran par écran |

Les chemins legacy des 55 bascules (M9-3 / M9-4) sont **le gros du volume**, et ils sont
**structurellement indispensables tant que la QA n'est pas faite** : ce sont eux qui permettent de
comparer legacy et socle sur le même compte, le même jour.

🔴 **Règle absolue : un écran en bascule est GELÉ.** On ne le refactore pas, on ne le nettoie pas,
on ne le « rend pas plus lisible » tant que sa case QA n'est pas cochée — sinon la comparaison
legacy/socle ne compare plus rien.

**Séquence** : case QA cochée → chemin legacy de **cette** bascule supprimé → entrée retirée de
`z_qa_flags.dart` → compteur mis à jour. Bascule par bascule, 55 fois. Jamais en lot.

**Preuves de clôture** : 55/55 entrées retirées, `z_qa_flags.dart` supprimé, 198/198 cases cochées,
`z_backed_*` requalifié écran par écran (certains ports resteront légitimes — ce ne sont pas tous
des chemins legacy).

---

## 4. Règles transverses, applicables à chaque lot

1. **Capturer avant de corriger.** Un test de caractérisation qui gèle le comportement **actuel**
   précède tout correctif. `test/characterization/` et `test/dette/` sont les emplacements.
2. **Compte étudiant, jamais admin.** Un admin voit des chemins qu'un étudiant ne voit pas ; une
   QA faite en admin ne prouve rien sur le produit livré.
3. **Relevé Firestore clé par clé**, avant/après, sur toute bascule `changesData: true` — il y en a
   **16** (mesuré), pas 14 comme l'annonce le commentaire de `z_qa_flags.dart:31`.
4. **Les tripwires se conservent.** 17 fichiers en portent aujourd'hui. Un tripwire qui rougit à
   l'adoption d'une CR est un **succès** : il désigne le doublon. On retire la compensation, on
   re-fige la garde, on ne la supprime jamais.
5. **Les 198 cases QA se ferment par lot**, pas à la fin. Une case ouverte à la fin d'un lot est
   une dette de mesure qui devient invérifiable.
6. **Un écran en bascule est gelé** (cf. H5).
7. **Toute affirmation d'absence porte son grep négatif montré.** « Je n'ai pas trouvé » n'est pas
   un constat — c'est la règle que le socle s'applique, et ce document s'y tient.

---

## 5. Ce que ce document ne prouve pas

Par honnêteté de mesure, les points suivants sont **repris du plan et non vérifiés** :

- les **≈ 1 084 lignes** de gain de H3 et les **≈ 1 800 lignes** des 3 saisies recopiées de H6 ;
- les **12 fusions existantes** de H4 — je n'ai pas su les isoler par grep ;
- les **≈ 2 181 lignes** de code mort certifié de H5 ;
- les **18 fichiers** de dégradés recopiés de H11 — la mesure du jour dit **1 fichier**, ce qui est
  un écart net à trancher côté hôte ;
- l'appartenance des deux `ZcrudScope(` nus (`folder_card_default_zcrud.dart:188`,
  `folder_detail_zcrud.dart:454`) au sous-arbre de la racine `main.dart:413` ;
- la classe d'ACL d'IFFD et son implémentation (ou non) de `ZKeyedAcl` — **bloquant pour H8**.

Et deux contradictions internes à lever côté IFFD :

- commit `90c878c` annonce « les quatre confirmations recopiées ramenées », alors que
  `showZConfirmDialog` / `ZConfirm*` ont **0 occurrence** dans `lib` ;
- `z_qa_flags.dart` compte **55** bascules et **16** `changesData: true`, quand son propre
  commentaire d'en-tête dit « vingt-cinq » providers et « QUATORZE » flags de données.
