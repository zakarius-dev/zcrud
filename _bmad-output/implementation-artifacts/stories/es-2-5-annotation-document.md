# Story ES-2.5 : Annotation de document (`ZDocumentAnnotation` / `ZAnnotationBounds`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur du domaine study zcrud**,
I want **modéliser une annotation de document PARTAGEABLE (`ZDocumentAnnotation`) et son rectangle d'ancrage borné `[0,1]` (`ZAnnotationBounds`), en EXTRAYANT `is_deleted` ET `updated_at` hors-entité vers `ZSyncMeta`**,
so that **le contenu d'annotation (surlignage / sticky note) soit partageable, réémis zéro-perte, et conforme à la convention de sync `ZSyncMeta` — jamais `isDeleted`/`updatedAt` inline comme dans la source lex, qui recréerait la perte de données soldée en ES-1.3.**

## Contexte & source de vérité

- **FR couverte** : **FR-S8** — « Annotation de document partageable (`ZDocumentAnnotation`/`ZAnnotationBounds`), `is_deleted` hors-entité. » [Source: epics-zcrud-study-2026-07-12/epics.md#FR-S8, table de traçabilité l.112]
- **Épic** : ES-2 (Modélisation du domaine éducatif). **Dépend de** : ES-1 (kernel + gate AD-19.1), ES-2.1 (package `zcrud_document` livré — patrons de référence). [Source: epics.md l.181-182]
- **Package cible** : `zcrud_document` (PAS le kernel). Fichiers : `packages/zcrud_document/lib/src/domain/{z_document_annotation.dart, z_annotation_bounds.dart}` (+ enum `z_document_annotation_kind.dart`) + `.g.dart` régénérés. [Source: epics.md l.422]
- **Parallélisation** : PARALLÉLISABLE avec ES-2.2 (`zcrud_note`) / ES-2.6 (`zcrud_exam`) — packages disjoints ; peut suivre ES-2.1 dans le même workstream `document`. Le **seul** point de contact possible serait `zcrud_core` : cette story **n'y écrit pas** (elle consomme uniquement la surface pur-Dart `domain.dart`). [Source: epics.md l.422 ; CLAUDE.md « Règles générales »]
- **Source lex à porter (et à DIVERGER)** :
  - `lex_core/lib/domain/entities/education/document_annotation.dart` — `DocumentAnnotation {id, docId, page, kind, colorKey, bounds, rects?, text?, createdAt, updatedAt, isDeleted}`.
  - `lex_core/lib/domain/entities/education/annotation_bounds.dart` — `AnnotationBounds {x, y, width, height}` (doubles, fractions [0,1]), **importe `dart:ui`** (`Rect`/`Size`).
  - `lex_core/lib/domain/enums/education/document_annotation_kind.dart` — `DocumentAnnotationKind {highlight, stickyNote}`, repli défensif `highlight`.

### Cette story ne livre PAS

- **Aucun widget, aucune UI, aucune toolbar/palette** : l'UI d'annotation accessible (WCAG, FR-S28) est **ES-8.2** (`lib/src/presentation/`). [Source: epics.md l.906-912]
- **Aucun repository, aucune persistance, aucune cascade** : la persistance des annotations et la cascade `folder→document→annotation` sont **ES-3.x** (AD-21, `zcrud_document` propriétaire d'arête). [Source: epics.md l.550]
- **Aucune conversion géométrique espace-écran** (`fromPageRect`/`toPageRect`) : elle dépend de `Rect`/`Size` (`dart:ui` → Flutter) et vit **en presentation, côté app** (ES-8.2). Voir DÉCISION D3.

## Acceptance Criteria

> Chaque garde/gate naît avec **sa fixture d'échec ISOLÉE** (R2) et son **injection de régression** rejouable (R3). Un artefact de vérification est validé sur son **POUVOIR DISCRIMINANT OBSERVÉ**, jamais sur sa seule existence. Aucune quantité de vert ne détecte un faux vert ; seul un rouge provoqué le peut.

### `ZAnnotationBounds` — value object borné `[0,1]`

**AC1.** `ZAnnotationBounds` est un **`@ZcrudModel(kind: 'annotation_bounds')` NON-`ZExtensible`** (patron `ZChoice` / `ZDocumentViewerPrefs`) portant **quatre `double` `@ZcrudField`** : `x`, `y`, `width`, `height` (fractions de page). Aucun slot `extra`/`extension`. Constructeur nominal **`const`** (défauts `0.0`), `factory fromMap` **défensif non-nu**, `toMap()` **méthode d'INSTANCE**, `copyWith` **d'INSTANCE**, `==`/`hashCode` de valeur.

**AC2.** **Invariant `[0,1]` (décision assumée, ABSENTE de lex — R-H/R1)** : une garde publique nommée `sanitizeCoord(double raw)` ramène chaque coordonnée dans son domaine — **`NaN`/`±Infinity` ⇒ `0.0`**, sinon **`raw.clamp(0.0, 1.0)`**. Elle est appliquée aux **DEUX frontières réelles** : `fromMap` (désérialisation) **ET** `copyWith` (mutation applicative) — **la même fonction nommée aux deux** (leçon H2, jamais deux jumelles divergentes). Le constructeur `const` **ne sanitise pas** (AD-10 y interdit `assert`/appel de fonction) : la garde vit aux frontières, jamais dans le ctor.
  - **Fixture d'échec ISOLÉE (R2)** : un test prouve que `ZAnnotationBounds.fromMap({'x': 5.0, 'y': -3.0, 'width': double.nan, 'height': 0.4})` rend `x==1.0`, `y==0.0`, `width==0.0`, `height==0.4`. **Injection de régression (R3)** : retirer `sanitizeCoord` de `fromMap` **OU** de `copyWith` doit rendre un test ROUGE (rejoué par l'orchestrateur).

**AC3.** **Défensif AD-10 total** : `ZAnnotationBounds.fromMap(const <String,dynamic>{})` **ne throw jamais** et rend `(0,0,0,0)`. Une valeur non numérique (`'x': 'abc'`, `'y': null`, `'width': []`) retombe sur `0.0` au décodage généré (`_$asDouble → null → défaut`) — **jamais de throw** du parent.

**AC4.** **Aucun import `dart:ui` ni Flutter** (D3, NFR-S3/SM-S5) : `ZAnnotationBounds` importe **uniquement** `zcrud_annotations` + la surface pur-Dart `zcrud_core/edition.dart`. Les helpers `fromPageRect`/`toPageRect` de lex (qui dépendent de `Rect`/`Size`) **ne sont PAS portés** ici (voir D3). Un test/gate d'analyse confirme zéro `import 'dart:ui'` et zéro `package:flutter` dans le package.

### `ZDocumentAnnotation` — contenu partageable `ZEntity` + `ZExtensible`

**AC5.** `ZDocumentAnnotation` est un **`@ZcrudModel(kind: 'document_annotation')` `extends ZEntity with ZExtensible`** (contenu top-level à identité propre, **partageable** — AD-26), portant :
  - `id` : `String?` (`@override @ZcrudId()`, opaque, nullable pour l'éphémère — AD-14, jamais attribué par l'entité) ;
  - `docId` : `String` `@ZcrudField()` (défaut `''`, persisté `doc_id`) ;
  - `page` : `int` `@ZcrudField()` (1-based, défaut `1`) ;
  - `kind` : `ZDocumentAnnotationKind` `@ZcrudField()` (enum, défaut défensif = 1ʳᵉ constante) ;
  - `colorKey` : `String` `@ZcrudField()` (persisté `color_key`, défaut `''`, **BRUT — aucun clamp dans l'entité**, précédent `ZFlashcardTag.colorKey`/`ZStudyFolder.colorKey`) ;
  - `bounds` : `ZAnnotationBounds` `@ZcrudField()` (sous-modèle, défaut `const ZAnnotationBounds()`) ;
  - `rects` : `List<ZAnnotationBounds>?` `@ZcrudField()` (liste de sous-modèles, `null`/vide pour sticky note ou surlignage mono-ligne) ;
  - `text` : `String?` `@ZcrudField()` (contenu note / extrait surligné) ;
  - `createdAt` : `DateTime?` `@ZcrudField()` (persisté `created_at`, **clé DISTINCTE** de toute clé réservée) ;
  - `extension` : `ZExtension?` (`@override`, hors-codegen) ; `extra` : `Map<String,dynamic>` (`@override`, hors-codegen).

**AC6. 🔴 AD-19 — `is_deleted` ET `updated_at` HORS-ENTITÉ (cœur de la FR).** `ZDocumentAnnotation` **ne déclare NI `isDeleted`, NI `updatedAt`** (ni sous ces noms, ni `is_deleted`/`updated_at`). Le soft-delete et l'autorité Last-Write-Wins de l'annotation partagée vivent **dans le STORE** (`ZSyncMeta`, hors-entité — AD-16/AD-9). **Divergence assumée vs lex (R-G)** : lex loge `updatedAt` **inline** — et c'est **littéralement la clé LWW** de l'annotation partagée — **et** `@JsonKey(defaultValue: false) isDeleted` inline. Un portage verbatim recréerait **exactement** le piège soldé en ES-1.3 (les stores écrivent la méta de sync **dans le corps, APRÈS** le corps métier, à chaque `put` ⇒ écrasement silencieux). C'est le **contraste ES-2.1** (`ZStudyDocument` a retiré `updatedAt`/`isDeleted` inline) reproduit ici, en plus aigu (`updatedAt` **EST** la clé LWW).
  - **Garanti par construction** : `_reservedKeys ⊇ ZSyncMeta.reservedKeys`. Un test prouve `$ZDocumentAnnotationFieldSpecs.map((s)=>s.name).toSet().intersection(ZSyncMeta.reservedKeys)` **== ∅** (aucune clé de champ ne collisionne une clé réservée). Un test prouve qu'`is_deleted`/`updated_at` injectés dans la map d'entrée **n'atterrissent JAMAIS dans `extra`** et **ne sont JAMAIS réémis** par `toMap()`.
  - **Fixture d'échec ISOLÉE (R2)** : `ZDocumentAnnotation.fromMap({...corps..., 'is_deleted': true, 'updated_at': '2026-01-01T00:00:00Z', 'zz_unknown': 'x'}).toMap()` ne contient **ni** `is_deleted` **ni** `updated_at`, **mais contient** `zz_unknown` (round-trip AD-4 non régressé). **Injection (R3)** : retirer `...ZSyncMeta.reservedKeys` de `_reservedKeys` doit rendre ce test ROUGE.

**AC7. Patron `extra` ES-2.2b INTÉGRAL** (jumeau `ZStudyDocument` / `ZFlashcardTag`), sans exception :
  - constructeur `const` **ne filtrant RIEN** (`: _extra = extra;`, `// ignore: prefer_initializing_formals`) ;
  - slot brut `_extra` **lu NULLE PART** ailleurs que dans l'accesseur (jamais dans `toMap`/`==`/`hashCode`) ;
  - accesseur `Map<String,dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys)` — **le seul point que TOUTES les voies traversent** ;
  - garde partagée `_sanitizeExtra` (= `zSanitizeExtra(raw, _reservedKeys)`) appelée par `fromMap` **ET** `copyWith` ;
  - `toMap()` étalant l'**ACCESSEUR** (`...extra`, **jamais** `_extra`) puis `...ZDocumentAnnotationZcrud(this).toMap()`, plus `extension` si non nul ;
  - `fromMap` **NON-déléguante-nue** (peuple `extra: _extraFrom(map)` — sinon `_rejectNakedCodegenDelegation` du build ROUGIT et le garde runtime `_$zRequireExtraPreserved` lève) ;
  - `copyWith` **à sentinelle** `_$undefined` couvrant **TOUS** les champs (y compris `extension`/`extra`, que le `copyWith` **généré** remettrait aux défauts → perte silencieuse) ;
  - égalité **PROFONDE** `zJsonEquals(extra, other.extra)` / `zJsonHash(extra)` ; `rects` comparés élément par élément (helper `_listEquals`, précédent `ZFlashcard.choices`).

**AC8. Défensif AD-10 total sur `ZDocumentAnnotation`** : `ZDocumentAnnotation.fromMap(const <String,dynamic>{})` **ne throw jamais**. Un `kind` inconnu/`null`/non-`String` ⇒ **1ʳᵉ constante** de l'enum (D5). Un `bounds` corrompu (non-map, scalaire) ⇒ `ZAnnotationBounds` neutre `(0,0,0,0)` (chemin `subModel` défensif), **jamais de throw du parent**. Un élément corrompu de `rects` est traité défensivement (chemin `listModel`, précédent `ZChoice`), **jamais de throw du parent** ; chaque `rect` survivant est **auto-clampé** `[0,1]` (via `ZAnnotationBounds.fromMap`, AC2). `page < 1` (corruption) ⇒ **`1`** via garde nommée `sanitizePage` appliquée aux **deux frontières** (`fromMap` + `copyWith`), décision R-H assumée.
  - **Fixture d'échec ISOLÉE (R2)** : un test décode une map polluée (`kind: 'zzz'`, `bounds: 'not-a-map'`, `rects: [ {x:2.0,...}, 'garbage' ]`, `page: -4`) et prouve : `kind == highlight`, `bounds == (0,0,0,0)`, `rects` ne contient que des bounds clampés `[0,1]`, `page == 1`, **sans throw**.

**AC9. Enum `ZDocumentAnnotationKind`** : `{highlight, stickyNote}`, **valeurs camelCase** (AD-3), `@JsonKey(unknownEnumValue: ZDocumentAnnotationKind.highlight)` sur le champ public, **1ʳᵉ constante = `highlight`** (repli défensif D5, aligné lex). Round-trip `stickyNote` ⇄ `'stickyNote'` épinglé par un vecteur à **pouvoir discriminant observé** (leçon ES-2.3 : un golden peut passer PAR COÏNCIDENCE — le vecteur choisit une valeur **distincte du défaut** pour discriminer réellement).

**AC10. Round-trip zéro-perte** (AD-4) : pour une annotation pleinement peuplée (`rects` non vide, `text` présent, `extension` concrète, `extra` avec clé inconnue), `ZDocumentAnnotation.fromMap(a.toMap(), extensionParser: ...) == a` (égalité **profonde**, incluant `rects` et `extra`). Le vecteur porte **au moins une clé inconnue** et **au moins deux rects distincts** (pouvoir discriminant). Idempotence : `toMap(fromMap(m))` stable.

### Câblage du gate `reserved-keys` — **DANS LA MÊME STORY (R8)**

**AC11.** Les DEUX nouvelles entités sont câblées dans `tool/reserved_keys_gate/lib/src/registrars.dart`, sans quoi le gate serait **VERT POUR RIEN** (`R_disk \ R_wired ≠ ∅` ⇒ ROUGE de couverture) :
  - `kRegistrars += registerZDocumentAnnotation, registerZAnnotationBounds` ;
  - `kProbeBodies['document_annotation']` = corps minimal valide **représentatif** (`id`, `doc_id`, `page`, `kind`, `color_key`, `bounds`) et `kProbeBodies['annotation_bounds']` = `{x, y, width, height}` ;
  - `kNonExtensibleKinds += 'annotation_bounds'` (VO sans `extra` — le cast `(e as ZExtensible)` throw dessus, piège n°1). **`document_annotation` N'Y FIGURE PAS** (elle **EST** `ZExtensible`) ;
  - `kExtraWriters['document_annotation']` = **DEUX** voies **VERBATIM** (règle AST (j)/(k)) : `ZExtraWriter(voie:'ctor', write:_ctorDocumentAnnotation, eagerlyNormalized:false)` **ET** `ZExtraWriter(voie:'copyWith', write:_copyWithDocumentAnnotation, eagerlyNormalized:true)`. Les fonctions `_ctor…`/`_copyWith…` transmettent `extra` **sans transformation** (un writer auto-sanitisant = « menteur poli », finding MAJEUR-2).
  - ⛔ **NE PAS toucher** `kLegacyUpdatedAtMirrors` (`{study_folder, flashcard}`) — l'ensemble est **verrouillé** par test à un attendu figé ; toute croissance rougit. `document_annotation` **n'émet jamais** `updated_at` (AC6) ⇒ **jamais** un miroir legacy.
  - **`tool/reserved_keys_gate/pubspec.yaml` dépend DÉJÀ de `zcrud_document`** (ajouté par ES-2.1, l.67) ⇒ **AUCUNE nouvelle dépendance pubspec du gate n'est requise**. (Vérifié.)

**AC12. Aucun canal hors-codegen `Map`/`List` non-réservé à câbler** (contraste ES-2.2/ES-2.4) : **tous** les champs de `ZDocumentAnnotation` sont `@ZcrudField` codegen-ables (dont `bounds` = sous-modèle `subModel`, et `rects` = `listModel`, précédent `ZFlashcard.choices`). Il **n'y a donc PAS** de canal type `learning`/`content`/`section_orders` (les seuls slots hors-codegen sont `extension`/`extra`, portés par le patron ES-2.2b). La règle AST (g)/(g2) du gate ne détectera aucun champ hors-codegen non réservé sur cette entité — à **confirmer** en rejouant le gate (un `bounds`/`rects` qui, contre toute attente, ne serait pas résolu en codegen ferait ROUGIR (g1)).

### Distribution & barrel

**AC13. Barrel `packages/zcrud_document/lib/zcrud_document.dart`** exporte les deux entités en **masquant les extensions générées** (politique UNIFORME du barrel, M2 ES-2.1) :
  - `export 'src/domain/z_document_annotation.dart' hide ZDocumentAnnotationZcrud;`
  - `export 'src/domain/z_annotation_bounds.dart' hide ZAnnotationBoundsZcrud;`
  - `export 'src/domain/z_document_annotation_kind.dart';` (enum, rien à masquer).
  - **Raison du `hide` sur le VO** : `ZAnnotationBounds` porte un **invariant de valeur** (`[0,1]`) ⇒ son `copyWith`/`toMap` généré, appelable **explicitement** depuis l'API publique, **CONTOURNERAIT** `sanitizeCoord` (leçon exacte de `ZDocumentViewerPrefs`/M2). `toMap()` est **promu en méthode d'INSTANCE** (surface (dé)sérialisation préservée, porte du `copyWith` fermée). Un test prouve que `ZDocumentAnnotationZcrud`/`ZAnnotationBoundsZcrud` **ne sont pas exportés** par le barrel (`// ignore: unused_import` + non-résolution, ou test de surface).

**AC14. `.g.dart` régénérés et SUIVIS par git** : `melos run generate` émet `z_document_annotation.g.dart` + `z_annotation_bounds.g.dart` sous `packages/zcrud_document/lib/` (dép. git, gate `codegen-distribution`) — **committés en fin d'epic**. Le `part` vise un fichier suivi (jamais gitignoré).

### Vérif verte & qualité

**AC15.** `melos run generate` OK → `dart analyze`/`melos run analyze` **RC=0** → `dart test` (pur-Dart, package `zcrud_document`) **RC=0**. Le gate `reserved-keys` (`scripts/ci/gate_reserved_keys.dart`, `flutter test --tags reserved-keys` traitant `exit 79` comme fatal) est **VERT** avec les deux nouvelles entités **effectivement sondées** (pas un vert par omission). Zéro `dart:io` non annoté, zéro dépendance lourde, zéro gestionnaire d'état, zéro `cloud_firestore`, zéro SDK Flutter (NFR-S3/SM-S5). Types `Z`, snake_case en persistance, enums camelCase, tests `*_test.dart` sous `dart test`.

## Tasks / Subtasks

- [x] **T1. Enum `ZDocumentAnnotationKind`** (AC9)
  - [x] Créer `packages/zcrud_document/lib/src/domain/z_document_annotation_kind.dart` : `enum {highlight, stickyNote}`, dartdoc d'origine lex, valeurs camelCase, `highlight` en 1ʳᵉ constante (repli D5).
- [x] **T2. `ZAnnotationBounds` (VO borné `[0,1]`)** (AC1–AC4)
  - [x] `z_annotation_bounds.dart` : `@ZcrudModel(kind: 'annotation_bounds')` NON-`ZExtensible`, 4 `double @ZcrudField`, ctor `const` (défauts `0.0`), `part`.
  - [x] `factory fromMap` **non-nu** délégant à `_$ZAnnotationBoundsFromMap` **puis** appliquant `sanitizeCoord` aux 4 coords ; `toMap()` **d'instance** (`ZAnnotationBoundsZcrud(this).toMap()`) ; `copyWith` **d'instance** re-sanitisant ; `==`/`hashCode` de valeur.
  - [x] `static double sanitizeCoord(double raw)` : non-fini ⇒ `0.0`, sinon `raw.clamp(0.0, 1.0)` — **publique et nommée** (même fonction aux deux frontières).
  - [x] **NE PAS** importer `dart:ui` ; **NE PAS** porter `fromPageRect`/`toPageRect` (D3).
- [x] **T3. `ZDocumentAnnotation` (`ZEntity`+`ZExtensible`)** (AC5–AC8, AC10)
  - [x] `z_document_annotation.dart` : patron ES-2.2b INTÉGRAL calqué sur `z_flashcard_tag.dart` / `z_study_document.dart` (typedef `…ExtensionParser`, `_decodeExtension`, `_asStringMap`, `_reservedKeys` dérivé de `$…FieldSpecs` + `'extension'` + `...ZSyncMeta.reservedKeys`, `_extraFrom`, `_sanitizeExtra`).
  - [x] Champs AC5 ; **aucun** `updatedAt`/`isDeleted` (AC6) ; `createdAt` conservé (clé distincte).
  - [x] `fromMap` défensif : `sanitizePage`, `bounds` via `subModel`, `rects` via `listModel` (chaque rect auto-clampé), `kind` défaut D5.
  - [x] `copyWith` à sentinelle couvrant tous champs, ré-appliquant `sanitizePage` (garde partagée nommée).
  - [x] `static int sanitizePage(int raw)` : `raw < 1 ⇒ 1` (deux frontières).
  - [x] `==`/`hashCode` profonds (`zJsonEquals`/`zJsonHash` sur `extra`, `_listEquals` sur `rects`).
- [x] **T4. Barrel + `hide`** (AC13)
  - [x] Éditer `lib/zcrud_document.dart` : 3 exports (2 avec `hide …Zcrud`), dartdoc alignée sur la politique UNIFORME M2.
- [x] **T5. Codegen** (AC14) : `dart run melos run generate` ; committer les 2 `.g.dart` en fin d'epic.
- [x] **T6. Câblage gate `reserved-keys`** (AC11–AC12)
  - [x] `registrars.dart` : `kRegistrars`, `kProbeBodies` (les deux kinds), `kNonExtensibleKinds += 'annotation_bounds'`, `kExtraWriters['document_annotation']` (ctor + copyWith VERBATIM) + fonctions `_ctorDocumentAnnotation`/`_copyWithDocumentAnnotation`.
  - [x] Vérifier (et NE PAS modifier) `kLegacyUpdatedAtMirrors`. Confirmer que `pubspec.yaml` du gate voit déjà `zcrud_document` (aucun ajout).
- [x] **T7. Tests à pouvoir discriminant** (AC1–AC12, R2/R3)
  - [x] `test/z_annotation_bounds_test.dart` : clamp `[0,1]` aux 2 frontières, `NaN`/`Inf`, map vide, non-numérique, round-trip, fixture d'échec + injection.
  - [x] `test/z_document_annotation_test.dart` : défensif total (AC8 map polluée), AD-19 (AC6 `is_deleted`/`updated_at` jamais dans `extra`/`toMap`, `$FieldSpecs ∩ ZSyncMeta.reservedKeys == ∅`), round-trip zéro-perte (AC10), enum (AC9), `extra` ES-2.2b (ctor pollué + copyWith), fixtures d'échec + injections.
  - [x] (Optionnel) test de non-export des extensions générées par le barrel (AC13) — surface test (`ZDocumentAnnotationZcrud`/`ZAnnotationBoundsZcrud` accessibles uniquement par import interne).
- [x] **T8. Vérif verte rejouée** (AC15) : `generate` → `analyze` RC=0 → `dart test` RC=0 (package) → gate `reserved-keys` VERT (sondage effectif). L'orchestrateur rejoue les injections de régression R3.

## Dev Notes

### Décisions structurantes (tranchées par lecture du générateur + de la source lex)

- **D1 — `ZDocumentAnnotation` = `ZEntity` + `ZExtensible`.** Contenu personnel **partageable** top-level à identité propre (sous-collection `.../documents/{docId}/annotations/{id}` en lex) ⇒ patron ES-2.2b **INTÉGRAL** (identique `ZStudyDocument`/`ZFlashcardTag`). [Source: z_study_document.dart, z_flashcard_tag.dart]
- **D2 — `ZAnnotationBounds` = value object `@ZcrudModel` NON-`ZExtensible`, codegen-able.** Les `double` **SONT** codegen-ables (précédent `ZDocumentViewerPrefs.zoomLevel: double @ZcrudField`). Un sous-modèle exige `@ZcrudModel` : `ZAnnotationBounds` en est un ⇒ `bounds` (`subModel`) et `rects` (`listModel`) sont codegen-ables sans canal hors-codegen (précédents `ZDocumentReadingState.prefs` et `ZFlashcard.choices: List<ZChoice>?`). **Ce n'est donc PAS un canal `Map` hors-codegen** comme `learning`/`content`/`section_orders`. [Source: z_document_viewer_prefs.dart l.131 ; z_choice.dart ; z_flashcard.dart l.167]
- **D3 — `dart:ui` REJETÉ ; `fromPageRect`/`toPageRect` NON portés.** La source lex `annotation_bounds.dart` importe `dart:ui` pour `Rect`/`Size` (conversion espace-page ↔ fractions). `zcrud_document` est **pur-Dart** (tests sous `dart test`, NFR-S3/SM-S5) : `dart:ui` = Flutter, **interdit**. La conversion géométrique est un **seam de présentation** (elle a besoin de la taille de page mesurée par le viewer) ⇒ elle vit en **ES-8.2 presentation, côté app**. Le domaine ne porte que les 4 fractions bornées. [Source: annotation_bounds.dart l.1 (`import 'dart:ui'`) ; z_document_viewer_prefs.dart l.8-11 (précédent : enums Syncfusion refusés, mapping en presentation)]
- **D4 — Invariant `[0,1]` AJOUTÉ (assumé vs lex).** lex **ne borne pas** x/y/w/h (dartdoc « fractions [0,1] » = prose, aucune machine ne la tient). L'AC FR-S8 exige « bornée [0,1] » ⇒ R-H/R1 : l'invariant naît **avec sa garde** `sanitizeCoord`, aux **deux frontières** (`fromMap`+`copyWith`), jamais dans le ctor `const`. Précédent EXACT : `ZDocumentViewerPrefs.sanitizeZoomLevel` (clamp `[kMin,kMax]`, non-fini/`<=0` ⇒ défaut). [Source: z_document_viewer_prefs.dart l.55-67, l.116-127]
- **D5 — `is_deleted` inline lex REJETÉ + `updatedAt` inline lex REJETÉ (AD-19, cœur FR).** lex porte `final DateTime updatedAt` (**la clé LWW**) **et** `@JsonKey(defaultValue:false) final bool isDeleted` inline (document_annotation.dart l.59-64). C'est **exactement** le piège AD-19 réalisé dans la source — reproduit du contraste ES-2.1 (`ZStudyDocument` D2), en **plus aigu** car `updatedAt` **EST** l'autorité LWW. Rejet des deux ; `createdAt` **conservé** (clé `created_at` distincte des réservées, précédent `ZStudyFolder.archivedAt`). `_reservedKeys ⊇ ZSyncMeta.reservedKeys` est **le** rempart. [Source: document_annotation.dart l.56-64 ; z_study_document.dart l.15-29, l.313-329]
- **D6 — `colorKey` BRUT, aucun clamp entité.** Précédent EXACT `ZFlashcardTag.colorKey`/`ZStudyFolder.colorKey` : la borne de palette est **injectée À L'AFFICHAGE** (`remapColorKey`, ES-8.x), pas dans le domaine (clamper ici forcerait une palette codée en dur — viole AD-13 — ou l'injection de la palette dans `fromMap` — fait fuiter la présentation). La leçon H2 (garde partagée) ne s'applique **pas** à `colorKey` : il n'y a rien à garder. [Source: z_flashcard_tag.dart l.31-39, l.114-119]
- **D7 — Dépendance pubspec du gate : AUCUN ajout.** `tool/reserved_keys_gate/pubspec.yaml` déclare déjà `zcrud_document: ^0.1.0` (ES-2.1, l.63-67). Les deux nouvelles entités vivent dans ce même package ⇒ le gate les voit sans nouvelle arête. [Source: reserved_keys_gate/pubspec.yaml l.63-67]
- **D8 — `page` sanitisé `< 1 ⇒ 1`.** `page` est 1-based (aligné convention Syncfusion). Une valeur `<= 0` (corruption) n'est pas une page ⇒ repli `1` (une annotation a au moins une page d'ancrage). Décision R-H assumée (lex ne borne pas), aux deux frontières. Nuance vs `ZStudyDocument.sanitizePageCount` (nullable « inconnu » `<=0 ⇒ null`) : ici `page` est **non-null et requis** ⇒ repli déterministe `1`. [Source: z_study_document.dart l.290-296]

### Invariants AD & rétro à respecter

- **AD-3 codegen** : `@ZcrudModel`/`@ZcrudField`, `@JsonSerializable` pur, `fieldRename: snake`, enums camelCase, `@JsonKey(unknownEnumValue:)`. `reflectable` banni. Le générateur **ne supporte AUCUN `Map`** (non pertinent ici — pas de canal Map). `List<subModel>`/`subModel`/`List<String>`/`double`/`int` **sont** codegen-ables.
- **AD-4 extensibilité** : slot `extension` typé versionné (`fromJsonSafe`/`ZExtension.guard`) + `extra` fourre-tout ; round-trip des clés inconnues **préservé** ; évolution **additive**.
- **AD-10 défensif** : ne throw **jamais** ; **aucun `assert` dans un ctor `const`** ; champ absent/corrompu ⇒ fallback sûr ; `fromMap(const {})` sûr ; coordonnée non-numérique/négative/`NaN` ⇒ fallback **déterministe**, pas de throw.
- **AD-16/AD-19** : soft-delete + LWW **hors-entité** (`ZSyncMeta`). Le store écrit sa méta **après** le corps ⇒ un champ métier sous clé réservée serait écrasé silencieusement (ES-1.3).
- **AD-26** : contenu partageable (`ZDocumentAnnotation`) **séparé** de l'état personnel — l'annotation **est** du contenu partageable (précédent `ZStudyDocument`), pas un état de lecture.
- **R1** : un invariant de valeur naît **avec sa garde** (bounds `[0,1]`, `page>=1`). **R2** : chaque garde/gate a sa **fixture d'échec ISOLÉE**. **R3** : **injection de régression** rejouée par l'orchestrateur (retirer la garde ⇒ ROUGE observé). **R5** : AST, pas regex (le gate `reserved-keys` dérive les voies du DISQUE). **R6** : tout saut d'assertion **déclaré et contrôlé**. **R8** : câblage du gate **dans la même story**. **R-G** : divergence vs lex **documentée par écrit**. **R-H** : garde **partagée nommée** aux deux frontières (jamais deux jumelles).
- **Leçons fraîches** : (ES-2.3) un golden/hash peut **passer par coïncidence** ⇒ vecteurs à **pouvoir discriminant OBSERVÉ** (valeurs distinctes des défauts). (ES-2.4 DW-ES24-1) l'immuabilité d'un canal n'est **profonde** que sur `fromMap`/`copyWith`, pas sur le ctor `const` — ne pas surpromettre « immuabilité profonde » sans qualifier la voie (ici : `rects` est une `List` — sa non-mutation vient de `fromMap`/`copyWith`, le ctor `const` reçoit la référence telle quelle).

### Fichiers à toucher

| Fichier | Nature |
|---|---|
| `packages/zcrud_document/lib/src/domain/z_document_annotation_kind.dart` | NEW |
| `packages/zcrud_document/lib/src/domain/z_annotation_bounds.dart` (+ `.g.dart`) | NEW |
| `packages/zcrud_document/lib/src/domain/z_document_annotation.dart` (+ `.g.dart`) | NEW |
| `packages/zcrud_document/lib/zcrud_document.dart` | UPDATE (barrel + `hide`) |
| `packages/zcrud_document/test/z_annotation_bounds_test.dart` | NEW |
| `packages/zcrud_document/test/z_document_annotation_test.dart` | NEW |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | UPDATE (câblage 2 entités) |

**État actuel du barrel `zcrud_document.dart`** (à préserver) : exporte déjà `z_doc_page_quality`, `z_document_learning_info`, `z_document_reading_state` (hide `…Zcrud`), `z_document_status`, `z_document_viewer_prefs` (hide `…Zcrud`), `z_study_document` (hide `…Zcrud`). Ajouter les 3 nouveaux exports **sans** casser la politique UNIFORME de `hide`.

### Project Structure Notes

- `zcrud_document` importe **uniquement** `zcrud_core` (surface pur-Dart `domain.dart` pour l'entité `ZExtensible`, `edition.dart` pour le VO), `zcrud_study_kernel`, `zcrud_annotations` (AD-1/AD-17, graphe acyclique, CORE OUT=0). Cette story **n'ajoute aucune arête** de package.
- Tests sous `package:test/test.dart` (`dart test`), **jamais** `flutter_test` — le package est pur-Dart (aucun `@Tags`, aucun `dart:io`).
- Le gate `reserved-keys` tourne, lui, sous `flutter test --tags reserved-keys` via `scripts/ci/gate_reserved_keys.dart` (harnais `tool/`, hors `melos test`).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-2.5 (l.416-429), #FR-S8 (l.41, l.112), #ES-8.2 (l.906-912), #AD-21-cascade (l.550)]
- [Source: packages/zcrud_document/lib/src/domain/z_study_document.dart — patron `ZEntity`+`ZExtensible` INTÉGRAL, AD-19 D2]
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart — jumeau `extra` ES-2.2b, `colorKey` brut D4]
- [Source: packages/zcrud_document/lib/src/domain/z_document_viewer_prefs.dart — VO NON-`ZExtensible` avec invariant de valeur clampé + `hide` M2]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_choice.dart — VO `@ZcrudModel` décodé en `listModel`]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart#choices (l.167, l.395) — précédent `List<subModel>?` codegen + `_listEquals`]
- [Source: tool/reserved_keys_gate/lib/src/registrars.dart — contrat d'extension R8 (kRegistrars/kProbeBodies/kNonExtensibleKinds/kExtraWriters)]
- [Source: tool/reserved_keys_gate/pubspec.yaml (l.63-67) — `zcrud_document` déjà dépendance]
- [Source: scripts/ci/gate_reserved_keys.dart — règles AST (g)/(g2)/(j)/(k), couverture DISQUE]
- [Source lex À DIVERGER : lex_core/lib/domain/entities/education/document_annotation.dart (l.56-64 `updatedAt`+`isDeleted` inline), annotation_bounds.dart (l.1 `dart:ui`), enums/education/document_annotation_kind.dart]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story, effort high) — skill BMAD `bmad-dev-story` invoqué via le tool `Skill` (PAS de fallback disque).

### Debug Log References

- Codegen : `build_runner build --delete-conflicting-outputs` OK (2 sorties : `z_annotation_bounds.g.dart`, `z_document_annotation.g.dart`) ; ré-exécution finale « wrote 0 outputs » (aucun churn).
- `dart test` (package `zcrud_document`) : **166 tests, All tests passed** (RC=0), dont ~40 nouveaux (bounds + annotation).
- `dart analyze lib` : **No issues found**. `melos run analyze` repo-wide : **SUCCESS** (RC=0 ; les 2 `info` résiduels sont pré-existants dans `z_document_viewer_prefs_test.dart`, ES-2.1).
- Gate `reserved-keys` (`scripts/ci/gate_reserved_keys.dart`) : **RC=0** — `document_annotation` **et** `annotation_bounds` effectivement sondés (14 registrars, 21 voies d'écriture, 4 canaux hors-codegen). `prove_gates.dart` : **41 OK / 0 FAIL**. `graph_proof.py` : **ACYCLIQUE + CORE OUT=0** (30 arêtes ; `zcrud_document` ne gagne aucune arête interdite, zéro `dart:ui`/flutter au domaine).

### Completion Notes List

**Injections de régression R3 (exécutées réellement, restaurées par édition ciblée — jamais `git checkout`)**

1. **Voie `ctor` retirée de `kExtraWriters['document_annotation']` (règle (j))** — gate ROUGE :
   > `[gate:reserved-keys] ÉCHEC : (j) VOIE D'ÉCRITURE NON SONDÉE : ZDocumentAnnotation.ctor (…z_document_annotation.dart) prend un paramètre extra — c'est une voie d'écriture PUBLIQUE du slot AD-4 — mais elle n'est PAS câblée dans le harnais.`
   Restaurée (ctor + copyWith re-câblés).

2. **`hide ZDocumentAnnotationZcrud` retiré du barrel (règle (h))** — gate ROUGE (RC=1) :
   > `[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : ZDocumentAnnotationZcrud est exposée par …zcrud_document.dart (export … sans hide), alors que ZDocumentAnnotation est ZExtensible.`
   Restauré.
   - ⚠️ **Finding (R-G, dette)** : la règle (h) **ne couvre QUE les `ZExtensible`**. Retirer `hide ZAnnotationBoundsZcrud` (VO NON-`ZExtensible`) laisse le gate **VERT** — exactement comme `ZDocumentViewerPrefs` (précédent M2). La fermeture de la porte `copyWith` du VO à invariant repose donc sur **convention + promotion `toMap`/`copyWith` d'instance + `hide`**, PAS sur une machine. Dette **pré-existante** (identique à `ZDocumentViewerPrefs`), non introduite par ES-2.5 — à statuer en rétro ES-2 (proposition : étendre (h) aux `@ZcrudModel` NON-`ZExtensible` portant un invariant de valeur).

3. **`sanitizeCoord` neutralisé (`=> raw`, clamp `[0,1]` contourné)** — tests ROUGES avec pouvoir discriminant OBSERVÉ :
   > `AC2 … FIXTURE R2 — fromMap {x:5, y:-3, width:NaN, height:0.4} [E]  Expected: <1.0>  Actual: <5.0>`
   > `AC8 … FIXTURE R2 — map polluée [E]  Expected: ZAnnotationBounds(x: 1.0, …)  Actual: ZAnnotationBounds(x: 2.0, …)` (le clamp des `rects` per-élément flue bien via `ZAnnotationBounds.fromMap`).
   Restauré.

4. **`...ZSyncMeta.reservedKeys` retiré de `ZDocumentAnnotation._reservedKeys`** — gate ROUGE (volet B, RC=1) **et** test per-entité ROUGE :
   > `[gate:reserved-keys] ÉCHEC : ajoutez ...ZSyncMeta.reservedKeys à _reservedKeys (AD-19.1) — …z_document_annotation.dart`
   > `AC6 … FIXTURE R2 — is_deleted/updated_at injectés [E]  Expected: empty  Actual: {'updated_at': …, 'is_deleted': false}`
   Restauré.

**Décisions D remises en cause** : aucune. D1–D8 confirmées par le code réel (générateur, source lex, précédents `ZDocumentViewerPrefs`/`ZChoice`/`ZFlashcard`). Le générateur décode bien `bounds` en `subModel` et `rects` en `listModel` per-élément via `ZAnnotationBounds.fromMap` (donc auto-clamp per-rect) — conforme à AC8/AC12, aucun canal `Map` hors-codegen.

**Dettes ouvertes** : (a) lacune de la règle (h) sur les VO NON-`ZExtensible` à invariant (ci-dessus) ; (b) `.g.dart` régénérés LAISSÉS dans l'arbre non committés (commit en fin d'epic, comme prescrit).

### File List

- `packages/zcrud_document/lib/src/domain/z_document_annotation_kind.dart` (NEW)
- `packages/zcrud_document/lib/src/domain/z_annotation_bounds.dart` (NEW)
- `packages/zcrud_document/lib/src/domain/z_annotation_bounds.g.dart` (NEW, généré)
- `packages/zcrud_document/lib/src/domain/z_document_annotation.dart` (NEW)
- `packages/zcrud_document/lib/src/domain/z_document_annotation.g.dart` (NEW, généré)
- `packages/zcrud_document/lib/zcrud_document.dart` (UPDATE — barrel + 3 exports, 2 avec `hide`)
- `packages/zcrud_document/test/z_annotation_bounds_test.dart` (NEW)
- `packages/zcrud_document/test/z_document_annotation_test.dart` (NEW)
- `tool/reserved_keys_gate/lib/src/registrars.dart` (UPDATE — câblage gate des 2 entités)
