# Code-review epic CHAT — lentille « conformité aux invariants d'architecture + isolation des dépendances »

Date : 2026-08-01 · Mode : **lecture seule** (aucun fichier de code modifié) · Aucun gate `melos` rejoué
(les autres relecteurs travaillaient en parallèle ; l'orchestrateur les avait déjà joués verts).

Périmètre relu : `packages/zcrud_chat_kernel`, `packages/zcrud_chat`, `packages/zcrud_chat_syncfusion`,
`packages/zcrud_menu`, plus les points de contact `packages/zcrud_core` et `packages/zcrud_study`.

---

## Verdict global

**Le socle CHAT est, en l'état du code livré, CONFORME aux invariants d'architecture.** Aucune violation
active d'AD-1, AD-2/AD-15, AD-3, AD-5/AD-11, AD-10 ou AD-57 n'a pu être établie sur disque. Les quatre
paquets sont sensiblement plus disciplinés que la moyenne du dépôt (zéro `throw`, zéro codegen, zéro
couleur en dur, réactivité par tranches).

**Ce qui n'est pas conforme, ce sont deux GARDES** — pas le code qu'elles surveillent. Elles sont vertes
aujourd'hui parce que le code est propre, pas parce qu'elles mordraient s'il cessait de l'être. Le
principal (F1) est exactement le motif que l'énoncé de la revue annonçait : une garde « flutter ou
`zcrud_*` », faible par construction dans un dépôt où **22 satellites `zcrud_*` portent une dépendance
tierce**.

| Sévérité | Nombre |
|---|---|
| HIGH | 0 |
| MAJEUR | 1 (F1) |
| MEDIUM | 3 (F2, F3, F4) |
| LOW | 2 (F5, F6) |

---

## 1. Ce qui est PROUVÉ conforme (greps montrés)

### 1.1 AD-1 — CORE OUT = 0, graphe acyclique

```
$ grep -nE "^\s+zcrud_" packages/zcrud_core/pubspec.yaml
rc=1                                   # aucune arête sortante déclarée

$ grep -rn "import 'package:zcrud_" packages/zcrud_core/lib | grep -v zcrud_core
rc=1                                   # aucun import d'un satellite dans le cœur

$ find packages/zcrud_core -ipath "*chat*"
(aucun résultat)

$ grep -rn "ZChat" packages/zcrud_core/lib
rc=0 (aucune ligne)                    # CHAT-0r : zéro résidu du domaine chat dans le cœur
```

Arêtes déclarées (lues dans les `pubspec.yaml`) :

```
zcrud_chat_kernel     -> {zcrud_core}
zcrud_chat            -> {flutter, zcrud_chat_kernel, zcrud_core}
zcrud_chat_syncfusion -> {flutter, syncfusion_flutter_chat, zcrud_chat, zcrud_chat_kernel, zcrud_core}
zcrud_menu            -> {flutter, zcrud_core}
zcrud_study           -> {…, zcrud_menu}          # CHAT-4b, acyclique (zcrud_menu ne dépend que du cœur)
```

Acyclique, `zcrud_core` puits. La garde `z_sf_ad57_isolation_guard_test.dart` (c) vérifie en outre que
**personne** ne dépend de `zcrud_chat_syncfusion` (puits inverse), en balayant tous les `packages/*/pubspec.yaml`.

**Aucune dépendance non déclarée** (import d'un `package:` absent du bloc `dependencies`), vérifié par
script sur les 35 paquets :

```
$ for d in packages/*/; do … comparer imports de lib/ ↔ dependencies … done
(aucune sortie)
```

### 1.2 AD-57 — Syncfusion isolé, prouvé en distinguant imports et prose

```
$ grep -rn "^import 'package:syncfusion" packages/*/lib packages/*/test
packages/zcrud_chat_syncfusion/lib/src/presentation/z_sf_assist_shell_renderer.dart:  syncfusion_flutter_chat/assist_view.dart
packages/zcrud_chat_syncfusion/test/z_sf_assist_view_test.dart:                        syncfusion_flutter_chat/assist_view.dart
packages/zcrud_export*/…                                                              syncfusion_flutter_pdf / xlsio
packages/zcrud_list/…                                                                 syncfusion_flutter_datagrid
```

`syncfusion_flutter_chat` n'apparaît **nulle part** hors de `zcrud_chat_syncfusion` — ni en import, ni
en dépendance de pubspec. Le filtre `^import` élimine les faux positifs de prose : les quatre paquets
CHAT commentent abondamment l'isolation Syncfusion, un grep naïf sur `syncfusion` en aurait sorti une
douzaine.

Le type Syncfusion **ne fuit pas non plus dans la surface publique** : `AssistMessage` /
`SfAIAssistView` n'apparaissent que comme variables locales dans `buildShell`
(`z_sf_assist_shell_renderer.dart:105-134`) ; aucune signature publique du barrel n'en porte.

Le guard `z_sf_ad57_isolation_guard_test.dart:337-388` va plus loin que le grep : il calcule la
**fermeture transitive** via `dart pub deps --json` et exige que `closure(zcrud_core / zcrud_chat_kernel
/ zcrud_chat)` ne contienne aucun `syncfusion*`, avec un contrôle positif (`closure(kOwner)` doit
contenir `syncfusion_flutter_core`, dépendance **indirecte**, pour prouver que la fermeture suit bien les
arêtes externe→externe). C'est le seul guard d'isolation transitive du périmètre, et il est bien fait.

### 1.3 AD-2 / AD-15 — aucun gestionnaire d'état, réactivité Flutter-native

```
$ grep -rnE "import 'package:(flutter_riverpod|riverpod|get|provider|get_it)/" \
      packages/zcrud_chat* packages/zcrud_menu packages/zcrud_core/lib
packages/zcrud_chat/test/z_chat_purity_test.dart:217:  "import 'package:provider/provider.dart';",
```

L'unique hit est le **témoin synthétique** du contrôle positif de la garde (discipline R3) — vérifié
lignes 215-229 : il sert à prouver que le détecteur sait distinguer une directive réelle d'une chaîne.

`ZChatController` (`z_chat_controller.dart:144`) est un `ChangeNotifier` pur dont les imports se limitent
à `dart:async`, `flutter/foundation.dart` et `flutter/widgets.dart show TextEditingController`
(ligne 87 — import **restreint**, pas le paquet entier). L'état est découpé en tranches indépendantes :
`_attachmentIds`, `_canSend`, `_messages`, `_activeRequests`, `_lastFailure`, `_liveAnnouncement`, plus
une tranche `ValueNotifier<String>` et une `ValueNotifier<ZChatStreamProgress>` **par requête**
(lignes 209-228). `notifyListeners()` n'est appelé qu'à un seul endroit : `attach()` ligne 360, le
changement structurel de conversation. Le tic d'un flux ne peut donc pas reconstruire la conversation.

```
$ grep -rn "setState"        packages/zcrud_chat/lib packages/zcrud_menu/lib packages/zcrud_chat_syncfusion/lib
$ grep -rn "ListView("       …
$ grep -rnE "EdgeInsets\.only\(\s*(left|right)|Alignment\.center(Left|Right)|TextAlign\.(left|right)" …
$ grep -rnE "Color\(0x|Colors\."  …                     rc=1
```

Tous les hits des trois premiers greps sont de la **prose** (dartdoc qui explique pourquoi la règle
s'applique) ; le quatrième ne rend rien du tout. L'unique `StatefulWidget` du périmètre,
`ZChatMessageTile` (`z_chat_message_tile.dart:50`), porte son état de dépli dans deux `ValueNotifier`
créés en champ de `State` et disposés (lignes 78-89) — pas de `setState`, pas de controller recréé au
build.

### 1.4 AD-3 — aucun codegen dans les paquets chat

```
$ find packages/zcrud_chat_kernel packages/zcrud_chat packages/zcrud_chat_syncfusion packages/zcrud_menu \
       -name "*.g.dart" -o -name "*.freezed.dart"
(aucun résultat)

$ grep -rn "^part " packages/zcrud_chat_kernel/lib packages/zcrud_chat/lib \
                    packages/zcrud_chat_syncfusion/lib packages/zcrud_menu/lib
rc=1
```

Aucun des quatre pubspecs ne déclare `zcrud_annotations`, `build_runner`, `json_serializable` ou
`json_annotation`. La (dé)sérialisation est bien écrite à la main : 28 points d'entrée `fromJson`/
`fromMap` recensés dans le kernel, tous manuels.

### 1.5 AD-5 / AD-11 — `Either` partout, aucun type de transport dans le domaine

```
$ grep -rnE "Last-Event-ID|Idempotency-Key|EventSource|HttpClient|Dio|Authorization|Bearer|'data: '" \
      packages/zcrud_chat_kernel/lib   → rc=1
      packages/zcrud_chat/lib          → rc=1
```

Les contrats du kernel rendent tous un `ZResult` (= `Either<ZFailure, T>`) :

```
z_chat_generation_port.dart:208   Future<ZResult<List<ZContentBlock>>> generate(…)
z_chat_generation_port.dart:262   Stream<ZResult<ZChatStreamEvent>> stream(…)
z_chat_action_executor.dart:44    Future<ZResult<ZChatActionImpact>> estimateImpact(…)
z_chat_action_executor.dart:56    Future<ZResult<List<String>>> regenerate(…)
z_chat_action_executor.dart:74    Future<ZResult<Unit>> cancelRequest(…)
z_chat_action_executor.dart:84    Future<ZResult<List<String>>> executeCustom(…)
```

Point notable et **bien traité** : l'adaptateur IFFD est le seul endroit qui touche au texte de
transport, et il ne le laisse pas remonter. `ZIffdRawStreamOpener`
(`z_iffd_stream_port.dart:32-36`) est un `Stream<String> Function(request, token)` fourni par l'hôte :
le socle ne connaît ni SSE, ni en-tête, ni `CancelToken`. La reprise (`Last-Event-ID`) est modélisée
comme `ZChatRequestToken.resumeFrom(sequenceId)`, sans nom de transport — et le normalizer refuse
délibérément de **fabriquer** des `sequenceId` (`z_iffd_stream_normalizer.dart:20-28`), parce que le
serveur IFFD n'a aucun point de reprise : mentir sur `resumeFrom` ferait rejouer un tour entier. C'est
une décision d'isolation exacte, pas une omission.

### 1.6 AD-10 — désérialisation et normalisation défensives

```
$ grep -rn "throw " packages/zcrud_chat_kernel/lib packages/zcrud_chat/lib \
                    packages/zcrud_chat_syncfusion/lib packages/zcrud_menu/lib
(aucun résultat dans les quatre paquets)
```

Vérifications de fond, faites en lisant le code et pas la dartdoc :

* `ZContentBlock.fromJson` (`z_content_block.dart:183-268`) : `raw` non-Map ⇒ `null` ; `type` absent ou
  vide ⇒ `null` ; type inconnu ⇒ `ZCustomContentBlock` **payload verbatim** ; codec du `ZTypeRegistry`
  appelé via `tryCodecFor` (jamais `codecFor`, qui lève) et enveloppé dans `zJsonGuard` ligne 263 —
  un codec d'app qui lève est absorbé, avec repli sur le payload brut.
* `ZChatMessage.fromMap` (`z_chat_message.dart:87-140`) : chaque champ passe par un helper total
  (`zJsonStringOrNull`, `zJsonDate`, `zJsonDecodeList`, `X.fromJson`). `zJsonDecodeList`
  (`packages/zcrud_core/lib/src/domain/json/z_json_read.dart:159-161`) ignore l'élément illisible et
  **conserve la liste**. `zJsonGuard` (ligne 132-138) est un `try/catch(_) → null`. Aucun `throw` dans
  tout `z_json_read.dart`.
* `ZIffdLexer` (`z_iffd_lexer.dart`) : marqueur `###LINE###` coupé entre deux fragments et balise coupée
  entre deux fragments sont retenus, mais la rétention de balise est **bornée à 64 caractères**
  (`_maxTagHold`, ligne 88) — un `<` littéral (« a < b ») ne peut donc pas geler le flux, et la queue est
  relâchée **comme du texte** : mémoire bornée + zéro perte. `close()` vide la queue.
* `ZIffdStreamNormalizer` : sentinelle jamais refermée ⇒ émission au fil de l'eau (aucun événement
  n'attend un `</…>` qui n'arrivera pas) ; fermante orpheline ⇒ ignorée, jamais rendue comme texte
  (ligne 124-128) ; balise inconnue ⇒ canal `thinking` par défaut ; JSON de payload illisible ⇒
  `ZChatCustomStreamEvent` portant le texte brut sous `raw` (ligne 234-242) ; flux tronqué ⇒ `close()`
  vide ligne et payload partiels.
* `ZIffdTextStreamPort.stream` (`z_iffd_stream_port.dart:55-79`) : `on Object catch` — **toute**
  exception du transport de l'hôte devient un `Left(ZChatStreamInterruptedFailure)`, après avoir vidé
  le normalizer pour ne pas perdre le contenu déjà décodé.
* `ZChatController._ask` (`z_chat_controller.dart:725-731`) : un seam de confirmation d'hôte qui **lève**
  vaut un **refus**, jamais une destruction par défaut.
* `ZChatController._fail` (lignes 593-623) : contenu partiel conservé ; si rien n'a été produit et que
  l'arrêt n'est pas volontaire, le message optimiste est retiré et la **saisie restituée**.

### 1.7 AD-4 — extension par registre

`ZContentBlock` est `sealed` mais **scellé en interne uniquement** : l'ouverture inter-package passe par
`ZTypeRegistry` + le variant `ZCustomContentBlock` (`z_content_block.dart:155-157`, 258-266). Même
motif pour `ZChatStreamEvent` (variant `ZChatCustomStreamEvent`) et pour `ZChatGenerationStyle`, que le
guard `z_chat_ai_ports_guard_test.dart:326` maintient **non-enum**. `ZChatSource` réutilise le
`ZSourceRegistry` existant du cœur (paramètre `registry` propagé jusque dans `ZContentBlock.fromJson`
ligne 246) — pas de second registre, le guard G-C5 « AUCUN second registre n'est créé (le motif
CR-LEX-78) » (ligne 336) le vérifie. Les slots `ZExtension?` + `extra` sont présents sur `ZChatMessage`
et `ZChatConversation`, avec normalisation eager contre `ZSyncMeta.reservedKeys`.

### 1.8 Le cœur reste transverse

Le seul ajout de CHAT-0 dans `zcrud_core` est `lib/src/domain/json/z_json_read.dart`, exporté par
`domain.dart:89`. Il ne mentionne « chat » que dans deux lignes de dartdoc citant les consommateurs
(`ZFlashcardSource`, `AppFile`, `ZMindmap`, le modèle de chat). C'est bien un mécanisme transverse, pas
un domaine métier.

---

## 2. Findings

### F1 — MAJEUR · la garde « aucune dépendance TIERCE » de `zcrud_chat` n'interdit rien de tiers

**Chemin** : `packages/zcrud_chat/test/z_chat_purity_test.dart:290-311`, en particulier **ligne 305**.

**Règle** : AD-1 (isolation des dépendances : un satellite ne doit pas faire entrer une dépendance
tierce par transitivité) et l'engagement écrit du paquet lui-même
(`packages/zcrud_chat/pubspec.yaml` : « ⛔ AUCUNE dépendance TIERCE (ni client HTTP, ni SDK IA) »).

**Le code** :

```dart
// z_chat_purity_test.dart:304-310
expect(
  deps.where((String d) => d != 'flutter' && !d.startsWith('zcrud_')),
  isEmpty,
  reason: '🔴 le transport (HTTP/SSE), les SDK IA et les prompts restent '
      'CÔTÉ APP (AD-11/AD-12), derrière `ZChatStreamPort`. Vu : $deps',
);
```

Le test s'intitule « aucune dépendance **TIERCE** ». Ce qu'il vérifie est : *aucune dépendance qui ne
soit ni `flutter` ni un `zcrud_*`*. Dans ce dépôt, ce n'est pas la même chose — **22 paquets `zcrud_*`
portent une dépendance tierce**, mesuré :

```
zcrud_markdown       -> flutter_quill, markdown, markdown_quill, vsc_quill_delta_to_html,
                        flutter_quill_delta_from_html, flutter_math_fork
zcrud_get            -> get, get_it, reflectable
zcrud_riverpod / zcrud_provider -> riverpod / provider
zcrud_firestore      -> cloud_firestore, firebase_core, hive, hive_flutter
zcrud_list / zcrud_export / zcrud_export_pdf / zcrud_chat_syncfusion -> syncfusion_*
zcrud_media, zcrud_geo, zcrud_html, zcrud_dnd, zcrud_select, zcrud_reorder,
zcrud_session, zcrud_intl, zcrud_field_extras, zcrud_export_ui, zcrud_mindmap …
```

**Scénario d'échec concret** — et ce n'est pas hypothétique, c'est la suite planifiée du lot : l'entrée
`chat-3-rendu-neutre` du sprint-status spécifie « rendu riche via ZCodec (**zcrud_markdown**, AD-7) ».
Le jour où quelqu'un ajoute `zcrud_markdown: ^0.29.0` aux `dependencies` de `zcrud_chat` pour honorer
cette ligne :

1. la fermeture de dépendances de `zcrud_chat` gagne `flutter_quill`, `markdown`, `markdown_quill`,
   `vsc_quill_delta_to_html`, `flutter_quill_delta_from_html` et `flutter_math_fork` ;
2. `z_chat_purity_test.dart` reste **VERT** — `zcrud_markdown` commence par `zcrud_` ;
3. le titre du test continue d'affirmer « aucune dépendance TIERCE », et le pubspec continue d'afficher
   « ⛔ AUCUNE dépendance TIERCE » ;
4. tout hôte qui tire `zcrud_chat` (dont DODLP et DLCFTI, qui n'ont aucun usage de Quill) en porte le
   poids — **exactement l'erreur que CHAT-0r vient de corriger** en sortant le domaine chat de
   `zcrud_core`.

Variante plus grave : `zcrud_get` amènerait `get` (gestionnaire d'état, AD-2/AD-15) **et**
`reflectable` (interdit explicite du dépôt). Le denylist `_banned` du même fichier
(`z_chat_purity_test.dart:54-66`) ne le verrait pas non plus : il balaye les **imports du `lib/` local**,
pas la fermeture de dépendances. Les deux gardes du fichier ont donc le même angle mort, et il est le
même que celui de la CR-LEX-44 (« une CR qui change un contrat doit chercher ses gardes jumelles »).

**Remède** : la formulation correcte existe déjà dans le périmètre —
`packages/zcrud_menu/test/z_menu_purity_test.dart:17` :

```dart
const Set<String> _depsAutorisees = <String>{'flutter', 'zcrud_core'};
```

Un **allowlist nominatif** (`{flutter, zcrud_core, zcrud_chat_kernel}`), ou mieux une preuve de
fermeture transitive sur le modèle de `z_sf_ad57_isolation_guard_test.dart:337-388`, ferme le trou.

---

### F2 — MEDIUM · la garde de pureté du kernel ne couvre que `lib/src/domain/`, et son interdit tiers est un denylist

**Chemins** : `packages/zcrud_chat_kernel/test/support/z_repo_sources.dart:53-56` (périmètre du scan) ·
`packages/zcrud_chat_kernel/test/z_chat_naming_guard_test.dart:195-233` (règle G17) ·
`.../z_chat_naming_guard_test.dart:313-345` (règle pubspec).

**Règle** : AD-1 / AD-14 — le kernel est un puits pur-Dart, arête sortante unique vers
`package:zcrud_core/domain.dart`.

**Ce qui est bon** : la partie `zcrud_*` de G17 est un **allowlist** exact (ligne 226-231 : tout
`package:zcrud_` qui n'est pas `package:zcrud_core/domain.dart` est un offender). C'est la bonne
formulation, celle qui manque à F1.

**Les deux trous** :

1. **Périmètre.** `chatDartFiles()` liste uniquement
   `packages/zcrud_chat_kernel/lib/src/domain/`. Aujourd'hui c'est tout le paquet (26 fichiers sur 27,
   le 27ᵉ étant le barrel) — donc la garde est verte et complète *par coïncidence de structure*.
2. **Nature de l'interdit tiers.** La liste `interdits` (lignes 196-207) est un **denylist** figé :
   flutter, dart:ui, firestore, firebase, hive, riverpod, get, provider, json_annotation. Et le test
   pubspec (313-345) n'interdit que les quatre dépendances de codegen + les arêtes `zcrud_*` du cœur.
   **Aucun test n'énumère les dépendances autorisées du kernel.**

**Scénario d'échec concret** : un lot ultérieur ajoute `packages/zcrud_chat_kernel/lib/src/data/z_chat_openai_client.dart`
avec `import 'package:openai_dart/openai_dart.dart';` et déclare `openai_dart` au pubspec du kernel.
Résultat : G17 ne scanne pas `lib/src/data/` → pas d'offender ; le denylist ne contient pas `openai_dart`
→ pas d'offender même si le fichier avait été scanné ; le test pubspec ne cherche que le codegen → vert ;
la garde `.g.dart` scanne bien `lib/` en récursif mais uniquement pour les fichiers générés. **Les 283
tests du kernel restent verts** alors qu'un SDK IA vient d'entrer dans le noyau pur-Dart du chat, en
violation directe d'AD-11/AD-12 et de la raison d'être du paquet.

**Remède** : ancrer le scan sur `lib/` (récursif, barrel compris) plutôt que sur `lib/src/domain/`, et
ajouter le pendant de `_depsAutorisees` : `dependencies ⊆ {zcrud_core}`, `dev_dependencies ⊆ {test}`.

---

### F3 — MEDIUM · les tranches par requête ne sont jamais libérées à la fin d'un tour

**Chemin** : `packages/zcrud_chat/lib/src/presentation/z_chat_controller.dart:644-653` (`_release`),
lignes 225-228 (les tables), 747-752 (`_textOf` / `_progressOf`), 340-361 (`attach`), 762-787 (`dispose`).

**Règle** : AD-2 / SM-1 — les tranches réactives sont un mécanisme de performance ; leur cycle de vie doit
être borné.

**Le code** :

```dart
// z_chat_controller.dart:644-653
/// Retire une requête des tables **sans** disposer ses tranches : un widget
/// peut encore les écouter le temps d'une transition.
void _release(String requestId) {
  _tokens.remove(requestId);
  _states.remove(requestId);
  _activeRequests.value = …;
}
```

`_streamTexts[requestId]` et `_progress[requestId]` ne sont retirés **nulle part** ailleurs qu'en
`attach()` (changement de conversation) et `dispose()`. Grep exhaustif des deux tables :

```
$ grep -n "_streamTexts\|_progress\[" packages/zcrud_chat/lib/src/presentation/z_chat_controller.dart
225,227  déclaration
346,349  attach() — dispose + clear
350,353  attach() — dispose + clear
748,751  création paresseuse (??=)
778,785  dispose() — dispose + clear
```

**Scénario d'échec concret** : une conversation longue, jamais quittée (le cas nominal d'un assistant
d'étude — c'est le sens même de `attach(conversationId:)`, qui n'est appelé qu'au **changement** de
conversation). 200 tours ⇒ 400 `ValueNotifier` vivants, dont 200 `ValueNotifier<String>` retenant
**l'intégralité du texte de leur réponse**. Ce texte est un doublon : `_settle`
(lignes 568-588) l'a déjà recopié dans un `ZChatMessage` de `_messages`. Sur des réponses de quelques
kilo-octets, c'est un doublement pur de l'empreinte mémoire de la conversation, croissant sans borne et
sans éviction. Aucun test ne l'affirme (`grep -rn "leak\|fuite\|évict\|unbounded" packages/zcrud_chat/test`
ne rend que des occurrences relatives aux bornes de pièces jointes).

L'intention documentée (« un widget peut encore les écouter le temps d'une transition ») est légitime ;
ce qui manque est la **borne** : pas de fenêtre, pas de LRU, pas de libération différée.

**Remède** : conserver les N derniers `requestId` (N petit, paramétrable), disposer au-delà ; ou libérer
la tranche à la frame suivante après `_settle`/`_fail`. Et une garde qui compte
`controller.debugSliceCount` après k tours.

---

### F4 — MEDIUM · `zcrud_chat_syncfusion` n'a qu'un denylist d'imports, sans allowlist de pubspec

**Chemin** : `packages/zcrud_chat_syncfusion/test/z_sf_purity_guard_test.dart:42-56` (`kBannedImports`)
et 124-140 (application).

**Règle** : AD-11 / AD-12 — le transport et les SDK IA restent côté app ; le paquet ne consomme qu'un
`Stream<String>` déjà décadré.

`kBannedImports` énumère riverpod, hooks_riverpod, get, get_it, provider, dio, http, firebase_,
cloud_firestore. C'est la bonne intention, mais c'est une liste **fermée**, et rien ne contraint le
`pubspec.yaml` de ce paquet (contrairement à `zcrud_menu`, dont les deux blocs sont sous allowlist).

**Scénario d'échec concret** : l'adaptateur IFFD gagne un jour un appel direct au backend — l'auteur
ajoute `google_generative_ai` (ou `openai_dart`, ou `web_socket_channel`, ou `sse_channel`) au pubspec
et l'importe dans `src/data/`. Aucun motif de `kBannedImports` ne matche. Les 52 tests restent verts, et
la promesse centrale du paquet — « ce paquet consomme un `Stream<String>` déjà décadré, fourni par
l'hôte », écrite dans son propre pubspec — devient fausse sans qu'aucune garde ne rougisse. Le contrat
`ZIffdRawStreamOpener` reste dans le code, mais plus rien n'oblige à passer par lui.

Détail secondaire du même fichier : la règle applique `s.contains(banned)` sur le **fichier entier**, pas
sur les lignes de directive. C'est le biais **inverse** de F1 (faux positif possible sur une dartdoc
citant `package:dio/`), donc sans danger d'échappement — mais la version par directive existe déjà à
côté, dans `z_chat_purity_test.dart:103` (`_directives`), et serait plus juste.

**Remède** : allowlist `dependencies ⊆ {flutter, syncfusion_flutter_chat, zcrud_chat, zcrud_chat_kernel,
zcrud_core}`, sur le modèle de `z_menu_purity_test.dart:17`.

---

### F5 — LOW · une valeur d'enum inconnue est perdue au round-trip, sans repli de préservation

**Chemins** : `packages/zcrud_chat_kernel/lib/src/domain/z_chat_enums.dart:160` (`ZChatFeedbackRating`),
`:197` (`ZChatFeedbackCategory`), `:235` (`ZChatSuggestionType`), `:269` (`ZChatSuggestionActionType`),
`:305` (`ZChatSourceUsageStatus`).

Ces cinq `fromJson` rendent `null` sur une valeur inconnue. Le champ étant une **clé réservée**
(`ZChatMessage._reservedKeys`), la valeur brute n'est pas non plus recueillie dans `extra` — elle
disparaît. `toMap` omet alors la clé.

**Scénario** : une app v2 écrit `feedback_category: "hallucination"` ; un client encore sur v1 relit le
message et le réécrit (le store local est source de vérité, AD-9, et le merge est LWW sur `updatedAt`) ;
la catégorie est **effacée** côté serveur, silencieusement.

**Pourquoi LOW et pas MEDIUM** : c'est exactement le comportement que la convention du dépôt prescrit
(`@JsonKey(unknownEnumValue:)`, CLAUDE.md/AD-3), et l'évolution de schéma est déclarée « additive
seulement ». Le fichier applique par ailleurs le motif de repli **explicite** là où il compte
(`ZChatRole.unknown` ligne 42, avec la justification que lex coerçait tout en `user` ;
`ZChatDatasetFreshness.unknown` ; `ZChatConfidenceLevel.toVerify`, repli fail-safe). À consigner comme
dette connue, pas à corriger dans cette epic — le motif ouvert existe déjà (`ZChatGenerationStyle` via
`ZTypeRegistry`) si le besoin devient réel.

---

### F6 — LOW · la preuve de fermeture AD-57 peut être silencieusement absente

**Chemin** : `packages/zcrud_chat_syncfusion/test/z_sf_ad57_isolation_guard_test.dart:344-349` et 364-366.

`resolvedGraph()` rend `null` si `dart pub deps --json` échoue ou est indisponible ; les tests (a) et (b)
appellent alors `markTestSkipped` et passent. Le scanner de sources reste exécuté — il couvre les
imports, pas la **transitivité**, qui est précisément l'apport de ces deux tests.

**Scénario** : en environnement où `dart pub deps` échoue (workspace non bootstrappé, cache absent), la
suite affiche « 52 tests OK » et la seule preuve d'isolation transitive du dépôt n'a pas tourné. Le repli
est raisonnable (mieux vaut un skip qu'un rouge d'environnement), mais il devrait être **visible** :
compter les skips, ou faire échouer le run si le graphe est indisponible **et** que la variable CI est
positionnée.

---

## 3. Ce que je n'ai PAS pu vérifier

* Les gates `melos run verify` / `analyze` / `graph_proof` n'ont pas été rejoués (consigne : trois
  relecteurs en parallèle). Je m'appuie sur la vérif verte de l'orchestrateur pour la compilation, et
  uniquement sur la **lecture du code et des greps** pour les constats ci-dessus.
* La fermeture transitive réelle (`dart pub deps --json`) n'a pas été calculée par moi : les arêtes
  rapportées viennent des `pubspec.yaml`. Pour `syncfusion_*`, le guard du dépôt la calcule et la vérifie,
  avec contrôle positif — je considère ce point prouvé par un mécanisme que j'ai lu.
* Les lentilles a11y/RTL, tests porteurs, adversariale et parité fonctionnelle relèvent des autres
  relecteurs ; je ne les ai touchées que là où elles croisent un invariant (AD-13 sur les greps de style).
