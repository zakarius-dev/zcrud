# Handoff **v0.85.0** — un seul cadre : le chrome porte la bordure

> **Tag à épingler : `v0.85.0`** — répond à `cr-markdown-double-border-with-chrome`.
> **Voie (a), sans interrupteur** : le bon rendu découle de la surface, comme pour `multiRow`.
> Aucun jeton nouveau, aucune arête, 39 paquets.

---

## 1. Ce qui change

Quand un `ZMarkdownFieldChrome` est actif, la zone d'édition **ne dessine plus** sa bordure ni son
padding propre — **la carte porte le cadre et le padding** (le précédent est le vôtre :
`ZMarkdownReaderChrome` côté lecture). Sans chrome : rendu **strictement inchangé**, gardé — c'est
la bordure qui matérialise le champ.

🔵 **Pourquoi (a) seul, sans l'interrupteur (b) — mesuré, pas préféré** : la carte du chrome dessine
**toujours** sa bordure (largeurs `const`, aucun paramètre pour l'éteindre). Une carte sans cadre
est **inconstructible** — donc le champ ne peut jamais se retrouver sans aucun cadre, et (b)
protégerait un cas inatteignable.

**Couverture au-delà de la lettre** : les deux voies de construction du champ (contexte de registre
et `controller`) passaient par le même empilement — corrigées et gardées toutes deux ; le mode
`block` sous chrome était déjà correct ; le plein écran vit hors du sous-arbre de la carte — cadre
unique, garde de mesure ajoutée.

## 2. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **DODLP (chrome actif)** | 🟢 rien — le double cadre disparaît. ⚠️ le padding n'est plus **doublé** sous la carte : léger resserrement visuel attendu, c'est la correction |
| **hôte sans chrome** | strictement rien |

Aucun hôte compensateur connu — votre CR le constate elle-même.

## 3. Vérification

`melos generate` **RC=0** (0 `.g.dart`) · `melos analyze` **RC=0** · `melos verify` **RC=0** —
rejoués **après** le bump.
`zcrud_markdown` **584** (+5). **0 erreur, 0 avertissement.**

**R3** : gardes chrome **nées ROUGES sur v0.84.0** par assertion (`Expected 1 / Actual 2`, sur les
deux voies) ; injection inverse (flip de condition) → 4 rouges — la garde mord **dans les deux
sens** ; restauration par copie, sha identiques, résidus par grep négatif montré.
🟢 À noter : le premier script d'injection a **refusé de s'exécuter** sur un motif ambigu
(2 occurrences du texte visé) plutôt que d'injecter au petit bonheur — c'est le comportement
attendu, consigné.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.

* Dettes antérieures : cf. `v0.84.0` (B3 vous attend toujours ; config de barre par surface = votre
  arbitrage) et les handoffs précédents.
