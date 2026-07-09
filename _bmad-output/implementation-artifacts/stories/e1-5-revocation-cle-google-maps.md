---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 1.5 : 🔴 Révocation de la clé Google Maps fuitée (immédiat, AD-12)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **responsable sécurité du programme zcrud (Owner : Zakarius)**,
je veux que **la clé Google Maps commitée en clair dans les dépôts DODLP et DLCFTI soit neutralisée (révoquée/restreinte) et que zcrud garantisse par conception qu'aucune clé/secret ne réintroduise ce risque — procédure d'injection par config plateforme documentée, découplage confirmé de `zcrud_geo`**,
afin que **la fuite historique soit close avant tout autre travail d'implémentation, et que les futurs champs géo (E11a) consomment la clé via la config plateforme de l'app, jamais via un package.**

## Contexte & valeur (sécurité)

Cette story est le **traitement immédiat du secret fuité** qui fonde l'épic E1 (« workspace melos opérationnel, gates CI, et **traitement immédiat du secret fuité** ») et matérialise **AD-12** (*« Zéro secret dans les packages »*). L'inventaire technique a établi qu'une **clé Google Maps est aujourd'hui commitée en clair** dans les dépôts applicatifs **DODLP** et **DLCFTI** (moteurs `data_crud` dupliqués dont zcrud est l'extraction).

Le risque est **exogène à ce dépôt** : la clé vit dans DODLP/DLCFTI (dépôts externes) et sa révocation s'opère dans la **console Google Cloud**. zcrud ne peut ni exécuter ni vérifier cette révocation par un agent. Ce que zcrud **peut et doit** garantir : (1) qu'aucune clé n'entre jamais dans un de ses 14 packages (prouvé par `gate:secrets`, durci en E1-3) ; (2) que la **procédure d'injection sécurisée par config plateforme** est documentée pour que les apps consommatrices fournissent la clé sans la committer ; (3) que le futur package `zcrud_geo` est **découplé** de toute clé (l'impl réelle est déférée en E11a/E11b — aujourd'hui squelette).

**Valeur :** clore la fuite (action Owner) + prévenir par conception toute réintroduction dans zcrud + fournir le runbook d'injection/rotation que consommeront E11a (`zcrud_geo`), E7 (intégration DODLP) et E11a-3 (retrait de tout `badCertificateCallback => true`).

> ⚠️ **Séparation critique des responsabilités.** Cette story a **deux natures d'AC** (voir §Acceptance Criteria) :
> - **Groupe A — vérifiable sur disque / automatisable** : réalisable et vérifiable par `dev-story` dans ce dépôt (runbook, découplage, gate vert).
> - **Groupe B — ACTION HUMAINE (Owner: Zakarius)** : révocation/restriction effective dans la console Google Cloud + preuve que l'ancienne clé est invalide. **Aucun agent ne peut cocher le groupe B.** Le passage global de la story à `done` reste **conditionné à une attestation humaine** de l'Owner (voir §Condition de clôture).

## État réel en place (hérité, à ne PAS régresser)

Vérifié sur disque au `baseline_commit` :

- **E1-1..E1-4 = DONE.** Workspace melos (14 membres pur-Dart, `resolution: workspace`, lockfile racine unique), barrels + `src/`, graphe AD-1 acyclique, analysis_options partagé, CI GitHub Actions (`codegen → analyze → test → gates`), gate de compat (E1-4).
- **`gate:secrets` opérationnel et durci (E1-3)** : `scripts/ci/gate_secret_scan.dart` — repli local reproductible de gitleaks, motifs `AIza…` (clé Google), `AKIA…` (AWS), PEM, **`badCertificateCallback = (...) => true`** (formes d'affectation réelles, H-1), token Slack. Périmètre M-2 : **tous les fichiers texte** (pas de filtre d'extension), la prose Markdown restant hors périmètre du repli local (contre-exemples documentés) mais **couverte par gitleaks en CI**. Auto-exclusion du script lui-même, `.git`, code généré, caches, `scripts/ci/fixtures/**`.
- **Preuve par fixture** : `scripts/ci/prove_gates.dart` construit une clé `AIza…` factice **par concaténation** (jamais un littéral secret) et une affectation `badCertificateCallback` réelle, puis vérifie que le gate **échoue** dessus (exit≠0) et **passe** sur l'arbre propre. Invocation : `dart run melos run gate:secrets` (ou via `melos run verify` qui enchaîne les 6 gates).
- **`zcrud_geo` = squelette** : `packages/zcrud_geo/lib/zcrud_geo.dart` (barrel) → `src/domain/z_geo_api.dart` = `abstract final class ZGeoApi` placeholder (version `0.0.1`, référence `ZCoreApi.version` pour rendre l'arête AD-1 tangible). `pubspec.yaml` : seule dépendance = `zcrud_core: ^0.0.1`. **Aucune clé, aucune dépendance à un SDK Maps, aucun `AIza…`** dans le package. L'impl réelle du champ géo est **déférée en E11a-1** (« aucune clé API dans le package, config plateforme, dépend de E1-5 »).
- **zcrud propre** : `grep` sur `packages/`+`scripts/` (hors `gate_secret_scan.dart` et fixtures `prove_gates.dart`) → **aucune** occurrence de `AIza`/`GOOGLE_MAPS`/`badCertificateCallback` réelle. La fuite n'est **pas** dans zcrud ; elle est dans DODLP/DLCFTI (externes).
- `docs/` contient `technical-inventory.md`, `canonical-schema.md`. **Pas encore** de dossier `docs/security/` ni de runbook d'injection.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **Runbook d'injection sécurisée par config plateforme** (nouveau doc, ex. `docs/security/api-keys-injection-runbook.md`) : où et comment l'app fournit la clé Maps (et tout secret) **sans jamais la committer** — voir §Runbook ci-dessous.
- ✅ **Check-list de révocation/rotation à destination de l'Owner** (dans le runbook ou un doc annexe) : étapes console Google Cloud + critère d'attestation.
- ✅ **Confirmation formelle du découplage** : preuve automatisée que `zcrud_geo` (et le reste de zcrud) ne contient **aucune clé ni dépendance à une clé** ; que l'injection est le seul mécanisme prévu (documenté).
- 🚫 **Hors périmètre** : l'implémentation réelle du champ géo / adaptateur Google/OSM (→ **E11a-1**, MVP parité) et le reste géo (→ **E11b**). Le retrait de tout `badCertificateCallback => true` côté export (→ **E11a-3**) — ici on garantit seulement que le **gate** le bloque.
- 🚫 **Hors dépôt (non exécutable par un agent)** : la révocation effective dans la console, la modification des dépôts DODLP/DLCFTI. Ces actions sont **documentées** (check-list) et **attestées** par l'Owner, pas réalisées ici.
- 🚫 **Ne JAMAIS écrire une vraie clé** dans un quelconque fichier de ce dépôt (doc, test, fixture) — utiliser des placeholders (`AIza<REDACTED>`, `$GOOGLE_MAPS_API_KEY`) ou une concaténation factice comme le fait déjà `prove_gates.dart`.

## Runbook d'injection sécurisée (spécification du doc à produire — groupe A)

Le doc doit couvrir, **par plateforme**, comment l'app consommatrice fournit la clé Maps **à l'exécution / au build**, la clé restant **hors du contrôle de version** :

- **Dart / build-time** : `--dart-define=GOOGLE_MAPS_API_KEY=…` ou, recommandé, `--dart-define-from-file=config/secrets.json` (fichier **gitignoré**). Accès in-app via `String.fromEnvironment('GOOGLE_MAPS_API_KEY')`. Jamais de littéral dans le code.
- **Android** : clé placée dans `local.properties` (**gitignoré**, jamais committé) ou une variable d'env CI, propagée au manifeste via `manifestPlaceholders`/`resValue` Gradle ; référencée dans `AndroidManifest.xml` par placeholder (`${GOOGLE_MAPS_API_KEY}`), jamais en dur.
- **iOS** : clé injectée via un `.xcconfig` (**gitignoré**) ou variable d'env CI, exposée dans `Info.plist` par référence de build setting ; jamais de littéral committé.
- **Web** : clé injectée au build (template `index.html` + substitution CI) ou via config runtime servie par le backend ; jamais committée dans le repo statique.
- **CI/CD** : la clé vit **exclusivement** dans les **secrets du pipeline** (GitHub Actions secrets / variables protégées), injectée au build par `--dart-define(-from-file)` ou variable d'env ; **jamais** dans un fichier suivi.
- **Restriction de la clé** (défense en profondeur, à faire côté console — renvoi au groupe B) : restreindre par application (empreinte SHA-1 Android, bundle id iOS, referer HTTP web) **et** par API (Maps SDK uniquement). Une clé restreinte limite l'impact d'une fuite résiduelle.
- **`.gitignore`** : confirmer que les porteurs de secrets (`*.env`, `config/secrets.json`, `local.properties`, `*.xcconfig` de secrets) sont ignorés — s'appuyer sur l'existant (`.env*` déjà ignoré) et **documenter** les ajouts recommandés côté app (ce dépôt n'héberge pas ces fichiers, mais le runbook les prescrit aux apps).

## Procédure de révocation / rotation (à EXÉCUTER par l'Owner — groupe B)

Check-list console Google Cloud (documentée par `dev-story`, **exécutée par Zakarius**) :

1. Identifier la clé fuitée dans **Google Cloud Console → APIs & Services → Credentials** du projet Maps de DODLP/DLCFTI.
2. **Révoquer** (supprimer) l'ancienne clé **ou** la **restreindre** drastiquement (application + API) si une rotation transparente est préférée.
3. **Créer une nouvelle clé restreinte** (par app + par API) et l'injecter via la config plateforme (cf. Runbook) — **jamais committée**.
4. **Purger** la clé des dépôts DODLP/DLCFTI (retrait du fichier suivi ; idéalement réécriture d'historique / invalidation puisque l'ancienne clé est révoquée).
5. **Vérifier que l'ancienne clé est invalide** : un appel Maps avec l'ancienne clé retourne une erreur d'autorisation (`REQUEST_DENIED` / clé invalide).
6. **Attester** la complétion (voir §Condition de clôture).

## Acceptance Criteria

### Groupe A — Vérifiables sur disque / automatisables (réalisables par `dev-story`)

1. **Runbook d'injection documenté.** Un document (ex. `docs/security/api-keys-injection-runbook.md`) décrit la procédure d'injection de la clé Maps par **config plateforme** pour Dart (`--dart-define` / `--dart-define-from-file`), Android (`local.properties`/Gradle placeholders), iOS (`.xcconfig`/`Info.plist`), Web et CI (secrets pipeline) — avec la règle explicite **« la clé n'est JAMAIS committée »**. Aucune vraie clé n'y figure (placeholders uniquement).
2. **Check-list de révocation/rotation Owner.** Le doc contient la procédure console Google Cloud (révoquer/restreindre → nouvelle clé restreinte → purge dépôts → vérif invalidité → attestation), **clairement étiquetée « HUMAN ACTION REQUIRED — Owner: Zakarius »**.
3. **Découplage `zcrud_geo` confirmé (automatisé).** Preuve reproductible qu'aucune clé ni dépendance à une clé n'existe dans `zcrud_geo` ni ailleurs dans zcrud : `grep` ciblé (`AIza`, `GOOGLE_MAPS`, SDK Maps) sur `packages/zcrud_geo/**` et `packages/**` → **zéro occurrence réelle** (hors doc/fixtures) ; `packages/zcrud_geo/pubspec.yaml` ne dépend d'**aucun** SDK Maps.
4. **`gate:secrets` vert sur l'arbre propre.** `dart run melos run gate:secrets` (et `melos run verify`) → **exit 0** au `baseline_commit` et après cette story ; le gate **échoue** toujours sur les fixtures (`prove_gates.dart` : `AIza…` factice + affectation `badCertificateCallback`) — non-régression du gate durci en E1-3.
5. **Interdiction TLS toujours barrée.** Le runbook rappelle l'interdit AD-12 `badCertificateCallback => true` et renvoie au gate qui le bloque ; aucune occurrence réelle dans zcrud (hors fixtures/doc).
6. **Aucune vraie clé introduite.** La story n'ajoute aucun secret réel au dépôt (placeholders / concaténation factice uniquement) ; `gate:secrets` reste vert (recouvre l'AC 4).

### Groupe B — ACTION HUMAINE REQUISE (Owner: Zakarius) — non cochable par un agent

7. **HUMAN ACTION REQUIRED — Révocation/restriction effective.** L'ancienne clé Google Maps fuitée dans DODLP/DLCFTI est **révoquée ou restreinte** dans la console Google Cloud. *Critère de confirmation :* l'Owner atteste la révocation/restriction (date + projet + moyen).
8. **HUMAN ACTION REQUIRED — Preuve d'invalidité.** Un appel Maps utilisant l'**ancienne clé** échoue (autorisation refusée / clé invalide). *Critère de confirmation :* l'Owner joint/atteste la preuve (capture ou statut `REQUEST_DENIED`), sans jamais recopier la vraie clé dans ce dépôt.
9. **HUMAN ACTION REQUIRED — Purge des dépôts externes.** La clé est retirée des fichiers suivis de DODLP/DLCFTI (et l'historique traité selon la politique retenue). *Critère de confirmation :* attestation Owner que les dépôts externes ne portent plus la clé active.

## Condition de clôture (`done`)

- Le **groupe A** est intégralement satisfait et **rejoué vert sur disque** (`gate:secrets` exit 0 + grep découplage) → conditionne le passage `review → done` côté agent.
- Le **groupe B** ne peut être clôturé que par une **attestation humaine explicite de l'Owner (Zakarius)**. Tant que cette attestation n'est pas fournie, la story **ne peut pas** passer globalement à `done` : elle reste bloquée sur l'action humaine, même si tout le code/doc du groupe A est vert. `dev-story`/`code-review` **n'ont pas autorité** pour cocher les AC 7–9.

## Tasks / Subtasks

- [x] **T1. Rédiger le runbook d'injection sécurisée** (AC : #1, #5) — `docs/security/api-keys-injection-runbook.md`
  - [x] Sections par plateforme (Dart/Android/iOS/Web/CI) avec exemples à placeholders, règle « jamais committée »
  - [x] Rappel interdit AD-12 `badCertificateCallback => true` + renvoi au `gate:secrets`
  - [x] Prescription `.gitignore` côté app (porteurs de secrets)
- [x] **T2. Documenter la check-list de révocation/rotation Owner** (AC : #2) — _documentation seule ; AC #7/#8/#9 (groupe B) restent en attente d'attestation Owner, non cochés_
  - [x] Étapes console Google Cloud, étiquette « HUMAN ACTION REQUIRED — Owner: Zakarius »
  - [x] Critères d'attestation (révocation, invalidité, purge) — sans jamais exiger la vraie clé dans le dépôt
- [x] **T3. Confirmer et prouver le découplage `zcrud_geo`** (AC : #3)
  - [x] `grep` ciblé sur `packages/zcrud_geo/**` et `packages/**` → zéro clé/SDK Maps réel
  - [x] Vérifier `packages/zcrud_geo/pubspec.yaml` : aucune dépendance à un SDK Maps ; noter le renvoi à E11a-1 pour l'impl (config plateforme)
- [x] **T4. Rejouer la vérif verte** (AC : #4, #6)
  - [x] `dart run melos run gate:secrets` → exit 0 ; `melos run verify` → gates verts
  - [x] Confirmer que `prove_gates.dart` fait toujours échouer le gate sur fixtures (non-régression : 22 OK / 0 FAIL)
  - [x] `melos run analyze` RC=0 ; `melos run test` : aucun dossier test/ (story documentaire, non-régression)
- [x] **T5. Consigner la dépendance à l'attestation Owner** (AC : #7, #8, #9 — documentation de la dépendance seulement)
  - [x] Notes de complétion : groupe A vert sur disque ; groupe B en attente d'attestation humaine → `done` global bloqué tant que l'Owner n'a pas attesté

## Dev Notes

- **AD-12 (contrat)** : *aucune clé API ni secret n'entre dans un package zcrud ; les clés (Maps, endpoints) sont fournies par la config plateforme de l'app. Interdits : `badCertificateCallback => true`, endpoints en dur non surchargeables.* Cette story est le point d'ancrage du contrat pour toute la suite géo (E11a/E11b) et l'intégration DODLP (E7).
- **Nature documentaire + preuve.** L'essentiel du groupe A est **doc + vérification automatisée** ; aucun code applicatif n'est produit (l'impl géo est E11a-1). Ne pas déborder sur `zcrud_geo` au-delà d'une confirmation de découplage.
- **Renvois amont/aval** : E1-3 a posé/durci `gate:secrets` (motifs, périmètre M-2, preuve par fixture) — **s'appuyer dessus, ne pas le réécrire**. E11a-1 dépend explicitement de E1-5 (« aucune clé API dans le package, config plateforme »). E11a-3 retirera tout `badCertificateCallback => true` côté export.
- **Placeholders obligatoires** : suivre le pattern `prove_gates.dart` (clé factice par concaténation) si un exemple ressemblant à une clé est nécessaire ; sinon `$GOOGLE_MAPS_API_KEY` / `AIza<REDACTED>`. **Ne jamais** faire échouer `gate:secrets` avec un faux positif dans le runbook — la prose Markdown est hors périmètre du repli local mais couverte par gitleaks en CI : préférer des formes non déclenchantes (placeholders explicites, pas de séquence `AIza` suivie de 35 caractères réels).

### Project Structure Notes

- Nouveau dossier **`docs/security/`** (n'existe pas encore ; `docs/` ne contient que `technical-inventory.md` et `canonical-schema.md`). Aligné avec l'usage `docs/` du projet (source of truth documentaire, cf. CLAUDE.md).
- **Aucune** modification des 14 packages, du `melos.yaml`, du `pubspec.yaml` racine, ni des scripts `scripts/ci/*` (le gate existe déjà). Si un ajustement de `.gitignore` racine est jugé utile, le limiter à des porteurs de secrets et le justifier — l'existant ignore déjà `.env*`.
- **Ne pas** toucher `sprint-status.yaml` (géré par l'orchestrateur) ni committer (commit en fin d'épic).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E1] — Objectif E1 (traitement immédiat du secret fuité) et Story E1-5 (l.57), Story E11a-1 (l.114, dépend de E1-5), E11a-3 (l.116, retrait `badCertificateCallback`).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-12] — Zéro secret dans les packages ; interdits TLS/endpoints en dur (l.112-115).
- [Source: scripts/ci/gate_secret_scan.dart] — motifs `AIza…`/AWS/PEM/`badCertificateCallback`/Slack, périmètre M-2, auto-exclusions.
- [Source: scripts/ci/prove_gates.dart#87-107] — preuve par fixture (clé factice par concaténation, affectation `badCertificateCallback`).
- [Source: melos.yaml#gate:secrets / verify] — `dart run melos run gate:secrets`, `melos run verify` (l.42-67).
- [Source: packages/zcrud_geo/] — squelette `ZGeoApi` (placeholder), `pubspec.yaml` = `zcrud_core` seul ; impl déférée E11a-1.
- [Source: CLAUDE.md#Key Don'ts] — « Never de secret dans un package (clé API Google Maps, endpoints) — config plateforme de l'app ; never `badCertificateCallback => true` ».

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high) — chemin pris : skill `bmad-dev-story` chargé (base `/home/zakarius/DEV/zcrud/.claude/skills/bmad-dev-story`).

### Debug Log References

Vérif verte rejouée réellement sur disque (post-implémentation), au `baseline_commit` `8f28755` :

- `dart run scripts/ci/gate_secret_scan.dart` → `gate:secrets OK` — **exit 0**.
- `dart run melos run verify` → tous les gates verts (graph ACYCLIQUE OK / core out=0 ; melos ; reflectable ; secrets ; codegen ; compat manifeste OK, voie workspace SKIP informationnel ; verify:serialization no-op vert) — **RC=0**.
- `dart run scripts/ci/prove_gates.dart` → **22 OK, 0 FAIL** (fixtures de violation échouent toujours ; non-régression du gate durci E1-3) — **RC=0**.
- `dart run melos run analyze` → **RC=0**.
- `dart run melos list` → **14** membres. Graphe AD-1 acyclique intact. `git ls-files '*.g.dart'` → **0** (aucun code généré committé).
- Découplage prouvé : `grep -rn "AIza" packages/` → **aucune occurrence** ; `grep -rniE "google_maps|maps_flutter|mapbox|google_maps_flutter" packages/` → **aucune occurrence** ; `packages/zcrud_geo/pubspec.yaml` → seule dépendance `zcrud_core: ^0.0.1`.
- Zéro vraie clé introduite : `grep -rnE "AIza[0-9A-Za-z_-]{35}" .` (hors `.git/`) → **aucune occurrence** dans tout le dépôt. Le runbook n'utilise que des placeholders (`YOUR_MAPS_API_KEY`, `$GOOGLE_MAPS_API_KEY`, `AIza<REDACTED>`). NB : le repli local de `gate:secrets` exclut la prose Markdown (`.md`/`.markdown`) — contre-exemples documentés — mais gitleaks la couvre en CI ; le runbook a été rédigé sans séquence `AIza`+35 réels par précaution.

### Completion Notes List

**Groupe A (vérifiable sur disque) — RÉALISÉ et vert :**
- ✅ AC1 — Runbook d'injection par config plateforme créé : `docs/security/api-keys-injection-runbook.md` (Dart `--dart-define`/`--dart-define-from-file`, Android `local.properties`/Gradle `manifestPlaceholders` → manifest `${...}`, iOS `.xcconfig`/`Info.plist` par référence, Web substitution build/runtime, CI secrets pipeline), règle « la clé n'est JAMAIS committée » explicite, placeholders uniquement.
- ✅ AC2 — Check-list de révocation/rotation Owner documentée (§4), étiquetée **« 🔴 HUMAN ACTION REQUIRED — Owner: Zakarius »**, avec critères d'attestation (révocation, invalidité `REQUEST_DENIED`, purge DODLP/DLCFTI) sans jamais exiger la vraie clé.
- ✅ AC3 — Découplage `zcrud_geo` prouvé (grep zéro clé/SDK Maps sur `packages/**` ; `pubspec.yaml` = `zcrud_core` seul ; renvoi impl E11a-1 noté).
- ✅ AC4 — `gate:secrets` exit 0 + `melos run verify` RC=0 ; `prove_gates.dart` inchangé (22 OK / 0 FAIL).
- ✅ AC5 — Interdit AD-12 `badCertificateCallback => true` rappelé dans le runbook (§6) + renvoi au gate qui le bloque ; aucune occurrence réelle dans zcrud.
- ✅ AC6 — Aucune vraie clé introduite (placeholders uniquement) ; `gate:secrets` reste vert.

**Groupe B (ACTION HUMAINE — Owner: Zakarius) — NON traité, hors ressort de l'agent :**
- ⏳ AC7 (révocation/restriction effective), AC8 (preuve d'invalidité), AC9 (purge dépôts externes DODLP/DLCFTI) — **non cochés**. Ces actions s'opèrent dans la console Google Cloud et sur des dépôts externes ; aucun agent ne peut les exécuter ni les attester.

> **⚠️ Passage à `done` BLOQUÉ par le groupe B.** Le groupe A est intégralement vert sur disque, ce qui conditionne `review`. Le passage **global** de la story à `done` reste **conditionné à l'attestation humaine explicite de l'Owner (Zakarius)** des AC 7–9 (§5 du runbook / §Condition de clôture). `dev-story` n'a pas autorité pour cocher les AC 7–9. Statut story → **review**.

### File List

- `docs/security/api-keys-injection-runbook.md` (créé) — runbook d'injection sécurisée + check-list de révocation/rotation Owner + garanties by-design zcrud.
- `_bmad-output/implementation-artifacts/stories/e1-5-revocation-cle-google-maps.md` (modifié) — sections permises : Status, Tasks/Subtasks, Dev Agent Record, File List.
