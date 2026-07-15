<!-- Story enrichie BMAD — create-story. Skill réel : bmad-create-story (tool Skill, succès — PAS de fallback disque). -->

Status: done

# Story ES-2.4 : Ordre de contenu de dossier personnel (`ZFolderContentsOrder`)

- **Story id** : `es-2-4-ordre-contenu-dossier`
- **Epic** : ES-2 — Domaine canonique éducatif + codegen
- **FR couverte** : **FR-S7** — Ordre de contenu de dossier personnel (`ZFolderContentsOrder`).
- **Taille** : **S** · **Parallélisation** : **SÉQUENTIELLE** (écrit `zcrud_study_kernel`).
- **Package** : `zcrud_study_kernel` (utilise `applyOrder<T>` d'ES-1.2, déjà livré).
- **AD qui mordent** : AD-3 (codegen), AD-4 (extensibilité), AD-10 (défensif), AD-16/AD-19 (sync hors-entité), AD-1/AD-17 (acyclicité, clés neutres), AD-26 (état personnel jamais colocalisé), AD-13 (n/a ici — aucun visuel).

---

## Story

As a **développeur**,
I want **persister et appliquer un ordre personnel du contenu d'un dossier par section (`ZFolderContentsOrder` : `folderId` + un ordre `List<id>` par `sectionKey`)**,
So that **l'ordre choisi par l'utilisateur dans study-tools (ES-5.2) soit stable, reproductible et purement en état personnel — jamais partagé, jamais colocalisé avec le contenu partageable**.

---

## ⚠️ LE PATRON ES-2 (établi ES-2.0, durci ES-2.1, systématisé ES-2.2b, reproduit ES-2.3) — à respecter DÈS LA NAISSANCE

Cette entité **REPRODUIT À L'IDENTIQUE** le patron `ZExtensible` + canal hors-codegen des jumeaux déjà livrés. **Le jumeau structurel EXACT est `ZDocumentReadingState`** (état PERSONNEL, clé par un id étranger, PAS un `ZEntity`, `ZExtensible`, avec un canal `Map` hors-codegen — `learning`). Ne rien réinventer : copier ce fichier et l'adapter.

Patron `extra` ES-2.2b **INTÉGRAL** (non négociable, mesuré cassé sinon) :
1. constructeur nominal `const` qui **ne filtre RIEN** (`: _extra = extra;`) ;
2. slot brut `_extra` **lu NULLE PART ailleurs** que dans l'accesseur (jamais dans `toMap`/`==`/`hashCode`) ;
3. accesseur `Map<String,dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys)` — **LE SEUL point que TOUTES les voies traversent** ;
4. garde **partagée** `_sanitizeExtra` (= `zSanitizeExtra(raw, _reservedKeys)`) appelée par **`fromMap` ET `copyWith`** (jamais divergentes) ;
5. `toMap()` étale l'**ACCESSEUR** (`...extra`), jamais le champ brut `_extra` ;
6. `copyWith` **à sentinelle** (`_$undefined`) couvrant **TOUS** les champs, y compris `extension` et `extra` ;
7. égalité **profonde** `zJsonEquals`/`zJsonHash` sur `extra` ;
8. `fromMap` **NON-déléguante-nue** (peuple `extra: _extraFrom(map)`) — une délégation nue laisse `extra` vide → **build ROUGE** (`_rejectNakedCodegenDelegation` / garde runtime).

---

## ⚠️ Décisions de conception — CHAQUE prescription est CONFRONTÉE AU CODE RÉEL (R4 / R-G)

> **R-G (rétro ES-1)** : *la spec d'une story ES-2 peut elle-même porter le défaut.* Le dev **DOIT remettre chaque prescription en cause en la confrontant au code réel sur disque** (générateur, entités livrées, gate). Si une prescription ci-dessous contredit le code, **le code gagne** — le documenter dans les Completion Notes (précédent : D7 d'ES-2.3, dérogation `hide` justifiée sur le code réel du gate).

### D1 — Schéma = **lex** (module « Étude »), LU fichier par fichier
Source de vérité : l'ordre de contenu de dossier de lex_douane (chercher `folder_contents_order` / `ContentsOrder` / l'ordre manuel des sections de `StudyFolder`). **LECTURE SEULE** — aucun fichier hors du repo zcrud n'est modifié. Si la source lex loge l'ordre **dans** `StudyFolder` (colocalisé) ou porte `updatedAt`/`isDeleted` inline, ce sont des **pièges à REJETER** (AD-26 : état personnel extrait ; AD-19 : sync hors-entité) — documenter le rejet comme `ZDocumentReadingState` l'a fait pour `updatedAt`.

### D2 — `ZFolderContentsOrder` = **état PERSONNEL clé par `folderId`**, `with ZExtensible`, **PAS un `ZEntity`** (jumeau `ZDocumentReadingState`)
- Jointure **1↔1** avec le dossier (patron `ZDocumentReadingState` clé par `docId`, `ZRepetitionInfo` clé par `flashcardId`) : **aucun `id` propre**, aucune réconciliation d'identifiant. La clé d'identité est `folderId`.
- **`with ZExtensible`** (contenu personnel top-level persisté comme document autonome, `@ZcrudModel(kind: 'folder_contents_order')`) → **patron ES-2.2b intégral** (ci-dessus).
- **AD-26** : cet état d'ordre est **personnel** — il ne vit **jamais** dans le sous-arbre partageable du dossier (`ZStudyFolder`). Partager/dupliquer un dossier n'emporte JAMAIS l'ordre personnel d'autrui. La non-colocation est prouvée **par machine** (aucune clé d'ordre dans `$ZStudyFolderFieldSpecs` ; l'entité n'est jamais imbriquée dans `ZStudyFolder`). La résolution de collection (« où ») est **ES-3, hors périmètre**.

### D3 — 🔴 **LE CŒUR STRUCTURANT** : l'ordre par section est un **CANAL HORS-CODEGEN** (le générateur ne supporte AUCUN `Map`)
- Le champ payload est un **`Map<String, List<String>>`** (`sectionKey → ordre d'ids`). **Vérifié sur disque** (`zcrud_model_generator.dart` `_classify`) : le générateur accepte `String/int/double/num/bool/DateTime/enum/sous-modèle @ZcrudModel` et les `List<` de ces types — **aucune branche `isDartCoreMap`**. Un champ `Map` annoté `@ZcrudField` **fait ÉCHOUER LE BUILD**.
  - ⚠️ **Nuance mesurée** : le générateur **supporte** `List<String>` nativement (`ZStudySessionConfig.tagIds`/`types` — défauts défensifs : non-liste → `null`, éléments non-`String` filtrés). Mais la valeur ici est un **`Map` de listes** → **c'est le `Map` extérieur qui interdit le codegen**, pas les listes.
- ⇒ **`sectionOrders` est un canal HORS-CODEGEN** (patron EXACT `ZDocumentReadingState.learning` / `ZSmartNote.content` / `ZFlashcard.source`) : décodé/réémis **à la main**, sa clé `kSectionOrdersKey = 'section_orders'` **réservée** (`_reservedKeys`). Sans cette réserve, la clé atterrirait **aussi** dans `extra` et serait émise **DEUX FOIS** (une par `...extra`, une par le câblage manuel) → round-trip non idempotent + `==` cassée mémoire-vs-store.
- **Le SEUL `@ZcrudField` codegen-able** est `folderId` (`String`). C'est volontaire — une entité à un seul champ codegen + un canal hors-codegen est valide (`ZDocumentReadingState` en a plusieurs, mais rien n'impose un minimum).

### D3-bis — 🔴 Décodage défensif du canal à **DEUX niveaux** + immuabilité **PROFONDE** (M3, R-H)
Le canal a **deux niveaux de corruption possibles** (le `Map` extérieur ET chaque `List` intérieure) ; chacun a sa garde (R-H : *chaque invariant de valeur naît avec son test de garde ET son cas corrompu*, AD-10 jamais de throw) :
- `section_orders` **absente / non-`Map`** (`42`, une chaîne, une liste) ⇒ `{}` (aucun ordre), **jamais de throw** ;
- une **valeur de section non-`List`** (`{"flashcards": 7}`) ⇒ section **ignorée** ;
- un **élément non-`String`** dans une liste (`["a", 3, null]`) ⇒ élément **filtré** (même tolérance que `tag_ids`), ordre relatif préservé ;
- clés de section **verbatim** (opaques), listes d'ids **verbatim** (ids opaques `String`, `''` toléré comme clé opaque — précédent `orphanTagIds`).
- **Immuabilité M3** : la map exposée **ET ses listes internes** sont rendues **NON MODIFIABLES en profondeur** (comme `extra` est `unmodifiable`, comme `ZDocumentLearningInfo.qualityByPage`). Une mutation en place contournerait l'invariant, changerait le `hashCode` et **perdrait l'instance dans son propre `Set`**. La garde vit à **TOUTES** les frontières qui construisent la map : `fromMap`, `copyWith` (et le décodage).
- **PAS de dédoublonnage au stockage** : l'ordre est préservé **verbatim** (round-trip byte-stable) ; les doublons éventuels sont neutralisés **à l'application** par `applyOrder` (1re occurrence gagne). Ne pas « nettoyer » au décodage — ce serait une perte muette (R6).

> **Latitude dev (R-G)** : le canal peut être porté (a) **inline** — champ `Map<String, List<String>>` + helpers `static` privés `_decodeSectionOrders`/`_encodeSectionOrders` sur l'entité (recommandé, taille S, aucune surface publique de plus), **OU** (b) un **value-object pur** dédié type `ZDocumentLearningInfo` (`fromJsonSafe`/`toJson`/`_guard`) si le décodage à deux niveaux gagne en lisibilité. **Défaut prescrit : inline** (le VO `learning` existait pour son comportement riche `mark`/`qualityOf` — ici l'ordre n'a aucun comportement au-delà d'`applyOrder`). Trancher par lecture, documenter.

### D4 — 🔴 `applyOrder<T>` d'ES-1.2 EST le mécanisme d'intégrité — **AUCUNE nouvelle primitive**
- L'AC de l'epic ES-2.4 exige que **`applyOrder<T>` applique l'ordre de façon stable** (FR-S2). L'entité expose une **méthode pure** `applyTo<T>` qui **délègue** à `applyOrder` (jamais de tri réinventé — R6). Précédent d'usage documenté dans `apply_order.dart` : *« Usage prévu : `ZFolderContentsOrder` (FR-S7) »*.
- **DÉCISION TRANCHÉE (contraste avec ES-2.3 / AC5)** : **cette story ne livre AUCUNE primitive d'intégrité référentielle** (type `orphanTagIds`). Raison confrontée à l'AC de l'epic : l'AC ES-2.4 **ne mentionne aucune détection d'orphelins**, et `applyOrder` est **déjà TOTAL et défensif par construction** — un id d'ordre ne correspondant à aucun item est **simplement ignoré**, un item absent de l'ordre garde une **position déterministe**. La réconciliation/purge (retirer d'un ordre les ids de contenu supprimés) est du ressort **repository/UI (ES-5.2 / ES-8, hors périmètre)**. ⇒ La « cohérence ordre↔contenu » est portée **gratuitement** par `applyOrder`, prouvée par un test à pouvoir discriminant (AC ci-dessous), pas par une primitive nouvelle. Documenter ce choix (taille S préservée).

### D5 — 🔴 Égalité : **profonde**, ordre-SENSIBLE dans une liste, ordre-INSENSIBLE entre sections (piège subtil, différent de `ZDocumentLearningInfo`)
- **L'ORDRE EST LE PAYLOAD** : deux instances au même `folderId` et mêmes sections mais dont **une section a sa liste inversée** doivent être **INÉGALES**. ⇒ le `==` compare chaque liste de section **positionnellement** (`_listEquals`), et le `hashCode` d'une liste est **ordre-sensible** (`Object.hashAll(list)`).
- **Entre sections**, l'ordre des clés de la `Map` n'a **aucun sens** : deux instances aux mêmes sections insérées dans des ordres de clés différents sont **ÉGALES** ⇒ l'égalité des clés de section est **ensembliste** et le hash extérieur est **COMMUTATIF** (somme sur les sections), comme `ZDocumentLearningInfo` (mais **attention** : là le VALUE était un scalaire ; ici le value est une **liste ordonnée** → hash intérieur ordre-sensible, hash extérieur ordre-insensible).
- `extra` : égalité profonde `zJsonEquals`/`zJsonHash` (patron ES-2.2b).

### D6 — Câblage du gate `reserved-keys` (**R8**) — DANS LA MÊME STORY (non négociable)
Une entité ES-2 **ne peut pas naître sans être câblée au harnais** (`tool/reserved_keys_gate/lib/src/registrars.dart`) — sinon elle n'est **pas sondée** (R-A : l'oubli de `...ZSyncMeta.reservedKeys` s'est produit 2 fois sur 4 sous 1193 tests verts). À ajouter dans la MÊME story :
1. `registerZFolderContentsOrder` → **`kRegistrars`** (sinon `gate_reserved_keys.dart` rougit sur `R_disk \ R_wired ≠ ∅`).
2. Corps de sonde **`kProbeBodies['folder_contents_order']`** — **NON VIDE** et **portant le canal `section_orders` NON VIDE** (règle **g2** : une sonde sans le canal, ou avec un canal vide, rendrait le canal « préservé PAR PROSE » ; c'est le finding H1 d'ES-2.1 / H2 d'ES-2.0 à NE PAS rejouer).
3. **`kExtraWriters['folder_contents_order']`** = **TOUTES les voies publiques** d'écriture de `extra` (règle AST **(j)**, dérivée du DISQUE) : **`ctor`** (`eagerlyNormalized: false`, `const` : ne filtre rien) **ET** **`copyWith`** (`eagerlyNormalized: true`), chacune transmettant `extra` **VERBATIM** (règle **(k)** — un writer auto-sanitisant = MAJEUR-2). Ajouter `_ctorFolderContentsOrder` + `_copyWithFolderContentsOrder`.
4. **NE PAS** ajouter à `kNonExtensibleKinds` (l'entité EST `ZExtensible`), **NI** à `kExtensionPayloadPreservers` (aucune `ZExtension` concrète livrée ici).
5. ⛔ **NE PAS TOUCHER** `kLegacyUpdatedAtMirrors` (reste `{study_folder, flashcard}`) — toute entrée = décision d'archi.

### D7 — 🔴 Surface publique : barrel kernel (règle (h)) + réexport `zcrud_flashcard` (garde `z_kernel_surface_guard_test`)
- **Barrel kernel** (`packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart`) : `export 'src/domain/z_folder_contents_order.dart' hide ZFolderContentsOrderZcrud;` — **règle (h)** du gate : l'extension GÉNÉRÉE `ZFolderContentsOrderZcrud` d'une entité `ZExtensible` **DOIT être masquée** (son `copyWith`/`toMap` généré ignore `extra`/`extension`/le canal → DÉTRUIT en silence, finding H3 d'ES-2.1). Précédents : `ZStudyFolderZcrud`, `ZFlashcardTagZcrud`.
- **Réexport `zcrud_flashcard`** : le barrel flashcard réexporte le kernel via une liste **`hide`**. `ZFolderContentsOrder` est un concept **study PERSONNEL, NON pertinent flashcard** ⇒ **par défaut, AJOUTER ses symboles publics à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (précédent : les utilitaires ES-1.2 y sont `hide`) — **PAS** à l'allowlist (contraste avec `ZFlashcardTag`, allowlisté car pertinent migration DODLP).
- **La garde `z_kernel_surface_guard_test.dart` TIENT la règle** : elle croise **TOUT** symbole public réel du barrel kernel avec (`hide` flashcard ∪ allowlist) ; un symbole **non classé fait ÉCHOUER les tests**. Le dev **exécute cette garde** — elle **nomme** chaque symbole `ZFolderContentsOrder*` à classer (entité, typedef `ZFolderContentsOrderExtensionParser`, `registerZFolderContentsOrder`, `$ZFolderContentsOrderFieldSpecs`). Classer chacun (défaut : `hide`). **Confronter au code (R-G)** : si un consommateur flashcard en a besoin, allowlister à la place et le justifier.

### D8 — AD-19 dès la naissance : **zéro** clé de sync dans l'entité (R-C), prouvé PAR MACHINE
`_reservedKeys` = `{ $ZFolderContentsOrderFieldSpecs.name..., 'extension', kSectionOrdersKey, ...ZSyncMeta.reservedKeys }`. `...ZSyncMeta.reservedKeys` (`updated_at`, `is_deleted`) est **ESSENTIEL** : l'entité est persistée top-level, le store écrit sa méta **dans le corps** avant de passer la map complète à `fromMap`. Sans ce spread, `updated_at`/`is_deleted` (propriété du **store**, AD-16) atterriraient dans `extra` et seraient **réémises** par `toMap`. Et `$ZFolderContentsOrderFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (R-C : aucun champ métier sous une clé réservée).

---

## Schéma canonique retenu (clés persistées **snake_case**)

### `ZFolderContentsOrder` — `@ZcrudModel(kind: 'folder_contents_order')` · `with ZExtensible` · **PAS un `ZEntity`**

| Champ Dart | Clé persistée | Type | Codegen ? | Défaut / défensif |
|---|---|---|---|---|
| `folderId` | `folder_id` | `String` | ✅ `@ZcrudField()` | absent → `''` (identité 1↔1, jamais d'`id` propre) |
| `sectionOrders` | `section_orders` | `Map<String, List<String>>` | ❌ **HORS-CODEGEN** (clé réservée `kSectionOrdersKey`) | non-`Map` → `{}` ; section non-liste → ignorée ; élément non-`String` → filtré ; **profondément non modifiable** (M3) |
| `extension` | `extension` | `ZExtension?` | ❌ hors-codegen (slot AD-4 pt.1) | corrompue → `null` (`ZExtension.guard`) |
| `extra` | (clés non réservées) | `Map<String, dynamic>` | ❌ hors-codegen (slot AD-4 pt.2) | défaut `const {}`, jamais `null`, accesseur normalisant |

**Persistance** : `{"folder_id": "f1", "section_orders": {"flashcards": ["c3","c1"], "notes": ["n2"]}}`.

Généré (`z_folder_contents_order.g.dart`, **committé**) : `_$ZFolderContentsOrderFromMap`, extension `ZFolderContentsOrderZcrud`, `$ZFolderContentsOrderFieldSpecs`, `registerZFolderContentsOrder`, garde runtime `_$zRequireExtraPreserved`.

### Méthode pure (délègue à `applyOrder<T>` — jamais de tri réinventé)

```
List<T> applyTo<T>(
  String sectionKey,
  Iterable<T> items, {
  required String Function(T) idOf,
  ZUnorderedPlacement unordered = ZUnorderedPlacement.end,
}) => applyOrder(items, sectionOrders[sectionKey] ?? const <String>[], idOf: idOf, unordered: unordered);
```

(Optionnel : `List<String> orderFor(String sectionKey) => sectionOrders[sectionKey] ?? const <String>[];`.)

---

## Acceptance Criteria

### AC1 — `ZFolderContentsOrder` : `@ZcrudModel(kind:'folder_contents_order')` `ZExtensible`, patron ES-2.2b **INTÉGRAL**
**Given** l'entité modélisée avec `folderId` + `sectionOrders` (canal hors-codegen)
**When** on inspecte sa structure `extra`
**Then** ctor `const` ne filtrant RIEN (`: _extra = extra`), slot `_extra` **lu nulle part** ailleurs que dans l'accesseur, accesseur `get extra => zNormalizeExtra(_extra, _reservedKeys)` **seul point traversé**, garde partagée `_sanitizeExtra` (`fromMap` **et** `copyWith`), `toMap` étalant `...extra` (l'accesseur), `copyWith` à sentinelle couvrant tous les champs, égalité profonde `zJsonEquals`/`zJsonHash`.
**And** l'entité **n'est PAS un `ZEntity`** (aucun `id` propre) ; l'identité est `folderId` (jointure 1↔1, patron `ZDocumentReadingState`).

### AC2 — 🔴 D3 — `sectionOrders` est un **canal HORS-CODEGEN**, clé réservée, round-trip **idempotent**
**Given** que le générateur ne supporte aucun type `Map` (vérifié sur disque)
**When** on modélise `sectionOrders: Map<String, List<String>>`
**Then** il **n'est PAS** un `@ZcrudField` : décodé depuis `map['section_orders']` et réémis **à la main** par `toMap` ; sa clé `kSectionOrdersKey = 'section_orders'` est dans `_reservedKeys` (déclarée **une seule fois**, consommée par `fromMap` + `toMap` + `_reservedKeys` — aucun littéral dupliqué).
**And** `toMap()` émet `section_orders` **toujours** (même `{}`) → `fromMap(toMap(x)) == x` (idempotent), et la clé **n'apparaît jamais** dans `extra` (jamais émise en double).

### AC3 — 🔴 D3-bis / AD-10 / M3 — décodage défensif à DEUX niveaux + immuabilité PROFONDE, **jamais de throw**
**Given** une map de store corrompue
**When** on appelle `ZFolderContentsOrder.fromMap(map)`
**Then** aucun cas ne throw, **pas même `fromMap(const {})`** :
- `section_orders` absente / `42` / `"x"` / une liste ⇒ `sectionOrders == {}` ;
- section à valeur non-liste (`{"a": 7}`) ⇒ section ignorée ;
- éléments non-`String` (`["a", 3, null]`) ⇒ filtrés, ordre relatif des `String` préservé ;
**And** `sectionOrders` **et chaque liste interne** sont **NON MODIFIABLES** (une écriture en place throw `UnsupportedError`) — M3 ; la garde vit **aussi** dans `copyWith` (une mutation applicative ne rouvre pas l'invariant).

### AC4 — 🔴 D4 — `applyTo<T>` **délègue** à `applyOrder<T>`, ordre **stable**, intégrité **gratuite** (pouvoir discriminant OBSERVÉ)
**Given** un dossier avec un ordre personnel **partiel et permuté**
**When** on appelle `applyTo(sectionKey, items, idOf: …)`
**Then** le résultat est **exactement** l'ordre attendu (vecteur à pouvoir discriminant, cf. Stratégie de tests) — items ordonnés dans l'ordre de `order`, puis items absents de l'ordre en position déterministe (`unordered`), tri **stable** ;
**And** un id de l'ordre ne correspondant à **aucun** item est **ignoré** (intégrité gratuite, sans primitive nouvelle — D4), un item absent de l'ordre garde une position déterministe, un id **dupliqué** dans l'ordre → 1re occurrence fait foi ;
**And** `applyTo` **ne réimplémente aucun tri** (délègue à `applyOrder` — R6).

### AC5 — 🔴 D5 — Égalité profonde : ordre-SENSIBLE dans une liste, ordre-INSENSIBLE entre sections (OBSERVÉ)
**Given** deux instances au même `folderId`
**When** elles diffèrent **uniquement** par l'**ordre interne** d'une section (liste inversée)
**Then** elles sont **INÉGALES** et de `hashCode` **différents** (l'ordre EST le payload) ;
**And** deux instances aux **mêmes** sections **insérées dans un ordre de clés différent** (même contenu) sont **ÉGALES** et de **même** `hashCode` (commutatif sur les sections).

### AC6 — AD-19 dès la naissance : **zéro** clé de sync (R-C), prouvé PAR MACHINE
**Given** l'entité annotée persistée top-level
**When** on inspecte `_reservedKeys` et `$ZFolderContentsOrderFieldSpecs`
**Then** `_reservedKeys ⊇ ZSyncMeta.reservedKeys` (`...ZSyncMeta.reservedKeys` présent), inclut `'extension'` et `kSectionOrdersKey` ;
**And** `$ZFolderContentsOrderFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (aucun `updated_at`/`is_deleted` inline) ; `toMap()` ne produit **jamais** `updated_at`/`is_deleted`.

### AC7 — R-A : round-trip de STORE prouvé **COMPORTEMENTALEMENT** (anti-vacuité)
**Given** une map de store `{ 'folder_id':'f', 'section_orders':{…}, 'updated_at':…, 'is_deleted':…, 'zz_cle_inconnue':'gardee' }`
**When** `x = fromMap(map)` puis `x.toMap()`
**Then** `x.extra['zz_cle_inconnue'] == 'gardee'` **et** `x.toMap()['zz_cle_inconnue'] == 'gardee'` (clé métier inconnue **survit** — anti-vacuité) ;
**And** `x.extra.keys ∩ ZSyncMeta.reservedKeys == {}` **et** `toMap()` ne réémet ni `updated_at` ni `is_deleted` ni `section_orders` en double.

### AC8 — Pollution du ctor `const` **neutralisée** (la voie que le harnais ne sondait pas)
**Given** `ZFolderContentsOrder(folderId:'f', extra:{'is_deleted':true, 'section_orders':{}, 'ok':1})`
**When** on lit `.extra` et `.toMap()`
**Then** `extra` ne contient **ni** `is_deleted` **ni** `section_orders` (clés réservées filtrées par l'accesseur), `extra['ok'] == 1`, et `x == fromMap(x.toMap())` ;
**And** **aucun `assert`** dans le ctor `const` (AD-10).

### AC9 — R8 : câblage du harnais `reserved-keys` **DANS LA MÊME STORY** (D6)
**Given** l'entité livrée
**When** on inspecte `tool/reserved_keys_gate/lib/src/registrars.dart`
**Then** `registerZFolderContentsOrder ∈ kRegistrars` ; `kProbeBodies['folder_contents_order']` **non vide** avec `section_orders` **non vide** (g2) ; `kExtraWriters['folder_contents_order']` = **[`ctor`, `copyWith`]** (VERBATIM, (j)/(k)) ; l'entité **absente** de `kNonExtensibleKinds`/`kExtensionPayloadPreservers` ; `kLegacyUpdatedAtMirrors` **inchangé** ;
**And** `gate:reserved-keys` **VERT** (couverture « N registrars disque / N câblés »), `prove_gates` **0 FAIL**.

### AC10 — R3 : **injections de régression** — les filets sont vus **ROUGIR** (par l'orchestrateur)
**Given** les filets câblés
**When** on injecte, un par un, isolément :
1. retrait de la voie **`ctor`** de `kExtraWriters['folder_contents_order']` ⇒ gate **(j)** ROUGE (`VOIE D'ÉCRITURE NON SONDÉE : ZFolderContentsOrder.ctor`) ;
2. retrait de `hide ZFolderContentsOrderZcrud` du barrel kernel ⇒ gate **(h)** ROUGE (`EXTENSION GÉNÉRÉE EXPORTÉE`) ;
3. retrait de `kSectionOrdersKey` de `_reservedKeys` ⇒ round-trip **cassé** (canal en double dans `extra` + `toMap`) — test entité ROUGE ;
**Then** chaque injection **rougit avec le bon message**, restauration → **VERT** (diff vide). Séquence rejouée et documentée (R9).

### AC11 — D7 : surface publique CLASSÉE (barrel (h) + garde `z_kernel_surface_guard`)
**Given** l'entité exportée
**When** on exécute `z_kernel_surface_guard_test.dart`
**Then** **TOUT** symbole public `ZFolderContentsOrder*` du barrel kernel est **classé** (`hide` flashcard par défaut, ou allowlist justifiée) — la garde est **VERTE** ; `ZFolderContentsOrderZcrud` **absente** de la surface publique du kernel (règle (h)).

### AC12 — gate:web : tests kernel sous `dart test`, **aucun `dart:io`**
**Given** les tests de la story
**When** on les exécute
**Then** ils tournent sous `dart test` (pas `flutter test`), **zéro** `import 'dart:io'` (sinon `@TestOn('vm')` + raison explicite — non attendu ici).

### AC13 — R9 : vérif verte **repo-wide**, codegen **committé**, acyclicité préservée
**Given** la story terminée
**When** l'orchestrateur rejoue `melos run generate` → `melos run analyze` → `dart test`/`flutter test` **repo-wide**
**Then** RC=0 partout ; `z_folder_contents_order.g.dart` **committé** (gate `codegen-distribution`) ; `pubspec.yaml` kernel reste **`{zcrud_core, zcrud_annotations}`** (aucune arête satellite — AD-1/AD-17) ; graphe **acyclique**.

### AC14 — Périmètre : **aucune** écriture hors du kernel + câblage minimal (SÉQUENTIEL)
**Given** la parallélisation SÉQUENTIELLE (écrit le kernel)
**When** on inspecte `git diff --stat`
**Then** seuls sont touchés : `zcrud_study_kernel/` (entité + `.g.dart` + barrel + tests), `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage), `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (hide) + `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (classement si nécessaire). **Aucune** ligne de `zcrud_core`/`zcrud_document`/`zcrud_note`/`zcrud_firestore`/lex/iffd.

---

## Tasks / Subtasks

1. **LIRE avant d'écrire** (patrons à copier, pas à réinventer) — cf. Dev Notes « Fichiers à LIRE ». Confronter D1–D8 au code réel (R-G).
2. **Créer `z_folder_contents_order.dart`** : `@ZcrudModel(kind:'folder_contents_order')`, `with ZExtensible`, ctor `const` brut, `folderId` `@ZcrudField()`, canal hors-codegen `sectionOrders` (inline recommandé — D3-bis), `const kSectionOrdersKey = 'section_orders'`, typedef `ZFolderContentsOrderExtensionParser`, `fromMap` non-nue défensive (2 niveaux, M3 unmodifiable profond), `toMap` (`...extra` + généré + `section_orders` toujours + `extension`), `copyWith` sentinelle, `applyTo<T>` (délègue `applyOrder`), `_reservedKeys` (D8), `_sanitizeExtra`/`_extraFrom`, `==`/`hashCode` (D5). `part 'z_folder_contents_order.g.dart';`.
3. **`melos run generate`** → committer `z_folder_contents_order.g.dart`.
4. **Barrel kernel** : `export 'src/domain/z_folder_contents_order.dart' hide ZFolderContentsOrderZcrud;` (règle (h)).
5. **Câbler le gate (R8/D6)** dans `registrars.dart` : `kRegistrars`, `kProbeBodies['folder_contents_order']` (avec `section_orders` non vide), `kExtraWriters['folder_contents_order']` (`ctor` + `copyWith`), `_ctorFolderContentsOrder`, `_copyWithFolderContentsOrder`. NE PAS toucher `kLegacyUpdatedAtMirrors`.
6. **Surface (D7)** : exécuter `z_kernel_surface_guard_test.dart` ; ajouter les symboles `ZFolderContentsOrder*` à la liste `hide` de `zcrud_flashcard.dart` (défaut) jusqu'à ce que la garde soit verte.
7. **Tests** `z_folder_contents_order_test.dart` (cf. Stratégie de tests) — pouvoir discriminant OBSERVÉ, jamais un golden fortuit.
8. **Vérif verte** kernel (`analyze` + `dart test`) puis signaler à l'orchestrateur pour rejeu **repo-wide** + injections R3 (AC10).

---

## Dev Notes

### Fichiers à LIRE avant d'écrire une ligne (patrons à copier)
- 🥇 **`packages/zcrud_document/lib/src/domain/z_document_reading_state.dart`** — **le jumeau EXACT** : état personnel, clé par id étranger (`docId`), `ZExtensible`, canal `Map` hors-codegen (`learning`), `ZSyncMeta` hors-entité, `kLearningKey` réservée déclarée une seule fois. **Copier sa structure.**
- **`packages/zcrud_document/lib/src/domain/z_document_learning_info.dart`** — patron de décodage défensif d'un canal `Map` (fromJsonSafe/toJson/_guard, immuabilité M3, hash commutatif) — utile si l'on choisit le VO (D3, latitude (b)).
- **`packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart`** + **`z_study_session_config.dart`** — patron ES-2.2b `extra` intégral (jumeaux kernel).
- **`packages/zcrud_study_kernel/lib/src/domain/apply_order.dart`** — `applyOrder<T>` + `ZUnorderedPlacement` (à déléguer, cite déjà `ZFolderContentsOrder` comme usage prévu).
- **`tool/reserved_keys_gate/lib/src/registrars.dart`** — les 3 lignes de câblage par entité (`kRegistrars`/`kProbeBodies`/`kExtraWriters`) + `_ctorXxx`/`_copyWithXxx`.
- **`packages/zcrud_flashcard/lib/zcrud_flashcard.dart`** (liste `hide`) + **`packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart`** (garde de classement).
- **`scripts/ci/gate_reserved_keys.dart`** — règles (h)/(j)/(k) (AST, jamais regex — R5).
- **`_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md`** — R1–R9, R-A/R-C/R-G/R-H.

### Imports (vérifiés sur disque — ne pas improviser)
```
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';
import 'apply_order.dart';           // applyOrder + ZUnorderedPlacement (même package)
part 'z_folder_contents_order.g.dart';
```
Depuis `zcrud_core/domain.dart` : `ZExtensible`, `ZExtension`, `zNormalizeExtra`, `zSanitizeExtra`, `zJsonEquals`, `zJsonHash`, `ZSyncMeta`, `_$undefined` (sentinelle — vérifier le nom exact exporté, cf. `ZFlashcardTag`).

### AD & règles qui MORDENT ici
- **AD-3** codegen : `@ZcrudModel/@ZcrudField`, `fieldRename: snake` (via `kind` sans `fieldRename` explicite ? — vérifier : `ZDocumentReadingState` = `@ZcrudModel(kind:'document_reading_state')` **sans** `fieldRename`, mais `docId`→`doc_id` : le snake est le défaut du modèle. **Confronter au code** — aligner sur le jumeau). Le `Map` **interdit** au codegen ⇒ canal hors-codegen.
- **AD-4** : `extra` (brut + accesseur) + `extension` versionné.
- **AD-10** : zéro throw, zéro `assert` au ctor `const`, `fromMap(const {})` sûr, décodage 2 niveaux tolérant.
- **AD-16/AD-19** : sync hors-entité, `_reservedKeys ⊇ ZSyncMeta.reservedKeys`, `$FieldSpecs ∩ reservedKeys == {}`.
- **AD-26** : état personnel, jamais colocalisé avec `ZStudyFolder` (prouvé par absence de clé d'ordre dans `$ZStudyFolderFieldSpecs`).
- **AD-1/AD-17** : kernel sans arête satellite ; ids de contenu = `String` neutres (pas d'import `zcrud_flashcard`/`zcrud_document`).
- **R5** : gate en AST, jamais regex. **R6** : aucune dégradation silencieuse (coercer/filtrer, jamais perdre en silence sans que ce soit le contrat). **R8** : câblage même story. **R9** : vérif verte repo-wide par l'orchestrateur.

### Pièges spécifiques
- 🔴 **Le `Map` extérieur interdit le codegen, PAS les listes** — `List<String>` est codegen-able (session config), mais `Map<…, List<String>>` ne l'est pas. Le canal entier est hors-codegen.
- 🔴 **Hash extérieur commutatif MAIS hash intérieur ordre-sensible** (D5) — piège subtil différent de `ZDocumentLearningInfo` (value scalaire). Ne PAS « corriger » le hash de liste en somme : l'ordre EST le payload.
- 🔴 **Immuabilité PROFONDE** (M3) : `Map.unmodifiable` extérieur **ET** `List.unmodifiable` sur chaque liste interne — sinon `x.sectionOrders['s'].add(...)` contourne l'invariant.
- 🔴 **`section_orders` toujours émise** par `toMap` (même `{}`) — round-trip idempotent (patron `learning`).
- 🔴 **Ne PAS ajouter de primitive d'intégrité** (D4) — `applyOrder` la porte gratuitement. Un test l'observe.
- 🔴 **Ne PAS déléguer nuement** à `_$…FromMap` (entité `ZExtensible`) — peupler `extra: _extraFrom(map)`.

### Ce que cette story ne fait PAS (frontières)
- Aucune UI, aucun widget (l'application de l'ordre dans study-tools = **ES-5.2**).
- Aucun repository, aucune purge/réconciliation ordre↔contenu (= **ES-3 / ES-5.2 / ES-8**).
- Aucune résolution de collection / chemin de persistance (= **ES-3.2**).
- Aucune primitive d'intégrité référentielle nouvelle (D4).
- Aucune écriture dans `zcrud_core` ni aucun satellite (SÉQUENTIEL kernel).

### Stratégie de tests (pouvoir discriminant OBSERVÉ — jamais un golden fortuit — leçon ES-2.3)
> ⚠️ **Motif dominant** : un artefact déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. Un golden d'ordre peut **passer par coïncidence**. Prescrire des vecteurs qui **divergeraient garantie** sur un code fautif.

- **`applyTo` — vecteur discriminant** : items `[a,b,c,d]`, ordre `['c','a']` ⇒ attendu **`[c,a,b,d]`** (`unordered: end`). Un impl qui rend l'entrée inchangée → `[a,b,c,d]` **ROUGE** ; un impl qui trie lexicographiquement → `[a,b,c,d]` **ROUGE**. Tester aussi `unordered: start` ⇒ `[b,d,c,a]`.
- **Intégrité gratuite (D4)** : ordre `['z','c','a']` (`z` = id fantôme, aucun item) ⇒ `z` ignoré, attendu `[c,a,b,d]`. Item `d` absent de l'ordre → position déterministe. Ordre `['a','a','b']` (doublon) → 1re occurrence.
- **Égalité ordre-SENSIBLE dans une liste (D5, discriminant)** : `x` = section `s:['a','b']`, `y` = section `s:['b','a']` ⇒ `x != y` **ET** `x.hashCode != y.hashCode`. Un `==`/hash naïvement ensembliste sur la liste rendrait ce test **VERT à tort** — c'est LE test qui prouve que l'ordre est observé.
- **Égalité entre sections ordre-INSENSIBLE (D5)** : construire `{s1:[…], s2:[…]}` et `{s2:[…], s1:[…]}` (mêmes contenus, ordre de clés inversé) ⇒ **ÉGAUX** et même `hashCode`.
- **Round-trip idempotent (AC2)** : `x` avec 2 sections dont une à liste inversée-vs-naturelle ⇒ `fromMap(toMap(x)) == x` ; `toMap(x)['section_orders']` présent même si `{}` ; `section_orders` **jamais** dans `extra`.
- **AD-10 corrompu (AC3)** : `fromMap(const {})` ; `section_orders` = `42` / `"x"` / `[]` ⇒ `{}` ; `{"a": 7}` ⇒ section ignorée ; `{"a": ["x", 3, null]}` ⇒ `{"a":["x"]}` ; aucun throw. Immuabilité : `expect(() => x.sectionOrders['a'].add('z'), throwsUnsupportedError)` et `expect(() => x.sectionOrders['b']= [], throwsUnsupportedError)`.
- **AD-19 store (AC7)** + **ctor pollution (AC8)** : cf. ACs (patron `z_flashcard_tag_test.dart` l.163-212).
- **Field-specs (AC6)** : `$ZFolderContentsOrderFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `kSectionOrdersKey ∈ _reservedKeys`.
- **Gate (AC9/AC10)** : `gate:reserved-keys` VERT ; les 3 injections R3 (rejouées par l'orchestrateur) rougissent avec le bon message.
- Tests sous **`dart test`**, zéro `dart:io` (AC12).

---

## Definition of Done
- [ ] `ZFolderContentsOrder` livré : `@ZcrudModel` `ZExtensible`, `folderId` codegen + `sectionOrders` canal hors-codegen (D3), patron ES-2.2b intégral (AC1).
- [ ] Canal `section_orders` : clé réservée, décodage 2 niveaux défensif, immuabilité **profonde** M3, round-trip idempotent (AC2/AC3).
- [ ] `applyTo<T>` délègue à `applyOrder`, intégrité gratuite, ordre stable — pouvoir discriminant observé (AC4).
- [ ] Égalité D5 (ordre-sensible liste / ordre-insensible sections) prouvée par test discriminant (AC5).
- [ ] AD-19 : zéro clé de sync, prouvé par machine (AC6) ; store round-trip anti-vacuité (AC7) ; ctor pollution neutralisée, aucun `assert` const (AC8).
- [ ] Gate `reserved-keys` câblé DANS la story (R8/D6) : `kRegistrars`/`kProbeBodies` (g2)/`kExtraWriters` (ctor+copyWith VERBATIM) ; `kLegacyUpdatedAtMirrors` inchangé (AC9).
- [ ] 3 injections R3 rougissent avec le bon message, restauration verte (AC10).
- [ ] Barrel kernel `hide ZFolderContentsOrderZcrud` (règle (h)) ; surface-guard verte, symboles classés (AC11).
- [ ] Tests sous `dart test`, zéro `dart:io` (AC12).
- [ ] `melos run generate` → `.g.dart` **committé** ; `analyze` + tests **repo-wide** RC=0 ; pubspec kernel `{zcrud_core, zcrud_annotations}` ; acyclique (AC13).
- [ ] Périmètre respecté : kernel + gate + hide flashcard uniquement (AC14).
- [ ] `prove_gates` 0 FAIL ; MEDIUM du code-review corrigés ou justifiés par écrit.

---

## Dev Agent Record

### Context Reference
- Epic ES-2.4 : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md` (l.401-414, traçabilité FR-S7 l.111).
- Jumeau structurel : `packages/zcrud_document/lib/src/domain/z_document_reading_state.dart` (+ `z_document_learning_info.dart`).
- Patron ES-2.2b : `packages/zcrud_study_kernel/lib/src/domain/{z_flashcard_tag.dart, z_study_session_config.dart}`.
- `applyOrder` : `packages/zcrud_study_kernel/lib/src/domain/apply_order.dart`.
- Gate : `tool/reserved_keys_gate/lib/src/registrars.dart` ; `scripts/ci/gate_reserved_keys.dart`.
- Rétro ES-1 (R1–R9) : `_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md`.
- Code-reviews de référence : `code-review-es-2-1.md` (canal `learning`), `code-review-es-2-3.md` (patron kernel + faux-vert golden).

### Completion Notes

**Skill réel** : `bmad-dev-story` (tool `Skill`, succès — PAS de fallback disque).

**Contexte de reprise** : le working-tree contenait un état PARTIEL d'une exécution
antérieure interrompue (entité + `.g.dart` + test + barrel + câblage gate déjà
présents et corrects). **Un seul défaut résiduel** : `kExtraWriters['folder_contents_order']`
ne câblait QUE la voie `copyWith` — la voie `ctor` (`_ctorFolderContentsOrder`, déjà
définie) n'était PAS listée, laissant `_ctorFolderContentsOrder` en élément inutilisé
ET le gate `reserved-keys` ROUGE (test `AC9 — kExtraWriters ... CHAQUE kind câble la
voie ctor`). **Corrigé** : ajout de la voie `ctor` (`eagerlyNormalized: false`) →
`[ctor, copyWith]` VERBATIM conforme à D6/AC9.

**Confrontation des prescriptions D1–D8 au code réel (R-G)** :
- **D1 (source lex, port propre)** : conforme — l'entité documente (l.21-26) que lex
  loge DÉJÀ cet ordre HORS du sous-arbre partagé (`users/{uid}/study_content_orders/{folderId}`)
  et NE déclare NI `updatedAt` NI `isDeleted` inline. Contrairement au piège
  `ZDocumentReadingState` (lex y logeait `updatedAt`), le port ES-2.4 est propre :
  aucun piège AD-26/AD-19 à rejeter, seulement l'adaptation au patron zcrud.
- **D3 (canal hors-codegen)** : confirmé sur disque — le `.g.dart` généré ne traite
  `folderId` que (`_$ZFolderContentsOrderFromMap` ne décode QUE `folder_id`), aucune
  branche `Map`. `section_orders` est bien décodé/réémis à la main.
- **D7 (surface flashcard)** : conforme au DÉFAUT prescrit (`hide`, contrairement à
  `ZFlashcardTag` allowlisté) — `ZFolderContentsOrder`, `ZFolderContentsOrderExtensionParser`,
  `kSectionOrdersKey` ajoutés à la liste `hide` de `zcrud_flashcard.dart`. Aucun
  consommateur flashcard n'en a besoin (état study personnel). Garde de surface VERTE.
- **D6 (kExtraWriters ctor+copyWith)** : voir défaut résiduel ci-dessus (corrigé).
- Aucune prescription contredite par le code : les D1–D8 tiennent toutes.

**Toolchain — `dart test` sur le gate tool** : `dart test tool/reserved_keys_gate`
CRASHE (FFI transformer : `type 'InvalidType' is not a subtype of FunctionType` —
trace `caretMetrics`/`Offset` de Flutter). Cause : le tool importe transitivement les
widgets Flutter de `zcrud_flashcard`, incompilables par la VM Dart pure. Le runner
CANONIQUE est `flutter test --tags reserved-keys` (invoqué par
`scripts/ci/gate_reserved_keys.dart` l.1429-1431) : **VERT, 106 tests**. Ce n'est PAS
une régression ES-2.4 (caractéristique d'environnement préexistante, indépendante).

**Injections de régression R3 (AC10) — EXÉCUTÉES RÉELLEMENT, une par une, restaurées
par édition ciblée (JAMAIS `git checkout`, working-tree non committé)** :

1. **Retrait voie `ctor` de `kExtraWriters` → (j)/AC9 ROUGE** (RC=1) :
   ```
   00:00 +104 -1: Some tests failed.
     .../reserved_keys_test.dart: AC9 — `kExtraWriters` : couverture BIDIRECTIONNELLE
     (la MACHINE) CHAQUE kind câble la voie `ctor` (la voie NON filtrante)
   ```
2. **Retrait `hide ZFolderContentsOrderZcrud` du barrel kernel → (h) ROUGE** (RC=1) :
   ```
   [gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : `ZFolderContentsOrderZcrud`
   est exposée par le point d'entrée public .../zcrud_study_kernel.dart
   (`export 'src/domain/z_folder_contents_order.dart';` sans `hide`), alors que
   `ZFolderContentsOrder` est `ZExtensible`.
   [gate:reserved-keys] 1 violation(s) — AD-19.1.
   ```
3. **Retrait `kSectionOrdersKey` de `_reservedKeys` → round-trip cassé, test entité ROUGE**
   (RC=1) — clé du canal fuit dans `extra` (double émission) :
   ```
   00:00 +4 -3: ... section_orders décodée depuis la map, jamais dans extra [E]
     Expected: false
       Actual: <true>
   00:00 +2 -1: ... round-trip PLEIN : fromMap(toMap(x)) == x [E]
   00:00 +4 -2: ... section_orders TOUJOURS émise, même {} (idempotence) [E]
   ```
   Chaque injection restaurée → VERT (sentinels re-vérifiés sur disque).

**Preuve de POUVOIR DISCRIMINANT de l'égalité ordre-sensible D5 (AC5, leçon ES-2.3)** :
`_listEquals` rendu ensembliste (tri-puis-compare) + hash interne de liste rendu
COMMUTATIF (somme) → le test `ordre-SENSIBLE dans une liste : [a,b] != [b,a]` ROUGIT :
```
00:00 +0 -1: ... ordre-SENSIBLE dans une liste : [a,b] != [b,a] (INÉGALES + hash≠) [E]
  Expected: not <Instance of 'ZFolderContentsOrder'>
    Actual: <Instance of 'ZFolderContentsOrder'>
```
tandis que `ordre-INSENSIBLE entre sections`, `folderId discriminant` et `extra profond`
restent VERTS — le test isole EXACTEMENT l'ordre-sensibilité intra-liste (pas un golden
fortuit). Restauré → VERT.

**Vérif verte finale (rejouée réellement sur disque)** :
- `melos run generate` : SUCCESS ; `.g.dart` kernel régénéré, identique (laissé dans
  l'arbre, NON committé — commit en fin d'epic par l'orchestrateur).
- `melos run analyze` REPO-WIDE : RC=0, SUCCESS (17 packages « No issues » ; 2 `info`
  préexistants dans `zcrud_document/test/z_document_viewer_prefs_test.dart`, hors story).
- `dart analyze packages/zcrud_study_kernel` : No issues found.
- Kernel `dart test` : **+196 All tests passed** (dont 60+ propres à `z_folder_contents_order_test.dart`).
- Flashcard `flutter test` : **+189 All tests passed** ; surface-guard `+5 passed`.
- `flutter test --tags reserved-keys` (gate tool) : **+106 All tests passed**.
- `gate_reserved_keys.dart` : **VERT** (volet A + B + couverture AD-19.1.c).
- `prove_gates.dart` : **41 OK, 0 FAIL** (aucune entrée prove_gates ajoutée — 41 attendu).
- `graph_proof.py` : **ACYCLIQUE OK, CORE OUT=0 OK** ; kernel deps = {zcrud_core,
  zcrud_annotations, zcrud_generator(dev)} — aucune arête satellite (AD-1/AD-17).

**Dettes ouvertes** : aucune propre à ES-2.4. Dettes préexistantes héritées (hors
périmètre) : `DW-ES14-2` (le registre ne type jamais `extension`), `DW-ES22-5` (ZMindmap
sans `==` de valeur), 2 `info` analyze dans `zcrud_document` (ES-2.1). La résolution de
collection / purge ordre↔contenu reste ES-3.2 / ES-5.2 / ES-8 (frontières respectées).

### File List
- `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart` (NEW)
- `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.g.dart` (NEW, généré — à committer en fin d'epic)
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (barrel : `export ... hide ZFolderContentsOrderZcrud`)
- `packages/zcrud_study_kernel/test/z_folder_contents_order_test.dart` (NEW)
- `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage R8/D6 : `kRegistrars`, `kProbeBodies`, `kExtraWriters` [ctor+copyWith], `_ctorFolderContentsOrder`, `_copyWithFolderContentsOrder`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (liste `hide` : `ZFolderContentsOrder`, `ZFolderContentsOrderExtensionParser`, `kSectionOrdersKey`)

### Change Log
- 2026-07-15 — ES-2.4 : `ZFolderContentsOrder` livré (`ZExtensible`, état personnel clé par `folderId`, canal hors-codegen `section_orders` : décodage 2 niveaux défensif + immuabilité profonde M3, égalité D5 ordre-sensible-liste / ordre-insensible-sections, `applyTo` déléguant à `applyOrder`). Correction du défaut résiduel de la reprise : voie `ctor` ajoutée à `kExtraWriters['folder_contents_order']` (D6/AC9). 3 injections R3 + preuve discriminante D5 rejouées vertes-après-restauration. Vérif verte repo-wide.
