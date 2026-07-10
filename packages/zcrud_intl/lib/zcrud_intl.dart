/// Barrel d'API publique de `zcrud_intl`.
///
/// Champs **téléphone** (`phoneNumber`), **pays** (`country`) et **adresse**
/// (`address`) à parité DODLP (E11a-2). Valeurs de tranche **neutres** :
/// [ZPhoneNumber] (E.164), code ISO alpha-2 `String` (pays), [ZPostalAddress]
/// (adresse structurée). Constantes pays servies depuis un **asset JSON paresseux**
/// ([ZCountryCatalog]). Widgets servis via `ZWidgetRegistry` (factories `.builder`).
///
/// **AD-1 (isolation)** : ce barrel n'exporte AUCUN symbole d'une lib intl/
/// téléphone (`phone_numbers_parser`). La (dé)normalisation E.164 est confinée à
/// un pont interne (`src/presentation/z_phone_codec.dart`), jamais exporté. Aucun
/// type de lib tierce ne fuit dans une valeur de tranche ni dans une signature
/// publique.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_country_catalog.dart';
export 'src/data/z_currency_catalog.dart';
export 'src/data/z_subdivision_catalog.dart';
export 'src/domain/z_country_info.dart';
export 'src/domain/z_currency_info.dart';
export 'src/domain/z_intl_api.dart';
export 'src/domain/z_intl_field_config.dart';
export 'src/domain/z_money.dart';
export 'src/domain/z_phone_number.dart';
export 'src/domain/z_postal_address.dart';
export 'src/domain/z_subdivision.dart';
export 'src/presentation/z_address_field_widget.dart';
export 'src/presentation/z_country_field_widget.dart';
export 'src/presentation/z_currency_field_widget.dart';
export 'src/presentation/z_phone_field_widget.dart';
export 'src/presentation/z_state_field_widget.dart';
