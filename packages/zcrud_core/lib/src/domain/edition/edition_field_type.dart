/// Catalogue canonique des **types de champ** du moteur déclaratif `zcrud`
/// (FR-2). Un même `EditionFieldType` pilote à la fois le widget d'édition
/// (`DynamicEdition`, E3) et la colonne de liste (`DynamicList`, E4).
///
/// origine: catalogue de parité DODLP — `docs/technical-inventory.md` §3
/// (tableau « Type », référence unique de la checklist de parité SM-2).
/// Vit dans `zcrud_core` (couche `domain`, pur-Dart) — architecture.md:141
/// (« enum canonique des champs = `EditionFieldType` ») et architecture.md:232
/// (« Catalogue de champs (FR-2) → `zcrud_core` »). Placer cet enum dans
/// `zcrud_annotations` forcerait l'arête interdite `zcrud_core →
/// zcrud_annotations` (AD-1, cœur OUT=0) : impossible.
library;

/// Type déclaratif d'un champ du schéma `zcrud` (source unique authoring ↔
/// runtime : référencé par `@ZcrudField.type` en authoring et par le futur
/// `ZFieldSpec.type` en runtime, émis par E2-5).
///
/// **Enum ouvert (AD-4)** : la valeur [custom] absorbe toute extension de type
/// projetée par une app hôte. Pour toute (dé)sérialisation d'introspection
/// future, appliquer la discipline `@JsonKey(unknownEnumValue: custom)` (les
/// valeurs d'enum restent en camelCase — canonique §5). L'enum lui-même n'est
/// pas persisté en E2-4 ; la discipline est posée pour l'aval.
///
/// **Résolution du widget déférée** : certains types ont leur widget hors du
/// cœur ([markdown]/[inlineMarkdown]/[richText] → E6 ; [geoArea]/[location] →
/// zcrud_geo/E11a ; [phoneNumber]/[country]/[address] → zcrud_intl/E11a). L'enum
/// les **nomme** ; leur widget est servi runtime via `ZTypeRegistry` (E3-3b).
///
/// **Cas limites documentés (technical-inventory §3)** :
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

  /// Choix unique dans une liste d'options statiques (`select`).
  select,

  /// Choix unique exposé en boutons radio.
  radio,

  /// Choix multiple exposé en cases à cocher.
  checkbox,

  /// Relation vers une autre entité (DODLP `crudDataSelect`) : la source
  /// (repository/stream) est câblée au runtime (E4/ports E2-2), jamais dans
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

  /// Zone géographique (point/polygone/cercle) — widget en zcrud_geo (E11a).
  geoArea,

  /// Numéro de téléphone international — widget en zcrud_intl (E11a).
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

  /// Markdown riche (bloc) — widget en zcrud_markdown (E6).
  markdown,

  /// Markdown en ligne — widget en zcrud_markdown (E6).
  inlineMarkdown,

  /// HTML riche (bloc).
  html,

  /// HTML en ligne.
  inlineHtml,

  /// Texte riche (Delta interne) — widget en zcrud_markdown (E6).
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
