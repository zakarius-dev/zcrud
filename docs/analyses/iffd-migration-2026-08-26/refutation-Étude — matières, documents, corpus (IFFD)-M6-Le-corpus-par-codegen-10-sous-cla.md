# Réfutation — M6 « Le corpus par codegen »

Domaine : **Étude — matières, documents, corpus (IFFD)**
Besoin hôte : 10 sous-classes + 10 dépôts + 10 providers + 2 tables de dispatch → un `ZValuationText{kind, identifier, title, description, content}`
Gain annoncé : ~1230 lignes d'hôte supprimées

## VERDICT : RÉFUTÉE

Le canal existe et fait ce qu'on lui prête. **Mais il ne fait pas le travail qui produit le gain**, il n'est pas atteignable en l'état, et sa couverture du besoin réel est partielle — 6 structures indexées par `Type` dans 22 fichiers, dont trois portent l'identité fonctionnelle du corpus (l10n, nom de collection Firestore, ACL).

---

## 1. Ce qui RÉSISTE (crédit intégral)

Vérifié dans le **corps**, pas dans la dartdoc.

| Affirmation | Vérification | Verdict |
|---|---|---|
| `zcrud_model.dart:151` | `class ZcrudModel` bien en 151 ; `kind` + `fieldRename` | ✅ |
| `zcrud_field.dart:52` | `const ZcrudField({...})` en 52 ; **18 paramètres** comptés un à un | ✅ |
| 5 émissions | `_emitFromMap`:853, `extension ${className}Zcrud`:978, `_emitFieldSpecs`:1065, registrar:1177, `_emitTimestampFields`:1224 — chaînées en 179-190 | ✅ |
| 10 classes aux lignes citées | 163/205/247/289/331/373/415/457/499/541 — vérifiées par `awk` | ✅ |
| 42 lignes chacune, duplication au mot près | `Decision`:163-201 et `Annexe`:541-581 lues intégralement : ctor + `copyWith` + `fromMap` + `toString`, identiques hors le nom du type | ✅ |
| ArticleGATT seul en `Crud.valuationToolCrudOperations` | `firebase_models_repositories_impls.dart:306-434` lu ; 9 en `defaultFolderContentCrudOperations` | ✅ |
| `getFirebaseCollectionName<T>` rend bien `collectionName ?? FIREBASE_COLLECTION_NAMES[T] ?? T.toString()` | `databases_functions.dart:8-11` | ✅ |
| Prérequis absents | `grep -n zcrud_generator pubspec.yaml` → **RC=1** ; `grep -rn '@ZcrudModel' lib` → **RC=1** | ✅ |

Crédit supplémentaire non revendiqué par l'affirmation, et réel : le registre **accepte** un même type Dart sous plusieurs `kind` — `_kindsByType` est un `Map<Type, Set<String>>` (`zcrud_registry.dart:163`). La forme visée n'est donc pas interdite par le socle.

---

## 2. Ce qui la DÉMENT

### 2.1 — Le codegen ne fait PAS la bascule qui produit le gain (réfutation principale)

`@ZcrudModel(kind:)` est une annotation **`const`** : un `kind` par classe, figé à la compilation. `_emitRegister` (generator:1173-1183) émet exactement **une** ligne :

```
registry.register<$className>('$kind', fromMap: …, toMap: …, fieldSpecs: …)
```

Le `kind` y est un **littéral de chaîne soudé au code émis**. Une classe annotée = une inscription. Les 10 `kind` du corpus ne sont donc **pas** générés : 1 sur 10 vient du codegen, les 9 autres s'écrivent à la main.

Conséquence de fond : **l'effondrement 10 types → 1 type est un refactor d'hôte pur**, réalisable aujourd'hui sans une ligne de zcrud. C'est lui — pas le codegen — qui retire les 10 sous-classes, les 10 dépôts et les 10 providers, c'est-à-dire la quasi-totalité des ~1230 lignes annoncées. Le codegen n'enlève que le boilerplate de sérialisation *par classe*. L'affirmation attribue au socle un gain dont la cause est ailleurs.

### 2.2 — Condition cachée : le générateur EXIGE une `fromMap` écrite à la main

Non mentionné par l'affirmation. `_requireDomainFromMap` (generator:245-277) **échoue le build** (`InvalidGenerationSourceError`) si la classe annotée ne déclare pas un décodeur `fromMap` (factory ou méthode statique). Pour une classe `ZExtensible`, `_rejectNakedCodegenDelegation` refuse en plus la délégation nue `=> _$XxxFromMap(map)`. Le codegen n'est donc jamais « annoter et c'est fini ».

### 2.3 — Non atteignable : `zcrud_annotations` n'est pas une dépendance déclarée

Sections du pubspec IFFD : `dependencies:` 10-532, `dev_dependencies:` 533-551, `dependency_overrides:` 552-733.

```
grep -n "zcrud_annotations" pubspec.yaml   → 569 (commentaire), 577, 581
sed -n '10,532p'  pubspec.yaml | grep zcrud_annotations → RC=1
sed -n '533,551p' pubspec.yaml | grep zcrud_annotations → RC=1
grep -n "zcrud_generator" pubspec.yaml → RC=1
grep -rn "package:zcrud_annotations" lib/ → RC=1
```

`zcrud_annotations` n'existe **que** dans `dependency_overrides` (577). Un override ne confère aucun droit d'import : il redirige la source d'un paquet déjà dans le graphe (ici par transitivité `zcrud_study_kernel → zcrud_annotations`). Importer un paquet transitif est une violation de `depend_on_referenced_packages`. Le prérequis n'est donc pas « ajouter `zcrud_generator` » mais **deux** entrées : `zcrud_annotations` en `dependencies`, `zcrud_generator` en `dev_dependencies`. `build_runner ^2.15.1` et `build.yaml` sont en revanche déjà présents.

### 2.4 — « 2 tables de dispatch » : il y en a SIX, dans 22 fichiers

283 occurrences écrites à la main des 10 noms de types dans `lib/` (hors `.g.dart`), réparties sur 22 fichiers — l'affirmation en compte 5.

| # | Structure indexée par `Type` | Emplacement | Compté ? |
|---|---|---|---|
| 1 | `_toolFactories` `Map<Type, …>` | `valuation_tool_model.dart:~65-79` | oui |
| 2 | `getRepository<T>` (chaîne if/else sur `T`) | `valuation_tool_model_repository.dart:45-68` | oui |
| 3 | `factories` global de `fromMap<T>` | `data_functions.dart:338+` (10 entrées valuation) | **non** |
| 4 | `resourceFactories` (l10n) | `l10n/data_crud/messages/abstract.dart:69-78` | **non** |
| 5 | `valuationTools` (corpus de seed) | `utils/constants/valuation_tools/valuation_tools.dart:12-22` | **non** |
| 6 | `tabsTypes` `List<Type>` | `valuation_tool_model.dart:148-160` | **non** |

Distribution mesurée (`grep -rnwE … | cut -d: -f1 | sort | uniq -c`) : 94 `valuation_tool_model.dart` · 36 `folder_flashcards_list_page.dart` · 30 `firebase_models_repositories_impls.dart` · 20 `valuation_tool_model_repository.dart` · 18 `folder_flashcards_filter_zcrud_edition.dart` · 14 `data_functions.dart` · 10 `valuation_tool_model_actions_dialog_widget.dart` · 10 `l10n/…/abstract.dart` · 10 `corpus_providers.dart` · 9 `valuation_tools.dart` · 32 dans 8 fichiers de seed · 1 `ai_prompt_generator.dart` · … Et 17 signatures `<T extends ValuationToolModel>`.

### 2.5 — Trois régressions non chiffrées, toutes portées par le Type Dart

**(a) Nom de collection Firestore.** `databases.dart:3` : `const Map<Type, String> FIREBASE_COLLECTION_NAMES = {};` — **la table est VIDE**. `getFirebaseCollectionName<T>()` retombe donc systématiquement sur `T.toString()` : **le nom du type Dart EST le nom de la collection**. L'affirmation dit « l'override EXISTE DÉJÀ » — vrai du *paramètre*, faux de son câblage : aucun site valuation ne le passe. Effondrer les 10 types sans re-câbler chaque appel fait converger les 10 collections sur une seule (`"ZValuationText"`). Ce n'est pas « ne bloque pas » : c'est une migration de données.

**(b) Localisation.** `abstract.dart:107-112` :
```dart
String ressourceName(dynamic type, num count) {
  String notFound(int count) => type.toString();
  final translation = resourceFactories[type.toString()] ?? notFound;
  return translation.call(howMany);
}
```
Indexé sur `type.toString()`. Après effondrement, les 10 libellés humains (« Décision », « Avis Consultatif », …) tombent tous sur `notFound` et l'UI affiche la chaîne `ZValuationText`. Sites concernés relevés : `valuation_tool_model_actions_dialog_widget.dart:162`, `folder_flashcards_filter_zcrud_edition.dart:419` et `:515`, `folder_flashcards_list_page.dart:960/972/980`…

**(c) ACL.** `valuation_tool_model_actions_dialog_widget.dart:335` appelle `permissions?.can<T>(crud)`. `app_user_permissions.dart:70` : `bool can<R>(Crud crud, [String? dataType])` — résolution par le type générique quand `dataType` est omis, ce qui est le cas ici. Une permission unique couvrirait alors les 10 corpus. L'échappatoire `dataType` existe, non câblée — même situation que `collectionName`.

### 2.6 — « DUPLICATION VÉRIFIÉE AU MOT PRÈS » masque que le « 10 » n'est pas uniforme

ArticleGATT est singulier de **trois** façons, pas d'une :

```
sed -n '135,147p' … | grep -c "'"        → 10   (tabsTitles)
sed -n '149,160p' … | grep -cE "^\s+[A-Z]" →  9   (tabsTypes)
sed -n '148,161p' … | grep -w ArticleGATT  → RC=1 (absent)
grep -w ArticleGATT …/valuation_tools.dart → RC=1 (absent du seed)
```

`tabsTitles` porte 10 libellés, `tabsTypes` 9 types ; le corpus de seed `valuationTools` a 9 entrées. S'y ajoute l'ACL distincte déjà relevée. Une classe unique à `kind` uniforme doit donc **reconduire ces asymétries** explicitement. (Note : `tabsTitles`/`tabsTypes` n'ont aucun consommateur — `grep -rn "tabsTypes\|tabsTitles" lib/` ne rend que les 2 déclarations : code mort, mais désalignement 10/9 latent.)

### 2.7 — Le décompte de lignes est gonflé

`corpus_providers.dart` fait **90 lignes au total** (pas « 48 + 650 »). Les 650 lignes sont `corpus_providers.g.dart`, **généré par `riverpod_generator`** — du code déjà produit par codegen, pas du code d'hôte maintenu à la main. Le compter comme « lignes d'hôte supprimées » gonfle le gain d'environ la moitié. À l'inverse, non porté au débit : 992 lignes de seed dans `utils/constants/valuation_tools/` (dont la forme, `List<Map<String,String>>`, est heureusement non typée et survivrait telle quelle).

### 2.8 — Effet de bord du multi-`kind` sur un type unique

Le registre l'accepte, mais `kindOfType` (`zcrud_registry.dart:207-219`) **lève `StateError`** dès qu'un type porte plus d'un `kind`, et `decodeOf<T>` (`:295`) en hérite. Tout chemin résolvant kind-depuis-type devient donc un chemin d'exception : l'hôte doit passer partout par la voie explicite `encode(kind, …)` / `decode(kind, …)`. Contrainte réelle, jamais mentionnée.

---

## 3. Ce qui est vrai à la place

Le moteur codegen de zcrud est réel, ses cinq émissions sont vérifiées dans le corps du générateur, et le registre supporte bien un type unique sous plusieurs `kind`. Mais :

1. il devient atteignable au prix de **deux** entrées de pubspec (`zcrud_annotations` → `dependencies`, `zcrud_generator` → `dev_dependencies`), pas d'une ;
2. il **exige une `fromMap` écrite à la main** par classe annotée, sous peine d'échec de build ;
3. il **ne réalise pas** l'effondrement 10 → 1 — ce refactor est purement côté hôte et concentre l'essentiel du gain annoncé ; le codegen n'émet qu'1 des 10 inscriptions ;
4. il laisse à réécrire à la main **6 structures indexées par `Type`** réparties sur **22 fichiers** (283 sites), dont trois — nom de collection Firestore (table **vide**, donc `T.toString()`), libellés l10n, ACL `can<T>` — tirent aujourd'hui leur identité du **type Dart lui-même** ;
5. le gain net est nettement inférieur à ~1230 lignes, dont 650 sont du code déjà généré.

Formulation qui résisterait : « le socle sait générer la (dé)sérialisation, le schéma et l'inscription au registre d'**une** entité `ZValuationText` ; l'effondrement des 10 types, la ré-indexation par `kind` des 6 tables de dispatch de l'hôte et le re-câblage explicite de `collectionName` / `ressourceName` / `can` restent à la charge d'IFFD. »

---

### Méthode
Lectures seules dans `/home/zakarius/DEV/iffd`. Aucun test lancé, aucun fichier hôte modifié. Toute absence est établie par un RC de `grep` montré ci-dessus.
