# Étude CR-IFFD-52 — rendu par défaut ET listes ordonnées

**Statut : tranchée et implémentée** (voies typées `ZStudyToolsSectionSpec.flashcards`
/ `.mindmaps` / `.exams`). Document court et factuel, comme demandé par la CR.

## La question

> Comment une application obtient-elle le rendu par défaut ET l'ordre
> utilisateur, sans que le socle renonce à l'invariant qui protège le glisser ?

L'invariant en jeu : `onReorder != null ⇒ itemIds != null && itemIds.length ==
itemCount` (`z_study_tools_section_spec.dart`, assert du constructeur
principal). Il protège d'un défaut mesuré et fermé (D1/R3,
`ZFlashcardListView`) : une carte **éphémère** (`id == null`) fait diverger
l'espace d'indices affiché de l'espace persistable — un glisser déplacerait
silencieusement la mauvaise carte.

## Options considérées

1. **Statu quo** (voie « widget seul » : l'hôte pose `ZDefaultFlashcardCard` &
   co. dans son propre `itemBuilder` sur le constructeur principal). Débloque
   IFFD — mais rétablit exactement le travail que CR-47/48 supprimaient
   (compter, fabriquer le builder, résoudre balises et types). La promesse des
   voies typées ne tiendrait que pour les listes non ordonnées.
2. **Ouvrir `onReorder` + `itemIds` sur les voies typées** (la forme de la
   CR-51 retirée). Rejetée : `itemIds` fourni par l'hôte sur une voie qui
   détient déjà les données recrée l'**espace de divergence** (liste d'ids ≠
   liste de modèles — longueur, ordre, correspondance) que la voie typée
   existe précisément pour éliminer. La garde resterait **déclarative**.
3. **Ouvrir `onReorder` seul, `itemIds` DÉRIVÉ en interne** des modèles
   (`cards[i].id` / `maps[i].id` / `exams[i].id`). Retenue.

## La mesure qui tranche

Les voies typées **détiennent les données** : elles peuvent vérifier **sur
pièces** ce que le constructeur principal fait seulement **déclarer** par
l'hôte. La garde n'est pas assouplie, elle est renforcée :

- id **nul/vide** (item éphémère) avec `onReorder` fourni ⇒ **refus à la
  construction** (assert nommant l'index fautif et le remède) ; en release
  (AD-10, les asserts sont inactifs) le réordonnancement est **retiré**
  (`onReorder`/`itemIds` retombent à `null` ENSEMBLE — capacité absente AD-4)
  plutôt que de risquer de déplacer la mauvaise carte. Refuser à la
  construction est le plus sûr : le défaut est nommé au moment où il naît
  (chez le développeur), jamais découvert par l'utilisateur au premier
  glisser.
- id **dupliqué** ⇒ même refus. Constat fait pendant l'étude : le rendu mappe
  id→index (`itemIds.indexOf`) — deux ids identiques rendent le mapping
  ambigu, même classe de défaut que l'éphémère. La garde du constructeur
  principal ne le voit pas ; la dérivation le voit.
- vérifié par tests : le glisser **réel** (geste depuis la poignée) déplace la
  **bonne** carte sur les trois voies typées ; l'éphémère et le dupliqué sont
  refusés avec l'index dans le message
  (`test/presentation/cr_iffd52_typed_reorder_test.dart`).

## Interaction avec `railPreviewCount` (CR-49)

Un rail tronqué réordonnable n'a pas de sens : l'espace visible (N premiers)
≠ l'espace persistable (liste complète) — **le défaut original**. Tranché par
un assert : `onReorder` exige `axis: Axis.vertical` sur les voies typées ; le
rail horizontal n'est pas réordonnable (déjà documenté sur `axis`), et
`railPreviewCount` (qui exige l'horizontal) est donc transitivement
incompatible avec `onReorder`. En release, la dérivation retombe à `null`
hors axe vertical (même repli AD-10).

## Ce qui est délibérément REFUSÉ

- **`itemIds` fourni par l'hôte sur une voie typée** : le paramètre n'existe
  pas et une garde de source l'atteste (grep négatif dans
  `cr_iffd52_typed_reorder_test.dart`). Le fournir permettrait à l'hôte de
  « prouver » une identité que les modèles contredisent — la preuve doit
  venir des pièces, pas de la déclaration.
- **Assouplir l'assert du constructeur principal** : intact, au caractère
  près.
- **Réordonner le rail horizontal / un rail tronqué** : cf. ci-dessus.

## Ce que l'hôte gagne

`ZStudyToolsSectionSpec.flashcards(cards: …, onReorder: (o, n) => persist(…))`
suffit : rendu par défaut complet (CR-47/48/49) + glisser persistable, indices
dans la même convention `removeAt/insert` que le constructeur principal
(`zReorderIds`). Les libellés/glyphes de réordonnancement du principal
(`reorderHandleSemanticLabel`, `reorderHandleIcon`,
`reorderMoveBeforeSemanticLabel`, `reorderMoveAfterSemanticLabel`) sont
relayés à l'identique sur les trois voies typées.
