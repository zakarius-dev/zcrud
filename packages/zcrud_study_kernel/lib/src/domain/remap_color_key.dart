/// `remapColorKey` — remap déterministe de la `colorKey` affichable d'un tag
/// contre une palette injectée.
///
/// Habille le remap déjà existant [ZColorPalette.resolveKey] pour la
/// sémantique « tag », sans jamais le réimplémenter :
///
/// 1. Pas de dépendance de hachage cryptographique : [ZColorPalette] utilise
///    délibérément FNV-1a ([zFnv1a32]) pour préserver la fermeture
///    transitive minimale du kernel. Une application qui a besoin de parité
///    byte-à-byte avec un serveur externe injecte son propre [ZKeyHash]
///    dans la palette, sans que le kernel n'acquière de dépendance
///    supplémentaire (invariant AD-4 : extension par injection). Ce fichier
///    n'importe donc que `z_color_palette.dart`.
/// 2. Pas de palette figée en dur : la palette est un paramètre (défaut
///    recommandé aux appelants : [ZColorPalette.defaultStudy], clés
///    neutres). Le kernel ne connaît aucune couleur concrète.
/// 3. Pas de type `Color` : `colorKey` est une `String` symbolique ; la
///    résolution `colorKey → Color` est un seam de présentation fourni par
///    `zcrud_core` (`ZcrudScope.colorKeyResolver`), hors périmètre de ce
///    kernel (invariant AD-13).
///
/// La valeur remappée ne décide que du slot de palette affiché : la valeur
/// **persistée** reste la `colorKey` brute stockée verbatim par l'entité
/// (`ZFlashcardTag.colorKey`, aucun clamp dans l'entité).
library;

import 'z_color_palette.dart';

/// Résout la `colorKey` affichable d'un tag contre une palette injectée.
///
/// Pure, totale, déterministe (mêmes entrées → même sortie, y compris entre
/// exécutions, appareils et plateformes différents via [ZColorPalette.hash])
/// — ne lève jamais ; résultat toujours dans [ZColorPalette.keys] (jamais
/// hors-palette, jamais `null` — invariant AD-10).
///
/// - [rawColorKey] déjà dans `palette.keys` en casse exacte (aux espaces
///   près) → renvoyée verbatim (identité stricte, cohérente avec
///   [ZColorPalette.resolveKey] qui compare aussi en casse exacte) ;
/// - sinon, si sa forme minuscule est dans `palette.keys` (tolérance de
///   casse pour la convention à clés minuscules de
///   [ZColorPalette.defaultStudy]) → renvoyée sous cette forme minuscule ;
/// - le remap ne s'applique donc qu'aux clés réellement inconnues ;
/// - sinon → remap déterministe sur la graine [seedTitle] (« même tag →
///   même couleur »), via [ZColorPalette.resolveKey] — aucun hash dupliqué,
///   la palette est composée, jamais réimplémentée ;
/// - [seedTitle] `null` ou vide → repli sur la clé brute (elle-même
///   éventuellement vide → `palette.resolveKey(null)` renvoie le repli
///   effectif de la palette).
///
/// Une [rawColorKey] `null`/vide avec un [seedTitle] présent remappe sur le
/// titre (deux tags de même titre obtiennent la même clé, même sans couleur
/// proposée).
String remapColorKey({
  required ZColorPalette palette,
  String? rawColorKey,
  String? seedTitle,
}) {
  final rawTrimmed = (rawColorKey ?? '').trim();
  // Clé connue en casse exacte → identité stricte (jamais remappée), cohérent
  // avec ZColorPalette.resolveKey qui compare aussi en casse exacte.
  if (palette.keys.contains(rawTrimmed)) return rawTrimmed;
  // Tolérance de casse : forme minuscule connue (convention defaultStudy) → identité.
  final rawLower = rawTrimmed.toLowerCase();
  if (palette.keys.contains(rawLower)) return rawLower;
  // Clé inconnue/vide → remap déterministe sur la graine, via l'algorithme
  // injectable de la palette (délègue — aucun hash local).
  final trimmedSeed = seedTitle?.trim() ?? '';
  final seed = trimmedSeed.isEmpty ? rawLower : trimmedSeed;
  return palette.resolveKey(seed.isEmpty ? null : seed);
}
