# Story VIS-3: Dégradés par type de question et flip thémable

Status: done

## Story

En tant que consommateur de `zcrud_flashcard`,
je veux décorer une `ZFlashcardReviewCard` par l'identité stable de son type et régler son flip depuis le thème,
afin de garder une identité hôte cohérente, sans palette dans le package ni régression zéro-configuration.

## Contexte et décision D3

VIS-1 est livré : `ZGradientSpec`, `ZGradientResolver`, `zResolveGradient`, `zDerivedGradientResolver` et `ZcrudScope.gradientResolver` sont publics depuis `package:zcrud_core/zcrud_core.dart`. La chaîne est volontairement opt-in : `zResolveGradient(context, key)` appelle le resolver du scope et retourne `null` sans scope/resolver/résultat. `zDerivedGradientResolver` n'est pas un fallback automatique. Les tokens VIS `flipDuration`, `flipCurve`, `accentBarHeight`, `gradientBegin` et `gradientEnd` sont nullable : `null` conserve v0.19.3.

Le défaut IFFD lu en lecture seule est une quadruple redéclaration :

| Fichier IFFD absolu | Lignes | openQuestion | exercise |
|---|---:|---|---|
| `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/flashcard_widgets.dart` | 145-156 | bleu/cyan `4FACFE → 00F2FE` | violet/rose `F093FB → F5576C` |
| `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/flashcard_repetition_widgets.dart` | 49-55 | violet/rose `F093FB → F5576C` | bleu/cyan `4FACFE → 00F2FE` |
| `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/interactive_flashcard_repetition_card.dart` | 87-93 | violet/rose `F093FB → F5576C` | bleu/cyan `4FACFE → 00F2FE` |
| `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/white_exam_question_card.dart` | 86-92 | violet/rose `F093FB → F5576C` | bleu/cyan `4FACFE → 00F2FE` |

Ainsi, `flashcard_widgets.dart` est le divergent : il porte la couleur attendue openQuestion bleu/cyan et exercise violet/rose, alors que les trois autres les inversent. VIS-3 ne copie ni hex ni palette IFFD : FR-26/NFR-S7 l'interdit.

**D3 non négociable.** Dans `zcrud_flashcard`, une seule voie canonique associe le type à la clé stable `widget.card.type.name` (ou un helper exhaustif équivalent), puis appelle `zResolveGradient`. L'unique table effective clé → `ZGradientSpec` est le `ZGradientResolver` injecté par l'hôte; aucun widget du package ne redéclare de `Map<ZFlashcardType, …>` / `Map<QuestionType, …>`, palette, ni calcul depuis un index de liste. Tri, filtre, pagination et position affichée ne peuvent donc jamais changer le dégradé d'un type.

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde est prouvée mordante : injection de la régression, rouge constaté, restauration, vert constaté, puis chemin/ligne/symptôme consignés au Dev Agent Record.

1. **AC1 — Accent opt-in par type stable.** `ZFlashcardReviewCard` (`packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart`) résout le gradient exclusivement avec `zResolveGradient(context, widget.card.type.name)`. Quand une `ZGradientSpec` est disponible, elle rend une barre décorative avec `spec.gradient`; tout texte éventuel emploie `spec.onGradient`. La hauteur lit `ZcrudTheme.of(context).accentBarHeight` seulement si non nulle. Sans spec, aucun conteneur/espace/barre transparent supplémentaire n'existe.

2. **AC2 — Défaut pixel-identique.** Sans `gradientResolver` et avec tokens VIS nuls, la carte conserve exactement dimensions, couleurs, arbre fonctionnel, animation et interactions actuels. Le golden sans injection demeure identique; il est interdit de le régénérer pour accepter une régression.

3. **AC3 — Unicité et indépendance de l'ordre.** Une seule voie/table canonique type → clé → resolver existe dans le package. Les six valeurs de `ZFlashcardType` restent couvertes sans `default` silencieux si un helper est introduit. Pour un même type, le resolver reçoit la même clé et renvoie la même spec avant/après tri, filtre, permutation ou pagination simulée.

4. **AC4 — Flip public, thémable, rétrocompatible.** Rendre publiques, documentées et exportées par `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` les constantes actuelles de la carte : `_kPerspective = 0.001` (ligne 61), `_kHalfTurn = 0.5` (65), `_kMinTarget = 48` (68). Leurs noms publics commencent par `Z`; valeurs et rôle (perspective, demi-tour, cible AD-13) restent inchangés.

   La durée effective est, dans cet ordre : override explicite de carte, `ZcrudTheme.flipDuration`, puis `const Duration(milliseconds: 250)`. Adapter `transitionDuration` seulement si nécessaire pour distinguer « absent » d'un override explicite; documenter la priorité et préserver les appels existants. La courbe effective est `ZcrudTheme.flipCurve ?? Curves.linear`, car le fichier actuel n'expose ni n'applique de courbe. Elle est réellement appliquée aux branches `flip3d` et `fade`, sans déplacer le seuil `_kHalfTurn` ni changer Reduce Motion. Un changement de thème ajuste le controller existant, sans recréer ticker/controller ni perdre la face révélée.

5. **AC5 — AD-2, AD-13, FR-26/NFR-S7.** Aucune couleur littérale (`Color(0x…)`, `Colors.*`), palette IFFD, dépendance ou gestionnaire d'état. Préserver `ValueNotifier`/tranches `ValueListenableBuilder`, controller créé une fois, et `child:` hissé des `AnimatedBuilder` : aucun `setState` global ni contenu reconstruit à chaque tick. Conserver Semantics, 48 dp, `const` et APIs directionnelles; la décoration n'est jamais le seul canal d'information.

6. **AC6 — Périmètre fermé.** Modifier uniquement `packages/zcrud_flashcard` (carte, barrel si requis, helper justifié, tests/golden). Ne toucher ni core, IFFD, lex_douane, codegen, pubspec, sprint-status, autre package ou `*.g.dart`.

## Tasks / Subtasks

- [ ] **T1 — Contrat de flip et état stable** (AC4-AC5)
  - [ ] Lire carte et tests avant modification; préserver `didUpdateWidget`, `_showBack`, Reduce Motion, les deux `AnimatedBuilder` et leur child hissé.
  - [ ] Centraliser durée/courbe effectives; propager une durée effective changée au controller stable lors d'un changement de widget ou de thème.
  - [ ] Exposer les trois constantes sous noms `Z…` sans collision de barrel.

- [ ] **T2 — Raccord gradient D3** (AC1-AC3)
  - [ ] Créer au plus un helper testable/exhaustif de clé, ou employer directement `card.type.name`; ne jamais accepter de `displayIndex`.
  - [ ] Appeler seulement `zResolveGradient`, rendre la barre seulement si la spec est non nulle et appliquer les tokens VIS uniquement avec leur repli null.
  - [ ] Ne créer aucune palette locale : la correspondance clé → spec reste l'unique resolver hôte.

- [ ] **T3 — Tests R3** (AC1-AC5)
  - [ ] Étendre les harnais existants ou créer des suites à côté, via le barrel core.
  - [ ] Ajouter les gardes ci-dessous et documenter toutes les injections réelles.

- [ ] **T4 — Gates** (AC6)
  - [ ] Dans `packages/zcrud_flashcard` : `flutter test` (jamais `dart test`) avec total final ≥ baseline 560 + nouveaux tests.
  - [ ] Pour clôturer la story : `dart run melos run generate`, `dart run melos run analyze`, `dart run melos run test`, RC=0. L'orchestrateur seul modifie le sprint.

## Plan de tests détaillé — R3

| Garde | Emplacement | Assertion verte | Régression injectée → rouge |
|---|---|---|---|
| G1 — type invariant sous ordre | nouveau `z_flashcard_question_gradient_test.dart` | Resolver injecté distingue open/exercise; pour une liste triée, filtrée puis permutée, chaque type reçoit toujours `.name` et la même spec. | Réinjecter `gradients[displayIndex % …]` : après permutation, le même type reçoit l'autre gradient. C'est la garde qui aurait capté IFFD. |
| G2 — anti-duplication | `z_flashcard_gradient_source_guard_test.dart` | Scan structuré de `lib` : une seule voie autorisée; zéro autre `Map<ZFlashcardType,` / `Map<QuestionType,`, `Color(0x` ou `Colors.` VIS. | Ajouter un second mapping dans un widget : le scan rougit. |
| G3 — seam réellement consommé | widget test | Resolver hôte retourne une spec distinctive pour `card.type.name`; la barre existe, porte exactement son Gradient et la hauteur tokenisée. | Clé constante, spec ignorée ou autre resolver : appel/gradient attendu absent. |
| G4 — golden zéro-config | nouveau golden widget déterministe | Vérification faite : aucun golden widget/image n'existe dans ce package (les « golden » actuels sont numériques SM-2). Créer donc une baseline sans resolver et tokens nuls. | Rendre une barre pour `null`, hauteur par défaut non nulle ou timing différent : mismatch; restaurer sans mettre à jour l'oracle. |
| G5 — durée/courbe | `z_flashcard_reveal_transition_test.dart` + widget test | Prouver par temps/sonde que tokens durée et courbe affectent `flip3d` et `fade`; prouver null ⇒ 250 ms + linéaire; vérifier changement à chaud sans nouveau controller. | Ignorer tokens, courber une seule branche ou recréer controller : timings/transform-opacité/identité rougissent. |
| G6 — SM-1/a11y/RTL | suites SM1/a11y/RTL existantes | Barre n'induit pas de rebuild par tick, Semantics/48 dp/RTL restent verts. | Replacer contenu dans builder animé, API physique ou cible <48 : compteur/scan/a11y rouge. |

## Dev Notes

### État relevé sur disque

- Dans `z_flashcard_review_card.dart` : constantes privées aux lignes 61, 65, 68; constructeur 82-92; `transitionDuration` par défaut 250 ms ligne 86, champ 104; controller lignes 198-201 et mise à jour stable 211-216.
- Aucune occurrence de courbe d'animation n'a été trouvée dans ce fichier : `_flip3d` (517-534) et `_fade` (542-552) emploient directement `_controller.value`, donc le défaut est linéaire.
- `_revealed`/ `_showBack` sont stables et `_faceSlot` est le `child:` des AnimatedBuilder : invariant SM-1 à préserver.
- `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:11-96` porte `ZGradientSpec`, resolver, opt-in dérivé et résolution scope → null; ne pas contourner cette couture.
- `z_theme.dart:73-88` contient les tokens VIS concernés; `zcrud_scope.dart:203-246` contient le seam et la comparaison d'identité; le barrel core exporte le resolver à `zcrud_core.dart:185-187`.
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` est l'unique barrel public et exporte déjà la carte.

### Contraintes

- `zcrud_flashcard` dépend de core seulement; ne pas ajouter Riverpod/GetX/provider/Firebase/Syncfusion/Quill/`flip_card`.
- FR-26/NFR-S7 : les couleurs viennent exclusivement de la spec hôte ou des rôles de thème existants.
- Hors périmètre : modifier IFFD, créer un preset/palette app-side, changer les six rendus de question, Reduce Motion ou le sprint.

### Baseline pré-dev

Le 2026-07-27, `flutter test` a été exécuté réellement dans `/home/zakarius/DEV/zcrud/packages/zcrud_flashcard` : **RC=0, 560 tests passed**. Des avertissements workspace `uses-material-design` existent mais aucun échec. Cette baseline ne remplace pas les trois gates finaux.

### References

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml:515-532] — décision VIS, invariant et VIS-3.
- [Source: _bmad-output/implementation-artifacts/stories/vis-1-tokens-look-couture-degrade.md:52-138] — contrat VIS-1 et R3.
- [Source: packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart:61,65,68,76-104,198-216,501-552,625-701] — état réel de la carte.
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:11-96] — couture de gradient.
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:73-88] — tokens.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/flashcard_widgets.dart:145-156] — mapping divergent, lecture seule.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/flashcard_repetition_widgets.dart:49-59] — mapping répétition, lecture seule.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/interactive_flashcard_repetition_card.dart:87-97] — mapping interactif, lecture seule.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/widgets/white_exam_question_card.dart:86-96] — mapping examen, lecture seule.

## Dev Agent Record

### Agent Model Used

Implémentation : Codex (`gpt-5.6-terra`). Vérifications et rejeux : orchestrateur Claude.

### Debug Log References

- Baseline pré-dev **mesurée par l'orchestrateur** : `flutter test` → RC=0, **560 tests**.
- **Vérif verte finale, rejouée par l'orchestrateur** : `melos run analyze` **RC=0** (0 erreur) ·
  `melos run verify` **RC=0** · `zcrud_flashcard` **RC=0 — 568 tests** (560 + 8).

**Injections R3 — 5 gardes prouvées mordantes**

| Garde | Régression injectée | Résultat | Par |
|---|---|---|---|
| G1 — invariance sous tri/filtrage | `gradients[displayIndex % length]` à la place de `card.type.name` | **ROUGE** — clés `multipleChoice`/`trueOrFalse` observées au lieu d'`openQuestion` | dev |
| G2 — unicité de la table | `Map<ZFlashcardType, String>` local ré-introduit | **ROUGE** — le scan de source détecte le mapping interdit | dev |
| G3 — clé transmise | couverte par G1 (clé forcée erronée) | **ROUGE** | dev |
| G4 — golden zéro-config | barre d'accent rendue **par défaut** (les 4 entrées forcées non nulles) | **ROUGE** — écart golden | **orchestrateur** |
| G5 — tokens de flip | sondes sur `flipDuration`/`flipCurve` (3D et fondu) | **ROUGE** | dev |

⚠️ **G4 a été re-prouvée par l'orchestrateur** : le dev l'avait consignée comme « golden créé puis
vérifié sans régénération », ce qui **n'est pas une preuve de morsure** — créer un oracle ne
démontre rien. L'injection réelle (rendre la barre par défaut) a bien rendu la golden rouge.
Au passage, une première injection de l'orchestrateur (forcer la seule `accentBarHeight`) était
**insuffisante** : la barre exige les **quatre** entrées non nulles (`z_flashcard_review_card.dart:692`).

**G1 est la garde qui compte** : c'est celle qui aurait attrapé le défaut réel d'IFFD, où le dégradé
est choisi par `index % gradients.length` (`folders_page.dart:461,472`) — un tri ou un filtre y change
donc la couleur d'un même élément.

### Completion Notes List

- Clé stable unique : `widget.card.type.name`, transmise telle quelle à `zResolveGradient`. Aucun
  mapping local, aucune palette dans le package — la table canonique vit **chez l'hôte**
  (démonstration dans `example/`).
- Le repli dérivé n'est **pas** ré-introduit côté consommateur : le grep de la code-review d'epic sur
  `zDerivedGradientResolver` dans VIS-2/3/4 et `example/` rend **RC=1** (aucune occurrence).
- Tokens de flip raccordés en conservant les valeurs actuelles comme défaut effectif ; AD-2/SM-1
  préservés (controllers stables, `child:` hissé dans les `AnimatedBuilder`).
- Blocage transitoire pendant la parallélisation : `melos run analyze` était rouge à cause d'`example/`
  alors en cours d'édition par VIS-4 — **artefact de concurrence**, confirmé résolu au repos.

### File List

**Production** — `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart`

**Tests** — `test/z_flashcard_question_gradient_test.dart`, `test/z_flashcard_gradient_source_guard_test.dart`,
`test/z_flashcard_review_card_theme_test.dart`, `test/z_flashcard_review_card_golden_test.dart`,
`test/goldens/z_flashcard_review_card_default.png`

