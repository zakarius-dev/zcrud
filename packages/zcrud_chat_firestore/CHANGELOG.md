# Changelog

Toutes les modifications notables de `zcrud_chat_firestore` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.8.0 — 2026-08-23

### Ajouté

- Paquet `zcrud_chat_firestore` : satellite Firestore du catalogue de
  routeurs IA du chat, puits du graphe (dépend de `zcrud_core`,
  `zcrud_chat_kernel`, `zcrud_firestore` ; aucune arête entrante, et aucune
  arête `zcrud_firestore → zcrud_chat*`).
- `buildChatRouterFirestoreRepository` : fabrique d'un
  `ZRepository<ZChatRouter>` sur le repository Firestore générique —
  `kind: kZChatRouterKind`, codec du noyau, point d'accroche d'un codec
  legacy (`toCanonical` en amont du décodage, `toLegacy` en aval de
  l'encodage), sémantique de suppression choisie par l'hôte
  (`ZDeletionSemantics.absentMeansAlive` pour une collection sans
  `is_deleted`), `legacyDeletedKey`, `extensionParser`, `logger`.
- `zChatRouterShapeIssue` : prédicat défensif appliqué avant le décodage —
  un document sans aucune clé du schéma, ou dont une clé du schéma porte un
  type illisible, est écarté et journalisé au lieu de devenir un routeur
  vide actif.
- `ZChatRouterMapCodec` : type des deux transformations de map d'un codec
  legacy.
- Tests : bout-en-bout sur `FakeFirebaseFirestore` (forme canonique, forme
  legacy via codec, document corrompu écarté, soft-delete/restore,
  round-trip, sémantique stricte sur une collection legacy) ; garde
  structurelle du graphe (aucune arête `zcrud_firestore → zcrud_chat*`,
  aucun code généré, imports bornés).
