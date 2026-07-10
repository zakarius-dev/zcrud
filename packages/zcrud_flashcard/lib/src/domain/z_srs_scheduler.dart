/// Interface `ZSrsScheduler` — planificateur de répétition espacée
/// **REMPLAÇABLE** (Story E9-2, AC3 ; FR-17 ; AD-9).
///
/// origine: lex_core (module « Étude ») — `ZSrs`/`Sm2` (canonique §2.1, l.75) :
/// l'algorithme de répétition espacée est **derrière une interface** pour
/// pouvoir brancher FSRS/Leitner **sans toucher les modèles** (`ZRepetitionInfo`
/// reste inchangé). `ZSm2Scheduler` en est l'implémentation par défaut
/// (SuperMemo-2).
///
/// **VOIE D'ÉCRITURE UNIQUE (AD-9)** : [apply] est l'**unique** transformation
/// produisant un état SRS avancé ; [initial] est l'**unique** création d'un
/// état neuf. Aucune autre API publique ne fait progresser l'état (cf.
/// `ZRepetitionInfo` : pas de `copyWith`/setter SRS public).
///
/// **Pur, sans état, horloge injectée (AD-14)** : un scheduler ne porte
/// **aucun** état mutable (réutilisable, thread-safe) ; l'horloge est passée en
/// paramètre (`now`, défaut `DateTime.now()` **au sein de l'impl**, jamais
/// capturée à la construction) pour un déterminisme total en test.
///
/// **Jamais `sealed`** (AD-4) : extension inter-package/app (FSRS/Leitner)
/// possible sans forker ce package.
library;

import 'z_repetition_info.dart';

/// Contrat d'un planificateur de répétition espacée (remplaçable).
abstract interface class ZSrsScheduler {
  /// **Unique voie d'avancement (AD-9)** : applique une révision de [quality]
  /// (`0..5`, clampée défensivement par l'impl — AC6) à l'état [current] et
  /// retourne une **nouvelle** [ZRepetitionInfo] (fonction pure, jamais de
  /// mutation en place).
  ///
  /// [now] injecte l'horloge (défaut `DateTime.now()` dans l'impl) : l'échéance
  /// (`nextReviewDate`) est calculée relativement à ce point.
  ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now});

  /// Prévisualise le prochain état **sans** le persister (sémantique
  /// « projection ») : retourne l'état que produirait [apply] pour [quality],
  /// sans effet de bord. Peut simplement déléguer à [apply].
  ZRepetitionInfo simulate(ZRepetitionInfo current, int quality,
      {DateTime? now});

  /// Crée un état neuf déterministe pour la carte [flashcardId] du dossier
  /// [folderId] (le SEUL autre write autorisé hors [apply], cf. canonique
  /// `initRepetition`) : compteurs à zéro, `easeFactor` = défaut de la config,
  /// dates `null`.
  ZRepetitionInfo initial({
    required String flashcardId,
    required String folderId,
  });
}
