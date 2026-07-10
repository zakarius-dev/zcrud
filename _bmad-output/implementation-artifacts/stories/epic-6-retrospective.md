# Rétrospective — Epic E6 : Markdown & rich text (`zcrud_markdown`)

**Date :** 2026-07-10
**Facilitatrice :** Amelia (Developer)
**Statut epic :** 4/4 stories `done` — e6-1, e6-2, e6-3, e6-4
**Stories couvertes :** ZMarkdownField Quill isolé · ZCodec pluggable Delta/Markdown · embed LaTeX · embed tableau

---

## 1. Livré

Éditeur rich-text **Quill isolé** (`ZMarkdownField`, controller à durée de vie stable, conforme AD-2/AD-7) + **`ZCodec` pluggable** (Delta neutre ⇆ Markdown via `markdown_quill`, `ZDeltaCodec` par défaut = identité défensive) + deux **embeds opaques** (LaTeX via `flutter_math_fork`, tableau via `Table` natif Flutter).

**Métriques réelles (rejouées sur disque) :**

| Métrique | Valeur |
|---|---|
| Tests `zcrud_markdown` | **155** (RC=0) |
| `flutter analyze` | **RC=0, 0 issue** |
| Isolation cœur (`graph_proof.py`) | **CORE OUT=0**, acyclique |
| `melos list` | **14** packages |
| Dépendances ajoutées pour l'embed tableau | **0** (`Table` natif) |

Isolation prouvée par gates de graphe : `flutter_quill` / `markdown_quill` / `flutter_math_fork` **absents** de la fermeture transitive de `zcrud_core`, **présents** dans `zcrud_markdown` (contrôle positif anti-faux-vert).

---

## 2. Ce qui a bien marché

- **(a) SM-1 préservé de bout en bout (objectif produit n°1).** Controller Quill créé une fois / disposé, `embedBuilders` et `_toolbarConfig` **const stables** (référence figée, assertion `identical`), codec **hors du chemin chaud** de frappe (`_onQuillChanged` n'appelle jamais le codec). Le harnais 100-frappes d'E6-1 a été rejoué à chaque story (E6-3, E6-4) avec embeds actifs : rebuild du seul champ courant, zéro recréation du controller, zéro perte de focus/curseur.
- **(b) Contrat « tranche = Delta neutre » invariant.** La tranche du `ZFormController` reste toujours le Delta JSON neutre pendant l'édition ; le codec ne transforme qu'au seed (`decode`) et à la persistance (`encode`). Résultat : rétrocompatibilité + curseur/focus jamais perdus, et parité E6-1 stricte pour `ZDeltaCodec`.
- **(c) Embeds opaques additifs (AD-4).** LaTeX (E6-3) et tableau (E6-4) traversent le round-trip via le **placeholder générique `[embed:<type>]`** introduit en E6-2 — **sans jamais modifier le codec**. Extensibilité additive prouvée : deux types d'embed ajoutés, zéro touche au cœur de conversion.
- **(d) Isolation dépendances lourdes confinée** à `zcrud_markdown`, revérifiée à chaque story (CORE OUT=0 intact).

---

## 3. Incidents & leçons

- **(a) e6-1 — MED-1 (MEDIUM, efficacité).** Le listener branché sur `_quill.addListener` sérialisait tout le document à chaque **déplacement de curseur** (encodage O(taille doc) sur simple mouvement de caret). **Correction :** écouter `_quill.document.changes` (mutations de contenu seulement), abonnement annulé au `dispose` **et ré-abonné** après remplacement de document. **Leçon :** écouter le flux de *contenu*, jamais le controller entier ; le chemin chaud ne doit contenir aucun travail proportionnel à la taille du document.
- **(b) e6-2 — HIGH-1 (MAJEUR, perte de données).** Un embed au milieu du texte faisait *throw* `DeltaToMarkdown` → **document entier vidé** (perte totale silencieuse, faussement « bornée »). **Correction :** remplacer chaque embed opaque par un placeholder textuel **avant** conversion → texte environnant préservé, seul l'embed dégrade. **Leçon :** une conversion lossy doit **dégrader par-op, jamais laisser un throw effacer tout** ; tester systématiquement le contenu mixte texte+embed.
- **(c) e6-2 — MEDIUM-1.** La voie de persistance de prod passait par un membre `@visibleForTesting` (`debugPersistedValue` → `invalid_use_of_visible_for_testing_member` côté app) et le type de tranche était incohérent (`String` seed vs `List<Map>` après frappe). **Correction :** API publique `persistedValueOf` + normalisation de la tranche en Delta neutre dès `initState`. **Leçon :** exposer une **vraie API de persistance non-debug** et normaliser la tranche dès le montage.
- **(d) e6-3 — F1 (MEDIUM).** Le rendu readOnly de l'embed LaTeX était « prouvé » par proxy (présence du builder câblé). **Correction :** monter un `QuillEditor(readOnly: true)` réel et asserter `find.byType(Math) findsWidgets`. **Leçon :** tester le **rendu réel**, pas la simple présence du builder.

---

## 4. Action items

| ID | Libellé | Owner |
|---|---|---|
| **AI-E6-1** | Réutiliser le pattern **embed opaque + placeholder générique** pour tout futur embed (v1.x : image, mermaid…) — ne jamais modifier le codec pour un nouveau type. | Charlie (Senior Dev) |
| **AI-E6-2** | Toute conversion lossy **dégrade par-segment**, jamais tout-ou-rien ; test contenu-mixte systématique. | Dana (QA Engineer) |
| **AI-E6-3** | **Bannir les membres `@visibleForTesting` dans les voies de prod** ; API de persistance publique explicite. | Charlie (Senior Dev) |
| **AI-E6-4** | **EX-3** doit démontrer l'éditeur markdown + embeds sous `ZcrudScope`. | Amelia (Developer) |

---

## 5. Dette v1.x (actée, hors périmètre MVP)

- **ZHtmlCodec** — troisième codec optionnel (Delta/Markdown faits ; HTML non implémenté).
- **Overflow-x tableau large** — scroll horizontal des tableaux dépassant la largeur.
- **Édition par tap direct des embeds** — actuellement insertion/rendu, pas d'édition inline au tap.
- **Cellule riche / fusion / redimensionnement** de l'embed tableau (cellules texte simple pour le MVP).

---

## 6. Readiness — transition vers la suite

Epic E6 **complet et solide** : SM-1 non régressé, isolation prouvée, perte de données bornée, extensibilité additive validée. Aucune découverte significative n'invalide le plan aval.

**Prochaine étape MVP :** **EX-3** (démo markdown/geo/firestore sous `ZcrudScope`) — voir AI-E6-4 — puis **REL** (publication).

**Sprint-status :** transition `epic-6-retrospective: optional → done` à appliquer par l'orchestrateur (édition ciblée, non effectuée par cette rétro).
