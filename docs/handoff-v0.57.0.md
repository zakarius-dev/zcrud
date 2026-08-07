# Handoff **v0.57.0** — la feuille de réglages devient déclarative (mode Tile), le sélecteur de modèle arrive

> **Tag à épingler : `v0.57.0`** · strictement additif, aucune rupture d'API.
> Chantier arbitré par le propriétaire **sur vidéos** (screencasts des deux apps fournis et
> analysés image par image) : le mode Tile d'IFFD devient un **modèle de données injectable**,
> les contrôles adoptent le rendu lex là où il est meilleur, et le sélecteur de modèle des
> deux composers entre au socle.

---

## 1. Le modèle d'entrées — votre feuille devient déclarative

`ZChatSettingsEntry` : une app déclare désormais sa feuille d'outils comme une **liste
d'entrées typées** — `id` opaque, icône, titre/sous-titre par clés de libellé, section
d'appartenance, et un contrôle dont le `kind` est **OUVERT** (interface, jamais un enum) :
`toggle` · `scale`/`select` (segments à coche — le rendu lex) · `navigation` (chevron) ·
`numberBounded` (bornes **réellement appliquées** — le `MinMaxFormatter` d'IFFD au corps
commenté n'a pas été porté).

Le rendu par défaut est le **mode Tile IFFD** : icône + titre + sous-titre + contrôle, en
sections titrées — la partie la plus réussie de votre legacy, confirmée à l'image.

**Tout est surchargeable, à quatre niveaux** : par entrée (`entryBuilders`), par kind
(`kindBuilders` — c'est là qu'un hôte porte ses kinds propres), par section
(`sectionBuilders`), et le repli `unknownEntryBuilder`. Un kind inconnu sans builder ⇒ entrée
**absente**, jamais un throw.

### 🔴 L'hybride, prouvé à l'arbre près
Les 5 familles standard sont **re-exprimées en interne** sur ce modèle — une seule voie de
rendu, pas deux (le motif de divergence CR-LEX-78). L'API publique n'a pas bougé, et la preuve
est forte : l'arbre rendu par défaut a été **sérialisé AVANT le refactor** (étalon versionné,
sha vérifié) et la garde d'égalité est verte APRÈS — avec démonstration que le sérialiseur
**voit** une différence réelle (un `SizedBox` injecté dans la voie commune la fait rougir).
Votre feuille rend **exactement** la même chose ; elle est simplement devenue extensible.

## 2. Le sélecteur de modèle — « ✦ Mini/Plus/Pro », « Polaris Lite/Polaris »

Visible dans vos deux vidéos, absent du socle. Livré :
* **Contrat opaque** `ZChatModelOption {id, label|labelKey, icon?}` — 🔴 **zéro nom de modèle
  dans le socle** (gardé par grep avec contre-preuve) : « Mini » et « Polaris » sont vos
  données, pas les nôtres ;
* **Menu par défaut au rendu des vidéos** : déclencheur dans la rangée d'accessoires, menu
  au-dessus aligné au bord de fin (directionnel), **coche sur l'actif** = `Semantics(selected:)`
  + l'emphase CR-74 peinte + glyphe d'hôte ;
* **Absent sans options** (AD-4), monté par `ZChatComposerModelSelector.slot(...)` ;
* La sélection remonte par `onSelect(id)` — **la persistance reste chez vous**
  (votre `aiRouterId`). Aucun membre n'a été ajouté au contrôleur (G-CH1 non approchée,
  vérifié : le créneau suffisait).

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **IFFD** | vos entrées de corpus, « ignorer pour l'IA », etc. deviennent des `ZChatSettingsEntry` injectées — plus aucune feuille maison ; branchez `ZChatComposerModelSelector.slot` avec vos options Polaris et persistez `onSelect` dans votre `aiRouterId` |
| **lex_douane** | vos segments à coche et votre en-tête sont désormais le rendu par défaut ; le sélecteur Mini/Plus/Pro se déclare en 3 `ZChatModelOption` |
| **hôte passif** | rien — arbre par défaut **identique à l'octet près** (étalon versionné), sélecteur absent sans options |
| **hôte à feuille custom** | vos builders historiques **priment toujours** (ordre de résolution : builder historique > entrée > kind > défaut) |

🟢 **Tripwire recommandé** : un test qui sérialise votre feuille rendue et l'épingle — le
patron de l'étalon du socle est réutilisable tel quel (`z_chat_settings_tree_reference.txt`).

## 4. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (38 paquets) · `melos generate` RC=0 ·
`zcrud_chat` **510** (+26) · jumelles : kernel 411, study 1521, syncfusion 65, markdown 504,
material 39 · **0 erreur, 0 avertissement**.

**R3 — 9 injections, toutes ROUGE-ASSERTION** ; sha256 à chaque pas ; aucun résidu.
🟢 **Une garde vacante de plus démasquée par l'agent sur son propre travail** : sa garde SM-1
« frère non reconstruit » était **inatteignable telle qu'écrite** (instances de widgets
identiques entre deux builds) — deux injections d'ancêtre restées vertes l'ont prouvé. Elle a
été **re-scopée sur l'atteignable** (aucun abonnement du sélecteur aux tranches de flux,
mesuré sur un tour complet) plutôt que gardée pour le décor.

⚠️ Notre CI reste à l'arrêt (facturation) : vérifications locales, état commité re-mesuré
après commit (règle v0.54.1).

## 5. Non couvert

* Le budget de calcul garde ses **segments** (contrainte d'arbre identique) — le
  « toggle + slider de profondeur » de lex s'obtient par `kindBuilders` ou via le satellite.
* Le menu du sélecteur n'est pas contraint au viewport (déclencheur en haut d'écran ⇒ passez
  `menuBuilder`).
* Au satellite Material (signalé, non écrit) : coche `Icons.check`, chevron, `Switch`, slider
  de profondeur, champ nombre, menu pixel-perfect.
* 4 jetons à poser dans `zcrud_core` (`chatSettingsSectionTitleWeight`, `chatSettingsSectionGap`,
  `chatSettingsMarkGap`, `chatModelMenuGap`) — la chaîne paramètre > référence fonctionne en
  attendant.
* Dettes antérieures : cf. v0.56.0.
