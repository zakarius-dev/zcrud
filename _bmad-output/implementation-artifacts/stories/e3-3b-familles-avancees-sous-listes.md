---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---
# Story 3.3b : Familles avancées & sous-listes

Status: review (sous-story **E3-3b-3**) — **E3-3b COMPLET : -1/-2/-3 done**. **-1 done (review)** ; **-2 done (review)** ; **-3 done (review)** (signature/widget libre).

> **Avancement du découpage (orchestrateur a DÉCOUPÉ en 3 sous-stories)** :
> - **E3-3b-1** (registre `ZWidgetRegistry` + feuilles simples tags/rowChips/rating/slider/color + relâchement L-2) → **DONE (review)**. ACs `[→ -1]` : **1,2,3,4,5,6,7,12,13(harnais),14(base+frontières),15(préservé),16** satisfaits ; vérif verte rejouée (analyze RC=0 · 287 tests RC=0 · verify RC=0 · CORE OUT=0 · 14 pkgs).
> - **E3-3b-2** (sous-listes/subItems/dynamicItem — ACs 8,9) → **DONE (review)**. ACs `[→ -2]` : **8,9,13(enrichi),14(subList/dynamicItem),15(SM-1 imbriqué),16** satisfaits ; vérif verte rejouée (analyze RC=0 · **297** tests zcrud_core RC=0 · **418** tests workspace RC=0 · verify RC=0 · CORE OUT=0 · 14 pkgs). POINT DE VIGILANCE AD-2 N°1 (slices imbriqués) traité.
> - **E3-3b-3** (signature/widget libre — ACs 10,11) → **DONE (review)**. ACs `[→ -3]` : **10,11,13(catalogue enrichi signature+widget libre),14(signature→`signature`, `widget`→`freeWidget` quittent `unsupported`),15(SM-1/UJ-2 préservés),16** satisfaits ; vérif verte rejouée (analyze RC=0 · **311** tests zcrud_core RC=0 · **432** tests workspace RC=0 · verify RC=0 · CORE OUT=0 · 14 pkgs). **E3-3b COMPLET.**

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> ⚠️ **AVIS DE SUR-DIMENSIONNEMENT (CLAUDE.md « E3-3b à décomposer au démarrage »).**
> Cette story est jugée **XL**. La section **[Découpage recommandé](#découpage-recommandé-xl--orchestrateur-décide)**
> propose 3 sous-stories cohérentes (E3-3b-1 / -2 / -3). **L'orchestrateur décide** de
> découper (recommandé) ou de traiter l'umbrella d'un bloc. Les ACs et Tâches ci-dessous
> sont **balisés `[→ -1] / [→ -2] / [→ -3]`** pour se répartir sans réécriture si le split
> est retenu.

## Story

As a développeur intégrant zcrud,
I want, **en réutilisant intégralement la machinerie de tranche/stabilité/a11y/RTL d'E3-3a**,
(1) des **widgets d'édition dédiés** pour les **familles avancées** (`tags`, `rowChips`,
`rating`, `slider`, `color`, `signature`), (2) un **mini-CRUD imbriqué** pour les
**sous-listes** (`subItems`) et l'item dynamique (`dynamicItem`), (3) un **vrai registre
de widgets** (`ZWidgetRegistry`) qui sert les types dont le widget **vit ailleurs**
(markdown→E6, géo/tél→E11a, `custom`→AD-4) et le **widget libre** (`widget`) **sans que
`zcrud_core` ne connaisse ces packages**,
so that un formulaire dérivé du schéma rende le bon contrôle riche par type — accessible,
RTL-correct, à rebuilds granulaires (SM-1/UJ-2 préservés) — et reste **extensible par
enregistrement** au lieu d'un `default` fourre-tout.

## Contexte

E3-3a (`e3-3a-dispatcher-familles-base.md`, **done** ; code-review **APPROVED**, 0
HIGH/MAJEUR/MEDIUM) a livré, dans `packages/zcrud_core/lib/src/presentation/edition/` :

- **`ZFieldWidget`** (dispatcher-hôte) : réutilise `ZFieldListenableBuilder` (E2-7, **unique
  frontière de rebuild** AD-2), `ZValidatorCompiler` (validateur mémoïsé), le contrat de
  stabilité E3-2 (`TextEditingController`/`FocusNode` `late final`, alloués **1×** et
  **seulement** pour les familles clavier via `familyUsesTextController`, sync guardée hors
  focus). Le dispatch **n'échange que le sous-arbre interne** sous le slice.
- **`familyOf(EditionFieldType) → EditionFamily`** : `switch` **exhaustif SANS `default:`**
  (AC2 E3-3a) sur les **39** valeurs → un type non classé **casse la compilation**. Les 6
  familles de base + `hidden` sont servies ; **les 25 types « ailleurs » retombent
  actuellement sur `EditionFamily.unsupported`**.
- **`ZUnsupportedFieldWidget`** : repli contrôlé accessible (jamais un `throw`, jamais un
  `ErrorWidget`). Son docstring **désigne explicitement E3-3b** comme responsable de le
  remplacer par un **registre de widgets** aligné sur AD-4.
- Garde **`KeyedSubtree(ValueKey(field.name))`** posée par `DynamicEdition._buildField`
  (place stable non contournable, L3/AC7 — UJ-2).
- Preuves rejouées à travers le dispatcher : SM-1 plein-formulaire, UJ-2, stabilité
  contrôleur, a11y (`meetsGuideline(androidTapTargetGuideline)`), RTL, exhaustivité 0-default.

**E3-3b transforme les branches `unsupported` en widgets réels ou en points d'extension**,
en **réutilisant** (jamais réécrivant) la machinerie E3-3a/E3-1/E3-2. Deux natures :

1. **Familles avancées « feuilles »** (`tags`, `rowChips`, `rating`, `slider`, `color`,
   `signature`, `subItems`, `dynamicItem`, `widget`) → nouvelles `EditionFamily` + widgets
   dédiés, **value-in-slice** comme booléen/select/date d'E3-3a (lecture `value`, écriture
   `controller.setValue`, **aucun** `TextEditingController` recréé — sauf tags si saisie
   texte, à traiter comme E3-2).
2. **Types servis ailleurs** (`markdown`/`inlineMarkdown`/`html`/`inlineHtml`/`richText`→E6 ;
   `location`/`geoArea`/`phoneNumber`/`country`/`address`→E11a ; `icon` hors-parité MVP ;
   `custom`→AD-4) → **`ZWidgetRegistry`** : le cœur les rend via un builder **injecté par
   l'app hôte** (le package satellite fournit le widget) ; **repli `ZUnsupportedFieldWidget`
   si non enregistré**. `zcrud_core` **n'importe aucun** de ces packages (graphe OUT=0
   inchangé).

### ⚠️ Reclassement clé : `ZTypeRegistry` = **codec**, pas widget

`ZTypeRegistry` (E2-3, `lib/src/domain/registry/z_type_registry.dart`) et sa base
`ZOpenRegistry` enregistrent des **codecs** `register(kind, fromJson, toJson)` — **pas des
`Widget`**. L'epics dit « widget servi via `ZTypeRegistry` » : c'est une **imprécision de
planification** (déjà relevée en E3-3a, Ambiguïté #1, tranchée « registre de widgets = E3-3b »).
E3-3b **NE détourne PAS** `ZTypeRegistry` pour porter des widgets (violerait sa sémantique
codec **et** AD-1 : un registre de codecs vit en `domain/` pur-Dart, un registre de widgets
a besoin de Flutter → `presentation/`). E3-3b **introduit un registre distinct**
**`ZWidgetRegistry`** (couche `presentation/`, renvoie des `Widget`), injecté via `ZcrudScope`.
Convention de nommage de `kind` **alignée** sur `ZTypeRegistry` (mêmes clés `String` : nom
d'`EditionFieldType` pour les types enum ; discriminant `custom` pour `EditionFieldType.custom`)
pour qu'app enregistre **codec + widget sous le même `kind`**.

### Frontière E3-3b (DÉCIDÉE — source de vérité, préserve l'exhaustivité 0-default)

Reclassification des 25 types actuellement `unsupported`. **`familyOf` reste un `switch`
exhaustif SANS `default:`** ; chaque type ci-dessous quitte `unsupported` pour une nouvelle
`EditionFamily` **ou** pour la famille `registryOrFallback` :

| `EditionFieldType` | Nouvelle `EditionFamily` | Traité par | Widget |
|---|---|---|---|
| `tags` | `tags` | **E3-3b** [→ -1] | chips multi-valeur (add/remove), `List<String>` en tranche |
| `rowChips` | `rowChips` | **E3-3b** [→ -1] | rangée de chips mono-choix depuis `choices` |
| `rating` | `rating` | **E3-3b** [→ -1] | étoiles/segments, `num` en tranche |
| `slider` | `slider` | **E3-3b** [→ -1] | `Slider` borné (min/max/divisions), `num` en tranche |
| `color` | `color` | **E3-3b** [→ -1] | sélecteur de couleur, `int`/hex `String` en tranche |
| `subItems` | `subList` | **E3-3b** [→ -2] | **mini-CRUD imbriqué** : `List<Map>` d'items édités par slice imbriqué |
| `dynamicItem` | `dynamicItem` | **E3-3b** [→ -2] | item unique dynamique (add/replace), `Map`/valeur en tranche |
| `signature` | `signature` | **E3-3b** [→ -3] | capture gestuelle, strokes encodés en tranche |
| `widget` | `freeWidget` | **E3-3b** [→ -3] | **widget libre** host-fourni via `ZWidgetRegistry` |
| `markdown`, `inlineMarkdown`, `html`, `inlineHtml`, `richText` | `registryOrFallback` | **E3-3b** (point d'extension) [→ -1] | **registre** → sinon repli. Widget réel = **E6** |
| `location`, `geoArea`, `phoneNumber`, `country`, `address` | `registryOrFallback` | **E3-3b** (point d'extension) [→ -1] | **registre** → sinon repli. Widget réel = **E11a** |
| `icon` | `registryOrFallback` | **E3-3b** (point d'extension) [→ -1] | **registre** → sinon repli. Hors-parité MVP |
| `custom` | `registryOrFallback` | **E3-3b** (point d'extension) [→ -1] | **registre** par discriminant (AD-4). Réel = app hôte |
| **`stepper`** | **reste `unsupported`** | **E3-5** (hors E3-3b) | regroupement multi-étapes, **PAS un champ-feuille** → repli contrôlé ici |
| **`file`, `image`, `document`** | **restent `unsupported`** | **E3-3c** (hors E3-3b) | `ZAppFileField` → repli contrôlé ici |

> **Résultat exhaustivité (les 39 types partitionnés)** :
> **base = 13** (E3-3a) · **hidden = 1** ·
> **avancées-feuilles = 9** (`tags`,`rowChips`,`rating`,`slider`,`color`,`subItems`,`dynamicItem`,`signature`,`widget`) ·
> **registryOrFallback = 12** (`markdown`,`inlineMarkdown`,`html`,`inlineHtml`,`richText`,`location`,`geoArea`,`phoneNumber`,`country`,`address`,`icon`,`custom`) ·
> **unsupported restants = 4** (`stepper`→E3-5 ; `file`/`image`/`document`→E3-3c).
> Somme : 13 + 1 + 9 + 12 + 4 = **39** ✅. Le test d'exhaustivité (itère
> `EditionFieldType.values`) est **étendu** en conséquence.

## Découpage recommandé (XL → orchestrateur décide)

**Verdict : XL — découpage FORTEMENT recommandé.** La story empile trois natures de travail
d'efforts et de risques très différents (dont un **mini-CRUD imbriqué** qui touche AD-2 en
profondeur). Sous-stories **cohérentes, à fichiers largement disjoints** :

| Sous-story | Périmètre | Taille | Dépendances | Justification |
|---|---|---|---|---|
| **E3-3b-1 — Registre de widgets + familles-feuilles simples + L-2** | `ZWidgetRegistry` (seam + injection `ZcrudScope` + résolution dispatcher + repli) ; familles `tags`/`rowChips`/`rating`/`slider`/`color` ; **relâchement ciblé L-2** (`TextInputFormatter`) + `inputFormatters` du champ nombre. | **M/L** | E3-3a | Pose l'**infra d'extensibilité** (débloque E6/E11a/`custom`) + les feuilles à faible risque (value-in-slice pur, calquées sur booléen/select). L-2 vit ici car il touche le champ nombre (E3-3a) et la garde de pureté — un seul changement de garde. |
| **E3-3b-2 — Sous-listes / subItems / dynamicItem (mini-CRUD imbriqué)** | Famille `subList` (`subItems`) : `List<Map>`, add/remove/(reorder), **slice imbriqué par item respectant AD-2** ; famille `dynamicItem`. | **L/XL** | E3-3b-1 (ordonnancement ; pas de dépendance de code stricte) | Le **cœur du risque** : contrôleurs/slices **imbriqués**, préservation SM-1 au niveau imbriqué, cycle de vie add/remove. Mérite sa propre revue adversariale. Recoupe la capacité `ZSubListScreen` d'E4-5 (à ne pas dupliquer — cf. Ambiguïtés). |
| **E3-3b-3 — Signature + widget libre** | Famille `signature` (capture gestuelle + encodage + clear/undo + a11y non-visuelle) ; famille `freeWidget` (`widget`) via `ZWidgetRegistry`. | **M** | E3-3b-1 (réutilise `ZWidgetRegistry`) | `signature` = rendu custom (gesture/canvas) distinct ; `widget` libre = variante host-fournie du registre. Regroupement « rendu custom ». |

**Fichiers disjoints** : chaque sous-story crée ses `families/z_*_field_widget.dart` propres ;
seuls **`edition_field_family.dart`** (ajout de valeurs d'enum + cases), **`z_field_widget.dart`**
(nouveaux cases de dispatch) et **`zcrud_core.dart`** (exports) sont touchés en commun → **écritures
séquentielles** (jamais deux sous-stories en parallèle sur ces 3 fichiers ; cf. règle « fichiers
disjoints » CLAUDE.md). `ZWidgetRegistry` + `ZcrudScope` ne sont modifiés qu'en **-1**. Le
relâchement L-2 (`presentation_purity_test.dart`) n'est touché qu'en **-1**.

> Si l'orchestrateur **ne découpe pas**, traiter l'umbrella comme une seule story L/XL en
> suivant l'ordre des tâches (registre → feuilles simples → sous-listes → signature/widget).
> Si l'orchestrateur **découpe**, il crée 3 clés `e3-3b-1-*`/`e3-3b-2-*`/`e3-3b-3-*` dans le
> sprint-status (**non fait par cette story** — cf. Contraintes) et redistribue ACs/Tâches
> via les balises `[→ -N]`.

## Acceptance Criteria

1. **`ZWidgetRegistry` — seam de registre de widgets injecté.** [→ -1] Un registre
   **instanciable** (`presentation/`) associe un `kind` (`String`) à un **builder de widget**
   `Widget Function(BuildContext, ZFieldWidgetContext)` où `ZFieldWidgetContext` porte
   `{ZFieldSpec field, Object? value, ValueChanged<Object?> onChanged}` (le builder lit
   `value` et écrit via `onChanged`, **dans** la frontière de rebuild existante). API :
   `register(kind, builder)`, `isRegistered`, `builderFor`/`tryBuilderFor`. Injecté via un
   **nouveau champ optionnel `ZcrudScope.widgetRegistry`** (défaut `null`). **Aucun singleton
   statique mutable** (AD-4, Dev Notes E2-3 #2). Test : registre vide → dispatcher rend le
   repli ; registre peuplé → rend le widget hôte.

2. **Type servi « ailleurs » sans que le cœur le connaisse.** [→ -1] Pour tout type
   `registryOrFallback` (markdown/géo/tél/`icon`/`custom`), le dispatcher : (a) résout le
   `kind` (nom d'`EditionFieldType`, ou discriminant `custom` depuis `field.config`/`extra`) ;
   (b) si `ZWidgetRegistry.tryBuilderFor(kind) != null` → rend le widget hôte **dans**
   `ZFieldListenableBuilder` (value-in-slice, `onChanged→setValue`) ; (c) sinon →
   `ZUnsupportedFieldWidget`. **`zcrud_core` n'importe AUCUN** package markdown/géo/tél :
   `graph_proof` **CORE OUT=0** inchangé, 14 packages, graphe acyclique. Test : un
   **widget de démo/test** (faux `kind`, p. ex. `'demo'`/`custom`) enregistré est rendu par
   le dispatcher, lit/écrit la tranche, **aucune** exception, a11y présente — **sans** tirer
   E6/E11a. *(Le widget markdown/géo RÉEL n'est PAS livré ici : E6/E11a.)*

3. **Famille `tags`.** [→ -1] Widget de saisie multi-valeur à chips : ajout (champ de saisie
   ou sélection) + retrait par chip, valeur `List<String>` en tranche. Si saisie texte
   interne : `TextEditingController` **stable** (contrat E3-2, jamais recréé/ré-injecté
   pendant la frappe). A11y : chaque chip supprimable expose une action sémantique + cible
   **≥ 48 dp** ; RTL directionnel.

4. **Famille `rowChips`.** [→ -1] Rangée de chips **mono-choix** alimentée par
   `ZFieldSpec.choices` (`{value,label}`), valeur unique en tranche, `Semantics`
   sélectionné/label, cibles ≥ 48 dp, RTL.

5. **Famille `rating`.** [→ -1] Contrôle de notation (étoiles/segments), valeur `num` en
   tranche, borne max depuis config (défaut 5), `Semantics(value, label)`, chaque cible
   interactive ≥ 48 dp, RTL (progression début→fin directionnelle).

6. **Famille `slider`.** [→ -1] `Slider` borné (min/max/divisions depuis config, défauts
   sûrs), valeur `num` en tranche, `Semantics` de slider (valeur annoncée), RTL, thème
   injecté (aucune couleur en dur — FR-26).

7. **Famille `color`.** [→ -1] Sélecteur de couleur (palette/roue), valeur encodée
   **stable** en tranche (`int` ARGB **ou** hex `String` — décider et documenter), aperçu
   accessible (`Semantics` label + valeur), cibles ≥ 48 dp, RTL. Les swatches sont des
   **données** (pas un style codé en dur de la charte — pas de violation FR-26).

8. **Famille `subList` (sous-liste / `subItems`) — mini-CRUD imbriqué.** [→ -2] Édition d'une
   `List<Map<String,dynamic>>` d'items : **ajouter**, **supprimer** (et **réordonner** si
   trivial), chaque item édité via un **slice/sous-contrôleur imbriqué** respectant AD-2 —
   **taper dans un champ d'un item ne reconstruit que ce champ** (SM-1 au niveau imbriqué),
   **aucun `setState` global**, **aucun `Form`/`FormBuilder` global**. Écriture de la liste
   dans la tranche parente via `setValue`. A11y (boutons add/remove ≥ 48 dp, `Semantics`),
   RTL. Test : add/remove modifie la liste en tranche ; **SM-1 imbriqué** (frappe dans un
   champ d'item → seul ce champ reconstruit) ; retrait d'un item ne casse pas l'état des
   autres (place stable par clé d'item).

9. **Famille `dynamicItem`.** [→ -2] Item unique de type dynamique (add/replace/clear),
   valeur `Map`/opaque en tranche, AD-2 (rebuild ciblé), a11y/RTL. Test : set/replace/clear
   reflété en tranche sans rebuild global.

10. **Famille `signature`.** [→ -3] ✅ **-3** Capture de signature gestuelle : tracé, **clear**/**undo**,
    valeur = strokes encodés **stables** en tranche (format documenté : liste de points/segments
    ou bytes). A11y : `Semantics` (label + état « signé/vide ») + **alternative non gestuelle**
    documentée (au minimum label descriptif ; cible d'effacement ≥ 48 dp) ; RTL des contrôles.
    Aucune dépendance lourde tirée dans le cœur (rendu via `CustomPaint`/gesture Flutter natif).
    Test : tracé → tranche non vide ; clear → tranche vide/`null`, **aucune** exception.

11. **Famille `freeWidget` (`widget` libre).** [→ -3] ✅ **-3** Le type `widget` rend un **widget
    host-fourni** via `ZWidgetRegistry` (même seam qu'AC1/AC2 ; `kind` = `'widget'` ou
    discriminant de `field.config`/`extra`), **repli `ZUnsupportedFieldWidget` si non
    enregistré**. Le cœur reste agnostique (aucun widget métier codé dans `zcrud_core`).
    Test : `widget` enregistré → rendu host ; non enregistré → repli, aucune exception.

12. **Relâchement L-2 (ciblé) — `TextInputFormatter` autorisé, `services.dart` en bloc
    toujours banni.** [→ -1] `presentation_purity_test.dart` est **relâché de façon
    CIBLÉE** : `import 'package:flutter/services.dart'` est autorisé **UNIQUEMENT** avec une
    clause `show` **restreinte** à un allowlist de symboles **purs sans état**
    (`TextInputFormatter`, `FilteringTextInputFormatter` ; `TextInputType` si utile) —
    analogue à `form_builder_validators` déjà whitelisté (E3-2). Un `import
    'package:flutter/services.dart';` **nu** (sans `show`, ou avec un symbole hors allowlist,
    p. ex. `Clipboard`/`SystemChannels`/`rootBundle`) **reste REJETÉ**. Le champ **nombre**
    (`z_number_field_widget.dart`, E3-3a) porte alors des `inputFormatters`
    (`FilteringTextInputFormatter.digitsOnly` pour `integer`, motif décimal/signe pour
    `number`/`float`). Tests de garde **bidirectionnels** : (a) `services.dart show
    TextInputFormatter` → **autorisé** ; (b) `services.dart` nu → **rejeté** ; (c)
    `services.dart show Clipboard` → **rejeté**. Test comportemental : le champ nombre filtre
    la saisie non-numérique (plus de caractère non-numérique transitoire au clavier physique).

13. **Test a11y de RÉFÉRENCE sur le catalogue.** [→ -1 (harnais), enrichi par -2/-3] Un
    formulaire **catalogue** couvrant **toutes** les familles avancées E3-3b (tags, rowChips,
    rating, slider, color, subList, dynamicItem, signature, freeWidget) **+ un type
    registryOrFallback servi par un widget de démo enregistré** passe
    `meetsGuideline(androidTapTargetGuideline)` (≥ 48 dp) **et** `textContrastGuideline`, et
    présente des `Semantics`/labels sur chaque contrôle interactif ; **rendu RTL sans
    overflow/exception**. `SemanticsHandle` disposé.

14. **Exhaustivité 0-default PRÉSERVÉE + frontières.** [→ -1 (base) / -2 / -3 (compléments)]
    `familyOf` reste un `switch` **exhaustif SANS `default:`** ; les nouvelles `EditionFamily`
    (`tags`/`rowChips`/`rating`/`slider`/`color`/`subList`/`dynamicItem`/`signature`/
    `freeWidget`/`registryOrFallback`) sont ajoutées ; **`stepper` reste `unsupported`
    (→ E3-5)** et **`file`/`image`/`document` restent `unsupported` (→ E3-3c)** — repli
    contrôlé, **jamais** un widget avancé usurpé. Test étendu itérant les **39**
    `EditionFieldType.values` : chaque type → sa famille attendue (aucun type avancé ne tombe
    en `unsupported` ; `stepper`/`file`/`image`/`document` **restent** en repli).

15. **SM-1 / UJ-2 PRÉSERVÉS à travers le dispatcher étendu (objectif produit n°1, AD-2).**
    [→ tous] Les preuves E3-3a restent **vertes** : sur le formulaire de référence, 100
    frappes dans un champ **texte** ne reconstruisent que ce champ (voisins + structurel
    inchangés, focus/curseur intacts) ; rebuild d'ancêtre ne recrée pas l'état des champs
    (UJ-2). **Aucune famille avancée n'introduit de rebuild global** ; le mini-CRUD imbriqué
    (`subList`) préserve la granularité **au niveau imbriqué** (SM-1 imbriqué, AC8). **Aucun
    `Form`/`FormBuilder` global** n'apparaît sous `presentation/edition/` (`find.byType(Form)
    → findsNothing`).

16. **Vérif verte + gates + graphe.** [→ chaque sous-story, avant `review`/`done`]
    `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 (dont
    `presentation_purity_test` **relâché-mais-vert**, `style_purity_test`, `domain_purity_test`,
    exhaustivité, a11y catalogue, SM-1/UJ-2). `melos run verify` RC=0 (reflectable/secrets/
    codegen/compat). `graph_proof` **CORE OUT=0**, acyclique, **14 packages**. **0 `.g.dart`
    committé.**

## Tasks / Subtasks

- [x] **Task 1 — `ZWidgetRegistry` + injection `ZcrudScope` + résolution dispatcher** (AC: 1, 2) [→ -1] ✅ **-1**
  - [x] Créer `lib/src/presentation/edition/z_widget_registry.dart` : `ZWidgetRegistry`
    (instanciable, non-statique) + typedef `ZFieldWidgetBuilder = Widget Function(BuildContext,
    ZFieldWidgetContext)` + `ZFieldWidgetContext {field, value, onChanged}`. API
    `register`/`isRegistered`/`builderFor`(strict throw)/`tryBuilderFor`(défensif null). Aligner
    la sémantique `kind` (`String`) sur `ZTypeRegistry` (documenter le mapping).
  - [x] Ajouter le champ optionnel `widgetRegistry` (défaut `null`) à `ZcrudScope` +
    `updateShouldNotify` (identité) ; documenter le défaut « aucun registre → repli ».
  - [x] Dans `ZFieldWidget._dispatch` (ou le pré-dispatch de `build`), pour la famille
    `registryOrFallback` : résoudre `kind`, lire `ZcrudScope.maybeOf(context)?.widgetRegistry`,
    tenter `tryBuilderFor(kind)` → rendre **dans** `ZFieldListenableBuilder` (value-in-slice,
    `onChanged→setValue`) ; sinon `ZUnsupportedFieldWidget`. **Ne pas** élargir la frontière
    de rebuild. Documenter le point d'injection `custom` (discriminant).
- [x] **Task 2 — `familyOf` : nouvelles familles + exhaustivité** (AC: 14) [→ -1 base, -2/-3 compléments] ✅ **-1 (base)** + **-2** (`subList`/`dynamicItem`) + **-3** (`signature`→`EditionFamily.signature`, `widget`→`EditionFamily.freeWidget` quittent `unsupported` ; `switch` exhaustif SANS `default:` ; partition 39 re-vérifiée = 13 base + 1 hidden + 8 feuilles + 1 freeWidget + 12 registryOrFallback + 4 unsupported)
  - [x] Étendre `EditionFamily` (**-1** : tags, rowChips, rating, slider, color, registryOrFallback).
    Reclasser markdown/HTML/richText/géo/tél/`icon`/`custom` → `registryOrFallback` ; **conserver**
    `subItems`/`dynamicItem`/`signature`/`widget` (→ -2/-3), `stepper` (→E3-5) et
    `file`/`image`/`document` (→E3-3c) en `unsupported`. `switch` **exhaustif SANS `default:`**
    (partition 39 = 13 base + 1 hidden + 5 feuilles + 12 registre + 8 unsupported vérifiée par test).
  - [x] `familyUsesTextController` **inchangé** (text/number) : décision -1 — `tags` gère un
    `TextEditingController` d'ajout **éphémère LOCAL** (état du widget, PAS la valeur du champ →
    en tranche), donc l'hôte `ZFieldWidget` n'alloue AUCUN contrôleur pour `tags` (stabilité E3-2
    respectée par construction : contrôleur d'ajout créé 1× en `initState`, jamais recréé).
- [x] **Task 3 — Familles-feuilles simples** (AC: 3, 4, 5, 6, 7) [→ -1] ✅ **-1**
  - [x] `families/z_tags_field_widget.dart` (`tags` — `List<String>`, add/remove, saisie stable).
  - [x] `families/z_row_chips_field_widget.dart` (`rowChips` — mono-choix depuis `choices`).
  - [x] `families/z_rating_field_widget.dart` (`rating` — `num`, max config).
  - [x] `families/z_slider_field_widget.dart` (`slider` — `num`, min/max/divisions config).
  - [x] `families/z_color_field_widget.dart` (`color` — encodage `int` ARGB documenté).
  - [x] Chacun : value-in-slice (lecture `value`, écriture `setValue`), `Semantics` + ≥ 48 dp,
    **directionnel exclusif**, thème injecté. Configs **triviales pur-cœur** additives ajoutées
    (`ZSliderConfig{min,max,divisions}`/`ZRatingConfig{max}` — `const`, pur-données, AD-4).
- [x] **Task 4 — Sous-listes / dynamicItem (mini-CRUD imbriqué)** (AC: 8, 9, 15) [→ -2] ✅ **-2**
  - [x] `families/z_sub_list_field_widget.dart` (`subItems`) : `List<Map>`, add/remove/reorder,
    **slice imbriqué par item** (`ZFormController` propre + place stable `KeyedSubtree(ValueKey(itemId))`),
    AD-2 strict (aucun rebuild global ; frappe dans un item → seul ce champ — prouvé par compteurs).
    Sous-schéma d'item = config additive `ZSubListConfig{itemFields, reorderable}` (`const`, pur-données,
    AD-4) ; édition d'item **réutilise** `ZFieldWidget` (dispatcher).
  - [x] `families/z_dynamic_item_field_widget.dart` (`dynamicItem`) : item unique add/edit/clear
    (cardinalité ≤ 1, même invariant SM-1 imbriqué).
  - [x] **Ne pas dupliquer** `ZSubListScreen` (E4-5) : ces widgets sont le **champ d'édition
    imbriqué** (E3), pas l'écran de liste autonome (E4). Frontière documentée dans les docstrings +
    `ZSubListConfig` (sous-schéma `const` = brique commune réutilisable côté E4-5).
- [x] **Task 5 — Signature + widget libre** (AC: 10, 11) [→ -3] ✅ **-3**
  - [x] `families/z_signature_field_widget.dart` (`signature`) : `CustomPaint`/gesture natif
    (`GestureDetector` onPan* → strokes normalisés `[0,1]` ; `_SignaturePainter`),
    clear/undo, encodage stable **documenté** (`Map` versionnée `{formatVersion, strokes:[[x,y,…]]}`,
    normalisé, sérialisable, PAS de bytes image), a11y non-gestuelle (`Semantics` label « zone de
    signature » + état signé/vide, cibles clear/undo ≥ 48 dp). **Aucune** dépendance lourde
    (CustomPaint/gesture natif ; `PointMode`/`dart:ui` évités → garde de pureté verte).
  - [x] `families/z_free_widget_field_widget.dart` (`widget`) : **CONSOMME** `ZWidgetRegistry`
    (Task 1, kind `field.type.name` = `'widget'`), repli `ZUnsupportedFieldWidget` si non enregistré.
- [x] **Task 6 — Relâchement L-2 (garde de pureté) + `inputFormatters` du champ nombre** (AC: 12) [→ -1] ✅ **-1**
  - [x] Modifier `test/purity/presentation_purity_test.dart` : autoriser `package:flutter/
    services.dart` **uniquement** avec `show` restreint à l'allowlist de symboles purs
    (`TextInputFormatter`, `FilteringTextInputFormatter`, `TextInputType`) ; parser la clause
    `show` (robuste au multi-ligne) ; **rejeter** `services.dart` nu ou avec symbole hors allowlist.
  - [x] Ajouter les tests de garde **bidirectionnels** (autorisé/rejeté/rejeté-symbole).
  - [x] `z_number_field_widget.dart` : importer `services.dart show FilteringTextInputFormatter,
    TextInputFormatter` et poser `inputFormatters` (int : `digitsOnly` ; `[0-9.\-]` pour
    `number`/`float`) sans casser le parse défensif (`tryParse→null`) ni la sync guardée E3-2.
- [x] **Task 7 — Exports barrel + l10n/thème** (AC: 1–13) [→ chaque sous-story pour ses widgets] ✅ **-1 (portion)** + **-2** + **-3** : exports `ZSignatureFieldWidget`/`ZFreeWidgetFieldWidget` ; clés l10n `signatureArea`/`signatureSigned`/`signatureEmpty`/`clearSignature`/`undoSignature` (en/fr)
  - [x] Exporter l'API publique **-1** dans `lib/zcrud_core.dart` (`ZWidgetRegistry`,
    `ZFieldWidgetContext`/`ZFieldWidgetBuilder`, `ZTagsFieldWidget`/`ZRowChipsFieldWidget`/
    `ZRatingFieldWidget`/`ZSliderFieldWidget`/`ZColorFieldWidget`). l10n étendue
    (`addTag`/`removeTag`/`selectColor`/`rate`) — aucun littéral métier codé en dur.
- [x] **Task 8 — Tests** (AC: 1–16) — voir « Testing ». [→ chaque sous-story pour son périmètre + AC13/15/16 transverses] ✅ **-1** + **-2** + **-3** (signature : capture/clear/undo/encodage sérialisable/défensif/a11y/RTL ; freeWidget : host rendu+écrit / repli sans registre / repli kind absent ; dispatch 39 étendu ; catalogue a11y enrichi)
- [x] **Task 9 — Vérif verte + gates + graphe** (AC: 16) [→ chaque sous-story avant `review`] ✅ **-1** + **-2** + **-3**
  - [x] `analyze` RC=0 (14 pkgs) → `flutter test` RC=0 (**311** tests zcrud_core / **432** workspace) ;
    `melos run verify` RC=0 ; `graph_proof` **CORE OUT=0** acyclique **14** pkgs ; 0 `.g.dart` committé.

## Dev Notes

### Architecture — invariants applicables (NON-NÉGOCIABLES)

- **AD-2 (objectif produit n°1)** : chaque famille avancée **échange le sous-arbre interne**
  sous `ZFieldListenableBuilder` (RÉUTILISÉ, E2-7) ; **jamais** de `setState` de niveau
  formulaire, **jamais** de construction de champs dans une closure locale recréée au build,
  **jamais** de recréation de `TextEditingController`. **`subList` (mini-CRUD imbriqué) est le
  point de vigilance n°1** : le slice imbriqué doit préserver la granularité (place stable par
  item, contrôleur d'item non recréé). [Source: architecture.md#AD-2 ; CLAUDE.md AD-2]
- **AD-4 (extensibilité / registre ouvert)** : le registre de widgets est **instanciable et
  injecté** (`ZcrudScope`), **jamais** un singleton statique mutable ; `kind` ouvert ; `custom`
  par discriminant ; slot `extra`/`ZExtension?` disponibles. **Rejetés** : héritage de classes
  sérialisées, `sealed` pour l'extension inter-package. `ZTypeRegistry` (codec) **non
  détourné**. [Source: architecture.md#AD-4 ; z_type_registry.dart / z_open_registry.dart]
- **AD-13 (RTL/a11y/l10n)** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start-end`/
  `PositionedDirectional` **uniquement** ; `Semantics` explicites ; cibles **≥ 48 dp** ; l10n via
  registre/delegate injecté (zéro `lex_localizations`/`go_router`/`context.l10n`). [Source:
  architecture.md#AD-13 ↔ FR-23]
- **AD-15 / AD-1** : `zcrud_core` **n'importe aucun** gestionnaire d'état **ni** package
  satellite (markdown/géo/tél) ; graphe **acyclique, OUT=0** ; le registre de widgets rend le
  cœur agnostique des widgets externes. [Source: architecture.md#AD-15 / AD-1]
- **FR-26** : aucun style/couleur codé en dur ; thème injecté (`ZcrudTheme`/`ThemeExtension`),
  repli `Theme.of(context)`. Les swatches `color` et les segments `rating` sont des **données**,
  pas la charte. [Source: architecture.md#AD-13 / CLAUDE.md]

### CLAUDE.md — Key Don'ts directement pertinents

- **Jamais** `EdgeInsets.only(left/right)`, `Alignment.*Left/Right`, `Positioned(left/right)`,
  `TextAlign.left/right`, `BorderRadius.only/horizontal` → variantes **directionnelles**.
- **Jamais** `ListView(children: [...])` → `ListView.builder` (pertinent pour `subList`).
- **Toujours** `Semantics` explicites + cibles ≥ 48 dp ; `const` pour les widgets immuables.
- **Jamais** de style/couleur codé en dur ; **jamais** importer un gestionnaire d'état dans le cœur.
- **Jamais** `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` → `ZcrudScope`/seams.

### Finding de code-review à couvrir (porté dans AC12)

- **L-2** (code-review **E3-3a** §3 + LOW-2) : *« relâcher la garde de pureté pour autoriser
  `TextInputFormatter`/`FilteringTextInputFormatter` (transformateurs **purs**, sans état —
  analogues à `form_builder_validators` déjà whitelisté ; **jamais** tout `services.dart` en
  bloc — whitelister par symbole ou par sous-chemin). À traiter en E3-3b. »* → **AC12** :
  relâchement **par symbole via `show`** (`TextInputFormatter`/`FilteringTextInputFormatter`/
  `TextInputType`), `services.dart` nu **toujours banni**, + `inputFormatters` du champ nombre.
  *Vérification SDK déjà faite (code-review E3-3a §3) : `TextInputType` est re-exporté par
  `widgets.dart` (d'où compilation actuelle) ; `TextInputFormatter`/`FilteringTextInputFormatter`
  exigent réellement `import 'package:flutter/services.dart'`.*

### Fichiers existants à RÉUTILISER / MODIFIER (LIRE avant d'implémenter — ne pas réécrire)

**À MODIFIER :**
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` — ajouter les
  `EditionFamily` + reclasser les cases (exhaustif sans `default:`). *(État : 6 base + hidden +
  25 `unsupported`.)*
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` — nouveaux cases de
  dispatch + résolution `registryOrFallback` via `ZcrudScope.widgetRegistry`. **Préserver** la
  frontière `ZFieldListenableBuilder`, la stabilité contrôleur clavier (`familyUsesTextController`),
  la sync guardée `_syncText`. *(Ne pas casser les cases `hidden`/`unsupported` traités avant le
  slice.)*
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — champ optionnel `widgetRegistry`
  + `updateShouldNotify`. *(Bundle immuable de seams — cf. `resolver`/`acl`/`labels`/`theme`.)*
- `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` —
  `inputFormatters` (AC12).
- `packages/zcrud_core/test/purity/presentation_purity_test.dart` — relâchement L-2 (AC12).
- `packages/zcrud_core/lib/zcrud_core.dart` — exports.
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` — libellés des nouveaux contrôles.

**À RÉUTILISER tel quel (NE PAS réécrire) :**
- `.../edition/z_field_widget.dart` machinerie de slice/stabilité (dispatcher-hôte E3-3a).
- `.../presentation/z_field_listenable_builder.dart` (E2-7) — **unique** frontière de rebuild.
- `.../edition/z_validator_compiler.dart` — validateur mémoïsé.
- `.../edition/dynamic_edition.dart` — assembleur + garde `KeyedSubtree` (place stable). **Réutiliser
  pour l'édition d'un item de `subList`** plutôt que réimplémenter un formulaire imbriqué.
- `.../edition/families/z_unsupported_field_widget.dart` — repli (branché par le registre).
- `.../edition/families/z_boolean_field_widget.dart`, `z_select_field_widget.dart`,
  `z_date_field_widget.dart` — **patrons value-in-slice** à imiter pour les feuilles avancées.
- `.../domain/edition/edition_field_type.dart` (39 valeurs), `z_field_spec.dart`
  (`choices`/`config`/`multiple`/`readOnly`/`defaultValue`), `z_field_config.dart` (base
  `abstract` AD-4 + `ZTextConfig`/`ZNumberConfig`/`ZDateConfig` — modèle pour configs additives),
  `z_field_choice.dart`.
- `.../domain/registry/z_type_registry.dart` + `z_open_registry.dart` — **modèle** du registre
  (mais widgets ≠ codecs → `ZWidgetRegistry` distinct en `presentation/`).
- Gardes : `test/purity/style_purity_test.dart` (directionnel + couleur — doit rester vert),
  `test/purity/presentation_purity_test.dart` (whitelist ; **relâchée** L-2), `domain_purity_test.dart`.

### Décision d'intégration (respect AD-2)

- Le **dispatcher-hôte `ZFieldWidget` reste le point unique** : les familles avancées sont de
  nouveaux cases sous le même `ZFieldListenableBuilder` (comme booléen/select/date). **Ne pas**
  créer un second chemin de rebuild.
- **Registre** : résolu via `ZcrudScope.maybeOf(context)` **dans** le `build`/`_dispatch`
  (dépendance d'héritage) — le widget hôte est rendu **sous** le slice (value-in-slice). Si le
  widget hôte a besoin d'un contrôleur isolé (cas markdown E6), c'est **sa** responsabilité (le
  cœur ne gère pas sa stabilité) — cohérent AD-7 « rich-text à controller isolé ».
- **subList** : réutiliser `ZFieldWidget`/`DynamicEdition` pour éditer **un item** (sous-schéma),
  la place stable par item via `ValueKey(itemId)` ; le champ agrège `List<Map>` et écrit la
  liste entière via `setValue` sur mutation. Contrôleur d'item **non recréé** sur rebuild parent.

### Ambiguïtés détectées (à trancher en dev, sans bloquer)

1. **`ZTypeRegistry` = codec, pas widget** → E3-3b introduit **`ZWidgetRegistry`** distinct
   (`presentation/`), pas de détournement (tranché ; cf. Contexte + E3-3a Ambiguïté #1).
2. **`stepper` hors E3-3b** : regroupement multi-étapes (E3-5), pas un champ-feuille → reste
   `unsupported` (repli) ici. **`file`/`image`/`document` hors E3-3b** (E3-3c) → restent
   `unsupported`.
3. **Sous-schéma des items `subList`** : où vit le `ZFieldSpec[]` d'un item ? Options : config
   additive d'item (`ZSubListConfig` avec `List<ZFieldSpec>`), ou registre. **À trancher en -2** ;
   privilégier une config additive pur-données (`const`, AD-4) réutilisant `DynamicEdition`.
4. **Recoupement E4-5 (`ZSubListScreen`)** : E3-3b livre le **champ d'édition imbriqué** (dans un
   formulaire) ; E4-5 livre l'**écran de sous-liste autonome** (mini-CRUD de niveau liste). **Ne
   pas dupliquer** ; documenter la frontière et, si possible, factoriser la brique commune.
5. **Encodage `color`** (`int` ARGB vs hex `String`) et **`signature`** (points vs bytes) :
   décider un format **stable, sérialisable, additif** et le documenter (cohérent AD-3/AD-10 :
   désérialisation défensive, `fromJsonSafe→null`).
6. **`custom` (`registryOrFallback`)** : d'où vient le `kind` ? Depuis `field.config`/`extra`
   (discriminant AD-4). Le dispatcher lit un discriminant ; **à documenter** le contrat
   d'enregistrement app (codec `ZTypeRegistry` + widget `ZWidgetRegistry` sous le **même `kind`**).
7. **`icon`** : hors-parité MVP → `registryOrFallback` (repli si non enregistré), pas de widget
   dédié ici.

### Project Structure Notes

- Nouveaux fichiers sous `packages/zcrud_core/lib/src/presentation/edition/` :
  `z_widget_registry.dart` (+ `ZFieldWidgetContext`) et `families/z_{tags,row_chips,rating,slider,
  color,sub_list,dynamic_item,signature,free_widget}_field_widget.dart`. Configs additives
  éventuelles sous `lib/src/domain/edition/` (`z_field_config.dart` étendu ou fichiers dédiés,
  `const` pur-données).
- **Pureté** : `presentation/` autorise `material`/`widgets`/`foundation` + `form_builder_validators`
  + (**AC12**) `services.dart show TextInputFormatter,FilteringTextInputFormatter[,TextInputType]`.
  **Toujours interdits** : `cupertino`, `services.dart` nu/hors-allowlist, gestionnaires d'état,
  `flutter_form_builder`, Firebase/Hive/Syncfusion/Quill/Maps. `domain/` reste **pur-Dart**.
- Le graphe reste **acyclique**, `zcrud_core` out-degree **0** — **aucune** nouvelle dépendance de
  package (le registre rend markdown/géo/tél servables **sans** les importer).

### Testing

Framework : `flutter_test` (widgets) + `package:test` (gardes fichiers). Répertoire :
`packages/zcrud_core/test/presentation/edition/`. Réutiliser/étendre `_family_form.dart` (harnais
E3-3a) en un **catalogue** couvrant les familles avancées.

Tests exigés :

- **Registre (AC1/AC2)** : `z_widget_registry_test.dart` — register/lookup/tryLookup ; dispatcher
  avec registre vide → repli ; registre peuplé (**widget de démo**, faux `kind`/`custom`) → widget
  hôte rendu, lit `value`/écrit via `onChanged` (tranche mise à jour), **aucune** exception, a11y
  présente ; `graph_proof` CORE OUT=0 (aucun import externe).
- **Feuilles simples (AC3–7)** : un test par famille (`z_tags`/`z_row_chips`/`z_rating`/`z_slider`/
  `z_color`) — interaction → tranche mise à jour (type attendu) ; type de widget attendu (jamais le
  repli) ; `Semantics`/≥ 48 dp ; RTL sans overflow.
- **subList / dynamicItem (AC8/AC9)** : `z_sub_list_test.dart` — add/remove/(reorder) modifie la
  `List` en tranche ; **SM-1 imbriqué** (frappe dans un champ d'item → seul ce champ reconstruit,
  compteur voisins inchangé) ; retrait d'item n'altère pas l'état des autres (place stable). `Form
  → findsNothing`.
- **signature / freeWidget (AC10/AC11)** : tracé → tranche non vide ; clear → vide/`null` ; `widget`
  enregistré → host, non enregistré → repli ; aucune exception.
- **L-2 garde (AC12)** : `presentation_purity_test` **bidirectionnel** — `services.dart show
  TextInputFormatter` autorisé ; `services.dart` nu rejeté ; `services.dart show Clipboard` rejeté.
  Comportemental : champ nombre filtre la saisie non-numérique (formatter appliqué).
- **Catalogue a11y de référence (AC13)** : `catalogue_a11y_test.dart` — toutes familles avancées +
  1 type registre (démo) ; `meetsGuideline(androidTapTargetGuideline)` + `textContrastGuideline` +
  `Semantics` ; **RTL** (`Directionality.rtl`) sans overflow. `SemanticsHandle` disposé.
- **Exhaustivité 0-default (AC14)** : `z_field_dispatch_test.dart` **étendu** — itère les 39
  `EditionFieldType.values` ; chaque type → famille attendue (avancées jamais `unsupported`) ;
  `stepper`/`file`/`image`/`document` **restent** `unsupported`/repli ; `familyOf` sans `default:`
  (compilation).
- **SM-1/UJ-2 non-régression (AC15)** : rejouer `sm1_full_form`, `uj2_external_rebuild`,
  `uj2_dispatch_nontext`, `l4_focus_change`, `controller_stability`, `mid_cursor`,
  `external_value_sync`, `keyed_subtree_guard`, `validation_targeted_dispatch` — **verts** à travers
  le dispatcher étendu.

Non-régression : suite `zcrud_core` complète verte (E2-*, E3-1/E3-2/E3-3a — **260** tests avant
E3-3b) ; gates melos/reflectable/secrets/codegen/compat ; `graph_proof` CORE OUT=0 ; 14 packages ;
0 `.g.dart` committé.

### References

- [Source: epics.md#E3 — Story E3-3b] (`subItems`/`dynamicItem`/`tags`/`rowChips`/`rating`/`slider`/
  `signature`/`color`/`widget` ; types « ailleurs » via registre — markdown→E6, géo/tél→E11a ;
  a11y/RTL comme E3-3a ; test a11y de référence catalogue). NB epics : `stepper`→E3-5 (regroupement).
- [Source: epics.md#E4 — Story E4-5] `ZSubListScreen` (écran autonome — frontière avec le **champ**
  imbriqué E3-3b).
- [Source: architecture.md#AD-2] rebuilds granulaires ; [architecture.md#AD-4] registre ouvert
  instanciable/`custom` ; [architecture.md#AD-13 ↔ FR-23] RTL/a11y/l10n ; [architecture.md#AD-1/AD-15]
  graphe OUT=0 / aucun gestionnaire d'état ; [architecture.md#AD-7] rich-text à controller isolé
  (widget hôte du registre).
- [Source: code-review-e3-3a.md §3 + §4 (L-2 / LOW-2)] relâchement ciblé `TextInputFormatter`.
- [Source: e3-3a-dispatcher-familles-base.md] machinerie réutilisée (dispatcher-hôte, `familyOf` 0
  default, `ZUnsupportedFieldWidget` point d'extension, `KeyedSubtree`, contrat de stabilité E3-2).
- [Source: CLAUDE.md] Key Don'ts (directionnel, `ListView.builder`, Semantics ≥ 48 dp, no hardcoded
  style, no state-manager in core) ; **« E3-3b sur-dimensionnée à décomposer au démarrage »** →
  [Découpage recommandé](#découpage-recommandé-xl--orchestrateur-décide).
- Fichiers : `edition_field_family.dart`, `z_field_widget.dart`, `zcrud_scope.dart`,
  `z_type_registry.dart`, `z_open_registry.dart`, `z_field_spec.dart`, `z_field_config.dart`,
  `z_number_field_widget.dart`, `presentation_purity_test.dart`, `style_purity_test.dart`,
  `dynamic_edition.dart`, `z_field_listenable_builder.dart`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, périmètre **sous-story E3-3b-1 uniquement** ; skill chargé
depuis le disque `.claude/skills/bmad-dev-story/SKILL.md`).

### Debug Log References

- `flutter analyze lib test` (zcrud_core) → **No issues found** (RC=0).
- `melos run analyze` → **14/14 packages** No issues found (RC=0).
- `flutter test` (zcrud_core) → **All tests passed** — **287** tests (RC=0 ; +27 vs 260 baseline E3-3a).
- `melos run verify` → RC=0 (graph_proof · gate_melos · gate_reflectable · gate_secret_scan ·
  gate_codegen · gate_compat · verify_serialization). `graph_proof.py` : **out-degree(zcrud_core)=0**,
  ACYCLIQUE OK, **CORE OUT=0 OK**, 14 nœuds.
- Correctif intra-story : la garde L-2 échouait d'abord car l'import `services.dart` du champ
  nombre s'étend sur **2 lignes** (le `show` sur la 2e) → parseur de pureté rendu robuste au
  multi-ligne (`_joinStatement` jusqu'au `;`). Verte ensuite.

### Completion Notes List (sous-story -1)

**PÉRIMÈTRE STRICT -1** : registre `ZWidgetRegistry` + feuilles simples (tags/rowChips/rating/
slider/color) + relâchement L-2. **NON traité (hors -1)** : subItems/dynamicItem (= -2),
signature/widget libre (= -3) → ces types **restent `unsupported`** (repli contrôlé) ; `stepper`
(E3-5) et `file`/`image`/`document` (E3-3c) restent aussi `unsupported`.

- **AC1/AC2 (registre)** : `ZWidgetRegistry` **instanciable** (jamais singleton statique — AD-4),
  couche `presentation/`, **DISTINCT** de `ZTypeRegistry` (codecs domain/). `kind:String → Widget
  Function(BuildContext, ZFieldWidgetContext{field,value,onChanged})`. API `register`/`isRegistered`/
  `kinds`/`builderFor`(throw `ZUnregisteredTypeError`)/`tryBuilderFor`(null). Injecté via nouveau
  champ optionnel `ZcrudScope.widgetRegistry` (défaut `null`). Dispatcher : famille
  `registryOrFallback` résolue **dans** `ZFieldListenableBuilder` (value-in-slice) via
  `tryBuilderFor(field.type.name)` → sinon `ZUnsupportedFieldWidget`. **Preuve d'agnosticité** : un
  **widget de démo défini DANS le test** (kind `'markdown'`/`'custom'`) est servi/lit/écrit la
  tranche sans que le cœur importe E6/E11a → `graph_proof` CORE OUT=0 inchangé.
- **AC3–7 (feuilles)** : `ZTagsFieldWidget` (`List<String>`, add/remove, contrôleur d'ajout
  éphémère LOCAL stable), `ZRowChipsFieldWidget` (mono-choix `ChoiceChip`), `ZRatingFieldWidget`
  (`num`, `IconButton` étoiles ≥48), `ZSliderFieldWidget` (`num` borné `ZSliderConfig`),
  `ZColorFieldWidget` (**`int` ARGB 32 bits `0xAARRGGBB`** documenté ; palette DÉRIVÉE HSV, aucun
  littéral de couleur → FR-26 respecté). Toutes value-in-slice, `Semantics` + cibles ≥ 48 dp, RTL
  directionnel exclusif, thème injecté.
- **AC12 (L-2)** : garde de pureté relâchée **par symbole via `show`** (allowlist
  `TextInputFormatter`/`FilteringTextInputFormatter`/`TextInputType`) ; `services.dart` **nu** ou
  symbole **hors allowlist** (`Clipboard`…) **toujours rejeté** (tests bidirectionnels a/b/c/d).
  Champ nombre : `inputFormatters` (int `digitsOnly` ; décimal `[0-9.\-]`) filtrent la saisie
  non-numérique (test comportemental : `'a1b2c3' → '123'`, `'12x.5y' → '12.5'`).
- **AC14 (0-default)** : `familyOf` reste un `switch` **exhaustif SANS `default:`** ; partition des
  **39** types re-vérifiée par test (13 base + 1 hidden + 5 feuilles + 12 registryOrFallback + 8
  unsupported). `stepper`/`file`/`image`/`document` + subItems/dynamicItem/signature/widget
  **restent en repli**.
- **AC13 (catalogue a11y)** : formulaire catalogue (5 feuilles + 1 type registre servi par démo) →
  `androidTapTargetGuideline` + `textContrastGuideline` verts, `Semantics` sur chaque contrôle,
  RTL sans overflow, `SemanticsHandle` disposé.
- **AC15 (SM-1/UJ-2 préservés)** : suite E3-3a (sm1_full_form, uj2_*, controller_stability,
  mid_cursor, external_value_sync, keyed_subtree_guard, validation_targeted_dispatch) **verte** à
  travers le dispatcher étendu ; `find.byType(Form) → findsNothing` sous le catalogue avancé ;
  aucune famille -1 n'introduit de rebuild global (rendu sous l'unique `ZFieldListenableBuilder`).
- **AC16 (vérif verte + gates + graphe)** : voir Debug Log.

**Décisions d'ambiguïté (-1)** :
- **`kind` `custom`** : résolu par `field.type.name` (`'custom'`) — pas de discriminant fin
  per-sous-type (ZFieldSpec n'expose pas de slot `extra`/discriminant générique). Contrat app :
  enregistrer codec (`ZTypeRegistry`) + widget (`ZWidgetRegistry`) sous le **même `kind`**. Un
  discriminant plus fin est une évolution additive future.
- **Encodage `color`** : **`int` ARGB 32 bits** (`0xAARRGGBB`, alpha en poids fort) — stable,
  sérialisable, additif (cohérent AD-3/AD-10).
- **`tags` et le contrat E3-2** : `familyUsesTextController` **inchangé** ; le contrôleur d'ajout
  vit dans le `State` du widget `tags` (éphémère, ≠ valeur de champ) → l'hôte n'alloue rien pour
  `tags`, aucune régression de stabilité.

### File List

**Créés (lib) :**
- `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_tags_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_row_chips_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_rating_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_slider_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart`

**Modifiés (lib) :**
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (familles + `familyOf`)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (dispatch + résolution registre)
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (`widgetRegistry`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` (`inputFormatters`)
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` (`ZSliderConfig`/`ZRatingConfig`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clés -1)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports -1)

**Créés (test) :**
- `packages/zcrud_core/test/presentation/edition/z_widget_registry_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_advanced_leaves_test.dart`
- `packages/zcrud_core/test/presentation/edition/number_input_formatter_test.dart`
- `packages/zcrud_core/test/presentation/edition/catalogue_a11y_test.dart`

**Modifiés (test) :**
- `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart` (partition -1 étendue)
- `packages/zcrud_core/test/purity/presentation_purity_test.dart` (relâchement L-2 + garde bidirectionnelle)

---

### Dev Agent Record — sous-story E3-3b-2 (sous-listes / dynamicItem)

**Skill / chemin pris** : `bmad-dev-story` chargé via le tool `Skill` (workflow injecté), config résolue
via `resolve_customization.py` (RC=0). Modèle : hérité de l'orchestrateur.

**Agent Model Used** : claude-opus-4-8.

**Debug Log (rejoué réellement sur disque)** :
- `flutter analyze lib test` (zcrud_core) → **No issues found** (RC=0).
- `melos run analyze` → **14/14** packages No issues found (RC=0).
- `flutter test` (zcrud_core) → **297** tests **All passed** (RC=0 ; **+10** vs 287 baseline -1).
- `melos run test` (workspace) → **418** tests RC=0 (zcrud_core 297 · zcrud_generator 80 · zcrud_get 17 ·
  zcrud_annotations 8 · zcrud_riverpod 8 · zcrud_provider 8).
- `melos run verify` → **RC=0** (graph_proof · gate_melos · gate_reflectable · gate_secret_scan ·
  gate_codegen · gate_compat · verify_serialization). `graph_proof` : **out-degree(zcrud_core)=0**,
  **ACYCLIQUE OK**, **CORE OUT=0 OK**, **14 nœuds**. **0 `.g.dart` committé.**

**Completion Notes (sous-story -2)** — PÉRIMÈTRE STRICT -2 : familles imbriquées `subList` (`subItems`)
+ `dynamicItem` (mini-CRUD imbriqué). **NON traité (hors -2)** : signature/widget libre (= -3) → restent
`unsupported` (repli) ; `stepper` (E3-5) + `file`/`image`/`document` (E3-3c) restent `unsupported`.

- **AC8 (subList — POINT DE VIGILANCE AD-2 N°1)** : `ZSubListFieldWidget` édite une
  `List<Map<String,dynamic>>` — add/remove/**reorder** (monter/descendre). Chaque item a son **propre
  `ZFormController`** (slice imbriqué) et une **place stable** `KeyedSubtree(ValueKey(itemId))`. Écriture
  de la liste agrégée dans la tranche parente via `onChanged→setValue`.
- **SM-1 IMBRIQUÉ (critique, prouvé)** : le conteneur est monté par `ZFieldWidget` **AVANT** la
  souscription à la tranche parente (comme `hidden`/`unsupported`) → il écoute un **canal STRUCTUREL**
  (add/remove/reorder via `setState`), **jamais** la valeur des sous-champs. L'agrégation vers le parent
  se fait par un **listener sur chaque slice imbriqué** (hors voie de rebuild). **Preuves (compteurs)** :
  (a) 30 frappes dans un sous-champ → **exactement 1** clé de rebuild bouge (le sous-champ courant, +30) ;
  les 3 autres sous-champs (même item + autre item) **strictement inchangés** ; (b) frappe imbriquée →
  **host parent (subList) inchangé**, **sibling texte inchangé**, **build structurel racine inchangé**,
  valeur bien agrégée dans la tranche parente. Focus imbriqué conservé à chaque frappe.
- **Réordonnancement préserve état/focus** : monter/descendre réutilise les mêmes `_SubItem` (mêmes clés)
  → Element/State réutilisés ; test : focus + texte de l'item déplacé **préservés** après déplacement.
- **Dispose des items retirés (pas de fuite)** : `removeAt` détache les listeners **puis** `dispose()` le
  `ZFormController` de l'item retiré ; `State.dispose` dispose tous les items restants. Test : retrait de
  l'item du milieu → les autres gardent leur texte (place stable par clé), aucune exception.
- **AC9 (dynamicItem)** : `ZDynamicItemFieldWidget` = variante cardinalité ≤ 1 (add/edit/clear), `Map?`
  en tranche, même invariant SM-1 imbriqué (monté hors voie de rebuild, agrégation par listener). Test :
  add → `Map` ; edit sous-champ → maj ; clear → `null` ; valeur initiale `Map` → item pré-rempli.
- **AC14 (0-default préservée)** : `familyOf` reste un `switch` **exhaustif SANS `default:`** ; `subItems`
  → `EditionFamily.subList`, `dynamicItem` → `EditionFamily.dynamicItem` (quittent `unsupported`).
  Nouvelle partition des **39** : 13 base + 1 hidden + **7** feuilles (5 + subList + dynamicItem) + 12
  registryOrFallback + **6** unsupported (`signature`/`widget`/`stepper`/`file`/`image`/`document`).
- **AC13 (catalogue a11y enrichi -2)** : `catalogue_a11y_test` étendu avec `subItems` + `dynamicItem` →
  `androidTapTargetGuideline` + `textContrastGuideline` verts, RTL sans overflow. Test dédié subList :
  cibles ≥ 48 dp (IconButton monter/descendre/supprimer, bouton add) + `Semantics` conteneur, RTL.
- **AC15 (SM-1/UJ-2 préservés)** : suite E3-3a/-3b-1 **verte** à travers le dispatcher étendu ;
  `find.byType(Form) → findsNothing` sous subList/dynamicItem ; aucune famille -2 n'introduit de rebuild
  global (mini-CRUD hors voie de rebuild parente).
- **AC16 (vérif verte + gates + graphe)** : voir Debug Log.

**Décisions d'ambiguïté (-2)** :
- **Sous-schéma des items (Ambiguïté #3)** : config additive **`ZSubListConfig{itemFields: List<ZFieldSpec>,
  reorderable}`** (`const`, pur-données, AD-4) dans un fichier dédié `z_sub_list_config.dart` (évite le
  cycle d'import `z_field_config`↔`z_field_spec`). L'édition d'un item **réutilise `ZFieldWidget`** (le
  dispatcher — machinerie SM-1 par champ), pas une réimplémentation.
- **Recoupement E4-5 (Ambiguïté #4)** : ces widgets = **champ d'édition imbriqué** (E3) ; l'**écran
  autonome** `ZSubListScreen` reste **E4-5**. Non dupliqué ; frontière documentée en docstring. Le
  sous-schéma `const` (`ZSubListConfig`) est la **brique commune** réutilisable côté E4-5.
- **Décision d'intégration AD-2** : `subList`/`dynamicItem` sont traités **AVANT** le
  `ZFieldListenableBuilder` (comme `hidden`/`unsupported`) — nécessaire pour que l'écriture per-frappe de
  la tranche parente ne reconstruise **pas** le conteneur (sinon tous les items reconstruiraient). Le
  `switch` de `_dispatch` conserve des cases `subList`/`dynamicItem` (→ `SizedBox.shrink`, jamais atteints)
  pour rester exhaustif sans `default:`.
- **Encodage** : la valeur = `List<Map<String,dynamic>>` (subList) / `Map<String,dynamic>?` (dynamicItem)
  — sérialisable, additif, compatible codegen `subItems` (E2-5). Lecture **défensive** (`null`/type
  inattendu → `[]`/`null`, cohérent AD-10).

**File List (sous-story -2)** :

*Créés (lib)* :
- `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_dynamic_item_field_widget.dart`

*Modifiés (lib)* :
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (`subList`/`dynamicItem` + `familyOf`)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (dispatch pré-slice subList/dynamicItem)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clés addItem/removeItem/moveItemUp/Down/clearItem)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports -2)

*Créés (test)* :
- `packages/zcrud_core/test/presentation/edition/z_sub_list_test.dart`

*Modifiés (test)* :
- `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart` (partition -2 : subList/dynamicItem hors unsupported)
- `packages/zcrud_core/test/presentation/edition/catalogue_a11y_test.dart` (catalogue enrichi subItems/dynamicItem)

**État global de la story** : **-2 done (review)**.

---

### Dev Agent Record — sous-story E3-3b-3 (signature / widget libre)

**Skill / chemin pris** : `bmad-dev-story` chargé via le tool `Skill` (workflow injecté dans le
tour), config résolue via `resolve_customization.py` (RC=0, `persistent_facts` = project-context).
Modèle : hérité de l'orchestrateur.

**Agent Model Used** : claude-opus-4-8.

**Debug Log (rejoué réellement sur disque)** :
- `flutter analyze lib test` (zcrud_core) → **No issues found** (RC=0).
- `melos run analyze` → **14/14** packages No issues found (RC=0).
- `flutter test` (zcrud_core) → **311** tests **All passed** (RC=0 ; **+14** vs 297 baseline -2 :
  z_signature_test 9 + z_free_widget_test 4 + dispatch freeWidget-fallback 1).
- `melos run test` (workspace) → **432** tests RC=0 (zcrud_core 311 + satellites inchangés 121).
- `melos run verify` → **RC=0** (graph_proof · gate_melos · gate_reflectable · gate_secret_scan ·
  gate_codegen · gate_compat · verify_serialization). `graph_proof` : **out-degree(zcrud_core)=0**,
  **ACYCLIQUE OK**, **CORE OUT=0 OK**, **14 nœuds**. **0 `.g.dart` committé.** `melos list` = **14**.
- Correctif intra-story : (a) `PointMode`/`canvas.drawPoints` (point isolé) remplacé par
  `canvas.drawCircle` pour éviter l'import `dart:ui` direct (banni par la garde de pureté
  `presentation/`) ; (b) le test a11y vérifiait `getSize(IconButton) ≥ 48` (boîte visuelle = 40 dp
  en `MaterialTapTargetSize.padded`) → remplacé par `meetsGuideline(androidTapTargetGuideline)` qui
  valide la **cible tactile sémantique** ≥ 48 dp (le vrai critère AD-13).

**Completion Notes (sous-story -3)** — PÉRIMÈTRE STRICT -3 : rendu custom `signature` (capture
gestuelle) + `freeWidget` (widget libre via registre). **NON touché (hors -3)** : registre/feuilles
(= -1), sous-listes (= -2), `stepper` (E3-5), `file`/`image`/`document` (E3-3c) restent
`unsupported` (repli contrôlé).

- **AC10 (signature)** : `ZSignatureFieldWidget` (StatefulWidget) — capture via `GestureDetector`
  (`onPanStart/Update/End`) + `CustomPaint`/`_SignaturePainter` **natif Flutter**, AUCUNE dépendance
  lourde (graphe CORE OUT=0 inchangé, aucune arête ajoutée). **Encodage STABLE documenté** : valeur
  = `Map` VERSIONNÉE `{formatVersion:1, strokes:[[x0,y0,x1,y1,…], …]}`, coordonnées **normalisées
  `[0,1]`** relatives à la boîte de capture (résolution-indépendantes, sérialisables, additives —
  AD-3/AD-10) ; **PAS de bytes image lourds**. Vide/effacé ⇒ `null`. Lecture **défensive** (type
  inattendu ⇒ aucun stroke, jamais de throw). **clear** → tranche `null` ; **undo** → retire le
  dernier trait. Value-in-slice à propriété locale (State amorcé une fois depuis `initialValue`,
  écriture agrégée hors voie de rebuild du geste — AD-2). a11y : `Semantics(container, label « zone
  de signature », value signé/vide, readOnly)` = **alternative non gestuelle** ; boutons clear/undo
  `IconButton` (cible tactile ≥ 48 dp validée par guideline) + tooltips l10n ; insets/`Row`
  **directionnels** ; couleur de tracé/bordure **dérivée du thème** (FR-26, aucun littéral).
  Tests : dispatch dédié · tracé → `Map` de strokes normalisés `[0,1]` · **jsonEncode round-trip**
  (sérialisable) · clear → `null` · undo → 1 trait retiré · valeur initiale `Map` → pré-rempli ·
  lecture défensive (`'corrompu'`/`null`/`{strokes:42}` → vide, pas de throw) · a11y · RTL.
- **AC11 (freeWidget / `widget` libre)** : `ZFreeWidgetFieldWidget` (StatelessWidget) **CONSOMME**
  `ZWidgetRegistry` (E3-3b-1, NON réimplémenté) — résout `kind = field.type.name` (`'widget'`) via
  `ZcrudScope.widgetRegistry` ; builder trouvé → widget hôte rendu **dans** la frontière de rebuild
  (value-in-slice, `onChanged → setValue`) ; **sinon repli `ZUnsupportedFieldWidget`** (jamais de
  throw, AD-10). Le cœur reste agnostique (aucun import satellite). Tests : registre peuplé → host
  lit/écrit la tranche (rebuild granulaire) · **sans registre** → repli · **registre sans le kind
  `widget`** → repli · démo prouve le seam sans tirer E6/E11a.
- **AC14 (0-default préservée + frontières)** : `familyOf` reste un `switch` **exhaustif SANS
  `default:`** ; `signature`→`EditionFamily.signature`, `widget`→`EditionFamily.freeWidget`
  (quittent `unsupported`). Partition des **39** re-vérifiée par test : 13 base + 1 hidden + **8**
  feuilles (5 simples + subList + dynamicItem + signature) + **1** freeWidget + 12 registryOrFallback
  + **4** unsupported (`stepper`/`file`/`image`/`document`). `stepper` (E3-5) et
  `file`/`image`/`document` (E3-3c) **restent en repli contrôlé** (jamais un widget avancé usurpé).
- **AC13 (catalogue a11y enrichi -3)** : `catalogue_a11y_test` étendu avec `signature` +
  `widget` libre (servi par une démo enregistrée) → `androidTapTargetGuideline` +
  `textContrastGuideline` verts, `Semantics` présents, RTL sans overflow, `SemanticsHandle` disposé.
- **AC15 (SM-1/UJ-2 préservés)** : suite E3-3a/-3b-1/-3b-2 **verte** à travers le dispatcher étendu ;
  `find.byType(Form) → findsNothing` sous le catalogue (dont signature/freeWidget) ; signature =
  value-in-slice rendu sous l'unique `ZFieldListenableBuilder` (rebuild granulaire, gesture hors voie
  de rebuild) ; freeWidget = value-in-slice → aucune famille -3 n'introduit de rebuild global.
- **AC16 (vérif verte + gates + graphe)** : voir Debug Log.

**Décisions d'ambiguïté (-3)** :
- **Encodage `signature` (Ambiguïté #5)** : **points normalisés** (pas de bytes image) — `Map`
  versionnée `{formatVersion, strokes:[[x,y,…]]}`, coordonnées `[0,1]` → stable, sérialisable,
  résolution-indépendante, additive (AD-3/AD-10). Choisi sur « bytes image lourds » (proscrit par la
  spec : « pas de bytes image lourds dans la tranche »).
- **Rendu du point isolé** : `drawCircle` (disque) au lieu de `PointMode.points`/`drawPoints` — évite
  l'import `dart:ui` direct banni par la garde de pureté `presentation/` (aucun relâchement de garde
  nécessaire en -3, contrairement au L-2 de -1).
- **`freeWidget` vs `registryOrFallback`** : `widget` obtient une **famille dédiée**
  `EditionFamily.freeWidget` (sémantique « widget libre explicite ») mais **partage le seam**
  `ZWidgetRegistry` (même `kind = type.name`, même repli). `ZFreeWidgetFieldWidget` encapsule la
  résolution (widget exportable/testable) sans dupliquer le registre ; `registryOrFallback` conserve
  son chemin inline `_dispatchRegistry` (-1) inchangé → aucune régression sur les tests -1.
- **`signature` value-in-slice à propriété locale** : rendu **dans** le `ZFieldListenableBuilder`
  (comme color/rating) mais State local amorcé une fois via `initialValue` (le geste ne doit pas être
  écrasé par les rebuilds du slice) — cohérent AD-2 (rebuild granulaire, focus/tracé préservés).

**File List (sous-story -3)** :

*Créés (lib)* :
- `packages/zcrud_core/lib/src/presentation/edition/families/z_signature_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_free_widget_field_widget.dart`

*Modifiés (lib)* :
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (`signature`/`freeWidget` + `familyOf`)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (dispatch `signature`/`freeWidget` + imports)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clés signatureArea/signatureSigned/signatureEmpty/clearSignature/undoSignature)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports -3)

*Créés (test)* :
- `packages/zcrud_core/test/presentation/edition/z_signature_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_free_widget_test.dart`

*Modifiés (test)* :
- `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart` (partition -3 : signature/freeWidget hors unsupported ; freeWidget repli sans registre)
- `packages/zcrud_core/test/presentation/edition/catalogue_a11y_test.dart` (catalogue enrichi signature + widget libre)

**État global de la story** : **E3-3b COMPLET : -1/-2/-3 done (review)**.
