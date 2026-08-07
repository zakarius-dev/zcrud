# Handoff **v0.55.0** — CR-IFFD-73 + 74 : le rendu riche existe, l'option choisie se voit

> **Tag à épingler : `v0.55.0`** · strictement additif, aucune rupture d'API.
> **37ᵉ paquet** : `zcrud_chat_markdown` — la ligne vide de la table des implémentations
> a désormais son paquet. ⚠️ Consommateurs en dépendance git : ajoutez-le à vos
> `dependency_overrides` (recette mise à jour, `docs/private-git-consumption.md`).

---

## 1. CR-IFFD-73 — `zcrud_chat_markdown`

Votre lecture était juste : la couture était offerte et **vide**. Elle est remplie —
`ZChatMarkdownRenderer` implémente `ZChatRenderer` en s'adossant à `zcrud_markdown`, isolant
Quill **exactement** comme `zcrud_list` isole Syncfusion. Surface : **3 symboles**, ~90 lignes.
🔵 **Le port n'a pas eu besoin d'évoluer** : `isStreaming` + `streamingText` + `message.role`
suffisaient exactement. La couture était bien dessinée.

### Le streaming — votre « vrai sujet technique », mesuré

1. **Pas de casse** : 21 fragments tronqués aux endroits qui font mal + fuzz de 66 décodages ⇒
   **0 throw**, le texte n'est jamais mangé (AD-10).
2. **Mais l'artefact clignote, capturé** : sur `Le **commerce** est *libre*`, à 14 caractères le
   rendu est **italique** avec un astérisque orphelin, et bascule en **gras** un caractère plus
   tard.
3. **Coût mesuré** : ~10,8 ms par fragment en cycle complet, et le re-parse croît avec la
   longueur ⇒ **cumul quadratique** sur un long message.

⇒ **Défaut retenu : neutre pendant le flux, riche à la complétion.** Le rendu progressif reste
fluide (c'est le chemin neutre existant, granulaire), et le riche arrive sans clignotement.
`richWhileStreaming` reste **offert** pour qui préfère l'inverse, gardé.

### Périmètre et deux décisions à connaître

* `ZTextBlock` est le **seul kind produit** par le dépôt (grep montré) : les autres kinds
  **déclinent** proprement — rendu prouvé identique avec/sans satellite. Décliner Mermaid
  **préserve la donnée** (le rendre en Markdown mangerait ses flèches).
* 🔵 **Le texte de l'utilisateur reste littéral** (défaut `roles` = tout sauf `user`) : manger
  ses astérisques serait une perte silencieuse sur la seule donnée dont il connaît la forme.
* **LaTeX** : pont déclaré par défaut. CR-IFFD-69 est un défaut d'**encodage**, hors d'atteinte
  d'un décodeur. Mesuré : `5$ a 9$`, `250$ CAD`, `$5 et $9` restent du texte.

### 🔴 Défaut préexistant trouvé et corrigé — il vous concernait déjà

Monter `ZMarkdownReader` sur un texte contenant `***` (ou `---`, `___`) produisait
**`UnimplementedError` + `RenderErrorBox`** : `ZMarkdownCodec` produit un embed `divider`
qu'**aucun builder ne savait rendre** — sur toutes les voies rich-text, pas seulement le chat.
Invisible jusqu'ici parce que les gardes éprouvaient le codec, jamais le rendu de ce qu'il
produit. Corrigé en deux moitiés : `ZDividerEmbedBuilder` + `unknownEmbedBuilder` sur les
3 configs — la **classe** de défaut est fermée, pas seulement l'instance.

## 2. CR-IFFD-74 — l'option choisie se voit

Votre formulation était exacte : le canal visuel n'avait pas été ajouté, il avait été
**remplacé**. Corrigé sur **les 5 familles** (une seule primitive, 10 sites — vérifié) :

* **Canal : graisse `w700` + soulignement, zéro couleur.** Écarté par la mesure, pas par goût :
  les jetons couleur de `ZcrudTheme` sont `Color?` **sans défaut** — un canal coloré serait
  absent par défaut, le défaut même de votre CR ; et `material.dart` est banni du paquet, donc
  aucun `ColorScheme` n'y est atteignable.
* **Deux canaux parce qu'un seul s'annule** : une graisse seule disparaît sous un
  `DefaultTextStyle` ambiant gras (mesuré). Cas extrême fermé : si l'ambiant porte déjà les
  deux, le soulignement est retiré des options **non** choisies.
* **La sémantique est intacte et INDÉPENDANTE** : réinjecter le `Text` nu laisse la garde
  sémantique verte ; retirer `selected:` la fait rougir.
* **Votre « non mesuré » n°1, tranché par instrumentation** : le geste **portait déjà**
  (`toggleCorpusKey` et les 4 autres verbes, un tap ⇒ un geste). C'était bien « il porte sans
  retour ».
* **Sombre** : même différence dans les deux luminosités, invariance mesurée.
* La règle que votre CR formule est **inscrite au dartdoc** : un état doit être perceptible par
  au moins un canal **visible** — le symétrique d'AD-13 qui manquait.

### 🔵 Le même défaut existe ailleurs — non corrigé, à votre arbitrage
**`ZChatConversationTile`** : `isSelected` n'alimente que `Semantics`, aucun canal visible
(grep montré). Non corrigé **à dessein** : dans une liste, la sélection est souvent déjà peinte
par l'hôte — une addition socle s'additionnerait à votre compensation (le piège du handoff
v0.22.0). **Candidate CR** si vous la voulez ; dites-nous ce que votre câblage peint déjà.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | ajoutez `zcrud_chat_markdown` à vos overrides (recette § mise à jour), montez `ZChatMarkdownRenderer` sur le Notebook ; la feuille de réglages se corrige **sans geste** |
| **hôte passif du chat** | rien — le satellite est **opt-in prouvé** (fermetures sans Quill vérifiées), et le retour visible de sélection est le nouveau défaut de la feuille |
| **hôte ayant compensé** l'absence de retour visible (builder de tuile custom) | votre builder **prime toujours** — mais vous pouvez le retirer, le défaut est désormais correct |
| **hôte affichant du texte avec `---`/`***`** | 🟢 le crash `divider` est corrigé — si vous l'aviez contourné en amont, retirez le contournement |

🟢 **Tripwire recommandé** : un test qui monte votre Notebook avec le satellite et affirme que
`**gras**` est peint gras à la complétion — il rougira si le renderer saute de votre scope.

## 4. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** — ⚠️ il a d'abord **rougi à bon droit** :
le gate de recette de consommation a refusé le 37ᵉ paquet absent de
`docs/private-git-consumption.md` (exactement la friction F2 que DODLP signalait — le gate
existe et mord) ; recette complétée, gate vert · `melos generate` RC=0.

`zcrud_chat_markdown` **57** · `zcrud_markdown` **504** (+10) · `zcrud_chat` **434** (+28) ·
jumelles : kernel 392, study 67, syncfusion 65 · `zcrud_core` 1323 · **0 erreur,
0 avertissement**.

**R3 — 26 injections (13 + 13), toutes ROUGE-ASSERTION**, restaurations par copie, `sha256`
vérifié après chaque injection, aucun résidu (greps montrés).

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications locales.

## 5. Ce que nous savons ne pas avoir couvert

* **Coût de Quill en binaire** et coût du rendu sur appareil réel : non chiffrés (votre
  « non mesuré » reste ouvert).
* **Rendu Mermaid** : décliné, données préservées — surface future si besoin.
* `ZMarkdownReader` : deux défauts **préexistants** relevés, non corrigés — `_codec` en
  `late final` (changer le codec d'un widget remonté est silencieusement sans effet ;
  contourné par `ValueKey` côté satellite) et `placeholder: 'Aucun contenu'` en dur (FR-26).
* `ZMarkdownCodec` n'active pas GFM `TableSyntax` (limite héritée, délibérée).
* Jetons `chatSelectedEmphasisWeight`/`chatSelectedEmphasisDecoration` à poser dans
  `zcrud_core` (la chaîne paramètre > référence fonctionne en attendant).
* Dettes antérieures : cf. v0.54.1.
