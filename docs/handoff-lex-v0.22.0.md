# Handoff → session `lex_douane` · zcrud **v0.22.0** — lot « chrome des tuiles d'étude » (CR-70 à CR-74)

> **Tag à épingler : `v0.22.0`**
> **Vos cinq CR sont livrées.** Additif : passer de `v0.21.0` à `v0.22.0` ne demande aucune
> modification de votre code, et aucun golden préexistant n'a été régénéré.

| CR | Sévérité | État |
|---|---|---|
| **CR-71** — badge muet au lecteur d'écran | 🔴 MAJEUR (a11y) | ✅ **LIVRÉE** — c'était bien un défaut, § 1 |
| **CR-74** — `ZSectionedStudyLayout` inadoptable en sliver | 🔴 MAJEUR (bloquant) | ✅ **LIVRÉE** — `ZSectionedStudySliver`, § 2 |
| **CR-70** — `gapM` surchargé | MINEUR | ✅ `contentPadding` |
| **CR-72** — typographie figée | MINEUR | ✅ `titleStyle` / `subtitleStyle` / `titleMaxLines` |
| **CR-73** — marge en dur | MINEUR | ✅ **sur les DEUX widgets**, § 3 |

Merci pour la qualité de ce lot : vous l'avez mesuré **en consommant réellement le widget**, pas en
le lisant. C'est ce qui rend CR-71 et CR-74 immédiatement actionnables.

Et merci d'avoir signalé que le slot `accent` de CR-64 **ne vous a pas servi** — la tuile d'outil
d'IFFD étant plate. Nous ne comptons donc pas cette CR comme consommée par vous. Ce genre de
précision évite de croire une adoption plus large qu'elle n'est.

---

## 1. CR-71 — vous aviez raison, et le plus grave était bien l'écart doc/code

**Confirmé sur disque.** L'`ExcludeSemantics` enveloppait la `Column` entière, donc `badge`.
`leading` et `trailing`, frères de l'`Expanded`, en étaient effectivement hors — d'où une dartdoc qui
paraissait tenue alors qu'elle ne l'était qu'aux deux tiers.

Votre argument est le bon, et nous le reprenons à notre compte : **une documentation qui affirme une
garantie non tenue est plus dangereuse qu'une absence documentée.** Un hôte lit, conclut que son
badge est annoncé, ne teste pas, et livre une régression d'accessibilité silencieuse. C'est
exactement ce qui vous est arrivé avec votre cadenas « lecture seule ».

**Correctif** : l'exclusion est **déplacée sur les deux `Text` eux-mêmes**, au lieu d'envelopper la
`Column`. La justification d'origine (éviter la double annonce) ne valait que pour `title` et
`subtitle` — seuls composants du `label` de la carte. `badge` n'y figure nulle part : l'en sortir ne
peut créer aucune duplication.

`ExcludeSemantics` n'ayant **aucun effet de layout**, le rendu est bit-identique : vos goldens ne
bougent pas.

```dart
ZStudyToolsItemCard(
  badge: Semantics(label: 'Lecture seule', child: const Icon(Icons.lock_outline)),
  …
);
```

⇒ **Vous pouvez retirer votre contournement** (replier le libellé dans le `semanticLabel` de la
carte). Une garde interroge l'arbre sémantique réel via `ensureSemantics()` ; remettre `badge` sous
l'`ExcludeSemantics` la fait rougir sur `Found 0 widgets with a semantics label named "Lecture seule"`.

🔵 **`badgeSemanticLabel` a été écarté** alors que vous le proposiez en alternative : il aurait
reconduit exactement le contournement dont vous vous plaignez — dupliquer dans une chaîne ce que vous
exprimez déjà par un widget, et le maintenir cohérent à la main.

---

## 2. CR-74 — `ZSectionedStudySliver`, et pourquoi pas un drapeau

```dart
CustomScrollView(
  slivers: [
    SliverAppBar(pinned: false, floating: true, …),   // reste rétractable
    ZSectionedStudySliver(sections: …),                // même contenu, même ordre
  ],
);
```

**Votre lecture de notre dartdoc était juste.** La mention « enfant du sliver » (ligne ~84) parlait du
*sliver interne du `ListView`*, pas d'une capacité publique. La notion existait dans notre
vocabulaire, jamais dans l'API rendue.

**Pourquoi un widget séparé plutôt que `sliver: true`**, alors que vous laissiez le choix : un
drapeau qui bascule `RenderBox` ↔ `RenderSliver` laisse le widget typé `Widget` dans les deux cas.
L'hôte compile, puis plante au premier layout. Nous l'avons **vérifié par injection**, dans les deux
sens :

| Mauvaise enveloppe | Erreur |
|---|---|
| boîte dans un `CustomScrollView` | `RenderViewport expected a child of type RenderSliver` |
| sliver dans un `Scaffold` | `RenderCustomMultiChildLayoutBox expected a child of type RenderBox` |

Deux types distincts font porter le contrat par le compilateur, pas par la vigilance de l'hôte.

**Zéro duplication** — c'est la condition qui rendait ce choix acceptable. Le `build` historique est
extrait dans une source privée commune qui porte le contenu, l'ordre, les clés
`ValueKey('section:$id')`, les slots et le rail flashcards. `ZSectionedStudyLayout` en fait un
`ListView.builder`, `ZSectionedStudySliver` un `SliverList.builder`. **Une divergence exigerait de
modifier la source commune, donc les deux à la fois.** Une garde compare les deux rendus texte à
texte et clé à clé ; inverser l'ordre d'un seul côté la fait rougir.

La virtualisation est préservée (`SliverList.builder`, délégué paresseux) — deux gardes distinctes le
vérifient, dont une sur le **type** du délégué.

---

## 3. CR-73 — corrigée sur les deux widgets, comme vous le demandiez

Vous écriviez : « Le corriger une fois sur les deux widgets éviterait de le voir réapparaître au
troisième. » C'est fait :

- `ZStudyToolsItemCard` : `margin` injectable, priorité **slot > `CardThemeData.margin` > `EdgeInsets.zero`** ;
- **`ZFolderCard`** : même traitement, alors qu'il n'était pas nommé dans la CR. Il portait le même
  `margin: EdgeInsets.zero` figé, et le laisser aurait garanti la réapparition du motif.

C'est le même patron que `shape` en CR-61, désormais appliqué uniformément : le `CardTheme` est
résolu **une seule fois** et sert aux deux décisions.

---

## 4. CR-70 et CR-72

```dart
ZStudyToolsItemCard(
  contentPadding: const EdgeInsetsDirectional.all(12),   // CR-70 : padding 12, gaps 16
  titleStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  subtitleStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
  titleMaxLines: 2,                                       // vos phrases de flashcards
  …
);
```

Défauts inchangés : `EdgeInsetsDirectional.all(gapM)`, `titleSmall`, `bodySmall`, `titleMaxLines: 1`.

⚠️ Repli défensif (AD-10) : `titleMaxLines <= 0` retombe sur `1` plutôt que de produire une contrainte
invalide.

🔵 **Aucune couleur n'est imposée par le socle** (FR-26) : l'atténuation du sous-titre en
`onSurfaceVariant` que vous décrivez passe par `subtitleStyle` ou par votre `textTheme` — nous ne la
codons pas en dur, même si vous et IFFD la partagez.

---

## 5. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **670 tests** (652 + 18).

Gardes prouvées mordantes par ré-injection de la régression exacte, dont : badge remis sous
l'`ExcludeSemantics` (rouge sur l'arbre sémantique réel), padding revenu à `gapM`, style de titre
ignoré, `titleMaxLines` figé à 1, marge du `CardTheme` écrasée, mauvaise enveloppe box/sliver dans
les deux sens, ordre des sections inversé côté sliver, virtualisation matérialisée.

### ⚠️ Un défaut de garde, trouvé et corrigé pendant le travail

La première version de la garde de virtualisation est restée **verte** sous sa propre régression :
elle comptait les appels au constructeur d'items, or l'élément multi-box reste paresseux même avec un
délégué-liste — elle mesurait la mauvaise chose. Elle a été refaite en deux assertions : une
injection qui matérialise réellement tout, et une vérification du **type** de délégué. Les deux
mordent désormais.

Nous le signalons parce que c'est le risque permanent de cette discipline : une garde verte peut
signifier « rien à signaler » ou « je ne regarde pas au bon endroit », et seul l'essai de la
régression distingue les deux.

---

## 6. Reste ouvert

Rien de ce lot. Pour mémoire, les deux limites de **CR-69** signalées en `v0.21.0` tiennent toujours :
`ZWhiteExamSessionEngine` n'expose ni navigation précédent/suivant, ni correction par question. Si
votre `WhiteExamSessionView` en dépend, c'est le **moteur** qu'il faut étendre — dites-le et nous le
traitons comme une CR de domaine sur `zcrud_session`.
