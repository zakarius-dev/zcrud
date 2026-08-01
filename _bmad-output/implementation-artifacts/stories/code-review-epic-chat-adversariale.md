# Code-review Epic CHAT — lentille **adversariale + réalité du code**

Date : 2026-08-01 · Revue **en lecture seule** (aucun fichier de code modifié, aucun gate global joué).
Périmètre : `zcrud_chat_kernel`, `zcrud_chat`, `zcrud_chat_syncfusion`, `zcrud_menu`, `zcrud_study`,
`zcrud_core`. Sources externes lues en **lecture seule stricte** : `/home/zakarius/DEV/iffd`,
`/home/zakarius/DEV/lex_douane`, `/home/zakarius/DEV/smart_learn_cloudfunctions`, et le paquet
`syncfusion_flutter_chat-34.1.31` du pub-cache (version réellement résolue dans `pubspec.lock:1870`).

**Règle appliquée sans exception** : toute « absence » affirmée ici est adossée à un **grep négatif
reproduit dans le texte**. Aucun rapport de lot n'a été pris pour une preuve.

---

## Verdict

**Le socle CHAT est, à cette date, une SPÉCIFICATION EXÉCUTABLE, pas une fonctionnalité.**
Il est structurellement soigné — le contrat d'action, la couture par bloc, la couture de coquille et
la boucle de reprise du contrôleur sont solides et, sur plusieurs points que j'ai cherché à
contredire, ils **tiennent**. Mais trois choses ne sont pas ce que le sprint-status affirme :

1. **aucun hôte ne peut rien en faire sans écrire l'intégralité des adaptateurs** (0 implémenteur
   réel sur 8 des 10 ports, `example/` compris) ;
2. **le dispositif d'accessibilité livré par CHAT-3b n'a aucun effet observable** sur le chemin
   Syncfusion, et ses deux gardes ne mesurent pas ce qu'elles annoncent ;
3. **tous les libellés du chat sortent en clé brute** chez un hôte non configuré, pas « deux ».

Décompte : **2 HIGH · 5 MAJEUR · 4 MEDIUM · 3 LOW** · **6 affirmations du sprint-status infirmées**.

---

## Affirmations du sprint-status que j'INFIRME

| # | Affirmation (sprint-status) | Réalité mesurée | Finding |
|---|---|---|---|
| A1 | CHAT-5 : « **2 clés de libellé absentes** de la table en intégrée » | `grep -rn "zchat" packages/zcrud_core/ \| wc -l` → **0**. Les **12** clés (10 de `zcrud_chat` + 2 de `zcrud_chat_syncfusion`) sont absentes des tables `en` **et** `fr`. | MAJ-1 |
| A2 | CHAT-4b : « le dépôt porte encore **TROIS** menus » | **six** sites de construction de menu : `zcrud_menu` + `z_batch_action.dart:301` + `z_page_shell.dart:353` + `z_sub_list_field_widget.dart:574` + `z_table_embed.dart:413` + `:453`. Les deux derniers ne sont nommés nulle part. | MAJ-3 |
| A3 | CHAT-3b : « `accessibleText` … remplacé le résumé local, **exhaustif par construction** » (bénéfice a11y implicite) | `AssistMessage.data` n'atteint **ni le pixel ni l'arbre sémantique** dès que `messageContentBuilder` est fourni. `grep -rn "Semantics" lib/` du paquet Syncfusion → **1 occurrence**, dans `composer_area.dart`. | **HIGH-2** |
| A4 | CHAT-0b : « le **re-contrôle de `execute`** l'arrête avant l'effet » (à propos de `ZChatCustomAction` non scellée) | **VRAI** — `requiresConfirmation` est un *getter* recalculé (`z_chat_action_plan.dart:112`), donc un basculement pendant l'attente est bien rattrapé. **Mais** la garantie voisine « aucun chemin d'exécution ne contourne un impact chiffré » est **fausse** : le constructeur de `ZChatActionPlan` est public. | MAJ-2 |
| A5 | CHAT-1 : « `ZQuotaExceededFailure` enfin CONSTRUITE — **premier consommateur réel** » | Consommateur réel = **zéro**. `zChatFailureFromWire` n'est appelée par aucun implémenteur de port du dépôt, et 5 des 7 codes qu'elle reconnaît n'existent dans **aucun** des deux backends. | MED-2 |
| A6 | CHAT-6 : « aucun `sequenceId` n'est fabriqué … **l'aveu exact** » | L'aveu est **passif**. Le port n'inspecte jamais `token.isResumption` : `grep -rn "sequenceId\|isResumption\|resumeFrom" packages/zcrud_chat_syncfusion/lib/` → 5 hits, **tous en prose**, aucun en code. Un jeton de reprise est accepté en silence. | MED-1 |

Ce que j'ai cherché à contredire et qui **tient** (à dire, pour ne pas laisser croire à un audit à
charge) : la boucle essai→reprise du contrôleur (`z_chat_controller.dart:435-441`) refuse bien de
reprendre quand `lastSequenceId` est resté nul — donc *avec le contrôleur*, le backend IFFD ne peut
pas rejouer un tour ; l'inventaire de balises de `z_iffd_wire.dart` est **exact** au regard du
backend réel (`<RESPONSE>`, `<REASONING>`, `<OUTIL>`, `<ERREUR>`, `<TOOL_ERROR>`, `<RAG_REQUESTS_n>`,
`<AI_MODEL_REASONING_n>`, `<CACHE_MISS>` : tous trouvés dans `smart_learn_cloudfunctions`) ; le
multiplexage raisonnement/réponse dans **un seul** flux est confirmé
(`shared/layers/presentation.py:151-171`) ; « un seul site d'instanciation de `ZChatMessageTile` » et
« aucun `PopupMenuButton` construit dans la façade `ZItemActionsMenu` » sont **vrais**.

---

## HIGH

### HIGH-1 — Le socle promet une fonctionnalité et livre une interface : 0 implémenteur sur 8 ports

**Preuve (grep négatif, `packages/*/lib` + `example/`, hors tests) :**

```
ZChatRenderer            : 0
ZChatActionExecutor      : 0
ZChatGenerationPort      : 0
ZChatAttachmentPicker    : 0
ZChatAttachmentUploader  : 0
ZChatPdfComposer         : 0
ZChatExportSink          : 0   (l'unique « hit » est de la dartdoc, z_chat_export_ports.dart:67)
ZChatContextPort         : 0
ZChatStreamPort          : 1   (ZIffdTextStreamPort, adaptateur IFFD)
ZChatShellRenderer       : 1   (ZSfAssistShellRenderer)
ZMenuRenderer            : 1   (ZDefaultMenuRenderer)
```

`grep -rln "zcrud_chat\|ZChatController" example/` → **aucun fichier**. L'application d'exemple du
dépôt n'instancie pas une seule ligne de chat.

**Scénario concret.** IFFD adopte la v0.30.0 et branche `ZChatConversationView`. Il obtient : une
liste virtualisée, une région live, un dépli inline. Il n'obtient **ni** génération (`ZChatGenerationPort`),
**ni** exécution d'action — donc `runAction` rend `Left` sur *tous* les verbes tant qu'il n'a pas
écrit son `ZChatActionExecutor` —, **ni** sélection de fichier, **ni** PDF, **ni** partage. Le
« portage rapide » annoncé est en réalité : *écrire 8 classes d'adaptation avant le premier message
envoyé*.

**Ce que le handoff DOIT dire, mot pour mot** (et que la formule « additif » masquerait) :
> Cette version livre **les contrats**, pas les capacités. Aucun hôte n'obtient de génération, de
> pièce jointe, de PDF ni de partage sans écrire lui-même l'implémentation des ports listés
> ci-dessus. `ZChatController` **exige** un `ZChatStreamPort` et un `ZChatActionExecutor` à la
> construction : il ne compile pas sans eux. La seule chose utilisable telle quelle est le **rendu**
> (`ZChatConversationView`) et, pour IFFD seulement, la normalisation de son flux textuel.

**Corollaire non dit** : la garantie phare du lot — « confirmation systématique sur toute action
destructrice » — est **entièrement déléguée**. Sur `ZChatCustomAction`, c'est l'hôte qui déclare
`isDestructive`/`cascades` ; c'est son `estimateImpact` qui chiffre la cascade. Aucun implémenteur
n'existant, la chaîne complète n'a jamais tourné une seule fois.

---

### HIGH-2 — `accessibleText` n'est annoncé à personne : le chemin Syncfusion est muet, et ses deux gardes ne le mesurent pas

**Chaîne réelle.** `ZSfAssistShellRenderer._summary` (`z_sf_assist_shell_renderer.dart:157`) est
**l'unique** consommateur non-test de `zChatAccessibleTextOf` dans tout le dépôt :

```
grep -rn "accessibleText" packages/ | grep -v _test.dart
  → z_content_block.dart (définition + prose)
  → z_sf_assist_shell_renderer.dart:82,102,152,159
```

Le rendu neutre (`zcrud_chat`) ne l'appelle **jamais** — zéro hit dans
`packages/zcrud_chat/lib/`.

**Ce que Syncfusion fait de `data` (version résolue 34.1.31, `pubspec.lock:1870`) :**

* `conversion_area.dart:370-376` —
  ```dart
  Widget buildContent(BuildContext context) {
    if (widget.contentBuilder != null) {
      result = widget.contentBuilder!(context, widget.index, widget.message);
    } else {
      result = buildText();          // ← SEULE branche qui lit `data`
    }
  ```
* `grep -rn "\.data" lib/src/assist_view/*.dart lib/src/conversion_area.dart` → le champ n'est lu
  **qu'à** `conversion_area.dart:920` (suggestions) et par `buildText()`
  (`assist_view/conversion_area.dart:565`).
* `grep -rn "Semantics\|semanticLabel\|semanticsLabel" lib/` sur tout le paquet →
  **1 occurrence**, `composer_area.dart:185` (`MergeSemantics` du composeur).

Or `ZSfAssistShellRenderer` fournit **toujours** `messageContentBuilder`
(`z_sf_assist_shell_renderer.dart:145`). Donc la branche `buildText()` n'est **jamais** prise, `data`
n'est **jamais** rendue, et le paquet ne pose **aucun** nœud sémantique qui pourrait la porter.

**Conséquence, et réponse à la question posée.** Non : un lecteur d'écran **n'énoncera pas** un jeton
brut — il n'énoncera **rien du tout** venant de `accessibleText`. Ce qui est annoncé, sur le chemin
Syncfusion comme sur le chemin neutre, ce sont les widgets de `ZChatMessageTile`. Les deux chemins ne
font donc **pas** le même usage d'`accessibleText` : le neutre ne s'en sert pas, le Syncfusion s'en
sert pour remplir un champ inerte. Le trou que CHAT-3b dit avoir bouché (« un tableau n'était annoncé
nulle part ») était en réalité déjà couvert par la fabrique de tuile partagée — et il l'est toujours
par elle, pas par `accessibleText`.

**Pourquoi la revue précédente ne l'a pas vu — les deux gardes n'assertent pas l'annonce :**

* `z_sf_assist_view_test.dart:281-288` : `expect(view.messages.first.data, contains('0101'))` —
  assertion sur une **propriété de widget**, pas sur `getSemanticsData()`. Elle resterait verte si
  Syncfusion ignorait `data` entièrement (ce qu'il fait).
* `:439-451` : `expect(view.messages.first.data, 'reference juridique')` avec le motif
  « *un bloc OUVERT est **annonçable*** ». Le test prouve que la chaîne est **posée**, jamais qu'elle
  est **annonçable**. Le paquet voisin sait pourtant faire mieux : `ensureSemantics()` +
  `find.bySemanticsLabel` sont utilisés **au-dessus**, aux lignes 196-214 et 386-397.

**Scénario concret.** Un hôte IFFD malvoyant ouvre une réponse contenant un `ZTableBlock`. La tuile du
socle rend le `Table` (donc les cellules sont lues, une par une, sans en-tête de rubrique) ; le
résumé exhaustif que le kernel a fabriqué — titre, en-têtes, lignes jointes par `, ` — part dans un
champ que rien ne lit. Le « réglé une fois pour tous les adaptateurs » de CHAT-3b n'a produit aucun
effet mesurable, et sa suppression ne ferait rougir aucun test qui mesure l'annonce.

**Correctif suggéré (hors périmètre de cette revue)** : soit envelopper la valeur de retour de
`request.itemBuilder` dans un `Semantics(label: _summary(...))` côté adaptateur, soit assumer que le
résumé n'est pas un dispositif d'accessibilité et le documenter comme tel (donnée de copie /
d'export). Dans les deux cas, retendre les deux gardes sur `getSemanticsData()`.

---

## MAJEUR

### MAJ-1 — Les 12 clés de libellé du chat sortent en clé brute chez tout hôte non configuré

**Preuve (grep négatif) :** `grep -rn "zchat" packages/zcrud_core/ | wc -l` → **0**.
`_enLabels` (`z_localizations.dart:24`) ne contient aucune clé `zchat.*`, et `label()` (`:294-302`)
retombe donc sur `fallback ?? key` — la **clé brute**.

Clés concernées : `zchat.showMore`, `zchat.showLess`, `zchat.sources`, `zchat.suggestions`,
`zchat.diagram`, `zchat.unsupportedBlock`, `zchat.liveRegion`, `zchat.streaming`,
`zchat.attachments`, `zchat.removeAttachment` (`z_chat_labels.dart:56-67`), plus
`zchat.sf.userAuthor` et `zchat.sf.assistantAuthor` (`z_sf_assist_labels.dart:36-39`).

**Scénario concret.** DODLP monte `ZChatConversationView` sans alimenter `ZcrudScope.labels`. À
l'écran : un bouton « **zchat.showMore** », un en-tête de provenance « **zchat.sources** », un
en-tête de diagramme « **zchat.diagram** ». Au lecteur d'écran, la région live du chat s'annonce
« **zchat.liveRegion** » et la bulle en cours « **zchat.streaming** ». L'arbitrage « une clé brute est
bruyante donc corrigée » est défendable — mais il porte sur **la totalité de l'interface du chat**,
pas sur deux étiquettes marginales comme l'annonce le sprint-status.

**Point de handoff obligatoire** : livrer la liste `kZChatLabelKeys` + `kZSfAssistLabelKeys** et dire
que **rien** n'est traduit par défaut.

---

### MAJ-2 — `ZChatActionPlan` a un constructeur PUBLIC : la garantie « impact chiffré avant destruction » est fausse

`z_chat_action_plan.dart:98` :

```dart
const ZChatActionPlan({required this.action, required this.impact});
```

Ce constructeur est **public** et `const`. Les affirmations qu'il contredit, dans le même fichier :

* `:49` — « **aucun chemin d'exécution ne contourne un impact chiffré** » ;
* `:147-149` — « la seule fabrique est `ZChatActionPlan` — donc **on ne peut pas exécuter une action
  destructrice sans être passé par `prepare` et par un impact chiffré** ».

**Scénario concret.** Un hôte écrit, sans jamais toucher `prepare()` :

```dart
const plan = ZChatActionPlan(
  action: ZChatCustomAction(verb: 'purgeThread', isDestructive: false, cascades: false),
  impact: ZChatActionImpact(),          // 0 message touché — jamais mesuré
);
await dispatcher.execute(plan.proceedWithoutConfirmation()!);   // → executor.executeCustom()
```

`requiresConfirmation` vaut `false` (non destructif, pas de cascade, `affectedMessageCount == 0`), le
jeton est délivré, `execute` ne re-refuse rien et **`estimateImpact` n'a jamais été appelé**. Le
verbe purge le fil. C'est exactement la classe de contournement que D2 dit fermer, et les tests du
kernel l'empruntent déjà eux-mêmes (`z_chat_action_dispatcher_test.dart:241,269,391` ;
`z_chat_action_plan_test.dart:223,251,324,338,354` construisent tous des plans à la main) — la forme
est donc non seulement possible, elle est **démontrée en usage**.

Pour l'action **destructrice** la garantie reste partiellement tenue (il faut appeler
`confirmedByUser()`, le « mensonge localisé et greppable » assumé), mais **l'impact chiffré, lui,
est contournable dans tous les cas**. Deux formulations possibles : rendre le constructeur privé et
n'exposer que `prepare()`, ou corriger la dartdoc — elle promet aujourd'hui davantage que le code.

---

### MAJ-3 — Deux lectures INCOMPATIBLES de la même règle de sélection de menu, posées le même jour

`zcrud_menu` a mesuré et corrigé (CHAT-4b) un défaut : résoudre l'entrée sélectionnée par
`visible.contains(entry)` avale la sélection quand un rebuild refabrique la closure. La correction
(`z_action_menu.dart:88-109`) résout par **identité déclarée** (`identical`, puis `id`+`label`) et
n'invoque **que** l'effet de l'entrée courante ; une entrée inconnue est **sans effet**.

Les deux autres menus du cœur lisent la même règle à l'envers — par **position** :

* `packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart:301,322`
  `PopupMenuButton<int>` … `onSelected: (i) => entries[i].onPressed()`
* `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:353,369`
  `PopupMenuButton<int>` … `onSelected: (i) => overflow[i].onPressed?.call()`

**Scénario concret (ZBatchActionBar).** L'utilisateur sélectionne 3 fiches, ouvre le débordement de
la barre de lot (`[Exporter, Déplacer, Supprimer]`). Pendant que la surface flottante est ouverte, un
`Stream<List<T>>` Firestore rend un item invisible : la barre se reconstruit avec
`[Exporter, Supprimer]`. L'utilisateur tape « Supprimer » (index **2** capturé à l'ouverture) →
`entries[2]` sur une liste de longueur 2 → **`RangeError` dans un gestionnaire de tap**. Variante
plus grave : si l'action retirée est « Exporter », la liste devient `[Déplacer, Supprimer]` et
l'index 2 lève encore ; si une action est **ajoutée** en tête, l'index 2 désigne « Déplacer » alors
que l'utilisateur a lu « Supprimer » — **une autre action s'exécute, silencieusement**.

C'est strictement **pire** que le no-op qui a justifié la correction de `zcrud_menu` : là où le
défaut corrigé perdait le geste, celui-ci en exécute un autre. Deux paquets du même dépôt, deux
lectures conformes de « ne jamais avaler une sélection », résultats opposés.

**Et le décompte est faux** : le sprint-status annonce « trois menus ». Il y en a **six** sites :
les deux ci-dessus, plus `zcrud_core/…/z_sub_list_field_widget.dart:574` (`PopupMenuButton<int>` +
`templates[i]`, même forme positionnelle) et `zcrud_markdown/…/z_table_embed.dart:413` et `:453`.
Les trois derniers ne sont nommés **nulle part** dans le sprint-status — donc invisibles au plan de
migration.

---

### MAJ-4 — Deux lectures INCOMPATIBLES d'AD-10 sur les seams d'hôte, dans la même epic

| Seam | Hôte qui lève | Justification écrite |
|---|---|---|
| `ZAccessibleTextResolver` (kernel) | **ABSORBÉ** — `z_content_block.dart:300-308`, `try/catch` → repli sur le résumé du kernel | « AD-10 : un seam d'hôte qui lève ne doit pas rendre le message muet » |
| `ZChatRenderer.buildBlock` / `ZChatShellRenderer.buildShell` | **PROPAGÉ** — `z_chat_renderer_scope.dart:54-60`, « Aucun `try` ici » | « l'étouffer le rendrait indébogable … protéger ce seam-ci seulement ferait **diverger** les garanties de deux coutures voisines » |

Les deux motifs sont défendables. Ils sont **incompatibles**, et le second invoque précisément la
non-divergence comme argument — alors que la divergence existe déjà, à un fichier de distance, dans
la même livraison.

**Scénario concret.** Un hôte lex écrit **un seul** objet qui sait traiter son bloc ouvert
`'legalReference'` : il le rend (`buildBlock`) et l'annonce (`accessibleTextResolver`), les deux en
lisant `payload['articles'] as List`. Le backend renvoie un jour `articles: null`. Alors :

* via le resolver → exception avalée, le bloc est annoncé « legalReference », **personne ne le sait** ;
* via `buildBlock` → l'exception traverse `ZChatBlockView`, remonte le `ListView.builder`, et
  **toute la conversation** devient un écran rouge.

Même bug, même donnée, deux comportements opposés — et le chemin silencieux masque exactement le
défaut que le chemin bruyant révèle.

**Aggravation propre à la coquille.** `zResolveChatShell` propage aussi. Une exception jetée par
`SfAIAssistView` (paquet **tiers**, hors du contrôle de l'hôte) **ne retombe pas** sur la liste
neutre : la conversation disparaît. Cela contredit la promesse AD-57 répétée dans
`z_chat_block_view.dart:16-20` (« dégradé, **jamais absent** ») — promesse tenue pour le rendu de
bloc par le défaut neutre, mais **pas** pour le conteneur, où le défaut neutre existe pourtant
(`z_chat_conversation_view.dart:173`) et n'est jamais atteint en cas d'exception.

---

### MAJ-5 — Deux mécanismes de localisation qui divergent sur la MÊME chaîne

`zcrud_chat` porte bien **deux** dispositifs :

* résolution par `BuildContext` — `label(context, kZChatLabelSources)`
  (`z_chat_block_view.dart:138`), clé `zchat.sources` ;
* injection par constructeur — `ZChatExportVocabulary({this.sources = 'sources', …})`
  (`z_chat_export_service.dart`, défauts `user`/`assistant`/`system`/`sources`/`references`/`exported`).

Rien ne les relie : `grep -rn "ZcrudLabels\|label(context" packages/zcrud_chat/lib/…/export/` → aucun
hit ; le service d'export est pur-domaine et n'a pas de `BuildContext`.

**Scénario concret.** lex alimente `ZcrudScope.labels` avec `'zchat.sources' → 'Références'` et
oublie `ZChatExportVocabulary` (rien ne le lui signale : l'objet a un défaut complet, il n'y a ni
`required` ni assert). À l'écran, la rubrique s'appelle « Références » ; dans le Markdown exporté et
le PDF partagé, la **même** rubrique s'appelle « sources », et la date « exported ». L'utilisateur
partage un document à moitié en anglais technique.

L'arbitrage est cohérent pris fichier par fichier (aucune chaîne en dur des deux côtés) — mais il
crée **deux registres à alimenter** pour un seul vocabulaire, sans aucun pont ni garde de cohérence.
À minima, `ZChatExportVocabulary` devrait porter une fabrique documentée
`fromLabels(BuildContext)` alignée sur les mêmes clés.

---

## MEDIUM

### MED-1 — `ZIffdTextStreamPort` accepte un jeton de reprise en silence

**Preuve (grep négatif) :**
`grep -rn "sequenceId\|isResumption\|resumeFrom" packages/zcrud_chat_syncfusion/lib/` → **5 hits,
tous dans le bloc de prose de `z_iffd_stream_normalizer.dart:20-27`**. Aucune ligne de **code** du
paquet ne lit `token.isResumption` ni `token.lastSequenceId`. `stream()`
(`z_iffd_stream_port.dart:46-102`) appelle `open(request, token)` et repart de zéro.

Le contrôleur protège le cas nominal : `_consume` n'engage une reprise que si
`resumePoint != null` (`z_chat_controller.dart:435-441`), et le normaliseur IFFD n'émet jamais de
`sequenceId` — donc **avec `ZChatController`, aucun rejeu**. La faille est ailleurs :

**Scénario concret.** IFFD, comme le contrat de `ZChatStreamPort` l'y invite explicitement
(`z_chat_generation_port.dart:238-252` montre la boucle en exemple), consomme le port
**directement** depuis son propre code de reprise réseau et construit
`ZChatRequestToken(id, lastSequenceId: '17')` après une coupure Wi-Fi. `ZIffdTextStreamPort` ne
regarde pas le champ, rouvre le flux au début : la réponse **entière** est réémise et **concaténée**
à ce qui était déjà affiché, et le tour est **facturé deux fois** côté agent. Rien — ni assert, ni
`Left(ZUnsupportedOperationFailure)`, ni dartdoc sur la classe elle-même — ne le signale.

Le contrat le dit « assez fort » au niveau de l'**interface** (`:254` : « Une implémentation qui
ignore `token.lastSequenceId` rejouera le tour entier ») mais **pas au niveau de l'implémentation
livrée**, qui est justement celle qui l'ignore. Un `if (token.isResumption) yield Left(
ZUnsupportedOperationFailure(...))` rendrait la limite **bruyante** — la discipline que ce même lot
applique partout ailleurs.

**Risque symétrique côté lex** (à porter au handoff) : la reprise réelle de lex exige **trois**
choses simultanément — `Last-Event-ID` (entier, `routes.py:371-384`), `Idempotency-Key` **envoyée dès
la première tentative** (`routes.py:1020-1024`, `bind_key_to_message_id`) et `conversation_id`
(`routes.py:492`). Un adaptateur qui transporte `requestId` en `Idempotency-Key` **uniquement à la
reprise** obtiendra `get_message_id_for_key → None` donc « tour normal », c'est-à-dire un **rejeu
complet** — que le contrôleur, lui, **concaténera** au texte déjà accumulé
(`z_chat_controller.dart:532`, et `:449-452` documente explicitement que le texte n'est pas remis à
zéro). Message dupliqué visible à l'écran, quota consommé deux fois.

---

### MED-2 — Le mapping d'erreurs vise des codes que **ni** backend n'émet

**Preuve (grep négatif sur les deux backends réels) :**

| Alias reconnu par `_canonicalCode` (`z_chat_ai_failure.dart:268-285`) | lex `backend/app` | IFFD `smart_learn_cloudfunctions` |
|---|---|---|
| `MODERATION_BLOCKED` | **0** | **0** |
| `CONTENT_FILTERED` | **0** | **0** |
| `CONTEXT_LIMIT_EXCEEDED` | **0** | **0** |
| `CONTEXT_LENGTH_EXCEEDED` | **0** | **0** |
| `UNSUPPORTED` | **0** | **0** |
| `QUOTA_EXCEEDED` | 31 | 0 |
| `STREAM_INTERRUPTED` | 2 | 0 |

Les codes SSE **réellement** émis par lex sont ceux de `app/core/error_codes.py` :
`AGENT_TIMEOUT`, `LLM_ERROR`, `STREAM_INTERRUPTED`, `GRAPH_ERROR` (plus les 10 codes HTTP :
`VALIDATION_ERROR`, `NOT_FOUND`, `FORBIDDEN`, `RATE_LIMITED`, `CONFLICT`, `SERVICE_UNAVAILABLE`,
`INTERNAL_ERROR`, `UPGRADE_REQUIRED`, `UNAUTHORIZED`, `RANGE_NOT_SATISFIABLE`).

**Conséquence.** `ZChatModerationFailure` et `ZChatContextLimitFailure` — deux des trois familles
« qui manquaient réellement » — n'ont **aucun producteur observable** : seul un hôte qui invente ces
codes les fera naître. Sur les 4 codes SSE réels de lex, **un seul** (`STREAM_INTERRUPTED`) est typé ;
`AGENT_TIMEOUT`, `LLM_ERROR` et `GRAPH_ERROR` retombent en `ZChatProviderFailure` — le code est
conservé verbatim (bien), mais l'hôte doit refaire le triage à la main, ce que le lot annonçait
supprimer. Réponse à la piste 7 : **le socle sait exprimer les deux backends** (le fond du modèle est
bon — enveloppe neutre, code verbatim préservé, `Left` jamais confondu avec du contenu) ; ce qu'il a
silencieusement choisi, c'est un **vocabulaire de codes qui n'appartient à personne**.

---

### MED-3 — `zChatQuotaFromMetadata` : la garantie « jamais un instantané à zéro » ne couvre que l'absence TOTALE

`z_chat_quota_metadata.dart:104-118` rend `null` si **aucune** clé n'est présente. Dès qu'**une
seule** l'est, les autres prennent `?? 0` :

```dart
limit:      _int(lower[keys.limit]) ?? 0,
remaining:  _int(lower[keys.remaining]) ?? 0,
resetEpoch: _int(lower[keys.reset]) ?? 0,
```

et `isExhausted => remaining <= 0 && (prepaidBalance ?? 0) <= 0`
(`z_chat_quota_snapshot.dart:35`).

**Scénario concret.** L'endpoint RAG de lex ne pose que **deux** en-têtes —
`X-RAG-Quota-Limit` et `X-RAG-Quota-Remaining` (`app/api/v1/rag/routes.py:620-621`), **sans reset**.
Un adaptateur qui les projette sur les clés logiques obtient `resetEpoch: 0`, c'est-à-dire
**1er janvier 1970** : toute jauge affichant « réinitialisation dans … » annonce une date passée.
Plus grave sur une carte ne portant que `limit` (cas d'un adaptateur qui n'aurait mappé qu'un
en-tête) : `remaining: 0` ⇒ `isExhausted == true` ⇒ **l'utilisateur est bloqué par une donnée
inventée** — exactement le mal que la dartdoc `:26-30` dit prévenir.

Correctif de forme : rendre les champs nullables, ou n'accepter le snapshot que si le **triplet**
`limit`/`remaining`/`reset` est présent (ce que lex pose bien ensemble sur le chemin chat,
`routes.py:714-718` et `1506-1508`).

---

### MED-4 — La confirmation destructrice n'est prouvée nulle part de bout en bout

Le protocole est correct par construction (cf. A4 : le re-contrôle **tient**), mais chacun de ses
deux termes est fourni par l'hôte : `isDestructive`/`cascades` sur `ZChatCustomAction`
(`z_chat_action.dart:376-395`, champs déclarés par l'appelant) et `affectedMessageCount` par
`executor.estimateImpact`. Avec **0 implémenteur** (HIGH-1) et un plan fabricable sans `prepare`
(MAJ-2), la propriété « aucune destruction non confirmée » n'a jamais été observée sur un chemin réel.

**Formulation de handoff** : « le socle vous **oblige** à vous prononcer ; il ne peut pas vérifier
que vous dites vrai. Un `estimateImpact` qui rend `ZChatActionImpact()` par défaut désarme la
confirmation pour tous vos verbes d'hôte. »

---

## LOW

* **LOW-1** — Contradiction littérale entre deux fichiers du même lot sur la chaîne vide :
  `z_content_block.dart:113-119` pose que « une chaîne vide rendue à un lecteur d'écran est le pire
  des cas », et `z_sf_assist_shell_renderer.dart:129` écrit `data: ''` pour toute requête active.
  Sans conséquence observable **du fait de HIGH-2**, mais les deux règles sont opposées.
* **LOW-2** — `zChatAccessibleTextOf` rend `''` pour un message sans bloc
  (`z_content_block.dart:144-153`, « rendre `''` uniquement pour une suite vide »), là encore contre
  la règle « jamais vide » du même fichier. Un message vide devient donc muet, sans signal.
* **LOW-3** — `_ZChatList._item` rend `SizedBox.shrink()` sur index hors bornes
  (`z_chat_conversation_view.dart:149-151`), motivé par « une coquille tierce indexe comme elle
  veut ». C'est un **no-op silencieux** — la catégorie de défaut que MAJ-3 et CHAT-4b traitent partout
  ailleurs comme inacceptable. Une coquille qui décale ses index d'un cran afficherait des bulles
  vides sans qu'aucune garde ne morde.

---

## Note de méthode

Aucun test n'a été exécuté : trois relecteurs travaillent en parallèle et `flutter test` réécrit le
`.dart_tool/package_config` partagé du workspace (incident diagnostiqué en CHAT-4b). Les décomptes de
tests annoncés par le sprint-status (283 / 152 / 52 / 67 / 797) ne sont donc **ni confirmés ni
infirmés** par cette revue — ils ne font pas partie de sa lentille. Tout le reste est adossé à une
lecture de fichier ou à un grep reproduit ci-dessus.
