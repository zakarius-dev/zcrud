import 'package:zcrud_core/zcrud_core.dart';
// Le composeur fp-2-2 (AD-55) est le POINT DE COMPOSITION UNIQUE des widgets
// d'édition servis par les satellites. La showcase le CONSOMME (elle ne
// re-`register` pas kind-par-kind — AC7) et ÉTEND l'enrôlement des NOUVEAUX
// satellites fp-4/fp-5 via le seam `additionalRegistrars` (jamais une réécriture
// du composeur ni une re-registration manuelle).
import 'package:zcrud_field_extras/zcrud_field_extras.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_html/zcrud_html.dart';
import 'package:zcrud_intl/zcrud_intl.dart';
import 'package:zcrud_media/zcrud_media.dart';

/// Construit le `ZWidgetRegistry` **dédié à la showcase EXHAUSTIVE** (fp-3-2),
/// peuplé EXCLUSIVEMENT via le composeur `registerZcrudFormFields` du binding
/// `zcrud_get` (fp-2-2 / AD-55) — jamais par une re-registration manuelle
/// kind-par-kind (anti-pattern écarté par AD-55).
///
/// Kinds enrôlés PAR DÉFAUT (composeur) : markdown/inlineMarkdown/richText,
/// phoneNumber/country/address, location (repli coords-seules AD-12) et, avec
/// `wireGeoArea: true`, geoArea (style-picker fp-5-3).
///
/// Kinds enrôlés par les **`additionalRegistrars`** (satellites fp-4/fp-5, tous
/// `done`) — une ligne opt-in au site d'appel de l'app (AD-55) :
///  - [registerZHtmlFields] → `html`/`inlineHtml` (WYSIWYG édition / `ZHtmlView`
///    lecture). Kinds DISJOINTS de markdown ⇒ aucune collision `ZDuplicateRegistrationError`.
///  - [registerZMediaFieldWidgets] → `mediaImage`/`mediaFile`/`mediaVideo`
///    (`ZMediaFieldWidget`), picker média capturé par closure (AD-4).
///  - [registerZFieldExtrasFields] → `pin`/`autocomplete`/`editableTable`.
///
/// **AD-4** : instance NON-mutable après peuplement, détenue par l'app (créée 1×
/// par `ShowcaseScreen`) et injectée via `ZcrudScope.widgetRegistry`.
ZWidgetRegistry buildShowcaseWidgetRegistry({ZMediaFilePicker? mediaPicker}) {
  final registry = ZWidgetRegistry();
  registerZcrudFormFields(
    registry,
    // Catalogue pays partagé par phoneNumber/country/address (une seule lecture).
    countryCatalog: ZCountryCatalog(),
    // geoArea enrôlé (fp-5-3) — même repli coords-seules que location (AD-12).
    wireGeoArea: true,
    // geoAdapterFactory OMIS → repli coordonnées-seules (AD-12), aucun secret.
    additionalRegistrars: <void Function(ZWidgetRegistry)>[
      // Voie HTML WYSIWYG (opt-in, kinds disjoints de markdown — AD-50).
      registerZHtmlFields,
      // Média riche (fp-4-2) — picker partagé avec ZcrudScope.filePicker.
      (reg) => registerZMediaFieldWidgets(reg, picker: mediaPicker),
      // Champs spécialisés (fp-5-2) : pin / autocomplete / editableTable.
      registerZFieldExtrasFields,
    ],
  );
  return registry;
}
