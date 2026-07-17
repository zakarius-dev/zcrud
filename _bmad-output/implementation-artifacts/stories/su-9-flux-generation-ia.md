---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story SU-9 : Flux UI de génération IA (sheet + confirmation de tags)

Status: review

<!-- Source : epics-zcrud-study-ui-2026-07-16/epics.md § Story 1.9 (Epic 1 E-STUDY-UI) -->

## Story

As an **utilisateur**,
I want **générer un lot de flashcards depuis un document, des sujets ou un texte, puis confirmer les tags proposés**,
so that **je crée mes cartes sans tout saisir à la main — sans qu'aucune carte ne soit persistée avant ma revue**.

**Couvre :** FR-SU15 · **Taille :** L · **Dépend de :** su-8 (livrée), consomme su-1..su-8 · **Séquence :** A (flashcard/session), après su-8

---

## Contexte livré à CONSOMMER (ne pas refaire — vérifié sur disque)

| Acquis | Vérifié | Emplacement / contrat réel |
|---|---|---|
| `ZFlashcardGenerationPort` (seam IA neutre) | ✅ | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:89` — `abstract interface class`, une méthode `Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest)`. **`ZResult<T> = Either<ZFailure, T>`** (jamais une `List` nue, jamais un `Stream`). Aucune impl de référence : l'app *implements* app-side (AD-15/AD-35). |
| `ZFlashcardGenerationRequest` (DTO) | ✅ | même fichier `:33` — champs ACTUELS : `content:String`, `count:int?`, `languageTag:String?`, `provenance:ZFlashcardSource?`, `extra:Map` (normalisé AD-19.1). **`==`/`hashCode` par valeur.** ⚠️ **NE PORTE PAS `typesDistribution`/`instructions`/`modelId`** (greps négatifs joués : RC=1 pour les trois). |
| `ZFlashcardSource` (provenance registre AD-4) | ✅ | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` — `sealed` interne + variants `ZNoteSource`/`ZConversationSource`/`ZDocumentSource`/`ZCustomSource` ; ouverture inter-package via `ZSourceRegistry.register(kind, fromJson, toJson)`. |
| `ZSourceRegistry` (registre ouvert AD-4) | ✅ | `packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart:23` — `extends ZOpenRegistry` ; `register`/`isRegistered`/`kinds`/`codecFor`(throw)/`tryCodecFor`(→null). **Instance injectée via `ZcrudScope`/binding** (pas de singleton statique). |
| `ZFlashcardType` (6 valeurs) | ✅ | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart:20` — `multipleChoice, trueOrFalse, openQuestion, exercise, fillBlank, shortAnswer` ; repli défensif `openQuestion` (AD-10). |
| `ZFlashcardReviewCard` (su-2) | ✅ | `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart` — **SEULE** surface de rendu d'aperçu. |
| `ZFlashcardPreview` (su-2) | ✅ | `packages/zcrud_study/lib/src/presentation/z_flashcard_preview.dart:75` — **délègue** à `ZFlashcardReviewCard`, ne rend RIEN lui-même. **L'aperçu du lot généré passe par lui (jamais un rendu parallèle).** |
| Éditeur/chips de tags (ES-8.1) | ✅ | `packages/zcrud_study/lib/src/presentation/z_tag_editor.dart` (`ZTagEditor`, `existingTags:List<ZFlashcardTag>`, callbacks create/apply/delete) + `z_tag_chips.dart`. **À réutiliser** pour la confirmation de tags — jamais un second éditeur. |
| Gardes de package `zcrud_study` (su-8) | ✅ | `packages/zcrud_study/test/presentation/z_widgets_purity_test.dart` + `z_widgets_hardcode_scan_test.dart` (règle `fontSize:` ajoutée en su-8) + `z_flashcard_contrast_test.dart` + `z_flashcard_a11y_test.dart`. Elles scannent `Directory('lib/src/presentation')` du package ⇒ **couvriront automatiquement** les nouveaux widgets. **Étendre, ne pas dupliquer.** |
| `ZFlashcard` (id/isReadOnly/copyWith) | ✅ | `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` — `id:String?` (`:134`), `isReadOnly:bool` (`:185`), `copyWith(... id ...)` (`:277`), `source:ZFlashcardSource?`. |

**LECTURE SEULE (patrons à copier, jamais modifier) :** `/home/zakarius/DEV/lex_douane`, `/home/zakarius/DEV/iffd`, `docs/parity-study-ui-2026-07-16/annexes/lex_flashcards.md` (best-of-breed : `flashcard_generation_sheet.dart` slider 1..50 + `FilterChip` par type + `distributeTypes` ; `flashcard_tag_confirm_sheet.dart` pré-cochage éditable ; `flashcard_generation_controller.dart` anti-double-tap + `Either.fold` + erreurs typées).

---

## Décision d'architecture TRANCHÉE (écarts vs les acquis — non-interactif, option conservatrice)

1. **La requête d'union AD-37 est OBLIGATOIRE ⇒ on ÉTEND `ZFlashcardGenerationRequest` (in-place, additif).**
   Le DTO existant (ES-9.1) est minimal ; la ligne du sprint-status et **AD-37** exigent
   `{source, count borné, typesDistribution, language, instructions?, modelId: String?}`. On **ajoute
   trois champs OPTIONNELS** (`typesDistribution:Map<ZFlashcardType,int>?`, `instructions:String?`,
   `modelId:String?`) à `ZFlashcardGenerationRequest`, on met à jour `==`/`hashCode`. **Additif ⇒ zéro
   rupture** pour l'unique consommateur (la signature du port est inchangée). ⚠️ **Rejeté** : transporter
   ces champs canoniques via `extra` (violerait « source unique » d'AD-37 et masquerait le contrat
   opaque de `modelId` ; `extra` est l'échappatoire non typée, pas le lieu d'un champ canonique).
2. **`modelId` reste `String?` OPAQUE.** zcrud le **transporte sans jamais l'interpréter** : aucun
   `switch`, aucune enum, aucun catalogue, aucun libellé dans zcrud (catalogue = app-side).
3. **`count` BORNÉ + défaut de `typesDistribution` = SOURCE UNIQUE, dans le DOMAINE (pur, testable).**
   Nouveau module pur `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart` :
   bornes `[1, 50]` (parité lex : slider 1..50), `zClampGenerationCount`, `zEvenTypesDistribution`
   (répartition équitable pure, reste distribué déterministement), `zNormalizeTypesDistribution`.
   **Aucune** logique de bornage/répartition dupliquée dans un widget (garde de source unique).
4. **La vue vit dans `zcrud_study`** (`lib/src/presentation`), comme su-8 : contrainte de graphe — le
   port `ZFlashcardGenerationPort` vit dans `zcrud_study`, et `zcrud_study` est déjà un package de
   **présentation** (`sdk: flutter` déclaré). Aucune nouvelle arête de graphe (déps déjà présentes :
   `zcrud_core`, `zcrud_flashcard`, `flutter`).
5. **Le résultat est remis à l'APPELANT via callback ; su-9 ne persiste RIEN.** Le port ne retourne
   que `List<ZFlashcard>` — les **tags suggérés** ne sont pas un canal séparé du port : ils sont
   fournis par l'app (suggestion IA = app-side, AD-15) à la feuille de confirmation, laquelle produit
   l'ensemble confirmé remis à l'appelant avec les cartes éphémères. **Rejeté** : élargir la signature
   du port (hors périmètre — le port EXISTE, on ne le refactore pas).
6. **État de contrôleur = ENUM, pas des booléens** (AD-2 réactivité Flutter-native).
   `ZFlashcardGenerationController extends ChangeNotifier` (pur-Flutter, **aucun** gestionnaire d'état) ;
   statut `enum ZFlashcardGenerationStatus { idle, generating, preview, confirmingTags, failed }`.

---

## Acceptance Criteria

### AC1 — Requête d'union canonique AD-37 (le DTO porte les 6 dimensions)
**Given** la feuille de génération
**When** l'utilisateur configure sa demande et la soumet
**Then** la requête transmise au port est un `ZFlashcardGenerationRequest` portant
`{content (source), count, languageTag, typesDistribution, instructions, modelId, provenance}`
**And** la `provenance`/source provient du **registre `ZSourceRegistry`** (AD-4 : document/pages,
sujets, texte libre, article, note, conversation…), **extensible sans toucher zcrud**
**And** un test construit une requête avec les trois nouveaux champs et vérifie qu'ils y sont portés
**par valeur** (`==`/`hashCode` inclus les nouveaux champs — deux requêtes ne différant que par
`modelId`/`typesDistribution`/`instructions` ne sont **pas** égales).

### AC2 — `modelId` OPAQUE : transporté, jamais interprété
**Given** un `modelId` arbitraire fourni par l'app (ex. `"router:xyz-42/experimental"`)
**When** la requête est construite et transmise au port
**Then** `request.modelId` vaut **exactement** la chaîne fournie (round-trip verbatim, aucune
normalisation)
**And** zcrud ne l'interprète jamais : **grep négatif prouvé** — aucun `enum`/`switch`/catalogue de
modèle dans `z_flashcard_generation_port.dart` ni dans le contrôleur/feuille (garde de source :
`grep -qiE 'enum .*[Mm]odel'` ⇒ RC=1). Le type reste `String?` — **une garde rougit si `modelId`
devient une enum ou un type fermé** (un test passe une chaîne opaque inédite ; si le champ devenait
une enum, la valeur ne pourrait plus être portée — doublé du grep structurel car « casser la
compilation ne prouve rien »).

### AC3 — `count` BORNÉ, défaut de `typesDistribution` = source unique (AD-10, jamais de throw)
**Given** aucune `typesDistribution` fournie
**When** la requête est construite
**Then** le défaut est une **répartition équitable pure** calculée par `zEvenTypesDistribution(count,
types)` — **source unique** (garde : aucune seconde implémentation de répartition dans un widget)
**And** `count` est borné par `zClampGenerationCount` dans `[1, 50]` : `0 → 1`, `-5 → 1`,
`10000 → 50`, `null → défaut consigné (10)`, **sans jamais lever** (AD-10)
**And** la somme de la répartition par défaut **égale** le `count` borné (reste réparti
déterministement sur les premiers types).

### AC4 — `typesDistribution` incohérente : normalisée, jamais de throw
**Given** une `typesDistribution` fournie dont la somme ≠ count, ou contenant un type inconnu, ou une
valeur négative
**When** la requête est normalisée par `zNormalizeTypesDistribution`
**Then** la map résultante est cohérente : valeurs négatives ramenées à `0`, types hors des 6
`ZFlashcardType` **écartés**, et — décision tranchée — **la distribution fournie fait foi** : le
`count` effectif = somme (bornée) des valeurs retenues (aucune divergence silencieuse, aucun throw).

### AC5 — Cartes ÉPHÉMÈRES ; RIEN n'est persisté (AD-37/AD-43) — frontière DÉCLARÉE
**Given** un lot généré (le port a répondu `Right(cards)`)
**When** les cartes sont remises à l'appelant
**Then** elles sont **éphémères** : `id == null` sur **chaque** carte (jamais un id backend), la
`source` n'est **estampillée que depuis `request.provenance`** (jamais une source backend), et elles
sont remises via un **callback** `onGenerated(List<ZFlashcard>, confirmedTags)` — **jamais** persistées
silencieusement (typiquement consommées par le multi-éditeur FR-SU20)
**And (STRUCTUREL)** : la feuille/le contrôleur de génération **n'importe aucun** store/repository —
**grep négatif prouvé** sur `z_flashcard_generation_sheet.dart` + `z_flashcard_generation_controller.dart`
+ `z_flashcard_tag_confirm_sheet.dart` : aucun `ZRepository`/`ZLocalStore`/`ZRemoteStore`/`save`/
`persist`/`commit`-vers-store (`grep -qiE 'Repository|LocalStore|RemoteStore|\.save\(|persist'` ⇒ RC=1) ;
la garde `z_widgets_purity_test.dart` (su-8) est **étendue** pour couvrir explicitement ces fichiers.
**And (COMPORTEMENTAL, avec espion PROUVÉ captant — leçon su-7)** : un test injecte un **espion
repository** joignable via `ZcrudScope` ; **étape 1 — témoin positif** : le test appelle
directement `spy.save(card)` et assère `spy.writes == 1` (**sans ce 1, le 0 qui suit ne vaut rien**) ;
**étape 2** : génération complète → confirmation de tags → **abandon** (fermeture de la feuille) ⇒
`spy.writes` **inchangé** (aucune écriture ajoutée par su-9). L'app tuée en cours ⇒ rien (corollaire
de l'absence structurelle de tout store dans la voie).

### AC6 — AUCUNE voie de fuite du résultat éphémère (leçon su-8 : fermer TOUTE voie)
**Given** un résultat éphémère
**When** on balaye **toutes** les voies possibles de fuite en base
**Then** aucune n'existe : (a) pas de `onDuplicate` persistant ; (b) `copyWith` sur une carte générée
**conserve `id == null`** (un test le prouve : `copyWith(tags:)` post-confirmation ne matérialise
jamais d'id) ; (c) aucun `save` implicite sur `dispose`/`didUpdateWidget`/route pop ; (d) une **réponse
tardive du port** (feuille déjà fermée) n'écrit rien (cf. AC8, jeton de fraîcheur) ; (e) le callback
de handoff est le **seul** canal de sortie, et il remet des cartes éphémères sans les persister
lui-même (su-9 n'appelle aucun repository dans le callback).
**And** une garde assère `every card.id == null` sur le lot remis (démasque toute matérialisation
prématurée).

### AC7 — Port faillible : échec typé affiché, sans throw, saisie préservée (AD-10/NFR-SU6)
**Given** le port en échec ou hors ligne
**When** l'utilisateur lance la génération
**Then** l'échec est **typé et affiché** (le `Left<ZFailure>` est rendu en message lisible via `.fold`,
jamais une exception, jamais un écran rouge) **And** la configuration saisie (source, count,
distribution, instructions, modelId) est **préservée** (l'utilisateur peut relancer)
**And** un test couvre : (a) `Left(ZFailure)` → message d'échec + saisie intacte ; (b) le port qui
**lève** dans son `Future` → capté, converti en état `failed`, aucune exception ne remonte ; (c)
`Right([])` **0 carte** → état géré (message « aucune carte générée »), pas de crash ; (d) cartes
**malformées** → rendu **défensif** via `ZFlashcardReviewCard` (déjà défensif AD-10), jamais un throw.

### AC8 — Concurrence : jeton de fraîcheur, anti-double-soumission, annulation (leçon su-3/su-7)
**Given** une génération asynchrone en vol
**When** l'utilisateur re-soumet vite (double-tap), change la config, ferme/annule la feuille, ou le
port répond **après** fermeture
**Then** un **jeton de fraîcheur monotone** (`int _generation`), capturé avant l'`await` et comparé
après, **écarte** toute réponse périmée : aucune application d'un lot obsolète, aucun `setState`/
`notifyListeners` après `dispose`, aucune persistance
**And** l'anti-double-tap est actif (soumission ignorée pendant `status == generating`)
**And** l'annulation en vol laisse l'état cohérent (retour à `idle`/`preview` selon le cas), sans throw.
**And** un test pilote « réponse d'un appel N-1 arrivant après un appel N » ⇒ seule la réponse de N
est appliquée (le jeton démasque la régression **par le comportement**).

### AC9 — Feuille de confirmation de tags (réutilise l'éditeur existant), éditable, sans persistance
**Given** un lot généré
**When** la feuille de **confirmation de tags** est proposée
**Then** elle **réutilise** l'infrastructure de tags existante (`ZTagEditor`/`z_tag_chips`, ES-8.1) —
**jamais** un second éditeur — présentant les tags suggérés (fournis par l'app) **pré-cochés et
modifiables** (ajout/retrait/décochage) avant confirmation
**And** la confirmation applique l'ensemble retenu au lot éphémère (`copyWith`, `id` toujours `null`)
et le remet à l'appelant — **rien n'est persisté** ici non plus (AC5/AC6 s'appliquent à cette feuille).

### AC10 — Aperçu du lot via `ZFlashcardReviewCard` (jamais un rendu parallèle)
**Given** l'état `preview`
**When** le lot généré est présenté à l'utilisateur pour revue
**Then** chaque carte est rendue via `ZFlashcardPreview`/`ZFlashcardReviewCard` (su-2) — **aucune**
surface de rendu de flashcard parallèle (garde : aucun widget de rendu de flashcard réinventé dans
les fichiers de génération ; grep négatif sur un rendu maison de question/réponse).

### AC11 — Point d'entrée conditionnel : option IA absente sans port (jamais grisée)
**Given** aucun `ZFlashcardGenerationPort` injecté (via `ZcrudScope`/paramètre)
**When** le point d'entrée de génération s'affiche
**Then** l'option « Générer avec l'IA » est **absente** (jamais grisée/désactivée)
**And** avec un port injecté, l'option est présente et ouvre la feuille.
(Le point d'entrée de saisie manuelle reste hors périmètre de cette story : su-9 = génération.)

### AC12 — A11y / RTL / thème / L10n (AD-13, gardes étendues)
**Given** les nouveaux widgets (feuille de génération, feuille de confirmation)
**When** les gardes de package `zcrud_study` s'exécutent
**Then** aucun libellé ni couleur codés en dur (garde `z_widgets_hardcode_scan_test.dart` incluant la
règle `fontSize:` de su-8 — thème injecté, repli `Theme.of`), `Semantics` explicites + cibles ≥ 48 dp,
directionnels uniquement (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), contraste
WCAG vérifié (garde de contraste étendue), énumération a11y verte — **par extension des gardes
existantes, sans duplication**.

### AC13 — SM-1 : réactivité granulaire des champs de la feuille (objectif produit n°1)
**Given** la feuille de génération avec un champ texte (instructions/texte libre)
**When** l'utilisateur y tape
**Then** seul le champ courant se reconstruit : **zéro** perte de focus, `TextEditingController`
**jamais recréé**, `notifyListeners` ciblé (AD-2) — controller stable créé/`dispose`, pas de
construction de champ dans une closure de `build()`. Test widget + assertion de non-rebuild des autres
tranches.

---

## Tasks / Subtasks

- [x] **T1 — Étendre la requête d'union AD-37** (AC1, AC2) · `zcrud_study/lib/src/domain/z_flashcard_generation_port.dart`
  - [x] Ajouter `typesDistribution:Map<ZFlashcardType,int>?`, `instructions:String?`, `modelId:String?` (optionnels, additifs) ; mettre à jour ctor, `==`, `hashCode`.
  - [x] Dartdoc : `modelId` OPAQUE (transporté, jamais interprété — aucun catalogue/enum). **Aucune** prose non vérifiable.
- [x] **T2 — Module domaine pur : bornes + répartition (source unique)** (AC3, AC4) · `zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart` (NEW)
  - [x] `zGenerationCountBounds = (min:1, max:50)`, `zClampGenerationCount(int?) → int` (défaut null=10 consigné, AD-10 sans throw).
  - [x] `zEvenTypesDistribution(int count, List<ZFlashcardType> types) → Map` (reste déterministe).
  - [x] `zNormalizeTypesDistribution(Map?, int count, List<ZFlashcardType> types) → Map` (négatifs→0, types inconnus écartés, fournie fait foi).
- [x] **T3 — Contrôleur de génération (ChangeNotifier pur-Flutter, enum)** (AC5, AC6, AC7, AC8, AC13) · `zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart` (NEW)
  - [x] `enum ZFlashcardGenerationStatus { idle, generating, preview, confirmingTags, failed }` ; jeton `int _generation` ; anti-double-tap ; `.fold` sur `ZResult` ; **aucun** import de store/repository.
  - [x] Callback de handoff `onGenerated` ; **jamais** de persistance ; `dispose` propre (pas de `setState` post-dispose).
- [x] **T4 — Feuille de génération** (AC1, AC10, AC11, AC12, AC13) · `zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart` (NEW)
  - [x] Sélecteur de source depuis `ZSourceRegistry` (document/sujets/texte libre + kinds enregistrés) ; slider `count` 1..50 ; `FilterChip` par type (répartition) ; champ instructions ; champ `modelId` opaque optionnel.
  - [x] Aperçu du lot via `ZFlashcardPreview`/`ZFlashcardReviewCard` (jamais un rendu parallèle).
  - [x] Option « Générer avec l'IA » **absente** si port non injecté.
- [x] **T5 — Feuille de confirmation de tags** (AC9) · `zcrud_study/lib/src/presentation/z_flashcard_tag_confirm_sheet.dart` (NEW)
  - [x] Réutilise `ZTagEditor`/`z_tag_chips` ; pré-cochage éditable ; applique par `copyWith(tags:)` (id reste null) ; remet à l'appelant. **Aucune** persistance.
- [x] **T6 — Barrel + exports** · `zcrud_study/lib/zcrud_study.dart`
  - [x] Exporter les nouveaux widgets/controller publics + le module de défauts.
- [x] **T7 — Gardes étendues (NON dupliquées)** (AC2, AC5, AC10, AC12) · `zcrud_study/test/presentation/`
  - [x] Étendre `z_widgets_purity_test.dart` : ajouter l'assertion « aucun store/repository importé » couvrant les 3 nouveaux fichiers (grep négatif prouvé + preuve par mutant jetable).
  - [x] Garde `modelId` opaque : grep négatif `enum .*[Mm]odel` + test round-trip chaîne opaque inédite.
  - [x] Garde source unique de répartition : aucune seconde implémentation hors `z_flashcard_generation_defaults.dart`.
  - [x] Vérifier que `z_widgets_hardcode_scan_test.dart` (règle `fontSize:` su-8) + contrast + a11y couvrent bien les nouveaux fichiers (sinon étendre le corpus scanné).
- [x] **T8 — Tests porteurs comportementaux** (AC3..AC10, AC13) · `zcrud_study/test/presentation/z_flashcard_generation_*_test.dart` (NEW)
  - [x] Bornes/normalisation (0/-5/10000/null, somme≠count, type inconnu) ; échec typé + throw capté + 0 carte + malformé ; jeton de fraîcheur (réponse N-1 après N) ; double-tap ; **espion repository prouvé captant AVANT** (témoin positif `spy.writes==1`) puis génération+abandon ⇒ inchangé ; `every card.id == null` ; SM-1 (focus/controller).
  - [x] **Injection R3** rougissant **par le COMPORTEMENT** pour chaque AC (jamais une injection qui casse la seule compilation).

---

## Dev Notes

### Frontières (NE PAS déborder)
su-9 = **flux UI de génération IA** (feuille + confirmation de tags) + extension du DTO d'union AD-37 +
module de défauts. **PAS** d'impl IA concrète (app-side, AD-15/AD-35) · **PAS** de refactor du port
`ZFlashcardGenerationPort` (signature inchangée) · **PAS** de parcours example (su-10) · **PAS** de
multi-édition (epic ME / FR-SU20) · **PAS** de génération mindmap (su-12) · su-9 **ne persiste RIEN**
(le multi-éditeur FR-SU20 consommera le lot remis).

### AD applicables (spine study-ui + hérités)
- **AD-37** (requête d'union, `modelId` opaque, résultat éphémère, répartition équitable source unique)
  — cœur de la story.
- **AD-43** (frontière brouillon/persistance **déclarée** : rien persisté avant un commit explicite ;
  ici su-9 est en régime **brouillon** et le « commit » = handoff à l'appelant, pas une écriture base).
- **AD-35** (port advisory, impl app-side), **AD-4** (registre de source/type), **AD-10** (jamais de
  throw : bornes, normalisation, port faillible, réponse tardive), **AD-13** (a11y/RTL/thème),
  **AD-2/AD-15** (réactivité Flutter-native, `ChangeNotifier`, **aucun** gestionnaire d'état dans le
  cœur ; le code manager-spécifique n'existe pas ici), **AD-5** (`Either<ZFailure,·>`), **AD-19.1**
  (`extra` normalisé — déjà porté par le DTO).

### Leçons su-1..su-8 à NE PAS reproduire
- **su-7** : l'espion « zéro persistance » doit être **prouvé captant AVANT** l'assertion à 0 (témoin
  positif `writes==1`), sinon l'assertion est infalsifiable.
- **su-8** : le HIGH était une perte de données par une voie **non anticipée** (réordonner sous filtre).
  ⇒ AC6 balaye **toute** voie de fuite du résultat éphémère (onDuplicate / copyWith persisté / save
  implicite / réponse tardive / callback). Un défaut est un **motif** : balayer tout le diff.
- **su-8** : `fontSize:` en dur invisible à la garde hardcode → la règle `fontSize:\s*[0-9]` existe
  désormais ; vérifier qu'elle couvre les nouveaux fichiers.
- **su-3/su-7** : « carte/appel changé pendant un port en vol » ⇒ jeton de fraîcheur (`_generation`).
- **présence ≠ association** (un contrôle **actionné** dans son test) · **un test ne doit pas observer
  qu'UN canal** · **une garde qui n'assère que « aucune exception » ne vérifie pas la justesse** · **la
  prose ment** (toute affirmation de dartdoc vraie sur disque) · **un test infalsifiable** (corpus
  rendant l'assertion vraie quel que soit le code) · **deux gardes qui se contredisent** · 🚫 **on ne
  modifie JAMAIS un test pour taire un défaut réel.**

### Discipline de vérification (rejouée par l'orchestrateur avant tout done)
- `melos run generate` OK → `analyze` RC=0 → **`flutter test` DEPUIS `packages/zcrud_study`** RC=0.
- Pièges : `grep -q` **sans pipe** (un `| head` renvoie le RC de `head`) ; **`grep -qF`** pour tout
  symbole `$`/codegen ; toute **ABSENCE** prouvée par un **grep négatif** (commande + RC).
- 🚫 Jamais `melos run test` · 🚫 jamais `git checkout` (su-1..su-8 **non committés**) · 🚫 jamais
  `dart format`.
- Référence de non-régression : 23/23 packages, 4543 tests (`zcrud_study` **346** — su-9 doit
  l'augmenter, jamais le réduire).

### Project Structure Notes
- Nouveaux fichiers **tous dans `zcrud_study`** (présentation + domaine) — **aucune nouvelle arête de
  graphe** (déps `zcrud_core`/`zcrud_flashcard`/`flutter` déjà déclarées ; mettre à jour toute garde de
  graphe **seulement si** un compte d'arêtes change — ici il ne change pas).
- API publique via le **barrel** `lib/zcrud_study.dart` ; impl sous `lib/src/{domain,presentation}`.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.9]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-37, #AD-43, #AD-35, #AD-4, #AD-10, #AD-13]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU15, #NFR-SU6]
- [Source: packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:33,89]
- [Source: packages/zcrud_core/lib/src/domain/registry/z_source_registry.dart:23]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart:20]
- [Source: packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart]
- [Source: packages/zcrud_study/lib/src/presentation/z_flashcard_preview.dart:75]
- [Source: packages/zcrud_study/lib/src/presentation/z_tag_editor.dart]
- [Source: packages/zcrud_study/test/presentation/z_widgets_purity_test.dart, z_widgets_hardcode_scan_test.dart]
- [Source: docs/parity-study-ui-2026-07-16/annexes/lex_flashcards.md#Génération IA]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (bmad-dev-story, effort high).

### Debug Log References

- `dart run melos run analyze` → SUCCESS (RC=0) repo-wide (infos seuls).
- `dart run melos run verify` → RC=0 : ACYCLIQUE OK (graph_proof, aucune nouvelle
  arête), gate:secrets OK, gate:reflectable OK, gate:codegen OK (19 modèles, 0 `.g.dart`
  manquant — su-9 n'ajoute AUCUN modèle codegen), gate:reserved-keys OK, verify:serialization OK.
- `flutter test` DEPUIS `packages/zcrud_study` → **403/403** (baseline su-8 : 346 ⇒ +57).
- Injections R3 (cp + SHA-256, rouge PAR LE COMPORTEMENT, restaurées, SHA identiques) :
  AC3 clamp neutralisé ⇒ `Actual: <10000>` (au lieu de 50) ; AC5 `copyWith(id:null,source:)`
  retiré ⇒ `Actual: 'backend-id'` ; AC8 jeton ignoré ⇒ `Actual: preview` (N-1 périmée appliquée) ;
  AC5 structurelle `.save(` injecté ⇒ garde purity ROUGE.

### Completion Notes List

- **T1** — `ZFlashcardGenerationRequest` étendu in-place (additif, non-codegen) : `typesDistribution`
  / `instructions` / `modelId` (`String?` OPAQUE) ; `==`/`hashCode` profonds (map par valeur).
- **T2** — module DOMAINE PUR `z_flashcard_generation_defaults.dart` : `zGenerationCountBounds`
  `[1,50]`, `zClampGenerationCount` (null=10, 0/-5→1, 10000→50, jamais de throw), `zEvenTypesDistribution`
  (somme EXACTE, reste déterministe), `zNormalizeTypesDistribution` (négatifs→0, types inconnus écartés,
  distribution fournie fait foi, total borné). SOURCE UNIQUE.
- **T3** — `ZFlashcardGenerationController` (`ChangeNotifier` pur, AUCUN store) : statut ENUM, jeton de
  fraîcheur monotone, anti-double-tap, `.fold` sur `ZResult`, cartes ÉPHÉMÈRES (`id==null` forcé, source
  = `request.provenance` seule), handoff `onGenerated`, `dispose` propre.
- **T4** — `ZFlashcardGenerationSheet` (source depuis `ZSourceRegistry` via `ZGenerationSourceOption`,
  slider 1..50, `FilterChip` par type, `modelId` opaque, aperçu via `ZFlashcardPreview`→`ZFlashcardReviewCard`),
  `ZFlashcardGenerationScope`/`ZFlashcardGenerationLauncher` (option ABSENTE sans port, AC11), SM-1
  (controllers stables en initState).
- **T5** — `ZFlashcardTagConfirmSheet` : réutilise `ZTagEditor`, pré-cochage éditable, `id==null`, aucune
  persistance.
- **T6** — barrel `zcrud_study.dart` : exports défauts + controller + sheet + confirm.
- **T7** — gardes ÉTENDUES (non dupliquées) : `z_widgets_purity_test.dart` + ban STORE/REPOSITORY
  (`.save(`/`.persist(`/`Repository`…) couvrant les 3 fichiers + contre-preuve ; nouvelle garde
  `z_flashcard_generation_guards_test.dart` (modelId `enum .*Model` négatif + contre-preuve ; source
  unique `50`/`~/` interdits dans un widget + sonde de délégation ; AC10 accès `.question/.answer` interdit
  dans les fichiers de génération + contre-preuve). Hardcode/contrast/a11y su-8 couvrent auto les nouveaux
  fichiers (scan récursif).
- **T8** — tests comportementaux : défauts, request value-semantics + modelId round-trip verbatim,
  controller (Left/throw/0-carte/malformé/jeton N-1/double-tap/abandon/dispose/espion writes==1→inchangé),
  sheet (requête d'union, aperçu ReviewCard, launcher, tag-confirm, SM-1), confirm sheet (pré-coché/décoché).
- **Frontière AD-43 (preuve 3 étages)** : (a) STRUCTUREL — grep négatif code-only + garde purity étendue ;
  (b) COMPORTEMENTAL — espion `_SpyStore` PROUVÉ captant AVANT (`writes==1`) puis cycle complet+abandon ⇒
  `writes` inchangé ; (c) app tuée ⇒ rien (aucune voie de store dans le graphe des 3 fichiers).
- **Non fait (hors périmètre déclaré)** : impl IA concrète (app-side AD-15/AD-35), refactor du port,
  parcours example (su-10), multi-édition FR-SU20, génération mindmap (su-12). su-9 ne persiste RIEN.

### File List

- `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart` (M — DTO étendu)
- `packages/zcrud_study/lib/src/domain/z_flashcard_generation_defaults.dart` (NEW)
- `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart` (NEW)
- `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart` (NEW)
- `packages/zcrud_study/lib/src/presentation/z_flashcard_tag_confirm_sheet.dart` (NEW)
- `packages/zcrud_study/lib/zcrud_study.dart` (M — exports)
- `packages/zcrud_study/test/domain/z_flashcard_generation_defaults_test.dart` (NEW)
- `packages/zcrud_study/test/domain/z_flashcard_generation_request_test.dart` (NEW)
- `packages/zcrud_study/test/presentation/z_flashcard_generation_controller_test.dart` (NEW)
- `packages/zcrud_study/test/presentation/z_flashcard_generation_sheet_test.dart` (NEW)
- `packages/zcrud_study/test/presentation/z_flashcard_generation_guards_test.dart` (NEW)
- `packages/zcrud_study/test/presentation/z_flashcard_tag_confirm_sheet_test.dart` (NEW)
- `packages/zcrud_study/test/presentation/z_widgets_purity_test.dart` (M — ban STORE/REPOSITORY + contre-preuve)
