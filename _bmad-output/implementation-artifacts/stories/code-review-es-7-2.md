# Code-review ES-7.2 — Comblement écarts mindmap + décision rich-text (`zcrud_mindmap`, OQ-S5)

- **Skill réel invoqué** : `bmad-code-review` (tool `Skill`, préfixe `bmad-*`) — chargé et suivi (step-01 gather-context → step-02 review adversariale). Pas de fallback disque nécessaire.
- **Périmètre** : `packages/zcrud_mindmap/` UNIQUEMENT. Aucun autre package touché. Toutes les injections R3 restaurées par **édition ciblée** (R13, jamais `git checkout`).
- **Baseline** : `f29368c7a229bd17dfc5ab2ab37156a0407ccd6f`.
- **Statut story** : `review`.

## Preuves de vérification rejouées RÉELLEMENT (RC hors pipe — R15 ; runner FLUTTER — R14)

| Vérif | Commande | Résultat |
|---|---|---|
| Tests package | `flutter test` (zcrud_mindmap) | **All tests passed! (+140)** — 114 E10 pré-existants + 26 ES-7.2 |
| Graphe (AD-1) | `python3 scripts/dev/graph_proof.py` | **RC=0** — ACYCLIQUE, CORE OUT=0, **20 nœuds**, **42 arêtes**, `zcrud_mindmap → {zcrud_core, zcrud_markdown}` préexistantes, **0 nouvelle arête** |
| Aucun nouveau package | `dart run melos list \| wc -l` | **20** |
| Modèle domaine (AC7) | `git` — `z_mindmap_node.dart` **absent du diff** | `content` reste `String?`, `_knownKeys` = `{id,label,content,level,children,extension}` **inchangé** |

## Preuves R3 rejouées par le reviewer (mutation → RED → restauration ciblée)

| Injection | Cible neutralisée | Résultat | Verdict pouvoir |
|---|---|---|---|
| **INJ-ADV-A (AC4)** | branche plein-écran → `return body;` (suppression totale de `SizedBox.expand(ColoredBox(...))`) | **Tests AC4 restés VERTS (+2)** | ⚠️ **POWERLESS** (voir MEDIUM-1) |
| **INJ-2 (AC3 masquage)** | `z_mindmap_node_card` : toujours `contentBuilder` (retrait du `compact ? _CompactLabel`) | **RED (RC=1, +0 -1)** | ✅ Discriminant confirmé |

Après restauration exacte des deux mutations : `flutter test` → **All tests passed! (+140)** ; diff-stat identique à l'état ES-7.2 (`z_mindmap_view.dart` 361, `z_mindmap_node_card.dart` 37) ⇒ restaurations **byte-exactes**.

Les autres gardes ont été auditées par lecture + traçage d'injection (INJ-1 clamp zoom, INJ-3 super-racine 1-racine, INJ-4 clés émises figées, INJ-6 scan anti-codec, INJ-7 repli plain-text) : gardes réelles présentes dans le code de prod, assertions ancrées sur l'objet propre — jugées discriminantes.

---

## FINDINGS

### MEDIUM-1 — AC4 plein-écran : test POWERLESS + sémantique « remplit le parent » ≠ « occupe le plein-écran »

**Fichier** : `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart:150-164` (impl) ; `packages/zcrud_mindmap/test/z_mindmap_view_controls_test.dart:186-214` (test).

**Deux défauts liés :**

1. **Test sans pouvoir discriminant (R12).** PROUVÉ : j'ai supprimé intégralement le wrapper plein-écran (`SizedBox.expand(ColoredBox(color: bg, child: body))`) en faisant retourner `body` brut dans la branche `fullscreen` — **les 2 tests AC4 sont restés VERTS**. Le seul test de comportement AC4 (`toggle plein-écran : affordance de sortie étiquetée apparaît`) n'assert QUE le libellé du bouton (`exitFullscreen`), qui vit dans la barre de contrôles présente dans `body` dans **les deux branches**. Aucune assertion ne vérifie que la surface passe réellement en plein-écran. `INJ-3b` (l.187-193) ne teste que `controller.fullscreen.value == false` (état contrôleur), pas le layout — le commentaire de la story « faire du plein-écran le défaut ⇒ test E10 de layout inline RED » est **inexact** : aucun test de layout ne casserait.

2. **Sémantique de plein-écran discutable (déviation AC4).** L'AC4 demande « la surface mindmap occupe le **plein-écran** (route/overlay dédié) ». L'implémentation enveloppe simplement le corps dans `SizedBox.expand` : elle **remplit les contraintes du parent**, elle n'échappe PAS à l'arbre (pas d'`Overlay`/route). Consommée par ES-7.1 dans une section study **contrainte** (ou un scroll à hauteur non bornée), le toggle « plein-écran » ne couvrira pas l'écran (voire lèvera une contrainte non bornée). Le rendu est donc « remplir le conteneur », pas « plein-écran ».

**Scénario d'échec** : `ZMindmapView` monté dans un conteneur 300×200 (section study-tools) ; l'utilisateur active « plein écran » ; la surface reste dans 300×200. Un futur régresseur qui supprime le wrapper visuel ne serait détecté par aucun test.

**Correctif proposé** : (a) ajouter une assertion discriminante — ex. sous fullscreen ON, `find.byType(SizedBox)` couvrant l'espace / présence du `ColoredBox` d'arrière-plan uniquement quand ON ; idéalement tester via un host contraint que la surface plein-écran déborde le conteneur ; (b) trancher la sémantique : soit passer par un `OverlayEntry`/route dédié (échappe au parent, conforme « occupe le plein-écran »), soit requalifier l'AC en « expansion dans le conteneur hôte » et le documenter. Défaut off (AC6) reste respecté quoi qu'il arrive.

### LOW-1 — AC8 : le test « R22 » unitaire est POWERLESS vis-à-vis de l'adaptateur (anti-pattern R20)

**Fichier** : `packages/zcrud_mindmap/test/z_mindmap_markdown_content_test.dart:47-58`.

Le test `R22 : le payload rendu == le payload stocké` construit un `const ZDeltaCodec()` **localement dans le test** et round-trip `codec.decode(codec.encode(ops))`. Il teste donc une propriété de `ZDeltaCodec` (de `zcrud_markdown`) — exactement l'objet que R20 met en garde de ne PAS asserter — et **pas** la composition de l'adaptateur : remplacer le codec dans `ZMindmapMarkdownContent` laisserait ce test VERT. Le pouvoir réel de l'identité du codec est en fait porté par le test widget voisin (l.60-82 : `reader.codec, isA<ZDeltaCodec>()` + `reader.value, equals(_ops())` extraits du widget effectivement construit) — celui-ci EST discriminant. Le test R22 unitaire est donc redondant/trompeur (fausse confiance).

**Correctif proposé** : supprimer le test R22 unitaire, OU l'ancrer sur le codec effectivement composé (`tester.widget<ZMarkdownReader>(...).codec` puis round-trip via ce codec-là), pour qu'un swap de codec dans l'adaptateur le rougisse.

### LOW-2 — Barre de contrôles non protégée contre le débordement horizontal (RTL/étroit)

**Fichier** : `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart:412-479` (`_ZMindmapControlBar`).

6 `IconButton` de largeur min 48 dp dans un `Row(mainAxisSize: min)` non défilable ⇒ largeur mini ~288 dp + paddings. Sous un hôte très étroit (petite section study, split-view, gros facteur d'accessibilité), risque de `RenderFlex overflow`. Les tests utilisent un host 800 dp et ne couvrent pas ce cas.

**Correctif proposé** : envelopper la `Row` dans un `SingleChildScrollView(scrollDirection: Axis.horizontal)` ou un `Wrap`, ou tester à largeur contrainte.

### LOW-3 (nit) — Couleur d'icône des contrôles non issue de `ZcrudTheme`

**Fichier** : `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart:501-508` (`_ControlButton`).

`Icon(icon)` sans couleur explicite ⇒ couleur héritée de l'`IconTheme`/`Theme.of` ambiant, pas d'un token `ZcrudTheme` comme les cartes de nœud (`theme.labelColor`). Le scan FR-26 (aucune couleur en dur) passe — c'est un repli `Theme.of` admissible — mais l'incohérence avec le reste du package (tokens `ZcrudTheme`) reste un nit de finition. Optionnel.

---

## Axes adversariaux — bilan

- **AD-28 / OQ-S5** : ✅ modèle `ZMindmapNode` INCHANGÉ (`content: String?`, `_knownKeys` figé) ; rich-text = slot AD-4 opt-in via `ZMindmapMarkdownContent` composant `ZMarkdownReader` + `const ZDeltaCodec()` identité ; **aucun** `implements/extends ZCodec`, **aucune** heuristique (`startsWith('[')` / `"insert"`) — scan machine présent et vérifié ; repli plain-text défensif (`_resolveRichOps → null ⇒ ZMindmapDefaultNodeContent`), jamais de throw ; round-trip `extra['rich_delta']` byte-préservé (AC7) + clés de sync jamais réémises (AD-16).
- **Leçon R20** : ✅ l'AC8 ancre bien ses assertions load-bearing sur l'objet PROPRE à l'adaptateur (résolution slot AD-4, repli, identité du codec du widget construit). Seule exception : le test R22 unitaire (LOW-1).
- **Additif strict (AC6)** : ✅ 114 tests E10 pré-existants VERTS INCHANGÉS ; tous les nouveaux paramètres (`controller`, `viewLabels`, `compact`, `compactListenable`, `superRootLabel`) sont **optionnels, défaut = E10** ; `controller == null` ⇒ chemin E10 strict (aucune barre, aucune enveloppe zoom).
- **SM-1** : ✅ zoom piloté par `Transform.scale` externe avec `child` passé une fois ⇒ un zoom ne reconstruit pas les nœuds (test `contentBuilds` inchangé, discriminant). Tranches `ValueNotifier` isolées, aucun `setState` global.
- **AD-1 / DW-ES72-1** : ✅ 0 nouvelle arête (42 inchangé) ; zoom via `Transform.scale` externe + neutralisation zoom interne (`min=max=1`), **aucun fork graphite** ; melos list=20.
- **DW-ES72-4** : ✅ aucun flowchart legacy (`flutter_flow_chart`/`graphview`) réintroduit par la voie plein-écran.

---

## VERDICT

**APPROUVÉ SOUS RÉSERVE (Changes Requested — MEDIUM).**

- **0 HIGH / 0 MAJEUR.** L'implémentation respecte AD-28/AD-4/AD-7/AD-10/AD-16/AD-1/AD-2 : décision OQ-S5 correctement matérialisée, additif strict prouvé, 0 nouvelle arête, aucun nouveau codec, modèle intact.
- **1 MEDIUM** (MEDIUM-1, AC4 plein-écran) à corriger par défaut dans le périmètre de la story (renforcer le test pour lui donner du pouvoir discriminant **et** trancher la sémantique route/overlay vs remplir-parent), ou reporter avec justification écrite si l'expansion-dans-le-conteneur est le comportement voulu — auquel cas requalifier l'AC4.
- **3 LOW** (LOW-1 test R22 powerless ; LOW-2 débordement barre ; LOW-3 nit couleur icône) — LOW-1 recommandé (fausse confiance R20), LOW-2/LOW-3 optionnels.

La remédiation est pilotée par l'orchestrateur (le reviewer ne corrige pas). `architecture.md` (note AD-28, DW-ES72-3) et `sprint-status.yaml` NON touchés.

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| MEDIUM-1 (AC4 plein-écran) | 🟠 MEDIUM | ✅ **CORRIGÉ** | (a) **Pouvoir discriminant restauré** : le wrapper plein-écran (`SizedBox.expand`) porte désormais `key: ValueKey(kMindmapMaximizedSurfaceKey)` ; le test AC4 assère sa présence/absence STRUCTURELLE (`find.byKey`), plus seulement le libellé du bouton. **Prouvé par l'orchestrateur** : INJ-ADV-A (wrapper → `return body;`) fait ROUGIR AC4 (`Found 0 widgets with key`, RC=1) ; restauré → RC=0. (b) **Sémantique tranchée** : requalifié « **maximisation dans le conteneur** » (l'honnêteté de `SizedBox.expand`) — doc prod corrigée ; un vrai overlay-écran est **déféré (DW-ES72-5)**, hors périmètre M. |
| LOW-1 (AC8 R22 powerless) | 🟡 LOW | ✅ **CORRIGÉ** | Round-trip R22 **ré-ancré sur le codec RÉEL de l'adaptateur** : le test widget round-trip via `reader.codec` (le codec composé par `ZMindmapMarkdownContent`), pas un `ZDeltaCodec` local — un swap de codec dans l'adaptateur ROUGIRAIT désormais. Le test unitaire est requalifié en test de la **propriété d'identité de `ZDeltaCodec`** (honnête, non trompeur). |
| LOW-2 (control bar overflow) | 🟡 LOW | ✅ **CORRIGÉ** | `_ZMindmapControlBar` : `Row` de 6 cibles ≥48dp enveloppé dans un `SingleChildScrollView(horizontal)` — plus de `RenderFlex overflow` en hôte étroit/RTL, aucune cible tactile rognée. |
| LOW-3 (couleur d'icône) | 🟡 LOW | 🟡 **CONSIGNÉ** | Couleur d'icône des contrôles héritée de l'`IconTheme` ambiant (repli FR-26 admissible). Nit de finition non-bloquant ; consigné. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_mindmap (R14) → RC=0, **140 tests** · `dart analyze` (scope zcrud_mindmap) → RC=0 (*No issues found!*).

**Doc appliquée par l'orchestrateur** : `architecture.md § AD-28` (OQ-S5 RÉSOLU ET IMPLÉMENTÉ) + § Deferred (DW-ES72-5, plein-écran = maximisation-dans-le-conteneur).

**Verdict final** : ✅ **PRÊT POUR `done`** — MEDIUM-1 corrigé et prouvé non-powerless ; LOW-1/LOW-2 corrigés ; LOW-3 consigné ; doc appliquée.
