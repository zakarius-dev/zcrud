# Audit de parité — widgets de session `zcrud_session` ↔ natifs `lex_ui`

> **Date** : 2026-07-26 · **Story** : SUF-4 (clôture de l'epic SUF) · **Méthode** : lecture croisée
> widget-par-widget, **chemins + n° de ligne vérifiés sur disque des DEUX côtés**.
> **Source canonique** : `/home/zakarius/DEV/lex_douane` — **LECTURE SEULE ABSOLUE** (aucune écriture,
> aucun fichier créé ni modifié dans ce dépôt ; seuls `grep`/lecture ont été employés).
> **Cible** : `/home/zakarius/DEV/zcrud/packages/zcrud_session`.
> **Usage** : preuve que l'app lex_douane peut bridger le flux de session complet
> (mode-selector → boutons SRS → indicateur → bilan) **sans perte visuelle ni fonctionnelle**.
>
> ⚠️ Les n° de ligne `zcrud` sont ceux d'**APRÈS** les fermetures livrées par SUF-4 ; quand une preuve
> porte sur l'état **AVANT**, elle est rejouée via `git show HEAD:<fichier>` (commande consignée).

---

## 1. Réponse courte

- **Paire 1 (boutons SRS)** — parité **fonctionnelle complète** (échelle dérivée, preview d'intervalle,
  suggestion IA). **Un écart VISUEL réel** : l'affordance d'emphase de zcrud était **figée** (fond plein,
  zéro bord) alors que lex l'exprime par **teinte + bord** (`0.12`→`0.24`, `1`→`2` px). **FERMÉ** par
  `ZSrsQualityEmphasis` (dimensions injectables, aucune couleur).
- **Paire 2 (bilan de session)** — « Encore N dues » et pilules de répartition : **parité**. **Un écart
  réel mineur** : zcrud omettait les crans à `0`, lex les affiche toujours (répartition à longueur
  stable). **FERMÉ** par `ZQualityBreakdownCoverage.wholeScale` (+ pass-through sur `ZSessionSummaryView`).
- **Paire 3 (sélecteur de mode)** — **DIVERGENCE STRUCTURELLE assumée, pas un manque à combler.** Les
  deux widgets ne répondent pas à la même question. Les 3 capacités interrogées sont **atteignables par
  composition** (`ZTestFiltersDialog` + hôte) ou **délibérément absentes**. **Aucun code ajouté** —
  preuve négative ci-dessous. Un redesign 6-modes serait hors périmètre et non demandé.
- **Paire 4 (indicateur de progression)** — **ÉCART RÉEL et FORT** : aucun mode barre **continue** face
  au `LinearProgressIndicator(minHeight: 6)` de lex. **FERMÉ** par `ZSessionProgressStyle.linear`
  (épaisseur **thémable + injectable**, jamais le `6` en dur).

**Verdict migration** : les 4 paires sont bridgeables. 3 écarts réels fermés par **slots additifs**
(défauts inchangés ⇒ zéro régression) ; 1 divergence structurelle documentée et composable.

---

## 2. Matrice de parité

Légende : ✅ parité (directe ou par bridge) · 🟡 atteignable par **composition** (l'hôte assemble) ·
🔧 **écart réel FERMÉ** par un slot injectable livré ici · ❌ absent et **assumé** (hors contrat).

| # | Question de la spec | lex (source canonique) | zcrud (avant SUF-4) | Statut |
|---|---|---|---|---|
| 1a | Échelle **5 crans** ? | `Sm2QualityLevel.values` — `srs_quality_buttons.dart:134` | `ZQualityScale.fromConfig` dérive `[min..max]` de `ZSrsConfig` — `z_srs_quality_buttons.dart:53` | ✅ parité par bridge (AD-46, aucun littéral) |
| 1b | **Preview d'intervalle** ? | `_intervalLabel` → `srsIntervalPreviewLabel` — `srs_quality_buttons.dart:116,26` | seam `previewLabelFor` — `z_srs_quality_buttons.dart:229` | ✅ parité (l'hôte branche `simulate`) |
| 1c | **Surbrillance du niveau suggéré IA** ? | `suggested` → `alpha 0.24` vs `0.12` (`:214`) + `width: 2` vs `1` (`:227`) + `Semantics(selected:)` (`:211`) | `selectedQuality` → `Semantics(selected:)` + icône coche + annonce ; **fond plein, aucun bord, FIGÉS** | 🔧 **écart fermé** — `ZSrsQualityEmphasis` (`z_srs_quality_buttons.dart:120`) |
| 2a | Bouton **« Encore N dues »** ? | `_MoreDueButton`, absent si `n <= 0` — `session_summary_view.dart:209,218` | `dueRemaining` + `onContinue`, absent si `0` — `z_session_summary_view.dart:180,536` | ✅ parité stricte (patron AD-45 des deux côtés) |
| 2b | **Pilules de répartition** ? | `SessionQualityBreakdown` — `session_summary_view.dart:153`, `session_quality_breakdown.dart:26` | `ZSessionQualityBreakdown` — `z_session_summary_view.dart:421` | ✅ parité |
| 2b′ | …crans **à 0** affichés ? | **OUI** : `for (level in Sm2QualityLevel.values)` + `histogram[level] ?? 0` — `session_quality_breakdown.dart:71,78` | **NON** : filtre `containsKey` — `HEAD:z_session_quality_breakdown.dart:77` | 🔧 **écart fermé** — `ZQualityBreakdownCoverage.wholeScale` (`:46`) |
| 3a | **`FilterChips`** ? | tags + types + portée — `study_mode_selector_screen.dart:106,116,97` ; `FilterChip` en `:269` | **aucun `FilterChip`** dans `zcrud_session/lib` ; filtres = **maîtrise + source** (`z_test_filters_dialog.dart:188,209`) | 🟡 axes DIFFÉRENTS, composables (§4.3) |
| 3b | **Stepper de N** ? | `_CountStepper` sur `cycleCount` — `study_mode_selector_screen.dart:84,281` | `_QuestionCountStepper` (bornes **injectées**) — `z_test_filters_dialog.dart:177,274` | 🟡 **présent**, mais dans le dialog (composition) |
| 3c | **Sémantique radio** ? | `inMutuallyExclusiveGroup: true` — `mode_selector_card.dart:49` | `_ModeTile` : `button: true`, **aucun** `inMutuallyExclusiveGroup` — `z_session_mode_selector.dart:254` | ❌ **assumé** : les tuiles zcrud **lancent**, elles ne **sélectionnent** pas (§4.3) |
| 4a | `LinearProgressIndicator` **continu**, `h=6` ? | `_SessionHeader` — `study_session_screen.dart:472,511,513` | **aucun** : seuls `dots`/`segmentedBar` (N éléments par carte) | 🔧 **écart fermé** — `ZSessionProgressStyle.linear` (`z_session_progress_indicator.dart:72`) |
| 4b | Bouton **fermer** + **titre** de l'en-tête ? | `IconButton(Icons.close_rounded)` + `Text(sessionProgress(...))` — `study_session_screen.dart:495,501` | **hors du widget** — composition d'en-tête (SUF-1 `ZPageScaffold` / app-side) | ✅ **preuve négative** (§4.4) — non-écart |

---

## 3. Preuves NÉGATIVES (commande + RC, rejouées le 2026-07-26)

> Discipline « réalité du code » : **toute absence est prouvée par un grep**, jamais affirmée de mémoire.
> `RC=1` = aucune correspondance (l'absence est vraie). Toutes les commandes sont lancées depuis
> `/home/zakarius/DEV/zcrud`.

```console
### P4-1 : AUCUN LinearProgressIndicator dans zcrud_session AVANT SUF-4
$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart \
    | grep -n "LinearProgressIndicator"
RC=1

### P4-2 : AUCUN style continu dans l'enum AVANT SUF-4
$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart \
    | grep -nE "^\s+(linear|continuous),"
RC=1

### P4-3 : le bouton fermer / le tooltip ne sont PAS dans le widget zcrud (non-écart : composition)
$ grep -rn "Icons.close\|closeButtonTooltip" \
    packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart
RC=1

### P3-1 : AUCUN FilterChip dans TOUT zcrud_session/lib
$ grep -rn "FilterChip" packages/zcrud_session/lib/
RC=1

### P3-2 : AUCUNE sémantique radio dans le sélecteur de mode
$ grep -n "inMutuallyExclusiveGroup\|selected:" \
    packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart
RC=1
   (contre-preuve : le motif EXISTE ailleurs dans le package —
    z_flashcard_answer_input.dart:1081 `inMutuallyExclusiveGroup: single` — donc ce n'est
    ni une méconnaissance de l'API ni un grep mal formé : c'est un choix.)

### P3-3 : AUCUN stepper dans le sélecteur de mode
$ grep -n "Stepper\|Increment\|increment" \
    packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart
RC=1

### P1-1 : AUCUN bord ni teinte d'emphase dans la rangée SRS AVANT SUF-4
$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart \
    | grep -nE "BorderSide|withValues|Border\.all"
RC=1

### P1-3 : AUCUN littéral de borne d'échelle (AD-46 tenu)
$ grep -nE "minQuality = [0-9]|maxQuality = [0-9]|qualities = <int>\[0" \
    packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart
RC=1
```

Preuves **POSITIVES** correspondantes (ce qui EXISTE, pour que l'audit ne soit pas qu'une liste de
manques) :

```console
### P3-4 : le stepper EXISTE — dans le dialog de filtres (paire 3b)
$ grep -n "_QuestionCountStepper\|questionCountIncrementKey" \
    packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart
97:  static const ValueKey<String> questionCountIncrementKey =
177:            _QuestionCountStepper(
274:class _QuestionCountStepper extends StatelessWidget {          RC=0

### P2-1 : « Encore N dues » EXISTE et disparaît à 0 (paire 2a)
$ grep -n "dueRemaining\|showContinue" \
    packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart
180:  final int dueRemaining;
536:    final showContinue = widget.dueRemaining > 0 && onContinue != null;   RC=0

### P2-2 : la CAUSE de l'écart 2b′, sur le code d'AVANT
$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart \
    | grep -n "containsKey"
77:        if (byQuality.containsKey('$quality'))                            RC=0
```

---

## 4. Audit détaillé, paire par paire

### 4.1 — `ZSrsQualityButtons` ↔ `SrsQualityButtons`

| | lex `packages/lex_ui/lib/presentation/widgets/study/srs_quality_buttons.dart` | zcrud `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` |
|---|---|---|
| Classe | `:55` `ConsumerWidget` (Riverpod) | `:195` `StatelessWidget` **pur** (AD-2/AD-15) |
| Échelle | `Sm2QualityLevel.values` (`:134`) — enum fermé de 5 | `ZQualityScale.fromConfig` (`:53`) — **dérivée** de `ZSrsConfig` |
| Couleur | `AppColors.srs*` en dur (`:83-96`) | seam `colorKeyFor` → `zResolveColorKeyOrSlot` |
| Libellé | `l10n.quality*` (`:98-111`) | seam `labelKeyFor` → `label(context, …)` |
| Preview | `srsIntervalPreviewLabel` (`:26`, source unique partagée avec le pont zcrud) | seam `previewLabelFor` (`:229`) |
| Suggestion IA | `suggested` (`:146`) → `alpha 0.24/0.12` (`:214`), `width 2/1` (`:227`), `Semantics(selected:)` (`:211`) | `selectedQuality` (`:254`) → `Semantics(selected:)`, **icône coche**, annonce « sélectionné » |
| Cible tactile | `minHeight: 48` (`:220`) | `minTarget = 48` |
| Layout | responsive `LayoutBuilder` : `Row` ≥ 480 px, `Column` sinon (`:151-181`) | `Wrap` (reflow naturel) |

**Réponses aux 3 questions.**
1. *Échelle 5 crans* → ✅ **parité par bridge**. `ZSrsConfig(minQuality: 1, maxQuality: 5)` produit
   exactement 5 crans. Aucune borne n'est redéclarée côté UI (preuve négative P1-3), ce que la garde
   `z_quality_scale_single_source_test.dart` maintient.
2. *Preview d'intervalle* → ✅ **parité**. Les deux côtés déportent le calcul : lex dans une fonction
   partagée, zcrud dans un seam injecté. L'hôte lex branche sa propre `srsIntervalPreviewLabel`.
3. *Surbrillance du niveau suggéré* → 🔧 **ÉCART RÉEL, fermé.**
   - Sur le **canal a11y**, zcrud est un **superset** : lex ne pose que `selected:` ; zcrud pose
     `selected:` **et** annonce l'état en toutes lettres **et** rend une **forme** (coche) — lisible en
     niveaux de gris.
   - Sur le **canal visuel**, l'affordance zcrud était **figée dans le widget** : `Material(color:
     pair.color)` **opaque**, **sans aucun bord** (preuve négative P1-1). Un hôte lex bridgeant la
     rangée **perdait** sa teinte 12 %/24 % **et** son bord 1/2 px : c'est une perte visuelle nette,
     inatteignable par composition (le widget n'expose ni `child`, ni `decoration`).

**Fermeture livrée** — `ZSrsQualityEmphasis` (`:120`, exposée par le barrel) : un VO de **dimensions
seules** (`fillOpacity`, `selectedFillOpacity`, `borderWidth`, `selectedBorderWidth`). Il ne porte
**aucune couleur** — il module la couleur **déjà résolue par les seams**. Les valeurs de lex vivent
**côté app**. Défaut `ZSrsQualityEmphasis.none` ⇒ rendu **strictement** historique (`:386` : sans
opacité, **aucun** `withValues` n'est appliqué ; `:394` : `BorderSide.none`). Bornage AD-10 :
opacité clampée à `[0,1]`, épaisseur négative/NaN ⇒ `0`.

> **Non-écarts consignés** (aucune action) : le `ConsumerWidget` de lex est **interdit** ici (AD-2/AD-15,
> c'est l'écart NON-NÉGOCIABLE de zcrud) ; le layout `Wrap` vs `LayoutBuilder` est une **stratégie de
> reflow** équivalente à ≥ 48 dp près, non interrogée par la spec — non traité pour ne pas élargir le
> périmètre.

### 4.2 — `ZSessionSummaryView` ↔ `SessionSummaryView`

| | lex `…/widgets/study/session_summary_view.dart` | zcrud `…/z_session_summary_view.dart` |
|---|---|---|
| Classe | `:41` `ConsumerStatefulWidget` | `:129` `StatefulWidget` pur |
| « Encore N dues » | `_MoreDueButton` (`:209`), `if (n <= 0) return SizedBox.shrink()` (`:218`) | `dueRemaining` (`:180`), `showContinue` (`:536`), bouton en `:556` |
| Répartition | `SessionQualityBreakdown(histogram:)` (`:153`) | `ZSessionQualityBreakdown(byQuality:)` (`:421`) |
| Confetti | inconditionnel hors Reduce Motion (`:81`) | **opt-in** `ZSummaryCelebration` (défaut `none`), confiné au fichier |

**Réponses aux 2 questions.**
1. *Bouton « Encore N dues »* → ✅ **parité stricte**. Les deux appliquent le patron « une option à 0 est
   **absente**, jamais grisée » (AD-45). Différence de **provenance** seulement : lex lit un provider
   Riverpod, zcrud reçoit `dueRemaining` en prop — c'est l'inversion attendue (AD-2/AD-15), et l'hôte
   fait le pont en une ligne.
2. *Pilules de répartition* → ✅ pour la **présence** ; 🔧 **écart réel** sur la **couverture**.
   lex énumère `Sm2QualityLevel.values` et rend `histogram[level] ?? 0` (`session_quality_breakdown.dart:71,78`),
   sa dartdoc étant explicite : « un niveau à 0 reste affiché pour une **répartition stable** » (`:24`).
   zcrud filtrait sur `containsKey` (preuve P2-2) : une session sans aucun « Difficile » affichait
   **4 pilules** là où lex en montre **5**, et la longueur du bloc changeait d'une session à l'autre.

**Fermeture livrée** — `ZQualityBreakdownCoverage` (`z_session_quality_breakdown.dart:25`, **enum** et
non booléen, conformément à la norme du package) : `presentKeysOnly` (défaut, historique) /
`wholeScale`. Pass-through `ZSessionSummaryView.breakdownCoverage` (`:160,204,425`) — sans lui l'écart
resterait inatteignable, le breakdown étant construit **à l'intérieur** de l'écran de fin. Les clés
**hors échelle** restent rendues à part et signalées (R6), jamais fusionnées ni inventées, et la map
d'entrée n'est **pas mutée**.

### 4.3 — `ZSessionModeSelector` ↔ `StudyModeSelectorScreen` — divergence STRUCTURELLE

**Ce ne sont pas deux implémentations du même widget.** Ils répondent à deux questions différentes :

| | lex `…/screens/study_mode_selector_screen.dart:40` | zcrud `…/z_session_mode_selector.dart:58` |
|---|---|---|
| Nature | **écran de CONFIGURATION** (`Scaffold` + `AppBar` + `bottomNavigationBar`) | **composant LANCEUR** (`Column`, aucun chrome) |
| Sortie | une `StudySessionConfig` **puis** `pushNamed('study_session')` (`:162`) | **une file de cartes** via `onStart(kind, queue)` |
| Cardinalité | **6 modes** (`StudyMode.values`, `:69`) | **3 options** (`learnNew`/`review`/`test`) |
| Sélection | **persistante**, radio (`mode_selector_card.dart:49`) + barre « Commencer (n) » (`:137`) | **immédiate** : le tap **est** le lancement |
| Filtres | tags (`:106`), types (`:116`), portée sous-dossier (`:97`) | maîtrise + source, dans `ZTestFiltersDialog` |
| Comptage | `sessionMatchingCountProvider` en direct (`:51`) | `zCategorize` (fonction **pure**), compte par option |

**Réponses aux 3 questions** (après lecture **obligatoire** de `z_test_filters_dialog.dart`, faite) :

- *`FilterChips` ?* → **❌ absent en tant que tel** (preuve P3-1), mais **les filtres existent** : zcrud
  filtre par **seau de maîtrise** (`ZMasteryLevel.values`, `:188`) et par **`kind` de source** (registre
  **ouvert** AD-4, `:209`). Les **axes** diffèrent (tags/types chez lex, maîtrise/source chez zcrud), pas
  la capacité. Un hôte lex compose ses propres chips au-dessus de `zApplyTestFilters` : la fonction pure
  de filtrage est déjà en amont, dans `zcrud_flashcard` (AD-33). **Aucun code ajouté** : porter les axes
  de lex dans zcrud reviendrait à importer des concepts d'app (tags, `FlashcardType`) dans un package
  générique — exactement ce que la frontière interdit.
- *Stepper ?* → **🟡 PRÉSENT, ailleurs.** `_QuestionCountStepper` (`z_test_filters_dialog.dart:274`) règle
  le **nombre de questions**, bornes `min`/`max` **injectées** (`:76-78`) — plus configurable que le
  `_CountStepper` de lex, qui est borné à `[1, maxMatching]` en dur (`:146`). L'écart n'est pas
  « manque de stepper » mais **emplacement** : chez lex il est dans l'écran, chez zcrud dans le dialog
  que l'option « Test » ouvre (`z_session_mode_selector.dart:194`). **Composition, pas manque.**
- *Sémantique radio ?* → **❌ absente, et c'est CORRECT.** `_ModeTile` porte `button: true` (`:254`) sans
  `inMutuallyExclusiveGroup` (preuve P3-2). Une sémantique radio **annonce un état de sélection
  persistant** ; les tuiles zcrud n'en ont aucun — le tap **lance** la session. Poser
  `inMutuallyExclusiveGroup` sur un contrôle sans état sélectionné ferait **mentir** le lecteur d'écran
  (il annoncerait « non sélectionné » sur trois tuiles indéfiniment). La contre-preuve P3-2 montre que
  le motif est **connu et utilisé** ailleurs dans le même package (`z_flashcard_answer_input.dart:1081`)
  quand il y a une vraie sélection exclusive : ce n'est donc pas un oubli.

**Conclusion paire 3 — AUCUNE fermeture livrée, et c'est un choix motivé.** Combler « l'écart » exigerait
de transformer un lanceur en écran de configuration à 6 modes : la story l'exclut explicitement
(« ne pas redessiner un écran 6-modes »), et ce serait un widget **différent**, pas un slot. Le pont
app-side est direct : l'hôte lex garde son écran, compose sa `StudySessionConfig`, et n'utilise de zcrud
que ce dont il a besoin (dialog de filtres, boutons SRS, indicateur, bilan). **Aucune escalade
`correct-course` nécessaire** : rien n'est bloqué.

### 4.4 — `ZSessionProgressIndicator` ↔ `_SessionHeader`

`_SessionHeader` (`study_session_screen.dart:472`) est un **en-tête composite** de trois choses :

| Élément de `_SessionHeader` | Ligne | Contrepartie zcrud |
|---|---|---|
| `IconButton(Icons.close_rounded)` | `:495` | **hors périmètre du widget** — chrome de page (SUF-1 `ZPageScaffold` / app-side). Preuve négative P4-3. |
| `Text(l10n.sessionProgress(completed, total))` | `:501` | **hors périmètre** — même raison ; l'information existe déjà dans `Semantics(value:)`. |
| `LinearProgressIndicator(value: progress, minHeight: 6)` | `:511-513` | **ABSENT avant SUF-4** (preuves P4-1/P4-2) |

**Réponse à la question** → 🔧 **ÉCART RÉEL et FORT, fermé.** `dots` et `segmentedBar` rendent tous deux
**N éléments** (un par carte) : sur une file de 200 cartes, lex affiche une barre lisible et zcrud, 200
segments d'un pixel. Aucune composition d'appelant ne comble ça (le widget n'accepte pas de `child`).

**Fermeture livrée** — `ZSessionProgressStyle.linear` (`z_session_progress_indicator.dart:72`) :

- **épaisseur** : `resolvedLinearThickness` (`:177`) = `linearThickness` injectée si utilisable, sinon le
  token `ZcrudTheme.gapS`. **Le `6` de lex n'apparaît nulle part dans le package** — il est passé par
  l'app (la démo assemblée le fait, cf. §5). Valeur `<= 0`, `NaN` ou `∞` ⇒ repli thème (AD-10).
- **rayon** : `theme.radiusS` (défaut `Radius.circular(4)`, qui **coïncide** avec le `ClipRRect(4)` de
  lex — sans le coder).
- **couleurs** : `zResolveColorKeyOrSlot` (`'primary'` pour le remplissage, `'neutral'` pour la piste) —
  jamais un `Colors.*`.
- **fraction** : `resolvedLinearValue` (`:170`) dérive de `position`, **la même source** que le
  `Semantics(value:)`. La barre et l'annonce ne peuvent donc pas diverger.
- **a11y** : contrat **identique** aux deux autres styles ; le `value` reste porté par `progressKey`.

> 🔴 **Défaut MESURÉ pendant la fermeture** (pas anticipé) : passer `semanticsValue: null` au
> `LinearProgressIndicator` ne **supprime pas** son annonce — le framework la **calcule** (pourcentage).
> L'arbre sémantique réel portait **deux** valeurs : `« 2/4 »` (nœud zcrud) **et** `« 50 »` (nœud
> Material) ⇒ double annonce, dans deux unités. Corrigé par `ExcludeSemantics` (`:248`). La garde
> `suf4_parity_closures_test.dart` (« la progression n'est annoncée QU'UNE FOIS ») a rougi sur
> `['2/4', '50']` avant correction.

> **Nuance consignée (non-écart, non fermée)** : lex peint `completed/total`, zcrud `position/total` —
> soit **une carte d'écart** au plus. C'est un choix délibéré : la fraction peinte est **exactement**
> celle qu'annonce le lecteur d'écran. Aligner la barre sur `completed` désynchroniserait les deux
> canaux, ce que ce dépôt traque. L'hôte qui veut l'un ou l'autre pilote `currentIndex`.

---

## 5. Volet DÉMO — voie retenue et **preuve d'arêtes** (AC7)

### 5.1 Le conflit structurel est RÉEL et TOUJOURS OUVERT après SUF-2/SUF-3

Re-prouvé sur disque le 2026-07-26 (le `pubspec.yaml` de `zcrud_study` a changé en SUF-3, la preuve a
donc été **rejouée**, pas recopiée) :

```console
$ awk '/^dependencies:/,/^dev_dependencies:/' packages/zcrud_study/pubspec.yaml | grep -v '^#'
dependencies:
  flutter: {sdk: flutter}
  zcrud_core: ^0.18.0
  zcrud_study_kernel: ^0.18.0
  zcrud_annotations: ^0.18.0
  zcrud_mindmap: ^0.18.0          ← arête DURE, toujours là
  zcrud_flashcard: ^0.18.0
  zcrud_exam: ^0.18.0             ← arête DURE, toujours là
  zcrud_responsive: ^0.18.0
  zcrud_session: ^0.18.0
  zcrud_ui_kit: ^0.18.0

$ grep -rn "package:zcrud_mindmap\|package:zcrud_exam" packages/zcrud_study/lib/
lib/src/presentation/z_study_mindmap_section.dart:35   import 'package:zcrud_mindmap/zcrud_mindmap.dart';
lib/src/domain/z_mindmap_generation_port.dart:30       import 'package:zcrud_mindmap/…' show ZMindmapNode;
lib/src/presentation/z_exam_reminders_section.dart:19  import 'package:zcrud_exam/zcrud_exam.dart';
lib/src/presentation/z_exam_reminders.dart:38          import 'package:zcrud_exam/zcrud_exam.dart';
lib/src/presentation/z_exam_editor.dart:37             import 'package:zcrud_exam/zcrud_exam.dart';
```

Ces arêtes sont **consommées par du vrai code** (5 sites d'import). Les rendre optionnelles serait une
refonte d'architecture, hors périmètre SUF-4. Et `example/test/boundary_deps_test.dart` fait rougir
**par construction** tout `zcrud_mindmap` déclaré, y compris en `dependency_overrides` — or l'override
`path:` est **obligatoire** dès qu'un `zcrud_*` entre dans le lock de l'app isolée.

### 5.2 Voie retenue : **(b)** — démo assemblée en test d'assemblage bout-en-bout

- **Option (a)** (démo complète dans `example/`) : **IMPOSSIBLE sans violer AC10 de su-10**. Écartée.
- **Option (c)** (escalade `correct-course`) : **non nécessaire** — rien n'est bloqué, le parcours
  s'assemble intégralement là où les arêtes sont légitimes.
- **Option (b)** : la démo vit dans `packages/zcrud_study/test/support/suf4_assembly_demo.dart`,
  exercée par `packages/zcrud_study/test/suf4_assembly_demo_test.dart`.

**Aucune contrainte existante n'a été dégradée** : `example/pubspec.yaml` et
`example/test/boundary_deps_test.dart` sont **inchangés** ; aucun `pubspec.yaml` n'a bougé ; le graphe
reste **ACYCLIQUE, CORE OUT = 0, 69 arêtes**.

### 5.3 Ce que la démo assemble (surfaces **publiques** seules + fakes app-side)

`grille ZFolderCard (ZAdaptiveGrid) → ZStudyFolderDetail → ZSessionModeSelector →
ZSessionProgressIndicator(linear) + ZSrsQualityButtons(emphasis) → ZSessionSummaryView(wholeScale)`.

Elle **exerce les trois fermetures SUF-4** en conditions réelles, et injecte le `6` dp de lex **côté
app** — démontrant que la fermeture rend l'apparence lex atteignable **sans** que le widget la connaisse.

> 🔴 **Défaut MESURÉ dans la démo** (attrapé par sa propre garde de thème, AC8) : le `ZcrudScope` était
> placé **sous** le `MaterialApp`, donc **sous** le `Navigator` — les écrans **poussés** (détail,
> session) ne voyaient pas l'`InheritedWidget` et retombaient silencieusement sur les tokens par défaut
> (`gapM` 24 injecté → 8 rendu). Un thème d'app qui s'arrête au premier écran est le pire des mondes :
> il *a l'air* branché. Corrigé — le scope est désormais **ancêtre** du `MaterialApp`.

---

## 6. Récapitulatif des livrables

| Fermeture | Fichier | Surface publique ajoutée | Défaut |
|---|---|---|---|
| Paire 4 | `z_session_progress_indicator.dart` | `ZSessionProgressStyle.linear`, `linearThickness`, `linearKey`, `position`, `resolvedLinearValue`, `resolvedLinearThickness` | `dots` — **inchangé** |
| Paire 1 | `z_srs_quality_buttons.dart` | `ZSrsQualityEmphasis` (+ `emphasis:`) | `none` — rendu **inchangé** |
| Paire 2 | `z_session_quality_breakdown.dart`, `z_session_summary_view.dart` | `ZQualityBreakdownCoverage` (+ `coverage:`, `breakdownCoverage:`) | `presentKeysOnly` — **inchangé** |

Gardes R3 : `packages/zcrud_session/test/presentation/suf4_parity_closures_test.dart` (14 tests) et
`packages/zcrud_study/test/suf4_assembly_demo_test.dart` (7 tests). **13 régressions ré-injectées, 13
rouges observés** — détail dans les Completion Notes de la story SUF-4.
