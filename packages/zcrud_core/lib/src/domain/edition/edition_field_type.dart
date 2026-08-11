/// Catalogue canonique des **types de champ** du moteur déclaratif `zcrud`.
/// Un même `EditionFieldType` pilote à la fois le widget d'édition
/// (`DynamicEdition`) et la colonne de liste (`DynamicList`).
///
/// Vit dans `zcrud_core` (couche `domain`, pur-Dart) : c'est l'enum canonique
/// des types de champ de tout l'écosystème. Le placer dans
/// `zcrud_annotations` forcerait l'arête interdite `zcrud_core →
/// zcrud_annotations` (invariant AD-1, le cœur n'a aucune dépendance
/// `zcrud_*` sortante) : impossible.
library;

/// Type déclaratif d'un champ du schéma `zcrud` — source unique entre le
/// modèle annoté (`@ZcrudField.type`) et le schéma runtime (`ZFieldSpec.type`,
/// produit par le générateur).
///
/// **Enum ouvert (invariant AD-4)** : la valeur [custom] absorbe toute
/// extension de type projetée par une app hôte. Pour toute (dé)sérialisation
/// d'introspection future, appliquer la discipline
/// `@JsonKey(unknownEnumValue: custom)` (les valeurs d'enum restent en
/// camelCase). L'enum lui-même n'est pas persisté.
///
/// **Résolution du widget déférée** : certains types ont leur widget hors du
/// cœur ([markdown]/[inlineMarkdown]/[richText] dans `zcrud_markdown` ;
/// [geoArea]/[location] dans `zcrud_geo` ; [phoneNumber]/[country]/[address]
/// dans `zcrud_intl`). L'enum les **nomme** ; leur widget est servi au runtime
/// via `ZTypeRegistry`.
///
/// **Cas limites documentés** :
/// - [icon] : **hors parité MVP** (non implémenté à la source ; déclaré comme
///   valeur, fallback au rendu).
/// - [password] : `text` + validateur (valeur d'enum distincte, **pas** de
///   widget dédié — masquage seul).
/// - [hidden] : champ **non rendu** (comportement conservé, pas un widget).
/// - [widget] : builder libre — la closure `(state, readOnly, …) → Widget`
///   **n'entre pas** dans l'annotation `const` ; elle est attachée au runtime
///   via `ZTypeRegistry` / la config de champ. L'enum ne fait que **nommer** ce
///   type.
enum EditionFieldType {
  /// Texte court mono-ligne (`TextFormField`).
  text,

  /// Texte multi-ligne (`minLines`/`maxLines`).
  multiline,

  /// Nombre générique (`num`).
  number,

  /// Entier (`int`).
  integer,

  /// Décimal (`double`/`float`).
  float,

  /// Booléen (switch/toggle).
  boolean,

  /// Date + heure (picker).
  dateTime,

  /// Heure seule (picker).
  time,

  /// Plage de dates `{start, end}` (picker de plage). Valeur [ZDateRange]
  /// sérialisée `{'start', 'end'}` ISO-8601, invariant `end >= start` (AD-47).
  dateRange,

  /// Choix unique dans une liste d'options statiques (`select`).
  select,

  /// Choix unique exposé en boutons radio.
  radio,

  /// Choix multiple exposé en cases à cocher.
  checkbox,

  /// Relation vers une autre entité : la source
  /// (repository/stream) est câblée au runtime, jamais dans
  /// l'annotation `const`.
  relation,

  /// Puces horizontales (`rowChips`).
  rowChips,

  /// Étiquettes en saisie libre (`tags`).
  tags,

  /// Liste imbriquée (mini-CRUD `subItems`).
  subItems,

  /// Sous-formulaire dynamique (`dynamicItem` / `DeepAttribute`).
  dynamicItem,

  /// Fichier générique.
  file,

  /// Image.
  image,

  /// Document.
  document,

  /// Point géographique.
  location,

  /// Zone géographique (point/polygone/cercle) — widget en zcrud_geo.
  geoArea,

  /// Numéro de téléphone international — widget en zcrud_intl.
  phoneNumber,

  /// Pays (picker).
  country,

  /// Adresse postale / recherche d'adresse.
  address,

  /// Note en étoiles.
  rating,

  /// Curseur (`Slider`).
  slider,

  /// Signature manuscrite.
  signature,

  /// Couleur (color picker).
  color,

  /// Icône — **hors parité MVP** (déclaré, fallback).
  icon,

  /// Code PIN / OTP (saisie segmentée). Valeur **neutre** `String` (AD-53).
  /// **Widget servi ailleurs** : `zcrud_field_extras` via
  /// `ZWidgetRegistry` ; tant que le `kind` n'est pas enregistré, le champ
  /// dégrade proprement en `ZUnsupportedFieldWidget` (jamais un crash). Le cœur
  /// ne **nomme** que le type (famille `registryOrFallback`) — aucune dépendance
  /// lourde tirée ici (invariant AD-1).
  pin,

  /// Saisie **auto-complétée** (champ texte + suggestions). Valeur **neutre**
  /// `String` (AD-53). **Widget servi ailleurs** : `zcrud_field_extras`
  /// via `ZWidgetRegistry` ; repli `ZUnsupportedFieldWidget` tant que
  /// non enregistré. Le cœur ne nomme que le type (famille `registryOrFallback`,
  /// aucune dépendance lourde — AD-1).
  autocomplete,

  /// Table **éditable** (grille de lignes/colonnes). Valeur **neutre**
  /// `List<Map<String, dynamic>>` (AD-53). **Widget servi ailleurs** :
  /// `zcrud_field_extras` via `ZWidgetRegistry` ;
  /// repli `ZUnsupportedFieldWidget` tant que non enregistré. Le cœur ne nomme
  /// que le type (famille `registryOrFallback`, aucune dépendance lourde —
  /// AD-1).
  editableTable,

  /// **Image RICHE** (drop-zone + ouverture + aperçu). Valeur **neutre** :
  /// `AppFile?` (mono) ou `List<AppFile>` (multiple) — AUCUN type plateforme
  /// (AD-40). **Widget servi ailleurs** : `zcrud_media`
  /// (`registerZMediaFieldWidgets`) via `ZWidgetRegistry` sous le `kind`
  /// [name] (`'mediaImage'`) ; tant que le `kind` n'est pas enregistré, le
  /// champ dégrade proprement en `ZUnsupportedFieldWidget` (jamais un crash,
  /// AD-10). Le cœur ne **nomme** que le type (famille `registryOrFallback`) —
  /// aucune dépendance média lourde tirée ici (invariant AD-1). Distinct du
  /// type natif [image] (routé, lui, vers `ZAppFileField`).
  mediaImage,

  /// **Fichier/document RICHE** (drop-zone + ouverture au tap). Valeur
  /// **neutre** `AppFile?`/`List<AppFile>` (AD-40). **Widget servi ailleurs** :
  /// `zcrud_media` via `ZWidgetRegistry` sous le `kind` [name]
  /// (`'mediaFile'`) ; repli `ZUnsupportedFieldWidget` tant que non enregistré
  /// (AD-10). Famille `registryOrFallback`, aucune dépendance lourde (AD-1).
  mediaFile,

  /// **Vidéo RICHE** (drop-zone + vignette générée, type neutre `Uint8List`).
  /// Valeur **neutre** `AppFile?`/`List<AppFile>` (AD-40). **Widget servi
  /// ailleurs** : `zcrud_media` via `ZWidgetRegistry` sous le `kind` [name]
  /// (`'mediaVideo'`) ; repli `ZUnsupportedFieldWidget` tant que non
  /// enregistré (AD-10). Famille `registryOrFallback`, aucune dépendance
  /// lourde (AD-1).
  mediaVideo,

  /// Markdown riche (bloc) — widget en zcrud_markdown.
  markdown,

  /// Markdown en ligne — widget en zcrud_markdown.
  inlineMarkdown,

  /// HTML riche (bloc).
  html,

  /// HTML en ligne.
  inlineHtml,

  /// Texte riche (Delta interne) — widget en zcrud_markdown.
  richText,

  /// Regroupement multi-étapes (`stepper`).
  stepper,

  /// Mot de passe : `text` masqué + validateur (pas de widget dédié).
  password,

  /// Champ **non rendu** (valeur conservée mais invisible).
  hidden,

  /// Builder de widget libre : la closure est **attachée au runtime**
  /// (`ZTypeRegistry` / config), jamais dans l'annotation `const`.
  widget,

  /// **Valeur ouverte (AD-4)** : type projeté par une app hôte, résolu via
  /// `ZTypeRegistry`. Cible de `@JsonKey(unknownEnumValue: custom)` pour toute
  /// introspection future.
  custom,
}
