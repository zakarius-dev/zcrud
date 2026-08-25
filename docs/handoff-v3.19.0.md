# Handoff v3.19.0 — la poignée qui amorce vraiment le geste

> **Date** : 2026-08-25. **Portée** : `zcrud_core`, `zcrud_responsive`, `zcrud_reorder`.
> **Origine** : constat interne, né de la revue documentaire de la version précédente — aucune CR
> d'hôte ne l'avait signalé.

## 1. Les défauts

**① La poignée était morte sous tout renderer injecté.** La sous-liste rend une poignée visible en
tête de chaque ligne réordonnable. Sous le repli interne du cœur, elle amorce réellement le
glissement. Sous un renderer **injecté**, le socle l'enveloppait d'un `ReorderableDragStartListener`
du SDK — dont le `onPointerDown` appelle `list?.startItemDragReorder` : hors d'un
`SliverReorderableList`, c'est un **no-op silencieux**. Or aucun de nos deux satellites n'emploie ce
châssis. Conséquence absurde : injecter le renderer « supérieur » **dégradait** le geste — la
poignée devenait décorative et le glissement n'était plus atteignable qu'en appui long sur la ligne
entière, là où vivent des sous-champs éditables qui se disputent ce geste.

**② L'aperçu flotté faisait lever une ligne portant un sous-widget Material.** L'aperçu d'un
glissement vit dans l'`Overlay`, donc **hors** de l'arbre de l'écran : un `TextField` y perd son
ancêtre `Material` et lève `No Material widget found` (assertion de debug). Le cœur avait déjà
rencontré et corrigé ce défaut pour son propre repli ; `zcrud_responsive` l'avait toujours, sur les
deux chemins. Défaut **préexistant**, reproduit par sonde avant d'être corrigé.

## 2. Ce que le socle livre

**Un contrat de poignée sur le port**, à **implémentation par défaut identité** :

```dart
Widget buildDragHandle(BuildContext context, int index, Widget handle) => handle;
```

Le défaut identité est ce qui rend l'ajout additif (AD-4) : les trois implémentations connues — et
celles des hôtes — compilent et se comportent exactement comme avant. Trois garanties sont exigées
de qui l'honore : **ancrer et rien d'autre**, rendre la poignée **inchangée** (ni taille, ni marge,
ni sémantique ajoutée), **ne pas confisquer** le geste propre à l'item. Le mécanisme repose sur un
fait de structure : `itemBuilder` est appelé **par le renderer**, donc dans son propre sous-arbre —
un satellite y retrouve sa machinerie par un canal privé, sans qu'aucun de ses types n'entre dans le
port.

**Un canal d'habillage de l'aperçu flotté** : `ZReorderRenderRequest.dragPreviewWrapper`, nullable.
L'appelant — seul à connaître la surface dont ses sous-widgets ont besoin — habille l'aperçu sans
que le renderer ait à en dépendre. Non rempli : identité, rendu inchangé. La sous-liste définit
cette surface **une seule fois** et la sert aux deux bouts.

**`zcrud_responsive` honore le contrat** : glissement immédiat depuis la poignée, alimentant la
machinerie existante — même aperçu, même resynchronisation, même restauration sur échec. L'appui
long reste disponible. Le paquet n'importe toujours **pas** Material. Deux corrections nées de la
mesure : la donnée du glissement est la **position affichée** et non l'index reçu du port (les
confondre réordonnait la mauvaise ligne, en silence), et la zone sensible couvre désormais **toute**
la cible tactile — au défaut, seule sa part peinte l'était.

**`zcrud_reorder` ne l'honore pas, et c'est établi par la mesure.** Le châssis tiers n'expose aucun
déclencheur par poignée ; son écouteur, posé autour de la cellule entière, réinstalle son propre
reconnaisseur après tout déclencheur externe. Quatre renderers expérimentaux l'ont montré : la seule
configuration qui fonctionne exige de désactiver le glissement de l'item, donc de **confisquer** son
geste — ce que la garantie n°3 interdit — et repose sur un appel `dynamic` qui **blanchirait** le
lint interdisant les imports d'implémentation. Rejeté. Le défaut identité est conservé, sous
tripwire.

## 3. Ce qui change pour un hôte

- **Hôte passif : rien ne change — prouvé.** Les gardes d'inertie mesurent l'arbre et la géométrie,
  et la référence « avant-lot » a été rejouée contre le contenu du tag précédent, où elle est verte.
- 🔴 **Hôte qui a écrit son propre renderer sur `SliverReorderableList`/`ReorderableListView`** :
  sa poignée était vivante **par accident** — elle marchait parce que le socle présumait son
  châssis. Elle ne l'est plus tant qu'il n'écrit pas `buildDragHandle` (une ligne). C'est le seul
  delta cassant de cette version, et il ne concerne qu'un hôte ayant sa propre implémentation du
  port.
- 🔴 **Hôte qui compensait l'inertie de la poignée** (poignée doublée d'un déclencheur maison, ou
  masquée sous ce renderer) : **retirer la compensation**, sinon deux déclencheurs se disputent
  l'arène.
- **Hôte qui compensait l'aperçu** en enveloppant chaque cellule : il peut retirer sa compensation ;
  deux surfaces **opaques** cumulées resteraient visibles, c'est son choix.
- **Choix de renderer** : si l'exigence porte sur une poignée qui amorce le geste, prendre le
  renderer par défaut de `zcrud_responsive` — sous `zcrud_reorder`, la poignée reste une affordance
  et le glissement s'amorce à l'appui long. La voie non gestuelle (actions sémantiques par ligne)
  est offerte dans **tous** les cas : c'est elle qui rend la capacité atteignable au lecteur
  d'écran, quel que soit le renderer.

## 4. Vérification

Rejouée par l'orchestrateur, lots au repos.

| Contrôle | Résultat |
|---|---|
| `zcrud_core` | **2 536 tests verts** |
| `zcrud_responsive` | **128 tests verts** |
| `zcrud_reorder` | **34 tests verts** |
| Gardes inter-paquets (interchangeabilité, seam de renderer, grille d'étude) | vertes, rejouées **au repos** |
| `melos run generate` | SUCCESS — 0 `.g.dart` modifié |
| `melos run analyze` repo-wide | RC=0 |
| `melos run verify` (12 gates) | RC=0 |
| Balayage des **41 paquets**, chacun depuis son dossier | **40 verts** ; `zcrud_generator` rouge **environnemental** de signature inchangée (`Isolate.packageConfig` via `build_test`) |

**Discipline R3** : 4 + 11 + 5 + 10 injections selon les lots, toutes rouges **par assertion**,
restauration par copie, sha256 identiques, grep négatif montré. Trois campagnes ont trouvé une
**garde faible** et l'ont renforcée plutôt que d'assouplir l'injection : une garde aveugle à un
encart symétrique autour d'un enfant centré ; une garde paramétrée de telle sorte que ses deux cas
retombaient sur le même mode, laissant l'autre site inerte ; et une garde d'héritage de défaut qui
devait prouver qu'habiller une poignée ne la rend pas vivante.

## 5. Ce que la mesure a réfuté

Deux hypothèses de départ étaient **fausses**, et l'ont montré avant d'être livrées :

1. **`zcrud_reorder` n'avait pas le défaut d'aperçu.** Le châssis tiers habille déjà son aperçu d'un
   `Material`. Mieux : le point d'extension public qui aurait permis de relayer l'habillage de
   l'appelant **remplace** ce proxy au lieu de l'envelopper — le relayer aurait **retiré** cette
   surface chez tous les hôtes. Rien n'a été relayé ; un tripwire fige la propriété dont ce choix
   dépend.
2. **Le canal du satellite ne pouvait pas être posé où on le croyait.** Le contexte servi à
   `itemBuilder` était commun à toutes les cellules et situé **au-dessus** d'elles : un canal posé là
   serait resté invisible depuis la poignée.
