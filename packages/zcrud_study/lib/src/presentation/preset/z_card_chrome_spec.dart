/// Chrome de la carte de session : ce qui l'habille, décrit une fois.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardQuestionTypeBadgeBuilder;

/// Décrit le chrome de la carte à afficher pour une carte donnée.
///
/// Appelé pour **la carte réellement rendue** : la description peut donc
/// dépendre de son type, de son dossier ou de n'importe laquelle de ses
/// données.
typedef ZCardChromeSpecBuilder = ZCardChromeSpec Function(ZFlashcard card);

/// Habillage de la carte de session — un descripteur, jamais un widget.
///
/// Chaque champ nul est **absent** : il laisse la chaîne de résolution
/// habituelle de la carte décider (seam de l'hôte, puis jeton de thème). Poser
/// un champ ne fait donc jamais que **prendre la main** sur ce maillon-là.
///
/// Les quatre champs sont battus par leur paramètre homonyme de l'écran de
/// session quand celui-ci est posé : un paramètre explicite gagne toujours.
@immutable
class ZCardChromeSpec {
  /// Décrit un habillage. Tout champ omis reste résolu comme aujourd'hui.
  const ZCardChromeSpec({
    this.typeGradientKey,
    this.instructionBanner,
    this.questionTypeBadgeBuilder,
    this.accentHeight,
  });

  /// Clé de dégradé soumise **telle quelle** au résolveur de l'hôte.
  ///
  /// Court-circuite la clé que la carte dériverait du type de la flashcard.
  /// La même résolution peint le liseré de tête **et** la pastille de type :
  /// les deux ne peuvent pas diverger.
  final String? typeGradientKey;

  /// Bandeau de consigne, déjà localisé par l'hôte.
  ///
  /// Rendu sous la question, insensible aux gestes : il n'intercepte jamais la
  /// commande de révélation de la carte.
  final Widget? instructionBanner;

  /// Construit la pastille annonçant le type de question.
  ///
  /// `null` ⇒ **aucune pastille dans l'arbre** — jamais une pastille vide.
  final ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder;

  /// Hauteur du liseré dégradé de tête de carte.
  ///
  /// C'est le **seul interrupteur** du liseré côté paramètre : `null` laisse le
  /// jeton de thème `accentBarHeight` décider, et les deux nuls ⇒ aucun liseré.
  /// Un liseré demandé sans dégradé résoluble n'est pas peint pour autant : il
  /// faut une clé — celle du type, ou [typeGradientKey].
  final double? accentHeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCardChromeSpec &&
          runtimeType == other.runtimeType &&
          typeGradientKey == other.typeGradientKey &&
          instructionBanner == other.instructionBanner &&
          questionTypeBadgeBuilder == other.questionTypeBadgeBuilder &&
          accentHeight == other.accentHeight;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        typeGradientKey,
        instructionBanner,
        questionTypeBadgeBuilder,
        accentHeight,
      );

  @override
  String toString() => 'ZCardChromeSpec(typeGradientKey: $typeGradientKey, '
      'accentHeight: $accentHeight)';
}
