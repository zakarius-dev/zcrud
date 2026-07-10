# Code Review — Story EX-1 (scaffold app exemple Flutter + démo édition E3)

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` ; step-file architecture, `step-01-gather-context`). Workflow résolu via `_bmad/scripts/resolve_customization.py` (RC=0, aucun prepend/append).
- **Cible** : diff `example/` (répertoire non suivi, baseline `868438a`), statut story `review`.
- **Mode** : full (spec = `ex-1-scaffold-edition-demo.md`).
- **Vérifs rejouées sur disque** : `melos list` = **14** ✅ ; `graph_proof.py` ACYCLIQUE, **CORE OUT=0** ✅ ; `git status -- packages/` **vide** ✅ ; API `zcrud_core` inspectée (`ZEditionSubmitController`, `ZFieldListenableBuilder`, 3 binding scopes).

## Verdicts synthétiques

| Axe | Verdict | Preuve |
|-----|---------|--------|
| **Isolation prouvée** | **OUI** | `melos list`=14, graph_proof CORE OUT=0 inchangé, `packages/` git-clean, app hors `workspace:`/glob melos/graph_proof ; `dependency_overrides` path pur (aucune source hosted résiduelle). |
| **SM-1 réellement prouvé** | **OUI** | Le badge n'écoute que `controller.fieldListenable(name)` (tranche scellée, pas de listener global). Le test asserte `countOf('nickname')` **inchangé** après 100 frappes dans `fullName` → prouve à la fois l'absence de notify-de-tranche ET l'absence de rebuild du `ListView` de `DynamicEdition` (sinon l'item voisin serait reconstruit et son badge bumperait). Focus + `selection.baseOffset==100` conservés. `find.byType(Form) findsNothing`. Ce n'est PAS un simple proxy. |
| **Parité 4 bindings** | **PARTIELLE** | Les familles texte/nombre/etc. montent à l'identique sous les 4 wraps (test vert). MAIS les familles `file/image/document` sont **non fonctionnelles** sous get/riverpod/provider (le `ZcrudScope` interne du wrap ne re-propage pas le `filePicker` racine) → cf. MEDIUM-1. Le test de parité ne couvre que les champs texte, donc ne détecte pas l'écart. |

## Findings

| # | Sévérité | Fichier:ligne | Résumé |
|---|----------|---------------|--------|
| 1 | **MAJEUR** | `example/lib/demos/edition_demo_screen.dart:52-77` | `ZEditionSubmitController _submit` jamais `dispose()` — fuite du `ValueNotifier` à chaque switch de binding et au teardown. |
| 2 | **MEDIUM** | `example/lib/binding/binding_selector.dart:37-42` | Parité incomplète : `filePicker` racine masqué sous get/riverpod/provider → familles file/image/document mortes sous 3 des 4 bindings ; non couvert par le test de parité. |
| 3 | **LOW** | `example/lib/home_screen.dart:101` (+ `app.dart`, `reference_form.dart`) | Démo l10n creuse : toute la surface visible est en littéraux français codés en dur ; le toggle `fr↔en` ne change quasi rien de visible. |
| 4 | **LOW/nit** | `example/lib/support/rebuild_indicator.dart:47-50` | Le compteur SM-1 mesure le rebuild du **badge** (proxy co-localisé), pas du `ZFieldWidget` éditeur lui-même. Proxy sain mais implicite. |
| 5 | **LOW/nit** | `example/lib/home_screen.dart:85-94` | Le getter `_entries` réalloue la liste à chaque `build` (l'entrée « Édition » n'est pas `const` à cause de sa closure). |

---

### MAJEUR-1 — `ZEditionSubmitController` jamais libéré (fuite de `ValueNotifier`)

- **Fichier** : `example/lib/demos/edition_demo_screen.dart:52-77`
- **Preuve (vérifiée sur disque)** :
  - `_buildControllers()` (l.52) crée `_submit = ZEditionSubmitController(...)`. Il est appelé en `initState` (l.49) **et** à chaque `_changeBinding` (l.68).
  - `_changeBinding` (l.62-71) sauvegarde et dispose **uniquement** l'ancien `_controller` (`old.dispose()` l.70) — l'ancien `_submit` est écrasé sans être libéré.
  - `dispose()` de l'État (l.73-77) n'appelle **que** `_controller.dispose()` — `_submit.dispose()` absent.
  - `grep '_submit' example/lib/` → aucune occurrence de `_submit.dispose()`.
  - Contrat du cœur : `packages/zcrud_core/lib/src/presentation/edition/z_submission.dart:204-205` — `void dispose() => _state.dispose(); // À appeler par l'hôte au dispose.`
- **Impact** : chaque bascule de binding et chaque fermeture d'écran fuit le `ValueNotifier<ZSubmissionState>` interne. Non-crash, non détecté par les tests, mais **viole le contrat explicite de dispose** et la discipline AD-2 « controller stable (create/dispose) » — dans l'écran-vitrine même censé exemplifier le lifecycle correct.
- **Remède** : dans `_changeBinding`, capturer aussi l'ancien `_submit` et le `dispose()` après `setState` ; dans `State.dispose()`, appeler `_submit.dispose()` avant `super.dispose()`.

### MEDIUM-1 — Parité file/image/document rompue sous 3 des 4 bindings

- **Fichier** : `example/lib/binding/binding_selector.dart:37-42`
- **Preuve (vérifiée sur disque)** : `wrapWithBinding` enveloppe le child dans `ZcrudGetScope`/`ZcrudRiverpodScope`/`ZcrudProviderScope`. Chacun construit en interne un `ZcrudScope` **sans** transmettre de `filePicker` (`zcrud_get_scope.dart:133`, `zcrud_riverpod_scope.dart:84`, `zcrud_provider_scope.dart:86` — aucun `filePicker:` passé). La résolution `ZcrudScope.of` s'arrêtant au scope le plus proche, le `DemoFilePicker` racine est masqué → actions de picker désactivées. Le mode `scope` (défaut) conserve le picker. La note dev #210 le reconnaît, mais AC7 stipule « comportement identique dans les quatre ».
- **Impact** : la démonstration de parité — argument central de l'epic (AD-15) — est incomplète pour 3 familles de champs, et l'écart n'est **ni** signalé dans l'UI **ni** couvert par `binding_parity_test.dart` (qui n'assert que `ZTextFieldWidget`). Un évaluateur qui bascule sur GetX/Riverpod/provider et teste un champ fichier constate un comportement différent sans explication.
- **Remède** (in-scope EX-1, sans toucher `packages/`) : dans chaque branche de `wrapWithBinding`, réinjecter `ZcrudScope(filePicker: const DemoFilePicker(), child: child)` sous le wrap du manager ; OU étiqueter le caveat dans l'UI. Idéalement, ajouter au test de parité une assertion couvrant une famille fichier.

### LOW-1 — Démonstration l10n creuse

- **Fichier** : `example/lib/home_screen.dart:101` (`'zcrud — Démos'`), `app.dart` (dialogues/boutons), `reference_form.dart` (tous les `label:` en français).
- **Preuve** : toute la surface visible de l'app est en littéraux français ; `_toggleLocale` (app.dart:28) change la `Locale` mais seule la chaîne interne de `zcrud_core` (délégué `ZcrudLocalizationsDelegate`) bascule. Le test AC3 (`app_smoke_test.dart:45`) n'asserte que le tooltip `'Langue (en)'`, dérivé de `locale.languageCode` — pas une vraie traduction.
- **Impact** : le showcase l10n annoncé par AC3 est cosmétique côté surface de l'app. Justifiable pour une démo, mais faible.
- **Remède** : router quelques libellés via `AppLocalizations`/`ZcrudLabels`, ou documenter que le toggle ne pilote que la couche zcrud.

### LOW/nit-2, -3

- `rebuild_indicator.dart:47-50` : le badge est un proxy co-localisé fidèle (même `fieldBuilder` Column que `ZFieldWidget`), mais compte SES propres rebuilds. Envisager une assertion additionnelle sur le build de l'éditeur ou un commentaire explicite.
- `home_screen.dart:85-94` : `_entries` réalloue à chaque build ; impact négligeable.

## Conformité (points vérifiés OK)

- **AD-2** : `ZFormController` stable (create `initState` l.47 / `dispose` l.75) ; `ValueKey(field.name)` garanti par `DynamicEdition` (tests `find.byKey(ValueKey('fullName'))` verts) ; aucun `setState` à l'échelle du formulaire (les `setState` d'app pilotent thème/locale/RTL et le remontage de binding, pas la saisie) ; `ReferenceForm` pur-données `const` ; badge SM-1 granulaire (aucun listener global).
- **AD-13** : aucune variante non directionnelle — `grep` confirme uniquement `EdgeInsetsDirectional`/`TextAlign.start` ; `EdgeInsetsDirectional.only(bottom:)` OK (pas de left/right) ; toggle RTL via `Directionality(textDirection:)` réel (app.dart:68) ; `Semantics` sur le badge ; cibles Material ≥48 dp.
- **Thème** : `ZcrudTheme(gapM/gapL)` sans couleur (repli `Theme.of`) ; toutes les couleurs via `theme.colorScheme.*` (aucune couleur codée en dur dans un widget ; `colorSchemeSeed: Colors.indigo` est la config MaterialApp de l'app, licite).
- **Key Don'ts** : `ListView.builder` (home_screen.dart:120) ; pas de secret ; pas de `WidgetRef`/`Get.find`/`Provider.of` hors binding (`grep` vide) ; manager confiné au `wrap`.
- **Isolation / AC2 / AC9** : `melos list`=14, graph inchangé, `packages/` intouché, lock d'app propre, `dependency_overrides` path pur.
- **AC10** : `boundary_deps_test.dart` strippe les commentaires puis interdit les 6 packages de démo — robuste.

## Recommandation

- **Avant `done`** : corriger **MAJEUR-1** (dispose de `_submit`). Traiter **MEDIUM-1** dans le périmètre (réinjection du `filePicker` sous chaque wrap + assertion de parité fichier) ou le justifier par écrit. LOW optionnels.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sévérité | Statut | Détail |
|---|----------|--------|--------|
| 1 | MAJEUR | ✅ **corrigé** | `edition_demo_screen.dart` : `_submit.dispose()` ajouté dans `dispose()` ET au switch de binding (`oldSubmit.dispose()` avant `oldController.dispose()`). Contrat `z_submission.dart:205` respecté ; plus de fuite de `ValueNotifier`. |
| 2 | MEDIUM | ✅ **corrigé** | `binding_selector.dart` : `wrapWithBinding(..., {rootScope})` + `_BindingSeamForwarder` re-déclarent SOUS le scope du binding les seams racine (`filePicker`/`theme`/`labels`/`listRenderer`/`widgetRegistry`/`cloudStorage`) tout en conservant le `resolver`/`acl` injecté. `edition_demo_screen.dart` capte `ZcrudScope.maybeOf(context)` et le passe. Familles file/image/document désormais fonctionnelles sous get/riverpod/provider (bonus : thème/l10n aussi restaurés → atténue LOW-3). **Test ajouté** : `binding_parity_test.dart` sonde `ZcrudScope.of(context).filePicker == picker` sous les 4 voies. |
| 3 | LOW | 🟡 **consigné** | Démo l10n creuse : partiellement atténué (labels forwardés sous bindings). Enrichissement de surface reporté à EX-2/EX-3 (croissance de l'app). |
| 4 | LOW/nit | 🟡 **sans action** | Compteur SM-1 = proxy co-localisé sain (confirmé par le reviewer) ; aucune correction requise. |
| 5 | LOW/nit | 🟡 **consigné** | `_entries` réalloué par build (nit perf négligeable, écran d'accueil statique) ; reporté. |

**Vérif verte rejouée après remédiation** : `flutter analyze` RC=0 (No issues found), `flutter test` RC=0 — **18 tests** (14 + 4 nouveaux MEDIUM-1). `packages/` inchangé (git status vide) ; isolation intacte.

**Verdict final** : MAJEUR + MEDIUM corrigés et verrouillés par test ; LOW consignés. Story EX-1 → **done**.
