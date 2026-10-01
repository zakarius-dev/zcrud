# Handoff v3.57.0 — flux segmenté, citations, PDF et cache par compte

Release du 2026-10-01, tag `v3.57.0`. Origine : Lex CR-115 à CR-124, vérifiées sur le socle v3.56.0. Aucun document déjà persisté n'est invalidé. Les champs ajoutés sont omis quand ils sont absents. Une box ouverte sans `scope` garde le nom `zcrud_<kind>`.

L'exemple PDF du handoff v3.56.0 citait un symbole `latexRasterizer` qui n'existe pas. La classe livrée est `ZFlutterMathLatexRasterizer`, dans `zcrud_export_ui`.

## Hôte passif

Un hôte qui n'appelait aucune des coutures nouvelles compile encore, à une exception près : un rappel `onCitationTap` passé à l'écran de conversation, à l'écran notebook ou à leur vue doit maintenant accepter le message. Le rappel de la tuile, lui, reste `void Function(int)`.

Le menu de modèle, le menu d'actions d'une conversation étroite, le `+` pendant un tour, et le PDF par défaut changent de comportement natif. Un hôte passif en bénéficie sans code à écrire. Helvetica, le sens gauche-à-droite et les boxes non cloisonnées restent le défaut.

## Hôte qui compensait

Retirer la compensation, sinon elle s'additionne au correctif.

| Compensation locale | Retrait |
|---|---|
| Rendu maison des segments du tour encore en vol | La tuile live les affiche dans l'ordre dès qu'un bloc structuré est arrivé. `streamText` reste la concaténation du texte. |
| Rappel de citation posé seulement sur la tuile, parce que l'écran ne recevait pas le message | L'écran et la vue reçoivent `(message, index)`. L'index part de 1. |
| Menu d'effort ou menu de modèle maison, parce que le menu sortait de l'écran | Le menu du socle est ramené dans l'écran, dans les deux sens. |
| Menu d'actions d'historique maison dans un tiroir étroit | Le menu replié est un overlay. `actionsGlyph` fournit le glyphe. Le nom de l'action reste annoncé. |
| PDF serveur conservé pour l'arabe ou le markdown | Rester sur ce port est valide. Pour le PDF du socle : passer `fontBytes` (TTF) et `rightToLeft: true`. Le rasteriseur est `ZFlutterMathLatexRasterizer`. |
| Feuille de transformations et barre occupée maison | `lockedWhen`, `onLocked`, et le futur de `onSelect` qui ignore un second geste. |
| Panneau de sources maison (cause, pages, confirmation, fichier déjà envoyé) | `errorKey`, `pageCount`, `confirmRemove`, Actualiser, `attach(fileId:)`. |
| Bouton `+` désactivé à la main pendant le tour | Le déclencheur suit `activeRequests`. `pickersEnabled: false` le force fermé. |
| Stores dossier recopiés cinq fois | `ZFolderScopedLocalStore` ou `folderIdOf` sur la fabrique. Ce filtre ne sépare pas deux comptes. |
| Filtre propriétaire seulement sur le notebook | Passer `scope` (l'identité du compte) à `openBox` pour chaque box partagée. Le rattrapage ignore en plus une entrée dont le propriétaire encodé n'est pas celui du dépôt. |

## CR-115 — segments pendant le flux

`streamBlocks(requestId)` est une `ValueListenable<List<ZContentBlock>>`. Tant que le tour ne contient que du texte, elle reste vide et la tuile continue de lire `streamText` : un rendu d'hôte branché sur ce canal n'est pas court-circuité. Dès qu'un bloc structuré ferme un segment, la liste publiée est l'ordre du flux, texte ouvert compris, et la tuile rend chaque bloc.

## CR-116 — citation et message

```dart
typedef ZChatCitationTap = void Function(ZChatMessage message, int index);
```

L'écran, la vue de conversation et la vue notebook prennent ce type. La tuile et `ZChatBlockView` restent `void Function(int)`. L'index part de 1.

## CR-117 et CR-118 — menus

Le menu de modèle est décalé pour rester dans l'écran, horizontalement et verticalement, LTR et RTL. Le libellé d'une option trop longue est tronqué.

Sous 360 dp, ouvrir les actions d'une conversation ne les ajoute plus dans la ligne : elles passent par un overlay. Sans `actionsGlyph`, le déclencheur reste le libellé Actions.

## CR-119 — PDF

`fontBytes` et `rightToLeft` sont sur `ZPdfExportOptions`, réexporté par `zcrud_export`. Le port `ZLatexRasterizer` reste dans `zcrud_export_pdf`. L'implémentation de référence est `ZFlutterMathLatexRasterizer` (`zcrud_export_ui`) : `zcrud_export_pdf` n'importe pas Flutter Math.

```dart
final bytes = await buildMarkdownPdfBytes(
  markdown,
  title: title,
  options: ZPdfExportOptions(
    fontBytes: ttf,
    rightToLeft: true,
  ),
  latex: const ZFlutterMathLatexRasterizer(),
);
```

`latexEnabled: false` n'appelle pas le rasteriseur. Aucune URL n'est résolue.

## CR-120 — palette et portée

`lockedWhen` ne retire pas l'entrée : `offeredFor` la montre, `visibleFor` non. `onLocked` reçoit le geste. Un second appui sur la même clé est ignoré jusqu'à la fin du futur.

`generateForScope` pose `allowEmptyNotes: true`. Le port est donc appelé même si le fil est vide. Un artefact `subjectRequired` avec un sujet vide est toujours refusé, y compris par cette voie. Une génération ancrée sur un message refuse encore des notes vides, sauf `allowEmptyNotes` explicite.

## CR-121 — sources

`errorKey` et `pageCount` sont lus et écrits (`error_key`, `page_count`), omis quand ils sont `null`. `confirmRemove` qui renvoie `false`, ou qui lève, annule le retrait. `null` retire tout de suite, comme avant. Actualiser relit le port.

```dart
Future<ZResult<ZNotebookSource>> attach({
  required String title,
  String? fileId,
});
```

## CR-122 — menu `+`

`enabled: false` sur le déclencheur annonce l'état désactivé et n'ouvre pas le menu. Le composer par défaut le combine avec l'absence de requête en vol.

## CR-123 — cache et compte

```dart
HiveZLocalStore.boxNameFor('notebook', scope: uid);
```

Sans scope, le nom reste `zcrud_notebook`. Les boxes déjà ouvertes ne sont pas renommées : l'hôte choisit le scope à l'ouverture suivante.

Le rattrapage lit `user_id`, `userId`, `owner_id` et `ownerId` sur l'encodage. Une valeur texte non vide et différente de l'utilisateur du dépôt n'est pas envoyée. Une entité sans ces clés part encore.

## CR-124 — dossier

`ZFolderScopedLocalStore` filtre lectures, écritures utilisateur et `clear`. `applyMerged` reste délégué : c'est la voie du merge. `dispose` ne ferme pas le store partagé.

```dart
buildFolderScopedStudyRepository<T>(
  // ...
  folderId: folderId,
  folderIdOf: (item) => item.folderId,
);
```

Sans `folderIdOf`, le store local est celui qu'on a passé, comme avant. Filtrer par dossier ne retient pas les entrées d'un autre compte : les deux mesures sont distinctes.

## Vérifications et publication

| Contrôle réellement exécuté | Résultat |
|---|---|
| `dart run melos run generate` | RC=0 ; aucun `*.g.dart` modifié |
| `dart run melos run analyze` | RC≠0 : **0 erreur**. Quatre warnings `unawaited_return_in_try_block` déjà présents : export de conversation (`z_chat_export_service.dart:182`), lecture de brouillon (`z_chat_controller.dart:778`), et deux retours de `z_media_file_picker.dart` (lignes 70 et 78). |
| `dart run melos run verify` | RC=0 |
| `flutter test --no-pub` depuis chaque `packages/<pkg>` | 42 paquets. 41 verts, dont `zcrud_chat` 1 091, `zcrud_chat_kernel` 723, `zcrud_export_pdf` 83, `zcrud_firestore` 839, `zcrud_core` 2 707, `zcrud_study` 2 435. |
| `zcrud_generator` | RC=1, 139 tests passés et 75 échecs, tous `Unsupported operation: Isolate.packageConfig` via `package:build_test`. Même écart qu'en v3.56.0, non imputé à ce diff. |
| `git diff --check` | RC=0 |

Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.57.0`. La recette `docs/private-git-consumption.md` épingle `v3.57.0`. Les outils `tool/binding_conformance` et `tool/reserved_keys_gate` restent en `0.0.1`.

Les lockfiles racine et `example/` préexistants sont exclus. Pas de publication pub.dev. Pas de modification des dépôts hôtes.
