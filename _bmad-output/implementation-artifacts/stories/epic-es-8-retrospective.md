# Rétrospective — Epic ES-8 : Tags & annotations (UI)

- **Skill** : `bmad-retrospective` (VRAI skill, tool `Skill`, préfixe `bmad-*`, invoqué avec succès — **pas de fallback disque**). Exécution en mode subagent non-interactif : l'intention du skill (analyse profonde des stories, continuité avec les rétros ES-6/ES-7, préparation d'ES-9, action items) est suivie, mais le document est produit directement (pas de session party-mode interactive).
- **Périmètre** : ES-8.1 (`zcrud_study/presentation` — `ZTagEditor`/`ZTagChips`) ∥ ES-8.2 (`zcrud_document/presentation` — `ZAnnotationToolbar`/`ZAnnotationPanel`/`ZAnnotationToolController`). Doc hors code : `architecture.md § Deferred` (DW-ES82-1 escaladée) + memlog.
- **Statut réel sur disque** (vérifié) : sprint-status `es-8-1-…: done`, `es-8-2-…: done`, `epic-es-8: in-progress`, `epic-es-8-retrospective: optional`. Épic **COMPLET** (2/2 stories `done`). Cette rétro NE touche NI le code NI `sprint-status.yaml`.

---

## 1. Résumé de l'epic

| Story | Contenu | Vérif verte réelle & code-review |
|---|---|---|
| **ES-8.1** (`zcrud_study`) | `ZTagEditor` (création + dédup par titre normalisé + suppression/purge structurelle + confirmation suggestion IA `ZSuggestedTag`) et `ZTagChips` (affichage, couleur dérivée palette→chip, `usageCount` DÉRIVÉ au rendu). **Adaptateur MINCE** composant des primitives kernel DÉJÀ livrées (`ZFlashcardTag`, `normalizeTagTitle`/`dedupeByNormalizedTitle`, `remapColorKey`/`ZColorPalette`, `orphanTagIds`) + core (`zResolveColorKeyOrSlot`, `ZcrudTheme`). **0 nouvelle arête** (contraste avec ES-7.1). | `flutter test` (R14) **84** RC=0 (19 ES-8.1 + 65 non-régression ES-5/ES-7) ; `dart analyze` scope `zcrud_study` RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0, **42 arêtes (0 delta)**, 20 nœuds ; `melos list`=20. 11/11 injections R3 RED. **APPROVE — 0 HIGH/0 MAJEUR** ; **1 MEDIUM F1 CORRIGÉ** (AC3 aveugle à l'over-purge) ; **1 LOW F2 consigné**. |
| **ES-8.2** (`zcrud_document`) | `ZAnnotationToolbar` (sélection kind + palette colorKey, canal non-coloré, marqueur structurel keyé, contraste WCAG mesuré) + `ZAnnotationPanel` (`ListView.builder` lazy accessible) + `ZAnnotationToolController` (owned/injected). **CŒUR WCAG AD-13** : couleur JAMAIS seul canal (Semantics distinct + marqueur keyé + contraste dérivé mesuré). **Bascule Flutter** de `zcrud_document` (pur-Dart → Flutter). **0 nouvelle arête**. | `flutter test` (R14) **195** RC=0 (dont 25 ES-8.2) ; `dart analyze` scope `zcrud_document` RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0, **0 nouvelle arête**, 20 nœuds ; `melos list`=20. 10 injections R3 côté dev + **5 injections indépendantes rejouées par le reviewer** (toutes RED). **APPROUVÉ — 0 HIGH/0 MAJEUR/0 MEDIUM** (un faux-positif MEDIUM RETIRÉ par test empirique du reviewer) ; **LOW-3 scan corrigé, LOW-1/LOW-2 consignés** ; **DW-ES82-1 escaladée**. |

**Trajectoire** : deux stories menées **EN PARALLÈLE à PACKAGES STRICTEMENT INDÉPENDANTS** (`zcrud_study` ∥ `zcrud_document`), **aucune arête `zcrud_study ↔ zcrud_document`**, aucun symbole partagé hors `zcrud_core`/`zcrud_study_kernel` (déjà `done`). Les deux stories sont vertes, non-régression ES-5/ES-7 (côté study) et domaine `zcrud_document` (sous `flutter test`) à chaque étape.

---

## 2. Ce qui a bien marché (spécifique ES-8)

- **Parallélisation à PACKAGES STRICTEMENT INDÉPENDANTS — la forme la plus simple, et elle a tenu.** Contrairement à ES-7 (« dépendant ∥ dépendance », R23 : `zcrud_study` composait l'API en-mouvement de `zcrud_mindmap`), ES-8 est le cas CLASSIQUE : `zcrud_study` et `zcrud_document` ne partagent **aucune** arête, aucun symbole hors dépendances déjà `done`. Résultat : `create-story` ∥, `dev` ∥ (modulo la fenêtre pub-get ci-dessous), `code-reviews` ∥. Le seul point de contact THÉORIQUE (`zcrud_core`) n'est écrit par **aucune** des deux. C'est le régime de parallélisation le plus sûr et le moins coûteux en garde-fous.
- **R20/R24 INTÉRIORISÉS DÈS LE DEV côté ES-8.1.** ES-8.1 est l'archétype R20 : un adaptateur mince composant des primitives kernel DÉJÀ testées. La story a explicitement REFUSÉ de re-tester `normalizeTagTitle`/`orphanTagIds`/`remapColorKey` en boîte noire (« ce sont des tests kernel — POWERLESS sur le widget ») et a ancré chaque AC sur la **ligne PROPRE au widget** (fil palette→chip, garde de création, composition purge-sur-émission, dérivation du compteur, identité du controller détenu). 11/11 injections RED dès le dev.
- **ES-8.2 : gardes WCAG RÉELLEMENT discriminantes dès le dev — le contre-exemple parfait du motif dominant.** Les 5 gardes a11y les plus piégeuses (contraste mesuré, canal non-coloré, marqueur structurel R24, granularité SM-1, lazy `ListView.builder`) ont été ancrées STRUCTURELLEMENT (`ValueKey(kAnnotationSelectedMarkerKey)`, `wcagContrastRatio` numérique, capture d'identité du controller, `find.byKey` présence/absence). Le **reviewer a rejoué 5 injections INDÉPENDANTES** (P1..P5) neutralisant la ligne de prod — **toutes RED**. « Aucune accessibilité fantôme ».
- **Le reviewer d'ES-8.2 a AUTO-CORRIGÉ un faux-positif MEDIUM par test empirique.** Discipline R12 appliquée à ses PROPRES hypothèses : une garde suspectée powerless a été testée empiriquement (injection), s'est révélée discriminante, et le MEDIUM a été RETIRÉ. C'est la maturité inverse du motif dominant — on ne fait plus confiance à l'intuition « ça a l'air faux » sans neutraliser la ligne de prod pour vérifier.
- **Bascule Flutter d'ES-8.2 exécutée sans nouvelle arête, précédent ES-6.1 réutilisé.** `zcrud_document` passe `sdk: flutter` (pour `ZcrudScope`/widgets) mais les arêtes `→ zcrud_core`/`→ zcrud_study_kernel` PRÉEXISTAIENT ⇒ `graph_proof` delta nul, `melos list`=20. Le patron `zcrud_note` (D2/D4) a servi de gabarit direct ; garde de pureté `source_policy_test.dart` AJOUTÉE (NFR-S10, R13 « ajout jamais suppression »).
- **0 HIGH / 0 MAJEUR sur tout l'epic**, comme ES-7. Un seul MEDIUM (ES-8.1 F1), corrigé et re-prouvé non-powerless.

---

## 3. Ce qui est à améliorer / points de friction (spécifique ES-8)

- **« Packages indépendants » ne suffit PAS pour tout paralléliser — une bascule pubspec/SDK impose une fenêtre SÉRIALISÉE.** Voir § 4 (bilan parallélisation). C'est la leçon structurante d'ES-8, codifiée en **R25**.
- **Récurrence du motif dominant — MEDIUM F1 d'ES-8.1 (AC3 satisfait par des listes VIDES).** Voir § 5. Contraste frappant avec ES-8.2 (gardes WCAG discriminantes dès le dev). Le motif « valide sur EXISTENCE, jamais sur POUVOIR DISCRIMINANT » a resurgi sous une forme NEUVE : non plus l'existence d'un libellé/widget, mais la satisfaction d'un invariant (`orphanTagIds == {}`) par un état DÉGÉNÉRÉ (over-purge → tout vide) — une classe de bug ORTHOGONALE à celle que l'AC prétendait cerner.
- **DW-ES82-1 (perte `gate:web`) — motif RÉCURRENT, pas encore soldé génériquement.** Chaque satellite domaine qui gagne une UI (`zcrud_note` en ES-6.1, `zcrud_document` en ES-8.2) bascule Flutter et sort de `gate:web`. La dette est escaladée story par story, mais la solution GÉNÉRIQUE (runner web pour packages Flutter, ou séparation domaine-pur/présentation-Flutter) reste ouverte — le trou se multiplie.

---

## 4. Bilan de la parallélisation à PACKAGES INDÉPENDANTS + fenêtre bascule Flutter sérialisée

ES-8 est le **premier epic à packages STRICTEMENT indépendants** (ES-7 était « dépendant ∥ dépendance »). Bilan des garde-fous CLAUDE.md :

**Ce qui a été ∥ sans risque :**
- **`create-story` ∥** : aucune information croisée nécessaire, chaque story lit ses propres primitives.
- **`dev` ∥ (modulo la fenêtre pub-get)** : fichiers de code DISJOINTS (`zcrud_study/presentation` vs `zcrud_document/presentation`), zéro co-écriture de `zcrud_core`.
- **`code-reviews` ∥** : une fois le workspace stable, les deux CR sont menées en parallèle sans contamination d'injections R3 (packages disjoints ⇒ aucune fuite de mutation croisée).

**La contrainte qui a PERSISTÉ — une fenêtre SÉRIALISÉE malgré l'indépendance des packages :**
- ES-8.2 fait **basculer `zcrud_document` en package Flutter** (`pubspec.yaml` : `flutter: sdk: flutter` + `dart pub get` sur le **workspace melos partagé**). Or `dart pub get`/`melos bootstrap` opèrent sur le **workspace ENTIER**, pas sur un package isolé.
- ⇒ **RACE bootstrap-vs-pub-get (R17)** : si ES-8.1 (qui n'a besoin d'AUCUNE bascule pubspec) rejoue ses vérifs `flutter test` PENDANT que ES-8.2 réécrit `pubspec.yaml` + `dart pub get`, la résolution du workspace est en mouvement → RED transitoire ou état de lock incohérent.
- **Résolution appliquée** : le **dev d'ES-8.2 (bascule pubspec + pub get) a été SÉRIALISÉ APRÈS le REPOS d'ES-8.1** (workstream study au repos, aucune vérif en vol). Une fois le workspace re-stabilisé (bascule Flutter acquise, `dart pub get` vert, `melos list`=20), les **code-reviews des deux stories ont pu reprendre en ∥** (surface figée).

**Leçon** : l'indépendance des PACKAGES DE CODE (fichiers disjoints, 0 arête croisée) est nécessaire mais **NON suffisante** pour tout paralléliser. Toute opération qui touche l'**état PARTAGÉ du workspace** — bascule `pubspec` (`sdk: flutter`), `dart pub get`/`melos bootstrap`, ajout/retrait de dépendance — impose une **fenêtre SÉRIALISÉE** : la story qui mute le workspace vole SEULE le temps de sa bascule + résolution, les autres workstreams au REPOS, puis reprise ∥ une fois la surface figée. C'est le pendant « workspace partagé » des garde-fous « fichiers disjoints ». Codifié en **R25**.

---

## 5. Le motif dominant — occurrences en ES-8 (« valide sur EXISTENCE, jamais sur POUVOIR DISCRIMINANT »)

Le motif dominant du repo (R12/R13/R18/R20/R24, § 4 des rétros ES-6/ES-7) a de nouveau produit **une occurrence ET un contre-exemple**, avec un contraste instructif.

**Occurrence — MEDIUM F1 d'ES-8.1 (AC3 aveugle à l'over-purge).**
- L'AC3 (« la suppression n'émet AUCUNE référence orpheline ») assérait uniquement (a) `orphanTagIds(refsÉmises, existantsAprès) == {}` et (b) `t` absent de chaque liste émise. **Les deux sont satisfaits par une émission de listes VIDES.** Une régression où la purge retirerait TROP (les références LÉGITIMES `a`/`b` aussi, ex. `for (final l in cards) <String>[]`) resterait **VERTE** : `orphans=∅`, aucun `t` — PASS à tort, alors que toutes les cartes ont perdu leurs tags.
- **Forme NEUVE du motif** : ce n'est pas « un libellé qui survit dans les deux branches » (R24) ni « un composant réutilisé garanti » (R20). C'est un **invariant satisfait par un ÉTAT DÉGÉNÉRÉ** : l'absence-d'orphelin est vraie de façon VACUELLE quand tout est vide. La classe de bug réellement dangereuse (perte silencieuse d'associations carte↔tag) est **ORTHOGONALE** à celle que l'AC prétendait cerner « STRUCTURELLEMENT ».
- **Remédié + verrouillé** : ajout d'une **assertion de PRÉSERVATION EXACTE** — après purge de l'orphelin `t`, `[['t','a'],['b','t'],['a']]` doit devenir **exactement** `[['a'],['b'],['a']]`. Prouvé par l'orchestrateur : injection de sur-purge (`for … <String>[]`) fait ROUGIR la préservation (`Expected [['a'],['b'],['a']], Actual [[],[],[]]`, RC=1) là où l'ancien test restait faussement vert ; restauré → RC=0. Le flanc « valide sur EXISTENCE (absence d'anomalie), pas sur PRÉSERVATION (les données légitimes survivent) » est fermé.

**Contre-exemple — ES-8.2, gardes WCAG discriminantes DÈS LE DEV + auto-correction du reviewer.**
- Sur ES-8.2, les 5 gardes a11y les plus piégeuses étaient RÉELLEMENT discriminantes dès le dev (10 injections R3 côté dev, dont R3-6/R3-7 reformulées après avoir constaté qu'une 1ʳᵉ formulation échouait à la COMPILATION = proof powerless, reformulées en neutralisations COMPILANTES ⇒ échec sur l'ASSERTION). **Le reviewer a REJOUÉ 5 injections indépendantes (P1..P5) — toutes RED** (spot-check orchestrateur AC4 inclus).
- **Plus fort encore** : le reviewer a **auto-corrigé un faux-positif MEDIUM par test empirique** — il a soupçonné une garde powerless, l'a testée par injection, l'a trouvée discriminante, et a RETIRÉ le MEDIUM. C'est R12 appliqué aux hypothèses du reviewer LUI-MÊME : ne jamais classer un finding « powerless » sur intuition sans neutraliser la ligne de prod pour observer le rouge.

**Leçon actionnable → R26** : un AC qui protège un **invariant de filtrage/purge** (`X == {}`, `orphans vide`, `aucun doublon`) est POWERLESS s'il est satisfait par l'**état DÉGÉNÉRÉ** de l'opération (tout vide / tout supprimé). Toute garde d'une opération qui FILTRE/PURGE doit asserter la **PRÉSERVATION EXACTE des éléments légitimes** (le résultat attendu byte-à-byte : « seul l'orphelin retiré »), **pas seulement l'absence d'anomalie**. Prouver par injection de **sur-purge** (résultat vide) ⇒ RC=1 sur la préservation.

---

## 6. Dettes techniques — état après ES-8

| Dette | Statut | Détail |
|---|---|---|
| **DW-ES81-1** (`usageCount` DÉRIVÉ, non persisté) | 🟡 **OUVERTE (design assumé)** | `ZFlashcardTag` n'a **aucun** champ `usageCount` (AD-19). ES-8.1 le traite comme un compteur DÉRIVÉ au rendu (nb de cartes référençantes) ; AC4 le garde (injection d'un compteur figé ⇒ RC=1). Si un besoin produit exige un `usageCount` PERSISTÉ (cache serveur lex), c'est une écriture kernel + repository (**ES-2/ES-3**), hors périmètre M. À revisiter uniquement sur besoin réel. |
| **DW-ES81-2** (purge PERSISTÉE = repository, ES-3) | 🟡 **OUVERTE (frontière R24 honnête)** | ES-8.1 garantit UNIQUEMENT que l'UI **n'émet aucune référence orpheline** après suppression (composition purge-sur-émission via `orphanTagIds` + `onReferencesPurged` callback). Le retrait effectif de l'`id` des `tagIds` de TOUTES les cartes DANS LE STORE (transaction, `Either`) est le travail de `ZStudyRepository`/adapter — **ES-3**. AC3 est honnête vis-à-vis de ce périmètre (assère l'absence d'orphelin dans le modèle ÉMIS, jamais un effet de store). À solder en ES-3.x. |
| **DW-ES82-1** (perte `gate:web` après bascule Flutter de `zcrud_document`) | ✅ **ESCALADÉE** (`architecture.md § Deferred` l.420) | JUMEAU de DW-ES-6.1-1. `zcrud_document` sort de `gate_web_determinism.dart` (exclut `sdk: flutter`) ⇒ les matrices de coercition JSON déterministe du domaine (`ZAnnotationBounds [0,1]`, `sanitizePage`, `sanitizeExtra`) ne sont plus rejouées sous `dart test -p node`. **Aucune régression** (195 verts sous VM). **Motif RÉCURRENT signalé** : chaque satellite domaine + UI perd `gate:web` — arbitrer une solution GÉNÉRIQUE (runner web pour packages Flutter, ou séparation domaine-pur/présentation-Flutter) avant que le trou ne se multiplie. |
| ES-8.1 LOW F2 (suggestions value-égales fusionnées) | ✅ **CONSIGNÉ** | `_removeSuggestion` retire toutes les `ZSuggestedTag` value-égales ensemble. Choix de design cohérent (value-object sans `id`, unicité par valeur) ; à revisiter si l'unicité par instance devient requise. |
| ES-8.2 LOW-1 (marqueur via `scheme.onSurface` au lieu de `pair.onColor`) | ✅ **CONSIGNÉ** | Code correct et vert partout (AC5 ≥3.0 satisfait). Basculer sur `pair.onColor` risquerait AC5 (compagnon M3 non explicitement max-contraste) ; robustesse optionnelle sur ColorScheme custom. |
| ES-8.2 LOW-2 (double annonce Semantics) | ✅ **CONSIGNÉ** | `Semantics(label/value)` non exclusif au-dessus d'enfants `Text` → verbosité lecteur d'écran (pas de perte a11y). `excludeSemantics`/`MergeSemantics` toucherait l'arbre Semantics (risque de régression) pour un gain de verbosité. |

**Aucune dette bloquante.** Aucun HIGH/MAJEUR sur tout l'epic ; le seul MEDIUM (ES-8.1 F1) est remédié et re-prouvé non-powerless. DW-ES82-1 escaladée (motif récurrent signalé) ; DW-ES81-1/2 = frontière de périmètre honnête vers ES-2/ES-3.

---

## 7. Décisions verrouillées réutilisables pour ES-9+ (suite § 8 d'ES-7)

- **R25 — Une bascule pubspec/SDK d'un package en vol impose une FENÊTRE SÉRIALISÉE, même à packages de code indépendants.** L'indépendance des fichiers de code (0 arête croisée, `presentation` disjointe) ne suffit PAS : toute mutation de l'**état PARTAGÉ du workspace** (bascule `sdk: flutter`, `dart pub get`/`melos bootstrap`, ajout/retrait de dépendance) opère sur le workspace ENTIER. La story qui mute le workspace vole **SEULE** le temps de sa bascule + résolution (autres workstreams au REPOS, aucune vérif `flutter test` en vol — race bootstrap-vs-pub-get R17) ; les code-reviews reprennent en ∥ une fois la surface FIGÉE (`dart pub get` vert, `melos list` stable). Pendant du garde-fou « fichiers disjoints » pour l'axe « workspace partagé ».
- **R26 — Une garde d'opération FILTRE/PURGE doit asserter la PRÉSERVATION EXACTE, pas seulement l'absence d'anomalie.** Un invariant de type `X == {}` / `orphans vide` / `aucun doublon` est satisfait de façon VACUELLE par l'état DÉGÉNÉRÉ de l'opération (tout vide / tout supprimé) — une classe de bug (perte silencieuse) ORTHOGONALE à celle visée. Asserter le **résultat attendu byte-à-byte** (« seul l'orphelin retiré : `[['a'],['b'],['a']]` ») et prouver par injection de **sur-purge** (résultat vide) ⇒ RC=1. Spécialisation du motif dominant au sous-cas « invariant satisfait par l'état dégénéré ».
- **WCAG STRUCTUREL — patron confirmé load-bearing (ES-8.2).** Pour toute UI accessible future : couleur JAMAIS seul canal via (1) `Semantics.label` NON vide et DISTINCT par option (mesuré `tester.getSemantics`), (2) marqueur de sélection STRUCTUREL non-coloré porté par `ValueKey(...)` (assertion `find.byKey` présence/absence, R24), (3) contraste WCAG **numériquement mesuré** (`wcagContrastRatio` sur les `Color` réellement rendus, seuil ≥ 3.0 composant UI / ≥ 4.5 texte), (4) cibles ≥ 48 dp mesurées (`tester.getSize`), (5) `ListView.builder` prouvé lazy. Rejouer les injections qui neutralisent CHAQUE canal en code-review (pas seulement au dev). Réutilise le patron `ZSrsQualityButtons` (ES-5).
- **Le reviewer applique R12 à ses PROPRES hypothèses (ES-8.2).** Ne jamais classer un finding « powerless » sur intuition : neutraliser la ligne de prod, observer le rouge, et RETIRER le finding si la garde est discriminante. Discipline empirique confirmée.
- **Adaptateur mince à 0 nouvelle arête (ES-8.1) = marqueur de conformité AD-1 le plus simple.** Quand une story compose UNIQUEMENT des primitives déjà en dépendance, `graph_proof` à **delta nul** (42/20 inchangé) est la preuve de conformité la plus directe. Si le dev croit devoir ajouter une arête, c'est une erreur de conception (le symbole visé est déjà exporté par un package en dépendance).
- **Bascule Flutter acquise sur `zcrud_document`.** `zcrud_study`, `zcrud_mindmap`, `zcrud_note`, `zcrud_markdown`, `zcrud_document` sont désormais Flutter (`flutter test`, R14, hors `gate:web`). Les futures stories sur ces packages n'ajoutent aucune nouvelle dette de plateforme.

---

## 8. Préparation ES-9 — recommandations de séquencement / parallélisation

Épic suivant **ES-9** (backlog) — 4 stories : ES-9.1 (seams IA neutres + `ZEducationQuotaInfo` + registre provenance, `zcrud_study`), ES-9.2 (UI examens/rappels, `zcrud_exam`/`zcrud_study`), ES-9.3 (podcasts seam génération, `zcrud_study`), ES-9.4 (communauté/partage optionnel + modération, `zcrud_study`).

- **🔴 CHAÎNE SÉRIELLE STRICTE sur `zcrud_study` — ES-9.1, ES-9.3, ES-9.4 écrivent TOUTES `zcrud_study`.** Sprint-status les marque `SÉQ … NON ∥`. **Une seule story écrivant `zcrud_study` en vol à la fois — JAMAIS deux de ces trois en parallèle.** ES-6/ES-7/ES-8.1 ont validé empiriquement ce point (chaque story de la chaîne study vole SEULE sur son package). Ordre du sprint-status respecté (9.1 → 9.3 → 9.4).
- **ES-9.2 (`zcrud_exam`/`zcrud_study`) : SÉQUENTIELLE aussi.** Elle touche `zcrud_study` ⇒ ne peut PAS voler ∥ avec une autre story `zcrud_study`. Si un nouveau package `zcrud_exam` est créé/basculé Flutter, **appliquer R25** : fenêtre pub-get sérialisée (bascule pubspec + `dart pub get` en solo, autres workstreams au repos) avant reprise.
- **Pas de parallélisation interne à ES-9 sur `zcrud_study`.** Une éventuelle story ES-9 sur un package DISJOINT pourrait voler ∥, mais **PAS deux stories `zcrud_study`**. En cas de doute → séquentiel.
- **Gate d'epic ES-9 : `melos run analyze` ET `melos run verify` REPO-WIDE** (workstreams au repos), pas seulement par-package — leçon `ZExportApi` (une suppression de symbole public cassant un consommateur n'est visible que repo-wide). Un `graph_proof`/`secrets`/`melos list` verts NE remplacent PAS `melos analyze`.
- **Doc `architecture.md` : sérialiser les écritures** (DW-ES72-3, reconduit). Si plusieurs stories ES-9 touchent la doc (§ Deferred, nouveaux AD), écritures ciblées et sérialisées par l'orchestrateur, jamais concurrentes.
- **Dette IA/quota/sécurité anticipée (ES-9.1/9.4).** Les seams IA neutres et le partage communautaire introduiront probablement des dettes de provenance/modération/sécurité lex — les traiter avec le même rigueur R26 (gardes de filtrage/modération = préservation exacte, pas absence d'anomalie).

---

## 9. Transitions de statut (ressort de l'orchestrateur — hors cette rétro)

`epic-es-8-retrospective` (`optional`) → `done` et `epic-es-8` (`in-progress`) → `done`, report des dettes (DW-ES81-1/2 ouvertes vers ES-2/ES-3, DW-ES82-1 escaladée) : **ressort de l'orchestrateur** (écriture ciblée et sérialisée du sprint-status). **Cette rétro NE touche NI le code NI `sprint-status.yaml`.**
