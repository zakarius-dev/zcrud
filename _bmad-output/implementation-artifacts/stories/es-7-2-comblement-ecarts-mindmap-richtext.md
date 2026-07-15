---
baseline_commit: f29368c7a229bd17dfc5ab2ab37156a0407ccd6f
---

# Story ES-7.2 : Comblement des écarts mindmap + décision rich-text du `content` de nœud (`zcrud_mindmap`, OQ-S5)

Status: review

<!-- Skill réel : bmad-create-story (tool Skill). Story enrichie à pouvoir discriminant (R12). -->

## Métadonnées

- **Epic** : ES-7 — Intégration mindmap (réutilisation `zcrud_mindmap`).
- **Taille** : **M** · **Parallélisation** : **PARALLÉLISABLE** — écrit **`zcrud_mindmap`** (package DISJOINT de `zcrud_study`). Peut voler en même temps qu'ES-7.1 (`zcrud_study`) et ES-8.2 (`zcrud_document`). ⛔ **NON ∥ avec toute story écrivant `zcrud_markdown`** (R21 : un écart rich-text pourrait s'y combler — cf. dette anticipée DW-ES72-2).
- **Package cible** : `packages/zcrud_mindmap/` (+ note de décision dans `architecture.md` AD-28 + memlog — hors code).
- **Couvre** : FR-S26 · **AD** : AD-28, AD-4, AD-1, AD-2/AD-15, AD-7, AD-13, AD-16, AD-10 · FR-26 · **SM-S4** (objectif : combler à l'origine, jamais dupliquer) · **SM-1** (rebuild granulaire).
- **Dépend de** : ES-5 (au niveau epic). **N'a AUCUNE dépendance de code entrante sur ES-7.1** (voir § Dépendance inverse).

---

## Story

As a **développeur intégrateur IFFD**,
I want **combler les écarts de l'éditeur/vue outline (zoom piloté, mode compact, plein-écran, super-racine multi-forêt) DANS `zcrud_mindmap` de façon strictement additive, et trancher/matérialiser/prouver la décision rich-text du `content` de nœud (OQ-S5)**,
so that **IFFD puisse migrer avec rich-text sans forcer les autres apps ni modifier le modèle de nœud, les écarts vivant dans le package d'origine (jamais dupliqués dans `zcrud_study`), et ES-7.1 puisse composer l'API existante EN PARALLÈLE sans casse**.

---

## ⚠️ LE FAIT STRUCTURANT n°1 — OQ-S5 est DÉJÀ TRANCHÉE par AD-28 : cette story l'IMPLÉMENTE et la PROUVE, elle ne la re-décide pas

`architecture.md` § **AD-28** (l. 264-267) tranche déjà :

> « Le `content` d'un **nœud mindmap reste texte brut** dans `zcrud_mindmap` ; le rich-text éventuel est un **slot `ZExtension`/`ZCodec` câblé côté app** (opt-in), **pas** un champ du modèle nœud — de sorte qu'IFFD puisse migrer avec rich-text sans forcer les autres apps ni modifier `zcrud_mindmap`. Les écarts de `zcrud_mindmap`/`zcrud_markdown` … se comblent **dans le package d'origine**, jamais dupliqués. »

**Le rôle d'ES-7.2 est donc de RENDRE VRAIE et PROUVABLE cette décision**, pas de délibérer. Concrètement :
1. **NE PAS** ajouter de champ rich-text au modèle `ZMindmapNode` (`content` reste `String?` texte brut ; `_knownKeys` inchangé). Voir AC7.
2. **Livrer le SEAM opt-in** : un `nodeContentBuilder` prêt-à-l'emploi (`ZMindmapMarkdownContent`) dans **`zcrud_mindmap`** (package d'origine — R21) qui compose `ZMarkdownReader` + `ZDeltaCodec` **identité** (**aucun nouveau codec**), lit le payload rich depuis le **slot AD-4** (`extra`/`extension`), et **retombe en texte brut** (`content`/`label`) si absent. L'app CHOISIT ce builder (défaut = texte brut ⇒ autres apps non forcées) : c'est cela, « câblé côté app opt-in ». Voir AC8.
3. **Prouver par round-trip discriminant** (R22) que le payload rich survit inchangé via le slot AD-4, et que forcer un chemin destructeur (nouveau codec / champ modèle) rougit. Voir AC7/AC8.
4. **Documenter** OQ-S5 comme RÉSOLU (note AD-28 + memlog). Voir AC9.

## ⚠️ LE FAIT STRUCTURANT n°2 — beaucoup d'« écarts » listés existent DÉJÀ ; le dev ÉTEND, il ne réinvente PAS

État lu sur disque (E10-1/2/3, `git 709406d` et antérieurs). **NE PAS ré-implémenter** :

| Affordance de la liste epic | État AVANT réel | Ce que fait ES-7.2 |
|---|---|---|
| **indent / outdent au clic** | **DÉJÀ** : boutons `_OutlineActionButton` (`indent`/`outdent`) dans `z_mindmap_outline_editor.dart` → `ZMindmapOutlineController.indent/outdent` → `ZMindmapTreeOps.indentNode/outdentNode` (recalcul `level`). | **Verrouiller par régression** (AC6) ; ne rien changer. |
| **super-racine multi-forêt** | **DÉJÀ pour le LAYOUT graphe** : `ZMindmapGraphMapper.fromForest` crée une **racine virtuelle non affichée** (`virtualRootId`) quand `roots.length > 1` (`usesVirtualRoot`). | **Exposer un opt-in USER-FACING** (montrer/replier la super-racine étiquetée en graphe ET outline), en **réutilisant** `usesVirtualRoot` — jamais un 2e mécanisme. AC5. |
| **zoom** | **BORNES DÉJÀ** : `ZMindmapViewConfig.minScale/maxScale` passées à `DirectGraph` (InteractiveViewer interne de `graphite`). **Aucun contrôle user-facing.** | Ajouter des **contrôles zoom pilotés** (in/out/reset) bornés par la config. AC2. |
| **compact** | **ABSENT** (seul `editContentField:bool` existe côté éditeur). | Ajouter un **mode compact** (rendu condensé label-seul), rebuild ciblé. AC3. |
| **plein-écran** | **ABSENT** dans la vue mindmap (⚠️ `showZRichTextFullscreenDialog` existe dans `zcrud_markdown` mais concerne l'édition **markdown**, PAS la vue mindmap — ne pas confondre). | Ajouter un **toggle plein-écran** de la surface mindmap. AC4. |

**Règle d'or de la story (SM-S4)** : tout écart comblé vit **sous `packages/zcrud_mindmap/lib/src/`** et est exporté par le barrel ; **rien** dans `zcrud_study` (qu'ES-7.1 écrit en parallèle).

## ⚠️ LE FAIT STRUCTURANT n°3 — ADDITIF STRICT (contrat de parallélisation avec ES-7.1)

ES-7.1 (`zcrud_study`, en vol PARALLÈLE) **compose l'API E10 EXISTANTE** (`ZMindmapView`, `ZMindmapOutlineController`, `ZMindmapOutlineEditor`). Pour que la parallélisation tienne (architecture l. 107), **ES-7.2 est ADDITIF STRICT** : aucune signature publique existante modifiée, aucun défaut de comportement changé, tout nouveau paramètre **optionnel avec défaut = comportement actuel**. Preuve load-bearing = **toute la suite E10 pré-existante passe INCHANGÉE** (AC6).

---

## Contexte fichiers EXISTANTS lus (état AVANT — à préserver)

### `zcrud_mindmap` (package CIBLE — Flutter, R14)
- `lib/src/domain/z_mindmap_node.dart` — **NE PAS TOUCHER LE MODÈLE** (AC7). `content` = `String?` texte brut ; `_knownKeys` = `{id,label,content,level,children,extension}` ; slots AD-4 `extension`/`extra` ; garde `_sanitizeExtra` (ctor **non-`const`**) ; `fromJson`/`toJson` défensifs (AD-10/AD-16). Mutation EXCLUSIVEMENT via `ZMindmapTreeOps` (aucun `copyWith`).
- `lib/src/domain/z_mindmap_tree_ops.dart` — moteur PUR (`indentNode`/`outdentNode`/`reorderChild`/`moveNode`/`normalizeLevels`/`newRootNode`/`newChildNode`). **Réutiliser tel quel** ; aucun nouvel op requis.
- `lib/src/domain/z_mindmap_api.dart` — porte déjà l'arête `zcrud_mindmap → zcrud_markdown` (`ZMarkdownApi.version`).
- `lib/src/presentation/z_mindmap_view.dart` — vue graphe (`DirectGraph`) + liste ; état de vue local en `ValueNotifier` (`_selected`, `_mode`) + `ValueListenableBuilder` (AD-2/AD-15) ; `nodeContentBuilder` injectable (**le seam rich-text**, défaut `ZMindmapDefaultNodeContent` texte brut) ; zoom borné par config ; `ExcludeSemantics` sur le graphe (liste = surface a11y).
- `lib/src/presentation/z_mindmap_graph_mapper.dart` — `virtualRootId`/`usesVirtualRoot` (super-racine de LAYOUT déjà présente).
- `lib/src/presentation/z_mindmap_view_config.dart` — `ZMindmapViewConfig` (immuable, `minScale`/`maxScale`/`cellSize`/`indentStep`/`minTapTarget≥48`). **Aucune couleur** (thème injecté FR-26).
- `lib/src/presentation/z_mindmap_outline_editor.dart` / `z_mindmap_outline_controller.dart` / `z_mindmap_outline_labels.dart` — éditeur outline corrigé (bug save lex soldé) ; controllers `TextEditingController` stables keyés par `id` (SM-1) ; libellés a11y externalisés ; boutons ≥48 dp `Semantics`.
- `lib/src/presentation/z_mindmap_list_view.dart` / `z_mindmap_node_card.dart` — surfaces de rendu.
- `lib/zcrud_mindmap.dart` — barrel (tout nouveau symbole PUBLIC doit y être `export`é).
- Tests E10 existants (**à NE PAS régresser**, AC6) : `z_mindmap_test.dart` (10), `z_mindmap_node_test.dart` (17), `z_mindmap_tree_ops_test.dart` (29), `z_mindmap_view_test.dart` (16), `z_mindmap_outline_editor_test.dart` (3), `z_mindmap_conformance_test.dart` (3).

### `zcrud_markdown` (RÉUTILISÉ tel quel — ⚠️ NE PAS MODIFIER dans cette story)
- Barrel exporte `ZMarkdownReader` (`value`/`codec`/`label`/`placeholder`), `ZCodec`, `ZDeltaCodec` (codec **identité** `const` — `encode`=`jsonEncode`, `decode`=`DeltaNeutralOps.decodeDefensiveOps`). **Patron de référence** : `zcrud_note/.../z_smart_note_reader.dart` fait `ZMarkdownReader(value: note.content, codec: const ZDeltaCodec(), label: ...)` (ES-6.1). `ZMindmapMarkdownContent` en est l'analogue exact.
- ⚠️ Si ES-7.2 découvre un **écart** dans `zcrud_markdown`, R21 impose de le combler **là** — ce qui rendrait la story NON-∥ avec toute story écrivant `zcrud_markdown`. **Objectif : NE PAS écrire `zcrud_markdown`** (le seam se construit dans `zcrud_mindmap` en composant l'API markdown existante). Voir dette DW-ES72-2.

### `zcrud_core` (RÉUTILISÉ — NE PAS MODIFIER)
- `ZExtensible`/`ZExtension` (slots AD-4), `ZSyncMeta.reservedKeys`, `ZcrudTheme.of(context)` (FR-26), `zSanitizeExtra`.

---

## 🔴 DÉCISIONS DE CONCEPTION (D1..D8)

- **D1 — OQ-S5 : `content` de nœud reste `String?` texte brut.** Zéro champ rich-text sur `ZMindmapNode`. `_knownKeys` inchangé. (AD-28, AC7.)
- **D2 — Seam rich-text = `nodeContentBuilder` opt-in, dans `zcrud_mindmap`.** Nouveau builder mince `ZMindmapMarkdownContent` (fichier `lib/src/presentation/z_mindmap_markdown_content.dart`) composant `ZMarkdownReader` + `const ZDeltaCodec()`. **Aucun `implements ZCodec`**, **aucun `QuillController`/`Delta` manipulé à la main**. Défaut de la vue reste texte brut ⇒ autres apps non forcées. (AD-28/AD-7, R20/R21, AC8.)
- **D3 — Payload rich stocké dans le slot AD-4, pas dans `content`.** Le builder lit les ops Delta depuis `node.extra[<clé applicative>]` (ou `node.extension`), **repli** sur `content`/`label` texte brut si absent/mal formé (défensif AD-10). La clé applicative est un **paramètre du builder** (l'app la possède) — `zcrud_mindmap` n'impose aucune clé réservée. (AD-4/AD-10.)
- **D4 — Zoom piloté par un `TransformationController`/`ValueNotifier<double>` PROPRE à la vue.** `graphite.DirectGraph` gère son propre `InteractiveViewer` interne **non pilotable de l'extérieur** : envelopper la surface graphe dans un `InteractiveViewer` externe (ou `Transform`) piloté par notre controller, boutons in/out/reset **clampés** à `[config.minScale, config.maxScale]`. ⚠️ **Vérifier d'abord l'API `graphite` 1.2.1** ; **ne jamais forker `graphite`**. Si double-zoom (interne+externe) gêne, neutraliser proprement l'un des deux — décision de dev documentée dans le Change Log. (AC2.)
- **D5 — compact/plein-écran/super-racine = état de vue LOCAL en `ValueNotifier` + `ValueListenableBuilder`.** Aucun `setState` à l'échelle vue/page, aucun gestionnaire d'état tiers, rebuild ciblé (AD-2/AD-15/SM-1). (AC3/AC4/AC5.)
- **D6 — super-racine user-facing RÉUTILISE `usesVirtualRoot`.** Opt-in `showSuperRoot` : quand `roots.length > 1` et opt-in, la racine virtuelle est **affichée** (étiquette externalisée) et groupe la forêt ; toggle off ⇒ forêt plate ; 1 seule racine ⇒ **jamais** de super-racine. Aucun 2e mécanisme de virtual-root. (AC5.)
- **D7 — a11y/thème des nouveaux contrôles.** Boutons zoom/compact/plein-écran/super-racine : **≥ 48 dp**, `Semantics` étiquetés via libellés **externalisés** (étendre `ZMindmapOutlineLabels` ou nouveau bundle `ZMindmapViewLabels`), **directionnels** (`EdgeInsetsDirectional`/`AlignmentDirectional`), **aucune couleur/dimension codée en dur** (tout de `ZcrudTheme.of(context)`, repli `Theme.of`). (AD-13/FR-26, AC10.)
- **D8 — ADDITIF STRICT.** Tout nouveau paramètre de `ZMindmapView`/`ZMindmapViewConfig`/éditeur est **optionnel, défaut = comportement E10 actuel**. Aucune signature existante cassée. (AC6.)

---

## Acceptance Criteria (à pouvoir discriminant — R12)

> Chaque AC load-bearing est accompagné d'une **injection** (§ Injections R3) qui le rend ROUGE si la garde est neutralisée. Un AC dont l'injection reste VERTE est POWERLESS et doit être renforcé.

**AC1 — SM-S4 : les écarts sont comblés DANS `zcrud_mindmap` (origine), exportés par le barrel, testés en standalone**
- **Given** les nouveaux contrôles (zoom/compact/plein-écran/super-racine) et le seam rich-text
- **When** on inspecte l'emplacement
- **Then** tout le code neuf vit sous `packages/zcrud_mindmap/lib/src/` et est **exporté par `lib/zcrud_mindmap.dart`** ; la suite de tests **`zcrud_mindmap` seule** (sans dépendance à `zcrud_study`) les exerce (preuve qu'ils vivent à l'origine)
- **And** aucun symbole équivalent n'est créé dans `zcrud_study` (SM-S4).
- *Discriminant* : retirer l'`export` du barrel ⇒ le test standalone ne résout plus le symbole (RED).

**AC2 — Zoom user-facing borné + reset (vue graphe)**
- **Given** `ZMindmapView` en mode graphe et `config.minScale=0.25 / maxScale=2.5`
- **When** on actionne zoom-in N fois puis reset
- **Then** l'échelle appliquée est **clampée à `maxScale`** (jamais au-delà), zoom-out clampé à `minScale`, et **reset** restaure l'échelle initiale
- **And** les contrôles pilotent un controller PROPRE à la vue (pas l'InteractiveViewer interne non pilotable de `graphite`).
- *Discriminant* : supprimer le `clamp(min,max)` ⇒ N zoom-in dépasse `maxScale` (RED).

**AC3 — Mode compact (rebuild ciblé)**
- **Given** une forêt rendue et un toggle `compact`
- **When** on active compact
- **Then** le rendu passe en **condensé** (le contenu long/extrait `content` est masqué, `label` seul), via un `ValueNotifier<bool>` + `ValueListenableBuilder` (**aucun `setState` global, aucun autre nœud/section reconstruit** — SM-1)
- **And** re-désactiver restaure le rendu plein.
- *Discriminant* : router le toggle compact par un `setState` d'ancêtre / notifier global ⇒ témoin « nombre de rebuilds d'un nœud frère » > 0 (RED) ; OU compact ne masquant pas le contenu ⇒ assertion de masquage RED.

**AC4 — Plein-écran (toggle, défaut off)**
- **Given** `ZMindmapView` (défaut : NON plein-écran)
- **When** on active le plein-écran
- **Then** la surface mindmap occupe le plein-écran (route/overlay dédié) avec une affordance de sortie étiquetée ; **le défaut reste le layout E10 actuel** (off)
- **And** l'état plein-écran est local (`ValueNotifier`), sans gestionnaire d'état tiers.
- *Discriminant* : faire du plein-écran le défaut ⇒ un test E10 de layout inline rougit (RED, recoupe AC6).

**AC5 — Super-racine multi-forêt (opt-in, réutilise `usesVirtualRoot`)**
- **Given** une forêt à **> 1** racines et `showSuperRoot` opt-in
- **When** on active la super-racine
- **Then** la racine virtuelle (`ZMindmapGraphMapper.virtualRootId`) est **affichée et étiquetée** (libellé externalisé), groupant les racines ; toggle off ⇒ forêt plate
- **And** avec **1 seule** racine, **aucune** super-racine n'apparaît (préserve `usesVirtualRoot == roots.length > 1`)
- **And** aucun 2e mécanisme de racine virtuelle n'est introduit (réutilisation du mapper).
- *Discriminant* : forcer `usesVirtualRoot=true` pour 1 racine ⇒ test « 1 racine ⇒ pas de super-racine » RED.

**AC6 — ADDITIF STRICT / non-régression E10 (contrat de parallélisation ES-7.1)** *(load-bearing)*
- **Given** l'API publique E10 (`ZMindmapView`, `ZMindmapOutlineController`, `ZMindmapOutlineEditor`, `ZMindmapViewConfig`)
- **When** ES-7.2 ajoute ses paramètres/contrôles
- **Then** **toutes** les signatures publiques existantes restent valides et **toute la suite de tests E10 pré-existante passe INCHANGÉE** (78 tests existants non modifiés)
- **And** chaque nouveau paramètre est **optionnel, défaut = comportement E10 actuel**.
- *Discriminant* : rendre un nouveau paramètre `required` ou changer un défaut ⇒ ≥ 1 test E10 pré-existant RED (compilation ou comportement).

**AC7 — OQ-S5 : `ZMindmapNode.content` reste texte brut, ZÉRO champ rich-text (modèle inchangé)** *(load-bearing)*
- **Given** le modèle `ZMindmapNode`
- **When** on inspecte ses champs et son round-trip
- **Then** `content` reste `String?` **texte brut**, `_knownKeys` **inchangé** (aucun `delta`/`richContent`/`format`), aucun champ rich-text ajouté
- **And** un nœud portant un payload rich **dans le slot AD-4** (`extra['<clé>']`) a un round-trip `fromJson → toJson` **byte-préservé** (payload inchangé, `content` texte brut préservé, clés de sync jamais réémises — AD-16)
- *Discriminant* : ajouter un champ rich-text au modèle / l'insérer dans `_knownKeys` ⇒ le verrou « `_knownKeys` == ensemble figé » et/ou le round-trip RED.

**AC8 — OQ-S5 : seam rich-text opt-in via adaptateur MINCE `zcrud_markdown`, AUCUN nouveau codec (R20/R21/R22)** *(load-bearing)*
- **Given** `ZMindmapMarkdownContent` (nouveau `nodeContentBuilder` opt-in dans `zcrud_mindmap`)
- **When** l'app le passe en `nodeContentBuilder` avec une clé de slot AD-4 portant des ops Delta
- **Then** le nœud est rendu en rich-text via **`ZMarkdownReader` + `const ZDeltaCodec()`** (réutilisés tels quels), **sans** nouveau codec, **sans** `QuillController`/`Delta` construit à la main
- **And** scan machine (patron ES-6.1 AC9) : dans `zcrud_mindmap`, **zéro `implements ZCodec`**, **zéro** heuristique markdown-vs-Delta (`startsWith('[')`/`contains('"insert"')`), `import` obligatoire de `package:zcrud_markdown`
- **And** **repli plain-text** : si le slot AD-4 est absent/mal formé, le builder rend `content`/`label` en texte brut (défensif AD-10, jamais de throw)
- **And** le `nodeContentBuilder` **par défaut** de la vue reste texte brut (autres apps non forcées)
- **And** round-trip discriminant (R22) : le payload Delta rendu = le payload stocké (identité) ; forcer un ré-encodage/pseudo-codec altère le payload ⇒ RED.
- *Discriminant* : remplacer `ZDeltaCodec` identité par un codec ré-encodant, OU retirer le repli plain-text (nœud sans payload ⇒ rendu vide), OU ajouter `implements ZCodec` ⇒ RED (round-trip / repli / scan).

**AC9 — OQ-S5 documentée (décision RÉSOLUE)**
- **Given** la décision D1..D3
- **When** on clôt OQ-S5
- **Then** `architecture.md` § AD-28 porte une **note de résolution** « OQ-S5 RÉSOLU (ES-7.2) : `content` texte brut ; rich-text = slot AD-4 + `nodeContentBuilder` opt-in `ZMindmapMarkdownContent` (adaptateur mince `ZMarkdownReader`+`ZDeltaCodec`, aucun nouveau codec) » ; une entrée **memlog** consigne le choix + justification (réutilisation maximale, leçon ES-6.1)
- **And** la présente story documente le quoi + le pourquoi.
- *(AC de documentation — vérifié par présence, pas par test runner.)*

**AC10 — a11y / thème des nouveaux contrôles (AD-13 / FR-26)**
- **Given** les boutons zoom/compact/plein-écran/super-racine
- **When** on les rend
- **Then** chacun est **≥ 48 dp**, `Semantics(button:true, label:…)` avec libellés **externalisés** (repli neutre non-nul), **directionnel** (`EdgeInsetsDirectional`/`AlignmentDirectional`, jamais `left/right`), et **aucune couleur/dimension codée en dur** (tout `ZcrudTheme.of(context)`, repli `Theme.of`)
- *Discriminant* : coder une couleur en dur / une cible < 48 dp / un libellé en dur ⇒ scan/`expect` de conformité RED (patron E10-3 MEDIUM-1/LOW-2).

---

## Deliverables (D)

- **Dev-1** — `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_controls.dart` (NOUVEAU) : état de vue local `ZMindmapViewController`/`ValueNotifier`s (zoom `double`, `compact` bool, `fullscreen` bool, `showSuperRoot` bool) — pur-Flutter (AD-2/AD-15). *(Nom à ajuster ; éviter les sous-chaînes scannées par les gardes.)*
- **Dev-2** — `z_mindmap_view.dart` (UPDATE, additif) : câblage des contrôles (barre d'outils zoom in/out/reset clampée ; toggles compact/plein-écran/super-racine) ; enveloppe zoom PROPRE (D4) ; affichage étiqueté de `virtualRootId` en super-racine (D6). Paramètres nouveaux **optionnels, défauts = E10**.
- **Dev-3** — `z_mindmap_view_config.dart` et/ou nouveau `ZMindmapViewLabels` (UPDATE/NEW) : libellés a11y externalisés des nouveaux contrôles (repli neutre non-nul) ; éventuels réglages de layout compact. Aucune couleur.
- **Dev-4** — `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart` (NOUVEAU) : `ZMindmapMarkdownContent` = `nodeContentBuilder` opt-in composant `ZMarkdownReader` + `const ZDeltaCodec()`, lecture du slot AD-4 (clé applicative paramétrée), repli plain-text. Adaptateur MINCE (R20/R21).
- **Dev-5** — `z_mindmap_node_card.dart` / `z_mindmap_list_view.dart` (UPDATE si nécessaire) : prise en compte du mode compact dans le rendu (masquage du contenu long). Additif.
- **Dev-6** — `lib/zcrud_mindmap.dart` (UPDATE) : `export` des nouveaux symboles publics.
- **Dev-7** — Tests (`packages/zcrud_mindmap/test/`, `flutter test` R14) : `z_mindmap_view_controls_test.dart` (AC2/AC3/AC4/AC5/AC6/AC10), `z_mindmap_markdown_content_test.dart` (AC8), extension round-trip modèle (AC7 dans `z_mindmap_node_test.dart` sans le modifier destructivement, ou nouveau fichier). Chaque test load-bearing accompagné de son injection (§ R3).
- **Doc-1** — `architecture.md` § AD-28 : note de résolution OQ-S5 (AC9). *(hors code ; ⚠️ NON-∥ si un autre workstream édite `architecture.md` — sérialiser cette écriture avec l'orchestrateur.)*
- **Doc-2** — memlog : entrée OQ-S5 résolue (AC9).

---

## Tâches (T)

- [x] **T1** (AC1/AC6/D8) — Ossature ADDITIVE posée : `z_mindmap_view_controls.dart` (`ZMindmapViewController` + `ZMindmapViewLabels`), paramètres optionnels `controller`/`viewLabels` sur `ZMindmapView`, `export` barrel. Suite E10 rejouée INCHANGÉE ⇒ VERTE (114 tests).
- [x] **T2** (AC2/D4) — Zoom piloté : API `graphite` 1.2.1 vérifiée (`transformationController` DOCUMENTÉ mais ABSENT du constructeur ⇒ InteractiveViewer interne non pilotable) ⇒ enveloppe `Transform.scale` EXTERNE clampée + neutralisation du zoom interne (`min=max=1`), sans forker graphite. Boutons in/out/reset. INJ-1 prouvée RED.
- [x] **T3** (AC3/AC10/D5/D7) — Mode compact : `ValueNotifier<bool>` + rendu condensé label-seul (masquage `content`), rebuild ciblé. INJ-2 (masquage) + SM-1 (zoom ne reconstruit pas les nœuds) prouvées RED.
- [x] **T4** (AC4/AC10/D5) — Plein-écran toggle (défaut off), affordance de sortie étiquetée (`exitFullscreen`). INJ-3b (défaut off) verte.
- [x] **T5** (AC5/D6) — Super-racine opt-in réutilisant `usesVirtualRoot` (graphe + liste), 1 racine ⇒ jamais. INJ-3 prouvée RED.
- [x] **T6** (AC7/D1/D3) — Verrou modèle : ensemble de clés ÉMISES figé (`{id,label,level,children}` [+content/extension]), `content` texte brut, round-trip byte-préservé d'un payload rich dans `extra`. INJ-4 prouvée RED. **Modèle NON modifié.**
- [x] **T7** (AC8/D2/D3) — `ZMindmapMarkdownContent` : compose `ZMarkdownReader`+`const ZDeltaCodec()`, lecture slot AD-4, repli plain-text. Scan machine (zéro `implements/extends ZCodec`, zéro heuristique). R22 round-trip identité. INJ-6/INJ-7 prouvées RED.
- [x] **T8** (AC10/D7) — a11y/thème sur tous les contrôles (≥48 dp `constraints`, `Semantics(button,label)` externalisés, directionnel, thème injecté). Scan conformité (0 couleur codée en dur) + conformance E10 pré-existant couvrant les nouveaux fichiers.
- [~] **T9** (AC9/Doc) — DÉFÉRÉ à l'orchestrateur (DW-ES72-3) : note AD-28 + memlog. Texte proposé consigné en Completion Notes (écriture `architecture.md` sérialisée, hors périmètre code de cette story).
- [x] **T10** — Vérif verte réelle : `flutter test` zcrud_mindmap RC=0 (140 tests) + `graph_proof.py` RC=0 (ACYCLIQUE, CORE OUT=0, 20 nœuds, **0 nouvelle arête**) + `melos list`=20 + `dart analyze` ciblé SUCCESS.

---

## Injections R3 prévues (preuve NON-POWERLESS — chaque garde rougit quand on la neutralise)

- **INJ-1 (AC2)** — retirer `clamp(minScale, maxScale)` du zoom ⇒ N zoom-in dépasse `maxScale` ⇒ test RED (« échelle ≤ maxScale »).
- **INJ-2 (AC3)** — router le toggle compact par un `setState`/notifier d'ancêtre (au lieu du `ValueNotifier` ciblé) ⇒ témoin « rebuilds d'un nœud frère non concerné » > 0 ⇒ RED (SM-1). Variante : compact ne masque pas `content` ⇒ assertion de masquage RED.
- **INJ-3 (AC5)** — forcer `usesVirtualRoot=true` (ou afficher la super-racine) pour une forêt à 1 racine ⇒ test « 1 racine ⇒ pas de super-racine » RED.
- **INJ-3b (AC4/AC6)** — faire du plein-écran le défaut ⇒ test E10 de layout inline (pré-existant) RED.
- **INJ-4 (AC7)** — ajouter un champ rich-text à `ZMindmapNode` / l'insérer dans `_knownKeys` ⇒ verrou « `_knownKeys` == set figé » RED et/ou round-trip RED.
- **INJ-5 (AC8, R22)** — remplacer `const ZDeltaCodec()` par un codec ré-encodant les ops ⇒ round-trip « payload rendu == payload stocké » RED.
- **INJ-6 (AC8, scan)** — introduire un `class … implements ZCodec` (ou une heuristique `startsWith('[')`) dans `zcrud_mindmap` ⇒ scan anti-nouveau-codec RED.
- **INJ-7 (AC8, repli)** — retirer le repli plain-text ⇒ nœud sans payload AD-4 rendu vide ⇒ test de repli RED.

> Note R20 (leçon ES-6.1 MEDIUM-1) : `ZMindmapMarkdownContent` est un **adaptateur** réutilisant `ZMarkdownReader`. Un test qui n'assert QUE des propriétés protégées par `ZMarkdownReader` serait POWERLESS. Ancrer les assertions AC8 sur ce que **l'adaptateur** possède : la **résolution du payload depuis le slot AD-4**, le **repli plain-text**, l'**identité du codec passé** — pas sur le rendu interne de `ZMarkdownReader`.

---

## Vérif verte à rejouer RÉELLEMENT (RC capturé HORS pipe — R15 ; runner FLUTTER — R14)

```bash
# 1) Tests du package CIBLE — zcrud_mindmap est Flutter (R14), RC hors pipe (R15)
cd packages/zcrud_mindmap && flutter test; echo "RC_mindmap=$?"
# Attendu : 78 tests E10 pré-existants INCHANGÉS VERTS + nouveaux tests ES-7.2 verts.

# 2) Graphe : acyclicité + CORE OUT=0 + AUCUNE nouvelle arête (l'arête
#    zcrud_mindmap -> zcrud_markdown EXISTE déjà ; ES-7.2 n'en ajoute pas)
python3 scripts/dev/graph_proof.py; echo "RC_graph=$?"
# Attendu : ACYCLIQUE, CORE OUT=0, 20 nœuds, arêtes INCHANGÉES (0 nouvelle).

# 3) Aucun nouveau package
dart run melos list | wc -l   # Attendu : 20 (inchangé)

# 4) Analyse — ciblée en dev actif ; REPO-WIDE au gate de commit d'epic (CLAUDE.md)
cd packages/zcrud_mindmap && flutter analyze; echo "RC_analyze=$?"
#   au gate d'epic (workstreams au repos) : dart run melos run analyze ET melos run verify REPO-WIDE.
```

**Attendus** : `RC_mindmap=0`, `RC_graph=0`, `melos list`=20, `RC_analyze=0`. **0 nouvelle arête de graphe** (fait structurant : l'arête markdown préexiste).

---

## Dépendance inverse ES-7.1 ↔ ES-7.2 (CRUCIAL pour le séquencement)

**RÉPONSE : NON — ES-7.1 ne consomme AUCUNE API que 7.2 doit livrer d'abord ; pas de dépendance de code entrante. Ils sont PARALLÉLISABLES par conception (architecture l. 107).**

- ES-7.1 (`zcrud_study/.../z_study_mindmap_section.dart`) **compose l'API E10 DÉJÀ EXISTANTE** (`ZMindmapView`, `ZMindmapOutlineController`) — son AC dit littéralement « `ZMindmapView`/`ZMindmapOutlineController` (**existants**) sont composés ». Il n'a **pas besoin** que les contrôles ES-7.2 existent.
- La seule relation est un **contrat de STABILITÉ** : pour que la parallélisation tienne, **ES-7.2 doit être ADDITIF STRICT** (AC6/D8). Si ES-7.2 cassait une signature existante, ES-7.1 (en vol) se casserait. **AC6 est donc le garde-fou de la parallélisation.**
- Relation **soft/optionnelle** : si la section study-tools voulait *surfacer* les nouvelles affordances (zoom/compact/plein-écran), ES-7.1 *pourrait* les consommer — mais ce n'est **pas requis** par l'AC d'ES-7.1. À traiter, le cas échéant, en **améliration additive ultérieure**, pas en dépendance bloquante.
- **Conséquence séquencement** : ES-7.1 ∥ ES-7.2 OK (packages disjoints `zcrud_study` vs `zcrud_mindmap`). Sérialiser uniquement : (a) toute écriture de `architecture.md` (Doc-1), (b) `zcrud_study` (ES-7.1 seul l'écrit), (c) `zcrud_markdown` si un écart y était révélé (DW-ES72-2 ⇒ alors NON-∥).

---

## Arêtes de graphe impactées (AD-1)

- **Aucune nouvelle arête.** `zcrud_mindmap → zcrud_markdown` **existe déjà** (pubspec + `z_mindmap_api.dart`), et `zcrud_mindmap → zcrud_core` aussi. `ZMindmapMarkdownContent` **réutilise** l'arête markdown existante ; il ne crée pas d'arête.
- `graph_proof.py` attendu **INCHANGÉ** : ACYCLIQUE, **CORE OUT=0**, 20 nœuds, jeu d'arêtes identique. Toute nouvelle arête serait un signal d'over-reach (à justifier/refuser).

---

## Injections R3 / Invariants AD applicables (rappel — s'appliquent à CHAQUE tâche)

- **AD-1** : acyclique, CORE OUT=0 ; **0 nouvelle arête** attendue.
- **AD-2/AD-15** : réactivité Flutter-native ; état de vue en `ValueNotifier`/`ChangeNotifier` pur ; **aucun** `flutter_riverpod`/`get`/`provider`, `WidgetRef`/`Get.`/`Provider.of` ; **aucun `setState` global** ; controllers stables (SM-1).
- **AD-4** : payload rich dans le slot d'extension (`extra`/`extension`), clé applicative paramétrée ; `String` opaque ; callback `null` = affordance absente.
- **AD-7** : rich-text = controller isolé (celui de `ZMarkdownReader`), `ZCodec` pluggable réutilisé (`ZDeltaCodec` identité), **aucun nouveau pipeline**.
- **AD-10** : seam rich-text et super-racine défensifs (payload mal formé ⇒ repli, jamais de throw).
- **AD-13** : directionnel, `Semantics`, cibles ≥ 48 dp ; graphe `ExcludeSemantics`, liste = surface a11y.
- **AD-16** : round-trip nœud ne réémet jamais les clés de sync.
- **FR-26** : couleurs/dimensions du thème injecté (`ZcrudTheme`), repli `Theme.of`.
- **SM-S4** : combler à l'origine (`zcrud_mindmap`), jamais dupliquer dans `zcrud_study`.
- **R14** : `flutter test` (package Flutter). **R15** : RC hors pipe. **R20/R21/R22** : adaptateur mince, ancrage des tests sur l'objet propre, couture à l'origine, round-trip discriminant.

---

## Findings / dettes anticipés

- **DW-ES72-1 (RISQUE technique, AC2)** — pilotage du zoom vs `InteractiveViewer` interne de `graphite`. Si `graphite` 1.2.1 n'expose pas de controller externe, envelopper dans un `InteractiveViewer`/`Transform` externe (D4) sans forker `graphite` ; documenter le choix (double-zoom neutralisé) dans le Change Log. **Ne pas** dégrader l'AC2 en simple réglage de bornes sans contrôle user-facing.
- **DW-ES72-2 (SÉQUENCEMENT, R21)** — si un écart de `zcrud_markdown` est révélé (ex. rendu inline compact), R21 impose de le combler **dans `zcrud_markdown`**, ce qui rend la story **NON-∥** avec toute story écrivant `zcrud_markdown`. Objectif : rester dans `zcrud_mindmap` (composition seule). Si l'écart est inévitable, **re-séquencer** (sortir `zcrud_markdown` du vol parallèle) et le signaler à l'orchestrateur.
- **DW-ES72-3 (Doc-1)** — l'édition de `architecture.md` (note AD-28) est **hors code** et partagée : la **sérialiser** avec l'orchestrateur (jamais deux écritures concurrentes du même artefact planning).
- **DW-ES72-4 (portée)** — le mode flowchart legacy IFFD n'est **PAS** porté (`flutter_flow_chart`/`graphview` interdits — épics l. 89, AC ES-7.1). Ne pas l'introduire par la bande via « plein-écran ».
- **Note R20** — risque d'AC8 POWERLESS si les assertions portent sur les protections de `ZMarkdownReader` au lieu de l'objet propre à l'adaptateur (résolution slot + repli + identité du codec). Explicitement adressé § R3.

---

## DÉCISION OQ-S5 tranchée (résumé pour AC9 / memlog)

**OQ-S5 — rich-text dans les nœuds mindmap : RÉSOLU (conforme AD-28, matérialisé par ES-7.2).**

- **Décision** : le `content` d'un `ZMindmapNode` **reste texte brut** (`String?`) — **aucun** champ rich-text au modèle. Le rich-text est un **slot AD-4 opt-in** (`extension`/`extra`) rendu par un **`nodeContentBuilder` opt-in** `ZMindmapMarkdownContent`, **adaptateur MINCE** composant `ZMarkdownReader` + `ZDeltaCodec` **identité** de `zcrud_markdown` — **aucun nouveau codec**, **aucune** heuristique markdown-vs-Delta. Le builder **par défaut** reste texte brut ⇒ les autres apps ne sont pas forcées ; IFFD migre en câblant le builder + en stockant le Delta dans le slot, **sans** modifier `zcrud_mindmap`.
- **Justification** : (1) **réutilisation maximale** (leçon ES-6.1 : le pipeline rich-text = source unique, l'entité = adaptateur ; « aucun nouveau codec sauf justification forte » — aucune ici) ; (2) **AD-4/AD-10** — additif, défensif, extensible sans toucher le modèle ; (3) **AD-1** — réutilise l'arête `zcrud_mindmap → zcrud_markdown` existante, **0 nouvelle arête** ; (4) **non-imposition** — le défaut texte brut n'oblige aucune app à tirer un rendu riche.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, tool `Skill`, effort high).

### Debug Log References

- `flutter test` zcrud_mindmap → **RC=0, 140 tests** (114 E10 pré-existants INCHANGÉS + 26 nouveaux ES-7.2).
- `python3 scripts/dev/graph_proof.py` → **RC=0** : ACYCLIQUE, CORE OUT=0, 20 nœuds, 42 arêtes ; `zcrud_mindmap` → {`zcrud_core`, `zcrud_markdown`} (les 2 PRÉEXISTANTES, **0 nouvelle arête**).
- `dart run melos list | wc -l` → **20** (aucun nouveau package).
- `dart run melos exec --scope=zcrud_mindmap -- dart analyze` → **SUCCESS (RC=0)**.
- **Preuves R3 (mutation → RED → restauration ciblée)** rejouées réellement : INJ-1 (clamp zoom), INJ-2 (masquage compact), INJ-3 (super-racine 1 racine), INJ-4 (clé rich émise), INJ-6 (`implements ZCodec`), INJ-7 (repli plain-text), SM-1 (zoom reconstruit les nœuds) — **toutes ROUGES sous mutation, VERTES après restauration**. INJ-5/R22 (identité du codec) couverte par le test round-trip `ZDeltaCodec`.

### Completion Notes List

- **DÉCISION OQ-S5 (AD-28) IMPLÉMENTÉE, non re-décidée** : `ZMindmapNode.content` **reste `String?` texte brut** (modèle NON modifié) ; rich-text = **slot AD-4 opt-in** rendu par `ZMindmapMarkdownContent`, adaptateur **MINCE** composant `ZMarkdownReader` + `const ZDeltaCodec()` (identité) — **aucun nouveau codec, aucune heuristique**. `nodeContentBuilder` par défaut = texte brut ⇒ autres apps non forcées.
- **DW-ES72-1 tranché** : `graphite` 1.2.1 n'expose PAS de `TransformationController` (paramètre documenté mais absent du constructeur). Zoom piloté via `Transform.scale` EXTERNE (child pass-through ⇒ SM-1) + neutralisation du zoom interne (`min=max=1`). Pas de fork.
- **Périmètre STRICT respecté** : écritures UNIQUEMENT dans `packages/zcrud_mindmap/` ; **aucun** fichier `zcrud_study`/`zcrud_core`/`zcrud_markdown` touché. Aucun écart `zcrud_markdown` révélé (composition seule) ⇒ story restée ∥-safe (pas de déclenchement DW-ES72-2).
- **Éditions documentaires DÉFÉRÉES (DW-ES72-3, à appliquer par l'orchestrateur)** :
  - **Doc-1 — `architecture.md` § AD-28**, ajouter la note : « **OQ-S5 RÉSOLU (ES-7.2)** : le `content` d'un `ZMindmapNode` reste texte brut ; le rich-text est un slot AD-4 opt-in rendu par le `nodeContentBuilder` `ZMindmapMarkdownContent` — adaptateur mince composant `ZMarkdownReader` + `ZDeltaCodec` identité de `zcrud_markdown`, **aucun nouveau codec, aucune heuristique** ; le builder par défaut reste texte brut (aucune app forcée). Aucune nouvelle arête de graphe (réutilise `zcrud_mindmap → zcrud_markdown`). »
  - **Doc-2 — memlog**, entrée : « ES-7.2 / OQ-S5 : rich-text mindmap = réutilisation maximale (leçon ES-6.1) — pipeline rich-text source unique, l'entité mindmap n'est qu'un adaptateur ; content de nœud inchangé (additif, défensif AD-4/AD-10) ; combler à l'origine `zcrud_mindmap` (SM-S4), jamais dupliquer dans `zcrud_study`. »
- **sprint-status.yaml NON touché** (sérialisé par l'orchestrateur).

### File List

**Nouveaux (zcrud_mindmap) :**
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_controls.dart` — `ZMindmapViewController` (état de vue pur-Flutter, zoom clampé) + `ZMindmapViewLabels` (libellés a11y externalisés).
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart` — `ZMindmapMarkdownContent` (seam rich-text opt-in, adaptateur mince).
- `packages/zcrud_mindmap/test/z_mindmap_view_controls_test.dart` — AC2/AC3/AC4/AC5/AC6/AC10 (+ INJ-1/INJ-2/INJ-3/INJ-3b + SM-1).
- `packages/zcrud_mindmap/test/z_mindmap_markdown_content_test.dart` — AC8 (+ R22/INJ-5/INJ-6/INJ-7).
- `packages/zcrud_mindmap/test/z_mindmap_node_richtext_test.dart` — AC7 (+ INJ-4, AD-16).

**Modifiés (zcrud_mindmap) — additifs :**
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart` — `controller`/`viewLabels` optionnels, barre de contrôles, `Transform.scale` externe, super-racine graphe, plein-écran.
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart` — param `compact` (défaut false) + `_CompactLabel`.
- `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_list_view.dart` — `compactListenable`/`superRootLabel` optionnels + entête super-racine.
- `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` — exports des nouveaux symboles publics.

**NON modifié (verrou AC7)** : `packages/zcrud_mindmap/lib/src/domain/z_mindmap_node.dart` (modèle intact).

### Change Log

- **ES-7.2** — Comblement additif des écarts mindmap (zoom piloté/clampé, compact, plein-écran, super-racine multi-forêt) + matérialisation/preuve de la décision OQ-S5 (rich-text du `content` = slot AD-4 opt-in via adaptateur mince `ZMarkdownReader`+`ZDeltaCodec`, aucun nouveau codec). Strictement additif (E10 vert inchangé). Zoom externe `Transform.scale` (graphite 1.2.1 sans controller externe, DW-ES72-1). 0 nouvelle arête de graphe.
