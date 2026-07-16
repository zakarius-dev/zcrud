# Code-review — Story EX-UI.2 : `ZResponsiveLayout`

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chargé — PAS de fallback disque).
- **Portée** : `packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart`, barrel `lib/zcrud_responsive.dart`, `test/z_responsive_layout_test.dart` ; contexte lu `lib/src/domain/z_window_size_class.dart`.
- **Posture** : adversariale. Lecture seule. Aucune modification de code ni de sprint-status.
- **Vérif verte rejouée réellement sur disque** :
  - `dart analyze packages/zcrud_responsive` → **RC=0** (No issues found).
  - `flutter test` (repo) → **RC=0**, **49/49** verts (dont les tests EX-UI.2 neufs + EX-UI.1).
  - `grep ZResponsiveLayout` hors package → **aucune** référence externe (feuille du graphe, AD-1 intact).

## Synthèse sévérité

| Sévérité | Nombre |
|---|---|
| HIGH | **0** |
| MEDIUM | **0** |
| LOW | 4 |

**Aucun finding HIGH ou MEDIUM.** Les 6 AC sont satisfaits ET testés. Findings LOW uniquement (complétude de test / cosmétique), non bloquants.

## Revue par axe adversarial

1. **AC1..AC6 satisfaits + testés** — OUI. AC1 (API 3 `WidgetBuilder`, `compact` requis) : conforme, ctor `const`. AC2 (sélection via `LayoutBuilder` → `fromWidth(constraints.maxWidth)`, bornes 599/600/839/840) : testé aux 4 frontières. AC3 (cascade) : 3 cas testés. AC4 (`StatelessWidget`, 0 gestionnaire d'état) : conforme (voir LOW-4). AC5 (RTL + split/imbriqué) : testé. AC6 (barrel + gates) : conforme.
2. **Cascade descendante `expanded ?? medium ?? compact`** — CORRECTE. `_builderFor` (l.62-71) : `expanded → expanded ?? medium ?? compact`, `medium → medium ?? compact`, `compact → compact`. Jamais de remontée, jamais `null`. `compact` requis = plancher anti-écran-vide (AD-10). Les 3 cas de builder manquant sont couverts un à un (compact seul ; compact+medium ; compact+expanded sans medium → redescend au plancher).
3. **Largeur LOCALE via `LayoutBuilder`** — CORRECTE. `constraints.maxWidth` (l.77), **jamais** `MediaQuery`/`Get.width`. Test « panneau 500 dp sous écran 1200 → compact » (l.155-181) prouve la lecture du conteneur, pas de l'écran ; test `LayoutBuilder` parent imbriqué (l.183-200) prouve la mesure du conteneur immédiat.
4. **AD-2/AD-15** — CONFORME. `StatelessWidget` pur, ctor `const`, aucun `setState`, imports = `flutter/widgets.dart` + import relatif domaine uniquement. Aucune arête `zcrud_*` neuve, CORE OUT=0 intact.
5. **AD-13 RTL invariant** — CONFORME. Sélection = fonction de `constraints.maxWidth` (directionnellement neutre). Tests RTL 500/700/1000 → même palier qu'en LTR.
6. **Seuils 600/840 NON recodés** — CONFORME. Zéro littéral 600/840 dans `z_responsive_layout.dart` ; délégation totale à `ZWindowSizeClass.fromWidth`.
7. **Barrel** — CONFORME. Une seule ligne d'export ajoutée (l.43) ; ré-exports `zcrud_core` (l.34-35) et exports domaine (l.38-39) intacts ; `directives_ordering` respecté (package: puis src/ alphabétique).
8. **Tests porteurs vs tautologiques** — MAJORITAIREMENT PORTEURS. Compteurs de non-invocation (l.73-99), bornes 599/600/839/840, marqueurs distincts par palier avec `findsNothing` sur les non-retenus. Réserves mineures ci-dessous.

## Findings LOW

- **LOW-1 — Non-invocation par compteurs limitée au palier medium** (`test/z_responsive_layout_test.dart:73-99`). Le test « compteurs » n'instrumente que la largeur 700 (medium) : `compact=0`, `expanded=0`, `medium=1`. La non-invocation aux paliers compact et expanded ne repose que sur l'absence de marqueur (`findsNothing`). Impact : garde plus faible qu'un compteur direct. Correction (optionnelle) : dupliquer le test compteurs à 500 (compact) et 1000 (expanded).
- **LOW-2 — Tests RTL sans assertion `findsNothing`** (`test/z_responsive_layout_test.dart:203-225`). Chaque cas RTL n'affirme que `findsOneWidget(expectedKey)` ; il ne vérifie pas l'absence des autres marqueurs. Impact : un hypothétique double-rendu passerait sous RTL. Correction : ajouter les `expect(find.byKey(k), findsNothing)` pour les paliers non retenus, comme dans les tests LTR.
- **LOW-3 — `.gitkeep` résiduel** (`lib/src/presentation/.gitkeep`). Superflu depuis que le dossier est peuplé. Cosmétique, déjà signalé dans la story (question 2). Correction : suppression optionnelle.
- **LOW-4 — AC4 (absence d'import gestionnaire d'état) non gardé par un test statique** (`z_responsive_layout.dart`). L'invariant « aucun import `get`/`flutter_riverpod`/`provider`/`go_router` » n'est vérifié que par revue (T3.2 l'assume). Vrai à ce jour, mais aucune protection anti-régression locale. Correction (optionnelle) : ajouter un test de scan source, ou s'en remettre au gate repo `no_*` de l'orchestrateur.

## Verdict

**PRÊT POUR `done`.** Aucun finding HIGH/MEDIUM à remédier avant clôture. Les 4 LOW sont optionnels (complétude de test / cosmétique) et peuvent être consignés sans blocage. La story est verte sur disque (analyze RC=0, 49/49 tests), respecte AD-1/AD-2/AD-10/AD-13/AD-31 et NFR-U1/U7/U11, et n'introduit aucune arête `zcrud_*` ni redéclaration de seuil.
