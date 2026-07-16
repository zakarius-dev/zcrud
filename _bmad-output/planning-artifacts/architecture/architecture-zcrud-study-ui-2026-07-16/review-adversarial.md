---
title: "Revue adversariale — ARCHITECTURE-SPINE E-STUDY-UI + E-MULTI-EDIT"
target: ARCHITECTURE-SPINE.md (2026-07-16, AD-33..AD-42)
lens: "Deux stories conformes à CHAQUE AD, qui construisent pourtant des choses incompatibles"
verdict: NEEDS WORK — 3 trous HIGH bloquants avant toute story
created: 2026-07-16
---

# Revue adversariale — spine E-STUDY-UI + E-MULTI-EDIT

## Méthode

Lentille imposée : descendre d'un niveau (story), construire des **paires de stories
légitimes** — chacune respectant AD-1..AD-42 **à la lettre** — et montrer qu'elles
produisent des artefacts **incompatibles**. Chaque paire est un trou : un AD manquant
ou sous-spécifié. Toutes les paires ci-dessous sont **ancrées dans le code réel du
repo** (lu, pas supposé), pas dans des hypothèses.

**Ce qui est solide et ne doit pas bouger** : AD-33 (seam d'écriture unique) et AD-34
(zéro-SRS *par le type*, révision assumée du no-op) sont exemplaires — ils ferment
l'invariant par construction, pas par convention, et le refus de fournir un
`ZSessionReviewer` no-op est le bon appel (une valeur passable est une porte dérobée ;
un type absent n'en est pas une). AD-42 (export pur / satellite `zcrud_export_ui`) et
AD-41 (rendu borné à la cellule) tranchent des OA proprement. Les trous ci-dessous
n'attaquent pas ces décisions : ils attaquent ce que le spine **ne dit pas**.

---

## T1 — HIGH — L'échelle de qualité n'a aucun propriétaire ; AD-35 renvoie à un `ZSrsConfig` qui n'en porte pas

### Le fait

AD-35 écrit : sortie typée `{feedback, suggestedQuality (échelle ZSrsConfig), isCorrect?}`.

Or `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` **ne porte aucune
échelle** — seulement `passThreshold = 3` et les facteurs d'aisance. L'échelle réelle
vit **ailleurs**, dans la **présentation** d'un autre package :

```dart
// packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart
class ZQualityScale {
  const ZQualityScale({this.min = 0, this.max = 5})   // ← DÉFAUT 0..5
      : assert(min == 0 || min == 1, ...);
}
```

Le PRD, lui, dit **1-5** partout (glossaire §4 ; FR-SU2 « score 1-5 » ; « Je ne sais
pas » = qualité **1** ; repli neutre **3** ; FR-SU3 plancher **2**). Le memlog note
« échelle qualité zcrud = 0..5 ». **Le spine ne tranche pas** — il délègue à un
propriétaire inexistant.

### La paire

**Story A — `ZFlashcardReviewCard` (FR-SU1/2/3, `zcrud_flashcard`).** Lit le PRD, code :

```dart
void _onDontKnow() => widget.onQualitySelected(1);   // PRD FR-SU2, littéral
// AD-35 « QCM/VF exact → max sinon min » :
final q = _isExactMatch ? 5 : 1;
```

**Story B — `ZSessionCardSwiper` / notation (FR-SU6, `zcrud_session`).** Lit AD-35 et
le code existant, code :

```dart
final scale = const ZQualityScale();      // défaut du repo = 0..5
final q = _isExactMatch ? scale.max : scale.min;   // → min = 0
```

Les deux respectent **chaque** AD. La même mauvaise réponse vaut **0** chez B et **1**
chez A.

### Pourquoi c'est structurel, pas cosmétique

1. **FR-SU12 devient faux** : les seaux de maîtrise sont « mauvais = q1-2 **ou jamais
   vue** / bon = q3 / maîtrisé = q4-5 ». Une carte notée **0 n'appartient à aucun
   seau** — elle n'est ni « jamais vue » (elle a une répétition) ni « mauvaise ». Elle
   **disparaît** des filtres test/examen et fausse les stats FR-SU8 et le décompte
   « Encore N dues ». Un `switch` sur les seaux tombera dans un `default` muet.
2. **Le graphe interdit à A d'importer l'échelle de B.** L'arête réelle du pubspec est
   `zcrud_session → zcrud_flashcard` (`z_session_reviewer.dart` importe
   `ZRepetitionInfo`). `ZQualityScale` est **en aval** de `ZFlashcardReviewCard`.
   Story A **ne peut pas** la réutiliser sans inverser le graphe (AD-1). Elle
   redéclarera donc légitimement sa propre échelle dans `zcrud_flashcard` →
   **deux définitions du même concept**, aucune ne violant un AD.

### Règle à ajouter (AD-43 proposé)

- **Une seule value-object d'échelle**, dans le **domaine** de `zcrud_flashcard` (en
  amont de `zcrud_session`), **portée par `ZSrsConfig`** : `ZSrsConfig.scale`,
  `.neutralQuality`, `.hintFloor`. `ZQualityScale` de `zcrud_session` devient un
  **ré-export**, jamais un doublon. AD-35 doit citer un propriétaire qui **existe**.
- **Tout littéral de qualité est interdit dans une story** : jamais `1`, `3`, `5` en
  dur — `config.scale.min/max`, `config.neutralQuality`, `config.passThreshold`
  (précédent déjà en vigueur : `ZSrsQualityButtons` interdit `3` en dur, D5/AC6).
- **Trancher min = 0 ou min = 1 dans le spine**, explicitement, et **amender le PRD
  ou les seaux FR-SU12** pour couvrir la borne basse de façon exhaustive (aucune
  qualité de l'échelle ne doit tomber hors seau).

---

## T2 — HIGH — AD-40 s'appuie sur un graphe de paquets **faux** : `zcrud_flashcard` tire déjà Quill en dur

### Le fait

AD-40 — *« Prevents : `zcrud_flashcard`/`zcrud_mindmap` qui tirent Quill »*. C'est
**déjà consommé** :

```yaml
# packages/zcrud_flashcard/pubspec.yaml
  zcrud_markdown: ^0.2.1      # → flutter_quill ^11.5.0 + flutter_math_fork ^0.7.4
  zcrud_export: ^0.2.1
# packages/zcrud_mindmap/pubspec.yaml
  zcrud_markdown: ^0.2.1
```

Et l'arête est **revendiquée comme un acquis AD-1**, pas subie :

```dart
// packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart
/// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_markdown`.
static const String markdownApiVersion = ZMarkdownApi.version;
```

Le mermaid du spine dessine `md -. "adaptateurs injectables (AD-40)" .-> flash` —
**pointillé, injection**. La réalité est une **arête dure de pubspec**. Le spine décrit
un graphe qui n'est pas celui du repo.

### La paire

**Story A — `ZFlashcardReviewCard` (FR-SU1).** Raisonnement imparable : « la dépendance
`zcrud_markdown` est là, elle est **déclarée arête AD-1 légitime**, le graphe reste
acyclique, FR-SU1 exige un rendu riche » → importe `ZMarkdownReader` directement,
rendu riche **par défaut, sans slot**. Ne viole **aucun AD** littéralement.

**Story B — `ZFlashcardListView` (FR-SU14, « question riche tronquée »).** Suit AD-40 →
slot injectable, **défaut texte brut thématisé**, adaptateur fourni par
`zcrud_markdown`.

Résultat : **deux contrats de rendu du même contenu dans le même package**. Le
consommateur qui n'injecte rien voit du markdown rendu dans la carte de révision et du
texte brut dans la liste — incohérence visuelle qu'aucune revue de story ne verra
(chaque story est conforme, isolément).

### Aggravant : NFR-SU7 est déjà en échec

« aucun nouveau package tiers dans `zcrud_core` » est tenu, mais l'intention réelle
(« qui ne veut pas de Quill n'en tire pas ») est **déjà morte** : toute app qui dépend
de `zcrud_flashcard` — c'est-à-dire **tout consommateur d'étude** — tire `flutter_quill`
transitivement, **pour un marqueur de version** (`ZFlashcardApi.markdownApiVersion`).
AD-40 prétend prévenir un état déjà atteint.

### Règle à ajouter (AD-40 renforcé)

1. **Supprimer les arêtes `zcrud_flashcard → zcrud_markdown` et
   `zcrud_flashcard → zcrud_export`** (elles n'existent que pour un `static const
   String` de marqueur) — ou les **reclasser explicitement** dans le spine, en assumant
   par écrit que Quill est transitif pour tout consommateur d'étude. Le statu quo — un
   AD qui interdit ce que le pubspec fait — est le pire des trois.
2. **Rendre la règle vérifiable par machine**, sur le patron du gate
   `anti-reflectable` : `import package:zcrud_markdown` **interdit hors des packages
   d'adaptateurs**. Un AD non gaté sur ce point sera contourné par la première story
   pressée, en toute bonne foi.
3. **Corriger le mermaid** : distinguer arête dure et injection — un diagramme qui ment
   sur le graphe est un piège pour chaque story qui le lit.
4. **Nommer le type du payload du slot.** `ZMindmapMarkdownContent.builder(slotKey:)`
   lit un Delta dans `node.extra[slotKey]` (canal AD-4) ; `ZFlashcard.question` est un
   **`String` nu** (aucun type rich-text, malgré AD-28 « contenus rich-text typés »).
   Deux adaptateurs, **deux signatures inconciliables** : `zcrud_markdown` ne pourra
   pas les factoriser. Trancher la forme du contenu de carte **avant** FR-SU1.

---

## T3 — HIGH — AD-38 réinvente une entité qui **existe déjà** et livrée

### Le fait

AD-38 : *« l'ordre manuel est une **entité séparée générique** `{scopeId,
Map<sectionKey, List<id>>}` »*. Le memlog va plus loin : `ZContentOrder{scopeId}`,
« dé-flashcardisée ».

Cette entité **existe**, complète, testée, gatée, dans `zcrud_study_kernel` :

```dart
// packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart
@ZcrudModel(kind: 'folder_contents_order')
class ZFolderContentsOrder with ZExtensible {
  final String folderId;                                  // ← scopeId, déjà opaque
  Map<String, List<String>> get sectionOrders => ...;      // canal hors-codegen, clé réservée
  List<T> applyTo<T>(String sectionKey, Iterable<T> items, {required String Function(T) idOf, ...});
}
```

avec `applyOrder<T>` (pur, total, stable, générique de collection — `apply_order.dart`),
l'égalité D5, la garde d'immuabilité profonde, le gate `reserved-keys`. **AD-38 ne le
mentionne pas.** Un lecteur du spine ne peut pas deviner que la décision est déjà
implémentée.

### La paire

**Story A — `ZFlashcardListView`, tri « ordre manuel persisté » (FR-SU14).** Explore le
repo, trouve l'entité, réutilise :
`order.applyTo('flashcard/$subId', cards, idOf: (c) => c.id!)`.

**Story B — « ordre manuel générique » (lecture littérale d'AD-38 + memlog).** Crée
`@ZcrudModel(kind: 'content_order') class ZContentOrder { final String scopeId; ... }`
+ son `applyTo`. Conforme à AD-38, AD-4, AD-9/AD-19, AD-21 — **conforme à tout**.

Résultat : **deux `kind` persistés pour la même donnée**, deux collections, deux voies
d'écriture. L'ordre écrit depuis la liste de flashcards est **invisible** pour la
mindmap et réciproquement. Exactement le « deux propriétaires d'une même entité » que
le spine est censé prévenir.

### Aggravant : `sectionKey` n'a **aucun constructeur canonique**

Le format `'<kind>'` / `'<kind>/<subFolderId>'` ne vit **que dans une doc-string** (et
dans le memlog). Aucune fonction ne le produit. Deux stories fabriqueront la clé à la
main :

```dart
// Story A                          // Story B
'flashcard/$subFolderId'            'flashcards/$subFolderId'
```

Et **rien ne le détectera** : `applyOrder` est **total et défensif par conception** —
une section inconnue ⇒ ordre d'entrée préservé, **aucune erreur, aucun log**. L'ordre
personnel de l'utilisateur est silencieusement ignoré, en production, sans test rouge.
La qualité même de `applyOrder` (totalité) rend la divergence **invisible**.

### Règle à ajouter (AD-38 amendé)

- **L'entité est `ZFolderContentsOrder`, existante.** Interdiction d'un second type.
  La généricité est atteinte **sans renommage** (`folderId` est déjà un id opaque =
  `scopeId`) ; si le renommage est voulu, c'est une **story de migration explicite**
  (kind persisté + adapter, patron AD-27), jamais un effet de bord d'une story UI.
- **`sectionKey` est produit par une fonction pure unique exportée** —
  `zSectionKey(kind, {subFolderId})` — **littéral de clé interdit** dans les stories.
  Sans cela `reorderSection` n'a de sémantique partagée pour personne.
- **Nommer le port propriétaire de `reorderSection(scopeId, sectionKey, orderedIds)`**
  (`ZStudyRepository`) : il **n'existe nulle part** aujourd'hui. Deux stories
  l'inventeront chacune, avec deux signatures.

---

## T4 — MEDIUM-HIGH — Le plafond d'indices : deux chemins de mutation du même grade

### Le fait

AD-36 : *« chaque indice abaisse d'un cran la **qualité maximale attribuable**
(plancher configurable) ; le nombre d'indices est **aussi transmis au port** »*.
AD-35 : le port rend `suggestedQuality`, **advisory**, qui **pré-sélectionne** un
bouton. Le spine dit *« pénalité locale et unique »* — mais **ne nomme aucun
propriétaire**.

### La paire

**Story A — `ZFlashcardReviewCard`, indices (FR-SU3).** Applique le plafond à l'UI :

```dart
final cap = scale.max - hintsUsed;      // AD-36, « abaisse d'un cran »
// boutons > cap désactivés ; onQualitySelected(min(q, max(cap, floor)))
```

**Story B — adaptateur du port d'évaluation (AD-35).** Le contrat lui **donne**
`hintsUsed` ; elle en fait légitimement usage :

```dart
// suggestedQuality déjà pénalisée : l'IA sait que 2 indices ont été utilisés
return ZAnswerEvaluation(feedback: ..., suggestedQuality: 3, isCorrect: true);
```

**Deux issues, toutes deux mauvaises** :
- les deux appliquent → **double pénalité**, non reproductible d'une app à l'autre
  (l'adaptateur est app-side : IFFD pénalise, lex non) ;
- chacune suppose que l'autre le fait → **aucune pénalité**. FR-SU3 est muet et
  **aucun test ne le voit** : le plafond n'est écrit nulle part comme une fonction
  nommée qu'on puisse tester.

Le trou est exactement l'ambiguïté de « transmis au port » : *pour informer le
feedback* ou *pour pénaliser* ? Les deux lectures sont raisonnables.

### Règle à ajouter (AD-36 renforcé)

- **Le plafond est une fonction pure unique** — `zCapQualityForHints(quality, hintsUsed,
  floor)` — du domaine flashcard, appelée **exactement une fois**, **en aval du port**
  et **en amont du seam `ZSessionReviewer`** (le seul point que tout grade traverse,
  AD-33). L'UI **affiche** le plafond, ne le calcule pas.
- **Le contrat du port est explicite** : `hintsUsed` est fourni **pour le feedback
  pédagogique** ; `suggestedQuality` est **par contrat non pénalisée** — le clamp
  n'est jamais du ressort du port (cohérent avec « advisory strict » : un port qui
  pénalise, décide).
- **Trancher le propriétaire de `floor`** : le PRD dit « via la config de session »
  (⇒ `ZStudySessionConfig`, kernel, qui n'a pas le champ) ; T1 propose `ZSrsConfig`
  (flashcard, avec l'échelle). Sinon deux stories l'ajoutent aux **deux** endroits —
  et les deux valeurs divergeront (cf. T8).

---

## T5 — MEDIUM — « QCM/VF évalués localement » ne couvre que **2 des 6** types canoniques

### Le fait

```dart
// packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart
enum ZFlashcardType { multipleChoice, trueOrFalse, openQuestion, exercise, fillBlank, shortAnswer }
```

AD-35 tranche : *« QCM/VF évalués localement (déterministe, hors ligne) »* ; replis :
*« QCM/VF exact → max sinon min ; rédigée → qualité neutre »*. **`fillBlank` et
`shortAnswer` ne sont ni l'un ni l'autre.** Le PRD FR-SU2 n'énumère que QCM / V-F /
ouverte / exercice (héritage IFFD : 4 types) — zcrud en a **6**.

### La paire

**Story A — `ZFlashcardReviewCard` (FR-SU2).** `fillBlank` a une réponse attendue
exacte ⇒ évaluation locale déterministe (comparaison normalisée), hors ligne, ce qui
**sert** NFR-SU8. Conforme.

**Story B — adaptateur/port d'évaluation.** `fillBlank` = « réponse rédigée » ⇒ appel
port, repli **qualité neutre**. Conforme aussi.

Même carte, même réponse : **max/min** chez A, **neutre** chez B. Et le comportement
hors ligne diverge (A fonctionne, B retombe sur le repli). Aucun AD ne tranche.

### Règle à ajouter

- **La locale-évaluabilité est une propriété du type, déclarée une seule fois** :
  prédicat/table unique `zIsLocallyEvaluable(typeKey)` — ou, pour rester ouvert (AD-4),
  une `ZAnswerEvaluationStrategy` par type au registre. **Énumérer les 6 types
  exhaustivement dans le spine** (un `switch` exhaustif sur l'enum, pas une prose à
  deux exemples).
- **Préciser la normalisation** du « exact » (casse / accents / espaces) et
  **réutiliser** celle de la recherche FR-SU14 (« recherche normalisée, insensible
  accents/espaces ») plutôt que d'en écrire une seconde — sinon deux notions de
  « égal » cohabiteront dans le même package.

---

## T6 — MEDIUM — AD-37 « preview → commit » : commit **client** ou commit **backend** ? Deux cycles de vie

### Le fait

AD-37 : *« Résultat = cartes **éphémères** (ni id ni source du backend) + tags
suggérés, matérialisées **côté client** après revue (preview → commit) »*.
Le memlog (fait lex) : *« flux 2-phases `generatePreview → commitPreview(tagIds)` »* —
un **appel backend** qui matérialise et décompte le quota.

« preview → commit » désigne donc **deux mécanismes opposés** selon la phrase qu'on lit.

### La paire

**Story A — `ZFlashcardGenerationSheet` (FR-SU15).** Porte le flux 2-phases dans le
port : `commitPreview(tagIds)` = 2e appel. Les cartes existent **côté serveur** dès la
feuille de confirmation de tags.

**Story B — `ZMultiFlashcardEditor` (FR-SU20).** « toutes les modifications
s'appliquent immédiatement à une **liste de travail en mémoire** — **rien n'est
persisté avant la sauvegarde finale groupée explicite** » ; les cartes générées « sont
ajoutées à la liste de travail pour revue ».

**Le scénario qui casse** : générer depuis le multi-éditeur → confirmer les tags →
**abandonner** via `ZDiscardChangesGuard`. B croit tout jeté ; A a persisté. Le
garde-fou d'abandon **ment**, et FR-SU20 promet explicitement le contraire. Deux
propriétaires du cycle de vie de la même entité.

**Second front** : deux voies d'application des tags — la « feuille de confirmation de
tags » (FR-SU15) et le panneau « appliquer à la sélection (tags…) » (FR-SU20). Les deux
écrivent `tagIds` sur des cartes qui n'ont pas le même statut de persistance.

### Règle à ajouter (AD-37 amendé)

- **Trancher : `commit` est client-side, point.** Le port ne fait que **`preview`** ;
  **toute** matérialisation passe par le repository normal — donc par le brouillon
  FR-SU20 et sa sauvegarde groupée. C'est la seule lecture compatible avec
  « éphémères » + FR-SU20 + `ZDiscardChangesGuard`.
- Si un backend **impose** un `commitPreview` (quota), il est modélisé comme un **port
  de quota/confirmation qui ne persiste aucune carte**, et le contrat le dit
  explicitement — « ce port n'écrit jamais de carte » est la sœur de la clause
  advisory d'AD-35, et mérite le même traitement.
- **Une seule voie d'application des tags suggérés** : la liste de travail.

---

## T7 — MEDIUM — AD-39 : la borne ≤ 450 d'AD-21 **ne compose pas** sur un lot

### Le fait

AD-21 : cascade déclarative **bornée ≤ 450 écritures/lot**. AD-39 : *« toute suppression
— **unitaire comme par lot** — passe par la cascade AD-21, **awaited**, avec **rapport
d'échecs par élément** »*. Le spine ne dit **pas qui planifie ni qui découpe**.

### La paire

**Story A — FR-SU19 « supprimer les N sélectionnés »** (`zcrud_list`/`zcrud_core`).
Lecture littérale d'AD-39 : boucle sur N cascades unitaires, awaited, un rapport par
élément :

```dart
for (final id in selectedIds) {          // N = 200
  final r = await cascade.deleteFlashcard(id);   // 200 allers-retours séquentiels
  report[id] = r;                                 // ← rapport par élément : facile
}
```
⇒ UI figée, 200 round-trips, et la borne ≤ 450 **jamais atteinte par cascade** donc
jamais évaluée globalement.

**Story B — cascade dossier existante (AD-21).** Un **plan unique borné**, tranches
atomiques :

```dart
final plan = registry.planFor(kind: 'flashcard', ids: selectedIds);  // 200 cartes + repetitions
await store.runBatched(plan, maxWrites: 450);   // ← une tranche échoue → EN BLOC
```
⇒ borne respectée, mais le **« rapport d'échecs par élément » est impossible à
produire** : un lot Firestore échoue **atomiquement**, on ne sait pas *quel élément* a
fauté.

**Les deux exigences d'AD-39 — « cascade AD-21 bornée » et « rapport par élément » —
sont en tension**, et le spine les juxtapose sans arbitrer. Chaque story résoudra la
tension dans le sens de sa facilité.

### Règle à ajouter (AD-39 amendé)

- **Un plan de cascade unique pour les N ids** (jamais N plans), produit par
  `ZCascadeRegistry`, propriété du **kernel** (jamais de la liste).
- **Découpage en tranches ≤ 450 à sémantique écrite** : chaque tranche est atomique ;
  l'échec d'une tranche marque **tous ses éléments** en échec dans le rapport (le
  rapport est *par élément* en **lecture**, *par tranche* en **granularité réelle** —
  le dire, plutôt que de laisser croire à un échec isolable).
- **Idempotence du rejeu** : le soft-delete `is_deleted` (AD-9) la garantit — l'écrire,
  sinon une story « réessayer les échecs » double-supprimera.

---

## T8 — MEDIUM — `ZStudySessionConfig` (AD-24, « forme unique ») est un **hub partagé** par 4 stories réputées parallèles

### Le fait

Forme actuelle (`zcrud_study_kernel`) :

```dart
@ZcrudField(defaultValue: ZReviewMode.spaced) final ZReviewMode mode;
@ZcrudField() final String? folderId;
@ZcrudField() final List<String>? tagIds;
@ZcrudField() final List<String>? types;    // clés opaques camelCase (typeKey)
@ZcrudField() final int? count;
```

Veulent **toutes** y ajouter un champ : FR-SU3 (plancher d'indices — « via la config de
session »), FR-SU10 (taille de lot, défaut 30), FR-SU12 (niveaux de maîtrise **et**
sources), FR-SU5 (défaut d'avance par mode).

Or le spine déclare **E-STUDY-UI « additif, satellites uniquement »** et
**E-MULTI-EDIT « seul epic autorisé à écrire dans le cœur »** ; la règle de
sérialisation (CLAUDE.md) ne protège que **`zcrud_core`**. **Le kernel est le hub réel
et il n'est protégé par rien.**

### La paire

**Story A — filtres FR-SU12.** AD-24 (« forme domaine-pur **unique** ») ⇒ champs typés :

```dart
@ZcrudField() final List<String>? masteryLevels;
@ZcrudField() final List<String>? sourceKinds;
```

**Story B — n'importe quelle autre.** AD-4 (« extension par composition + slots
`extension`/`extra` », **explicitement recommandé** pour l'additif) ⇒ :

```dart
config.copyWith(extra: {'mastery_levels': [...]});
```

**Même concept, deux formes persistées**, `_reservedKeys` divergents (celles de A
deviennent réservées, celles de B non), **round-trip cassé** pour l'autre — et deux
stories parallèles éditant le même fichier codegen + son `.g.dart` committé.

AD-24 et AD-4 se contredisent ici, et le spine hérite des deux sans arbitrer la
frontière : *quand un champ mérite-t-il le codegen plutôt qu'`extra` ?*

### Règle à ajouter

- **`zcrud_study_kernel` est un second hub sérialisé** : une seule story à la fois y
  écrit — étendre la clause de parallélisation (aujourd'hui : « le seul point de
  contact possible = `zcrud_core` »), qui est **factuellement fausse** pour ces epics.
- **Trancher la forme finale de `ZStudySessionConfig` pour les 4 FR d'un coup**, dans
  une **story de schéma préalable**, avant toute story UI. Sinon la « forme unique »
  d'AD-24 sera atteinte par quatre chemins.
- **Écrire la frontière AD-24 ↔ AD-4** : champ typé si zcrud le lit/valide ; `extra`
  si seule l'app le lit. Sans ce critère, chaque story choisira au ressenti.

### Note satellite (LOW, même racine)

AD-37 dit `typesDistribution` sans nommer le **vocabulaire des clés**. Le précédent
kernel est net (`ZSessionCandidate.typeKey` = clé **opaque camelCase**,
`config.types: List<String>`, « l'ergonomie typée `ZFlashcardType` est restituée côté
`zcrud_flashcard` »). Une story FR-SU15 écrira `Map<ZFlashcardType, int>` (elle est
dans `zcrud_flashcard`, le type est là), une story FR-SU12 `List<String>`. Le
rattraper d'une phrase dans AD-37 : **`Map<typeKey, int>`, univers = les 6 types
canoniques**, la répartition équitable se calcule sur cet univers.

---

## Synthèse

| # | Trou | Sévérité | AD visé |
|---|---|---|---|
| T1 | Échelle de qualité sans propriétaire (`ZSrsConfig` n'en porte pas ; `ZQualityScale` 0..5 est en aval et inatteignable ; PRD dit 1..5 ; q=0 hors seaux FR-SU12) | **HIGH** | AD-35 → **AD-43 neuf** |
| T2 | AD-40 interdit ce que le pubspec fait déjà (`zcrud_flashcard`/`zcrud_mindmap` → `zcrud_markdown` → Quill) ; mermaid faux ; payload du slot non typé | **HIGH** | AD-40 renforcé + gate |
| T3 | AD-38 réinvente `ZFolderContentsOrder` (existant, gaté) ; `sectionKey` sans constructeur canonique → divergence **silencieuse** (`applyOrder` est total) ; `reorderSection` sans propriétaire | **HIGH** | AD-38 amendé |
| T4 | Plafond d'indices : UI **et** port peuvent légitimement l'appliquer → double pénalité ou aucune ; propriétaire du `floor` non tranché | MEDIUM-HIGH | AD-36 renforcé |
| T5 | « QCM/VF localement » ne couvre que 2 des **6** types ; `fillBlank`/`shortAnswer` orphelins → même carte notée max/min ou neutre | MEDIUM | AD-35 exhaustif |
| T6 | « preview → commit » = commit client (spine) **ou** backend (lex) → cartes persistées malgré `ZDiscardChangesGuard` ; deux voies de tags | MEDIUM | AD-37 amendé |
| T7 | « cascade bornée ≤450 » **et** « rapport par élément » en tension, non arbitrée → N plans séquentiels vs 1 plan atomique | MEDIUM | AD-39 amendé |
| T8 | `ZStudySessionConfig` = hub non protégé (4 FR y écrivent) ; AD-24 (champ typé) vs AD-4 (`extra`) non arbitrés ; vocabulaire `typeKey` d'AD-37 flou | MEDIUM | AD-24/AD-4 + clause de parallélisation |

**Verdict** : le spine tranche bien les OA et ses seams d'écriture (AD-33/34) sont
exemplaires ; mais **T1/T2/T3 le rendent non implémentable en parallèle en l'état** —
chacun produit deux artefacts incompatibles à partir de stories toutes conformes.

**Trois de ces trous ont la même racine** : le spine décrit un état du repo qui n'est
pas l'état réel (échelle inexistante chez son propriétaire déclaré, arête Quill déjà
dure, entité d'ordre déjà livrée). Une passe de **confrontation du spine au code** —
et non aux seuls faits lex/IFFD du memlog, qui sont eux très bien tenus — est le
correctif le plus rentable avant `create-story`.
