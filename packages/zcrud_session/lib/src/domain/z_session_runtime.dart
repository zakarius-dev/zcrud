/// TABLE UNIQUE `ZReviewMode` → runtime de session (SU-4, AC3 — AD-34).
///
/// **AUCUN moteur n'est créé ici.** Les **trois** runtimes EXISTENT déjà et
/// couvrent les **six** modes ; cette table ne fait que **désigner** lequel sert
/// quel mode. Elle est le pendant exact de `zDefaultAdvanceBehavior` (SU-3) :
/// *une table unique, jamais redécidée par un widget*.
///
/// 🔴 **Le régime d'écriture SRS est une propriété du TYPE, jamais du `mode`**
/// (AD-34). Cette table ne l'INSTAURE pas — elle s'y **conforme**. La garde
/// vit dans les constructeurs réels, et elle y est **déjà** :
///
/// | Mode | Runtime | Garde RÉELLE (sur disque) | Peut écrire du SRS ? |
/// |---|---|---|---|
/// | `spaced`, `learn` | `ZStudySessionEngine` | `assert(mode == spaced ‖ learn)` (SU-1) | **oui** — le SEUL à recevoir un `ZSessionReviewer` |
/// | `list`, `cramming` | `ZLinearSessionState` | `assert(mode == list ‖ cramming)` | non — **aucun paramètre** de reviewer |
/// | `test`, `whiteExam` | `ZWhiteExamSessionEngine` | *(aucune — preuve STRUCTURELLE)* | non — **ni `mode` ni reviewer** au ctor |
///
/// ⚠️ `ZWhiteExamSessionEngine` ne lève **aucun** `AssertionError` : il n'a pas
/// de paramètre `mode` à valider. Sa preuve est **structurelle** (aucun seam à
/// recevoir ⇒ aucun point d'appel SRS atteignable), pas assertive. Un test qui
/// attendrait un assert de sa part échouerait — et aurait raison.
///
/// 🚫 **Aucun `ZSessionReviewer` no-op n'est fourni** pour « adapter » un runtime
/// à un mode qu'il refuse : ce serait la **porte dérobée** qu'AD-34 interdit
/// nommément (un mode non-SRS servi par le moteur SRS sous couvert d'un reviewer
/// inerte).
///
/// Pur-Dart : aucun import Flutter (`test/z_purity_test.dart` le garde).
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Régime d'exécution d'un mode de session — **propriété du TYPE** (AD-34).
///
/// Désigne *lequel* des trois runtimes existants sert un mode. Ce n'est pas un
/// booléen « écrit du SRS ou non » : le régime d'écriture découle du type
/// désigné (seul [srsEngine] détient un seam d'écriture).
enum ZSessionRuntimeKind {
  /// `ZStudySessionEngine` — répétition espacée. **Seul** runtime à recevoir un
  /// `ZSessionReviewer` (voie d'écriture SRS unique, AD-33).
  srsEngine,

  /// `ZLinearSessionState` — parcours linéaire (avec re-boucle en cramming).
  /// **Aucun** seam SRS : l'absence d'écriture est structurelle (AD-23).
  linear,

  /// `ZWhiteExamSessionEngine` — examen blanc à scoring différé. **Aucun** seam
  /// SRS ; son ctor n'a même pas de paramètre `mode`.
  whiteExam,
}

/// Désigne le runtime qui sert [mode] — **TABLE UNIQUE de prod** (AD-34).
///
/// `switch` **exhaustif SANS `default`** : une 7ᵉ valeur de [ZReviewMode] casse
/// la **compilation** plutôt que de retomber silencieusement dans un régime
/// arbitraire. C'est délibéré — un `default` transformerait l'ajout d'un mode en
/// bug muet (le mode inconnu hériterait du régime du voisin, potentiellement
/// SRS).
///
/// La table est **confrontée aux constructeurs réels** par
/// `test/z_session_runtime_mapping_test.dart` : la relire ne prouverait rien
/// (elle se réciterait à elle-même) — le test construit, pour chaque mode, le
/// runtime que la table désigne, et prouve que les modes qu'elle n'y envoie pas
/// sont bien **refusés** par les asserts réels.
ZSessionRuntimeKind zSessionRuntimeForMode(ZReviewMode mode) => switch (mode) {
      ZReviewMode.spaced || ZReviewMode.learn => ZSessionRuntimeKind.srsEngine,
      ZReviewMode.list || ZReviewMode.cramming => ZSessionRuntimeKind.linear,
      ZReviewMode.test ||
      ZReviewMode.whiteExam =>
        ZSessionRuntimeKind.whiteExam,
    };
