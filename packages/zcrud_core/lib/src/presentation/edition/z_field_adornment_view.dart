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
      // Taille pilotée par le jeton `adornmentIconSize` — canal de DIMENSION
      // pur : `null` ⇒ `Icon(data, size: null)`, strictement le widget
      // d'avant (le `IconTheme` ambiant décide). Appliquée ICI (à la
      // construction du glyphe) et jamais par `IconTheme.merge` : le verrou
      // structurel du socle réserve ce duo d'enveloppes à
      // `ZForegroundOverride`.
      resolved = data == null
          ? null
          : Icon(data, size: ZcrudTheme.of(context).adornmentIconSize);
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

/// Résout la couleur servie par le résolveur du scope pour [key], NORMALISÉE
/// pour le contraste contre la surface du champ. `null` si la chaîne ne sert
/// rien (aucun scope, aucun résolveur, clé non servie).
Color? _tintForKey(BuildContext context, String key) {
  final tintSpec = zResolveGradient(context, key);
  if (tintSpec == null) return null;
  final surface = ZcrudTheme.of(context).fieldFillColor ??
      Theme.of(context).colorScheme.surfaceContainerHighest;
  final colors = tintSpec.gradient.colors;
  final base = colors.isNotEmpty ? colors.first : tintSpec.onGradient;
  return zReadableTintOn(base, surface: surface);
}

/// **Teinte par type de champ** de [field], prête à peindre — ou `null`.
///
/// C'est la teinte que la décoration native applique à la bordure de focus, au
/// libellé flottant et aux icônes d'ornement. Strictement **opt-in** : elle
/// n'existe que si le résolveur de dégradé du scope
/// ([ZcrudScope.gradientResolver]) répond à la clé
/// [zFieldTypeTintKey]`(field.type)`. Aucun résolveur / clé non servie ⇒
/// `null` — l'appelant ne peint alors rien de plus.
///
/// Une couleur servie n'est **jamais rendue telle quelle** : elle est
/// NORMALISÉE pour le contraste (plancher non-texte WCAG §1.4.11, 3.0:1)
/// contre la surface du champ (`ZcrudTheme.fieldFillColor`, repli
/// `ColorScheme.surfaceContainerHighest`), thème clair comme sombre.
///
/// Fonction pure cheap (invariant AD-2) : appelable dans un `build`.
Color? zResolveFieldTint(BuildContext context, ZFieldSpec field) =>
    _tintForKey(context, zFieldTypeTintKey(field.type));

/// Couleur de la **barre d'accent supérieure** de [field] — ou `null`.
///
/// Deux sources, dans cet ordre de priorité :
/// 1. une couleur déclarée **champ par champ** par le résolveur du scope sous
///    la clé [zFieldAccentKey]`(field.name)` ;
/// 2. à défaut, la **teinte par type** ([zResolveFieldTint]).
///
/// Même normalisation de contraste que [zResolveFieldTint]. `null` (aucune
/// source) ⇒ aucune barre : le rendu du champ est strictement inchangé.
Color? zResolveFieldAccent(BuildContext context, ZFieldSpec field) =>
    _tintForKey(context, zFieldAccentKey(field.name)) ??
    zResolveFieldTint(context, field);

/// Ornement résolu pour un **présentateur riche** : la teinte normalisée du
/// champ et le widget d'ornement prêt à poser sur une tuile.
///
/// Voir [zResolveTintedAdornment] pour le contrat complet.
@immutable
class ZTintedAdornment {
  /// Construit le résultat immuable d'une résolution d'ornement teinté.
  const ZTintedAdornment({this.tint, this.child});

  /// Teinte du champ, **déjà normalisée** pour le contraste contre la surface
  /// du champ ([zResolveFieldTint]) — `null` si aucun résolveur ne la sert.
  /// Utilisable telle quelle par le présentateur pour ses propres canaux
  /// d'accent (bordure, libellé), sans re-normaliser.
  final Color? tint;

  /// Ornement prêt à poser : glyphe teinté, enveloppé de sa pastille quand
  /// les jetons la déclarent — `null` si l'ornement est absent ou si sa clé
  /// ne se résout pas (invariant AD-10, jamais de throw).
  final Widget? child;
}

/// Résout, pour un **présentateur riche** (tuile de sélection, carte…),
/// l'ornement [adornment] de [field] avec la même chaîne de teinte et de
/// pastille que la décoration native — sans que l'appelant duplique ni la
/// résolution de clé, ni la normalisation de contraste, ni la gouvernance des
/// jetons.
///
/// **Entrées** : le [context] (le scope y fournit résolveur d'icônes,
/// résolveur de dégradé et thème), l'[adornment] à résoudre (typiquement
/// `field.leading`), la [field] décorée, et l'éventuel lecteur nommé [valueOf]
/// (transmis aux ornements `.widget`, cf. [resolveAdornment]).
///
/// **Ce qui est rendu** :
/// * [ZTintedAdornment.tint] — la teinte par type du champ, normalisée
///   (plancher non-texte WCAG §1.4.11 contre la surface du champ), ou `null`
///   sans résolveur : rien n'est inventé.
/// * [ZTintedAdornment.child] — l'ornement résolu. Un ornement **icône
///   décoratif** porte la teinte sur son glyphe et, si les jetons
///   `adornmentIconBackgroundAlpha`/`adornmentIconBackgroundRadius` sont
///   posés **et** qu'une teinte existe, sa pastille de fond (teinte atténuée
///   par l'alpha, insets directionnels) ; `adornmentIconSize` dimensionne le
///   glyphe. Un ornement **interactif** (`onTap`) reste un `IconButton` nu
///   (cible ≥ 48 dp) — jamais pastillé. Les ornements `.text`/`.widget` sont
///   rendus comme par [resolveAdornment], sans teinte imposée.
///
/// **Ce qui reste à l'appelant** : poser le widget (placement, espacement,
/// sémantique de la tuile), décider de ses propres surfaces — et ne PAS
/// re-teinter [ZTintedAdornment.child], qui porte déjà sa couleur.
///
/// [backgroundAlpha] permet à un présentateur d'atténuer la pastille pour
/// signaler un **état** (typiquement : le champ ne porte pas encore de
/// valeur). Il **ne crée jamais** de pastille : sans le jeton
/// `adornmentIconBackgroundAlpha`, l'ornement reste nu, exactement comme sans
/// ce paramètre. `null` ⇒ l'alpha du jeton, inchangé.
ZTintedAdornment zResolveTintedAdornment(
  BuildContext context,
  ZFieldAdornment? adornment, {
  required ZFieldSpec field,
  ZValueOf? valueOf,
  double? backgroundAlpha,
}) {
  final Color? tint = zResolveFieldTint(context, field);
  if (adornment == null) return ZTintedAdornment(tint: tint);
  Widget? child;
  if (adornment.kind == ZAdornmentKind.icon && adornment.onTap == null) {
    // Icône DÉCORATIVE : le glyphe est construit ici pour porter la teinte
    // directement (`Icon.color`) — hors d'une `InputDecoration`, aucun
    // `iconColor` ne la porterait. Jamais par `IconTheme.merge` : le verrou
    // structurel du socle réserve ce duo d'enveloppes à `ZForegroundOverride`.
    final data = zResolveAdornmentIcon(context, adornment.value);
    if (data != null) {
      final tokens = ZcrudTheme.of(context);
      final icon =
          Icon(data, size: tokens.adornmentIconSize, color: tint);
      child = _maybeIconPill(
        icon,
        adornment,
        tint,
        tokens,
        alphaOverride: backgroundAlpha,
      );
    }
  } else {
    child = resolveAdornment(context, adornment, field: field, valueOf: valueOf);
  }
  return ZTintedAdornment(tint: tint, child: child);
}

// Retrait interne de la pastille d'ornement icône, de chaque côté du glyphe.
// Constante de DIMENSION (pas une couleur — FR-26 ne porte que sur les
// couleurs) : le côté rendu de la pastille vaut `adornmentIconSize + 2 × 7`
// (18 dp de glyphe ⇒ pastille de 32 dp, la géométrie de référence des
// captures). L'hôte pilote donc le côté final via `adornmentIconSize`.
const double _kAdornmentIconPillInset = 7.0;

/// Enveloppe un ornement **icône décoratif** dans sa « pastille » de fond —
/// un aplat de la teinte par type de champ atténué par
/// `ZcrudTheme.adornmentIconBackgroundAlpha`, arrondi par
/// `adornmentIconBackgroundRadius`.
///
/// Strictement opt-in, dans les DEUX directions :
/// - jeton d'alpha absent ⇒ [icon] rendu tel quel, aucun conteneur ajouté à
///   l'arbre — y compris quand l'appelant demande une atténuation d'état ;
/// - `tint == null` (aucune teinte résolue pour le champ) ⇒ idem : le fond n'a
///   pas d'autre source de couleur, une pastille « neutre » serait une couleur
///   inventée (invariant FR-26) — les jetons seuls ne peignent RIEN.
///
/// Un ornement **interactif** (`onTap` déclaré) n'est pas enveloppé : il est
/// déjà rendu en `IconButton` (cible ≥ 48 dp, splash natif — invariant AD-13)
/// et la pastille, purement décorative, ne doit ni doubler cette affordance ni
/// en réduire la cible.
Widget _maybeIconPill(
  Widget icon,
  ZFieldAdornment adornment,
  Color? tint,
  ZcrudTheme tokens, {
  double? alphaOverride,
}) {
  final double? posed = tokens.adornmentIconBackgroundAlpha;
  if (posed == null || tint == null || adornment.onTap != null) return icon;
  // L'atténuation d'ÉTAT ne se substitue qu'à la VALEUR de l'alpha, jamais à
  // la condition d'existence : c'est le jeton, et lui seul, qui décide qu'il y
  // a une pastille. Sans lui, un appelant qui demande une atténuation obtient
  // toujours l'icône nue — l'opt-in reste entier dans les deux directions.
  final double alpha = alphaOverride ?? posed;
  final Radius? radius = tokens.adornmentIconBackgroundRadius;
  // `Center` : la pastille ÉPOUSE le glyphe au centre du slot `prefixIcon`/
  // `suffixIcon` (contraint à ≥ 48 dp par `InputDecoration`) au lieu de
  // s'étirer — la cible et la géométrie du slot sont inchangées (AD-13).
  // La teinte est DÉJÀ normalisée pour le contraste par l'appelant ; l'alpha
  // ne fait qu'atténuer le fond, le glyphe par-dessus garde la teinte pleine
  // (c'est lui qui porte la lisibilité, via `prefixIconColor`/
  // `suffixIconColor`).
  return Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: alpha),
        borderRadius: radius == null ? null : BorderRadius.all(radius),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(_kAdornmentIconPillInset),
        child: icon,
      ),
    ),
  );
}

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
  // Teinte PAR TYPE DE CHAMP — strictement opt-in (voir [zResolveFieldTint]).
  // En `bare` (Card large), le canal n'existe pas : décoration inchangée.
  final Color? tint = bare ? null : zResolveFieldTint(context, field);
  String? l10n(String? key) =>
      key == null ? null : label(context, key, fallback: key);

  // `leading` → tête hors bordure (`icon`). Omis en `bare` (porté par la
  // Card). Un ornement ICÔNE y reçoit la même pastille que `prefixIcon`/
  // `suffixIcon` (mêmes jetons, même teinte, même gouvernance — la teinte du
  // glyphe passe par `InputDecoration.iconColor`).
  Widget? leadingIcon;
  final lead = bare ? null : field.leading;
  if (lead != null) {
    final w = resolveAdornment(context, lead, field: field, valueOf: valueOf);
    if (w != null) {
      leadingIcon = lead.kind == ZAdornmentKind.icon
          ? _maybeIconPill(w, lead, tint, tokens)
          : w;
    }
  }

  Widget? prefix;
  Widget? prefixIcon;
  final p = field.prefix;
  if (p != null) {
    final w = resolveAdornment(context, p, field: field, valueOf: valueOf);
    if (w != null) {
      if (p.kind == ZAdornmentKind.icon) {
        prefixIcon = _maybeIconPill(w, p, tint, tokens);
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
        suffixIcon = _maybeIconPill(w, s, tint, tokens);
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
