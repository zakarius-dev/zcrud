/// Barrel d'API publique de `zcrud_intl`.
///
/// Champs **téléphone** (`phoneNumber`), **pays** (`country`), **devise**,
/// **état/province** et **adresse** (`address`). Valeurs de tranche
/// **neutres** : forme internationale `String` (téléphone), code ISO
/// alpha-2 `String` (pays), code ISO 4217 `String` ou [ZMoney] (devise),
/// code ISO 3166-2 `String` (état/province), [ZPostalAddress] (adresse
/// structurée). Constantes pays/devise/subdivisions servies depuis des
/// **assets JSON paresseux** ([ZCountryCatalog], [ZCurrencyCatalog],
/// [ZSubdivisionCatalog]). Widgets servis via `ZWidgetRegistry` (factories
/// `.builder`).
///
/// **Isolation (invariant AD-1)** : ce barrel n'exporte aucun symbole
/// d'une lib intl/téléphone (`phone_numbers_parser`,
/// `intl_phone_number_input`). La (dé)normalisation E.164 est confinée à
/// un pont interne (`src/presentation/z_phone_codec.dart`), jamais
/// exporté. Aucun type de lib tierce ne fuit dans une valeur de tranche ni
/// dans une signature publique.
///
/// **Point d'entrée séparé** : l'implémentation `intl` du port de
/// formatage de date (`ZIntlDateDisplayFormatter`) n'est **pas** exportée
/// par ce barrel — elle vit dans `package:zcrud_intl/date_formatter.dart`
/// pour qu'un hôte qui n'a besoin que des champs téléphone/pays n'ait pas à
/// payer le poids des données de locale CLDR.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_country_catalog.dart';
export 'src/data/z_currency_catalog.dart';
export 'src/data/z_subdivision_catalog.dart';
export 'src/domain/z_address_codec.dart';
export 'src/domain/z_country_info.dart';
export 'src/domain/z_currency_info.dart';
export 'src/domain/z_intl_api.dart';
export 'src/domain/z_intl_field_config.dart';
export 'src/domain/z_money.dart';
export 'src/domain/z_national_phone_validator.dart';
export 'src/domain/z_phone_number.dart';
export 'src/domain/z_place_search_provider.dart';
export 'src/domain/z_postal_address.dart';
export 'src/domain/z_subdivision.dart';
export 'src/presentation/z_address_field_widget.dart';
export 'src/presentation/z_country_field_widget.dart';
export 'src/presentation/z_currency_field_widget.dart';
export 'src/presentation/z_national_phone_message.dart';
export 'src/presentation/z_phone_field_widget.dart';
export 'src/presentation/z_state_field_widget.dart';
