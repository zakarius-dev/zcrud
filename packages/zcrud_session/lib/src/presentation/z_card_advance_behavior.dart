/// Comportement d'**avance** après soumission `ZCardAdvanceBehavior` +
/// **TABLE UNIQUE** des défauts par mode (Story SU-3, AC8 — FR-SU5).
///
/// 🔒 **ENUM, jamais un booléen** (convention du spine : « enums > booléens »).
///
/// 🔒 **TABLE UNIQUE, JAMAIS redécidée par un widget** (spine § Conventions :
/// « défauts de `ZCardAdvanceBehavior` **par mode** : table unique, jamais
/// redécidée par widget »). [zDefaultAdvanceBehavior] est **la** table : une
/// seconde décision, prise dans un `build()`, divergerait en silence du jour où
/// la table change — et deux surfaces de session se comporteraient différemment
/// dans le **même** mode.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Comportement d'avance à la carte suivante après soumission (2 valeurs).
enum ZCardAdvanceBehavior {
  /// **Auto-passage** après un délai court (défaut `200 ms`, parité IFFD F13),
  /// via le callback injecté `onAdvance`.
  ///
  /// Adapté aux modes **chronométrés** (test/examen blanc) : l'apprenant
  /// enchaîne, la correction détaillée est pour la fin.
  auto,

  /// **Aucun** auto-passage : l'utilisateur lit la correction, puis avance
  /// lui-même.
  ///
  /// Adapté aux modes d'**apprentissage/consultation**, où la correction est
  /// précisément ce qu'on vient lire — la faire disparaître après 200 ms
  /// retirerait l'essentiel de la valeur pédagogique.
  manual,
}

/// **TABLE UNIQUE** des défauts d'avance **par mode** (AC8).
///
/// 🔒 `switch` **EXHAUSTIF SANS `default`** sur les **6** `ZReviewMode` réels :
/// une 7ᵉ valeur d'enum doit casser la **compilation** ici — et non retomber
/// silencieusement sur `manual`, ce qui ferait perdre l'auto-passage à un futur
/// mode chronométré sans qu'aucun test ne rougisse.
///
/// - `test` / `whiteExam` ⇒ [ZCardAdvanceBehavior.auto] (modes chronométrés) ;
/// - `spaced` / `learn` / `list` / `cramming` ⇒ [ZCardAdvanceBehavior.manual].
///
/// Une valeur **explicite** passée par l'hôte **prime** sur ce défaut (le
/// paramètre est nullable côté widget : `advanceBehavior ??
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
