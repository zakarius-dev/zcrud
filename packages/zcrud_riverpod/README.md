# zcrud_riverpod

Binding optionnel état/injection Riverpod pour zcrud — un manager parmi
d'autres derrière le même cœur réactif (invariant AD-15).

## Aperçu {#apercu}

`zcrud_riverpod` branche l'injection et le cycle de vie du cœur zcrud sur
Riverpod, sans jamais réimplémenter la réactivité : `ZFormController` reste
un `ChangeNotifier` pur Flutter (invariant AD-2), ce paquet se contente de
l'exposer via un `Provider.autoDispose` et de fournir un resolver Riverpod
pour le seam `ZDependencyResolver` du cœur. Le cœur `zcrud_core` ignore
totalement Riverpod — aucun `WidgetRef` ni `ref.watch` n'y entre jamais.

Ce paquet fournit aussi des providers génériques pour le domaine study
(`zcrud_study_kernel`) : seam de repository, flux de liste nu, et sélection
de session dédupliquée par égalité profonde.

**Utilisez ce paquet** si votre application est déjà organisée autour de
Riverpod et que vous voulez que l'injection zcrud (resolver, ACL, seams
study) suive le même idiome. **N'utilisez pas ce paquet** si votre
application n'utilise pas Riverpod : `ZcrudScope` (le binding par défaut,
zéro dépendance, dans `zcrud_core`) ou `zcrud_get`/`zcrud_provider`
conviennent alors mieux.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

/// Enveloppe un sous-arbre applicatif dans le binding Riverpod : monte un
/// ProviderContainer, expose le ZFormController en auto-dispose et câble le
/// resolver du cœur.
Widget wrap(Widget child) => ZcrudRiverpodScope(child: child);
```

## Concepts clés {#concepts-cles}

- **Réutiliser, jamais réimplémenter (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  `zFormControllerProvider` expose le même `ZFormController` à tranches
  `ValueListenable` que le binding par défaut ; ce paquet n'ajoute aucune
  couche de state management par-dessus.
- **Seams qui échouent explicitement (invariant [AD-6](../../docs/site/concepts/invariants.md#ad-6))** —
  `ZRiverpodResolver.resolve<T>()` lève un `ZScopeError` actionnable quand
  aucun provider n'est enregistré pour `T` dans `seams`, plutôt que de
  résoudre silencieusement vers une valeur par défaut inattendue. Même
  principe pour `zStudyRepositoryProvider<T>()`, dont la lecture *throw* tant
  qu'il n'est pas surchargé (`overrideWith`).
- **L'égalité de clé de cache vit dans le binding (invariant [AD-24](../../docs/site/concepts/invariants.md#ad-24))** —
  `ZSessionConfigKey` réimplémente sa propre égalité profonde par valeur sur
  une `ZStudySessionConfig`, pour que la garantie « pas de rebuild si la
  configuration est structurellement inchangée » se prouve dans ce paquet,
  indépendamment de ce que le kernel décide de son propre `==`.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZcrudRiverpodScope` | Widget de scope : monte un `ProviderContainer`, expose le `ZFormController` en auto-dispose, enveloppe l'enfant dans un `ZcrudScope`. |
| `zFormControllerProvider` | Provider auto-dispose exposant un `ZFormController` neuf, disposé avec le container. |
| `ZRiverpodResolver` | Implémentation Riverpod du seam `ZDependencyResolver` du cœur — résout par registre `Type → provider`. |
| `ZRiverpodApi` | Marqueur de version de l'API publique du paquet. |
| `zStudyRepositoryProvider<T>` | Fabrique le seam d'un `ZStudyRepository<T>` — *throw* tant qu'il n'est pas surchargé. |
| `zStudyWatchAllProvider<T>` | `StreamProvider.autoDispose` exposant le flux nu `watchAll()` du repository résolu. |
| `zStudySessionSelectorProvider` | Family Riverpod de sélection de session, clée par [ZSessionConfigKey]. |
| `ZSessionConfigKey` | Clé de family à égalité profonde par valeur, enveloppant une `ZStudySessionConfig`. |
| `ZScopeError` | Ré-exporté depuis `zcrud_core` — le type d'erreur levé par tout seam non surchargé. |

## Cas limites et invariants {#cas-limites}

- **Auto-dispose partout, pas de fuite** — le `ZFormController` du scope et
  les flux `watchAll()` sont libérés dès que plus personne ne les écoute (ou
  que le `ProviderContainer` du scope est disposé) : aucun abonnement ne
  survit à son écran.
- **Riverpod 3 : auto-dispose par défaut** — le type de retour de
  `zStudyWatchAllProvider` est `StreamProvider<List<T>>` (le type
  `AutoDisposeStreamProvider` a disparu de l'API Riverpod 3) ; la sémantique
  d'annulation à la disparition du dernier auditeur reste inchangée.
- **`ZSessionConfigKey` compare TOUS les champs de la config**, y compris les
  listes (`tagIds`, `types`, comparaison profonde) et `extra` (JSON imbriqué,
  comparaison structurelle) — une différence sur un seul champ produit une
  clé différente, donc un rebuild.
- **Providers typés concrets non fournis ici** — ce paquet reste générique
  (dépendance minimale à `zcrud_study_kernel` seul) ; les providers adossés à
  une entité applicative concrète (ex. `zStudyWatchAllProvider<MonDocument>`)
  s'instancient côté application.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_riverpod.md`](../../docs/site/paquets/zcrud_riverpod.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZcrudScope` (binding par défaut), `ZFormController`, `ZDependencyResolver`.
- `zcrud_get` / `zcrud_provider` — les bindings équivalents pour GetX et provider.

## Licence {#licence}

MIT — voir la racine du dépôt.
