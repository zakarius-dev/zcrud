# Réconciliation transverse — l'état de l'HÔTE sur les invariants du socle

**Périmètre** : IFFD `@ 65d1af9` (2026-08-26) × zcrud `@ main` (v3.21.0).
**Lecture seule stricte sur `/home/zakarius/DEV/iffd`.** Aucun test lancé.

**Le trou que ce document comble** : les cinq catalogues décrivent ce que *le socle offre* en
thème, a11y, l10n, hors-ligne et granularité. Les onze cartes de domaine décrivent ce que *l'hôte
fait*, domaine par domaine. Aucun des deux ne mesure **l'état transverse de l'hôte** — c'est
précisément ce qu'une découpe par domaine rend invisible, parce qu'un défaut réparti sur 549
fichiers n'appartient à aucun quartier.

Assiette mesurée : `lib/` = **549 fichiers, 179 222 lignes** ; `test/` = **228 fichiers
(224 `*_test.dart`), 58 639 lignes**.
```
$ find lib -name '*.dart' | wc -l                 → 549
$ find lib -name '*.dart' -exec cat {} + | wc -l  → 179222
$ find test -name '*_test.dart' | wc -l           → 224
```

---

## 1. Les chiffres remesurés, et l'écart avec la critique

Méthode : les motifs ne sont **pas** de mon invention — ce sont ceux de la garde du socle,
`packages/zcrud_core/test/purity/style_purity_test.dart:25-49`, recopiés à l'identique et appliqués
à `iffd/lib`. C'est la seule mesure qui a du sens : elle dit ce que l'hôte devrait corriger *pour
passer la garde que le socle s'applique à lui-même*.

| Sujet | Critique | **Remesuré** | Écart | Commande |
|---|---:|---:|---|---|
| Sites non directionnels (AD-13) | 249 | **321** occ / **68** fichiers | **+72** | regex `style_purity_test.dart:42-49` sur `lib` |
| `Semantics(` | 25 | **26** occ / **16** fichiers | +1 | `grep -rn 'Semantics(' lib` (25 *lignes*, 26 *occurrences*) |
| `StatefulWidget` | 105 | **93** `extends StatefulWidget` + **12** `ConsumerStatefulWidget` = **105** | 0 | ✔ confirmé |
| `setState(` | 420 | **420** occ / **54** fichiers | 0 | ✔ confirmé à l'unité |
| Couleurs en dur (FR-26) | 2 225 | **2 601** occ dédupliquées / **157** fichiers | +376 | voir détail ci-dessous |
| Fichiers de test | 224 | **224** | 0 | ✔ confirmé |
| Dépendances tierces | 122 | **123** hors zcrud (**146** directes, dont **23** zcrud) | +1 | parse `pubspec.yaml` |
| Deps sans un seul import | 13 | **17** | **+4** | `comm -23` deps × imports `lib`+`test` |

**Détail directionnel** (les 321) :
```
107  EdgeInsets.only([^)]*\b(left|right)\s*:
104  Alignment.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)
 46  Positioned([^)]*\b(left|right)\s*:
 27  BorderRadius.only(
 24  EdgeInsets.fromLTRB(
 13  TextAlign.(left|right)
  0  BorderRadius.horizontal(
```
L'écart de +72 vient de deux motifs que la critique n'avait pas comptés mais que **la garde du
socle compte** : `EdgeInsets.fromLTRB(` (24) et `BorderRadius.only(` (27), plus les occurrences
multiples sur une même ligne que `grep -c` écrase.

**Détail couleurs** (les 2 601) : `Colors.<nom>` **1 964**, `Color(0x…)` **601**,
`Color.fromARGB` **19**, `Color.fromRGBO` **17**. La garde du socle compte en plus le motif brut
`0x[fF]{6,8}` (**594**), qui recouvre presque intégralement les `Color(0x…)` — d'où **3 195** si
on additionne naïvement les sept motifs, et **2 601** en dédupliquant. Les 2 225 de la critique
sont probablement un `grep -c` par lignes ; l'ordre de grandeur tient, le chiffre exact non.

**Les 17 dépendances déclarées sans un seul `import` dans `lib/` ni `test/`** :
`animated_icon`, `async`, `awesome_dio_interceptor`, `cloud_firestore_platform_interface`,
`cupertino_icons`, `firebase_performance`, `flex_seed_scheme`, `flutter_chat_types`,
`flutter_slidable`, `flutter_tts`, `form_builder_extra_fields`, `form_builder_file_picker`,
`json_annotation`, `loading_overlay`, `ms_map_utils`, `scroll_to_index`, **`zcrud_riverpod`**.

> 🔴 **`zcrud_riverpod` est déclaré et jamais importé**, alors que **136 fichiers** de `lib/`
> importent `flutter_riverpod` directement. Le binding officiel du socle pour ce gestionnaire est
> payé en résolution de dépendance et contourné en pratique. Unique occurrence du nom dans le
> code : un commentaire, `lib/src/data/repositories/z_backed_folder_repository.dart:17`.

---

## 2. Sujet par sujet : ce que le socle offre déjà, ce qui manque

### 2.1 Directionnalité (AD-13) — 321 sites

**Ce que le socle offre.** Pas une API : une **garde**, et des widgets propres par construction.
- `packages/zcrud_core/test/purity/style_purity_test.dart:42-53` — les sept motifs interdits,
  appliqués à `zcrud_core/lib/src/presentation`.
- Gardes jumelles réparties : `zcrud_flashcard/test/z_flashcard_rtl_guard_test.dart`,
  `zcrud_menu/test/z_menu_a11y_rtl_test.dart`, `zcrud_session/test/presentation/z_widgets_purity_test.dart`,
  `zcrud_document/test/source_policy_test.dart`, `zcrud_markdown/test/z_markdown_source_scan_test.dart`.

**Ce qui manque.** La garde s'arrête au bord du socle : `Directory('lib/src/presentation')` résolu
depuis le paquet. **Rien ne la porte côté hôte.** L'hôte a pourtant **25 gardes de source**
(`grep -rln "Directory('lib')" test | wc -l → 25`) — parité de formulaires, tripwires de bascule,
absence de GetX dans les écrans portés — mais **aucune** qui scanne `lib/` pour le directionnel ou
les couleurs. Grep négatif :
```
$ grep -rln "Directory('lib')" test | xargs grep -lE 'Colors\\\.|EdgeInsets\\\.only|AlignmentDirectional'
test/w9b/conversation_list_defects_test.dart     ← garde d'un écran, pas transverse
```
Une seule, et elle est locale à un écran.

### 2.2 Accessibilité — 26 `Semantics(` pour 105 widgets à état

**Le constat décisif de ce document** :

```
Semantics total lib : 26   dont dans les fichiers important package:zcrud_* : 26
$ grep -rln 'Semantics(' lib | while read f; do grep -q 'package:zcrud_' "$f" || echo "$f"; done
(aucune sortie)
```

> **Les 26 `Semantics(` de l'hôte sont TOUS dans les 110 fichiers déjà portés au socle.
> Les 439 fichiers non portés en contiennent ZÉRO.**

Autres marqueurs : `semanticLabel` → **4** occurrences ; `MergeSemantics|ExcludeSemantics` → **2** ;
`tooltip:` → 107 (le seul vecteur d'a11y réellement pratiqué, et il ne couvre ni les listes, ni les
états, ni les champs).

Densité comparée : socle **542 `Semantics(` / 825 fichiers** = 0,66 par fichier ; hôte
**26 / 549** = 0,047. **Facteur 14.**

**Ce que le socle offre** : `kZMinTapTarget = 48` (`packages/zcrud_markdown/lib/src/presentation/z_rich_text_core.dart:41`,
13 usages), et la sémantique câblée dans chaque widget publié. **Ce qui manque** : la constante des
48 dp vit dans `zcrud_markdown`, pas dans `zcrud_core` — un hôte qui n'adopte pas le markdown n'a
pas de plancher de cible tactile nommé à réutiliser.

### 2.3 Localisation — l'hôte est monolingue, sans infrastructure

```
$ find . -name '*.arb' -not -path './build/*' | wc -l   → 0
$ ls l10n.yaml                                          → Aucun fichier
$ grep -rn 'AppLocalizations|\.tr\b|S\.of\(' lib | wc -l → 0
lib/main.dart:51: const supportedLocales = [Locale("fr")];
```
Chaînes littérales dans un `Text(` : **332**. Il n'y a pas de dette de traduction — il n'y a
**aucune infrastructure de traduction**.

**Ce que le socle offre**, et que l'hôte consomme déjà :
- `ZcrudLocalizations` / `ZcrudLocalizationsDelegate` — `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:373` et `:407`, monté à `lib/main.dart:312`.
- `ZcrudLabels` — `packages/zcrud_core/lib/src/presentation/l10n/z_labels.dart:20`, exposé par
  `ZcrudScope.labels` (`zcrud_core/lib/src/presentation/zcrud_scope.dart:120`).

**Ce qui manque, côté hôte** : `ZcrudScope.labels` n'est **jamais** passé.
```
$ grep -rn 'labels:' lib --include='*.dart' | grep -v '//'
lib/src/presentation/features/mindmap/zcrud/mindmap_outline_zcrud.dart:170
lib/src/presentation/features/flashcards/zcrud/multi_flashcard_editor_zcrud.dart:181
lib/src/presentation/features/flashcards/zcrud/flashcard_list_zcrud.dart:194
```
Trois sites, tous des paramètres **de widget**, aucun sur `ZcrudScope`. Le socle documente
lui-même l'incident dans le code de l'hôte (`lib/main.dart:290-305`) : sept boutons « Add item »
rendus en anglais parce que le delegate n'était pas monté, jusqu'au 2026-08-09 — et le commentaire
prend soin de dire **« ce n'était pas une CR »**. Le motif *offert, non passé* y est daté
26ᵉ occurrence.

### 2.4 Thème (FR-26) — 2 601 couleurs en dur, réparties

Par module :
```
src/presentation  1170 occ /  92 fichiers
data_crud          432 occ /  17
workflow           197 occ /  12
ai_assistant       137 occ /  14
src/utils           79 /2   src/config 72/4   src/domain 34/5   reste ≈ 46
```
Le pire fichier est `lib/data_crud/edition_screen.dart` (**203**), c'est-à-dire le **moteur de
formulaire legacy** — celui que la bascule supprime.

**Ce que le socle offre** : `ZcrudTheme extends ThemeExtension<ZcrudTheme>`
(`packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:323`), injecté par `ZcrudScope.theme`
(`zcrud_scope.dart:44`) ; `ZForegroundOverride` (`zcrud_core/lib/src/presentation/theme/z_foreground_override.dart:76`) ;
l'exception FR-26 encadrée pour les valeurs legacy (patron `ZStudyCardReference`).

**Ce que l'hôte a déjà branché** : `IffdZcrudScope`
(`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:346-406`) passe `widgetRegistry`,
`theme`, `iconResolver`, `colorKeyResolver`, `selectPresenter`, `defaultTextConfig`,
`numberDisplayFormatter`, `dateDisplayFormatter`, `acl`. **Ce qui n'est jamais passé** :
```
$ grep -rn -E '^\s+(listRenderer|filePicker|cloudStorage|richTextRenderer|resolver):' lib --include='*.dart'
(aucune sortie)
```
Cinq seams du scope non alimentés — dont `listRenderer`, ce qui explique que
`lib/data_crud/dynamic_list_screen.dart` (1 753 lignes) survive.

### 2.5 Hors-ligne (AD-9) — l'hôte n'a pas d'offline-first, et n'en a jamais eu

```
$ grep -rln 'package:hive' lib | wc -l        → 0
$ grep -rn 'connectivity' lib | wc -l         → 0
$ grep -n '^  (hive|sqflite|isar|drift|connectivity_plus):' pubspec.yaml → aucune
$ grep -rn 'persistenceEnabled|Source.cache|GetOptions' lib             → aucun résultat pertinent
```
L'hôte s'en remet au **cache implicite du SDK `cloud_firestore`** (activé par défaut sur mobile,
jamais configuré ici) : pas de store local source de vérité, pas de merge LWW explicite, pas de
soft-delete piloté, pas de débounce de synchronisation.

**Ce que le socle offre**, entièrement inutilisé sur ce plan : port `ZLocalStore`
(`zcrud_core/lib/src/domain/ports/z_local_store.dart:43`), `ZSyncOrchestrator`
(`zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart:117`), `ZSyncMeta`
(`.../z_sync_meta.dart:20`), et côté adaptateur `zcrud_firestore/lib/src/data/` :
`hive_z_local_store.dart`, `z_offline_first_repository.dart`, `z_offline_first_box_repository.dart`,
`z_study_sync_orchestrator.dart`, `z_firestore_cascade_batcher.dart`.

**Nuance mesurée, à ne pas écraser** : `ZSyncMeta` **est** connu de l'hôte — 85 occurrences des
symboles de synchronisation, dont `lib/src/data/repositories/z_backed_flashcard_repository.dart:74`
qui l'importe et documente le LWW sur `updated_at` hors-entité. L'hôte a donc adopté la
**convention** de métadonnées d'AD-9 sans en adopter la **machinerie**. Seuls **5 fichiers**
importent `zcrud_firestore`.

### 2.6 Granularité des reconstructions — voir §3

---

## 3. 🔴 Verdict sur l'objectif produit n°1

**Question posée** : les 420 `setState(` sont-ils dans des formulaires — donc résolus par
l'adoption du moteur d'édition — ou ailleurs ?

**Réponse : très majoritairement AILLEURS. La bascule des formulaires ne rachète qu'environ un
quart de la dette, et le reste ne partira jamais tout seul.**

Trois mesures tranchent.

**(a) Les formulaires déjà portés sont à zéro. Sans exception.**
```
$ grep -rn --include='*zcrud_edition*.dart' 'setState(' lib | wc -l → 0
```
27 fichiers `*_zcrud_edition.dart`, **0 `setState`**. Le moteur d'édition tient sa promesse là où
il est adopté : ce n'est pas une hypothèse, c'est un compte nul sur 27 fichiers.

**(b) Mais la masse n'est pas dans les formulaires.** Répartition des 420 :
```
src/features   186 occ / 30 fichiers
workflow       158 occ /  8 fichiers   ← module agenda/tâches, hors périmètre CRUD
data_crud       62 occ / 10 fichiers   ← moteur legacy, remplacé par la bascule
cotation 5 · accounting 5 · ai_assistant 2 · divers 2
```
Les fichiers dont le nom porte `form|edition|dialog` totalisent **108** occurrences, soit **26 %**.
Le reste vit dans des visionneuses PDF (`document_viewer/bottom_toolbar.dart` 17,
`search_toolbar.dart` 6), des cartes de révision (`interactive_flashcard_repetition_card.dart` 13),
un éditeur de graphe (`graphite_editor_widget.dart` 8), une page de login (10), un éditeur de
rendez-vous Syncfusion de 7 858 lignes (`workflow/screens/appointment_editor.dart` **79**).

**(c) Le défaut historique exact — le rebuild global — est identifiable et localisé.**
Le motif `setState(() {})` **vide** est la signature littérale de « je reconstruis tout l'écran
parce que je ne sais pas quoi reconstruire » :
```
$ grep -rn -E 'setState\(\(\)\s*(=>)?\s*\{\s*\}\s*\)' lib | wc -l → 66
lib/data_crud/edition_screen.dart                        16   ← 4 073 lignes
lib/…/documents/widgets/folder_documents_actions_dialog…  7
lib/data_crud/sub_list_screen.dart                        7
lib/data_crud/dynamic_list_screen.dart                    6   ← 1 753 lignes
lib/…/flashcards/widgets/flashcard_edition_screen.dart    5
lib/…/flashcards/pages/multi_flashcard_editor_page.dart   5
lib/workflow/screens/appointment_editor.dart              3
```
Et **40** `setState` se déclenchent depuis un `onChanged:` (fenêtre de 3 lignes), dont **4** sont
des `setState(() {})` vides — le jank à la frappe, à la lettre.

**Verdict, arithmétique montrée.** Les 17 fichiers dont le nom porte `form|edition|dialog` pèsent
**108** des 420, dont **25** dans `data_crud/` et **15** dans `workflow/task_edition_screen.dart`.

- **62** vivent dans `data_crud/` (tout le moteur legacy, pas seulement ses fichiers « edition ») →
  **disparaissent mécaniquement** quand le moteur meurt.
- **~68** de plus sont dans des dialogues/éditeurs de `src/features` → portables vers
  `ZFormController` (`packages/zcrud_core/lib/src/presentation/z_form_controller.dart:33`).
  ⚠️ Le plus gros d'entre eux, `folder_documents_actions_dialog_widget.dart` (**17**), est un
  **menu d'actions**, pas une saisie : le compte est un plafond optimiste, pas un acquis.
- **≈ 290 restants — dont les 158 de `workflow/`** — ne sont **pas** un problème de formulaire et
  resteront à la charge de l'hôte après une bascule CRUD complète.

Autrement dit : la bascule des formulaires rachète **au mieux 31 %** des 420. Les qualifier
« résolus par la migration » serait faux.

**Contrepoint honnête** : l'hôte n'est pas démuni en réactivité fine — **104**
`ValueListenableBuilder|ListenableBuilder` et **101** `ref.watch(` cohabitent avec les 420
`setState`. Le socle en a 243 pour 825 fichiers. La dette est concentrée, pas diffuse.

---

## 4. Le risque de régression que porte la bascule

Un écran porté hérite des invariants du socle. Trois d'entre eux **changent le rendu** — donc
peuvent régresser une compensation existante (cf. la règle de handoff : hôte passif ≠ hôte ayant
compensé).

### Ce que l'hôte gagne AUTOMATIQUEMENT (aucun travail, mais un risque visuel)

| Invariant | Gagné par | Risque de régression |
|---|---|---|
| **Directionnel (AD-13)** | tout widget du socle est déjà `EdgeInsetsDirectional`/`AlignmentDirectional` | **Aucun en `fr` (LTR)** : les deux formes rendent à l'identique. Le gain est théorique tant que `supportedLocales = [Locale("fr")]`. |
| **Sémantique** | les 542 `Semantics(` du socle | **Aucun visuel.** Les tests de l'hôte qui localisent par `find.byType` continuent ; ceux par `find.text` peuvent voir un nœud sémantique s'interposer. |
| **Thème** | `ZcrudTheme` + repli `Theme.of` | 🔴 **Réel.** L'hôte passe déjà `theme:` et `colorKeyResolver:`, et l'a calibré pour compenser des défauts amont. Chaque correction du socle qui rend une couleur *native* **s'additionne** à la compensation de l'hôte. C'est exactement le motif CR-LEX-76 (marge à 24 dp au lieu de 12). |
| **Libellés** | `ZcrudLocalizationsDelegate`, déjà monté | Aucun — mais **`ZcrudScope.labels` reste nul** : toute surcharge de libellé passe encore par des constantes de widget dispersées sur 3 sites. |

### Ce qui reste intégralement le travail de l'hôte

1. **Les 439 fichiers non portés gardent zéro `Semantics`.** Porter les écrans CRUD ne touche pas
   `workflow/` (8 fichiers, 158 `setState`), les visionneuses de documents, `accounting/`,
   `cotation/`. L'a11y ne se propage pas par osmose.
2. **Les ~2 160 couleurs en dur hors `data_crud/`.** La bascule en efface 432 (`data_crud/`) et
   197 si `workflow/` suivait — soit au mieux **24 %**.
3. **Les ~310 `setState` hors formulaire** (§3).
4. **Le hors-ligne.** Aucun écran porté ne devient offline-first : il faut *choisir* d'instancier
   `ZOfflineFirstRepository` / `HiveZLocalStore`. La bascule ne le fait pas à la place de l'hôte,
   et `hive` n'est même pas au `pubspec`.
5. **La l10n.** Le socle localise *ses* libellés. Les 332 `Text('…')` français de l'hôte restent
   codés en dur, sans `.arb` ni `l10n.yaml` pour les recevoir.
6. **Le filet transverse.** 224 fichiers de test, **0 golden**, **10** avec `Directionality`,
   **17** touchant `Semantics`, **8** testant le mode sombre. Le socle sait garder ses invariants
   par des gardes de source ; l'hôte n'en a aucune sur ces sujets.

### Le geste le moins cher, et il n'est pas dans le socle

Recopier les **sept regex** de `packages/zcrud_core/test/purity/style_purity_test.dart:42-49` dans
une garde de source côté hôte, ancrée sur `lib/`, avec une **liste d'exemption nominative** des 68
fichiers actuels — c'est un **cliquet** : le stock reste, mais rien ne s'y ajoute, et chaque
fichier porté sort de la liste. C'est exactement le patron que l'hôte pratique déjà avec talent
(`test/s2/l10n_extraite_test.dart`, `test/m0/formulaires_socle_tripwires_test.dart`) — appliqué
aux domaines, jamais au transverse.

---

## 5. Ce que je n'ai pas mesuré

- Le rendu réel en RTL (aucun test lancé, et l'app est monolingue `fr`).
- L'impact perf des 420 `setState` (aucun profilage — la classification du §3 est structurelle,
  par lecture du motif et de son site d'appel).
- Les 122 fichiers de `test/` non ouverts : la couverture transverse est estimée par grep, pas par
  lecture.
- `android/`, `ios/`, `web/`, `functions/`, `nodejs/`, `build/` : hors périmètre.
