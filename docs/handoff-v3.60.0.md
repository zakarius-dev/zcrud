# Handoff v3.60.0 — tour adopté ancré dans le fil

Release du 2026-10-02, tag `v3.60.0`. Origine : Lex CR-162. Aucun document déjà persisté n'est invalidé.

Les compensations de `docs/handoff-v3.59.0.md` et `docs/handoff-v3.58.0.md` qui n'ont pas encore été retirées le restent : cette note ne les annule pas.

## Hôte passif

Un hôte qui n'appelle pas les paramètres nouveaux compile encore. Sans ancre, le tour en vol reste rendu après le dernier message, comme avant.

La liste neutre et la coquille Syncfusion suivent le même ordre.

## Hôte qui compensait

Retirer la compensation, sinon les échanges postérieurs disparaissent encore pendant le tour.

| Compensation locale | Retrait |
|---|---|
| Fil tronqué jusqu'à la question le temps de la régénération, puis fil entier réadopté au `done` | `adoptTurn(..., afterMessageId: idDeLaQuestion)`. Adopter le fil entier pendant le flux. `insertAt` place le tour par index si l'identité n'est pas connue. `displayIndexOf` relit la position après un `adoptMessages`. |

`afterMessageId` l'emporte sur `insertAt` tant que ce message est dans le fil. S'il a disparu, `insertAt` prend le relais. Une identité inconnue sans index laisse le tour en fin de fil.

## Ancrage

```dart
controller.adoptTurn(
  events,
  requestId: 'tour-1',
  settle: false,
  afterMessageId: questionId,
  onStarted: (ZChatRequestToken token) {},
);
controller.adoptMessages(filEntier);
```

`settle: true` écrit la réponse au même endroit. Les messages qui suivaient la question restent après elle.

## Versions

Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.60.0`. La recette `docs/private-git-consumption.md` épingle `v3.60.0`. Les outils `tool/binding_conformance` et `tool/reserved_keys_gate` restent en `0.0.1`. Pas de publication pub.dev, pas de dépôt hôte, pas de site.
