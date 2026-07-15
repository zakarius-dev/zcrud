---
baseline_commit: aaa7989612f5213509daae9ddbddb7a7513cd650
---

# Story ES-5.4 : Disponibilité de fonctionnalités injectable — `ZFeatureAvailability`

Status: review

<!-- Epic ES-5 · Taille S · SÉQ légère (fichier ISOLÉ zcrud_study) · Peut suivre ES-5.3 (done). DERNIÈRE story d'ES-5 → déclenche la rétro ES-5. Workstream B — ISOLATION vs workstream A (ES-4 / zcrud_session / scripts/ci). READ-ONLY sauf le fichier story + les fichiers de PROD/test de zcrud_study listés. -->

## Story

As a **développeur intégrateur (Zakarius, apps IFFD et lex_douane aux roadmaps d'éditeurs DIFFÉRENTES)**,
I want **une interface INJECTABLE `ZFeatureAvailability` qui exprime de façon déclarative la disponibilité progressive des fonctionnalités « study tools » (sections / actions d'ajout / actions d'item), COMPOSÉE avec le layout/hub/menu déjà livrés (ES-5.1/5.2/5.3)**,
so that **chaque app fournit ses propres disponibilités par simple injection — sans modifier `zcrud_study` — et une fonctionnalité marquée indisponible n'est ni rendue ni actionnable, en RÉUTILISANT le motif AD-4 `enabled`/`onTap: null` d'ES-5.3 (aucun nouveau chemin de rendu, aucun gestionnaire d'état)**.

---

## Contexte & problème (pourquoi cette story existe)

ES-5.1/5.2/5.3 ont livré (done) le layout « study tools » apparence IFFD comme composition paramétrique : `ZStudyToolsSectionSpec` (`addAction` nullable), `ZSectionedStudyLayout`, `ZStudyToolsPage` (scoping SM-1 isolé), `ZContentHubSheet`/`ZContentHubEntry` (`enabled`/`onTap` — `enabled == false || onTap == null ⇒ isActionable == false`, AD-4) et `ZItemActionsMenu`/`ZItemAction` (`onSelected == null ⇒ action ABSENTE du menu`, AD-4). **Le motif « capacité absente = `null`/`enabled:false` » est donc DÉJÀ le vocabulaire de non-disponibilité du package.**

Ce qui manque (FR-S24, AD-25) : un mécanisme **déclaratif et injectable** permettant à l'app hôte de DÉCIDER *quelles* fonctionnalités sont disponibles — sans coder en dur cette décision dans `zcrud_study`, et sans que deux apps aux roadmaps différentes ne se marchent dessus. Aujourd'hui, rien ne relie « telle fonctionnalité est-elle activée pour cette app ? » aux slots `onTap`/`addAction`/`onSelected` : chaque appelant devrait re-câbler manuellement des `null` un peu partout.

**ES-5.4 comble cet écart par une INTERFACE (jamais une classe `const` compilée figeant une roadmap) :**

1. **`ZFeatureAvailability`** — `abstract interface class` pure (domaine présentation) : `bool isAvailable(String featureKey)` (featureKey = `String` OPAQUE, extensible AD-4 — jamais un enum fermé couplé aux satellites `zcrud_note`/`zcrud_document`/…). Deux méthodes de COMPOSITION concrètes (non abstraites) réutilisant le vocabulaire AD-4 d'ES-5.3 : `bool enabledFor(String)` (⇒ `ZContentHubEntry.enabled`) et `VoidCallback? gate(String, VoidCallback?)` (⇒ `onTap`/`addAction`/`onSelected` : retourne le callback SSI disponible, sinon `null` ⇒ non actionnable/absente PAR LE MÉCANISME EXISTANT).
2. **Implémentations de référence const-compatibles** (immuables) : `ZAllFeaturesAvailable` (tout disponible — **DÉFAUT fail-open**, cf. D1) et `ZMapFeatureAvailability` (`Map<String,bool> flags` + `bool availableWhenUnspecified` — flag absent ⇒ politique par défaut de la map).
3. **Accès injecté Flutter-native** — `ZFeatureAvailabilityScope` (`InheritedWidget` pur, AD-15 — AUCUN gestionnaire d'état) : `ZFeatureAvailabilityScope.of(context)` renvoie l'instance injectée, ou **`const ZAllFeaturesAvailable()` (fail-open)** si aucun ancêtre n'en fournit. L'injection peut aussi se faire par **paramètre** (l'app passe directement une `ZFeatureAvailability` au code qui construit les entrées/actions). Aucune modification de `zcrud_core`/`ZcrudScope`.

**Reconnaissance READ-ONLY IFFD (AUCUN fichier IFFD modifié)** — l'état réel de la gestion de disponibilité mesuré :
- **Pas d'abstraction de disponibilité** dans IFFD : la disponibilité est portée par des **booléens codés en dur propagés à la main** widget par widget. `folder_content_creating_buttons.dart:22` `final bool readOnly;` + `:23` `final bool subjectToolPage;` ; le gating d'action réel est `folder_content_creating_buttons.dart:~72` `? null` et `onPressed: widget.readOnly ? null : …` (MESURÉ : `onPressed: widget.readOnly` sur 2 boutons). Autrement dit IFFD utilise DÉJÀ, ponctuellement, le motif « bool ⇒ `onPressed: null` » — mais SANS abstraction : chaque widget re-teste son propre bool, aucune source déclarative unique, aucun point d'injection. `grep -niE "isAvailable|featureFlag|comingSoon|coming_soon"` sur `lib/` IFFD = **0** occurrence (aucun feature-flag structuré).
- `ZFeatureAvailability` est donc une **abstraction propre neuve** : elle GÉNÉRALISE le `readOnly ? null : …` diffus d'IFFD en une source déclarative injectable, et se BRANCHE sur le vocabulaire AD-4 (`enabled`/`onTap:null`) déjà livré en ES-5.3 — pas un portage 1:1.

---

## Périmètre & NON-périmètre (garde-fous)

**DANS le périmètre ES-5.4** (package `zcrud_study` UNIQUEMENT, fichier ISOLÉ) :

1. **`z_feature_availability.dart` (NEW)** — un SEUL fichier de PROD :
   - `abstract interface class ZFeatureAvailability` : `const ZFeatureAvailability();` + `bool isAvailable(String featureKey);` (abstrait) + méthodes de composition concrètes `bool enabledFor(String featureKey) => isAvailable(featureKey);` et `VoidCallback? gate(String featureKey, VoidCallback? action) => isAvailable(featureKey) ? action : null;`.
   - `class ZAllFeaturesAvailable implements ZFeatureAvailability` : `const ZAllFeaturesAvailable();` — `isAvailable(_) => true` (fail-open, D1). `@immutable`.
   - `class ZMapFeatureAvailability implements ZFeatureAvailability` : `const ZMapFeatureAvailability(this.flags, {this.availableWhenUnspecified = true});` — `isAvailable(k) => flags[k] ?? availableWhenUnspecified`. `@immutable`, const-compatible (une app déclare `const ZMapFeatureAvailability({'note': true, 'exam': false})`).
   - `class ZFeatureAvailabilityScope extends InheritedWidget` : champ `final ZFeatureAvailability availability;` ; statiques `static ZFeatureAvailability of(BuildContext) → injectée ou const ZAllFeaturesAvailable()` (fail-open, D1) et `static ZFeatureAvailability? maybeOf(BuildContext)` ; `updateShouldNotify => availability != oldWidget.availability`. AUCUN état mutable, AUCUN gestionnaire d'état (AD-2/AD-15).
2. **Export barrel** — `lib/zcrud_study.dart` (MODIFIED) : `export 'src/presentation/z_feature_availability.dart';` (types publics `ZFeatureAvailability`, `ZAllFeaturesAvailable`, `ZMapFeatureAvailability`, `ZFeatureAvailabilityScope`).
3. **Tests discriminants** — `test/z_feature_availability_test.dart` (NEW) : gating/composition, défaut fail-open, injection scope + SM-SC2, invariants.

**HORS périmètre (NE PAS implémenter ici)** :
- Toute modification de `z_sectioned_study_layout.dart`/`z_study_tools_page.dart`/`z_content_hub_sheet.dart`/`z_item_actions_menu.dart`/`z_study_tools_section_spec.dart` : ES-5.4 **COMPOSE** avec ces types via leurs slots `null`/`enabled` EXISTANTS (ES-5.3) — **aucun nouveau chemin de rendu**, aucune régénération golden (l'apparence par défaut, fail-open, est INCHANGÉE). Anti-inertie : réutiliser, ne pas dupliquer.
- Toute modification de `zcrud_core`/`ZcrudScope` (AD-1), de `zcrud_study_kernel`, de `scripts/ci`, de `graph_proof.py`, de `sprint-status.yaml` (workstream A actif — ISOLATION).
- Tout enum FERMÉ de featureKeys couplé aux satellites (`FlashcardModel`/`ZSmartNote`/…) : featureKey reste `String` opaque extensible (AD-4). L'app définit ses propres clés (constantes app-side).
- Toute persistance / repository / résolution Firestore de la config de disponibilité (l'app injecte une `ZFeatureAvailability` déjà construite ; sa provenance — remote-config, build-flag — est hors package).
- Toute nouvelle arête de package (aucune dépendance vers un satellite ni un tiers).

---

## Décisions de conception (D1..D3)

**D1 — DÉFAUT = fail-OPEN (`ZAllFeaturesAvailable`, tout disponible), JUSTIFIÉ.**
Quand AUCUNE disponibilité n'est injectée (pas d'ancêtre `ZFeatureAvailabilityScope`, ou clé absente d'une `ZMapFeatureAvailability` avec `availableWhenUnspecified` au défaut `true`), la fonctionnalité est **disponible**. Justification :
- **Non-régression / SM-SC2** : `zcrud_study` est un package PARTAGÉ dont l'apparence de référence (ES-5.1/5.2/5.3 goldens + tests) est « tout rendu, tout actionnable ». Un défaut fail-safe (tout MASQUÉ) casserait cette baseline et FORCERAIT chaque consommateur à énumérer exhaustivement ses features pour ne rien perdre — friction d'adoption inverse de FR-S24 (« fournir ses disponibilités SANS modifier zcrud_study »).
- **La restriction est un OPT-IN de l'app** : c'est l'app qui décide de RETIRER une fonctionnalité (roadmap progressive), pas le package qui décide de la cacher par ignorance. Le package ne doit JAMAIS masquer une fonctionnalité qu'une app a réellement câblée simplement parce qu'aucune disponibilité n'a été fournie.
- **Cohérence AD-4** : la « capacité absente » réelle reste exprimée par les callbacks `null` de l'APP (ES-5.3) ; `ZFeatureAvailability` ne fait que RELAYER une décision d'app. En l'absence de décision, on ne relaie aucune restriction ⇒ fail-open. Le risque « fuite d'une feature non finie » est porté par l'app (elle ne câble pas le callback), pas par un défaut fail-safe du package.
- **Contraste `ZMapFeatureAvailability.availableWhenUnspecified`** : configurable — une app qui PRÉFÈRE une politique fail-safe locale (clé inconnue ⇒ masquée) passe `availableWhenUnspecified: false`. Le défaut global du package reste fail-open ; la politique fail-safe est un choix explicite et local de l'app.

**D2 — `ZFeatureAvailability` est une INTERFACE (jamais une classe `const` figeant une roadmap dans le package partagé), AD-25/SM-SC2.**
`abstract interface class` : les décisions de disponibilité vivent dans l'IMPLÉMENTATION injectée par l'app, jamais dans une constante compilée du package. `ZAllFeaturesAvailable`/`ZMapFeatureAvailability` sont des implémentations de RÉFÉRENCE neutres (l'une inconditionnelle, l'autre paramétrée par la map de l'app) — aucune ne code en dur une liste de features « métier ». Preuve SM-SC2 : deux apps injectant deux `ZMapFeatureAvailability` différentes obtiennent des disponibilités différentes SANS toucher `zcrud_study` (AC3).

**D3 — Composition, pas nouveau rendu (AD-4, anti-inertie).**
Une fonctionnalité indisponible n'est « ni rendue ni actionnable » via le mécanisme DÉJÀ livré : `gate('k', cb)` renvoie `null` ⇒ `ZContentHubEntry(onTap: null)` (tuile désactivée, ES-5.3 AC3) / `ZStudyToolsSectionSpec(addAction: null)` (action d'ajout ABSENTE, ES-5.1) / `ZItemAction(onSelected: null)` (action ABSENTE du menu, ES-5.3 AC4) ; `enabledFor('k')` alimente `ZContentHubEntry.enabled`. ES-5.4 n'introduit AUCUN widget de rendu — juste la fabrique de `null`/`bool` consommée par l'existant.

---

## Acceptance Criteria

Chaque AC est à **pouvoir discriminant** (R12) : un test DOIT pouvoir le faire ROUGIR si l'implémentation dévie. **AC1 (composition gating) et AC2 (défaut) sont CENTRAUX.**

**AC1 — [CENTRAL] Une fonctionnalité indisponible n'est ni actionnable ni rendue (composition AD-4 avec ES-5.3)**
**Given** une `ZFeatureAvailability` où `isAvailable('note') == true` et `isAvailable('exam') == false` (ex. `const ZMapFeatureAvailability({'note': true, 'exam': false})`), et un callback témoin `cb` (compteur d'invocations)
**When** on compose les surfaces ES-5.3 avec cette disponibilité — `ZContentHubEntry(enabled: fa.enabledFor(k), onTap: fa.gate(k, cb))` pour `'note'` et `'exam'`, rendues dans un `ZContentHubSheet`, et de même `ZItemAction(onSelected: fa.gate(k, cb))` dans un `ZItemActionsMenu`
**Then** pour `'note'` (disponible) : `gate('note', cb) == cb` (identité), `enabledFor('note') == true` ; l'entrée est actionnable et tape ⇒ `cb` invoqué **exactement 1 fois** ; l'action `'note'` est PRÉSENTE dans le menu
**And** pour `'exam'` (indisponible) : `gate('exam', cb) == null`, `enabledFor('exam') == false` ; l'entrée du hub est **non actionnable** (tuile désactivée, tap sans effet, compteur = 0) et l'action `'exam'` est **ABSENTE** du menu (`ZItemAction.onSelected == null`, filtrée par ES-5.3)
**And** (pouvoir discriminant — R3-I1) si `gate` renvoie le callback même quand `isAvailable == false` (ou si `enabledFor` renvoie `true` pour une feature indisponible), l'entrée `'exam'` redevient actionnable / l'action `'exam'` réapparaît ⇒ l'assertion `compteur == 0` / `findsNothing` ROUGIT.

**AC2 — [CENTRAL] Comportement PAR DÉFAUT = fail-open (tout disponible), sans injection (D1)**
**Given** (a) aucune disponibilité injectée — un `BuildContext` SANS ancêtre `ZFeatureAvailabilityScope` ; (b) `const ZAllFeaturesAvailable()` ; (c) `const ZMapFeatureAvailability({'x': true})` interrogée sur une clé ABSENTE `'y'`
**When** on résout la disponibilité
**Then** (a) `ZFeatureAvailabilityScope.of(context).isAvailable(<toute clé>) == true` (repli `ZAllFeaturesAvailable`, fail-open) et `ZFeatureAvailabilityScope.maybeOf(context) == null` ; (b) `ZAllFeaturesAvailable().isAvailable(<toute clé>) == true` ; (c) `isAvailable('y') == availableWhenUnspecified == true` (défaut), et avec `availableWhenUnspecified: false` ⇒ `isAvailable('y') == false` (politique fail-safe LOCALE opt-in)
**And** (pouvoir discriminant — R3-I2) si le défaut dévie — `ZAllFeaturesAvailable` renvoie `false`, OU `.of(context)` sans ancêtre renvoie un repli fail-safe (tout masqué) / lève une exception, OU `ZMapFeatureAvailability` masque une clé absente alors que `availableWhenUnspecified == true` — les assertions `== true` ROUGISSENT.

**AC3 — Interface INJECTABLE : deux apps aux roadmaps différentes, ZÉRO modification de `zcrud_study` (D2/SM-SC2, AD-25/AD-15)**
**Given** deux implémentations distinctes injectées — app A : `const ZMapFeatureAvailability({'note': true, 'exam': false})` ; app B : `const ZMapFeatureAvailability({'note': false, 'exam': true})` — chacune fournie via `ZFeatureAvailabilityScope(availability: …, child: …)` OU passée par paramètre
**When** un même sous-arbre / une même logique de composition lit `ZFeatureAvailabilityScope.of(context)` (ou le paramètre) et interroge `'note'`/`'exam'`
**Then** sous A : `'note'` disponible / `'exam'` indisponible ; sous B : `'note'` indisponible / `'exam'` disponible — les DEUX résultats sont produits par le MÊME code de `zcrud_study` non modifié (seule l'instance injectée diffère), prouvant l'injectabilité (SM-SC2)
**And** (pouvoir discriminant — R3-I4) si l'implémentation IGNORE la config injectée (ex. `ZMapFeatureAvailability.isAvailable` renvoie une constante, ou `ZFeatureAvailabilityScope.of` renvoie toujours le même repli au lieu de l'ancêtre injecté), A et B produisent des réponses IDENTIQUES ⇒ l'assertion « A != B » ROUGIT.

**AC4 — Invariants transverses AD-1/AD-2/AD-4/AD-15 respectés**
**Given** le fichier `z_feature_availability.dart` + le barrel après ajout
**When** on l'analyse
**Then** `ZFeatureAvailability` est une `abstract interface class` (jamais une classe `const` figeant une roadmap — D2) ; `ZAllFeaturesAvailable`/`ZMapFeatureAvailability` sont `@immutable` et **const-compatibles** (constructeurs `const`, champs `final`) ; `ZFeatureAvailabilityScope` est un `InheritedWidget` pur — **AUCUN** import/symbole de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`/`ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`/`setState`), aucune couleur/label/`IconData` codé en dur (le fichier ne rend rien — pure logique), featureKey `String` opaque (aucun enum fermé couplé aux satellites, AD-4)
**And** l'arête de dépendance de `zcrud_study` est INCHANGÉE (`→ zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations` ; le fichier importe au plus `package:flutter/widgets.dart` pour `InheritedWidget`/`VoidCallback` — aucune nouvelle arête de package).

**AC5 — Acyclicité AD-1 / CORE OUT=0 préservées, vérif verte (RC hors pipe R15)**
**Given** le package `zcrud_study` après ajout de `ZFeatureAvailability`
**When** on rejoue les gates CIBLÉS
**Then** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE** avec **out-degree(zcrud_core) == 0** (arêtes de `zcrud_study` inchangées ; `melos list` reste à **20** packages — INCHANGÉ)
**And** `flutter test` (RUNNER Flutter, R14) est **VERT RC=0** (AC1/AC2/AC3 discriminants + non-régression des tests ES-5.1/5.2/5.3 — golden INCHANGÉ, aucune apparence par défaut modifiée) ; `dart analyze` (zcrud_study) RC=0 ; scans interdits VIDES hors commentaires.

---

## Tasks / Subtasks

- [x] **T1 — `ZFeatureAvailability` (interface) + méthodes de composition (AC1, AC4)**
  - [x] `z_feature_availability.dart` (NEW) : `abstract interface class ZFeatureAvailability { const ZFeatureAvailability(); bool isAvailable(String featureKey); }` + méthodes CONCRÈTES `bool enabledFor(String featureKey) => isAvailable(featureKey);` et `VoidCallback? gate(String featureKey, VoidCallback? action) => isAvailable(featureKey) ? action : null;`. Docstrings : featureKey `String` OPAQUE extensible (AD-4) ; `gate`/`enabledFor` = points de COMPOSITION avec `ZContentHubEntry.onTap`/`enabled`, `ZStudyToolsSectionSpec.addAction`, `ZItemAction.onSelected` (ES-5.3, `null`/`false` = capacité absente).

- [x] **T2 — Implémentations de référence const-compatibles (AC2, AC3, AC4)**
  - [x] `class ZAllFeaturesAvailable extends ZFeatureAvailability` : `const ZAllFeaturesAvailable();` `@immutable` — `isAvailable(_) => true` (fail-open, D1). Documenter le DÉFAUT + justification D1. (NOTE conception : `extends` — non `implements` — car les impls de référence vivent dans la MÊME librairie que l'`interface class` : `extends` intra-librairie hérite des défauts concrets `enabledFor`/`gate` sans les dupliquer ; `implements` obligerait à les redéfinir. AC4 exige `abstract interface class` sur le type de base — respecté.)
  - [x] `class ZMapFeatureAvailability extends ZFeatureAvailability` : `const ZMapFeatureAvailability(this.flags, {this.availableWhenUnspecified = true});` `@immutable` — `final Map<String,bool> flags; final bool availableWhenUnspecified;` ; `isAvailable(k) => flags[k] ?? availableWhenUnspecified`. `availableWhenUnspecified` = politique locale opt-in (fail-safe si `false`). `==`/`hashCode` : égalité PROFONDE de `flags` implémentée inline (`_flagsEqual`, PAS `mapEquals` — pour ne dépendre QUE de `package:flutter/widgets.dart`, AC4/AD-1) ⇒ `updateShouldNotify` distingue par CONTENU.

- [x] **T3 — Accès injecté Flutter-native `ZFeatureAvailabilityScope` (AC2, AC3, AC4)**
  - [x] `class ZFeatureAvailabilityScope extends InheritedWidget` : `final ZFeatureAvailability availability;` ; `const ZFeatureAvailabilityScope({required this.availability, required super.child, super.key});` ; `static ZFeatureAvailability of(BuildContext c) => maybeOf(c) ?? const ZAllFeaturesAvailable();` (repli fail-open D1) ; `static ZFeatureAvailability? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ZFeatureAvailabilityScope>()?.availability;` ; `bool updateShouldNotify(old) => availability != old.availability;`. AUCUN gestionnaire d'état (AD-15), InheritedWidget pur (AD-2).

- [x] **T4 — Export barrel (AC1..AC4)**
  - [x] `lib/zcrud_study.dart` : `export 'src/presentation/z_feature_availability.dart';` (7e export). Impl sous `lib/src/`.

- [x] **T5 — Tests discriminants (AC1, AC2, AC3, AC4) — le cœur**
  - [x] `test/z_feature_availability_test.dart` (NEW, 13 tests) :
    - (AC1) COMPOSITION : `ZMapFeatureAvailability({'note': true, 'exam': false})` → `gate`/`enabledFor` alimentent un `ZContentHubSheet` (2 entrées) + un `ZItemActionsMenu` (2 actions) ; widget test : tap `'note'` ⇒ compteur=1 ; `'exam'` ⇒ tuile désactivée (compteur=0) + action ABSENTE du menu (`findsNothing`). Assertions unitaires `gate('exam', cb) == null`, `gate('note', cb) == cb`.
    - (AC2) DÉFAUT fail-open : `of(context)` sans ancêtre ⇒ `ZAllFeaturesAvailable` (`isAvailable('anything') == true`), `maybeOf(context) == null` ; `ZAllFeaturesAvailable().isAvailable(...) == true` ; `ZMapFeatureAvailability({'x': true}).isAvailable('y') == true` puis `availableWhenUnspecified: false` ⇒ `false`.
    - (AC3) INJECTABILITÉ / SM-SC2 : même code de lecture sous scope A vs scope B ⇒ résultats OPPOSÉS pour `'note'`/`'exam'` (widget test avec deux `ZFeatureAvailabilityScope`), MÊME code non modifié. `expect(resA, isNot(resB))`.
    - (AC4) invariants : const-compatibilité (`identical(const ...)` canonicalisation) ; égalité profonde `mapEquals`-like ; `updateShouldNotify` change quand la config injectée change.

- [x] **T6 — Injections R3 + vérif verte CIBLÉE (AC5)**
  - [x] R3-I1..I4 joués RÉELLEMENT (RC=1 RED capturé au Debug Log), restaurés par ÉDITION CIBLÉE (aucun `git checkout/restore/stash`), re-vérif verte.
  - [x] Vérif verte CIBLÉE (RC hors pipe R15) : `flutter test` (zcrud_study) RC=0 (51 tests), `dart analyze` RC=0, `graph_proof.py` RC=0 (ACYCLIQUE + CORE OUT=0 ; `melos list`=20), scans interdits vides. Golden INCHANGÉ.

---

## Dev Notes

### Architecture — invariants NON-NÉGOCIABLES applicables (AD)
- **AD-25** [archi:249-252] — `ZStudyToolsPage` = liste de sections paramétriques à scoping isolé ; **`ZFeatureAvailability` est une INTERFACE INJECTABLE (jamais une classe `const` compilée)** : deux apps aux roadmaps différentes fournissent leurs disponibilités SANS modifier `zcrud_study` ; `ZItemActionsMenu`/`ZContentHubSheet` paramétrés (`null` = action absente, AD-4).
- **AD-4** [archi:46] — composition, pas héritage de vues ; slots additifs ; **callback/valeur `null` = capacité ABSENTE** (jamais un no-op silencieux). ES-5.4 RELAIE une décision d'app vers ces slots (`gate ⇒ null`, `enabledFor ⇒ false`) — aucun nouveau chemin de rendu. featureKey `String` opaque extensible (aucun enum fermé couplé aux satellites).
- **AD-15** [archi:44] — AUCUN gestionnaire d'état dans `zcrud_study` ; injection via `InheritedWidget` (`ZFeatureAvailabilityScope`) OU paramètre — jamais `ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`. Aucune modification de `zcrud_core`/`ZcrudScope` (isolation + AD-1).
- **AD-2** [archi:44] — réactivité Flutter-native pure ; `InheritedWidget` = mécanisme SDK, aucun `setState` d'échelle page/section, aucun état mutable dans le scope.
- **AD-1 / AD-17** [archi:54] — graphe **acyclique**, `zcrud_study → zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations` (jamais l'inverse), **out-degree(zcrud_core)=0**. Le fichier importe au plus `package:flutter/widgets.dart` (`InheritedWidget`/`VoidCallback`) — AUCUNE nouvelle arête de package (`graph_proof.py` inchangé, `melos list`=20).
- **AD-13** [archi:51] — a11y/directionnel/thème : SANS OBJET direct ici (le fichier ne rend AUCUNE UI — pure logique de disponibilité). La composition avec le hub/menu/section RÉUTILISE l'a11y déjà conforme d'ES-5.1/5.3.

### API réutilisée (déjà livrée, NE PAS réimplémenter ni dupliquer — anti-inertie)
- **`ZContentHubEntry`** [`z_content_hub_sheet.dart:27-54`, ES-5.3] — `enabled` (`bool`, défaut `true`) + `onTap` (`VoidCallback?`) ; `bool get isActionable => enabled && onTap != null`. `ZFeatureAvailability` alimente ces DEUX slots (`enabled: fa.enabledFor(k)`, `onTap: fa.gate(k, cb)`). NE PAS réintroduire de logique d'actionnabilité.
- **`ZItemAction`** [`z_item_actions_menu.dart:52-72`, ES-5.3] — `onSelected` (`VoidCallback?`) ; `ZItemActionsMenu` FILTRE `where((a) => a.onSelected != null)` (`:101-102`) ⇒ `onSelected: null` = action ABSENTE. `fa.gate(k, cb)` produit ce `null`.
- **`ZStudyToolsSectionSpec`** [`z_study_tools_section_spec.dart:71-72`, ES-5.1] — `addAction` (`VoidCallback?`, `null` = action d'ajout ABSENTE). `fa.gate(k, cb)` produit ce `null`.
- **Barrel** [`lib/zcrud_study.dart`] — 6 exports actuels ; ajouter 1 export.
> Le motif « capacité absente = `null`/`enabled:false` » est le VOCABULAIRE d'ES-5.3. ES-5.4 = une fabrique de ce vocabulaire pilotée par une décision d'app injectée. AUCUNE duplication de rendu/actionnabilité.

### Reconnaissance IFFD (READ-ONLY, MESURÉ, aucun fichier modifié)
- `~/DEV/iffd/lib/src/presentation/features/folders/widgets/folder_content_creating_buttons.dart:22` `final bool readOnly;` ; `:23` `final bool subjectToolPage;` ; `:~72` `? null` et `onPressed: widget.readOnly ? null : …` (gating d'action réel par bool codé en dur, propagé à la main). `grep -niE "isAvailable|featureFlag|comingSoon"` sur `lib/` IFFD = **0** ⇒ aucune abstraction de disponibilité structurée : `ZFeatureAvailability` GÉNÉRALISE ce `readOnly ? null : …` diffus en une source déclarative injectable branchée sur AD-4.

### Injections R3 prévues (défaut réel → test RED → restauration par ÉDITION CIBLÉE, R13)
> JAMAIS `git checkout/restore/stash` (working-tree partagé workstream A). Restauration par édition ciblée du fichier, RC RED puis GREEN consignés au Debug Log.

| # | Injection (édition ciblée dans la PROD) | Test attendu RED | Restauration |
|---|---|---|---|
| **R3-I1** (composition gating — CENTRAL AC1) | `gate(k, action) => action;` (ignore `isAvailable`) OU `enabledFor(k) => true;` | `test AC1` : entrée `'exam'` redevient actionnable (compteur 0→1) / action `'exam'` PRÉSENTE ⇒ `expect(compteur, 0)` / `findsNothing` ROUGIT | rétablir `isAvailable(k) ? action : null` / `=> isAvailable(k)` |
| **R3-I2** (défaut fail-open — CENTRAL AC2) | `ZAllFeaturesAvailable.isAvailable(_) => false;` OU `ZFeatureAvailabilityScope.of` repli `=> const _NoneAvailable()` OU `ZMapFeatureAvailability` défaut `?? false` | `test AC2` : `isAvailable(...) == true` ROUGIT (`Expected true / Actual false`) | rétablir `=> true` / repli `const ZAllFeaturesAvailable()` / `?? availableWhenUnspecified` |
| **R3-I3** (injection scope — AC3) | `ZFeatureAvailabilityScope.of` renvoie toujours `const ZAllFeaturesAvailable()` (ignore `dependOnInheritedWidgetOfExactType`) | `test AC3` : sous scope B `'note'` reste disponible ⇒ `expect(resB['note'], false)` ROUGIT | rétablir `maybeOf(c) ?? const ZAllFeaturesAvailable()` |
| **R3-I4** (config honorée / SM-SC2 — AC3) | `ZMapFeatureAvailability.isAvailable(_) => true;` (ignore `flags`) | `test AC3` : A et B produisent le MÊME résultat ⇒ `expect(resA, isNot(resB))` ROUGIT | rétablir `flags[k] ?? availableWhenUnspecified` |

### GOTCHA RUNNER (R14) — `flutter test`, PAS `dart test`
`zcrud_study` déclare `flutter: sdk: flutter` → package **Flutter**. `InheritedWidget`/widget tests importent `flutter`/`flutter_test` → tournent UNIQUEMENT sous `flutter test`. `codegen-distribution` : aucun `@ZcrudModel` dans `zcrud_study` (pas de `*.g.dart`), sans objet.

### GOTCHA RC (R15) — mesurer le vrai code de sortie HORS pipe
```bash
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
```
Un `flutter test | tee` renvoie le RC de `tee`, pas du test.

### Golden — INCHANGÉ
ES-5.4 n'introduit AUCUN rendu et ne modifie AUCUNE apparence par défaut (fail-open ⇒ tout rendu comme avant). `study_tools_sectioned.png` reste INCHANGÉ ; le pouvoir discriminant golden ES-5.1 n'est pas touché. Aucun `--update-goldens`.

### Injections R3 — restauration (R13)
Working-tree PARTAGÉ avec workstream A (ES-4) : **JAMAIS** `git checkout/restore/stash`. Restaurer chaque injection par ÉDITION CIBLÉE inverse, RC RED puis GREEN consignés au Debug Log.

### Structure du package (à modifier/créer)
```text
packages/zcrud_study/
  lib/
    zcrud_study.dart                              # + export z_feature_availability.dart (MODIFIED)
    src/presentation/
      z_feature_availability.dart                 # ZFeatureAvailability + ZAllFeaturesAvailable + ZMapFeatureAvailability + ZFeatureAvailabilityScope (NEW)
  test/
    z_feature_availability_test.dart              # AC1 composition + AC2 défaut + AC3 injectabilité/SM-SC2 + AC4 (NEW)
```

### Project Structure Notes
- **Isolation workstream B** : NE PAS toucher `zcrud_core`, `zcrud_study_kernel`, `zcrud_session`, `scripts/ci`, `sprint-status.yaml` (workstream A actif). Aucun fichier hors `packages/zcrud_study/**` (sauf ce fichier story). NE PAS toucher les autres fichiers `presentation/` d'ES-5.x (composition via leurs slots publics EXISTANTS).
- `graph_proof.py` INCHANGÉ (même package, aucune nouvelle arête — `InheritedWidget`/`VoidCallback` = `package:flutter`, déjà présent). `melos list` reste à **20** packages. `pubspec.yaml` de `zcrud_study` INCHANGÉ.

### Vérif verte à rejouer (commandes exactes, RC hors pipe R15 — CIBLÉES, PAS de `melos verify`/`analyze` repo-wide tant que workstream A actif)
```bash
# 1. Tests du package (RUNNER = flutter test, R14) — composition + défaut + injectabilité + non-régr. ES-5.x
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"

# 2. Analyse ciblée du package (RC=0)
OUT=$(cd packages/zcrud_study && dart analyze 2>&1); RC=$?; echo "$OUT" | tail -20; echo "RC=$RC"

# 3. Acyclicité AD-1 + CORE OUT=0 (inchangé — aucune arête nouvelle)
OUT=$(python3 scripts/dev/graph_proof.py 2>&1); RC=$?; echo "$OUT"; echo "RC=$RC"

# 4. Scans interdits (doivent être VIDES, hors commentaires)
grep -rnE "flutter_riverpod|package:get/|package:provider/|ConsumerWidget|WidgetRef|Get\.|Provider\.of|setState\(" packages/zcrud_study/lib/src/presentation/z_feature_availability.dart
```
**Attendu** : (1) `flutter test` RC=0 (AC1/AC2/AC3 discriminants + non-régr. ES-5.1/5.2/5.3, golden inchangé) ; (2) `dart analyze` RC=0 ; (3) `ACYCLIQUE` + `out-degree(zcrud_core)=0` RC=0, `melos list`=20 ; (4) scans VIDES (seule occurrence tolérée = commentaire).
> La vérif repo-wide (`melos run analyze` ET `melos run verify`) reste à la charge de l'orchestrateur AU GATE DE COMMIT D'EPIC (workstreams au repos, après la rétro ES-5) — non rejouée ici (isolation).

### Dépendances de la story
- **Dépend de** : **ES-5.1/5.2/5.3 (done)** — `ZFeatureAvailability` COMPOSE avec `ZContentHubEntry`/`ZItemAction`/`ZStudyToolsSectionSpec.addAction` (slots `null`/`enabled` livrés). Aucun couplage kernel/core.
- **Position dans l'epic** : **DERNIÈRE story d'ES-5** — sa clôture (`done`) déclenche la **rétrospective ES-5** (`bmad-retrospective`) puis le commit unique de fin d'epic (inclut les fichiers de `zcrud_study` ; golden inchangé). Les épics aval (ES-6 notes / ES-7 documents / ES-10 mindmap) pourront injecter une `ZFeatureAvailability` pour activer/désactiver progressivement leurs éditeurs dans `ZStudyToolsPage`.

### References
- [Source: epics-zcrud-study-2026-07-12/epics.md#Story-ES-5.4] (l.780-793) — ACs canoniques : `ZFeatureAvailability` interface INJECTABLE (jamais classe `const` compilée), chaque app fournit ses disponibilités sans modifier `zcrud_study` (SM-SC2).
- [Source: epics.md#Story-ES-5.4-métadonnées] (l.786) — Taille S, SÉQ légère, fichier isolé `z_feature_availability.dart`, peut suivre ES-5.3.
- [Source: epics.md] (l.128) — FR-S24 `ZFeatureAvailability` injectable ← ES-5.4.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-25] (l.249-252) — `ZFeatureAvailability` INTERFACE injectable, deux apps roadmaps différentes, sans modifier `zcrud_study` ; paramétrage `null` = absente (AD-4).
- [Source: architecture.md] (l.44,46,51,54) — AD-2/AD-15 (aucun gestionnaire d'état, injection Flutter-native), AD-4 (composition/slots additifs/`null`=absent), AD-13, AD-1 (acyclicité, CORE OUT=0).
- [Source: packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart:27-54] — `ZContentHubEntry.enabled`/`onTap`/`isActionable` (cible de composition ES-5.4).
- [Source: packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:52-72,101-102] — `ZItemAction.onSelected` + filtre `where(onSelected != null)` (`null` = action absente).
- [Source: packages/zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart:71-72] — `addAction` nullable (`null` = action d'ajout absente).
- [Source: packages/zcrud_study/lib/zcrud_study.dart] — barrel (6 exports → +1).
- [Source: es-5-3-sections-reordonnables-hub-menu.md] — motif AD-4 `enabled`/`onTap:null`, SM-1, isolation workstream B, R3/R13/R14/R15 réutilisés.
- [Source: ~/DEV/iffd/lib/src/presentation/features/folders/widgets/folder_content_creating_buttons.dart:22-23,~72] — disponibilité IFFD réelle = booléens `readOnly`/`subjectToolPage` codés en dur, `onPressed: readOnly ? null : …` (aucune abstraction ; `grep isAvailable|featureFlag|comingSoon` = 0). READ-ONLY, aucun fichier IFFD modifié.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high, workstream B).

### Debug Log References

**Vérif verte CIBLÉE (RC hors pipe, R15)** :

| Gate | Commande | RC | Résultat |
|------|----------|----|----------|
| Analyse | `dart analyze` (zcrud_study) | 0 | `No issues found!` |
| Tests | `flutter test` (zcrud_study, R14) | 0 | `All tests passed!` — **51** tests (dont **13** neufs ES-5.4), non-régr. ES-5.1/5.2/5.3 |
| Acyclicité | `python3 scripts/dev/graph_proof.py` | 0 | `ACYCLIQUE OK` + `out-degree(zcrud_core) = 0 (runtime)` + `CORE OUT=0 OK` ; arête `zcrud_study → zcrud_core` INCHANGÉE |
| Packages | `dart run melos list` | — | **20** (INCHANGÉ) |
| Scans interdits | `grep -nE "flutter_riverpod\|package:get/\|package:provider/\|ConsumerWidget\|WidgetRef\|Get\.\|Provider\.of\|setState\("` sur le fichier | — | VIDE |
| Golden | — | — | INCHANGÉ (aucun `--update-goldens`, aucune apparence par défaut modifiée) |

**Injections R3 discriminantes (RED capturé RÉELLEMENT, RC=1, restaurées par édition ciblée)** :

- **R3-I1** (composition gating — CENTRAL AC1) : `gate(k, action) => action;` (ignore `isAvailable`). RED :
  - unité : `Expected: null / Actual: <Closure: () => void>` — "indisponible ⇒ gate ⇒ null (surface non actionnable/absente)".
  - menu : `Expected: no matching candidates / Actual: Found 1 widget with text "EXAM-XYZ"` — "feature indisponible : onSelected null ⇒ action ABSENTE (AD-4)".
  - hub : `Expected: <0> / Actual: <1>` — "feature indisponible : tuile désactivée (onTap null, AD-4)".
- **R3-I2** (défaut fail-open — CENTRAL AC2) : `ZAllFeaturesAvailable.isAvailable(_) => false;`. RED : `Expected: true / Actual: <false>` — "aucune injection ⇒ fail-open (D1), jamais fail-safe".
- **R3-I3** (injection scope — AC3) : `ZFeatureAvailabilityScope.of => const ZAllFeaturesAvailable();` (ignore l'ancêtre). RED : `Expected: {'note': true, 'exam': false} / Actual: {'note': true, 'exam': true} — Which: at location ['exam'] is <true> instead of <false>`.
- **R3-I4** (config honorée / SM-SC2 — AC3) : `ZMapFeatureAvailability.isAvailable(_) => true;` (ignore `flags`). RED : `Expected: not {'note': true, 'exam': true} / Actual: {'note': true, 'exam': true}`.

Toutes les injections restaurées par édition ciblée inverse ; re-vérif GREEN (analyze RC=0, `flutter test` RC=0/51, graph RC=0).

### Completion Notes List

- **Conception** : `ZFeatureAvailability` = `abstract interface class` (D2, AC4) avec `const` ctor + `isAvailable` abstrait + défauts concrets `enabledFor`/`gate`. Les deux impls de référence (`ZAllFeaturesAvailable` fail-open D1, `ZMapFeatureAvailability` piloté par `flags`) **`extends`** l'interface (intra-librairie) pour hériter des défauts de composition sans duplication (anti-inertie D3) — `implements` aurait forcé leur redéfinition. `ZFeatureAvailabilityScope` = `InheritedWidget` pur (AD-2/AD-15), `of` fail-open, `maybeOf` nullable.
- **Composition, PAS nouveau rendu (D3)** : `gate`/`enabledFor` alimentent les slots `null`/`enabled` DÉJÀ livrés en ES-5.3 (`ZContentHubEntry.onTap/enabled`, `ZItemAction.onSelected` filtrée, `ZStudyToolsSectionSpec.addAction`). Aucune modification d'un autre fichier `presentation/`, golden inchangé.
- **Import minimal** : seul `package:flutter/widgets.dart` (`InheritedWidget`/`VoidCallback`/`BuildContext`/`@immutable`). Égalité profonde de `flags` implémentée inline (`_flagsEqual`) au lieu de `mapEquals` (non surfacé par `widgets.dart`) pour respecter AC4 (import maximal) et éviter toute nouvelle arête ; `graph_proof.py` inchangé, `melos list`=20.
- **featureKey `String` opaque** (AD-4) : aucun enum fermé couplé aux satellites.
- **Isolation workstream B** : aucun fichier hors `packages/zcrud_study/**` + le fichier story ; sprint-status NON touché (orchestrateur).

### File List

- `packages/zcrud_study/lib/src/presentation/z_feature_availability.dart` (NEW)
- `packages/zcrud_study/lib/zcrud_study.dart` (MODIFIED — +1 export)
- `packages/zcrud_study/test/z_feature_availability_test.dart` (NEW)
