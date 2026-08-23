# Handoff v3.11.0 — CR-IFFD-90 : le transcript partagé par le Chat et le Notebook

> **Date** : 2026-08-23. **Portée** : `zcrud_chat`. **Traite** : CR-IFFD-90, émise en migrant l'onglet
> Assistant d'IFFD vers zcrud, trouvée **par lecture du socle**.

## 1. Le défaut

`ZChatNotebookController` reçoit un `ZChatTranscriptPort` : il s'abonne au fil
(`z_chat_notebook_controller.dart:310`) et persiste chaque message réglé (`:778`, `append`/`update`).
`ZChatConversationScreen` construisait un `ZChatController` **nu** sur `initialMessages` statique —
aucun transcript : une conversation du Chat vivait en mémoire et disparaissait au redémarrage.
`ZChatConversationLifecyclePort` ne comble pas le trou (archivage seulement).

Constat vérifié sur disque : `grep transcript` dans `z_chat_controller.dart` = 0 ; l'écran de
conversation n'accepte que `lifecycle`.

Le principe du propriétaire — **Chat et Notebook partagent les mêmes fonctionnalités de base** — exige
que la mécanique « flux → messages, envoi → persistance » soit écrite une fois et composée par les deux.

## 2. Ce que le socle livre
- **`ZChatTranscriptBinding`** (`zcrud_chat/lib/src/presentation/z_chat_transcript_binding.dart`) : la mécanique extraite du Notebook — abonnement unique, `attach` au premier instantané, `append`/`update` à chaque tour réglé, `Left` publiés, `dispose`. Gardée : **un seul site** dans `lib/` ; `ZChatNotebookController` la compose sans changer de surface (sa garde d'ensemble de membres reste verte).
- **`ZChatConversationController`** : `ZChatController` + transcript, paramètres à défaut inerte.
- **`ZChatConversationScreen(transcript:)`** : contrôleur de conversation créé dans `initState`, libéré dans `dispose` ; sans `transcript`, arbre identique à v3.10.0 (étalon).

### Ce que l'onglet Assistant écrit désormais (exemple minimal, 11 lignes)

```dart
ZChatConversationScreen(                       // 1
  streamPort: polarisStreamPort,               // 2
  transcript: iffdTranscriptPort,              // 3  ← le même que le Notebook
  conversationId: conversation.id,             // 4
  cursorColor: theme.colorScheme.primary,      // 5
  confirm: askUser,                            // 6
  failureBuilder: (_, f) => Text(l10n.of(f)),  // 7  tours ET écritures du fil
  liveLabels: labels,                          // 8
  key: ValueKey(conversation.id),              // 9  changer de conversation = nouvelle clé
)                                              // 10
// `initialMessages` n'est plus lu : le fil vient du dépôt. (11)
```

Trouvé en passant : le Notebook laissait remonter une **exception synchrone** du port de transcript ; la pièce partagée la publie en `Left` sur `lastFailure`.


## 3. Ce qui change pour un hôte
- **Passif** (sans `transcript`) : rien — `initialMessages` reste la source, arbre identique.
- **IFFD** : brancher le **même** `IffdTranscriptPort` que le Notebook sur l'Assistant ; les
  conversations Polaris se persistent, la liste se recharge du dépôt. Son tripwire
  `assistant_transcript_manque_test.dart` rougit et désigne le pont à retirer.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_chat` **851** (832 → +19, 26 s) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. Dix-huit injections R3 : seize rouges par assertion, une a révélé un angle mort (garde renforcée, rejouée rouge), une inerte par construction (consignée). Restauration prouvée par empreintes identiques sur les quatre fichiers ; résidus zéro.
