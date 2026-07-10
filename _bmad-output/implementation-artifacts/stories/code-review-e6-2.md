# Code Review — E6-2 : `ZCodec` pluggable (Delta / Markdown)

- **Story** : `e6-2-zcodec-pluggable.md` (statut `review`)
- **Package** : `zcrud_markdown`
- **Skill** : `bmad-code-review` (chemin pris : **Skill tool invoqué**, `Launching skill: bmad-code-review` — pas de fallback disque)
- **Mode** : revue adversariale autonome (sous-agent, pas de checkpoint interactif)
- **Périmètre** : `zcrud_markdown` uniquement (zcrud_intl / zcrud_export / example non touchés)
- **Date** : 2026-07-10

---

## Verdicts synthétiques

| Axe | Verdict |
|-----|---------|
| Contrat tranche = Delta neutre pendant l'édition | **OUI** (hot path `_onQuillChanged` sans codec, `setValue` = `List<Map>`) |
| SM-1 / MED-1 (E6-1) intacts avec `ZMarkdownCodec` | **OUI** (test AC10 : `init==1`, `identical`, voisin figé, caret=101, codec hors `_onQuillChanged`) |
| Round-trip SM-4 réel (non tautologique) | **OUI** (`ZDeltaCodec` = vraie identité via json ; `ZMarkdownCodec` = sémantique réelle via `markdown_quill` + table des pertes assertée) |
| Isolation lib de conversion (AD-1) | **OUI** (`markdown`/`markdown_quill` au seul pubspec, barrel/signatures neutres, gate graphe + contrôle positif) |
| Défensif (AD-10) | **OUI** (matrices null/vide/corrompu/legacy → `[]` sans throw, des deux codecs) |
| Rétrocompat `ZDeltaCodec` = E6-1 | **OUI** (`decode` = identité défensive partagée, seed inchangé) |
| Frontière E6-3/E6-4 (pas d'anticipation) | **OUI** (embeds = ops opaques, aucune dep flutter_math/table) |
| **Persistance / perte de données ZMarkdownCodec** | ⚠️ **RÉSERVE** (voir HIGH-1 + MEDIUM-1) |

---

## Findings

### HIGH-1 (MAJEUR) — `ZMarkdownCodec.encode` : un embed dans le document efface TOUT le document (perte totale silencieuse, non « bornée »)

- **Fichier** : `lib/src/data/z_markdown_codec.dart:48-63` (encode), doc `:39` (table des pertes)
- **Preuve** :
  - `encode` enveloppe **tout** l'appel `DeltaToMarkdown().convert(delta)` dans un unique `try { … } on Object { return ''; }`.
  - `DeltaToMarkdown()` est construit **nu** (aucun `customEmbedHandler`/handler d'embed — vérifié `grep`), donc il **throw** sur toute op embed inconnue (formule LaTeX E6-3, tableau E6-4) — comportement confirmé par la Debug Log de la story (« embed `formula` → `DeltaToMarkdown` throw »).
  - Conséquence : dès que le document contient **une** op embed **au milieu de texte réel**, la conversion throw et le catch renvoie `''` → **l'intégralité du contenu (le texte autour compris) est persistée vide**, pas seulement l'embed.
  - La **table des pertes** (`:39`) annonce « Embed LaTeX/tableau → **perdu** (op opaque non-MD) », laissant croire que seul l'embed disparaît (le texte survivrait, comme pour `color` en `:35-36`). Le test couleur (`z_markdown_codec_test.dart:101-110`) prouve d'ailleurs que les attributs non-MD **normaux** dégradent en préservant le texte — l'embed, lui, détruit tout.
  - **Aucun test ne couvre texte + embed mélangés** : `latexEmbedOps`/`opaqueEmbedOps` (`rich_corpus.dart:132-151`) sont des documents **embed-seul**. Le test `returnsNormally` + « containsFormula isFalse » masque la perte totale.
- **Scénario d'échec concret** : app configure `ZMarkdownField(codec: ZMarkdownCodec())`, l'utilisateur a « Texte avant \[formule\] texte après », l'app persiste via `codec.encode(ops)` → `''` → au rechargement le champ est **entièrement vide**. Perte de données **silencieuse et totale**, en contradiction directe avec le contrat E6-2 « perte **bornée** et documentée » (AC9).
- **Impact** : latent aujourd'hui (E6-3/E6-4 non livrés → pas d'embed en prod), mais **arme un piège de perte totale** dès qu'un embed existe, et le corpus prétend déjà « faire traverser » les embeds. Contredit AC9 (« bornée ») et la table des pertes.
- **Remède** : dégrader **par op** avant conversion — retirer / remplacer par un placeholder les inserts embed non convertibles **avant** `DeltaToMarkdown().convert`, de sorte que le texte environnant survive ; **ou** fournir un `customEmbedHandler` renvoyant `''`/placeholder. Ajouter un test round-trip **texte + embed** asserant : texte préservé, embed seul perdu. Corriger le libellé de la table des pertes (« embed perdu, texte préservé »).
- **Verdict** : PLAUSIBLE (chemin de code + note empirique du dev + absence de handler confirmée par `grep` ; non ré-exécuté en respect du read-only).

### MEDIUM-1 — La voie de persistance de prod repose sur un membre `@visibleForTesting`, et la tranche seed n'est pas normalisée

- **Fichier** : `lib/src/presentation/z_markdown_field.dart:76-83` (interface), `:186-188` (impl), `:204-228` (initState)
- **Preuve** :
  - `debugPersistedValue` est **`@visibleForTesting`** mais sa doc le désigne comme « **Voie par laquelle l'app persiste le format choisi (`toMap`)** » (`:78-82`). Une app qui l'appelle déclenche l'analyzer `invalid_use_of_visible_for_testing_member`. Il n'existe **aucun accesseur public** (getter/callback `onPersist`) pour récupérer la valeur encodée par le codec.
  - `initState` (`:204-228`) lit `valueOf(_name)` et construit le `Document`, mais **n'écrit jamais** la tranche (`setValue` absent). Donc **avant la première frappe**, la tranche conserve la **valeur seed brute** : une `String` Markdown si l'app a seedé du Markdown, une `List<Map>` seulement **après** édition.
  - Résultat : la tranche n'a **pas de type invariant** hors édition. Une app qui tente de persister en lisant la tranche puis `codec.encode(slice)` **crashe** (l'`encode` attend `List<Map>`, reçoit une `String` seed) ; une app qui lit la tranche brute avec `ZDeltaCodec` par défaut récupère du Delta, pas le format voulu. La **seule** voie fiable (encoder le `Document` vivant quel que soit l'état d'édition) est justement `debugPersistedValue` — `@visibleForTesting`.
- **Scénario d'échec concret** : champ seedé String Markdown, jamais édité, l'app fait `codec.encode(controller.valueOf(name))` → `TypeError` (String ≠ List<Map>). Ou l'app lit la tranche pour persister « le Markdown » et obtient le Delta neutre.
- **Impact** : le cœur de la proposition de valeur E6-2 (persister dans le format choisi — AD-7) n'a **pas d'API de prod propre** ; le chemin « naïf » (lire la tranche) est incohérent/buggé.
- **Remède** : exposer un **accesseur/callback public** de la valeur persistée (ex. `onPersistedChanged` ou getter public non-debug), **et/ou** normaliser le seed dans la tranche (`setValue` du Delta décodé en post-frame) pour rendre la tranche invariante ; ajuster la doc de `debugPersistedValue` (retirer la mention « voie de persistance app »).
- **Verdict** : CONFIRMED (statique : `@visibleForTesting` + absence de `setValue` en initState vérifiés).

### LOW-1 — Un changement de `ZMarkdownCodecScope.codec` ne se propage pas aux champs déjà montés

- **Fichier** : `lib/src/presentation/z_markdown_field.dart:195-202` + `z_markdown_codec_scope.dart:41-42`
- **Preuve** : `_resolveCodec` lit le scope via `getElementForInheritedWidgetOfExactType` (sans dépendance) une seule fois en `initState`. `updateShouldNotify` renvoie `true` sur changement de codec, mais aucun champ ne dépend du scope → **no-op silencieux** pour les champs montés. Documenté comme intentionnel (« config statique »), mais surprenant.
- **Remède** : documenter explicitement côté `ZMarkdownCodecScope` que le codec doit être stable au montage, ou re-résoudre en `didChangeDependencies` si la re-config à chaud est souhaitée. Optionnel.

### LOW-2 — `ZMarkdownCodecScope.of` throw un null-check nu en release

- **Fichier** : `lib/src/presentation/z_markdown_codec_scope.dart:34-38`
- **Preuve** : `of` fait `assert(codec != null, …)` puis `return codec!` ; asserts désactivés en release → `Null check operator used on a null value` peu descriptif. `of` n'est pas utilisé en interne (le champ passe par `getElementForInheritedWidgetOfExactType`).
- **Remède** : lever un `FlutterError` descriptif (comme les `of` Material) si vraiment nécessaire, sinon consigner. Nit.

---

## Points vérifiés SANS finding (adversarial)

- **Hot path** : `_onQuillChanged` (`:258-266`) n'appelle **jamais** le codec ; pousse `encodeNeutral` = `List<Map>`. Dédup `_lastValueJson`, garde `_applyingExternal`, sens unique — inchangés d'E6-1.
- **`_syncFromExternal`** (`:286-307`) : gardé `if (_focus.hasFocus) return;` → hors chemin chaud ; codec-aware via `_codec.decode(value)` tolérant `List` (Delta) **ou** `String` (persisté) ; ré-abonnement `document.changes` après swap ; idempotent via comparaison JSON. Pas d'écrasement de sélection en focus.
- **`ZDeltaCodec`** : vraie identité (`jsonEncode`/`decodeDefensiveOps` → `asDeltaOps` → jsonDecode), asserts `equals(c.ops)` **et** `jsonEncode` sur 12 cas réels dont embeds opaques (Map inserts survivent). Non tautologique.
- **`ZMarkdownCodec` round-trip** : sémantique réelle via `markdown_quill 4.3.0` (bold/italic/header/list+indent:1/link/code/blockquote/entités HTML) ; table des pertes **assertée** (couleur/embed). `md.Document(encodeHtml:false)` volontaire pour préserver `<`/`&` littéraux.
- **Défensif** : `decodeDefensiveOps` + `decodeDefensiveDocument` capturent tout (`on Object`), log `assert`-only ; matrices AC5 des deux codecs (null/''/'   '/'[]'/[]/JSON tronqué/op sans insert/op non-Map/int/non-JSON/Markdown mal formé) → `[]`/`returnsNormally`.
- **Isolation** : `pubspec.yaml` = `markdown`/`markdown_quill` uniquement ici ; barrel (`zcrud_markdown.dart`) exporte seulement les `src/…` neutres ; `z_codec.dart` 100% neutre (`Object?`/`String`/`List<Map>`) ; gate graphe `conversion_libs_isolation_graph_test.dart` (fermeture `dart pub deps --json` + fallback local + contrôle positif markdown_quill + acyclicité + out-degree zcrud_* du cœur = 0) ; `quill_signature_isolation_test.dart` étendu (barrel + signature `ZCodec` + runtime encode→String/decode→List<Map>).
- **Frontière E6-3/E6-4** : aucune dep `flutter_math_fork`/table ; embeds traités en ops opaques.
- **Sélection codec** : précédence `widget.codec ?? scope ?? const ZDeltaCodec()` (`:195-202`) prouvée (param seul / scope seul / param>scope / défaut / maybeOf null hors scope). `ZMarkdownCodecScope` **local** au package, jamais via `ZcrudScope`/core.
- **Const / secrets / RTL / a11y** : codecs `const`, aucun secret, `EdgeInsetsDirectional`, `Semantics`, cibles 48 dp inchangées.

---

## Recommandation

Corriger **HIGH-1** (dégradation par-op de l'embed + test texte+embed + libellé table des pertes) et **MEDIUM-1** (API de persistance de prod propre / normalisation de la tranche) avant `done`, puis re-vérif verte. LOW-1/LOW-2 optionnels.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | HIGH | ✅ **corrigé** | `DeltaNeutralOps.toDeltaForMarkdown` remplace chaque embed opaque (Map LaTeX/tableau) par un placeholder `[embed:<type>]` AVANT `DeltaToMarkdown().convert` → l'embed ne fait plus throw ; **perte bornée à l'embed, texte environnant préservé** (fini le document vide). Table des pertes réécrite. Test réel : texte + embed LaTeX + texte + embed tableau → Markdown non vide, 2 segments + marqueur/embed, aucun embed ne ressuscite. |
| 2 | MEDIUM | ✅ **corrigé (a+b)** | (a) Voie de persistance **publique non-debug** `ZMarkdownField.persistedValueOf(controller, name, {codec})` (= `encode(decode(tranche))`, robuste au type) ; `debugPersistedValue` recadré test-only ; plus d'`invalid_use_of_visible_for_testing_member`. (b) `initState` normalise la tranche en Delta neutre canonique quand le seed est `String` (setValue post-frame, gating strict → 0 régression E6-1) → tranche `List<Map>` cohérente avant/après 1re frappe. Tests ajoutés. |
| 3 | LOW-1 | 🟡 documenté | Codec résolu 1×/initState = config statique intentionnelle (note de stabilité sur `ZMarkdownCodecScope`). |
| 4 | LOW-2 | ✅ corrigé | `ZMarkdownCodecScope.of` → `FlutterError` descriptif au lieu du `codec!` nu. |

**Vérif verte rejouée (orchestrateur, ciblée zcrud_markdown)** : `flutter analyze` **0 issue** · `flutter test` **102/102** (dont texte+2embeds, tranche-List<Map>-après-montage, persistedValueOf robuste) · `dart pub get --dry-run` OK · **CORE OUT=0**. Invariants E6-1 (SM-1/MED-1) intacts.

**Verdict final** : 1 HIGH + 1 MEDIUM corrigés (tests à l'appui) + LOW traités. Story E6-2 → **done**.
