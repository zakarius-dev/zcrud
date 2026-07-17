# Code-review — Story `su-1-socle-types-partages-gardes-slots`

**Date** : 2026-07-16 · **Branche** : `main` (rien de committé — commit en fin d'epic)
**Mode** : Workflow **multi-agent à lentilles** (5 lentilles parallèles), puis corrections appliquées
par un agent unique sur arbre quiescent.

**Lentilles jouées** : Conformité AD · Tests porteurs (R3) · Adversariale & réalité du code ·
A11y/RTL/L10n/Thème/SM-1 · Isolation des deps & surface publique.
Rapports complets : `/home/zakarius/.claude/jobs/39909dce/tmp/review-su1-*.md`.

---

## Verdict

**APPROUVÉ après corrections.** 7 findings retenus (2 HIGH, 2 MAJEURS, 3 MEDIUM) — **tous corrigés**,
**aucun reporté**. 2 LOW consignés (1 corrigé au passage, 1 hors périmètre → ledger su-3/su-4).

Le code de production livré par su-1 était **sain sur l'isolation des deps, la surface publique, le
RTL, le thème et l'a11y** (CORE OUT=0, graphe acyclique, zéro couleur/libellé en dur, zéro
gestionnaire d'état dans le cœur, aucune arête ajoutée, aucun `pubspec` modifié, `zcrud_core` non
touché). Les défauts réels portaient sur **AD-46** (deux sources de vérité de l'échelle de qualité et
une garde retirée sans remplacement) et sur le **pouvoir réel des gardes** (une garde aveugle à la
forme nominale du code, trois contre-preuves qui réimplémentaient le scanner au lieu de l'exercer).

> **Note de procédure — faux positifs écartés.** Les rapports de lentilles signalent un HIGH
> « l'arbre est muté pendant la revue / ne compile pas » (`QuillController` non défini) et un
> `melos run verify` RC=1. **Ce n'est PAS un défaut de la story** : c'étaient les **injections R3 de
> lentilles concurrentes** dans le working tree partagé. Vérifié sur arbre quiescent : aucun résidu
> (`grep QuillController packages/zcrud_flashcard/lib/` → RC=1), et les gates repassent verts (§
> Vérif verte). De même, un `-6` en phase `loading` sur `zcrud_session` était dû à deux
> `flutter test` lancés en parallèle sur le même workspace melos. **Leçon** : les injections R3
> destructives doivent être faites dans un worktree jetable quand des lentilles tournent en parallèle.

---

## Findings & dispositions

### D1 — **HIGH** — AD-46 : `ZSrsConfig` admet des échelles que SM-2 ne sait pas honorer
**Fichier** : `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart:20-42` (constructeur)
croisé avec `z_sm2_scheduler.dart:54` (formule gelée).

**Scénario d'échec** : l'AC2 a retiré de `ZQualityScale` la garde historique
`assert(min == 0 || min == 1)` + `assert(max == 5)` **sans la remplacer** — l'`assert` introduit dans
`ZSrsConfig` ne contraignait que la cohérence interne (`minQuality < maxQuality`, seuil dans
l'intervalle). `ZSrsConfig(maxQuality: 4)` — **la config discriminante employée par la story
elle-même** — devenait donc constructible. Or la formule SM-2 est **gelée** sur le sommet `5` :

```
q=3 -> deltaEF=-0.1400
q=4 -> deltaEF= 0.0000   ← le MEILLEUR score possible d'une échelle 1..4
q=5 -> deltaEF=+0.1000   ← seul q=5 fait CROÎTRE l'easeFactor
```

Avec `maxQuality: 4`, `deltaEF` est **nul au meilleur score** et strictement négatif partout
ailleurs : l'`easeFactor` ne peut **plus jamais croître**. Les intervalles d'un apprenant sans faute
cessent de s'espacer ; à la première erreur l'ease descend et ne remonte jamais. **Silencieux** :
aucune exception, aucun test rouge. Symétriquement `maxQuality: 10` passait les asserts, l'UI
affichait 11 crans, et `q=10` était clampé à 5 puis comparé à `passThreshold: 6` ⇒ **la meilleure
réponse possible traitée en échec total** (lapse, 30 j de progression détruits).

**Disposition : CORRIGÉ** (option (a), arbitrée). Transposition de l'ancienne garde vers son nouveau
propriétaire — deux `assert` en liste d'initialisation, message riche expliquant **pourquoi** :
`maxQuality == 5` et `minQuality ∈ {0, 1}`. AD-46 dit littéralement « échelle canonique : **0..5** —
SM-2 complet » : rendre le sommet configurable ne généralise pas l'algorithme, ça fabrique des
configs que le moteur ne sait pas servir. Le trou est désormais fermé **par construction**.
Dartdocs de `minQuality`/`maxQuality` alignés (`maxQuality` = champ **de lecture**, pas de réglage :
il existe pour que le clamp et `fromConfig` le **lisent** au lieu de le recopier).

**Conséquence traitée** : les discriminants AC1/AC2 employant `maxQuality: 4` sont remplacés par
`minQuality: 1, maxQuality: 5` (échelle « sans blackout ») — discriminant **tout aussi valide** de la
dérivation (une échelle en dur rendrait `[0..5]` et contiendrait `0`), sans exercer une config
corruptrice. **Le pouvoir R3 est conservé** (preuve rejouée ci-dessous).

**Test porteur ajouté** (`z_srs_config_test.dart`) : `ZSrsConfig(maxQuality: 4)`, `(maxQuality: 10)`,
`(minQuality: 2)`, `(minQuality: -1)` ⇒ `AssertionError` en debug.

---

### D2 — **HIGH** — AD-46 : seconde source de vérité — `quality.clamp(0, 5)` en dur
**Fichier** : `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart:49`

**Scénario d'échec** : sur `ZSrsConfig(minQuality: 1, ...)` (« sans blackout »), le domaine et l'UI
déclarent que `q = 0` **n'existe pas** (`ZQualityScale.fromConfig(config).contains(0) == false`).
Mais une qualité `0` atteint `reviewCard` par un chemin **réel et attendu** (l'AC1 annonce
`clampQuality` consommé par **su-3** via le `suggestedQuality` du **port d'évaluation** ; ou une
valeur persistée corrompue — AD-10). Le scheduler appliquait alors `0.clamp(0, 5) = 0` — **pas**
clampé au `minQuality: 1` de la config : `deltaEF = -0.80` au lieu de `-0.54`. **L'UI et le scheduler
lisaient deux échelles différentes**, en silence. Corollaire : `clampQuality`, déclaré « unique
propriétaire du clamp », était **du code mort** (grep : zéro call-site prod).

**Disposition : CORRIGÉ** — `final q = config.clampQuality(quality);` (le `config` était **déjà** un
champ de la classe, utilisé deux lignes plus bas). Effets : `clampQuality` devient réellement l'unique
propriétaire, et le dartdoc du fichier cesse d'être contredit.
La formule `(5 - q)` n'est **PAS** touchée (gelée) — D1 la protège désormais par construction ; le
dartdoc du fichier a été rendu **honnête** sur ce point (le `5` de la formule est intrinsèque à SM-2,
pas un réglage, et ne peut plus diverger de la config puisque `maxQuality` y est épinglé).

**Contrat gelé rejoué : VERT** — `z_sm2_contract_test.dart` **+53 All tests passed**. Attendu : les
vecteurs gelés emploient la config par défaut ⇒ `config.clampQuality(q) ≡ q.clamp(0,5)` **par
identité**. Le contrat figeait le *comportement défensif*, pas la *provenance des bornes*.

**Test porteur ajouté** (`z_srs_scheduler_test.dart`) : avec `minQuality: 1`, `apply(info, 0)` ⇒
`lastQuality == 1` et état **strictement égal** à `apply(info, 1)`.

---

### D3 — **MAJEUR** — AD-38 : la garde de composition unique ne couvrait qu'un package sur deux
**Fichier** : `packages/zcrud_study_kernel/test/z_section_key_single_composition_test.dart:53`

`Directory('lib')` ne scannait que le **kernel**, alors que l'AC3 exige mot pour mot
`zcrud_study_kernel` **+ `zcrud_study`** — or `zcrud_study` est le package qui **ÉCRIT**
`sectionOrders` (patron documenté en `z_study_tools_section_spec.dart:123`), donc le **vrai lieu du
risque**. Le filet était tendu sous le package qui n'en a pas besoin (celui qui possède déjà le foyer
canonique), et absent sous celui qui en aura besoin (su-4/su-5).

**Scénario d'échec** : su-14 (« ordre manuel ») compose `'$contentType/$subfolderId'` à la main dans
`zcrud_study/lib/` ; avec `subfolderId == ''` la clé vaut `'flashcards/'` — la **clé fantôme** que
`z_section_key.dart` prend soin d'éviter. `applyOrder` étant **TOTAL**, l'ordre est **ignoré en
silence** : l'utilisateur voit son classement « oublié », et la garde reste **verte**.

**Disposition : CORRIGÉ** — scan étendu à `../zcrud_study/lib` (constante `_scannedLibRoots`), avec
contre-preuve `isNotEmpty` **par racine** (une racine vide = garde morte ⇒ rouge explicite) et
assertion que toutes les racines exigées ont bien été scannées. Dartdoc corrigée : l'affirmation
« seul package du monorepo qui possède la notion de section » était **fausse** et redéfinissait la
portée à la baisse sans citer l'AC.

**État actuel non en violation** — grep négatif confirmé : `zcrud_study/lib` ne compose aucune clé
aujourd'hui (seules des mentions en dartdoc). La garde couvre l'**avenir**, sa seule raison d'être.

---

### D4 — **MAJEUR** — AC4 : la garde anti-fuite de type riche était aveugle au MULTI-LIGNES
**Fichier** : `packages/zcrud_flashcard/test/z_flashcard_rich_type_leak_test.dart:44-57`

`_isPublicDeclaration` filtrait **ligne à ligne** par liste blanche de préfixes. Or le typedef protégé
est lui-même wrappé sur 4 lignes — **le formatage que `dart format` (80 col.) impose** : la ligne du
paramètre (`  QuillController content,`) ne satisfait **aucun** préfixe et n'était **jamais** scannée.
Le multi-lignes est le cas **NOMINAL**, pas l'exception. C'était le **SEUL filet** revendiqué par AC4
contre la fuite de type — la clause « aucun type Quill dans une signature publique » n'était donc
prouvée par **aucun** test porteur.

**Preuve du défaut (rejouée par la lentille tests-porteurs)** : injection multi-lignes ⇒
`+3: All tests passed!` (garde **verte** sur une fuite réelle). La même fuite **mono-ligne** était
bien attrapée — frontière exacte du trou.

**Disposition : CORRIGÉ** — le scanner (`scanForRichTypeLeaks`) raisonne désormais par
**DÉCLARATION** : les lignes de continuation sont **recollées** jusqu'au `;`/`{`/`}` qui clôt l'unité
syntaxique, les espaces sont normalisés, et les annotations en tête (`@override`…) sont retirées
avant le test de publicité (elles masquaient auparavant la déclaration qu'elles décorent). La
violation pointe la **ligne d'ouverture**. Ajout d'un test **anti-sur-blocage** (le recollage ne doit
pas fusionner une déclaration saine avec une déclaration privée voisine) — une garde qui crie au loup
finit désarmée.

---

### D5 — **MEDIUM** (R3) — test tautologique : le « DISCRIMINANT » du slot
**Fichier** : `packages/zcrud_flashcard/test/z_flashcard_content_slot_test.dart:75-93`

Le groupe « le slot est RÉELLEMENT branché (pas décoratif) » définissait un builder local et
**l'appelait lui-même** : zéro symbole de production dans les 18 lignes du test. Il prouvait que
`Text('INJECTÉ:x')` affiche `INJECTÉ:x` — **une propriété de Flutter**. Supprimer tout le code de
production sauf le typedef l'aurait laissé **vert**.

**Racine** : il est **infalsifiable en su-1** — grep négatif : `ZFlashcardContentBuilder` n'a **aucun
consommateur de production** (le câblage arrive en su-2 ; bornage explicitement assumé par la story).
**Le défaut est le LIBELLÉ, pas la conception** : le test atteste une propriété non testable ici.

**Disposition : CORRIGÉ (honnêteté)** — le test tautologique est **supprimé** (il n'apportait rien
que son voisin, qui lui exerce le vrai `ZFlashcardDefaultContent.builder`, n'apporte déjà). Le groupe
est retitré « **FORME du contrat d'injection (branchement effectif : su-2)** » et documenté : ce qu'il
prouve, ce qu'il ne prouve pas, et **pourquoi la preuve du branchement incombe à su-2** (c'est là
qu'existera le call-site et que le discriminant « slot décoratif » deviendra falsifiable). Le dartdoc
de tête du fichier, qui promettait cette preuve, est corrigé.
**Aucun faux consommateur de production n'a été inventé** pour verdir le test.

> ⚠️ **À reporter au ledger su-2** : AC4 « le slot est réellement branché » et la vraie garde SM-1
> (« aucune closure réallouée à chaque build ») **restent à prouver en su-2**. Sans cette trace, su-2
> hériterait d'ACs réputés couverts qui ne le sont pas.

---

### D6 — **MEDIUM** (R3) — les contre-preuves réimplémentaient le scanner au lieu de l'exercer
**Fichiers** : `z_section_key_single_composition_test.dart:107-140` ·
`z_quality_scale_single_source_test.dart:90-120` · `z_flashcard_rich_type_leak_test.dart:144-176`

Chaque « contre-preuve du scanner lui-même » **recopiait la boucle de scan** sur des chaînes
artificielles, ne partageant que la constante de motifs. Elle validait donc les **MOTIFS**, jamais le
**SCANNER** : si la boucle réelle régressait, la contre-preuve restait **verte** sur sa propre copie
intacte.

**C'est la racine causale exacte de D4** : la contre-preuve nourrissait le scanner avec des lignes
**mono-ligne** et passait, donnant l'illusion d'une garde saine **pendant que le vrai scanner était
aveugle au multi-lignes**. Une contre-preuve exerçant la vraie fonction aurait révélé le trou.

**Disposition : CORRIGÉ** — la boucle de scan est extraite en fonction partagée
(`scanForManualComposition` / `scanForScaleLiterals` / `scanForRichTypeLeaks`), **appelée des deux
côtés** (garde sur le code de prod, contre-preuve sur la source artificielle). Les trois fichiers
sont traités.

---

### D7 — **MEDIUM** (thème) — le test « repli sur `Theme.of` » n'atteignait jamais sa branche
**Fichier** : `packages/zcrud_flashcard/test/z_flashcard_content_slot_test.dart:152-161`

`ZcrudTheme.fallback` remplit **TOUJOURS** `labelColor` (`z_theme.dart:81` :
`labelColor: text.bodyMedium?.color ?? scheme.onSurface`) ⇒ le `??` de
`z_flashcard_content_slot.dart:71` prenait **toujours la branche gauche**. Le test ne passait que par
**coïncidence numérique** (`bodyMedium.color == onSurface` dans le ThemeData par défaut). Double
défaut : **faux vert** (su-2 « simplifie » en supprimant la lecture de `ZcrudTheme` — violation FR-26
franche — le test reste vert car il compare justement à `onSurface`) et **faux rouge** (un hôte qui
adoucit sa typographie, `bodyColor: 0xFF333333`, fait rougir un comportement **correct**).

**Disposition : CORRIGÉ (honnêteté + couverture réelle)** — deux tests désormais :
1. le test existant est aligné sur la branche **réellement** empruntée
   (`ZcrudTheme.fallback(Theme.of(context)).labelColor`) et retitré, avec la coïncidence documentée ;
2. un **vrai DISCRIMINANT** ajouté qui exerce la branche de repli pour de bon :
   `ZcrudScope(theme: ZcrudTheme())` (⇒ `labelColor == null`) + un `ColorScheme.onSurface`
   **volontairement distinct** de `bodyMedium.color` (sans quoi le test passerait quelle que soit la
   branche prise, et ne discriminerait rien).

**Le code de production est CONFORME** (aucune couleur en dur) — **non modifié**, conformément à
l'arbitrage.

---

### LOW — consignés

| # | Objet | Disposition |
|---|---|---|
| L1 | `z_flashcard_content_slot_test.dart` — le test de « stabilité du tear-off » est un **truisme du langage** (deux tear-offs `const` d'une même méthode statique sont canonicalisés : l'assertion runtime ne peut pas échouer ; son `reason` promettait « pas de closure réallouée à chaque build », propriété du **call-site** jamais observée). | **CORRIGÉ** (trivial) — retitré/redocumenté : le pouvoir réel est **à la compilation** (si `builder` devenait un getter renvoyant une closure, le `const` cesserait de compiler). Vraie garde SM-1 **déférée à su-2** (tracé). |
| L2 | `reviewCard` (`z_flashcard_repository.dart:272`) est public et **mode-agnostique** : une app peut l'appeler hors runtime pendant une session `cramming`. | **REPORTÉ — justifié** : **pré-existant**, non introduit par su-1, et **hors périmètre déclaré** (AD-34 vise les *runtimes*, dont la garde est conforme et symétrique). → ledger **su-3/su-4**. |

### Dettes PRÉ-EXISTANTES relevées (hors périmètre su-1 → ledger)

Aucun hunk de su-1 ne descend sous la ligne 60 de `z_srs_quality_buttons.dart` (`git blame` →
`f751d82f`, 2026-07-15, **antérieur** à su-1). Corriger ici élargirait une story « tête bloquante ».

- **MEDIUM a11y/l10n** — `z_srs_quality_buttons.dart:208` : `passed ? 'ok' : 'lapse'` en dur dans
  `Semantics.value`, **lu à voix haute** par le lecteur d'écran, alors que le dartdoc du fichier
  promet l'inverse et que ce `value` est désigné comme le **canal non-coloré obligatoire d'AD-13**.
  Mécanisme disponible : `label(context, key, fallback:)`.
- **LOW FR-26** — `z_srs_quality_buttons.dart:243` : `fontSize: 12` en dur.
- **LOW SM-1** — `ZQualityScale.fromConfig` n'étant jamais `const`, construire l'échelle dans un
  `build()` réallouera une identité à chaque rebuild (Flutter ne court-circuite que sur `identical`,
  **jamais** sur `==`). Piège à documenter pour su-2..su-6 (hoister hors du `build()`).

---

## Preuves R3 rejouées RÉELLEMENT sur disque

Chaque injection : sauvegarde → faute → test → constat → **restauration vérifiée par `diff`**.
Arbre au repos, **un seul `flutter test` à la fois** (jamais deux en parallèle sur ce workspace melos).

| Inj. | Faute injectée dans le code de PRODUCTION | Attendu | **CONSTATÉ** |
|---|---|---|---|
| **D4** | `QuillController` dans le typedef public, wrappé **multi-lignes** (`dart format`) | 🔴 | ✅ **🔴 `+4 -1`** — `TYPE RICHE dans une signature publique`. *(Avant correction : `+3: All tests passed!`)* |
| **D2** | `config.clampQuality(quality)` → `quality.clamp(0, 5)` | 🔴 | ✅ **🔴 `+16 -1`** — seul le porteur AD-46 échoue |
| **D3** | composition manuelle `'$contentType/$subfolderId'` dans `zcrud_study/lib` | 🔴 | ✅ **🔴 `+0 -1`** — violation pointée `…z_study_tools_section_spec.dart:138`. *(Avant correction : garde aveugle — hors scan)* |
| **D7** | couleur **en dur** dans la branche de repli (`?? const Color(0xFFAABBCC)`) | 🔴 | ✅ **🔴 `+8 -1`** — seul le DISCRIMINANT de repli échoue |
| **D6** | scanner **réel** rendu aveugle (skip de commentaire régressé en `if (true)`) | 🔴 | ✅ **🔴 `+1 -1`** — « interpolation manuelle non détectée — garde morte » : **la contre-preuve exerce bien le vrai scanner** |
| **D1** | *(garde par construction — test porteur permanent)* | 🔴 | ✅ `ZSrsConfig(maxQuality: 4)` ⇒ `AssertionError` |

**Restauration prouvée** : `diff` vs sauvegarde **vide** sur les 5 fichiers injectés ;
`git status --short packages/zcrud_study/` → **vide** ; sweep de résidus →
`grep QuillController packages/zcrud_flashcard/lib/` **RC=1**, `grep "clamp(0, 5)" packages/*/lib/`
**RC=1**, `grep "injectedKey|R3-D3|if (true) {" packages/*/lib packages/*/test` → **aucun hit**
(l'unique `0xFFAABBCC` du repo est un test **pré-existant** de `zcrud_core`, non touché).

---

## Vérif verte — RC RÉELS (rejoués sur arbre quiescent, séquentiellement)

| Gate | Commande | **RC réel** | Détail |
|---|---|---|---|
| Analyze | `dart run melos run analyze` | **0** | repo-wide — `dart analyze . └> SUCCESS` |
| Verify | `dart run melos run verify` | **0** | `ACYCLIQUE OK` · **`CORE OUT=0 OK`** · `gate:secrets OK` · `gate:codegen-distribution OK` · `gate:compat OK` · `gate:web OK` (`dart test -p node` sur `zcrud_study_kernel`) · `gate:reserved-keys OK` |
| Test | `dart run melos run test` | **0** | **3606 tests** — `All tests passed!` sur les 23 packages |

**Deltas de comptage expliqués** (aucun test perdu par accident) :

| Package | Avant | Après | Explication |
|---|---|---|---|
| `zcrud_flashcard` | 235 | **240** | +2 porteurs D1 · +1 porteur D2 · +2 scanner D4 (multi-lignes + anti-sur-blocage) · +1 discriminant D7 · **−1** tautologique D5 supprimé |
| `zcrud_session` | 87 | **86** | **−1** : le cas « échelle tronquée en bas (1..5) » devenait le **doublon** exact du discriminant R3-I2 réécrit — fusionné, pouvoir conservé |
| `zcrud_study_kernel` | 313 | **313** | refactor D3/D6 à périmètre de tests constant (portée du scan **élargie**) |

---

## Fichiers touchés par les corrections

**Production (3)**
- `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` — D1 (2 `assert` + dartdocs)
- `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart` — D2 (`config.clampQuality` + dartdoc honnête)
- *(aucune modification du code de prod pour D3..D7 — les défauts étaient dans les gardes)*

**Tests (6)**
- `packages/zcrud_flashcard/test/z_srs_config_test.dart` — porteurs D1, discriminants `1..4` → `1..5`
- `packages/zcrud_flashcard/test/z_srs_scheduler_test.dart` — porteur D2
- `packages/zcrud_flashcard/test/z_flashcard_rich_type_leak_test.dart` — D4 + D6
- `packages/zcrud_flashcard/test/z_flashcard_content_slot_test.dart` — D5 + D7 + L1
- `packages/zcrud_session/test/z_quality_scale_single_source_test.dart` — D6
- `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` — D1 (call-sites)
- `packages/zcrud_study_kernel/test/z_section_key_single_composition_test.dart` — D3 + D6

**Non touchés, conformément aux contraintes** : `sprint-status.yaml`, `zcrud_core`, tout dépôt externe
(`iffd`/`lex_douane`), la formule SM-2 gelée, `z_sm2_contract_test.dart`.
