/// Résolveur de présentation d'un [ZFieldAdornment] **pur-données** en `Widget?`
/// (DP-12, M1) — traduit le slot déclaratif `leading`/`prefix`/`suffix` en un
/// widget thémé, **défensivement** (AD-10).
///
/// Frontière domaine/présentation : le domaine ne porte qu'une **donnée** neutre
/// (`ZFieldAdornment`, discriminée `text`/`icon`/`widget` avec un payload
/// `String`). La **résolution** vit ici :
/// - `.text` → `Text` thémé (résolution l10n via `label`, style dérivé du thème
///   — aucune couleur en dur, FR-26) ;
/// - `.icon` → `Icon` résolue via un **seam neutre** (`ZcrudScope.iconResolver`
///   host-fourni) puis une **table Material bornée** du cœur ; clé inconnue ⇒
///   `null` (jamais de throw) — aucun `IconData` ne fuit dans le domaine ;
/// - `.widget` → builder host-fourni via `ZcrudScope.widgetRegistry`
///   (`tryBuilderFor(kind)`) ; `kind` non enregistré ⇒ `null` (dégradation
///   propre). Porte le cas état-dépendant DODLP (`suffix(editionState)`) : le
///   widget host **lit l'état lui-même** via son `context`/scope — jamais une
///   closure sérialisée dans le domaine (AD-3/AD-14).
///
/// SM-1/AD-2 : ces résolutions sont des **fonctions pures cheap** (aucune
/// allocation de `TextEditingController`/`FocusNode`, aucun `Listenable`) — elles
/// se font dans la construction **statique** de la décoration.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_field_adornment.dart';
import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_theme.dart';
import '../zcrud_scope.dart';
import 'z_field_label.dart';
import 'z_widget_registry.dart';

/// Résolveur d'icône **host-fourni** : traduit une **clé neutre** (`String`) en
/// `IconData`, ou `null` si la clé est inconnue de l'hôte (le cœur retombe alors
/// sur sa table Material par défaut, puis `null` — AD-10). Injecté via
/// `ZcrudScope.iconResolver`. Le domaine ne porte JAMAIS d'`IconData` (AD-3).
typedef ZAdornmentIconResolver = IconData? Function(String key);

/// Table Material **bornée** par défaut du cœur (repli si aucun
/// [ZcrudScope.iconResolver] n'est injecté ou ne connaît pas la clé). Clés
/// neutres alignées sur les usages de formulaire courants (DODLP). Clé absente
/// ⇒ `null` (slot omis, jamais de throw — AD-10).
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
/// **prioritaire**, puis la table [_defaultIconTable], sinon `null` (AD-10).
IconData? zResolveAdornmentIcon(BuildContext context, String key) =>
    ZcrudScope.maybeOf(context)?.iconResolver?.call(key) ??
    _defaultIconTable[key];

/// Traduit [adornment] en `Widget?` **défensivement** (AD-10) pour le [field]
/// décoré. `null` (adornment absent OU clé non résolue) ⇒ aucun slot rendu.
///
/// Aucune couleur en dur (FR-26) : le texte hérite du `TextTheme`, l'icône du
/// `IconTheme` ambiant. Les insets éventuels sont directionnels (AD-13).
Widget? resolveAdornment(
  BuildContext context,
  ZFieldAdornment? adornment, {
  required ZFieldSpec field,
}) {
  if (adornment == null) return null;
  switch (adornment.kind) {
    case ZAdornmentKind.text:
      final text = label(context, adornment.value, fallback: adornment.value);
      return Text(
        text,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    case ZAdornmentKind.icon:
      final data = zResolveAdornmentIcon(context, adornment.value);
      // Clé inconnue ⇒ slot omis (jamais de throw — AD-10).
      return data == null ? null : Icon(data);
    case ZAdornmentKind.widget:
      // Cas état-dépendant DODLP (`suffix(editionState)`) : le widget host lit
      // l'état via son propre context/scope. `value`/`onChanged` ne portent pas
      // de sémantique d'édition pour un ornement décoratif (display-only).
      final builder =
          ZcrudScope.maybeOf(context)?.widgetRegistry?.tryBuilderFor(adornment.value);
      if (builder == null) return null;
      return builder(
        context,
        ZFieldWidgetContext(
          field: field,
          value: null,
          onChanged: _noop,
        ),
      );
  }
}

/// `onChanged` inerte pour un ornement `.widget` (display-only) : un ornement
/// n'écrit jamais la tranche (parité DODLP `suffix` décoratif).
void _noop(Object? _) {}

/// Construit la décoration **enrichie** d'une famille décor-portante (DP-12,
/// M1/M5/M6) : label enrichi ([ZFieldLabel]), `hintText`/`helperText` résolus
/// l10n, et ornements `leading`/`prefix`/`suffix` répartis dans les slots
/// `InputDecoration` selon leur `ZAdornmentKind` (`.icon` → `prefixIcon`/
/// `suffixIcon` ; `.text`/`.widget` → `prefix`/`suffix` ; `leading` → `icon`).
///
/// En mode [bare] (Card large, AC4) : **aucun label** (porté par la Card) et
/// `leading`/`suffix` sont **omis** (le dispatcher les branche sur les slots
/// `ZLargeFieldCard.leading`/`.suffix`) ; seul le `prefix` **interne** subsiste.
///
/// Résolution **statique** et **défensive** (AD-2/AD-10) : fonctions pures cheap,
/// aucune allocation de contrôleur/`Listenable`, aucune couleur en dur (FR-26).
InputDecoration zFieldDecoration(
  BuildContext context,
  ZFieldSpec field, {
  bool bare = false,
  String? errorText,
  String? suffixText,
}) {
  final tokens = ZcrudTheme.of(context);
  String? l10n(String? key) =>
      key == null ? null : label(context, key, fallback: key);

  // `leading` → tête hors bordure (`icon`). Omis en `bare` (porté par la Card).
  final leadingIcon =
      bare ? null : resolveAdornment(context, field.leading, field: field);

  Widget? prefix;
  Widget? prefixIcon;
  final p = field.prefix;
  if (p != null) {
    final w = resolveAdornment(context, p, field: field);
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
    final w = resolveAdornment(context, s, field: field);
    if (w != null) {
      if (s.kind == ZAdornmentKind.icon) {
        suffixIcon = w;
      } else {
        suffix = w;
      }
    }
  }

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
    // DP-17 (M17) : suffixe monétaire/pourcentage NEUTRE (donnée, jamais un
    // style FR-26). `InputDecoration` interdit `suffix` (widget) ET `suffixText`
    // simultanément (assertion Flutter) : un ornement `suffix` déclaratif (DP-12)
    // l'emporte donc sur le `suffixText` (garde DP-12-L1, cas rarissime d'un champ
    // portant les deux). `suffixIcon` + `suffixText` restent compatibles.
    suffixText: suffix != null ? null : suffixText,
  );
}
