/// Classification **exhaustive** des [EditionFieldType] en **familles de rendu**.
/// Pilote le dispatcher `ZFieldWidget` : chaque type est routé vers la
/// famille de widget qui sait le rendre (ou vers le repli contrôlé).
///
/// Les **familles de base** (texte/nombre/date/booléen/select/relation) et
/// `hidden` ont chacune un widget dédié. Les **familles-feuilles simples**
/// (`tags`/`rowChips`/`rating`/`slider`/`color`) et la famille de **point
/// d'extension** [EditionFamily.registryOrFallback] (markdown/géo/tél/
/// `icon`/`custom` — servis par un `ZWidgetRegistry` injecté, sinon repli)
/// suivent le même principe. Les **familles-feuilles imbriquées**
/// [EditionFamily.subList] (`subItems`) et [EditionFamily.dynamicItem]
/// (`dynamicItem` — mini-CRUD imbriqué) recomposent leur propre tranche.
/// Le **rendu custom** couvre [EditionFamily.signature] (`signature` —
/// capture gestuelle, value-in-slice) et [EditionFamily.freeWidget]
/// (`widget` — widget libre host-fourni via `ZWidgetRegistry`, repli si non
/// enregistré). La famille dédiée [EditionFamily.file] (`file`/`image`/
/// `document` — `ZAppFileField`, seams picker/storage injectés) couvre les
/// pièces jointes. Le reste (`stepper`, regroupement multi-étapes plutôt
/// qu'un champ-feuille) reste classé [EditionFamily.unsupported] → **repli
/// contrôlé** (`ZUnsupportedFieldWidget`), jamais un crash.
///
/// **INVARIANT (0 default)** : [familyOf] est un `switch` **exhaustif** sur
/// `EditionFieldType` **SANS clause `default:`**. Un futur `EditionFieldType`
/// non classé **casse la COMPILATION** de cette fonction — garde-fou de parité
/// (aucune famille de base ne peut « tomber » silencieusement dans le repli).
///
/// Pur-présentation, aucune dépendance lourde (invariants AD-1/AD-15) : ne
/// pilote QUE le choix du sous-arbre de rendu ; ne touche ni la tranche, ni
/// la validation.
library;

import '../../domain/edition/edition_field_type.dart';

/// Famille de **rendu** d'un champ d'édition.
///
/// Les six premières valeurs sont les **familles de base** servies par un widget
/// dédié ; [hidden] rend un widget zéro-taille ; [unsupported] est le **repli
/// contrôlé** (registre / hors-parité) — jamais une exception.
enum EditionFamily {
  /// `text` / `multiline` / `password` — `TextFormField` (contrôleur stable).
  text,

  /// `number` / `integer` / `float` — champ numérique typé (contrôleur stable).
  number,

  /// `dateTime` / `time` — déclencheur de picker directionnel, valeur ISO-8601.
  date,

  /// `dateRange` — déclencheur de picker de **plage** directionnel
  /// (`showDateRangePicker`), valeur `ZDateRange{start, end}`.
  dateRange,

  /// `boolean` — `Switch`/toggle avec état sémantique.
  boolean,

  /// `select` / `radio` / `checkbox` — options depuis `ZFieldSpec.choices`.
  select,

  /// `relation` — sélecteur d'entité liée (source **injectable**).
  relation,

  /// `tags` — saisie multi-valeur à puces (`List<String>` en tranche).
  tags,

  /// `rowChips` — rangée de puces **mono-choix** depuis `choices`.
  rowChips,

  /// `rating` — note en étoiles/segments (`num` en tranche).
  rating,

  /// `slider` — `Slider` borné (`num` en tranche).
  slider,

  /// `color` — sélecteur de couleur (`int` ARGB en tranche).
  color,

  /// `subItems` — **mini-CRUD imbriqué** : `List<Map>` d'items édités par un
  /// slice imbriqué (add/remove/reorder, invariant AD-2).
  subList,

  /// `dynamicItem` — item unique dynamique (`Map?` add/edit/clear, slice
  /// imbriqué, invariant AD-2).
  dynamicItem,

  /// `signature` — capture gestuelle (strokes normalisés encodés en tranche,
  /// `CustomPaint`/gesture Flutter natif, AUCUNE dépendance lourde — invariant
  /// AD-13).
  signature,

  /// `widget` — **widget libre** host-fourni via un `ZWidgetRegistry` injecté
  /// si le `kind` `'widget'` est enregistré, **sinon repli**
  /// `ZUnsupportedFieldWidget` (invariant AD-4). Même seam que
  /// [registryOrFallback] ; le cœur reste agnostique du widget métier.
  freeWidget,

  /// Type servi **ailleurs** (markdown/géo/tél/`icon`/`custom`) : rendu par un
  /// **`ZWidgetRegistry`** injecté si le `kind` est enregistré, **sinon repli**
  /// `ZUnsupportedFieldWidget` (invariant AD-4). Le cœur reste agnostique du
  /// package satellite (graphe OUT=0 inchangé).
  registryOrFallback,

  /// `file` / `image` / `document` — champ **fichier** value-in-slice
  /// (`ZAppFileField`) : boutons d'action (scan/caméra/galerie/picker)
  /// servis par un `ZFilePicker` injecté, prévisualisation + états d'upload
  /// reflétés via un `CloudStorageRepository` injecté (repli propre si `null` :
  /// actions désactivées / fichier `pending`). AUCUNE dépendance lourde
  /// (invariant AD-1).
  file,

  /// `hidden` — champ **non rendu** (`SizedBox.shrink`), jamais un crash.
  hidden,

  /// Type non encore servi ici (`stepper`, regroupement multi-étapes) — **repli
  /// contrôlé** `ZUnsupportedFieldWidget`, jamais une exception.
  unsupported,
}

/// Classe [type] dans sa [EditionFamily] de rendu.
///
/// `switch` **exhaustif SANS `default:`** : toutes les valeurs sont énumérées ;
/// ajouter un `EditionFieldType` sans le classer ici **casse la compilation**.
EditionFamily familyOf(EditionFieldType type) {
  switch (type) {
    // ── Familles de base (widget dédié) ─────────────────────────────────────
    case EditionFieldType.text:
    case EditionFieldType.multiline:
    case EditionFieldType.password:
      return EditionFamily.text;

    case EditionFieldType.number:
    case EditionFieldType.integer:
    case EditionFieldType.float:
      return EditionFamily.number;

    case EditionFieldType.dateTime:
    case EditionFieldType.time:
      return EditionFamily.date;

    case EditionFieldType.dateRange:
      return EditionFamily.dateRange;

    case EditionFieldType.boolean:
      return EditionFamily.boolean;

    case EditionFieldType.select:
    case EditionFieldType.radio:
    case EditionFieldType.checkbox:
      return EditionFamily.select;

    case EditionFieldType.relation:
      return EditionFamily.relation;

    // ── Familles-feuilles avancées (widget dédié value-in-slice) ────────────
    case EditionFieldType.tags:
      return EditionFamily.tags;

    case EditionFieldType.rowChips:
      return EditionFamily.rowChips;

    case EditionFieldType.rating:
      return EditionFamily.rating;

    case EditionFieldType.slider:
      return EditionFamily.slider;

    case EditionFieldType.color:
      return EditionFamily.color;

    // ── Familles-feuilles imbriquées (mini-CRUD, canal structurel) ───────────
    case EditionFieldType.subItems:
      return EditionFamily.subList;

    case EditionFieldType.dynamicItem:
      return EditionFamily.dynamicItem;

    // ── Rendu custom ─────────────────────────────────────────────────────────
    // `signature` = capture gestuelle (widget dédié, value-in-slice) ;
    // `widget` = widget libre host-fourni via `ZWidgetRegistry` (même seam que
    // `registryOrFallback`, repli si non enregistré).
    case EditionFieldType.signature:
      return EditionFamily.signature;

    case EditionFieldType.widget:
      return EditionFamily.freeWidget;

    // ── Point d'extension : widget servi AILLEURS via `ZWidgetRegistry` ──────
    // markdown/HTML/richText, géo/tél/pays/adresse, `icon` hors-parité MVP,
    // `custom` → app hôte (invariant AD-4). Le dispatcher tente le registre
    // injecté, sinon repli contrôlé. Le cœur n'importe AUCUN de ces packages
    // (graphe OUT=0 inchangé).
    case EditionFieldType.markdown:
    case EditionFieldType.inlineMarkdown:
    case EditionFieldType.html:
    case EditionFieldType.inlineHtml:
    case EditionFieldType.richText:
    case EditionFieldType.location:
    case EditionFieldType.geoArea:
    case EditionFieldType.phoneNumber:
    case EditionFieldType.country:
    case EditionFieldType.address:
    case EditionFieldType.icon:
    // `pin`/`autocomplete`/`editableTable` = types NOMMÉS au cœur, valeurs
    // NEUTRES (String/String/List<Map>), widget riche servi par un package
    // satellite via `ZWidgetRegistry`. Aucune nouvelle `EditionFamily`, aucun
    // widget natif : repli `ZUnsupportedFieldWidget` tant que le `kind`
    // n'est pas enregistré. Cœur OUT=0 préservé.
    case EditionFieldType.pin:
    case EditionFieldType.autocomplete:
    case EditionFieldType.editableTable:
    // `mediaImage`/`mediaFile`/`mediaVideo` = types NOMMÉS au cœur, valeurs
    // NEUTRES (`AppFile`/liste), widget riche (drop-zone/ouverture/vignette)
    // servi par un package satellite (`registerZMediaFieldWidgets`) via
    // `ZWidgetRegistry` sous `kind == type.name`. Repli
    // `ZUnsupportedFieldWidget` tant que non enregistré (invariant AD-10).
    // Aucune dépendance média dans le cœur (invariant AD-1, CORE OUT=0).
    // Distincts des types natifs `image`/`file`/`document` (famille `file`,
    // `ZAppFileField`).
    case EditionFieldType.mediaImage:
    case EditionFieldType.mediaFile:
    case EditionFieldType.mediaVideo:
    case EditionFieldType.custom:
      return EditionFamily.registryOrFallback;

    // ── Famille fichier (widget dédié value-in-slice) ────────────────────────
    // `file`/`image`/`document` → `ZAppFileField` (picker/storage injectés).
    case EditionFieldType.file:
    case EditionFieldType.image:
    case EditionFieldType.document:
      return EditionFamily.file;

    // ── Non rendu ───────────────────────────────────────────────────────────
    case EditionFieldType.hidden:
      return EditionFamily.hidden;

    // ── Repli contrôlé ───────────────────────────────────────────────────────
    // `stepper` (regroupement multi-étapes, PAS un champ-feuille) reste le
    // SEUL type en repli accessible.
    case EditionFieldType.stepper:
      return EditionFamily.unsupported;
  }
}

/// `true` si la [family] s'édite au **clavier** et requiert un
/// `TextEditingController` **stable** (texte & nombre) — les autres familles
/// lisent/écrivent la tranche sans contrôleur de texte (invariant AD-2).
bool familyUsesTextController(EditionFamily family) =>
    family == EditionFamily.text || family == EditionFamily.number;
