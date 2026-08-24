# Handoff v3.15.0 — CR-IFFD-104/105 : la teinte jusqu'au libellé flottant et à la pastille

> **Date** : 2026-08-24. **Portée prévue** : `zcrud_core`. **Traite** : CR-IFFD-104 et 105, suites
> directes de la teinte par type de champ (v3.14.0) — les deux canaux qui manquaient pour la parité
> visuelle complète des champs.

## 1. Les défauts

**104** — la bordure de focus et l'icône se teintent, mais le **libellé flottant** est reconstruit
depuis le style de base sans jamais lire la teinte : un champ focalisé montre une bordure colorée
sous un libellé gris — l'écart saute aux yeux au moment exact où l'utilisateur regarde le champ.

**105** — l'icône d'ornement se colore, mais son **fond** (la « pastille » : carré arrondi rempli
de la teinte en alpha) est inexprimable. Le contournement par `ZFieldAdornment.widget` coûterait
trois garanties du socle : la normalisation de contraste, la gouvernance des modes `bare`/`large`,
et la résolution de clé d'icône — l'arbitrage que la règle de partage maximal demande de remonter.

## 2. Ce que le socle livre (`zcrud_core`, 2 455 → 2 463 tests)
- **104** : la couleur du libellé flottant prend la teinte résolue du type de champ, normalisée pour le contraste ; sans résolveur, étalon au pixel.
- **105** : la pastille — fond arrondi teinté sous l'icône d'ornement — par jetons (alpha clair/sombre, rayon, taille), peinte dans la vue d'ornement : la normalisation de contraste, la gouvernance `bare`/`large` et la résolution de clé d'icône sont conservées, ce que le contournement par `ZFieldAdornment.widget` aurait perdu. Aucun jeton ⇒ aucun conteneur.

## 3. Ce qui change pour un hôte
- **Passif** : rien — les deux canaux sont opt-in, aucun jeton ⇒ aucun changement au pixel, aucun
  conteneur ajouté (le précédent du contrôle d'ajout des sous-listes).
- **IFFD** : 104 — rien à écrire, son résolveur est déjà posé ; 105 — poser les jetons de pastille
  et déclarer ses `prefix:`. Ses deux tripwires (`parite_visuelle_champs_test.dart`) rougissent.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_core` **2 463** (2 455 → +8, ~63 s) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. **Neuf injections R3**, neuf rouges par assertion, empreintes identiques, résidus zéro. La garde d'inertie de v3.14.0 s'est appliquée aux jetons neufs : chacun a son consommateur.
