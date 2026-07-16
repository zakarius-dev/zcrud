# Code Review — EX-UI.10 : `ZAlphabetIndexBar` + transitions de route RTL-aware

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, workflow adversarial chargé — pas de fallback disque).
- **Date** : 2026-07-16
- **Reviewer** : agent adversarial (lecture seule, aucune modification code/sprint-status).
- **Baseline** : `709406d`
- **Cible** : `z_route_transition.dart` (domaine) + `z_alphabet_index_bar.dart` + `z_transitions.dart` (présentation) + barrel + 3 tests neufs.

## Vérifs rejouées réellement sur disque

| Vérif | Résultat |
|---|---|
| `dart analyze packages/zcrud_ui_kit` | **No issues found** (RC=0) |
| `flutter test` (3 fichiers EX-UI.10) | **23/23 verts** depuis la racine du repo |
| `flutter test packages/zcrud_ui_kit` (suite complète) | **84 verts / 1 ROUGE** (voir L-1, hors périmètre EX-UI.10) |
| `graph_proof.py` | **ACYCLIQUE OK / CORE OUT=0 OK** — seule arête `zcrud_ui_kit → zcrud_core`, inchangée |
| Grep patterns interdits (`EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, hex `0x`, `setState`, managers, `go_router`) dans le code | **AUCUN** (occurrences uniquement en prose dartdoc) |
| Barrel | 3 exports ajoutés aux bonnes places alpha, EX-UI.7/8/9 intacts, pas de ré-export `zcrud_core` |

## Couverture des ACs (adversarial)

- **AC1** ✅ 26 lettres A→Z + jeu injecté rendus ; `StatelessWidget const` ; scan d'imports (aucun manager/routeur). Porteur.
- **AC2** ✅ tap actif → `onLetter('M')` 1× ; tap inerte → non appelé ; `activeLetters==null` → toutes actives. Porteur.
- **AC3** ✅ `currentLetter:'C'` → `isSemantics(isSelected:true)` + `FontWeight.bold` (canal non-couleur) ; lettre non-courante en `normal`. Porteur.
- **AC4** ✅ `Semantics(button/enabled)` par lettre ; cible ≥ 48 dp en **largeur** ; RTL sans exception. (cf. L-2 sur la hauteur.)
- **AC5 (PIVOT)** ✅ `zSlideBeginOffset` **pure**, sans `BuildContext`, totale, jamais de throw ; `ltr==Offset(1,0)`, `rtl==Offset(-1,0)`, `ltr.dx == -rtl.dx`. **Test porteur confirmé** : supprimer l'inversion (`rtl?-1:1`) ferait rougir le cas RTL + le cas inversion + le widget-test en contexte. `fade` insensible à la direction vérifié.
- **AC6** ✅ `zPageRoute` → `PageRouteBuilder<T>` neutre ; `switch` exhaustif sans `default` ; enum `ZRouteTransition{slide,fade}` (pas de bool) ; scan code (hors dartdoc) sans `CustomTransitionPage`/`GoRouterState` ; `ZPageTransitionsBuilder` livré et enregistrable.
- **AC7** ✅ graphe inchangé, barrel clôturé, codegen non concerné (0 `@ZcrudModel`).

## Findings

### HIGH
Aucun.

### MEDIUM

**M-1 — Couverture : le chemin de tap de la configuration PAR DÉFAUT (`enableScrub: true`) n'est jamais asserté.**
`test/z_alphabet_index_bar_test.dart:66,81,93,129` — **les 4** tests de tap forcent `enableScrub: false`. Or le défaut du widget est `enableScrub = true` (`z_alphabet_index_bar.dart:46`), qui enveloppe la colonne dans un `_ZAlphabetScrubDetector` (`GestureDetector(onVerticalDrag*)`). Le comportement réellement livré aux appelants (scrub actif) n'a donc **aucune** assertion prouvant qu'un simple tap y émet toujours `onLetter` : une régression d'arbitrage de l'arène de gestes (drag vertical avalant le tap) passerait invisible.
*Impact* : le parcours d'interaction principal du composant tel qu'exposé par défaut est non couvert. *Correction* : ajouter un test tap avec `enableScrub` par défaut (true) asservissant `onLetter(lettre)` — et idéalement un test de scrub vertical émettant les lettres dé-dupliquées (T2.3 non couvert par un test dédié).

### LOW

**L-1 — (HORS PÉRIMÈTRE EX-UI.10) suite `flutter test packages/zcrud_ui_kit` ROUGE depuis la racine du repo.**
`test/z_discard_changes_guard_reactivity_test.dart:153-155` (fichier **EX-UI.9**, non suivi git, hors périmètre de cette story) lit `File('lib/src/presentation/z_discard_changes_guard.dart')` en **chemin relatif au cwd non robuste** → `PathNotFoundException` quand la suite est lancée depuis la racine (cwd = repo root). EX-UI.10 **n'a pas le droit** de toucher ce fichier (contrainte story) et ses propres tests utilisent, eux, le helper robuste `_readSource` (double base cwd) — EX-UI.10 est donc **propre**. Mais le DoD « `flutter test` verts » de la story est **techniquement faux depuis la racine** : à remonter à l'orchestrateur (le gate repo-wide le capterait). *Correction (autre story/dette EX-UI.9)* : aligner ce test sur le helper `_readSource` multi-cwd.

**L-2 — Cible tactile verticale d'une lettre < 48 dp pour le tap.**
`z_alphabet_index_bar.dart:172-181` — la cible ≥ 48 dp n'est garantie qu'en **largeur** (`ConstrainedBox(minWidth:48)`) ; la hauteur d'une lettre reste compacte (`fontSize:11`, `vertical:1`), soit ~13 dp. Pour un utilisateur qui **tape** (et non scrub), le point de contact vertical est < 48 dp (littéralement sous le minimum Material). Choix **documenté et assumé** par la story (D2 + Debug Log : 26×48 dp déborderait tout écran ; la zone de scrub ≥ 48 dp de large sert de cible continue). Conforme au périmètre validé — consigné comme dette a11y, non bloquant.

## Verdict

**APPROUVÉ avec réserve.** 0 HIGH. 1 MEDIUM (M-1, couverture du tap en config par défaut — corrigeable dans le périmètre par un test additionnel, sans toucher au code de prod). 2 LOW (L-1 hors périmètre à remonter ; L-2 dette a11y assumée). Le code EX-UI.10 respecte AD-1/AD-2/AD-13/AD-32, NFR-U2/U6/U7/U10/U11 ; la fonction pivot `zSlideBeginOffset` est pure et son test est porteur ; graphe et barrel intacts.
