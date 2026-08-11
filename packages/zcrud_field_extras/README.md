# zcrud_field_extras

Satellite **champs spécialisés** de zcrud : PIN/OTP, autocomplétion et table
éditable, servis par le `ZWidgetRegistry` du cœur.

## Aperçu {#apercu}

`zcrud_field_extras` enregistre trois widgets d'édition riches dans le
`ZWidgetRegistry` de `zcrud_core`, sous des `kind` alignés sur les noms
d'`EditionFieldType` que le dispatcher du cœur résout automatiquement :

- **PIN / OTP** (`ZPinFieldWidget`, `kind` `'pin'`) — segments via `pinput`,
  seule dépendance lourde du paquet, confinée à l'implémentation ;
- **Autocomplétion** (`ZAutocompleteFieldWidget`, `kind` `'autocomplete'`) —
  widget natif Flutter `Autocomplete`, sans dépendance tierce ;
- **Table éditable** (`ZEditableTableFieldWidget`, `kind` `'editableTable'`) —
  virtualisée (`ListView.builder`), édition **en mémoire uniquement** (voir
  cas limites).

Ce paquet ne modifie jamais `zcrud_core` : l'enrôlement est **explicite**, au
bootstrap du binding ou de l'application — jamais un effet de bord d'import.
Sans enrôlement, ces trois types de champ dégradent proprement en
`ZUnsupportedFieldWidget`, jamais en crash.

**Utilisez ce paquet** pour un champ PIN/OTP, une autocomplétion texte simple
ou une petite table éditée en mémoire. **N'utilisez pas ce paquet** si vous
avez besoin de persister une table éditable via `@ZcrudModel` : le
générateur ne supporte pas aujourd'hui un champ `List<Map<String, dynamic>>`
(voir cas limites).

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_field_extras/zcrud_field_extras.dart';

Widget buildApp(Widget child) {
  final registry = ZWidgetRegistry();
  registerZFieldExtrasFields(registry);
  return ZcrudScope(widgetRegistry: registry, child: child);
}
```

## Concepts clés {#concepts-cles}

- **Value-in-slice (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  chaque widget lit `ctx.value` et écrit via `ctx.onChanged` dans la
  frontière de rebuild du dispatcher, sans jamais capturer le
  `ZFormController` ni s'abonner plus largement. Les contrôleurs internes
  (`TextEditingController`, contrôleurs de cellule) sont alloués une seule
  fois et jamais recréés au rebuild — aucune perte de focus, aucune
  reconstruction inutile.
- **Repli défensif systématique (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  une valeur externe corrompue ou d'un type inattendu ne provoque jamais de
  crash : champ vide pour PIN/autocomplétion, table vide pour
  `editableTable`.
- **Cibles tactiles et thème injecté (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  chaque cellule ou action mesure au moins 48 dp, les couleurs sont dérivées
  du thème (`ZcrudTheme`/`ColorScheme`) et non codées en dur, Reduce Motion
  est honoré pour le champ PIN.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `registerZFieldExtrasFields` | Enrôle les trois builders dans un `ZWidgetRegistry`, à appeler au bootstrap. |
| `ZPinFieldWidget` / `pinFieldKind` | Champ PIN/OTP segmenté. |
| `ZAutocompleteFieldWidget` / `autocompleteFieldKind` | Champ texte auto-complété, natif Flutter. |
| `ZEditableTableFieldWidget` / `editableTableFieldKind` | Table éditable virtualisée, édition en mémoire. |
| `zParseTableRows` / `zTableColumns` | Fonctions pures de parsing défensif et de dérivation des colonnes d'une table. |

## Cas limites et invariants {#cas-limites}

- **Persistance non supportée pour `editableTable`** : la valeur est
  `List<Map<String, dynamic>>`, éditée pleinement en mémoire, mais le
  générateur zcrud ne sait pas aujourd'hui sérialiser un champ `Map` via
  `@ZcrudModel`. Un type de valeur dédié avec son propre codec serait requis
  pour lever cette limite — ne tentez pas de la contourner localement.
  Ce paquet gère ce cas.
- **« Tags riches » non couvert** : `EditionFieldType.tags` route vers la
  famille native `tags` du cœur, jamais vers `registryOrFallback` ; un `kind
  == 'tags'` enregistré ici serait du code mort. Le besoin est déjà couvert
  sans dépendance par `ZSubListDisplayMode.tags`.
- **Enrôlement unique** : enregistrer deux fois le même `kind` sur un
  registre lève `ZDuplicateRegistrationError` — jamais un dernier-écrit
  silencieux.

## Voir aussi {#voir-aussi}

- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) —
  AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
