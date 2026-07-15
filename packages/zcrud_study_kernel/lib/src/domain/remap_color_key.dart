/// `remapColorKey` — remap déterministe de la `colorKey` AFFICHABLE d'un tag
/// contre une palette **INJECTÉE** (ES-2.3, FR-S6, AC3 — décision D3).
///
/// **Le cœur de la story** : il **HABILLE** le remap déjà existant
/// [ZColorPalette.resolveKey] (ES-1.2) pour la sémantique « tag », sans jamais
/// le réimplémenter. Trois REJETS explicites de la forme lex
/// (`FlashcardTag.remapColorKey`, R6 — corrections structurelles, pas rustines) :
///
/// 1. ⛔ **PAS `package:crypto` / SHA-256.** [ZColorPalette] a délibérément choisi
///    FNV-1a ([zFnv1a32]) pour préserver la fermeture transitive minimale du
///    kernel (`{zcrud_core, zcrud_annotations}` — NFR-S10/SM-S7). Une app qui a
///    besoin de **parité byte-à-byte** avec le serveur lex injecte son propre
///    [ZKeyHash] (SHA-256) dans la palette, **sans** que le kernel n'acquière
///    `crypto` (AD-4 : extension par injection). Ce fichier n'importe donc que
///    `z_color_palette.dart` (aucune dépendance nouvelle — vérifié : le
///    `pubspec.yaml` du kernel reste `{zcrud_core, zcrud_annotations}`).
/// 2. ⛔ **PAS de palette de 8 clés en dur.** La palette est un **paramètre**
///    (défaut recommandé aux appelants : [ZColorPalette.defaultStudy], clés
///    NEUTRES). Le kernel ne connaît aucune couleur concrète (SM-S5).
/// 3. ⛔ **PAS de `Color`.** `colorKey` est une `String` symbolique ; la
///    résolution `colorKey → Color` est un seam de présentation de `zcrud_core`
///    (`ZcrudScope.colorKeyResolver`), hors périmètre. AD-13 / FR-26 / NFR-S7.
///
/// **La valeur RemapPée ne décide QUE du slot de palette AFFICHÉ** : la valeur
/// **persistée** reste la `colorKey` brute stockée VERBATIM par l'entité
/// (`ZFlashcardTag.colorKey`, décision D4 — aucun clamp dans l'entité).
library;

import 'z_color_palette.dart';

/// Résout la `colorKey` **AFFICHABLE** d'un tag contre une palette **INJECTÉE**.
///
/// PURE · TOTALE · DÉTERMINISTE (mêmes entrées → même sortie, cross-run /
/// cross-device / cross-plateforme via [ZColorPalette.hash]) · ne throw
/// **JAMAIS** · résultat **TOUJOURS ∈ [ZColorPalette.keys]** (jamais hors-palette,
/// jamais `null` — AD-10, AC3).
///
/// - [rawColorKey] déjà dans `palette.keys` **en casse exacte** (aux espaces près)
///   → renvoyée **verbatim** (identité stricte, cohérente avec
///   [ZColorPalette.resolveKey] qui compare aussi en casse exacte) ;
/// - sinon, si sa forme **minuscule** est dans `palette.keys` (tolérance de casse
///   pour la convention à clés minuscules de [ZColorPalette.defaultStudy]) →
///   renvoyée sous cette forme minuscule ;
/// - le remap ne s'applique donc **qu'aux clés réellement inconnues** ;
/// - sinon → remap **déterministe** sur la graine [seedTitle] (« même tag → même
///   couleur », sémantique lex), via [ZColorPalette.resolveKey] — **AUCUN hash
///   dupliqué** (R6, on **compose** la palette, on ne la réimplémente pas) ;
/// - [seedTitle] `null`/vide → repli sur la clé brute (elle-même éventuellement
///   vide → `palette.resolveKey(null)` renvoie le repli effectif de la palette).
///
/// Une [rawColorKey] `null`/vide **avec** un [seedTitle] présent remappe sur le
/// titre (deux tags de même titre obtiennent la même clé, même sans couleur
/// proposée).
String remapColorKey({
  required ZColorPalette palette,
  String? rawColorKey,
  String? seedTitle,
}) {
  final rawTrimmed = (rawColorKey ?? '').trim();
  // Clé connue en CASSE EXACTE → identité stricte (jamais remappée), cohérent
  // avec ZColorPalette.resolveKey qui compare aussi en casse exacte (LOW-1).
  if (palette.keys.contains(rawTrimmed)) return rawTrimmed;
  // Tolérance de casse : forme minuscule connue (convention defaultStudy) → identité.
  final rawLower = rawTrimmed.toLowerCase();
  if (palette.keys.contains(rawLower)) return rawLower;
  // Clé inconnue/vide → remap DÉTERMINISTE sur la graine, via l'algorithme
  // INJECTABLE de la palette (délègue — aucun hash local, R6).
  final trimmedSeed = seedTitle?.trim() ?? '';
  final seed = trimmedSeed.isEmpty ? rawLower : trimmedSeed;
  return palette.resolveKey(seed.isEmpty ? null : seed);
}
