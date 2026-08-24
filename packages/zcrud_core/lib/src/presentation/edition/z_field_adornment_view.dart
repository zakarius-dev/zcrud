/// Résolveur de présentation d'un [ZFieldAdornment] **pur-données** en `Widget?`
/// — traduit le slot déclaratif `leading`/`prefix`/`suffix` en un widget
/// thémé, **défensivement** (invariant AD-10).
///
/// Frontière domaine/présentation : le domaine ne porte qu'une **donnée** neutre
/// (`ZFieldAdornment`, discriminée `text`/`icon`/`widget` avec un payload
/// `String`). La **résolution** vit ici :
/// - `.text` → `Text` thémé (résolution l10n via `label`, style dérivé du thème
///   — aucune couleur en dur, invariant FR-26) ;
/// - `.icon` → `Icon` résolue via un **seam neutre** (`ZcrudScope.iconResolver`
///   host-fourni) puis une **table Material bornée** du cœur ; clé inconnue ⇒
///   `null` (jamais de throw) — aucun `IconData` ne fuit dans le domaine ;
/// - `.widget` → builder host-fourni via `ZcrudScope.widgetRegistry`
///   (`tryBuilderFor(kind)`) ; `kind` non enregistré ⇒ `null` (dégradation
///   propre). Couvre le cas état-dépendant d'un ornement qui **dépend du champ
///   qu'il orne** ou d'un champ voisin : le dispatcher lui passe la **valeur
///   courante** de la tranche ornée et le **lecteur nommé** `valueOf` (via
///   `ZFieldWidgetContext`) — jamais une closure sérialisée dans le domaine
///   (invariants AD-3/AD-14). L'ornement reste en **lecture seule** : son
///   `onChanged` est inerte.
///
/// Invariant AD-2 : ces résolutions sont des **fonctions pures cheap** (aucune
/// allocation de `TextEditingController`/`FocusNode`, aucun `Listenable`) — elles
/// se font dans la construction **statique** de la décoration.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../domain/edition/z_field_adornment.dart';
import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_gradient_resolver.dart';
import '../theme/z_readable_tint.dart';
import '../theme/z_theme.dart';
import '../zcrud_scope.dart';
import 'z_field_label.dart';
import 'z_widget_registry.dart';

/// Résolveur d'icône **host-fourni** : traduit une **clé neutre** (`String`) en
/// `IconData`, ou `null` si la clé est inconnue de l'hôte (le cœur retombe alors
/// sur sa table Material par défaut, puis `null` — invariant AD-10). Injecté
/// via `ZcrudScope.iconResolver`. Le domaine ne porte JAMAIS d'`IconData`
/// (invariant AD-3).
typedef ZAdornmentIconResolver = IconData? Function(String key);

/// Table Material **bornée** par défaut du cœur (repli si aucun
/// [ZcrudScope.iconResolver] n'est injecté ou ne connaît pas la clé). Clés
/// neutres alignées sur les usages de formulaire courants. Clé absente
/// ⇒ `null` (slot omis, jamais de throw — invariant AD-10).
const Map<String, IconData> _defaultIconTable = <String, IconData>{
  'search': Icons.search,
  'email': Icons.email_outlined,
  'phone': Icons.phone_outlined,
  'calendar': Icons.calendar_today_outlined,
  'date': Icons.event_outlined,
  'time': Icons.access_time_outlined,
  'person': Icons.person_outline,
  'lock': Icons.lock_outline,
  'info': Icons.info_outline,
  'warning': Icons.warning_amber_outlined,
  'check': Icons.check,
  'close': Icons.close,
  'add': Icons.add,
  'edit': Icons.edit_outlined,
  'delete': Icons.delete_outline,
  'money': Icons.attach_money,
  'percent': Icons.percent_outlined,
  'location': Icons.location_on_outlined,
  'link': Icons.link_outlined,
  'star': Icons.star_outline,
  'visibility': Icons.visibility_outlined,
  'visibility_off': Icons.visibility_off_outlined,
  'clear': Icons.clear,
  'copy': Icons.copy_outlined,
};

/// Résout un [IconData] pour une clé neutre : seam host ([ZcrudScope.iconResolver])
/// **prioritaire**, puis la table [_defaultIconTable], sinon `null` (invariant
/// AD-10).
IconData? zResolveAdornmentIcon(BuildContext context, String key) =>
    ZcrudScope.maybeOf(context)?.iconResolver?.call(key) ??
    _defaultIconTable[key];

/// Traduit [adornment] en `Widget?` **défensivement** (invariant AD-10) pour
/// le [field] décoré. `null` (adornment absent OU clé non résolue) ⇒ aucun
/// slot rendu.
///
/// [valueOf] est le **lecteur nommé** du formulaire hôte (typiquement fourni
/// par le dispatcher de champ). Il sert un ornement `.widget` de deux façons :
/// la **valeur courante** du champ orné (`valueOf(field.name)`, exposée en
/// `ZFieldWidgetContext.value`) et la lecture d'un **autre** champ. Omis
/// (`null`), l'ornement est rendu sans valeur — c'est le cas d'une composition
/// hors formulaire, et le comportement des ornements `.text`/`.icon` est
/// inchangé dans tous les cas.
///
/// Aucune couleur en dur (invariant FR-26) : le texte hérite du `TextTheme`,
/// l'icône du `IconTheme` ambiant. Les insets éventuels sont directionnels
/// (invariant AD-13).
Widget? resolveAdornment(
  BuildContext context,
  ZFieldAdornment? adornment, {
  required ZFieldSpec field,
  ZValueOf? valueOf,
}) {
  if (adornment == null) return null;
  final Widget? resolved;
  switch (adornment.kind) {
    case ZAdornmentKind.text:
      final text = label(context, adornment.value, fallback: adornment.value);
      resolved = Text(
        text,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    case ZAdornmentKind.icon:
      final data = zResolveAdornmentIcon(context, adornment.value);
      // Clé inconnue ⇒ slot omis (jamais de throw — invariant AD-10).
      resolved = data == null ? null : Icon(data);
    case ZAdornmentKind.widget:
      // Cas état-dépendant : l'ornement reçoit la valeur COURANTE du champ
      // qu'il orne et le lecteur nommé des autres champs. `onChanged` reste
      // inerte — un ornement est un affichage (display-only).
      final builder =
          ZcrudScope.maybeOf(context)?.widgetRegistry?.tryBuilderFor(adornment.value);
      resolved = builder == null
          ? null
          : builder(
              context,
              ZFieldWidgetContext(
                field: field,
                value: valueOf?.call(field.name),
                onChanged: _noop,
                valueOf: valueOf,
              ),
            );
  }
  if (resolved == null) return null;
  final onTap = adornment.onTap;
  // Sans `onTap`, l'ornement reste purement DÉCORATIF : arbre strictement
  // identique à l'antérieur (additif — aucun wrapper, aucune sémantique
  // ajoutée).
  if (onTap == null) return resolved;
  // Ornement INTERACTIF : cible tactile accessible ≥ 48 dp + sémantique de
  // bouton (AD-13). Une icône passe par `IconButton` (contraintes 48 dp
  // natives, splash standard) ; texte/widget par une cible `InkWell` bornée.
  if (adornment.kind == ZAdornmentKind.icon) {
    return IconButton(onPressed: onTap, icon: resolved);
  }
  return Semantics(
    button: true,
    container: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        child: Center(child: resolved),
      ),
    ),
  );
}

/// `onChanged` inerte pour un ornement `.widget` (display-only) : un ornement
/// n'écrit jamais la tranche.
void _noop(Object? _) {}

/// Construit la décoration **enrichie** d'une famille décor-portante :
/// label enrichi ([ZFieldLabel]), `hintText`/`helperText` résolus
/// l10n, et ornements `leading`/`prefix`/`suffix` répartis dans les slots
/// `InputDecoration` selon leur `ZAdornmentKind` (`.icon` → `prefixIcon`/
/// `suffixIcon` ; `.text`/`.widget` → `prefix`/`suffix` ; `leading` → `icon`).
///
/// En mode [bare] (Card large) : **aucun label** (porté par la Card) et
/// `leading`/`suffix` sont **omis** (le dispatcher les branche sur les slots
/// `ZLargeFieldCard.leading`/`.suffix`) ; seul le `prefix` **interne** subsiste.
///
/// [valueOf] est transmis tel quel aux ornements `.widget` (voir
/// [resolveAdornment]) : il leur donne la valeur du champ décoré et la lecture
/// nommée de ses voisins. Omis, la décoration est exactement celle d'avant.
///
/// Résolution **statique** et **défensive** (invariants AD-2/AD-10) :
/// fonctions pures cheap, aucune allocation de contrôleur/`Listenable`,
/// aucune couleur en dur (invariant FR-26).
InputDecoration zFieldDecoration(
  BuildContext context,
  ZFieldSpec field, {
  bool bare = false,
  String? errorText,
  String? suffixText,
  ZValueOf? valueOf,
  Widget? suffixIconOverride,
}) {
  final tokens = ZcrudTheme.of(context);
  // Teinte PAR TYPE DE CHAMP — strictement opt-in : elle n'existe que si le
  // résolveur de dégradé du scope répond à la clé `zFieldTypeTintKey(type)`.
  // Aucun résolveur / clé non servie ⇒ `tint == null` et la décoration est
  // celle d'avant, au pixel près. Une couleur servie est NORMALISÉE pour le
  // contraste contre la surface du champ (`zReadableTintOn`, plancher
  // non-texte WCAG §1.4.11), thème clair comme sombre — jamais une couleur
  // illisible appliquée telle quelle.
  Color? tint;
  if (!bare) {
    final tintSpec = zResolveGradient(context, zFieldTypeTintKey(field.type));
    if (tintSpec != null) {
      final surface = tokens.fieldFillColor ??
          Theme.of(context).colorScheme.surfaceContainerHighest;
      final colors = tintSpec.gradient.colors;
      final base = colors.isNotEmpty ? colors.first : tintSpec.onGradient;
      tint = zReadableTintOn(base, surface: surface);
    }
  }
  String? l10n(String? key) =>
      key == null ? null : label(context, key, fallback: key);

  // `leading` → tête hors bordure (`icon`). Omis en `bare` (porté par la Card).
  final leadingIcon = bare
      ? null
      : resolveAdornment(context, field.leading,
          field: field, valueOf: valueOf);

  Widget? prefix;
  Widget? prefixIcon;
  final p = field.prefix;
  if (p != null) {
    final w = resolveAdornment(context, p, field: field, valueOf: valueOf);
    if (w != null) {
      if (p.kind == ZAdornmentKind.icon) {
        prefixIcon = w;
      } else {
        prefix = w;
      }
    }
  }

  Widget? suffix;
  Widget? suffixIcon;
  // `suffix` interne en normal ; en `bare` il est porté par la Card (dispatcher).
  final s = bare ? null : field.suffix;
  if (s != null) {
    final w = resolveAdornment(context, s, field: field, valueOf: valueOf);
    if (w != null) {
      if (s.kind == ZAdornmentKind.icon) {
        suffixIcon = w;
      } else {
        suffix = w;
      }
    }
  }
  // Slot `suffixIcon` fourni par la FAMILLE (œil du mot de passe) : il prime
  // sur un ornement `.icon` déclaré — le geste de la famille ne doit jamais
  // être évincé par un décor.
  if (suffixIconOverride != null) suffixIcon = suffixIconOverride;

  return tokens.inputDecoration(
    context,
    labelWidget: bare ? null : ZFieldLabel(field: field),
    hintText: l10n(field.hintText),
    helperText: l10n(field.helperText),
    errorText: errorText,
    bare: bare,
    leadingIcon: leadingIcon,
    prefix: prefix,
    prefixIcon: prefixIcon,
    suffix: suffix,
    suffixIcon: suffixIcon,
    // Suffixe monétaire/pourcentage NEUTRE (donnée, jamais un style —
    // invariant FR-26). `InputDecoration` interdit `suffix` (widget) ET
    // `suffixText` simultanément (assertion Flutter) : un ornement `suffix`
    // déclaratif l'emporte donc sur le `suffixText` (cas rarissime d'un
    // champ portant les deux). `suffixIcon` + `suffixText` restent
    // compatibles.
    suffixText: suffix != null ? null : suffixText,
    tintColor: tint,
  );
}
