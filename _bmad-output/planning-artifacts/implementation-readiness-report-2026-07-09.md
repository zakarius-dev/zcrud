# Rapport de complétude d'implémentation — zcrud
**Date:** 2026-07-09 · **Projet:** zcrud

## 1. Verdict global

**NEEDS WORK.**

Le socle de planification est dense et globalement implémentable : les 25 FR, 14 AD et 48 stories/11 épics couvrent le chemin critique MVP (E1→E8), le graphe des 12 packages est acyclique, et la traçabilité FR→story (96 %) comme métrique→story (SM-1..SM-6 tous rattachés) est excellente. Le contexte est un **produit-développeur brownfield** : les épics fondations E1 (melos/CI/gate de compat) et E2 (contrats/codegen/injection) sont des habilitations légitimes, à condition d'expliciter leur valeur pour l'intégrateur. Cependant, trois défauts de sévérité **critique** empêchent une entrée en implémentation directe : (1) une contradiction PRD↔architecture sur la dépendance Riverpod du cœur qui menace la métrique primaire SM-2, (2) deux dépendances de phase inversées (MVP → post-MVP) non déclarées, (3) un secret (clé Google Maps) dont la révocation n'est capturée par aucune story. Aucun n'est rédhibitoire sur le fond — tous sont résolubles par des corrections ciblées de cohérence, quelques AC/stories manquantes et un action-item sécurité — d'où NEEDS WORK plutôt que NOT READY.

## 2. Inventaire des documents

| Document | Présence | Statut |
|---|---|---|
| PRD (`prd.md`) | 1, pas de doublon | Complet, haute qualité intrinsèque |
| Architecture (`architecture.md`) | 1, pas de doublon | 14 AD, 6 [ADOPTED] |
| Épics (`epics.md`) | 1, pas de doublon | 11 épics / 48 stories |
| Brief (`brief.md`) | Présent (grounding) | **Obsolète sur 2 points verrouillés** (freezed, packages) |
| Inventaire technique (`technical-inventory.md`) | Présent (grounding) | Cohérent, mais ne référence pas zcrud_list/zcrud_riverpod |
| Schéma canonique (`canonical-schema.md`) | Présent (grounding) | Source des modèles portés |
| **Doc UX séparé** | **Absent** | WARNING défendable (produit-développeur, UX intégrée au PRD via FR-1/FR-3/FR-23 + AD-2/AD-13, thème hérité de l'app hôte). Acceptable **sous réserve** d'ajouter les AC a11y/RTL par-widget et les états d'interaction manquants (voir §6). |

## 3. Analyse PRD (FR/NFR)

- **25 FR** (FR-1..FR-25), toutes numérotées globalement et dotées de « Conséquences (testables) » concrètes, tracées aux parcours UJ-1..4 et métriques SM-1..6.
- **14 clusters NFR** : Annexe A (NFR-A1..A6 transverses), Annexe B (surface d'API, versionnage, budgets perf, politique deps), Annexe C (sécurité ×2 + contraintes cibles lex_douane/DODLP).
- **6 métriques** SM-1..SM-6 + 2 contre-métriques ; 6 Non-Goals explicites ; 12 OQ (dont 3 résolues : OQ-1, OQ-7, OQ-11) ; 3 hypothèses indexées §9.
- Qualité globale élevée (Glossaire verbatim, index des hypothèses, registre d'OQ), mais **défauts de testabilité/cohérence réels** :
  - **FR-2 / SM-2 non testable** : parité sur « ~37 » types alors que le grounding chiffre « 37-40 ». Sans liste figée, le critère d'acceptation majeur (objectif produit n°1) est passer/échouer sur un nombre flou.
  - **FR-14 contradiction interne** : format rich-text « figé et documenté » vs OQ-1 (résolu) « pluggable via ZCodec ».
  - **FR-7 vs OQ-9** : pagination curseur affirmée « dans le contrat neutre » alors que OQ-9 pose la question comme non tranchée. « Champs pertinents » pour la recherche sans accents jamais défini (aucune propriété ZFieldSpec `searchable`).
  - **NFR-A4 ambigu** : « cœur canonique Dart pur » non mappé à un package ; laisse croire à tort que zcrud_core (qui contient DynamicEdition Flutter) doit être sans Flutter.
  - **FR-11** : une « conséquence testable » est en réalité une [HYPOTHÈSE] (@JsonSerializable pur).
  - **FR vagues/adossées à OQ** : FR-4→OQ-4, FR-13→OQ-8, FR-15→OQ-6, FR-19→OQ-5/10 — pas prêtes au découpage tant que l'OQ n'est pas tranchée.

## 4. Traçabilité FR → Stories (matrice)

| FR | Story | Statut |
|---|---|---|
| FR-1 | E3-1, E3-2 | Couvert |
| FR-2 | E3-3 (+E3-2) | Couvert |
| FR-3 | E3-4 | Couvert |
| FR-4 | E3-5 | Couvert (adossé OQ-4) |
| FR-5 | E3-6 | Couvert |
| FR-6 | E4-1, E4-2 | Couvert |
| FR-7 | E4-3 (+E2-2) | Couvert (adossé OQ-9) |
| FR-8 | E4-4 ; export E11-3 | Couvert (décalage de phase, cf. §7) |
| FR-9 | E2-4, E2-5 | Couvert |
| FR-10 | E2-3 (+E9-1, E10-1) | Couvert |
| FR-11 | E2-6 | Couvert |
| FR-12 | E2-2 (+E5-1) | Couvert |
| FR-13 | E5-2, E5-3, E5-4 | Couvert |
| FR-14 | E6-1, E6-2 | Couvert |
| FR-15 | E6-3, E6-4 | Couvert |
| FR-16 | E9-1 | Couvert |
| FR-17 | E9-2 | Couvert |
| FR-18 | E9-3 | Couvert |
| FR-19 | E10-1, E10-2, E10-3 | Couvert |
| FR-20 | E11-1 | Couvert |
| FR-21 | E11-2 | Couvert |
| FR-22 | E2-7, E7-1 | Couvert |
| **FR-23** | E2-8 (l10n/RTL) ; a11y widget en E8-2/E10-2 seulement | **Partiel** — a11y widget-level (Semantics, ≥48 dp, insets directionnels) sans AC en E3/E4 |
| FR-24 | E1-1, E1-2 | Couvert |
| FR-25 | E1-4 (+E8-3) | Couvert |

**Statistiques de couverture :** 24/25 Couverts (96 %), 1/25 Partiel (FR-23, 4 %), **0 Manquant**. FR MVP (§6.1) toutes tracées ; FR différées FR-16..FR-21 tracées en E9/E10/E11.

**Stories orphelines (sans FR pilote) :** E4-5 (sous-listes/relations & onglets — capacité en prose §4.2 jamais promue en FR), E1-3 (lint/CI — infrastructure légitime mais non rattachée à un NFR/SM-6).

## 5. Couverture des décisions d'architecture (AD)

| AD | Réalisation (story/FR) | Statut |
|---|---|---|
| AD-1 | E1-1, E1-2 | Couvert |
| AD-2 | E3-1, E3-2, E6-1 (SM-1) | Couvert — **mais dépendance Riverpod du cœur non assumée (critique)** |
| AD-3 | E2-4, E2-5 | Couvert |
| AD-4 | E2-3, E9-1, E10-1 | Couvert |
| AD-5 | E2-2, E5-1, E5-2 | Couvert |
| AD-6 | E2-7, E7-1 | Couvert — nuance seams DI ≠ substrat d'état Riverpod |
| AD-7 | E6-1, E6-2 | Couvert |
| AD-8 | E4-1 | Couvert |
| AD-9 | E5-3, E5-4, E9-2 | **Partiel** — clause « contenu publié cache-first + checksum » (ZPublishedDoc) sans story |
| AD-10 | E2-3, E2-5 | Couvert — discipline « additif seulement » non testée |
| AD-11 | E2-1, E2-2, E4, E5-1 | Couvert |
| AD-12 | E11-1, E11-3 | Couvert (phase v1.x/v2) |
| AD-13 | E2-8, E8-2, E10-2 | Couvert |
| AD-14 | E2-1, E5-3, E9 | Couvert |

**Contradictions PRD↔architecture :**
- **[CRITIQUE] Riverpod du cœur.** AD-2 place les ConsumerWidget + EditionFormNotifier (Riverpod) DANS zcrud_core (l.60-63, 213 ; inventaire §6 liste `flutter_riverpod` en dep de zcrud_core), alors que le paradigme dit « le cœur n'en dépend pas directement » (l.28), AD-6 « aucun conteneur d'injection » (l.82) et le PRD promet DODLP « migré sans Riverpod » (UJ-1 l.51, hypothèse §6.1 l.399) avec « bootstrap inchangé » (SM-2). Si le moteur est fait de ConsumerWidget/Notifier, DODLP doit intégrer flutter_riverpod + un ProviderScope — l'hypothèse « sans Riverpod » et **la métrique primaire SM-2** sont menacées.
- **[MAJEUR] 7 FR sans AD gouvernante.** L'en-tête déclare « binds FR-1..FR-25 » mais FR-2, FR-4, FR-5, FR-7, FR-8, FR-21, FR-25 n'apparaissent dans le `Binds:` d'aucune AD. Des décisions non triviales restent sans invariant : ZAcl (FR-8), pagination curseur dans le contrat neutre (FR-7/OQ-9), enveloppe stepper (FR-4/OQ-4), budget assets (FR-21).
- **[MAJEUR] freezed.** Le brief verrouille « freezed + json_serializable » (l.18, l.92) ; AD-3, FR-11 et canonique §5 imposent l'inverse (« freezed NON imposé » / « PAS de freezed »). Décision verrouillée renversée sans mise à jour du brief.
- **[MAJEUR] graphite vs graphview.** Architecture/épics/inventaire spécifient `graphite ^1.2.1` (viewer) ; le canonique décrit ZMindmapView avec `graphview` + BuchheimWalker. Deux libs d'auto-layout sans arbitrage.
- **[MINEUR] Grounding aval non répercuté.** zcrud_list et zcrud_riverpod (12 packages en arch/PRD/épics) absents du brief et de l'inventaire (10 packages).

## 6. Alignement UX

L'absence de doc UX séparé est un **WARNING acceptable** pour un produit-développeur (UX intégrée au PRD, thème hérité de l'app hôte). Mais elle a laissé des trous d'AC concrets qui doivent être comblés :

- **A11y/RTL au niveau composant manquants** sur la surface UX principale : E3-3 (dispatcher + ~37 ZFieldWidget) et E3-4 (grille responsive) n'ont **aucun AC** RTL (EdgeInsetsDirectional/AlignmentDirectional/TextAlign.start), Semantics, cibles ≥48 dp — alors que l'a11y est « non négociable » (Annexe C), SM-3 la mesure, et FR-23 l'exige. La conformité n'est vérifiée qu'au plumbing l10n (E2-8), en intégration lex_douane (E8-2) et vue liste mindmap (E10-2, v1.x).
- **États d'interaction non spécifiés** : DynamicList (loading, empty, no-results-après-filtre, error) et DynamicEdition (submit-in-progress, échec de soumission) n'ont aucune AC de rendu accessible, bien que AD-11 gère AsyncValue.error côté providers.
- **Edge case UJ-2 non storié** : « perte de connexion pendant la saisie → l'état du formulaire n'est pas perdu » (distinct de l'offline-first données E5) sans AC sur le EditionFormNotifier.

## 7. Qualité des épics & stories

**11 épics, 48 stories** (E1=4, E2=8, E3=6, E4=5, E5=4, E6=4, E7=4, E8=3, E9=4, E10=3, E11=3). Structure globalement saine : story de setup melos (E1-1), gate de compat (E1-4), stories brownfield DODLP (E7) / lex_douane_admin (E8) / additifs lex (E9-4, E10-3), 25 FR et 14 AD tous rattachés, beaucoup d'AC mesurables (E3-1, E5-1, E6-2).

**Findings par sévérité :**

**Critique**
- **[C4-1] E7 (MVP) dépend de E11 (post-MVP).** La parité ~37 types + « export préservé » validées en E7-4 (métrique **primaire** SM-2) requièrent les widgets geo/téléphone/pays/adresse (zcrud_geo/zcrud_intl = E11-1/E11-2, FR-20/21) et l'export (zcrud_export = E11-3). E7 déclare « Dépend de E3, E4, E5, E6 » (omet E11), et E11 est séquencé APRÈS E7. **Preuve :** E7-4 AC + catalogue DODLP inventaire §3 + phasage §6.2.

**Majeur**
- **[C4-2] E9 → E11 non déclarée.** zcrud_flashcard dépend de zcrud_export (architecture « FC → EXP », inventaire §6, canonique §2.7), mais E9 déclare seulement « E2, E5, E6 » et aucune arête E9→E11 dans le mermaid.
- **[C3-1] E7-3 surdimensionnée** : re-pointer 180 imports + supprimer le code dupliqué de src/ = charge d'un épic, non complétable en une unité de sprint.
- **[C3-2] E3-3 surdimensionnée** : dispatcher + ~37 widgets en une story ; son AC « aucun default silencieux sur tout le catalogue » est intenable dans les dépendances déclarées d'E3 (markdown en E6, geo/intl en E11).
- **[C1-1] E2 « fourre-tout »** : 8 stories / 6 FR / 7 AD sur le chemin critique, contredit la note « prioriser E2 juste ce qu'il faut pour débloquer E3 » (E2-5 générateur complet déjà lourd).

**Mineur**
- **AC de cas d'erreur manquants** (exigés par les AD) : E6-3/E6-4 (embed LaTeX/tableau malformé → repli sûr, AD-10), E5-4 (échec partiel de sync « best-effort », AD-9), E4-3 (curseur invalide/backend sans curseur), E9 (invariant canonique « SRS jamais dans le sous-arbre partageable, collection top-level » + dépôt offline-first ZFlashcard).
- **Format Given/When/Then absent** partout (AC restent testables → mineur ; recommandé pour E3-1, E5-1, E6-2, E7-4).
- **Valeur E1/E2** énoncée comme outillage sans résultat end-to-end (légitime mais à expliciter).
- **FR-8 décalage de phase** : FR MVP (§6.1) dont la sous-exigence export est livrée en E11 (v1.x/v2) — à marquer explicitement différée.

## 8. Lacunes transverses & questions ouvertes bloquantes

**OQ bloquant réellement le MVP :**
- **OQ-4 (stepper) — la seule vraie tension MVP non tranchée.** Envelopper l'arbre stepper dans un unique conteneur `flutter_form_builder` entre en conflit latent avec AD-2 (un champ = ConsumerWidget, aucun setState de formulaire). La coexistence flutter_form_builder (GlobalKey<FormBuilderState>, listé au Stack) ↔ EditionFormNotifier granulaire n'est décrite nulle part (le diagramme du cycle réactif AD-2 ne mentionne pas form_builder). Touche E3-1/E3-2/E3-5. Risque : réintroduire le rebuild global (le bug historique).

**OQ non bloquantes (résolues ailleurs ou correctement déférées, mais PRD §8 obsolète) :** OQ-3 est ADOPTED par AD-6 ; OQ-8 (ZLocalStore) et OQ-9 (curseur) déférées avec stories (E4-2/E2-2/E4-3) ; OQ-5/OQ-10/OQ-12 déférées en v1.x. Le PRD §8 les liste encore « ouvertes » → à synchroniser.

**Lacunes transverses :**
- **Modèles canoniques abandonnés silencieusement** : ZHierarchyNode (« LE générique évident à factoriser ») et ZSemanticContext (archétype d'extension versionné) — canonique §3 « à porter » — absents de PRD/architecture/épics sans note de report. ZPublishedDoc/ZDownloadCache : distinction reconnue (AD-9) mais sans modèle ni story.
- **Gate de test rétro-compat sérialisation absent** : AD-10 (« un champ absent/corrompu ne fait jamais échouer le parent ») affirmé en AC mais sans story de gate CI (seul SM-4/round-trip Markdown E6-2 en a un). OQ inventaire §9 #13 non résolue.
- **SM-6 sans enforcement** : aucun lint/gate CI ne bannit reflectable dans le moteur, ne scanne les secrets, ni ne vérifie le 100 % codegen ; le volet « zéro secret » est de plus couplé à E11 (post-MVP).

## 9. Findings priorisés (regroupés par sévérité, dédoublonnés)

### Critiques (3)
1. **Riverpod dans zcrud_core vs « DODLP sans Riverpod »** (AD-2 ↔ AD-6/UJ-1/SM-2) — menace la métrique primaire SM-2. *(§5)*
2. **E7 (MVP) → E11 (post-MVP)** : parité SM-2 + export dépendent de widgets/export post-MVP. *(§7)*
3. **Clé Google Maps commitée en clair** : sa non-inclusion dans les packages est couverte (E11-1) mais sa **révocation/restriction** (« action immédiate ») n'a aucune story, ni owner, ni échéance, et E11 est post-MVP. *(brief l.109, inventaire §2.9/§7, AD-12, Annexe C)*

### Majeurs (9)
4. **FR-14** contradiction figé vs pluggable (OQ-1).
5. **FR-2 / SM-2** parité « ~37 » non testable (liste non figée).
6. **FR-7** pagination curseur affirmée vs OQ-9 non tranchée.
7. **NFR-A4** « cœur canonique » ambigu vs package zcrud_core (Flutter).
8. **FR-23 partiel** : a11y/RTL widget-level sans AC en E3/E4. *(dédup agents 2+5)*
9. **7 FR sans AD gouvernante** (FR-2/4/5/7/8/21/25) malgré « binds FR-1..25 ».
10. **freezed** : brief verrouille imposé vs PRD/arch/canonique non imposé. *(dédup agents 3+5)*
11. **graphite vs graphview** : lib d'auto-layout mindmap divergente.
12. **E9 → E11** graphe incohérent + **E7-3/E3-3 surdimensionnées** + **E2 fourre-tout** + **PRD §8 OQ obsolètes** + **OQ-4 stepper non tranchée** + **modèles canoniques manquants (ZHierarchyNode/ZSemanticContext/ZPublishedDoc)** + **gate test rétro-compat sérialisation absent**. *(regroupés — chacun majeur, cf. §7-8)*

### Mineurs (regroupés)
- FR-7 « champs pertinents » non défini ; FR-11 conséquence hypothétique ; FR-4/13/15/19 adossées à OQ non résolues.
- Stories orphelines E4-5 (sous-listes/onglets) et E1-3 (lint/CI).
- AC de cas d'erreur manquants (E6-3/4, E5-4, E4-3, E9) ; format GWT absent ; valeur E1/E2 à expliciter ; FR-8 décalage de phase.
- SM-6 sans gate CI ; états UI non spécifiés (DynamicList/DynamicEdition) ; edge case UJ-2 offline non storié.
- Collision de nommage **SM-2** (métrique parité ↔ algo SuperMemo-2) ; debounce ~250 ms non tranché ; glossaire incomplet (ZChoice/ZFlashcardSource/ZSyncMeta ; ZStudySession* ; FR-16 omet isReadOnly/subFolderId) ; zcrud_riverpod sans story d'implémentation ; AD-9 clause « contenu publié » sans story ; flutter_form_builder rôle résiduel non précisé.

## 10. Recommandations & prochaines étapes

**Bloquants à traiter AVANT implémentation (ordre) :**
1. **Sécurité — immédiat, hors séquencement produit :** révoquer + restreindre la clé Google Maps fuitée pendant E1, avec AC de vérification (la clé n'est plus valide). Découpler du volet E11.
2. **Trancher la dépendance Riverpod du cœur :** documenter que zcrud_core DÉPEND de flutter_riverpod pour l'ÉTAT (Notifier), distinct d'un conteneur de DI (seams). Corriger le paradigme + AD-6, et reformuler UJ-1/§6.1/SM-2 (DODLP intègre flutter_riverpod + ProviderScope pour le formulaire, injection des services en mode locator via ZcrudScope). Réévaluer explicitement l'hypothèse « sans Riverpod ».
3. **Réconcilier le séquencement de phase :** extraire un sous-ensemble « parité MVP DODLP » d'E11 (widgets geo/téléphone/pays/adresse + export DataGrid) séquencé AVANT E7 avec dépendance déclarée — OU statuer dans E7-4 que ces types restent servis par les widgets DODLP existants via ZTypeRegistry (parité par enregistrement) et ajuster SM-2. Idem trancher E9→E11 (export flashcard optionnel, ou dépendance déclarée). Aligner les deux graphes de dépendances.
4. **Résoudre OQ-4 (stepper)** et préciser dans l'architecture le rôle de flutter_form_builder (validation seule vs source d'état) et sa cohabitation avec EditionFormNotifier, avant E3.

**Corrections de cohérence documentaire :**
5. Figer la **liste canonique exacte** des EditionFieldType (table inventaire §3), remplacer « ~37 » par un compte énuméré, faire de SM-2 un checklist type-par-type. Renommer la collision SM-2/SuperMemo-2.
6. Reformuler **FR-14** (format par défaut documenté + surchargeable ZCodec), **FR-7** (au conditionnel + propriété `searchable`), **NFR-A4** (distinguer « modèles canoniques Dart pur » vs « package zcrud_core Flutter autorisé »).
7. Mettre à jour le **brief** (freezed non imposé, reflectable banni sauf ReflectableCodec DODLP ; introduction de zcrud_list/zcrud_riverpod). Synchroniser **PRD §8** avec les AD/Deferred. Trancher **graphite vs graphview**.
8. Ajouter les **AD/clauses manquantes** : ZAcl (FR-8), pagination curseur dans DataRequest neutre (FR-7), enveloppe stepper (FR-4), budget assets (FR-21) — ou corriger l'en-tête « binds FR-1..25 ».
9. Décider et documenter le sort de **ZHierarchyNode/ZSemanticContext/ZPublishedDoc** (porter ou Deferred justifié).

**Durcissement du backlog (avant de figer) :**
10. Ajouter des **AC a11y/RTL par-widget** à E3-3/E3-4 (Semantics, ≥48 dp, insets directionnels) + test a11y de référence sur le catalogue.
11. Ajouter les **AC de cas d'erreur** manquants (E6-3/4, E5-4, E4-3), une **story dépôt offline-first ZFlashcard** + invariant SRS top-level (E9), les **états UI** (E4/E3-6), l'edge case **UJ-2 offline** (E3-1).
12. Créer une **story gate CI** : tests de désérialisation défensive + round-trip sur documents historiques/tronqués (AD-10, inventaire §9 #13), et gate SM-6 (lint anti-reflectable, scan de secrets, contrôle codegen) dans E1-3.
13. **Découper** E7-3 (par lots, AC « app compile + tests verts après lot N »), E3-3 (par familles de champs), et documenter un ordre de sous-livraison intra-E2 pour débloquer E3 au plus tôt.
14. **Promouvoir ou déprioriser** les stories orphelines (E4-5 en FR-6b ou hors MVP ; E1-3 rattachée à SM-6), expliciter la valeur habilitante d'E1/E2.

Une fois les 4 bloquants levés et les corrections de cohérence §5-8 appliquées, le backlog est implémentable ; le verdict passera à READY.
