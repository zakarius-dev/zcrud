# Changelog

All notable changes to `zcrud_generator` are documented in this file.

## 3.37.0 — 2026-08-30

### Corrigé — `fieldRename` est enfin déclarable depuis un paquet consommateur

`@ZcrudModel(fieldRename: ZFieldRename.…)` écrit dans une bibliothèque qui
n'importait que `package:zcrud_annotations/zcrud_annotations.dart` faisait
échouer le build sur « constante nulle ». Cause mesurée : `ZFieldRename` vit
dans `zcrud_core` et n'était **pas ré-exporté** par le barrel des annotations ;
l'identifiant écrit ne se résolvait donc pas, et l'analyzer rendait une
constante `null` pour `fieldRename` là où `kind` restait lisible. Les entités du
socle y échappaient parce qu'elles importent aussi un barrel de `zcrud_core` —
d'où l'asymétrie.

- `zcrud_annotations` ré-exporte `ZFieldRename` : le paramètre est renseignable
  avec le seul barrel des annotations (voir son propre CHANGELOG).
- **Lecture de secours par l'AST** : si la constante reste illisible (versions
  désalignées, import masqué), le générateur relit ce qui est **littéralement
  écrit** sur l'annotation. Seule la forme `ZFieldRename.<valeur>` (préfixe
  d'import toléré) est acceptée — un alias `const`, une expression calculée ou un
  argument absent ne donnent rien à lire.
- **Aucun repli, jamais.** Quand rien de littéral n'est lisible, le build échoue,
  désormais avec un message **actionnable** : importer `ZFieldRename`, écrire la
  valeur littéralement, aligner les versions de `zcrud_annotations` et
  `zcrud_core`. Un repli sur `snake` renommerait les clés persistées à l'insu de
  l'auteur.

Gardes ajoutées (`test/field_rename_consumer_test.dart`) : déclaration depuis le
seul barrel des annotations (les trois stratégies), relecture AST quand la
constante est illisible, refus par échec de build d'un alias `const`, contenu
actionnable du message.

## 3.36.0 — 2026-08-30

### Corrigé — l'extension générée ne peut plus être SÉMANTIQUEMENT MORTE en silence

Une classe annotée `@ZcrudModel` dont la **hiérarchie** déclarait déjà `toMap()`
(ou `copyWith()`) en **membre d'instance** recevait un `toMap()` généré dans une
**extension** — et un membre d'extension ne surcharge **jamais** un membre
d'instance hérité. L'extension était syntaxiquement présente et sémantiquement
morte : c'est le corps hérité qui répondait, y compris pour un appel écrit dans
la sous-classe elle-même. Les champs **propres** du modèle étaient décodés mais
**jamais écrits** au document persisté.

Rien ne le signalait. Le build passait, `analyze` passait, et un test de fixture
passait aussi — l'objet en mémoire étant correct, la perte n'existait qu'au
document. Le premier symptôme aurait été une donnée utilisateur disparue.

Le remède existait déjà — le mixin `_$XxxZcrud`, qui apporte les **mêmes** corps
en membres d'instance — mais rien n'avertissait celui qui ne l'appliquait pas.
Ce cas est désormais un **échec de build** (`InvalidGenerationSourceError`)
nommant la classe, le membre hérité, le `fichier:ligne` de sa déclaration et le
geste : `class Xxx extends … with _$XxxZcrud`.

Trois situations restent **acceptées**, et sont gardées par contre-preuve : la
classe applique le mixin (le remède) ; elle déclare le membre elle-même (choix
écrit dans sa propre source) ; le membre « hérité » vient d'une **extension**,
qui ne se transmet pas par héritage et ne masque rien.

Aucun modèle du dépôt n'était concerné : `melos run generate` reste vert, sans
un octet de diff sur les `.g.dart`.

### Corrigé — un accesseur qui rétrécit un champ hérité ne perd plus sa spec

Un getter portant le nom d'un champ **hérité annoté**
(`DateTime get createdAt => super.createdAt ?? epoch`) était traité comme un
masquage de champ. Un accesseur n'étant pas un `FieldElement`, la spec du champ
hérité **disparaissait** : `$XxxFieldSpecs` rétrécissait sans un mot, et le
`.g.dart` cessait de compiler — pendant que `analyze` disait « No issues », les
`*.g.dart` étant exclus de l'analyse. Le silence était le défaut.

Seule une **vraie redéclaration de champ** masque désormais. Un accesseur
n'apporte aucun stockage : la spec du champ hérité est **conservée**, et le
`toMap()` émis lit `this.<champ>` — donc l'accesseur. Le rétrécissement est
honoré sans rien coûter à la persistance, et le champ reste `required` au
constructeur. Si le constructeur non nommé n'expose pas le champ ainsi conservé,
l'échec de build existant le **nomme** au lieu de le perdre.

## 3.34.0 — 2026-08-29

### Ajouté — les structures IMBRIQUÉES : `List<Map<K, V>>` et `Map<K, Map<K2, V2>>`

Une `Map<K, V>` était (dé)sérialisable comme **type de champ**, mais nulle part
ailleurs : un élément de liste ou une valeur de map de type `Map` faisaient
**échouer le build**. Les deux refus étaient des manques, pas des arbitrages —
celui de la liste l'écrivait littéralement (« pas *encore* comme ÉLÉMENT de
liste »), celui de la valeur ne proposait pour tout remède que de déclarer la
valeur `dynamic`, c'est-à-dire de **renoncer au typage** et de rendre au
consommateur l'entière charge du décodage défensif.

Sont désormais émis, avec les **mêmes** types de valeur que `Map<K, V>`
(`dynamic`/`Object?`, scalaires, `DateTime`, `ZDateRange`, enum, sous-modèle
`@ZcrudModel`, `List<T>` de ceux-ci) et à **profondeur libre** :

```dart
@ZcrudField() final List<Map<String, dynamic>> rows;
@ZcrudField() final Map<String, Map<String, int>> matrix;
@ZcrudField() final Map<String, Map<LedgerZone, DateTime>> schedule;
@ZcrudField() final Map<String, List<Map<String, int>>> deep;
```

Le décodage est **défensif à chaque niveau** (AD-10) : un élément non-map est
écarté et la liste survit amputée ; une entrée illisible **à l'intérieur** d'une
map interne n'emporte ni la map interne, ni l'entrée externe, ni le parent — qui
ne lève jamais. Un `null` de valeur déclaré nullable reste **préservé**. La map
persistée reste à clés `String` **à tous les niveaux** (clé enum → `.name`), et
les `DateTime` internes sortent en ISO-8601.

### Reste REFUSÉ, explicitement

- `List<Map<K, V>?>` (élément map **nullable**) : le décodage d'une liste filtre
  ses éléments illisibles par `whereType`, geste qui effacerait aussi les `null`
  **déclarés** ; la liste rendue aurait alors une longueur différente de celle
  écrite, sans signal. Le message nomme le remède (`List<Map<K, V>>`).
- Une clé de map non `String`/enum et une valeur non (dé)sérialisable, **à
  quelque niveau que ce soit** : le refus remonte du niveau interne comme du
  niveau externe.

### Aucun `.g.dart` existant ne change de contenu

Les liaisons du code émis ne sont numérotées **qu'aux niveaux imbriqués**
(`e$1`, `k$2`…) ; la profondeur 0 garde ses noms historiques (`e$`, `k$`, `v$`).
Toutes les formes déjà supportées produisent donc un texte **identique à
l'octet** — mesuré : les trois fixtures non touchées du paquet gardent leur
sha256 après régénération. Deux gardes tiennent cette propriété : l'une exige
`e$` (et l'absence de `e$1`) sur `Map<String, List<T>>`, l'autre exige la
numérotation sur les formes imbriquées.

### Conséquence à connaître

Un champ **non annoté** de type `List<Map<…>>` ne fait plus rougir le build par
le contrôle de perte silencieuse : comme tout type désormais sérialisable, il
est simplement hors persistance tant qu'il n'est pas annoté. C'est le
comportement déjà en vigueur pour `Map<K, V>` depuis son ouverture.

Un hôte qui avait **contourné** ces refus par un canal manuel (décodage et
réémission écrits à la main, clé réservée hors `extra`) peut désormais annoter
le champ — mais **doit alors retirer son canal manuel**, sous peine de réémettre
la clé en double. Le contournement et le codegen s'**additionnent**, ils ne se
remplacent pas silencieusement.

## 3.33.0 — 2026-08-29

### Ajouté — le code émis est aussi disponible en MEMBRES D'INSTANCE (mixin `_$XxxZcrud`)

`toMap()` et `copyWith()` n'étaient émis que dans l'extension publique
`XxxZcrud`. Un membre d'extension n'est ni virtuel ni héritable : il **ne
satisfait jamais** un membre abstrait déclaré par une super-classe, et il reste
invisible à tout appel fait à travers un type de base
(`(model as Base).toMap()`). Une hiérarchie dont la racine déclare `toMap()` /
`copyWith()` abstraits — la forme la plus répandue chez les hôtes portant un
modèle dynamique — ne pouvait donc pas adopter le codegen du tout.

Le générateur émet désormais, **en plus** de l'extension, un mixin
`_$XxxZcrud` portant les **mêmes** `toMap()`/`copyWith()` en membres
d'instance, plus un getter abstrait par champ persisté. Application côté
modèle, facultative, en une ligne :

```dart
class Facture extends DynamicModel with _$FactureZcrud { … }
```

Le mixin ne déclare aucun champ d'instance : les constructeurs `const` du
modèle restent `const`. Les champs déclarés par la classe qui l'applique
deviennent des `@override` des getters abstraits (lint `annotate_overrides`).

### Inchangé — la map produite, à l'octet

Les corps des deux émissions proviennent d'**une seule source de texte** : le
`toMap()` du mixin et celui de l'extension sont identiques caractère par
caractère, et une garde le vérifie sur le texte émis. Appliquer le mixin ne
change donc pas d'un octet le document persisté. L'extension `XxxZcrud` est
conservée telle quelle : un modèle qui n'applique pas le mixin ne voit
strictement aucun changement de comportement.

Les fichiers `*.g.dart` de tous les paquets sont réécrits (un bloc `mixin` en
plus) — **diff de forme, pas de fond** : aucun symbole existant n'est renommé,
déplacé ni supprimé, et la (dé)sérialisation est inchangée.

## 3.31.0 — 2026-08-29

### Ajouté — les champs annotés HÉRITÉS entrent dans le code émis

Un champ portant `@ZcrudField`/`@ZcrudId` déclaré sur une **super-classe** ou un
mixin n'était pas collecté : il était absent de `toMap()`, du décodeur et de
`$XxxFieldSpecs` de la sous-classe, **sans que le build ne rougisse** — la
donnée disparaissait du document à la première écriture, sans aucun signal. Ces
champs sont désormais collectés, dans l'ordre de **linéarisation Dart**
(ancêtre le plus lointain → mixins → classe annotée), donc **avant** les champs
locaux et de façon stable d'un build à l'autre.

- Une redéclaration plus **proche** de la classe annotée masque la déclaration
  de base : le champ n'est jamais collecté deux fois.
- Un champ hérité annoté que le **constructeur non nommé n'expose pas** est un
  **échec de build explicite** (le `.g.dart` ne compilerait pas) : le message
  nomme le champ, sa classe de déclaration et prescrit `super.<champ>`.
- Aucun modèle existant n'est touché : la seule base commune du dépôt
  (`ZEntity`) ne porte aucun champ annoté.

### Ajouté — les champs `Map<K, V>` sont (dé)sérialisables

`Map` n'était classifiable ni comme type de champ ni comme type non
sérialisable exploitable : les trois issues étaient perdantes (build rouge sans
annotation, build rouge avec `@ZcrudField`, perte de données avec
`@ZcrudIgnore`).

- **Clé** : `String`, ou un enum non nullable — encodé par `.name`, la map
  persistée restant à clés `String`.
- **Valeur** : `dynamic`/`Object?` (recopiée telle quelle), scalaire supporté,
  `DateTime` (ISO-8601), `ZDateRange`, enum, sous-modèle `@ZcrudModel`, ou
  `List` de ceux-ci ; une valeur nullable est admise et son `null` **survit** au
  round-trip.
- **Décodage défensif** (AD-10) : une entrée dont la clé ou la valeur est
  illisible est ignorée, le reste de la map survit, le parent ne lève jamais.
- Type de champ inféré : `EditionFieldType.dynamicItem`, surchargeable par
  `@ZcrudField(type:)`. Une map n'est **pas** marquée `multiple` — c'est un
  dictionnaire, pas une multi-valeur.
- Deux formes restent **refusées explicitement**, jamais approximées : une clé
  d'un autre type, et une `List` de maps.

Conséquence de contrat : un champ `Map` **non annoté** ne fait plus échouer le
build. Il est ignoré en silence, comme tout champ non annoté d'un type
sérialisable — `@ZcrudIgnore` reste la façon d'assumer explicitement
l'exclusion.

## 3.3.0 — 2026-08-21

### Modifié — la dartdoc émise dans le code généré est documentaire

Les commentaires que le générateur écrit dans les `*.g.dart` citaient des
identifiants de suivi interne. La documentation du projet étant générée à partir
des commentaires Dart, ils s'adressaient au mauvais lecteur. Le contenu décrit
désormais ce que le symbole garantit, sans référence de traitement.

## 0.90.0 — 2026-08-12

### Modifié — durcissement cassant

- **Un champ enum dont le type redéclare `name` comme membre d'instance est
  désormais un échec de build** (champ direct comme `List<T>`). L'encodage émis
  passe par `.name` : sur un tel enum, l'appel résout sur le membre déclaré —
  typiquement un libellé d'affichage — et la valeur écrite diverge du nom
  technique ; le décodeur émis, qui compare au nom technique via l'extension
  SDK non masquable, ne la relit jamais. Le piège était **silencieux** : ni le
  build ni l'exécution ne signalaient rien, seuls des documents illisibles au
  décodage le révélaient. Le build le refuse, nomme **tous** les champs fautifs
  du modèle en une passe et cite les deux remèdes : renommer le membre de
  l'enum (ex. `label`), ou annoter le champ `@ZcrudIgnore` et persister la
  valeur par un canal manuel.

  **Qui est concerné.** Tout modèle `@ZcrudModel` portant un champ enum
  (annoté `@ZcrudField`) dont le type déclare un champ ou un getter d'instance
  `name` — localement ou via un mixin. Les enhanced enums **sans** membre
  `name` (constructeur, autres champs comme `label`) restent acceptés à
  l'identique. Aucun changement du contrat d'émission : `.name` reste
  l'encodage, et il désigne désormais toujours le nom technique.

## 0.88.0 — 2026-08-12

### Corrigé

- **`@ZcrudModel(fieldRename:)` était ignoré** : quelle que soit la stratégie
  déclarée (`none`, `kebab`, `pascal`), les clés persistées étaient renommées en
  `snake_case`. La lecture de l'énumération d'annotation comparait un accesseur
  **qualifié** (`ZFieldRename.none`) à un nom nu, et retombait donc toujours sur
  la branche par défaut. Adopter le codegen sur un parc documentaire existant
  renommait ainsi **toutes** les clés : documents déjà écrits devenus illisibles
  par le décodeur généré, et documents neufs illisibles par le chemin hérité.
  Les quatre stratégies sont désormais exercées de bout en bout sur la sortie
  émise.
- La même lecture d'énumération sert `@ZcrudField(persistAs:)` et toute valeur
  d'énumération re-émise dans un `ZFieldSpec`. Elle lit désormais le **dernier
  segment de l'accesseur qualifié** que l'analyse rend pour toute constante
  d'enum, ce qui la rend **insensible aux alias `const`**, aux préfixes d'import
  et à la forme d'écriture (mesuré sur les quatre stratégies et `persistAs`,
  écrits littéralement et derrière un alias).

### Modifié — durcissement cassant

- **Un champ non annoté de type non sérialisable est désormais un échec de
  build.** Seuls les champs annotés sont sérialisés ; un tel champ disparaissait
  du document persisté sans aucun signal. Le build le refuse, nomme **tous** les
  champs fautifs du modèle en une passe (champs déclarés **et** champs concrets
  hérités d'une super-classe ou d'un mixin hors SDK) et cite les trois remèdes :
  donner au champ un type sérialisable et l'annoter `@ZcrudField` ; annoter le
  type `@ZcrudModel` **et** le champ `@ZcrudField` ; ou déclarer l'exclusion
  avec `@ZcrudIgnore`.

  **Qui est concerné.** Tout modèle `@ZcrudModel` portant un champ **public**
  non annoté dont le type n'est ni scalaire supporté, ni `enum`, ni classe
  `@ZcrudModel` — typiquement un canal sérialisé à la main (`source`,
  `learning`…) ou un sous-objet métier oublié. **Ne sont PAS concernés** (exemptés
  d'office) : les champs **privés** (`_xxx`), les slots AD-4 d'une classe
  `ZExtensible` (`extension`, `extra`) — déjà couverts par le contrat de factory
  de domaine et le garde d'extensibilité —, les champs statiques, et tout champ
  non annoté de type **sérialisable** (contrat inchangé : ignoré en silence).
  Mesure sur le monorepo après exemptions : 4 champs sur 21 modèles ont réclamé
  `@ZcrudIgnore`, tous des canaux hors-codegen déjà documentés comme tels.
- **`@ZcrudIgnore` combiné à `@ZcrudField` ou `@ZcrudId` sur le même champ est
  un échec de build** : les deux déclarations se contredisent, aucune résolution
  silencieuse n'est appliquée.

### Ajouté

- **Prise en charge de `@ZcrudIgnore`** (nouvelle annotation de
  `zcrud_annotations`) : lève l'échec ci-dessus sans rien ajouter au code émis.
  `@ZcrudIgnore` signifie « cette donnée n'est **pas** écrite par le codegen » —
  un canal manuel (`fromMap`/`toMap` de domaine, slot `extra`) reste à la charge
  de l'auteur si la donnée doit vivre dans le document.
- Une valeur de `fieldRename` non reconnue — ou illisible sous résolution
  dégradée — est un **échec de build explicite**, jamais un repli muet sur
  `snake`.

### Documentation

- La dartdoc du générateur explique désormais, au point d'usage, pourquoi les
  clés de synchronisation `updated_at` / `is_deleted` sont **omises quand elles
  sont nulles** alors qu'une clé métier comme `created_at` est toujours émise —
  l'asymétrie tient au statut de la clé, pas au type du champ.
- Avertissement explicite : le `toMap()` généré émet **toute** date en `String`
  ISO-8601 ; le format natif du backend est appliqué par le **repository** via
  `$XxxTimestampFields`. Un moteur de persistance qui appelle `toMap()`
  directement écrira des `String` là où le parc attend le type natif.

#### Migration

Un modèle qui déclarait `fieldRename` autrement que `snake` voit ses clés
persistées **changer** à la prochaine génération — c'est la correction attendue,
mais elle doit être rapprochée du format réellement présent sur disque avant
d'être déployée. Un modèle portant des champs **publics** non annotés de type
non sérialisable (hors exemptions ci-dessus) devra les qualifier
(`@ZcrudField`, `@ZcrudModel` sur le type **et** `@ZcrudField` sur le champ, ou
`@ZcrudIgnore`) : le build les nomme tous en une passe. Un champ qui portait
`@ZcrudIgnore` **et** `@ZcrudField`/`@ZcrudId` doit perdre l'une des deux
annotations.

### ⚠️ BREAKING — every `@ZcrudModel` class must now declare a domain `fromMap`

**What changed.** The generated registrar now wires the **domain** decoder
(`fromMap: Xxx.fromMap`) instead of the **codegen** one (`fromMap: _$XxxFromMap`).

**Why.** `_$XxxFromMap` only knows `@ZcrudField`-annotated fields. It never
populates the *out-of-codegen* channels — `extra` (the AD-4 escape hatch),
`extension`, `source`. Any store wired on `registry.decode`
(`FirebaseZRepositoryImpl.fromRegistry`) therefore **destroyed every business key
unknown to the schema, silently and irreversibly, on each read → write cycle**
(debt `DW-ES14-1`).

**Migration.** Declare `Xxx.fromMap(Map<String, dynamic> map)` — a **factory**
*or* a **static method**; extra **optional** parameters are allowed
(`extensionParser`, `sourceRegistry`…).

- Class **without** an `extra` slot (plain value object): a bare delegation is
  correct and remains legal.

  ```dart
  factory ZChoice.fromMap(Map<String, dynamic> map) => _$ZChoiceFromMap(map);
  ```

- Class **`ZExtensible`** (it has an `extra` slot): a bare delegation is
  **REJECTED AT BUILD TIME** — it *is* the defect above. Populate `extra` on the
  way in, and re-emit it on the way out (the **generated** `toMap()` does *not*
  spread `extra`):

  ```dart
  factory ZFlashcard.fromMap(Map<String, dynamic> map) {
    final base = _$ZFlashcardFromMap(map);            // schema fields
    return ZFlashcard(/* …copied from `base`… */, extra: _extraFrom(map));
  }

  Map<String, dynamic> toMap() =>
      {...extra, ...ZFlashcardZcrud(this).toMap()};   // instance toMap
  ```

### Enforcement — three machine nets (no net relies on prose)

1. **Build** — missing decoder, or a signature no `Map<String, dynamic>` can be
   assigned to ⇒ `InvalidGenerationSourceError`.
2. **Build** — a `ZExtensible` class whose `fromMap` **bare-delegates** to
   `_$XxxFromMap` ⇒ `InvalidGenerationSourceError`. Detected on the constructor
   **body AST** (`package:analyzer`), never by regex.
3. **Runtime** — the emitted `registerXxx` of a `ZExtensible` class carries an
   **executable guard**: it decodes a probe carrying an out-of-schema key and
   requires it to **survive the full round-trip** (`fromMap` *and* `toMap`),
   raising an explicit `StateError` at registration. It is deliberately **not**
   behind `assert` — the net must hold in release, where the data loss is
   permanent.

### Fixed

- Signature validation compared the **display string**
  (`getDisplayString() == 'Map<String, dynamic>'`), so it wrongly **rejected**
  legal, assignable decoders: `Map<String, Object?>`, a `typedef` alias, an
  import-prefixed form. It now compares **types** via the analyzer `TypeSystem`.
- A `fromMap` declared as a **static method** (a perfectly valid tear-off) was
  rejected with a message claiming no `fromMap` existed at all. Static decoders
  are now accepted.

## 0.1.0

Initial public release.

- The `build_runner` code generator for zcrud.
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
