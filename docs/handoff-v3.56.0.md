# Handoff v3.56.0 — tour de chat, citations, notebook et export PDF

Release du 2026-09-30, tag `v3.56.0`. Origine : Lex CR-104 à CR-114, vérifiées sur le socle v3.55.0. Aucun modèle persisté existant n'est invalidé. Trois champs additifs sur `ZChatMessage` (`grounded`, `unverified`, `level`) : absents, ils restent `null`.

## Hôte passif

Un hôte qui n'appelait aucune des coutures nouvelles ne change pas de montage. Les constructeurs d'écran qui passent déjà `streamPort` (et `transcript` pour le notebook) compilent encore. `messageId` reste accepté sur une requête d'artefact. Le menu de modèle, la tuile de conversation et l'ordre des segments d'une réponse réglée changent de comportement natif, décrit plus bas : un hôte passif en bénéficie sans code à écrire.

## Hôte qui compensait

Retirer la compensation, sinon elle s'additionne au correctif.

| Compensation locale | Retrait |
|---|---|
| Réordonnancement des segments texte/bloc à la clôture du tour | Le message réglé est déjà dans l'ordre du flux. Le canal live reste, lui, la concaténation du texte. |
| `PopupMenuButton` du sélecteur de modèle parce que le menu sortait de l'écran | Le menu du socle s'ancre au-dessus du déclencheur. |
| Date non flexible et menu d'actions maison dans un tiroir étroit | Sous 360 dp les actions se replient ; la date se tronque. |
| Accordéon de réflexion posé dans le créneau d'identité | Utiliser `thinkingBuilder`, entre l'identité et le premier bloc. Lire `progress.statuses` et `progress.reasoning`. |
| Réécriture des `[n]` vers un schéma d'URL interne | Passer `onCitationTap`. L'index part de 1. `citationSource` résout la source. |
| Fil recopié parce que seul le premier instantané atteignait le contrôleur | Passer le contrôleur à l'écran, ou laisser le dépôt : au repos, l'instantané suivant remplace le fil. |
| Artefacts de dossier stockés hors du socle, un par message seulement | `scopeId` sur la requête, `generateForScope`, barre `artifactScopeId` + `transformPalette`. |
| Panneau de sources, catalogue et palette réécrits | `ZNotebookSourcesPort`, `ZNotebookArtifactKind`, `ZTransformPalette`, panneau et barre du socle. Le backend reste celui de l'hôte. |
| Export PDF local d'un message ou d'un artefact de notebook | `ZChatExportPort` sur l'écran, adapté depuis `buildMarkdownPdfBytes`. |

`retainFailed: false` ne libère le plafond de fichiers qu'après un échec d'envoi. Un succès quitte toujours `pending` pour `uploaded` : un hôte qui vidait aussi les succès dans un `finally` le garde.

## CR-104 — réflexion sans agent

`thinkingBuilder` est un créneau de tuile, distinct du créneau de réflexion du composer. La progression porte `statuses` (`phase`, `detail`) et `reasoning` (fragments ajoutés). Les kinds `status` et `reasoning` sont typés ; un événement ouvert de ces kinds est traité de la même façon.

## CR-105 — citations

`onCitationTap` sur la tuile, la vue et la requête de rendu. Sans rappel, les crochets restent un `Text`. `ZChatController.citationSource(index, message:, requestId:)` lit d'abord les sources du message.

## CR-106 — contrôleur externe et fin de tour

`controller` sur les deux écrans. Non nul, l'écran ne le possède pas. `ZChatController.adoptMessages` ne remplace le fil que s'il n'y a aucune requête en vol : `attach` reste le seul geste qui annule.

`grounded`, `unverified` et `level` sont optionnels, omis de `toMap` quand ils sont `null`, et réservés hors de `extra`.

## CR-107 — ordre des segments

Chaque `ZChatContentBlockEvent` ferme le segment de texte ouvert. Le texte encore en train d'arriver n'est pas découpé : `streamText` reste la chaîne complète.

## CR-108 et CR-109 — menu et tiroir

Le menu du sélecteur suit le déclencheur. `kZChatConversationActionsInlineMinWidth` vaut 360 : en dessous, les actions passent dans un menu à `ValueNotifier`.

## CR-110 — PDF

`ZChatExportPort` vit dans `zcrud_chat`. `buildMarkdownPdfBytes` vit dans `zcrud_export_pdf` et n'importe pas le chat. `zcrud_export` le réexporte. Les liens et les images sont réduits à leur libellé ; aucune URL n'est résolue. `latexEnabled: false` n'appelle pas le rasteriseur.

```dart
class _Pdf implements ZChatExportPort {
  Future<ZResult<Uint8List>> exportPdf({
    required String markdown,
    String? title,
  }) async {
    final bytes = await buildMarkdownPdfBytes(
      markdown,
      title: title,
      options: const ZPdfExportOptions(latexEnabled: true),
      latex: const ZFlutterMathLatexRasterizer(),
    );
    return Right(bytes);
  }
}
```

L'écran n'enregistre pas le fichier : le port le fait, ou l'hôte consomme les bytes qu'il a lui-même produits.

## CR-111 — sources, catalogue, palette

`ZNotebookSourcesPort` liste, rattache et retire. Le panneau affiche l'état d'ingestion. Le sélecteur de document reste dans `onAttach` : le socle n'ouvre aucun fichier. `ZTransformPaletteEntry.allows` filtre par niveau ; le libellé est fourni par l'hôte. `ZNotebookArtifactView` affiche un titre et un corps, sans moteur de quiz ni de carte mentale. Le regroupement temporel de l'historique n'est pas livré : la redondance n'est pas établie sur un second hôte.

## CR-112 — portée dossier

```dart
ZChatArtifactGenerationRequest(
  scopeId: folderId,
  artifactKey: ZNotebookArtifactKind.summary,
  notes: notes,
)
```

Le contenu est stocké sous `scopeId`. Un `messageId` non vide reste l'ancre, comme avant.

## CR-113 et CR-114 — pièces jointes

`retainFailed` défaut `true` conserve l'ancien comportement. `pick(source, {int? maxBytes})` est la signature du port. **Toute redéfinition doit accepter `maxBytes`.** `fileTooLarge` fait partie des refus relayés. La taille déclarée n'est pas un champ du transit : le refus a lieu dans le sélecteur, avant qu'une pièce en attente n'existe.

## Vérifications et publication

| Contrôle réellement exécuté | Résultat |
|---|---|
| `dart run melos run generate` | RC=0 ; aucun `*.g.dart` modifié |
| `dart run melos run analyze` | RC≠0 : **0 erreur**. Quatre warnings `unawaited_return_in_try_block` déjà présents hors de ce diff : export de conversation (`z_chat_export_service.dart`), lecture de brouillon (la ligne a seulement glissé), et deux retours de `zcrud_media` dont le seul changement est la version. Diagnostics informatifs préexistants dans `zcrud_study`, qui ne font pas échouer le paquet. |
| `dart run melos run verify` | RC=0 |
| `flutter test --no-pub` depuis chaque `packages/<pkg>` | 41 paquets : tous les tests passent. `zcrud_chat` 1 087, `zcrud_chat_kernel` 721, `zcrud_export_pdf` 82, `zcrud_core` 2 707, `zcrud_study` 2 435. |
| `zcrud_generator` | RC=1, 139 tests passés et 75 échecs, tous `Unsupported operation: Isolate.packageConfig` via `package:build_test`. Échec d'environnement, non imputé à ce diff. |
| `git diff --check` | RC=0 |

Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.56.0`. La recette `docs/private-git-consumption.md` épingle `v3.56.0`. Les outils `tool/binding_conformance` et `tool/reserved_keys_gate` restent en `0.0.1`, comme à la release précédente.

Les lockfiles racine et `example/` préexistants sont exclus. Publication du tag annoté `v3.56.0` et de `main` vers `https://github.com/zakarius-dev/zcrud`. Pas de publication pub.dev. Pas de modification des dépôts hôtes.
