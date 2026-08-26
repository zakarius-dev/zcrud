# Critique de complétude du relevé `iffd-migration-2026-08-26`

> Mesuré le **2026-08-26**. `/home/zakarius/DEV/iffd` lu en **lecture seule stricte** (HEAD `65d1af9`,
> branche `feat/migration-zcrud`, arbre propre). Socle `/home/zakarius/DEV/zcrud` @ **v3.21.0**, 41 paquets.
> Aucun test lancé, dans aucun dépôt. Seul fichier écrit : celui-ci.
>
> Matière critiquée : **60 fichiers, 22 756 lignes** (`wc -l *.md`).
> Ce document ne résume rien. Il ne liste que ce qui **manque**, ce qui **se contredit** et ce qu'il faut
> **remesurer**. Chaque point porte sa preuve ; chaque absence porte son grep négatif montré.

---

## 0. Ce que j'ai vérifié moi-même, et ce que je n'ai pas vérifié

**Vérifié sur disque** : la volumétrie réelle d'IFFD par dossier ; l'état des sept CR 114→120 ; le
`pubspec.yaml` de l'hôte (sections, paquets zcrud, 122 dépendances tierces) ; l'inventaire de
`iffd/docs/` ; les compteurs transverses app-wide (RTL, `setState`, couleurs, `Semantics`, tests) ;
cinq « manques au socle » repris par sondage dans le code du socle ; les périmètres déclarés par les
onze cartes ; les CHANGELOG des 41 paquets.

**Non vérifié, et je le dis** : je n'ai relu ni ligne à ligne les 22 756 lignes du relevé, ni les
7 899 lignes du registre de CR. Les contradictions listées au §3 ont été trouvées par recoupement
ciblé — **il en reste probablement d'autres du même type**, la méthode qui les produit étant
structurelle (§3.5) et non accidentelle.

---

## 1. LE MANQUE PRINCIPAL — il n'existe aucune synthèse

### 1.1 Zéro fichier de total, de séquencement ou de priorisation

```
$ cd docs/analyses/iffd-migration-2026-08-26
$ ls | grep -iE "synth|plan|roadmap|backlog|index|README|priorit|sequen"
$ echo "RC=$?"
RC=1
```

**Onze cartes, onze confrontations, cinq catalogues, trente-trois réfutations — et pas une page qui
additionne.** Le relevé produit des verdicts par domaine et s'arrête là. Or les domaines ont été
découpés *a priori*, et ils **se recouvrent** (§3.3, §3.4) : la somme naïve des chiffrages est donc
fausse, et personne n'a écrit la somme corrigée.

Chiffrages « migrable aujourd'hui » réellement publiés, par domaine :

| Confrontation | Total déclaré | Emplacement |
|---|---:|---|
| `revision-srs-sessions` | **≈ 6 776** | `:443` |
| `formulaires-crud` | **≈ 6 234** | `:659` |
| `socle-app` | **≈ 4 750** | `:86`, `:384` |
| `ia-chat-generation` | **≈ 4 900** | `:21` |
| `etude-dossiers` | **≈ 2 220** | `:338` |
| `etude-matieres-corpus` | **≈ 2 080** (3 180 avec G3) | `:532-533` |
| `taches-decouverte` | **≈ 1 666** | `:616` |
| `examens` | **≈ 990** | `:438` |
| `mindmap` | **AUCUN** | — |
| `revision-flashcards` | **AUCUN** | — |
| `notes-smartnotes` | § 5 « Bilan chiffré », pas de ligne TOTAL | `:262` |

**Deux confrontations sur onze ne chiffrent pas leur domaine.** Grep négatif :

```
$ grep -nE "≈ ?[0-9] ?[0-9]{3}|TOTAL|Total supprimable" confrontation-mindmap.md ; echo "RC=$?"
RC=1
$ grep -nE "≈ ?[0-9] ?[0-9]{3}|TOTAL|Total supprimable" confrontation-revision-flashcards.md ; echo "RC=$?"
RC=1
```

⇒ **À produire** : une page unique qui (a) déduplique les périmètres, (b) réconcilie les deux
mesures incompatibles du §3.1 et du §3.2, (c) ordonne les lots par dépendance (`G3` bloque M5 de
`etude-matieres` ; `M4`/`ZEntity` conditionne le codegen), (d) chiffre `mindmap` et
`revision-flashcards`.

### 1.2 Le brief de l'orchestrateur est lui-même faux sur les CR — et neuf cartes sur onze l'ont recopié

Le contexte daté annonce « **sept CR ouvertes** (CR-IFFD-114 → 120) ». **Mesuré :**

```
$ grep -n "^## CR-IFFD-1(1[4-9]|20)" docs/zcrud-change-requests.md
7589:## CR-IFFD-114 — le TABLEAU markdown rendu …
7675:## CR-IFFD-115 — le retour à la ligne SOUPLE …
7734:## CR-IFFD-116 — le dialogue d'édition plein écran n'a pas de sous-titre …
7787:## CR-IFFD-117 — RETIRÉE AVANT ÉMISSION …
7825:## CR-IFFD-118 — RETIRÉE AVANT ÉMISSION …
7859:## CR-IFFD-119 — RETIRÉE AVANT ÉMISSION …
7879:## CR-IFFD-120 — RETIRÉE AVANT ÉMISSION …
```

**Trois ouvertes, quatre retirées avant émission.** Deux documents seulement ont refusé le chiffre
du brief et l'ont dit — `carte-formulaires-crud.md:168` (« ce n'est pas de sept CR émises ») et
`carte-ia-chat-generation.md:604-610` (« Quatre ont été retirées avant… »). C'est exemplaire, et
c'est **2 sur 11**.

Couverture réelle des trois CR ouvertes : **114** dans 11 fichiers, **115** dans 6, **116** dans 6 —
et un traitement de fond dans `confrontation-formulaires-crud.md:890-970` (L9/L10/L11) et
`confrontation-notes-smartnotes.md:229-231` (M-7/M-8/M-9). **Ce point du brief est couvert.** Ce
qui manque, c'est l'inverse : `confrontation-formulaires-crud.md:23` écrit que le lot était
« **entièrement absent** » de la matière d'entrée — l'aveu que neuf cartes sur onze ont été rédigées
sans lire le lot de CR le plus récent de l'hôte.

---

## 2. LE PAN ENTIER JAMAIS CARTOGRAPHIÉ — la documentation de migration de l'hôte

`iffd/docs/` fait **20 770 lignes**. Le relevé en cite **deux** fichiers de façon substantielle
(`zcrud-change-requests.md`, 16 renvois ; `qa-plan-comparaison-legacy-zcrud.md`, 13). Douze fichiers
sont **à zéro renvoi**, mesuré fichier par fichier (`grep -rl <nom> .` → 0) :

| Document de l'hôte | Lignes | Renvois dans le relevé |
|---|---:|---:|
| `dette-bugs-preexistants.md` | 2 669 | **0** |
| `decisions-adoption-zcrud.md` | 710 | **0** |
| `w7-ecarts-de-portage.md` | 572 | **0** |
| `plan-modeles-zentity-codegen.md` | 568 | **0** |
| `w4-opaque-keys-inventory.md` | 551 | **0** |
| `zcrud-migration-plan.md` | 463 | **0** |
| `etat-des-lieux-zcrud-v2.5.0.md` | 455 | **0** |
| `surveillance-zcrud.md` | 428 | **0** |
| `chiffrage-migration-chat.md` | 374 | **0** |
| `zcrud-integration-inventory.md` | 289 | **0** |
| `retrait-modules-juridiques.md` | 177 | **0** |
| `etat-migration-zcrud.md` | 108 | **0** |
| **Total non lu** | **7 364** | |

Plus, à zéro renvoi également : `notebook-dépouillement-N1/N2/N4` (1 486 l.), `qa-w2-resultats.md`,
`w2-qa-manuelle.md`, `qa-m1-1-famille-a.md` (838 l.).

### 2.1 Deux de ces documents **invalident** des propositions du relevé

**`docs/decisions-adoption-zcrud.md:9-19`** porte des arbitrages **tranchés par l'owner le
2026-08-19**, avec `chemin:ligne` :

- `RACINE-1` : « **la vague N2 est annulée** » ;
- `RACINE-3` : « **une seule migration de schéma, dans M7** ⇒ `ZFieldRename.none` d'ici là »
  (répété `:139`, `:388`) ;
- `:200` : liste nominative des paquets **à adopter**, dont `zcrud_generator` + `zcrud_annotations` ;
- `:292-298` : `DEC-11` — les modèles `workflow` (`Task`, `Event`, `Appointment`) sont **hors
  codegen**, « et c'est motivé, pas paresseux ».

**`docs/plan-modeles-zentity-codegen.md`** (568 l., mesuré 2026-08-19) chiffre déjà le chantier
codegen : « **3 958 lignes** de codecs manuels visées, **5 obstacles mesurés** », vagues N0→N7.

Or le relevé propose le codegen dans **au moins quatre** confrontations, sans jamais citer ni le
chiffre de l'hôte, ni ses cinq obstacles, ni la contrainte `ZFieldRename.none` :

| Proposition du relevé | Lignes revendiquées |
|---|---:|
| `confrontation-formulaires-crud.md:258` — M3, désérialisation à la main | **2 604** |
| `confrontation-etude-matieres-corpus.md:235` — M6, corpus par codegen | **≈ 1 230** |
| `confrontation-etude-dossiers.md:173` — M6, 6 modèles de dossier | **639** |
| `confrontation-ia-chat-generation.md:170` — 2.9, cinq modèles | non chiffré isolément |

Grep négatif du relevé :
```
$ grep -rn "3 958\|3958" docs/analyses/iffd-migration-2026-08-26/ ; echo "RC=$?"
RC=1
$ grep -rl "plan-modeles-zentity-codegen\|decisions-adoption-zcrud" docs/analyses/iffd-migration-2026-08-26/ | wc -l
0
```

**Conséquence** : ≥ 4 470 lignes de « migrable aujourd'hui » reposent sur une adoption du codegen
que l'hôte a déjà instruite, chiffrée autrement, et **conditionnée à une vague M7 qui n'a pas eu
lieu**. À remesurer avant de proposer quoi que ce soit.

### 2.2 L'état de départ codegen est plus dur que le relevé ne le dit

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn "@ZcrudModel" lib | wc -l          →  0
$ grep -rn "@JsonSerializable" lib | wc -l    →  0
$ grep -rn "@riverpod\|@Riverpod" lib | wc -l →  79
$ find lib -name '*.g.dart' | wc -l           →  16   (tous Riverpod)
$ grep -n "zcrud_generator" pubspec.yaml ; echo "RC=$?"
RC=1                                            (le paquet n'est PAS déclaré)
```

**Zéro modèle annoté, zéro `@JsonSerializable`, `zcrud_generator` absent du `pubspec`.** L'hôte
consomme **29 paquets zcrud sur 41** ; les 12 non consommés sont `zcrud_generator`, `zcrud_dnd`,
`zcrud_field_extras`, `zcrud_reorder`, `zcrud_media`, `zcrud_html`, `zcrud_export_ui`, `zcrud_geo`,
`zcrud_geo_location`, `zcrud_chat_firestore`, `zcrud_chat_study`, `zcrud_get`. Aucun document du
relevé ne dresse cette liste.

---

## 3. CONTRADICTIONS INTERNES — le relevé se contredit sur les mêmes fichiers

### 3.1 🔴 `appointment_editor.dart` : « migrable pour 2 500 l » **et** « manque au socle »

Le **même fichier**, les **mêmes trois classes**, deux documents du même relevé, verdicts opposés :

| | `confrontation-socle-app.md:204-249` (M3) | `confrontation-taches-decouverte.md` (N2) |
|---|---|---|
| Verdict | 🔴 **MIGRABLE AUJOURD'HUI** | 🔴 **MANQUE AU SOCLE** |
| Thèse | « Le socle rend les trois surfaces d'**une** déclaration » — `ZPresentationPolicy` + 46 `EditionFieldType` | « un **satellite** `zcrud_calendar` » à écrire ; `SfCalendar`/`timezone`/`attendee` → **RC=1** dans tout `packages/*/lib` |
| Chiffre | **2 500 l** comptées dans le total ≈ 4 750 | comptées dans « ≈ 3 200 l de manque » |
| `PopUpAppointmentEditorState` | **657 l** | **658 l** |
| `AppointmentEditorWebState` | **3 507 l** | **3 508 l** |
| `AppointmentEditorState` | **927 l** | **928 l** |

Le fichier existe et fait bien **7 858 lignes** (`wc -l` vérifié). L'écart d'**une ligne sur chacune
des trois classes** prouve que les deux mesures sont indépendantes et que **personne n'a comparé**.
Un lecteur qui additionne les deux confrontations compte ces lignes une fois en gain et une fois en
dette.

**À trancher** : le seam `EditionFieldType.custom` + `ZWidgetRegistry` (thèse M3) suffit-il quand
`SfCalendar`, le fuseau horaire, les participants et le dialogue « cette occurrence / toute la
série » sont absents (thèse N2) ? Les deux ne peuvent pas être vraies.

### 3.2 🔴 `presentFormEdition` : les mêmes quatre fichiers, chiffrés **× 3**

| Fichier | `confrontation-formulaires-crud.md:162-176` | `confrontation-etude-matieres-corpus.md:93-99` |
|---|---:|---:|
| `subject_zcrud_edition.dart` | 45 | **124** |
| `folder_document_zcrud_edition.dart` | 39 | **91** |
| `valuation_tool_model_zcrud_edition.dart` | 49 | **117** |
| `ai_router_zcrud_edition.dart` | 58 | **250** |
| **Sous-total** | **191** | **582** (→ ≈ 420 net) |

Deux conventions de mesure jamais réconciliées : `formulaires-crud` compte
`chrome + dispose + bloc ZEditionSubmitController` ; `etude-matieres` compte « de la déclaration du
`Screen` à EOF ». **Facteur 2,2 à 4,3.** Les deux chiffres alimentent deux totaux de domaine
(≈ 6 234 et ≈ 2 080) qui seront additionnés par le premier lecteur venu.

Accessoirement, `etude-matieres` s'attribue `ai_router_zcrud_edition.dart` (domaine IA) et
`valuation_tool_model_zcrud_edition.dart` (domaine examens/valuation) : **fuite de périmètre**.

### 3.3 🔴 `lib/workflow/` (17 417 l) appartient à deux cartes

`carte-socle-app.md:11` : « `lib/workflow/` | 38 | **17 417** ».
`carte-taches-decouverte.md:19` : « 🔴 `lib/workflow/` (**inclus au-delà**) | 38 | 17 417 ».

Et le compteur `setState` de `carte-taches-decouverte.md:136` (« **158** ») **est exactement** celui
de `lib/workflow/` :
```
$ grep -rn 'setState(' lib/workflow | wc -l  →  158
```
tandis que `carte-socle-app.md:96` annonce « `setState(` **185**/15 » pour ses neuf dossiers — dont
le même `lib/workflow/`. Les deux mesures se recouvrent à 85 %.

### 3.4 🔴 Deux cartes pour un seul répertoire de flashcards

| | `carte-revision-flashcards.md:9-21` | `carte-revision-srs-sessions.md:9-21` |
|---|---|---|
| Zone principale | `features/flashcards/**` — 35 f., **18 178 l** | `features/flashcards/**` — 35 f., **18 178 l** |
| Total périmètre | **47 f. / 20 991 l** | **49 f. / ≈ 21 073 l** |

**Le même répertoire, deux fois.** Les deux confrontations proposent des canaux qui se répètent
(`ZSessionCardSwiper` : M8 chez l'une, M8 chez l'autre ; `zApplyTestFilters` : M5 / M4 ;
`zEvaluateLocally` : M4 / — ; `ZSessionSummaryView` : M7 / M7). L'une chiffre **≈ 6 776**, l'autre
ne chiffre pas. Le découpage « flashcards » / « SRS-sessions » n'a **aucune traduction sur disque**.

### 3.5 La cause structurelle : chevauchement massif des canaux, jamais dédupliqué

Nombre de confrontations (sur 11) qui revendiquent le **même** canal du socle :

| Canal | Confrontations le revendiquant |
|---|---:|
| `presentFormEdition` | **10** |
| `showZConfirmDialog` | **9** |
| `ZEmptyState` | **8** |
| `ZContentStateView` | **8** |
| `ZCrudScreen` | **7** |
| `ZItemActionsMenu` | **5** |
| `ZAdaptiveGrid` | **5** |
| `ZSearchableAppBar` | **5** |
| `@ZcrudModel` | **5** |

Aucun document n'écrit combien de sites hôte distincts chaque canal couvre **au total**. Seul
`confrontation-taches-decouverte.md:599` prend la précaution explicite (« séparé pour ne pas être
compté deux fois par un autre »). **Un sur onze.**

### 3.6 Collision de numérotation avec les vagues officielles de l'hôte

Le relevé numérote ses lots `M1…M11` et `N1…N6` **par document**. L'hôte utilise déjà `M1…M8`
(`plan-migration-zcrud-v2.md`) et `N0…N7` (`plan-modeles-zentity-codegen.md`) comme **vagues
officielles de sa migration**. Résultat, cinq sens différents pour « M7 » :

| Source | « M7 » désigne |
|---|---|
| `decisions-adoption-zcrud.md:15` | la **migration de schéma** (`ZFieldRename`) |
| `confrontation-socle-app.md:75` | l'app-bar recherchable (372 l) |
| `confrontation-revision-srs-sessions.md:195` | le résumé de fin de session |
| `confrontation-taches-decouverte.md:294` | `ZActionMenu` / `ZContextMenuRegion` |
| `confrontation-etude-dossiers.md` | la cascade de suppression |

Idem « N3 » : `confrontation-taches-decouverte.md:417` = l'entité tâche ; hôte = le codegen du
groupe B. **Renuméroter, ou préfixer par domaine.**

### 3.7 Deux cartes se trompent sur la branche mesurée

`carte-examens.md:4` : « branche **`main`** ». Réel : `git branch --show-current` →
**`feat/migration-zcrud`**. Les neuf autres cartes ont le bon nom. Le HEAD (`65d1af9`) est correct
partout — l'erreur est sans conséquence sur les mesures, mais elle invalide la reproductibilité
annoncée.

---

## 4. LES TRANSVERSES — catalogués côté socle, jamais mesurés côté hôte

L'hypothèse « aucun transverse n'a été traité » est **fausse** : `capacites-zcrud-donnees-transverse.md`
porte six chapitres transverses (`:64` seams, `:112` thème, `:204` l10n, `:250` a11y/RTL, `:271`
hors-ligne, `:297` granularité). Le vrai défaut est ailleurs : **ces chapitres décrivent ce que le
socle GARANTIT, pas ce que l'hôte DOIT.**

### 4.1 🔴 Accessibilité et RTL — zéro mesure de l'hôte

```
$ awk 'NR>=250 && NR<=270' capacites-zcrud-donnees-transverse.md | grep -ciE "hôte|iffd"
0
```

Le chapitre §4 est une table de **garanties du socle** (tests de pureté, planchers tactiles). Aucun
chiffre d'IFFD. Ce qui n'est écrit nulle part dans le relevé (mesuré ce jour sur `lib/`, `.g.dart`
exclus) :

| Motif non directionnel (AD-13) | Sites |
|---|---:|
| `EdgeInsets.only(… left\|right:)` | **80** |
| `EdgeInsets.fromLTRB(` | **24** |
| `Alignment.{center,top,bottom}{Left,Right}` | **104** |
| `TextAlign.left\|right` | **13** |
| `BorderRadius.only(` | **27** |
| `Positioned(left\|right:` | **1** |
| **Total app-wide** | **249** |
| `Semantics(` — pour 105 `StatefulWidget` | **25** |

Grep négatif du relevé : `grep -rn "249 site" .` → RC=1. Les seuls comptes existants sont **partiels
et concurrents** (`confrontation-socle-app.md:26` → 103 ; `carte-taches-decouverte.md:288-290` → 71),
et ils portent sur des périmètres qui se recouvrent (§3.3).

### 4.2 🔴 Granularité des reconstructions — l'objectif produit n°1 n'a pas de verdict

`capacites-zcrud-donnees-transverse.md:297` ouvre « §6 TRANSVERSE — granularité des reconstructions
(objectif produit n°1) ». Le chapitre liste `DynamicEdition.onStructuralBuild`, `ZDisplayState`… et
**ne mesure rien chez l'hôte**. Mesuré ce jour :

```
$ grep -rn "setState("            lib | wc -l  →  420
$ grep -rn "extends StatefulWidget\|extends ConsumerStatefulWidget" lib | wc -l  →  105
$ grep -rn "ValueListenableBuilder\|ListenableBuilder" lib | wc -l  →  104
$ grep -rn "ConsumerWidget\|ConsumerStatefulWidget\|ref.watch" lib | wc -l  →  146
```

**420 `setState`** dans l'application qui adopte un socle dont la raison d'être est de les supprimer.
Aucun document ne pose la question SM-1 pour IFFD, ni ne dit quels écrans en sortiraient. Les
comptes existants sont, là encore, partiels et non additionnables (185 / 158 / 72 / 158…).

### 4.3 🔴 Thème et couleurs — pas de total, pas de chiffrage FR-26

Mesuré : **1 762** `Colors.<nom>` + **463** `Color(0x…)` = **2 225 sites** de couleur codée en dur
dans `lib/` (hors `.g.dart`). L'hôte n'a que **161 lignes** de jetons
(`lib/src/config/themes/iffd_tokens.dart`, 13 champs) et **un seul** `ZcrudScope(theme:)`
(`z_iffd_field_registry.dart:354`). Le relevé cite `iffd_tokens` dans **1** fichier sur 60.
Les seuls chiffres existants sont locaux (`carte-examens.md:546` → 268 ;
`confrontation-revision-srs-sessions.md:24` → 313 + 89). **Aucun total, aucun chiffrage du coût
FR-26.**

### 4.4 🔴 Tests et QA — le coût de la migration côté vérification est absent

```
$ find test -name '*_test.dart' | wc -l  →  224      (228 fichiers .dart dans test/)
$ grep -rniE "tests à réécrire|coût de (la )?QA|non-régression" docs/analyses/iffd-migration-2026-08-26/
$ echo "RC=$?"
RC=1
```

**224 fichiers de test chez l'hôte, et pas une ligne du relevé sur ce que la migration leur fait.**
C'est d'autant plus grave que l'hôte pratique le **tripwire** recommandé par les handoffs
(`carte-ia-chat-generation.md:636` : « 17 fichiers portent un tripwire ») : chaque correction du
socle **fait rougir** un test de l'hôte, par conception. Le relevé propose des dizaines de
migrations sans jamais dire lesquelles cassent quel tripwire.

### 4.5 🔴 Le « DÉJÀ MIGRÉ » repose sur 52 bascules dont **zéro** validée

```
$ grep -c "^    id: '" lib/src/presentation/shared/zcrud/z_qa_flags.dart   →  52
$ grep -o "\[ \]" docs/qa-plan-comparaison-legacy-zcrud.md | wc -l          →  198
$ grep -o "\[x\]" docs/qa-plan-comparaison-legacy-zcrud.md | wc -l          →  0
```

`confrontation-revision-srs-sessions.md:41` est le **seul** document à publier ce couple 198/0.
Les onze sections « DÉJÀ MIGRÉ » du relevé décrivent donc un état **porté mais non validé** — et
aucune ne le dit dans son en-tête. `confrontation-socle-app.md:401` (R9) le frôle : « c'est un état
de migration, pas une architecture ».

### 4.6 🔴 Dépendances tierces — 122 déclarées, aucun inventaire de retrait

Une seule section dans tout le relevé (`confrontation-revision-srs-sessions.md:448`,
« Dépendances tierces retirées »). Or c'est l'un des bénéfices les plus concrets de l'adoption.
Mesuré : **122 dépendances non-zcrud** dans `dependencies:`. Candidates au retrait par un canal du
socle, avec leur emprise réelle :

| Tiers | Fichiers | Canal du socle |
|---|---:|---|
| `flutter_form_builder` (+3 `form_builder_*`) | 14 | `DynamicEdition` |
| `expandable` | 11 | `zcrud_ui_kit` |
| `flutter_flow_chart` | 7 | — (manque réel, cf. `confrontation-mindmap.md:3.2`) |
| `awesome_select` | 6 | `zcrud_select` |
| `popup_menu`, `star_menu`, `flutter_expandable_fab` | 5+3+2 | `ZActionMenu` |
| `flutter_switch` | 5 | `z_iffd_boolean_field` |
| `skeletonizer` | 4 | `ZLoadingState` |
| `flip_card`, `flutter_card_swiper` | 3+2 | `ZSessionCardSwiper` |
| `toastification`, `confetti` | 2+2 | `ZToast`, `ZSummaryCelebration` |
| `spaced_repetition` | **1** | `ZSrsScheduler` |

Et **13 dépendances déclarées sans un seul import** dans `lib/` ni `test/` :
`cupertino_icons`, `firebase_performance`, `cloud_firestore_platform_interface`, `json_annotation`,
`awesome_dio_interceptor`, `form_builder_extra_fields`, `form_builder_file_picker`, `animated_icon`,
`flex_seed_scheme`, `loading_overlay`, `scroll_to_index`, `async`, `ms_map_utils`.
*(Certaines sont légitimement plugin-only — `cupertino_icons`, `firebase_performance` ; au moins
huit sont des bibliothèques Dart pures, dont `json_annotation` cohérent avec les 0 `@JsonSerializable`.)*

### 4.7 l10n — le transverse est **réel mais non bloquant**, et il fallait le dire

```
$ find . -name '*.arb' -not -path './build/*' ; echo "RC=$?"      →  RC=1
$ grep -rn "AppLocalizations\|context.l10n\|S.of(context)" lib | wc -l  →  0
$ grep -n "supportedLocales" lib/main.dart   →  const supportedLocales = [Locale("fr")];
```

IFFD est **monolingue français, sans ARB**. Les 22 fichiers `l10n/` de `workflow/` + `accounting/`
sont recensés (`confrontation-socle-app.md:402` : « dont **14 fichiers de 4 lignes, vides** »).
Le seul fait transverse réel est déjà écrit **chez l'hôte**, pas dans le relevé
(`iffd/lib/main.dart:290-306`) : le delegate `zcrud_core` n'était pas monté, et « chaque bouton,
état vide et message d'erreur venu du socle sortait en anglais ». **Ce transverse est bien couvert
côté hôte ; le relevé ne le reprend pas.**

### 4.8 Hors-ligne / synchronisation — **correctement traité**, à noter pour ne pas le rouvrir

`capacites-zcrud-donnees-transverse.md:271-296` et `:352-400` portent les contrats **et** la mesure
hôte (`ZSyncMeta` **84** sites ; `ZSyncOrchestrator`, `ZClock`, `HiveZLocalStore`,
`FirestoreZRemoteStore` **0** chacun). Vérifié : `grep -rn "\bHive\b" iffd/lib` → **0**,
`ZSyncOrchestrator` → **0**. Rien à ajouter.

---

## 5. LES QUATRE DOSSIERS NOMMÉS PAR LE BRIEF — verdict mesuré

Volumétrie réelle des huit racines de `lib/` (549 fichiers `.dart`, **179 222 lignes**) :

| Racine | Fichiers | Lignes | Couverture du relevé |
|---|---:|---:|---|
| `lib/src/` | 414 | 127 189 | ✅ onze cartes |
| `lib/workflow/` | 38 | 17 417 | ⚠️ **deux fois** (§3.3) |
| `lib/data_crud/` | 24 | 14 980 | ✅ `carte-formulaires-crud` |
| `lib/ai_assistant/` | 37 | 14 183 | ✅ `carte-ia-chat-generation` |
| `lib/accounting/` | 26 | 2 783 | 🟡 **3 fichiers, en marge** |
| `lib/cotation/` | 3 | 624 | 🟡 **2 fichiers, en marge** |
| `lib/gen/` | 1 | 487 | 🟡 1 fichier |
| `lib/douanes_togolaises/` | **0** | **0** | ✅ sans objet |

**`lib/douanes_togolaises/` est un répertoire VIDE** — il ne contient qu'un sous-dossier `utils/`
lui-même vide (`find lib/douanes_togolaises -type f` → aucune sortie). Ce n'est pas un pan oublié :
c'est un résidu à supprimer côté hôte.

**`accounting/` et `cotation/` sont couverts**, mais **hors du modèle du relevé** : ils sont classés
« RESTE À L'HÔTE » (`confrontation-socle-app.md:399` R7 le plan SYSCOHADA ; `:400` R8 la cotation), et
la réfutation le prouve proprement (`grep -rn "DynamicModel" lib/accounting/` → **RC=1**, donc le
correctif `ZCrudScreen` n'y mord pas ; 402 des 647 l. d'écrans ne relèvent pas du canal). **Verdict :
l'hypothèse d'un pan non couvert est réfutée pour ces trois dossiers.** Ce qui manque n'est pas la
couverture, c'est le **fait que 3 407 lignes soient déclarées hors périmètre sans jamais apparaître
dans un dénominateur** (§1.1).

**Le plus gros fichier d'IFFD n'est cité nulle part comme tel** : `lib/src/utils/constants/sh2022.dart`
= **9 415 lignes** (5,3 % de `lib/`), un blob de données — la nomenclature douanière SH2022. Une seule
mention en passant (`carte-revision-flashcards.md:261`). Toute statistique « lignes de `lib/` » du
relevé l'inclut silencieusement.

---

## 6. LES « MANQUES AU SOCLE » — sondage de vérification : **0 faux sur 5**

Cinq manques déclarés, re-vérifiés dans le code du socle :

| Manque déclaré | Vérification | Verdict |
|---|---|---|
| `formulaires-crud` L7 — aucune implémentation de `ZNumberDisplayFormatter` | `grep -rn "implements\|extends ZNumberDisplayFormatter" packages/*/lib` → **0** (6 hits, tous dans `test/`) | ✅ **confirmé** |
| `formulaires-crud` L3 — `beforeSubmit` n'existe que sur `ZCrudScreen` | 3 hits, tous `zcrud_screen/…/z_crud_screen.dart` (`:218`, `:671`, `:1710`) | ✅ **confirmé** |
| `etude-matieres` G3 — aucun créneau d'état vide sur `ZCrudScreen` | `grep -n "emptyBuilder\|emptyState\|emptyView" zcrud_screen/lib` → **0** ; les 40 hits `empty` de `z_crud_screen.dart` sont tous `isEmpty`/`exportEmpty` | ✅ **confirmé** |
| `etude-matieres` G1 — `ZDocumentAnnotationKind` n'a que 2 valeurs | `z_document_annotation_kind.dart:23-30` → `highlight`, `stickyNote` | ✅ **confirmé** |
| `mindmap` 3.2 — canevas libre absent | 3 occurrences de `flutter_flow_chart` dans `packages/*/lib`, **toutes en dartdoc** (`z_study_mindmap_section.dart:12`, `z_study_codec.dart:87`) | ✅ **confirmé** |

**Aucun faux manque trouvé sur cet échantillon.** La discipline du grep négatif montré est
réellement tenue dans les sections « MANQUE AU SOCLE ». C'est le point fort du relevé, et il
contraste avec l'absence totale de vérification croisée **entre** documents (§3).

⚠️ **Deux confrontations n'ont pas de section « MANQUE AU SOCLE » structurée** :
`confrontation-notes-smartnotes.md` (`:225` — un titre, pas de sous-sections) et
`confrontation-revision-flashcards.md` (aucun `### ` sous le titre). À compléter ou à déclarer vide
explicitement.

---

## 7. MÉTHODE — un angle mort structurel dans la matière d'entrée

Le brief demandait de « lire les `CHANGELOG.md` des paquets, pas seulement le code ». **C'est
impossible pour 14 paquets sur 41** : leur `CHANGELOG.md` est un stub figé, deux à trois majeures
derrière leur `pubspec`.

| Paquet | `pubspec version:` | tête du `CHANGELOG.md` | lignes du fichier |
|---|---|---|---:|
| `zcrud_exam` | **3.21.0** | `[0.86.0] — Chantier documentation` | 30 |
| `zcrud_flashcard` | **3.21.0** | `[0.86.0] — Chantier documentation` | 29 |
| `zcrud_session` | **3.21.0** | `[Non publié] — Chantier documentation` | 34 |
| `zcrud_note` | **3.21.0** | `[0.86.0] — Chantier documentation` | 30 |
| `zcrud_mindmap` | **3.21.0** | `[0.86.0] — Chantier documentation` | 30 |
| `zcrud_chat_study`, `zcrud_dnd`, `zcrud_html`, `zcrud_media`, `zcrud_field_extras`, `zcrud_export_ui` | 3.21.0 | `[0.86.0]` | ~30 |
| `zcrud_geo`, `zcrud_intl` | 3.21.0 | `0.1.0` | — |
| `zcrud_geo_location` | 3.21.0 | `0.81.0` | — |

**Ce sont exactement les paquets des domaines analysés** (examens, flashcards, sessions, notes,
mindmap). Un seul document l'a vu et l'a écrit : `capacites-zcrud-etude-revision.md:123` — « la
matière récente vit dans `docs/handoff-v3.*.md`, pas dans les CHANGELOGs ». Les quatre autres
catalogues ne le disent pas, et **4 fichiers sur 60** citent un handoff.

⇒ **Deux actions distinctes** : (1) côté relevé, rejouer les catalogues `etude-revision`, `ia`,
`edition`, `listes-ecrans` contre `docs/handoff-v3.6.0.md → v3.21.0` ; (2) côté socle, c'est un
défaut de publication à corriger — 14 CHANGELOG mensongers pour un consommateur en dépendance git.

---

## 8. Ce qu'il faut faire, par ordre de coût décroissant du risque

| # | Action | Pourquoi |
|---|---|---|
| **1** | **Trancher §3.1** — `appointment_editor.dart` est-il migrable (2 500 l de gain) ou un manque (satellite `zcrud_calendar`) ? | Les deux verdicts sont publiés ; l'un des deux est faux, et il pèse ~2 500 l dans un sens ou dans l'autre |
| **2** | **Lire `decisions-adoption-zcrud.md` + `plan-modeles-zentity-codegen.md`** (1 278 l) et rejouer les 4 propositions codegen | ≥ 4 470 l revendiquées contre un chantier déjà arbitré par l'owner et contraint à `ZFieldRename.none` |
| **3** | **Écrire la page de synthèse** : dédupliquer, réconcilier §3.2, chiffrer `mindmap` + `revision-flashcards`, ordonner par dépendance | Sans elle, 22 756 lignes ne produisent aucune décision |
| **4** | **Fusionner** `revision-flashcards` et `revision-srs-sessions` ; **arbitrer** `lib/workflow/` entre `socle-app` et `taches-decouverte` | Deux périmètres comptés deux fois |
| **5** | **Ajouter un chapitre transverse HÔTE** : 249 sites RTL, 25 `Semantics`, 420 `setState`, 2 225 couleurs, 224 tests, 198 cases QA à 0, 122 tiers | Six sujets qui ne sont le domaine de personne |
| **6** | **Renuméroter** les lots (préfixe de domaine) | Cinq sens pour « M7 », dont celui de l'hôte |
| **7** | Corriger `carte-examens.md:4` (branche) ; signaler à l'hôte `lib/douanes_togolaises/` vide et les 13 dépendances sans import | Hygiène |
| **8** | Rejouer les 4 catalogues contre les handoffs `v3.6.0 → v3.21.0` | 14 CHANGELOG figés à `0.86.0` |
