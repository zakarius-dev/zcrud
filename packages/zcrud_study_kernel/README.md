# zcrud_study_kernel

Noyau Dart pur d'étude de zcrud — dossiers, sessions et utilitaires
d'assiduité partagés, bornés par l'invariant AD-1 (aucune dépendance lourde,
seul `zcrud_core` en arête sortante).

## Aperçu {#apercu}

`zcrud_study_kernel` est le paquet **kernel** de la capacité d'étude, au
sens du patron [kernel/satellite](../../docs/site/concepts/architecture-hexagonale.md#le-patron-kernel-satellite) :
il porte les entités et les règles métier bas-niveau communes à tous les
satellites d'étude (`zcrud_document`, un futur satellite de flashcards,
de notes, de mindmaps…), sans aucune dépendance `flutter:`.

Ce paquet fournit :

- le **dossier d'organisation** — `ZStudyFolder` (hiérarchie 2 niveaux,
  rattachement inverse : le dossier ne liste jamais ses items) et la
  primitive pure `validatePlacement` ;
- la **sélection de session** — `ZStudySessionConfig` (filtres persistables)
  et `ZStudySessionSelector`, qui opèrent sur le port neutre
  `ZSessionCandidate` implémenté par chaque satellite ;
- le **dépôt CRUD offline-first générique** — `ZStudyRepository<T>`, qui
  compose avec `ZSyncableRepository` du cœur pour ajouter un hook de
  validation métier garanti exécuté avant toute persistance ;
- les **tags**, la **flamme d'assiduité**, l'**ordre de contenu personnel**
  d'un dossier, le **podcast content-addressed** et l'**agrégation « rythme
  du jour »** — chacun avec sa désérialisation défensive ;
- des **utilitaires domaine purs partagés** — palette de couleurs
  déterministe, tri à ordre personnel, normalisation de titre de tag —
  réutilisables par tout satellite sans dupliquer la logique.

**Utilisez ce paquet** si vous écrivez un nouveau satellite d'étude qui a
besoin du dossier, de la sélection de session ou des utilitaires partagés,
ou si vous traitez des données d'étude hors Flutter (migration, script,
test unitaire). **N'utilisez pas ce paquet directement** pour construire une
interface — passez par un satellite qui assemble ce kernel avec un
contrôleur réactif et un rendu.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  // Un dossier racine, puis validation d'un placement en sous-dossier.
  const folder = ZStudyFolder(title: 'Droit douanier');
  final placement = validatePlacement(parentId: null);
  assert(placement.isRight());

  // Sélection de session : filtre par dossier + type, plafonnée à 20 cartes.
  const config = ZStudySessionConfig(
    folderId: 'folder-1',
    types: <String>['multipleChoice'],
    count: 20,
  );
  final selector = ZStudySessionSelector(config);
  final selection = selector.selectFrom(<_Card>[
    _Card(folderId: 'folder-1', typeKey: 'multipleChoice'),
    _Card(folderId: 'folder-2', typeKey: 'multipleChoice'),
  ]);
  assert(selection.length == 1);
}

/// Un satellite implémente ZSessionCandidate sur son entité concrète.
class _Card implements ZSessionCandidate {
  const _Card({required this.folderId, required this.typeKey});

  @override
  final String? folderId;
  @override
  String? get subFolderId => null;
  @override
  List<String> get tagIds => const <String>[];
  @override
  final String typeKey;
}
```

## Concepts clés {#concepts-cles}

- **Kernel Dart pur** — ce paquet n'importe ni `flutter:`, ni `dart:ui`, ni
  aucun autre paquet `zcrud_*` que `zcrud_core` et `zcrud_annotations`
  (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)). Sa suite
  tourne sous `dart test`. Voir
  [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md).
- **Ports neutres plutôt que dépendances de satellite** — `ZSessionCandidate`,
  `ZApproachingExam`, `ZStudyDocumentRef`, `ZStudyNoteRef` sont des
  `abstract interface class` définies ici et implémentées côté satellite :
  le kernel remonte la logique de sélection/agrégation sans jamais connaître
  un type concret de carte, d'examen, de document ou de note.
- **Extension par composition, jamais par héritage (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  les familles ouvertes (`ZDailyStudyTask`) utilisent un discriminant `String
  kind` plutôt qu'un `sealed`, pour qu'un satellite ajoute une variante sans
  modifier le kernel. `colorKey`, `formatKey` et les types filtrants sont des
  chaînes opaques, jamais des enums fermés.
- **Désérialisation totale, jamais levée (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  chaque `fromMap`/`fromJson` de ce paquet rend un résultat même sur une
  entrée vide, corrompue ou de mauvais type : un enum inconnu retombe sur sa
  première constante déclarée, un compteur négatif est planché à zéro, une
  date illisible devient `null`.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Dossier et hiérarchie** | |
| `ZStudyFolder` | Dossier d'organisation multi-type, rattachement inverse. |
| `validatePlacement` | Primitive pure validant la hiérarchie 2 niveaux max. |
| **Session** | |
| `ZStudySessionConfig` / `ZReviewMode` | Filtres de session persistables et modes de révision. |
| `ZSessionCandidate` | Port neutre implémenté par les entités d'étude des satellites. |
| `ZStudySessionSelector` | Sélection pure de candidats à partir d'une config. |
| `ZStudySessionResult` | Value-object du résultat d'une session (mode, total, correct, qualités). |
| **Dépôt** | |
| `ZStudyRepository<T>` | Port CRUD offline-first générique à hook de validation métier. |
| **Tags** | |
| `ZFlashcardTag` / `ZSuggestedTag` | Tag first-class à identité propre ; suggestion éphémère par un port IA. |
| `normalizeTagTitle` / `dedupeByNormalizedTitle` | Normalisation et dédoublonnage de titre de tag. |
| `orphanTagIds` | Détection des références de tag orphelines. |
| **Couleur et ordre** | |
| `ZColorPalette` / `remapColorKey` / `zFnv1a32` | Registre de `colorKey` borné et remap déterministe. |
| `applyOrder` / `ZUnorderedPlacement` | Tri stable à ordre personnel partiel. |
| `ZFolderContentsOrder` / `zSectionKey` | Ordre de contenu personnel d'un dossier, par section. |
| **Assiduité** | |
| `ZStudyStreak` / `zAdvanceStreak` / `ZStreakOutcome` | Flamme d'assiduité et son avancement pur, horloge paramétrée. |
| **Podcast et rythme du jour** | |
| `ZStudyPodcast` / `ZPodcastMode` / `ZPodcastStatus` / `ZPodcastFreshness` | Podcast généré content-addressed et son cycle de vie. |
| `aggregateDailyStudyTasks` / `ZDailyStudyTask` / `ZApproachingExam` | Vue « rythme du jour » (cartes dues + examens approchants). |
| **Cascade et références neutres** | |
| `ZCascadeRegistry` / `ZCascadeEdge` | Registre déclaratif de cascade de suppression parent→enfant. |
| `ZStudyDocumentRef` / `ZStudyNoteRef` | Références neutres d'un document/d'une note pour le socle de présentation. |

## Cas limites et invariants {#cas-limites}

- **Un enum inconnu retombe sur sa première constante déclarée** — le
  générateur zcrud décode un enum par nom et, pour un champ non-nullable
  sans valeur par défaut, son repli est `T.values.first`. L'ordre de
  déclaration est donc normatif sur `ZReviewMode`, `ZPodcastStatus`,
  `ZPodcastMode`, `ZPodcastSourceKind` : le réordonner change silencieusement
  le comportement défensif.
- **Aucune couleur concrète dans le kernel** — `ZColorPalette` et
  `remapColorKey` ne manipulent que des `String` symboliques ; la résolution
  `colorKey → Color` est un seam de présentation injecté côté `zcrud_core`
  (`ZcrudScope.colorKeyResolver`).
- **Le hash déterministe est FNV-1a, jamais un hash cryptographique** —
  `zFnv1a32` préserve la fermeture transitive minimale du kernel (`{zcrud_core,
  zcrud_annotations}`) ; la multiplication interne est délibérément
  décomposée en deux moitiés de 16 bits pour rester identique sous
  compilation web.
- **La flamme d'assiduité compare des jours civils, jamais des durées** —
  `zAdvanceStreak` ne fait aucune arithmétique de `Duration` ; l'écart entre
  deux jours est une soustraction d'entiers de calendrier, insensible aux
  changements d'heure.
- **Aucun horodatage de synchronisation dans les entités** — `ZStudyFolder`,
  `ZFlashcardTag`, `ZFolderContentsOrder`, `ZStudyPodcast`, `ZStudyStreak`
  ne déclarent ni `updatedAt` ni `isDeleted` inline ; ces clés vivent
  hors-entité (`ZSyncMeta`).

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_study_kernel.md`](../../docs/site/paquets/zcrud_study_kernel.md)
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches, ports et patron kernel/satellite.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_document` — satellite qui dépend de ce kernel pour le dossier et la palette.
- `zcrud_core` — seule dépendance `zcrud_*` de ce paquet (surface pur-Dart).

## Licence {#licence}

MIT — voir la racine du dépôt.
