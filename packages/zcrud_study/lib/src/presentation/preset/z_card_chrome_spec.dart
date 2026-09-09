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

/// Résout la teinte d'ombre d'une carte **au site de montage**.
///
/// Le `BuildContext` est ce qui distingue ce contrat de la simple valeur
/// [ZCardChromeSpec.shadowColor] : il donne accès aux chaînes de résolution du
/// socle (résolveur de l'hôte, jetons de thème), donc à une teinte qui dépend
/// du thème courant et de la carte, et non d'une constante décrite d'avance.
///
/// `null` signifie « aucune teinte pour cette carte » : la carte reprend alors
/// sa propre chaîne (jeton de thème, puis aucune ombre).
typedef ZCardShadowColorResolver = Color? Function(
  BuildContext context,
  ZFlashcard card,
);

/// Habillage de la carte de session — un descripteur, jamais un widget.
///
/// Chaque champ nul est **absent** : il laisse la chaîne de résolution
/// habituelle de la carte décider (seam de l'hôte, puis jeton de thème). Poser
/// un champ ne fait donc jamais que **prendre la main** sur ce maillon-là.
///
/// Les champs d'habillage sont battus par leur paramètre homonyme de l'écran
/// de session quand celui-ci est posé : un paramètre explicite gagne toujours.
@immutable
class ZCardChromeSpec {
  /// Décrit un habillage. Tout champ omis reste résolu comme aujourd'hui.
  const ZCardChromeSpec({
    this.typeGradientKey,
    this.instructionBanner,
    this.questionTypeBadgeBuilder,
    this.accentHeight,
    this.shadowColor,
    this.shadowColorResolver,
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

  /// Teinte d'ombre portée, décrite en VALEUR.
  ///
  /// Prime [shadowColorResolver] : une teinte explicitement demandée gagne sur
  /// une teinte dérivée. `null` ⇒ le résolveur décide, et à défaut la carte
  /// reprend sa propre chaîne (jeton de thème, puis aucune ombre).
  ///
  /// Seule la TEINTE est décrite ici : la carte applique elle-même l'opacité,
  /// le flou et le décalage de son ombre.
  final Color? shadowColor;

  /// Teinte d'ombre dérivée, résolue **au site de montage**.
  ///
  /// Sert ce qu'une valeur ne peut pas exprimer : une teinte qui dépend du
  /// thème courant et de la carte rendue — par exemple une teinte par type de
  /// question, qu'un jeton de thème (valeur unique) ne peut pas porter.
  ///
  /// Battu par [shadowColor] quand les deux sont posés. `null` des deux côtés
  /// ⇒ le chrome ne dit rien de l'ombre, et le jeton de thème garde la main.
  final ZCardShadowColorResolver? shadowColorResolver;

  /// La teinte d'ombre effective pour [card] dans [context].
  ///
  /// Priorité **valeur > résolveur > rien**. Le `null` rendu quand le chrome
  /// ne décrit aucune ombre est significatif : transmis tel quel à la carte,
  /// il laisse le jeton de thème peindre — le chrome ne l'écrase jamais.
  Color? resolveShadowColor(BuildContext context, ZFlashcard card) =>
      shadowColor ?? shadowColorResolver?.call(context, card);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCardChromeSpec &&
          runtimeType == other.runtimeType &&
          typeGradientKey == other.typeGradientKey &&
          instructionBanner == other.instructionBanner &&
          questionTypeBadgeBuilder == other.questionTypeBadgeBuilder &&
          accentHeight == other.accentHeight &&
          shadowColor == other.shadowColor &&
          shadowColorResolver == other.shadowColorResolver;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        typeGradientKey,
        instructionBanner,
        questionTypeBadgeBuilder,
        accentHeight,
        shadowColor,
        shadowColorResolver,
      );

  @override
  String toString() => 'ZCardChromeSpec(typeGradientKey: $typeGradientKey, '
      'accentHeight: $accentHeight, shadowColor: $shadowColor, '
      'shadowColorResolver: '
      '${shadowColorResolver == null ? 'absent' : 'présent'})';
}
