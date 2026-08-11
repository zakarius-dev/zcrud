# zcrud_generator

Générateur `build_runner` du moteur codegen zcrud — lit `@ZcrudModel`
statiquement et émet la (dé)sérialisation, le `ZFieldSpec[]` et
l'enregistrement au registre (invariant AD-3).

## Aperçu {#apercu}

`zcrud_generator` est le seul point de la chaîne où les modèles annotés par
`zcrud_annotations` (`@ZcrudModel`, `@ZcrudField`, `@ZcrudId`) sont **lus**.
Il produit, dans le `part '<file>.g.dart'` de chaque bibliothèque, quatre
artefacts :

1. `_$XxxFromMap` — reconstruction défensive du modèle depuis une
   `Map<String, dynamic>` ;
2. l'extension `XxxZcrud` — `toMap()` (snake_case, enum `.name` camelCase,
   dates ISO-8601) et `copyWith()` à sentinelle ;
3. `$XxxFieldSpecs` — le `List<ZFieldSpec>` projeté 1:1 des `@ZcrudField`,
   avec inférence de type quand `type` n'est pas explicite ;
4. `registerXxx(ZcrudRegistry)` — le câblage `kind → (fromMap, toMap,
   fieldSpecs)`.

La toolchain codegen (`build`, `source_gen`, `analyzer`) est confinée à ce
paquet, en `dev_dependency` (invariant AD-1) : elle ne fuit jamais dans le
build d'une application consommatrice.

**Utilisez ce paquet** en `dev_dependency`, dès qu'un modèle de votre
application porte `@ZcrudModel`. **N'utilisez pas ce paquet** en
`dependency` (runtime) : il n'a rien à offrir hors du `build_runner`, et
tirerait `analyzer`/`build` dans votre application.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`. Déclarez-le en `dev_dependency`, aux côtés de
`build_runner`.

## Démarrage rapide {#demarrage-rapide}

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.5.0
  zcrud_generator: ^0.1.0
```

```bash
# Régénère les compagnons *.g.dart :
dart run build_runner build --delete-conflicting-outputs
```

## Concepts clés {#concepts-cles}

- **Le modèle est la source unique de vérité (invariant [AD-3](../../docs/site/concepts/invariants.md#ad-3))** —
  `zcrud_generator` ne fait que **projeter** ce que `@ZcrudModel`/`@ZcrudField`
  déclarent ; il n'invente aucune règle de schéma. Un type de champ non
  (dé)sérialisable (ni scalaire, ni enum, ni `@ZcrudModel` annoté) est un
  **échec de build explicite** (`InvalidGenerationSourceError`), jamais un
  cast silencieux.
- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  `_$XxxFromMap` ne jette jamais : champ absent → `defaultValue`/valeur sûre,
  enum inconnu → repli (jamais `byName` nu), sous-objet corrompu → `null`
  filtrable, sans jamais faire échouer le parent.
- **`persistAs: ZPersistAs.timestamp` et l'artefact neutre** — un champ date
  hinté fait collecter sa clé persistée dans `$XxxTimestampFields`
  (`Set<String>` pur-Dart) ; c'est `zcrud_firestore`, seul, qui traduit cette
  métadonnée en `Timestamp` natif (invariant [AD-5](../../docs/site/concepts/invariants.md#ad-5)).

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `zcrudModelBuilder` (`builder.dart`) | Fabrique de `Builder` référencée par `build.yaml` — point d'entrée `build_runner`. |
| `ZGeneratorApi` | Marqueur de version de l'API publique du paquet. |

L'implémentation du générateur (`ZcrudModelGenerator`, sous `lib/src/`) n'est
pas destinée à un import direct : le point d'entrée public est
`package:zcrud_generator/builder.dart`, câblé par `build.yaml`.

## Cas limites et invariants {#cas-limites}

### Contrat obligatoire — un décodeur de domaine `fromMap`

Toute classe `@ZcrudModel` **doit** déclarer
`Xxx.fromMap(Map<String, dynamic> map)` — factory ou méthode statique, avec
autant de paramètres optionnels supplémentaires que nécessaire. C'est ce
décodeur que le registrar généré câble (`fromMap: Xxx.fromMap`), **jamais**
`_$XxxFromMap`. Son absence est un **échec de build**, jamais un repli
silencieux :

```dart
@ZcrudModel(kind: 'article')
class Article {
  // Factory OU méthode statique ; des paramètres optionnels supplémentaires
  // sont autorisés.
  factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);
  // ...
}
```

**Si la classe est `ZExtensible`** (elle porte un slot `extra`, invariant
[AD-4](../../docs/site/concepts/invariants.md#ad-4)), cette délégation nue
est **rejetée au build**. `_$XxxFromMap` ne connaît que les champs
`@ZcrudField` et laisse `extra` **vide** — un store câblé sur
`registry.decode` effacerait alors toute clé métier hors schéma, à chaque
cycle lecture → écriture, irréversiblement. La factory doit peupler `extra`,
et le `toMap()` d'instance doit le réémettre (le `toMap()` **généré** n'étale
pas `extra`) :

```dart
@ZcrudModel(kind: 'flashcard')
class ZFlashcard with ZExtensible {
  factory ZFlashcard.fromMap(Map<String, dynamic> map) {
    final base = _$ZFlashcardFromMap(map); // champs du schéma
    return ZFlashcard(/* …champs recopiés depuis `base`… */,
        extra: _extraFrom(map)); // clés hors schéma
  }

  /// Masque le `toMap()` généré, qui n'étale pas `extra`.
  Map<String, dynamic> toMap() => {...extra, ...ZFlashcardZcrud(this).toMap()};

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardFieldSpecs) spec.name,
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      Map<String, dynamic>.unmodifiable({
        for (final e in map.entries)
          if (!_reservedKeys.contains(e.key)) e.key: e.value,
      });
}
```

Le `registerZFlashcard` émis porte en plus un **garde exécutoire** : il
décode une sonde portant une clé hors schéma et exige qu'elle survive au
round-trip complet (`fromMap` **et** `toMap`), levant un `StateError`
explicite sinon. Ce garde n'est **pas** sous `assert` — il tient en release,
là où la perte serait définitive, et c'est le seul filet qui suive un paquet
publié chez un consommateur externe.

### Autres cas limites

- **Collision de clé persistée** — deux champs qui se résolvent à la même
  clé (après renommage) sont un échec de build ; désambiguïser via
  `@ZcrudField(name:)`.
- **Renommage de champ (`fieldRename`)** — `snake` (défaut, persistance
  snake_case), `none`, `kebab`, `pascal` ; un `@ZcrudField.name` explicite
  prime toujours sur la stratégie de classe.
- **`copyWith` à sentinelle** — un paramètre omis préserve la valeur
  courante ; `null` explicite la remet à `null` (distinction reset vs. non
  fourni).

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_generator.md`](../../docs/site/paquets/zcrud_generator.md)
- `zcrud_annotations` — les annotations lues par ce générateur.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
