import 'package:zcrud_core/zcrud_core.dart';

/// Statut de **couverture** d'un `EditionFieldType` dans la showcase EXHAUSTIVE
/// (fp-3-2, AC1 — SM-2/SM-4). Il n'existe **AUCUN** statut « inconnu » : la
/// couverture est prouvée PAR CONSTRUCTION (le test énumère
/// `EditionFieldType.values` et exige une entrée pour CHAQUE valeur), jamais par
/// une liste codée en dur qui pourrait diverger de l'enum.
enum CoverageStatus {
  /// Rendu par un **adaptateur NATIF du cœur** (`zcrud_core`), zéro satellite.
  liveNative,

  /// Rendu par un **adaptateur SATELLITE** enrôlé via le composeur / un registrar
  /// (`markdown`/`intl`/`geo`/`html`/`media`/`field_extras`).
  liveSatellite,

  /// **Comportement / seam** (pas une famille de widget dédiée) : `password`
  /// (`text` masqué), `hidden` (non rendu), `stepper` (paramètre de
  /// `DynamicEdition`), `widget`/`custom` (seams ouverts AD-4).
  behavior,

  /// **Gap ASSUMÉ** (étiqueté ABSENT, jamais faux-rendu) : hors parité MVP ou
  /// banni par un invariant d'architecture (cf. `ShowcaseData.absentCapabilities`).
  assumedGap,
}

/// Une entrée de couverture : le [status] + une [note] (statut lisible, SM-2).
class TypeCoverage {
  /// Construit une entrée de couverture.
  const TypeCoverage(this.status, this.note);

  /// Statut connu (jamais « inconnu » — l'enum n'a pas de valeur d'ignorance).
  final CoverageStatus status;

  /// Justification lisible du statut (audit SM-4).
  final String note;
}

/// **Matrice de couverture EXHAUSTIVE** (fp-3-2, AC1) : un statut CONNU par
/// `EditionFieldType`. La complétude est prouvée par le test `showcase_exhaustive`
/// qui énumère `EditionFieldType.values` et exige `byType.containsKey(t)` pour
/// chaque `t` — la couverture vient donc de l'enum lui-même (46 aujourd'hui),
/// jamais d'un nombre figé.
abstract final class ShowcaseCoverage {
  /// Statut de couverture par type (les 46 valeurs de l'enum).
  static const Map<EditionFieldType, TypeCoverage> byType =
      <EditionFieldType, TypeCoverage>{
    // ── Familles NATIVES du cœur (liveNative) ──────────────────────────────
    EditionFieldType.text:
        TypeCoverage(CoverageStatus.liveNative, 'ZTextFieldWidget'),
    EditionFieldType.multiline:
        TypeCoverage(CoverageStatus.liveNative, 'ZTextFieldWidget (multi-ligne)'),
    EditionFieldType.number:
        TypeCoverage(CoverageStatus.liveNative, 'ZNumberFieldWidget'),
    EditionFieldType.integer:
        TypeCoverage(CoverageStatus.liveNative, 'ZNumberFieldWidget (int)'),
    EditionFieldType.float:
        TypeCoverage(CoverageStatus.liveNative, 'ZNumberFieldWidget (double)'),
    EditionFieldType.boolean:
        TypeCoverage(CoverageStatus.liveNative, 'ZBooleanFieldWidget'),
    EditionFieldType.dateTime:
        TypeCoverage(CoverageStatus.liveNative, 'ZDateFieldWidget'),
    EditionFieldType.time:
        TypeCoverage(CoverageStatus.liveNative, 'ZDateFieldWidget (heure)'),
    EditionFieldType.dateRange:
        TypeCoverage(CoverageStatus.liveNative, 'ZDateRangeFieldWidget (fp-1-1)'),
    EditionFieldType.select: TypeCoverage(
        CoverageStatus.liveNative, 'ZSelectFieldWidget (natif ; modal via seam)'),
    EditionFieldType.radio: TypeCoverage(
        CoverageStatus.liveNative, 'ZSelectFieldWidget (natif ; modal via seam)'),
    EditionFieldType.checkbox:
        TypeCoverage(CoverageStatus.liveNative, 'ZSelectFieldWidget'),
    EditionFieldType.relation: TypeCoverage(CoverageStatus.liveNative,
        'ZRelationFieldWidget (natif ; modal via ZSmartSelectPresenter)'),
    EditionFieldType.rowChips:
        TypeCoverage(CoverageStatus.liveNative, 'ZRowChipsFieldWidget'),
    EditionFieldType.tags:
        TypeCoverage(CoverageStatus.liveNative, 'ZTagsFieldWidget'),
    EditionFieldType.subItems:
        TypeCoverage(CoverageStatus.liveNative, 'ZSubListFieldWidget (réordo)'),
    EditionFieldType.dynamicItem:
        TypeCoverage(CoverageStatus.liveNative, 'ZDynamicItemFieldWidget'),
    EditionFieldType.file:
        TypeCoverage(CoverageStatus.liveNative, 'ZAppFileField'),
    EditionFieldType.image:
        TypeCoverage(CoverageStatus.liveNative, 'ZAppFileField (image native)'),
    EditionFieldType.document:
        TypeCoverage(CoverageStatus.liveNative, 'ZAppFileField (document)'),
    EditionFieldType.rating:
        TypeCoverage(CoverageStatus.liveNative, 'ZRatingFieldWidget'),
    EditionFieldType.slider:
        TypeCoverage(CoverageStatus.liveNative, 'ZSliderFieldWidget'),
    EditionFieldType.signature:
        TypeCoverage(CoverageStatus.liveNative, 'ZSignatureFieldWidget'),
    EditionFieldType.color: TypeCoverage(CoverageStatus.liveNative,
        'ZColorFieldWidget (simple) / ZColorMultiFieldWidget (multiple, fp-4-4)'),
    // ── Familles SATELLITES (liveSatellite) ────────────────────────────────
    EditionFieldType.location: TypeCoverage(
        CoverageStatus.liveSatellite, 'ZGeoFieldWidget (geo, coords-seules AD-12)'),
    EditionFieldType.geoArea: TypeCoverage(CoverageStatus.liveSatellite,
        'ZGeoFieldWidget (geo, wireGeoArea, fp-5-3)'),
    EditionFieldType.phoneNumber:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZPhoneFieldWidget (intl)'),
    EditionFieldType.country:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZCountryFieldWidget (intl)'),
    EditionFieldType.address:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZAddressFieldWidget (intl)'),
    EditionFieldType.markdown:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZMarkdownField'),
    EditionFieldType.inlineMarkdown:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZMarkdownField (inline)'),
    EditionFieldType.richText:
        TypeCoverage(CoverageStatus.liveSatellite, 'ZMarkdownField (Delta)'),
    EditionFieldType.html: TypeCoverage(CoverageStatus.liveSatellite,
        'ZHtmlView (lecture, fp-4-3 ; édition WYSIWYG ZHtmlEditorField runtime, '
        'non montable en test — ET-5)'),
    EditionFieldType.inlineHtml: TypeCoverage(CoverageStatus.liveSatellite,
        'ZHtmlView (lecture ; édition WYSIWYG ZHtmlEditorField runtime, ET-5)'),
    EditionFieldType.mediaImage: TypeCoverage(
        CoverageStatus.liveSatellite, 'ZMediaFieldWidget (image riche, fp-4-2)'),
    EditionFieldType.mediaFile: TypeCoverage(
        CoverageStatus.liveSatellite, 'ZMediaFieldWidget (fichier riche)'),
    EditionFieldType.mediaVideo: TypeCoverage(
        CoverageStatus.liveSatellite, 'ZMediaFieldWidget (vidéo riche)'),
    EditionFieldType.pin: TypeCoverage(
        CoverageStatus.liveSatellite, 'ZPinFieldWidget (field_extras, fp-5-2)'),
    EditionFieldType.autocomplete: TypeCoverage(CoverageStatus.liveSatellite,
        'ZAutocompleteFieldWidget (field_extras)'),
    EditionFieldType.editableTable: TypeCoverage(CoverageStatus.liveSatellite,
        'ZEditableTableFieldWidget (field_extras)'),
    // ── Comportements / seams (behavior) ───────────────────────────────────
    EditionFieldType.password: TypeCoverage(
        CoverageStatus.behavior, 'ZTextFieldWidget masqué (comportement text)'),
    EditionFieldType.hidden: TypeCoverage(
        CoverageStatus.behavior, 'Non rendu (valeur conservée, invisible)'),
    EditionFieldType.stepper: TypeCoverage(CoverageStatus.behavior,
        'Paramètre ZStepperConfig de DynamicEdition (pas une famille)'),
    EditionFieldType.widget: TypeCoverage(
        CoverageStatus.behavior, 'Seam widget libre (freeWidget, AD-4)'),
    EditionFieldType.custom: TypeCoverage(
        CoverageStatus.behavior, 'Valeur ouverte via ZTypeRegistry (AD-4)'),
    // ── Gaps ASSUMÉS (assumedGap) ──────────────────────────────────────────
    EditionFieldType.icon: TypeCoverage(CoverageStatus.assumedGap,
        'Picker d\'icône — hors parité MVP (FIELD-PACKAGE-MATRIX #29)'),
  };

  /// Statut d'un type (jamais `null` : la matrice couvre l'enum entier — l'accès
  /// `!` est un INVARIANT prouvé par le test d'exhaustivité).
  static TypeCoverage of(EditionFieldType type) => byType[type]!;
}
