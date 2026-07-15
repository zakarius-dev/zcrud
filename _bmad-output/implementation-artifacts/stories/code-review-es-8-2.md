# Code-review ES-8.2 — UI d'annotations accessible (WCAG) `zcrud_document/presentation`

- **Skill réel invoqué** : `bmad-code-review` (tool `Skill`, chargé avec succès — PAS de fallback disque).
- **Périmètre** : `packages/zcrud_document/` uniquement. `zcrud_study`, `zcrud_core`, `zcrud_study_kernel`, `zcrud_annotations` NON touchés. Aucun `dart pub get`/bascule pubspec. `architecture.md` et `sprint-status.yaml` NON touchés.
- **Baseline** : `e8e94b380a8081f0674f69f1b817b1508a4ea4ea`.
- **Fichiers revus** : `z_annotation_tool_controller.dart` (NEW), `z_annotation_toolbar.dart` (NEW), `z_annotation_panel.dart` (NEW), `zcrud_document.dart` (barrel MODIF), `pubspec.yaml` (bascule Flutter MODIF), `test/z_annotation_toolbar_test.dart`/`z_annotation_panel_test.dart`/`source_policy_test.dart` (NEW).

## Verdict : APPROUVÉ — story reste VERTE, aucun finding bloquant

Story de très bonne facture. Les gardes WCAG (cœur AD-13) sont **réellement discriminantes** : les 5 injections indépendantes rejouées ci-dessous neutralisent la LIGNE DE PROD protégée et **rougissent** — aucune « accessibilité fantôme ». Aucun HIGH/MAJEUR/MEDIUM ne survit à la vérification. Findings restants : LOW (polish a11y + réutilisation) + 1 informational (dette déférée DW-ES82-1 à escalader par l'orchestrateur).

## Vérif verte rejouée RÉELLEMENT (RC hors pipe — R15 ; runner Flutter — R14)

| Vérif | Résultat |
|---|---|
| `flutter test` (suite COMPLÈTE zcrud_document, domaine + présentation) | **RC=0 — 195 tests** (dont 25 ES-8.2) |
| `flutter test` (3 suites ES-8.2 ciblées) | **RC=0 — 25 tests** |
| `python3 scripts/dev/graph_proof.py` | **RC=0** — ACYCLIQUE OK, CORE OUT=0 OK ; `zcrud_document → {zcrud_annotations, zcrud_core, zcrud_generator, zcrud_study_kernel}` = **4 arêtes préexistantes, 0 nouvelle** |
| `melos list` | **20 packages** |
| `melos exec --scope=zcrud_document -- dart analyze` | **RC=0 — SUCCESS** |

## Preuves R3 — pouvoir discriminant VÉRIFIÉ PAR LE REVIEWER (injections indépendantes, restaurées R13)

Chaque injection neutralise la ligne de prod que l'AC protège ; test rejoué `--name` HORS pipe ; restauration ciblée ensuite. Intégrité confirmée : `grep INJ-PROBE lib/` = vide + suite complète 195 verte APRÈS restauration.

| # | AC (cœur WCAG) | Neutralisation appliquée par le reviewer | Résultat |
|---|----|----|----|
| P1 | **AC5** (contraste mesuré) | `markerColor = pair.color` (marqueur = fond) | **RED** (ratio < 3 sur swatch claire) |
| P2 | **AC3** (couleur ≠ seul canal) | `Semantics.label` swatch → `'swatch'` (uniformisé) | **RED** (labels non distincts) |
| P3 | **AC8a** (SM-1 granulaire) | rangée kinds ré-écoute `selectedColorKey` | **RED** (`kindRowBuilds` 1→11) |
| P4 | **AC4** (marqueur structurel R24) | `if (false)` sur le marqueur keyé | **RED** (`find.byKey` → 0) |
| P5 | **AC9** (lazy `ListView.builder`) | remplacé par `ListView(children:[...])` | **RED** (200 construits + delegate non-builder) |

⇒ Les gardes a11y les plus « piégeuses » (contraste, canal non-coloré, marqueur structurel, granularité, lazy) sont **non-powerless**. Cohérent avec les 10 injections du Dev Agent Record.

## Findings

### LOW-1 — Le marqueur de sélection re-dérive un premier plan au lieu d'utiliser `pair.onColor` garanti (réutilisation)
`z_annotation_toolbar.dart:254,322-329` — `_contrastingForeground(pair.color, scheme)` choisit entre `scheme.onSurface`/`scheme.surface` le plus contrasté avec le fond. Or `zResolveColorKeyOrSlot` renvoie déjà `pair.onColor`, **compagnon dont le contraste avec `pair.color` est GARANTI par Material 3** (contrat explicite de `ZColorPair`, cf. `z_color_key_resolver.dart:52-65`). Le code jette cette garantie et recalcule une logique de contraste déjà tenue en amont. Conforme à la prescription D6 (« dérivé du ColorScheme ») et fonctionne pour tous les schemes par défaut + les injections testées — mais pour un `ColorScheme` custom injecté dont `surface`/`onSurface` ne couvrent pas la plage de luminance, la dérivation pourrait sous-contraster alors que `pair.onColor` resterait correct. **Correctif recommandé (non bloquant)** : `final markerColor = pair.onColor;` (plus simple, plus robuste, honore le contrat). Passerait AC5 (onColor `#111111` vs `#EEEEEE` ≈ ratio 17).

### LOW-2 — Double annonce lecteur d'écran : `Semantics` explicite non exclusif au-dessus d'enfants `Text` (polish a11y)
`z_annotation_toolbar.dart:200-224` (`_KindButton`) et `z_annotation_panel.dart:173-183` (`_PanelEntry`) enveloppent un `Semantics(label:/value:)` explicite autour d'un sous-arbre qui contient aussi des `Text` (le libellé du kind, l'extrait, la page, `colorText`) **sans** `excludeSemantics: true` ni `MergeSemantics`. Un lecteur d'écran annonce donc le `label`/`value` explicite PUIS re-lit les nœuds `Text` descendants (verbosité/redondance). L'information reste présente (pas de perte a11y) → LOW. `_Swatch` n'est pas concerné (pas de `Text` enfant). **Correctif** : `excludeSemantics: true` sur le `Semantics` porteur, ou `MergeSemantics`. Les tests AC7 restent verts (ils n'assèrent que `isButton`/`label non vide`), donc la garde ne détecte pas la verbosité.

### LOW-3 — Deux gardes plus étroites que leur libellé (pouvoir discriminant partiel, code sous-jacent correct)
- `source_policy_test.dart:132-148` (AC13-e) affirme « aucun type Flutter/Color en signature publique des 2 widgets » mais **ne scanne que les identifiants du `show`** du barrel, jamais les **types de paramètres** des constructeurs. Or `ZAnnotationPanel({..., Widget? emptyState, Key? key})` expose bel et bien `Widget` en surface publique (sanctionné par D3 — override d'empty-state) : la garde resterait VERTE même si un paramètre exposait `Color`. Non bloquant (l'API `Widget? emptyState`/`Key?` est intentionnelle et inévitable pour un widget), mais la garde n'a pas le pouvoir de vérifier la propriété qu'elle énonce.
- `z_annotation_toolbar_test.dart:80-89` (AC2) vérifie qu'il existe **au moins une** swatch par `palette.keys` mais **ne compte pas le total** — l'énoncé story « nombre de swatches == palette.keys.length » (surplus de swatches non détecté). L'implémentation itère `widget.palette.keys` (count exact de fait), donc code correct ; garde partielle.
- `source_policy_test.dart:98-111` (AC13-d) matche `Color(0x` et `Colors.<name>` mais laisse passer `Color.fromARGB/fromRGBO/Color.from(...)` — non utilisés par l'impl ; complétude de scan.

### INFO — DW-ES82-1 : perte de couverture `gate:web` à ESCALADER (hors périmètre de cette revue)
Bascule Flutter ⇒ `zcrud_document` sort de `gate_web_determinism.dart` (exclut `sdk: flutter`) : les matrices de coercition JSON déterministe du domaine (`ZAnnotationBounds [0,1]`, `sanitizePage`, `sanitizeExtra`) ne sont plus rejouées sous `dart test -p node`. **AUCUNE régression** (tout tourne sous VM via `flutter test`, 195 verts). Consignée dans `pubspec.yaml` + `source_policy_test.dart`. L'escalade documentaire vers `architecture.md § Deferred` (jumeau DW-ES-6.1-1) **reste à faire par l'orchestrateur** — non appliquée par cette revue (consigne de périmètre : ne pas toucher `architecture.md`).

## Conformité AD/FR vérifiée
- **AD-1** : 0 nouvelle arête (graph_proof), acyclique, CORE OUT=0, `melos list`=20. Barrel exporte via `show` bornés ; aucun type Flutter/Color dans les identifiants exportés (helpers `_wcagContrastRatio`/`_contrastingForeground` privés, non fuités).
- **AD-2/AD-15/SM-1** : `ZAnnotationToolController` = `ChangeNotifier` pur-Flutter (`package:flutter/foundation.dart` seul), `ValueListenable` par tranche ; owned/injected créé en `initState` ssi non injecté, disposé ssi possédé, **jamais recréé au build** (AC8b vérifié `identical`) ; tranches scopées par `ValueListenableBuilder` (AC8a P3 prouvé RED sous injection). Aucun gestionnaire d'état importé.
- **AD-13** : `Semantics` explicites (AC7), cibles ≥ 48 dp mesurées (AC6), couleur JAMAIS seul canal (AC3/AC4/AC5 prouvés discriminants), directionnel (`EdgeInsetsDirectional`/`WrapAlignment.start`/`TextAlign.start` ; scan AC13-c vert + RTL AC10 mirroré), `ListView.builder` (AC9 P5 prouvé RED sous injection).
- **AD-10** : rendu défensif — `colorKey ''`/`text null`/liste vide/`colorKeyResolver` absent → repli `ColorScheme`, empty-state, jamais de throw (AC12).
- **FR-26** : couleurs via `zResolveColorKeyOrSlot`/`ZcrudScope.colorKeyResolver`, libellés via `label()`/`ZcrudScope.labels` ; aucun hex en dur (scan AC13-d vert ; AC11 injection couleur/libellé honorée).
- **NFR-S10** : garde de pureté domaine AJOUTÉE (`source_policy_test.dart`) — `lib/src/domain/` sans Flutter/`dart:ui`.

## Recommandation de transition
Aucun finding bloquant. Les 3 LOW sont optionnels (polish a11y `excludeSemantics` = amélioration de qualité recommandée ; `pair.onColor` = simplification robuste). L'INFO DW-ES82-1 requiert l'action de l'orchestrateur (escalade `architecture.md § Deferred`) avant clôture d'epic. Story éligible `review → done`.

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-3 (scan AC13-d sous-scanne) | 🟡 LOW | ✅ **CORRIGÉ (volet fromARGB/fromRGBO)** | `test/source_policy_test.dart` AC13-d : le scan anti-couleur-en-dur ne couvrait que `Color(0x…)`/`Colors.<name>` ; ajout de `Color.fromARGB(…)` et `Color.fromRGBO(…)`. **Prouvé par l'orchestrateur** : injection d'un vrai `Color.fromARGB(...)` dans `z_annotation_panel.dart` fait ROUGIR le scan (`Actual: [...→ Color.fromARGB(…)]`, RC=1) ; restauré → RC=0. (Une injection en COMMENTAIRE reste verte — `_sourcesUnder` dépouille les commentaires, conception correcte.) Les sous-volets AC13-e (scan `show` du barrel, pas les types de params) et AC2 (compte de swatches) sont **consignés** : code sous-jacent correct (D3 sanctionne déjà les fuites de types), élargissement optionnel. |
| LOW-1 (marqueur via scheme.onSurface) | 🟡 LOW | 🟡 **CONSIGNÉ** | `markerColor` re-dérivé via `_contrastingForeground(pair.color, scheme)` au lieu de `pair.onColor`. Le code est **correct et vert partout** (AC5 contraste ≥3.0 satisfait). Basculer sur `pair.onColor` imposerait de supprimer `_contrastingForeground` (usage unique) et risquerait AC5 (`pair.onColor` = compagnon Material 3 non explicitement max-contraste). Robustesse optionnelle sur ColorScheme custom, pas un défaut ; consigné pour éviter de déstabiliser du vert. |
| LOW-2 (double Semantics) | 🟡 LOW | 🟡 **CONSIGNÉ** | `Semantics(label/value)` non exclusif au-dessus d'enfants `Text` → double annonce lecteur d'écran (verbosité). AC7 reste vert. Ajouter `excludeSemantics`/`MergeSemantics` toucherait l'arbre Semantics (risque de régression a11y) pour un gain de verbosité ; consigné. |
| DW-ES82-1 (gate:web) | INFO | ✅ **ESCALADÉ** | Escaladée dans `architecture.md § Deferred` (jumeau DW-ES-6.1-1), avec note sur le motif RÉCURRENT (chaque satellite domaine gagnant une UI perd `gate:web` → arbitrer une solution générique). |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_document (R14) → RC=0, **195 tests** · graph_proof RC=0 (0 nouvelle arête) · melos list=20 · analyze RC=0.

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; LOW-3 (scan) corrigé et prouvé ; LOW-1/LOW-2 consignés ; DW-ES82-1 escaladé.
