/// Point de composition unique du binding `zcrud_get` (fp-2-2, **AD-55**).
///
/// AD-55 fait du **binding** le point d'enrôlement UNIQUE des widgets d'édition
/// servis par les satellites (markdown, intl, geo). [registerZcrudFormFields]
/// **appelle** les registrars/builders exposés par chaque satellite sur un
/// [ZWidgetRegistry] **fourni par l'appelant** — il ne construit JAMAIS de
/// registre en singleton statique interne (AD-4) : l'app possède le registre
/// (via son bootstrap / `ZcrudGetScope`) et l'injecte ensuite dans l'arbre via
/// `ZcrudScope.widgetRegistry`, où le dispatcher `ZFieldWidget` le résout.
///
/// **Anti-pattern écarté (AC2)** : aucun satellite n'édite CE fichier. Chaque
/// satellite fournit SON registrar (`registerZMarkdownFields`,
/// `registerZAddressFieldWidgets`) ou son `.builder()` statique
/// (`ZPhoneFieldWidget.builder`, `ZCountryFieldWidget.builder`,
/// `ZGeoFieldWidget.builder`) ; le composeur, qui appartient au binding, les
/// **appelle**. L'ajout d'un satellite futur (`html`/`media`/`select`/
/// `field_extras`) coûte **une ligne opt-in** au site d'appel de l'app via le
/// seam [additionalRegistrars] — jamais une réécriture du composeur ni une
/// nouvelle arête de dépendance du binding.
///
/// **Exclusivité html ⇄ markdown (AD-50)** : la voie markdown
/// (`markdown`/`inlineMarkdown`/`richText`) est câblée **par défaut**. La voie
/// HTML WYSIWYG (`html`/`inlineHtml`) est un **opt-in** : l'app passe le
/// `registerZHtmlFields` de `zcrud_html` (ou la voie HTML-via-Delta de
/// `zcrud_markdown`) dans [additionalRegistrars]. Câbler DEUX voies revendiquant
/// le même `kind` fait **`throw` `ZDuplicateRegistrationError`** (contrat
/// `ZWidgetRegistry.register` — jamais un last-wins silencieux). Les
/// [additionalRegistrars] sont exécutés **en dernier** pour que toute collision
/// opt-in survienne de façon déterministe.
///
/// **Frontière registre ⇄ scope** : ce composeur câble UNIQUEMENT le
/// `ZWidgetRegistry` (association `kind → ZFieldWidgetBuilder`). Les autres seams
/// AD-55 sont des **valeurs de `ZcrudScope`** injectées **à côté** par l'app :
/// `ZcrudScope.selectPresenter` (`ZSmartSelectPresenter` — fp-4, présentateur,
/// PAS un registrar de widget), `ZcrudScope.filePicker` (média — fp-5),
/// `ZcrudScope.colorPicker` (roue HSV côté binding — AD-52). Le composeur ne les
/// recâble pas ; l'app fait
/// `ZcrudScope(widgetRegistry: reg, selectPresenter: …, filePicker: …)`.
///
/// **Catalogues partagés** : sans [countryCatalog] injecté, les builders intl
/// retombent sur `sharedDefaultCountryCatalog()` (une seule lecture d'asset
/// partagée par phone/country/address).
///
/// **AD-12 (secrets)** : aucune clé Maps n'est embarquée ici ;
/// [geoAdapterFactory] et la config carte viennent de la plateforme de l'app,
/// injectés au site d'appel.
library;

import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_intl/zcrud_intl.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Enrôle en UN point les widgets d'édition des satellites MVP (markdown, intl,
/// geo) dans le [registry] **injecté** (AD-55 / AD-4).
///
/// Tous les paramètres de composition sont optionnels (défauts sûrs) :
/// * [richTextCodec] — format persisté partagé par la voie markdown (défaut
///   `ZDeltaCodec` côté `ZMarkdownField`) ;
/// * [countryCatalog] — catalogue pays partagé par `phoneNumber`/`country`/
///   `address` (défaut `sharedDefaultCountryCatalog()`) ;
/// * [subdivisionCatalog] — subdivisions pour le champ `address` ;
/// * [placeSearch] — seam d'autocomplétion d'adresse (`addressSearchField`) ;
/// * [geoAdapterFactory] — fabrique de carte du champ `location` (défaut `null`
///   → repli coordonnées-seules, aucun SDK carte, aucun secret — AD-12) ;
/// * [wireGeoArea] — enrôle aussi le `kind` `geoArea` (même patron que
///   `location`) ;
/// * [additionalRegistrars] — **seam d'extension opt-in** : chaque entrée est
///   appelée avec [registry] **en dernier** (html/media/field_extras futurs, une
///   ligne au site d'appel de l'app — sans dépendance du binding).
///
/// Collision de `kind` (double composition, ou opt-in en conflit avec une voie
/// déjà câblée) → **`throw` `ZDuplicateRegistrationError`**.
void registerZcrudFormFields(
  ZWidgetRegistry registry, {
  ZCodec? richTextCodec,
  ZCountryCatalog? countryCatalog,
  ZSubdivisionCatalog? subdivisionCatalog,
  ZPlaceSearchProvider? placeSearch,
  ZMapAdapterFactory? geoAdapterFactory,
  bool wireGeoArea = false,
  Iterable<void Function(ZWidgetRegistry)> additionalRegistrars =
      const <void Function(ZWidgetRegistry)>[],
}) {
  // Voie rich-text PAR DÉFAUT (markdown/inlineMarkdown/richText — FR-21, AD-7).
  registerZMarkdownFields(registry, codec: richTextCodec);

  // intl : phone/country enrôlés par `.builder()` (les satellites n'exposent
  // PAS de `registerZ<Pkg>Fields` pour ces kinds — écart connu, conforme AD-55 :
  // le point de composition est le binding). address a SON registrar dédié.
  registry.register(
    'phoneNumber',
    ZPhoneFieldWidget.builder(catalog: countryCatalog),
  );
  registry.register(
    'country',
    ZCountryFieldWidget.builder(catalog: countryCatalog),
  );
  registerZAddressFieldWidgets(
    registry,
    catalog: countryCatalog,
    subdivisionCatalog: subdivisionCatalog,
    placeSearch: placeSearch,
  );

  // geo : `location` (+ `geoArea` opt-in). CORE OUT=0 — le satellite reste isolé.
  registry.register(
    'location',
    ZGeoFieldWidget.builder(adapterFactory: geoAdapterFactory),
  );
  if (wireGeoArea) {
    registry.register(
      'geoArea',
      ZGeoFieldWidget.builder(adapterFactory: geoAdapterFactory),
    );
  }

  // Seam opt-in EN DERNIER : toute collision (ex. html revendiquant un kind déjà
  // pris, ou double html) throw de façon déterministe (AD-50).
  for (final registrar in additionalRegistrars) {
    registrar(registry);
  }
}
