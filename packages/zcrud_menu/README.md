# zcrud_menu

Menus contextuels à **déclencheur et contenu découplés** pour zcrud, servis
en données plutôt qu'en widgets construits.

## Aperçu {#apercu}

`zcrud_menu` n'est pas un menu spécifique à un domaine : aucun type de sa
surface publique ne nomme une entité métier. Il sert indifféremment un item
de liste, une carte de contenu, une barre d'application ou un message de
conversation — parce que c'est le même geste : un déclencheur, des entrées
d'action déclarées en données, un rendu résolu par un port injectable.

L'hôte branche son propre package de menus derrière `ZMenuRenderer` ; sans
injection, `ZDefaultMenuRenderer` (Flutter/Material seul, zéro dépendance
tierce) reste pleinement fonctionnel.

**Utilisez ce paquet** pour tout menu contextuel d'action — liste, carte,
barre d'app, conversation — construit en données plutôt qu'en widget dur.
**N'utilisez pas ce paquet** dans `zcrud_core` : le cœur ne peut dépendre
d'aucun satellite (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)),
un menu qui y vit garde son rendu en dur tant que la couture n'y est pas
elle-même déplacée.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

Widget buildMenu(VoidCallback ouvrir, VoidCallback supprimer, bool peutSupprimer) {
  return ZActionMenu(
    trigger: ZMenuTrigger(icon: Icons.more_vert, semanticLabel: 'Plus d\'options'),
    entries: [
      ZMenuEntry(id: ZMenuEntryIds.open, label: 'Ouvrir', onSelected: ouvrir),
      // présente, désactivée, motif annoncé :
      ZMenuEntry(id: ZMenuEntryIds.edit, label: 'Éditer', disabledReason: 'Bientôt disponible'),
      // ni actionnable ni désactivée ⇒ absente :
      const ZMenuEntry(id: ZMenuEntryIds.share, label: '—'),
      // droit refusé ⇒ absente, sans traduction côté appelant :
      ZMenuEntry(
        id: ZMenuEntryIds.delete,
        label: 'Supprimer',
        permitted: peutSupprimer,
        onSelected: supprimer,
      ),
    ],
  );
}
```

## Concepts clés {#concepts-cles}

- **Trois états représentables (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  une entrée est actionnable (`onSelected` non nul), absente (les deux nuls)
  ou présente-mais-désactivée-avec-motif (`disabledReason` non nul,
  `onSelected` nul). `permitted: false` force l'absence quel que soit le
  reste. Le filtrage de la règle d'absence a un site unique
  (`zVisibleMenuEntries`), appliqué avant tout renderer — il est donc
  inopposable à un renderer injecté.
- **Déclencheur et contenu déclarés en données** — `ZMenuTrigger` et
  `ZMenuEntry` sont des data-class immuables, jamais des widgets construits :
  c'est ce qui permet à un `ZMenuRenderer` injecté de rendre le déclencheur
  autrement (appui long, clic droit, feuille modale) sans que l'appelant
  change d'un caractère.
- **Voie unique de sélection** — toute sélection passe par
  `ZMenuRequest.select`, jamais par `entry.onSelected` directement : un
  renderer (y compris un adaptateur tiers) ne peut ni exécuter une entrée
  désactivée, ni une entrée qu'il aurait fabriquée lui-même.
- **Chaîne de résolution totale** — `zResolveMenuRenderer` ne rend jamais
  `null` et ne lève jamais : paramètre explicite → `ZMenuScope` → repli
  `ZDefaultMenuRenderer`. Brancher ce paquet sans rien configurer ne change
  rien à ce qu'un hôte voit.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZActionMenu` | Point d'entrée unique : déclare entrées et déclencheur, délègue au renderer résolu. |
| `ZMenuEntry` / `ZMenuEntryIds` | Entrée de menu déclarée en données ; vocabulaire canonique d'identités. |
| `ZMenuTrigger` | Description immuable du déclencheur (glyphe ou widget). |
| `ZMenuRenderer` / `ZMenuRequest` | Port de rendu et sa requête neutre. |
| `ZDefaultMenuRenderer` | Repli zéro-dépendance, Material seul. |
| `ZMenuEntryTile` | Cellule d'entrée réutilisable, offerte aux présentations de contenu injectées. |
| `ZMenuScope` / `zResolveMenuRenderer` | Scope d'injection et chaîne de résolution totale du renderer. |

## Cas limites et invariants {#cas-limites}

- Une entrée désactivée reste **présente** dans le menu, jamais absente ni
  grisée sans motif — le silence seul est proscrit, la désactivation avec
  motif est un état de première classe.
- `ZMenuEntryTile.gridDelegate` borne `mainAxisExtent` par le bas à la cible
  tactile minimale : une disposition en grille qui l'écraserait signale une
  erreur de disposition en mode debug plutôt que de livrer silencieusement
  une cellule sous-dimensionnée (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13)).
- Une liste d'entrées vide sans contenu injecté rend un déclencheur
  **inerte**, jamais une surface fantôme ni une exception (invariant
  [AD-10](../../docs/site/concepts/invariants.md#ad-10)).
- Une exception levée par le renderer de l'hôte se propage : elle n'est
  jamais avalée par la chaîne de résolution.

## Voir aussi {#voir-aussi}

- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
