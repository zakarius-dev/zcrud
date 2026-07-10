# Code Review — REL-1 : Préparation des packages publiables (v0.1.0)

- **Date** : 2026-07-10
- **Reviewer** : bmad-code-review (adversarial, effort high) — skill invoqué via `Skill(bmad-code-review)`, exécution guidée par `.claude/skills/bmad-code-review/steps/step-0{1,2,3}.md`.
- **Cible** : diff vs baseline `6f6c9fb` (16 pubspecs modifiés + 36 docs créés + `z_export_api.dart` restauré + export barrel).
- **Story** : `stories/rel-1-prep-packages-publiables.md` (statut `review`, 13 ACs).
- **Mode** : full (spec présente). Layers : Acceptance Auditor + Blind Hunter + Edge Case Hunter (exécutés en une passe unique, agent non interactif).

## Verdicts synthétiques

| Contrôle | Verdict |
|---|---|
| Métadonnées 12 packages (version/description len/url/topics/no publish_to) conformes | **OUI** |
| LICENSE + CHANGELOG(`## 0.1.0`) + README par package présents | **OUI** (contenu README : voir MAJEUR-1) |
| Contraintes inter-zcrud `^0.1.0` cohérentes (14 + binding_conformance) | **OUI** |
| ZExportApi restauré sans fuite Syncfusion, cohérent avec siblings | **OUI** |
| Non-régression `analyze` repo-wide (flashcard réparé) | **OUI** |
| Périmètre 12 publiés + 2 différés (flashcard/mindmap 0.0.1 + publish_to:none) | **OUI** |

## Findings

### MAJEUR-1 — 6 des 12 README publiés contiennent un exemple qui NE COMPILE PAS (API inventée) — viole AC9

**Sévérité : HIGH (MAJEUR).** AC9 exige explicitement « un **exemple minimal** d'usage » et les Project Structure Notes imposent « les exemples de README référencent l'API publique réelle exportée par `lib/<pkg>.dart` … éviter des symboles inexistants ». La Completion Note revendique « exemple minimal **aligné sur le barrel réel** » — ce qui est **factuellement faux** pour la moitié des packages. Impact : un développeur qui découvre le package sur pub.dev et copie l'exemple obtient une erreur de compilation immédiate — exactement la perte de crédibilité que D1 invoquait pour différer les squelettes. Non bloquant pour `dart pub publish --dry-run` (les README ne sont pas compilés), donc invisible aux gates ; à corriger avant `done`.

| Package | Fichier:ligne | Symbole inventé | API réelle |
|---|---|---|---|
| zcrud_core | `packages/zcrud_core/README.md` (snippet dart) | `ZFormController(fields: [nameField])` **et** `controller.value('name')` | ctor = `ZFormController({Map<String,Object?>? initialValues, …})` (pas de `fields:`) ; accès tranche = `fieldListenable(String)` (pas de `value()`) — cf. `z_form_controller.dart:40,103` |
| zcrud_export | `packages/zcrud_export/README.md:20-22` | `Future<Uint8List> … exporter.toExcel(table)` | `Uint8List toExcelBytes(ZListRenderRequest request, {resolveHeader})` — **synchrone**, prend un `ZListRenderRequest` (pas un `ZExportTable`) ; aucune méthode `toExcel` n'existe — cf. `z_exporter.dart:46` |
| zcrud_markdown | `packages/zcrud_markdown/README.md` (snippet) | `ZMarkdownField(… fieldName: 'body')` | paramètre requis = `field` (un `ZFieldSpec`), pas `fieldName` (un `String`) — cf. `z_markdown_field.dart:101-103` |
| zcrud_intl | `packages/zcrud_intl/README.md` (snippet) | `ZPhoneNumber.parse('+22790000000')` | `parse` est un `static` de `ZPhoneCodec` (`z_phone_codec.dart:19,53`), classe **non exportée par le barrel** (« pont interne, jamais exporté ») ; `ZPhoneNumber` n'a pas de `.parse` |
| zcrud_geo | `packages/zcrud_geo/README.md` (snippet) | `ZGeoPoint(latitude: 13.5, longitude: 2.1)` | paramètres requis = `lat` / `lng` (pas `latitude`/`longitude`) — cf. `z_geo_point.dart:21-22` |
| zcrud_firestore | `packages/zcrud_firestore/README.md` (snippet) | `FirebaseZRepositoryImpl(firestore:, collectionPath:, fromMap:, toMap:)` | ctor a un paramètre **`required String kind`** omis → l'exemple ne compile pas — cf. `firebase_z_repository_impl.dart:95-102` |

**Remède** : réécrire les 6 snippets contre le barrel/ctor réel (noms de paramètres corrects, méthode `toExcelBytes` + `ZListRenderRequest`, `kind` requis, `fieldListenable`/`initialValues`, `lat`/`lng`, retirer `ZPhoneNumber.parse` non public ou exposer un point d'entrée public d'intl). Fixes unambigus (bucket **patch**). READMEs sains : zcrud_annotations, zcrud_generator, zcrud_list, zcrud_riverpod, zcrud_get, zcrud_provider.

## Contrôles PASS (preuves sur disque)

- **Versions** : les 12 publiés en `version: 0.1.0` ; flashcard/mindmap restés `0.0.1` + `publish_to: none` (seuls résiduels sous `packages/`). `tool/binding_conformance` intact (version 0.0.1).
- **Descriptions EN** : mono-ligne quotée, longueurs **93–129 char** (∈ [60,180]), sans redondance du nom de package.
- **URLs** : `homepage` + `repository` (sous-dossier `/tree/main/packages/<pkg>`) + `issue_tracker` présents sur les 12, pointant `github.com/zakarius-dev/zcrud`.
- **topics** : 4–5 par package, tous conformes `^[a-z][a-z0-9-]*$`, 2–32 char.
- **LICENSE** : présent sur les 12 et **identique** au `LICENSE` racine (diff `-q` = identique pour tous).
- **CHANGELOG** : `## 0.1.0` présent sur les 12.
- **Contraintes** : `^0.0.1 → ^0.1.0` sur les 14 pubspecs + `tool/binding_conformance` (déviation justifiée : membre du workspace, sinon `pub get` casse) ; `binding_conformance: ^0.0.1` (dev_dependency) non touché. Flashcard/mindmap : deps bumpées, version/publish_to conservés.
- **ZExportApi restauré** (`packages/zcrud_export/lib/src/data/z_export_api.dart`) : `abstract final class` avec `version` + `coreApiVersion = ZCoreApi.version` — **strictement homogène** à `ZMarkdownApi`/`ZCoreApi`/… ; import **`zcrud_core` uniquement**, **aucun** symbole Syncfusion en signature (isolation AD-1/AD-8 préservée) ; exporté proprement par le barrel `show ZExportApi` ; référencé par `z_flashcard_api.dart:23` (`ZExportApi.version`), arête AD-1 flashcard→export re-tangibilisée.
- **Non-régression** : `dart analyze packages/zcrud_flashcard` → **`No issues found!`** (l'erreur baseline `Undefined name 'ZExportApi'` est éliminée) ; `resolution: workspace` conservé partout ; aucun code runtime modifié hors le marqueur d'export.
- **Publiabilité** : aucun warning pana bloquant anticipé (description/LICENSE/homepage/CHANGELOG/README tous présents ; deps toutes en cours de publication). Absence d'`example/` par package = dette de score non bloquante (documentée). `example/` non touché (frontière EX-3 respectée). Aucune publication réelle tentée (frontière REL-2/Owner respectée).

## Nits (LOW, optionnels)

- Le marqueur `ZExportApi.version = '0.0.1'` reste à `'0.0.1'` alors que le package passe à `0.1.0` — cohérent avec la convention des autres marqueurs (« version d'API distincte de la version du package », tous à `0.0.1`), donc **non un défaut** ; à faire évoluer en bloc si la convention change.
- `example/` par package absent → boost de score pana différé (déjà consigné en Dev Notes, EX-3).

## Conclusion

Story techniquement solide : métadonnées, licences, changelogs, réconciliation de contraintes, périmètre 12+2 et restauration de `ZExportApi` **tous conformes et vérifiés sur disque**, non-régression confirmée. **Un finding MAJEUR** : la moitié des README publiés expose des exemples qui ne compilent pas (API inventée), en contradiction directe avec AC9 et avec la Completion Note. À corriger (fixes unambigus) avant `done`.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| MAJEUR-1 | HIGH | ✅ **corrigé (6 README)** | Chaque snippet réécrit contre l'API RÉELLE, vérifié par inspection de symbole (barrel + ctor source) : **core** `ZFormController(initialValues:)` + `fieldListenable(name)` ; **export** `const ZExporter().toExcelBytes(ZListRenderRequest.fromSchema(...))` synchrone ; **markdown** `ZMarkdownField(controller:, field: ZFieldSpec)` ; **intl** `const ZPhoneNumber(e164:, isoCode:)` + round-trip (pas de `.parse`) ; **geo** `ZGeoPoint(lat:, lng:)` ; **firestore** ctor avec `kind:` requis. READMEs sains (annotations/generator/list/riverpod/get/provider) inchangés. |
| LOW | LOW | 🟡 non-défaut | `ZExportApi.version='0.0.1'` = convention des marqueurs de squelette (comme `ZMarkdownApi`), distincte de la version du package. |

**Vérif verte rejouée (orchestrateur)** : `melos run analyze` **RC=0 repo-wide (SUCCESS)** · `melos run verify` RC=0 · `dart pub publish --dry-run` (core/export/markdown) sans warning de métadonnée/README (seul « modified in git » attendu tant que non committé). Spot-checks des snippets confirmés contre l'API réelle. Corroboration : EX-3 (app exemple) compile les mêmes API réellement.

**Verdict final** : MAJEUR-1 corrigé. Story REL-1 → **done**. REL-2 (dry-run autoritatif sur commit propre + publication réelle) = **action Owner** (`dart pub login`).
