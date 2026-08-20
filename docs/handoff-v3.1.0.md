# Handoff **v3.1.0** — la marge de personnalisation, rendue infaillible

> **Tag à épingler : `v3.1.0`** — corrige un défaut livré en 3.0.0 et supprime **deux dettes** qui
> faisaient disparaître, en silence, ce qu'un hôte déclare.
> Paquets porteurs : **`zcrud_get`**, **`zcrud_provider`**, **`zcrud_riverpod`**, **`zcrud_study`**,
> **`zcrud_core`**.

---

## 1. 🔴 Un binding effaçait 21 seams sur 23

Les trois bindings construisaient un `ZcrudScope` **à neuf**, avec le résolveur et l'ACL seuls. Or
le constructeur **n'hérite pas** de l'ambiant — la sentinelle d'omission ne vaut que pour
`copyWith`/`derive`. Un scope imbriqué **masque** donc son parent.

⇒ **Si vous posiez votre propre `ZcrudScope` — thème, registres, canaux de rendu déclaratif —
au-dessus d'un binding, tout cela disparaissait sous ce binding.** Sans erreur, sans avertissement.

Les trois **dérivent** désormais de l'ambiant : ce qu'ils déclarent prime, le reste est hérité.
**Sans scope ambiant, rien ne change** — gardé par contre-témoin, repli d'ACL compris.

Chaque binding a été traité **sur mesure** : Provider doit conserver son constructeur intermédiaire
sous son fournisseur multiple, et c'est ce contexte-là qui sert à la dérivation. Une garde mesure
d'ailleurs qu'il ne peut pas se dériver de lui-même.

## 2. La re-pose du scope devient infaillible par construction

Deux sites de `zcrud_study` recopiaient le scope **seam par seam** sous un `Overlay`. Les
commentaires du fichier recensaient **cinq** ports oubliés puis rattrapés un par un — les deux
derniers datant de la veille, et le **site jumeau** portant les mêmes manquants sans qu'aucune garde
ne le surveille.

`copyWith` **hérite de tout paramètre omis** : le défaut ne peut plus se produire, au lieu d'être
rattrapé après coup.

**La garde a été repensée, pas supprimée.** Elle scannait la source à la recherche d'une énumération
— elle aurait donc rougi sur une correction qui tient mieux la propriété qu'elle protège. Elle
vérifie désormais le **comportement** : huit seams survivent par **identité**, dans la feuille
**et** dans la carte, et elle échouerait si quelqu'un revenait à une énumération manuelle.

## 3. 🔴 Un défaut que nous avons livré en 3.0.0

La teinte d'état des actions de menu passait par `IconTheme.merge`, qui n'atteint **que le contenu
qui hérite**. Un slot d'hôte stylé depuis `Theme.of(context).textTheme.*` (rôles `inherit: false`)
gardait la couleur ambiante et **restait illisible** — le défaut même que la teinte prétend corriger.

Remplacé par `ZForegroundOverride`, la primitive prévue, qui réécrit **aussi**
`ThemeData.textTheme`/`iconTheme`.

⚠️ **Et nous vous devons de dire comment il est passé.** Une garde **inter-paquets** de `zcrud_core`
scanne les sources de tous les paquets et interdit exactement cela. Elle était rouge — mais nous ne
rejouons que les suites des paquets touchés, et `zcrud_core` n'en faisait pas partie. **C'est la
deuxième fois en une journée** qu'une garde inter-paquets attrape un défaut livré pour cette même
raison ; la première est décrite au §1 du handoff v3.0.0.

**Corrigé côté process** : la vérification de release rejoue désormais les suites des **40 paquets**,
pas seulement des paquets modifiés. Ce balayage est ce qui a trouvé ce défaut.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire.
- **Hôte employant un binding** : ce que vous déclariez au-dessus **arrive enfin** sous le binding.
  Si vous aviez compensé en redéclarant vos seams **sous** le binding, cette compensation est
  désormais inutile — elle reste sans effet nuisible, votre déclaration la plus proche primant.
- **Hôte employant les menus d'actions de `zcrud_study`** : la teinte d'état atteint maintenant les
  slots libres. Si un slot vous paraissait ignorer la teinte en 3.0.0, c'était ce défaut.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0.

**Balayage complet des suites — 39 paquets verts sur 39 exécutables** :
`zcrud_core` **2341** · `zcrud_study` **1540** · `zcrud_firestore` 812 · `zcrud_flashcard` 586 ·
`zcrud_markdown` 584 · `zcrud_session` 581 · `zcrud_chat` 556 · `zcrud_chat_kernel` 411 ·
`zcrud_study_kernel` 398 · `zcrud_geo` 370 · `zcrud_screen` 350 · `zcrud_intl` 286 ·
`zcrud_document` 235 · `zcrud_ui_kit` 232 · `zcrud_mindmap` 223 · `zcrud_navigation` 188 ·
`zcrud_note` 173 · `zcrud_get` **152** · `zcrud_select` 142 · `zcrud_responsive` 117 ·
`zcrud_export_pdf` 80 · `zcrud_menu` 80 · `zcrud_exam` 79 · `zcrud_chat_syncfusion` 69 ·
`zcrud_list` 69 · `zcrud_chat_study` 67 · `zcrud_chat_markdown` 57 · `zcrud_export` 51 ·
`zcrud_chat_material` 47 · `zcrud_dnd` 33 · `zcrud_media` 31 · `zcrud_export_ui` 30 ·
`zcrud_riverpod` **28** · `zcrud_reorder` 27 · `zcrud_field_extras` 26 · `zcrud_html` 25 ·
`zcrud_geo_location` 22 · `zcrud_annotations` 10 · `zcrud_provider` **10**.

⚠️ `zcrud_generator` échoue de façon **environnementale** (`Unsupported operation:
Isolate.packageConfig`, via `build_test`) — paquet **intact**, hors de cette vague, rouge qualifié
et non imputé au code.

Injections R3 sur les deux lots, rouges **par assertion**, restaurations par copie avec sha256
avant/après cités. Une garde est **restée verte** sous injection : son auteur l'a dit, en a trouvé la
cause — l'observation était masquée par le déclencheur — l'a corrigée pour ne mesurer que la
surface visée, puis elle a mordu.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
