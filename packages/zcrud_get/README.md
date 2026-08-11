# zcrud_get

Le binding optionnel état/injection GetX + get_it de zcrud (cible l'hôte
GetX, DODLP) — invariant [AD-15](../../docs/site/concepts/invariants.md#ad-15)
(multi-gestionnaire par bindings).

## Aperçu {#apercu}

`zcrud_get` fournit `ZcrudGetScope` (crée/scope/dispose le `ZFormController`
selon le lifecycle GetX/get_it) et `ZGetResolver` (résolution de dépendances
via `get_it`). Il réutilise la réactivité du cœur (`ZFormController`/
`ZFieldListenableBuilder`) sans la réimplémenter : tout le code spécifique à
GetX reste confiné à ce paquet.

Au-delà du scope de base, le paquet fournit :

- des **implémentations manager** de ports UI purs, substituables aux
  défauts pur-Flutter via leurs seams (`ZGetFormPresenter` pour
  `ZFormPresenter`, `ZGetToaster` pour `ZToaster`, `ZcrudGetUiScope` pour les
  monter d'un coup) ;
- `registerZcrudFormFields`, le point de composition unique enrôlant les
  widgets d'édition des satellites (markdown, intl, geo) dans un
  `ZWidgetRegistry` ;
- `ReflectableCodec`, la **seule exception `reflectable`** du monorepo,
  adaptant un modèle réfléchi vers le `ZcrudRegistry` ;
- un binding study générique GetX (`ZStudyWatchController`,
  `zPutStudySessionSelector`), miroir GetX d'un binding Riverpod équivalent.

**Utilisez ce paquet** si votre application utilise GetX/get_it pour la
gestion d'état et l'injection. **N'utilisez pas ce paquet** avec Riverpod
(`zcrud_riverpod`) ou `provider` (`zcrud_provider`) : chaque idiome a son
propre binding, et le cœur n'importe jamais aucun d'entre eux.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_get/zcrud_get.dart';

Widget wrap(Widget child) => ZcrudGetScope(child: child);
```

## Concepts clés {#concepts-cles}

- **Réactivité Flutter-native préservée (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  ce binding ne réimplémente jamais `ZFormController` : il le crée, le scope
  au lifecycle GetX/get_it, l'expose via `ZcrudScope.of(context)`. Les
  widgets du cœur ignorent totalement que GetX est derrière.
- **Résolution par seam, jamais silencieuse** — `ZGetResolver.resolve<T>()`
  interroge le `GetIt` du scope ; si `T` n'y est pas enregistré, il lève
  `ZScopeError` avec un message actionnable plutôt que de retourner un
  résultat inattendu.
- **Garde d'appartenance sur un locator partagé** — quand plusieurs
  `ZcrudGetScope` partagent le même `GetIt` ou le même singleton GetX, chaque
  scope ne désenregistre que ce qu'il a lui-même enregistré au démontage :
  aucun risque de supprimer le `ZFormController` d'un scope frère encore
  vivant.
- **`reflectable` confiné à un seul fichier (invariant [AD-3](../../docs/site/concepts/invariants.md#ad-3))** —
  `ReflectableCodec` est la seule exception `reflectable` autorisée du
  monorepo, allowlistée par un gate CI dédié ; le cœur n'en dépend jamais.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZcrudGetScope` | Scope de binding : crée/scope/dispose le `ZFormController` selon le lifecycle GetX/get_it. |
| `ZGetResolver` | Résolveur de dépendances adossé au locator `get_it`. |
| `ZGetFormPresenter` | Implémentation GetX du port `ZFormPresenter` (page/sheet/dialog). |
| `ZGetToaster` | Implémentation GetX du port `ZToaster` (`Get.snackbar`). |
| `ZcrudGetUiScope` | Monte présentateur et toaster GetX en un seul widget. |
| `registerZcrudFormFields` | Point de composition unique des widgets d'édition des satellites dans un `ZWidgetRegistry`. |
| `ReflectableCodec` / `ZReflectionCapability` | Adaptateur d'un modèle `reflectable` vers le `ZcrudRegistry`, via une capacité de réflexion injectée. |
| `ZStudyWatchController` / `zPutStudySessionSelector` | Binding study générique GetX, paramétré par l'entité de l'application hôte. |

## Cas limites et invariants {#cas-limites}

- Un `T` non enregistré dans le locator lève une erreur explicite au lieu
  d'une résolution silencieuse ou d'un crash tardif.
- Un `ZSessionConfigKey` garantit `a == b ⟺ a.tag == b.tag` sur les sept
  champs de sa configuration : deux configurations structurellement égales
  réutilisent la même instance GetX, jamais une recréation superflue.
- L'ajout d'un satellite futur à `registerZcrudFormFields` (via
  `additionalRegistrars`) ne réécrit jamais le composeur ni n'ajoute de
  nouvelle dépendance au binding ; une collision de `kind` déclenche
  `ZDuplicateRegistrationError` plutôt qu'un dernier-écrit silencieux.

## Voir aussi {#voir-aussi}

- Matrice de paramètres détaillée de `ZGetFormPresenter` :
  [`doc/parameter-matrix-z-get-form-presenter.md`](doc/parameter-matrix-z-get-form-presenter.md).
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) —
  AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
