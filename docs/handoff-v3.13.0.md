# Handoff v3.13.0 — CR-IFFD-92 : la parité des formulaires

> **Date** : 2026-08-24. **Portée prévue** : `zcrud_select`, `zcrud_core`. **Traite** : CR-IFFD-92
> (six volets), émise en portant le formulaire de routeur IA vers la parité visuelle avec le legacy —
> demande du propriétaire.

## 1. Les défauts

① **Le présentateur de référence ment sur la valeur orpheline.** `ZSmartSelectPresenter` supplante le
rendu natif des familles `select` et perd son invariant : une valeur persistée absente du catalogue
s'affiche « Sélectionner » — le champ paraît vide, la valeur sera soumise. L'hôte a mesuré la
régression (une garde rougit, douze suivent) et a **retiré l'injection** plutôt que de réintroduire
un mensonge déjà fermé.

② **`reorderable` accepté puis ignoré en `compact`.** Les contrôles d'ordre n'existent qu'en
`inline` ; aucun seam n'expose `onReorder`. Dans un routeur IA, l'ordre EST la donnée (principal,
puis replis) : impossible de changer le modèle qui répond sans supprimer/recréer.

③ **La section n'a ni icône, ni décoration, ni filet** — le legacy a les trois (icône de préfixe,
en-tête décoré, filet vertical continu à gauche des enfants).

④ **Les actions de ligne** : trois icônes en dur, grises, gouvernées par le seul ACL — pas de canal
de préférence d'affichage (l'ACL dit le PERMIS, pas le MONTRÉ), ni couleur ni taille.

⑤ **Le bouton d'ajout** n'est pas décorable (le seam reçoit le widget construit, pas le rappel).

⑥ **`captionBuilder`** ne reçoit ni le champ ni le compte — douze seams là où un suffirait.

## 2. Ce que le socle livre
- **①** (`zcrud_select`) : le présentateur signale la valeur orpheline comme le rendu natif — option synthétique désactivée, clé l10n `choiceUnresolved` surchargeable, tuile + modal + multi + chemin asynchrone.
- **②** : `reorderable: true` agit en `compact` ; `tags` + `true` ⇒ assertion de debug ; `onReorder` aux seams. `reorderable` devient `bool?` (`null` = historique).
- **③** : `ZEditionSection.icon` + `ZEditionSectionStyle` (fond, filet supérieur, rayon, typographie, chevrons, **filet vertical côté début**, RTL testé).
- **④** : préférences `show{View,Edit,Delete}Action` (montré = permis ET préféré, garde adversariale) + 4 jetons de thème.
- **⑤** : 5 jetons pour le contrôle d'ajout ; aucun jeton ⇒ aucun conteneur ajouté.
- **⑥** : `headerBuilder` (`ZSubListHeaderView` : champ, compte, `addControl`, `onAdd`) ; `captionBuilder` intact.

## 3. Ce qui change pour un hôte
- **Passif** : rien — tous les défauts visuels sont inchangés ; seuls des canaux s'ouvrent, plus
  l'invariant d'orphelin qui devient vrai partout.
- **IFFD** : décommente `selectPresenter:` ; retire son contournement d'ordre ; déclare icône,
  décoration et filet de section ; retire l'œil et colore crayon/corbeille ; habille son bouton
  d'ajout ; remplace ses douze seams par un seul. Ses tripwires (`formulaire_parite_socle_test.dart`)
  le rappellent un par un.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_core` **2 416** (2 389 → +27, 1 min 01) ; `zcrud_select` **148** (142 → +6) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. Douze injections R3 (8 cœur + 4 select), douze rouges par assertion — dont une garde adversariale prouvant qu'une préférence d'affichage ne rouvre pas un droit refusé, et un mutant d'orphelin d'abord inerte, renforcé puis rejoué rouge. Fausse alerte levée : le seul `.reorderable` externe est une `Key` homonyme de `zcrud_study` — la rupture `bool → bool?` ne casse personne.
