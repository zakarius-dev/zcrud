/// Le thème **Classic** : une identité visuelle complète, prête à poser, qui
/// habille les widgets EXISTANTS de la boîte à outils.
///
/// ## Adoption — une seule ligne, à la racine
///
/// ```dart
/// ZcrudScope(
///   theme: ZClassicTheme.of(context),
///   colorKeyResolver: ZClassicTheme.colorKeys,
///   gradientResolver: ZClassicTheme.gradients,
///   child: MonApp(),
/// )
/// ```
///
/// Rien d'autre n'est requis : aucun widget à remplacer, aucun rendu à
/// réimplémenter. Le thème remplit des **jetons** et alimente les **seams**
/// que le socle interroge déjà.
///
/// ## Ce que ce fichier n'est pas
///
/// Il ne rend rien. Il ne construit aucun widget et n'en exporte aucun : un
/// second rendu, concurrent de celui du socle, est exactement ce qu'un thème
/// doit éviter. Ce qu'il produit, ce sont des valeurs.
///
/// ## La chaîne de priorité est préservée
///
/// Le thème n'occupe que le maillon « jeton ». Un paramètre passé sur un
/// widget continue de l'emporter sur lui, dans tous les cas — la chaîne reste
/// **paramètre > jeton > référence**. C'est ce qui permet à un écran de
/// diverger localement sans quitter le thème.
///
/// **Là où un seam existe, il passe devant le jeton.** Les dégradés par type
/// de carte se résolvent `paramètre > seam > jeton > référence` : un hôte qui
/// branche son propre `ZcrudScope.gradientResolver` voit **son** résolveur
/// peindre, et le jeton posé ici n'est plus qu'un **repli**, consulté quand le
/// résolveur se tait. Un thème ne prend jamais la main sur une décision que
/// l'application a exprimée.
///
/// ## Les libellés restent à l'hôte
///
/// Ce paquet ne rend jamais un texte affiché : il rend des **clés** l10n, que
/// l'hôte traduit. C'est vrai des libellés de crans comme de l'aperçu
/// d'intervalle ; [previewLabelFor] fournit l'adaptateur qui compose la clé
/// avec le résolveur de l'hôte.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorKeyResolver,
        ZColorPair,
        ZGradientResolver,
        ZGradientSpec,
        ZPaletteIndexStrategy,
        ZReferenceProfile,
        ZcrudTheme;
import 'package:zcrud_session/zcrud_session.dart' show ZSrsQualityEmphasis;

import '../../z_theme_catalog.dart';
import 'z_classic_card_gradients_reference.dart';
import 'z_classic_celebration_reference.dart';
import 'z_classic_srs_palette_reference.dart';
import 'z_classic_surface_reference.dart';

// Préfixe de clé recopié du seam de la carte de flashcard
// (`zcrud_study`, `kZFlashcardTypeGradientKeyPrefix` — `flashcard.type.`).
// Il est recopié plutôt qu'importé : ce paquet n'a pas d'arête vers
// `zcrud_study`, et en ouvrir une pour une constante de six mots coûterait à
// tout hôte la fermeture entière du paquet d'étude. Une garde
// (`z_socle_gradient_parity_test.dart`) lit la DÉCLARATION du socle sur disque
// et vérifie que le résolveur ci-dessous répond aux clés que le socle compose
// réellement : la valeur recopiée ne peut donc pas dériver en silence.
const String _kFlashcardTypeGradientKeyPrefix = 'flashcard.type.';

/// Le thème Classic : fabriques de `ZcrudTheme` et résolveurs prêts à brancher.
abstract final class ZClassicTheme {
  /// Identité de ce thème dans le registre ouvert.
  static const ZThemeSpec spec = ZThemeCatalog.classic;

  /// Le thème Classic pour la luminosité de [context].
  ///
  /// Construit à partir du repli du socle (`ZcrudTheme.fallback`), dont il ne
  /// remplace que les jetons qu'il a mesurés : tout ce que le thème ne dit pas
  /// reste ce que le socle dit.
  static ZcrudTheme of(BuildContext context) => forTheme(Theme.of(context));

  /// Le thème Classic construit sur [themeData].
  ///
  /// Utile hors arbre de widgets (tests, prévisualisation d'un choix de thème
  /// dans un sélecteur).
  static ZcrudTheme forTheme(ThemeData themeData) {
    final Brightness brightness = themeData.brightness;
    return ZcrudTheme.fallback(themeData).copyWith(
      // Surfaces et rayons mesurés.
      surfaceColor: ZClassicSurfaceReference.cardFor(brightness),
      // Fond de la carte de flashcard — la plus grande surface de l'écran de
      // révision. Sans ce jeton, la carte retombe sur le rôle
      // `scaffoldBackgroundColor`, c'est-à-dire le fond de PAGE : elle se
      // confond alors avec son écran. Le code de référence distingue les deux
      // (`…/widgets/interactive_flashcard_repetition_card.dart:424` pour la
      // carte, `…/pages/folder_flashcards_repetitions_page.dart:239` pour la
      // page) ; le jeton restitue cette distinction.
      flashcardCardBackgroundColor:
          ZClassicSurfaceReference.cardFor(brightness),
      // ⚠️ `flashcardCardShadowColor` est DÉLIBÉRÉMENT NON POSÉ.
      // La référence dérive la teinte de l'ombre du dégradé du TYPE de carte
      // (`…/widgets/interactive_flashcard_repetition_card.dart:414` —
      // `_cardGradient.first.withAlpha(isDark ? 30 : 50)`) : elle vaut quatre
      // couleurs, une par type, là où le jeton n'en porte qu'une. Y figer
      // l'une des quatre repeindrait les trois autres. Aucune valeur unique
      // n'étant mesurable, le rôle `shadowColor` de l'hôte reste le repli.
      //
      // ⚠️ `studySessionDividerColor` est DÉLIBÉRÉMENT NON POSÉ.
      // L'écran de référence ne trace AUCUN trait entre la pile et la zone de
      // notation : la notation y vit à l'intérieur de la carte, et la page de
      // session ne déclare ni `Divider` ni `Border`. Il n'y a donc rien à
      // relever ; le rôle `outlineVariant` reste le repli.
      radiusM: ZClassicSurfaceReference.cardRadius,
      radiusS: ZClassicSurfaceReference.tileRadius,
      badgeRadius: ZClassicSurfaceReference.tileRadius,
      studyCardRadius: ZClassicSurfaceReference.cardRadius,
      folderCardRadius: ZClassicSurfaceReference.cardRadius,
      // Dégradés par type de carte : le maillon JETON, qui est un REPLI et non
      // une décision. Les deux cartes consultent d'abord le seam
      // (`z_flashcard_review_card.dart:912-928`,
      // `z_default_flashcard_card.dart:439-457` : le seam AVANT le jeton) ;
      // un hôte qui branche son résolveur voit donc le sien peindre, et ce
      // jeton ne sert qu'au silence du résolveur. La table posée est
      // STRICTEMENT ÉGALE à celle du socle (`ZFlashcardCardReference`) — le
      // thème rend explicite au maillon jeton ce que le socle applique déjà au
      // dernier maillon, et une garde de source prouve l'égalité.
      flashcardTypeGradients: ZClassicCardGradientsReference.typeGradients,
      // ⚠️ `accentBarHeight` est DÉLIBÉRÉMENT NON POSÉ.
      // Le liseré de tête d'une carte de révision vaut 4 dp
      // (`ZClassicSurfaceReference.cardAccentHeight`), mais ce jeton-là est
      // GLOBAL : il gouverne aussi le liseré des cartes de dossier
      // (`z_folder_card_chrome.dart:32`) et celui des champs de formulaire
      // (`z_field_widget.dart:613`), deux surfaces qui le lisent NU — aucun
      // paramètre ne permet de s'y soustraire. Mesuré : posé ici, il fait
      // apparaître le liseré de la carte (60 → 67 nœuds) et, chez un hôte qui
      // branche un résolveur large, celui de chaque champ (61 → 64 nœuds).
      // Le rendu dépendrait donc de ce que l'hôte branche par ailleurs. La
      // voie précise existe : `cardAccentHeight` sur l'écran de session, ou
      // `accentHeight` sur la carte.
      //
      // ⚠️ Les HUIT jetons de chrome de page (`appBarWashAlphas`,
      // `appBarWashElevation`, `fabShape`, `fabElevation`, `fabIconSize`,
      // `fabLabelStyle`, `choiceChipShape`, `choiceChipShowCheckmark`) sont
      // DÉLIBÉRÉMENT NON POSÉS. Leur valeur mesurée est déjà celle que le
      // dernier maillon peint : `ZPageShellReference` (`zcrud_ui_kit`) porte
      // la rampe de lavis `[0.15, 0.10, 0.05, 0.02]` et les métriques de
      // bouton et de puce, et chaque consommateur résout `jeton ?? référence`
      // sans condition. Les poser ici écrirait la valeur déjà peinte : un
      // SECOND CANAL vers le même pixel, jamais une valeur de plus.
      // Palette signature : le bandeau de tête, indexé de façon STABLE (le
      // `hashCode` d'une chaîne varie d'une plateforme à l'autre — une même
      // matière ne doit pas changer de couleur entre le web et le mobile).
      //
      // ⚠️ L'ORDRE des quatre dernières entrées est celui de la PALETTE du
      // socle (`ZSignaturePaletteReference.gradients`, quatre premières), et
      // NON celui des types de carte : c'est lui qui décide quelle couleur
      // reçoit une identité de section. Réordonner cette liste en suivant les
      // noms de type repeindrait les sections sans que rien ne le demande —
      // une garde compare les deux listes, entrée par entrée.
      signaturePalette: <ZGradientSpec>[
        ZClassicSurfaceReference.heroGradientFor(brightness),
        ZClassicCardGradientsReference.multipleChoice, // violet → pourpre
        ZClassicCardGradientsReference.trueOrFalse, // sarcelle → vert
        ZClassicCardGradientsReference.exercise, // rose → corail
        ZClassicCardGradientsReference.openQuestion, // bleu → cyan
      ],
      signaturePaletteIndexStrategy: ZPaletteIndexStrategy.stableFnv,
      referenceProfile: ZReferenceProfile.legacy,
      // Plancher tactile : jamais réduit par un thème (invariant AD-13).
      studySessionMinTarget: ZClassicSurfaceReference.minTapTarget,
    );
  }

  /// Résolveur de couleur du thème Classic, à brancher sur
  /// `ZcrudScope.colorKeyResolver`.
  ///
  /// Répond aux clés de paliers SRS
  /// ([ZClassicSrsPaletteReference.colorKeyPrefix]) et rend `null` pour toute
  /// autre clé — le socle poursuit alors sa chaîne (rôles Material 3, puis
  /// slot déterministe). Le thème n'écrase donc jamais une clé qu'il ne
  /// connaît pas.
  static ZColorPair? colorKeys(ColorScheme scheme, String colorKey) {
    const String prefix = ZClassicSrsPaletteReference.colorKeyPrefix;
    if (!colorKey.startsWith(prefix)) return null;
    final ZClassicSrsStep? step = ZClassicSrsPaletteReference.byName(
      colorKey.substring(prefix.length),
    );
    if (step == null) return null;
    return ZColorPair(color: step.color, onColor: step.onColor);
  }

  /// Résolveur de dégradé du thème Classic, à brancher sur
  /// `ZcrudScope.gradientResolver`.
  ///
  /// Répond aux clés de type de carte (`flashcard.type.<type>`) et à la clé de
  /// la médaille de célébration ; rend `null` ailleurs, de sorte qu'un écran
  /// sans dégradé déclaré garde exactement son rendu.
  ///
  /// Branché sur le seam, ce résolveur passe **devant** le jeton
  /// `ZcrudTheme.flashcardTypeGradients` que [forTheme] pose — sans effet
  /// visible, les deux portant la même table. Un hôte qui branche son propre
  /// résolveur à la place voit le sien peindre : c'est la règle générale, pas
  /// une exception faite à ce thème.
  static ZGradientSpec? gradients(ColorScheme scheme, String gradientKey) {
    if (gradientKey == ZClassicCelebrationReference.badgeGradientKey) {
      return ZClassicCelebrationReference.badgeGradient;
    }
    if (!gradientKey.startsWith(_kFlashcardTypeGradientKeyPrefix)) return null;
    return ZClassicCardGradientsReference.typeGradients[
        gradientKey.substring(_kFlashcardTypeGradientKeyPrefix.length)];
  }

  /// Le résolveur [colorKeys] typé comme le seam qu'il alimente.
  static const ZColorKeyResolver colorKeyResolver = colorKeys;

  /// Le résolveur [gradients] typé comme le seam qu'il alimente.
  static const ZGradientResolver gradientResolver = gradients;

  /// Seam `qualityColorKeyFor` : la clé de couleur du cran [quality].
  ///
  /// Rend une clé, résolue ensuite par [colorKeys]. Le cran ne porte donc
  /// jamais une couleur en dur, et un hôte peut intercepter la clé pour la
  /// peindre autrement.
  static String qualityColorKeyFor(int quality) =>
      ZClassicSrsPaletteReference.colorKeyFor(quality);

  /// Seam `qualityLabelKeyFor` : la clé l10n du libellé du cran [quality].
  ///
  /// Les crans Classic ont une identité nommée (`fail`…`perfect`) : la clé la
  /// porte, plutôt que le seul numéro de qualité.
  static String qualityLabelKeyFor(int quality) =>
      ZClassicSrsPaletteReference.labelKeyFor(quality);

  /// Clé l10n de l'aperçu d'intervalle du cran [quality].
  ///
  /// Le seam `qualityPreviewLabelFor` du socle rend un **texte affiché** ; ce
  /// paquet n'en produit aucun. Cette méthode rend la clé, et [previewLabelFor]
  /// fabrique le seam en la composant avec le résolveur de l'hôte.
  static String qualityPreviewLabelKeyFor(int quality) =>
      ZClassicSrsPaletteReference.previewKeyFor(quality);

  /// Fabrique le seam `qualityPreviewLabelFor` à partir du résolveur l10n
  /// [label] de l'hôte.
  ///
  /// ```dart
  /// previewLabelFor: ZClassicTheme.previewLabelFor(
  ///   (key) => AppLocalizations.of(context).lookup(key),
  /// ),
  /// ```
  ///
  /// Le texte affiché reste ainsi produit par l'hôte, dans sa langue : ce
  /// paquet ne fournit que la clé.
  static String Function(int quality) previewLabelFor(
    String Function(String key) label,
  ) =>
      (int quality) => label(qualityPreviewLabelKeyFor(quality));

  /// Seam `qualityEmphasis` : l'affordance des crans du thème Classic.
  ///
  /// Des dimensions seulement — jamais une couleur : la teinte vient de
  /// [qualityColorKeyFor] et de [colorKeys]. Le cran sélectionné est plus
  /// opaque et plus épais que les autres ; l'emphase s'ajoute aux canaux non
  /// chromatiques du socle (`Semantics(selected:)`, coche) sans les remplacer
  /// (invariant AD-13).
  // Relevé : `…/widgets/interactive_flashcard_repetition_card.dart:682-692` —
  // fond `alpha 8` (ordinaire) / `alpha 20` (sélectionné), bord `width 1` / `2`.
  static const ZSrsQualityEmphasis qualityEmphasis = ZSrsQualityEmphasis(
    fillOpacity: 8 / 255,
    selectedFillOpacity: 20 / 255,
    borderWidth: 1,
    selectedBorderWidth: 2,
  );
}
