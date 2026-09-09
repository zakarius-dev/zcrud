# Handoff v3.53.0 — un palier tapé dans l'assemblage note enfin le moteur

> ⚠️ **En cours de rédaction**, complété lot par lot. Rien n'est publié tant que la vérif
> verte n'a pas été rejouée au repos.

Origine : quatre demandes déposées par une application hôte après avoir porté sa session de
révision sur `ZStudySessionHost.wired` en visant la parité avec la référence. Toutes
mesurées, l'une **bloquante** — et elle désigne un trou dans une garantie que le handoff
v3.51.0 affirmait.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Constats vérifiés sur disque avant tout travail

| # | Constat de l'hôte | Vérification | Verdict |
|---|---|---|---|
| 98 🔴 | Avec `gradingVisibility: always`, un palier tapé **notifie** l'hôte mais **ne note pas** le moteur ; la carte reste figée, saisie verrouillée | le host relaie `onQualitySelected` **nu** (`z_study_session_host.dart:616`) ; `_gradeAndAdvance` n'est atteint que par la soumission (`:1613`) | réel — **bloquant** |
| 98 bis | Une carte réinsérée au lapse **seule** garde la saisie précédente : la clé `zStudySessionAnswer_<id>` ne porte pas de numéro de présentation | à mesurer par le lot | à mesurer |
| 96 | `onSource` de la carte n'est relayé ni par le wiring ni par le slot | `grep onSource` host/view/slot ⇒ 0 | réel |
| 97 | `allowSkipEvaluation` et `revealStoredHint` ne sont pas relayés ; une saisie vide part au port d'évaluation | `grep` host ⇒ 0 ; validateur `answerRequired` présent dans la saisie (`:1339`) | réel, soumission vide à mesurer |
| 95 | `qualityPreviewLabelFor` ne reçoit pas la carte : un aperçu SM-2 par carte est inatteignable | `String Function(int quality)` sur host et saisie | réel |

Sur le point 98, la garde de v3.51.0 comptait les **notifications** de la surface de saisie,
pas les **écritures** du host. Elle était verte, mordante — et regardait à côté. L'hôte a
raison sur les mots : « le compteur mesuré est celui du rappel, pas celui de l'écriture ».
