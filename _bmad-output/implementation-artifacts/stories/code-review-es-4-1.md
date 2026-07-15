# Code-Review ES-4.1 — Convergence SM-2 + tests de contrat (revue adversariale, effort high)

**Verdict : APPROUVÉ (done-ready).** 0 HIGH · 0 MAJEUR · 0 MEDIUM · 1 LOW (nit doc).
Le livrable EST un verrou de contrat réel (R12 satisfait), zéro changement de comportement du scheduler de prod (R12/D5), doc AD-22 (AC8) présente et exacte.

## Preuve REJOUÉE sur disque (workstream A, vérifs CIBLÉES)

| Contrôle | Commande | RC |
|---|---|---|
| Contrat seul (22 vecteurs) | `flutter test test/z_sm2_contract_test.dart` | **0** (All tests passed) |
| Suite complète flashcard | `flutter test` | **0** (211 tests) |
| Analyse ciblée | `dart analyze packages/zcrud_flashcard` | **0** (No issues found) |
| Graphe | `graph_proof.py` | **0** (ACYCLIQUE OK, CORE OUT=0 OK, 37 arêtes) |

`git diff packages/zcrud_flashcard/lib/` = **VIDE** en début de revue (scheduler de prod INTACT ; livrable = 1 test + doc AD-22 par l'orchestrateur). Confirmé.

## Le contrat est-il un VERROU (R12) — injections REJOUÉES sur le CODE DE PROD

Rejouées par le reviewer via **édition ciblée** (jamais git checkout), RC capturé HORS pipe (R15) :

- **INJ-1** — `0.1`→`0.11` dans la formule EF (`z_sm2_scheduler.dart` l.54) : **ROUGE, RC=1**. Message capturé : `AC2 … q=3 … EF 2.36 [E] Expected: 2.36 (±1e-9) Actual: <2.37>` (cascade q=2/q=1/q=0). Restauré par édition ciblée → contrat re-vert.
- **INJ-2** — retrait de `* easeFactor` de la branche multiplicative (l.70-72) : **ROUGE, RC=1**. Message : `Expected: <15> Actual: <6> — pas 3 : interval attendu 15` (courbe 1,6,15,38,95 cassée). Restauré → contrat re-vert.
- **Après restauration** : `git diff packages/zcrud_flashcard/lib/` de nouveau **VIDE**, `flutter test test/z_sm2_contract_test.dart` **RC=0**. Le code de prod est bit-identique à l'état initial.

**Golden NUMÉRIQUE, pas tautologie.** Les EF/intervalles attendus sont des **littéraux figés** dans le test (`ef(2.36)`, `ef(2.18)`, `ef(1.96)`, `ef(1.70)` ; `[1,6,15,38,95]` ; plancher exact `1.3` / config-custom exact `1.5` en égalité stricte ; plafond `2.5`), jamais recalculés via le scheduler → le contrat ne peut pas « suivre » une dérive du code. `moreOrLessEquals(1e-9)` absorbe la seule représentation binaire décimale (dérive réelle minimale 0.01 = 100 000× l'epsilon) sans éroder le pouvoir discriminant : INJ-1 (dérive 0.01) rougit bien.

**INJ-5 / défense en profondeur (AC3)** : le vecteur courbe q=5 porte DEUX asserts interval-dépendants (`expect(info.interval, …)` l.146 ET `expect(info.nextReviewDate, kNow+interval j)` l.151) — neutraliser le seul `interval` ne suffit pas à faire passer sous INJ-2, `nextReviewDate` mord aussi. Charge réellement portée (contrat NON décoratif). Cohérent avec la note dev.

## Axes adversariaux (effort high)

1. **Voie d'écriture UNIQUE (AD-9, AC7)** — VÉRIFIÉ. `apply` + `initial` sont les seules productions d'état (lu `z_sm2_scheduler.dart`). `withFolder` (`z_repetition_info.dart` l.194-205) recopie à l'identique TOUS les champs d'ordonnancement (interval/repetitions/easeFactor/nextReviewDate/learnedAt/lastQuality), ne prend aucun paramètre SRS, n'invoque aucun scheduler → relocalisation pure. Le vecteur AC7 (l.298-315) l'assert champ par champ : INJ-4 (mutation `interval+1` dans `withFolder`) rougirait `expect(moved.interval, info.interval)`. `ZRepetitionInfoZcrud` (porteur de `copyWith`) est `hide` au barrel (`zcrud_flashcard.dart` l.132) — aucun setter SRS public.

2. **Bornes EF** — VÉRIFIÉ. Clamp `[config.minEaseFactor ; config.maxEaseFactor]` recalculé à CHAQUE `apply`, lapse compris (l.53-56, hors branche passed/lapse). Le vecteur AC5 config-custom `minEaseFactor:1.5` (égalité stricte l.248) prouve la lecture de config : INJ-1b (littéral `1.3`) le rougirait. Plancher/plafond figés en égalité stricte (`1.3`/`2.5`).

3. **learnedAt** — VÉRIFIÉ. `current.learnedAt ?? (passed ? now : null)` (l.81) : 1re réussite non-null, PRÉSERVÉ sur lapse (jamais re-null). Vecteur AC4 (l.197 `expect(r.learnedAt, kNow)` après `apply(q=2)` depuis état avancé) : INJ-3 le rougirait.

4. **AC8 doc AD-22 (architecture.md l.232-237)** — PRÉSENT et EXACT. Les 5 points figurent : **(i)** parité numérique lex `Sm2` ↔ `ZSm2Scheduler` au régime de défaut, cite `lex_core/.../education/sm2.dart:103-268` + formule/clamp/constantes `1.3/2.5/2.5/1.0/0.5/3` ; **(ii)** overdue NON porté (`overdueBonusFactor` inerte, D3) ; **(iii)** divergence de portée `intervalModifier` (lex tous régimes vs zcrud branche multiplicative, D4) ; **(iv)** gel qualité `0..5` (D6, mapping UI → ES-4.5) ; **(v)** correction de prémisse mesurée (dodlp 0 fichier SRS ; IFFD pas de classe algo isolée, lex `Sm2` EST la variante IFFD). Marqueur `✅ RÉSOLU par ES-4.1 (OQ-S3)` présent l.232.

5. **AC9 défensif (AD-10)** — VÉRIFIÉ. `ZRepetitionInfo.fromMap`/`toMap` (dé)sérialisent TEL QUEL sans scheduler ; le vecteur AC9 round-trip d'un état avancé = identité (`round == info`), et l'état corrompu (`ease_factor:'not-a-number'`, compteurs négatifs) → pas de throw, replis sûrs (`interval 0`, `rep 0`, `easeFactor kDefaultEaseFactor`). Sanitisation prod confirmée (`z_repetition_info.dart` l.115-116). Non-régression, pas de duplication du groupe défensif existant.

6. **AC10 graphe/surface** — VÉRIFIÉ. `graph_proof.py` : ACYCLIQUE, CORE OUT=0, aucune arête ajoutée. Barrel inchangé, `ZRepetitionInfoZcrud`/`ZFlashcardZcrud`/`ZStudyFolderZcrud` toujours `hide`. Aucun `.g.dart` neuf (aucun `@ZcrudModel` modifié). `git status` : seul `z_sm2_contract_test.dart` untracked.

7. **Déterminisme** — VÉRIFIÉ. Horloge fixée `kNow = DateTime.utc(2026,1,1)`, **aucun `DateTime.now()`** dans le test. Distinct de `z_srs_scheduler_test.dart` (propriétés : monotonie/bornes/remplaçabilité) — le contrat porte la TABLE GELÉE (golden), pas de duplication.

8. **Couverture des 10 ACs** — discriminante. AC1 confirmé par les vecteurs AC2-AC5 ; AC2-AC7 golden load-bearing (INJ prouvées) ; AC8 doc bornée par mesures ; AC9/AC10 non-régression vérifiées. **Aucun test POWERLESS détecté.**

## Findings

- **LOW-1 (nit doc, AC8)** — Dans la note AD-22 committée, les points (ii)/(iii)/(iv) décrivent correctement les divergences mais citent le symbole (`overdueBonusFactor`, `defaultIntervalModifier`, clamp `0..5`) sans le `fichier:ligne` zcrud explicite que portaient les Completion Notes de la story (`z_srs_config.dart` l.51-54 ; `z_sm2_scheduler.dart` l.70-72 ; l.49). Le point (i) et (v) citent bien des emplacements mesurés. Substance présente, correcte et vérifiable ; **non bloquant** — consigné, pas de correction requise (l'édition AD-22 relève de l'orchestrateur, pas de la story).

## Conclusion

Story ES-4.1 conforme aux 10 ACs. Le contrat est un verrou EXÉCUTABLE prouvé (2 injections rejouées sur le code de prod → rouge → restaurées, diff `lib/` re-vide, contrat re-vert). Zéro changement de comportement du scheduler (D1/D5 respectés). Doc AD-22 (AC8) présente et exacte. Vérif verte ciblée intégralement verte. **Aucun finding HIGH/MAJEUR/MEDIUM. Prêt pour `done`** (transition sprint-status + `melos analyze`/`verify` REPO-WIDE délégués à l'orchestrateur au gate de commit d'epic, workstream B actif).
