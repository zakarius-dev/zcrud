# Rapport de complétude d'implémentation — zcrud
**Date:** 2026-07-09 · **Projet:** zcrud

## 1. Verdict global

**NEEDS WORK.**

Le dossier est solide et proche du prêt : les 5 dimensions de validation convergent sur NEEDS_WORK, aucune sur NOT READY. La couverture FR→stories est de ~96 % (25/26 FR pleinement couverts), les 16 décisions d'architecture (AD-1..AD-16) sont chacune concrétisées par au moins une story, et il n'existe **aucune contradiction dure** entre le PRD et l'architecture. S'agissant d'un produit-développeur brownfield, les épics d'infrastructure (E1/E2) sont légitimes et leur valeur d'intégrateur est explicitée. Ce qui empêche le READY relève de trous ciblés et rattrapables : un défaut de traçabilité systématique de FR-26, une lacune de couverture sur le type de champ fichier (menaçant la métrique primaire SM-2), un offline-first MVP sans consommateur ni harnais de validation, et des scories de numérotation/comptage. Rien de bloquant fonctionnellement, mais la traçabilité et le périmètre de validation doivent être resserrés avant décomposition en stories exécutables.

## 2. Inventaire des documents

| Document | Présence | Statut |
|---|---|---|
| PRD | 1 | Présent, haute qualité intrinsèque, pas de doublon |
| Architecture (spine + AD-1..AD-16) | 1 | Présent, pas de doublon |
| Épics & stories (E1..E11, 56 stories) | 1 | Présent, post-remédiation |
| Brief produit | 1 | Présent (résumé exécutif partiellement périmé) |
| Inventaire technique | 1 | Présent (§6 désynchronisé sur le découpage packages) |
| Schéma canonique | 1 | Présent |
| Document UX séparé | 0 | **Absent** — architecture `companions: []` |

Statut UX : absence **défendable** pour un produit-développeur. Le rebuild granulaire (AD-2/SM-1), RTL/a11y (AD-13), le thème délégué (FR-26) et les états UI accessibles (loading/empty/no-results/error en E4-2 ; submit-in-progress/échec en E3-6) sont intégrés au PRD et à l'architecture. Ce n'est pas un bloqueur, mais un warning (voir §6).

## 3. Analyse PRD (FR/NFR)

- **FR : 26** (FR-1 à FR-26), tous présents. Anomalie : **FR-26 est hors séquence** (inséré en §4.9 entre FR-23 et FR-24), ce qui a déjà provoqué un mécompte « 25 FR » propagé dans les épics et l'architecture.
- **NFR : 13** (Annexe A : 6 transverses ; Annexe B : 4 ; Annexe C : 3).
- **Parcours** : 4 (UJ-1..UJ-4) ; **Métriques** : 6 SM (3 primaires, 3 secondaires) + 2 contre-métriques ; **Non-Goals** : 6 ; **OQ** : 12 (2 ouvertes OQ-2/OQ-5, 1 déférée OQ-12, 9 résolues).

**Qualité** : PRD de haut niveau — glossaire verbatim, « Conséquences (testables) » pour quasiment chaque FR, MVP séquencé, NFR ancrées.

**FR vagues / non testables identifiées** :
- **SM-2 / catalogue figé** : frontière inexacte (« ~37 » vs « 37-40 » vs types fallback `icon`/`hidden`/`password`) → la checklist de parité type-par-type n'est pas déterministe (majeur).
- **FR-3** : revendique une « grille responsive 12 colonnes » sans **aucune** conséquence testable (majeur).
- **FR-13** : bornes non chiffrées (« cascade bornée », « débouncée », « best-effort ») (majeur).
- **FR-8** : corbeille (soft-delete) et dégradation gracieuse de l'export annoncées sans critère testable dédié (mineur).
- Couverture métrique partielle : **14/26 FR** ne sont rattachés à aucune SM (FR-4,5,6,7,8,10,12,13,16,17,18,19,21,26).

## 4. Traçabilité FR → Stories (matrice)

| FR | Story(s) | Statut |
|---|---|---|
| FR-1 | E3-1, E3-2 (SM-1, AD-2) | Couvert |
| FR-2 | E3-3a, E3-3b | **Partiel** — type fichier/image/document + upload/storage sans story |
| FR-3 | E3-4 | Couvert (mais responsive sans AC côté PRD) |
| FR-4 | E3-5 | Couvert |
| FR-5 | E3-6 | Couvert |
| FR-6 | E4-1, E4-2, E4-5 | Couvert |
| FR-7 | E4-3, E2-2, E5-1 | Couvert |
| FR-8 | E4-4, E11a-3 | Couvert (dégradation export sans AC) |
| FR-9 | E2-4, E2-5, E1-3 | Couvert |
| FR-10 | E2-3, E2-5 | Couvert |
| FR-11 | E2-6, E7-2, E8-1 | Couvert |
| FR-12 | E2-1, E2-2, E5-1 | Couvert |
| FR-13 | E5-2, E5-3, E5-4 | Couvert |
| FR-14 | E6-1, E6-2 | Couvert |
| FR-15 | E6-3, E6-4 | Couvert |
| FR-16 | E9-1 | Couvert |
| FR-17 | E9-2 | Couvert |
| FR-18 | E9-3 | Couvert |
| FR-19 | E10-1, E10-2, E10-3 | Couvert |
| FR-20 | E11a-1, E11b-1, E1-5 | Couvert |
| FR-21 | E11a-2, E11b-2 | Couvert |
| FR-22 | E2-7, E2-9 | Couvert |
| FR-23 | E2-8, E3-3a/b, E3-4, E8-2 | Couvert |
| FR-24 | E1-1, E1-2, E4-1 | Couvert |
| FR-25 | E1-4, E8-3 | Couvert |
| FR-26 | E2-8 | **Partiel** — couvert par story mais non tracé (binds/capability map/AD) |

**Statistiques de couverture** :
- FR pleinement couverts : **25/26 (96 %)**
- FR partiels : 2 (FR-2, FR-26) · FR manquants (aucune story) : **0**
- Couverture pondérée (partiel = 0,5) : **~98 %**
- Stories sans FR directe mais légitimes (habilitation/sécurité/qualité) : E1-3 (gates CI/SM-6), E1-5 (révocation clé Maps/AD-12), E2-10 (rétro-compat/AD-10).

## 5. Couverture des décisions d'architecture (AD)

| AD | Concrétisée par | Statut |
|---|---|---|
| AD-1 | E1-1, E1-2 · FR-24 | Couvert |
| AD-2 | E2-7, E3-1, E3-2, E3-5 · FR-1..4 | Couvert |
| AD-3 | E2-4, E2-5, E1-3 | Couvert |
| AD-4 | E2-3, E9-1, E9-3, E10-1 | Couvert |
| AD-5 | E2-2, E5-1, E5-2 | Couvert |
| AD-6 | E2-7, E2-9, E7-1, E8-1 | Couvert |
| AD-7 | E6-1, E6-2 | Couvert |
| AD-8 | E4-1 · SM-5 | Couvert |
| AD-9 | E5-3, E5-4, E9-2, E9-4 | Couvert |
| AD-10 | E2-5, E2-10, E6-3, E6-4 | Couvert |
| AD-11 | E2-1, E2-2, E3-6, E4-2 | Couvert |
| AD-12 | E1-3, E1-5, E11a-1, E11a-3 | Couvert |
| AD-13 | E2-8, E3-3a/b, E3-4, E10-2 | Couvert |
| AD-14 | E2-1 (AC), E9-3, E9-4 | **Partiel** — aucun gate CI de pureté des couches |
| AD-15 | E2-9, E7-1, E8-1 | Couvert |
| AD-16 | E2-2, E4-3, E4-4, E5-1 | Couvert |

**Contradictions / tensions PRD↔Architecture** :
- **Aucune contradiction dure.** Réactivité Flutter-native, freezed non imposé, Syncfusion isolé, ZCodec pluggable, ports neutres : tout est aligné.
- **FR-26 orphelin côté architecture** : `binds` s'arrête à FR-25, aucun AD ne le gouverne (le PRD renvoie à AD-6/AD-13 qui ne mentionnent pas le thème), absent de la Capability→Architecture Map.
- **Décompte incohérent** : « 25 FR » (épics + architecture) vs 26 FR réels.
- **Ambiguïtés internes d'architecture** : pagination curseur (MVP sous AD-16 **et** listée en Deferred) ; `copyWith` avec sentinelle (AC ferme E2-5 vs marquée « à trancher » en Deferred, OQ-12).
- **3 FR gouvernées uniquement par le catch-all AD-1** : FR-5, FR-21, FR-25.
- **Groundings désynchronisés** : le brief et l'inventaire §6 ignorent zcrud_list et les 3 bindings, placent le moteur liste + flutter_riverpod dans zcrud_core (contredit AD-8/AD-15) ; le résumé exécutif du brief affirme encore « rebuilds via Riverpod » et « freezed + json_serializable » (contredit AD-2/AD-3/AD-15).

## 6. Alignement UX

Décision d'absence de doc UX **défendable** (produit-développeur). Les fondamentaux UX sont portés : rebuild (AD-2/SM-1), RTL/a11y (AD-13), états UI accessibles (E4-2, E3-6). **Warning** : des surfaces à forte UX end-user restent spécifiées fonctionnellement mais jamais comme flux d'interaction — stepper multi-étapes, sous-liste mini-CRUD, corbeille, recherche instantanée, sélection multiple (MVP) ; et en v1.x la révision flashcards 6 modes (flip/swiper/confetti) et l'éditeur mindmap zoom/pan + outline. Ces flux devraient être spécifiés avant E9/E10.

**Lacune UX la plus concrète** : pour un produit dont la valeur est l'adoption par des intégrateurs, **aucune story de livrable documentaire** (guide de migration DODLP 180 fichiers, référence d'API par package, exemples d'usage). L'Annexe B.1 ne couvre que l'hygiène de surface d'API, pas la production de doc. L'onboarding développeur conditionne SM-2 et SM-3.

## 7. Qualité des épics & stories

**12 unités d'épic (E1..E11, E11 scindé E11a/E11b), 56 stories.** Les 6 critères de checklist sont majoritairement satisfaits (valeur explicitée, brownfield DODLP/lex présent, setup melos en E1-1, AC largement testables avec cas d'erreur). Findings :

**Majeurs**
- **Numérotation ≠ ordre d'exécution** : E11a (label « 11 ») est un épic MVP exécuté **avant** E7/E9, si bien que E7 et E9 déclarent une dépendance vers un numéro **supérieur** (viole « Epic N ne requiert pas Epic N+1 »). Preuve : E7 l.119 « Dépend de : E3, E4, E5, E6, E11a » ; E9 l.134 idem. Risque : un planning ordonnant par numéro casse E7-4 (parité SM-2).
- **Aucun gate CI permanent d'isolation du cœur** (AD-1/B.4/SM-5, et pureté AD-14) : la vérification n'existe qu'en contrôle ponctuel à la création des squelettes (E1-2). E1-3 outille anti-reflectable + scan secrets + codegen mais **pas** de contrôle de frontière de dépendances/imports. Risque : ajout silencieux de cloud_firestore/syncfusion au cœur.
- **E2-9 empaquette 3 bindings** (zcrud_riverpod/get/provider) avec un AC combiné non complétable incrémentalement (anti-pattern « setup all »), alors que E7/E8 n'ont besoin chacun que d'un binding.

**Mineurs**
- Graphe mermaid omet l'arête E11a→E9 pourtant déclarée en dépendance d'E9.
- Aucun AC en Given/When/Then ; préconditions/oracle parfois implicites (ex. E3-1, formulaire de référence SM-1).
- Valeur d'intégrateur d'E1/E2 reléguée en note globale (l.163) plutôt que dans les « Objectif ».
- SM-5 partiellement couvert : E4-1 teste l'exclusion Syncfusion mais pas l'isolation complète de zcrud_markdown vis-à-vis de Firebase/Maps.
- Sur-dimensionnement : E3-3b (≈10 familles de champs + test a11y) et E7-3 (migration 180 imports « par lots » non énumérés → non estimable).

## 8. Lacunes transverses & questions ouvertes bloquantes

**OQ bloquant le MVP : aucune.** Contrairement à une prémisse répandue, seules **OQ-2 et OQ-5 sont ouvertes** (OQ-12 déférée, le reste résolu). OQ-5 (level cache vs dérivé) et OQ-12 (casse) n'affectent que v1.x/E10 ou le générateur E2-5. **OQ-2** (portée du/des registre(s)) touche la story MVP E2-3, mais est **déjà tranchée de facto** par AD-4/E2-3 en faveur de 3 registres — à acter formellement pour lever la contradiction PRD (ouvert) ↔ architecture (décidé).

**Lacunes transverses les plus sérieuses** (aucune bloquante à l'implémentation, mais à corriger) :
- **Offline-first MVP sans consommateur MVP** : E5-1/E5-3/E5-4 (LWW, ZSyncOrchestrator, adaptateur Firestore) n'ont aucun chemin d'acceptation — DODLP (E7) conserve ses repos Firebase inchangés (la dépendance E5→E7 contredit ce contrat), lex_douane_admin (E8) ne migre que des écrans. Le vrai premier consommateur est E9 (flashcards, v1.x). Livré sans example-app et sans aucune SM.
- **example-app sans story** : le répertoire `example/` du Structural Seed n'est créé/maintenu par aucune story, alors que c'est la seule surface exécutable pour valider parité multi-binding (E2-9), isolation SM-5 et offline-first.
- **ZListController fantôme** : nommé dans AD-6 **et** AD-15 mais absent du glossaire PRD et produit/testé par aucune story (E2-7/E2-9 ne couvrent que ZFormController).
- **Nommage** : DataRequest/DataState non préfixés Z (auto-violation de convention) ; double nom DataRequest/ZQuery. Dérives modèles Z* (ZStudySession vs ZStudySessionConfig/State/Result ; ZNode livré MVP mais consommateur v1.x ; ZNode/ZTreeNode/ZHierarchyNode non réconciliés).

## 9. Findings priorisés (regroupés par sévérité, dédoublonnés)

### Critique
1. **FR-2 partiel — champ fichier/image/document non implémenté** (agent Traçabilité). Type de premier plan du catalogue figé DODLP (AppFileEditionField 738 l. + FileFieldConfig, inventaire §3/§6, cœur zcrud_core), sans **aucune** story, sans port upload/CloudStorageRepository, retiré du Structural Seed. Menace directement **SM-2** (métrique primaire), qui exige « chaque type du catalogue figé à parité ». *Preuve* : E3-3a/E3-3b ne mentionnent aucun file/image/AppFile ; E7-4/SM-2 ne prévoient le repli ZTypeRegistry que pour géo/tél/pays.

### Majeurs
2. **FR-26 systématiquement sous-tracé** (agents 1,2,3,5 — dédoublonné). Présent PRD §4.9, couvert par E2-8, mais absent des `binds` architecture (FR-1..FR-25), de la Capability Map, d'un AD gouvernant, et sous-compté (« 25 FR »). Hors séquence (entre FR-23 et FR-24).
3. **Catalogue figé sans frontière exacte** (SM-2 non déterministe) : « ~37 » vs « 37-40 » vs types fallback icon/hidden/password. FR-2 + SM-2 doivent pointer vers une liste unique énumérée.
4. **Offline-first MVP sans consommateur ni harnais** (E5 vs E7 « repos Firebase inchangés » ; example-app absente ; aucune SM offline). Contradiction de l'arête E5→E7.
5. **ZListController asserté (AD-6/AD-15) mais non livré par le backlog.**
6. **Aucun livrable documentaire intégrateur** (guide migration DODLP, référence API, exemples) — UX réelle du produit-développeur.
7. **Numérotation des épics ≠ ordre d'exécution** (E11a avant E7/E9 → dépendance vers numéro supérieur).
8. **Aucun gate CI permanent d'isolation/pureté du cœur** (AD-1/AD-14/B.4/SM-5).
9. **E2-9 empaquette 3 bindings** en une story non incrémentale.
10. **FR-3 grille responsive sans conséquence testable** ; **FR-13 bornes non chiffrées** (offline/sync).

### Mineurs
11. Décompte FR 25 vs 26 dans épics et architecture (corollaire de #2).
12. FR-8 : corbeille et dégradation gracieuse export sans AC dédié.
13. Types hidden/password implicites (non explicités dans les AC — ferme la checklist SM-2).
14. OQ-2 marquée ouverte au PRD mais tranchée par AD-4/E2-3.
15. Nommage : DataRequest/ZQuery/DataState non préfixés Z ; dérives ZStudySession, ZNode/ZTreeNode/ZHierarchyNode.
16. Graphe mermaid omet E11a→E9.
17. Ambiguïté périmètre pagination curseur (MVP vs Deferred) ; tension E2-5 sentinelle vs Deferred (OQ-12).
18. Groundings périmés : brief exec summary (Riverpod/freezed) et inventaire §6 (flutter_riverpod dans zcrud_core, absence zcrud_list/bindings).
19. Couverture métrique partielle (14/26 FR sans SM) ; SM-5 faiblement ancrée ; aucune SM offline-first/perf-liste.
20. Sur-dimensionnement E3-3b et E7-3 (à décomposer au démarrage).
21. Incohérences PRD internes : OQ-7 « Résolu » vs hypothèse §9 « à confirmer » ; budget liste B.3 non chiffré ; NFR-C1 mêle invariant testable et action de remédiation externe ; collision OQ-9 PRD vs OQ-9 canonique.
22. 3 stories sans FR directe (E1-3, E1-5, E2-10) — légitimes, à documenter leur rattachement AD/SM.

## 10. Recommandations & prochaines étapes

Actions ordonnées (les 3 premières lèvent la majorité des risques bloquants) :

1. **Fermer FR-2 (critique)** : ajouter une story `ZFileField + FileFieldConfig + port ZCloudStorage` (impl Firebase Storage dans zcrud_firestore), OU acter formellement la parité-par-enregistrement du widget fichier DODLP via ZTypeRegistry dans E7-4 ; réintégrer « champ fichier générique » dans la description zcrud_core du Structural Seed.
2. **Passe de réconciliation traçabilité FR-26** : porter le décompte à **26 FR** partout (épics + `binds` architecture), ajouter FR-26 à la Capability Map, l'attacher à un AD gouvernant (élargir AD-6/AD-13 ou créer AD-17), et renuméroter ou documenter son ordre.
3. **Geler le catalogue figé** : liste unique énumérée (N précis) dans l'inventaire §3, statuer icon/hidden/password (in/hors parité), faire pointer FR-2 + SM-2 + E7-4 dessus.
4. **Décider du périmètre offline-first** : soit ne garder en MVP que les ports neutres (E2-2) et déplacer E5-1/E5-3/E5-4 en v1.x aligné sur E9 ; soit ajouter une story **example-app** exerçant l'offline-first + une SM dédiée. Dans tous les cas, corriger/retirer l'arête E5→E7.
5. **Créer la story example-app** (rattachée E1/E2) comme harnais de validation SM-1, SM-5, E2-9 (parité multi-binding) et offline-first.
6. **Ajouter une story documentation intégrateur** au MVP (guide migration DODLP pas-à-pas, quickstart par package, exemples annotation→schéma→liste).
7. **Renuméroter les épics** pour que numéro = ordre d'exécution (lot parité en ~E7, décaler DODLP/lex) ; ajouter l'arête E11a→E9 au graphe.
8. **Renforcer les gates CI dans E1-3** : boundary-check de dépendances/imports (dart_dependency_validator ou lint custom) interdisant Firebase/Syncfusion/Maps/managers dans zcrud_core, symétrique de l'anti-reflectable ; test de résolution SM-5 sur l'example-app.
9. **Scinder E2-9** en une story par binding + une story-gate de parité (prioriser zcrud_get pour E7, zcrud_riverpod pour E8).
10. **Rendre FR-3 et FR-13 testables** : ajouter une conséquence testable à la grille responsive ; chiffrer les bornes offline (profondeur cascade, fenêtre debounce ms, critère observable de « non bloquant »).
11. **Nettoyages** : acter OQ-2 résolue (AD-4/E2-3) ; fixer un nom canonique (ZDataRequest/ZDataState) ; clarifier pagination Deferred et sentinelle E2-5 ; ajouter AC dégradation export (E4-2) et types hidden/password ; corriger les groundings périmés (brief exec summary, inventaire §6) ; aligner OQ-7/§9 et séparer NFR-C1.

Une fois les actions 1 à 5 traitées, le dossier passe au seuil **READY** ; les actions 6 à 11 sont des resserrements de qualité réalisables en parallèle du début d'implémentation MVP.
