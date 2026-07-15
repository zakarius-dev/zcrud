---
baseline_commit: e8e94b380a8081f0674f69f1b817b1508a4ea4ea
---
# Story ES-8.1 : UI de tags + intégrité référentielle (`ZTagEditor` / `ZTagChips`)

Status: review

<!-- Skill : bmad-create-story (tool Skill, préfixe bmad-*) — INVOQUÉ RÉELLEMENT (pas de fallback disque). -->
<!-- Sprint-status NON touché par cette étape (édition ciblée réservée à l'orchestrateur). -->

## Story

As a **utilisateur**,
I want **créer/appliquer des tags via un éditeur + des chips à palette injectable, avec confirmation des
suggestions IA et purge des références orphelines à la suppression**,
so that **organiser mes flashcards par tags sans doublons ni références cassées**.

## Contexte & décision de séquencement (LIRE EN PREMIER)

**Périmètre validé sur disque** — ES-8.1 écrit **uniquement** `packages/zcrud_study/` (présentation :
`z_tag_editor.dart`, `z_tag_chips.dart` + barrel + tests). C'est, comme ES-6.1 / ES-7.1, un **ADAPTATEUR
MINCE de PRÉSENTATION** qui **COMPOSE** des primitives de domaine **DÉJÀ LIVRÉES** — il n'en réimplémente
aucune :

- `ZFlashcardTag` (`{id, title, colorKey}`, entité first-class, ES-2.3) et `ZSuggestedTag` (`{title,
  colorKey}`, value object éphémère SANS `id` proposé par un port IA) —
  `packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart` / `z_suggested_tag.dart`.
- `normalizeTagTitle(String?)` + `dedupeByNormalizedTitle<T>({titleOf})` (trim + collapse `\s+` + lowercase,
  dédoublonnage stable — ES-1.2) — `.../normalize_tag_title.dart`.
- `remapColorKey({palette, rawColorKey, seedTitle})` + `ZColorPalette` (registre borné injectable,
  `.defaultStudy()`, remap FNV-1a déterministe — ES-1.2/ES-2.3) — `.../remap_color_key.dart` /
  `z_color_palette.dart`.
- `orphanTagIds({referencedTagIds, existingTagIds}) → Set<String>` (**DÉTECTION** pure des références
  orphelines — ES-2.3) — `.../tag_referential_integrity.dart`.
- Côté `zcrud_core` : `zResolveColorKeyOrSlot(context, colorKey, {slotIndex}) → ZColorPair` (résolution
  **totale** `colorKey → couleur` via `ZcrudScope.colorKeyResolver` puis repli slot ; contraste M3 garanti),
  `ZColorPair`, `ZcrudTheme.of` (tokens `gapS`/`labelColor`…) —
  `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart` / `z_theme.dart`.

Toutes ces primitives sont **déjà exportées** par `package:zcrud_study_kernel/zcrud_study_kernel.dart` et
`package:zcrud_core/zcrud_core.dart`, et **déjà couvertes par des tests kernel** (`tag_referential_integrity_test.dart`,
`normalize_tag_title_test.dart`, `remap_color_key_test.dart`, `z_color_palette_test.dart`). ⇒ **R20/R24 : les
AC d'ES-8.1 NE RE-TESTENT PAS ces primitives** ; ils ancrent sur les **lignes PROPRES aux widgets**
(le fil palette→chip, la garde anti-doublon au point de création, la composition purge-sur-suppression, la
dérivation du compteur d'usage, le cycle de vie du controller détenu).

**AD-1 — AUCUNE nouvelle arête de graphe attendue (différence notable vs ES-7.1).** `zcrud_study` dépend
**déjà** de `zcrud_core`, `zcrud_study_kernel`, `zcrud_annotations`, `zcrud_mindmap` (cf.
`packages/zcrud_study/pubspec.yaml`, vérifié). Les widgets tags consomment `ZFlashcardTag`/`normalizeTagTitle`/
`remapColorKey`/`ZColorPalette`/`orphanTagIds` (**tous** `zcrud_study_kernel`, arête existante) +
`zResolveColorKeyOrSlot`/`ZColorPair`/`ZcrudTheme` (**tous** `zcrud_core`, arête existante). ⇒ **`pubspec.yaml`
NE CHANGE PAS**, `graph_proof` reste **42 arêtes / 20 nœuds** (0 delta). Si le dev croit devoir ajouter une
arête, **c'est une erreur de conception** : re-vérifier que le symbole visé est bien exporté par un package
déjà en dépendance.

**DÉPENDANCE envers ES-8.2 : NON (aucune).** ES-8.2 (`ZAnnotationToolbar`/`ZAnnotationPanel`, WCAG) écrit
**`zcrud_document/presentation`** — package **DISJOINT**, **aucune** arête `zcrud_study ↔ zcrud_document`
(vérifié : `zcrud_study/pubspec.yaml` ne référence pas `zcrud_document`, et l'inverse serait un cycle
proscrit). ES-8.1 ne consomme **aucun** symbole qu'ES-8.2 doit livrer. ⇒ parallélisation **CLASSIQUE**
(packages strictement indépendants — même pas le cas « dépendant ∥ dépendance » de R23). Le SEUL point de
contact théorique reste `zcrud_core` : ES-8.1 ne l'**écrit pas** (lecture seule de `zResolveColorKeyOrSlot`).
La chaîne sérielle `zcrud_study` (ES-7.1 → ES-8.1 → ES-9.*) impose néanmoins : **ES-8.1 vole SEULE sur
`zcrud_study`** — jamais en même temps qu'une autre story écrivant ce package (rétro ES-6 §8 / ES-7 §9).

> ⚠️ **Frontière de périmètre honnête (R24 — ne pas sur-promettre).** L'AC métier de l'epic dit « ses
> références orphelines sont **purgées** … et `usageCount` reste cohérent ». La **purge PERSISTÉE** (retirer
> l'`id` du tag des `tagIds` de **toutes** les cartes dans le store) est le travail du **repository**
> (`ZStudyRepository`/adapter — **ES-3**, hors périmètre M d'ES-8.1). Ce qu'ES-8.1 possède et prouve :
> l'UI **n'émet jamais** un modèle de références portant une référence orpheline **après** une suppression —
> la composition purge-sur-suppression du widget (via `orphanTagIds`) garantit `orphanTagIds(refsÉmises,
> existantsAprès) == {}`. La persistance de cette purge est **déléguée à l'app/au repository via callback**
> (`onDeleteTag`). Voir Dev Notes › Dettes.

## Acceptance Criteria

Chaque AC est à **POUVOIR DISCRIMINANT** (R12) : il **rougit** quand on neutralise la ligne de prod qu'il
protège (cf. § « Injections R3 prévues »). **Ancrage R20/R24** (leçon centrale ES-6/ES-7) : ES-8.1 compose des
primitives kernel **déjà testées** — les AC ci-dessous ancrent sur les **lignes PROPRES aux widgets**
(`ZTagEditor`/`ZTagChips`), **jamais** sur la garantie de la primitive réutilisée (ne PAS re-tester
`orphanTagIds([b],[a])=={b}` ni `normalizeTagTitle('  A ')=='a'` — ce sont des tests kernel), **ni** sur un
artefact adjacent stable présent dans toutes les branches.

**AC1 — Palette INJECTABLE effectivement filée jusqu'à la couleur du chip (`remapColorKey` → `zResolveColorKeyOrSlot`).**
**Given** un `ZFlashcardTag` de `colorKey` **inconnue** de la palette (donc soumise au remap) et **deux**
palettes injectées **différentes**,
**When** `ZTagChips` rend le chip du tag,
**Then** la couleur de fond du chip est **exactement** `zResolveColorKeyOrSlot(context,
remapColorKey(palette, rawColorKey: tag.colorKey, seedTitle: tag.title), slotIndex: palette.indexOf(<clé
remappée>))` — c.-à-d. le widget **file la palette injectée** à travers `remapColorKey` puis le résolveur du
cœur ; **And** changer la palette injectée **change** la couleur résolue du chip (preuve que la palette n'est
**pas** codée en dur ni ignorée).
*(Ancrage R20 : l'assertion porte sur le FIL palette→chip PROPRE à `ZTagChips`, pas sur la correction de
`remapColorKey`/`ZColorPalette.resolveKey` — déjà testée au kernel. Injection R3-I1 : ignorer la palette
injectée / clé codée en dur ⇒ RC=1.)*

**AC2 — `normalizeTagTitle` empêche les DOUBLONS au point de CRÉATION (garde propre à l'éditeur).**
**Given** un ensemble de tags existants contenant `"Droit Douanier"` et un `ZTagEditor` monté dessus,
**When** l'utilisateur saisit `"  droit   douanier "` (même titre **normalisé**) et valide la création,
**Then** **aucun** nouveau tag n'est émis (`onCreateTag` **non appelé**) et l'éditeur **applique/sélectionne
le tag EXISTANT** (dédoublonnage par titre normalisé) ; **And** saisir un titre de forme normalisée **inédite**
émet bien un nouveau tag exactement **une** fois.
*(Ancrage R20 : l'assertion porte sur la GARDE anti-doublon au call-site de création DANS `ZTagEditor`, pas
sur `normalizeTagTitle`/`dedupeByNormalizedTitle` en tant que fonctions. Injection R3-I2 : retirer la garde
(émettre sans normaliser/dédupliquer) ⇒ doublon émis ⇒ RC=1.)*

**AC3 — Intégrité référentielle STRUCTURELLE : la suppression n'émet AUCUNE référence orpheline.**
**Given** un tag `T` (`id == 't'`) appliqué à des cartes dont les `tagIds` référencent `t`, et un ensemble de
tags existants,
**When** l'utilisateur supprime `T` via `ZTagEditor` (`onDeleteTag`),
**Then** le modèle de références que le widget **ÉMET** au callback ne contient **plus aucune** référence à
`t` — prouvé en capturant les références émises et en vérifiant `orphanTagIds(referencedTagIds: <refs
émises aplaties>, existingTagIds: <ids existants APRÈS retrait de t>) == {}` **et** que `t` est absent de
**chaque** liste de `tagIds` émise ; **And** l'`id` `t` est retiré du registre des tags existants remonté.
*(Ancrage R24 : l'assertion porte sur la LIGNE de composition purge-sur-suppression PROPRE à `ZTagEditor`
(retrait effectif de `t` des références émises), **pas** sur `orphanTagIds` comme boîte noire, **ni** sur un
libellé « supprimé » qui survivrait quelle que soit la purge. Injection R3-I3 : émettre les références
**inchangées** (purge court-circuitée) ⇒ `t` reste orphelin ⇒ RC=1.)*

**AC4 — `usageCount` DÉRIVÉ et COHÉRENT après purge (jamais un compteur stocké périmé).**
**Given** un tag et l'ensemble des cartes le référençant,
**When** `ZTagChips`/`ZTagEditor` affiche le nombre d'usages du tag, y compris **après** une suppression/purge,
**Then** le compteur affiché est **DÉRIVÉ** du nombre réel de cartes référençant le tag **au moment du rendu**
(`referencingCardsOf(tag).length`, recalculé), **jamais** un champ `usageCount` stocké/figé (qui n'existe pas
sur `ZFlashcardTag` — AD-19) ; **And** après purge d'un tag, le compteur du tag purgé n'est plus affiché (tag
retiré) et les compteurs des autres tags restent exacts.
*(Ancrage : l'assertion porte sur la DÉRIVATION au rendu PROPRE au widget. Injection R3-I4 : afficher une
valeur figée passée en props au lieu de la dérivation ⇒ décalage après purge ⇒ RC=1.)*

**AC5 — Réactivité Flutter-native : controller SAISIE détenu (initState/dispose), notifier LOCAL, SM-1.**
**Given** un `ZTagEditor` **sans** controller de saisie injecté, subissant une **tempête de rebuilds** (≥ 5
rebuilds du parent) puis démonté,
**When** on observe le controller de champ de saisie (`TextEditingController`/`ZFormController`) **détenu** par
l'éditeur,
**Then** il est créé **UNE seule fois** (créé en `initState`, `identical` avant/après la tempête, **jamais**
dans `build`) et **disposé exactement une fois** au démontage ; **And** un controller **injecté** par
l'appelant est **UTILISÉ tel quel** et **JAMAIS disposé** ; **And** l'état de saisie/sélection vit dans un
`ValueNotifier`/`ValueListenableBuilder` **LOCAL** (aucun `setState` de page, aucun gestionnaire d'état —
`flutter_riverpod`/`get`/`provider` interdits) ⇒ frappe dans l'éditeur = **zéro** rebuild d'un widget frère
instrumenté (SM-1), zéro perte de focus.
*(Ancrage R20 : identité de l'objet DÉTENU par `ZTagEditor`, capturée par le test — pas la garantie interne du
`TextEditingController`. Injection R3-I5 : créer le controller dans `build()` ⇒ non-`identical` ⇒ RC=1 ;
R3-I6 : lifter l'état au parent via `setState` ⇒ frère reconstruit ⇒ RC=1.)*

**AC6 — A11y AD-13/FR-26 : la couleur n'est JAMAIS le seul canal ; ≥ 48 dp ; Semantics/labels INJECTÉS ; directionnel ; thème injecté.**
**Given** un `ZTagChips`/`ZTagEditor` rendu,
**When** on inspecte un chip et les cibles interactives,
**Then** le **titre textuel** du tag est **TOUJOURS** rendu à côté de la pastille de couleur (**couleur jamais
seul canal** — WCAG/NFR-S6) ; **And** toute cible interactive (chip supprimable, bouton d'ajout/confirmation)
est **≥ 48 dp** ; **And** les libellés sémantiques (supprimer le tag, ajouter, confirmer la suggestion) et le
`hint`/label du champ sont **INJECTÉS** (aucun `'Supprimer'`/`'Ajouter'`/`'Tag'` codé en dur) ; **And**
padding/alignement sont **directionnels** (`EdgeInsetsDirectional`, `TextAlign.start`, jamais `.only(left:)`/
`Alignment.centerLeft`) ; **And** couleurs/espacements viennent de `zResolveColorKeyOrSlot`/`ZcrudTheme.of`
(repli `Theme.of`) — **aucune** `Color`/valeur d'espacement codée en dur, aucun `Colors.*`/hex.
*(Injections R3-I7 : rendre le chip **sans** son titre textuel (couleur seule) ⇒ RC=1 ; R3-I8 : cible < 48 dp
⇒ RC=1 ; R3-I9 : label sémantique codé en dur ⇒ label observé ≠ label injecté ⇒ RC=1.)*

**AC7 — Confirmation EXPLICITE d'une suggestion IA (`ZSuggestedTag`), routée par la MÊME garde anti-doublon.**
**Given** un `ZSuggestedTag` (value object **sans `id`**, proposé par un port IA) présenté par `ZTagEditor`,
**When** l'utilisateur **confirme** la suggestion,
**Then** elle n'est appliquée **qu'après** action explicite de confirmation (jamais auto-appliquée à
l'affichage) et sa matérialisation en tag passe par **exactement la même garde `normalizeTagTitle`/dédup**
qu'AC2 : une suggestion dont le titre normalisé **duplique** un tag existant **n'émet pas** de doublon (elle
applique l'existant) ; **And** une suggestion **rejetée** n'émet rien et disparaît de la zone de suggestions.
*(Ancrage : le call-site de confirmation PROPRE à `ZTagEditor`. Injection R3-I10 : auto-appliquer la
suggestion à l'affichage (sans confirmation) ⇒ tag émis sans geste ⇒ RC=1 ; R3-I11 : confirmer en
court-circuitant la garde de dédup ⇒ doublon émis ⇒ RC=1.)*

## Tasks / Subtasks

- [x] **T1 — `ZTagChips` (affichage) (AC1, AC4, AC6)**
  - [x] Créer `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart`.
  - [x] Signature : `tags` (`List<ZFlashcardTag>`), `palette` (`ZColorPalette`, **injectée** — défaut
        recommandé documenté `ZColorPalette.defaultStudy()`, jamais verrouillée), `referencingCardsCountOf`
        (`int Function(ZFlashcardTag)` **DÉRIVÉ** — AC4, jamais un champ figé), `onTagTap?`/`onTagRemoved?`
        (callbacks `null` = capacité absente, AD-4), libellés sémantiques **injectés**
        (`removeTagSemanticLabel`/`tagSemanticLabel`), `showUsageCount` (bool).
  - [x] Chaque chip : **pastille de couleur** = `zResolveColorKeyOrSlot(context, remapColorKey(palette,
        rawColorKey: tag.colorKey, seedTitle: tag.title), slotIndex: palette.indexOf(remapColorKey(...)))`
        (AC1) **+ TITRE textuel TOUJOURS visible** (`Text(tag.title, textAlign: TextAlign.start)` — AC6,
        couleur jamais seul canal). `usageCount` dérivé via `referencingCardsCountOf(tag)` (AC4).
  - [x] Cibles ≥ 48 dp (`ConstrainedBox`), `Semantics`/`tooltip` labels **injectés**, `EdgeInsetsDirectional`,
        `ListView.builder`/`Wrap` (jamais `ListView(children:[...])`), couleurs/gaps `ZcrudTheme.of`.
- [x] **T2 — `ZTagEditor` (création + dédup + suppression/purge) (AC2, AC3, AC5, AC6)**
  - [x] Créer `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart`.
  - [x] Signature : `existingTags` (`List<ZFlashcardTag>`), `palette` (injectée), `onCreateTag`
        (`void Function(ZFlashcardTag)` — matérialisation **sans id** côté widget : le widget émet un
        `ZFlashcardTag(title, colorKey)` **id `null`**, l'`id` est attribué par le **repository**, AD-14),
        `onApplyExisting`/`onDeleteTag` (`void Function(ZFlashcardTag)`), `referencedTagIdsOf`/apport des cartes
        pour la purge (`List<List<String>> Function()` ou modèle de références + `onReferencesPurged`),
        `inputController?` (injecté, NON disposé), labels **injectés**.
  - [x] `StatefulWidget` **uniquement** pour : (a) cycle de vie du `TextEditingController`/`ZFormController`
        **possédé** (créé `initState` ssi non injecté, disposé `dispose` ssi possédé — AC5) ;
        (b) `ValueNotifier` **local** de l'état saisie/sélection. `didUpdateWidget` : transitions
        possédé↔injecté défensives (jamais recréé en rebuild ordinaire).
  - [x] **Création (AC2)** : au submit, `final norm = normalizeTagTitle(input)` ; si un `existingTags` a
        `normalizeTagTitle(title) == norm` ⇒ `onApplyExisting(existant)` (**pas** `onCreateTag`) ; sinon
        `onCreateTag(ZFlashcardTag(title: input, colorKey: <clé choisie/remappée>))`. Réutiliser
        `dedupeByNormalizedTitle`/`normalizeTagTitle` du kernel — **aucune** réimplémentation.
  - [x] **Suppression/purge (AC3)** : au `onDeleteTag(T)`, calculer via `orphanTagIds` les références
        devenues orphelines et **émettre** un modèle de références où **`T.id` est retiré de chaque** `tagIds`
        (garantie `orphanTagIds(refsÉmises, existingsSansT) == {}`), puis remonter `onDeleteTag(T)` +
        `onReferencesPurged(refsNettoyées)`. La **persistance** est déléguée (repository ES-3) — le widget ne
        garantit QUE l'absence d'orphelin dans le modèle émis.
  - [x] A11y (AC6) : ≥ 48 dp, Semantics/labels injectés, directionnel, thème injecté (idem T1).
  - [x] **Aucun** import `flutter_riverpod`/`get`/`provider` ; aucun `WidgetRef`/`Get.`/`Provider.of` (AC5).
- [x] **T3 — Confirmation de suggestion IA `ZSuggestedTag` (AC7)**
  - [x] Dans `ZTagEditor` : slot `suggestions` (`List<ZSuggestedTag>`) + `onSuggestionConfirmed`/
        `onSuggestionRejected` (callbacks `null` = zone suggestions ABSENTE, AD-4). Une suggestion n'est
        matérialisée qu'au **geste de confirmation** explicite (jamais à l'affichage) et **route par la MÊME
        garde** `normalizeTagTitle`/dédup que la création (AC2) : dup normalisé ⇒ applique l'existant, jamais
        de doublon. Rejet ⇒ retire la suggestion, n'émet rien.
- [x] **T4 — Barrel (AC1, AC6)**
  - [x] Exporter `src/presentation/z_tag_chips.dart` et `src/presentation/z_tag_editor.dart` dans
        `packages/zcrud_study/lib/zcrud_study.dart`.
  - [x] ⛔ **NE PAS toucher `pubspec.yaml`** — 0 nouvelle arête (tous les symboles proviennent de
        `zcrud_core`/`zcrud_study_kernel` déjà en dépendance ; cf. AD-1 ci-dessus).
- [x] **T5 — Tests `flutter test` (R14) — `packages/zcrud_study/test/z_tag_{chips,editor}_test.dart`**
  - [x] AC1 : deux palettes injectées différentes ⇒ deux `ZColorPair` de chip distinctes ; couleur du chip ==
        `zResolveColorKeyOrSlot(...remapColorKey(paletteInjectée, ...))` (récupérée par `Element`/`find` du
        `ColoredBox`/`DecoratedBox` de la pastille). **Ne PAS** re-tester `remapColorKey` isolément.
  - [x] AC2 : `existingTags=['Droit Douanier']` ; saisir `'  droit   douanier '` ⇒ `onCreateTag` **jamais**
        appelé, `onApplyExisting` appelé avec l'existant ; saisir `'Fiscalité'` ⇒ `onCreateTag` appelé 1×.
  - [x] AC3 : cartes référençant `t` ; `onDeleteTag(T)` ⇒ capturer refs émises ; `orphanTagIds(refsÉmises,
        existantsSansT)` **vide** ; `t` absent de chaque `tagIds` émise.
  - [x] AC4 : compteur affiché == `referencingCardsCountOf(tag)` recalculé ; après purge, tag purgé absent,
        compteurs des autres exacts. Injection d'un compteur figé ⇒ RC=1.
  - [x] AC5 : controller capturé (possédé) avant tempête (6 rebuilds), `identical` après ; `isDisposed==true`
        au démontage (possédé) ; injecté ⇒ `isDisposed==false` ; frère-sonde (compteur de builds) inchangé sous
        frappe.
  - [x] AC6 : `find.text(tag.title)` présent pour chaque chip (couleur non seule) ; `ConstrainedBox`
        minWidth/minHeight ≥ 48 ; `find.bySemanticsLabel(labelInjecté)` ; scan absence `Colors.`/hex/
        `EdgeInsets.only(left`.
  - [x] AC7 : suggestion NON appliquée avant confirmation (`onSuggestionConfirmed` non déclenché à
        l'affichage) ; confirmer une suggestion dupliquant un existant ⇒ `onApplyExisting`, pas `onCreateTag` ;
        rejet ⇒ rien émis, suggestion retirée.
- [x] **T6 — Vérif verte rejouée** (cf. § dédiée) + mise à jour File List.

## Injections R3 prévues (mutation → AC rouge → restauration)

Pour chaque AC load-bearing, l'injection **fidèle** de la panne + preuve de rougissement, puis restauration
(→ vert). À exécuter réellement (RC **hors pipe**, R15).

| Ref | AC | Mutation (ligne de prod neutralisée) | Attendu |
|-----|----|--------------------------------------|---------|
| R3-I1 | AC1 | Ignorer la palette injectée (clé codée en dur / `ZColorPalette.defaultStudy()` en dur au lieu de `widget.palette`) | deux palettes ⇒ même couleur / couleur ≠ résolveur attendu → **RC=1** |
| R3-I2 | AC2 | Émettre `onCreateTag` **sans** garde `normalizeTagTitle`/dédup | doublon normalisé émis → **RC=1** |
| R3-I3 | AC3 | Émettre les références **inchangées** (purge court-circuitée : ne pas retirer `t`) | `orphanTagIds(refsÉmises, existantsSansT)` non vide → **RC=1** |
| R3-I4 | AC4 | Afficher un `usageCount` **figé** passé en props (au lieu de `referencingCardsCountOf`) | compteur décalé après purge → **RC=1** |
| R3-I5 | AC5 | Créer le controller de saisie **dans `build()`** (au lieu d'`initState`) | `identical(before, after)` faux après tempête → **RC=1** |
| R3-I6 | AC5 | Lifter l'état saisie/sélection au parent via `setState` (au lieu du `ValueNotifier` local) | frère-sonde reconstruit → **RC=1** |
| R3-I7 | AC6 | Rendre le chip **sans** son titre textuel (pastille de couleur seule) | `find.text(tag.title)` absent → **RC=1** (couleur seul canal) |
| R3-I8 | AC6 | Ramener une cible interactive à `< 48 dp` | assert taille ≥ 48 → **RC=1** |
| R3-I9 | AC6 | Coder en dur `semanticLabel: 'Supprimer'` (au lieu du label injecté) | label observé ≠ label injecté → **RC=1** |
| R3-I10 | AC7 | Auto-appliquer la suggestion à l'affichage (sans geste de confirmation) | tag émis sans confirmation → **RC=1** |
| R3-I11 | AC7 | Confirmer une suggestion en court-circuitant la garde de dédup | doublon émis → **RC=1** |

> **Pièges R20/R24 explicitement traités** :
> - NE PAS ancrer AC2/AC3 sur la correction de `normalizeTagTitle`/`orphanTagIds` (ce sont des **primitives
>   kernel déjà testées** — les re-tester ici serait POWERLESS sur le widget : la primitive masquerait un
>   court-circuit de la garde/purge du widget). Ancrer sur le **call-site DANS le widget** (R3-I2 retire la
>   garde de création ; R3-I3 court-circuite la purge d'émission) — ce sont les lignes de prod propres.
> - NE PAS ancrer AC3 sur un **libellé « supprimé »** ni sur le simple retrait du tag de la liste des tags
>   (artefacts adjacents qui survivent à une purge incomplète des **références**) — ancrer sur l'**absence
>   d'orphelin dans les références ÉMISES** (`orphanTagIds(refsÉmises, …) == {}`), la branche que la purge
>   produit (R24).
> - NE PAS ancrer AC5 sur le fait qu'un `TextEditingController` protège son texte (garantie du widget SDK) —
>   ancrer sur l'**identité du controller DÉTENU par `ZTagEditor`** (R20, miroir ES-6.1/ES-7.1).

## Dev Notes

### Architecture & invariants (NON-NÉGOCIABLES)
- **AD-1 (graphe acyclique, CORE OUT=0)** : **0 nouvelle arête**. Tous les symboles proviennent de
  `zcrud_study_kernel` (`ZFlashcardTag`, `ZSuggestedTag`, `normalizeTagTitle`, `dedupeByNormalizedTitle`,
  `remapColorKey`, `ZColorPalette`, `orphanTagIds`) et `zcrud_core` (`zResolveColorKeyOrSlot`, `ZColorPair`,
  `ZcrudTheme`) — **déjà** en dépendance de `zcrud_study`. `pubspec.yaml` INCHANGÉ ; `graph_proof` reste 42
  arêtes / 20 nœuds. [Source: architecture.md#AD-1 ; packages/zcrud_study/pubspec.yaml]
- **AD-2/AD-15 (réactivité Flutter-native)** : aucun `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/
  `Get.`/`Provider.of`. État de saisie/sélection = `ValueNotifier`/`ValueListenableBuilder` locaux ;
  controller de saisie possédé créé/disposé hors `build` (patron owned/injected de `ZStudyToolsPage` ES-5.2 /
  `ZSmartNoteEditor` ES-6.1 / `ZStudyMindmapSection` ES-7.1). Frontière rebuild SM-1 préservée. [Source:
  architecture.md#AD-2, #AD-25 ; z_study_mindmap_section.dart]
- **AD-4 (extensibilité, String opaque, callback null = absent)** : `tag.id`/`folderId` = `String` opaque ;
  `onTagRemoved`/`onDeleteTag`/`onSuggestionConfirmed` `null` = capacité ABSENTE (jamais no-op) ; suggestions
  = value objects `ZSuggestedTag` (registre/port IA côté app). `abstract interface` (jamais `sealed`) si une
  interface est introduite. [Source: architecture.md#AD-4]
- **AD-14 (id attribué par le repository, jamais l'entité)** : `ZTagEditor.onCreateTag` émet un
  `ZFlashcardTag` d'`id == null` (éphémère) ; la matérialisation de l'`id` est faite par le **repository**
  (ES-3), jamais par le widget. [Source: architecture.md#AD-14 ; z_flashcard_tag.dart l.104-108]
- **AD-19 (`ZSyncMeta` hors-entité ; pas de compteur/flag inline)** : `ZFlashcardTag` **n'a pas** de champ
  `usageCount`/`updatedAt`/`isDeleted` (vérifié : `z_flashcard_tag.dart`). Le `usageCount` affiché est donc
  **DÉRIVÉ au rendu** (nombre de cartes référençantes), jamais un champ stocké. [Source: architecture.md#AD-19]
- **AD-13/FR-26 (RTL/a11y/thème injecté ; couleur jamais seul canal)** : directionnel
  (`EdgeInsetsDirectional`, `TextAlign.start`), `Semantics` explicites + labels injectés, cibles ≥ 48 dp,
  **titre textuel du tag toujours rendu** (couleur jamais l'unique canal — WCAG/NFR-S6), couleurs via
  `zResolveColorKeyOrSlot`/`ZcrudTheme.of` (repli `Theme.of`), **aucune** `Color`/hex/`Colors.*`/espacement
  codé en dur. [Source: architecture.md#AD-13 ; z_color_key_resolver.dart]
- **AD-5/AD-11 (Either au repository seulement)** : ES-8.1 est **présentation** — pas de contrat repository
  ici ; la purge PERSISTÉE (retour `Either<ZFailure, Unit>`) est ES-3. Le widget expose des **callbacks** de
  présentation, pas un port. [Source: architecture.md#AD-5, #AD-11]

### API réutilisée (déjà livrée — NE PAS réimplémenter)
- `ZFlashcardTag({id, title, colorKey, extension, extra})` (value equality **profonde** — contrairement à
  `ZMindmap`, DW-ES22-5 ne s'applique PAS : les fixtures PEUVENT comparer par valeur) ; `ZSuggestedTag({title,
  colorKey})` (sans `id`). [Source: z_flashcard_tag.dart ; z_suggested_tag.dart]
- `normalizeTagTitle(String?) → String` ; `dedupeByNormalizedTitle<T>(Iterable<T>, {String? Function(T)
  titleOf}) → List<T>`. [Source: normalize_tag_title.dart]
- `remapColorKey({required ZColorPalette palette, String? rawColorKey, String? seedTitle}) → String` ;
  `ZColorPalette({keys, fallbackKey, hash})` / `const ZColorPalette.defaultStudy()` / `resolveKey`/`indexOf`.
  [Source: remap_color_key.dart ; z_color_palette.dart]
- `orphanTagIds({required Iterable<String> referencedTagIds, required Iterable<String> existingTagIds}) →
  Set<String>` (**DÉTECTION** pure, jamais purge). [Source: tag_referential_integrity.dart]
- `zResolveColorKeyOrSlot(BuildContext, String colorKey, {required int slotIndex}) → ZColorPair` (total,
  contraste M3 garanti) ; `ZColorPair({color, onColor})` ; `ZcrudTheme.of(context)` (`gapS`/`gapM`/
  `labelColor`…). [Source: z_color_key_resolver.dart l.185-224 ; z_theme.dart]
- `ZStudyToolsSectionSpec`/`ZSectionedStudyLayout` (ES-5) — réutilisables si l'app veut insérer les tags comme
  section, **mais** ES-8.1 ne FORCE pas de `sectionSpec` (les tags sont des widgets inline, pas une section
  singleton comme la mindmap). Pas de sur-conception. [Source: z_study_tools_section_spec.dart]

### Source tree à toucher
- **NEW** `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart` (affichage + couleur dérivée + usageCount dérivé).
- **NEW** `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart` (création/dédup + suppression/purge + suggestions IA).
- **UPDATE** `packages/zcrud_study/lib/zcrud_study.dart` (2 exports barrel).
- **NEW** `packages/zcrud_study/test/z_tag_chips_test.dart`.
- **NEW** `packages/zcrud_study/test/z_tag_editor_test.dart`.
- ⛔ **PAS** de changement à `packages/zcrud_study/pubspec.yaml` (0 nouvelle arête — AD-1).

### Dettes / pièges anticipés
- **DW-ES81-1 (usageCount = DÉRIVÉ, non persisté).** L'AC métier parle de « `usageCount` cohérent » mais
  `ZFlashcardTag` n'a **aucun** champ `usageCount` (AD-19, vérifié sur disque). ES-8.1 le traite comme un
  **compteur DÉRIVÉ au rendu** (nb de cartes référençantes). Si un besoin produit réel exige un `usageCount`
  **persisté** (cache serveur lex), c'est une écriture kernel + repository (**ES-2/ES-3**, hors périmètre M) —
  à consigner, ne PAS l'ajouter ici. Preuve de cohérence = AC4 (dérivation au rendu, injection d'un compteur
  figé ⇒ RC=1).
- **DW-ES81-2 (purge PERSISTÉE = repository, ES-3).** ES-8.1 garantit uniquement que l'UI **n'émet aucune
  référence orpheline** après suppression (composition purge-sur-émission via `orphanTagIds`). Le retrait
  effectif de l'`id` du tag des `tagIds` de **toutes** les cartes DANS LE STORE (transaction, `Either`) est le
  travail du `ZStudyRepository`/adapter (`StudyTagsRepository.deleteTag` chez lex — **ES-3**). AC3 est honnête
  vis-à-vis de ce périmètre (R24) : il assère l'**absence d'orphelin dans le modèle émis**, jamais un effet de
  store. Consigner comme dette de continuité si l'app branche le store avant ES-3.
- **R20/R24 (motif dominant du repo — ES-6.1, ES-7.2).** Les primitives réutilisées (`normalizeTagTitle`,
  `orphanTagIds`, `remapColorKey`, `ZColorPalette`) sont **déjà testées au kernel** : re-les-tester ici serait
  POWERLESS sur les widgets. Chaque AC ancre sur la **ligne de prod PROPRE** au widget (fil palette→chip,
  garde de création, composition purge-sur-émission, dérivation du compteur, identité du controller détenu),
  et le prouve par une injection qui **neutralise cette ligne** (jamais un libellé ni un artefact adjacent qui
  survit à la panne).
- **ZFlashcardTag a une égalité de valeur profonde** (contrairement à `ZMindmap`/`ZMindmapNode`, DW-ES22-5) :
  les fixtures/`expect` PEUVENT comparer `ZFlashcardTag == ZFlashcardTag` sans fragilité. [Source:
  z_flashcard_tag.dart l.232-249]
- **Couleur jamais seul canal = concern WCAG partagé avec ES-8.2** (annotations), mais **packages disjoints,
  aucune couplage** : ici c'est le **titre textuel** du chip, là-bas un label/forme d'annotation. Aucune API
  commune à extraire (pas de sur-abstraction prématurée).
- **AD-2 : ne PAS envelopper l'éditeur dans un `ListenableBuilder(listenable: controller)` global** (churn) —
  scoper les `ValueListenableBuilder` par tranche (état saisie ⟂ liste de chips), miroir ES-6.1.

### Vérif verte à rejouer (avant tout `review`/`done`)
- `dart run melos bootstrap` (aucune nouvelle arête à résoudre — sanity) — RC=0.
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, `total arêtes = 42`
  (**0 delta** — AC/AD-1), `noeuds = 20`.
- `dart run melos run analyze` (repo-wide **ET** ciblé `zcrud_study`) — RC=0 (une suppression de symbole public
  casserait un consommateur : vérif **repo-wide** obligatoire, gate d'epic — leçon `ZExportApi`).
- `flutter test` sur `packages/zcrud_study` (**R14** — package Flutter, jamais `dart test`) — RC=0, tous les AC
  verts + **non-régression** des suites ES-5/ES-7 existantes (mindmap, layout, reorder, feature-availability).
- **RC capturé HORS pipe** (R15) : `flutter test ...; echo "RC=$?"` (jamais `| tee`).
- `dart run melos list` inchangé (**20** — aucun nouveau package).
- Injections R3-I1..I11 rejouées (rouge attendu RC=1 sur l'AC visé) puis restaurées (vert), SRC restauré
  byte-identique.

### Project Structure Notes
- Conforme à la structure `zcrud_study` (présentation sous `lib/src/presentation/`, API = barrel
  `lib/zcrud_study.dart`). Aucun `@ZcrudModel` (pas de codegen ; gate `codegen-distribution` sans objet).
- **Variance notable vs ES-7.1** : ES-7.1 AJOUTAIT l'arête `zcrud_study → zcrud_mindmap` ; **ES-8.1 n'ajoute
  AUCUNE arête** (composition de primitives déjà en dépendance). C'est le marqueur de conformité AD-1 le plus
  simple à vérifier (graph_proof à delta nul).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Epic-ES-8 (l.884-905), #FR-S27, #FR-S6]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-1, #AD-2, #AD-4, #AD-13, #AD-14, #AD-19, #AD-25]
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-6-retrospective.md#R20, #R21, #R22]
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-7-retrospective.md#R23, #R24, §9 (séquencement ES-8+)]
- [Source: _bmad-output/implementation-artifacts/stories/es-7-1-integration-mindmap-study-tools.md (patron adaptateur mince + owned/injected + injections R3)]
- [Source: packages/zcrud_study_kernel/lib/src/domain/{z_flashcard_tag.dart, z_suggested_tag.dart, normalize_tag_title.dart, remap_color_key.dart, z_color_palette.dart, tag_referential_integrity.dart}]
- [Source: packages/zcrud_core/lib/src/presentation/theme/{z_color_key_resolver.dart, z_theme.dart}]
- [Source: packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart ; z_study_tools_section_spec.dart ; packages/zcrud_study/pubspec.yaml]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill BMAD `bmad-dev-story` réellement invoqué via tool Skill — pas de fallback disque).

### Debug Log References

Vérif verte rejouée réellement sur disque (RC hors pipe — R15) :
- `dart pub get` → RC=0.
- `flutter test` (packages/zcrud_study, R14) → **RC=0, 84 tests** (19 nouveaux ES-8.1 + 65 de
  non-régression ES-5/ES-7 : mindmap, layout, reorder, rebuild SM-1, content-hub, feature-availability).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK, CORE OUT=0 OK, total arêtes = 42 (0 delta),
  nœuds = 20**. `zcrud_study` ne dépend que d'annotations/core/mindmap/study_kernel — **aucune nouvelle arête**.
- `dart run melos exec --scope=zcrud_study -- dart analyze` → **SUCCESS (RC=0)**.
- `dart run melos list` → **20** (aucun nouveau package).

Injections R3 rejouées réellement (mutation d'UNE ligne de prod → test ciblé → RC hors pipe → restauration
byte-identique vérifiée par `cmp`). **11/11 RED(RC=1)** ; suite complète re-verte (84) après restauration :

| Ref | AC | Ligne de prod neutralisée | Résultat |
|-----|----|---------------------------|----------|
| R3-I1 | AC1 | `remapColorKey(palette: palette…)` → `defaultStudy()` en dur | RED(RC=1) |
| R3-I2 | AC2 | garde `_existingByNormalizedTitle(normalized)` → `null` | RED(RC=1) |
| R3-I3 | AC3 | purge `if (!orphans.contains(id)) id` → `id` (inchangé) | RED(RC=1) |
| R3-I4 | AC4 | `'${referencingCardsCountOf(tag)}'` → `'0'` (figé) | RED(RC=1) |
| R3-I5 | AC5 | `_controller` → `TextEditingController()` créé au getter/build | RED(RC=1) |
| R3-I6 | AC5 | `TextField` + `onChanged: (_) => setState((){})` (état lifté) | RED(RC=1) |
| R3-I7 | AC6 | `Text(tag.title…)` → `SizedBox.shrink()` (couleur seule) | RED(RC=1) |
| R3-I8 | AC6 | cible suppression `48` → `24` | RED(RC=1) |
| R3-I9 | AC6 | `removeTagSemanticLabel(tag)` → `'Supprimer'` en dur | RED(RC=1) |
| R3-I10 | AC7 | matérialisation des suggestions dès `initState` (sans geste) | RED(RC=1) |
| R3-I11 | AC7 | confirmation court-circuitant la garde de dédup | RED(RC=1) |

### Completion Notes List

- **T1 `ZTagChips`** — affichage `StatelessWidget` : FIL palette→chip (`remapColorKey` →
  `zResolveColorKeyOrSlot`, AC1), compteur d'usages DÉRIVÉ au rendu (`referencingCardsCountOf`, AC4/AD-19,
  jamais un champ figé), titre textuel TOUJOURS visible à côté de la pastille (couleur jamais seul canal,
  AC6), cibles ≥ 48 dp, libellés sémantiques INJECTÉS, chrome directionnel, couleurs/gaps du thème injecté.
- **T2 `ZTagEditor`** — patron owned/injected d'`ZStudyMindmapSection` : `TextEditingController` POSSÉDÉ créé
  en `initState` (jamais dans `build`), disposé au `dispose` ; injecté utilisé tel quel, JAMAIS disposé
  (AC5). GARDE anti-doublon au point de création (`normalizeTagTitle`/`dedupeByNormalizedTitle`, AC2 —
  `onCreateTag` émet un `ZFlashcardTag` d'`id == null`, AD-14). Composition purge-sur-émission via
  `orphanTagIds` (AC3, STRUCTURELLE — `orphanTagIds(refsÉmises, existantsAprès) == {}`). État de la zone de
  suggestions dans un `ValueNotifier` LOCAL (SM-1, aucun `setState` de page, aucun gestionnaire d'état).
- **T3 suggestions IA** — `ZSuggestedTag` matérialisée QU'au geste de confirmation explicite (jamais à
  l'affichage, AC7), routée par la MÊME garde de dédup que la création ; rejet retire la suggestion sans rien
  émettre.
- **T4 barrel** — 2 exports ajoutés à `zcrud_study.dart` ; **`pubspec.yaml` INCHANGÉ** (0 nouvelle arête).
- **Dettes** : DW-ES81-1 (usageCount DÉRIVÉ, non persisté) et DW-ES81-2 (purge PERSISTÉE côté store =
  repository ES-3, hors périmètre) respectées : le widget délègue la persistance via `onReferencesPurged`
  (callback de présentation) et ne garantit QUE l'absence d'orphelin dans le modèle ÉMIS.
- **Périmètre** : uniquement `packages/zcrud_study/` (barrel + 4 fichiers) ; aucun fichier de
  `zcrud_document`/`zcrud_study_kernel`/`zcrud_core` touché ; `sprint-status.yaml` NON touché.

### File List

- **NEW** `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart`
- **NEW** `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart`
- **NEW** `packages/zcrud_study/test/z_tag_chips_test.dart`
- **NEW** `packages/zcrud_study/test/z_tag_editor_test.dart`
- **UPDATE** `packages/zcrud_study/lib/zcrud_study.dart` (2 exports barrel)
