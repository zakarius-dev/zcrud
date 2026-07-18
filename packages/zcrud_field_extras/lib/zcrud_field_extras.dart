/// Barrel d'API publique de `zcrud_field_extras` — satellite CHAMPS SPÉCIALISÉS
/// (fp-5-2, AD-53).
///
/// Fournit trois widgets d'édition **riches**, servis par `ZWidgetRegistry` et
/// enrôlés par [registerZFieldExtrasFields] (patron `registerZMediaFieldWidgets`),
/// sous des `kind` **alignés sur les noms d'`EditionFieldType`** que le
/// dispatcher cœur route vers `registryOrFallback` :
///
/// - **PIN / OTP** ([ZPinFieldWidget], kind [pinFieldKind] = `'pin'`) — segments
///   via `pinput` (SEULE dép lourde, confinée à ce satellite).
/// - **Autocomplétion** ([ZAutocompleteFieldWidget], kind [autocompleteFieldKind]
///   = `'autocomplete'`) — widget **natif Flutter `Autocomplete`** (zéro dép).
/// - **Table éditable** ([ZEditableTableFieldWidget], kind
///   [editableTableFieldKind] = `'editableTable'`) — virtualisée
///   (`ListView.builder`), **runtime-only** (cf. limite de persistance ci-dessous).
///
/// ## Séquence de câblage (côté binding/app — enrôlement EXPLICITE)
///
/// ```dart
/// final registry = ZWidgetRegistry();
/// registerZFieldExtrasFields(registry);
/// ZcrudScope(widgetRegistry: registry, child: ...)
/// ```
///
/// Sans cet enrôlement, un champ `pin`/`autocomplete`/`editableTable` dégrade
/// proprement en `ZUnsupportedFieldWidget` (AD-10) — jamais un crash.
///
/// ## ⚠️ SIGNAL 1 — persistance `editableTable` (SUIVI hors fp-5-2)
///
/// La valeur d'une table éditable est `List<Map<String, dynamic>>`. Le widget
/// l'édite pleinement **en mémoire**, mais **la persistance via `@ZcrudModel`
/// d'un tel champ N'EST PAS supportée par le générateur** (limite préexistante
/// découverte en fp-5-1 : `InvalidGenerationSourceError` sur un élément `Map`).
/// Un **type de valeur dédié + codec** est un SUIVI (story cœur/générateur).
///
/// ## ⚠️ SIGNAL 2 — « tags riches » NON livré (décision owner requise, AC-D)
///
/// `EditionFieldType.tags` route vers la famille NATIVE `tags` (pas
/// `registryOrFallback`) : un builder sous `kind == 'tags'` serait du **code
/// mort** jamais atteint par le dispatcher. Le besoin « tag + icône + toggle »
/// est déjà couvert **zéro-dép** par `ZSubListDisplayMode.tags` (fp-5-1).
/// `flutter_tags`/`drag_and_drop_lists` sont **rejetés par l'étude** (morts dans
/// DODLP). Un chemin dispatcher-atteignable exigerait un NOUVEAU type d'enum
/// cœur (`richTags` routé `registryOrFallback`) = story cœur ultérieure.
///
/// 🔴 **Isolation (AD-1)** : la seule dép lourde (`pinput`) est confinée à
/// `lib/src/` ; l'arête `zcrud_*` sortante unique est `zcrud_core` (CORE OUT=0,
/// garde `test/z_field_extras_confinement_test.dart` + `graph_proof.py`).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_autocomplete_field_widget.dart'
    show ZAutocompleteFieldWidget, autocompleteFieldKind;
export 'src/presentation/z_editable_table_field_widget.dart'
    show
        ZEditableTableFieldWidget,
        editableTableFieldKind,
        kZTableDefaultColumn,
        zParseTableRows,
        zTableColumns;
export 'src/presentation/z_field_extras_registrar.dart'
    show registerZFieldExtrasFields;
export 'src/presentation/z_pin_field_widget.dart'
    show
        ZPinFieldWidget,
        kZPinCellMinSize,
        kZPinDefaultLength,
        pinFieldKind,
        zPinLengthOf;
