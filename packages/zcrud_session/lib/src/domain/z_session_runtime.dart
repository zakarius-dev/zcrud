/// Table unique associant chaque `ZReviewMode` à son runtime de session.
///
/// Aucun moteur n'est créé ici : les trois runtimes existent déjà et
/// couvrent à eux trois les six modes ; cette table ne fait que désigner
/// lequel sert quel mode — sur le même patron que le choix de comportement
/// d'avancement par défaut, une table unique jamais redécidée par un widget.
///
/// Le régime d'écriture SRS est une propriété du runtime, jamais du `mode`
/// pris isolément. Cette table ne l'instaure pas, elle s'y conforme : la
/// garde vit dans les constructeurs réels des trois runtimes.
///
/// | Mode | Runtime | Garde réelle (sur disque) | Peut écrire du SRS ? |
/// |---|---|---|---|
/// | `spaced`, `learn` | `ZStudySessionEngine` | `assert(mode == spaced ‖ learn)` | oui — seul runtime à recevoir un `ZSessionReviewer` |
/// | `list`, `cramming` | `ZLinearSessionState` | `assert(mode == list ‖ cramming)` | non — aucun paramètre de reviewer |
/// | `test`, `whiteExam` | `ZWhiteExamSessionEngine` | aucune : preuve structurelle | non — ni `mode` ni reviewer au constructeur |
///
/// `ZWhiteExamSessionEngine` ne lève aucun `AssertionError` : il n'a pas de
/// paramètre `mode` à valider. Sa preuve est structurelle (aucun seam à
/// recevoir, donc aucun point d'appel SRS atteignable), pas assertive.
///
/// Aucun `ZSessionReviewer` no-op n'est fourni pour « adapter » un runtime à
/// un mode qu'il refuse : ce serait la porte dérobée qu'interdit
/// précisément cette table (un mode non-SRS servi par le moteur SRS sous
/// couvert d'un reviewer inerte).
///
/// Pur-Dart : aucun import Flutter.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Régime d'exécution d'un mode de session — propriété du runtime désigné.
///
/// Désigne lequel des trois runtimes existants sert un mode. Ce n'est pas un
/// booléen « écrit du SRS ou non » : le régime d'écriture découle du type
/// désigné (seul [srsEngine] détient un seam d'écriture).
enum ZSessionRuntimeKind {
  /// `ZStudySessionEngine` — répétition espacée. Seul runtime à recevoir un
  /// `ZSessionReviewer` (voie d'écriture SRS unique, invariant AD-9).
  srsEngine,

  /// `ZLinearSessionState` — parcours linéaire (avec re-boucle en cramming).
  /// Aucun seam SRS : l'absence d'écriture est structurelle.
  linear,

  /// `ZWhiteExamSessionEngine` — examen blanc à scoring différé. Aucun seam
  /// SRS ; son constructeur n'a même pas de paramètre `mode`.
  whiteExam,
}

/// Désigne le runtime qui sert [mode] — table unique de production.
///
/// `switch` exhaustif sans `default` : une septième valeur de [ZReviewMode]
/// casse la compilation plutôt que de retomber silencieusement dans un
/// régime arbitraire. C'est délibéré — un `default` transformerait l'ajout
/// d'un mode en bug muet (le mode inconnu hériterait du régime du voisin,
/// potentiellement SRS).
///
/// La table est confrontée aux constructeurs réels par une garde dédiée :
/// la relire ne prouverait rien (elle se réciterait à elle-même) — la garde
/// construit, pour chaque mode, le runtime que la table désigne, et prouve
/// que les modes qu'elle n'y envoie pas sont bien refusés par les asserts
/// réels.
ZSessionRuntimeKind zSessionRuntimeForMode(ZReviewMode mode) => switch (mode) {
      ZReviewMode.spaced || ZReviewMode.learn => ZSessionRuntimeKind.srsEngine,
      ZReviewMode.list || ZReviewMode.cramming => ZSessionRuntimeKind.linear,
      ZReviewMode.test ||
      ZReviewMode.whiteExam =>
        ZSessionRuntimeKind.whiteExam,
    };
