/// Évaluation **LOCALE** exacte des QCM et Vrai/Faux (Story SU-3, AC1 — AD-35).
///
/// 🔒 **Fonctions PURES** : aucun Flutter, aucun port, aucune I/O, aucun état.
/// Testables hors widget.
///
/// **Pourquoi local et non IA (AD-35)** : pour un QCM ou un Vrai/Faux, la bonne
/// réponse est **déjà portée par la carte** (`ZChoice.isCorrect`,
/// `ZFlashcard.isTrue`). Une comparaison ensembliste est **exacte, instantanée
/// et gratuite** ; un appel IA serait **coûteux, latent et faillible** — il
/// pourrait même contredire la donnée. **Écart ASSUMÉ avec IFFD** (qui fait
/// passer QCM/VF par l'IA) : ne pas « corriger » vers IFFD.
///
/// 🔒 **Les bornes sont LUES sur `ZSrsConfig`** (AD-46), jamais `5`/`0` en dur :
/// `ZSrsConfig` est le **propriétaire unique** de l'échelle. Une app qui tronque
/// l'échelle (`minQuality: 1`) le fait **une seule fois** et l'évaluation suit
/// par construction.
library;

import 'z_flashcard.dart';
import 'z_srs_config.dart';

/// Vrai si [type] est évalué **LOCALEMENT** (jamais par le port IA — AD-35).
///
/// 🔒 **C'est CETTE fonction qui décide du routage**, et elle ne regarde que le
/// **type** — jamais le résultat de [zEvaluateLocally].
///
/// **Pourquoi cette distinction est vitale** : [zEvaluateLocally] rend `null`
/// dans **deux** cas très différents — (a) le type n'est pas local, (b) le type
/// **est** local mais la carte est **malformée** (`choices` absent/vide,
/// `isTrue == null`). Router sur « `null` ⇒ appeler le port » enverrait donc un
/// **QCM malformé à l'IA** — exactement ce qu'AD-35 interdit, et de façon
/// **silencieuse** (aucun test de chemin nominal ne le verrait). Le routage se
/// fait donc **par le type**, une fois pour toutes, ici.
///
/// Cas (b) : la surface **n'offre pas de saisie** (AD-10) — il n'y a donc aucune
/// soumission à router.
///
/// 🔒 **Elle est RÉELLEMENT le routeur** (`ZFlashcardAnswerInput._submitWritten`
/// l'appelle et refuse le port si elle rend `true`) : c'est la **seule** table
/// qui décide « port ou local ». Le `switch` d'affordance de saisie de la surface
/// décide **quel widget monter** — un objet différent, un propriétaire différent.
/// ⚠️ Cette fonction a été, un temps, documentée ici et dans le barrel comme « la
/// voie de routage » alors qu'elle n'avait **AUCUN site d'appel** : la décision
/// était en fait prise par le `switch` d'affordance. Deux tables décidaient la
/// même chose sans rien qui les lie — une 7ᵉ valeur (`cloze`) déclarée `true`
/// ici mais rangée dans la chaîne `||` des types rédigés là-bas aurait envoyé à
/// l'IA un type déclaré **LOCAL**, en compilant vert. La seconde source est
/// supprimée, et `z_flashcard_answer_input_qcm_vf_test.dart` **lie les deux
/// tables** sur les **6** types (`spy.callCount == 0 ⟺ zIsLocallyEvaluatedType`).
bool zIsLocallyEvaluatedType(ZFlashcardType type) => switch (type) {
  ZFlashcardType.multipleChoice => true,
  ZFlashcardType.trueOrFalse => true,
  ZFlashcardType.openQuestion => false,
  ZFlashcardType.exercise => false,
  ZFlashcardType.fillBlank => false,
  ZFlashcardType.shortAnswer => false,
};

/// Vrai si le QCM [card] est à **choix unique** — 🔒 **DÉDUIT** du nombre de
/// `ZChoice.isCorrect == true`, **jamais** d'un champ ni d'un paramètre d'app.
///
/// `1` correct ⇒ **choix unique** (cocher B **décoche** A) ; `≥ 2` corrects ⇒
/// **multi-sélection** (cases cumulatives). La donnée **est** la spécification :
/// un champ `isMultiple` séparé pourrait **contredire** les choix eux-mêmes et
/// dériverait en silence.
///
/// Rend `false` pour une carte sans choix exploitables (cf. [zEvaluateLocally],
/// qui n'offre alors aucune saisie).
bool zIsSingleChoiceQcm(ZFlashcard card) =>
    zCorrectChoiceIndexes(card).length == 1;

/// Indices (positions) des choix corrects de [card] — ensemble, jamais une liste.
///
/// **L'identité d'un choix est sa POSITION** : `ZChoice` ne porte **aucun `id`**
/// (champs réels : `content`, `isCorrect` — vérifié sur disque), et deux choix
/// peuvent porter un `content` **identique**. Indexer par contenu confondrait
/// donc deux choix distincts ; la position est la seule identité fiable.
Set<int> zCorrectChoiceIndexes(ZFlashcard card) {
  final choices = card.choices;
  if (choices == null) return const <int>{};
  return <int>{
    for (var i = 0; i < choices.length; i++)
      if (choices[i].isCorrect) i,
  };
}

/// Évalue **LOCALEMENT** la réponse à un QCM ou un Vrai/Faux (AD-35).
///
/// Rend la **qualité** — `config.maxQuality` si la réponse est **exacte**,
/// `config.minQuality` sinon (bornes **LUES**, AD-46) — ou `null` si aucune
/// évaluation locale n'est possible :
/// - le type n'est **pas** local (cf. [zIsLocallyEvaluatedType]) ;
/// - QCM sans `choices` exploitables (`null`, vide, ou **aucun** correct) ;
/// - Vrai/Faux dont `card.isTrue == null`, ou resté **sans réponse**.
///
/// 🔒 **AD-10** : aucun `!`, aucune exception — une carte malformée rend `null`
/// et la surface n'offre simplement **pas de saisie**.
///
/// 🔒 **QCM = ÉGALITÉ ENSEMBLISTE STRICTE**, jamais un sous-ensemble :
/// `{sélection} == {corrects}`. Une bonne réponse **manquante** ⇒ faux ; une
/// mauvaise **cochée** ⇒ faux. Un test par inclusion (`containsAll`) noterait
/// « exact » un apprenant qui a coché **toutes** les cases — l'évaluation
/// deviendrait une formalité.
///
/// 🔒 **Le plafond d'indices n'est PAS appliqué ici** : il l'est **EN DERNIER**,
/// sur la valeur rendue, par `zApplyHintCeiling` (propriétaire **unique**,
/// AD-36) — une pénalité appliquée à deux endroits se cumulerait.
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
      // « réussie par une sélection vide ». Sans ce garde, `{} == {}` rendrait
      // `maxQuality` à qui ne coche RIEN (AD-10 : dégrader, jamais récompenser).
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
      // Types NON locaux : évalués par le port ADVISORY (AC2), jamais ici.
      return null;
  }
}

/// Borne haute si [exact], borne basse sinon — 🔒 **LUES** sur [config] (AD-46).
int _qualityFor({required bool exact, required ZSrsConfig config}) =>
    exact ? config.maxQuality : config.minQuality;

/// Égalité **ensembliste stricte** (jamais une inclusion).
bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
