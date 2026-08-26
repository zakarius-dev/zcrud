# Réfutation — M6 : « `ZContentHubSheet` remplace les 4 raccourcis maison, et `gate` fait DISPARAÎTRE les 3 affordances inertes »

> ⚠️ Nom de fichier RACCOURCI : le nom demandé fait **379 octets** et contient des `/`
> (« 59 fichiers **/** 22 778 lignes », « lib**/**workflow ») — au-delà de la limite de 255 octets
> d'ext4, et le `/` est un séparateur de chemin. Le domaine complet est repris ci-dessous.

**Domaine** : Tâches et découverte (IFFD) — 59 fichiers / 22 778 lignes : tâches quotidiennes
(lecture, agrégat révisions+examens), espace de travail lib/workflow (listes de tâches, tâches,
agenda, événements, récurrence), et Découverte (recherche + fil IA en flux + TTS/podcast +
réglages de génération + corpus documentaire)
**Besoin hôte M6** : `ZContentHubSheet` remplace les 4 raccourcis maison, et `gate` fait
**DISPARAÎTRE** les 3 affordances inertes au lieu de les **griser** (AD-4)
**Gain annoncé** : ~202 lignes d'hôte supprimées
**Date** : 2026-08-26 — dépôts hôtes lus en LECTURE SEULE

## VERDICT : **AFFIRMATION DÉMENTIE**

Le canal existe, il est exporté, il est atteignable, et le défaut hôte est exactement celui décrit.
Mais **le mécanisme invoqué ne produit pas l'effet exigé par M6** : `ZFeatureAvailability.gate`
appliqué à `ZContentHubEntry.onTap` ne fait **pas disparaître** l'entrée — il la laisse **rendue,
au complet, à pleine opacité**, seulement non tapable. M6 demande la disparition ; le socle livre
la présence inerte. Et il ne grise même pas : la migration serait une **régression** contre l'état
actuel de l'hôte, qui grise à `Opacity(0.5)`.

---

## 1. Ce qui RÉSISTE (vérifié, à ne pas rejouer)

| Affirmation | Vérification | Statut |
|---|---|---|
| `z_content_hub_sheet.dart:188` = `class ZContentHubSheet extends StatelessWidget` | `grep -n "class ZContentHubSheet"` → `188:class ZContentHubSheet extends StatelessWidget {` | ✅ exact |
| dartdoc `:168` « Testable en isolation (widget nu) ou présentée en modale via [show] » | `grep -n "Testable en isolation"` → `168:` | ✅ exact |
| dartdoc `:181` `onTap: fa.gate('flashcards.ai', _generate)` | `grep -n "fa.gate"` → `181:` | ✅ exact **mais c'est un COMMENTAIRE** (cf. §5) |
| `z_feature_availability.dart:41` interface, `:63` `gate`, `:94` `ZMapFeatureAvailability`, `:149` `Scope` | fichier lu en entier (173 l.) | ✅ exact |
| Exporté par le barrel | `lib/zcrud_study.dart:66` (`z_content_hub_sheet.dart`) et `:93` (`z_feature_availability.dart`) sur 74 exports | ✅ atteignable |
| `zcrud_study` est une dépendance déclarée d'IFFD | `/home/zakarius/DEV/iffd/pubspec.yaml:391` (dépendance git) + `:654` (override) | ✅ atteignable |
| Défaut hôte : 4 raccourcis dont 3 inertes | `daily_tasks_page.dart:916-918`, `:925-927`, `:933-935` — `isLocked/enabled: false, onTap: () {}` | ✅ exact |
| Volume supprimable | `_QuickActionsWidget` :900-983 = **84 l.** ; `_QuickActionCard` :985-1101 = **117 l.** ; total **201** (l'affirmation dit « ≈202 ») | ✅ à 1 ligne près |
| Suppression auto-contenue | `grep -rn "_QuickActionCard\|_QuickActionsWidget" iffd/lib/` → 9 hits, **tous** dans `daily_tasks_page.dart` | ✅ |

Dérives de citation mineures (non bloquantes) : « gridBreakpoint/gridCrossAxisCount :203-204 » →
réellement `:208-209` (constructeur) et `:270`/`:274` (champs) ; « densité :229 » → `:197`
(constructeur) et `:230` (champ).

---

## 2. RÉFUTATION DÉCISIVE — `gate` ne fait rien disparaître

### 2.1 Le corps du rendu, lu

`_ZContentHubTile.build` (`z_content_hub_sheet.dart:640-695`) :

```
642|    final bool actionable = entry.isActionable;
...
671|      child: Semantics(
672|        button: true,
673|        enabled: actionable,
674|        label: entry.label,
...
678|          child: InkWell(
679|            onTap: actionable ? entry.onTap : null,
```

**GREP NÉGATIF MONTRÉ** — toutes les occurrences de `actionable` dans les 903 lignes du fichier :

```
$ grep -n "actionable" packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart
642:    final bool actionable = entry.isActionable;
673:        enabled: actionable,
679:            onTap: actionable ? entry.onTap : null,
```

**3 sites, aucun autre.** `actionable` ne pilote ni une absence de l'arbre, ni une atténuation.

**GREP NÉGATIF MONTRÉ** — aucune atténuation visuelle :

```
$ grep -n "Opacity\|opacity\|disabledColor\|actionable ?" z_content_hub_sheet.dart
679:            onTap: actionable ? entry.onTap : null,
```

Un seul hit, et c'est le `onTap`. **Aucun `Opacity`, aucun `disabledColor`, aucune branche de
couleur sur `actionable`** dans `_buildCard` (:698-733), `_buildCompact` (:738-765),
`_buildLabelBlock` (:771-804), `_buildAvatar` (:808-837), `_buildChevron` (:842-855),
`_buildBadge` (:859-902). Une entrée gatée est peinte **à l'identique d'une entrée active**.

### 2.2 Aucun filtrage — l'entrée reste dans la liste

```
340|  List<ZContentHubSection> _groups() => <ZContentHubSection>[
341|    if (entries.isNotEmpty) ZContentHubSection(entries: entries),
342|    for (final ZContentHubSection section in sections)
343|      if (section.entries.isNotEmpty) section,
344|  ];
```

`_groups()` n'écarte que les sections **vides** — jamais une entrée non actionnable. Et les deux
builders comptent **toutes** les entrées :

```
456|                          itemCount: group.entries.length,     (SliverList.builder)
486|                          itemCount: group.entries.length,     (SliverGrid.builder)
```

**GREP NÉGATIF MONTRÉ** — aucun filtre d'entrées :

```
$ grep -n "\.where(\|whereType\|removeWhere\|if (entry" z_content_hub_sheet.dart
590:    if (entry.tint != null) return entry.tint;
```

Unique hit : la résolution de teinte. **Aucun `.where(`, aucun `removeWhere`, aucun `whereType`
sur `entries`** dans les 903 lignes.

**GREP NÉGATIF MONTRÉ** — `ZContentHubLauncher` ne filtre pas davantage :

```
$ grep -n "class \|isActionable\|where(\|entries\|ZFeatureAvailability" z_content_hub_launcher.dart
100:///       entries: <ZContentHubEntry>[
113:class ZContentHubLauncher {
117:    this.entries = const <ZContentHubEntry>[],
139:  final List<ZContentHubEntry> entries;
200:    entries: entries,
233:          listEquals(entries, other.entries) &&
255:    Object.hashAll(entries),
287:class ZContentHubScope extends InheritedWidget {
```

Zéro `isActionable`, zéro `where(` sur les 325 lignes du lanceur.

### 2.3 Une GARDE VERTE DU SOCLE prouve la présence

`packages/zcrud_study/test/z_content_hub_sheet_test.dart` :

* ligne 40 : `await tester.tap(find.text(kDisabledLabel));` — on ne tape que ce qui est **rendu** ;
* lignes 89-99 : `semanticsFor(kDisabledLabel).properties.enabled` → `isFalse`, avec
  `firstWhere((s) => s.properties.label == label)` : le nœud `Semantics` de l'entrée désactivée
  **existe dans l'arbre**, sinon `firstWhere` lèverait.

⇒ M6 n'est pas seulement **non couvert** : il est **contredit par une garde verte du socle**.
Livrer la disparition demanderait de **casser** ce test — c'est un changement de socle, pas une
migration.

---

## 3. RÉGRESSION — le socle est en retrait de l'état actuel de l'hôte

`daily_tasks_page.dart:1007-1013` :

```
1007|    return GestureDetector(
1008|      onTap: enabled ? onTap : null,
1009|      child: MouseRegion(
1010|        cursor:
1011|            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
1012|        child: Opacity(
1013|          opacity: enabled ? 1.0 : 0.5,
```

L'hôte grise **aujourd'hui** (opacité 0.5) et change le curseur. Le socle ne fait ni l'un ni
l'autre (§2.1). Migrer tel quel rendrait les **3 affordances inertes visuellement identiques aux
actives**, tapables sans effet — l'exact « no-op silencieux » que l'AD-4 proscrit, et que
l'affirmation prétend éliminer.

---

## 4. La dartdoc citée dit LE CONTRAIRE de ce qu'on lui fait dire

`z_feature_availability.dart:50-53` — le point de composition destiné au hub :

```
50|  /// Point de composition ⇒ [ZContentHubEntry.enabled].
51|  ///
52|  /// Relaie [isAvailable] : une entrée du hub dont la feature est indisponible
53|  /// est rendue DÉSACTIVÉE (tuile non actionnable, AD-4), sans nouveau rendu.
```

**« rendue DÉSACTIVÉE »** — c'est-à-dire *grisée*, exactement ce que M6 refuse.

Et `:58-62`, cité par l'affirmation, distribue ses qualificatifs par slot :

```
58|  /// Retourne [action] SSI la feature est disponible, sinon `null`. Le `null`
59|  /// rend la surface NON actionnable / ABSENTE **par le mécanisme EXISTANT**
60|  /// ([ZContentHubEntry.onTap] `null`, [ZItemAction.onSelected] `null` filtrée,
61|  /// [ZStudyToolsSectionSpec.addAction] `null`) — jamais un no-op silencieux
```

« **filtrée** » est accolé à `ZItemAction.onSelected`, pas à `ZContentHubEntry.onTap`.
L'affirmation a transporté la garantie d'un canal vers un autre.

**Le socle SAIT faire disparaître — ailleurs.** `z_item_actions_menu.dart:135-141` :

```
135| /// | [onSelected] | [disabledReason] | État rendu |
137| /// | non-`null` | `null` | **présente et actionnable** |
138| /// | `null` | `null` | **ABSENTE** — règle AD-4 HISTORIQUE, préservée |
139| /// | `null` | non-`null` | **présente, INERTE, motif ANNONCÉ** |
141| /// [permitted] `false` force l'absence, quoi qu'il en soit du reste de la ligne.
```

`ZItemAction` a trois états et un `permitted`. `ZContentHubEntry` en a **zéro** — liste
exhaustive de ses 9 champs (`:82,87,90,98,101,110,119,127,130`) : `icon`, `label`, `enabled`,
`hint`, `onTap`, `tint`, `colorKey`, `badgeLabel`, `badgeSemanticLabel`. **Pas de `permitted`.**

**GREP NÉGATIF MONTRÉ** :
```
$ grep -n "physics\|permitted\|shrinkWrap\|ScrollController\|primary:" z_content_hub_sheet.dart
440:            shrinkWrap: true,
```

---

## 5. `.gate(` dans le hub est un COMMENTAIRE, jamais du code

**GREP NÉGATIF MONTRÉ** — tous les appels à `.gate(`/`enabledFor(` dans `packages/*/lib/` :

```
$ grep -rn "\.gate(\|enabledFor(" packages/*/lib/
packages/zcrud_study/lib/src/presentation/z_content_hub_sheet.dart:181:///           onTap: fa.gate('flashcards.ai', _generate),
packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart:1152:        onSelected: availability.gate(
packages/zcrud_study/lib/src/presentation/z_feature_availability.dart:54:  bool enabledFor(String featureKey) => isAvailable(featureKey);
```

* `:181` est préfixé `///` — c'est **l'exemple de la dartdoc**, dans un bloc ```dart``` (:170-187).
* L'**unique** site d'appel réel du socle, `z_flashcard_list_view.dart:1152`, alimente
  `onSelected:` — précisément le slot qui **est** filtré. Le seul `gate` exécuté du socle prouve
  la disparition… dans l'autre composant.

**GREP NÉGATIF MONTRÉ** — `ZContentHubSheet` n'a jamais entendu parler du Scope :

```
$ grep -n "ZFeatureAvailabilityScope\|ZFeatureAvailability" z_content_hub_sheet.dart
(aucune sortie — RC=1)
```

Le hub ne lit **pas** `ZFeatureAvailabilityScope.of(context)`. `ZMapFeatureAvailability` et
`ZFeatureAvailabilityScope`, avancés comme preuves, n'ont donc **aucun effet** sur le hub : c'est
l'hôte qui doit appeler `gate` à la main, entrée par entrée. Le Scope n'achète rien pour M6.

**GREP NÉGATIF MONTRÉ** — aucun usage hôte :
```
$ grep -rn "ZFeatureAvailability" /home/zakarius/DEV/iffd/lib/
(aucune sortie — RC=1)
```

---

## 6. Couverture PARTIELLE du besoin réel de l'hôte

### 6.1 `isLocked` — le cadenas n'a aucun canal

`isLocked` est **orthogonal** à `enabled` chez l'hôte, ce que l'affirmation ignore :

| Carte | ligne | `isLocked` | `enabled` | comportement |
|---|---|---|---|---|
| Générer des flashcards | :912-919 | **true** | false | inerte |
| Aide aux devoirs | :920-927 | false | false | inerte |
| Créer un plan d'étude | :928-935 | false | false | inerte |
| Comprendre un sujet | :936-951 | **true** | **true** | **navigue** vers `DiscovryPage` |

La 4ᵉ carte est **verrouillée ET active** : `isLocked` marque un accès premium, pas une
indisponibilité. Rendu : `Icons.lock` 12 dp dans un conteneur teinté (`:1077-1087`).

Or `ZContentHubEntry.badgeLabel` est un `String?` (`:127`) et `_buildBadge` rend
`Text(label)` (`:889`) — **badge textuel uniquement**.

**GREP NÉGATIF MONTRÉ** :
```
$ grep -n "lock\|Lock\|premium\|badgeIcon\|IconData? badge" z_content_hub_sheet.dart
728:            child: _buildLabelBlock(material),
761:        Expanded(child: _buildLabelBlock(material)),
771:  Widget _buildLabelBlock(ThemeData material) {
```
Trois hits, tous la sous-chaîne « Lock » de `_buildLabelBlock`. **Aucune notion de verrou.**

### 6.2 L'échelle de colonnes n'est pas reproductible

Hôte (`:960-966`) :
```
960|        const double minItemWidth = 400.0;
963|        int crossAxisCount = (screenWidth / minItemWidth).floor();
966|        crossAxisCount = crossAxisCount.clamp(2, 4);
```
→ ladder continu **2 / 3 / 4**, avec un **plancher de 2 colonnes même sur téléphone** (375 lp).

Socle (`:435-437`) :
```
435|          final int columns = !comfortable || constraints.maxWidth < breakpoint
436|              ? 1
437|              : (wideColumns < 1 ? 1 : wideColumns);
```
→ fonction en escalier à **deux valeurs seulement** : `1` ou `wideColumns`. Références :
`gridBreakpoint = 600`, `gridCrossAxisCount = 2` (`z_content_hub_reference.dart:285,288`).

**3 colonnes est inatteignable**, et à 375 lp l'hôte passerait de **2 colonnes à 1**.

### 6.3 Rupture de rendu assumée par le socle lui-même

`itemExtent = kToolbarHeight * 2` = **112** (`z_content_hub_reference.dart:168`) contre
`childAspectRatio: itemWidth / (kToolbarHeight * 2.5)` = **140** chez l'hôte (`:977`).
La barre d'accent en dégradé (`:1033-1044`) n'a **aucun slot** (`tint`/`colorKey` ne peignent
qu'une pastille et un fond de carte). La dartdoc du socle le dit d'ailleurs elle-même
(`z_content_hub_sheet.dart:28-29`) : « Tout hôte passif voit son rendu changer sans avoir rien
demandé. C'est assumé et déclaré : **écart de conception, pas une parité**. »

---

## 7. Condition cachée BLOQUANTE — scrollable imbriqué sur l'un des deux sites d'appel

`ZContentHubSheet.build` retourne (`:439-440`) :
```
439|          return CustomScrollView(
440|            shrinkWrap: true,
```
`shrinkWrap: true` est **codé en dur**, et il n'existe **aucun paramètre `physics`,
`primary` ou `ScrollController`** (grep négatif du §4 : hit unique ligne 440).

Or `buildQuickAction()` a **deux** sites d'appel dans l'hôte :

* `:535` — **à l'intérieur d'un `SingleChildScrollView`** ouvert ligne `:246` ;
* `:551` — hors de ce scrollable.

C'est exactement pourquoi l'hôte écrit `physics: const NeverScrollableScrollPhysics()` (`:972`).
Un `CustomScrollView` non paramétrable imbriqué dans un `SingleChildScrollView` de même axe
absorbe le geste de défilement. Le socle **n'offre pas d'échappatoire**.

Preuve empirique côté hôte : IFFD consomme **déjà** `ZContentHubSheet`
(`lib/src/presentation/features/folders/zcrud/content_hub_zcrud.dart:453`), et l'y place
`Flexible(child: ZContentHubSheet(sections: _sections()))` dans une **modale bornée** —
jamais dans un scrollable parent. « S'embarque en ligne dans une page » n'est donc pas établi
pour *cette* page.

---

## 8. Ce qui est vrai à la place

1. `ZContentHubSheet` est bien le bon composant pour **présenter** 4 entrées de création de
   contenu, et IFFD sait déjà s'en servir (`content_hub_zcrud.dart`). Les ~201 lignes de
   `_QuickActionsWidget` + `_QuickActionCard` sont bien supprimables **sur le principe**.
2. Mais **M6 tel qu'écrit n'est PAS livrable sur le socle actuel** :
   * faire **disparaître** les 3 affordances demande aujourd'hui un simple `if` côté hôte
     (ne pas construire l'entrée) — c'est **du code hôte**, pas `gate`, et `gate` devient inutile ;
   * le livrer **par le socle** demande une **évolution de `zcrud_study`** : un drapeau
     `permitted` sur `ZContentHubEntry` (patron `ZItemAction`) + filtrage dans `_groups()`,
     ce qui **casse la garde** `z_content_hub_sheet_test.dart:89-99`.
3. Trois autres évolutions de socle sont nécessaires pour une parité honnête : un slot de badge
   **iconique** (`isLocked`), un `physics`/`shrinkWrap` injectable (site d'appel `:535`), et une
   échelle de colonnes continue (2/3/4) ou un `gridCrossAxisCount` fonction de la largeur.
4. À défaut, la migration **régresse** l'accessibilité visuelle : 3 cartes aujourd'hui à
   `Opacity(0.5)` deviendraient indiscernables des actives.

**M6 doit être requalifié en CR d'évolution du socle, pas en migration.**
