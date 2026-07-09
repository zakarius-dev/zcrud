# Rapport de complétude d'implémentation — zcrud
**Date:** 2026-07-09 · **Projet:** zcrud

## 1. Verdict global

**NEEDS WORK.**

Le corpus est mûr et implémentable : les 25 FR et les 16 AD sont tous rattachés à au moins une story, le graphe d'exécution est acyclique, le setup melos existe (E1-1) et le brownfield (migration DODLP en E7, lex_douane_admin en E8, adaptateurs ReflectableCodec/JsonSerializable en E2-6, révocation du secret Maps en E1-5) est solidement couvert. S'agissant d'un produit-développeur brownfield, les épics d'infrastructure E1/E2 portent une valeur d'intégrateur légitime et explicitée. Aucun défaut n'est bloquant au point de justifier un NOT READY : la couverture FR est quasi complète (24/25 pleinement, 1 partielle et résoluble) et aucune question ouverte ne bloque le MVP (E1–E8). En revanche, un défaut de cohérence documentaire **critique** (le substrat de réactivité étiqueté « Riverpod » contredit l'invariant adopté d'un cœur Flutter-native) et une douzaine de findings **majeurs** de cohérence/complétude doivent être corrigés avant de figer le séquencement de sprint et de lancer E3.

## 2. Inventaire des documents

| Document | Présence | Statut |
|---|---|---|
| PRD (`prd.md`) | 1 exemplaire, pas de doublon | Structurellement solide ; front-matter `status: draft`, titre « à confirmer », résidu `[NOTE FOR PM]` en §6.2 → à geler |
| Architecture (`architecture.md`) | 1 exemplaire | 16 AD, table de traçabilité, ER diagram ; contient le diagramme AD-2 périmé (Riverpod) |
| Épics (`epics.md`) | 1 exemplaire | 12 épics (E1–E11b, dont E11a intercalé), ~56 stories |
| Brief (`brief.md`) | Grounding | Auto-incohérent (corps prescrit Riverpod vs sa propre section « Décisions verrouillées ») |
| Inventaire technique (`technical-inventory.md`) | Grounding | §4.2/§5.2 prescrivent « Paradigme UNIQUE = Riverpod » — non réconcilié avec AD-15 |
| Schéma canonique (`canonical-schema.md`) | Grounding | ZHierarchyNode/ZSemanticContext proéminents mais non repris en aval |
| **UX (doc séparé)** | **Absent** | **Statut légitime** pour un produit-développeur : l'UX end-user pertinente (rebuild granulaire, RTL/a11y, structure de formulaire) est intégrée au PRD/architecture. Deux surfaces UX de librairie restent toutefois non planifiées (theming, doc intégrateur — cf. §6). |

## 3. Analyse PRD (FR/NFR)

- **FR total : 25** (FR-1 à FR-25), groupées par fonctionnalité, chacune assortie de « Conséquences (testables) » concrètes.
- **NFR total : 13** — Annexe A : 6 (perf édition, rétro-compat sérialisation, offline-first, pureté des couches, RTL/a11y, zéro réflexion) ; Annexe B : 4 (surface API, versionnage, budgets perf, cibles runtime/deps) ; Annexe C : 3 (sécurité, contraintes lex_douane, contraintes DODLP).
- **Autres :** 6 métriques de succès (SM-1..SM-6, 3 primaires) + 2 contre-métriques ; 12 OQ (6 résolues) ; 3 hypothèses ; 6 Non-Goals.

**Qualité intrinsèque : bonne base, mais FR vagues / non chiffrées à corriger :**

- **FR-2 (majeur)** — catalogue de types « figé » mais cardinalité imprécise et incohérente (« ~37 » dans le glossaire vs « union 37-40 » dans l'inventaire) ; il pilote pourtant la métrique primaire SM-2 (parité type-par-type). La validation transverse reste une liste ouverte (« required, min/max, email, url, match, **etc.** »).
- **FR-15 (majeur)** — contradiction sur le moteur LaTeX : `flutter_math_fork` (conséquence FR-15) vs `flutter_tex`/`html_editor_enhanced` (§4.5 et Annexe B.4). Deux moteurs distincts (natif vs WebView) → impacte NFR-B4 (isolation deps).
- **FR-8 (majeur)** — surchargée (ACL + sélection + corbeille + export) ; la « corbeille » n'a **aucune** conséquence testable, l'export est simultanément « optionnel ».
- **Mineurs** : FR-13 (« cascade bornée », « débouncée », « best-effort » non chiffrés) ; FR-3 (grille 12 colonnes sans breakpoints testables) ; FR-7 (repli in-memory renvoyé à la doc) ; FR-18 (modes « défensifs » non définis) ; Annexe B.3 (budgets perf non chiffrés hors O(1)).

## 4. Traçabilité FR → Stories (matrice)

| FR | Story(ies) | Statut |
|---|---|---|
| FR-1 | E3-1, E3-2 | Couvert |
| FR-2 | E3-3a, E3-3b | **Partiel** — fichier/image/document, password, hidden, icon, inlineHtml non couverts par story |
| FR-3 | E3-4 | Couvert |
| FR-4 | E3-5 | Couvert |
| FR-5 | E3-6 | Couvert |
| FR-6 | E4-1, E4-2 (+E4-5) | Couvert |
| FR-7 | E4-3 | Couvert |
| FR-8 | E4-4 + E11a-3/E11b-3 (export) | Couvert |
| FR-9 | E2-4, E2-5 | Couvert |
| FR-10 | E2-3, E2-5 | Couvert |
| FR-11 | E2-6, E7-2, E8-1 | Couvert |
| FR-12 | E2-2, E5-1 | Couvert |
| FR-13 | E5-2, E5-3, E5-4 | Couvert |
| FR-14 | E6-1, E6-2 | Couvert |
| FR-15 | E6-3, E6-4 | Couvert |
| FR-16 | E9-1 | Couvert |
| FR-17 | E9-2 | Couvert |
| FR-18 | E9-3 | Couvert |
| FR-19 | E10-1, E10-2, E10-3 | Couvert |
| FR-20 | E11a-1, E11b-1 | Couvert |
| FR-21 | E11a-2, E11b-2 | Couvert |
| FR-22 | E2-7, E2-9 | Couvert |
| FR-23 | E2-8 (+AC a11y E3/E8/E10) | Couvert |
| FR-24 | E1-1, E1-2, E4-1 | Couvert |
| FR-25 | E1-4, E8-3 | Couvert |

**Statistiques de couverture :** 24/25 pleinement couverts (**96 %**), 1 partiel (FR-2), 0 orphelin. Couverts au moins partiellement : **25/25 (100 %)**.

**Hygiène de traçabilité :** 3 stories ancrées sur AD/SM/NFR plutôt que FR (E1-5 → AD-12/Annexe C ; E1-3, E2-10 → SM-6/AD-10) — légitime pour un produit-librairie mais à documenter. **E4-5 référence un « FR-6b » inexistant** (la capacité sous-listes/onglets vit en prose §4.2, non numérotée).

## 5. Couverture des décisions d'architecture (AD)

| AD | Story / FR | Statut |
|---|---|---|
| AD-1 (monorepo, graphe acyclique) | E1-1, E1-2 / FR-24, FR-25 | Couvert |
| AD-2 (rebuilds granulaires, réactivité pur-Flutter) | E2-7, E3-1/2/5 / SM-1 | **Partiel — diagramme contradictoire** |
| AD-3 (codegen, reflectable banni) | E2-4, E2-5, E1-3 | Couvert |
| AD-4 (extension : ZExtension+extra par entité) | E2-3 / FR-10 | **Partiel — non câblé par entité** |
| AD-5 (domaine backend-agnostique) | E2-2, E5-2 | Couvert |
| AD-6 (injection pluggable) | E2-7, E2-9, E7-1 | Couvert |
| AD-7 (rich-text Delta + ZCodec) | E6-1, E6-2 | Couvert |
| AD-8 (Syncfusion isolé dans zcrud_list) | E4-1 / SM-5 | Couvert (pkg absent du grounding) |
| AD-9 (offline-first LWW, SRS séparé) | E5-3/4, E9-2/4 | **Partiel — clause « contenu publié » orpheline** |
| AD-10 (schéma additif, désérial. défensive) | E2-5, E2-10 | Couvert |
| AD-11 (Either<ZFailure,T>, Stream nu) | E2-1, E2-2, E3-6 | Couvert |
| AD-12 (zéro secret, pas de contournement TLS) | E1-5, E11a-1/3 | Couvert |
| AD-13 (RTL/a11y/l10n injectable) | E2-8, E3-3/4, E10-2 | Couvert (Binds sous-estimé → FR-23 seul) |
| AD-14 (pureté des couches) | E2-1, E1-2, E9-3/4 | Couvert |
| AD-15 (multi-gestionnaire par bindings) | E2-9, E7-1, E8-1 | Couvert |
| AD-16 (ACL + pagination curseur neutres) | E2-2, E4-3/4, E5-1 | Couvert |

**Contradictions PRD ↔ Architecture :**
- **[CRITIQUE]** Diagramme « Cycle réactif du formulaire (AD-2) » (architecture.md L216-225) étiquette `EditionFormNotifier (Riverpod)` et `ZFieldWidget (ConsumerWidget)` — reliquat pré-AD-15 qui contredit AD-2/AD-15 (aucun gestionnaire d'état dans zcrud_core). Un implémenteur suivant ce diagramme importerait Riverpod dans le cœur → casse SM-5/AD-1. Le même paradigme périmé irrigue le corps du Brief, l'inventaire §4.2/§5.2 et le glossaire PRD (ZcrudScope « + seams Riverpod »).
- **[MAJEUR]** `zcrud_list` (AD-8) et les bindings `zcrud_riverpod/get/provider` (AD-15) sont absents de la liste de packages du Brief et de l'inventaire §6, qui placent Syncfusion dans zcrud_core.
- **[MAJEUR]** AD-4 exige `extra`+`ZExtension?` sur chaque entité canonique, mais aucune AC ne l'impose sur ZFlashcard (E9-1), ZStudyFolder (E9-3), ZMindmapNode (E10-1).
- **[MAJEUR]** ZHierarchyNode / ZSemanticContext (canonique §2.4, « le générique évident à factoriser », « à porter tel quel ») ont disparu de l'architecture/PRD/épics sans décision de report — contrairement à la génération LLM et Supabase, explicitement différées.
- **[Mineurs]** Deferred renvoie la pagination curseur à AD-5 au lieu d'AD-16 ; double gouvernance FR-7/FR-8 dans la capability map ; invariant AD-9 « contenu publié distinct » sans FR/story.

## 6. Alignement UX

L'absence de doc UX séparé est **légitime** : l'UX end-user (rebuild granulaire sans jank, RTL/a11y, structure de formulaire) est correctement intégrée au PRD/architecture et couverte par des stories (E3-1/2, E2-8, E3-3/4, E10-2). Deux surfaces UX propres à un **produit-librairie** restent néanmoins **non planifiées** :

- **[MAJEUR] Theming / design-tokens injectables** — aucun FR ni story ne couvre la manière dont l'app hôte style le chrome CRUD. L'inventaire §7 identifie le couplage à casser (`kNavyColor`, `kFormInputDecorationTheme`) et §8.1-4 cite `ZcrudConfig/ThemeExtension`, mais rien n'est promu en FR/story. Le seam `config` de ZcrudScope reste vague.
- **[MINEUR] Doc intégrateur + app example** — `example/` est listé en Structural Seed mais aucune story ne le produit ; aucun README/API-docs/guide de migration DODLP, alors qu'UJ-1 est une migration de ~180 fichiers.

## 7. Qualité des épics & stories

**Critique**
- Diagramme AD-2 « Riverpod/ConsumerWidget » (déjà détaillé §5) — trap de cohérence sur le chemin critique E3 et l'objectif produit n°1.

**Majeurs**
- **Numérotation ≠ ordre d'exécution** — E7 (dépend E11a) et E9 (dépend E11a) requièrent un épic numéroté **après** eux (11 > 7, 11 > 9). Un plan de sprint ordonnancé par numéro casserait le build (parité DODLP géo/tél/export absente). Preuve : epics.md L119, L134.
- **Graphe mermaid incohérent** — l'arête **E11a→E9 est absente** du diagramme alors que l'en-tête E9 et la note L46 l'affirment (« E7 et E9 dépendent de E11a »).
- **E2-9 surdimensionnée** — « setup all bindings » livre 3 packages (zcrud_riverpod + get + provider) + test croisé en une seule story, malgré la revendication de « découpage des stories surdimensionnées » (L18).
- **E2 méga-épic goulot** — 10 stories, aucune indépendamment expédiable, dépendance de 5 épics ; E2-5 (générateur complet : toMap/fromMap/copyWith + ZFieldSpec + enregistrement + enums + sentinelle + round-trip) est à lui seul un livrable majeur.
- **UJ-4 sans métrique** — les widgets flashcards/mindmaps additifs pour lex_douane (besoin explicitement « chargé émotionnellement ») sont livrés par E9/E10 mais aucune SM ne valide l'intégration additive (paramétrage par entité hôte, non-remplacement du module Étude, offline-first préservé).

**Mineurs**
- FR-23 omis du rollup d'en-tête de E2 (pourtant réalisé par E2-8).
- E10-3 (éditeur outline) sous-spécifiée : une seule AC vague, pas d'ops indent/outdent/reorder, pas de FR rattaché.
- Format « En tant que… je veux… » et Given/When/Then quasi absents (E4/E5/E8 = titres-tâches + puces).
- E7-3 (migration ~180 fichiers DODLP) non bornée : pas de découpage de lots ni DoD par lot ni critère de complétude global (0 import legacy).
- Cas d'erreur d'injection/ACL absents en E4-4, E7-1/2, E8-1/2 (effort inégal vs E4-3/E5-4/E6-3-4 qui les ont).
- Incohérence de grounding : 6 types de flashcards (PRD/canonique) vs « 4 types » (Brief/inventaire §2.7).
- E1-5 (révocation clé Maps) ignore le rollout cross-repo : la clé vit en clair dans DODLP **et** DLCFTI en prod → préférer la restriction + redéploiement coordonné à la révocation sèche.

## 8. Lacunes transverses & questions ouvertes bloquantes

**OQ bloquant le MVP (E1–E8) : 0.** Aucune question ouverte ne bloque l'implémentation du MVP.

- **Réellement ouvertes mais non bloquantes :** OQ-2 (portée du/des registre(s) — touche le design d'E2-3, à trancher en tête d'E2 car conditionne la surface API publique) ; OQ-5 (level mindmap — v1.x, E10).
- **Marquées « ouvertes » dans PRD §8 mais déjà tranchées en aval (PRD trompeur) :** OQ-6 (deps LaTeX optionnelles → FR-15/E6-4), OQ-8 (ZFieldSpec unique + ZLocalStore → FR-6/AD-5/E5-2), OQ-10 (reparentage mindmap → FR-19/E10-1), OQ-12 (casse → Consistency/Deferred). À re-synchroniser.
- **Correction de prémisse :** OQ-3, OQ-4, OQ-9 sont marquées **✅ Résolu** dans le PRD (et non ouvertes).
- **Modèles canoniques sans décision de scope :** ZHierarchyNode, ZSemanticContext (ni portés ni exclus — cf. §5).

## 9. Findings priorisés (dédoublonnés)

### Critique (1)
1. **Substrat de réactivité « Riverpod » vs cœur Flutter-native** — diagramme AD-2 (architecture L216-225) + Brief + inventaire §4.2/§5.2 + glossaire PRD contredisent AD-2/AD-15. Impacte E3 (chemin critique, objectif n°1). *(fusion des findings agent-3 critique + agent-5 majeur)*

### Majeurs (11)
2. **FR-2 partiel** — cardinalité imprécise (« ~37 » vs « 37-40 ») **et** types fichier/image/document, password, hidden, icon, inlineHtml sans story d'édition (l'architecture place pourtant le champ fichier dans zcrud_core, L301). Risque direct sur SM-2 (parité DODLP). *(fusion agent-1 + agent-2)*
3. **FR-15** — contradiction moteur LaTeX (flutter_math_fork vs flutter_tex/html_editor_enhanced).
4. **FR-8** — surchargée ; « corbeille » sans conséquence testable.
5. **Numérotation épics ≠ ordre d'exécution** (E7/E9 dépendent d'E11a numéroté après).
6. **Graphe mermaid** — arête E11a→E9 manquante.
7. **E2-9 surdimensionnée** (3 bindings en 1 story).
8. **E2 méga-épic goulot** + E2-5 découpage insuffisant.
9. **zcrud_list & bindings absents du grounding** (Brief/inventaire placent Syncfusion dans le cœur).
10. **AD-4 non câblé par entité** (extra/ZExtension? absents des AC E9-1/E9-3/E10-1).
11. **ZHierarchyNode / ZSemanticContext** hors périmètre sans décision de report. *(fusion agent-3 + agent-5)*
12. **UJ-4 sans métrique de succès** + **theming injectable non planifié** (deux lacunes de validation/UX produit-librairie).

### Mineurs (regroupés)
- **PRD/grounding :** OQ-6/8/10/12 obsolètes en §8 ; glossaire incomplet (ZChoice, ZSyncMeta, ZSyncOrchestrator, ZcrudScope Riverpod-centré) ; 4 vs 6 types de flashcards ; résidus d'authoring (`status: draft`, `[NOTE FOR PM]`).
- **FR non chiffrées :** FR-13 (cascade/debounce/best-effort), FR-3 (breakpoints), FR-7 (repli in-memory), FR-18 (modes « défensifs »), Annexe B.3 (budgets perf).
- **Traçabilité :** E4-5 « FR-6b » inexistant ; FR-23 absent du rollup E2 ; Binds AD-13 sous-estimé ; double gouvernance FR-7/FR-8 ; références Deferred AD-5 vs AD-16 ; invariant AD-9 « contenu publié » orphelin ; SM ne couvrent qu'un sous-ensemble des FR.
- **Épics :** E10-3 vague ; E7-3 non bornée ; format story/GWT absent ; cas d'erreur manquants (E4-4, E7, E8) ; debounce ~250ms/non-recompute décoration non repris en AC d'E3-2.
- **Opérationnel :** E1-5 rollout cross-repo DODLP/DLCFTI non coordonné ; doc intégrateur + example app non planifiés.

## 10. Recommandations & prochaines étapes

**Bloquant avant de démarrer E3 (chemin critique) :**
1. **Réécrire le diagramme AD-2** en ZFormController (ChangeNotifier) → ValueListenable par champ → ListenableBuilder ; supprimer toute mention Riverpod/ConsumerWidget. Annoter Brief, inventaire §4.2/§5.2 et glossaire PRD comme *superseded* par AD-15.
2. **Ajouter les AC anti-rebuild à E3-2** : décision explicite sur le debounce (~250 ms ou non), non-recompute décoration/validateurs par frappe (Annexe A).

**Avant de figer le séquencement de sprint :**
3. **Renuméroter** le lot parité (E11a) en position d'exécution réelle, ou le sortir de la série numérique (« Lot-Parité-DODLP »). **Ajouter l'arête E11a→E9** au mermaid (ou la marquer optionnelle).
4. **Scinder E2** (contrats+données / codegen+extensibilité / bindings+réactivité) et **E2-9** (une story par binding + une story de conformité multi-binding). Découper E2-5.

**Avant de geler le PRD comme référence :**
5. **Figer FR-2** : liste dénombrée et exhaustive des types (N exact) + liste close des validateurs ; **ajouter une story champ fichier/image/document + password/hidden/icon/inlineHtml** dans zcrud_core.
6. **Trancher FR-15** (moteur LaTeX canonique) et **scinder FR-8** (isoler corbeille + AC testable, et export).
7. **Aligner le grounding** : ajouter zcrud_list + bindings à la liste de packages ; harmoniser 6 types de flashcards ; compléter le glossaire.

**Complétude de périmètre / validation :**
8. **Trancher ZHierarchyNode / ZSemanticContext** : Non-Goal explicite (§5) ou story de portage.
9. **Ajouter une AC `extra`+`ZExtension?`** à chaque entité canonique (E9-1, E9-3, E10-1).
10. **Ajouter SM-7 (UJ-4)** et **une FR/story theming injectable** (ThemeExtension/InputDecorationTheme via seam).
11. **Synchroniser PRD §8** (marquer OQ-6/8/10/12 résolues) ; trancher OQ-2 (portée registre) en tête d'E2.

**Opérationnel :**
12. Reformuler E1-5 en restriction + redéploiement coordonné DODLP/DLCFTI ; planifier une story « example app + doc intégrateur/migration ».
