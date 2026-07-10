# Rétrospective — Epic EX : Application exemple Flutter (`example/`)

- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill`, args `retrospective EX`). Chemin pris : **skill réel** (chargé, workflow party-mode). Le fichier de sortie est fixé par la consigne orchestrateur (`epic-ex-retrospective.md`) et non le nom horodaté par défaut du skill ; le sprint-status **n'est pas** modifié par cette rétro (écriture ciblée réservée à l'orchestrateur).
- **Date** : 2026-07-10
- **Périmètre** : EX-1 (scaffold + démo édition E3, badge SM-1, parité 4 bindings) · EX-2 (démo liste E4 `DynamicList` + pagination + corbeille) · EX-3 (démos markdown/geo/intl/export/offline + registre de widgets injecté à la racine).
- **Statut des 3 stories** : `done` (sprint-status). Toutes remédiations MAJEUR/MEDIUM verrouillées par test.

---

## 1. Livré

Une **application Flutter exemple consommatrice, isolée hors du workspace**, qui démontre de bout en bout les fonctionnalités MVP de zcrud :

- **Édition** (`DynamicEdition` / moteur E3) : familles de champs, sections, conditionnels, grille, stepper, soumission/dirty, avec **preuve visuelle de la granularité de rebuild (SM-1)** via un badge par champ.
- **Liste** (`DynamicList` / E4, Syncfusion) : tri, colonnes, **pagination curseur navigable** (bouton « Charger plus »), corbeille / soft-delete.
- **Markdown** (E6) : montage `ZMarkdownField`, valeur persistée, bascule de codec.
- **Geo** (E11a, OSM sans clé), **Intl** (téléphone/pays/devise), **Export** (PDF/Excel).
- **Offline** (Hive réel) : CRUD create / softDelete / **restore** exerçable à la main (undo via SnackBar).
- **Parité des 4 bindings** : `ZcrudScope` (défaut) · `zcrud_get` · `zcrud_riverpod` · `zcrud_provider`, montés à l'identique.
- **Registre de widgets** injecté au `ZcrudScope` **racine** et re-propagé sous chaque binding.

**Métriques réelles (rejouées sur disque) :**

| Métrique | Valeur |
|---|---|
| Tests `example/` | **49** verts |
| `flutter analyze` | **RC=0** (No issues found) |
| `flutter build web` | **RC=0** |
| `packages/` | **INCHANGÉ** (git status vide à chaque story — isolation intacte) |
| Root `pubspec.lock` | **non pollué** (seul `example/pubspec.lock` untracked ; entrées lourdes du lock racine préexistantes, issues des membres workspace) |
| `melos list` | **14** packages (invariant « 14 packages produit » préservé) |

---

## 2. Ce qui a bien marché

**(a) L'app comme harnais de validation réel.**
- **SM-1** prouvé *visuellement* : taper dans un champ n'incrémente que le badge de rebuild de *ce* champ (proxy co-localisé confirmé sain par la revue), zéro rebuild global, zéro perte de focus.
- **SM-5 / isolation des SDK lourds** : Syncfusion, Firebase/Firestore, Maps, Quill sont tirés **exclusivement via les packages satellites**, jamais via `zcrud_core`. `grep` = 0 import direct de `cloud_firestore`/`firebase_core`/`flutter_map`/`flutter_quill`/`syncfusion_*` dans `example/lib`.
- **Parité 4 bindings** démontrée à l'exécution : mêmes familles de champs, même `SfDataGrid`, mêmes écrans registre-servis sous les 4 wraps.

**(b) Isolation stricte tenue de bout en bout.**
- App **hors workspace**, branchée par `dependency_overrides` (path) ; `packages/` **jamais touché** par EX — vérifié à *chaque* story via `git status`. Root lock non pollué. Boundary test étendu à chaque story (satellites autorisés par périmètre : E3 seul en EX-1, +`zcrud_list` en EX-2, +markdown/geo/intl/export en EX-3).

**(c) Validation croisée de l'API publique.**
- EX-3 **compile les mêmes API publiques** que celles documentées par les README de REL-1, corroborant leur exactitude. Chaque écran a été vérifié adversarialement contre `packages/*/lib`. L'app exemple agit comme test de compilation vivant de la surface publique.

---

## 3. Incidents & leçons

**(a) EX-1 — MAJEUR : `ZEditionSubmitController` (`_submit`) jamais `dispose()`.**
- Fuite du `ValueNotifier<ZSubmissionState>` à chaque bascule de binding et au teardown ; violation du contrat explicite `z_submission.dart:205` et de la discipline AD-2, dans l'écran-vitrine même censé exemplifier le lifecycle correct.
- **Corrigé** : `_submit.dispose()` ajouté au switch (avant `oldController.dispose()`) et dans `State.dispose()`.
- **Leçon** : *disposer TOUS les controllers, le submit inclus — pas seulement le `ZFormController`.*

**(b) EX-1 — MEDIUM : le scope interne d'un binding masquait les seams racine.**
- Le `ZcrudScope` interne des wraps get/riverpod/provider ne re-propageait pas les seams injectés à la racine (`filePicker`, thème, `labels`, `listRenderer`, `widgetRegistry`, `cloudStorage`) → familles file/image/document **mortes** sous 3 des 4 bindings, non détecté par le test de parité (limité au texte).
- **Corrigé** : `wrapWithBinding(rootScope:)` + **`_BindingSeamForwarder`** qui re-déclare les seams racine SOUS le scope du binding, tout en conservant `resolver`/`acl` injectés. Test de parité sondant `ZcrudScope.of(context).filePicker == picker` sous les 4 voies.
- **Réutilisé** tel quel par EX-2 (re-propage `listRenderer`) et EX-3 (`widgetRegistry`).
- **Leçon** : *un binding doit re-propager la totalité des seams racine ; un test de parité doit couvrir les familles à dépendance de seam, pas seulement le texte.*

**(c) EX-2 — MEDIUM : pagination non navigable en UI (`loadMore()` jamais invoqué).**
- La couche données supportait le curseur (testé 15→30→45→48), mais aucune affordance UI : seuls 15/48 enregistrements atteignables — le chemin curseur jamais exercé end-to-end.
- **Corrigé** : widget `_LoadMoreBar` (écoute la seule tranche `state`, AD-2, ≥48dp) → `ZListController.loadMore()` ; pagination navigable testée en UI.
- **Leçon** : *une démo de feature doit exercer le parcours utilisateur complet, pas seulement la couche données.*

**(d) EX-3 — MEDIUM : restore offline non exposé en UI.**
- AC7 revendiquait « soft-delete + restore » mais l'écran n'offrait aucune voie de restauration (restore seulement dans le test unité).
- **Corrigé** : SnackBar « Annuler » → `store.restore(id)` ; CRUD offline complet exerçable à la main + test widget.
- **Leçon** : *même leçon que (c) — exposer le parcours réel, pas un proxy prouvé uniquement par test.*

*(LOW consignés : démo l10n partiellement creuse, couverture éditeur Quill reportée sur E6, parité géo optionnelle — tous documentés, sans impact bloquant.)*

---

## 4. Action items

| ID | Libellé | Owner |
|---|---|---|
| **AI-EX-1** | `_BindingSeamForwarder` est une brique réutilisable (re-propagation exhaustive des seams sous un binding). Envisager de la **remonter en util partagé** pour les vraies apps (DODLP / lex_douane), au lieu de la ré-implémenter par app. | Architecte / mainteneur core |
| **AI-EX-2** | **Toute démo de feature doit exposer le parcours utilisateur complet** (pagination, restore, …) — jamais un proxy prouvé seulement à la couche données ou par test unité. À poser en critère d'AC des futures stories de démo. | SM / auteur de story |
| **AI-EX-3** | L'app exemple **valide l'API publique réelle** : la garder **synchronisée avec les packages à chaque nouvelle feature** (E9 flashcards, E10 mindmaps en v1.x) pour préserver la validation croisée README/compilation. | Mainteneur |

---

## 5. Dette / suite actée

- **Flashcards (E9)** et **mindmaps (E10)** : démos à ajouter en **v1.x** (hors MVP).
- **Démo Firestore distant réelle** : différée — nécessite une config Firebase (`initializeApp`) ; actuellement documentée mais non initialisée (no-secret respecté, aucune clé/licence committée).
- **Enrichissement l10n de surface** : reporté (labels forwardés sous bindings ; toggle fr↔en peu visible).
- **Prochaine étape** : **REL-2 — publication** (action **Owner**), l'app exemple servant de harnais de validation SM-1 / SM-5 / parité bindings pour la release.

---

*Contrainte respectée : `sprint-status.yaml` non modifié par cette rétro (l'entrée `epic-ex-retrospective` reste sous contrôle de l'orchestrateur).*
