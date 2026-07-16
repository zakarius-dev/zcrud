# Code Review — EX-UI.9 : `ZDiscardChangesGuard`

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chargé OK). Revue conduite en mode adversarial, **lecture seule** (aucun code ni sprint-status modifié).
- **Story** : `_bmad-output/implementation-artifacts/stories/ex-ui-9-discard-changes-guard.md` (6 ACs).
- **Cible** :
  - `packages/zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart` (NEW)
  - `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (barrel, +1 export)
  - `packages/zcrud_ui_kit/test/z_discard_changes_guard_test.dart`
  - `packages/zcrud_ui_kit/test/z_discard_changes_guard_reactivity_test.dart`
- **Baseline** : verifs dev (analyze RC=0, 62 tests) non rejouées ici (revue statique adversariale).

---

## Verdict

**APPROUVÉ avec réserves mineures.** Les 6 ACs sont satisfaits et testés ; l'implémentation respecte AD-2/AD-15 (aucun manager, `StatelessWidget` pur), AD-32 (contact `zcrud_core` en lecture seule via `ValueListenable<bool>`), AD-6 (réutilise `showZConfirmDialog`, pas d'`AlertDialog` inline), AD-10 (`?? false` + garde `navigator.mounted`), NFR-U7 (`isDirty` seul `bool`). **0 HIGH, 1 MEDIUM, 2 LOW.**

---

## Findings

### MEDIUM-1 — Test SM-1 « child non reconstruit » non porteur (tautologique)
- **Fichier** : `test/z_discard_changes_guard_reactivity_test.dart:67-75`
- **Impact** : Le test prétend prouver l'objectif produit n°1 (rebuild granulaire, SM-1/AC5) via un compteur `childBuilds` inchangé au flip dirty. Or le `child` (`_CountingChild`) est **injecté une seule fois** par le `MaterialPageRoute` builder ; l'instance passée au `builder` du `ValueListenableBuilder` est **identique** à chaque rebuild. Flutter court-circuite `Element.updateChild` pour un widget identique (`identical(old,new)`) → `_CountingChild.build` n'est **jamais** rappelé, quelle que soit l'implémentation. Même une implémentation fautive qui ignorerait le paramètre `child` du builder (`builder: (c,d,_) => PopScope(child: this.child)`) ou envelopperait `child` dans un widget neuf à chaque flip laisserait `childBuilds` stable. Le compteur **ne peut structurellement jamais s'incrémenter** : il ne « rougit » sur aucune régression de la propriété SM-1 qu'il prétend garder.
- **Correction** : renforcer le porteur — p. ex. faire flipper le notifier **plusieurs fois** et asserter `childBuilds == 1` **tout en** vérifiant que le `PopScope`/`canPop` a bien changé (déjà fait via la re-sortie), OU vérifier l'identité de l'`Element` du child (préservé) vs un marqueur qui ne différerait que si le sous-arbre était reconstruit. À défaut, documenter explicitement que la non-reconstruction est garantie par l'injection (et non par le paramètre `child`), et déplacer l'assertion réellement porteuse sur « seul `PopScope`/`canPop` bascule » (la re-sortie directe sans dialog après flip, elle, est porteuse).
- **Note** : l'implémentation source (`z_discard_changes_guard.dart:96-108`) est **correcte** (child bien passé via le paramètre `child`). Le finding porte sur la **force du test**, pas sur un défaut de code.

### LOW-1 — Libellés par défaut `title`/`message` en anglais, non localisés
- **Fichier** : `z_discard_changes_guard.dart:64,67-68` (`defaultTitle = 'Discard changes?'`, `defaultMessage = 'You have unsaved changes. Discard them?'`)
- **Impact** : Les libellés de **boutons** retombent bien sur `MaterialLocalizations` (l10n), mais `title`/`message` par défaut sont des littéraux anglais figés. Une app francophone qui ne surcharge pas verra un titre/message anglais. Non-bloquant : chaînes **neutres/non-métier**, surchargeables (conforme à la décision D5, exception assumée par la story).
- **Correction** (optionnelle) : à terme, alimenter les replis via un seam l10n (`ZcrudLocalizations`) plutôt qu'un littéral anglais. Acceptable en l'état car documenté.

### LOW-2 — Ordre `onDiscard` PUIS `pop` non asserté par le test
- **Fichier** : `test/z_discard_changes_guard_test.dart:107-109`
- **Impact** : L'AC4 exige `onDiscard?.call()` **avant** `Navigator.pop`. Le test vérifie `discarded == 1` et `BODY` disparu, mais **pas l'ordre** relatif. L'ordre est garanti par la séquence du code (`z_discard_changes_guard.dart:130-131`), donc risque faible.
- **Correction** (optionnelle) : capturer dans `onDiscard` un booléen « la page est-elle encore montée ? » ou l'ordre d'un journal pour rendre l'invariant explicite.

---

## Axes adversariaux — synthèse

1. **ACs 1..6 satisfaits ET testés** : OUI. AC1 (import statique sans manager + `StatelessWidget`), AC2 (propre→pop direct), AC3 (dirty→intercept+`showZConfirmDialog`), AC4 (confirm/annuler/barrier), AC5 (flip + re-sortie directe ; compteur cf. MEDIUM-1), AC6 (RTL sans exception ; graphe/gates délégués orchestrateur).
2. **Contact `zcrud_core` lecture seule** : OUI. Source importe uniquement `foundation` (`ValueListenable`), `material`, et interne (`z_confirm_tone`, `z_confirm_dialog`). Aucun import `zcrud_core` (test l.146). `ValueListenable` sans setter ⇒ mutation impossible. `_updateDirty`/`markPristine`/`reset` du controller jamais appelés.
3. **PopScope** : `canPop:!dirty` (l.102). Propre→pop direct sans dialog (`didPop` short-circuit l.118). Dirty→`showZConfirmDialog(tone:destructive)` (l.121-128). Confirmer→`onDiscard` puis `navigator.pop` (l.130-131). Annuler/barrier→`?? false` interne ⇒ reste, `onDiscard` non appelé. Tests porteurs sur `canPop` (casser `canPop:true` ferait échouer le test AC3).
4. **SM-1 child param** : implémentation correcte ; **test non porteur** → MEDIUM-1.
5. **Réutilise `showZConfirmDialog`** : OUI (pas d'`AlertDialog` inline). Boutons `FilledButton 'OK'` / `TextButton 'Cancel'` cohérents avec `MaterialLocalizations` (`z_confirm_dialog.dart:66-91`).
6. **NFR-U7** : `isDirty` seul `bool`. `onDiscard=VoidCallback?`, labels `String?`, `tone` = enum. Conforme.
7. **AD-2 aucun manager** : aucun `flutter_riverpod`/`get`/`provider`. `StatelessWidget`. Conforme.
8. **AD-13 RTL/a11y** : test RTL sans exception ; a11y héritée du dialog ; aucun `EdgeInsets.only(left/right)`/`Alignment.centerLeft` (le garde n'a pas de layout propre).
9. **Graphe CORE OUT=0** : aucune arête ajoutée (source n'importe pas `zcrud_core`) ; barrel n'ajoute qu'un export interne. Cohérent avec la revendication ACYCLIQUE (non rejoué ici).
10. **Labels par défaut neutres** : `defaultTitle`/`defaultMessage` génériques non-métier, surchargeables (cf. LOW-1 pour la non-l10n).
