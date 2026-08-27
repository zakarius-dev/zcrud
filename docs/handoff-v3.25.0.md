# Handoff v3.25.0 — le contrat du composer, exécuté jusqu'au bout

> **Date** : 2026-08-27. **Portée** : `zcrud_chat`.
> **Achève** CR-IFFD-125, sous le mandat du propriétaire : *« prévoir et offrir toutes les
> fonctionnalités possibles d'un composer de chat avancé »*. Trois lots — gestes et contexte,
> session vocale continue, relais des créneaux — après les sept de la version précédente.

## 1. Ce que le socle livre

**Les gestes d'entrée, en ports et créneaux.** Collage, zone de dépôt, rappel du dernier message,
compteur. Le socle **reçoit et transmet** ; il ne lit pas le presse-papier et n'ouvre aucun fichier.
Contrainte tenue et vérifiée : **aucune dépendance nouvelle** — le manifeste du paquet est inchangé
à l'octet sur les dix lots du chantier.

**Les déclencheurs de contexte**, seul manque de *mécanique* du référentiel. Le socle reconnaît `@`
et `/`, demande à la source de l'hôte, rend ce qu'elle retourne et transmet la sélection. Il **ne
filtre pas, ne trie pas, ne tronque pas** — filtrer, c'est résoudre — et n'exécute aucune commande.

**La session vocale continue** : la boucle qui manquait entre deux ports déjà présents. Elle
**appelle** la dictée ponctuelle existante plutôt que de la dupliquer, et **refuse d'envoyer sans
surface de relecture montée** : une boucle vocale qui enverrait sans relecture serait un canal
d'envoi non contrôlé.

**Le porteur de créneaux pour les écrans assemblés.** Le remplacement du composer était
tout-ou-rien : styliser une seule pièce coûtait la perte de **cinq câblages** que l'écran fait pour
l'hôte — le contrôleur de réglages que l'envoi consulte, le déclencheur de la feuille projetée, le
badge et son arbitrage, le sélecteur de routeur substitué, les jetons de chrome. Le porteur permet
de remplacer une pièce et de **garder les cinq**.

## 2. Ce qui change pour un hôte

- 🔴 **Déclarer le remplacement total ET le porteur de créneaux lève en debug** — deux intentions
  contradictoires. Le remplacement total reste l'échappatoire et prime. Migrer en **un seul**
  changement.
- 🔴 **Hôte ayant câblé sa propre boucle dictée ↔ énoncé** : la **retirer** avant d'adopter le
  créneau vocal, sous peine de **deux micros ouverts**.
- **Hôte ayant compensé** par un composer complet pour styliser une pièce : retirer ce composer,
  passer le porteur, et récupérer le câblage — en retirant l'arbitrage du badge s'il l'avait
  recopié, sinon double comptage.
- Le créneau de modèle **prime** sur le sélecteur de routeur quand une session de routage est
  déclarée.
- La flèche haut ne rappelle le dernier message que dans un champ **vide**.
- **Hôte passif** : rien ne bouge, établi par des gardes d'inertie mesurées **en absolu**.

## 3. Ce que le socle a refusé, et pourquoi — la part la plus utile

- **Intercepter le raccourci de collage** : le port est asynchrone, l'interception aurait fait
  **perdre un collage de texte** pendant l'attente. Refus de mécanique, pas de principe.
- **Compter les jetons** : cela dépend du tokenizer. Sans port, la mesure est **absente** — jamais
  zéro, ni approximation par nombre de caractères, qui serait prise pour la mesure du modèle.
- **Demander une permission micro** : un port dit s'il est disponible, et c'est tout.
- **Implémenter presse-papier et glisser-déposer** : ils exigent des plugins ⇒ ports et créneaux,
  l'implémentation vit chez l'hôte.

## 4. Trois refus d'écrire du code, et un défaut trouvé par une contre-preuve

Le lot vocal a **supprimé** un mécanisme d'attente séparée que le flux n'exerçait jamais, **retiré**
une clause de sortie dont l'injection restait verte — donc subsumée — et **assumé de ne pas garder**
un repère de défense qu'aucun scénario atteignable ne distingue. Le lot des gestes avait de même
retiré une clause de condition subsumée plutôt que d'écrire une branche inatteignable.

C'est la conduite que la semaine a rendue explicite : **dire qu'une propriété n'est pas prouvable
vaut mieux que produire une preuve creuse.**

Et la **contre-preuve** d'une garde vocale a révélé un défaut réel : fermer le composer pendant une
session active levait une erreur de framework — l'arrêt notifiait un bandeau encore abonné pendant
que l'arbre était verrouillé. Corrigé par un arrêt différé.

## 5. Vérification

| Contrôle | Résultat |
|---|---|
| `zcrud_chat` | **1 033 tests verts** (851 au début du chantier, +182) |
| Durée de la suite | **18,2 s** — inchangée sur dix lots (aucun flux laissé ouvert) |
| `pubspec.yaml` | **inchangé à l'octet** — aucune dépendance ajoutée |
| `melos run generate` | 0 `.g.dart` |
| `melos run analyze` repo-wide | RC=0 |
| `melos run verify` (12 gates) | RC=0, avant **et** après le bump |
| Balayage des **41 paquets** | **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) |
| Résidus d'injection R3 | **0** |

Environ **190 injections R3** sur l'ensemble du chantier, toutes rouges **par assertion**,
restaurations **par copie exclusivement**.

## 6. Le critère d'acceptation

La demande fixait un critère mesurable : que les **1 231 lignes** du composer d'une application
consommatrice deviennent supprimables au profit d'un montage du composer du socle, **sans perte**.
Les dix lots du contrat sont exécutés.

**Nous ne déclarons pas le critère atteint** : c'est au consommateur de faire le diff et de le
mesurer. Un socle qui annonce lui-même avoir rendu du code supprimable se paie de mots. Ce que nous
pouvons dire, et qui est vérifié : chaque capacité du référentiel est soit livrée, soit **refusée
avec sa raison mesurée**, et aucune n'est en attente sans être nommée.
