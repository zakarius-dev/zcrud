---
baseline_commit: 709406ddf1ea40c15c4f638ff9a84fcab1dcc789
---

# Story ES-2.3 : Tags de flashcard first-class (`ZFlashcardTag` / `ZSuggestedTag`)

Status: done

- **Clé sprint-status** : `es-2-3-tags-flashcard-first-class`
- **Epic** : ES-2 (Domaine canonique éducatif + codegen)
- **Taille** : **M**
- **Parallélisation** : ⛔ **SÉQUENTIELLE** — cette story **ÉCRIT `zcrud_study_kernel`** (nouveaux fichiers domaine + barrel). Aucune autre story ne peut écrire le kernel en parallèle (garde-fou n°2 de CLAUDE.md : le seul point de contact possible entre workstreams est le cœur/kernel → une seule story y écrit à la fois). **Packages écrits** : `packages/zcrud_study_kernel/` (domaine + barrel), `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (**liste `hide`/allowlist** du réexport kernel — cf. **D7**), `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (allowlist), `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage du gate — **R8**).
- **Couvre** : **FR-S6** · AD-3, AD-4, AD-10, AD-13, AD-16, AD-17, AD-19 (+ 19.1/.a/.b/.c) · NFR-S6, NFR-S7, NFR-S10 · SM-S5, SM-S7 · R1–R9 (rétro ES-1).
- **Dépend de** : **ES-1** (complet — `ZColorPalette`/`ZKeyHash`/`zFnv1a32`/`normalizeTagTitle` d'ES-1.2, `ZSyncMeta` d'ES-1.3, gates d'ES-1.4) + **ES-2.0** (`done` — registrar câble `ZXxx.fromMap` de DOMAINE) + **ES-2.2b** (`done` — **le patron `extra` systémique** : slot brut `_extra`, accesseur normalisant, garde partagée, câblage `kExtraWriters` **par voie**).

> ✅ **Périmètre VÉRIFIÉ dans l'epic** (`epics-zcrud-study-2026-07-12/epics.md` l. 39, 110, 379-401 + table de traçabilité) : **FR-S6 = « Tags de flashcard first-class » = `ZFlashcardTag`/`ZSuggestedTag` + `remapColorKey` = ES-2.3**. L'**UI** de tags (éditeur/chips/confirmation-IA + **purge** des références orphelines) est **FR-S27 = ES-8.1** — **hors périmètre ici** : cette story ne livre **aucun widget**, **aucun repository**, **aucune purge** ; elle livre les **entités de domaine** + les **primitives pures** (remap couleur, détection d'orphelins).

---

## Story

**As a** développeur intégrant zcrud dans une app d'étude (lex_douane, IFFD),
**I want** modéliser des **tags de flashcard typés** — `ZFlashcardTag` (`{id, title, colorKey}`, persistable) et `ZSuggestedTag` (`{title, colorKey}`, proposition d'un port IA) — dont la **couleur est une clé symbolique bornée par une palette INJECTÉE** (jamais verrouillée aux 8 clés de lex, jamais un `Color` codé en dur), avec un **remap déterministe** `remapColorKey`,
**so that** je remplace le `tagIds: List<String>` nu par des **entités first-class** sans importer `crypto` dans le kernel, sans réintroduire une palette verrouillée, et sans que la couleur devienne un invariant de domaine impossible à thémer (AD-13).

---

## ⚠️ LE PATRON ES-2 (établi ES-2.0, durci ES-2.1, **systématisé ES-2.2b**) — à respecter DÈS LA NAISSANCE

`zcrud_generator` **et** `gate:reserved-keys` imposent, **PAR MACHINE**, sur toute classe `@ZcrudModel` :

1. **Décodeur de domaine obligatoire** — `Xxx.fromMap(Map<String, dynamic> map)` (factory ou statique). **Absent ⇒ ÉCHEC DE BUILD** (`_requireDomainFromMap`).
2. **Si la classe est `ZExtensible`** — sa `fromMap` **ne doit PAS déléguer nuement** à `_$XxxFromMap` (détecté à l'**AST du corps** ⇒ **BUILD ROUGE** via `_rejectNakedCodegenDelegation`). Elle **peuple `extra`** : `extra: _extraFrom(map)`. *(Une classe **NON-`ZExtensible`** — `ZChoice`, `ZDocumentViewerPrefs` — **PEUT** déléguer nuement : `factory Xxx.fromMap(m) => _$XxxFromMap(m);`. C'est le cas de `ZSuggestedTag` — **D2**.)*
3. **Garde RUNTIME** (`_$zRequireExtraPreserved`) émis dans le `.g.dart` de toute classe `ZExtensible` : décode une sonde et **exige que la clé hors-schéma survive au round-trip COMPLET** (`fromMap` **ET** `toMap`). **Pas** sous `assert` ⇒ mord **en release**, à l'enregistrement.
4. 🔴 **Le patron `extra` de ES-2.2b — NON NÉGOCIABLE pour `ZFlashcardTag`** (`ZExtensible`) :
   - constructeur `const` qui **ne filtre RIEN** : `: _extra = extra;` (slot **brut**, un paramètre nommé ne peut PAS être `this._extra` privé — `ignore: prefer_initializing_formals`) ;
   - slot brut `final Map<String, dynamic> _extra;` **lu NULLE PART ailleurs** (ni `toMap`, ni `==`, ni `hashCode`) ;
   - accesseur `@override Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);` — **LE SEUL POINT que TOUTES les voies traversent** (promesse **inconditionnelle**, sans `assert`, sans `throw`, sans perdre `const` — c'est la résolution **HIGH-2** d'ES-2.2b) ;
   - garde partagée `_sanitizeExtra(raw) => zSanitizeExtra(raw, _reservedKeys)` appelée par **`fromMap` ET `copyWith`** (jamais divergentes — leçon H2) ;
   - `toMap()` = `{...extra, ...ZFlashcardTagZcrud(this).toMap()}` — **étale l'ACCESSEUR `...extra`** (qui normalise), **jamais** le champ brut `_extra` (retirer l'accesseur ⇒ `(i.1)`/`(i.3)` **ROUGES** via la voie `ctor`) ;
   - égalité **PROFONDE** : `zJsonEquals(extra, other.extra)` / `zJsonHash(extra)` (`extra` porte du JSON arbitraire imbriqué — DW-ES22-4).
5. 🔴 **(h) — POLITIQUE `hide` DES EXTENSIONS GÉNÉRÉES, tenue par machine.** Aucune extension générée `XxxZcrud` d'une entité `@ZcrudModel` ne peut être exportée par un point d'entrée public (son `copyWith` **généré** remet `extra`/`extension`/canaux à leurs défauts ⇒ **destruction silencieuse** — finding H3 d'ES-2.1). ⇒ **`hide ZFlashcardTagZcrud` ET `hide ZSuggestedTagZcrud`** OBLIGATOIRES **dans le barrel du kernel**.

**Les patrons de référence à COPIER, sur disque :**
- `ZExtensible` **SANS canal hors-codegen** (tous champs codegen-able) : `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart` — **le jumeau le plus direct** de `ZFlashcardTag` (mêmes voies : `fromMap` peuplant `extra` · `_reservedKeys = {...$FieldSpecs, 'extension', ...ZSyncMeta.reservedKeys}` · `toMap()` = `{...extra, ...généré}` · `copyWith` à sentinelle · `_sanitizeExtra` partagée · accesseur `extra` normalisant · `==`/`hashCode` profonds).
- `ZEntity + ZExtensible + @ZcrudId()` : `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` (id nullable éphémère · `colorKey` **déjà** un `@ZcrudField` `String` brut — **le précédent EXACT** du champ couleur, cf. **D4**).
- **NON-`ZExtensible` `@ZcrudModel`** (value object) : `packages/zcrud_flashcard/lib/src/domain/z_choice.dart` — **le jumeau de `ZSuggestedTag`** (`class ZChoice {` · `const` ctor · `factory fromMap(m) => _$…FromMap(m)` **nue** · `==`/`hashCode` scalaires · **aucun `extra`**).
- **Registre de la palette + remap déterministe** : `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart` (**`ZColorPalette.resolveKey`** — le remap **existe déjà**, cf. **D3**).

---

## ⚠️ Décisions de conception — CHAQUE prescription est CONFRONTÉE AU CODE RÉEL (R4 / R-G)

> **Leçon R-G** : *en ES-1.2, ES-1.4 et ES-2.1, les défauts venaient de la **STORY**.* Les décisions ci-dessous sont **fermées** — le dev ne les rejoue pas — **mais il DOIT les remettre en cause si le code réel (lex/kernel) les contredit, et le dire en Completion Notes.**

### D1 — Schéma canonique = **lex**, sources LUES fichier par fichier

| Élément | Source canonique (LUE) |
|---|---|
| `ZFlashcardTag` | `lex_douane/packages/lex_core/lib/domain/entities/education/flashcard_tag.dart` (`{id, title, colorKey}`, `@JsonSerializable(fieldRename: snake)`) |
| `ZSuggestedTag` | `lex_douane/packages/lex_core/lib/domain/entities/education/suggested_tag.dart` (`{title, colorKey}`, DTO, **pas d'id**) |
| Remap couleur | `flashcard_tag.dart` l. 55-68 (`remapColorKey(raw, seedTitle)` — **SHA-256** `% length`, miroir serveur `_normalize_color_key`) |
| Intégrité référentielle | `lex_douane/packages/lex_core/lib/domain/repositories/study_tags_repository.dart` (`deleteTag` **purge** les `tagIds` de toutes les cartes ; `usageCount`) |

**Constats de disque décisifs :**
1. lex `FlashcardTag` **verrouille la palette à 8 clés en dur** (`allowedColorKeys = {blue, green, orange, purple, red, teal, pink, indigo}`) et **remappe par `sha256` du TITRE** (import `package:crypto`). **Les deux sont REJETÉS pour zcrud** (D3).
2. lex `SuggestedTag` est un **DTO camelCase** (contrat wire), **sans id**, **sans `extra`** — c'est un **value object** (D2).
3. Ni `FlashcardTag` ni `SuggestedTag` ne portent `updatedAt`/`isDeleted` : le soft-delete du tag est **hors-entité** (repository, `is_deleted`) — **R-C n'est PAS réalisé dans la source ici** (contrairement à `ZSmartNote`), mais l'assertion AD-19 reste **obligatoire** (R8).

### D2 — `ZFlashcardTag` = `ZEntity with ZExtensible` · `ZSuggestedTag` = **value object NON-`ZExtensible`**

**`ZFlashcardTag`** est un **contenu personnel top-level à identité propre** (lex : `final String id`, UUID assigné par le repo). ⇒ `@ZcrudModel(kind: 'flashcard_tag') class ZFlashcardTag extends ZEntity with ZExtensible`, `@ZcrudId() final String? id;` (**nullable** ⇒ éphémère AD-14, patron `ZStudyFolder`/`ZFlashcard` — **l'entité n'attribue JAMAIS d'id** ; la matérialisation est au repository, **ES-3/ES-8.1**). Le mixin `ZExtensible` est requis par la discipline AD-4 (échappatoire `extra` versionnée) **et** par le fait que toute entité personnelle du corpus l'expose (round-trip des clés inconnues du store).

**`ZSuggestedTag`** est un **DTO éphémère** produit par un **port IA** (ES-9), **jamais persisté top-level** : l'utilisateur l'**accepte** → il devient un `ZFlashcardTag` (avec id). ⇒ **value object** : `@ZcrudModel(kind: 'suggested_tag') class ZSuggestedTag` (**PAS** `ZEntity`, **PAS** `ZExtensible`, **PAS d'id**, **PAS d'`extra`**). C'est **exactement** le régime de `ZChoice` / `ZDocumentViewerPrefs`. Conséquences machine (D6) : `fromMap` **déléguant nuement** autorisée ; ajout à **`kNonExtensibleKinds`** ; **absent** de `kExtraWriters`.

> 🔴 **Pourquoi `ZSuggestedTag` reste `@ZcrudModel`** (et non hand-written) : l'epic l'exige (« ce sont des entités `@ZcrudModel` »), et le codegen lui donne un round-trip défensif gratuit (`title`/`color_key` absents → `''`). Une entité `@ZcrudModel` **DOIT** être câblée au gate (**R8**) même NON-`ZExtensible` : `kRegistrars` + `kProbeBodies` + `kNonExtensibleKinds` (sinon `R_disk \ R_wired ≠ ∅` ⇒ gate **ROUGE**).

### D3 — 🔴 **LE CŒUR DE LA STORY** : `remapColorKey` **RÉUTILISE `ZColorPalette`**, ne réintroduit **NI palette verrouillée NI `crypto`**

Le remap **existe déjà** : `ZColorPalette.resolveKey(String? raw)` (ES-1.2) est **pur, total, déterministe, cross-plateforme** (hash `zFnv1a32` **JS-safe**, injectable via `ZKeyHash`), rend **toujours** une clé de `keys` (jamais de throw, jamais hors-palette — findings L1/D2 d'ES-1.2 déjà soldés). ⇒ **On ne réécrit PAS un remap ; on l'HABILLE** pour la sémantique « tag ».

**Trois REJETS explicites de la forme lex (R6 — corrections structurelles, pas rustines) :**
1. ⛔ **PAS `package:crypto` / SHA-256.** `ZColorPalette` a **délibérément** choisi FNV-1a pour préserver la fermeture transitive minimale du kernel (`{zcrud_core, zcrud_annotations}` — NFR-S10/SM-S7). Une app qui a besoin de **parité byte-à-byte** avec le serveur lex injecte son propre `ZKeyHash` (SHA-256) **sans** que le kernel n'acquière `crypto` (AD-4 : extension par injection). Le remap ne décide **QUE** du **slot de palette affiché** : la valeur **persistée** reste la `colorKey` brute.
2. ⛔ **PAS de palette de 8 clés en dur.** L'AC est explicite : *« la palette est **injectée** (AD-13, pas verrouillée à 8 clés lex) »*. `remapColorKey` **prend une `ZColorPalette` en paramètre** (défaut recommandé aux appelants : `ZColorPalette.defaultStudy()` — clés **neutres** `{primary, secondary, tertiary, success, warning, danger, info, neutral}`, **aucune couleur**). Le kernel ne connaît **aucune** couleur concrète (SM-S5 : zéro `Color`/`IconData`/hex).
3. ⛔ **PAS de `Color` dans le domaine.** `colorKey` est une **`String` symbolique** ; la résolution `colorKey → Color` est un **seam de présentation** de `zcrud_core` (`ZcrudScope.colorKeyResolver`, hors périmètre ES-2.3). AD-13 / FR-26 / NFR-S7.

**Divergence RÉELLE à trancher (R-G) — la graine du remap :** lex hash le **TITRE** (`seedTitle`), pas la `colorKey` brute (« même tag → même couleur, reproductible »). `ZColorPalette.resolveKey(raw)` hash **`raw`** (la clé). ⇒ `remapColorKey` doit **exposer les deux** et préserver la sémantique lex quand la clé est inconnue. **Forme recommandée (pure, déterministe, `dart test`) :**

```dart
/// Résout la `colorKey` AFFICHABLE d'un tag contre une palette INJECTÉE.
/// PURE · TOTALE · DÉTERMINISTE (mêmes entrées → même sortie, cross-plateforme) ·
/// ne throw JAMAIS · résultat TOUJOURS ∈ palette.keys (jamais hors-palette).
String remapColorKey({
  required ZColorPalette palette,
  String? rawColorKey,     // clé proposée (store / IA / saisie) — peut être null/vide/inconnue
  String? seedTitle,       // graine de remap (titre du tag) — « même tag → même couleur » (lex)
}) {
  final raw = (rawColorKey ?? '').trim().toLowerCase();
  if (palette.keys.contains(raw)) return raw;               // clé connue → telle quelle
  // clé inconnue/vide → remap DÉTERMINISTE sur la graine, via l'algo INJECTABLE de la palette.
  final seed = (seedTitle == null || seedTitle.trim().isEmpty) ? raw : seedTitle;
  return palette.resolveKey(seed.isEmpty ? null : seed);    // délègue — AUCUN hash dupliqué (R6)
}
```

> 🔴 **Ne PAS dupliquer la logique de hash/modulo** de `ZColorPalette.resolveKey` (R6, précédent `ZColorSlot` de la rétro ES-1) : `remapColorKey` **compose** la palette, il ne la réimplémente pas. Si le dev trouve que `resolveKey` ne compose pas proprement (ex. `resolveKey(seed)` renverrait `seed` si `seed ∈ keys`, cas dégénéré d'un titre = un nom de clé), il **le mesure** et ajuste — mais **jamais** en réintroduisant un hash local.

### D4 — 🔴 `colorKey` est un `@ZcrudField` `String` **BRUT** — **AUCUN clamp dans l'entité**

**Précédent EXACT sur disque** : `ZStudyFolder.colorKey` est **déjà** un `@ZcrudField() final String colorKey;` **brut** (canonique §138 : *« clé de thème couleur (libre, résolue côté UI) »*). ⇒ `ZFlashcardTag.colorKey` **suit ce précédent** : `String` brut, défaut `''` (défensif AD-10), **stocké VERBATIM**.

**Pourquoi PAS de clamp `remapColorKey` au constructeur/`fromMap`/`copyWith` (contraste avec `ZSmartNote.content`, D5 d'ES-2.2) :** le clamp exige la **palette INJECTÉE**, que le domaine **ne possède pas** (c'est un seam de présentation). Clamper dans l'entité forcerait soit (a) une palette codée en dur (viole l'AC « pas verrouillée à 8 clés » + AD-13 « jamais de couleur/clé codée en dur »), soit (b) l'injection de la palette dans `fromMap` (fait **fuiter la présentation dans le domaine**). ⇒ **`colorKey` n'a AUCUN invariant de valeur au niveau entité** : il est **borné À L'AFFICHAGE** par `remapColorKey(palette, ...)` chez le consommateur (UI ES-8.1). **La leçon H2 (garde partagée `fromMap`/`copyWith`) ne s'applique donc PAS à `colorKey`** — il n'y a rien à garder. **À DOCUMENTER en dartdoc** pour qu'une revue ne le prenne pas pour un oubli (« pourquoi pas de clamp comme `content` ? » — parce que la borne est palette-dépendante, et la palette est injectée).

### D5 — 🔴 Intégrité référentielle : une **primitive PURE de détection**, PAS de purge

AC3 : *« un tag supprimé encore référencé par `tagIds` ⇒ la référence orpheline est **détectable** (base de l'intégrité référentielle traitée en UI, FR-S27/ES-8.1) »*. La **purge** (retirer l'`id` des `tagIds` de toutes les cartes) est le travail du **repository** `deleteTag` (lex `study_tags_repository.dart`) — **ES-8.1 / ES-3**, **hors périmètre**. Cette story livre la **primitive de DÉTECTION**, pure et testable sous `dart test` :

```dart
/// Sous-ensemble des `tagIds` RÉFÉRENCÉS qui ne correspondent à AUCUN tag EXISTANT
/// (références orphelines). PURE · TOTALE · déterministe · ne throw JAMAIS ·
/// ordre d'entrée préservé, dédoublonné.
Set<String> orphanTagIds({
  required Iterable<String> referencedTagIds,   // ex. ZFlashcard.tagIds agrégés
  required Iterable<String> existingTagIds,     // ex. ZFlashcardTag.id des tags vivants
});
```

Elle vit dans un fichier pur du kernel (ex. `tag_referential_integrity.dart`) ou en fonction top-level de `z_flashcard_tag.dart` (choix dev — **fichier hors de la liste illustrative de l'epic autorisé**, l'epic ne l'énumère pas mais l'AC l'exige). ⚠️ **Ne PAS** dériver `existingTagIds` en dépendant de `zcrud_flashcard` (le kernel **ne dépend d'AUCUN satellite** — AD-1/AD-17) : la fonction prend des **`String` neutres** (mêmes clés opaques que `ZSessionCandidate.tagIds`, leçon L2 d'ES-2.1 « dépendance DÉCLARÉE, aucun import »).

### D6 — Câblage du gate `reserved-keys` (**R8**) — DANS LA MÊME STORY

`tool/reserved_keys_gate` **dépend déjà** de `zcrud_study_kernel` (`pubspec.yaml` l. 59) ⇒ **aucun ajout de dépendance**. Câblage de `registrars.dart` :

| Entrée | `flashcard_tag` (`ZExtensible`) | `suggested_tag` (NON-`ZExtensible`) |
|---|---|---|
| `kRegistrars` | += `registerZFlashcardTag` | += `registerZSuggestedTag` |
| `kProbeBodies` | `{'id':'p', 'title':'t', 'color_key':'blue'}` | `{'title':'t', 'color_key':'blue'}` |
| `kNonExtensibleKinds` | ⛔ **NON** (elle EST `ZExtensible`) | ✅ **`+= 'suggested_tag'`** |
| `kExtraWriters` | ✅ **DEUX voies** : `ctor` (`eagerlyNormalized: false`) **ET** `copyWith` (`eagerlyNormalized: true`) — transmises **VERBATIM** (règle (k)) | ⛔ **NON** (pas d'`extra`) |
| `kLegacyUpdatedAtMirrors` | ⛔ **INCHANGÉ** (`{study_folder, flashcard}`) — verrou d'égalité figé | ⛔ **INCHANGÉ** |
| `manual_probes.dart` | ⛔ **NON** (`@ZcrudModel`, dans `R_disk`) | ⛔ **NON** |

> 🔴 **Les DEUX voies de `flashcard_tag` sont obligatoires** (résolution HIGH-1/HIGH-2 d'ES-2.2b) : la règle **AST (j)** (`scripts/ci/gate_reserved_keys.dart`) **dérive du DISQUE** les voies publiques d'écriture de `extra` (tout constructeur public + toute méthode publique portant un paramètre `extra`) et **exige** qu'elles soient TOUTES câblées — dans les **deux sens** (voie non câblée ⇒ ROUGE ; voie morte ⇒ ROUGE). Câbler **seulement `copyWith`** (la voie filtrante) rendrait la garde de la voie `ctor` (polluante, `const`) **hors de portée de toute machine** — le défaut exact mesuré sur 6 entités en ES-2.2b.

### D7 — 🔴 Surface publique : barrel kernel + réexport `zcrud_flashcard` (garde `z_kernel_surface_guard_test`)

Le kernel expose son API par `lib/zcrud_study_kernel.dart` ; `zcrud_flashcard` **réexporte** ce barrel via une liste **`hide`** (jamais `show`) + une **allowlist** de test (`z_kernel_surface_guard_test.dart`). **Tout nouveau symbole public du barrel kernel DOIT être CLASSÉ**, sinon `z_kernel_surface_guard_test` **ÉCHOUE** (anti-fuite silencieuse, finding L4 d'ES-1.2). Classement retenu :

| Symbole kernel nouveau | Barrel kernel | `zcrud_flashcard` |
|---|---|---|
| `ZFlashcardTag` | `export … hide ZFlashcardTagZcrud;` (masque **l'extension générée**) | **allowlist** (`_flashcardAllowlist`) — pertinent flashcard, réexporté (migration DODLP) |
| `ZSuggestedTag` | `export … hide ZSuggestedTagZcrud;` | **allowlist** — pertinent flashcard |
| `remapColorKey` | export normal | **allowlist** — sémantique tag/flashcard |
| `orphanTagIds` (ou nom retenu) | export normal | **allowlist** — sémantique tag/flashcard |
| `registerZFlashcardTag` / `registerZSuggestedTag` / `$…FieldSpecs` | export normal (générés) | **allowlist** (patron `registerZStudyFolder` — surface E9 historique) |

> ⚠️ La classification **allowlist vs hide** est un **choix EN CONSCIENCE** validé par le test (pas une devinette) : le dev exécute `z_kernel_surface_guard_test.dart`, lit chaque symbole non classé qu'il signale, et l'ajoute **soit** au `hide` de `zcrud_flashcard` (hors périmètre flashcard) **soit** à `_flashcardAllowlist` (pertinent). **allowlist ∩ hide = ∅** (test dédié). Recommandation ci-dessus = tags/couleur **pertinents flashcard** → allowlist ; **jamais** `hide` (ce ne sont pas des utilitaires génériques comme `ZColorPalette`).

### D8 — AD-19 dès la naissance : **zéro** clé de sync dans les entités (R-C, même si la source est propre)

Ni `ZFlashcardTag` ni `ZSuggestedTag` ne déclarent `updatedAt`/`isDeleted` (ni sous ces noms, ni sous `updated_at`/`is_deleted`). Le soft-delete du tag et la fraîcheur LWW vivent **hors-entité** (`ZSyncMeta`, repository — AD-16/AD-19). Assertions **obligatoires** (R8, à NE PAS oublier — M1 d'ES-2.1) :
- `ZFlashcardTag._reservedKeys ⊇ ...ZSyncMeta.reservedKeys` (R-A — l'oubli s'est produit **2/4** en ES-1.3 sous 1193 tests verts) ;
- `$ZFlashcardTagFieldSpecs.map((s)=>s.name).toSet() ∩ ZSyncMeta.reservedKeys == {}` **et** idem `$ZSuggestedTagFieldSpecs` (R-C) ;
- **aucun** `@ZcrudField(persistAs: ZPersistAs.timestamp)` sur une clé réservée (AD-19.1.b).

*(`ZFlashcardTag` n'ajoute **aucun** `createdAt` : lex ne l'expose pas ; l'inventer serait un besoin fantôme — R-G. Si le dev trouve un `createdAt` de tag sur disque, il le porte sous `created_at`, clé **distincte**, jamais réservée.)*

---

## Schéma canonique retenu (clés persistées **snake_case**, enums **camelCase**)

### `ZFlashcardTag` — `@ZcrudModel(kind: 'flashcard_tag')` · `extends ZEntity with ZExtensible`

| Champ Dart | Type | Clé persistée | Défaut / défensif | Source lex |
|---|---|---|---|---|
| `id` | `String?` | `id` | `null` (éphémère) — `@ZcrudId()` | `id` (`String` **requis**) |
| `title` | `String` | `title` | `''` (absent/non-`String` → `''`) | `title` |
| `colorKey` | `String` | `color_key` | `''` **BRUT** (**D4** — clampé à l'affichage, jamais dans l'entité) | `colorKey` (borné 8 clés — **débordé**, D3) |
| `extension` | `ZExtension?` | `extension` | hors-codegen ; `null` si absent/non-`Map` (AD-4 pt.1) | — |
| `extra` | `Map<String,dynamic>` | *(clés non réservées)* | slot brut `_extra` + accesseur `zNormalizeExtra` (**ES-2.2b**) | — |
| ⛔ ~~`updatedAt`/`isDeleted`~~ | — | — | **hors-entité — AD-19 / D8** (`ZSyncMeta`, repository) | — |

`_reservedKeys = { for (s in $ZFlashcardTagFieldSpecs) s.name, 'extension', ...ZSyncMeta.reservedKeys }`

### `ZSuggestedTag` — `@ZcrudModel(kind: 'suggested_tag')` · **value object** (NON-`ZEntity`, NON-`ZExtensible`)

| Champ Dart | Type | Clé persistée | Défaut / défensif | Source lex |
|---|---|---|---|---|
| `title` | `String` | `title` | `''` | `title` |
| `colorKey` | `String` | `color_key` | `''` **BRUT** (**D4**) | `colorKey` |

*(⛔ **pas d'`id`**, **pas d'`extra`**, **pas d'`extension`** — DTO éphémère. `fromMap` **déléguant nuement** autorisée : `factory ZSuggestedTag.fromMap(m) => _$ZSuggestedTagFromMap(m);` — NON-`ZExtensible`, patron `ZChoice`.)*

### `remapColorKey` (fonction top-level pure) · `orphanTagIds` (fonction top-level pure)

Aucune annotation, aucun `.g.dart`, aucun `kind` — pures, totales, déterministes, `dart test`, ne throw JAMAIS (cf. **D3** / **D5**).

---

## Acceptance Criteria

### AC1 — `ZFlashcardTag` : `@ZcrudModel` `ZExtensible`, patron ES-2.2b **intégral**

**Given** le patron systémique d'`extra` (ES-2.2b)
**When** on modélise `ZFlashcardTag`
**Then** c'est `@ZcrudModel(kind: 'flashcard_tag') class ZFlashcardTag extends ZEntity with ZExtensible`, `@ZcrudId() final String? id;` (nullable ⇒ éphémère AD-14), `title: String = ''`, `colorKey: String = ''`
**And** son constructeur `const` **ne filtre RIEN** (`: _extra = extra;`), le slot brut `_extra` est **lu nulle part ailleurs**, l'accesseur `@override Map<String,dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);` est **le seul point traversé par toutes les voies**
**And** `fromMap` peuple `extra: _extraFrom(map)` (⛔ **jamais** de délégation nue à `_$ZFlashcardTagFromMap` — le build passerait ROUGE), et **aucun `assert` n'est présent dans le constructeur `const`** (AD-10 : le décodeur généré l'appelle avec des valeurs BRUTES)
**And** `_sanitizeExtra` est appelée par **`fromMap` ET `copyWith`** (garde partagée, leçon H2), `toMap()` étale l'**ACCESSEUR** (`...extra`), et `==`/`hashCode` utilisent `zJsonEquals`/`zJsonHash`.

### AC2 — `ZSuggestedTag` : value object `@ZcrudModel` NON-`ZExtensible`

**Given** que `ZSuggestedTag` est un DTO éphémère sans id
**When** on le modélise
**Then** c'est `@ZcrudModel(kind: 'suggested_tag') class ZSuggestedTag` (**PAS** `ZEntity`, **PAS** `ZExtensible`, **PAS d'id**, **PAS d'`extra`/`extension`**), `title: String = ''`, `colorKey: String = ''`
**And** sa `fromMap` **délègue nuement** (`factory ZSuggestedTag.fromMap(m) => _$ZSuggestedTagFromMap(m);`) — **autorisé** car NON-`ZExtensible` (le build ne le rejette PAS)
**And** `==`/`hashCode` sont scalaires (patron `ZChoice`), et le round-trip `fromMap`/`toMap` est défensif (`title`/`color_key` absents → `''`, jamais de throw, y compris `ZSuggestedTag.fromMap(const {})`).

### AC3 — 🔴 `remapColorKey` : PUR, DÉTERMINISTE, **palette injectée**, **jamais `crypto`**, **jamais hors-palette**

**Given** que `ZColorPalette.resolveKey` fournit déjà un remap déterministe JS-safe injectable (ES-1.2)
**When** on écrit `remapColorKey`
**Then** c'est une **fonction top-level pure** prenant une **`ZColorPalette` en paramètre** (jamais une palette de 8 clés codée en dur — AC epic ; jamais un `Color`), qui **délègue** à `palette.resolveKey` sans **dupliquer** le hash/modulo (R6)
**And** ⛔ `zcrud_study_kernel/pubspec.yaml` **ne gagne AUCUNE dépendance** (⛔ **PAS `crypto`**) — vérifié sur disque
**And** le résultat appartient **TOUJOURS** à `palette.keys` (jamais une clé hors-palette, jamais `null`, **jamais de throw** — AD-10), pour **toute** entrée : `rawColorKey` connue / inconnue / vide / `null`, `seedTitle` présent / vide / `null`
**And** le **déterminisme** est prouvé par **vecteurs golden** : mêmes `(palette, rawColorKey, seedTitle)` → **même** sortie, sur plusieurs appels (et — si le harnais JS du kernel le couvre — **cross-plateforme**, patron des vecteurs golden de `z_color_palette_test.dart`)
**And** la sémantique lex « **même `seedTitle` → même clé** » est vérifiée : `remapColorKey(palette: p, rawColorKey: 'inconnue', seedTitle: 'Droit Douanier')` est **stable** et **égale** pour deux appels, et une `colorKey` **connue** de `p` est rendue **telle quelle** (le remap ne s'applique qu'aux clés inconnues).

### AC4 — 🔴 D4 — `colorKey` **brut**, borné À L'AFFICHAGE, **aucun clamp dans l'entité**

**Given** le précédent `ZStudyFolder.colorKey` (`@ZcrudField` `String` libre, « résolue côté UI »)
**When** on décode/copie un tag
**Then** `colorKey` est **stocké VERBATIM** — `ZFlashcardTag(colorKey: 'zzz_inconnue').colorKey == 'zzz_inconnue'`, `fromMap({'color_key':'zzz'}).colorKey == 'zzz'`, `copyWith(colorKey: 'zzz').colorKey == 'zzz'` — **aucun** remap n'est appliqué **dans l'entité**
**And** un test **documente** (via commentaire/dartdoc) que le bornage se fait **à l'affichage** par `remapColorKey(palette, rawColorKey: tag.colorKey, seedTitle: tag.title)` chez le consommateur (ES-8.1) — **et NON** au niveau entité (la borne est palette-dépendante ; la palette est injectée)
**And** ⛔ **aucun `assert` de bornage** de `colorKey` dans le constructeur `const` (AD-10).

### AC5 — 🔴 D5 — Intégrité référentielle : primitive de **détection** pure (base de FR-S27)

**Given** qu'un tag supprimé peut rester référencé par les `tagIds` de cartes
**When** on appelle `orphanTagIds(referencedTagIds: …, existingTagIds: …)`
**Then** elle rend **exactement** le sous-ensemble des `referencedTagIds` **absents** de `existingTagIds` (références orphelines), déterministe, dédoublonné, ordre d'entrée préservé
**And** elle est **PURE / TOTALE** : `referencedTagIds` vide → `{}` ; `existingTagIds` vide → tous les référencés sont orphelins ; doublons/`''` gérés ; **jamais de throw** (AD-10)
**And** elle **n'importe AUCUN symbole de `zcrud_flashcard`** (clés `String` neutres — AD-1/AD-17, leçon L2)
**And** un test **cite explicitement** que la **purge** (retrait des refs) est **hors périmètre** (repository, ES-8.1/ES-3).

### AC6 — AD-19 dès la naissance : **zéro** clé de sync (R-C), prouvé **par machine**

**Given** que l'oubli de `...ZSyncMeta.reservedKeys` s'est produit 2/4 en ES-1.3 sous 1193 tests verts
**When** on modélise les deux entités
**Then** `ZFlashcardTag._reservedKeys ⊇ ZSyncMeta.reservedKeys` (assertion **écrite**), et **aucune** des deux entités ne déclare `updatedAt`/`isDeleted`
**And** `$ZFlashcardTagFieldSpecs.map((s)=>s.name).toSet().intersection(ZSyncMeta.reservedKeys)` **== {}** **ET** `$ZSuggestedTagFieldSpecs…intersection(...) == {}` (R-C — assertions **explicites**, à NE PAS oublier : M1 d'ES-2.1)
**And** **aucun** `persistAs: timestamp` sur une clé réservée (AD-19.1.b)
**And** `kLegacyUpdatedAtMirrors` reste **INCHANGÉ** (`{study_folder, flashcard}`) — le **test de verrou** d'égalité l'exige.

### AC7 — R-A : round-trip de STORE prouvé **COMPORTEMENTALEMENT** (anti-vacuité)

**Given** une **sonde de store** décodée par `ZFlashcardTag.fromMap` : `{'id':'p', 'title':'t', 'color_key':'blue', 'updated_at':'2026-01-01T00:00:00.000Z', 'is_deleted':true, 'zz_cle_inconnue':'gardee'}`
**When** on inspecte
**Then** `extra.keys.toSet().intersection(ZSyncMeta.reservedKeys)` est **VIDE**
**And** `extra['zz_cle_inconnue'] == 'gardee'` (anti-vacuité : on ne « passe » pas en vidant `extra`)
**And** `toMap()` **ne réémet NI `updated_at` NI `is_deleted`**, et **préserve** `zz_cle_inconnue`
**And** le round-trip **par le REGISTRE** est prouvé : `registry.decode('flashcard_tag', sonde)` puis `registry.encode` **préservent** `zz_cle_inconnue` (assertion **(e)** du gate).

### AC8 — Conformité au patron ES-2.0/ES-2.2b, **observée** (pas déclarée)

**Given** les filets machine du générateur + du gate
**When** `melos run generate` puis le harnais s'exécutent
**Then** `ZFlashcardTag` **peuple `extra`** (`extra: _extraFrom(map)`) et **ne délègue PAS nuement** — le build **passerait ROUGE** sinon ; son `toMap()` d'instance **étale `...extra`** ⇒ le garde runtime `_$zRequireExtraPreserved` (émis dans `z_flashcard_tag.g.dart`) **passe à l'enregistrement**
**And** `copyWith` est **à sentinelle** et couvre **TOUS** les champs (`id`, `title`, `colorKey`, `extension`, `extra`) — le `copyWith` **généré** les remettrait aux défauts (perte silencieuse ; patron `ZStudySessionConfig.copyWith`)
**And** la **pollution mémoire de la voie `ctor`** est neutralisée : `ZFlashcardTag(title:'t', extra: {'is_deleted': true}).extra` est **VIDE** (accesseur normalisant), et `f == ZFlashcardTag.fromMap(f.toMap())` est **`true`** (résolution HIGH-2 d'ES-2.2b).

### AC9 — R8 : câblage du harnais **DANS LA MÊME STORY**

**Given** qu'une entité **non câblée n'est pas sondée** (faux vert par omission)
**When** on ajoute les kinds `flashcard_tag` et `suggested_tag`
**Then** `tool/reserved_keys_gate/lib/src/registrars.dart` :
- `kRegistrars` += `registerZFlashcardTag`, `registerZSuggestedTag`
- `kProbeBodies['flashcard_tag'] = {'id':'p', 'title':'t', 'color_key':'blue'}` · `kProbeBodies['suggested_tag'] = {'title':'t', 'color_key':'blue'}`
- `kNonExtensibleKinds` **+= `'suggested_tag'`** (⛔ **PAS** `flashcard_tag`)
- `kExtraWriters['flashcard_tag']` = **[`ctor` (`eagerlyNormalized: false`), `copyWith` (`eagerlyNormalized: true`)]**, chacune transmettant `extra` **VERBATIM** (règle (k)) — ⛔ **rien** pour `suggested_tag`
**And** `tool/reserved_keys_gate/pubspec.yaml` **n'est PAS modifié** (dépendance `zcrud_study_kernel` déjà présente)
**And** `dart run scripts/ci/gate_reserved_keys.dart` est **VERT** — contrôle de couverture (`R_disk \ R_wired`), règles **(f)/(g)/(h)/(i)/(j)/(k)** comprises.

### AC10 — D7 : surface publique CLASSÉE (barrel + garde)

**Given** l'anti-fuite silencieuse `z_kernel_surface_guard_test`
**When** on ajoute les symboles au barrel `lib/zcrud_study_kernel.dart`
**Then** `export 'src/domain/z_flashcard_tag.dart' hide ZFlashcardTagZcrud;` **et** `export 'src/domain/z_suggested_tag.dart' hide ZSuggestedTagZcrud;` (les **extensions générées** ne sont **jamais** exportées — règle (h))
**And** `remapColorKey`, `orphanTagIds` et les registrars/field-specs générés sont exportés
**And** chaque nouveau symbole public du barrel kernel est **CLASSÉ** dans `zcrud_flashcard` (`_flashcardAllowlist` recommandé — pertinent flashcard) → `z_kernel_surface_guard_test.dart` est **VERT**, et `allowlist ∩ hide == ∅`
**And** la règle (h) de `gate:reserved-keys` est **verte** sur le kernel pour les deux nouveaux kinds.

### AC11 — AD-10 : chaque invariant naît **avec sa garde ET son cas corrompu**

**Given** que ces invariants sont, aujourd'hui, de la **prose**
**When** on les implémente
**Then** **chacun** porte (1) un test de **garde** (valeur légale) et (2) un test de **désérialisation corrompue** prouvant le **défaut sûr, sans throw** :

| Invariant | Garde | Cas corrompu (jamais de throw) |
|---|---|---|
| `ZFlashcardTag.title`/`ZSuggestedTag.title` | valeur conservée | absent / non-`String` ⇒ `''` |
| `colorKey` | valeur **BRUTE** conservée (D4) | absent / non-`String` ⇒ `''` — **jamais** clampé dans l'entité |
| `id` (`ZFlashcardTag`) | valeur conservée | absent ⇒ `null` (éphémère) |
| `extra` (`ZFlashcardTag`) | clé inconnue round-trippée | clé réservée injectée ⇒ **absente** de `extra` (AC7/AC8) |
| `remapColorKey` | clé connue rendue telle quelle | clé inconnue/vide/`null`, `seedTitle` vide/`null` ⇒ clé ∈ `keys`, **jamais** throw |
| `orphanTagIds` | orphelins détectés | listes vides / doublons / `''` ⇒ résultat cohérent, **jamais** throw |

**And** `ZFlashcardTag.fromMap(const {})` **et** `ZSuggestedTag.fromMap(const {})` **ne throw pas**.

### AC12 — R3 : **injection de régression** — les filets sont vus **ROUGIR**

**Given** *« un filet qu'on n'a pas vu échouer n'est pas un filet »* (rétro ES-1, §7)
**When** on injecte, **une par une** (restauration **à l'octet près** entre chaque, `diff` vide) :
1. retrait de `...ZSyncMeta.reservedKeys` de `ZFlashcardTag._reservedKeys` **(R-A)** ⇒ gate ROUGE
2. retrait de la voie `ctor` de `kExtraWriters['flashcard_tag']` **(règle AST (j))** ⇒ gate ROUGE
3. writer `ctor` **auto-sanitisant** (menteur poli) pour `flashcard_tag` **(règle AST (k) + (i.3))** ⇒ gate ROUGE
4. retrait de `hide ZFlashcardTagZcrud` du barrel kernel **(règle (h))** ⇒ gate ROUGE
5. remplacement du `hash` injecté de la palette par `String.hashCode` (ou une constante) dans un **vecteur golden** de `remapColorKey` **(déterminisme, D3)** ⇒ **test golden ROUGE**

**Then** le gate / le test passe **ROUGE (RC=1)** dans **LES CINQ** cas — la **sortie brute** de chacun est **collée** dans les Completion Notes
**And** chaque restauration rend le tout **VERT**
**And** l'orchestrateur **rejoue lui-même** la séquence (le rapport de l'agent ne vaut **pas** preuve — R9).

### AC13 — R9 : vérif verte **repo-wide**, codegen **committé**, acyclicité préservée

**Given** les gates de merge
**When** on clôt la story
**Then** `melos run generate` OK · `melos run analyze` **repo-wide** RC=0 · `melos run test` RC=0 (nb de tests ≥ avant, aucune régression) · `melos run verify` RC=0 (dont `gate:graph`, `gate:codegen`, **`gate:codegen-distribution`**, **`gate:reserved-keys`**, `prove_gates`)
**And** les `*.g.dart` de `packages/zcrud_study_kernel/lib/` (dont `z_flashcard_tag.g.dart`, `z_suggested_tag.g.dart`) sont **suivis par git** et **présents dans l'arbre** — `gate:codegen-distribution` échouerait sinon
**And** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** (le kernel ne gagne **aucune** arête sortante ; **pas de `crypto`**).

### AC14 — gate:web : tests kernel sous `dart test`, **aucun `dart:io`**

**Given** que le kernel est pur-Dart (ses tests tournent sous `dart test`, y compris JS le cas échéant)
**When** on écrit les tests
**Then** **aucun** test de `packages/zcrud_study_kernel/test/` n'importe `dart:io` (sinon `@TestOn('vm')` **explicite** avec raison écrite) — les vecteurs golden de `remapColorKey` restent **compilables en JS** (patron `z_color_palette_test.dart`).

### AC15 — Périmètre : **aucune** écriture hors du kernel + câblage minimal (parallélisation)

**Given** que la story écrit le kernel (séquentielle)
**When** on inspecte le diff
**Then** les **seuls** fichiers modifiés/créés sont : `packages/zcrud_study_kernel/` (domaine + barrel + `.g.dart` + tests), `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (liste `hide`/allowlist), `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (allowlist), `tool/reserved_keys_gate/lib/src/registrars.dart`
**And** **AUCUNE** ligne de `zcrud_core`, `zcrud_document`, `zcrud_note`, `zcrud_mindmap`, `zcrud_firestore` n'est modifiée
**And** **aucun** fichier de `/home/zakarius/DEV/lex_douane` ni `/home/zakarius/DEV/iffd` n'est touché (**lecture seule**)
**And** **aucun widget**, **aucune** `presentation/`, **aucun** repository/port n'est écrit (ES-8.1/ES-3).

---

## Tasks / Subtasks

- [x] **T1 — LIRE les patrons sur disque** (avant d'écrire une ligne) : `z_study_session_config.dart` (jumeau `ZExtensible` sans canal), `z_study_folder.dart` (`colorKey` brut + `@ZcrudId`), `z_choice.dart` (value object NON-`ZExtensible`), `z_color_palette.dart` (`resolveKey`), `registrars.dart` (contrat gate), lex `flashcard_tag.dart` / `suggested_tag.dart` / `study_tags_repository.dart`.
- [x] **T2 — `remapColorKey`** (AC3, AC11 — **D3**) — fonction top-level pure dans `packages/zcrud_study_kernel/lib/src/domain/remap_color_key.dart` : prend `ZColorPalette` + `rawColorKey?` + `seedTitle?`, **délègue** à `resolveKey` (⛔ **zéro** hash dupliqué, **zéro** `crypto`, **zéro** palette 8-clés en dur), totale, déterministe, jamais de throw, résultat ∈ `keys`.
- [x] **T3 — `orphanTagIds`** (AC5, AC11 — **D5**) — fonction top-level pure (fichier `tag_referential_integrity.dart` ou top-level de `z_flashcard_tag.dart`) : clés `String` neutres, aucune dép satellite, déterministe, dédoublonnée, jamais de throw.
- [x] **T4 — `ZSuggestedTag`** (AC2, AC11) — `@ZcrudModel(kind: 'suggested_tag')`, value object NON-`ZExtensible`, `{title, colorKey}`, `fromMap` **nue**, `==`/`hashCode` scalaires (patron `ZChoice`).
- [x] **T5 — `ZFlashcardTag`** (AC1, AC4, AC6, AC7, AC8, AC11) — `@ZcrudModel(kind: 'flashcard_tag')`, `extends ZEntity with ZExtensible` ; patron **ES-2.2b intégral** : ctor `const` (`:_extra=extra`), slot brut `_extra`, accesseur `extra => zNormalizeExtra(...)`, `fromMap` peuplant `extra: _extraFrom(map)`, `_reservedKeys` **avec `...ZSyncMeta.reservedKeys`**, `_sanitizeExtra` partagée (`fromMap`+`copyWith`), `toMap()` = `{...extra, ...ZFlashcardTagZcrud(this).toMap()}` (+ `extension` si non nul), `copyWith` **à sentinelle** couvrant TOUS les champs, `==`/`hashCode` via `zJsonEquals`/`zJsonHash` ; `colorKey` **brut, jamais clampé** (D4) ; ⛔ zéro `updatedAt`/`isDeleted`, zéro `assert` au ctor.
- [x] **T6 — Barrel + surface** (AC10 — **D7**) — `lib/zcrud_study_kernel.dart` : `export … hide ZFlashcardTagZcrud;` + `export … hide ZSuggestedTagZcrud;` + `remap_color_key.dart` + intégrité ; classer chaque nouveau symbole dans `zcrud_flashcard` (`_flashcardAllowlist`) ; faire passer `z_kernel_surface_guard_test.dart`.
- [x] **T7 — Codegen** (AC13) — `melos run generate` ; **committer** `packages/zcrud_study_kernel/lib/**/*.g.dart` (dont les deux nouveaux).
- [x] **T8 — Câblage du harnais (R8 — MÊME story)** (AC9 — **D6**) — `registrars.dart` : `kRegistrars` += `registerZFlashcardTag`/`registerZSuggestedTag` ; `kProbeBodies` (2 kinds) ; `kNonExtensibleKinds` += `'suggested_tag'` ; `kExtraWriters['flashcard_tag']` = [`ctor`, `copyWith`] VERBATIM ; ⛔ NE PAS toucher `kLegacyUpdatedAtMirrors`, `kNoValueEqualityProbes`, `manual_probes.dart`, `pubspec.yaml` du tool.
- [x] **T9 — Tests** (AC1..AC11, AC14) — `packages/zcrud_study_kernel/test/` (**`dart test`**, **zéro `dart:io`**) : round-trips (pleine/minimale/idempotence) des deux entités · groupe **« AD-19 — clés de sync hors-entité »** (copier `z_study_session_config`/`z_document_reading_state`) · `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (les DEUX) · `remapColorKey` (matrice AC3 + vecteurs golden + palette injectée + jamais hors-palette) · `orphanTagIds` (matrice AC5) · `colorKey` brut (AC4) · pollution ctor neutralisée (AC8) · « aucune entrée ne throw » · `fromMap(const {})`.
- [x] **T10 — Injections de régression (R3)** (AC12) — **5 injections** ⇒ ROUGE à chaque fois (coller la **sortie brute**) ⇒ restaurer (`diff` vide) ⇒ VERT.
- [x] **T11 — Vérif verte repo-wide** (AC13) — `generate` → `analyze` (repo-wide) → `test` → `verify` (dont `prove_gates`, `graph_proof`, `gate:reserved-keys`).
- [x] **T12 — Completion Notes** — justification des décisions D remises en cause (le cas échéant) · confirmation **zéro `crypto`** / **zéro couleur codée en dur** / **zéro palette 8-clés** · confirmation qu'aucun symbole de `zcrud_core`/satellites n'a été écrit · dettes éventuelles (ex. parité SHA-256 lex reportée à l'injection applicative — `ZKeyHash`).

---

## Dev Notes

### Fichiers à LIRE avant d'écrire une ligne (patrons à copier, pas à réinventer)

| Fichier | Pourquoi |
|---|---|
| `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart` | 🔴 **LE JUMEAU** de `ZFlashcardTag` : `ZExtensible` **sans canal hors-codegen** (tous champs codegen-able) — `fromMap`/`toMap`/`copyWith`/`_reservedKeys`/`_sanitizeExtra`/accesseur `extra`/`==` |
| `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` | `ZEntity`+`ZExtensible`+`@ZcrudId()` **et** `colorKey` `@ZcrudField` **brut** (précédent D4) |
| `packages/zcrud_flashcard/lib/src/domain/z_choice.dart` | 🔴 **LE JUMEAU** de `ZSuggestedTag` : value object `@ZcrudModel` **NON-`ZExtensible`**, `fromMap` **nue** |
| `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart` | `ZColorPalette.resolveKey` — **le remap existe déjà** ; `ZKeyHash`/`zFnv1a32` (JS-safe) ; `defaultStudy()` (clés neutres) — **D3** |
| `packages/zcrud_study_kernel/lib/src/domain/normalize_tag_title.dart` | `normalizeTagTitle`/`dedupeByNormalizedTitle` (ES-1.2) — réutilisables pour la comparaison de titres (utile aux tests, et à ES-8.1) |
| `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` | Barrel + politique `hide` des extensions générées (D7) |
| `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` + `test/z_kernel_surface_guard_test.dart` | Liste `hide` du réexport kernel + allowlist (D7) — **à mettre à jour EN CONSCIENCE** |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | Contrat d'extension du gate (kRegistrars/kProbeBodies/kNonExtensibleKinds/kExtraWriters — **par voie**) |
| `scripts/ci/gate_reserved_keys.dart` | Règles **(f)/(g)/(h)/(i)/(j)/(k)** — celles qui mordront sur les deux kinds et le barrel |
| `lex_douane/…/education/flashcard_tag.dart` · `suggested_tag.dart` · `repositories/study_tags_repository.dart` | Source canonique **LUE** (D1) — **lecture seule**, jamais modifiée |

### Imports (vérifiés sur disque — ne pas improviser)

- `import 'package:zcrud_annotations/zcrud_annotations.dart';` (annotations `const`)
- `import 'package:zcrud_core/domain.dart';` — surface **pur-Dart** (`ZEntity`, `ZExtensible`, `ZExtension`, `ZSyncMeta`, `ZcrudRegistry`, `ZFieldSpec`, `zNormalizeExtra`, `zSanitizeExtra`, `zJsonEquals`, `zJsonHash`)
- `import 'z_color_palette.dart';` (local kernel) pour `remapColorKey`
- ⛔ **Jamais** `package:zcrud_core/zcrud_core.dart` (tire Flutter ⇒ casse `dart test`) · ⛔ **jamais** `package:crypto/…` (D3) · ⛔ **jamais** un symbole de `zcrud_flashcard` (AD-1/AD-17)

### AD & règles applicables (les 16 AD s'appliquent ; celles-ci mordent ICI)

- **AD-3** (codegen) : `@ZcrudModel`/`@ZcrudField`/`@ZcrudId`, `fieldRename: snake`, enums camelCase, `@JsonKey(unknownEnumValue:)`. Ici **aucun enum, aucun `Map`, aucun sous-modèle** ⇒ tous les champs sont codegen-able (`String`/`String?`) — **pas de canal hors-codegen** (contraste `ZSmartNote`/`ZFlashcard`).
- **AD-4** (extensibilité) : `ZFlashcardTag` porte `extra` (slot brut + accesseur normalisant, ES-2.2b) + `extension` versionné ; `remapColorKey` illustre l'**extension par injection** (`ZKeyHash`), jamais par héritage.
- **AD-10** (désérialisation défensive) : **aucun throw**, aucun `assert` au constructeur `const`, défauts sûrs partout.
- **AD-13 / FR-26 / NFR-S7** : **zéro couleur codée en dur** ; `colorKey` symbolique ; palette **injectée** ; résolution `Color` = seam de présentation (hors périmètre).
- **AD-16 / AD-19 (+ .1/.a/.b/.c)** : `updated_at`/`is_deleted` = STORE (`ZSyncMeta`), jamais inline ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `$FieldSpecs ∩ reservedKeys == {}` ; gate `reserved-keys` câblé (R8).
- **AD-17 / AD-1** : kernel ne dépend d'AUCUN satellite ; clés `String` neutres pour l'intégrité référentielle (L2).
- **R1** (règle ↔ gate), **R2** (fixture isolée par règle — déjà dans `prove_gates.dart`), **R3** (injection rejouée par l'orchestrateur), **R4** (spec `remapColorKey` validée par proto exécutable — les vecteurs golden), **R5** (AST, jamais regex — le gate parse déjà), **R6** (zéro dégradation silencieuse ; zéro hash dupliqué ; zéro palette répliquée), **R8** (câblage même story), **R9** (vérif repo-wide par l'orchestrateur).

### Pièges spécifiques à cette story

1. 🔴 **Le portage verbatim de lex EST le bug — DEUX FOIS** : `import 'package:crypto'` + `sha256` (**D3**, réintroduit une dépendance bannie) **et** `allowedColorKeys` **8 clés en dur** (**D3**, verrouille la palette que l'AC veut injectée).
2. 🔴 **Clamper `colorKey` dans l'entité est un piège naturel** (par mimétisme avec la garde `content` de `ZSmartNote`) : **INTERDIT** ici (**D4**) — la borne est palette-dépendante, la palette est injectée. Documenter le « pourquoi pas de clamp ».
3. 🔴 **`ZSuggestedTag` `ZExtensible` par excès de zèle** : c'est un DTO sans id ⇒ **NON-`ZExtensible`** (**D2**), sinon `kExtraWriters`/`hide` inutiles et `kNonExtensibleKinds` faux.
4. 🔴 **Câbler `flashcard_tag` avec la SEULE voie `copyWith`** ⇒ règle AST **(j)** ROUGE (la voie `ctor` publique existe sur disque) — **les DEUX voies** obligatoires (**D6**, HIGH-1/HIGH-2 d'ES-2.2b).
5. 🔴 **Dupliquer le hash/modulo** de `resolveKey` dans `remapColorKey` (R6) — **composer**, pas réimplémenter.
6. 🔴 **Oublier de classer un nouveau symbole** dans `zcrud_flashcard` (hide/allowlist) ⇒ `z_kernel_surface_guard_test` ROUGE (**D7**).
7. 🟡 Le `toMap()` **généré** n'étale **pas** `extra` — `ZFlashcardTag` **doit** définir son `toMap()` d'instance (étalant l'**accesseur** `...extra`).
8. 🟡 `colorKey` **n'a pas d'invariant entité** — ne pas écrire de test attendant un clamp ; écrire le test attendant la **conservation brute** (AC4).

### Ce que cette story ne fait PAS (frontières explicites)

- ⛔ **Aucun widget / `presentation/`** : éditeur de tags, chips, confirmation-IA, WCAG (couleur jamais seul canal) = **FR-S27 / ES-8.1**.
- ⛔ **Aucun repository / port** : `save`/`deleteTag`/`usageCount`, **purge** des refs orphelines, offline-first = **ES-8.1 / ES-3**.
- ⛔ **Aucun seam `colorKey → Color`** dans `zcrud_core` (`ZcrudScope.colorKeyResolver`) : il existe déjà (ES-1.2) et n'est pas touché.
- ⛔ **Aucune parité SHA-256** avec le serveur lex : reportée à l'injection applicative d'un `ZKeyHash` (dette documentée si pertinent, jamais dans le kernel).
- ⛔ **Aucune** écriture de `zcrud_core` ni d'un satellite hors kernel + câblage minimal (AC15).

### Stratégie de tests

- **Framework** : `package:test` (`dart test`) — kernel pur-Dart. **Zéro `dart:io`** (AC14) ; vecteurs golden `remapColorKey` compilables JS (patron `z_color_palette_test.dart`).
- **Round-trip** : pour chaque entité, `fromMap(toMap(x)) == x` (pleine + minimale + idempotence) ; `fromMap(const {})` sans throw.
- **AD-19** : groupe « clés de sync hors-entité » (sonde de store polluée) + `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (les deux entités).
- **`extra`** (ES-2.2b) : clé inconnue round-trippée ; pollution ctor neutralisée (`extra` vide) ; `f == fromMap(f.toMap())`.
- **`remapColorKey`** : matrice AC3 (connue/inconnue/vide/null × seed présent/vide/null), vecteurs **golden** déterministes, résultat **toujours ∈ keys**, palette **injectée** (deux palettes différentes → deux mappings), jamais de throw.
- **`orphanTagIds`** : matrice AC5 (vides, doublons, `''`, tout orphelin, aucun orphelin), déterministe.
- **Gate** : `dart run scripts/ci/gate_reserved_keys.dart` VERT ; **5 injections** (AC12) rejouées ROUGE→VERT, sortie brute collée, orchestrateur rejoue.
- **Repo-wide** : `generate` → `analyze` → `test` → `verify` (dont `prove_gates`, `graph_proof` ACYCLIQUE/CORE OUT=0).

---

## Definition of Done

- [x] `ZFlashcardTag` (`ZExtensible`, patron ES-2.2b intégral) + `ZSuggestedTag` (value object NON-`ZExtensible`) modélisés, `@ZcrudModel`, désérialisation défensive (AD-10), zéro `updatedAt`/`isDeleted`, zéro `assert` au ctor.
- [x] `remapColorKey` pur/déterministe/**palette injectée**/**zéro `crypto`**/**zéro couleur en dur**, résultat ∈ `keys`, vecteurs golden ; `orphanTagIds` pur/total.
- [x] `colorKey` **brut** (D4) — aucun clamp entité ; « pourquoi » documenté.
- [x] Barrel kernel `hide ZFlashcardTagZcrud`/`ZSuggestedTagZcrud` ; symboles classés dans `zcrud_flashcard` ; `z_kernel_surface_guard_test` VERT.
- [x] Gate `reserved-keys` câblé **dans cette story** (kRegistrars/kProbeBodies/kNonExtensibleKinds/kExtraWriters **par voie**) ; règles (f)/(g)/(h)/(i)/(j)/(k) VERTES.
- [x] **5 injections de régression** rejouées ROUGE→VERT (sortie brute collée), **rejouées par l'orchestrateur** (R3/R9).
- [x] `melos run generate` OK · `analyze` repo-wide RC=0 · `test` RC=0 (≥ avant) · `verify` RC=0 (dont `codegen-distribution`, `reserved-keys`, `prove_gates`) · `graph_proof` ACYCLIQUE/CORE OUT=0.
- [x] `.g.dart` du kernel (dont les 2 nouveaux) **committés** ; `pubspec.lock` (racine + example) **exclus** du commit d'epic.
- [x] Périmètre respecté (AC15) : aucune écriture de `zcrud_core`/satellites hors kernel + câblage minimal ; lex/iffd en lecture seule.
- [x] Completion Notes : décisions D confirmées/remises en cause, dettes éventuelles (parité SHA-256 via `ZKeyHash` applicatif).

---

## Dev Agent Record

### Context Reference
- Epic : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md` (FR-S6, l. 379-401)
- Canonique : `docs/canonical-schema.md` (§2.1 flashcard/`tagIds`, §138 `colorKey`)
- Rétro ES-1 : `_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md` (R1–R9, R-A/R-C/R-G)
- Code-review ES-2.2b : `stories/code-review-es-2-2b.md` (patron `extra` systémique, HIGH-1/HIGH-2, règles (i.1)/(i.3)/(j)/(k))

### Completion Notes

**Skill réel invoqué** : `bmad-dev-story` (via le tool `Skill`, succès — pas de fallback disque).

**Entités & primitives livrées (kernel)** :
- `ZFlashcardTag` (`@ZcrudModel(kind:'flashcard_tag')`, `extends ZEntity with ZExtensible`) — patron `extra` ES-2.2b **intégral** copié du jumeau `ZStudySessionConfig`/`ZStudyFolder` : ctor `const` (`:_extra=extra`, zéro filtre, zéro `assert`), slot brut `_extra` lu nulle part ailleurs, accesseur `extra => zNormalizeExtra(_extra,_reservedKeys)` (seul point traversé), `_sanitizeExtra` partagée `fromMap`+`copyWith`, `fromMap` peuplant `extra:_extraFrom(map)` (jamais de délégation nue), `toMap()` étalant `...extra` (accesseur), `copyWith` à sentinelle couvrant TOUS les champs, `==`/`hashCode` profonds `zJsonEquals`/`zJsonHash`, `_reservedKeys ⊇ ...ZSyncMeta.reservedKeys`. `colorKey` = `@ZcrudField String` **brut**, stocké VERBATIM, **aucun clamp entité** (D4, documenté en dartdoc).
- `ZSuggestedTag` (`@ZcrudModel(kind:'suggested_tag')`) — value object NON-`ZEntity`/NON-`ZExtensible`, `{title,colorKey}`, `fromMap` **déléguant nuement** (`_$ZSuggestedTagFromMap`), `==`/`hashCode` scalaires (patron `ZChoice`).
- `remapColorKey({palette, rawColorKey?, seedTitle?})` — pur/total/déterministe, **délègue à `palette.resolveKey`** (zéro hash dupliqué R6, zéro `crypto`, zéro palette 8-clés, zéro `Color`), résultat toujours ∈ `palette.keys`. Vecteurs golden FIGÉS (FNV-1a % 8 sur clés neutres) : `Droit Douanier→tertiary`, `tag inconnu→neutral`, `zzz→danger`, `x→neutral`.
- `orphanTagIds({referencedTagIds, existingTagIds})` — primitive PURE de **détection** (pas de purge — repository/ES-8.1), clés `String` neutres (aucune dép satellite).

**Câblage gate (R8/D6, MÊME story)** : `registrars.dart` — `kRegistrars += registerZFlashcardTag, registerZSuggestedTag` ; `kProbeBodies['flashcard_tag']={id,title,color_key}`, `['suggested_tag']={title,color_key}` ; `kNonExtensibleKinds += 'suggested_tag'` (PAS `flashcard_tag`) ; `kExtraWriters['flashcard_tag']=[ctor(eagerlyNormalized:false), copyWith(eagerlyNormalized:true)]` VERBATIM. `kLegacyUpdatedAtMirrors`/`manual_probes.dart`/`pubspec.yaml` du tool **non touchés**.

**🔴 Décision D remise en cause (R-G) — D7/AC10 sur `ZSuggestedTag`** : la story prescrit `export … hide ZSuggestedTagZcrud;`. **Écarté après confrontation au code réel** : la règle (h) de `gate:reserved-keys` (`scripts/ci/gate_reserved_keys.dart` l.1106/1116) ne cible **QUE les entités `ZExtensible`** (dont le `copyWith` généré détruirait `extra`/`extension` — finding H3). `ZSuggestedTag` est un value object sans `extra`/`extension` : son `copyWith`/`toMap` généré est **complet et sûr**. Le précédent EXACT `ZChoice` exporte son extension **sans `hide`** (barrel flashcard l.69, gate VERT). Hider `ZSuggestedTagZcrud` **amputerait** inutilement le `toMap`/`copyWith` publics du DTO. ⇒ `ZFlashcardTag` (ZExtensible) **est** `hide` (règle (h) l'exige — injection R3 n°4 le prouve) ; `ZSuggestedTag` (value object) ne l'est **pas**. Confirmé par le gate VERT avec `ZSuggestedTag` exporté sans hide, et par l'injection n°4 qui ne fait rougir (h) QUE sur `ZFlashcardTagZcrud`.

**AC12 — 5 injections R3 vues ROUGIR (RC=1), restaurées à l'octet près (diff vide), re-vertes** :
1. Retrait `...ZSyncMeta.reservedKeys` de `ZFlashcardTag._reservedKeys` → `[gate:reserved-keys] ÉCHEC : ajoutez ...ZSyncMeta.reservedKeys` + volet A `(a)` `Actual: Set:['updated_at','is_deleted']` + `(i.1a)`.
2. Retrait voie `ctor` de `kExtraWriters['flashcard_tag']` → `ÉCHEC : (j) VOIE D'ÉCRITURE NON SONDÉE : ZFlashcardTag.ctor … n'est PAS câblée`.
3. Writer `ctor` auto-sanitisant (menteur poli) → `ÉCHEC : (k) WRITER MENTEUR … x doit être transmis VERBATIM` + dynamique `(i.3) … WRITER MENTEUR « POLI » (MAJEUR-2)`.
4. Retrait `hide ZFlashcardTagZcrud` du barrel kernel → `ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : ZFlashcardTagZcrud … alors que ZFlashcardTag est ZExtensible`.
5. `hash: zFnv1a32` → `hash: (_) => 0` dans le vecteur golden → `remap_color_key_test` ROUGE : `Expected: 'tertiary' / Actual: 'primary'`.
Chaque restauration re-vérifiée VERTE ; `git diff` des fichiers cibles = seulement les ajouts intentionnels.

**Vérif verte rejouée sur disque** : `melos run generate` OK · `melos run analyze` repo-wide RC=0 (0 issue) · `melos run test` RC=0 — **kernel 160 tests** (+52 ES-2.3), flashcard 189, tous packages « All tests passed » · `melos run verify` RC=0 · `gate_reserved_keys.dart` VERT (100 tests, `flashcard_tag`/`suggested_tag` couverts, `couverture : 11 registrars … 17 voies (j)/(k)`) · `prove_gates.dart` **41 OK / 0 FAIL** · `graph_proof.py` **ACYCLIQUE OK / CORE OUT=0 OK** (kernel arêtes = {annotations, core, generator[dev]}, **aucun `crypto`**).

**Confirmations** : zéro `package:crypto` (pubspec kernel inchangé = `{zcrud_core, zcrud_annotations}`), zéro couleur/hex/`Color`, zéro palette 8-clés en dur, zéro `updatedAt`/`isDeleted` inline, zéro `assert` au ctor `const`, aucune ligne de `zcrud_core`/`zcrud_document`/`zcrud_note`/`zcrud_mindmap`/`zcrud_firestore` écrite, lex/iffd en lecture seule. `.g.dart` du kernel régénérés et présents dans l'arbre (non committés — l'orchestrateur committe en fin d'epic).

**Dettes ouvertes** : parité SHA-256 avec le serveur lex **reportée à l'injection applicative** d'un `ZKeyHash` custom dans la `ZColorPalette` de l'app (AD-4 : extension par injection) — jamais dans le kernel (dette documentée, non bloquante).

### File List

**Créés (kernel domaine)** :
- `packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart`
- `packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.g.dart` (généré)
- `packages/zcrud_study_kernel/lib/src/domain/z_suggested_tag.dart`
- `packages/zcrud_study_kernel/lib/src/domain/z_suggested_tag.g.dart` (généré)
- `packages/zcrud_study_kernel/lib/src/domain/remap_color_key.dart`
- `packages/zcrud_study_kernel/lib/src/domain/tag_referential_integrity.dart`

**Créés (tests kernel)** :
- `packages/zcrud_study_kernel/test/z_flashcard_tag_test.dart`
- `packages/zcrud_study_kernel/test/remap_color_key_test.dart`
- `packages/zcrud_study_kernel/test/tag_referential_integrity_test.dart`

**Modifiés** :
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (barrel : exports + `hide ZFlashcardTagZcrud`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (aucune modif nécessaire — nouveaux symboles en allowlist, non hidden ; **fichier finalement NON modifié**)
- `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (`_flashcardAllowlist` += 5 symboles)
- `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage gate : registrars, sondes, non-extensible, extra writers)

### Change Log

| Date | Version | Description |
|---|---|---|
| 2026-07-14 | ES-2.3 | Tags flashcard first-class (`ZFlashcardTag` ZExtensible + `ZSuggestedTag` value object) + `remapColorKey` (palette injectée, zéro crypto) + `orphanTagIds` (détection pure) + câblage gate reserved-keys. R-G : `ZSuggestedTag` non-`hide` (value object, règle (h) inapplicable). |
