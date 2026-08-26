# Réfutation — Cartes mentales (mindmap) — IFFD

**Affirmation attaquée** : « le socle sait déjà le faire, par
`ZStudyToolsSectionSpec.mindmaps({maps: List<ZMindmap>, nodeCountLabel, colorKeyOf, progressOf, ...})
+ ZDefaultMindmapCard` ».
**Gain annoncé** : ~64 lignes d'hôte supprimées.

## VERDICT : **DÉMENTIE**

Le canal existe, son corps fait ce qu'on lui prête, il est exporté et atteignable.
**Ce qui tombe, c'est la COUVERTURE** : `.mindmaps` ne peut pas exprimer le besoin réel de la
section IFFD. Trois écarts, dont deux bloquants, et un gain surévalué de ~60 %.

---

## 1. Ce qui RÉSISTE (la moitié « socle » de l'affirmation est exacte)

Vérifié pièce par pièce, aucun écart :

| Preuve avancée | Vérification | Statut |
|---|---|---|
| ctor typé `:469` | `z_study_tools_section_spec.dart:469` `ZStudyToolsSectionSpec.mindmaps({...})` | ✅ |
| corps construit la carte | `:621-658` — `itemBuilder` assigne `ZDefaultMindmapCard`, clé stable `ValueKey('zDefaultMindmapCard-${map.id…}')`, repli `ephemeral-$index` | ✅ |
| `zMindmapNodeCount :69-79` parcourt toute la forêt par pile explicite | `z_default_mindmap_card.dart:69-79` — `while (stack.isNotEmpty) { count++; stack.addAll(node.children); }`, aucune récursion | ✅ |
| puce absente sans `nodeCountLabel` (AD-4) | `:222-223` `final String? countText = nodeCountLabel?.call(count);` ; montage `:393` | ✅ |
| vignette `ExcludeSemantics`, info redite en texte | `:255`, `:319` `leading: ExcludeSemantics(` ; doc `:28-39` | ✅ |
| parité `progressOf` / `colorKeyOf` / `cardTrailingBuilder` | relayés `:645-648` vers la carte | ✅ |

**Atteignabilité** — également vérifiée, l'affirmation ne triche pas :
- barrel : `packages/zcrud_study/lib/zcrud_study.dart:83` (carte) et `:209` (spec) ;
- dépendances IFFD déclarées : `iffd/pubspec.yaml:391` (`zcrud_study`), `:345` (`zcrud_mindmap`).

**Grep négatifs de l'hôte — REJOUÉS PAR MOI, tous confirmés** (`cd /home/zakarius/DEV/iffd`) :

```
ZStudyToolsSectionSpec.mindmaps    -> 0
ZStudyToolsSectionSpec.flashcards  -> 0
ZStudyToolsSectionSpec.documents   -> 0
ZStudyToolsSectionSpec.notes       -> 0
ZStudyToolsSectionSpec.folders     -> 0
ZStudyToolsSectionSpec.exams       -> 0
ZDefaultMindmapCard                -> 0
zMindmapNodeCount                  -> 0
```

Aucune voie typée n'est utilisée par IFFD. **Ce constat-là tient.** Il ne dit rien, en revanche,
de la question qui décide : *pouvait-elle l'être ?*

⚠️ Correction de localisation : le fichier hôte est
`lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart` (962 l.), sous
`features/folders/`, non `features/study/`.

---

## 2. RÉFUTATION 1 (BLOQUANTE) — l'atténuation `Opacity(0.5)` n'est pas exprimable

L'hôte enveloppe **chaque item** dans un `Opacity` :

```dart
// study_tools_zcrud_adapter.dart:789-802
cardBuilder: (BuildContext context, int index) {
  final ZStudyToolsItem it = mindmaps[index];
  return Opacity(
    opacity: it.opacity,          // :792
    child: ZDefaultNoteCard(…),
  );
},
```

Règle métier, `:959` :
```dart
opacity: !subjectToolPage && mindmap.folderId == null ? 0.5 : 1.0,
```
→ une carte mentale **héritée** (rattachée à aucun dossier) est **grisée**.

### GREP NÉGATIF MONTRÉ — le socle n'a aucune prise

```
$ cd /home/zakarius/DEV/zcrud/packages/zcrud_study/lib && grep -rn "opacity" . | wc -l
0
```

**Zéro occurrence de `opacity` dans TOUT `zcrud_study/lib`.** Et sur le spec :

```
$ grep -n "itemWrapper\|itemDecorator\|wrapItem\|cardWrapper" z_study_tools_section_spec.dart
(aucun hit)
```

Il n'existe donc :
- **ni** paramètre `opacity` sur `ZDefaultMindmapCard` (ctor complet lu, `:92-115` : 21 paramètres,
  aucun d'atténuation) ;
- **ni** hook d'enveloppement sur `ZStudyToolsSectionSpec`.

Le ctor `.mindmaps` **assigne `itemBuilder` lui-même** (`:621`) et retourne la carte directement
(ou emballée dans `ZRailItem` en horizontal, `:655-659`). Le consommateur n'a **aucun point
d'insertion** entre la section et la carte.

### Ce n'est pas un détail cosmétique : c'est gardé par un tripwire de l'hôte

`test/w6/study_tools_zcrud_test.dart:1561-1586` :

> `testWidgets('atténuation legacy d'un contenu hérité (Opacity 0.5) CONSERVÉE au-dessus de la carte du socle')`
> `expect(opacityOf('d0').opacity, 0.5);`

Le titre du test dit explicitement que l'atténuation doit rester **au-dessus de la carte du socle**.
Plus les assertions unitaires `:459-460` (`expect(mapped.first.opacity, 0.5)`) et `:469`
(`subjectToolPage: true` ⇒ `1.0`).

**Adopter `.mindmaps` fait tomber ce test et supprime un comportement visible caractérisé.**

### Portée : ce n'est pas un problème « mindmap »

Le motif est **systémique** — 4 sites d'application dans l'adaptateur :
`:723`, `:758`, `:792` (mindmaps), `:914`, plus les deux règles `:936` (notes) et `:959` (mindmaps),
sur un champ `ZStudyToolsItem.opacity` déclaré `:277` / `:316`.
⇒ Le même blocage vaut pour **toutes** les voies typées (`.notes`, `.documents`, `.flashcards`…),
ce qui explique mieux le `-> 0` généralisé que « l'hôte n'a pas essayé ».

---

## 3. RÉFUTATION 2 (BLOQUANTE) — le signal qui pilote l'atténuation est DÉTRUIT par la conversion

Même si l'on ajoutait un hook d'opacité, la règle serait **incalculable** depuis un `ZMindmap`.

| Côté | Déclaration | Nullabilité |
|---|---|---|
| Socle | `z_mindmap.dart:46`, `:73` — `final String folderId;` <br>dartdoc : « clé de sous-collection + filtrage stream, **non-null** » | **non-nullable** |
| IFFD | `folder_model.dart:257` — `final String? folderId;` | **nullable** |

Or **c'est précisément la nullité qui porte l'information** (`mindmap.folderId == null ? 0.5 : 1.0`).

Le mappeur existant de l'hôte l'écrase :

```dart
// mindmap_zcrud_mapper.dart:155-157
return ZMindmap(
  id: _str(model.id) ?? '',
  folderId: _str(model.folderId) ?? '',   // ← null ET '' collapsent sur ''
```

Après conversion, `folderId == null` et `folderId == ''` sont **indiscernables**. Reconstituer la
règle exigerait de fabriquer une convention (`isEmpty` vaut `null`) — c'est-à-dire **inventer une
donnée que la source n'a pas**, exactement ce que la charte du dépôt interdit.

---

## 4. RÉFUTATION 3 (MAJEURE) — les callbacks typés rendent un `ZMindmap`, l'hôte exige le modèle d'origine

Les rappels de `.mindmaps` sont typés sur `ZMindmap` (`:475-481`) :
`onCardTap(ZMindmap)`, `cardTrailingBuilder(BuildContext, ZMindmap)`, `progressOf(BuildContext, ZMindmap)`.

Les actions de l'hôte exigent un **`MindmapModel`** :

| Action hôte | Signature | Fichier:ligne |
|---|---|---|
| Ouverture | `showFolderMindmapViewer({MindmapModel? mindmap, …})` | `mindmap_dialogs.dart:124-125` |
| Trailing | `_mindmapTrailing(BuildContext, WidgetRef, MindmapModel mindmap)` | `folder_study_tools_page.dart:799-800` |
| Mise à jour | `onChanged: (updated) => …update(updated)` — `ValueChanged<MindmapModel?>` | `mindmap_dialogs.dart:128` |

Et l'hôte a **contractualisé** ce point par un test :
`test/w6/study_tools_zcrud_test.dart:494` — `test('callback d'ouverture remonte le MODÈLE d'origine')`.

⇒ `ZMindmap` ne conserve **pas** de référence au modèle d'origine (champs lus : `id`, `folderId`,
`title`, `description`, `nodes`, `extension`, `extra` — `z_mindmap.dart:61-90`). L'hôte devrait
maintenir un **index inverse `Map<String, MindmapModel>`** et faire un `lookup` dans chacun des
trois rappels. **Cela AJOUTE de la glu au lieu d'en retirer.**

---

## 5. RÉFUTATION 4 — le gain de « ~64 lignes » est surévalué d'environ 60 %

Décompte réel sur disque, bornes exactes :

| Bloc supprimable | Lignes | Compte |
|---|---|---|
| Closure `cardBuilder` | `789-802` | **14** |
| Commentaire qui la justifie | `786-788` | **3** |
| `mindmapStudyItems` (dartdoc `941-942` + corps `943-963`) | `941-963` | **23** |
| **Total** | | **40** |

Le reste de l'appel `zStudyToolsSection(` (`781-812`, 32 l. au total) — `id`, `title`, `emptyState`,
`collapsible`, `collapseOnHeaderTap`, `reorderHandleMode`, `crossAxisMinItemWidth`, `addAction`,
`onReorder`, `reorderHandleSemanticLabel` — **subsiste à l'identique** avec `.mindmaps`, qui expose
tous ces paramètres.

**40 lignes brutes, pas 64** — et ce chiffre suppose les points 2-4 résolus. Net des ajouts
(index inverse + appels `toZMindmap` + restitution de l'atténuation), le gain est **nul ou négatif**.

---

## 6. Un point où je donne raison à l'affirmation CONTRE l'hôte

L'affirmation reprend la justification de l'hôte (`:786-788`) :
> « Carte par PRIMITIVES : plus besoin du détour `ZMindmap` retiré au tour précédent. »

**Cette justification est plus faible qu'elle n'en a l'air**, et il est honnête de le dire : le
détour n'a **pas** été retiré du dépôt. `MindmapZcrudMapper.toZMindmap` **existe toujours** —
`mindmap_zcrud_mapper.dart:132` — et est appelé à 3 sites :
`mindmap_outline_zcrud.dart:129`, `zcrud_mindmap_view.dart:75`, `z_backed_mindmap_repository.dart:226`.
`ZMindmap` compte **80 occurrences** dans `lib`+`test` d'IFFD, réparties sur 9 fichiers.

⇒ Le coût de mapping invoqué par l'hôte est **déjà payé et amorti**. Ce n'est donc pas là que se
joue le refus. Le refus se joue sur l'**opacité** (§2) et sur le **type des rappels** (§4) — deux
raisons que le commentaire de l'hôte ne mentionne pas.

**Conséquence pratique** : la voie typée redeviendrait crédible si le socle ajoutait un point
d'insertion d'enveloppement (ou un `opacity`/`dimmed` sur la carte) **et** un moyen de retrouver
le modèle d'origine. Ce sont deux CR de socle, pas une migration d'hôte.

---

## 7. Constat annexe — défaut réel dans le socle (hors périmètre de l'affirmation)

`_buildTintedTile` **reçoit** `count` et `countText` en paramètres (`:308-313`), mais la puce
recalcule tout :

```dart
// :392-393
child: Text(
  nodeCountLabel!.call(zMindmapNodeCount(map.nodes)),
```

⇒ **second parcours intégral de la forêt** + second appel de `nodeCountLabel` à chaque rebuild du
chemin `tintedTile`, alors que les deux valeurs sont disponibles sur la pile. Inefficacité réelle
(O(N) redondant par rebuild), contraire à l'esprit de la réactivité granulaire (AD-2).
Correctif trivial : utiliser `countText` déjà transmis.

---

## Synthèse

| # | Écart | Gravité | Preuve |
|---|---|---|---|
| 1 | `Opacity(0.5)` inexprimable — 0 occurrence d'`opacity` dans tout `zcrud_study/lib`, aucun hook d'enveloppement, tripwire hôte explicite | **BLOQUANT** | grep négatif montré ; `test/w6:1561-1586` |
| 2 | `ZMindmap.folderId` non-nullable vs `MindmapModel.folderId` nullable **porteur de sens** ; le mappeur collapse sur `''` | **BLOQUANT** | `z_mindmap.dart:73` vs `folder_model.dart:257` ; `mindmap_zcrud_mapper.dart:156` |
| 3 | Rappels typés `ZMindmap`, actions hôte typées `MindmapModel` ⇒ index inverse à ajouter | **MAJEUR** | `mindmap_dialogs.dart:124-125` ; `folder_study_tools_page.dart:799-800` ; `test/w6:494` |
| 4 | Gain réel ≈ **40 l.** brutes, pas 64 ; net ≈ 0 après ajouts | **MAJEUR** | bornes `786-802`, `941-963` |
| 5 | *(annexe socle)* double parcours de la forêt dans `_buildTintedTile` | MINEUR | `z_default_mindmap_card.dart:311-312` vs `:393` |

**L'affirmation est DÉMENTIE.** Le canal est réel, honnête et bien construit ; il ne couvre pas le
besoin de l'hôte. Elle décrivait la version **simplifiée** du besoin (titre, sous-titre, icône,
compteur) en laissant hors champ les deux propriétés qui décident : l'**atténuation des contenus
hérités** et le **transport du modèle d'origine** — toutes deux gardées par des tests de l'hôte.
