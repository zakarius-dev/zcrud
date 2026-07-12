# Code-review adversarial (groupé) — MIN-1 + MIN-2

**Skill** : `bmad-code-review` (VRAI skill invoqué ; mode subagent unique — reviewer full-model, pas de fan-out de sous-agents).
**Date** : 2026-07-12.
**Périmètre** : diff `HEAD` sur `packages/zcrud_core` (MIN-2) + `packages/zcrud_markdown` (MIN-1), soit 23 fichiers (+1215 / −143). Stories `stories/min-1-markdown-mineurs.md`, `stories/min-2-core-mineurs.md`.
**Portée** : review-only — aucune correction, aucun commit, sprint-status NON touché.

---

## Vérifications REJOUÉES sur disque (RC réels)

| Commande | RC | Résultat |
|---|---|---|
| `dart analyze packages/zcrud_core packages/zcrud_markdown` | **0** | No issues found! |
| `flutter test packages/zcrud_core` | **0** | **884 tests** passés |
| `flutter test packages/zcrud_markdown` | **0** | **269 tests** passés |
| `flutter test packages/zcrud_mindmap` (consommateur) | **0** | **110 tests** passés |
| `python3 scripts/dev/graph_proof.py` | **0** | ACYCLIQUE OK · **CORE OUT=0 OK** |
| `dart test packages/zcrud_core/test/purity/domain_entrypoint_dart_test.dart` | **0** | domaine pur-Dart OK (AD-14) |

Aucune divergence entre les RC déclarés dans les stories et les RC rejoués.

---

## Zones à risque — audit adversarial (résultats)

1. **Slider défaut 1→100 (MIN-2)** — VÉRIFIÉ SÛR. Seul consommateur = `ZSliderFieldWidget`, qui construit `const ZSliderConfig()` par défaut et **clampe** `value.clamp(min, max)` + garde `max > min`. Aucun test/consommateur core ne dépend du `0..1`. Le test `min2_config_time_test.dart` asserte `0..100` par défaut ET le respect des bornes explicites. Changement documenté + note de migration. → informational (LOW-4).
2. **text→multiline (MIN-2)** — VÉRIFIÉ SÛR. `configWantsMultiline` exige `!isPassword && minLines>1` ; n'affecte QUE le défaut de `maxLines`. `text` nu ⇒ 1/1 inchangé ; `password` forcé 1/1 par garde en aval ; `maxLines` explicite respecté.
3. **date clear / select reset (MIN-2)** — VÉRIFIÉ. Croix/reset conditionnés `!isRequired && !readOnly && hasValue` au dispatcher ET au widget ; croix hors nœud `excludeSemantics` (pas de double-annonce) ; ≥48 dp. SM-1 non régressé (widgets structurels, hors voie de frappe). Gap mineur documenté ci-dessous (LOW-1).
4. **souligné `<u>` round-trip (MIN-1)** — VÉRIFIÉ. `_kUnderlineAttr='underline'` = clé Quill réelle. Machine à états défensive, court-circuit si aucun marqueur, embeds préservés, autres attributs conservés. `ZDeltaCodec` inchangé. Sentinel `<u>` littéral = limite documentée assumée (parité DODLP, AD-10). 6 tests round-trip verts.
5. **latexBlock additif (MIN-1)** — VÉRIFIÉ. `latex` inline (`MathStyle.text`) INCHANGÉ ; `latexBlock` = type d'embed strictement additif ; rendu partagé `_buildmath` défensif (`onErrorFallback` + placeholder) ; `_latexEmbedAtSelection` gère les deux, comptage d'index Delta correct.
6. **menus tableau (MIN-1)** — VÉRIFIÉ. `dispose()` itère `_cells` à la fermeture ; `_deleteRowAt`/`_deleteColumnAt` disposent immédiatement et retirent de `_cells` (pas de double-dispose) ; bornes `_kMinDim`/`_kMaxDim` respectées, item « supprimer » désactivé au minimum.
7. **styles Quill thémés (MIN-1)** — VÉRIFIÉ. `zQuillThemedStyles` dérive H1..H6 du `TextTheme`, zéro couleur en dur (FR-26) ; mémoïsé en `didChangeDependencies` côté éditeur (hors chemin chaud). `DefaultStyles` reste interne (jamais dans le barrel).
8. **seams neutres (MIN-2)** — VÉRIFIÉ. `ZTimeCodec` pur-Dart Flutter-free (aucun `TimeOfDay`/Material — purity test vert), défensif (hors-bornes ⇒ `null`). `ZSectionCollapseStore` abstrait + impl mémoire ; impl disque déférée au binding (AD-1). Chargement/persistance défensifs (try/catch ⇒ repli défauts).
9. **isolation markdown (MIN-1)** — VÉRIFIÉ. Le barrel `zcrud_markdown.dart` n'exporte NI `z_latex_embed`, NI `z_rich_text_core`, NI `z_table_embed` : `ZLatexInput`, `ZLatexBlockEmbed`, `kZEmbedBuilders`, `zQuillThemedStyles` restent internes à `lib/src/`. Aucun type Quill/math dans la surface publique. DP-3/DP-4/DP-22 intacts.
10. **rétro-compat additive + SM-1 + CORE OUT=0** — VÉRIFIÉ. Tous les nouveaux paramètres optionnels avec défauts rétro-compat ; aucun symbole public supprimé/renommé ; graph_proof CORE OUT=0.

---

## Findings

### MIN-1 (`zcrud_markdown`)

| # | Sévérité | Fichier:ligne | Description | Remédiation |
|---|---|---|---|---|
| LOW-M1 | LOW | `z_markdown_field.dart:454-476` (`_enforceCharacterLimit`) | La troncature « souple » supprime l'excédent **en fin de document** (juste avant le `\n` terminal) et repositionne le caret à `deleteAt`, quel que soit l'endroit où l'utilisateur saisit. Sur un document déjà au-delà de la limite, taller au milieu retire des caractères de la queue et déplace la sélection — surprenant. Best-effort documenté, non-fatal. | Acceptable en l'état (opt-in, documenté « souple »). Amélioration possible : tronquer à la position de saisie ou seulement bloquer l'insertion excédentaire. À consigner, pas bloquant. |
| LOW-M2 | LOW | `z_markdown_field.dart:442-449 / 460-462` | `_plainTextLength` compte les embeds comme 1 caractère (object-replacement) et `deleteAt` est calculé sur `document.length` : en présence d'embeds, la borne peut légèrement diverger du décompte texte réel. Best-effort documenté. | Acceptable (cas marginal). Consigner. |

*Limite `<u>` littéral (codec) : explicitement assumée/documentée (parité sentinel DODLP, AD-10) — non comptée comme finding.*

### MIN-2 (`zcrud_core`)

| # | Sévérité | Fichier:ligne | Description | Remédiation |
|---|---|---|---|---|
| LOW-C1 | LOW | `z_field_widget.dart:487-489` + `z_select_field_widget.dart:132-146` | `onCleared` est fourni à `ZSelectFieldWidget` pour tout select/radio **mono non requis éditable**, mais `_withReset` n'est appliqué que dans `_buildDropdown` et `_buildModalMono`. Un **`radio` inline** (`radioAsModal=false`) reçoit `onCleared` mais **ne rend jamais** de bouton reset ⇒ pas de remise à `null` possible pour un radio inline. AC4 « reset mono » n'est couvert que pour dropdown/modal. | Non-régression (comportement radio inline inchangé). Soit câbler `_withReset` autour de `_buildRadios`, soit restreindre la doc de l'AC4 aux familles dropdown/modal. LOW. |
| LOW-C2 | LOW (informational) | `z_field_config.dart:47` | Changement de défaut `ZSliderConfig.max` `1→100`. **Aucune régression code** (widget clampe, aucun consommateur/test core ne dépend du `0..1`, vérifié). Impact = **données** : une valeur persistée contre le `0..1` implicite s'affichera à une position relative différente. Documenté + note de migration (`ZSliderConfig(max: 1)`). | Accepté/documenté. Aucune action code requise ; signaler aux apps consommatrices (DODLP) lors de l'intégration. |

Aucun finding HIGH / MAJEUR / MEDIUM. Aucune violation AD-1/AD-2/AD-3/AD-10/AD-13/AD-14, FR-26, ni SM-1 détectée.

---

## Verdicts

- **MIN-1 (`zcrud_markdown`)** : **APPROVED** — 2 findings LOW (best-effort documentés), vérifs vertes, isolation AD-1/AD-7 confirmée, rétro-compat DP-3/DP-4/DP-22.
- **MIN-2 (`zcrud_core`)** : **APPROVED** — 2 findings LOW (1 gap d'AC mineur radio inline, 1 changement de défaut documenté), vérifs vertes, CORE OUT=0, purity AD-14 OK, additivité stricte.

Les LOW sont optionnels (CLAUDE.md) : corrigeables si triviaux (LOW-C1 = ~5 lignes), sinon consignés. Aucun blocage vers `done`.

**Rapport** : `_bmad-output/implementation-artifacts/stories/code-review-mineurs.md`
