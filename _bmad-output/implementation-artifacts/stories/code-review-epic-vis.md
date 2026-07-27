# Code-review adversariale unique — Epic VIS

Date : 2026-07-27. Baseline demandée : `fd83a1b`.

## 1. Périmètre exact revu

Commande exécutée : `git status --short && git rev-parse --verify fd83a1b && git diff --stat fd83a1b && git diff --name-status fd83a1b`.

Résultat : `fd83a1b1ffb53ffa7b1e04fc4f27c7f5de15fbc1` résout correctement ; le diff suivi contient 16 fichiers, 1 556 insertions et 546 suppressions. `git status --short` montre en plus les fichiers VIS non suivis (sources, tests, goldens, stories, recette et preset) ; ils ont été lus eux aussi.

Fichiers de production revus par story :

| Story | Fichiers VIS revus |
|---|---|
| VIS-1 / `zcrud_core` | `z_theme.dart`, `z_gradient_resolver.dart` (nouveau), `zcrud_scope.dart`, `zcrud_core.dart`, tests thème/scope/resolver |
| VIS-2 / `zcrud_study` | `z_folder_card.dart`, `z_folder_card_chrome.dart` (nouveau), `z_subfolder_item_chrome.dart`, barrel, tests et golden VIS-2 |
| VIS-3 / `zcrud_flashcard` | `z_flashcard_review_card.dart`, tests de source/gradient/thème/golden VIS-3 |
| VIS-4 / `zcrud_session` | `z_session_summary_view.dart`, son test, preset `example/`, raccord app/binding/session et `docs/recipe-preset-iffd.md` |

Les quatre stories ont été lues avant jugement : `vis-1-tokens-look-couture-degrade.md`, `vis-2-carte-dossier-accent-badges.md`, `vis-3-degrades-type-question.md`, `vis-4-celebration-preset-demo.md`.

## 2. Exécuté vs seulement lu

### Exécuté

- `python3 _bmad/scripts/resolve_customization.py --skill .claude/skills/bmad-code-review --key workflow` : workflow résolu ; pas d'étape d'activation additionnelle, fait persistant `project-context.md` sans fichier trouvé.
- Lecture complète et application séquentielle de `.claude/skills/bmad-code-review/SKILL.md` puis des annexes `steps/step-01-gather-context.md` à `step-04-present.md`. Trois lentilles ont été exécutées : Blind Hunter, Edge Case Hunter, Acceptance Auditor ; leurs pistes ont été revalidées localement avant triage.
- `git status --short`, `git diff --stat fd83a1b`, `git diff --name-status fd83a1b`, `git diff --check fd83a1b` : arbre/diff inspectés ; `git diff --check` n'a produit aucune sortie (RC=0).
- `git ls-tree -r --name-only fd83a1b -- packages/zcrud_study/test/golden/goldens packages/zcrud_flashcard/test/goldens`, `git status --short -- '*.png'`, `git diff --numstat fd83a1b -- '*.png'` : les PNG suivis préexistants sont `study_tools_sectioned.png` et `z_folder_card_neutral.png`; aucun PNG suivi modifié. Les deux PNG VIS sont non suivis/nouveaux (`z_folder_card_vis2_preset.png`, `z_flashcard_review_card_default.png`).
- `dart run melos run analyze && dart run melos run verify` : RC=0. L'analyse rapporte des `info` préexistants, aucune erreur ; `verify` confirme notamment `CORE OUT=0 OK`, graphe acyclique, reflectable/secrets/codegen/compatibilité verts.
- Greps négatifs exacts :
  - `rg -n -P --glob '*.dart' --glob '!**/test/**' '^(?!\\s*//).*\\b(?:Colors\\.|Color\\s*\\(0x)' packages/zcrud_core/lib packages/zcrud_study/lib packages/zcrud_flashcard/lib packages/zcrud_session/lib; echo "RC=$?"` → aucune ligne, `RC=1`.
  - `rg -n --glob '*.dart' --glob '!**/test/**' 'zDerivedGradientResolver' packages/zcrud_study packages/zcrud_flashcard packages/zcrud_session example; echo "RC=$?"` → aucune ligne, `RC=1`.
  - `rg -n -P --glob '*.dart' --glob '!**/test/**' '^(?!\\s*//).*\\b(?:package:zcrud_study_kernel|package:flutter_riverpod|package:riverpod|package:get/|package:provider/)' packages/zcrud_core/lib; echo "RC=$?"` → aucune ligne, `RC=1`.
- `rg -n 'assert\\(|emissionFrequency|numberOfParticles|gravity' /home/zakarius/.pub-cache/hosted/pub.dev/confetti-0.8.0/lib` : assertions vérifiées dans `src/confetti.dart:35-45` (fréquence, particules, gravité) et `:501` (durée strictement positive).

### Seulement lu

- Sources et tests touchés, avec `nl -ba` pour les références de lignes.
- Les quatre stories, leurs AC, décisions et Dev Agent Records.
- Le code de `confetti` cité ci-dessus (lecture seule dans le cache).

Non rejoué : les quatre suites `flutter test` complètes et `melos run test`; l'orchestrateur les avait annoncées vertes. Cette revue ne leur attribue pas une exécution propre.

## 3. Invariants HIGH

### 1. Neutralité sans injection — conforme

`zResolveGradient` retourne la valeur nullable du seam seulement (`packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:91-96`), les consommateurs ne créent leur barre qu'avec spec et trois tokens non nuls (`z_folder_card_chrome.dart:23-31`, `z_flashcard_review_card.dart:685-709`). Le test VIS-3 vérifie l'absence de barre sans seam/tokens (`z_flashcard_question_gradient_test.dart:123-137`). Les PNG préexistants n'ont pas été modifiés, preuve Git ci-dessus.

### 2. FR-26/NFR-S7, couleurs littérales — conforme

**Violée dans le périmètre formulé (`packages/*`, y compris tests).** Le grep de production (`lib/` uniquement) retourne bien `RC=1`, mais la commande exécutée `rg -n 'Colors\\.|Color\\s*\\(\\s*0x' packages/zcrud_core/test/presentation/z_gradient_resolver_test.dart packages/zcrud_study/test/presentation/z_folder_card_vis2_test.dart packages/zcrud_study/test/golden/z_folder_card_vis2_golden_test.dart` retourne des littéraux à `z_gradient_resolver_test.dart:9,13`, `z_folder_card_vis2_test.dart:11-12,21` et dans le golden-test VIS-2. Finding HIGH-2.

### 3. AD-1, indépendance de `zcrud_core` — conforme

Le grep négatif des imports `zcrud_study_kernel` et gestionnaires d'état dans `packages/zcrud_core/lib` retourne `RC=1`; `melos run verify` a aussi produit `CORE OUT=0 OK`.

### 4. AD-2, Flutter natif et granularité — conforme dans le diff

La carte flashcard conserve ses notifiers/controllers stables (`z_flashcard_review_card.dart:189-203`, `217-265`) et ses `AnimatedBuilder` avec `child` hissé (`:551-568`, `576-590`). Le résumé limite l'animation d'entrée à son sous-arbre (`z_session_summary_view.dart:523-572`). Aucun import de manager n'est trouvé dans le cœur par le grep négatif du chapitre 2.

### 5. AD-13, sémantique/48dp/RTL — conforme dans le diff

Les badges ont un `Semantics` explicite et une contrainte 48×48 (`z_subfolder_item_chrome.dart:122-153`); les actions flashcard restent à 48dp (`z_flashcard_review_card.dart:647-677`) ; les gradients emploient `AlignmentDirectional` (`z_gradient_resolver.dart:74-82`, `z_folder_card_chrome.dart:35-44`). Les scans ciblés de variantes physiques ont été lus ; aucun ajout VIS physique n'a été constaté.

### 6. AD-10, `zResolveGradient` total/non-levant — **violé**

Le seam est appelé sans protection à `z_gradient_resolver.dart:91-96`. Un resolver hôte qui lève propage l'exception dans le build VIS-2/VIS-3. Finding HIGH-1.

### 7. D3, clé stable et table canonique — conforme pour la production

VIS-2 demande une clé opaque stable (`z_folder_card_chrome.dart:9-19`) et appelle le resolver avec elle (`:29`). VIS-3 emploie uniquement `widget.card.type.name` (`z_flashcard_review_card.dart:685-691`). Le grep de `zDerivedGradientResolver` dans les consommateurs retourne `RC=1`, donc aucun fallback automatique ne contourne la couture. La garde VIS-2 censée prouver cette propriété est toutefois insuffisante : finding MEDIUM-2.

## 4. Points chauds

### a. Arbitrage AC4/AC9 — conforme

Chaîne lue : seam hôte → `null` (`z_gradient_resolver.dart:85-96`). `zDerivedGradientResolver` est public mais opt-in (`:37-58`). Le grep négatif exécuté sur VIS-2/VIS-3/VIS-4/example ne renvoie aucune occurrence de `zDerivedGradientResolver` (`RC=1`).

### b. `ZcrudTheme.lerp`, 16 tokens — conforme

Les 16 valeurs `null/null` sont conservées par les helpers : doubles `:642-643`, offset `:645-648`, radius `:650-653`, padding `:655-665`, alignement `:667-677`, durée `:679-689`, courbes `:691-696`. Les appels couvrent, un par un : `accentBarHeight` `:574-578`; `gradientBegin` `:579-583`; `gradientEnd` `:584`; `cardShadowBlurRadius` `:585-589`; `cardShadowOffset` `:590-594`; `cardShadowAlpha` `:595-599`; `cardTintAlpha` `:600`; `iconContainerSize` `:601-605`; `iconContainerRadius` `:606-610`; `countPillPadding` `:611-615`; `countPillRadius` `:616-620`; `countPillIconSize` `:621-625`; `celebrationDuration` `:626-630`; `celebrationCurve` `:631-635`; `flipDuration` `:636`; `flipCurve` `:637`. Le test couvre les 16 `isNull` (`z_theme_test.dart:80-95`).

### c. `ZcrudScope.updateShouldNotify`, 18 seams — conforme

Les comparaisons `identical` sont exactement aux lignes `zcrud_scope.dart:229-246` : 18 au total, incluant `reorderRenderer` `:240`, `dropRegionRenderer` `:241` et `gradientResolver` `:246`.

### d. Stabilité du preset example — conforme

Le thème est une constante top-level (`iffd_visual_preset.dart:14-19`), la recette de célébration aussi (`:22-32`), et le resolver est une fonction top-level (`:122-139`) passée au scope (`example/lib/app.dart:65-68`), non une closure recréée dans `build`.

### e. VIS-4, défauts célébration — conforme

Les défauts package sont 800 ms (`z_session_summary_view.dart:795-797`), 12 (`:821`), 0,05 (`:822`) et 0,3 (`:823`). Les valeurs IFFD 5 s/50 vivent dans `example/lib/demos/iffd_visual_preset.dart:22-26`.

### f. Tests tautologiques R3 — partiellement violé

La recherche `isNotNull`, `isNull`, `equals` a été exécutée sur les tests VIS. Deux assertions ne protègent pas la régression annoncée : VIS-2 G5 (finding MEDIUM-2) et `a.onGradient isNotNull` (finding LOW-1). Les assertions de neutralité de resolver sont, elles, correctes (`z_gradient_resolver_test.dart:52-59`, `:92-93`, `:164`).

### g. Dette connue hors périmètre — non traitée

`packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:450` appelle `ZStudyProgressRings(data: data)` sans argument. Elle est explicitement hors périmètre, donc sans finding.

## 5. Findings complets

### HIGH

1. **HIGH-1 — Resolver hôte non confiné, `zResolveGradient` peut lever.**
   - Preuve : `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:91-96` appelle directement `gradientResolver?.call(...)`; le test ne couvre qu'un resolver qui retourne `null` (`packages/zcrud_core/test/presentation/z_gradient_resolver_test.dart:24-25,47-59`).
   - Scénario : `ZcrudScope(gradientResolver: (_, key) { if (key == 'inconnu') throw StateError(); return null; })`, puis `ZFolderCardGradientAccent(gradientKey: 'inconnu')` ou une flashcard de ce type. L'exception sort du resolver et casse le build, au lieu de conserver l'accent uni.
   - Correctif proposé, non appliqué : entourer l'appel du seam d'un `try/catch` et retourner `null`; ajouter un widget test avec seam volontairement levant.

2. **HIGH-2 — Couleurs littérales nouvelles sous `packages/*`.**
   - Preuve : `packages/zcrud_core/test/presentation/z_gradient_resolver_test.dart:9,13` introduit `Colors.deepPurple`; `packages/zcrud_study/test/presentation/z_folder_card_vis2_test.dart:11-12,21` et `packages/zcrud_study/test/golden/z_folder_card_vis2_golden_test.dart:7-8,14,35-36` introduisent `Color(0x...)`. Le grep cité au chapitre invariant 2 les retourne littéralement.
   - Scénario : la règle de pureté FR-26/NFR-S7, explicitement demandée sur tout `packages/*`, est déjà contournée par les nouvelles fixtures ; une palette/littéral pourrait ensuite être validé localement au lieu d'être injecté.
   - Correctif proposé, non appliqué : remplacer ces fixtures par des rôles de `ColorScheme`, des valeurs construites via le thème de test ou une injection app-side ; garder les hex exclusivement dans `example/`.

### MAJEUR

1. **MAJEUR-1 — Lerp d'une durée nullable matérialise `Duration.zero` et peut faire tomber le confetti pendant une transition de thème.**
   - Preuve : `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:679-689` remplace un endpoint nul par `Duration.zero`; `:626-637` l'applique à `celebrationDuration` et `flipDuration`. Le résumé consomme cette durée telle quelle à `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:395-402`; confetti exige une durée strictement positive (`confetti.dart:501`). Le test encode l'état fautif avec `expect(base.lerp(changed, 0).accentBarHeight, isZero)` à `z_theme_test.dart:96` et ne couvre pas la durée effective.
   - Scénario : `ThemeData.extensions` anime un thème sans `celebrationDuration` vers le preset 5 s. Au premier interpolat où le token est matérialisé à zéro, une session `confetti` peut construire `ConfettiController(Duration.zero)` et lever son assertion.
   - Correctif proposé, non appliqué : interpoler les durées avec le repli effectif du consommateur (800 ms/250 ms), ou préserver `null` à l'endpoint absent ; ajouter un test ThemeData animé + célébration.

2. **MAJEUR-2 — Le preset IFFD ne rend aucun dégradé VIS dans l'exemple.**
   - Preuve : `example/lib/demos/iffd_visual_preset.dart:14-19` ne fournit ni `accentBarHeight`, ni `gradientBegin`, ni `gradientEnd`; VIS-2 et VIS-3 retournent structurellement sans barre si un de ces tokens est nul (`z_folder_card_chrome.dart:25-31`, `z_flashcard_review_card.dart:685-693`). Le grep exécuté `rg -n 'ZFolderCardGradientAccent|headerDecoration|gradientKey|iffd-folder' example --glob '*.dart'` ne retourne que les déclarations du preset, aucun montage de `ZFolderCardGradientAccent`; le resolver ne reconnaît en outre que `iffd-folder-0..4` (`iffd_visual_preset.dart:126-138`), alors que VIS-3 lui passe `card.type.name` (`z_flashcard_review_card.dart:690`).
   - Scénario : sous thème clair ou sombre, l'écran example de session reçoit le resolver mais aucune barre n'est construite ; les dix dégradés déclarés ne sont observables dans aucun parcours démontré, en violation de VIS-4 AC6.
   - Correctif proposé, non appliqué : injecter les tokens d'accent, raccorder au moins une primitive VIS-2 avec une clé stable, mapper aussi les noms de types si VIS-3 doit être démontrée, puis tester les deux luminosités.

3. **MAJEUR-3 — Les preuves R3 et les records de développement VIS-2/VIS-3 sont absents.**
   - Preuve : les Dev Agent Records de `vis-2-carte-dossier-accent-badges.md:201-213` et `vis-3-degrades-type-question.md:114-127` portent encore « À renseigner » ; les tâches VIS-3 restent non cochées (`:48-62`). Pourtant les AC de ces stories exigent les injections rouge→vert consignées.
   - Scénario : une assertion tautologique ou une garde qui n'a jamais rougi peut être présentée comme protection ; MEDIUM-2 et MEDIUM-4 illustrent déjà ce risque.
   - Correctif proposé, non appliqué : consigner pour chaque garde l'injection, la commande, le symptôme rouge et le vert restauré ; actualiser les tâches/records sans falsifier les preuves.

### MEDIUM

1. **MEDIUM-1 — `ZCelebrationSpec` public accepte des valeurs qui font échouer le résumé.**
   - Preuve : champs non validés à `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:92-137`, transmis au controller `:395-402` et au widget confetti `:821-824`. Le package confetti affirme durée positive à `confetti.dart:501`, et fréquence `[0,1]`, particules `>0`, gravité `[0,1]` à `src/confetti.dart:35-45`.
   - Scénario : `ZCelebrationSpec(burstDuration: Duration.zero)` avec `celebration: confetti` fait échouer l'assertion du `ConfettiController`; `numberOfParticles: 0` ou `gravity: -0.1` échoue à la construction du `ConfettiWidget`.
   - Correctif proposé, non appliqué : normaliser chaque valeur invalide vers le défaut historique (800 ms/12/0,05/0,3), ou valider explicitement puis garantir un repli release ; ajouter les tests limites.

2. **MEDIUM-2 — La garde VIS-2 G5 ne détecte pas la régression indexée qu'elle prétend couvrir.**
   - Preuve : le resolver de test renvoie `_first` seulement pour `folder-a`, `_second` pour toute autre clé (`packages/zcrud_study/test/presentation/z_folder_card_vis2_test.dart:14-22`). Après permutation, les assertions ne vérifient que l'égalité avant/après (`:159-198`). Si la production transmet `displayIndex`, `folder-a` reçoit `_second` avant et après la permutation et ces assertions restent vertes.
   - Scénario : remplacer `gradientKey` par une clé d'index constante/normalisée dans le chemin testé ; le test conserve son résultat malgré la perte d'identité stable.
   - Correctif proposé, non appliqué : resolver témoin bijectif/journalisant chaque clé et assertions explicites « id → clé reçue → gradient distinct » ; vérifier qu'une injection `displayIndex` rend réellement la garde rouge.

3. **MEDIUM-3 — `ZCountBadge` direct accepte et affiche un compteur nul ou négatif.**
   - Preuve : le constructeur public ne valide pas `count` (`packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:96-110`) ; le filtrage `count > 0` n'existe que dans `ZCountBadgeRow` (`:167-183`).
   - Scénario : un hôte construit directement `ZCountBadge(count: 0, ...)` : un badge « 0 » est rendu, contrairement à la règle d'absence structurelle annoncée par VIS-2 AC6.
   - Correctif proposé, non appliqué : documenter l'invariant et imposer `assert(count > 0)` (ou rendre le widget vide) ; ajouter un test direct.

4. **MEDIUM-4 — La garde de changement de thème VIS-3 ne change pas de thème.**
   - Preuve : les deux pompes de `packages/zcrud_flashcard/test/z_flashcard_review_card_theme_test.dart:43-50` et `:62-69` injectent le même `ZcrudTheme(flipDuration: 800 ms, flipCurve: easeIn)`, puis `:71-75` conclut sur un changement à chaud et sur la stabilité du controller.
   - Scénario : une régression qui recrée le controller seulement lorsque durée/courbe changent reste verte.
   - Correctif proposé, non appliqué : refaire la seconde pompe avec une durée/courbe distinctes et observer simultanément identité du State/controller et cinématique mise à jour.

### LOW

1. **LOW-1 — Assertion R3 impossible à faire rougir.**
   - Preuve : `expect(a.onGradient, isNotNull)` à `packages/zcrud_core/test/presentation/z_gradient_resolver_test.dart:108`, alors que `onGradient` est `required` et non nullable (`packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:13,19`).
   - Scénario : aucun défaut de câblage/contraste n'est détecté : l'assertion reste verte tant que le code compile.
   - Correctif proposé, non appliqué : supprimer cette assertion ou la remplacer par un test consommateur qui observe réellement l'emploi de `spec.onGradient`.

## 6. Verdict global de la story-review

**needs-work.** HIGH-1 viole directement AD-10/AC4 : une donnée hôte invalide ne doit pas pouvoir abattre le rendu. HIGH-2 contrevient à l'interdiction explicite des littéraux dans `packages/*`. Les trois majeurs empêchent en plus de garantir l'animation de thème, la démonstration effective du preset et la preuve R3. La neutralité des PNG préexistants, l'architecture du cœur, la granularité, RTL/a11y et les défauts confetti historiques sont autrement conformes sur le diff examiné.
