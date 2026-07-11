# Code-review — DP-3 : Rich-text lecture seule + modes (B4+B6) — `zcrud_markdown`

- **Mode d'exécution** : VRAI skill `bmad-code-review` invoqué (tool `Skill`) — workflow step-file suivi (step-01 gather-context, step-02 review). Revue exécutée en agent unique (subagent non-interactif), périmètre imposé par la tâche. **Aucune simulation.**
- **Story** : `_bmad-output/implementation-artifacts/stories/dp-3-richtext-lecture-seule-modes.md` (7 ACs, `baseline_commit = 1bcae2a` == HEAD ⇒ revue du working-tree).
- **Périmètre STRICT revu** (uniquement DP-3, `packages/zcrud_markdown/`) :
  - NEW : `lib/src/presentation/z_rich_text_core.dart`, `z_markdown_reader.dart`, `z_rich_text_fullscreen_dialog.dart`, `z_markdown_registration.dart`
  - MODIFIÉS : `lib/src/presentation/z_markdown_field.dart`, `lib/zcrud_markdown.dart`
  - TESTS : `test/z_markdown_richtext_modes_test.dart`, `test/support/a11y_asserts.dart`
  - Contexte lu (non modifié) : `z_widget_registry.dart` (cœur), `delta_neutral_ops.dart`. **Aucun autre package revu, aucun fichier DODLP touché.**

## Verdict : **APPROUVÉ** (aucun finding bloquant — 0 HIGH, 0 MAJEUR, 0 MEDIUM bloquant)

Les 7 ACs sont satisfaits, les invariants AD-1/AD-2/AD-7/AD-10/AD-13/AD-4/FR-26 tenus, la rétro-compat E6 stricte (155 tests E6 inchangés). Findings LOW/nits seulement (non bloquants).

---

## Vérif verte rejouée réellement sur disque

| Étape | Commande | RC / Résultat réel |
|-------|----------|--------------------|
| analyze | `dart analyze packages/zcrud_markdown` | **No issues found!** (RC=0) |
| test | `flutter test` (packages/zcrud_markdown) | **All tests passed — 174** (RC=0) ; dont 19 DP-3 + 155 E6 baseline |
| graph | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK ; CORE OUT=0 OK** (RC=0) |
| gate isolation | `quill_signature_isolation_test` + `flutter_quill_isolation_graph_test` | **verts** (aucun type Quill exporté) |
| garde thème/directionnel | grep denylist sur les 5 fichiers `lib/` DP-3 | **0 match** (RC=1 grep = aucune occurrence) |

Compte : 174 tests = **155 E6 (baseline, inchangés) + 19 DP-3**. Baseline E6 préservée (174 − 19 = 155).

---

## Axes adversariaux — validation

- **AC1 — readOnly honoré** ✅. `ZMarkdownReader` : `QuillController(readOnly:true)` (`z_markdown_reader.dart:94-98`), **0 toolbar**, **0 bouton d'édition**, `showCursor:false`, **aucun** abonnement `document.changes`, **aucun** `setValue`/`onChanged`. `debugDocSubscriptionActive` reste `false` (pas de `_docChangesSub` en mode reader). Corrompu/vide → rendu vide propre via `DeltaNeutralOps.decodeDefensiveDocument` (AD-10, jamais de throw ; log non-fatal sous `assert`). Vérifié voie `controller` ET voie `ctx`.
- **AC2 — inline vs block dérivé du kind** ✅. `registerZMarkdownFields` : `inlineMarkdown`→`inline`, `markdown`/`richText`→`block` (`z_markdown_registration.dart:38-49`). `inline` = éditeur compact éditable (toolbar `minimal:true`) + toggle plein-écran ; `block` = aperçu reader non éditable + bouton « Rédiger »/« Modifier » (aucun `QuillController` d'édition : `_needsEditingController` false pour `blockPreview`).
- **AC3 — `ZRichTextFullscreenDialog`** ✅. Dialog dimensionné 80 %×70 % (`_sizedDialog`, `size.width*0.8`/`size.height*0.7`) ; repli `Scaffold`/`Dialog.fullscreen` sous 600 dp (`_kFullscreenBreakpoint`). Valider ⇒ retourne valeur **neutre** (`encodeNeutral`), écrite via `_write` + `_forceApplyNeutral`. Annuler/dismiss ⇒ `null`, no-op (tranche inchangée). **Aucun type Quill** dans `showZRichTextFullscreenDialog(...)→Future<Object?>` ni dans le constructeur (`Object? initialValue`).
- **AC4/AC5 — AD-2/SM-1** ✅. Adaptateur `ctx`-natif (`ZMarkdownField.fromContext`) : `QuillController`/`FocusNode`/`ScrollController` créés 1× en `initState` (`_initEditingController`), disposés, jamais recréés ; abonnement `document.changes` annulé au `dispose` ; écriture sens unique (`_onQuillChanged→_write`) ; sync guardée `!hasFocus` (`_syncFromExternal:427`). Init==1, sélection seule ⇒ 0 setValue (dédup `_lastValueJson` + garde `_documentChangeCount`). Voies `controller` et `ctx` partagent le même `State` (pas de duplication du chemin chaud).
- **AC6 — factory + a11y + thème + isolation** ✅. `registerZMarkdownFields` sur `ZWidgetRegistry` **instanciable** (pas de singleton) ; collision→`throw` (`ZDuplicateRegistrationError`, testé). Cibles ≥ 48 dp (`kZMinTapTarget`, `assertMinTapTarget`) + action sémantique opérable (`assertSemanticActionTap`). Thème via `ZcrudTheme.of` (repli `Theme.of`), **0 couleur en dur** (grep denylist vert). Isolation AD-1/AD-7 : barrel `show` neutres uniquement, `zcrud_core` intact, aucune dépendance ajoutée au `pubspec.yaml`.
- **AC7 — vérif verte** ✅ (cf. tableau).
- **Rétro-compat E6 STRICTE** ✅. `ZMarkdownField({required controller, field, showToolbar, codec, onInit, onBuild})` inchangée (signature + comportement par défaut = éditeur pleine-toolbar, `showToolbar` honoré). 155 tests E6 verts sans modification de leurs attentes.

---

## Findings

### LOW-1 — Fidélité du test SM-1 « 100 caractères » (voie `ctx`) : harnais bespoke, pas le dispatch `DynamicEdition`
- **Fichier** : `test/z_markdown_richtext_modes_test.dart:350-409`.
- **Constat** : le test-vedette AC5 (100 frappes → voisin non reconstruit, `init==1`, identité `QuillController` stable) monte le champ via un harnais **bespoke** (`KeyedSubtree`→`ValueListenableBuilder`→`ZMarkdownField.fromContext`), **pas** via `registerZMarkdownFields` + `DynamicEdition`/`ZFieldWidget` comme le stipule littéralement l'AC5 (« monté via un `ZWidgetRegistry` peuplé par la factory du package et rendu par `ZFieldWidget`/`DynamicEdition` »). Le chemin réel du dispatcher n'est stressé que par le test MED-1 (`z_markdown-richtext_modes:411`, `_appRegistry`), qui vérifie « sélection seule ⇒ 0 setValue » mais **pas** les 100 frappes / l'identité du controller / le non-rebuild du voisin.
- **Risque réel** : **faible**. Le harnais bespoke réplique fidèlement la frontière value-in-slice posée par le dispatcher (`ZFieldListenableBuilder`), et le test MED-1 confirme que la vraie voie registre/`DynamicEdition` fonctionne (rendu, focus, dédup). La couverture est donc effective, mais scindée sur deux tests au lieu d'un seul passant par le dispatch de production.
- **Reco** : ajouter (ou faire porter à MED-1) une assertion « 100 frappes + identité `QuillController` stable + voisin non reconstruit » montée via `_appRegistry`/`DynamicEdition`, pour clore l'AC5 sur le chemin de production exact. **Non bloquant.**

### LOW-2 — Chaînes UI en dur (français), hors l10n
- **Fichiers** : `z_markdown_reader.dart:47` (`'Aucun contenu'`), `z_rich_text_fullscreen_dialog.dart:147` (`'Barre d'outils'`), `:214` (`'Éditer'`), `z_markdown_field.dart:561/570` (`'Agrandir'`), `:579` (`'Rédiger'`/`'Modifier'`), `z_rich_text_core.dart:70/75` (`'Insérer une formule'`/`'Insérer un tableau'`).
- **Constat** : libellés/tooltips/placeholders utilisateur codés en dur, non routés via l10n. Les actions Valider/Annuler du dialog utilisent correctement `MaterialLocalizations` (`okButtonLabel`/`cancelButtonLabel`) — bon patron — mais le reste ne suit pas.
- **Risque réel** : **faible / divergence assumée**. Parité avec E6 (les tooltips embeds étaient déjà en dur), la story ne requiert pas d'l10n de ces libellés, et le placeholder est paramétrable (`ZMarkdownReader.placeholder`). À consigner comme dette l10n pour l'intégration DODLP/lex_douane. **Non bloquant.**

### LOW-3 — AD-10 (valeur corrompue) non testé sur la voie d'**édition** (inline/full)
- **Fichier** : `test/z_markdown_richtext_modes_test.dart:160-172` (corrompu testé **uniquement** en `readOnly`/reader).
- **Constat** : le décodage défensif AD-10 est bien commun (`decodeDefensiveDocument`), et `_initEditingController` l'emprunte, mais aucun test DP-3 ne monte un **éditeur inline** avec une tranche corrompue (`'not-a-delta'`) pour prouver « document vide éditable, pas de throw » sur la voie d'édition. Couvert indirectement par les tests E6 sur la voie `controller`.
- **Reco** : ajouter un cas « inline + valeur corrompue → éditeur vide, `takeException()==null` ». **Non bloquant (nit).**

### LOW-4 — `Semantics(readOnly:true)` sans `textField:true` dans le reader
- **Fichier** : `z_markdown_reader.dart:168-172`.
- **Constat** : le flag sémantique `readOnly` n'a de sens standard qu'associé à `textField:true`. Le reader vise « lisible mais non éditable » ; l'intention est correcte, mais le signal `readOnly` isolé est peu porteur pour un lecteur d'écran (le contenu reste exposé via le sous-arbre `QuillEditor`).
- **Reco** : soit retirer `readOnly` (le contenu est déjà exposé), soit assumer un `label` container simple. Cosmétique a11y. **Non bloquant (nit).**

---

## Confirmations demandées

- **readOnly** : ✅ honoré sur les deux voies (`controller` + `ctx`) ; reader `QuillController(readOnly:true)`, 0 toolbar, 0 bouton, `onChanged` jamais émis, corrompu/vide → vide (AD-10).
- **Modes inline/block** : ✅ dérivés du kind par la factory (`inlineMarkdown`→inline ; `markdown`/`richText`→block) ; inline = compact + toggle plein-écran ; block = aperçu + « Rédiger/Modifier » + dialog.
- **Aucun type Quill exposé** : ✅ barrel `show` neutres uniquement ; signatures dialog/reader/adaptateur en `Object?` Delta JSON + `ZCodec` ; gates `quill_signature_isolation` / `flutter_quill_isolation_graph` verts.
- **Rétro-compat E6** : ✅ voie publique `ZMarkdownField({controller})` inchangée ; 155 tests E6 verts sans retouche.
- **Isolation AD-1** : ✅ `zcrud_core` intact ; `graph_proof` CORE OUT=0 ; aucune dépendance ajoutée.

**Décision** : findings tous LOW/nits — story peut passer `review → done` après consignation. Les LOW-1/LOW-3 (compléments de tests) et LOW-2 (dette l10n) sont **reportables et justifiés** (couverture effective + parité E6 assumée) ; corrigeables opportunément hors périmètre bloquant.

---

## Résolution (orchestrateur)

Verdict reviewer : **APPROUVÉ** — 0 HIGH / 0 MAJEUR / 0 MEDIUM. Vérif rejouée : analyze RC=0, `flutter test packages/zcrud_markdown` **174 tests** (155 E6 + 19 DP-3), graph CORE OUT=0, gates isolation Quill verts.

- **LOW-1/2/3/4 — CONSIGNÉS** (optionnels) : LOW-1 (test-vedette SM-1 via harnais bespoke plutôt que le dispatch registre — la frontière value-in-slice est répliquée fidèlement, risque faible) ; LOW-2 (chaînes UI FR en dur hors l10n — **dette l10n consignée**, cohérente avec la parité E6) ; LOW-3 (cas corrompu inline) ; LOW-4 (Semantics reader sans textField). À reprendre si besoin.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
