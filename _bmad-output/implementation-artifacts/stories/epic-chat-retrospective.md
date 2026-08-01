# Rétrospective — Epic `CHAT` (portage de l'assistant IA : socle de conversation neutre)

- **Skill** : `bmad-retrospective` — **invoqué réellement** via le tool `Skill` (workflow chargé, 13 étapes). Exécution **non interactive** : l'epic, le périmètre et le chemin de sortie étaient imposés par la demande ; les étapes de dialogue party-mode ont été jouées en analyse et non en conversation.
- **Date** : 2026-08-01 · Facilitation : Amelia (Developer). Participants : Zakarius (Project Lead), Amelia, Dana (QA), Winston (Architect), Alice (PO).
- **Périmètre** : 12 lots livrés `done` (`chat-0`, `0r`, `0b`, `1`, `1b`, `2`, `3`, `4`, `3b`, `4b`, `5`, `6`), 4 lots restés `backlog` (`chat-7..10`). Revue de fin d'epic à **4 lentilles**. Livraison taguée **v0.30.0**, commit `9c49827`.
- **Vérifié sur disque par moi pendant la rédaction** : commit `9c49827` = **180 fichiers, +34 064 / −282** · `epic-chat-retrospective` **n'existe pas** comme clé du sprint-status (à ajouter par l'orchestrateur) · comptage d'implémenteurs de ports rejoué **après** corrections (§ 5).
- **Aucun fichier de code n'a été écrit ni modifié par cette rétro. Aucun gate joué.**

---

## 0. La thèse de cette epic

Cette epic n'a pas produit de pannes. Elle a produit des **verdicts faux**.

Pas un seul des incidents majeurs ne s'est manifesté par un plantage, un crash ou un rouge. Ils se sont tous manifestés par du **vert** : une garde qui passe, un rapport qui conclut, une affirmation de sprint-status qui tient. Un rouge peut venir du compilateur, de l'infrastructure ou d'un voisin — il a au moins la vertu d'exister. Un vert, lui, peut venir d'une vérification qui n'a **rien vérifié**, et rien ne le signale.

Le corollaire opérationnel est désagréable : **le nombre de tests verts d'un paquet n'est pas une mesure de sa sûreté**. Les cinq paquets de l'epic totalisaient 1 378 tests verts au moment où la revue a établi 3 HIGH et 9 MAJEUR, dont un défaut d'accessibilité **sans aucun effet observable** défendu par deux gardes vertes, et un plancher tactile mesuré à **28,6 dp** sur une cible déclarée de 48. Aucun de ces chiffres n'était faux. Ils ne mesuraient simplement pas ce qu'on croyait.

---

## 1. Ce qui a marché — avec les preuves, et pourquoi

### 1.1 La discipline R3 (injecter la régression exacte) a été appliquée systématiquement, et elle a payé

Ce n'est pas un satisfecit : c'est la seule raison pour laquelle des défauts **réels** ont été trouvés avant les hôtes.

| Lot | Ce que R3 a trouvé, et que rien d'autre n'aurait trouvé |
|---|---|
| `chat-0b` | la garde anti-champ-mutable ne cherchait que `final\|late\|static\|var` — `String? currentRequestId;` (**la forme exacte du CancelToken partagé d'IFFD**) passait |
| `chat-2` | 5 injections dans le **vrai** code de production, dont `notifyListeners()` à chaque frappe ⇒ **les deux moitiés de SM-1 tombent** ; la garde **compte** les rebuilds par tranche, ce n'est pas une garde de présence |
| `chat-3` | `ListView(children:)` injecté ⇒ rouge nommant `SliverChildListDelegate(estimated child count: 200)` — **la virtualisation est prouvée par son mécanisme, pas par comptage** |
| `chat-5` | deux défauts de **code** trouvés par ses propres gardes : `theme.formPadding` écrasait `minHeight: 48` (hauteur réelle **40 dp**) ; `_canSend` n'était recalculé que par le listener du `TextEditingController` — la garde d'UI et celle du domaine **se contredisaient** |
| revue « tests porteurs » | **13 gardes prouvées mordantes** par injection, **tous les rouges étant des échecs d'ASSERTION** (jamais de compilation, jamais de chargement) |

**Pourquoi ça a marché** : parce que le rouge attendu était **nommé à l'avance** (fichier, message d'assertion), et que le vert de restauration était contrôlé par `md5sum -c`. Un rouge non qualifié aurait été aussi peu concluant qu'un vert.

### 1.2 Deux refus, et c'est le meilleur de l'epic

- **`chat-6` a refusé de fabriquer un `sequenceId`.** Le fil d'IFFD n'en porte pas et son serveur n'a aucun point de reprise. En inventer aurait fait croire que `resumeFrom` est honoré alors qu'une reconnexion **rejouerait le tour** (quota consommé deux fois). Le lot a préféré livrer une **limite explicite** plutôt qu'une capacité fausse.
- **La correction de HIGH-2 a rejeté sa propre première solution** après l'avoir mesurée **inerte** : le résumé accessible partait dans `AssistMessage.data`, un champ que le paquet tiers **n'exploite pas** sur notre chemin de rendu (branche `buildText()` jamais prise dès que `messageContentBuilder` est fourni). Plutôt que de re-promettre le défaut derrière un dispositif verdi, la solution a été remplacée par un `Semantics` **que nous contrôlons**, commun aux deux branches.

Un troisième refus est du même sang : un agent a **refusé d'écrire une garde** là où le scénario visé n'était pas atteignable, au lieu de produire une garde vacuelle de plus. Ces trois décisions valent mieux que dix gardes ajoutées.

### 1.3 Le script R3 s'est arrêté SEUL sur un motif ambigu

`chat-5`, injection I14 : le motif visé avait **5 occurrences**. Le script a refusé d'appliquer et s'est arrêté ; le motif a été réancré. C'est **la garde anti-faux-vert du dispositif R3 lui-même** qui a fonctionné — sans elle, l'injection aurait porté ailleurs et le vert obtenu n'aurait rien signifié.

### 1.4 Les leçons de la rétro VIS ont été réellement appliquées (2 sur 4)

| Leçon VIS | État en CHAT |
|---|---|
| **3.2** — `git checkout` confond référence, travail légitime et injection | ✅ **appliquée** : manifeste `md5sum` des 244 `.dart` pris **avant**, sauvegarde `cp -a`, restauration **par copie**, `md5sum -c` après **chacune** des 10 injections, **0 divergence**, **aucun `git checkout`** |
| **3.1** — un gate global sur un arbre mutable ne mesure pas le workstream | ✅ **appliquée** : gates repo-wide joués **uniquement aux points de quiescence** ; les relecteurs ont explicitement **renoncé** à `melos` en parallèle |
| **3.4** — une défaillance d'infra n'est pas une défaillance produit | 🟡 **reconnue mais repayée** : `chat-4b` a diagnostiqué 3 échecs de **chargement** dus au `.dart_tool/package_config` **partagé** du workspace, réécrit par chaque `flutter test` concurrent |
| **3.3** — un oracle peut rendre un verdict sans exercer la propriété | ❌ **NON tenue en couverture** — c'est le thème dominant de CHAT (§ 3). La méthode a été apprise ; la **portée** ne l'a pas été |

### 1.5 Les invariants d'architecture, eux, tiennent

La lentille conformité conclut **0 HIGH** et le prouve par greps : `CORE OUT = 0`, graphe acyclique, `syncfusion_flutter_chat` nulle part hors de son adaptateur (avec **fermeture transitive** calculée et contrôle positif), zéro gestionnaire d'état, zéro `throw` dans les quatre paquets, zéro couleur littérale, `notifyListeners()` appelé **à un seul endroit**. `chat-0r` a sorti 3 863 lignes de `zcrud_core` **sans perdre un test** (1 110 + 134 = 1 244, exactement le total d'avant).

**La conformité n'était pas le problème de cette epic. La vérifiabilité l'était.**

---

## 2. Ce que ça a coûté

### 2.1 Un tiers des lots livrés sont des lots de reprise ou de suite

| Lot | Nature | Cause |
|---|---|---|
| `chat-0r` | **relocalisation** de 18 fichiers / 3 863 lignes | le domaine chat avait été écrit dans `zcrud_core` — DODLP/DLCFTI l'auraient porté sans usage |
| `chat-1b` | **correctif ciblé** de `chat-1` | 3 faits établis **après** le lancement du lot (contrat SSE reprenable, axe d'effort de calcul démontré, quota par en-têtes) — dont un **axe refusé sur un argument devenu faux** |
| `chat-3b` | **couture manquante** | `chat-3` avait posé un seam **par bloc** et aucun seam de **conversation** ; `chat-6` a dû écrire une vue **parallèle** (217 lignes + tuile recopiée + 54 lignes de passe-plat + 2 clés jumelles) |
| `chat-4b` | **migration** | `chat-4` avait livré la couture sans la faire consommer ; le doublon CR-LEX-78 était **différé, pas éliminé** |

**4 lots sur 12 = 33 % de l'epic** consacrés à défaire ou compléter des lots de la même epic. Aucun n'est un accident isolé : tous les quatre sont le même motif — **un lot livré « vert » dont la preuve ne couvrait pas la propriété qui comptait** (placement, actualité des faits, consommation, périmètre du seam).

### 2.2 Le coût du travail non prouvé par un consommateur

`chat-4b` a trouvé, dans `zcrud_menu` **livré le jour même**, un défaut réel : `ZActionMenu.select` filtrait par `visible.contains(entry)`, or `ZMenuEntry.==` compare `onSelected`, donc une **identité de closure**. Tout hôte écrivant `onSelected: () => faire(x)` — le patron **normal** — en refabrique une à chaque rebuild : un rebuild pendant que le menu est ouvert **avalait la sélection sans aucune trace**. Le no-op silencieux que AD-4 proscrit, entré par la porte de derrière du garde-fou censé le prévenir.

Ce défaut a survécu à 51 tests verts et à une campagne R3. Il n'est apparu qu'au **premier vrai consommateur**. **Une couture non consommée n'est pas prouvée** — elle est seulement compilable.

### 2.3 Trois incidents d'orchestration, tous imputables à l'orchestrateur, zéro imputable au code

| Incident | Coût mesuré |
|---|---|
| Un `SendMessage` vers un agent **terminé** l'a **réveillé** → deux rédacteurs simultanés sur `zcrud_chat_kernel` | paquet laissé **rouge (13 erreurs)** ; lot à reprendre. Le second agent a détecté la collision par horodatages et **restauré par copie** — comportement exemplaire, dégât limité par lui, pas par l'orchestrateur |
| Un `TaskStop` **n'a pas pris effet immédiatement** : l'agent arrêté a continué d'écrire **~10 min** (`chat-1b`) | paquet resté cohérent par chance (arrêt **avant** toute injection) |
| Deux agents parallèles partageant un **scratchpad** : l'un a détruit la sauvegarde de l'autre en pleine campagne R3 (`chat-2`) | agent figé **32 min**, remplaçant arrêté en cours, **injection résiduelle laissée en place** (jeton d'instance + 2 sites d'usage) ⇒ paquet trouvé **rouge, cassé par construction** ; campagne R3 finalement **rejouée par l'orchestrateur lui-même** |

### 2.4 Le coût de la revue de fin d'epic

Décompte cumulé des 4 lentilles : **3 HIGH · 9 MAJEUR · ~12 MEDIUM · ~8 LOW**, plus **5 gardes prouvées non mordantes par injection**, plus **6 affirmations du sprint-status infirmées** par la seule lentille adversariale. À quoi s'ajoutent **2 affirmations d'exploration** révélées fausses et corrigées à la main pendant l'epic.

Le prix de la directive « une seule revue en fin d'epic » n'est pas le nombre de findings : c'est leur **date**. Un HIGH trouvé au lot 3 coûte une correction ; trouvé en fin d'epic, il coûte une correction **plus** la relecture des 9 lots qui ont bâti dessus.

### 2.5 Le filet automatique n'existe plus

**La CI est morte depuis ~75 pushes** (compte verrouillé, facturation). 75 runs sur 75 en échec, 3 à 10 s, le job n'a **jamais démarré**. Conséquence directe et mesurée : un test rouge a été **taggé et livré en v0.29.0** (`zcrud_firestore`, garde CR-LEX-26 restée sur `ZDomainFailure` après que CR-LEX-44 eut substitué `ZUnsupportedOperationFailure`).

**Ce que ça change** : la vérif verte locale rejouée par l'orchestrateur n'est plus un **doublon** de la CI, c'est la **seule** ligne de défense. Un orchestrateur qui « fait confiance au rapport » ne délègue plus une vérification redondante — il en **supprime la dernière**. C'est aussi ce qui rend le § 2.3 grave : chacun des trois incidents a laissé un paquet dans un état qu'aucun automate n'aurait signalé.

⚠️ **Action owner, hors périmètre technique : débloquer la facturation.**

---

## 3. Les familles de défauts de garde, et la règle qui va avec

Sept des douze lots ont trouvé au moins une garde non mordante **dans leur propre périmètre** ; la revue de fin d'epic en a trouvé **cinq de plus**. Elles se rangent en huit familles.

### F-1 — La garde mesure le plancher du SDK, jamais le nôtre
`z_flashcard_a11y_test`, `z_menu_a11y_rtl_test`, `chat4b_…:373` mesuraient tous un ancêtre `PopupMenuItem`, qui impose déjà `kMinInteractiveDimension` (48). Mettre **notre** plancher à zéro les laissait **vertes**. Mesure du défaut réel : `Size(100.0, 28.6)` en grille `childAspectRatio: 3.5`.
> **Règle** — une garde de dimension mesure **le widget qu'on écrit**, jamais un ancêtre du framework, et elle lit la **contrainte** (`widget.constraints.minHeight`) autant que la taille rendue. Preuve d'acceptation obligatoire : mettre notre constante à `0` doit rougir.

### F-2 — Le widget visé n'est pas monté
Le test RTL de `chat-6` restait vert sous injection : sans `streamingRequestId`, le seul `Align` du paquet **n'était pas dans l'arbre**. Idem `find.byType(ListView) findsNothing`, satisfait parce que la coquille tierce monte le sien.
> **Règle** — toute assertion de **propriété** ou d'**absence** doit être précédée d'une assertion de **présence du sujet** (`findsWidgets`, `expect(scanned, greaterThan(N))`). Une garde qui ne peut pas dire combien d'éléments elle a examinés ne peut rien affirmer.

### F-3 — Le harnais neutralise la condition qu'il croit poser
Un `Directionality` sous `MaterialApp` **ne s'applique pas** à une surface flottante rendue dans l'`Overlay` : la garde RTL testait un rendu **LTR**. La croire aurait fait « corriger » du code sain.
> **Règle** — la condition doit être **mesurée là où le sujet est rendu** (sonde `Directionality.of(element(find.text(…)))` **dans** la surface), et imposée par un `LocalizationsDelegate<WidgetsLocalizations>`, pas par un widget ancêtre.

### F-4 — La regex de source ne décide pas ce qu'elle croit décider
`RegExp(r"Text\(\s*['\"]")` en scan **ligne à ligne** : le témoin réel (littéral **à la ligne suivante** et pas premier argument) passait. Symétriquement, un grep du mot brut `syncfusion` rougissait sur **21 fichiers dont les commentaires documentent l'isolation**.
> **Règle** — « littéral en position d'argument » n'est **pas décidable par regex**. Déplacer la cible vers une propriété **totale** (« aucun littéral porteur de mot ≥ 4 lettres dans ces fichiers ») ; **stripper commentaires de bloc et littéraux** avant tout scan ; et prouver le scanner sur des **témoins synthétiques** dans le même run (patron `z_sf_ad57_isolation_guard_test` — le meilleur du dépôt).

### F-5 — La garde de comptage n'est pas un oracle
`sources.length >= 7`, « au moins 3 `Semantics(` », `relais == variants.length` compté sur **tout le fichier**, `_Capacite('glyphe de déclencheur injecté', 'final IconData? icon;')` satisfaite par **un autre fichier**. Mesuré : `z_menu_trigger.dart` **entièrement vidé** ⇒ **1 seul rouge sur 34**, et le groupe PRÉSERVATION resté vert alors que `ZMenuTrigger`, son `icon`, son `semanticLabel` et son assert avaient tous disparu.
> **Règle** — un seuil n'est pas un oracle. Toute garde d'inventaire doit être **nominative** et **ancrée au fichier attendu** (motif + chemin). Un compte ne compense jamais un manque par un excès ailleurs.

### F-6 — La garde tautologique / vacuelle
`expect(kZChatMinTapTarget, greaterThanOrEqualTo(48.0))` — une constante comparée à elle-même ; elle resterait verte si **tous** les widgets cessaient d'appliquer le plancher. `expect(all, contains('liveRegion: true'))` — grep de source : l'annotation **est** présente, et pourtant **rien n'est annoncé** (défaut M-1).
> **Règle** — un oracle doit être **falsifiable par une injection dans la production**. Une garde qu'aucune injection ne peut faire rougir n'ajoute pas de sûreté : elle ajoute du **vert**. La supprimer est un gain net.

### F-7 — La garde formulée en négation faible (denylist)
`deps.where((d) => d != 'flutter' && !d.startsWith('zcrud_'))` s'appelait « aucune dépendance **TIERCE** » — dans un dépôt où **22 satellites `zcrud_*` portent une dépendance tierce**. Preuve rejouée : avec `zcrud_export_ui` au pubspec, la garde de pureté passait **+8 VERTE**. Même angle mort dans `kBannedImports` (liste fermée) et dans le denylist du kernel.
> **Règle** — jamais de denylist pour une propriété d'isolation. **Allowlist nominatif** (`{flutter, zcrud_core, zcrud_chat_kernel}`), et pour ce qui compte vraiment, **fermeture transitive** via `dart pub deps --json` **avec contrôle positif**. Corollaire : le **titre** d'un test est une affirmation ; s'il dit « tierce », il doit tester « tierce ».

### F-8 — 🔴 La garde qui DÉFEND LE DÉFAUT
C'est le cas insidieux, et il est **hors de portée de R3 par construction**. Deux gardes de `zcrud_chat` étaient vertes, mordantes, correctement écrites — et **protégeaient le mauvais comportement** : « sans registre, c'est la clé qui s'affiche ». Elles ont dû être **renversées** en fin d'epic. Mesuré avant correction : `zchat.removeAttachment` **affiché** sur un bouton, `zchat.liveRegion` **annoncé** à un lecteur d'écran — sur **12 clés sur 12**, pas « deux » comme l'affirmait le sprint-status. Même famille : la garde qui **figeait** le slug ASCII-only (`« Étude » → « tude »`, titre entièrement non-latin ⇒ slug **vide**) au nom de la parité avec lex.
> **Règle** — une garde verte et mordante prouve qu'un comportement est **STABLE**, jamais qu'il est **BON**. Toute garde qui **fige un arbitrage** doit (a) citer l'arbitrage en clair dans sa dartdoc, (b) nommer la lecture concurrente qui a été écartée, (c) être **re-soumise** dès que le contexte change. Et une règle du dépôt appliquée de deux façons opposées dans deux paquets voisins (`label(context, 'cancel', fallback: 'Annuler')` chez `zcrud_session`/`zcrud_study` contre « pas même un repli » chez `zcrud_chat`) est une **divergence à trancher**, pas deux arbitrages également valables.

### La racine commune

**Une garde hérite de l'angle mort de son auteur.** Elle est écrite par la même personne, dans la même passe, à partir de la **même lecture** que le code qu'elle défend. Elle prouve donc la stabilité d'une **propriété choisie** — jamais l'absence de défaut.

R3 corrige la **rigueur** (l'oracle rougit-il ?) mais **pas le choix de la propriété** : injecter la régression qu'on avait en tête ne révèle jamais celle qu'on n'avait pas en tête. Trois des quatre familles les plus coûteuses (F-1, F-2, F-8) sont **invisibles à R3 menée par l'auteur** — F-1 parce que l'injection porte au bon endroit mais la mesure regarde ailleurs ; F-2 parce que l'injection ne s'exécute pas ; F-8 parce que l'injection **confirme** le défaut au lieu de le dénoncer.

**Le seul dispositif qui change la propriété choisie est le changement de LENTILLE** — c'est-à-dire un lecteur qui n'a pas écrit le code. C'est exactement ce que la revue à 4 lentilles a fourni, et c'est pourquoi elle a produit 12 findings HIGH/MAJEUR sur un socle dont les gates étaient tous verts.

### Le motif « contrainte déclarée, non tenue, garde qui regarde à côté » — troisième occurrence

1. **CR-IFFD-37** (v0.29.0) — `belowSubtitle` inutilisable à densité contrainte ;
2. **`chat-5`** — `theme.formPadding` écrasait `minHeight: 48`, hauteur utile réelle **40 dp** ;
3. **`chat-4b` / M-3** — `ConstrainedBox` écrasé par `enforce(contraintes du parent)`, mesuré **28,6 dp** dans la grille que la dartdoc du fichier cite elle-même comme cas cible.

Trois fois, le code **déclarait** la cible sans la tenir ; trois fois, la garde mesurait autre chose. Le correctif retenu cette fois est le bon parce qu'il est **structurel** : le plancher passe de la **cellule** à la **disposition** (`ZMenuEntryTile.gridDelegate`), et un enfant ne peut pas être plus grand que la place imposée — c'est le protocole de Flutter, pas une promesse. Le chemin où l'hôte impose sa propre grille serrée n'est plus garanti : il est **DÉNONCÉ** par une erreur de disposition en debug **qui nomme le remède**.
> **Règle générale** — une contrainte qui dépend du parent ne peut pas être garantie par l'enfant. Soit on **porte la contrainte au niveau qui la décide** (la disposition), soit on **renonce explicitement et on rend le manquement bruyant**. Jamais « déclarer et espérer ».

---

## 4. Leçons d'orchestration — ce que `CLAUDE.md` couvre déjà, et ce qu'il manque

### Déjà inscrit et suffisant
- **Un message envoyé à un agent TERMINÉ le RÉVEILLE** — la section existe, elle est datée, elle nomme l'incident et donne 4 règles. **Rien à ajouter.**
- **Health-check ~5 min d'inactivité de transcript** — présent, et il a servi (agent figé 32 min détecté).
- **`flutter test` depuis le dossier du paquet** — présent, chiffré, et respecté par tous les relecteurs.
- **CI morte / vérif locale seule ligne de défense** — présent.
- **Sérialisation des écritures du sprint-status** — présent et tenu ; aucune corruption du YAML cette epic.

### À ajouter — quatre règles que cette epic a payées et que `CLAUDE.md` ne porte pas

1. **`TaskStop` n'est pas synchrone.** Un agent arrêté a continué d'écrire ~10 min. → *Après un `TaskStop`, prouver l'arrêt réel par les **horodatages de fichiers** (`find lib test -newermt '-90 seconds'`) et par le figement du transcript, **avant** de lancer un remplaçant.* (Symétrique exact de la règle « ne jamais écrire "aucun autre agent n'édite" sans l'avoir mesuré ».)
2. **Un agent arrêté en pleine campagne R3 laisse le paquet CASSÉ PAR CONSTRUCTION.** Constaté : jeton d'instance + 2 sites d'usage laissés en place, paquet trouvé rouge. → *Après **tout** arrêt d'agent, avant toute autre action : `grep` du **marqueur d'injection** sur `lib/` **et** rejeu des tests du paquet. Le rouge trouvé après un arrêt est présumé **résiduel**, pas produit, jusqu'à preuve du contraire.*
3. **Le scratchpad n'est pas partageable entre agents parallèles.** Un agent a détruit la sauvegarde de l'autre. → *Un répertoire de travail **nommé par agent**. Toute campagne d'injection : manifeste `md5sum` **avant**, sauvegarde `cp -a`, restauration **par copie**, `md5sum -c` **après chaque** injection, **jamais `git checkout`**. Ce protocole existe déjà — il a été exécuté parfaitement par la lentille « tests porteurs » (244 fichiers, 10 injections, 0 divergence). Il doit être la **norme écrite**, pas une bonne pratique locale.*
4. **`.dart_tool/package_config` est PARTAGÉ par le workspace.** Chaque `flutter test` le réécrit ; un workstream parallèle en déclenche aussi. → *Un rouge de **chargement** (pas d'assertion) survenu pendant qu'un autre workstream tourne est présumé **infra** jusqu'à rejeu isolé. Ne jamais attribuer un rouge de chargement au code sans quiescence.* (C'est la leçon VIS 3.4 sous une nouvelle forme — deuxième occurrence.)

### Une règle méthodologique, pas d'orchestration
5. **Toute « absence » affirmée doit être adossée à un grep négatif reproduit dans le texte.** La lentille adversariale s'est imposé cette règle sans exception et a infirmé **6 affirmations** du sprint-status — dont « 2 clés de libellé » (réalité : 12), « trois menus » (réalité : **six** sites, dont trois **nommés nulle part** et donc invisibles au plan de migration), et « premier consommateur réel de `ZQuotaExceededFailure` » (réalité : **zéro**). *À généraliser aux rapports de lot, pas seulement aux revues.*

---

## 5. Ce que l'epic promet aux hôtes et n'a pas livré

**Mesuré par moi, sur le commit `9c49827`, après application de toutes les corrections de revue** (`grep -rn "implements X\|extends X" packages/*/lib example/`) :

| Port | Implémenteurs |
|---|---|
| `ZChatRenderer`, `ZChatActionExecutor`, `ZChatGenerationPort`, `ZChatAttachmentPicker`, `ZChatAttachmentUploader`, `ZChatPdfComposer`, `ZChatContextPort` | **0** |
| `ZChatExportSink` | **0** (l'unique hit est une dartdoc, `z_chat_export_ports.dart:67`) |
| `ZChatStreamPort` | 1 (`ZIffdTextStreamPort`) |
| `ZChatShellRenderer` | 1 (`ZSfAssistShellRenderer`) |
| `ZMenuRenderer` | 1 (`ZDefaultMenuRenderer`) |

**8 ports sur 11 n'ont aucun implémenteur**, `example/` compris — `grep -rln "zcrud_chat\|ZChatController" example/` → **aucun fichier**. L'application d'exemple du dépôt n'instancie **pas une ligne** de chat.

### Le risque, nommé

Ce n'est pas seulement « il reste du travail chez l'hôte ». C'est que **la garantie phare de l'epic n'a jamais tourné une seule fois**. La chaîne « confirmation systématique sur toute action destructrice » repose sur deux termes fournis **par l'hôte** : `isDestructive`/`cascades` déclarés sur `ZChatCustomAction`, et `affectedMessageCount` rendu par `executor.estimateImpact`. Sans implémenteur, la propriété est **structurellement invérifiable**. Aggravant : le constructeur de `ZChatActionPlan` est **public et `const`**, donc l'impact chiffré est contournable — la dartdoc promet aujourd'hui davantage que le code, et les tests du kernel empruntent eux-mêmes cette forme.

Le précédent est déjà écrit : `chat-4b` a prouvé qu'**une couture non consommée n'est pas prouvée**. Il n'y a aucune raison de croire que les 8 ports restants échapperont à la règle. Le premier hôte qui les branchera trouvera l'équivalent du défaut d'identité de closure — mais **chez lui**, sous notre nom, dans une API publique **irréversible**.

### Ce qui a été correctement fait malgré tout

Le handoff v0.30.0 **le dit en § 1, avant tout le reste** : « ce socle est une spécification exécutable, pas une fonctionnalité clé en main », avec le tableau reçoit/ne reçoit pas, le décompte 8/10 et la phrase « ce n'est pas un défaut de livraison, c'est AD-57 ». Il annonce aussi la migration IFFD comme **non additive**, liste nommément ce que chaque hôte doit **retirer**, et recommande **trois tripwires** qui rougiront à l'adoption. C'est exactement ce que les trois occurrences antérieures de l'erreur « additif pour qui ? » (v0.16.0, v0.19.1, v0.22.0) réclamaient. **La quatrième occurrence n'a pas eu lieu.**

### La suite

`chat-7..10` restent `backlog`, et `chat-7` s'est **effondré** à l'exploration (le serveur de lex calcule déjà tous les verdicts : `citation_guard.py`, `faithfulness_score`, `quality_grade` — le lot se réduit à **modéliser `done.metadata`**, pas à calculer de la confiance). C'est une bonne nouvelle de charge, mais elle ne remplace pas le manque : **le prochain lot prioritaire n'est aucun des quatre restants, c'est un consommateur de référence.**

---

## 6. Trois recommandations pour l'epic suivante, par ordre d'impact

### R1 — Un consommateur de référence dans `example/` est un **livrable de la story**, pas un extra

**Impact : le plus élevé.** C'est la seule mesure qui adresse à la fois le § 2.2 (couture non prouvée), le § 5 (8 ports orphelins) et la famille F-8 (garde qui défend le défaut — un consommateur réel ne peut pas être d'accord avec une garde qui protège un mauvais comportement, il *casse*).

- **Règle proposée** : aucune couture ne passe `done` sans **au moins un implémenteur non-test** dans le dépôt (`example/` compte, un fake de test **ne compte pas**).
- **Dette immédiate à ouvrir** : un lot `chat-11` qui écrit dans `example/` un `ZChatActionExecutor` et un `ZChatGenerationPort` de référence, et monte `ZChatConversationView`. Coût faible, valeur de preuve maximale : c'est le dispositif qui aurait trouvé l'identité de closure avant l'hôte.

### R2 — Une lentille « gardes non mordantes » jouée **à mi-epic**, pas seulement en fin

**Impact : élevé, coût faible.** La directive owner « une seule revue en fin d'epic » a bien été compensée par la vérif verte + R3 après chaque lot — mais R3 par l'auteur ne voit pas F-1, F-2 ni F-8 (§ 3). Résultat : 3 HIGH et 9 MAJEUR ont attendu la fin de 12 lots.

- Cette lentille est **la moins chère de toutes** : elle ne lit que les fichiers de `test/`, ne juge ni l'architecture ni la fonctionnalité, et son verdict est binaire et reproductible (injection → rouge d'assertion attendu, ou pas).
- **Déclencheur proposé** : au **premier lot qui introduit un nouveau paquet**, et à mi-parcours. Sur CHAT, jouée après `chat-3`, elle aurait rendu `chat-4b`, `chat-5` et `chat-6` moins coûteux — la garde 48 dp resserrée par `chat-4b` chez lui n'aurait pas laissé son **jumeau** `zcrud_study` sur la forme faible.
- Corollaire déjà dans `CLAUDE.md` mais à durcir : **une CR qui resserre une garde doit chercher ses jumelles** (`grep -rn "<motif>" packages/*/test`). Cette epic en a produit **trois** cas (48 dp, `Text(` faible, `AD-57` sur prose).

### R3 — Fermer les quatre trous d'orchestration par écrit, dans `CLAUDE.md`

**Impact : moyen sur la qualité, élevé sur le temps perdu.** Trois incidents, zéro dû au code, un paquet laissé rouge et une campagne R3 à rejouer intégralement. Les quatre règles du § 4 (arrêt non synchrone · contrôle anti-injection résiduelle après tout arrêt · scratchpad par agent + protocole `md5sum` normatif · `package_config` partagé) sont courtes, vérifiables, et chacune a un incident daté derrière elle.

À y joindre la règle méthodologique du § 4.5 : **toute « absence » affirmée dans un rapport de lot doit porter son grep négatif** — six affirmations du sprint-status ont été infirmées faute de cette discipline, et deux affirmations d'exploration ont dû être corrigées à la main.

---

## 7. Points de suivi ouverts (non traités dans cette epic)

| # | Sujet | Sévérité résiduelle |
|---|---|---|
| 1 | `ZChatActionPlan` : constructeur public ⇒ impact chiffré contournable (MAJ-2) | MAJEUR — dartdoc à corriger **ou** constructeur à privatiser |
| 2 | Menus résolus **par position** (`entries[i]`) dans `ZBatchActionBar`, `ZPageShell`, `z_sub_list_field_widget`, `z_table_embed` ×2 — **pire** que le no-op corrigé : exécute une **autre** action, ou lève un `RangeError` (MAJ-3) | MAJEUR — 3 des 5 sites ne sont **nommés nulle part** |
| 3 | Deux lectures **incompatibles** d'AD-10 sur les seams d'hôte : le kernel **absorbe**, les résolveurs **propagent** (MAJ-4) — corrigé en fin d'epic, à ne pas laisser rediverger | à garder sous garde |
| 4 | `ZChatExportVocabulary` ⊥ `ZcrudLabels` : deux registres pour un vocabulaire, **aucun pont, aucune garde de cohérence** (MAJ-5 / D-4) | MEDIUM |
| 5 | `zChatQuotaFromMetadata` : une seule clé présente ⇒ les autres à `0` ⇒ `resetEpoch: 0` (1970) et `isExhausted` **sur une donnée inventée** (MED-3) | MEDIUM |
| 6 | Mapping d'erreurs visant **5 codes qu'aucun des deux backends n'émet** ; 3 des 4 codes SSE réels de lex retombent en `ZChatProviderFailure` (MED-2) | MEDIUM |
| 7 | Gardes de pureté par **denylist** dans le kernel et l'adaptateur Syncfusion ; scan du kernel ancré sur `lib/src/domain/` seulement (F2, F4) | MEDIUM |
| 8 | `zcrud_menu` n'a **aucune** garde « chaîne en dur » (état actuel sans faute, filet absent) (D-5) | MEDIUM |
| 9 | HTML exporté sans `lang` ni `dir` ; slug ASCII-only ⇒ **vide** pour un titre non-latin, **figé par une garde** (D-2, D-3) | MEDIUM |
| 10 | La preuve de fermeture AD-57 se **skippe silencieusement** si `dart pub deps` échoue (F6) | LOW — rendre le skip visible |
| 11 | 🔴 **CI GitHub à l'arrêt** — action **owner** | bloquant hors code |
| 12 | Clé `epic-chat-retrospective` **absente** du sprint-status — à créer par l'orchestrateur, puis `done` | administratif |

---

## 8. Verdict de clôture

L'epic CHAT a livré un socle **architecturalement conforme** (0 HIGH de conformité, prouvé par greps et fermeture transitive) et **structurellement soigné** — la lentille adversariale, qui cherchait à le contredire, écrit elle-même que le contrat d'action, la couture par bloc, la couture de coquille et la boucle de reprise **tiennent**.

Elle a aussi établi, à ses frais, que **la couverture de test d'un dépôt n'est pas une propriété du code : c'est une propriété de la lecture qui l'a produite.** Douze lots verts, 1 378 tests, une campagne R3 par lot — et 12 findings HIGH/MAJEUR trouvés par des lecteurs qui n'avaient rien écrit.

La leçon à ne pas repayer tient en une ligne : **une garde prouve qu'un comportement est stable ; seul un consommateur prouve qu'il est juste.**
