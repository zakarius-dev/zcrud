# Handoff v3.58.0 — tour adopté, menus, portée et boxes cloisonnées

Release du 2026-10-02, tag `v3.58.0`. Origine : Lex CR-125 à CR-131 et CR-140 à CR-143, vérifiées sur le socle v3.57.0. Aucun document déjà persisté n'est invalidé. Les champs ajoutés sont omis quand ils sont absents. Une box ouverte sans `scope` garde le nom `zcrud_<kind>`.

## Hôte passif

Un hôte qui n'appelait aucune des coutures nouvelles compile encore. Les paramètres ajoutés ont un défaut.

Trois comportements changent sans code à écrire :

- Une transformation de la barre occupe toutes les autres jusqu'à la fin de son futur (`oneAtATime` vaut `true`).
- Le temps relatif par défaut dit « il y a 1 an ». Les hôtes qui passent `timeFormatter` ne voient pas ce texte.
- Un scope de box qui n'est pas déjà en minuscules sûres (`a-z`, chiffres, `_`, `-`, `~`) change de nom. Un scope déjà sûr, y compris `uid-a` et un encodage en `~`, ne change pas. Les boxes déjà ouvertes ne sont pas renommées.

Le menu `+`, le menu d'actions et le sélecteur de modèle prennent la surface du thème, se ferment au choix, au retour et à Échap, et restent dans l'écran. L'identité du message encore en vol est `zChatStreamingMessageId(requestId)`, soit `requestId/reply`.

## Hôte qui compensait

Retirer la compensation, sinon elle s'additionne au correctif.

| Compensation locale | Retrait |
|---|---|
| Tuile live maison pour un tour ouvert hors du compositeur | `adoptTurn` consomme le flux de l'hôte. Le port du contrôleur n'est pas appelé. `emitsUserMessage: false` n'ajoute pas de question et ne vide pas la saisie. |
| Brouillon effacé parce que `send` consommait toujours le compositeur | `send(draft: …)` n'efface pas la saisie. `emitsUserMessage: false` n'ajoute pas le message utilisateur. |
| Identité du fantôme calée sur `requestId` | Lire `zChatStreamingMessageId`. Le message utilisateur optimiste garde `requestId`. |
| Sources, suggestions ou niveau recopiés après la fin du flux | Le message posé les reprend depuis la progression et les métadonnées de fin. |
| Menus `+`, d'actions ou de modèle maison | `menuBuilder`, ou la surface par défaut. Le menu se ferme tout seul. |
| Liste shell qui inversait l'ordre parce que la liste du socle ne le faisait pas | La liste par défaut mappe l'index visuel. `itemBuilder` reçoit l'ordre chronologique : une coquille qui inverse elle-même ne doit pas être inversée une seconde fois. |
| `Expanded` forcé sur le titre, date qui poussait le titre | La date est bornée à 40 % de la ligne. |
| Feuille de transformations maison, ou occupation perdue à la destruction du widget | `busyKeys` survit au widget. `oneAtATime` bloque les autres clés. `entryBuilder` reçoit `locked` et `busy`. |
| Panneau de sources maison (pages, erreur, vide, import) | Le panneau du socle. Une ingestion non reconnue vaut `unknown`, pas `ready`. |
| Génération de portée qui fabriquait un fil pour obtenir un contrôleur | `ZChatScopeGeneration`, sans transcript. `onGenerated` remplace l'écriture remplaçante du magasin. |
| Encodage de scope recopié parce que deux casses ouvraient la même box | Passer le scope tel quel à `boxNameFor` / `openBox`. Ne pas ré-encoder un scope déjà sûr. |
| Réaffectation locale des entrées « local » ou d'un autre compte | `isForeign` sur le dépôt. Le filtre par défaut, y compris le faux positif `local`, ne change pas tant que le prédicat n'est pas passé. |
| Store de compte qui ouvrait la box non cloisonnée avant l'authentification | `ZDeferredScopedLocalStore`. Déconnecté, aucune box n'est ouverte. |
| Recopie des entrées non cloisonnées vers la box du compte | `HiveZLocalStore.adoptUnscoped`. `isMine` doit rester faux tant que le propriétaire n'est pas établi. |

## CR-125 — tour adopté

```dart
controller.adoptTurn(events, emitsUserMessage: false, draft: draft);
controller.send(draft: draft, emitsUserMessage: false);
```

`adoptTurn` refuse un contrôleur libéré, une édition en cours, et un brouillon vide lorsque `emitsUserMessage` est vrai. Il ne reprend pas une requête et n'appelle pas le résolveur de route. `adoptMessages` refuse encore tant qu'une requête est en vol.

Le message posé reprend les sources et les suggestions de la progression, et `grounded`, `unverified`, `level` des métadonnées de fin.

## CR-126 — menus

`menuBuilder` est sur le déclencheur `+`, le menu d'actions de conversation et le sélecteur de modèle. Sans lui, `ZChatMenuSurface` reprend la surface et le filet du thème. Le menu se ferme au choix, sur la barrière, au retour et à Échap, et le focus est pris à l'ouverture. Le décalage le ramène dans l'écran. La cible de l'action est bornée à son contenu.

## CR-127 — liste

`scrollController` et `emptyBuilder` sont sur la vue et l'écran. L'écran transmet aussi `pickersEnabled`, `pickerGlyph`, `showThinkingToggle`, `showWebSearchToggle`, `showEffortSelector` et `onDictate`.

Seul le `ListView` par défaut traduit l'index visuel d'une liste inversée. `itemBuilder` voit l'ordre du dialogue.

## CR-128 — titre et durée

Le titre prend la largeur restante. La date est intrinsèque, plafonnée à 40 % de la ligne, avec ellipse.

`zChatPluralCategory` distingue `one` pour le français (`n == 1`) et les catégories arabes `zero`, `one`, `two`, `few`, `many`. Seule la catégorie `one` choisit la clé singulière. Un hôte qui a besoin de chaque forme passe `timeFormatter`. Le paquet n'ajoute pas `intl`.

## CR-129 — palette

`busyKeys` est un `ValueListenable<Set<String>>` détenu par l'hôte. `oneAtATime` vaut `true` : une clé occupée, locale ou distante, bloque les autres. L'occupation locale n'est écrite que si le widget est encore monté.

Une entrée verrouillée qui a un `onLocked` reste activable. Son annonce est le libellé de verrou. `ZTransformPaletteSection` regroupe les entrées. Sans `sections`, la barre reste une seule rangée.

## CR-130 — sources

La ligne annonce le nombre de pages et le libellé de `errorKey`. Une clé inconnue retombe sur la clé elle-même. L'échec du port affiche le libellé générique, ou `failureBuilder`, jamais `failure.message`. Les états vide, chargement et import en cours ont leur libellé. Le libellé d'ajout est distinct de celui des pièces jointes.

La liste est un `ListView.builder` dans un créneau borné : 40 % de l'écran lorsque le parent n'a pas de hauteur finie.

`ZNotebookIngestionState.fromJson` : `''` et `ready` restent `ready`. `pending`, `running` et `failed` sont inchangés. Toute autre chaîne, par exemple `no_text`, vaut `unknown`.

## CR-131 — portée

`ZChatScopeGeneration` ne demande pas de contrôleur de fil. Une seconde génération sur le même `scopeId` est refusée. `busy` publie les portées occupées.

`generateForScope` du contrôleur notebook a le même refus, observable sur `scopeBusy`. `onGenerated` remplace l'écriture du magasin. Sans lui, le magasin remplace encore le contenu.

`ZChatArtifactContent.structured` accompagne le texte. `isEmpty` n'est vrai que si les deux sont vides. Un contenu seulement structuré est donc écrit.

## CR-140 — nom de box

```dart
HiveZLocalStore.boxNameFor('flashcard', scope: 'uid-a');
// zcrud_flashcard__uid-a

HiveZLocalStore.boxNameFor('exam', scope: 'AbC');
// zcrud_exam__zenc + hex UTF-8, distinct de aBc
```

Un scope qui commence par `zenc` est encodé, même s'il est par ailleurs sûr : le préfixe est réservé à l'encodage. Un hôte qui passait un uid à casse mixte directement obtient une box neuve. Il ne faut pas recopier l'ancien nom à la main.

## CR-141 — propriétaire

`isForeign` remplace tout le prédicat de rattrapage. Sans lui, le filtre de la 3.57.0 reste : un `user_id`, `userId`, `owner_id` ou `ownerId` non vide et différent de l'utilisateur du dépôt, y compris la sentinelle `local`, n'est pas envoyé. Une clé absente part encore. Chaque entrée retenue est journalisée (`catch-up withheld`).

## CR-142 — scope différé

```dart
ZDeferredScopedLocalStore<T>(
  kind: kind,
  scope: accountId,
  open: (scope) => HiveZLocalStore.openBox<T>(kind: kind, scope: scope, ...),
);
```

`accountId` est un `ValueListenable<String?>`. `null` ou vide : lectures vides, écritures en `Left`, box non cloisonnée non ouverte. Un changement de scope ferme la box précédente avant d'en ouvrir une autre. Les ouvertures du même nom sont sérialisées, parce que Hive rend la main avant de retirer la box du registre. `dispose` ferme les boxes que ce store a ouvertes. Ne pas lui passer un store partagé.

## CR-143 — adoption non cloisonnée

```dart
final moved = await HiveZLocalStore.adoptUnscoped<Note>(
  kind: 'note',
  scope: accountId,
  isMine: (note) => note.ownerId == accountId,
  fromMap: Note.fromMap,
  toMap: (note) => note.toMap(),
);
```

`isMine` vrai copie l'entrée par `applyMerged` puis la purge de la box d'origine. `updated_at` n'est pas réestampillé. `isMine` faux laisse l'entrée. Un scope vide est refusé.

Ne pas rendre `isMine` vrai lorsqu'aucun propriétaire n'est établi : l'entrée serait donnée au compte courant. Ne pas ouvrir, pour y lire la preuve, une autre box que celle que l'on adopte. Ne pas y coder une purge calendaire : ce n'est pas le contrat.

## Vérifications et publication

| Contrôle réellement exécuté | Résultat |
|---|---|
| `dart run melos run generate` | RC=0 ; aucun `*.g.dart` modifié |
| `dart run melos run analyze` | RC≠0 : **0 erreur**. Quatre warnings `unawaited_return_in_try_block` déjà présents : export de conversation (`z_chat_export_service.dart:182`), lecture de brouillon (`z_chat_controller.dart:785`), et deux retours de `z_media_file_picker.dart` (lignes 70 et 78). La chaîne s'arrête sur `analyze:packages` (exit 2 de `zcrud_chat` et `zcrud_media`). |
| `dart run melos run analyze:example` | RC=0. Quatre infos déjà présentes (dépréciation `softDeleteSelected`, underscores, `prefer_const_constructors`). |
| `dart run melos run verify` | RC=0 |
| `flutter test --no-pub` depuis chaque `packages/<pkg>` | 42 paquets. 41 verts, dont `zcrud_chat` 1 099, `zcrud_chat_kernel` 725, `zcrud_export_pdf` 83, `zcrud_firestore` 843, `zcrud_core` 2 707, `zcrud_study` 2 435. |
| `zcrud_generator` | RC=1, 139 tests passés et 75 échecs, tous `Unsupported operation: Isolate.packageConfig` via `package:build_test`. Même écart qu'en v3.57.0, non imputé à ce diff. |
| `git diff --check` | RC=0 |

Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.58.0`. La recette `docs/private-git-consumption.md` épingle `v3.58.0`. Les outils `tool/binding_conformance` et `tool/reserved_keys_gate` restent en `0.0.1`.

Les lockfiles racine et `example/` préexistants sont exclus. Pas de publication pub.dev. Pas de modification des dépôts hôtes.
