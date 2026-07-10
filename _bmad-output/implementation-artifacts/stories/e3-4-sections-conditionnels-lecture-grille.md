---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---

# Story 3.4 : Sections repliables, champs conditionnels, mode lecture, grille responsive

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

Story ID : E3-4 · Epic : E3 (Moteur DynamicEdition à rebuilds granulaires) · Phase : MVP
Couvre : **FR-3** · AD-2, AD-13 · SM-1 · Dépend de : E3-1, E3-2, E3-3a, E3-3b(-1/-2/-3) — précède E3-5 (stepper) et E3-6 (soumission).

## Story

En tant que **développeur consommateur de zcrud** (DODLP puis lex_douane),
je veux pouvoir **structurer un formulaire en sections repliables, révéler/masquer des champs par condition déclarative, l'afficher en lecture seule, et disposer les champs sur une grille responsive 12 colonnes**,
afin de **reproduire par conception les formulaires riches historiques SANS jamais réintroduire le rebuild global ni la perte de focus (objectif produit n°1)**.

## Acceptance Criteria

Les ACs sont **testables** (widget / layout / golden à largeurs fixées / a11y / RTL). Chaque AC cite sa source.

### A. Champs conditionnels — `displayCondition` évalué par sélecteur dérivé, place stable (AD-2, FR-3)

1. **AC1 — Évaluateur pur de `ZCondition`.** Une fonction pure `bool evaluate(ZCondition, Object? Function(String field) valueOf)` évalue toutes les variantes de `ZConditionOp` (`equals`, `notEquals`, `isNull`, `notNull`, `truthy`, `and`, `or`, `not`), y compris combinateurs imbriqués. Testable unitairement, **pur-Dart**, sans Flutter. `truthy` = non nul / non vide (String/Iterable/Map) / non `false` / non `0`. [Source: z_condition.dart ; FR-3]
2. **AC2 — Apparition/disparition pilotée par la valeur d'un autre champ.** Un champ B porteur d'une `condition` référençant le champ A **apparaît** quand la condition devient vraie et **disparaît** quand elle devient fausse, en réaction à un `setValue('A', …)`. La visibilité effective de B est reflétée dans `controller.visibleFields` (canal structurel). [Source: architecture.md#AD-2 ; z_form_controller.dart ; epics E3-4]
3. **AC3 — Sélecteur dérivé = rebuild de la SEULE zone concernée, PAS de rebuild global de champ.** Un `setValue` sur un champ **référencé par au moins une condition** (« champ de garde ») ne peut reconstruire QUE : (a) le canal structurel (`visibleFields` / la liste montée par `DynamicEdition`) **si et seulement si** l'ensemble visible change ; (b) jamais la tranche d'un champ non concerné. Un `setValue` sur un champ **non référencé par aucune condition** (frappe ordinaire) **ne déclenche AUCUN** recalcul de visibilité ni rebuild structurel (SM-1 préservé). [Source: architecture.md#AD-2 ; z_condition.dart lignes 10-14 « seul un changement de visibilité reconstruit la LISTE »]
4. **AC4 — Idempotence / no-op sur visibilité inchangée.** Si un champ de garde change mais que l'ensemble visible résultant est **identique** (ex. `truthy` reste vrai), `setVisibleFields` est **no-op** (aucun `notifyListeners`, aucun rebuild structurel) — garanti par `listEquals` existant. [Source: z_form_controller.dart lignes 103-108]
5. **AC5 — Place stable + ORDRE canonique préservés (UJ-2).** Un champ conditionnel qui réapparaît reprend **sa position ordinale canonique** dans la liste des champs (jamais ajouté en fin), avec sa `ValueKey(field.name)` inchangée ⇒ réutilisation d'`Element`/`State`. Sa **valeur de tranche est préservée** pendant qu'il est masqué (le slice n'est pas détruit ; `valueOf` inchangé), donc à la réapparition la valeur précédemment saisie est toujours là. « Masqué = non rendu mais place réservée logiquement » (la place logique = l'index canonique). [Source: CLAUDE.md « place stable pour les champs conditionnels » ; architecture.md#AD-2 ; z_form_controller.dart lifecycle]
6. **AC6 — Focus non déplacé.** Taper dans un champ pendant qu'un champ conditionnel **ailleurs** apparaît/disparaît ne déplace pas le focus ni le curseur du champ en cours d'édition (réalise UJ-2 / PRD §climax lignes 58-59). [Source: prd.md lignes 58-59, 114]

### B. Sections repliables (AD-13 a11y)

7. **AC7 — En-tête repliable accessible.** Une section peut être **repliable** : son en-tête est actionnable (tap) et bascule l'état d'expansion. L'en-tête expose `Semantics(button: true, expanded: <bool>, label: <titre>)`, une **cible tactile ≥ 48 dp**, et des insets **directionnels** (`EdgeInsetsDirectional`) (AD-13). [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts directionnels]
8. **AC8 — Repli = masquage visuel SANS destruction d'état.** Replier une section n'affiche pas ses champs mais **ne détruit pas** leurs tranches (`valueOf` préservé) ; déplier ré-affiche les champs avec leur valeur. L'état d'expansion est **local à la présentation** (pas une donnée de formulaire) et **survit à un rebuild structurel** (changement de visibilité conditionnelle) — via un `State` keyé sur l'identité stable de la section. [Source: architecture.md#AD-2 ; z_form_controller.dart]
9. **AC9 — Repli n'entre pas en conflit avec la visibilité conditionnelle.** Le repli d'une section est **orthogonal** à `visibleFields` : replier une section ne modifie PAS `controller.visibleFields` (canal réservé à la logique conditionnelle) ; c'est la section qui décide du rendu de ses membres. Les deux dimensions se composent (un champ masqué par condition reste masqué même section dépliée ; une section repliée cache ses champs visibles). [Source: architecture.md#AD-2]

### C. Mode lecture (`readOnly` global + `showIfNull`) — FR-3

10. **AC10 — Mode lecture global propagé.** `DynamicEdition` accepte un drapeau `readOnly` global ; quand il est actif, **chaque** champ est rendu non éditable, en **présentation**, indépendamment du `ZFieldSpec.readOnly` par champ (le global **force** la lecture ; le per-champ reste respecté hors mode global). [Source: prd.md ligne 130 ; z_field_spec.dart lignes 78-82]
11. **AC11 — `showIfNull` masque les champs vides en lecture.** En mode lecture, un champ dont la valeur est **absente/vide** (`null`, `''`, liste/map vide) et dont `ZFieldSpec.showIfNull == false` **n'est pas affiché** ; si `showIfNull == true` (défaut) il reste affiché (en présentation). `showIfNull` **n'a aucun effet hors mode lecture** (édition = tous les champs visibles selon la condition). [Source: z_field_spec.dart lignes 46, 81-82 ; prd.md ligne 130]

### D. Grille responsive 12 colonnes (FR-3, AD-13)

12. **AC12 — Grille 12 colonnes, reflow par breakpoint.** Le formulaire peut disposer les champs sur une grille à **12 colonnes** ; un champ se voit attribuer un **`span` (1..12) par breakpoint** `xs/sm/md/lg/xl`. À une largeur donnée, un champ occupe le nombre de colonnes attendu et la ligne reflow (wrap) quand la somme des spans dépasse 12. Vérifiable par **test de layout / golden à largeurs fixées** (une largeur par breakpoint). [Source: prd.md ligne 131 ; epics E3-4]
13. **AC13 — Défaut = pleine largeur (12).** Un champ sans span déclaré occupe 12 colonnes (pleine largeur) à tous les breakpoints — compatibilité ascendante avec `DynamicEdition` sans layout. [Source: FR-3]
14. **AC14 — Grille directionnelle & accessible (AD-13).** Les gouttières/marges de la grille utilisent exclusivement `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional` — **aucun** `EdgeInsets.only(left/right)`, `fromLTRB`, `Alignment.centerLeft/Right`, `TextAlign.left/right`. Sous `Directionality.rtl`, l'ordre des colonnes suit le sens de lecture (test RTL sans overflow/exception, bascule LTR↔RTL). La garde `style_purity_test` / `field_rtl_test` reste **verte sans relâchement**. [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts ; code-review-e3-3a.md §2.3]

### E. Invariants transverses (repris des ACs précédents E3)

15. **AC15 — SM-1 re-prouvé au niveau formulaire.** Sur un formulaire de référence ≥ 30 champs / ≥ 3 sections **avec** au moins un champ conditionnel, une section repliable et une ligne de grille multi-colonnes : taper 100 caractères ne provoque **aucun rebuild hors du champ courant** (compteur `onStructuralBuild` inchangé pendant la saisie) et **zéro perte de focus**. [Source: prd.md ligne 378 (SM-1) ; dynamic_edition.dart lignes 99-103]
16. **AC16 — Aucun gestionnaire d'état, cœur pur.** Aucun import de `flutter_riverpod`/`get`/`provider` ; réactivité 100 % `Listenable`/`ValueListenable` ; `domain/` reste pur-Dart ; graphe `CORE OUT=0` inchangé ; **zéro `.g.dart`** committé ; vérif verte (`analyze` RC=0, `flutter test` RC=0). [Source: architecture.md#AD-15, AD-1 ; CLAUDE.md]

## Tasks / Subtasks

- [x] **T1 — Évaluateur pur de condition** (AC1)
  - [x] Créer `packages/zcrud_core/lib/src/presentation/edition/z_condition_evaluator.dart` (ou `domain/edition/` si strictement pur-Dart — préférer domaine car pur-données) : `bool evaluateZCondition(ZCondition, Object? Function(String) valueOf)`.
  - [x] Couvrir les 8 `ZConditionOp` + imbrication `and`/`or`/`not` ; définir la sémantique `truthy` (non nul / non vide / non `false` / non `0`).
  - [x] Tests unitaires exhaustifs (table de vérité par opérateur + imbrication).
- [x] **T2 — Sélecteur de visibilité dérivé (dependency-scoped)** (AC2, AC3, AC4, AC5, AC6)
  - [x] Extraire l'**ensemble des champs de garde** (union des `field` référencés par toutes les `condition` des specs) → `Set<String> guardFields`.
  - [x] Poser un binder de présentation (ex. `_ConditionalVisibilityBinder` interne à `DynamicEdition`, ou un mixin/`StatefulWidget` dédié) qui **s'abonne UNIQUEMENT** aux `fieldListenable(g)` des `guardFields` (jamais à tous les champs).
  - [x] À chaque changement d'un champ de garde : recalculer l'ensemble visible = **ordre canonique** des champs `fields` filtré par `evaluateZCondition` ; appeler `controller.setVisibleFields(next)` (no-op natif si inchangé — AC4).
  - [x] Garantir la **préservation de l'ordre ordinal** (réinsertion à l'index canonique — AC5) et **ne jamais détruire** les slices masqués.
  - [x] Amorçage : calculer la visibilité initiale au montage à partir des valeurs initiales du controller.
- [x] **T3 — Sections repliables** (AC7, AC8, AC9)
  - [x] Étendre `ZEditionSection` (ou ajouter `collapsible`/`initiallyExpanded`) SANS casser l'API existante (défaut = non repliable, rétro-compatible avec E3-1).
  - [x] En-tête repliable : `StatefulWidget` keyé sur `ValueKey('section:<title>')` (état d'expansion local, survit au rebuild structurel — AC8) ; `Semantics(button, expanded, label)` ; cible ≥ 48 dp ; `EdgeInsetsDirectional`.
  - [x] Rendu conditionnel des membres selon l'expansion, orthogonal à `visibleFields` (AC9) ; slices préservés au repli.
- [x] **T4 — Mode lecture global + showIfNull** (AC10, AC11)
  - [x] Ajouter `readOnly` (bool) à `DynamicEdition` ; propager au rendu des champs (overlay forçant la lecture par-dessus `ZFieldSpec.readOnly`).
  - [x] Décider le canal de propagation (voir « Décision d'intégration ») : le plus propre est un flag transmis au `fieldBuilder`/`ZFieldWidget` — vérifier que chaque famille respecte déjà `field.readOnly` (elles le font, cf. grep) et router le mode global via une spec effective (`spec.copyWith(readOnly: true)`) OU un paramètre widget.
  - [x] Filtrer les champs vides en lecture selon `showIfNull` **au niveau du calcul de la liste montée** (n'affecte que le rendu lecture, pas `visibleFields` structurel côté édition).
- [x] **T5 — Grille responsive 12 colonnes directionnelle** (AC12, AC13, AC14)
  - [x] Définir un descripteur de layout **présentation** (ex. `ZResponsiveSpan { xs, sm, md, lg, xl }`, défaut 12) + une map `Map<String, ZResponsiveSpan>` passée à `DynamicEdition` (ne PAS toucher au générateur / annotations — additif, domaine pur préservé).
  - [x] Widget grille (`ZResponsiveGrid` / `Wrap`+`LayoutBuilder` ou `Flow`) : résout le breakpoint courant via `LayoutBuilder`/`MediaQuery` width, calcule la largeur `span/12`, wrap au dépassement de 12. Gouttières `EdgeInsetsDirectional`.
  - [x] Intégrer dans `DynamicEdition` : chaque champ conserve sa `ValueKey(name)` (place stable NON contournable) même à l'intérieur d'une cellule de grille.
  - [x] Fixer les **seuils de breakpoint** (hypothèse : xs < 576, sm ≥ 576, md ≥ 768, lg ≥ 992, xl ≥ 1200 — style Bootstrap ; à confirmer, cf. Ambiguïtés).
- [x] **T6 — Formulaire de référence & preuve SM-1** (AC15, AC16)
  - [x] Monter un fixture ≥ 30 champs / ≥ 3 sections, ≥ 1 conditionnel, ≥ 1 section repliable, ≥ 1 ligne grille multi-span.
  - [x] Test : 100 frappes ⇒ `onStructuralBuild` non incrémenté ; focus préservé.
  - [x] Rejouer les gardes `style_purity_test` / `field_rtl_test` / graphe `CORE OUT=0` / scan `.g.dart`.
- [x] **T7 — Barrel & docs** : exporter les nouveaux types publics via `lib/zcrud_core.dart` (préfixe `Z`) ; documenter (dartdoc FR) les invariants AD-2/AD-13 sur chaque nouveau fichier.

## Dev Notes

### Architecture — invariants applicables (NON-NÉGOCIABLES)

- **AD-2 (objectif produit n°1)** — [architecture.md lignes 62-65] : réactivité Flutter-native ; `setValue` ne notifie QUE sa tranche ; `notifyListeners()` global réservé au canal **structurel** `visibleFields`. **Champs conditionnels via PLACE STABLE** — pas de reconstruction de l'arbre. La visibilité est **dérivée par sélecteur** (abonné aux seuls champs de garde), jamais par un `setState` global. Interdits repris : construction des champs dans une closure locale de `build()`, recréation de `TextEditingController`, ré-injection de valeur.
- **AD-13** — [architecture.md lignes 117-121] : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional` ; `Semantics` explicites ; cibles ≥ 48 dp. **La grille et les en-têtes de section sont des surfaces UI ⇒ intégralement directionnels et accessibles.**
- **AD-15 / AD-1** — cœur sans gestionnaire d'état ; `zcrud_core` out-degree contrôlé (`CORE OUT=0`) ; `domain/` pur-Dart (garde `domain_purity_test.dart`).
- **FR-3** — [prd.md lignes 125-131] : sections repliables + conditionnels + grille 12 colonnes reflow xs..xl + mode lecture `readOnly` avec `showIfNull`.
- **SM-1** — [prd.md ligne 378] : ≥ 30 champs / ≥ 3 sections, 100 caractères, zéro rebuild hors champ courant, zéro perte de focus.

### CLAUDE.md — Key Don'ts directement pertinents

- **Never** `setState` à l'échelle du formulaire · **Never** `ListView(children:[...])` → `ListView.builder` · **Never** insets/alignements non directionnels · **Never** style/couleur codé en dur (thème via `ZcrudScope`/`ThemeExtension`, repli `Theme.of`) · **Always** `const` widgets immuables, `Semantics` + cibles ≥ 48 dp · **Never** éditer/committer un `.g.dart`.

### Fichiers existants à RÉUTILISER (LIRE avant d'implémenter — ne pas réécrire)

- `presentation/edition/dynamic_edition.dart` — **point d'extension central de cette story.** Aujourd'hui : `build` observe UNIQUEMENT `controller.visibleFields` (`ValueListenableBuilder<List<String>>`), monte via `ListView.builder`, interleave des en-têtes de section **non repliables**, chaque champ enveloppé dans `KeyedSubtree(key: ValueKey(name))` par `_buildField` (garde L3/AC7 NON contournable). Sections/conditionnels/grille/lecture y sont explicitement annoncés « relèvent d'E3-4 » (lignes 17-23, 83, 89, 92). **À préserver** : le canal structurel unique, la place stable non contournable, `ListView.builder`, `onStructuralBuild`. **À étendre** : sections repliables, filtrage `showIfNull`, grille, propagation `readOnly`, binder de visibilité.
- `presentation/z_form_controller.dart` — `visibleFields` (canal structurel + `notifyListeners`), `setVisibleFields` (no-op sur `listEquals`), `fieldListenable`/`setValue`/`valueOf`, slices mémoïsés jamais détruits sauf `dispose`. **Réutiliser tel quel** ; le sélecteur de visibilité pilote `setVisibleFields`. Ne PAS ajouter de logique conditionnelle DANS le controller (il reste agnostique du schéma) — la dérivation vit en présentation.
- `domain/edition/z_condition.dart` — `ZCondition` + `ZConditionOp` (pur-données `const`). L'**évaluation** est à créer (T1). NE PAS mettre de closure dans la condition (interdit historique, cause du focus perdu — lignes 5-8).
- `domain/edition/z_field_spec.dart` — porte déjà `condition`, `readOnly`, `showIfNull`, `defaultValue`. Additif only.
- `presentation/edition/z_field_widget.dart` + `families/*` — chaque famille respecte déjà `field.readOnly` (grep confirmé : text/number/date/boolean/select/relation/slider/rating/tags/rowChips/color/subList/dynamicItem/signature). La propagation du **mode lecture global** doit réutiliser ce respect existant (spec effective `readOnly:true`), sans réécrire les familles.
- `presentation/edition/z_edition_field.dart` / `z_field_listenable_builder.dart` — hôte scellé sur la tranche + sync guardée hors focus (E3-2). Réutiliser.

### Décision d'intégration (à trancher par le dev dans le respect d'AD-2)

- **Propagation du mode lecture global** : deux options — (a) `DynamicEdition` recalcule une **spec effective** par champ (`spec.readOnly || globalReadOnly`) avant de la passer au rendu ; (b) un paramètre widget booléen traversant `ZFieldWidget`. **Recommandé (a)** : plus simple, réutilise le respect `field.readOnly` déjà présent dans toutes les familles, aucun changement de signature de widget. Vérifier l'existence d'un `copyWith` sur `ZFieldSpec` (sinon dériver localement).
- **Source des `span` de grille** : NE PAS étendre le générateur/annotations pour cette story. Poser un descripteur **présentation** (`ZResponsiveSpan` + map `name→span` en paramètre de `DynamicEdition`), défaut 12. Une éventuelle projection depuis `@ZcrudField`/`config` est **hors périmètre** (traçable pour une story ultérieure si un besoin d'authoring déclaratif émerge).
- **Binder de visibilité** : préférer un composant de présentation **abonné aux seuls champs de garde** (pas un `AnimatedBuilder` sur le controller entier, qui recalculerait à chaque `setValue`). L'abonnement ciblé est ce qui satisfait AC3 (frappe ordinaire ⇒ zéro recalcul).

### Décision — mécanisme UNIFORME de reflet de valeur EXTERNE (write-mostly)

**Contexte (finding récurrent).** Plusieurs widgets lisent leur valeur **une seule fois** au montage puis ignorent un `setValue` externe postérieur : signature (LOW-1 / LOW-3 de e3-3b-3), mini-CRUD sous-liste (LOW-1 de e3-3b-2), dropdown `select`/`relation` (L-3 de e3-3a). Asymétrie vs `date`/`boolean`/`select` qui relisent `value` à chaque build. Le risque se matérialise sur un **rechargement asynchrone d'enregistrement** ou un **reset de formulaire piloté par le parent**.

**Tranche pour E3-4 :** **poser ICI le CONTRAT uniforme (documenté) mais DIFFÉRER l'implémentation write-back à E3-6/E7.** Justification :
1. E3-4 introduit de l'**état dérivé en LECTURE** (sélecteur de visibilité, mode lecture, showIfNull) — ces surfaces **lisent `valueOf`/la tranche à chaque calcul** et **ne souffrent donc PAS** du problème write-mostly (elles n'ont pas de buffer interne). Le sélecteur de visibilité **reflète** nativement toute écriture externe d'un champ de garde (AC2/AC3 le prouvent).
2. Le problème write-back ne concerne QUE les widgets à **buffer d'édition interne** (texte/signature/sous-liste). **E3-4 n'ajoute aucun tel widget** ; poser un mécanisme de re-seed ici serait **spéculatif et non testable** dans le périmètre des ACs E3-4.
3. Le **déclencheur** réel (reset de formulaire / chargement tardif) est livré par **E3-6** (soumission/dirty/abandon → reset) et **E7** (intégration DODLP, chargement async d'un enregistrement). C'est là que le write-back devient **observable et testable**.

**Contrat uniforme documenté (à honorer par E3-6/E7, consigné ici pour cohérence) :** le reflet d'une valeur externe dans un widget à buffer interne se fait par **re-amorçage contrôlé par clé de révision** — `ValueKey(field.name + reseedRevision)` ou un « epoch » de re-seed exposé par le controller — appliqué **uniquement hors focus** (jamais un write-back en cours de geste/frappe, qui casserait FR-1/SM-1). Ce contrat unifie les LOW-1 de -2/-3 et le L-3 de -3a. **Statut : reporté et justifié (findings LOW, non bloquants).** À porter comme AC explicite dans E3-6/E7.

### Findings de code-review antérieurs à garder verts

- `style_purity_test` durci (L-2/L-3 de e3-3a, scan multi-lignes) : 0 inset/alignement non directionnel, 0 couleur codée en dur — **la grille et les en-têtes de section y sont soumis** (AC14).
- `field_rtl_test` : bascule LTR↔RTL sans overflow — **étendre au layout grille + sections repliables**.
- Garde de pureté `presentation/` (bannit `dart:ui` hors CustomPaint signature) et `domain_purity_test` — l'évaluateur de condition, s'il est placé en `domain/`, doit rester pur-Dart.

### Familles / rendu — rappel

Le rendu par famille est livré (E3-3a/b). Cette story n'ajoute **aucune** famille de champ : elle orchestre **structure** (sections, visibilité), **présentation** (lecture) et **layout** (grille) AUTOUR du dispatcher existant. Le champ reste keyé `ValueKey(name)` (place stable non contournable via `KeyedSubtree`).

### Ambiguïtés détectées (à trancher en dev, sans bloquer)

1. **Seuils de breakpoint xs/sm/md/lg/xl** — non spécifiés par FR-3 (qui exige seulement « reflow selon breakpoints, vérifiable par test à largeurs fixées »). Hypothèse retenue : Bootstrap-like (576/768/992/1200). À figer dans une constante documentée testée ; ajustable.
2. **Base de mesure de largeur** — `LayoutBuilder` (largeur du conteneur, recommandé pour l'imbrication) vs `MediaQuery` (largeur écran). Recommandé : `LayoutBuilder` (composable dans un scroll/split-view, cf. `shrinkWrap`/`physics` déjà exposés par `DynamicEdition`).
3. **`showIfNull` — définition de « vide »** : `null` seul, ou aussi `''` / `[]` / `{}` ? Retenu : `null` **et** collections/chaîne vides (cohérent avec `truthy`). À confirmer si un champ « faux booléen » doit compter comme vide (retenu : **non**, `false` reste une valeur affichable en lecture).
4. **Mode lecture par champ vs global** : le global **force** la lecture ; un champ déjà `readOnly:true` reste lu même hors mode global (comportement additif, sans surprise).
5. **Section repliable & grille** : une section repliable contient-elle une grille interne ou la grille est-elle globale au formulaire ? Retenu : la grille s'applique **par section** (chaque section = un contexte de layout 12 colonnes), le repli cache toute la grille de la section. À confirmer si un layout inter-sections est requis (peu probable).

### Frontière E3-4 / E3-5 / E3-6 (DÉCIDÉE)

- **E3-4 (cette story)** : sections **repliables** (accordéon dans une page unique), champs conditionnels (`displayCondition` place-stable), mode lecture (`readOnly` global + `showIfNull`), grille responsive 12 colonnes directionnelle. **Ne fait PAS** : navigation multi-étapes, soumission, dirty.
- **E3-5 (stepper)** : partitionne le **même** `ZFormController` en **étapes** (wizard), validation par étape (`form_builder_validators`), état préservé entre étapes — **distinct** des sections repliables (les sections d'E3-4 coexistent sur une page ; le stepper séquence des étapes). E3-4 **ne doit pas** implémenter de navigation d'étapes.
- **E3-6 (soumission)** : validation → `onSubmit`, détection **dirty** + confirmation d'abandon/reset, états UI (`submit-in-progress`, erreur via `AsyncValue.error`). **C'est là** que le **write-back de valeur externe** (reset/reload) devient observable → le **contrat uniforme** posé ci-dessus y est implémenté et testé. E3-4 **ne fait pas** de dirty ni de soumission.

### Project Structure Notes

- Nouveaux fichiers (présentation, `packages/zcrud_core/lib/src/`) : `presentation/edition/z_condition_evaluator.dart` (ou `domain/edition/` si pur-Dart — préférer domaine), `presentation/edition/z_responsive_grid.dart` (grille + `ZResponsiveSpan`), extension de `presentation/edition/dynamic_edition.dart` (sections repliables + readOnly global + showIfNull + binder de visibilité).
- Exports publics via barrel `lib/zcrud_core.dart` — types préfixés `Z` (`ZResponsiveSpan`, éventuel `ZFormLayout`).
- Tests : `packages/zcrud_core/test/presentation/edition/` (conditionnel, sections, lecture, grille, RTL, SM-1) + `test/domain/edition/z_condition_evaluator_test.dart` si domaine.
- **Aucune** modification du générateur/annotations ni des familles de champ. **Aucun** `.g.dart` à committer.

### Testing

Stratégie (widget + unit + layout/golden + a11y/RTL) :
- **Conditionnel** : (a) apparition/disparition de B au `setValue('A')` reflétée dans `visibleFields` (AC2) ; (b) **place stable** — B réapparaît à son index canonique, même `Element`/`State`, valeur préservée (AC5) ; (c) **pas de rebuild global** — frappe sur un champ non-garde ⇒ `onStructuralBuild` inchangé ; frappe sur un champ garde à visibilité inchangée ⇒ `onStructuralBuild` inchangé (AC3/AC4) ; (d) focus non déplacé pendant apparition ailleurs (AC6).
- **Évaluateur** : table de vérité unitaire par `ZConditionOp` + imbrication `and/or/not` (AC1).
- **Sections repliables** : tap replie/déplie ; `Semantics(expanded)` ; valeur de tranche préservée au repli ; état d'expansion survit à un rebuild structurel ; cible ≥ 48 dp (AC7/AC8/AC9).
- **Mode lecture** : `readOnly` global rend tous les champs en présentation (AC10) ; `showIfNull:false` masque un champ vide en lecture, `showIfNull:true` l'affiche ; hors lecture, `showIfNull` sans effet (AC11).
- **Grille** : test de layout à **5 largeurs fixées** (une par breakpoint) — un champ de span donné occupe la largeur `span/12`, wrap au dépassement (AC12) ; défaut 12 (AC13). **RTL** : ordre des colonnes suit le sens de lecture, aucun overflow (AC14) ; rejouer `style_purity_test`.
- **SM-1** : formulaire de référence (≥ 30 champs/≥ 3 sections + conditionnel + repliable + grille) ; 100 frappes ⇒ zéro build structurel, zéro perte de focus (AC15).
- **Gardes CI** : `analyze` RC=0, `flutter test` RC=0, `CORE OUT=0`, 0 `.g.dart`, `domain_purity_test` vert (AC16).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md — Story E3-4 (ligne 82), E3-5 (83), E3-6 (84)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-2 (lignes 62-65), #AD-13 (117-121), #AD-15 (128-130)]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#FR-3 (lignes 125-131), climax UJ-2 (58-59, 114), SM-1 (378)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart — canal structurel, place stable, sections visuelles E3-1]
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart — visibleFields/setVisibleFields/slices]
- [Source: packages/zcrud_core/lib/src/domain/edition/z_condition.dart — ZCondition/ZConditionOp ; frontière statique/runtime AD-2]
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart — condition/readOnly/showIfNull]
- [Source: CLAUDE.md — « place stable pour les champs conditionnels » ; Key Don'ts directionnels/ListView.builder/setState global]
- [Source: code-review-e3-3a.md (L-3 dropdown), code-review-e3-3b-2.md (LOW-1 mini-CRUD), code-review-e3-3b-3.md (LOW-1/LOW-3 signature) — findings write-mostly → contrat uniforme reporté E3-6/E7]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8) — skill `bmad-dev-story`.

### Debug Log References

- `melos run analyze` → RC=0 (14 packages, « SUCCESS »).
- `zcrud_core` : `flutter test` → RC=0, **346 tests** (baseline 311 → +35 nouveaux E3-4).
- `melos run test` (workspace) → RC=0, aucune régression (6 packages « All tests passed! », dont les 5 satellites d'état inchangés).
- `melos run verify` → RC=0 : `ACYCLIQUE OK`, `CORE OUT=0 OK`, `gate:melos OK`, `gate:reflectable OK`, `gate:secrets OK`, `gate:codegen OK (0 .g.dart manquant)`, `gate:compat OK`.
- `melos list` = **14**. `git ls-files '*.g.dart'` = **0** committé.
- Gardes durcies rejouées vertes : `style_purity_test` (directionnel exclusif + 0 couleur codée), `presentation_purity_test`, `domain_purity_test`, `field_rtl_test`.

### Completion Notes List

**Périmètre livré (16 ACs, 7 tâches — tous cochés) :**
- **T1/AC1** — Évaluateur PUR `evaluateZCondition` (domaine, pur-Dart) : 8 opérateurs + imbrication `and/or/not`, sémantique `truthy` (`zIsTruthy`), extraction des champs de garde `zGuardFieldsOf`. Total/défensif (ne lève jamais).
- **T2/AC2-AC6** — Sélecteur de visibilité dérivé **fondu dans `_DynamicEditionState`** : abonné UNIQUEMENT aux tranches des `guardFields` (jamais à tous les champs) ; recalcul en **ordre canonique** de `fields` → `setVisibleFields` (no-op natif `listEquals`). Frappe non-garde ⇒ **0 recalcul, 0 build structurel** (prouvé). Amorçage de visibilité au montage.
- **AC6 — correctif de conception** : ajout de `findChildIndexCallback` au `ListView.builder` pour PRÉSERVER l'`Element`/`State`/focus d'un champ keyé qui **change d'index** lors de l'insertion/retrait d'un voisin conditionnel (un simple `ValueKey` ne suffit pas dans un sliver paresseux). Sans lui, `other` perdait le focus à l'apparition de `dependent`.
- **T3/AC7-AC9** — Sections repliables : `ZEditionSection.collapsible`/`initiallyExpanded` (additif) ; en-tête `_CollapsibleSectionHeader` keyé `ValueKey('section:<title>')`, `Semantics(button, expanded, label)`, cible ≥ 48 dp (`minHeight`), `EdgeInsetsDirectional`. Repli = masquage VISUEL (slice jamais détruit). État d'expansion détenu par le **`State` parent** (`ValueNotifier _collapsed`), orthogonal à `visibleFields` (AC9).
- **T4/AC10-AC11** — Mode lecture global : spec effective `spec.copyWith(readOnly: true)` (réutilise le respect de `field.readOnly` par toutes les familles, aucune réécriture). `copyWith` ajouté à `ZFieldSpec` (domaine). `showIfNull:false` masque les champs vides EN LECTURE seulement (`null`/`''`/collection vide ; `false`/`0` restent affichés).
- **T5/AC12-AC14** — Grille 12 colonnes : `ZResponsiveSpan{xs..xl}` (défaut 12, cascade mobile-first, bornage `[1,12]`) + `ZResponsiveGrid` (`LayoutBuilder` → breakpoint conteneur, `Wrap` directionnel, gouttières `EdgeInsetsDirectional`). Breakpoints Bootstrap (576/768/992/1200) dans `ZResponsiveBreakpoints`. Aucune modif du générateur/annotations (domaine préservé).
- **T6/AC15-AC16** — Fixture composite (37 champs / 3 sections + conditionnel + repliable + grille) : 100 frappes ⇒ 0 build structurel, focus + curseur préservés. `CORE OUT=0`, 0 `.g.dart`, purity/style/rtl verts.
- **T7** — Barrel : export de `z_condition_evaluator.dart`, `z_responsive_grid.dart` (types préfixés `Z`). Dartdoc FR (AD-2/AD-13) sur chaque nouveau fichier.

**Décisions d'ambiguïtés (Dev Notes) :**
1. Breakpoints = Bootstrap (576/768/992/1200), documentés/testés dans `ZResponsiveBreakpoints`.
2. Base de mesure = `LayoutBuilder` (largeur conteneur, composable) — retenu.
3. « Vide » (showIfNull) = `null` + `String`/`Iterable`/`Map` vide ; `false`/`0` NON vides (valeurs affichables). Cohérent avec `zIsTruthy` sauf que `false`/`0` restent affichés en lecture (choix story #3).
4. Global `readOnly` **force** la lecture ; per-champ `readOnly:true` respecté hors mode global.
5. Grille **par section** (chaque bloc = contexte 12 colonnes) ; le repli cache la grille de sa section.
- **Écart assumé vs libellé T3** : l'état d'expansion est porté par le `State` **parent** (`_collapsed`) plutôt que par un `State` local d'en-tête. Justification : survit non seulement au rebuild structurel mais AUSSI au recyclage `ListView.builder` (un `State` local serait perdu au défilement) ; reste orthogonal à `visibleFields`. En-tête keyé `ValueKey('section:<title>')` conservé.

**Chemins d'exécution préservés (AD-2) :** rendu **PLAT** inchangé (compat E3-1/E3-2/E3-3) quand `layout` vide ET aucune section repliable → toutes les preuves SM-1/UJ-2 antérieures rejouées vertes. Rendu **GROUPÉ** (sections/grille) activé uniquement à l'opt-in. `DynamicEdition` passe de `StatelessWidget` à `StatefulWidget` pour héberger le binder de visibilité + `_collapsed` (aucun `setState` dans la voie de frappe ; canaux structurels via `ListenableBuilder(merge(visibleFields, _collapsed))`).

**Contrat write-back externe** : documenté (dartdoc `dynamic_edition.dart`) mais **NON câblé** (reporté E3-6/E7) — l'état dérivé E3-4 relit la tranche à chaque calcul, sans buffer interne (finding LOW justifié, non bloquant).

### File List

**Créés :**
- `packages/zcrud_core/lib/src/domain/edition/z_condition_evaluator.dart` — évaluateur pur + `zIsTruthy` + `zGuardFieldsOf`.
- `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart` — `ZResponsiveSpan`, `ZBreakpoint`, `ZResponsiveBreakpoints`, `ZResponsiveGrid`.
- `packages/zcrud_core/test/domain/edition/z_condition_evaluator_test.dart`
- `packages/zcrud_core/test/presentation/edition/conditional_visibility_test.dart`
- `packages/zcrud_core/test/presentation/edition/collapsible_sections_test.dart`
- `packages/zcrud_core/test/presentation/edition/read_mode_test.dart`
- `packages/zcrud_core/test/presentation/edition/responsive_grid_test.dart`
- `packages/zcrud_core/test/presentation/edition/sm1_e3_4_composite_test.dart`

**Modifiés :**
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` — `StatefulWidget` : binder de visibilité (guardFields), sections repliables, mode lecture global + showIfNull, intégration grille, `findChildIndexCallback` (place stable focus).
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` — ajout `copyWith` (mode lecture global).
- `packages/zcrud_core/lib/zcrud_core.dart` — exports `z_condition_evaluator.dart`, `z_responsive_grid.dart`.

### Remédiation code-review E3-4 (passe post-review — statut reste `review`)

Rapport source : `code-review-e3-4.md` (verdict CHANGES REQUESTED). Correctifs appliqués, story rejouée verte.

**MAJEUR-1 [CONFIRMÉ] — grille : clé enfouie sous `SizedBox` non keyé (AC5/AC6/SM-1/AD-2/FR-1).**
- Cause : `ZResponsiveGrid` enveloppait chaque cellule dans un `SizedBox` **non keyé**, enfant DIRECT du `Wrap` (multi-enfant non paresseux qui réconcilie **par position**). La `ValueKey(name)` étant enfouie sous ce `SizedBox`, l'insertion d'une cellule conditionnelle AVANT une cellule focalisée décalait les `SizedBox` → destruction de l'`Element`/`State` du champ focalisé → focus + curseur perdus.
- Correctif :
  - `z_responsive_grid.dart` — la cellule (`SizedBox`, enfant direct du `Wrap`) porte désormais la `ValueKey(name)` (nouveau paramètre `keys`, aligné par index ; repli `children[i].key`). `Wrap` réconcilie donc PAR CLÉ.
  - `dynamic_edition.dart` (`_membersLayout`, branche grille) — passe `keys: [ValueKey(spec.name)…]` + des enfants **non keyés à la racine** (`_fieldChild`, extrait de `_buildField`) pour éviter une clé dupliquée (SizedBox + descendant). La garde L3 « place stable non contournable » reste tenue par `keys`.
- Preuve : `test/presentation/edition/grid_conditional_focus_test.dart` — champ `target` focalisé dans une grille (spans 6/12), insertion du conditionnel `dependent` AVANT lui ⇒ `focusNode.hasFocus == true`, caret médian (offset 3) conservé, `fieldInits['target'] == 1` (State non recréé). **Échoue avec l'ancien code** (cellule non keyée → init passerait à 2, focus perdu — vérifié par revert temporaire), **passe après**.

**MEDIUM-1 [PLAUSIBLE→corrigé] — chemin GROUPÉ : blocs non keyés sans `findChildIndexCallback` (AC5/AC6/AD-2).**
- Cause : le `ListView.builder` externe du chemin groupé montait des blocs (`Column` de section, bloc loose) **non keyés** et **sans** `findChildIndexCallback` ; un bloc loose de tête qui bascule OU une section amont qui se vide (`if (members.isEmpty) continue`) décalait les `Column` par position → State/focus des blocs aval perdus.
- Correctif : `dynamic_edition.dart` (`_buildGrouped`) — chaque bloc keyé via un helper `addBlock` (`KeyedSubtree(ValueKey('block:__loose__' | 'block:section:<title>'))`) + `findChildIndexCallback: (key) => blockKeyIndex[key]` sur le `ListView.builder` groupé (parité avec le chemin plat). Ordre canonique et masquage conditionnel/repli inchangés.
- Preuve : `test/presentation/edition/grouped_block_focus_test.dart` — 2 scénarios : (a) bloc loose de tête qui apparaît ; (b) section amont qui se vide. Dans les deux, focus + texte + caret + `State` (`fieldInits['b1'] == 1`) du champ aval `b1` préservés. Le scénario (b) **échoue avec l'ancien code** (sans `findChildIndexCallback`, vérifié par revert temporaire), passe après.

**LOW traités :**
- **LOW-4** — `z_condition_evaluator.dart` : les feuilles déréférençaient `condition.field!`. Remplacé par une lecture défensive `leafValue()` (`field == null ? null : valueOf(field)`) ⇒ total, ne lève jamais (cohérent AD-10). Non testable via l'API publique (constructeur `._` privé, aucun `fromJson`) ; comportement inchangé pour toute condition bien formée (évaluateur unit-test rejoué vert).
- **LOW-1 / LOW-2 / LOW-3** — consignés, non corrigés (nits, hors périmètre focus/place stable ; aucun risque de crash). LOW-1 = limitation classique `copyWith` (sans effet pour l'usage E3-4). LOW-2 = arrondi largeur grille (tests verts, gutter 0). LOW-3 = réactivité `showIfNull` en lecture (mode lecture largement statique).

**Vérif verte rejouée réellement (post-remédiation) :**
- `melos run analyze` → **RC=0** (14 packages, SUCCESS).
- `zcrud_core` : `flutter test` → **RC=0, 349 tests** (346 → **+3** : `grid_conditional_focus_test` ×1, `grouped_block_focus_test` ×2).
- `melos run test` (workspace) → **RC=0**, aucune régression (E3-1/E3-2/E3-3a/E3-3b-* verts).
- `melos run verify` → **RC=0** : `ACYCLIQUE OK`, `CORE OUT=0 OK`, `gate:melos/reflectable/secrets/codegen/compat OK`.
- `melos list` = **14** ; `git ls-files '*.g.dart'` = **0** ; purity (`style_purity`/`presentation_purity`)/RTL verts ; 0 violation directionnelle/couleur sur les fichiers touchés.
- SM-1 rejoué vert sur **tous** les chemins : plat, composite, imbriqué, **grille** (nouveau `grid_conditional_focus_test`), **grouped** (nouveau `grouped_block_focus_test`).

**Fichiers de la remédiation :**
- Modifiés : `z_responsive_grid.dart` (param `keys`, clé sur cellule) ; `dynamic_edition.dart` (`_fieldChild` extrait, blocs groupés keyés + `findChildIndexCallback`, grille `keys`) ; `z_condition_evaluator.dart` (garde défensive `leafValue`).
- Créés : `test/presentation/edition/grid_conditional_focus_test.dart` ; `test/presentation/edition/grouped_block_focus_test.dart`.
