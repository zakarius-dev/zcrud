---
baseline_commit: aaa7989612f5213509daae9ddbddb7a7513cd650
---

# Story ES-5.3 : Sections réordonnables + hub d'ajout + menu d'actions

Status: review

<!-- Epic ES-5 · Taille L · SÉQUENTIELLE vs ES-5.2 (review/done) · Package `zcrud_study` (présentation), MÊME package que 5.1/5.2. Dépend d'ES-5.2 done ; DERNIÈRE story STRUCTURANTE d'ES-5 avant ES-5.4 (ZFeatureAvailability). Workstream B — ISOLATION vs workstream A (ES-4 / scripts/ci / zcrud_flashcard / zcrud_session). -->

## Story

As a **utilisateur (et développeur intégrateur IFFD, Zakarius)**,
I want **réordonner le contenu d'une section « study tools » par glisser-déposer avec l'ordre CONSERVÉ entre sessions (persisté via `ZFolderContentsOrder`), ajouter du contenu via un hub paramétrique (`ZContentHubSheet`) et agir sur un item via un menu paramétrique (`ZItemActionsMenu`)**,
so that **j'organise mon dossier avec l'ergonomie IFFD, l'ordre étant restauré à l'ouverture suivante, SANS jamais réintroduire le bug historique de rebuild global (SM-1/ES-5.2 préservé) ni casser la décomposabilité keyée (ES-5.1)**.

---

## Contexte & problème (pourquoi cette story existe)

ES-5.1 a livré (done, golden 6/6) le **socle décomposable** : `ZStudyToolsSectionSpec` (`id`/`title`/`itemCount`/`itemBuilder`/`emptyState`/`addAction?`/`addActionIcon?`/`addActionSemanticLabel?`/`axis`) + `ZSectionedStudyLayout` (une frontière de widget keyée `ValueKey('section:$id')` par section, `ListView.builder`, ordre d'entrée préservé). ES-5.2 a livré (review, 19 tests) `ZStudyToolsPage` : le **scoping réactif ISOLÉ** — taper 100 caractères dans un champ scopé ne reconstruit QUE ce champ (`buildsA=101`, `buildsB=1`, `buildsPage=1`), zéro perte de focus (**objectif produit n°1 / SM-1 / NFR-S1**), controller `ZFormController` STABLE, `_ZStudyFormScope` (`InheritedWidget`), orientation `axis` (rail flashcards horizontal vs grilles verticales). La réordonnabilité/drag a été **explicitement DÉFÉRÉE d'ES-5.2 à ES-5.3** (cf. ES-5.2 §NON-périmètre l.47, `z_study_tools_section_spec.dart:82` « La réordonnabilité/drag (`ReorderableGridView`) reste HORS PÉRIMÈTRE (ES-5.3) »).

**ES-5.3 SOLDE les trois capacités d'ergonomie IFFD manquantes** (AD-25) :

1. **Sections réordonnables PERSISTANTES** — chaque section de contenu (grilles docs/notes/mindmaps) devient réordonnable par glisser-déposer ; l'ordre choisi **persiste** via `ZFolderContentsOrder` (FR-S7, ES-2.4) et l'application de l'ordre au rendu passe par `ZFolderContentsOrder.applyTo` → `applyOrder<T>` (tri stable pur, ES-1.2). **Aucune primitive de tri réinventée** ; **aucune modification du kernel** (`ZFolderContentsOrder` réutilisé EN LECTURE + `copyWith`).
2. **Hub d'ajout paramétrique** — `ZContentHubSheet` : la feuille d'ajout de contenu paramétrée par des entrées `ZContentHubEntry` (icon/label/enabled/hint/onTap) — remplace le monolithe IFFD `folder_content_creating_buttons.dart` (241 l.) / `folder_content_add_dialog_widget.dart` (550 l.). Icônes/labels **injectés** (i18n) ; **entrée désactivée / `onTap == null` ⇒ non actionnable** (AD-4).
3. **Menu d'actions par item paramétrique** — `ZItemActionsMenu` : menu d'actions sur un item, paramétré par un **enum de nature d'action** (`ZItemActionKind`) + callbacks ; **callback `null` = action ABSENTE** (AD-4). Comble l'absence IFFD (menu d'item **diffus**, aucun `PopupMenuButton` centralisé mesuré dans `lib/src/presentation/features/folders/`).

**Reconnaissance READ-ONLY IFFD (AUCUN fichier IFFD modifié)** — patterns de référence MESURÉS :
- Réordonnancement réel : `folder_study_tools_page.dart:1009,1369,1685` `ReorderableGridView.count(onReorder: …)` (paquet tiers `reorderable_grid_view: ^2.2.8`, `pubspec.yaml:154`). La logique de réordonnancement `onFolderContentReorder<T>` (`folder_study_tools_page.dart:300-343`) : `newIds = List.from(sortedIds); id = newIds.removeAt(oldIndex); newIds.insert(newIndex, id);` PUIS persiste via `folderContentsOrders.copyWith(subDocumentsIds/…)` → `folderContentsOrdersRepositoryProvider.update(...)`. L'application de l'ordre au rendu (`folder_study_tools_page.dart:256-259`) : `contentOrder.indexOf(a.id).compareTo(contentOrder.indexOf(b.id))` (équivalent NON stable de `applyOrder<T>`, que zcrud REMPLACE par le tri stable pur).
- Hub d'ajout : `folder_content_creating_buttons.dart` (241 l., `label:` l.95/141/222, `IconData icon` l.173) + `EmtyFolderContent` (`empty_folder_content.dart:128` bouton « Ajouter du contenu », `IconData icon` l.35).
- Menu d'item : **absent/diffus** — `grep PopupMenuButton|showMenu|onSelected` sur `features/folders/` = 0 occurrence. `ZItemActionsMenu` est donc une abstraction **propre neuve** (paramétrique, AD-4), pas un portage 1:1.

**⚠️ Décision de dépendance NON-NÉGOCIABLE (anti-inertie)** : zcrud n'importe **PAS** le paquet tiers `reorderable_grid_view` (arête lourde interdite, AD-1/AD-17 — le graphe de `zcrud_study` reste `→ zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations`). Le réordonnancement utilise **`ReorderableListView.builder` du SDK Flutter** (`package:flutter/material`, déjà transitivement disponible — `reorderable_list.dart:66`), directionnel et accessible par construction. Aucune nouvelle arête de package (`graph_proof.py` inchangé, `melos list` reste à 19 packages).

---

## Périmètre & NON-périmètre (garde-fous)

**DANS le périmètre ES-5.3** (package `zcrud_study` UNIQUEMENT) :

1. **Réordonnancement de section** — `z_sectioned_study_layout.dart` (MODIFIED) + `z_study_tools_section_spec.dart` (MODIFIED, slots ADDITIFS const-compatibles) :
   - Slots additifs sur `ZStudyToolsSectionSpec` : `itemIds` (`List<String>?`, ordre courant des ids rendus — clés stables de réordonnancement + calcul du nouvel ordre), `onReorder` (`void Function(int oldIndex, int newIndex)?` — **`null` = section NON réordonnable**, AD-4), `reorderHandleSemanticLabel` (`String?`, label a11y INJECTÉ de la poignée de drag — i18n).
   - Quand `onReorder != null` **et** `axis == Axis.vertical`, `_ZStudySection._buildItems` rend un **`ReorderableListView.builder`** (`shrinkWrap: true`, `physics: NeverScrollableScrollPhysics()` — imbriqué dans le `ListView.builder` du layout), chaque enfant keyé `ValueKey(spec.itemIds![index])`, poignée directionnelle a11y ≥ 48 dp (`ReorderableDragStartListener` + `Semantics`). Quand `onReorder == null` : rendu ES-5.2 inchangé (non-régression).
   - Le rail horizontal flashcards (`axis == Axis.horizontal`) **N'EST PAS réordonnable** dans cette story (documenté — l'epic ne cible que « grilles réordonnables docs/notes/mindmaps »).
2. **Application + persistance de l'ordre** — **RÉUTILISATION** de `ZFolderContentsOrder` (ES-2.4, kernel, EN LECTURE + `copyWith`) et `applyOrder<T>` / `ZFolderContentsOrder.applyTo<T>` (tri stable, ES-1.2). L'appelant fournit `itemIds` = ids déjà ordonnés (via `order.applyTo(sectionKey, items, idOf:)`) ; `onReorder(oldIndex, newIndex)` calcule le nouvel ordre (`removeAt`/`insert`) et persiste `order.copyWith(sectionOrders: {…order.sectionOrders, sectionKey: newIds})`. Un helper pur PRÉSENTATION `zReorderIds(List<String> ids, int oldIndex, int newIndex)` (removeAt/insert, opération DISTINCTE d'`applyOrder` — jamais un doublon du tri stable) est fourni pour la symétrie test/impl.
3. **`ZContentHubSheet`** — `z_content_hub_sheet.dart` (NEW) : widget + entrée `ZContentHubEntry` (`icon` `IconData` injectée, `label` `String` localisé injecté, `enabled` `bool`, `hint` `String?` injecté, `onTap` `VoidCallback?`). `ListView.builder`, cibles ≥ 48 dp, `Semantics`, directionnel, thème injecté (`ZcrudTheme.of`). **`enabled == false` OU `onTap == null` ⇒ entrée NON actionnable** (rendue désactivée, tap sans effet — AD-4). Méthode statique `ZContentHubSheet.show(context, entries:)` (`showModalBottomSheet`) + le widget testable en isolation.
4. **`ZItemActionsMenu`** — `z_item_actions_menu.dart` (NEW) : widget + `ZItemAction` (enum `ZItemActionKind { open, rename, move, share, delete, … }` extensible + `label` injecté + `icon` injectée + `onSelected` `VoidCallback?`). **`onSelected == null` ⇒ action ABSENTE du menu** (jamais un item grisé silencieux ni un no-op — AD-4). Rendu via `PopupMenuButton`/feuille, ≥ 48 dp, `Semantics`, labels injectés.
5. **Export barrel** — `lib/zcrud_study.dart` (MODIFIED) exporte les types publics nouveaux (`ZContentHubSheet`, `ZContentHubEntry`, `ZItemActionsMenu`, `ZItemAction`, `ZItemActionKind`, `zReorderIds`). Impl sous `lib/src/`.
6. **Golden ES-5.1/5.2** — régénéré (`study_tools_sectioned.png`) **SI** l'apparence change (poignée de drag visible sur une section réordonnable de la fixture) — `flutter test --update-goldens` + re-commit du PNG. Le harnais reste DISCRIMINANT (byte-diff m1/m2/m3 + comptage N→N-1).

**HORS périmètre (NE PAS implémenter ici)** :
- `ZFeatureAvailability` (disponibilité progressive des éditeurs) → **ES-5.4**.
- Toute modification de `zcrud_study_kernel` (`ZFolderContentsOrder`/`applyOrder` réutilisés EN L'ÉTAT — aucune primitive d'intégrité neuve), de `zcrud_core` (AD-1), de `scripts/ci`, de `sprint-status.yaml` (workstream A actif — ISOLATION).
- Toute arête vers un satellite lourd (`zcrud_flashcard`/`zcrud_mindmap`/`zcrud_note`/`zcrud_document`/`zcrud_session`) ou tiers (`reorderable_grid_view`) : les données réelles/cartes d'item viennent des `itemBuilder`/entrées fournis par l'appelant.
- La **résolution de collection** / la persistance Firestore réelle de `ZFolderContentsOrder` (`ZFirestorePathResolver`, `study_content_orders/{folderId}`) → ES-3.2 (l'appelant injecte l'`onReorder` qui persiste ; la story teste le contrat ordre↔`ZFolderContentsOrder` en mémoire, pas le backend).
- La réconciliation/purge des ids d'items supprimés d'un ordre (repository/UI) → hors périmètre (déjà documenté sur `ZFolderContentsOrder` D4).

---

## Acceptance Criteria

Chaque AC est formulé à **pouvoir discriminant** (R12) : un test DOIT pouvoir le faire échouer si l'implémentation dévie. **AC1 (ordre persisté) et AC2 (SM-1 non régressé) sont les AC CENTRAUX.**

**AC1 — [CENTRAL] Réordonner une section reflète le nouvel ordre dans `ZFolderContentsOrder`, et l'ordre lu est APPLIQUÉ au rendu (tri stable)**
**Given** une section réordonnable (`onReorder != null`, `axis: Axis.vertical`) dont les items sont rendus dans l'ordre issu de `order.applyTo(sectionKey, items, idOf:)` à partir d'un `ZFolderContentsOrder` initial, et `itemIds` = ces ids ordonnés
**When** on déplace l'item à `oldIndex` vers `newIndex` (glisser-déposer simulé sur le `ReorderableListView`, déclenchant `onReorder(oldIndex, newIndex)`)
**Then** le callback `onReorder` calcule le nouvel ordre (`zReorderIds` : `removeAt(oldIndex)` puis `insert(newIndex)`) et produit un `ZFolderContentsOrder` **persisté** dont `orderFor(sectionKey)` == le nouvel ordre attendu (l'item déplacé à sa nouvelle position, ordre relatif des autres préservé)
**And** re-rendre la section avec ce nouvel ordre replace visuellement l'item à `newIndex` (ordre visuel == `applyTo(sectionKey, items)` du nouvel ordre — l'ordre persisté est bien APPLIQUÉ, pas ignoré)
**And** (pouvoir discriminant — R3-I1) si le rendu **ignore l'ordre persisté** (items rendus dans leur ordre brut d'entrée, `applyTo` non appelé) OU si `onReorder` **ne produit pas** un `ZFolderContentsOrder` reflétant le déplacement (no-op), l'assertion sur `orderFor(sectionKey)` / l'ordre visuel ROUGIT.

**AC2 — [CENTRAL / SM-1 non régressé / objectif n°1] La réordonnabilité ne réintroduit AUCUN rebuild global**
**Given** une `ZStudyToolsPage` à deux sections, la section A réordonnable (`onReorder != null`) contenant un champ éditable scopé (`ZFieldListenableBuilder`) + un observateur structurel de page, la section B (autre section) avec un champ voisin scopé, compteurs `buildsA`/`buildsB`/`buildsPage`
**When** (a) on tape 100 caractères dans le champ scopé de A, puis (b) on réordonne la section A
**Then** (a) taper reste SM-1-conforme : `buildsA` croît de 100, `buildsB` reste à 1, `buildsPage` reste à 1 (non-régression ES-5.2), focus jamais perdu
**And** (b) réordonner la section A **ne reconstruit PAS** la section B ni l'observateur de page (`buildsB == 1`, `buildsPage == 1` après réordonnancement) — la frontière keyée `ValueKey('section:$id')` reste la seule frontière de rebuild, aucun `setState` à l'échelle page/section, aucun `ListenableBuilder(listenable: controller)` enveloppant
**And** (pouvoir discriminant — R3-I2) si le réordonnancement est câblé via un `setState` au niveau page/section OU enveloppe les sections dans un `ListenableBuilder` global, `buildsB` et/ou `buildsPage` deviennent > 1 ⇒ **le test ROUGIT**.

**AC3 — Hub d'ajout paramétrique `ZContentHubSheet` : entrées injectées, désactivation honorée (AD-4)**
**Given** un `ZContentHubSheet` paramétré par `List<ZContentHubEntry>` mêlant (i) une entrée active (`enabled: true`, `onTap` non-null, `icon`/`label`/`hint` injectés) et (ii) une entrée désactivée (`enabled: false` OU `onTap: null`)
**When** on rend la feuille et on **tape** sur chaque entrée
**Then** l'entrée active invoque son `onTap` **exactement une fois** (compteur = 1) et affiche son `icon`/`label`/`hint` INJECTÉS (jamais un label FR/EN codé en dur)
**And** l'entrée désactivée est rendue **non actionnable** (tap sans effet, compteur = 0) et signalée comme désactivée (`Semantics` / apparence thémée)
**And** (pouvoir discriminant — R3-I3) si une entrée `enabled: false`/`onTap: null` reste actionnable (tap déclenche un effet) OU si le label/icône est codé en dur, l'assertion ROUGIT.

**AC4 — Menu d'actions par item `ZItemActionsMenu` : paramétré par enum kind + callbacks, `null` = action absente (AD-4)**
**Given** un `ZItemActionsMenu` paramétré par une `List<ZItemAction>` mêlant des actions à `onSelected` non-null (ex. `open`, `rename`) et au moins une à `onSelected: null` (ex. `delete`)
**When** on ouvre le menu et on **sélectionne** une action à callback non-null
**Then** son `onSelected` est invoqué **exactement une fois** ; son `label`/`icon` INJECTÉS sont affichés
**And** l'action à `onSelected == null` n'apparaît **PAS** dans le menu (ABSENTE, jamais un item grisé silencieux ni un no-op — AD-4)
**And** (pouvoir discriminant — R3-I4) si une action `onSelected == null` est rendue/actionnable, ou si l'action à callback n'invoque pas le callback injecté, l'assertion ROUGIT.

**AC5 — Golden réordonné : l'ordre visuel SUIT l'ordre persisté (harnais DISCRIMINANT préservé)**
**Given** le harnais golden ES-5.1/5.2 (`study_tools_page_golden_test.dart` + `_fixtures.dart`)
**When** on rend la fixture canonique avec une section réordonnable (poignée de drag visible)
**Then** l'apparence correspond au golden committé régénéré (`matchesGoldenFile`), et si l'apparence change, le PNG est régénéré (`--update-goldens`) + re-commité
**And** (pouvoir discriminant) le byte-diff m1/m2/m3 (fusion/permutation/altération) et le comptage structurel N→N-1 restent ROUGES sous mutation (le pouvoir discriminant du golden ES-5.1 n'est PAS affaibli) ; permuter l'ordre d'entrée d'une section réordonnable change le rendu (l'ordre visuel suit l'ordre appliqué).

**AC6 — Invariants transverses AD-2/AD-13/AD-15 respectés (a11y + directionnel + thème injecté)**
**Given** toutes les surfaces nouvelles/modifiées de `zcrud_study` (layout réordonnable + hub + menu)
**When** on les analyse
**Then** **AUCUN** import/symbole de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`/`ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`) — réactivité Flutter-native pure ; injection thème via `ZcrudTheme.of` (repli `Theme.of`, AUCUNE couleur/`IconData`/label codé en dur)
**And** la poignée de drag, les entrées du hub et les items du menu ont des cibles interactives ≥ 48 dp, des `Semantics` explicites (label a11y INJECTÉ pour la poignée), un rendu directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, jamais `.left/.right`/`Positioned(left:`), `ListView.builder` (jamais `ListView(children:)`), `const` où possible (AD-13/NFR-S6/NFR-S7).

**AC7 — Acyclicité AD-1 / CORE OUT=0 préservées, aucune arête lourde, vérif verte (RC hors pipe)**
**Given** le package `zcrud_study` après ajout du réordonnancement + hub + menu
**When** on rejoue les gates ciblés
**Then** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE** avec **out-degree(zcrud_core) == 0** (arêtes de `zcrud_study` inchangées : `→ zcrud_core`, `→ zcrud_study_kernel`, `→ zcrud_annotations` ; AUCUNE arête `reorderable_grid_view` ni satellite lourd — `ReorderableListView` du SDK Flutter)
**And** `flutter test` (RUNNER Flutter, R14) est **VERT RC=0** (golden régénéré + non-régression SM-1 + AC1/AC3/AC4 discriminants) ; `dart analyze` (zcrud_study) RC=0 ; `melos list` reste à 19 packages.

---

## Tasks / Subtasks

- [x] **T1 — Slots réordonnables ADDITIFS sur `ZStudyToolsSectionSpec` (AC1, AC2, AC6)**
  - [x] `z_study_tools_section_spec.dart` : ajouter `final List<String>? itemIds;`, `final void Function(int oldIndex, int newIndex)? onReorder;` (`null` = non réordonnable, AD-4), `final String? reorderHandleSemanticLabel;` — tous const-compatibles, additifs (défauts `null` ⇒ non-cassant pour ES-5.1/5.2 et les fixtures golden). Docstrings i18n/injection ; corriger la note `:82` (« réordonnabilité … HORS PÉRIMÈTRE ES-5.3 » → livrée ici, vertical uniquement). Assert de cohérence `onReorder != null ⇒ itemIds != null && itemIds!.length == itemCount` (AD-10 : assert de développement, pas de throw runtime persistant).

- [x] **T2 — Rendu réordonnable dans le layout (AC1, AC2, AC6)**
  - [x] `z_sectioned_study_layout.dart` : dans `_ZStudySection._buildItems`, quand `spec.onReorder != null && spec.axis == Axis.vertical` → `ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: spec.itemCount, onReorder: spec.onReorder!, itemBuilder: …)` ; chaque enfant keyé `ValueKey(spec.itemIds![index])` (clé STABLE requise par `ReorderableListView`), poignée directionnelle a11y (`ReorderableDragStartListener` + `Semantics(label: spec.reorderHandleSemanticLabel ?? spec.title)`, cible ≥ 48 dp). Sinon (défaut `onReorder == null`) : rendu ES-5.2 inchangé (`Column`/rail). Directionnel, thème injecté.
  - [x] La frontière keyée `ValueKey('section:$id')` de `ZSectionedStudyLayout` reste INCHANGÉE (SM-1) : réordonner ne touche que le sous-arbre de la section.

- [x] **T3 — Helper pur de réordonnancement + réutilisation `ZFolderContentsOrder` (AC1)**
  - [x] `zReorderIds(List<String> ids, int oldIndex, int newIndex)` (util présentation, pure, totale) : `newIds = List.of(ids); id = newIds.removeAt(oldIndex); newIds.insert(newIndex, id); return newIds;` — opération DISTINCTE d'`applyOrder` (déplacement ≠ tri stable partiel). Défensif sur indices hors bornes (clamp, pas de throw).
  - [x] Documenter le contrat de persistance : l'appelant fournit `itemIds` via `order.applyTo(sectionKey, items, idOf:)` et, dans `onReorder`, persiste `order.copyWith(sectionOrders: {...order.sectionOrders, sectionKey: zReorderIds(order.orderFor(sectionKey)-ou-itemIds, old, new)})`. **AUCUNE écriture kernel** ; `ZFolderContentsOrder` réutilisé EN LECTURE + `copyWith`.

- [x] **T4 — `ZContentHubSheet` + `ZContentHubEntry` (AC3, AC6)**
  - [x] `z_content_hub_sheet.dart` (NEW) : `ZContentHubEntry` (`IconData icon`, `String label`, `bool enabled = true`, `String? hint`, `VoidCallback? onTap`) ; `ZContentHubSheet` (`List<ZContentHubEntry> entries`) → `ListView.builder`, `ListTile`/tuiles ≥ 48 dp, `Semantics`, directionnel, thème injecté. `enabled == false || onTap == null` ⇒ tuile désactivée (non actionnable, `Semantics` désactivée). Statique `ZContentHubSheet.show(context, entries:)` (`showModalBottomSheet`).

- [x] **T5 — `ZItemActionsMenu` + `ZItemAction`/`ZItemActionKind` (AC4, AC6)**
  - [x] `z_item_actions_menu.dart` (NEW) : enum `ZItemActionKind` (extensible : `open`/`rename`/`move`/`share`/`delete`, + `custom`) ; `ZItemAction` (`ZItemActionKind kind`, `String label` injecté, `IconData icon` injectée, `VoidCallback? onSelected`) ; `ZItemActionsMenu` (`List<ZItemAction> actions`) rendu via `PopupMenuButton`/feuille — **filtre les actions à `onSelected == null`** (absentes, AD-4). Cibles ≥ 48 dp, `Semantics`, labels injectés.

- [x] **T6 — Export barrel (AC1..AC4)**
  - [x] `lib/zcrud_study.dart` : exporter `z_content_hub_sheet.dart`, `z_item_actions_menu.dart` + les slots additifs (déjà via `z_study_tools_section_spec.dart`) + `zReorderIds`. Impl sous `lib/src/`.

- [x] **T7 — Tests discriminants réordonnancement + SM-1 non-régression (AC1, AC2) — le cœur**
  - [x] `test/z_study_tools_reorder_test.dart` (NEW) : (AC1) fixture avec `ZFolderContentsOrder` initial → `applyTo` → render `ReorderableListView` → drag simulé → `onReorder` → `copyWith` → `expect(order.orderFor(sectionKey), attendu)` + ordre visuel re-rendu ; (AC2) 2 sections, section A réordonnable + champ scopé + observateur page, section B champ voisin — 100 frappes ⇒ `buildsA=101`/`buildsB=1`/`buildsPage=1` (non-régression ES-5.2) PUIS réordonnancement A ⇒ `buildsB=1`/`buildsPage=1`.

- [x] **T8 — Tests hub + menu (AC3, AC4)**
  - [x] `test/z_content_hub_sheet_test.dart` (NEW) : entrée active tap ⇒ compteur=1 + icône/label/hint injectés trouvés ; entrée désactivée tap ⇒ compteur=0 + `Semantics` désactivée.
  - [x] `test/z_item_actions_menu_test.dart` (NEW) : action à callback ⇒ sélection invoque le callback (compteur=1) + label/icône injectés ; action `onSelected: null` ⇒ ABSENTE du menu.

- [x] **T9 — Golden (AC5) + injections R3 + vérif verte (AC1, AC2, AC3, AC4, AC7)**
  - [x] Régénérer `study_tools_sectioned.png` SI l'apparence change (poignée de drag sur une section réordonnable de la fixture) ; harnais discriminant préservé (byte-diff m1/m2/m3 + comptage N→N-1). Sinon golden inchangé.
  - [x] R3-I1..I5 joués RÉELLEMENT (RC=1 RED capturé au Debug Log), restaurés par ÉDITION CIBLÉE (aucun `git checkout/restore/stash` — working-tree partagé workstream A), re-vérif verte.
  - [x] Vérif verte CIBLÉE (RC hors pipe R15) : `flutter test` RC=0, `dart analyze` RC=0, `graph_proof.py` RC=0 (`melos list`=19), scans interdits vides.

---

## Dev Notes

### Architecture — invariants NON-NÉGOCIABLES applicables (AD)
- **AD-25** [archi:243-246] — `ZStudyToolsPage` = liste de sections paramétriques ; **grilles réordonnables docs/notes/mindmaps** ; **l'ordre persiste via `ZFolderContentsOrder` (`applyOrder<T>`, tri stable pur)** ; chaque section = scoping `ValueListenable` isolé (une frappe/édition/réordonnancement dans une section ne reconstruit AUCUNE autre — SM-1) ; **aucun `setState` page/section** ; `ZItemActionsMenu`/`ZContentHubSheet` **paramétrés (`null` = action absente**, AD-4) ; couleurs/labels/l10n injectés, directionnel / ≥ 48 dp / `Semantics` / `ListView.builder`.
- **AD-2** [archi:44] — `ZFormController` pur-Flutter ; un champ = un `ZFieldListenableBuilder`/`ValueListenableBuilder` n'écoutant que SA tranche ; controller STABLE ; **jamais** de `setState` de formulaire ni de closure de `build()` recréant les controllers. Le réordonnancement N'EST PAS une valeur de champ : il ne passe PAS par un `setState` page/section (il vit dans le sous-arbre keyé de la section).
- **AD-4** [archi] — composition, pas héritage de vues ; slots additifs versionnés ; **callback/valeur `null` = capacité ABSENTE** (jamais un no-op silencieux ni un item grisé muet) : `onReorder == null` (section non réordonnable), `ZContentHubEntry.onTap == null`/`enabled == false` (entrée non actionnable), `ZItemAction.onSelected == null` (action absente du menu).
- **AD-13** [archi:51] — RTL directionnel, `Semantics` explicites, cibles ≥ 48 dp, couleur jamais seul canal, thème/l10n injectés (`ZcrudScope`/`ThemeExtension`, repli `Theme.of`). La **poignée de drag** porte un `Semantics(label:)` INJECTÉ (i18n) et une cible ≥ 48 dp.
- **AD-15** [archi:44] — AUCUN gestionnaire d'état dans `zcrud_study` ; injection via `ZcrudScope` (jamais `ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`).
- **AD-1 / AD-17** [archi:54,89] — graphe **acyclique**, `zcrud_study → zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations` (jamais l'inverse), **out-degree(zcrud_core)=0**. **NE PAS** tirer `reorderable_grid_view` ni un satellite lourd — `ReorderableListView` du SDK Flutter suffit.
- **AD-10** [z_folder_contents_order.dart] — décodage/tri **défensif, jamais de throw** ; `zReorderIds` clampe les indices hors bornes.
- **AD-26** [archi:...] — `ZFolderContentsOrder` est un **état PERSONNEL** séparé du sous-arbre partageable ; réordonner n'écrit QUE cet état personnel (jamais `ZStudyFolder`). Réutilisé EN LECTURE + `copyWith` (aucune écriture kernel).

### API réutilisée (déjà livrée, NE PAS réimplémenter ni dupliquer)
- **`ZFolderContentsOrder`** [`zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart`, ES-2.4] — état personnel clé par `folderId`. Réutiliser : `orderFor(sectionKey) → List<String>` (`:284`, ordre courant), `applyTo<T>(sectionKey, items, {idOf, unordered}) → List<T>` (`:294`, DÉLÈGUE à `applyOrder`, tri stable pur), `copyWith(sectionOrders:)` (`:258`, immuabilité PROFONDE M3 — la map fournie est rendue non modifiable ; `sectionOrders` ordre-sensible dans une liste). **Exporté par le barrel kernel** (`export … hide ZFolderContentsOrderZcrud`). ⛔ **NE PAS modifier le kernel.**
- **`applyOrder<T>`** [`apply_order.dart`, ES-1.2] — tri stable d'une collection selon un ordre partiel ; item absent de l'ordre en position déterministe (`ZUnorderedPlacement.end` par défaut), id d'ordre sans item ignoré, doublon → 1re occurrence. Exporté par le barrel kernel. **NE PAS réinventer** un tri (contraste avec l'IFFD `contentOrder.indexOf(a).compareTo(indexOf(b))` non stable, remplacé).
- **`ZStudyToolsSectionSpec`** [ES-5.1/5.2] — descripteur étendu ici par des slots additifs (jamais un type parallèle générique `ZStudyToolsSection<T>` qui dupliquerait le layout — le nommage de l'epic est honoré par extension du descripteur existant, COMPOSITION AD-4).
- **`ZSectionedStudyLayout`** / **`ZStudyToolsPage`** [ES-5.1/5.2] — COMPOSÉS, jamais réimplémentés. Le rendu réordonnable s'insère dans `_ZStudySection._buildItems` (frontière keyée intacte).
- **`ZcrudTheme.of(context)`** [`theme/z_theme.dart:296`] — tokens `gapS`/`gapM`/`gapL`/`radiusS`/`radiusM`/`labelTextStyle` (repli `Theme.of`). Aucune couleur/label/icône en dur.
- **`ReorderableListView.builder`** [`package:flutter/material`, SDK, `reorderable_list.dart:66`] — réordonnancement directionnel, accessible par construction, drag handles ; `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()` quand imbriqué. **Pas de paquet tiers.**

### Réutilisation `ZFolderContentsOrder` — schéma du contrat (RÉORDONNANCEMENT)
```
Rendu :   order.applyTo(sectionKey, items, idOf:) → items ORDONNÉS (tri stable, ES-1.2)
           → itemIds = ces ids → ReorderableListView.builder (enfant keyé ValueKey(id))
Drag  :   onReorder(oldIndex, newIndex)
           → newIds = zReorderIds(order.orderFor(sectionKey)-ou-itemIds, oldIndex, newIndex)  [removeAt/insert]
           → order.copyWith(sectionOrders: {...order.sectionOrders, sectionKey: newIds})       [PERSISTÉ par l'appelant]
           → re-render : order'.applyTo(sectionKey, items) reflète le déplacement
```
L'appelant (app/binding) porte la persistance réelle (repository ES-3.2) ; la story teste le contrat ordre↔`ZFolderContentsOrder` EN MÉMOIRE.

### GOTCHA `ReorderableListView` imbriqué (R14 — Flutter)
Imbriqué dans le `ListView.builder` de `ZSectionedStudyLayout`, `ReorderableListView` DOIT être `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()` (sinon exception « viewport unbounded height » / double-scroll — cf. IFFD `folder_study_tools_page.dart:1017-1019` `shrinkWrap: true, physics: NeverScrollableScrollPhysics()`). Chaque enfant DOIT avoir une `Key` STABLE (`ValueKey(itemId)`), sans quoi `ReorderableListView` lève « Every item … must have a key ».

### GOTCHA RUNNER (R14) — `flutter test`, PAS `dart test`
`zcrud_study` déclare `flutter: sdk: flutter` → package **Flutter**. Les tests importent `flutter_test`/`dart:ui` → tournent UNIQUEMENT sous `flutter test`. Le gate `gate:web-determinism` (`dart test -p node`) auto-exclut les packages Flutter — `zcrud_study` hors couverture. `codegen-distribution` : aucun `@ZcrudModel` dans `zcrud_study` (pas de `*.g.dart`), sans objet.

### GOTCHA RC (R15) — mesurer le vrai code de sortie HORS pipe
```bash
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
```
Un `flutter test | tee` renvoie le RC de `tee`, pas du test.

### Golden — régénération conditionnelle
Une section de la fixture canonique devenant réordonnable fera apparaître une **poignée de drag** → pixels différents → `matchesGoldenFile` ROUGIT tant que le PNG n'est pas régénéré. Prévoir `flutter test --update-goldens` + re-commit `test/golden/goldens/study_tools_sectioned.png` (au commit d'epic ES-5). SI la fixture canonique reste sans section réordonnable (poignée non rendue), le golden est INCHANGÉ — décider selon l'apparence réelle. Le pouvoir discriminant (byte-diff m1/m2/m3 + comptage N→N-1) NE DOIT PAS régresser.

### Injections R3 prévues (défaut réel → test RED → restauration par ÉDITION CIBLÉE, R13)
> JAMAIS `git checkout/restore/stash` (working-tree partagé workstream A). Restauration par édition ciblée du fichier, RC RED puis GREEN consignés au Debug Log.

| # | Injection (édition ciblée dans la PROD) | Test attendu RED | Restauration |
|---|---|---|---|
| **R3-I1** (ordre appliqué + persisté — CENTRAL AC1) | Rendu : ignorer l'ordre (rendre les items dans leur ordre BRUT d'entrée, ne PAS appeler `applyTo`) OU `onReorder` no-op (ne produit pas de `ZFolderContentsOrder` déplacé) | `test AC1` : `expect(order.orderFor(sectionKey), newIds)` / ordre visuel ROUGIT (item non déplacé) | remettre `applyTo` au rendu + `zReorderIds`+`copyWith` dans `onReorder` |
| **R3-I2** (SM-1 non régressé — CENTRAL AC2) | Câbler le réordonnancement via un `setState` au niveau `ZStudyToolsPage`/section OU envelopper les sections dans `ListenableBuilder(listenable: controller)` | `test AC2` : `buildsB`/`buildsPage` deviennent > 1 → `expect(buildsB, 1)`/`expect(buildsPage, 1)` ROUGIT | supprimer le `setState`/`ListenableBuilder` global (réordonnancement confiné au sous-arbre keyé) |
| **R3-I3** (hub désactivation — AC3) | `ZContentHubSheet` : rendre l'entrée `enabled:false`/`onTap:null` actionnable (câbler un onTap) OU hardcoder le label/icône | `test hub` : entrée désactivée ⇒ compteur passe 0→1 / label injecté absent ROUGIT | rebrancher la garde `enabled && onTap != null` + label/icône injectés |
| **R3-I4** (menu null=absent — AC4) | `ZItemActionsMenu` : NE PAS filtrer les actions `onSelected == null` (les rendre, éventuellement grisées) | `test menu` : action `onSelected:null` trouvée dans le menu ROUGIT (`findsNothing` échoue) | rétablir le filtre `actions.where((a) => a.onSelected != null)` |
| **R3-I5** (poignée a11y ≥48dp — AC6) | Poignée de drag sans `Semantics` label OU cible < 48 dp | `test a11y` : `find.bySemanticsLabel(handleLabel)` == 0 / contrainte de taille ROUGIT | remettre `Semantics(label: reorderHandleSemanticLabel ?? title)` + `ConstrainedBox(minWidth/minHeight: 48)` |

### Structure du package (à modifier/créer)
```text
packages/zcrud_study/
  lib/
    zcrud_study.dart                              # + exports hub/menu/zReorderIds (MODIFIED)
    src/presentation/
      z_study_tools_section_spec.dart             # + itemIds/onReorder/reorderHandleSemanticLabel (MODIFIED)
      z_sectioned_study_layout.dart               # rendu ReorderableListView si onReorder!=null && vertical (MODIFIED)
      z_content_hub_sheet.dart                    # ZContentHubSheet + ZContentHubEntry (NEW)
      z_item_actions_menu.dart                    # ZItemActionsMenu + ZItemAction + ZItemActionKind (NEW)
      z_reorder_ids.dart                          # helper pur zReorderIds (NEW, ou co-localisé au spec)
  test/
    z_study_tools_reorder_test.dart               # AC1 (ordre↔ZFolderContentsOrder) + AC2 (SM-1 non-régr.) (NEW)
    z_content_hub_sheet_test.dart                 # AC3 (NEW)
    z_item_actions_menu_test.dart                 # AC4 (NEW)
    golden/
      study_tools_page_golden_test.dart           # inchangé/ajusté (MODIFIED si fixture réordonnable)
      _fixtures.dart                              # + section réordonnable éventuelle (MODIFIED si apparence change)
      goldens/study_tools_sectioned.png           # régénéré SI apparence change (MODIFIED conditionnel)
```

### Project Structure Notes
- **Isolation workstream B** : NE PAS toucher `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_session`, `scripts/ci`, `sprint-status.yaml` (workstream A actif). Aucun fichier hors `packages/zcrud_study/**`.
- `graph_proof.py` INCHANGÉ (même package, aucune nouvelle arête — `ReorderableListView` = SDK Flutter, déjà présent). `melos list` reste à 19 packages. `pubspec.yaml` de `zcrud_study` INCHANGÉ (l'arête `zcrud_study_kernel` est DÉJÀ déclarée, l.52).
- Le spec gagne 3 champs optionnels additifs (const-compatible) — non-cassant pour les fixtures golden ES-5.1/5.2 et les tests ES-5.2 (valeurs par défaut `null`).

### Vérif verte à rejouer (commandes exactes, RC hors pipe R15 — CIBLÉES, PAS de `melos verify`/`analyze` repo-wide tant que workstream A actif)
```bash
# 1. Tests du package (RUNNER = flutter test, R14) — réordonnancement + SM-1 + hub + menu + golden
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
#   (si apparence changée : cd packages/zcrud_study && flutter test --update-goldens  PUIS re-run vert)

# 2. Analyse ciblée du package (RC=0)
OUT=$(cd packages/zcrud_study && dart analyze 2>&1); RC=$?; echo "$OUT" | tail -20; echo "RC=$RC"

# 3. Acyclicité AD-1 + CORE OUT=0 (inchangé — aucune arête reorderable_grid_view)
OUT=$(python3 scripts/dev/graph_proof.py 2>&1); RC=$?; echo "$OUT"; echo "RC=$RC"

# 4. Scans interdits (doivent être VIDES, hors commentaires)
grep -rnE "flutter_riverpod|package:get/|package:provider/|ConsumerWidget|WidgetRef|Get\.|Provider\.of|setState\(|reorderable_grid_view" packages/zcrud_study/lib
grep -rnE "EdgeInsets\.only\(|centerLeft|centerRight|Positioned\(left|Positioned\(right|TextAlign\.(left|right)|ListView\(children:" packages/zcrud_study/lib
```
**Attendu** : (1) `flutter test` RC=0 (réordonnancement + SM-1 non-régr. + hub + menu + golden) ; (2) `dart analyze` RC=0 ; (3) `ACYCLIQUE` + `out-degree(zcrud_core)=0` RC=0, `melos list`=19 ; (4) scans VIDES (seule occurrence tolérée = commentaire).
> La vérif repo-wide (`melos run analyze` ET `melos run verify`) reste à la charge de l'orchestrateur AU GATE DE COMMIT D'EPIC (workstreams au repos) — non rejouée ici (isolation).

### Dépendances de la story
- **Dépend de** : **ES-5.2 (done)** — consomme `ZStudyToolsPage` + `ZStudyToolsSectionSpec` (étendu ici) + `ZSectionedStudyLayout` + le scoping SM-1 prouvé. **ES-2.4 (done)** — `ZFolderContentsOrder` + `applyOrder<T>`/`applyTo` (réutilisés EN LECTURE + `copyWith`). ES-1.2 (`applyOrder`).
- **Position dans l'epic** : **DERNIÈRE story STRUCTURANTE d'ES-5** avant **ES-5.4** (`ZFeatureAvailability`, injectable, fichier isolé). ES-5.4 pourra composer les sections/hub/menu livrés ici. ES-6 (notes) / ES-7 (documents) / ES-10 (mindmap) composeront `ZStudyToolsPage` + `ZItemActionsMenu`/`ZContentHubSheet`.

### References
- [Source: epics-zcrud-study-2026-07-12/epics.md#Story-ES-5.3] (l.758-778) — ACs canoniques (ordre persiste via `ZFolderContentsOrder`+`applyOrder`, `ZContentHubSheet` par entrées icon/label/enabled/hint/onTap, `ZItemActionsMenu` enum kind + callbacks `null`=absente).
- [Source: epics.md#Story-ES-5.3-métadonnées] (l.764) — fichiers cibles `{z_study_tools_section.dart, z_content_hub_sheet.dart, z_item_actions_menu.dart}` (utilise `ZFolderContentsOrder` d'ES-2.4).
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-25] (l.243-246) — grilles réordonnables, ordre persiste via `ZFolderContentsOrder`/`applyOrder<T>`, `ZItemActionsMenu`/`ZContentHubSheet` paramétrés (`null`=absente), a11y/directionnel/thème injectés.
- [Source: architecture.md#AD-26] — `ZFolderContentsOrder` = état PERSONNEL séparé du sous-arbre partageable, jamais emporté par le partage.
- [Source: architecture.md] (l.44,51) — AD-2/AD-15 (aucun gestionnaire d'état), AD-13 (RTL/a11y/thème injecté).
- [Source: es-5-2-zstudytoolspage-scoping-isole-sm1.md] — socle ES-5.2 (`ZStudyToolsPage`, `_ZStudyFormScope`, SM-1 prouvé, `axis`), §NON-périmètre (réordonnabilité déférée ici).
- [Source: code-review-es-5-2.md] — ES-5.2 APPROVED, SM-1 load-bearing prouvé par injection R3-I1 rejouée (buildsB 1→101).
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart] — `orderFor`/`applyTo`/`copyWith`/`sectionOrders` (ES-2.4), immuabilité PROFONDE M3, égalité ordre-sensible.
- [Source: packages/zcrud_study_kernel/lib/src/domain/apply_order.dart] — `applyOrder<T>` (tri stable partiel, `ZUnorderedPlacement`).
- [Source: packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart] / [z_study_tools_section_spec.dart] / [z_study_tools_page.dart] — cibles de modification/composition.
- [Source: packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart] — pattern SM-1 de référence (compteurs, focus).
- [Source: ~/DEV/iffd/lib/src/presentation/features/folders/pages/folder_study_tools_page.dart] — réordonnancement MESURÉ : `ReorderableGridView.count(onReorder:)` l.1009/1369/1685 ; `onFolderContentReorder<T>` l.300-343 (`removeAt`/`insert` → `copyWith` → repository.update) ; application ordre l.256-259 (`indexOf` non stable, remplacé par `applyOrder`). `reorderable_grid_view: ^2.2.8` (`pubspec.yaml:154`) — NON tiré côté zcrud. READ-ONLY, aucun fichier IFFD modifié.
- [Source: ~/DEV/iffd/lib/src/presentation/features/folders/widgets/folder_content_creating_buttons.dart] (241 l., `label:` l.95/141/222, `IconData icon` l.173) + [empty_folder_content.dart] (`IconData icon` l.35, bouton « Ajouter du contenu » l.128) — hub d'ajout de référence. `PopupMenuButton`/menu d'item = ABSENT dans `features/folders/` (grep=0) ⇒ `ZItemActionsMenu` = abstraction propre neuve.
- [Source: package:flutter/lib/src/material/reorderable_list.dart:66] — `ReorderableListView` SDK (pas de paquet tiers).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high) — workstream B, isolation stricte `packages/zcrud_study/**`.

### Debug Log References

**Vérif verte CIBLÉE finale (RC hors pipe, R15)** :

| Gate | Commande | Résultat |
|------|----------|----------|
| Tests | `flutter test` (zcrud_study) | **RC=0 — 37 tests OK** (dont 18 nouveaux ES-5.3 : 10 reorder + 5 hub + 3 menu ; +19 ES-5.2 rebuild ; +golden) |
| Analyse | `dart analyze` (zcrud_study) | **RC=0 — No issues found** |
| Graphe AD-1 | `python3 scripts/dev/graph_proof.py` | **RC=0 — ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds** ; arêtes `zcrud_study` INCHANGÉES (`→ zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations`, aucune arête `reorderable_grid_view`) |
| Packages | `dart run melos list` | **20** (workspace a crû depuis la rédaction : +`zcrud_document`/`zcrud_note` ; la story mentionnait 19) |
| Scans interdits | `grep -rnE "flutter_riverpod\|get/\|provider/\|ConsumerWidget\|WidgetRef\|Get\.\|Provider\.of\|setState(\|reorderable_grid_view"` + directionnels | **VIDES hors commentaires** (aucun `setState`, aucun gestionnaire d'état, aucun non-directionnel en code) |

**Golden** : NON régénéré — la fixture canonique reste NON réordonnable (`onReorder == null`), donc aucune poignée de drag n'apparaît → `study_tools_sectioned.png` INCHANGÉ (permis par AC5 « SI l'apparence change »). Pouvoir discriminant golden ES-5.1 (byte-diff m1/m2/m3 + comptage N→N-1) préservé ; l'ordre visuel « suit l'ordre appliqué » d'une section réordonnable est prouvé par un byte-diff dédié (`_captureReorderable`, hauteurs distinctes pour éviter l'écueil Ahem/powerless R12).

**Injections R3-I1..I5 (R12) — rejouées RÉELLEMENT, RC=1 RED capturé, restaurées par ÉDITION CIBLÉE (R13, aucun `git checkout/restore/stash`)** :

| # | Injection (prod) | Message EXACT capturé (RED) | Restaurée |
|---|---|---|---|
| **I1** (AC1 ordre persisté) | `_handleReorder` ne rappelle plus `widget.spec.onReorder!` | `Expected: ['b', 'a', 'c']` / `Actual: []` / `Which: at location [0] is [] which shorter than expected` | ✅ (re-vérifié RED post-refactor ValueNotifier puis GREEN) |
| **I2** (AC2 SM-1) | `ZStudyToolsPage.build` enveloppe le corps dans un `ValueListenableBuilder`(slice champ) reconstruisant un `ZSectionedStudyLayout` neuf | `Expected: <1>` / `Actual: <101>` (buildsFieldB) | ✅ |
| **I3** (AC3 hub désactivation) | `ZContentHubSheet` : `final actionable = true;` (au lieu de `entry.isActionable`) | `Expected: <0>` / `Actual: <1>` (« entrée désactivée : le tap n'a AUCUN effet ») + `Expected: false / Actual: <true>` (Semantics) | ✅ |
| **I4** (AC4 menu null=absent) | `ZItemActionsMenu` : `actions.toList()` (filtre `onSelected != null` retiré) | `Expected: no matching candidates` / `Actual: Found 1 widget with text "SUPPRIMER-ABSENTE"` | ✅ |
| **I5** (AC6 poignée a11y) | poignée `Semantics(label:)` retiré | `Expected: exactly 3 matching candidates` / `Actual: Found 0 widgets with widget matching predicate` | ✅ |

> Note I2 : la 1ʳᵉ tentative (`ListenableBuilder(listenable: _controller)`) ne rougissait PAS — `ZFormController.setValue` ne déclenche PAS `notifyListeners()` global (seule une tranche notifie, invariant SM-1 du cœur). La 2ᵉ (`builder → même instance body`) non plus (Flutter court-circuite un widget identique). L'injection retenue construit un layout NEUF à chaque frappe → buildsFieldB 1→101 : c'est bien la régression « global builder » que l'AC2 attrape.

### Completion Notes List

**Conception — réordonnancement (`ReorderableListView` + `ZFolderContentsOrder`)** :
- Slots ADDITIFS const-compatibles sur `ZStudyToolsSectionSpec` (`itemIds`/`onReorder`/`reorderHandleSemanticLabel`, défauts `null` ⇒ non-cassant ES-5.1/5.2). Assert de dev `onReorder != null ⇒ itemIds!=null && length==itemCount` (AD-10, jamais de throw runtime).
- Rendu via `ReorderableListView.builder` du **SDK Flutter** (jamais `reorderable_grid_view` — AD-1), imbriqué (`shrinkWrap:true` + `NeverScrollableScrollPhysics`), enfants keyés `ValueKey(itemId)`, `buildDefaultDragHandles:false` + poignée FOURNIE (`ReorderableDragStartListener` + `Semantics(container:true, label INJECTÉ)` + cible ≥ 48 dp, directionnelle). Uniquement `axis == Axis.vertical` ; `onReorder == null` ⇒ rendu ES-5.2 STRICTEMENT inchangé (non-régression prouvée).
- API SDK `onReorderItem` (remplace `onReorder` obsolète) : `newIndex` déjà ajusté ⇒ convention `removeAt/insert` directe, aucun `-1` manuel.
- **Réutilisation `ZFolderContentsOrder` (kernel NON modifié)** : rendu = `order.applyTo(sectionKey, items, idOf:)` (tri stable `applyOrder`, ES-1.2) → `itemIds` ; drag = `order.copyWith(sectionOrders: {…, sectionKey: zReorderIds(ids, o, n)})`. Contrat testé EN MÉMOIRE (persistance repo = ES-3.2, hors périmètre). `zReorderIds` = helper PUR removeAt/insert clampé (opération DISTINCTE d'`applyOrder`).

**Préservation SM-1 (AC2, objectif n°1)** : l'ordre optimiste local vit dans un `ValueNotifier<List<String>>` d'un `_ReorderableItemList` (StatefulWidget) SOUS la frontière keyée `ValueKey('section:$id')` — **AUCUN `setState`** (rebuild confiné au seul `ValueListenableBuilder` du sous-arbre de la section, réactivité Flutter-native pure AD-2/AD-15). Prouvé : (a) 100 frappes ⇒ `buildsFieldA=101`, `buildsAObs=1`, `buildsFieldB=1`, `buildsPage=1`, focus jamais perdu (non-régression ES-5.2) ; (b) réordonner la section A ⇒ `buildsFieldB=1`, `buildsPage=1` (ni B ni l'observateur de page reconstruits). `didUpdateWidget` resynchronise l'ordre local si l'appelant repousse un ordre persisté.

**Hub (`ZContentHubSheet`/`ZContentHubEntry`)** : `ListView.builder`, tuiles ≥ 48 dp, `Semantics(button, enabled)`, directionnel, thème injecté ; `enabled==false || onTap==null ⇒ isActionable==false` ⇒ tuile désactivée (`onTap:null`, tap sans effet — AD-4). Statique `.show()` (`showModalBottomSheet`).

**Menu (`ZItemActionsMenu`/`ZItemAction`/`ZItemActionKind`)** : `PopupMenuButton`, enum de nature extensible (`open/rename/move/share/delete/custom`), labels/icônes INJECTÉS, items ≥ 48 dp + `Semantics` ; **filtre `where(onSelected != null)`** ⇒ action à callback `null` ABSENTE du menu (AD-4, jamais grisée/no-op).

**Invariants** : AD-1 (graphe inchangé, CORE OUT=0), AD-2/AD-15 (aucun gestionnaire d'état, aucun `setState`), AD-4 (`null` = capacité absente sur les 3 surfaces), AD-13/FR-26 (directionnel, `Semantics`, ≥ 48 dp, thème/labels injectés — seuls repli d'icônes neutres documentés `Icons.add`/`Icons.drag_handle`/`Icons.more_vert`), AD-26 (`ZFolderContentsOrder` = état personnel, réutilisé EN LECTURE + `copyWith`).

### File List

**MODIFIED**
- `packages/zcrud_study/lib/zcrud_study.dart` — exports `ZContentHubSheet`/`ZContentHubEntry`/`ZItemActionsMenu`/`ZItemAction`/`ZItemActionKind`/`zReorderIds`.
- `packages/zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart` — slots additifs `itemIds`/`onReorder`/`reorderHandleSemanticLabel` + assert de cohérence ; note `:82` corrigée.
- `packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart` — rendu réordonnable (`_ReorderableItemList` StatefulWidget + `ValueNotifier`, `_ReorderableItemRow` poignée a11y) branché dans `_buildItems` quand `onReorder != null && axis == vertical`.

**NEW (lib)**
- `packages/zcrud_study/lib/src/presentation/z_reorder_ids.dart` — helper pur `zReorderIds`.
- `packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart` — `ZContentHubSheet` + `ZContentHubEntry`.
- `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart` — `ZItemActionsMenu` + `ZItemAction` + `ZItemActionKind`.

**NEW (test)**
- `packages/zcrud_study/test/z_study_tools_reorder_test.dart` — AC1 (ordre↔`ZFolderContentsOrder`) + AC2 (SM-1 non-régr. + confinement) + AC5 (byte-diff réordonnable) + AC6 (poignée a11y) + `zReorderIds` + non-régr. `onReorder==null`.
- `packages/zcrud_study/test/z_content_hub_sheet_test.dart` — AC3 (actionnable/désactivée) + AC6.
- `packages/zcrud_study/test/z_item_actions_menu_test.dart` — AC4 (callback/absente) + AC6.

**Golden** : `packages/zcrud_study/test/golden/goldens/study_tools_sectioned.png` — INCHANGÉ (fixture canonique non réordonnable ; aucune régénération `--update-goldens`).
