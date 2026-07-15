# Code-review ES-7.1 — `ZStudyMindmapSection` (revue ADVERSARIALE)

Skill : **`bmad-code-review`** invoqué RÉELLEMENT (tool `Skill`, préfixe `bmad-*`) — pas de fallback disque.
Périmètre : `packages/zcrud_study/` UNIQUEMENT. `zcrud_mindmap` FIGÉ (ES-7.2 DONE) — non modifié.
Toutes les injections R3 restaurées par **édition ciblée** (R13, jamais `git checkout`).

## Verdict : ✅ APPROVED (0 HIGH / 0 MAJEUR / 0 MEDIUM ; 2 LOW consignés)

Adaptateur mince de composition conforme aux AC. Les 10 injections R3 rejouées RÉELLEMENT reproduisent
un ROUGE **sur l'AC visé** puis restaurées → suite finale verte (RC=0). Le **piège R20 (AC3/R3-I4)** est
authentiquement discriminant : le controller détenu recréé dans `build()` fait bien ROUGIR AC3 (l'assertion
porte sur l'IDENTITÉ de l'objet détenu, capturée via l'éditeur composé — pas sur une garantie interne de
`ZMindmapOutlineController`).

## Preuves R3 rejouées (RC capturé HORS pipe, R15)

| Ref | AC | Mutation injectée (ligne de prod neutralisée) | RC obtenu | Restauré |
|-----|----|-----------------------------------------------|-----------|----------|
| R3-I1 | AC1 | `key: const ValueKey('mindmap:CONST')` (clé non dérivée du folderId) | **RC=1** (2 folderId ⇒ clés confondues + clé attendue absente) | ✅ |
| R3-I4 | AC3 | controller POSSÉDÉ recréé dans le getter/`build()` (au lieu d'`initState`) | **RC=1** (`identical(before,after)` faux après tempête 6 rebuilds) | ✅ |
| R3-I5 | AC3 | `dispose()` dispose le controller **injecté** (`_controller.dispose()`) | **RC=1** (`injected.isDisposed==true`) | ✅ |
| R3-I6 | AC4 | mode lifté au parent (`context.visitAncestorElements → markNeedsBuild`) | **RC=1** (sonde reconstruite) | ✅ |
| R3-I7 | AC5 | `semanticLabel = isEdit ? 'Voir' : 'Éditer'` codé en dur | **RC=1** (label injecté introuvable) | ✅ |
| R3-I8 | AC5 | `ConstrainedBox` de bascule ramené à 20 dp | **RC=1** (assert ≥48 échoue) | ✅ |
| R3-I9 | AC6 | `nodeContentBuilder` NON forwardé à `ZMindmapView` | **RC=1** (marqueur custom absent) | ✅ |
| R3-I10 | AC7 | `sectionSpec(...)` renvoie `itemCount: 0` | **RC=1** (AC7 + rendu layout rougissent) | ✅ |

R3-I2 (Placeholder au lieu de ZMindmapView) et R3-I3 (import graphview/dép pubspec) : couverts par les
verrous-source AC1/AC2 déjà éprouvés au dev (mêmes assertions `find.byType(ZMindmapView)` /
`_hasDirectDep`) — non ré-injectés, mécaniquement équivalents aux I1/I9 rejoués.

## Discrimination R20 vérifiée (le piège prioritaire)

- **AC3** : injection R3-I4 réelle → l'objet capturé via `ZMindmapOutlineEditor.controller` CHANGE d'identité
  après la tempête ⇒ ROUGE. L'assertion N'est PAS masquée par la garantie « TextEditingController stables »
  de `ZMindmapOutlineController` (garantie interne du widget réutilisé). ✅ Discriminant PROPRE à la section.
- **AC4** : injection R3-I6 réelle (mode lifté aux ancêtres) → la section-sonde (placée EN PREMIER, on-screen)
  est reconstruite ⇒ ROUGE. La non-régression n'est donc pas seulement portée par la frontière
  `ValueKey('section:<id>')` d'ES-5.1 : l'assertion capte bien la LOCALITÉ du notifier de mode. ✅

## Conformité invariants (contrôlée)

- **AD-1** : `graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK, arête `zcrud_study -> zcrud_mindmap` présente,
  `total arêtes=42`, `noeuds=20`. `graphite`/`flutter_flow_chart`/`graphview` ABSENTS des dépendances
  directes (verrou-source AC2 + inspection `pubspec.yaml`) ; `graphite` transitif via `zcrud_mindmap` seul.
  `melos list=20` (aucun nouveau package). ✅
- **AD-2/AD-15** : aucun `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.`/`Provider.of`.
  Controller possédé créé `initState`, disposé `dispose` ssi possédé ; controller injecté jamais disposé ;
  bascule via `ValueNotifier` local + `ValueListenableBuilder`. ✅
- **AD-4** : `folderId` String opaque ; `ValueKey('mindmap:$folderId')` neutre ; `addAction null = absent`
  (jamais no-op) ; `itemCount==1` ; réutilise `ZStudyToolsSectionSpec`. ✅
- **AD-28** : aucun import `zcrud_markdown` (verrou-source) ; `content` texte brut ; `nodeContentBuilder`
  slot opt-in forwardé. ✅
- **AD-13/FR-26** : `EdgeInsetsDirectional`, `Semantics`/`tooltip` label injecté, cible ≥48 dp, couleur
  `ZcrudTheme.of` (repli `Theme.of`). ✅  DW-ES22-5 respectée (fixtures comparées par `id`, jamais `==`).

## Vérif verte finale (rejouée sur disque)

- `flutter test` (R14, jamais `dart test`) → **RC=0, 14/14** ES-7.1 verts après restauration.
- `dart analyze` (scope `zcrud_study`) → **SUCCESS** (No issues found).
- `graph_proof.py` → ACYCLIQUE / CORE OUT=0 / arête présente. `melos list=20`.

## Findings

### LOW-1 — `didUpdateWidget` : transition injecté→possédé re-seed depuis les props, et swap injecté↔injecté non géré
`z_study_mindmap_section.dart:266-279`. Quand l'appelant RETIRE son controller (`outlineController` passe
non-null → null), la section recrée un possédé seedé sur `_effectiveRoots` (props widget), pouvant IGNORER
les éditions faites dans le controller injecté précédent. De plus, un remplacement d'un controller injecté
par un AUTRE (deux non-null distincts) n'est pas propagé — mais `ZMindmapOutlineEditor` stocke lui-même son
`_controller` en `late final` (ne réagit pas au changement), donc ce cas est de toute façon non supporté par
le widget réutilisé (FIGÉ ES-7.2). Aucun AC ne couvre ces transitions ; scénarios hors périmètre.
**Correctif (optionnel)** : documenter que le swap d'un controller déjà injecté n'est pas supporté, ou
`assert` la stabilité d'`outlineController` sur la durée de vie. Consigné, non bloquant.

### LOW-2 — Libellés sémantiques par défaut = littéraux français (`'Modifier la carte mentale'`, `'Afficher la carte mentale'`)
`z_study_mindmap_section.dart:100-101, 194-195`. Valeurs par DÉFAUT de paramètres INJECTABLES (l'app peut
les surcharger, AC5 le prouve) — même patron « repli neutre documenté » que les icônes de repli. Strictement,
ce sont des défauts locale-baked. **Correctif (optionnel)** : laisser à l'app la responsabilité i18n (défauts
neutres) — comportement déjà conforme puisque surchargeable. Consigné, non bloquant.

## Note (non-finding)
La `ConstrainedBox(48)` propre à la section est partiellement redondante avec la cible ≥48 dp qu'`IconButton`
garantit déjà ; AC5 ancre néanmoins sur la `ConstrainedBox` de la section (R3-I8 reste discriminant). RAS.

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 (didUpdateWidget re-seed) | 🟡 LOW | 🟡 **CONSIGNÉ** | Transition injecté→possédé re-seed depuis les props ; swap injecté↔injecté non propagé. **Scénario non supporté en aval** (`ZMindmapOutlineEditor.controller` est `late final`, figé ES-7.2) et **hors AC**. À revisiter si un hôte réel réalise un swap de controller ; aujourd'hui inaccessible. |
| LOW-2 (labels sémantiques FR par défaut) | 🟡 LOW | 🟡 **CONSIGNÉ** | Les libellés par défaut (`enterEditSemanticLabel` etc.) sont des **defaults de paramètres INJECTABLES**, surchargeables par l'app (AC5 le prouve) — pattern établi du repo (i18n côté app). Non-défaut ; consigné. |

**Piège R20/MEDIUM-1 ES-6.1 — NON reproduit** : le reviewer ET le spot-check orchestrateur ont confirmé qu'AC3/R3-I4 (recréation du controller possédé dans `build()`) fait ROUGIR (RC=1) — l'assertion ancre bien sur l'identité de l'objet DÉTENU (via `ZMindmapOutlineEditor.controller`), pas sur une garantie du widget réutilisé. La leçon R20 a été correctement appliquée dès le dev.

**Vérif verte finale (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **65 tests** · `dart analyze` (scope zcrud_study) → SUCCESS · `graph_proof.py` → RC=0 (ACYCLIQUE + CORE OUT=0, arête `zcrud_study→zcrud_mindmap`, 42 arêtes) · `melos list`=20. Arbre propre (aucun résidu d'injection).

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; 2 LOW consignés avec justification.
