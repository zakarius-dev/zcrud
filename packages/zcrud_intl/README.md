# zcrud_intl

Champs internationaux de zcrud — téléphone, pays, devise, état/province et
adresse — dont chaque valeur de tranche reste **neutre** (aucun type d'une
lib tierce ne fuit dans le `ZFormController`, invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)).

## Aperçu {#apercu}

`zcrud_intl` sert cinq champs additifs via `ZWidgetRegistry` : `phoneNumber`
(rendu natif, sélecteur pays + formatage « as-you-type »), `country`
(sélecteur pays inline), `address`/`addressSearchField` (sous-formulaire
structuré, avec recherche géo optionnelle) — plus deux champs composables
que l'app enregistre elle-même sous le `kind` de son choix : devise
([ZCurrencyField]) et état/province ([ZStateField]). Chaque champ émet une
valeur de tranche **neutre** : une `String` internationale pour le
téléphone, un code ISO alpha-2 pour le pays, un code ISO 4217 (ou un
[ZMoney]) pour la devise, un code ISO 3166-2 pour l'état/province, un
[ZPostalAddress] structuré pour l'adresse. Les catalogues pays/devise/
subdivisions sont servis depuis des **assets JSON bundlés**, chargés
paresseusement et mis en cache.

Ce paquet **dépend de `zcrud_core`** et confine ses deux seules
dépendances téléphone (`phone_numbers_parser` pour le (dé)codage E.164,
`intl_phone_number_input` pour le rendu) à deux ponts internes jamais
exportés — aucun type de ces libs n'apparaît dans une signature publique
ni dans une valeur de tranche (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)).

**Utilisez ce paquet** pour ajouter des champs téléphone/pays/devise/
état/adresse à un formulaire `zcrud_core`, ou pour manipuler leurs valeurs
neutres ([ZPhoneNumber], [ZPostalAddress]…) hors formulaire. **N'utilisez
pas ce paquet** si vous avez seulement besoin du formatage de date localisé
(`ZIntlDateDisplayFormatter`) : c'est un point d'entrée séparé
(`package:zcrud_intl/date_formatter.dart`), qui évite de payer le poids
des données de locale CLDR à un hôte qui ne l'utilise pas.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

/// Enregistre les champs internationaux dans le registre de widgets de
/// l'hôte. `phoneNumber`/`country`/`address` sont les kinds canoniques ;
/// devise et état/province sont composables, sous un kind au choix.
void registerIntlFields(ZWidgetRegistry registry) {
  registry.register('phoneNumber', ZPhoneFieldWidget.builder());
  registry.register('country', ZCountryFieldWidget.builder());
  registerZAddressFieldWidgets(registry); // enregistre address + addressSearchField
  registry.register('currency', ZCurrencyField.builder());
  registry.register('state', ZStateField.builder());
}

// Valeur neutre, sans passer par un formulaire : (dé)sérialisation sûre.
void roundTrip() {
  const addr = ZPostalAddress(city: 'Niamey', countryCode: 'NE');
  final map = addr.toMap();
  final restored = ZPostalAddress.fromMapSafe(map); // ne throw jamais
  assert(restored?.city == 'Niamey');
}
```

## Concepts clés {#concepts-cles}

- **Valeur de tranche toujours neutre** — chaque champ n'émet que des types
  pur-Dart (`String`, `int`, ou un modèle de ce paquet comme
  [ZPostalAddress]). Le pont vers une lib tierce ([ZPhoneCodec],
  `z_intl_phone_input_bridge.dart`) reste **interne**, jamais exporté par
  le barrel — vérifié par une garde de confinement.
- **Catalogues paresseux et partagés** — [ZCountryCatalog],
  [ZCurrencyCatalog] et [ZSubdivisionCatalog] chargent leur asset JSON à
  la première demande, le mettent en cache (lecture seule, donc
  partageable), et ne lèvent jamais : asset absent ou JSON malformé
  retombent sur un catalogue vide.
- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** — tout `fromMapSafe` de ce paquet
  accepte une entrée hostile (`Map` non conforme, type inattendu, champ
  absent) et rend `null` plutôt que de lever ; un champ non désérialisable
  ne fait jamais échouer le parent.
- **Config additive par champ (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** — [ZIntlFieldConfig], posée sur
  `ZFieldSpec.config`, porte les défauts par champ (pays initial, pays
  préférés/autorisés, validateur téléphonique national opt-in…) sans
  jamais modifier `zcrud_core` : `config == null` reproduit exactement le
  comportement sans config.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Valeurs neutres** | |
| `ZPhoneNumber` | Numéro de téléphone neutre (pur-Dart) — modèle legacy, encore ingéré à l'amorçage. |
| `ZPostalAddress` / `ZAddressCodec` | Adresse structurée neutre et son codec de compatibilité avec un schéma `String` legacy. |
| `ZMoney` | Couple montant + devise ISO 4217, pour le champ devise en mode groupe. |
| `ZCountryInfo` / `ZCurrencyInfo` / `ZSubdivision` | Entrées de catalogue enrichissant l'affichage (nom, drapeau, symbole…) — jamais la valeur de tranche elle-même. |
| **Catalogues** | |
| `ZCountryCatalog` / `ZCurrencyCatalog` / `ZSubdivisionCatalog` | Catalogues paresseux + cachés, injectables, chargés depuis un asset bundlé. |
| `sharedDefaultCountryCatalog` | Instance partagée lazy, pour qu'un formulaire à plusieurs champs intl ne lise l'asset qu'une fois. |
| **Champs de formulaire** | |
| `ZPhoneFieldWidget` | Champ téléphone international — rendu natif (sélecteur pays + formatage as-you-type), valeur `String`. |
| `ZCountryFieldWidget` / `ZCountryPickerField` | Champ pays et son sélecteur inline (interne) réutilisé par les autres champs. |
| `ZAddressFieldWidget` | Sous-formulaire adresse structuré, avec recherche géo optionnelle via `ZPlaceSearchProvider`. |
| `ZCurrencyField` | Champ devise composable — code ISO 4217 seul, ou `ZMoney` en mode groupe. |
| `ZStateField` | Champ état/province composable, dépendant du pays — repli texte libre si aucune subdivision. |
| **Configuration et validation** | |
| `ZIntlFieldConfig` | Config additive par champ (pays/devise par défaut, restrictions, retrait de sélecteur, validateur national). |
| `ZNationalPhoneValidator` / `ZNationalPhoneError` | Validateur de numéro national paramétrable (longueur + préfixes), opt-in, sans politique codée en dur. |
| `nationalPhoneErrorText` | Résout le message l10n d'un `ZNationalPhoneError` — repli français, surchargeable via `ZcrudScope`. |
| `ZPlaceSearchProvider` / `ZPlacePrediction` | Port de recherche géographique injectable — l'implémentation (Google Places, OSM…) vit hors de ce paquet. |
| **Formatage de date (point d'entrée séparé)** | |
| `ZIntlDateDisplayFormatter` | Implémentation `intl` du port `ZDateDisplayFormatter` — `package:zcrud_intl/date_formatter.dart` uniquement. |

## Cas limites et invariants {#cas-limites}

- **Aucune donnée fabriquée** — le pays présélectionné du champ téléphone
  n'est jamais inventé : il est dérivé, dans l'ordre, de la valeur déjà
  saisie, de la config par champ, du paramètre de widget, de la locale
  ambiante, puis des locales de l'appareil. Sans aucune source, aucun pays
  n'est transmis plutôt qu'un choix arbitraire.
- **Rupture de contrat assumée sur `phoneNumber`** — la valeur de tranche
  du champ téléphone est une **`String`** en forme internationale
  (`^\+[0-9]+$`), pas un [ZPhoneNumber]. La lecture reste défensive : une
  valeur d'un ancien schéma [ZPhoneNumber] (ou sa map sérialisée) est
  encore ingérée à l'amorçage, puis ré-émise en `String`.
- **Zéro secret, zéro réseau (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** — aucune clé API, aucun endpoint en dur.
  La recherche géographique de `ZAddressFieldWidget` est optionnelle : sans
  `ZPlaceSearchProvider` injecté par l'app, aucune affordance de recherche
  n'apparaît (comportement strictement identique).
- **Défauts nationaux toujours surchargeables (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** — aucun code
  pays, préfixe ou longueur téléphonique n'est codé en dur dans ce
  paquet : une politique nationale (ex. validation d'un numéro togolais)
  se déclare entièrement par paramètres, côté application.
- **RTL et accessibilité (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** — sélecteurs et déclencheurs exposent une
  action sémantique opérable au lecteur d'écran (`ExcludeSemantics` +
  `onTap` porté par le nœud englobant), cibles ≥ 48 dp, layout
  directionnel.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_intl.md`](../../docs/site/paquets/zcrud_intl.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZWidgetRegistry`, `ZFieldSpec.config`, `ZDateDisplayFormatter`.
- `zcrud_geo` — champs géographiques complémentaires (coordonnées, carte).

## Licence {#licence}

MIT — voir la racine du dépôt.
