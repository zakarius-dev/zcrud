# Handoff **v0.27.0** — CR-IFFD-27/28/29/30/31 + CR-LEX-81

> **Tag à épingler : `v0.27.0`**
> ⚠️ Handoff adressé aux **DEUX** apps. IFFD : cinq CR livrées. lex : CR-81, plus des
> changements qui vous concernent (§ 5).

## 🔴 Impact — lisez d'abord votre ligne

| Vous êtes… | Action |
|---|---|
| **hôte passif** | **rien** — tous les défauts sont inchangés, aucune golden régénérée |
| **hôte ayant contourné CR-IFFD-29** (`tintAlpha: 0` + décor externe) | **RETIREZ la compensation** — elle s'additionne désormais à `CardTheme.color` |
| **hôte réglant `cardShadow*` « au cas où »** | ces jetons étaient **inertes**, ils sont **actifs** — et sur **deux** cartes (§ 1) |
| **lex, sur `width`** | **rien à retirer** — votre `SizedBox` est désormais le comportement documenté et garanti (§ 4) |

**Rupture d'API mineure** : `ZFolderCard.tintAlpha` passe de `double` à `double?`. Les appels de
constructeur sont inchangés ; seul un hôte qui **lit** `card.tintAlpha` dans une variable `double`
recompilera avec erreur.

---

## 1. CR-IFFD-27 — cinq jetons qui mentaient

Votre constat était exact et le défaut est le nôtre : `cardShadowBlurRadius`, `cardShadowOffset`,
`cardShadowAlpha`, `cardTintAlpha`, `iconContainerRadius` avaient **0 consommateur**. Livrés en
v0.20.0 avec la promesse qu'ils profiteraient à tout hôte, jamais câblés. Votre formule est juste :
*un jeton que personne ne lit est un jeton qui ment.*

**Voie 1 retenue — les consommer**, pas les retirer : un hôte les ayant réglés en croyant à un effet
n'aurait rien gagné à voir son code cesser de compiler.

Vous aviez raison sur `Card.elevation` : Material dérive flou et décalage de l'élévation sans
permettre de les fixer. L'ombre est donc peinte par une `BoxDecoration` sous la carte, avec
`elevation: 0` pour ne pas en superposer deux. Couleur depuis `CardThemeData.shadowColor ??
ThemeData.shadowColor` — aucun littéral.

⚠️ **Point de conception qui vous concerne** : dès qu'**un seul** des trois jetons est fourni, les
deux autres retombent sur des défauts **non neutres** (`kZCardShadowBlurRadius = 8`,
`kZCardShadowOffset = (0,2)`, `kZCardShadowAlpha = 0.12`), publics et documentés. Des replis neutres
— flou 0 — auraient rendu un `cardShadowAlpha` seul **invisible**, c'est-à-dire recréé exactement le
jeton menteur que votre CR corrige. Une garde l'assure.

⚠️ **Au-delà de votre cible** : l'ombre est câblée sur `ZFolderCard` **et `ZStudyToolsItemCard`**.
Vos exemples ne visaient que la première ; nous le signalons parce que c'est le genre d'extension
invisible depuis la lecture d'une CR (leçon CR-LEX-76).

🔵 `cardTintAlpha` n'est **pas** consommé par `ZStudyToolsItemCard` : cette carte n'a aucune couleur
d'identité (`colorKey`) à teinter — un tint y serait arbitraire. Le jeton a un consommateur réel,
l'exigence « 0 consommateur » est levée sans inventer un comportement.

---

## 2. CR-IFFD-28 — `belowSubtitle` sur `ZFolderCard`

**Même nom, même type, même position, même espacement, même traitement sémantique** que
`ZStudyToolsItemCard` et `ZStudyNoteCard`. Vous exigiez « au même contrat, pas une variante » : un
bloc migré d'une carte à l'autre n'a rien à réécrire.

🔵 **Nommé `belowSubtitle` et non `subtitle`**, alors que vous laissiez le choix. `ZFolderCard` n'a
pas de `subtitle` (son titre tient 2 lignes ellipsées) ; introduire ce nom aurait créé une
**troisième** sémantique dans la famille — l'inverse de ce que la CR demande.

⇒ Vous pouvez retirer le sous-titre du slot `counts`. Vous aviez raison sur le fond : un sous-titre
n'est pas un compteur, et le jour où `counts` recevra un traitement propre, il l'aurait subi.

---

## 3. CR-IFFD-29 — `tintAlpha: 0` donne enfin une carte NEUTRE

Priorité : `tintAlpha` (slot) → `theme.cardTintAlpha` → `kZFolderCardTintAlpha` (0.12, inchangé).
Une valeur `≤ 0` retombe sur `CardTheme.color`, sinon sur le défaut Material **opaque** — **jamais**
transparent. `> 1` est clampé, `< 0` traité comme 0 (AD-10).

Votre argument portait : c'est le même motif que CR-LEX-61 (`shape`) et CR-LEX-73 (`margin`), déjà
retenus deux fois. La résolution `CardTheme.of(context)` **existante** est réutilisée — une seule
lecture, pas une seconde.

🔵 **Pas de `Color? tint`**, que vous proposiez en alternative : introduire une prop **typée couleur**
sur une primitive qui interdit précisément les couleurs (FR-26) aurait dupliqué `CardTheme.color` —
le doublon même que CR-61/73 ont supprimé.

---

## 4. CR-IFFD-30 et CR-LEX-81 — la sidebar

**`ZSubfolderNavSpec.sidebarHeader`** (`Widget?`), rendu **uniquement déplié** : il disparaît au repli
sans que vous vous abonniez à `collapsed`. C'était le cœur de votre CR — la part qu'un hôte ne peut
pas faire proprement de l'extérieur. Placé sur la **spec** et non en paramètre du widget, parce que
`ZStudyFolderDetail` instancie la sidebar lui-même : un paramètre de widget vous serait inatteignable
depuis la façade.

**`width` n'a PAS été appliquée**, et c'est délibéré. L'appliquer ferait décider la taille au widget
(contraire à AD-2) et transformerait votre `SizedBox` en **doublon** — le motif exact de CR-LEX-76,
déjà commis une fois. Vous qualifiiez d'ailleurs la CR de « défaut de contrat documenté », pas de
comportement.

Livré : une dartdoc qui dit ce que `width` fait (poignée, annonce sémantique) et ne fait pas (aucune
borne), **avec le symptôme nommé** — des milliers de `Failed assertion: 'hasSize'` levées loin du site
fautif — pour que le prochain hôte le reconnaisse. Plus **trois gardes structurelles** qui rougissent
si le code se met à diverger de cette doc : c'est le défaut de CR-LEX-71 (doc et code désaccordés) qui
est fermé ici.

🟢 **Rien à retirer chez vous** : votre `SizedBox` est désormais le comportement documenté et garanti.
Si vous aviez un tripwire affirmant la perte, gardez-le — il ne rougira pas, et c'est le signal correct.

---

## 5. CR-IFFD-31 — le mode est livré, mais **par le `context`**

⚠️ **Écart assumé avec votre demande** : vous demandiez un 4ᵉ paramètre
`ZSubfolderItemBuilder(context, ref, selected, mode)`. La **capacité est livrée intégralement**, mais
la signature du typedef reste à **3 paramètres** :

```dart
itemBuilder: (context, ref, selected) {
  final mode = ZSubfolderLayoutMode.of(context);   // sidebar | compact
  return switch (mode) {
    ZSubfolderLayoutMode.sidebar => ListTile(title: Text(ref.label)),  // largeur bornée
    ZSubfolderLayoutMode.compact => Text(ref.label),                    // non bornée
  };
}
```

**Pourquoi pas le 4ᵉ paramètre** : il aurait forcé **tout hôte ayant fourni un `itemBuilder`** à
réécrire sa signature. Pour un socle diffusé en dépendance git, à des consommateurs qui ne régénèrent
rien, c'est un coût imposé sans contrepartie — le builder recevait **déjà** `context`, il lui manquait
une clé de lecture, pas un canal. **Votre code d'appel est donc inchangé** ; seul le corps du builder
gagne un `switch`.

Le scope du sélecteur compact est posé **au-dessus** du `ChoiceChip` — donc au-dessus du dry layout
qui fermait la voie `LayoutBuilder`. Vérifié par montage réel à 900 dp et 500 dp, pas déduit.

Repli documenté : hors surface zcrud, `maybeOf` vaut `null` et `of` replie sur **`compact`** — le seul
mode dont les contraintes sont satisfaites partout. Le repli inverse aurait transformé une absence de
scope en `BoxConstraints forces an infinite width`.

---

## 6. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **747 tests** (714 + 33).

Les cinq jetons de CR-27 ont désormais **1 consommateur chacun** (contre 0) — vérifié par le même
grep que le vôtre. Goldens `z_folder_card_neutral`, `z_folder_card_vis2_preset`, `study_tools_page`
passent **sans régénération**.

### ⚠️ Deux défauts de garde trouvés et corrigés en cours de route

Nous les signalons parce qu'ils illustrent votre propre mise en garde sur les gardes vertes.

1. La garde comportementale de `width` restait **verte** sous sa régression : le parent du test posait
   des contraintes **serrées**, qui écrasaient le `SizedBox` injecté. Refaite en contraintes lâches.
2. La lecture du mode utilisait `of()`, dont le repli est `compact` — un scope absent serait passé
   inaperçu. Les tests d'observation utilisent désormais `maybeOf` (non-null exigé).

---

## 7. Reste ouvert

Vos quatre CR suivantes (**CR-IFFD-32 à 35**) sont **lues et vérifiées sur disque**, non traitées.
CR-34 et CR-35 sont marquées **bloquantes** de votre côté ; les quatre constats sont confirmés :
`PopupMenuButton` figé, `progressionBuilder` absent (0 contre 3 pour `notebookBuilder`), app-bar sans
`subtitle` ni `gradient` (0 occurrence de chacun), `ZFlashcardListView` sans `GridView` ni
`crossAxisMaxColumns` (0 occurrence).

🔵 Votre lecture de CR-34 est la bonne et nous la reprenons : le sous-titre manque sur **trois
surfaces** d'affilée. Ce n'est plus un oubli ponctuel, c'est une lacune de couverture — elle sera
traitée comme telle.
