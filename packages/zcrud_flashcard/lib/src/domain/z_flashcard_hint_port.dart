/// Seam IA neutre de génération d'indices `ZFlashcardHintPort`.
///
/// Contrat pur (`abstract interface class`) : l'application hôte
/// l'implémente avec son propre routeur IA.
///
/// ## L'ordre est le contrat
///
/// 1. l'indice stocké (`ZFlashcard.hint`) est servi d'abord ;
/// 2. ce port n'est appelé qu'après épuisement de l'indice stocké.
///
/// Une carte qui porte déjà son indice n'a rien à générer — appeler le port
/// dès la première demande coûterait un aller-retour réseau, de la latence
/// et du quota pour produire un texte qu'on avait déjà.
///
/// ## Anti-répétition
///
/// [ZFlashcardHintRequest.shownHints] transporte les indices déjà montrés
/// (le stocké inclus) — sans eux, le barème regénérerait une paraphrase du
/// même indice, et l'apprenant paierait un indice pour n'apprendre rien de
/// neuf.
///
/// ## Les indices générés sont éphémères
///
/// Ils ne sont jamais persistés sur la carte. La `ZFlashcard` reçue par la
/// surface n'est jamais mutée et aucune écriture de repository n'a lieu. Un
/// indice généré est une aide de session, pas une donnée de la carte : le
/// persister ferait dériver silencieusement le contenu utilisateur au gré
/// des appels IA.
///
/// `abstract interface class` (invariant AD-4) : frontière inter-paquet,
/// donc jamais `sealed`. `Either<ZFailure,·>` (invariant AD-5) : un échec —
/// ou même une exception levée par l'implémentation applicative — ne fait
/// jamais remonter d'exception (invariant AD-10) et n'incrémente pas le
/// compteur d'indices : un indice non obtenu ne doit pas pénaliser
/// l'apprenant.
///
/// Ce port vit dans `zcrud_flashcard` pour la même raison que le port
/// d'évaluation de réponse voisin : le loger dans le paquet d'étude
/// créerait un cycle de dépendances (invariant AD-1).
library;

import 'package:zcrud_core/domain.dart';

import 'z_flashcard_type.dart';

/// Requête immuable de génération d'indice (value-object, `==`/`hashCode`
/// par valeur).
class ZFlashcardHintRequest {
  /// Construit une requête d'indice.
  const ZFlashcardHintRequest({
    required this.question,
    required this.cardType,
    this.expectedAnswer,
    this.shownHints = const <String>[],
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Énoncé de la carte (`ZFlashcard.question`).
  final String question;

  /// Type de la carte.
  final ZFlashcardType cardType;

  /// Réponse attendue (`ZFlashcard.answer`), ou `null`.
  final String? expectedAnswer;

  /// Indices déjà montrés, dans l'ordre d'affichage (anti-répétition).
  ///
  /// Inclut l'indice stocké (`ZFlashcard.hint`) dès lors qu'il a été servi :
  /// c'est précisément lui que le barème ne doit pas paraphraser au tap
  /// suivant. Cumulatif au fil des demandes.
  final List<String> shownHints;

  /// Emplacement brut de l'échappatoire (normalisé à la lecture via
  /// [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres applicatifs neutres). Défaut
  /// `const {}`. Normalisée à la lecture : clés de synchronisation
  /// réservées écartées.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra].
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardHintRequest &&
          question == other.question &&
          cardType == other.cardType &&
          expectedAnswer == other.expectedAnswer &&
          _listEquals(shownHints, other.shownHints) &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        question,
        cardType,
        expectedAnswer,
        Object.hashAll(shownHints),
        zJsonHash(extra),
      );

  @override
  String toString() =>
      'ZFlashcardHintRequest(cardType: $cardType, shownHints: $shownHints)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Port neutre de génération d'indice (invariant AD-5 : `Either<ZFailure,·>`).
abstract interface class ZFlashcardHintPort {
  /// Génère un indice neuf pour [request].
  ///
  /// Appelé uniquement après épuisement de l'indice stocké
  /// (`ZFlashcard.hint`). Le résultat est éphémère : jamais persisté sur la
  /// carte.
  ///
  /// `Left` en cas d'échec (quota, réseau) : le consommateur affiche un
  /// message localisé, sans exception (invariant AD-10), et n'incrémente
  /// pas le compteur d'indices.
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request);
}
