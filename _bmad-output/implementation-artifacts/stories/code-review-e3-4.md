# Code-review — E3-4 · Sections repliables, champs conditionnels, mode lecture, grille responsive

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, chemin pris = **skill réel** ; step-files `.claude/skills/bmad-code-review/steps/`).
- **Story** : `_bmad-output/implementation-artifacts/stories/e3-4-sections-conditionnels-lecture-grille.md` (16 ACs, statut `review`).
- **Diff revu** : changements non commités depuis `acc6a21` — `z_condition_evaluator.dart` (créé), `z_responsive_grid.dart` (créé), `dynamic_edition.dart` (StatefulWidget), `z_field_spec.dart` (`copyWith`), barrel `zcrud_core.dart`, + 6 tests E3-4.
- **Grounding** : `architecture.md` (AD-2, AD-13, AD-15/AD-1), `prd.md` (FR-3, SM-1, UJ-2), `CLAUDE.md`.
- **Date** : 2026-07-10.

## Verdict : **CHANGES REQUESTED**

Un défaut **MAJEUR reproduit** de place-stabilité/focus dans le chemin **grille + conditionnel** viole AC5/AC6/SM-1 (objectif produit n°1) dans une combinaison de fonctionnalités toutes deux livrées par cette story. Le reste des ACs est correctement satisfait et les gardes CI sont vertes.

## Vérifications RÉELLES rejouées sur disque

| Vérif | Résultat |
|---|---|
| `melos run analyze` | **RC=0** — 14 packages, `SUCCESS`, "No issues found!" partout |
| `melos run test` | **RC=0** — 0 échec ; `zcrud_core` **346**, generator 80, get 17, annotations/provider/riverpod 8 (467 total) |
| `melos run verify` | **RC=0** — `ACYCLIQUE OK`, **`CORE OUT=0 OK`**, `gate:melos/reflectable/secrets/codegen/compat OK` |
| Graphe cœur | `CORE OUT=0` (out-degree 0 préservé, AD-1) |
| `melos list` | **14** packages |
| `git ls-files '*.g.dart'` | **0** committé |
| Directionnel/style (grep) | `z_responsive_grid.dart` / `dynamic_edition.dart` : **0** `EdgeInsets.only`/`fromLTRB`/`Alignment.centerLeft-Right`/`TextAlign.left-right`/`Positioned(`/`Color(0x`/`Colors.` (hors commentaires) ; `ListView.builder` exclusif |

### Preuve adversariale rejouée par AC

- **displayCondition place-stable + 0 recalcul frappe non-garde (AC2/AC3/AC4/AC5)** — VERT (chemin **plat**). `conditional_visibility_test` : dependent apparaît/disparaît via `visibleFields`, réinséré à l'index canonique, slice préservé ; frappe ×20 sur `other` (non-garde) ⇒ `formBuilds` inchangé, voisin `trig` non reconstruit ; garde changeant sans changer la visibilité ⇒ `listEquals` no-op. Le binder s'abonne bien **uniquement** aux `guardFields` (`_bindGuards` sur `zGuardFieldsOf`).
- **Focus `findChildIndexCallback` (AC6)** — VERT **dans le chemin plat** : insertion de `dependent` avant `other` focalisé ⇒ focus conservé (index inverse `Key→position` alimente le sliver paresseux). **KO dans le chemin grille** (cf. MAJEUR-1).
- **Sections a11y / expansion survit (AC7/AC8/AC9)** — VERT. `collapsible_sections_test` : `Semantics(button,expanded,label)`, cible ≥ 48 dp, `EdgeInsetsDirectional` ; repli = masquage visuel, slice conservé ; expansion portée par le `State` parent ⇒ survit à un rebuild structurel ; orthogonal à `visibleFields`.
- **Mode lecture / showIfNull (AC10/AC11)** — VERT. `read_mode_test` : `readOnly` global force `ed.readOnly` par spec effective `copyWith(readOnly:true)` ; `showIfNull:false` masque le vide **en lecture seule**, affiche le renseigné, sans effet en édition. Définition « vide » = `null`+chaîne/collection vide ; `false`/`0` affichés (cohérent doc).
- **Grille par breakpoint + RTL directionnel (AC12/AC13/AC14)** — VERT. `responsive_grid_test` : spans résolus xs..xl (cascade mobile-first, bornage [1,12]), reflow > 12, défaut 12, RTL `start`=droite sans overflow, bascule LTR↔RTL. Domaine/générateur non modifiés (grille = présentation).
- **SM-1 composite (AC15/AC16)** — VERT **pour le scénario testé** : 37 champs / 3 sections + conditionnel + repliable + grille, 100 frappes ⇒ 0 build structurel, focus+curseur préservés. **Attention** : la cible `f_1_5` et le conditionnel `cond` sont ordonnés de sorte que `cond` s'insère **en fin** de section — le cas « insertion **avant** la cible dans une grille » (MAJEUR-1) n'est pas exercé.

## Findings

### MAJEUR-1 — [CONFIRMÉ] Perte de focus/State d'un champ dans une grille quand un conditionnel s'insère AVANT lui (AC5/AC6/SM-1/AD-2)

`z_responsive_grid.dart:188-196` — `ZResponsiveGrid` enveloppe chaque cellule dans un **`SizedBox` NON keyé** (`SizedBox(width:…, child: children[i])`), enfant direct du `Wrap`. La `ValueKey(field.name)` posée par `_buildField` (`dynamic_edition.dart:462`) se retrouve **sous** ce `SizedBox`. `Wrap` (multi-enfant **non paresseux**) réconcilie ses enfants directs (les `SizedBox`) **par position** : les clés n'agissant pas à ce niveau, l'insertion d'une cellule conditionnelle **avant** une cellule focalisée décale les `SizedBox`, dont les `KeyedSubtree` internes ne matchent plus → l'`Element`/`State` du champ focalisé est détruit → **focus + curseur perdus** (la valeur, elle, survit car détenue par le controller).

Le chemin **plat** est protégé par `findChildIndexCallback` (`dynamic_edition.dart:350`) et le chemin **grouped-Column** par des enfants directs keyés — **seul le chemin grille n'a ni l'un ni l'autre**.

**Reproduction (rejouée réellement)** : grille 1 section, ordre canonique `trig`(garde), `dependent`(conditionnel), `target`(focalisé) ; focus sur `target`, puis `setValue('trig','x')` ⇒ `dependent` s'insère à l'index 1 ⇒ **`target.focusNode.hasFocus == false`** (attendu `true`). Test de repro `expect(... isTrue)` → **échec confirmé**.

**Correctif suggéré** : porter la `ValueKey(name)` sur l'enfant **direct** du `Wrap` (le `SizedBox`), p. ex. `ZResponsiveGrid` accepte une liste de clés (ou lit `children[i].key`) et pose `SizedBox(key: ValueKey(name), …)`. Ajouter un test grille « conditionnel inséré avant un champ focalisé ⇒ focus conservé ».

### MEDIUM-1 — [PLAUSIBLE] Blocs du chemin GROUPÉ non keyés + sans `findChildIndexCallback` (AC5/AC6/AD-2)

`dynamic_edition.dart:414-420` — le `ListView.builder` externe du chemin groupé monte des **`blocks` non keyés** et **sans** `findChildIndexCallback`. Quand la composition des blocs se **décale** — bloc « loose » de tête qui apparaît/disparaît (l.369) ou section qui devient vide et est sautée `if (members.isEmpty) continue` (l.383) quand tous ses membres sont masqués par condition/`showIfNull` — le `Column` d'une section est réutilisé **par position** pour une **autre** section ; ses enfants keyés ne matchent plus → State/focus perdus pour les champs des blocs décalés. Même classe de défaut que MAJEUR-1, déclencheur plus large. Non couvert par les tests (le composite garde une composition de blocs stable).

**Correctif suggéré** : keyer chaque bloc (`ValueKey('block:<section-or-loose>')`) et/ou fournir un `findChildIndexCallback` sur le `ListView` externe groupé. Ajouter un test « une section en amont se vide ⇒ focus d'un champ d'une section en aval conservé ».

### LOW-1 — `ZFieldSpec.copyWith` ne peut pas remettre un champ nullable à `null`

`z_field_spec.dart:94-123` — `label`/`config`/`condition`/`defaultValue` utilisent `x ?? this.x` : passer `null` **conserve** l'ancienne valeur (limitation classique de `copyWith`). Sans effet pour l'usage `copyWith(readOnly:true)` d'E3-4, mais piège latent pour de futurs appelants. Consigné (nit).

### LOW-2 — Ajustement exact de largeur de grille sensible à l'arrondi

`z_responsive_grid.dart:185-210` — une rangée dont la somme des spans vaut exactement 12 tient « au pixel » (`colWidth*12 + gutter*11 == width`) ; l'arrondi flottant à certaines largeurs/gouttières non divisibles pourrait provoquer un **wrap parasite** (12 colonnes → 2 rangées). Les tests passent (gutter 0, largeurs divisibles). Robustesse : envisager une marge d'epsilon ou un `Wrap`/`Flow` tolérant. LOW.

### LOW-3 — Réactivité de `showIfNull` en mode lecture

`dynamic_edition.dart:288-292` — en mode lecture, un champ `showIfNull:false` qui passe vide↔renseigné via `setValue` (champ non-garde) n'apparaît/disparaît **pas** tant qu'aucun changement structurel n'a lieu (le builder structurel n'écoute que `visibleFields`+`_collapsed`). Le mode lecture est largement statique ; acceptable, mais à documenter/couvrir. LOW.

### LOW-4 — `condition.field!` dans l'évaluateur

`z_condition_evaluator.dart:43-51` — les feuilles déréférencent `condition.field!` ; la doc promet « ne lève jamais / total ». Non atteignable via les constructeurs publics (qui posent toujours `field` pour une feuille), mais une `ZCondition` mal formée à la main lèverait. Mineur (doc/impl). LOW.

## Trous de couverture identifiés

1. **Grille + conditionnel inséré AVANT un champ focalisé** (→ MAJEUR-1, non testé).
2. **Réordonnancement de blocs groupés** (section en amont qui se vide / bloc loose qui bascule) → focus aval (→ MEDIUM-1, non testé).
3. **Conditionnels chaînés** (C dépend de B, B dépend de A) : l'évaluateur lit la **valeur** brute d'un champ masqué (visibilité non transitive) — choix sémantique non testé au niveau widget.
4. **Condition multi-garde (`and`/`or`)** au niveau du binder (union `guardFields` de 2+ champs) — l'évaluateur est unit-testé, pas l'abonnement widget multi-garde.
5. **`showIfNull` + conditionnel combinés** et **grille en RTL avec conditionnel** — non testés.

## Décisions différées vérifiées (non bloquantes)

- Contrat write-back de valeur externe **documenté mais non câblé** (reporté E3-6/E7) : cohérent — l'état dérivé E3-4 relit `valueOf` à chaque calcul, sans buffer. OK.
