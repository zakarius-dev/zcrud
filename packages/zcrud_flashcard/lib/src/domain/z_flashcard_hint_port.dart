/// Seam IA neutre de **génération d'indices** `ZFlashcardHintPort`
/// (Story SU-3, AC5 — AD-36).
///
/// origine: seam IA neutre du domaine flashcard (AD-5/AD-36). Contrat **pur**
/// (`abstract interface class`) : l'app hôte l'*implements* avec son routeur IA
/// (patron **exact** `z_flashcard_generation_port.dart`).
///
/// 🔒 **L'ordre est le contrat (AD-36)** — la raison d'être de ce fichier :
/// 1. l'indice **STOCKÉ** (`ZFlashcard.hint`) est servi **D'ABORD** ;
/// 2. ce port n'est appelé qu'**APRÈS ÉPUISEMENT** du stocké.
///
/// AD-36 le dit mot pour mot : « **Prevents** : un appel IA superflu ». Une
/// carte qui **porte déjà** son indice n'a **rien** à générer — appeler le port
/// dès le 1ᵉʳ tap coûterait un aller-retour réseau, de la latence et du quota
/// pour produire un texte **qu'on avait déjà**. La garde de l'AC5 est donc une
/// **assertion d'ABSENCE d'appel** (`hintSpy.callCount == 0` au 1ᵉʳ tap).
///
/// 🔒 **Anti-répétition** : [ZFlashcardHintRequest.shownHints] transporte les
/// indices **déjà montrés** (stocké **inclus**) — sans eux, le barème
/// re-générerait une paraphrase du même indice, et l'apprenant paierait un
/// indice pour n'apprendre **rien de neuf**.
///
/// 🔒 **Les indices générés sont ÉPHÉMÈRES** : **jamais** persistés sur la
/// carte. La `ZFlashcard` reçue par la surface n'est **jamais mutée** et
/// **aucune** écriture de repository n'a lieu (AC5). Un indice généré est une
/// aide **de session**, pas une donnée de la carte : le persister ferait dériver
/// silencieusement le contenu utilisateur au gré des appels IA.
///
/// **`abstract interface class` (AD-4)** : frontière inter-package ⇒ **jamais
/// `sealed`**. **`Either<ZFailure,·>` (AD-5)** : un échec (`Left`) — ou même un
/// `throw` de l'impl app — ne fait **jamais** remonter d'exception (AD-10) et
/// **n'incrémente PAS** le compteur d'indices : un indice **non obtenu** ne doit
/// pas pénaliser l'apprenant (AC5).
///
/// **Foyer imposé par le graphe (AD-1)** : cf.
/// `z_flashcard_answer_evaluation_port.dart` — `zcrud_study` dépend de
/// `zcrud_flashcard`, l'y loger créerait un **cycle**.
library;

import 'package:zcrud_core/domain.dart';

import 'z_flashcard_type.dart';

/// Requête **immuable** de génération d'indice (value-object, `==`/`hashCode`
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

  /// Indices **DÉJÀ MONTRÉS**, dans l'ordre d'affichage — 🔒 anti-répétition
  /// (AD-36).
  ///
  /// Inclut l'indice **stocké** (`ZFlashcard.hint`) dès lors qu'il a été servi :
  /// c'est précisément lui que le barème ne doit pas paraphraser au 2ᵉ tap.
  /// **Cumulatif** : au 3ᵉ tap, il en porte **deux**.
  final List<String> shownHints;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres app-specific neutres). Défaut `const {}`.
  /// **Normalisée à la LECTURE (AD-19.1)** : clés de sync réservées écartées.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1).
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

/// Port neutre de **génération d'indice** (AD-5 : `Either<ZFailure,·>`).
abstract interface class ZFlashcardHintPort {
  /// Génère un indice **neuf** pour [request].
  ///
  /// 🔒 Appelé **UNIQUEMENT après épuisement** de l'indice **stocké**
  /// (`ZFlashcard.hint`) — AD-36 : « Prevents : un appel IA superflu ».
  /// 🔒 Le résultat est **ÉPHÉMÈRE** : jamais persisté sur la carte.
  ///
  /// `Left` en cas d'échec (quota, réseau) : le consommateur affiche un message
  /// l10n, **sans exception** (AD-10), et **n'incrémente pas** le compteur
  /// d'indices.
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request);
}
