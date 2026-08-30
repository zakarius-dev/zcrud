# Handoff v3.38.0 — la couleur du dossier et son dégradé cessent de s'exclure

> **Date** : 2026-08-30. **Portée** : `zcrud_study`. **Traite** : CR-LEX-86 (MAJEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. Le défaut

Dans `ZDefaultFolderCard`, une couleur **déclarée** (clé passée à la carte ou réponse du
`colorKeyResolver` de l'hôte) mettait le dégradé de signature hors circuit : `declared ⇒ signature
= null`. Et comme toute la matière de la carte suivait la même source — bande, tuile d'icône,
badges, sous-titre, liseré —, l'hôte n'avait le choix qu'entre une carte **colorée mais plate** et
un dégradé **au prix de la couleur choisie par l'utilisateur**.

Ce qui a rendu la demande décisive n'est pas l'argument, c'est le fait : **deux hôtes indépendants
avaient abandonné la carte par défaut pour cette seule cause** — l'un restant sur la primitive et
rendant sa barre à part, l'autre recomposant à la main ce que la carte compose déjà.

## 2. Ce que le socle livre

Les deux décisions sont **découplées** (forme n°1 de la CR ; la forme « passe-plat `topAccent` »
a été écartée : elle aurait rendu la bande à l'hôte et lui aurait fait perdre la cohérence de
teinte que la carte garantit) :

- `accentGradient: ZGradientSpec?` — spécification directe ;
- `gradientKey: String?` — clé opaque résolue par `zResolveGradient`, donc aussi le moyen
  d'obtenir la signature **malgré** une couleur déclarée : la « forme 2 » de la CR rendue opt-in
  sans paramètre supplémentaire ni défaut modifié.

Précédence documentée : `accent` (widget verbatim) > `accentGradient` > `gradientKey` > repli de
signature (seulement sans couleur déclarée) > bande unie. Partage des rôles mesuré : **la couleur
déclarée pilote la matière** (tuile, badges, sous-titre, liseré), **le dégradé pilote la bande** ;
sans couleur déclarée, la matière suit la tête du dégradé — le rendu du repli, inchangé. Le
contraste reste mesuré par `zReadableTintOn` contre la surface réellement peinte.

Les deux gardes qui figeaient « couleur déclarée ⇒ jamais de dégradé » ont été **ré-ancrées** sur
le repli de signature et sur l'absence de demande explicite : reformulées, jamais affaiblies.

## 3. Ce qui change pour un hôte

- **Passif : rien** — arbre et couleurs figés à l'octet tant qu'aucun des deux paramètres n'est
  passé (relevé d'inertie pris **avant** modification, puis figé en littéraux).
- 🔴 **Hôte ayant contourné** — les **deux** hôtes cités par la CR : ils peuvent revenir à
  `ZDefaultFolderCard` et **retirer** leur composition manuelle. La laisser en place
  **s'additionnerait** à la bande native. C'est la classe d'impact « défaut contourné devenu
  comportement natif » : retirer d'abord, adopter ensuite.

**Limites dites** : le dégradé fourni n'est pas corrigé en contraste (l'appelant possède son
`onGradient`, comme pour le repli) ; `ZGradientSpec` n'est pas ré-exporté par le barrel de
`zcrud_study` — `gradientKey` évite d'avoir à le construire ; deux planchers WCAG tombent à
4,47/4,48 après quantification 8 bits, propriété **préexistante** de `zReadableTintOn`, hors
périmètre de ce lot.

## 4. Vérification

`zcrud_study` : **1 842 verts** (1 831 + 11), analyze 72 infos préexistantes, 0 neuve ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 11 injections,
toutes rouges **par assertion** (une tentative non compilable rejetée puis remplacée),
restaurations par copie, sha identiques, grep négatif · Balayage des 41 : **41/41 verts**.
