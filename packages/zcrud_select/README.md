# zcrud_select

Satellite **sélection** de zcrud — présentateur riche `single`/`multiple` au
-dessus du fork MIT vendorisé `awesome_select`.

## Aperçu {#apercu}

`zcrud_select` fournit `ZSmartSelectPresenter`, implémentation concrète du
seam `ZSelectPresenter` du cœur. Injecté via
`ZcrudScope(selectPresenter: const ZSmartSelectPresenter())`, il supplante le
rendu natif des familles `select`/`radio`/`checkbox`/`multiselect`/`relation`
par un **modal en bottom-sheet** (radios en mono, checkboxes/interrupteurs en
multi), avec recherche optionnelle. Aucun type `awesome_select`/`SmartSelect`/
`S2*` ne fuit dans l'API publique.

Sans rien configurer, un hôte qui enrôle le présentateur obtient une
apparence de référence éprouvée (carte à bordure douce, rayon 12, tuile de
liste avec chevron, puces en multi) — les **couleurs**, elles, restent des
**rôles** `ColorScheme`, donc le thème de chaque application reste le sien.
Pour dévier, `ZSmartSelectPresenter(spec: ZSelectTileSpec(…))` surcharge la
chaîne `paramètre > jeton `ZcrudTheme.select*` > référence`.

**Utilisez ce paquet** pour un rendu de sélection riche (modal, recherche,
apparence cohérente) sur les champs `select`/`radio`/`checkbox`/
`multiselect`/`relation`. **N'utilisez pas ce paquet** si le rendu natif du
cœur suffit : sans enrôlement, ces familles conservent leur rendu natif,
sans régression.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`. Il dépend en outre du fork privé vendorisé
`awesome_select`, feuille dépendue par ce seul paquet.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

Widget buildApp(Widget child) {
  return ZcrudScope(
    selectPresenter: const ZSmartSelectPresenter(),
    child: child,
  );
}
```

## Concepts clés {#concepts-cles}

- **Confinement du fork (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1))** —
  `awesome_select` est dépendu par ce paquet et par lui seul ; aucun type
  `S2*` ne fuit au barrel ni dans la signature `present()`.
- **Chaîne de résolution à trois maillons** — `paramètre ([ZSelectTileSpec])
  > jeton (`ZcrudTheme.select*`) > référence auditée
  ([ZSelectTileReference])` ; un maillon `null` ne se prononce pas et laisse
  décider le suivant, il ne le remplace jamais par une valeur neutre.
- **Value-in-slice (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  le présentateur ne touche jamais le `ZFormController` ; il lit
  `presentation.selected` et notifie `presentation.onChanged` avec une vraie
  valeur métier (scalaire en mono, `List` en multi), jamais un type interne
  du fork.
- **Zéro side-effect d'import** — aucun `register*()` top-level ; importer ce
  paquet ne change le rendu de rien, seule l'injection au scope le fait.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZSmartSelectPresenter` | Présentateur riche, implémentation de `ZSelectPresenter`. |
| `ZSelectTileSpec` | Surcharge par paramètre de l'apparence du déclencheur et du modal. |
| `ZSelectTileReference` | Valeurs de référence auditées (dimensions uniquement, aucune couleur). |
| `ZSelectChoiceStyle` / `ZSelectModalShape` | Formes des options et du conteneur de modal (enums locaux). |
| `ZSelectTileMetrics` / `zSelectTileMetricsOf` | Métriques résolues de la chaîne paramètre/jeton/référence. |
| `zSelectChoiceStyleFromToken` / `zSelectModalShapeFromToken` | Conversion totale d'un nom de jeton vers son enum, jamais levantes. |

## Cas limites et invariants {#cas-limites}

- Options vides, `selected` hors options, option `disabled`, spec absente :
  rendu **dégradé défini** (sélecteur vide accessible, placeholder, option
  non cochable) — jamais une exception (invariant AD-10).
- Le plancher de hauteur de 48 dp (invariant AD-13) ne peut être que
  **rehaussé**, jamais abaissé, quelle que soit la valeur posée par le
  paramètre ou par le jeton.
- Un chargeur d'options asynchrone qui ne se termine pas est abandonné après
  30 s au profit du rendu dégradé (liste vide), plutôt que de laisser le
  modal attendre indéfiniment.
- Un jeton de palier inconnu (par exemple un thème sérialisé par une version
  plus récente) retombe sur la référence, sans lever.

## Voir aussi {#voir-aussi}

- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
