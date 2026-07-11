/// `ZFieldAdornment` — ornement **déclaratif pur-données** d'un champ d'édition
/// (DP-12, parité DODLP M1 : `leading`/`preffix`/`suffix`).
///
/// origine: DODLP porte par champ des slots `leading`/`preffix`/`preffixText`/
/// `preffixIcon`/`suffix`/`suffixText`/`suffixIcon` (`models.dart:742-752`). Le
/// `suffix` DODLP est une **closure** état-dépendante
/// (`Widget? Function(Map<String,dynamic> editionState)`) — **NON portable en
/// pur-données** (AD-3/AD-14). zcrud remplace ces slots par un **type-valeur
/// `const`** discriminé, résolu en `Widget` **côté présentation** :
/// - [ZFieldAdornment.text] — un texte littéral ou une clé l10n (résolu UI) ;
/// - [ZFieldAdornment.icon] — une **clé d'icône neutre** (`String`), résolue en
///   `Widget` côté présentation (jamais un `IconData` dans le domaine) ;
/// - [ZFieldAdornment.widget] — une **clé de registre** neutre servie via le
///   seam `ZcrudScope.widgetRegistry` (host-fourni), couvrant le cas
///   état-dépendant DODLP (`suffix(editionState)`) SANS closure sérialisée.
///
/// **Pur-Dart `const`** (couche `domain`, AD-1/AD-3/AD-14, garde
/// `domain_purity_test.dart`) : aucun `IconData`, aucun `Widget`, aucune closure,
/// aucune dépendance Flutter. Un seul payload `String` ([value]) discriminé par
/// [kind]. Égalité de **valeur** (`==`/`hashCode`/`toString`) — utile aux tests
/// de projection (E2-5) et à la mémoïsation runtime (E3).
library;

/// Nature d'un [ZFieldAdornment] — discriminant du payload [ZFieldAdornment.value].
enum ZAdornmentKind {
  /// [ZFieldAdornment.value] est un **texte** (littéral ou clé l10n).
  text,

  /// [ZFieldAdornment.value] est une **clé d'icône neutre** (résolue côté UI).
  icon,

  /// [ZFieldAdornment.value] est une **clé de registre** de widget (servie par
  /// `ZcrudScope.widgetRegistry` — cas état-dépendant DODLP sans closure).
  widget,
}

/// Ornement `const` **pur-données** d'un champ (`leading`/`prefix`/`suffix`).
class ZFieldAdornment {
  const ZFieldAdornment._(this.kind, this.value);

  /// Ornement **texte** : [value] est un libellé littéral **ou** une clé l10n
  /// (résolu côté présentation via `label(context, value, fallback: value)`).
  const ZFieldAdornment.text(String value) : this._(ZAdornmentKind.text, value);

  /// Ornement **icône** : [iconKey] est une **clé neutre** (`String`) résolue en
  /// `Widget` côté présentation (table de correspondance / seam host) — jamais un
  /// `IconData` dans le domaine (AD-3/AD-14).
  const ZFieldAdornment.icon(String iconKey)
      : this._(ZAdornmentKind.icon, iconKey);

  /// Ornement **widget** : [kind] est une **clé de registre** neutre résolue via
  /// `ZcrudScope.widgetRegistry.tryBuilderFor(kind)` — porte le cas
  /// état-dépendant DODLP (`suffix(editionState)`) SANS closure sérialisée.
  const ZFieldAdornment.widget(String kind)
      : this._(ZAdornmentKind.widget, kind);

  /// Discriminant du payload (voir [ZAdornmentKind]).
  final ZAdornmentKind kind;

  /// Payload unique (`String`) : texte/clé l10n, clé d'icône, ou clé de registre
  /// selon [kind].
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldAdornment &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, kind, value);

  @override
  String toString() => 'ZFieldAdornment(${kind.name}: $value)';
}
