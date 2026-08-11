# zcrud_chat_material

Skin Material pixel-perfect pour le composer du chat zcrud — satellite
opt-in qui n'ajoute aucune dépendance tierce (invariant AD-1).

## Aperçu {#apercu}

Le composer par défaut de `zcrud_chat` est chromatiquement nu par
construction : pas de rôle `ColorScheme`, pas d'icône Material, pour que le
socle reste utilisable sous n'importe quel design system. Ce paquet fournit
les builders Material qui habillent ce composer — bouton d'envoi animé,
chips d'effort, badges de compteur, chips de pièces jointes, slider de
budget de calcul — sans jamais dupliquer sa logique.

Chaque widget se branche sur un créneau déjà exposé par le socle
(`ZChatComposer.trailing`/`tools`/`leading`, ou
`ZChatSettingsSheet.computeBudgetBuilder`) : ce paquet ne construit ni
composer ni feuille de réglages parallèles. L'envoi passe toujours par
`ZChatComposerSlot.submit`, le site d'envoi unique du socle.

**Utilisez ce paquet** si votre application est en Material Design et que
vous voulez un composer de chat entièrement stylé sans écrire vous-même les
rôles `ColorScheme`, glyphes et dimensions conformes à l'accessibilité.

**N'utilisez pas ce paquet** si votre application suit un autre design
system (Cupertino, un thème maison) : composez directement sur les créneaux
de `zcrud_chat`, qui restent nus et remplaçables.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

/// Le composer complet, stylé Material, prêt à monter.
Widget buildMaterialComposer(
  ZChatController controller,
  ZChatSettingsController settings,
) {
  return ZChatMaterialComposer(controller: controller, settings: settings);
}
```

## Concepts clés {#concepts-cles}

- **Des builders sur les créneaux du socle, jamais une vue parallèle** —
  chaque widget de ce paquet remplit un créneau que `zcrud_chat` expose déjà
  (bouton d'envoi, bascules, badges) ; aucun composer ni feuille de réglages
  n'est réécrit.
- **La chaîne de résolution du chrome** — dimensions, couleurs d'identité et
  durées ne sont jamais codées en dur : elles sont résolues via
  `zChatComposerChromeOf` avec la priorité paramètre explicite > jeton de
  thème > référence Material intégrée à ce paquet.
- **Accessibilité et RTL ([AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  toute cible tactile est tenue ≥ 48 dp en géométrie rendue (pas seulement
  promise par le thème), tout est directionnel, et un état n'est jamais porté
  par la seule couleur (un canal non chromatique — coche, icône — coexiste
  toujours avec la teinte).
- **Composabilité par créneaux nullables ([AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  chaque builder est indépendant : l'hôte en monte un, plusieurs ou aucun ; un
  réglage absent fait rendre `null`, jamais une affordance inerte.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZChatMaterialComposer` | Le composer complet assemblé — glyphes, rôles Material et FAB d'envoi sur `ZDefaultChatComposer`. |
| `zChatMaterialSendFab` / `ZChatMaterialSendFab` | Le bouton d'envoi animé, à brancher sur le créneau `trailing`. |
| `zChatMaterialEffortChips` / `ZChatMaterialEffortChips` | Les chips de palier de longueur de réponse, à brancher sur le créneau `tools`. |
| `ZChatMaterialBadge` / `ZChatMaterialToolsBadge` | Le badge compteur statique, et sa variante liée au nombre de réglages actifs. |
| `zChatMaterialAttachmentChips` / `ZChatMaterialAttachmentChips` | La rangée de chips de pièces jointes en attente. |
| `zChatMaterialBudgetSlider` / `ZChatMaterialBudgetSlider` | Le slider labellisé de budget de calcul, alternative aux chips par défaut. |

## Cas limites et invariants {#cas-limites}

- **Aucun second site d'envoi** — le tap du bouton d'envoi appartient à la
  primitive du socle (`ZChatComposerSendTarget`), jamais à un `onPressed`
  propre à ce paquet : il n'existe qu'un seul chemin d'envoi.
- **`borderColor` du composer assemblé** — un hôte qui obtenait déjà un filet
  autour du composer en l'enveloppant d'un second conteneur doit retirer
  cette compensation en migrant vers ce paramètre ; sinon les deux filets se
  superposent à des rayons différents.
- **La teinte n'est jamais le seul canal d'un état** — sélection, activation
  et compteurs restent lisibles sans couleur (coche, icône, `Semantics`
  explicite).
- **Aucune animation propre à ce paquet** — les transitions viennent des
  primitives du socle, qui respectent déjà le réglage de réduction des
  animations de la plateforme.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat_material.md`](../../docs/site/paquets/zcrud_chat_material.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet habille le composer.
- `zcrud_chat_kernel` — le domaine pur de conversation, dont dépend `zcrud_chat`.

## Licence {#licence}

MIT — voir la racine du dépôt.
