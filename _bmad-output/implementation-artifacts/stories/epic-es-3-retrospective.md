# Rétrospective — Epic ES-3 : Ports & couche data offline-first bi-topologie

**Skill** : `bmad-retrospective` (voie Skill, effort medium).
**Date** : 2026-07-15.
**Périmètre** : 6 stories, **toutes `done`** (ES-3.0 → ES-3.5).
**Packages touchés** : `zcrud_core`, `zcrud_generator`, `zcrud_study_kernel` (ports/registre), `zcrud_firestore` (adapters), + 9 `.g.dart` régénérés.

> Facilitation : Amelia (Developer), Alice (Product Owner), Charlie (Senior Dev), Dana (QA), Zakarius (Project Lead).
> Sécurité psychologique — on juge des systèmes et des artefacts, jamais des personnes.

---

## 1. Résumé de livraison

| Story | Objet | Verdict CR | Findings | Dette soldée / ouverte |
|-------|-------|-----------|----------|------------------------|
| **ES-3.0** | `ZDecodeContext` ; registre préserve extension TYPÉE + `sourceRegistry` (DW-ES14-2) ; immuabilité inconditionnelle patron des 5 canaux (DW-ES24-1). TÊTE bloquante. | APPROVED | 0 H/MAJ/MED, 2 LOW (nit idempotence + hygiène `pubspec.lock`) | ✅ DW-ES14-2, ✅ DW-ES24-1 |
| **ES-3.1** | `ZStudyRepository<T>` Template Method (`save`→`validate`→`persist`). | APPROUVÉ s/réserve M1 | M1 (MEDIUM) **corrigé** : `@nonVirtual save` ; 1 LOW informationnel | — |
| **ES-3.2** | `ZOfflineFirstBoxRepository` + `ZFirestorePathResolver` bi-topologie. | APPROUVÉ | 0 H/MAJ/MED, 1 LOW (DW-ES32-1) | DW-ES32-1 **reportée** |
| **ES-3.3** | `ZCascadeRegistry` + `ZFirestoreCascadeBatcher` (bornage ≤450 via `batchCount`, anti-two-owners, terminaison). | APPROUVÉ | 0 H/MAJ/MED, 3 LOW (DW-ES33-1) | DW-ES33-1 reportée (aval zcrud_study) |
| **ES-3.4** | `registerAll` additif (core) + fabrique `assembleZStudySyncOrchestrator`. | APPROVED | 0 H/MAJ/MED, 2 LOW (dont DW-E54-1) | DW-E54-1 (bug pré-existant E5-4) |
| **ES-3.5** | `ZStudyLegacyCodec` + corpus IFFD legacy + gate `verify:serialization` **ENFORCED**. | APPROUVÉ | 0 H/MAJ, 3 LOW (dont DW-ES35-1) | ✅ DW-ES21-1 ; DW-ES32-1 partielle ; LOW DW-ES35-1 |

**Bilan qualité** : 6/6 stories vertes. **1 seul finding MEDIUM sur tout l'epic** (M1 ES-3.1, corrigé). Zéro HIGH, zéro MAJEUR. Tous les cœurs prouvés par **injection R3 rejouée par l'orchestrateur** (pas seulement l'agent), restaurée par édition ciblée (R13, jamais `git checkout`).

---

## 2. Ce qui a marché

- **La TÊTE bloquante ES-3.0 a payé exactement comme la rétro ES-2 l'avait prescrite.** Solder DW-ES14-2 et DW-ES24-1 *avant* tout câblage store (R11) a évité que la voie registre destructrice ne soit branchée sur un store : la « perte de données irréversible dès la 1ʳᵉ écriture » redoutée en ES-2 n'a jamais eu de fenêtre pour exister. `ZNoteAudio` round-trippe et **revient TYPÉ**, prouvé discriminant. La clause d'échappement mensongère de `firebase_z_repository_impl.dart` a été **supprimée**, pas contournée.
- **Composition AD-4 systématique.** L'immuabilité (DW-ES24-1) a été soldée par un **accesseur immuabilisant uniforme sur les 5 canaux** — un patron unique, pas 5 correctifs par entité (application propre de R11). Idem la cascade ES-3.3 (registre déclaratif borné) et l'orchestrateur ES-3.4 (`registerAll` **strictement additif** au core, +17 lignes / 0 suppression) : chaque brique compose au lieu de dupliquer.
- **Additivité stricte du core tenue tout l'epic.** Aucune story ES-3 n'a retiré de symbole public de `zcrud_core` — la classe de régression cross-package qui avait laissé `melos analyze` RED plusieurs commits en E11a-3 ne s'est pas reproduite. AD-1 (`CORE OUT = 0`) re-vérifié OBSERVÉ en ES-3.0.
- **R3 rejouée par l'ORCHESTRATEUR, pas seulement l'agent.** Sur chaque story, le net a été prouvé load-bearing par un rouge provoqué *ré-exécuté indépendamment* : le rapport de l'agent n'a jamais tenu lieu de preuve. C'est ce protocole qui a validé le durcissement de gate d'ES-3.5.
- **Le durcissement du gate `verify:serialization` (warning → ENFORCED).** ES-3.5 est l'incarnation du motif traqué : un gate déclaré valide sur son *existence* ne prouve rien ; seul un **rouge provoqué** (corpus vidé → RC=1 ; firestore détaggé → RC=1) prouve son pouvoir discriminant. Le gate mord désormais réellement, et DW-ES21-1 (mapping legacy IFFD 6→4 statuts) est soldée dans l'ADAPTER, jamais dans le domaine.

## 3. Ce qui est à améliorer

- **Deux gotchas d'outillage ont failli produire de faux diagnostics** — non détectables par lecture, seulement par exécution. Ils doivent devenir des règles (R14/R15 ci-dessous), sinon ils se reproduiront à chaque story data.
- **Un gate dont la population est self-déclarée porte un faux-vert résiduel** (DW-ES35-1) : le pouvoir discriminant *présent* d'ES-3.5 ne protège pas contre une *sortie silencieuse* future de la population (retrait d'un `dart_test.yaml`). Motif R6/R10 non encore totalement fermé — à statuer (§4).
- **Reste une frange DW-ES32-1** (double/num + `Timestamp` tiers) : le codec normalise `int` millis mais pas `double`/`num`, et la voie méta lit encore le map brut. Hors-système tant qu'aucun writer tiers n'écrit de `Timestamp` natif — mais ES-3.5 (interop DODLP/IFFD) est précisément le contexte qui pourrait l'introduire.

---

## 4. Nouvelles règles (suite de R1..R13)

### R14 — Le runner d'un package Flutter est `flutter test`, jamais `dart test`

`zcrud_core`, `zcrud_study_kernel`, `zcrud_firestore` sont des **paquets Flutter** : les exécuter sous `dart test` crash le compilateur (chargement FFI) et produit un **artefact de faux diagnostic** (échec attribué au code alors qu'il est attribuable au runner). Corollaire de R3/R9 : une vérif verte n'est probante que si elle a tourné sous le **bon runner** ; un « rouge » sous mauvais runner ne prouve rien et un « vert » non plus. Choix du runner = par nature du package (dépendance `flutter` dans `pubspec.yaml`), jamais par habitude.

### R15 — La mesure d'un code de retour se capture, elle ne se lit pas en bout de pipe

Sous zsh (et POSIX), `cmd | tail` renvoie le **RC du dernier maillon du pipe**, pas de `cmd`. Mesurer un RC via un pipe masque systématiquement l'échec réel (faux-vert d'outillage). Tout gate/vérif dont le verdict est un RC le capture d'abord (`OUT=$(cmd); RC=$?`) **avant** tout filtrage d'affichage. Corollaire de R3 : une injection R3 dont le rouge est lu à travers un pipe n'a **rien prouvé** — il faut le RC de la commande gardée elle-même.

### R16 — Un gate à population self-déclarée porte un faux-vert résiduel : il exige un plancher non-optable

Un gate qui dérive sa population redevable d'un **opt-in** (tag/`dart_test.yaml`, allowlist, annotation) peut être **vidé silencieusement** par le retrait de l'opt-in, sans RC=1 — le gate cesse de mordre sans crier (violation R6 « pas de dégradation silencieuse », angle mort R10). Tout gate à population opt-in doit porter un **plancher constant, non-optable** : un ensemble de membres *toujours* redevables quel que soit leur opt-in, dont la **sortie** de la population est RC=1. L'opt-in reste pour l'évolutivité (ajout de nouveaux membres) ; le plancher garantit qu'un membre-socle ne peut pas s'auto-exclure. *(DW-ES35-1 : `verify_serialization.dart` doit planchériser `{zcrud_firestore, zcrud_generator, zcrud_study_kernel}`.)*

---

## 5. DÉCISION DW-ES35-1 (décision de PATRON, R11) — **OUI, avec plancher**

**Question** : ajouter un plancher `{zcrud_firestore, zcrud_generator, zcrud_study_kernel}` TOUJOURS redevable dans `verify_serialization.dart`, indépendamment de leur `dart_test.yaml` ?

**Recommandation : OUI.** Justification :
1. **R16 (cristallisée dans cette rétro) l'impose directement** : un gate à population opt-in sans plancher est un faux-vert résiduel structurel, pas un nit contextuel. C'est exactement la classe de défaut R6/R10 qui a produit trois faux-verts en ES-1.
2. **Coût quasi nul, bénéfice permanent** : le micro-changement est additif et confiné à un seul fichier ; il n'altère pas l'évolutivité opt-in (D7) — il ne fait qu'interdire la *sortie* des trois socles.
3. **Le contexte aval le rend actif** : ES-4/ES-5 et E7 (intégration DODLP) vont multiplier les entités persistées ; la probabilité qu'un refactor déplace/retire un `dart_test.yaml` de socle croît.

**Micro-changement (à implémenter — la rétro ne code pas)** :
```dart
// scripts/ci/verify_serialization.dart
const _floorRequired = {'zcrud_firestore', 'zcrud_generator', 'zcrud_study_kernel'};
// après construction de la population redevable :
final missing = _floorRequired.difference(payablePackages);
if (missing.isNotEmpty) { stderr.writeln('FLOOR VIOLATION: $missing hors population'); exit(1); }
```
Garde-fous R2/R3 : livrer avec **sa fixture d'échec isolée** dans `prove_gates.dart` (retirer un socle de la population → RC=1 **par ce plancher**, distinct du RC=1 corpus-vidé) et **injection R3 rejouée par l'orchestrateur**.

**Assignation** : story dédiée **early ES-4** — `ES-4.0` (ou first-task d'ES-4.1), en TÊTE, avant que l'afflux d'entités SRS n'élargisse la population opt-in. Alternative acceptable : la greffer sur la première story ES-4 touchant `zcrud_firestore`. **Ne pas** l'enfouir dans une story fonctionnelle non nommée (violerait R1/R8 : un durcissement de gate est une story nommée).

---

## 6. État des dettes après ES-3

| Dette | Statut | Échéance / story cible |
|-------|--------|------------------------|
| **DW-ES14-2** | ✅ **SOLDÉE** (ES-3.0 — extension TYPÉE + sourceRegistry préservés, clause mensongère supprimée) | — |
| **DW-ES24-1** | ✅ **SOLDÉE** (ES-3.0 — immuabilité inconditionnelle uniforme, 5 canaux) | — |
| **DW-ES21-1** | ✅ **SOLDÉE** (ES-3.5 — mapping legacy IFFD 6→4 dans l'adapter) | — |
| **DW-ES25-1** (R4 — hide des VO à invariant) | ⚠️ **OUVERTE, atténuée** — la convention `hide` est en place ; le trou est l'absence de garde-régression machine. **Le scoping tag-declarer d'ES-3.5 ne l'honore PAS** : c'est une garde de *couverture sérialisation*, pas de *non-export des VO générés*. R4 (prototype avant promesse machine) reste dû. | À prototyper puis statuer — avant ES-6.1 (édition/lecture notes, terrain VO markdown) |
| **DW-ES32-1** | ⚠️ **PARTIELLE** — reste `double`/`num` millis (LOW-3 ES-3.5) + voie méta lisant le map brut sur `Timestamp` tiers. Hors-système actuel. | À solder **si** un writer tiers `Timestamp` est introduit (interop DODLP/IFFD, E7) |
| **DW-ES33-1** (placement arêtes cascade) | ⚠️ **OUVERTE** — aval `zcrud_study` (déclaration des arêtes de cascade côté présentation/étude) | ES-5 / ES-7 (câblage study-tools) |
| **DW-E54-1** (bug E5-4 : `failures` incomplet sur throw) | ⚠️ **OUVERTE** — pré-existant, hors périmètre additif ES-3.4 ; invariant best-effort tenu, seul le rapport est incomplet | Story future touchant l'orchestrateur E5 |
| **DW-ES35-1** | 🟢 **STATUÉE ce jour → OUI plancher** (voir §5) | **early ES-4** (story dédiée) |

**Résumé** : 3 dettes soldées cet epic (14-2, 24-1, 21-1). 1 statuée (35-1 → à implémenter). 4 restent ouvertes/atténuées, toutes hors-système ou couvertes par convention, avec échéance nommée.

---

## 7. Recommandations de séquencement (suite)

- **ES-4 (SRS convergé) ∥ ES-5 (layout study-tools)** : parallélisables — packages **disjoints** (`zcrud_flashcard`/`zcrud_session` vs `zcrud_study`), aucun point de contact `zcrud_core`. Feu vert R-parallélisation (≤3 en vol, fichiers disjoints). Rejouer `melos analyze`/`verify` **repo-wide** au gate de commit de chaque epic (R9).
- **Insérer le plancher DW-ES35-1 en TÊTE d'ES-4** (story dédiée), avant l'afflux d'entités SRS qui élargit la population opt-in du gate.
- **E7 (intégration DODLP) reste bloqué par E11a** (lot parité DODLP) — ne pas le tirer en avant. C'est aussi le déclencheur probable de DW-ES32-1 (writer `Timestamp` tiers) : prévoir de solder la frange double/num **avant** E7, pas pendant.
- **DW-ES25-1** doit être prototypée (R4) **avant ES-6.1** (notes markdown = terrain VO), pas plus tard : sinon un contributeur retire un `hide` sans signal machine.

---

## 8. Verdict de clôture

Epic ES-3 : **COMPLET et SOLIDE.** 6/6 stories vertes, 1 seul MEDIUM (corrigé), cœurs tous prouvés discriminants par R3 orchestrateur. Trois dettes de tête soldées, le patron d'immuabilité et la voie registre définitivement fermés avant tout store. Deux gotchas d'outillage cristallisés en R14/R15, un faux-vert résiduel de gate cristallisé en R16 et **tranché (plancher OUI, early ES-4)**. Aucune découverte ne remet en cause le plan ES-4/ES-5. Prêt à enchaîner ES-4 ∥ ES-5.
