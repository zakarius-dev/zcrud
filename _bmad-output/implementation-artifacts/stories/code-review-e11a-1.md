# Code Review — E11a-1 : zcrud_geo (champ géo + carte)

- **Story** : `e11a-1-zcrud-geo-champ-geo-carte.md` (statut `review`, 12 ACs)
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` ; step-file `steps/step-01-gather-context.md` chargé)
- **Périmètre revu** : `packages/zcrud_geo/` uniquement (code + 5 fichiers de test). `zcrud_core` lu en référence, NON modifié. `zcrud_markdown`/`example` hors périmètre (E6-2/EX-2 parallèles) — non touchés.
- **Mode** : revue adversariale, lecture seule. Aucune modification de code ni de `sprint-status.yaml`.
- **Vérifs orchestrateur (reprises)** : analyze 0 issue ; 41 tests verts ; `zcrud_core/pubspec.yaml` sans lib carte ; CORE OUT=0 ; `zcrud_core` intact. Confirmés cohérents avec la lecture disque.

---

## Verdicts synthétiques

| Axe | Verdict | Preuve |
|---|---|---|
| Isolation carte (AD-1) | **OUI** | `flutter_map`/`latlong2` au seul `zcrud_geo/pubspec.yaml` ; barrel `zcrud_geo.dart` n'exporte que modèles neutres + `ZMapAdapter` + widget ; OSM atteint uniquement via `lib/adapters/osm.dart` ; aucun `import flutter_map/latlong2` hors `z_osm_map_adapter.dart` |
| Valeur form neutre | **OUI** | tranche = `ZGeoPoint`/`ZGeoShape` (double/String/List seulement) ; aucun `LatLng` en signature publique ; conversion SDK confinée à l'adaptateur |
| No-secret (AD-12) | **OUI** | OSM sans clé ; `tileUrlTemplate` surchargeable ; aucun `badCertificateCallback` ; `userAgentPackageName` = valeur d'exemple, pas un secret ; gate de scan présent |
| SM-1 réellement prouvé (AD-2) | **OUI (avec réserve)** | `initA==1`, `buildB` inchangé, `focusNode.hasFocus` vrai après frappe — non-proxy. Réserve : prouvé sur un slice `ValueListenableBuilder` fait-main, pas via le vrai dispatch `DynamicEdition→ZFieldWidget` (LOW-6) |
| Défensif cas réels (AD-10) | **OUI** | table `ZGeoPoint`/`ZGeoShape` : absent, non-num, NaN/Inf, hors-bornes ×4, sommet invalide ignoré ; lat valide + lng invalide couvert (parse + `_emitPointFromFields`) |
| Anti-fuite | **OUI (widget) / partiel (OSM)** | 4 contrôleurs + focus + adaptateur disposés ; `FakeMapAdapter.disposed` prouvé. Idempotence OSM implémentée mais NON testée (MEDIUM-2) |
| Repli sans adaptateur | **OUI** | `mapAdapter == null → SizedBox.shrink()`, coordonnées-seules, `takeException()==null`, pas de `ZScopeError` |
| Frontière E11a-1 | **OUI** | aucune anticipation intl/pays/export/2e adaptateur/géocodage ; strictement champ géo + carte |

---

## Findings

### MAJEUR-1 — La factory `builder(mapAdapter:)` capture une **instance d'adaptateur partagée** → contrôleur natif aliasé + disposé par chaque montage
**Fichiers** : `lib/src/presentation/z_geo_field_widget.dart:63-73` (factory) ; `lib/src/presentation/z_map_adapter.dart:12-16` (contrat) ; dispose `z_geo_field_widget.dart:140`.

`ZGeoFieldWidget.builder({ZMapAdapter? mapAdapter})` renvoie une closure qui **capture la même instance `mapAdapter`** et la réinjecte à *chaque* invocation du builder. Or `ZMapAdapter` documente explicitement « une instance d'adaptateur est **à usage unique par montage de champ** » et `ZGeoFieldWidget.dispose()` appelle `widget.mapAdapter?.dispose()` (le champ se déclare **propriétaire** du cycle de vie). Les deux ne peuvent pas coexister dès qu'il y a plus d'un montage :

- **Deux champs `location` (ou `geoArea`) dans un même formulaire** → les deux `State` partagent le **même `MapController`** rendu dans deux `FlutterMap` (flutter_map n'admet pas un contrôleur sur deux cartes → assert/erreur runtime), et **chacun** disposera l'unique contrôleur.
- **Champ démonté puis remonté** (visibilité conditionnelle, onglet, navigation) → au premier `dispose` l'adaptateur est disposé (idempotent), le remontage rappelle `buildMap` sur un `MapController` **déjà disposé** → carte morte, plus de ré-init.

**Impact** : scénario réaliste côté DODLP (banc parité). Défaut de conception latent : l'API livrée **ne peut pas honorer son propre contrat** en formulaire multi-champs/à remontage.
**Remède** : injecter une **fabrique** plutôt qu'une instance — `builder({ZMapAdapter Function()? adapterFactory})` — et créer l'adaptateur **1× en `initState`** (puis dispose en `dispose`), garantissant une instance par montage. À défaut, documenter/asserter une contrainte « un builder = un champ » (insuffisant, non enforceable).

### MEDIUM-2 — Idempotence + confinement de `ZOsmMapAdapter.dispose()` **non testés**
**Fichier** : `lib/src/presentation/adapters/z_osm_map_adapter.dart:119-124`.
Le garde `if (_disposed) return;` et le double-dispose sûr sont **implémentés** mais **aucun test n'instancie `ZOsmMapAdapter`** (AC7 ne prouve l'anti-fuite que via `FakeMapAdapter`). L'adaptateur concret réel (seul détenteur d'un `MapController` natif, cible du learning E5) n'a **aucune** couverture — ni idempotence, ni le fait que `buildMap` produit bien un widget neutre. Gate d'isolation purement statique.
**Remède** : test léger construisant `ZOsmMapAdapter`, appelant `dispose()` deux fois (aucun throw) ; idéalement un `pumpWidget` de `buildMap` sous `MaterialApp` pour valider le rendu et le confinement SDK réel.

### MEDIUM-3 — `geoArea` : ajout de sommet en **lecture-au-moment-de-l'événement** → perte de mise à jour si deux événements dans la même frame
**Fichier** : `lib/src/presentation/z_geo_field_widget.dart:179-182` (`_appendVertex`), `167-176` (`_addCandidateVertex`), `185-190` (`_removeVertex`).
`_appendVertex` fait `onChanged(_shapeOf(widget.ctx.value).addVertex(point))`. `widget.ctx.value` n'est rafraîchi que **par un rebuild** (après `setValue`→notify). Deux taps carte (ou tap + Ajouter) traités **dans la même frame**, avant que le `ValueListenableBuilder` du cœur n'ait reconstruit avec la nouvelle valeur, lisent tous deux le **même `ctx.value` obsolète** → le second écrase le premier (sommet perdu). Idem `_removeVertex`.
**Impact** : réaliste sur une carte tactile (double-tap rapide d'ajout de points). Correctness — silencieux.
**Remède** : accumuler le sommet candidat dans un état local réduit-au-fil-de-l'eau, ou lire la valeur via une source fraîche (contrôleur) plutôt que `widget.ctx.value` capturé au build ; alternativement débouncer/sérialiser les ajouts.

### LOW-4 — Chaînes UI et dimensions **codées en dur** (i18n / thème)
**Fichier** : `z_geo_field_widget.dart:308` (`'Ajouter'`), `295/339/302` (`'ajouter-sommet'`, `'retirer-sommet-$i'`), `368` (`SizedBox(height: 200)`) ; `z_osm_map_adapter.dart:101-111` (tailles marqueurs 40/24/12).
`'Ajouter'` est une chaîne UI française en dur (le cœur expose `ZcrudScope.labels`) ; la hauteur de carte `200` et les tailles de marqueurs sont des dimensions littérales non thémées. AD-13 vise surtout couleurs/styles (respecté : `ZcrudTheme.of`, zéro couleur en dur, gate RTL vert), mais ces littéraux échappent à l'injection.
**Remède** : router les libellés visibles via `ZcrudScope.labels`/l10n ; exposer la hauteur de carte en paramètre/thème.

### LOW-5 — `_pointOf` fait confiance à un `ZGeoPoint` déjà présent dans la tranche sans re-vérifier les bornes
**Fichier** : `z_geo_field_widget.dart:194-195`.
`value is ZGeoPoint ? value : ZGeoPoint.fromMapSafe(value)` : un `ZGeoPoint` construit programmatiquement hors-bornes (le constructeur n'a pas d'`assert`, cf. `z_geo_point.dart:21-26`) est amorcé tel quel dans les champs et **envoyé au centre carte** (`LatLng(200,…)`). Le défensif AD-10 ne couvre que la voie `Map`. Marginal (la voie utilisateur est validée), mais l'invariant « la tranche est toujours valide » n'est pas garanti côté lecture.
**Remède** : filtrer par `isValid` en lecture (`value is ZGeoPoint && value.isValid ? value : fromMapSafe(...)`).

### LOW-6 — SM-1 prouvé sur un slice fait-main, pas via le vrai dispatch `DynamicEdition→ZFieldWidget`
**Fichier** : `test/z_geo_field_widget_test.dart:161-220`.
Le test AC6 monte deux `ZGeoFieldWidget` dans des `ValueListenableBuilder` hand-rollés — probant pour la granularité interne, mais ne rejoue pas le chemin réel `ZFieldWidget`/`registryOrFallback`/`ZFieldListenableBuilder`. AC3 (ligne 74-96) exerce le vrai chemin via `DynamicEdition` mais **n'assure pas le focus** après frappe. Aucune régression prouvée n'est masquée, mais la preuve SM-1 « bout-en-bout » repose sur une reconstitution.
**Remède** : ajouter une assertion de focus/curseur sur le chemin `DynamicEdition` réel.

---

## Contrôles adversariaux passés (non-findings)

- **Voie sens-unique AD-2** : en `location`, `onChanged` per-frappe → `_emitPointFromFields` ; `didUpdateWidget` **retourne tôt** si `_hasFieldFocus` (pas de write-back pendant la frappe) → pas de saut de curseur. Correct.
- **Repli `ZUnsupportedFieldWidget`** préservé pour registre vide (AC2, `find…UnsupportedFieldWidget` + `takeException()==null`).
- **Gate isolation** : contrôle **positif** présent (le pubspec `zcrud_geo` DOIT contenir `flutter_map:`/`latlong2:`, `isolation_gates_test.dart:37-41`) + négatif sur `zcrud_core` + barrel sans `adapters/`. Scan secret (regex clé Google + `badCertificateCallback`) et scan RTL couvrent `lib/` récursif (inclut l'adaptateur OSM). Chemins `_read` robustes depuis dossier package et racine.
- **`FakeMapAdapter`** reflète fidèlement le contrat (rendu tappable, `onTap` neutre, `disposed`, capture des params neutres) — pas tautologique.
- **`ZGeoShape.vertices`** non modifiable (test `throwsUnsupportedError`) ; égalité de valeur `==`/`hashCode` correcte (listes + label).
- **Registre** : `kind == field.type.name` (`'location'`/`'geoArea'`), enregistrement via `ZWidgetRegistry` instanciable injecté — pas de singleton statique (AD-4).
- **Thème injecté** : `ZcrudTheme.of(context)` (repli `Theme.of`, vérifié `z_theme.dart:89`), `fieldPadding` directionnel, gaps thémés.

---

## Conclusion

**12/12 ACs matériellement satisfaits** ; isolation carte, neutralité de la valeur, no-secret et défensif AD-10 **solides et réellement prouvés**. **1 MAJEUR** de conception (adaptateur partagé vs contrat « une instance par montage » — corriger avant `done` : passer à une fabrique d'adaptateur créée en `initState`), **2 MEDIUM** (couverture idempotence OSM ; perte de sommet multi-événement) à corriger dans le périmètre ou justifier, **3 LOW** consignés.

**Finding le plus grave** : `ZGeoFieldWidget.builder` capture une **unique instance d'adaptateur** réutilisée pour chaque champ et disposée par chaque montage, ce qui aliase le `MapController` natif et casse le rendu/dispose dès qu'un formulaire a deux champs géo ou qu'un champ est remonté — en contradiction directe avec le contrat « à usage unique par montage » de `ZMapAdapter`.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MAJEUR | ✅ **corrigé** | Instance→**fabrique** : typedef `ZMapAdapterFactory = ZMapAdapter Function()` ; `ZGeoFieldWidget({adapterFactory})` appelle la fabrique **1× en initState** → instance possédée, disposée en dispose, jamais aliasée. Caller `lib/adapters/osm.dart` → `adapterFactory: ZOsmMapAdapter.new`. Tests : 2 champs simultanés → 2 instances/surfaces distinctes ; remontage → nouvelle instance, ancienne disposée sans affecter la neuve. |
| 2 | MEDIUM-2 | ✅ corrigé | `test/z_osm_map_adapter_test.dart` sur le VRAI `ZOsmMapAdapter` : dispose idempotent (2 appels), buildMap réel (location+geoArea) sans exception. |
| 3 | MEDIUM-3 | ✅ corrigé | État local `_workingShape` atomique (amorcé initState, réconcilié didUpdateWidget par égalité de valeur) ; append/remove mutent avant d'émettre. Test : 2 taps même frame → 2 sommets. |
| 4 | LOW-4 | ✅ corrigé | `'Ajouter'`→`label(context,'geo.addVertex',fallback)` ; hauteur carte param `mapHeight` (défaut 200) + test surcharge `ZcrudScope.labels`. |
| 5 | LOW-5 | ✅ corrigé | `_pointOf` re-check `isValid` (ZGeoPoint hors-bornes en tranche → null) + test. |
| 6 | LOW-6 | ✅ corrigé | Test SM-1 bout-en-bout via le vrai dispatch `DynamicEdition` (focus préservé). |

**Vérif verte rejouée (orchestrateur, ciblée zcrud_geo)** : `flutter analyze` **0 issue** · `flutter test` **52/52** (41→52, +11) · `graph_proof.py` **CORE OUT=0** acyclique. zcrud_core NON touché.

**Verdict final** : 1 MAJEUR + 2 MEDIUM + 3 LOW corrigés (tests à l'appui). Story E11a-1 → **done**.
