# Rétrospective d'epic — E-DP : Parité migration DODLP

- **Date** : 2026-07-11
- **Epic** : E-DP — Parité du moteur d'édition DODLP → zcrud (14 gaps BLOQUANTS B1→B14)
- **Skill** : `bmad-retrospective` (VRAI skill invoqué via le tool `Skill` ; workflow résolu par `resolve_customization.py` → OK, aucun override team/user)
- **Mode** : rétrospective factuelle non-interactive (sous-agent orchestré ; format party-mode allégé, contenu ancré sur la lecture réelle des stories, code-reviews et sprint-status sur disque)
- **Source de vérité** : `docs/dodlp-edition-parity-gap.md` · `_bmad-output/implementation-artifacts/sprint-status.yaml` (section `epic-dp`)
- **Stories** : DP-1 … DP-11 — **toutes `done`** (11 stories couvrant 14 bloquants B1→B14 + M2)

---

## 1. Résumé de livraison (métriques réelles)

| Story | Gaps couverts | Verdict code-review | Findings | Statut |
|---|---|---|---|---|
| DP-1 | B1 FieldSize + B2 minLines/maxLines + M2 thème/décoration | APPROVED (après corr.) | 2 MEDIUM **corrigés** (crash min>max, double libellé a11y), 2 LOW consignés | done |
| DP-2 | B3 displayCondition étendu (`ZCondition`) | APPROVED (après corr.) | **1 MEDIUM-1 corrigé** (recalcul `persisted` sur `reseed`), 3 LOW consignés | done |
| DP-3 | B4 richtext readonly + B6 inline/plein-écran | APPROVED | 0 H/MAJ/MED, 4 LOW consignés | done |
| DP-4 | B5 champ HTML + `ZHtmlCodec` | APPROVED | 0 H/MAJ/MED, 3 LOW | done |
| DP-5 | B7 relation dynamique `crudDataSelect` | APPROVED | 0 H/MAJ/MED, 4 LOW | done |
| DP-6 | B8 subItems compact + dialog | APPROVED | 0 H/MAJ/MED, 2 LOW | done |
| DP-7 | B9 geo editor toolbar | APPROVED (après corr.) | **1 MEDIUM-1 corrigé** (défauts `ZGeoMapOptions` alignés DODLP), 2 LOW | done |
| DP-8 | B10 adresse String/Places | APPROVED | 1 MEDIUM-1 **justifié + follow-up core tracké**, 1 LOW corrigé, 3 LOW consignés | done |
| DP-9 | B11 StepperConfig + steppers imbriqués | APPROVED | 0 H/MAJ/MED, 4 LOW | done |
| DP-10 | B12 bornes dates + B13 datetime | APPROVED | 0 H/MAJ/MED, 3 LOW | done |
| DP-11 | B14 timestamp persistance hint | APPROVED (après corr.) | **1 MAJEUR-1 corrigé** (hint appliqué aussi sur `_mergedMap` sync), 1 LOW consigné | done |

**Bilan qualité** : 0 finding HIGH/critique ouvert sur toute l'epic. 1 MAJEUR (DP-11) corrigé. 4 MEDIUM au total (DP-1 ×2, DP-2 ×1, DP-7 ×1) **corrigés dans le périmètre** ; 1 MEDIUM (DP-8) **justifié par écrit** (non corrigible sans toucher `zcrud_core`) avec follow-up. Invariants AD tenus à chaque story : **CORE OUT=0**, graphe **ACYCLIQUE**, pureté domaine, **SM-1/AD-2** non régressés, AD-13 (directionnel/a11y), AD-10 (désérialisation défensive).

---

## 2. Ce qui a bien marché

**Amelia (Developer)** : « On a livré les 14 bloquants sans laisser un seul HIGH ouvert, et avec les invariants d'architecture verts à chaque gate. Regardons pourquoi ça a tenu. »

- **Parallélisation par vague de `create-story`** — les stories à packages disjoints (markdown : DP-3/DP-4 ; geo/intl : DP-7/DP-8 ; firestore : DP-11) ont pu être préparées en vague sans collision, ce qui a compressé le cycle sans jamais faire écrire le sprint-status par deux agents.
- **Sérialisation stricte du verrou `zcrud_core`** — la règle « une seule story touche le cœur à la fois » a été appliquée pour DP-1 (fondation FieldSize/décoration), DP-2 (`ZCondition`), DP-5/6/9/10. DP-1 a servi de fondation débloquant les stories cœur suivantes. Aucune régression cross-package cœur détectée.
- **Additivité stricte** — chaque gap a été comblé par extension (nouveaux champs de config lus, nouveaux `ZCodec`/registries instanciables, flags optionnels) sans casser la rétro-compat E5/E6/E11a/E11b. Preuve rejouée : rétro-compat de sérialisation verte, `CORE OUT=0` maintenu, SM-1 préservé (tests « frappe → 0 build voisin » sur DP-2/DP-3/DP-6).
- **Discipline de confinement des SDK lourds** — Quill (DP-3/DP-4), Google Maps (DP-7), Places (DP-8), Firestore `Timestamp` (DP-11) sont restés hors `zcrud_core` ; AD-5 confiné et prouvé côté générateur/`zcrud_firestore` pour B14.
- **Code-review adversariale efficace** — a réellement attrapé des chemins de crash (DP-1 min>max) et une incohérence de format sur disque offline-first (DP-11 `_mergedMap`) qui auraient défait le but interop de B14. Ces findings n'étaient pas cosmétiques.

## 3. Frictions

**Charlie (Senior Dev)** : « Le point qui a coûté, c'est le cœur en accès exclusif. »

- **Le fichier cœur entièrement sérialisé = goulot de débit.** Toutes les stories cœur (DP-1, DP-2, DP-5, DP-6, DP-9, DP-10) ont dû s'aligner en file derrière `zcrud_core`. La parallélisation n'a bénéficié qu'aux satellites (markdown/geo/intl/firestore). Le débit de l'epic a été plafonné par ce chemin critique unique.
- **Point de contact partagé `dynamic_edition.dart` non anticipé en DP-9.** DP-9 (steppers imbriqués) a dû toucher `dynamic_edition.dart` pour introduire `manageVisibility:false` (invariant single-writer racine de `visibleFields`) — un fichier cœur déjà réputé « propriété » du chemin DP-2. Le contact n'était pas prévu au découpage : la composition des vagues n'a pas détecté ce partage en amont.
- **DP-2 MEDIUM-1 (recalcul `persisted` sur `reseed`).** Les Dev Notes affirmaient à tort « baseline immuable dans une session » ; `reseed()`/`markPristine()` mutent en fait la baseline sans ré-évaluer les conditions `source: persisted`. Corrigé (abonnement conditionnel à `reseedRevision`), mais révèle un angle mort de raisonnement sur le cycle de vie du controller au moment du design de `ZCondition`.

## 4. Dette et reports explicites

**Alice (Product Owner)** : « On a fermé les bloquants. Soyons honnêtes sur ce qu'on a sciemment laissé derrière. »

- **~24 gaps MAJEURS (M1…M20) NON traités** — reportés au lot **DP-12+** (déjà acté en commentaire du sprint-status : « lot des ~24 majeurs, planifié après les bloquants »). Régressions fonctionnelles/visuelles à contournement coûteux, hors périmètre parité-bloquante.
- **Bindings/impls concrètes déférés** (le cœur expose les points d'extension, l'app fournit l'implémentation) :
  - DP-5 : impl concrète `ZRelationSource` (stream/repository Firestore réel, filtre cross-champ) — seul le registre instanciable + le contrat sont livrés ; câblage « E4 » à confirmer. **CRUD inline** et **`s2ChoiceDisabled`** non implémentés.
  - DP-8 : `ZPlaceSearchProvider` réseau réel non fourni (LOW-2 debounce + `sessionToken`, LOW-3 course async des réponses) ; enum core **`addressSearchField`** absent → mapping app-side `addressSearchField → address` (MEDIUM-1 justifié, follow-up cœur tracké).
- **LOWs consignés notables** :
  - **DP-5 LOW-4** — double libellé en `fieldSize: large` (interaction avec DP-1), en écho au **DP-1 MEDIUM-2 résiduel / LOW-1/LOW-2** (`bare` non honoré radio/checkbox en `large`, fallback libellé sur `field.name`). → lot **M2-résiduel** d'harmonisation du décor des familles restantes.
  - **DP-2 `markPristine`** — recalcul de visibilité post-`markPristine` (après soumission) reporté à **E7**.
  - **DP-3 LOW-2** — chaînes UI en dur (FR) hors l10n → **dette l10n** cohérente avec la parité E6.
  - **DP-11 LOW-1** — `persistAs: timestamp` sur champ non-date silencieusement toléré → warning de génération reportable côté générateur.
  - Tests SM-1 « vedette » via harnais bespoke plutôt que dispatch `DynamicEdition` réel (DP-3 LOW-1) et sans compteur de rebuild voisin (DP-10 LOW-3, DP-5 LOW-3).

## 5. Action items — AI-DP-*

| # | Action | Priorité | Owner proposé | Critère de complétion |
|---|---|---|---|---|
| **AI-DP-1** | Planifier et lancer le lot **DP-12+** couvrant les ~24 MAJEURS (M1…M20) via `bmad-create-story` ; les séquencer par package pour respecter le verrou cœur | **Haute** | Orchestrateur / PO | Stories DP-12+ créées dans le sprint-status avec dépendances tracées |
| **AI-DP-2** | **Cartographier les points de contact `zcrud_core` (notamment `dynamic_edition.dart`) AVANT chaque vague parallèle** ; toute story touchant un fichier cœur partagé est re-séquencée en exclusif (leçon DP-9) | **Haute** | Orchestrateur | Checklist « fichiers cœur partagés » appliquée au découpage de la prochaine vague |
| **AI-DP-3** | Câbler le recalcul de visibilité `persisted` sur **`markPristine`** (après soumission) — actuellement reporté E7 | **Moyenne** | Dev (E7) | Test : `markPristine` → conditions `persisted` ré-évaluées ; SM-1 intact |
| **AI-DP-4** | Fournir une **impl concrète `ZRelationSource`** (stream Firestore + filtre cross-champ) dans `zcrud_firestore`/binding, + CRUD inline + `s2ChoiceDisabled` | **Moyenne** | Dev (E4/E7) | `ZRelationSource` réel enregistré et testé de bout en bout sur un cas DODLP |
| **AI-DP-5** | Ajouter l'enum core **`addressSearchField`** (ou acter définitivement le mapping `→ address`) pour lever le MEDIUM-1 DP-8 ; fournir un `ZPlaceSearchProvider` réseau avec **debounce + `sessionToken` + garde anti-course** | **Moyenne** | Dev core + binding | Dispatcher atteint le widget adresse-recherche par le chemin réel ; provider réseau debouncé testé |
| **AI-DP-6** | Traiter le lot **M2-résiduel** : double libellé `fieldSize: large` (DP-1 MED-2 résiduel + DP-5 LOW-4), `bare` radio/checkbox en `large` (DP-1 LOW-1), fallback libellé (DP-1 LOW-2) | **Moyenne** | Dev core | Un seul libellé annoncé en `large` toutes familles ; `bare` honoré ; test a11y `bySemanticsLabel` findsOne |
| **AI-DP-7** | Ouvrir le lot **l10n** : externaliser les chaînes UI FR en dur (DP-3 LOW-2, et scan des autres stories) | **Basse** | Dev core / tech-writer | Chaînes rich-text/édition passées par le mécanisme l10n de `zcrud_core` |
| **AI-DP-8** | Émettre un **warning de génération** quand `persistAs: timestamp` cible un champ non-date (DP-11 LOW-1) | **Basse** | Dev generator | Build-time warning + test générateur |
| **AI-DP-9** | Renforcer les **tests SM-1** : router par le dispatch `DynamicEdition` réel (DP-3 LOW-1) et ajouter un compteur de rebuild du champ voisin (DP-5 LOW-3, DP-10 LOW-3) | **Basse** | Dev / QA | Test SM-1 « 100 caractères → 0 build voisin » via le vrai registre sur ≥1 famille rich/relation/date |

---

## 6. Prochaines étapes

1. L'orchestrateur applique la transition sprint-status `epic-dp-retrospective: optional → done` (hors périmètre de cette rétro — géré par l'orchestrateur, non committé ici).
2. **AI-DP-1** amorce le lot DP-12+ (majeurs) en respectant le séquencement du verrou cœur (AI-DP-2).
3. Le lot **E7 (intégration DODLP)** reste le débouché de la dette différée (AI-DP-3, AI-DP-4, AI-DP-5) : les points d'extension sont livrés, l'intégration réelle valide les contrats.

**Amelia (Developer)** : « E-DP a rempli son mandat : parité structurelle des 14 bloquants, zéro HIGH ouvert, invariants AD tenus. La dette majeure est cadrée, pas dispersée. On enchaîne proprement sur DP-12+ puis E7. »
