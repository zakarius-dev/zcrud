# Changelog

Toutes les modifications notables de `zcrud_core` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.91.0 — 2026-08-12

### Ajouté

#### `ZcrudRegistry` — résolution depuis les génériques non bornés

- Nouvelles résolutions `kindOfType(Type)` et `kindOfInstance(Object)` pour les
  moteurs génériques non bornés (`toMap<T>(T? item)`) que la borne de
  `kindOf<T>()` excluait — contrat identique (`null` si absent, `StateError`
  actionnable si ambigu) ; `kindOf<T>()` délègue à `kindOfType(T)` (source de
  vérité unique).
- Dartdoc `encode`/`encodeOf` : les clés nulles sont émises ; en écriture
  fusionnée Firestore (`merge: true`), une clé nulle **efface** la valeur
  distante — voir `omitNullFields` de `FirebaseZRepositoryImpl`.

#### `DynamicList` — parité écrans segmentés

- **Onglets** : `ZListTab` (et sa fabrique `.category`) porte un **contexte de
  création par onglet** optionnel — `Object? Function()? defaultItemBuilder` —
  pour le motif « liste segmentée par statut, la création hérite du segment
  courant ». Rappel : le filtre par onglet et le chrome à état préservé
  existaient déjà (`ZTabbedList`/`ZListTab.category`).
- **Corbeille sans repository** : fabriques `ZRowAction.softDeleteWith(handler)`
  / `ZRowAction.restoreWith(handler)` — l'écriture est déléguée à l'app
  (migration progressive, listes alimentées par des flux legacy), l'ACL reste
  appliquée exactement comme pour `softDelete(repository)`/`restore(repository)`,
  qui restent le raccourci nominal. L'entité éphémère (`id == null`) est
  transmise au handler.
- **Clé éphémère standard** : `ZListRow.ephemeralKey(index)`
  (`'__ephemeral_<index>'`) et `ZListRow.isEphemeralKey(id)` — la clé
  positionnelle des entités non persistées est fabriquée par le cœur, plus par
  chaque consommateur.
- **Grille neutre** : `ZListGridLayout` — grille de cartes **responsive** rendue
  `GridView.builder` **dans le cœur** (virtualisée, directionnelle RTL, sans
  Syncfusion ni renderer) ; sélection et actions de ligne supportées (pied de
  tuile accessible, ≥ 48 dp).
- **Doc** : `deriveColumns` documente l'escamotage silencieux des champs hors
  liste blanche tabulaire et son contournement (`ZColumnPolicy.forceInclude`).

## 0.90.0 — 2026-08-12

### Ajouté

- `ZcrudRegistry.kindOf<T>()` : le registre **retient** l'association
  `Type → kind` au moment de `register<T>(kind, …)` (elle était jetée avec
  l'effacement de `T`) et l'expose. Contrat : `kind` si l'association est
  univoque ; `null` si le type n'est pas enregistré ; `StateError` actionnable
  (nommant le type et les `kind` en jeu) si le même type est enregistré sous
  plusieurs `kind` — cet usage reste **permis** à l'enregistrement (modèle
  partagé par plusieurs collections), l'ambiguïté est signalée à la lecture.
  Un moteur générique sur `T` n'a plus à maintenir sa propre table
  `Map<Type, String>` (demande du pilote DODLP, 48 entrées manuelles).
- `ZcrudRegistry.encodeOf<T>(value)` / `ZcrudRegistry.decodeOf<T>(map)` :
  variantes typées d'`encode`/`decode` qui résolvent le `kind` depuis `T`
  via cette table. `decodeOf<T>` retourne directement un `T`. Type non
  enregistré ou ambigu → `StateError` explicite, jamais un silence ; le
  contexte de décodage est threadé comme par la voie par-`kind`.
  Aucun changement du générateur : les registrars émis appellent déjà
  `register<T>` typé.

## 0.89.0 — 2026-08-12

### Ajouté

- `ZcrudScope.copyWith(...)` : dérivation sûre d'un scope — tout seam omis
  hérite de la valeur du scope courant (les 21 seams couverts) ; pour un seam
  nullable, un `null` explicite le remet à son repli par défaut (sentinelle,
  même patron que le `copyWith` généré par `zcrud_generator`).
- `ZcrudScope.derive(context, ...)` : dérive le scope **ambiant** en ne
  remplaçant que les seams nommés — la forme recommandée pour une surcharge
  par écran (par exemple une ACL propre à la ressource affichée). Sans scope
  ambiant, la dérivation part du scope zéro-config.
- Garde de non-oubli (`z_scope_copywith_parity_test.dart`) : tout seam déclaré
  sur `ZcrudScope` doit être couvert par `copyWith` **et** `derive` — un
  nouveau seam absent de la dérivation rougit par assertion au lieu d'être
  perdu silencieusement par les scopes dérivés.

### Modifié

- `ZListRow.id` : la dartdoc explicite le contrat face à `ZEntity.id` nullable —
  une entité éphémère (`id == null`) n'a pas de clé de ligne naturelle ; le
  projecteur `T → ZListRow` fabrique une clé stable (clé positionnelle stable
  ou identité locale) jusqu'à la persistance. Aucun changement de code.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu des
  couches domaine/présentation, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_core.md` (rôle, quand l'utiliser, types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du barrel (`zcrud_core.dart`, `domain.dart`,
  `edition.dart`) et du schéma déclaratif (`lib/src/domain/edition/`) :
  première phrase autonome, invariants d'architecture cités par leur nom
  stable (`docs/site/concepts/invariants.md`). Purge des références de story
  et d'epic, des comparatifs legacy nominatifs et des emoji de journal —
  conservation des invariants, cas limites et avertissements de contrat. Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_core/`.
