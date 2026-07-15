# Code-review ES-6.2 — Migration tables markdown legacy + upgrade sticky-notes

- **Skill réel** : `bmad-code-review` (tool `Skill`, invoqué avec succès — pas de fallback disque).
- **Mode** : `full` (spec = fichier story) — Blind Hunter / Edge-Case Hunter / Acceptance Auditor exécutés inline par le reviewer (sous-agents non requis en contexte orchestré).
- **Baseline** : `f751d82` (frontmatter story). Périmètre revu = les 9 fichiers ES-6.2 nommés par l'orchestrateur.
- **Runner** : `flutter test` (R14 — `zcrud_note` ET `zcrud_markdown` sont Flutter depuis ES-6.1). RC capturés hors pipe (R15).

## Verdict : ✅ APPROUVÉ (aucun finding HIGH / MAJEUR / MEDIUM)

Implémentation conforme à la story. Le comblement `zcrud_markdown` (couture neutre `z_table_ops.dart`) est correctement isolé (aucun type Quill exporté, isolation `quill_signature_isolation_test` verte). Le migrateur `zcrud_note` est défensif (AD-10), préservant, idempotent, et le contrat table est **importé** (jamais dupliqué — SM-S4). Le retarget de pureté (domain strict / data neutre) mord au bon endroit. Graphe AD-1 intact (0 nouvelle arête, acyclique, CORE OUT=0), `melos list` = 20.

**Tous les tests load-bearing prouvés NON-POWERLESS** (rouge provoqué par neutralisation de la ligne de prod porteuse, restauration par édition ciblée R13 — aucune garde laissée neutralisée).

## Preuves R3 rejouées (injection → rouge → restauration → vert)

| # | AC / axe | Injection (ligne de prod neutralisée) | Résultat | Restauré |
|---|----------|----------------------------------------|----------|----------|
| R3#2 | **AC5 DÉFENSIF (LOAD-BEARING)** | `_tableSpanAt` : garde de régularité `sepCount != header.length` retirée | 🔴 ROUGE — cas header3/sep2 structuré (embed produit au lieu de texte préservé) | ✅ |
| R3#1 | **AC2 PRÉSERVATION** | `_tableSpanAt` : séparateur consommé comme donnée (`j=i+1`, `end=i`) | 🔴 ROUGE — les 2 tests AC2 (cells gagne `['---','---']`) | ✅ |
| R3#3 | **AC4 sticky verbatim** | `zMigrateStickyNote` : repli `[]` sur `String` au lieu de déléguer `normalizeNoteContentOps` | 🔴 ROUGE — les 2 tests AC4 (texte détruit) | ✅ |
| R3#4 | **AC7 no-dup SM-S4** | `const _rInjectDup = 'table'` (contrat dupliqué en dur dans le migrateur) | 🔴 ROUGE — scan `source_policy_test` › data | ✅ |
| R3#6 | **AC1/AC9 comblement** | `z_table_ops.dart` : `kTableEmbedType = 'tbl'` (diverge du contrat) | 🔴 ROUGE — AC1 structure/type | ✅ |

`grep -rn INJECT packages/*/lib` après restauration → **NO INJECTION MARKERS REMAIN**.

## Vérif verte rejouée réellement (RC hors pipe — R15)

- `flutter test` `zcrud_markdown` (FULL) → **RC=0**, `+277: All tests passed!` (E6-4 + isolation NON régressés + AC1/AC9).
- `flutter test` `zcrud_note` (FULL) → **RC=0**, `+162: All tests passed!` (AC2..AC8 + suites ES-6.1/ES-2 intactes).
- `python3 scripts/dev/graph_proof.py` → **RC=0** : `ACYCLIQUE OK`, `CORE OUT=0 OK`, `20 nœuds`.
- `dart run melos list | wc -l` → **20** (inchangé).
- `dart run melos exec --scope=zcrud_markdown --scope=zcrud_note -- dart analyze` → **RC=0** : `No issues found!` (les 2 packages).

## Axes adversariaux — conclusions

1. **Pouvoir discriminant (R12)** : vérifié sur les 5 injections ci-dessus. Aucun artefact menteur.
2. **Défensivité AD-10** : header/sep divergents, absence de séparateur, ligne jagged, entrées limites (`''`, `'|'`, `'|---|'`, `'||'`) → jamais de throw, jamais d'embed jagged, texte préservé. `zTableEmbedOp` padde toujours (op rectangulaire ⇒ jamais le placeholder d'erreur du builder).
3. **Préservation & ordre** : offsets `_emitTextWithTables` corrects sur table début/fin/adjacentes ; prose avant/après verbatim et dans l'ordre. Deux tables adjacentes SANS ligne séparatrice → une seule table (comportement conforme GFM), correctement séparées quand de la prose les isole.
4. **Idempotence** : `zMigrateNoteTables(once)` NO-OP profond (embed passe par la branche `else` verbatim ; texte re-scanné sans table). `zUpgradeLegacyNoteContent` idempotent sur sa propre sortie.
5. **Anti-dup SM-S4** : `kTableEmbedType`/clés = source unique dans `z_table_ops.dart` ; `z_table_embed.dart` et `z_rich_text_core.dart` re-câblés sur l'import ; aucun littéral `'table'`/`'rows'`/... dans le migrateur.
6. **Pureté re-target (D3)** : `domain/` strict, `data/` neutre (zcrud_markdown OK, Flutter/Quill direct interdit) — gardes verifiées mordantes.
7. **Isolation barrel** : barrel markdown exporte `z_table_ops.dart show zTableEmbedOp, kTableEmbedType` ; aucune sous-chaîne `z_table_embed`/`ZTableEmbed`/`ZTableEmbedBuilder` (case-sensitive : `zTableEmbedOp` ≠ `ZTableEmbed`). Isolation verte.

## Findings LOW (non bloquants — consignés)

- **LOW-1 — perte de whitespace de bloc de table (préservation edge).** `z_note_table_migration.dart` `_emitTextWithTables` : la prose « avant » est flushée jusqu'à `starts[span.start]` (début de la ligne d'en-tête). Si la 1re ligne d'un tableau est **indentée** (`'   | a | b |'`) ou porte un **CR** (CRLF), ces caractères d'espacement tombent dans la région `[tableStart, tableEnd]` remplacée par l'embed et sont **perdus**. Impact borné : seul du whitespace **insignifiant** de formatage de table est concerné (conforme GFM — indentation ≤3 espaces / CR ignorés) ; **aucun caractère de prose non-blanc n'est perdu** (le contenu des cellules survit, trimmé comme en GFM). Non couvert par un test. *Correctif optionnel si on veut la préservation stricte : inclure le whitespace de tête de la 1re ligne de table dans le flush de prose précédent. Recommandation : accepter tel quel (comportement GFM-cohérent, portée volontairement bornée D4/§PORTÉE).*

- **LOW-2 (nit) — `assert` redondant.** `z_note_table_migration.dart:116-119` : l'`assert((embed['insert']! as Map).containsKey(kTableEmbedType), …)` vérifie un invariant que `zTableEmbedOp` garantit déjà structurellement (couture D1). Filet décoratif (léger R6) ; sans effet en release. Optionnel à retirer.

## D10 (documentaire — déféré au code-review, autorisé par la story)

ES-6.2 **solde le volet « migration des tables » de FR-S25** (bloc BDD n°1 = table GFM `String`→structure sans perte ; bloc n°2 = sticky-note texte plat→Delta neutre via `normalizeNoteContentOps` ; bloc n°3 = écart `zcrud_markdown` comblé DANS `zcrud_markdown`, jamais dupliqué). **Rappel d'exclusion — DW-ES22-2** : le mapping de PERSISTANCE legacy IFFD (camelCase, `Timestamp`, `audioText`, `subjectId`/`creatorId`, `audioTextHash: int`) reste dû à l'**adapter `zcrud_firestore`** (ES-3.5 / ES-11.2 — AD-27), **jamais** dans le domaine ni ce migrateur, qui n'opère que sur des **ops neutres déjà normalisées**. **Aucune nouvelle dette `gate:web`** (D6 — les deux packages sont déjà Flutter).

**Recommandation de transition** : `review` → `done` après consignation des 2 LOW (aucune correction requise avant `done` — findings LOW optionnels).

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 | 🟡 LOW | 🟡 **CONSIGNÉ (non corrigé)** | Perte de whitespace de bloc de table (`_emitTextWithTables`) : indentation/CR (CRLF) en 1re ligne de table tombe dans la région remplacée par l'embed. **Bornée à du whitespace insignifiant** (conforme GFM) — **aucun caractère de prose non-blanc perdu**. Corriger imposerait de re-préserver un whitespace sémantiquement nul (sur-conception vs portée bornée D4). Consigné ; à revisiter si un corpus réel exhibe un CRLF signifiant. |
| LOW-2 | 🟡 LOW | 🟡 **CONSIGNÉ (non corrigé)** | `assert` (l.116-119) documentant le contrat cross-package de `zTableEmbedOp` (produit `kTableEmbedType`). **Non load-bearing** (l'invariant est garanti par la couture) → nit R6. Conservé comme **assertion de contrat cross-package** (garde-fou si la couture change) ; suppression sans bénéfice net. |
| D10 | — | ✅ **CONSIGNÉ** | Note de clôture documentaire ajoutée dans `architecture.md § Deferred` : volet « migration des tables » de FR-S25 **SOLDÉ** ; rappel d'exclusion **DW-ES22-2** (mapping persistance legacy IFFD → adapter `zcrud_firestore`, jamais dans ce migrateur). |

**Aucun HIGH/MAJEUR/MEDIUM** — aucune correction bloquante requise. Les 8 tests load-bearing prouvés non-powerless (code-review R3#1-6 + spot-check orchestrateur R18 sur AC5, jagged `['3','']` paddé → RC=1 → restauré RC=0).

**Vérif verte (RC hors pipe — R15)** : `flutter test` zcrud_markdown → RC=0/277 · zcrud_note → RC=0/162 · `graph_proof.py` → RC=0 (ACYCLIQUE + CORE OUT=0, 20 nœuds) · `melos list`=20 · analyze RC=0.

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; 2 LOW consignés avec justification ; D10 consignée.
