---
baseline_commit: fd83a1b
---

# Story VIS-1 : tokens de look et couture de dégradé injectable

Status: done

<!-- Epic VIS : alignement visuel IFFD par préréglage injectable — story TÊTE et seule écriture dans zcrud_core. -->
<!-- Source de plan : sprint-status.yaml:515-529 ; les dépôts IFFD et lex_douane sont strictement en lecture seule. -->

## Story

As a **développeur d'une application hôte de zcrud**,
I want **des tokens de style incolores et une couture de dégradé neutre, injectables par l'hôte**,
so that **je puisse appliquer un préréglage visuel inspiré d'IFFD sans coupler `zcrud_core` à sa marque, sans couleur codée en dur et sans modifier le rendu existant sans injection**.

**Couvre :** la fondation VIS (taille L, `zcrud_core` seulement). **Dépend de :** rien ; **débloque :** VIS-2, VIS-3 et VIS-4. **Hors périmètre :** consommateurs des tokens, palette décorative exacte IFFD (navy/gold/teal), démo et tout changement dans IFFD/lex. Ces trois sujets appartiennent aux stories suivantes/app hôte.

---

## Décisions tranchées avant dev

### D1 — Architecture hybride à trois couches, pas une palette IFFD dans le cœur

1. Les dimensions, alphas, ratios, durées et courbes sont des tokens `ZcrudTheme` **sans couleur**.
2. Un dégradé est résolu par une couture hôte, avec repli dérivé du `ColorScheme` et sans hex littéral.
3. Les huit paires décoratives exactes IFFD restent **app-side** : jamais dans un package `zcrud`.

FR-26/NFR-S7 interdisent dans le package tout `Colors.*` et `Color(0x…)`. Le repli doit employer exclusivement le `ColorScheme` courant. Sans injection, tout consommateur futur doit continuer à rendre son accent uni actuel : golden v0.19.3 inchangé au pixel près.

### D2 — Les nouveaux tokens sont tous opt-in et conservent l'héritage quand ils sont nuls

`ZcrudTheme` contient actuellement 33 champs orientés formulaire, dont `gapS/M/L`, `radiusS/M` et `badgeRadius`. Les tokens VIS sont ajoutés **nullables** : `null` signifie « le consommateur conserve exactement son comportement v0.19.3 ». Aucun défaut visuel IFFD ne doit être introduit dans `ZcrudTheme.fallback`.

Ce choix est nécessaire au contrat de non-régression et évite de figer des choix de widgets que VIS-2/3/4 appliqueront plus tard. Il implique le traitement spécifique de `lerp` détaillé en T1/AC2.

### D3 — Une clé de dégradé est stable, jamais l'index de l'UI

Une `gradientKey` est une identité persistante/stable : par exemple `questionType.name` ou une clé de dossier persistée. Une liste affichée peut être triée, filtrée ou paginée : **son index ne doit jamais décider du dégradé**.

Pour les domaines study, le bridge applicatif réutilise `ZColorPalette.indexOf(String? raw)` (`packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:182-188`) ; `resolveKey` y remappe une inconnue avec le hash FNV-1a déterministe (`zFnv1a32`, lignes 16-79). `zcrud_core` ne doit ni importer le kernel ni recopier ce hash : il reçoit seulement la clé neutre.

**Anti-modèle explicitement interdit :** IFFD construit `buildFolderItem(FolderModel folder, int index)` (`folders_page.dart:461-462`) puis prend `themeGradients[index % themeGradients.length]` quand le dossier n'a pas de couleur (`:472-478`). Un tri/filtre change donc la couleur du même dossier. Ne pas reproduire ce comportement.

### D4 — Les seams sont immuables et leur identité importe

`ZcrudTheme` n'implémente ni `operator ==` ni `hashCode`; `ZcrudScope.updateShouldNotify` compare les seams avec `identical`. Un préréglage et ses resolvers doivent donc être `const` quand possible, ou mémoïsés hors de `build`; ne jamais créer une nouvelle closure/instance à chaque `build`, sous peine de notifier inutilement tout descendant.

---

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde ci-dessous doit être prouvée mordante : injecter précisément la régression décrite, constater le rouge, restaurer, constater le vert, et consigner chemin/ligne/symptôme dans le Dev Agent Record. Une garde qui reste verte après retrait du correctif est rejetée.

1. **AC1 — Tokens VIS opt-in, complets et exportables.** `ZcrudTheme` expose les tokens incolores suivants, tous `nullable`, documentés avec leur repli `null ⇒ rendu v0.19.3 inchangé` :
   - `accentBarHeight` ;
   - `gradientBegin` et `gradientEnd` de type `AlignmentGeometry?` (valeurs directionnelles attendues par le preset ; pas d'`Alignment.centerLeft/Right`) ;
   - recette d'ombre de carte `cardShadowBlurRadius`, `cardShadowOffset`, `cardShadowAlpha` ;
   - `cardTintAlpha` ;
   - `iconContainerSize`, `iconContainerRadius` ;
   - `countPillPadding` (`EdgeInsetsDirectional?`), `countPillRadius`, `countPillIconSize` ;
   - `celebrationDuration`, `celebrationCurve`, `flipDuration`, `flipCurve`.

   Chaque champ est ajouté aux **quatre endroits réels** de `z_theme.dart` : constructeur (lignes 27-73 aujourd'hui), déclaration/documentation (88-205), `copyWith` (316-386) et `lerp` (389-463). Les types Flutter (`Duration`, `Curve`, `Offset`, `AlignmentGeometry`) restent ceux de Flutter : aucune dépendance, aucune couleur et aucun widget consommateur dans cette story.

2. **AC2 — `lerp` préserve réellement l'héritage nullable.** Pour **chaque** token VIS nullable dont le dartdoc déclare un héritage/repli à `null`, `a.lerp(b, t)` doit renvoyer `null` quand ce token est `null` des deux côtés. Copier strictement le principe du correctif mesuré de `badgeRadius` aux lignes 401-414 : court-circuit explicite `null/null → null`, sinon interpolation/choix approprié des deux valeurs effectives. Ne pas laisser `Radius.lerp`, `AlignmentGeometry.lerp`, `EdgeInsetsDirectional.lerp` ou un choix de courbe matérialiser un défaut et geler l'héritage à la première transition de thème.

   Les scalaires/durées s'interpolent seulement si au moins un côté est fourni, en utilisant la valeur effective définie pour le consommateur; les courbes, non interpolables, choisissent le côté cohérent avec `t` sans jamais convertir `null/null` en valeur. `copyWith()` sans surcharge conserve chaque valeur actuelle.

3. **AC3 — Valeur objet de dégradé contrastée.** Le nouveau fichier voisin `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart` déclare `@immutable class ZGradientSpec` avec `Gradient gradient` et `Color onGradient`, constructeur `const`, égalité/hashCode structurels et dartdoc expliquant que l'hôte choisit le premier plan. Un `Gradient` seul ne permet pas de déduire un contraste fiable; tout appelant reçoit donc les deux.

4. **AC4 — Couture totale, priorité documentée.** Le même fichier expose exactement `typedef ZGradientResolver = ZGradientSpec? Function(ColorScheme scheme, String gradientKey);`, `zResolveGradient(BuildContext context, String gradientKey)` et `zDerivedGradientResolver`. `zResolveGradient` est une chaîne totale et non levante : (1) `ZcrudScope.gradientResolver`, prioritaire ; (2) `null` sinon. `null` est une valeur fonctionnelle : le consommateur garde l'accent uni existant. Une clé vide/inconnue, un scope absent ou un resolver hôte qui retourne `null` ne déclenchent jamais d'exception.

   > ⚠️ **AC4 AMENDÉ EN COURS DE DEV — il contredisait AC9.** La rédaction initiale plaçait `zDerivedGradientResolver` comme repli **automatique** entre (1) et (3). Or ce repli rend un dégradé pour **toute clé non vide** : **mesuré par sonde**, (a) sans aucun `ZcrudScope` la résolution rendait un dégradé au lieu de `null` — l'invariant AC9 « pas d'injection ⇒ rendu identique au pixel près » était donc faux dès le premier consommateur ; (b) un hôte rendant `null` pour signifier « accent uni pour cette clé » voyait sa décision **écrasée**. AC9 étant l'invariant non négociable de l'epic, il l'emporte : le repli dérivé reste public mais devient **opt-in explicite** (`ZcrudScope(gradientResolver: zDerivedGradientResolver)`). Gardes ajoutées pour les deux points.

5. **AC5 — Repli dérivé, aucune couleur littérale.** `zDerivedGradientResolver` dérive un `LinearGradient` depuis le `ColorScheme` par variation HSL de rôles du scheme (et choisit son `onGradient` depuis un rôle `on*` associé), sans `Color(0x…)`, `Colors.*`, table de marque ou dépendance kernel. Il est injecté/typable comme `ZGradientResolver`; son résultat varie réellement entre un `ColorScheme` light et dark. Le fallback ne doit pas prétendre connaître les huit paires IFFD.

6. **AC6 — Pattern existant réutilisé, non réinventé.** L'API, le dartdoc et les garanties de `z_gradient_resolver.dart` suivent le modèle réel de `z_color_key_resolver.dart` : value object fond/premier plan (`ZColorPair`, 52-80), typedef host-side (138-152), fallback dérivé (154-173), puis chaîne de résolution explicite et totale (191-203). Les fonctions de dégradé sont publiques via le barrel sans dupliquer `ZColorSlot`, les clés study ou `ZColorPalette` dans le cœur.

7. **AC7 — Scope câblé et bug latent corrigé.** `ZcrudScope` accepte et expose `ZGradientResolver? gradientResolver`, documenté comme seam immuable, injecté et rétrocompatible (`null` → repli/neutre). L'import de `z_gradient_resolver.dart`, le paramètre constructeur (actuellement 55-75), le champ et `updateShouldNotify` sont mis à jour. Le fichier porte aujourd'hui 17 seams/champs injectés, mais `updateShouldNotify` n'en compare que 15 : il omet les deux seams réels `reorderRenderer` et `dropRegionRenderer` (champs 146/156, absents de la comparaison 222-237 actuelle). Après ajout de `gradientResolver`, il doit comparer les **18** seams par `identical`. Aucun autre comportement du scope ne change.

8. **AC8 — Barrel public cohérent.** `packages/zcrud_core/lib/zcrud_core.dart` exporte `src/presentation/theme/z_gradient_resolver.dart` au voisinage des exports de thème actuels (`z_color_key_resolver.dart`, ligne 185, et `z_theme.dart`, 186). Les symboles publics sont donc utilisables depuis `package:zcrud_core/zcrud_core.dart`; aucun détail privé ne fuit.

9. **AC9 — Défaut pixel-identique et stabilité d'identité.** Sans `gradientResolver` ni tokens VIS injectés, aucun widget existant ne change de branche, de dimensions, d'ombre, d'animation ou de couleur; la golden de référence concernée reste byte/pixel-identique. La documentation/API d'exemple indique qu'un preset est `const` ou mémoïsé hors `build`, cohérent avec `updateShouldNotify` fondé sur l'identité.

10. **AC10 — Architecture du cœur préservée.** Seuls les quatre fichiers de production nommés dans cette story sont modifiés/créés : `z_theme.dart`, `z_gradient_resolver.dart`, `zcrud_scope.dart`, `zcrud_core.dart` (plus tests `zcrud_core`). Pas de package tiers, gestionnaire d'état, dépendance à `zcrud_study_kernel`, couleur littérale, codegen, ni changement app/IFFD/lex.

---

## Tasks / Subtasks

- [ ] **T1 — Étendre `ZcrudTheme` sans modifier le défaut** (AC1, AC2, AC9)
  - [ ] Ajouter les 16 tokens VIS nullables avec dartdoc précis : unité/usage futur, repli `null`, et contrainte directionnelle pour les alignements/padding.
  - [ ] Les raccorder systématiquement dans constructeur, champs, `copyWith` et `lerp`; ne pas toucher à `fallback` sauf nécessité purement non-visuelle démontrée.
  - [ ] Centraliser si utile une minuscule logique privée de lerp nullable pour rendre impossible l'oubli du court-circuit `null/null`; vérifier explicitement chaque champ, pas seulement un helper supposé.

- [ ] **T2 — Créer la couture de dégradé** (AC3-AC6)
  - [ ] Créer `lib/src/presentation/theme/z_gradient_resolver.dart`, avec `library;`, imports minimaux Flutter et `../zcrud_scope.dart`, style de dartdoc/calage sur `z_color_key_resolver.dart`.
  - [ ] Implémenter `ZGradientSpec`, typedef, fallback HSL à partir du `ColorScheme`, puis `zResolveGradient` (scope → fallback → null). Le resolver ne doit jamais lever, même en présence d'une clé inattendue.
  - [ ] Employer uniquement des rôles `ColorScheme` et `HSLColor`; aucune couleur de marque, aucune liste de clés métier, aucun calcul FNV dans `zcrud_core`.

- [ ] **T3 — Câbler le scope et fermer les notifications manquantes** (AC7, AC9)
  - [ ] Ajouter import, argument constructeur, field dartdoc et comparaison `gradientResolver`.
  - [ ] Ajouter aussi `!identical(reorderRenderer, oldWidget.reorderRenderer)` et `!identical(dropRegionRenderer, oldWidget.dropRegionRenderer)` à `updateShouldNotify`; conserver la comparaison d'identité de tous les autres seams.
  - [ ] Dans le dartdoc du nouveau seam, rappeler l'obligation d'une instance stable (`const`/mémoïsée hors build).

- [ ] **T4 — Export public** (AC8, AC10)
  - [ ] Ajouter l'export unique du resolver au barrel, sans ordre ni export parasite.

- [ ] **T5 — Tests R3 et golden** (AC1-AC10)
  - [ ] Étendre `test/presentation/z_theme_test.dart`, `z_color_key_resolver_test.dart` (ou créer l'équivalent `z_gradient_resolver_test.dart`) et `zcrud_scope_test.dart`; utiliser `flutter_test`, jamais `dart test` directement pour ce package Flutter.
  - [ ] Ajouter/étendre uniquement une golden ciblée déjà existante du core, ou créer un harnais déterministe minimal si aucune golden du composant concerné n'existe. La baseline sans injection doit rester inchangée, pas être réacceptée par mise à jour opportuniste.

- [ ] **T6 — Gates de sortie** (AC10)
  - [ ] `dart run melos run analyze` → RC=0.
  - [ ] Depuis `packages/zcrud_core`, `flutter test` → RC=0 et total `>= 1078 + nombre exact de nouveaux tests VIS-1`. Ne pas exécuter `dart test` : il produirait un faux rouge sur `dart:ui`.
  - [ ] Comme c'est une story core, exécuter aussi `dart run melos run generate` puis `dart run melos run test` avant transition finale, conformément à l'AGENTS.md; aucun fichier généré ne doit être édité manuellement.

---

## Plan de tests détaillé — R3

| Garde | Emplacement conseillé | Assertion verte | Régression à ré-injecter, puis rouge attendu |
|---|---|---|---|
| G1 — défaut inchangé | golden ciblée core | Aucun token/scope injecté : image exactement égale à la baseline v0.19.3 | Donner une valeur par défaut non nulle à `accentBarHeight` ou faire consommer un token sans null-check : mismatch golden. Restaurer, ne pas mettre à jour l'oracle. |
| G2 — `lerp` null/null | `z_theme_test.dart` | Deux `const ZcrudTheme()` interpolés gardent **chacun** des tokens VIS `null`; un second lerp après changement d'un token de base ne fige pas l'héritage | Retirer le court-circuit d'un token (p. ex. `iconContainerRadius`) : `Radius.lerp` matérialise un rayon et l'assertion `isNull` rougit. Répéter pour chaque famille/type de token. |
| G3 — `copyWith`/endpoints | `z_theme_test.dart` | `copyWith()` conserve tous les tokens et `lerp(a,b,0/1)` rend les extrêmes prévus lorsqu'une valeur est injectée | Retirer un câblage `copyWith` ou inverser le choix à `t=1` : endpoint/identité rouge. |
| G4 — priorité résolution | `z_gradient_resolver_test.dart` | Un resolver scope renvoyant une spec distinctive pour une clé connue gagne sur le fallback | Remplacer `scope ?? fallback` par le fallback direct : la spec distinctive n'est plus observée. |
| G5 — repli puis null, total | même fichier | Resolver hôte muet : repli dérivé obtenu pour une clé supportée; clé vide/inconnue : résultat `null` ou repli défini, mais **jamais throw** | Faire indexer une table/forcer `first` sans garde sur une clé inconnue : exception et test rouge. |
| G6 — parité light/dark dérivée | même fichier | Pour une même clé supportée, `gradient.colors` et/ou `onGradient` diffèrent réellement entre `ColorScheme` light/dark; aucun besoin de hex dans la prod | Remplacer la dérivation HSL/`ColorScheme` par une valeur figée : les deux résultats deviennent égaux et la garde rougit. |
| G7 — `ZGradientSpec` | même fichier | Égalité/hashCode structurels; le premier plan est porté avec le gradient | Retirer `onGradient` de la spec ou le remplacer par une constante non issue du resolver : compilation/assertion de contraste rouge. |
| G8 — stabilité clé métier | test kernel/bridge consommateur VIS-2/3, préparé comme contrat dans cette story | Une clé persistée garde la même résolution après permutation/filtrage de la liste; le bridge emploie `ZColorPalette.indexOf(stableKey)` et non la position affichée | Réinjecter `displayIndex % gradients.length` à la place de l'identité : après tri, le même dossier/type change de gradient → rouge. Cette garde est à réaliser par le premier consommateur, pas en important le kernel dans core. |
| G9 — scope complet | `zcrud_scope_test.dart` | Chaque seam identique ⇒ `false`; changer isolément `reorderRenderer`, `dropRegionRenderer` ou `gradientResolver` ⇒ `true` | Retirer successivement chaque `identical(...)` : son cas isolé reste faux et le test rougit. |
| G10 — zéro-config | widget test resolver/scope | Scope sans `gradientResolver` expose `null`; résolution sans scope ne lève pas; une instance de preset stable ne provoque pas de notification quand elle est réutilisée | Créer deux closures/instances différentes dans le test de stabilité ou enlever le fallback `maybeOf` : notification inutile/exception, garde rouge. |
| G11 — pureté statique | garde source existante/étendue | Scan des fichiers VIS : zéro `Color(0x`, `Colors.` et zéro import `zcrud_study_kernel` | Réinjecter `Colors.blue` ou l'import kernel : scan rouge. |

Documenter les résultats rouge→vert réels dans le Dev Agent Record, sans les préremplir maintenant.

---

## Dev Notes

### Fichiers et état actuel vérifiés sur disque

- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart`
  - constructeur : lignes 27-73 ; 33 champs actuels; `fallback` ne dérive que les couleurs du thème (75-86) ;
  - champs : 88-205 ; `badgeRadius` documente déjà l'héritage `null ⇒ radiusM` (115-117) ;
  - `copyWith` : 316-386 ; `lerp` : 389-463 ;
  - ne pas manquer le correctif de régression `badgeRadius` 401-414 : il explique le gel différé après une première transition Flutter. C'est le précédent obligatoire pour chaque token VIS nullable à héritage documenté.

- `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart`
  - est le **motif à copier**, pas une API à détourner : `ZColorPair` porte fond+premier plan (52-80), `ZColorKeyResolver` porte `ColorScheme`+clé (138-152), fallback `zDefaultColorKeyResolver` (154-173), chaîne totale scope→fallback→null (191-203).
  - le nouveau fichier est son frère : mêmes garanties de nullabilité/défense/dartdoc, mais aucun `ZColorSlot` ou vocabulaire study copié.

- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart`
  - les seams actuels sont injectés dans le constructeur 55-75 ; `reorderRenderer`/`dropRegionRenderer` sont bien des champs (146/156) ;
  - `updateShouldNotify` (222-237) compare seulement 15 seams : il omet ces deux champs. Ajouter les deux correctifs et le nouveau resolver dans cette story, aucune comparaison structurelle.

- `packages/zcrud_core/lib/zcrud_core.dart:185-191` : emplacement réel des exports de thème/presentation.

- `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:16-79,163-188` : FNV-1a déterministe et signature exacte `int indexOf(String? raw)`. Le kernel reste pur Dart; aucune arête inverse ne peut être ajoutée depuis `zcrud_core`.

### Contraintes d'architecture non négociables

- `zcrud_core` reste le puits du graphe : Flutter seul, aucun package zcrud, Firebase, Syncfusion, Quill, manager ou dépendance de marque.
- `ZcrudScope` est un `InheritedWidget` immuable. Toutes les closures/resolvers injectés ont une identité stable; aucun singleton mutable.
- Préserver l'accessibilité et le RTL : `AlignmentGeometry` et `EdgeInsetsDirectional` en API; les futures utilisations choisissent `AlignmentDirectional`, jamais les variantes gauche/droite physiques.
- Aucun codegen n'est introduit. Ne pas modifier de `*.g.dart`.
- Ne pas ouvrir le périmètre : pas de consommation des tokens dans les widgets, pas de palette IFFD, pas de modification de `sprint-status.yaml` par le dev de cette story sans instruction d'orchestration.

### Structure de projet

**Production modifiée/créée :**

- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` — UPDATE
- `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart` — NEW
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — UPDATE
- `packages/zcrud_core/lib/zcrud_core.dart` — UPDATE

**Tests à créer/mettre à jour :** uniquement sous `packages/zcrud_core/test/presentation/`, en privilégiant les suites existantes `z_theme_test.dart`, `z_color_key_resolver_test.dart` et `zcrud_scope_test.dart`; un `z_gradient_resolver_test.dart` dédié est permis et plus lisible.

### Références

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml:515-529] — décision hybride VIS, séquencement et invariant golden.
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:27-73,115-117,316-414] — quatre raccords et précédent `badgeRadius`.
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:52-80,138-203] — motif exact seam/fallback/chaîne totale à reproduire.
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:55-75,137-156,182-199,222-237] — constructeur, seams et omissions vérifiées.
- [Source: packages/zcrud_core/lib/zcrud_core.dart:185-191] — barrel public.
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:16-79,163-188] — FNV-1a et `indexOf`, à réutiliser côté bridge sans dépendance core→kernel.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/features/folders/pages/folders_page.dart:461-478] — anti-modèle index de liste, LECTURE SEULE.
- [Source: _bmad-output/implementation-artifacts/stories/suf-1-page-shell-searchable-appbar.md, suf-2-carte-dossier.md, suf-3-page-detail-dossier-sous-dossiers-adaptatifs.md] — structure enrichie, décisions vérifiées et discipline R3.

## Dev Agent Record

### Agent Model Used

GPT-5.6-Codex.

### Debug Log References

**Vérif verte finale — REJOUÉE PAR L'ORCHESTRATEUR** (jamais sur la foi du rapport d'agent)
`melos run analyze` **RC=0** · `zcrud_core` `flutter test` **RC=0 — 1086 tests** (1078 baseline + 8).
Structure vérifiée par comptage : `ZcrudTheme` **49 champs** (33 + 16 tokens VIS) ;
`updateShouldNotify` **18 comparaisons** pour 18 seams.

Reprise R3 par l'orchestrateur : le dev avait laissé **10 gardes sur 11 non injectées** (G1 seule
prouvée). Toutes ont été exécutées ensuite ; une garde non prouvée mordante n'est pas une garde.

| Garde | Régression injectée | Résultat |
|---|---|---|
| G1 | `accentBarHeight = 1` au constructeur | **ROUGE** (`Expected: null / Actual: <1.0>`) |
| G2 | court-circuit `null/null` retiré de `_lerpNullableDouble` | **ROUGE** RC=1 |
| G2b | idem sur `_lerpNullableRadius` (`Radius.lerp` matérialise un rayon) | **ROUGE** RC=1 |
| G9a | comparaison `reorderRenderer` retirée d'`updateShouldNotify` | **ROUGE** RC=1 |
| G9b | comparaison `dropRegionRenderer` retirée | **ROUGE** RC=1 |
| G9c | comparaison `gradientResolver` retirée | **ROUGE** RC=1 |
| I1 | repli dérivé ré-introduit dans la chaîne `zResolveGradient` | **ROUGE** RC=1 |
| I2bis | `tertiaryContainer` → `secondaryContainer` (dégradé plat) | **ROUGE** RC=1, écart **0,0392** < seuil 0,05 |
| I3 | `AlignmentDirectional` → `Alignment` physique (RTL) | **ROUGE** RC=1 |

⚠️ **Une injection a d'abord échoué à mordre — et c'était un défaut de MA garde, pas du code.**
Premier essai I2 : ré-introduire la *moyenne* de clarté/saturation ⇒ **VERT**. Mesure faite ensuite :
la moyenne n'était pas la cause du dégradé plat, c'était le **choix des rôles**
(`primary`/`secondary` = 0,039 d'écart RGB contre `primary`/`tertiary` = 0,212 ; la moyenne
n'aggravait que de 0,039 → 0,020). Commentaire de code et seuil corrigés **sur la mesure**, injection
refaite sur le vrai discriminant.

### Completion Notes List

**Deux défauts trouvés APRÈS le dev, que la suite de tests CERTIFIAIT comme corrects.**

1. **AC4 contre AC9 : contradiction réelle, tranchée en faveur d'AC9.** `zResolveGradient` chaînait
   `seam hôte ?? zDerivedGradientResolver(...)`. Le repli rendant un dégradé pour toute clé non vide,
   deux garanties tombaient — **mesuré par sonde** : (a) sans aucun `ZcrudScope`, la résolution rendait
   un dégradé au lieu de `null`, donc l'invariant « pas d'injection ⇒ rendu identique au pixel près »
   était faux dès le premier consommateur (VIS-2) ; (b) un hôte rendant `null` pour signifier « accent
   uni pour cette clé » voyait sa décision **écrasée**, son `null` devenant inexprimable.
   Correctif : chaîne `seam → null`, et `zDerivedGradientResolver` passe en **opt-in explicite**.
   AC9 est l'invariant non négociable de l'epic ; **AC4 est amendé** en conséquence.
2. **Dégradé dérivé visuellement plat** (cf. I2bis) — rôles `ColorScheme` trop voisins.

🔴 **Les tests livrés affirmaient le comportement fautif** : `expect(fromFallback, isNotNull)` et, en
zéro-config, `expect(result, isNotNull)`. La suite était verte **parce qu'**elle encodait le défaut —
un test peut certifier une erreur aussi bien qu'il la détecte. Corrigés, et complétés par quatre
gardes : invariant de non-régression AC9, `null` de l'hôte respecté, anti-aplat réglé sur la mesure,
alignements directionnels AD-13.

Story laissée en **`review`** : par directive owner du 2026-07-27, la code-review multi-lentilles est
unique et se tient en **fin d'epic VIS**, sur les 4 stories à la fois.

### File List

- packages/zcrud_core/lib/src/presentation/theme/z_theme.dart
- packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart
- packages/zcrud_core/lib/src/presentation/zcrud_scope.dart
- packages/zcrud_core/lib/zcrud_core.dart
- packages/zcrud_core/test/presentation/z_theme_test.dart
- packages/zcrud_core/test/presentation/z_gradient_resolver_test.dart
- packages/zcrud_core/test/presentation/zcrud_scope_test.dart
