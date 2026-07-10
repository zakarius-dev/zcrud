# Code Review — E6-3 · Embed LaTeX (`zcrud_markdown`)

- **Statut story** : review
- **Reviewer** : bmad-code-review (revue adversariale, effort high)
- **Skill** : `bmad-code-review` (invoqué via tool `Skill`, chemin pris = tool ; step-01 chargé)
- **Baseline** : `fe203b9` (frontmatter story) — l'epic E6 n'est pas encore committée : les fichiers `lib/src/{data,domain,presentation}/**` + `test/**` de `zcrud_markdown` sont **untracked** (commit en fin d'epic). Revue faite sur le **working tree réel** (contenu lu intégralement), pas sur un `git diff` (qui ne montre que barrel + pubspec).
- **Vérif verte** : confirmée par l'orchestrateur sur disque (`flutter analyze` RC=0 / 0 issue, `flutter test` RC=0 / 125 tests, `dart pub get --dry-run` RC=0, `graph_proof.py` CORE OUT=0 acyclique). Non re-rejouée ici (redondant).

## Périmètre lu

`z_latex_embed.dart`, `z_markdown_field.dart`, `delta_neutral_ops.dart`, `z_delta_codec.dart`, `z_markdown_codec.dart`, barrel, `pubspec.yaml` ; tests `z_latex_embed_test.dart`, `math_lib_isolation_graph_test.dart`, `quill_signature_isolation_test.dart`, `z_markdown_codec_test.dart`, `z_delta_codec_test.dart`, fixtures `rich_corpus.dart`.

## Verdicts (invariants clés)

| Invariant | Verdict | Preuve |
|---|---|---|
| **SM-1 non régressé — `embedBuilders` stable** | **OUI** | `_kLatexEmbedBuilders` = `const List<EmbedBuilder>` top-level (canonicalisée → instance UNIQUE) ; `QuillEditorConfig` RESTE `const` (le builder a un ctor `const`) ⇒ zéro allocation par build. `_toolbarConfig` = `late final` (construit 1× en initState). Chemin chaud `_onQuillChanged` **inchangé** (identique à E6-1). Test AC8 (100 frappes, seed AVEC embed) prouve réellement : `initA==1`, `identical(controller)`, `identical(buildersAfter, buildersBefore)`, `buildB`/`globalBuilds` figés, `focus.hasFocus`, `caret == end+100`. |
| **Isolation `flutter_math_fork` (AD-1)** | **OUI** | Dép au SEUL `zcrud_markdown/pubspec.yaml`. Gate graphe fermeture transitive : (a) `zcrud_core` sans la lib ; (b) contrôle positif `zcrud_markdown` la contient ; (c) acyclicité + out-degree zcrud_* du cœur = 0. Barrel n'exporte PAS `z_latex_embed`/`ZLatexEmbed` ; scan signature publique sans `Math`/`SelectableMath`/`MathStyle`/`FlutterMathException`. Tranche runtime = `List<Map>` JSON-safe (op embed = Map opaque). |
| **Codec E6-2 inchangé / op opaque** | **OUI** | `ZDeltaCodec`/`ZMarkdownCodec`/`DeltaNeutralOps` NON modifiés (aucun cas spécial `latex`). L'op `{insert:{latex:...}}` traverse `ZDeltaCodec` à l'identité (corpus `latex-type-embed`, `mixed-text+latex`) et devient `[embed:latex]` via le placeholder **générique** (`_embedPlaceholder` = 1re clé). Round-trip texte préservé (`avant`/`apres` survivent, embed non ressuscité). |
| **Défensif LaTeX invalide (AD-10)** | **OUI** | `build()` court-circuite AVANT `Math.tex` si `data is! String || trim().isEmpty` → placeholder ; malformé → `onErrorFallback` → placeholder (`error_outline`). Matrice réelle testée (`\frac{`, `''`, `null`, `42`) : `takeException()==null`, champ montable, LTR **et** RTL. |
| **Round-trip préservé** | **OUI** | `z_delta_codec_test` identité sur corpus incl. embed latex ; `z_markdown_codec_test` perte bornée `[embed:latex]`. |
| **Frontière E6-3 (LaTeX uniquement)** | **OUI** | Seule dép ajoutée = `flutter_math_fork ^0.7.4`. Aucune dép table (`flutter_tex`/`html_editor_enhanced`), aucun embed tableau, `zcrud_core` intact. |

## Findings

| # | Sévérité | Fichier:ligne | Résumé (1 ligne) |
|---|---|---|---|
| F1 | **MEDIUM** | `test/z_latex_embed_test.dart:88` | AC2 « rendu en **lecture** (`readOnly`) » n'est pas réellement exercé : seul un proxy (« un `EmbedBuilder` de clé `latex` est câblé ») est asserté, aucun rendu en mode readOnly. |
| F2 | **LOW** | `lib/src/presentation/z_latex_embed.dart:145` | Valider le dialogue avec un champ **vide** insère un embed `ZLatexEmbed('')` (placeholder d'erreur persistant) au lieu de traiter `''` comme une annulation. |
| F3 | **LOW** | `lib/src/presentation/z_latex_embed.dart:35` | Le label a11y du placeholder (`kLatexInvalidLabel` « formule invalide », requis AC9) n'est asserté par **aucun** test (le test a11y vérifie l'icône + la couleur, pas le `Semantics.label`). |
| F4 | **LOW/nit** | `lib/src/presentation/z_markdown_field.dart:497` | `final sel = _quill.selection;` est lu avant la branche `existing != null` où il n'est pas utilisé (lecture morte, sans effet). |
| F5 | **LOW/nit** | `lib/src/presentation/z_latex_embed.dart:69` | Édition d'un embed par **tap direct** sur la formule non implémentée (l'`EmbedBuilder` ne pose pas de `GestureDetector`) : seule la voie « caret adjacent + bouton toolbar » édite. AC3 (« tap/**bouton** ») reste satisfait par la voie bouton. |

### Détails

**F1 — MEDIUM (test-coverage vs AC2 explicite).**
AC2 exige un test widget montrant la formule rendue « en édition **ET en lecture** (`QuillController.readOnly == true` / champ en mode lecture) ». Le test `« les embedBuilders sont câblés (édition ET lecture, même config) »` (l. 88-106) n'assert que la présence d'un builder de clé `latex` dans la config — il **n'instancie jamais** un rendu readOnly. `ZMarkdownField` n'expose d'ailleurs aucun paramètre `readOnly`, donc le chemin lecture n'est ni atteignable ni couvert.
*Impact* : faible en pratique (les `embedBuilders` servent les deux modes via la même config), mais l'AC « lecture » n'est pas prouvée.
*Remède* : ajouter un test seedant l'op latex avec `QuillController.readOnly = true` (ou documenter que le mode lecture est hors périmètre du widget actuel et amender l'AC). Reporté justifiable car aucun risque de régression, mais à consigner.

**F2 — LOW.** `_submit() => Navigator.of(context).pop(_text.text);` renvoie la chaîne telle quelle. `_promptAndInsertLatex` ne rejette que `source == null` (annulation). Un OK sur champ vide insère donc un embed vide → placeholder d'erreur permanent dans le document. Cohérent avec « vide → placeholder » (AD-10) mais UX discutable.
*Remède* : traiter `text.trim().isEmpty` comme une annulation (`pop(null)`), ou ne pas muter si `source.trim().isEmpty`.

**F3 — LOW.** Ajouter `expect(find.bySemanticsLabel('formule invalide'), findsWidgets)` (ou via `SemanticsFinder`) dans le groupe AC9 pour verrouiller l'invariant a11y.

**F4 — LOW/nit.** Déplacer `final sel = _quill.selection;` dans la branche `else` (insertion) où il est effectivement utilisé.

**F5 — LOW/nit.** Optionnel : envelopper le rendu de l'embed d'un `GestureDetector`/`Semantics(button:true)` déclenchant `_promptAndInsertLatex` pré-rempli, pour une édition « tap » directe. Non requis (AC3 = « tap/bouton »).

## Points positifs notables

- `QuillEditorConfig` conservé **`const`** (via `_kLatexEmbedBuilders` const + ctor const du builder) : SM-1 réellement préservé, l'assertion `identical` du test le prouve (pas un proxy).
- Défensif à **deux niveaux** : court-circuit avant `Math.tex` (données non-`String`/vides) + `onErrorFallback` (malformé). Matrice réelle, `takeException()` null, RTL couvert. L'ajustement de test signalé (retirer l'assertion « pas de Math » sur le malformé car `Math.tex` rend son propre fallback) est **légitime** : l'invariant asserté reste le placeholder `error_outline`, pas un contournement.
- Cohérence E6-2 **irréprochable** : zéro ligne modifiée dans les codecs/`DeltaNeutralOps` ; l'op `latex` capté par le placeholder générique ; identité `ZDeltaCodec` prouvée sur le type canonique.
- Isolation : barrel propre, gate de graphe avec contrôle positif anti-faux-vert, tranche runtime JSON-safe vérifiée après insertion.
- Le déclenchement du bouton via `options.onPressed` réel (au lieu d'un hit-test de toolbar défilante) est la voie de production exacte — ajustement de test **légitime**, non un masquage.

## Recommandation

**Aucun finding HIGH/MAJEUR.** Les invariants critiques (SM-1, isolation AD-1, codec E6-2 opaque, défensif AD-10, round-trip, frontière) sont **tous tenus et prouvés par des tests réels**. F1 (MEDIUM) devrait être corrigé dans le périmètre (petit test readOnly) ou **justifié par écrit** avant `done` ; F2-F5 (LOW) optionnels. Story éligible à `done` après traitement de F1.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| F1 | MEDIUM | ✅ **corrigé** | Test rendu **readOnly RÉEL** : `QuillEditor` + `QuillController(readOnly:true)` câblé sur `ZLatexEmbedBuilder` + document latex → `controller.readOnly==true` ET `find.byType(Math) findsWidgets` (plus un proxy). |
| F2 | LOW | ✅ corrigé | Dialogue OK sur saisie vide/blanche (`trim().isEmpty`) → annulation (`pop(null)`), aucun embed vide inséré. Test vide + `'   '`. |
| F3 | LOW | ✅ corrigé | Test AC9 : placeholder d'erreur porte `Semantics.label == kLatexInvalidLabel`. |
| F4 | LOW/nit | ✅ corrigé | Lecture morte `sel` déplacée dans la branche insertion. |
| F5 | LOW/nit | 🟡 documenté | Édition par tap direct hors périmètre (garde l'embed const sans état, SM-1) ; ré-édition via bouton toolbar. |

**Vérif verte rejouée (orchestrateur, ciblée zcrud_markdown)** : `flutter analyze` **0 issue** · `flutter test` **128/128** (125→128, +3 : readOnly, cancel-sur-vide, label a11y) · **CORE OUT=0** · dry-run OK. SM-1 non régressé.

**Verdict final** : 1 MEDIUM + 4 LOW traités. Story E6-3 → **done**.
