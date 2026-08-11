# zcrud_dnd

Implémentation opt-in du port `ZDropRegionRenderer` de `zcrud_core`, pour
recevoir des dépôts **natifs** — fichiers, images, textes, adresses venus du
système ou d'une autre application.

## Aperçu {#apercu}

`zcrud_dnd` est un satellite **opt-in** : il ne contient qu'un adaptateur du
port `ZDropRegionRenderer` déclaré dans `zcrud_core`, adossé au paquet tiers
`super_drag_and_drop`. « Natif » désigne ici l'échange de données avec le
**système** ou une **autre application** (déposer un fichier de
l'explorateur sur une carte, glisser un contenu depuis un navigateur) — à ne
pas confondre avec le réordonnancement **interne** d'une collection, qui est
le rôle de `zcrud_reorder`. Les deux capacités sont délibérément séparées :
les mélanger imposerait une chaîne de compilation native aux hôtes qui
veulent seulement réordonner.

`super_drag_and_drop` embarque du code natif et télécharge des binaires
précompilés à la construction. zcrud étant distribué en dépendance git — sans
étape de publication qui absorberait ce coût — cette contrainte s'impose au
build de toute application consommatrice qui ajoute ce paquet. C'est pourquoi
la capacité vit à part, en satellite séparé.

**Utilisez ce paquet** si votre application doit recevoir des dépôts
d'origine système (fichiers, images, adresses, texte). **N'utilisez pas ce
paquet** pour réordonner une liste interne (`zcrud_reorder`) ni si votre
application n'a besoin d'aucun dépôt : le port a un défaut
zéro-dépendance (`ZNoDropRegionRenderer`, dans `zcrud_core`) qui rend la zone
inchangée et n'accepte aucun dépôt.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_dnd/zcrud_dnd.dart';

Widget buildApp(Widget child) {
  return ZcrudScope(
    dropRegionRenderer: const ZNativeDropRegionRenderer(),
    child: child,
  );
}
```

## Concepts clés {#concepts-cles}

- **Port neutre, adaptateur confiné** — `zcrud_core` ne connaît que
  `ZDropRegionRenderer`, `ZDropRegionRequest`, `ZDroppedItem` et `ZDropKind` ;
  aucun type de `super_drag_and_drop`/`super_clipboard` n'apparaît dans une
  signature publique de ce paquet. L'échange avec le tiers est confiné à
  `ZNativeDropRegionRenderer` et à son adaptateur privé.
- **Robustesse défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  la réception d'un dépôt ne lève jamais : un format illisible, un nom ou un
  texte dont la lecture échoue dégradent le champ concerné en `null`,
  l'élément reste remonté (au pire en `ZDropKind.unknown`). Seule la lecture
  **explicite** des octets (`ZDroppedItem.readBytes`) peut faire échouer sa
  future avec une [ZDropReadFailure].
- **Lecture paresseuse des octets** — construire la liste des éléments
  déposés ne matérialise aucun octet ; `readBytes` n'est invoquée que si, et
  quand, l'hôte le décide explicitement.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZNativeDropRegionRenderer` | Implémentation native du port `ZDropRegionRenderer`, adossée à `super_drag_and_drop`. |
| `ZDropItemSource` | Couture neutre confinant le paquet tiers, utilisée par les tests sans engine natif. |
| `ZDropReadFailure` | Échec porté par la future de `ZDroppedItem.readBytes`, jamais pendant la réception du dépôt. |
| `zBuildDroppedItems` | Construit les éléments déposés neutres à partir de sources, en filtrant par natures acceptées. |
| `zCandidateDropKinds` / `zSelectDropKind` | Déduisent les natures plausibles d'un élément et retiennent la plus prioritaire acceptée. |
| `zMimeTypeForFormats` | Extrait un type MIME plausible parmi les identifiants de format natifs. |
| `kZDropKindPriority` | Ordre de préférence entre natures quand plusieurs sont plausibles pour un même élément. |

## Cas limites et invariants {#cas-limites}

- Un élément dont aucune nature candidate n'est acceptée est **ignoré**,
  jamais signalé en erreur.
- Un dépôt entièrement hors du périmètre accepté est ignoré en silence — le
  callback `onDrop` n'est pas appelé pour une liste vide.
- Aucune affordance visuelle n'est rendue par ce paquet : le contenu passé en
  `request.child` est rendu inchangé, le survol est signalé par
  `request.onHoverChanged` pour que l'hôte le peigne avec son propre thème
  (aucune couleur codée en dur, correction RTL garantie car aucune géométrie
  directionnelle n'est introduite).

## Voir aussi {#voir-aussi}

- [zcrud_reorder](../zcrud_reorder/README.md) — réordonnancement interne
  d'une collection, capacité distincte de ce paquet.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
