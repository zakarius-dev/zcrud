# Handoff **v0.53.0** — `ZChatNotebookReference` : le rendu de référence du Notebook

> **Tag à épingler : `v0.53.0`** · **strictement additif**, aucune rupture d'API.
> Dernier lot du chantier issu de l'étude **CR-IFFD-72**. v0.52.0 a livré l'ossature
> (composer partagé, réglages, portée de corpus) ; **v0.53.0 livre l'habillage**.
> 🔴 **Le skin est OPT-IN** : sans geste explicite, les deux vues rendent l'arbre d'avant —
> et **un jeton seul ne suffit pas** à l'activer.

---

## 1. `ZChatNotebookReference` — 50 constantes, chacune tracée

Patron **exact** des références d'étude (`abstract final class`, une constante par valeur, la
ligne legacy d'origine en dartdoc). Vit dans `zcrud_chat`, **pur** — `flutter/widgets.dart`
seul.

### 🔵 Nous avons REFUSÉ 4 des 7 familles que le relevé proposait d'exempter
L'exception FR-26 encadrée ne vaut que pour ce qui n'est **pas dérivable d'un `ColorScheme`**.
Écartées parce qu'elles le sont :

| Famille proposée | Rôle qui la couvre |
|---|---|
| rouge des badges | `error` |
| `lightBlue` « joindre actif » | `primary` |
| repli orange de focus | un **repli** doit être un rôle — le relevé le disait lui-même |
| gris des sous-titres | `onSurfaceVariant` |

Restent **13 littéraux en 3 familles** réellement irréductibles : l'accent d'outil, la palette
d'occupation (7 teintes) et les accents de capacité (5).

⇒ L'exception reste **étroite**. C'est sa condition de survie.

## 2. Les jetons : 9, dans `ZcrudTheme`

Motif : `zcrud_chat` bannit `material.dart` ; un porteur local aurait imposé un
`InheritedWidget` de plus **à côté** de `ZcrudScope.theme`, que le paquet lit déjà. Les 4 sites
(champ, constructeur, `copyWith`, `lerp`) sont respectés, garde des 4 sites verte **et
mordante**.

**Chaîne paramètre > jeton > référence** : `ZChatNotebookSkin.resolve()`, **pure** et vivant
dans `zcrud_chat` — donc prouvable **sans monter Syncfusion**. Résolution **champ par champ**,
pas objet par objet : vous pouvez ne remplacer qu'une valeur.

## 3. Le skin, par la couture existante

`ZSfAssistShellRenderer.notebookSkin` (nullable) règle **exactement les deux membres** que le
legacy règle réellement. **Aucune vue parallèle** — le dartdoc du renderer documente qu'une
`ZSfAssistConversationView` avait été livrée puis **supprimée** (motif CR-LEX-78) ; nous ne
l'avons pas refaite.

🔵 **Ce que nous n'avons pas inventé** : le legacy ne pose de `shape` que sur la bulle de
**requête**. Donc `responseBubbleRadius = null`, avec garde et injection dédiées. Une valeur
inventée aurait été indétectable — et fausse.

**Hôte passif, mesuré champ par champ** : les 11 champs du `SfAIAssistView` **réellement
monté** comparés à `const AssistMessageSettings()`. Au passage, un fait utile : le défaut
Syncfusion est `widthFactor == 0.8`, **pas** 0.95 — le 0,95 du Notebook est bien un choix
legacy, pas un défaut hérité.

---

## 4. 🔴 Ce que « pixel près » ne recouvre PAS — les défauts non reproduits

| Défaut legacy | Ce que fait le socle |
|---|---|
| bouton d'envoi **40 dp** | **48 dp**, égal à `kZChatMinTapTarget` — et 40 rendu **indéclarable** |
| 5 sites non directionnels | tout directionnel, jusqu'au `BorderRadiusDirectional` du skin |
| information portée par la **seule couleur** | **inexprimable** : `generatedLabelKey` et `generatedMarkSize` sont **requis** — ni thémables, ni paramétrables |
| libellés français en dur | clé + repli (`kZChatLabelGenerated`), convention du paquet respectée |
| `TextScaler` figé | **non porté** |
| format d'horodatage EU | **non imposé** (publié, à votre main) |

## 5. 🔴 Thème sombre : le verdict est contre-intuitif, et il vous concerne

Sur les 8 teintes distinctes du relevé, **5 échouent le seuil WCAG 3.0 — dont 4 en thème
CLAIR** (le jaune « humour » mesure **1,22:1**), et **une seule** en sombre (le brun, 2,86).

> Autrement dit : **le legacy était déjà fautif sur son propre thème par défaut**, et pas
> seulement en sombre comme on pouvait le supposer.

**Notre choix** : ne **pas** recolorer — ce serait renoncer au pixel près que vous demandez —
mais **retirer à la couleur sa charge d'information**, structurellement, par le type (§ 4,
ligne 3). La couleur reste ce qu'elle était ; elle cesse d'être le seul canal. Une garde
recalcule les 8 ratios et rougira si une valeur d'ici cesse de satisfaire son seuil.

---

## 6. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — arbre inchangé, et un jeton seul n'active pas le skin (mesuré) |
| **vous, IFFD** | montez `ZSfAssistShellRenderer(notebookSkin: …)` ; les 50 constantes sont lisibles pour aligner **votre** chrome (composer, feuille d'outils, badges, indicateur) |
| **hôte voulant une seule valeur différente** | `ZChatNotebookSkin` résout **champ par champ** — un paramètre suffit, inutile de tout redéclarer |
| **hôte du mode Chat** | rien : ce lot ne touche que le Notebook ; la modernisation du Chat (référence **lex_douane**) reste un chantier à venir |

🟢 **Tripwire recommandé** : un test qui affirme vos propres constantes de chrome notebook
(`kFolderCard…`-like) — il rougira le jour où vous les remplacerez par la référence du socle,
et vous désignera le doublon.

---

## 7. Vérification

`melos generate` **RC=0** (0 `.g.dart` modifié) · `melos analyze` **RC=0** · `melos verify`
**RC=0** (ACYCLIQUE + CORE OUT=0 + corpus de sérialisation, 36 paquets).

`zcrud_chat` **406** (+29) · `zcrud_core` **1251** (+7) · `zcrud_chat_syncfusion` **65** (+8) ·
jumelles inchangées : `zcrud_chat_kernel` 392, `zcrud_chat_study` 67 · **0 erreur, 0
avertissement**.

**R3 — 17 injections, 17 mordantes, toutes ROUGE-ASSERTION.** Intégrité (`sha256` + `diff -q`)
vérifiée **après chaque** injection et chaque retrait, pas seulement en fin de campagne.
🔵 **Une injection requalifiée** : R3-12 rendait un rouge de **COMPILATION** (une vue citant la
référence sans l'importer) — rejouée avec import, rouge d'**ASSERTION**. Un rouge de
compilation ne prouve rien.

**L'exemption nominative est prouvée portante** : 5 injections — un littéral (couleur **ou**
mot) placé dans le fichier **voisin** rougit ; ses deux cardinaux sont assertés ; et elle ne
couvre **que** les 2 règles de couleur, jamais les 5 règles AD-13.
🔵 Elle a été étendue à `z_chat_purity_test` — c'est **là** que vivent réellement les règles
anti-couleur du paquet, pas seulement dans la garde de rendu.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 8. Ce que nous savons ne pas avoir couvert

* **Aucun widget de chrome notebook n'est rendu par le socle** (composer, feuille d'outils,
  badges, indicateur) : pour ces familles, la référence est une **API de lecture** destinée à
  votre alignement, pas un rendu.
* La géométrie fine de la bulle appartient à Syncfusion : non mesurable de notre côté.
* Les canaux non chromatiques sont **exigés par le type**, non **rendus** : la garde est un
  contrat d'API, pas une mesure de pixels — nous le disons plutôt que d'écrire une garde sur
  un sujet non monté.
* Le `Checkbox` rond de la feuille d'outils n'est pas tranché.
* La modernisation du **mode Chat** (référence lex_douane) : chantier à venir, hors de ce lot.
* Dettes antérieures ouvertes : champ de recherche sous dégradé (v0.49.0), deux gardes inertes
  de `ZMindmapView` (v0.49.0), estampillage par carte en multi-sources (v0.51.0),
  `ZChatRequestBuilder` non élargi (v0.52.0, arbitrage mesuré).
