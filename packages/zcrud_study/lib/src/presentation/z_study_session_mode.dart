/// **Lot 1 « étude »** — TABLE UNIQUE `ZSessionModeKind` → `ZReviewMode`,
/// **montée** de la démo vers le socle.
///
/// ## Pourquoi cette table monte ici
///
/// Elle n'existait que dans l'écran de démonstration
/// (`example/lib/demos/study_session_demo_screen.dart:35`, `zReviewModeForKind`)
/// — mesuré : `grep -rn "case ZSessionModeKind\."` sur `packages` + `example`
/// rendait **3 lignes, toutes dans ce seul fichier**. Chaque hôte réel (IFFD,
/// lex_douane) l'aurait donc **réécrite**, et deux réécritures divergentes
/// enverraient le même geste utilisateur vers deux runtimes différents — sans
/// qu'aucun test ne rougisse.
///
/// ## Ce que cette table N'EST PAS
///
/// 🚫 Elle **ne décide pas** du runtime. Le runtime est désigné par
/// `zSessionRuntimeForMode` (`zcrud_session`, AD-34) — voie **unique**, jamais
/// redécidée. La démo, elle, redécidait : son `_makeRuntime`
/// (`study_session_demo_screen.dart:212`) portait un second `switch` sur
/// `ZReviewMode`, parallèle à la table de `zcrud_session`. Cette table-ci
/// s'arrête **une couche plus haut** : elle traduit le *choix du sélecteur* en
/// *mode de session*, et laisse `zSessionRuntimeForMode` faire le reste.
///
/// ```text
/// ZSessionModeKind  ──[zReviewModeForKind]──▶  ZReviewMode
///                                                  │
///                                    [zSessionRuntimeForMode]  (zcrud_session)
///                                                  ▼
///                                          ZSessionRuntimeKind
/// ```
///
/// ## `cramming` — le membre qui manquait, **arrivé** (2026-08-06)
///
/// `ZLinearSessionState` sert **déjà** `list` **et** `cramming`
/// (`zSessionRuntimeForMode` : `list || cramming => linear`). Le mode était donc
/// entièrement exécutable : `ZStudySessionHost` l'accepte en entrée directe. Ce
/// qui manquait était le **point d'entrée par le sélecteur** — et il vient
/// d'être posé côté `zcrud_session` (`ZSessionModeKind.cramming`).
///
/// **Le `switch` sans `default` a fait EXACTEMENT son travail** : l'ajout du
/// membre n'a pas produit un bug muet (le mode voisin hérité en silence — et
/// `learn`/`spaced` **écrivent du SRS**, AD-33/AD-34), il a produit une **erreur
/// de compilation** qui a désigné le site à mettre à jour. C'est le coût
/// « quasi gratuit » annoncé plus haut, encaissé tel quel : **une** ligne.
///
/// La correspondance retenue est celle que porte la dartdoc du sélecteur
/// lui-même (`z_session_mode_selector.dart` : « sans aucune écriture SRS —
/// `ZReviewMode.cramming` → `ZLinearSessionState` ») : elle est **relevée**, pas
/// choisie ici.
///
/// ## Pourquoi `switch` exhaustif SANS `default`
///
/// Patron **exact** de `zSessionRuntimeForMode` : une 4ᵉ valeur de
/// [ZSessionModeKind] casse la **compilation** plutôt que de retomber
/// silencieusement dans le régime du voisin. Un `default` transformerait
/// l'ajout du membre `cramming` en bug muet — il hériterait du mode d'à côté,
/// potentiellement un mode **qui écrit du SRS** (AD-33/AD-34).
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
/// 🔒 Les correspondances sont celles de l'assemblage de référence
/// (`study_session_demo_screen.dart:36-43`), **relevées** et non réinventées ;
/// celle de `cramming` est relevée de la dartdoc de `ZSessionModeKind.cramming`.
ZReviewMode zReviewModeForKind(ZSessionModeKind kind) => switch (kind) {
      ZSessionModeKind.learnNew => ZReviewMode.learn,
      ZSessionModeKind.review => ZReviewMode.spaced,
      ZSessionModeKind.test => ZReviewMode.whiteExam,
      ZSessionModeKind.cramming => ZReviewMode.cramming,
    };
