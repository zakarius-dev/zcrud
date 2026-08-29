/// **Unique** fichier de référence COULEUR de `zcrud_document`.
///
/// ## Ce que ce fichier est
///
/// La palette d'annotation de référence, sous forme de littéraux
/// hexadécimaux. C'est le seul endroit du paquet où une couleur a le droit
/// d'être écrite : les gardes de source anti-couleurs (FR-26) l'exemptent
/// **nominativement par chemin exact**, et lui seul. Toute recopie de ces
/// valeurs ailleurs dans `lib/` est un défaut, et les gardes le disent.
///
/// ## Ce que ce fichier n'est pas
///
/// Ce n'est pas un défaut inconditionnel. Ces couleurs ne sont peintes que par
/// le **dernier maillon** d'une chaîne de priorité
/// **paramètre > résolveur hôte > référence > rôle Material 3**, et seulement
/// sous le profil `ZReferenceProfile.legacy` (le défaut). Sous
/// `ZReferenceProfile.neutral`, ce fichier n'est jamais lu et la couleur
/// rendue reste celle du `ColorScheme` courant.
///
/// Concrètement, pour une `colorKey` donnée :
///
/// 1. la liste passée en paramètre (`ZAnnotationToolbar.swatchColors`,
///    `ZAnnotationPanel.swatchColors`) — si elle couvre l'index demandé ;
/// 2. le résolveur injecté par l'hôte (`ZcrudScope.colorKeyResolver`), puis le
///    repli de rôle Material 3 du socle (`primary`, `secondary`, `tertiary`,
///    `error`, `neutral` sont des **rôles**, pas des teintes de cette
///    palette : ils continuent d'être résolus par le thème) ;
/// 3. **cette référence**, sous profil `legacy` uniquement ;
/// 4. le slot de `ColorScheme` indexé — le comportement du profil `neutral`.
///
/// ## `onColor` est MESURÉ, jamais décrété
///
/// [foregroundFor] départage le blanc et le noir par **mesure de contraste**
/// WCAG 2.2 (`zContrastRatio`) contre le fond réellement peint, et retient le
/// meilleur des deux. Le plancher atteignable par ce choix est
/// **4.58:1** — au-dessus de `kZNonTextMinContrast` (3.0:1) quelle que soit la
/// teinte, y compris la plus défavorable. Une garde le recalcule sur les 40
/// teintes plutôt que de croire cette phrase.
///
/// ## Bornes
///
/// [pairAt] est **totale** (AD-10) : l'index est ramené dans les bornes
/// (`abs() % n`), une palette vide rend `null`. Aucun appel ne lève.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZcrudTheme,
        zColorSlotPair,
        zContrastRatio,
        zLegacyOrIn,
        zResolveColorKey;

/// Blanc opaque — **candidat** de premier plan, retenu ou écarté par mesure.
const Color _kWhite = Color(0xFFFFFFFF);

/// Noir opaque — **candidat** de premier plan, retenu ou écarté par mesure.
const Color _kBlack = Color(0xFF000000);

/// Palette d'annotation de référence, auditée.
///
/// Les valeurs sont figées : les changer change ce que voient tous les hôtes
/// qui n'ont ni paramètre ni résolveur. Une garde compare cette table à une
/// copie indépendante et rougit à la moindre dérive.
abstract final class ZAnnotationPaletteReference {
  /// Grille complète — **40 teintes**, dans l'ordre de la référence.
  ///
  /// Quatre rangées de huit : un dégradé achromatique (blanc → presque noir),
  /// puis des pastels, puis les mêmes familles chromatiques en trois paliers
  /// de plus en plus sombres. L'ordre fait partie du contrat : c'est lui que
  /// [pairAt] indexe.
  //
  // Relevé à la main sur le legacy IFFD (branche `main`), fichier
  // `lib/src/presentation/features/documents/widgets/document_viewer/
  // color_palette.dart`, lignes 124 à 163 — la grille `GridView.count`
  // (`crossAxisCount: 8`) du panneau de palette bureau. La première entrée y
  // est écrite `Colors.white` (:124), rendue ici par son hex explicite : le
  // paquet n'a pas le droit de nommer `Colors`, pas même dans ce fichier.
  static const List<Color> colors = <Color>[
    // Rangée 1 — achromatiques (:124-131).
    Color(0xFFFFFFFF),
    Color(0xFFDADADA),
    Color(0xFFB2B1B1),
    Color(0xFF909090),
    Color(0xFF6F6F6F),
    Color(0xFF515151),
    Color(0xFF383737),
    Color(0xFF060606),
    // Rangée 2 — pastels (:132-139).
    Color(0xFFFFA6A6),
    Color(0xFFFFDEA6),
    Color(0xFFFBFBA6),
    Color(0xFFA7FFAB),
    Color(0xFFA6FFF9),
    Color(0xFFACA9FF),
    Color(0xFFE7A6FF),
    Color(0xFFFBA6FB),
    // Rangée 3 — teintes vives (:140-147).
    Color(0xFFFF0000),
    Color(0xFFFFA200),
    Color(0xFFF3F500),
    Color(0xFF03FF0F),
    Color(0xFF00FFEF),
    Color(0xFF1108FF),
    Color(0xFFB900FF),
    Color(0xFFF500F3),
    // Rangée 4 — teintes moyennes (:148-155).
    Color(0xFFD60000),
    Color(0xFFD68800),
    Color(0xFFCACC00),
    Color(0xFF00D60A),
    Color(0xFF00D6C8),
    Color(0xFF0800E0),
    Color(0xFF9B00D6),
    Color(0xFFCC00CA),
    // Rangée 5 — teintes sombres (:156-163).
    Color(0xFF990000),
    Color(0xFF996100),
    Color(0xFF979900),
    Color(0xFF009907),
    Color(0xFF00998F),
    Color(0xFF050099),
    Color(0xFF6F0099),
    Color(0xFF990097),
  ];

  /// Rangée compacte — **7 teintes**, sous-ensemble strict de [colors].
  ///
  /// C'est la sélection retenue quand la place manque pour la grille entière
  /// (une seule rangée d'accès direct). Offerte telle quelle : aucun widget du
  /// socle ne la lit — c'est à l'hôte de la passer en paramètre s'il veut ce
  /// jeu restreint.
  //
  // Legacy IFFD `color_palette.dart:293-299` — la rangée du `_getMobilePalette`.
  static const List<Color> compact = <Color>[
    Color(0xFF03FF0F),
    Color(0xFF00FFEF),
    Color(0xFF1108FF),
    Color(0xFFB900FF),
    Color(0xFFF500F3),
    Color(0xFFD60000),
    Color(0xFFD68800),
  ];

  /// Premier plan **mesuré** pour [background] : celui des deux candidats
  /// achromatiques (blanc, noir) qui contraste le plus avec lui.
  ///
  /// La mesure porte sur [background] **tel que passé** : un fond
  /// semi-transparent doit être composé (`zCompositeOver`) par l'appelant
  /// avant d'arriver ici, sinon le chiffre ne décrit pas ce qui est peint.
  static Color foregroundFor(Color background) =>
      zContrastRatio(_kWhite, background) >= zContrastRatio(_kBlack, background)
          ? _kWhite
          : _kBlack;

  /// Paire fond + premier plan de l'entrée [index] de [palette] (défaut
  /// [colors]).
  ///
  /// Totale et défensive (AD-10) : l'index est ramené dans les bornes
  /// (`abs() % n`), donc un index négatif, hors-bornes ou `-1` ne peut pas
  /// lever. Une palette **vide** rend `null` — c'est le seul cas nul, et il
  /// signifie « cette référence n'a rien à proposer », pas « erreur ».
  static ZColorPair? pairAt(int index, {List<Color> palette = colors}) {
    if (palette.isEmpty) return null;
    final Color background = palette[index.abs() % palette.length];
    return ZColorPair(color: background, onColor: foregroundFor(background));
  }
}

/// Chaîne **totale** de résolution d'une couleur d'annotation (jamais nulle,
/// jamais de levée — AD-10), dans l'ordre de priorité :
///
/// 1. [swatchColors] — la liste posée par l'appelant, indexée par [slotIndex]
///    (ramené dans les bornes). Elle l'emporte dans **les deux** profils ;
/// 2. `ZcrudScope.colorKeyResolver`, puis le repli de rôle Material 3 du
///    socle — c'est-à-dire `zResolveColorKey` : une `colorKey` qui nomme un
///    rôle (`primary`, `secondary`, `tertiary`, `error`, `neutral`) reste
///    résolue par le **thème**, jamais par la référence ;
/// 3. [ZAnnotationPaletteReference], sous profil `ZReferenceProfile.legacy`
///    seulement ;
/// 4. le slot de `ColorScheme` indexé — ce que le socle rendait avant
///    l'introduction de la référence, et ce qu'il rend encore sous profil
///    `ZReferenceProfile.neutral`.
///
/// Le premier plan rendu est **mesuré** aux étapes 1 et 3
/// ([ZAnnotationPaletteReference.foregroundFor]) et **garanti par Material 3**
/// aux étapes 2 et 4.
ZColorPair zResolveAnnotationColor(
  BuildContext context,
  String colorKey, {
  required int slotIndex,
  List<Color>? swatchColors,
}) {
  if (swatchColors != null && swatchColors.isNotEmpty) {
    final Color background =
        swatchColors[slotIndex.abs() % swatchColors.length];
    return ZColorPair(
      color: background,
      onColor: ZAnnotationPaletteReference.foregroundFor(background),
    );
  }
  final ZColorPair? hosted = zResolveColorKey(context, colorKey);
  if (hosted != null) return hosted;
  // Dernier maillon avant le repli de rôle : la référence, et seulement sous
  // profil `legacy`. Sous `neutral`, `zLegacyOrIn` rend `null` et la chaîne
  // retombe exactement là où elle retombait avant ce lot.
  final ZColorPair? reference = zLegacyOrIn<ZColorPair?>(
    ZcrudTheme.of(context).referenceProfile,
    ZAnnotationPaletteReference.pairAt(slotIndex),
  );
  if (reference != null) return reference;
  return zColorSlotPair(Theme.of(context).colorScheme, slotIndex);
}
