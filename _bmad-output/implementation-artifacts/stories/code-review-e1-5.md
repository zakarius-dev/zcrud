# Code Review — Story E1-5 : Révocation clé Google Maps (AD-12)

- **Story** : `_bmad-output/implementation-artifacts/stories/e1-5-revocation-cle-google-maps.md`
- **Statut à la revue** : `review`
- **Périmètre revu** : **GROUPE A uniquement** (livrables disque : runbook, découplage, gates). Le **GROUPE B** (AC7/AC8/AC9 — action console Google Cloud + dépôts externes DODLP/DLCFTI) est **hors compétence** de cette revue technique (non exécutable/non vérifiable par un agent). Il n'est pas jugé comme un défaut du code.
- **Baseline** : `8f28755` (= HEAD)
- **Diff revu** : `docs/security/api-keys-injection-runbook.md` (créé), `packages/zcrud_geo/pubspec.yaml` (vérifié, non modifié par E1-5), story (sections permises).
- **Skill** : `bmad-code-review` (chemin pris : tool `Skill` → `bmad-code-review`, workflow step-file `.claude/skills/bmad-code-review/steps/`). Revue conduite en direct par le reviewer (diff petit et documentaire ; couches Blind Hunter / Edge Case Hunter / Acceptance Auditor appliquées manuellement).
- **Grounding** : `architecture.md#AD-12` (« Zéro secret dans les packages » ; interdits `badCertificateCallback => true`, endpoints en dur), `CLAUDE.md#Key Don'ts`.

---

## Verdict (GROUPE A) : ✅ APPROVED

Le groupe A est **intégralement satisfait et rejoué vert sur disque**. Zéro finding critique/majeur/medium. Deux nits LOW optionnels (durcissement doc), non bloquants.

> ⚠️ **La clôture `done` reste conditionnée à l'attestation Owner (GROUPE B).** Cette approbation porte exclusivement sur le groupe A (agent). Les AC 7/8/9 ne peuvent être cochés que par une attestation humaine explicite de l'Owner (Zakarius) — hors de la compétence de cette revue. Tant que cette attestation n'est pas fournie, E1-5 ne peut **pas** passer globalement à `done`, même groupe A vert.

---

## Triage par sévérité

| Sévérité | Nb | Statut |
|---|---|---|
| HIGH / MAJEUR | 0 | — |
| MEDIUM | 0 | — |
| LOW / nit | 2 | consignés (optionnels) |

**Aucun finding HIGH/MAJEUR ni MEDIUM.** Correction non requise avant clôture groupe A.

---

## Vérifications adversariales rejouées réellement (sur disque)

| Contrôle | Commande | Résultat |
|---|---|---|
| Zéro vraie clé (tout le dépôt) | `grep -rnE 'AIza[0-9A-Za-z_-]{35}' . --exclude-dir=.git` | **0 occurrence** (RC=1) ✅ |
| Zéro vraie clé (docs/) | `grep -rnE 'AIza[0-9A-Za-z_\-]{35}' docs/` | **0 occurrence** ✅ |
| Découplage Maps (packages) | `grep -rniE 'google_maps\|maps_flutter\|mapbox\|com.google.android.geo\|GMSApiKey' packages/` | **0 occurrence** ✅ |
| `zcrud_geo` deps | `packages/zcrud_geo/pubspec.yaml` | **`zcrud_core: ^0.0.1` seul** — aucun SDK Maps, aucune clé ✅ |
| Gate secrets | `dart run scripts/ci/gate_secret_scan.dart` | **exit 0** ✅ |
| Preuve fixtures | `dart run scripts/ci/prove_gates.dart` | **22 OK, 0 FAIL** (RC=0) ✅ |
| Vérif verte globale | `dart run melos run verify` | **RC=0** (graph ACYCLIQUE, core out=0, melos, reflectable, secrets, codegen, compat manifeste OK, workspace SKIP informationnel, serialization no-op vert) ✅ |
| Membres workspace | `dart run melos list` | **14** ✅ |
| Code généré committé | `git ls-files '*.g.dart'` | **0** ✅ |

**Non-régression confirmée** : `prove_gates.dart` inchangé (22 OK/0 FAIL), gate durci E1-3 intact, aucun `.g.dart` committé, graphe AD-1 acyclique.

---

## Couverture des Acceptance Criteria — GROUPE A

| AC | Vérifié | Preuve |
|---|---|---|
| **AC1** Runbook d'injection par config plateforme | ✅ | `docs/security/api-keys-injection-runbook.md` §1 : Dart `--dart-define(-from-file)`, Android `local.properties`/`manifestPlaceholders`→`${…}`, iOS `.xcconfig`/`Info.plist` par référence, Web substitution build/runtime, CI secrets pipeline. Règle « la clé n'est JAMAIS committée » explicite (§0). Placeholders uniquement. |
| **AC2** Check-list révocation/rotation Owner | ✅ | §4, étiquetée **« 🔴 HUMAN ACTION REQUIRED — Owner: Zakarius »**, 6 étapes console + critères d'attestation. |
| **AC3** Découplage `zcrud_geo` prouvé | ✅ | grep 0 (packages), `pubspec.yaml` = `zcrud_core` seul, renvoi impl E11a-1 noté (§6). |
| **AC4** `gate:secrets` vert + fixtures | ✅ | exit 0 ; `verify` RC=0 ; `prove_gates` 22/0. |
| **AC5** Interdit TLS `badCertificateCallback => true` rappelé | ✅ | §6 « banni et bloqué par le gate » + renvoi ; §0/tableau placeholders. Aucune occurrence *réelle* (affectation exécutable) dans zcrud. |
| **AC6** Aucune vraie clé introduite | ✅ | grep AIza+35 = 0 partout ; placeholders `YOUR_MAPS_API_KEY`/`$GOOGLE_MAPS_API_KEY`/`AIza<REDACTED>`/`__GOOGLE_MAPS_API_KEY__`. |

---

## Honnêteté du GROUPE B (contrôle anti-fausse-complétion) — ✅ CONFORME

Le code/doc **ne prétend nulle part** avoir réalisé la révocation :

- **Story** — AC7/AC8/AC9 explicitement `⏳ NON traité, hors ressort de l'agent` (Completion Notes, l.164-167) ; bannière « Passage à `done` BLOQUÉ par le groupe B ». Tasks T2/T5 notent la dépendance à l'attestation Owner, **non cochées** pour le groupe B. Statut story = `review` (jamais `done`).
- **Runbook §5** — tableau d'attestation : AC7/AC8/AC9 tous `⏳ En attente Owner` ; note « E1-5 ne peut pas passer globalement à `done` tant que non attesté ».
- **Runbook §4** — bannière `🔴 HUMAN ACTION REQUIRED`, mention explicite « ne sont pas exécutables par un agent ».

La check-list Owner est **actionnable** (étapes console numérotées, critères de confirmation clairs, interdiction de recopier la vraie clé même pour la preuve).

---

## Sûreté du runbook (contrôle « ne recommande rien d'interdit ») — ✅ CONFORME

- Aucune recommandation de committer une clé ; règle d'or « JAMAIS committée » (§0) répétée par plateforme.
- Porteurs de secrets prescrits gitignorés (`config/secrets.json`, `local.properties`, `*.xcconfig`, keystores) — §3.
- `badCertificateCallback => true` présenté **uniquement** comme interdit à bloquer (jamais recommandé).
- Restriction de clé (app + API) recommandée en défense en profondeur (§2), sans se substituer à la non-committance.
- **Risque de faux positif CI écarté** : le repli local `gate_secret_scan.dart` exclut la prose Markdown (`.md`/`.markdown`, cf. `_proseExtensions`) → le `badCertificateCallback = (...) => true` cité en §263 du runbook ne trip pas le gate (exit 0 confirmé). Côté gitleaks (`useDefault`), ce motif n'est pas une règle par défaut et les placeholders (`YOUR_MAPS_API_KEY`, low-entropy) ne matchent pas la règle GCP/generic-api-key → pas de blocage CI attendu.

---

## Findings LOW (optionnels — non bloquants)

### LOW-1 — Substitution Web sans garde-fou « placeholder résiduel »
- **Fichier** : `docs/security/api-keys-injection-runbook.md` §1.4 (l.135-147)
- **Constat** : le template committé `web/index.html` porte `key=__GOOGLE_MAPS_API_KEY__` ; si l'étape CI `sed` est oubliée/mal configurée, l'app **shippe le placeholder littéral** et Maps échoue silencieusement (pas de fuite — footgun de fiabilité, pas de sécurité).
- **Suggestion** (doc) : ajouter une assertion build-time « fail-fast si `__GOOGLE_MAPS_API_KEY__` subsiste dans `build/web/index.html` ». Non requis pour AC1.

### LOW-2 — `google-services.json` en gitignore recommandé
- **Fichier** : `docs/security/api-keys-injection-runbook.md` §3 (l.201)
- **Constat** : recommander de gitignorer `**/google-services.json` (« si contient des identifiants sensibles ») est défendable mais peut gêner les apps qui le committent légitimement avec une clé Firebase restreinte. Nuance déjà partiellement portée par « si contient… ».
- **Suggestion** (doc) : préciser « uniquement si non restreint / contient un secret serveur ». Cosmétique.

Les deux LOW sont des durcissements de documentation côté app consommatrice, sans impact sur la conformité AD-12 de **ce** dépôt ni sur les ACs du groupe A.

---

## Conformité aux invariants AD (échantillon pertinent)

- **AD-12** ✅ — zéro secret dans les 14 packages ; injection par config plateforme documentée ; interdit TLS rappelé et gaté.
- **AD-1** ✅ — `zcrud_geo` ne dépend que de `zcrud_core` ; graphe acyclique intact (`verify` OK).
- **CLAUDE.md Key Don'ts** ✅ — aucun secret en package ; aucun `badCertificateCallback => true` réel ; aucun endpoint sensible.

---

## Conclusion

**GROUPE A : APPROVED.** 0 HIGH, 0 MAJEUR, 0 MEDIUM, 2 LOW optionnels. Gates réellement verts (secrets exit 0, verify RC=0, prove_gates 22/0), découplage prouvé (grep clé=0, grep Maps=0, `zcrud_geo` = `zcrud_core` seul), aucune vraie clé, groupe B honnêtement non-coché.

**Transition recommandée** : le groupe A autorise le maintien en `review` sans correction obligatoire. Le passage à `done` demeure **bloqué** jusqu'à l'**attestation Owner (Zakarius)** des AC 7/8/9 (groupe B) — décision hors compétence de l'agent. La transition `sprint-status` reste du ressort de l'orchestrateur.
