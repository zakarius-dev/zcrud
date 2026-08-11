# Handoff **v0.81.0** — vos données legacy deviennent lisibles : géo (G1) et embeds markdown (GAP-1/2/3/4)

> **Tag à épingler : `v0.81.0`** — premiers lots des deux CR d'exploration du 2026-08-11.
> Traités : **geo G1** (le préalable absolu) · **markdown GAP-3, GAP-4, GAP-1, GAP-2** (vos
> priorités 1 et 2). Restent : G2..G23 et GAP-5..12, par lots suivants.
> **Lecture élargie, écriture inchangée** des deux côtés — un hôte zcrud existant ne bouge pas.
> Aucun jeton nouveau, aucune arête, 38 paquets.

---

## 1. Geo — G1 : vos documents Firestore existants se lisent désormais

Mesuré sur votre `geo_shape.dart` (lecture seule) avant d'écrire quoi que ce soit :
enveloppe **String JSON**, `type` toujours émis, cercle = `points[0]` + `radius` (m),
couleurs = **int ARGB** (pas des strings), style toujours présent.

Livré, **en lecture seulement** :
* les trois `fromMapSafe` acceptent la **String JSON** (décodage défensif — un JSON invalide rend
  `null`, jamais un throw) ;
* **alias de lecture** `points`→`vertices`, `radius`→`radius_m`, `fillColor`/`strokeColor`→`*Argb`,
  `latitude`/`longitude`. La clé zcrud **prime toujours** — jamais de secours d'une clé stricte
  corrompue vers l'alias ;
* **`ZGeoValue.fromMapSafe`**, point d'entrée discriminé sur `type` (`point|circle|polygon|polyline`),
  avec détection structurelle quand `type` manque ;
* doc de migration champ à champ : `packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md`.

🔵 **Deux choses que l'alias naïf aurait ratées** :
* votre lecteur legacy accepte aussi une **List JSON nue** de points (1 ⇒ point, sinon polygone) —
  cette forme est lue aussi, sinon la parité aurait été partielle ;
* une Map legacy de type `circle` passée à `ZGeoShape.fromMapSafe` rend **`null`** — jamais une forme
  qui aurait silencieusement **perdu son rayon**. La perte silencieuse que G1 dénonce aurait sinon
  été reproduite sous une autre forme.

🟡 **Refusé, à arbitrer avec vous** : pas d'ancêtre commun créé pour les trois types de valeur
(`ZGeoValue.fromMapSafe` retourne `Object?`). Le type-somme fort de votre demande (c) est un
changement de modèle qui dépasse G1 — lot dédié si vous le confirmez.

## 2. Markdown — vos contenus à formules et tableaux s'affichent

Charges mesurées dans votre code (pas supposées) :
* `formula` / `formula_inline` portent une **String LaTeX nue** — rendu aligné sur le vôtre
  (`MathStyle.display`, non étendu) ;
* le tableau legacy est la clé **`x-embed-table`** portant un **String Markdown GFM** — d'où un
  builder dédié, avec un parseur **porté fidèlement du vôtre** (conscient de `$...$`, `{}`, `\|`).

⚠️ **Migration à SENS UNIQUE, dit clairement** : zcrud **lit** vos clés legacy, mais tout contenu
qu'il réécrit repart sur `latex`/`latexBlock`/`table`. **Ne rouvrez jamais dans l'éditeur legacy un
document réécrit par zcrud** — il tomberait sur son propre repli. C'est documenté dans le paquet.

* **GAP-3** : `placeholder` par champ, chaîne *paramètre > `field.hintText` (l10n) > rien* — aucun
  libellé français en dur dans le paquet (recherche négative montrée) : le texte vient de vous.
* **GAP-4** : `showClipboardCopy`/`showClipboardPaste`, câblés sur les boutons **natifs** de Quill —
  rien de réinventé. Défaut `true` en présets `full`/`markdown` (contrat « full = tout actif »),
  `false` en `minimal`.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | rien — sinon **2 boutons clipboard** de plus en préset `full`/`markdown`, désactivables |
| 🔴 **hôte qui PRÉ-CONVERTISSAIT** ses valeurs géo legacy avant de les donner au champ | **retirez la conversion** — elle est désormais redondante, et un tripwire est recommandé (doc) |
| 🔴 **hôte qui CONVERTISSAIT ses Delta à la main** (formules/tableaux) | **retirez la conversion** — une double migration produit le placeholder d'embed inconnu |
| **DODLP** | G1 débloquant la migration ; l'intégration de `zcrud_geo` reste conditionnée à G2/G3/G5 (lots suivants) |

## 4. Vérification

`melos generate` **RC=0**, **0** `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_geo` **201** (+27) · `zcrud_markdown` **536** (+20) · `zcrud_core` 1744 · `example` 108.
**0 erreur, 0 avertissement.**

**R3 — 11 injections au total, tous les rouges par ASSERTION**, sha avant/après chacune,
restauration par copie, résidus prouvés par greps négatifs montrés.
**Ligne de base dans les deux sens**, et surtout : les gardes d'interop consomment des échantillons
**copiés de vos writers legacy** — pas des échantillons inventés qui épouseraient notre
implémentation. Côté geo : **10 rouges d'assertion sur le code d'origine** avant correctif.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.

## 5. Restes des deux CR (non traités ici, dans l'ordre de vos priorisations)

* **Geo** : lot « paramétrage » (G2, G4, G15) → « rendu » (G3, G9, G14, G17-18) → « interaction »
  (G5, G7, G10, G11, G13) → « surface » (G6, G8, G12, G19-23) → enrichissements (§ 2 de votre CR).
* **Markdown** : GAP-5/6/7 (styles, chrome, hooks par champ) puis GAP-8..12 (finitions).
* Dettes antérieures : cf. `v0.80.0` et les handoffs précédents.
