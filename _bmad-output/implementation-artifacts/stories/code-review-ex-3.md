# Code Review — EX-3 : Démos Markdown / Geo / Intl / Export / Offline (CLÔTURE epic EX)

- **Story** : `ex-3-reste-features-demo.md` (statut `review`, 12 ACs)
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` ; steps chargés depuis `.claude/skills/bmad-code-review/steps/`)
- **Revue** : adversariale, lecture seule sur `example/` (+ `packages/*/lib` pour vérifier l'API réelle). Aucun fichier modifié.
- **HEAD** : `9ada9d0` — baseline story `6f6c9fb`. `git status -- packages/` : **VIDE** (aucun fichier EX-3 sous `packages/`).
- **Verdict global** : **APPROUVÉ sous réserve** — 0 HIGH, 0 MAJEUR, 1 MEDIUM (justifié/documenté), 2 LOW. Les 12 ACs sont matériellement satisfaits, à la nuance AC7 (restore non exposé dans l'UI, prouvé seulement par test unité).

---

## Findings

| # | Sévérité | Fichier:ligne | Résumé |
|---|----------|---------------|--------|
| 1 | MEDIUM | `example/lib/demos/offline_demo_screen.dart:124` | AC7 liste « soft-delete+restore » comme CRUD démontré, mais l'écran n'expose PAS de voie `restore()` : après soft-delete l'enregistrement disparaît (watchAll exclut les supprimés) sans corbeille ni bouton restaurer. `restore()` n'apparaît que dans des commentaires et le test unité `offline_demo_test.dart`. Impact : parcours utilisateur AC7 incomplet à l'écran. Remède : ajouter une bascule « afficher supprimés + restaurer » (ou justifier le report — déjà fait par écrit dans les Completion Notes de la story). |
| 2 | LOW | `example/test/markdown_demo_test.dart:22` | L'interaction Markdown est simulée par `controller.setValue('body', <Delta>)` + switch codec ; les **embeds LaTeX/tableau** de la toolbar (AC3) et la frappe réelle (focus) ne sont PAS exercés au niveau démo — couverture reportée sur les tests package E6. Remède : taper les boutons embed de la toolbar dans le test démo (ou documenter le report sur E6). |
| 3 | LOW | `example/test/geo_demo_test.dart:13` | La parité multi-binding AC10 n'est prouvée que sur l'écran **Intl** (`demo_registry_test.dart`, scope+riverpod). L'écran **Geo** n'est monté que sous le binding par défaut. AC10 n'exige qu'UN écran registre-servi sous ≥2 wraps (satisfait par Intl), donc conforme, mais la parité géo sous binding reste non observée. Remède : optionnel — boucler `GeoDemoScreen(initialBinding:)` sur ≥2 bindings. |

**Observation (hors périmètre EX-3, non-finding)** : `tool/binding_conformance/pubspec.yaml` est modifié dans l'arbre de travail (bump `zcrud_core ^0.0.1 → ^0.1.0`). Le commentaire l'attribue explicitement à **REL-1** (développé en parallèle) ; le fichier est hors `packages/` ET hors `example/`. Ce n'est PAS une violation de périmètre EX-3, mais un changement du flux REL-1 co-présent dans le même arbre — à ne pas committer avec EX-3.

---

## Vérifications adversariales (preuves sur disque)

### API réelle des satellites — par écran (toutes VÉRIFIÉES contre `packages/*/lib`)

| Écran | API consommée | Réelle ? |
|-------|---------------|----------|
| Markdown | `ZMarkdownField(controller:, field:, codec:)` + `ZMarkdownField.persistedValueOf(controller, name, codec:)` static + `controller.fieldListenable(name)` | **OUI** — signatures confirmées (`z_markdown_field.dart:101,159` ; `z_form_controller.dart:103`). Monté DIRECTEMENT (contrôleur isolé AD-7), pas via le registre — correct (`ZFieldWidgetContext` n'expose pas de `ZFormController`). |
| Geo | `ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new)` via registre ; valeur neutre `ZGeoPoint(lat:,lng:)` | **OUI** — `z_geo_field_widget.dart:76` ; `ZOsmMapAdapter` exporté par l'entrée dédiée `adapters/osm.dart` (SDK `flutter_map` hors barrel). |
| Intl | `ZPhoneFieldWidget.builder(catalog:)` / `ZCountryFieldWidget.builder` / `ZAddressFieldWidget.builder` via registre ; `ZPhoneNumber.e164` | **OUI** — builders confirmés ; validation E.164 réellement exercée (numéro valide `+33…` → `e164` non nul ; `+331` → `e164` nul). |
| Export | `const ZExporter().toExcelBytes(ZListRenderRequest)` / `.toPdfBytes(...)` ; `ZListRenderRequest.fromSchema(demoSchema, rows, policy: ZColumnPolicy())` | **OUI** — `z_exporter.dart:39,46,59` ; contrôle `%PDF-` réel ; bytes non vides confirmés à l'utilisateur (non tautologique). |
| Offline | port `ZLocalStore<DemoRecord>` ; runtime `HiveZLocalStore.openBox(kind:, fromMap:, toMap:)` | **OUI** — `hive_z_local_store.dart:89` ; écran construit CONTRE le port (injectable) ; signatures neutres (`ZResult`/`Stream` nus). |

→ **API réelle par écran : OUI (5/5).** Aucune API inventée. Chaque écran fait ce qu'il prétend (édition + persisted value ; champs géo/intl rendus via registre → valeur neutre ; export bytes non vides ; CRUD offline réel).

### Isolation / SM-5

- **Aucun import direct** de `cloud_firestore`/`firebase_core`/`flutter_map`/`flutter_quill`/`syncfusion_*`/`latlong2` dans `example/lib` (grep = 0). Seules arêtes lourdes directes : `hive_flutter` (main.dart, déclaré + justifié) et `zcrud_geo/adapters/osm.dart` (entrée dédiée). → SDK lourds tirés **exclusivement** via les satellites.
- **`packages/` INCHANGÉ** par EX-3 (`git status -- packages/` vide).
- **Root `pubspec.lock` NON modifié** (pas dans la liste `git status` ; seul `example/pubspec.lock` est nouveau/untracked). Les entrées `cloud_firestore`/`flutter_map`/`flutter_quill`/`syncfusion_*` présentes dans le lock racine proviennent des **membres workspace** (`zcrud_firestore`/`zcrud_geo`/`zcrud_markdown`/`zcrud_export`) — **préexistantes**, pas une pollution EX-3.
- **`melos list` = 14** ; `graph_proof` : toutes arêtes pointent VERS `zcrud_core` (CORE OUT=0, acyclique).
- Aucun type SDK dans une valeur de tranche (`ZGeoPoint`/`ZPhoneNumber`/`Uint8List`/Delta JSON/`DemoRecord`).

→ **SM-5 isolation + root lock intact : OUI. packages/ non touché : OUI.**

### No-secret / Firestore

- Scan `apiKey|AIza|firebaseConfig|google-services|badCertificate|registerLicense|SyncfusionLicense` sur `example/lib` + `example/test` : **0 résultat**.
- Firestore distant **documenté mais NON initialisé** (`Firebase.initializeApp` absent ; `FirestoreZRemoteStore`/`FirebaseZRepositoryImpl` uniquement en bloc doc, jamais instanciés). OSM sans clé. Aucune licence Syncfusion committée.

→ **No-secret Firestore : OUI.**

### Parité bindings (AD-15)

- `widgetRegistry: _widgetRegistry` injecté au `ZcrudScope` **racine** (`app.dart:90`), re-propagé sous chaque binding par `_BindingSeamForwarder` (`binding_selector.dart:83`, NON modifié).
- Geo/Intl : `wrapWithBinding(rootScope: ZcrudScope.maybeOf(context))` + `KeyedSubtree(ValueKey(binding))` + nouveau controller par wrap + dispose de l'ancien.
- Test AC10 : `IntlDemoScreen` monté sous `DemoBinding.scope` ET `DemoBinding.riverpod` → 3 champs rendus, **0 `ZUnsupportedFieldWidget`** sous les 2 wraps.

→ **Parité bindings : OUI.**

### AD-2 (contrôleurs stables)

- Markdown : `ZFormController` créé en `initState`, disposé en `dispose` ; champ re-monté par `ValueKey(codec)` au switch (résolution codec 1×). Contrôleur Quill isolé interne à `ZMarkdownField`.
- Geo/Intl : controller créé en `initState`, remplacé (nouveau + dispose de l'ancien) au switch de binding uniquement.
- Export : `DemoStore` possédé par le `State`, disposé.
- Offline : `watchAll()` appelé UNE fois (flux caché dans le `State`) — évite la boucle de ré-abonnement ; `ListView.builder`.

→ Aucune recréation au rebuild, dispose propres. **AD-2 : conforme.**

### Build web / Firebase

- Ambiguïté (b) tranchée par la story : `flutter build web` RC=0 rejoué par l'orchestrateur (dépendre de `cloud_firestore`/`firebase_core` sans `initializeApp()` ne casse pas le build). Non re-rejoué dans cette revue (lecture seule) ; aucun appel `Firebase.initializeApp` au runtime → pas de crash. → **OUI** (sur la foi de la vérif orchestrateur + absence d'init).

### Offline CRUD réel

- Test `test()` (option a) : **Hive réel** en temp-dir hermétique — create → getAll → softDelete → getAll(vide) → **restore** → getAll → clear. CRUD offline réel prouvé (restore inclus, côté port).
- Test widget (option b) : fake `_InMemoryLocalStore` **honnête** (implémente `ZLocalStore<DemoRecord>` : soft-delete hors-entité, `watchAll` seed+broadcast, `getById` défensif) — reflète le contrat neutre du port.

→ **Offline CRUD réel : OUI** (nuance : restore prouvé par test, non exposé à l'UI — Finding #1).

### Qualité tests

- 1 test affichage + 1 interaction par écran (Markdown/Geo/Intl/Export/Offline). Aucune tautologie détectée (export vérifie l'absence de « invalide » ; intl vérifie e164 non nul/nul ; geo vérifie `ZGeoPoint` neutre).
- Navigation accueil (`home_nav_test.dart`) : les 5 nouvelles entrées (Markdown/Geo/Intl/Export/Offline) ouvertes + retour ; `app_smoke_test` : plus AUCUN chip « à venir ».
- Frontière (`boundary_deps_test.dart`) : 10 paquets autorisés déclarés ; `zcrud_flashcard`/`zcrud_mindmap` **INTERDITS** (strippe les commentaires avant l'assertion → non tautologique).

### Frontière

- `zcrud_flashcard`/`zcrud_mindmap` (E9/E10) restent interdits ; aucune démo de ces features. EX-3 **clôt l'epic EX**.

→ **Frontière : OUI.**

---

## Verdicts synthétiques

| Contrôle | Verdict |
|----------|---------|
| API réelle par écran (5/5) | **OUI** |
| SM-5 isolation + root lock intact | **OUI** |
| `packages/` non touché | **OUI** |
| No-secret Firestore | **OUI** |
| Parité bindings (AD-15) | **OUI** |
| Build web OK | **OUI** (vérif orchestrateur + aucun `initializeApp`) |
| Offline CRUD réel | **OUI** (restore prouvé par test, non exposé UI — Finding #1) |
| Frontière (flashcard/mindmap interdits, EX clos) | **OUI** |

**Finding le plus grave** : AC7 revendique un CRUD offline « soft-delete+restore » mais l'écran `OfflineDemoScreen` n'offre aucune voie de restauration à l'utilisateur (restore uniquement dans le test unité) — parcours démo incomplet, sans impact de correction ni de régression.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MEDIUM | ✅ **corrigé** | `OfflineDemoScreen._softDelete` déclenche un SnackBar « Annuler » → `store.restore(id)` → CRUD offline complet create/softDelete/**restore** exerçable à la main (voie undo car le port `ZLocalStore` exclut les soft-deleted de `watchAll`/`getAll`). Test widget : supprimer → SnackBar → Annuler → réapparaît. |
| 2 | LOW-2 | 🟡 documenté | Couverture profonde de l'éditeur (frappe Quill, embeds) = E6 (155 tests) ; la démo teste l'intégration (montage + valeur persistée + bascule codec). |
| 3 | LOW-3 | ✅ corrigé | Boucle de parité Geo ajoutée (scope + riverpod) → 2 `ZGeoFieldWidget`, 0 `ZUnsupportedFieldWidget`. |

**Vérif verte rejouée (orchestrateur, ciblée example/)** : `flutter analyze` **0 issue** · `flutter test` **49/49** (46→49) · `flutter build web` RC=0 · `packages/` non touché · root lock intact.

**Verdict final** : 1 MEDIUM + 2 LOW traités. Story EX-3 → **done**.
