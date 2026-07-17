# Code-review — su-2 · Carte de révision adaptative

**Story** : `su-2-carte-revision-adaptative` (8 ACs) · **Package** : `zcrud_flashcard` · **Branche** : `main` (rien committé)
**Spine** : `ARCHITECTURE-SPINE.md` (AD-40/41 + hérités AD-1..32) · `CLAUDE.md`
**Lentilles** : conformité AD · a11y/motion · l10n/thème · SM-1/perf · adversariale · isolation/surface · tests porteurs

## Verdict

**CHANGEMENTS APPLIQUÉS — story VERTE après correction.** 14 findings (2 HIGH, 3 MAJEURS, 9 MEDIUM) : **14/14 corrigés**, **0 reporté**. LOW : 4 corrigés, 4 consignés (justifiés).

Les deux HIGH étaient invisibles à la suite livrée : la **révélation était morte** sur le chemin d'usage que la story documente verbatim, et le **canal non-coloré d'AD-13 désignait le mauvais choix** — le tout avec **328/328 verts**. Le nœud commun des 14 findings n'est pas le code : ce sont des **gardes infalsifiables**. Cinq d'entre elles ne pouvaient structurellement pas rougir (D4, D5, D7, D12, D13) ; une avait été **modifiée pour taire un défaut réel** (D3).

**Référence verte** : `zcrud_flashcard` **328** (arbre quiescent, rejouée). Les 331/332 rapportés par certaines lentilles étaient leurs propres sondes jetables — le 328 de la story est **CORRECT**, non corrigé.

## Vérif verte (rejouée réellement)

| Gate | Commande | RC |
|---|---|---|
| Analyze repo-wide | `dart run melos run analyze` | **0** |
| Verify repo-wide | `dart run melos run verify` | **0** |
| Tests (23/23 packages, séquentiel) | `flutter test` par package | **0** — **3725 tests** |

`zcrud_flashcard` : **328 → 359** (+31 tests neufs). Total repo **3694 → 3725**. `melos run test` **jamais lancé** (piège avéré : parallélise et se bloque).

## Preuves R3 — falsifiabilité (injection → rouge obtenu ?)

Chaque fix retiré à tour de rôle sur le fichier de prod, run ciblé, **restauration vérifiée par SHA-256** (`ffda33ae…d633e96` avant = après ; ces fichiers ne sont pas suivis par git).

| # | Injection de faute | Résultat |
|---|---|---|
| D1 | `IgnorePointer` retiré du contenu | ✅ ROUGE (2) |
| D2 | `MergeSemantics` retiré de `_choiceRow` | ✅ ROUGE (1) |
| D3 | `SingleChildScrollView` retiré | ✅ ROUGE (1) |
| D4 | `Text(card.question)` injecté sur le chemin `trueOrFalse` | ✅ ROUGE (1) |
| D5 | hoisting `child:` retiré (contenu par frame) | ✅ ROUGE (1) |
| D6 | reset rendu muet | ✅ ROUGE (2) |
| D7 | libellé de toggle rendu constant | ✅ ROUGE (2) |
| D8 | `excludeFromSemantics` retiré | ✅ ROUGE (1) |
| D9 | `size: theme.gapL` restauré | ✅ ROUGE (1) |
| D11 | défaut résolu → adaptateur riche | ✅ ROUGE (1) |
| D12 | canal 1 (`_toggle`) retiré **SEUL** | ✅ ROUGE (1) |
| D12 | canal 2 (`_animatedFace`) retiré **SEUL** | ✅ ROUGE (1) |
| D13 | branche `transitionDuration` retirée | ✅ ROUGE (1) |

**13/13 gardes rougissent.** D12 est le point notable : les deux canaux se masquaient (retirer l'un OU l'autre laissait 6/6 vert) ; chacun rougit désormais **seul**.

---

## Findings

### 🔴 D1 — HIGH — la révélation par tap est MORTE sur le chemin markdown · **CORRIGÉ**
`z_flashcard_review_card.dart:506` × `z_markdown_reader.dart:152-166`

**Scénario d'échec** : une app suit l'exemple que la story documente verbatim (`contentBuilder: ZFlashcardMarkdownContent.builder()`). Le `QuillEditor` (qui autorise la sélection) **gagne l'arène des gestes** contre l'`InkWell` de la carte : `onRevealChanged` ne reçoit rien, **la réponse n'apparaît jamais**. Mesuré : défaut ⇒ `[true]` ; markdown ⇒ `[]`. La fonction centrale de su-2 était morte sur son chemin d'usage documenté, avec 328/328 verts.

**Cause du trou** : les 9 taps d'AC2 n'exercent que le `contentBuilder` **par défaut**.

**Fix** : `_content` enveloppe le sous-arbre du slot dans un `IgnorePointer` — en su-2 le contenu est **purement d'affichage** (la saisie est su-3). Les `Semantics` du sous-arbre restent lisibles (vérifié : le test d'association D2 lit le texte du choix au travers). AC4 tenu : les actions restent **absentes**, jamais grisées — garde dédiée ajoutée (`edits == 1` sous markdown).

**Tests** : 3 cas neufs (tap carte, tap **au centre du contenu riche**, non-régression AC4).

### 🔴 D2 — HIGH — le canal non-coloré est DÉTACHÉ de son choix (AD-13) · **CORRIGÉ**
`z_flashcard_review_card.dart:297-327` (conséquence d'`explicitChildNodes: true` en `:531`)

**Scénario d'échec** : `_choiceRow` n'avait ni `MergeSemantics` ni `Semantics(container:)` ⇒ le marqueur « Bonne réponse » était un **nœud autonome**. Dump réel : `"Paris" -> "Bonne réponse" -> "Lome"` — le lecteur d'écran attache le marqueur à **Paris**, le choix FAUX. **Un utilisateur non-voyant apprend une erreur.** Le fix a11y de su-2 avait exhumé le marqueur mais dé-fusionné la ligne.

**Fix** : `MergeSemantics` au niveau de la **ligne** — le marqueur est rattaché à SON choix sans retomber dans le blob illisible que `explicitChildNodes` avait supprimé (garde-fou ajouté : un choix faux ne porte pas le marqueur).

**Tests** : correct en **position 2** (jamais en tête — sinon un marqueur détaché se lit malgré tout juste avant le bon choix et le défaut reste invisible) ; assertion d'**association** (`node.label` contient `Lome`, pas `Paris`/`Accra`), non de simple présence.

### 🟠 D3 — MAJEUR — débordement RÉEL : un test avait été modifié pour cacher un défaut · **CORRIGÉ**
`z_flashcard_review_card.dart:264`

**Scénario d'échec** : QCM **ordinaire** 8 choix + explication à 800×600 ⇒ `RenderFlex overflowed by 200 pixels` ; contenu long **sans aucun markdown** ⇒ **3436 pixels**. Ni le markdown ni le harnais n'étaient en cause — c'est ce que verrait l'utilisateur, qui ne peut pas lire la fin de la réponse. `grep -nE "SingleChildScrollView|Scrollable|ClipRect|maxHeight"` → **RC=1, aucun mécanisme**, alors que la source de parité citée par la story pose exactement celui qui manque (`lex_ui/…/session_flashcard_view.dart:247`, consultée en lecture seule).

L'écart auto-déclaré n°2 du dev (« artefact de harnais, test corrigé PAS le code ») est **RÉFUTÉ par l'exécution**. **On ne modifie jamais un test pour faire taire un défaut réel.**

**Fix** : face défilable (patron lex_ui). Le `LayoutBuilder` est **nécessaire** et non décoratif : un viewport exige une hauteur **bornée** ; rendre la face inconditionnellement défilable lèverait « Vertical viewport was given unbounded height » pour tout hôte posant la carte dans un `ListView`. En hauteur bornée ⇒ `Flexible` + `SingleChildScrollView` ; sinon la colonne est rendue telle quelle.

**Tests** : 4 cas — QCM ordinaire, contenu long, **contre-preuve** (le harnais SAIT produire un débordement, sinon les `takeException(), isNull` seraient aveugles), et carte dans un `ListView`. Cas `'# ' * 500` **RESTAURÉ** dans `z_flashcard_markdown_content_test.dart` : les sources compactes du dev sont un bon **ajout**, elles ne **remplacent** rien.

### 🟠 D4 — MAJEUR — la sentinelle AC1-d ne couvrait que 2 chemins `question` sur 3 · **CORRIGÉ**
`z_flashcard_review_card.dart:246`

**Nuance** : le **code était correct** (les 3 chemins passent par `_content`) — c'est la **garde** qui était incomplète. Injecter `Text(card.question)` sur le chemin `trueOrFalse` laissait **328/328 VERTE**. Preuve d'absence : `grep -rn "INJ:Vrai\|INJ:Faux" test/` → RC=1.

**Fix (test)** : la sentinelle traverse désormais **tous** les chemins de contenu par **construction** — boucle sur `ZFlashcardType.values` (une 7ᵉ valeur ajoutera mécaniquement son cas). La promesse centrale de su-2 est devenue VRAIE : **prouvé**, l'injection en `:246` rougit maintenant.

### 🟠 D5 — MAJEUR — SM-1 : la face entière était reconstruite à CHAQUE FRAME · **CORRIGÉ**
`z_flashcard_review_card.dart:379-396`, `:402-414`

**Scénario d'échec** : l'`AnimatedBuilder` **jetait son `child:`** ⇒ `contentBuilder` ré-invoqué à chaque tick : **17** invocations par révélation (carte simple), **153** (QCM 8 choix + explication). Une fois D1 corrigé, cela devient **153 décodages markdown + `Document` + `jsonEncode` par flip** — `z_markdown_reader.dart:110-113` dédupe **APRÈS** le coût. **SM-1 est l'objectif produit n°1.**

**Fix** : le contenu passe en `child:` de l'`AnimatedBuilder` (il ne dépend pas de l'animation) ; seule la `Matrix4`/l'`Opacity` est réévaluée par frame. La sélection de face est dérivée du controller par un `ValueNotifier _showBack` ⇒ le contenu se reconstruit **au plus une fois par flip** (au franchissement de la mi-course), pas une fois par tick.

**Tests** : la **sonde de comptage dans le `contentBuilder`** — discriminant (1) d'AC7, **prescrit mot pour mot par la story** et **absent** (`grep "buildCount|count++|invocations"` → RC=1). La sonde livrée (`sm1_test.dart:104-149`) mesurait la rangée d'actions, un **sibling hors de l'`AnimatedBuilder`** : structurellement aveugle. 3 cas neufs, dont le discriminant **structurel** : *une transition 4× plus longue ne construit pas 4× plus de contenu* — un seuil absolu peut toujours être « ajusté », ce rapport-là ne peut être satisfait que si le contenu est hors de la boucle de frames. + contre-preuve (sonde réellement invoquée).

### 🟡 D6 — MEDIUM — `onRevealChanged` muet au reset de carte · **CORRIGÉ**
`z_flashcard_review_card.dart:169-174` (grep RC=1), contre son propre dartdoc `:96` (« notifié à **chaque** bascule »).

**Scénario d'échec** : su-4 swipe A→B ; l'hôte croit `revealed == true` ⇒ `ZSrsQualityButtons` affichés sur une carte **non révélée** ⇒ l'apprenant note une carte dont il n'a pas vu la réponse ⇒ **écriture SRS faussée**.

**Fix** : voie **unique** `_setRevealed(bool)` — les deux voies (tap, reset) notifient, et **seulement sur changement réel** (pas de `false` redondant). ⚠️ La notification du reset est **reportée en fin de frame** : `didUpdateWidget` s'exécute **pendant le build du parent**, où une notification synchrone ferait planter tout hôte réagissant par `setState` (« called during build ») — hôte parfaitement légitime. L'**état**, lui, est juste immédiatement.

**Tests** : 3 cas (notification au reset ; **aucun faux événement** quand rien ne bascule ; hôte à `setState` ne plante pas).

### 🟡 D7 — MEDIUM — libellé d'un contrôle TOGGLE constant · **CORRIGÉ**
`z_flashcard_review_card.dart:534-538`

**Scénario d'échec** : face réponse, le contrôle annonce « Afficher la réponse » alors que le tap **masque** ⇒ **annonce fausse dans 50 % des états**. **Aggravant** : `a11y_test.dart:210,217` trouvait le nœud **par ce libellé** sur les deux faces ⇒ la garde ne pouvait **jamais** rougir.

**Fix** : libellé dérivé de `revealed` (clé l10n `zcrud.flashcard.hide`, fallback « Masquer la réponse »). **Test corrigé aussi** : le nœud de la face réponse est cherché par son libellé propre.

### 🟡 D8 — MEDIUM — nœud tappable ANONYME · **CORRIGÉ**
`z_flashcard_review_card.dart:506` — `label="" actions=tap` enveloppant la carte, doublon de la révélation nommée ⇒ TalkBack annonce un contrôle **sans nom**. **Fix** : `excludeFromSemantics: true` sur l'`InkWell`. **Test** : parcours réel de l'arbre sémantique, aucun nœud tappable à libellé vide.

### 🟡 D9 — MEDIUM — taille d'icône pilotée par un token d'ESPACEMENT · **CORRIGÉ**
`z_flashcard_review_card.dart:306` — `size: theme.gapL` (**seul cas du repo**). Une app réglant `gapL: 8` rétrécissait à 8 dp le `check_circle`, **seul canal visuel discriminant** ⇒ **AD-13 perdu pour un daltonien**, aucun test n'assertant de taille. **Fix** : plus de `size:` — la taille vient de l'`IconTheme`. **Test** : sous `ZcrudTheme(gapL: 8)`, marqueur ≥ 24 dp.

### 🟡 D10 — MEDIUM — dartdoc factuellement fausse · **CORRIGÉ**
`z_flashcard_markdown_content.dart:24` — « une app qui n'injecte pas ce builder ne tire **pas** Quill » alors que `zcrud_flashcard → zcrud_markdown → flutter_quill` est une arête runtime **dure** (vérifié : `dart pub deps --style=tree`, `flutter_quill: ^11.5.0` en dépendance normale de `zcrud_markdown`). L'opt-in d'AD-40 porte sur le **rendu**, pas sur la fermeture de dépendances. **Fix** : la dartdoc dit désormais le vrai (« ne construit aucun widget Quill ») et **nomme explicitement** ce que l'opt-in n'est pas. Même correction sur les deux autres occurrences de la même affirmation (`z_flashcard_review_card.dart:16-17` — su-2 ; `z_flashcard_content_slot.dart:12` — fichier de su-1, corrigé car prose seule, risque nul, et laisser la même contre-vérité à côté n'aurait aucun sens).

### 🟡 D11 — MEDIUM — garde « défaut texte brut » ignorant le widget qui résout le défaut · **CORRIGÉ**
`z_flashcard_rich_type_leak_test.dart:177-205` — n'inspectait que `z_flashcard_content_slot.dart` et ignorait `ZFlashcardReviewCard` (grep `review_card` → RC=1). **Un futur `?? ZFlashcardMarkdownContent.builder()` violerait AD-40 garde verte** (tout consommateur paierait le rendu riche). **Fix** : le scan d'imports couvre les deux fichiers du chemin par défaut + garde de source neuve sur la **ligne de résolution** elle-même (contre-preuve R12 : exactement 1 occurrence vue).

### 🟡 D12 — MEDIUM — deux canaux Reduce Motion se masquaient · **CORRIGÉ**
`z_flashcard_review_card.dart:192` (`_toggle`) et `:362` (`_animatedFace`) — retirer l'un **OU** l'autre ⇒ **6/6 VERT** ; seul le retrait des deux rougissait. `:362` était du code mort pour la CI alors qu'il est le **seul** à couvrir « Reduce Motion s'active pendant une animation en vol ».

**Fix (tests)** : une garde par canal, chacune rougissant **seule** (prouvé).
- Canal 2 : Reduce Motion activé **pendant un flip en vol** ⇒ rotation neutralisée.
- Canal 1 : la valeur du controller est lue en **rallumant** les animations sans y retoucher (la face redevient une rotation qui l'expose). ⚠️ `tester.hasRunningAnimations` **ne discrimine pas** : le ripple de l'`InkWell` tourne après tout tap, quelle que soit la branche — piège rencontré et écarté.

### 🟡 D13 — MEDIUM — branche `transitionDuration` jamais exercée · **CORRIGÉ**
`z_flashcard_review_card.dart:165-168` — `grep "transitionDuration" test/` → RC=1 ; la supprimer ⇒ **328/328 VERT**. **Fix (test)** : durée changée **à chaud** (800 ms) ⇒ à 400 ms le flip est encore en vol ; **contre-preuve** avec 250 ms (retombé sur l'identité). Assertion sur l'**arbre** (même piège du ripple qu'en D12).

### 🟡 D14 — MEDIUM — entrée `''` neutralisée dans la boucle AD-10 · **CORRIGÉ**
`z_flashcard_markdown_content_test.dart:110-131` — `malformed.isEmpty ? 'Q' : malformed` (:122) faisait rendre `'Q'` : le cas **attestait une propriété qu'il n'exerçait pas**. **Fix** : sources nommées (`''` ne peut pas être décrite par un extrait d'elle-même), `''` passé **tel quel**. Vérifié à l'exécution : le cas « source VIDE » s'exécute bien.

---

## LOW

| # | Item | Disposition |
|---|---|---|
| L1 | `:170-177` « la carte mesure ≥ 48 dp » **tautologique** (largeur imposée par le `SizedBox(400)` du harnais) | **CORRIGÉ** — contraintes lâches ; `< 200` prouve la taille intrinsèque |
| L2 | `:302` `labelColor` à **deux replis divergents** (`?? primary` vs `?? onSurface`) ⇒ marqueur et texte de couleurs différentes dans la même `Row` ; `primary` suggère un interactif que su-2 interdit | **CORRIGÉ** — repli unique `?? onSurface` + test d'égalité marqueur/texte |
| L3 | `z_flip_card_dep_guard_test.dart:131` ne scanne ni `example/pubspec.yaml` ni la racine | **CORRIGÉ** — scan depuis la racine, artefacts d'outillage exclus, présence des deux pubspecs assertée |
| L4 | `Opacity` (saveLayer) plutôt que `FadeTransition` | **CONSIGNÉ** — `Opacity` est **délibéré** : la face doit **changer** à mi-course, ce qu'un `FadeTransition` nu ne fait pas. Le coût `saveLayer` porte sur un sous-arbre désormais hissé (D5). Changer la mécanique de transition hors nécessité serait un risque net. |
| L5 | `question: ''` ⇒ face vide (seul champ sans repli, alors qu'AC1 dit « jamais un écran vide ») | **CONSIGNÉ** — un repli dans la carte **écraserait le placeholder injecté** par le slot et casserait le contrat AD-40 (le slot décide du rendu du contenu qu'il reçoit ; `markdown_content_test` prouve que `question: ''` rend « VIDE PERSO », pas un écran vide). Le résiduel ne concerne que le **défaut** (`Text('')`) et se traiterait dans `ZFlashcardDefaultContent` — fichier de **su-1**, hors périmètre. → **ledger** |
| L6 | `ZcrudTheme.of` re-résolu ×3-4 par face | **CONSIGNÉ** — `ZcrudTheme.of` est une lecture d'`InheritedWidget` (O(1), pas de recalcul) ; hisser la résolution nuirait à la lisibilité pour un gain non mesurable. |
| L7 | `ZFlashcardMarkdownContent.builder()` **alloue une closure neuve** à chaque appel et le dartdoc la construit dans un `build()` (précédent identique `z_mindmap_markdown_content.dart:65`) | **CONSIGNÉ** — le contrat est symétrique du patron mindmap ; le corriger ici seul désynchroniserait les deux slots AD-40 du repo. → **ledger** (traitement conjoint des deux adaptateurs) |
| L8 | `zReduceMotionOf` « voie unique » ni gardée ni atteignable par `zcrud_mindmap`/`zcrud_ui_kit` (foyer naturel = `zcrud_core`/`zcrud_ui_kit`, **interdits d'écriture** en story SU) | **CONSIGNÉ** → **ledger su-5** |

## Écarts / notes de procédure

- **Compteur de tests** : les lentilles rapportant 331/332 mesuraient **leurs propres sondes jetables**. Référence quiescente **328** confirmée par run direct — non « corrigée ».
- **Aucune écriture** dans `zcrud_core`, `sprint-status.yaml`, ni hors `/home/zakarius/DEV/zcrud`. `lex_ui` **consultée en lecture seule** (D3).
- **Aucun commit.** Aucun fichier scratch résiduel (`ls test/ | grep -iE "zz_|tmp|probe"` → RC=1).
- Restauration des injections R3 **prouvée par SHA-256** (la plupart de ces fichiers ne sont pas suivis par git).
