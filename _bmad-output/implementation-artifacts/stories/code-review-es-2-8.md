# Code Review — ES-2.8 « Podcast content-addressed (`ZStudyPodcast` + invalidation par `sourceHash`) »

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chargé normalement — **PAS** de fallback disque).
- **Date** : 2026-07-15
- **Story** : `_bmad-output/implementation-artifacts/stories/es-2-8-podcast-content-addressed.md` (16 ACs, DERNIÈRE story de l'epic ES-2)
- **Statut entrant** : `review`
- **Mode** : revue adversariale, restauration par **édition ciblée** (jamais `git checkout` — working-tree non committé).
- **Périmètre diff (LU, `git diff --stat`)** : kernel `zcrud_study_kernel` (5 fichiers domaine neufs + `z_study_podcast.g.dart` généré + 4 tests + barrel + `z_kernel_purity_test.dart`), `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (barrel : 7 symboles `hide`), `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (classification), `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage). **Aucun widget, aucun repository, aucune dép crypto.** ✅

---

## VERDICT : ✅ APPROUVÉ (`done`-ready)

**0 HIGH · 0 MAJEUR · 0 MEDIUM · 2 LOW/nits (consignés, non bloquants).**

L'implémentation est un **jumeau fidèle** de `ZExam` / `ZDocumentAnnotation` (patron `ZExtensible` ES-2.2b INTÉGRAL), avec l'invariant central FR-S11 tenu : **le kernel COMPARE des empreintes `String` OPAQUES, il ne HASHE RIEN**. Toutes les gardes critiques ont un **pouvoir discriminant OBSERVÉ** (8 injections R3 rejouées, RC≠0), y compris la vérification **bidirectionnelle** de `isStale` / `podcastFreshness` exigée par la leçon ES-2.3. Aucun faux-vert détecté.

---

## Axes adversariaux — résultats OBSERVÉS (rouges provoqués réels)

### 1. `isStale` / `podcastFreshness` — pouvoir discriminant BIDIRECTIONNEL ✅ OBSERVÉ
- `isStale => false` : **3 tests RED** (`source A : isStale(B)==true`, `symétrie source B`, `R3 retour constant`) — la jambe « stale » mord.
- `isStale => true` : **3 tests RED** (mêmes tests) — la jambe « fresh » mord. **Pouvoir bidirectionnel PROUVÉ** : ni un `sourceHash` figé, ni un golden fortuit ne survivrait. Les tests font varier **les DEUX** empreintes (stored ET current).
- `podcastFreshness => ZPodcastFreshness.fresh` (constante) : **3 tests RED** (`parité lex absent/fresh/stale`, `R3 garde absent`) — la garde `storedHash null/vide → absent` **et** la branche `stale` mordent.
- **Politique `sourceHash` vide/null** : documentée et déterministe (D4, dartdoc `z_podcast_freshness.dart` l.44-49). Bords testés (5 couples + boucle de totalité `returnsNormally` sur 3×4 combinaisons). `isStale('')` sur `sourceHash=''` → `false` ; `podcastFreshness('' , 'h') → absent`. La divergence `isStale`(2 états)/`podcastFreshness`(3 états) sur `storedHash` vide est **intentionnelle et SANS risque** (les deux surfaces sont sûres : jamais de faux « fresh » sur une source réellement changée). Voir OBS-1.

### 2. Kernel crypto-free ✅ OBSERVÉ
- Injection `import 'package:crypto/crypto.dart';` dans `z_study_podcast.dart` → `z_kernel_purity_test.dart` **RED** (test `aucun fichier de lib/ ne référence 'package:crypto' en CODE`). Le scan couvre **tout** `lib/**` (AC13). Restauré.
- `pubspec.yaml` du kernel : **AUCUNE** dépendance crypto (LU — inchangé par la story). `graph_proof` (rejoué par l'orchestrateur) : deps kernel = `{annotations, core}`, ACYCLIQUE + CORE OUT=0.
- Le kernel ne hashe rien : `sourceHash` est un `String` comparé (`!=`) ; aucun `zFnv1a32`, aucun SHA-256 (LU, `z_study_podcast.dart` l.243, `z_podcast_freshness.dart` l.60-62).

### 3. Enum `ZPodcastStatus` — ordre normatif ✅ OBSERVÉ
- `ready` est **`.values.first`** (LU `z_podcast_status.dart` l.36 ; test `z_podcast_status_test.dart` l'épingle).
- Injection **reorder** (`pending` en tête) + `build_runner` : **RED** (`la 1ʳᵉ constante EST ready` + `absent/null/non-String/inconnu ⇒ ready`) — le fallback bascule silencieusement sur `pending`, capté. Restauré + regénéré (byte-identique : le `.g.dart` référence `.values.first` symboliquement, `grep -c values.first` = 3).
- Décodage corrompu `status:'zzz'` → `ready` (fallback), `mode:'zzz'` → `simple`, `source_kind:'zzz'` → `note` (LU + testé, no throw). `unknownEnumValue` couvert par `_$enumFromName(...) ?? T.values.first` généré. Valeurs persistées **camelCase** (`name`) — testé (`map['status']=='stale'`, etc.).

### 4. Injections R3 gate (≥2 exigées — **4 rejouées**) ✅ OBSERVÉ
| # | Injection | Résultat | RC |
|---|-----------|----------|-----|
| (D) | `registerZStudyPodcast` retiré de `kRegistrars` | gate **RED** — writer orphelin + `ZUnregisteredTypeError study_podcast` (couverture R_disk\R_wired) | ≠0 |
| (G) | `...ZSyncMeta.reservedKeys` retiré de `_reservedKeys` | gate **RED** — `[study_podcast#ctor]/[#copyWith] (i.1a) DW-ES22-3 VIOLÉ : is_deleted RÉÉMIS` | ≠0 |
| (H) | `hide ZStudyPodcastZcrud` retiré du barrel kernel | `prove_gates` **RED** — `reserved-keys/clean` passe OK→FAIL (règle (h) capte l'extension générée exportée) | ≠0 |
| (surf) | `ZStudyPodcast` retiré du `hide` de `zcrud_flashcard` | surface-guard **RED** — `FUITE POTENTIELLE {ZStudyPodcast}` | ≠0 |

Voie `ctor` : câblée et **VERBATIM** (`_ctorStudyPodcast` transmet `extra: x` sans filtre, LU l.781-796) ; `eagerlyNormalized:false` (ctor `const`). Voie `copyWith` VERBATIM (`_copyWithStudyPodcast`, l.599-600), `eagerlyNormalized:true`. Les deux voies sondées par le volet (A) — leur suppression rougirait (i.1). `git diff --stat` après restauration : **aucune modification résiduelle** (working-tree identique à l'état entrant).

### 5. AD-19 ✅ LU + OBSERVÉ
- `updated_at`/`is_deleted` de lex **RETIRÉS** (aucun champ inline — LU, `$ZStudyPodcastFieldSpecs` = `{id, source_kind, source_id, folder_id, mode, source_hash, result_ref, status, created_at}`). Test `aucun champ nommé updated_at/is_deleted`.
- `sourceHash`/`createdAt` = clés MÉTIER (jamais `updated_at`). `_reservedKeys ⊇ ZSyncMeta.reservedKeys` (l.339-343). `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (testé). `$ZStudyPodcastTimestampFields == {}` (∩ sync = {}, testé).
- `kLegacyUpdatedAtMirrors = {'study_folder','flashcard'}` **INCHANGÉ** (LU l.330 — podcast absent). ✅
- Injection (G) prouve que le spread `ZSyncMeta.reservedKeys` est **load-bearing** (le retirer réémet les clés de sync).

### 6. Patron extra ES-2.2b ✅ LU + OBSERVÉ
- Ctor `const` `: _extra = extra` ne filtre rien (l.104) ; accesseur `extra => zNormalizeExtra(_extra, _reservedKeys)` (l.226) = SEUL point traversé ; garde partagée `_sanitizeExtra` = `zSanitizeExtra(raw, _reservedKeys)` appelée par `fromMap` **ET** `copyWith` (l.312-314, 347-354) ; `toMap` étale `...extra` (accesseur, l.260) ; `copyWith` à sentinelle `_$undefined` couvrant **TOUS** les 11 champs.
- Tests OBSERVÉS : `ZStudyPodcast(extra:{'updated_at':'X','k':1}).extra == {'k':1}` (ctor `const` pollué neutralisé) ; `x == fromMap(x.toMap())` ; clé inconnue `zz_cle_inconnue` survit au round-trip store ; `fromMap(const {})` sûr ; égalité **profonde** sur `extra` imbriqué (`{'a':{'b':1}}`) ; `copyWith(extra:{'is_deleted':true})` ne fuit pas.
- Volet (A) du gate confirme (i.1) sur les deux voies (ctor + copyWith).

### 7. AD-10 défensif ✅ LU + OBSERVÉ
- `sourceHash`/`resultRef`/`sourceId`/`folderId` absents ou non-`String` → `''` ; `id` absent → `null` ; `createdAt` non-parsable → `null` ; `extension` corrompue → `null` (`ZExtension.guard`). Tous testés (`fromMap` fixtures corrompues, no throw).
- **AUCUN `assert` dans le ctor `const`** (LU l.88-104, dartdoc explicite). Gardes exclusivement aux frontières `fromMap`/`copyWith`.
- `buildId`, `isStale`, `podcastFreshness` **TOTALES** (jamais throw / `null!`).

### 8. Surface (D) ✅ OBSERVÉ
- 7 symboles `hide` dans `zcrud_flashcard.dart` (`ZStudyPodcast`, `ZStudyPodcastExtensionParser`, `ZPodcastSourceKind`, `ZPodcastMode`, `ZPodcastStatus`, `ZPodcastFreshness`, `podcastFreshness`) + classés via `hide` (pas allowlist). Injection surface-guard = RED (pouvoir observé, pas powerless — leçon DW-ES25-1). Barrel kernel : `z_study_podcast.dart hide ZStudyPodcastZcrud` ; 4 enums + `podcastFreshness` exportés **sans** `hide` (précédent `ZReviewMode`).

### 9. Périmètre ✅
Diff limité à : kernel (entité + 4 enums + g.dart + 4 tests + barrel + purity test) + `zcrud_flashcard.dart` (barrel) + surface-guard test + `registrars.dart`. Aucun widget/repository, aucune crypto. Conforme à la File List de la story.

---

## Findings

### OBS-1 (informationnel, non-défaut) — divergence `isStale` vs `podcastFreshness` sur `storedHash` vide
`z_study_podcast.dart:243` / `z_podcast_freshness.dart:57-62`. Pour un podcast à `sourceHash == ''` (jamais généré), `isStale(currentNonVide)` retourne `true` (« stale »), tandis que `podcastFreshness(storedHash:'', ...)` retourne `absent`. **Ce n'est PAS un défaut** : `isStale` est binaire (2 états) et collapse `absent`→`stale` (côté sûr : « régénérer ») ; `podcastFreshness` distingue les 3 états pour l'UI. Aucun scénario ne produit un faux « fresh » sur une source réellement changée (pas de cache-hit erroné, pas de perte). Comportement documenté (D4). Consigné pour mémoire, **aucune action requise**.

### LOW-1 (doc) — libellé AC3 vs ordre du spread `toMap`
`z_study_podcast.dart:255-262`. L'AC3 dit littéralement « réutilise `ZStudyPodcastZcrud(this).toMap()` **puis** superpose `...extra` », ce qui suggérerait `extra` en dernier (gagnant). Le code fait `{...extra, ...ZStudyPodcastZcrud(this).toMap()}` (extra **en premier**), **strictement conforme aux jumeaux `ZExam` (l.240-241) et `ZDocumentAnnotation`**. Comme `extra` est normalisé contre `_reservedKeys` (qui **contient** tous les noms de champs de schéma), les deux ensembles sont **disjoints par construction** ⇒ l'ordre est sans effet observable. Le code suit le bon précédent ; c'est le **libellé de l'AC** qui est imprécis. **Aucune correction de code nécessaire.**

### LOW-2 (nit) — helper privé `_asStringMap` dupliqué
`z_study_podcast.dart:392-398` redéfinit un coerce map identique en intention au `_$asStringMap` généré (g.dart:149-159). Duplication mineure **assumée par le patron** (les jumeaux exposent aussi leur propre helper d'instance, indépendant du code généré). Non bloquant.

---

## Vérification verte rejouée (réelle, sur disque)
- Tests kernel podcast/enums/purity : **42 passed** (`dart test`, VM). ✅
- Surface-guard `zcrud_flashcard` : vert (rougit sous injection). ✅
- `prove_gates.dart` : **41 OK, 0 FAIL** (après restauration). ✅
- `gate_reserved_keys.dart` (volet A + B + couverture AD-19.1.c) : **OK**. ✅
- `.g.dart` intact (regen post-reorder byte-identique). ✅

**MEDIUM à corriger** : aucun. **HIGH/MAJEUR** : aucun. Story prête pour `done` (transition réservée à l'orchestrateur ; ce reviewer NE touche NI le code de production NI le sprint-status).
