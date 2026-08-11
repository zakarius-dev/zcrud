# Handoff **v0.86.0** — le parc legacy redevient lisible, la corbeille existe, l'export s'habille

> **Tag à épingler : `v0.86.0`** — répond à `cr-generator-analyzer-constraint` (bloquante),
> `cr-firestore-legacy-park-read` (bloquante) et aux volets zcrud des Lots 2a/4/5 de
> `cr-list-screen-parity-legacy`. **Tout est opt-in, défauts inchangés**, 39 paquets.

---

## 1. `zcrud_generator` : analyzer `>=12.0.0 <14.0.0`

Votre diagnostic était exact — `^12` n'intersectait aucune version de `reflectable_builder`.
🔵 **Les deux bornes sont prouvées, pas promises** : notre workspace teste sous 12 (nos
dev-deps plafonnent analyzer <13 en local — c'est pour ça que la borne 13 ne pouvait pas se
prouver « chez nous ») ; la borne 13 a été prouvée en **bac à sable hors workspace** :
analyzer 13.0.0 + source_gen 4.2.4 + build 4.0.7, `dart analyze` 0 erreur, **127/127 tests du
générateur verts**. Chez vous : `reflectable_builder 1.2.3` + `riverpod_generator ^4` +
`zcrud_generator` co-résolvent — l'ADR-1 (codegen `@ZcrudModel`) est débloquée.

## 2. `zcrud_firestore` : `ZDeletionSemantics.absentMeansAlive`

Exactement la forme demandée, plus votre bonus :

```dart
FirebaseZRepositoryImpl<T>(
  …,
  deletionSemantics: ZDeletionSemantics.absentMeansAlive,
  legacyDeletedKey: 'deleted',   // votre clé camelCase du parc ancien (optionnel)
)
```

- **`strict` reste le défaut, inchangé et gardé** — les parcs nés zcrud ne bougent pas.
- En `absentMeansAlive` : lecture **sans clause** `is_deleted`, filtrage **client** au
  décodage (un document est écarté si `is_deleted == true` **ou** `legacyDeletedKey == true`).
  Coût documenté en dartdoc : le tri serveur reste intact, le filtrage de suppression devient
  client (`count()` compte côté client dans ce mode) — marginal tant que la corbeille l'est.
- **Convergence prouvée par test** : chaque `save` pose `is_deleted: false` — le parc migre
  naturellement vers `strict`, la bascule ultérieure se fait sans backfill.
- Votre test de spike a été **reproduit tel quel** chez nous (document legacy → invisible en
  strict, visible en compat). 🟢 **Votre tripwire va rougir** : le test
  `expect(all, isEmpty)` de `z_berth_repository_test.dart` est exactement le test à
  **inverser** quand vous passez `absentMeansAlive` — c'est prévu par votre CR, c'est le
  système qui marche.
- L'annexe est traitée : le contrat « votre `fromMap` doit accepter les dates ISO-8601 »
  est désormais en dartdoc de `FirebaseZRepositoryImpl`.

## 3. Corbeille (Lot 2a) : `ZDataRequest.deletedScope`

```dart
ZDataRequest(deletedScope: ZDeletedScope.deletedOnly)  // la vue corbeille
```

`aliveOnly` (défaut, inchangé) / `includeDeleted` / `deletedOnly` — honoré par
`getAll`/`watch`/`count` dans **les deux** sémantiques (en compat, `deletedOnly` voit aussi
les `deleted: true` legacy si `legacyDeletedKey` est fourni). Le défèrement documenté du
listing corbeille (`z_row_action.dart`) est **levé**. Limite connue : `includeDeleted` en
mode strict passe par `whereIn` (bornes Firestore usuelles).

## 4. Export (Lot 4) : `ZPdfHeaderSpec`

`ZPdfExportOptions.header` accepte une valeur neutre (logo en bytes, lignes d'organisation,
sous-titre) — parité `dodlp_pdf_header`. Défaut `null` = rendu actuel intact.
🔵 **Refus motivés** (rapports complets au dépôt) : le **nom de fichier** est déjà
paramétrable chez nous (`ZFileSaver.save(fileName:)` requis — le `DataGrid.pdf` figé est un
défaut du call-site legacy, pas un gap zcrud) ; un callback `PdfGraphics` violerait le
confinement Syncfusion gardé par test ; votre **branding reste chez vous** (injecté via
`organizationLines`/`subtitle` — FR-26).

## 5. Liste (Lot 5 + §2) : le renderer s'ouvre

`ZSfDataGridRenderer` gagne, tout opt-in, défauts identiques : **`onLoadMore`**
(infinite-scroll natif Syncfusion branché sur votre `ZListController.loadMore` — le grep
« aucun chemin n'appelle loadMore() » était exact, il est levé), `headerRowHeight`,
`columnWidthMode`, `withOrderNumber` (+ `orderColumnHeader`), `cellColorBuilder` (parité
`setCellColor`, sur les types neutres publics — zéro arête nouvelle).

## 6. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **DODLP** | dé-commentez le codegen (`reflectable_builder 1.2.3` co-résout) ; passez `absentMeansAlive` + `legacyDeletedKey: 'deleted'` sur les repos du parc ancien et **inversez votre test de limite** ; branchez la corbeille sur `deletedScope` ; `header:` sur vos exports |
| **hôte passif (IFFD/lex/DLCFTI)** | rien — tous les défauts sont inchangés et gardés |
| **hôte ayant compensé** | si vous filtriez la suppression côté app faute de `deletedScope`, retirez la compensation en migrant vers la requête |

## 7. Vérification

**R3** : 12 injections (dont la régression exacte de votre CR : clause serveur réintroduite
en `absentMeansAlive` → rouge d'assertion), restaurations par copie sha-conformes, résidus
prouvés RC=1. **Suites rejouées par l'orchestrateur** : `zcrud_core` 1751 · `zcrud_firestore`
797 (+16) · `zcrud_list` 27 (+6, dont un drag réel jusqu'à `maxScrollExtent`) ·
`zcrud_export` 41 (+8). `melos generate`/`analyze`/`verify` rejoués après le bump (§ ci-dessous).

Cette version embarque aussi la **Phase 0-2 du chantier documentation** (gardes doc-safe,
charte, 12 pages de site, README racine) — sans effet sur vos API.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.
