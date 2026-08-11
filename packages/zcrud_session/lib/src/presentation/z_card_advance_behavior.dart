/// Comportement d'avance après soumission (`ZCardAdvanceBehavior`) et table
/// unique des défauts par mode.
///
/// Un enum plutôt qu'un booléen : la sémantique du comportement reste
/// explicite à l'appel.
///
/// Table unique, jamais redécidée par un widget : [zDefaultAdvanceBehavior]
/// est la seule source du défaut par mode. Une seconde décision, prise dans
/// un `build()`, divergerait en silence du jour où la table change — et
/// deux surfaces de session se comporteraient différemment dans le même
/// mode.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Comportement d'avance à la carte suivante après soumission (2 valeurs).
enum ZCardAdvanceBehavior {
  /// Auto-passage après un délai court, via le callback injecté `onAdvance`.
  ///
  /// Adapté aux modes chronométrés (test/examen blanc) : l'apprenant
  /// enchaîne, la correction détaillée est pour la fin.
  auto,

  /// Aucun auto-passage : l'utilisateur lit la correction, puis avance
  /// lui-même.
  ///
  /// Adapté aux modes d'apprentissage/consultation, où la correction est
  /// précisément ce qu'on vient lire — la faire disparaître automatiquement
  /// retirerait l'essentiel de la valeur pédagogique.
  manual,
}

/// Table unique des défauts d'avance par mode.
///
/// `switch` exhaustif sans `default` sur les six `ZReviewMode` réels : une
/// septième valeur d'enum doit casser la compilation ici, plutôt que de
/// retomber silencieusement sur `manual`, ce qui ferait perdre l'auto-passage
/// à un futur mode chronométré sans qu'aucun test ne rougisse.
///
/// - `test` / `whiteExam` → [ZCardAdvanceBehavior.auto] (modes chronométrés) ;
/// - `spaced` / `learn` / `list` / `cramming` → [ZCardAdvanceBehavior.manual].
///
/// Une valeur explicite passée par l'hôte prime sur ce défaut (le paramètre
/// est nullable côté widget : `advanceBehavior ??
/// zDefaultAdvanceBehavior(mode)`).
ZCardAdvanceBehavior zDefaultAdvanceBehavior(ZReviewMode mode) =>
    switch (mode) {
      ZReviewMode.test => ZCardAdvanceBehavior.auto,
      ZReviewMode.whiteExam => ZCardAdvanceBehavior.auto,
      ZReviewMode.spaced => ZCardAdvanceBehavior.manual,
      ZReviewMode.learn => ZCardAdvanceBehavior.manual,
      ZReviewMode.list => ZCardAdvanceBehavior.manual,
      ZReviewMode.cramming => ZCardAdvanceBehavior.manual,
    };
