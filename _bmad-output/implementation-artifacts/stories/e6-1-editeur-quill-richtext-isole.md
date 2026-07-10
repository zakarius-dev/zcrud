---
baseline_commit: fe203b90bb95a659063452af4cf584f66e7bab0f
---

# Story 6.1: Éditeur Quill + champ rich-text à controller isolé (`zcrud_markdown`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud (DODLP puis lex_douane)**,
I want **un champ rich-text `ZMarkdownField` (éditeur Quill) au controller ISOLÉ, branché sur une tranche du `ZFormController` via une valeur neutre**,
so that **je puisse éditer du contenu riche dans un formulaire sans reconstruire globalement le formulaire à chaque frappe (objectif produit n°1 / SM-1), sans perte de focus ni saut de curseur, et sans que `flutter_quill` ne fuite dans `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

Début de l'**epic E6 — Markdown & rich text** (`zcrud_markdown`). Cette story pose **l'éditeur Quill isolé** et **le champ rich-text branché sur `ZFormController`**. Elle NE fait QUE cela.

- **AD-7 (Rich-text)** [Source: architecture.md#AD-7] : l'éditeur travaille en **Delta** en interne (Quill) ; le champ rich-text a **son propre controller isolé, conforme AD-2**. La (dé)sérialisation du format persisté passera par un **`ZCodec` pluggable (Delta/Markdown/HTML)** — **c'est E6-2, PAS cette story**.
- **AD-2 (rebuilds granulaires, objectif produit n°1)** [Source: architecture.md#AD-2] : état dans `ZFormController` (`ChangeNotifier`/`ValueListenable` pur-Flutter), un champ = un widget qui n'écoute QUE sa tranche via `ValueListenableBuilder`. **Interdits** : recréation du controller au rebuild, ré-injection de valeur écrasant la sélection, `setState` à l'échelle du formulaire. **Obligatoires** : controller stable (create/dispose), `ValueKey(field.name)`, `AutovalidateMode.onUserInteraction`.
- **AD-1 (acyclicité + isolation)** [Source: architecture.md#AD-1] : `zcrud_core` ne dépend d'**aucun** autre package zcrud ni de **Quill**. `zcrud_markdown` dépend de `zcrud_core`. `flutter_quill` vit **au seul pubspec de `zcrud_markdown`** ; **aucun type Quill ne fuit** dans `zcrud_core` ni dans la valeur exposée au `ZFormController`.
- **AD-10 (désérialisation défensive)** [Source: architecture.md#AD-10] : Delta absent/vide/corrompu → document vide, **jamais** de throw.
- **AD-13 (RTL/a11y/thème injecté)** [Source: architecture.md#AD-13] : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, `Semantics` explicites, cibles ≥ 48 dp ; thème injecté via `ZcrudScope`, repli `Theme.of(context)`, **zéro couleur/style codé en dur**.

**Frontière E6-1 vs le reste de l'epic (NON-NÉGOCIABLE)** :
| Story | Périmètre | Dans E6-1 ? |
|---|---|---|
| **E6-1 (ici)** | Éditeur Quill isolé + `ZMarkdownField` branché sur `ZFormController` avec **valeur neutre** ; toolbar presets ; conversion Delta↔JSON **minimale interne** (via l'API Quill native) ; défensif ; thème/RTL/a11y ; isolation. | ✅ |
| E6-2 | **`ZCodec` pluggable** (Delta/Markdown/HTML), format persisté par défaut documenté + round-trip (SM-4). | ❌ (E6-2) |
| E6-3 | Embed **LaTeX** (`flutter_math_fork`). | ❌ (E6-3) |
| E6-4 | Embed **tableau**. | ❌ (E6-4) |

> ⚠️ En E6-1, le champ expose/consomme une **valeur neutre** (Delta JSON = `List`/`Map` JSON-safe, ou `String` JSON). La sélection du **format persisté** et l'abstraction `ZCodec` sont **explicitement hors périmètre** (E6-2). Utiliser directement l'API native de Quill (`Document.fromJson` / `document.toDelta().toJson()`) pour la conversion interne minimale ; ne PAS anticiper `ZCodec`.

## Acceptance Criteria

1. **Édition → tranche du form (AD-2/AD-7).** Éditer dans `ZMarkdownField` met à jour la tranche `controller.fieldListenable(name)` du `ZFormController` avec une **valeur neutre** (Delta JSON : `List`/`Map` JSON-safe, ou `String`), via un listener du document Quill → `controller.setValue(name, <deltaJsonNeutre>)`. `controller.valueOf(name)` reflète le contenu édité. La saisie est à **sens unique** dans la voie de frappe (pas de ré-injection).

2. **SM-1 / objectif produit n°1 (AD-2).** Éditer N caractères ne reconstruit **QUE** le sous-arbre du champ rich-text (rendu sous `ZFieldListenableBuilder` du core, RÉUTILISÉ — jamais réimplémenté) : **zéro** rebuild d'un champ voisin, **zéro** rebuild global du formulaire ; le `QuillController` n'est **JAMAIS** recréé ; **focus + sélection/curseur préservés** (aucune ré-injection écrasant la sélection pendant l'édition, y compris curseur au milieu). Vérifié par test widget (compteurs de build par champ + global) et par preuve de non-recréation du controller (compteur `initState == 1`).

3. **Controller stable + cycle de vie propre (AD-2 ; parité AI-E5-4).** `QuillController` (et `FocusNode`/`ScrollController` associés) créé **UNE SEULE FOIS** en `initState`, **disposé** en `dispose` ; le **listener** du document est **retiré** au `dispose` (pas de fuite d'abonnement/listener). Test anti-fuite : après `dispose`, plus aucun listener actif ; N cycles montage/démontage → zéro croissance.

4. **Désérialisation défensive (AD-10 ; AI-E5-3).** Valeur de tranche **absente (`null`)**, **vide**, ou **Delta corrompu** (JSON tronqué, type inattendu, opération malformée, `insert` manquant) → l'éditeur ouvre un **document VIDE utilisable**, **aucun throw**, log non-fatal. Testé sur des cas **RÉELS** de corruption (pas seulement le happy-path).

5. **Thème injecté (AD-13, FR-26).** Couleurs/typographie de l'éditeur et de la toolbar proviennent du **thème injecté via `ZcrudScope`** avec repli `Theme.of(context)` ; **aucune** couleur/style codé en dur. Test : un thème custom injecté est effectivement reflété.

6. **RTL + a11y (AD-13).** Rendu directionnel (respecte `Directionality`) ; `Semantics` explicites sur l'éditeur et la toolbar ; cibles interactives de la toolbar **≥ 48 dp**. Test RTL (rendu sous `TextDirection.rtl` sans casse) + assertions de sémantique/taille de cible.

7. **Isolation dépendances — gate (AD-1).** `zcrud_core` **ne tire PAS** `flutter_quill` : `flutter_quill` est **absent** des dépendances (directes et transitives via zcrud_*) de `zcrud_core` et présent **uniquement** dans `zcrud_markdown`. Vérifié par un test/gate de dépendances.

8. **Isolation signature — aucun type Quill ne fuit (AD-1).** Aucun type Quill (`QuillController`, `Document`, `Delta`, `Attribute`, …) n'apparaît dans la **signature publique** de `zcrud_core`, ni dans la **valeur exposée au `ZFormController`** (qui reste neutre : Delta JSON / `String`). Test de signature/API publique.

9. **Toolbar presets (epic E6-1 AC).** Une **toolbar Quill optionnelle** (activable/désactivable par paramètre du widget, presets par défaut) est branchée sur le **même** `QuillController`. Par défaut cohérente ; désactivable pour un rendu compact.

10. **Sync guardée hors focus (AD-2/FR-1).** Une valeur changée de l'**extérieur** (reseed/UJ-2) se reflète dans l'éditeur **quand il n'a PAS le focus**, mais n'est **JAMAIS** ré-injectée **pendant l'édition** (sélection/curseur préservés) — miroir exact de la sync guardée de `ZEditionField`.

## Tasks / Subtasks

- [x] **Tâche 1 — Couche presentation + dépendance isolée (AC7)**
  - [x] Ajouter `flutter_quill: ^11.5.0` (série `^11.5.x`, cf. stack architecture) au **seul** `packages/zcrud_markdown/pubspec.yaml` (+ `flutter` sdk). NE PAS l'ajouter à `zcrud_core`.
  - [x] Créer `packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` ; exporter `ZMarkdownField` depuis le barrel `lib/zcrud_markdown.dart`.
- [x] **Tâche 2 — `ZMarkdownField` (StatefulWidget) branché sur la tranche (AC1, AC2, AC3, AC10)**
  - [x] Signature : `controller: ZFormController`, `field: ZFieldSpec` (ou `name: String` + label), `showToolbar: bool = true`, hooks `@visibleForTesting onInit/onBuild` (miroir de `ZEditionField`).
  - [x] `initState` : lire `controller.valueOf(name)`, décoder défensivement en `Document` (Tâche 4), créer `QuillController(document, selection)` + `FocusNode` + `ScrollController` **une fois** ; enregistrer un **listener** de document → `controller.setValue(name, documentDeltaJsonNeutre)` (sens unique, pas de ré-injection).
  - [x] `build` : rendre sous `ZFieldListenableBuilder(controller, name, builder: …)` (RÉUTILISER le helper du core — AD-2) ; **sync guardée** : refléter la valeur externe dans le `QuillController` **uniquement hors focus** et si différente (idempotent pendant la frappe), **jamais** pendant l'édition.
  - [x] `dispose` : `removeListener` + `dispose()` du `QuillController`, `FocusNode`, `ScrollController`.
  - [x] L'assembleur doit poser `key: ValueKey(name)` (place stable) — documenté dans le dartdoc du widget.
- [x] **Tâche 3 — Toolbar presets + thème/RTL/a11y (AC5, AC6, AC9)**
  - [x] Toolbar Quill optionnelle (presets) branchée sur le même `QuillController`, activable via `showToolbar`.
  - [x] Styles depuis `ZcrudScope` (thème injecté) avec repli `Theme.of(context)` ; **aucune** couleur codée en dur.
  - [x] `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start` ; `Semantics` explicites ; cibles toolbar ≥ 48 dp ; respect de `Directionality`.
- [x] **Tâche 4 — Conversion neutre Delta↔JSON minimale + défensif (AC1, AC4, AC8)**
  - [x] Helper interne (privé) `Document _decodeDefensive(Object? sliceValue)` : `null`/vide/JSON invalide/opération malformée → `Document()` vide, **jamais** de throw (try/catch borné + log non-fatal).
  - [x] Helper interne `Object _encodeNeutral(Document)` → **valeur neutre JSON-safe** (`document.toDelta().toJson()` = `List<Map>`), **jamais** un type Quill exposé.
  - [x] Garantir qu'aucun type Quill n'apparaît dans l'API publique de `zcrud_markdown` exposée au form (valeur = Delta JSON / `String`).
- [x] **Tâche 5 — Tests (voir stratégie ci-dessous)** couvrant AC1–AC10 (SM-1, focus, dispose/anti-fuite, défensif réel, thème, RTL, gate deps, signature).
- [x] **Tâche 6 — Vérif verte** : `melos run generate` → `melos run analyze` (RC=0) → `flutter test` `zcrud_markdown` + `zcrud_core` (aucune régression) ; `melos run verify` (gates melos/reflectable/secrets/codegen/compat) RC=0 ; graphe **ACYCLIQUE** + `CORE OUT=0` intacts.

## Dev Notes

### Patron de référence à MIROITER (ne pas réinventer)
`ZEditionField` [Source: packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart] est le patron canonique AD-2 : `StatefulWidget`, `TextEditingController` créé **une fois** en `initState` / `dispose`, `FocusNode` stable, rendu sous `ZFieldListenableBuilder`, **sync guardée hors focus** (`if (!_focus.hasFocus && _text.text != s) …`), `onChanged → controller.setValue`. **`ZMarkdownField` reprend exactement ce contrat**, en remplaçant `TextEditingController` par `QuillController` et l'`onChanged` par un **listener de document**.

### API `ZFormController` réelle (à consommer, ne pas dupliquer)
[Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart]
- `ValueListenable<Object?> fieldListenable(String name)` — tranche mémoïsée (toujours la même instance pour un `name`).
- `Object? valueOf(String name)` — lecture de la tranche (valeur initiale en `initState`).
- `void setValue(String name, Object? value)` — notifie **UNIQUEMENT** les listeners de `fieldListenable(name)`, jamais de rebuild global.
- Helper `ZFieldListenableBuilder(controller, name, builder)` [Source: packages/zcrud_core/lib/src/presentation/z_field_listenable_builder.dart] — **frontière de rebuild = la tranche** ; RÉUTILISER, ne pas réimplémenter.

> La valeur de tranche est `Object?` : y stocker le **Delta JSON neutre** (`List<Map<String,dynamic>>`) est conforme (pas de type Quill dans le controller).

### Isolation AD-1 (preuve, pas affirmation — cf. rétro E5)
La rétro E5 insiste : l'isolation doit être **prouvée** (E5 a re-vérifié `CORE OUT=0` + 0 fuite de type backend). Ici, transposer :
- `flutter_quill` **jamais** dans `zcrud_core` (gate AC7) ;
- **aucun** `QuillController`/`Document`/`Delta` en signature publique côté core, ni dans la valeur du form (AC8) ;
- la valeur remontée est **neutre** (Delta JSON / `String`).

### Learnings E5 à appliquer (AI-E5-3, AI-E5-4)
[Source: epic-5-retrospective.md#4]
- **AI-E5-3 (défensif RÉEL)** : tester **entrée corrompue / champ absent / vide** — pas seulement un seed propre. Un Delta tronqué/mal typé ne doit **jamais** casser (AC4). Le happy-path masque les vrais cas limites.
- **AI-E5-4 (fuite de cycle de vie par parité)** : chercher toute fuite d'abonnement/listener. Ici le `QuillController` + le **listener de document** DOIVENT être disposés/retirés proprement (AC3), avec test anti-fuite (miroir du défaut `onCancel` d'E5).

### Stratégie de tests
| # | Test | Prouve |
|---|---|---|
| T1 | widget : éditer → `valueOf(name)` = Delta JSON neutre attendu | AC1 |
| T2 | widget SM-1 : N frappes → `buildsField` incrémente, `buildsVoisin`/`buildsGlobal` inchangés ; `initState` compteur == 1 ; focus/sélection préservés | AC2 |
| T3 | dispose/anti-fuite : montage→démontage ×N, listener retiré, zéro croissance | AC3 |
| T4 | défensif : `null`, `{}`/`[]` vide, JSON tronqué, type non-List, opération sans `insert` → document vide, **aucun throw** | AC4 |
| T5 | thème : `ZcrudScope` avec thème custom → reflété ; grep/absence de couleur en dur | AC5 |
| T6 | RTL/a11y : rendu `TextDirection.rtl` sans casse ; `Semantics` présents ; cible toolbar ≥ 48 dp | AC6 |
| T7 | gate deps : `flutter_quill` absent des deps (dir+transitives) de `zcrud_core`, présent dans `zcrud_markdown` | AC7 |
| T8 | signature : aucun type Quill dans l'API publique exposée au form ; valeur = Delta JSON/`String` | AC8 |
| T9 | toolbar : `showToolbar:false` → pas de toolbar ; `true` → toolbar sur le même controller | AC9 |
| T10 | sync guardée : setValue externe hors focus → reflété ; pendant focus/édition → **non** ré-injecté (sélection préservée) | AC10 |

### Project Structure Notes
- Nouveau : `packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` (couche `presentation/`, cohérent avec la structure `src/{domain,data,presentation}`).
- Barrel : exporter `ZMarkdownField` depuis `packages/zcrud_markdown/lib/zcrud_markdown.dart` (actuellement l'API n'expose que le placeholder `ZMarkdownApi`).
- `pubspec.yaml` `zcrud_markdown` : ajouter `flutter` (sdk) + `flutter_quill: ^11.5.0`. Le squelette actuel ne déclare que `zcrud_core`.
- **Ne PAS** modifier `zcrud_core` (sauf besoin avéré ; si un point d'extension core manque, le signaler plutôt que de faire fuiter Quill).
- **Ne PAS** modifier `sprint-status.yaml` (géré par l'orchestrateur).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E6] — Story E6-1 (éditeur Quill + champ rich-text controller isolé ; toolbar presets) ; frontière E6-2/3/4.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-7] — Delta interne, controller isolé conforme AD-2, ZCodec = E6-2.
- [Source: architecture.md#AD-2] — rebuilds granulaires, controller stable, interdits/obligatoires, objectif produit n°1 / SM-1.
- [Source: architecture.md#AD-1] — acyclicité + isolation Quill dans zcrud_markdown.
- [Source: architecture.md#AD-10] — désérialisation défensive.
- [Source: architecture.md#AD-13] — RTL/a11y/thème injecté.
- [Source: architecture.md — Tech Stack] — `flutter_quill ^11.5.x`.
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart] — patron de champ AD-2 à miroiter.
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart / z_field_listenable_builder.dart] — API tranche/slice.
- [Source: _bmad-output/implementation-artifacts/stories/epic-5-retrospective.md#4] — AI-E5-3 (défensif réel), AI-E5-4 (fuite cycle de vie par parité).
- [Source: CLAUDE.md] — Key Don'ts : jamais Quill dans zcrud_core ; controller rich-text isolé ; jamais style codé en dur ; RTL directionnel.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- Blocage résolu #1 — SM-1 multi-champs : `find.byType(QuillEditor)` ambigu avec 2 champs (« Too many elements ») → finders scellés au sous-arbre via `find.descendant(of: find.byKey(ValueKey(name)), …)`.
- Blocage résolu #2 — `A Timer is still pending` : la toolbar Quill (`QuillToolbarArrowIndicatedButtonList.initState`) planifie un `Timer.run(0)` et l'éditeur focalisé un `Timer.periodic` de curseur → helper `_settle` (pompe 50 ms pour drainer, puis démonte l'arbre) avant la vérification d'invariants de fin de test.
- Blocage résolu #3 — gate barrel : le commentaire du barrel nomme légitimement `flutter_quill` → le test ne scanne que les DIRECTIVES `import`/`export` (commentaires ignorés).

### Completion Notes List

Implémentation E6-1 — éditeur Quill isolé + `ZMarkdownField` branché sur `ZFormController` (valeur NEUTRE Delta JSON), STRICTEMENT dans `packages/zcrud_markdown/` (aucune modif de `zcrud_core`/example/autres packages/sprint-status).

- **AC1** — édition → tranche : listener de `QuillController` → `setValue(name, deltaJsonNeutre)` (sens unique). `valueOf(name)` = `List<Map<String,dynamic>>`. ✅
- **AC2 / SM-1** — 100 frappes ne reconstruisent QUE le champ courant (voisin figé, compteur global `AnimatedBuilder(controller)` inchangé = zéro `notifyListeners` global) ; `QuillController` jamais recréé (`onInit`==1) ; **focus + curseur au milieu préservés** (offset 1 → 101). ✅
- **AC3** — controller/FocusNode/ScrollController créés en `initState`, disposés en `dispose`, listener retiré AVANT dispose ; anti-fuite : 6 cycles montage/démontage, `onInit`==6, aucun listener fantôme (setValue post-démontage sans throw). ✅
- **AC4** — décodage défensif RÉEL : `null`, `[]`, `{}`, JSON tronqué, string vide, string non-JSON, op non-Map, op sans `insert` (retain seul), nombre brut → document VIDE, **aucun** throw (9 cas). ✅
- **AC5** — thème : `ZcrudScope(theme: ZcrudTheme(fieldBorderColor:))` reflété dans la bordure ; zéro couleur en dur (repli `ZcrudTheme.of` → `Theme.of`). ✅
- **AC6** — RTL (`TextDirection.rtl` sans casse) + `Semantics` éditeur/toolbar + cible toolbar ≥ 48 dp (`ConstrainedBox(minHeight:48)` + `toolbarSize:48`) ; insets directionnels. ✅
- **AC7** — gate de graphe : fermeture de `zcrud_core` SANS `flutter_quill` ; contrôle positif `zcrud_markdown` AVEC `flutter_quill` (+ transitif externe `dart_quill_delta`) ; acyclicité `zcrud_markdown → zcrud_core`, `CORE OUT zcrud_*=0`. ✅
- **AC8** — isolation signature : valeur du form = `List<Map<String,dynamic>>` JSON-safe (jamais `Document`) ; scan statique : barrel sans directive `flutter_quill`, surface publique de `ZMarkdownField` sans type Quill. ✅
- **AC9** — toolbar presets : `showToolbar:false` → aucune toolbar ; `true` → toolbar sur le MÊME `QuillController` (identité). ✅
- **AC10** — sync guardée : reseed externe HORS focus reflété ; PENDANT le focus jamais ré-injecté (document + curseur intacts). ✅

**Frontière respectée** : PAS de `ZCodec` pluggable (E6-2), PAS d'embed LaTeX (E6-3), PAS d'embed tableau (E6-4) — conversion Delta↔JSON minimale via l'API native Quill uniquement. `flutter_quill: ^11.5.0` au SEUL pubspec de `zcrud_markdown`.

**Vérif verte rejouée réellement sur disque** :
- `dart run melos run generate` → RC=0 (SUCCESS).
- `dart run melos run analyze` → RC=0, **0 issue** (tous packages, dont `zcrud_markdown`).
- `flutter test` (`zcrud_markdown`) → RC=0, **27 tests** passés.
- `flutter test` (`zcrud_core`) → RC=0, **562 tests** (aucune régression).
- `dart run melos run verify` → RC=0 : **ACYCLIQUE OK**, **CORE OUT=0 OK**, gates melos/reflectable/secrets/codegen/compat OK.
- `melos list` = **14**.

### Remédiation code-review E6-1 (skill `bmad-dev-story`)

Findings du rapport `code-review-e6-1.md` (0 HIGH, 0 MAJEUR, 1 MEDIUM + 3 LOW) traités STRICTEMENT dans `packages/zcrud_markdown/` (aucune modif hors package ; sprint-status non touché).

- **MED-1 (efficacité) — CORRIGÉ** : le listener n'est PLUS branché sur `_quill.addListener` (qui notifiait AUSSI sur déplacement de curseur/sélection → encodage O(taille doc) à chaque mouvement de caret). Il écoute désormais le flux de **mutations de CONTENU** `_quill.document.changes.listen(...)`, qui n'émet PAS sur changement de sélection. L'abonnement (`StreamSubscription<DocChange>`) est géré proprement : **annulé et remis à `null` au `dispose`** (anti-fuite), et **ré-abonné** après remplacement du document par la sync guardée (`_quill.document = …` swappe l'instance de `Document` sans transférer l'abonnement — sinon les frappes suivantes deviendraient muettes). Garde `_applyingExternal` + dédup `_lastValueJson` conservées. Nouveau test `MED-1 — sélection seule ⇒ AUCUN encodage` : 20 déplacements de curseur + 1 sélection étendue ne changent NI `debugDocChangeCount` NI le nb de `setValue`, alors qu'une frappe réelle les incrémente. SM-1 reste prouvé (test AC2 inchangé : frappe → encode + `setValue` ciblé, voisin/global figés).
- **LOW-1 (test anti-fuite proxy) — CORRIGÉ** : ajout d'une fenêtre de test `ZMarkdownFieldDebug` (`@visibleForTesting`, implémentée par le `State`, SANS exposer le State privé ni un type Quill) exposant `debugDocChangeCount` (invocations réelles du listener) et `debugDocSubscriptionActive` (abonnement encore actif). Nouveau test `LOW-1` : capture la fenêtre debug avant démontage, prouve l'abonnement ACTIF + exercé par une frappe, puis après démontage vérifie `debugDocSubscriptionActive == false` — **preuve DIRECTE** du retrait (un `cancel` oublié ferait échouer l'invariant, ce que le proxy « setValue post-démontage sans throw » ne pouvait pas).
- **LOW-2 (cible ≥48 dp) — CORRIGÉ** : le test toolbar assère désormais, EN PLUS de la hauteur du conteneur, la taille d'un **bouton toolbar RÉEL** (`IconButton` descendant de `QuillSimpleToolbar` sous `toolbarSize:48`) ≥ 48 dp.
- **LOW-3 (double couche sémantique) — DOCUMENTÉ (intentionnel)** : commentaire ajouté sur le `Semantics(textField:true,label:)` de l'éditeur — ce nœud n'apporte QUE l'étiquette + le rôle `textField` ; les nœuds d'édition internes de `QuillEditor` ne sont PAS exclus (préservation de la lecture du contenu). Rendu vérifié sans exception ; une passe TalkBack/VoiceOver réelle relève de la QA a11y d'intégration.

**Vérif verte de remédiation rejouée réellement sur disque** :
- `dart run melos run analyze` → RC=0, **0 issue** (14/14 packages « No issues found »).
- `flutter test` (`zcrud_markdown`) → RC=0, **29 tests** passés (dont le nouveau test MED-1 « sélection seule » et le test LOW-1 anti-fuite renforcé).
- `dart run melos run verify` → RC=0 : **CORE OUT=0 OK**, gates graphe/reflectable/secrets/codegen/compat + corpus sérialisation OK.
- `melos list` = **14**.

### File List

- `packages/zcrud_markdown/pubspec.yaml` (modifié — ajout `flutter` sdk + `flutter_quill: ^11.5.0` + `flutter_test` + `uses-material-design`)
- `packages/zcrud_markdown/lib/zcrud_markdown.dart` (modifié — export `ZMarkdownField`)
- `packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` (créé — widget `ZMarkdownField` ; **remédiation E6-1** : listener sur `document.changes` [MED-1], fenêtre `ZMarkdownFieldDebug` [LOW-1], doc a11y [LOW-3])
- `packages/zcrud_markdown/test/z_markdown_field_test.dart` (créé — AC1–AC5, AC9, AC10 ; **remédiation E6-1** : test MED-1 « sélection seule ⇒ aucun encodage »)
- `packages/zcrud_markdown/test/z_markdown_field_lifecycle_test.dart` (créé — AC3 anti-fuite, AC6 RTL/a11y ; **remédiation E6-1** : test LOW-1 anti-fuite direct + LOW-2 bouton toolbar réel ≥48 dp)
- `packages/zcrud_markdown/test/flutter_quill_isolation_graph_test.dart` (créé — AC7 gate de graphe)
- `packages/zcrud_markdown/test/quill_signature_isolation_test.dart` (créé — AC8 isolation signature/valeur)
