# Code Review — DP-5 · Relation dynamique `crudDataSelect` (parité DODLP, gap B7)

- **Story** : `dp-5-relation-dynamique-cruddataselect.md` (18 ACs)
- **Périmètre revu** : `zcrud_core` uniquement (port neutre + config + widget + dispatcher + scope + barrels + tests)
- **Mode** : skill BMAD réel `bmad-code-review` invoqué (step-01 gather-context → step-02 review). Revue conduite en mode subagent autonome (pas de HALT interactif ; cible = diff working-tree vs baseline `1bcae2a` restreint aux fichiers DP-5).
- **Date** : 2026-07-11
- **Verdict** : ✅ **APPROVED** (0 HIGH, 0 MAJEUR, 0 MEDIUM ; 4 LOW/nits non bloquants)

---

## Vérifications rejouées réellement (RC réels)

| Vérification | Commande | RC | Résultat |
|---|---|---|---|
| Analyse statique | `dart analyze` (packages/zcrud_core) | **0** | `No issues found!` |
| Tests | `flutter test` (packages/zcrud_core) | **0** | `All tests passed!` — **683 tests** |
| Graphe de dépendances | `python3 scripts/dev/graph_proof.py` | **0** | `ACYCLIQUE OK` · **`CORE OUT=0 OK`** (out-degree(zcrud_core)=0, 19 arêtes, 14 nœuds) |
| Pureté entrypoint domaine | `dart test test/purity/domain_entrypoint_dart_test.dart` | **0** | `All tests passed!` (domain.dart surface pur-Dart, aucun Flutter) |

Toutes vertes. `melos run generate` sans objet (aucune annotation `@ZcrudModel`/`@ZcrudField`/`@JsonSerializable` touchée).

---

## Analyse par axe adversarial

### (1) AD-1/AD-5 — neutralité du port ✅
- `z_relation_source.dart` importe **uniquement** `dart:async`, `z_field_choice.dart`, `z_registry_error.dart`. Aucun Flutter, aucun `cloud_firestore`/Hive/gestionnaire d'état.
- Port = `Stream<List<ZFieldChoice>> options(Map<String,Object?>)` — **`Stream<List<T>>` nu**, jamais enveloppé dans `Either`. Conforme AD-5.
- `graph_proof` confirme **CORE OUT=0** inchangé ; `domain_entrypoint_dart_test` vert (l'export additif dans `domain.dart` ne fait fuiter aucun Flutter).

### (2) AD-2/SM-1 — abonnement unique + ciblage `filterKeys` ✅
- **Un seul** `StreamSubscription` possédé par le `State` (`_sub`), créé en `initState` (si `source!=null`), annulé en `dispose`, ré-abonné en `didUpdateWidget` **uniquement** si `identical(source)` change OU si `_mapEquals(filterContext)` détecte un changement de contenu. Jamais recréé dans `build`.
- Le dispatcher fabrique un **nouveau** `filterContext` à chaque rebuild de la frontière, mais `didUpdateWidget` compare le **contenu** (`_mapEquals`) → pas de ré-abonnement parasite quand le contenu est stable (ex. incrément de `reveal`). Correct.
- Abonnement ciblé `filterKeys` fusionné dans `_refListenables` (même canal que `refKeys` inter-champs), jamais un canal global. Vérifié par le test « changer `parent` re-interroge (received==2), frappe `other` hors filterKeys = 0 ré-interrogation (received==1) ». **SM-1 respecté.**
- La source résolue via `trySourceFor(sourceKey)` retourne l'**instance enregistrée stable** ⇒ `identical(source)` reste vrai entre rebuilds ⇒ aucun ré-abonnement spurious.

### (3) Fuite de souscription ✅
- Aucun chemin ne laisse deux souscriptions actives : `didUpdateWidget` fait `cancel()` + `= null` avant tout ré-abonnement. `dispose()` annule. `source` non-null→null → annule sans ré-abonner. Pas de leak détecté.

### (4) AD-10 — défensif de bout en bout ✅
- `onError` capturé (bloc vide, `cancelOnError:false`) → aucune exception propagée, dernière liste connue conservée. Test « flux en erreur → aucune exception » vert.
- Avant 1ʳᵉ émission → `_isLoading` → contrôle désactivé + hint `'loading'`. Émission vide → dropdown sans option, pas de crash.
- Repli statique strict quand `source==null` (registre non injecté / clé absente / pas de `ZRelationConfig`) — dispatcher passe `source:null`. Tests « registre null » et « sourceKey non enregistré » verts.
- Valeur courante absente des options live → `values.contains(value)?value:null` (mono) / chip fallback `'$v'` (multi) → non sélectionnée, jamais de crash.
- `fieldListenable(k)` sur un `filterKey` inexistant : `_slice` fait `putIfAbsent` (slice `null` paresseuse) → **pas de throw** ; défensif confirmé côté controller.

### (5) AD-4 — registre instanciable ✅
- `ZRelationSourceRegistry` instanciable (constructeur public, map interne), **jamais** singleton statique. `register` collision → `ZDuplicateRegistrationError` ; `sourceFor` strict → `ZUnregisteredTypeError` ; `trySourceFor` défensif → `null`. Isolation d'instances testée (deux registres indépendants). API alignée sur `ZWidgetRegistry`.

### (6) Rétro-compat additive stricte ✅
- `ZRelationConfig` `const`, `extends ZFieldConfig`, aucun `Function`/`Stream` (const-safe `ConstantReader`), `==`/`hashCode` avec égalité profonde `filterKeys` via `_listEquals`.
- Params widget additifs **optionnels** à défaut rétro-compat (`source=null`, `filterContext={}`, `multiple=false`, `searchable=false`, `options=[]`).
- `ZcrudScope.relationSourceRegistry` défaut `null` + `updateShouldNotify` (`!identical`). Barrels additifs (`domain.dart` export du port). Aucune API renommée/retirée. Enums (`ZDateMode`) camelCase — mais `ZDateMode` relève de DP-10, pas DP-5.

### (7) A11y AD-13 / FR-26 ✅
- Chips : `InputChip` + `MaterialTapTargetSize.padded` (≥48dp), `Semantics(label)`, suppression `deleteButtonTooltipMessage`. Bouton d'ajout dans `ConstrainedBox(minHeight:48)`.
- Modal : `ListView.builder`, `EdgeInsetsDirectional`, `TextAlign.start`, `Semantics(liveRegion)` sur la zone de résultats, boutons `close`/`confirm` l10n, champ `search` l10n. `_SelectionTrigger` `Semantics(button)` + `minHeight:48`.
- Couleurs via `Theme.of(context)` (`hintColor`, `textTheme`). Aucune couleur/inset non directionnel en dur. `EdgeInsets.only(bottom:)` (viewInsets) = axe vertical, hors interdiction RTL.

### (8) Non-régression DP-10 (date) ✅
- La branche `EditionFamily.date` (closures `firstDate`/`lastDate` + `ZDateConfig`) est **intacte et disjointe** de la branche `relation`. Les deux cohabitent via des `field.config is X` typés. Tests date (`dp10_date_bounds_datetime_test.dart`) inclus dans les 683 verts.

---

## Findings

### HIGH / MAJEUR
_Aucun._

### MEDIUM
_Aucun._

### LOW / nits (non bloquants)

**LOW-1 — Contrat `options()` : stream re-souscriptible non documenté**
`z_relation_source.dart:57` / `z_relation_field_widget.dart:113-128`
Sur changement de `source`/`filterContext`, le widget fait `_sub.cancel()` puis rappelle `source.options(ctx).listen(...)`. Si une impl retourne le **même** `Stream` single-subscription à chaque appel (au lieu d'un flux frais ou `broadcast`), le second `.listen()` lève `Bad state: Stream has already been listened to` — levée **synchrone** au `listen`, hors du `onError`, donc propagée hors de `didUpdateWidget`.
- Failure scenario : source Firestore mal implémentée renvoyant un champ `Stream` mis en cache → crash au 1ᵉʳ changement de `filterKey`.
- Remédiation : documenter dans le doc-comment de `ZRelationSource.options` que **chaque appel doit retourner un flux indépendamment souscriptible** (fresh/`broadcast`) ; optionnellement envelopper le `.listen()` dans un `try` défensif. Faible probabilité (les backends réels — `snapshots()` — renvoient un flux neuf par appel).

**LOW-2 — Options périmées après changement de filtre (fenêtre async)**
`z_relation_field_widget.dart:112-116`
Au ré-abonnement, `_liveChoices` n'est **pas** remis à `null`. Pour une source **asynchrone**, entre le ré-abonnement et la nouvelle émission, les options de l'**ancien** filtre restent affichées et sélectionnables (`_isLoading` reste `false`). Un utilisateur pourrait sélectionner une option invalidée par le nouveau filtre.
- C'est un compromis délibéré (évite un flash « chargement » ; conforme « conservation de la dernière liste connue » AC10), mais non testé pour un flux asynchrone.
- Remédiation (optionnelle) : réinitialiser `_liveChoices=null` sur changement de `filterContext` (repasser en chargement), OU documenter le comportement retenu.

**LOW-3 — Couverture SM-1 dynamique partielle**
`test/presentation/edition/z_relation_field_widget_test.dart:232-275`
Le test « 100 frappes = structurel == 1 » utilise un champ `relation` **sans source** (chemin repli statique) : il ne parcourt pas la voie d'abonnement dynamique. Le « 0 ré-interrogation hors filterKeys » est bien couvert (received==1, un seul `pump`), mais aucun test ne couvre (a) le ré-abonnement sur **swap de source**, ni (b) l'annulation en `dispose`.
- Remédiation (optionnelle) : ajouter un cas 100-frappes avec source active + un cas de swap de `sourceKey`.

**LOW-4 — Double libellé possible en `fieldSize: large` (interaction DP-1)**
`z_field_widget.dart:265-271` × `z_relation_field_widget.dart:178-180,215`
La branche `relation` ne passe pas de mode `bare` (contrairement à text/number/select) : un champ `relation` en `ZFieldSize.large` afficherait le libellé **deux fois** (Card `ZLargeFieldCard` + `labelText`/header interne du widget relation). Interaction cross-story DP-1/DP-5 ; combinaison inhabituelle.
- Remédiation (optionnelle, hors périmètre strict DP-5) : soit exclure `relation` du wrapping `large`, soit propager un `bare` supprimant le libellé interne.

---

## Conclusion

Implémentation **conforme** aux invariants ciblés : port neutre `Stream<List<ZFieldChoice>>` nu (AD-1/AD-5, CORE OUT=0), abonnement unique possédé par le `State` avec ciblage `filterKeys` (AD-2/SM-1), défensif complet (AD-10), registre instanciable injecté (AD-4), rétro-compat additive stricte, a11y/RTL (AD-13), et **aucune régression DP-10**. Les 4 findings sont des **LOW** (documentation de contrat, fenêtre async cosmétique, couverture de test, interaction DP-1) — aucun ne bloque le passage `review → done`.

**Verdict : APPROVED.** Findings LOW à consigner (correction optionnelle si triviale, sinon reportée sans justification requise pour un LOW).
