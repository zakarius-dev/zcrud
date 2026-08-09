/// **Feuille contrainte et encadrée** (CR-IFFD-SHEET, 2026-08-09) — la
/// bottom-sheet du socle n'occupe plus toute la largeur de l'écran et porte un
/// **cadre** hérité du thème.
///
/// ## Ce que fait réellement IFFD (mesuré, pas cru)
///
/// `iffd/lib/src/utils/functions/forms_utils.dart` (~l. 655-720),
/// `showPushedDialog` :
///
/// ```dart
/// Get.bottomSheet<T>(
///   elevation: 8,
///   Container(
///     constraints: BoxConstraints(
///       maxHeight: maxHeight ?? screenHeight * 0.9 * ratio,
///       maxWidth:  maxWidth  ?? screenWidth * 0.9,        // ← la « marge »
///     ),
///     child: isEditionScreen ? builder : Card.outlined(child: builder), // ← le « gris »
///   ),
///   ignoreSafeArea: false,
///   isScrollControlled: ...,
/// );
/// ```
///
/// * Ce n'est **PAS** dans leur thème : `iffd/lib/src/config/themes/app_theme.dart`
///   l. 67-85, `kBottomSheetTheme` / `kBottomSheetThemeDark` ne portent **qu'une**
///   `shape` (`RoundedRectangleBorder`, rayon 50 en haut). **Aucune** marge,
///   **aucune** bordure, **aucune** contrainte.
/// * La « marge » est donc un **ratio de largeur (0,9)**, pas une marge fixe.
/// * Le « gris » est celui de `Card.outlined`, c'est-à-dire — lu dans le SDK,
///   `flutter/lib/src/material/card.dart`, `_OutlinedCardDefaultsM3` — un
///   `BorderSide(color: ColorScheme.outlineVariant)` sur un
///   `RoundedRectangleBorder(radius: 12)`, `elevation: 0`,
///   `margin: EdgeInsets.all(4)`, `color: ColorScheme.surface`.
///   ⇒ **une couleur de RÔLE, jamais un littéral** (FR-26 respecté par
///   construction : ce fichier ne contient aucune couleur).
///
/// ## 🔴 Écart DÉLIBÉRÉ avec la source : pas d'exception « écran d'édition »
///
/// IFFD retire le cadre quand le contenu est un écran d'édition, et le
/// détermine par `builder.runtimeType.toString().endsWith("EditionScreen")` —
/// une **heuristique de chaîne**. Le socle ne la reproduit pas :
///
/// 1. elle est **fragile** (renommer la classe change le rendu, silencieusement) ;
/// 2. elle est **indéboguable** côté hôte (rien ne dit pourquoi le cadre a
///    disparu) ;
/// 3. elle fait **deviner** au socle une propriété du contenu, alors que
///    l'hôte la connaît.
///
/// À la place, [ZSheetFrameMode] rend la décision **explicite et déclarée par
/// l'hôte** — et [ZSheetFrameMode.unlessChrome] restitue exactement l'intention
/// d'IFFD (« encadre, sauf quand c'est un formulaire d'édition ») sans aucune
/// reconnaissance de type : « c'est une édition » y signifie « l'appelant a
/// fourni un `ZEditionChrome` », donc *l'hôte a déclaré*.
///
/// ## Chaîne de résolution (patron du dépôt)
///
/// **paramètre ([ZSheetFrameSpec]) > jeton `ZcrudTheme.editionSheet*` >
/// référence auditée ([ZSheetFrameReference])**.
///
/// ### 🔴 `ZSheetFrameTheme` a été SUPPRIMÉE (CR-TOKENS, 2026-08-09)
///
/// La version du 2026-08-09 portait le maillon « jeton » par une
/// `ThemeExtension` **locale** `ZSheetFrameTheme`, faute de pouvoir écrire dans
/// `zcrud_core` ce jour-là. Les jetons `ZcrudTheme.editionSheet*` existent
/// désormais, et la `ThemeExtension` locale a été **retirée** plutôt que
/// conservée en second canal :
///
/// * **deux canaux pour la même propriété est le motif de divergence** que ce
///   dépôt s'interdit (CR-LEX-78, « pas de vue parallèle ») : un hôte qui pose
///   les deux obtient un gagnant silencieux, et chaque évolution doit être
///   écrite deux fois (deux `copyWith`, deux `lerp`, deux dartdocs) ;
/// * **mesuré** : `grep -rn "extends ThemeExtension<" packages --include="*.dart"`
///   rend exactement **deux** classes dans tout le dépôt — `ZcrudTheme` et
///   `ZSheetFrameTheme`. Sur quatorze paquets, `ZcrudTheme` est le canal de
///   thème **unique** ; l'exception datait de la veille ;
/// * le seul avantage propre de la version locale était le **typage** du mode
///   (`ZSheetFrameMode` au lieu d'un `String`, imposé par AD-1). Il est restitué
///   **sans second canal** : l'hôte écrit
///   `ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name)` — l'enum
///   reste la source du nom, donc un renommage reste une erreur de compilation
///   au call-site ;
/// * rien n'était publié : `grep -rn "ZSheetFrameTheme" packages` hors de ce
///   fichier ne rendait que du code de ce même paquet.
///
/// Un jeton de mode **inconnu** (chaîne libre, thème sérialisé par une version
/// plus récente) retombe sur la référence — **jamais** d'exception (AD-10).
///
/// ## Invariants
///
/// * **FR-26 / NFR-S7** : aucune couleur littérale ici — la teinte du cadre est
///   le **rôle** `ColorScheme.outlineVariant`, surchargeable par jeton et par
///   paramètre. La référence auditée ne porte que des **dimensions**.
/// * **AD-13** : le cadre n'est **jamais le seul canal** d'une information — il
///   est purement décoratif (aucune sémantique n'en dépend), et la contrainte de
///   largeur ne réduit aucune cible sous 48 dp.
/// * **AD-10** : aucune exception ; une `shape` ambiante non-[OutlinedBorder]
///   retombe sur la forme de référence.
/// * **AD-4** : `null` ⇒ **absent de l'arbre** — cadre désactivé ⇒ aucune
///   `shape` n'est imposée, `showModalBottomSheet` retrouve exactement la
///   résolution du SDK (`thème > défauts M3`).
/// * **AD-1** : aucune arête de paquet ajoutée (Flutter vanilla uniquement).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// **Quand** encadrer une bottom-sheet — déclaré par l'hôte, jamais deviné.
enum ZSheetFrameMode {
  /// Toujours encadrer. **Défaut du socle** (décision propriétaire, 2026-08-09).
  always,

  /// Ne jamais encadrer — restitue le rendu d'avant la CR (aucune `shape`
  /// imposée), **sans** rendre pour autant la feuille pleine largeur : la
  /// contrainte de largeur est un réglage **indépendant**.
  never,

  /// Encadrer **sauf** quand l'appelant a fourni un `ZEditionChrome`.
  ///
  /// C'est l'intention d'IFFD (« pas de cadre sur les écrans d'édition »),
  /// obtenue **sans** heuristique de type : la présence d'un chrome est une
  /// déclaration explicite du call-site.
  unlessChrome,
}

/// Les **valeurs de référence** de la feuille contrainte — point d'audit unique.
///
/// 🔴 **AUCUNE COULEUR ici** : uniquement des dimensions et un mode. La teinte
/// du cadre est résolue au rendu sur un **rôle** du `ColorScheme`.
abstract final class ZSheetFrameReference {
  /// Mode par défaut : **encadrer partout** (décision propriétaire).
  static const ZSheetFrameMode mode = ZSheetFrameMode.always;

  /// Fraction de la largeur d'écran allouée à la feuille — **0,9, la valeur
  /// mesurée dans IFFD** (`screenWidth * 0.9`).
  static const double widthRatio = 0.9;

  /// Plafond **absolu** de largeur (dp).
  ///
  /// 🔴 Ce n'est pas un choix de goût : c'est **le défaut de Flutter lui-même**.
  /// `flutter/lib/src/material/bottom_sheet.dart`, `_BottomSheetDefaultsM3` :
  /// `constraints => const BoxConstraints(maxWidth: 640.0)`. Or le presenter
  /// **passait déjà** un `constraints` non-`null` (`maxWidth: double.infinity`),
  /// ce qui **écrasait ce plafond** : sur un écran de 1600 dp la feuille du
  /// socle faisait 1600 dp de large, alors qu'une `showModalBottomSheet` nue en
  /// aurait fait 640. Le plafond restaure le défaut M3 au lieu de le contredire.
  ///
  /// Effet mesuré de `min(largeur * 0,9, 640)` :
  ///
  /// | Écran | Ratio seul | Retenu | Commentaire                     |
  /// |-------|-----------|--------|----------------------------------|
  /// | 360   | 324       | 324    | parité IFFD (18 dp de part et d'autre) |
  /// | 400   | 360       | 360    | parité IFFD                      |
  /// | 700   | 630       | 630    | ratio encore actif               |
  /// | 1600  | 1440      | **640**| plafond M3 — 1440 dp serait illisible |
  static const double maxWidth = 640;

  /// Épaisseur du cadre (dp) — celle d'un `BorderSide` par défaut, donc celle
  /// que `Card.outlined` peint dans IFFD.
  static const double borderWidth = 1;

  /// Rayon **de repli** du haut de feuille (dp) quand la `shape` ambiante n'est
  /// pas un [OutlinedBorder] auquel ajouter un côté. C'est le rayon M3
  /// (`_BottomSheetDefaultsM3.shape`), donc un repli **iso-rendu**.
  static const double fallbackTopRadius = 28;
}

/// **Surcharge par paramètre** (priorité la plus haute) de la feuille contrainte.
///
/// Chaque champ `null` ⇒ « je ne me prononce pas », et le maillon suivant de la
/// chaîne décide (jeton, puis référence). Un `ZSheetFrameSpec()` vide est donc
/// rigoureusement équivalent à `null` (AD-4).
@immutable
class ZSheetFrameSpec {
  /// Construit une surcharge partielle.
  const ZSheetFrameSpec({
    this.mode,
    this.widthRatio,
    this.maxWidth,
    this.borderColor,
    this.borderWidth,
  });

  /// Quand encadrer. `null` ⇒ jeton, puis [ZSheetFrameReference.mode].
  final ZSheetFrameMode? mode;

  /// Fraction de largeur d'écran. `null` ⇒ jeton, puis référence (0,9).
  final double? widthRatio;

  /// Plafond absolu de largeur (dp). `null` ⇒ jeton, puis référence (640).
  final double? maxWidth;

  /// Teinte du cadre. `null` ⇒ jeton, puis **rôle** `ColorScheme.outlineVariant`.
  final Color? borderColor;

  /// Épaisseur du cadre (dp). `null` ⇒ jeton, puis référence (1).
  final double? borderWidth;

  /// Copie modifiée (AD-4 : extension par composition).
  ZSheetFrameSpec copyWith({
    ZSheetFrameMode? mode,
    double? widthRatio,
    double? maxWidth,
    Color? borderColor,
    double? borderWidth,
  }) =>
      ZSheetFrameSpec(
        mode: mode ?? this.mode,
        widthRatio: widthRatio ?? this.widthRatio,
        maxWidth: maxWidth ?? this.maxWidth,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
      );
}

/// Traduit le jeton **`String`** `ZcrudTheme.editionSheetFrameMode` en
/// [ZSheetFrameMode] — **le seul** point de traduction du paquet.
///
/// 🔴 Pourquoi une chaîne du côté du cœur : `ZSheetFrameMode` vit ici, et
/// **AD-1 interdit à `zcrud_core` de dépendre d'un satellite**. Le jeton porte
/// donc le **nom** du palier (`ZSheetFrameMode.always.name` == `'always'`),
/// exactement comme `ZcrudTheme.chatResponseLengthAccents` est indexé par le
/// nom d'un palier du kernel du chat.
///
/// 🔴 **AD-10 — jamais d'exception.** `null`, chaîne vide, casse différente,
/// palier inventé, palier d'une version **future** du socle : tous rendent
/// `null`, c'est-à-dire « le jeton ne se prononce pas », et le maillon suivant
/// de la chaîne décide. Un thème est une donnée que l'hôte écrit à la main (ou
/// qu'il désérialise) : une valeur inattendue ne doit pas faire planter un
/// rendu.
///
/// Côté hôte, le nom se produit **sans** chaîne codée en dur :
/// `ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name)`.
ZSheetFrameMode? zSheetFrameModeFromToken(String? token) {
  if (token == null) {
    return null;
  }
  for (final ZSheetFrameMode mode in ZSheetFrameMode.values) {
    if (mode.name == token) {
      return mode;
    }
  }
  return null;
}

/// Métriques **résolues** de la feuille (paramètre > jeton > référence).
///
/// Porte-valeurs immuable : plus aucune décision n'y reste à prendre.
@immutable
class ZSheetFrameMetrics {
  /// Construit un jeu de métriques déjà résolu.
  const ZSheetFrameMetrics({
    required this.framed,
    required this.widthRatio,
    required this.maxWidth,
    required this.borderColor,
    required this.borderWidth,
    required this.fallbackTopRadius,
  });

  /// `true` ssi un cadre doit être peint.
  final bool framed;

  /// Fraction de largeur d'écran retenue.
  final double widthRatio;

  /// Plafond absolu de largeur (dp).
  final double maxWidth;

  /// Teinte **résolue** du cadre (déjà repliée sur le rôle du `ColorScheme`).
  final Color borderColor;

  /// Épaisseur du cadre (dp).
  final double borderWidth;

  /// Rayon de repli du haut de feuille (dp).
  final double fallbackTopRadius;

  /// Largeur maximale effective pour un écran de largeur [screenWidth] :
  /// `min(screenWidth * widthRatio, maxWidth)`.
  ///
  /// Le ratio seul ne suffit pas (1600 × 0,9 = 1440 dp de feuille) ; le plafond
  /// seul ne suffit pas non plus (aucune marge sous 640 dp, donc pas de bordure
  /// visible sur les petits écrans — exactement ce que le propriétaire demande
  /// d'obtenir « même sur les petits écrans »).
  double effectiveMaxWidth(double screenWidth) =>
      math.min(screenWidth * widthRatio, maxWidth);

  /// La `shape` à imposer à la bottom-sheet, ou **`null` si aucun cadre** —
  /// auquel cas `showModalBottomSheet` retrouve *exactement* sa résolution
  /// native (`shape` du thème, puis défauts M3), donc l'arbre d'avant la CR.
  ///
  /// La forme ambiante est **conservée** : seul un côté lui est ajouté. Un hôte
  /// qui a réglé un rayon de 50 dp en haut (cas d'IFFD) le garde ; il gagne son
  /// contour, il ne perd pas son arrondi. Si la forme ambiante n'est pas un
  /// [OutlinedBorder] (pas de `copyWith(side:)` possible), repli sur la forme de
  /// référence (AD-10 — jamais d'exception).
  ShapeBorder? resolveShape(ShapeBorder? ambient) {
    if (!framed) {
      return null;
    }
    final BorderSide side =
        BorderSide(color: borderColor, width: borderWidth);
    final OutlinedBorder base = ambient is OutlinedBorder
        ? ambient
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(fallbackTopRadius),
            ),
          );
    return base.copyWith(side: side);
  }
}

/// Résout les métriques de la feuille — **paramètre > jeton
/// `ZcrudTheme.editionSheet*` > référence**.
///
/// [hasChrome] dit si l'appelant a fourni un `ZEditionChrome` ; c'est la seule
/// entrée dont dépend [ZSheetFrameMode.unlessChrome], et elle vient d'une
/// **déclaration** du call-site, jamais d'une inspection du contenu.
ZSheetFrameMetrics zSheetFrameMetricsOf(
  BuildContext context, {
  ZSheetFrameSpec? spec,
  required bool hasChrome,
}) {
  final ZcrudTheme token = ZcrudTheme.of(context);
  // AD-10 : un jeton de mode INCONNU rend `null` ⇒ la référence décide.
  final ZSheetFrameMode mode = spec?.mode ??
      zSheetFrameModeFromToken(token.editionSheetFrameMode) ??
      ZSheetFrameReference.mode;
  final bool framed = switch (mode) {
    ZSheetFrameMode.always => true,
    ZSheetFrameMode.never => false,
    ZSheetFrameMode.unlessChrome => !hasChrome,
  };
  return ZSheetFrameMetrics(
    framed: framed,
    widthRatio: spec?.widthRatio ??
        token.editionSheetWidthRatio ??
        ZSheetFrameReference.widthRatio,
    maxWidth: spec?.maxWidth ??
        token.editionSheetMaxWidth ??
        ZSheetFrameReference.maxWidth,
    // 🔴 Dernier maillon = un **RÔLE** du `ColorScheme`, jamais un littéral :
    // la teinte reste héritée du thème de l'hôte (FR-26). C'est le rôle que
    // `Card.outlined` utilise (`_OutlinedCardDefaultsM3`), donc le « gris »
    // exact d'IFFD, en clair comme en sombre.
    borderColor: spec?.borderColor ??
        token.editionSheetBorderColor ??
        Theme.of(context).colorScheme.outlineVariant,
    borderWidth: spec?.borderWidth ??
        token.editionSheetBorderWidth ??
        ZSheetFrameReference.borderWidth,
    fallbackTopRadius: ZSheetFrameReference.fallbackTopRadius,
  );
}
