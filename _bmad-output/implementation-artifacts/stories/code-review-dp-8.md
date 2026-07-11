# Code Review — DP-8 : Adresse String + Places (gap B10, `zcrud_intl`)

- **Mode d'exécution** : VRAI skill `bmad-code-review` invoqué (step-file architecture, layers adversariales exécutées en session courante — pas de fallback disque).
- **Story** : `_bmad-output/implementation-artifacts/stories/dp-8-adresse-string-places.md` (9 ACs, statut `review`).
- **Baseline** : `1bcae2a` (= HEAD ; diff = arbre de travail non commité).
- **Périmètre revu (strict)** : `packages/zcrud_intl/` uniquement.
  - NEW `lib/src/domain/z_address_codec.dart`
  - NEW `lib/src/domain/z_place_search_provider.dart`
  - UPDATE `lib/src/presentation/z_address_field_widget.dart` (+317/-17)
  - UPDATE `lib/zcrud_intl.dart` (+2)
  - NEW `test/z_address_codec_test.dart`
  - UPDATE `test/z_intl_field_widgets_test.dart` (+159)
  - UPDATE `test/isolation_gates_test.dart` (+67)
- **Hors périmètre** (non revus) : autres packages (DP-1/3/7/11 en vol), DODLP.

## Vérif verte rejouée réellement sur disque

| Gate | Commande | Résultat |
|------|----------|----------|
| Analyze | `dart analyze packages/zcrud_intl` | **RC=0** — « No issues found! » |
| Tests | `flutter test` (cwd `packages/zcrud_intl`) | **RC=0 — 150/150 passés** (dont 5 nouveaux DP-8) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **RC=0** — `CORE OUT=0 OK`, ACYCLIQUE OK, `zcrud_intl -> zcrud_core` (aucune nouvelle arête) |

## Confirmations sur les axes adversariaux clés

- **ZÉRO secret / réseau (AC4, AD-12)** : CONFIRMÉ. `z_place_search_provider.dart` n'importe que `z_postal_address.dart` (pur-Dart) ; aucun `http`/`google_maps_webservice`/`flutter_google_places`/URL/clé/`badCertificateCallback`. `isolation_gates_test.dart` étendu (denylist réseau `_bannedNetworkLibs`, pubspec sans lib réseau, barrel sans exposition, codec+seam sans `package:flutter/`) — **vert**.
- **Round-trip String byte-exact (AC2/AC3a)** : CONFIRMÉ. `decodeString` porte la String **telle quelle** (espaces conservés, ligne 54-55) ; `encodeToString` préfère `formatted` non altéré (ligne 66-69). Perte structure→String documentée en dartdoc et testée.
- **Défensif jamais-throw (AD-10)** : CONFIRMÉ. `raw is! String` / `trim().isEmpty` → `null` ; aucune entrée (`Map`/`int`/`List`/`bool`/`double`/`Object`) ne throw. Testé.
- **Single-emission (AD-2)** : CONFIRMÉ. `_fillFromPlace` → `setState` (rebuild local, pas global) + **un seul** `_emit()` → un seul `ctx.onChanged`. Prouvé par test (`emitCount` delta == 1, `detailsCount` == 1). Pas de double dispatch.
- **Rétro-compat E11a-2/E11b-2 STRICTE (AC7)** : CONFIRMÉ. `placeSearch == null` → `_header` rend un simple `Text`, aucun bouton (testé « SANS provider ⇒ aucun bouton »). `_formatted` défaut `null` → chemin E11a-2 identique. `ZPostalAddress`/`ZIntlFieldConfig` inchangés (additif). Les 145 tests pré-existants restent verts **sans modification**.
- **AD-13 / thème injecté** : CONFIRMÉ. `TextAlign.start`, `EdgeInsetsDirectional`, `Semantics`, cibles ≥ 48 dp (`BoxConstraints(minWidth:48,minHeight:48)`), `ZcrudTheme.of(context)` (aucune couleur en dur — gate AD-13 vert).
- **AD-14 domaine pur** : CONFIRMÉ. Codec + port en `lib/src/domain/`, aucun import Flutter/lourd (gate pur-Dart vert).
- **Compat schéma au bord (AC6)** : CONFIRMÉ. `_addressOf` route `String → decodeString` avant `fromMapSafe` ; ingestion legacy sans crash, sans réémission automatique (aucune réécriture Map). Testé.

## Findings (triés par sévérité)

### MEDIUM-1 — Enregistrement du kind `addressSearchField` **inatteignable** par le dispatcher réel (AC5 satisfait seulement au niveau registre)
- **Fichiers** : `lib/src/presentation/z_address_field_widget.dart:67` (`registry.register(addressSearchFieldKind, builder)`) ; rationale erroné dans la story (Dev Notes « Besoin `zcrud_core` détecté : AUCUN »).
- **Constat** : le dispatcher du cœur résout un widget **exclusivement** via `field.type.name` (`packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:460` et `.../families/z_free_widget_field_widget.dart:54`). L'énumération `EditionFieldType` (`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`) **ne contient QUE `address`** — il n'existe **aucune** valeur `addressSearchField`. Un `ZFieldSpec` réel ne peut donc **jamais** avoir `type.name == "addressSearchField"`, si bien que le second `register(...)` n'est **jamais** consulté en production.
- **Impact** : le « mapping n:1 parité DODLP » d'AC5 n'est prouvé qu'au niveau du registre (le test `tryBuilderFor('addressSearchField')` contourne l'enum), pas de bout en bout. La conclusion « AUCUN besoin core » est **inexacte** : une vraie parité de l'enum DODLP `addressSearchField` exigerait soit une valeur d'enum côté core (hors périmètre DP-8), soit un **mapping app-side** des champs DODLP `addressSearchField → EditionFieldType.address`.
- **Atténuant** : l'affordance de recherche est pilotée par `placeSearch != null`, **pas** par le kind — donc le comportement « recherche » fonctionne parfaitement sous le kind `address` ; le second enregistrement est **inerte mais non nuisible** (aucune régression, aucun crash). Impact utilisateur nul.
- **Reco (périmètre respecté — pas d'édition core)** : documenter explicitement dans la story (justification écrite MEDIUM) que les champs DODLP `addressSearchField` se mappent sur `EditionFieldType.address` au bord d'ingestion app, la recherche étant activée par injection du `ZPlaceSearchProvider` (kind-agnostique). Conserver `registerZAddressFieldWidgets` sous les deux kinds est acceptable comme point d'extension **si** une valeur d'enum `addressSearchField` est ajoutée ultérieurement au core — sinon, retirer la ligne 67 réduirait la fausse impression de parité. **À justifier par écrit** (MEDIUM reporté ne pouvant être corrigé sans toucher `zcrud_core`, hors périmètre dur de la story).

### LOW-1 — `_onManualEdit` n'appelle pas `setState` → aperçu `formatted` potentiellement rémanent
- **Fichier** : `lib/src/presentation/z_address_field_widget.dart:271-274`.
- **Constat** : à l'édition manuelle d'un sous-champ, `_formatted` passe non-null → `null` mais **sans** `setState` local (contrairement à `_onCountrySelected`/`_onSubdivisionSelected`/`_fillFromPlace` qui, eux, `setState`). L'effacement de l'encart `_formattedPreview` (condition `if (_notBlank(_formatted))` dans `build`) ne se produit alors que si l'hôte reconstruit le champ suite à `_emit()→ctx.onChanged` (rebuild granulaire `ValueListenableBuilder` attendu par AD-2). Sous cet hôte, ça s'auto-corrige ; mais si l'hôte débounce/ignore l'`onChanged` (identité de valeur inchangée, throttling), l'aperçu legacy reste affiché alors que les sous-champs divergent.
- **Reco** : ajouter un `setState((){})` (ou envelopper l'effacement de `_formatted`) dans `_onManualEdit` pour rendre la disparition de l'aperçu indépendante du comportement de rebuild de l'hôte. Trivial, sans régression.

### LOW-2 — Recherche déclenchée à chaque frappe (pas de debounce) + `sessionToken` jamais transmis
- **Fichier** : `lib/src/presentation/z_address_field_widget.dart:590` (`onChanged: _runSearch`) ; `_openPlaceSearch`/`_pick` appellent `search(...)`/`details(...)` **sans** `sessionToken`.
- **Constat** : pour un `ZPlaceSearchProvider` réel adossé au réseau (cas DODLP/Google Places), un appel `search` **par caractère** sans debounce et **sans session** groupée augmente latence et coût de facturation (DODLP utilisait `sessionToken`). Le seam expose `sessionToken` (AC4) mais le widget ne le génère/propage jamais.
- **Atténuant** : `sessionToken` est optionnel (non requis par AC5) ; l'implémentation app peut débouncer/tokeniser côté provider. Aucun impact fonctionnel/test.
- **Reco (optionnel)** : débouncer `_runSearch` (~300 ms) et générer un `sessionToken` par ouverture de dialogue, transmis à `search` puis clos par `details`. Non bloquant.

### LOW-3 — Course asynchrone possible dans `_PlaceSearchDialog._runSearch` (réponses hors-séquence)
- **Fichier** : `lib/src/presentation/z_address_field_widget.dart:547-560`.
- **Constat** : des saisies rapides lancent plusieurs `search` concurrents ; `_predictions` est écrasé par **la dernière réponse résolue**, qui peut correspondre à une requête **antérieure** (out-of-order) → prédictions affichées incohérentes avec le champ. Aucun garde de séquence/annulation.
- **Reco (optionnel)** : garder la dernière requête (compteur/`latestQuery`) et n'appliquer `setState(_predictions=...)` que si la réponse correspond à la requête courante. Non bloquant (couplé à LOW-2, le debounce réduit déjà l'exposition).

### LOW-4 — Édition manuelle / sélection pays d'une adresse **ingérée en String legacy** peut effacer tout le texte
- **Fichier** : `lib/src/presentation/z_address_field_widget.dart:271-284` (`_onManualEdit`/`_onCountrySelected` remettent `_formatted = null`).
- **Constat** : après ingestion d'une String legacy (`formatted` renseigné, sous-champs **vides**), un simple choix de pays (ou frappe) efface `_formatted` et émet un `ZPostalAddress` réduit (ex. `countryCode` seul) — le **texte d'adresse legacy est perdu** silencieusement pendant l'édition de migration.
- **Atténuant** : comportement **documenté** (« le rendu n'est plus autoritatif ») et cohérent avec l'absence de parseur d'adresse. By-design.
- **Reco (optionnel)** : envisager de conserver `formatted` tant qu'aucun sous-champ structuré n'a été renseigné, ou avertir l'utilisateur. Purement défensif ; acceptable en l'état.

## Verdict

**APPROUVÉ SOUS RÉSERVE** (Approve with reservations).

- **Aucun finding HIGH/MAJEUR/critique.** Les invariants durs (ZÉRO secret/réseau, single-emission AD-2, round-trip byte-exact, défensif jamais-throw, rétro-compat stricte, AD-13/14) sont **tous vérifiés et verts**.
- **1 MEDIUM (MEDIUM-1)** non corrigible dans le périmètre dur de la story (exigerait une édition de `zcrud_core`) → doit être **justifié par écrit** (mapping app-side `addressSearchField → address`) OU la ligne d'enregistrement `addressSearchField` retirée pour ne pas surestimer la parité. Décision orchestrateur requise avant `done`.
- **4 LOW** optionnels (LOW-1 trivial recommandé ; LOW-2/3/4 non bloquants, pertinents surtout pour un provider réseau réel).

## Résultats bruts

```
dart analyze packages/zcrud_intl   → RC=0  (No issues found!)
flutter test (cwd packages/zcrud_intl) → RC=0  (All tests passed! — 150/150)
python3 scripts/dev/graph_proof.py → RC=0  (CORE OUT=0 OK, ACYCLIQUE OK)
```

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_intl` RC=0, `flutter test` (depuis le package) **150 tests**, graph CORE OUT=0, zéro secret, rétro-compat E11a-2/E11b-2 stricte.

- **0 HIGH / 0 MAJEUR.**
- **MEDIUM-1 (kind `addressSearchField` non atteignable par le dispatcher) — REPORTÉ AVEC JUSTIFICATION ÉCRITE (politique MEDIUM).** Le dispatcher cœur résout via `field.type.name` et l'enum `EditionFieldType` ne contient que `address` (pas `addressSearchField`) — corriger exigerait d'éditer `zcrud_core`, **interdit dans le périmètre dur de DP-8**. **Non bloquant fonctionnellement** : la capacité de recherche est délivrée par le type `address` + le provider `placeSearch` (affordance loupe **kind-agnostique**, pilotée par `placeSearch != null`), donc la parité DODLP de comportement est atteinte via `address`. Le mapping app-side `addressSearchField → EditionFieldType.address` couvre la migration. Pour une **parité stricte de l'enum**, l'ajout de la valeur `addressSearchField` à `EditionFieldType` est un changement cœur d'une ligne → **tracké en follow-up** (lot majeurs / DP-12+, ou intégré à une prochaine story core). La ligne d'enregistrement du kind est conservée (inerte mais non nuisible ; s'activera si le cœur ajoute l'enum).
- **LOW-1 (aperçu non rafraîchi) — CORRIGÉ** (`setState` dans `_onManualEdit`). **LOW-2 (debounce/sessionToken), LOW-3 (course async recherche), LOW-4 (édition pays efface le legacy) — CONSIGNÉS** (optionnels ; pertinents surtout pour un provider réseau réel, injecté par l'app).

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert (MEDIUM-1 justifié + follow-up core tracké).
