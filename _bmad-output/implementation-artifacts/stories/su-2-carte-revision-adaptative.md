---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story SU-2 : Carte de révision adaptative

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an **apprenant**,
I want **voir une flashcard rendue selon son type et révéler la réponse d'un geste**,
so that **je puisse réviser avec la même expérience que dans mon app actuelle.**

**Couvre :** FR-SU1, FR-SU21 (**aperçu seulement** — la duplication est su-8).
**Source de spécification :** `epics.md` § Epic 1 → **Story 1.2** (ACs repris, jamais réinventés).
**Ligne du sprint-status** (l.454) : `[L][A — après su-1] FR-SU1 + FR-SU21(aperçu)
ZFlashcardReviewCard 6 types + ZRevealTransition{flip3d,fade} (flip 3D MAISON, PAS de dep flip_card)
+ Reduce Motion + adaptateur markdown DANS zcrud_flashcard (AD-40, jamais dans zcrud_markdown = cycle)`.

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

**Place dans le séquencement** : première story du **workstream (A)** (`zcrud_flashcard`,
`zcrud_session`, `zcrud_study_kernel`), après la tête bloquante su-1 (**`done`**). Les workstreams
(B) su-11 `zcrud_export`/`zcrud_export_ui` et (C) su-12 `zcrud_mindmap` tournent **en parallèle sur
des packages disjoints** — d'où l'interdiction absolue, ci-dessous, de retoucher leurs fichiers.

**Périmètre RÉEL, vérifié sur disque (ne rien inventer, ne rien recréer) :**

| Symbole | Existe ? | Emplacement RÉEL vérifié |
|---|---|---|
| `ZFlashcardType` (**6 valeurs**) | ✅ existe | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart:20` |
| `ZFlashcard` (`question`/`answer`/`isTrue`/`choices`/`explanation`/`hint`/`isReadOnly`) | ✅ existe | `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:66` |
| `ZChoice` (`content`, `isCorrect`) | ✅ existe | `packages/zcrud_flashcard/lib/src/domain/z_choice.dart:25` |
| `ZFlashcardContentBuilder` (**slot AD-40 à CÂBLER**) | ✅ existe (su-1) | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart:41` |
| `ZFlashcardDefaultContent.builder` (tear-off statique) | ✅ existe (su-1) | `.../z_flashcard_content_slot.dart:65` |
| `ZMarkdownReader` (`value:Object?`, `codec:ZCodec?`, `label:`, `placeholder:`) | ✅ existe | `packages/zcrud_markdown/lib/src/presentation/z_markdown_reader.dart:36` |
| `ZMarkdownCodec` (`decode(String md) → ops Delta`, **défensif**) | ✅ existe | `packages/zcrud_markdown/lib/src/data/z_markdown_codec.dart:69` |
| `ZMindmapMarkdownContent` (**patron d'adaptateur AD-40 à copier**) | ✅ existe | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart:38` |
| `_defaultContent` + `builder ?? _defaultContent` (**patron de branchement à copier**) | ✅ existe | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart:137-142` |
| `label(context, key, fallback:)` (l10n) | ✅ existe | `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:288` |
| `ZcrudTheme.of` / `.fallback` | ✅ existe | `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:295` |
| `minTarget = 48` + `Semantics` (**patron a11y**) | ✅ existe | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:197,212` |

**AUCUNE écriture dans `zcrud_core`** (interdit à toute story SU) · **AUCUNE écriture dans
`zcrud_mindmap`/`zcrud_export`** (workstreams B/C en vol — fichiers disjoints obligatoires) ·
**AUCUN moteur de session** (su-4) · **AUCUNE saisie notée / indice / minuteur** (su-3).

### Absences PROUVÉES par grep négatif (commandes rejouables, RC cité)

Le dev agent **ne doit pas chercher** ces symboles : ils n'existent pas, ils sont à créer.

```bash
# PREUVE A — ZFlashcardReviewCard n'existe nulle part → RC=1
grep -rn "ZFlashcardReviewCard" packages/ --include="*.dart"                      # RC=1 ✅
# PREUVE B — ZRevealTransition n'existe nulle part → RC=1
grep -rn "ZRevealTransition" packages/ --include="*.dart"                         # RC=1 ✅
# PREUVE C — AUCUNE dépendance flip_card dans AUCUN pubspec (elle est INTERDITE) → RC=1
grep -rn "flip_card" packages/ --include="pubspec.yaml"                           # RC=1 ✅
# PREUVE D/E — AUCUN traitement Reduce Motion n'existe dans le repo → RC=1 (su-2 est le PREMIER)
grep -rn "disableAnimations" packages/ --include="*.dart"                         # RC=1 ✅
grep -rn "accessibleNavigation" packages/ --include="*.dart"                      # RC=1 ✅
# PREUVE K — AUCUN cycle : zcrud_markdown n'a AUCUNE arête vers zcrud_flashcard → RC=1
grep -rn "zcrud_flashcard" packages/zcrud_markdown/ --include="pubspec.yaml" --include="*.dart"  # RC=1 ✅
# PREUVE H — les clés `zcrud.srs.*` ne sont PAS dans la table l10n du cœur → RC=1
#   ⇒ patron `label(context, key, fallback: '…')`, AUCUNE écriture dans zcrud_core (cf. § l10n)
grep -rn "zcrud.srs" packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart  # RC=1 ✅
```

### Arêtes de graphe : AUCUNE nouvelle (vérifié — PREUVE J/K)

`zcrud_flashcard` **dépend déjà** de `zcrud_markdown` (`pubspec.yaml` : `zcrud_markdown: ^0.2.1`)
et **l'importe déjà** en `lib/` (`z_flashcard_api.dart:3`). → L'adaptateur AD-40 de cette story
**ne coûte AUCUNE arête** ; `graph_proof` et **CORE OUT=0** restent inchangés. **Si le dev agent
croit devoir toucher un `pubspec.yaml`, il se trompe** : aucune dépendance n'est à ajouter — et
`flip_card` est **interdite** (PREUVE C).

Le sens de l'arête est **le seul autorisé** : `zcrud_markdown → zcrud_flashcard` (l'inverse)
créerait un **cycle** (AD-1). L'adaptateur vit donc **chez le consommateur**, `zcrud_flashcard`.

### 🔴 DETTE LÉGUÉE PAR LE CODE-REVIEW DE su-1 — su-2 DOIT LA SOLDER

`code-review-su-1.md` **§ D5** et **§ LOW L1** reportent explicitement deux preuves au ledger su-2 :

> ⚠️ *« À reporter au ledger su-2 : AC4 "le slot est réellement branché" et la vraie garde SM-1
> ("aucune closure réallouée à chaque build") **restent à prouver en su-2**. Sans cette trace, su-2
> hériterait d'ACs réputés couverts qui ne le sont pas. »*

**Pourquoi c'était infalsifiable en su-1** : `ZFlashcardContentBuilder` n'avait **aucun consommateur
de production** ; un test du slot ne pouvait qu'appeler sa propre closure locale (tautologie D5,
supprimée par honnêteté plutôt que verdie). **su-2 crée ce consommateur** (`ZFlashcardReviewCard`)
⇒ le discriminant « slot décoratif » **devient falsifiable** et **DOIT** être livré (AC1-d/AC6).

**Patron réel à imiter** (`z_mindmap_view.dart:137-142`) :

```dart
static Widget _defaultContent(BuildContext context, ZMindmapNode node) =>
    ZMindmapDefaultNodeContent(node: node);
ZMindmapNodeContentBuilder get _contentBuilder =>
    widget.nodeContentBuilder ?? _defaultContent;   // ← résolution `builder ?? défaut`
```

### ⚠️ Signature du slot : elle SUFFIT — ne PAS la changer (arbitrage tranché)

su-1 a laissé ouvert : *« si su-2 démontre le besoin de la carte complète, l'enrichissement lui
appartient »*. **Vérification faite sur disque : le besoin n'existe pas.** Le typedef
`Widget Function(BuildContext, String content)` **suffit**, parce que `ZMarkdownReader` accepte
`value: Object?` et **normalise par le codec** — `ZMarkdownCodec.decode(String)` transforme une
**source markdown** en ops Delta (`z_markdown_codec.dart:101`, défensif AD-10 : markdown mal formé
⇒ `[]`, **jamais** de throw). L'adaptateur est donc `(context, content) → ZMarkdownReader(value:
content, codec: const ZMarkdownCodec())`.

**Différence assumée avec le patron mindmap** (à ne pas confondre) : `ZMindmapMarkdownContent` lit
un payload Delta dans le **slot AD-4 `extra[slotKey]`** avec un codec **identité** (`ZDeltaCodec`)
parce que `ZMindmapNode.content` est **texte brut** par décision OQ-S5/AD-28. Côté flashcard,
**FR-SU1 dit littéralement** *« Contenus question/réponse/choix rendus en texte riche
(markdown/LaTeX) »* : **le texte de la carte EST la source markdown** — c'est la lecture de lex_ui
(source canonique) et elle ne coûte **ni changement de signature, ni entité nouvelle, ni clé
persistée**. ⇒ **NE PAS élargir le typedef** (ce serait un changement d'API cassant, non démontré).

### ⚠️ Périmètre : su-2 AFFICHE, su-3 FAIT SAISIR (frontière dure)

`epics.md` scinde nettement. **Toute dérive ici casserait su-3.**

| Dans su-2 | Reporté à su-3 (FR-SU2/3/4/5) |
|---|---|
| Rendu des **6 types** + révélation | **Saisie interactive** notée (QCM cliquable, VF auto-soumis, rédaction) |
| Affichage des choix + **marquage du correct** sur la face réponse | **Correction post-soumission**, évaluation locale/port advisory |
| — | Indices (`ZFlashcardHintPort`), **minuteur**, `ZCardAdvanceBehavior` |

🚫 **N'introduire AUCUN** port d'évaluation, plafond de qualité, `ZTimerDisplay`, ni bouton de
soumission : su-2 est une **surface d'affichage** avec révélation. Les boutons de notation restent
aux `ZSrsQualityButtons` **existants** (su-4 les assemble).

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** : ancré sur une ligne de prod réelle et accompagné d'une
**injection de faute** qui doit la faire ROUGIR. Un test qui reste vert quand on casse la logique est
un test tautologique et **invalide l'AC** (discipline R3). Le code-review de su-1 a démasqué **3**
tests qui attestaient des propriétés qu'ils n'exerçaient pas : **ne pas en produire de nouveaux**
(pas de test qui appelle sa propre fonction locale — D5 ; pas de garde de scan ligne-à-ligne — D4 ;
pas de contre-preuve qui réimplémente son scanner — D6).

---

**AC1 — `ZFlashcardReviewCard` rend les 6 types canoniques, par le slot AD-40 branché**

**Given** une flashcard de chacun des **6 types canoniques** (`ZFlashcardType`, vérifié
`z_flashcard_type.dart:20`)
**When** `ZFlashcardReviewCard` l'affiche
**Then**
- le rendu est **adapté au type** — table de rendu **unique** (jamais redécidée ailleurs) :

  | Type | Face **question** | Face **réponse** |
  |---|---|---|
  | `multipleChoice` | `question` + **liste des `choices`** (`ZChoice.content`), non interactifs (su-3) | choix + **marquage du/des `isCorrect`** (canal **non-coloré** obligatoire, cf. AC5) |
  | `trueOrFalse` | `question` | **Vrai/Faux** dérivé de `isTrue` (l10n, cf. AC5) |
  | `openQuestion`, `exercise`, `fillBlank`, `shortAnswer` | `question` | `answer` |

- `explanation` s'affiche sur la face **réponse** quand elle est non nulle/non vide ; **absente**
  sinon (jamais un bloc vide) ;
- **AD-10 (défensif, NFR-SU6)** : aucun champ nullable ne fait planter le rendu — `answer == null`,
  `choices == null`/vide, `isTrue == null` ⇒ **repli l10n** (« Aucune réponse »), **jamais** de
  `!`, jamais d'exception, jamais un écran vide ;
- **(d) le slot AD-40 est RÉELLEMENT BRANCHÉ — solde de la dette D5** : **tout** contenu textuel de
  carte (question, réponse, `ZChoice.content`, `explanation`) passe par
  `contentBuilder ?? ZFlashcardDefaultContent.builder` (patron `z_mindmap_view.dart:142`) —
  **aucun `Text(card.question)` en dur** sur un chemin de contenu ;
- le défaut (aucune injection) reste le **texte brut thématisé** de su-1 : le chemin par défaut
  **n'atteint jamais** `zcrud_markdown` (un consommateur qui n'injecte rien **ne paie pas Quill**).

**Discriminant (falsifiable, contrairement à su-1)** : injecter un `contentBuilder` sentinelle
`(c, s) => Text('INJ:$s')` ⇒ **`INJ:` est trouvé pour chacun** des chemins de contenu, et le rendu
par défaut **ne l'est plus**. **Injection R3-I1** : recoder un seul chemin en `Text(card.question)`
en dur ⇒ le cas correspondant **ROUGIT**. *(C'est exactement le test que su-1 ne pouvait pas
écrire : le call-site de production existe désormais.)*
**Injection R3-I1b** : renvoyer `answer!` sans repli ⇒ le cas `answer == null` ROUGIT.

---

**AC2 — `ZRevealTransition { flip3d, fade }` — flip 3D MAISON, `flip_card` INTERDITE**

**Given** `ZRevealTransition.flip3d` **puis** `ZRevealTransition.fade`
**When** l'utilisateur révèle la réponse
**Then**
- la transition **correspond à l'enum** — `enum ZRevealTransition { flip3d, fade }` (**un enum,
  JAMAIS un booléen** — convention du spine « enums > booléens ») ;
- le flip 3D est **MAISON** : `AnimationController` + `Transform` sur une `Matrix4` avec
  **perspective** (`..setEntry(3, 2, 0.001)..rotateY(θ)`), **bascule de face à mi-course**
  (θ = π/2) et **contre-rotation de la face arrière** (sinon le dos s'affiche **en miroir** — piège
  classique) ;
- **AUCUNE dépendance `flip_card`** n'est ajoutée (PREUVE C : elle n'existe dans aucun pubspec —
  interdite par FR-SU1 et par la contre-métrique du PRD « pas de nouvelle dépendance tierce
  au-delà des trois décidées ») ; **aucun `pubspec.yaml` n'est modifié par cette story** ;
- **un test couvre chaque valeur de l'enum** (exigé mot pour mot par l'epic) — et une **garde
  d'exhaustivité** (`switch` exhaustif sans `default`) fait **rougir la compilation** si une valeur
  est ajoutée sans être traitée ;
- le `AnimationController` est **stable** (`create`/`dispose` du `State`, `SingleTickerProvider`),
  **jamais recréé au rebuild** (AD-2/NFR-SU2).

**Discriminant** : sous `flip3d`, à mi-animation (`pump(50ms)` sur 250 ms) un `Transform` porte une
matrice **de rotation Y non identitaire** ; sous `fade`, **aucune** rotation n'est appliquée et
c'est un `FadeTransition`/opacité qui varie. Les deux valeurs **produisent des arbres de widgets
distincts** — un test par valeur. **Injection R3-I2** : câbler `fade` sur le chemin `flip3d`
(ignorer l'enum) ⇒ le cas `flip3d` ROUGIT.
**Garde de source (anti-dep)** : test rougissant si `flip_card` apparaît dans un `pubspec.yaml` du
repo — scan **par déclaration**, avec **contre-preuve R12** exerçant le **vrai scanner** (patron
imposé par D4/D6 : jamais de filtrage ligne-à-ligne, jamais de contre-preuve qui recopie la boucle).

---

**AC3 — Reduce Motion : jamais de flip animé (NFR-SU3) — su-2 est le PREMIER du repo**

**Given** Reduce Motion actif
**When** l'utilisateur révèle la réponse
**Then**
- la révélation est **instantanée ou en fondu court**, **jamais un flip animé** — y compris quand
  `revealTransition == ZRevealTransition.flip3d` (**Reduce Motion PRIME sur l'enum**) ;
- le signal est `MediaQuery.disableAnimationsOf(context)` — **PREUVE D/E : aucun traitement Reduce
  Motion n'existe aujourd'hui dans le repo (RC=1)**. su-2 **établit le patron** que su-4 (drag
  statique) et su-5 (confetti supprimé) réutiliseront : le résoudre dans une **primitive interne
  unique et réutilisable**, jamais dispersé dans les `build()` ;
- le respect de Reduce Motion **n'annule pas la révélation** : la réponse s'affiche bel et bien
  (dégradation de l'**animation**, pas de la **fonction**).

**Discriminant** : `MediaQuery(data: MediaQueryData(disableAnimations: true))` ⇒ sous **`flip3d`**,
**aucun `Transform` de rotation Y** n'apparaît à aucun instant de la révélation, et la face réponse
est présente **immédiatement** (ou après un fondu court borné). **Injection R3-I3** : ignorer
`disableAnimations` (lire la seule valeur de l'enum) ⇒ le test ROUGIT en trouvant la rotation.
⚠️ **Test tautologique à ne PAS écrire** : `expect(disableAnimations, isTrue)` ne prouve rien (il
teste `MediaQuery`, pas le widget) — l'assertion **doit porter sur l'arbre rendu**.

---

**AC4 — `isReadOnly` ⇒ aperçu lecture seule, actions ABSENTES (FR-SU21, AD-45)**

**Given** une flashcard **`isReadOnly`** (champ réel — `z_flashcard.dart`, défaut `false`)
**When** la carte s'ouvre
**Then**
- elle est en **aperçu lecture seule** : les actions d'édition/suppression sont **ABSENTES de
  l'arbre** — **jamais grisées/désactivées** (AD-45 littéral : *« actions d'édition et de
  suppression absentes, jamais désactivées-grisées »*) ;
- **patron `ZItemActionsMenu`** (convention du spine : *« action **absente** si non fournie »*) :
  les callbacks `onEdit`/`onDelete` sont **injectés** ; un callback **non fourni** ⇒ action
  **absente**, exactement comme `isReadOnly` ⇒ **les deux voies convergent**, jamais deux règles ;
- **« Dupliquer pour modifier » n'est PAS de cette story** — la FR Coverage Map de l'epic dit
  `FR-SU1, FR-SU21 (aperçu) | 1.2` **vs** `FR-SU14, FR-SU21 (duplication) | 1.8` : su-2 livre
  **l'aperçu**, su-8 la duplication. **Ne pas l'anticiper.**

**Discriminant** : `isReadOnly: true` **+ `onEdit`/`onDelete` fournis** ⇒ `finder` des actions
**`findsNothing`** (et **non** un widget désactivé : asserter l'**absence**, pas `enabled == false`
— sinon le test resterait vert sur un bouton grisé, ce qu'AD-45 **interdit**) ; `isReadOnly: false`
+ callbacks fournis ⇒ actions **présentes et tapables**. **Injection R3-I4** : remplacer l'absence
par `onPressed: null` (grisé) ⇒ le cas lecture seule ROUGIT.

---

**AC5 — Zéro couleur/libellé en dur, ≥ 48 dp, `Semantics`, RTL (NFR-SU3/4/5, AD-13)**

**Given** la révision d'une carte
**When** l'utilisateur interagit
**Then**
- **aucune couleur codée en dur** : `ZcrudTheme.of(context)` avec repli `Theme.of(context)`
  (patron `z_flashcard_content_slot.dart:70-71`) — y compris le marquage du choix correct ;
- **aucun libellé codé en dur** : `label(context, 'zcrud.flashcard.<clé>', fallback: '…')` (patron
  **réel** `z_session_quality_breakdown.dart:82`). ⚠️ **PREUVE H** : les clés de satellite
  (`zcrud.srs.*`) ne sont **PAS** dans la table du cœur (RC=1) ⇒ le `fallback:` **est** le
  mécanisme, et **AUCUNE écriture dans `zcrud_core` n'est nécessaire ni autorisée** ;
- **cibles tactiles ≥ 48 dp** avec `Semantics` explicites (patron `minTarget = 48`,
  `z_srs_quality_buttons.dart:197,212`) ;
- **variantes directionnelles obligatoires** (RTL, AD-13) : `EdgeInsetsDirectional`,
  `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end` — **jamais**
  `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right` ;
- **canal non-coloré obligatoire** (AD-13) : le choix correct est signalé par **icône + `Semantics`**,
  **jamais par la seule couleur** (un daltonien et un lecteur d'écran doivent le percevoir) ;
- l'état révélé est annoncé sémantiquement (la révélation n'est pas qu'un effet visuel).

**Discriminant** : (1) **thème** — un `ZcrudScope(theme: ZcrudTheme())` + un `ColorScheme.onSurface`
**volontairement distinct** de `bodyMedium.color` prouve que la branche de repli est **réellement**
empruntée (leçon **D7** de su-1 : sans cette distinction, le test passe **quelle que soit** la
branche et ne discrimine **rien**) ; (2) **48 dp** — `tester.getSize()` de chaque cible interactive
`>= const Size(48, 48)` ; (3) **RTL** — la carte se construit sous `Directionality(rtl)` et
`Directionality(ltr)` sans exception ni débordement ; (4) **canal non-coloré** — le marquage correct
est trouvable **sans lire une couleur**. **Injection R3-I5** : `const Color(0xFF00AA00)` en dur sur
le marquage correct ⇒ le discriminant de thème ROUGIT.
**Garde de source RTL** : scan du **code de prod** de `zcrud_flashcard/lib` rougissant sur
`EdgeInsets.only(left:`/`right:`, `Alignment.centerLeft/Right`, `TextAlign.left/right`,
`Positioned(left:/right:)` — scan **par déclaration** + **contre-preuve exerçant le vrai scanner**
(D4/D6). Portée **déclarée honnêtement** : couvre le code zcrud, jamais les tests.

---

**AC6 — Adaptateur markdown/LaTeX prêt à injecter, DANS `zcrud_flashcard` (AD-40)**

**Given** que le contenu riche doit passer par le **slot injectable** (AD-40)
**When** la story est livrée
**Then**
- `zcrud_flashcard` fournit **`ZFlashcardMarkdownContent`** — **adaptateur MINCE**, calqué sur
  `ZMindmapMarkdownContent` (`z_mindmap_markdown_content.dart:38`) : il **compose** `ZMarkdownReader`
  + `const ZMarkdownCodec()` **TELS QUELS**. **AUCUN** nouveau codec, **AUCUNE** heuristique de
  format, **AUCUN** `QuillController`/`Delta` construit à la main ;
- il expose une **fabrique statique** conforme au slot su-1 :
  `static ZFlashcardContentBuilder builder({String? placeholder})` (patron
  `ZMindmapMarkdownContent.builder(slotKey:)`) — voie d'usage app :
  `ZFlashcardReviewCard(contentBuilder: ZFlashcardMarkdownContent.builder())` ;
- il vit **dans `zcrud_flashcard`**, **JAMAIS** dans `zcrud_markdown` (**cycle**, AD-1/AD-40) —
  **PREUVE K** : `zcrud_markdown` n'a aujourd'hui **aucune** arête vers `zcrud_flashcard` (RC=1), et
  cette story **n'en crée pas** ;
- **aucun type `Quill`/`flutter_math_fork` dans une signature publique** (AD-7/AD-40) — la garde de
  source **existante** `z_flashcard_rich_type_leak_test.dart` (durcie **multi-lignes** par le D4 de
  su-1) **couvre déjà** les nouveaux symboles : elle scanne le package, **ne pas la contourner** ;
- **le LaTeX est rendu** : `ZMarkdownReader` monte `kZEmbedBuilders` (`z_markdown_reader.dart:163`)
  qui embarque les embeds LaTeX (`kLatexEmbedType`, `z_latex_embed.dart:38`) — **rien à recâbler** ;
- **AD-10** : une source markdown mal formée **ne casse jamais** le rendu (`ZMarkdownCodec.decode`
  retombe sur `[]`, `z_markdown_codec.dart:115`) ;
- **l'adaptateur reste OPT-IN** : le **défaut** de `ZFlashcardReviewCard` demeure le texte brut de
  su-1 (une app qui ne l'injecte pas **ne tire pas Quill**).

**Discriminant** : (1) avec `contentBuilder: ZFlashcardMarkdownContent.builder()`, un contenu
`'**gras**'` rend un `ZMarkdownReader` **et non** le texte littéral `'**gras**'` ; (2) **sans**
injection, `'**gras**'` s'affiche **verbatim** en texte brut et **aucun** `ZMarkdownReader`
n'apparaît dans l'arbre (**preuve que le riche est bien une injection, pas un défaut**) ; (3) un
markdown mal formé ne lève **aucune** exception. **Injection R3-I6** : rendre le riche en dur dans
`ZFlashcardReviewCard` (sans injection) ⇒ le cas (2) ROUGIT.

---

**AC7 — SM-1 / rebuilds granulaires (NFR-SU2) — solde de la dette L1 de su-1**

**Given** une carte affichée
**When** l'utilisateur révèle la réponse
**Then**
- **seule la tranche de face se reconstruit** — l'état de révélation vit dans un
  **`ValueNotifier<bool>` stable** (créé une fois, `dispose`é) lu par un `ValueListenableBuilder` ;
  **jamais** de `setState` à l'échelle de la carte (AD-2, **objectif produit n°1**) ;
- **aucune closure réallouée à chaque build** sur le chemin du slot : la résolution est
  `widget.contentBuilder ?? ZFlashcardDefaultContent.builder` (**tear-off statique**) — **jamais**
  `?? (c, s) => …` (closure neuve à chaque build, identité changeante, rebuilds cassés). *C'est la
  garde SM-1 que su-1 a explicitement **déférée à su-2** (L1).* ⚠️ **Piège tracé par le
  code-review de su-1 (LOW SM-1)** : `ZQualityScale.fromConfig` **n'est jamais `const`** ⇒ si su-2
  construit une échelle, la **hoister hors du `build()`** ;
- changer de carte (`ZFlashcard` différente) **réinitialise** la révélation à « question » —
  `ValueKey(card.id)` / `didUpdateWidget` : une carte suivante **ne s'ouvre jamais** réponse déjà
  révélée (bug fonctionnel réel).

**Discriminant** : (1) une **sonde de comptage** dans le `contentBuilder` injecté prouve que la
révélation **ne reconstruit pas** le sous-arbre stable de la carte ; (2) `identical()` sur le
builder résolu **entre deux builds successifs** ⇒ **`true`** (rougit si une closure est allouée
dans `build()`) ; (3) après `didUpdateWidget` avec une **nouvelle** carte, la face **question** est
affichée. **Injection R3-I7** : remplacer le tear-off par `?? (c, s) => ZFlashcardDefaultContent(
content: s)` ⇒ le cas (2) ROUGIT. **Injection R3-I7b** : retirer la réinitialisation ⇒ (3) ROUGIT.

---

**AC8 — Gates repo-wide verts**

**Given** les gates du monorepo
**When** la story est déclarée verte
**Then** `melos run generate` OK · `melos run analyze` **RC=0 repo-wide** · `melos run test`
**RC=0** · `melos run verify` **RC=0** (graphe **acyclique**, **CORE OUT=0**, secrets,
`codegen-distribution`).
**Non négociable** : `analyze` **repo-wide**, jamais par-package seul (précédent `ZExportApi` en
E11a-3 : symbole public supprimé, `melos analyze` RED plusieurs commits sans être vu).
⚠️ **Workstreams B/C en vol** : si un `melos` global est bruité par un dev concurrent, **rejouer
ciblé** (`zcrud_flashcard`) **puis** exiger le repo-wide à l'arrêt — **jamais deux `flutter test`
en parallèle sur ce workspace melos** (précédent `-6` en phase `loading`, cf. code-review su-1).

## Spécifications techniques — signatures exactes (contrat à livrer)

**Forme indicative mais CONTRAIGNANTE sur les points marqués 🔒** (le reste est à l'appréciation du
dev tant que les ACs sont satisfaits).

```dart
// packages/zcrud_flashcard/lib/src/domain/z_reveal_transition.dart
/// Transition de révélation question→réponse (FR-SU1). 🔒 ENUM, jamais un booléen.
/// Reduce Motion PRIME sur cette valeur (AC3).
enum ZRevealTransition { flip3d, fade }

// packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart
class ZFlashcardReviewCard extends StatefulWidget {
  const ZFlashcardReviewCard({
    required this.card,                                       // 🔒 ZFlashcard existant
    this.revealTransition = ZRevealTransition.flip3d,         // 🔒 défaut flip3d (arbitrage 5)
    this.contentBuilder,                                      // 🔒 slot su-1 (nullable = opt-in)
    this.transitionDuration = const Duration(milliseconds: 250), // 🔒 250 ms (arbitrage 7)
    this.onRevealChanged,                                     //    callback facultatif
    this.onEdit,                                              // 🔒 null ⇒ action ABSENTE (AD-45)
    this.onDelete,                                            // 🔒 null ⇒ action ABSENTE (AD-45)
    super.key,
  });

  final ZFlashcard card;
  final ZRevealTransition revealTransition;
  final ZFlashcardContentBuilder? contentBuilder;  // 🔒 typedef su-1 INCHANGÉ (arbitrage 1)
  final Duration transitionDuration;
  final ValueChanged<bool>? onRevealChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
}

// packages/zcrud_flashcard/lib/src/presentation/z_flashcard_markdown_content.dart
/// Adaptateur MINCE AD-40 — vit chez le CONSOMMATEUR (jamais dans zcrud_markdown = cycle).
class ZFlashcardMarkdownContent extends StatelessWidget {
  const ZFlashcardMarkdownContent({required this.content, this.placeholder, super.key});
  final String content;      // 🔒 source markdown/LaTeX (le TEXTE de la carte — arbitrage 2)
  final String? placeholder;

  /// 🔒 Fabrique conforme au slot su-1 — voie d'usage app.
  static ZFlashcardContentBuilder builder({String? placeholder}) => /* … */;

  @override
  Widget build(BuildContext context) => ZMarkdownReader(   // 🔒 RÉUTILISÉ tel quel
        value: content,
        codec: const ZMarkdownCodec(),                     // 🔒 markdown String → ops Delta
        placeholder: placeholder ?? /* repli l10n */,
      );
}
```

**Résolution du slot (🔒 patron exact — AC1-d/AC7, `z_mindmap_view.dart:137-142`)** :

```dart
ZFlashcardContentBuilder get _contentBuilder =>
    widget.contentBuilder ?? ZFlashcardDefaultContent.builder;  // 🔒 tear-off, JAMAIS `?? (c,s) => …`
```

**Reduce Motion (🔒 API vérifiée sur le SDK installé — Flutter 3.44.4,
`media_query.dart:1950`)** : `MediaQuery.disableAnimationsOf(context)` → `bool`. **PREUVE D/E :
aucun usage dans le repo ⇒ su-2 fixe le patron** (primitive interne unique, réutilisée par su-4/su-5).

**Geste de révélation (ambiguïté tranchée — arbitrage 8)** : **tap sur la carte** (`InkWell`/
`GestureDetector` ≥ 48 dp + `Semantics(button: true, onTap:)` — l'epic dit « révéler la réponse
**d'un geste** »). Le tap **bascule** question↔réponse ; `onRevealChanged` **notifie** l'hôte
(su-3/su-4 en dépendront) **sans** que la carte cède la propriété de son état (AD-2 : l'état de
révélation appartient à la carte — un `ValueNotifier<bool>` interne stable, AC7).

## Tasks / Subtasks

- [x] **T1 — `ZRevealTransition` (AC2)** · `zcrud_flashcard`
  - [x] Créer `lib/src/domain/z_reveal_transition.dart` : `enum ZRevealTransition { flip3d, fade }`
        + dartdoc citant FR-SU1/AD-13 (**enum, jamais booléen** ; Reduce Motion **prime**).
  - [x] Exporter depuis le barrel `lib/zcrud_flashcard.dart` (ordre alphabétique des `export`).
- [x] **T2 — `ZFlashcardReviewCard` : rendu des 6 types (AC1)** · `zcrud_flashcard`
  - [x] Créer `lib/src/presentation/z_flashcard_review_card.dart` (`StatefulWidget`).
  - [x] Table de rendu **unique** par `ZFlashcardType` (`switch` **exhaustif, sans `default`** — une
        7ᵉ valeur doit casser la **compilation**, pas filer un repli silencieux).
  - [x] Replis défensifs AD-10 (`answer`/`choices`/`isTrue` nuls ⇒ repli l10n, jamais de `!`).
  - [x] **Câbler le slot su-1** sur **tous** les chemins de contenu :
        `widget.contentBuilder ?? ZFlashcardDefaultContent.builder` (**tear-off statique**, AC7).
- [x] **T3 — Révélation + transitions maison (AC2, AC3, AC7)** · `zcrud_flashcard`
  - [x] `ValueNotifier<bool>` de révélation **stable** (create/dispose) + `ValueListenableBuilder`
        (**aucun `setState` de carte**).
  - [x] `AnimationController` stable (`SingleTickerProviderStateMixin`), **jamais recréé**.
  - [x] `flip3d` **MAISON** : `Matrix4..setEntry(3, 2, 0.001)..rotateY(θ)`, bascule à θ=π/2,
        **contre-rotation de la face arrière** (sinon miroir). **AUCUNE dep `flip_card`.**
  - [x] `fade` : fondu court, **aucune** rotation.
  - [x] **Reduce Motion** (`MediaQuery.disableAnimationsOf`) : primitive **unique réutilisable**
        (su-4/su-5 la consommeront) ⇒ instantané/fondu court, **prime sur l'enum**.
  - [x] Réinitialisation de la révélation au changement de carte (`didUpdateWidget`).
- [x] **T4 — Aperçu lecture seule (AC4)** · `zcrud_flashcard`
  - [x] Callbacks `onEdit`/`onDelete` injectés ; action **ABSENTE** si `isReadOnly` **ou** callback
        non fourni (patron `ZItemActionsMenu` — **jamais grisée**).
  - [x] 🚫 **Ne PAS** implémenter « Dupliquer pour modifier » (**su-8**).
- [x] **T5 — A11y / thème / l10n / RTL (AC5)** · `zcrud_flashcard`
  - [x] `ZcrudTheme.of` + repli `Theme.of` ; **zéro** couleur en dur.
  - [x] `label(context, 'zcrud.flashcard.*', fallback: '…')` ; **zéro** libellé en dur ; **aucune**
        écriture dans `zcrud_core` (PREUVE H).
  - [x] Cibles ≥ 48 dp (`minTarget`) + `Semantics` explicites + **canal non-coloré** (icône) du
        choix correct ; variantes **directionnelles** partout.
- [x] **T6 — Adaptateur `ZFlashcardMarkdownContent` (AC6)** · `zcrud_flashcard`
  - [x] Créer `lib/src/presentation/z_flashcard_markdown_content.dart` — **adaptateur mince**
        (`ZMarkdownReader` + `const ZMarkdownCodec()`), fabrique
        `static ZFlashcardContentBuilder builder({String? placeholder})`.
  - [x] Exporter depuis le barrel. **Aucun `pubspec.yaml` touché** (arête préexistante, PREUVE J).
- [x] **T7 — Tests porteurs (AC1..AC7)** — cf. § Stratégie de test.
- [x] **T8 — Vérif verte (AC8)** : `melos run generate` → `analyze` → `test` → `verify` **repo-wide**.

## Stratégie de test

**Runner (R14)** : `zcrud_flashcard` **est un package Flutter** (`pubspec.yaml` : `flutter: sdk`
déclaré explicitement, vérifié) ⇒ **`flutter test`**, jamais `dart test`.
⚠️ **Écart réel constaté en su-1** (à ne pas rejouer) : `zcrud_study_kernel`, lui, n'est **PAS** un
package Flutter (`test: ^1.25.0`) — sans objet ici, su-2 ne touche pas le kernel.
**Gardes de source** : `@TestOn('vm')` + `dart:io`, scan **par DÉCLARATION** (recollage des lignes
de continuation — **leçon D4** : `dart format` wrappe à 80 col., le multi-lignes est le cas
**NOMINAL**), **contre-preuve R12** (`isNotEmpty` sur ce qui est scanné) **exerçant la vraie
fonction de scan** (**leçon D6** : une contre-preuve qui recopie la boucle valide les motifs, jamais
le scanner — c'est la racine causale exacte de D4).

| Fichier de test | Ce qu'il PROUVE (rougit si…) |
|---|---|
| `packages/zcrud_flashcard/test/z_flashcard_review_card_test.dart` **(NEUF, widget)** | AC1 — **6 types** rendus (1 cas/type) ; `explanation` présente/absente ; replis AD-10 (`answer`/`choices`/`isTrue` nuls) ; **AC1-d : slot branché** (sentinelle `INJ:` sur **tous** les chemins — *solde D5*) |
| `packages/zcrud_flashcard/test/z_flashcard_reveal_transition_test.dart` **(NEUF, widget)** | AC2 — **un cas par valeur** de l'enum ; `flip3d` ⇒ rotation Y à mi-course, `fade` ⇒ **aucune** rotation ; exhaustivité du `switch` |
| `packages/zcrud_flashcard/test/z_flashcard_reduce_motion_test.dart` **(NEUF, widget)** | AC3 — `disableAnimations: true` + `flip3d` ⇒ **aucune** rotation Y à aucun instant, réponse présente ; assertion **sur l'arbre**, jamais sur `MediaQuery` |
| `packages/zcrud_flashcard/test/z_flashcard_read_only_preview_test.dart` **(NEUF, widget)** | AC4 — `isReadOnly` ⇒ actions **`findsNothing`** (**pas** « désactivées ») ; callback absent ⇒ action absente ; `isReadOnly: false` ⇒ présentes/tapables |
| `packages/zcrud_flashcard/test/z_flashcard_review_card_a11y_test.dart` **(NEUF, widget)** | AC5 — repli de thème **réellement** emprunté (`onSurface` ≠ `bodyMedium.color` — *leçon D7*) ; ≥ 48 dp ; RTL+LTR ; canal **non-coloré** du choix correct |
| `packages/zcrud_flashcard/test/z_flashcard_rtl_guard_test.dart` **(NEUF, garde de source)** | AC5 — rougit si une variante **non directionnelle** apparaît dans `zcrud_flashcard/lib` |
| `packages/zcrud_flashcard/test/z_flashcard_markdown_content_test.dart` **(NEUF, widget)** | AC6 — avec injection ⇒ `ZMarkdownReader` ; **sans** ⇒ texte **verbatim** et **aucun** `ZMarkdownReader` ; markdown mal formé ⇒ **aucune** exception |
| `packages/zcrud_flashcard/test/z_flip_card_dep_guard_test.dart` **(NEUF, garde de source)** | AC2 — rougit si `flip_card` entre dans un `pubspec.yaml` |
| `packages/zcrud_flashcard/test/z_flashcard_review_card_sm1_test.dart` **(NEUF, widget)** | AC7 — sonde de comptage (révélation ⇒ pas de rebuild global) ; `identical()` du builder résolu entre deux builds (*solde L1*) ; reset au changement de carte |
| `packages/zcrud_flashcard/test/z_flashcard_rich_type_leak_test.dart` *(EXISTE — vérifier, ne pas affaiblir)* | AC6 — la garde **durcie par D4** couvre déjà les nouveaux symboles : **aucun** type Quill en signature publique |
| `packages/zcrud_flashcard/test/z_public_surface_test.dart` *(EXISTE — positif seul)* | Non-régression : la surface historique reste intacte (les ajouts sont **additifs** ⇒ ne le cassent pas) |

**Non-régression obligatoire** : `z_flashcard_content_slot_test.dart` (**le contrat + le défaut de
su-1 — su-2 le CONSOMME, ne le réécrit pas**), `z_flashcard_test.dart`, `z_flashcard_editors_test.dart`,
`z_srs_config_test.dart`, `z_sm2_contract_test.dart`, `z_public_surface_test.dart`,
`z_kernel_surface_guard_test.dart` **restent verts**. **Si l'un rougit, c'est la retouche qui est
fautive — jamais le test à assouplir.**

**⚠️ Piège cross-package tracé (précédent su-1, note 2)** : l'ajout d'un export au barrel
`zcrud_flashcard` avait fait **rougir** `z_kernel_surface_guard_test.dart` — **invisible d'une vérif
par-package**. Les symboles de su-2 sont **flashcard-locaux** (aucun réexport kernel) ⇒ le risque est
faible, mais **AC8 (`melos run test` repo-wide) reste la seule preuve**.

**⚠️ Injections R3 destructives** : les jouer **dans un worktree jetable** ou sur **arbre quiescent**
— les workstreams B/C tournent en parallèle (leçon explicite du code-review su-1 : des injections
concurrentes dans un working tree partagé ont produit de **faux HIGH**).

## Dev Notes

### Contraintes AD applicables (invariants — chaque story SU y est soumise)

- **AD-40** — rendu riche **par slot injectable** ; **défaut texte brut** ; **adaptateur chez le
  CONSOMMATEUR** (`zcrud_flashcard`) — **jamais** dans `zcrud_markdown` (**cycle**, AD-1) ; **aucun
  type Quill/`flutter_math_fork` en signature publique**.
- **AD-45** — lecture seule : aperçu, actions **absentes** (jamais grisées) ; duplication = **su-8**.
- **AD-2 / AD-15** — réactivité **Flutter-native** (`ValueListenable`/`ChangeNotifier`) ; **aucun**
  gestionnaire d'état ; controllers **stables** ; **aucun `setState`** de formulaire/carte.
- **AD-13** — RTL (variantes **directionnelles**), `Semantics`, **≥ 48 dp**, thème/l10n **injectés**,
  **Reduce Motion**, **canal non-coloré**.
- **AD-10 / NFR-SU6** — défensif : **jamais** d'exception, replis définis (champs nuls, markdown
  mal formé).
- **AD-1 / NFR-SU7** — graphe **acyclique**, **CORE OUT=0**, dépendance tierce confinée à son
  satellite ; **aucune** nouvelle dépendance (`flip_card` **interdite**).
- **AD-4** — extension par composition/registre ; **enums > booléens** (convention du spine).
- **AD-46** *(consommé, pas retouché)* — l'échelle **0..5** appartient à `ZSrsConfig` ;
  `ZQualityScale.fromConfig` en dérive. **Ne JAMAIS la redéclarer** (su-2 n'en a a priori pas besoin :
  la notation est à su-4).

### Key Don'ts (spécifiques à cette story)

- 🚫 **Jamais** écrire dans `zcrud_core` (interdit à toute story SU — et **inutile** : PREUVE H).
- 🚫 **Jamais** toucher `zcrud_mindmap` / `zcrud_export` / `zcrud_export_ui` (**workstreams B/C en
  vol** — fichiers **disjoints** obligatoires).
- 🚫 **Jamais** ajouter `flip_card` ni **aucune** dépendance (le flip est **MAISON**) ; **aucun
  `pubspec.yaml`** n'est modifié par cette story.
- 🚫 **Jamais** placer l'adaptateur dans `zcrud_markdown` (**cycle** AD-1/AD-40).
- 🚫 **Jamais** élargir le typedef `ZFlashcardContentBuilder` (le besoin n'est **pas** démontré —
  `ZMarkdownCodec.decode(String)` suffit).
- 🚫 **Jamais** un booléen là où l'enum est exigé (`ZRevealTransition`).
- 🚫 **Jamais** de `setState` à l'échelle de la carte ; **jamais** de controller recréé au rebuild ;
  **jamais** de closure de slot allouée dans `build()`.
- 🚫 **Jamais** une action **grisée** en lecture seule (AD-45 exige l'**absence**).
- 🚫 **Jamais** de couleur/libellé en dur ; **jamais** `EdgeInsets.only(left:/right:)`,
  `Alignment.centerLeft/Right`, `TextAlign.left/right`, `Positioned(left:/right:)`.
- 🚫 **Jamais** anticiper su-3 (saisie notée, indices, minuteur, avance) ni su-8 (duplication).
- 🚫 **Jamais** assouplir un test existant pour faire passer une retouche.

### Project Structure Notes

Fichiers **NEW** (tous dans `packages/zcrud_flashcard/`) :
`lib/src/domain/z_reveal_transition.dart` · `lib/src/presentation/z_flashcard_review_card.dart` ·
`lib/src/presentation/z_flashcard_markdown_content.dart` · les **9 tests neufs** du tableau.
Fichiers **UPDATE** : `lib/zcrud_flashcard.dart` (**exports additifs seulement**).
Fichiers **LECTURE SEULE — modèles à copier, à ne PAS modifier** :
`z_flashcard_content_slot.dart` (**contrat + défaut de su-1 : le CONSOMMER**) ·
`z_mindmap_view.dart:137-142` (**patron de branchement `builder ?? défaut`**) ·
`z_mindmap_markdown_content.dart` (**patron d'adaptateur mince AD-40**) ·
`z_srs_quality_buttons.dart:197,212` (**patron a11y 48 dp + `Semantics`**) ·
`z_session_quality_breakdown.dart:82` (**patron `label(context, key, fallback:)`**).
**Convention** : API publique par barrel `lib/<pkg>.dart`, impl sous `lib/src/{domain,data,presentation}`,
types publics préfixés **`Z`**, fichiers `snake_case`, tests `*_test.dart`, `const` partout où possible.

### Ambiguïtés relevées & arbitrages (tranchés faute d'interlocuteur — mode non interactif)

1. **Signature du slot** (laissée ouverte par su-1) : **inchangée**. `ZMarkdownReader(value:
   Object?, codec:)` + `ZMarkdownCodec.decode(String)` couvrent le besoin ⇒ élargir le typedef
   serait un **changement d'API cassant non démontré**. *(Le plus conservateur.)*
2. **Source du riche : texte de la carte vs slot AD-4 `extra`** : **le texte** — FR-SU1 dit
   « contenus question/réponse/choix rendus en texte riche », et le persisté de `ZFlashcard` porte
   déjà le markdown (usage lex). Le patron `extra[slotKey]` du mindmap répond à une **autre**
   contrainte (OQ-S5 : `content` **imposé** texte brut). **Aucune clé persistée nouvelle.**
3. **Interactivité des choix QCM** : **hors périmètre** (su-3). su-2 les **affiche** et **marque le
   correct** sur la face réponse. *(Frontière dictée par la FR Coverage Map de l'epic.)*
4. **« Dupliquer pour modifier »** : **su-8** (`FR-SU21 (duplication) | 1.8`). su-2 = **aperçu**.
5. **Défaut de `revealTransition`** : **`flip3d`** — c'est la carte flip décrite par FR-SU1 et le
   comportement des deux apps sources. Reduce Motion le **neutralise** de toute façon (AC3).
6. **Reduce Motion — signal** : `MediaQuery.disableAnimationsOf(context)` (**aucun précédent dans
   le repo, PREUVE D/E**) ⇒ su-2 **fixe le patron** de su-4/su-5 : primitive **unique**, jamais
   dispersée. *(`accessibleNavigation` n'est **pas** le bon signal : il désigne le lecteur d'écran,
   pas la réduction d'animations.)*
7. **Durée de transition** : **paramétrable**, défaut **250 ms** — valeur de la source canonique
   (`SessionFlashcardView` : `AnimatedSwitcher` **fade 250 ms**, rapport de parité §2).
8. **Geste de révélation** : **tap sur la carte** (l'epic dit « d'un geste », sans le nommer) —
   c'est le geste des deux apps sources et il **n'entre pas en conflit** avec le **swipe de
   navigation** de su-4 (`ZSessionCardSwiper`, FR-SU6 : *« le swipe navigue uniquement »*). ⚠️ **su-2
   ne pose AUCUN `Dismissible`/`onHorizontalDrag`** : il consommerait le geste dont su-4 a besoin.
9. **Propriété de l'état de révélation** : **la carte** (`ValueNotifier<bool>` interne, AD-2), avec
   `onRevealChanged` en **notification sortante**. *(Le plus conservateur : aucun paramètre `revealed`
   entrant — su-3/su-4 n'ont pas encore démontré le besoin de piloter la révélation de l'extérieur ;
   l'ajouter serait une extension additive, non cassante, le jour où le besoin existe.)*

### Previous Story Intelligence (su-1 — `done`, vert)

- **Consommer, ne pas refaire** : `ZFlashcardContentBuilder` + `ZFlashcardDefaultContent.builder`
  **existent** ; `ZSrsConfig` possède l'échelle **0..5** ; `ZQualityScale.fromConfig` en dérive ;
  `zSectionKey` est le constructeur canonique ; la garde de mode d'AD-34 est posée.
- **Dettes explicitement léguées à su-2** (D5 + L1) : **preuve du branchement effectif du slot**
  (AC1-d) et **vraie garde SM-1** (AC7). *Sans elles, su-2 hérite d'ACs réputés couverts qui ne le
  sont pas.*
- **Leçons de revue à ne pas rejouer** : **D4** (garde ligne-à-ligne aveugle au multi-lignes —
  scanner **par déclaration**) · **D6** (contre-preuve qui recopie le scanner — **exercer la vraie
  fonction**) · **D5** (test qui appelle sa propre closure — **zéro symbole de prod = tautologie**)
  · **D7** (branche de repli jamais atteinte — **rendre les valeurs discriminantes**) · **procédure**
  (injections R3 sur **arbre quiescent** ; **un seul `flutter test`** à la fois sur ce workspace).
- **Dette pré-existante tracée** (hors périmètre su-2, ledger su-3/su-4) :
  `z_srs_quality_buttons.dart:208` `'ok'`/`'lapse'` **en dur** dans `Semantics.value` ;
  `fontSize: 12` en dur (`:243`) ; `ZQualityScale.fromConfig` **jamais `const`** (hoister hors du
  `build()`).

### Git Intelligence

`git log` (5 derniers) : `9ea262f` bump 0.2.0→0.2.1 · `46afb56` epic **EX-UI** (`zcrud_responsive`,
`zcrud_navigation`, `zcrud_ui_kit`, `zcrud_get`) · `9e405a0` bump 0.1.0→0.2.0 · `ecd4753` +
`2df33be` (sprint-status). **Travail de su-1 non committé** (commit **en fin d'epic** — règle
projet). ⇒ **Ne PAS committer** ; **ne PAS toucher** `pubspec.lock` (racine/`example/`).
Contraintes inter-packages en **`^0.2.1`** : les nouveaux symboles sont **additifs** ⇒ aucun bump.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.2: Carte de révision adaptative`] — **spécification source des ACs** · [`#FR Coverage Map`] — frontière su-2 (aperçu) / su-8 (duplication)
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-40`] · [`#AD-45`] · [`#Invariants hérités`] · [`#Conventions`] (enums > booléens ; Reduce Motion) · [`#Placement des paquets`]
- [Source: `.../prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU1`] · [`#FR-SU21`] · [`#NFR-SU2/3/4/5/6/7`] · [`#6. Critères de succès`] (contre-métrique : aucune dépendance au-delà des trois décidées)
- [Source: `docs/parity-study-ui-2026-07-16/rapport.md#2. Matrice de parité — FLASHCARDS`] — ❌ **PERTE** « Carte de révision FLIP interactive » ; source canonique `lex_ui/.../session_flashcard_view.dart` (**fade 250 ms**, adaptée par type) · [`#5. Sources best-of-breed`] · [`#6.1`]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-1.md#D5`] · [`#LOW L1`] — **dettes léguées à su-2** · [`#D4`] · [`#D6`] · [`#D7`] — patrons de garde à ne pas rejouer
- [Source: `_bmad-output/implementation-artifacts/stories/su-1-socle-types-partages-gardes-slots.md#AC4`] — contrat + défaut du slot AD-40 livrés, **adaptateur explicitement déféré à su-2**
- [Source: `CLAUDE.md#Critical Patterns`] · [`#Key Don'ts (zcrud)`] · [`#Processus BMAD strict`] — vérif verte `analyze`/`verify` **repo-wide** avant `done`
- [Source: `_bmad-output/implementation-artifacts/sprint-status.yaml:447-454`] — workstreams (A)/(B)/(C) à **packages disjoints**

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8[1m]` — skill `bmad-dev-story` (mode non interactif).

### Debug Log References

- **Défaut a11y RÉEL démasqué par le test AC5** (corrigé, pas contourné) : le
  `Semantics(container: true)` de la carte **fusionnait tous ses descendants** —
  le lecteur d'écran aurait annoncé un unique blob « Afficher la réponse · Q ·
  Bon · Mauvais… » et le marqueur **« Bonne réponse »** du choix correct aurait
  été **enterré**, faisant perdre en pratique le **canal non-coloré** d'AD-13.
  Diagnostiqué par dump de l'arbre sémantique réel (le libellé n'était pas
  « vide » : il était concaténé). Corrigé par `explicitChildNodes: true`.
- **Artefact de harnais (test corrigé, PAS le code)** : le cas AD-10 `'# ' * 500`
  échouait sur un `RenderFlex overflow` de l'hôte de test (500 titres dépassent
  l'écran), non sur un défaut de décodage. Remplacé par des sources réellement
  mal formées et compactes (fence non fermée, table tronquée).
- **Arbitrage non interactif consigné** : le skill `bmad-dev-story` (steps 4/9)
  prescrit d'écrire `sprint-status.yaml`. **Non exécuté** — l'orchestrateur est
  seul habilité à ce fichier (option la plus conservatrice). Le `Status` de la
  story porte la transition.

### Completion Notes List

- **AC1..AC7 satisfaits** ; **AC8** vert (`generate` OK · `analyze` **RC=0
  repo-wide** · `verify` **RC=0** · tests RC=0).
- **Dettes de su-1 SOLDÉES** :
  - **D5** (« le slot est réellement branché ») — `ZFlashcardReviewCard` est le
    **premier call-site de production** du slot AD-40 : la sentinelle `INJ:`
    traverse désormais du **code de prod** sur **tous** les chemins de contenu
    (question / réponse / `ZChoice.content` / explanation). L'injection **R3-I1**
    le prouve falsifiable.
  - **L1** (« aucune closure réallouée à chaque build ») — `resolvedContentBuilder`
    est l'**unique** voie de résolution, empruntée par `build` ; `identical()`
    entre deux builds est vert et **R3-I7** le fait rougir.
- **9 injections R3 jouées réellement** (7 de la story + 2 variantes), chacune
  **rouge sur son AC cible**, toutes restaurées et vérifiées par empreinte
  SHA-256 (les fichiers étant **non suivis par git**, `git checkout` ne les
  aurait pas restaurés). **Zéro résidu** : le seul match de `Text(card.question)`
  restant est la **prose dartdoc** qui l'interdit.
- **Périmètre tenu** : aucune saisie notée / indice / minuteur (su-3) ; aucune
  duplication (su-8) ; **aucun `Dismissible`/drag horizontal** (le geste de swipe
  reste à su-4) ; **aucune écriture** dans `zcrud_core`, `zcrud_mindmap`,
  `zcrud_export`. **Aucun `pubspec.yaml` modifié** — `flip_card` absente du repo
  (garde de source posée), l'arête `zcrud_flashcard → zcrud_markdown` préexistait.
- **Ajout hors liste NEW de la story, assumé** : `lib/src/presentation/z_reduce_motion.dart`.
  L'AC3 exige une **primitive unique et réutilisable** par su-4/su-5 ; ces stories
  vivant dans d'**autres packages**, la primitive doit être **exportée** pour être
  réutilisable — un helper privé dans la carte n'aurait pas tenu l'AC. Ajout
  **additif**, aucune surface existante touchée.
- **Compteurs** : `zcrud_flashcard` **240 → 328 tests** (+88 ajoutés par su-2).

### File List

**NEW — code de production** (`packages/zcrud_flashcard/`)
- `lib/src/domain/z_reveal_transition.dart`
- `lib/src/presentation/z_flashcard_review_card.dart`
- `lib/src/presentation/z_flashcard_markdown_content.dart`
- `lib/src/presentation/z_reduce_motion.dart`

**NEW — tests** (`packages/zcrud_flashcard/test/`)
- `z_flashcard_review_card_test.dart` (AC1 + AC1-d, 19 tests)
- `z_flashcard_reveal_transition_test.dart` (AC2, 11 tests)
- `z_flashcard_reduce_motion_test.dart` (AC3, 6 tests)
- `z_flashcard_read_only_preview_test.dart` (AC4, 6 tests)
- `z_flashcard_review_card_a11y_test.dart` (AC5, 13 tests)
- `z_flashcard_rtl_guard_test.dart` (AC5, garde de source, 5 tests)
- `z_flashcard_markdown_content_test.dart` (AC6, 13 tests)
- `z_flip_card_dep_guard_test.dart` (AC2, garde de source, 5 tests)
- `z_flashcard_review_card_sm1_test.dart` (AC7, 10 tests)

**UPDATE**
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — **exports additifs seuls**.

### Change Log

| Date | Changement |
|---|---|
| 2026-07-16 | Story créée (`bmad-create-story`, mode non interactif). ACs repris de `epics.md` Story 1.2 ; périmètre vérifié sur disque (7 preuves par grep négatif) ; dettes D5/L1 de su-1 explicitement soldées par AC1-d et AC7. |
| 2026-07-16 | `bmad-dev-story` : AC1..AC8 implémentés (`ZRevealTransition`, `ZFlashcardReviewCard`, `ZFlashcardMarkdownContent`, `zReduceMotionOf`) + 9 tests neufs (88 tests). Dettes **D5** et **L1** de su-1 soldées. Défaut a11y réel corrigé (`explicitChildNodes` — marqueur non-coloré enterré par la fusion sémantique). 9 injections R3 jouées, toutes rouges puis restaurées (sha OK). Vérif verte : `generate` OK · `analyze` RC=0 repo-wide · `verify` RC=0 · tests RC=0. Statut → `review`. |
