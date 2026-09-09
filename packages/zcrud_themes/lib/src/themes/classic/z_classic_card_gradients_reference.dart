/// **Unique** fichier de référence COULEUR de la famille « dégradés par type
/// de carte » du thème Classic.
///
/// Quatre dégradés, un par type de carte porteur d'une identité. Un dégradé
/// n'est pas un rôle de `ColorScheme` : il n'est donc pas dérivable, et entre
/// comme référence auditée (exception FR-26 encadrée, centralisée ici).
///
/// ## `onGradient` est MESURÉ, jamais décrété
///
/// Le premier plan de chaque dégradé est celui des deux candidats achromatiques
/// (blanc, noir) dont le contraste sur la **bande médiane** est le plus élevé,
/// et le contrat rendu est `>= kZNonTextMinContrast` (3.0:1) pour les quatre.
/// Une garde recalcule ces ratios avec `zContrastRatio` et rougit si l'un
/// d'eux passe sous le plancher ou si le candidat retenu change.
///
/// ## La table est CELLE DU SOCLE, à l'octet
///
/// [typeGradients] est strictement égale à `ZFlashcardCardReference`
/// `.typeGradients` (`zcrud_study`) : mêmes clés, mêmes arrêts, même sens,
/// mêmes premiers plans. Poser le thème ne change donc pas le dégradé d'un
/// type de carte — il rend seulement explicite, au maillon JETON, ce que le
/// socle applique déjà au dernier maillon. Une garde de source lit la
/// référence du socle sur disque et rougit à la première divergence, d'un côté
/// comme de l'autre.
///
/// ## Le maillon jeton est un REPLI
///
/// Les deux cartes qui lisent cette table consultent le seam
/// `ZcrudScope.gradientResolver` **avant** elle : un hôte qui branche son
/// propre résolveur de dégradés par type voit **son** résolveur peindre, et
/// cette table ne sert plus que là où il se tait. Un hôte qui veut au
/// contraire que sa table gagne ne pose pas de résolveur pour ces clés.
///
/// ## Les clés, pas les couleurs
///
/// La table [typeGradients] est indexée par le **nom** du type de carte
/// (`ZFlashcardType.name`), et non par le type lui-même : c'est la forme
/// qu'attend le jeton `ZcrudTheme.flashcardTypeGradients`, et c'est ce qui
/// laisse un type futur, inconnu de ce fichier, retomber proprement sur
/// l'accent uni du socle (chaîne totale, invariant AD-10).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcardType;

/// Blanc opaque — candidat de premier plan, retenu ou écarté par mesure.
const Color _kWhite = Color(0xFFFFFFFF);

/// Noir opaque — candidat de premier plan, retenu ou écarté par mesure.
const Color _kBlack = Color(0xFF000000);

// Relevé : `lib/src/presentation/features/flashcards/widgets/
// flashcard_widgets.dart:149-160`, getter `_typeGradient` de la carte de
// grille/liste du code de référence.
//
// ⚠️ PIÈGE MESURÉ — le code de référence porte DEUX tables de dégradés par
// type, dans deux widgets différents, et elles sont MUTUELLEMENT INVERSÉES sur
// `openQuestion` et `exercise` :
//   carte de grille/liste (`flashcard_widgets.dart:149-160`, retenue ICI) :
//     openQuestion cyan,  exercise rose
//   carte de répétition (`interactive_flashcard_repetition_card.dart:105-108`) :
//     openQuestion rose,  exercise cyan
// Le socle (`ZFlashcardCardReference`, zcrud_study) réplique la PREMIÈRE, et
// elle seule. Ce fichier la réplique aussi : une table unique, et une garde
// (`z_socle_gradient_parity_test.dart`) prouve l'égalité stricte entre les
// deux. Ne jamais « corriger » ces deux entrées sans avoir rouvert
// `FlashcardCard._typeGradient`.

ZGradientSpec _spec(Color a, Color b, Color on) => ZGradientSpec(
      gradient: LinearGradient(
        // AD-13 : alignements DIRECTIONNELS — le sens suit celui du texte.
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: <Color>[a, b],
      ),
      onGradient: on,
    );

/// Les quatre dégradés par type de carte du thème Classic — point d'audit
/// unique.
abstract final class ZClassicCardGradientsReference {
  /// `multipleChoice` : `#667eea → #764ba2` (violet), premier plan blanc.
  static final ZGradientSpec multipleChoice =
      _spec(const Color(0xFF667EEA), const Color(0xFF764BA2), _kWhite);

  /// `trueOrFalse` : `#11998e → #38ef7d` (sarcelle → vert), premier plan noir.
  static final ZGradientSpec trueOrFalse =
      _spec(const Color(0xFF11998E), const Color(0xFF38EF7D), _kBlack);

  /// `openQuestion` : `#4facfe → #00f2fe` (bleu → cyan), premier plan noir.
  static final ZGradientSpec openQuestion =
      _spec(const Color(0xFF4FACFE), const Color(0xFF00F2FE), _kBlack);

  /// `exercise` : `#f093fb → #f5576c` (rose → corail), premier plan noir.
  static final ZGradientSpec exercise =
      _spec(const Color(0xFFF093FB), const Color(0xFFF5576C), _kBlack);

  /// Table `nom de type → dégradé`, dans la forme attendue par le jeton
  /// `ZcrudTheme.flashcardTypeGradients` — un **repli**, que le seam
  /// `ZcrudScope.gradientResolver` de l'hôte précède.
  ///
  /// Strictement égale à `ZFlashcardCardReference.typeGradients` — l'égalité
  /// est vérifiée par machine, pas affirmée.
  ///
  /// Un type absent de la table (`fillBlank`, `shortAnswer`, ou tout type
  /// futur) rend `null` : la carte retombe alors sur l'accent uni du socle,
  /// sans exception (invariant AD-10).
  static final Map<String, ZGradientSpec> typeGradients =
      Map<String, ZGradientSpec>.unmodifiable(<String, ZGradientSpec>{
    ZFlashcardType.multipleChoice.name: multipleChoice,
    ZFlashcardType.trueOrFalse.name: trueOrFalse,
    ZFlashcardType.openQuestion.name: openQuestion,
    ZFlashcardType.exercise.name: exercise,
  });
}
