/// **Lot 1 « étude »** — les TRANCHES RÉACTIVES de l'écran de session
/// (AD-2/AD-15/SM-1).
///
/// ## 🔴 Pourquoi des tranches, et pas un état d'écran
///
/// L'assemblage de référence (`example/lib/demos/study_session_demo_screen.dart`)
/// pilote tout par `setState` **à l'échelle de l'écran** : 5 sites
/// (`:196`, `:270`, `:333`, `:355`, `:386`, `:531`). C'est acceptable pour une
/// démo ; c'est **interdit** dans le socle — et pas seulement au nom d'AD-2.
///
/// Un `setState` d'écran reconstruit le sous-arbre du swiper à **chaque**
/// notification. Or la `key` de la pile est dérivée de l'identité de la file :
/// un rebuild global qui traverse un changement de file **recrée l'`Element`**
/// du swiper, et c'est exactement le chemin du `RangeError` documenté en su-4
/// D1 (un index survivant à la file qu'il n'indexe plus). La granularité n'est
/// donc pas une optimisation ici : c'est ce qui **empêche** la classe de bug
/// que la dartdoc de la démo passe l'essentiel de son texte à décrire.
///
/// ## Le contrat
///
/// **UNE tranche = UN `ValueListenable`.** [ZStudySessionView] ne reçoit que
/// des listenables et des callbacks : elle ne possède aucun état, ne se
/// reconstruit jamais en entier, et chaque slot est enveloppé dans **son**
/// `ValueListenableBuilder` sur **sa seule** tranche.
///
/// | Tranche | Ce qu'elle pilote — et RIEN d'autre |
/// |---|---|
/// | [ZStudySessionSlices.phase] | l'aiguillage étude / vide / résumé |
/// | [ZStudySessionSlices.queue] | la pile de cartes (et **sa `key`**) |
/// | [ZStudySessionSlices.current] | la surface de saisie + de notation |
/// | [ZStudySessionSlices.progress] | les compteurs |
///
/// Taper dans le champ de réponse ne traverse **aucune** de ces tranches : la
/// saisie vit dans le `State` de `ZFlashcardAnswerInput`. Noter ne traverse que
/// `queue`, `current` et `progress` — jamais l'écran.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSessionItem;

/// Phase de l'écran de session — aiguillage **exhaustif**, jamais un booléen.
///
/// Reprend les trois états réellement atteints par l'assemblage de référence
/// (`_StudyPhase`, `study_session_demo_screen.dart:141`), moins la phase
/// `selecting` : le sélecteur de modes est un écran **amont**
/// (`ZSessionModeSelector`, `zcrud_session`), pas une phase de la session.
enum ZStudySessionPhase {
  /// Une file non vide est en cours d'étude.
  studying,

  /// La file est vide **à l'entrée** : rien à étudier (AD-10 — une issue de
  /// sortie est rendue, jamais un cul-de-sac).
  empty,

  /// La file est épuisée : place au résumé de session.
  celebrating,

  /// 🔴 Le mode demandé **ne peut pas** être servi avec ce qui a été injecté —
  /// en pratique : un mode SRS (`spaced`/`learn`) sans `ZSessionReviewer`.
  ///
  /// Cette phase existe parce que les **deux** échappatoires sont interdites :
  ///
  /// * fabriquer un `ZSessionReviewer` no-op pour « adapter » le moteur SRS est
  ///   nommément la porte dérobée qu'AD-34 ferme (un mode SRS servi sans voie
  ///   d'écriture, en silence — l'apprenant réviserait, et rien ne serait
  ///   jamais enregistré) ;
  /// * router le mode vers `ZLinearSessionState` ferait **lever son `assert`**
  ///   (il refuse `spaced`/`learn` par construction).
  ///
  /// Il ne reste donc qu'à le **dire** : aucun runtime n'est créé, l'écran rend
  /// un repli explicite et son issue de sortie (AD-10 — jamais un throw, jamais
  /// un cul-de-sac, jamais une session muette qui n'écrit rien).
  unavailable,
}

/// Compteurs de session — VO **pur**, recalculé depuis le runtime à chaque
/// transition, jamais accumulé dans un widget.
@immutable
class ZStudySessionProgress {
  /// Construit un instantané de progression.
  const ZStudySessionProgress({
    this.total = 0,
    this.reviewed = 0,
    this.remaining = 0,
    this.lapses = 0,
    this.index = 0,
  });

  /// Nombre de cartes de la file **d'origine**.
  final int total;

  /// Nombre de cartes notées depuis le début de la session.
  final int reviewed;

  /// Nombre de cartes encore en file.
  ///
  /// ⚠️ **`remaining + reviewed != total` en régime SRS**, et c'est correct :
  /// le moteur `ZStudySessionEngine` est **cyclique** — il réinsère les lapses
  /// dans sa file. Une carte ratée est donc comptée dans `reviewed` **et**
  /// toujours présente dans `remaining`. Un compteur qui « corrigerait » cet
  /// écart mentirait sur le travail restant.
  final int remaining;

  /// Nombre de notes sous le seuil de réussite (lapses).
  final int lapses;

  /// Index de la carte de devant dans la file **courante**.
  final int index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySessionProgress &&
          total == other.total &&
          reviewed == other.reviewed &&
          remaining == other.remaining &&
          lapses == other.lapses &&
          index == other.index;

  @override
  int get hashCode => Object.hash(total, reviewed, remaining, lapses, index);

  @override
  String toString() => 'ZStudySessionProgress(total: $total, '
      'reviewed: $reviewed, remaining: $remaining, lapses: $lapses, '
      'index: $index)';
}

/// Le faisceau de tranches qu'un hôte fournit à [ZStudySessionView].
///
/// 🔒 **Aucune valeur nue.** Chaque champ est un `ValueListenable` : c'est ce
/// qui rend structurellement impossible, pour la vue, de se reconstruire en
/// entier — elle n'a pas les valeurs, seulement les sources.
///
/// [ZStudySessionHost] en construit un depuis ses `ValueNotifier` possédés ; un
/// hôte qui détient déjà son propre état peut en construire un depuis les
/// siens, sans passer par le host.
@immutable
class ZStudySessionSlices {
  /// Assemble les quatre tranches.
  const ZStudySessionSlices({
    required this.phase,
    required this.queue,
    required this.current,
    required this.progress,
  });

  /// Phase courante — pilote l'aiguillage, et lui seul.
  final ValueListenable<ZStudySessionPhase> phase;

  /// File **courante** (identités seules).
  ///
  /// 🔴 En régime SRS c'est `engine.state.queue` — la file **dynamique** du
  /// moteur, pas une copie figée prise au démarrage. C'est la clause « une
  /// seule source de séquence » (su-10 D1) : le swiper **suit** le moteur, il
  /// ne tient pas un second curseur qui divergerait au 1ᵉʳ lapse.
  final ValueListenable<List<ZSessionItem>> queue;

  /// Carte de devant — **la carte affichée ET notée**.
  ///
  /// En régime SRS c'est **toujours** `engine.current`. Pour les runtimes à
  /// file FIXE (linéaire, examen — aucune réinsertion), c'est l'item à l'index
  /// du swiper.
  final ValueListenable<ZSessionItem?> current;

  /// Compteurs de session.
  final ValueListenable<ZStudySessionProgress> progress;
}

/// Empreinte d'identité d'une file — l'ordre de ses `flashcardId`.
///
/// 🔴 Sert de `key` au sous-arbre de la pile (su-4 D1). Deux files de même
/// longueur mais d'ordre différent produisent deux empreintes différentes :
/// l'`Element` du swiper est remonté, et aucun index ne survit à la file qu'il
/// n'indexe plus. Une `key` constante — ou dérivée de la seule **longueur** —
/// rouvrirait le `RangeError`.
String zSessionQueueIdentity(List<ZSessionItem> queue) =>
    queue.map((ZSessionItem i) => i.flashcardId).join('|');
