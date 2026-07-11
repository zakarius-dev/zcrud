# Code Review — DP-1 : Layout & décoration de formulaire (B1 + B2 + M2)

- **Mode** : skill réel `bmad-code-review` invoqué (workflow step-file). Exécution autonome (subagent non-interactif) — checkpoints HALT du workflow contournés, méthode adversariale appliquée.
- **Périmètre** : `packages/zcrud_core` uniquement (fichiers DP-1). Les workstreams DP-3/7/8/11 en vol (autres packages) n'ont PAS été revus.
- **Date** : 2026-07-11
- **Statut story à la revue** : `review`

## Fichiers revus (périmètre DP-1)

- `lib/src/domain/edition/z_field_size.dart` (NEW)
- `lib/src/domain/edition/z_field_spec.dart` (UPDATE)
- `lib/domain.dart` / `lib/zcrud_core.dart` (barrels)
- `lib/src/presentation/theme/z_theme.dart` (UPDATE — tokens + fabrique)
- `lib/src/presentation/edition/z_large_field_card.dart` (NEW)
- `lib/src/presentation/edition/z_field_widget.dart` (UPDATE — dispatch large + bare)
- `lib/src/presentation/edition/families/z_text_field_widget.dart` (B2 + M2)
- `lib/src/presentation/edition/families/z_number_field_widget.dart` (M2)
- `lib/src/presentation/edition/families/z_select_field_widget.dart` (M2)
- `test/presentation/edition/dp1_layout_decoration_test.dart` (NEW) + `test/domain/edition/z_field_spec_test.dart`

## Vérif verte rejouée réellement (sur disque)

| Gate | Commande | Résultat réel |
|------|----------|---------------|
| Analyze | `dart analyze packages/zcrud_core` | **RC=0** — `No issues found!` |
| Tests | `flutter test packages/zcrud_core` | **RC=0 — 623 tests OK** (`All tests passed!`) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **CORE OUT=0 OK**, ACYCLIQUE OK |
| Pureté domaine | `dart test test/purity/domain_entrypoint_dart_test.dart` | **RC=0** (surface `domain.dart` Flutter-free) |
| Garde style | `flutter test test/purity/style_purity_test.dart` | **RC=0** (scan récursif `lib/src/presentation/**` → couvre les 2 NEW) |

Les 5 gates sont verts. Le compte 623 correspond au rapport dev-story.

## Analyse par axe adversarial

- **Additivité / rétro-compat** : ✅ CONFORME. Aucun symbole retiré/renommé. `ZFieldSpec.fieldSize` défaut `ZFieldSize.normal`, intégré ctor/`copyWith`/`==`/`hashCode` (les 4 endroits — vérifié l.50/116/132/151/169). `toString` inchangé. 16 tokens `ZcrudTheme` tous à défauts, intégrés ctor/`copyWith`/`lerp`. `fallback` (couleurs) inchangé, `radiusM`/`fieldPadding` NON mutés (décision Dev Notes respectée). Chemin `normal` : `z_field_widget.dart:253` — `if (large) {…} return reactive;` ⇒ retour inline strictement inchangé.
- **B1 rendu large** : ✅ CONFORME. `ZLargeFieldCard` = `Card(elevation:0)` + bordure rayon-token, `ConstrainedBox(minHeight token 64)`, `Padding` directionnel token, `Row` leading/suffix optionnels, `Column` label au-dessus + gap. 100 % tokens `large*`/`input*`, zéro couleur en dur (couleur bordure = `scheme.outline`, dérivée).
- **B2 minLines/maxLines** : ⚠️ lus réellement (`config?.minLines ?? repli`) — mais robustesse min>max non gardée (cf. MEDIUM-1). Garde password 1/1 OK ; `keyboardType` multiline dès `maxLines != 1` OK.
- **M2 fabrique inputDecoration** : ✅ couleurs DÉRIVÉES du `ColorScheme` (outline/primary/error/surfaceContainerHighest), jamais en dur. Override app consommé via `ZcrudTheme.of(context)` (test AC12 vert). Mode `bare` conforme.
- **AD-13 directionnel** : ✅ tous insets `EdgeInsetsDirectional`, `TextAlign.start`. Garde `style_purity` verte.
- **AD-2 / SM-1** : ✅ wrapper `large` STATIQUE en sortie de `build()`, hors du `ListenableBuilder`/`ZFieldListenableBuilder`. Frontière de rebuild inchangée. Controller/focus jamais recréés. Test char-par-char : focus conservé, Card montée 1×.
- **Surface `domain.dart` Flutter-free** : ✅ `ZFieldSize` pur-Dart `enum`, exporté par `domain.dart:44`. Gate purity entrypoint vert.
- **Barrels** : ✅ `z_field_size.dart` sur `domain.dart` ; `z_large_field_card.dart` sur `zcrud_core.dart`.

## Findings

### MEDIUM-1 — `minLines > maxLines` non gardé → assertion Flutter (crash au build)
**Fichier** : `lib/src/presentation/edition/families/z_text_field_widget.dart:78-79`
`effectiveMinLines`/`effectiveMaxLines` dérivent indépendamment de `config` et du repli type-dépendant, sans garantir `effectiveMinLines <= effectiveMaxLines`. `TextField` porte l'assertion `maxLines == null || maxLines >= minLines`.
**Scénario d'échec concret et plausible** : un champ `multiline` avec `ZTextConfig(maxLines: 2)` (sans `minLines`) ⇒ `effectiveMinLines = 3` (repli multiline) et `effectiveMaxLines = 2` ⇒ `3 > 2` ⇒ **AssertionError au build**, le formulaire crashe. Idem `ZTextConfig(minLines: 3, maxLines: 1)` sur un champ `text`. Contraste avec la garde défensive `password` (forcé 1/1) qui, elle, est présente — l'esprit AD-10 (une config atypique ne doit jamais casser le parent) n'est pas tenu ici.
**Reco** : après résolution, clamper — `if (effectiveMaxLines != null && effectiveMinLines > effectiveMaxLines) effectiveMinLines = effectiveMaxLines;` (ou `min(...)`). Ajouter un test `ZTextConfig(maxLines: 2)` sur `multiline`.

### MEDIUM-2 — a11y : double libellé en variante `large` (annonce redondante lecteur d'écran)
**Fichier** : `lib/src/presentation/edition/z_large_field_card.dart:56` + `80-82`
La Card enveloppe dans `Semantics(container: true, label: label)` ET rend un `Text(label)` visible enfant. Sans `explicitChildNodes`/`excludeSemantics`, le nœud conteneur (porte `label`) et le nœud `Text` (porte le même texte) coexistent ⇒ le lecteur d'écran annonce le libellé **deux fois**. AD-13 fait de l'a11y un invariant de premier ordre et l'AC3 insiste sur `Semantics`.
**Scénario** : navigation TalkBack/VoiceOver sur un champ `large` ⇒ « Grand … Grand ».
**Reco** : soit `excludeSemantics: true` sur le `Text(label)`, soit retirer le `label:` du `Semantics` conteneur et laisser le `Text` visible porter le libellé accessible (le champ interne étant `bare`, sans `labelText`, le `Text` reste la source sémantique du nom). Correctif trivial.

### LOW-1 — `bare` non honoré pour `radio`/`checkbox` en `large`
**Fichier** : `lib/src/presentation/edition/z_field_widget.dart:361-367` + `families/z_select_field_widget.dart:95-152`
En `large`, `bare: true` est transmis à `ZSelectFieldWidget` mais seul `_buildDropdown` le consomme. Pour `radio`/`checkbox`, le `Padding` de libellé interne (`EdgeInsetsDirectional.fromSTEB(16,8,16,0)`) est toujours rendu ⇒ libellé affiché deux fois (label Card + label interne) et champ non « bare ». Le périmètre AC4 vise les décor-portantes (dropdown) ; `radio`/`checkbox` en `large` reste un cas non testé.
**Reco** : masquer le libellé interne quand `bare == true`, ou documenter `radio`/`checkbox`+`large` comme non pris en charge (suivi M2-résiduel).

### LOW-2 — Libellé `large` retombe sur `field.name` brut si `label == null`
**Fichier** : `lib/src/presentation/edition/z_field_widget.dart:254-258`
`resolvedLabel = field.label ?? field.name` ⇒ un champ `large` sans `label` affiche la clé persistée snake_case (ex. `created_at`) en libellé proéminent. Cohérent avec les familles (même repli), donc pas une régression — mais plus visible en `large`.
**Reco** : acceptable (parité) ; à noter pour l'authoring (fournir un `label` sur les champs `large`).

### OBSERVATION (non-défaut) — M2 pilote désormais TOUTE décoration des champs `normal`
La fabrique `inputDecoration` impose bordure/`filled: true`/`fillColor: surfaceContainerHighest`/padding 16-16 à **tous** les champs text/number/select, y compris `normal`, remplaçant l'`InputDecorationTheme` de l'app consommatrice. C'est **voulu** par AC11/M2 (parité DODLP, surchargeable via `ZcrudScope.theme`/`ThemeExtension`). Signalé pour la migration DODLP : les apps s'appuyant sur leur propre `InputDecorationTheme` verront le rendu zcrud primer. Pas un défaut.

## Verdict

**Corrections requises (2 MEDIUM) avant `done`.**

- Les invariants structurels (additivité/rétro-compat, B1, M2 fabrique, AD-2/SM-1, AD-13, pureté domaine, barrels) sont **conformes** ; les 5 gates sont verts. Aucun finding HIGH/MAJEUR.
- **MEDIUM-1** (crash `minLines > maxLines`) : chemin de crash réel et facilement atteignable via un `ZTextConfig` valide — à corriger (clamp + test) ; c'est le finding le plus fort.
- **MEDIUM-2** (double libellé a11y) : correctif trivial ; à corriger ou justifier par écrit (règle CLAUDE.md : MEDIUM corrigé par défaut).
- LOW-1/LOW-2 : optionnels (corrigés si triviaux, sinon consignés en suivi M2-résiduel/M1).

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_core` RC=0, `flutter test packages/zcrud_core` **625 tests** (+2), graph CORE OUT=0, dart-test purity OK.

- **MEDIUM-1 (crash minLines>maxLines) — CORRIGÉ.** Clamp `effectiveMinLines <= maxLines` dans `z_text_field_widget.dart` (cas multiline + ZTextConfig(maxLines:2) sans minLines). **Test ajouté** : `takeException()==null` + minLines clampé.
- **MEDIUM-2 (double annonce a11y) — CORRIGÉ.** Le `Text` label visible de `ZLargeFieldCard` est enveloppé en `ExcludeSemantics` → label a11y porté une seule fois par le `Semantics` conteneur. **Test ajouté** : `bySemanticsLabel` findsOneWidget.
- **LOW-1 (bare non honoré pour radio/checkbox en large), LOW-2 (label fallback field.name) — CONSIGNÉS** → rattachés au lot **M2-résiduel / DP-12+** (harmonisation décor des familles restantes) ; hors périmètre B1/B2 strict.
- **OBSERVATION (fabrique pilote la décoration des champs normal, surchargeant l'InputDecorationTheme app)** : VOULU (AC11, parité DODLP, overridable via ZcrudScope) — pas un défaut.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert. Fondation core livrée → débloque les stories core sérialisées (DP-2/5/6/9/10).
