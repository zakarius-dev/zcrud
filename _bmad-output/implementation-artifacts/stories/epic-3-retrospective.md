# Rétrospective — Epic E3 : Moteur DynamicEdition à rebuilds granulaires

- **Date** : 2026-07-10
- **Projet** : zcrud
- **Skill** : `bmad-retrospective` (VRAI skill invoqué via le tool `Skill`, args `retro epic 3`). Chemin pris : **Skill tool** — workflow chargé depuis `.claude/skills/bmad-retrospective/SKILL.md`.
- **Couvre** : FR-1..FR-5 · AD-2 (objectif produit n°1) · SM-1. **Dépend de** : E2. **Phase** : MVP.
- **Format** : exécution non-interactive (subagent). Le dialogue party-mode est **synthétisé** à partir des artefacts réels (stories, code-reviews, sprint-status, architecture) — aucune vérification n'a été « jouée de mémoire ».

> ⚠️ **Réserve de complétude (rétro partielle assumée)** : le sprint-status marque `epic-3: in-progress` et **`e3-3c-champ-fichier-image-document: backlog`**. E3 est **9/10 stories `done`** ; `e3-3c` (champ fichier/image/document, port `CloudStorageRepository`) reste à planifier — voir action item **AI-E3-4**. La rétro porte sur les 9 stories livrées ; la clôture formelle de l'epic reste conditionnée à `e3-3c` (ou à sa descoping explicite vers un slot ultérieur dépendant d'E5).

---

## 1. Résumé de livraison

| Métrique | Valeur |
|---|---|
| Stories `done` | **9** (e3-1, e3-2, e3-3a, e3-3b-1, e3-3b-2, e3-3b-3, e3-4, e3-5, e3-6) |
| Story en attente | **e3-3c** (`backlog`) — champ fichier, dépend du port `CloudStorageRepository` (impl E5) |
| Décomposition notable | **e3-3b (XL) splittée** en 3 sous-stories (-1 registre+feuilles, -2 sous-listes mini-CRUD, -3 signature+widget libre) — directive CLAUDE.md « décomposer les stories XL » |
| Verdicts code-review | 8× **APPROVED** · 1× **CHANGES REQUESTED** (e3-4, corrigé puis approuvé) |
| Findings bloquants | **1 MAJEUR** (e3-4) — **corrigé** · **1 MEDIUM** grille groupée (e3-4) — **corrigé** |
| Findings MEDIUM justifiés-déférés | e3-5 MEDIUM-1 (révélation non-texte → **résolu en e3-6**) · e3-6 MEDIUM-1 (dates inter-champs → **déféré E7/E8**) · e3-2 MEDIUM-1 (couverture compilateur validateurs) |
| Objectif produit n°1 (SM-1) | ✅ **ATTEINT à tous les niveaux** (voir §2) |
| Gates CI | Anti-`reflectable`, scan secrets, codegen, rétro-compat sérialisation, pureté présentation/RTL : **verts** à chaque `done` |
| Vérif verte finale (e3-6) | analyze RC=0 · flutter test RC=0 · verify RC=0 · graphe CORE OUT=0 · 14 pkgs · 0 `.g.dart` committé |

---

## 2. Objectif produit n°1 — SM-1 prouvé à **tous** les niveaux

Le bug historique (rebuild global du formulaire à chaque frappe → jank, perte de focus) est **corrigé par conception** et prouvé par des tests widget instrumentés, pas seulement par le « vert » :

- **Plat** (e3-1/e3-2) : 100 caractères ⇒ seul le champ courant rebuild, `initState==1`, focus/curseur préservés, `TextEditingController` jamais recréé ni ré-injecté.
- **À travers le dispatcher** (e3-3a/e3-3b) : `_dispatchRegistry` appelé **sous** `ZFieldListenableBuilder.builder` — frontière AD-2 inchangée ; `find.byType(Form) → findsNothing` sur tout le catalogue.
- **Imbriqué** (e3-3b-2) : SM-1 dans les sous-listes mini-CRUD (subItems/dynamicItem), frappe dans un sous-item ne reconstruit pas le formulaire parent.
- **Stepper** (e3-5) : les étapes sectionnent le **même** `ZFormController` (aucun `FormBuilder` global), état préservé entre étapes, zéro rebuild global re-vérifié.
- **Composite** (e3-4) : 37 champs / 3 sections + conditionnel + repliable + grille 12-col, 100 frappes ⇒ 0 build structurel.

Un seul `ZFormController`, aucun `Form` global, zéro perte de focus/curseur. **UJ-2** (rebuild d'ancêtre, ex. perte de connexion) prouvé : l'état du controller n'est pas reconstruit grâce à la place stable (`ValueKey`).

---

## 3. Discussion d'équipe (synthèse party-mode)

Amelia (Developer) : « E3 est le cœur de la promesse produit. Ce qui m'a frappée : SM-1 tient non seulement à plat, mais **à travers le dispatcher, en imbriqué, en stepper et en composite**. On n'a jamais élargi la frontière de rebuild — chaque feuille reste sous son `ValueListenableBuilder`. »

Charlie (Senior Dev) : « Et le seam registre est propre : `ZWidgetRegistry` **instanciable et agnostique**, distinct du `ZTypeRegistry` des codecs, injecté par `ZcrudScope`, résolu **dans la slice**. On sert un type externe (`markdown`, géo/tél) sans que `zcrud_core` importe E6/E11a — prouvé par un widget de démo défini dans le test. »

Alice (Product Owner) : « La décomposition d'e3-3b en trois a payé. Une story XL "familles avancées + sous-listes + signature + widget libre" aurait noyé la revue. En trois slices, chaque frontière AD-2 a été isolée et re-prouvée. »

Dana (QA Engineer) : « Le point le plus instructif, c'est e3-4. Le "vert" passait — mais le code-review adversarial a trouvé **MAJEUR-1** : dans le chemin **grille + conditionnel**, un `ValueKey` enfoui sous un `SizedBox` non keyé faisait réconcilier le `Wrap` **par position** → perte de focus quand un conditionnel s'insère **avant** le champ focalisé. Le test composite ne l'exerçait pas (le conditionnel s'insérait en fin de section). Sans la revue, ça partait en prod. »

Charlie (Senior Dev) : « Même classe de défaut sur **MEDIUM-1** : les blocs du chemin groupé étaient montés non keyés et sans `findChildIndexCallback` — un décalage de composition (section qui se vide, bloc "loose" qui bascule) réutilisait un `Column` par position. Les deux corrigés dans la même passe. »

Amelia (Developer) : « Leçon nette : **le "vert" prouve ce qu'on a pensé à tester ; le code-review adversarial capte l'invariant subtil qu'on n'a pas pensé à exercer.** C'est exactement la continuité de la leçon E2 (H1/AD-10). »

{user_name} (Project Lead) : [participation — voir décisions et inflexions §4]

---

## 4. Ce qui a bien marché

1. **SM-1 tenu à tous les niveaux** (plat / dispatcher / imbriqué / stepper / composite) — objectif produit n°1 atteint, instrumenté par des tests qui **détecteraient** un rebuild global ou de voisin.
2. **Cœur agnostique manager préservé** : aucun gestionnaire d'état dans `zcrud_core` ; le pont `AsyncValue.error` (états de soumission AD-11) vit au binding, pas dans le cœur.
3. **Décomposition d'une story XL** (e3-3b → -1/-2/-3) : chaque slice a une frontière de rebuild isolée, une revue ciblée, une vérif verte propre.
4. **Seam d'extensibilité propre** : `ZWidgetRegistry` distinct du `ZTypeRegistry`, instanciable, injecté par `ZcrudScope`, résolu dans la slice (AD-1/AD-4) ; type externe servi sans dépendance du cœur.
5. **Exhaustivité 0-default** maintenue sur toutes les familles (partition 39) — aucun type ne tombe dans un `default`.
6. **A11y/RTL par-widget** systématiques : `style_purity_test`/`presentation_purity_test` verts (0 `EdgeInsets.only(left/right)`, 0 `TextAlign.left/right`, 0 couleur codée en dur), `androidTapTargetGuideline` + `textContrastGuideline` sur le catalogue de référence.
7. **Le code-review adversarial a systématiquement capté ce que le "vert" ratait** (MAJEUR-1 + MEDIUM-1 e3-4) — filet confirmé pour la 2e fois (après H1/AD-10 en E2).
8. **Reports résolus dans l'epic** : write-back de valeur externe (reseed hors focus, `reseedRevision`), inter-champs `match`/`refKey`, révélation d'erreur non-texte (surface additive `Semantics(liveRegion)+Text`, source unique `ZCrossFieldValidator.compileField`).

## 5. Ce qui a coincé

1. **MAJEUR-1 e3-4 (CHANGES REQUESTED)** : `ValueKey` enfouie sous `SizedBox` non keyé dans le chemin grille → réconciliation `Wrap` par position → perte de focus sur insertion conditionnelle **avant** la cible. Le test composite ne l'exerçait pas. **Corrigé** (place stable jusqu'à la feuille + garde), + **MEDIUM-1** (blocs groupés non keyés / sans `findChildIndexCallback`) corrigé dans la même passe.
2. **Trous de couverture répétés** captés en MEDIUM/LOW : compilateur de validateurs public non testé sur ~17 familles (e3-2 MEDIUM-1) ; blocage `required` sur familles non-texte non exercé (e3-5) ; agrégation stepper toutes-étapes (e3-6 LOW-1) ; cas 2-niveaux imbriqués (e3-3b-2 LOW-4). Pattern : les invariants **comportementaux** sont testés, mais la **surface publique complète** (mappings, familles non-texte) reste sous-couverte.
3. **Inter-champs sur dates** (e3-6 MEDIUM-1) : `minKey`/`maxKey` comparent en `num.tryParse` uniquement — l'exemple normatif AC11 sur les DATES n'est pas honoré. **Déféré E7/E8** (ambiguïté #5 documentée) ; contradiction texte AC11 ↔ résolution à réconcilier.
4. **Relâchement ciblé de la garde de pureté** : `TextInputFormatter`/`FilteringTextInputFormatter` nécessitent `package:flutter/services.dart` (banni). Décision prise en e3-3b-1 : **allowlist par symbole** (`{TextInputFormatter, FilteringTextInputFormatter, TextInputType}`), garde bidirectionnelle prouvée (import nu et symbole hors-allowlist rejetés) — **jamais** `services.dart` en bloc.
5. **e3-3c non livrée** (`backlog`) : le champ fichier/image/document dépend du port `CloudStorageRepository` dont l'impl concrète arrive en E5 — trou de parité DODLP à combler.

## 6. Leçons clés

1. **Le code-review adversarial est le filet qui capte les invariants subtils de rebuild que le "vert" rate.** MAJEUR-1 (grille + conditionnel) était invisible au test composite (insertion en fin de section). La discipline « corriger MAJEUR obligatoire, MEDIUM par défaut, report justifié par écrit » a de nouveau fonctionné.
2. **Décomposer une story XL restaure l'auditabilité.** e3-3b en trois slices a permis d'isoler et re-prouver chaque frontière AD-2 séparément, là où un bloc monolithique aurait dilué la revue.
3. **La place stable doit aller jusqu'à la feuille.** Un `ValueKey` correct mais **enfoui sous un wrapper non keyé** (SizedBox/Wrap) casse la réconciliation par position — la garde `KeyedSubtree`/`findChildIndexCallback` doit couvrir **tous** les chemins (plat, grille, groupé), pas seulement le chemin par défaut.
4. **Un seam d'extension bien nommé évite la confusion.** `ZWidgetRegistry` (widgets) vs `ZTypeRegistry` (codecs) : deux responsabilités, deux registres — la conflation aurait fuité des dépendances lourdes dans le cœur.
5. **Relâcher une garde CI doit se faire par allowlist chirurgicale**, jamais en bloc, avec preuve bidirectionnelle (ce qui est autorisé passe, ce qui ne l'est pas est rejeté).
6. **Couvrir les invariants ≠ couvrir la surface publique.** Le prochain réflexe : tester le mapping complet des familles et les familles non-texte, pas seulement le chemin comportemental heureux.

---

## 7. Suivi des action items E2 (continuité)

| # (E2) | Action | Rattachement | Statut au sortir d'E3 |
|---|---|---|---|
| AI-3 | Compteur sur un consommateur de seam `ZcrudScope.of(context)` pour certifier la stabilité du resolver | E3 (moteur) | ✅ **Adressé** — e3-3b-1 prouve que `ZcrudScope.maybeOf(context)` établit sa dépendance dans le slice : un changement de scope rebuild **le slice**, jamais le formulaire. Harnais de parité complet reste à consolider en E7. |
| AI-4 | Example-app / formulaire de référence (banc SM-1 + vitrine) | E3–E7 | ⏳ **En cours / reporté** — SM-1 prouvé par tests widget instrumentés, mais l'**example-app dédiée n'existe toujours pas** (readiness #5). Re-porté E7. |
| AI-1 | Décodage défensif au niveau registre/adaptateur (`decodeSafe`) | E5 | ❌ Non adressé (hors périmètre E3) — reste ouvert pour E5. |
| AI-2 | `ZcrudGetScope` locator partagé / double-scope en conditions réelles | E7-1 | ❌ Non adressé (hors périmètre E3) — reste ouvert pour E7-1. |
| AI-5 | E1-5 groupe B (révocation clé Google Maps) — attestation Owner | E1 (clôture) | ❌ Toujours ouvert — `e1-5` reste `ready-for-dev`, E1 non clôturé. |
| AI-6 | Spike `zcrud_kernel` pur-Dart (dette d'inflexion Flutter/Material) | Backlog / pré-E5 | ❌ Non adressé — reste au backlog. |

---

## 8. Action items E3

| # | Action | Catégorie | Rattachement | Owner | Statut |
|---|---|---|---|---|---|
| **AI-E3-1** | **Réconcilier AC11 inter-champs sur les DATES** (e3-6 MEDIUM-1) : soit scoper explicitement le texte d'AC11 hors E3-6, soit ajouter une branche `DateTime.tryParse` dans `_compileOne` (min/max refKey). Lever la contradiction AC11 ↔ ambiguïté #5. | Correctness / dette tracée | **E7/E8** | Dev | open |
| **AI-E3-2** | **Combler la couverture de surface publique** : mapping complet du compilateur de validateurs (~17 familles, e3-2 MEDIUM-1) + blocage `required` sur familles **non-texte** (e3-5 LOW-3) + agrégation stepper toutes-étapes (e3-6 LOW-1). | Qualité / test-coverage | **E3 (dette) → E7** | Dev | open |
| **AI-E3-3** | **Couvrir le cas sous-listes 2 niveaux** (e3-3b-2 LOW-4) — surface AD-2 la plus à risque en imbriqué — + valeurs défensives feuilles avancées (readOnly, color hors-gamme, rating hors-borne). | Qualité / test-coverage | **E3 (dette) / E4-5** | Dev | open |
| **AI-E3-4** | **Livrer e3-3c (champ fichier/image/document)** : `AppFile` + `FileFieldConfig` + `ZAppFileField` derrière le port `CloudStorageRepository` (impl Firebase Storage en E5). Bloque la parité DODLP (SM-2). Ordonnancer après/avec E5 ou descoper explicitement. | Fonctionnel / parité | **E5 → E7** | Dev | open |
| **AI-E3-5** | **`controller.values` sérialise les champs masqués par condition** (e3-6 LOW-3 informational) : décider si les champs masqués doivent être exclus de la soumission (impact create/update réel). | Design / correctness | **E7** | Dev | open |
| **AI-E3-6** | **Durcir la garde de pureté** `presentation_purity_test` L-7 (reconstruire l'instruction d'import avant extraction d'URI, e3-3b-1) — risque négligeable, durcissement optionnel. | Gates CI (nit) | **Backlog** | Dev | open |

**Reports résolus dans E3 (fermés, pour mémoire)** : write-back valeur externe (reseed hors focus) · inter-champs `match`/`refKey` · révélation d'erreur non-texte (report a absorbé en e3-6) · MAJEUR-1 + MEDIUM-1 grille/groupé e3-4.

---

## 9. Préparation de la suite (graphe : E3 → E4 ∥ E5 ∥ E6 ∥ E11a → E7 → E8)

- **Aucune découverte significative** invalidant le plan aval. Le moteur d'édition expose les seams attendus (`ZFormController`, `ZFieldSpec`, `ZWidgetRegistry`, `ZcrudScope`, thème/l10n).
- **Dépendance E5 ↔ e3-3c** : le champ fichier attend `CloudStorageRepository` (impl Firebase Storage en E5). À séquencer explicitement (AI-E3-4).
- **Points de vigilance à porter en aval** :
  - E7/E8 : réconcilier AC11 dates (AI-E3-1) et décider du sort des champs masqués à la soumission (AI-E3-5) sur des formulaires riches réels.
  - E7 : matérialiser enfin l'**example-app** banc SM-1 (AI-4 E2 + parité DODLP).
  - E4 : garder en tête la limite « ValueKey + position viewport » (recyclage `ListView.builder`) lors des vrais réordonnancements de liste.

---

## 10. Verdict

| Dimension | État |
|---|---|
| Objectif produit n°1 (SM-1) | ✅ Atteint à tous les niveaux, prouvé par tests instrumentés |
| Invariants AD-2 / AD-13 / AD-11 | ✅ Respectés (cœur agnostique, RTL/a11y, états via `AsyncValue.error` au binding) |
| Findings bloquants restants | **0** (MAJEUR-1 + MEDIUM-1 e3-4 corrigés ; MEDIUM dates justifié-déféré E7/E8) |
| Gates CI | ✅ Verts (anti-`reflectable`, secrets, codegen, rétro-compat, pureté) |
| Complétude epic | ⚠️ **9/10 stories `done`** — `e3-3c` reste `backlog` (→ AI-E3-4, dépend E5) |
| Découvertes significatives | Aucune — plan aval intact |

**Conclusion** : E3 livre le cœur de la promesse produit avec un niveau de preuve élevé sur SM-1. La clôture formelle de l'epic reste conditionnée à `e3-3c` (ou à sa descoping documentée vers un slot dépendant d'E5). Aucun des action items ouverts n'est bloquant pour démarrer E4/E5/E6/E11a en parallèle.

---

## Mise à jour de complétude (post-rétro, orchestrateur) — E3 COMPLET 10/10

`e3-3c` (champ fichier/image/document, `ZAppFileField`) avait été **sauté par erreur** dans le séquencement ; la rétro l'a **correctement détecté** (réserve de complétude ci-dessus). Il a ensuite été livré via le cycle BMAD strict complet :
- **create-story → dev-story → vérif verte → code-review → remédiation (M1) → done**.
- Conception AD-1-safe : `AppFile` (référence sans bytes), port neutre `CloudStorageRepository`, seam `ZFilePicker` injecté via `ZcrudScope` — **`zcrud_core` reste sans dep lourde** (0 `image_picker`/`file_picker`/`firebase`, 0 `dart:io`, CORE OUT=0). Famille `file` (file/image/document), value-in-slice, SM-1 préservé, a11y/RTL.
- Code-review : APPROVED (1 MEDIUM M1 = refus `maxFiles` accessible **corrigé** ; course `liveValue` jugée SOUND ; L1 corrigé ; L2/L4 → E5). **429 tests core, tout vert.**

**→ AI-E3-4 (livrer e3-3c) : RÉSOLU.** E3 est désormais **10/10 stories `done`** ; la clôture formelle de l'epic n'est plus conditionnée. Les autres action items (AI-E3-1 dates inter-champs, AI-E3-2/3 couverture, AI-E3-5 champs masqués, AI-E3-6 garde pureté, + reports E2 ouverts) restent trackés vers E5/E7/backlog, non bloquants.

*Note : cette section est une finalisation ciblée par l'orchestrateur (l'epic étant complété après le run de rétro) — le corps analytique ci-dessus reste le produit du skill `bmad-retrospective`.*

---

*Note process : conformément au mandat du subagent, ce document ne modifie ni `sprint-status.yaml`, ni le code, et ne committe rien. La transition `epic-3-retrospective → done` et l'append des action items au `sprint-status.yaml` restent à appliquer par l'orchestrateur (édition ciblée, sérialisée).*
