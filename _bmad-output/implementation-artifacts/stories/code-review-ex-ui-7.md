# Code-review — EX-UI.7 (États de contenu + ZConfirmDialog)

- **Story** : `ex-ui-7-content-state-confirm-dialog` (statut `review`)
- **Reviewer** : agent BMAD adversarial (skill `bmad-code-review` invoqué avec succès)
- **Périmètre** : `packages/zcrud_ui_kit/` (pubspec, barrel, `lib/src/domain/{z_content_state,z_confirm_tone}.dart`, `lib/src/presentation/{z_state_widgets,z_confirm_dialog}.dart`, 5 fichiers de test)
- **Vérifs rejouées sur disque** :
  - `dart analyze packages/zcrud_ui_kit` → **No issues found!** (RC=0)
  - `flutter test packages/zcrud_ui_kit` → **28 tests PASS** (RC=0)
  - `python3 scripts/dev/graph_proof.py` → `zcrud_ui_kit -> zcrud_core`, **ACYCLIQUE OK**, **CORE OUT=0 OK**
  - grep couleurs codées en dur (`Color(0x`/`Colors.*`/`0xFF`) et primitives non directionnelles (`EdgeInsets.only`/`Alignment.center{Left,Right}`/`TextAlign.{left,right}`/`Positioned(`) → **NONE**
  - grep managers/routeur/dartz (`get`/`flutter_riverpod`/`provider`/`go_router`/`dartz`) dans `lib/` → **NONE** (uniquement mentions en commentaire pubspec)

## Couverture des AC

| AC | Verdict | Preuve |
|----|---------|--------|
| AC1 scaffolding | OK | pubspec `0.2.0`/`publish_to:none`/`resolution:workspace`, dep = `zcrud_core:^0.2.0`+flutter ; barrel exporte 4 fichiers |
| AC2 `ZContentState` (5, camelCase) | OK | `z_content_state_test.dart` (length==5, `.name`) |
| AC3 3 widgets const + a11y | OK (voir M1) | `z_state_widgets_test.dart` light+dark |
| AC4 aiguilleur switch exhaustif | OK | `switch` sans `default` sur 5 valeurs ; `z_content_state_view_test.dart` porteur |
| AC5 ZConfirmDialog/showZConfirmDialog | OK | `z_confirm_dialog_test.dart` (true/false/barrier→false, labels `MaterialLocalizations`) |
| AC6 `ZConfirmTone` enum | OK | destructive→`ColorScheme.error`, neutral→`primary` testés (porteur) |
| AC7 RTL/a11y | OK (voir M1/L1) | `z_rtl_a11y_test.dart` (RTL sans exception, ≥48dp, Semantics) |
| AC8 graphe/gates/no-op | OK | graph_proof ACYCLIQUE/CORE OUT=0 ; 0 `.g.dart` ; analyze RC=0 |

## Findings

### MEDIUM

**M1 — `ZLoadingState` sans message n'émet aucune annonce pour lecteur d'écran**
`z_state_widgets.dart:95-98` — `Semantics(liveRegion:true, label: message, ...)` : quand `message == null`, `label` est `null` et le `CircularProgressIndicator` n'a aucun `semanticsLabel`. Or le **repli par défaut** de l'aiguilleur est précisément `const ZLoadingState()` **sans message** (`z_state_widgets.dart:209`) — le chemin le plus courant. Un utilisateur de lecteur d'écran ne reçoit alors **aucune** annonce « chargement en cours », alors que D3/AC3 demandent un `Semantics(label:)` explicite et que WCAG 4.1.3 (status messages) l'attend.
- **Impact** : régression d'accessibilité silencieuse sur le cas d'usage par défaut.
- **Correction** : fournir un libellé de repli quand `message == null`, dérivé de la l10n injectée (ex. `ZcrudLocalizations`/`MaterialLocalizations`), ou a minima `CircularProgressIndicator(semanticsLabel: message)` complété d'un fallback non-null. Ajouter un test porteur (Semantics présent même sans message).

### LOW

**L1 — RTL « testé » = anti-crash uniquement, pas de vérif de bascule directionnelle**
`z_rtl_a11y_test.dart:15-37,52-73` : sous `Directionality.rtl` on n'assert que `takeException() == null` + Semantics + tailles. Aucune assertion ne prouve une bascule start/end (le code étant directionnellement propre — `EdgeInsetsDirectional`, `TextAlign.center` neutre — la garantie est structurelle, pas testée). Acceptable mais faible ; le grep « no left/right » est ici la vraie garde.

**L2 — `foregroundColor` du bouton destructive/neutral non couvert**
`z_confirm_dialog.dart:85-88` : `onError`/`onPrimary` dérivés mais seul `backgroundColor` est testé. Ajouter une assertion sur `foregroundColor` fiabiliserait le contraste.

**L3 — Absence de test porteur « ExcludeSemantics ne masque pas le CTA »**
`z_state_widgets.dart:251,288-295` : le CTA est bien hors de l'`ExcludeSemantics` (donc accessible), mais aucun test n'assert explicitement que le bouton conserve une sémantique cliquable après l'ajout de l'`ExcludeSemantics` (régression debug-log). Un test `find.bySemanticsLabel(actionLabel)` verrouillerait l'invariant.

## Axes adversariaux — synthèse

- Switch `ZContentStateView` **exhaustif sans `default`** sur les 5 valeurs, replis sûrs conformes (idle/empty/error→`SizedBox.shrink`, loading→`ZLoadingState`, success→builder) ; test **porteur** (un aiguillage inversé rougit — chaque slot testé isolément).
- Enums > booléens : `ZContentState`/`ZConfirmTone` — conforme NFR-U7.
- **Aucune** couleur codée en dur ; destructive→`ColorScheme.error` (dérivé) — vérifié.
- `showZConfirmDialog` : `true`/`false`/`?? false` (barrier), `Navigator.pop` typé, labels par défaut `MaterialLocalizations` — conforme.
- AD-2 : aucun gestionnaire d'état ; `StatelessWidget const` ; `showDialog`+`Navigator.pop`.
- Graphe : `zcrud_ui_kit → zcrud_core`, 1 sortante / 0 entrante, `CORE OUT=0` intact.

## Verdict

**APPROUVÉ avec réserve** — 0 HIGH, 1 MEDIUM (M1, à corriger dans le périmètre : annonce a11y du loading par défaut), 3 LOW (durcissement de tests). Story fonctionnellement complète, verte (analyze RC=0, 28 tests PASS, graphe conforme). Corriger M1 avant `done` ou justifier par écrit.
