/// Entrée **neutre** du gabarit PDF flashcards (su-11, AC1/AC3/T1).
///
/// origine: su-11 (FR-SU16). `ZFlashcardPdfTemplate` est une fonction PURE de
/// `zcrud_export` : elle ne peut PAS importer `zcrud_flashcard` (l'arête réelle
/// est `zcrud_flashcard → zcrud_export`, jamais l'inverse — AD-1). Le modèle
/// d'entrée est donc **projeté chez l'appelant** (`zcrud_flashcard`/app) en
/// primitives neutres : c'est cette projection que reçoit le gabarit.
///
/// **Type de carte = clé neutre `String`** (`typeKey`, camelCase, ex.
/// `"multipleChoice"`), JAMAIS l'enum `ZFlashcardType` de `zcrud_flashcard` (qui
/// forcerait une arête interdite). Une clé inconnue/absente retombe défensivement
/// sur le badge « question ouverte » ([kFlashcardPdfTypeOpenQuestion]) — AD-10.
///
/// **Libellés injectés** ([ZFlashcardPdfLabels]) : le gabarit produit des BYTES
/// sans `BuildContext` (aucune l10n runtime possible) ; les libellés (badges,
/// « Réponse », « Explication »…) sont donc **fournis par l'appelant** (défauts
/// FR documentés), jamais figés dans le rendu (esprit AD-13/FR-26).
library;

/// Clés de type **neutres** (camelCase = `ZFlashcardType.name`) — miroir STABLE
/// des 6 types canoniques, sans dépendre de `zcrud_flashcard`. L'appelant
/// projette `card.type.name` vers l'une d'elles ; le gabarit les mappe à un badge.
const String kFlashcardPdfTypeMultipleChoice = 'multipleChoice';

/// Vrai/Faux — réponse portée par [ZFlashcardPdfCard.isTrue].
const String kFlashcardPdfTypeTrueOrFalse = 'trueOrFalse';

/// Question ouverte — **valeur de repli défensive** (type inconnu → celle-ci).
const String kFlashcardPdfTypeOpenQuestion = 'openQuestion';

/// Exercice.
const String kFlashcardPdfTypeExercise = 'exercise';

/// Texte à trous.
const String kFlashcardPdfTypeFillBlank = 'fillBlank';

/// Réponse courte.
const String kFlashcardPdfTypeShortAnswer = 'shortAnswer';

/// Un choix de QCM **neutre** : libellé + caractère correct (projeté depuis
/// `ZChoice`). Immuable.
class ZFlashcardPdfChoice {
  /// Construit un choix neutre.
  const ZFlashcardPdfChoice({this.content = '', this.isCorrect = false});

  /// Libellé du choix.
  final String content;

  /// `true` si ce choix est correct (rendu ✓ vert en `withAnswers`).
  final bool isCorrect;
}

/// Une carte **projetée en primitives neutres** (aucun type `zcrud_flashcard`).
///
/// Défensif (AD-10) : tous les champs sont tolérants — [question] `''` admise,
/// [choices]/[answer]/[explanation]/[isTrue] `null` admis, [typeKey] inconnu
/// retombe sur « question ouverte ».
class ZFlashcardPdfCard {
  /// Construit une carte neutre pour le gabarit PDF.
  const ZFlashcardPdfCard({
    this.typeKey = kFlashcardPdfTypeOpenQuestion,
    this.question = '',
    this.answer,
    this.isTrue,
    this.choices,
    this.explanation,
  });

  /// Clé de type neutre (camelCase). Inconnue/absente → badge « question ouverte ».
  final String typeKey;

  /// Énoncé de la carte (peut contenir des formules LaTeX inline `$...$`).
  final String question;

  /// Réponse libre distinguée (masquée en `withoutAnswers`). Peut contenir du LaTeX.
  final String? answer;

  /// Réponse V/F (masquée en `withoutAnswers`).
  final bool? isTrue;

  /// Choix de QCM (marqués ✓/✗ en `withAnswers`, non marqués en `withoutAnswers`).
  final List<ZFlashcardPdfChoice>? choices;

  /// Explication (masquée en `withoutAnswers`). Peut contenir du LaTeX.
  final String? explanation;
}

/// Libellés **injectés** du gabarit (défauts FR documentés). Aucun texte figé
/// dans le rendu : l'appelant peut fournir des libellés localisés (AD-13/FR-26).
class ZFlashcardPdfLabels {
  /// Construit un jeu de libellés (défauts FR).
  const ZFlashcardPdfLabels({
    this.multipleChoice = 'QCM — cochez la ou les bonne(s) réponse(s)',
    this.trueOrFalse = 'Vrai ou faux ?',
    this.openQuestion = 'Question ouverte',
    this.exercise = 'Exercice',
    this.fillBlank = 'Texte à trous — complétez',
    this.shortAnswer = 'Réponse courte',
    this.answerLabel = 'Réponse',
    this.explanationLabel = 'Explication',
    this.trueLabel = 'Vrai',
    this.falseLabel = 'Faux',
  });

  /// Badge du type QCM.
  final String multipleChoice;

  /// Badge du type Vrai/Faux.
  final String trueOrFalse;

  /// Badge du type question ouverte (aussi utilisé comme **repli** défensif).
  final String openQuestion;

  /// Badge du type exercice.
  final String exercise;

  /// Badge du type texte à trous.
  final String fillBlank;

  /// Badge du type réponse courte.
  final String shortAnswer;

  /// Préfixe de la réponse distinguée.
  final String answerLabel;

  /// Préfixe de l'explication.
  final String explanationLabel;

  /// Libellé « vrai » (V/F).
  final String trueLabel;

  /// Libellé « faux » (V/F).
  final String falseLabel;

  /// Badge pour une [typeKey] neutre — repli défensif sur [openQuestion]
  /// (AD-10 : clé inconnue/absente jamais fatale). **Table unique** de décision.
  String badgeFor(String typeKey) => switch (typeKey) {
        kFlashcardPdfTypeMultipleChoice => multipleChoice,
        kFlashcardPdfTypeTrueOrFalse => trueOrFalse,
        kFlashcardPdfTypeExercise => exercise,
        kFlashcardPdfTypeFillBlank => fillBlank,
        kFlashcardPdfTypeShortAnswer => shortAnswer,
        _ => openQuestion,
      };
}

/// Entrée complète du gabarit : titre + cartes + mode d'affichage + libellés.
class ZFlashcardPdfInput {
  /// Construit l'entrée du gabarit.
  const ZFlashcardPdfInput({
    this.title = '',
    this.cards = const <ZFlashcardPdfCard>[],
    this.labels = const ZFlashcardPdfLabels(),
  });

  /// Titre du document (rendu en tête ; dossier entier **ou** sélection).
  final String title;

  /// Les cartes à rendre (dossier entier ou sélection). Vide → PDF 1 page (titre).
  final List<ZFlashcardPdfCard> cards;

  /// Libellés injectés (défauts FR).
  final ZFlashcardPdfLabels labels;
}
