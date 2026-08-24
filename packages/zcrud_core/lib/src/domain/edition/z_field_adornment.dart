/// `ZFieldAdornment` — ornement **déclaratif pur-données** d'un champ d'édition
/// (`leading`/`prefix`/`suffix`).
///
/// Un ornement dynamique dépendant de l'état du formulaire prendrait la forme
/// d'une **closure** — **non portable en pur-données** (invariants
/// AD-3/AD-14). zcrud exprime donc ces slots avec un **type-valeur `const`**
/// discriminé, résolu en `Widget` **côté présentation** :
/// - [ZFieldAdornment.text] — un texte littéral ou une clé l10n (résolu UI) ;
/// - [ZFieldAdornment.icon] — une **clé d'icône neutre** (`String`), résolue en
///   `Widget` côté présentation (jamais un `IconData` dans le domaine) ;
/// - [ZFieldAdornment.widget] — une **clé de registre** neutre servie via le
///   seam `ZcrudScope.widgetRegistry` (fourni par l'hôte), couvrant le cas
///   état-dépendant SANS closure sérialisée.
///
/// **Pur-Dart `const`** (couche `domain`, invariants AD-1/AD-3/AD-14) : aucun
/// `IconData`, aucun `Widget`, aucune closure, aucune dépendance Flutter. Un
/// seul payload `String` ([value]) discriminé par [kind]. Égalité de
/// **valeur** (`==`/`hashCode`/`toString`) — utile aux tests de projection et
/// à la mémoïsation runtime.
library;

/// Nature d'un [ZFieldAdornment] — discriminant du payload [ZFieldAdornment.value].
enum ZAdornmentKind {
  /// [ZFieldAdornment.value] est un **texte** (littéral ou clé l10n).
  text,

  /// [ZFieldAdornment.value] est une **clé d'icône neutre** (résolue côté UI).
  icon,

  /// [ZFieldAdornment.value] est une **clé de registre** de widget (servie par
  /// `ZcrudScope.widgetRegistry` — cas état-dépendant sans closure).
  widget,
}

/// Ornement `const` **pur-données** d'un champ (`leading`/`prefix`/`suffix`).
class ZFieldAdornment {
  const ZFieldAdornment._(this.kind, this.value, this.onTap);

  /// Ornement **texte** : [value] est un libellé littéral **ou** une clé l10n
  /// (résolu côté présentation via `label(context, value, fallback: value)`).
  const ZFieldAdornment.text(String value, {void Function()? onTap})
      : this._(ZAdornmentKind.text, value, onTap);

  /// Ornement **icône** : [iconKey] est une **clé neutre** (`String`) résolue en
  /// `Widget` côté présentation (table de correspondance / seam hôte) — jamais un
  /// `IconData` dans le domaine (invariants AD-3/AD-14).
  const ZFieldAdornment.icon(String iconKey, {void Function()? onTap})
      : this._(ZAdornmentKind.icon, iconKey, onTap);

  /// Ornement **widget** : [kind] est une **clé de registre** neutre résolue via
  /// `ZcrudScope.widgetRegistry.tryBuilderFor(kind)` — porte le cas
  /// état-dépendant SANS closure sérialisée.
  const ZFieldAdornment.widget(String kind, {void Function()? onTap})
      : this._(ZAdornmentKind.widget, kind, onTap);

  /// Discriminant du payload (voir [ZAdornmentKind]).
  final ZAdornmentKind kind;

  /// Payload unique (`String`) : texte/clé l10n, clé d'icône, ou clé de registre
  /// selon [kind].
  final String value;

  /// Geste **optionnel** de l'ornement.
  ///
  /// `null` (défaut) ⇒ l'ornement reste purement **décoratif**, rendu à
  /// l'identique. Non-`null` ⇒ la présentation l'enveloppe dans une cible
  /// tactile accessible (≥ 48 dp, sémantique de bouton) et appelle cette
  /// fonction au tap.
  ///
  /// Seul membre à porter une **closure** : il n'est donc pas émissible par le
  /// générateur (le schéma annoté reste pur-données) — c'est une surcharge
  /// posée à la main dans une spec runtime. Il est volontairement **exclu de
  /// `==`/`hashCode`** : deux ornements ne diffèrent jamais par l'identité
  /// d'une closure (même règle que `ZFieldSpec.derivedFrom`).
  final void Function()? onTap;

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
