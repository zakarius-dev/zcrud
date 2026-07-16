# Code-Review — EX-UI.8 : Port `ZToaster` + `enum ZToastSeverity` + `ZScaffoldMessengerToaster` + seam `ZToasterScope`

- **Story** : `ex-ui-8-toaster-port-severity.md` (7 ACs, statut `review`)
- **Reviewer** : agent adversarial BMAD (lecture seule)
- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (workflow step-file chargé). Revue conduite selon les axes adversariaux fournis ; aucune modification de code ni de sprint-status.
- **Périmètre** : `lib/src/domain/{z_toast_severity,z_toaster}.dart`, `lib/src/presentation/{z_scaffold_messenger_toaster,z_toaster_scope}.dart`, barrel, 5 tests.

## Verdict

**APPROVE avec 1 MEDIUM (couverture) recommandé.** 0 HIGH. Le port, l'impl par défaut et le seam sont conformes aux AD-32/AD-4/AD-6/AD-2/AD-13/AD-10 ; enums > booléens respecté ; couleur toujours dérivée du `ColorScheme` (aucun hex/`Colors.x`) ; switch exhaustif sans `default` ; substituabilité prouvée par `_FakeToaster` externe ; graphe inchangé (aucune dépendance ajoutée, `CORE OUT=0`).

## Vérification par axe adversarial

1. **AC1..AC7 satisfaits + testés** : AC1 (enum 4 valeurs camelCase, non sérialisé) ✓ testé. AC2 (`abstract interface class`, jamais `sealed`, défaut `info`, aucun `bool` multi-état) ✓. AC3 (ScaffoldMessenger, couleur dérivée, icône+texte) ✓ light+dark. AC4 (SnackBarAction ≥48dp, Semantics, RTL) ✓. AC5 (seam, défaut sûr, updateShouldNotify) ✓. AC6 (`_FakeToaster implements ZToaster` externe) ✓. AC7 (graphe/gates) ✓ vérifié (voir ci-dessous). **Lacune ciblée** : voir MEDIUM.
2. **Port non-`sealed`, substituable** : `abstract interface class ZToaster` ; `_FakeToaster implements ZToaster` défini hors du fichier du port, injecté via `ZToasterScope`, intercepte l'appel (SnackBar Flutter absente). Seam prouvé. ✓
3. **Mapping sévérité→couleur EXHAUSTIF** : `switch` sur 4 valeurs sans `default` (`z_scaffold_messenger_toaster.dart:96-115`) → ajout d'une valeur = erreur de compilation. `error → ZcrudTheme.of(context).errorColor ?? scheme.error` (idiome EX-UI.7 confirmé : `ZcrudTheme.fallback` pose `errorColor: scheme.error`). Autres → rôles M3 (`primary`/`tertiary`/`secondary` + `on*`). **Aucun** hex/`Colors.x` (grep NONE). Test porteur : `_expectedBackground` duplique indépendamment le mapping ⇒ casser un rôle en prod rougit. ✓ (réserve error : voir MEDIUM).
4. **Enums > booléens** : `ZToastSeverity` remplace `bool isError`/`String` libre ; aucun `bool` multi-état dans la signature. ✓
5. **ScaffoldMessenger, pas de manager** : `ScaffoldMessenger.of(context).showSnackBar` (`:85`), aucun `Get.showSnackbar`. `SnackBarAction` conditionnel (`actionLabel != null && onAction != null`), tap → callback testé (`z_toaster_action_test.dart:40-42`). ✓
6. **AD-13** : cible ≥48dp mesurée via `tester.getSize` du `TextButton` interne (`z_toaster_action_test.dart:60-61`) — indirecte mais verte (tap target Material `padded`). `Semantics(container, liveRegion, label)` + `ExcludeSemantics` visuel (anti-double-annonce). `TextAlign.start`, `Row` directionnel, aucun `EdgeInsets.only`/`centerLeft`. RTL testé (no exception + label sémantique). ✓
7. **Seam `ZToasterScope`** : `InheritedWidget` local, défaut `const ZScaffoldMessengerToaster()` (jamais de throw), `updateShouldNotify = oldWidget.toaster != toaster` testé ; `zToast` résout via `.of()` et délègue. ✓
8. **AD-2 aucun manager** : grep `get|flutter_riverpod|provider|toastification|go_router|dartz` sur `lib/` = NONE. ✓
9. **Graphe inchangé** : `pubspec.yaml` du package = `zcrud_core` + flutter uniquement (aucune dép ajoutée) ; arête unique sortante `→ zcrud_core`, `CORE OUT=0`, barrel ne ré-exporte pas `zcrud_core`. ✓
10. **Tests light ET dark porteurs** : boucle `ThemeData.light()` / `ThemeData.dark()` × 4 sévérités, assertion sur `data.colorScheme` ⇒ dark-mode-aware prouvé. ✓

## Findings

### MEDIUM
**M1 — Précédence `ZcrudTheme.errorColor` non couverte par un test.** `z_scaffold_messenger_toaster.dart:112-113` : `error → ZcrudTheme.of(context).errorColor ?? scheme.error`. Les tests ne montent jamais de `ZcrudScope`/extension `ZcrudTheme` avec un `errorColor` custom ≠ `scheme.error` ; `ZcrudTheme.fallback` fixant `errorColor = scheme.error`, tous les tests passent aussi bien avec la version complète qu'avec un simple `scheme.error`. **Impact** : supprimer le préfixe `ZcrudTheme.of(context).errorColor ??` NE rougit AUCUN test — la branche d'override (l'intérêt même de l'idiome) n'est pas porteuse. **Correction** : ajouter 1 test montant un `ZcrudScope`/`Theme` avec `ZcrudTheme(errorColor: <couleur distincte>)` et asserter que la `SnackBar.backgroundColor` en sévérité `error` prend cette couleur. Non bloquant (idiome identique au patron EX-UI.7 déjà éprouvé), mais recommandé dans le périmètre.

### LOW
- **L1** — Sévérité `error` : foreground figé à `scheme.onError` alors que le fond peut être un `ZcrudTheme.errorColor` custom ⇒ contraste on-color non garanti si l'app override `errorColor` sans cohérence avec `onError`. Documenté, acceptable ; à noter pour EX-UI.11.
- **L2** — Le défaut `severity = info` du helper `zToast` n'est pas asserté (le test « sans scope » vérifie seulement la présence d'une `SnackBar`, pas la sévérité). Trivial.
- **L3** — `duration ?? const Duration(seconds: 4)` non testé (ni durée fournie, ni défaut). Trivial.
- **L4** — Le test RTL vérifie l'absence d'exception + le label sémantique, mais pas le placement directionnel effectif (icône côté start). `Row` étant directionnel, risque faible.

## Conclusion
Aucun blocage. Les 7 ACs sont satisfaits et testés (light/dark, LTR/RTL, action, substitution). Recommandation : traiter **M1** (test de la précédence `ZcrudTheme.errorColor`) avant `done`, ou le justifier par écrit comme reporté (idiome hérité EX-UI.7 déjà couvert). Les LOW sont optionnels.
