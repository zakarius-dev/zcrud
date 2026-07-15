# Rétrospective — Epic ES-6 : Notes & markdown (réutilisation `zcrud_markdown`)

- **Skill** : `bmad-retrospective` (VRAI skill, tool `Skill`, invoqué avec succès — pas de fallback disque). Exécution en mode subagent non-interactif : l'intention du skill (analyse profonde des stories, continuité avec la rétro précédente, préparation de l'epic suivant, action items) est suivie, mais le document est produit directement (pas de session party-mode interactive).
- **Date** : 2026-07-15.
- **Packages cibles** : `zcrud_note` (bascule Flutter + présentation + couche `data/` de migration) ; **comblement ciblé** dans `zcrud_markdown` (couture neutre pur-Dart).
- **Stories** : ES-6.1, ES-6.2 — **toutes `done`**.
- **Contexte process** : Epic **TÊTE + SÉQ interne** (ES-6.1 précède ES-6.2, même package `zcrud_note`). Head parallélisable en principe avec `ES-7.2`/`ES-8.2` (packages disjoints), mais exécuté ici en séquentiel propre. Rétro READ-ONLY (n'écrit QUE ce fichier ; ne touche NI le code NI le `sprint-status.yaml`).

---

## 1. Résultats livrés (vérifiés sur les story-files + code-reviews)

| Story | Livrable | Preuve verte (dernier état des CR) |
|---|---|---|
| **ES-6.1** | Deux **minces adaptateurs** de présentation dans `zcrud_note` : `ZSmartNoteReader` (compose `ZMarkdownReader` + `ZDeltaCodec` identité) et `ZSmartNoteEditor` (`ZFormController` isolé initState/dispose, `ZFieldSpec` const `content`, `ZMarkdownField` voie controller, `ValueKey('content')`, saisie à sens unique → `onChanged(copyWith)`). **Bascule Flutter** de `zcrud_note` (arête `→ zcrud_markdown` née). **AUCUN nouveau codec, zéro duplication** de `zcrud_markdown` (SM-S4/AD-28). **DW-ES22-1 RÉCONCILIÉE PAR CONSTRUCTION** (seul `note.content`, ops déjà canoniques, entre dans le champ ; la branche destructrice `asDeltaOps(String)→null→[]` est inatteignable) — preuve exécutable AC5. Retarget des gardes de pureté (domain+data purs, présentation autorisée). | `flutter test` (R14) **147** RC=0 (88 domaine inchangés + 59 nouveaux) ; `dart analyze` RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0, 41 arêtes / 20 nœuds ; `melos list` inchangé (20). APPROUVÉ, aucun HIGH/MAJEUR ; **MEDIUM-1 CORRIGÉ**, LOW-3 corrigé, LOW-1/LOW-2 consignés. |
| **ES-6.2** | **Comblement `zcrud_markdown`** (SM-S4) : couture **NEUTRE pur-Dart** `z_table_ops.dart` (`kTableEmbedType` **source unique** + `zTableEmbedOp({cells})` JSON-safe, gel profond, lignes paddées ⇒ jamais jagged) ; `z_table_embed.dart`/`z_rich_text_core.dart` re-câblés sur l'import (E6-4 inchangé) ; barrel `show zTableEmbedOp, kTableEmbedType` (aucun type Quill). **Migrateur `zcrud_note/lib/src/data/`** : `zMigrateStickyNote` (DÉLÈGUE `normalizeNoteContentOps`), `zMigrateNoteTables` (détection GFM structurelle, défensif AD-10, préservant au caractère près), `zUpgradeLegacyNoteContent` (composition), **idempotent**. Contrat table **importé, jamais dupliqué**. Retarget pureté (domain strict / data neutre). **Volet « migration des tables » de FR-S25 SOLDÉ.** | `flutter test` `zcrud_markdown` **+277** RC=0 (E6-4 + isolation NON régressés) ; `zcrud_note` **+162** RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0, **0 nouvelle arête**, 20 nœuds ; `melos list`=20 ; analyze RC=0. **APPROUVÉ — 0 HIGH/MAJEUR/MEDIUM**, 2 LOW consignés. |

**Trajectoire** : ES-6.1 bascule Flutter + adaptateurs (147 tests zcrud_note) → ES-6.2 comblement + migrateur (277 zcrud_markdown, 162 zcrud_note), tous verts, non-régression E6-4/isolation à chaque étape.

---

## 2. Ce qui a marché

- **La stratégie « ADAPTATEUR MINCE, zéro nouveau codec » tenue de bout en bout (SM-S4/AD-28).** Tout l'epic est bâti par **réutilisation** de `zcrud_markdown` tel quel : `ZSmartNoteReader`/`ZSmartNoteEditor` composent `ZMarkdownReader`/`ZMarkdownField` + `ZDeltaCodec` (identité) — jamais un `QuillController`/`Delta` manipulé à la main, jamais une classe `implements ZCodec`, jamais une heuristique markdown-vs-Delta. Le scan machine AC9 (ES-6.1) / AC7 (ES-6.2) fige cette contrainte : `zéro implements ZCodec`, `zéro startsWith('[')/contains('"insert"')`. C'est la démonstration vivante de « le pipeline rich-text = source unique, l'entité note = adaptateur ».

- **DW-ES22-1 réconciliée PAR CONSTRUCTION, pas par patch — et prouvée exécutablement.** La dette la plus délicate d'ES-6 (divergence sémantique SUR LA PRÉSERVATION DES DONNÉES : `normalizeNoteContentOps` préserve un markdown legacy, `asDeltaOps(String)→null→[]` le détruit) a été résolue non pas en modifiant `zcrud_markdown`, mais en **garantissant en code que seul `note.content` (ops déjà canoniques) atteint le champ**. La branche destructrice devient inatteignable. AC5 est la **preuve exécutable centrale** : injecter une `String` brute effondre le corps legacy à `'\n'` (RC=1) — le round-trip livré préserve `# Titre markdown legacy` VERBATIM. Réconciliation SOLDÉE et épinglée dans `architecture.md § Deferred`.

- **Le COMBLEMENT dans le package d'origine (jamais la duplication) comme patron réutilisable.** ES-6.2 avait besoin d'une fabrique programmatique d'op embed tableau ; le contrat `{table:{rows,columns,cells}}` n'existait qu'à travers un dialogue Flutter (`showZTableDialog`), sans couture pur-Dart. Plutôt que dupliquer `kTableEmbedType`/les clés dans `zcrud_note`, l'écart a été **comblé DANS `zcrud_markdown`** via une couture NEUTRE (`z_table_ops.dart`), faisant du type la **source unique** partagée par le builder de rendu ET le migrateur. Le scan AC7 (aucun littéral `'table'`/`'rows'`/... dans le migrateur, `import` obligatoire de `kTableEmbedType`) verrouille l'anti-duplication.

- **Défensivité AD-10 systématique et prouvée LOAD-BEARING (ES-6.2).** Le migrateur est intégralement défensif : une table GFM malformée (jagged, séparateur absent/incohérent) est **préservée comme texte VERBATIM**, jamais de throw, jamais d'embed jagged ; idempotence profonde (`noteContentEquals(once, twice)`). L'injection AC5 (retirer la garde de régularité) rougit franchement — c'est la preuve exécutable de la dégradation gracieuse.

- **Le RETARGET de garde (jamais suppression) reconduit proprement de story en story (R13).** ES-6.1 retargete `source_policy_test` : pureté sur `domain/`+`data/`, présentation autorisée. ES-6.2 re-retargete encore (pureté STRICTE `domain/` seul ; nouvelle garde `data/` = couture neutre `zcrud_markdown` OK, Flutter/Quill DIRECT interdit). À chaque fois : **la garde reste MORDANTE** là où il faut (injection prouvée), jamais neutralisée. La tension anticipée « chemin epic `data/` ↔ garde ES-6.1 » (FINDING-ANTICIPÉ-1) a été tranchée par re-scoping, pas par relâchement.

- **Isolation de type conservée sous pression (AD-1/AD-7).** Aucun symbole Quill ne fuit : ni dans la surface publique de `ZSmartNoteEditor`/`ZSmartNoteReader` (ES-6.1), ni dans le barrel `zcrud_markdown` après comblement (ES-6.2). La déviation de nommage assumée (`z_table_ops.dart`, PAS `z_table_embed_ops.dart` qui contient la sous-chaîne interdite `z_table_embed` scannée par `quill_signature_isolation_test`) montre une lecture fine de la garde d'isolation — confirmée verte en machine.

---

## 3. Ce qui est à améliorer / incidents

- **RÉCURRENCE DU MOTIF DOMINANT (MEDIUM-1 d'ES-6.1) — voir § 4.** Un test load-bearing (AC3/SM-1) déclaré couvrant sur son EXISTENCE, mais dont le POUVOIR DISCRIMINANT réel ne portait PAS sur l'invariant visé. Détail et leçon actionnable en § 4.

- **La bascule Flutter d'un package pur-Dart a un COÛT de couverture de plateforme (DW-ES-6.1-1).** Faire dépendre `zcrud_note` de `zcrud_markdown` (Flutter) le sort de `gate:web` : la matrice de coercition JSON déterministe (`jsonDecode` sous VM JS) n'est plus rejouée. **Aucune régression de test** (tout tourne sous `flutter test`), mais **perte d'un filet cross-runtime**. Cette conséquence était ASSUMÉE et ANNONCÉE dès la story (D5), correctement escaladée en `architecture.md § Deferred` par l'orchestrateur/code-review — mais elle **reste ouverte** et devra être arbitrée avant l'adoption store d'ES-3.x sur `smart_note`.

- **Une décision d'architecture des packages différée sous la dette.** La « vraie » résolution de DW-ES-6.1-1 (extraire un sous-package `zcrud_note_domain` pur-Dart pour restaurer la couverture JS) a été jugée hors périmètre M — à juste titre (elle réécrirait l'architecture des packages). Mais cela laisse `zcrud_note` dans un état où son domaine PUR-DART (réutilisable sans Flutter, NFR-S10) n'est plus prouvé cross-runtime. La garde de pureté retargetée conserve l'invariant STRUCTUREL (aucun import Flutter en `domain/`), mais pas la preuve d'EXÉCUTION JS. À ne pas oublier.

- **Deux LOW de préservation edge non couverts (ES-6.2).** LOW-1 (perte de whitespace de tête de table indentée/CRLF, tombant dans la région remplacée par l'embed) est **borné à du whitespace GFM-insignifiant** (aucune prose non-blanche perdue), mais **non couvert par un test**. Consigné, à revisiter si un corpus réel IFFD exhibe un CRLF signifiant. Rappel que la portée « pipe-tables GFM + texte plat » est volontairement bornée : une variante de table non-GFM tomberait en fallback préservant (texte verbatim), mais ne serait pas structurée — à valider sur échantillon réel en ES-11.2.

---

## 4. Motif dominant du repo : « artefact de vérification valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé »

**Occurrence en ES-6 — MEDIUM-1 d'ES-6.1 (énième récurrence, après R12/R13/R18).**

AC3/SM-1 (objectif produit n°1) prouvait bien « 100 frappes ⇒ focus conservé, curseur à 101, témoin frère à sa valeur, `QuillController` jamais recréé ». **MAIS** toutes ses assertions portaient sur des propriétés que **`ZMarkdownField` protège lui-même** (identité du `QuillController`, `FocusNode`, `onChangedCount`). **Aucune n'observait l'identité du `ZFormController` de l'éditeur** — l'objet PROPRE à l'adaptateur, celui dont l'invariant AD-2 « créé UNE FOIS, jamais recréé, disposé » est précisément l'objectif produit n°1.

Preuve du trou : en recréant `_form` **à chaque `build`** (churn, fuite d'un `ZFormController` + listener par frame, jamais disposés), **AC3 restait VERT** (injection #1, RC=0). Le seul pouvoir discriminant contre « controller recréé dans build » reposait sur le fait que `late final` *throw* — pas sur une assertion comportementale. Le code livré était CORRECT ; c'était une **lacune de pouvoir discriminant**, exactement le motif dominant : le harnais protégé (`ZMarkdownField`) masquait l'invariant du composant testé (`ZSmartNoteEditor`).

**Ce qui a attrapé la récurrence** : le code-review adversarial (R12) a posé l'injection fidèle (`_form` non-`final` recréé dans `build`, listener ré-attaché pour préserver `onChangedCount==100`) et constaté le VERT — démasquant le trou. **Remédiation** : AC3 capture désormais `final formBefore = md.controller` AVANT la tempête et asserte `identical(md.controller, formBefore)` APRÈS — ancrant l'invariant sur l'objet propre à l'éditeur. Pouvoir discriminant re-prouvé (injection ⇒ RC=1 « ZFormController recréé sous rebuild ⇒ AD-2 violé »), restauré ⇒ 147/RC=0.

**Leçon actionnable → R20.** Le contraste avec ES-6.2 est instructif : là, les tests load-bearing (AC2/AC5/AC7) portaient TOUS sur des lignes de prod PROPRES au code livré (détection de séparateur, garde de régularité, délégation `normalizeNoteContentOps`, import du contrat) — leurs injections rougissaient toutes DÈS le dev (preuves R3#1-6), aucun trou en revue. La différence : ES-6.2 testait ses PROPRES mécanismes ; ES-6.1 (AC3) testait un mécanisme du VOISIN réutilisé, en croyant tester le sien.

---

## 5. Nouvelles règles (suite R1..R19)

### R20 — Un test d'un ADAPTATEUR doit ancrer son invariant sur l'objet PROPRE à l'adaptateur, jamais sur une protection du composant réutilisé
Quand un widget/service est un **mince adaptateur** composant un composant réutilisé qui porte DÉJÀ des garanties (ex. `ZMarkdownField` protège son `QuillController`/`FocusNode`), un test load-bearing de l'adaptateur qui n'assert QUE des propriétés du composant réutilisé est **POWERLESS sur l'invariant propre de l'adaptateur** : le composant réutilisé masque le churn de l'adaptateur (cf. MEDIUM-1 ES-6.1 — AC3 restait vert alors que `ZFormController` était recréé à chaque frame). Règle : pour tout invariant « créé UNE FOIS / jamais recréé / disposé » d'un objet DÉTENU par l'adaptateur (controller, listener, subscription), **capturer l'identité de CET objet avant la mutation stressante et asserter `identical(...)` après** (+ optionnellement prouver le `dispose`). Ne jamais se fier au fait qu'un `late final` *throw* comme unique garde-fou contre la recréation-dans-`build` : c'est un artefact de langage, pas une assertion comportementale. Corollaire de R18/R12 spécialisé au motif « adaptateur mince ».

### R21 — Combler un écart DANS le package d'origine via une couture NEUTRE pur-Dart, jamais dupliquer un contrat cross-package (SM-S4)
Quand un package satellite a besoin d'une capacité programmatique dont le contrat n'existe que sous une forme couplée (ex. structure d'embed tableau accessible seulement via un dialogue Flutter), **ne pas dupliquer le contrat** (`kTableEmbedType`, clés de structure) dans le satellite. Combler l'écart **dans le package d'origine** en y ajoutant une **couture NEUTRE pur-Dart** (nouveau fichier `lib/src/data/`, aucun `import package:flutter*`), qui devient la **SOURCE UNIQUE** du contrat — importée à la fois par le rendu (présentation d'origine) et par le consommateur (satellite). Garde-fous : (1) barrel n'exporte que la fabrique neutre + le type (`show`), **jamais** les symboles Quill/présentation ; (2) le nom du fichier/symbole **évite les sous-chaînes scannées** par les gardes d'isolation (`z_table_ops.dart` ≠ `z_table_embed`) ; (3) scan machine côté consommateur : **zéro littéral du contrat en dur**, `import` obligatoire depuis l'origine (anti-duplication) ; (4) la présentation d'origine est re-câblée sur l'import (comportement inchangé, prouvé par la suite existante NON régressée). Motive : SM-S4 (l'écart se comble à l'origine, jamais dupliqué) + AD-1/AD-7 (isolation de type conservée).

### R22 — Une réconciliation « PAR CONSTRUCTION » d'une divergence de préservation exige une preuve de round-trip discriminante, pas un simple argument
Quand deux fonctions cross-package DIVERGENT sur la préservation de la donnée (l'une préserve, l'autre détruit) et que la résolution consiste à garantir en code que **seule la branche préservante est atteinte** (jamais un patch de la contrepartie), la preuve exigée n'est PAS l'argument « la mauvaise branche est inatteignable » mais un **test de round-trip complet, discriminant, qui rougit EXACTEMENT quand on force le chemin destructeur** (cf. AC5 DW-ES22-1 : seed d'une `String` brute ⇒ corps effondré à `'\n'` ⇒ RC=1). En complément, si un verrou exécutant les DEUX côtés est impossible (contrepartie privée / package Flutter incompatible runner), **figer la contrepartie par sa SOURCE** (verrou-source épinglant que le symbole destructeur reste privé et non exporté) — le verrou rougit dès que la contrepartie bouge. Une réconciliation « par construction » sans ces deux filets est une affirmation, pas une preuve.

---

## 6. État des dettes après ES-6

| Dette | État | Détail |
|---|---|---|
| **DW-ES22-1** (divergence préservation `normalizeNoteContentOps` vs `asDeltaOps(String)→[]`) | ✅ **SOLDÉE (ES-6.1)** | RÉCONCILIÉE PAR CONSTRUCTION (seul `note.content` ops-canoniques entre dans le champ ⇒ branche destructrice inatteignable). Prouvée en machine (AC5 rougit sur seed `String` brute). Verrou-source conservé (`DeltaNeutralOps` privé, non exporté). Épinglée `architecture.md § Deferred`. |
| **DW-ES-6.1-1** (perte `gate:web` après bascule Flutter de `zcrud_note`) | 🟡 **OUVERTE** | Escaladée `architecture.md § Deferred › DETTES OUVERTES`. Perte d'un filet cross-runtime (couverture JS déterministe de la matrice de coercition), **aucune régression de test**. Correctif possible : extraire `zcrud_note_domain` pur-Dart, OU étendre `gate:web` aux packages Flutter via runner web dédié. **À arbitrer avant l'adoption store d'ES-3.x sur `smart_note`.** |
| **DW-ES22-2** (mapping legacy IFFD camelCase/`Timestamp`/`audioText`… de PERSISTANCE) | ⚪ **HORS PÉRIMÈTRE — confirmée non touchée (ES-6.2, D10)** | Dû à l'**adapter `zcrud_firestore`** (ES-3.5/ES-11.2 — AD-27), **jamais** dans le domaine ni le migrateur. Le migrateur opère sur des **ops de CONTENU déjà neutralisées**, jamais sur la forme de persistance. Non aggravée. |
| MEDIUM-1 ES-6.1 (AC3 non discriminant sur `ZFormController`) | ✅ **REMÉDIÉ + verrouillé** | Assertion d'identité directe `identical(md.controller, formBefore)` après tempête ; pouvoir discriminant re-prouvé (injection ⇒ RC=1). Plus un trou. |
| LOW-1/LOW-2 ES-6.1 (swap de note sans `didUpdateWidget` ; `onChanged` de normalisation au montage) | 🟡 consignés, non bloquants | LOW-1 = mésusage hôte (réutilisation d'élément sans `Key` distincte) hors périmètre ; discipline `Key: ValueKey(note.id)` documentée. LOW-2 = comportement hérité de `ZMarkdownField`, neutre. À traiter si un consommateur réel les rencontre. |
| LOW-1/LOW-2 ES-6.2 (whitespace de bloc de table ; `assert` de contrat cross-package) | 🟡 consignés, non bloquants | LOW-1 borné à du whitespace GFM-insignifiant (aucune prose non-blanche perdue) ; LOW-2 conservé comme assertion de contrat cross-package (garde-fou si la couture change). |

**Aucune dette bloquante.** Aucun HIGH/MAJEUR sur tout l'epic ; le seul MEDIUM (ES-6.1) est remédié et re-prouvé. **DW-ES22-1 soldée** ; **DW-ES-6.1-1 ouverte** (seule vraie dette à porter) ; **DW-ES22-2 hors périmètre, confirmée non touchée**.

---

## 7. Décisions verrouillées réutilisables pour ES-7+

- **Adaptateur mince réutilisant un widget `zcrud_markdown`, `ZDeltaCodec` identité, AUCUN nouveau codec.** Patron confirmé load-bearing : composer `ZMarkdownField`/`ZMarkdownReader` + `ZDeltaCodec`, `ZFormController` isolé (initState/dispose, jamais recréé), `ValueKey` stable, saisie à sens unique. Directement réutilisable pour ES-7.2 (décision rich-text mindmap, OQ-S5) et tout futur champ rich-text : le rich-text éventuel d'un nœud mindmap est un **slot `ZExtension`/`ZCodec` câblé côté app** (opt-in), **jamais** un champ du modèle nœud (architecture.md l. 267).
- **Couture NEUTRE pur-Dart pour exposer une structure d'embed sans fuite Quill ni duplication de contrat (R21).** Réutilisable dès qu'un satellite doit construire/consommer programmatiquement une structure d'embed de `zcrud_markdown` (LaTeX/média — explicitement NON généralisé en ES-6.2 pour éviter la sur-conception, à ajouter au besoin). Source unique du contrat dans le package d'origine, barrel `show` de la seule fabrique neutre, nommage évitant les sous-chaînes d'isolation.
- **Retarget de garde de pureté (jamais suppression) à chaque évolution de couche (R13).** Domain strict / data adapter neutre : quand une couche `data/` doit importer une couture cross-package, re-scoper la pureté STRICTE au `domain/` et ajouter une garde `data/` autorisant la couture neutre mais interdisant Flutter/Quill DIRECT. Prouver la garde mordante par injection.
- **Réconciliation par construction + preuve round-trip discriminante + verrou-source (R22).** Pour toute divergence de préservation cross-package.

---

## 8. Recommandations de séquencement / parallélisation pour ES-7+

- **Le graphe des stories écrivant `zcrud_study` forme une CHAÎNE SÉRIELLE.** `ES-7.1` (`ZStudyMindmapSection`), `ES-8.1` (`ZTagEditor`/`ZTagChips`), `ES-9.1`/`ES-9.3`/`ES-9.4` écrivent TOUTES `zcrud_study` — sprint-status les marque explicitement `SÉQ … NON ∥`. **Une seule story touche `zcrud_study` à la fois** (garde-fou n°2 de CLAUDE.md : le seul point de contact possible est `zcrud_core`, mais ici c'est `zcrud_study` qui est le point de contact partagé). Ne JAMAIS mettre deux de ces stories en vol simultanément.
- **Deux TÊTES `∥` à fichiers disjoints, candidates à parallélisation :**
  - **ES-7.2** (`zcrud_mindmap` — comblement outline + décision rich-text OQ-S5) : package disjoint de `zcrud_study`. ⛔ NON ∥ avec toute story écrivant `zcrud_markdown` (elle pourrait y combler un écart rich-text, comme ES-6.2). Le patron « comblement dans le package d'origine » (R21) s'y applique directement si un écart `zcrud_markdown` est révélé.
  - **ES-8.2** (`zcrud_document/presentation` — `ZAnnotationToolbar`/`Panel`, WCAG) : package disjoint.
  - ⇒ **Parallélisation encadrée possible** : `ES-7.1` (série `zcrud_study`) ∥ `ES-7.2` (`zcrud_mindmap`) ∥ `ES-8.2` (`zcrud_document`) — trois packages disjoints, aucun écrivant `zcrud_study` en même temps que `ES-7.1`. Garde-fous R14-R17 obligatoires (vérifs CIBLÉES par package en dev actif, sérialisation ponctuelle si l'une bootstrappe/crée un package — R17, health-check).
- **NON-NÉGOCIABLE au gate de commit d'epic** (workstreams au repos) : rejouer `melos run analyze` **ET** `melos run verify` **REPO-WIDE** — d'autant plus qu'ES-6.2 a modifié une **surface publique de `zcrud_markdown`** (couture neutre exportée). Une régression cross-package (un consommateur du barrel `zcrud_markdown`) n'est visible que repo-wide (leçon `ZExportApi`). Un `graph_proof`/isolation vert NE remplace PAS `melos analyze`.
- **Arbitrer DW-ES-6.1-1 avant ES-3.x store sur `smart_note`.** La perte `gate:web` doit être tranchée (extraction `zcrud_note_domain` OU runner web pour packages Flutter) avant que la persistance store de `smart_note` soit adoptée — sinon la matrice de coercition JSON reste non couverte cross-runtime.
- **Bascule Flutter acquise, réutilisable.** `zcrud_note` ET `zcrud_markdown` sont déjà Flutter (`flutter test`, R14, déjà hors `gate:web`) — les futures stories `zcrud_note` n'ajoutent aucune nouvelle dette de plateforme.

---

## Transition sprint-status
`epic-es-6-retrospective` (actuellement `optional`) → `done` et report des dettes (DW-ES-6.1-1 ouverte, DW-ES22-1 soldée, DW-ES22-2 hors périmètre), transition `epic-es-6` → `done` : **ressort de l'orchestrateur** (écriture ciblée et sérialisée). **Cette rétro NE touche NI le code NI le `sprint-status.yaml`.**
