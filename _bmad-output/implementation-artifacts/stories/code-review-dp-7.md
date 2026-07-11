# Code Review — DP-7 : Barre d'outils éditeur geo (`ZGeoEditorToolbarConfig`, gap B9)

- **Mode d'exécution** : skill réel `bmad-code-review` invoqué (step-file architecture) ; revue adversariale menée en session (sous-agents non disponibles dans ce contexte → couches Blind Hunter / Edge Case Hunter / Acceptance Auditor jouées en direct par le reviewer, comme prévu par le fallback du step-02).
- **Story** : `_bmad-output/implementation-artifacts/stories/dp-7-geo-editor-toolbar.md` (11 ACs).
- **Baseline** : `1bcae2a` (frontmatter story).
- **Périmètre** : fichiers DP-7 sous `packages/zcrud_geo/` uniquement. Autres packages (DP-1/3/8/11 en vol) exclus. Aucun fichier DODLP modifié (lecture seule pour vérif parité).

## Vérif verte rejouée réellement sur disque

| Vérif | Commande | RC | Résultat |
|---|---|---|---|
| Analyze | `dart analyze packages/zcrud_geo` | **0** | `No issues found!` (lib + tests) |
| Tests | `flutter test packages/zcrud_geo` | **0** | **136 tests** — `All tests passed!` |
| Graph | `python3 scripts/dev/graph_proof.py` | **0** | `ACYCLIQUE OK`, **CORE OUT=0**, seule arête `zcrud_geo -> zcrud_core` (aucune arête SDK carte vers le cœur) |
| Secrets | `grep -E apiKey/token/secret/badCert/geolocator/location/AIza` sur `lib/` | — | **0 secret réel** ; uniquement des commentaires « ZÉRO clé/secret » ; **aucune** dépendance de géoloc ajoutée |

## Confirmations d'invariants (axes adversariaux)

- **Presets — parité DODLP 1:1 EXACTE** : vérifié flag-par-flag contre la source `dodlp-otr/.../geo_editor_config.dart:81-273`. Défauts, `none`, `minimal`, `standard`, `full` (17 toggles true + **`compactMode:false`**), `professional` (full sauf indoor/zoom/compass/mapToolbar) → **tous identiques**. Le parenthétique imprécis de l'AC2 (« full = 18 à true ») est correctement tranché en faveur de la règle liante « exactement DODLP » (`compactMode:false`), documenté en Completion Notes et asserté par le test.
- **Additif / rétro-compat E11a-1/E11b-1 STRICTE** : `toolbarConfig` défaut `null`, propagé dans `copyWith`/`==`/`hashCode`. `null` → aucune barre (`find.byKey('z-geo-toolbar')` = `findsNothing`), `_mapOptions = null`, `buildMap(mapOptions: null)` → chemin Google `?? <défaut widget>` reproduit exactement les défauts natifs → **UI d'origine inchangée**. Tests dédiés + suite E11a/E11b intacte.
- **Voie UNIQUE `ctx.onChanged`** : `_clearAll`/`_undo`/`_useMyLocation` réutilisent les helpers atomiques existants (`_appendVertex`/`_removeVertex`/`_setPointFromTap`/`_setCircleCenterFromTap`/`_workingShape`) ; aucune mutation d'arbre parasite. `type-de-carte`/toggles features = actions **discrètes** via `setState(_mapOptions)`, jamais la voie de frappe.
- **Seam `ZGeoLocationResolver`** : typedef pur `Future<ZGeoPoint?> Function()`, capturé par closure de `builder(...)`, **aucun** SDK géoloc, **aucun** slot `zcrud_core`/`ZcrudScope`. Bouton ma-position **masqué si seam absent** même quand `showMyLocationButton == true` (testé). `mounted`-guardé après `await`, avale erreur/null (AD-10, testé).
- **AD-2 / SM-1** : contrôleurs/focus `late final` créés 1× en `initState`, jamais recréés par l'ajout de la barre ; `onInit == 1` après frappe + toggle (testé). `readOnly` → tous les boutons `onPressed: null` (clear testé ; map-type + toggles gated en code).
- **AD-13** : chaque bouton `ConstrainedBox(minHeight:48,minWidth:48)` + `Semantics(button/label/enabled/toggled)` + `tooltip`/label l10n ; layout directionnel (`AlignmentDirectional.centerStart`, `Wrap`, `TextAlign.start`) ; **zéro couleur en dur** (IconButton/TextButton du thème + `ZcrudTheme.of`). Tests ≥48dp, RTL, thème dark, l10n surchargeable verts.
- **AD-1 (SDK confiné)** : `ZGeoMapType`/`ZGeoMapOptions` neutres (aucun `MapType` SDK) ; traduction `_toGoogleMapType` confinée au fichier adaptateur Google ; OSM ignore documenté ; barrel `lib/zcrud_geo.dart` n'exporte aucun symbole SDK. graph_proof CORE OUT=0.
- **l10n** : clés `geo.undo/clear/myLocation/mapType[.normal|hybrid|satellite|terrain]/traffic/…` via `label(context, key, fallback:)` inline → **aucun** changement `zcrud_core` requis ; surcharge `ZcrudScope.labels` testée.

## Findings

### MEDIUM-1 — Défauts `ZGeoMapOptions` non alignés sur DODLP `GeoEditorMapState.defaultState` → désactive le chrome natif Google quand une barre est présente
**Fichiers** : `lib/src/domain/z_geo_map_options.dart:41-51` (défauts) ; `lib/src/presentation/adapters/z_google_map_adapter.dart:116-122` (chemin non-null) ; `lib/src/presentation/z_geo_field_widget.dart:191` (`_mapOptions = const ZGeoMapOptions()`).

**Constat** : DODLP `GeoEditorMapState.defaultState` (`geo_editor_config.dart:288-299`) porte `mapType: hybrid`, `buildingsEnabled: true`, `zoomControlsEnabled: true`, `compassEnabled: true`, `mapToolbarEnabled: true`. zcrud `ZGeoMapOptions()` met **tout à `false`** et `mapType: normal`. L'adaptateur Google traduit `null → défaut natif (?? true)` mais `non-null all-false → false`. Conséquence : **dès qu'une barre d'outils existe** (même `minimal`/`standard`, qui n'exposent PAS les toggles zoom/compass/buildings/mapToolbar), `_mapOptions` initial = `const ZGeoMapOptions()` → la carte Google perd **boussole, contrôles de zoom, bâtiments 3D et map-toolbar natifs**, sans aucun moyen pour l'utilisateur de les réactiver (toggles non rendus par ces presets), et le type initial passe de hybride (DODLP) à normal.

**Scénario d'échec** : champ géo migré avec `toolbarConfig: ZGeoEditorToolbarConfig.standard` sur adaptateur Google → au montage, `buildMap(mapOptions: ZGeoMapOptions())` → `compassEnabled:false, zoomControlsEnabled:false, buildingsEnabled:false, mapToolbarEnabled:false, mapType:normal`. L'utilisateur voit une carte **dépouillée** vs DODLP (hybride + chrome complet) et vs le champ zcrud SANS barre (chrome complet). Régression de parité (but même de l'épopée E-DP) + surprise UX. Non couvert par les tests (FakeMapAdapter ne matérialise pas la traduction Google).

**Portée / atténuation** : la rétro-compat stricte E11a-1/E11b-1 (chemin `mapOptions == null`, sans barre) **reste intacte** — le défaut est cantonné au chemin « barre présente + adaptateur Google ». Il tombe partiellement sous la clause HORS-story « honoré-si-supporté » (pas de test pixel SDK exigé), mais il contredit la parité DODLP et le commentaire `z_geo_map_options.dart:38-40` (« un `ZGeoMapOptions()` par défaut ne modifie rien de visible ») qui est **inexact** dès que l'adaptateur force les flags.

**Reco** : aligner les défauts de `ZGeoMapOptions()` sur `GeoEditorMapState.defaultState` (`mapType: hybrid`, `buildings/zoomControls/compass/mapToolbar = true`) — parité 1:1 et cohérence avec le chemin `null → ?? true`. À défaut de correction dans le périmètre, **justifier par écrit** le report (MEDIUM déféré) : préciser que les presets non-GIS perdent le chrome natif Google et créer un follow-up.

### LOW-1 — `useMapOptionsDropdown` sans effet de rendu
**Fichier** : `lib/src/domain/z_geo_editor_toolbar_config.dart:124` ; consommation absente dans `z_geo_field_widget.dart`.
Les presets `full`/`professional` posent `useMapOptionsDropdown: true`, mais la barre rend **toujours** des boutons/toggles à plat (aucun regroupement en menu déroulant). Le flag est porté pour la parité de config mais **inerte**. Cohérent avec le scope IN (seuls undo/clear/ma-position/type-carte + toggles features sont câblés ; le dropdown n'est pas listé), mais mérite une ligne explicite en Dev Notes « HORS-story » comme pour `showModeSelector`/`showOptimizeButton`. Nit documentaire.

### LOW-2 — Commentaires « comportement de base inchangé » trompeurs sur le chemin non-null
**Fichiers** : `z_geo_map_options.dart:38-40`, `z_map_adapter.dart` (docstring `mapOptions` « `null` (défaut) → comportement inchangé »).
Exact pour `mapOptions == null` uniquement. Un `ZGeoMapOptions()` non-null modifie bien le rendu Google (cf. MEDIUM-1). Reformuler pour distinguer « `null` → inchangé » de « instance neutre → flags appliqués ». Se résout avec MEDIUM-1.

### Note positive
`ZGeoEditorToolbarConfig.copyWith` **ajoute** le paramètre `disabled` que le `copyWith` DODLP omet (`geo_editor_config.dart:228-248`) : divergence bénigne et **améliorante** (DODLP ne peut pas copier `disabled`), pas un écart de parité fonctionnelle.

## Verdict

**APPROUVÉ SOUS RÉSERVE (changes-requested léger).**

- Aucun finding **HIGH/critique/majeur**. Zéro secret, SDK carte confiné (CORE OUT=0), rétro-compat E11a-1/E11b-1 stricte, presets DODLP 1:1 exacts, AD-1/2/4/10/13 respectés, 136 tests verts.
- **1 MEDIUM** (MEDIUM-1 : défauts `ZGeoMapOptions` vs DODLP `defaultState`) : à corriger dans le périmètre (aligner les défauts) OU à déférer avec justification écrite conforme à la politique MEDIUM (CLAUDE.md). Ne bloque pas le vert ; affecte la parité visuelle Google + cohérence.
- **2 LOW** documentaires (optionnels).

La story peut passer `done` une fois MEDIUM-1 tranché (corrigé de préférence, sinon justifié par écrit ici + follow-up).

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_geo` RC=0, `flutter test packages/zcrud_geo` **136 tests**, graph CORE OUT=0 (SDK confiné).

- **MEDIUM-1 (défauts non alignés DODLP) — CORRIGÉ.** Les défauts de `ZGeoMapOptions()` reproduisent désormais le `defaultState` DODLP : `hybrid` + bâtiments/gestes(rotation,tilt)/zoom/boussole/map-toolbar **actifs**, trafic/indoor inactifs. Une carte munie d'une barre (même preset `minimal`/`standard`) conserve son rendu natif au lieu de tout désactiver. Rétro-compat E11a-1/E11b-1 intacte (`mapOptions == null` sans barre → défauts widget inchangés). Tests ajustés (défauts + cycle de type démarrant à `hybrid`).
- **LOW-1 (useMapOptionsDropdown inerte), LOW-2 (commentaires « inchangé » pour instance non-null) — CONSIGNÉS** (nits) : le dropdown d'options est reportable ; commentaires clarifiés par la nouvelle sémantique des défauts.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
