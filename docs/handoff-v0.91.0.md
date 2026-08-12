# Handoff **v0.91.0** — `omitNullFields`, résolution non bornée du registre, parité des écrans segmentés

> **Tag à épingler : `v0.91.0`** — répond à deux CR DODLP du 2026-08-12 :
> `cr-firestore-omit-null-fields` et `cr-list-onglets-suppression-grille`.
> Paquets porteurs : **`zcrud_firestore`**, **`zcrud_core`**. Release **strictement
> additive** : tous les défauts restent inchangés (`omitNullFields: false`, aucune API
> existante modifiée).

---

## 1. CR firestore — clés nulles en `merge: true` : **`omitNullFields` (option 1)**

`FirebaseZRepositoryImpl` (et `fromRegistry`) accepte `omitNullFields: true`, symétrique
de `timestampFields` : les clés à `null` du **corps** de l'entité sont retirées avant
écriture, **récursivement** (sous-maps, maps dans les listes ; les éléments de liste nuls
sont conservés — c'est écrit en dartdoc). Deux protections délibérées :

- le retrait s'applique au **corps seul**, avant la fusion `ZSyncMeta` — les clés de sync
  (`is_deleted`, `updated_at`) que le repository écrit délibérément, y compris le
  `updated_at` verbatim `null`, ne sont **jamais** touchées ;
- le défaut est `false` : aucun consommateur actuel ne change de comportement.

Le piège lui-même est désormais écrit aux trois points d'usage (`omitNullFields`,
`ZcrudRegistry.encode`, `encodeOf`) : en `merge: true`, clé absente = valeur distante
intacte, clé à `null` = valeur distante **effacée**.

**Hôte ayant compensé (votre cas)** : votre condition de bascule —
`.compact(true).cast<String, dynamic>()` en aval de `encode` — devient redondante avec
`omitNullFields: true` posé sur le repository. Les deux formes coexistent sans double
effet (retirer deux fois les nulls est idempotent), donc le retrait de votre `compact`
peut se faire à votre rythme, arbitré par votre garde d'équivalence — qui a, au passage,
exactement rempli son office.

## 2. CR firestore, constat 2 — `kindOf<T>` inappelable d'un générique non borné : **corrigé**

Vous aviez raison sur le paradoxe, et la borne n'était pas la fautive. Deux résolutions
s'ajoutent au registre, mêmes contrats que `kindOf` (`null` si absent, `StateError`
actionnable si ambigu) :

- **`kindOfType(Type type)`** — l'appelant passe `T` réifié ou `runtimeType` ;
- **`kindOfInstance(Object value)`** — le cas réel d'un `toMap<T>(T? item)` ; attention à
  la limite documentée : `runtimeType` d'une instance ne rend pas les types génériques.

`kindOf<T>()` délègue désormais à `kindOfType(T)` — une seule source de vérité. Votre
bascule suspendue peut reprendre : depuis `toMap<T>(T? item)`, `item == null ? … :
registry.kindOfInstance(item)` compile et résout.

### Constats annexes de votre CR — position zcrud

- **`fromMap({})` qui lève sur un modèle manuel** : le filet AD-10 (désérialisation
  défensive) est une propriété du **code généré** ; l'étendre aux modèles manuels par une
  garde d'exécution reviendrait à promettre un contrat que zcrud ne contrôle pas. La voie
  est la migration au codegen (vos 48 kinds y sont presque) — chaque modèle migré gagne le
  filet mécaniquement. Non retenu, assumé.
- **Encodage non déterministe (`id ?? randomId()`)** : défaut de modèle hôte, hors
  contrat zcrud — votre verrou « l'encodage est déterministe » est la bonne réponse, et
  une bonne pratique à propager.

## 3. CR liste — point 1 (onglets) : **l'existant couvrait déjà l'essentiel**

Correction amicale du constat « `DynamicList` n'a aucune notion d'onglet » :
**`ZTabbedList` + `ZListTab.category(labelKey, filters, buildList)` existent** (exportés
par le barrel de `zcrud_core`) — libellé l10n, filtres de catégorie non écrasables par la
recherche utilisateur, état préservé par onglet (keep-alive). Votre écran
`convocations_bmd_screen` (3 onglets à filtres enum) est couvert **tel quel** par l'API
existante.

Ce qui manquait réellement — et qui est livré : le **contexte de création par onglet**.
`ZListTab` (et `.category`) porte désormais `defaultItemBuilder` (`Object? Function()?`),
lu par le geste de création de l'onglet courant. `operations_screen` (5 onglets, un
`defaultItem` par `OperationType`) s'écrit :

```dart
ZListTab.category(
  labelKey: 'operations.loading',
  filters: [ZFilter.equals('type', 'loading')],
  defaultItemBuilder: () => Operation.empty(type: OperationType.loading),
  buildList: (context, categoryFilters) => /* DynamicList branchée sur les filtres */,
)
```

## 4. CR liste — points 2 à 4

- **Corbeille sans repository** : `ZRowAction.softDeleteWith(handler)` /
  `restoreWith(handler)` — l'écriture est déléguée à l'app (vos streams legacy), l'ACL
  appliquée **exactement** comme pour les fabriques à repository, qui restent le
  raccourci nominal. Limite dite franchement : la **partition** vivants/supprimés
  (`deletedScope`) reste portée par `ZListController` + `ZRepository` — en cohabitation,
  partitionnez côté streams et alimentez les lignes directement.
- **Clé éphémère** : `ZListRow.ephemeralKey(index)` + `isEphemeralKey(id)` — le cœur
  fabrique la clé, plus chaque consommateur. **Hôte ayant contourné** : votre coquille
  qui fabrique `__ephemere_$index` doit **retirer** sa fabrication au profit du helper
  (format `__ephemeral_<index>` — une lettre d'écart, transitoire, aucun impact de
  données persistées).
- **Grille neutre** : `ZListGridLayout` — grille de cartes responsive rendue
  `GridView.builder` dans le cœur (virtualisée, RTL, thème injecté, sans Syncfusion).
  Vos 9 écrans BMD en grille de cartes n'ont plus besoin de `zcrud_list`.
- **`deriveColumns`** documente désormais l'escamotage silencieux des champs hors liste
  blanche tabulaire, et son contournement (`ZColumnPolicy.forceInclude`).

Vos trois écrans hors périmètre (`ship_handlings`, `bmd_parametres`, `ship_documents`)
sont bien hors sujet zcrud — rien à signaler.

## 5. État des vérifications

`melos run analyze` RC=0, `melos run verify` RC=0 (14 gates), tests rejoués depuis le
dossier de chaque paquet touché, workstreams au repos : core **1791**, firestore **803** —
tous verts. Neuf injections R3 au total sur les deux lots (contrats par défaut, récursion,
méta de sync, ambiguïté du registre, contexte de création, ACL des callbacks, clé
éphémère, responsivité) — toutes rouges **par assertion**, restaurations par copie
vérifiées par sha256, résidus prouvés absents par grep négatif.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.
