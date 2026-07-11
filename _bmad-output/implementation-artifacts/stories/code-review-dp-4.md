# Code Review — DP-4 : Champ HTML + `ZHtmlCodec` (parité DODLP, gap B5)

- **Story** : `_bmad-output/implementation-artifacts/stories/dp-4-champ-html-codec.md` (7 ACs)
- **Périmètre revu** : `zcrud_markdown` uniquement
- **Skill** : `bmad-code-review` (VRAI skill invoqué ; step-file architecture suivie)
- **Date** : 2026-07-11
- **Verdict** : ✅ **APPROVED** (0 HIGH, 0 MAJEUR, 0 MEDIUM ; 3 LOW/nits)

---

## Fichiers examinés (périmètre DP-4)

| Fichier | Rôle |
|---|---|
| `packages/zcrud_markdown/lib/src/data/z_html_codec.dart` | `ZHtmlCodec` (round-trip borné + défensif + table des pertes) |
| `packages/zcrud_markdown/lib/src/presentation/z_html_registration.dart` | `registerZHtmlFields`, kinds `html`/`inlineHtml` |
| `packages/zcrud_markdown/lib/src/data/delta_neutral_ops.dart` | helper `sanitizeEmbedsToPlaceholders` |
| `packages/zcrud_markdown/lib/zcrud_markdown.dart` | barrel (exports additifs) |
| `packages/zcrud_markdown/pubspec.yaml` | `vsc_quill_delta_to_html` + `flutter_quill_delta_from_html` |
| `test/z_html_codec_test.dart`, `test/z_html_registration_test.dart`, `test/conversion_libs_isolation_graph_test.dart` | tests |

Référence de conformité : `z_markdown_codec.dart` (modèle imité fidèlement).

---

## Vérifications rejouées RÉELLEMENT (RC réels)

| Vérif | Commande | RC | Résultat |
|---|---|---|---|
| Analyze package | `dart analyze packages/zcrud_markdown` | **0** | `No issues found!` |
| Tests package | `flutter test packages/zcrud_markdown` | **0** | **All tests passed — 219 tests** (+49 vs baseline 170, conforme AC7) |
| Graphe AD-1 | `python3 scripts/dev/graph_proof.py` | **0** | `ACYCLIQUE OK` / `CORE OUT=0 OK` (19 arêtes) |
| Dépendant barrel | `dart analyze packages/zcrud_mindmap` | **0** | `No issues found!` |
| Dépendant barrel | `dart analyze packages/zcrud_flashcard` | **0** | `No issues found!` |
| Compat E1-4 | `dart pub get --dry-run` | **0** | Résolution VERTE (`Would get dependencies`) — note informative « 31 packages have newer versions » (non bloquant) |
| Grep denylist (lib DP-4) | `grep -nE '<denylist>'` sur les 3 fichiers lib | — | 0 hit **effectif** (seuls hits = tokens `html_editor_enhanced`/WebView cités dans des **doc-comments** documentant la divergence AD volontaire ; le gate strip-comment du suite passe) |

---

## Revue adversariale ciblée (7 axes de l'orchestrateur)

### (1) AD-7 — codec HORS chemin chaud ✅
- `ZHtmlCodec` n'est invoqué qu'aux coutures `encode`/`decode` de persistance (`persistedValueOf`, seed, sync). Le champ HTML **réutilise à l'identique** `ZMarkdownField.fromContext` (DP-3), le seul delta étant le `codec` passé.
- **Preuve par test** (`z_html_registration_test.dart` AC4, `_CountingCodec`) : 100 frappes ⇒ `initA==1`, voisin non reconstruit, focus préservé, **identité `QuillController` stable**, tranche = **Delta neutre** (`c.valueOf('note')` est une `List`, pas une `String` HTML), codec appelé `< 100×`. La tranche porte du Delta ; le HTML n'apparaît qu'à `persistedValueOf(ZHtmlCodec)`.

### (2) Isolation des libs de conversion (AD-1/AD-7) ✅
- `vsc_quill_delta_to_html` / `flutter_quill_delta_from_html` importées **`as html_to` / `as html_from`**, cantonnées à `z_html_codec.dart`. Aucun type SDK (`QuillDeltaToHtmlConverter`, `HtmlToDelta`, `Delta`) n'apparaît dans une signature publique : `encode(List<Map<String,dynamic>>)→Object?`, `decode(Object?)→List<Map<String,dynamic>>`, `registerZHtmlFields(ZWidgetRegistry,{ZCodec?})` — 100 % neutres.
- `conversion_libs_isolation_graph_test.dart` **étendu** : (a) fermeture `zcrud_core` sans les libs HTML ; (b) contrôle positif — fermeture `zcrud_markdown` **contient** les 2 libs HTML ; (c) acyclicité. Gates `quill_signature_isolation_test.dart` + `flutter_quill_isolation_graph_test.dart` présents et verts (suite 219). Aucune dép `html_editor_enhanced`/`webview_flutter`/`flutter_html`.

### (3) Round-trip borné + défensif (AD-10) ✅
- `encode(const []) → ''` ; toute exception de conversion → `''` + `debugPrint` non-fatal (dans `assert`). `decode(null|''|'   '|42|'<not/valid'|[]|['x']) → []` **sans throw** (7 cas assertés). `List` legacy tolérée et normalisée via `DeltaNeutralOps`. HTML tronqué (`<p>texte`) récupéré en TEXTE (leniency HTML5, AD-10).
- **Perte BORNÉE** (HIGH-1 hérité) : embeds opaques → placeholder textuel `[embed:<kind>]` via `sanitizeEmbedsToPlaceholders` AVANT conversion ; texte environnant survit, document jamais vidé. Table des pertes **assertée** (code inline perdu, embeds LaTeX/table jamais ressuscités, texte préservé).

### (4) readOnly HTML ✅
- `field.readOnly==true` ⇒ délègue à `ZMarkdownReader(codec: ZHtmlCodec)` : 0 `QuillSimpleToolbar`, 0 bouton (`z-markdown-block-edit`/`z-markdown-fullscreen-toggle` absents), `readOnly==true`, `onChanged` jamais émis (`changes==0`), HTML corrompu ⇒ « Aucun contenu » sans exception.

### (5) a11y ≥48dp / thème FR-26 / secrets ✅
- a11y : `assertMinTapTarget(..., 48)` + `assertSemanticActionTap` sur toggle plein-écran et bouton édition block ; rendu RTL `html`+`inlineHtml` sans exception.
- Thème : 0 couleur/style codé en dur dans le neuf (grep effectif 0). `ZHtmlCodec` pur — aucun réseau, aucun `onImageUpload`, aucun secret (AD-16).

### (6) Aucune modif `zcrud_core` (AC6) ✅ (avec note)
- La **File List DP-4** est intégralement sous `packages/zcrud_markdown/**` ; aucun fichier cœur produit par cette story. Les types `html`/`inlineHtml` (enum + routage `registryOrFallback`) existaient déjà — aucune retouche cœur. Cf. LOW-3 pour la limite de vérification en working tree partagé.

### (7) AD-1 graphe inchangé ✅
- `graph_proof.py` : `CORE OUT=0`, acyclique. `zcrud_markdown → zcrud_core` uniquement.

---

## Findings

### HIGH
_Aucun._

### MAJEUR
_Aucun._

### MEDIUM
_Aucun._

### LOW / nits

- **LOW-1 — `z_html_registration_test.dart:310` : borne SM-1 codec `lessThan(100)` lâche.**
  L'assertion « codec appelé `< 100×` pour 100 frappes » passerait même à 99 appels (~1/frappe), donc ne prouve pas *à elle seule* que le codec est hors chemin chaud. La garantie SM-1 forte est portée par `initA==1` + identité `QuillController` + voisin non reconstruit (assertés). Conforme au libellé littéral de l'AC4 (« codec appelé <100× »). Remédiation optionnelle : resserrer à une petite constante (p. ex. `lessThan(3)`) pour durcir la preuve.

- **LOW-2 — `zcrud_markdown.dart:14` : export `z_html_codec.dart` sans `show`.**
  Contrairement aux exports de présentation (`show registerZHtmlFields`, `show ZMarkdownReader`…), le codec est ré-exporté sans `show`. Aucun leak aujourd'hui (les imports `as html_to`/`as html_from` ne sont pas ré-exportés par `export`, et la lib ne déclare que `ZHtmlCodec`), et c'est cohérent avec `z_delta_codec.dart`/`z_markdown_codec.dart`. Remédiation optionnelle : `show ZHtmlCodec` pour durcir contre un ajout futur.

- **LOW-3 — AC6 : gate « diff confiné à `zcrud_markdown` » non vérifiable en isolation.**
  Le working tree contient des modifs `zcrud_core` et autres packages issues des workstreams DP parallèles (DP-1/2/3…), donc `git diff --name-only` global n'est pas confiné. Ce n'est **pas** imputable à DP-4 (File List core-clean). Action : l'**orchestrateur** doit vérifier la confinement au gate de commit d'epic (par fichier), et rejouer `melos analyze`/`melos verify` repo-wide avant tout `done` (cf. règle NON-NÉGOCIABLE cross-package).

---

## Conclusion

Implémentation **fidèle et disciplinée**, calquée sur le modèle prouvé `ZMarkdownCodec` : signatures neutres, isolation AD-1 étendue et prouvée par graphe, décodage défensif AD-10 exhaustif, réutilisation stricte de l'infra rich-text DP-3 (SM-1/AD-2 intacts), table des pertes documentée + assertée. Les 7 ACs sont couverts et testés (219 tests verts, +49). Aucun finding bloquant ni MEDIUM.

**Verdict : APPROVED.** Les 3 LOW sont optionnels (aucun ne conditionne le `done`).
