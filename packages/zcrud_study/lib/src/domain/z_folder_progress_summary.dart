/// Agrégat de progression d'un dossier d'étude — **valeur pure**, calculée
/// une fois par l'hôte, jamais recalculée au rendu.
///
/// Le calcul ne redéfinit **aucune** règle de partition : il délègue à
/// `zCategorize` (`zcrud_flashcard`), la seule fonction du dépôt qui décide
/// ce qu'est une carte « jamais apprise » et une carte « due ». Ce fichier
/// n'en ajoute qu'une lecture de comptes.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZRepetitionInfo, ZSessionCategories, zCategorize,
        zIndexSrsById;

/// Comptes de progression d'un dossier, déjà agrégés.
///
/// Value object immuable : il transporte des entiers déjà calculés et n'a
/// aucune dépendance à l'horloge, au thème ou à un flux. Deux instances aux
/// mêmes comptes sont égales ([operator ==]/[hashCode]), ce qui permet à un
/// widget de le comparer sans recalculer quoi que ce soit.
///
/// Invariant de partition : `learned + toReview + toLearn == total`.
@immutable
class ZFolderProgressSummary {
  /// Construit un agrégat déjà calculé.
  ///
  /// Préférer [zSummarizeFolderProgress] : ce constructeur n'impose aucune
  /// cohérence entre les comptes (il sert aussi à figer un agrégat reçu d'un
  /// backend).
  const ZFolderProgressSummary({
    required this.learned,
    required this.toReview,
    required this.toLearn,
    required this.total,
    required this.ratio,
  });

  /// Agrégat d'un dossier vide — tous les comptes à zéro, [ratio] `0`.
  static const ZFolderProgressSummary empty = ZFolderProgressSummary(
    learned: 0,
    toReview: 0,
    toLearn: 0,
    total: 0,
    ratio: 0,
  );

  /// Cartes apprises et **non dues** à l'instant de référence.
  final int learned;

  /// Cartes apprises dont l'échéance est atteinte (« à réviser »).
  final int toReview;

  /// Cartes jamais apprises (« à apprendre »).
  final int toLearn;

  /// Nombre total de cartes du dossier.
  final int total;

  /// Fraction apprise, **clampée** dans `[0, 1]` (`0` si [total] vaut `0` —
  /// jamais de division par zéro).
  final double ratio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFolderProgressSummary &&
          learned == other.learned &&
          toReview == other.toReview &&
          toLearn == other.toLearn &&
          total == other.total &&
          ratio == other.ratio;

  @override
  int get hashCode => Object.hash(learned, toReview, toLearn, total, ratio);

  @override
  String toString() =>
      'ZFolderProgressSummary(learned: $learned, toReview: $toReview, '
      'toLearn: $toLearn, total: $total, ratio: $ratio)';
}

/// Agrège la progression de [cards] au regard de [repetitionInfos] — fonction
/// **pure** : aucune E/S, aucune horloge implicite, mêmes entrées ⇒ même
/// valeur.
///
/// - [now] : instant de référence, **paramètre obligatoire** (`DateTime.now()`
///   est interdit ici) ;
/// - une carte sans état SRS, ou dont `repetitions == 0`, compte dans
///   [ZFolderProgressSummary.toLearn] ;
/// - une carte apprise dont l'échéance est atteinte compte dans
///   [ZFolderProgressSummary.toReview] ;
/// - toutes les autres comptent dans [ZFolderProgressSummary.learned], y
///   compris une carte apprise sans échéance (elle l'a été, et rien ne la
///   réclame).
///
/// ## Règles de partition : une seule source
///
/// Les trois seaux sont dérivés de `zCategorize` — `toLearn` est
/// `neverLearned.length`, `toReview` est `due.length`, et `learned` est le
/// **reste** (`total - toLearn - toReview`). Aucune condition sur
/// `repetitions` ou `nextReviewDate` n'est réécrite ici : réécrire ces
/// conditions créerait une seconde définition de « apprise », qui divergerait
/// silencieusement de celle du sélecteur de session.
///
/// Il n'y a volontairement **aucun paramètre de configuration SRS** : la
/// partition déléguée n'en prend pas. En introduire un ici obligerait à
/// recalculer les seaux autrement — exactement la seconde formule que ce
/// contrat exclut.
///
/// ## Coût
///
/// Linéaire : les états SRS sont indexés **une fois** par `zIndexSrsById`,
/// puis consultés en O(1) par carte. Cette fonction est faite pour être
/// appelée quand les données changent, pas à chaque `build` — le widget qui
/// l'affiche consomme la valeur, il ne l'appelle jamais.
ZFolderProgressSummary zSummarizeFolderProgress(
  Iterable<ZFlashcard> cards,
  Iterable<ZRepetitionInfo> repetitionInfos, {
  required DateTime now,
}) {
  final List<ZFlashcard> materialized =
      cards is List<ZFlashcard> ? cards : cards.toList(growable: false);
  final int total = materialized.length;
  if (total == 0) return ZFolderProgressSummary.empty;

  // Délégation stricte : la partition est celle du domaine flashcard.
  final ZSessionCategories categories = zCategorize(
    materialized,
    srsById: zIndexSrsById(repetitionInfos),
    at: now,
  );

  final int toLearn = categories.neverLearned.length;
  final int toReview = categories.due.length;
  // `learned` est le RESTE, jamais une troisième condition recalculée.
  final int learned = total - toLearn - toReview;
  final double ratio = (learned / total).clamp(0.0, 1.0).toDouble();

  return ZFolderProgressSummary(
    learned: learned,
    toReview: toReview,
    toLearn: toLearn,
    total: total,
    ratio: ratio,
  );
}
