/// Interface `ZSrsScheduler` — planificateur de répétition espacée
/// remplaçable.
///
/// L'algorithme de répétition espacée est derrière une interface pour
/// pouvoir brancher un autre algorithme sans toucher les modèles
/// (`ZRepetitionInfo` reste inchangé). `ZSm2Scheduler` en est l'implémentation
/// par défaut (SuperMemo-2).
///
/// ## Voie d'écriture unique
///
/// [apply] est l'unique transformation produisant un état SRS avancé ;
/// [initial] est l'unique création d'un état neuf (invariant AD-9). Aucune
/// autre API publique ne fait progresser l'état (voir `ZRepetitionInfo` : pas
/// de `copyWith`/setter SRS public).
///
/// ## Pur, sans état, horloge injectée
///
/// Un scheduler ne porte aucun état mutable (réutilisable, thread-safe) ;
/// l'horloge est passée en paramètre (`now`, avec un défaut interne à
/// l'implémentation, jamais capturée à la construction) pour un déterminisme
/// total en test.
///
/// Jamais `sealed` (invariant AD-4) : une extension inter-paquet ou
/// applicative (un autre algorithme de répétition espacée) reste possible
/// sans forker ce paquet.
library;

import 'z_repetition_info.dart';

/// Contrat d'un planificateur de répétition espacée (remplaçable).
abstract interface class ZSrsScheduler {
  /// Voie d'avancement unique (invariant AD-9) : applique une révision de
  /// [quality] (`0..5`, clampée défensivement par l'implémentation) à l'état
  /// [current] et retourne une nouvelle [ZRepetitionInfo] (fonction pure,
  /// jamais de mutation en place).
  ///
  /// [now] injecte l'horloge (par défaut, l'heure courante dans
  /// l'implémentation) : l'échéance (`nextReviewDate`) est calculée
  /// relativement à ce point.
  ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now});

  /// Prévisualise le prochain état sans le persister (sémantique
  /// « projection ») : retourne l'état que produirait [apply] pour
  /// [quality], sans effet de bord. Peut simplement déléguer à [apply].
  ZRepetitionInfo simulate(ZRepetitionInfo current, int quality,
      {DateTime? now});

  /// Crée un état neuf déterministe pour la carte [flashcardId] du dossier
  /// [folderId] (le seul autre write autorisé hors [apply]) : compteurs à
  /// zéro, facteur de facilité par défaut de la configuration, dates
  /// `null`.
  ZRepetitionInfo initial({
    required String flashcardId,
    required String folderId,
  });
}
