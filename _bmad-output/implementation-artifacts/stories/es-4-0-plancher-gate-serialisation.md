---
baseline_commit: aaa7989612f5213509daae9ddbddb7a7513cd650
---

# Story ES-4.0 : Plancher constant du gate de rétro-compat sérialisation

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. TÊTE d'ES-4 (avant l'afflux d'entités SRS qui élargit la population opt-in du gate). -->
<!-- Solde DW-ES35-1 (faux-vert RÉSIDUEL de gate, code-review ES-3.5) — décision de PATRON statuée en rétro ES-3 : OUI plancher. -->
<!-- Cristallise R16 (« un gate à population self-déclarée exige un plancher non-optable »). -->
<!-- Fichiers : scripts/ci/verify_serialization.dart (ajout plancher + option --packages) + scripts/ci/prove_gates.dart (preuve isolée). NE touche AUCUN package lib/test, NI sprint-status.yaml. -->
<!-- Gotchas rétro ES-3 en vigueur : R14 (runner par nature du package), R15 (capture RC hors pipe), R13 (restauration par édition ciblée, jamais git checkout). -->

## Story

As a **mainteneur de la CI zcrud** (qui doit garantir que le gate de rétro-compatibilité de sérialisation `verify:serialization` continue de **mordre** sur les trois packages-socles à entité persistée — `zcrud_firestore`, `zcrud_generator`, `zcrud_study_kernel` — même si un refactor futur retire ou déplace leur `dart_test.yaml`, supprime leur dossier `test/`, ou dé-déclare le tag `serialization-compat`),
I want **un ensemble PLANCHER constant, littéral et non-optable `{zcrud_firestore, zcrud_generator, zcrud_study_kernel}` ajouté à `scripts/ci/verify_serialization.dart` — chacun de ces packages TOUJOURS redevable indépendamment de son `dart_test.yaml` ; la SORTIE d'un package-plancher de la population redevable (dossier `test/` absent, ou tag `serialization-compat` retiré du `dart_test.yaml`) déclenche une bannière dédiée BRUYANTE et un RC=1, sans altérer en rien le squelette existant (itération tag-declarers opt-in, runner `flutter`/`dart`, `exit 79`→skip, interrupteur `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`, bannière ES-1.4) — plus une preuve ISOLÉE et reproductible dans `scripts/ci/prove_gates.dart` (retrait d'un socle de la population ⇒ RC=1 par le plancher, distincte du RC=1 corpus-vidé)**,
so that **le faux-vert RÉSIDUEL structurel de DW-ES35-1 soit soldé : un gate dont la population est self-déclarée par opt-in (tag `dart_test.yaml`, D7) ne peut plus être VIDÉ silencieusement de ses socles par le simple retrait de l'opt-in (violation R6 « pas de dégradation silencieuse », angle mort R10) ; l'opt-in reste pour l'évolutivité (nouveaux packages à entité), le plancher garantit qu'un membre-socle ne peut pas s'auto-exclure (R16).**

---

## Contexte & problème mesuré

### 1. Le faux-vert RÉSIDUEL de DW-ES35-1 (mesuré sur `verify_serialization.dart`)

`scripts/ci/verify_serialization.dart` (lu INTÉGRALEMENT) construit sa **population redevable** ainsi (l.152-161) :

```dart
final withTests = <Directory>[];
for (final ent in pkgs.listSync()) {
  if (ent is Directory &&
      Directory('${ent.path}/test').existsSync() &&
      _declaresCompatTag(ent)) {          // ⇐ MICRO-AJUSTEMENT ES-3.5/D7 : opt-in par dart_test.yaml
    withTests.add(ent);
  }
}
```

`_declaresCompatTag` (l.78-95) renvoie `true` ssi le package **déclare** `serialization-compat:` sous `tags:` dans son `dart_test.yaml`. **La population est donc SELF-DÉCLARÉE par opt-in.** Population mesurée après ES-3.5 = `{zcrud_firestore, zcrud_generator, zcrud_study_kernel}` (les trois portent aujourd'hui `test/` + `dart_test.yaml` déclarant le tag — VÉRIFIÉ sur disque).

**Le trou (DW-ES35-1, code-review ES-3.5) :** un refactor qui **retire/omet le `dart_test.yaml`** (ou son bloc `tags:`), **renomme/supprime le dossier `test/`**, ou **déplace le package** fait sortir ce socle SILENCIEUSEMENT de la population : `_declaresCompatTag` renvoie `false` ⇒ le socle disparaît de `withTests` ⇒ **le gate ne l'itère plus, ne mord plus sur lui, et reste VERT** — y compris sous l'interrupteur (qui ne rend fatal que les tag-declarers *skippés*, pas les *absents*). Le pouvoir discriminant *présent* d'ES-3.5 (corpus vidé ⇒ RC=1 ; firestore détaggé ⇒ RC=1, prouvé en rétro) **ne protège pas** contre cette *sortie future de la population*. C'est exactement la classe de défaut R6/R10 qui a produit trois faux-verts en ES-1.

### 2. La décision de PATRON déjà tranchée (rétro ES-3 §5, R11)

> **DW-ES35-1 → OUI, avec plancher.** Justification (rétro ES-3, §5) : (1) **R16 l'impose directement** — un gate à population opt-in sans plancher est un faux-vert résiduel STRUCTUREL, pas un nit contextuel ; (2) **coût quasi nul, bénéfice permanent** — micro-changement additif, confiné à un fichier, n'altère pas l'évolutivité opt-in (D7), il interdit seulement la *sortie* des trois socles ; (3) **le contexte aval le rend actif** — ES-4/ES-5 et E7 vont multiplier les entités persistées, la probabilité qu'un refactor déplace un `dart_test.yaml` de socle croît.

**Micro-changement recommandé (la rétro ne code pas — cette story code) :**
```dart
const _floorRequired = {'zcrud_firestore', 'zcrud_generator', 'zcrud_study_kernel'};
// après construction de la population redevable :
final missing = _floorRequired.difference(payablePackages);
if (missing.isNotEmpty) { stderr.writeln('FLOOR VIOLATION: $missing hors population'); exit(1); }
```
Garde-fous exigés par la rétro : livrer avec **sa fixture d'échec ISOLÉE** dans `prove_gates.dart` (retirer un socle → RC=1 **par ce plancher**, distinct du RC=1 corpus-vidé) et **injection R3 rejouée par l'orchestrateur**.

### 3. R16 (cristallisée en rétro ES-3) — la loi à encoder

> **R16** — Un gate qui dérive sa population redevable d'un **opt-in** (tag/`dart_test.yaml`, allowlist, annotation) peut être **vidé silencieusement** par le retrait de l'opt-in, sans RC=1. Tout gate à population opt-in doit porter un **plancher constant, non-optable** : un ensemble de membres *toujours* redevables quel que soit leur opt-in, dont la **sortie** de la population est **RC=1**. L'opt-in reste pour l'évolutivité (ajout de nouveaux membres) ; le plancher garantit qu'un membre-socle ne peut pas s'auto-exclure.

### 4. Deux modes de dégradation à couvrir (dérivés du texte DW-ES35-1)

| Mode | Cause | Détection | Verdict |
|------|-------|-----------|---------|
| **(m1)** tag retiré du `dart_test.yaml` (bloc `tags:` supprimé, ou `serialization-compat:` retiré) | `_declaresCompatTag` → `false` | socle ∉ population self-déclarée | **FLOOR VIOLATION ⇒ RC=1** |
| **(m2)** dossier `test/` absent / package déplacé-supprimé | `Directory('.../test').existsSync()` → `false` (ou dir de package absent) | socle ∉ population self-déclarée | **FLOOR VIOLATION ⇒ RC=1** |

Les deux modes convergent vers **le même prédicat** : *un socle absent de la population self-déclarée* (`payablePackages = withTests` par basename). C'est le prédicat du micro-changement rétro. **Aucune exécution de test n'est requise pour ce verdict** — il est purement STRUCTUREL, dérivé du disque via les helpers existants.

### 5. Décision de conception — FLOOR VIOLATION **inconditionnelle** (plus fort que « sous l'interrupteur »)

Le prédicat FLOOR VIOLATION est rendu **fatal RC=1 INDÉPENDAMMENT de l'interrupteur** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`, alors que le mécanisme ORDINAIRE (tag-declarer *skippé* faute de corpus vert) reste, lui, fatal **uniquement sous l'interrupteur** (INCHANGÉ). Justification :

1. **R16 exige un plancher NON-OPTABLE.** Rendre la violation dépendante de l'interrupteur la rendrait *optable via l'interrupteur* — un socle pourrait s'auto-exclure en local sans signal fatal. L'inconditionnalité est ce qui donne au plancher de vraies dents.
2. **Elle est ce qui rend la preuve `prove_gates` ISOLABLE (R2) sans exécution de suites.** Une violation prouvée **sans l'interrupteur** est nécessairement imputable au plancher SEUL : le mécanisme ordinaire (skip) est non-fatal hors interrupteur ⇒ tout RC=1 hors interrupteur ⟺ le plancher. Un plancher *sous interrupteur* serait indiscernable du skip ordinaire par le seul RC.
3. **Le pseudo-code de la rétro ES-3 (§5) est déjà inconditionnel** (`exit(1)` nu) — et **R16 la formule inconditionnellement** (« sa **sortie** de population **est** RC=1 »).
4. **En CI l'interrupteur est TOUJOURS posé** ⇒ inconditionnel ⊇ sous-interrupteur : la directive de tâche « RC=1 sous l'interrupteur » est satisfaite *a fortiori*. La seule différence (bénéfique) est en LOCAL, où l'inconditionnalité donne une détection plus précoce et plus bruyante.

> ⚠️ La bannière FLOOR, elle, est émise **inconditionnellement** dès qu'une violation est détectée (R6 : jamais de dégradation silencieuse), interrupteur ou non — patron bannière ES-1.4.

### 6. Deux pièges d'implémentation MESURÉS (à ne pas reproduire)

- **PIÈGE-A — l'early-return `withTests.isEmpty` (l.164-170) court-circuite `exit(0)` AVANT toute logique de fin.** Un plancher naïvement ajouté *après* la boucle d'exécution serait **CODE MORT sur le chemin exact qu'il doit garder** : une sortie TOTALE du plancher (les 3 socles partis ⇒ population vide) tomberait dans `if (withTests.isEmpty) { … exit(0); }` et rendrait **VERT**. C'est le jumeau exact du bug `prove_gates.dart` « `exit()` dans le `try` ⇒ finally = code mort sur le chemin nominal » (constaté en remédiation ES-1.4). **Le contrôle plancher DOIT être évalué AVANT l'early-return `withTests.isEmpty` ET avant la boucle d'exécution.**
- **PIÈGE-B — `verify_serialization.dart` ne prend AUCUN argument** (il code en dur `Directory('packages')`, l.144). La preuve isolée du plancher dans `prove_gates.dart` a besoin de pointer le gate sur un **arbre de fixture éphémère** (comme TOUS les autres gates : `--root`, `--package`, `--pubspec/--melos`). Il faut donc **ajouter une option `--packages <dir>`** (défaut `packages`) — sans quoi la preuve serait impossible en isolation et le plancher **POWERLESS** (R12/DW-ES25-1 interdit).

### 7. Le piège de fond à contrer (motif dominant — R12)

> « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. »

Un plancher qui ne discrimine RIEN = un mensonge d'artefact. **Chaque AC porte donc un test/preuve qui ROUGIT si la garde saute** (§ Injections R3). La preuve committée dans `prove_gates.dart` doit être NON-POWERLESS : retirer le bloc plancher du code ⇒ la preuve DOIT rougir.

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant** : il nomme le test/preuve qui rougit si la garde saute.

1. **AC1 — Plancher = ensemble CONSTANT, LITTÉRAL, non dérivé.** `verify_serialization.dart` déclare `const Set<String> _floorRequired = {'zcrud_firestore', 'zcrud_generator', 'zcrud_study_kernel'};` — un littéral en dur, JAMAIS dérivé du disque, d'une config, d'un `dart_test.yaml` ou d'un glob. *(Discriminant : si l'ensemble était dérivé de la population elle-même, `_floorRequired.difference(payable)` serait toujours vide ⇒ plancher POWERLESS. Le test/preuve de prove_gates nomme les 3 packages exacts et rougirait sur un ensemble vide/dérivé.)*

2. **AC2 — Dents du plancher : sortie de population ⇒ RC=1 INCONDITIONNEL.** Si un package de `_floorRequired` est ABSENT de la population redevable self-déclarée (`payablePackages = {basename(d) | d ∈ withTests}`), le gate émet une bannière FLOOR dédiée et **sort RC=1, indépendamment de l'interrupteur** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`. Couvre **(m1)** tag retiré ET **(m2)** dossier `test/` absent (les deux ⇒ socle ∉ population). *(Discriminant : preuve prove_gates `serialization-floor/fixture-exit-population` — fixture SANS le socle → RC=1 SANS interrupteur ; INJ-4 : retirer le bloc plancher du code ⇒ RC=0 = faux-vert ré-ouvert.)*

3. **AC3 — Le contrôle plancher précède l'early-return `withTests.isEmpty` (anti-PIÈGE-A).** Le contrôle plancher est évalué AVANT `if (withTests.isEmpty) { … exit(0); }` et avant la boucle d'exécution, de sorte qu'une sortie TOTALE du plancher (population vide) donne **RC=1**, jamais le NO-OP `exit(0)`. *(Discriminant : preuve prove_gates avec `--packages` sur un dossier VIDE → RC=1 attendu, PAS 0 ; un plancher placé après l'early-return donnerait RC=0 — code mort sur le chemin qu'il garde.)*

4. **AC4 — Opt-in PRÉSERVÉ (non-régression ES-3.5/D7) — le plancher est un SUR-ensemble minimal, pas un remplacement.** Le squelette reste INCHANGÉ : population = tag-declarers avec `test/` ; un tag-declarer **hors-plancher** SANS corpus vert reste `skipped` ⇒ RC=1 **uniquement sous l'interrupteur** (comportement ES-3.5). Un package hors-plancher SANS tag reste NON-redevable (jamais forcé dans la population). *(Discriminant : INJ-3 — un tag-declarer hors-plancher sans corpus mord toujours sous l'interrupteur ; le même package, tag retiré, quitte la population sans RC=1 (par design opt-in) — prouvant que le plancher ne s'applique QU'aux 3 socles.)*

5. **AC5 — Option `--packages <dir>` (défaut `packages`) pour la rejouabilité en fixture.** `verify_serialization.dart` accepte `--packages <dir>` remplaçant `Directory('packages')` ; absent/inexistant ⇒ NO-OP `exit(0)` existant (l.144-150) inchangé. *(Discriminant : sans cette option, la preuve isolée du plancher est impossible ⇒ plancher POWERLESS (R12). prove_gates l'utilise ; une régression la casserait.)*

6. **AC6 — Preuve ISOLÉE et reproductible dans `prove_gates.dart`.** Une section `== gate:serialization-floor ==` ajoute au moins : (a) **violation** — fixture packages éphémère via `--packages` d'où un socle est ABSENT, exécutée **SANS interrupteur**, ⇒ RC=1 + bannière FLOOR nommant les 3 packages plancher constants (isolation : SANS interrupteur, le skip ordinaire est non-fatal ⇒ RC=1 ⟺ plancher ; withTests vide ⇒ AUCUNE exécution de suite parasite) ; (b) **contre-épreuve** — le gate sur l'arbre RÉEL (les 3 socles présents & taggés) ⇒ RC=0 (plancher muet, pas de faux-positif). Fixtures éphémères nettoyées dans un `finally` (jamais committées). *(Discriminant : la preuve (a) rougit si le bloc plancher est retiré — c'est sa raison d'être ; le compteur `RESULTAT: N OK, 0 FAIL` passe de 41 à 41+k, k≥2.)*

7. **AC7 — Squelette existant et gates voisins INTACTS (additivité stricte, anti-collateral).** Itération tag-declarers, sélection runner `flutter`/`dart` (`_isFlutterPackage`), `exit 79`→`skipped`, interrupteur, bannière ES-1.4 : INCHANGÉS. `gate:melos-divergence` (miroir melos↔pubspec) intact ; aucun secret introduit ; le gate reste rejouable. *(Discriminant : `melos run analyze` ET `melos run verify` REPO-WIDE verts ; les 41 checks prove_gates préexistants restent `[OK]`.)*

8. **AC8 — Bannière FLOOR BRUYANTE et distincte (R6/ES-1.4), inconditionnelle.** La FLOOR VIOLATION imprime une bannière dédiée (visuellement distincte de la bannière skipped ordinaire) sur `stderr`, nommant CHAQUE package plancher manquant et expliquant le plancher non-optable (R16 : « socle-plancher toujours redevable, sortie interdite »), **émise que l'interrupteur soit posé ou non** (jamais silencieuse). *(Discriminant : la preuve prove_gates asserte `out.contains(<message FLOOR>)` ET `out.contains('zcrud_firestore')` — une dégradation silencieuse échouerait l'assertion.)*

---

## Tasks / Subtasks

- [x] **T1 — Plancher constant + prédicat de sortie (AC1, AC2, AC3, AC8)** dans `scripts/ci/verify_serialization.dart`
  - [x] Déclarer `const Set<String> _floorRequired = {'zcrud_firestore', 'zcrud_generator', 'zcrud_study_kernel'};` (littéral, dartdoc renvoyant à DW-ES35-1/R16).
  - [x] Après construction de `withTests` (INCHANGÉE), calculer `payablePackages = withTests.map((d) => _basename(d.path)).toSet();` et `floorMissing = _floorRequired.difference(payablePackages);`.
  - [x] **Placer ce contrôle AVANT l'early-return `if (withTests.isEmpty) exit(0)` et avant la boucle** (anti-PIÈGE-A). Si `floorMissing` non vide ⇒ bannière FLOOR dédiée (stderr, inconditionnelle) + `exit(1)` inconditionnel.
  - [x] Ajouter une fonction `_floorBanner(Set<String> missing)` (patron `_banner`, message distinct nommant chaque socle + R16).
- [x] **T2 — Option `--packages <dir>` (AC5)**
  - [x] Parser `--packages <dir>` en tête de `main` (défaut `packages`) ; l'utiliser à la place du littéral `'packages'`. Conserver le NO-OP `exit(0)` si le dossier n'existe pas.
  - [x] La comparaison plancher se fait par **basename** (`_basename`) du chemin de package (robuste au préfixe de root de fixture).
- [x] **T3 — Preuve isolée `prove_gates.dart` (AC6, AC8)**
  - [x] Ajouter une section `stdout.writeln('== gate:serialization-floor (ES-4.0, R16) ==');`.
  - [x] `serialization-floor/fixture-exit-population` : fixture packages éphémère VIDE (les 3 socles absents), `verify_serialization.dart --packages <fixture>` via `_verifyNoSwitch` (interrupteur GARANTI absent), assert `exitCode != 0` ET bannière `FLOOR VIOLATION` + les 3 noms de socles.
  - [x] `serialization-floor/contre-epreuve-arbre-reel` : gate sur l'arbre RÉEL (`--packages packages`, les 3 socles présents & taggés) ⇒ assert `exitCode == 0` (plancher muet).
  - [x] Nettoyage de la fixture temp dans le `finally` existant (créée sous `tmp`, jamais committée).
- [x] **T4 — Vérif verte + injections R3 (AC2, AC3, AC4, AC7)**
  - [x] Rejouer `prove_gates.dart` (RC hors pipe) → 43 OK, 0 FAIL (41 → 43).
  - [x] Rejouer `verify_serialization.dart` sous interrupteur sur l'arbre réel → RC=0.
  - [x] `dart analyze` CIBLÉ sur les 2 scripts → RC=0. **`melos run analyze/verify` REPO-WIDE NON rejoué : workstream B (ES-5) résout le workspace en parallèle — rejeu repo-wide délégué à l'orchestrateur au gate de commit (isolation stricte du workstream A).**
  - [x] Dérouler INJ-1..INJ-4 (§ Injections R3), restaurées par édition ciblée (R13).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** capturer le RC via `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail` (renvoie le RC du pipe, pas de la commande gardée). Toute injection dont le rouge est lu à travers un pipe n'a **rien prouvé**.
> **Restauration (R13) :** par **édition ciblée** de retour, JAMAIS `git checkout` (qui masquerait un effet de bord).
> **Runner (R14) :** le run loop du gate choisit `flutter` pour `zcrud_firestore` (paquet Flutter) et `dart` pour `zcrud_generator`/`zcrud_study_kernel` (pur-Dart, cf. Dev Notes) ; le CONTRÔLE PLANCHER est lui STRUCTUREL (pré-exécution), runner-agnostique — ces injections ne dépendent donc pas du runner.

- **INJ-1 — Dents du plancher sur opt-out d'un socle RÉEL (AC2, m1).**
  Édition ciblée : retirer la ligne `serialization-compat:` du bloc `tags:` de `packages/zcrud_firestore/dart_test.yaml`.
  `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart; RC=$?` → **RC=1 attendu**, bannière FLOOR nommant `zcrud_firestore`.
  Restaurer par édition ciblée (ré-ajout de la ligne). *(Sans le plancher, ce même opt-out donnerait RC=0 silencieux — le faux-vert DW-ES35-1.)*

- **INJ-2 — Sortie TOTALE / chemin population vide (AC3, anti-PIÈGE-A).**
  `dart run scripts/ci/verify_serialization.dart --packages "$(mktemp -d)"; RC=$?` (dossier vide, existant) → **RC=1 attendu** (plancher : les 3 socles absents), PAS le NO-OP `exit(0)`. *(Un plancher placé après l'early-return `withTests.isEmpty` donnerait RC=0 : code mort sur le chemin qu'il garde.)*

- **INJ-3 — Opt-in NON-régressé (AC4).**
  (a) Preuve que l'opt-in mord toujours : un tag-declarer **hors-plancher** sans corpus vert → `skipped` → RC=1 **sous l'interrupteur** (comportement ES-3.5 inchangé — vérifié via une fixture `--packages` portant un tag-declarer non-plancher sans test taggé).
  (b) Preuve que le plancher ne s'étend PAS aux non-socles : le même package hors-plancher, **tag retiré**, quitte la population **sans RC=1** (par design opt-in) → RC=0 hors interrupteur. *(Prouve que le plancher est un SUR-ensemble MINIMAL de 3, pas un remplacement de l'opt-in.)*

- **INJ-4 — Retrait du bloc plancher ⇒ faux-vert ré-ouvert (AC2, contre-preuve de charge).**
  Édition ciblée : commenter le bloc `if (floorMissing.isNotEmpty) { … exit(1); }`.
  Rejouer INJ-1 → **RC=0** (l'opt-out du socle passe inaperçu). Rejouer la preuve prove_gates `serialization-floor/fixture-exit-population` → **`[FAIL]`**.
  Restaurer par édition ciblée (dé-commenter). *(Confirme que la preuve committée est NON-POWERLESS : elle rougit quand la garde saute — R12.)*

---

## Vérif verte à rejouer (commandes exactes, RC capturé HORS pipe — R15)

```bash
# 1. Harnais de preuve des gates (doit passer de 41 à ≥43 OK, 0 FAIL)
dart run scripts/ci/prove_gates.dart; echo "prove_gates RC=$?"

# 2. Gate rétro-compat sous interrupteur, arbre réel (plancher muet, socles verts) → RC=0
ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run scripts/ci/verify_serialization.dart; echo "verify RC=$?"

# 3. Contrôle plancher sur chemin population vide (INJ-2) → RC=1
TMPD="$(mktemp -d)"; dart run scripts/ci/verify_serialization.dart --packages "$TMPD"; echo "floor-empty RC=$?"; rmdir "$TMPD"

# 4. Analyse + verify REPO-WIDE (NON-NÉGOCIABLE au gate de commit — détecte les régressions cross-package)
dart run melos run analyze; echo "analyze RC=$?"
dart run melos run verify;  echo "verify  RC=$?"
```

> ⚠️ Ne JAMAIS mesurer un RC via `dart run … | tail` / `| grep` : le pipe renvoie le RC du dernier maillon (R15). Toujours `cmd; RC=$?`.

---

## Dev Notes

### Périmètre & invariants NON-NÉGOCIABLES
- **Fichiers touchés (EXCLUSIVEMENT)** : `scripts/ci/verify_serialization.dart` (plancher + option `--packages`) et `scripts/ci/prove_gates.dart` (preuve isolée). **NE touche AUCUN package `lib/`/`test/` fonctionnel, NI `sprint-status.yaml`, NI `melos.yaml`/`pubspec.yaml`** (le wiring CI d'ES-3.5 reste inchangé).
- **Le squelette existant reste INCHANGÉ** : `_declaresCompatTag` (opt-in D7), `_isFlutterPackage`, itération, `exit 79`→`skipped`, interrupteur, `_banner` ES-1.4. Le plancher est **strictement additif** — un SUR-ensemble minimal garanti, pas un remplacement de l'opt-in.
- **`_floorRequired` littéral** — aucune dérivation (AC1) : une dérivation depuis la population rendrait `difference` toujours vide (POWERLESS).

### Runner par nature du package (R14) — clarification MESURÉE
Le run loop choisit le runner via `_isFlutterPackage` (détection textuelle : `flutter:` sous `dependencies:` avec `sdk: flutter`). **Mesuré sur les pubspecs courants** :
- `zcrud_firestore` → **Flutter** ⇒ `flutter test`.
- `zcrud_generator` → **pur-Dart** ⇒ `dart test`.
- `zcrud_study_kernel` → **pur-Dart** ⇒ `dart test` (son `pubspec.yaml` déclare explicitement « ses tests tournent sous `dart test`, même convention que `zcrud_annotations` » ; ses `dependencies` ne contiennent PAS `sdk: flutter`).

⚠️ **Nuance vs R14 tel que formulé dans le prompt de tâche** (« firestore/kernel = paquets Flutter → flutter test ») : la détection réelle du gate classe `zcrud_study_kernel` en **pur-Dart**. **Ne PAS "corriger" le runner** — le run loop est hors périmètre de cette story, et le CONTRÔLE PLANCHER est structurel (pré-exécution), donc **runner-agnostique**. La seule chose que le plancher vérifie est l'appartenance à la population self-déclarée, jamais l'exécution.

### Anti-pièges (rappel)
- **PIÈGE-A** : contrôle plancher AVANT l'early-return `withTests.isEmpty` (sinon code mort sur le chemin population-vide — cf. bug `exit()`-dans-`try` d'ES-1.4).
- **PIÈGE-B** : `--packages <dir>` indispensable à la preuve isolée (sinon plancher POWERLESS).
- **Isolation prove_gates (R2)** : la fixture de violation exécutée **SANS interrupteur** rend le RC=1 imputable au plancher SEUL (le skip ordinaire est non-fatal hors interrupteur), et `withTests` vide évite toute exécution de suite parasite. Asserter la BANNIÈRE FLOOR (message) en plus du RC pour verrouiller l'isolation.

### Comment DW-ES35-1 est soldée
La sortie silencieuse d'un socle de la population self-déclarée devient un **RC=1 bruyant et inconditionnel**. L'opt-in (D7) reste pour l'évolutivité (nouveaux packages à entité), le plancher garantit qu'un des 3 socles ne peut plus s'auto-exclure (R16). La preuve committée dans `prove_gates.dart` est NON-POWERLESS (rougit si le bloc plancher saute), et l'injection R3 orchestrateur (INJ-1) démontre le rouge provoqué sur un opt-out réel. Après merge : passer la ligne `es-4-0-plancher-gate-serialisation` à `done` et la note DW-ES35-1 (bloc dettes) à ✅ SOLDÉE (édition ciblée du sprint-status par l'orchestrateur — PAS par cette story).

### Project Structure Notes
- `scripts/ci/verify_serialization.dart` : script Dart autonome, sans dépendance de package ; s'exécute au repo root. Conforme au patron des autres gates (`gate_*.dart` prennent tous un `--root`/`--package`).
- `scripts/ci/prove_gates.dart` : harnais « échoue sur violation, passe sinon » ; fixtures ÉPHÉMÈRES nettoyées inconditionnellement (`finally`), `exit(rc)` HORS du `try` (patron déjà en place, ne pas régresser).

### References
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-3-retrospective.md#5 — DÉCISION DW-ES35-1 (OUI plancher) + micro-changement]
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-3-retrospective.md#4 — R14, R15, R16]
- [Source: scripts/ci/verify_serialization.dart#L78-L95 — `_declaresCompatTag` (opt-in D7)]
- [Source: scripts/ci/verify_serialization.dart#L140-L211 — squelette main : population, early-return `withTests.isEmpty`, boucle, interrupteur, bannière]
- [Source: scripts/ci/prove_gates.dart#L196-L828 — patron fixtures éphémères + `finally` + `exit(rc)` hors try]
- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml#L327-L333 — note DW-ES35-1]
- [Source: CLAUDE.md — AD-10 (désérialisation défensive), gates CI, R12 (pouvoir discriminant)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high, workstream A — isolation stricte).

### Debug Log References

Vérifs CIBLÉES (RC hors pipe, R15 ; PAS de melos repo-wide — workstream B ES-5 résolvait le workspace) :

| # | Commande | RC | Résultat |
|---|----------|----|----------|
| 1 | `dart analyze scripts/ci/verify_serialization.dart scripts/ci/prove_gates.dart` | 0 | `No issues` (1 `info` `prefer_interpolation` PRÉEXISTANT l.295, hors périmètre) |
| 2 | `dart run scripts/ci/verify_serialization.dart` (sans env var) | 0 | `verify:serialization OK — corpus vert sur tous les packages` (plancher muet) |
| 3 | `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run …verify_serialization.dart` | 0 | corpus vert, plancher muet |
| 4 | `dart run scripts/ci/prove_gates.dart` | 0 | `RESULTAT: 43 OK, 0 FAIL` (41 → 43 ; +2 = fixture-exit-population + contre-epreuve-arbre-reel) |
| 5 | `dart run …verify_serialization.dart --packages <mktemp -d>` (post-restore) | 1 | FLOOR VIOLATION, 3 socles nommés (floor restauré) |

### Completion Notes List

- **Conception du plancher.** `verify_serialization.dart` — `const Set<String> _floorRequired = {'zcrud_firestore','zcrud_generator','zcrud_study_kernel'}` (littéral en dur, AC1). Prédicat `floorMissing = _floorRequired.difference(payablePackages)` où `payablePackages = withTests.map((d) => _basename(d.path)).toSet()` (basename robuste au préfixe de root de fixture). Si non vide ⇒ `_floorBanner(floorMissing)` (stderr, bannière `FLOOR VIOLATION` distincte nommant CHAQUE socle manquant + R16) puis `exit(1)` **INCONDITIONNEL** (indépendant de l'interrupteur).
- **Anti-PIÈGE-A.** Contrôle plancher placé **AVANT** `if (withTests.isEmpty) exit(0)` et avant la boucle d'exécution ⇒ population vide (3 socles partis) donne RC=1, jamais le NO-OP. Vérifié empiriquement (INJ-2 + INJ-4 : avec le bloc plancher retiré, la même population vide retombe dans le NO-OP `exit(0)` = RC=0).
- **PIÈGE-B / AC5.** Ajout de `--packages <dir>` (défaut `packages`, forme `--packages X` et `--packages=X`) rendant la preuve isolable. `main()` → `main(List<String> args)`. NO-OP `exit(0)` conservé si le dossier n'existe pas.
- **Squelette INCHANGÉ (AC4/AC7).** `_declaresCompatTag`, `_isFlutterPackage`, boucle, `exit 79`→skip, interrupteur, `_banner` ES-1.4 : intacts. `git diff -U0` ne supprime AUCUNE logique opt-in/loop (seuls la signature `main`, le littéral `'packages'`, et la string NO-OP sont remplacés additivement). Le plancher est un SUR-ensemble minimal, pas un remplacement.
- **Preuve isolée (prove_gates.dart).** Section `== gate:serialization-floor (ES-4.0, R16) ==` + helper `_verifyNoSwitch` (copie l'env, RETIRE `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`, `includeParentEnvironment: false`) ⇒ RC=1 imputable au plancher SEUL (skip ordinaire non-fatal hors interrupteur). (a) fixture VIDE ⇒ RC=1 + bannière + 3 socles ; (b) arbre réel ⇒ RC=0 (muet). Fixture sous `tmp`, nettoyée par le `finally` existant. Compteur 41 → 43.
- **Nuance runner (mesurée, non "corrigée").** `zcrud_study_kernel` détecté pur-Dart (`dart test`) par `_isFlutterPackage` — le contrôle plancher est STRUCTUREL (pré-boucle), runner-agnostique ; aucune modif du run loop.
- **Isolation workstream A.** Seuls `scripts/ci/verify_serialization.dart` et `scripts/ci/prove_gates.dart` modifiés (git status confirmé). INJ-1 a temporairement édité `packages/zcrud_firestore/dart_test.yaml` (probe R3) puis l'a **restauré par édition ciblée** (aucun diff résiduel). `melos`/`pubspec.yaml`/`melos.yaml`/`sprint-status.yaml` NON touchés. `sprint-status.yaml` laissé à l'orchestrateur.

**Injections R3 (message/RC EXACT, RC hors pipe) :**

- **INJ-1 — dents sur opt-out d'un socle RÉEL (m1).** Édition ciblée : tag `serialization-compat:` → `__INJ1_serialization-compat:` dans `packages/zcrud_firestore/dart_test.yaml`. `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 dart run …verify_serialization.dart` ⇒ **RC=1**, bannière `❌ FLOOR VIOLATION — SOCLE-PLANCHER HORS POPULATION REDEVABLE`, ligne `- zcrud_firestore`, `RC=1 INCONDITIONNEL`. Restauré par édition ciblée (git diff vide). *(Sans plancher : RC=0 silencieux = faux-vert DW-ES35-1.)*
- **INJ-2 — sortie TOTALE / population vide (anti-PIÈGE-A).** `dart run …verify_serialization.dart --packages "$(mktemp -d)"` ⇒ **RC=1**, bannière FLOOR nommant les **3** socles + `RC=1 INCONDITIONNEL`, PAS le NO-OP `exit(0)`. *(Plancher placé après l'early-return ⇒ RC=0 = code mort.)*
- **INJ-3 — opt-in NON-régressé (sélectivité du plancher).** Fixture `--packages` avec un tag-declarer HORS-plancher `zcrud_decoy` (test/ + tag) présent, SANS interrupteur ⇒ **RC=1** mais la bannière FLOOR nomme **UNIQUEMENT** les 3 socles (`zcrud_firestore`/`zcrud_generator`/`zcrud_study_kernel`), **JAMAIS `zcrud_decoy`** ⇒ prouve que `_floorRequired` = {3 socles} exactement, le plancher ne s'étend PAS à un non-socle (AC4). Complément : diff additif-seulement sur le path opt-in + runs arbre-réel verts (with/without interrupteur → RC=0) qui exercent la machinerie opt-in intacte. *(Un fully-isolated (a) skip→RC=1-sous-interrupteur exigerait des packages fixtures résolvables — impraticable sous le verrou de parallélisation ; le path opt-in est du code ES-3.5 INCHANGÉ, exercé vert sur l'arbre réel.)*
- **INJ-4 — retrait du bloc plancher ⇒ faux-vert ré-ouvert (contre-preuve de charge).** Bloc `if (floorMissing.isNotEmpty){…exit(1);}` commenté ⇒ `dart run …verify_serialization.dart --packages "$(mktemp -d)"` retombe dans `verify:serialization NO-OP — aucun dossier test/` ⇒ **RC=0**. L'assertion prove_gates (a) est `fBad.exitCode != 0` ⇒ RC=0 ⇒ **[FAIL]** (preuve NON-POWERLESS, R12). Restauré par édition ciblée ; empty-fixture repasse à RC=1.

### File List

- `scripts/ci/verify_serialization.dart` (modifié — `_floorRequired`, `_basename`, `_floorBanner`, `--packages`, contrôle plancher pré-early-return)
- `scripts/ci/prove_gates.dart` (modifié — helper `_verifyNoSwitch`, section `gate:serialization-floor`, 2 checks)
