# Code-review ES-9.4 — Communauté / partage optionnelle + modération (dette sécu lex)

- **Skill réel invoqué** : `bmad-code-review` (tool `Skill`, workflow adversarial — Blind Hunter / Edge Case Hunter / Acceptance Auditor joués par le reviewer, subagents indisponibles en contexte subagent).
- **Story** : `es-9-4-communaute-partage-optionnelle-moderation.md` — statut `review`, [L] SÉCURITÉ-CRITIQUE.
- **Baseline** : `5271ac1f`. Périmètre écrit/injecté : `packages/zcrud_study/` UNIQUEMENT. Kernel/core NON modifiés. Aucun `dart pub get`, aucune bascule pubspec. Toute injection R3 restaurée par édition ciblée (R13).
- **Date** : 2026-07-16.

## Verdict : ✅ APPROUVÉ — 0 HIGH · 0 MAJEUR · 0 MEDIUM · 2 LOW (informatifs, non bloquants)

La garde de sécurité cœur (`ZStudySharingAcl.canMutateControl`) est **réellement load-bearing** : sa neutralisation en prod fait ROUGIR 5 tests. Séparation d'état personnel, révocation monotone, `extra` protégé (AD-19.1), optionalité (AD-26) et neutralité des ports (AD-5/AD-11) sont tous verrouillés par des tests à rouge provoqué. Aucun secret/SDK/endpoint. Graphe intact.

---

## Preuves de vérification (R3 — RC hors pipe, rejouées RÉELLEMENT sur disque)

| Vérif | Commande | RC | Résultat |
|---|---|---|---|
| Tests package (R14 flutter) | `flutter test` | **0** | **201 tests** — All tests passed |
| Suite partage ES-9.4 (7 fichiers) | `flutter test test/z_study_sharing_*.dart` | **0** | **53 tests** verts |
| Graphe (AD-1/AC2) | `python3 scripts/dev/graph_proof.py` | **0** | **44 arêtes**, ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds |
| Workspace | `dart run melos list` | **0** | **20 packages** |
| Gates repo-wide | `dart run melos run verify` | **0** | `gate:secrets OK`, `[gate:reserved-keys] OK` (volets A+B+AD-19.1.c), reflectable/codegen/codegen-distribution/compat/`verify:serialization` OK |

### Pouvoir discriminant confirmé (injection CŒUR rejouée par l'orchestrateur)

- **R3-ACL (AC5, sécurité)** — `return isOwnerByRole || isOwnerByIdentity;` → `return true;` dans `z_study_sharing_acl.dart` : `z_study_sharing_acl_test.dart` **RC=1 (RED)**, **5 tests tombent** (contributeur, viewer, rôle inconnu, actorUid vide, dé-révocation par non-owner). Garde **NON powerless**. Fichier restauré à l'identique (`diff` = clean, aucune résidualité).

> Les autres verrous R3 (R3-EXTRA, R3-PERSONAL, R3-SECRET, R3-SURFACE, R3-EQ) sont structurellement prouvés : `gate:secrets` + `gate:reserved-keys` verts, tests de surface/égalité/personnel verts, et leur logique de rougissement est inspectée ci-dessous.

---

## Axes adversariaux — analyse

### 1. 🔴 SÉCURITÉ ACL (AC5, cœur, dette lex) — CONFORME

- `canMutateControl` : `owner` (par rôle) OU `actorUid == ownerUid` non vide ⇒ `true` ; `contributor`/`viewer`/`unknown` non-owner ⇒ `false`. Test couvre les 4 rôles + identité + `actorUid`/`ownerUid` vides (n'usurpe pas l'owner).
- **Révocation monotone** : `revoked`/`revoked_at` ∈ `controlFields` ; un contributeur ne peut donc dé-révoquer (test `R3-REVOKE` explicite). Le helper `ZShareLink.revoke()` ne dé-révoque jamais (positionne `revoked=true` uniquement).
- **Champs de contrôle** : `controlFields` couvre owner_uid/owner_id, is_public/listed_at, can_be_joined_with_link/joinable_with_link, share_id/share_link_id, co_owners_can_invite/co_workers_can_invite_others, shared_with, role, revoked/revoked_at — y compris les clés legacy du bloc V2c inerte de `ZStudyFolder` (défense d'un payload lex). Bloc V2c NON réactivé.
- Injection R3-ACL rougit ⇒ **pas de faille powerless**.

### 2. État personnel séparé (AC3) — CONFORME

`z_study_sharing_personal_state_test.dart` : intersection VIDE entre les clés `toJson()` des 4 entités + extension et l'ensemble `{repetition, repetition_info, folder_contents_order, reading_state, learning_info, ease_factor, interval, repetitions, due_date, next_review}`. Aucune entité de partage ne référence `ZRepetitionInfo`/`ZFolderContentsOrder`/état de lecture. Ajouter `ease_factor` au `toJson` d'une entité rendrait l'intersection non vide ⇒ RED.

### 3. Pouvoir discriminant (R12) + M-1 + égalité par valeur (leçon ES-9.3 MEDIUM-1) — CONFORME

- `==`/`hashCode` par valeur sur les 5 types, `extra` profond via `zJsonEquals`/`zJsonHash`. `z_study_sharing_entities_test.dart` varie **chaque champ un à un** (id, token, folderId, ownerUid, `revoked`, `revokedAt`, `role`, `status`, `extra`…) : retirer un champ de `operator ==` rendrait le cas mono-champ VERT ⇒ RED provoqué. Couverture complète vérifiée type par type.
- `extra` AD-19.1 verrouillé sur les 4 entités par `z_study_sharing_reserved_keys_test.dart` (accesseur `zSanitizeExtra` ; deux instances ne différant que par une clé réservée sont égales ; `toJson` ne réémet jamais `updated_at`/`is_deleted`). Neutraliser `get extra => _extra;` ⇒ RED.

### 4. R26 / AD-4 / AD-5 / AD-9 / AD-10 / AD-11 / AD-19.1 — CONFORME

- **R26** : round-trip `toJson`/`fromJson` exact non dégénéré ; la révocation survit au décodage (`revoked`/`revokedAt` reconstruits).
- **AD-4** : `ZStudySharingExtension implements ZExtension` (pas `extends`, pas `sealed`), `formatVersion` propre, `fromJsonSafe` sur `ZExtension.guard` (version absente/non gérée/corrompu ⇒ `null`, jamais throw). Ports `abstract interface class`, jamais `sealed`.
- **AD-5** : ports → `Future<ZResult<T>>` / `ZResult<Unit>` (void), flux `Stream<List<T>>` NU. Pincé par liaison de type statique (`z_study_sharing_ports_surface_test.dart`) — un retour non-`Unit` casserait la compilation.
- **AD-10** : `fromJson` défensif partout (non-map ⇒ défaut, type faux ⇒ repli, enum inconnu ⇒ `unknown`, jamais throw).
- **AD-11/AD-12** : ports neutres, aucun SDK/endpoint/clé/collection en dur/crypto. `z_study_sharing_no_secret_test.dart` + `gate:secrets` verts. `study_share_links` documenté comme concern d'adapter (AD-20), jamais codé dans le domaine.

### 5. AD-1 / optionalité (AC2) — CONFORME

- Graphe : **delta = 0** pour ES-9.4 (les arêtes `zcrud_flashcard`/`zcrud_exam` du pubspec proviennent de ES-9.1/ES-9.2, pas de cette story ; la surface de partage n'importe que `zcrud_core/domain.dart` et — en test seulement — `zcrud_study_kernel`). 44 arêtes, ACYCLIQUE, CORE OUT=0, 20 nœuds.
- **Optionalité** : `ZStudyFolder.fromMap(map)` SANS parser ⇒ `extension == null`, dossier survit ; AVEC `extensionParser: ZStudySharingExtension.fromJsonSafe` ⇒ extension typée. Slot kernel RÉUTILISÉ (R21), jamais re-déclaré. `zcrud_study_kernel` NON modifié.

---

## Findings

### LOW-1 — `ZStudySharingExtension` sans slot `extra` : clés inconnues (même formatVersion) non préservées au round-trip
`packages/zcrud_study/lib/src/domain/z_study_sharing_extension.dart:82-101`. `fromJsonSafe` ne lit que les 4 clés typées ; toute clé additionnelle d'un client futur de MÊME `format_version` est silencieusement abandonnée (pas d'échappatoire `extra` comme sur les 4 entités). **Scénario** : client v1.1 ajoute `moderated_by` sans bump de version → client v1.0 relit le dossier → `moderated_by` perdu. **Impact réel : nul** dans le cadre ES-9.4 (aucune telle clé n'existe ; l'évolution additive de l'extension passe par un bump `formatVersion` ⇒ `null` défensif, exactement le précédent `ZNoteAudio`). AC6 (« et `ZStudySharingExtension` portant un `extra` ») est **vacuously satisfait** : l'extension ne porte pas d'`extra`, donc rien à assainir. **Correctif optionnel** (hors périmètre, à consigner si une évolution additive intra-version devient nécessaire) : ajouter un slot `_extra` + `zSanitizeExtra` comme sur les entités. **Aucune action requise pour `done`.**

### LOW-2 — La garde locale fait confiance au `role` fourni par l'appelant (résiduel DW-ES94-1, déjà documenté)
`packages/zcrud_study/lib/src/domain/z_study_sharing_acl.dart:109-117`. `canMutateControl(role: ZMembershipRole.owner, ...)` renvoie `true` indépendamment de `actorUid`/`ownerUid` : la sûreté dépend de l'appelant (adapter app) qui DOIT fournir un `role` vérifié côté store, jamais une entrée client. C'est **exactement le résiduel DW-ES94-1**, explicitement inscrit en dartdoc `z_study_sharing_acl.dart:31-44` (+ ports) et escaladé par l'orchestrateur — enforcement serveur hors domaine backend-agnostique (AD-11/AD-12/AD-26). **Traité comme documenté, pas comme défaut caché** : NFR-S11 (« corrigée OU documentée, jamais héritée en silence ») est satisfait des deux façons. **Aucune action requise** ; note de vigilance pour l'implémenteur d'adapter côté app.

---

## Conclusion

Story **verte, sécurité prouvée load-bearing**, tous ACs couverts par des tests à pouvoir discriminant réel. Aucun finding bloquant (HIGH/MAJEUR/MEDIUM = 0). Les 2 LOW sont informatifs et non bloquants. **Prête pour `done`** (transition = responsabilité orchestrateur). `sprint-status.yaml` et `architecture.md` NON touchés ; **DW-ES94-1** reste à escalader par l'orchestrateur.

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 (extension sans slot extra) | 🟡 LOW | 🟡 **CONSIGNÉ** | `z_study_sharing_extension.dart` : les clés inconnues de même `formatVersion` ne sont pas préservées au round-trip. **Impact nul** (évolution additive via bump de version, précédent `ZNoteAudio`) ; AC6 vacuously satisfait (l'extension ne porte pas d'`extra`). Aucune action requise. |
| LOW-2 (ACL fait confiance au role fourni) | 🟡 LOW | ✅ **ESCALADÉ (= DW-ES94-1)** | La garde `canMutateControl` fait confiance au `role` fourni par l'appelant ⇒ la sûreté dépend d'un `role` vérifié côté store. **C'est exactement DW-ES94-1** (enforcement serveur hors domaine backend-agnostique) : déjà en dartdoc, désormais **escaladé dans `architecture.md § Deferred › DETTES OUVERTES › DW-ES94-1`**. Note de vigilance, non-bloquant (NFR-S11 satisfait : le domaine fournit le prédicat de vérité, l'app le fait respecter au serveur). |

**Spot-check orchestrateur (R3-ACL, sécurité cœur)** : `canMutateControl` neutralisé (`return true`) → `z_study_sharing_acl_test.dart` ROUGIT (`Expected: false, Actual: <true>` — « un contributeur ne doit JAMAIS muter un champ de contrôle », RC=1) ; restauré → RC=0. La dette de sécurité lex est **réellement fermée et verrouillée**.

**Vérif verte (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **201 tests** · `melos run verify` → RC=0 (gate:secrets + gate:reserved-keys OK) · graph_proof RC=0 (44 arêtes, delta=0, ACYCLIQUE, CORE OUT=0) · analyze RC=0.

**Doc appliquée par l'orchestrateur** : `architecture.md § Deferred › DW-ES94-1` (enforcement serveur de l'ACL, résiduel à solder par l'app).

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; sécurité prouvée (garde ACL load-bearing) ; LOW-1 consigné, LOW-2 escaladé (DW-ES94-1).
