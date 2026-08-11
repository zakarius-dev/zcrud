/// TABLE UNIQUE `ZSessionModeKind` → `ZReviewMode`.
///
/// ## Pourquoi cette table existe
///
/// Sans elle, chaque application hôte réécrirait sa propre correspondance
/// choix-du-sélecteur → mode-de-session — et deux réécritures divergentes
/// enverraient le même geste utilisateur vers deux runtimes différents, sans
/// qu'aucun test ne le détecte.
///
/// ## Ce que cette table N'EST PAS
///
/// Elle **ne décide pas** du runtime. Le runtime est désigné par
/// `zSessionRuntimeForMode` (`zcrud_session`) — voie **unique**, jamais
/// redécidée ici. Cette table s'arrête **une couche plus haut** : elle
/// traduit le *choix du sélecteur* en *mode de session*, et laisse
/// `zSessionRuntimeForMode` faire le reste.
///
/// ```text
/// ZSessionModeKind  ──[zReviewModeForKind]──▶  ZReviewMode
///                                                  │
///                                    [zSessionRuntimeForMode]  (zcrud_session)
///                                                  ▼
///                                          ZSessionRuntimeKind
/// ```
///
/// ## Pourquoi `switch` exhaustif SANS `default`
///
/// Même patron que `zSessionRuntimeForMode` : une valeur supplémentaire de
/// [ZSessionModeKind] casse la **compilation** plutôt que de retomber
/// silencieusement dans le régime du voisin. Un `default` transformerait
/// l'ajout d'un membre en bug muet — il hériterait du mode d'à côté,
/// potentiellement un mode qui **écrit du SRS** (invariant AD-9 : la seule
/// voie d'écriture SRS est `reviewCard() → ZSrsScheduler.apply`), alors que
/// le nouveau membre n'en écrit peut-être aucun.
library;

import 'package:zcrud_session/zcrud_session.dart' show ZSessionModeKind;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Traduit le choix du sélecteur ([ZSessionModeKind]) en mode de session
/// ([ZReviewMode]) — **voie UNIQUE**, jamais dupliquée par un hôte.
///
/// | Choix du sélecteur | Mode | Runtime désigné (par `zSessionRuntimeForMode`) |
/// |---|---|---|
/// | `learnNew` — « Apprendre +N » | `ZReviewMode.learn` | `srsEngine` |
/// | `review` — « À réviser » | `ZReviewMode.spaced` | `srsEngine` |
/// | `test` — « Test » | `ZReviewMode.whiteExam` | `whiteExam` |
/// | `cramming` — « Bachotage » | `ZReviewMode.cramming` | `linear` (aucune écriture SRS) |
///
/// La correspondance de `cramming` reprend celle documentée sur
/// `ZSessionModeKind.cramming` : ce fichier n'invente aucune règle propre.
ZReviewMode zReviewModeForKind(ZSessionModeKind kind) => switch (kind) {
      ZSessionModeKind.learnNew => ZReviewMode.learn,
      ZSessionModeKind.review => ZReviewMode.spaced,
      ZSessionModeKind.test => ZReviewMode.whiteExam,
      ZSessionModeKind.cramming => ZReviewMode.cramming,
    };
