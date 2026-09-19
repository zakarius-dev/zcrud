# Revue CR-102 / CR-103 — v3.55.0

Date : 2026-09-19. Base : `2b7c34e4a`. Revue BMAD : deux lentilles indépendantes (adversarial et cas limites), puis audit des critères d’acceptation. Diff lu avec fichiers nouveaux ; lockfiles étrangers exclus.

## Constats vérifiés et traitement

| Constat | Niveau | Décision | Preuve / correction attendue |
|---|---|---|---|
| Apprentissage activable dans les modes non SRS : la confirmation n’avance pas leur index visuel | HIGH | patch | Limiter l’activation aux modes learn/spaced ; tester inertie des autres modes |
| Confirmation avec correction différée : la branche masque le bouton avec le feedback | HIGH | patch | Afficher la confirmation sans dévoiler la correction ; test direct du composant |
| Ancien reviewer résolu après changement de session : moteur disposé et risque de contamination de la nouvelle session | HIGH | patch | Garde dispose moteur et identité runtime après await ; test avec Completer |
| Exception imprévue du reviewer : verrou de confirmation conservé | MEDIUM | patch | Exposer un échec et autoriser réessai, sans double écriture |
| Bouton confirmation sous thème shrinkWrap inférieur à 48 dp | MEDIUM | patch | Taille minimale explicite via thème ; test dimension |
| Politique de file figée alors que les options learning changent à chaud | MEDIUM | patch | Relayer la politique au moteur sans réinitialiser la session à chaque rebuild |
| Garde exhaustive du montage énuméré : learning absent du wiring | HIGH | patch | Ajouter learning au wiring requis, relayer exclusivement via wiring dans .wired et mettre à jour les sondes ; adaptation hôte documentée |

L’audit d’acceptation a également conduit à préciser le contrat de snapshot dans les notes de conception : le remplacement d’une closure non nulle ne constitue pas un nouvel abonnement, pour éviter la boucle de reconstruction. La réactivation après null republie l’état. Code, tests et handoff portent ce contrat.

La première hypothèse du reviewer sur un feedback différé implicite en whiteExam au niveau host était inexacte : le host ne transmet pas cette option. Le cas confirmé concerne le composant direct ; le blocage des modes non SRS est vérifié indépendamment dans la gestion de l’index.

CR-103 : aucun défaut confirmé par les deux lentilles. Le contrat documente la déduplication malgré une closure recréée et la republication après passage de null à un callback.

## Clôture

Les six constats de revue ont été corrigés et relus sur disque par le pilote. Les deux lentilles ont revalidé leurs constats sans finding restant. La suite globale a ensuite révélé le septième constat, sur le montage énuméré : sa garde est conservée, son contrat respecté et l’adaptation de compilation annoncée. Les tests couvrent les modes non SRS, le reviewer tardif, l’exception puis le réessai, la politique vivante, la correction différée et la cible tactile sous thème shrinkWrap. Un test de gestes depuis le scaffold prouve aussi q4 réinsérée puis q5 consommée, avec exactement deux écritures et une seule fin de session.

Les résultats des suites et gates de clôture sont consignés dans le handoff. Aucun statut de story du sprint n’est modifié : il s’agit de CR hors story.
