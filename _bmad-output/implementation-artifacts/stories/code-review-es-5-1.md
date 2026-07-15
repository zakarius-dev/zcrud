# Code Review — ES-5.1 (TÊTE golden : décomposabilité du layout « study tools »)

Revue adversariale (effort high, skill `bmad-code-review`). Workstream B, vérifs CIBLÉES `packages/zcrud_study` uniquement (workstream A actif sur `scripts/ci`/`zcrud_flashcard`). Aucune commande repo-wide `verify`/`analyze`, aucun `git checkout/restore/stash`.

## Verdict : APPROUVÉ (aucun finding HIGH/MAJEUR). 4 findings mineurs (1 MEDIUM, 3 LOW) — story reste verte.

Les 7 ACs sont discriminants et prouvés. Le golden est NON powerless. La décomposabilité (Deferred AD-25) est confirmée par preuve rejouée.

---

## Preuve REJOUÉE que le golden/comptage est discriminant (axe n°1)

| Vérif rejouée | Résultat |
|---|---|
| Golden PNG committé | **500×1000**, RGBA, 6680 o — NON trivial (pas 1×1), loin du powerless R12 |
| Comparateur golden | `grep` test/ ⇒ **aucun** `goldenFileComparator`/`tolerance`/`withinPercentage` ⇒ **comparateur exact par défaut (tolérance NULLE)** |
| Byte-capture surface | `kByteCaptureSize == kSurfaceSize == Size(500,1000)` (I4 non actif) |
| **Injection I1 REJOUÉE** (préfixe de clé `section:` → `sekshun:`) | AC5(b) **RED RC=1** : `Expected: exactly 4 matching candidates / Actual: Found 0` ; `fusion → N-1` : `Expected: exactly 3 / Found 0` |
| Restauration (édition ciblée R13, jamais git checkout) | `flutter test` **6/6 GREEN RC=0** |

Le comptage structurel par `Key('section:*')` est donc **réellement** discriminant : perdre la frontière par section fait rougir AC5(b). Combiné au byte-diff `RepaintBoundary→toImage→bytes` (m1/m2/m3, chacun `isNot(equals(canonique))`) et au comparateur golden exact, le harnais n'est ni permissif ni cosmétique. Les injections I1–I4 du Dev Agent Record sont crédibles et cohérentes avec le code lu (I1 vérifiée en live).

## Vérif verte CIBLÉE (RC hors pipe, R15)

| Gate | Résultat |
|---|---|
| `dart analyze` (zcrud_study) | **No issues found! RC=0** |
| `flutter test` (zcrud_study) | **6/6 GREEN RC=0** (AC4 golden + AC5(a) m1/m2/m3 + AC5(b) N / N-1) |
| `graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, **19 nœuds** ; arêtes `zcrud_study → {core, study_kernel, annotations}` uniquement, aucune entrante vers core |
| `melos list` | **19 packages**, `zcrud_study` présent (18→19) RC=0 |
| Scans interdits | AUCUN `flutter_riverpod`/`get`/`provider`/`ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`/`setState` ; AUCUN `.left`/`.right`/`centerLeft`/`EdgeInsets.only`/`Positioned(` ; AUCUN `ListView(children:)` (seule occurrence = un commentaire) |

## Conformité par axe

- **AD-1/AD-17** : acyclique, CORE OUT=0, 3 arêtes sortantes déclarées, jamais entrantes. OK.
- **AD-2/AD-15** : `StatelessWidget` purs, aucun gestionnaire d'état, injection via `ZcrudTheme.of` (`ZcrudScope.maybeOf` → `Theme.of` repli vérifié dans `z_theme.dart:295`). OK.
- **AD-13/RTL** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, `ListView.builder`, `Semantics` (header/button/container), cible d'ajout ≥48 dp (`ConstrainedBox` 48×48). OK (nuances a11y → LOW ci-dessous).
- **AD-25** : `ZStudyToolsSectionSpec` = data-class `const` immuable (`id/title/itemCount/itemBuilder/emptyState/addAction?`), `addAction` nullable = absence (AD-4, aucun bouton rendu si null), `emptyState` rendu quand `itemCount==0` (jamais `itemBuilder`). OK.
- **SM-1** : chaque section = frontière keyée `ValueKey('section:$id')` (sous-arbre `_ZStudySection` isolé) — socle du rebuild granulaire d'ES-5.2 posé sans le régresser. OK.
- **AC6** : décomposabilité CONFIRMÉE par écrit (mapping 4 sections IFFD→4 specs + fichier:ligne, écarts résiduels documentés). OK.

---

## Findings

### MEDIUM-1 — `IconData` codé en dur dans le layout + label a11y du bouton d'ajout non descriptif
`z_sectioned_study_layout.dart:121` `icon: const Icon(Icons.add)` : l'icône de l'affordance « + » est **codée en dur** dans le layout. La consigne de revue (axe 4) et FR-26 proscrivent tout `IconData`/style codé en dur dans un package ; le `ZStudyToolsSectionSpec` n'expose aucun slot d'icône/tooltip pour l'action d'ajout. De plus (`:110-113`) le `Semantics(button: true, label: spec.title)` du bouton d'ajout annonce **le titre de section** (« Flashcards ») sans indiquer l'action « ajouter » — un lecteur d'écran entend « Flashcards, bouton » sur le +, ambigu avec l'en-tête homonyme.
**Impact** : borderline — `Icons.add` est un glyphe universel, directionnellement neutre et coloré par le thème (IconButton). **Recommandation** : soit rendre l'icône/tooltip injectable (ou tirer un token du thème), soit **justifier par écrit** le report à ES-5.2 (branchement réel de `addAction`), conformément à la politique MEDIUM. Corrigeable proprement en ES-5.2 sans régression du socle.

### LOW-1 — Style du `_CountBadge` codé en dur (incohérent avec les tokens de thème)
`z_sectioned_study_layout.dart:158-165` : `BorderRadius.circular(10)` et paddings `8`/`2` sont des constantes en dur, alors que les gaps du même fichier passent par `theme.gapS`/`gapM`. Couleurs OK (via `colorScheme`). Incohérence de thématisation mineure ; pas de bug. À aligner sur des tokens de thème quand disponibles.

### LOW-2 — `Semantics` redondants / imbriqués
`_CountBadge` (`:155`) enveloppe un `Text('$count')` dans `Semantics(label:'$count')` → double annonce du compteur. Le bouton d'ajout imbrique un `Semantics(button:true)` autour d'un `IconButton` qui porte déjà sa sémantique de bouton (`:111-119`). Sans impact fonctionnel ; à simplifier.

### LOW-3 — Nommage « m1 fusion » imprécis (documentaire)
`study_tools_page_golden_test.dart:80` / `:78` : `fusedSections()` **retire** la section notes plutôt que de fusionner documents+notes en une section à `itemCount` agrégé ; le commentaire « itemCount agrégé (2+0=2) » tient par coïncidence (notes vide). Le **pouvoir discriminant reste valide** (N→N-1, octets ≠ canonique car un sous-arbre entier disparaît), mais le libellé pourrait induire en erreur. Purement documentaire.

---

## Aucune régression cross-package attendue
Package NEUF purement additif (ajout `- packages/zcrud_study` au bloc `workspace:`), aucune arête entrante vers un package existant, aucun symbole public retiré. La vérif repo-wide (`melos analyze`) au gate de commit d'epic reste à la charge de l'orchestrateur (workstream A actif) — non rejouée ici par consigne d'isolation.

État final : working tree restauré (injection I1 annulée par édition ciblée), `flutter test` 6/6 GREEN.

---

## Décision orchestrateur (report des findings — justification écrite, règle MEDIUM)

**MEDIUM-1 → REPORTÉ à ES-5.2, justifié.** Le traitement du bouton d'ajout
(`Icon(Icons.add)` codé en dur + `Semantics(label: spec.title)` au lieu d'une
sémantique « ajouter ») est cohésivement lié au branchement réel de `addAction`,
périmètre EXPLICITE d'ES-5.2 (ES-5.1 ne rend le bouton que pour la décomposabilité/
golden ; `addAction` reste un slot nullable non fonctionnel). Le correctif propre
exige d'ajouter au `ZStudyToolsSectionSpec` des slots INJECTABLES `addActionIcon`/
`addActionSemanticLabel` (hardcoder un label FR/EN violerait l'i18n), API à
co-concevoir avec le câblage réel d'ES-5.2. Rien ne commite avant la fin de l'epic
ES-5 (commit d'epic après 5.2/5.3/5.4) : le correctif ES-5.2 atterrit dans le MÊME
commit, aucun code livré ne porte le smell. `Icons.add` = glyphe universel
thème-coloré (pas de couleur codée en dur) ; le golden régénérera au branchement.

**LOW-1/2/3 → REPORTÉS à ES-5.2** (même zone : paddings/BorderRadius en dur,
Semantics redondants, `fusedSections()` documentaire). Optionnels, non bloquants.

→ Consigné DW-ES51-1 au sprint-status. Story ES-5.1 verte (golden 6/6), `done`.
