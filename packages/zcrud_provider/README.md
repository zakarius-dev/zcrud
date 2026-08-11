# zcrud_provider

Binding optionnel état/injection `provider` pour zcrud — complète la matrice
multi-gestionnaire derrière le même cœur réactif (invariant AD-15).

## Aperçu {#apercu}

`zcrud_provider` branche l'injection et le cycle de vie du cœur zcrud sur le
package `provider`, sans jamais réimplémenter la réactivité :
`ZFormController` reste un `ChangeNotifier` pur Flutter (invariant AD-2), ce
paquet se contente de le monter dans un `ChangeNotifierProvider` (dispose
géré automatiquement par `provider`) et de fournir un resolver adossé à
`context.read<T>()` pour le seam `ZDependencyResolver` du cœur. Le cœur
`zcrud_core` ignore totalement `provider` — il n'appelle jamais
`Provider.of`.

**Utilisez ce paquet** si votre application est déjà organisée autour de
`provider` et que vous voulez que l'injection zcrud (resolver, ACL, seams
applicatifs) suive le même idiome. **N'utilisez pas ce paquet** si votre
application n'utilise pas `provider` : `ZcrudScope` (le binding par défaut,
zéro dépendance, dans `zcrud_core`) ou `zcrud_get`/`zcrud_riverpod`
conviennent alors mieux.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_provider/zcrud_provider.dart';

/// Enveloppe un sous-arbre applicatif dans le binding provider : monte un
/// ChangeNotifierProvider<ZFormController> et câble le resolver du cœur.
Widget wrap(Widget child) => ZcrudProviderScope(child: child);
```

## Concepts clés {#concepts-cles}

- **Réutiliser, jamais réimplémenter (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  `ZcrudProviderScope` monte le même `ZFormController` à tranches
  `ValueListenable` que le binding par défaut ; ce paquet n'ajoute aucune
  couche de state management par-dessus, il délègue seulement le `dispose()`
  à `provider`.
- **Un seam qui échoue explicitement (invariant [AD-6](../../docs/site/concepts/invariants.md#ad-6))** —
  `ZProviderResolver.resolve<T>()` convertit une `ProviderNotFoundException`
  en `ZScopeError` actionnable, nommant le type manquant, plutôt que de
  planter avec une exception interne au package `provider`.
- **Identité de resolver stable (invariant [AD-15](../../docs/site/concepts/invariants.md#ad-15))** —
  le `ZProviderResolver` est mémoïsé par le scope (créé une fois) ; seul son
  `BuildContext` sous-jacent est réattaché à chaque rebuild. Comme
  `ZcrudScope.updateShouldNotify` compare le resolver par identité, cette
  stabilité évite un sur-rebuild des consommateurs de `ZcrudScope.of` — à
  parité avec les autres bindings de la matrice.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZcrudProviderScope` | Widget de scope : monte le `ZFormController` dans un `ChangeNotifierProvider`, enveloppe l'enfant dans un `ZcrudScope`. |
| `ZProviderResolver` | Implémentation `provider` du seam `ZDependencyResolver` du cœur — résout via `context.read<T>()`. |
| `ZProviderApi` | Marqueur de version de l'API publique du paquet. |

## Cas limites et invariants {#cas-limites}

- **Dispose entièrement délégué** — le `ZFormController` monté par
  `ZcrudProviderScope` est créé en `lazy: false` (dès le montage du scope,
  jamais paresseusement) et son `dispose()` est appelé automatiquement par
  `provider` au démontage : aucun appel manuel requis côté application.
- **Un seam manquant nomme le type attendu** — si aucun provider ne fournit
  `T` sous le scope, `ZProviderResolver.resolve<T>()` lève un `ZScopeError`
  dont le message inclut `T` et le geste correctif
  (`ZcrudProviderScope(providers: [...])`).
- **Le resolver n'est jamais recréé silencieusement** — un appel à
  `resolve<T>()` avant tout `attach()` (bug interne, jamais observable en
  usage normal) lève un `ZScopeError` explicite plutôt que de retourner une
  valeur incohérente.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_provider.md`](../../docs/site/paquets/zcrud_provider.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZcrudScope` (binding par défaut), `ZFormController`, `ZDependencyResolver`.
- `zcrud_get` / `zcrud_riverpod` — les bindings équivalents pour GetX et Riverpod.

## Licence {#licence}

MIT — voir la racine du dépôt.
