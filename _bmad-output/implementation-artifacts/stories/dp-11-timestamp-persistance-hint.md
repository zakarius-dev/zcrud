# Story DP.11: Hint de persistance `timestamp` (parité DODLP, gap B14)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur migrant un modèle DODLP vers zcrud,
I want déclarer par champ, via `@ZcrudField(persistAs: ZPersistAs.timestamp)`, qu'un champ date doit être persisté sur Firestore comme `Timestamp` natif (et non String ISO-8601),
so that la migration DODLP → zcrud ne change **pas silencieusement** le format sur disque des champs historiquement stockés en `Timestamp` (requêtes `orderBy`/plage temporelle, index, interop avec l'existant), **sans** faire fuiter le type `cloud_firestore.Timestamp` hors de `zcrud_firestore` (AD-5).

## Contexte & source de vérité

- **Gap B14** (`docs/dodlp-edition-parity-gap.md:35`, `:66`, `:145`, `:194`) : DODLP persiste certains champs via `Timestamp.fromDate` Firestore **natif** ; zcrud absorbe aujourd'hui **tout** en String ISO-8601. Absence de hint de sérialisation par champ ⇒ « migration change silencieusement le format sur disque ».
- **Comportement DODLP exact** (lecture réelle `dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart`) :
  - **Écriture** (`:3694`, cf. `onChanged`) : `value == null ? null : field.type == EditionFieldTypes.timestamp ? Timestamp.fromDate(value) : value`. Le type `timestamp` force l'écriture d'un `Timestamp` natif dans le corps de l'entité ; les autres types date restent des `DateTime` (convertis implicitement par le SDK).
  - **Lecture défensive** (`:3405`, `:851`) : `fieldValue is Timestamp ? fieldValue : Timestamp.fromDate(fieldValue as DateTime)` et `if (_value.runtimeType == Timestamp) value = (_value as Timestamp).toDate();`. DODLP lit **indifféremment** `Timestamp` **ou** `DateTime` (tolérant aux deux formats sur disque).
- **DP-11 (epics)** : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md:173` — « `@ZcrudField(persistAs: timestamp)` consommé par `zcrud_firestore` (AD-5 préservé). [B14, zcrud_annotations/generator + zcrud_firestore] ».

## Périmètre (STRICT)

**3 packages, disjoints du domaine :**
1. `packages/zcrud_annotations` — nouvel attribut PUR-DART `persistAs` sur `@ZcrudField` + enum neutre `ZPersistAs`.
2. `packages/zcrud_generator` — le générateur lit statiquement le hint et **émet un artefact neutre** (`Set<String>` des clés persistées hintées) par modèle.
3. `packages/zcrud_firestore` — l'adaptateur **consomme** cet ensemble de clés (plain `Set<String>`) pour encoder/décoder ces champs en `Timestamp` natif, le type `Timestamp` restant **confiné** ici.

**INTERDIT :** toute modification de `zcrud_core` (domaine). Voir §« Besoin `zcrud_core` détecté » ci-dessous : le chemin d'implémentation retenu **évite** `zcrud_core` par conception.

## Acceptance Criteria

1. **Attribut de hint pur-Dart (zcrud_annotations).** `@ZcrudField` expose un nouveau paramètre nommé optionnel `persistAs` de type `ZPersistAs` (enum neuf dans `zcrud_annotations`, valeurs `iso8601` et `timestamp`), défaut `ZPersistAs.iso8601`. `ZcrudField` reste `const` pur-données (tous champs `final`, zéro closure, zéro import backend) ; `ZPersistAs` ne référence **aucun** type `cloud_firestore` (test : `zcrud_annotations` n'a **aucune** dépendance sur `cloud_firestore`, cf. son `pubspec.yaml`).
2. **Le générateur lit le hint statiquement.** Le générateur lit `persistAs` via `ConstantReader` (jamais d'exécution/`reflectable`) et détermine, par champ, si le hint vaut `timestamp`. Un `persistAs` absent ⇒ traité comme `iso8601` (aucun champ collecté).
3. **Émission d'un artefact neutre par modèle.** Pour chaque `@ZcrudModel`, le générateur émet un `const Set<String> $XxxTimestampFields = <String>{...}` contenant **les clés persistées** (snake_case / override `name`, mêmes clés que `toMap`) des champs `persistAs: timestamp`. Aucun champ hinté ⇒ `const <String>{}` (ensemble vide émis). L'artefact ne référence **aucun** type `zcrud_core` ni `cloud_firestore` (métadonnée neutre pur-Dart : un `Set<String>` de clés).
4. **`zcrud_firestore` consomme le hint — encodage écriture.** `FirebaseZRepositoryImpl<T>` (et son factory `fromRegistry`) accepte un paramètre optionnel `timestampFields` de type `Set<String>` (défaut `const <String>{}`). Dans le chemin d'écriture (`_encode`), pour chaque clé présente dans `timestampFields` dont la valeur de la map est une **String ISO-8601 non nulle** parsable, la valeur est **remplacée par `Timestamp.fromDate(DateTime.parse(...).toUtc())`** (type `Timestamp` local). Valeur `null` ⇒ reste `null` ; valeur non parsable / non-String ⇒ **laissée inchangée** (défensif, jamais de throw — AD-10).
5. **`zcrud_firestore` consomme le hint — décodage lecture (défensif AD-10).** Dans le chemin de lecture (avant remise à `fromMap`/`_decode`, ex. dans `_inject` ou une étape dédiée), pour chaque clé de `timestampFields` dont la valeur lue est un `Timestamp`, celle-ci est **reconvertie en String ISO-8601** (`(value as Timestamp).toDate().toUtc().toIso8601String()`) afin que le `fromMap` généré (`_$asDateTime`, qui ne connaît que `DateTime`/`String`) restitue correctement le champ. Une valeur déjà String (ancien document ISO) est **laissée telle quelle** (tolérance bi-format : Timestamp **ou** String, comme DODLP).
6. **Confinement AD-5 exécutoire.** Le type `cloud_firestore.Timestamp` n'apparaît que dans `packages/zcrud_firestore/lib/src/data/**` ; il n'entre dans **aucune** signature publique (les paramètres publics ajoutés sont des `Set<String>` nus) et **ne fuit ni** dans `zcrud_core` **ni** dans `zcrud_annotations` **ni** dans le code généré. Grep de garde : `Timestamp` absent de `zcrud_annotations/`, `zcrud_generator/lib/`, et du code émis par le générateur.
7. **Rétro-compatibilité (défaut = comportement actuel).** Sans `persistAs` (ou `persistAs: iso8601`) : `$XxxTimestampFields` est vide et l'adaptateur, sans `timestampFields` fourni, produit **exactement** le même corps qu'aujourd'hui (String ISO-8601 pour les dates). Aucune régression sur les modèles existants ; les tests de sérialisation existants restent verts.
8. **Sync-meta inchangée.** Les métadonnées hors-entité `ZSyncMeta` (`updated_at`, `is_deleted`) restent en String ISO-8601 / bool et **ne sont jamais** converties en `Timestamp` (le merge LWW compare `updated_at` en ISO — AD-9). Le hint s'applique **uniquement** aux clés d'entité déclarées.
9. **Store local Hive inchangé.** `HiveZLocalStore` (source de vérité offline-first) continue de stocker des String ISO-8601 ; la conversion `Timestamp` est **exclusive** au chemin Firestore distant. Aucune conversion `Timestamp` dans `hive_z_local_store.dart` (AD-9 : local ISO, distant Timestamp).

## Tasks / Subtasks

- [x] **Task 1 — Annotation `persistAs` (zcrud_annotations)** (AC: 1)
  - [x] Créer l'enum `ZPersistAs { iso8601, timestamp }` (fichier `packages/zcrud_annotations/lib/src/domain/annotations/z_persist_as.dart`) avec dartdoc (neutre, aucun import backend) et l'exporter depuis `lib/zcrud_annotations.dart`.
  - [x] Ajouter `final ZPersistAs persistAs;` (défaut `ZPersistAs.iso8601`) au constructeur `const` de `ZcrudField` + dartdoc + ligne dans la table de correspondance `@ZcrudField → ZFieldSpec` du dartdoc de classe.
- [x] **Task 2 — Propagation générateur** (AC: 2, 3, 7)
  - [x] Dans `_resolveField`/`_Field` (`zcrud_model_generator.dart`), lire `reader.read('persistAs')` → booléen `persistAsTimestamp` (revive accessor == `timestamp`), défaut `false` si absent/`iso8601`.
  - [x] Ajouter une émission `_emitTimestampFields(className, fields)` produisant `const Set<String> $XxxTimestampFields = <String>{ 'key', ... };` (clés = `f.key`, mêmes que `toMap`/`_emitSpec`) ; ensemble vide ⇒ `const <String>{}`.
  - [x] Brancher l'émission dans `generateForModel` (après `_emitRegister`).
- [x] **Task 3 — Consommation Firestore (écriture + lecture)** (AC: 4, 5, 6, 8, 9)
  - [x] Ajouter `final Set<String> _timestampFields;` + param nommé `Set<String> timestampFields = const <String>{}` au constructeur de `FirebaseZRepositoryImpl` **et** au factory `fromRegistry` (le propager).
  - [x] `_encode` : après fusion `ZSyncMeta`, boucler `_timestampFields` et remplacer les String ISO parsables par `Timestamp.fromDate(...)` (défensif). Ne pas toucher `_kUpdatedAt`/`_kIsDeleted`.
  - [x] Chemin lecture : conversion `Timestamp → ISO String` sur les clés `_timestampFields` intégrée dans `_inject` (funnel unique appelé par `_decode` **et** le `withConverter.fromFirestore`). String déjà présente ⇒ inchangée.
  - [x] Vérifié `FirestoreZRemoteStore` : délègue à `FirebaseZRepositoryImpl` ⇒ `timestampFields` propagé via l'injection du repository (aucune logique dupliquée, aucun changement de fichier). `HiveZLocalStore` inchangé.
- [x] **Task 4 — Tests** (AC: 1–9)
  - [x] `zcrud_annotations` : défaut `iso8601`, port de `timestamp`, garde « aucune dépendance backend » (no_runtime_dep_test existant reste vert).
  - [x] `zcrud_generator` : `$ArticleTimestampFields == {'created_at'}` (clé snake_case) ; `$AuthorTimestampFields` vide (AC3/AC7) ; `toMap` reste ISO malgré le hint.
  - [x] `zcrud_firestore` (`fake_cloud_firestore`) : (a) `save` écrit un `Timestamp` natif + `getById` round-trip ; (b) sans hint reste String ISO (AC7) ; (c) doc pré-existant String ISO décodé sans perte (AC5 bi-format) ; (d) `null` reste `null` ; (e) `updated_at` reste String ISO (AC8) ; + watch.
  - [x] Garde AD-5 : test programmatique + grep confirmant l'absence du **type** `Timestamp` hors `zcrud_firestore/lib/src/data`.

## Dev Notes

### État actuel des fichiers à modifier (UPDATE)

- **`packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart`** — classe `const ZcrudField` pur-données ; importe `package:zcrud_core/edition.dart` (pour `EditionFieldType`, `ZFieldConfig`…). Ajout d'un champ `final ZPersistAs persistAs` (défaut). **À préserver** : caractère `const`, absence de closure, table de correspondance du dartdoc (y ajouter une ligne `persistAs`). Note : l'enum `ZPersistAs` vit dans `zcrud_annotations` (pas `zcrud_core`) pour respecter la contrainte de non-modification du domaine.
- **`packages/zcrud_generator/lib/src/zcrud_model_generator.dart`** — `generateForModel` émet `_emitFromMap` + `_emitExtension` + `_emitFieldSpecs` + `_emitRegister`. `_toMapExpr` sérialise les `DateTime` en `toIso8601String()` (`_Cat.dateTimeType`, ligne ~347) ; `_fromMapExpr` lit via `_$asDateTime` (String/DateTime tolérant, ligne ~247). `_emitSpec` liste les clés `f.key`. **À préserver** : la clé persistée `f.key` (snake_case/`name`) est la **même** que celle du `Set` à émettre ; ne pas router le hint par `ZFieldSpec`/registre (éviterait `zcrud_core`). **Ajouter** `_emitTimestampFields`. Le `_Field` doit porter `persistAsTimestamp`.
- **`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart`** — `_encode` (ligne ~200) fusionne `ZSyncMeta` (ISO-8601, jamais `Timestamp`, dartdoc AC). `_inject` (ligne ~195) injecte l'`id`. `_decode` (ligne ~212) est défensif (AD-10). `withConverter.fromFirestore` (ligne ~187) appelle `_fromMap(_inject(...))`. **À préserver** : lecture défensive, exclusion `is_deleted`, invariant `id` de corps, sémantique fire-and-forget. **Ajouter** : `_timestampFields` + conversions bidirectionnelles bornées à ces clés. Point d'attention : le générateur produit `_$asDateTime` qui ne reconnaît **pas** `Timestamp` ⇒ la conversion **lecture** `Timestamp→ISO` est **obligatoire** (sinon repli par défaut silencieux = bug de données).
- **`packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart`** — délègue tout à `FirebaseZRepositoryImpl` (composition, pas d'héritage). **À préserver** : n'importe **pas** `cloud_firestore`. La propagation de `timestampFields` se fait via le `repository` injecté ; ne rien ajouter d'autre ici.
- **`packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart`** — **NE PAS MODIFIER** : local = ISO (AD-9).

### Mécanisme retenu (annotation → generator → firestore)

```
@ZcrudField(persistAs: ZPersistAs.timestamp)      [zcrud_annotations — enum pur-Dart, défaut iso8601]
        │  (ConstantReader, statique)
        ▼
générateur émet:  const Set<String> $XxxTimestampFields = {'created_at'};   [zcrud_generator — clés persistées, métadonnée neutre]
        │  (wiring app-side: passe le Set au constructeur de l'adaptateur)
        ▼
FirebaseZRepositoryImpl(timestampFields: {'created_at'})                     [zcrud_firestore]
   • écriture _encode : ISO String → Timestamp.fromDate(...)   (Timestamp confiné ici)
   • lecture           : Timestamp → ISO String  (puis _$asDateTime restitue)   (défensif AD-10, bi-format)
```

Décision clé : le hint transite par un **artefact généré séparé** (`Set<String>` de clés persistées), **pas** par `ZFieldSpec`/`ZcrudRegistry`. Motif : (1) respecter la contrainte « ne pas toucher `zcrud_core` » ; (2) AD-1 — `zcrud_firestore` ne dépend que de `zcrud_core` (jamais `zcrud_annotations`), donc il ne peut consommer ni l'enum `ZPersistAs` ni une annotation ; un `Set<String>` nu est le contrat neutre minimal. Le wiring `Set → adaptateur` est **app-side** (l'app dépend de tous les packages).

### Confirmation AD-5 préservé

`Timestamp` reste **exclusivement** dans `zcrud_firestore/lib/src/data`. Les surfaces publiques ajoutées sont des `Set<String>` (clés persistées) — aucun type `cloud_firestore` dans une signature. `zcrud_core` **n'est pas** modifié ; `zcrud_annotations` reste pur-Dart (enum neutre). Le code généré ne contient que des littéraux `String`. **AD-5 intégralement préservé.**

### Besoin `zcrud_core` détecté (et évité)

- **Aucune modification de `zcrud_core` n'est requise** par le chemin retenu (artefact `Set<String>` séparé + param `Set<String>` sur l'adaptateur).
- **Alternative écartée (signalée)** : router le hint par `ZFieldSpec.persistAs` + `ZcrudRegistry.fieldSpecsFor(kind)` (le registre expose **déjà** `fieldSpecsFor`, cf. `zcrud_core/.../zcrud_registry.dart:96`). Cette voie « colle » davantage au libellé epic (« propage dans le ZFieldSpec/registre ») mais **exigerait** d'ajouter un enum neutre `ZPersistAs` + un champ `ZFieldSpec.persistAs` (+ `copyWith`/`==`/`hashCode`) dans `zcrud_core`. Cet ajout serait **AD-5-safe** (marqueur neutre, aucun `Timestamp`), mais **viole la contrainte dure** de cette story (« NE TOUCHE PAS `zcrud_core` »). ⇒ **Reporté** à une éventuelle story `zcrud_core` dédiée si l'on veut, plus tard, exposer le hint côté domaine/UI. Non nécessaire pour B14.

### Standards de test

- Générateur : test unitaire direct de `generateForModel(element, annotation)` (pattern `zcrud_model_generator_test.dart`, sans pipeline build_runner) ; assertions sur la string émise.
- Firestore : `fake_cloud_firestore` (`FakeFirebaseFirestore`) — pattern existant (`firebase_z_repository_impl_test.dart`). Lire le champ **brut** via `firestore.collection(...).doc(id).get()` puis `snap.data()![key] is Timestamp` pour prouver le format sur disque.
- Gate AD-5 : réutiliser le style des gardes de pureté (grep `Timestamp` hors `zcrud_firestore/lib/src/data`).

### Project Structure Notes

- Fichiers disjoints des autres stories DP en vol (aucune dépendance croisée) ; **ne touche pas `zcrud_core`** ⇒ pas de point de contact partagé. Parallélisable sous les garde-fous CLAUDE.md.
- Nommage : enum `ZPersistAs` (préfixe `Z`), fichier `z_persist_as.dart` (snake_case), artefact généré `$XxxTimestampFields` (cohérent avec `$XxxFieldSpecs`/`registerXxx`).

### References

- [Source: docs/dodlp-edition-parity-gap.md#B14] (lignes 35, 66, 145, 194) — gap `timestamp`, action proposée.
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:3694] — écriture `Timestamp.fromDate` conditionnée au type `timestamp`.
- [Source: dodlp-otr/.../edition_screen.dart:3405,851] — lecture tolérante `Timestamp`/`DateTime`.
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md:173] — story DP-11.
- [Source: packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart] — surface d'autorité `@ZcrudField`.
- [Source: packages/zcrud_generator/lib/src/zcrud_model_generator.dart:335-357,363-399,405-415] — `_toMapExpr` (ISO), `_emitFieldSpecs`, `_emitRegister`.
- [Source: packages/zcrud_generator/lib/src/zcrud_model_generator.dart:532-536] — `_$asDateTime` (String/DateTime seulement — motive la conversion lecture).
- [Source: packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:187-232] — `_typedCollection`/`_inject`/`_encode`/`_decode`.
- [Source: packages/zcrud_firestore/lib/src/data/firestore_z_remote_store.dart:19-76] — délégation par composition, isolation AD-5.
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart:75-107] — `register(..., fieldSpecs)` + `fieldSpecsFor`/`tryFieldSpecsFor` (voie alternative écartée).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] — AD-1 (graphe acyclique, `zcrud_firestore→zcrud_core`), AD-5 (domaine backend-agnostique), AD-9 (offline-first ISO local), AD-10 (désérialisation défensive).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze` (annotations/generator/firestore) : RC=0 chacun, `No issues found!`.
- `dart test` zcrud_annotations : 9/9 vert. `dart test` zcrud_generator : 84/84 vert (dont round-trip/AD-10 non-régression + 4 nouveaux tests artefact B14). `flutter test` zcrud_firestore : 82/82 vert (dont 8 nouveaux DP-11 + non-régression E5-1..E5-4).
- `python3 scripts/dev/graph_proof.py` : ACYCLIQUE OK, CORE OUT=0 OK (19 arêtes, inchangé).
- Garde AD-5 : aucun `import cloud_firestore`, aucun usage du **type** `Timestamp` hors `zcrud_firestore/lib/src/data` (seuls des identifiants camelCase `persistAsTimestamp`/`$XxxTimestampFields` et du dartdoc subsistent — sémantiquement neutres).

### Completion Notes List

- **Décision de portée (AC4)** : la conversion écriture ISO→`Timestamp` est appliquée **uniquement** dans `_encode` (chemin `save`), conformément à la story. Le chemin de merge E5-3 (`_mergedMap` via `writeMerged`/`applyMergedAll`) reste hors périmètre et écrit toujours en ISO — la **tolérance bi-format à la lecture** (`_inject` normalise `Timestamp`→ISO, laisse String tel quel) garantit qu'aucune donnée n'est perdue quel que soit le format sur disque.
- **Lecture unifiée** : la normalisation `Timestamp`→ISO vit dans `_inject`, funnel unique traversé par `_decode` (getById/getAll/watch/sync) **et** le `withConverter.fromFirestore` (round-trip de `save`). Zéro duplication.
- **Rétro-compat (AC7)** : `timestampFields` défaut `const <String>{}` ⇒ tous les chemins identiques à l'existant ; toutes les suites E2/E5 restent vertes sans modification.
- **AD-9 (AC8/AC9)** : `updated_at`/`is_deleted` (ZSyncMeta) jamais convertis (exclus de `_timestampFields`) ; `HiveZLocalStore` inchangé (local ISO).
- **zcrud_core NON modifié** : chemin retenu = artefact `Set<String>` séparé + param `Set<String>` sur l'adaptateur. Aucun besoin core détecté (l'alternative `ZFieldSpec.persistAs` reste écartée par contrainte de story).
- Fixture `Article.createdAt` annoté `persistAs: ZPersistAs.timestamp` pour couvrir l'ensemble non-vide (`{'created_at'}`) sans ajouter de champ ; `Author` couvre l'ensemble vide.

### File List

- `packages/zcrud_annotations/lib/src/domain/annotations/z_persist_as.dart` (nouveau — enum `ZPersistAs`)
- `packages/zcrud_annotations/lib/zcrud_annotations.dart` (export du nouvel enum)
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart` (param `persistAs` + dartdoc)
- `packages/zcrud_annotations/test/annotations_const_test.dart` (couverture `persistAs`)
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (`persistAsTimestamp` + `_emitTimestampFields` + branchement)
- `packages/zcrud_generator/test/models/article.dart` (fixture : `createdAt` hinté timestamp)
- `packages/zcrud_generator/test/zcrud_model_generator_test.dart` (tests artefact `$XxxTimestampFields`)
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (`_timestampFields` + `_encode`/`_applyTimestampHints`/`_inject`)
- `packages/zcrud_firestore/test/timestamp_hint_test.dart` (nouveau — 8 tests DP-11 + garde AD-5)
- _(code généré `packages/zcrud_generator/test/models/article.g.dart` régénéré par build_runner — gitignoré, non committé)_

### Change Log

- 2026-07-11 — Implémentation DP-11 (gap B14) : hint `@ZcrudField(persistAs: ZPersistAs.timestamp)` [zcrud_annotations] → artefact neutre `$XxxTimestampFields` (`Set<String>`) [zcrud_generator] → consommation `timestampFields` encode/decode `Timestamp` [zcrud_firestore]. AD-5 confiné, rétro-compat, zéro régression. Status → review.
