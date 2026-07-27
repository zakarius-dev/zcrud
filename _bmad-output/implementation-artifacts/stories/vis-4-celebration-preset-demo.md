---
baseline_commit: fd83a1b
---

# Story VIS-4 : célébration injectable et préréglage de démonstration

Status: done

<!-- Epic VIS : alignement visuel IFFD par préréglage injectable. VIS-1 est livré et vert ; VIS-4 n'écrit jamais zcrud_core. -->
<!-- Source de plan : sprint-status.yaml:522-532. Le statut de ce fichier est volontairement ready-for-dev ; sprint-status.yaml est hors écriture de cette tâche. -->

## Story

As a **développeur d'une application hôte de zcrud**,
I want **injecter la recette visuelle d'une célébration et disposer d'un préréglage complet dans l'application example**,
so that **je puisse obtenir une expérience « façon IFFD » sans changer le rendu historique, sans importer sa marque ni introduire de couleurs littérales dans les packages**.

**Couvre :** `zcrud_session` et `example/` (taille M). **Dépend de :** VIS-1 (tokens VIS et couture `ZGradientSpec` déjà publics). **Coordination :** VIS-2 modifie en parallèle le second consommateur de `ZStudyProgressRings` dans `zcrud_study` ; VIS-4 ne l'édite pas. **Hors périmètre :** tout changement de `zcrud_core`, de pubspec, de dépendance tierce, de `zcrud_study`, d'IFFD ou de lex_douane.

---

## Décisions tranchées avant dev

### D1 — Défaut historique strictement conservé ; le look IFFD est un opt-in hôte

Sans `ZCelebrationSpec`, token VIS non nul ou préréglage injecté, le rendu est identique au pixel près au comportement actuel : `ConfettiController(Duration(milliseconds: 800))`, `numberOfParticles: 12`, `emissionFrequency: 0.05`, `gravity: 0.3`, `Icons.emoji_events` et halo `BoxShape.circle`. Ce contrat prime toute « amélioration » visuelle ; la golden historique n'est jamais réacceptée.

Le préréglage hôte vise les réglages IFFD vérifiés : durée 5 s, 50 particules, gravité 0.15 et fréquence 0.03. Il est facultatif et ne devient jamais le nouveau défaut de `zcrud_session`.

### D2 — API additive, résolue avec une priorité explicite

Créer dans `z_session_summary_view.dart` la valeur publique, immuable et `const` `ZCelebrationSpec`. La prop publique optionnelle `celebrationSpec` de `ZSessionSummaryView` porte une instance complète ou partielle ; une valeur absente conserve le chemin v0.19.3.

Le spec expose au minimum : durée du burst, nombre de particules, gravité, fréquence d'émission, `IconData?` du trophée, `BoxDecoration?` de son halo, et les quatre pass-through déjà disponibles des anneaux (`diameter`, `strokeWidth`, `trackColorKey`, `progressColorKey`). Les champs optionnels `null` conservent leur valeur historique. Le décor `null` doit spécifiquement reconstruire le `BoxDecoration(color: pair.color, shape: BoxShape.circle)` actuel afin de conserver la couleur résolue et le pixel rendering sans injection.

Ordre de résolution : valeur non nulle du spec → token VIS pertinent de `ZcrudTheme` lorsque défini (`celebrationDuration`, `celebrationCurve`) → constante/comportement existant. La courbe ne doit affecter que l'animation d'entrée existante ; son défaut reste `Curves.elasticOut`/`Curves.easeIn` tel qu'il est aujourd'hui. Aucun `setState` supplémentaire, manager d'état, controller recréé ou changement du latch one-shot/Reduce Motion n'est permis.

### D3 — Réutiliser l'anneau, ne pas l'étendre ni toucher son autre appelant

`ZStudyProgressRings` est déjà paramétrable (défauts : diamètre 96, épaisseur 10, clés `neutral`/`primary`). VIS-4 passe les valeurs du `ZCelebrationSpec` depuis le seul assemblage `ZSessionSummaryView`; le widget anneau et ses défauts ne sont pas modifiés.

Dette différée obligatoire : `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:450` appelle aussi `ZStudyProgressRings(data: data)` sans argument. Il appartient à VIS-2, actuellement en parallèle ; ne pas l'éditer dans VIS-4 afin d'éviter une écriture concurrente cross-story. VIS-2 devra décider et transmettre ses propres paramètres après cette story.

### D4 — Le préréglage est app-side, stable et décoratif seulement

VIS-1 fournit `ZGradientSpec`, `ZGradientResolver`, `zResolveGradient` et la couture `ZcrudScope.gradientResolver`. `zDerivedGradientResolver` reste opt-in : il ne faut pas le transformer en repli automatique. Le preset de `example/` injecte une instance stable (`const`, ou mémoïsée hors `build`) de `ZcrudTheme`, de resolver et de `ZCelebrationSpec`, car `ZcrudTheme` n'a ni `==` ni `hashCode` et `ZcrudScope.updateShouldNotify` compare les seams par `identical`.

Les données IFFD réelles contredisent le brief : `folders_page.dart:51-66` contient **cinq** paires light et **cinq** paires dark, non huit. Reprendre exactement ces cinq paires light/dark dans le seul fichier de preset situé sous `example/`. Elles sont décoratives ; elles ne sont pas la charte IFFD. La charte IFFD, vérifiée séparément dans `app_colors.dart:5-18`, se limite aux rôles navy/gold/teal et ne doit pas être importée ou présentée comme la palette de dégradés.

FR-26/NFR-S7 interdisent `Color(0x...)` et `Colors.*` dans `packages/*`; cette règle ne s'applique pas à `example/`, qui est l'unique emplacement autorisé pour les hex décoratifs de ce preset. `example/` est hors workspace Melos : son gate est `dart run melos run analyze:example`, pas un `melos exec`.

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde doit être prouvée mordante : réinjecter la régression nommée, constater le rouge, restaurer, constater le vert et consigner commande, chemin, ligne et symptôme dans le Dev Agent Record. Une assertion qui reste verte après retrait de sa protection est rejetée.

1. **AC1 — `ZCelebrationSpec` public et additif.** `ZSessionSummaryView` accepte `ZCelebrationSpec? celebrationSpec` sans casser les appelants. Le spec est une valeur `@immutable`, `const`, documentée et exportée par `package:zcrud_session/zcrud_session.dart`; il permet de fournir durée, particules, gravité, fréquence, icône, décor de trophée et les quatre paramètres existants de `ZStudyProgressRings`. Les valeurs `null` sont des replis explicites, jamais des zéros sentinelles.

2. **AC2 — Parité zéro-injection non négociable.** Sans spec ni token VIS injecté, tous les réglages actuels sont réellement transmis au `ConfettiController`/`ConfettiWidget` : 800 ms, 12, 0.05, 0.3 ; l'icône est `Icons.emoji_events` et le halo garde la forme circulaire actuelle. Le comportement existant est préservé : confetti toujours opt-in via `ZSummaryCelebration.confetti`, one-shot, exclu sous Reduce Motion, contrôleurs stables/disposés, couleurs résolues du thème et `ExcludeSemantics`. La golden de référence reste inchangée au pixel près.

3. **AC3 — Injection effective de la célébration.** Avec un `ZCelebrationSpec` distinctif, le burst réel utilise exactement ses valeurs (dont 5 s/50/0.15/0.03 dans le preset example), son `IconData` remplace réellement `emoji_events`, et sa `BoxDecoration` remplace réellement le halo historique. Aucun type `confetti` ne fuit dans l'API publique et `confetti: ^0.8.0` reste la dépendance déjà présente et confinée à `zcrud_session` : aucune dépendance tierce supplémentaire, aucun `pubspec.yaml` modifié.

4. **AC4 — Anneaux réellement transmis depuis le résumé.** Le `ZStudyProgressRings` monté par `z_session_summary_view.dart` reçoit les quatre paramètres du spec ; avec un corpus discriminant, taille, épaisseur et les deux clés rendues diffèrent des défauts 96/10/`neutral`/`primary`. `ZProgressRingsData.fromResult(widget.result)` demeure la source unique des données : ni ratio ni compteur ne sont recalculés dans le résumé.

5. **AC5 — Accessibilité, RTL et réactivité conservés.** Les modifications respectent AD-13 : `Semantics` existantes explicites, confetti décoratif exclu, cibles d'action ≥ 48 dp, widgets `const` lorsque possible et APIs directionnelles. Elles respectent AD-2 : Flutter natif seulement, pas de manager, pas de `setState` à l'échelle du formulaire, pas de controller recréé ni réinjection destructrice de valeur/focus.

6. **AC6 — Préréglage IFFD démontrable, sans identité IFFD importée.** Créer un preset stable dans `example/lib/demos/iffd_visual_preset.dart`, puis le monter au `ZcrudScope` racine dans `example/lib/app.dart` et le transmettre à l'écran de session dans `example/lib/demos/study_session_demo_screen.dart`. Il déclare exactement les 5 paires light et 5 paires dark lues dans IFFD, des `ZGradientSpec` à premier plan contrasté, les tokens VIS (dont durée/courbe) et le `ZCelebrationSpec` IFFD. Le préréglage est bien observé en thème clair et sombre, sans closure/instance recréée à chaque `build`.

7. **AC7 — Documentation de recette.** Créer `docs/recipe-preset-iffd.md` : objectif décoratif, renvoi vers les 5 paires light/dark déclarées dans le preset (sans dupliquer les hex hors `example/`), réglages de célébration, exemple d'injection via les barrels publics, priorité/rôle de `gradientResolver`, stabilité d'identité, et avertissement explicite que la palette décorative n'est pas la charte navy/gold/teal. Le document rappelle que les hex décoratifs n'apparaissent que dans `example/`.

8. **AC8 — Gates et frontières.** `dart run melos run analyze` est RC=0 ; `flutter test` depuis `packages/zcrud_session` est RC=0 avec **au moins 547 tests** (baseline mesurée : 543 ; +4 tests widget R3 VIS-4 attendus, la 5e garde R3 est la compilation de `example/`) ; `dart run melos run analyze:example` est RC=0. Avant `done`, exécuter aussi `dart run melos run generate` et `dart run melos run test` conformément à l'AGENTS.md. Toute anomalie préexistante est distinguée par une preuve avant/après, jamais masquée.

## Tasks / Subtasks

- [x] **T1 — Concevoir et raccorder `ZCelebrationSpec`** (AC1-AC3, AC5)
  - [x] Ajouter la valeur publique et le paramètre optionnel au constructeur de `ZSessionSummaryView`, puis vérifier le barrel `zcrud_session.dart`.
  - [x] Résoudre chaque champ avec les priorités D2, en conservant toutes les branches historique/Reduce Motion/one-shot et l'isolation de `confetti`.
  - [x] Appliquer l'icône et la décoration au trophée sans enlever `Semantics` ni le contraste dynamique `pair.onColor` quand le décor n'est pas injecté.

- [x] **T2 — Passer les paramètres des anneaux dans le seul résumé** (AC4, AC5)
  - [x] Relayer les quatre valeurs au `ZStudyProgressRings` déjà monté en lignes ~405-407.
  - [x] Ne pas modifier `z_study_progress_rings.dart`, ni `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart`; consigner la dette D3.

- [x] **T3 — Écrire les cinq gardes R3 dans le test de résumé existant** (AC1-AC5)
  - [x] Étendre `packages/zcrud_session/test/presentation/z_session_summary_view_test.dart`; tester les propriétés réelles du `ConfettiWidget` et le sous-widget `ZStudyProgressRings`, jamais les constantes internes.
  - [x] Employer un corpus asymétrique et des valeurs distinctives, sans `pumpAndSettle` autour de `ConfettiWidget`.
  - [x] Réinjecter les cinq régressions du plan détaillé et consigner les cinq rouges→verts.

- [x] **T4 — Créer et brancher le preset de démonstration** (AC6, AC7)
  - [x] Créer `example/lib/demos/iffd_visual_preset.dart` avec les seules couleurs hex décoratives de la story, des instances `const`/stables et les variantes light/dark.
  - [x] Raccorder le theme/resolver au `ZcrudScope` racine de `example/lib/app.dart`; préserver ses seams existants, en particulier ceux re-propagés sous les bindings.
  - [x] Passer le spec au `ZSessionSummaryView` dans `example/lib/demos/study_session_demo_screen.dart`, depuis les seuls barrels publics.
  - [x] Créer `docs/recipe-preset-iffd.md` et vérifier que le texte ne confond pas palette décorative et marque.

- [x] **T5 — Gates de sortie** (AC8)
  - [x] Exécuter et consigner les commandes exactes listées dans « Vérification requise » ; ne modifier ni pubspec, ni fichiers générés manuellement, ni `sprint-status.yaml`.

## Plan de tests détaillé — R3

| Garde | Emplacement conseillé | Assertion verte | Régression à ré-injecter, puis rouge attendu |
|---|---|---|---|
| G1 — défaut confetti/icône | `z_session_summary_view_test.dart` | Sans spec/token, le `ConfettiWidget` réel porte **800 ms, 12, 0.05, 0.3** et le `Icon` réel porte `Icons.emoji_events`; le halo observé reste circulaire | Modifier une des constantes (p. ex. 12→13 ou `emoji_events`→une autre icône) : propriété réellement montée différente, test rouge. Ne pas comparer à une constante de production. |
| G2 — paramètres/décor injectés | même fichier | Un spec 5 s/50/0.03/0.15 + décoration distinctive produit exactement ces propriétés réelles et ce décor réel | Ignorer `celebrationSpec` dans `_ConfettiBurst` ou le halo : les valeurs/default circle restent observés, test rouge. |
| G3 — icône substituable | même fichier | Une `IconData` témoin du spec est l'icône réellement montée à la clé `trophyIconKey` | Réintroduire `Icons.emoji_events` en dur : l'icône témoin n'est plus trouvée, test rouge. |
| G4 — pass-through anneaux | même fichier | Un spec avec diamètre/épaisseur/clés distinctifs est reçu par l'instance `ZStudyProgressRings` montée par le résumé et rend les clés attendues | Retirer un argument de l'appel du résumé : le défaut 96/10/`neutral`/`primary` réapparaît, test rouge. |
| G5 — preset example compilable | vérification de compilation, documentée dans le record | Le preset est analysé et le parcours de session l'importe via barrels publics ; `dart run melos run analyze:example` RC=0 | Retirer l'export/import public ou casser un symbole du preset : l'analyse de `example/` échoue. C'est une garde de compilation, pas un test widget artificiel. |

Documenter les résultats rouge→vert réels dans le Dev Agent Record, sans les préremplir maintenant.

## Dev Notes

### Fichiers et état actuel vérifiés sur disque

- `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart` (729 lignes) : `_ConfettiBurst.burstDuration` vaut 800 ms (ligne ~700), `numberOfParticles: 12`, `emissionFrequency: 0.05`, `gravity: 0.3` (lignes ~723-725). Le trophée a `Icons.emoji_events` (ligne ~486) et un `BoxDecoration(... shape: BoxShape.circle)` (lignes ~481-484). `_StatTile` et `_ActionButton` sont privés ; ne pas les promouvoir pour cette story.
- Le même fichier contient déjà le controller confetti stable, le latch `_celebrationFired`, `ExcludeSemantics`, `pauseEmissionOnLowFrameRate: false`, couleurs dérivées de `zResolveColorKeyOrSlot`, et les animations d'entrée. Ce sont des comportements à préserver, pas à réécrire.
- `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:82-108` : constructeur existant `diameter = 96`, `strokeWidth = 10`, `trackColorKey = 'neutral'`, `progressColorKey = 'primary'`; pas de modification de ce fichier.
- Appelants actuels sans arguments : `z_session_summary_view.dart:405-407` et `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:450`. Seul le premier est autorisé ici.
- `packages/zcrud_session/pubspec.yaml:72-95` : `confetti: ^0.8.0` est déjà la deuxième et dernière dépendance tierce de l'epic, explicitement confinée. Toute dépendance supplémentaire est interdite.
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:259-263` porte déjà les tokens nullable `celebrationDuration` et `celebrationCurve`; `zcrud_core.dart` exporte la couture VIS-1. `ZcrudScope.gradientResolver` compare son identité dans `updateShouldNotify`.
- Baseline mesurée le 2026-07-27 : depuis `packages/zcrud_session`, `flutter test` → **RC=0, 543 tests**. Cible attendue après cette story : **547 ou plus** (+4 tests widget R3; la 5e garde R3 est une compilation `example/`).
- IFFD, lecture seule : `flashcards_learning_celebration_page.dart:31-39,103-106` confirme 5 s, 50, 0.03, 0.15. `folders_page.dart:51-66` confirme cinq paires light et cinq paires dark. `app_colors.dart:5-18` confirme navy/gold/teal distincts. Aucun fichier IFFD/lex n'est modifiable.

### Fichiers à toucher / réutiliser

| Action | Chemin exact | Rôle |
|---|---|---|
| Modifier | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart` | `ZCelebrationSpec`, résolution et pass-through anneaux. |
| Modifier | `packages/zcrud_session/test/presentation/z_session_summary_view_test.dart` | Les 4 gardes widget R3. |
| Créer | `example/lib/demos/iffd_visual_preset.dart` | Palette décorative exacte (5 paires/brightness), resolver/theme/spec stables. |
| Modifier | `example/lib/app.dart` | Injection racine stable dans `ZcrudScope`. |
| Modifier | `example/lib/demos/study_session_demo_screen.dart` | Transmission du spec au résumé avec imports de barrels publics. |
| Créer | `docs/recipe-preset-iffd.md` | Recette et limites de la palette. |
| Ne pas modifier (dette VIS-2) | `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart` | Second appelant des anneaux, hors périmètre pour éviter le conflit parallèle. |

### Contraintes d'architecture non négociables

- AD-1/FR-26/NFR-S7 : aucune couleur littérale, aucun `Colors.*`, aucune dépendance tierce nouvelle dans `packages/*`; les literals décoratifs ne vivent que dans `example/lib/demos/iffd_visual_preset.dart`.
- AD-2/AD-15 : Flutter natif, état à propriétaire unique, controllers stables. Ne pas élargir les rebuilds et ne pas ajouter Riverpod/GetX/provider au package.
- AD-13 : a11y/RTL/const ; couleur jamais seul canal. Le confetti reste décoratif et exclu du canal sémantique.
- API publique par barrel seulement : `example/` n'importe jamais `src/`. Aucun code généré n'est attendu; ne jamais modifier un `*.g.dart` à la main.
- Le scope le plus proche masque les seams : si le preset est re-propagé sous un binding, conserver la même instance de `theme`/`gradientResolver` pour ne pas perdre le preset ni provoquer de notifications inutiles.

### Vérification requise avant `done`

```console
dart run melos run generate
dart run melos run analyze
cd packages/zcrud_session && flutter test
dart run melos run analyze:example
dart run melos run test
```

Résultats attendus : tous RC=0; le test package affiche au moins 547 tests. `analyze:example` est obligatoire même si `melos run analyze` l'appelle déjà : il rend visible la frontière EX-1 et prouve explicitement le preset hors workspace.

### Project Structure Notes

- VIS-1 est la seule story VIS autorisée à écrire `zcrud_core`; VIS-4 le consomme uniquement par son barrel public.
- Le fichier de preset nouveau est volontairement dans `example/lib/demos/`, afin que l'exception décorative reste app-side et visible; `docs/` ne contient que la recette, pas une nouvelle source de couleurs de package.
- `example/` possède déjà le parcours de session et son `ZSessionSummaryView` à `study_session_demo_screen.dart:448-454`; l'étendre est préférable à une seconde démo.
- `sprint-status.yaml` affirme aujourd'hui `vis-4` in-progress, mais il n'est pas touché ici sur instruction explicite. L'orchestrateur sérialisera la transition réelle après dev/review.

### References

- [Source : `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:337-342,405-407,481-489,696-726`]
- [Source : `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:82-129`]
- [Source : `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:450` — dette VIS-2, lecture seule dans VIS-4]
- [Source : `packages/zcrud_session/pubspec.yaml:72-95`]
- [Source : `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:259-263`, `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:203-246`]
- [Source : `example/lib/app.dart:10-12,65-101`, `example/lib/demos/study_session_demo_screen.dart:448-454`, `pubspec.yaml:181-186`]
- [Source lecture seule : `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/pages/flashcards_learning_celebration_page.dart:31-39,103-106`]
- [Source lecture seule : `/home/zakarius/DEV/iffd/lib/src/presentation/features/folders/pages/folders_page.dart:51-66`]
- [Source lecture seule : `/home/zakarius/DEV/iffd/lib/src/config/themes/app_colors.dart:5-18`]
- [Source : `_bmad-output/implementation-artifacts/stories/vis-1-tokens-look-couture-degrade.md` — D1, D4, AC4/AC9 et Completion Notes]
- [Source : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` — AD-1, AD-2, AD-13, AD-15]

## Dev Agent Record

### Agent Model Used

GPT-5 Codex.

### Debug Log References

- G1 (`z_session_summary_view.dart:821`) : `12 → 13` ; test G1 rouge, attendu 12/observé 13 à `z_session_summary_view_test.dart:706`, puis vert après restauration.
- G2 (`:821`) : retrait de `spec?.numberOfParticles ??` ; test G2 rouge, attendu 50/observé 12 à `:751`, puis vert.
- G3 (`:570`) : `Icons.emoji_events` en dur ; test G3 rouge, icône témoin absente à `:773`, puis vert.
- G4 (`:472`) : retrait de `diameter` ; test G4 rouge, attendu 137/observé 96.0 à `:798`, puis vert.
- G5 (`example/lib/demos/iffd_visual_preset.dart:9`) : retrait de l'import barrel session ; `analyze:example` rouge, `ZCelebrationSpec` indéfini à `:21`, puis RC=0 après restauration.
- Gates : generate RC=0, analyze RC=0, session `flutter test` RC=0 (547 tests), analyze:example RC=0, melos test RC=0.

### Completion Notes List

- Story créée prête pour le dev ; aucune implémentation n'est incluse dans cet artefact.
- Le chiffre de huit paires du brief a été corrigé à cinq paires light/dark après vérification IFFD.
- Dette différée : second appelant `ZStudyProgressRings` de `zcrud_study`, propriété de VIS-2.
- `ZCelebrationSpec` est public via le barrel existant, résout spec → tokens VIS → défauts historiques, et ne fuit aucun type `confetti`.
- Le preset app-side est stable, injecte thème/résolveur racine et re-propage le résolveur sous les bindings. Aucun pubspec, fichier généré ni `sprint-status.yaml` n'a été modifié par VIS-4.

### File List

**À créer**

- `example/lib/demos/iffd_visual_preset.dart`
- `docs/recipe-preset-iffd.md`

**À modifier**

- `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart`
- `packages/zcrud_session/test/presentation/z_session_summary_view_test.dart`
- `example/lib/app.dart`
- `example/lib/demos/study_session_demo_screen.dart`
- `example/lib/binding/binding_selector.dart`
- `_bmad-output/implementation-artifacts/stories/vis-4-celebration-preset-demo.md`

**À ne pas modifier**

- `packages/zcrud_session/pubspec.yaml`
- `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart`
- `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart` (dette VIS-2)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Tout fichier sous `/home/zakarius/DEV/iffd` ou `/home/zakarius/DEV/lex_douane`

### Change Log

| Date | Changement |
|---|---|
| 2026-07-27 | Story VIS-4 enrichie créée en `ready-for-dev` : API de célébration additive, pass-through anneaux borné au résumé, preset example stable, recette et plan R3/gates. |
| 2026-07-27 | VIS-4 implémentée : recette injectable, preset example stable, gardes R3 et gates complets verts. |
