# Code-review — lentille **accessibilité / RTL / localisation / thème**

**Périmètre** : `zcrud_chat`, `zcrud_chat_syncfusion`, `zcrud_menu`, `zcrud_chat_kernel`,
et `ZItemActionsMenu` (`zcrud_study`) migré vers la couture de menu.
**Mode** : lecture seule du code de production. Toutes les sondes de mesure ont été
créées dans `test/` puis **supprimées** (`git status` des paquets inchangé à la fin).
**Date** : 2026-08-01.

---

## Verdict

**CHANGEMENTS REQUIS.** Le socle tient sa promesse sur la *forme* (aucune couleur
littérale, aucune variante directionnelle figée, `Semantics` réellement posées là où
IFFD en a zéro, harnais RTL correctement bâti sur `LocalizationsDelegate<WidgetsLocalizations>`).
Il la manque sur trois points **mesurés**, tous sur le chemin par défaut :

1. **12 clés de libellé sur 12** introduites par cette epic sont absentes des tables
   `en`/`fr` de `zcrud_core` — l'hôte non configuré voit la **clé brute à l'écran** ;
2. une réponse **sans texte** (tableau, sources, comparaison) est **totalement muette**
   pour un lecteur d'écran — la dette IFFD que ce paquet existe pour ne pas reproduire ;
3. deux invariants AD-13 sont **déclarés dans le code et démentis par la mesure** :
   double annonce dans la bande de pièces jointes, plancher 48 dp inopérant dans la
   grille de menu.

Le point commun des trois : **une garde existe, mais elle ne mesure pas le cas qui casse**.

---

## Méthode

Chaque affirmation ci-dessous est soit un **grep négatif montré**, soit une **mesure**
obtenue en exécutant une sonde `flutter test` depuis le dossier du paquet. Les sorties
brutes sont recopiées telles quelles.

---

## HIGH

### H-1 — 12 clés de libellé sur 12 rendent la **clé brute** chez un hôte non configuré

**Chemins** :
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:24-114` (table `_enLabels`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:116-206` (table `_frLabels`)
- clés déclarées : `packages/zcrud_chat/lib/src/presentation/view/z_chat_labels.dart:23-67`
  et `packages/zcrud_chat_syncfusion/lib/src/presentation/z_sf_assist_labels.dart:26-38`

**Règle violée** : FR-23 / FR-26 — la chaîne de résolution documentée en tête de
`z_chat_labels.dart:5-7` est « `ZcrudScope.labels` → delegate → **table `en` intégrée** →
clé brute ». Le maillon « table `en` intégrée » **n'existe pas** pour ces clés.

**Grep négatif** :

```
$ grep -rn "zchat\." packages/zcrud_core/ | wc -l
0
```

**Mesure** (sonde, hôte montant `ZcrudLocalizationsDelegate` en `fr`, sans `ZcrudLabels`) :

```
CLE zchat.showMore         -> "zchat.showMore"
CLE zchat.showLess         -> "zchat.showLess"
CLE zchat.sources          -> "zchat.sources"
CLE zchat.suggestions      -> "zchat.suggestions"
CLE zchat.diagram          -> "zchat.diagram"
CLE zchat.unsupportedBlock -> "zchat.unsupportedBlock"
CLE zchat.liveRegion       -> "zchat.liveRegion"
CLE zchat.streaming        -> "zchat.streaming"
CLE zchat.attachments      -> "zchat.attachments"
CLE zchat.removeAttachment -> "zchat.removeAttachment"
CLES BRUTES (10/10)
```

Les deux clés `zchat.sf.userAuthor` / `zchat.sf.assistantAuthor` sont dans le même cas
(même grep négatif) : **12 sur 12**. Le point de handoff signalé (« deux clés,
`zchat.attachments` et `zchat.removeAttachment` ») **sous-estime le problème d'un facteur 6**.

**Ce n'est pas seulement une étiquette sémantique** : deux de ces clés sont du **texte
visible**. Mesuré en montant `ZChatAttachmentStrip` :

```
TEXTE RENDU: "rapport.pdf"
TEXTE RENDU: "zchat.removeAttachment"
```

**Scénario d'échec** : DODLP (hôte GetX) branche `ZChatConversationView` sans alimenter
`ZcrudLabels`. Un utilisateur francophone voyant, joint un PDF : le bouton de retrait de
la vignette **affiche littéralement `zchat.removeAttachment`**, et le bouton de dépli d'une
réponse longue affiche `zchat.showMore`. Ce n'est pas une dégradation d'accessibilité,
c'est un défaut produit visible au premier écran.

**Sur l'arbitrage écrit en tête de `z_chat_labels.dart:9-15`** : refuser un repli
**français** codé en dur dans un socle multi-consommateurs est juste. Mais l'arbitrage
retenu n'était pas « ne rien livrer » : c'était « livrer par la table locale-aware du
delegate ». Livrer les 12 entrées dans `_enLabels` **et** `_frLabels` respecte
intégralement le raisonnement (aucun libellé figé dans le paquet de rendu, tout dans la
couche l10n locale-aware) et supprime le défaut. Le statu quo choisit l'option que le
dartdoc lui-même qualifie de « bruyante ».

**Correctif attendu** : ajouter les 12 entrées dans `_enLabels` et `_frLabels`, plus une
garde qui itère `kZChatLabelKeys ∪ kZSfAssistLabelKeys` et exige `label(ctx, k) != k`
(la surface exhaustive existe déjà, elle n'est simplement pas confrontée à la table).

---

## MAJEUR

### M-1 — Une réponse **sans texte** n'est annoncée **nulle part**

**Chemin** : `packages/zcrud_chat/lib/src/presentation/z_chat_controller.dart:585`
(`_settle`), et le pendant `:614` (`_fail` avec contenu partiel).

```dart
_liveAnnouncement.value = text;   // `text` = le SEUL texte streamé
```

**Règle violée** : AD-13 — « une réponse qui arrive en streaming doit être **annoncée** ».
C'est l'invariant que le dartdoc de `z_chat_conversation_view.dart:12-17` revendique
explicitement contre IFFD (« `Semantics` → 0 occurrence […] une réponse en streaming y est
**muette** »).

**Mesure** (sonde : le port de streaming n'émet **qu'un** `ZChatContentBlockEvent` portant
un `ZTableBlock`, aucun delta de texte) :

```
MESSAGES=2 blocs=1
ANNONCES=[]  valeur finale=""
accessibleText du kernel = "Droits de douane
A
1"
```

Le message **est rendu** (1 bloc). La région live, elle, **n'émet aucune annonce** :
`_liveAnnouncement` passe de `''` à `''`, et `ValueNotifier` supprime jusqu'à la
notification. Le lecteur d'écran n'apprend jamais que la réponse est arrivée.

Aggravant : **le correctif existe déjà dans le dépôt et n'est pas appelé ici**.
`zChatAccessibleTextOf` (`packages/zcrud_chat_kernel/lib/src/domain/z_content_block.dart:150`)
est un `switch` exhaustif sur l'union scellée, écrit précisément parce que le résumé local
de C6 « ne connaissait que `ZTextBlock` » (`z_content_block.dart:49-60`). Il est consommé
par la coquille Syncfusion (`z_sf_assist_shell_renderer.dart:157`) — **mais pas par la
région live du socle**, qui reproduit exactement le trou que le kernel a été écrit pour
boucher. Un hôte qui branche Syncfusion est mieux annoncé qu'un hôte sur le rendu neutre :
l'inverse de la promesse de non-perte.

**Pourquoi aucune garde ne l'a vu** : toutes les gardes de la région live utilisent une
réponse **purement textuelle** — `z_chat_sm1_test.dart:280` (`'x' * 100`),
`z_chat_token_lifecycle_test.dart:180` (`'ABCD'`). Et
`z_chat_render_guard_test.dart:388-395` ne vérifie la région live que par **grep de
source** (`expect(all, contains('liveRegion: true'))`), ce qui ne dit rien de ce qui est
annoncé. Aucun test n'exerce le cas « blocs sans texte ».

**Scénario d'échec** : lex_douane, utilisateur non-voyant sous TalkBack, question
« compare les taux TEC des positions 8703 et 8704 ». Le modèle répond par un
`ZComparisonTableBlock` sans phrase d'introduction. À l'écran : un tableau. Au casque :
**rien**. L'utilisateur croit que sa requête est restée sans réponse.

**Correctif attendu** : `_liveAnnouncement.value = zChatAccessibleTextOf(blocs du message
établi, resolver: …)` plutôt que `text` — même source de vérité que `AssistMessage.data`.

---

### M-2 — Double annonce du nom de fichier dans la bande de pièces jointes

**Chemin** : `packages/zcrud_chat/lib/src/presentation/view/z_chat_attachment_strip.dart:132-135`

```dart
return Semantics(
  label: attachment.fileName,      // ← pas d'excludeSemantics
  child: Row(children: [ … Text(attachment.fileName) … ]),
```

**Règle violée** : AD-13 — un `Semantics(label:)` qui n'exclut pas son sous-arbre fait
énoncer le libellé deux fois.

**Grep négatif** :

```
$ grep -rn "excludeSemantics" packages/zcrud_chat/lib
(aucune occurrence)
```

**Mesure** sur les données **fusionnées** (`getSemanticsData()`, ce que le lecteur énonce) :

```
NOEUD TEXTE nom fusionne=<rapport.pdf
rapport.pdf>
```

**Gravité aggravée par le contexte** : c'est **exactement** le défaut que le paquet voisin
documente et corrige, avec le même vocabulaire, à
`packages/zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:73-76` — « Sans cette
exclusion, le libellé de ce nœud ET celui du `Text` enfant sont tous deux annoncés
(“Ouvrir\nOuvrir”, mesuré SU-8/AC20) ». La leçon a été payée dans `zcrud_menu`, écrite
noir sur blanc, et **non propagée** au widget de `zcrud_chat` écrit dans la même epic.

**Scénario d'échec** : IFFD, utilisateur sous VoiceOver (iOS), joint trois documents à sa
question. En balayant la bande il entend « rapport.pdf rapport.pdf », « annexe.pdf
annexe.pdf », « decision.pdf decision.pdf » — six énoncés pour trois fichiers, dans une
bande horizontale déjà difficile à parcourir au doigt.

**Correctif attendu** : `excludeSemantics: true` sur le `Semantics` de `_ZAttachmentChip`
— avec la précaution notée dans `z_menu_entry_tile.dart:75` : le bouton de retrait est
**dans** ce sous-arbre, il faut donc soit sortir `_ZRemoveButton` du nœud exclu, soit
n'exclure que la portion « nom + vignette ». Une exclusion posée naïvement rendrait le
bouton de retrait **inatteignable** au lecteur d'écran : le remède serait pire.

---

### M-3 — Le plancher 48 dp de `ZMenuEntryTile` est **inopérant** dans la disposition qu'il cible

**Chemin** : `packages/zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:77-81`

```dart
child: ConstrainedBox(
  constraints: const BoxConstraints(
    minWidth: kZMenuMinTapTarget,
    minHeight: kZMenuMinTapTarget,
  ),
```

**Règle violée** : AD-13 / NFR-S6 — cibles ≥ 48 dp. Un `ConstrainedBox` applique
`constraints.enforce(contraintes du parent)` : sous une contrainte **serrée**, son minimum
est écrasé. Or la disposition explicitement visée par le dartdoc du fichier (`:7-11`) est
une **grille à `childAspectRatio`**, qui impose précisément des contraintes serrées.

**Mesure** (sonde reproduisant `folder_actions_menu_zcrud.dart:_grid` d'IFFD : 2 colonnes,
`childAspectRatio: 3.5`) :

```
CELLULE GRILLE size=Size(100.0, 28.6)
```

**28,6 dp** — soit 60 % de la cible. À titre de contrôle, la même tuile sous contraintes
lâches mesure bien `Size(160.0, 48.0)`, et son libellé fusionné est bien unique
(`<Ouvrir>`, `excludeSemantics: true` fonctionne). Le défaut est **spécifique à la
contrainte serrée**, c'est-à-dire au seul chemin pour lequel le widget a été écrit.

**Pourquoi la garde ne le voit pas** : `packages/zcrud_menu/test/z_menu_a11y_rtl_test.dart:128-146`
mesure la tuile **uniquement à l'intérieur d'un `PopupMenuItem`** — un ancêtre Material
qui impose déjà son propre plancher `kMinInteractiveDimension` (48 dp). La garde mesure
donc le plancher de Material, pas celui de la tuile. C'est le piège annoncé, et il est
présent tel quel.

**Conséquence de contrat** : `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:25-27`
annonce à l'hôte que « le renoncement a11y du slot est levé » grâce à `ZMenuEntryTile`.
Pour le chemin `menuBuilder` en grille — **le cas nommément cité** — c'est faux. Selon la
règle « handoffs » du dépôt, c'est le type d'affirmation qui doit être qualifiée ou retirée.

**Scénario d'échec** : IFFD, utilisateur âgé, tremblement essentiel, menu d'actions d'un
dossier rendu en grille 2 × 6. Les cellules font 28,6 dp de haut : il vise « Renommer » et
déclenche « Supprimer » (cellule adjacente). Exactement l'incident que le plancher 48 dp
prévient.

**Correctif attendu** : le plancher ne peut pas être porté par un `ConstrainedBox` seul.
Deux voies : (a) `SizedBox(height: max(intrinsèque, kZMenuMinTapTarget))` via
`ConstrainedBox` **plus** un `UnconstrainedBox(constrainedAxis: Axis.horizontal)` pour
échapper à la hauteur serrée ; (b) plus simplement, **ne pas prétendre** garantir le
plancher sous contrainte serrée et documenter que l'hôte doit dimensionner sa grille
(`mainAxisExtent: kZMenuMinTapTarget` au lieu de `childAspectRatio`), en ajoutant une
garde `debugAssert` ou un test qui **mesure la grille**. Dans les deux cas, la garde
actuelle doit être doublée d'une mesure **hors** `PopupMenuItem`.

---

## MEDIUM

### D-1 — La région live énonce la réponse intégrale, en permanence, en plus des tuiles

**Chemin** : `packages/zcrud_chat/lib/src/presentation/view/z_chat_conversation_view.dart:200-207`

```dart
return Semantics(
  container: true,
  liveRegion: true,
  label: text.isEmpty ? label(context, kZChatLabelLiveRegion) : text,
  child: child,
);
```

`text` vaut la **totalité** du texte de la dernière réponse
(`z_chat_controller.dart:585`), et n'est **jamais** remis à vide après annonce (seul
`attach()` le réinitialise, `:358`). Conséquences cumulées :

* le nœud conteneur de la liste porte durablement, comme nom accessible, l'intégralité de
  la dernière réponse — chaque fois que l'utilisateur entre dans la liste, il se la
  reprend en entier avant d'atteindre le premier message ;
* le contenu est ensuite **relu** message par message : deux énoncés pour un contenu ;
* le `label` n'est pas exclusif du sous-arbre (`container: true` sans exclusion).

**Scénario** : lex_douane, TalkBack, réponse de 1 800 caractères. L'utilisateur veut
relire le 3ᵉ paragraphe : chaque entrée dans la liste rejoue les 1 800 caractères depuis le
début. Il n'a aucun moyen de couper autrement qu'en quittant l'écran.

**Piste** : annoncer un résumé borné (ou un jalon « réponse reçue, N blocs ») et remettre
`_liveAnnouncement` à `''` après consommation, plutôt que de laisser le corps de la
réponse en nom accessible permanent d'un conteneur.

### D-2 — Slug de nom de fichier ASCII-only : perte totale pour un hôte non-latin

**Chemins** : `packages/zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:270-274`,
garde qui le fige : `packages/zcrud_chat/test/z_chat_export_test.dart:610-616`.

```dart
final String slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_') …
```

`« Étude № 4 » → « tude_4 »` est assumé au titre de la parité avec lex. Le cas non traité
est plus grave : un titre **entièrement** non-latin (arabe, cyrillique, chinois, grec,
hébreu) produit un slug **vide**, donc le repli `conversation`. Un hôte arabophone qui
exporte dix conversations obtient dix fichiers nommés `conversation.html` —
indiscernables dans le gestionnaire de fichiers et écrasés les uns par les autres au
téléchargement.

« Parité avec lex » justifie de ne pas *améliorer* ; elle ne justifie pas de **figer par
une garde** un comportement dont le socle, contrairement à lex, a des consommateurs
multi-locales déclarés. Au minimum : élargir la classe à `\p{L}\p{N}` (`unicode: true`) en
conservant `_` comme séparateur, ou faire du repli un discriminant (horodatage) plutôt
qu'une constante.

### D-3 — HTML exporté sans `lang` ni `dir`

**Chemin** : `packages/zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:458-468`

```dart
..writeln('<html><head><meta charset="utf-8">')
```

Le document exporté est un artefact rendu : AD-13 s'y applique. Sans `dir="rtl"`, une
conversation arabe exportée en HTML s'ouvre en LTR dans le navigateur — ponctuation en
fin de ligne du mauvais côté, listes alignées à gauche. Sans `lang`, un lecteur d'écran de
bureau lit le document avec la voix de la locale système.

Le vocabulaire d'export porte déjà la langue implicitement (`ZChatExportVocabulary`) : y
ajouter `languageTag` et `textDirection` est additif et non cassant.

### D-4 — Deux mécanismes de localisation dans le même paquet

**Chemin** : `packages/zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:94-130`

`ZChatExportVocabulary` est injecté **par constructeur** ; `kZChatLabelSources` est résolu
par `label(context, clé)`. Les deux portent le mot « sources ».

**Le motif est valable** : `ZChatExportService` est pur-Dart, sans `BuildContext`, et le
même arbitrage a été retenu — correctement — pour `ZAccessibleTextResolver` dans le
kernel. Ce n'est donc pas une dette de conception.

**La dette est ailleurs** : rien ne relie les deux surfaces. Un hôte peut traduire
`zchat.sources` en « Références juridiques » et laisser `vocabulary.sources` sur le jeton
`sources` par défaut, produisant un écran et un export qui se contredisent, **sans qu'aucune
garde ne rougisse**. À consigner explicitement dans le handoff (« si vous alimentez
`ZcrudLabels`, alimentez aussi `ZChatExportVocabulary` — voici la table de correspondance »),
et idéalement à couvrir par une garde de cohérence côté hôte.

### D-5 — `zcrud_menu` n'a **aucune** garde « aucune chaîne d'interface en dur »

**Chemins** : `packages/zcrud_menu/test/z_menu_purity_test.dart:118` — la seule garde
FR-26 du paquet porte sur les **couleurs** littérales.

Comparaison des trois paquets sur la règle « aucune chaîne en dur » :

| Paquet | Forme appliquée | Où |
|---|---|---|
| `zcrud_chat` | **forte** — « aucun littéral **porteur de mot**, où qu'il soit », balayage manuel plutôt que regex | `test/z_chat_render_guard_test.dart:71-81`, `:243-284` |
| `zcrud_chat_syncfusion` | **faible + forte** — `RegExp(r"Text\(\s*['\"]")` (`:172`) doublée de `wordBearing` (`:224`) | `test/z_sf_purity_guard_test.dart` |
| `zcrud_menu` | **aucune** | — |

`zcrud_chat` a explicitement diagnostiqué et corrigé l'aveuglement de la forme faible
(`z_chat_render_guard_test.dart:53-71` : « le littéral est sur la ligne suivante […] une
regex de littéral Dart n'est pas décidable »). `zcrud_chat_syncfusion` a suivi.
`zcrud_menu` n'a pas été rattrapé.

**État actuel : sans faute**, et je le prouve —

```
$ grep -rnE "Text\(\s*['\"]" packages/zcrud_menu/lib | wc -l
0
```

C'est donc une lacune de **filet**, pas un défaut de code : `zcrud_menu` reçoit tous ses
libellés de l'appelant (`ZMenuEntry.label`, `ZMenuTrigger.semanticLabel`). Mais c'est
justement le paquet où un futur repli (« Fermer », « Plus d'actions ») serait le plus
tentant à écrire en dur, et rien ne l'arrêterait.

---

## LOW

### L-1 — Deux gardes a11y de `zcrud_chat` ne mesurent rien

* `packages/zcrud_chat/test/z_chat_render_guard_test.dart:399-401` :
  `expect(kZChatMinTapTarget, greaterThanOrEqualTo(48.0))` — une constante comparée à
  elle-même. Elle ne rougirait pas si **tous** les widgets cessaient d'appliquer le
  plancher. La vraie mesure existe ailleurs (`z_chat_shell_seam_test.dart:336-362`,
  `z_chat_attachment_test.dart:365-375`) : celle-ci ne fait qu'ajouter du vert.
* `:388-395` : la région live est vérifiée par **grep de source**
  (`contains('liveRegion: true')`). Le défaut M-1 démontre ce que cette forme laisse
  passer : l'annotation est bien présente, et pourtant rien n'est annoncé.

### L-2 — Le niveau d'alerte est annoncé en donnée brute

`packages/zcrud_chat/lib/src/presentation/view/z_chat_block_view.dart:112-116` :
`Semantics(label: block.level)`. Mesuré : `NOEUD <Attention> fusionne=<warning | Attention>`.
Un francophone entend « warning ». L'arbitrage est documenté et défendable (`level` est une
`String` ouverte de l'hôte, le socle ne peut pas inventer sa table), mais l'hôte doit être
prévenu qu'il lui revient de fournir des `level` localisés ou un renderer de bloc — ce que
le handoff ne dit pas.

### L-3 — Aucun test de traversée sémantique complète

Aucune garde du périmètre ne parcourt l'arbre sémantique **entier** d'une conversation
rendue pour vérifier qu'aucun nœud n'est muet ou dupliqué ; les gardes ciblent des nœuds
connus un par un. C'est précisément pourquoi M-2 (double annonce dans la bande) a survécu
alors que le défaut jumeau était traité dans `zcrud_menu`.

---

## Ce qui est **conforme** — vérifié, pas supposé

Ces points sont crédités parce qu'ils ont été mesurés ou prouvés par grep, pas parce que
le dartdoc les affirme.

**Directionnalité (AD-13)** — aucune variante figée dans les quatre paquets de rendu :

```
$ grep -rn "EdgeInsets\.only\|Alignment\.center(Left|Right)\|Positioned(\|TextAlign\.(left|right)" \
    packages/zcrud_chat/lib packages/zcrud_chat_syncfusion/lib packages/zcrud_menu/lib
packages/zcrud_chat/lib/.../z_chat_attachment_strip.dart:148:  // AD-13 : jamais `TextAlign.left`.
packages/zcrud_menu/lib/.../z_menu_entry_tile.dart:92:  // AD-13 : jamais `TextAlign.left`/`right` …
```

Les deux seules occurrences sont des **commentaires** expliquant l'interdit. Usages
positifs : `EdgeInsetsDirectional` (`z_chat_attachment_strip.dart:89,97`),
`AlignmentDirectional` (`z_chat_message_tile.dart:200`, `z_chat_conversation_view.dart:245`,
`z_chat_attachment_strip.dart:180`), `TextAlign.start` partout,
`Table(textDirection: Directionality.of(context))` (`z_chat_block_view.dart:278`) — ce
dernier est le détail que la plupart des socles ratent.

**Thème (FR-26)** — aucune couleur littérale :

```
$ grep -rnE "Colors\.[a-z]|Color\(0x" \
    packages/zcrud_chat/lib packages/zcrud_menu/lib packages/zcrud_chat_syncfusion/lib | wc -l
0
```

`_ZNeutralBox` (`z_chat_block_view.dart:230-241`) va jusqu'à **ne pas dessiner de bordure**
quand le thème n'en fournit pas, plutôt qu'inventer un noir de repli. C'est la bonne
lecture de la règle.

**Le piège RTL de l'`Overlay` est traité correctement.**
`packages/zcrud_menu/test/z_menu_a11y_rtl_test.dart:20-51` documente le faux positif
(un `Directionality` sous `MaterialApp` ne touche pas la surface flottante du menu, « la
première version mesurait un glyphe à dx = 400 contre un libellé à dx = 504 en “RTL” »)
et impose la direction par un `LocalizationsDelegate<WidgetsLocalizations>`. La mesure de
position (`dxIcone > dxLabel`) est la bonne. **Rien à redire — c'est un modèle à propager
aux tests RTL de `zcrud_chat`, qui n'en ont pas d'équivalent pour une surface flottante.**

**Double annonce : le cas du menu est bien réglé.** Mesuré sur les données fusionnées,
tuile isolée : `TUILE SEULE label fusionne=<Ouvrir>` — un seul énoncé. C'est M-2 qui est
l'exception, pas la règle du dépôt.

**`zcrud_chat_kernel`** : aucun `Semantics`, aucune couleur, aucune chaîne d'interface —
et c'est correct : le paquet est pur-Dart, il ne rend rien. L'arbitrage de localisation
(`z_content_block.dart:62-75` : `accessibleText` n'émet que de la donnée et de la
ponctuation, la l10n passe par `ZAccessibleTextResolver`) est le bon, et il est appliqué.
Le reproche de M-1 n'est pas au kernel : c'est que `zcrud_chat` ne consomme pas ce que le
kernel lui offre.

---

## Récapitulatif

| # | Sév. | Chemin:ligne | Défaut |
|---|---|---|---|
| H-1 | **HIGH** | `zcrud_core/lib/src/presentation/l10n/z_localizations.dart:24-114` | 12/12 clés `zchat.*` absentes des tables `en`/`fr` ⇒ clé brute **affichée** |
| M-1 | **MAJEUR** | `zcrud_chat/lib/src/presentation/z_chat_controller.dart:585` | réponse sans texte ⇒ **zéro** annonce (`zChatAccessibleTextOf` non appelé) |
| M-2 | **MAJEUR** | `zcrud_chat/lib/src/presentation/view/z_chat_attachment_strip.dart:132-135` | double annonce du nom de fichier (`excludeSemantics` absent) |
| M-3 | **MAJEUR** | `zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:77-81` | plancher 48 dp écrasé en grille — mesuré **28,6 dp** |
| D-1 | MEDIUM | `zcrud_chat/lib/src/presentation/view/z_chat_conversation_view.dart:200-207` | réponse intégrale en nom accessible permanent du conteneur |
| D-2 | MEDIUM | `zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:270-274` | slug ASCII-only ⇒ vide pour un titre non-latin |
| D-3 | MEDIUM | `zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:458-468` | HTML exporté sans `lang` ni `dir` |
| D-4 | MEDIUM | `zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:94-130` | deux mécanismes de l10n non reliés, divergence non gardée |
| D-5 | MEDIUM | `zcrud_menu/test/z_menu_purity_test.dart:118` | aucune garde « chaîne en dur » (état actuel sans faute) |
| L-1 | LOW | `zcrud_chat/test/z_chat_render_guard_test.dart:399-401`, `:388-395` | gardes a11y tautologiques / par grep de source |
| L-2 | LOW | `zcrud_chat/lib/src/presentation/view/z_chat_block_view.dart:112-116` | niveau d'alerte annoncé en donnée brute non traduite |
| L-3 | LOW | — | aucune traversée sémantique complète d'une conversation rendue |

**Décompte demandé — clés de libellé non traduites : 12 sur 12**
(10 × `zchat.*` + 2 × `zchat.sf.*`), aucune présente dans `_enLabels` ni `_frLabels`.

---

## Note de méthode sur cette revue

Une lecture initiale du fichier `packages/zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart`
m'a présenté un contenu (`minHeight: 0.0`, `excludeSemantics: false`) **contredit** par la
vérification directe sur disque (`grep` + `md5sum` + `stat`, fichier inchangé depuis
14:11:13) et par la mesure (`TUILE SEULE size=Size(160.0, 48.0)`, label fusionné unique).
**Le code de production ne présente pas ces deux défauts** ; ils ne figurent pas dans ce
rapport. Le finding M-3 a été retenu parce qu'il est reproductible sur le code réel, et il
n'a été trouvé que parce que la mesure a été faite au lieu d'être déduite du dartdoc.
Signalé pour que le lecteur sache pourquoi ces deux points, qu'on pourrait s'attendre à
voir listés, ne le sont pas.
