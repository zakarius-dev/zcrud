/// Classification **exhaustive** des [EditionFieldType] en **familles de rendu**
/// (E3-3a). Pilote le dispatcher `ZFieldWidget` : chaque type est routé vers la
/// famille de widget qui sait le rendre (ou vers le repli contrôlé).
///
/// origine: frontière E3-3a / E3-3b / E3-3c (story E3-3a, table de frontière).
/// E3-3a a traité les **familles de base** (texte/nombre/date/booléen/select/
/// relation) + `hidden` ; **E3-3b sous-story -1** ajoute les **familles-feuilles
/// simples** (`tags`/`rowChips`/`rating`/`slider`/`color`) + la famille de
/// **point d'extension** [EditionFamily.registryOrFallback] (markdown/géo/tél/
/// `icon`/`custom` — servis par un `ZWidgetRegistry` injecté, sinon repli) ;
/// **E3-3b sous-story -2** ajoute les **familles-feuilles imbriquées**
/// [EditionFamily.subList] (`subItems`) et [EditionFamily.dynamicItem]
/// (`dynamicItem` — mini-CRUD imbriqué, SM-1 imbriqué) ; **E3-3b sous-story -3**
/// ajoute le **rendu custom** [EditionFamily.signature] (`signature` — capture
/// gestuelle, value-in-slice) et [EditionFamily.freeWidget] (`widget` — widget
/// libre host-fourni via `ZWidgetRegistry`, repli si non enregistré). Le
/// **E3-3c** ajoute la famille dédiée [EditionFamily.file] (`file`/`image`/
/// `document` — `ZAppFileField`, seams picker/storage injectés). Le reste
/// (`stepper` → E3-5, regroupement multi-étapes) reste classé
/// [EditionFamily.unsupported] → **repli contrôlé** (`ZUnsupportedFieldWidget`),
/// jamais un crash.
///
/// **INVARIANT AC2 (0 default)** : [familyOf] est un `switch` **exhaustif** sur
/// `EditionFieldType` **SANS clause `default:`**. Un futur `EditionFieldType`
/// non classé **casse la COMPILATION** de cette fonction — garde-fou de parité
/// (aucune famille de base ne peut « tomber » silencieusement dans le repli).
///
/// Pur-présentation, aucune dépendance lourde (AD-1/AD-15) : ne pilote QUE le
/// choix du sous-arbre de rendu ; ne touche ni la tranche, ni la validation.
library;

import '../../domain/edition/edition_field_type.dart';

/// Famille de **rendu** d'un champ d'édition (E3-3a).
///
/// Les six premières valeurs sont les **familles de base** servies par un widget
/// dédié ; [hidden] rend un widget zéro-taille ; [unsupported] est le **repli
/// contrôlé** (E3-3b/E3-3c/registre/hors-parité) — jamais une exception.
enum EditionFamily {
  /// `text` / `multiline` / `password` — `TextFormField` (contrôleur stable).
  text,

  /// `number` / `integer` / `float` — champ numérique typé (contrôleur stable).
  number,

  /// `dateTime` / `time` — déclencheur de picker directionnel, valeur ISO-8601.
  date,

  /// `dateRange` — déclencheur de picker de **plage** directionnel
  /// (`showDateRangePicker`), valeur `ZDateRange{start, end}` (AD-47).
  dateRange,

  /// `boolean` — `Switch`/toggle avec état sémantique.
  boolean,

  /// `select` / `radio` / `checkbox` — options depuis `ZFieldSpec.choices`.
  select,

  /// `relation` — sélecteur d'entité liée (source **injectable**, câblage E4).
  relation,

  /// `tags` — saisie multi-valeur à puces (`List<String>` en tranche, E3-3b-1).
  tags,

  /// `rowChips` — rangée de puces **mono-choix** depuis `choices` (E3-3b-1).
  rowChips,

  /// `rating` — note en étoiles/segments (`num` en tranche, E3-3b-1).
  rating,

  /// `slider` — `Slider` borné (`num` en tranche, E3-3b-1).
  slider,

  /// `color` — sélecteur de couleur (`int` ARGB en tranche, E3-3b-1).
  color,

  /// `subItems` — **mini-CRUD imbriqué** : `List<Map>` d'items édités par un
  /// slice imbriqué (add/remove/reorder, SM-1 imbriqué — E3-3b-2, AD-2).
  subList,

  /// `dynamicItem` — item unique dynamique (`Map?` add/edit/clear, slice
  /// imbriqué — E3-3b-2, AD-2).
  dynamicItem,

  /// `signature` — capture gestuelle (strokes normalisés encodés en tranche,
  /// `CustomPaint`/gesture Flutter natif, AUCUNE dépendance lourde — E3-3b-3,
  /// AD-13).
  signature,

  /// `widget` — **widget libre** host-fourni via un `ZWidgetRegistry` injecté
  /// si le `kind` `'widget'` est enregistré, **sinon repli**
  /// `ZUnsupportedFieldWidget` (E3-3b-3, AD-4). Même seam que
  /// [registryOrFallback] ; le cœur reste agnostique du widget métier.
  freeWidget,

  /// Type servi **ailleurs** (markdown/géo/tél/`icon`/`custom`) : rendu par un
  /// **`ZWidgetRegistry`** injecté si le `kind` est enregistré, **sinon repli**
  /// `ZUnsupportedFieldWidget` (E3-3b-1, AD-4). Le cœur reste agnostique du
  /// package satellite (graphe OUT=0 inchangé).
  registryOrFallback,

  /// `file` / `image` / `document` — champ **fichier** value-in-slice
  /// (`ZAppFileField`, E3-3c) : boutons d'action (scan/caméra/galerie/picker)
  /// servis par un `ZFilePicker` injecté, prévisualisation + états d'upload
  /// reflétés via un `CloudStorageRepository` injecté (repli propre si `null` :
  /// actions désactivées / fichier `pending`). AUCUNE dépendance lourde (AD-1).
  file,

  /// `hidden` — champ **non rendu** (`SizedBox.shrink`), jamais un crash.
  hidden,

  /// Type non encore servi ici (`stepper` → E3-5) — **repli contrôlé**
  /// `ZUnsupportedFieldWidget`, jamais une exception.
  unsupported,
}

/// Classe [type] dans sa [EditionFamily] de rendu (E3-3a).
///
/// `switch` **exhaustif SANS `default:`** (AC2) : toutes les valeurs sont énumérées ;
/// ajouter un `EditionFieldType` sans le classer ici **casse la compilation**.
EditionFamily familyOf(EditionFieldType type) {
  switch (type) {
    // ── Familles de base (E3-3a — widget dédié) ────────────────────────────
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

    // ── Familles-feuilles avancées (E3-3b-1 — widget dédié value-in-slice) ───
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

    // ── Familles-feuilles imbriquées (E3-3b-2 — mini-CRUD, SM-1 imbriqué) ────
    case EditionFieldType.subItems:
      return EditionFamily.subList;

    case EditionFieldType.dynamicItem:
      return EditionFamily.dynamicItem;

    // ── Rendu custom (E3-3b-3) ──────────────────────────────────────────────
    // `signature` = capture gestuelle (widget dédié, value-in-slice) ;
    // `widget` = widget libre host-fourni via `ZWidgetRegistry` (même seam que
    // `registryOrFallback`, repli si non enregistré).
    case EditionFieldType.signature:
      return EditionFamily.signature;

    case EditionFieldType.widget:
      return EditionFamily.freeWidget;

    // ── Point d'extension : widget servi AILLEURS via `ZWidgetRegistry` ──────
    // markdown/HTML/richText → E6 ; géo/tél/pays/adresse → E11a ; `icon`
    // hors-parité MVP ; `custom` → app hôte (AD-4). Le dispatcher tente le
    // registre injecté, sinon repli contrôlé. Le cœur n'importe AUCUN de ces
    // packages (graphe OUT=0 inchangé).
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
    // fp-5-1 (AD-52/AD-53) : `pin`/`autocomplete`/`editableTable` = types
    // NOMMÉS au cœur, valeurs NEUTRES (String/String/List<Map>), widget riche
    // servi par `zcrud_field_extras` (fp-5-2) via `ZWidgetRegistry`. Aucune
    // nouvelle `EditionFamily`, aucun widget natif : repli `ZUnsupportedFieldWidget`
    // tant que le `kind` n'est pas enregistré (AD-53/OQ-6). Cœur OUT=0 préservé.
    case EditionFieldType.pin:
    case EditionFieldType.autocomplete:
    case EditionFieldType.editableTable:
    // fp-4-2 (MAJEUR-1) : `mediaImage`/`mediaFile`/`mediaVideo` = types NOMMÉS
    // au cœur, valeurs NEUTRES (`AppFile`/liste — AD-40), widget riche
    // (drop-zone/ouverture/vignette) servi par `zcrud_media`
    // (`registerZMediaFieldWidgets`) via `ZWidgetRegistry` sous `kind == type.name`.
    // Repli `ZUnsupportedFieldWidget` tant que non enregistré (AD-10). Aucune
    // dépendance média dans le cœur (AD-1, CORE OUT=0). Distincts des types
    // natifs `image`/`file`/`document` (famille `file`, `ZAppFileField`).
    case EditionFieldType.mediaImage:
    case EditionFieldType.mediaFile:
    case EditionFieldType.mediaVideo:
    case EditionFieldType.custom:
      return EditionFamily.registryOrFallback;

    // ── Famille fichier (E3-3c — widget dédié value-in-slice) ────────────────
    // `file`/`image`/`document` → `ZAppFileField` (picker/storage injectés).
    case EditionFieldType.file:
    case EditionFieldType.image:
    case EditionFieldType.document:
      return EditionFamily.file;

    // ── Non rendu ───────────────────────────────────────────────────────────
    case EditionFieldType.hidden:
      return EditionFamily.hidden;

    // ── Repli contrôlé ───────────────────────────────────────────────────────
    // `stepper` → E3-5 (regroupement multi-étapes, PAS un champ-feuille) ; reste
    // le SEUL type en repli accessible jusqu'à sa story.
    case EditionFieldType.stepper:
      return EditionFamily.unsupported;
  }
}

/// `true` si la [family] s'édite au **clavier** et requiert un
/// `TextEditingController` **stable** (texte & nombre) — les autres familles
/// lisent/écrivent la tranche sans contrôleur de texte (AD-2).
bool familyUsesTextController(EditionFamily family) =>
    family == EditionFamily.text || family == EditionFamily.number;
