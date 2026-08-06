# Handoff **v0.54.1** — correctif : `v0.54.0` était ROUGE, ne l'épinglez pas

> 🔴 **N'épinglez PAS `v0.54.0`.** Deux tests y échouent. **Épinglez `v0.54.1`.**
> Aucun changement de comportement entre les deux hors le correctif ci-dessous.

## Ce qui s'est passé, dit franchement

`v0.54.0` a été taguée sur un état que **nous n'avions pas vérifié**. La séquence exacte :

1. nous mesurons `zcrud_core` à **1311 verts** et lançons les gates ;
2. un lot encore en cours écrit **après** cette mesure : un test de jeton, puis un correctif de
   `lerp` ;
3. notre `git add -A` ramasse **le test** mais le commit est figé **avant** le correctif ;
4. nous taguons et poussons — sans re-mesurer l'état réellement commité.

Résultat : le tag contient un test qui **asserte** qu'un seuil de mise en page est **discret**,
et un code qui l'**interpole encore**. Vérifié après coup, sur l'état exact du tag :

```
Failing tests: daily_tasks_tokens_test.dart
  › `lerp` — un côté absent ne matérialise pas non plus un SEUIL à 0
  › `lerp` — 🔴 le SEUIL de mois est DISCRET — il bascule, il ne glisse pas
```

**C'est notre erreur de procédure, pas un défaut de conception** : le correctif était écrit,
il n'était simplement pas dans le commit. La règle que nous nous appliquons désormais : **ne
jamais committer tant qu'un lot est en vol**, et **re-mesurer l'état commité**, pas l'état
mesuré avant.

⚠️ C'est la **deuxième fois** que ce dépôt tague un test rouge (déjà en v0.29.0). La cause est
identique : une vérification faite sur un état antérieur à celui qui est publié.

## Le correctif

`ZcrudTheme.dailyTasksMonthBreakpoint` — son `lerp` passe de **continu** à **discret**
(bascule à mi-course) :

```dart
dailyTasksMonthBreakpoint:
    t < 0.5 ? dailyTasksMonthBreakpoint : other.dailyTasksMonthBreakpoint,
```

**Pourquoi c'est le bon comportement** : un seuil interpolé traverse 630, 675, 750 pendant une
transition de thème — il ferait basculer la mise en page à une largeur **qu'aucun des deux
thèmes ne décrit**. Un point de rupture bascule, il ne glisse pas. Le dépôt avait déjà tranché
ainsi pour `folderCardFooterBesideMinWidth` (même nature d'objet) ; l'ancien
`contentHubGridBreakpoint` reste continu — précédent contradictoire, non repris.

Bénéfice mesuré en prime : le discret ne peut pas **matérialiser `0`**. Le helper générique
fait `(a ?? 0)`, donc `null → 600` à `t = 0` rendait **`0.0`** — un seuil à zéro afficherait la
vue mensuelle à **toute** largeur.

## Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + `CORE OUT = 0` + corpus de
sérialisation, 36 paquets) · `zcrud_core` **1323** · `zcrud_study` **1521** · **0 erreur, 0
avertissement**.

🔵 **Un constat utile du lot, sur la complémentarité des gardes** : quand le `lerp` a été
injecté en continu, la garde structurelle des **4 sites** est restée **verte** — elle lit la
**source**, jamais le **comportement**. Seule la garde comportementale a mordu. Les deux
familles ne sont donc pas redondantes, et c'est exactement pourquoi la garde de source seule
n'aurait pas rattrapé notre erreur de commit.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications locales — ce
qui rend l'erreur ci-dessus d'autant plus coûteuse, et la discipline d'autant plus nécessaire.

## Contenu fonctionnel

Identique à `v0.54.0` : voir `docs/handoff-v0.54.0.md` (domaine « étude » remonté dans le
socle, ordre d'affichage des champs corrigé, stepper data-driven, ports neutres). **Seul le
`lerp` du seuil change.**
