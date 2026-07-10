# Story E11a.1 : zcrud_geo (sous-ensemble) — modèle géo neutre + champ géo/carte

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant zcrud dans DODLP (banc d'essai parité SM-2)**,
je veux **un champ d'édition géo (`location`/`geoArea`) qui saisit/affiche des coordonnées neutres et les rend sur une carte via un adaptateur optionnel injecté**,
afin que **la parité DODLP soit atteinte AVANT E7 sans faire fuiter aucun SDK de carte ni aucune clé API dans le cœur (AD-1/AD-12), et sans reconstruction globale du formulaire (AD-2)**.

## Contexte & cadrage

**Épopée E11a — Lot parité DODLP** (sous-ensemble MVP de geo/intl/export). E11a **précède E7** (le graphe de dépendances prime sur la numérotation) : `E7 dépend de E11a`. Cette story est la **première d'E11a** et démarre l'épopée.

**Périmètre STRICT E11a-1 = champ géo + carte UNIQUEMENT.** Hors périmètre (frontière explicite) :
- **E11a-2** : `zcrud_intl` — téléphone international / pays / adresse (`phoneNumber`/`country`/`address`).
- **E11a-3** : `zcrud_export` — export DataGrid Excel/PDF (Syncfusion) + retrait `badCertificateCallback`.
- **E11b** : géo COMPLET au-delà de la parité MVP (second adaptateur, géocodage, dessin de polygones avancé, clustering…).

> Cette story se développe **EN PARALLÈLE d'E6 (`zcrud_markdown`)**. Elle reste **strictement** dans `packages/zcrud_geo/`. **Aucune modification de `zcrud_core`** n'est nécessaire (voir la section *Impact zcrud_core* ci-dessous) — l'orchestrateur n'a donc **pas** à sérialiser de fichier core avec E6.

### État réel du terrain (vérifié sur disque)

- **E1..E5 `done`, E6 en cours.** Le cœur fournit tout ce qu'il faut : le champ géo n'exige **rien de neuf** dans `zcrud_core`.
- **`EditionFieldType.location` et `EditionFieldType.geoArea` existent déjà** (`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`, lignes 100 & 103) — livrés en E3-3a. **Ne pas ajouter de valeur d'enum.**
- **Le seam d'injection de widget existe déjà** : `ZWidgetRegistry` (`packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart`, E3-3b-1), instanciable, injecté via `ZcrudScope.widgetRegistry` (`zcrud_scope.dart`, champ `widgetRegistry`).
- **Le dispatcher route déjà les types « servis ailleurs »** : `ZFieldWidget` (`z_field_widget.dart`) classe `location`/`geoArea` dans la famille **`registryOrFallback`** et, au build (lignes 437-444) :
  ```dart
  final registry = ZcrudScope.maybeOf(context)?.widgetRegistry;
  final builder  = registry?.tryBuilderFor(field.type.name); // kind = "location" | "geoArea"
  if (builder == null) return ZUnsupportedFieldWidget(field: field); // repli contrôlé, jamais d'exception
  return builder(context, ZFieldWidgetContext(field: field, value: <slice>, onChanged: <setValue>));
  ```
  Le builder est appelé **DANS** la frontière de rebuild (`ZFieldListenableBuilder`, value-in-slice). La granularité AD-2 au niveau de la tranche est donc **déjà assurée par le cœur** ; le widget géo n'a qu'à respecter AD-2 **en interne** (contrôleur stable, pas de recréation).
- **`zcrud_geo` est un squelette** : `pubspec.yaml` (dépend uniquement de `zcrud_core: ^0.0.1`), barrel `lib/zcrud_geo.dart`, marqueur `lib/src/domain/z_geo_api.dart`. C'est ici que vivent le modèle de valeur, le widget et l'adaptateur.

### ADs applicables (NON-NÉGOCIABLES)

- **AD-1** — `zcrud_geo → zcrud_core` seulement ; le SDK carte (google_maps_flutter/flutter_map) ne fuit **jamais** dans `zcrud_core` ; adaptateurs carte **OPTIONNELS** ; graphe acyclique préservé.
- **AD-2 / SM-1** — champ à **contrôleur isolé stable** (create/dispose, jamais recréé), `ValueKey` déjà posé par l'assembleur du cœur, rebuild ciblé à la tranche, focus préservé pendant la saisie de coordonnées. Interdits : `setState` de formulaire, ré-injection de valeur dans le contrôleur pendant la frappe.
- **AD-4** — le widget géo est fourni par le satellite et **enregistré** dans `ZWidgetRegistry` (instanciable, injecté ; jamais un singleton statique mutable). `kind` = **nom d'enum** (`"location"`, `"geoArea"`), aligné sur la convention `ZTypeRegistry`.
- **AD-10** — désérialisation **défensive** : coordonnées absentes / non numériques / hors-bornes (lat ∉ [-90,90], lng ∉ [-180,180]) → état neutre/vide, **jamais** de crash ni d'exception qui remonte au parent (`fromJsonSafe → null`, `@JsonKey(defaultValue)`).
- **AD-12** — **AUCUNE clé API ni secret** dans `zcrud_geo` (la clé Maps est fournie par la config plateforme de l'app hôte ; dépend d'E1-5, révocation déjà faite). Interdits : `badCertificateCallback => true`, endpoint en dur non surchargeable.
- **AD-13** — RTL (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional`), `Semantics` explicites, cibles tactiles **≥ 48 dp**, thème **injecté** via `ZcrudTheme.of(context)` (repli `Theme.of(context)`) — **aucune** couleur/style codé en dur.
- **AD-14/AD-15** — couche `domain/` du modèle de valeur = **Dart pur** (aucun Flutter/SDK carte) ; **aucun** gestionnaire d'état importé (primitives Flutter uniquement) ; la présentation (widget) peut dépendre de Flutter.

## Conception (résumé pour le dev)

1. **Modèle de valeur géo NEUTRE** (couche `domain/`, pur-Dart, sérialisable, `@JsonSerializable`/codegen ou `toMap/fromMap` manuel léger) :
   - `ZGeoPoint { double lat; double lng; String? label; String? address; }` → valeur de tranche pour `location`.
   - `ZGeoShape` (nom imposé par l'épopée) : aire/polygone = `List<ZGeoPoint> vertices` (+ éventuel `String? label`) → valeur de tranche pour `geoArea`. Un point unique reste un cas dégénéré exploitable.
   - **Agnostique SDK** : que des `double`/`String`/`List` — **aucun** `LatLng` google/osm dans la signature publique. Bornes validées à la construction/parse (défensif AD-10, pas d'assert dur).
   - `fromMap`/`fromJsonSafe` **défensif** : champ manquant/non numérique/hors-bornes → `null` (point) ou point ignoré (shape), jamais d'exception.
2. **Interface d'adaptateur carte OPTIONNELLE** (`ZMapAdapter`, couche `domain` ou `presentation`, **pure** de tout SDK lourd) :
   - Contrat minimal : rendre une carte centrée sur un `ZGeoPoint`/`ZGeoShape`, remonter un tap → `ZGeoPoint` (callback), disposer proprement son contrôleur natif. Signature en **types neutres uniquement**.
   - Le/les adaptateur(s) concret(s) (OSM `flutter_map` **ou** Google `google_maps_flutter`) portent la dépendance lourde **hors de la voie d'import par défaut** de `zcrud_geo` (fichier/point d'entrée dédié). **Recommandé MVP : OSM (`flutter_map`)** car **sans clé API** → meilleur alignement AD-12. Un seul adaptateur suffit à la parité (épopée : « Google **ou** OSM »).
3. **Widget de champ géo** (`ZGeoFieldWidget`, `StatefulWidget`, patron AD-2) branché via une **factory de builder** :
   - `ZGeoFieldWidget.builder({ZMapAdapter? mapAdapter}) → ZFieldWidgetBuilder` : renvoie la closure `(context, ZFieldWidgetContext ctx) => ZGeoFieldWidget(...)`. L'app enregistre `registry.register('location', ZGeoFieldWidget.builder(mapAdapter: osmAdapter))` (et/ou `'geoArea'`). **L'adaptateur est capturé par closure** → **aucun** nouveau slot dans `zcrud_core`, **aucun** `ZcrudScope` étendu.
   - Interne : `TextEditingController`(s) pour lat/lng créé(s) **1× en `initState`**, `dispose` en `dispose`, **jamais** recréé ni ré-injecté pendant la frappe (sync guardée hors focus). `FocusNode` stable. Lit `ctx.value` (neutre), écrit via `ctx.onChanged` (branché sur `setValue`, reste dans la frontière de rebuild du cœur).
   - Rendu : zone de saisie coordonnées + (si `mapAdapter != null`) rendu carte via l'adaptateur ; **si `mapAdapter == null` → repli propre** (saisie coordonnées seule, éventuel aperçu statique/texte), **jamais** de crash.
   - Cycle de vie carte : le contrôleur natif de l'adaptateur est **disposé** (anti-fuite, learning E5).
4. **Isolation (AD-1)** — la lib carte lourde n'est déclarée **qu'au** `pubspec.yaml` de `zcrud_geo` (idéalement en dépendance de l'entrée adaptateur concret, pas du barrel principal) ; **aucun** type carte ne fuit dans `zcrud_core` ni dans la valeur de tranche ni dans les signatures publiques ; **aucun** secret dans le package.
5. **Défensif (AD-10)** — coordonnées absentes/invalides/hors-bornes → champ vide/état neutre.

### Impact zcrud_core

**NON — aucune modification de `zcrud_core`.** Justification vérifiée sur disque :
- Les valeurs d'enum `location`/`geoArea` **existent déjà** (E3-3a).
- Le seam `ZWidgetRegistry` + le routage `registryOrFallback` + le repli `ZUnsupportedFieldWidget` **existent déjà** (E3-3a/E3-3b-1).
- L'adaptateur carte est **capturé par closure** dans la factory de builder de `zcrud_geo` → **pas** besoin d'ajouter un slot `mapAdapter` à `ZcrudScope`.

→ **Aucune sérialisation de fichier core à prévoir avec E6.** Si, en cours de dev, un besoin de toucher `zcrud_core` apparaissait (p. ex. slot d'injection d'adaptateur dans `ZcrudScope`), **STOP + signalement à l'orchestrateur** avant d'éditer le cœur (risque de conflit avec E6). La conception ci-dessus est précisément faite pour l'éviter.

## Acceptance Criteria

1. **Modèle de valeur géo neutre & sérialisable (AD-1/AD-14).** `ZGeoPoint` (lat/lng + label/address optionnels) et `ZGeoShape` (`List<ZGeoPoint>`) vivent dans `zcrud_geo` (`domain/`, pur-Dart), exposent `toMap/fromMap` (ou codegen), round-trip stable. **Aucun** type SDK carte (`LatLng`, etc.) n'apparaît dans leur API publique. *Test : round-trip toMap→fromMap ; `dart analyze` ; grep signatures sans type SDK.*
2. **Champ géo servi via le registre (AD-4).** `ZGeoFieldWidget.builder({ZMapAdapter?})` renvoie un `ZFieldWidgetBuilder` enregistrable sous `kind` `"location"` et/ou `"geoArea"` dans `ZWidgetRegistry` ; via un `ZcrudScope(widgetRegistry: …)` un champ `location` rend le widget géo (et non `ZUnsupportedFieldWidget`). *Test widget : registre peuplé → widget géo présent ; registre vide → repli `ZUnsupportedFieldWidget`, pas de crash.*
3. **L'édition met à jour la tranche (valeur neutre) (AD-2).** Saisir/modifier des coordonnées écrit un `ZGeoPoint`/`ZGeoShape` dans la tranche via `ctx.onChanged` ; la valeur lue du `ZFormController` est la valeur neutre attendue. *Test widget : frappe → `controller.valueOf('geo')` == ZGeoPoint attendu.*
4. **Carte rendue via adaptateur injecté + repli propre (AD-1).** Avec un `ZMapAdapter` injecté (fake en test), la carte est rendue et un tap remonte un `ZGeoPoint` neutre via callback ; **sans** adaptateur (`null`), le champ dégrade proprement (saisie coordonnées seule), **aucun** crash. *Test widget : adaptateur fake présent → surface carte rendue + tap→valeur ; adaptateur null → repli, pas d'exception.*
5. **Défensif : coordonnées absentes/invalides/hors-bornes (AD-10).** Valeur de tranche `null`, map corrompue, lat/lng non numériques, lat=200 / lng=999 → champ en état neutre/vide, **jamais** d'exception remontant au parent. *Test : table de cas (absent, non-numérique, hors-bornes ×4 signes, shape avec sommet invalide ignoré) → état neutre, pas de throw.*
6. **SM-1 / rebuild ciblé + focus préservé (AD-2).** Saisir des caractères dans le champ coordonnées ne reconstruit **que** la tranche du champ géo (compteur de build voisin inchangé), **zéro** perte de focus / saut de curseur ; `TextEditingController`/`FocusNode` créés **1×** (`initState`), jamais recréés. *Test widget : hooks `onInit`(==1)/`onBuild` + `expect(focusNode.hasFocus, isTrue)` après frappe.*
7. **Anti-fuite de cycle de vie (learning E5).** `dispose` libère le(s) `TextEditingController`, le `FocusNode` **et** le contrôleur natif de l'adaptateur carte ; aucun listener/contrôleur non disposé. *Test : pump→pumpWidget(SizedBox) ; le fake adaptateur enregistre `disposed == true`.*
8. **Thème injecté + RTL + a11y ≥48 dp (AD-13).** Couleurs/styles via `ZcrudTheme.of(context)` (repli `Theme.of`) — **aucune** valeur codée en dur ; paddings/alignements **directionnels** ; `Semantics` explicites ; cibles tactiles (boutons/poignées) **≥ 48 dp**. *Test : rendu sous `Directionality.rtl` sans exception + audit statique (grep anti `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, couleur littérale).*
9. **Gate isolation — `zcrud_core` ne tire AUCUNE lib carte (AD-1).** Le `pubspec.yaml` de `zcrud_core` ne liste ni `google_maps_flutter`, ni `flutter_map`, ni `flutter_osm_plugin`, ni `latlong2` ; la lib carte n'apparaît qu'au `pubspec.yaml` de `zcrud_geo`. *Test/gate : assertion sur les dépendances (script/grep) ; `dart pub deps` de `zcrud_core` sans lib carte.*
10. **Gate secrets — AUCUNE clé API dans le package (AD-12).** Aucune clé Google Maps / token / endpoint en dur dans `zcrud_geo` ; aucun `badCertificateCallback => true`. *Gate : scan de secrets (E1-3/E2-10) vert sur `zcrud_geo` ; grep négatif.*
11. **Aucune fuite de type carte (AD-1, signature).** Ni la valeur de tranche, ni l'API publique de `zcrud_geo` (barrel `lib/zcrud_geo.dart`), ni `ZMapAdapter` n'exposent un type du SDK carte ; les types SDK restent **internes** à l'entrée adaptateur concret. *Test : inspection des exports du barrel + `dart analyze` ; le barrel n'exporte pas de symbole SDK.*
12. **Vérif verte rejouée.** `melos run generate` OK → `dart analyze` RC=0 → `flutter test` RC=0 sur `zcrud_geo` (et workspace inchangé). *Gate `done`.*

## Tasks / Subtasks

- [x] **T1 — Modèle de valeur géo neutre** (AC: 1, 5, 11)
  - [x] `lib/src/domain/z_geo_point.dart` : `ZGeoPoint` (lat/lng + label/address optionnels), `toMap`/`fromMap` + `fromMapSafe → null` défensif (bornes lat/lng, non-numérique, non-fini).
  - [x] `lib/src/domain/z_geo_shape.dart` : `ZGeoShape` (`List<ZGeoPoint> vertices`), parse défensif (sommet invalide ignoré, jamais throw ; tous invalides → aire vide neutre).
  - [x] Barrel : exporter uniquement les modèles neutres (pas de type SDK).
- [x] **T2 — Interface adaptateur carte optionnelle** (AC: 4, 11)
  - [x] `lib/src/presentation/z_map_adapter.dart` : abstraction `ZMapAdapter` en types neutres (rendu, tap→`ZGeoPoint`, `dispose`) — **sans** dépendance SDK lourde.
- [x] **T3 — Widget de champ géo (patron AD-2)** (AC: 2, 3, 4, 6, 7, 8)
  - [x] `lib/src/presentation/z_geo_field_widget.dart` : `StatefulWidget`, contrôleurs/focus stables `late final` (create `initState` / `dispose`), sync guardée hors focus, lecture `ctx.value` / écriture `ctx.onChanged`.
  - [x] Factory `ZGeoFieldWidget.builder({ZMapAdapter? mapAdapter}) → ZFieldWidgetBuilder` (capture de l'adaptateur par closure).
  - [x] Rendu conditionnel carte / repli sans adaptateur ; thème `ZcrudTheme.of`, RTL directionnel, `Semantics`, cibles ≥ 48 dp.
  - [x] Dispose du contrôleur natif de l'adaptateur.
- [x] **T4 — Adaptateur concret de parité (OSM)** (AC: 4, 9, 10)
  - [x] Entrée dédiée `lib/src/presentation/adapters/z_osm_map_adapter.dart` + export séparé `lib/adapters/osm.dart`, implémentant `ZMapAdapter` via `flutter_map` ; types SDK (`LatLng`/`MapController`/`FlutterMap`) confinés au fichier.
  - [x] `pubspec.yaml` de `zcrud_geo` : `flutter_map: ^8.3.1` + `latlong2: ^0.10.1` — **rien** dans `zcrud_core`. Aucune clé/secret (OSM public surchargeable).
- [x] **T5 — Barrel & exports** (AC: 11)
  - [x] `lib/zcrud_geo.dart` exporte modèles neutres + `ZMapAdapter` + factory du widget ; **pas** de symbole SDK (adaptateur OSM hors barrel principal).
- [x] **T6 — Tests** (AC: 1-8, 11) — voir *Stratégie de tests* (41 tests, tous verts).
- [x] **T7 — Gates** (AC: 9, 10, 12)
  - [x] Assertion dépendances (`zcrud_core` sans lib carte), scan secrets vert, `generate`+`analyze`+`test`+`verify` RC=0.

## Stratégie de tests

- **Unitaires modèle (pur-Dart)** : round-trip `ZGeoPoint`/`ZGeoShape` ; table défensive AD-10 (absent, non-numérique, hors-bornes ×signes, shape à sommet invalide).
- **Widget** : (a) registre peuplé → widget géo ; registre vide → `ZUnsupportedFieldWidget` (repli) ; (b) frappe coordonnées → tranche = `ZGeoPoint` neutre ; (c) adaptateur fake présent → surface carte + tap→valeur ; adaptateur null → repli sans crash ; (d) SM-1 : `onInit`==1, focus conservé, compteur build voisin inchangé ; (e) `dispose` → fake adaptateur `disposed==true` ; (f) rendu sous `Directionality.rtl` sans exception.
- **Fake `ZMapAdapter`** en test (pas de SDK réel) : évite de dépendre d'un vrai rendu carte, prouve le contrat (rendu/tap/dispose) — cœur de l'isolation AD-1.
- **Gates statiques** : grep anti-SDK dans le barrel + `zcrud_core/pubspec.yaml` ; grep anti-clé/`badCertificateCallback` ; grep RTL (anti `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`).

## Dev Notes

### Fichiers du cœur à NE PAS modifier (lecture de référence)

- `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` — `ZWidgetRegistry`, `ZFieldWidgetBuilder`, `ZFieldWidgetContext` (le contrat que la factory doit satisfaire).
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (l. 411, 425-445) — routage `registryOrFallback` → `tryBuilderFor(field.type.name)` → repli. Confirme : `kind == field.type.name` (`"location"`/`"geoArea"`), builder appelé dans la frontière de rebuild, `ctx.onChanged` = `setValue`.
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — `widgetRegistry`, `theme` (`ZcrudTheme.of`), `labels`. **Ne pas** ajouter de slot ; l'adaptateur passe par la closure de la factory.
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (l. 100, 103) — `location`/`geoArea` déjà présents.

### Patron AD-2 à répliquer (source E3-3a/E3-3b)

Le cœur pose déjà `ValueKey(field.name)` (assembleur `DynamicEdition`) et scelle la tranche via `ZFieldListenableBuilder`. Le widget géo **n'élargit pas** la frontière : contrôleur `late final` créé 1× (`initState`), `dispose`, jamais ré-injecté dans la voie de frappe ; écriture via `ctx.onChanged` uniquement. S'inspirer de `z_text_field_widget.dart` / `z_app_file_field_widget.dart` pour la sync guardée hors focus.

### Learnings absorbés

- **E5** : tester les cas RÉELS de désérialisation défensive (coordonnées absentes/invalides/hors-bornes) ; **disposer** tout contrôleur/ressource (ici : contrôleur carte de l'adaptateur) pour éviter la fuite de cycle de vie.
- **E3-3b** : `ZTypeRegistry` = **codec** (pur-Dart), `ZWidgetRegistry` = **widgets** (présentation). Le champ géo passe par `ZWidgetRegistry`, **pas** `ZTypeRegistry`.

### Project Structure Notes

- Tout sous `packages/zcrud_geo/lib/` : `src/domain/` (modèles neutres, pur-Dart, AD-14) ; `src/presentation/` (widget, adaptateur, dépend de Flutter). Barrel `lib/zcrud_geo.dart`. `*_test.dart` sous `test/`. Aucun `*.g.dart` committé.
- Nommage : types publics préfixés `Z` (`ZGeoPoint`, `ZGeoShape`, `ZMapAdapter`, `ZGeoFieldWidget`) ; fichiers snake_case ; enums persistés camelCase.

### Latest tech (à confirmer via `pub` au dev — versions indicatives 2026)

- **OSM (recommandé, sans clé) :** `flutter_map` (≈ ^7.x/^8.x) + `latlong2` (≈ ^0.9.x). Aucune clé API → alignement AD-12 optimal.
- **Google (alternative, clé plateforme) :** `google_maps_flutter` (≈ ^2.9.x) — la clé reste **hors package** (config Android/iOS de l'app, E1-5). Ne PAS l'introduire dans `zcrud_geo` en dur.
- Un **seul** adaptateur suffit à la parité E11a-1 (épopée : « Google **ou** OSM »). Le second adaptateur = E11b.
- Confirmer la compat SDK Dart `^3.12.2` du workspace et le gate compat (E1-4, `dart pub get --dry-run`).

### References

- [Source: epics.md#E11a — Story E11a-1] (`_bmad-output/planning-artifacts/epics/.../epics.md` l. 111-116) — `ZGeoShape` + champ géo/carte ; modèle agnostique SDK ; aucune clé dans le package ; adaptateur Google **ou** OSM.
- [Source: architecture.md#AD-1] l. 57-60 — direction de dépendance acyclique ; SDK carte confiné.
- [Source: architecture.md#AD-2] l. 62-65 — rebuilds granulaires, contrôleur stable.
- [Source: architecture.md#AD-4] l. 71-75 — extension par registre injecté (jamais singleton statique).
- [Source: architecture.md#AD-10] l. 102-105 — désérialisation défensive.
- [Source: architecture.md#AD-12] l. 112-115 — zéro secret ; pas de `badCertificateCallback`.
- [Source: architecture.md#AD-13] l. 117-120 — RTL/a11y/thème injecté.
- [Source: architecture.md#Stack] l. 171 — `google_maps_flutter`/`flutter_osm_plugin` optionnels confinés à `zcrud_geo`.
- [Source: zcrud_core] `z_widget_registry.dart`, `z_field_widget.dart` (l. 411/425-445), `zcrud_scope.dart`, `edition_field_type.dart` (l. 100/103).
- [Source: CLAUDE.md] Key Don'ts — jamais de secret/clé Maps dans un package ; jamais de type carte lourd dans `zcrud_core` ; thème injecté ; RTL directionnel ; cibles ≥ 48 dp.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- `dart run melos run generate` → SUCCESS (RC=0 ; no-op pour `zcrud_geo`, aucun modèle annoté).
- `dart run melos run analyze` → SUCCESS, **0 issue** (workspace complet, RC=0).
- `flutter test` (`packages/zcrud_geo`) → **41 tests, tous verts** (RC=0).
- `dart run melos run verify` → RC=0 (graphe ACYCLIQUE + **CORE OUT=0**, gate secrets, reflectable, codegen, compat, serialization).
- `melos list` = **14** (invariant produit préservé).
- Résolution : `flutter_map 8.3.1` + `latlong2 0.10.1` (SDK Dart `^3.12.2`, Flutter 3.44.4).

**Remédiation code-review E11a-1 (2026-07-10) — vérif verte rejouée (ciblée `zcrud_geo`) :**
- `flutter analyze` (`packages/zcrud_geo`) → **0 issue** (RC=0).
- `flutter test` (`packages/zcrud_geo`) → **52 tests, tous verts** (RC=0 ; +11 vs 41 : MAJEUR-1 ×2, MEDIUM-2 ×4, MEDIUM-3 ×2, LOW-4/LOW-5/LOW-6 ×1).
- `python3 scripts/dev/graph_proof.py` → **CORE OUT=0**, ACYCLIQUE, 14 nœuds (RC=0).

### Completion Notes List

- **12/12 ACs satisfaits.** `zcrud_core` **NON touché** (aucune modification du cœur : enum `location`/`geoArea`, `ZWidgetRegistry`, routage `registryOrFallback` et repli `ZUnsupportedFieldWidget` déjà présents ; adaptateur capturé par closure de factory — aucun slot `ZcrudScope` ajouté).
- **Modèles neutres pur-Dart** (`ZGeoPoint`/`ZGeoShape`) : uniquement `double`/`String`/`List`, aucun `LatLng`. Parse défensif AD-10 réel (absent / non numérique / non fini NaN-Inf / hors-bornes ×4 signes / sommet invalide ignoré → état neutre, jamais de throw).
- **`ZMapAdapter`** port pur (types neutres) ; **`ZOsmMapAdapter`** (flutter_map, sans clé API) confiné à `src/presentation/adapters/` + entrée `lib/adapters/osm.dart` (hors barrel principal). Aucun type carte ne fuit en signature publique ni en valeur de tranche.
- **`ZGeoFieldWidget`** patron AD-2 : `TextEditingController`/`FocusNode` `late final` créés 1× (initState), jamais recréés ; sync guardée hors focus ; écriture via `ctx.onChanged` uniquement ; dispose du contrôleur natif de l'adaptateur (anti-fuite E5, prouvé par `FakeMapAdapter.disposed`). Repli propre coordonnées-seules si `mapAdapter == null` (aucun crash).
- **SM-1** prouvé : frappe → seule la tranche du champ se reconstruit (compteur voisin inchangé), `onInit == 1`, focus préservé.
- Thème via `ZcrudTheme.of` (repli `Theme.of`), zéro couleur en dur ; RTL directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`) ; `Semantics` explicites ; cibles ≥ 48 dp. Gate statique RTL (test) vert.
- **Isolation prouvée** : `zcrud_core/pubspec.yaml` sans lib carte (gate test) ; barrel principal sans symbole SDK (directives inspectées) ; gate secrets vert (aucune clé Google/`badCertificateCallback`).

#### Remédiation des findings code-review E11a-1 (2026-07-10)

- **MAJEUR-1 (adaptateur partagé → aliasé/disposé par chaque montage) — CORRIGÉ.** Passage d'une **instance** partagée à une **fabrique** `ZMapAdapterFactory = ZMapAdapter Function()` (nouveau typedef dans `z_map_adapter.dart`). `ZGeoFieldWidget.builder({ZMapAdapterFactory? adapterFactory})` ; le `State` appelle la fabrique **1× en `initState`** pour créer son instance possédée `_mapAdapter`, disposée en `dispose` — jamais aliasée, jamais réutilisée après dispose. Contrat « une instance par montage » désormais **honoré**. Callers mis à jour (`lib/adapters/osm.dart` → `adapterFactory: ZOsmMapAdapter.new`). Tests : 2 champs géo montés simultanément → **2 instances distinctes** + 2 surfaces ; remontage → **nouvelle instance**, ancienne disposée sans affecter la neuve.
- **MEDIUM-2 (dispose OSM non testé) — CORRIGÉ.** Nouveau `test/z_osm_map_adapter_test.dart` instanciant le **vrai** `ZOsmMapAdapter` : `dispose()` idempotent (2 appels, `returnsNormally`), dispose immédiat sans montage, et `buildMap` rendu réellement (location + geoArea) sous `MaterialApp` sans exception (confinement SDK).
- **MEDIUM-3 (perte de sommet geoArea, lost update même frame) — CORRIGÉ.** État local `_workingShape` « au fil de l'eau » (source atomique via `_currentShape`), amorcé en `initState`, réconcilié en `didUpdateWidget` avec une valeur externe (l'écho de notre propre émission n'écrase rien, égalité de valeur `ZGeoShape`). `_appendVertex`/`_removeVertex` mutent `_workingShape` **avant** d'émettre. Test : 2 taps carte dans la même frame (sans pump intermédiaire) → **2 sommets présents**.
- **LOW-4 (chaînes/dimensions en dur) — CORRIGÉ.** `'Ajouter'` routé via `label(context, 'geo.addVertex', fallback: 'Ajouter')` (l10n injectée `ZcrudScope.labels`) ; hauteur carte exposée en paramètre `mapHeight` (injectable, défaut 200). Test : `ZcrudScope.labels` surcharge bien le libellé. (Les `label` Semantics `ajouter-sommet`/`retirer-sommet-$i` sont des identifiants d'a11y stables, non des textes visibles → conservés.)
- **LOW-5 (`_pointOf` fait confiance à un `ZGeoPoint` hors-bornes) — CORRIGÉ.** Re-check `isValid` en lecture : `value is ZGeoPoint ? (value.isValid ? value : null) : fromMapSafe(value)` → jamais de coordonnée hors-bornes envoyée au centre carte. Test : `ZGeoPoint(200,999)` programmatique en tranche → champs vides, pas de throw.
- **LOW-6 (SM-1 prouvé sur slice fait-main) — CORRIGÉ.** Test bout-en-bout ajouté via le **vrai dispatch** `DynamicEdition` : focus préservé après deux frappes (chemin `ZFieldWidget`/registry/`ZFieldListenableBuilder` réel).

### File List

**Créés**
- `packages/zcrud_geo/lib/src/domain/z_geo_point.dart`
- `packages/zcrud_geo/lib/src/domain/z_geo_shape.dart`
- `packages/zcrud_geo/lib/src/presentation/z_map_adapter.dart`
- `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart`
- `packages/zcrud_geo/lib/src/presentation/adapters/z_osm_map_adapter.dart`
- `packages/zcrud_geo/lib/adapters/osm.dart`
- `packages/zcrud_geo/test/support/fake_map_adapter.dart`
- `packages/zcrud_geo/test/z_geo_point_test.dart`
- `packages/zcrud_geo/test/z_geo_shape_test.dart`
- `packages/zcrud_geo/test/z_geo_field_widget_test.dart`
- `packages/zcrud_geo/test/isolation_gates_test.dart`
- `packages/zcrud_geo/test/z_osm_map_adapter_test.dart` _(remédiation MEDIUM-2)_

**Modifiés**
- `packages/zcrud_geo/pubspec.yaml` (package Flutter ; deps `flutter`, `flutter_map ^8.3.1`, `latlong2 ^0.10.1`, `zcrud_core` ; dev `flutter_test`).
- `packages/zcrud_geo/lib/zcrud_geo.dart` (barrel : modèles neutres + `ZMapAdapter` + `ZGeoFieldWidget` ; aucun symbole SDK).

**Modifiés (remédiation code-review E11a-1, 2026-07-10)**
- `packages/zcrud_geo/lib/src/presentation/z_map_adapter.dart` (typedef `ZMapAdapterFactory` + contrat « une instance par montage » — MAJEUR-1).
- `packages/zcrud_geo/lib/src/presentation/z_geo_field_widget.dart` (fabrique d'adaptateur possédée en `initState` — MAJEUR-1 ; `_workingShape` atomique — MEDIUM-3 ; `label()` + `mapHeight` — LOW-4 ; `_pointOf` re-check `isValid` — LOW-5).
- `packages/zcrud_geo/lib/adapters/osm.dart` (exemple mis à jour : `adapterFactory: ZOsmMapAdapter.new`).
- `packages/zcrud_geo/test/z_geo_field_widget_test.dart` (helper `_registryFactory` + tests MAJEUR-1 ×2, MEDIUM-3 ×2, LOW-4, LOW-5, LOW-6).

**NON modifiés** : `zcrud_core` (aucun fichier), tout autre package.
