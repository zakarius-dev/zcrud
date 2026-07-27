# Handoff → session `lex_douane` · zcrud **v0.20.0** — epic VIS (alignement visuel thémable)

> **Tag à épingler : `v0.20.0`**
> **Rien à changer chez vous.** Tout est additif et **opt-in** : sans injection, le rendu est
> identique au pixel près à `v0.19.3`. Preuve : **aucun golden préexistant n'a été modifié**
> (vérifiable par `git show --stat v0.20.0 -- '*goldens*'`).

Ce lot ouvre zcrud à un **habillage visuel injectable**, motivé par un alignement vers IFFD. Vous
n'êtes pas la cible de cet habillage — mais les coutures qu'il ajoute vous sont utiles, et surtout
elles ne vous coûtent rien tant que vous ne les branchez pas.

---

## 1. Ce qui est ajouté, et pourquoi ça ne vous concerne que si vous le voulez

### 1.1 Seize tokens de « look » sur `ZcrudTheme`

`ZcrudTheme` n'avait aucun token d'apparence : ses 33 champs étaient tous orientés formulaire.
Seize s'ajoutent, **tous nullables**, `null` signifiant « garde le comportement actuel » :

| Famille | Tokens |
|---|---|
| Barre d'accent | `accentBarHeight`, `gradientBegin`, `gradientEnd` |
| Ombre / teinte de carte | `cardShadowBlurRadius`, `cardShadowOffset`, `cardShadowAlpha`, `cardTintAlpha` |
| Conteneur d'icône | `iconContainerSize`, `iconContainerRadius` |
| Pills de compteur | `countPillPadding`, `countPillRadius`, `countPillIconSize` |
| Animations | `celebrationDuration`, `celebrationCurve`, `flipDuration`, `flipCurve` |

### 1.2 Une couture de dégradé

```dart
typedef ZGradientResolver = ZGradientSpec? Function(ColorScheme scheme, String gradientKey);

ZcrudScope(
  gradientResolver: monResolveur,   // stable : const ou mémoïsé hors build
  child: …,
)
```

`ZGradientSpec` porte le `Gradient` **et** son premier plan (`onGradient`) : un dégradé seul ne
permet pas de déduire un contraste fiable, c'est donc vous qui choisissez la couleur de texte.

**Chaîne de résolution : `votre resolveur → null`.** C'est tout.

🔵 **`zDerivedGradientResolver` existe mais n'est PAS un repli automatique** — il faut le brancher
explicitement. Ce choix n'est pas cosmétique, il vient d'un défaut **mesuré** pendant le
développement : placé dans la chaîne, il rendait un dégradé **même sans aucune injection** (donc le
rendu par défaut changeait), et il **écrasait votre `null`** — vous ne pouviez plus dire « accent uni
pour cette clé ». Votre décision fait foi ; rien ne la recouvre.

### 1.3 Trois widgets ouverts

- `ZFolderCard.headerDecoration` — slot `Widget?`. Non-null il remplace la pastille ; `null` conserve
  la pastille circulaire de 14 dp. Votre rendu actuel est donc intact.
- `ZCountBadge` / `ZCountBadgeRow` / `ZCountBadgeSpec` — badges de compteurs. **Un compte à zéro est
  ABSENT de l'arbre**, pas masqué. `ZCountBadge` assertionne `count > 0`.
- `ZCelebrationSpec` — paramètres de célébration de fin de session (durée, particules, gravité,
  fréquence, icône, décor, anneaux). ⚠️ **Les défauts historiques ne bougent pas** (800 ms,
  12 particules) : les valeurs d'IFFD vivent dans notre `example/`, jamais dans le package.

---

## 2. Une règle que nous avons figée, et qui pourrait vous servir

**Une clé de dégradé est une identité STABLE — jamais un index de position.**

Ce n'est pas une préférence de style. Dans IFFD, le dégradé d'un dossier est choisi par
`themeGradients[index % length]` : **trier ou filtrer la liste change la couleur du même dossier**.
Nous avons refusé de reproduire ce comportement, et une garde le vérifie : elle journalise les clés
réellement reçues par le résolveur et rougit si l'une d'elles est un entier.

Si vous branchez la couture, passez l'identité persistée de l'entité (`folder.id`), pas sa position.
`ZColorPalette.indexOf` (hachage FNV-1a déterministe) reste le bon outil pour dériver un index
**stable** depuis une clé.

---

## 3. Deux défauts trouvés en vérifiant — signalés plutôt que tus

### 3.1 Une durée de thème pouvait valoir zéro pendant une transition

`ZcrudTheme.lerp` interpolait une durée nullable en traitant le côté absent comme `Duration.zero`.
Mesuré : avec `celebrationDuration` à `null` d'un côté et `5 s` de l'autre, `t = 0` rendait
`0:00:00.000000`.

Pourquoi c'était vicieux : Flutter interpole à **chaque** changement de thème. Un thème animé vers un
préréglage traversait donc un instant où la durée valait zéro — et `ConfettiController` **lève** sur
une durée non strictement positive. Le plantage serait survenu sur l'écran de bilan de session, au
pire moment, et de façon intermittente.

Corrigé, avec une distinction explicite : pour une **dimension**, zéro est une absence plausible (une
barre qui grandit depuis rien) ; pour une **durée**, zéro est une valeur **invalide**. Un côté `null`
signifie désormais « le consommateur applique son propre défaut », valeur que le thème ignore — on
rend donc l'autre côté, seul réellement connu.

### 3.2 Le dégradé dérivé était un aplat

`zDerivedGradientResolver` dérivait `primaryContainer → secondaryContainer` : deux rôles trop voisins
dans un `ColorScheme.fromSeed`. Écart RGB cumulé mesuré : **0,039** — invisible. Passé à
`tertiaryContainer` : **0,212**. Une garde tient désormais le seuil, réglé sur la mesure et non au
jugé.

---

## 4. Limite assumée, pour ne pas vous laisser croire à une garantie

`zResolveGradient` est **total** au sens où aucune clé n'est rejetée et où scope absent, résolveur
absent ou clé vide rendent tous `null` sans lever.

⚠️ En revanche, **une exception levée par VOTRE résolveur se propage** — elle n'est pas avalée. C'est
délibéré, et c'est déjà le comportement de `zResolveColorKey`, la couture jumelle. Étouffer
l'exception rendrait votre bug indébogable (vous verriez « pas de dégradé » sans savoir pourquoi), et
protéger un seul des deux seams ferait diverger deux API voisines. Notre dartdoc le disait mal ; il
est maintenant exact.

---

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_core` **1086** · `zcrud_study` **642** · `zcrud_flashcard` **568** · `zcrud_session` **547**.

**Aucun golden préexistant régénéré** — c'est la preuve qui compte pour la non-régression : un test
de neutralité qui passe parce qu'on a déplacé sa référence ne prouve rien.

Gardes prouvées mordantes par ré-injection de la régression exacte, dont : rendre la barre d'accent
par défaut, transmettre un index au lieu d'une identité, rendre présent un badge à zéro, retirer les
alignements directionnels, remettre l'interpolation de durée vers zéro.

---

## 6. Ce que ce lot nous a coûté, et qui peut vous éviter la même chose

Trois de nos quatre incidents de parcours n'ont **pas** produit de panne visible : ils ont produit un
**verdict faux**.

- Un gate global (`melos analyze`) joué pendant qu'un autre chantier éditait le dépôt rendait un
  rouge qui ne lui appartenait pas.
- Une injection de test dont le motif ne correspondait pas au code réel n'était **pas appliquée** —
  et le vert obtenu était présenté comme une preuve.
- `/tmp` saturé (7,4 Go de tmpfs, résidus de compilation) produisait un `Disk quota exceeded` imputé
  au code.

La leçon que nous retenons : **un code retour ne qualifie pas un résultat**. Un rouge peut venir du
compilateur, de l'infrastructure ou d'un voisin ; un vert peut venir d'une vérification qui n'a rien
vérifié. Nos outils d'injection échouent désormais **bruyamment** quand ils n'ont rien injecté,
plutôt que d'afficher un vert rassurant.

Et un rappel qui nous a coûté une reconstruction : `git checkout -- <répertoire>` ne distingue pas
une modification de test d'un travail légitime non commité.
