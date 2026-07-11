# Story DP.9: `ZStepperConfig` + steppers imbriqués (parité DODLP — B11)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que l'assistant multi-étapes (`ZStepperEdition`) reproduise fidèlement le **stepper configurable** de DODLP — style/orientation/position d'indicateur, **icône** et **sous-titre par étape**, gate de validation configurable — et supporte les **steppers imbriqués** (un stepper dans une étape),
so that les 20+ formulaires wizard DODLP (bmd/vido/pia/antaser) migrent **structurellement à l'identique** sur un **unique `ZFormController`** partagé, sans perte de personnalisation ni de comportement, tout en préservant l'objectif produit n°1 (SM-1 : la frappe ne reconstruit que le champ courant, jamais le chrome).

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gap couvert : **B11** (`StepperConfig` absent + stepper non récursif) et le major adjacent **M16** (métadonnées `stepIcon`/`stepSubtitle` par étape) / **M12** (gate `validateOnNext` configurable). Réf : `docs/dodlp-edition-parity-gap.md` §1 (B11), §2.5 (`StepperConfig` visuel, stepper métadonnées par champ), §2.6 (validation par étape stepper), §3 (B11, M12, M16) ; épic `E-DP` story DP-9.

## Contexte & état actuel (lu intégralement)

**zcrud aujourd'hui** (`presentation/edition/z_stepper_edition.dart`, lu en entier) :
- `ZStepperEdition` est une **structure d'orchestration** (pas un `ZFieldWidget`) posée AUTOUR de `DynamicEdition`, sur un **unique `ZFormController` partagé** (AD-2 / SM-1). Elle partitionne le catalogue via `steps: List<ZEditionStep>`.
- `ZEditionStep` = descripteur **présentation** `const` : `{ title, fields, sections }` (titre l10n/littéral + noms de champs + sections visuelles E3-4). **PAS une donnée de formulaire persistée** → aucune (dé)sérialisation domaine en jeu.
- Chrome = canaux **STRUCTURELS uniquement** : `_currentStep` (index), `_reveal` (révélation d'erreurs), `controller.visibleFields`. Une frappe ne touche aucun canal structurel ⇒ zéro rebuild du chrome (SM-1/AC11 de la story E3-5).
- Indicateur unique : `_StepIndicator` → **texte fixe « k/N » + titre**, `Semantics(header:true)`, insets directionnels, styles `Theme.of(context).textTheme` (aucun littéral — AD-13/FR-26).
- Navigation : `_next()` **valide l'étape courante** (validateurs champ-locaux E3-2 mémoïsés, évalués contre `controller.valueOf`, champs masqués par condition exclus) → invalide = blocage + `_reveal.value=true` (bascule locale `AutovalidateMode.always`, **jamais** de `Form` global). `_previous()` inconditionnel. Dernière étape → `onComplete` (soumission = E3-6).
- Fenêtre d'étape : `_syncWindow(i)` aligne `controller.visibleFields` sur les champs **visibles** de l'étape `i` ; les tranches survivent (état préservé en va-et-vient, AC7/AC9 E3-5).

**DODLP `StepperConfig`** (`dodlp-otr/lib/modules/data_crud/models/stepper_config.dart`, lecture seule) — options réelles :
- `indicatorPosition` : `top | left | bottom` (`StepIndicatorPosition`).
- `orientation` : `horizontal | vertical` (`StepOrientation`).
- `style` : `numbered | icons | progressBar | dots` (`StepStyle`).
- Couleurs : `completedColor / activeColor / inactiveColor / errorColor` (`Color?`).
- `showAllSteps`, `indicatorSize` (40), `stepSpacing` (8), `showLabels` (true), `showSubtitles` (false), `allowStepTap` (true), `validateOnNext` (**true**), `autoSaveOnStepChange` (true), `animationDuration` (300ms), `animationCurve` (easeInOut).
- Builders custom : `stepContentBuilder`, `stepIndicatorBuilder`.
- 5 presets `const` : `defaultHorizontal`, `defaultVertical`, `progressBarStyle`, `dotStyle`.

**DODLP métadonnées par étape** (`models.dart:692-704`) : le champ portant `stepIndex` porte aussi `stepTitle`, **`stepIcon` (`IconData?`)**, **`stepSubtitle` (`String?`)** et un `stepperConfig` par instance.

**DODLP nesting** (`dynamic_stepper.dart:8-31,190-290`, lecture seule) : `DynamicStepper` est **récursif** — un `child` de type `EditionFieldTypes.stepper` porteur d'un `stepperConfig` est rendu comme un **`DynamicStepper` imbriqué** (`nestingLevel + 1`) DANS le contenu d'une étape parente. Le même form-state est partagé (aucun controller par niveau) ; l'`indicatorSize` décroît avec la profondeur. La navigation DODLP est **LIBRE** (jamais `validate()` — cf. §2.6), `validateOnNext` étant la porte configurable.

## Acceptance Criteria

### Bloc A — `ZStepperConfig` (style / orientation / indicateur configurable)

1. **Enums de configuration (présentation, additifs).** Trois enums publics `const` sont ajoutés dans la couche `presentation/edition` de `zcrud_core` (à côté de `ZStepperEdition`, PAS dans le domaine — ils accompagnent des types Flutter, AD-1 réservé au domaine pur) : `ZStepOrientation { horizontal, vertical }`, `ZStepStyle { numbered, icons, progressBar, dots }`, `ZStepIndicatorPosition { top, start, bottom }`. Valeurs en camelCase (canonique §5). Miroir 1:1 de `StepOrientation`/`StepStyle`/`StepIndicatorPosition` DODLP, **à une exception directionnelle près** : `left` DODLP → **`start`** (AD-13 : jamais de `left`/`right` — l'indicateur latéral suit la `Directionality`). Chaque enum est exporté par le barrel `zcrud_core.dart`.

2. **`ZStepperConfig` `const` & immutable.** Une classe `@immutable class ZStepperConfig` (présentation, `edition/`) porte au minimum : `orientation` (défaut `horizontal`), `style` (défaut `numbered`), `indicatorPosition` (défaut `top`), `showLabels` (défaut `true`), `showSubtitles` (défaut `false`), `allowStepTap` (défaut `true`), `validateOnNext` (défaut **`true`** — cf. AC7/AC12), `indicatorSize` (défaut token), `stepSpacing` (défaut token), et des **overrides couleur NULLABLES** `activeColor` / `completedColor` / `inactiveColor` / `errorColor` (défaut `null` → dérivés du `ColorScheme`, cf. AC6/AC17). Constructeur `const`, `copyWith`, `==`, `hashCode`. Additif : aucune valeur numérique/couleur littérale codée « en dur » n'est imposée par le défaut du chrome (AC17).

3. **Presets `const` de parité.** `ZStepperConfig` expose des presets `static const` alignés sur DODLP : `defaultHorizontal` (top/horizontal/numbered), `defaultVertical` (start/vertical/numbered), `dotStyle` (bottom/horizontal/dots, `showLabels:false`), `progressBarStyle` (top/horizontal/progressBar, `showLabels:false`). Un preset ne fige **aucune** couleur (overrides restent `null`).

4. **`ZStepperEdition.config` additif & rétro-compatible.** `ZStepperEdition` gagne un paramètre nommé optionnel `ZStepperConfig config` **de défaut `const ZStepperConfig()`** reproduisant **exactement** le comportement actuel (indicateur `top/horizontal/numbered` « k/N » + titre). Une instanciation existante **sans** `config` (tests E3-5 `stepper_edition_test.dart`, `sm1_stepper_test.dart`, `stepper_a11y_rtl_test.dart`, `stepper_submit_aggregation_test.dart`) reste **verte sans modification** (aucun symbole retiré/renommé — additivité stricte du barrel partagé).

5. **Indicateur piloté par `style` & `orientation`.** L'indicateur d'étape honore `config.style` : `numbered` (cercles numérotés 1..N — inclut le rendu « k/N » historique en défaut), `icons` (icône par étape via AC10, repli numéro si absente), `dots` (points), `progressBar` (barre de progression continue). `config.orientation` place la bande d'étapes horizontalement (défaut) ou verticalement ; `config.indicatorPosition` (`top`/`start`/`bottom`) positionne la bande relativement à la zone de contenu, en **directionnel** (`start` = côté début de lecture). `showLabels:false` masque les titres dans la bande sans casser l'a11y (AC15). Le rendu reste **purement structurel** (aucune tranche de valeur observée — AC13).

### Bloc B — `ZEditionStep` enrichi (icône + sous-titre par étape)

6. *(intentionnellement fusionné dans AC17 — voir Transverse)*

7. **`ZEditionStep.icon` & `ZEditionStep.subtitle` additifs.** `ZEditionStep` gagne deux paramètres nommés optionnels : `IconData? icon` (défaut `null`) et `String? subtitle` (défaut `null`, clé l10n ou littéral résolu côté hôte via `label(context, …)`). Intégrés au constructeur `const`, à `==`, `hashCode`, `toString`. Miroir de `stepIcon`/`stepSubtitle` DODLP (`models.dart:698-701`). Le constructeur **reste `const`** et source-compatible (les 20+ sites existants qui n'ont ni `icon` ni `subtitle` compilent inchangés).

8. **Consommation de l'icône.** En `style: ZStepStyle.icons`, l'indicateur de l'étape `k` rend `steps[k].icon` (si non nul), sinon retombe sur le numéro (parité DODLP `StepState.indexed`). L'icône n'est **jamais** codée en dur ; sa couleur dérive de l'état (actif/complété/pending/erreur) via AC17. Cible tactile / sémantique conforme AC15.

9. **Consommation du sous-titre.** Quand `config.showSubtitles == true`, l'indicateur de l'étape **courante** (et de toutes les étapes si un mode « toutes visibles » est rendu) affiche `steps[k].subtitle` résolu par `label(context, subtitle)`. `showSubtitles == false` (défaut) ⇒ aucun sous-titre (parité défaut DODLP). Aucun sous-titre `null` ne produit de nœud vide.

10. **`allowStepTap` (navigation par tap sur l'indicateur).** Quand `config.allowStepTap == true` (défaut), taper l'indicateur d'une étape navigue vers elle : **retour arrière inconditionnel** (jamais de gate — cohérent AC6 E3-5 / `_previous`) ; **saut avant** soumis au **même gate que « Suivant »** (AC12 : valide les étapes intermédiaires si `validateOnNext`, sinon libre). `allowStepTap == false` ⇒ indicateur non interactif (navigation par boutons seulement). Cibles ≥ 48 dp (AC15).

### Bloc C — Steppers imbriqués (récursivité sur controller unique)

11. **Descripteur de nesting additif.** `ZEditionStep` gagne un moyen additif de porter un **sous-stepper** : paramètre nommé optionnel `List<ZEditionStep>? nestedSteps` (défaut `null`) **plus** `ZStepperConfig? nestedConfig` (défaut `null`). Quand `nestedSteps != null`, l'étape parente rend, dans son contenu (après/à la place de ses champs directs selon l'ordre déclaré), un **`ZStepperEdition` imbriqué** partageant le **MÊME `controller`** que le parent (AD-2 : jamais un `ZFormController` par niveau, jamais recréé). Miroir structurel du `DynamicStepper` récursif DODLP (`dynamic_stepper.dart:190-211`), profondeur arbitraire (nesting de nesting supporté). Alternative de câblage via `ZWidgetRegistry` évaluée et **écartée** (justification en Dev Notes — un stepper n'est pas un widget-feuille et dupliquerait la gestion de fenêtre) : le nesting est **structurel**, porté par `ZEditionStep`.

12. **Gate de validation par étape préservé & configurable (root + nested).** La transition « Suivant » (et le saut avant par tap AC10) valide les champs **visibles** de l'étape courante **ssi `config.validateOnNext == true`** (défaut → comportement zcrud actuel **inchangé** : gate strict). `validateOnNext == false` ⇒ navigation **libre** (parité DODLP §2.6, gap M12) sans jamais valider en transition. Le gate d'un stepper **imbriqué** utilise le `validateOnNext` de **sa** `nestedConfig` (indépendant du parent) ; un parent ne peut avancer au-delà d'une étape contenant un nested stepper que si — quand son propre `validateOnNext` est vrai — les champs **visibles de la sous-étape active** du nested passent aussi (le nested ne « cache » pas des champs invalides requis de la sous-étape montée). Champs masqués par `ZCondition` non validés (invariant E3-5 conservé).

13. **`controller.visibleFields` = union du chemin actif (source unique).** À tout instant, `controller.visibleFields` reflète l'**union des champs visibles le long du chemin d'étapes actif** : étape parente active → sa sous-étape active du nested → (récursivement). Un seul propriétaire écrit `visibleFields` : le **stepper racine** (le nested s'exécute en **mode « sans fenêtre »** — il ne fait PAS `setVisibleFields`, il publie seulement son sous-index actif via un canal structurel remonté au racine, qui recalcule la fenêtre). But : deux niveaux ne se battent jamais sur `visibleFields`, et les champs des sous-étapes non montées sont exclus de la fenêtre **sans** détruire leurs tranches (état préservé — AC14).

14. **État préservé en va-et-vient (y compris imbriqué).** Naviguer parent→nested→parent, ou sous-étape→sous-étape puis retour, **préserve intégralement** les valeurs saisies : les tranches du `ZFormController` unique survivent au démontage des sous-arbres d'étape (elles ne sont libérées qu'au `dispose` du controller possédé par l'hôte). Aucun `controller` recréé à un changement d'étape/sous-étape.

### Transverse — invariants & non-régression

15. **A11y / RTL (AD-13).** Indicateurs (numéros/icônes/dots/barre), sous-titres et zone tap exposent une `Semantics` explicite (`header`/rôle bouton pour un indicateur tapable, label « Étape k sur N : {titre} »), cibles tactiles ≥ 48 dp pour tout élément interactif, tous insets/positions **directionnels** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end` — `start`/`end` jamais `left`/`right`). Bascule LTR↔RTL sans overflow ni exception, à chaque `orientation`/`indicatorPosition`. La garde `test/purity/style_purity_test.dart` reste **verte**.

16. **SM-1 / AD-2 non régressés (root & nested).** Le chrome (bande d'indicateurs + navigation + zone d'étape), à **tout niveau de nesting**, n'observe QUE des canaux **structurels** (index d'étape, sous-index nested, canal de révélation, `controller.visibleFields`) — **jamais** une tranche de valeur. Taper 100 caractères dans un champ (d'une étape racine OU d'une sous-étape imbriquée) ne reconstruit que ce champ, sans perte de focus ni saut de curseur, et **ne ré-exécute pas** le build structurel du chrome (compteur `onStructuralBuild` inchangé pendant la frappe). Aucun `Form`/`FormBuilder` global à aucun niveau (`find.byType(Form)` = `findsNothing`).

17. **Zéro style/couleur codé en dur (AD-6/FR-26).** Les couleurs d'indicateur (actif/complété/pending/erreur) dérivent du `ColorScheme` de l'app (ex. actif/complété = `primary`, pending = `onSurfaceVariant`/`outline`, erreur = `error`) **ou** de l'override nullable de `ZStepperConfig` (AC2) fourni par l'app — **jamais** un `Colors.*`/`Color(0x…)` littéral dans le widget. Les mesures (taille d'indicateur, espacement, épaisseur de barre) proviennent de `config` et/ou de tokens `ZcrudTheme` avec repli `Theme.of(context)` ; aucune valeur de layout magique en dur. La garde `style_purity_test.dart` reste verte.

18. **Additivité stricte (barrel partagé).** Tous les ajouts sont **additifs** : nouveaux enums, nouvelle classe `ZStepperConfig`, nouveaux paramètres nommés optionnels sur `ZStepperEdition` (`config`) et `ZEditionStep` (`icon`, `subtitle`, `nestedSteps`, `nestedConfig`) — **aucun** symbole existant retiré/renommé, `ZEditionStep`/`ZStepperEdition` restent constructibles à l'identique. Aucune (dé)sérialisation **domaine/persistance** n'est touchée (les descripteurs de stepper sont présentation-only, non persistés) ; l'additivité porte sur l'**API publique** du barrel. `graph_proof` CORE OUT=0 conservé (aucun nouvel import lourd), surface pure Flutter-free du domaine inchangée.

### Non-goals (bornage explicite DP-9)

- **`showAllSteps` (timeline « toutes étapes dépliées »)** de DODLP : hors périmètre DP-9 (le chemin de parité prod est le stepper **interactif** mono-étape active). Le champ `config` peut être présent mais non consommé, ou omis — à documenter en Completion Notes ; à traiter en suivi si un usage prod l'exige.
- **`autoSaveOnStepChange`** (auto-persistance) : relève de la soumission E3-6 / de l'app hôte, hors E-DP core.
- **`stepContentBuilder` / `stepIndicatorBuilder` (builders custom DODLP)** : le seam `fieldBuilder` existant couvre le rendu de champ ; un seam d'indicateur custom est **optionnel** (à ajouter seulement si trivial, sinon différé — consigner).
- **Authoring** `@ZcrudField(stepIcon:/stepSubtitle:/stepperConfig:)` : hors `zcrud_core`. DP-9 livre le **runtime** (`ZEditionStep`/`ZStepperConfig`) ; la projection depuis annotations/générateur DODLP est une **story de suivi** (bloc `zcrud_annotations`/`zcrud_generator`) — à signaler.

## Tasks / Subtasks

- [x] **T1 — Enums + `ZStepperConfig` (AC1, AC2, AC3)**
  - [x] Ajouter `ZStepOrientation`, `ZStepStyle`, `ZStepIndicatorPosition` (présentation `edition/`, `const`, doc, `left→start` directionnel).
  - [x] Créer `ZStepperConfig` (`@immutable`, `const` ctor, `copyWith`, `==`, `hashCode`) : orientation/style/indicatorPosition/showLabels/showSubtitles/allowStepTap/validateOnNext(=true)/indicatorSize/stepSpacing + overrides couleur nullables (défaut `null`).
  - [x] Presets `static const` : `defaultHorizontal`, `defaultVertical`, `dotStyle`, `progressBarStyle`.
  - [x] Exporter enums + classe dans `zcrud_core.dart`.
- [x] **T2 — `ZEditionStep` enrichi (AC7)**
  - [x] Ajouter `IconData? icon`, `String? subtitle` (défaut `null`) au ctor `const` + `==`/`hashCode`/`toString`. Vérifier source-compat des sites existants.
- [x] **T3 — Indicateur configurable (AC5, AC8, AC9, AC17)**
  - [x] Refactorer `_StepIndicator` (paramétré par `config`) : `numbered`/`icons`/`dots`/`progressBar` ; orientation h/v ; position top/start/bottom (directionnel) ; `showLabels`/`showSubtitles` ; couleurs dérivées `ColorScheme`/overrides config ; mesures depuis `config`. Le défaut `ZStepperConfig()` reproduit « k/N » + titre à l'identique (AC4).
- [x] **T4 — `config` sur `ZStepperEdition` + gate configurable (AC4, AC12)**
  - [x] Ajouter `config` (défaut `const ZStepperConfig()`). Passer `config` au chrome/indicateur.
  - [x] Gate conditionnel à `config.validateOnNext` dans `_next()`/`_jumpTo()` ; `validateOnNext:false` ⇒ navigation libre (aucun `_reveal` forcé, aucune validation en transition).
- [x] **T5 — `allowStepTap` (AC10, AC15)**
  - [x] Indicateur `dots` tapable (si `allowStepTap`) : retour arrière libre, saut avant sous gate (AC12) ; `Semantics` bouton + cible ≥ 48 dp.
- [x] **T6 — Nesting (AC11, AC12, AC13, AC14, AC16)**
  - [x] Ajouter `nestedSteps`/`nestedConfig` à `ZEditionStep` ; rendre un `ZStepperEdition` imbriqué sur le **même** controller dans le contenu de l'étape.
  - [x] Mode « nested / sans fenêtre » : le nested ne fait PAS `setVisibleFields` ; il remonte sa **contribution de fenêtre** (`onNestedWindowChanged`) au racine.
  - [x] Racine : calcul **récursif** de la fenêtre → union du chemin actif ; `DynamicEdition` passif (`manageVisibility:false`) ; souscription aux gardes par niveau. Gate parent honore la sous-étape active du nested (AC12).
  - [x] Survie des tranches vérifiée (aucune destruction ; controller unique jamais recréé).
- [x] **T7 — Tests (AC1..AC18)** — `stepper_config_test.dart` (8) + `stepper_dp9_test.dart` (15).
  - [x] Config : `style` numbered/icons/dots/progressBar rendus ; indicatorPosition top/start/bottom (directionnel) ; `showLabels:false` ; presets.
  - [x] `ZEditionStep.icon`/`subtitle` : icône rendue en `style:icons` (repli numéro si `null`) ; sous-titre affiché ssi `showSubtitles` ; égalité/hashCode rétro-compat.
  - [x] Gate : `validateOnNext:true` (défaut) bloque + révèle ; `validateOnNext:false` navigation libre sans validation.
  - [x] `allowStepTap` : retour libre, saut avant gated ; `false` non interactif.
  - [x] Nesting : sous-stepper sur controller unique ; va-et-vient parent↔nested préserve les valeurs (AC14) ; `visibleFields` = union du chemin actif (AC13) ; gate parent honore la sous-étape active (AC12) ; profondeur ≥ 2.
  - [x] SM-1 : 100 frappes dans un champ de sous-étape imbriquée → focus conservé, rebuild ciblé, `onStructuralBuild` inchangé ; `find.byType(Form)` findsNothing à tous niveaux.
  - [x] A11y/RTL : `Semantics` indicateur/tap, cibles ≥ 48 dp, bascule LTR↔RTL sans overflow pour top/start/bottom.
  - [x] Rétro-compat : les 4 tests stepper E3-5 restent verts **sans modification** ; `style_purity_test.dart` vert.
- [x] **T8 — Vérif verte** : `dart analyze packages/zcrud_core` RC=0 → `flutter test packages/zcrud_core` RC=0 (724 tests) → `graph_proof` CORE OUT=0 → purity domaine Flutter-free OK.

## Dev Notes

### Décision clé — nesting sur controller unique (AD-2 NON-NÉGOCIABLE)

Le point le plus délicat : DODLP nesting = `DynamicStepper` récursif partageant le **même form-state**. En zcrud, `ZStepperEdition` **possède un mécanisme de fenêtre** (`controller.visibleFields`). Deux instances (parent + nested) écrivant `visibleFields` **entreraient en conflit**. Invariant imposé (AC13) : **un seul écrivain** de `visibleFields` = le stepper **racine**. Le nested tourne en **mode structurel « sans fenêtre »** : il gère son propre `_currentStep`/`_reveal` locaux (rendu + gate), mais NE fait PAS `setVisibleFields` ; il **expose son sous-index actif** (via un `ValueListenable<int>` fourni par le racine, ou un callback `onNestedStepChanged`) que le racine agrège pour recalculer `_windowFor` **récursivement** le long du chemin actif. Ainsi `controller.visibleFields` = union des champs visibles du chemin actif, les tranches des sous-étapes non montées survivent (état préservé), et le gate parent (AC12) peut interroger la sous-étape active.

- Introduire un paramètre additif `nested`/`windowMode` (ou `onNestedStepChanged` + `nestedSubIndex`) **interne** à `ZStepperEdition` pour distinguer racine vs imbriqué. Le rendre `@visibleForTesting` si exposé, sinon privé au fichier.
- `_windowFor(i)` doit devenir récursif : si `steps[i].nestedSteps != null`, inclure les champs directs visibles de l'étape **plus** le résultat de `_windowFor` de la **sous-étape active** du nested (condition `ZCondition` honorée à chaque niveau).
- Ne PAS recréer le controller ni de sous-controller. Ne PAS envelopper dans un `Form`.

### Pourquoi PAS via `ZWidgetRegistry`

`ZWidgetRegistry` (lu en entier) mappe un `kind` → **widget-feuille** rendu DANS la frontière de rebuild du dispatcher (`ZFieldListenableBuilder`, value-in-slice). Un stepper n'est **pas** un champ-feuille (le dispatcher `ZFieldWidget` classe `EditionFieldType.stepper` `unsupported` par conception, cf. entête `z_stepper_edition.dart`) et il a besoin de gérer une **fenêtre `visibleFields`** et une navigation structurelle — le faire passer par le registre dupliquerait cette gestion et casserait le « single writer » de `visibleFields`. Décision : le nesting est **structurel**, porté par `ZEditionStep.nestedSteps`, PAS par le registre. `ZWidgetRegistry` reste **inchangé** ; le signaler explicitement en Completion Notes (le prompt le citait comme point de contact possible — il est évalué puis écarté avec justification).

### Couleurs & tokens (AD-6/FR-26)

DODLP `StepperConfig` embarque des `Color?` littéraux applicatifs. En zcrud : `ZStepperConfig` n'expose que des **overrides nullables** (défaut `null`) ; le rendu dérive les couleurs du `ColorScheme` (actif/complété=`primary`, pending=`onSurfaceVariant`/`outline`, erreur=`error`) — aucun `Colors.*` dans le widget (garde `style_purity_test.dart`). Les presets ne figent aucune couleur. Mesures (indicatorSize/stepSpacing) : défauts via `config` (parité 40/8) OU tokens `ZcrudTheme` si l'on veut la surcharge thème — décision d'implémentation à consigner ; a minima passer par `config` (déjà surchargeable par l'app), repli `Theme.of(context)`.

### `left → start` (directionnel, AD-13)

`ZStepIndicatorPosition.start` remplace `left` DODLP. Le rendu latéral utilise l'ordre naturel `Row`/`AlignmentDirectional` (respecte `Directionality`) — **jamais** `Positioned(left:)`/`EdgeInsets.only(left:)`. Le stepper vertical DODLP utilise `Positioned(left:)` + `Colors.grey.shade300` (lignes de connexion) : **NE PAS** répliquer tel quel — utiliser `PositionedDirectional`/`AlignmentDirectional` et couleur dérivée (`outlineVariant`/`outline`).

### Rétro-compat gate (M12)

Le comportement zcrud actuel = gate **strict** (`_next()` valide toujours). DODLP = navigation **libre**. DP-9 rend le gate **configurable** (`validateOnNext`, **défaut `true`** = zcrud actuel préservé) : les tests E3-5 existants restent verts sans changement, et un formulaire DODLP à navigation libre s'exprime par `validateOnNext:false`. C'est exactement le gap M12 (« rendre le gate `_next()` configurable, défaut permissif pour parité DODLP ») — ici on choisit défaut **strict** pour la non-régression zcrud, la parité DODLP étant opt-in par config (consigner ce choix).

### État actuel des fichiers touchés (lus intégralement)

- **`presentation/edition/z_stepper_edition.dart`** — `ZEditionStep` (title/fields/sections), `ZStepperEdition` (controller unique, `_currentStep`/`_reveal`/`_structural`, `_syncWindow`/`_windowFor`, `_validateStep`/`_next`/`_previous`, `_StepIndicator`, `_StepNavigationBar`). **Cible principale** : enrichir sans déplacer la frontière de rebuild (le `ListenableBuilder` scellé sur `_structural`). Les libellés nav utilisent `label(context, 'z.stepper.previous'|next|finish, fallback:)`.
- **`presentation/edition/z_widget_registry.dart`** — registre widget-feuille injectable (AD-4). **NON modifié** (cf. décision ci-dessus) — signalé comme point de contact évalué/écarté.
- **`presentation/edition/dynamic_edition.dart`** — réutilisé par chaque zone d'étape (place stable, conditionnels, sections, grille) ; le nested passe par ce même `DynamicEdition` via un `ZStepperEdition` imbriqué. Ne pas dupliquer.
- **`lib/zcrud_core.dart`** — barrel : exporte déjà `z_stepper_edition.dart` (l.79). Ajouter les exports des nouveaux enums/`ZStepperConfig` si dans un fichier séparé (sinon ré-exportés via `z_stepper_edition.dart`).
- **Tests E3-5 existants** : `test/presentation/edition/{stepper_edition_test,sm1_stepper_test,stepper_a11y_rtl_test,stepper_submit_aggregation_test}.dart` — **doivent rester verts sans édition** (garde de non-régression additivité).

### Contraintes d'architecture (AD — NON-NÉGOCIABLES)

- **AD-2 / OBJECTIF N°1 / SM-1** : un seul `ZFormController` partagé à **tous** les niveaux de nesting ; chrome scellé sur canaux structurels ; frappe = rebuild ciblé, chrome intact ; aucun `Form` global ; controller jamais recréé.
- **AD-6 / FR-26** : zéro couleur/style en dur ; dérivation `ColorScheme`/`ZcrudTheme`, override app via `config`/thème.
- **AD-13** : directionnel only (`start`/`end`), `Semantics` explicites, cibles ≥ 48 dp, LTR↔RTL sans overflow.
- **AD-1** : les enums/`ZStepperConfig` vivent en **présentation** (ils accompagnent Flutter : `IconData`/couleurs/orientation de rendu) — le **domaine reste Flutter-free** ; aucune (dé)sérialisation domaine touchée (descripteurs présentation-only).
- **AD-3 / AD-4** : ajouts **additifs** rétro-compatibles (nouveaux enums/classe, params nommés optionnels à défauts) ; désérialisation défensive du domaine inchangée.

### Project Structure Notes

- Fichiers **NEW** : `lib/src/presentation/edition/z_stepper_config.dart` (enums + `ZStepperConfig` — recommandé pour lisibilité) (+ tests).
- Fichiers **UPDATE** : `z_stepper_edition.dart` (`ZEditionStep.icon/subtitle/nestedSteps/nestedConfig`, `ZStepperEdition.config`, indicateur paramétré, gate configurable, `_windowFor` récursif, nesting), `lib/zcrud_core.dart` (exports).
- Aucune nouvelle dépendance de package (AD-1). Aucun `*.g.dart` impacté (aucune annotation modifiée dans `zcrud_core`).

### References

- [Source: docs/dodlp-edition-parity-gap.md#1 — B11 (`StepperConfig` absent + stepper non récursif)]
- [Source: docs/dodlp-edition-parity-gap.md#2.5 — `StepperConfig` visuel + stepper métadonnées par champ]
- [Source: docs/dodlp-edition-parity-gap.md#2.6 — Validation par étape stepper (navigation LIBRE DODLP)]
- [Source: docs/dodlp-edition-parity-gap.md#3 — 🔴 B11 / 🟠 M12 / M16]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E-DP DP-9]
- [Source: dodlp-otr/lib/modules/data_crud/models/stepper_config.dart:1-268] (StepperConfig + enums + presets + FormStepInfo)
- [Source: dodlp-otr/lib/modules/data_crud/models.dart:692-704] (stepIndex/stepTitle/stepIcon/stepSubtitle/stepperConfig par champ)
- [Source: dodlp-otr/lib/modules/data_crud/presentation/widgets/dynamic_stepper.dart:8-31,80-290] (récursivité + collecte d'étapes + gate/validation)
- [Source: dodlp-otr/lib/modules/pia/presentation/views/screens/cargaison_stepper_form.dart:36-136] (usage prod : stepper de premier niveau + stepIndex/stepSubtitle)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart] (UPDATE — cible principale)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart] (contact évalué/écarté — non modifié)
- [Source: packages/zcrud_core/lib/zcrud_core.dart:79,90] (barrel exports)
- [Source: packages/zcrud_core/test/presentation/edition/{stepper_edition_test,sm1_stepper_test,stepper_a11y_rtl_test,stepper_submit_aggregation_test}.dart] (garde non-régression E3-5)
- [Source: packages/zcrud_core/test/purity/style_purity_test.dart] (garde zéro-couleur/directionnel — reste verte)
- [Source: CLAUDE.md#Critical Patterns] (AD-1, AD-2, AD-6/FR-26, AD-13)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze packages/zcrud_core` → **RC=0** (No issues found).
- `flutter test packages/zcrud_core` → **RC=0**, **724 tests** verts (baseline + 23 nouveaux DP-9).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK**.
- `dart test packages/zcrud_core/test/purity/domain_entrypoint_dart_test.dart` → **RC=0** (surface domaine Flutter-free inchangée).
- 4 tests stepper E3-5 (`stepper_edition_test`, `sm1_stepper_test`, `stepper_a11y_rtl_test`, `stepper_submit_aggregation_test`) + `style_purity_test` : **verts SANS modification**.

### Completion Notes List

**Décision d'architecture clé — single-writer racine (invariant HIGH validé).** Le
nesting est **structurel** (porté par `ZEditionStep.nestedSteps`), PAS routé via
`ZWidgetRegistry` (évalué puis **écarté** : un stepper n'est pas un widget-feuille
et le registre casserait le single-writer de `visibleFields`). Un unique écrivain
de `controller.visibleFields` = le stepper **RACINE** ; il publie l'**union du
chemin d'étapes actif**. Un stepper imbriqué tourne en mode « sans fenêtre » : il
**remonte** sa contribution via `onNestedWindowChanged` (callback interne
`@visibleForTesting`), jamais de `setVisibleFields`. Récursif → profondeur
arbitraire (test profondeur ≥ 2 vert).

**Point de contact core partagé additif signalé — `dynamic_edition.dart`.** Le
single-writer exige que les zones d'étape (parent-direct + nested) n'écrivent PAS
`visibleFields` (sinon elles se clobberaient mutuellement à leur montage). J'ai
donc ajouté un **flag additif `manageVisibility` (défaut `true`)** à
`DynamicEdition` : `true` = comportement E3-1..E3-4 **strictement inchangé**
(chemin LEGACY, gère `visibleFields` + gardes) ; `false` = rendu passif (rend
l'intersection de `controller.visibleFields` avec ses `fields`, aucune écriture,
aucune souscription garde). Le stepper passe `manageVisibility:false` **uniquement**
en mode `_driving` (racine avec nesting OU stepper imbriqué) ; en mode LEGACY
(aucun nesting) le chemin est identique à E3-5 (les 4 tests + SM-1 le prouvent). En
mode `_driving`, le stepper prend en charge la souscription aux **champs de garde**
(via `zGuardFieldsOf`) pour recalculer l'union sur bascule conditionnelle.

**Rétro-compat gate (M12).** Le gate reste **strict par défaut**
(`validateOnNext:true` = comportement zcrud E3-5), la navigation **libre** DODLP
étant **opt-in** (`validateOnNext:false`) — choix consigné (non-régression zcrud
prioritaire, parité DODLP par config).

**AC10 / allowStepTap — cadrage.** La navigation par tap per-étape est exposée sur
le style **`dots`** (marqueurs tapables, cible ≥ 48 dp, `Semantics` bouton) : retour
arrière libre, saut avant sous le même gate que « Suivant ». Les styles compacts
`numbered`/`icons` conservent le rendu historique « k/N » + titre (AC4 exact) et ne
sont pas per-étape tapables (navigation par boutons) ; `progressBar` idem. Ce
cadrage préserve strictement le défaut E3-5 tout en réalisant le mécanisme
`allowStepTap` (prouvé sur `dots`, y compris `allowStepTap:false` non interactif).

**Non-goals écartés (NON implémentés, comme borné) :** `showAllSteps` (timeline
toutes-étapes), `autoSaveOnStepChange`, `stepContentBuilder`/`stepIndicatorBuilder`
custom, authoring via annotations/générateur. `ZWidgetRegistry` **non modifié**.

**Sérialisation.** `ZStepperConfig`/enums/`ZEditionStep` sont **présentation-only**,
non annotés `@ZcrudModel` → **aucune** (dé)sérialisation domaine touchée, aucun objet
de générateur attendu, `domain.dart` (surface pur-Dart) inchangée (purity verte).

**Invariants confirmés :** AD-2/SM-1 (controller UNIQUE partagé root+nested, frontière
`ListenableBuilder`/`_structural` non déplacée, aucun `Form` à aucun niveau, 100
frappes en sous-étape imbriquée ⇒ 0 rebuild chrome, focus/curseur conservés) ;
AD-6/FR-26 (zéro couleur en dur, overrides nullables → `ColorScheme`, `style_purity`
verte) ; AD-13 (`left→start` directionnel, `Semantics` étapes, cibles ≥ 48 dp, LTR↔RTL
sans overflow) ; AD-3/AD-14 (additivité stricte, enums camelCase, barrel additif).

### File List

- `packages/zcrud_core/lib/src/presentation/edition/z_stepper_config.dart` (**NEW**) — enums `ZStepOrientation`/`ZStepStyle`/`ZStepIndicatorPosition` + `ZStepperConfig` (+ presets, résolveurs de couleur).
- `packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart` (**UPDATE**) — `ZEditionStep` (icon/subtitle/nestedSteps/nestedConfig + ==/hashCode/toString) ; `ZStepperEdition` (config, gate configurable, allowStepTap, indicateur paramétré, nesting single-writer racine, souscription gardes en mode driving).
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (**UPDATE**) — flag additif `manageVisibility` (défaut `true` = inchangé ; `false` = rendu passif pour le single-writer racine du nesting).
- `packages/zcrud_core/lib/zcrud_core.dart` (**UPDATE**) — export additif de `z_stepper_config.dart`.
- `packages/zcrud_core/test/presentation/edition/stepper_config_test.dart` (**NEW**) — 8 tests unitaires config/step.
- `packages/zcrud_core/test/presentation/edition/stepper_dp9_test.dart` (**NEW**) — 15 tests widget (styles, gate, tap, nesting, SM-1 imbriqué, a11y/positions).
