# Rétrospective — Epic E11a : Lot parité DODLP (sous-ensemble geo / intl / export)

- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill` — chemin skill pris, PAS le fallback disque `.claude/skills/bmad-retrospective/SKILL.md`).
- **Date** : 2026-07-10.
- **Mode d'exécution** : agent unique non-interactif (sous-agent d'orchestration). Les phases d'analyse du skill (lecture des 3 stories + 3 code-reviews + section E11a du sprint-status) ont été jouées réellement sur disque ; le format « party mode » interactif est condensé en rétro écrite (aucun interlocuteur humain en session).
- **Périmètre** : E11a uniquement. `zcrud_markdown` (E6-3, en cours **en parallèle**) NON touché. `sprint-status.yaml` NON modifié (transition d'épopée réservée à l'orchestrateur).

---

## 1. Livré

**3 nouveaux packages satellites, tous isolés du cœur (`CORE OUT=0`), aucune modification de `zcrud_core`.**

| Story | Package | Contenu livré | Tests |
|-------|---------|---------------|-------|
| E11a-1 | `zcrud_geo` | Modèles neutres `ZGeoPoint`/`ZGeoShape` (pur-Dart, agnostiques SDK) ; `ZGeoFieldWidget` (patron AD-2) servi via `ZWidgetRegistry` ; port `ZMapAdapter` + **fabrique** `ZMapAdapterFactory` (une instance par montage) ; adaptateur concret OSM `ZOsmMapAdapter` (`flutter_map`, sans clé) confiné hors barrel | **52** |
| E11a-2 | `zcrud_intl` | Modèles neutres `ZPhoneNumber` (E.164) / `ZCountryInfo` / `ZPostalAddress` ; `ZCountryCatalog` (asset `countries.json` **245 pays**, chargement paresseux + cache + dé-dup en vol) ; 3 widgets `ZPhoneFieldWidget` / `ZCountryFieldWidget` / `ZAddressFieldWidget` ; `phone_numbers_parser` confiné à `z_phone_codec.dart` (1 seul importateur) | **59** |
| E11a-3 | `zcrud_export` | `ZExporter.toExcelBytes/toPdfBytes` → `Uint8List` (signature 100 % neutre) ; projection `ZExportTable.fromRequest` réutilisant `ZListColumn.format` du cœur (parité écran/fichier, SM-5) ; backends Syncfusion `xlsio`/`pdf` confinés à `lib/src/data/` | **19** |

**Métriques réelles vérifiées sur disque (rejouées par l'orchestrateur à chaque `done`)** :
- Tests : geo **52**, intl **59**, export **19** — tous verts (RC=0).
- `flutter/dart analyze` : **0 issue** sur les 3 packages (RC=0).
- `graph_proof.py` : **ACYCLIQUE**, **CORE OUT=0**, **14 nœuds** (RC=0) — invariant produit `melos list = 14` préservé.
- `dart pub get --dry-run` : RC=0 (gate compat E1-4 vert ; Syncfusion co-résolu 32.2.9 ; `phone_numbers_parser` 9.0.24 ; `flutter_map` 8.3.1 / `latlong2` 0.10.1).

---

## 2. Ce qui a bien marché

**(a) IMPACT `zcrud_core` = NON pour les 3 stories → parallélisation réelle à 3 workstreams sans contention du cœur.**
Les seams étaient déjà en place et vérifiés sur disque avant dev : valeurs d'enum (`location`/`geoArea`/`phoneNumber`/`country`/`address`) livrées en E3-3a ; routage `familyOf → registryOrFallback` + dispatch `ZWidgetRegistry.tryBuilderFor(field.type.name)` + repli `ZUnsupportedFieldWidget` (E3-3a/E3-3b-1) ; contrat neutre de liste (`ZListColumn`/`ZListRow`/`ZListRenderRequest`, formatage `col.format`) livré en E4. Résultat : E11a-1, E11a-2 et E11a-3 (et E6-3) opèrent sur des **fichiers strictement disjoints**, sans qu'aucune écriture de fichier cœur n'ait à être sérialisée entre workstreams.

**(b) Isolation prouvée par triple gate, pas seulement affirmée.**
Lib carte (`flutter_map`/`latlong2`), lib intl (`phone_numbers_parser`) et Syncfusion (`xlsio`/`pdf`) restent chacune au seul pubspec de leur satellite, confinées à un fichier d'implémentation, jamais réexportées par le barrel. Preuve par **gate graphe** (fermeture transitive `CORE OUT=0`) + **gate signature** (barrel sans symbole SDK, valeurs de tranche/retour neutres) + **gate secrets** (aucune clé Google/licence Syncfusion, aucun `badCertificateCallback`).

**(c) Revue adversariale efficace — a trouvé de vrais défauts, pas des nits cosmétiques.**
E11a-1 : **MAJEUR** de conception (adaptateur partagé/aliasé). E11a-2 : **MEDIUM** d'opérabilité a11y (cibles présentes mais inactivables au lecteur d'écran) + MEDIUM dé-dup catalogue. E11a-3 : GO propre (0 HIGH/MAJEUR/MEDIUM), LOW déférés. La revue a aussi validé positivement les invariants critiques (SM-1 non-proxy, défensif sur cas réels, dispose).

---

## 3. Incidents & leçons

**(a) E11a-1 — MAJEUR : instance d'adaptateur partagée (aliasing du `MapController`).**
`ZGeoFieldWidget.builder({ZMapAdapter mapAdapter})` capturait **une seule instance** réinjectée à chaque montage, alors que le contrat `ZMapAdapter` est « à usage unique par montage » et que le champ se déclare propriétaire du `dispose`. Deux champs géo dans un formulaire → même `MapController` sur deux `FlutterMap` (aliasing + double dispose) ; remontage → carte morte. Corrigé : passage à une **fabrique** `ZMapAdapterFactory = ZMapAdapter Function()`, appelée **1× en `initState`** → instance possédée, disposée en `dispose`, jamais aliasée.
> **Leçon** : pour **toute ressource disposable**, injecter une **fabrique (une instance par montage)**, jamais une instance partagée capturée par closure. Une factory qui capture une dépendance ne doit capturer que du **partageable immuable** (ex. catalogue en lecture seule), jamais un contrôleur natif.

**(b) E11a-2 — MEDIUM a11y : cibles ≥48 dp mais INOPÉRABLES.**
Le patron `Semantics(button:true) > ExcludeSemantics(child: InkWell(onTap:))` (idem items de liste et champ numéro `textField`) retirait l'action de tap/édition du sous-arbre sans la recâbler sur le nœud englobant → nœud « bouton » sans `SemanticsAction.tap`, sélecteur pays inactivable au lecteur d'écran. Les tests AC8 n'assertaient que **présence du label** + **taille**, jamais l'action → gap non couvert. Corrigé : action recâblée (`onTap` sur le `Semantics` englobant), champ numéro exposant sa sémantique éditable native, + 3 tests d'action `tap` réellement déclenchée.
> **Leçon** : AD-13 = **opérabilité**, pas seulement taille. Un test a11y doit exercer l'**action sémantique** (`SemanticsAction.tap` déclenchée), pas se contenter de `bySemanticsLabel` + `getSize`.

**(c) E11a-2 — MEDIUM : dé-duplication de charge d'un asset partagé.**
`ZCountryCatalog.load()` ne mémoïsait pas le `Future` en vol (garde `_cache != null` vraie seulement **après** résolution) → deux pickers montés dans la même frame lisaient/parsaient chacun les 245 pays, violant l'invariant « chargé une seule fois ». Corrigé : mémoïsation du `Future` en cours (`_loading`, effacé à la résolution) + test concurrent (`identical(f1,f2)`, `assetReads==1`).
> **Leçon** : pour toute **ressource asset partagée** chargée en async, dé-dupliquer la charge par le **Future en vol** (pas seulement le résultat caché), et tester le cas concurrent multi-montage.

---

## 4. Parallélisation (bilan du passage à 3 workstreams)

Le passage de « une story à la fois » à **3 workstreams concurrents** (+ E6-3 markdown) a **bien tenu, aucune collision** :
- **`create-story` n'écrit qu'un fichier story** (`stories/e11a-N-*.md`) → zéro conflit d'écriture entre workstreams.
- **`dev-story` opère sur des packages disjoints** (`zcrud_geo` / `zcrud_intl` / `zcrud_export` / `zcrud_markdown`), aucune dépendance croisée, `zcrud_core` non touché par aucun → pas de fichier cœur à sérialiser.
- **`sprint-status.yaml` sérialisé par l'orchestrateur** : les sous-agents `dev-story`/`code-review` n'y touchent jamais ; les transitions de statut sont des éditions ciblées jouées une par une par l'orchestrateur.
- **Condition de validité respectée** : la parallélisation n'était sûre **que parce que** l'analyse « Impact zcrud_core = NON » a été vérifiée sur disque **avant** de lancer les workstreams (seams pré-existants). C'est cette pré-condition, pas la parallélisation en soi, qui a évité la contention.

---

## 5. Action items

| ID | Libellé | Owner |
|----|---------|-------|
| **AI-E11a-1** | Généraliser le pattern **fabrique-par-montage** (une instance possédée par `State`, créée en `initState`, disposée en `dispose`) à tout futur widget possédant une ressource disposable — cible directe : **flashcards (E9)** et **mindmaps (E10)**. | Dev |
| **AI-E11a-2** | Adopter une **checklist a11y** systématique pour tout champ interactif : (1) **action sémantique opérable** (`SemanticsAction.tap` présente ET déclenchable, testée) + (2) cible **≥48 dp** + (3) **label** injecté. | Dev / UX |
| **AI-E11a-3** | Cadrer **E11b** (compléments v1.x) : géo complet (2ᵉ adaptateur Google / géocodage) ; intl complet (**devise**, **états/provinces**, défauts nationaux surchargeables) ; export riche (styles, pagination/ajustement largeur PDF pour tables larges — cf. LOW-1 E11a-3). | PM / Dev |
| **AI-E11a-4** | Supprimer **effectivement** le `badCertificateCallback` hérité DODLP lors de l'intégration **E7** (le reliquat vit dans l'app hôte, hors dépôt zcrud) ; le `gate:secrets` verrouille déjà la **non-réintroduction** côté package. | Dev (E7) |

---

## 6. Dette v1.x actée

- **E11b** (compléments geo / intl / export) reste **backlog** v1.x, hors MVP :
  - geo : 2ᵉ adaptateur (Google), géocodage, polygones avancés, clustering.
  - intl : devise, états/provinces, défauts nationaux surchargeables.
  - export : mise en page riche, styles, en-têtes/pieds/pagination, **ajustement largeur PDF** (LOW-1 : tables larges rognées), export flashcard PDF (E9), formats additionnels.
- **LOW consignés/déférés** (non bloquants) : durcissement des gates d'isolation en test (allowlist dynamique, strip-comment conscient des chaînes, assertions Excel sur `<t>…</t>`) — le `gate:secrets` central reste autoritatif.

---

## 7. Readiness — suite MVP

E11a complet et vert débloque le chemin critique : **E7 dépend d'E11a** (parité DODLP : champs geo/intl + export préservé E7-4). Aucune découverte d'E11a ne remet en cause le plan des epics suivants. Prochaine étape MVP : **fin d'E6** (E6-3 en cours en parallèle, puis E6-4) → **EX-3** → **E7** (intégration DODLP, où AI-E11a-4 s'exécute).

**Transition d'épopée** (réservée à l'orchestrateur, hors périmètre de cette rétro) : `epic-11a-retrospective: optional → done` et `epic-11a: in-progress → done` une fois E6/EX confirmés selon le séquencement du sprint-status.
