/// Évaluation locale exacte des QCM et vrai/faux.
///
/// Fonctions pures : aucun Flutter, aucun port, aucune E/S, aucun état.
/// Testables hors widget.
///
/// Pourquoi local et non IA : pour un QCM ou un vrai/faux, la bonne réponse
/// est déjà portée par la carte (`ZChoice.isCorrect`, `ZFlashcard.isTrue`).
/// Une comparaison ensembliste est exacte, instantanée et gratuite ; un
/// appel IA serait coûteux, latent et faillible — il pourrait même
/// contredire la donnée.
///
/// Les bornes sont lues sur `ZSrsConfig`, jamais codées en dur : `ZSrsConfig`
/// est le propriétaire unique de l'échelle. Une application qui tronque
/// l'échelle (`minQuality: 1`) le fait une seule fois et l'évaluation suit
/// par construction.
library;

import 'z_flashcard.dart';
import 'z_srs_config.dart';

/// Vrai si [type] est évalué localement (jamais par le port IA).
///
/// C'est cette fonction qui décide du routage, et elle ne regarde que le
/// type — jamais le résultat de [zEvaluateLocally].
///
/// Pourquoi cette distinction est vitale : [zEvaluateLocally] rend `null`
/// dans deux cas très différents — (a) le type n'est pas local, (b) le type
/// est local mais la carte est malformée (`choices` absent/vide, `isTrue ==
/// null`). Router sur « `null` ⇒ appeler le port » enverrait donc un QCM
/// malformé à l'IA — exactement ce qu'il faut éviter, et de façon
/// silencieuse. Le routage se fait donc par le type, une fois pour toutes,
/// ici.
///
/// Dans le cas (b), la surface n'offre pas de saisie (invariant AD-10) — il
/// n'y a donc aucune soumission à router.
bool zIsLocallyEvaluatedType(ZFlashcardType type) => switch (type) {
  ZFlashcardType.multipleChoice => true,
  ZFlashcardType.trueOrFalse => true,
  ZFlashcardType.openQuestion => false,
  ZFlashcardType.exercise => false,
  ZFlashcardType.fillBlank => false,
  ZFlashcardType.shortAnswer => false,
};

/// Vrai si le QCM [card] est à choix unique — déduit du nombre de
/// `ZChoice.isCorrect == true`, jamais d'un champ ni d'un paramètre
/// applicatif.
///
/// Un seul choix correct ⇒ choix unique (cocher B décoche A) ; deux ou plus
/// ⇒ multi-sélection (cases cumulatives). La donnée est la spécification :
/// un champ séparé pourrait contredire les choix eux-mêmes et dériverait en
/// silence.
///
/// Rend `false` pour une carte sans choix exploitables (voir
/// [zEvaluateLocally], qui n'offre alors aucune saisie).
bool zIsSingleChoiceQcm(ZFlashcard card) =>
    zCorrectChoiceIndexes(card).length == 1;

/// Indices (positions) des choix corrects de [card] — ensemble, jamais une
/// liste.
///
/// L'identité d'un choix est sa position : `ZChoice` ne porte aucun `id`
/// (ses champs réels sont `content` et `isCorrect`), et deux choix peuvent
/// porter un `content` identique. Indexer par contenu confondrait donc deux
/// choix distincts ; la position est la seule identité fiable.
Set<int> zCorrectChoiceIndexes(ZFlashcard card) {
  final choices = card.choices;
  if (choices == null) return const <int>{};
  return <int>{
    for (var i = 0; i < choices.length; i++)
      if (choices[i].isCorrect) i,
  };
}

/// Évalue localement la réponse à un QCM ou un vrai/faux.
///
/// Rend la qualité — `config.maxQuality` si la réponse est exacte,
/// `config.minQuality` sinon (bornes lues sur la configuration) — ou `null`
/// si aucune évaluation locale n'est possible :
/// - le type n'est pas local (voir [zIsLocallyEvaluatedType]) ;
/// - QCM sans `choices` exploitables (`null`, vide, ou aucun correct) ;
/// - vrai/faux dont `card.isTrue == null`, ou resté sans réponse.
///
/// Invariant AD-10 : aucune assertion forcée, aucune exception — une carte
/// malformée rend `null` et la surface n'offre simplement pas de saisie.
///
/// QCM = égalité ensembliste stricte, jamais un sous-ensemble :
/// `{sélection} == {corrects}`. Une bonne réponse manquante ⇒ faux ; une
/// mauvaise cochée ⇒ faux. Un test par inclusion noterait « exact » un
/// apprenant qui a coché toutes les cases — l'évaluation deviendrait une
/// formalité.
///
/// Le plafond d'indices n'est pas appliqué ici : il l'est en dernier, sur la
/// valeur rendue, par `zApplyHintCeiling` (propriétaire unique) — une
/// pénalité appliquée à deux endroits se cumulerait.
int? zEvaluateLocally({
  required ZFlashcard card,
  required Set<int> selectedChoiceIndexes,
  bool? answeredTrue,
  required ZSrsConfig config,
}) {
  switch (card.type) {
    case ZFlashcardType.multipleChoice:
      final choices = card.choices;
      if (choices == null || choices.isEmpty) return null;
      final correct = zCorrectChoiceIndexes(card);
      // Aucun choix correct : la carte est malformée — elle n'est pas
      // « réussie par une sélection vide ». Sans ce garde, `{} == {}`
      // rendrait `maxQuality` à qui ne coche rien (invariant AD-10 :
      // dégrader, jamais récompenser).
      if (correct.isEmpty) return null;
      return _qualityFor(
        exact: _setEquals(selectedChoiceIndexes, correct),
        config: config,
      );
    case ZFlashcardType.trueOrFalse:
      final expected = card.isTrue;
      if (expected == null || answeredTrue == null) return null;
      return _qualityFor(exact: answeredTrue == expected, config: config);
    case ZFlashcardType.openQuestion:
    case ZFlashcardType.exercise:
    case ZFlashcardType.fillBlank:
    case ZFlashcardType.shortAnswer:
      // Types non locaux : évalués par le port consultatif, jamais ici.
      return null;
  }
}

/// Borne haute si [exact], borne basse sinon — lues sur [config].
int _qualityFor({required bool exact, required ZSrsConfig config}) =>
    exact ? config.maxQuality : config.minQuality;

/// Égalité ensembliste stricte (jamais une inclusion).
bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
