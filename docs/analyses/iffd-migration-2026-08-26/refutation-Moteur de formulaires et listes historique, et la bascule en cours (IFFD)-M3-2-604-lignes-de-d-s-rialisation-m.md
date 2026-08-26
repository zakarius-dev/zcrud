# Réfutation — M3 : « le socle sait déjà (dé)sérialiser à la place d'IFFD »

**Domaine** : Moteur de formulaires et listes historique, et la bascule en cours (IFFD)
**Besoin hôte** : 2 604 lignes de (dé)sérialisation manuelle + registre type→fabrique écrit à la main
**Gain annoncé** : ~2 604 lignes d'hôte supprimées
**Date** : 2026-08-26
**Verdict** : ❌ **DÉMENTIE**

---

## 0. Ce qui TIENT (vérifié, ligne par ligne)

Le canal existe, à l'endroit cité, et fait au niveau de l'émission ce qu'on lui prête.

| Affirmation | Vérification | Statut |
|---|---|---|
| `zcrud_generator/lib/builder.dart:19` | `Builder zcrudModelBuilder(BuilderOptions options) =>` — ligne **19** exacte | ✅ |
| `zcrud_annotations/.../zcrud_model.dart:151` | `class ZcrudModel {` — ligne **151** exacte | ✅ |
| Émet 6 artefacts | `generateForModel` (:165-192) : `_emitFromMap` + `_emitExtension` + `_emitFieldSpecs` + `_emitPersistedKeys` + `_emitRegister` + `_emitTimestampFields` | ✅ |
| registrar :1184 / :1208 | `'${doc}void register$className(ZcrudRegistry registry)…'` aux deux lignes | ✅ |
| timestampFields :1237 | `'const Set<String> \$${className}TimestampFields = $body;'` | ✅ |
| copyWith **:978** | En réalité **:986** (`'  $className copyWith({\n$copyParams\n  }) =>\n'`) ; `_emitExtension` commence :948 | ⚠️ imprécis |
| Annotations exportées | `zcrud_annotations.dart` exporte les 4 annotations + `z_persist_as` | ✅ |
| `auto_apply: dependents` | `zcrud_generator/build.yaml` — un consommateur en dev_dependency génère automatiquement | ✅ |
| `grep '@ZcrudModel' iffd/lib/` | **RC=1** — aucune occurrence | ✅ |
| `grep 'zcrud_generator' iffd/pubspec.yaml` | **RC=1** — absent | ✅ |
| `build_runner: ^2.15.1` au pubspec:539 | `iffd/pubspec.yaml:539` — exact | ✅ |
| Mesure des lignes | Rejouée par équilibrage d'accolades sur `iffd/lib/src/domain/` : **toMap 39 blocs / 522 l**, **copyWith 42 blocs / 954 l** → **1 476 l** au total. Identique au chiffre avancé, à la ligne près. | ✅ |
| `ZcrudRegistry` a une voie par `Type` | `kindOfType(Type)` :207, `kindOf<T>()` :186, `decodeOf<T>()` :294 — la table `_kindsByType` existe | ✅ |
| IFFD épingle `ref: v3.21.0` (48 fois), = version du générateur | ✅ |

**Le canal est réel.** Ce qui suit ne conteste pas son existence : il conteste qu'il **couvre le besoin d'IFFD**.

---

## R1 — DÉCISIF : le code émis vit dans une `extension`, et `DynamicModel` déclare `toMap`/`copyWith` **abstraits**

`zcrud_model_generator.dart:977` émet **exclusivement** :

```
extension ${className}Zcrud on $className {
  Map<String, dynamic> toMap() => …
  $className copyWith({…}) => …
}
```

**Grep négatif montré** — aucune autre forme de portage n'est émise :

```
$ grep -n "'mixin \|\"mixin \|abstract class \|implements " packages/zcrud_generator/lib/src/zcrud_model_generator.dart
RC_mixin=1
```

Or `iffd/lib/src/domain/models/dynamic_model.dart:9-13` :

```dart
abstract class DynamicModel {
  final String? id;
  const DynamicModel({this.id});
  Map<String, dynamic> toMap();                 // ABSTRAIT
  dynamic toJson() => json.encode(toMap());
  DynamicModel copyWith({String? id});          // ABSTRAIT
  List<Object?> get props;
```

Deux règles du langage Dart, sans exception :

1. **Un membre d'extension ne satisfait JAMAIS un membre abstrait hérité.** Supprimer `toMap()` d'une sous-classe de `DynamicModel` produit *« Missing concrete implementation of `DynamicModel.toMap` »*.
2. **Un membre d'instance MASQUE toujours l'homonyme d'extension.** Garder l'override rend le `toMap()` généré inatteignable autrement que par application explicite (`AnneeAccademiqueZcrud(this).toMap()`).

### Chiffrage

**33 des 49 classes** de `iffd/lib/src/domain/models/` sont enracinées à `DynamicModel` (fermeture transitive calculée sur les `extends`) :

> AnneeAccademique, Annexe, AppUser, AppUserData, ArticleCodeDuGATT, ArticleGATT, AuditeurIffd, AvisConsultatif, Commentaire, Course, Decision, Etude, EtudeDeCas, ExamModel, FlashcardModel, FlashcardRepetitionInfo, FlashcardTagModel, FolderContentModel, FolderContentsOrders, FolderDocument, FolderDocumentAnnotation, FolderDocumentLearningInfo, FolderDocumentReading, FolderInvitation, FolderModel, IffdAiRouterModel, MindmapModel, NoteExplicative, NoteInterpretative, SmartNoteModel, SubjectContentModel, SubjectModel, ValuationToolModel

Partition des 1 476 lignes de `toMap`+`copyWith` :

| Zone | Blocs | Lignes | % |
|---|---|---|---|
| **Classes enracinées `DynamicModel`** (extension inopérante) | 57 | **1 249** | **84,6 %** |
| Classes hors `DynamicModel` | 24 | 227 | 15,4 % |
| **Total** | 81 | 1 476 | 100 % |

**La borne annoncée « copyWith+toMap disparaissent (1 476 l) » est fausse à 84,6 %.** Elle se contredit d'ailleurs elle-même : elle pose dans la même phrase que « props/operator== restent à DynamicModel » — or c'est précisément `DynamicModel` qui rend les deux membres obligatoires en tant que membres d'instance.

Un repli par forwarder ne sauve rien : pour `toMap` il coûte une ligne par classe (gain net ~500 l, pas 522) ; pour `copyWith` il faut **redéclarer les N paramètres nommés** pour respecter la signature de l'hôte — soit exactement les 954 lignes qu'on prétendait supprimer.

---

## R2 — DÉCISIF : le générateur ne collecte QUE les champs déclarés localement, et la perte hérité est **silencieuse**

`_collectFields` (:465) itère `element.fields` — les champs **déclarés dans la classe**.

**Grep négatif montré** :

```
$ grep -n "allSupertypes" packages/zcrud_generator/lib/src/zcrud_model_generator.dart
RC_sup=1
```

La dartdoc du générateur l'admet (:645) : *« Un champ déclaré dans une classe de base **n'est pas collecté par le générateur** »*.

Pire : la garde censée couvrir ce cas, `_isSilentlyLost` (:630), **ne mord pas** sur un champ hérité de type sérialisable —

```dart
try {
  _classify(field, field.type);
  return false; // Type sérialisable : omission assumée, contrat inchangé.
} on InvalidGenerationSourceError {
  return true;
}
```

⇒ pour un `int`/`String?` hérité, **le build reste VERT** et le `toMap()` émis perd le champ **sans aucun signal** — exactement la classe d'échec (« effacerait le champ du document à la première écriture, sans erreur de build ni d'analyse ») que la dartdoc du générateur (:700-706) revendique refuser. La garde ne couvre que les types **non** sérialisables.

### Chiffrage côté hôte

**24 des 40 sous-classes** héritent d'une base **autre** que `DynamicModel`, porteuse de vrais champs :

| Base | Champs locaux | Sous-classes concernées |
|---|---|---|
| `AppUser` | 17 | `AppUserData`, `AuditeurIffd` |
| `ValuationToolModel` | 5 | `Annexe`, `ArticleGATT`, `ArticleCodeDuGATT`, `NoteInterpretative`, `Decision`, `AvisConsultatif`, `Commentaire`, `NoteExplicative`, `EtudeDeCas`, `Etude` (10) |
| `FolderContentModel` (+3 de `SubjectContentModel`) | 2 | `FlashcardModel`, `FlashcardTagModel`, `FolderDocument`, `MindmapModel`, `SmartNoteModel` (5) |
| chaîne CGI `Livre→Partie→Titre→Chapitre→Section→Paragraphe→Article` | tous les champs sont dans les bases | 7 |

La chaîne CGI est le cas limite : `grep -cE '^\s+final\s+'` rend **0** pour `Livre`, `Partie`, `Titre`, `Chapitre`, `Section`, `Paragraphe`, `Article` — leurs champs sont **mutables** (`int numero;`, `String? intitule;` dans `livre.dart:5-6`). `Article` (article.dart) déclare 2 champs locaux et hérite de 10 ; son `toMap()` fait :

```dart
@override
Map<String, dynamic> toMap() {
  return <String, dynamic>{
    ...super.toMap(),                 // ← notion que le générateur n'a pas
    ...{'paragraphe': paragraphe, 'contenu': contenu},
  };
}
```

et son `fromMap` est une **cascade de setters** (`..intitule = …`, 10 lignes), forme que `_$ArticleFromMap` ne produit pas.

⇒ pour `Article`, le `toMap()` généré émettrait **2 clés sur 12**, build vert. Pour `AppUserData`, **ses champs locaux seulement**, 17 clés hérités perdues.

---

## R3 — 36 champs `Map<…>` (+ 13 autres types) font LEVER le build, et l'échappatoire perd aussi des données

`_classify` (:818-847) accepte : `String`, `int`, `double`, `num`, `bool`, enum, `DateTime`, `ZDateRange`, un type `@ZcrudModel`, et `List<` de ceux-là. Sinon → `InvalidGenerationSourceError` (:841).

**Grep négatif montré** :

```
$ grep -n "isDartCoreMap" packages/zcrud_generator/lib/src/zcrud_model_generator.dart
RC_map=1
```

`Timestamp` n'apparaît dans le générateur que comme **métadonnée de clés** (`$XxxTimestampFields`, :1213-1235) — jamais comme type de champ classifiable.

### Inventaire mesuré des champs non classifiables dans `iffd/lib/src/domain/models/`

| Type | Champs | Où (extrait) |
|---|---|---|
| `Map<…>` | **36** | `annee_accademique.dart:16-34` (**22**, dont 6 en `Map<CycleIFFD, List<String>>`), `folder_model.dart:336-339` (4), `app_user.dart:47`, `ai_models.dart:239`, `requests/data_request.dart:7-12` |
| `Timestamp?` (cloud_firestore) | **3** | `annee_accademique.dart:13-14`, `exam_model.dart` |
| `IconData` / `IconData?` | **4** | — |
| `Color` / `Color?` | **4** | — |
| `Rect?`, `TimeOfDay?` | **2** | — |
| `List<PdfTextLine>` | **1** | — |
| génériques `List<T>`, `List<DataRequest<T>>` | **3** | `data_request.dart`, `data_response.dart` |

**12 des 31 fichiers** de modèles portent au moins un de ces types — dont les six plus gros : `app_user.dart` (589 l), `folder_model.dart` (489 l), `flashcard_repetition_info.dart` (489 l), `annee_accademique.dart` (483 l), `flashcard_model.dart` (410 l), `exam_model.dart` (168 l).

### Les trois issues sont toutes perdantes

1. Champ **non annoté** → `_rejectSilentlyLostFields` (:712) **lève** : build rouge.
2. Champ **annoté `@ZcrudField`** → `_classify` **lève** : build rouge.
3. Champ **annoté `@ZcrudIgnore`** → il sort de `fields`, donc du `copyWith` émis (`copyArgs` est construit sur `fields`, :969-975). L'appel généré `AnneeAccademique(…)` **ne passe plus** les 22 `Map` : paramètre requis ⇒ erreur de compilation ; paramètre optionnel à défaut (`= const {}`) ⇒ **remise au défaut silencieuse à chaque copyWith**.

---

## R4 — La sémantique de `copyWith` CHANGE, sur 241 sites d'appel

L'hôte utilise partout `param ?? this.param` (`annee_accademique.dart:277-319`) : passer `null` **conserve**.

Le généré utilise une **sentinelle** (`_emitExtension`, :969-975) :
`identical(x, _undefined) ? this.x : x as T` — passer `null` explicitement **remet à `null`**.

```
$ grep -rn "\.copyWith(" iffd/lib/ | grep -v "TextStyle|ThemeData|ColorScheme|EdgeInsets|BoxDecoration|IconTheme" | wc -l
241
```

**241 sites** dont chacun passant une expression nullable qui vaut `null` bascule de « conserver » à « effacer ». Ce n'est pas une suppression mécanique de lignes : c'est une migration de sémantique à auditer site par site. Le dépôt hôte porte déjà la trace d'un bug de cette famille (`annee_accademique.dart:313-315`, « B-4 : ce champ figurait dans la signature de copyWith mais n'était jamais réinjecté »).

---

## R5 — `id` n'est jamais émis

`DynamicModel.id` est **hérité**. `super.id` est utilisé sur **43 sites** dans `models/` ; seules **3** classes redéclarent un `id` local. N'étant pas dans `element.fields`, `id` n'entre ni dans le `toMap()` ni dans le `copyWith()` émis.

`DynamicModelExtension.copyWithId` (`dynamic_model.dart:75-79`) appelle `copyWith(id: id)` — **3 sites d'appel** — et ne compilerait plus contre un `copyWith` généré sans paramètre `id`.

---

## R6 — Le registre compte **46** entrées, pas 23

La citation `data_functions.dart:314` est exacte (`T fromMap<T>(Map<String, dynamic> map) {`). La map est ouverte à **:337** et fermée à **:409**. Comptage exact :

```
$ awk 'NR>337 && NR<409' lib/src/utils/functions/data_functions.dart | grep -cE "^\s+[A-Za-z_][A-Za-z0-9_.]*:\s*\(\)"
46
```

Décomposition : 1 `Color` + 20 modèles (`AnneeAccademique`…`AppUserRole`) + 7 CGI + 5 workflow + 10 valuation + 3 AI = **46**.

Le chiffre avancé (23) est faux d'un facteur 2. Note secondaire : l'entrée `Color:` (:346-351) n'est pas un modèle — le générateur ne peut pas l'émettre (on n'annote pas `Color`), elle resterait manuelle.

---

## R7 — Condition cachée non traitée : la fenêtre `analyzer`

`zcrud_generator/pubspec.yaml` :

```yaml
analyzer: ">=12.0.0 <14.0.0"
build: ^4.0.0
source_gen: ^4.0.0
```

`iffd/pubspec.lock` résout **aujourd'hui** :

| Paquet | Version résolue chez IFFD |
|---|---|
| **analyzer** | **9.0.0** |
| build | 4.0.7 |
| source_gen | 4.2.3 |
| build_runner | 2.15.1 |
| freezed | 3.2.5 |
| json_serializable | 6.13.0 |
| riverpod_analyzer_utils | 1.0.0-dev.9 |

Ajouter `zcrud_generator` impose un saut de **3 majeures** d'`analyzer`, à re-résoudre contre `freezed`, `json_serializable`, `riverpod_generator ^4.0.0+1`, `auto_route_generator ^10.1.0`, `flutter_gen_runner ^5.15.0`. Le pubspec du générateur documente lui-même que la borne `^12` seule *« rendait la résolution INSOLUBLE »* chez un hôte git.

⚠️ **Je ne peux pas trancher l'issue** : prouver la résolution exigerait un `pub get` dans `/home/zakarius/DEV/iffd`, interdit (lecture seule stricte). Mais la preuve avancée — « `build_runner ^2.15.1` est DÉJÀ au pubspec » — ne dit **rien** de cette fenêtre : la présence de `build_runner` est un proxy trompeur pour la compatibilité `analyzer`. **Défaut sur le doute : non tenu.**

---

## R8 — `zcrud_annotations` n'est pas une dépendance déclarée d'IFFD

`iffd/pubspec.yaml` : `dependencies:` ouvre ligne **10**, `dev_dependencies:` ligne **533**, `dependency_overrides:` ligne **552**. `zcrud_annotations` n'apparaît qu'à la ligne **577** — donc **uniquement en `dependency_overrides`**, jamais en `dependencies`.

**Grep négatif montré** :

```
$ grep -rn "zcrud_annotations" iffd/lib/
RC_ann_lib=1
```

Il faut donc ajouter `zcrud_annotations` en `dependencies` **et** `zcrud_generator` en `dev_dependencies`. Point mineur et résoluble, mais il contredit la lecture « il ne manque que le générateur ».

---

## R9 — Contrainte assumée, mais sous-estimée : `fromMap` reste à la main

`_requireDomainFromMap` (:245) **exige** que toute classe `@ZcrudModel` déclare un `fromMap` (factory ou statique) ; `_requireCompatibleSignature` (:381) impose exactement un positionnel requis auquel `Map<String, dynamic>` soit assignable ; sur une classe `ZExtensible`, `_rejectNakedCodegenDelegation` (:417) **refuse la délégation nue**.

La borne « les fromMap gardent une factory mince » est donc juste dans son principe — mais « mince » suppose que `_$XxxFromMap` fasse le travail. Or 38 blocs `fromMap` d'IFFD portent de la logique maison (`parseToInt`, `restoreMapValues`, cascades `..champ = …`, valeurs de repli), et pour les 24 classes à champs hérités (R2) et les 12 fichiers à champs non classifiables (R3), `_$XxxFromMap` **ne peut pas** produire l'objet complet. La factory reste épaisse.

---

## Bilan chiffré du gain réellement atteignable

| Poste | Annoncé | Réel |
|---|---|---|
| `toMap` + `copyWith` supprimés | 1 476 l | **≤ 227 l** (les seules 24 blocs hors `DynamicModel`) |
| dont réellement éligibles | — | encore moins : `DataRequest`/`DataResponse` sont **génériques** (non classifiables) ; les 7 classes CGI ont **tous** leurs champs hérités (perte silencieuse, R2) ; `MindmapNode` porte `Color` ; il ne reste en pratique qu'une poignée de classes plates |
| `fromMap` supprimés | « factory mince » | logique défensive maison conservée, 38 blocs / ~1 128 l largement préservés |
| registre `data_functions.dart` | 23 entrées | **46** entrées, dont 1 (`Color`) non générable |
| **Total** | **~2 604 l** | **quelques centaines de lignes au mieux**, au prix d'un audit de 241 sites `copyWith` et d'un saut `analyzer` 9→12 non résolu |

---

## Verdict

❌ **DÉMENTIE.**

Le canal existe et fonctionne — mais il est conçu pour des **modèles plats, sans héritage, à champs scalaires**, et il livre `toMap`/`copyWith` dans une **`extension`**. IFFD tient l'exact opposé : une hiérarchie de **33 classes enracinées à une base abstraite qui déclare `toMap`/`copyWith` obligatoires**, 24 sous-classes à champs hérités, 49 champs de types non classifiables, et une sémantique de `copyWith` inverse de celle du générateur.

Le gain n'est pas « ~2 604 lignes supprimées » : c'est **≤ 227 lignes théoriquement atteignables (15,4 %)**, encore réduites par R2/R3, et conditionnées à une résolution `analyzer` non démontrée.

**Ce qui rendrait l'affirmation vraie** — et qui n'est pas dans la CR :
1. **Faire émettre le générateur en `mixin` ou en membres d'instance**, pas en `extension` (lève R1 : 1 249 l redeviennent atteignables).
2. **Collecter les champs hérités** (`allSupertypes`), ou refuser explicitement au build toute classe `@ZcrudModel` à supertype non-`Object` porteur de champs (lève R2 : supprime la perte silencieuse).
3. **Une branche `Map<K,V>` dans `_classify`**, avec clé `String` ou enum (couvre 36 des 49 champs bloquants).
4. **Un mode `copyWith` à sémantique `??`**, optionnel, pour les hôtes migrants (lève R4 : évite l'audit de 241 sites).
5. **Prouver la co-résolution `analyzer >= 12`** avec la chaîne codegen d'IFFD (freezed 3.2.5, json_serializable 6.13.0, riverpod_generator ^4, auto_route_generator ^10.1).

---

### Fichiers lus (chemins absolus)

**zcrud** (lecture) :
- `/home/zakarius/DEV/zcrud/packages/zcrud_generator/lib/builder.dart`
- `/home/zakarius/DEV/zcrud/packages/zcrud_generator/build.yaml`
- `/home/zakarius/DEV/zcrud/packages/zcrud_generator/pubspec.yaml`
- `/home/zakarius/DEV/zcrud/packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (1 619 l)
- `/home/zakarius/DEV/zcrud/packages/zcrud_annotations/lib/zcrud_annotations.dart`
- `/home/zakarius/DEV/zcrud/packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart`
- `/home/zakarius/DEV/zcrud/packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart`

**iffd** (LECTURE SEULE — aucune écriture) :
- `/home/zakarius/DEV/iffd/pubspec.yaml`, `/home/zakarius/DEV/iffd/pubspec.lock`
- `/home/zakarius/DEV/iffd/lib/src/domain/models/dynamic_model.dart`
- `/home/zakarius/DEV/iffd/lib/src/domain/models/annee_accademique.dart`
- `/home/zakarius/DEV/iffd/lib/src/domain/models/cgi/livre.dart`, `cgi/article.dart`
- `/home/zakarius/DEV/iffd/lib/src/utils/functions/data_functions.dart`
- balayage : `/home/zakarius/DEV/iffd/lib/src/domain/` (71 fichiers `.dart`, 49 classes)
