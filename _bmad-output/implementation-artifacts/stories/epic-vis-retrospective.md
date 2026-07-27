# Rétrospective — Epic `VIS` (alignement visuel IFFD, thème hybride à trois couches)

- **Skill** : `bmad-retrospective` — fallback disque réellement appliqué : `.claude/skills/bmad-retrospective/SKILL.md`, workflow résolu, configuration et roster chargés ; exécution non interactive, la demande utilisateur déterminant l’epic et le périmètre de sortie.
- **Date** : 2026-07-27 · **Facilitation** : Amelia (Developer). Participants : Zakarius (Project Lead), Amelia (Developer), Dana (QA), Winston (Architect), Alice (PO).
- **Périmètre** : VIS-1 → VIS-4, **4 stories livrées** ; leur statut reste `review` dans `sprint-status.yaml` et `epic-vis` reste `in-progress`. Cette rétro ne les modifie pas, conformément au périmètre imposé.
- **Contraintes de clôture rejouées** : `melos run analyze` **RC=0** · `melos run verify` **RC=0**, dont graphe **ACYCLIQUE** et **CORE OUT=0**. Les suites package annoncées dans les records passent de **1078 → 1086** (`zcrud_core`), **633 → 642** (`zcrud_study`), **560 → 568** (`zcrud_flashcard`) et **543 → 547** (`zcrud_session`).

---

## 1. Ce que l’epic a livré

Le mandat était l’alignement visuel avec IFFD sans faire entrer sa palette de marque dans les packages. La décision retenue — et effectivement compatible avec FR-26/NFR-S7 — est une composition à trois couches : tokens incolores dans le thème, dégradés dérivés du `ColorScheme` sur choix explicite de l’hôte, puis palette décorative exacte déclarée uniquement app-side dans `example/`.

| Story | Livrable | Package |
|---|---|---|
| VIS-1 | 16 tokens incolores nullable, `ZGradientSpec`, `ZGradientResolver`, `zResolveGradient` et seam `ZcrudScope.gradientResolver` | `zcrud_core` |
| VIS-2 | slot `headerDecoration`, `ZFolderCardGradientAccent`, `ZCountBadge` / `ZCountBadgeRow` / `ZCountBadgeSpec` | `zcrud_study` |
| VIS-3 | dégradés de question par clé stable `card.type.name`, tokens de flip | `zcrud_flashcard` |
| VIS-4 | `ZCelebrationSpec`, preset « façon IFFD » app-side et `docs/recipe-preset-iffd.md` | `zcrud_session` + `example/` |

La contrainte structurante a été correctement reformulée en solution technique : les hex IFFD ne sont ni nécessaires ni autorisés dans `packages/*`. Environ 80 % du rendu recherché est formé de dimensions, alphas et ratios ; les cinq paires de dégradés de dossiers ne sont pas la palette de marque navy/gold/teal. Cela a évité une fausse parité qui aurait cassé l’architecture.

---

## 2. Qualité — revue unique de fin d’epic

La directive owner a retiré **à la fois** la revue par story et le dispositif multi-lentilles : une revue unique, menée par un seul agent, a conclu à **2 HIGH / 3 MAJEUR / 4 MEDIUM / 1 LOW**.

Deux corrections de tri sont importantes pour une lecture honnête du résultat :

- **HIGH-2 rejeté** : appliquer FR-26 aux tests ne constitue pas une règle tenable dans l’état réel du dépôt ; 22 fichiers de test préexistants emploient déjà des couleurs littérales. L’invariant réellement tenu porte sur la production des packages, où les couleurs IFFD ne sont pas entrées.
- **HIGH-1 requalifié** : la couture jumelle `zResolveColorKey` partage le comportement signalé pour `zResolveGradient`. Ce n’est donc pas une régression introduite par VIS ; la dartdoc promettait plus que le contrat établi. Le défaut de documentation et la robustesse attendue restent à traiter, sans attribuer faussement une régression à VIS.

La revue a néanmoins apporté des défauts matériels que les tests avaient manqués :

- `zResolveGradient` enchaînait le seam et le repli dérivé ; sans injection, il produisait un dégradé et écrasait le `null` explicite de l’hôte. Les tests livrés certifiaient précisément ce défaut avec `isNotNull`. AC4 a donc été amendé au profit d’AC9 : neutralité et `null` de l’hôte priment.
- Le dégradé dérivé `primary`/`secondary` était visuellement plat : écart RGB mesuré de **0,039**, contre **0,212** avec `tertiary`.
- Le `lerp` d’une durée nullable matérialisait `Duration.zero` : acceptable comme absence plausible pour une dimension, mais invalide pour une durée consommée par `ConfettiController` lors d’une transition de thème.
- Deux gardes étaient tautologiques : l’une avait un témoin dégénéré, l’autre prétendait tester un changement de thème tout en réinjectant le même thème.

**Comparaison avec SUF.** La consolidation de fin d’epic n’est pas en soi le problème : SUF a prouvé que la lecture transversale révèle les défauts aux coutures. En revanche, VIS a supprimé la seconde source de diversité — les lentilles — en même temps que les revues par story. Le coût est double : détection tardive des défauts intra-story et absence de recoupement spécialisé entre architecture, oracles de test, a11y/thème et réalité du code. Le bénéfice réel est un examen cohérent des quatre stories et de leur preset commun ; son coût réel est que ses verdicts ont demandé un tri d’orchestrateur, dont deux requalifications/rejets, sans filet indépendant. Pour le prochain epic, une revue consolidée reste utile aux coutures, mais elle doit comprendre des lentilles minimales indépendantes et se dérouler sur un arbre stable.

---

## 3. Les cinq prises de la rétro

### 3.1 Un gate global sur un arbre mutable ne mesure pas le workstream qu’il prétend juger

**Faits.** VIS-2 ne pouvait pas conclure parce que `zcrud_flashcard` était temporairement non compilable pendant VIS-3. VIS-3 a reçu un `melos analyze` rouge provenant de `example/` en édition dans VIS-4. Les deux rouges ne leur appartenaient pas.

**Classe d’incident : absence d’isolation du sujet de vérification.** Un gate repo-wide est une observation de l’arbre entier à un instant donné, pas une preuve sur un diff ou un workstream. Dès que l’échantillon change pendant l’observation, le résultat n’est plus attribuable : un rouge peut être externe, et un vert peut masquer une modification arrivée après le départ de la commande. La parallélisation a donc rendu la commande vraie sur le dépôt, mais fausse comme verdict de responsabilité.

**Leçon.** Les tests ciblés peuvent servir de preuve de progression par workstream ; les gates globaux ne deviennent des preuves de clôture qu’à un point de quiescence, avec arbre et base explicitement figés.

### 3.2 Restaurer avec Git a confondu état de référence, travail légitime et artefact d’injection

**Faits.** `git checkout -- lib/src/presentation/` a effacé le travail non commité de VIS-2 : slot `headerDecoration` et badges, puis 20 erreurs de compilation. Les tests et golden non suivis ont survécu et ont permis une reconstruction. Symétriquement, une injection dans un fichier non suivi a survécu au checkout et a pollué deux exécutions suivantes.

**Classe d’incident : restauration non transactionnelle avec visibilité Git incomplète.** Un répertoire Git ne distingue pas une mutation de test d’une modification métier non committée ; `checkout` ne couvre pas non plus les fichiers non suivis. La vérification a donc modifié son propre sujet, sans journal réversible complet. Le problème n’est pas une commande mal choisie à la marge : c’est l’absence de transaction locale « capturer → muter → constater → restaurer exactement → contrôler ».

**Leçon.** Les tests ont heureusement joué le rôle de contrat de reconstruction, mais ce rôle de secours ne doit jamais être le mécanisme normal de récupération.

### 3.3 Une injection ou un oracle peut produire un verdict sans avoir exercé la propriété annoncée

**Faits.** G1 et G6 de VIS-2 ont d’abord ciblé un motif absent : aucune injection, vert présenté comme preuve. G1 a ensuite produit un rouge de compilation via `??=` sur une variable `final`, non un rouge golden ; il a fallu trois tentatives. Le motif attendu était également mal compris : la garde produisait `SizedBox.shrink()`, non `null`. VIS-1 a, pour sa part, livré des assertions `isNotNull` qui validaient le comportement fautif ; deux autres gardes étaient tautologiques.

**Classe d’incident : défaut de chaîne de preuve, en deux formes.**

1. **Mutation fantôme ou mauvais mécanisme d’échec** : l’outil ne prouve que son RC ; il ne prouve ni que le patch a été appliqué, ni que l’échec provient de l’oracle visé.
2. **Oracle conforme à une spécification erronée ou non discriminant** : une assertion peut être parfaitement exécutée tout en certifiant le mauvais contrat, un témoin dégénéré, ou une absence d’effet.

Dans les deux formes, la vérification rend un verdict faux parce qu’elle ne relie pas mécaniquement : régression injectée → différence réellement observée → échec attendu et identifié → restauration exacte. Un test vert ne prouve rien si son oracle n’est pas falsifiable ; un test rouge ne prouve rien si sa signature d’échec n’est pas celle attendue.

### 3.4 La capacité de l’environnement est une précondition de validité des tests

**Faits.** `/tmp` sur tmpfs était à 76 % de ses 7,4 Go, avec des résidus `flutter_tools.*` de runs parallèles, dont un de 962 Mo. `Disk quota exceeded` a donné un faux rouge attribué d’abord au code. La purge a ramené l’occupation de 5,6 Go à 116 Mo.

**Classe d’incident : défaillance d’infrastructure confondue avec défaillance du produit.** Une suite n’observe le code que si son environnement de construction et d’écriture est disponible. Sans pré-vol de capacité ni signature de panne distinguée, un échec système est classé comme régression applicative. Le parallélisme multiplie ce risque car chaque run crée des artefacts temporaires et les résidus se cumulent.

**Leçon.** La disponibilité de l’espace temporaire doit être enregistrée avec le gate ; `Disk quota exceeded` est un verdict « infrastructure invalide », pas un rouge produit.

### 3.5 La parallélisation à trois workstreams : gain réel, coût réel

Après VIS-1, VIS-2, VIS-3 et VIS-4 étaient bien disjoints par package ; la règle « un seul auteur dans `zcrud_core` » a été respectée. Le gain réel est donc la livraison simultanée de trois surfaces indépendantes et l’absence de conflit structurel dans le cœur.

Le coût réel n’est toutefois pas abstrait : deux analyses globales ont été faussement attribuées, les R3 ont cohabité avec des mutations non stabilisées, les résidus temporaires ont provoqué un faux rouge, et la revue unique a attendu que les quatre branches soient réunies. Aucune donnée fournie ne permet de chiffrer un bilan de débit ; l’hypothèse défendable est seulement que le gain de concurrence a été partiellement consommé par le coût de coordination et de requalification des verdicts. Trois workstreams restent justifiés pour des packages réellement disjoints, à condition que les gates globaux et la revue soient sérialisés à l’état de repos.

---

## 4. Ce qui a bien marché (à reproduire)

- **Décision architecture avant l’implémentation** : la distinction tokens incolores / dérivés `ColorScheme` / preset app-side a conservé FR-26/NFR-S7, l’acyclicité et `CORE OUT=0`, tout en permettant le rendu IFFD recherché.
- **Clé stable plutôt qu’index d’affichage** : VIS-3 utilise `card.type.name`, précisément la garde qui aurait détecté le défaut de choix par index observé dans IFFD.
- **Neutralité finalement remise au centre** : l’arbitrage AC4 → AC9 a refusé le fallback implicite et rétabli à la fois le rendu historique et la capacité de l’hôte à choisir explicitement `null`.
- **Mesure plutôt qu’intuition visuelle** : l’écart RGB a montré que le problème de dégradé plat venait du choix des rôles, non de la moyenne initialement suspectée.
- **Tests/goldens survivants comme contrat de récupération** : ce n’est pas un succès de processus, mais c’est une preuve que les artefacts de VIS-2 décrivaient assez bien l’API pour reconstruire le travail perdu.
- **Gates finaux réellement verts** : les contrôles globaux ont finalement été rejoués dans un état stabilisé et confirment les invariants de graphe et de cœur.

---

## 5. Ce qui a moins bien marché / dette ouverte

| Sujet | Impact | Décision de suivi |
|---|---|---|
| Gates globaux joués pendant des écritures concurrentes | faux rouges, attribution erronée, preuve de clôture dégradée | AI-VIS-2 |
| Restauration R3 via `git checkout -- <répertoire>` | perte de travail non commité et pollution persistante des non suivis | AI-VIS-1 |
| Injection sans preuve d’application ou rouge de mauvaise nature | faux verts/faux rouges, trois tentatives pour G1 | AI-VIS-1 et AI-VIS-3 |
| Oracles qui encodent le défaut ou sont tautologiques | VIS-1 a certifié le fallback fautif ; défauts découverts après dev | AI-VIS-3 |
| Lerp nullable de durée | `Duration.zero` peut violer le contrat de `ConfettiController` pendant une transition | AI-VIS-3 |
| Revue finale unique sans multi-lentilles | détection et qualification dépendantes d’un seul regard ; deux verdicts à retrier | AI-VIS-4 |
| Saturation de `/tmp` | faux rouge de test, environnement invalide | AI-VIS-2 |

État de disponibilité : les gates finaux sont verts et l’architecture est saine ; la qualité de preuve doit toutefois être renforcée avant de traiter les stories comme définitivement closes. Aucun fait fourni ne permet d’indiquer une acceptation utilisateur externe, une mise en production, ni un epic suivant planifié ; ces éléments restent donc non évalués plutôt que présumés acquis.

---

## 6. Action items — `AI-VIS-*`

| # | Action | Priorité | Owner | Critère de complétion |
|---|---|---|---|---|
| **AI-VIS-1** | Remplacer toute restauration R3 par un protocole transactionnel fichier par fichier : copie explicite avant mutation, patch vérifié, restauration depuis la copie, puis contrôle de contenu ; inclure les fichiers suivis et non suivis. Interdire `git checkout`/`reset` sur un fichier ou répertoire de travail pour restaurer une injection. | **Haute** | Orchestrateur / Dev | Le prochain R3 conserve un manifeste « avant/après », prouve que chaque cible a été modifiée puis restaurée octet pour octet ; une tentative de restauration Git est refusée par la checklist. |
| **AI-VIS-2** | Séparer preuves locales et gates globaux : tests ciblés pendant les workstreams ; `analyze`/`verify` seulement à quiescence déclarée, sur un arbre figé. Ajouter un pré-vol de `/tmp` et classer explicitement toute erreur d’espace comme échec d’infrastructure, suivi d’une purge contrôlée des résidus `flutter_tools.*`. | **Haute** | Orchestrateur | Chaque gate global de clôture consigne base/diff et absence de workstream écrivain ; le pré-vol enregistre l’espace disponible ; une saturation temporaire produit « infrastructure invalide », jamais une régression code. |
| **AI-VIS-3** | Durcir R3 en chaîne de preuve : une injection doit échouer si le motif/cible attendue est absent, produire un diff attestant la mutation, et vérifier une signature d’échec attendue (test/golden concerné, jamais simple RC). Réviser les oracles VIS : neutralité `null`, opt-in du dérivé, durée nullable, dégradé non plat, et changement de thème réellement distinct. | **Haute** | Dev / QA | Pour chaque garde, record avec cible, diff, commande, signature rouge attendue et vert après restauration ; les mutations fantômes, rouges compilateur non attendus et assertions tautologiques font échouer le protocole. |
| **AI-VIS-4** | Conserver une revue consolidée d’epic pour les coutures, mais restaurer au minimum trois lentilles indépendantes : invariants/architecture, tests-oracles et réalité d’exécution (incluant thème, erreurs hôte et environnement). Revoir chaque finding contre le contrat réellement applicable et les précédents du dépôt avant classification finale. | **Haute** | Orchestrateur / reviewers | Le prochain rapport consolidé comporte trois sections/lentilles distinctes, chacune avec preuves ; aucun HIGH n’est clôturé sans confirmation de périmètre et sans distinguer régression, dette préexistante et dartdoc surpromettant. |
| **AI-VIS-5** | Formaliser le contrat des valeurs nullables à la couture thème : zéro est admissible pour une dimension si le consommateur le tolère ; une durée nulle est invalide quand la dépendance exige une durée positive. Documenter et tester ce contrat dans `ZcrudTheme.lerp`, `ZCelebrationSpec` et les coutures de résolution. | **Haute** | Dev `zcrud_core` / Dev `zcrud_session` | Tests de transition de thème couvrent `null ↔ valeur` pour dimensions et durées ; aucune transition ne construit `ConfettiController(Duration.zero)` ; la dartdoc décrit le `null` hôte et les replis sans surpromesse. |

---

## 7. Prochaines étapes

1. Appliquer **AI-VIS-1** et **AI-VIS-2** avant une nouvelle exécution parallèle : sans restauration sûre ni snapshot stable, aucun verdict global ne peut être attribué avec confiance.
2. Rejouer les gardes VIS sous **AI-VIS-3**, particulièrement celles qui avaient certifié le fallback non neutre, le témoin dégénéré et le faux changement de thème.
3. Traiter la correction de contrat nullable de **AI-VIS-5**, puis rejouer analyse et vérification globales à quiescence.
4. Organiser la prochaine revue consolidée selon **AI-VIS-4** avant toute transition des stories VIS de `review` à `done`.

**Amelia (Developer)** : « VIS a trouvé une bonne frontière de produit : le look IFFD devient un preset injectable sans contaminer les packages. La rétrospective montre surtout que la vérification doit isoler son sujet, muter de façon réversible et prouver la nature de son échec. Sans ces trois propriétés, vert et rouge restent des couleurs, pas des verdicts. »
