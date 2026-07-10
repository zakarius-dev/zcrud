# Rétrospective — Epic E10 : Cartes mentales (`zcrud_mindmap`)

- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill` — chemin skill pris, PAS le fallback disque `.claude/skills/bmad-retrospective/SKILL.md`).
- **Date** : 2026-07-10.
- **Mode d'exécution** : agent unique non-interactif (sous-agent d'orchestration). Les phases d'analyse du skill (lecture des 3 stories E10-1/2/3 + 3 code-reviews + section E10 du sprint-status + définition d'épic + AD-2/AD-4/AD-13/FR-26/FR-19) ont été jouées **réellement sur disque** ; le format « party mode » interactif est condensé en rétro écrite (aucun interlocuteur humain en session).
- **Périmètre** : E10 uniquement (`packages/zcrud_mindmap/`). Aucune modification de `zcrud_core` sur les 3 stories. `sprint-status.yaml` NON modifié (transition d'épopée + `epic-10-retrospective: optional → done` réservés à l'orchestrateur). Aucun commit (fin d'epic gérée par l'orchestrateur).

---

## 1. Livré

**Épic v1.x complète : un package satellite `zcrud_mindmap` de bout en bout (modèle → moteur d'arbre → vue lecture a11y → éditeur outline corrigé), 100 % isolé du cœur, `zcrud_core` NON modifié sur les 3 stories.** Couvre FR-19 ; conforme AD-1, AD-2, AD-4, AD-13, AD-15, FR-26.

| Story | Couche | Contenu livré | Tests (au `done`) |
|-------|--------|---------------|-------|
| **E10-1** | `domain/` | `ZMindmapNode` (`extends ZNode with ZExtensible`, immuable, `children` non-modifiable, **aucun `copyWith`**), `ZMindmap` (forêt multi-racine, `folder_id` snake_case, **sans `updated_at`/`is_deleted`** AD-16), `ZMindmapTreeOps` **pur/structural-sharing** : `updateNode`/`addChild`/`deleteNode`/`findNode` portés de lex **+ `moveNode`/`indentNode`/`outdentNode`/`reorderChild` AJOUTÉS** (dette n°5 lex : jamais codés) avec **recalcul systématique de `level`** + anti-cycle. `fromJson` défensif AD-10. | **56** (55 + 1 après MEDIUM-1) |
| **E10-2** | `presentation/` | `ZMindmapView` (auto-layout **graphite ^1.2.1**, supersede `graphview`, zoom/pan bornés, **aucun drag libre**, multi-racine via racine virtuelle non affichée/hors-sémantique, forêt vide accessible) + `ZMindmapListView` (**surface a11y de référence**, `ListView.builder`, indentation directionnelle par `level`, `Semantics` explicites, ≥48 dp) + `nodeContentBuilder` injectable partagé graphe/liste (défaut sûr sans dépendance à `zcrud_markdown`). Thème 100 % `ZcrudTheme.of`, réactivité Flutter-native (`ValueNotifier`/`ValueListenableBuilder`). | **83** (82 + 1 après H1) |
| **E10-3** | `presentation/` | `ZMindmapOutlineEditor` + `ZMindmapOutlineController` (`ChangeNotifier` pur) : **livrable clé de l'épic — la sauvegarde applique RÉELLEMENT les edits** (correction par conception du bug lex). Forêt du contrôleur = **source de vérité unique**, mutée en continu via `ZMindmapTreeOps` uniquement ; `onSave` émet exactement `controller.forest`. `TextEditingController` stables keyés par `id` (rebuild granulaire, zéro perte de focus, SM-1). `ZMindmapOutlineLabels` externalisés. | **110** (89 hérités + 21 nouveaux, après corrections) |

**Métriques réelles vérifiées sur disque (rejouées par l'orchestrateur à chaque `done`)** :
- `dart analyze packages/zcrud_mindmap` → **RC=0 (« No issues found! »)** à chaque story.
- `flutter test packages/zcrud_mindmap` → **RC=0**, montée cumulative **56 → 83 → 110 tests** verts.
- Aucun codegen (`*.g.dart`) : `fromJson`/`toJson` hand-written immuables + défensifs (permis AD-3, domaine pur immuable sans `copyWith`).
- Isolation : diff confiné à `packages/zcrud_mindmap/**` ; nouvelles arêtes pubspec = `flutter (sdk)` + `graphite ^1.2.1` (E10-2), autorisées par l'architecture ; **aucune** arête gestionnaire d'état / Firebase / Syncfusion ; `zcrud_core` intact.

---

## 2. Ce qui a bien marché

**(a) Correction par conception du bug historique lex — pas un patch, un invariant verrouillé par test.**
Le cœur de l'épic (E10-3) était de corriger la dette n°5 lex : `MindmapTreeOps` annonçait `move/indent/outdent` **non codés**, et l'éditeur outline **mutait une copie UI locale jamais reversée** au chemin de sauvegarde → edits perdus. zcrud a scindé le problème proprement : (1) **E10-1 a comblé la moitié moteur** (toutes les ops de reparentage codées + recalcul `level`) ; (2) **E10-3 a comblé la moitié UI+wiring** en faisant de la forêt du contrôleur la **source de vérité unique**, mutée en continu, avec `save() = émission de controller.forest`. Il n'existe **aucun chemin** où l'arbre d'origine serait re-persisté. Le **test anti-bug-lex** (`findNode(saved,'c1').label == 'ChildEdited'` ET `isNot('Child1')`, étendu à content/add/delete/indent/outdent/reorder + cohérence `level`) verrouille l'invariant pour toujours — c'est exactement le test qui aurait attrapé le bug lex.

**(b) Réutilisation exemplaire du cœur (AD-1) — zéro réinvention, `zcrud_core` intact sur 3 stories.**
`ZMindmapNode extends ZNode with ZExtensible` (contrat `id` non-null + slots AD-4 réutilisés) ; `ZExtension.guard` pour le parse défensif ; `ZcrudTheme.of`/`ZcrudScope` pour le thème (FR-26) ; `ZMindmapViewConfig`/`ZMindmapNodeCard`/`ZMindmapListView` d'E10-2 réutilisés comme patrons par E10-3 (aplatissement DFS, indentation directionnelle, `Semantics`, ≥48 dp). La revue E10-1 qualifie la réutilisation de « **exemplaire** ». Aucun contrat de nœud/extension recréé, aucune op TreeOps ré-implémentée, aucun `copyWith` inventé.

**(c) Réactivité Flutter-native tenue jusque dans l'éditeur (AD-2, objectif produit n°1).**
E10-3 démontre l'objectif n°1 hors du formulaire canonique : **édition de texte = 0 `notifyListeners`** (la forêt est mise à jour silencieusement, le `TextEditingController` stable porte déjà le texte) → seules les mutations **structurelles** notifient, l'outline ne se reconstruit qu'à celles-ci. `TextEditingController` keyés par `id` via `putIfAbsent`, jamais réaffectés `.text` pendant la frappe. Tests : identité stable du controller entre frappes, focus conservé après `enterText`, `editLabel` n'incrémente pas le compteur de notifications. Conforme SM-1, sans aucun gestionnaire d'état.

**(d) Structural sharing + désérialisation défensive solidement testés (E10-1).**
Toute op no-op renvoie la forêt d'entrée `identical` ; sous-arbres intacts partagés par référence ; anti-cycle (déplacement vers soi/descendant rejeté sans boucle) ; `fromJson` ne throw jamais (map vide, children non-liste, enfant corrompu, `level` non-int → renormalisé, extension `formatVersion` inconnue → null via guard, `extra` préservé). Bornes couvertes (cascade `level` sur profondeur ≥3, clamp d'index).

---

## 3. Findings récurrents & leçons (transversaux aux 3 stories)

La revue adversariale a trouvé des **défauts réels et structurellement récurrents**, pas des nits cosmétiques. Trois motifs traversent l'épic :

**(a) MOTIF #1 — a11y = opérabilité, pas seulement taille/label. (E10-2 H1 MAJEUR, E10-3 MEDIUM-1).**
- **E10-2 / H1 (MAJEUR)** : la vue liste — désignée **surface a11y de référence** — déclarait `Semantics(button: true)` mais **sans `onTap:`**, l'unique geste d'activation vivant sous `ExcludeSemantics` (interne à la carte). Résultat : nœud annoncé « bouton » mais **sans `SemanticsAction.tap`** → double-tap TalkBack/VoiceOver **ne déclenche rien**. Le pointeur masquait le défaut ; les tests tapaient via `tester.tap` (pointeur), jamais via action sémantique. Corrigé : `onTap` porté sur le `Semantics` parent + test exerçant réellement `SemanticsAction.tap`.
- **E10-3 / MEDIUM-1** : les deux `TextField` (`label`/`content`) en `isDense: true` **sans contrainte de hauteur** → ~40 dp, **sous le plancher AD-13 de 48 dp**, sur l'affordance d'édition principale. Le test « ≥48 dp » ne vérifiait que le bouton « Supprimer ». Corrigé : `InputDecoration.constraints: BoxConstraints(minHeight: config.minTapTarget)` + assertion de hauteur du `TextField`.
- **> C'est exactement la leçon AI-E11a-2 (checklist a11y).** Elle s'est **répétée** en E10 malgré l'action item E11a — signe que la checklist n'était pas encore systématisée. **Un test a11y doit exercer l'action sémantique déclenchée ET asserter ≥48 dp sur CHAQUE cible interactive (champs inclus), pas seulement `bySemanticsLabel` + `getSize` sur un échantillon.**

**(b) MOTIF #2 — un garde vert ne prouve QUE ce qu'il scanne. (E10-3 MEDIUM-2, E10-1 MEDIUM-1, gardes grep au cwd).**
- **E10-3 / MEDIUM-2** : le grep de garde FR-26 ne scannait que `Colors.` — **`Color(0x…)` non couvert** (pourtant explicitement interdit par AC5). Code de prod propre, donc pas de défaut vivant, mais le garde-fou ne remplissait pas sa promesse. Corrigé : motif `Color(0x` ajouté à la denylist.
- **E10-1 / MEDIUM-1** : le slot `extra` absorbait puis **ré-émettait les clés de sync réservées AD-16** (`updated_at`/`is_deleted`) via `...extra` dans `toJson`. L'invariant « sync hors-entité » ne tenait que pour une entité fraîchement construite, **pas sur le chemin `fromJson→toJson`** — latent tant qu'E5 (offline-first LWW sur `updated_at` + soft-delete `is_deleted`) n'était pas branché. Corrigé : denylist `_reservedSyncKeys` exclue de la capture `extra` + test round-trip dédié.
- **Gardes grep fragiles au cwd** : les tests de garde résolvaient leur chemin relativement au cwd. Durcis pour essayer `''` puis `packages/zcrud_mindmap/` (passent depuis la racine **et** le package) et pour **retirer les commentaires avant scan** (les docstrings nomment légitimement les API interdites).
- **> Leçon (rappel de la leçon E11a) : tout grep de garde de conformité doit (1) scanner la liste EXHAUSTIVE des motifs interdits par l'AC, pas un sous-ensemble ; (2) être robuste au cwd ; (3) strip-comment. Un garde de conformité incomplet est une dette latente qui donne une fausse assurance.**

**(c) MOTIF #3 — efficience du rebuild granulaire : ne pas empiler des abonnements au même notifier. (E10-2 M1 MEDIUM).**
- **E10-2 / M1** : double `ValueListenableBuilder` sur le **même** `selectedListenable` (un dans le `itemBuilder` de liste, un ré-souscrit dans `ZMindmapNodeCard`). Chaque ligne portait deux abonnements empilés ; une sélection reconstruisait **O(n)** lignes, pas « la seule tranche concernée » (AC6 littéral). Fonctionnellement correct mais s'éloignait de l'objectif de rebuild strictement ciblé. Corrigé : point d'écoute unique, `ZMindmapNodeCard` reçoit un `bool isSelected` déjà résolu (plus d'abonnement interne).
- **> Leçon : le rebuild ciblé (AD-2) exige UN SEUL point d'écoute par tranche. Un notifier partagé écouté par toutes les cellules recrée un rebuild O(n) déguisé — vérifier qu'une interaction ne reconstruit littéralement que la tranche concernée, pas « toutes les tranches qui écoutent le notifier partagé ».**

**Bilan de résolution** : 1 MAJEUR (E10-2 H1), 4 MEDIUM (E10-1 ×1, E10-2 ×1, E10-3 ×2) — **tous corrigés dans le périmètre** avec test de non-régression, re-vérif verte rejouée. LOW consignés (voir §5). **0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert** au `done` des 3 stories.

---

## 4. Points de friction

**(a) Portage de dette lex à deux étages (moteur puis UI) — séquençage intra-package strict.**
La dette n°5 lex imposait un ordre non négociable : E10-1 (moteur : ops de reparentage + recalcul `level`) **avant** E10-3 (UI+wiring). Un raccourci — coder l'éditeur avant d'avoir le moteur complet — aurait reproduit le bug lex (« nulle part où appliquer les reparentages »). Le séquencement a été respecté ; friction assumée et bénéfique.

**(b) Composition d'ops manquantes sans rouvrir E10-1 (E10-3).**
`ZMindmapTreeOps` n'exposait ni `findParent` public ni « insérer une racine à un index ». Plutôt que d'éditer E10-1/`zcrud_core` (interdit), E10-3 a **composé** : `addSibling(id)` = `addChild` sous le nœud → `outdentNode` (devient frère à `index+1`, `level` recalculé) ; `addRoot` sur forêt vide = `[newRootNode()]`, sinon `addSibling(dernière racine)` ; `moveUp/moveDown` = localisation lecture-seule + `reorderChild`. Composition correcte et tracée manuellement en revue — mais elle **repose sur des invariants d'E10-1 non triviaux** (le `level` recalculé par `outdentNode` doit être exact). Cela a bien tenu grâce à la couverture forte d'E10-1.

**(c) `graphite` multi-racine — cellule fantôme dans l'auto-layout (LOW consigné).**
La racine virtuelle (insérée seulement si ≥2 racines, rendue `SizedBox.shrink()` et hors-sémantique) reçoit malgré tout un emplacement dans l'auto-layout graphite → possible espace vide/arêtes fantômes en tête de graphe multi-racine. Purement visuel, choix documenté et acceptable ; à affiner si un rendu multi-racine « propre » est exigé.

**(d) Récurrence des mêmes findings malgré l'action item E11a.**
Le MOTIF #1 (a11y opérabilité) et le MOTIF #2 (garde incomplet) sont des **répétitions directes** de leçons déjà actées en rétro E11a (AI-E11a-2, leçon « garde vert ne prouve que ce qu'il scanne »). Elles ont été re-attrapées par la revue, donc corrigées — mais leur réapparition indique que ces leçons n'étaient pas encore **outillées** (checklist exécutable, template de garde). C'est le principal enseignement process de l'épic.

---

## 5. Action items

| ID | Libellé | Owner |
|----|---------|-------|
| **AI-E10-1** | **Outiller** (et non plus seulement documenter) la checklist a11y AD-13 : un helper de test réutilisable `assertSemanticActionTap(finder)` + `assertMinTapTarget(finder, 48)` appliqué à **chaque** cible interactive (boutons ET champs éditables). Cible immédiate : **E9-4/E9-5** (sessions/UI flashcards) et **E11b** (widgets geo/intl). Clôt la récurrence du MOTIF #1. | Dev / UX |
| **AI-E10-2** | Factoriser un **template de garde grep de conformité** exhaustif et robuste : denylist complète par AC (`Colors.`, `Color(0x`, `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `Positioned(left/right`, `TextAlign.left/right`, imports gestionnaires d'état), résolution de chemin cwd-robuste, strip-comment. À réutiliser tel quel en E9-4/E9-5 et E11b. Clôt la récurrence du MOTIF #2. | Dev |
| **AI-E10-3** | Vérifier systématiquement le **rebuild ciblé O(1)** (MOTIF #3) sur tout widget à état partagé : un seul point d'écoute par tranche, test « une interaction ne reconstruit QUE la tranche concernée ». Applicable aux sessions flashcard (E9-4/E9-5) et à tout futur éditeur. | Dev |
| **AI-E10-4** | Consigner en dette v1.x les **LOW différés** de l'épic (voir §6) et statuer sur le rendu multi-racine graphite propre si un besoin réel émerge côté intégration (lex_douane module Étude). | PM / Dev |

---

## 6. Dette v1.x actée (LOW consignés, non bloquants)

- **E10-1** — LOW-1 : perte de la charge `extension` au round-trip **sans décodeur enregistré** (design assumé AD-10, responsabilité du décodeur ; risque de fidélité pour E5 firestore — à documenter/surveiller). LOW-2 : `ZMindmapNode.fromJson` autonome ne renormalise pas les `level` des enfants (renormalisation au niveau forêt seulement ; nul en usage canonique). LOW-3 : couverture `reorderChild` avec `newIndex` hors bornes non exercée.
- **E10-2** — L4 : racine virtuelle multi-racine réservant une cellule vide dans le layout graphite (visuel, documenté).
- **E10-3** — LOW-1 (corrigé, mais motif à généraliser) : purge des `TextEditingController` de nœuds supprimés — traité par `_disposeSubtreeControllers` ; garder ce réflexe pour tout contrôleur à cache de sous-widgets. LOW-2 (corrigé) : sémantique `textField` redondante.

Aucune de ces dettes ne bloque un consommateur ; elles relèvent du durcissement de fidélité (E5) ou de raffinement visuel.

---

## 7. Readiness — suite v1.x

**E10 complet et vert clôt la carte mentale de bout en bout** (modèle → moteur → vue a11y → éditeur corrigé) pour lex_douane (module Étude) et DODLP. **Aucune découverte d'E10 ne remet en cause le plan des epics restants** — pas de *significant discovery* nécessitant une mise à jour d'épic. E10 n'est bloquant pour aucune autre épic (feuille du graphe de dépendances : `E2 → E10`, `E6 → E10`, tous deux `done`).

- **Épics v1.x restants (parallélisables, packages disjoints)** : **E9** (flashcards — E9-1/E9-2 `done`, reste E9-3 dossiers/sessions puis **E9-4/E9-5**) et **E11b** (geo/intl/export complet — E11b-1 geo → E11b-2/E11b-3). Ces workstreams ne touchent pas `zcrud_core` → parallélisation sûre tant qu'aucun n'y écrit simultanément.
- **Leçons E10 directement applicables à E9-4/E9-5 et E11b** : les 3 action items ci-dessus (checklist a11y outillée, template de garde grep exhaustif, vérif du rebuild ciblé O(1)) — précisément parce que E9 (sessions/révision SRS avec UI interactive) et E11b (widgets de champ) rejouent les trois motifs de findings de cette épic.
- **Rappel structural sharing / défensif** : le patron E10-1 (no-op → `identical`, `fromJson` jamais-throw, denylist des clés réservées) est le modèle de référence pour tout nouveau modèle immuable v1.x.

**Transition d'épopée** (réservée à l'orchestrateur, hors périmètre de cette rétro) : `epic-10-retrospective: optional → done` et `epic-10: in-progress → done` selon le séquencement du sprint-status, une fois la rétro validée.
