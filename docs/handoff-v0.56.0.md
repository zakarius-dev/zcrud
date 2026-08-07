# Handoff **v0.56.0** — le composer atteint la parité lex 8/8, la feuille de réglages devient complète

> **Tag à épingler : `v0.56.0`** · strictement additif · **38ᵉ paquet** : `zcrud_chat_material`
> (builders Material pixel-perfect, opt-in). Consommateurs git : la recette
> (`docs/private-git-consumption.md`) liste les 38 — ajoutez `zcrud_chat_material` à vos
> overrides si votre graphe l'atteint.
> Chantier arbitré par le propriétaire : **le composer lex est la référence** du mode Chat,
> visuellement et fonctionnellement ; la feuille fusionne **le meilleur des deux apps**.

---

## 1. Pour lex_douane — votre composer est devenu la référence du socle

`ZChatComposerReference` : **31 constantes relevées dans votre code, ligne à ligne** (conteneur
radius 12, champ 1..5 lignes, FAB 48 dp + scale 0.7→1.0/150 ms, chips avatar 24/radius 12,
badges radius 8, breakpoint 400, placeholder animé 4 s/900 ms/350 ms), plus vos **3 hex
d'effort** sous exception FR-26 encadrée (centralisés, remplaçables par paramètre ET jeton,
exemption nominative).

### 🔴 Quatre de vos défauts n'ont PAS été reproduits
* vos **4 cibles < 48 dp** — le plancher du socle est écrêté et **inexprimable à contourner**
  (un jeton à 40 rend 48) ;
* votre `Positioned(right:)` — tout est directionnel ;
* votre placeholder animé **sans garde Reduce-Motion** — chez nous, Reduce-Motion ⇒ **aucun
  Timer créé** (mesuré, pas simulé : une première garde était verte alors qu'un minuteur
  tournait derrière un rendu statique — démasquée par injection, corrigée **par design**) ;
* votre **mode édition perd le brouillon en cours — deux fois** : le socle le **restitue** à la
  fermeture de la session d'édition.

### La parité fonctionnelle est à 8/8
Les 8 mécanismes de votre `ChatInputController` sont couverts : 6 l'étaient par les créneaux,
et les 2 restants sont livrés — **mode édition** (`startEditing`/`cancelEditing`, soumission
par `runAction(ZChatEditAction)` avec confirmation et impact, `send()` **refuse** pendant
l'édition — jamais de double-stream) et **brouillon à compteur** (`seedDraft`, qui signale même
à texte identique — la raison d'être de votre `draftSuggestionSeq`). G-CH1 a été **rougie puis
étendue avec motif daté** : +5 membres, tous écrivant par le site unique gardé.

## 2. La feuille de réglages — « le plus complet possible » (arbitrage owner)

**T3 — le contrat d'abord** : `ZChatGenerationSettings` gagne `webSearch` (typé parce que **vos
deux backends le lisent** — vérifié ligne à ligne chez lex et IFFD) et un canal de **capacités
booléennes OUVERTES** (clés opaques — une app future ajoute « résumé » sans toucher le kernel).
Et le pendant de `corpusScope.audit()` : **`auditCapabilities(écho)`** — sans écho, tout ce qui
est exprimé est `unhonored`. **Le silence n'est jamais un succès.**

**T1 — la forme lex** : en-tête titre + reset + close (gated sur `onClose` — hôte passif :
arbre inchangé, mesuré), échelle de budget **labellisée**, **filtres à 2 niveaux** sur le
catalogue de corpus (désélection parent ⇒ clés d'enfants retirées ; entrée désactivée ⇒
sémantique + italique, jamais couleur seule), tuiles génériques publiques (échelle discrète,
capacités), compteur `activeCount`.

**T2 — préréglages à mémoire** : `applyPreset`/`clearPreset`/snapshot-restore sur le
contrôleur de réglages (votre `preExpertToolsContext` généralisé — hors G-CH1). Prouvé
**non vacant** : restitution exacte entre deux états différents.

🔵 **Un repli muet évité au raccord** : le `_with` du contrôleur nommait ses champs un à un —
tout geste d'axe aurait **effacé silencieusement** les capacités. Trouvé, corrigé, gardé.

🔵 **IFFD, votre contre-modèle a servi** : le `setAiExpert` qui écrase 13 réglages, le rebuild
global et les couleurs en dur ont été documentés comme ce que la fusion ne reproduit pas.

## 3. `zcrud_chat_material` — le pixel-perfect en satellite

FAB d'envoi, chips d'effort (`ChoiceChip`, accents par la chaîne du chrome — **aucun hex dans
le satellite**, garde d'exemption-zéro), badges, chips de pièces jointes (la chip **entière**
retire — votre cible de 20 dp est inexprimable), slider de budget Material. Chaque builder est
indépendant (AD-4), le paquet est un **puits** prouvé (aucune arête entrante, zéro dépendance
tierce — Material vient du SDK), opt-in par fermetures vérifiées.

🔵 Une garde vacante y a été démasquée **avant livraison** : la mesure de cible lisait le 48
**ambiant** du SDK (padding de `ChoiceChip`), pas le plancher du socle — verte sans lui.
Corrigée (mesure sous `shrinkWrap`), campagne R3 entièrement rejouée.

## 4. Les 10 jetons de thème

8 du composer + 2 de CR-74 (`chatSelectedEmphasisWeight`/`Decoration`), 4 sites chacun,
maillons branchés. Trois décisions de `lerp` à connaître : les **échelles** du FAB sont des
planchers (0 = glyphe invisible — une valeur invalide, pas une absence) ; le **breakpoint**
est **discret à t<.5** (leçon v0.54.1) ; et un helper `_lerpNullableFontWeight` est né parce
que `FontWeight.lerp` standard aurait fait **disparaître la sélection visible** en transition
de thème.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **lex_douane** | rien d'obligatoire — le socle vous a rejoint. À l'adoption : vos 4 cibles < 48 dp et la perte de brouillon sont corrigées côté socle ; **retirez vos compensations** si vous en aviez. `ThinkingToggle`/`WebSearchToggle` sont **morts chez vous** (remplacés par les chips) — ne les portez pas |
| **IFFD** | la feuille complète vous arrive sans geste ; vos corpus passent par le catalogue à 2 niveaux ; `webSearch` est typé (votre backend le lit déjà) |
| **hôte passif** | rien — en-tête gated, satellite opt-in, tous les défauts inchangés (gardés) |
| **hôte voulant le pixel-perfect** | montez les builders de `zcrud_chat_material` sur les créneaux — un, plusieurs ou aucun |

🟢 **Tripwire recommandé** (lex) : un test qui affirme votre restitution de brouillon **maison**
si vous en aviez une — il rougira quand vous adopterez celle du socle.

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (38 paquets, recette de consommation à
jour — le gate qui l'exige a mordu au paquet précédent, il est vert) · `melos generate` RC=0.

`zcrud_chat` **484** (+50 depuis v0.55.0) · `zcrud_chat_kernel` **411** (+19) · `zcrud_core`
**1336** (+13) · `zcrud_chat_material` **39** (nouveau) · jumelles : study 67, syncfusion 65,
markdown 57 · **0 erreur, 0 avertissement**.

**R3 — 43 injections (6 + 13 + 12 + 12), toutes ROUGE-ASSERTION** ; restaurations par copie,
`sha256` après chaque pas, résidus : greps négatifs montrés. **Deux gardes vacantes démasquées
par les agents sur leur propre travail** (le Timer masqué, le 48 ambiant du SDK).

⚠️ Notre CI reste à l'arrêt (facturation) : vérifications locales uniquement — l'état commité
a été re-mesuré après commit (règle v0.54.1).

## 7. Non couvert

* Trois valeurs de chips sans niveau paramètre/jeton dédié (repli référence — mineur, listé).
* Pas de verbe d'**annulation de stream** sur `ZChatComposerSlot` (état « stop » du FAB non
  simulable) — candidat lot.
* Menu `+` des pickers, bandeau d'édition Material, pouls d'opacité du placeholder (exigerait
  une animation en primitive socle).
* Écho **typé** des capacités côté réponse (`auditCapabilities` accepte l'écho d'où qu'il
  vienne ; la carte de réponse ne type que le mesuré serveur).
* Tri-état « couper » sur la tuile de capacités (exprimable par `setCapability`, non rendu).
* Dettes antérieures : cf. v0.55.0.
