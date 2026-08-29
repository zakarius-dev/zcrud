# Handoff v3.34.0 — le socle redevient lui-même par défaut, l'habillage legacy devient un choix

> **Date** : 2026-08-29. **Portée** : `zcrud_core`, `zcrud_ui_kit`, `zcrud_study`,
> `zcrud_document`, `zcrud_chat`, `zcrud_session`, `zcrud_generator`, `zcrud_note`.

## Clés de schéma ajoutées

**Aucune.** Aucun `toMap()` ne change, aucun `.g.dart` ne change de contenu.

## 1. LA BASCULE (décision du propriétaire)

Le défaut du profil de référence passe de `legacy` à **`neutral`** : sans configuration, le socle
rend **exactement ce qu'il rendait en v3.28.0** — ses propres améliorations, pas la peau d'IFFD.
Tout l'habillage legacy livré par les vagues d'apparence reste complet et se choisit en **une
ligne** : `ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.legacy))` à la racine.

**Les treize familles qui changent de défaut** (elles reviennent au rendu d'avant la vague ;
`legacy` explicite les restaure toutes) : bande + tuile des en-têtes de section de
`DynamicEdition` ; maillon `zcrud.signature.*` de `zResolveGradient` ; palette signature des
cartes de dossier sans couleur ; bande/tuile des sections d'outils d'étude ; pastille de
sous-dossier ; lavis d'app bar (`ZPageShell`/`ZPageScaffold`/`ZSearchableAppBar`) ; teinte
sélectionnée des chips ; `ZGradientFab` sans dégradé explicite ; palette d'annotation, pastille et
glyphe du lecteur de document ; couleurs de célébration du résumé de session ; `zBusyPaletteOf`
(le chat, lui, **ne change pas** : son indicateur retombe sur sa propre référence — repli local,
gardé) ; accents du skin de notebook sous `neutral` explicite ; sortie neutre des références de
viewer.

**Impact par hôte** :
- **DODLP, lex, DLCFTI : rien à faire** — leur rendu redevient celui d'avant v3.29.0 sans action.
  Un hôte qui avait posé `referenceProfile: neutral` en échappatoire peut retirer cette ligne
  (inoffensive si elle reste).
- **IFFD : une ligne** à la racine pour tout l'habillage legacy.

Deux défauts réels corrigés par la bascule elle-même : `ZChoiceChipStyle.resolve` effaçait sous
`neutral` une palette **posée par l'hôte** (la chaîne paramètre > jeton > référence est rétablie
et gardée) ; `zcrud_document` portait la seule recopie de l'arbitre de repli du dépôt — il
délègue désormais à `zLegacyOrIn` (arbitre unique).

## 2. Le générateur : `List<Map<…>>` et `Map` imbriquée

`List<Map<K,V>>` et `Map<K, Map<K2,V2>>` à profondeur libre, décodage défensif **à chaque
niveau** (une entrée illisible n'emporte ni sa map, ni l'entrée externe, ni le parent), `null`
déclaré préservé, dates ISO-8601 à tous les niveaux. `List<Map<K,V>?>` reste refusé avec un
message expliquant pourquoi (une liste amputée mentirait sur sa longueur). **Aucun `.g.dart`
existant ne change.** La dartdoc du canal manuel de `ZSmartNote.content` est réécrite : le canal
demeure pour ses propriétés propres (vue non modifiable, slot brut `const`, absence délibérée de
`ZFieldSpec`), plus au nom d'une limite du générateur qui n'existe plus.

## 3. Vérification

| Paquet | Tests |
|---|---|
| `zcrud_core` | **2 690** · `zcrud_ui_kit` **324** · `zcrud_study` **1 831** · `zcrud_document` **335** · `zcrud_chat` **1 070** · `zcrud_session` **653** · `zcrud_generator` **185** (`dart test`) · `zcrud_note` **197** |

`melos run generate` : 0 `.g.dart` modifié · `analyze` RC=0 · `verify` RC=0 · R3 : 6 campagnes de
bascule (61 rouges par assertion) + 5 injections generator, restaurations par copie, sha
identiques, greps négatifs. Constat de méthode consigné : sous injection du défaut, les variantes
« `neutral` explicite » restaient vertes — une garde qui ne mesure que la forme explicite est
aveugle au défaut, d'où les deux à trois formes mesurées partout. Balayage des 41 : **41/41 verts** après re-figement de l'étalon d'inertie de `zcrud_screen`
(390 verts) — figé sous l'app bar teintée de v3.30.0, il a rougi quand la bascule a ramené le
rendu d'avant : le tripwire a fait son travail dans les deux sens.
