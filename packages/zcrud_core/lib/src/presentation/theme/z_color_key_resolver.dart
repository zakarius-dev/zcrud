/// Seam de résolution `colorKey (String) → couleur` — **jumeau réel** du
/// précédent `ZAdornmentIconResolver`/`zResolveAdornmentIcon`
/// (`z_field_adornment_view.dart`) (ES-1.2, D1, AC3 ; corrige M2/M3/M4 du
/// code-review ES-1.2).
///
/// ## Le motif copié (et pourquoi)
///
/// Le précédent icône expose **trois** pièces : le `typedef` (seam hôte), une
/// table par défaut **bornée**, et surtout **la fonction de chaîne** qui les
/// compose (`zResolveAdornmentIcon(context, key)` = seam hôte prioritaire →
/// défaut → `null`, AD-10). Ce fichier reproduit les trois à l'identique pour la
/// couleur — [ZColorKeyResolver], [zDefaultColorKeyResolver], [zResolveColorKey]
/// — plus un **repli total garanti** ([zColorSlotPair] / [zResolveColorKeyOrSlot])
/// que l'icône n'a pas besoin d'avoir (un slot d'icône peut être omis ; un fond
/// de puce, non).
///
/// ## Zéro table sémantique study dans le cœur (M3)
///
/// `zcrud_core` est le **puits** du graphe (AD-1, out-degree 0) : il **ne peut
/// pas** dépendre de `zcrud_study_kernel`. Il ne doit donc **pas** répliquer la
/// liste de clés sémantiques du domaine study (`success`/`warning`/`info`/…) :
/// ce serait une duplication **non testable** (aucun package ne voit les deux),
/// qui dériverait silencieusement dès qu'ES-2 ajouterait une clé.
///
/// Ce fichier ne connaît donc **aucune clé study**. Son vocabulaire est celui
/// du `ColorScheme` **Material 3** lui-même, réifié par [ZColorSlot] : le
/// « défaut » n'est pas une table, c'est l'`enum` (`slot.name == colorKey`).
/// La **source unique** des clés study reste `ZColorPalette` (kernel), et le
/// pont entre les deux est un **entier** (`ZColorPalette.indexOf` → [ZColorSlot]),
/// pas une liste de `String` dupliquée.
///
/// ## Contraste garanti (M4, AD-13)
///
/// [ZColorSlot] n'expose que des rôles **d'emphase homogène** (`*Container`,
/// conçus comme **fonds**) **avec** leur compagnon `on*` : une [ZColorPair] est
/// donc **utilisable telle quelle** (fond + premier plan lisible), le contraste
/// étant garanti par le `ColorScheme` lui-même. Le cœur ne **prétend pas**
/// fournir de vert « success » ni d'ambre « warning » : Material 3 n'a pas ces
/// rôles, et les inventer exigerait une couleur codée en dur (**interdit** —
/// AD-13/FR-26/NFR-S7). Une sémantique success/warning **exacte** relève du
/// resolver **injecté par l'app** (`ZcrudScope.colorKeyResolver`) : c'est
/// précisément le rôle du seam.
///
/// **Aucun littéral hexadécimal, aucune `Color(0x…)`, aucun `Colors.*`** ici :
/// toute couleur est **dérivée** du [ColorScheme] courant (cf. `ZcrudTheme.fallback`).
library;

import 'package:flutter/material.dart';

import '../zcrud_scope.dart';

/// Paire **fond + premier plan** issue du `ColorScheme` — le contraste entre
/// [color] et [onColor] est **garanti par Material 3** (AD-13 : le cœur ne
/// renvoie jamais une couleur seule dont l'appelant ne saurait pas déduire un
/// premier plan lisible).
@immutable
class ZColorPair {
  /// Crée une paire fond/premier plan.
  const ZColorPair({required this.color, required this.onColor});

  /// Couleur de **fond** (rôle `*Container`/surface du `ColorScheme`).
  final Color color;

  /// Couleur de **premier plan** lisible sur [color] (rôle `on*` associé).
  final Color onColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColorPair &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          onColor == other.onColor;

  @override
  int get hashCode => Object.hash(color, onColor);

  @override
  String toString() => 'ZColorPair(color: $color, onColor: $onColor)';
}

/// Palette **bornée et ordonnée** de rôles du `ColorScheme` utilisables comme
/// fonds contrastés (M4/AD-13). C'est le **seul** vocabulaire de couleur du
/// cœur : des rôles Material 3, **jamais** des clés sémantiques d'un domaine
/// (study ou autre — cf. M3).
///
/// L'ordre est **stable** : il fait partie du contrat ([zColorSlotPair] indexe
/// dedans). Ne pas réordonner sans raison (le slot affiché pour une clé
/// inconnue changerait — cosmétique, mais inutilement).
enum ZColorSlot {
  /// `primaryContainer` / `onPrimaryContainer`.
  primary,

  /// `secondaryContainer` / `onSecondaryContainer`.
  secondary,

  /// `tertiaryContainer` / `onTertiaryContainer`.
  tertiary,

  /// `errorContainer` / `onErrorContainer`.
  error,

  /// `surfaceContainerHighest` / `onSurfaceVariant`.
  neutral;

  /// Résout ce slot dans [scheme] — **dérivé**, jamais codé en dur.
  ZColorPair of(ColorScheme scheme) {
    switch (this) {
      case ZColorSlot.primary:
        return ZColorPair(
          color: scheme.primaryContainer,
          onColor: scheme.onPrimaryContainer,
        );
      case ZColorSlot.secondary:
        return ZColorPair(
          color: scheme.secondaryContainer,
          onColor: scheme.onSecondaryContainer,
        );
      case ZColorSlot.tertiary:
        return ZColorPair(
          color: scheme.tertiaryContainer,
          onColor: scheme.onTertiaryContainer,
        );
      case ZColorSlot.error:
        return ZColorPair(
          color: scheme.errorContainer,
          onColor: scheme.onErrorContainer,
        );
      case ZColorSlot.neutral:
        return ZColorPair(
          color: scheme.surfaceContainerHighest,
          onColor: scheme.onSurfaceVariant,
        );
    }
  }
}

/// Résolveur de couleur **host-fourni** : traduit une **clé neutre** (`String`,
/// typiquement une `colorKey` déjà remappée via `ZColorPalette.resolveKey`) en
/// [ZColorPair], ou `null` si la clé est inconnue de l'hôte (le cœur retombe
/// alors sur [zDefaultColorKeyResolver], puis `null` — AD-10). Injecté via
/// `ZcrudScope.colorKeyResolver`.
///
/// La signature **compose** avec celle du repli (M2) : elle porte le
/// [ColorScheme] courant, de sorte qu'un resolver hôte puisse lui aussi dériver
/// du thème (et que `zDefaultColorKeyResolver` **soit** un `ZColorKeyResolver`,
/// substituable tel quel). Le domaine (`zcrud_study_kernel`) ne porte JAMAIS de
/// `Color` (AD-3/SM-S5).
typedef ZColorKeyResolver = ZColorPair? Function(
  ColorScheme scheme,
  String colorKey,
);

/// Repli **par défaut** du cœur : reconnaît le **vocabulaire de rôles Material 3**
/// ([ZColorSlot] — `primary`/`secondary`/`tertiary`/`error`/`neutral`) et rend la
/// [ZColorPair] correspondante, **dérivée** de [scheme].
///
/// Toute autre clé (y compris les clés **sémantiques** d'un domaine —
/// `success`, `warning`, `info`, `danger`, une clé legacy…) ⇒ `null` : le cœur
/// **n'invente pas** de teinte absente du `ColorScheme` (M4). L'appelant
/// dispose de deux issues, toutes deux **totales** :
/// 1. injecter un `ZcrudScope.colorKeyResolver` (sémantique exacte, côté app) ;
/// 2. retomber sur [zColorSlotPair] / [zResolveColorKeyOrSlot] avec l'index de
///    la clé dans sa palette (`ZColorPalette.indexOf`) — couleurs distinctes,
///    déterministes et contrastées, sans sémantique prétendue.
///
/// Jamais de throw (AD-10). Aucun littéral hexadécimal (FR-26/NFR-S7).
ZColorPair? zDefaultColorKeyResolver(ColorScheme scheme, String colorKey) {
  for (final slot in ZColorSlot.values) {
    if (slot.name == colorKey) return slot.of(scheme);
  }
  return null;
}

/// Paire du slot d'index [slotIndex] dans [ZColorSlot.values] — **totale** et
/// défensive (AD-10) : l'index est ramené dans les bornes (`abs() % n`), donc
/// un index négatif, hors-bornes ou `-1` (palette vide côté kernel) ne peut pas
/// lever de `RangeError`.
///
/// C'est le **pont** avec `ZColorPalette` : `zColorSlotPair(scheme,
/// palette.indexOf(rawKey))` donne une couleur **déterministe** (le hash
/// déterministe reste dans le kernel — **une seule** implémentation dans le
/// repo) et **contrastée**, pour n'importe quelle clé, sans que le cœur ne
/// connaisse la moindre clé study.
ZColorPair zColorSlotPair(ColorScheme scheme, int slotIndex) {
  final slots = ZColorSlot.values;
  final index = slotIndex.abs() % slots.length;
  return slots[index].of(scheme);
}

/// Chaîne de résolution **complète** d'une `colorKey` (strict miroir de
/// `zResolveAdornmentIcon`) :
/// 1. seam hôte prioritaire — `ZcrudScope.colorKeyResolver` ;
/// 2. repli du cœur dérivé du `ColorScheme` — [zDefaultColorKeyResolver] ;
/// 3. `null` si la clé reste inconnue (jamais de throw — AD-10).
///
/// Pour une résolution **garantie non nulle** (fond de puce/dossier), préférer
/// [zResolveColorKeyOrSlot].
ZColorPair? zResolveColorKey(BuildContext context, String colorKey) {
  final scheme = Theme.of(context).colorScheme;
  return ZcrudScope.maybeOf(context)?.colorKeyResolver?.call(scheme, colorKey) ??
      zDefaultColorKeyResolver(scheme, colorKey);
}

/// Chaîne **totale** : [zResolveColorKey] puis, si la clé reste inconnue, le
/// slot d'index [slotIndex] ([zColorSlotPair]). Rend **toujours** une
/// [ZColorPair] contrastée (jamais `null`, jamais de throw — AD-10).
///
/// Point d'entrée recommandé pour un consommateur study :
/// ```dart
/// final pair = zResolveColorKeyOrSlot(
///   context,
///   palette.resolveKey(folder.colorKey),      // kernel : clé bornée
///   slotIndex: palette.indexOf(folder.colorKey), // kernel : index déterministe
/// );
/// // pair.color = fond ; pair.onColor = premier plan lisible (AD-13).
/// ```
ZColorPair zResolveColorKeyOrSlot(
  BuildContext context,
  String colorKey, {
  required int slotIndex,
}) =>
    zResolveColorKey(context, colorKey) ??
    zColorSlotPair(Theme.of(context).colorScheme, slotIndex);
