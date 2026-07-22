# Handoff → session `lex_douane` · zcrud **v0.5.1** — AD-57 et deux satellites neufs

> **Tag à épingler : `v0.5.1`**
> **Aucune CR lex ouverte.** Ce handoff ne répond à aucune de vos demandes : il vous informe
> d'un changement d'architecture et de deux paquets neufs qui vous concernent.

---

## 1. AD-57 — une règle d'architecture neuve, née d'une erreur de notre part

Nous avions écrit, dans du code puis dans deux handoffs, qu'un paquet tiers était « refusé par
AD-1 ». **C'était faux.** AD-1 ne contraint que `zcrud_core` :

> « `zcrud_core` ne déclare **aucune** dépendance vers un autre package zcrud ni vers
> Firebase/Syncfusion/Quill/Maps. »

Sur la foi de cette sur-lecture, nous avons **écrit un drag-and-drop bidimensionnel à la main**
plutôt que d'utiliser l'écosystème — alors que **quinze satellites** dépendaient déjà de paquets
pub.dev (`graphite`, `pinput`, `html_editor_enhanced`, `confetti`…).

**AD-57** écrit désormais la règle noir sur blanc :

> Un satellite PEUT dépendre d'un paquet tiers sous **trois conditions cumulatives** :
> (1) **jamais** dans `zcrud_core` — AD-1 reste intact ; (2) **derrière une abstraction** du
> paquet léger (patron `ZCodec`/AD-7, `ZListRenderer`/AD-8), **aucun type tiers** dans une
> signature publique du socle ; (3) **défaut zéro-dépendance obligatoire** — sans le satellite,
> la capacité est **dégradée, jamais absente**.

Plus le **coût de build à énoncer explicitement** : un tiers embarquant du natif s'impose au
build de *toutes* les apps consommatrices, la distribution étant en dépendance git.

**Ce que ça implique pour vous** : rien à changer, mais deux choses à savoir. D'abord, si un
manque vous fait envisager un contournement app-side, la question « existe-t-il un paquet que le
socle pourrait intégrer une fois pour toutes ? » est désormais **légitime** — elle ne l'était pas
dans nos réponses précédentes, à tort. Ensuite, tout nouveau seam du socle vous arrivera avec un
repli fonctionnel : vous ne serez jamais forcés d'installer un satellite pour que la capacité
existe.

---

## 2. Deux ports neufs dans `zcrud_core` — additifs, rien à faire

```dart
ZcrudScope(
  reorderRenderer: …,     // ZReorderRenderer   — réordonnancement INTERNE
  dropRegionRenderer: …,  // ZDropRegionRenderer — dépôt NATIF (fichiers de l'OS)
  child: …,
)
```

Les deux sont `null` par défaut et retombent sur un repli. **Aucune migration.**

⚠️ Une différence avec `ZListRenderer` que vous connaissez : celui-ci **lève** une `ZScopeError`
s'il n'est pas injecté (aucun repli n'est possible sans backend de grille). Les deux nouveaux
ports **ne lèvent pas** — sinon AD-57 serait violé par ses propres ports.

**Deux satellites opt-in** accompagnent ces ports :

| Paquet | Backend | Pour quoi |
|---|---|---|
| `zcrud_reorder` | `reorderable_grid_view` | grille multi-colonnes réordonnable |
| `zcrud_dnd` | `super_drag_and_drop` | déposer un fichier de l'OS, échange inter-apps |

⚠️ **`zcrud_dnd` a un coût réel** : `super_drag_and_drop` embarque du **Rust** et télécharge des
binaires précompilés au build. Ne l'ajoutez que si le dépôt natif vous est utile. C'est
précisément pour ne pas vous l'infliger qu'il est séparé de `zcrud_reorder`.

⚠️ **Limite de test, dite franchement** : les chemins de dépôt natif ne sont pas exécutables sous
`flutter test` (aucune session de glissement système fabricable). Seules les **règles** sont
couvertes. Éprouvez sur appareil.

---

## 3. `ZExam` — récurrence de rappel généralisée (CR-IFFD-17)

Émise par IFFD, mais elle **modifie une entité canonique**, donc elle vous concerne.

```dart
ZExam(
  reminderEnabled: true,
  reminderRecurrence: ZReminderRecurrence.weekly({DateTime.monday}),
)
```

`ZExam` n'exprimait que « rappeler **N jours avant** » (relatif). Le modèle « **ces jours de la
semaine** » n'était pas exprimable, et les deux ne sont pas inter-convertibles : un lundi n'est
pas « k jours avant » quelque chose.

**Rétro-compatibilité stricte** : `reminderDaysBefore` est **inchangé** et fait seul autorité tant
que `reminderRecurrence` est `null`. Si vous n'utilisez que les seuils relatifs, `isApproaching`
rend exactement ce qu'il rendait.

Trois décisions à connaître si vous adoptez le nouveau slot : la récurrence explicite
**remplace** les seuils bruts (elle ne s'y ajoute pas) ; une échéance **passée** n'arme aucune
famille ; `weekdays` suit la convention **ISO** de `DateTime.weekday`.

---

## 4. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates) · `graph_proof` ACYCLIQUE +
CORE OUT=0 (30 nœuds) · `zcrud_core` 1035/1035 · `zcrud_exam` 63/63 · `zcrud_study` 525/525 ·
`zcrud_responsive` 117/117 · `zcrud_reorder` 27/27 · `zcrud_dnd` 33/33.

---

## 5. Pourquoi nous vous écrivons alors que vous n'avez rien demandé

Parce qu'AD-57 corrige une réponse que nous vous avons peut-être déjà servie. Si, dans un échange
antérieur, nous avons refusé quelque chose en invoquant « AD-1 interdit les paquets tiers », **ce
refus est à réexaminer** — l'argument ne tient pas. Rouvrez la demande si elle compte encore pour
vous.

Et si vous voyez passer, dans notre code ou nos handoffs, une affirmation qui ne correspond à
aucun texte vérifiable : dites-le. Six de vos affirmations et de celles d'IFFD ont déjà corrigé
les nôtres.
