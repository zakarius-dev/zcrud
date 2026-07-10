# Story 6.2: `ZCodec` pluggable (Delta / Markdown / HTML)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrateur zcrud (DODLP, lex_douane)**,
I want **un `ZCodec` pluggable qui (dé)sérialise le contenu rich-text de/vers un format persisté choisi par l'app (Delta / Markdown / HTML), pendant que l'éditeur continue de travailler en Delta neutre**,
so that **je décide moi-même du format stocké (Markdown lisible, HTML, ou Delta JSON) sans verrouiller le moteur, avec un round-trip fidèle et un décodage défensif qui ne casse jamais sur un contenu legacy/corrompu**.

## Contexte & valeur (AD-7 / SM-4)

E6-1 a livré `ZMarkdownField` (`zcrud_markdown`) : un éditeur Quill à controller **isolé**, scellé sur **sa seule tranche** du `ZFormController`, portant une **valeur neutre Delta JSON** (`List<Map<String, dynamic>>`). La conversion Delta↔JSON y est **minimale et interne** (API native Quill `Document.fromJson` / `document.toDelta().toJson()`). Le champ **ne choisit PAS encore de format persisté** — il stocke du Delta JSON brut. C'est précisément l'**incohérence** que **AD-7** veut corriger (« le champ `markdown` persistant du Delta JSON »).

**E6-2** introduit l'abstraction **`ZCodec`** : l'éditeur reste en **Delta interne**, mais la **(dé)sérialisation du format persisté** passe par un codec **pluggable** (Delta / Markdown / HTML), **choisi par l'app** (AD-7). Le **round-trip est prouvé** sur un corpus réel (listes imbriquées, entités HTML, cas embeds) avec **pertes documentées** selon le format (SM-4). Le décodage reste **défensif** (AD-10) : un format persisté corrompu / vide / legacy → Delta vide, **jamais** de throw. Toute lib de conversion vit au **seul** pubspec de `zcrud_markdown` (AD-1) et **aucun** type de conversion ne fuit dans une signature publique neutre.

> **Frontière E6-2 (stricte)** : E6-2 = **`ZCodec` pluggable UNIQUEMENT**. L'embed **LaTeX** = E6-3, l'embed **tableau** = E6-4. Les embeds sont traités ici comme des **ops Delta opaques** qui traversent le round-trip (fidélité totale via `ZDeltaCodec` ; bornée et documentée via `ZMarkdownCodec`).

## Acceptance Criteria

1. **AC1 — Abstraction `ZCodec` définie dans `zcrud_markdown`.** Une interface publique `ZCodec` (`lib/src/domain/`) expose exactement deux opérations sur la **valeur neutre Delta JSON** (`List<Map<String, dynamic>>` = ops Delta) et une **représentation persistée** neutre (`Object?`, typiquement `String`) :
   - `Object? encode(List<Map<String, dynamic>> deltaOps)` — Delta ops → format persisté ;
   - `List<Map<String, dynamic>> decode(Object? persisted)` — format persisté → Delta ops.
   La signature n'emploie **aucun** type Quill (`Document`/`Delta`) ni type d'une lib de conversion (`markdown`/`html`) — uniquement `Object?`, `String`, `List<Map<String, dynamic>>`, `Map<String, dynamic>`. Documenté au barrel (exporté).

2. **AC2 — `ZDeltaCodec` round-trip IDENTITÉ (sans perte).** Un codec `ZDeltaCodec` (format persisté = Delta JSON, la voie interne d'E6-1) vérifie `decode(encode(ops)) == ops` **exactement** sur un corpus représentatif : texte simple, gras/italique, listes **imbriquées**, liens, code, blockquote, **et ops embed opaques** (attributs custom simulant LaTeX/tableau). Sérialisation persistée = `String` JSON canonique **ou** `List` Delta (contrat documenté). Round-trip **bit-à-bit** sémantique (`jsonDecode(jsonEncode(x)) == x`).

3. **AC3 — `ZMarkdownCodec` round-trip sur corpus RÉEL + pertes documentées (SM-4).** Un codec `ZMarkdownCodec` (Delta↔Markdown) vérifie la **préservation sémantique** sur un corpus réel : titres (H1–H3), gras/italique, **listes imbriquées** (≥2 niveaux), liens, `code` inline + blocs, blockquote, entités HTML dans le texte. Les **pertes attendues** (attributs non exprimables en Markdown : couleur, police, alignement, embeds LaTeX/tableau non-MD) sont **documentées ET assertées** par un test « table des pertes » (round-trip qui perd → assertion explicite de la perte, jamais un throw). `encode`/`decode` sont **inverses au sens du sous-ensemble Markdown**, pas bit-à-bit.

4. **AC4 — Codec injecté / sélectionné par l'app (défaut rétrocompatible).** Le codec est choisi par l'app **sans toucher `zcrud_core`** :
   - défaut **`ZDeltaCodec`** → comportement **strictement identique** à E6-1 (aucune régression quand aucun codec n'est fourni) ;
   - override explicite via le paramètre `ZMarkdownField({... ZCodec? codec})` ;
   - et/ou défaut d'app via un `ZMarkdownCodecScope` (InheritedWidget **interne à `zcrud_markdown`**) résolu par `ZMarkdownCodecScope.of(context)`.
   **Précédence** : paramètre du champ > `ZMarkdownCodecScope` > `ZDeltaCodec`. Prouvé par test (les trois cas + précédence).

5. **AC5 — Décodage défensif (AD-10) : jamais de throw.** `decode(...)` d'une valeur `null` / vide (`''`, `[]`) / **corrompue** (JSON tronqué, op sans `insert`, op non-`Map`, type inattendu) / **legacy** (Markdown mal formé, HTML partiel) retourne des **ops Delta vides** (`[]`) — **jamais** de throw (log non-fatal en debug uniquement). Un `ZMarkdownField` seedé depuis une telle valeur affiche un **document vide utilisable** (parité stricte avec `_decodeDefensive` d'E6-1). Symétriquement `encode([])` → persisté vide (`''` MD/HTML, ou `[]`/`'[]'` Delta) sans throw.

6. **AC6 — Le champ délègue la (dé)sérialisation au codec à sa couture, la tranche reste NEUTRE.** Contrat clarifié et testé :
   - la **valeur de la tranche `ZFormController` pendant l'édition reste le Delta JSON neutre** (`List<Map>`), **inchangée** d'E6-1 (AD-2 préservé, chemin chaud intact) ;
   - au **seed**, `ZMarkdownField` accepte une valeur initiale qui peut être **soit** du Delta JSON (List) **soit** le **format persisté du codec** (ex. `String` Markdown) et la **normalise en Delta ops via `codec.decode`** (puis via le décodage défensif existant) ;
   - le champ expose au host la valeur persistée via `codec.encode` (méthode/hook d'accès documenté) — c'est la voie par laquelle l'app persiste le **format choisi** dans son modèle (`toMap`/`fromMap`).
   Le contrat « tranche = Delta neutre ; persistance = format du codec » est **écrit** dans la doc du champ et **prouvé** (avec `ZDeltaCodec`, persisté == tranche ; avec `ZMarkdownCodec`, persisté == `String` Markdown, tranche == Delta JSON).

7. **AC7 — Isolation des libs de conversion (gate AD-1).** Toute lib de conversion (`markdown`, converter Delta↔Markdown, éventuelles libs HTML) est déclarée au **SEUL** pubspec de `zcrud_markdown`. Un test de **graphe par fermeture transitive** (miroir de `flutter_quill_isolation_graph_test.dart`) prouve : (a) la closure de `zcrud_core` **ne contient AUCUNE** lib de conversion ; (b) **contrôle positif** : la closure de `zcrud_markdown` **contient** la lib de conversion (anti-faux-vert) ; (c) acyclicité `zcrud_markdown → zcrud_core` maintenue, out-degree zcrud_* du cœur = 0.

8. **AC8 — Aucun type de conversion ne fuit (signature + runtime).** Le barrel n'exporte **aucun** symbole `flutter_quill` ni de lib de conversion ; la surface **publique** de `ZCodec` et de `ZMarkdownField` ne mentionne **aucun** nom de type `Document`/`Delta`/`markdown`/`html` (scan statique). Runtime : la valeur persistée retournée par `encode` est une `String` (MD/HTML) **ou** une `List`/`String` (Delta) — jamais un type Quill/lib ; la tranche reste `List<Map<String, dynamic>>` neutre (scan statique + assertion runtime, miroir de `quill_signature_isolation_test.dart`).

9. **AC9 — Frontière E6-2 respectée (pas d'anticipation E6-3/E6-4).** Aucun rendu/édition d'embed LaTeX (E6-3) ni tableau (E6-4) n'est introduit. Les ops embed opaques **traversent** le round-trip : **fidélité totale** via `ZDeltaCodec` (assertée), **bornée + documentée** via `ZMarkdownCodec` (perte assertée dans la table des pertes AC3). Aucune dépendance `flutter_math_fork`/table lib ajoutée.

10. **AC10 — SM-1 / AD-2 non régressés par le codec.** Avec un codec non-défaut (`ZMarkdownCodec`) fourni, taper **100 caractères un par un** ne reconstruit **que** le champ courant (compteur de build de la tranche == frappes ; voisin figé ; `QuillController` jamais recréé — `init == 1`, `identical`), **zéro perte de focus / sélection** (caret conservé au point d'insertion). Le codec **n'intervient pas** dans le chemin chaud de frappe (encodage persistant uniquement à la couture de persistance, pas à chaque frappe). Réutilise le harnais de test SM-1 d'E6-1.

## Tasks / Subtasks

- [x] **Task 1 — Interface `ZCodec` + barrel (AC1, AC8).**
  - [x] Créer `lib/src/domain/z_codec.dart` : `abstract interface class ZCodec` avec `encode(List<Map<String,dynamic>>) -> Object?` et `decode(Object?) -> List<Map<String,dynamic>>` ; doc du contrat neutre (aucun type Quill/lib), doc « pertes selon format ».
  - [x] Exporter depuis `lib/zcrud_markdown.dart` (barrel) ; conserver l'isolation (aucun re-export Quill/conversion).
- [x] **Task 2 — `ZDeltaCodec` (identité) (AC2, AC5, AC9).**
  - [x] `lib/src/data/z_delta_codec.dart` : `encode` = ops → `String` JSON canonique ; `decode` = réutilise/partage la **normalisation défensive** d'E6-1 (`DeltaNeutralOps.decodeDefensiveOps`) → `[]` sur corrompu.
  - [x] Factoriser la normalisation défensive Delta (auparavant privée dans `z_markdown_field.dart`) dans un util partagé (`lib/src/data/delta_neutral_ops.dart`) **sans changer** le comportement d'E6-1 (le champ le consomme).
- [x] **Task 3 — `ZMarkdownCodec` (Delta↔Markdown) (AC3, AC5, AC9).**
  - [x] Ajout `markdown ^7.2.2` + `markdown_quill ^4.3.0` au pubspec `zcrud_markdown` ; **compat vérifiée** (dry-run VERT, cf. Completion Notes) : lib RÉELLE retenue (pas de convertisseur interne).
  - [x] `lib/src/data/z_markdown_codec.dart` : `encode` = ops → `Delta` (interne) → Markdown `String` ; `decode` = Markdown `String` → ops ; **défensif** (Markdown mal formé/vide → `[]`/pas de throw).
  - [x] **Table des pertes** (attributs non-MD) documentée dans la doc de classe.
- [x] **Task 4 — Sélection/injection du codec (AC4).**
  - [x] Paramètre optionnel `ZCodec? codec` sur `ZMarkdownField`.
  - [x] `ZMarkdownCodecScope` (InheritedWidget **dans `zcrud_markdown`**) + `of`/`maybeOf` ; `ZcrudScope` (core) NON touché.
  - [x] Résolution : `widget.codec ?? ZMarkdownCodecScope(...) ?? const ZDeltaCodec()` (lecture scope sans dépendance en `initState`).
- [x] **Task 5 — Couture de (dé)sérialisation dans `ZMarkdownField` (AC6, AC10).**
  - [x] Seed (`initState`) : `codec.decode(valueOf(name))` → ops → `decodeDefensiveDocument` → `Document`. Tranche **reste** Delta neutre ; chemin chaud **inchangé** (aucun codec par frappe).
  - [x] Voie de persistance exposée via `debugPersistedValue = codec.encode(encodeNeutral(document))` (hook host `toMap`).
  - [x] `_syncFromExternal` rendu codec-aware **hors focus** (accepte tranche Delta OU format persisté) ; chemin chaud intact ; non-régression SM-1 prouvée avec `ZMarkdownCodec`.
- [x] **Task 6 — Tests round-trip sur corpus réel (AC2, AC3, AC5, AC9).**
  - [x] Corpus partagé (`test/fixtures/rich_corpus.dart`) : simple, gras/italique, titres, listes imbriquées ≥2 niveaux, liens, code inline+bloc, blockquote, entités HTML, **ops embed opaques** (LaTeX + tableau).
  - [x] `ZDeltaCodec` : round-trip identité (`==` / `jsonEncode`).
  - [x] `ZMarkdownCodec` : round-trip sémantique + **table des pertes** assertée (couleur/embeds perdus).
  - [x] Défensif : matrices `null`/vide/corrompu/legacy → `[]`/`returnsNormally`.
- [x] **Task 7 — Gates d'isolation & signature (AC7, AC8).**
  - [x] Nouveau `conversion_libs_isolation_graph_test.dart` : `markdown`/`markdown_quill` **absents** de la closure `zcrud_core`, **présents** dans `zcrud_markdown` (contrôle positif).
  - [x] `quill_signature_isolation_test.dart` étendu : surface publique `ZCodec`/barrel sans type Quill/lib ; runtime `encode` → `String`, `decode` → `List<Map>` neutre.
- [x] **Task 8 — Vérif verte + doc.** `analyze` RC=0 (0 issue) → `flutter test` RC=0 (99 tests) → `dart pub get --dry-run` RC=0 ; doc de classe `ZMarkdownField` MAJ (contrat tranche=Delta neutre / persistance=codec) ; frontière E6-3/E6-4 notée.

## Dev Notes

### Décision de contrat (résout l'ambiguïté centrale)

> **Question ouverte détectée** : « la valeur PERSISTÉE dans la tranche devient-elle le format du codec (String Markdown/HTML), OU la tranche reste-t-elle Delta JSON ? »
>
> **Résolution retenue (à implémenter telle quelle)** : **la tranche `ZFormController` reste TOUJOURS le Delta JSON neutre** (représentation de travail, inchangée d'E6-1) ; **le `ZCodec` transforme à la couture de PERSISTANCE** (modèle/`toMap`/`fromMap`), **hors** de la tranche.
> - Avec `ZDeltaCodec` : persisté == tranche (Delta JSON) → aucune transformation → **rétrocompat E6-1 exacte**.
> - Avec `ZMarkdownCodec` : persisté == `String` Markdown, tranche == Delta JSON → transformation à la couture.
>
> **Pourquoi** : préserver **intactes** les invariants AD-2 prouvés d'E6-1 (focus/sélection, `QuillController` jamais recréé, chemin chaud O(bon marché)), et coller à la lettre d'AD-7 (« la **(dé)sérialisation du format persisté** passe par un `ZCodec` »). Faire varier la tranche par codec ré-ouvrirait le décodage défensif du chemin chaud et menacerait SM-1. Le champ « délègue au codec » **au seed et à la persistance**, pas à chaque frappe.

### État réel du point d'intégration (à lire AVANT de coder)

`packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` (E6-1, **done**) :
- **Ce qu'il fait aujourd'hui** : `initState` → `valueOf(name)` → `_decodeDefensive` (`Object? → Document`, jamais de throw) → `QuillController` unique. Frappe → `_onQuillChanged` → `_encodeNeutral(document)` (`List<Map<String,dynamic>>`) → `setValue(name, neutral)` (sens unique, dédup, garde `_applyingExternal`). Sync guardée `_syncFromExternal` **hors focus** uniquement.
- **Ce que E6-2 change** : (a) résolution d'un `ZCodec` (param > scope > `ZDeltaCodec`) ; (b) `initState` seed via `codec.decode(...)` **avant** `_decodeDefensive` ; (c) exposer `codec.encode(...)` comme voie de persistance host. **Rien d'autre.**
- **Ce qui DOIT être préservé (non-négociable)** : `QuillController`/`FocusNode`/`ScrollController` créés une fois / disposés ; abonnement `document.changes` (MED-1 d'E6-1 : n'émet que sur contenu) annulé au dispose et **ré-abonné** après remplacement de document ; sens unique ; dédup `_lastValueJson` ; sync guardée hors focus ; RTL/thème/a11y (AD-13). **Ne pas** introduire d'encodage codec dans `_onQuillChanged` (chemin chaud).
- **Réutiliser, ne pas réimplémenter** : `_decodeDefensive`, `_asDeltaOps`, `_encodeNeutral` (les factoriser dans `lib/src/data/` en util partagé consommé par `ZDeltaCodec` **et** le champ, sans changer le comportement).

### Learnings absorbés (E5 / E6-1)

- **Round-trip prouvé sur cas RÉELS** (pas de proxy) : E6-1 a validé 9 cas défensifs réels (`null`, `[]`, `{}`, JSON tronqué, string vide/non-JSON, op non-Map, op sans `insert`, nombre brut) → doc vide, `takeException()` null. **Reproduire ce niveau d'exigence** pour `decode` de chaque codec (matrice réelle, `returnsNormally`).
- **Pas de fuite de type** : E6-1 prouve la neutralité par **scan statique** (barrel + région publique) **et** **runtime** (`isA<List<Map<String,dynamic>>>` + `isNot(isA<Document>())`). Étendre à `ZCodec` (persisté `String`/`List`, jamais `Document`/`Delta`).
- **Gate de graphe par fermeture transitive** (`dart pub deps --json`, fallback local honnête) avec **contrôle positif** anti-faux-vert : réutiliser exactement ce patron pour la/les lib(s) de conversion.
- **MED-1 (efficacité)** : ne pas sérialiser sur simple déplacement de curseur — le codec ne doit **jamais** entrer dans le flux `document.changes`.
- **Frontière stricte** : E6-1 n'a rien anticipé d'E6-2/3/4 ; E6-2 ne doit rien anticiper d'E6-3/E6-4 (embeds = ops opaques).

### Invariants d'architecture applicables (AD)

- **AD-7** — Delta interne ; (dé)sérialisation du format persisté via `ZCodec` **pluggable** choisi par l'app ; round-trip testé.
- **AD-1** — `zcrud_core` sans lib de conversion ; lib au **seul** pubspec `zcrud_markdown` ; arête sortante zcrud_* = `zcrud_core` uniquement ; acyclicité préservée.
- **AD-10** — décodage **défensif** systématique : format corrompu/vide/legacy → Delta vide, jamais de throw ; évolution additive.
- **AD-2** — chemin chaud de frappe intact (le codec n'y entre pas) ; controller stable ; sens unique ; sync guardée hors focus.
- **AD-13** — RTL/thème/a11y du champ préservés (aucun changement de rendu attendu).

### Impact `zcrud_core` — **NON**

**`ZCodec` vit ENTIÈREMENT dans `zcrud_markdown`** (aucune modification de `zcrud_core`). Rationale : le codec est **spécifique au rich-text** (concept Delta/Markdown/HTML) et le champ qui le consomme vit dans `zcrud_markdown` ; garder `zcrud_core` **libre** de tout concept Quill/Delta/conversion (AD-1). La sélection d'app passe par un `ZMarkdownCodecScope` **local** au package, **pas** par `ZcrudScope` (core) → **zéro** couplage nouveau au cœur, **zéro** séquençage vs E11a/EX-2 (packages disjoints). *Note pour l'orchestrateur* : E8-1 (« entités exposées via `ZCodec` ») consommera ce `ZCodec` **au niveau app** (l'app dépend de `zcrud_markdown`) — pas besoin d'un port neutre dans `zcrud_core` pour le MVP. **Si** un futur besoin imposait un port `ZCodec` neutre dans `zcrud_core`, ce serait une **story distincte** à séquencer (hors E6-2).

### Libs de conversion — choix & versions

- **`markdown`** (dart-lang) `^7.2.2` — parsing Markdown → AST (base de la voie MD→Delta). Dart pur, mainteneur officiel.
- **Convertisseur Delta↔Markdown** : préférence **`markdown_quill`** `^4.x` (bidirectionnel, s'appuie sur `markdown` + `dart_quill_delta`). **Contrainte de compatibilité à vérifier au dev** : `markdown_quill` doit accepter la version de `dart_quill_delta` tirée par `flutter_quill 11.5.1` (E6-1). **Si incompatibilité de résolution** (`dart pub get --dry-run` rouge) → **implémenter un convertisseur interne borné** (sous-ensemble MD : titres, gras/italique, listes imbriquées, liens, code, blockquote) dans `lib/src/data/`, **sans** lib incompatible. Décision et version exacte **figées et justifiées** dans le fichier story lors du dev (frontmatter/notes).
- **HTML (`ZHtmlCodec`) — OPTIONNEL pour E6-2.** Markdown est prioritaire (nom du package). Si le temps le permet et la compat OK : `vsc_quill_delta_to_html ^1.0.x` (Delta→HTML) + `flutter_quill_delta_from_html ^1.x` (HTML→Delta), **isolés** au pubspec `zcrud_markdown`. **Sinon** : `ZHtmlCodec` reporté (justifié) — les **entités HTML** du corpus SM-4 restent couvertes en tant que **contenu texte** round-trippé par `ZMarkdownCodec`, pas comme codec HTML dédié. Le report éventuel d'un `ZHtmlCodec` ne bloque **aucun** AC obligatoire (AC3 exige Markdown + entités HTML dans le texte, pas un codec HTML).

> ⚠️ **Ne PAS** committer les `pubspec.lock` de package ni les `*.g.dart` (gitignorés). Toute nouvelle dépendance : **uniquement** `zcrud_markdown/pubspec.yaml` (AD-1).

### Stratégie de tests

- **Round-trip (SM-4)** : corpus réel partagé (`test/fixtures/`) couvrant listes imbriquées, entités HTML, ops embed opaques, formats riches. `ZDeltaCodec` → identité (`==`). `ZMarkdownCodec` → sémantique + **table des pertes** assertée (chaque perte attendue = assertion explicite, jamais un throw).
- **Défensif (AD-10)** : matrice réelle (`null`, `''`, `[]`, JSON tronqué, op sans `insert`, op non-Map, Markdown/HTML mal formé, type inattendu) → `decode` retourne `[]`, `returnsNormally`.
- **Sélection codec (AC4)** : param seul ; scope seul ; param **et** scope (param gagne) ; ni l'un ni l'autre (`ZDeltaCodec`).
- **Isolation graphe (AC7)** : fermeture transitive `dart pub deps --json` + fallback local + **contrôle positif**.
- **Signature (AC8)** : scan statique barrel + surface publique ; runtime `encode`/tranche neutres.
- **SM-1/AD-2 (AC10)** : réutiliser le harnais 100-frappes d'E6-1 **avec** `ZMarkdownCodec` fourni → build tranche == frappes, voisin figé, `init==1`, focus/sélection conservés.
- **Frontière (AC9)** : ops embed opaques → identité via `ZDeltaCodec`, perte documentée via `ZMarkdownCodec` ; aucune dépendance LaTeX/table ajoutée.

### Project Structure Notes

- **Fichiers NEW** (tous sous `packages/zcrud_markdown/`) : `lib/src/domain/z_codec.dart`, `lib/src/data/z_delta_codec.dart`, `lib/src/data/z_markdown_codec.dart`, `lib/src/data/delta_neutral_ops.dart` (util défensif factorisé), `lib/src/presentation/z_markdown_codec_scope.dart` ; tests `test/z_delta_codec_test.dart`, `test/z_markdown_codec_test.dart`, `test/z_codec_selection_test.dart`, `test/conversion_libs_isolation_graph_test.dart`, `test/fixtures/rich_corpus.dart`.
- **Fichiers UPDATE** : `lib/zcrud_markdown.dart` (barrel : + `ZCodec`, codecs, scope), `lib/src/presentation/z_markdown_field.dart` (résolution codec + seed/persistance via codec ; **chemin chaud inchangé**), `pubspec.yaml` (lib conversion), `test/quill_signature_isolation_test.dart` + `test/flutter_quill_isolation_graph_test.dart` (étendus). **Aucun** fichier hors `packages/zcrud_markdown/` (parallélisation E11a/EX-2 préservée). **Zéro** modif `zcrud_core`.
- **Naming** (conventions zcrud) : types `Z*` (`ZCodec`, `ZDeltaCodec`, `ZMarkdownCodec`, `ZHtmlCodec`, `ZMarkdownCodecScope`) ; fichiers snake_case ; API publique = barrel, impl sous `lib/src/{domain,data,presentation}`.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E6] — Story E6-2 (AC : Delta interne ; format persisté par défaut documenté, surchargeable par codec ; round-trip listes imbriquées/formules/tables/entités HTML) ; frontière E6-3 (LaTeX) / E6-4 (tableau).
- [Source: architecture.md#AD-7] — Delta interne + `ZCodec` pluggable choisi par l'app ; round-trip testé ; controller isolé (AD-2). SM-4 = round-trip du format persisté.
- [Source: architecture.md#AD-1] — `zcrud_core` sans lib lourde ; satellite → core uniquement ; acyclicité.
- [Source: architecture.md#AD-10] — désérialisation défensive systématique ; format corrompu/legacy → parent jamais cassé.
- [Source: architecture.md#AD-2] — chemin chaud granulaire, controller stable, sens unique.
- [Source: packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart] — point d'intégration E6-1 (`_decodeDefensive`, `_asDeltaOps`, `_encodeNeutral`, `_onQuillChanged`, `_syncFromExternal`).
- [Source: _bmad-output/implementation-artifacts/stories/code-review-e6-1.md] — learnings : round-trip réel, anti-fuite, gate de graphe + contrôle positif, MED-1 (pas de sérialisation sur sélection).
- [Source: packages/zcrud_markdown/test/flutter_quill_isolation_graph_test.dart, quill_signature_isolation_test.dart] — patrons de gate à réutiliser/étendre.
- [Source: CLAUDE.md] — `zcrud_markdown` = Quill + `ZCodec` + embeds ; Key Don'ts (pas de lib lourde dans le cœur, pas de fuite de type, barrel).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, effort high).

### Debug Log References

- `dart pub get --dry-run` (racine workspace) → RC=0, « No dependencies would change » ⇒ **gate compat E1-4 VERT** après ajout `markdown`/`markdown_quill`.
- Résolution figée (`pubspec.lock` racine) : `flutter_quill 11.5.1`, `markdown_quill 4.3.0`, `dart_quill_delta 10.8.3`, `markdown 7.3.1`.
- `flutter analyze` (zcrud_markdown) → RC=0, **0 issue**.
- `flutter test` (zcrud_markdown) → RC=0, **99 tests** verts.
- Sondage empirique `markdown_quill` (valeurs de référence des assertions) : gras `**x**`, titres `# / ## / ###`, liste imbriquée indentée, code fencé, blockquote `>`, couleur **perdue**, embed `formula` → `DeltaToMarkdown` throw (capté défensivement → `''`).

### Completion Notes List

- **Choix lib de conversion (preuve à l'appui)** : **lib RÉELLE `markdown_quill 4.3.0`** retenue (PAS de convertisseur interne). `markdown_quill` exige `flutter_quill ^11.0.0` (satisfait par notre `^11.5.0`) et `markdown ^7.2.1` ; `dart_quill_delta ^10.x` (tiré par flutter_quill) compatible. `dart pub get --dry-run` **VERT** ⇒ aucun risque pour le workspace (E1-4). Décision et versions figées ci-dessus.
- **Contrat clé (tranche = Delta neutre)** : la tranche `ZFormController` reste TOUJOURS le Delta JSON neutre pendant l'édition. Le `ZCodec` opère **uniquement** au seed (`decode`) et à la persistance (`encode` via `debugPersistedValue`). Le chemin chaud de frappe (`_onQuillChanged`) n'appelle JAMAIS le codec (MED-1/SM-1 préservés). `_syncFromExternal` est devenu codec-aware **mais reste gardé hors focus** ⇒ hors chemin chaud ; pour `ZDeltaCodec` (défaut) `decode` est l'identité défensive ⇒ **parité E6-1 stricte** (99 tests, dont ceux d'E6-1, verts).
- **Round-trip SM-4 prouvé** : `ZDeltaCodec` = **identité** (`jsonEncode(decode(encode(ops)))==jsonEncode(ops)`) sur 12 cas réels dont embeds opaques (LaTeX + tableau) ; `ZMarkdownCodec` = préservation sémantique du sous-ensemble MD + **table des pertes assertée** (couleur perdue ; embeds LaTeX/tableau perdus, sans throw — AC9).
- **Isolation (AC7/AC8)** : `markdown`/`markdown_quill` absents de la fermeture transitive `zcrud_core`, présents dans `zcrud_markdown` (contrôle positif anti-faux-vert) ; barrel + surface publique `ZCodec` sans nom de type Quill/lib ; runtime `encode → String`, `decode → List<Map>`. `melos list = 14`, out-degree zcrud_* du cœur = 0.
- **Impact `zcrud_core` = NON** : aucune modification hors `packages/zcrud_markdown/` (seul le `pubspec.lock` **racine** du workspace bouge, conséquence inévitable de l'ajout de deps à un membre — à committer en fin d'epic par l'orchestrateur).
- **`ZHtmlCodec` reporté (justifié)** : OPTIONNEL par la story (Dev Notes « Libs de conversion »). Markdown est prioritaire (nom du package) et couvre AC3 (Markdown + entités HTML **en tant que texte**). Aucun AC obligatoire ne dépend d'un codec HTML dédié ⇒ report sans impact. À planifier en story distincte si un format HTML persisté devient requis.
- **Frontière E6-3/E6-4 respectée** : aucun rendu/édition d'embed LaTeX ni tableau ; embeds traités comme ops Delta opaques (fidélité totale via `ZDeltaCodec`, perte bornée documentée via `ZMarkdownCodec`). Aucune dépendance `flutter_math_fork`/table ajoutée.

### Remédiation code-review (2026-07-10) — findings HIGH-1 / MEDIUM-1 / LOW

- **HIGH-1 (perte de données TOTALE → BORNÉE) — CORRIGÉ** : `DeltaNeutralOps.toDeltaForMarkdown` remplace désormais chaque `insert` **embed** opaque (Map — LaTeX E6-3 / tableau E6-4) par un **placeholder textuel** `[embed:<type>]` AVANT `DeltaToMarkdown().convert(...)`. L'embed inconnu ne fait plus throw la conversion, donc un embed AU MILIEU du texte ne vide plus le document ENTIER : le texte environnant SURVIT, seul l'embed dégrade (perte réellement **bornée**, AC9). Table des pertes de `ZMarkdownCodec` réécrite en conséquence (« embed → placeholder, texte environnant préservé »). Test RÉEL ajouté (`z_markdown_codec_test.dart` : `texte + embed LaTeX + texte + embed tableau`) : Markdown **jamais vide**, contient les 2 segments de texte + un marqueur par embed, aucun embed opaque ne ressuscite au round-trip.
- **MEDIUM-1 (voie de persistance = membre `@visibleForTesting` + type de tranche incohérent) — CORRIGÉ** :
  - (a) **Voie de persistance PUBLIQUE non-debug** : nouvelle API statique `ZMarkdownField.persistedValueOf(controller, name, {codec})` que le `toMap`/`onSubmit` de l'app appelle — plus aucun besoin du membre `@visibleForTesting` `debugPersistedValue` (dont la doc ne le présente plus comme voie de persistance). L'API `decode` DÉFENSIVEMENT la tranche PUIS `encode` ⇒ **robuste** au type de tranche (Delta neutre `List<Map>` OU seed `String` non normalisé) : plus de `TypeError` sur `encode(String)`.
  - (b) **Tranche normalisée dès le montage** : `initState` écrit la forme Delta neutre canonique du seed (`setValue`, en POST-FRAME) lorsque le seed est au format persisté `String` ⇒ le TYPE de tranche est INVARIANT (`List<Map>`) avant ET après la 1re frappe. Un seed déjà en Delta neutre (défaut `ZDeltaCodec` / parité E6-1) ou vide/corrompu n'est PAS retouché (aucune régression E6-1, aucun re-seed superflu — vérifié : SM-1, MED-1, défensif AD-10, cycles de vie tous verts).
  - Tests ajoutés (`z_markdown_field_codec_test.dart`) : tranche `List<Map>` dès le montage (sans frappe) + `persistedValueOf` encode le Markdown attendu ; robustesse `persistedValueOf` sur seed `String` non normalisé (aucun throw).
- **LOW-1 (swap de codec de scope non propagé) — DOCUMENTÉ** : comportement intentionnel (résolution du codec une fois en `initState`, config de persistance statique). Note explicite ajoutée sur `ZMarkdownCodecScope` (codec stable au montage ; remonter les champs pour un changement effectif). Pas de re-résolution `didChangeDependencies` (éviterait un re-seed à chaud incompatible avec le contrat tranche-de-travail).
- **LOW-2 (`ZMarkdownCodecScope.of` : null-check nu en release) — CORRIGÉ** : lève désormais une `FlutterError` descriptive (`ErrorSummary`/`ErrorDescription`/`ErrorHint`) au lieu de `codec!` (assert désactivé en release).
- **Vérif verte rejouée (CIBLÉE zcrud_markdown)** : `flutter analyze` RC=0 (**0 issue**, aucun `invalid_use_of_visible_for_testing_member`) · `flutter test` RC=0 (**102 tests** verts, dont les 3 nouveaux) · `dart pub get --dry-run` RC=0 · `python3 scripts/dev/graph_proof.py` RC=0 (**CORE OUT=0**, acyclique). Invariants E6-1 (SM-1/MED-1, tranche=Delta pendant l'édition, chemin chaud sans codec) INTACTS ; AD-1/AD-2/AD-7/AD-10 respectés. Aucune modification hors `packages/zcrud_markdown/`.

### File List

**NEW (packages/zcrud_markdown/) :**
- `lib/src/domain/z_codec.dart`
- `lib/src/data/delta_neutral_ops.dart`
- `lib/src/data/z_delta_codec.dart`
- `lib/src/data/z_markdown_codec.dart`
- `lib/src/presentation/z_markdown_codec_scope.dart`
- `test/fixtures/rich_corpus.dart`
- `test/z_delta_codec_test.dart`
- `test/z_markdown_codec_test.dart`
- `test/z_codec_selection_test.dart`
- `test/z_markdown_field_codec_test.dart`
- `test/conversion_libs_isolation_graph_test.dart`

**MODIFIED (packages/zcrud_markdown/) :**
- `lib/zcrud_markdown.dart` (barrel : + `ZCodec`, `ZDeltaCodec`, `ZMarkdownCodec`, `ZMarkdownCodecScope`)
- `lib/src/presentation/z_markdown_field.dart` (paramètre `codec` ; résolution codec ; seed via `codec.decode` ; `_syncFromExternal` codec-aware hors focus ; `debugPersistedValue` ; factorisation vers `DeltaNeutralOps` ; doc contrat) — **remédiation** : + API publique `persistedValueOf` (voie de persistance non-debug, MEDIUM-1a) ; normalisation POST-FRAME de la tranche en Delta neutre (MEDIUM-1b) ; doc `debugPersistedValue` recadrée en hook de test ; const `_kDefaultPersistedCodec`
- `lib/src/data/delta_neutral_ops.dart` — **remédiation HIGH-1** : `toDeltaForMarkdown` remplace les embeds opaques par un placeholder textuel `[embed:<type>]` (perte bornée) ; helper `_embedPlaceholder`
- `lib/src/data/z_markdown_codec.dart` — **remédiation HIGH-1** : table des pertes réécrite (embed → placeholder, texte préservé)
- `lib/src/presentation/z_markdown_codec_scope.dart` — **remédiation LOW-2** : `of()` lève une `FlutterError` descriptive ; **LOW-1** : doc de stabilité du codec au montage
- `pubspec.yaml` (+ `markdown ^7.2.2`, `markdown_quill ^4.3.0`)
- `test/quill_signature_isolation_test.dart` (extension AC8 : `ZCodec` + libs de conversion)
- `test/fixtures/rich_corpus.dart` — **remédiation** : + fixture `mixedTextAndEmbedsOps` (texte + 2 embeds)
- `test/z_markdown_codec_test.dart` — **remédiation HIGH-1** : test perte bornée texte + embeds mixtes
- `test/z_markdown_field_codec_test.dart` — **remédiation MEDIUM-1** : tests tranche normalisée dès montage + `persistedValueOf` robuste

**MODIFIED (racine, conséquence deps) :** `pubspec.lock` (lock partagé du workspace).

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-07-10 | 0.2.0 | E6-2 : `ZCodec` pluggable (`ZDeltaCodec` identité + `ZMarkdownCodec` via `markdown_quill`), `ZMarkdownCodecScope`, couture seed/persistance dans `ZMarkdownField` (tranche=Delta neutre préservée), gates isolation/signature étendus. 99 tests verts. |
| 2026-07-10 | 0.2.1 | Remédiation code-review : HIGH-1 (perte embed BORNÉE via placeholder, plus de doc vidé) ; MEDIUM-1 (API publique `persistedValueOf` non-debug + tranche normalisée `List<Map>` dès montage) ; LOW-1 (doc stabilité codec) ; LOW-2 (`FlutterError` descriptive). 102 tests verts, analyze 0 issue, graph CORE OUT=0. |
