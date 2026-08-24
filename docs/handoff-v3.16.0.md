# Handoff v3.16.0 — CR-IFFD-106/107 : l'accent de champ, et la teinte jusqu'aux tuiles

> **Date** : 2026-08-24. **Portée prévue** : `zcrud_core`, `zcrud_select`. **Traite** : CR-IFFD-106
> et 107, mesurées à l'écran en consommant v3.15.0 — les derniers maillons de la chaîne de teinte.

## 1. Les défauts

**106** — un champ ne peut pas porter d'**accent supérieur** (la fine barre en dégradé du legacy sur
les champs date, couleur, booléen). Les sections l'ont (`topAccent`) ; les champs, non. Et le socle
déclare `accentBarHeight` avec une dartdoc « hauteur **future** » — une option inerte de plus,
née dans l'angle mort de la garde d'inertie (dont le périmètre est les `Z*Config`, pas les jetons
de thème). Implémenter le canal, ou retirer le jeton — jamais le laisser mentir.

**107** — la teinte et la pastille ne suivent que `prefixIcon`/`suffixIcon` : le slot **`leading`**
et le **présentateur riche** (`ZSmartSelectPresenter`, qui appelle `resolveAdornment` sans passer
par la décoration) gardent une icône grise et nue — précisément là où le legacy met son carré
teinté, en tête de ses tuiles.

## 2. Ce que le socle livre

### `zcrud_core` (2 463 → 2 475 tests)
- **106** : accent supérieur de champ (accent par champ, repli teinte de type), **dimensionné par `accentBarHeight`** — le jeton « futur » cesse de mentir ; grammaire commune avec le `topAccent` de section.
- **107** : `leading` teinté et pastillé comme `prefixIcon` ; point d'entrée public `zResolveTintedAdornment` pour les présentateurs riches.
- **Garde d'inertie étendue aux jetons de thème** (205 jetons vérifiés, exemptions ≤ 6, contrôlées mécaniquement) — le trou qui avait laissé naître `accentBarHeight` muet est fermé.
- ⚠️ Correction du constat de la CR : `accentBarHeight` avait déjà deux consommateurs (cartes `zcrud_study`/`zcrud_flashcard`) — il n'était inerte que côté champ. Jeton partagé : voir §3.

### `zcrud_select` (148 → 153 tests)
La tête de tuile consomme `zResolveTintedAdornment` — teinte normalisée + pastille, opt-in strict, aucun signal existant écrasé. Constat croisé attrapé par le lot : la pastille du cœur (`Center`) explose dans un `leading` non borné — placement réglé côté tuile (`UnconstrainedBox`), taille intrinsèque.

## 3. Ce qui change pour un hôte
- **Passif** : rien — opt-in strict, étalons au pixel, comme les six canaux précédents.
- ⚠️ **Sauf un cas précis** : un hôte qui posait déjà `accentBarHeight` (pour ses cartes) **et** a un résolveur de teinte de type verra ses champs porter la barre d'accent — l'effet conjoint de deux déclarations existantes. IFFD est dans ce cas : c'est l'effet recherché par sa CR ; un autre hôte dans cette configuration qui ne le voudrait pas retire l'une des deux déclarations.
- **IFFD** : ses tripwires (`parite_visuelle_champs_test.dart`) rougissent ; il déclare l'accent sur
  ses champs date/couleur/booléen et laisse la tuile hériter de la pastille.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_core` **2 475** (2 463 → +12, ~65 s) ; `zcrud_select` **153** (148 → +5) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 38 verts au journal + **2 requalifiés verts à part** (`zcrud_get` 152 en 7 s, `zcrud_intl` 286 en 11 s — leurs lignes rouges sont des artefacts du déblocage), `zcrud_generator` rouge environnemental ⇒ **40 verts réels / 41**. **Onze injections R3** (6 cœur + 5 select), onze rouges par assertion. Incident d'infrastructure trouvé et traité : `/tmp` à 80 % (6 Go de restes `flutter_tools` du week-end) faisait pendre les harnais (`FileSystemException` sur un `.dill`) — nettoyé à 8 %, `zcrud_get`/`zcrud_intl` remesurés verts après coup.
