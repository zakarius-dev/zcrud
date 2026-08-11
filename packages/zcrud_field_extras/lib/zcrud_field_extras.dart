/// Barrel d'API publique de `zcrud_field_extras` — satellite CHAMPS SPÉCIALISÉS.
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
/// proprement en `ZUnsupportedFieldWidget` (invariant AD-10) — jamais un
/// crash.
///
/// ## Limite de persistance — `editableTable` en mémoire uniquement
///
/// La valeur d'une table éditable est `List<Map<String, dynamic>>`. Le widget
/// l'édite pleinement **en mémoire**, mais **la persistance via `@ZcrudModel`
/// d'un tel champ N'EST PAS supportée par le générateur** actuel : il lève
/// une erreur de génération sur un élément `Map` sans branche de
/// classification dédiée. Un type de valeur dédié avec son propre codec de
/// (dé)sérialisation serait requis pour lever cette limite.
///
/// ## « Tags riches » non couvert
///
/// `EditionFieldType.tags` route vers la famille NATIVE `tags` (pas
/// `registryOrFallback`) : un builder sous `kind == 'tags'` serait du **code
/// mort** jamais atteint par le dispatcher. Le besoin « tag + icône + toggle »
/// est déjà couvert **zéro-dép** par `ZSubListDisplayMode.tags`. Un chemin
/// dispatcher-atteignable exigerait un nouveau type d'enum cœur (`richTags`
/// routé `registryOrFallback`).
///
/// **Isolation (invariant AD-1)** : la seule dépendance lourde (`pinput`) est
/// confinée à `lib/src/` ; l'arête `zcrud_*` sortante unique est
/// `zcrud_core`.
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
